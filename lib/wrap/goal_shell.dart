import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../net_core/keep_box.dart';
import '../net_core/kicktrack_feed.dart';
import '../net_core/match_gateway.dart';
import '../net_core/net_pulse.dart';
import '../net_core/whistle_alert.dart';
import '../services/game_state_service.dart';
import '../setup/stadium_facade.dart';
import 'kickoff_pilot.dart';

/// Root MaterialApp. Owns the long-lived bridges and passes them into
/// the pilot along with the game state service used by the white
/// (native) side of the app.
class GoalShell extends StatelessWidget {
  const GoalShell({
    super.key,
    required this.gameState,
    required this.box,
    required this.pulse,
    required this.feed,
    required this.gateway,
    required this.alert,
  });

  final GameStateService gameState;
  final KeepBox box;
  final NetPulse pulse;
  final KicktrackFeed feed;
  final MatchGateway gateway;
  final WhistleAlert alert;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GameStateService>.value(
      value: gameState,
      child: MaterialApp(
        title: PitchOracle.displayName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: AppColors.night,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.gold,
            brightness: Brightness.dark,
          ),
          fontFamily: 'Roboto',
        ),
        home: KickoffPilot(
          box: box,
          pulse: pulse,
          feed: feed,
          gateway: gateway,
          alert: alert,
        ),
      ),
    );
  }
}
