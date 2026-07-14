import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'services/game_state_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Larger-than-default image cache so the four cosmetic WEBPs precached in
  // LoadingScreen are never evicted before the player reaches GameScreen.
  // The defaults (100 MB / 1000 entries) worked in isolation but left no
  // headroom for the loading-screen backdrop + logo + question mark + trophy
  // sitting alongside, causing an occasional synchronous re-decode on the
  // first Play tap.
  PaintingBinding.instance.imageCache.maximumSize = 200;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 256 << 20;
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final gameStateService = await GameStateService.create();
  runApp(GoalRushApp(gameStateService: gameStateService));
}
