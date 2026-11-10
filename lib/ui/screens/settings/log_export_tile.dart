import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_info.dart';
import '../../../core/app_log.dart';
import '../../../core/log_export.dart';
import '../../../core/paths.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/share_providers.dart';
import '../../../services/export/save_file.dart';
import '../../widgets/show_msg.dart';

String _stamp() => DateTime.now().toIso8601String().substring(0, 10);

/// «Esporta log»: redacted copy of `codecore.log` saved where the user picks.
class LogExportTile extends ConsumerWidget {
  const LogExportTile({super.key});

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final deviceName = ref.read(deviceNameProvider);
    String msg;
    try {
      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '';
      final text = await buildLogReport(
        supportDir: await appSupportDir(),
        home: home,
        appVersion: kAppVersion,
        platform: Platform.operatingSystem,
        deviceName: deviceName,
      );
      if (text == null) {
        msg = l.exportLogNone;
      } else {
        final saved = await saveBytes(
            'freekmusic-log-${_stamp()}.txt', utf8.encode(text),
            mimeType: 'text/plain');
        if (!saved) return;
        msg = l.exportLogSaved;
      }
    } on Object catch (e, st) {
      AppLog.e('export log failed', e, st);
      msg = l.exportLogFailed;
    }
    if (!context.mounted) return;
    showMsg(context, msg);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return ListTile(
      leading: const Icon(Icons.bug_report_outlined),
      title: Text(l.exportLog),
      subtitle: Text(kDebugMode ? l.exportLogDebugOnly : l.exportLogHint),
      enabled: !kDebugMode,
      onTap: kDebugMode ? null : () => _export(context, ref),
    );
  }
}
