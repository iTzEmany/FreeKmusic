import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_log.dart';
import '../../../data/db/app_database.dart';
import '../../../l10n/app_localizations.dart' show AppLocalizations;
import '../../../l10n/l10n_ext.dart';
import '../../../providers/curiosity_provider.dart';
import '../../../providers/database_providers.dart';
import '../../../providers/player_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/translation_providers.dart';
import '../../../services/online/lrc_parser.dart';
import '../../../services/online/lyrics_translator.dart';
import '../../../services/online/query_cleaner.dart';
import '../../theme/tokens.dart';
import '../../widgets/skeleton.dart';
import '../lyrics/lyrics_screen.dart';
import '../lyrics/lyrics_translate_flow.dart';
import 'proposal_card.dart' show CoverLine;
import 'queue_sheet.dart';
import '../../widgets/track_art.dart';
import '../../widgets/show_msg.dart';

/// The titled rounded card of the player (the Jam reuses it for its text cards).
class NpCard extends StatelessWidget {
  const NpCard({super.key, required this.title, required this.child, this.onTap});

  final String title;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    return Material(
      color: cc.surface1,
      borderRadius: BorderRadius.circular(CcDims.rCard),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(CcDims.gap16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

void _openLyrics(BuildContext context) => Navigator.of(
  context,
  rootNavigator: true,
).push(MaterialPageRoute<void>(builder: (_) => const LyricsScreen()));

/// Five lines around the current one; tap opens the full lyrics.
class LyricsCard extends ConsumerWidget {
  const LyricsCard({super.key, required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final synced = track.lyricsSynced;
    final lines = synced == null ? const <LrcLine>[] : parseLrc(synced);
    Widget body;
    if (lines.isNotEmpty) {
      body = _SyncedLines(lines: lines);
    } else if (track.lyricsPlain != null) {
      body = Text(
        track.lyricsPlain!,
        maxLines: 5,
        overflow: TextOverflow.ellipsis,
        strutStyle: _lyricsStrut(theme),
        style: _lyricsStyle(theme),
      );
    } else {
      body = Row(
        children: [
          Expanded(
            child: Text(
              l.noLyrics,
              style: theme.bodyMedium?.copyWith(color: cc.textMuted),
            ),
          ),
          OutlinedButton(
            onPressed: () => _openLyrics(context),
            child: Text(l.searchLyrics),
          ),
        ],
      );
    }
    return NpCard(
      title: l.lyrics,
      onTap: () => _openLyrics(context),
      // Fixed 5-line body: the cards below never jump (F-58, D-161).
      child: SizedBox(
        height: _lyricsRowHeight(context) * 5,
        child: Align(alignment: Alignment.topLeft, child: body),
      ),
    );
  }
}

const _lyricsLineHeight = 1.5;

/// One line (strut height) plus 2 dp of air above and below.
double _lyricsRowHeight(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(
          _lyricsFontSize(Theme.of(context).textTheme),
        ) *
        _lyricsLineHeight +
    4;

double _lyricsFontSize(TextTheme t) => t.bodyLarge?.fontSize ?? 16;

TextStyle? _lyricsStyle(TextTheme t) =>
    t.bodyLarge?.copyWith(height: _lyricsLineHeight);

// Forced strut: every line is exactly as tall, whatever glyph (note) it holds.
StrutStyle _lyricsStrut(TextTheme t) => StrutStyle(
  fontSize: _lyricsFontSize(t),
  height: _lyricsLineHeight,
  forceStrutHeight: true,
);

class _SyncedLines extends ConsumerWidget {
  const _SyncedLines({required this.lines});

  final List<LrcLine> lines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cc = context.cc;
    // Only rebuilds when the current line changes, not on every tick.
    final index = ref.watch(
      positionProvider.select(
        (p) => currentLrcIndex(lines, p.value ?? Duration.zero),
      ),
    );
    final center = index < 0 ? 0 : index;
    // Near the end the window moves back instead of getting shorter.
    final from = (center - 2).clamp(0, math.max(0, lines.length - 5)).toInt();
    final to = (from + 5).clamp(0, lines.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = from; i < to; i++)
          SizedBox(
            height: _lyricsRowHeight(context),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                lines[i].text.isEmpty ? '♪' : lines[i].text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                strutStyle: _lyricsStrut(Theme.of(context).textTheme),
                style: _lyricsStyle(Theme.of(context).textTheme)?.copyWith(
                  fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                  color: i == index ? cc.text : cc.textMuted,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Wikipedia trivia about the song and about the artist, fetched only on an
/// explicit tap. The song's lives on the track, the artist's is shared by all
/// the tracks of that artist.
class InfoCard extends ConsumerStatefulWidget {
  const InfoCard({super.key, required this.track});

  final Track track;

  @override
  ConsumerState<InfoCard> createState() => _InfoCardState();
}

class _InfoCardState extends ConsumerState<InfoCard> {
  Future<void> _fetch() async {
    final l = context.l10n;
    final out = await ref.read(curiosityProvider(widget.track.id).notifier).fetch(widget.track);
    if (!mounted) return;
    if (out.limited || out.failed || out.nothing) {
      showMsg(context, out.limited || out.failed ? l.serviceUnavailable : l.noResults);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final t = widget.track;
    final cleaned = cleanSearchQuery(t.title, t.artist ?? '');
    final artistInfo = ref.watch(artistInfoProvider(cleaned.artist)).value;
    final raw = t.curiosities;
    final search = ref.watch(curiosityProvider(t.id));
    final loading = search.isLoading;
    final outcome = search.value;
    final searched = outcome != null;
    final spinner = const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
    if (raw == null && artistInfo == null && !searched) {
      return NpCard(
        title: l.fieldCuriosity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverLine(trackId: t.id),
            loading
                ? spinner
                : OutlinedButton(
                    onPressed: _fetch,
                    child: Text(l.searchCuriosity),
                  ),
          ],
        ),
      );
    }
    final muted = Theme.of(context).textTheme.bodyMedium?.copyWith(color: cc.textMuted);
    final idx = raw?.lastIndexOf('\n') ?? -1;
    return NpCard(
      title: l.fieldCuriosity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoverLine(trackId: t.id),
          if (raw != null)
            _CuriosityText(
              heading: l.curiositySong,
              text: idx > 0 ? raw.substring(0, idx) : raw,
              url: idx > 0 ? raw.substring(idx + 1) : null,
              lang: wikiLangOf(idx > 0 ? raw.substring(idx + 1) : null),
            )
          else
            Text(
              (outcome?.songLimited ?? false) ? l.serviceUnavailable : l.curiosityNoSong,
              key: const ValueKey('curiosity-no-song'),
              style: muted,
            ),
          const SizedBox(height: 16),
          if (artistInfo != null)
            _CuriosityText(
              heading: l.curiosityArtist,
              text: artistInfo.body,
              url: artistInfo.sourceUrl,
              lang: artistInfo.lang,
            )
          else
            Text(
              cleaned.artist.isEmpty
                  ? l.unknownArtist
                  : (outcome?.artistLimited ?? false)
                  ? l.serviceUnavailable
                  : l.curiosityNoArtist,
              key: const ValueKey('curiosity-no-artist'),
              style: muted,
            ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: loading
                ? Padding(padding: const EdgeInsets.all(CcDims.gap8), child: spinner)
                : TextButton(onPressed: _fetch, child: Text(l.retry)),
          ),
        ],
      ),
    );
  }
}

/// `it` for `https://it.wikipedia.org/wiki/…`; null when it cannot be told.
String? wikiLangOf(String? url) {
  final host = url == null ? null : Uri.tryParse(url.trim())?.host;
  final m = host == null ? null : RegExp(r'^([a-z-]+)\.wikipedia\.org$').firstMatch(host);
  return m?.group(1);
}

/// One block of trivia: a heading, the text (a few lines, all of it on a tap or
/// on «Mostra tutto») and where it comes from. When it is in another language
/// than the app's and the phone can translate, «Traduci» shows it translated.
class _CuriosityText extends ConsumerStatefulWidget {
  const _CuriosityText({
    required this.heading,
    required this.text,
    this.url,
    this.lang,
  });

  final String heading, text;
  final String? url;

  /// Language of [text] (Wikipedia's code), if known.
  final String? lang;

  @override
  ConsumerState<_CuriosityText> createState() => _CuriosityTextState();
}

class _CuriosityTextState extends ConsumerState<_CuriosityText> {
  static const _collapsedLines = 5;
  bool _open = false;
  bool _busy = false;
  String? _translated;

  @override
  void didUpdateWidget(_CuriosityText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _translated = null; // a new search brought other text
  }

  Future<void> _translate(String from, String to) async {
    final translator = ref.read(lyricsTranslatorProvider);
    if (translator == null) return;
    final l = context.l10n;
    setState(() => _busy = true);
    var ok = false;
    try {
      if (!await ensureTranslationModels(context, translator, [from, to])) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      // Paragraphs one by one: the model keeps the sense of each.
      final parts = widget.text.split('\n');
      final out = await translateKeepingLayout(translator, parts, from: from, to: to);
      if (mounted) setState(() => _translated = out.join('\n'));
      ok = true;
    } on Object catch (e, st) {
      AppLog.e('curiosity translation failed', e, st);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      showMsg(context, l.translateFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final style = theme.bodyLarge;
    final appLang = ref.watch(settingsProvider).language;
    final from = widget.lang;
    final canTranslate = ref.watch(lyricsTranslatorProvider) != null &&
        from != null &&
        from != appLang &&
        translationLanguages.containsKey(from) &&
        translationLanguages.containsKey(appLang);
    final shown = _translated ?? widget.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.heading,
          style: theme.labelLarge?.copyWith(color: cc.accentSoft),
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, box) {
            // Is the text longer than the collapsed height? Then it can grow.
            final painter = TextPainter(
              text: TextSpan(text: shown, style: style),
              maxLines: _collapsedLines,
              textDirection: Directionality.of(context),
            )..layout(maxWidth: box.maxWidth);
            final longer = painter.didExceedMaxLines;
            painter.dispose();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: longer ? () => setState(() => _open = !_open) : null,
                  child: AnimatedSize(
                    duration: ccDuration(context, CcMotion.enter),
                    alignment: Alignment.topCenter,
                    child: Text(
                      shown,
                      maxLines: _open ? null : _collapsedLines,
                      overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis,
                      style: style,
                    ),
                  ),
                ),
                Wrap(
                  children: [
                    if (longer)
                      TextButton(
                        onPressed: () => setState(() => _open = !_open),
                        child: Text(_open ? l.showLess : l.showMore),
                      ),
                    if (canTranslate)
                      _busy
                          ? const Padding(
                              padding: EdgeInsets.all(CcDims.gap12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : TextButton.icon(
                              key: const ValueKey('curiosity-translate'),
                              onPressed: _translated == null
                                  ? () => _translate(from, appLang)
                                  : () => setState(() => _translated = null),
                              icon: Icon(
                                _translated == null ? Icons.translate_rounded : Icons.undo_rounded,
                                size: 18,
                              ),
                              label: Text(
                                _translated == null ? l.translateLyrics : l.translateRemove,
                              ),
                            ),
                  ],
                ),
              ],
            );
          },
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                switch (Uri.tryParse(widget.url ?? '')?.host) {
                  final h? when h.endsWith('discogs.com') => l.curiositySourceDiscogs,
                  final h? when h.endsWith('youtube.com') => l.sourceYoutubeMusic,
                  _ => l.sourceWikipedia,
                },
                style: theme.labelSmall?.copyWith(color: cc.textMuted),
              ),
            ),
            if (widget.url != null)
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: widget.url!));
                  if (!context.mounted) return;
                  showMsg(context, l.copied);
                },
                child: Text(l.copyLink),
              ),
          ],
        ),
      ],
    );
  }
}

