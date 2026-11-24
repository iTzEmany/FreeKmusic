import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:codecore/services/share/external_share.dart';

/// [ExternalShare] that records what it is asked to share; [error] makes it fail, [gate] holds it until completed.
class FakeShare implements ExternalShare {
  final texts = <String>[];
  final files = <String>[];
  final fileTexts = <String?>[];
  final origins = <Rect?>[];
  String? fileBody;
  Object? error;
  Completer<void>? gate;

  @override
  Future<void> shareText(String text, {String? subject, Rect? origin}) async {
    texts.add(text);
    origins.add(origin);
    await gate?.future;
    if (error != null) throw error!;
  }

  @override
  Future<void> shareFile(String path, {String? text, Rect? origin}) async {
    files.add(path);
    fileTexts.add(text);
    fileBody = utf8.decode(File(path).readAsBytesSync(), allowMalformed: true); // a PNG is not text
    origins.add(origin);
    await gate?.future;
    if (error != null) throw error!;
  }
}
