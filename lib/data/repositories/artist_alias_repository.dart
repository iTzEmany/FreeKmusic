import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// Artists with two YouTube Music profiles (D-402, D-414). Every alias points
/// straight at its main profile: there are no chains.
class ArtistAliasRepository {
  ArtistAliasRepository(this._db);

  final AppDatabase _db;

  /// The main profile of [id] ([id] itself when it is not an alias).
  Future<String> mainOf(String id) async {
    final r = await (_db.select(_db.artistAliases)..where((x) => x.aliasId.equals(id))).getSingleOrNull();
    return r?.mainId ?? id;
  }

  /// The main profile first, then its aliases by merge order. One element when [id] is alone.
  Future<List<String>> groupOf(String id) async {
    final main = await mainOf(id);
    final rows = await (_db.select(_db.artistAliases)
          ..where((x) => x.mainId.equals(main))
          ..orderBy([(x) => OrderingTerm.asc(x.createdAt), (x) => OrderingTerm.asc(x.aliasId)]))
        .get();
    return [main, for (final r in rows) r.aliasId];
  }

  /// Every alias -> main pair, for a screen that maps many profiles at once.
  Future<Map<String, String>> allAliases() async =>
      {for (final r in await _db.select(_db.artistAliases).get()) r.aliasId: r.mainId};

  /// Joins the group of [b] to the group of [a]: the main of [a] stays main, [b]'s
  /// main and its aliases become aliases of it. Clears the "different" pairs between the groups.
  /// [createdAt] (a backup's) keeps the group order; default now.
  Future<void> merge(String a, String b, {int? createdAt}) => _db.transaction(() async {
        final main = await mainOf(a);
        final other = await groupOf(b);
        if (other.first == main) return;
        final mine = await groupOf(main);
        await (_db.update(_db.artistAliases)..where((x) => x.mainId.equals(other.first)))
            .write(ArtistAliasesCompanion(mainId: Value(main)));
        await _db.into(_db.artistAliases).insert(ArtistAliasesCompanion.insert(
            aliasId: other.first, mainId: main, createdAt: createdAt == null ? const Value.absent() : Value(createdAt)));
        final all = [...mine, ...other];
        await (_db.delete(_db.artistNotSame)..where((r) => r.a.isIn(all) & r.b.isIn(all))).go();
      });

  /// Takes [id] out of its group. An alias just leaves; when the main leaves, its
  /// oldest alias becomes the main of the rest. A profile alone: nothing happens.
  Future<void> split(String id) => _db.transaction(() async {
        final group = await groupOf(id);
        if (group.length < 2) return;
        if (id != group.first) {
          await (_db.delete(_db.artistAliases)..where((x) => x.aliasId.equals(id))).go();
          return;
        }
        final newMain = group[1];
        final kept = await (_db.select(_db.artistAliases)..where((x) => x.aliasId.isIn(group.skip(2)))).get();
        await (_db.delete(_db.artistAliases)..where((x) => x.mainId.equals(id))).go();
        await (_db.delete(_db.artistAliases)..where((x) => x.aliasId.equals(newMain))).go();
        await _db.batch((b) => b.insertAll(_db.artistAliases, [
              for (final r in kept) ArtistAliasesCompanion.insert(aliasId: r.aliasId, mainId: newMain, createdAt: Value(r.createdAt)),
            ]));
      });

  /// Breaks the whole group of [id] apart and marks every pair «different», so the
  /// detector does not propose the merge again at once.
  Future<void> dissolve(String id) => _db.transaction(() async {
        final group = await groupOf(id);
        for (final x in group.skip(1)) {
          await split(x);
        }
        for (var i = 0; i < group.length; i++) {
          for (var j = i + 1; j < group.length; j++) {
            await markNotSame(group[i], group[j]);
          }
        }
      });

  /// The user said [a] and [b] are different artists. A no-op for profiles
  /// already in the same group (they were merged: they are the same).
  Future<void> markNotSame(String a, String b) async {
    if (a == b || await mainOf(a) == await mainOf(b)) return;
    final (x, y) = _ordered(a, b);
    await _db.into(_db.artistNotSame).insertOnConflictUpdate(ArtistNotSameCompanion.insert(a: x, b: y));
  }

  /// «Rimuovi» on a «different» pair, so the merge can be offered again.
  Future<void> unmarkNotSame(String a, String b) {
    final (x, y) = _ordered(a, b);
    return (_db.delete(_db.artistNotSame)..where((r) => r.a.equals(x) & r.b.equals(y))).go();
  }

  /// The «different» pairs, as ordered [a, b].
  Stream<List<(String, String)>> watchNotSame() =>
      _db.select(_db.artistNotSame).watch().map((rows) => [for (final r in rows) (r.a, r.b)]);

  /// Takes [id] out of its group and marks it «different» from the rest, so the
  /// detector does not offer the merge at once. Returns the group as it was.
  Future<List<String>> separate(String id) => _db.transaction(() async {
        final group = await groupOf(id);
        await split(id);
        for (final x in group) {
          if (x != id) await markNotSame(id, x);
        }
        return group;
      });

  /// Undoes [separate]: [group] is what it returned.
  Future<void> rejoin(List<String> group, String id) =>
      id == group.first ? merge(id, group[1]) : merge(group.first, id);

  Future<bool> isNotSame(String a, String b) async {
    final (x, y) = _ordered(a, b);
    return await (_db.select(_db.artistNotSame)..where((r) => r.a.equals(x) & r.b.equals(y))).getSingleOrNull() != null;
  }

  /// Emits when a profile joins or leaves a group.
  Stream<Map<String, String>> watchAliases() =>
      _db.select(_db.artistAliases).watch().map((rows) => {for (final r in rows) r.aliasId: r.mainId});

  // SQLite's CHECK (a < b) compares UTF-8 bytes, not UTF-16 units.
  static (String, String) _ordered(String a, String b) {
    final x = utf8.encode(a), y = utf8.encode(b);
    for (var i = 0; i < x.length && i < y.length; i++) {
      if (x[i] != y[i]) return x[i] < y[i] ? (a, b) : (b, a);
    }
    return x.length <= y.length ? (a, b) : (b, a);
  }
}
