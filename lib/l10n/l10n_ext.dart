import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

extension PlaylistNameL10n on AppLocalizations {
  /// A blank playlist name reads as the generic «Playlist» instead of nothing.
  String playlistLabel(String name) =>
      name.trim().isEmpty ? navPlaylists : name;
}
