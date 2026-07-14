import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/assets.dart';
import '../widgets/answer_button.dart';
import '../widgets/stat_chip.dart';

/// A one-frame prerender of the GameScreen visual composition.
///
/// This widget exists solely to force Flutter's paint pipeline through the
/// exact same sequence of operations that GameScreen will hit on its first
/// real frame: decoding + GPU-uploading the cosmetic textures, rasterizing
/// the glyphs used in the HUD / question card / answer buttons, and
/// compiling the Impeller pipeline state for the gradient + shadow + blur
/// combinations. Without this pre-warmup, the first "Play" tap on a fresh
/// install stalls the raster thread long enough (~1-3 seconds on mid-range
/// Android devices) that the OS shows an ANR dialog.
///
/// The widget itself is 100% static — no controllers, no animations, no
/// timers — so it can be safely mounted inside LoadingScreen without any
/// side effects. It is placed underneath the loading screen background
/// image and is never visible to the user.
class GameSceneWarmup extends StatelessWidget {
  const GameSceneWarmup({
    super.key,
    required this.selectedField,
    required this.selectedKeeper,
    required this.selectedGoalpost,
    required this.selectedBall,
  });

  final int selectedField;
  final int selectedKeeper;
  final int selectedGoalpost;
  final int selectedBall;

  @override
  Widget build(BuildContext context) {
    final fieldAsset = AppAssets.verticalFields[selectedField];
    final keeperAsset = AppAssets.goalkeepers[selectedKeeper];
    final goalpostAsset = AppAssets.goalposts[selectedGoalpost];
    final ballAsset = AppAssets.balls[selectedBall];

    return IgnorePointer(
      child: Stack(
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
                _HudRow(),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final h = constraints.maxHeight;
                      final goalW = w * 0.88;
                      final goalH = goalW / (1376 / 768);
                      final goalLeft = (w - goalW) / 2;
                      final goalTop = h * 0.10;
                      final keeperW = w * 0.33;
                      final keeperLeft = (w - keeperW) / 2;
                      final keeperTop = goalTop + goalH * 0.94 - keeperW;
                      final ballSize = w * 0.17;
                      final ballCenter = Offset(w / 2, h * 0.89);
                      return Stack(
                        children: [
                          Positioned(
                            left: goalLeft + goalW * 0.06,
                            top: goalTop + goalH * 0.92,
                            width: goalW * 0.88,
                            height: goalH * 0.22,
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
                          Positioned(
                            left: goalLeft,
                            top: goalTop,
                            width: goalW,
                            height: goalH,
                            child: Image.asset(goalpostAsset, fit: BoxFit.fill),
                          ),
                          Positioned(
                            left: keeperLeft,
                            top: keeperTop,
                            width: keeperW,
                            child: Image.asset(keeperAsset, width: keeperW, fit: BoxFit.contain),
                          ),
                          Positioned(
                            left: ballCenter.dx - ballSize / 2,
                            top: ballCenter.dy - ballSize / 2,
                            width: ballSize,
                            height: ballSize,
                            child: Image.asset(ballAsset, fit: BoxFit.contain),
                          ),
                          Align(
                            alignment: const Alignment(0, 0.98),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: _QuestionCardShell(),
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
        ],
      ),
    );
  }
}

class _HudRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () {},
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
                const StatChip(icon: Icons.sports_soccer, value: '0', iconColor: AppColors.gold),
                const StatChip(icon: Icons.emoji_events, value: '0', iconColor: AppColors.gold),
                const StatChip(icon: Icons.local_fire_department, value: '0', iconColor: Colors.orangeAccent),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 1),
                      child: Icon(Icons.favorite, size: 18, color: AppColors.danger),
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
}

class _QuestionCardShell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
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
                child: const Text(
                  'TRIVIA',
                  style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                ),
              ),
              const Spacer(),
              Image.asset(AppAssets.goldenQuestionMark, width: 22, height: 22),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'What is 2 + 2 equal to today?',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, height: 1.2),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 10,
              color: Colors.black.withValues(alpha: 0.35),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    boxShadow: [BoxShadow(color: AppColors.success.withValues(alpha: 0.7), blurRadius: 8)],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.6,
            children: List.generate(4, (index) {
              return AnswerButton(
                label: 'Answer ${index + 1}',
                letter: String.fromCharCode(65 + index),
                state: AnswerVisualState.idle,
                onTap: null,
              );
            }),
          ),
        ],
      ),
    );
  }
}
