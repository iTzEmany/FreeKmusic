import 'dart:async';

import 'package:flutter/services.dart';

import '../../core/app_log.dart';

const appName = 'FreeKmusic';
// The window title is not app UI: the separator is written escaped on purpose (guards on « · » in strings).
const _sep = ' \u00B7 ';

/// The desktop window title follows the song: «Artista — Titolo · FreeKmusic»
/// while it plays, plain «FreeKmusic» when paused or without a song.
class WindowTitle {
  WindowTitle({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('freekmusic/window');

  final MethodChannel _channel;
  String? _last;

  /// [song] is the playing song's label, null for none/paused.
  Future<void> update(String? song) async {
    final title = song == null ? appName : '$song$_sep$appName';
    if (title == _last) return;
    _last = title;
    try {
      await _channel.invokeMethod<void>('setTitle', title);
    } on PlatformException catch (e, st) {
      AppLog.w('window title not set', e, st);
    } on MissingPluginException catch (e, st) {
      AppLog.w('window title: no channel in this runner', e, st);
    }
  }
}

/// «Artist — Title» of a song, or just the title.
String songLabel(String? artist, String title) =>
    (artist ?? '').trim().isEmpty ? title : '${artist!.trim()} — $title';
