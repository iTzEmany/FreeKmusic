import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/share_hub.dart';
import '../../../services/share/offers.dart';

/// Asks the user whether to accept files offered by a nearby device.
class IncomingOfferDialog extends ConsumerWidget {
  const IncomingOfferDialog({super.key, required this.offer});

  final IncomingOffer offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final hub = ref.read(shareHubProvider.notifier);
    final mb = (offer.totalBytes / 1048576).toStringAsFixed(1);
    final shown = offer.items.take(5).toList();
    return AlertDialog(
      title: Text(offer.trusted ? l.incomingTrustedTitle(offer.fromName) : l.incomingTitle(offer.fromName)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (offer.playlist != null) Text(l.incomingPlaylist(offer.playlist!.name)),
          if (offer.items.isNotEmpty) Text(l.incomingBody(offer.items.length, mb)),
          if (offer.streams.isNotEmpty) Text(l.incomingStreams(offer.streams.length)),
          const SizedBox(height: 8),
          for (final it in shown)
            Text(
              it.artist == null ? it.title : '${it.artist} – ${it.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (offer.items.length > shown.length)
            Text('…', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            hub.decline(offer);
            Navigator.of(context).pop();
          },
          child: Text(l.decline),
        ),
        FilledButton(
          onPressed: () {
            hub.accept(offer);
            Navigator.of(context).pop();
          },
          child: Text(l.accept),
        ),
      ],
    );
  }
}
