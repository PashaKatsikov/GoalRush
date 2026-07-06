import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Horizontal shrinking countdown bar shown under the question prompt.
class TimerBar extends StatelessWidget {
  const TimerBar({super.key, required this.remainingFraction});

  /// 1.0 = full time left, 0.0 = expired.
  final double remainingFraction;

  Color get _color {
    if (remainingFraction > 0.5) return AppColors.success;
    if (remainingFraction > 0.22) return AppColors.gold;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 10,
        color: Colors.black.withValues(alpha: 0.35),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: remainingFraction.clamp(0.0, 1.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _color,
              boxShadow: [BoxShadow(color: _color.withValues(alpha: 0.7), blurRadius: 8)],
            ),
          ),
        ),
      ),
    );
  }
}
