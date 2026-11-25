import 'dart:io' show FileSystemEntity;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../../core/app_log.dart';
import '../../l10n/l10n_ext.dart';
import '../../services/platform/open_files.dart';
import '../widgets/show_msg.dart';

/// Desktop drag-and-drop of files onto the app (F-208): a veil while dragging, then the audio
/// goes the same way as «Apri con» ([onAudio] is `OpenFiles.handle`). Folders, other files and
/// items without a path are ignored with a message.
class DropOverlay extends StatefulWidget {
  const DropOverlay({super.key, required this.onAudio, required this.child});

  final Future<void> Function(List<String> paths) onAudio;
  final Widget child;

  @override
  State<DropOverlay> createState() => _DropOverlayState();
}

class _DropOverlayState extends State<DropOverlay> {
  bool _dragging = false;

  Future<void> _done(DropDoneDetails d) async {
    setState(() => _dragging = false);
    final audio = <String>[];
    var rejected = false;
    for (final f in d.files) {
      final path = f.path;
      if (path.isEmpty) {
        AppLog.w('drop: item without a local path (${f.name})');
        rejected = true;
      } else if (await FileSystemEntity.isDirectory(path)) {
        AppLog.i('drop: folder $path ignored');
        rejected = true;
      } else if (OpenFiles.audioPaths([path]).isEmpty) {
        AppLog.i('drop: $path is not audio');
        rejected = true;
      } else {
        audio.add(path);
      }
    }
    if (!mounted) return;
    if (rejected) showMsg(context, context.l10n.dropRejected);
    if (audio.isNotEmpty) await widget.onAudio(audio);
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: _done,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          if (_dragging)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Colors.black54,
                  child: Center(
                    child: Text(
                      context.l10n.dropHint,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
