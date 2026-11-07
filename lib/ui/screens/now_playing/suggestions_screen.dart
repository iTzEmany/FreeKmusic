import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_log.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/shuffle_plus_providers.dart';
import '../../../providers/youtube_providers.dart';
import '../../../services/online/youtube_service.dart';
import '../../../services/shuffle_plus/suggestion_log.dart';
import '../../widgets/confirm.dart';
import '../../widgets/async_body.dart' show RowsLoading;
import '../../widgets/empty_state.dart';
import '../online/online_song_row.dart';
import '../../widgets/cc_app_bar.dart';
import '../../theme/tokens.dart';

/// Newest first; waits for the file to be read.
final suggestionRecordsProvider = FutureProvider.autoDispose<List<SuggestionRecord>>((ref) async {
  final log = ref.watch(suggestionLogProvider);
  await log.load();
  return log.recent;
});

String suggestionOutcomeText(AppLocalizations l, SuggestionOutcome o) => switch (o) {
      SuggestionOutcome.queued => l.suggestionOutcomeQueued,
      SuggestionOutcome.skipped => l.suggestionOutcomeSkipped,
      SuggestionOutcome.heard => l.suggestionOutcomeHeard,
      SuggestionOutcome.downloaded => l.suggestionOutcomeDownloaded,
      SuggestionOutcome.disliked => l.suggestionOutcomeDisliked,
    };

/// The log has no picture or length: the thumbnail is the video's own.
YtResult suggestionResult(SuggestionRecord r) => YtResult(
      id: r.videoId,
      title: r.title,
      channel: r.artist,
      duration: null,
      artists: r.artist.isEmpty ? const [] : [r.artist],
      thumbnailUrl: 'https://i.ytimg.com/vi/${r.videoId}/mqdefault.jpg',
    );

/// «Suggeriti di recente»: what Shuffle+ proposed and how each one ended,
/// with «Ascolta» and «Scarica».
class SuggestionsScreen extends ConsumerWidget {
  const SuggestionsScreen({super.key});

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final ok = await showConfirm(
      context,
      title: l.suggestionsClear,
      body: l.suggestionsClearBody,
      confirmLabel: l.suggestionsClear,
      destructive: true,
    );
    if (!ok) return;
    // The list is empty at once; the file is rewritten meanwhile.
    final written = ref.read(suggestionLogProvider).clear();
    ref.invalidate(suggestionRecordsProvider);
    await written;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final records = ref.watch(suggestionRecordsProvider);
    final hasAny = records.value?.isNotEmpty ?? false;
    return Scaffold(
      appBar: CcAppBar(
        title: l.suggestionsRecentTitle,
        actions: [
          if (hasAny)
            IconButton(
              tooltip: l.suggestionsClear,
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _clear(context, ref),
            ),
        ],
      ),
      body: records.when(
        loading: () => RowsLoading(rowHeight: onlineRowExtentOf(context)),
        error: (e, st) {
          AppLog.w('suggestions load failed', e, st);
          return EmptyState(icon: Icons.error_outline, message: l.suggestionsRecentEmpty);
        },
        data: (list) => list.isEmpty
            ? EmptyState(icon: Icons.cloud_outlined, message: l.suggestionsRecentEmpty)
            : ListView.builder(
                padding: EdgeInsets.zero.withDock(context),
                itemCount: list.length,
                itemExtent: onlineRowExtentOf(context),
                itemBuilder: (_, i) => _SuggestionRow(record: list[i]),
              ),
      ),
    );
  }
}

class _SuggestionRow extends ConsumerWidget {
  const _SuggestionRow({required this.record});

  final SuggestionRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final result = suggestionResult(record);
    final inLibrary = ref.watch(downloadIndexProvider).value?.contains(result.id, source: result.source) ??
        false;
    final item = ref.watch(downloadsProvider.select((d) => d.where((x) => x.result.id == result.id).lastOrNull));
    return OnlineSongRow(
      result: result,
      inLibrary: inLibrary,
      item: item,
      square: true,
      note: l.suggestionsRowNote(record.seedTitle, suggestionOutcomeText(l, record.outcome)),
      onDownload: () {
        ref.read(downloadsProvider.notifier).add(result);
        ref.read(suggestionLogProvider).setOutcome(result.id, SuggestionOutcome.downloaded);
        ref.invalidate(suggestionRecordsProvider);
      },
      listen: IconButton(
        key: ValueKey('listen-${result.indexKey}'),
        tooltip: l.listenAction,
        icon: const Icon(Icons.headphones_rounded),
        onPressed: () => tapOnline(context, ref, result),
      ),
    );
  }
}

/// Opens the screen from a menu or a sheet.
Future<void> openSuggestions(BuildContext context) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => const SuggestionsScreen()));
