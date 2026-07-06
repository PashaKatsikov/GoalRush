import 'dart:math';

import 'question.dart';

/// Generates the never-ending stream of penalty-kick questions.
///
/// Math / sequence / comparison questions are generated procedurally so they
/// never run out and scale in difficulty with [round]. Logic / trivia / odd
/// one out come from a hand-written pool so the wording stays natural, and
/// are shuffled + de-duplicated so repeats are rare within a session.
class QuestionBank {
  QuestionBank({Random? random}) : _random = random ?? Random();

  final Random _random;
  final List<int> _recentLogic = [];
  final List<int> _recentTrivia = [];
  final List<int> _recentOddOneOut = [];

  /// Returns a new question. [round] (1-based) drives difficulty scaling.
  Question next(int round) {
    final category = QuestionCategory.values[_random.nextInt(QuestionCategory.values.length)];
    switch (category) {
      case QuestionCategory.math:
        return _generateMath(round);
      case QuestionCategory.sequence:
        return _generateSequence(round);
      case QuestionCategory.comparison:
        return _generateComparison(round);
      case QuestionCategory.logic:
        return _pick(_logicPool, _recentLogic, QuestionCategory.logic);
      case QuestionCategory.generalKnowledge:
        return _pick(_triviaPool, _recentTrivia, QuestionCategory.generalKnowledge);
      case QuestionCategory.oddOneOut:
        return _pick(_oddOneOutPool, _recentOddOneOut, QuestionCategory.oddOneOut);
    }
  }

  /// Suggested countdown duration (seconds) for the given round. Starts
  /// generous and tightens up as rounds progress, per the game design doc.
  static double timeForRound(int round) {
    final value = 9.5 - (round - 1) * 0.35;
    return value.clamp(3.5, 9.5);
  }

  // ---------------------------------------------------------------------
  // Procedural generators
  // ---------------------------------------------------------------------

  Question _generateMath(int round) {
    final maxN = 8 + round * 3;
    final ops = ['+', '-', '\u00d7'];
    final op = ops[_random.nextInt(round < 4 ? 2 : ops.length)];
    int a = 1 + _random.nextInt(maxN);
    int b = 1 + _random.nextInt(maxN);
    int answer;
    switch (op) {
      case '+':
        answer = a + b;
        break;
      case '-':
        if (b > a) {
          final t = a;
          a = b;
          b = t;
        }
        answer = a - b;
        break;
      default:
        a = 1 + _random.nextInt(min(6 + round, 12));
        b = 1 + _random.nextInt(min(6 + round, 12));
        answer = a * b;
    }
    final prompt = '$a $op $b = ?';
    final options = _numericDistractors(answer, spread: max(2, (maxN / 4).round()));
    return _buildFromOptions(QuestionCategory.math, prompt, options, answer.toString());
  }

  Question _generateSequence(int round) {
    final step = 2 + _random.nextInt(3 + (round ~/ 2));
    final ascending = _random.nextBool();
    final signedStep = ascending ? step : -step;
    final start = 2 + _random.nextInt(10 + round * 2);
    final seq = List<int>.generate(4, (i) => start + signedStep * i);
    final answer = start + signedStep * 4;
    final prompt = '${seq.join(', ')}, ?';
    final options = _numericDistractors(answer, spread: step);
    return _buildFromOptions(QuestionCategory.sequence, prompt, options, answer.toString());
  }

  Question _generateComparison(int round) {
    final maxN = 20 + round * 8;
    final wantLargest = _random.nextBool();
    final numbers = <int>{};
    while (numbers.length < 4) {
      numbers.add(1 + _random.nextInt(maxN));
    }
    final list = numbers.toList();
    final answer = wantLargest ? list.reduce(max) : list.reduce(min);
    final prompt = wantLargest ? 'Which number is the largest?' : 'Which number is the smallest?';
    final options = list.map((e) => e.toString()).toList()..shuffle(_random);
    return Question(
      category: QuestionCategory.comparison,
      prompt: prompt,
      options: options,
      correctIndex: options.indexOf(answer.toString()),
    );
  }

  List<int> _numericDistractors(int answer, {required int spread}) {
    final set = <int>{answer};
    while (set.length < 4) {
      final delta = 1 + _random.nextInt(max(2, spread));
      final candidate = _random.nextBool() ? answer + delta : answer - delta;
      if (candidate >= 0) set.add(candidate);
    }
    return set.toList();
  }

