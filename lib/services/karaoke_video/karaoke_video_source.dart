/// Address of the video-only stream of a karaoke video; [expires] from the URL's `expire` parameter.
typedef KaraokeVideoStream = ({Uri url, Map<String, String> headers, DateTime? expires});

KaraokeVideoStream karaokeVideoStreamOf(Uri url, [Map<String, String> headers = const {}]) {
  final secs = int.tryParse(url.queryParameters['expire'] ?? '');
  return (
    url: url,
    headers: headers,
    expires: secs == null ? null : DateTime.fromMillisecondsSinceEpoch(secs * 1000, isUtc: true),
  );
}

/// Where the video of a karaoke track comes from: the platform's yt-dlp service (`service.videoUrl`).
class KaraokeVideoSource {
  const KaraokeVideoSource(this._fetch);
  final Future<KaraokeVideoStream> Function(String id) _fetch;

  Future<KaraokeVideoStream> videoUrl(String id) => _fetch(id);
}
