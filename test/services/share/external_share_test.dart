import 'package:codecore/services/share/external_share.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
