import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_log.dart';
import 'platform.dart';

Future<String> appSupportDir() async {
  final dir = await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  return dir.path;
}

Future<String> coversDir() async {
  final dir = Directory(p.join(await appSupportDir(), 'covers'));
  await dir.create(recursive: true);
  return dir.path;
}

const _dbName = 'codecore.sqlite';
Future<String>? _dbDir;

/// The folder of the database, resolved once per run: the one source of truth
/// for `driftDatabase` and [databaseFile].
Future<String> databaseDir() => _dbDir ??= resolveDatabaseDir(
  desktop: isDesktop,
  documentsDir: () async => (await getApplicationDocumentsDirectory()).path,
  supportDir: appSupportDir,
);

/// Desktop: `<appSupport>`, after copying a database found in Documents (D-539
/// era, shared with the old Codecore app) when the new folder has none. The old
/// file stays. If the copy fails, this run keeps using Documents (retry next start).
/// Phones: Documents, which is already private to the app.
Future<String> resolveDatabaseDir({
  required bool desktop,
  required Future<String> Function() documentsDir,
  required Future<String> Function() supportDir,
}) async {
  final docs = await documentsDir();
  if (!desktop) return docs;
  final support = await supportDir();
  final target = File(p.join(support, _dbName));
  final old = File(p.join(docs, _dbName));
  if (await target.exists() || !await old.exists()) return support;
  try {
    for (final suffix in const ['', '-wal', '-shm', '-journal']) {
      final src = File(old.path + suffix);
      if (!await src.exists()) continue;
      final tmp = File('${target.path}$suffix.tmp');
      await src.copy(tmp.path);
      // The main file goes last: its presence marks a finished migration.
      if (suffix.isNotEmpty) await tmp.rename(target.path + suffix);
    }
    await File('${target.path}.tmp').rename(target.path);
    AppLog.i('database copied from ${old.path} to ${target.path}');
    return support;
  } on Object catch (e, st) {
    AppLog.e('database migration failed, using ${old.path} this run', e, st);
    return docs;
  }
}

Future<File> databaseFile() async => File(p.join(await databaseDir(), _dbName));

/// Where a backup waits to replace the database at the next start.
Future<Directory> restoreStagingDir() async => Directory(p.join(await appSupportDir(), 'restore'));

/// `<appSupportDir>/theme`: the pictures chosen as a theme background.
Future<Directory> themeDir() async =>
    Directory(p.join(await appSupportDir(), 'theme'));
