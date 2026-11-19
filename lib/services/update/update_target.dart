import 'dart:io';

import '../../core/constants.dart' show kEnableYoutube;
import '../../core/platform.dart' show isAndroid;
import '../online/update_checker.dart' show UpdateAsset;

enum UpdateKind { androidFull, androidLite, windows, appImage, deb, flatpak, linuxZip, macos }

class UpdateTarget {
  const UpdateTarget({required this.kind, this.abi});

  final UpdateKind kind;

  /// Android only: `arm64-v8a`, `armeabi-v7a`.
  final String? abi;
}

/// Which release file this install updates to; null where there is none.
Future<UpdateTarget?> detectUpdateTarget({
  Future<String> Function()? androidAbi,
  Map<String, String>? env,
  String? executable,
}) async {
  if (isAndroid) {
    if (androidAbi == null) return null;
    return UpdateTarget(kind: kEnableYoutube ? UpdateKind.androidFull : UpdateKind.androidLite, abi: await androidAbi());
  }
  if (Platform.isWindows) return const UpdateTarget(kind: UpdateKind.windows);
  if (Platform.isMacOS) return const UpdateTarget(kind: UpdateKind.macos);
  if (!Platform.isLinux) return null;
  final e = env ?? Platform.environment;
  if ((e['APPIMAGE'] ?? '').isNotEmpty) return const UpdateTarget(kind: UpdateKind.appImage);
  if ((e['FLATPAK_ID'] ?? '').isNotEmpty) return const UpdateTarget(kind: UpdateKind.flatpak);
  final exe = executable ?? Platform.resolvedExecutable;
  if (exe.startsWith('/usr/') || exe.startsWith('/opt/')) return const UpdateTarget(kind: UpdateKind.deb);
  return const UpdateTarget(kind: UpdateKind.linuxZip);
}

bool selfInstalls(UpdateKind k) =>
    k == UpdateKind.androidFull || k == UpdateKind.androidLite || k == UpdateKind.windows || k == UpdateKind.appImage;

/// The release file for [t] by name, as `release.yml` names them (the version
/// is a placeholder); null if the release does not carry it.
UpdateAsset? pickUpdateAsset(List<UpdateAsset> assets, UpdateTarget t) {
  final RegExp re = switch (t.kind) {
    UpdateKind.androidFull || UpdateKind.androidLite => RegExp(
      '^freekmusic-${t.kind == UpdateKind.androidFull ? 'full' : 'lite'}-${RegExp.escape(t.abi ?? '')}-release\\.apk\$',
    ),
    UpdateKind.windows => RegExp(r'^FreeKmusic-Setup-.+\.exe$'),
    UpdateKind.appImage => RegExp(r'^freekmusic-.+-x86_64\.AppImage$'),
    UpdateKind.deb => RegExp(r'^freekmusic_.+_amd64\.deb$'),
    UpdateKind.flatpak => RegExp(r'^freekmusic\.flatpak$'),
    UpdateKind.linuxZip => RegExp(r'^freekmusic-linux-x64\.zip$'),
    UpdateKind.macos => RegExp(r'^FreeKmusic-.+-macos\.zip$'),
  };
  for (final a in assets) {
    if (re.hasMatch(a.name)) return a;
  }
  return null;
}
