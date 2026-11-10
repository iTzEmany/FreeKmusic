import 'package:path/path.dart' as p;

import '../../../data/repositories/memory_queries.dart';

/// Display names for the folder rows, keyed by folder path. Folders whose
/// names are unique keep them; when names collide each one gets the shortest
/// trailing part of its path that tells them apart, skipping technical
/// segments (`0`, `files`...): `Music` vs `com.freekmusic.player/Music`.
Map<String, String> folderLabels(List<SizeGroup> folders) {
  final paths = [
    for (final g in folders)
      if (g.path != null) g.path!,
  ];
  final names = {
    for (final g in folders)
      if (g.path != null) g.path!: g.name,
  };
  final byName = <String, List<String>>{};
  for (final path in paths) {
    byName.putIfAbsent(names[path]!, () => []).add(path);
  }
  final out = <String, String>{...names};
  for (final group in byName.values) {
    if (group.length < 2) continue;
    final parts = {for (final path in group) path: _readable(p.split(path))};
    for (final path in group) {
      final mine = parts[path]!;
      var n = 1;
      while (n < mine.length &&
          group.any(
            (o) => o != path && _tail(parts[o]!, n) == _tail(mine, n),
          )) {
        n++;
      }
      out[path] = _tail(mine, n);
    }
  }
  return out;
}

String _tail(List<String> parts, int n) =>
    parts.sublist(parts.length > n ? parts.length - n : 0).join('/');

const _technical = {'/', 'storage', 'emulated', 'android', 'data', 'files'};

/// Drops segments that say nothing to a person (never the last one).
List<String> _readable(List<String> parts) => [
  for (var i = 0; i < parts.length; i++)
    if (i == parts.length - 1 ||
        !(_technical.contains(parts[i].toLowerCase()) ||
            int.tryParse(parts[i]) != null))
      parts[i],
];
