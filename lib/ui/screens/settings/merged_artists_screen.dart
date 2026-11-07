import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_log.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/artist_merge_providers.dart';
import '../../../services/online/ytm_artist.dart';
import '../../shell/shell_nav.dart';
import '../../theme/tokens.dart';
import '../../widgets/cc_app_bar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/show_msg.dart';
import '../online/artist_page_screen.dart';
import '../online/merged_profiles.dart';

/// Settings → «Artisti uniti»: the merged groups with «Separa», and the pairs
/// marked «diversi» with «Rimuovi». Names come from what is stored locally (followed artists, lookups); no request.
class MergedArtistsScreen extends ConsumerWidget {
  const MergedArtistsScreen({super.key});

  Future<void> _change(BuildContext context, WidgetRef ref, Future<void> Function() change) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.loadFailed;
    try {
      await change();
    } on Object catch (e, st) {
      AppLog.w('merged artists change failed', e, st);
      showMsgOn(messenger, failed);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final groups = ref.watch(mergedGroupsProvider).value ?? const <List<String>>[];
    final pairs = ref.watch(notSamePairsProvider).value ?? const <(String, String)>[];
    final names = ref.watch(artistNamesProvider).value ?? const <String, String>{};
    String name(String id) => names[id] ?? id;
    void open(String id) =>
        ShellNav.open<void>(context, ArtistPageScreen(artist: YtmArtistRef(id: id, name: name(id))));
    final ops = ref.read(artistMergeOpsProvider);
    final theme = Theme.of(context).textTheme;
    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(CcDims.margin, CcDims.gap16, CcDims.margin, CcDims.gap4),
          child: Semantics(header: true, child: Text(text, style: theme.titleSmall)),
        );
    return Scaffold(
      appBar: CcAppBar(title: l.settingsMergedArtists),
      body: groups.isEmpty && pairs.isEmpty
          ? EmptyState(
              key: const ValueKey('merged-empty'),
              icon: Icons.people_outline,
              message: l.mergedArtistsEmpty,
              help: l.mergedArtistsEmptyHelp,
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: CcDims.gap24).withDock(context),
              children: [
                for (final g in groups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(CcDims.margin, CcDims.gap16, CcDims.gap8, 0),
                    child: Row(children: [
                      Expanded(child: Text(name(g.first), style: theme.titleSmall)),
                      TextButton(
                        key: ValueKey('split-all-${g.first}'),
                        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                        onPressed: () => _change(context, ref, () => ops.dissolve(g.first)),
                        child: Text(l.mergedArtistsSplitAll),
                      ),
                    ]),
                  ),
                  for (final id in g)
                    ListTile(
                      key: ValueKey('group-row-$id'),
                      minTileHeight: 56,
                      title: Text(name(id)),
                      subtitle: id == g.first ? Text(l.artistMainProfile) : null,
                      onTap: () => open(id),
                      trailing: id == g.first
                          ? null
                          : TextButton(
                              key: ValueKey('separate-$id'),
                              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                              onPressed: () => separateProfile(context, ref, id),
                              child: Text(l.artistSeparate),
                            ),
                    ),
                ],
                if (pairs.isNotEmpty) header(l.notSameTitle),
                for (final (a, b) in pairs)
                  ListTile(
                    key: ValueKey('pair-$a-$b'),
                    minTileHeight: 56,
                    title: Text(name(a)),
                    subtitle: Text(name(b)),
                    trailing: TextButton(
                      key: ValueKey('unmark-$a-$b'),
                      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                      onPressed: () => _change(context, ref, () => ops.unmarkNotSame(a, b)),
                      child: Text(l.notSameRemove),
                    ),
                  ),
              ],
            ),
    );
  }
}
