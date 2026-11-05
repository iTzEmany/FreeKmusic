import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/library_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../theme/tokens.dart';
import 'onboarding_screen.dart';

/// Shows the first-run guide instead of [child] when the app starts with an
/// empty library and the guide was never finished. Whoever already has music
/// (an update, a restored backup) never sees it, and is not asked later.
class OnboardingGate extends ConsumerStatefulWidget {
  const OnboardingGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends ConsumerState<OnboardingGate> {
  /// Once the guide has started it stays until it ends, even though adding a
  /// folder makes the library «not empty» on the way.
  bool _guiding = false;

  @override
  Widget build(BuildContext context) {
    final done = ref.watch(settingsProvider.select((s) => s.onboardingDone));
    if (done) return widget.child;
    if (_guiding) {
      return OnboardingScreen(
        onFinished: () => setState(() => _guiding = false),
      );
    }
    final folders = ref.watch(foldersProvider);
    final tracks = ref.watch(tracksProvider(const TrackQuery()));
    // Wait for both answers: no flash of the app before the guide.
    if (!folders.hasValue || !tracks.hasValue) {
      return ColoredBox(color: context.cc.bg);
    }
    final empty = folders.value!.isEmpty && tracks.value!.isEmpty;
    if (empty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _guiding = true);
      });
      return ColoredBox(color: context.cc.bg);
    }
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
