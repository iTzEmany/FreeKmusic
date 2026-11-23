import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_log.dart';
import '../../../core/network_kind.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/chinese_dictionary_providers.dart';
import '../../../providers/model_catalog_providers.dart';
import '../../../providers/shuffle_plus_providers.dart'
    show networkProbeProvider;
import '../../shell/shell_nav.dart';
import '../../theme/tokens.dart';
import '../../widgets/cc_app_bar.dart';
import '../../widgets/confirm.dart';
import '../../widgets/format_utils.dart';
import '../../widgets/show_msg.dart';

/// The one entry of Settings → Online for models and dictionaries (D-673):
/// a summary that opens [ModelsScreen].
class ModelsTile extends ConsumerWidget {
  const ModelsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final catalog = ref.watch(modelCatalogProvider);
    final entries = catalog.value;
    final locale = Localizations.localeOf(context).toString();
    return ListTile(
      key: const ValueKey('models-tile'),
      leading: const Icon(Icons.model_training_rounded),
      title: Text(l.modelsTitle),
      subtitle: entries == null
          ? (catalog.hasError ? Text(l.modelsLoadFailed) : null)
          : Text(
              l.modelsSummary(
                entries.where((e) => e.installed).length,
                formatBytes(installedModelsBytes(entries), locale),
              ),
            ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => ShellNav.open<void>(context, const ModelsScreen()),
    );
  }
}

/// Settings → Modelli e dizionari: every downloadable model with a checkbox,
/// «Scarica selezionati» / «Elimina selezionati» and the space they take.
class ModelsScreen extends ConsumerStatefulWidget {
  const ModelsScreen({super.key});

  @override
  ConsumerState<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends ConsumerState<ModelsScreen> {
  final _selected = <String>{};

  var _asking = false; // network probe or confirm dialog open
  var _deleting = false;

  Future<void> _download(List<ModelEntry> targets) async {
    if (_asking) return;
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final size = formatBytes(targets.fold(0, (s, e) => s + e.bytes), locale);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _asking = true);
    try {
      // D-656: on a metered network the size is asked before downloading.
      var net = const NetworkKind();
      try {
        net = await ref.read(networkProbeProvider).current();
      } on Object catch (e, st) {
        AppLog.w('models screen: network probe failed', e, st);
      }
      if (!mounted) return;
      // Offline, an ML Kit download would stay «in progress» for ever.
      if (!net.online) {
        showMsgOn(messenger, l.modelsOffline);
        return;
      }
      final ok = await showConfirm(
        context,
        title: l.modelsDownloadTitle,
        body: net.metered
            ? l.modelsDownloadMeteredBody(size)
            : l.modelsDownloadBody(size),
        confirmLabel: l.chineseDictionaryDownload,
      );
      if (!ok || !mounted) return;
    } finally {
      if (mounted) setState(() => _asking = false);
    }
    // The queue is the notifier's: it goes on when this page is left.
    unawaited(
      ref
          .read(modelQueueProvider.notifier)
          .downloadAll(
            targets,
            onFailed: (e) =>
                showMsgOn(messenger, l.modelsDownloadFailed(e.name)),
            onDone: (e) {
              if (mounted) setState(() => _selected.remove(modelKey(e)));
            },
          ),
    );
  }

