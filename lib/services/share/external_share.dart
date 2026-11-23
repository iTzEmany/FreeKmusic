import 'dart:ui' show Rect;

import 'package:share_plus/share_plus.dart';

/// Thin wrapper over the system share sheet (D-670); fakeable in tests.
abstract class ExternalShare {
  /// [origin] anchors the sheet on iPad/desktop.
  Future<void> shareText(String text, {String? subject, Rect? origin});

  Future<void> shareFile(String path, {String? text, Rect? origin});
}

/// The platform has no usable share sheet (e.g. Linux file sharing, old Windows);
/// the UI falls back to "Copy text".
class ExternalShareUnavailable implements Exception {
  const ExternalShareUnavailable(this.reason);
  final String reason;
  @override
  String toString() => 'ExternalShareUnavailable: $reason';
}

class SharePlusExternalShare implements ExternalShare {
  const SharePlusExternalShare() : _run = null;

  /// Test seam: replaces the native call.
  const SharePlusExternalShare.withRunner(
    Future<Object?> Function(ShareParams) run,
  ) : _run = run;

  final Future<Object?> Function(ShareParams)? _run;

  Future<void> _share(ShareParams p) async {
    try {
      await (_run ?? SharePlus.instance.share)(p);
    } on Object catch (e) {
      throw ExternalShareUnavailable('$e');
    }
  }

  @override
  Future<void> shareText(String text, {String? subject, Rect? origin}) =>
      _share(
        ShareParams(text: text, subject: subject, sharePositionOrigin: origin),
      );

  @override
  Future<void> shareFile(String path, {String? text, Rect? origin}) => _share(
    ShareParams(files: [XFile(path)], text: text, sharePositionOrigin: origin),
  );
}
