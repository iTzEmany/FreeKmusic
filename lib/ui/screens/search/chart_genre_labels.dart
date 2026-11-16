import '../../../l10n/app_localizations.dart';

/// Name of a macro-genre in the app's language (D-591).
String chartGenreLabel(AppLocalizations l, String id) => switch (id) {
      'pop' => l.chartGenrePop,
      'rap' => l.chartGenreRap,
      'rock' => l.chartGenreRock,
      'dance' => l.chartGenreDance,
      'rnb' => l.chartGenreRnb,
      'latin' => l.chartGenreLatin,
      'italian' => l.chartGenreItalian,
      'indie' => l.chartGenreIndie,
      'jazz' => l.chartGenreJazz,
      'classical' => l.chartGenreClassical,
      'metal' => l.chartGenreMetal,
      _ => l.chartGenreCountry,
    };
