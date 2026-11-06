import 'package:codecore/services/online/ytm_artist.dart';
import 'package:codecore/services/online/ytm_artist_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

YtmArtistRef _a(String id, String name) => YtmArtistRef(id: id, name: name);

void main() {
  test('exactly one artist with that name opens by itself, whatever the case', () {
    final pick = pickYtmArtist('PINK FLOYD', [_a('1', 'Pink Floyd Tribute'), _a('2', 'Pink Floyd'), _a('3', 'Roger Waters')]);
    expect(pick, isA<ExactArtist>());
    expect((pick as ExactArtist).artist.id, '2');
  });

  test('two with the same name are offered to choose from, at most three', () {
    final pick = pickYtmArtist('Queen', [_a('1', 'Queen'), _a('2', 'QUEEN'), _a('3', 'Queen Latifah'), _a('4', 'Queen Naija')]);
    expect(pick, isA<ChooseArtist>());
    expect((pick as ChooseArtist).artists.map((a) => a.id), ['1', '2', '3']);
  });

  test('no exact name: the first found are offered; nothing found: none', () {
    expect(pickYtmArtist('Vasco', [_a('1', 'Vasco Rossi')]), isA<ChooseArtist>());
    expect(pickYtmArtist('Vasco', const []), isA<NoArtist>());
  });

  test('a library name with «feat.» finds the main artist', () {
    expect(pickYtmArtist('Björk feat. Thom Yorke', [_a('1', 'Bjork')]), isA<ExactArtist>());
  });

  test('two same-name profiles that are one group open the main one', () {
    final found = [_a('1', 'Queen'), _a('2', 'Queen')];
    final pick = pickYtmArtist('Queen', found, aliases: {'1': '2'});
    expect((pick as ExactArtist).artist.id, '2');
    expect(pickYtmArtist('Queen', found, aliases: {'1': '9'}), isA<ChooseArtist>());
  });
}
