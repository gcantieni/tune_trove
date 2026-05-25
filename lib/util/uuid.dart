import 'dart:math';

String generateUuid() {
  final rng = Random.secure();
  final b = List<int>.generate(16, (_) => rng.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // version 4
  b[8] = (b[8] & 0x3f) | 0x80; // variant
  String hex(List<int> s) =>
      s.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  return '${hex(b.sublist(0, 4))}-${hex(b.sublist(4, 6))}-'
      '${hex(b.sublist(6, 8))}-${hex(b.sublist(8, 10))}-${hex(b.sublist(10))}';
}
