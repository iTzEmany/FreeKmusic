import 'package:flutter/material.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../services/online/external_collection.dart';
import '../../theme/tokens.dart';

String _line(ExternalTrack t) => [t.title, if (t.artists.isNotEmpty) t.artists.join(', ')].join(', ');

/// A song still being matched: its words and a small indicator.
class PendingRow extends StatelessWidget {
  const PendingRow(this.track, this.index, {super.key});

  final ExternalTrack track;
  final int index;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Semantics(
      label: '${_line(track)}, ${l.extMatching}',
      excludeSemantics: true,
      child: ListTile(
        key: ValueKey('pending-$index'),
        title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(track.artists.join(', '), maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

/// A song with no match: grey, and a tap opens Search with its words (R-196).
class NotFoundRow extends StatelessWidget {
  const NotFoundRow(this.track, this.index, {required this.onSearch, super.key});

  final ExternalTrack track;
  final int index;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final muted = TextStyle(color: context.cc.textMuted);
    return Semantics(
      label: '${_line(track)}, ${l.extNotFoundLabel}',
      button: true,
      excludeSemantics: true,
      onTap: onSearch,
      child: ListTile(
        key: ValueKey('notfound-$index'),
        onTap: onSearch,
        title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
        subtitle: Text(track.artists.join(', '), maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
        trailing: Text(l.extFindByHand,
            style: TextStyle(color: context.cc.accentSoft, decoration: TextDecoration.underline)),
      ),
    );
  }
}
