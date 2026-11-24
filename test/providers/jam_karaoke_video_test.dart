import 'dart:async';

import 'package:codecore/providers/jam_providers.dart';
import 'package:codecore/providers/karaoke_video_cache_providers.dart';
import 'package:codecore/providers/karaoke_video_providers.dart';
import 'package:codecore/services/jam/jam_models.dart';
import 'package:codecore/services/karaoke_video/karaoke_video_cache.dart';
import 'package:codecore/services/karaoke_video/karaoke_video_source.dart';
import 'package:codecore/services/karaoke_video/karaoke_video_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart' show VideoController;

class _Port implements KaraokeVideoPort {
  final calls = <String>[];
  final opened = <String>[];
  final seeks = <Duration>[];
  var disposed = false;
  final _pos = StreamController<Duration>.broadcast();
  @override
  VideoController? get video => null;
  @override
  Stream<String> get errors => const Stream.empty();
  @override
  Stream<Duration> get position => _pos.stream;
  @override
  Future<void> open(String source, Map<String, String> headers) async => opened.add(source);
  @override
  Future<void> firstFrame() async {}
  @override
  Future<void> play() async => calls.add('play');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> seek(Duration pos) async {
    calls.add('seek');
    seeks.add(pos);
    Timer.run(() => _pos.add(pos));
  }

  @override
  Future<void> dispose() async => disposed = true;
}

class _Jam extends JamController {
  @override
  JamUiState build() => const JamUiState(phase: JamPhase.active, role: JamRole.host);
  void set(JamState? s) => state = JamUiState(phase: JamPhase.active, role: JamRole.host, jam: s);
  @override
  int jamNowMs() => 0;
}

class _Cache implements KaraokeVideoCache {
  @override
  dynamic noSuchMethod(Invocation i) {
    if (i.memberName == #cached) return Future<Null>.value(null);
    return null;
  }
}

JamItem _item(int n, String title, {String ref = 'yt:youtube:'}) => JamItem(
  id: n, ownerDeviceId: 'd', title: title, ext: 'm4a', ref: '$ref$n', videoId: 'v$n',
);

JamState _jam(List<JamItem> items, int cur, {bool playing = true}) => JamState(
  items: items, currentIndex: cur, playing: playing, hostDeviceId: 'd', outputDeviceId: 'd',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<_Port> ports;
  late ProviderContainer c;
  late _Jam jam;
  late List<KaraokeVideoState> states;

  setUp(() {
    ports = [];
    states = [];
    c = ProviderContainer(overrides: [
      jamProvider.overrideWith(_Jam.new),
      karaokeVideoCacheProvider.overrideWithValue(_Cache()),
      karaokeVideoSourceProvider.overrideWithValue(
        KaraokeVideoSource((id) async => (url: Uri.parse('https://v/$id'), headers: const <String, String>{}, expires: null)),
      ),
      karaokeVideoPortFactoryProvider.overrideWithValue(() {
        final p = _Port();
        ports.add(p);
        return p;
      }),
    ]);
    jam = c.read(jamProvider.notifier) as _Jam;
  });
  tearDown(() => c.dispose());

  void listen() => c.listen(jamKaraokeVideoProvider, (_, s) => states.add(s), fireImmediately: true);
  KaraokeVideoStatus status() => c.read(jamKaraokeVideoProvider).status;

  Future<void> push(JamState s) async {
    jam.set(s);
    await pumpEventQueue();
  }

  test('loads the video of a karaoke current item', () async {
    listen();
    await push(_jam([_item(1, 'Song karaoke')], 0));
    expect(status(), KaraokeVideoStatus.ready);
    expect(ports.single.opened, ['https://v/v1']);
  });

  test('follows a change of the current item', () async {
    listen();
    final items = [_item(1, 'A karaoke'), _item(2, 'B karaoke')];
    await push(_jam(items, 0));
    await push(_jam(items, 1));
    expect(ports.map((p) => p.opened.single), ['https://v/v1', 'https://v/v2']);
    expect(ports.first.disposed, isTrue);
    expect(status(), KaraokeVideoStatus.ready);
  });

  test('pauses when the Jam pauses', () async {
    listen();
    await push(_jam([_item(1, 'A karaoke')], 0));
    await push(_jam([_item(1, 'A karaoke')], 0, playing: false));
    expect(ports.single.calls.last, 'pause');
  });

  test('a Jam that moves to a non-karaoke item closes the video', () async {
    listen();
    final items = [_item(1, 'A karaoke'), _item(2, 'Plain')];
    await push(_jam(items, 0));
    await push(_jam(items, 1));
    expect(status(), KaraokeVideoStatus.none);
    expect(ports.single.disposed, isTrue);
  });

  test('starts where the Jam is: a guest joining mid-song', () async {
    listen();
    await push(_jam([_item(1, 'A karaoke')], 0).copyWith(positionMs: 90000));
    expect(ports.single.calls, contains('seek'));
    expect(ports.single.seeks.last, const Duration(seconds: 90));
  });
}
