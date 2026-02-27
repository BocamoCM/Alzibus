import 'dart:io';

void main(List<String> args) {
  if (args.length < 2) {
    print('Usage: dart compare_nfc.dart <file1> <file2>');
    return;
  }

  final file1 = File(args[0]);
  final file2 = File(args[1]);

  final blocks1 = parseBlocks(file1.readAsLinesSync());
  final blocks2 = parseBlocks(file2.readAsLinesSync());

  print('Comparing ${args[0]} vs ${args[1]}');
  print('-----------------------------------------');

  for (int i = 0; i < 64; i++) {
    final b1 = blocks1[i] ?? [];
    final b2 = blocks2[i] ?? [];

    if (!listEquals(b1, b2)) {
      print('Block $i:');
      print('  File 1: ${formatBytes(b1)}');
      print('  File 2: ${formatBytes(b2)}');
      
      final diffs = <String>[];
      for (int j = 0; j < 16; j++) {
        if (j < b1.length && j < b2.length && b1[j] != b2[j]) {
          diffs.add('Byte $j: 0x${b1[j].toRadixString(16).padLeft(2, '0')} -> 0x${b2[j].toRadixString(16).padLeft(2, '0')} (${b1[j]} -> ${b2[j]})');
        }
      }
      print('  Diffs: ${diffs.join(', ')}');
    }
  }
}

Map<int, List<int>> parseBlocks(List<String> lines) {
  final blocks = <int, List<int>>{};
  for (final line in lines) {
    if (line.startsWith('Block ')) {
      final match = RegExp(r'Block (\d+): (.+)').firstMatch(line);
      if (match != null) {
        final index = int.parse(match.group(1)!);
        final bytes = match.group(2)!.split(' ')
            .where((h) => h.isNotEmpty && h != '??')
            .map((h) => int.parse(h, radix: 16))
            .toList();
        blocks[index] = bytes;
      }
    }
  }
  return blocks;
}

String formatBytes(List<int> bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
}

bool listEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
