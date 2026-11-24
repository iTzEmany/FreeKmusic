import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;

import '../../core/text_utils.dart' show sanitizeFileName;
import '../../data/db/app_database.dart' show Track;
import '../../ui/widgets/share_card.dart';
import 'share_fragment.dart' show SharedKind;

/// Makes the share card PNG of a track, album or playlist; throws when it cannot (the caller shares text then).
typedef ShareCardMaker = Future<Uint8List> Function(SharedKind kind, String title, String? subtitle, List<Track> tracks);

/// Longest wait for covers and drawing: a card that is late is not worth waiting for.
const kShareCardTimeout = Duration(seconds: 4);

/// Decodes [covers] first (no card with holes), then draws the card built by [card] off screen
/// at 1080 x 1350 and encodes it as PNG. Decoding and encoding run in the engine's own threads.
Future<Uint8List> renderShareCardPng(
  List<File> covers,
  ShareCard Function(List<ui.Image> images) card, {
  Duration timeout = kShareCardTimeout,
}) => _render(covers, card).timeout(timeout);

Future<Uint8List> _render(List<File> covers, ShareCard Function(List<ui.Image>) card) async {
  final images = <ui.Image>[];
  ui.Image? out;
  // What the finally below takes down (nothing may stay hooked to the engine or the focus system).
  PipelineOwner? pipeline;
  RenderView? view;
  BuildOwner? build;
  FocusManager? focus;
  RenderObjectToWidgetElement<RenderBox>? root;
  RenderRepaintBoundary? boundary;
  try {
    for (final f in covers) {
      final codec = await ui.instantiateImageCodec(await f.readAsBytes(), targetWidth: covers.length >= 4 ? 360 : 720);
      images.add((await codec.getNextFrame()).image);
      codec.dispose();
    }
    final repaint = RenderRepaintBoundary();
    boundary = repaint;
    final v = RenderView(
      view: ui.PlatformDispatcher.instance.views.first,
      configuration: ViewConfiguration(logicalConstraints: BoxConstraints.tight(kShareCardSize)),
      child: RenderPositionedBox(child: repaint),
    );
    view = v;
    final pipe = PipelineOwner()..rootNode = v;
    pipeline = pipe;
    v.prepareInitialFrame();
    focus = FocusManager();
    final owner = BuildOwner(focusManager: focus);
    build = owner;
    final r = RenderObjectToWidgetAdapter<RenderBox>(
      container: repaint,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: DefaultTextStyle(style: const TextStyle(decoration: TextDecoration.none), child: card(images)),
      ),
    ).attachToRenderTree(owner);
    root = r;
    owner.buildScope(r);
    owner.finalizeTree();
    pipe
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();
    out = await repaint.toImage();
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('share card: no PNG data');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    final b = build;
    final r = root;
    if (b != null && r != null && boundary != null) {
      // An adapter without a child unmounts the cloned covers and the widgets.
      RenderObjectToWidgetAdapter<RenderBox>(container: boundary).attachToRenderTree(b, r);
      b.buildScope(r);
      b.finalizeTree();
    }
    pipeline?.rootNode = null;
    view?.dispose();
    focus?.dispose();
    out?.dispose();
    for (final i in images) {
      i.dispose();
    }
  }
}

/// Writes [png] as `<name>.png` in [dir], which is ours alone: what an earlier share left there is deleted first.
Future<File> writeSharePng(Directory dir, String name, Uint8List png) async {
  if (await dir.exists()) await dir.delete(recursive: true);
  await dir.create(recursive: true);
  return File(p.join(dir.path, '${sanitizeFileName(name)}.png')).writeAsBytes(png);
}
