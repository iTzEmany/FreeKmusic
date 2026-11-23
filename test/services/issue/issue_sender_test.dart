import 'dart:convert';
import 'dart:typed_data';

import 'package:codecore/core/app_info.dart' show kReleaseRepo;
import 'package:codecore/services/issue/issue_sender.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter({this.status = 201, this.body = '{"url":"https://github.com/$kReleaseRepo/issues/7"}', this.error});
  final int status;
  final String body;
  final DioException? error;
  RequestOptions? seen;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    seen = options;
    if (error != null) throw error!;
    return ResponseBody.fromString(body, status, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

Future<(IssueSendResult, _Adapter)> _send({
  String endpoint = 'https://x.test/report',
  _Adapter? adapter,
}) async {
  final a = adapter ?? _Adapter();
  final dio = Dio(BaseOptions(validateStatus: (_) => true))..httpClientAdapter = a;
  final r = await HttpIssueSender(endpoint, dio).send(title: 't', body: 'b', version: '1.0');
  return (r, a);
}

void main() {
  test('posts the report as JSON and returns the issue address', () async {
    final (r, a) = await _send();
    expect(r.status, IssueSendStatus.sent);
    expect(r.url, 'https://github.com/$kReleaseRepo/issues/7');
    expect(a.seen!.headers['content-type'], contains('application/json'));
    expect(a.seen!.data, {'title': 't', 'body': 'b', 'version': '1.0'});
  });

  test('201 without a valid address is still sent (no duplicate on retry)', () async {
    for (final body in ['{}', 'not json', '{"url":"http://x"}']) {
      final (r, _) = await _send(adapter: _Adapter(body: body));
      expect(r.status, IssueSendStatus.sent, reason: body);
      expect(r.url, kIssuesListUrl, reason: body);
    }
    // Only an issue link of this repository is shown to the user.
    final (r, _) = await _send(adapter: _Adapter(body: '{"url":"https://evil.test/x"}'));
    expect(r.url, kIssuesListUrl);
  });

  test('429 is rate limited, other answers are rejected', () async {
    expect((await _send(adapter: _Adapter(status: 429))).$1.status, IssueSendStatus.rateLimited);
    expect((await _send(adapter: _Adapter(status: 400, body: jsonEncode({'error': 'x'})))).$1.status,
        IssueSendStatus.rejected);
  });

  test('a network error is unsure (the issue may exist)', () async {
    final e = DioException(requestOptions: RequestOptions(), type: DioExceptionType.receiveTimeout);
    expect((await _send(adapter: _Adapter(error: e))).$1.status, IssueSendStatus.unsure);
  });

  test('504 (the service had no answer from GitHub) is unsure', () async {
    expect((await _send(adapter: _Adapter(status: 504))).$1.status, IssueSendStatus.unsure);
  });

  test('an empty endpoint sends nothing', () async {
    final (r, a) = await _send(endpoint: '');
    expect(r.status, IssueSendStatus.rejected);
    expect(a.seen, isNull);
  });
}
