import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'constants/app_colors.dart';
import 'screens/loading_screen.dart';
import 'services/game_state_service.dart';

class GoalRushApp extends StatelessWidget {
  const GoalRushApp({super.key, required this.gameStateService});

  final GameStateService gameStateService;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GameStateService>.value(
      value: gameStateService,
      child: MaterialApp(
        title: 'Goal Rush',
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
        home: const LoadingScreen(),
      ),
    );
  }
}
