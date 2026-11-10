import 'dart:io';

import 'package:path/path.dart' as p;

final _ipv4 = RegExp(r'(?<![\w.])(?:\d{1,3}\.){3}\d{1,3}(?![\w.])');
final _mac = RegExp(r'(?<![\w:])(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}(?![\w:])');
final _ipv6Full =
    RegExp(r'(?<![\w:])(?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}(?![\w:])');
// `::` is required so a clock time such as 13:21:05 is never taken for an address.
final _ipv6Short = RegExp(
    r'(?<![\w:])(?:[0-9a-fA-F]{1,4}(?::[0-9a-fA-F]{1,4}){0,6})?::'
    r'(?:[0-9a-fA-F]{1,4}(?::[0-9a-fA-F]{1,4}){0,6})?(?:%\w+)?(?![\w:])');
final _secretParam =
    RegExp(r'\b((?:file)?token|pin)=[^&\s"]+', caseSensitive: false);
final _secretJson = RegExp(
    r'''("(?:file)?(?:token|pin)"\s*:\s*)"[^"]*"''',
    caseSensitive: false);
final _jamHeader =
    RegExp(r'''(x-jam-file["']?\s*[:=]\s*)[^\s,;"']+''', caseSensitive: false);
final _posixUser = RegExp(r'(/(?:home|Users)/)[^/\s]+');
final _winUser = RegExp(r'([A-Za-z]:[\\/]+Users[\\/]+)[^\\/\s]+');

/// Strips what identifies the person from a log: home folder, user name,
/// addresses, device name, PIN and tokens.
String redactLog(String text, {required String home, String? deviceName}) {
  var s = text;
  if (home.length > 1) {
    s = s.replaceAll(home, '~');
    s = s.replaceAll(home.replaceAll(r'\', '/'), '~');
  }
  s = s.replaceAllMapped(_posixUser, (m) => '${m[1]}<utente>');
  s = s.replaceAllMapped(_winUser, (m) => '${m[1]}<utente>');
  s = s.replaceAllMapped(_secretParam, (m) => '${m[1]}=***');
  s = s.replaceAllMapped(_secretJson, (m) => '${m[1]}"***"');
  s = s.replaceAllMapped(_jamHeader, (m) => '${m[1]}***');
  s = s.replaceAll(_mac, '<mac>');
  s = s.replaceAll(_ipv6Full, '<ip>');
  s = s.replaceAll(_ipv6Short, '<ip>');
  s = s.replaceAllMapped(_ipv4, (m) {
    final parts = m[0]!.split('.').map(int.parse);
    return parts.every((n) => n <= 255) ? '<ip>' : m[0]!;
  });
  final name = deviceName?.trim();
  if (name != null && name.length >= 3) s = s.replaceAll(name, '<dispositivo>');
  return s;
}

/// The two rotated log files in chronological order, redacted, under a header
/// with the app version and platform. Null when there is no log file.
Future<String?> buildLogReport({
  required String supportDir,
  required String home,
  required String appVersion,
  required String platform,
  String? deviceName,
}) async {
  final parts = <String>[];
  for (final name in const ['codecore.log.1', 'codecore.log']) {
    final f = File(p.join(supportDir, name));
    if (await f.exists()) parts.add(await f.readAsString());
  }
  if (parts.isEmpty) return null;
  final body = redactLog(parts.join(), home: home, deviceName: deviceName);
  return 'FreeKmusic $appVersion, $platform\n\n$body';
}
