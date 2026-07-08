import 'package:flutter/material.dart';

/// Buttons for the gray (shell) screens: notification permission,
/// no-internet, etc. Design deliberately differs from the SkyPill
/// variant used in template fleet projects — a rectangular emerald-and-
/// gold "boot studs" pill with an angular top highlight, chunky border
/// and press-down offset.
class TurfActionButton extends StatefulWidget {
  const TurfActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.width,
    this.height = 58,
    this.tone = TurfTone.emerald,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final double? width;
  final double height;
  final TurfTone tone;

  @override
  State<TurfActionButton> createState() => _TurfActionButtonState();
}

enum TurfTone { emerald, coal, gold }

class _TurfActionButtonState extends State<TurfActionButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  List<Color> _colors() {
    switch (widget.tone) {
      case TurfTone.emerald:
        return const <Color>[Color(0xFF3AD26A), Color(0xFF128A3D)];
      case TurfTone.gold:
        return const <Color>[Color(0xFFFFD770), Color(0xFFE0A029)];
      case TurfTone.coal:
        return const <Color>[Color(0xFF3B3F49), Color(0xFF1B1E24)];
    }
  }

  Color _shadowTint() {
    switch (widget.tone) {
      case TurfTone.emerald:
        return const Color(0xFF083B1E);
      case TurfTone.gold:
        return const Color(0xFF6E4A0D);
      case TurfTone.coal:
        return const Color(0xFF000000);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Color> colors = _colors();
    final Color shadow = _shadowTint();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        width: widget.width,
        height: widget.height,
        transform: Matrix4.translationValues(0, _pressed ? 4 : 0, 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withValues(alpha: 0.55), width: 2.2),
          boxShadow: _pressed
              ? <BoxShadow>[
                  BoxShadow(
                    color: shadow.withValues(alpha: 0.45),
                    offset: const Offset(0, 2),
                    blurRadius: 0,
                  ),
                ]
              : <BoxShadow>[
                  BoxShadow(
                    color: shadow,
                    offset: const Offset(0, 6),
                    blurRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    offset: const Offset(0, 8),
                    blurRadius: 14,
                  ),
                ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Angular top highlight — the "studs sheen".
            Positioned(
              top: 3,
              left: 6,
              right: 6,
              height: widget.height * 0.32,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.white.withValues(alpha: 0.35),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  if (widget.icon != null) ...<Widget>[
                    Icon(widget.icon, size: 22, color: Colors.white),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      height: 1.0,
                      shadows: <Shadow>[
                        Shadow(
                          color: Color(0xAA000000),
                          offset: Offset(0, 2),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
