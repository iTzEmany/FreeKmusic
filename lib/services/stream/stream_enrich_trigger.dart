import '../../core/app_log.dart';

/// Starts the enrichment of a streamed track as soon as it has its shadow row
/// (D-351): fed with the current track and its row, fires once per listen.
class StreamEnrichTrigger {
  StreamEnrichTrigger(this.enrich);

  final Future<void> Function(int rowId) enrich;
  int? _current;
  int? _firedRow; // the row launched in this listen
  final _running = <int>{};

  void update(int? currentId, int? rowId) {
    if (currentId != _current) {
      _current = currentId;
      _firedRow = null; // a new listen is a new attempt
    }
    if (rowId == null || rowId == _firedRow || !_running.add(rowId)) return;
    _firedRow = rowId; // a different row in the same listen is launched too
    AppLog.i('stream enrich row=$rowId');
    Future.sync(() => enrich(rowId))
        .catchError((Object e, StackTrace st) => AppLog.w('stream enrich failed row=$rowId', e, st))
        .whenComplete(() => _running.remove(rowId));
  }
}
