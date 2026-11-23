import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_log.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/chinese_dictionary_providers.dart';
import '../../../providers/model_catalog_providers.dart';
import '../../../providers/shuffle_plus_providers.dart' show networkProbeProvider;
import '../../shell/shell_nav.dart';
import '../../theme/tokens.dart';
import '../../widgets/cc_app_bar.dart';
import '../../widgets/confirm.dart';
import '../../widgets/format_utils.dart';
import '../../widgets/show_msg.dart';

String _key(ModelEntry e) => '${e.kind.name}:${e.id}';

/// The one entry of Settings → Online for models and dictionaries (D-673):
/// a summary that opens [ModelsScreen].
class ModelsTile extends ConsumerWidget {
  const ModelsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final entries = ref.watch(modelCatalogProvider).value;
    final locale = Localizations.localeOf(context).toString();
    return ListTile(
      key: const ValueKey('models-tile'),
      leading: const Icon(Icons.model_training_rounded),
      title: Text(l.modelsTitle),
      subtitle: entries == null
          ? null
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
  final _busy = <String>{};

  Future<void> _download(List<ModelEntry> targets) async {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final size = formatBytes(targets.fold(0, (s, e) => s + e.bytes), locale);
    // D-656: on a metered network the size is asked before downloading.
    final metered = (await ref.read(networkProbeProvider).current()).metered;
    if (!mounted) return;
    final ok = await showConfirm(
      context,
      title: l.modelsDownloadTitle,
      body: metered ? l.modelsDownloadMeteredBody(size) : l.modelsDownloadBody(size),
      confirmLabel: l.chineseDictionaryDownload,
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(modelCatalogProvider.notifier);
    setState(() => _busy.addAll(targets.map(_key)));
    // One at a time: the models are large and share the network.
    for (final e in targets) {
      try {
        await notifier.download(e);
      } on Object catch (_) {
        // Already logged by the catalog; tell the user and go on with the rest.
        showMsgOn(messenger, l.modelsDownloadFailed(e.name));
      }
      if (mounted) {
        setState(() {
          _busy.remove(_key(e));
          _selected.remove(_key(e));
        });
      }
    }
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
    for (final e in targets) {
      try {
        await notifier.delete(e);
      } on Object catch (err, st) {
        AppLog.w('models screen: delete ${e.id} failed', err, st);
        showMsgOn(messenger, l.modelsDeleteFailed(e.name));
      }
      if (mounted) setState(() => _selected.remove(_key(e)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final entries = ref.watch(modelCatalogProvider).value;
    final dict = ref.watch(chineseDictionaryProvider);
    final theme = Theme.of(context).textTheme;
    if (entries == null) {
      return Scaffold(
        appBar: CcAppBar(title: l.modelsTitle),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final picked = [for (final e in entries) if (_selected.contains(_key(e))) e];
    final toDownload = picked.where((e) => !e.installed).toList();
    final toDelete = picked.where((e) => e.installed).toList();
    final working = _busy.isNotEmpty;

    Widget section(String title, ModelKind kind) {
      final items = entries.where((e) => e.kind == kind).toList();
      if (items.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(CcDims.margin, CcDims.gap16, CcDims.margin, CcDims.gap4),
            child: Semantics(header: true, child: Text(title, style: theme.titleSmall)),
          ),
          for (final e in items) _row(l, locale, e, dict),
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
                  padding: const EdgeInsets.fromLTRB(CcDims.margin, CcDims.gap16, CcDims.margin, 0),
                  child: Text(
                    l.modelsUsed(formatBytes(installedModelsBytes(entries), locale)),
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
                    onPressed: toDownload.isEmpty || working ? null : () => _download(toDownload),
                    child: Text(l.modelsDownloadSelected(toDownload.length)),
                  ),
                  OutlinedButton(
                    key: const ValueKey('models-delete'),
                    onPressed: toDelete.isEmpty || working ? null : () => _delete(toDelete),
                    child: Text(l.modelsDeleteSelected(toDelete.length)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(AppLocalizations l, String locale, ModelEntry e, ChineseDictionaryState dict) {
    final k = _key(e);
    final busy = _busy.contains(k);
    final size = formatBytes(e.bytes, locale);
    return CheckboxListTile(
      key: ValueKey('model-$k'),
      value: _selected.contains(k),
      onChanged: busy
          ? null
          : (v) => setState(() => v == true ? _selected.add(k) : _selected.remove(k)),
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(e.name),
      subtitle: Text(
        busy
            ? l.modelsDownloading
            : e.installed
            ? l.modelsInstalledSize(size)
            : l.modelsNotInstalledSize(size),
      ),
      secondary: busy
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
              onPressed: () => _delete([e]),
            )
          : null,
    );
  }
}
