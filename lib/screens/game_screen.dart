import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../constants/assets.dart';
import '../models/question.dart';
import '../models/question_bank.dart';
import '../services/game_state_service.dart';
import '../widgets/answer_button.dart';
import '../widgets/ball_view.dart';
import '../widgets/goalkeeper_view.dart';
import '../widgets/primary_button.dart';
import '../widgets/stat_chip.dart';
import '../widgets/timer_bar.dart';

enum _RoundPhase { question, resolving }

/// Pixel geometry for the goal, keeper and ball, computed fresh from the
/// pitch area's actual constraints so the ball always lands inside the net
/// (never on the posts) and the goal is grounded on the grass instead of
/// floating in the stands.
class _PitchGeometry {
  _PitchGeometry(double w, double h)
      : goalWidth = w * 0.88,
        goalHeight = (w * 0.88) / _goalAspect,
        goalLeft = (w - w * 0.88) / 2,
        goalTop = h * 0.10,
        keeperWidth = w * 0.33,
        ballRestCenter = Offset(w / 2, h * 0.89),
        ballRestSize = w * 0.17,
        ballFlySize = w * 0.10 {
    keeperLeft = (w - keeperWidth) / 2;
    // Feet close to the goal line, standing on the ground instead of
    // hovering mid-air inside the goal mouth.
    keeperTop = goalTop + goalHeight * 0.94 - keeperWidth;
  }

  static const double _goalAspect = 1376 / 768;

  final double goalWidth;
  final double goalHeight;
  final double goalLeft;
  final double goalTop;
  final double keeperWidth;
  late final double keeperLeft;
  late final double keeperTop;
  final Offset ballRestCenter;
  final double ballRestSize;
  final double ballFlySize;

  /// Landing spot inside the net for a scored goal; kept a comfortable
  /// margin away from the posts/crossbar so the ball never overlaps them.
  Offset netTarget(double dir, double magnitude) {
    final halfRangeX = goalWidth * 0.24;
    final x = goalLeft + goalWidth / 2 + dir * halfRangeX * magnitude;
    final y = goalTop + goalHeight * 0.58;
    return Offset(x, y);
  }

  /// Landing spot near the keeper's (already dived) hands for a saved shot.
  /// [diveFraction] is the exact same fractional slide applied to the
  /// keeper sprite itself, so the ball always converges on wherever the
  /// keeper's body actually ends up instead of an independently-tuned spot.
  Offset saveTarget(Offset diveFraction) {
    final x = keeperLeft + keeperWidth / 2 + diveFraction.dx * keeperWidth;
    final y = keeperTop + keeperWidth * 0.36 + diveFraction.dy * keeperWidth;
    return Offset(x, y);
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  final _bank = QuestionBank();
  final _random = Random();
  late final AnimationController _timerController;

  int _round = 1;
  int _score = 0;
  int _streak = 0;
  int _maxStreak = 0;
  int _lives = 3;
  int _goals = 0;
  int _correctAnswers = 0;
  int? _selectedIndex;
  bool _gameOver = false;
  bool _resultSaved = false;

  late Question _question;
  _RoundPhase _phase = _RoundPhase.question;

  // Sign (-1 / 1) and magnitude (0..1) of the current/last kick, used to
  // derive both the ball's flight target and the goalkeeper's dive.
  double _shotDir = 1;
  double _shotMagnitude = 0.7;
  bool? _lastCorrect;

  Offset _keeperSlide = Offset.zero;
  double _keeperRotation = 0.0;
  bool _showBanner = false;
  String _bannerText = '';
  Color _bannerColor = AppColors.success;

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..addStatusListener(_onTimerStatus);
    _question = _bank.next(_round);
    _timerController.forward();
  }

  @override
  void dispose() {
    _timerController.dispose();
    super.dispose();
  }

