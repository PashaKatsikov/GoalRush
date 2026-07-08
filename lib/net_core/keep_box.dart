import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../kinds/pitch_mode.dart';

// ============================================================
// KEEP BOX — persistence (prefs + secure storage)
// ============================================================
// Plain flags live in SharedPreferences.
// URLs (cached / pending) live in the encrypted store.
// Keys are terse and neutral so a prefs dump does not reveal intent.
// ============================================================

class KeepBox {
  KeepBox({FlutterSecureStorage? vault})
      : _vault = vault ?? const FlutterSecureStorage();

  // Neutral, non-descriptive prefs keys.
  static const String _kPitchMode = 'kb_pmode_v1';
  static const String _kUrlExpiry = 'kb_u_exp';
  static const String _kInviteCooldown = 'kb_inv_until';
  static const String _kPushGranted = 'kb_push_ok';
  static const String _kPushOsBlocked = 'kb_push_stop';

  static const String _kCachedUrl = 'kb_url_cache';
  static const String _kPendingPush = 'kb_url_pending';

  late final SharedPreferences _prefs;
  final FlutterSecureStorage _vault;

  Future<void> awaken() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Pitch mode ──
  PitchMode readMode() => PitchMode.fromToken(_prefs.getString(_kPitchMode));

  Future<void> saveMode(PitchMode mode) =>
      _prefs.setString(_kPitchMode, mode.toToken());

  // ── Cached content URL (secure) ──
  Future<String?> readCachedUrl() => _vault.read(key: _kCachedUrl);

  Future<void> saveCachedUrl(String url) =>
      _vault.write(key: _kCachedUrl, value: url);

  // ── URL expiry ──
  int? readUrlExpiry() => _prefs.getInt(_kUrlExpiry);

  Future<void> saveUrlExpiry(int unixSeconds) =>
      _prefs.setInt(_kUrlExpiry, unixSeconds);

  bool isUrlStale() {
    final int? until = readUrlExpiry();
    if (until == null) return true;
    return _nowSeconds() >= until;
  }

  // ── Push permission state ──
  bool isPushGranted() => _prefs.getBool(_kPushGranted) ?? false;

  Future<void> savePushGranted(bool granted) =>
      _prefs.setBool(_kPushGranted, granted);

  /// True after the user denied the OS dialog — Android can never show
  /// the system prompt again, so the invite screen must stop looping.
  bool isPushBlockedByOs() => _prefs.getBool(_kPushOsBlocked) ?? false;

  Future<void> markPushBlockedByOs() =>
      _prefs.setBool(_kPushOsBlocked, true);

  int? readInviteCooldown() => _prefs.getInt(_kInviteCooldown);

  Future<void> saveInviteCooldown(int unixSeconds) =>
      _prefs.setInt(_kInviteCooldown, unixSeconds);

  /// Decides whether to show the push-invite promo before the WebView.
  bool shouldShowPushInvite() {
    if (isPushGranted()) return false;
    if (isPushBlockedByOs()) return false;
    final int? until = readInviteCooldown();
    if (until == null) return true;
    return _nowSeconds() >= until;
  }

  // ── One-shot push URL (secure) ──
  Future<void> stashPendingPush(String? url) async {
    if (url == null) {
      await _vault.delete(key: _kPendingPush);
    } else {
      await _vault.write(key: _kPendingPush, value: url);
    }
  }

  Future<String?> drainPendingPush() async {
    final String? url = await _vault.read(key: _kPendingPush);
    if (url != null) await _vault.delete(key: _kPendingPush);
    return url;
  }

  static int _nowSeconds() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000;
}
