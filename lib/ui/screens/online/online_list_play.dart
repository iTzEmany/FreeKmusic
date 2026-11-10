import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_log.dart';
import '../../../providers/player_providers.dart';
import '../../../services/online/youtube_service.dart' show YtResult;
import '../../widgets/show_msg.dart';
import '../now_playing/now_playing_screen.dart';

/// Play / Shuffle of an online list: opens the player in loading; the controller
/// queues the list in the Jam instead when one is on (D-89), then no player opens.
void playOrQueueOnline(BuildContext context, WidgetRef ref, List<YtResult> songs,
    {required Object listKey}) {
  if (songs.isEmpty) return;
  unawaited(ref.read(playerControllerProvider).inJam
      ? queueOnlineList(context, ref, songs)
      : playOnlineListAndOpen(context, ref, songs, listKey: listKey));
}

Future<void> queueOnlineList(BuildContext context, WidgetRef ref, List<YtResult> songs) async {
  final ctrl = ref.read(playerControllerProvider);
  var added = 0, full = false;
  try {
    for (final r in songs) {
      if (ctrl.jamQueueFull) {
        full = true;
        break;
      }
      await ctrl.enqueueOnline(r);
      added++;
    }
  } on Object catch (e, st) {
    AppLog.w('online list queue failed', e, st);
    return;
  }
  if (context.mounted) showQueued(context, (added: added, full: full), wanted: songs.length);
}
