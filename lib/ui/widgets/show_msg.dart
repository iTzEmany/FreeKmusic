import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/l10n_ext.dart';
import '../../services/jam/jam_models.dart' show JamAddResult;
import '../theme/tokens.dart';

/// The one snackbar: replaces the current one and the queue, fixed duration.
/// [persist] keeps an action snackbar longer ([CcTiming.msgLong]); none stays forever (D-541). Safe after an `await` (does nothing if [context] is gone).
void showMsg(
  BuildContext context,
  String text, {
  SnackBarAction? action,
  bool persist = false,
}) {
  if (!context.mounted) return;
  showMsgOn(
    ScaffoldMessenger.of(context),
    text,
    action: action,
    persist: persist,
  );
}

/// The confirmation of a queue add. [r] is what a Jam did with [wanted] tracks (null: no Jam,
/// all went in); a full Jam says so instead of confirming (D-194), any other failure says it failed.
void showQueued(
  BuildContext context,
  JamAddResult? r, {
  int wanted = 1,
  String? ok,
}) {
  if (!context.mounted) return;
  final l = context.l10n;
  final added = r?.added;
  showMsg(
    context,
    added == null || added >= wanted
        ? ok ?? l.addedToQueue
        : added > 0
        ? l.jamAdded(added)
        : r!.full
        ? l.jamFull
        : l.jamAddFailed,
  );
}

/// Same as [showMsg] with a messenger captured earlier: for messages shown
/// after the dialog or sheet that owned the context has closed.
void showMsgOn(
  ScaffoldMessengerState messenger,
  String text, {
  SnackBarAction? action,
  bool persist = false,
  Duration? duration,
}) {
  final d =
      duration ??
      (action == null
          ? CcTiming.msg
          : persist
          ? CcTiming.msgLong
          : CcTiming.msgAction);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: CcSnackContent(text, d),
      action: action,
      // Never Flutter's persist: every snackbar times out (D-541). With TalkBack on,
      // Flutter itself still keeps one with an action until it is used.
      persist: false,
      duration: d,
    ),
  );
}

const _ringSize = 18.0;
const _snackEnter = Duration(
  milliseconds: 250,
); // Flutter's snackbar entrance: its timer starts after it

/// A snackbar's text with the countdown at its end: a thin accent ring that empties
/// clockwise over [duration], with a dot trailing its moving end at a small gap (the «pallino», like the
/// tab dot). Same [duration] as the SnackBar. Not read by TalkBack; with animations
/// off the ring stays full.
class CcSnackContent extends StatelessWidget {
  const CcSnackContent(this.text, this.duration, {super.key});
  final String text;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final color = context.cc.accent;
    final ring = MediaQuery.disableAnimationsOf(context)
        ? CustomPaint(painter: _RingPainter(1, color))
        : TweenAnimationBuilder<double>(
            tween: Tween(begin: 1, end: 0),
            duration: duration + _snackEnter,
            curve: Interval(
              _snackEnter.inMilliseconds /
                  (duration + _snackEnter).inMilliseconds,
              1,
            ),
            builder: (_, t, _) => CustomPaint(painter: _RingPainter(t, color)),
          );
    return Row(
      children: [
        Expanded(child: Text(text)),
        const SizedBox(width: 12),
        ExcludeSemantics(
          child: SizedBox(
            key: const ValueKey('snack-ring'),
            width: _ringSize,
            height: _ringSize,
            child: ring,
          ),
        ),
      ],
    );
  }
}

/// [left] (1 → 0) is the part of the ring still to go; it ends at the top, the dot sits at its start.
class _RingPainter extends CustomPainter {
  _RingPainter(this.left, this.color);
  final double left;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 2.0;
    final c = size.center(Offset.zero);
    final r = (size.width - 3) / 2;
    final start = -math.pi / 2 + 2 * math.pi * (1 - left);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      start,
      2 * math.pi * left,
      false,
      paint,
    );
    if (left > 0) {
      // The dot trails the ring's moving end on the emptied part, with a clear gap (D-541).
      const dotR = 2.5, gap = 2.0;
      final a = start - (stroke / 2 + gap + dotR) / r;
      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * r,
        dotR,
        paint..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.left != left || o.color != color;
}
