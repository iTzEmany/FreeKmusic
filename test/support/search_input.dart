import 'package:codecore/providers/library_providers.dart' show searchIndexProvider;
import 'package:codecore/providers/ui_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter_test/flutter_test.dart';

// On a phone the Search field lives in the dock; tests that pump only
// `SearchScreen` drive the same shared controller and submit signal.
ProviderContainer _container(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(MaterialApp)));

void typeSearch(WidgetTester t, String text) =>
    _container(t).read(searchControllerProvider).text = text;

void submitSearch(WidgetTester t) =>
    _container(t).read(searchSubmitProvider.notifier).submit();

/// The search index is built on another isolate, which the test clock does
/// not wait for: pump and give the real loop a turn until it is there. A
/// failed build fails the test.
Future<void> indexReady(WidgetTester t) async {
  final c = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
  Future<void> turn() async {
    await t.pump(const Duration(milliseconds: 50));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
  }

  await turn(); // a write reaches the index through drift's notice
  if (!c.exists(searchIndexProvider)) return; // nothing asked for it (yet)
  Object? failure;
  var done = false;
  c.read(searchIndexProvider.future).then(
    (_) => done = true,
    onError: (Object e) {
      failure = e;
      done = true;
    },
  );
  for (var i = 0; i < 100 && !done; i++) {
    await turn();
  }
  if (failure != null) throw failure!;
  expect(done, isTrue, reason: 'search index not built');
}