  void _onTimerStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _phase == _RoundPhase.question) {
      _resolveRound(correct: false, remainingFraction: 0, selectedIndex: null);
    }
  }

  void _onAnswerTap(int index) {
    if (_phase != _RoundPhase.question) return;
    _timerController.stop();
    final remaining = (1 - _timerController.value).clamp(0.0, 1.0);
    final correct = _question.isCorrect(index);
    _resolveRound(correct: correct, remainingFraction: remaining, selectedIndex: index);
  }

  void _resolveRound({required bool correct, required double remainingFraction, int? selectedIndex}) {
    final shotMagnitude = 0.5 + _random.nextDouble() * 0.5;
    final shotSign = _random.nextBool() ? 1.0 : -1.0;
    final diveDir = correct ? -shotSign : shotSign;

    setState(() {
      _phase = _RoundPhase.resolving;
      _selectedIndex = selectedIndex;
      _lastCorrect = correct;
      _shotDir = shotSign;
      _shotMagnitude = shotMagnitude;
      if (correct) {
        _streak++;
        if (_streak > _maxStreak) _maxStreak = _streak;
        _goals++;
        _correctAnswers++;
        final speedBonus = (remainingFraction * 80).round();
        final streakBonus = min(_streak - 1, 10) * 10;
        _score += 100 + speedBonus + streakBonus;
        _bannerText = 'GOAL!';
        _bannerColor = AppColors.success;
      } else {
        _streak = 0;
        _lives = max(0, _lives - 1);
        _bannerText = selectedIndex == null ? "TIME'S UP!" : 'SAVED!';
        _bannerColor = AppColors.danger;
      }
      // Dive distance scales with the shot's magnitude so a "lazy" shot
      // gets a smaller dive and a "power" shot gets a fully stretched one.
      _keeperSlide = Offset(diveDir * (0.20 + 0.55 * shotMagnitude), -0.10);
      _keeperRotation = diveDir * -0.07;
    });

    Future.delayed(const Duration(milliseconds: 380), () {
      if (mounted) setState(() => _showBanner = true);
    });

    Future.delayed(const Duration(milliseconds: 1450), () {
      if (!mounted) return;
      if (_lives <= 0) {
        _endGame();
      } else {
        _nextRound();
      }
    });
  }

  void _nextRound() {
    setState(() {
      _round++;
      _question = _bank.next(_round);
      _phase = _RoundPhase.question;
      _selectedIndex = null;
      _showBanner = false;
      _lastCorrect = null;
      _keeperSlide = Offset.zero;
      _keeperRotation = 0.0;
    });
    _timerController.duration = Duration(
      milliseconds: (QuestionBank.timeForRound(_round) * 1000).round(),
    );
    _timerController.forward(from: 0);
  }

  void _endGame() {
    setState(() => _gameOver = true);
    if (!_resultSaved) {
      _resultSaved = true;
      context.read<GameStateService>().recordGameResult(
            score: _score,
            goals: _goals,
            correctAnswers: _correctAnswers,
            bestStreakThisRun: _maxStreak,
          );
    }
  }

  void _restart() {
    setState(() {
      _round = 1;
      _score = 0;
      _streak = 0;
      _maxStreak = 0;
      _lives = 3;
      _goals = 0;
      _correctAnswers = 0;
      _selectedIndex = null;
      _gameOver = false;
      _resultSaved = false;
      _question = _bank.next(_round);
      _phase = _RoundPhase.question;
      _showBanner = false;
      _lastCorrect = null;
      _keeperSlide = Offset.zero;
      _keeperRotation = 0.0;
    });
    _timerController.duration = const Duration(seconds: 8);
    _timerController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameStateService>();
    final fieldAsset = AppAssets.verticalFields[gameState.selectedField];
    final keeperAsset = AppAssets.goalkeepers[gameState.selectedKeeper];
    final goalpostAsset = AppAssets.goalposts[gameState.selectedGoalpost];
    final ballAsset = AppAssets.balls[gameState.selectedBall];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _confirmExit();
      },
      child: Scaffold(
        backgroundColor: AppColors.night,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(fieldAsset, fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                  stops: const [0.0, 0.25, 0.6, 1.0],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildHud(gameState),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final geo = _PitchGeometry(constraints.maxWidth, constraints.maxHeight);
                        final Offset ballCenter;
                        final double ballSize;
                        if (_phase == _RoundPhase.question || _lastCorrect == null) {
                          ballCenter = geo.ballRestCenter;
                          ballSize = geo.ballRestSize;
                        } else if (_lastCorrect == true) {
                          ballCenter = geo.netTarget(_shotDir, _shotMagnitude);
                          ballSize = geo.ballFlySize;
                        } else {
                          ballCenter = geo.saveTarget(_keeperSlide);
                          ballSize = geo.ballFlySize * 1.15;
                        }

                        return Stack(
                          children: [
                            // Soft grounding shadow so the goal reads as
                            // standing on the pitch rather than floating.
                            Positioned(
                              left: geo.goalLeft + geo.goalWidth * 0.06,
                              top: geo.goalTop + geo.goalHeight * 0.92,
                              width: geo.goalWidth * 0.88,
                              height: geo.goalHeight * 0.22,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  gradient: RadialGradient(
                                    colors: [
                                      Colors.black.withValues(alpha: 0.38),
                                      Colors.black.withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Goalpost + keeper block, grounded on the pitch.
                            Positioned(
                              left: geo.goalLeft,
                              top: geo.goalTop,
                              width: geo.goalWidth,
                              height: geo.goalHeight,
                              child: Image.asset(goalpostAsset, fit: BoxFit.fill),
                            ),
                            Positioned(
                              left: geo.keeperLeft,
                              top: geo.keeperTop,
                              width: geo.keeperWidth,
                              child: GoalkeeperView(
                                assetPath: keeperAsset,
                                slideOffset: _keeperSlide,
                                rotationTurns: _keeperRotation,
                                width: geo.keeperWidth,
                              ),
                            ),
                            // Ball, flying between the penalty spot and the goal.
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 520),
                              curve: Curves.easeOutCubic,
                              left: ballCenter.dx - ballSize / 2,
                              top: ballCenter.dy - ballSize / 2,
                              width: ballSize,
                              height: ballSize,
                              child: BallView(assetPath: ballAsset, size: ballSize),
                            ),
                            if (_showBanner)
                              Align(
                                alignment: const Alignment(0, -0.05),
                                child: _ResultBanner(text: _bannerText, color: _bannerColor),
                              ),
                            Align(
                              alignment: const Alignment(0, 0.98),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: _QuestionCard(
                                  key: ValueKey(_round),
                                  question: _question,
                                  timerController: _timerController,
                                  selectedIndex: _selectedIndex,
                                  resolving: _phase == _RoundPhase.resolving,
                                  onAnswerTap: _onAnswerTap,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (_gameOver)
              _GameOverOverlay(
                score: _score,
                bestScore: gameState.bestScore,
                goals: _goals,
                correctAnswers: _correctAnswers,
                maxStreak: _maxStreak,
                onRetry: _restart,
                onHome: () => Navigator.of(context).pop(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHud(GameStateService gameState) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: _confirmExit,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            style: IconButton.styleFrom(backgroundColor: Colors.black26),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 6,
              runSpacing: 6,
              children: [
                StatChip(icon: Icons.sports_soccer, value: '$_score', iconColor: AppColors.gold),
                StatChip(icon: Icons.emoji_events, value: '${gameState.bestScore}', iconColor: AppColors.gold),
                StatChip(icon: Icons.local_fire_department, value: '$_streak', iconColor: Colors.orangeAccent),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final filled = i < _lives;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Icon(
                        filled ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: filled ? AppColors.danger : Colors.white38,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmExit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Quit match?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Your current run will be lost.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Quit')),
        ],
      ),
    );
    if (shouldExit == true && mounted) {
      Navigator.of(context).pop();
    }
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.elasticOut,
      builder: (context, value, child) => Transform.scale(scale: value, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 18)],
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 26,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    super.key,
    required this.question,
    required this.timerController,
    required this.selectedIndex,
    required this.resolving,
    required this.onAnswerTap,
  });

  final Question question;
  final AnimationController timerController;
  final int? selectedIndex;
  final bool resolving;
  final ValueChanged<int> onAnswerTap;

  AnswerVisualState _stateFor(int index) {
    if (!resolving) return AnswerVisualState.idle;
    if (index == question.correctIndex) return AnswerVisualState.correct;
    if (index == selectedIndex) return AnswerVisualState.wrong;
    return AnswerVisualState.dimmed;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(anim),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(question.prompt),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: AppColors.nightDeep.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.6), width: 1.5),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 14, offset: Offset(0, 6))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    question.category.label.toUpperCase(),
                    style: const TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                  ),
                ),
                const Spacer(),
                Image.asset(AppAssets.goldenQuestionMark, width: 22, height: 22),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              question.prompt,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, height: 1.2),
            ),
            const SizedBox(height: 10),
            AnimatedBuilder(
              animation: timerController,
              builder: (context, _) => TimerBar(remainingFraction: 1 - timerController.value),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.6,
              children: List.generate(question.options.length, (index) {
                final letter = String.fromCharCode(65 + index);
                return AnswerButton(
                  label: question.options[index],
                  letter: letter,
                  state: _stateFor(index),
                  onTap: resolving ? null : () => onAnswerTap(index),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({
    required this.score,
    required this.bestScore,
    required this.goals,
    required this.correctAnswers,
    required this.maxStreak,
    required this.onRetry,
    required this.onHome,
  });

  final int score;
  final int bestScore;
  final int goals;
  final int correctAnswers;
  final int maxStreak;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final isNewBest = score >= bestScore && score > 0;
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.85, end: 1.0),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutBack,
        builder: (context, value, child) => Transform.scale(scale: value, child: child),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.gold, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 24)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(AppAssets.goldenTrophy, width: 84),
              const SizedBox(height: 8),
              Text(
                isNewBest ? 'NEW BEST SCORE!' : 'FULL TIME',
                style: const TextStyle(color: AppColors.gold, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
              const SizedBox(height: 14),
              Text('$score', style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900)),
              const Text('POINTS', style: TextStyle(color: Colors.white54, letterSpacing: 2, fontSize: 12)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatColumn(icon: Icons.sports_soccer, value: '$goals', label: 'Goals'),
                  _StatColumn(icon: Icons.check_circle, value: '$correctAnswers', label: 'Correct'),
                  _StatColumn(icon: Icons.local_fire_department, value: '$maxStreak', label: 'Best streak'),
                ],
              ),
              const SizedBox(height: 22),
              PrimaryButton(label: 'PLAY AGAIN', icon: Icons.replay_rounded, onTap: onRetry),
              const SizedBox(height: 10),
              TextButton(
                onPressed: onHome,
                child: const Text('BACK TO MENU', style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.gold, size: 22),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }
}
