import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_log.dart';
import '../../../core/app_info.dart';
import '../../../core/constants.dart';
import '../../../core/platform.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/cover_ops.dart';
import '../../../providers/equalizer_providers.dart';
import '../../../providers/library_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../widgets/cc_sheet.dart';
import '../../widgets/confirm.dart';
import '../../widgets/cover_image.dart';
import '../../../providers/folder_actions.dart';
import '../library/folders_sheet.dart';
import '../../../providers/share_providers.dart';
import '../../../providers/translation_providers.dart';
import '../../shell/shell_nav.dart';
import '../share/share_screen.dart';
import '../../theme/tokens.dart';
import '../../widgets/prompt_name.dart';
import 'icon_follow_tile.dart';
import 'theme_tiles.dart';
import 'cleanup_tiles.dart';
import 'advanced_section.dart';
import 'backup_section.dart';
import 'download_settings_tiles.dart';
import 'enrich_library_tile.dart';
import 'equalizer_screen.dart';
import 'log_export_tile.dart';
import 'report_issue_tile.dart';
import 'missing_tracks_screen.dart';
import 'transition_settings_tiles.dart';
import 'speaker_jam_tiles.dart';
import '../../../providers/jam_remote_providers.dart';
import 'jam_gate_tiles.dart';
import 'jam_remote_settings.dart';
import 'trusted_devices_tiles.dart';
import 'translation_models_tiles.dart';
import 'update_tiles.dart';
import 'shuffle_plus_tiles.dart';
import 'release_settings_tiles.dart';
import '../../widgets/segmented_blocks.dart';
import '../import/exportify_remind_choice.dart';
import '../../widgets/show_msg.dart';

const _languages = {
  'it': 'Italiano',
  'en': 'English',
  'de': 'Deutsch',
  'es': 'Español',
  'fr': 'Français',
  'pt': 'Português',
};

/// Language name as shown in the picker and in the index summary.
String languageName(String code) => _languages[code] ?? code;

enum SettingsPage {
  appearance,
  playback,
  library,
  online,
  network,
  backup,
  advanced,
}

String settingsPageTitle(AppLocalizations l, SettingsPage p) => switch (p) {
  SettingsPage.appearance => l.settingsPageAppearance,
  SettingsPage.playback => l.settingsPagePlayback,
  SettingsPage.library => l.settingsPageLibrary,
  SettingsPage.online => l.settingsPageOnline,
  SettingsPage.network => l.settingsPageNetwork,
  SettingsPage.backup => l.settingsPageBackup,
  SettingsPage.advanced => l.settingsPageAdvanced,
};

/// The groups of one settings page, in a scrolling column (max 760 wide).
class SettingsPageView extends ConsumerWidget {
  const SettingsPageView(this.page, {super.key});

  final SettingsPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The gate lists change without a provider rebuild.
    if (page == SettingsPage.network) {
      return ListenableBuilder(
        listenable: ref.watch(jamGateProvider),
        builder: (context, _) => _body(context, ref),
      );
    }
    return _body(context, ref);
  }

  Widget _body(BuildContext context, WidgetRef ref) {
    final groups = switch (page) {
      SettingsPage.appearance => _appearance(context, ref),
      SettingsPage.playback => _playback(context, ref),
      SettingsPage.library => _library(context, ref),
      SettingsPage.online => _online(context, ref),
      SettingsPage.network => _network(context, ref),
      SettingsPage.backup => _backup(context, ref),
      SettingsPage.advanced => _advanced(context, ref),
    };
    // A page with a single group needs no group title.
    final single = groups.length == 1;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.only(bottom: CcDims.gap24),
          children: [
            for (final g in groups)
              single ? SettingsGroup(children: g.children) : g,
          ],
        ),
      ),
    );
  }
}

