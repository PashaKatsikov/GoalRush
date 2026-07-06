import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Small pill used in the top HUD and menus to show a labelled numeric stat.
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.value,
    required this.iconColor,
    this.label,
  });

  final IconData icon;
  final String value;
  final String? label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.nightDeep.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
          ),
          if (label != null) ...[
            const SizedBox(width: 3),
            Text(
              label!,
              style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w600, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
