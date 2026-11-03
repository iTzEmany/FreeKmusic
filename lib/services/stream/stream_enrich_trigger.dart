import '../../core/app_log.dart';

/// Starts the enrichment of a streamed track as soon as it has its shadow row
/// (D-351): fed with the current track and its row, fires once per listen.
class StreamEnrichTrigger {
  StreamEnrichTrigger(this.enrich);

  final Future<void> Function(int rowId) enrich;
  int? _current;
  var _fired = false;
  final _running = <int>{};

  void update(int? currentId, int? rowId) {
    if (currentId != _current) {
      _current = currentId;
      _fired = false; // a new listen is a new attempt
    }
    if (_fired || rowId == null || !_running.add(rowId)) return;
    _fired = true;
    AppLog.i('stream enrich row=$rowId');
    Future.sync(() => enrich(rowId))
        .catchError((Object e, StackTrace st) => AppLog.w('stream enrich failed row=$rowId', e, st))
        .whenComplete(() => _running.remove(rowId));
  }
}