List<SettingsGroup> _appearance(BuildContext context, WidgetRef ref) {
  final l = context.l10n;
  final s = ref.watch(settingsProvider);
  final notifier = ref.read(settingsProvider.notifier);
  return [
    SettingsGroup(
      title: l.settingsAppearance,
      children: [
        const ThemeTiles(),
        const IconFollowTile(),
        ListTile(
          title: Text(l.settingsTextSize),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: CcDims.gap8),
            child: SegmentedBlocks<double>(
              items: [
                BlockItem(
                  value: 0.9,
                  icon: Icons.text_decrease,
                  label: l.textSmall,
                ),
                BlockItem(
                  value: 1.0,
                  icon: Icons.text_fields,
                  label: l.textNormal,
                ),
                BlockItem(
                  value: 1.15,
                  icon: Icons.text_increase,
                  label: l.textLarge,
                ),
              ],
              selected: s.fontScale,
              onChanged: (v) =>
                  notifier.update((c) => c.copyWith(fontScale: v)),
            ),
          ),
        ),
        SwitchListTile(
          title: Text(l.settingsCompact),
          value: s.compactMode,
          onChanged: (v) => notifier.update((c) => c.copyWith(compactMode: v)),
        ),
        SwitchListTile(
          title: Text(l.settingsReducedMotion),
          value: s.reducedMotion,
          onChanged: (v) =>
              notifier.update((c) => c.copyWith(reducedMotion: v)),
        ),
        SwitchListTile(
          title: Text(l.settingsSpinCover),
          subtitle: Text(l.settingsSpinCoverHint),
          value: s.spinCover,
          onChanged: (v) => notifier.update((c) => c.copyWith(spinCover: v)),
        ),
      ],
    ),
    SettingsGroup(
      title: l.settingsLanguage,
      children: [
        ListTile(
          leading: const Icon(Icons.language_rounded),
          title: Text(_languages[s.language] ?? s.language),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _pickLanguage(context, ref),
        ),
      ],
    ),
  ];
}

List<SettingsGroup> _playback(BuildContext context, WidgetRef ref) {
  final l = context.l10n;
  final s = ref.watch(settingsProvider);
  final notifier = ref.read(settingsProvider.notifier);
  return [
    SettingsGroup(
      title: l.settingsPlayback,
      children: [
        if (ref.watch(equalizerProvider) != null)
          ListTile(
            leading: const Icon(Icons.equalizer_rounded),
            title: Text(l.equalizer),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => ShellNav.open<void>(context, const EqualizerScreen()),
          ),
        const TransitionSettingsTiles(),
        const ShufflePlusTiles(),
        SwitchListTile(
          title: Text(l.settingsRecordHistory),
          subtitle: Text(l.settingsRecordHistoryHint),
          value: s.recordHistory,
          onChanged: (v) =>
              notifier.update((c) => c.copyWith(recordHistory: v)),
        ),
        SwitchListTile(
          title: Text(l.normalizeVolume),
          subtitle: Text(l.normalizeVolumeHint),
          value: s.normalizeVolume,
          onChanged: (v) =>
              notifier.update((c) => c.copyWith(normalizeVolume: v)),
        ),
      ],
    ),
  ];
}

List<SettingsGroup> _library(BuildContext context, WidgetRef ref) {
  final l = context.l10n;
  final folders = ref.watch(foldersProvider).value ?? const [];
  final missing = ref.watch(missingTracksProvider).value ?? const [];
  return [
    SettingsGroup(
      title: l.settingsLibrary,
      children: [
        for (final f in folders)
          ListTile(
            leading: const Icon(Icons.folder),
            title: Text(f.path, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              tooltip: l.removeFolder,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => confirmRemoveFolder(context, ref, f.id),
            ),
          ),
        ListTile(
          leading: const Icon(Icons.create_new_folder),
          title: Text(l.addFolder),
          onTap: () => addFolderAndScan(ref),
        ),
        ListTile(
          leading: const Icon(Icons.refresh),
          title: Text(l.rescanNow),
          onTap: () => scanWithPermission(ref),
        ),
        ListTile(
          leading: const Icon(Icons.image_not_supported_outlined),
          title: Text(l.clearCoverCache),
          onTap: () => _clearCovers(context, ref),
        ),
        if (missing.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.report_problem_outlined),
            title: Text(l.missingTracksCount(missing.length)),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const MissingTracksScreen(),
              ),
            ),
          ),
      ],
    ),
    SettingsGroup(
      title: l.cleanupSection,
      children: cleanupTiles(context, ref),
    ),
  ];
}

