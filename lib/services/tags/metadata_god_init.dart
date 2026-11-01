import 'package:metadata_god/metadata_god.dart';

// Process-wide: the Rust library refuses to be initialised twice.
Future<void>? _init;

/// Initialises the Rust library once; a failed attempt can be retried.
Future<void> ensureMetadataGod() async {
  final pending = _init ??= MetadataGod.initialize();
  try {
    await pending;
  } catch (_) {
    _init = null;
    rethrow;
  }
}
