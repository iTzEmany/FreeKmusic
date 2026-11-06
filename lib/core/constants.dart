/// Single switch for the YouTube download feature (docs/fase-5, parte B).
/// `--dart-define=CODECORE_YOUTUBE=false` builds without it (the `lite`
/// Android build also leaves yt-dlp out of the APK).
/// Pause before a search or a list reloads while the user types (CcTiming.debounce).
const kInputDebounce = Duration(milliseconds: 250);

const bool kEnableYoutube = bool.fromEnvironment('CODECORE_YOUTUBE', defaultValue: true);
