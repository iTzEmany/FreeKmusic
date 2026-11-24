import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../services/share/external_share_text.dart';
import '../services/share/share_card_renderer.dart';
import '../services/share/share_fragment.dart' show SharedKind, untitledShare;
import '../ui/theme/cover_tint.dart';
import '../ui/theme/tokens.dart' show CcColors;
import '../ui/widgets/cover_image.dart';
import '../ui/widgets/format_utils.dart' show formatDuration;
import '../ui/widgets/share_card.dart';
import 'settings_providers.dart';

/// The default [ShareCardMaker]: covers and tint from the library, texts in the app's language.
ShareCardMaker shareCardMaker(Ref ref) => (kind, title, subtitle, tracks) async {
  final l = lookupAppLocalizations(Locale(ref.read(settingsProvider).language));
  final keys = {for (final t in tracks) ?t.coverKey}.take(kind == SharedKind.playlist ? 4 : 1).toList();
  final files = <File>[for (final k in keys) ?ref.read(coverFileProvider(k))];
  final tint = keys.isEmpty ? null : await ref.read(coverTintProvider(keys.first).future);
  final base = CcColors.notte.heroBase;
  final ms = tracks.fold<int>(0, (a, t) => a + t.durationMs);
  final time = ms > 0 ? formatDuration(ms) : null;
  final count = l.tracksCount(tracks.length);
  return renderShareCardPng(
    files,
    (images) => ShareCard(
      kind: kind,
      brand: l.appName,
      kindLabel: switch (kind) {
        SharedKind.track => l.shareKindTrack,
        SharedKind.album => l.kindAlbum,
        SharedKind.playlist => l.kindPlaylist,
      },
      title: title.trim().isEmpty ? untitledShare : title,
      subtitle: subtitle,
            meta: kind == SharedKind.track ? (time ?? '') : [count, ?time].join(' ${String.fromCharCode(0xb7)} '),
      tint: tint == null ? base : heroTint(tint, base),
      covers: images,
      qrLink: shareCardLink(kind, title, tracks),
    ),
  );
};
