import 'dart:io';

import 'package:codecore/core/log_export.dart';
import 'package:flutter_test/flutter_test.dart';

String r(String s, {String? device}) =>
    redactLog(s, home: '/home/emanuele', deviceName: device);

void main() {
  test('home folder becomes ~ and user names disappear', () {
    expect(r('x /home/emanuele/Music/a.mp3 y'), 'x ~/Music/a.mp3 y');
    expect(r('/home/other/Music/a.mp3'), '/home/<utente>/Music/a.mp3');
    expect(redactLog(r'open C:\Users\Marco\Music\a.mp3', home: '/nope'),
        r'open C:\Users\<utente>\Music\a.mp3');
    expect(redactLog('/Users/marco/x', home: '/nope'), '/Users/<utente>/x');
  });

  test('IPv4 and IPv6 addresses', () {
    expect(r('offer from 192.168.1.23:8080 ok'), 'offer from <ip>:8080 ok');
    expect(r('fe80::1c2b:3d4e:5f60:7182%wlan0 up'), '<ip> up');
    expect(r('2001:0db8:85a3:0000:0000:8a2e:0370:7334'), '<ip>');
    expect(r('bind ::1'), 'bind <ip>');
  });

  test('timestamps, versions and yt-dlp versions are left alone', () {
    const line = '2026-10-16T13:21:05.123 [I] yt-dlp 2026.08.19 app 1.1.0+2';
    expect(r(line), line);
    expect(r('999.1.1.1 stays'), '999.1.1.1 stays');
  });

  test('MAC addresses', () {
    expect(r('wlan aa:bb:cc:dd:ee:ff'), 'wlan <mac>');
  });

  test('device name', () {
    expect(r("sent to Marco's Pixel", device: "Marco's Pixel"),
        'sent to <dispositivo>');
    expect(r('a b', device: 'a'), 'a b', reason: 'too short to be a name');
  });

  test('PIN and tokens in URLs, JSON and headers', () {
    expect(r('GET /hello?pin=123456&x=1'), 'GET /hello?pin=***&x=1');
    expect(r('/file/3?token=abcDEF12'), '/file/3?token=***');
    expect(r('{"token":"abc","fileToken": "zzz","a":1}'),
        '{"token":"***","fileToken": "***","a":1}');
    expect(r('x-jam-file: s3cr3t'), 'x-jam-file: ***');
    expect(r('headers {x-jam-file: s3cr3t, host: a}'),
        'headers {x-jam-file: ***, host: a}');
  });

  test('buildLogReport joins the rotated files in order and redacts', () async {
    final dir = Directory.systemTemp.createTempSync('cc_log');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/codecore.log.1').writeAsStringSync('old /home/emanuele/a\n');
    File('${dir.path}/codecore.log').writeAsStringSync('new 10.0.0.5\n');
    final out = await buildLogReport(
        supportDir: dir.path,
        home: '/home/emanuele',
        appVersion: '1.1.0',
        platform: 'linux');
    expect(out, 'FreeKmusic 1.1.0, linux\n\nold ~/a\nnew <ip>\n');
    expect(
        await buildLogReport(
            supportDir: '${dir.path}/none',
            home: '/h',
            appVersion: '1',
            platform: 'x'),
        isNull);
  });
}
