import 'jam_models.dart';
import 'jam_turns.dart';

/// The one «queue full» rule (D-194, D-264): the seats from the current track on, played
/// tracks excluded, are taken. [reserve] seats stay free (the automatic fill leaves
/// [jamManualSeats] for hand-made adds); [inFlight]: adds sent but not yet in [s].
bool jamQueueFull(JamState s, {int reserve = 0, int inFlight = 0}) =>
    s.items.length + inFlight - (s.currentIndex < 0 ? 0 : s.currentIndex) >= maxJamItems - reserve;

/// Pure reducer for the authoritative Jam state (lives on the host).
///
/// [from] is the device id issuing the command; [nowMs] is the host clock.
/// Rules (docs/fase-8-jam.md): the guest can add, move, play/pause, seek,
/// volume, skip (`next`, `jump`, D-160) and change the output device, but
/// cannot remove the current item nor end the session; each participant removes their own items, the host
/// removes any. An added track goes right after the current one (after earlier
/// adds, before the host's inherited seed); a full queue drops the last
/// inherited track instead of refusing.
JamResult applyCommand(
  JamState s,
  JamCommand cmd, {
  required String from,
  required int nowMs,
}) {
  if (s.ended) return const JamResult.fail(JamError.ended);
  final isHost = from == s.hostDeviceId;
  if (s.speakerAwaySince != null &&
      const {
        JamCommandType.play,
        JamCommandType.seek,
        JamCommandType.next,
        JamCommandType.jump,
        JamCommandType.previous,
      }.contains(cmd.type)) {
    return const JamResult.fail(JamError.noSpeaker);
  }
  final items = [...s.items];

  JamResult commit(JamState n) => JamResult.ok(n.copyWith(version: s.version + 1));

  int indexOf(int? id) => id == null ? -1 : items.indexWhere((i) => i.id == id);

  final together = s.mode == JamMode.together;
  final order = [for (final p in s.participants) p.id];

  /// In together mode the items after the current one take turns (D-187).
  List<JamItem> reordered(List<JamItem> l, int cur) =>
      together ? togetherOrder(l, cur, order) : l;

  /// State with position frozen at "now" so play/pause keep the clock honest.
  JamState frozen() =>
      s.copyWith(positionMs: s.positionAtTime(nowMs), positionAt: nowMs);

  /// When playback resumes: now, or a moment ahead when several devices have
  /// to start together.
  int startAt(JamState n) => n.synced ? nowMs + jamStartLeadMs : nowMs;

  switch (cmd.type) {
    case JamCommandType.add:
      final item = cmd.item!;
      if (item.ownerDeviceId != from) return const JamResult.fail(JamError.forbidden);
      // A fed track sent twice (lost answer, resend) is in the Jam once (invariant 3).
      final pk = item.partKey;
      if (pk != null && items.any((i) => i.ownerDeviceId == from && i.partKey == pk)) {
        return JamResult.ok(s);
      }
      final inherited = isHost && item.inherited;
      final added = item.copyWith(id: s.nextItemId, inherited: inherited);
      final first = s.currentIndex < 0;
      var cur = s.currentIndex;
      if (items.length >= maxJamItems) {
        if (together && !jamQueueFull(s)) {
          // The window slides: the oldest played track makes room (D-194).
          items.removeAt(0);
          cur--;
        } else if (together) {
          return const JamResult.fail(JamError.full); // together never drops an unplayed track
        } else {
          final victim = inherited
              ? -1
              : items.lastIndexWhere((i) => i.inherited, items.length - 1);
          if (victim <= cur) return const JamResult.fail(JamError.full);
          items.removeAt(victim);
        }
      }
      if (first || (inherited && !together)) {
        items.add(added);
      } else if (together) {
        // A fed track (seed or part key) goes to the back of the sender's part,
        // keeping the part's order; any other add to its head. Turns are redone (D-214).
        var p = items.length;
        if (inherited || added.partKey != null) {
          final last = items.lastIndexWhere((i) => i.ownerDeviceId == from);
          if (last > cur) p = last + 1;
        } else {
          final head = items.indexWhere((i) => i.ownerDeviceId == from, cur + 1);
          if (head >= 0) p = head;
        }
        items.insert(p, added);
        items.replaceRange(0, items.length, reordered(items, cur));
      } else {
        var p = cur + 1;
        while (p < items.length && !items[p].inherited) {
          p++;
        }
        items.insert(p, added);
      }
      return commit(s.copyWith(
        items: items,
        nextItemId: s.nextItemId + 1,
        currentIndex: first ? items.length - 1 : cur,
        positionMs: first ? 0 : null,
        positionAt: first ? nowMs : null,
      ));

    case JamCommandType.remove:
      final idx = indexOf(cmd.itemId);
      if (idx < 0) return const JamResult.fail(JamError.notFound);
      if (!isHost && items[idx].ownerDeviceId != from) {
        return const JamResult.fail(JamError.forbidden);
      }
      if (!isHost && idx == s.currentIndex) {
        return const JamResult.fail(JamError.forbidden);
      }
      items.removeAt(idx);
      var cur = s.currentIndex;
      var out = s;
      if (idx < cur) {
        cur -= 1;
      } else if (idx == cur) {
        // Removed the current track: the one that slid into its place plays.
        if (cur >= items.length) cur = items.isEmpty ? -1 : items.length - 1;
        out = s.copyWith(positionMs: 0, positionAt: nowMs, playing: items.isEmpty ? false : s.playing);
      }
      return commit(out.copyWith(items: reordered(items, cur), currentIndex: cur));

    case JamCommandType.move:
      if (together) return const JamResult.fail(JamError.forbidden); // R-103
      final idx = indexOf(cmd.itemId);
      if (idx < 0) return const JamResult.fail(JamError.notFound);
      final to = cmd.toIndex!;
      if (to < 0 || to >= items.length) return const JamResult.fail(JamError.invalid);
      if (to == idx) return JamResult.ok(s);
      final curId = s.current?.id;
      final it = items.removeAt(idx);
      items.insert(to, it);
      // Keep the inherited block contiguous: adopt the neighbour's flag.
      if (items.length > 1) {
        final nb = items[to + 1 < items.length ? to + 1 : to - 1];
        items[to] = it.copyWith(inherited: nb.inherited);
      }
      return commit(s.copyWith(
        items: items,
        currentIndex: curId == null ? -1 : items.indexWhere((i) => i.id == curId),
      ));

    case JamCommandType.play:
      if (s.current == null) return const JamResult.fail(JamError.invalid);
      final started = frozen().copyWith(playing: true);
      return commit(started.copyWith(positionAt: startAt(started)));

    case JamCommandType.pause:
      return commit(frozen().copyWith(playing: false));

    case JamCommandType.seek:
      final p = cmd.positionMs!;
      final dur = s.current?.durationMs ?? 0;
      if (s.current == null || p < 0 || (dur > 0 && p > dur)) {
        return const JamResult.fail(JamError.invalid);
      }
      return commit(s.copyWith(positionMs: p, positionAt: startAt(s)));

    case JamCommandType.volume:
      final v = cmd.volume!;
      if (v.isNaN || v < 0 || v > 1) return const JamResult.fail(JamError.invalid);
      return commit(s.copyWith(volume: v));

    case JamCommandType.setOutput:
      final d = cmd.deviceId!;
      if (s.participant(d)?.remote == true) return const JamResult.fail(JamError.forbidden); // R-157
      // Invariant 4: with a speaker the host is the only output.
      if (s.speaker && d != s.hostDeviceId) {
        return const JamResult.fail(JamError.forbidden);
      }
      // Any participant can be the output. Before a roster exists (tests,
      // old peers) only the host and the sender are accepted.
      final known = s.participants.isEmpty
          ? (d == s.hostDeviceId || d == from || isHost)
          : s.participant(d) != null;
      if (!known) return const JamResult.fail(JamError.invalid);
      if (d == s.outputDeviceId && s.outputDeviceIds.isEmpty) {
        return JamResult.ok(s);
      }
      return commit(
          frozen().copyWith(outputDeviceId: d, outputDeviceIds: const []));

    case JamCommandType.setOutputs:
      final ids = cmd.deviceIds!.toSet().toList();
      if (ids.any((d) => s.participant(d)?.remote == true)) {
        return const JamResult.fail(JamError.forbidden); // R-157
      }
      if (s.speaker && (ids.length != 1 || ids.first != s.hostDeviceId)) {
        return const JamResult.fail(JamError.forbidden);
      }
      final allKnown = s.participants.isEmpty
          ? ids.every((d) => d == s.hostDeviceId || d == from || isHost)
          : ids.every((d) => s.participant(d) != null);
      if (ids.isEmpty || !allKnown) return const JamResult.fail(JamError.invalid);
      final n = frozen().copyWith(
          outputDeviceId: ids.first,
          outputDeviceIds: ids.length == 1 ? const [] : ids);
      // Re-align everybody: the new set starts together a moment from now.
      return commit(n.playing ? n.copyWith(positionAt: startAt(n)) : n);

    case JamCommandType.next:
      return _advance(s, nowMs, commit);

    case JamCommandType.jump:
      final idx = indexOf(cmd.itemId);
      if (idx < 0) return const JamResult.fail(JamError.notFound);
      return commit(s.copyWith(
          items: reordered(items, idx),
          currentIndex: idx, positionMs: 0, positionAt: startAt(s), playing: true));

    case JamCommandType.trackEnded:
      // A late report from the speaker that just went away must not advance a stopped Jam.
      if (s.speakerAwaySince != null) return JamResult.ok(s);
      // Natural end of a track, reported by the output device (either role).
      if (s.current?.id != cmd.itemId) return JamResult.ok(s);
      return _advance(s, nowMs, commit);

    case JamCommandType.previous:
      // The host's own state decides (D-160 rule), never a guest's stale one.
      // Nothing to go back from: a no-op, so `invalid` only means «old host».
      if (s.current == null) return JamResult.ok(s);
      return applyCommand(s, jamPreviousCommand(s, nowMs), from: from, nowMs: nowMs);

    case JamCommandType.setMode:
      if (!isHost) return const JamResult.fail(JamError.forbidden);
      final m = cmd.mode!;
      if (m == s.mode) return JamResult.ok(s);
      // Going back to host mode leaves the items where they are (R-104).
      return commit(s.copyWith(
          mode: m,
          items: m == JamMode.together
              ? togetherOrder(items, s.currentIndex, order)
              : null));

    case JamCommandType.speakerAway:
      if (!s.speaker) return const JamResult.fail(JamError.invalid);
      if (!isHost && !(s.outputs.length == 1 && s.outputs.first == from)) {
        return const JamResult.fail(JamError.forbidden);
      }
      if (s.speakerAwaySince != null) return JamResult.ok(s);
      return commit(frozen().copyWith(
          playing: false,
          speakerAwaySince: nowMs,
          outputDeviceId: s.hostDeviceId,
          outputDeviceIds: const []));

    case JamCommandType.speakerBack:
      if (!isHost) return const JamResult.fail(JamError.forbidden);
      if (!s.speaker) return const JamResult.fail(JamError.invalid);
      if (s.speakerAwaySince == null) return JamResult.ok(s);
      return commit(s.copyWith(clearSpeakerAway: true));

    case JamCommandType.offerSpeaker:
      if (isHost || s.participant(from)?.remote == true) {
        return const JamResult.fail(JamError.forbidden); // R-157: LAN only
      }
      if (!s.speaker || s.speakerAwaySince == null) {
        return const JamResult.fail(JamError.invalid);
      }
      if (s.participants.isNotEmpty && s.participant(from) == null) {
        return const JamResult.fail(JamError.invalid);
      }
      return commit(frozen().copyWith(
          playing: false,
          outputDeviceId: from,
          outputDeviceIds: const [],
          clearSpeakerAway: true));

    case JamCommandType.continueOnPhone:
      if (!isHost) return const JamResult.fail(JamError.forbidden);
      if (s.speakerAwaySince == null) return const JamResult.fail(JamError.invalid);
      return commit(s.copyWith(speaker: false, clearSpeakerAway: true));

    case JamCommandType.end:
      if (!isHost) return const JamResult.fail(JamError.forbidden);
      return JamResult.ok(
          s.copyWith(version: s.version + 1, ended: true, playing: false));
  }
}

JamResult _advance(JamState s, int nowMs, JamResult Function(JamState) commit) {
  final n = s.currentIndex + 1;
  if (n >= s.items.length) {
    // Queue finished: stop on the last item, rewound.
    return commit(s.copyWith(playing: false, positionMs: 0, positionAt: nowMs));
  }
  return commit(s.copyWith(
      currentIndex: n,
      positionMs: 0,
      positionAt: s.synced ? nowMs + jamStartLeadMs : nowMs));
}

/// «Previous» as in the player (D-160): past 3 s, or on the first item, back
/// to the start; within 3 s, a jump to the item before the current one.
JamCommand jamPreviousCommand(JamState s, int nowMs) {
  final i = s.currentIndex;
  if (i <= 0 || i >= s.items.length || s.positionAtTime(nowMs) > 3000) {
    return const JamCommand.seek(0);
  }
  return JamCommand.jump(s.items[i - 1].id);
}
