import 'package:codecore/providers/jam_providers.dart';
import 'package:codecore/providers/shuffle_plus_providers.dart';
import 'package:codecore/services/shuffle_plus/shuffle_plus_controller.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// Only what the provider reads: the engine's `pending`.
class _Engine implements ShufflePlusController {
  final _pending = ValueNotifier(ShufflePlusPending.none);

  @override
  ValueNotifier<ShufflePlusPending> get pending => _pending;

  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _ActiveJam extends JamController {
  @override
  JamUiState build() => const JamUiState(phase: JamPhase.active, role: JamRole.host);
}

class _Mode extends Notifier<ShuffleMode> {
  @override
  ShuffleMode build() => ShuffleMode.shuffle;

  void set(ShuffleMode m) => state = m;
}

final _modeProvider = NotifierProvider<_Mode, ShuffleMode>(_Mode.new);

void main() {
  test('the provider follows the engine\'s pending state, and stops when it is disposed', () async {
    final engine = _Engine();
    final container = ProviderContainer(overrides: [
      shufflePlusProvider.overrideWith((ref) async => engine),
      shuffleModeProvider.overrideWithValue(ShuffleMode.plus),
    ]);
    final seen = <ShufflePlusPending>[];
    container.listen(shufflePlusPendingProvider, (_, next) => seen.add(next));
    await container.read(shufflePlusProvider.future);
    expect(container.read(shufflePlusPendingProvider), ShufflePlusPending.none);

    engine.pending.value = const ShufflePlusPending(incoming: 3);
    expect(container.read(shufflePlusPendingProvider).incoming, 3);
    engine.pending.value = const ShufflePlusPending(incoming: 1, enriching: {7});
    expect(container.read(shufflePlusPendingProvider), const ShufflePlusPending(incoming: 1, enriching: {7}));
    engine.pending.value = ShufflePlusPending.none;
    expect(container.read(shufflePlusPendingProvider), ShufflePlusPending.none);

    container.dispose();
    engine.pending.value = const ShufflePlusPending(incoming: 2); // no listener left: no error
  });

  for (final (name, modes) in <(String, List<Override>)>[
    ('Shuffle+ off', [shuffleModeProvider.overrideWithValue(ShuffleMode.shuffle)]),
    ('a Jam', [shuffleModeProvider.overrideWithValue(ShuffleMode.plus), jamProvider.overrideWith(_ActiveJam.new)]),
  ]) {
    test('$name: no placeholders, whatever the engine says', () async {
      final engine = _Engine()..pending.value = const ShufflePlusPending(incoming: 3);
      final container = ProviderContainer(overrides: [
        shufflePlusProvider.overrideWith((ref) async => engine),
        ...modes,
      ]);
      addTearDown(container.dispose);
      await container.read(shufflePlusProvider.future);
      expect(container.read(shufflePlusPendingProvider), ShufflePlusPending.none);
    });
  }

  test('Shuffle+ turned off and on again: the placeholders come back', () async {
    final engine = _Engine()..pending.value = const ShufflePlusPending(incoming: 2);
    final container = ProviderContainer(overrides: [
      shufflePlusProvider.overrideWith((ref) async => engine),
      shuffleModeProvider.overrideWith((ref) => ref.watch(_modeProvider)),
    ]);
    addTearDown(container.dispose);
    await container.read(shufflePlusProvider.future);
    expect(container.read(shufflePlusPendingProvider), ShufflePlusPending.none);

    container.read(_modeProvider.notifier).set(ShuffleMode.plus);
    expect(container.read(shufflePlusPendingProvider).incoming, 2);
    container.read(_modeProvider.notifier).set(ShuffleMode.shuffle);
    expect(container.read(shufflePlusPendingProvider), ShufflePlusPending.none);
  });
}