  Question _buildFromOptions(
    QuestionCategory category,
    String prompt,
    List<int> numericOptions,
    String correctValue,
  ) {
    final options = numericOptions.map((e) => e.toString()).toList()..shuffle(_random);
    return Question(
      category: category,
      prompt: prompt,
      options: options,
      correctIndex: options.indexOf(correctValue),
    );
  }

  Question _pick(List<_RawQuestion> pool, List<int> recent, QuestionCategory category) {
    int index;
    do {
      index = _random.nextInt(pool.length);
    } while (pool.length > recent.length + 1 && recent.contains(index));
    recent.add(index);
    if (recent.length > (pool.length / 2).ceil()) {
      recent.removeAt(0);
    }
    final raw = pool[index];
    final options = List<String>.from(raw.options)..shuffle(_random);
    return Question(
      category: category,
      prompt: raw.prompt,
      options: options,
      correctIndex: options.indexOf(raw.options[raw.correctIndex]),
    );
  }

  // ---------------------------------------------------------------------
  // Fixed pools
  // ---------------------------------------------------------------------

  static final List<_RawQuestion> _logicPool = [
    _RawQuestion('Amir is older than Kofi. Kofi is older than Lia. Who is the youngest?',
        ['Amir', 'Kofi', 'Lia', 'Cannot be determined'], 2),
    _RawQuestion('If all strikers are athletes, and Sam is a striker, what must be true?',
        ['Sam is an athlete', 'Sam is a goalkeeper', 'Sam is not an athlete', 'Sam is a coach'], 0),
    _RawQuestion('A team wins if it scores more goals than the opponent. Team A: 2, Team B: 3. Who wins?',
        ['Team A', 'Team B', 'It is a draw', 'Not enough info'], 1),
    _RawQuestion('Every red card removes one player. A team starts with 11 and gets 2 red cards. How many players remain?',
        ['9', '10', '8', '11'], 0),
    _RawQuestion('If today is Tuesday, what day was it 3 days ago?',
        ['Sunday', 'Saturday', 'Monday', 'Friday'], 1),
    _RawQuestion('A box has more red balls than blue balls. There are no other colors. If you remove all blue balls, what remains?',
        ['Only red balls', 'Only blue balls', 'An empty box', 'Equal red and blue'], 0),
    _RawQuestion('Mia finished the race before Zoe. Zoe finished before Ken. Who finished first?',
        ['Mia', 'Zoe', 'Ken', 'Cannot be determined'], 0),
    _RawQuestion('A clock shows 3:00. What time was it 90 minutes earlier?',
        ['1:30', '2:30', '4:30', '12:30'], 0),
    _RawQuestion('If it rains, the match is postponed. It is raining. What happens to the match?',
        ['It is postponed', 'It continues as normal', 'It ends in a draw', 'It starts early'], 0),
    _RawQuestion('Three friends split 9 apples equally. How many apples does each friend get?',
        ['3', '4', '2', '9'], 0),
    _RawQuestion('A player must score twice to get a hat-trick bonus... wait, a hat-trick needs 3 goals. If a player scored 2, how many more for a hat-trick?',
        ['1', '2', '3', '0'], 0),
    _RawQuestion('All squares are rectangles. Is every rectangle a square?',
        ['No', 'Yes', 'Only big ones', 'Only small ones'], 0),
    _RawQuestion('If A = B and B = C, what is the relationship between A and C?',
        ['A = C', 'A > C', 'A < C', 'No relationship'], 0),
    _RawQuestion('A referee shows yellow, then a second yellow to the same player. What card follows?',
        ['Red card', 'Green card', 'Blue card', 'No card'], 0),
    _RawQuestion('Five players stand in a line. The tallest is in the middle. What position is the tallest?',
        ['3rd', '1st', '5th', '2nd'], 0),
  ];

