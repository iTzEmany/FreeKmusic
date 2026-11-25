import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_providers.dart';

enum NavTab { home, search, library, memory }

/// Remembers the pages the user closed with «back» (Alt+Left, the mouse's back
/// button) so «forward» can reopen them (the page is rebuilt, its state is not
/// kept). Pops by the app itself (a deleted item's page) are not recorded. A
/// new push of any other page forgets them.
class ForwardStack extends NavigatorObserver {
  final _popped = <WidgetBuilder>[];
  bool _forwarding = false;
  bool _byUser = false;

  void clear() => _popped.clear();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_byUser && route is MaterialPageRoute) _popped.add(route.builder);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!_forwarding) _popped.clear();
  }

  /// A pop asked by the user: the page may refuse (its own PopScope).
  Future<void> back() async {
    _byUser = true;
    try {
      await navigator?.maybePop();
    } finally {
      _byUser = false;
    }
  }

  void forward() {
    if (_popped.isEmpty) return;
    _forwarding = true;
    navigator?.push(MaterialPageRoute<void>(builder: _popped.removeLast()));
    _forwarding = false;
  }
}

/// One per tab, in [NavTab] order.
final forwardStacksProvider = Provider<List<ForwardStack>>(
  (ref) => [for (final _ in NavTab.values) ForwardStack()],
);

class NavIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int i) => state = i;
}

final navIndexProvider = NotifierProvider<NavIndexNotifier, int>(
  NavIndexNotifier.new,
);

/// One navigator per tab, so pages opened in a tab keep the mini-player and
/// the bottom bar on screen. A new key for one tab rebuilds it from scratch
/// (D-392): leaving a tab bumps its key, so coming back finds it as on first
/// open. The other tabs keep their key and are not rebuilt.
class TabNavigatorKeys extends Notifier<List<GlobalKey<NavigatorState>>> {
  @override
  List<GlobalKey<NavigatorState>> build() => [
    for (final t in NavTab.values) _key(t.index),
  ];

  static GlobalKey<NavigatorState> _key(int tab) =>
      GlobalKey<NavigatorState>(debugLabel: 'tab-${NavTab.values[tab].name}');

  void reset(int tab) {
    ref.read(forwardStacksProvider)[tab].clear();
    state = [
      for (final (i, k) in state.indexed) i == tab ? _key(i) : k,
    ];
  }
}

final tabNavigatorKeysProvider =
    NotifierProvider<TabNavigatorKeys, List<GlobalKey<NavigatorState>>>(
      TabNavigatorKeys.new,
    );

/// Right-hand panel of the desktop layout.
enum SidePanel { none, queue, lyrics, info }

/// Closed by default; the choice is remembered on this device (D-739).
class SidePanelNotifier extends Notifier<SidePanel> {
  @override
  SidePanel build() {
    final name = ref.read(settingsStoreProvider).readSidePanel();
    return SidePanel.values.asNameMap()[name] ?? SidePanel.none;
  }

  void _set(SidePanel p) {
    state = p;
    ref.read(settingsStoreProvider).writeSidePanel(p.name);
  }

  /// Tapping the open panel's button again closes it.
  void toggle(SidePanel p) => _set(state == p ? SidePanel.none : p);

  void close() => _set(SidePanel.none);
}

final sidePanelProvider = NotifierProvider<SidePanelNotifier, SidePanel>(
  SidePanelNotifier.new,
);
