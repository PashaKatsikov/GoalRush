import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

// ============================================================
// NET PULSE — connectivity + real DNS reachability
// ============================================================
// [isReachable] combines the adapter state (`connectivity_plus`) with
// a real DNS probe so captive/limited networks are treated as offline.
//
// VPN, Bluetooth and "other" interfaces are treated as real connectivity
// — otherwise a user with an always-on VPN would be stuck on the
// no-Wi-Fi screen (see .cursor/rules/gray_part_pitfalls.md §3).
// ============================================================

class NetPulse {
  NetPulse({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static const Set<ConnectivityResult> _liveAdapters = <ConnectivityResult>{
    ConnectivityResult.wifi,
    ConnectivityResult.mobile,
    ConnectivityResult.ethernet,
    ConnectivityResult.vpn,
    ConnectivityResult.bluetooth,
    ConnectivityResult.other,
  };

  /// Fast-return connectivity check. Probes DNS against a stable public
  /// host to detect captive-portal / limited-network cases.
  Future<bool> isReachable() async {
    final List<ConnectivityResult> states =
        await _connectivity.checkConnectivity();
    if (!states.any(_liveAdapters.contains)) return false;

    try {
      final List<InternetAddress> answer = await InternetAddress.lookup(
        'one.one.one.one',
      ).timeout(const Duration(seconds: 7));
      return answer.isNotEmpty && answer.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Stream<List<ConnectivityResult>> get pulses =>
      _connectivity.onConnectivityChanged;
}
