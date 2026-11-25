import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../services/platform/flatpak_data_notice.dart';

Future<void> showFlatpakDataDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (ctx) {
    final l = ctx.l10n;
    return AlertDialog(
      title: Text(l.flatpakDataTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.flatpakDataBody(flatpakOldDir, flatpakNewDir)),
            const SizedBox(height: 12),
            SelectableText(flatpakCopyCommand),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Clipboard.setData(const ClipboardData(text: flatpakCopyCommand)),
          child: Text(l.flatpakDataCopy),
        ),
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.close)),
      ],
    );
  },
);
