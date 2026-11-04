import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../data/db/app_database.dart';
import '../../../data/repositories/library_entries.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/library_providers.dart';
import '../../../providers/player_providers.dart';
import '../../../providers/releases_providers.dart';
import '../../shell/shell_nav.dart';
import '../../theme/tokens.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/playlist_cover.dart';
import '../../widgets/section_header.dart';
import '../library/album_detail_screen.dart';
import '../now_playing/now_playing_screen.dart' show playContextName;
import '../playlists/playlist_detail_screen.dart';
import '../releases/new_releases_screen.dart';
import 'home_row.dart';

/// One line of «Riprendi».
sealed class ResumeRow {
  const ResumeRow();
}

/// What is playing now, with its place in the queue.
class QueueResume extends ResumeRow {
  const QueueResume(this.track, this.index, this.length, this.source);
  final Track track;
  final int index, length;
  final PlayContext? source;
}

/// A track left in the middle.
class TrackResume extends ResumeRow {
  const TrackResume(this.track);
  final Track track;
}

/// An album or playlist played lately.
class EntryResume extends ResumeRow {
  const EntryResume(this.entry);
  final LibraryEntry entry;
}

class ReleasesResume extends ResumeRow {
  const ReleasesResume();
}

const _maxRows = 4;

List<ResumeRow> buildResumeRows({
  Track? current,
  List<Track> queue = const [],
  PlayContext? source,
  List<Track> resumable = const [],
  List<LibraryEntry> entries = const [],
  bool hasNewReleases = false,
}) {
  final index = current == null
      ? -1
      : queue.indexWhere((t) => t.id == current.id);
  final queued = current != null && index >= 0;
  final recent = entries.where((e) => e.lastPlayedAt != null).toList()
    ..sort((a, b) => b.lastPlayedAt!.compareTo(a.lastPlayedAt!));
  return [
    if (hasNewReleases) const ReleasesResume(),
    if (queued) QueueResume(current, index, queue.length, source),
    for (final t in resumable)
      if (!queued || t.id != current.id) TrackResume(t),
    for (final e in recent) EntryResume(e),
  ].take(_maxRows).toList();
}

/// «Riprendi»: the rows of [buildResumeRows]. Hidden when empty.
class ResumeList extends ConsumerWidget {
  const ResumeList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final newReleases =
        kEnableYoutube && (ref.watch(newReleasesCountProvider).value ?? 0) > 0;
    final rows = buildResumeRows(
      current: ref.watch(currentTrackProvider).value,
      queue: ref.watch(queueProvider).value ?? const [],
      source: ref.watch(playContextProvider),
      resumable: ref.watch(resumableTracksProvider).value ?? const [],
      entries: ref.watch(recentEntriesProvider),
      hasNewReleases: newReleases,
    );
    if (rows.isEmpty) return const SizedBox.shrink();
    final ctrl = ref.read(playerControllerProvider);

    return Column(
      children: [
        SectionHeader(l.homeResume),
        HomeBlock(
          children: [
            for (final r in rows)
              switch (r) {
                ReleasesResume() => HomeRow(
                  key: const ValueKey('resume-releases'),
                  cover: const HomeIconCover(Icons.new_releases_outlined),
                  title: l.newReleasesTitle,
                  onTap: () =>
                      ShellNav.open<void>(context, const NewReleasesScreen()),
                ),
                QueueResume() => _QueueRow(
                  r,
                  subtitle: _queueSubtitle(context, r),
                ),
                TrackResume() => HomeRow(
                  key: ValueKey('resume-track-${r.track.id}'),
                  cover: CoverImage(
                    coverKey: r.track.coverKey,
                    size: kHomeCover,
                    radius: CcDims.rList,
                  ),
                  title: r.track.title,
                  subtitle: l.homeMinutesLeft(_minutesLeft(r.track)),
                  progress: _fraction(
                    r.track.resumePositionMs,
                    r.track.durationMs,
                  ),
                  onTap: () => ctrl.playFromList([r.track], 0),
                ),
                EntryResume() => HomeRow(
                  key: ValueKey(
                    'resume-entry-${r.entry.kind.name}-${r.entry.id}',
                  ),
                  cover: r.entry.kind == LibraryKind.playlist
                      ? PlaylistCover(
                          size: kHomeCover,
                          radius: CcDims.rList,
                          coverKeys: playlistCoverKeys(null, [
                            r.entry.coverKey,
                          ]),
                        )
                      : CoverImage(
                          coverKey: r.entry.coverKey,
                          size: kHomeCover,
                          radius: CcDims.rList,
                        ),
                  title: r.entry.title ?? l.unknownAlbum,
                  subtitle: r.entry.kind == LibraryKind.playlist
                      ? l.tracksCount(r.entry.count)
                      : (r.entry.variousArtists
                            ? l.variousArtists
                            : (r.entry.artist ?? l.unknownArtist)),
                  onTap: () => r.entry.kind == LibraryKind.playlist
                      ? ShellNav.open<void>(
                          context,
                          PlaylistDetailScreen(
                            playlist: r.entry.playlist!.playlist,
                          ),
                        )
                      : ShellNav.open<void>(
                          context,
                          AlbumDetailScreen(album: r.entry.album!),
                        ),
                ),
              },
          ],
        ),
      ],
    );
  }

  String _queueSubtitle(BuildContext context, QueueResume r) {
    final l = context.l10n;
    final from = playContextName(l, r.source);
    return from == null
        ? l.homeResumeQueue(r.index + 1, r.length)
        : l.homeResumeQueueFrom(from, r.index + 1, r.length);
  }

  int _minutesLeft(Track t) {
    final left = t.durationMs - (t.resumePositionMs ?? 0);
    return (left / 60000).ceil().clamp(1, 1 << 30);
  }

  double _fraction(int? position, int? duration) =>
      duration == null || duration <= 0 || position == null
      ? 0
      : (position / duration).clamp(0.0, 1.0);
}

/// Watches play/pause itself so the list above does not rebuild on it.
class _QueueRow extends ConsumerWidget {
  const _QueueRow(this.row, {required this.subtitle});

  final QueueResume row;
  final String subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = ref.watch(isPlayingProvider).value ?? false;
    return HomeRow(
      key: const ValueKey('resume-queue'),
      cover: CoverImage(
        coverKey: row.track.coverKey,
        size: kHomeCover,
        radius: CcDims.rList,
      ),
      title: row.track.title,
      subtitle: subtitle,
      now: true,
      // shortcut: a playing row does nothing, open Now Playing if it feels dead.
      onTap: playing
          ? null
          : ref.read(playerControllerProvider).togglePlayPause,
    );
  }
}
