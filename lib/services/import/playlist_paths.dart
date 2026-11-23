// Helpers shared by the M3U and XSPF readers and by the library lookup.

final _windowsDrive = RegExp(r'^[A-Za-z]:[\\/]');

/// A `file://` URL or a plain path as a path with `/` separators; null for
/// anything that is not a local file (`http(s)://`, `smb://`...).
String? localPathFromLocation(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  if (RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(s) &&
      !_windowsDrive.hasMatch(s)) {
    if (!s.toLowerCase().startsWith('file://')) return null;
    s = s.substring(7);
    // file:///C:/Music/x.mp3 -> C:/Music/x.mp3
    if (RegExp(r'^/[A-Za-z]:/').hasMatch(s)) s = s.substring(1);
    s = _safeDecode(s);
  }
  return s.replaceAll(r'\', '/');
}

/// The library path of the streamed row a YouTube Music page address (`watch?v=<id>`) stands for
/// (`stream:youtube:<id>`, the shadow row's path), or null for any other text.
String? streamPathOfWatchUrl(String raw) {
  final u = Uri.tryParse(raw.trim());
  final host = u?.host.toLowerCase() ?? '';
  final id = u?.queryParameters['v'];
  if (u == null || id == null || id.isEmpty || u.path != '/watch') return null;
  return host == 'youtube.com' || host.endsWith('.youtube.com') ? 'stream:youtube:$id' : null;
}

String _safeDecode(String s) {
  try {
    return Uri.decodeFull(s);
  } on ArgumentError {
    return s;
  }
}

bool isAbsoluteLocalPath(String p) => p.startsWith('/') || _windowsDrive.hasMatch(p);

/// Lower-case comparison key: Windows and macOS paths ignore case and a
/// playlist may have been written on another system.
String pathKey(String p) => p.replaceAll(r'\', '/').toLowerCase();

String basenameOf(String p) {
  final s = p.replaceAll(r'\', '/');
  return s.substring(s.lastIndexOf('/') + 1);
}

/// `Artist - Title`; without the separator everything is the title.
({String? artist, String title}) splitLabel(String label) {
  final i = label.indexOf(' - ');
  if (i <= 0) return (artist: null, title: label.trim());
  return (
    artist: label.substring(0, i).trim(),
    title: label.substring(i + 3).trim(),
  );
}

String withoutExtension(String name) {
  final dot = name.lastIndexOf('.');
  return dot <= 0 ? name : name.substring(0, dot);
}
