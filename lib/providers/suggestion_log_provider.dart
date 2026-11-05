import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/paths.dart';
import '../services/shuffle_plus/suggestion_log.dart';

/// `suggestions.json`: what was suggested and how it ended. A leaf file, so
/// that the player and Shuffle+ providers can both read it.
final suggestionLogProvider = Provider<SuggestionLog>((ref) {
  final log = SuggestionLog(
      file: () async => File(p.join(await appSupportDir(), 'suggestions.json')));
  ref.onDispose(() => unawaited(log.flush()));
  return log;
});
