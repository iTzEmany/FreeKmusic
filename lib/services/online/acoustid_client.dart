import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/app_info.dart';
import '../../core/app_log.dart';
import 'http_client.dart';
import 'request_budget.dart' show apiUserAgent;

/// One recording AcoustID links to a fingerprint.
class AcoustIdRecording {
  const AcoustIdRecording({
    required this.id,
    required this.title,
    required this.artists,
    this.durationS,
    this.year,
  });

  /// MusicBrainz recording id.
  final String id;
  final String title;
  final List<String> artists;
  final int? durationS;

  /// Earliest release year, if any release carries one.
  final int? year;
}

/// A fingerprint match: [score] is 0..1, [recordings] keeps AcoustID's order.
class AcoustIdHit {
  const AcoustIdHit({required this.id, required this.score, required this.recordings});

  final String id;
  final double score;
  final List<AcoustIdRecording> recordings;
}

/// AcoustID lookup by fingerprint. Only the fingerprint travels, never audio.
class AcoustIdClient {
  AcoustIdClient([Dio? dio, RateLimiter? limiter, DateTime Function()? now])
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 15),
              validateStatus: (_) => true,
            )),
        _limiter = limiter ?? RateLimiter(minGap: const Duration(milliseconds: 340)),
        _now = now ?? DateTime.now;

  static const _url = 'https://api.acoustid.org/v2/lookup';
  static const cooldown = Duration(minutes: 5);

  final Dio _dio;
  final RateLimiter _limiter;
  final DateTime Function() _now;
  DateTime? _restUntil;

  bool get isResting => _restUntil?.isAfter(_now()) ?? false;

  Future<List<AcoustIdHit>> lookup(String fp, int secs, {CancelToken? cancel}) async {
    if (isResting) throw const RateLimitedException(429);
    await _limiter.wait();
    // Queued calls wake up after a 429 or a cancel: re-check.
    if (isResting) throw const RateLimitedException(429);
    if (cancel?.isCancelled ?? false) {
      throw DioException.requestCancelled(
        requestOptions: RequestOptions(path: _url),
        reason: cancel!.cancelError?.message,
      );
    }
    final body = Uri(queryParameters: {
      'client': kAcoustIdClient,
      'duration': '$secs',
      'fingerprint': fp,
      // Space, not '+': in a form body it is what the docs' "recordings+releases" means.
      'meta': 'recordings releases compress',
    }).query;
    final res = await _dio.post<Object?>(
      _url,
      cancelToken: cancel,
      data: Uint8List.fromList(gzip.encode(utf8.encode(body))),
      options: Options(
        responseType: ResponseType.json,
        headers: {
          'User-Agent': apiUserAgent,
          'Content-Encoding': 'gzip',
          Headers.contentTypeHeader: Headers.formUrlEncodedContentType,
        },
      ),
    );
    final code = res.statusCode;
    if (code == 429 || code == 503) {
      _restUntil = _now().add(cooldown);
      AppLog.w('AcoustID HTTP $code: resting for ${cooldown.inMinutes} min');
      throw RateLimitedException(code!);
    }
    final data = res.data;
    if (code != 200 || data is! Map) throw Exception('AcoustID HTTP $code');
    return parseAcoustId(data);
  }

  void close() => _dio.close();
}

/// Untrusted input: whatever is missing or of the wrong type is skipped.
List<AcoustIdHit> parseAcoustId(Map data) {
  final results = data['results'];
  return [
    if (results is List)
      for (final r in results)
        if (r is Map && r['id'] is String && r['score'] is num && (r['score'] as num).isFinite)
          AcoustIdHit(
            id: r['id'] as String,
            score: (r['score'] as num).toDouble(),
            recordings: [
              if (r['recordings'] is List)
                for (final rec in r['recordings'] as List)
                  if (rec is Map && rec['id'] is String && rec['title'] is String)
                    AcoustIdRecording(
                      id: rec['id'] as String,
                      title: rec['title'] as String,
                      artists: [
                        if (rec['artists'] is List)
                          for (final a in rec['artists'] as List)
                            if (a is Map && a['name'] is String) a['name'] as String,
                      ],
                      durationS: rec['duration'] is num && (rec['duration'] as num).isFinite
                          ? (rec['duration'] as num).round()
                          : null,
                      year: _minYear(rec['releases']),
                    ),
            ],
          ),
  ];
}

int? _minYear(Object? releases) {
  if (releases is! List) return null;
  int? min;
  for (final r in releases) {
    final d = r is Map ? r['date'] : null;
    final y = d is Map ? d['year'] : null;
    if (y is int && (min == null || y < min)) min = y;
  }
  return min;
}
