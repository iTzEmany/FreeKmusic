import 'dart:convert';
import 'dart:typed_data' show BytesBuilder;
import 'dart:io';

/// Max tracks in one shared link or text (D-702); above it we fall back to m3u8.
const int kMaxSharedTracks = 50;

const int _maxTitle = 120;
const int _maxDecompressed = 64 * 1024;
const _idLen = 11;
final _idChars = RegExp(r'^[A-Za-z0-9_-]+$');

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
String encodeShareFragment(SharedFragment f) {
  _validate(f.ids);
  final title = f.title.replaceAll(RegExp(r'[\r\n]'), ' ');
  final clipped = String.fromCharCodes(title.runes.take(_maxTitle));
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
  final bytes = base64Url.decode(base64Url.normalize(fragment.trim()));
  final out = BytesBuilder(copy: false);
  final dec = gzip.decoder.startChunkedConversion(_LimitSink(out));
  dec.add(bytes);
  dec.close();
  final lines = utf8.decode(out.takeBytes()).split('\n');
  if (lines.length != 4 || lines[0] != 'FK1') {
    throw const ShareFragmentError('bad prefix or layout');
  }
  final kind = SharedKind.values.where((k) => k.code == lines[1]);
  if (kind.isEmpty) throw const ShareFragmentError('unknown kind');
  final s = lines[3];
  if (s.isNotEmpty && !_idChars.hasMatch(s)) {
    throw const ShareFragmentError('invalid id characters');
  }
  if (s.length % _idLen != 0) throw const ShareFragmentError('bad ids length');
  final ids = [
    for (var i = 0; i < s.length; i += _idLen) s.substring(i, i + _idLen),
  ];
  _validate(ids);
  return SharedFragment(kind.first, lines[2], ids);
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
