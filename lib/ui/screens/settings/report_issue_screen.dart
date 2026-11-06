import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_info.dart';
import '../../../core/issue_report.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/issue_providers.dart';
import '../../theme/tokens.dart';
import '../../widgets/segmented_blocks.dart';
import '../../widgets/show_msg.dart';
import '../../widgets/cc_app_bar.dart';

const kIssueMinDescription = 20;

/// «Segnala un problema»: builds a pre-filled GitHub issue page (no token in
/// the app) and opens it in the browser, or copies the text.
class ReportIssueScreen extends ConsumerStatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  ConsumerState<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends ConsumerState<ReportIssueScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  IssueKind _kind = IssueKind.bug;
  bool _attach = true;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  bool get _valid =>
      _title.text.trim().isNotEmpty &&
      _desc.text.trim().length >= kIssueMinDescription;

  IssueDraft _draft(TechInfo? info) => buildIssue(
    repo: kReleaseRepo,
    kind: _kind,
    title: _title.text,
    description: _desc.text,
    info: _attach ? info : null,
  );

  Future<void> _open(TechInfo? info) async {
    final l = context.l10n;
    final draft = _draft(info);
    final ok = await ref.read(linkOpenerProvider).open(draft.url);
    if (ok) return;
    await Clipboard.setData(ClipboardData(text: draft.plainText));
    if (!mounted) return;
    showMsg(context, l.reportOpenFailed);
  }

  Future<void> _copy(TechInfo? info) async {
    final l = context.l10n;
    await Clipboard.setData(ClipboardData(text: _draft(info).plainText));
    if (!mounted) return;
    showMsg(context, l.reportCopied);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final info = ref.watch(issueTechInfoProvider).value;
    final draft = _valid ? _draft(info) : null;
    return Scaffold(
      appBar: CcAppBar(title: l.reportIssue),
      body: ListView(
        padding: const EdgeInsets.all(CcDims.gap16).withDock(context),
        children: [
          SegmentedBlocks<IssueKind>(
            items: [
              BlockItem(
                value: IssueKind.bug,
                icon: Icons.bug_report_outlined,
                label: l.reportKindBug,
              ),
              BlockItem(
                value: IssueKind.idea,
                icon: Icons.lightbulb_outline,
                label: l.reportKindIdea,
              ),
            ],
            selected: _kind,
            onChanged: (v) => setState(() => _kind = v),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('report-title'),
            controller: _title,
            maxLength: 120,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l.reportTitleLabel,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('report-description'),
            controller: _desc,
            minLines: 5,
            maxLines: 10,
            maxLength: 3000,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              labelText: l.reportDescLabel,
              helperText: l.reportDescHelper(kIssueMinDescription),
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          CheckboxListTile(
            key: const ValueKey('report-attach'),
            contentPadding: EdgeInsets.zero,
            value: _attach,
            title: Text(l.reportAttach),
            onChanged: (v) => setState(() => _attach = v ?? false),
          ),
          if (_attach) _Preview(info: info),
          if (draft != null && draft.logTruncated)
            Padding(
              padding: const EdgeInsets.only(top: CcDims.gap8),
              child: Text(
                l.reportLogShortened,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('report-open'),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l.reportOpen),
                  onPressed: _valid ? () => _open(info) : null,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                key: const ValueKey('report-copy'),
                icon: const Icon(Icons.copy),
                label: Text(l.reportCopy),
                onPressed: _valid ? () => _copy(info) : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l.reportGithubNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.info});

  final TechInfo? info;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context);
    final i = info;
    final text = i == null
        ? '…'
        : i.logLines.isEmpty
        ? '${i.summary}\n\n${l.reportNoLog}'
        : i.render();
    return Container(
      key: const ValueKey('report-preview'),
      padding: const EdgeInsets.all(CcDims.gap12),
      decoration: BoxDecoration(
        color: context.cc.surface1,
        borderRadius: BorderRadius.circular(CcDims.rCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.reportAttachPreview, style: t.textTheme.labelMedium),
          const SizedBox(height: 6),
          SelectableText(
            text,
            style: t.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
