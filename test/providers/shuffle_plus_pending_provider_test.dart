import 'package:codecore/providers/shuffle_plus_providers.dart';
import 'package:codecore/services/shuffle_plus/shuffle_plus_controller.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Only what the provider reads: the engine's `pending`.
class _Engine implements ShufflePlusController {
  final _pending = ValueNotifier(ShufflePlusPending.none);

  @override
  ValueNotifier<ShufflePlusPending> get pending => _pending;

  @override
  dynamic noSuchMethod(Invocation i) => null;
}

void main() {
  test('the provider follows the engine\'s pending state, and stops when it is disposed', () async {
    final engine = _Engine();
    final container = ProviderContainer(overrides: [
      shufflePlusProvider.overrideWith((ref) async => engine),
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
}
