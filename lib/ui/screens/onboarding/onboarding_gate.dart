import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_log.dart';
import '../../../providers/library_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../services/platform/flatpak_data_notice.dart';
import '../../theme/tokens.dart';
import 'flatpak_data_dialog.dart';
import 'onboarding_screen.dart';

/// Shows the first-run guide instead of [child] when the app starts with an
/// empty library and the guide was never finished. Whoever already has music
/// (an update, a restored backup) never sees it, and is not asked later.
class OnboardingGate extends ConsumerStatefulWidget {
  const OnboardingGate({super.key, required this.child, this.ensureFolder, this.env});

  final Widget child;

  /// R-228: adds the default folder when the library has none (the app passes it).
  final Future<void> Function()? ensureFolder;

  /// The environment the flatpak check reads (tests inject it).
  final Map<String, String>? env;

  @override
  ConsumerState<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends ConsumerState<OnboardingGate> {
  /// Once the guide has started it stays until it ends, even though adding a
  /// folder makes the library «not empty» on the way.
  bool _guiding = false;
  bool _ensured = false;
  bool _noticed = false;

  /// F-214: once per install, when the library is empty inside a flatpak.
  void _noticeOnce() {
    if (_noticed) return;
    final store = ref.read(settingsStoreProvider);
    if (!flatpakNoticeDue(env: widget.env ?? Platform.environment, libraryEmpty: true, shown: store.flatpakNoticeShown)) return;
    _noticed = true;
    store.markFlatpakNoticeShown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showFlatpakDataDialog(context);
    });
  }

  void _ensureOnce() {
    if (_ensured || widget.ensureFolder == null) return;
    _ensured = true;
    widget.ensureFolder!().catchError((Object e) => AppLog.w('default folder: $e'));
  }

  @override
  Widget build(BuildContext context) {
    final done = ref.watch(settingsProvider.select((s) => s.onboardingDone));
    final folders = ref.watch(foldersProvider);
    if (done) {
      if (folders.value?.isEmpty ?? false) {
        _noticeOnce();
        _ensureOnce();
      }
      return widget.child;
    }
    if (_guiding) {
      return OnboardingScreen(
        onFinished: () {
          _ensureOnce(); // the permission was explained by the guide
          setState(() => _guiding = false);
        },
      );
    }
    final tracks = ref.watch(tracksProvider(const TrackQuery()));
    // Wait for both answers: no flash of the app before the guide.
    if (!folders.hasValue || !tracks.hasValue) {
      return ColoredBox(color: context.cc.bg);
    }
    final empty = folders.value!.isEmpty && tracks.value!.isEmpty;
    if (empty) {
      _noticeOnce();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _guiding = true);
      });
      return ColoredBox(color: context.cc.bg);
    }
    _noticed = true; // someone with music never gets it, not even after the library list settles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(settingsProvider.notifier)
            .update((s) => s.copyWith(onboardingDone: true));
      }
    });
    return widget.child;
  }
}
