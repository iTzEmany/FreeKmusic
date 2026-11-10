import 'package:flutter/material.dart';

import '../../../core/app_log.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../services/online/external_collection.dart';
import '../../../services/online/innertube_client.dart';
import '../../../services/online/youtube_service.dart';
import '../../theme/tokens.dart';
import '../youtube/online_results.dart' show ytErrorText;

/// Why an online page could not be shown, each cause with its own words:
/// not found (no «Riprova»), unreadable (offers [onSearch]), network or other.
class CatalogErrorView extends StatelessWidget {
  const CatalogErrorView({
    super.key,
    required this.error,
    required this.onRetry,
    this.notFoundText,
    this.unreadableText,
    this.onSearch,
    this.searchLabel,
  });

  final Object error;
  final VoidCallback onRetry;

  /// Words for «not found» and «YouTube changed something».
  final String? notFoundText, unreadableText;

  /// The way out of an unreadable page (a normal search) and its label.
  final VoidCallback? onSearch;
  final String? searchLabel;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final e = error;
    AppLog.w('online page failed: $e');
    final String message;
    var retry = true;
    if (e is ArtistNotFound) {
      message = notFoundText ?? l.ytmArtistNotFound;
      retry = false;
    } else if (e is CollectionNotFound) {
      // R-207: private, deleted or wrong link; asking again changes nothing.
      message = notFoundText ?? l.extNotPublic;
      retry = false;
    } else if (e is InnerTubeChanged || e is CollectionUnreadable) {
      message = unreadableText ?? (e is InnerTubeChanged ? l.ytmPageUnreadable : l.extUnreadable);
    } else if (e is YtException) {
      message = ytErrorText(context, e.kind);
    } else {
      message = l.loadFailed;
    }
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(CcDims.margin, CcDims.gap24, CcDims.margin, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: Theme.of(context).textTheme.titleSmall),
            if ((e is InnerTubeChanged || e is CollectionUnreadable) &&
                onSearch != null &&
                searchLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('error-search'),
                onPressed: onSearch,
                child: Text(searchLabel!),
              ),
            ],
            if (retry) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                key: const ValueKey('error-retry'),
                onPressed: onRetry,
                child: Text(l.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
