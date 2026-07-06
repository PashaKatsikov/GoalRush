import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../constants/assets.dart';
import '../services/game_state_service.dart';

class CustomizeScreen extends StatelessWidget {
  const CustomizeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.night,
      appBar: AppBar(
        backgroundColor: AppColors.nightDeep,
        title: const Text('Customize', style: TextStyle(fontWeight: FontWeight.w800)),
        foregroundColor: Colors.white,
      ),
      body: Consumer<GameStateService>(
        builder: (context, gameState, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              _CosmeticSection(
                title: 'Field',
                assets: AppAssets.verticalFields,
                names: AppAssets.fieldNames,
                selected: gameState.selectedField,
                onSelect: gameState.selectField,
                gameState: gameState,
                aspectRatio: 0.62,
              ),
              _CosmeticSection(
                title: 'Goalkeeper',
                assets: AppAssets.goalkeepers,
                names: AppAssets.goalkeeperNames,
                selected: gameState.selectedKeeper,
                onSelect: gameState.selectKeeper,
                gameState: gameState,
                aspectRatio: 1,
                contain: true,
              ),
              _CosmeticSection(
                title: 'Goal',
                assets: AppAssets.goalposts,
                names: AppAssets.goalpostNames,
                selected: gameState.selectedGoalpost,
                onSelect: gameState.selectGoalpost,
                gameState: gameState,
                aspectRatio: 1.3,
                contain: true,
              ),
              _CosmeticSection(
                title: 'Ball',
                assets: AppAssets.balls,
                names: AppAssets.ballNames,
                selected: gameState.selectedBall,
                onSelect: gameState.selectBall,
                gameState: gameState,
                aspectRatio: 1,
                contain: true,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CosmeticSection extends StatelessWidget {
  const _CosmeticSection({
    required this.title,
    required this.assets,
    required this.names,
    required this.selected,
    required this.onSelect,
    required this.gameState,
    required this.aspectRatio,
    this.contain = false,
  });

  final String title;
  final List<String> assets;
  final List<String> names;
  final int selected;
  final ValueChanged<int> onSelect;
  final GameStateService gameState;
  final double aspectRatio;
  final bool contain;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800, letterSpacing: 1, fontSize: 13),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: assets.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final unlocked = gameState.isUnlocked(index);
                final isSelected = selected == index;
                return GestureDetector(
                  onTap: unlocked ? () => onSelect(index) : () => _showLockedMessage(context, index),
                  child: Container(
                    width: 110,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.cardDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.gold : Colors.white.withValues(alpha: 0.12),
                        width: isSelected ? 2.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Opacity(
                                opacity: unlocked ? 1 : 0.28,
                                child: AspectRatio(
                                  aspectRatio: aspectRatio,
                                  child: Image.asset(
                                    assets[index],
                                    fit: contain ? BoxFit.contain : BoxFit.cover,
                                  ),
                                ),
                              ),
                              if (!unlocked)
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.lock_rounded, color: Colors.white70, size: 22),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${kUnlockThresholds[index]} goals',
                                      style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              if (isSelected)
                                const Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          names[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showLockedMessage(BuildContext context, int index) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Score ${kUnlockThresholds[index]} lifetime goals to unlock this!'),
        backgroundColor: AppColors.cardDark,
      ),
    );
  }
}
