import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/repositories/release_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/releases_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../services/releases/release_check_controller.dart'
    show ReleaseCheckController;
import '../../../services/releases/release_checker.dart' show CheckStop;
import '../../shell/shell_nav.dart';
import '../../theme/tokens.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/net_thumbnail.dart';
import '../online/artist_page_sections.dart' show thumbAt;
import 'followed_artists_screen.dart';
import 'release_labels.dart';
import '../../widgets/show_msg.dart';
import '../../widgets/cc_app_bar.dart';

/// «Nuove uscite»: the last 90 days, filtered by artist, with «Controlla ora»,
/// the time of the last check and the list of followed artists.
class NewReleasesScreen extends ConsumerStatefulWidget {
  const NewReleasesScreen({super.key});

  @override
  ConsumerState<NewReleasesScreen> createState() => _NewReleasesScreenState();
}

class _NewReleasesScreenState extends ConsumerState<NewReleasesScreen> {
  static const _maxArtistChips = 8;
  bool _allArtists = false;

  Iterable<MapEntry<String, String>> _artistsShown(
    Map<String, String> artists,
  ) => _allArtists ? artists.entries : artists.entries.take(_maxArtistChips);

  String? _artistId;

  String _time(DateTime t) =>
      MaterialLocalizations.of(context)
          .formatTimeOfDay(TimeOfDay.fromDateTime(t));

  /// «YouTube chiede una pausa…» while the pause asked by YouTube lasts.
  String? _pause(AppLocalizations l) {
    final ms = ref.read(settingsStoreProvider).releasesRetryAt;
    if (ms == null) return null;
    final at = DateTime.fromMillisecondsSinceEpoch(ms);
    return at.isAfter(DateTime.now()) ? l.releasesPaused(_time(at)) : null;
  }

  Future<void> _checkNow() async {
    final l = context.l10n;
    final controller = ref.read(releaseCheckControllerProvider);
    if (controller.running.value) return;
    final manual = ref.read(manualReleaseCheckProvider.notifier)..set(true);
    final out = await controller.checkNow();
    manual.set(false);
    if (!mounted) return;
    final text = out == null
        ? (_pause(l) ?? l.releasesCantCheck)
        : switch (out.stoppedBy) {
            CheckStop.rateLimited => _pause(l) ?? l.releasesCantCheck,
            CheckStop.changed => l.releasesChanged,
            _ =>
              out.fresh.isEmpty
                  ? l.releasesCheckNone
                  : l.releasesCheckFound(out.fresh.length),
          };
    showMsg(context, text);
  }

  Widget _checkHeader(ReleaseCheckController controller) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    return ValueListenableBuilder<bool>(
      valueListenable: controller.running,
      builder: (_, running, _) {
        final last = ref.read(settingsStoreProvider).releasesLastRunAt;
        final lastText = last == null
            ? l.releasesNeverChecked
            : l.releasesLastCheck(
                DateFormat.yMd(Localizations.localeOf(context).toLanguageTag())
                    .add_Hm()
                    .format(DateTime.fromMillisecondsSinceEpoch(last)),
              );
        final pause = _pause(l);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FilledButton.tonalIcon(
                  key: const ValueKey('check-now'),
                  onPressed: running ? null : _checkNow,
                  icon: running
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(
                    running ? l.releasesChecking : l.releasesCheckNow,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              lastText,
              key: const ValueKey('last-check'),
              style: theme.bodyMedium?.copyWith(color: cc.textMuted),
            ),
            if (pause != null)
              Text(
                pause,
                key: const ValueKey('check-pause'),
                style: theme.bodyMedium?.copyWith(color: cc.error),
              ),
          ],
        );
      },
    );
  }

  Widget _artistChips(Map<String, String> artists) {
    final l = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip(
          l.releasesAllArtists,
          _artistId == null,
          () => setState(() => _artistId = null),
        ),
        for (final e in _artistsShown(artists))
          _chip(
            e.value,
            _artistId == e.key,
            () => setState(() => _artistId = _artistId == e.key ? null : e.key),
          ),
        if (!_allArtists && artists.length > _maxArtistChips)
          ActionChip(
            key: const ValueKey('artist-chips-more'),
            label: Text(l.showMore),
            onPressed: () => setState(() => _allArtists = true),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final all =
        ref.watch(recentReleasesProvider(90)).value ?? const <RecentRelease>[];
    final followedCount = ref.watch(
      followedArtistsProvider.select((v) => v.value?.length ?? 0),
    );
    final controller = ref.watch(releaseCheckControllerProvider);
    final artists = <String, String>{
      for (final r in all) r.release.artistId: r.artistName,
    };
    final shown = [
      for (final r in all)
        if (_artistId == null || r.release.artistId == _artistId) r,
    ];
    return Scaffold(
      appBar: CcAppBar(title: l.newReleasesTitle),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: EdgeInsets.zero.withDock(context),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CcDims.margin,
                  CcDims.gap8,
                  CcDims.margin,
                  0,
                ),
                child: _checkHeader(controller),
              ),
              ListTile(
                key: const ValueKey('followed-artists-link'),
                leading: const Icon(Icons.people_outline_rounded),
                title: Text(l.releasesFollowedTitle(followedCount)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    ShellNav.open<void>(context, const FollowedArtistsScreen()),
              ),
              if (artists.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    CcDims.margin,
                    CcDims.gap4,
                    CcDims.margin,
                    CcDims.gap8,
                  ),
                  child: _artistChips(artists),
                ),
              if (shown.isEmpty)
                SizedBox(
                  height: 260,
                  child: EmptyState(
                    icon: Icons.album_outlined,
                    message: l.releasesEmpty,
                  ),
                )
              else
                for (final r in shown) _ReleaseRow(release: r),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
  );
}

class _ReleaseRow extends ConsumerWidget {
  const _ReleaseRow({required this.release});

  final RecentRelease release;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final r = release.release;
    final more = release.variants > 0
        ? ', ${l.releaseVariants(release.variants)}'
        : '';
    return ListTile(
      key: ValueKey('release-row-${r.browseId}'),
      leading: NetThumbnail(
        url: thumbAt(context, r.thumbUrl, 56),
        width: 56,
        height: 56,
        icon: Icons.album_rounded,
      ),
      title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${release.artistName}, ${releaseKindLabel(l, r)}$more',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: r.isNew
          ? Semantics(
              label: l.releaseNewBadge,
              child: Container(
                key: ValueKey('row-dot-${r.browseId}'),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: cc.accent,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
      onTap: () => openRelease(context, ref, release),
    );
  }
}
