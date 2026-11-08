import 'dart:math' as math;
import 'dart:ui' show DisplayFeatureType;

import '../screens/share/pairing_dialogs.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart' show kEnableYoutube;
import '../../core/platform.dart';
import '../../providers/library_providers.dart';
import '../../providers/nav_providers.dart';
import '../../providers/player_providers.dart';
import '../../providers/pending_playlist_adds.dart';
import '../../providers/preview_providers.dart';
import '../../providers/shuffle_plus_providers.dart';
import '../../services/shuffle_plus/shuffle_plus_controller.dart'
    show ShufflePlusNotice;
import '../../providers/ui_providers.dart';
import '../../providers/youtube_providers.dart' show ytDlpStatusProvider;
import '../../services/audio/codecore_audio_handler.dart';
import '../screens/library/library_screen.dart';
import '../screens/memory/memory_screen.dart';
import '../screens/share/incoming_offer_dialog.dart';
import '../../providers/jam_providers.dart';
import '../../providers/jam_remote_providers.dart' show jamBridgeProvider;
import '../../providers/share_hub.dart';
import '../screens/jam/jam_request_dialog.dart';
import '../screens/jam/speaker_notices.dart';
import '../screens/jam/speaker_sheets.dart';
import '../../providers/speaker_providers.dart';
import '../screens/search/search_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/releases/new_releases_screen.dart';
import '../../providers/exportify_providers.dart' show incomingPathProvider;
import '../../providers/releases_providers.dart' show launchTargetProvider;
import '../screens/import/import_flow.dart' show openImportFile;
import 'shell_nav.dart';
import '../../l10n/l10n_ext.dart';
import '../theme/tokens.dart';
import '../widgets/enrich_result_listener.dart';
import '../widgets/import_event_listener.dart';
import 'bottom_bar.dart';
import 'desktop_player_bar.dart';
import 'desktop_sidebar.dart';
import 'shell_keys.dart';
import 'side_panel.dart';
import '../widgets/motion.dart';
import '../widgets/show_msg.dart';

