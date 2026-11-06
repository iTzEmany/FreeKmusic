import 'package:flutter/widgets.dart' show BuildContext;

import '../../../l10n/app_localizations.dart';
import '../../../services/online/youtube_service.dart' show YtErrorKind;
import '../youtube/online_results.dart' show ytErrorText;
import '../../../services/podcast/apple_podcasts.dart' show PodcastGenre;
import '../../../services/podcast/podcast_models.dart';

/// Why a podcast operation failed, in words.
String podcastErrorText(AppLocalizations l, PodcastErrorKind kind) => switch (kind) {
  PodcastErrorKind.invalidUrl => l.podcastErrInvalidUrl,
  PodcastErrorKind.tooLarge => l.podcastErrTooLarge,
  PodcastErrorKind.network => l.podcastErrNetwork,
  PodcastErrorKind.notFeed => l.podcastErrNotFeed,
  PodcastErrorKind.unsupportedFormat => l.podcastErrUnsupportedFormat,
};

/// A top-level Apple genre in the app language; an id not listed keeps Apple's name.
String podcastGenreName(AppLocalizations l, PodcastGenre g) => switch (g.id) {
  '1301' => l.podcastGenreArts,
  '1321' => l.podcastGenreBusiness,
  '1303' => l.podcastGenreComedy,
  '1304' => l.podcastGenreEducation,
  '1305' => l.podcastGenreKids,
  '1307' => l.podcastGenreHealth,
  '1309' => l.podcastGenreTvFilm,
  '1310' => l.podcastGenreMusic,
  '1311' || '1489' => l.podcastGenreNews,
  '1314' => l.podcastGenreReligion,
  '1315' => l.podcastGenreScience,
  '1316' => l.podcastGenreSports,
  '1318' => l.podcastGenreTechnology,
  '1324' => l.podcastGenreSociety,
  '1325' => l.podcastGenreGovernment,
  '1487' => l.podcastGenreHistory,
  '1488' => l.podcastGenreTrueCrime,
  _ => g.name,
};

/// A failure in words: a YouTube Music / yt-dlp one (when [yt] is set) in the
/// words of the rest of the app, any other in the podcast ones.
String podcastFailureText(BuildContext context, AppLocalizations l, PodcastErrorKind kind, YtErrorKind? yt) =>
    yt == null ? podcastErrorText(l, kind) : ytErrorText(context, yt);

/// «Riprova» only makes sense when waiting or trying again can change the answer.
bool podcastCanRetry(YtErrorKind? yt) => yt == null || yt == YtErrorKind.network || yt == YtErrorKind.rateLimited;
