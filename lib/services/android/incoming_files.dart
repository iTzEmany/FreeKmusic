import 'dart:async';

import 'package:flutter/services.dart';

import '../../core/app_log.dart';

/// Files other apps hand to Codecore (channel `codecore/incoming`): Kotlin
/// copies them to the cache and keeps the path until Dart takes it.
class IncomingFiles {
  IncomingFiles({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('codecore/incoming');

  final MethodChannel _channel;
  final _pushed = StreamController<void>.broadcast();
  final _pushedText = StreamController<void>.broadcast();
  bool _listening = false;

  Future<String?> takeIncoming() async {
    try {
      return await _channel.invokeMethod<String>('takeIncoming');
    } on PlatformException catch (e, st) {
      AppLog.w('incoming file not readable', e, st);
      return null;
    }
  }

  /// Every text shared since the last call, oldest first.
  Future<List<String>> takeIncomingTexts() async {
    try {
      return await _channel.invokeListMethod<String>('takeIncomingText') ?? [];
    } on PlatformException catch (e, st) {
      AppLog.w('incoming text not readable', e, st);
      return [];
    }
  }

  void _listen() {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'incoming') _pushed.add(null);
      if (call.method == 'incomingText') _pushedText.add(null);
    });
  }

  /// The text that started the app, then every later one while it lives.
  Stream<String> texts() async* {
    _listen();
    yield* Stream.fromIterable(await takeIncomingTexts());
    await for (final _ in _pushedText.stream) {
      yield* Stream.fromIterable(await takeIncomingTexts());
    }
  }

  /// The file that started the app, then every later one while it lives.
  Stream<String> paths() async* {
    _listen();
    final first = await takeIncoming();
    if (first != null) yield first;
    await for (final _ in _pushed.stream) {
      final p = await takeIncoming();
      if (p != null) yield p;
    }
  }
}
