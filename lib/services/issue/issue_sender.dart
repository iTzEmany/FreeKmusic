import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/app_info.dart' show kReleaseRepo;
import '../../core/app_log.dart';
import '../online/http_client.dart' show DioWebClient;

/// sent: created (url is the issue, or the repo's issue list when the answer
/// had no valid one); rateLimited: HTTP 429; rejected: any other answer (not
/// created); unsure: no answer (it may have been created).
enum IssueSendStatus { sent, rateLimited, rejected, unsure }

class IssueSendResult {
  const IssueSendResult(this.status, [this.url]);
  final IssueSendStatus status;
  final String? url;
}

const kIssuesListUrl = 'https://github.com/$kReleaseRepo/issues';

/// Sends a report to the anonymous-report service (tools/report-worker).
/// Only the «Invia» button calls it.
abstract class IssueSender {
  Future<IssueSendResult> send({required String title, required String body, required String version});
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
  Future<IssueSendResult> send({required String title, required String body, required String version}) async {
    if (endpoint.isEmpty) return const IssueSendResult(IssueSendStatus.rejected);
    try {
      final r = await _dio.post<String>(
        endpoint,
        data: {'title': title, 'body': body, 'version': version},
        options: Options(contentType: Headers.jsonContentType),
      );
      if (r.statusCode == 429) {
        AppLog.w('report not sent: rate limited');
        return const IssueSendResult(IssueSendStatus.rateLimited);
      }
      if (r.statusCode != 201) {
        AppLog.w('report not sent: HTTP ${r.statusCode}');
        return const IssueSendResult(IssueSendStatus.rejected);
      }
      // The issue exists whatever the body says: never turn a bad body into a failure.
      Object? data;
      try {
        data = jsonDecode(r.data ?? '');
      } on FormatException {
        data = null;
      }
      final url = data is Map ? data['url'] : null;
      return IssueSendResult(
        IssueSendStatus.sent,
        url is String && url.startsWith('https://') ? url : kIssuesListUrl,
      );
    } on DioException catch (e, st) {
      AppLog.w('report not sent', e, st);
      return const IssueSendResult(IssueSendStatus.unsure);
    }
  }
}
