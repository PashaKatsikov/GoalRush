import 'dart:typed_data';

// ============================================================
// MASK ENGINE — per-project string masking
// ============================================================
// Sensitive strings (gate endpoint, attribution key, messaging id,
// UA fragments) never appear as plaintext in the binary. They live
// as byte lists produced by tool/mask_packer.dart and are recovered
// at runtime through this module.
//
// The scheme is intentionally different from any other project in
// the fleet — djb2 hash seeds a linear-congruential generator, and
// each output byte gets an additional bit-rotation salt so identical
// plaintext bytes at different offsets encode differently.
//
// ─────────────────────────────────────────────────────────────
// [FINGERPRINT] MANDATORY per-project change
// ─────────────────────────────────────────────────────────────
// Change BOTH values below on every new project:
//   • _saltPhrase — 8..20 char opaque ASCII token. Do not use a
//                   theme-related word (a Goal Rush build with
//                   `goalrush_seed` is trivially greppable).
//   • _wheelSize  — vary between 20 and 40. Cycle length of the
//                   keystream, changes byte-level entropy.
//
// After a change, re-run  `dart run tool/mask_packer.dart`  and
// paste the fresh byte lists into `lib/setup/veiled_strings.dart`.
// ============================================================

const String _saltPhrase = 'PxK9!turf-2r7q';
const int _wheelSize = 29;

Uint8List _spinWheel() {
  // djb2 hash over salt bytes.
  int hash = 5381;
  for (final int c in _saltPhrase.codeUnits) {
    hash = ((hash << 5) + hash + c) & 0xFFFFFFFF;
  }

  // Numerical Recipes LCG (Park & Miller) — different generator from
  // the fleet templates that use xorshift32.
  int state = hash == 0 ? 0xDEADBEEF : hash;
  final Uint8List wheel = Uint8List(_wheelSize);
  for (int i = 0; i < _wheelSize; i++) {
    state = (state * 1664525 + 1013904223) & 0xFFFFFFFF;
    // Take a rotated middle byte — makes the wheel unlike a raw LCG dump.
    final int mid = (state >> 12) & 0xFF;
    wheel[i] = (_rotL8(mid, i % 8)) & 0xFF;
  }
  return wheel;
}

int _rotL8(int value, int by) {
  final int v = value & 0xFF;
  final int b = by & 7;
  return ((v << b) | (v >> (8 - b))) & 0xFF;
}

final Uint8List _wheel = _spinWheel();

/// Decodes a masked byte list back into the original string.
/// Empty input safely returns "" — that is the intentional idle
/// state until real credentials are packed via tool/mask_packer.dart.
String unmask(List<int> masked) {
  if (masked.isEmpty) return '';
  final Uint8List out = Uint8List(masked.length);
  for (int i = 0; i < masked.length; i++) {
    final int salt = _wheel[i % _wheelSize];
    // Additional per-position rotation makes the ciphertext non-periodic
    // even for long stretches of identical plaintext.
    final int mix = _rotL8(salt, i & 7);
    out[i] = (masked[i] ^ mix ^ ((i * 37) & 0xFF)) & 0xFF;
  }
  return String.fromCharCodes(out);
}
