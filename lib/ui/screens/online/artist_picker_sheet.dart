import '../../widgets/cc_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_log.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/artist_merge_providers.dart';
import '../../../providers/smart_search_providers.dart' show searchRowsLimiterProvider, sourceCooldownProvider;
import '../../../services/online/budgeted_call.dart';
import '../../../providers/ytm_catalog_providers.dart';
import '../../../services/online/innertube_client.dart';
import '../../../services/online/youtube_service.dart';
import '../../../services/online/ytm_artist.dart';
import '../../../services/online/ytm_artist_resolver.dart';
import '../../theme/tokens.dart';
import '../../widgets/net_thumbnail.dart';
import '../youtube/online_results.dart' show ytErrorText;
import 'artist_page_screen.dart';
import 'artist_page_sections.dart' show thumbAt;
import '../../widgets/show_msg.dart';
import '../../../core/artist_key.dart';

/// Looks the artist [name] up among YouTube Music's artists: a single exact
/// name is the answer, otherwise the first few are offered in a sheet. Null
/// (after saying why) when nobody was found or chosen. Only ever started by
/// the user's tap.
Future<YtmArtistRef?> lookupYtmArtist(
  BuildContext context,
  WidgetRef ref,
  String name,
) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  showMsg(context, l.ytmSearchingArtist);
  final List<YtmArtistRef> found;
  try {
    found = await ref
        .read(ytmCatalogProvider)
        .searchArtists(name, ref.read(ytmLanguageProvider));
  } on Object catch (e) {
    AppLog.w('artist lookup failed ($e)');
    if (!context.mounted) return null;
    showMsg(context, 
      e is YtException
          ? ytErrorText(context, e.kind)
          : e is InnerTubeChanged
          ? l.ytmPageUnreadable
          : l.loadFailed,
    );
    return null;
  }
  messenger.clearSnackBars();
  if (!context.mounted) return null;
  final pick = await ref.read(artistMergeOpsProvider).pick(name, found);
  if (!context.mounted) return null;
  switch (pick) {
    case ExactArtist(:final artist):
      return artist;
    case ChooseArtist(:final artists):
      return showCcSheet<YtmArtistRef>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => ArtistPickerSheet(artists: artists),
      );
    case NoArtist():
      showMsg(context, l.ytmArtistNone);
      return null;
  }
}

/// «Su YouTube Music» from the library: opens the page of the artist found.
Future<void> openYtmArtist(
  BuildContext context,
  WidgetRef ref,
  String name, {
  required void Function(Widget page) open,
}) async {
  final artist = await lookupYtmArtist(context, ref, name);
  if (artist != null) open(ArtistPageScreen(artist: artist));
}

/// «Unisci con…» (D-402): a sheet with a search field (the artist's name filled
/// in) listing the profiles found other than the ones of its [group], the likely
/// one first; the one chosen joins the group. Nothing changes when it is dismissed.
Future<void> mergeArtistWith(
  BuildContext context,
  WidgetRef ref,
  YtmArtistRef head,
  List<String> group,
) async {
  final l = context.l10n;
  final cooldown = ref.read(sourceCooldownProvider);
  final limiter = ref.read(searchRowsLimiterProvider);
  final catalog = ref.read(ytmCatalogProvider);
  final hl = ref.read(ytmLanguageProvider);
  // The same budget and 429 pause as the search rows (D-425), but the error is shown.
  Future<List<YtmArtistRef>> search(String q) =>
      budgetedYtm(cooldown, limiter, () => catalog.searchArtists(q, hl)) ??
      Future.error(const YtException(YtErrorKind.rateLimited));

  final chosen = await showCcSheet<YtmArtistRef>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => MergePickerSheet(name: head.name, exclude: group, search: search),
  );
  if (chosen == null || !context.mounted) return;
  try {
    await ref.read(artistMergeOpsProvider).merge(head.id, chosen.id);
    if (context.mounted) showMsg(context, l.artistMerged);
  } on Object catch (e, st) {
    AppLog.w('artist merge failed', e, st);
    if (context.mounted) showMsg(context, l.loadFailed);
  }
}