/// Ctrl+F searches the Library when there is no online Search or it is the
/// current tab; elsewhere it opens Search.
@visibleForTesting
bool ctrlFTargetsLibrary({required bool youtube, required int tab}) =>
    !youtube || tab == NavTab.library.index;

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const _space = SingleActivator(LogicalKeyboardKey.space);
  static const _volUp = SingleActivator(
    LogicalKeyboardKey.arrowUp,
    control: true,
  );
  static const _volDown = SingleActivator(
    LogicalKeyboardKey.arrowDown,
    control: true,
  );

  Map<ShortcutActivator, VoidCallback> _shortcuts(
    WidgetRef ref, {
    required bool preview,
  }) {
    void back() => ref
        .read(tabNavigatorKeysProvider)[ref.read(navIndexProvider)]
        .currentState
        ?.maybePop();
    final ctrl = ref.read(playerControllerProvider);
    final vol = ref.read(volumeProvider.notifier);

    void bump(double d) =>
        vol.set((ref.read(volumeProvider) + d).clamp(0.0, 1.0));
    return {
      _space: ctrl.togglePlayPause,
      const SingleActivator(LogicalKeyboardKey.arrowRight, control: true):
          ctrl.next,
      const SingleActivator(LogicalKeyboardKey.arrowLeft, control: true):
          ctrl.previous,
      // Hardware media keys (delivered to the focused window).
      const SingleActivator(LogicalKeyboardKey.mediaPlayPause):
          ctrl.togglePlayPause,
      const SingleActivator(LogicalKeyboardKey.mediaTrackNext): ctrl.next,
      const SingleActivator(LogicalKeyboardKey.mediaTrackPrevious):
          ctrl.previous,
      const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
        if (ctrlFTargetsLibrary(
          youtube: kEnableYoutube,
          tab: ref.read(navIndexProvider),
        )) {
          final wasLibrary = ref.read(navIndexProvider) == NavTab.library.index;
          final nav = ref.read(tabNavigatorKeysProvider)[NavTab.library.index];
          // An album or a list may sit above the Library: the lens is on its root.
          nav.currentState?.popUntil((r) => r.isFirst);
          ref.read(navIndexProvider.notifier).set(NavTab.library.index);
          void request() =>
              ref.read(librarySearchRequestProvider.notifier).request();
          if (wasLibrary) {
            request();
          } else {
            // The tab may only mount after the frame and must hear the request.
            WidgetsBinding.instance.addPostFrameCallback((_) => request());
            WidgetsBinding.instance.scheduleFrame();
          }
          return;
        }
        // Narrow windows have no page field: the dock's one opens (and focuses).
        ref.read(searchBarProvider.notifier).open();
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => ref.read(searchFocusProvider).requestFocus(),
        );
      },
      const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): back,
      // Ends a 20 s preview started from the menu. Only bound while one
      // runs: ShellKeys would swallow the Esc a sheet in a tab needs.
      if (preview)
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            ref.read(previewProvider.notifier).stop(),
      _volUp: () => bump(0.05),
      _volDown: () => bump(-0.05),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _listen(context, ref);
    final index = ref.watch(navIndexProvider);
    final keys = ref.watch(tabNavigatorKeysProvider);
    // Leaving a tab sends it back to its first state; the tab being entered
    // is untouched, so a page pushed there right after (openInLibrary) stays.
    ref.listen(navIndexProvider, (prev, next) {
      if (prev == null || prev == next) return;
      // A page pushed in the tab that guards its exit keeps the tab as it is.
      if (ShellNav.pageGuardsExit(keys[prev].currentState)) return;
      ref.read(tabNavigatorKeysProvider.notifier).reset(prev);
      if (prev == NavTab.search.index) {
        ref.read(searchControllerProvider).clear();
      }
      if (prev == NavTab.library.index) {
        ref.invalidate(trackQueryProvider(false));
      }
    });
    final wide = MediaQuery.sizeOf(context).width >= CcDims.wideBreakpoint;
    final l = context.l10n;
    void select(int i) {
      if (i == index) ShellNav.popToRoot(keys[i].currentState);
      if (i == NavTab.search.index) {
        ref.read(searchBarProvider.notifier).open();
      } else if (i != index) {
        ref.read(navIndexProvider.notifier).set(i);
      }
    }

    final items = [
      BottomBarItem(Icons.home_outlined, Icons.home_rounded, l.navHome),
      BottomBarItem(Icons.search_rounded, Icons.search_rounded, l.navSearch),
      BottomBarItem(
        Icons.library_music_outlined,
        Icons.library_music_rounded,
        l.navLibrary,
      ),
      BottomBarItem(Icons.storage_outlined, Icons.storage_rounded, l.navMemory),
    ];
    Widget tab(int i, Widget root) => Navigator(
      key: keys[i],
      // A page opened from Search brings the tabs back, so Back pops it.
      observers: [
        if (i == NavTab.search.index)
          _SearchPages(
            onPush: ref.read(searchBarProvider.notifier).close,
            onReturn: ref.read(searchBarProvider.notifier).reopen,
          ),
      ],
      onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => root),
    );
    final body = TabFade(
      child: IndexedStack(
        index: index,
        // Offstage does not stop tickers: a hidden tab's spinner would keep
        // repainting the whole stack.
        children: [
          for (final (i, page) in [
            (NavTab.home.index, const HomeScreen()),
            (NavTab.search.index, const SearchScreen()),
            (NavTab.library.index, const LibraryScreen()),
            (NavTab.memory.index, const MemoryScreen()),
          ])
            TickerMode(enabled: i == index, child: tab(i, page)),
        ],
      ),
    );
    Widget content;
    if (wide) {
      content = _WideShell(body: body);
    } else {
      // extendBody: the body runs under the dock, and the Scaffold gives it the
      // dock's height as MediaQuery.padding.bottom, the one inset lists read.
      content = Scaffold(
        extendBody: true,
        // viewPadding follows the dock too: nested Scaffolds lift their FABs
        // by it, not by padding.
        body: Builder(
          builder: (c) {
            final mq = MediaQuery.of(c);
            return MediaQuery(
              data: mq.copyWith(
                viewPadding: mq.viewPadding.copyWith(
                  bottom: math.max(mq.viewPadding.bottom, mq.padding.bottom),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Expanded(child: body),
                    const EnrichResultListener(),
                    const ImportEventListener(),
                  ],
                ),
              ),
            );
          },
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SpeakerAwayNotice(),
            const JamInviteBanner(),
            // Own layer: the dot, ink and mini player repaint only the dock, and the
            // engine can cache it while the page under it animates.
            RepaintBoundary(
              child: ShellDock(items: items, selected: index, onSelect: select),
            ),
          ],
        ),
      );
    }
    // Android back: keyboard, nested navigator, Home, then leave the app.
    content = PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // The phone's Search field with the keyboard up: Back only hides the
        // keyboard. (View, not MediaQuery: no rebuild on each keyboard frame.)
        if (!wide &&
            index == NavTab.search.index &&
            ref.read(searchBarProvider) &&
            View.of(context).viewInsets.bottom > 0) {
          ref.read(searchFocusProvider).unfocus();
          return;
        }
        final nav = keys[index].currentState;
        // maybePop (not pop) so a page's own PopScope, e.g. a selection that
        // Back must end first, is consulted.
        if (nav != null && await nav.maybePop()) {
          return;
        } else if (index != 0) {
          ref.read(navIndexProvider.notifier).set(0);
        } else {
          SystemNavigator.pop();
        }
      },
      child: content,
    );
    if (isDesktop) {
      content = ShellKeys(
        bindings: _shortcuts(
          ref,
          preview: ref.watch(previewProvider.select((p) => p.active)),
        ),
        textOnly: const {_space, _volUp, _volDown},
        // Any click ends a preview started from the menu.
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) {
            if (ref.read(previewProvider).active) {
              ref.read(previewProvider.notifier).stop();
            }
          },
          child: content,
        ),
      );
    }
    return content;
  }

  void _listen(BuildContext context, WidgetRef ref) {
    // Desktop only: starts the yt-dlp version check at launch (Android would
    // have to boot its embedded Python for it).
    if (isDesktop) ref.listen(ytDlpStatusProvider, (_, _) {});
    ref.listen(playerFailuresProvider, (_, next) {
      final f = next.value;
      if (f == null) return;
      final l = context.l10n;
      final reason = switch (f.reason) {
        PlaybackFailureReason.fileMissing => l.reasonFileMissing,
        PlaybackFailureReason.unplayable => l.reasonUnplayable,
        PlaybackFailureReason.notInLibrary => l.reasonNotInLibrary,
        PlaybackFailureReason.onlineUnavailable => l.reasonOnlineUnavailable,
        PlaybackFailureReason.ageRestricted => l.reasonAgeRestricted,
        PlaybackFailureReason.networkUnavailable => l.ytErrNetwork,
        PlaybackFailureReason.radioUnavailable => l.reasonRadioUnavailable,
      };
      showMsg(context, l.playbackError(f.title ?? '', reason));
    });
    // Shuffle+ runs while the shell is up; a suggestion downloaded "into a
    // playlist" joins it when the file lands.
    ref.watch(shufflePlusProvider);
    ref.watch(pendingPlaylistAddsProvider);
    ref.listen(shufflePlusNoticesProvider, (_, next) {
      final n = next.value;
      if (n == null) return;
      final l = context.l10n;
      showMsg(context, switch (n) {
        ShufflePlusNotice.rateLimited => l.shufflePlusNoticeRateLimited,
        ShufflePlusNotice.tooManyErrors => l.shufflePlusNoticeTooManyErrors,
      });
    });
    // A tap on the «Nuove uscite» notification opens that page.
    ref.listen(launchTargetProvider, (_, next) {
      if (next.value != 'releases') return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ShellNav.openInHome(context, ref, const NewReleasesScreen());
        }
      });
    });
    // A ZIP/CSV opened with Codecore from another app (Android).
    ref.listen(incomingPathProvider, (_, next) {
      final path = next.value;
      if (path == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) openImportFile(context, ref, path);
      });
    });
    ref.listen(shareOffersProvider, (_, next) {
      final o = next.value;
      if (o == null) return;
      showDialog<void>(
        context: context,
        builder: (_) => IncomingOfferDialog(offer: o),
      );
    });
    ref.listen(pairRequestsProvider, (_, next) {
      final r = next.value;
      if (r == null) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PairRequestDialog(request: r),
      );
    });
    ref.listen(jamRequestsProvider, (_, next) {
      final r = next.value;
      if (r == null) return;
      showDialog<void>(
        context: context,
        builder: (_) => JamRequestDialog(request: r),
      );
    });
    // Permission and «È una cassa?» (Android; the stream is silent elsewhere).
    ref.listen(speakerPromptsProvider, (_, next) {
      final p = next.value;
      if (p != null) showSpeakerPrompt(context, p);
    });
    // The remote bridge's switch and the speaker's Jam live as long as the shell.
    ref.listen(jamBridgeProvider, (_, _) {}); // keep-alive only, no rebuild
    final speakerJam = ref.watch(speakerJamProvider);
    ref.listen(speakerOfferProvider, (_, next) {
      if (next.value == true) {
        showSpeakerOffer(context, speakerJam);
      } else {
        closeSpeakerOffer();
      }
    });
  }
}

