import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/second_opinion_providers.dart';
import '../../../services/online/enrichment_service.dart' show EnrichField;
import '../../../services/online/second_opinion.dart';
import '../../theme/tokens.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/cc_app_bar.dart';

/// The tracks YouTube Music's second opinion looked at in this session, newest
/// first, each with how it went.
class SecondOpinionLogScreen extends ConsumerWidget {
  const SecondOpinionLogScreen({super.key});

  static String _field(AppLocalizations l, EnrichField f) => switch (f) {
    EnrichField.title => l.fieldTitle,
    EnrichField.artist => l.fieldArtist,
    EnrichField.album => l.fieldAlbum,
    EnrichField.year => l.fieldYear,
    EnrichField.genre => l.fieldGenre,
    EnrichField.trackNumber => l.fieldTrackNumber,
    EnrichField.cover => l.fieldCover,
    EnrichField.lyrics => l.fieldLyrics,
    EnrichField.curiosity => l.curiositySong,
  };

  static String _outcome(AppLocalizations l, SecondOpinionLine e) =>
      switch (e.kind) {
        SecondOpinionKind.confirmed =>
          e.written.isEmpty
              ? l.secondOpinionConfirmed
              : l.secondOpinionConfirmedFields(
                  [
                    for (final f in EnrichField.values)
                      if (e.written.contains(f)) _field(l, f),
                  ].join(', '),
                ),
        SecondOpinionKind.notConfirmed => l.secondOpinionNotConfirmed,
        SecondOpinionKind.networkError => l.secondOpinionNetwork,
        SecondOpinionKind.throttled => l.secondOpinionThrottled,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final log = ref.watch(secondOpinionJobProvider.select((s) => s.log));
    final time = DateFormat.Hm(Localizations.localeOf(context).toLanguageTag());
    return Scaffold(
      appBar: CcAppBar(title: l.secondOpinionLogTitle),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: log.isEmpty
              ? EmptyState(
                  icon: Icons.fact_check_outlined,
                  message: l.secondOpinionLogEmpty,
                )
              : ListView.builder(
                  padding: EdgeInsets.zero.withDock(context),
                  itemExtent: 84,
                  itemCount: log.length,
                  itemBuilder: (_, i) {
                    final e = log[i];
                    final bad =
                        e.kind == SecondOpinionKind.networkError ||
                        e.kind == SecondOpinionKind.throttled;
                    final artist = (e.artist ?? '').trim();
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CcDims.margin,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.bodyLarge,
                          ),
                          Text(
                            '${artist.isEmpty ? '' : '$artist, '}${time.format(e.at)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.bodyMedium?.copyWith(
                              color: cc.textMuted,
                            ),
                          ),
                          Text(
                            _outcome(l, e),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.bodyMedium?.copyWith(
                              color: bad
                                  ? cc.error
                                  : e.kind == SecondOpinionKind.confirmed
                                  ? cc.accentSoft
                                  : cc.textMuted,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
