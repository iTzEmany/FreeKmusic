import '../../widgets/cc_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_log.dart';
import '../../../core/import_row.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/import_providers.dart';
import '../../../providers/youtube_providers.dart';
import '../../../services/online/youtube_service.dart';
import '../../theme/tokens.dart';
import '../../widgets/cc_search_field.dart';
import '../../widgets/format_utils.dart';
import '../youtube/online_results.dart' show ytErrorText;

/// Plain YouTube search for one CSV row; the chosen result is downloaded and
/// ends up at the row's place in the playlist.
class ImportManualSearchSheet extends ConsumerStatefulWidget {
  const ImportManualSearchSheet({
    super.key,
    required this.importId,
    required this.row,
  });

  final int importId;
  final ImportRow row;

  static Future<void> show(
    BuildContext context, {
    required int importId,
    required ImportRow row,
  }) => showCcSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ImportManualSearchSheet(importId: importId, row: row),
  );

  @override
  ConsumerState<ImportManualSearchSheet> createState() => _State();
}

class _State extends ConsumerState<ImportManualSearchSheet> {
  late final TextEditingController _q = TextEditingController(
    text: '${widget.row.primaryArtist} ${widget.row.title}'.trim(),
  );
  List<YtResult> _results = const [];
  bool _busy = false;
  YtErrorKind? _error;
  int _request = 0;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final id = ++_request;
    setState(() {
      _busy = true;
      _error = null;
    });
    List<YtResult> res = const [];
    YtErrorKind? err;
    try {
      res = await ref.read(youtubeServiceProvider).search(_q.text);
    } on YtException catch (e, st) {
      AppLog.w('manual import search failed', e, st);
      err = e.kind;
    }
    if (!mounted || id != _request) return;
    setState(() {
      _busy = false;
      _results = res;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CcDims.margin,
                  0,
                  CcDims.margin,
                  CcDims.gap8,
                ),
                child: CcSearchField(
                  controller: _q,
                  hint: l.csvImportManual,
                  onSubmitted: (_) => _search(),
                ),
              ),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(CcDims.margin),
                  child: Text(
                    ytErrorText(context, _error!),
                    style: TextStyle(color: cc.error),
                  ),
                ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final r = _results[i];
                    return ListTile(
                      title: Text(
                        r.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${r.channel}, '
                        '${formatDuration(r.duration?.inMilliseconds ?? 0)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.download_rounded),
                      onTap: () {
                        ref
                            .read(playlistImportServiceProvider)
                            .download(widget.importId, widget.row.index, r);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
