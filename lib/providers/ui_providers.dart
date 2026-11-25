import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared so Ctrl+F in the shell can focus the tracks search field.
final searchFocusProvider = Provider<FocusNode>((ref) {
  final node = FocusNode(debugLabel: 'search');
  ref.onDispose(node.dispose);
  return node;
});

/// The Search text, shared by the field in `SearchScreen` and the pages that read it.
final searchControllerProvider = Provider<TextEditingController>((ref) {
  final c = TextEditingController();
  ref.onDispose(c.dispose);
  return c;
});

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

/// A text for the Search tab to run in «Online» (from «Cerca questo brano»).
class SearchPrefillNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? text) => state = text;
}

final searchPrefillProvider =
    NotifierProvider<SearchPrefillNotifier, String?>(SearchPrefillNotifier.new);

/// Counts the F5 requests: the page on screen (Search, Nuove uscite, the online
/// pages) reads again, see [listenReload].
class ReloadRequestNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state++;
}

final reloadRequestProvider =
    NotifierProvider<ReloadRequestNotifier, int>(ReloadRequestNotifier.new);

final _reloading = Expando<bool>('reloading');

/// Call from `build`: runs [onReload] on F5 when this page is the one shown
/// (not a page under another one, nor one of a hidden tab). A second F5 while
/// the first reload runs is dropped.
void listenReload(BuildContext context, WidgetRef ref, FutureOr<void> Function()? onReload) {
  ref.listen(reloadRequestProvider, (_, _) async {
    if (onReload == null || !context.mounted || _reloading[context] == true) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true) || !TickerMode.valuesOf(context).enabled) return;
    _reloading[context] = true;
    try {
      await onReload();
    } finally {
      _reloading[context] = false;
    }
  });
}
