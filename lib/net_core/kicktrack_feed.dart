import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

import '../setup/stadium_facade.dart';
import '../setup/veiled_strings.dart';
import 'geared_client.dart';

// ============================================================
// KICKTRACK FEED — AppsFlyer install + deep-link + GCD retry
// ============================================================
// Collects install conversion, deep-link click and app-open attribution
// payloads, then folds them into the gate request body.
//
// Organic false-positive guard: AppsFlyer occasionally reports
// af_status == "Organic" on the first conversion callback for genuinely
// paid installs. In that case we wait a few seconds then re-query the
// GCD endpoint to obtain the real attribution.
//
// When no dev key is configured yet, the feed short-circuits so the
// shell does not stall for 30s before falling back to the game.
// ============================================================

class KicktrackFeed {
  AppsflyerSdk? _sdk;

  Map<String, dynamic>? _installPayload;
  Map<String, dynamic>? _deepLinkPayload;
  Map<String, dynamic>? _appOpenPayload;

  final Completer<Map<String, dynamic>> _installReady =
      Completer<Map<String, dynamic>>();
  final Completer<void> _deepLinkReady = Completer<void>();

  bool _started = false;

  /// Initializes the SDK and wires callbacks. Safe to call more than once.
  Future<void> spark() async {
    if (_started) return;
    _started = true;

    final String devKey = PitchOracle.attributionKey;
    if (devKey.isEmpty) {
      _resolveInstall(<String, dynamic>{});
      _resolveDeepLink();
      return;
    }

    final AppsFlyerOptions options = AppsFlyerOptions(
      afDevKey: devKey,
      appId: PitchOracle.appStoreNumericId,
      showDebug: kDebugMode,
      timeToWaitForATTUserAuthorization: 10,
    );

    final AppsflyerSdk sdk = AppsflyerSdk(options);
    _sdk = sdk;

    sdk.onInstallConversionData((dynamic res) async {
      final Map<String, dynamic> payload = _flatten(res);
      final String? status = payload['af_status']?.toString();
      if (status == 'Organic') {
        await Future<void>.delayed(
          Duration(seconds: PitchOracle.organicRetrySeconds),
        );
        final Map<String, dynamic>? refreshed = await _refreshViaGcd();
        _installPayload = refreshed ?? payload;
      } else {
        _installPayload = payload;
      }
      _resolveInstall(_installPayload ?? <String, dynamic>{});
    });

    sdk.onAppOpenAttribution((dynamic res) {
      _appOpenPayload = _flatten(res);
    });

    sdk.onDeepLinking((DeepLinkResult result) {
      final Map<String, dynamic>? click = result.deepLink?.clickEvent;
      if (click != null) {
        _deepLinkPayload = Map<String, dynamic>.from(click);
      }
      _resolveDeepLink();
    });

    try {
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (_) {
      _resolveInstall(<String, dynamic>{});
      _resolveDeepLink();
    }
  }

  /// Waits up to [seconds] for the install conversion payload.
  Future<Map<String, dynamic>> awaitInstall({int seconds = 30}) {
    return _installReady.future.timeout(
      Duration(seconds: seconds),
      onTimeout: () => <String, dynamic>{},
    );
  }

  /// Waits up to 5s for the deep-link callback.
  Future<void> awaitDeepLink() {
    return _deepLinkReady.future
        .timeout(const Duration(seconds: 5), onTimeout: () {});
  }

  Future<String?> deviceUid() async {
    if (_sdk == null) return null;
    try {
      return await _sdk!.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  /// Builds the merged gate (config) request body.
  Future<Map<String, dynamic>> composeGateBody({
    required String locale,
    String? pushToken,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{};

    if (_installPayload != null) body.addAll(_installPayload!);
    _deepLinkPayload
        ?.forEach((String k, dynamic v) => body.putIfAbsent(k, () => v));
    _appOpenPayload
        ?.forEach((String k, dynamic v) => body.putIfAbsent(k, () => v));

    body['af_id'] = await deviceUid() ?? '';
    body['bundle_id'] = PitchOracle.packageId;
    body['os'] = Platform.isAndroid ? 'Android' : 'iOS';
    body['store_id'] = PitchOracle.marketId;
    body['locale'] = locale;

    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
    }
    final String project = PitchOracle.messagingProject;
    if (project.isNotEmpty) {
      body['firebase_project_id'] = project;
    }

    if (kDebugMode) {
      debugPrint('[KicktrackFeed] gate body: ${jsonEncode(body)}');
    }
    return body;
  }

  Future<Map<String, dynamic>?> _refreshViaGcd() async {
    try {
      final String? uid = await deviceUid();
      if (uid == null) return null;
      final String appId = Platform.isIOS
          ? PitchOracle.appStoreNumericId
          : PitchOracle.packageId;
      final String url = revealGcdUrl(appId, uid);
      if (url.isEmpty) return null;

      final dynamic response = await stadiumWire.get(
        Uri.parse(url),
        headers: <String, String>{
          'authorization': 'Bearer ${PitchOracle.attributionKey}',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  void _resolveInstall(Map<String, dynamic> data) {
    if (!_installReady.isCompleted) _installReady.complete(data);
  }

  void _resolveDeepLink() {
    if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
  }

  static Map<String, dynamic> _flatten(dynamic res) {
    if (res is! Map) return <String, dynamic>{};
    final dynamic inner = res['payload'] ?? res['data'] ?? res;
    if (inner is Map) {
      return inner.map(
        (dynamic k, dynamic v) =>
            MapEntry<String, dynamic>(k.toString(), v),
      );
    }
    return <String, dynamic>{};
  }
}
