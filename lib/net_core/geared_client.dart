import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../setup/veiled_strings.dart';

// ============================================================
// GEARED CLIENT — HTTP client that wears a real device UA
// ============================================================
// Outgoing requests (gate POST, GCD refresh, push image fetch) and the
// WebView share one User-Agent string that mimics the actual device's
// Chrome build. The default Dart UA is an instant fingerprint.
//
// The Android UA reports the *Android release version* (e.g. "15"),
// never the SDK level — SDK numbers are a scanner tell.
//
// Chrome / WebKit stamps are decoded from veiled_strings.
// ============================================================

class GearedHttpClient extends http.BaseClient {
  GearedHttpClient({http.Client? inner}) : _inner = inner ?? http.Client();

  final http.Client _inner;
  String _ua = 'Mozilla/5.0';

  String get userAgent => _ua;

  /// Reads device info and assembles the User-Agent. Call once from main().
  Future<void> prepare() async {
    final String chrome = _defaulted(revealChromeStamp(), '132.0.6834.110');
    final String webkit = _defaulted(revealWebkitStamp(), '537.36');

    try {
      final DeviceInfoPlugin probe = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final AndroidDeviceInfo info = await probe.androidInfo;
        // ⚠️ Report the Android RELEASE (e.g. "15"), not the SDK integer.
        // Scanners flag "Android 34" as an implausible OS string.
        final String release = info.version.release.isNotEmpty
            ? info.version.release
            : '14';
        final String build = info.display.isNotEmpty ? info.display : info.id;
        final String brand = info.brand.isNotEmpty ? info.brand : 'samsung';
        final String model = info.model.isNotEmpty ? info.model : 'SM-S931U';

        _ua = 'Mozilla/5.0 (Linux; Android $release; '
            '$brand $model Build/$build) '
            'AppleWebKit/$webkit (KHTML, like Gecko) '
            'Chrome/$chrome Mobile Safari/$webkit';
      } else if (Platform.isIOS) {
        final IosDeviceInfo info = await probe.iosInfo;
        final String os = info.systemVersion.replaceAll('.', '_');
        _ua = 'Mozilla/5.0 (iPhone; CPU iPhone OS $os like Mac OS X) '
            'AppleWebKit/$webkit (KHTML, like Gecko) '
            'Version/${info.systemVersion} Mobile/15E148 Safari/$webkit';
      }
    } catch (_) {
      _ua = 'Mozilla/5.0 (Linux; Android 15; Pixel 8 Build/AP3A.240905.015.A2) '
          'AppleWebKit/$webkit (KHTML, like Gecko) '
          'Chrome/$chrome Mobile Safari/$webkit';
    }
  }

  static String _defaulted(String value, String fallback) =>
      value.isEmpty ? fallback : value;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => _ua);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

/// Shared client used by every networking module.
final GearedHttpClient stadiumWire = GearedHttpClient();
