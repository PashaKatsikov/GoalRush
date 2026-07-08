import '../cipher/mask_engine.dart';

// ============================================================
// VEILED STRINGS — masked endpoints & credentials
// ============================================================
// Every constant below is a masked byte list produced by
//   `dart run tool/mask_packer.dart`.
// Plaintext must NEVER appear as a string literal in this file.
//
// The gate + GCD base + UA fragments are already packed against the
// production Goal Rush endpoint. The AppsFlyer key and Firebase
// messaging project number are intentionally empty until the manager
// hands them over — the shell degrades gracefully (falls back to the
// native game) as long as they are missing.
// ============================================================

// gateEndpoint <= "https://goalrussh.com/config.php"
const List<int> _packedGate = <int>[
  83, 198, 58, 138, 254, 133, 222, 170, 50, 62, 104, 208, 135, 69, 203, 214,
  92, 188, 1, 130, 113, 206, 37, 199, 165, 181, 54, 134, 42, 38, 204, 139,
];

// gcdBase <= "https://gcdsdk.appsflyer.com/install_data/v4.0/"
const List<int> _packedGcd = <int>[
  83, 198, 58, 138, 254, 133, 222, 170, 50, 50, 109, 207, 145, 91, 150, 196,
  68, 226, 17, 139, 112, 152, 35, 218, 229, 176, 48, 140, 43, 63, 202, 136,
  102, 135, 70, 134, 187, 146, 156, 184, 204, 235, 94, 212, 163, 61, 117,
];

// chromeMajor <= "149.0.7412.67"
const List<int> _packedChrome = <int>[
  10, 134, 119, 212, 189, 145, 198, 177, 100, 99, 39, 138, 194,
];

// webkitStamp <= "537.36"
const List<int> _packedWebkit = <int>[14, 129, 121, 212, 190, 137];

// AppsFlyer Dev Key
const List<int> _packedAttribution = <int>[
  117, 240, 45, 184, 185, 221, 149, 223, 61, 60, 98, 255, 192, 122, 213, 232,
  12, 245, 53, 223, 126, 164,
];

// Firebase project number / sender id
const List<int> _packedMessaging = <int>[
  12, 128, 123, 207, 189, 143, 200, 183, 102, 105, 49,
];

String revealGateEndpoint() => unmask(_packedGate);

String revealAttributionKey() => unmask(_packedAttribution);

String revealMessagingProject() => unmask(_packedMessaging);

String revealChromeStamp() => unmask(_packedChrome);

String revealWebkitStamp() => unmask(_packedWebkit);

/// Builds the GCD refresh URL for the given app + device identifiers.
/// Returns an empty string when the GCD base cannot be revealed —
/// callers must treat that as "GCD refresh not available".
String revealGcdUrl(String appId, String deviceId) {
  final String base = unmask(_packedGcd);
  if (base.isEmpty) return '';
  return '$base$appId?devkey=${revealAttributionKey()}&device_id=$deviceId';
}
