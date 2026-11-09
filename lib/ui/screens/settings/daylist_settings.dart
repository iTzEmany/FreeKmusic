import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/artist_key.dart' show matchKey;
import '../../../l10n/l10n_ext.dart';
import '../../../providers/daylist_providers.dart';
import '../../../services/daylist/daylist_slots.dart';
import '../../../services/daylist/mood_table.dart';
import '../../shell/shell_nav.dart';
import '../../theme/tokens.dart';
import '../../widgets/cc_app_bar.dart';
import '../../widgets/confirm.dart';
import '../daylist/daylist_labels.dart';

String _summary(BuildContext context, DaylistSlot s) => s.enabled
    ? context.l10n.daylistSlotSummary(
        s.prefer.take(3).map(genreDisplay).join(', '),
        s.sharePercent,
      )
    : context.l10n.daylistSlotOff;

/// Settings > Daylist: intro and the 8 slots (tap opens the editor, the
/// switch turns the slot on or off).
class DaylistSlotsTiles extends ConsumerWidget {
  const DaylistSlotsTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final text = Theme.of(context).textTheme;
    final cfg = ref.watch(daylistConfigProvider);
    final now = ref.watch(daylistProvider).value;
    return Column(
      children: [
        ListTile(
          title: Text(
            l.daylistIntro,
            style: text.bodyMedium?.copyWith(color: cc.textMuted),
          ),
        ),
        for (var i = 0; i < DaylistConfig.slotCount; i++)
          _slotRow(
            context,
            ref,
            cfg,
            i,
            warn: now != null && now.slotIndex == i && now.result.tooFew,
          ),
      ],
    );
  }

  Widget _slotRow(
    BuildContext context,
    WidgetRef ref,
    DaylistConfig cfg,
    int i, {
    required bool warn,
  }) {
    final l = context.l10n;
    final cc = context.cc;
    final text = Theme.of(context).textTheme;
    final s = cfg.slots[i];
    final name = daylistSlotName(l, i);
    final time = daylistHour(s.startHour);
    void open() => ShellNav.open<void>(context, DaylistSlotEditor(i));
    final short = warn && s.enabled;
    final label = l.daylistSlotRowLabel(name, _summary(context, s), time);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            excludeSemantics: true,
            label: short ? '$label, ${l.daylistTooFewWarn}' : label,
            onTap: open,
            child: InkWell(
              key: ValueKey('daylist-slot-$i'),
              onTap: open,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CcDims.margin,
                    vertical: CcDims.gap8,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(
                          time,
                          style: text.titleSmall?.copyWith(
                            color: cc.accentSoft,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: text.bodyLarge),
                            Text(
                              _summary(context, s),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall?.copyWith(
                                color: cc.textMuted,
                              ),
                            ),
                            // D-473: the slot of the moment, when it has too few songs.
                            if (short)
                              Text(
                                l.daylistTooFewWarn,
                                style: text.bodySmall?.copyWith(
                                  color: cc.error,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: CcDims.gap12),
          child: Semantics(
            label: s.enabled
                ? l.daylistSwitchOn(name)
                : l.daylistSwitchOff(name),
            child: Switch(
              key: ValueKey('daylist-switch-$i'),
              value: s.enabled,
              onChanged: (v) => ref
                  .read(daylistConfigProvider.notifier)
                  .setSlot(i, s.copyWith(enabled: v)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Genre-to-mood entry and the reset of everything (with a confirmation).
class DaylistExtraTiles extends ConsumerWidget {
  const DaylistExtraTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    return Column(
      children: [
        ListTile(
          title: Text(l.daylistMoodTable),
          subtitle: Text(l.daylistMoodTableSub),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () =>
              ShellNav.open<void>(context, const DaylistMoodTableScreen()),
        ),
        ListTile(
          leading: Icon(Icons.restart_alt_rounded, color: cc.error),
          title: Text(l.daylistResetAll, style: TextStyle(color: cc.error)),
          onTap: () async {
            final ok = await showConfirm(
              context,
              title: l.daylistResetTitle,
              body: l.daylistResetBody,
              confirmLabel: l.daylistResetGo,
              destructive: true,
            );
            if (!ok) return;
            ref.read(daylistConfigProvider.notifier).reset();
            ref.read(moodTableProvider.notifier).reset();
          },
        ),
      ],
    );
  }
}

/// One slot: switch, start hour (1 h steps within [DaylistConfig.canStart]),
/// genres to prefer or avoid, moods, share of suggestions, reset of the slot.
class DaylistSlotEditor extends ConsumerStatefulWidget {
  const DaylistSlotEditor(this.index, {super.key});

  final int index;

  @override
  ConsumerState<DaylistSlotEditor> createState() => _DaylistSlotEditorState();
}

class _DaylistSlotEditorState extends ConsumerState<DaylistSlotEditor> {
  /// Which genre picker is open: 'prefer', 'avoid' or null.
  String? _picker;

  /// The share while the slider is dragged; written on release.
  double? _share;

  int get _i => widget.index;

  void _set(DaylistSlot s) =>
      ref.read(daylistConfigProvider.notifier).setSlot(_i, s);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final text = Theme.of(context).textTheme;
    final cfg = ref.watch(daylistConfigProvider);
    final table = ref.watch(moodTableProvider);
    final s = cfg.slots[_i];
    final end = cfg.slots[(_i + 1) % DaylistConfig.slotCount].startHour;
    final share = _share ?? s.sharePercent.toDouble();
    final suggested = (50 * share / 100).round();
    void move(int by) {
      final h = (s.startHour + by + 24) % 24;
      if (cfg.canStart(_i, h)) {
        ref.read(daylistConfigProvider.notifier).setStart(_i, h);
      }
    }

    Widget group(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(
        CcDims.margin,
        20,
        CcDims.margin,
        CcDims.gap8,
      ),
      child: Text(title, style: text.titleMedium),
    );

    Widget genres({required bool prefer}) {
      final chosen = prefer ? s.prefer : s.avoid;
      final key = prefer ? 'prefer' : 'avoid';
      final taken = {
        for (final g in {...s.prefer, ...s.avoid}) matchKey(g),
      };
      final pool = [
        for (final g in table.genres)
          if (!taken.contains(matchKey(g))) g,
      ];
      void update(Set<String> v) =>
          _set(prefer ? s.copyWith(prefer: v) : s.copyWith(avoid: v));
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final g in chosen)
                  Semantics(
                    button: true,
                    excludeSemantics: true,
                    label: prefer
                        ? l.daylistRemovePrefer(genreDisplay(g))
                        : l.daylistRemoveAvoid(genreDisplay(g)),
                    onTap: () => update({...chosen}..remove(g)),
                    child: ActionChip(
                      key: ValueKey('daylist-$key-$g'),
                      label: Text(genreDisplay(g)),
                      avatar: const Icon(Icons.close_rounded, size: 16),
                      side: prefer ? null : BorderSide(color: cc.error),
                      onPressed: () => update({...chosen}..remove(g)),
                    ),
                  ),
                Semantics(
                  button: true,
                  excludeSemantics: true,
                  label: prefer ? l.daylistAddPrefer : l.daylistAddAvoid,
                  onTap: () =>
                      setState(() => _picker = _picker == key ? null : key),
                  child: ActionChip(
                    key: ValueKey('daylist-add-$key'),
                    label: Text(l.daylistAdd),
                    avatar: const Icon(Icons.add_rounded, size: 16),
                    onPressed: () =>
                        setState(() => _picker = _picker == key ? null : key),
                  ),
                ),
              ],
            ),
            if (_picker == key)
              Padding(
                padding: const EdgeInsets.only(top: CcDims.gap8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final g in pool)
                      Semantics(
                        button: true,
                        excludeSemantics: true,
                        label: l.daylistAddNamed(genreDisplay(g)),
                        onTap: () {
                          update({...chosen, g});
                          setState(() => _picker = null);
                        },
                        child: ActionChip(
                          key: ValueKey('daylist-pick-$g'),
                          label: Text(genreDisplay(g)),
                          onPressed: () {
                            update({...chosen, g});
                            setState(() => _picker = null);
                          },
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: CcAppBar(title: daylistSlotName(l, _i)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: CcDims.gap24).withDock(context),
        children: [
          SwitchListTile(
            key: const ValueKey('daylist-editor-switch'),
            title: Text(l.daylistSlotSwitch),
            subtitle: Text(
              s.enabled
                  ? l.daylistRegenAt(daylistHour(s.startHour))
                  : l.daylistNoCard,
            ),
            value: s.enabled,
            onChanged: (v) => _set(s.copyWith(enabled: v)),
          ),
          ListTile(
            title: Text(l.daylistStartsAt),
            subtitle: Text(l.daylistEndsAt(daylistHour(end))),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const ValueKey('daylist-earlier'),
                  tooltip: l.daylistEarlier,
                  icon: const Icon(Icons.remove_rounded),
                  onPressed: cfg.canStart(_i, (s.startHour + 23) % 24)
                      ? () => move(-1)
                      : null,
                ),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    daylistHour(s.startHour),
                    style: text.titleMedium,
                  ),
                ),
                IconButton(
                  key: const ValueKey('daylist-later'),
                  tooltip: l.daylistLater,
                  icon: const Icon(Icons.add_rounded),
                  onPressed: cfg.canStart(_i, (s.startHour + 1) % 24)
                      ? () => move(1)
                      : null,
                ),
              ],
            ),
          ),
          group(l.daylistPrefer),
          genres(prefer: true),
          group(l.daylistAvoid),
          genres(prefer: false),
          group(l.daylistMoods),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final m in Mood.values)
                  FilterChip(
                    key: ValueKey('daylist-mood-${m.name}'),
                    label: Text(daylistMoodName(l, m)),
                    selected: s.moods.contains(m),
                    onSelected: (v) => _set(
                      s.copyWith(
                        moods: v ? {...s.moods, m} : ({...s.moods}..remove(m)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          group(l.daylistShare),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text(l.daylistShareFrom)),
                    Text('${share.round()}%', style: text.titleMedium),
                  ],
                ),
                Slider(
                  key: const ValueKey('daylist-share'),
                  semanticFormatterCallback: (v) => '${v.round()}%',
                  min: 0,
                  max: 100,
                  divisions: 20,
                  value: share,
                  label: '${share.round()}%',
                  onChanged: (v) => setState(() => _share = v),
                  onChangeEnd: (v) {
                    _set(s.copyWith(sharePercent: v.round()));
                    setState(() => _share = null);
                  },
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l.daylistShareSplit(50 - suggested, suggested),
                    style: text.bodySmall?.copyWith(color: cc.textMuted),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(CcDims.gap8, CcDims.gap8, 0, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const ValueKey('daylist-reset-slot'),
                onPressed: () {
                  final d = DaylistConfig.defaults().slots[_i];
                  _set(
                    d.copyWith(
                      startHour: cfg.canStart(_i, d.startHour)
                          ? d.startHour
                          : s.startHour,
                    ),
                  );
                },
                child: Text(l.daylistResetSlot),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Genre to mood table with a search; a tap on a mood adds or removes it.
class DaylistMoodTableScreen extends ConsumerStatefulWidget {
  const DaylistMoodTableScreen({super.key});

  @override
  ConsumerState<DaylistMoodTableScreen> createState() =>
      _DaylistMoodTableScreenState();
}

class _DaylistMoodTableScreenState
    extends ConsumerState<DaylistMoodTableScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final text = Theme.of(context).textTheme;
    final table = ref.watch(moodTableProvider);
    final all = table.genres;
    final q = matchKey(_q);
    final shown = [
      for (final g in all)
        if (g.contains(q)) g,
    ];
    return Scaffold(
      appBar: CcAppBar(title: l.daylistMoodTable),
      body: ListView(
        padding: const EdgeInsets.only(bottom: CcDims.gap24).withDock(context),
        children: [
          Padding(
            padding: const EdgeInsets.all(CcDims.margin),
            child: Text(
              l.daylistMoodHelp,
              style: text.bodyMedium?.copyWith(color: cc.textMuted),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
            child: TextField(
              key: const ValueKey('daylist-genre-search'),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: l.daylistGenreSearch,
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CcDims.margin,
              CcDims.gap8,
              CcDims.margin,
              CcDims.gap4,
            ),
            child: Text(
              l.daylistGenreCount(shown.length, all.length),
              style: text.bodySmall?.copyWith(color: cc.textMuted),
            ),
          ),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.all(CcDims.margin),
              child: Text(
                l.daylistNoGenre(_q.trim()),
                style: text.bodyMedium?.copyWith(color: cc.textMuted),
              ),
            ),
          for (final g in shown) _genreBox(context, g, table.moodsOf(g)),
        ],
      ),
    );
  }

  Widget _genreBox(BuildContext context, String g, Set<Mood> moods) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CcDims.margin,
        vertical: CcDims.gap8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(genreDisplay(g), style: text.titleSmall)),
              Text(
                moods.isEmpty
                    ? l.daylistNoMood
                    : l.daylistMoodCount(moods.length),
                style: text.bodySmall?.copyWith(color: context.cc.textMuted),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final m in Mood.values)
                Semantics(
                  label: l.daylistGenreMoodLabel(
                    genreDisplay(g),
                    daylistMoodName(l, m),
                  ),
                  excludeSemantics: true,
                  child: FilterChip(
                    key: ValueKey('daylist-genre-$g-${m.name}'),
                    label: Text(daylistMoodName(l, m)),
                    selected: moods.contains(m),
                    onSelected: (v) => ref
                        .read(moodTableProvider.notifier)
                        .setMoods(
                          g,
                          v ? {...moods, m} : ({...moods}..remove(m)),
                        ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
