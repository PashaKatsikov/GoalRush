import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../constants/assets.dart';
import '../services/game_state_service.dart';
import 'home_screen.dart';

/// The very first screen the player sees. Unlike the rest of the (strictly
/// portrait) game, this screen follows whatever orientation the device is
/// currently in, showing the matching art. A left-to-right progress bar
/// stays partially filled while assets warm up and only rushes to 100%
/// right before the app actually hands off to the main menu.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  late final Animation<double> _progress;

  static const _creepDuration = Duration(milliseconds: 1700);
  static const _rushDuration = Duration(milliseconds: 380);

  @override
  void initState() {
    super.initState();
    // Allow every orientation while this screen is up (mirrors the manifest's
    // "unspecified" activity orientation) so it can mirror whatever way the
    // player is holding the phone at launch.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _progressController = AnimationController(
      vsync: this,
      duration: _creepDuration + _rushDuration,
    );
    _progress = TweenSequence<double>([
      TweenSequenceItem(
        weight: _creepDuration.inMilliseconds.toDouble(),
        tween: Tween(begin: 0.0, end: 0.86).chain(CurveTween(curve: Curves.easeOutCubic)),
      ),
      TweenSequenceItem(
        weight: _rushDuration.inMilliseconds.toDouble(),
        tween: Tween(begin: 0.86, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
      ),
    ]).animate(_progressController);

    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final warmUp = _warmUpAssets();
    final animation = _progressController.forward().orCancel.catchError((_) {});
    await Future.wait([warmUp, animation]);
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 180));
    await _launch();
  }

  Future<void> _warmUpAssets() async {
    // Only the assets that the very next two screens (HomeScreen + GameScreen)
    // actually paint on their first frame, in the order they appear. Loading
    // the currently selected cosmetics — not [0] — so returning players don't
    // get a decode stall the moment they hit "Play". Decoding is done one at a
    // time on purpose: parallel `Future.wait` on 5-7 WEBPs was pushing the
    // image cache + IO isolate hard enough during engine warm-up to leave
    // GameScreen's first frame stalled long enough to trigger an ANR on the
    // Play tap.
    final gameState = context.read<GameStateService>();
    final assetsToWarm = <String>[
      AppAssets.logo,
      AppAssets.verticalFields[gameState.selectedField],
      AppAssets.goldenQuestionMark,
      AppAssets.goalposts[gameState.selectedGoalpost],
      AppAssets.goalkeepers[gameState.selectedKeeper],
      AppAssets.balls[gameState.selectedBall],
      AppAssets.goldenTrophy,
    ];
    for (final path in assetsToWarm) {
      if (!mounted) return;
      await precacheImage(AssetImage(path), context);
    }
  }

  Future<void> _launch() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.night,
      body: OrientationBuilder(
        builder: (context, orientation) {
          final isLandscape = orientation == Orientation.landscape;
          final asset = isLandscape ? AppAssets.horizontalLoading : AppAssets.verticalLoading;
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(asset, fit: BoxFit.cover),
              Positioned(
                left: 0,
                right: 0,
                bottom: (isLandscape ? 22 : 56) + MediaQuery.of(context).padding.bottom,
                child: Padding(
                  // Deliberately ignore left/right safe-area insets (e.g. a
                  // sidebar navigation bar in landscape): the art is meant
                  // to be centered on the physical screen, not re-centered
                  // around one-sided system cutouts.
                  padding: EdgeInsets.symmetric(horizontal: isLandscape ? 60 : 36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _LoadingLabel(),
                      const SizedBox(height: 10),
                      AnimatedBuilder(
                        animation: _progress,
                        builder: (context, _) => _ProgressTrack(value: _progress.value),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 14,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.2),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value.clamp(0.0, 1.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.gold, AppColors.goldDeep]),
              boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.8), blurRadius: 10)],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingLabel extends StatefulWidget {
  const _LoadingLabel();

  @override
  State<_LoadingLabel> createState() => _LoadingLabelState();
}

class _LoadingLabelState extends State<_LoadingLabel> {
  late final Timer _timer;
  int _dots = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 420), (_) {
      setState(() => _dots = (_dots + 1) % 4);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      'Loading${'.' * _dots}',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        shadows: [Shadow(color: Colors.black87, blurRadius: 10, offset: Offset(0, 2))],
      ),
    );
  }
}
