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

  test('a failing share_plus call becomes ExternalShareUnavailable', () {
    final share = SharePlusExternalShare.withRunner(
      (_) async => throw UnimplementedError('no share sheet'),
    );
    expect(
      () => share.shareText('hi'),
      throwsA(isA<ExternalShareUnavailable>()),
    );
    expect(
      () => share.shareFile('/tmp/x.m3u8'),
      throwsA(isA<ExternalShareUnavailable>()),
    );
  });
}