class _WideShell extends ConsumerWidget {
  const _WideShell({required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final panel = ref.watch(sidePanelProvider);
    final collapsed = width < 1000;
    // Wide windows show the queue from the first track on, until the user
    // closes it (or picks another panel).
    if (width >= CcDims.xlBreakpoint &&
        panel == SidePanel.none &&
        !ref.read(sidePanelProvider.notifier).chosen &&
        ref.watch(currentTrackProvider.select((t) => t.value != null))) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(sidePanelProvider.notifier).autoOpen(),
      );
    }
    // A vertical hinge must not cut the sidebar: the content starts after it.
    final hinge = MediaQuery.displayFeaturesOf(context)
        .where(
          (f) =>
              (f.type == DisplayFeatureType.hinge ||
                  f.type == DisplayFeatureType.fold) &&
              f.bounds.height >= MediaQuery.sizeOf(context).height * 0.9 &&
              f.bounds.width < width / 3,
        )
        .firstOrNull;
    final sidebarWidth = collapsed
        ? CcDims.sidebarCollapsedWidth
        : CcDims.sidebarWidth;
    final inset = hinge != null && hinge.bounds.left < sidebarWidth
        ? hinge.bounds.right
        : 0.0;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(left: inset),
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    DesktopSidebar(collapsed: collapsed),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(child: body),
                          const EnrichResultListener(),
                          const ImportEventListener(),
                        ],
                      ),
                    ),
                    if (panel != SidePanel.none) SidePanelView(panel: panel),
                  ],
                ),
              ),
              const SpeakerAwayNotice(),
              const JamInviteBanner(),
              const DesktopPlayerBar(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchPages extends NavigatorObserver {
  _SearchPages({required this.onPush, required this.onReturn});

  final VoidCallback onPush, onReturn;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // The tab's root route is pushed while the navigator builds.
    if (previousRoute != null) onPush();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute?.isFirst ?? false) onReturn();
  }
}
