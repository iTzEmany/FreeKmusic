import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/providers/artist_merge_providers.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/services/online/artist_link_resolver.dart';
import 'package:codecore/services/online/ytm_artist.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

YtmArtistRef _a(String id, String name) => YtmArtistRef(id: id, name: name);

void main() {
  late AppDatabase db;
  late ProviderContainer c;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      artistMergeSearchProvider.overrideWithValue(
          (name) async => [_a('1', 'Queen'), _a('2', 'QUEEN'), _a('3', 'Queen Latifah')]),
    ]);
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });

  const me = (id: '1', name: 'Queen');
  Future<YtmArtistRef?> ask(({String id, String name}) who) async {
    await Future<void>.delayed(const Duration(milliseconds: 50)); // let autoDispose and the alias stream settle
    final sub = c.listen(artistMergeSuggestionProvider(who), (_, _) {});
    final v = await c.read(artistMergeSuggestionProvider(who).future);
    sub.close();
    return v;
  }

  test('a same-name profile is suggested', () async {
    expect((await ask(me))?.id, '2');
  });

  test('no suggestion once merged or marked different', () async {
    final repo = c.read(artistAliasRepositoryProvider);
    await repo.merge('1', '2');
    expect(await ask(me), isNull);
    await repo.split('2');
    expect((await ask(me))?.id, '2');
    await repo.markNotSame('2', '1');
    c.read(artistMergeEpochProvider.notifier).bump();
    expect(await ask(me), isNull);
  });

  test('different names only: nothing', () async {
    expect(await ask((id: '9', name: 'Vasco')), isNull);
  });

  test('group follows a merge', () async {
    final sub = c.listen(artistGroupProvider('2'), (_, _) {});
    expect(await c.read(artistGroupProvider('2').future), ['2']);
    await c.read(artistAliasRepositoryProvider).merge('1', '2');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(c.read(artistGroupProvider('2')).value, ['1', '2']);
    sub.close();
  });

  test('an alias opens the main profile through the link resolver', () async {
    await c.read(artistAliasRepositoryProvider).merge('2', '1');
    final r = ArtistLinkResolver(
      library: (_) async => null,
      search: (_) async => [_a('1', 'Queen'), _a('2', 'Queen')],
      aliases: () => c.read(artistAliasRepositoryProvider).allAliases(),
    );
    final link = await r.resolve('Queen');
    expect((link as OnlineArtist).artist.id, '2');
  });

  test('a «diversi» pair saved with another member of the group still holds', () async {
    final repo = c.read(artistAliasRepositoryProvider);
    await repo.merge('1', '5');
    await repo.markNotSame('5', '2');
    expect(await ask(me), isNull);
  });
}
