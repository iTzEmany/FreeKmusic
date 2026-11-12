import '../../l10n/app_localizations.dart';
import '../../services/audio/codecore_audio_handler.dart' show PlaybackFailureReason;

/// The user-facing text of why a track did not play (snackbar and Registro).
String playbackReasonText(AppLocalizations l, PlaybackFailureReason? r) => switch (r) {
  PlaybackFailureReason.fileMissing => l.reasonFileMissing,
  PlaybackFailureReason.notInLibrary => l.reasonNotInLibrary,
  PlaybackFailureReason.onlineUnavailable => l.reasonOnlineUnavailable,
  PlaybackFailureReason.episodeUnavailable => l.reasonEpisodeUnavailable,
  PlaybackFailureReason.ageRestricted => l.reasonAgeRestricted,
  PlaybackFailureReason.networkUnavailable => l.ytErrNetwork,
  PlaybackFailureReason.radioUnavailable => l.reasonRadioUnavailable,
  PlaybackFailureReason.unplayable || null => l.reasonUnplayable,
};
