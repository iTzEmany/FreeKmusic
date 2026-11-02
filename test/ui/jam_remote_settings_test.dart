import 'dart:async';
import 'dart:typed_data';

import 'package:codecore/providers/jam_broker_providers.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/services/jam/remote/broker_entry.dart';
import 'package:codecore/services/jam/remote/mqtt_link.dart';
import 'package:codecore/ui/screens/settings/jam_remote_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/app_harness.dart';

/// Echoes every publish back; [fail] makes connect throw.
class FakeMqttLink implements MqttLink {
  FakeMqttLink({this.fail = false, this.echo = true});
  final bool fail;
  final bool echo;
  final subscribed = <String>{};
  final _ctl = StreamController<MqttIncoming>.broadcast();
  bool disconnected = false;

  @override
  Future<void> connect(BrokerEntry broker) async {
    if (fail) throw StateError('bad certificate');
  }

  @override
  void subscribe(String topic) => subscribed.add(topic);
  @override
  void unsubscribe(String topic) {}
  @override
  void publish(String topic, Uint8List bytes, {bool retain = false}) =>
      echo && subscribed.contains(topic)
          ? scheduleMicrotask(() => _ctl.add((topic: topic, payload: bytes)))
          : null;
  @override
  Stream<MqttIncoming> get messages => _ctl.stream;
  @override
  Stream<void> get onDisconnected => const Stream.empty();
  @override
  bool get connected => true;
  @override
  void disconnect() => disconnected = true;
}

const _mosquitto = BrokerEntry(host: 'test.mosquitto.org', port: 8886);