List<SettingsGroup> _online(BuildContext context, WidgetRef ref) {
  final l = context.l10n;
  final s = ref.watch(settingsProvider);
  final notifier = ref.read(settingsProvider.notifier);
  return [
    SettingsGroup(
      title: l.settingsOnline,
      children: [
        const EnrichLibraryTile(),
        SwitchListTile(
          title: Text(l.autoEnrich),
          subtitle: Text(l.autoEnrichHint),
          value: s.autoEnrich,
          onChanged: (v) => notifier.update((c) => c.copyWith(autoEnrich: v)),
        ),
        SwitchListTile(
          title: Text(l.autoLyrics),
          subtitle: Text(l.autoLyricsHint),
          value: s.autoLyrics,
          onChanged: (v) => notifier.update((c) => c.copyWith(autoLyrics: v)),
        ),
        SwitchListTile(
          title: Text(l.autoCuriosities),
          subtitle: Text(l.autoCuriositiesHint),
          value: s.autoCuriosities,
          onChanged: (v) =>
              notifier.update((c) => c.copyWith(autoCuriosities: v)),
        ),
        SwitchListTile(
          title: Text(l.deezerMeta),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.deezerMetaHint),
              const SizedBox(height: 4),
              Text(l.deezerMetaNote),
            ],
          ),
          isThreeLine: true,
          value: s.deezerMeta,
          onChanged: (v) => notifier.update((c) => c.copyWith(deezerMeta: v)),
        ),
        SwitchListTile(
          title: Text(l.acoustId),
          subtitle: Text(l.acoustIdHint),
          value: s.acoustId,
          onChanged: (v) => notifier.update((c) => c.copyWith(acoustId: v)),
        ),
        SwitchListTile(
          title: Text(l.creditsDetails),
          subtitle: Text('${l.creditsDetailsHint}\n${l.creditsDetailsNote}'),
          isThreeLine: true,
          value: s.creditsDetails,
          onChanged: (v) => notifier.update((c) => c.copyWith(creditsDetails: v)),
        ),
      ],
    ),
    SettingsGroup(
      title: l.exportifyRemindTitle,
      children: const [
        Padding(
          padding: EdgeInsets.fromLTRB(
            CcDims.gap16,
            CcDims.gap4,
            CcDims.gap16,
            CcDims.gap8,
          ),
          child: ExportifyRemindChoice(),
        ),
      ],
    ),
    if (kEnableYoutube)
      SettingsGroup(
        title: l.newReleasesTitle,
        children: const [ReleaseSettingsTiles()],
      ),
    if (kEnableYoutube)
      SettingsGroup(
        title: l.settingsDownloads,
        children: const [DownloadSettingsTiles()],
      ),
    if (ref.watch(lyricsTranslatorProvider) != null)
      SettingsGroup(
        title: l.translationModels,
        children: const [TranslationModelsTiles()],
      ),
  ];
}

List<SettingsGroup> _network(BuildContext context, WidgetRef ref) {
  final l = context.l10n;
  final s = ref.watch(settingsProvider);
  final notifier = ref.read(settingsProvider.notifier);
  return [
    SettingsGroup(
      title: l.settingsLocalNetwork,
      children: [
        ListTile(
          leading: const Icon(Icons.wifi_tethering),
          title: Text(l.shareTitle),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const ShareScreen())),
        ),
        SwitchListTile(
          title: Text(l.receiveFromLan),
          subtitle: Text(l.receiveFromLanHint),
          value: s.receiveFromLan,
          // The hub reacts to this setting (service, notification, discovery).
          onChanged: (v) =>
              notifier.update((c) => c.copyWith(receiveFromLan: v)),
        ),
        ListTile(
          leading: const Icon(Icons.public),
          title: Text(l.jamRemoteTitle),
          onTap: () => ShellNav.open<void>(context, const JamRemoteSettings()),
        ),
        ownFingerprintTile(context, ref),
        ListTile(
          leading: const Icon(Icons.badge_outlined),
          title: Text(l.shareDeviceName),
          subtitle: Text(ref.watch(deviceNameProvider)),
          onTap: () => _editDeviceName(context, ref),
        ),
      ],
    ),
    ..._trustedGroup(context, ref),
    ...jamGateGroups(context, ref.read(jamGateProvider)),
    ..._speakerGroup(context),
  ];
}

