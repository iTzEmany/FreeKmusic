import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/app_log.dart';
import '../data/db/app_database.dart' show Track;
import '../services/share/external_share.dart';
import '../services/share/external_share_text.dart';
import '../services/share/share_fragment.dart';
import '../services/share/share_m3u8.dart';
import 'external_share_provider.dart';

/// «Condividi» (D-677): the system share sheet with readable text and links, or an m3u8 above the limit (D-702).
class ExternalShareActions {
  ExternalShareActions(this._share, this._tempDir);

  final ExternalShare _share;
  final Future<Directory> Function() _tempDir;

  /// [origin] anchors the sheet on iPad and desktop.
  Future<void> share(SharedKind kind, String title, List<Track> tracks, {String? subtitle, Rect? origin}) async {
    try {
      if (exceedsShareLimit(tracks)) {
        final file = await writeShareM3u8(Directory(p.join((await _tempDir()).path, 'share')), title, tracks);
        await _share.shareFile(file.path, text: title, origin: origin);
      } else {
        await _share.shareText(buildShareText(kind, title, tracks, subtitle: subtitle), subject: title, origin: origin);
      }
    } on Object catch (e, st) {
      AppLog.w('external share failed', e, st);
    }
  }
}

final externalShareActionsProvider = Provider<ExternalShareActions>(
  (ref) => ExternalShareActions(ref.watch(externalShareProvider), getTemporaryDirectory),
);
