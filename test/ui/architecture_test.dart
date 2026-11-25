// Architecture rule (D-24): lib/ui talks to the data layer only through
// providers (the *Ops in lib/providers), never databaseProvider or
// *RepositoryProvider/*QueriesProvider directly.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _forbidden = RegExp(r'databaseProvider|RepositoryProvider|QueriesProvider');

void main() {
  test('no lib/ui file uses databaseProvider, *RepositoryProvider or *QueriesProvider', () {
    final offenders = [
      for (final f in Directory('lib/ui').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            _forbidden.hasMatch(f.readAsStringSync()))
          f.path.replaceAll(r'\', '/'),
    ]..sort();
    expect(offenders, isEmpty);
  });

  test('no lib/ui file uses PopupMenuButton or showMenu(: menus are sheets', () {
    final menu = RegExp(r'PopupMenuButton|showMenu\(');
    // D-717: the desktop pointer menu lives in this one file.
    const allowed = 'lib/ui/widgets/context_menu.dart';
    final offenders = [
      for (final f in Directory('lib/ui').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            f.path.replaceAll(r'\', '/') != allowed &&
            menu.hasMatch(f.readAsStringSync()))
          f.path.replaceAll(r'\', '/'),
    ]..sort();
    expect(offenders, isEmpty);
  });

  test('no lib/services file imports lib/ui (bar the theme types of two files)', () {
    // Theme types the services read or write: custom themes in a backup, the icon colours.
    const allowed = {
      'lib/services/app_icon/app_icon.dart',
      'lib/services/backup/restore_service.dart',
    };
    final ui = RegExp(r'''^import\s+['"][^'"]*\bui/''', multiLine: true);
    final offenders = [
      for (final f in Directory('lib/services').listSync(recursive: true))
        if (f is File && f.path.endsWith('.dart') && ui.hasMatch(f.readAsStringSync()))
          f.path.replaceAll(r'\', '/'),
    ]..sort();
    expect(offenders, equals(allowed.toList()..sort()));
  });
}
