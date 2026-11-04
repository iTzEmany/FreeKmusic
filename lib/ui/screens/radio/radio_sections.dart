import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/app_log.dart';
import '../../../data/db/app_database.dart';
import '../../../data/repositories/radio_repository.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/radio_ops.dart';
import '../../../providers/radio_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../services/radio/radio_catalog.dart';
import '../../../services/radio/radio_station.dart';
import '../../../services/radio/regions.dart';
import '../../theme/tokens.dart';
import '../../widgets/error_state.dart';
import '../../widgets/section_header.dart';
import '../../widgets/show_msg.dart';
import '../../widgets/skeleton.dart';
import 'radio_actions.dart';
import 'radio_labels.dart';
import 'radio_region_sheet.dart';
import 'radio_station_row.dart';
import 'radio_station_sheet.dart';

/// The longest list played as a queue: a whole country is thousands of rows.
const kRadioListCap = 200;

/// Rows of [stations]; a tap plays from there with the same list as the queue.
class StationsSliver extends ConsumerWidget {
  const StationsSliver({
    super.key,
    required this.stations,
    required this.listName,
  });

  final List<RadioStation> stations;
  final String listName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = stations.length > kRadioListCap
        ? stations.sublist(0, kRadioListCap)
        : stations;
    return SliverFixedExtentList(
      itemExtent: radioRowHeight(context),
      delegate: SliverChildBuilderDelegate(
        childCount: list.length,
        (context, i) => RadioStationRow(
          key: ValueKey('${listName}_${list[i].id}'),
          station: list[i],
          onTap: () => playRadioList(context, ref, list, i, listName),
          onMore: () => RadioStationSheet.show(context, list[i]),
        ),
      ),
    );
  }
}

/// A one-line message in a sliver.
class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CcDims.margin,
        vertical: CcDims.gap8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: context.cc.textMuted),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) =>
      const SliverToBoxAdapter(child: Skeleton.list(rows: 3));
}

/// Loading, error with «Riprova», empty and data of a list of stations.
Widget _stationsOf(
  BuildContext context,
  AsyncValue<List<RadioStation>> value,
  String listName,
  VoidCallback retry,
) {
  final l = context.l10n;
  return value.when(
    loading: () => const _Loading(),
    error: (_, _) => SliverToBoxAdapter(
      child: ErrorState(message: l.radioLoadFailed, onRetry: retry),
    ),
    data: (list) => list.isEmpty
        ? _Message(l.radioNoResults)
        : StationsSliver(stations: list, listName: listName),
  );
}

