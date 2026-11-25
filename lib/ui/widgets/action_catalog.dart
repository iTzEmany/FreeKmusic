import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// The one table action → icon → text (F-01..F-05, F-12). Every menu, bar and header takes its
/// icon and label from here, so a given action looks and reads the same everywhere.
/// The queue and the library never share an icon; Export (save a file) is not Share; ⋮ is [more].
enum CatalogAction {
  queue(Icons.add_to_queue_rounded),
  library(Icons.bookmark_add_rounded),
  playlist(Icons.playlist_add_rounded),
  download(Icons.download_rounded),
  share(Icons.share_rounded),
  export(Icons.save_alt_rounded),
  more(Icons.more_vert_rounded),

  /// The queue as a place (panel, empty queue); the only user of this icon for «queue».
  queuePanel(Icons.queue_music_rounded);

  const CatalogAction(this.icon);
  final IconData icon;

  String label(AppLocalizations l) => switch (this) {
    queue => l.addToQueue,
    library => l.addToLibrary,
    playlist => l.addToPlaylist,
    download => l.ytDownload,
    share => l.shareAction,
    export => l.exportPlaylist,
    more => l.moreActions,
    queuePanel => l.queue,
  };
}
