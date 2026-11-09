import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_log.dart';
import '../../services/audio/audio_backend.dart' show TransitionMode;
import '../../services/audio/equalizer.dart';
import '../../services/audio/play_queue.dart';
import '../../services/daylist/daylist_slots.dart';
import '../../services/daylist/mood_table.dart';
import '../../services/online/youtube_service.dart' show DownloadFormat;
import '../../services/recognition/track_identity.dart' show kRecogVersion;

/// The equalizer curve chosen for one kind of output (speaker or headphones).
class EqProfile {
  const EqProfile({this.preset = EqPreset.flat, this.custom = const []});

  final EqPreset preset;

  /// The user's own gains in dB, one per band (used when [preset] is custom).
  final List<double> custom;

  EqProfile copyWith({EqPreset? preset, List<double>? custom}) =>
      EqProfile(preset: preset ?? this.preset, custom: custom ?? this.custom);
}

/// Whether the launcher icon (Android) follows the theme: not decided yet
/// (the user is asked at the first change), yes, or no.
enum IconFollow { ask, on, off }

class AppSettings {
  const AppSettings({
    this.theme = 'notte',
    this.accent = 'viola',
    this.fontScale = 1.0,
    this.compactMode = false,
    this.reducedMotion = false,
    this.spinCover = false,
    this.blurredChrome = false,
    this.language = 'it',
    this.autoEnrich = false,
    this.autoLyrics = false,
    this.deezerMeta = true,
    this.acoustId = true,
    this.creditsDetails = false,
    this.romanization = true,
    this.autoCuriosities = false,
    this.showUndoSnackbar = true,
    this.deviceName,
    this.jamLatencyMs = 0,
    this.normalizeVolume = false,
    this.receiveFromLan = false,
    this.librarySort = 'recent',
    this.librarySortAscending,
    this.playlistSorts = const {},
    this.libraryGrid = false,
    this.recentSearches = const [],
    this.ytNoticeSeen = false,
    this.onboardingDone = false,
    this.recordHistory = true,
    this.downloadParallel = 2,
    this.downloadRateLimitKBps = 0,
    this.downloadFormat = DownloadFormat.m4a,
    this.streamCacheMb = 1024,
    this.importSureThreshold = 0.80,
    this.importReviewThreshold = 0.55,
    this.playbackSpeed = 1.0,
    this.eqEnabled = false,
    this.eqSpeaker = const EqProfile(),
    this.eqHeadphones = const EqProfile(),
    this.transition = TransitionMode.normal,
    this.crossfadeSeconds = 6,
    this.crossfadePlainInAlbum = true,
    this.writeTagsToFiles = false,
    this.tagsAlsoInFile = true,
    this.writeTagsAfterDownload = true,
    this.shufflePlus = false,
    this.shufflePlusEvery = 4,
    this.shufflePlusUnmeteredOnly = true,
    this.radioCountry = '',
    this.radioRegion = '',
    this.radioOnlyCountry = false,
    this.iconFollow = IconFollow.ask,
  });

  final String theme;

  /// The first-run guide was finished or skipped (never shown again).
  final bool onboardingDone;

  /// Keep the listening history (`plays`); local only.
  final bool recordHistory;

  /// One of the eight accent names (`CcAccent`); unknown ones mean violet.
  final String accent;
  final double fontScale;

  /// The now-playing cover turns while music plays; off by default.
  final bool spinCover;

  /// Dock and headers semi-transparent with a blur; off by default (slow on weak phones, D-406).
  final bool blurredChrome;
  final bool compactMode,
      reducedMotion,
      autoEnrich,
      autoLyrics,
      showUndoSnackbar;

  /// Deezer as a metadata source (data only); on unless the user turned it off.
  final bool deezerMeta, acoustId, creditsDetails, autoCuriosities;

  /// Transliteration under CJK lyrics (D-459, D-475): on unless the user turned it off.
  final bool romanization;

  /// Applies ReplayGain (track gain) at playback time.
  final bool normalizeVolume;

  /// Listen for offers from nearby devices while the app is open.
  final bool receiveFromLan;
  final String language;

  /// Library order: the name of a `LibrarySort`.
  final String librarySort;

  /// Direction of [librarySort]; null = the criterion's own (latest/most first).
  final bool? librarySortAscending;

  /// Each playlist's own order, by playlist id: «criterion:asc|desc» (D-424).
  /// A missing id means the personal order.
  final Map<String, String> playlistSorts;

  /// Library as a grid instead of a list.
  final bool libraryGrid;

  /// Latest library searches, newest first (max 10).
  final List<String> recentSearches;

  /// The YouTube legal notice was dismissed once.
  final bool ytNoticeSeen;

  /// Downloads running at once (1–3).
  final int downloadParallel;

  /// Download speed cap in KB/s; 0 = none.
  final int downloadRateLimitKBps;

