import 'dart:convert';

import '../kinds/kickoff_verdict.dart';
import '../setup/stadium_facade.dart';
import 'geared_client.dart';
import 'keep_box.dart';

// ============================================================
// MATCH GATEWAY — posts the gate body, reads the verdict
// ============================================================
// Sends the merged attribution body to the gate endpoint. On a granted
// verdict the URL + expiry are cached so returning launches can fall
// back to the last-known-good if the network later fails. Missing
// endpoint or any error yields a rejection (→ routes to the game).
// ============================================================

class MatchGateway {
  MatchGateway(this._box);

  final KeepBox _box;

  Future<KickoffVerdict> query(Map<String, dynamic> body) async {
    final String endpoint = PitchOracle.gateEndpoint;
    if (endpoint.isEmpty) {
      return KickoffVerdict.rejected('no-endpoint');
    }

    try {
      final dynamic response = await stadiumWire
          .post(
            Uri.parse(endpoint),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return KickoffVerdict.rejected('http-${response.statusCode}');
      }

      final Map<String, dynamic> map =
          jsonDecode(response.body) as Map<String, dynamic>;
      final KickoffVerdict verdict = KickoffVerdict.fromMap(map);

      if (verdict.granted && verdict.hasUrl) {
        await _box.saveCachedUrl(verdict.contentUrl!);
        if (verdict.expiresAt != null) {
          await _box.saveUrlExpiry(verdict.expiresAt!);
        }
      }
      return verdict;
    } catch (e) {
      return KickoffVerdict.rejected(e.toString());
    }
  }

  Future<String?> cachedUrl() => _box.readCachedUrl();
}
