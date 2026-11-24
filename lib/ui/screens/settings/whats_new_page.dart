import 'package:flutter/material.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../services/online/update_checker.dart';
import '../../../services/update/release_notes.dart';
import '../../theme/tokens.dart';
import '../../widgets/release_notes_view.dart';

/// «Aggiornata alla X»: a full-screen sheet on a phone, a dialog from [CcDims.wideBreakpoint].
/// No button leads to a feature (D-711): only «Inizia» and the link to GitHub.
Future<void> showWhatsNew(BuildContext context, UpdateInfo info) {
  final page = WhatsNewPage(info: info);
  return MediaQuery.sizeOf(context).width >= CcDims.wideBreakpoint
      ? showDialog<void>(context: context, builder: (_) => page)
      : Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => page));
}

class WhatsNewPage extends StatelessWidget {
  const WhatsNewPage({super.key, required this.info});

  final UpdateInfo info;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= CcDims.wideBreakpoint;
    final body = ListView(
      padding: const EdgeInsets.all(CcDims.margin),
      children: [
        const SizedBox(height: 12),
        ExcludeSemantics(
          child: Center(
            child: CircleAvatar(
              radius: 36,
              backgroundColor: t.colorScheme.primaryContainer,
              child: Icon(Icons.check_rounded, size: 40, color: t.colorScheme.onPrimaryContainer),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: Text(l.whatsNewTitle(info.version), style: t.textTheme.headlineSmall, textAlign: TextAlign.center),
        ),
        const SizedBox(height: 8),
        Text(l.whatsNewSafe, style: t.textTheme.bodyMedium, textAlign: TextAlign.center),
        ReleaseNotesView(notes: parseReleaseNotes(info.notes), url: info.url),
      ],
    );
    final start = Padding(
      padding: const EdgeInsets.all(CcDims.margin),
      child: FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.whatsNewStart)),
    );
    final content = Column(
      children: [
        Expanded(child: body),
        SafeArea(top: false, child: start),
      ],
    );
    return wide
        ? Dialog(
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640), child: content),
          )
        : Scaffold(body: SafeArea(bottom: false, child: content));
  }
}
