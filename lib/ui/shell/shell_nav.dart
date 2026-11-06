import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/nav_providers.dart';
import '../../providers/ui_providers.dart';

/// Opens pages inside the tab's own navigator so the mini-player and the
/// bottom bar stay on screen.
abstract final class ShellNav {
  /// In the current tab. Called from a page already inside a tab navigator it
  /// is the same as `Navigator.of(context).push`.
  static Future<T?> open<T>(BuildContext context, Widget page) =>
      Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: (_) => page));

  /// True when a page pushed above the tab's root guards its exit (unsaved
  /// edits, a running job). The root itself may guard (the Library lens): it
  /// does not count.
  static bool pageGuardsExit(NavigatorState? nav) {
    if (nav == null || !nav.canPop()) return false;
    var guarded = false;
    nav.popUntil((r) {
      guarded = r.popDisposition == RoutePopDisposition.doNotPop;
      return true;
    });
    return guarded;
  }

  /// Re-selecting the active tab: back to its root, but a guarding page gets
  /// to ask first (its own PopScope runs).
  static void popToRoot(NavigatorState? nav) {
    if (nav == null) return;
    if (pageGuardsExit(nav)) {
      nav.maybePop();
    } else {
      nav.popUntil((r) => r.isFirst);
    }
  }

  /// From anywhere (Now Playing, lyrics, other tabs): closes the routes above
  /// the shell, switches to Library and pushes [page] there.
  static void openInLibrary(BuildContext context, WidgetRef ref, Widget page) {
    final root = Navigator.of(context, rootNavigator: true);
    root.popUntil((r) => r.isFirst);
    ref.read(navIndexProvider.notifier).set(NavTab.library.index);
    final nav = ref
        .read(tabNavigatorKeysProvider)[NavTab.library.index]
        .currentState;
    nav?.push(MaterialPageRoute<void>(builder: (_) => page));
  }

  /// Same as [openInLibrary] but for the Home tab (a tap on a notification).
  static void openInHome(BuildContext context, WidgetRef ref, Widget page) {
    final root = Navigator.of(context, rootNavigator: true);
    root.popUntil((r) => r.isFirst);
    ref.read(navIndexProvider.notifier).set(NavTab.home.index);
    final nav = ref.read(tabNavigatorKeysProvider)[NavTab.home.index].currentState;
    nav?.push(MaterialPageRoute<void>(builder: (_) => page));
  }

  /// Same as [openInLibrary] but for the Search tab.
  static void showSearch(BuildContext context, WidgetRef ref) {
    final root = Navigator.of(context, rootNavigator: true);
    root.popUntil((r) => r.isFirst);
    ref.read(searchBarProvider.notifier).open();
  }
}
