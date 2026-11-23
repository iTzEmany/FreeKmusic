import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart' show Track;
import '../../l10n/l10n_ext.dart';
import '../../providers/external_share_actions.dart';
import '../../services/share/share_fragment.dart' show SharedKind;
import 'show_msg.dart';

/// «Condividi»: the system sheet, or, when it is not there, the text on the clipboard and a message saying so.
Future<void> shareTracks(
  BuildContext context,
  WidgetRef ref,
  SharedKind kind,
  String title,
  List<Track> tracks, {
  String? subtitle,
  Rect? origin,
}) async {
  final copied = await ref
      .read(externalShareActionsProvider)
      .share(kind, title, tracks, subtitle: subtitle, origin: origin);
  if (copied && context.mounted) showMsg(context, context.l10n.shareCopied);
}
