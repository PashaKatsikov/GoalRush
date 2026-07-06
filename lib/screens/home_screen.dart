import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../constants/assets.dart';
import '../models/daily_challenge.dart';
import '../services/game_state_service.dart';
import '../widgets/primary_button.dart';
import '../widgets/stat_chip.dart';
import 'customize_screen.dart';
import 'game_screen.dart';
import 'webview_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const String privacyUrl = 'https://goalrussh.com/privacy-policy.html';
  static const String supportUrl = 'https://goalrussh.com/support.html';

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameStateService>();
    final fieldAsset = AppAssets.verticalFields[gameState.selectedField];

    return Scaffold(
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
                  AppColors.nightDeep.withValues(alpha: 0.55),
                  AppColors.nightDeep.withValues(alpha: 0.75),
                  AppColors.nightDeep.withValues(alpha: 0.95),
                ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Image.asset(AppAssets.logo, width: 220),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      StatChip(icon: Icons.emoji_events, value: '${gameState.bestScore}', label: 'BEST', iconColor: AppColors.gold),
                      const SizedBox(width: 10),
                      StatChip(icon: Icons.local_fire_department, value: '${gameState.bestStreak}', label: 'STREAK', iconColor: Colors.orangeAccent),
                      const SizedBox(width: 10),
                      StatChip(icon: Icons.sports_soccer, value: '${gameState.totalGoals}', label: 'GOALS', iconColor: AppColors.skyBlue),
                    ],
                  ),
                  const SizedBox(height: 26),
                  PrimaryButton(
                    label: 'PLAY',
                    icon: Icons.play_arrow_rounded,
                    height: 64,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const GameScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: 'CUSTOMIZE',
                    icon: Icons.checkroom_rounded,
                    colors: const [AppColors.skyBlue, Color(0xFF1B4FA0)],
                    textColor: Colors.white,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CustomizeScreen()),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _DailyChallengesCard(gameState: gameState),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SecondaryButton(
                        label: 'Privacy Policy',
                        icon: Icons.privacy_tip_outlined,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const WebViewScreen(title: 'Privacy Policy', url: privacyUrl),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SecondaryButton(
                        label: 'Support',
                        icon: Icons.support_agent_outlined,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const WebViewScreen(title: 'Support', url: supportUrl),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyChallengesCard extends StatelessWidget {
  const _DailyChallengesCard({required this.gameState});

  final GameStateService gameState;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.calendar_today_rounded, color: AppColors.gold, size: 18),
              SizedBox(width: 8),
              Text(
                'DAILY CHALLENGES',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final challenge in kDailyChallenges) ...[
            _ChallengeRow(challenge: challenge, gameState: gameState),
            if (challenge != kDailyChallenges.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ChallengeRow extends StatelessWidget {
  const _ChallengeRow({required this.challenge, required this.gameState});

  final DailyChallengeDef challenge;
  final GameStateService gameState;

  @override
  Widget build(BuildContext context) {
    final progress = gameState.progressFor(challenge.id);
    final done = gameState.isClaimed(challenge.id) || progress >= challenge.target;
    final fraction = (progress / challenge.target).clamp(0.0, 1.0);
    return Row(
      children: [
        Icon(
          done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          color: done ? AppColors.success : Colors.white38,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                challenge.title,
                style: TextStyle(
                  color: done ? Colors.white70 : Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  decoration: done ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 6,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(done ? AppColors.success : AppColors.gold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${progress.clamp(0, challenge.target)}/${challenge.target}',
          style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
