// ignore_for_file: avoid_print
// ============================================================
// MASK PACKER — encodes plaintext secrets into byte arrays
// ============================================================
// Mirrors lib/cipher/mask_engine.dart exactly. Run with:
//   dart run tool/mask_packer.dart
// then paste the printed arrays into lib/setup/veiled_strings.dart.
//
// ⚠️ Always run via `dart run` (native 64-bit ints). Never port
//    this to PowerShell — it overflows at 32 bits and corrupts bytes.
//
// Keep the salt / wheel size in sync with mask_engine.dart.
// ============================================================

const String saltPhrase = 'PxK9!turf-2r7q';
const int wheelSize = 29;

int rotL8(int value, int by) {
  final int v = value & 0xFF;
  final int b = by & 7;
  return ((v << b) | (v >> (8 - b))) & 0xFF;
}

List<int> buildWheel() {
  int hash = 5381;
  for (final int c in saltPhrase.codeUnits) {
    hash = ((hash << 5) + hash + c) & 0xFFFFFFFF;
  }
  int state = hash == 0 ? 0xDEADBEEF : hash;
  final List<int> wheel = List<int>.filled(wheelSize, 0);
  for (int i = 0; i < wheelSize; i++) {
    state = (state * 1664525 + 1013904223) & 0xFFFFFFFF;
    final int mid = (state >> 12) & 0xFF;
    wheel[i] = rotL8(mid, i % 8) & 0xFF;
  }
  return wheel;
}

final List<int> wheel = buildWheel();

List<int> pack(String plain) {
  final List<int> bytes = plain.codeUnits;
  final List<int> out = List<int>.filled(bytes.length, 0);
  for (int i = 0; i < bytes.length; i++) {
    final int salt = wheel[i % wheelSize];
    final int mix = rotL8(salt, i & 7);
    out[i] = (bytes[i] ^ mix ^ ((i * 37) & 0xFF)) & 0xFF;
  }
  return out;
}

void emit(String label, String plain) {
  if (plain.isEmpty) {
    print('// $label — (empty, fill in later)');
    print('const <int>[];\n');
    return;
  }
  final List<int> packed = pack(plain);
  print('// $label  <= "$plain"');
  print('const <int>[${packed.join(', ')}],\n');
}

void main() {
  // ── Fill the plaintext values, run the script, paste into veiled_strings.dart ──
  const String gateEndpoint = 'https://goalrussh.com/config.php';
  const String gcdBase = 'https://gcdsdk.appsflyer.com/install_data/v4.0/';
  const String chromeMajor = '149.0.7412.67';
  const String webkitStamp = '537.36';

  const String attributionKey = 'NBcB4bdZhmkC5JmM8gW2bE'; // AppsFlyer Dev Key
  const String messagingProject = '72550092388'; // Firebase project number

  print('=== Goal Rush mask_packer ===\n');
  emit('gateEndpoint', gateEndpoint);
  emit('gcdBase', gcdBase);
  emit('chromeMajor', chromeMajor);
  emit('webkitStamp', webkitStamp);
  emit('attributionKey', attributionKey);
  emit('messagingProject', messagingProject);
}
