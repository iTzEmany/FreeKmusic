import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_log.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/artist_merge_providers.dart';
import '../../../providers/ytm_catalog_providers.dart';
import '../../theme/tokens.dart';
import '../../widgets/cc_sheet.dart';
import '../../widgets/net_thumbnail.dart';
import '../../widgets/show_msg.dart';
import 'artist_page_sections.dart' show thumbAt;

/// Takes [id] out of its group and says so; «Annulla» joins it back.
Future<void> separateProfile(BuildContext context, WidgetRef ref, String id) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final ops = ref.read(artistMergeOpsProvider);
  try {
    final group = await ops.separate(id);
    showMsgOn(
      messenger,
      l.artistSeparated,
      action: SnackBarAction(
        label: l.undo,
        onPressed: () async {
          try {
            await ops.rejoin(group, id);
          } on Object catch (e, st) {
            AppLog.w('artist rejoin failed', e, st);
          }
        },
      ),
    );
  } on Object catch (e, st) {
    AppLog.w('artist separate failed', e, st);
    showMsgOn(messenger, l.loadFailed);
  }
}

/// The profiles merged under [head]: the main one and each alias with «Separa».
Future<void> showMergedProfilesSheet(BuildContext context, String head) => showCcSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => MergedProfilesSheet(head: head),
    );

class MergedProfilesSheet extends ConsumerWidget {
  const MergedProfilesSheet({super.key, required this.head});

  final String head;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final ids = ref.watch(artistGroupProvider(head)).value ?? [head];
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(CcDims.margin, 0, CcDims.margin, CcDims.gap8),
              child: Semantics(header: true, child: Text(l.mergedSheetTitle, style: Theme.of(context).textTheme.titleMedium)),
            ),
            for (final id in ids) _ProfileRow(id: id, isMain: id == ids.first, alone: ids.length < 2),
          ],
        ),
      ),
    );
  }
}

class _ProfileRow extends ConsumerWidget {
  const _ProfileRow({required this.id, required this.isMain, required this.alone});

  final String id;
  final bool isMain, alone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    // The pages of the group are already loaded by the artist page.
    final ref0 = ref.watch(artistPageProvider(id)).value?.value.ref;
    final name = ref0?.name ?? id;
    final audience = ref0?.audience;
    final sub = [
      if (isMain) l.artistMainProfile,
      if (audience != null && audience.isNotEmpty) audience,
    ].join(', ');
    return ListTile(
      key: ValueKey('profile-$id'),
      minTileHeight: 56,
      leading: NetThumbnail(
        url: thumbAt(context, ref0?.thumbnailUrl, 40),
        width: 40,
        height: 40,
        icon: Icons.person_rounded,
        circle: true,
      ),
      title: Text(name),
      subtitle: sub.isEmpty ? null : Text(sub),
      trailing: alone
          ? null
          : Semantics(
              button: true,
              label: '${l.artistSeparate}: $name',
              excludeSemantics: true,
              child: TextButton(
                key: ValueKey('separate-$id'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () {
                  Navigator.of(context).pop();
                  separateProfile(context, ref, id);
                },
                child: Text(l.artistSeparate),
              ),
            ),
    );
  }
}
