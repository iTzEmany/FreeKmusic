import 'dart:ui' show Rect;

import 'package:share_plus/share_plus.dart';

/// Thin wrapper over the system share sheet (D-670); fakeable in tests.
abstract class ExternalShare {
  /// [origin] anchors the sheet on iPad/desktop.
  Future<void> shareText(String text, {String? subject, Rect? origin});

  Future<void> shareFile(String path, {String? text, Rect? origin});
}

class SharePlusExternalShare implements ExternalShare {
  const SharePlusExternalShare();

  @override
  Future<void> shareText(String text, {String? subject, Rect? origin}) =>
      SharePlus.instance.share(
        ShareParams(text: text, subject: subject, sharePositionOrigin: origin),
      );

  @override
  Future<void> shareFile(String path, {String? text, Rect? origin}) =>
      SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          text: text,
          sharePositionOrigin: origin,
        ),
      );
}
