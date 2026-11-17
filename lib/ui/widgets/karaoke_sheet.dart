import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_log.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/jam_providers.dart';
import '../../providers/karaoke_providers.dart';
import '../../providers/player_providers.dart';
import '../../services/jam/jam_models.dart';
import '../../services/karaoke/karaoke_send_throttle.dart';
import '../../services/karaoke/separation_service.dart';
import '../theme/tokens.dart';
import 'cc_sheet.dart';
import '../screens/lyrics/lyrics_screen.dart';

/// The microphone of «In riproduzione» (D-584): absent where the backend has no
/// voice filter (macOS, iOS, Windows); opens [showKaraokeSheet].
class KaraokeButton extends ConsumerWidget {
  const KaraokeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(karaokeButtonVisibleProvider)) return const SizedBox.shrink();
    final jam = ref.watch(jamKaraokeProvider);
    // Bypassed (episode, radio): the filter does nothing, so the mic looks off.
    final on = jam != null
        ? jam.on
        : ref.watch(karaokeProvider.select((k) => k.on)) && !ref.watch(karaokeBypassProvider);
    // A guest without the host's permission: off, and the reason is the tooltip.
    final enabled = jam?.canCommand ?? true;
    final name = enabled ? context.l10n.karaoke : context.l10n.karaokeJamHostOnly;
    final cc = context.cc;
    // One node: the state is toggled, the name stays «Karaoke».
    return Semantics(
      button: true,
      excludeSemantics: true,
      enabled: enabled,
      toggled: on,
      label: name,
      onTap: enabled ? () => showKaraokeSheet(context) : null,
      child: IconButton(
        visualDensity: VisualDensity.compact, // next to the sleep chip
        tooltip: name,
        onPressed: enabled ? () => showKaraokeSheet(context) : null,
        icon: Icon(
          on ? Icons.mic_rounded : Icons.mic_none_rounded,
          color: on ? cc.accent : cc.textMuted,
        ),
      ),
    );
  }
}

/// Switch and «Voce» slider. Turning karaoke on opens the lyrics page when the
/// track has synced lyrics, unless [openLyrics] is false (already there).
Future<void> showKaraokeSheet(BuildContext context, {bool openLyrics = true}) =>
    showCcSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            CcDims.margin,
            0,
            CcDims.margin,
            CcDims.margin,
          ),
          child: _KaraokePanel(openLyrics: openLyrics),
        ),
      ),
    );

class _KaraokePanel extends ConsumerStatefulWidget {
  const _KaraokePanel({required this.openLyrics});

  final bool openLyrics;

  @override
  ConsumerState<_KaraokePanel> createState() => _KaraokePanelState();
}

class _KaraokePanelState extends ConsumerState<_KaraokePanel> {
  // In a Jam the level comes back from the host with a delay: the thumb stays where the finger left
  // it until the host's state has the same level (or the Jam refuses it).
  double? _drag;
  bool _dragging = false;
  // Read once: dispose() flushes a pending send after the ref is gone.
  late final JamController _jam;
  late final ProviderContainer _container;
  late ScaffoldMessengerState _messenger;
  late String _forbiddenText;
  late final _send = KaraokeSendThrottle(_sendLevel);