  /// M4A keeps YouTube's AAC as served; MP3 converts for players that need it.
  final DownloadFormat downloadFormat;

  /// Disk space for the streaming cache, in MB (256–8192).
  final int streamCacheMb;

  /// CSV import: score from which a match is downloaded without asking, and
  /// from which it is at least proposed (advanced settings).
  final double importSureThreshold, importReviewThreshold;

  /// Playback speed (0.5–2.0), the same for every track; tone is preserved.
  final double playbackSpeed;

  /// Equalizer on/off (Android) and its curve for each kind of output.
  final bool eqEnabled;
  final EqProfile eqSpeaker, eqHeadphones;

  /// How one track gives way to the next, and the length of a crossfade.
  final TransitionMode transition;
  final int crossfadeSeconds;

  /// Inside an album the tracks follow each other plainly, with no fade.
  final bool crossfadePlainInAlbum;

  /// Shuffle+ (phase 31): with shuffle on, a song you do not have every
  /// [shufflePlusEvery] songs (3–10); [shufflePlusUnmeteredOnly] keeps it off
  /// mobile data.
  final bool shufflePlus, shufflePlusUnmeteredOnly;
  final int shufflePlusEvery;

  /// Radio (phase 33): the country (ISO code; empty = the system's) and the
  /// region id chosen for «Vicino a te» (empty = still to ask); search only
  /// inside the country.
  final String radioCountry, radioRegion;
  final bool radioOnlyCountry;

  /// The launcher icon follows the theme and accent (Android).
  final IconFollow iconFollow;

  /// Edits of title, artist, album… are also written into the music files
  /// (through `SafeTagWriter`, with a backup). Off by default.
  final bool writeTagsToFiles;

  /// With [writeTagsToFiles] on: the last answer to «also in the file?».
  final bool tagsAlsoInFile;

  /// Tags of files Codecore downloaded or received are written into them.
  final bool writeTagsAfterDownload;

  /// Shown to the device on the other side of a LAN share; null = hostname.
  final String? deviceName;

  /// Extra output latency of this device in a synchronised Jam (ms).
  final int jamLatencyMs;

  AppSettings copyWith({
    String? theme,
    String? accent,
    double? fontScale,
    bool? compactMode,
    bool? reducedMotion,
    bool? spinCover,
    bool? blurredChrome,
    String? language,
    bool? autoEnrich,
    bool? autoLyrics,
    bool? deezerMeta,
    bool? acoustId,
    bool? creditsDetails,
    bool? romanization,
    bool? autoCuriosities,
    bool? showUndoSnackbar,
    String? deviceName,
    int? jamLatencyMs,
    bool? normalizeVolume,
    bool? receiveFromLan,
    String? librarySort,
    bool? librarySortAscending,
    Map<String, String>? playlistSorts,
    bool? libraryGrid,
    List<String>? recentSearches,
    bool? ytNoticeSeen,
    bool? onboardingDone,
    bool? recordHistory,
    int? downloadParallel,
    int? downloadRateLimitKBps,
    DownloadFormat? downloadFormat,
    int? streamCacheMb,
    double? importSureThreshold,
    double? importReviewThreshold,
    double? playbackSpeed,
    bool? eqEnabled,
    EqProfile? eqSpeaker,
    EqProfile? eqHeadphones,
    TransitionMode? transition,
    int? crossfadeSeconds,
    bool? crossfadePlainInAlbum,
    bool? writeTagsToFiles,
    bool? tagsAlsoInFile,
    bool? writeTagsAfterDownload,
    bool? shufflePlus,
    int? shufflePlusEvery,
    bool? shufflePlusUnmeteredOnly,
    String? radioCountry,
    String? radioRegion,
    bool? radioOnlyCountry,
    IconFollow? iconFollow,
  }) => AppSettings(
    theme: theme ?? this.theme,
    accent: accent ?? this.accent,
    fontScale: fontScale ?? this.fontScale,
    compactMode: compactMode ?? this.compactMode,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    spinCover: spinCover ?? this.spinCover,
    blurredChrome: blurredChrome ?? this.blurredChrome,
    language: language ?? this.language,
    autoEnrich: autoEnrich ?? this.autoEnrich,
    autoLyrics: autoLyrics ?? this.autoLyrics,
    deezerMeta: deezerMeta ?? this.deezerMeta,
    acoustId: acoustId ?? this.acoustId,
    creditsDetails: creditsDetails ?? this.creditsDetails,
    romanization: romanization ?? this.romanization,
    autoCuriosities: autoCuriosities ?? this.autoCuriosities,
    showUndoSnackbar: showUndoSnackbar ?? this.showUndoSnackbar,
    deviceName: deviceName ?? this.deviceName,
    jamLatencyMs: jamLatencyMs ?? this.jamLatencyMs,
    normalizeVolume: normalizeVolume ?? this.normalizeVolume,
    receiveFromLan: receiveFromLan ?? this.receiveFromLan,
    librarySort: librarySort ?? this.librarySort,
    librarySortAscending: librarySortAscending ?? this.librarySortAscending,
    playlistSorts: playlistSorts ?? this.playlistSorts,
    libraryGrid: libraryGrid ?? this.libraryGrid,
    recentSearches: recentSearches ?? this.recentSearches,
    ytNoticeSeen: ytNoticeSeen ?? this.ytNoticeSeen,
    onboardingDone: onboardingDone ?? this.onboardingDone,
    recordHistory: recordHistory ?? this.recordHistory,
    downloadParallel: downloadParallel ?? this.downloadParallel,
    downloadRateLimitKBps: downloadRateLimitKBps ?? this.downloadRateLimitKBps,
    downloadFormat: downloadFormat ?? this.downloadFormat,
    streamCacheMb: streamCacheMb ?? this.streamCacheMb,
    importSureThreshold: importSureThreshold ?? this.importSureThreshold,
    importReviewThreshold: importReviewThreshold ?? this.importReviewThreshold,
    playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    eqEnabled: eqEnabled ?? this.eqEnabled,
    eqSpeaker: eqSpeaker ?? this.eqSpeaker,
    eqHeadphones: eqHeadphones ?? this.eqHeadphones,
    transition: transition ?? this.transition,
    crossfadeSeconds: crossfadeSeconds ?? this.crossfadeSeconds,
    crossfadePlainInAlbum: crossfadePlainInAlbum ?? this.crossfadePlainInAlbum,
    writeTagsToFiles: writeTagsToFiles ?? this.writeTagsToFiles,
    tagsAlsoInFile: tagsAlsoInFile ?? this.tagsAlsoInFile,
    writeTagsAfterDownload:
        writeTagsAfterDownload ?? this.writeTagsAfterDownload,
    shufflePlus: shufflePlus ?? this.shufflePlus,
    shufflePlusEvery: shufflePlusEvery ?? this.shufflePlusEvery,
    shufflePlusUnmeteredOnly:
        shufflePlusUnmeteredOnly ?? this.shufflePlusUnmeteredOnly,
    radioCountry: radioCountry ?? this.radioCountry,
    radioRegion: radioRegion ?? this.radioRegion,
    radioOnlyCountry: radioOnlyCountry ?? this.radioOnlyCountry,
    iconFollow: iconFollow ?? this.iconFollow,
  );
}

