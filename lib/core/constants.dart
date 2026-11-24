/// Single switch for the YouTube download feature (docs/storico/fasi/fase-5-online.md, parte B).
/// `--dart-define=CODECORE_YOUTUBE=false` builds without it (the `lite`
/// Android build also leaves yt-dlp out of the APK).
const bool kEnableYoutube = bool.fromEnvironment('CODECORE_YOUTUBE', defaultValue: true);

/// Pause before a search or a list reloads while the user types (CcTiming.debounce).
const kInputDebounce = Duration(milliseconds: 250);

/// Address of the anonymous-report service (tools/report-worker, D-669/D-701).
/// Empty means not deployed: the report screen then offers only «Copia testo»
/// and the GitHub page.
const kReportEndpoint = 'https://freekmusic-report.itzemany.workers.dev/';
