import 'package:codecore/services/update/android_update.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('codecore/update');
  late List<String> calls;
  late bool can;
  late bool same;
  late bool boom;

  setUp(() {
    calls = [];
    can = true;
    same = true;
    boom = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (c) async {
          calls.add(c.method);
          if (c.method == 'canInstall') return can;
          if (c.method == 'sameSigner') return same;
          if (c.method == 'install' && boom) {
            throw PlatformException(code: 'update');
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test('missing permission: needsPermission, no installer', () async {
    can = false;
    expect(
      await AndroidUpdate().install('/c/updates/a.apk'),
      AndroidInstallResult.needsPermission,
    );
    expect(calls, isNot(contains('install')));
  });

  test('different signer: differentSigner, installer not started', () async {
    same = false;
    expect(
      await AndroidUpdate().install('/c/updates/a.apk'),
      AndroidInstallResult.differentSigner,
    );
    expect(calls, isNot(contains('install')));
  });

  test('happy path: started', () async {
    expect(
      await AndroidUpdate().install('/c/updates/a.apk'),
      AndroidInstallResult.started,
    );
    expect(calls, ['canInstall', 'sameSigner', 'install']);
  });

  test('platform error: failed', () async {
    boom = true;
    expect(
      await AndroidUpdate().install('/c/updates/a.apk'),
      AndroidInstallResult.failed,
    );
  });
}
