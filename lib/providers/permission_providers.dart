import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/permissions.dart';

/// Whether audio files can be read (always true on desktop). Read at start and on every
/// resume, so the home banner and the Settings entry vanish when the user grants it in the system settings.
final audioPermissionProvider = NotifierProvider<AudioPermission, bool>(AudioPermission.new);

class AudioPermission extends Notifier<bool> {
  @override
  bool build() {
    final life = AppLifecycleListener(onResume: () => unawaited(refresh()));
    ref.onDispose(life.dispose);
    unawaited(refresh());
    return true;
  }

  Future<void> refresh() async {
    final ok = await hasAudioPermission();
    if (ref.mounted) state = ok;
  }

  /// The one «Concedi»: asks; if the system will not ask again, opens the app's settings.
  Future<void> grant() async {
    if (await isAudioPermissionPermanentlyDenied()) {
      await openAudioPermissionSettings();
    } else {
      state = await ensureAudioPermission();
    }
  }
}