  static final List<_RawQuestion> _triviaPool = [
    _RawQuestion('How many players are on a football team on the pitch (including goalkeeper)?',
        ['11', '9', '10', '12'], 0),
    _RawQuestion('What shape is a standard football pitch?',
        ['Rectangle', 'Circle', 'Square', 'Triangle'], 0),
    _RawQuestion('How many minutes are in a standard football half?',
        ['45', '30', '60', '20'], 0),
    _RawQuestion('What color is a caution card in football?',
        ['Yellow', 'Blue', 'Purple', 'Orange'], 0),
    _RawQuestion('Which planet is known as the Red Planet?',
        ['Mars', 'Venus', 'Jupiter', 'Saturn'], 0),
    _RawQuestion('How many continents are there on Earth?',
        ['7', '5', '6', '8'], 0),
    _RawQuestion('What is the freezing point of water in Celsius?',
        ['0', '100', '32', '-10'], 0),
    _RawQuestion('How many days are there in a leap year?',
        ['366', '365', '360', '364'], 0),
    _RawQuestion('What is the largest ocean on Earth?',
        ['Pacific', 'Atlantic', 'Indian', 'Arctic'], 0),
    _RawQuestion('How many sides does a hexagon have?',
        ['6', '5', '7', '8'], 0),
    _RawQuestion('Which organ pumps blood through the body?',
        ['Heart', 'Lungs', 'Liver', 'Kidney'], 0),
    _RawQuestion('What do you call a shape with three sides?',
        ['Triangle', 'Square', 'Pentagon', 'Hexagon'], 0),
    _RawQuestion('How many colors are there in a rainbow?',
        ['7', '5', '6', '8'], 0),
    _RawQuestion('What gas do plants absorb from the air to grow?',
        ['Carbon dioxide', 'Oxygen', 'Nitrogen', 'Hydrogen'], 0),
    _RawQuestion('How many hours are there in a full day?',
        ['24', '12', '48', '20'], 0),
  ];

  static final List<_RawQuestion> _oddOneOutPool = [
    _RawQuestion('Which one does not belong: Apple, Banana, Carrot, Orange?',
        ['Carrot', 'Apple', 'Banana', 'Orange'], 0),
    _RawQuestion('Which one does not belong: Football, Basketball, Guitar, Tennis?',
        ['Guitar', 'Football', 'Basketball', 'Tennis'], 0),
    _RawQuestion('Which one does not belong: Dog, Cat, Chair, Rabbit?',
        ['Chair', 'Dog', 'Cat', 'Rabbit'], 0),
    _RawQuestion('Which one does not belong: Red, Blue, Circle, Green?',
        ['Circle', 'Red', 'Blue', 'Green'], 0),
    _RawQuestion('Which one does not belong: Car, Bus, Bicycle, Sandwich?',
        ['Sandwich', 'Car', 'Bus', 'Bicycle'], 0),
    _RawQuestion('Which one does not belong: January, Monday, March, July?',
        ['Monday', 'January', 'March', 'July'], 0),
    _RawQuestion('Which one does not belong: Square, Rectangle, Triangle, River?',
        ['River', 'Square', 'Rectangle', 'Triangle'], 0),
    _RawQuestion('Which one does not belong: Piano, Violin, Drum, Spoon?',
        ['Spoon', 'Piano', 'Violin', 'Drum'], 0),
    _RawQuestion('Which one does not belong: Goalkeeper, Striker, Referee, Umbrella?',
        ['Umbrella', 'Goalkeeper', 'Striker', 'Referee'], 0),
    _RawQuestion('Which one does not belong: Sun, Moon, Star, Shoe?',
        ['Shoe', 'Sun', 'Moon', 'Star'], 0),
    _RawQuestion('Which one does not belong: Whale, Shark, Dolphin, Eagle?',
        ['Eagle', 'Whale', 'Shark', 'Dolphin'], 0),
    _RawQuestion('Which one does not belong: Spring, Summer, Autumn, Friday?',
        ['Friday', 'Spring', 'Summer', 'Autumn'], 0),
    _RawQuestion('Which one does not belong: Gold, Silver, Bronze, Cloud?',
        ['Cloud', 'Gold', 'Silver', 'Bronze'], 0),
    _RawQuestion('Which one does not belong: Pen, Pencil, Marker, Ball?',
        ['Ball', 'Pen', 'Pencil', 'Marker'], 0),
    _RawQuestion('Which one does not belong: Two, Four, Six, Seven?',
        ['Seven', 'Two', 'Four', 'Six'], 0),
  ];
}

class _RawQuestion {
  const _RawQuestion(this.prompt, this.options, this.correctIndex);

  final String prompt;
  final List<String> options;
  final int correctIndex;
}
