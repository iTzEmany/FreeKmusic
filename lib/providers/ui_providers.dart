import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'nav_providers.dart';

/// Shared so Ctrl+F in the shell can focus the tracks search field.
final searchFocusProvider = Provider<FocusNode>((ref) {
  final node = FocusNode(debugLabel: 'search');
  ref.onDispose(node.dispose);
  return node;
});

/// The Search text, shared by the dock's field (phone), the desktop field in
/// `SearchScreen` and the page that reads it.
final searchControllerProvider = Provider<TextEditingController>((ref) {
  final c = TextEditingController();
  ref.onDispose(c.dispose);
  return c;
});

/// Counts the submits (Enter) of the dock's field; `SearchScreen` runs them.
class SearchSubmitNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void submit() => state++;
}

final searchSubmitProvider = NotifierProvider<SearchSubmitNotifier, int>(
  SearchSubmitNotifier.new,
);

/// Counts the Ctrl+F requests for the Library's own search; `LibraryScreen` opens it.
class LibrarySearchRequestNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state++;
}

final librarySearchRequestProvider =
    NotifierProvider<LibrarySearchRequestNotifier, int>(
      LibrarySearchRequestNotifier.new,
    );

/// True while the phone's dock carries the Search field (on the Search tab).
class SearchBarNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Any way out of Search (a page opened in Library...) closes the field.
    ref.listen(navIndexProvider, (_, tab) {
      if (tab != NavTab.search.index) state = false;
    });
    return false;
  }

  /// Shows the field above the dock, on the Search tab. No focus, no
  /// keyboard: the focus comes with a tap (Ctrl+F asks for it itself).
  void open() {
    ref.read(navIndexProvider.notifier).set(NavTab.search.index);
    state = true;
  }

  /// Back to the root of Search from a page: the field returns, no keyboard.
  void reopen() {
    if (ref.read(navIndexProvider) != NavTab.search.index) return;
    state = true;
  }

  /// A page opened from Search: the field goes, the text stays.
  void close() {
    ref.read(searchFocusProvider).unfocus();
    state = false;
  }
}

final searchBarProvider = NotifierProvider<SearchBarNotifier, bool>(
  SearchBarNotifier.new,
);
