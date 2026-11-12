import 'dart:convert';
import 'dart:io';

import '../../core/app_log.dart';

/// Paths of downloaded files whose tags are not written yet, kept on disk so a
/// killed app can finish them at the next start. A path leaves the set when
/// its tagging ends (written or refused), so a failure never loops.
class PendingTags {
  PendingTags(this._file);

  final Future<File> Function() _file;
  Set<String>? _paths;
  // Saves run one after another: two writers on one file would interleave.
  Future<void> _writing = Future.value();

  Future<Set<String>> _load() async {
    if (_paths != null) return _paths!;
    final s = <String>{};
    try {
      final f = await _file();
      if (await f.exists()) {
        s.addAll((jsonDecode(await f.readAsString()) as List).map((e) => '$e'));
      }
    } on Object catch (e, st) {
      AppLog.w('pending tags unreadable', e, st);
    }
    return _paths ??= s;
  }

  Future<List<String>> paths() async => (await _load()).toList();

  Future<void> add(String path) async {
    if ((await _load()).add(path)) await _save();
  }

  Future<void> remove(String path) async {
    if ((await _load()).remove(path)) await _save();
  }

  Future<void> _save() => _writing = _writing.then((_) => _write());

  Future<void> _write() async {
    try {
      final f = await _file();
      await f.parent.create(recursive: true);
      // Written aside and renamed: a kill mid-write never leaves half a file.
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode(_paths!.toList()));
      await tmp.rename(f.path);
    } on Object catch (e, st) {
      AppLog.w('pending tags write failed', e, st);
    }
  }
}
