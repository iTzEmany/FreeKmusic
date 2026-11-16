import 'package:flutter/material.dart';

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

/// Tile colours: mid tones that keep white text above 4.5:1.
const chartGenreColors = <String, Color>{
  'pop': Color(0xFFC2185B),
  'rap': Color(0xFF6A1B9A),
  'rock': Color(0xFFB71C1C),
  'dance': Color(0xFF00695C),
  'rnb': Color(0xFF4527A0),
  'latin': Color(0xFFD84315),
  'italian': Color(0xFF1B5E20),
  'indie': Color(0xFF0D47A1),
  'jazz': Color(0xFF6D4C41),
  'classical': Color(0xFF455A64),
  'metal': Color(0xFF37474F),
  'country': Color(0xFF8D6E00),
};
