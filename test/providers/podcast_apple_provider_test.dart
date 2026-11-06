import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/library_providers.dart';
import 'package:codecore/providers/podcast_providers.dart';
import 'package:codecore/services/covers/cover_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the Apple client (cache, rate limit) survives a rebuild of the podcast service', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      podcastsDirProvider.overrideWith((ref) async => '/tmp/none'),
      coverStoreProvider.overrideWithValue(CoverStore(Directory.systemTemp)),
    ]);
    addTearDown(c.dispose);
    final first = c.read(podcastServiceProvider);
    c.invalidate(podcastServiceProvider);
    final second = c.read(podcastServiceProvider);
    expect(identical(first, second), isFalse);
    expect(identical(first.apple, second.apple), isTrue);
  });
}