class SavedPlayback {
  const SavedPlayback({
    this.queueIds = const [],
    this.index = 0,
    this.positionMs = 0,
    this.volume = 1.0,
    this.shuffle = false,
    this.repeat = PlayRepeat.off,
    this.contextKind,
    this.contextName,
    this.userAhead = 0,
  });

  final List<int> queueIds;
  final int index, positionMs;

  /// Where the queue came from (`PlayContextKind.index` and the list's name);
  /// null in what older versions saved.
  final int? contextKind;
  final String? contextName;

  /// Entries of the user block after the current one (absent in older saves = 0).
  final int userAhead;
  final double volume;
  final bool shuffle;
  final PlayRepeat repeat;
}

const enrichMarkKey = 'enrichMark';

/// Tracks whose synced lyrics are switched off (track ids, D-472).
const unsyncedLyricsKey = 'unsyncedLyrics';

/// Tracks whose lyrics the user typed in the editor (track ids, D-475).
const handWrittenLyricsKey = 'handWrittenLyrics';

/// Transliterations typed by hand, as JSON `{"trackId": "text"}` (D-475).
const manualRomanizationKey = 'manualRomanization';

/// Daylist slots and the user's changes to the genre -> mood table. Not
/// device-bound: they travel in the backup's settings.json.
const daylistSlotsKey = 'daylistSlots';
const moodTableKey = 'daylistMoodTable';
const recogPassAfterKey = 'recogPassAfter';
const recogPassDoneKey = 'recogPassDone';
const genreRereadAfterKey = 'genreRereadAfter';
const genreRereadDoneKey = 'genreRereadDone';

class SettingsStore {
  SettingsStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<SettingsStore> open() async =>
      SettingsStore(await SharedPreferences.getInstance());

  Map<String, String> _readPlaylistSorts() {
    final raw = _prefs.get('playlistSorts');
    if (raw == null) return const {};
    if (raw is! String) {
      AppLog.w(
        'playlistSorts has type ${raw.runtimeType}, back to personal order',
      );
      return const {};
    }
    try {
      final m = jsonDecode(raw);
      if (m is Map) {
        return {for (final e in m.entries) '${e.key}': '${e.value}'};
      }
    } on FormatException catch (e) {
      AppLog.w('playlistSorts unreadable, back to personal order', e);
    }
    return const {};
  }

