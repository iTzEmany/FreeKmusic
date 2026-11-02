import 'dart:async';

import '../../core/clock.dart';
import '../../data/repositories/credits_repository.dart';
import 'enrich_engine.dart';
import 'enrich_parts.dart';
import 'enrich_runner.dart';

export 'enrich_runner.dart' show EnrichRound;

/// Completes the library in the background: one [EnrichRunner] at a time,
/// over the library from the bookmark. The state lives in the database, so a
/// new run simply carries on where the last one stopped.
class EnrichCompleter {
  EnrichCompleter({
    required this.engine,
    required this.repo,
    required this.parts,
    required this.waitIdle,
    this.onProgress,
    this.onWaiting,
    this.loadMark,
    this.saveMark,
    this.recogQuery,
    this.recogNeeds,
    this.yieldPass,
    this.loadPassAfter,
    this.savePassAfter,
    this.passDone,
    this.markPassDone,
    int Function()? nowMs,
  }) : _nowMs = nowMs ?? _clock;

  static int _clock() => nowMs();

  final EnrichEngine engine;
  final CreditsRepository repo;

  /// The parts the switches turn on, read at each chunk.
  final Set<EnrichPart> Function() parts;

  /// Completes when the user leaves the app alone (and no pause is on).
  final Future<void> Function() waitIdle;

  /// After each committed block: tracks complete, tracks in all.
  final void Function(int complete, int total)? onProgress;

  /// See [EnrichRunner.onWaiting].
  final void Function(bool waiting)? onWaiting;

  /// Bookmark: the last track tried, so a run starts after it. Without them
  /// every run starts from the first track.
  final int Function()? loadMark;
  final void Function(int id)? saveMark;

  /// The one-off recognition re-pass (R-176), run after a clean round; without
  /// [recogQuery] there is none. [passDone] says it already ran for this
  /// `kRecogVersion`; [markPassDone] is called when it went through every track.
  final Future<List<int>> Function(int after, int limit)? recogQuery;

  /// `needsRecognition` of one track of the pass.
  final Future<bool> Function(int id)? recogNeeds;

  /// True when something else wants the runner (a new start arrived): the pass stops, its bookmark stays.
  final bool Function()? yieldPass;
  final int Function()? loadPassAfter;
  final void Function(int id)? savePassAfter;
  final bool Function()? passDone;
  final void Function()? markPassDone;
  final int Function() _nowMs;

  /// The re-pass that followed the last [run]; null when none ran.
  EnrichRound? pass;

  /// The last pass stopped for other work and has more to do: run again.
  bool passInterrupted = false;

  /// The re-pass is wired, not done for this version, and a part is on.
  bool get passDue => recogQuery != null && !(passDone?.call() ?? false) && parts().isNotEmpty;

  EnrichRunner? _runner;
  Future<EnrichRound>? _current;

  bool get running => _current != null;

  /// The request in flight is aborted (that track is not tried, the bookmark
  /// stays before it), no track is started, and a wait for the user ends at once.
  void cancel() => _runner?.cancel();

  /// One run until nothing is due, [cancel] or an error, then the re-pass if
  /// it is due. Called during a run it joins it: the same future comes back.
  Future<EnrichRound> run() {
    final current = _current;
    if (current != null) return current;
    return _current = _go().whenComplete(() {
      _current = null;
      _runner = null;
    });
  }

  EnrichRunner _newRunner(EnrichIds ids, {bool progress = true}) => _runner = EnrichRunner(
    engine: engine,
    ids: ids,
    parts: parts,
    waitIdle: waitIdle,
    onProgress: progress ? onProgress : null,
    onWaiting: onWaiting,
    nowMs: _nowMs,
  );

  Future<EnrichRound> _go() async {
    pass = null;
    passInterrupted = false;
    final first = _newRunner(MarkCursor(repo, load: loadMark, save: saveMark));
    final round = await first.run();
    final clean = !(round.failed || round.allRefused || round.limited || round.endedSilent || first.cancelled);
    if (!clean || !passDue) return round;
    final ids = RecogPassIds(
      recogQuery!,
      recogNeeds ?? (_) async => true,
      load: loadPassAfter,
      save: savePassAfter,
      // Only a new start stops the pass; tracks that stay due after a clean round would loop forever.
      interrupt: () async => yieldPass?.call() ?? false,
    );
    final runner = _newRunner(ids, progress: false);
    final r = pass = await runner.run();
    final whole = await ids.complete();
    passInterrupted = ids.interrupted;
    if (whole && !r.failed && !r.limited && !runner.cancelled) {
      savePassAfter?.call(0); // the next version starts from the first track
      markPassDone?.call();
    }
    return round;
  }
}
