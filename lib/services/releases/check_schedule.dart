import '../../core/network_kind.dart';
import 'release_checker.dart';

/// Time between two automatic rounds.
const kCheckEvery = Duration(hours: 24);

/// Whether a round of release checks should start now.
///
/// - Never without artists to check, offline, or on a metered network with
///   «Solo su Wi-Fi» on.
/// - Never before [retryAt] (YouTube asked for a pause); once it has passed,
///   the round is due even if the last one was less than a day ago.
/// - Otherwise due when the last round is 24 h old or more (or never made);
///   [force] («Controlla ora») skips only that wait.
bool isCheckDue({
  required DateTime? lastRunAt,
  required DateTime? retryAt,
  required DateTime now,
  required bool hasArtists,
  required NetworkKind network,
  required bool unmeteredOnly,
  bool force = false,
}) {
  if (!hasArtists || !network.online) return false;
  if (unmeteredOnly && network.metered) return false;
  if (retryAt != null) {
    return !now.isBefore(retryAt);
  }
  if (force || lastRunAt == null) return true;
  return now.difference(lastRunAt) >= kCheckEvery;
}

/// Whether a running round must stop because of the network or the options.
bool mustCancelCheck({required NetworkKind network, required bool unmeteredOnly}) =>
    !network.online || (unmeteredOnly && network.metered);

/// What to tell the user after a round: the new releases of artists that are
/// not muted, or null for no notification (switched off, nothing new, all
/// muted, or one already sent today).
List<FreshRelease>? releasesToNotify({
  required List<FreshRelease> fresh,
  required bool enabled,
  required DateTime? lastNotifiedAt,
  required DateTime now,
}) {
  if (!enabled) return null;
  if (lastNotifiedAt != null && _sameDay(lastNotifiedAt, now)) return null;
  final audible = [for (final f in fresh) if (!f.artist.muted) f];
  return audible.isEmpty ? null : audible;
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
