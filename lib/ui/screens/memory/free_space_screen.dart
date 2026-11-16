import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/free_space_providers.dart';
import '../../../providers/library_providers.dart' show scanStateProvider;
import '../../../services/library/free_space.dart';
import '../../theme/tokens.dart';
import '../../widgets/cc_app_bar.dart';
import '../../widgets/confirm.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/format_utils.dart';
import '../../widgets/show_msg.dart';

/// «Libera spazio» (D-581): the downloads picked here go back to streams and their files are
/// deleted. Nothing is deleted without the confirmation (D-598).
class FreeSpaceScreen extends ConsumerStatefulWidget {
  const FreeSpaceScreen({super.key});

  @override
  ConsumerState<FreeSpaceScreen> createState() => _FreeSpaceScreenState();
}

class _FreeSpaceScreenState extends ConsumerState<FreeSpaceScreen> {
  List<FreeSpaceCandidate>? _items;
  final _sel = <int>{};
  var _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = await ref.read(freeSpaceServiceProvider.future);
    final items = await service.freeSpaceCandidates();
    if (!mounted) return;
    setState(() {
      _items = items;
      _sel
        ..clear()
        ..addAll([for (final c in items) if (c.stale) c.track.id]);
    });
  }

  int _bytes(Iterable<FreeSpaceCandidate> items) => items.fold(0, (s, c) => s + c.sizeBytes);

  Future<void> _free() async {
    final l = context.l10n;
    final ok = await showConfirm(
      context,
      title: l.freeSpaceConfirmTitle,
      body: l.freeSpaceConfirmBody(_sel.length),
      confirmLabel: l.freeSpaceTitle,
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _working = true);
    final service = await ref.read(freeSpaceServiceProvider.future);
    final r = await service.freeSpace(_sel.toList());
    if (!mounted) return;
    setState(() => _working = false);
    final locale = l.localeName;
    showMsg(
      context,
      [
        if (r.freedIds.isNotEmpty) l.freeSpaceDone(r.freedIds.length, formatBytes(r.freedBytes, locale)),
        if (r.failedIds.isNotEmpty) l.freeSpaceFailed(r.failedIds.length),
      ].join(' '),
    );
    await _load();
  }

  Widget _tile(FreeSpaceCandidate c, String locale) => CheckboxListTile(
    value: _sel.contains(c.track.id),
    onChanged: (v) => setState(() => v == true ? _sel.add(c.track.id) : _sel.remove(c.track.id)),
    title: Text(c.track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: (c.track.artist ?? '').isEmpty ? null : Text(c.track.artist!, maxLines: 1, overflow: TextOverflow.ellipsis),
    secondary: Text(formatBytes(c.sizeBytes, locale)),
  );

  Widget _header(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: context.cc.textMuted)),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = l.localeName;
    final items = _items;
    final scanning = ref.watch(scanStateProvider.select((s) => s.running));
    final stale = [for (final c in items ?? const <FreeSpaceCandidate>[]) if (c.stale) c];
    final rest = [for (final c in items ?? const <FreeSpaceCandidate>[]) if (!c.stale) c];
    final picked = [for (final c in items ?? const <FreeSpaceCandidate>[]) if (_sel.contains(c.track.id)) c];
    final all = items != null && items.isNotEmpty && _sel.length == items.length;
    return Scaffold(
      appBar: CcAppBar(title: l.freeSpaceTitle),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? EmptyState(icon: Icons.check_circle_outline, message: l.freeSpaceEmpty)
          : ListView(
              padding: EdgeInsets.zero.withDock(context),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l.freeSpaceIntro),
                ),
                if (scanning)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(l.freeSpaceBusy, style: TextStyle(color: context.cc.error)),
                  ),
                if (stale.isNotEmpty) _header(l.freeSpaceStale),
                for (final c in stale) _tile(c, locale),
                if (rest.isNotEmpty && stale.isNotEmpty) _header(l.freeSpaceOthers),
                for (final c in rest) _tile(c, locale),
                CheckboxListTile(
                  value: all,
                  onChanged: (v) => setState(() {
                    _sel.clear();
                    if (v == true) _sel.addAll([for (final c in items) c.track.id]);
                  }),
                  title: Text(l.freeSpaceAll(items.length, formatBytes(_bytes(items), locale))),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: _sel.isEmpty || scanning || _working ? null : _free,
                    child: Text(l.freeSpaceButton(formatBytes(_bytes(picked), locale))),
                  ),
                ),
              ],
            ),
    );
  }
}