  bool? _readSortAscending() {
    final v = _prefs.get('librarySortAscending');
    if (v is bool?) return v;
    AppLog.w(
      'librarySortAscending has type ${v.runtimeType}, using the default',
    );
    return null;
  }

  AppSettings readSettings() => AppSettings(
    theme: _prefs.getString('theme') ?? 'notte',
    accent: _prefs.getString('accent') ?? 'viola',
    fontScale: _prefs.getDouble('fontScale') ?? 1.0,
    compactMode: _prefs.getBool('compactMode') ?? false,
    reducedMotion: _prefs.getBool('reducedMotion') ?? false,
    spinCover: _prefs.getBool('spinCover') ?? false,
    blurredChrome: _prefs.getBool('blurredChrome') ?? false,
    language: _prefs.getString('language') ?? 'it',
    autoEnrich: _prefs.getBool('autoEnrich') ?? false,
    autoLyrics: _prefs.getBool('autoLyrics') ?? false,
    deezerMeta: _prefs.getBool('deezerMeta') ?? true,
    acoustId: _prefs.getBool('acoustId') ?? true,
    creditsDetails: _prefs.getBool('creditsDetails') ?? false,
    romanization: _prefs.getBool('romanization') ?? true,
    autoCuriosities: _prefs.getBool('autoCuriosities') ?? false,
    showUndoSnackbar: _prefs.getBool('showUndoSnackbar') ?? true,
    deviceName: _prefs.getString('deviceName'),
    normalizeVolume: _prefs.getBool('normalizeVolume') ?? false,
    receiveFromLan: _prefs.getBool('receiveFromLan') ?? false,
    jamLatencyMs: _prefs.getInt('jamLatencyMs') ?? 0,
    librarySort: _prefs.getString('librarySort') ?? 'recent',
    librarySortAscending: _readSortAscending(),
    playlistSorts: _readPlaylistSorts(),
    libraryGrid: _prefs.getBool('libraryGrid') ?? false,
    recentSearches: _prefs.getStringList('recentSearches') ?? const [],
    ytNoticeSeen: _prefs.getBool('ytNoticeSeen') ?? false,
    onboardingDone: _prefs.getBool('onboardingDone') ?? false,
    recordHistory: _prefs.getBool('recordHistory') ?? true,
    downloadParallel: (_prefs.getInt('downloadParallel') ?? 2).clamp(1, 3),
    downloadRateLimitKBps: _prefs.getInt('downloadRateLimitKBps') ?? 0,
    streamCacheMb: (_prefs.getInt('streamCacheMb') ?? 1024).clamp(256, 8192),
    // The old «downloadOriginal» switch is not read: MP3 was only ever the
    // default, so everyone moves to M4A.
    downloadFormat: DownloadFormat.values.firstWhere(
      (f) => f.name == _prefs.getString('downloadFormat'),
      orElse: () => DownloadFormat.m4a,
    ),
    importSureThreshold: _prefs.getDouble('importSureThreshold') ?? 0.80,
    importReviewThreshold: _prefs.getDouble('importReviewThreshold') ?? 0.55,
    playbackSpeed: (_prefs.getDouble('playbackSpeed') ?? 1.0).clamp(0.5, 2.0),
    eqEnabled: _prefs.getBool('eqEnabled') ?? false,
    eqSpeaker: _readEq('speaker'),
    eqHeadphones: _readEq('headphones'),
    transition: TransitionMode.values.firstWhere(
      (m) => m.name == _prefs.getString('transition'),
      orElse: () => TransitionMode.normal,
    ),
    crossfadeSeconds: (_prefs.getInt('crossfadeSeconds') ?? 6).clamp(2, 12),
    crossfadePlainInAlbum: _prefs.getBool('crossfadePlainInAlbum') ?? true,
    writeTagsToFiles: _prefs.getBool('writeTagsToFiles') ?? false,
    tagsAlsoInFile: _prefs.getBool('tagsAlsoInFile') ?? true,
    writeTagsAfterDownload: _prefs.getBool('writeTagsAfterDownload') ?? true,
    shufflePlus: _prefs.getBool('shufflePlus') ?? false,
    shufflePlusEvery: (_prefs.getInt('shufflePlusEvery') ?? 4).clamp(3, 10),
    shufflePlusUnmeteredOnly:
        _prefs.getBool('shufflePlusUnmeteredOnly') ?? true,
    radioCountry: _prefs.getString('radioCountry') ?? '',
    radioRegion: _prefs.getString('radioRegion') ?? '',
    radioOnlyCountry: _prefs.getBool('radioOnlyCountry') ?? false,
    iconFollow: IconFollow.values.firstWhere(
      (f) => f.name == _prefs.getString('iconFollow'),
      orElse: () => IconFollow.ask,
    ),
  );

