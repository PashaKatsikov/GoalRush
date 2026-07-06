import 'package:flutter/material.dart';

/// Renders the goalkeeper sprite and animates dives using simple implicit
/// slide + rotation transforms (no per-frame sprite sheet is available).
class GoalkeeperView extends StatelessWidget {
  const GoalkeeperView({
    super.key,
    required this.assetPath,
    required this.slideOffset,
    required this.rotationTurns,
    required this.width,
  });

  final String assetPath;
  final Offset slideOffset;
  final double rotationTurns;
  final double width;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: slideOffset,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      child: AnimatedRotation(
        turns: rotationTurns,
        duration: const Duration(milliseconds: 520),
        alignment: Alignment.bottomCenter,
        curve: Curves.easeOutCubic,
        child: Image.asset(assetPath, width: width, fit: BoxFit.contain),
      ),
    );
  }
}
