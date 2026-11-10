import 'package:dio/dio.dart';

import 'external_collection.dart';
import 'external_links.dart';

const _maxHops = 5;
final _spotifyInBody = RegExp(r'https://open\.spotify\.com/[^\s"\x27<>\\]+');

/// Follows the redirects of a share link by hand, without a cookie jar.
class ShortLinkResolver {
  ShortLinkResolver([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              followRedirects: false,
              validateStatus: (_) => true,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              responseType: ResponseType.plain,
            ));

  final Dio _dio;

  /// The page the short link leads to. A loop, more than five hops or a dead
  /// end is [CollectionNotFound].
  Future<String> resolve(String url, {CancelToken? cancelToken}) async {
    final seen = <String>{};
    var current = url;
    for (var hop = 0; hop <= _maxHops; hop++) {
      final uri = Uri.parse(current);
      if (!seen.add(uri.host)) throw const CollectionNotFound();
      final Response<dynamic> r;
      try {
        r = await _dio.getUri(uri, cancelToken: cancelToken);
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) rethrow;
        throw CollectionUnreadable(e);
      }
      final code = r.statusCode ?? 0;
      if (code >= 300 && code < 400) {
        final loc = r.headers.value('location');
        if (loc == null) throw const CollectionNotFound();
        final next = uri.resolve(loc).toString();
        // A redirect already on its final page host ends the chain.
        if (parseExternalLink(next) != null) return next;
        current = next;
        continue;
      }
      if (code == 200) {
        final m = _spotifyInBody.firstMatch('${r.data}');
        if (m != null) return m.group(0)!;
      }
      throw const CollectionNotFound();
    }
    throw const CollectionNotFound();
  }
}
