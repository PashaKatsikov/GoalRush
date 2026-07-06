enum QuestionCategory {
  math,
  logic,
  sequence,
  generalKnowledge,
  comparison,
  oddOneOut,
}

extension QuestionCategoryLabel on QuestionCategory {
  String get label {
    switch (this) {
      case QuestionCategory.math:
        return 'Math';
      case QuestionCategory.logic:
        return 'Logic';
      case QuestionCategory.sequence:
        return 'Sequence';
      case QuestionCategory.generalKnowledge:
        return 'Trivia';
      case QuestionCategory.comparison:
        return 'Compare';
      case QuestionCategory.oddOneOut:
        return 'Odd One Out';
    }
  }
}

/// A single round's question: prompt text plus shuffled answer options.
class Question {
  Question({
    required this.category,
    required this.prompt,
    required this.options,
    required this.correctIndex,
  });

  final QuestionCategory category;
  final String prompt;
  final List<String> options;
  final int correctIndex;

  bool isCorrect(int selectedIndex) => selectedIndex == correctIndex;
}
