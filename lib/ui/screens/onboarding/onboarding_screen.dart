import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/settings_providers.dart';
import '../../theme/tokens.dart';
import 'onboarding_pages.dart';

const onboardingPageCount = 5;

/// The guide of the first start: welcome, music folders (and, on Android, the
/// audio permission), the online features (off by default), the optional
/// Spotify sync reminder and what downloads,
/// Jam and sharing do.  It cannot be skipped.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.onFinished, this.askAudioPermission});

  /// Called once, after the choices are saved (the gate uses it to move on).
  final VoidCallback? onFinished;

  /// Whether the folders page explains and asks for the audio permission
  /// (Android only). Defaults to the platform.
  final bool? askAudioPermission;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _last => _page == onboardingPageCount - 1;

  void _finish() {
    // Whoever read the last page has seen the download notice.
    ref
        .read(settingsProvider.notifier)
        .update(
          (s) => s.copyWith(
            onboardingDone: true,
            ytNoticeSeen: true,
          ),
        );
    widget.onFinished?.call();
  }

  void _next() {
    if (_last) {
      _finish();
    } else {
      _controller.nextPage(
        duration: ccDuration(context, CcMotion.sheet),
        curve: CcMotion.curveIn,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final askPermission = widget.askAudioPermission ?? isAndroid;
    return Scaffold(
      backgroundColor: cc.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _page = i),
                    children: [
                      const WelcomePage(),
                      FoldersPage(askAudioPermission: askPermission),
                      const OnlinePage(),
                      const SpotifyPage(),
                      const SharePage(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    CcDims.margin,
                    CcDims.gap8,
                    CcDims.margin,
                    CcDims.margin,
                  ),
                  child: Row(
                    children: [
                      Text(
                        l.onboardingPageOf(_page + 1, onboardingPageCount),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cc.textMuted),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _next,
                        child: Text(
                          _last ? l.onboardingStart : l.onboardingNext,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
