import 'package:codecore/core/network_kind.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/services/releases/check_schedule.dart';
import 'package:codecore/services/releases/release_checker.dart';
import 'package:codecore/services/releases/release_diff.dart';
import 'package:codecore/services/online/ytm_artist.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 22, 12);
  const wifi = NetworkKind();
  bool due({
    DateTime? lastRunAt,
    DateTime? retryAt,
    bool hasArtists = true,
    NetworkKind network = wifi,
    bool unmeteredOnly = false,
    bool force = false,
  }) =>
      isCheckDue(
          lastRunAt: lastRunAt,
          retryAt: retryAt,
          now: now,
          hasArtists: hasArtists,
          network: network,
          unmeteredOnly: unmeteredOnly,
          force: force);

  group('isCheckDue', () {
    test('due after 24 hours (or never run) and not before', () {
      expect(due(), isTrue);
      expect(due(lastRunAt: now.subtract(const Duration(hours: 24))), isTrue);
      expect(due(lastRunAt: now.subtract(const Duration(hours: 23, minutes: 59))), isFalse);
    });

    test('never without artists or without a network', () {
      expect(due(hasArtists: false), isFalse);
      expect(due(network: const NetworkKind(online: false)), isFalse);
      expect(due(force: true, hasArtists: false), isFalse);
    });

    test('a metered network blocks it only with «Solo su Wi-Fi»', () {
      const mobile = NetworkKind(metered: true);
      expect(due(network: mobile), isTrue);
      expect(due(network: mobile, unmeteredOnly: true), isFalse);
      expect(due(network: mobile, unmeteredOnly: true, force: true), isFalse);
    });

    test('not before retryAt, even forced; after it, due even if the last round was recent', () {
      final recent = now.subtract(const Duration(hours: 1));
      expect(due(lastRunAt: recent, retryAt: now.add(const Duration(minutes: 1))), isFalse);
      expect(due(retryAt: now.add(const Duration(minutes: 1)), force: true), isFalse);
      expect(due(lastRunAt: recent, retryAt: now), isTrue);
    });

    test('«Controlla ora» skips the 24 hours', () {
      final recent = now.subtract(const Duration(hours: 1));
      expect(due(lastRunAt: recent), isFalse);
      expect(due(lastRunAt: recent, force: true), isTrue);
    });
  });

  group('releasesToNotify', () {
    FreshRelease fresh(String id, {bool muted = false}) => FreshRelease(
          FollowedArtist(
              ytmId: id, name: id, origin: 0, excluded: false, muted: muted,
              followedAt: 0, checksFailed: 0),
          NewRelease(
              release: YtmRelease(browseId: 'MPREb_$id', title: 'T $id', subtitle: '2026'),
              kind: ReleaseKind.album, year: 2026, groupKey: id, variants: const []),
        );

    List<String>? ids(List<FreshRelease>? l) => l?.map((f) => f.artist.ytmId).toList();

    test('muted artists are left out; all muted or nothing new means no notification', () {
      final r = releasesToNotify(
          fresh: [fresh('a'), fresh('b', muted: true)], enabled: true, lastNotifiedAt: null, now: now);
      expect(ids(r), ['a']);
      expect(
          releasesToNotify(fresh: [fresh('b', muted: true)], enabled: true, lastNotifiedAt: null, now: now),
          isNull);
      expect(releasesToNotify(fresh: const [], enabled: true, lastNotifiedAt: null, now: now), isNull);
    });

    test('switched off, or already notified today: none; yesterday: yes', () {
      final f = [fresh('a')];
      expect(releasesToNotify(fresh: f, enabled: false, lastNotifiedAt: null, now: now), isNull);
      expect(releasesToNotify(fresh: f, enabled: true, lastNotifiedAt: DateTime(2026, 10, 22, 1), now: now),
          isNull);
      expect(
          releasesToNotify(fresh: f, enabled: true, lastNotifiedAt: DateTime(2026, 10, 21, 23), now: now),
          isNotNull);
    });
  });
}