  EqProfile _readEq(String profile) => EqProfile(
    preset: EqPreset.values.firstWhere(
      (p) => p.name == _prefs.getString('eqPreset.$profile'),
      orElse: () => EqPreset.flat,
    ),
    custom: [
      for (final g in _prefs.getStringList('eqGains.$profile') ?? const [])
        ?double.tryParse(g),
    ],
  );

  Future<void> _writeEq(String profile, EqProfile p) async {
    await _prefs.setString('eqPreset.$profile', p.preset.name);
    await _prefs.setStringList('eqGains.$profile', [
      for (final g in p.custom) '$g',
    ]);
  }

  Future<void> writeSettings(AppSettings s) async {
    await _prefs.setString('theme', s.theme);
    await _prefs.setString('accent', s.accent);
    await _prefs.setDouble('fontScale', s.fontScale);
    await _prefs.setBool('compactMode', s.compactMode);
    await _prefs.setBool('reducedMotion', s.reducedMotion);
    await _prefs.setBool('spinCover', s.spinCover);
    await _prefs.setBool('blurredChrome', s.blurredChrome);
    await _prefs.setString('language', s.language);
    await _prefs.setBool('autoEnrich', s.autoEnrich);
    await _prefs.setBool('autoLyrics', s.autoLyrics);
    await _prefs.setBool('deezerMeta', s.deezerMeta);
    await _prefs.setBool('acoustId', s.acoustId);
    await _prefs.setBool('creditsDetails', s.creditsDetails);
    await _prefs.setBool('romanization', s.romanization);
    await _prefs.setBool('autoCuriosities', s.autoCuriosities);
    await _prefs.setBool('showUndoSnackbar', s.showUndoSnackbar);
    await _prefs.setBool('normalizeVolume', s.normalizeVolume);
    await _prefs.setBool('receiveFromLan', s.receiveFromLan);
    await _prefs.setInt('jamLatencyMs', s.jamLatencyMs);
    await _prefs.setString('librarySort', s.librarySort);
    final asc = s.librarySortAscending;
    if (asc == null) {
      await _prefs.remove('librarySortAscending');
    } else {
      await _prefs.setBool('librarySortAscending', asc);
    }
    await _prefs.setString('playlistSorts', jsonEncode(s.playlistSorts));
    await _prefs.setBool('libraryGrid', s.libraryGrid);
    await _prefs.setStringList('recentSearches', s.recentSearches);
    await _prefs.setBool('ytNoticeSeen', s.ytNoticeSeen);
    await _prefs.setBool('onboardingDone', s.onboardingDone);
    await _prefs.setBool('recordHistory', s.recordHistory);
    await _prefs.setInt('downloadParallel', s.downloadParallel);
    await _prefs.setInt('downloadRateLimitKBps', s.downloadRateLimitKBps);
    await _prefs.setString('downloadFormat', s.downloadFormat.name);
    await _prefs.setInt('streamCacheMb', s.streamCacheMb);
    await _prefs.remove('downloadOriginal');
    await _prefs.setDouble('importSureThreshold', s.importSureThreshold);
    await _prefs.setDouble('importReviewThreshold', s.importReviewThreshold);
    await _prefs.setDouble('playbackSpeed', s.playbackSpeed);
    await _prefs.setBool('eqEnabled', s.eqEnabled);
    await _writeEq('speaker', s.eqSpeaker);
    await _writeEq('headphones', s.eqHeadphones);
    await _prefs.setString('transition', s.transition.name);
    await _prefs.setInt('crossfadeSeconds', s.crossfadeSeconds);
    await _prefs.setBool('crossfadePlainInAlbum', s.crossfadePlainInAlbum);
    await _prefs.setBool('writeTagsToFiles', s.writeTagsToFiles);
    await _prefs.setBool('tagsAlsoInFile', s.tagsAlsoInFile);
    await _prefs.setBool('writeTagsAfterDownload', s.writeTagsAfterDownload);
    await _prefs.setBool('shufflePlus', s.shufflePlus);
    await _prefs.setInt('shufflePlusEvery', s.shufflePlusEvery);
    await _prefs.setBool(
      'shufflePlusUnmeteredOnly',
      s.shufflePlusUnmeteredOnly,
    );
    await _prefs.setString('radioCountry', s.radioCountry);
    await _prefs.setString('radioRegion', s.radioRegion);
    await _prefs.setBool('radioOnlyCountry', s.radioOnlyCountry);
    await _prefs.setString('iconFollow', s.iconFollow.name);
    final dn = s.deviceName;
    if (dn == null || dn.isEmpty) {
      await _prefs.remove('deviceName');
    } else {
      await _prefs.setString('deviceName', dn);
    }
  }

