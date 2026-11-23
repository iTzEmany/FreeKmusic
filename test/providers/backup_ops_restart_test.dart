import 'dart:async';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/providers/app_restart_provider.dart';
import 'package:codecore/providers/backup_ops.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/services/restart/app_restart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _HangingDb extends Fake implements AppDatabase {
  @override
  Future<void> close() => Completer<void>().future;
}

class _Restart implements AppRestart {
  int restarts = 0;
  @override
  Future<bool> restart() async => ++restarts > 0;
  @override
  Future<void> quit() async {}
}

void main() {
  test('a database that never closes does not stop the restart', () async {
    final restart = _Restart();
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(_HangingDb()),
      appRestartProvider.overrideWithValue(restart),
    ]);
    addTearDown(c.dispose);
    final ops = BackupOps(c.read(Provider((ref) => ref)), closeTimeout: const Duration(milliseconds: 20));
    expect(await ops.restartAfterRestore(), isTrue);
    expect(restart.restarts, 1);
  });
}
