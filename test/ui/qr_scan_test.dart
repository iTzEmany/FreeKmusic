import 'package:codecore/services/share/share_link.dart';
import 'package:codecore/ui/screens/share/qr_scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void main() {
  testWidgets('a share link read by the camera closes the screen with it; other codes are ignored with a notice', (tester) async {
    final h = await Harness.create(tester);
    void Function(String)? feed;
    ShareLink? result;
    await h.pump(
      tester,
      Builder(builder: (context) => TextButton(
            onPressed: () async => result = await Navigator.of(context).push<ShareLink>(MaterialPageRoute(
                builder: (_) => QrScanScreen(
                      allowLoopback: true,
                      scannerBuilder: (onText) {
                        feed = onText;
                        return const Center(child: Text('camera'));
                      },
                    ))),
            child: const Text('open'),
          )),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Inquadra il codice QR'), findsOneWidget);
    expect(find.text('camera'), findsOneWidget);

    feed!('https://example.com/poster');
    await tester.pump();
    expect(find.text('Questo codice non è di FreeKmusic.'), findsOneWidget);
    expect(result, isNull);
    feed!('http://8.8.8.8:80/?pin=123456'); // public address: ignored too
    await tester.pump();
    expect(result, isNull);

    feed!('http://127.0.0.1:4455/?pin=654321');
    await tester.pumpAndSettle();
    expect((result!.host, result!.port, result!.pin), ('127.0.0.1', 4455, '654321'));
    expect(find.text('camera'), findsNothing, reason: 'the scanner closed');
    await h.dispose(tester);
  });
}
