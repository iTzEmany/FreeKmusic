import 'dart:convert';
import 'dart:typed_data' show BytesBuilder, ByteData, Endian, Uint8List;
import 'dart:io';

/// Max tracks in one shared link or text (D-702); above it we fall back to m3u8.
const int kMaxSharedTracks = 50;

const int _maxTitle = 120;
const int _maxDecompressed = 64 * 1024;
const _idLen = 11;

/// The page that opens a shared link (D-702); the fragment after `#` carries the tracks.
const kSharePageUrl = 'https://itzemany.github.io/FreeKmusic/';
final _idChars = RegExp(r'^[A-Za-z0-9_-]+$');

/// A YouTube video id: 11 url-safe characters.
bool isVideoId(String s) => s.length == _idLen && _idChars.hasMatch(s);
final _b64Body = RegExp(r'^([A-Za-z0-9_-]+)(={0,2})$');

/// Title of a collection without a name.
const untitledShare = 'Senza titolo';

enum SharedKind {
  track('t'),
  album('a'),
  playlist('p');

  const SharedKind(this.code);
  final String code;
}

class SharedFragment {
  const SharedFragment(this.kind, this.title, this.ids);
  final SharedKind kind;
  final String title;
  final List<String> ids;
}

class ShareFragmentError implements Exception {
  const ShareFragmentError(this.message);
  final String message;
  @override
  String toString() => 'ShareFragmentError: $message';
}

/// `FK1\n<kind>\n<title>\n<ids>` -> gzip -> base64url without padding.
/// The title is non-blank and at most 120 chars; a blank one becomes "Senza titolo".
String encodeShareFragment(SharedFragment f) {
  _validate(f.ids);
  final title = f.title.replaceAll(RegExp(r'[\r\n]'), ' ').trim();
  final clipped = title.isEmpty
      ? untitledShare
      : String.fromCharCodes(title.runes.take(_maxTitle));
  final payload = 'FK1\n${f.kind.code}\n$clipped\n${f.ids.join()}';
  return base64Url
      .encode(gzip.encode(utf8.encode(payload)))
      .replaceAll('=', '');
}

SharedFragment decodeShareFragment(String fragment) {
  try {
    return _decode(fragment);
  } on ShareFragmentError {
    rethrow;
  } on Object catch (e) {
    // base64, gzip and utf8 failures all surface as one typed error.
    throw ShareFragmentError('illegible fragment: $e');
  }
}

SharedFragment _decode(String fragment) {
  final m = _b64Body.firstMatch(
    fragment.startsWith('#') ? fragment.substring(1) : fragment,
  );
  if (m == null) throw const ShareFragmentError('bad base64url');
  final body = m[1]!;
  final pad = m[2]!.length;
  // Padding is optional, but when present it must be the canonical amount.
  if (body.length % 4 == 1 || (pad != 0 && pad != (4 - body.length % 4) % 4)) {
    throw const ShareFragmentError('bad base64url padding');
  }
  final bytes = base64Url.decode(base64Url.normalize(body));
  final out = BytesBuilder(copy: false);
  final dec = gzip.decoder.startChunkedConversion(_LimitSink(out));
  dec.add(bytes);
  dec.close();
  final raw = out.takeBytes();
  _checkGzipTrailer(bytes, raw);
  final lines = utf8.decode(raw).split('\n');
  if (lines.length != 4 || lines[0] != 'FK1') {
    throw const ShareFragmentError('bad prefix or layout');
  }
  final kind = SharedKind.values.firstWhere(
    (k) => k.code == lines[1],
    orElse: () => throw const ShareFragmentError('unknown kind'),
  );
  final title = lines[2];
  if (title.trim().isEmpty || title.runes.length > _maxTitle) {
    throw const ShareFragmentError('bad title');
  }
  final s = lines[3];
  if (s.isNotEmpty && !_idChars.hasMatch(s)) {
    throw const ShareFragmentError('invalid id characters');
  }
  if (s.length % _idLen != 0) throw const ShareFragmentError('bad ids length');
  final ids = [
    for (var i = 0; i < s.length; i += _idLen) s.substring(i, i + _idLen),
  ];
  _validate(ids);
  return SharedFragment(kind, title, ids);
}

/// dart:io does not check the gzip trailer: a truncated stream, trailing bytes or
/// a zlib stream would pass. Require the last 8 bytes to be CRC32 + ISIZE of [raw].
void _checkGzipTrailer(Uint8List gz, Uint8List raw) {
  if (gz.length < 18 || gz[0] != 0x1f || gz[1] != 0x8b || gz[2] != 8) {
    throw const ShareFragmentError('not gzip');
  }
  final t = ByteData.sublistView(gz, gz.length - 8);
  if (t.getUint32(0, Endian.little) != _crc32(raw) ||
      t.getUint32(4, Endian.little) != raw.length) {
    throw const ShareFragmentError('bad gzip trailer');
  }
}

int _crc32(Uint8List data) {
  var c = 0xFFFFFFFF;
  for (final b in data) {
    c ^= b;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? (c >> 1) ^ 0xEDB88320 : c >> 1;
    }
  }
  return c ^ 0xFFFFFFFF;
}

void _validate(List<String> ids) {
  if (ids.isEmpty) throw const ShareFragmentError('no ids');
  if (ids.length > kMaxSharedTracks) {
    throw const ShareFragmentError('too many tracks');
  }
  for (final id in ids) {
    if (id.length != _idLen || !_idChars.hasMatch(id)) {
      throw ShareFragmentError('invalid id: $id');
    }
  }
}

class _LimitSink extends ByteConversionSinkBase {
  _LimitSink(this._out);
  final BytesBuilder _out;

  @override
  void add(List<int> chunk) {
    _out.add(chunk);
    if (_out.length > _maxDecompressed) {
      throw const ShareFragmentError('payload too large');
    }
  }

  @override
  void close() {}
}