/// The next three tracks of the queue and a shortcut to the full queue.
class UpNextCard extends ConsumerWidget {
  const UpNextCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final queue = ref.watch(queueProvider).value ?? const <Track>[];
    ref.watch(currentTrackProvider.select((t) => t.value?.id));
    final at = ref.read(audioHandlerProvider).currentIndex;
    final next = at < 0 ? const <Track>[] : queue.skip(at + 1).take(3).toList();
    return NpCard(
      title: l.upNext,
      onTap: () => showQueueSheet(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (next.isEmpty)
            Text(
              l.emptyQueue,
              style: theme.bodyMedium?.copyWith(color: cc.textMuted),
            ),
          for (final t in next)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: CcDims.gap4),
              child: Row(
                children: [
                  TrackArt(track: t, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.bodyLarge,
                        ),
                        Text(
                          t.artist ?? l.unknownArtist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => showQueueSheet(context),
              child: Text(l.openQueue),
            ),
          ),
        ],
      ),
    );
  }
}

/// Height of one line of [style] at the user's text scale.
double _lineOf(BuildContext context, TextStyle? style) {
  final p = TextPainter(
    text: TextSpan(text: 'A', style: style),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final h = p.height;
  p.dispose();
  return h;
}

/// A streamed track's cards before its data row exists: skeletons with the
/// shape and height of the real ones (no jump on arrival); after 20 s a single
/// «Non disponibile» card with Riprova (F-52). [infoOnly] is the side panel's.
class StreamCardsWait extends ConsumerStatefulWidget {
  const StreamCardsWait({super.key, required this.trackId, this.infoOnly = false});

  static const wait = Duration(seconds: 20);
  /// The queue id of the streamed track (negative).
  final int trackId;
  final bool infoOnly;

  @override
  ConsumerState<StreamCardsWait> createState() => _StreamCardsWaitState();
}

class _StreamCardsWaitState extends ConsumerState<StreamCardsWait> {
  Timer? _timer;
  bool _late = false;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  void _arm() {
    _timer?.cancel();
    _timer = Timer(StreamCardsWait.wait, () => setState(() => _late = true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _retry() {
    setState(() => _late = false);
    _arm();
    // A sibling widget on this track may still watch the wait: it starts over too.
    ref.invalidate(shadowWaitProvider(widget.trackId));
    unawaited(
      ref.read(playerControllerProvider).retryShadow().catchError((Object e, StackTrace st) {
        AppLog.w('stream cards retry failed', e, st);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    if (!_late) return _skeleton(context);
    // A slow but working download keeps the skeleton: the row is made when the file is whole.
    final wait = ref.watch(shadowWaitProvider(widget.trackId)).value;
    return wait == ShadowWait.unavailable ? _unavailable(l, t) : _skeleton(context);
  }

  Widget _unavailable(AppLocalizations l, TextTheme t) => NpCard(
    title: l.streamCardsUnavailable,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.streamCardsUnavailableBody, style: t.bodyMedium?.copyWith(color: context.cc.textMuted)),
        TextButton.icon(onPressed: _retry, icon: const Icon(Icons.refresh), label: Text(l.retry)),
      ],
    ),
  );

  Widget _skeleton(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final body = _lineOf(context, t.bodyLarge);
    // Same blocks as InfoCard: heading, 5 lines, the «show more» and source rows.
    final block = [
      Skeleton.card(lines: 1, lineHeight: _lineOf(context, t.labelLarge)),
      const SizedBox(height: 4),
      Skeleton.card(lines: 5, lineHeight: body),
      const SizedBox(height: 96),
    ];
    final info = NpCard(
      title: l.fieldCuriosity,
      child: Column(
        children: [
          ...block,
          const SizedBox(height: 16),
          ...block,
          const SizedBox(height: 52),
        ],
      ),
    );
    return Semantics(
      label: l.loadingContent,
      liveRegion: true,
      child: ExcludeSemantics(
        child: widget.infoOnly
            ? info
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NpCard(
                    title: l.lyrics,
                    child: Skeleton.card(lines: 5, lineHeight: _lyricsRowHeight(context)),
                  ),
                  const SizedBox(height: 12),
                  info,
                  const SizedBox(height: 12),
                  NpCard(
                    title: l.creditsTitle,
                    child: Column(
                      children: [
                        // The group heading of the real rows.
                        SizedBox(height: 16 + _lineOf(context, t.labelLarge)),
                        const Skeleton.card(lines: 3, roles: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
      ),
    );
  }
}