  @override
  void initState() {
    super.initState();
    _jam = ref.read(jamProvider.notifier);
    _container = ProviderScope.containerOf(context, listen: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.of(context);
    _forbiddenText = context.l10n.karaokeJamForbidden;
  }

  void _sendJam(double? level) {
    _jam.send(JamCommand.karaoke(level)).then((e) {
      if (e == null) return;
      AppLog.d('karaoke: the Jam refused the level ($e)');
      if (mounted) setState(() => _drag = null);
      if (e == JamError.forbidden && _messenger.mounted) {
        _messenger.showSnackBar(SnackBar(content: Text(_forbiddenText)));
      }
    });
  }

  // A drag in flight must not turn back on a karaoke somebody else just switched off.
  void _sendLevel(double? level) {
    if (_container.read(jamKaraokeProvider)?.on == true) _sendJam(level);
  }

  @override
  void dispose() {
    _send.flush();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = ref.watch(karaokeProvider);
    final jam = ref.watch(jamKaraokeProvider);
    final bypass = jam == null && ref.watch(karaokeBypassProvider);
    final on = jam != null ? jam.on : k.on;
    final enabled = jam?.canCommand ?? true;
    // Jam karaoke off: the slider is disabled and shows this device's own level, which the switch sends.
    final level = _drag ?? (jam?.level ?? k.level);
    final percent = (level * 100).round();
    ref.listen(jamKaraokeProvider.select((j) => j?.level), (_, next) {
      final d = _drag;
      if (!_dragging && d != null && (next == null || (next - d).abs() < 0.01)) setState(() => _drag = null);
    });
    // «Alta qualità» (D-622): Android only, not in a Jam.
    final target = ref.watch(karaokeTargetProvider).value;
    final sep = ref.watch(separationStateProvider);
    final base = ref.watch(karaokeBaseProvider).value;
    final useBase = ref.watch(karaokeUseBaseProvider);
    final highQuality = ref.watch(separationServiceProvider) != null && jam == null && on && target != null;
    final baseReady = highQuality && base?.path != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (bypass)
          Text(
            l.karaokeBypassed,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.cc.textMuted),
          ),
        if (!enabled)
          Text(
            l.karaokeJamHostOnly,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.cc.textMuted),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.karaoke),
          value: on,
          onChanged: !enabled
              ? null
              : (v) {
                  if (jam != null) {
                    _sendJam(v ? level : null);
                    return;
                  }
                  setKaraokeOn(ref, v);
                  final track = ref.read(currentShadowRowProvider) ??
                      ref.read(liveCurrentTrackProvider).value;
                  if (v && widget.openLyrics && track?.lyricsSynced != null) {
                    final nav = Navigator.of(context, rootNavigator: true);
                    Navigator.of(context).pop();
                    nav.push(MaterialPageRoute<void>(builder: (_) => const LyricsScreen()));
                  }
                },
        ),
        if (highQuality) _HighQualityRow(base: base, target: target, sep: sep),
        if (baseReady)
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: true, label: Text(l.karaokeBase)),
              ButtonSegment(value: false, label: Text(l.karaokeOriginal)),
            ],
            selected: {useBase},
            onSelectionChanged: (v) => ref.read(karaokeUseBaseProvider.notifier).set(v.first),
          ),
        // Base chosen: the voice filter is bypassed, so its level has no meaning.
        if (!baseReady || !useBase) Row(
          children: [
            ExcludeSemantics(child: Text(l.karaokeVoice)),
            Expanded(
              child: Semantics(
                label: l.karaokeVoice,
                child: Slider(
                  value: level,
                  divisions: 20,
                  semanticFormatterCallback: (v) => l.karaokePercent((v * 100).round()),
                  onChanged: !enabled || (jam != null && !jam.on)
                      ? null
                      : (v) {
                          if (jam == null) return setKaraokeLevel(ref, v);
                          setState(() {
                            _drag = v;
                            _dragging = true;
                          });
                          _send.add(v);
                        },
                  onChangeEnd: (_) {
                    _dragging = false;
                    _send.flush();
                  },
                ),
              ),
            ),
            ExcludeSemantics(child: Text(l.karaokePercent(percent))),
          ],
        ),
      ],
    );
  }
}

/// «Alta qualità»: starts the separation of the current track and shows its progress.
/// Nothing while the backing track exists (the Base / Originale choice takes over).
class _HighQualityRow extends ConsumerWidget {
  const _HighQualityRow({required this.base, required this.target, required this.sep});

  final KaraokeBase? base;
  final KaraokeTarget? target;
  final SeparationState sep;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = this.target;
    if (target == null || base?.path != null) return const SizedBox.shrink();
    final l = context.l10n;
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(color: context.cc.textMuted);
    final running = sep.phase == SeparationPhase.model || sep.phase == SeparationPhase.separating;
    if (running) {
      final model = sep.phase == SeparationPhase.model;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(l.karaokeHighQuality)),
                Text(
                  '${model ? l.karaokeHighQualityModel : l.karaokeHighQualitySeparating} '
                  '${l.karaokePercent((sep.fraction * 100).round())}',
                  style: muted,
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: sep.fraction > 0 ? sep.fraction : null),
            const SizedBox(height: 6),
            Text(l.karaokeHighQualityNote, style: muted),
          ],
        ),
      );
    }
    final input = target.input;
    final failed = sep.phase == SeparationPhase.failed;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(l.karaokeHighQuality),
      subtitle: Text(
        input == null
            ? l.karaokeHighQualityWaiting
            : failed
                ? l.karaokeHighQualityFailed
                : l.karaokeHighQualityNote,
      ),
      enabled: input != null,
      onTap: input == null
          ? null
          : () => unawaited(ref.read(separationServiceProvider)!.request(target.key, input)),
    );
  }
}
