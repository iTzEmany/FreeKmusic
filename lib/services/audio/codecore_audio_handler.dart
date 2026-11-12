import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;

import '../../core/app_log.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/play_history_repository.dart';
import '../../data/repositories/track_kinds.dart';
import '../../data/repositories/track_repository.dart';
import '../online/youtube_service.dart';
import '../stream/stream_key.dart';
import '../stream/stream_preparer.dart';
import 'audio_backend.dart';
import '../online/google_thumb.dart';
import 'crossfade_engine.dart';
import 'equalizer.dart';
import '../radio/icy_title.dart';
import '../radio/radio_station.dart';
import 'next_window.dart';
import 'online_entries.dart';
import 'media_browse_tree.dart';
import 'play_queue.dart';
import 'remote_transport.dart';
import 'resume_point.dart';

enum PlaybackFailureReason {
  fileMissing,
  unplayable,
  notInLibrary,
  onlineUnavailable,
  episodeUnavailable,
  ageRestricted,
  networkUnavailable,
  radioUnavailable,
}

class PlaybackFailure {
  const PlaybackFailure(this.title, this.reason);

  final String? title;
  final PlaybackFailureReason reason;
}

class CodecoreAudioHandler extends BaseAudioHandler with SeekHandler {
  CodecoreAudioHandler(
    AudioBackend backend,
    this._queue,
    this._tracks, {
    required this.onError,
    this.coverPathFor,
    this.history,
    this.onEpisodeHeard,
    this.onEpisodeResumed,
    this.online,
    StreamPreparer? preparer,
    this.onRadioStart,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       _backend = backend,
       _window = backend is GaplessCapable
           ? NextWindow(_queue, backend as GaplessCapable)
           : null {
    _subs
      ..add(_backend.state.listen(_onBackendState))
      ..add(
        _backend.position.listen((p) {
          _onPosition(p);
          // While a stream loads, the backend still reports the old track.
          _posOut.add(_waitingStream ? Duration.zero : p);
        }),
      )
      ..add(_backend.duration.listen(_onBackendDuration))
      ..add(_backend.streamTitle.listen(_onStreamTitle))
      ..add(_queueController.stream.listen((_) => unawaited(_syncPreparer())));
    this.preparer = preparer;
    if (backend is GaplessCapable) {
      _subs.add(
        (backend as GaplessCapable).advanced.listen(
          (_) => unawaited(_onAdvanced()),
        ),
      );
    }
  }

  static const maxConsecutiveErrors = 3;

  /// Waits before the 1st, 2nd and 3rd new attempt when a radio stream drops.
  static const radioRetryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 15),
  ];

  /// A radio paused for longer has lost its stream: resuming connects again.
  static const radioResumeAfter = Duration(seconds: 30);
  static const _radioSteadyAfter = Duration(seconds: 10);

  final AudioBackend _backend;
  final PlayHistoryRepository? history;

  /// Told once per session when a podcast episode (track kind 1) has been
  /// listened to from 95 % on, or to its end. The handler writes nothing about
  /// podcasts itself (their rows are told through this and [onEpisodeResumed]),
  /// but it plays the rows of episodes not downloaded, from their address.
  final FutureOr<void> Function(int trackId)? onEpisodeHeard;

  /// Told once per listen when an episode gets a new bookmark: it may have been marked as
  /// heard before, and listening again takes that mark away.
  final FutureOr<void> Function(int trackId)? onEpisodeResumed;

  /// Streamed (not owned) entries of the queue, which have negative ids.
  /// Null: the queue holds only library tracks.
  final OnlineEntries? online;

  /// Downloads online entries and `kind = 2` rows into the cache; null: they cannot play.
  /// Set by main once the providers exist, before any queue is restored.
  StreamPreparer? get preparer => _preparer;
  set preparer(StreamPreparer? p) {
    _preparer?.phases.removeListener(_onPhases);
    _preparer = p;
    p?.phases.addListener(_onPhases);
  }

  StreamPreparer? _preparer;

  // The file of what follows may arrive while the current track plays (R-80), or move
  // (a download): a library track in the window stays, a cached one is looked up again.
  void _onPhases() {
    final next = _window?.track;
    if (_current == null ||
        (next != null && !isStreamTrack(next)) ||
        _loadBusy ||
        _waitingStream) {
      return;
    }
    _window?.invalidate();
    unawaited(_refreshWindow());
  }

  /// The library track already holding an online result (a download), if any
  /// (D-81). Set by main; null: every online entry streams.
  Future<int?> Function(YtResult)? libraryIdOf;
  int _syncToken = 0;

  /// [libraryIdOf] that never throws: an unreadable index means «not downloaded».
  Future<int?> _downloadedId(YtResult r) async {
    try {
      final id = await libraryIdOf?.call(r);
      _lookupWarned = false;
      return id;
    } on Object catch (e, st) {
      if (!_lookupWarned) {
        AppLog.w('download lookup failed: online entries stream', e, st);
      }
      _lookupWarned = true; // one line per failure streak, not per entry
      return null;
    }
  }

  bool _lookupWarned = false;

  /// Tells the preparer again what is queued: a song downloaded or promoted
  /// meanwhile must not be prefetched (K-02).
  Future<void> resyncPreparer() => _syncPreparer();

  /// Looks again for the shadow row of the streamed track now playing (the
  /// player's «Riprova»): asks the preparer for the file again (a failed job
  /// is replaced), then binds the row.
  Future<void> retryShadow() async {
    final token = _loadToken;
    final id = _queue.currentId;
    final entry = id == null ? null : online?.entryOf(id);
    final p = preparer;
    if (entry == null || entry.trackId != null || p == null) return;
    final key = entry.result.indexKey;
    try {
      await resyncPreparer();
      await p.ready(key, entry.result);
    } on Object catch (e, st) {
      AppLog.w('shadow row of $key: retry failed', e, st);
      return;
    }
    await _bindShadow(key, entry.id, token);
  }

  /// The queue entry now playing (an online entry keeps its own id even when
  /// its library file plays).
  int? get currentQueueId => _queue.currentId;

  /// A streamed track is being fetched: the old one is paused, the backend's
  /// events and positions are not the new track's. [play]/[pause] only set
  /// [_playWhenReady] meanwhile.
  bool _waitingStream = false;
  bool _playWhenReady = true;

  /// A load is under way; a pause meanwhile must stick (the old track is not the one to pause).
  bool _loadBusy = false, _loadPaused = false;

  /// Shadow row of the online entry now playing, once the preparer made it.
  int? _shadowId;

  /// Told (without waiting) each time a radio station starts, not on a
  /// reconnection: the click Radio Browser asks for, the «last played» of a
  /// saved station.
  final void Function(RadioStation station)? onRadioStart;
  final DateTime Function() _clock;
  final NextWindow? _window;
  final PlayQueue _queue;
  final TrackRepository _tracks;
  final void Function(PlaybackFailure failure) onError;
  final String? Function(Track track)? coverPathFor;
  final List<StreamSubscription<Object?>> _subs = [];
  final _trackController = StreamController<Track?>.broadcast();
  final _queueController = StreamController<void>.broadcast();

  BackendState _state = BackendState.idle;
  Duration _position = Duration.zero;
  Duration? _duration;
  Track? _current;
  int _loadToken = 0;
  // Tap-to-first-sound timing of the load in flight (logged once, see _onPosition).
  _Timing? _timing;
  int _consecutiveErrors = 0;
  // The current streamed track plays from its address (not the cached file): an
  // error there asks the preparer for a new start (R-76).
  _UrlSession? _url;
  bool _recoverOnPlay = false, _errorWhileLoading = false;
  bool _playCounted = false;
  RemoteTransport? _remote;
  StreamSubscription<RemoteStatus>? _remoteSub;

  /// The listening history (`plays`) is written only while this is on.
  bool recordHistory = true;
  final _context = ValueNotifier<({int kind, String? name})?>(null);

  // The listen being timed: the row (once it counted as played), the time
  // really spent playing the current track and the last position seen.
  Future<int?>? _playRow;
  int _playedMs = 0;
  int _flushedMs = 0;
  Duration? _lastTick;
  Duration _lastResumeSave = Duration.zero;

  /// Where a seek on a remote episode asked to go, until the player is there.
  Duration? _seekTo;

