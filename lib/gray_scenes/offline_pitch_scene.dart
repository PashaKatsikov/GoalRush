import 'package:flutter/material.dart';

import '../constants/assets.dart';
import 'turf_button.dart';

/// Shown when the device has no connection. Uses the project-specific
/// no-Wi-Fi artwork (orientation-aware) with a Retry button.
///
/// Retry rebuilds whatever screen the caller supplies via [onRetryBuild].
///
/// In LANDSCAPE the screen intentionally skips the SafeArea horizontal
/// insets and centers the Retry button on the PHYSICAL screen — per TZ
/// the notch inset must not push the button off-center.
class OfflinePitchScene extends StatefulWidget {
  const OfflinePitchScene({super.key, required this.onRetryBuild});

  final WidgetBuilder onRetryBuild;

  @override
  State<OfflinePitchScene> createState() => _OfflinePitchSceneState();
}

class _OfflinePitchSceneState extends State<OfflinePitchScene> {
  bool _busy = false;

  Future<void> _retry() async {
    if (_busy) return;
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: widget.onRetryBuild),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final bool landscape = mq.orientation == Orientation.landscape;
    final Size size = mq.size;
    final String bg = landscape
        ? AppAssets.horizontalNoWifi
        : AppAssets.verticalNoWifi;

    final Widget retryBtn = _busy
        ? const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3AD26A)),
            ),
          )
        : TurfActionButton(
            label: 'RETRY',
            icon: Icons.refresh_rounded,
            width: landscape ? size.width * 0.34 : size.width * 0.72,
            height: 58,
            onTap: _retry,
          );

    return Scaffold(
      backgroundColor: const Color(0xFF0A1F3D),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            bg,
            fit: BoxFit.cover,
            width: size.width,
            height: size.height,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: <Color>[Colors.transparent, Color(0x99000000)],
              ),
            ),
          ),
          // ─── Retry button ───
          // Landscape: no horizontal SafeArea — the button is centered on
          // the physical screen so a camera cutout on one edge doesn't
          // shift it. Portrait: honour the top SafeArea only via padding
          // on the bottom offset (the button is anchored to the bottom).
          Positioned(
            left: 0,
            right: 0,
            bottom: landscape
                ? size.height * 0.09
                : size.height * 0.10 + mq.padding.bottom * 0.4,
            child: Center(child: retryBtn),
          ),
        ],
      ),
    );
  }
}
