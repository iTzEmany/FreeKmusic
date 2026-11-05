import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_ext.dart';
import '../../services/online/artist_link_resolver.dart';
import '../../services/online/credit_roles.dart';
import '../../services/online/credits.dart';
import '../theme/tokens.dart';
import 'artist_link_open.dart';

const _maxRows = 8;

/// Details and credits of a track: presentation only (the data comes from the
/// caller). Every name opens the artist page, like `ArtistLinks`.
class CreditsSection extends ConsumerStatefulWidget {
  const CreditsSection(this.credits, this.details, {super.key});

  final List<TrackCredit> credits;
  final TrackDetails? details;

  /// Whether there is anything to show.
  static bool hasContent(List<TrackCredit> credits, TrackDetails? details) =>
      credits.isNotEmpty ||
      (details != null && detailLines(null, details).isNotEmpty);

  @override
  ConsumerState<CreditsSection> createState() => _CreditsSectionState();
}

/// The short detail lines; with a null [l] only their presence is meaningful.
List<String> detailLines(AppLocalizations? l, TrackDetails d) {
  String join(List<String?> parts) =>
      parts.whereType<String>().where((s) => s.isNotEmpty).join(', ');
  String? kind(String? k) => switch (k) {
    null || '' => null,
    'album' => l?.kindAlbum ?? k,
    'single' => l?.creditsKindSingle ?? k,
    'ep' => l?.creditsKindEp ?? k,
    _ => k,
  };
  return [
    join([
      if (d.bpm != null) '${d.bpm!.round()} ${l?.creditsBpm ?? ''}',
      d.label == null || d.label!.isEmpty
          ? null
          : '${l?.creditsLabel ?? ''}: ${d.label}',
      d.copyright,
    ]),
    join([
      d.digitalReleaseDate == null
          ? null
          : '${l?.creditsDigitalRelease ?? ''}: ${d.digitalReleaseDate}',
      d.physicalReleaseDate == null
          ? null
          : '${l?.creditsPhysicalRelease ?? ''}: ${d.physicalReleaseDate}',
      kind(d.recordType),
    ]),
    join([
      if (d.rank != null) '${l?.creditsRank ?? ''}: ${d.rank}',
      if (d.albumFans != null) '${l?.creditsAlbumFans ?? ''}: ${d.albumFans}',
    ]),
    if (d.explicit == true) l?.creditsExplicit ?? 'explicit',
  ].where((s) => s.isNotEmpty).toList();
}

/// One person, all the roles they have.
typedef _Row = ({String name, List<String> roles, CreditGroup group});

List<_Row> _rows(List<TrackCredit> credits) {
  final byKey = <String, ({String name, List<String> roles})>{};
  for (final c in credits) {
    final e = byKey.putIfAbsent(
      c.nameKey,
      () => (name: c.name, roles: <String>[]),
    );
    if (!e.roles.contains(c.role)) e.roles.add(c.role);
  }
  final rows = [
    for (final e in byKey.values)
      (name: e.name, roles: e.roles, group: creditGroup(e.roles.first)),
  ];
  // Stable: names keep their order inside a group.
  return [
    for (final g in CreditGroup.values) ...rows.where((r) => r.group == g),
  ];
}

class _CreditsSectionState extends ConsumerState<CreditsSection> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final muted = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: cc.textMuted);
    final rows = _rows(widget.credits);
    final shown = _all ? rows : rows.take(_maxRows).toList();
    final lines = widget.details == null
        ? const <String>[]
        : detailLines(l, widget.details!);
    CreditGroup? last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(s, style: muted),
          ),
        for (final r in shown) ...[
          if (r.group != last)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                creditGroupTitle(l, last = r.group),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          _NameRow(r),
        ],
        if (rows.length > _maxRows && !_all)
          TextButton(
            onPressed: () => setState(() => _all = true),
            child: Text(l.creditsShowAll),
          ),
      ],
    );
  }
}

class _NameRow extends ConsumerWidget {
  const _NameRow(this.row);

  final _Row row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final roles = row.roles.map((r) => creditRoleLabel(l, r)).join(', ');
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: '${l.creditsOpenArtist(row.name)}, $roles',
      onTap: () => openArtistLink(context, ref, ArtistName(row.name)),
      child: InkWell(
        onTap: () => openArtistLink(context, ref, ArtistName(row.name)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  roles,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: context.cc.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
