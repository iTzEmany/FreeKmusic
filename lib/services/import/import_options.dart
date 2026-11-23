import 'package:shared_preferences/shared_preferences.dart';

import '../../core/import_row.dart';

/// Preference key prefix of «scarica anche» (D-665), one key per import: device state, never in a backup.
const importDownloadTooPrefix = 'importDownloadToo.';

/// Drops the «scarica anche» key of each import in [importIds] (cancelled, or deleted with its playlist).
Future<void> forgetImportDownloadToo(SharedPreferences prefs, Iterable<int> importIds) async {
  for (final id in importIds) {
    await prefs.remove('$importDownloadTooPrefix$id');
  }
}

/// What the user chose in the preview, stored with the import.
class ImportOptions {
  const ImportOptions({
    this.linkOnly = false,
    this.planFirst = false,
    this.folderPath,
    this.numberFiles = false,
    this.fetchCovers = false,
    this.downloadToo = false,
  });

  /// Link what the library has, search and download nothing.
  final bool linkOnly;

  /// Search every row first and wait for the user before downloading.
  final bool planFirst;

  /// Download into this sub-folder of the download folder.
  final String? folderPath;

  /// Prefix file names with the row number.
  final bool numberFiles;

  /// Look the album cover up after each download.
  final bool fetchCovers;

  /// «Scarica anche»: besides saving the songs in streaming, download their files (D-665).
  final bool downloadToo;
}

/// Short codes kept in `playlist_import_items.note`; the UI turns them into text.
abstract final class ImportNote {
  static const noResults = 'no_results';
  static const lowScore = 'low_score';
  static const linkOnly = 'link_only';
  static const youtubeOff = 'youtube_off';
  static const downloadFailed = 'download_failed';
  static const lengthOff = 'length_off';

  /// A row a sync found already in the playlist: nothing was done for it.
  static const unchanged = 'unchanged';
}

/// File name (no extension) of a row: `Artist - Title`, or with its position
/// `007 - Artist - Title` so a folder plays in playlist order in any player.
/// [total] fixes the width of the number (at least two digits).
String importDownloadName(ImportRow row, {required bool number, required int total}) {
  final base = row.artists.isEmpty ? row.title : '${row.artistLine} - ${row.title}';
  if (!number) return base;
  final width = total.toString().length < 2 ? 2 : total.toString().length;
  return '${(row.index + 1).toString().padLeft(width, '0')} - $base';
}
