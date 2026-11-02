import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/jam_providers.dart';
import '../../../providers/jam_remote_providers.dart';
import '../../../services/jam/remote/jam_bridge.dart' show JamBridgeStatus;
import '../../../services/jam/remote/jam_invite.dart';
import '../../../services/jam/remote/jam_protocol.dart';
import '../../theme/tokens.dart';
import '../../widgets/cc_app_bar.dart';
import '../../widgets/cc_sheet.dart';
import '../settings/jam_remote_settings.dart';
import 'jam_screen.dart';

/// «Invita chi è vicino»: bridge state, the rotating QR and the typed code.
class JamInviteSheet extends ConsumerStatefulWidget {
  const JamInviteSheet({super.key});

  static Future<void> show(BuildContext context) => showCcSheet<void>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        builder: (_) => const JamInviteSheet(),
      );

  @override
  ConsumerState<JamInviteSheet> createState() => _JamInviteSheetState();
}

class _JamInviteSheetState extends ConsumerState<JamInviteSheet> {
  // Captured now: `ref` must not be used from dispose().
  late final JamController _jam = ref.read(jamProvider.notifier);
  late final JamBridgeNotifier _bridge = ref.read(jamBridgeProvider.notifier);
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Riverpod forbids changing a provider while the tree builds.
    scheduleMicrotask(_jam.invite);
    // The QR changes every 30 s and the code counts down: redraw each second.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
    // The bridge comes up a moment after invite(): the code starts with it.
    ref.listenManual(jamBridgeProvider.select((s) => s.on), (was, on) {
      if (on) unawaited(_bridge.startCode());
      if (was == true && !on) _close(); // the Jam is over: nothing left to invite to
    }, fireImmediately: true);
    // The guest got in: the bridge stays on for the Jam, the sheet has done its job.
    ref.listenManual(jamProvider.select((s) => s.active), (_, active) {
      if (active) _close();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    final jam = _jam, bridge = _bridge;
    scheduleMicrotask(() {
      bridge.stopCode();
      jam.stopInviting();
    });
    super.dispose();
  }

  void _close() {
    if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) Navigator.of(context).pop();
  }

  void _openSettings() {
    final nav = Navigator.of(context, rootNavigator: true);
    nav.pop();
    nav.push(MaterialPageRoute<void>(builder: (_) => const JamRemoteSettings()));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context).textTheme;
    final b = ref.watch(jamBridgeProvider);
    final qr = b.on && b.status == JamBridgeStatus.up ? _bridge.currentQr() : null;
    final code = _bridge.code;
    final left = _bridge.codeExpiresAt?.difference(DateTime.now()).inSeconds ?? 0;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(CcDims.margin, 0, CcDims.margin, CcDims.gap16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.jamInviteNearby, style: theme.titleMedium),
            const SizedBox(height: 8),
            Text(l.jamInviteHint, style: theme.bodyMedium),
            const SizedBox(height: 16),
            if (b.status == JamBridgeStatus.unreachable) ...[
              Text(l.jamBridgeUnreachable, style: theme.bodyLarge),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: _openSettings, child: Text(l.jamRemoteTitle)),
              ),
            ] else if (qr == null)
              Row(children: [
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Text(b.status == JamBridgeStatus.retrying ? l.jamBridgeRetrying : l.jamBridgeConnecting),
              ])
            else ...[
              Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(CcDims.gap8),
                  child: QrImageView(data: qr, size: 200),
                ),
              ),
              const SizedBox(height: 16),
              if (code != null) ...[
                Center(child: SelectableText(code, style: theme.headlineMedium)),
                Center(child: Text(l.jamCodeExpiresIn(left < 0 ? 0 : left), style: theme.labelMedium)),
              ] else
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ],
        ),
      ),
    );
  }
}

/// «Entra con un codice»: the typed code, or the QR on Android.
class JamJoinSheet extends ConsumerStatefulWidget {
  const JamJoinSheet({super.key});

  static Future<void> show(BuildContext context) => showCcSheet<void>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        builder: (_) => const JamJoinSheet(),
      );

  @override
  ConsumerState<JamJoinSheet> createState() => _JamJoinSheetState();
}

class _JamJoinSheetState extends ConsumerState<JamJoinSheet> {
  final _code = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  /// A malformed code is told here, with no network; the rest goes to the Jam screen.
  void _go(JamInvite? invite) {
    if (invite == null) return setState(() => _invalid = true);
    final nav = Navigator.of(context, rootNavigator: true);
    unawaited(ref.read(jamProvider.notifier).requestRemote(invite));
    nav.pop();
    nav.push(MaterialPageRoute<void>(builder: (_) => const JamScreen()));
  }

  Future<void> _scan() async {
    final text = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _JamQrScan()));
    if (text == null || !mounted) return;
    final protocol = JamProtocol(await ref.read(jamCryptoProvider.future));
    if (mounted) _go(JamInvite.fromQr(text, protocol));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(CcDims.margin, 0, CcDims.margin, CcDims.gap16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.jamEnterCode, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                TextInputFormatter.withFunction((o, n) => n.copyWith(text: n.text.toUpperCase())),
              ],
              decoration: InputDecoration(
                labelText: l.jamCodeLabel,
                hintText: 'XXXX-XXXX',
                errorText: _invalid ? l.jamCodeInvalid : null,
              ),
              onChanged: (_) => _invalid ? setState(() => _invalid = false) : null,
              onSubmitted: (v) => _go(JamInvite.fromCode(v)),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => _go(JamInvite.fromCode(_code.text)), child: Text(l.jamJoinAction)),
            if (Platform.isAndroid)
              TextButton.icon(
                onPressed: _scan,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: Text(l.jamScanQr),
              ),
          ],
        ),
      ),
    );
  }
}

/// Camera page: returns the first QR that is a Jam one (`CCJ1:`).
class _JamQrScan extends StatefulWidget {
  const _JamQrScan();

  @override
  State<_JamQrScan> createState() => _JamQrScanState();
}

class _JamQrScanState extends State<_JamQrScan> {
  bool _done = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: CcAppBar(title: context.l10n.jamScanQr),
        body: MobileScanner(
          onDetect: (capture) {
            for (final b in capture.barcodes) {
              final v = b.rawValue;
              if (!_done && v != null && v.startsWith('CCJ1:')) {
                _done = true;
                Navigator.of(context).pop(v);
              }
            }
          },
        ),
      );
}
