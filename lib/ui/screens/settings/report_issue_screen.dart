import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_info.dart';
import '../../../core/app_log.dart';
import '../../../core/issue_report.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/issue_providers.dart';
import '../../../services/issue/issue_sender.dart' show IssueSendStatus;
import '../../theme/tokens.dart';
import '../../widgets/segmented_blocks.dart';
import '../../widgets/show_msg.dart';
import '../../widgets/cc_app_bar.dart';

const kIssueMinDescription = 20;
const _kMaxWidth = 600.0;
const _kPreviewMaxHeight = 132.0;

/// «Segnala un problema»: sends the report anonymously through the report
/// service (only from «Invia»), copies the text, or builds a pre-filled GitHub
/// page. [title] and [details] pre-fill the form (a line of the Registro).
class ReportIssueScreen extends ConsumerStatefulWidget {
  const ReportIssueScreen({super.key, this.title = '', this.details = ''});

  final String title, details;

  @override
  ConsumerState<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends ConsumerState<ReportIssueScreen> {
  late final _title = TextEditingController(text: widget.title);
  late final _desc = TextEditingController(text: widget.details);
  IssueKind _kind = IssueKind.bug;
  bool _attach = true;
  bool _sending = false;
  IssueSendStatus? _failure;
  bool _shortened = false;
  String? _sentUrl;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  bool get _valid =>
      _title.text.trim().isNotEmpty &&
      _desc.text.trim().length >= kIssueMinDescription;

  /// Built only when a button is pressed, never while typing.
  IssueDraft _draft(TechInfo? info, {bool forService = false}) => buildIssue(
    repo: kReleaseRepo,
    kind: _kind,
    title: _title.text,
    description: _desc.text,
    info: _attach ? info : null,
    fits: forService
        ? (t, b) => fitsReportService(t, b, kAppVersion)
        : null,
  );

  Future<void> _send(TechInfo? loaded) async {
    setState(() {
      _sending = true;
      _failure = null;
    });
    // The preview may still be loading: what is sent must be what the preview shows.
    var info = loaded;
    if (_attach && info == null) {
      try {
        info = await ref.read(issueTechInfoProvider.future);
      } on Object catch (e, st) {
        AppLog.w('technical info for a report failed', e, st);
      }
    }
    final draft = _draft(info, forService: true);
    final r = await ref.read(issueSenderProvider).send(
      title: draft.title,
      body: draft.body,
      version: kAppVersion,
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      _shortened = draft.logTruncated;
      _sentUrl = r.status == IssueSendStatus.sent ? r.url : null;
      _failure = r.status == IssueSendStatus.sent ? null : r.status;
    });
  }

  Future<void> _open(TechInfo? info) async {
    final l = context.l10n;
    final draft = _draft(info);
    final ok = await ref.read(linkOpenerProvider).open(draft.url);
    if (ok) {
      if (draft.logTruncated && mounted) showMsg(context, l.reportLogShortened);
      return;
    }
    await Clipboard.setData(ClipboardData(text: draft.plainText));
    if (!mounted) return;
    showMsg(context, l.reportOpenFailed);
  }

  Future<void> _copy(TechInfo? info) async {
    final l = context.l10n;
    final draft = _draft(info);
    await Clipboard.setData(ClipboardData(text: draft.plainText));
    if (!mounted) return;
    showMsg(context, draft.logTruncated ? '${l.reportCopied}. ${l.reportLogShortened}' : l.reportCopied);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final small = Theme.of(context).textTheme.bodySmall;
    final info = ref.watch(issueTechInfoProvider).value;
    final canSend = ref.watch(issueEndpointProvider).isNotEmpty;
    final valid = _valid;
    final sent = _sentUrl;
    return Scaffold(
      appBar: CcAppBar(title: l.reportIssue),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kMaxWidth),
          child: ListView(
            padding: const EdgeInsets.all(CcDims.gap16).withDock(context),
            children: [
              SegmentedBlocks<IssueKind>(
                items: [
                  BlockItem(value: IssueKind.bug, label: l.reportKindBug),
                  BlockItem(value: IssueKind.idea, label: l.reportKindIdea),
                ],
                selected: _kind,
                onChanged: (v) => setState(() => _kind = v),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('report-title'),
                controller: _title,
                maxLength: kIssueTitleMax,
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
                minLines: 4,
                maxLines: 6,
                maxLength: 3000,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  labelText: l.reportDescLabel,
                  helperText: l.reportDescHelper(kIssueMinDescription),
                  helperMaxLines: 2,
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
              if (_attach && info != null) _Preview(info: info),
              const SizedBox(height: 16),
              if (_shortened)
                Padding(
                  padding: const EdgeInsets.only(bottom: CcDims.gap8),
                  child: Text(l.reportLogShortened, key: const ValueKey('report-shortened'), style: small),
                ),
              if (sent != null)
                _Sent(url: sent, onOpen: () => ref.read(linkOpenerProvider).open(sent))
              else ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (canSend)
                      FilledButton.icon(
                        key: const ValueKey('report-send'),
                        icon: const Icon(Icons.send),
                        label: Text(_sending ? l.reportSending : l.reportSend),
                        onPressed: valid && !_sending ? () => _send(info) : null,
                      ),
                    if (canSend)
                      OutlinedButton.icon(
                        key: const ValueKey('report-copy'),
                        icon: const Icon(Icons.copy),
                        label: Text(l.reportCopy),
                        onPressed: valid ? () => _copy(info) : null,
                      )
                    else
                      FilledButton.icon(
                        key: const ValueKey('report-copy'),
                        icon: const Icon(Icons.copy),
                        label: Text(l.reportCopy),
                        onPressed: valid ? () => _copy(info) : null,
                      ),
                    TextButton.icon(
                      key: const ValueKey('report-open'),
                      icon: const Icon(Icons.open_in_new),
                      label: Text(l.reportOpen),
                      onPressed: valid ? () => _open(info) : null,
                    ),
                  ],
                ),
                if (!valid)
                  Padding(
                    padding: const EdgeInsets.only(top: CcDims.gap8),
                    child: Text(
                      (canSend ? l.reportWhyDisabled : l.reportWhyDisabledCopy)(kIssueMinDescription),
                      key: const ValueKey('report-why-disabled'),
                      style: small,
                    ),
                  ),
                if (_failure != null)
                  Padding(
                    padding: const EdgeInsets.only(top: CcDims.gap8),
                    child: Text(
                      switch (_failure!) {
                        IssueSendStatus.rateLimited => l.reportSendRateLimited,
                        IssueSendStatus.unsure => l.reportSendUnsure,
                        _ => l.reportSendFailed,
                      },
                      key: const ValueKey('report-send-failed'),
                      style: small?.copyWith(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              Text(canSend ? l.reportAnonNote : l.reportGithubNote, style: small),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sent extends StatelessWidget {
  const _Sent({required this.url, required this.onOpen});

  final String url;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      key: const ValueKey('report-sent'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.reportSent),
        const SizedBox(height: 6),
        SelectableText(url),
        const SizedBox(height: 8),
        FilledButton.icon(
          icon: const Icon(Icons.open_in_new),
          label: Text(l.reportOpenSent),
          onPressed: onOpen,
        ),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.info});

  final TechInfo info;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context);
    final i = info;
    final text = i.logLines.isEmpty
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: _kPreviewMaxHeight),
            child: Scrollbar(
              child: SingleChildScrollView(
                child: SelectableText(
                  text,
                  style: t.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
