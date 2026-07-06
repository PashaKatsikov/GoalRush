import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:goalrush/app.dart';
import 'package:goalrush/services/game_state_service.dart';

void main() {
  testWidgets('Loading screen shows the Loading label', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final gameState = await GameStateService.create();

    await tester.pumpWidget(GoalRushApp(gameStateService: gameState));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Loading'), findsOneWidget);
  });
}
