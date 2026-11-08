import 'dart:io';

import 'package:codecore/services/shuffle_plus/dislike_store.dart';
import 'package:codecore/services/shuffle_plus/suggestion_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SuggestionGate gate;

  setUp(() {
    final store = DislikeStore(
      file: () async => File('/nonexistent/dislikes.json'),
    );
    store.blockTrack(
      const DislikedTrack(videoId: 'bad', title: 't', artist: 'a'),
    );
    store.blockArtist(const DislikedArtist(key: 'nope', name: 'Nope'));
    gate = SuggestionGate(store);
  });

  test('a blocked artist is never allowed, even with many seeds on top', () {
    expect(gate.allows('x', 'nope', [1, 1, 1]), isFalse);
  });

  test('an unblocked song is always allowed', () {
    expect(gate.allows('x', 'fine', const []), isTrue);
  });

  test('a blocked song in one seed radio only is not allowed', () {
    expect(gate.allows('bad', 'fine', [1]), isFalse);
  });

  test('a blocked song at row 11 of two seeds is not allowed', () {
    expect(gate.allows('bad', 'fine', [11, 11]), isFalse);
    expect(gate.allows('bad', 'fine', [3, 11]), isFalse);
  });

  test('a blocked song at row 10 of two seeds is allowed', () {
    expect(gate.allows('bad', 'fine', [10, 4]), isTrue);
  });
}
