import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

enum AnswerVisualState { idle, correct, wrong, dimmed }

/// One tappable answer tile in the 2x2 response grid.
class AnswerButton extends StatelessWidget {
  const AnswerButton({
    super.key,
    required this.label,
    required this.letter,
    required this.state,
    required this.onTap,
  });

  final String label;
  final String letter;
  final AnswerVisualState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color letterBg;
    switch (state) {
      case AnswerVisualState.idle:
        bg = AppColors.cardDark;
        border = Colors.white.withValues(alpha: 0.25);
        letterBg = AppColors.skyBlue;
        break;
      case AnswerVisualState.correct:
        bg = AppColors.success.withValues(alpha: 0.85);
        border = Colors.white;
        letterBg = Colors.white.withValues(alpha: 0.3);
        break;
      case AnswerVisualState.wrong:
        bg = AppColors.danger.withValues(alpha: 0.85);
        border = Colors.white;
        letterBg = Colors.white.withValues(alpha: 0.3);
        break;
      case AnswerVisualState.dimmed:
        bg = AppColors.cardDark.withValues(alpha: 0.4);
        border = Colors.white.withValues(alpha: 0.08);
        letterBg = Colors.white.withValues(alpha: 0.12);
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 2),
        boxShadow: state == AnswerVisualState.correct || state == AnswerVisualState.wrong
            ? [BoxShadow(color: bg.withValues(alpha: 0.6), blurRadius: 12, offset: const Offset(0, 4))]
            : [const BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: letterBg,
                  child: Text(
                    letter,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
