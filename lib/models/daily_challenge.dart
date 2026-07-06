/// Definition of a single repeatable daily task, as described in the game
/// design doc ("ЕЖЕДНЕВНЫЕ ЗАДАНИЯ").
class DailyChallengeDef {
  const DailyChallengeDef({
    required this.id,
    required this.title,
    required this.target,
    required this.reward,
  });

  final String id;
  final String title;
  final int target;

  /// Bonus unlock-points granted once the task is completed for the day.
  final int reward;
}

const List<DailyChallengeDef> kDailyChallenges = [
  DailyChallengeDef(id: 'goals', title: 'Score 10 goals', target: 10, reward: 5),
  DailyChallengeDef(id: 'correct', title: 'Answer 15 questions correctly', target: 15, reward: 5),
  DailyChallengeDef(id: 'streak', title: 'Reach a streak of 8', target: 8, reward: 8),
];
