import '../../core/app_log.dart';

/// Starts the enrichment of a streamed track once it has played [after]
/// (D-345): fed with every position tick, fires once per listen.
class StreamEnrichTrigger {
  StreamEnrichTrigger(this.enrich, {this.after = const Duration(seconds: 5)});

  final Future<void> Function(int rowId) enrich;
  final Duration after;
  int? _current;
  var _fired = false;
  final _running = <int>{};

  void tick(int? currentId, int? rowId, Duration position) {
    if (currentId != _current) {
      _current = currentId;
      _fired = false; // a new listen is a new attempt
    }
    if (_fired || rowId == null || position < after || !_running.add(rowId)) return;
    _fired = true;
    AppLog.i('stream enrich row=$rowId');
    enrich(rowId)
        .catchError((Object e, StackTrace st) => AppLog.w('stream enrich failed row=$rowId', e, st))
        .whenComplete(() => _running.remove(rowId));
  }
}