  /// Stable random id of this installation (used to recognise devices).
  Future<String> deviceId() async {
    final existing = _prefs.getString('deviceId');
    if (existing != null && existing.length >= 16) return existing;
    final r = Random.secure();
    final id = List.generate(
      16,
      (_) => r.nextInt(256),
    ).map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    await _prefs.setString('deviceId', id);
    return id;
  }

  /// The paired devices, as written by `TrustedDevices.encode`.
  String? readTrustedDevicesRaw() => _prefs.getString('trustedDevices');

  Future<void> writeTrustedDevicesRaw(String raw) =>
      _prefs.setString('trustedDevices', raw);

  /// Remote Jam brokers, JSON `[{host, port, tls}]` (null = the defaults).
  String? readJamBrokersRaw() => _prefs.getString('jamBrokers');

  Future<void> writeJamBrokersRaw(String? raw) => raw == null
      ? _prefs.remove('jamBrokers')
      : _prefs.setString('jamBrokers', raw);

  /// «Accetta gli amici senza chiedere» of the remote Jam: off unless turned on (R-145).
  bool readJamAutoAcceptFriends() =>
      _prefs.getBool('jamAutoAcceptFriends') ?? false;

  Future<void> writeJamAutoAcceptFriends(bool v) =>
      _prefs.setBool('jamAutoAcceptFriends', v);

  /// «Cerca Jam vicine» (Bluetooth): on, false after a refused permission (R-138).
  bool readJamNearbyScan() => _prefs.getBool('jamNearbyScan') ?? true;

  Future<void> writeJamNearbyScan(bool v) => _prefs.setBool('jamNearbyScan', v);

  /// The Bluetooth permission sheet has been shown once.
  bool readJamBlePermAsked() => _prefs.getBool('jamBlePermAsked') ?? false;

  Future<void> writeJamBlePermAsked(bool v) =>
      _prefs.setBool('jamBlePermAsked', v);

  /// The user's own themes, as written by `CustomThemes.encode`.
  String? readCustomThemesRaw() => _prefs.getString('customThemes');

  Future<void> writeCustomThemesRaw(String raw) =>
      _prefs.setString('customThemes', raw);

  /// «Controlla all'avvio» for new versions: off unless the user turns it on.
  bool readCheckUpdatesOnStart() =>
      _prefs.getBool('checkUpdatesOnStart') ?? false;

  Future<void> writeCheckUpdatesOnStart(bool on) =>
      _prefs.setBool('checkUpdatesOnStart', on);

  /// Day (days since the epoch) of the last check made at start-up.
  int readLastUpdateCheckDay() => _prefs.getInt('lastUpdateCheckDay') ?? 0;

  Future<void> writeLastUpdateCheckDay(int day) =>
      _prefs.setInt('lastUpdateCheckDay', day);

  /// Background enrichment bookmark: id of the last track tried (0 = none).
  /// Device-bound, never in a backup.
  int get enrichMark => _prefs.getInt(enrichMarkKey) ?? 0;
  Future<void> writeEnrichMark(int id) => _prefs.setInt(enrichMarkKey, id);

  /// Recognition re-pass (R-176): the bookmark is kept as `version:id` and only
  /// holds for [kRecogVersion]; [recogPassDone] is the version it finished for.
  /// Device-bound, never in a backup.
  int get recogPassAfter {
    final parts = (_prefs.getString(recogPassAfterKey) ?? '').split(':');
    return parts.length == 2 && int.tryParse(parts[0]) == kRecogVersion
        ? int.tryParse(parts[1]) ?? 0
        : 0;
  }

  Future<void> writeRecogPassAfter(int id) =>
      _prefs.setString(recogPassAfterKey, '$kRecogVersion:$id');
  int get recogPassDone => _prefs.getInt(recogPassDoneKey) ?? 0;
  Future<void> writeRecogPassDone(int v) => _prefs.setInt(recogPassDoneKey, v);

  /// Genre re-read of the existing library (D-390): the last track done, and the
  /// `kGenreRereadVersion` it finished for. Device-bound (track ids), never in a backup.
  int get genreRereadAfter => _prefs.getInt(genreRereadAfterKey) ?? 0;
  Future<void> writeGenreRereadAfter(int id) =>
      _prefs.setInt(genreRereadAfterKey, id);
  int get genreRereadDone => _prefs.getInt(genreRereadDoneKey) ?? 0;
  Future<void> writeGenreRereadDone(int v) =>
      _prefs.setInt(genreRereadDoneKey, v);

  // New releases of followed artists (phase 34).

  /// «Più ascoltati»: follow the most listened artists automatically (off).
  bool get releasesTopArtists => _prefs.getBool('releasesTopArtists') ?? false;
  Future<void> writeReleasesTopArtists(bool on) =>
      _prefs.setBool('releasesTopArtists', on);

