import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A theme can be any colours the user picks, so no widget may hold a colour
/// of its own: they all come from `context.cc` (lib/ui/theme/tokens.dart).
void main() {
  // Files that must keep a fixed colour, and why.
  const allowed = {
    // A QR code is only read reliably as dark on white, in any theme.
    'lib/ui/screens/share/send_tab.dart',
    'lib/ui/screens/jam/jam_remote_sheets.dart',
    // The picker paints the hue/saturation/brightness gradients of the colour being chosen.
    'lib/ui/widgets/color_picker.dart',
  };
  final literal = RegExp(r'Color\(\s*0x|Colors\.(?!transparent\b)[a-zA-Z]');

  test('no hex colour and no named material colour outside lib/ui/theme (bar a few justified files)', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      final path = f.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart') ||
          path.startsWith('lib/ui/theme/') ||
          path.startsWith('lib/l10n/') ||
          allowed.contains(path)) {
        continue;
      }
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].split('//').first;
        if (literal.hasMatch(code)) offenders.add('$path:${i + 1}: ${lines[i].trim()}');
      }
    }
    expect(offenders, isEmpty, reason: 'use context.cc instead:\n${offenders.join('\n')}');
  });

  test('the allowed files really still need their exception', () {
    for (final path in allowed) {
      expect(File(path).readAsStringSync(), matches(literal), reason: '$path no longer needs to be allowed');
    }
  });
}
