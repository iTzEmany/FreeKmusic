import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../core/app_log.dart';

/// This device's identity for the local network: a self-signed EC P-256
/// certificate made once and kept. Its SHA-256 [fingerprint] is what a paired
/// device remembers; the certificate itself is trusted by nobody else.
class DeviceIdentity {
  const DeviceIdentity._({
    required this.certPem,
    required this.keyPem,
    required this.fingerprint,
    required this.regenerated,
  });

  final String certPem, keyPem;

  /// 64 upper-case hex digits (SHA-256 of the DER certificate).
  final String fingerprint;

  /// The files were unreadable and a new identity replaced them: devices
  /// paired before must pair again.
  final bool regenerated;

  /// Reads `<dir>/identity/{cert,key}.pem`; makes them the first time. Files
  /// that do not form a usable pair are replaced (and [regenerated] says so).
  static Future<DeviceIdentity> loadOrCreate(Directory dir) async {
    final folder = Directory(p.join(dir.path, 'identity'));
    final certFile = File(p.join(folder.path, 'cert.pem'));
    final keyFile = File(p.join(folder.path, 'key.pem'));
    var hadFiles = false;
    if (certFile.existsSync() && keyFile.existsSync()) {
      hadFiles = true;
      try {
        return _fromPem(certFile.readAsStringSync(), keyFile.readAsStringSync(), regenerated: false);
      } on Object catch (e) {
        AppLog.w('device identity unreadable, making a new one: paired devices must pair again', e);
      }
    }
    final (cert, key) = await Isolate.run(_generate);
    folder.createSync(recursive: true);
    // Written to a temp name first, so a crash never leaves half a pair.
    final tmpCert = File('${certFile.path}.tmp')..writeAsStringSync(cert);
    final tmpKey = File('${keyFile.path}.tmp')..writeAsStringSync(key);
    tmpKey.renameSync(keyFile.path);
    tmpCert.renameSync(certFile.path);
    if (!Platform.isWindows) {
      try {
        Process.runSync('chmod', ['600', keyFile.path]);
      } on Object catch (e) {
        AppLog.d('could not restrict the key file', e);
      }
    }
    return _fromPem(cert, key, regenerated: hadFiles);
  }

  static DeviceIdentity _fromPem(String cert, String key, {required bool regenerated}) {
    final der = derFromPem(cert);
    // A mismatched or damaged pair fails here, not at the first connection.
    SecurityContext()
      ..useCertificateChainBytes(utf8.encode(cert))
      ..usePrivateKeyBytes(utf8.encode(key));
    return DeviceIdentity._(
      certPem: cert,
      keyPem: key,
      fingerprint: fingerprintOfDer(der),
      regenerated: regenerated,
    );
  }

  /// For `HttpServer.bindSecure`.
  SecurityContext context() => SecurityContext()
    ..useCertificateChainBytes(utf8.encode(certPem))
    ..usePrivateKeyBytes(utf8.encode(keyPem));

  static String fingerprintOfDer(List<int> der) =>
      sha256.convert(der).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();

  /// The DER bytes of the first certificate in [pem].
  static List<int> derFromPem(String pem) {
    final body = pem
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('-----'))
        .join();
    return base64.decode(body);
  }
}

(String cert, String key) _generate() {
  final pair = CryptoUtils.generateEcKeyPair();
  final priv = pair.privateKey as ECPrivateKey;
  final pub = pair.publicKey as ECPublicKey;
  final csr = X509Utils.generateEccCsrPem({'CN': 'FreeKmusic', 'O': 'FreeKmusic'}, priv, pub);
  final cert = X509Utils.generateSelfSignedCertificate(priv, csr, 365 * 20, sans: ['localhost']);
  return (cert, CryptoUtils.encodeEcPrivateKeyToPem(priv));
}
