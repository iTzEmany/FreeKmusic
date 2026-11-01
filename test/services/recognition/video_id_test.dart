import 'package:codecore/services/recognition/video_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cases = <String, String?>{
    '/m/Adele - Skyfall (Lyrics) [sZrTJesvJeo].mp3': 'sZrTJesvJeo',
    r'C:\m\Higurashi OPENING [Creditless][DVD-Rip] [XgWkIrFQQE0].mp3': 'XgWkIrFQQE0',
    '/m/NEFFEX - Crown [_MTbjHKtobY].m4a': '_MTbjHKtobY',
    'stream:youtube:sZrTJesvJeo': 'sZrTJesvJeo',
    // no id, or brackets that do not hold one
    '/m/Adele - Skyfall.mp3': null,
    '/m/Song [sZrTJesvJe].mp3': null, // 10 characters
    '/m/Song [sZrTJesvJeoo].mp3': null, // 12 characters
    '/m/Song [sZrTJes vJe].mp3': null, // a space
    '/m/Song (sZrTJesvJeo).mp3': null, // not square brackets
    '/m/Song [Remastered!].mp3': null,
    '/m/[sZrTJesvJeo] Song.mp3': null, // not before the extension
    'stream:youtube:short': null,
    'stream:soundcloud:sZrTJesvJeo': null,
  };

  cases.forEach((path, id) {
    test('$path -> $id', () => expect(videoIdOf(path), id));
  });
}
