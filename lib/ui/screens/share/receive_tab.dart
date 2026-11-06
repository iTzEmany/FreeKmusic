import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/app_log.dart';
import '../../../l10n/l10n_ext.dart';
import '../../theme/tokens.dart';
import '../../../providers/folder_ops.dart';
import '../../../providers/track_ops.dart';
import '../../../providers/library_providers.dart';
import '../../../providers/online_providers.dart' show afterReceive;
import '../../../providers/selection_providers.dart';
import '../../../providers/share_providers.dart';
import '../../../services/share/lan_client.dart';
import '../../../providers/share_hub.dart';
import '../../../core/platform.dart';
import 'incoming_offer_tile.dart';
import 'qr_scan_screen.dart';

class ReceiveTab extends ConsumerStatefulWidget {
  const ReceiveTab({super.key});

  @override
  ConsumerState<ReceiveTab> createState() => _ReceiveTabState();
}

class _ReceiveTabState extends ConsumerState<ReceiveTab> {
  final _address = TextEditingController();
  final _pin = TextEditingController();
  ({String host, int port})? _target;
  List<RemoteTrack> _tracks = const [];
  static final _key = SelectionKey.receive.key;
  String? _remoteName;
  String? _error;
  bool _busy = false;
  CancelToken? _cancel;
  int _doneCount = 0;
  int _totalCount = 0;
  double _fileProgress = 0;
  int? _received;

  @override
  void dispose() {
    _cancel?.cancel();
    _address.dispose();
    _pin.dispose();
    super.dispose();
  }

  String _errorText(LanError e) {
    final l = context.l10n;
    return switch (e) {
      LanError.unreachable => l.shareErrUnreachable,
      LanError.wrongPin => l.shareErrPin,
      LanError.blocked => l.shareErrBlocked,
      LanError.notCodecore => l.shareErrNotCodecore,
      LanError.failed => l.shareErrFailed,
      LanError.identityChanged => l.shareErrIdentity,
    };
  }

  Future<void> _scan() async {
    final link = await scanShareLink(context);
    if (link == null || !mounted) return;
    _address.text = '${link.host}:${link.port}';
    _pin.text = link.pin;
    await _connect();
  }

