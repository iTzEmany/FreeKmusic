import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/releases_providers.dart';
import '../../theme/tokens.dart';

/// Shown once in Home: «Vuoi sapere quando escono brani nuovi dei tuoi artisti
/// più ascoltati?». Either answer makes it go away for good.
class TopArtistsCard extends ConsumerWidget {
  const TopArtistsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seen = ref.watch(releaseOptionsProvider.select((o) => o.topCardSeen));
    if (seen) return const SizedBox.shrink();
    final l = context.l10n;
    final cc = context.cc;
    final options = ref.read(releaseOptionsProvider.notifier);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: CcDims.margin,
        vertical: CcDims.blockPad,
      ),
      child: Container(
        key: const ValueKey('top-artists-card'),
        padding: const EdgeInsets.only(top: CcDims.gap12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: cc.separator)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.releasesTopCardTitle,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Container(
              alignment: Alignment.centerRight,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: cc.separator)),
              ),
              child: Wrap(
                children: [
                  TextButton(
                    key: const ValueKey('top-artists-no'),
                    onPressed: options.dismissTopCard,
                    style: TextButton.styleFrom(foregroundColor: cc.textMuted),
                    child: Text(l.releasesTopCardNo),
                  ),
                  TextButton(
                    key: const ValueKey('top-artists-yes'),
                    onPressed: () => options.setTopArtists(true),
                    style: TextButton.styleFrom(foregroundColor: cc.accentSoft),
                    child: Text(l.releasesTopCardYes),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
