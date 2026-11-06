import '../../widgets/cc_sheet.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_log.dart';
import '../../../core/platform.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/radio_ops.dart';
import '../../../providers/radio_providers.dart';
import '../../../services/radio/radio_station.dart';
import '../../theme/tokens.dart';
import '../../widgets/prompt_name.dart';
import '../../widgets/radio_art.dart';
import '../../widgets/show_msg.dart';
import 'radio_actions.dart';
import 'radio_labels.dart';

/// Opens [address] in the browser on a desktop; on a phone, where there is no
/// way to do it without a new package, copies it and says so.
Future<void> openStationSite(BuildContext context, String address) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final copied = context.l10n.radioSiteCopied;
  try {
    if (isDesktop) {
      if (Platform.isWindows) {
        await Process.start('rundll32', ['url.dll,FileProtocolHandler', address]);
      } else {
        await Process.start('xdg-open', [address]);
      }
      return;
    }
  } on Object catch (e, st) {
    AppLog.w('opening the station site failed', e, st);
  }
  await Clipboard.setData(ClipboardData(text: address));
  if (messenger != null) showMsgOn(messenger, copied);
}

/// What is known about a station, with save / remove, rename (saved ones) and
/// its website.
class RadioStationSheet extends ConsumerWidget {
  const RadioStationSheet({super.key, required this.station});

  final RadioStation station;

  static Future<void> show(BuildContext context, RadioStation station) =>
      showCcSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => RadioStationSheet(station: station),
      );

  Future<void> _rename(BuildContext context, WidgetRef ref, String current) async {
    final l = context.l10n;
    final repo = ref.read(radioOpsProvider);
    final name = await promptName(
      context,
      title: l.radioRenameTitle,
      confirmLabel: l.save,
      initial: current,
    );
    if (name != null) await repo.rename(station.id, name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final saved = ref.watch(savedRadioIdsProvider.select((s) => s.contains(station.id)));
    final shownName = ref
            .watch(savedRadiosProvider)
            .value
            ?.where((r) => r.stationId == station.id)
            .map((r) => r.name)
            .firstOrNull ??
        station.name;
    final mb = radioMbPerHour(station.bitrate);
    final facts = [
      [station.state, station.countryCode].where((e) => e.isNotEmpty).join(', '),
      radioQualityLine(station),
      if (mb > 0) l.radioDataPerHour('$mb'),
      station.tags.take(6).join(', '),
    ].where((e) => e.isNotEmpty).toList();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(CcDims.margin, 0, CcDims.margin, CcDims.gap16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RadioArt(station: station, size: 64),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(shownName, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final f in facts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(f, style: theme.bodyMedium?.copyWith(color: cc.textMuted)),
              ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(saved ? Icons.star_rounded : Icons.star_border_rounded,
                  color: saved ? cc.accent : null),
              title: Text(saved ? l.radioUnsave : l.radioSave),
              onTap: () => toggleSavedRadio(context, ref, station),
            ),
            if (saved)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_outlined),
                title: Text(l.rename),
                onTap: () => _rename(context, ref, shownName),
              ),
            if (station.homepage.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.public_rounded),
                title: Text(l.radioSite),
                subtitle: Text(station.homepage, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => openStationSite(context, station.homepage),
              ),
          ],
        ),
      ),
    );
  }
}
