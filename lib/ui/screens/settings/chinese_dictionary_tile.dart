import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_log.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/chinese_dictionary_providers.dart';
import '../../widgets/confirm.dart';
import '../../widgets/format_utils.dart';
import '../../widgets/show_msg.dart';

/// The CC-CEDICT dictionary of the Chinese transliteration: state, «Scarica»
/// when missing, «Elimina» when there (D-476).
class ChineseDictionaryTile extends ConsumerWidget {
  const ChineseDictionaryTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final d = ref.watch(chineseDictionaryProvider);
    final notifier = ref.read(chineseDictionaryProvider.notifier);
    final locale = Localizations.localeOf(context).toString();
    final busy = d.status == ChineseDictionaryStatus.downloading;
    final ready = d.status == ChineseDictionaryStatus.ready;
    return ListTile(
      key: const ValueKey('chinese-dictionary'),
      leading: const Icon(Icons.translate_rounded),
      title: Text(l.chineseDictionary),
      subtitle: Text(switch (d.status) {
        ChineseDictionaryStatus.ready => formatBytes(d.sizeBytes, locale),
        ChineseDictionaryStatus.downloading => l.chineseDictionaryDownloading,
        ChineseDictionaryStatus.error => l.chineseDictionaryError,
        ChineseDictionaryStatus.notDownloaded =>
          '${l.chineseDictionaryNone}. ${l.chineseDictionaryHint}',
      }),
      trailing: busy
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                value: d.progress,
                semanticsLabel: l.chineseDictionaryDownloading,
              ),
            )
          : ready
          ? IconButton(
              tooltip: l.chineseDictionaryDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                final ok = await showConfirm(
                  context,
                  title: l.chineseDictionaryDeleteTitle,
                  body: l.chineseDictionaryDeleteBody,
                  confirmLabel: l.delete,
                  destructive: true,
                );
                if (!ok) return;
                try {
                  await notifier.delete();
                } on Object catch (e, st) {
                  AppLog.e('delete Chinese dictionary failed', e, st);
                  if (context.mounted) {
                    showMsg(context, l.chineseDictionaryDeleteFailed);
                  }
                }
              },
            )
          : TextButton(
              onPressed: () => notifier.ensure(download: true),
              child: Text(l.chineseDictionaryDownload),
            ),
    );
  }
}
