import '../audio/codecore_audio_handler.dart' show PlaybackFailure;

/// What Shuffle+ needs from the player: the play order, the list playback
/// started from, and a way to put entries in and out of the queue. The
/// handler is adapted to it (`providers/shuffle_plus_providers.dart`), tests
/// use a fake.
abstract interface class ShuffleHost {
  /// The play order (library ids are > 0, online ones < 0).
  List<int> get queueIds;
  int get currentIndex;

  /// The list playback was started from, null when there is none.
  List<int>? get sourceIds;
  bool get shuffleEnabled;
  bool get isPlaying;

  /// How many entries right after the current one are the user's queue block.
  int get userAhead;

  /// Fires when the queue, the current song, shuffle or play/pause change.
  Stream<void> get changes;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<PlaybackFailure> get failures;

  void insertAt(int index, int id);
  Future<void> removeQueueId(int id);
}
