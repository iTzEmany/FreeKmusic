import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/share_hub.dart';
import '../../../services/share/offers.dart';
import 'offer_status_label.dart';

class IncomingOfferTile extends ConsumerWidget {
  const IncomingOfferTile({super.key, required this.offer});

  final IncomingOffer offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final hub = ref.read(shareHubProvider.notifier);
    final mb = (offer.totalBytes / 1048576).toStringAsFixed(1);
    final pending = offer.status == OfferStatus.pending;
    final accepted = offer.status == OfferStatus.accepted;
    return ListTile(
      leading: const Icon(Icons.south_west),
      title: Text(
        l.incomingTitle(offer.fromName),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: accepted
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.receivingProgress(offer.received, offer.items.length)),
                LinearProgressIndicator(
                  value: offer.items.isEmpty
                      ? null
                      : offer.received / offer.items.length,
                ),
              ],
            )
          : pending && offer.playlist != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.incomingPlaylist(offer.playlist!.name)),
                    Text(l.incomingBody(offer.items.length, mb)),
                  ],
                )
              : Text(
                  pending
                      ? l.incomingBody(offer.items.length, mb)
                      : offerStatusLabel(l, offer.status),
                ),
      trailing: pending
          ? Wrap(
              children: [
                IconButton(
                  tooltip: l.decline,
                  icon: const Icon(Icons.close),
                  onPressed: () => hub.decline(offer),
                ),
                IconButton(
                  tooltip: l.accept,
                  icon: const Icon(Icons.check),
                  onPressed: () => hub.accept(offer),
                ),
              ],
            )
          : null,
    );
  }
}
