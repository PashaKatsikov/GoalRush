import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:goalrush/net_core/keep_box.dart';
import 'package:goalrush/net_core/kicktrack_feed.dart';
import 'package:goalrush/net_core/match_gateway.dart';
import 'package:goalrush/net_core/net_pulse.dart';
import 'package:goalrush/net_core/whistle_alert.dart';
import 'package:goalrush/services/game_state_service.dart';
import 'package:goalrush/wrap/goal_shell.dart';

void main() {
  testWidgets('Kickoff pilot shows a Loading caption', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final GameStateService gameState = await GameStateService.create();
    final KeepBox box = KeepBox();
    await box.awaken();

    await tester.pumpWidget(GoalShell(
      gameState: gameState,
      box: box,
      pulse: NetPulse(),
      feed: KicktrackFeed(),
      gateway: MatchGateway(box),
      alert: WhistleAlert(box),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Loading'), findsOneWidget);
  });
}
