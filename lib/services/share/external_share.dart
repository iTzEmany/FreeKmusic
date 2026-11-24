import 'dart:io' show Platform;
import 'dart:ui' show Rect;

import 'package:share_plus/share_plus.dart';

/// Thin wrapper over the system share sheet (D-670); fakeable in tests.
abstract class ExternalShare {
  /// [origin] anchors the sheet on iPad/desktop.
  Future<void> shareText(String text, {String? subject, Rect? origin});

  Future<void> shareFile(String path, {String? text, Rect? origin});
}

class SharePlusExternalShare implements ExternalShare {
  const SharePlusExternalShare() : _run = null, _linux = null;

  /// Test seam: replaces the native call.
  const SharePlusExternalShare.withRunner(Future<Object?> Function(ShareParams) run, {bool? linux}) : _run = run, _linux = linux ?? false;

  final Future<Object?> Function(ShareParams)? _run;
  final bool? _linux; // null: ask the platform

  // Linux: share_plus opens a mailto and answers "unavailable"; throwing makes the caller copy the text.
  // The ShareResult is not read elsewhere: Android and Windows say "unavailable" even when the share happened.
  Future<void> _share(ShareParams p) async {
    if (_linux ?? Platform.isLinux) throw UnsupportedError('no share sheet on Linux');
    await (_run ?? SharePlus.instance.share)(p);
  }

  @override
  Future<void> shareText(String text, {String? subject, Rect? origin}) =>
      _share(ShareParams(text: text, subject: subject, sharePositionOrigin: origin));

  @override
  Future<void> shareFile(String path, {String? text, Rect? origin}) => _share(
    ShareParams(
      files: [XFile(path, mimeType: 'audio/x-mpegurl')],
      text: text,
      sharePositionOrigin: origin,
    ),
  );
}