  Future<void> _delete(List<ModelEntry> targets) async {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final size = formatBytes(targets.fold(0, (s, e) => s + e.bytes), locale);
    final ok = await showConfirm(
      context,
      title: l.modelsDeleteTitle,
      body: l.modelsDeleteBody(size),
      confirmLabel: l.delete,
      destructive: true,
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(modelCatalogProvider.notifier);
    setState(() => _deleting = true);
    try {
      for (final e in targets) {
        var done = false;
        try {
          await notifier.delete(e);
          done = true;
        } on Object catch (err, st) {
          AppLog.w('models screen: delete ${e.id} failed', err, st);
          showMsgOn(messenger, l.modelsDeleteFailed(e.name));
        }
        if (done && mounted) setState(() => _selected.remove(modelKey(e)));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final catalog = ref.watch(modelCatalogProvider);
    final entries = catalog.value;
    final dict = ref.watch(chineseDictionaryProvider);
    final queue = ref.watch(modelQueueProvider);
    final theme = Theme.of(context).textTheme;
    if (entries == null) {
      return Scaffold(
        appBar: CcAppBar(title: l.modelsTitle),
        body: Center(
          child: catalog.hasError
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l.modelsLoadFailed,
                      key: const ValueKey('models-error'),
                    ),
                    TextButton(
                      onPressed: () => ref.invalidate(modelCatalogProvider),
                      child: Text(l.retry),
                    ),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      );
    }
    _selected.retainAll(entries.map(modelKey));
    final dictBusy = dict.status == ChineseDictionaryStatus.downloading;
    final picked = [
      for (final e in entries)
        if (_selected.contains(modelKey(e))) e,
    ];
    final toDownload = picked.where((e) => !e.installed).toList();
    final toDelete = picked.where((e) => e.installed).toList();
    // Also a dictionary fetched by a lyrics page counts as «in progress».
    final working = queue.active || _asking || _deleting || dictBusy;

    Widget section(String title, ModelKind kind) {
      final items = entries.where((e) => e.kind == kind).toList();
      if (items.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CcDims.margin,
              CcDims.gap16,
              CcDims.margin,
              CcDims.gap4,
            ),
            child: Semantics(
              header: true,
              child: Text(title, style: theme.titleSmall),
            ),
          ),
          for (final e in items) _row(l, locale, e, dict, queue),
        ],
      );
    }

    return Scaffold(
      appBar: CcAppBar(title: l.modelsTitle),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    CcDims.margin,
                    CcDims.gap16,
                    CcDims.margin,
                    0,
                  ),
                  child: Text(
                    l.modelsUsed(
                      formatBytes(installedModelsBytes(entries), locale),
                    ),
                    key: const ValueKey('models-used'),
                    style: theme.bodyLarge,
                  ),
                ),
                section(l.translationModels, ModelKind.translation),
                section(l.chineseDictionary, ModelKind.dictionary),
                section(l.karaoke, ModelKind.karaoke),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(CcDims.gap8),
              child: Wrap(
                spacing: CcDims.gap8,
                runSpacing: CcDims.gap8,
                children: [
                  FilledButton(
                    key: const ValueKey('models-download'),
                    onPressed: toDownload.isEmpty || working
                        ? null
                        : () => _download(toDownload),
                    child: Text(l.modelsDownloadSelected(toDownload.length)),
                  ),
                  OutlinedButton(
                    key: const ValueKey('models-delete'),
                    onPressed: toDelete.isEmpty || working
                        ? null
                        : () => _delete(toDelete),
                    child: Text(l.modelsDeleteSelected(toDelete.length)),
                  ),
                  if (queue.queued.isNotEmpty)
                    TextButton(
                      key: const ValueKey('models-cancel'),
                      onPressed: () {
                        ref.read(modelQueueProvider.notifier).cancelQueued();
                        showMsg(context, l.modelsCancelled);
                      },
                      child: Text(l.cancel),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    AppLocalizations l,
    String locale,
    ModelEntry e,
    ChineseDictionaryState dict,
    ModelQueueState queue,
  ) {
    final k = modelKey(e);
    final fromElsewhere =
        e.kind == ModelKind.dictionary &&
        dict.status == ChineseDictionaryStatus.downloading;
    final running = queue.running == k || fromElsewhere;
    final queued = queue.queued.contains(k);
    final busy = running || queued;
    final size = formatBytes(e.bytes, locale);
    final failed =
        e.kind == ModelKind.dictionary &&
        dict.status == ChineseDictionaryStatus.error &&
        !e.installed;
    final status = running
        ? l.modelsDownloading
        : queued
        ? l.modelsQueued
        : failed
        ? l.modelsDownloadFailed(e.name)
        : e.installed
        ? l.modelsInstalledSize(size)
        : l.modelsNotInstalledSize(size);
    final working = queue.active || _asking || _deleting || fromElsewhere;
    void toggle(bool? v) =>
        setState(() => v == true ? _selected.add(k) : _selected.remove(k));
    final picked = _selected.contains(k);
    // One stop for the row (name, state, checked); the trash stays a button of its own.
    return Semantics(
      checked: picked,
      child: ListTile(
        key: ValueKey('model-$k'),
        leading: ExcludeSemantics(
          child: Checkbox(value: picked, onChanged: busy ? null : toggle),
        ),
        onTap: busy ? null : () => toggle(!picked),
        title: Text(e.name),
        subtitle: Semantics(liveRegion: true, child: Text(status)),
        // The trash is a button of its own (a merged checkbox tile hid it from TalkBack).
        trailing: running
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  // Only the dictionary reports progress.
                  value: e.kind == ModelKind.dictionary ? dict.progress : null,
                  semanticsLabel: l.modelsDownloading,
                ),
              )
            : e.installed
            ? IconButton(
                tooltip: l.modelsDeleteOne(e.name),
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: working ? null : () => _delete([e]),
              )
            : null,
      ),
    );
  }
}
