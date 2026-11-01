import 'package:metadata_god/metadata_god.dart' as rust;

import 'metadata_god_init.dart';

/// Chromaprint of a file: `fp` as `fpcalc` prints it, `secs` the whole duration.
abstract class Fingerprinter {
  /// Opus and WebM cannot be decoded (R-184): they are never fingerprinted.
  static bool supports(String path) {
    final p = path.toLowerCase();
    return !p.endsWith('.opus') && !p.endsWith('.webm');
  }

  Future<({String fp, int secs})?> of(String path);
}

class RustFingerprinter implements Fingerprinter {
  /// null = the format is not fingerprintable; a read failure throws, so the
  /// caller can tell a «no» from a file that could not be read this time.
  @override
  Future<({String fp, int secs})?> of(String path) async {
    if (!Fingerprinter.supports(path)) return null;
    await ensureMetadataGod();
    final f = await rust.fingerprint(path: path);
    return f.fingerprint.isEmpty ? null : (fp: f.fingerprint, secs: f.durationS);
  }
}
