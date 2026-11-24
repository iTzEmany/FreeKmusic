import '../../core/app_log.dart';
import 'http_client.dart';

/// Orders two versions like `1.2.0`, `v1.10.1`, `1.2.0-beta.1+5`: negative if
/// [a] is older than [b], 0 if equal, positive if newer. A pre-release is
/// older than its release; the build part after `+` is ignored.
int compareVersions(String a, String b) {
  final pa = _Version.parse(a), pb = _Version.parse(b);
  for (var i = 0; i < 3; i++) {
    final c = pa.core[i].compareTo(pb.core[i]);
    if (c != 0) return c;
  }
  if (pa.pre.isEmpty && pb.pre.isEmpty) return 0;
  if (pa.pre.isEmpty) return 1;
  if (pb.pre.isEmpty) return -1;
  final n = pa.pre.length < pb.pre.length ? pa.pre.length : pb.pre.length;
  for (var i = 0; i < n; i++) {
    final x = pa.pre[i], y = pb.pre[i];
    final nx = int.tryParse(x), ny = int.tryParse(y);
    final c = nx != null && ny != null ? nx.compareTo(ny) : x.compareTo(y);
    if (c != 0) return c;
  }
  return pa.pre.length.compareTo(pb.pre.length);
}

class _Version {
  _Version(this.core, this.pre);

  final List<int> core;
  final List<String> pre;

  factory _Version.parse(String raw) {
    var s = raw.trim();
    if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
    final plus = s.indexOf('+');
    if (plus >= 0) s = s.substring(0, plus);
    final dash = s.indexOf('-');
    final pre = dash >= 0 ? s.substring(dash + 1).split('.') : <String>[];
    final nums = (dash >= 0 ? s.substring(0, dash) : s).split('.');
    return _Version([
      for (var i = 0; i < 3; i++) i < nums.length ? int.tryParse(nums[i]) ?? 0 : 0,
    ], pre);
  }
}

/// A file attached to a release; [sha256] comes from the API's `digest`.
class UpdateAsset {
  const UpdateAsset({required this.name, required this.url, required this.size, this.sha256});

  final String name;
  final Uri url;
  final int size;
  final String? sha256;
}

List<UpdateAsset> _assetsOf(Object? raw) => [
  if (raw is List)
    for (final a in raw)
      if (a is Map && a['name'] is String && a['browser_download_url'] is String)
        UpdateAsset(
          name: a['name'] as String,
          url: Uri.parse(a['browser_download_url'] as String),
          size: a['size'] is int ? a['size'] as int : 0,
          sha256: a['digest'] is String && (a['digest'] as String).startsWith('sha256:')
              ? (a['digest'] as String).substring(7).trim().toLowerCase()
              : null,
        ),
];

class UpdateInfo {
  const UpdateInfo({required this.version, required this.url, this.notes = '', this.assets = const []});

  /// Without the leading `v`.
  final String version;

  /// The release page, to copy.
  final String url;
  final String notes;
  final List<UpdateAsset> assets;
}

enum UpdateStatus { newer, upToDate, rateLimited, failed }

class UpdateResult {
  const UpdateResult(this.status, [this.info]);

  final UpdateStatus status;

  /// The latest release (also when [status] is [UpdateStatus.upToDate], unless
  /// the repository has no published release yet).
  final UpdateInfo? info;
}

/// Asks GitHub for the latest release of [repo] (`owner/name`). Only when
/// called: nothing here schedules a check.
class UpdateChecker {
  UpdateChecker(this._web, {required this.repo, required this.current, this.onNewer});

  final WebClient _web;
  final String repo;
  final String current;

  /// Told of the release when a check finds a newer one (the app keeps its notes).
  final void Function(UpdateInfo info)? onNewer;

  Future<UpdateResult> check() async {
    if (repo.isEmpty) return const UpdateResult(UpdateStatus.failed);
    try {
      // /releases/latest answers 404 while nothing is published, which the
      // client reads as a failure: list the releases and pick the first one.
      final list = await _web.getJson('https://api.github.com/repos/$repo/releases?per_page=10');
      if (list is! List) return const UpdateResult(UpdateStatus.failed);
      Map? json;
      for (final e in list) {
        if (e is Map && e['draft'] != true && e['prerelease'] != true) {
          json = e;
          break;
        }
      }
      // No published release yet: nothing newer than this one.
      if (json == null) return const UpdateResult(UpdateStatus.upToDate);
      final tag = json['tag_name'];
      if (tag is! String || tag.isEmpty) return const UpdateResult(UpdateStatus.failed);
      final info = UpdateInfo(
        version: tag.replaceFirst(RegExp('^[vV]'), ''),
        url: json['html_url'] is String ? json['html_url'] as String : 'https://github.com/$repo/releases',
        notes: json['body'] is String ? (json['body'] as String).trim() : '',
        assets: _assetsOf(json['assets']),
      );
      final newer = compareVersions(info.version, current) > 0;
      if (newer) onNewer?.call(info);
      return UpdateResult(newer ? UpdateStatus.newer : UpdateStatus.upToDate, info);
    } on RateLimitedException {
      return const UpdateResult(UpdateStatus.rateLimited);
    } on Object catch (e, st) {
      AppLog.w('update check failed', e, st);
      return const UpdateResult(UpdateStatus.failed);
    }
  }
}
