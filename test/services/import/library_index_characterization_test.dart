import 'package:codecore/core/import_row.dart';
import 'package:codecore/services/import/track_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final lib = LibraryIndex(const [
    LibraryEntryLite(id: 1, title: 'Born On The Bayou', artist: 'Creedence Clearwater Revival', durationMs: 315222),
  ]);

  ImportRow row(int ms) => ImportRow(
      index: 0, title: 'Born On The Bayou', artists: const ['Creedence Clearwater Revival'], durationMs: ms);

  test('same song, 84 s apart (live vs studio length): not found today', () {
    // flips in phase 88.1 (D-389)
    expect(lib.find(row(231000)), isNull);
  });

  test('the same song within 5 s is found, and so is one with no known length', () {
    expect(lib.find(row(315222 + 4000))?.id, 1);
    expect(lib.find(const ImportRow(index: 0, title: 'Born On The Bayou', artists: ['Creedence Clearwater Revival']))?.id, 1);
  });
}
