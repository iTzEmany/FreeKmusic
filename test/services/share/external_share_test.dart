import 'package:codecore/services/share/external_share.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart' show ShareParams;

void main() {
  test('the m3u8 goes out as audio/x-mpegurl', () async {
    ShareParams? got;
    await SharePlusExternalShare.withRunner((p) async {
      got = p;
      return null;
    }).shareFile('/tmp/x.m3u8');
    expect(got!.files!.single.mimeType, 'audio/x-mpegurl');
  });

  test('on Linux the sheet is never opened: the caller gets an error and copies the text', () {
    var called = false;
    final share = SharePlusExternalShare.withRunner((_) async => called = true, linux: true);
    expect(() => share.shareText('hi'), throwsUnsupportedError);
    expect(called, isFalse);
  });
}
