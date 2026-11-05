import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/library_providers.dart';
import '../../../providers/selection_providers.dart';
import '../../../providers/track_ops.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/async_body.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/cc_app_bar.dart';
import '../../widgets/cc_search_field.dart';

/// Multi-select over the whole library; pops with the chosen ids.
class TrackPickerScreen extends ConsumerStatefulWidget {
  const TrackPickerScreen({super.key, this.initial = const {}});

  final Set<int> initial;

  @override
  ConsumerState<TrackPickerScreen> createState() => _State();
}

class _State extends ConsumerState<TrackPickerScreen> {
  static final _key = SelectionKey.picker.key;
  final _controller = TextEditingController();
  String _query = '';
  AsyncValue<List<Track>>? _prev;

  @override
  void initState() {
    super.initState();
    // Keeps the provider alive; a provider cannot change during initState.
    ref.listenManual(selectionProvider(_key), (_, _) {});
    Future.microtask(() {
      if (mounted) ref.read(selectionProvider(_key).notifier).selectAll(widget.initial.toList());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final picked = ref.watch(selectionProvider(_key));
    return Scaffold(
      appBar: CcAppBar(
        title: l.sharePick,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(Set.of(picked.ids)),
            child: Text(l.save),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(CcDims.gap12),
            child: CcSearchField(
              controller: _controller,
              hint: l.searchHint,
              onQuery: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                final fresh = ref.watch(trackSearchProvider(_query));
                final found = keepWhileLoading(fresh, _prev);
                _prev = found.hasError ? null : found;
                return AsyncBody(
                  value: found,
                  rowHeight: trackRowExtentOf(context, false),
                  onRetry: () => ref.invalidate(trackSearchProvider(_query)),
                  data: (tracks) => ListView.builder(
                    itemExtent: trackRowExtentOf(context, false),
                    itemCount: tracks.length,
                    itemBuilder: (_, i) {
                      final t = tracks[i];
                      return CheckboxListTile(
                        value: picked.contains(t.id),
                        onChanged: (_) => ref.read(selectionProvider(_key).notifier).toggle(t.id),
                        secondary: CoverImage(coverKey: t.coverKey, size: 44),
                        title: Text(
                          t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          t.artist ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