  /// The track whose load or stream failed: it keeps its old bookmark.
  int? _noSaveId;
  bool _handlingCompleted = false;

  // Live radio: the cleaned «now playing» text, the new attempts after a drop
  // and when the stream was left paused.
  String? _onAir;
  final _onAirController = StreamController<String?>.broadcast();
  int _radioRetries = 0;
  bool _radioBusy = false;
  bool _radioStale = false;
  Timer? _retryTimer;
  Timer? _steadyTimer;
  DateTime? _radioPausedAt;
  ({bool shuffle, PlayRepeat repeat})? _beforeRadio;

  /// The station playing now, if the current entry is a radio.
  RadioEntry? get _radioNow {
    final id = _current?.id;
    return id == null || !isOnlineId(id) ? null : online?.radioOf(id);
  }

  /// Whether the current entry is a live radio (no length, no seeking).
  bool get isRadio => _radioNow != null;

  /// The station the queue points at, even while nothing is loaded (after an
  /// error or while switching): navigation must not depend on `_current`.
  RadioEntry? get _queueRadio {
    final id = _queue.currentId;
    return id == null ? null : online?.radioOf(id);
  }

  /// What the station says is on air, or null.
  String? get onAir => _onAir;
  Stream<String?> get onAirStream => _onAirController.stream;

  /// Sleep timer "end of track": the next track is loaded but not started.
  bool get pauseAtTrackEnd => _pauseAtTrackEnd;
  set pauseAtTrackEnd(bool value) {
    _pauseAtTrackEnd = value;
    unawaited(_refreshWindow()); // nothing may follow on its own
  }

  bool _pauseAtTrackEnd = false;

  /// Fires when [pauseAtTrackEnd] has been honoured (or playback ended with
  /// it on), so the sleep timer can clear its state.
  Stream<void> get pausedAtTrackEnd => _pausedAtTrackEnd.stream;
  final _pausedAtTrackEnd = StreamController<void>.broadcast();

  TransitionMode _transition = TransitionMode.normal;
  TransitionMode get transition => _transition;

  /// In the crossfade, tracks of the same album follow each other plainly.
  bool _plainInAlbum = false;
  int _crossfadeSeconds = 6;

  /// Playback speed, kept by the handler so every new track gets it again.
  static const minSpeed = 0.5, maxSpeed = 2.0;
  double _speed = 1.0;
  double get speed => _speed;

  double _baseVolume = 1.0;
  double get volume => _baseVolume;
  final _volumeController = StreamController<double>.broadcast();
  final _volumeRequests = StreamController<double>.broadcast();

  /// Every change of the base volume (slider, sleep-timer fade, MPRIS).
  Stream<double> get volumeStream => _volumeController.stream;

  /// Volume asked from outside the app (MPRIS): the UI owner applies it so
  /// the slider and the saved setting follow.
  Stream<double> get volumeRequests => _volumeRequests.stream;

  void requestVolume(double v) {
    if (_volumeRequests.hasListener) {
      _volumeRequests.add(v);
    } else {
      unawaited(setVolume(v));
    }
  }

  bool _normalize = false;
  double _gainFactor = 1.0;

  /// The main player's equalizer, or null where there is none.
  Equalizer? get equalizer => _backend.equalizer;

  Track? get currentTrack => _current;
  Stream<Track?> get currentTrackStream => _trackController.stream;
  Stream<void> get queueChanges => _queueController.stream;
  final _posOut = StreamController<Duration>.broadcast();
  final _durOut = StreamController<Duration?>.broadcast();
  Stream<Duration> get positionStream => _posOut.stream;
  Stream<Duration?> get durationStream => _durOut.stream;
  BackendState get backendState => _state;
  bool get isPlaying => _state == BackendState.playing;
  /// Local playback is asked to run (also while loading or just resumed), not
  /// only what the backend reports now.
  bool get wantsPlay =>
      _remote == null &&
      _queue.currentId != null &&
      _playWhenReady &&
      (_current != null || _loadBusy);
  /// A Jam or other remote transport owns playback.
  bool get hasRemote => _remote != null;
  List<int> get queueIds => _queue.items;
  List<int> get queueKeys => _queue.keys;
  int get currentIndex => _queue.currentIndex;
  int get userAhead => _queue.userAhead;
  bool get currentFromUser => _queue.currentFromUser;
  bool get hasNext =>
      _queue.hasNext || (_queueRadio != null && _queue.items.length > 1);
  bool get shuffleEnabled => _queue.shuffle;
  PlayRepeat get repeatMode => _queue.repeat;

  /// The list playback was started from (a playlist, an album, the search
  /// results…): «Svuota» builds what follows again from it.
  List<int>? _source;

  /// The list playback was started from, if any.
  List<int>? get sourceIds =>
      _source == null ? null : List.unmodifiable(_source!);

  Future<void> playQueue(List<int> ids, int index) async {
    _leaveRadioMode();
    _source = List.of(ids);
    _queue.setItems(ids, startIndex: index, keepUser: true);
    _consecutiveErrors = 0;
    _queueController.add(null);
    await _loadCurrent(play: true);
  }

  /// Plays [stations] from [index]: the queue is that list, so next and
  /// previous move between stations. Shuffle and repeat are set aside until
  /// something else is played.
  Future<void> playStations(List<RadioStation> stations, int index) async {
    final registry = online;
    if (registry == null || stations.isEmpty) return;
    final ids = [for (final s in stations) registry.registerRadio(s)];
    _beforeRadio ??= (shuffle: _queue.shuffle, repeat: _queue.repeat);
    _queue.shuffle = false;
    _queue.repeat = PlayRepeat.off;
    _source = List.of(ids);
    _queue.setItems(ids, startIndex: index);
    _consecutiveErrors = 0;
    _queueController.add(null);
    await _loadCurrent(play: true);
  }

  void _leaveRadioMode() {
    final before = _beforeRadio;
    if (before == null) return;
    _beforeRadio = null;
    _queue.shuffle = before.shuffle;
    _queue.repeat = before.repeat;
  }