  /// A notification for new releases (Android).
  bool get releasesNotify => _prefs.getBool('releasesNotify') ?? true;
  Future<void> writeReleasesNotify(bool on) =>
      _prefs.setBool('releasesNotify', on);

  /// Check only on a network that is not metered (off).
  bool get releasesUnmeteredOnly =>
      _prefs.getBool('releasesUnmeteredOnly') ?? false;
  Future<void> writeReleasesUnmeteredOnly(bool on) =>
      _prefs.setBool('releasesUnmeteredOnly', on);

  /// The Home card about «Più ascoltati» was answered (either way).
  bool get releasesTopCardSeen =>
      _prefs.getBool('releasesTopCardSeen') ?? false;
  Future<void> writeReleasesTopCardSeen(bool seen) =>
      _prefs.setBool('releasesTopCardSeen', seen);

  /// Start of the last round, and the earliest time for another after a 429
  /// (epoch ms; null = none).
  int? get releasesLastRunAt => _prefs.getInt('releasesLastRunAt');
  int? get releasesRetryAt => _prefs.getInt('releasesRetryAt');
  int? get releasesLastNotifiedAt => _prefs.getInt('releasesLastNotifiedAt');

  Future<void> writeReleasesLastRunAt(int ms) =>
      _prefs.setInt('releasesLastRunAt', ms);
  Future<void> writeReleasesLastNotifiedAt(int ms) =>
      _prefs.setInt('releasesLastNotifiedAt', ms);
  Future<void> writeReleasesRetryAt(int? ms) => ms == null
      ? _prefs.remove('releasesRetryAt')
      : _prefs.setInt('releasesRetryAt', ms);

  /// Duplicate groups the user marked «not duplicates» (`DuplicateGroup.key`).
  Set<String> readNotDuplicates() =>
      (_prefs.getStringList('notDuplicates') ?? const []).toSet();

  Future<void> writeNotDuplicates(Set<String> keys) =>
      _prefs.setStringList('notDuplicates', keys.toList()..sort());

  /// Tracks the user marked «va bene così» in «Da revisionare» (track ids).
  Set<int> readReviewDismissed() =>
      (_prefs.getStringList('reviewDismissed') ?? const [])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();

  Future<void> writeReviewDismissed(Set<int> ids) => _prefs.setStringList(
    'reviewDismissed',
    [for (final i in ids.toList()..sort()) '$i'],
  );

  /// Tracks the second opinion of YouTube Music already looked at, so opening
  /// «Da revisionare» does not ask again (track ids).
  Set<int> readReviewChecked() =>
      (_prefs.getStringList('reviewChecked') ?? const [])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();

  Future<void> writeReviewChecked(Set<int> ids) => _prefs.setStringList(
    'reviewChecked',
    [for (final i in ids.toList()..sort()) '$i'],
  );

  /// Tracks whose synced lyrics are switched off: the plain text is shown (track ids).
  Set<int> readUnsyncedLyrics() =>
      (_prefs.getStringList(unsyncedLyricsKey) ?? const [])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();

  Future<void> writeUnsyncedLyrics(Set<int> ids) => _prefs.setStringList(
    unsyncedLyricsKey,
    [for (final i in ids.toList()..sort()) '$i'],
  );

  /// Tracks whose lyrics were typed or pasted in the editor (track ids).
  Set<int> readHandWrittenLyrics() =>
      (_prefs.getStringList(handWrittenLyricsKey) ?? const [])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();

  Future<void> writeHandWrittenLyrics(Set<int> ids) => ids.isEmpty
      ? _prefs.remove(handWrittenLyricsKey)
      : _prefs.setStringList(handWrittenLyricsKey, [
          for (final i in ids.toList()..sort()) '$i',
        ]);

  /// Transliterations typed by hand: track id -> text, one line per lyrics line.
  Map<int, String> readManualRomanizations() {
    try {
      final raw = _prefs.getString(manualRomanizationKey);
      if (raw == null) return const {};
      final m = jsonDecode(raw);
      if (m is Map) {
        return {
          for (final e in m.entries)
            if (int.tryParse('${e.key}') != null && e.value is String)
              int.parse('${e.key}'): e.value as String,
        };
      }
    } on Object catch (e, st) {
      AppLog.w('manual transliterations unreadable, starting empty', e, st);
    }
    return const {};
  }

  Future<void> writeManualRomanizations(Map<int, String> texts) => texts.isEmpty
      ? _prefs.remove(manualRomanizationKey)
      : _prefs.setString(
          manualRomanizationKey,
          jsonEncode({for (final e in texts.entries) '${e.key}': e.value}),
        );

  DaylistConfig readDaylistConfig() =>
      DaylistConfig.fromJsonString(_prefs.getString(daylistSlotsKey));

