import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../constants/assets.dart';
import '../gray_scenes/offline_pitch_scene.dart';
import '../gray_scenes/pitch_web_scene.dart';
import '../gray_scenes/whistle_invite_scene.dart';
import '../kinds/kickoff_verdict.dart';
import '../kinds/pitch_mode.dart';
import '../net_core/kicktrack_feed.dart';
import '../net_core/keep_box.dart';
import '../net_core/match_gateway.dart';
import '../net_core/net_pulse.dart';
import '../net_core/whistle_alert.dart';
import '../screens/home_screen.dart';
import '../services/game_state_service.dart';

// ============================================================
// KICKOFF PILOT — loading + gray/native decision engine
// ============================================================
// The single startup screen. Shows the Goal-Rush loading artwork with a
// gold progress bar and animated caption while it resolves attribution
// and queries the gate, then routes to either:
//   • PitchWebScene (gray content) or
//   • HomeScreen    (native game — "white" path)
//
// State-machine invariants — see .cursor/rules/android_gray_guide.md
// §"Gray Flow State Machine". Do NOT scatter routing logic elsewhere.
//
// First-launch UX contract — if the device is OFFLINE on the first
// launch (OneLink install with Wi-Fi disabled), the pilot short-circuits
// to OfflinePitchScene BEFORE AppsFlyer ignites. Retry restarts the full
// pipeline. On returning launches with mode == nativeGame we skip the
// network entirely and boot straight into the game (game must run
// without internet).
// ============================================================

class KickoffPilot extends StatefulWidget {
  const KickoffPilot({
    super.key,
    required this.box,
    required this.pulse,
    required this.feed,
    required this.gateway,
    required this.alert,
  });

  final KeepBox box;
  final NetPulse pulse;
  final KicktrackFeed feed;
  final MatchGateway gateway;
  final WhistleAlert alert;

  @override
  State<KickoffPilot> createState() => _KickoffPilotState();
}