List<SettingsGroup> _backup(BuildContext context, WidgetRef ref) {
  final l = context.l10n;
  return [
    SettingsGroup(title: l.backupSection, children: backupTiles(context, ref)),
  ];
}

List<SettingsGroup> _advanced(BuildContext context, WidgetRef ref) {
  final l = context.l10n;
  return [
    SettingsGroup(
      title: l.settingsAdvanced,
      children: const [AdvancedSettingsTiles()],
    ),
    SettingsGroup(
      title: l.settingsAbout,
      children: [
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(l.appVersion(kAppVersion)),
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text(l.licenses),
          onTap: () => showLicensePage(context: context),
        ),
        ...updateTiles(context, ref),
        const LogExportTile(),
        const ReportIssueTile(),
      ],
    ),
  ];
}

Future<void> _pickLanguage(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final notifier = ref.read(settingsProvider.notifier);
  final current = ref.read(settingsProvider).language;
  final picked = await showCcSheet<String>(
    context: context,
    builder: (c) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CcDims.gap24,
              CcDims.gap16,
              CcDims.gap24,
              CcDims.gap8,
            ),
            child: Text(
              l.settingsLanguage,
              style: Theme.of(c).textTheme.titleMedium,
            ),
          ),
          for (final e in _languages.entries)
            ListTile(
              title: Text(e.value),
              trailing: e.key == current
                  ? Icon(Icons.check_rounded, color: c.cc.accent)
                  : null,
              onTap: () => Navigator.of(c).pop(e.key),
            ),
        ],
      ),
    ),
  );
  if (picked != null) notifier.update((s) => s.copyWith(language: picked));
}

Future<void> _editDeviceName(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final name = await promptName(
    context,
    initial: ref.read(deviceNameProvider),
    confirmLabel: l.save,
    title: l.shareDeviceName,
    hint: l.shareDeviceName,
  );
  if (name == null) return;
  ref
      .read(settingsProvider.notifier)
      .update((s) => s.copyWith(deviceName: name));
}

Future<void> _clearCovers(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final msg = l.coverCacheCleared;
  final ok = await showConfirm(
    context,
    title: l.confirmClearCoversTitle,
    body: l.confirmClearCoversBody,
    confirmLabel: l.clearCoverCache,
  );
  if (!ok || !context.mounted) return;
  try {
    await ref.read(coverOpsProvider).clearCache();
    ref.invalidate(coverIndexProvider);
  } on Object catch (e, st) {
    AppLog.e('clear covers failed', e, st);
  }
  if (!context.mounted) return;
  showMsg(context, msg);
  await scanWithPermission(ref);
}

/// «Dispositivi fidati»: only once something is paired.
List<SettingsGroup> _trustedGroup(BuildContext context, WidgetRef ref) {
  final tiles = trustedDevicesTiles(context, ref);
  if (tiles.isEmpty) return const [];
  return [SettingsGroup(title: context.l10n.trustedSection, children: tiles)];
}

/// «Jam sulla cassa»: Android only (the Bluetooth outputs come from the native side).
List<SettingsGroup> _speakerGroup(BuildContext context) {
  if (!isAndroid) return const [];
  return [SettingsGroup(title: context.l10n.speakerJamSection, children: const [SpeakerJamTiles()])];
}

/// A (optionally titled) group of settings on a rounded surface.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(CcDims.margin, 20, CcDims.margin, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(
                left: CcDims.gap4,
                bottom: CcDims.gap8,
              ),
              child: Text(
                title!,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          Material(
            color: cc.surface1,
            borderRadius: BorderRadius.circular(CcDims.rCard),
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}
