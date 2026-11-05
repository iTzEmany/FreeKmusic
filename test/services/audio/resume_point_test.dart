import 'package:codecore/services/audio/resume_point.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const long = 3 * 60 * 60 * 1000; // 3 h

  group('resumePointFor', () {
    test('a long track in the middle is remembered as is', () {
      expect(resumePointFor(const Duration(minutes: 42, seconds: 10), long),
          const Duration(minutes: 42, seconds: 10).inMilliseconds);
    });

    test('short tracks never get a bookmark', () {
      expect(resumePointFor(const Duration(minutes: 2), 4 * 60 * 1000), isNull);
      // 19:59 is still short, 20:00 is long.
      expect(resumePointFor(const Duration(minutes: 10), 19 * 60 * 1000 + 59000), isNull);
      expect(resumePointFor(const Duration(minutes: 10), 20 * 60 * 1000), isNotNull);
    });

    test('the first and last 30 seconds clear it', () {
      expect(resumePointFor(const Duration(seconds: 29), long), isNull);
      expect(resumePointFor(const Duration(seconds: 30), long), 30000);
      final end = Duration(milliseconds: long);
      expect(resumePointFor(end - const Duration(seconds: 31), long), isNotNull);
      expect(resumePointFor(end - const Duration(seconds: 29), long), isNull);
      expect(resumePointFor(end, long), isNull);
    });

    test('unknown length never gets one', () {
      expect(resumePointFor(const Duration(minutes: 30), 0), isNull);
    });
  });

  group('resumePointFor for a podcast episode', () {
    const episode = 30 * 60 * 1000;
    const short = 8 * 60 * 1000;

    test('remembered whatever its length, from the first 10 seconds on', () {
      expect(resumePointFor(const Duration(minutes: 3), short, episode: true), 180000);
      expect(resumePointFor(const Duration(seconds: 9), short, episode: true), isNull);
      expect(resumePointFor(const Duration(seconds: 10), short, episode: true), 10000);
      // The same short track as music is never bookmarked.
      expect(resumePointFor(const Duration(minutes: 3), short), isNull);
    });

    test('from 95 % on it is heard, not a place to come back to', () {
      expect(resumePointFor(Duration(milliseconds: (episode * 0.94).round()), episode, episode: true), isNotNull);
      expect(resumePointFor(Duration(milliseconds: (episode * 0.95).round()), episode, episode: true), isNull);
      expect(resumePointFor(Duration(milliseconds: episode), episode, episode: true), isNull);
    });

    test('unknown length: nothing', () {
      expect(resumePointFor(const Duration(minutes: 3), 0, episode: true), isNull);
    });
  });

  group('episodeHeard', () {
    test('exactly at 95 %', () {
      expect(episodeHeard(const Duration(seconds: 94), 100000), isFalse);
      expect(episodeHeard(const Duration(seconds: 95), 100000), isTrue);
      expect(episodeHeard(const Duration(seconds: 100), 100000), isTrue);
      expect(episodeHeard(const Duration(seconds: 5), 0), isFalse);
    });
  });

  group('resumeStartFor', () {
    test('starts 5 seconds before the saved point', () {
      expect(resumeStartFor(600000), const Duration(minutes: 9, seconds: 55));
    });

    test('never before the start; nothing saved means no start', () {
      expect(resumeStartFor(3000), Duration.zero);
      expect(resumeStartFor(null), isNull);
      expect(resumeStartFor(0), isNull);
    });
  });

  group('isPastEnd', () {
    test('only a position at or after the end is stale; an unknown length never', () {
      const p = Duration(seconds: 10);
      expect(isPastEnd(p, 10001), isFalse);
      expect(isPastEnd(p, 10000), isTrue);
      expect(isPastEnd(p, 9999), isTrue);
      expect(isPastEnd(p, 0), isFalse);
      expect(isPastEnd(p, -1), isFalse);
    });
  });
}