  Future<void> _connect() async {
    var text = _address.text.trim();
    // A pasted QR link carries the PIN: http://ip:port/?pin=123456
    final uri = Uri.tryParse(text);
    if (uri != null && uri.queryParameters['pin'] != null) {
      _pin.text = uri.queryParameters['pin']!;
    }
    final target = LanClient.parseAddress(text);
    if (target == null) {
      setState(() => _error = context.l10n.shareErrUnreachable);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _received = null;
    });
    final client = ref.read(lanClientProvider);
    try {
      final info = await client.hello(target.host, target.port);
      final list = await client.manifest(
        target.host,
        target.port,
        _pin.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _target = target;
        _remoteName = info.name;
        _tracks = list;
      });
      ref.read(selectionProvider(_key).notifier).selectAll([for (final t in list) t.id]);
    } on LanException catch (e) {
      AppLog.w('share receive failed', e);
      if (mounted) setState(() => _error = _errorText(e.error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download() async {
    final target = _target;
    if (target == null || !ref.read(selectionProvider(_key)).active) return;
    // The container outlives this widget: tags are written after the awaits.
    final read = ProviderScope.containerOf(context, listen: false).read;
    final base = await ref.read(folderOpsProvider).downloadFolder();
    if (!mounted) return;
    if (base == null) {
      if (mounted) setState(() => _error = context.l10n.ytNoFolder);
      return;
    }
    final out = Directory(p.join(base.$1.path, 'Ricevuti'));
    final todo = [
      for (final t in _tracks)
        if (ref.read(selectionProvider(_key)).contains(t.id)) t,
    ];
    final cancel = _cancel = CancelToken();
    setState(() {
      _busy = true;
      _error = null;
      _doneCount = 0;
      _totalCount = todo.length;
      _fileProgress = 0;
    });
    final client = ref.read(lanClientProvider);
    final repo = ref.read(trackOpsProvider);
    final pin = _pin.text.trim();
    final saved = <String>[];
    final savedTracks = <String, RemoteTrack>{};
    try {
      for (final t in todo) {
        if (cancel.isCancelled) break;
        await for (final e in client.download(
          target.host,
          target.port,
          pin,
          t,
          out,
          cancel: cancel,
        )) {
          if (!mounted) return;
          setState(() => _fileProgress = e.fraction);
          if (e.path != null) {
            saved.add(e.path!);
            savedTracks[e.path!] = t;
          }
        }
        if (mounted) setState(() => _doneCount++);
      }
      if (saved.isNotEmpty) {
        await ref
            .read(libraryScannerProvider)
            .scanFiles(base.$2, saved)
            .drain<void>();
        for (final entry in savedTracks.entries) {
          await ref.read(shareControllerProvider).applyReceived(
            entry.key,
            entry.value.meta,
            fetchCover: () => client.downloadCover(
                target.host, target.port, pin, entry.value.id),
          );
          final row = await repo.byPath(entry.key);
          if (row != null) afterReceive(read, row.id);
        }
      }
      if (mounted) setState(() => _received = saved.length);
    } on LanException catch (e) {
      AppLog.w('share download failed: $e');
      if (mounted) setState(() => _error = _errorText(e.error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final picked = ref.watch(selectionProvider(_key));
    final l = context.l10n;
    final hub = ref.watch(shareHubProvider);
    final head = <Widget>[
      if (hub.incoming.isNotEmpty) ...[
        Text(
          l.receivedRequests,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final o in hub.incoming) IncomingOfferTile(offer: o),
        const SizedBox(height: 24),
      ],
      Text(l.manualConnection, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      TextField(
        controller: _address,
        enabled: !_busy,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(
          labelText: l.shareAddress,
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _pin,
        enabled: !_busy,
        keyboardType: TextInputType.number,
        maxLength: 6,
        decoration: InputDecoration(
          labelText: l.sharePin,
          border: const OutlineInputBorder(),
        ),
      ),
      if (isAndroid)
        Padding(
          padding: const EdgeInsets.only(bottom: CcDims.gap8),
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _scan,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: Text(l.scanCode),
          ),
        ),
      FilledButton(
        onPressed: _busy ? null : _connect,
        child: Text(l.shareConnect),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: CcDims.gap12),
          child: Text(_error!, style: TextStyle(color: context.cc.error)),
        ),
      if (_remoteName != null) ...[
        const SizedBox(height: 16),
        Text(
          l.shareConnectedTo(_remoteName!),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    ];
    final foot = <Widget>[
      if (_remoteName != null) ...[
        const SizedBox(height: 8),
        if (_busy && _totalCount > 0) ...[
          Text(l.shareProgress(_doneCount + 1, _totalCount)),
          LinearProgressIndicator(value: _fileProgress),
          TextButton(onPressed: () => _cancel?.cancel(), child: Text(l.cancel)),
        ] else
          FilledButton.icon(
            onPressed: !picked.active ? null : _download,
            icon: const Icon(Icons.download),
            label: Text(l.shareDownloadSelected(picked.count)),
          ),
        if (_received != null)
          Padding(
            padding: const EdgeInsets.only(top: CcDims.gap8),
            child: Text(l.shareDone(_received!)),
          ),
      ],
    ];
    final shown = _remoteName == null ? 0 : _tracks.length;
    return ListView.builder(
      padding: const EdgeInsets.all(CcDims.margin).withDock(context),
      itemCount: head.length + shown + foot.length,
      itemBuilder: (_, i) {
        if (i < head.length) return head[i];
        i -= head.length;
        if (i >= shown) return foot[i - shown];
        final t = _tracks[i];
        return CheckboxListTile(
          dense: true,
          value: picked.contains(t.id),
          onChanged: _busy
              ? null
              : (_) => ref.read(selectionProvider(_key).notifier).toggle(t.id),
          title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(t.artist ?? '', maxLines: 1),
        );
      },
    );
  }
}