  Future<void> writeDaylistConfig(DaylistConfig c) =>
      _prefs.setString(daylistSlotsKey, c.toJsonString());

  MoodTable readMoodTable() =>
      MoodTable.fromJsonString(_prefs.getString(moodTableKey));

  Future<void> writeMoodTable(MoodTable t) =>
      _prefs.setString(moodTableKey, t.toJsonString());

  /// Slots, quotas and table back to the defaults.
  Future<void> resetDaylist() async {
    await resetDaylistSlots();
    await resetMoodTable();
  }

  /// Only the slots: the key goes, so the backup does not carry the defaults.
  Future<void> resetDaylistSlots() => _prefs.remove(daylistSlotsKey);

  Future<void> resetMoodTable() => _prefs.remove(moodTableKey);

  SavedPlayback readPlayback() {
    final ids = (_prefs.getStringList('lastQueueIds') ?? const [])
        .map(int.tryParse)
        .whereType<int>()
        .toList();
    final repeat = PlayRepeat.values.firstWhere(
      (r) => r.name == _prefs.getString('repeat'),
      orElse: () => PlayRepeat.off,
    );
    return SavedPlayback(
      queueIds: ids,
      index: _prefs.getInt('lastIndex') ?? 0,
      positionMs: _prefs.getInt('lastPositionMs') ?? 0,
      volume: _prefs.getDouble('volume') ?? 1.0,
      shuffle: _prefs.getBool('shuffle') ?? false,
      repeat: repeat,
      contextKind: _prefs.getInt('lastContextKind'),
      contextName: _prefs.getString('lastContextName'),
      userAhead: _prefs.getInt('lastQueueUser') ?? 0,
    );
  }

  Future<void> writePlayback(SavedPlayback s) async {
    await _prefs.setStringList('lastQueueIds', [
      for (final id in s.queueIds) '$id',
    ]);
    await _prefs.setInt('lastQueueUser', s.userAhead);
    await _prefs.setInt('lastIndex', s.index);
    await _prefs.setInt('lastPositionMs', s.positionMs);
    await _prefs.setDouble('volume', s.volume);
    await _prefs.setBool('shuffle', s.shuffle);
    await _prefs.setString('repeat', s.repeat.name);
    final kind = s.contextKind, name = s.contextName;
    await (kind == null
        ? _prefs.remove('lastContextKind')
        : _prefs.setInt('lastContextKind', kind));
    await (name == null
        ? _prefs.remove('lastContextName')
        : _prefs.setString('lastContextName', name));
  }

  /// The queue and shuffle mode a restart in the middle of a Jam must find (D-341);
  /// an empty queue means: only the mode. [plus]: Shuffle+ rather than plain shuffle.
  ({SavedPlayback queue, bool plus})? readJamAside() {
    final raw = _prefs.getString('jamAside');
    if (raw == null) return null;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return (
      queue: SavedPlayback(
        queueIds: [for (final i in j['ids'] as List) i as int],
        index: j['index'] as int,
        positionMs: j['ms'] as int,
        shuffle: j['shuffle'] as bool,
      ),
      plus: j['plus'] as bool,
    );
  }

  Future<void> writeJamAside(SavedPlayback q, {required bool plus}) =>
      _prefs.setString(
        'jamAside',
        jsonEncode({
          'ids': q.queueIds,
          'index': q.index,
          'ms': q.positionMs,
          'shuffle': q.shuffle,
          'plus': plus,
        }),
      );

  Future<void> clearJamAside() => _prefs.remove('jamAside');

  /// When the last Exportify sync ended (ms since epoch); null if never.
  int? readExportifyLastSyncAt() => _prefs.getInt('exportifyLastSyncAt');

  Future<void> writeExportifyLastSyncAt(int ms) =>
      _prefs.setInt('exportifyLastSyncAt', ms);

  /// Days between sync reminders: 0 = off, else 7, 14 or 30.
  int readExportifyRemindDays() => _prefs.getInt('exportifyRemindDays') ?? 0;

  Future<void> writeExportifyRemindDays(int days) =>
      _prefs.setInt('exportifyRemindDays', days);

  /// The reminder stays quiet until then (ms since epoch); null = not snoozed.
  int? readExportifySnoozeUntil() => _prefs.getInt('exportifySnoozeUntil');

  Future<void> writeExportifySnoozeUntil(int ms) =>
      _prefs.setInt('exportifySnoozeUntil', ms);

  /// When «Apri exportify.net» was last tapped (ms since epoch); null = never
  /// or already used. The desktop looks for a download newer than this.
  int? readExportifyOpenedAt() => _prefs.getInt('exportifyOpenedAt');

  Future<void> writeExportifyOpenedAt(int? ms) => ms == null
      ? _prefs.remove('exportifyOpenedAt')
      : _prefs.setInt('exportifyOpenedAt', ms);
}
