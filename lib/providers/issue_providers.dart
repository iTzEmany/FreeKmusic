import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/app_info.dart';
import '../core/app_log.dart';
import '../core/constants.dart';
import '../core/issue_report.dart';
import '../core/paths.dart';
import '../services/issue/issue_sender.dart';
import '../services/issue/link_opener.dart';
import 'settings_providers.dart';
import 'share_providers.dart';

final linkOpenerProvider = Provider<LinkOpener>((ref) => LinkOpener());

/// Where reports are sent; empty = no anonymous sending.
final issueEndpointProvider = Provider<String>((ref) => kReportEndpoint);

final issueSenderProvider = Provider<IssueSender>(
  (ref) => HttpIssueSender(ref.watch(issueEndpointProvider)),
);

/// What «Segnala un problema» would attach, with the log already redacted.
final issueTechInfoProvider = FutureProvider.autoDispose<TechInfo>((ref) async {
  final s = ref.read(settingsProvider);
  final device = await ref.read(linkOpenerProvider).deviceInfo();
  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
  var log = '';
  try {
    final dir = await appSupportDir();
    for (final name in const ['codecore.log.1', 'codecore.log']) {
      final f = File(p.join(dir, name));
      if (await f.exists()) log += await f.readAsString();
    }
  } on Object catch (e, st) {
    AppLog.w('reading the log for a report failed', e, st);
  }
  return TechInfo(
    appVersion: kAppVersion,
    buildNumber: device['build'] ?? '-',
    platform: Platform.operatingSystem,
    osVersion: device['os'] ?? Platform.operatingSystemVersion,
    deviceModel: device['model'] ?? Platform.operatingSystem,
    flavor: kEnableYoutube ? 'completa' : 'lite',
    transition: s.transition.name,
    shufflePlus: s.shufflePlus,
    language: s.language,
    logLines: recentProblemLines(
      log,
      home: home,
      deviceName: ref.read(deviceNameProvider),
    ),
  );
});
