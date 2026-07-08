import 'legal_links.dart';
import 'veiled_strings.dart';

// ============================================================
// STADIUM FACADE — one place for app-wide constants
// ============================================================
// Identity fields ship as plaintext (they must match the store
// listing anyway). Endpoints / credentials resolve lazily through
// the mask_engine so plaintext never lands in the binary.
// ============================================================

class PitchOracle {
  PitchOracle._();

  // ─────────────────────────────────────────────────────────
  // Identity — must match the store listing exactly.
  // ─────────────────────────────────────────────────────────
  static const String packageId = 'com.goalrush.goalrush';
  static const String marketId = 'com.goalrush.goalrush';
  static const String displayName = 'Goal Rush';

  // iOS App Store numeric id — Android-only project keeps it empty.
  static const String appStoreNumericId = '';

  // ─────────────────────────────────────────────────────────
  // Resolved endpoints / credentials (masked at rest)
  // ─────────────────────────────────────────────────────────
  static String get gateEndpoint => revealGateEndpoint();
  static String get attributionKey => revealAttributionKey();
  static String get messagingProject => revealMessagingProject();

  // ─────────────────────────────────────────────────────────
  // Public URLs
  // ─────────────────────────────────────────────────────────
  static const String privacyUrl = kPrivacyPolicyUrl;
  static const String helpUrl = kSupportUrl;
  static const String homeUrl = kSiteHome;

  // ─────────────────────────────────────────────────────────
  // Timing knobs
  // ─────────────────────────────────────────────────────────
  /// Re-prompt the push invite this many seconds after a Skip (3 days).
  /// Per TZ §"Push permission" — do not lower without approval.
  static const int inviteCooldownSeconds = 3 * 24 * 60 * 60;

  /// Delay before retrying attribution via GCD when the first callback
  /// reports a (possibly false) Organic status.
  static const int organicRetrySeconds = 5;

  // GAME THEME CATEGORY: undecided — the User-Agent ships without the
  // appid/appname suffix per manager instruction. If the partner later
  // requires the suffix (slot theme), append it in geared_client.dart.
}
