import 'dart:async';

import 'package:flutter/services.dart';

import 'app_log.dart';

/// Android media volume (`codecore/volume`): 0..1, 0 = the stream's minimum.
/// Elsewhere (no plugin) it stays silent.
class SystemVolume {
  SystemVolume([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel('codecore/volume');

  final MethodChannel _channel;
  final _changes = StreamController<double>.broadcast();
  bool _handler = false;

  Stream<double> get changes {
    if (!_handler) {
      _handler = true;
      _channel.setMethodCallHandler((call) async {
        final v = call.arguments;
        if (call.method == 'changed' && v is num) _changes.add(v.toDouble());
      });
    }
    return _changes.stream;
  }

  Future<double?> current() => _call<double>('get');

  Future<void> start() async {
    changes; // make sure the handler is installed
    await _call<void>('start');
  }

  Future<void> stop() => _call<void>('stop');

  Future<T?> _call<T>(String method) async {
    try {
      return await _channel.invokeMethod<T>(method);
    } on MissingPluginException {
      AppLog.d('system volume $method: no plugin');
      return null;
    } on PlatformException catch (e, st) {
      AppLog.w('system volume $method failed', e, st);
      return null;
    }
  }
}