/// The sheet of «Unisci con…»: a field (starts as [name]) and what [search] finds.
class MergePickerSheet extends StatefulWidget {
  const MergePickerSheet({super.key, required this.name, required this.exclude, required this.search});

  final String name;

  /// Profiles already in the group: never offered.
  final List<String> exclude;
  final Future<List<YtmArtistRef>> Function(String query) search;

  @override
  State<MergePickerSheet> createState() => _MergePickerSheetState();
}

class _MergePickerSheetState extends State<MergePickerSheet> {
  late final _ctrl = TextEditingController(text: widget.name);
  late Future<List<YtmArtistRef>> _found = _run();

  Future<List<YtmArtistRef>> _run() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return const [];
    final all = await widget.search(q);
    return likelyFirst(widget.name, [for (final a in all) if (!widget.exclude.contains(a.id)) a]);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _error(Object e) {
    final l = context.l10n;
    AppLog.w('artist merge search failed ($e)');
    return e is YtException
        ? ytErrorText(context, e.kind)
        : e is InnerTubeChanged
            ? l.ytmPageUnreadable
            : l.loadFailed;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(CcDims.margin, 0, CcDims.margin, CcDims.gap8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(l.artistMergePick, style: Theme.of(context).textTheme.titleMedium),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(CcDims.margin, 0, CcDims.margin, CcDims.gap8),
                child: TextField(
                  key: const ValueKey('merge-search'),
                  controller: _ctrl,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: l.artistMergeWith),
                  onSubmitted: (_) => setState(() {
                    _found = _run();
                  }),
                ),
              ),
              Flexible(
                child: FutureBuilder<List<YtmArtistRef>>(
                  future: _found,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Padding(padding: EdgeInsets.all(CcDims.gap16), child: CircularProgressIndicator());
                    }
                    final text = snap.hasError
                        ? _error(snap.error!)
                        : snap.data!.isEmpty
                            ? l.ytmArtistNone
                            : null;
                    if (text != null) {
                      return Padding(
                        padding: const EdgeInsets.all(CcDims.margin),
                        child: Text(text, key: const ValueKey('merge-message'), style: TextStyle(color: cc.textMuted)),
                      );
                    }
                    final list = snap.data!;
                    return ListView.builder(
                      shrinkWrap: list.length <= 20,
                      itemCount: list.length,
                      itemBuilder: (context, i) => ArtistPickTile(artist: list[i]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [found] with the profiles named like [name] (accents, case and «feat.» ignored) first.
List<YtmArtistRef> likelyFirst(String name, List<YtmArtistRef> found) {
  final keys = artistNameKeys(name);
  final same = [for (final a in found) if (keys.contains(matchKey(a.name))) a];
  return [...same, for (final a in found) if (!same.contains(a)) a];
}

/// The few artists to choose from: photo, name and monthly audience.
class ArtistPickerSheet extends StatelessWidget {
  const ArtistPickerSheet({super.key, required this.artists, this.title});

  final List<YtmArtistRef> artists;

  /// The heading; «Quale artista?» when null.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CcDims.margin,
                0,
                CcDims.margin,
                CcDims.gap8,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title ?? l.ytmPickArtist,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                // Many entries already exceed the max height, so lazy changes nothing visible.
                shrinkWrap: artists.length <= 20,
                itemCount: artists.length,
                itemBuilder: (context, i) {
                  return ArtistPickTile(artist: artists[i]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row of an artist choice: photo, name and monthly audience; pops the artist.
class ArtistPickTile extends StatelessWidget {
  const ArtistPickTile({super.key, required this.artist});

  final YtmArtistRef artist;

  @override
  Widget build(BuildContext context) {
    final a = artist;
    return ListTile(
      key: ValueKey('pick-${a.id}'),
      leading: NetThumbnail(
        url: thumbAt(context, a.thumbnailUrl, 48),
        width: 48,
        height: 48,
        icon: Icons.person_rounded,
        circle: true,
      ),
      title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: a.audience == null
          ? null
          : Text(
              a.audience!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.cc.textMuted),
            ),
      onTap: () => Navigator.pop(context, a),
    );
  }
}
