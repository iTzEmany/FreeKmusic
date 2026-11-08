import 'package:codecore/services/online/budgeted_call.dart';
import 'package:codecore/services/online/query_match.dart';
import 'package:codecore/services/online/request_budget.dart';
import 'package:codecore/services/online/source_cooldown.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SourceCooldown cooldown;
  late WindowLimiter limiter;
  var calls = 0;
  setUp(() {
    cooldown = SourceCooldown();
    limiter = WindowLimiter(perMinute: 3);
    calls = 0;
  });
  Future<int> run() async => ++calls;

  test('paused or without budget: null, run not called', () {
    cooldown.trip(MediaKind.ytmSong);
    expect(budgetedYtm(cooldown, limiter, run), isNull);
    expect(limiter.recent, 0);
    final fresh = SourceCooldown();
    expect(budgetedYtm(fresh, limiter, run, cost: 4), isNull);
    expect(calls, 0);
  });

  test('a 429 pauses the source and is rethrown', () async {
    final f = budgetedYtm<int>(
      cooldown,
      limiter,
      () async => throw const YtException(YtErrorKind.rateLimited),
    );
    await expectLater(f, throwsA(isA<YtException>()));
    expect(cooldown.isPaused(MediaKind.ytmSong), isTrue);
  });

  test('ok: the value, and cost slots spent', () async {
    expect(await budgetedYtm(cooldown, limiter, run, cost: 2), 1);
    expect(limiter.recent, 2);
    expect(cooldown.isPaused(MediaKind.ytmSong), isFalse);
  });

  test(
    'an error that is not a 429 is rethrown and does not pause the source',
    () async {
      final f = budgetedYtm<int>(
        cooldown,
        limiter,
        () async => throw const YtException(YtErrorKind.network),
      );
      await expectLater(f, throwsA(isA<YtException>()));
      expect(cooldown.isPaused(MediaKind.ytmSong), isFalse);
    },
  );
}
