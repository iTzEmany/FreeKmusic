import 'package:dio/dio.dart';

import '../../core/app_log.dart';
import '../online/http_client.dart' show DioWebClient;

/// Sends a report to the anonymous-report service (tools/report-worker).
/// Only the «Invia» button calls it.
abstract class IssueSender {
  /// The address of the issue created, or null on any failure (empty service
  /// address, network, any answer other than 201).
  Future<String?> send({required String title, required String body, required String version});
}

class HttpIssueSender implements IssueSender {
  HttpIssueSender(this.endpoint, [Dio? dio])
    : _dio = dio ??
          Dio(BaseOptions(
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 15),
            headers: {'User-Agent': DioWebClient.userAgent},
            validateStatus: (_) => true,
          ));

  final String endpoint;
  final Dio _dio;

  @override
  Future<String?> send({required String title, required String body, required String version}) async {
    if (endpoint.isEmpty) return null;
    try {
      final r = await _dio.post<Object?>(
        endpoint,
        data: {'title': title, 'body': body, 'version': version},
        options: Options(contentType: Headers.jsonContentType),
      );
      if (r.statusCode != 201) {
        AppLog.w('report not sent: HTTP ${r.statusCode}');
        return null;
      }
      final data = r.data;
      final url = data is Map ? data['url'] : null;
      return url is String && url.startsWith('https://') ? url : null;
    } on DioException catch (e, st) {
      AppLog.w('report not sent', e, st);
      return null;
    }
  }
}
