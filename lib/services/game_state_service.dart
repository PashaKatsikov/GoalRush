import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_challenge.dart';

/// Milestones (cumulative goals scored across all games) required to unlock
/// each cosmetic slot. Index 0 is unlocked from the very start.
const List<int> kUnlockThresholds = [0, 15, 40, 80, 150];

/// Loads, persists and exposes every piece of player progress: best score,
/// lifetime stats used to unlock cosmetics, the player's cosmetic choices
/// and today's daily-challenge progress.
class GameStateService extends ChangeNotifier {
  GameStateService(this._prefs) {
    _loadDailyState();
  }

  final SharedPreferences _prefs;

  static Future<GameStateService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return GameStateService(prefs);
  }

  // ---------------------------------------------------------------------
  // Lifetime stats
  // ---------------------------------------------------------------------

  int get bestScore => _prefs.getInt('bestScore') ?? 0;
  int get bestStreak => _prefs.getInt('bestStreak') ?? 0;
  int get totalGoals => _prefs.getInt('totalGoals') ?? 0;
  int get totalCorrect => _prefs.getInt('totalCorrect') ?? 0;
  int get gamesPlayed => _prefs.getInt('gamesPlayed') ?? 0;

  int get selectedField => _prefs.getInt('selectedField') ?? 0;
  int get selectedKeeper => _prefs.getInt('selectedKeeper') ?? 0;
  int get selectedGoalpost => _prefs.getInt('selectedGoalpost') ?? 0;
  int get selectedBall => _prefs.getInt('selectedBall') ?? 0;

  int unlockedCount() {
    var count = 1;
    for (var i = 1; i < kUnlockThresholds.length; i++) {
      if (totalGoals >= kUnlockThresholds[i]) count++;
    }
    return count;
  }

  bool isUnlocked(int index) => totalGoals >= kUnlockThresholds[index];

  Future<void> selectField(int index) async {
    if (!isUnlocked(index)) return;
    await _prefs.setInt('selectedField', index);
    notifyListeners();
  }

  Future<void> selectKeeper(int index) async {
    if (!isUnlocked(index)) return;
    await _prefs.setInt('selectedKeeper', index);
    notifyListeners();
  }

  Future<void> selectGoalpost(int index) async {
    if (!isUnlocked(index)) return;
    await _prefs.setInt('selectedGoalpost', index);
    notifyListeners();
  }

  Future<void> selectBall(int index) async {
    if (!isUnlocked(index)) return;
    await _prefs.setInt('selectedBall', index);
    notifyListeners();
  }

  /// Called once a run ends. Persists the final tally and rolls it into
  /// lifetime + daily progress.
  Future<void> recordGameResult({
    required int score,
    required int goals,
    required int correctAnswers,
    required int bestStreakThisRun,
  }) async {
    _loadDailyState();
    if (score > bestScore) await _prefs.setInt('bestScore', score);
    if (bestStreakThisRun > bestStreak) await _prefs.setInt('bestStreak', bestStreakThisRun);
    await _prefs.setInt('totalGoals', totalGoals + goals);
    await _prefs.setInt('totalCorrect', totalCorrect + correctAnswers);
    await _prefs.setInt('gamesPlayed', gamesPlayed + 1);

    _dailyGoals += goals;
    _dailyCorrect += correctAnswers;
    if (bestStreakThisRun > _dailyStreak) _dailyStreak = bestStreakThisRun;
    await _persistDaily();
    await _grantDailyRewardsIfNeeded();
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Daily challenges
  // ---------------------------------------------------------------------

  late int _dailyGoals;
  late int _dailyCorrect;
  late int _dailyStreak;
  late Set<String> _dailyClaimed;

  int progressFor(String id) {
    switch (id) {
      case 'goals':
        return _dailyGoals;
      case 'correct':
        return _dailyCorrect;
      case 'streak':
        return _dailyStreak;
      default:
        return 0;
    }
  }

  bool isClaimed(String id) => _dailyClaimed.contains(id);

  String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  void _loadDailyState() {
    final storedDay = _prefs.getString('dailyDate');
    if (storedDay != _todayKey) {
      // New day: reset progress.
      _dailyGoals = 0;
      _dailyCorrect = 0;
      _dailyStreak = 0;
      _dailyClaimed = {};
      _prefs.setString('dailyDate', _todayKey);
      _prefs.setInt('dailyGoals', 0);
      _prefs.setInt('dailyCorrect', 0);
      _prefs.setInt('dailyStreak', 0);
      _prefs.setStringList('dailyClaimed', []);
    } else {
      _dailyGoals = _prefs.getInt('dailyGoals') ?? 0;
      _dailyCorrect = _prefs.getInt('dailyCorrect') ?? 0;
      _dailyStreak = _prefs.getInt('dailyStreak') ?? 0;
      _dailyClaimed = (_prefs.getStringList('dailyClaimed') ?? []).toSet();
    }
  }

  Future<void> _persistDaily() async {
    await _prefs.setString('dailyDate', _todayKey);
    await _prefs.setInt('dailyGoals', _dailyGoals);
    await _prefs.setInt('dailyCorrect', _dailyCorrect);
    await _prefs.setInt('dailyStreak', _dailyStreak);
    await _prefs.setStringList('dailyClaimed', _dailyClaimed.toList());
  }

  Future<void> _grantDailyRewardsIfNeeded() async {
    var bonus = 0;
    for (final challenge in kDailyChallenges) {
      if (!_dailyClaimed.contains(challenge.id) && progressFor(challenge.id) >= challenge.target) {
        _dailyClaimed.add(challenge.id);
        bonus += challenge.reward;
      }
    }
    if (bonus > 0) {
      await _prefs.setInt('totalGoals', totalGoals + bonus);
      await _persistDaily();
    }
  }
}
