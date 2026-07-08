import 'package:flutter/material.dart';

import '../constants/assets.dart';
import '../net_core/keep_box.dart';
import '../net_core/net_pulse.dart';
import '../net_core/whistle_alert.dart';
import '../setup/stadium_facade.dart';
import 'pitch_web_scene.dart';
import 'turf_button.dart';

/// Push opt-in promo shown once before the WebView (gray mode) if the
/// permission has not been decided yet. Uses the notification artwork
/// (orientation-aware). Accept triggers the OS permission dialog; Skip
/// arms a 3-day cooldown. Either way the user then continues to the
/// content URL.
///
/// Layout:
///   • Portrait — Accept + Skip stacked vertically, honouring SafeArea.
///   • Landscape — Accept + Skip laid out HORIZONTALLY side-by-side,
///     centered on the physical screen. Horizontal SafeArea is
///     intentionally NOT applied so a camera cutout does not shift
///     the buttons off-center.
class WhistleInviteScene extends StatelessWidget {
  const WhistleInviteScene({
    super.key,
    required this.box,
    required this.alert,
    required this.pulse,
    required this.contentUrl,
  });

  final KeepBox box;
  final WhistleAlert alert;
  final NetPulse pulse;
  final String contentUrl;

  Future<void> _accept(BuildContext context) async {
    final bool granted = await alert.askPermission();
    if (!granted) {
      await box.saveInviteCooldown(_cooldownAt());
    }
    if (context.mounted) _forward(context);
  }

  Future<void> _skip(BuildContext context) async {
    await box.saveInviteCooldown(_cooldownAt());
    if (context.mounted) _forward(context);
  }

  int _cooldownAt() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 +
      PitchOracle.inviteCooldownSeconds;

  void _forward(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PitchWebScene(
          contentUrl: contentUrl,
          box: box,
          alert: alert,
          pulse: pulse,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final Size size = mq.size;
    final bool landscape = mq.orientation == Orientation.landscape;
    final String bg = landscape
        ? AppAssets.horizontalNotifications
        : AppAssets.verticalNotifications;

    // Одинаковые размеры для обеих кнопок в каждой ориентации.
    final double btnWidth = landscape ? size.width * 0.28 : size.width * 0.78;
    const double btnHeight = 56;

    final TurfActionButton acceptBtn = TurfActionButton(
      label: 'ACCEPT',
      icon: Icons.notifications_active_rounded,
      tone: TurfTone.emerald,
      width: btnWidth,
      height: btnHeight,
      onTap: () => _accept(context),
    );

    final TurfActionButton skipBtn = TurfActionButton(
      label: 'SKIP',
      icon: Icons.close_rounded,
      tone: TurfTone.coal,
      width: btnWidth,
      height: btnHeight,
      onTap: () => _skip(context),
    );

    final Widget actions = landscape
        ? Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              acceptBtn,
              const SizedBox(width: 18),
              skipBtn,
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              acceptBtn,
              const SizedBox(height: 14),
              skipBtn,
            ],
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
          Positioned(
            left: 0,
            right: 0,
            bottom: landscape
                ? size.height * 0.09
                : size.height * 0.08 + mq.padding.bottom * 0.4,
            child: Center(child: actions),
          ),
        ],
      ),
    );
  }
}
