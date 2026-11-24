import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/app_log.dart';
import '../data/db/app_database.dart' show Track;
import '../services/share/external_share.dart';
import '../services/share/external_share_text.dart';
import '../services/share/share_card_renderer.dart';
import '../services/share/share_fragment.dart';
import '../services/share/share_m3u8.dart';
import 'external_share_provider.dart';
import 'share_card_maker.dart';

/// «Condividi» (D-677): the system share sheet with readable text and links, or an m3u8 above the limit (D-702).
class ExternalShareActions {
  ExternalShareActions(this._share, this._tempDir, {bool? canShareFiles, this.cardMaker})
    : _canShareFiles = canShareFiles ?? !Platform.isLinux;

  /// Draws the share card (D-713); null, or a failure, shares the text instead.
  final ShareCardMaker? cardMaker;

  final ExternalShare _share;
  final Future<Directory> Function() _tempDir;

  /// Linux has no sheet (D-702): the text goes to the clipboard. Windows takes files from 10 RS5;
  /// on older ones share_plus throws and the catch below copies.
  final bool _canShareFiles;
  bool _busy = false;

  /// [origin] anchors the sheet on iPad and desktop. True when the text was copied to the clipboard
  /// instead of shared (the caller says so); false when shared, or when another share is in progress.
  Future<bool> share(SharedKind kind, String title, List<Track> tracks, {String? subtitle, Rect? origin}) async {
    if (_busy) return false;
    _busy = true;
    String? text;
    try {
      if (exceedsShareLimit(tracks, kind: kind, title: title)) {
        text = shareM3u8Body(title, tracks);
        if (!_canShareFiles) return await _copy(text);
        // A folder of our own: only it is emptied before a new file is written.
        final dir = await _shareDir();
        final file = await writeShareM3u8(dir, title, tracks);
        await _share.shareFile(file.path, text: title, origin: origin);
      } else {
        text = buildShareText(kind, title, tracks, subtitle: subtitle);
        final png = _canShareFiles ? await _card(kind, title, subtitle, tracks) : null;
        if (png != null) {
          await _share.shareFile(png.path, text: buildShareCaption(kind, title, tracks), origin: origin);
        } else {
          await _share.shareText(text, subject: title, origin: origin);
        }
      }
      return false;
    } on Object catch (e, st) {
      AppLog.w('external share failed', e, st);
      return text != null && await _copy(text);
    } finally {
      _busy = false;
    }
  }

  /// The card as a file in our own folder, or null (logged) when it cannot be drawn in time.
  Future<File?> _card(SharedKind kind, String title, String? subtitle, List<Track> tracks) async {
    try {
      final png = await cardMaker?.call(kind, title, subtitle, tracks);
      return png == null ? null : await writeSharePng(await _shareDir(), title, png);
    } on Object catch (e, st) {
      AppLog.w('share card failed, sharing text', e, st);
      return null;
    }
  }

  Future<Directory> _shareDir() async => Directory(p.join((await _tempDir()).path, 'freekmusic_share'));

  Future<bool> _copy(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return true;
    } on Object catch (e, st) {
      AppLog.w('share: text not copied', e, st);
      return false;
    }
  }
}

final externalShareActionsProvider = Provider<ExternalShareActions>(
  (ref) => ExternalShareActions(ref.watch(externalShareProvider), getTemporaryDirectory, cardMaker: shareCardMaker(ref)),
);