  /// What Android Auto and other media browsers see (set at start-up).
  MediaBrowseTree? browse;

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    try {
      return await browse?.children(parentMediaId) ?? const [];
    } on Object catch (e, st) {
      AppLog.w('browse $parentMediaId failed', e, st);
      return const [];
    }
  }

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async {
    try {
      return await browse?.item(mediaId);
    } on Object catch (e, st) {
      AppLog.w('browse item $mediaId failed', e, st);
      return null;
    }
  }

  @override
  Future<List<MediaItem>> search(
    String query, [
    Map<String, dynamic>? extras,
  ]) async {
    try {
      return await browse?.search(query) ?? const [];
    } on Object catch (e, st) {
      AppLog.w('browse search failed', e, st);
      return const [];
    }
  }

  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    try {
      // A list of the car's menu is not the last one of the app; an id that
      // resolves to nothing leaves the context alone.
      final radio = await browse?.resolveRadio(mediaId);
      if (radio != null) {
        setPlayContext(null, null);
        await playStations(radio.stations, radio.index);
        return;
      }
      final r = await browse?.resolve(mediaId);
      if (r != null) {
        setPlayContext(null, null);
        await playQueue(r.ids, r.index);
      }
    } on Object catch (e, st) {
      AppLog.w('play from $mediaId failed', e, st);
    }
  }

  /// Loads the queue paused, at [position] (used to resume after a restart).
  Future<void> restore(List<int> ids, int index, Duration position, {int userAhead = 0}) async {
    _leaveRadioMode();
    _source = List.of(ids);
    _queue.setItems(ids, startIndex: index, alreadyShuffled: true, userAhead: userAhead);
    _queueController.add(null);
    await _loadCurrent(play: false, startAt: position);
  }

  /// [ended]: when the track before ended by itself (for the gap of the timing line).
  Future<void> _loadCurrent({
    required bool play,
    Duration? startAt,
    DateTime? ended,
  }) async {
    final token = ++_loadToken;
    _waitingStream = false;
    _loadBusy = true;
    _loadPaused = false;
    _url = null;
    _recoverOnPlay = _errorWhileLoading = false;
    _playWhenReady = play;
    _cancelRadioTimers();
    final id = _queue.currentId;
    if (id == null) {
      _loadBusy = false;
      await _goIdle();
      return;
    }
    final isOnline = isOnlineId(id);
    var entry = isOnline ? online?.entryOf(id) : null;
    final radio = isOnline ? online?.radioOf(id) : null;
    // Downloaded since it was queued (D-81): the library file plays, not a stream.
    final libId = entry == null ? null : await _downloadedId(entry.result);
    final libTrack = libId == null ? null : await _tracks.getById(libId);
    if (libTrack != null) entry = null;
    final track =
        libTrack ??
        (isOnline ? online?.trackOf(id) : await _tracks.getById(id));
    if (token != _loadToken) return;
    if (track == null) {
      await _failAndSkip(PlaybackFailureReason.notInLibrary, null, token);
      return;
    }
    // The track we are leaving keeps its place (long tracks only).
    _endListen();
    _saveResume();
    _seekTo = null;
    _lastResumeSave = Duration.zero;
    // An explicit position (restoring a session) wins over the bookmark.
    // Streams have neither a bookmark nor ReplayGain.
    final streamKey = entry != null
        ? entry.result.indexKey
        : (track.kind == kStreamKind || track.kind == kEpisodeKind
              ? keyOfStreamPath(track.path)
              : null);
    // A podcast episode not downloaded: the feed's address plays as it is (a YouTube Music one has a stream key).
    final directUrl =
        streamKey == null &&
        track.kind == kEpisodeKind &&
        isRemoteEpisodePath(track.path);
    final t0 = _clock();
    _Timing timingOf(String key, String from) => (
      token: token,
      key: key,
      from: from,
      t0: t0,
      pos0: startAt ?? Duration.zero,
      ended: ended,
    );
    // A stream's line is set once its source is known (below).
    _timing = play && radio == null && streamKey == null
        ? timingOf('track:${track.id}', 'file')
        : null;
    // A saved position past the end of the track (a stale one) is not used.
    final startOk =
        startAt != null &&
        startAt > Duration.zero &&
        !isPastEnd(startAt, track.durationMs);
    final start = startOk
        ? startAt
        : ((isOnline && libTrack == null) ||
                  (streamKey != null && track.kind != kEpisodeKind)
              ? null
              : resumeStartFor(track.resumePositionMs));
    // Before the item goes out: «Caricamento…» only while waiting for the file (no awaits up to the stream branch).
    if (streamKey != null) {
      _waitingStream = true;
      _playWhenReady = play;
    }
    _enterTrack(track);
    final synced = _syncPreparer();
    unawaited(synced);
    _publish(AudioProcessingState.loading);
    var playNow = play;
    var offline = false; // the stream could not be fetched for lack of network
    var ageGated = false; // age-restricted video with no audio-only substitute
    try {
      if (radio != null) {
        _radioBusy = true;
        if (play) _notifyRadioStart(radio.station);
        await _backend.loadUri(_streamUri(radio.station));
      } else if (streamKey != null) {
        final p = preparer;
        if (p == null) throw const BackendException('no stream preparer');
        // The old track stops now; the new one starts when its file is there.
        _waitingStream = true;
        _playWhenReady = play;
        if (_state == BackendState.playing) await _backend.pause();
        if (token != _loadToken) return;
        // The queue goes to the preparer first, so the current one runs first.
        await synced;
        if (token != _loadToken) return;
        final res = entry?.result ?? streamResultOfRow(streamKey, track);
        final began = await _asStream(streamKey, p.start(streamKey, res));
        if (token != _loadToken) return;
        playNow = _playWhenReady;
        final fromUrl = await _loadStart(
          p,
          began,
          streamKey,
          res,
          entry?.id,
          token,
        );
        if (fromUrl == null) return;
        playNow = _playWhenReady;
        if (fromUrl) _url = _UrlSession(streamKey, res, entry?.id);
        if (play) _timing = timingOf(streamKey, fromUrl ? 'url' : 'cache');
      } else if (directUrl) {
        // The fragment only tells apart two episodes with one address: the server never sees it.
        final uri = Uri.tryParse(track.path)?.removeFragment();
        if (uri == null) throw const BackendException('bad episode address');
        // The old track stops now, not when the network answers.
        if (_state == BackendState.playing) await _backend.pause();
        if (token != _loadToken) return;
        await _backend.loadUri(uri);
      } else {
        await _backend.load(track.path);
      }
      if (token != _loadToken) return;
      // Some backends forget the rate when a new file is loaded. A live
      // stream cannot be sped up: it plays at 1× until a track comes.
      if (radio != null) {
        _radioBusy = false;
        if (_speed != 1.0) await _backend.setSpeed(1.0);
      } else if (_speed != 1.0) {
        await _backend.setSpeed(_speed);
      }
      if (start != null && start > Duration.zero) {
        await _backend.seek(start);
        _position = start; // a paused backend emits no position
      }
      _consecutiveErrors = 0;
      _noSaveId = null;
      // A backend that was playing keeps playing a newly loaded file.
      if (playNow && !_loadPaused) {
        await _backend.play();
      } else {
        await _backend.pause();
      }
      _window?.invalidate(); // the load dropped the backend's window
      unawaited(_refreshWindow());
    } on Object catch (e, st) {
      // A load replaced by a newer one is not a failure (just_audio: «Loading interrupted»).
      if (token != _loadToken || '$e'.toLowerCase().contains('interrupted')) {
        AppLog.d('load superseded: $e');
        return;
      }
      if (e is! BackendException) Error.throwWithStackTrace(e, st);
      AppLog.w('load failed: ${e.message}');
      if (radio != null) {
        _radioBusy = false;
        _radioRetries = 0;
        _scheduleRadioRetry(radio, token);
        return;
      }
      if (streamKey != null && e is _StreamNotReady) {
        offline = e.offline;
        ageGated = e.ageRestricted;
        playNow = _playWhenReady;
      }
      await _failAndSkip(
        offline
            ? PlaybackFailureReason.networkUnavailable
            : ageGated
            ? PlaybackFailureReason.ageRestricted
            : track.kind == kEpisodeKind && (streamKey != null || directUrl)
            ? PlaybackFailureReason.episodeUnavailable
            : (isOnline && libTrack == null) || streamKey != null || directUrl
            ? PlaybackFailureReason.onlineUnavailable
            : e.fileMissing
            ? PlaybackFailureReason.fileMissing
            : PlaybackFailureReason.unplayable,
        track,
        token,
        play: playNow,
      );
    } finally {
      if (token == _loadToken) {
        _waitingStream = _loadBusy = false;
        if (_errorWhileLoading && _url != null) _onUrlError();
        _errorWhileLoading = false;
      }
    }
  }

  /// Runs [f]; a failure is logged and comes out as a [_StreamNotReady].
  Future<T> _asStream<T>(String key, Future<T> f) async {
    try {
      return await f;
    } on Object catch (e, st) {
      AppLog.w('stream $key is not ready', e, st);
      throw _StreamNotReady(e);
    }
  }

  /// Gets [began] loaded: its address (opened, the file follows in the
  /// background) or else the file (waited for). Returns where it plays from
  /// (true: the address, false: the file), or null when a newer load took over.
  Future<bool?> _loadStart(
    StreamPreparer p,
    StreamStart began,
    String key,
    YtResult res,
    int? entryId,
    int token,
  ) async {
    if (token != _loadToken) return null;
    var file = began.file;
    if (file == null) {
      _waitingStream = false;
      try {
        await _backend.loadUri(began.url!, headers: began.headers);
        if (token != _loadToken) return null;
        // Plays count on the shadow row, which exists once the file does (the same job).
        unawaited(
          p
              .ready(key, res)
              .then(
                (_) => _bindShadow(key, entryId, token),
                onError: (Object e, StackTrace st) =>
                    AppLog.w('stream $key: no file after the address', e, st),
              ),
        );
        return true;
      } on BackendException catch (e) {
        if (token != _loadToken) return null;
        // No message to the user: the file comes, a little later (R-75).
        AppLog.i(
          'stream timing key=$key fallback=${e.expired ? 'expired' : 'load-failed'}',
        );
        _waitingStream = true;
      }
    }
    final File ready = file ?? await _asStream<File>(key, p.ready(key, res));
    if (token != _loadToken) return null;
    await _bindShadow(key, entryId, token);
    if (token != _loadToken) return null;
    _waitingStream = false;
    await _backend.load(ready.path);
    return token == _loadToken ? false : null;
  }

  Future<void> _bindShadow(String key, int? entryId, int token) async {
    if (entryId == null) return;
    try {
      final row = await _tracks.streamRow(key);
      if (token != _loadToken || row == null) return;
      _shadowId = row.id;
      online?.bindRow(entryId, row.id);
    } on Object catch (e, st) {
      AppLog.w('shadow row of $key unreadable: plays are not counted', e, st);
    }
  }

  /// The address failed: recover now if the user wants to hear it, else at ▶.
  void _onUrlError() {
    if (_playWhenReady) {
      unawaited(_recoverFromUrl());
    } else {
      _recoverOnPlay = true;
    }
  }

  Uri _streamUri(RadioStation s) {
    final uri = Uri.tryParse(s.streamUrl);
    if (uri == null || !uri.hasScheme) {
      throw const BackendException('bad stream address');
    }
    return uri;
  }

  void _notifyRadioStart(RadioStation station) {
    try {
      onRadioStart?.call(station);
    } on Object catch (e, st) {
      AppLog.w('radio start hook failed', e, st);
    }
  }

  void _cancelRadioTimers() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _steadyTimer?.cancel();
    _steadyTimer = null;
    _radioBusy = false;
  }

  /// The stream dropped or could not be opened: tries again after 2, 5 and
  /// 15 seconds, then gives up. It never jumps to another station.
  void _scheduleRadioRetry(RadioEntry radio, int token) {
    if (_radioRetries >= radioRetryDelays.length) {
      _radioRetries = 0;
      onError(
        PlaybackFailure(
          radio.station.name,
          PlaybackFailureReason.radioUnavailable,
        ),
      );
      unawaited(_goIdle());
      return;
    }
    final delay = radioRetryDelays[_radioRetries++];
    AppLog.w(
      'radio "${radio.station.name}" down, new attempt in ${delay.inSeconds}s',
    );
    _publish(AudioProcessingState.loading);
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      if (token != _loadToken) return;
      unawaited(_reconnectRadio(radio, token));
    });
  }

  Future<void> _reconnectRadio(RadioEntry radio, int token) async {
    _radioBusy = true;
    _publish(AudioProcessingState.loading);
    try {
      await _backend.loadUri(_streamUri(radio.station));
      if (token != _loadToken) return;
      _radioBusy = false;
      _radioStale = false;
      _radioPausedAt = null;
      await _backend.play();
    } on BackendException catch (e) {
      if (token != _loadToken) return;
      AppLog.w('radio reconnection failed: ${e.message}');
      _radioBusy = false;
      _scheduleRadioRetry(radio, token);
    }
  }

  /// A drop seen while playing; while paused it is only remembered, and the
  /// next play connects again.
  void _onRadioDrop(RadioEntry radio, bool wasLive) {
    if (_radioBusy || (_retryTimer?.isActive ?? false)) return;
    // A late event of the station we are leaving must not retry it.
    if (!identical(radio, _queueRadio)) return;
    if (!wasLive) {
      _radioStale = true;
      return;
    }
    _radioRetries = 0;
    _scheduleRadioRetry(radio, _loadToken);
  }

  void _onStreamTitle(String? raw) {
    final radio = _radioNow;
    if (radio == null) return;
    _setOnAir(cleanIcyTitle(raw, radio.station.name));
  }

  void _setOnAir(String? value) {
    if (value == _onAir) return;
    _onAir = value;
    _onAirController.add(value);
    final t = _current;
    if (t != null && _remote == null) mediaItem.add(_toMediaItem(t));
  }

  /// Tells the preparer the upcoming streamed tracks, current first. Only the
  /// next [_lookupAhead] library ids are read from the DB to find kind-2 rows,
  /// and only the next [_lookupAhead] online entries are checked for a download.
  static const _lookupAhead = 30;
  Future<void> _syncPreparer() async {
    final p = preparer;
    if (p == null) return;
    final token = ++_syncToken;
    final from = _queue.currentIndex < 0 ? 0 : _queue.currentIndex;
    final ids = _queue.items.skip(from).toList();
    final List<Track> rows;
    try {
      rows = await _tracks.streamRowsAmong(
        [
          for (final i in ids)
            if (!isOnlineId(i)) i,
        ].take(_lookupAhead).toList(),
      );
    } on Object catch (e, st) {
      AppLog.w('could not read the queue for the stream preparer', e, st);
      return;
    }
    if (token != _syncToken) return;
    final byId = {for (final r in rows) r.id: r};
    final out = <StreamItem>[];
    var looked = 0;
    for (final id in ids) {
      if (isOnlineId(id)) {
        final r = online?.entryOf(id)?.result;
        if (r != null &&
            (looked++ >= _lookupAhead || await _downloadedId(r) == null)) {
          out.add(StreamItem(r.indexKey, r));
        }
        if (token != _syncToken) return;
      } else {
        final row = byId[id];
        final key = row == null
            ? null
            : keyOfStreamPath(row.path); // streamRowsAmong: kind 2 and 1
        if (key != null) out.add(StreamItem(key, streamResultOfRow(key, row!)));
      }
    }
    p.setQueue(out);
  }

  /// A podcast file's tags or the feed often carry a wrong length: once the
  /// player knows the real one, the library row takes it.
  void _onBackendDuration(Duration? d) {
    if (_waitingStream) return; // the old track's length
    // The stream has not told its length yet: the one we know stays (K-SV-08).
    if (d == null && _url != null && _duration != null) return;
    if (isRadio) {
      _duration = null; // a live stream has no length
      _durOut.add(null);
      return;
    }
    _duration = d;
    _durOut.add(d);
    final t = _current;
    if (d == null || t == null || t.kind != 1) return;
    final ms = d.inMilliseconds;
    if (ms <= 0 || (ms - t.durationMs).abs() < 2000) return;
    _current = t.copyWith(durationMs: ms);
    _tracks.setDurationMs(t.id, ms).catchError((Object e, StackTrace st) {
      AppLog.w('could not save the length of "${t.title}"', e, st);
    });
  }

  /// Makes [track] the current one (state, gain, notification).
  void _enterTrack(Track track) {
    _seekTo = null;
    _playCounted = false;
    _playedMs = 0;
    _flushedMs = 0;
    _lastTick = null;
    _shadowId = null;
    _gainFactor = isStreamTrack(track) ? 1.0 : gainFactor(track.replayGainDb);
    if (_normalize) unawaited(_applyVolume());
    _position = Duration.zero;
    _duration = track.durationMs > 0
        ? Duration(milliseconds: track.durationMs)
        : null;
    _current = track;
    if (_waitingStream) {
      _posOut.add(Duration.zero);
      _durOut.add(_duration);
    }
    if (_onAir != null) {
      _onAir = null;
      _onAirController.add(null);
    }
    _trackController.add(track);
    mediaItem.add(_toMediaItem(track));
  }

  Future<void> _failAndSkip(
    PlaybackFailureReason reason,
    Track? track,
    int token, {
    bool play = true,
  }) async {
    _consecutiveErrors++;
    // What the failed track reports from here on (position 0, a seek never reached) is not a place
    // somebody listened to: its bookmark stays as it was until it plays again.
    _noSaveId = track?.id;
    onError(PlaybackFailure(track?.title, reason));
    if (_consecutiveErrors > maxConsecutiveErrors) {
      await _goIdle();
      return;
    }
    final next = _nextInQueue(auto: true);
    if (next == null) {
      await _goIdle();
      return;
    }
    await _loadCurrent(play: play);
  }

  Future<void> _goIdle() async {
    _waitingStream = false;
    _url = null;
    _cancelRadioTimers();
    _radioRetries = 0;
    _radioStale = false;
    _radioPausedAt = null;
    _endListen();
    _saveResume();
    _window?.clear();
    _loadToken++;
    await _backend.stop();
    _current = null;
    if (_onAir != null) {
      _onAir = null;
      _onAirController.add(null);
    }
    _position = Duration.zero;
    _trackController.add(null);
    mediaItem.add(null);
    _publish(AudioProcessingState.idle);
  }

  MediaItem _toMediaItem(Track t) {
    final radio = isOnlineId(t.id) ? online?.radioOf(t.id) : null;
    if (radio != null) {
      final icon = radio.station.faviconUrl;
      return MediaItem(
        id: 'radio:${radio.station.id}',
        title: _onAir ?? radio.station.name,
        artist: _onAir == null ? null : radio.station.name,
        artUri: icon.isEmpty ? null : Uri.tryParse(icon),
        extras: const {'online': true, 'radio': true},
      );
    }
    final entry = isOnlineId(t.id) ? online?.entryOf(t.id) : null;
    if (entry != null) {
      final thumb = entry.result.thumbnailUrl;
      return MediaItem(
        id: 'online:${entry.result.id}',
        title: t.title,
        artist: loadingStream ? loadingLabel() : t.artist,
        album: t.album,
        duration: _duration,
        artUri: thumb == null ? null : Uri.tryParse(googleThumbAt(thumb, 544)),
        extras: const {'online': true},
      );
    }
    final cover = coverPathFor?.call(t);
    return MediaItem(
      id: '${t.id}',
      title: t.title,
      artist: loadingStream ? loadingLabel() : t.artist,
      album: t.album,
      duration: _duration,
      artUri: cover == null ? null : Uri.file(cover),
    );
  }

  void _onBackendState(BackendState s) {
    final wasPlaying = _state == BackendState.playing;
    final wasLive = wasPlaying || _state == BackendState.loading;
    _state = s;
    if (_waitingStream) {
      if (s != BackendState.completed) _publish(AudioProcessingState.loading);
      return;
    }
    final radio = _radioNow;
    if (radio != null) {
      if (wasPlaying && s == BackendState.paused) _radioPausedAt = _clock();
      _steadyTimer?.cancel();
      if (s == BackendState.playing) {
        // A stream that holds for a while has earned a fresh set of attempts.
        _steadyTimer = Timer(_radioSteadyAfter, () => _radioRetries = 0);
      }
      if (s == BackendState.completed || s == BackendState.error) {
        _onRadioDrop(radio, wasLive);
        return;
      }
    } else if (s == BackendState.error) {
      // A player error nobody asked about: the load that caused it reports it.
      AppLog.w('player reported an error');
      final url = _url;
      if (url != null) {
        if (_loadBusy) {
          _errorWhileLoading =
              true; // the load is still going: it asks when done
        } else if (!url.recovering) {
          _onUrlError();
        }
      } else if (!_loadBusy &&
          _current != null &&
          _isRemoteEpisode(_current!)) {
        unawaited(_onStreamCut());
      }
      return;
    }
    if (wasPlaying && s == BackendState.paused) {
      _saveResume();
      _flushListen();
    }
    if (s == BackendState.completed) {
      unawaited(_onCompleted());
      return;
    }
    _publish(switch (s) {
      BackendState.idle => AudioProcessingState.idle,
      BackendState.loading => AudioProcessingState.loading,
      BackendState.error => AudioProcessingState.error,
      _ => AudioProcessingState.ready,
    });
  }

  /// The address of the streamed track failed while playing (expired, network
  /// change): asks the preparer again and goes on from the same position (R-76).
  Future<void> _recoverFromUrl() async {
    final s = _url, p = preparer;
    final token = _loadToken;
    if (s == null || s.recovering || p == null) return;
    final key = s.key, r = s.res;
    s.recovering = true;
    _recoverOnPlay = false;
    final pos = _position;
    _waitingStream = true;
    try {
      final StreamStart began;
      if (++s.recoveries > 2) {
        began = StreamStart.file(
          await _asStream<File>(key, p.ready(key, r)),
        ); // no more addresses
      } else {
        began = await _asStream(key, p.restart(key, r));
      }
      final fromUrl = await _loadStart(p, began, key, r, s.entry, token);
      if (fromUrl == null) return;
      if (!fromUrl && _url == s) _url = null;
      if (_speed != 1.0) await _backend.setSpeed(_speed);
      if (token != _loadToken) return;
      if (pos > Duration.zero) await _backend.seek(pos);
      if (token != _loadToken) return;
      _waitingStream = false;
      if (_playWhenReady) {
        await _backend.play();
      } else {
        await _backend.pause();
      }
      _window?.invalidate(); // the new load dropped the backend's window
      unawaited(_refreshWindow());
    } on Object catch (e, st) {
      AppLog.w('stream $key could not be restarted', e, st);
      if (token == _loadToken) {
        _waitingStream = false;
        await _failAndSkip(
          e is _StreamNotReady && e.offline
              ? PlaybackFailureReason.networkUnavailable
              : _current?.kind == kEpisodeKind
              ? PlaybackFailureReason.episodeUnavailable
              : PlaybackFailureReason.onlineUnavailable,
          _current,
          token,
          play: _playWhenReady,
        );
      }
    } finally {
      s.recovering = false;
      if (token == _loadToken) _waitingStream = false;
    }
  }

  Future<void> _onCompleted() async {
    if (_handlingCompleted) return;
    _handlingCompleted = true;
    final ended = _clock();
    try {
      final cur = _current;
      if (cur != null && _isRemoteEpisode(cur) && _cutShort(cur)) {
        await _failCut(cur);
        return;
      }
      _forgetBookmarkOfFinished();
      final next = _nextInQueue(auto: true);
      final stay = _pauseAtTrackEnd;
      _pauseAtTrackEnd = false;
      if (next == null) {
        await _goIdle();
      } else {
        await _loadCurrent(play: !stay, ended: ended);
      }
      if (stay) _pausedAtTrackEnd.add(null);
    } finally {
      _handlingCompleted = false;
    }
  }

  /// A streamed episode stopped well before its end (the network went): it is not heard.
  bool _cutShort(Track t) {
    final length = _lengthOf(t);
    return length > 0 && !episodeHeard(_position, length);
  }

  /// The place stays, the user is told, and the queue goes on (or stops): never stuck.
  Future<void> _failCut(Track t) async {
    AppLog.w('episode "${t.title}" stopped early at $_position');
    _saveResume();
    await _failAndSkip(
      PlaybackFailureReason.episodeUnavailable,
      t,
      _loadToken,
      play: _playWhenReady,
    );
  }

  /// The player failed on a streamed episode that was already playing.
  Future<void> _onStreamCut() async {
    final cur = _current;
    if (cur == null || _handlingCompleted) return;
    _handlingCompleted = true;
    try {
      await _failCut(cur);
    } finally {
      _handlingCompleted = false;
    }
  }

  int _lengthOf(Track t) =>
      t.durationMs > 0 ? t.durationMs : (_duration?.inMilliseconds ?? 0);

  /// A track played to its end has no place to come back to.
  void _forgetBookmarkOfFinished() {
    final finished = _current;
    if (finished == null || isStreamTrack(finished)) return;
    if (finished.kind == 1) _markHeard(finished);
    if (finished.resumePositionMs != null ||
        _savedResume[finished.id] != null) {
      unawaited(_writeResume(finished, null));
    }
  }

  /// The backend moved on by itself to the track prepared in the window.
  Future<void> _onAdvanced() async {
    final ended = _clock();
    _endListen();
    final preparedFor = _window?.id;
    final prepared = _window?.consume();
    _forgetBookmarkOfFinished();
    final id = _nextInQueue(auto: true);
    // The sleep timer was set too late to stop the backend from moving on by
    // itself: the next track has started, so stop it at its very beginning.
    final stay = _pauseAtTrackEnd;
    _pauseAtTrackEnd = false;
    if (prepared == null || id != preparedFor) {
      // The queue changed after the window was set: play what the queue says.
      if (id == null) {
        await _goIdle();
      } else {
        await _loadCurrent(play: !stay, ended: ended);
      }
      if (stay) _pausedAtTrackEnd.add(null);
      return;
    }
    _consecutiveErrors = 0;
    _lastResumeSave = Duration.zero;
    // The old load's late callbacks (a file arriving, a recovery) are not the new track's.
    _loadToken++;
    // The gapless next track is a file: an error there is not the old address's.
    _url = null;
    _recoverOnPlay = _errorWhileLoading = false;
    _enterTrack(prepared);
    // An online entry joined from its cached file: plays count on its row.
    final entry = online?.entryOf(prepared.id);
    if (entry != null) {
      unawaited(_bindShadow(entry.result.indexKey, entry.id, _loadToken));
    }
    unawaited(_syncPreparer());
    if (stay) {
      await _backend.pause();
      await _backend.seek(Duration.zero);
      _pausedAtTrackEnd.add(null);
    }
    _publish(AudioProcessingState.ready);
    await _refreshWindow();
  }

  double _volumeFor(Track t) =>
      (_baseVolume *
              (_normalize && !isStreamTrack(t)
                  ? gainFactor(t.replayGainDb)
                  : 1.0))
          .clamp(0, 1)
          .toDouble();

  /// What the window may prepare for queue id [id]: a track with a file (the
  /// library's, or a streamed one in the cache), else null: a plain load (R-80).
  Future<({Track track, String path})?> _nextFile(int id) async {
    final cur = _current;
    if (cur != null &&
        cur.id == id &&
        !isStreamTrack(cur) &&
        !_isRemoteEpisode(cur)) {
      return (track: cur, path: cur.path); // repeat one
    }
    final entry = online?.entryOf(id);
    if (isOnlineId(id) && entry == null) return null; // radio or forgotten
    final libId = entry == null ? null : await _downloadedId(entry.result);
    final lib = libId == null ? null : await _tracks.getById(libId);
    if (lib != null) return (track: lib, path: lib.path);
    final track = entry == null
        ? await _tracks.getById(id)
        : online?.trackOf(id);
    if (track == null) return null;
    if (!isStreamTrack(track) && !_isRemoteEpisode(track)) {
      return (track: track, path: track.path);
    }
    final key = entry?.result.indexKey ?? keyOfStreamPath(track.path);
    final res =
        entry?.result ?? (key == null ? null : streamResultOfRow(key, track));
    final file = key == null || res == null
        ? null
        : await preparer?.cachedFile(key, res);
    return file == null ? null : (track: track, path: file.path);
  }

  bool _isRemoteEpisode(Track t) =>
      t.kind == kEpisodeKind && isRemoteEpisodePath(t.path);

  Future<void> _refreshWindow() async {
    final window = _window;
    final current = _current;
    if (current == null) return;
    if (window == null) return;
    try {
      await window.refresh(
        current,
        enabled: _transition != TransitionMode.normal && !_pauseAtTrackEnd,
        volumeFor: _volumeFor,
        overlap: (a, b) =>
            _transition == TransitionMode.crossfade &&
            !(_plainInAlbum &&
                a.albumKey == b.albumKey &&
                // Online entries have no album key: two of them are not «the same album».
                (a.albumKey.isNotEmpty ||
                    (!isStreamTrack(a) && !isStreamTrack(b)))),
        resolve: _nextFile,
      );
    } on Object catch (e, st) {
      AppLog.w('could not prepare the next track', e, st);
    }
  }

  /// Chooses how tracks follow each other. Takes effect from the next join.
  Future<void> setTransition(
    TransitionMode mode, {
    bool plainInAlbum = false,
    int crossfadeSeconds = 6,
  }) async {
    if (mode == _transition &&
        plainInAlbum == _plainInAlbum &&
        crossfadeSeconds == _crossfadeSeconds) {
      return;
    }
    _transition = mode;
    _plainInAlbum = plainInAlbum;
    _crossfadeSeconds = crossfadeSeconds;
    final engine = _backend;
    if (engine is CrossfadeEngine) {
      engine.crossfade = mode == TransitionMode.crossfade
          ? Duration(seconds: crossfadeSeconds)
          : null;
    }
    _window?.invalidate();
    await _refreshWindow();
  }

  /// Time really spent playing the current track: the position moving on while
  /// playing (a seek is a jump, not time; at 2× it is half the music).
  void _tickPlayed(Duration p) {
    final prev = _lastTick;
    _lastTick = p;
    if (prev == null || _state != BackendState.playing) return;
    final d = p - prev;
    if (d > Duration.zero && d < const Duration(seconds: 3)) {
      _playedMs += (d.inMilliseconds / _speed).round();
    }
  }

  /// Where the listen being recorded came from (`PlayContextKind.index`).
  void setPlayContext(int? kind, String? name) =>
      _context.value = kind == null ? null : (kind: kind, name: name);

  /// The context of the list started last (null: none); the one source, so a
  /// new controller still resumes the queue with its name (D-364).
  ({int kind, String? name})? get playContext => _context.value;

  /// [playContext] as a listenable, for the providers that follow it.
  ValueListenable<({int kind, String? name})?> get playContextListenable =>
      _context;

  /// The track just counted as played: opens its row in the history.
  void _beginListen(Track track, int listenId) {
    final repo = history;
    // Podcast episodes are not music: they stay out of the history and the recap.
    if (repo == null || !recordHistory || !listenKinds.contains(track.kind)) {
      return;
    }
    _flushedMs = _playedMs;
    _playRow = repo
        .start(
          listenId,
          DateTime.now().millisecondsSinceEpoch,
          context: _context.value?.kind,
          contextName: _context.value?.name,
          msPlayed: _playedMs,
        )
        .then<int?>((id) => id)
        .catchError((Object e, StackTrace st) {
          AppLog.w('could not record the listen', e, st);
          return null;
        });
  }

  /// Writes the time played so far into the row (it only grows).
  void _flushListen() {
    final row = _playRow;
    if (row == null || _playedMs == _flushedMs) return;
    final ms = _playedMs;
    _flushedMs = ms;
    unawaited(
      row
          .then((id) async {
            if (id != null) await history!.finish(id, ms);
          })
          .catchError((Object e, StackTrace st) {
            AppLog.w('could not update the listen', e, st);
          }),
    );
  }

  void _endListen() {
    _flushListen();
    _playRow = null;
    _playedMs = 0;
    _flushedMs = 0;
    _lastTick = null;
  }

  void _onPosition(Duration p) {
    if (_waitingStream) return;
    _position = p;
    final target = _seekTo;
    if (target != null && (p - target).abs() <= kSeekConfirm) _seekTo = null;
    final timing = _timing;
    if (timing != null && _state == BackendState.playing && p > timing.pos0) {
      _timing = null;
      if (timing.token == _loadToken) {
        final now = _clock();
        final ms = now.difference(timing.t0).inMilliseconds;
        final end = timing.ended;
        final gap = end == null
            ? ''
            : ' gap=${now.difference(end).inMilliseconds}';
        AppLog.i(
          'stream timing key=${timing.key} play=$ms from=${timing.from}$gap',
        );
      }
    }
    final track = _current;
    _tickPlayed(p);
    if (_playRow != null && _playedMs - _flushedMs >= 30000) _flushListen();
    if (track != null &&
        _state == BackendState.playing &&
        (p - _lastResumeSave).abs() >= kResumeSaveEvery) {
      _lastResumeSave = p;
      _saveResume();
    }
    if (_playCounted || track == null || _state != BackendState.playing) return;
    // An online entry counts on its shadow row; radio has none (and no row yet).
    final listenId = isOnlineId(track.id) ? _shadowId : track.id;
    if (listenId == null) return;
    final total = _duration;
    final half = total != null && total > Duration.zero && p * 2 >= total;
    if (half || p >= const Duration(seconds: 30)) {
      _playCounted = true;
      _tracks.registerPlay(listenId).catchError((Object e, StackTrace st) {
        AppLog.w('registerPlay failed', e, st);
      });
      _beginListen(track, listenId);
    }
  }

  /// The notification subtitle while a stream loads (the app sets the localized text).
  String Function() loadingLabel = () => 'Caricamento…';

  bool _loadingStream = false;

  /// A stream (not a radio) waits for its file: the UI shows a spinner (R-02).
  bool get loadingStream => _waitingStream && !isRadio;

  void _publish(AudioProcessingState processing) {
    if (_remote != null) return; // the Jam owns the notification
    final cur = _current;
    final loadingNow = loadingStream;
    final loadingChanged = loadingNow != _loadingStream;
    _loadingStream = loadingNow;
    final playing = _state == BackendState.playing;
    final live = isRadio;
    playbackState.add(
      PlaybackState(
        processingState: processing,
        playing: playing,
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        androidCompactActionIndices: const [0, 1, 2],
        systemActions: live ? const {} : const {MediaAction.seek},
        updatePosition: _position,
        speed: live ? 1.0 : _speed,
        queueIndex: _queue.currentIndex < 0 ? null : _queue.currentIndex,
        shuffleMode: _queue.shuffle
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        repeatMode: switch (_queue.repeat) {
          PlayRepeat.off => AudioServiceRepeatMode.none,
          PlayRepeat.all => AudioServiceRepeatMode.all,
          PlayRepeat.one => AudioServiceRepeatMode.one,
        },
      ),
    );
    if (loadingChanged && cur != null) mediaItem.add(_toMediaItem(cur));
  }

  Future<void> togglePlayPause() async {
    if (_queue.currentId == null) return;
    if (_state == BackendState.playing || (_waitingStream && _playWhenReady)) {
      await pause();
    } else {
      await play();
    }
  }

  @override
  Future<void> play() async {
    final remote = _remote;
    if (remote != null) return remote.play();
    if (_queue.currentId == null) return;
    _loadPaused = false;
    _playWhenReady = true;
    if (_recoverOnPlay && _url != null) {
      await _recoverFromUrl();
      return;
    }
    if (_waitingStream) {
      _playWhenReady = true;
      return;
    }
    if (_current == null ||
        _state == BackendState.idle ||
        _state == BackendState.completed) {
      await _loadCurrent(play: true);
      return;
    }
    final radio = _radioNow;
    if (radio != null && _radioWentStale()) {
      _radioRetries = 0;
      _cancelRadioTimers();
      await _reconnectRadio(radio, ++_loadToken);
      return;
    }
    // Paused on the very end (the backend never said «completed»): ▶ would end
    // the last track again at once and empty the player. Start it over.
    final total = _duration;
    if (total != null &&
        _position >= total - const Duration(milliseconds: 500)) {
      await seek(Duration.zero);
    }
    await _backend.play();
  }

  bool _radioWentStale() {
    if (_radioStale) return true;
    final since = _radioPausedAt;
    return since != null && _clock().difference(since) > radioResumeAfter;
  }

  @override
  Future<void> pause() {
    if (_loadBusy) _loadPaused = true;
    if (_remote == null) _playWhenReady = false;
    if (_waitingStream && _remote == null) {
      return Future.value();
    }
    return _remote?.pause() ?? _backend.pause();
  }

  @override
  Future<void> stop() async {
    final remote = _remote;
    if (remote != null) {
      return remote.pause(); // ending the Jam is its own button
    }
    await _goIdle();
  }

  @override
  Future<void> seek(Duration position) async {
    final remote = _remote;
    if (remote != null) return remote.seek(position);
    if (isRadio || loadingStream) {
      return; // live, or the old file is still loaded
    }
    // A remote episode may not get there (no network): no place is saved until the player reports it.
    final before = _position;
    final c = _current;
    if (c != null && _isRemoteEpisode(c)) _seekTo = position;
    _position = position;
    try {
      await _backend.seek(position);
    } on Object {
      _seekTo = null;
      _position = before;
      rethrow;
    }
    _publish(playbackState.value.processingState);
  }

  /// `PlayQueue.next`, telling the lists when a shuffled lap restarts.
  int? _nextInQueue({bool auto = false}) {
    final lap = _queue.shuffle &&
        _queue.currentIndex == _queue.items.length - 1 &&
        !(auto && _queue.repeat == PlayRepeat.one);
    final id = _queue.next(auto: auto);
    if (lap && id != null) _queueController.add(null); // a new lap reshuffled everything
    return id;
  }

  @override
  Future<void> skipToNext() async {
    final remote = _remote;
    if (remote != null) return remote.next();
    if (_queue.currentId == null) return;
    var next = _nextInQueue();
    // Past the last station the list starts again.
    if (next == null && _queueRadio != null && _queue.items.length > 1) {
      _queue.jumpTo(0);
      next = _queue.currentId;
    }
    if (next == null) {
      await _goIdle();
      return;
    }
    await _loadCurrent(play: true);
  }

  @override
  Future<void> skipToPrevious() async {
    final remote = _remote;
    if (remote != null) {
      await remote.previous();
      return;
    }
    if (_queue.currentId == null) return;
    if (_queueRadio != null) {
      // A live station has no start to go back to: the previous one, wrapping.
      final n = _queue.items.length;
      if (n > 1) _queue.jumpTo((_queue.currentIndex - 1 + n) % n);
    } else if (_position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    } else {
      _queue.previous();
    }
    _queueController.add(null); // the block follows the new current entry
    await _loadCurrent(play: true);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    _queue.jumpTo(index);
    // The block moved behind the new current entry: lists must see the new order.
    _queueController.add(null);
    await _loadCurrent(play: true);
  }

  Future<void> removeFromQueue(int index) async {
    final wasCurrent = _queue.removeAt(index);
    _queueController.add(null);
    if (wasCurrent) {
      await _loadCurrent(play: _state == BackendState.playing);
    } else {
      unawaited(_refreshWindow());
    }
  }

  /// Takes every occurrence of [ids] out of the queue and out of the list
  /// playback started from (so «Svuota» never builds them again), for tracks
  /// about to be deleted from disk. When the playing one is among them the
  /// next one is loaded, keeping play/pause (or playback stops with an empty
  /// queue). Completes once the player has let go of the files: on Windows a
  /// file that is open cannot be deleted.
  Future<void> removeTracks(Set<int> ids) async {
    if (ids.isEmpty) return;
    _source = _source?.where((id) => !ids.contains(id)).toList();
    final items = _queue.items;
    final currentGone = _current != null && ids.contains(_current!.id);
    final playing = _state == BackendState.playing;
    // An online entry playing its library file goes with it, or it would reload.
    final qid = _queue.currentId;
    final gone = currentGone && qid != null && isOnlineId(qid)
        ? {...ids, qid}
        : ids;
    var removed = false;
    // From the end, so the natural indices still to visit do not shift.
    for (var i = items.length - 1; i >= 0; i--) {
      if (!gone.contains(items[i])) continue;
      _queue.removeAt(i);
      removed = true;
    }
    if (_queue.isEmpty) _source = null;
    if (!removed && !currentGone) return;
    _queueController.add(null);
    if (currentGone) {
      await _loadCurrent(play: playing);
    }
    // The gapless window may hold the next track open as well.
    await _refreshWindow();
  }

  /// Puts the online (or library) entry [id] at [index] of the play order;
  /// the current track keeps playing. Returns the index actually used.
  int insertAt(int index, int id) {
    if (_queue.isEmpty) _source = null;
    final at = _queue.insertAt(index, id);
    _queueController.add(null);
    unawaited(_refreshWindow());
    return at;
  }

  /// Swaps the stream entry [oldId] for the library track [newId] (it was
  /// downloaded) at the same place of the queue. The entry now playing keeps
  /// streaming. Returns whether anything changed.
  bool replaceQueueId(int oldId, int newId) {
    if (_queue.replaceId(oldId, newId) == 0) return false;
    _queueController.add(null);
    unawaited(_refreshWindow());
    return true;
  }

  /// Takes the first occurrence of [id] out of the queue (not out of
  /// [sourceIds]); when it was the playing one the next is loaded.
  Future<void> removeQueueId(int id) async {
    final wasCurrent = _queue.removeId(id);
    _queueController.add(null);
    if (wasCurrent) {
      await _loadCurrent(play: _state == BackendState.playing);
    } else {
      unawaited(_refreshWindow());
    }
  }

  void moveInQueue(int from, int to) {
    _queue.move(from, to);
    _queueController.add(null);
    unawaited(_refreshWindow());
  }

  /// «Svuota»: what follows the current track is dropped and, when playback
  /// started from a list, built again from it ([PlayQueue.rebuildUpcoming]).
  /// Returns the queue as it was, for an undo; null with nothing playing.
  QueueState? rebuildUpcoming() {
    if (_queue.currentId == null) return null;
    final before = _queue.saveState();
    _queue.rebuildUpcoming(_source);
    _queueController.add(null);
    unawaited(_refreshWindow());
    return before;
  }

  /// Whether [rebuildUpcoming] has a list to build from.
  bool get hasSource => _source?.isNotEmpty ?? false;

  /// Undoes [rebuildUpcoming] while the same track still plays.
  void restoreQueue(QueueState state) {
    if (!_queue.restoreState(state)) return;
    _queueController.add(null);
    unawaited(_refreshWindow());
  }

  /// Undo of a queue removal: see [PlayQueue.putBack].
  void putBackInQueue(int index, int id, {required bool user}) {
    if (_queue.isEmpty) _source = null;
    _queue.putBack(index, id, user: user);
    _queueController.add(null);
    unawaited(_refreshWindow());
  }

  void addToQueue(int trackId) {
    if (_queue.isEmpty) _source = null;
    _queue.enqueue(trackId);
    _queueController.add(null);
    unawaited(_refreshWindow());
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    if (isRadio) return; // a list of stations is never shuffled
    _queue.shuffle = shuffleMode != AudioServiceShuffleMode.none;
    _queueController.add(null);
    unawaited(_refreshWindow());
    _publish(playbackState.value.processingState);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    if (isRadio) return;
    _queue.repeat = switch (repeatMode) {
      AudioServiceRepeatMode.none => PlayRepeat.off,
      AudioServiceRepeatMode.one => PlayRepeat.one,
      _ => PlayRepeat.all,
    };
    unawaited(_refreshWindow());
    _publish(playbackState.value.processingState);
  }

  void setShuffleAndRepeat({
    required bool shuffle,
    required PlayRepeat repeat,
  }) {
    final reshuffled = _queue.shuffle != shuffle;
    _queue.shuffle = shuffle;
    _queue.repeat = repeat;
    if (reshuffled) _queueController.add(null);
    unawaited(_refreshWindow());
  }

  /// 0.5×–2×, tone unchanged (mpv `scaletempo`, ExoPlayer pitch 1.0).
  @override
  Future<void> setSpeed(double value) async {
    final v = value.clamp(minSpeed, maxSpeed).toDouble();
    if (v == _speed) return;
    _speed = v;
    // A live stream stays at 1×; the rate comes back with the next track.
    if (!isRadio) await _backend.setSpeed(v);
    _publish(playbackState.value.processingState);
  }

  Future<void> setVolume(double v) {
    _baseVolume = v.clamp(0, 1).toDouble();
    _volumeController.add(_baseVolume);
    _volumeChangedForWindow();
    return _applyVolume();
  }

  /// ReplayGain: scale the volume down for loud tracks (never above 1.0).
  Future<void> setNormalize(bool enabled) {
    _normalize = enabled;
    _volumeChangedForWindow();
    return _applyVolume();
  }

  /// The next track is announced with its own volume: tell the backend again.
  void _volumeChangedForWindow() {
    final window = _window;
    if (window == null ||
        window.track == null ||
        _transition != TransitionMode.crossfade) {
      return; // only a crossfade plays the next track before its turn
    }
    window.invalidate();
    unawaited(_refreshWindow());
  }

  static double gainFactor(double? db) =>
      db == null ? 1.0 : (db >= 0 ? 1.0 : _pow10(db / 20));

  static double _pow10(double x) => math.exp(x * math.ln10);

  Future<void> _applyVolume() => _backend.setVolume(
    (_baseVolume * (_normalize ? _gainFactor : 1.0)).clamp(0, 1),
  );

  /// Hands the system controls to [transport] (a Jam) until it is detached
  /// with null. The local queue and backend are not touched meanwhile.
  void attachRemote(RemoteTransport? transport) {
    _remoteSub?.cancel();
    _remoteSub = null;
    if (transport != null && isRadio) _stopRadioForJam();
    _remote = transport;
    if (transport == null) {
      // Back to what the local player says.
      final t = _current;
      mediaItem.add(t == null ? null : _toMediaItem(t));
      _publish(_publishedProcessing);
      return;
    }
    _showRemote(transport.status);
    _remoteSub = transport.changes.listen(_showRemote);
  }

  /// A Jam starting stops the radio, like it stops local music.
  void _stopRadioForJam() {
    _cancelRadioTimers();
    _radioRetries = 0;
    _loadToken++;
    unawaited(_backend.stop());
    _current = null;
    _onAir = null;
    _trackController.add(null);
  }

  void _showRemote(RemoteStatus s) {
    mediaItem.add(
      s.hasItem
          ? MediaItem(
              id: 'jam',
              title: s.title!,
              artist: s.artist,
              album: s.album,
              duration: s.duration,
            )
          : null,
    );
    playbackState.add(
      PlaybackState(
        processingState: s.hasItem
            ? AudioProcessingState.ready
            : AudioProcessingState.idle,
        playing: s.playing,
        controls: [
          s.playing ? MediaControl.pause : MediaControl.play,
          if (s.canSkip) MediaControl.skipToNext,
        ],
        androidCompactActionIndices: s.canSkip ? const [0, 1] : const [0],
        systemActions: const {MediaAction.seek},
        updatePosition: s.position,
        speed: 1,
      ),
    );
  }

  AudioProcessingState get _publishedProcessing =>
      playbackState.value.processingState;

  /// Stores where the current track is (only if it is long enough to matter).
  void _saveResume() {
    final t = _current;
    if (t == null || isStreamTrack(t) || t.id == _noSaveId || _seekTo != null) {
      return;
    }
    final length = _lengthOf(t);
    final episode = t.kind == 1;
    if (episode && episodeHeard(_position, length)) _markHeard(t);
    final ms = resumePointFor(_position, length, episode: episode);
    if (episode && ms != null) _markResumed(t);
    if (ms == null &&
        t.resumePositionMs == null &&
        _savedResume[t.id] == null) {
      return;
    }
    if (_savedResume.containsKey(t.id) && _savedResume[t.id] == ms) return;
    unawaited(_writeResume(t, ms));
  }

  final _heard = <int>{};

  final _resumed = <int>{};

  /// The user marked the episode [trackId] as heard by hand: its place is forgotten, and not
  /// written again while this listen goes on (it would put the episode back in «Riprendi»).
  void episodeHeardByHand(int trackId) {
    _savedResume[trackId] = null;
    _heard.add(trackId);
    _resumed.remove(trackId);
    if (_current?.id == trackId) _noSaveId = trackId;
    unawaited(
      _tracks.setResumePosition(trackId, null).catchError((
        Object e,
        StackTrace st,
      ) {
        AppLog.w('could not forget the place of episode $trackId', e, st);
      }),
    );
  }

  /// The user took the heard mark off [trackId]: this listen saves its place and ends as heard again.
  void episodeUnheardByHand(int trackId) {
    _heard.remove(trackId);
    if (_noSaveId == trackId) _noSaveId = null;
  }

  void _markResumed(Track episode) {
    if (!_resumed.add(episode.id)) return;
    _heard.remove(episode.id);
    _tell(onEpisodeResumed, episode, 'take the heard mark off');
  }

  /// Calls [callback]; a failure, also an asynchronous one, is logged and never reaches playback.
  void _tell(
    FutureOr<void> Function(int)? callback,
    Track episode,
    String what,
  ) {
    if (callback == null) return;
    unawaited(
      Future<void>.sync(() => callback(episode.id))
          .catchError((Object e, StackTrace st) {
            AppLog.w('could not $what "${episode.title}"', e, st);
          }),
    );
  }

  void _markHeard(Track episode) {
    if (!_heard.add(episode.id)) return;
    _resumed.remove(episode.id);
    _tell(onEpisodeHeard, episode, 'mark as heard');
  }

  /// Last bookmark written per track in this session (avoids repeat writes).
  final _savedResume = <int, int?>{};

  Future<void> _writeResume(Track t, int? ms) async {
    _savedResume[t.id] = ms;
    try {
      await _tracks.setResumePosition(t.id, ms);
    } on Object catch (e, st) {
      AppLog.w('could not save the resume position of "${t.title}"', e, st);
    }
  }

  Future<void> dispose() async {
    _cancelRadioTimers();
    _endListen();
    await _remoteSub?.cancel();
    preparer = null;
    for (final s in _subs) {
      await s.cancel();
    }
    await _posOut.close();
    await _durOut.close();
    await _trackController.close();
    await _queueController.close();
    await _pausedAtTrackEnd.close();
    await _onAirController.close();
    await _backend.dispose();
  }
}

typedef _Timing = ({
  int token,
  String key,
  String from,
  DateTime t0,
  Duration pos0,
  DateTime? ended,
});

/// The streamed track plays from its address: what a recovery (R-76) needs.
class _UrlSession {
  _UrlSession(this.key, this.res, this.entry);
  final String key;
  final YtResult res;
  final int? entry;
  int recoveries = 0; // after two the file is waited for
  bool recovering = false;
}

/// The stream of a track could not be had; [offline] when the network is why.
class _StreamNotReady extends BackendException {
  _StreamNotReady(Object cause)
    : offline = cause is YtException && cause.kind == YtErrorKind.network,
      ageRestricted = isAgeRestricted(cause),
      super('stream not ready: $cause');
  final bool offline;
  final bool ageRestricted;
}
