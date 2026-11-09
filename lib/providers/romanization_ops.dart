import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_providers.dart';

/// What the UI does to the transliteration typed by hand (D-475), as
/// [TrackOps] does for lyrics. Each write returns its undo (null when it did nothing).
class RomanizationOps {
  RomanizationOps(this._ref);

  final Ref _ref;

  ManualRomanizationNotifier get _store =>
      _ref.read(manualRomanizationProvider.notifier);

  /// Saves [raw] (one line per shown line, blank where there is none) for [id];
  /// blank text saves nothing. Leading blank lines are part of the text.
  Future<Future<void> Function()?> save(int id, String raw) async {
    if (raw.trim().isEmpty) return null;
    final before = _ref.read(manualRomanizationProvider)[id];
    await _store.setText(id, raw);
    return () => _store.setText(id, before);
  }

  /// Removes the typed transliteration of [id].
  Future<Future<void> Function()?> delete(int id) async {
    final before = _ref.read(manualRomanizationProvider)[id];
    if (before == null) return null;
    await _store.setText(id, null);
    return () => _store.setText(id, before);
  }
}

final romanizationOpsProvider = Provider<RomanizationOps>(RomanizationOps.new);
