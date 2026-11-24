import 'package:codecore/services/update/release_notes.dart';
import 'package:codecore/ui/widgets/release_notes_view.dart';
import 'package:flutter_test/flutter_test.dart';

const _block = '''
## Novità
- evidenza | mic | Video karaoke nella Jam | Metti un video karaoke.
- play | Ascolta subito | I brani partono in streaming.
- rotta senza barre
- home | Solo titolo
- ufo | Icona strana | Finisce sull'icona generica.
## Correzioni
- La musica riparte
-
- Il karaoke riprende
## What's Changed
* feat(136): roba by @x in https://github.com/x/y/pull/1
''';

void main() {
  test('the 1.7.0 body (only «What\'s Changed») gives nothing', () {
    final n = parseReleaseNotes("## What's Changed\n* feat(136): arricchimento by @x in https://x/pull/208\n");
    expect(n.isEmpty, isTrue);
  });

  test('a full block: highlight, news and fixes; broken lines skipped', () {
    final n = parseReleaseNotes(_block);
    expect(n.highlight!.title, 'Video karaoke nella Jam');
    expect(n.highlight!.icon, 'mic');
    expect(n.news.map((e) => e.title), ['Ascolta subito', 'Icona strana']);
    expect(n.fixes, ['La musica riparte', 'Il karaoke riprende']);
  });

  test('only the first «evidenza» is the highlight; null and empty do not throw', () {
    final n = parseReleaseNotes('## Novità\n- evidenza | mic | A | a\n- evidenza | play | B | b');
    expect([n.highlight!.title, n.news.single.title], ['A', 'B']);
    expect(parseReleaseNotes(null).isEmpty, isTrue);
    expect(parseReleaseNotes('').isEmpty, isTrue);
  });

  test('an unknown icon becomes the generic one, and every name has a Material icon', () {
    expect(parseReleaseNotes(_block).news.last.icon, kReleaseNoteGenericIcon);
    for (final name in kReleaseNoteIcons) {
      expect(releaseNoteIcons.containsKey(name), isTrue, reason: name);
    }
  });
}
