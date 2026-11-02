import 'package:codecore/providers/online_providers.dart';
import 'package:codecore/services/recognition/track_identity.dart';
import 'package:codecore/services/recognition/track_recognizer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fake implements TrackRecognizer {
  final answers = <Recognition?>[];
  var asked = 0;

  @override
  Future<Recognition?> recognizeOnline(String videoId, {cancel}) async => answers[asked++];

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

void main() {
  test('a failed look is asked again, a found one is kept', () async {
    final fake = _Fake()..answers.addAll([null, Recognition(at: 1), Recognition(at: 2)]);
    final c = ProviderContainer(overrides: [trackRecognizerProvider.overrideWithValue(fake)]);
    addTearDown(c.dispose);
    expect(await c.read(onlineRecognitionProvider('v').future), isNull);
    await c.pump();
    expect((await c.read(onlineRecognitionProvider('v').future))!.at, 1);
    await c.pump();
    expect((await c.read(onlineRecognitionProvider('v').future))!.at, 1);
    expect(fake.asked, 2);
  });
}
