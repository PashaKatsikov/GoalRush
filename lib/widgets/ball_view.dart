import 'package:flutter/material.dart';

/// The penalty ball, gently spinning at all times and repositioned by the
/// parent via [AnimatedAlign]/[AnimatedScale] to simulate the kick.
class BallView extends StatefulWidget {
  const BallView({super.key, required this.assetPath, required this.size});

  final String assetPath;
  final double size;

  @override
  State<BallView> createState() => _BallViewState();
}

class _BallViewState extends State<BallView> with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _spinController,
      child: Image.asset(
        widget.assetPath,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
      ),
    );
  }
}