void main() {
  Future<Harness> open(WidgetTester t, {bool failLink = false, FakeMqttLink? link}) async {
    t.view.physicalSize = const Size(500, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final h = await Harness.create(t);
    await h.pump(t, const JamRemoteSettings(), extraOverrides: [
      mqttLinkFactoryProvider.overrideWithValue(() => link ?? FakeMqttLink(fail: failLink)),
    ]);
    ProviderScope.containerOf(t.element(find.byType(JamRemoteSettings))).read(jamBrokersProvider.notifier).add(_mosquitto); // a second broker to move and remove
    await t.pumpAndSettle();
    return h;
  }

  ProviderContainer box(WidgetTester t) => ProviderScope.containerOf(t.element(find.byType(JamRemoteSettings)));

  testWidgets('shows the defaults, adds a broker and an invalid one is refused', (t) async {
    final h = await open(t);
    expect(find.text('broker.emqx.io:8883'), findsOneWidget);
    expect(find.text('test.mosquitto.org:8886'), findsOneWidget);
    await t.tap(find.text('Aggiungi broker'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'Indirizzo'), 'a b');
    await t.tap(find.text('Salva'));
    await t.pumpAndSettle();
    expect(find.text('Indirizzo o porta non validi'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'Indirizzo'), 'mio.broker.net');
    await t.tap(find.text('Salva'));
    await t.pumpAndSettle();
    expect(find.text('mio.broker.net:8883'), findsOneWidget);
    expect(box(t).read(jamBrokersProvider).length, 3);
    await h.dispose(t);
  });

  testWidgets('a broker without TLS is warned about, in the sheet and next to the entry', (t) async {
    final h = await open(t);
    await t.tap(find.text('Aggiungi broker'));
    await t.pumpAndSettle();
    expect(find.textContaining('Senza TLS'), findsNothing);
    await t.tap(find.byType(Switch));
    await t.pumpAndSettle();
    expect(find.textContaining('Senza TLS'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'Indirizzo'), 'plain.net');
    await t.tap(find.text('Salva'));
    await t.pumpAndSettle();
    expect(find.textContaining('Senza TLS'), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('moves a broker up, removes one and restores the defaults', (t) async {
    final h = await open(t);
    final c = box(t);
    await t.tap(find.byTooltip('Sposta su'));
    await t.pumpAndSettle();
    expect(c.read(jamBrokersProvider).first.host, 'test.mosquitto.org');
    await t.tap(find.byTooltip('Togli').first);
    await t.pumpAndSettle();
    expect(c.read(jamBrokersProvider).map((b) => b.host), ['broker.emqx.io']);
    await t.tap(find.text('Ripristina'));
    await t.pumpAndSettle();
    expect(c.read(jamBrokersProvider), kDefaultJamBrokers);
    await h.dispose(t);
  });

  testWidgets('Prova connessione: success and failure', (t) async {
    final link = FakeMqttLink();
    var h = await open(t, link: link);
    await t.tap(find.byTooltip('Prova connessione').first);
    await t.pumpAndSettle();
    expect(find.textContaining('connessione riuscita'), findsOneWidget);
    expect(link.disconnected, isTrue);
    await h.dispose(t);

    h = await open(t, failLink: true);
    await t.tap(find.byTooltip('Prova connessione').first);
    await t.pumpAndSettle();
    expect(find.textContaining('non riesco a collegarmi'), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('every change is written to jamBrokers and the last broker has no Togli', (t) async {
    final h = await open(t);
    final c = box(t);
    await t.tap(find.byTooltip('Togli').first);
    await t.pumpAndSettle();
    expect(decodeBrokers(c.read(settingsStoreProvider).readJamBrokersRaw()).map((b) => b.host), ['test.mosquitto.org']);
    expect(find.byTooltip('Togli'), findsNothing);
    c.read(jamBrokersProvider.notifier).remove(c.read(jamBrokersProvider).single);
    expect(c.read(jamBrokersProvider).length, 1);
    await h.dispose(t);
  });

  test('Prova without an echo fails after the timeout and still disconnects', () async {
    final link = FakeMqttLink(echo: false);
    expect(await testBroker(link, kDefaultJamBrokers[0], timeout: const Duration(milliseconds: 50)), isFalse);
    expect(link.disconnected, isTrue);
  });

  test('Prova fails when the message comes back on another topic or with another payload', () async {
    for (final mangle in [true, false]) {
      final link = _WrongEchoLink(mangleTopic: mangle);
      expect(await testBroker(link, kDefaultJamBrokers[0], timeout: const Duration(milliseconds: 50)), isFalse);
    }
  });

  test('add of a duplicate or an invalid broker returns false; port 1 is valid, port 0 is not', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await SettingsStore.open();
    final c = ProviderContainer(overrides: [settingsStoreProvider.overrideWithValue(store)]);
    addTearDown(c.dispose);
    final n = c.read(jamBrokersProvider.notifier);
    expect(n.add(kDefaultJamBrokers[0]), isFalse);
    expect(n.add(const BrokerEntry(host: 'p.net', port: 0)), isFalse);
    expect(n.add(const BrokerEntry(host: 'p.net', port: 1)), isTrue);
    expect(n.add(const BrokerEntry(host: 'P.NET', port: 1)), isFalse);
  });

  test('move down by one swaps the neighbours; restore removes the saved key', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await SettingsStore.open();
    final c = ProviderContainer(overrides: [settingsStoreProvider.overrideWithValue(store)]);
    addTearDown(c.dispose);
    final n = c.read(jamBrokersProvider.notifier);
    n.add(_mosquitto);
    n.add(const BrokerEntry(host: 'c.net', port: 1));
    n.move(0, 2); // the UI passes index + 1 for "down by one"
    expect(c.read(jamBrokersProvider).map((b) => b.host), ['test.mosquitto.org', 'broker.emqx.io', 'c.net']);
    await Future<void>.delayed(Duration.zero);
    expect(store.readJamBrokersRaw(), isNotNull);
    n.restore();
    await Future<void>.delayed(Duration.zero);
    expect(store.readJamBrokersRaw(), isNull);
  });

  test('Prova with a refused connection still disconnects', () async {
    final link = FakeMqttLink(fail: true);
    expect(await testBroker(link, kDefaultJamBrokers[0]), isFalse);
    expect(link.disconnected, isTrue);
  });
}

/// Subscribes fine but echoes on another topic, or the same topic with another payload.
class _WrongEchoLink extends FakeMqttLink {
  _WrongEchoLink({required this.mangleTopic});
  final bool mangleTopic;
  final _out = StreamController<MqttIncoming>.broadcast();
  @override
  Stream<MqttIncoming> get messages => _out.stream;
  @override
  void publish(String topic, Uint8List bytes, {bool retain = false}) => scheduleMicrotask(() => _out.add((
        topic: mangleTopic ? '$topic/x' : topic,
        payload: mangleTopic ? bytes : Uint8List.fromList([for (final b in bytes) b ^ 1]),
      )));
}
