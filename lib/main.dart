import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'net_core/geared_client.dart';
import 'net_core/keep_box.dart';
import 'net_core/kicktrack_feed.dart';
import 'net_core/match_gateway.dart';
import 'net_core/net_pulse.dart';
import 'net_core/whistle_alert.dart';
import 'services/game_state_service.dart';
import 'wrap/goal_shell.dart';

// ============================================================
// main.dart — bootstrap
// ============================================================
// Wiring order (do not shuffle without reading the guide):
//   1. WidgetsFlutterBinding — required before any plugin call.
//   2. Firebase + AppCheck   — wrapped in try/catch so the app still
//      launches when google-services.json is missing (gray path just
//      falls back to the native game in that case).
//   3. Orientation whitelist — all four while loading + gray path;
//      the native game re-locks to portrait inside KickoffPilot.
//   4. Status bar transparent + light icons — loading art goes
//      edge-to-edge.
//   5. stadiumWire.prepare() — builds the forged device UA used by BOTH
//      the gate HTTP call AND the WebView.
//   6. KeepBox.awaken() — warms SharedPreferences so the pilot can
//      inspect the persisted mode synchronously on its first frame.
//   7. GameStateService.create() — loads white-side game progress.
//   8. Bridges are constructed but not `ignite()`-ed here; WhistleAlert
//      and KicktrackFeed run inside KickoffPilot after the UI is up.
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase + App Check are optional until credentials land.
  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
    );
  } catch (_) {}

  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await stadiumWire.prepare();

  final KeepBox box = KeepBox();
  await box.awaken();

  final GameStateService gameState = await GameStateService.create();

  final NetPulse pulse = NetPulse();
  final KicktrackFeed feed = KicktrackFeed();
  final MatchGateway gateway = MatchGateway(box);
  final WhistleAlert alert = WhistleAlert(box);

  runApp(GoalShell(
    gameState: gameState,
    box: box,
    pulse: pulse,
    feed: feed,
    gateway: gateway,
    alert: alert,
  ));
}
