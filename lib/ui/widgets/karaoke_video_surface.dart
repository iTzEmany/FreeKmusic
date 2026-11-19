import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Builds the real video surface; tests replace it (no libmpv there).
final karaokeVideoBuilderProvider = Provider<Widget Function(VideoController)>(
  (_) =>
      (c) => Video(controller: c, controls: NoVideoControls),
);
