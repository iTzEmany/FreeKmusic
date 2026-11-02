import 'package:codecore/data/db/app_database.dart' show Track;
import 'package:codecore/services/jam/jam_models.dart';
import 'package:codecore/services/jam/remote/jam_remote_meta.dart';
import 'package:codecore/services/online/curiosity_finder.dart';
import 'package:codecore/services/online/curiosity_service.dart';
import 'package:codecore/services/online/lrclib_client.dart';
import 'package:codecore/services/online/lyrics_chain.dart';
import 'package:codecore/services/online/wikipedia_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const item = JamItem(id: 1, ownerDeviceId: 'p', title: 'T', ext: 'mp3', artist: 'A');

  JamRemoteMeta make(List<bool> limited, void Function() onLyrics) => JamRemoteMeta(
        lyrics: (Track t) async {
          onLyrics();
          return LyricsChainResult(
              lyrics: const LyricsResult(plain: 'parole'), limited: limited.removeAt(0));
        },
        curiosity: (Track t) async => CuriosityLookup(
            pair: CuriosityPair(song: Curiosity('storia', Uri.parse('https://a.b/x'), 'it')),
            artist: 'A',
            outcome: const CuriosityOutcome()),
      );

  test('a complete answer is cached until clear, a limited one is searched again', () async {
    var calls = 0;
    final m = make([true, false, false], () => calls++);
    await m.of(item);
    expect(calls, 1);
    final ok = await m.of(item); // limited before: searched again, now saved
    expect(calls, 2);
    expect((ok.lyricsPlain, ok.curiosities), ('parole', 'storia\nhttps://a.b/x'));
    await m.of(item);
    expect(calls, 2);
    m.clear();
    await m.of(item);
    expect(calls, 3);
  });
}