/// «Le mie radio»: reorderable; hidden when nothing is saved.
class MineSection extends ConsumerWidget {
  const MineSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final saved = ref.watch(savedRadiosProvider).value ?? const <SavedRadio>[];
    if (saved.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final stations = [for (final r in saved) r.toStation()];
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: SectionHeader(l.radioMine)),
        SliverReorderableList(
          itemCount: saved.length,
          itemExtent: radioRowHeight(context),
          onReorderItem: (from, to) async {
            final ids = [for (final r in saved) r.stationId];
            ids.insert(to, ids.removeAt(from));
            try {
              await ref.read(radioOpsProvider).reorder(ids);
            } catch (e, st) {
              // The list reads the DB stream, so the old order stays on screen.
              AppLog.w('reordering saved radios failed', e, st);
              if (context.mounted) showMsg(context, l.radioReorderFailed);
            }
          },
          itemBuilder: (context, i) => Material(
            key: ValueKey('mine_${saved[i].stationId}'),
            color: Colors.transparent,
            child: RadioStationRow(
              station: stations[i],
              unreachable: saved[i].unreachable,
              onTap: () =>
                  playRadioList(context, ref, stations, i, l.radioMine),
              onMore: () => RadioStationSheet.show(context, stations[i]),
              dragHandle: ReorderableDragStartListener(
                index: i,
                child: Tooltip(
                  message: l.radioReorder,
                  child: Padding(
                    padding: const EdgeInsets.all(CcDims.gap8),
                    child: Icon(
                      Icons.drag_handle_rounded,
                      color: context.cc.textFaint,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// «Vicino a te»: the region the user chose, with its stations.
class NearYouSection extends ConsumerWidget {
  const NearYouSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final country = ref.watch(radioCountryProvider);
    final regionId = ref.watch(settingsProvider.select((s) => s.radioRegion));
    final region = regionById(country, regionId);
    final header = SliverToBoxAdapter(
      child: SectionHeader(
        l.radioNearYou,
        actionLabel: region == null ? l.radioChooseRegion : region.label,
        onAction: () => RadioRegionSheet.show(context),
      ),
    );
    if (region == null) return SliverMainAxisGroup(slivers: [header]);
    final near = ref.watch(nearYouProvider);
    final name = '${l.radioNearYou}, ${region.label}';
    return SliverMainAxisGroup(
      slivers: [
        header,
        ..._withStale(context, near.value, <Widget>[
          near.when(
            loading: () => const _Loading(),
            error: (_, _) => SliverToBoxAdapter(
              child: ErrorState(
                message: l.radioLoadFailed,
                onRetry: () => ref.invalidate(nearYouProvider),
              ),
            ),
            data: (list) => list == null || list.stations.isEmpty
                ? _Message(l.radioNoResults)
                : StationsSliver(stations: list.stations, listName: name),
          ),
        ]),
      ],
    );
  }
}

/// The «Non in linea · elenco del …» line above a list read from the old copy.
List<Widget> _withStale(
  BuildContext context,
  RadioList? list,
  List<Widget> body,
) {
  if (list == null || !list.stale) return body;
  final at = list.fetchedAt;
  final date = at == null
      ? ''
      : DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(at);
  return [_Message(context.l10n.radioOfflineList(date)), ...body];
}

/// The 24 genres in a uniform grid (4, 3 or 2 columns by text scale);
/// [selected] is highlighted.
class GenresSection extends StatelessWidget {
  const GenresSection({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final scaler = MediaQuery.textScalerOf(context);
    final scale = scaler.scale(12) / 12;
    final columns = scale < 1.3 ? 4 : (scale < 1.8 ? 3 : 2);
    // Two lines of 12 sp text plus padding, never under 56 dp.
    final cell = (scaler.scale(12) * 2 * 1.4 + 16).clamp(56.0, 200.0);
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(l.radioGenres),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              crossAxisCount: columns,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              mainAxisExtent: cell,
              children: [
                for (final tag in kRadioGenreTags)
                  Material(
                    key: ValueKey('genre-$tag'),
                    color: tag == selected ? cc.accent : cc.surface2,
                    borderRadius: BorderRadius.circular(8),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => onSelect(tag),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Center(
                          child: Text(
                            radioGenreLabel(l, tag),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: tag == selected ? cc.onAccent : cc.text,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// «Le più ascoltate» of the whole country.
class TopSection extends ConsumerWidget {
  const TopSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final top = ref.watch(radioCountryStationsProvider);
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: SectionHeader(l.radioTopListened)),
        ..._withStale(context, top.value, <Widget>[
          _stationsOf(
            context,
            top.whenData((r) => r.stations),
            l.radioTopListened,
            () => ref.invalidate(radioCountryStationsProvider),
          ),
        ]),
      ],
    );
  }
}

/// Results of a name search.
class SearchResultsSection extends ConsumerWidget {
  const SearchResultsSection({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: SectionHeader(l.radioResults)),
        _stationsOf(
          context,
          ref.watch(radioSearchProvider(query)),
          l.radioResults,
          () => ref.invalidate(radioSearchProvider(query)),
        ),
      ],
    );
  }
}

/// Stations of one genre.
class GenreResultsSection extends ConsumerWidget {
  const GenreResultsSection({
    super.key,
    required this.tag,
    required this.onClose,
  });

  final String tag;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final name = radioGenreLabel(l, tag);
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: SectionHeader(name, actionLabel: l.close, onAction: onClose),
        ),
        _stationsOf(
          context,
          ref.watch(radioGenreProvider(tag)),
          name,
          () => ref.invalidate(radioGenreProvider(tag)),
        ),
      ],
    );
  }
}
