import 'dart:typed_data';

import 'package:metadata_god/metadata_god.dart';

import '../../core/app_log.dart';
import 'metadata_god_init.dart';
import 'tag_writer.dart';

/// `metadata_god` (Rust, lofty): changes only the fields given and keeps
/// cover, ReplayGain and unknown tags (checked in 21.1).
class MetadataGodTagWriter implements TagWriter {
  MetadataGodTagWriter();

  static const _formats = {'mp3', 'flac', 'm4a', 'ogg'};

  @override
  bool supports(String format) => _formats.contains(format.toLowerCase());

  @override
  Future<void> write(String path, TagChanges c) async {
    try {
      await ensureMetadataGod();
      await MetadataGod.writeMetadata(
        file: path,
        metadata: Metadata(
          title: c.title,
          artist: c.artist,
          album: c.album,
          albumArtist: c.albumArtist,
          year: c.year,
          genre: c.genre,
          trackNumber: c.trackNumber,
          discNumber: c.discNumber,
          picture: c.cover == null
              ? null
              : Picture(data: Uint8List.fromList(c.cover!.bytes), mimeType: c.cover!.mime),
        ),
      );
    } catch (e, st) {
      AppLog.e('metadata_god write failed: $path', e, st);
      throw TagWriteException(TagWriteReason.writeFailed, '$e');
    }
  }
}