class _KickoffPilotState extends State<KickoffPilot>
    with SingleTickerProviderStateMixin {
  double _progress = 0.05;
  bool _routed = false;
  late final AnimationController _dotsCtl;

  @override
  void initState() {
    super.initState();
    _dotsCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    // Every orientation while the loading screen is up — matches whichever
    // way the user holds the phone at first frame.
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    widget.alert.onTokenRotated = _repostOnRotate;
    WidgetsBinding.instance.addPostFrameCallback((_) => _drive());
  }

  @override
  void dispose() {
    widget.alert.onTokenRotated = null;
    _dotsCtl.dispose();
    super.dispose();
  }

  void _lift(double v) {
    if (!mounted) return;
    setState(() => _progress = v);
  }

  Future<void> _drive() async {
    // Push init is cheap and can run in parallel with connectivity.
    unawaited(widget.alert.ignite());
    _lift(0.15);

    switch (widget.box.readMode()) {
      case PitchMode.nativeGame:
        // Native path must be reachable offline — do not touch the network.
        await _toNative(startLift: 0.4);
        break;
      case PitchMode.webContent:
        await _resumeGray();
        break;
      case PitchMode.undecided:
        await _firstLaunch();
        break;
    }
  }

  Future<void> _firstLaunch() async {
    if (!await widget.pulse.isReachable()) {
      _toOffline();
      return;
    }
    _lift(0.35);

    await widget.feed.spark();
    await Future.wait<void>(<Future<void>>[
      widget.feed.awaitInstall(),
      widget.feed.awaitDeepLink(),
    ]);
    _lift(0.7);

    final KickoffVerdict verdict = await _askGate();

    if (verdict.granted && verdict.hasUrl) {
      await widget.box.saveMode(PitchMode.webContent);
      _lift(1.0);
      await _settle();
      _toGray(verdict.contentUrl!);
    } else {
      await widget.box.saveMode(PitchMode.nativeGame);
      await _toNative(startLift: 0.85);
    }
  }

  Future<void> _resumeGray() async {
    if (!await widget.pulse.isReachable()) {
      _lift(1.0);
      _toOffline();
      return;
    }
    _lift(0.35);

    // Wait for ignite() to finish processing getInitialMessage() and write
    // the cold-tap URL to the vault before we try to drain it. The
    // connectivity check above already ran in parallel with ignite(), so
    // awaiting here adds zero extra latency on most devices.
    await widget.alert.coldTapReady;

    // Pending push URL wins over everything else.
    final String? pending = await widget.box.drainPendingPush();
    if (pending != null) {
      _lift(1.0);
      await _settle();
      _toGray(pending);
      return;
    }

    final String? cached = await widget.box.readCachedUrl();

    await widget.feed.spark();
    await Future.wait<void>(<Future<void>>[
      widget.feed.awaitInstall(seconds: 10),
      widget.feed.awaitDeepLink(),
    ]);
    _lift(0.7);

    final KickoffVerdict verdict = await _askGate();
    _lift(1.0);
    await _settle();

    if (verdict.granted && verdict.hasUrl) {
      _toGray(verdict.contentUrl!);
    } else if (cached != null) {
      _toGray(cached);
    } else {
      _toOffline();
    }
  }

  Future<KickoffVerdict> _askGate() async {
    final String locale = Platform.localeName.replaceAll('-', '_');
    final Map<String, dynamic> body = await widget.feed.composeGateBody(
      locale: locale,
      pushToken: widget.alert.token,
    );
    return widget.gateway.query(body);
  }

  void _repostOnRotate(String token) async {
    final String locale = Platform.localeName.replaceAll('-', '_');
    final Map<String, dynamic> body = await widget.feed.composeGateBody(
      locale: locale,
      pushToken: token,
    );
    unawaited(widget.gateway.query(body));
  }

  Future<void> _settle() =>
      Future<void>.delayed(const Duration(milliseconds: 320));

  // ── Routing ──

  Future<void> _toNative({required double startLift}) async {
    _lift(startLift);
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    await _warmGameArt();
    _lift(1.0);
    await _settle();
    if (_routed || !mounted) return;
    _routed = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _warmGameArt() async {
    // Cold-start ANR guard.
    //
    // Empirical: parallel-decoding all 20 cosmetic WEBPs blows past the
    // 100 MB ImageCache budget once decoded to raw ARGB (~10 MB per
    // full-screen image on a 1080p phone) and triggers massive GC +
    // thrashing → the very ANR we were trying to prevent. Instead we
    // warm ONLY the images that appear on the first two frames after
    // the loading screen exits:
    //   • the logo (HomeScreen header)
    //   • the four cosmetics for the CURRENTLY SELECTED loadout
    //     (HomeScreen background and GameScreen pitch/keeper/goal/ball)
    //
    // The Customize screen's horizontal ListView.separated is lazy —
    // only the visible tiles decode, and the user can scroll at reading
    // speed rather than in a single frame, so no cache pressure there.
    //
    // Decodes are sequential to keep peak memory low; each is a fire-
    // and-forget try/catch so a missing asset never blocks routing.
    if (!mounted) return;
    final GameStateService state = context.read<GameStateService>();
    final List<String> warm = <String>[
      AppAssets.logo,
      AppAssets.verticalFields[state.selectedField],
      AppAssets.goalkeepers[state.selectedKeeper],
      AppAssets.goalposts[state.selectedGoalpost],
      AppAssets.balls[state.selectedBall],
    ];
    for (final String path in warm) {
      if (!mounted) return;
      try {
        await precacheImage(AssetImage(path), context);
      } catch (_) {}
    }
  }

  void _toGray(String url) {
    if (_routed || !mounted) return;
    _routed = true;
    if (widget.box.shouldShowPushInvite()) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => WhistleInviteScene(
            box: widget.box,
            alert: widget.alert,
            pulse: widget.pulse,
            contentUrl: url,
          ),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PitchWebScene(
            contentUrl: url,
            box: widget.box,
            alert: widget.alert,
            pulse: widget.pulse,
          ),
        ),
      );
    }
  }

  void _toOffline() {
    if (_routed || !mounted) return;
    _routed = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => OfflinePitchScene(
          onRetryBuild: (_) => KickoffPilot(
            box: widget.box,
            pulse: widget.pulse,
            feed: widget.feed,
            gateway: widget.gateway,
            alert: widget.alert,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final bool landscape = mq.orientation == Orientation.landscape;
    final Size size = mq.size;
    final String bg = landscape
        ? AppAssets.horizontalLoading
        : AppAssets.verticalLoading;

    return IgnorePointer(
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: const Color(0xFF0A1F3D),
          body: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Image.asset(bg, fit: BoxFit.cover),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Colors.transparent, Color(0x88000000)],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: (landscape ? 22 : 56) + mq.padding.bottom,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: landscape ? size.width * 0.20 : 34,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      AnimatedBuilder(
                        animation: _dotsCtl,
                        builder: (BuildContext context, _) {
                          final int n = (_dotsCtl.value * 4).floor() % 4;
                          return Text(
                            'Loading${'.' * n}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                              shadows: <Shadow>[
                                Shadow(
                                  color: Colors.black87,
                                  offset: Offset(0, 2),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _GoldTrack(value: _progress),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoldTrack extends StatelessWidget {
  const _GoldTrack({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 16,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.4),
        ),
        child: AnimatedFractionallySizedBox(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          alignment: Alignment.centerLeft,
          widthFactor: value.clamp(0.0, 1.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFFFFD770), Color(0xFFE0A029)],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFFFFD770).withValues(alpha: 0.7),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
