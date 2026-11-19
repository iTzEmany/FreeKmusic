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
  late bool? canAnswer;
  late bool? sameAnswer;
  late bool noHandler;
  late String? path;

  setUp(() {
    calls = [];
    can = true;
    same = true;
    boom = false;
    canAnswer = true;
    sameAnswer = true;
    noHandler = false;
    path = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (c) async {
          calls.add(c.method);
          if (noHandler) throw MissingPluginException();
          if (c.method == 'canInstall') return canAnswer == true ? can : canAnswer;
          if (c.method == 'sameSigner') {
            path = (c.arguments as Map)['path'] as String;
            return sameAnswer == true ? same : sameAnswer;
          }
          if (c.method == 'install') path = (c.arguments as Map)['path'] as String;
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

  test(
    'can=false and same=false: differentSigner (signer checked first)',
    () async {
      can = false;
      same = false;
      expect(
        await AndroidUpdate().install('/c/updates/a.apk'),
        AndroidInstallResult.differentSigner,
      );
    },
  );

  test('openInstallSettings calls the channel and answers true', () async {
    expect(await AndroidUpdate().openInstallSettings(), isTrue);
    expect(calls, ['openInstallSettings']);
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
    expect(calls, ['sameSigner', 'canInstall', 'install']);
  });

  test('platform error: failed', () async {
    boom = true;
    expect(
      await AndroidUpdate().install('/c/updates/a.apk'),
      AndroidInstallResult.failed,
    );
  });

  test('signer answer null: differentSigner, permission not asked', () async {
    sameAnswer = null;
    expect(await AndroidUpdate().install('/c/updates/a.apk'), AndroidInstallResult.differentSigner);
    expect(calls, ['sameSigner']);
  });

  test('permission answer null: needsPermission', () async {
    canAnswer = null;
    expect(await AndroidUpdate().install('/c/updates/a.apk'), AndroidInstallResult.needsPermission);
  });

  test('the path reaches the platform', () async {
    await AndroidUpdate().install('/c/updates/a.apk');
    expect(path, '/c/updates/a.apk');
  });

  test('no handler on the platform: failed, canInstall false, nothing thrown', () async {
    noHandler = true;
    final a = AndroidUpdate();
    expect(await a.install('/c/updates/a.apk'), AndroidInstallResult.failed);
    expect(await a.canInstall(), isFalse);
    expect(await a.openInstallSettings(), isFalse);
  });
}
