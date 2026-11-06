// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Codecore';

  @override
  String get chooseFolder => 'Choose folder';

  @override
  String get scan => 'Scan';

  @override
  String get noTracks => 'No tracks. Choose a folder and scan.';

  @override
  String get openSettings => 'Open settings';

  @override
  String get permissionDenied => 'Audio read permission denied';

  @override
  String get permissionExplain =>
      'Codecore needs permission to read audio files to show your music.';

  @override
  String get navLibrary => 'Library';

  @override
  String get navFavorites => 'Favorites';

  @override
  String get navPlaylists => 'Playlists';

  @override
  String get navSettings => 'Settings';

  @override
  String get tracks => 'Tracks';

  @override
  String get albums => 'Albums';

  @override
  String get artists => 'Artists';

  @override
  String get searchHint => 'Search';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get sortBy => 'Sort by';

  @override
  String get addMusicFolder => 'Add your music folder';

  @override
  String get addFolder => 'Add folder';

  @override
  String get folders => 'Music folders';

  @override
  String get refreshLibrary => 'Refresh library';

  @override
  String get removeFolder => 'Remove folder';

  @override
  String get unknownArtist => 'Unknown artist';

  @override
  String get unknownAlbum => 'Unknown album';

  @override
  String get variousArtists => 'Various artists';

  @override
  String get play => 'Play';

  @override
  String get shuffle => 'Shuffle';

  @override
  String get queue => 'Queue';

  @override
  String get nowPlaying => 'Now playing';

  @override
  String get nothingPlaying => 'Nothing playing';

  @override
  String get mute => 'Mute';

  @override
  String get scanning => 'Scanning…';

  @override
  String get emptyQueue => 'The queue is empty';

  @override
  String get noResults => 'No results';

  @override
  String get sortDefault => 'Default';

  @override
  String get sortPersonal => 'Personal order';

  @override
  String get sortTitle => 'Title';

  @override
  String get sortArtist => 'Artist';

  @override
  String get sortAlbum => 'Album';

  @override
  String get sortYear => 'Year';

  @override
  String get sortAdded => 'Recently added';

  @override
  String get sortDuration => 'Duration';

  @override
  String tracksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
    );
    return '$_temp0';
  }

  @override
  String albumsCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString albums',
      one: '1 album',
    );
    return '$_temp0';
  }

  @override
  String get libraryAll => 'All';

  @override
  String libraryItemsCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String playlistsCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString playlists',
      one: '1 playlist',
    );
    return '$_temp0';
  }

  @override
  String artistsCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString artists',
      one: '1 artist',
    );
    return '$_temp0';
  }

  @override
  String minutesWords(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String hoursWords(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String hoursAndMinutes(String hours, String minutes) {
    return '$hours $minutes';
  }

  @override
  String get collectionNoTracks => 'No tracks';

  @override
  String missingTracksCount(int count) {
    return 'Missing tracks ($count)';
  }

  @override
  String get addedToFavorites => 'Added to favorites';

  @override
  String get removedFromFavorites => 'Removed from favorites';

  @override
  String get undo => 'Undo';

  @override
  String get favoritesEmptyTitle => 'No favourites yet';

  @override
  String get favoritesEmptyHelp =>
      'Tap the heart on a song and it shows up here.';

  @override
  String get openAllTracks => 'Open all songs';

  @override
  String get newPlaylist => 'New playlist';

  @override
  String get newPlaylistEllipsis => 'New playlist…';

  @override
  String get playlistName => 'Playlist name';

  @override
  String get create => 'Create';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get rename => 'Rename';

  @override
  String get noPlaylists => 'No playlists. Create one.';

  @override
  String get addToPlaylist => 'Add to playlist…';

  @override
  String addedToPlaylist(String name) {
    return 'Added to “$name”';
  }

  @override
  String get playNext => 'Play next';

  @override
  String get addToQueue => 'Add to queue';

  @override
  String get addedToQueue => 'Added to queue';

  @override
  String get favorite => 'Favorite';

  @override
  String get removeFromFavorites => 'Remove from favorites';

  @override
  String get removeFromList => 'Remove';

  @override
  String get editInfo => 'Edit info';

  @override
  String get details => 'Details';

  @override
  String get showInFolder => 'Show in folder';

  @override
  String get detailPath => 'Path';

  @override
  String get detailFormat => 'Format';

  @override
  String get detailSize => 'Size';

  @override
  String get detailDuration => 'Duration';

  @override
  String get detailAdded => 'Added on';

  @override
  String get detailPlays => 'Plays';

  @override
  String get close => 'Close';

  @override
  String get fieldTitle => 'Title';

  @override
  String get fieldArtist => 'Artist';

  @override
  String get fieldAlbum => 'Album';

  @override
  String get fieldAlbumArtist => 'Album artist';

  @override
  String get fieldYear => 'Year';

  @override
  String get fieldTrackNumber => 'Track number';

  @override
  String get fieldGenre => 'Genre';

  @override
  String get restoreFromFile => 'Restore from file tags';

  @override
  String get titleRequired => 'Title cannot be empty';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get themeNotte => 'Purple night';

  @override
  String get themeOled => 'Pure black';

  @override
  String get settingsTextSize => 'Text size';

  @override
  String get textSmall => 'Small';

  @override
  String get textNormal => 'Normal';

  @override
  String get textLarge => 'Large';

  @override
  String get settingsCompact => 'Compact mode';

  @override
  String get settingsReducedMotion => 'Reduce animations';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLibrary => 'Library';

  @override
  String get rescanNow => 'Rescan now';

  @override
  String get clearCoverCache => 'Clear cover cache';

  @override
  String get coverCacheCleared => 'Cover cache cleared';

  @override
  String get settingsOnline => 'Online';

  @override
  String get settingsPageAppearance => 'Appearance and language';

  @override
  String get settingsPagePlayback => 'Playback';

  @override
  String get settingsPageLibrary => 'Library';

  @override
  String get settingsPageOnline => 'Online and downloads';

  @override
  String get settingsPageNetwork => 'Network and devices';

  @override
  String get settingsPageBackup => 'Backup';

  @override
  String get settingsPageAdvanced => 'Advanced and about';

  @override
  String summaryLibrary(int folders, int tracks) {
    String _temp0 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: '$folders folders',
      one: '1 folder',
    );
    String _temp1 = intl.Intl.pluralLogic(
      tracks,
      locale: localeName,
      other: '$tracks tracks',
      one: '1 track',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String summaryTrusted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trusted devices',
      one: '1 trusted device',
    );
    return '$_temp0';
  }

  @override
  String get summaryNormalizeOn => 'normalization on';

  @override
  String get summaryBackup => 'Export and restore the library';

  @override
  String summaryCrossfade(int seconds) {
    return '$seconds s';
  }

  @override
  String get openPlaybackSettings => 'Open Playback';

  @override
  String get autoEnrich => 'Automatic enrichment';

  @override
  String get autoEnrichHint =>
      'Look up metadata and covers online for new tracks';

  @override
  String get autoLyrics => 'Automatic lyrics';

  @override
  String get autoLyricsHint => 'Download lyrics from LRCLIB for new tracks';

  @override
  String get settingsAbout => 'About';

  @override
  String appVersion(String version) {
    return 'Version $version';
  }

  @override
  String get licenses => 'Licenses';

  @override
  String get personalUse => 'Personal-use app';

  @override
  String get missingTracksTitle => 'Missing tracks';

  @override
  String get removeFromLibrary => 'Remove from library';

  @override
  String get ignore => 'Ignore';

  @override
  String get confirmRemoveTitle => 'Remove from library?';

  @override
  String get confirmRemoveBody =>
      'The file is not touched; you lose favorites and playlists for this track.';

  @override
  String get noMissingTracks => 'No missing tracks';

  @override
  String get retry => 'Retry';

  @override
  String scanFailed(String error) {
    return 'Scan failed: $error';
  }

  @override
  String playbackError(String reason, String title) {
    return 'Cannot play “$title”: $reason';
  }

  @override
  String get reasonFileMissing => 'file not found';

  @override
  String get reasonUnplayable => 'file cannot be played';

  @override
  String get reasonNotInLibrary => 'track not in library';

  @override
  String get reasonOnlineUnavailable => 'online track not available';

  @override
  String get reasonAgeRestricted =>
      'age-restricted video, no audio track found';

  @override
  String get searchWeb => 'Search info online';

  @override
  String get enrichPreviewTitle => 'Information preview';

  @override
  String get currentValue => 'Current';

  @override
  String get proposedValue => 'Proposed';

  @override
  String get apply => 'Apply';

  @override
  String get nothingFound => 'Nothing found';

  @override
  String get userEditedLocked => 'Edited by you: will not be overwritten';

  @override
  String get fieldCover => 'Cover';

  @override
  String get fieldLyrics => 'Lyrics';

  @override
  String get fieldCuriosity => 'Trivia';

  @override
  String get enrichAlbum => 'Enrich album';

  @override
  String get enrichLibrary => 'Enrich whole library';

  @override
  String enrichRunning(int done, int total) {
    return 'Enriching $done/$total';
  }

  @override
  String enrichResult(int notFound, int updated) {
    return '$updated updated, $notFound not found';
  }

  @override
  String get enrichBusy => 'An enrichment is already running';

  @override
  String get enrichNothingToDo =>
      'Nothing to enrich: no track is missing anything';

  @override
  String get serviceUnavailable => 'Service unavailable, try again later';

  @override
  String get lyrics => 'Lyrics';

  @override
  String get searchLyrics => 'Search lyrics';

  @override
  String get noLyrics => 'No lyrics available';

  @override
  String get lyricsNotFound => 'Lyrics not found';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get sourceWikipedia => 'Source: Wikipedia (CC BY-SA)';

  @override
  String get youtube => 'YouTube';

  @override
  String get ytHint => 'Search or paste a link';

  @override
  String get ytDownload => 'Download';

  @override
  String get listenAction => 'Listen';

  @override
  String get ytAlreadyInLibrary => 'Already in library';

  @override
  String get ytNoResults => 'No results';

  @override
  String get ytQueued => 'Queued';

  @override
  String get ytDownloading => 'Downloading';

  @override
  String get ytDone => 'Done';

  @override
  String get ytFailed => 'Failed';

  @override
  String get ytCancelled => 'Cancelled';

  @override
  String get ytClearCompleted => 'Clear completed';

  @override
  String get ytCancel => 'Cancel download';

  @override
  String get ytErrUnavailable => 'Video unavailable (age/region/private)';

  @override
  String get ytErrNetwork => 'Network unavailable';

  @override
  String get ytErrChanged =>
      'YouTube changed something: update the app or package';

  @override
  String get ytNoFolder => 'Add a music folder first';

  @override
  String get ytLegal =>
      'Personal use only. Respect copyright and the terms of YouTube.';

  @override
  String get useDefaultFolder => 'Use the device Music folder';

  @override
  String get ytErrToolMissing =>
      'yt-dlp not found: install it (pip install -U yt-dlp) and retry';

  @override
  String get ytErrRateLimited =>
      'YouTube asked to slow down: try again in a few minutes';

  @override
  String get playlistChangeCover => 'Change cover';

  @override
  String get playlistRemoveCover => 'Remove cover';

  @override
  String get coverTooLarge => 'Image too large (max 4 MB)';

  @override
  String get addSongs => 'Add songs';

  @override
  String addNSongs(int count) {
    return 'Add ($count)';
  }

  @override
  String get allSongsInPlaylist => 'All songs are already in the playlist';

  @override
  String get shareTitle => 'Sharing';

  @override
  String get shareSend => 'Send';

  @override
  String get shareReceive => 'Receive';

  @override
  String get shareAll => 'Whole library';

  @override
  String shareSelection(int count) {
    return 'Selection ($count tracks)';
  }

  @override
  String get sharePick => 'Choose tracks';

  @override
  String get shareStart => 'Start sharing';

  @override
  String get shareStop => 'Stop';

  @override
  String get shareActive => 'Sharing is on';

  @override
  String get shareAddress => 'Address (IP:port)';

  @override
  String get sharePin => 'PIN';

  @override
  String get shareConnect => 'Connect';

  @override
  String shareDownloadSelected(int count) {
    return 'Download selected ($count)';
  }

  @override
  String shareProgress(int done, int total) {
    return 'Track $done of $total';
  }

  @override
  String shareDone(int count) {
    return '$count tracks received';
  }

  @override
  String shareConnectedTo(String name) {
    return 'Connected to $name';
  }

  @override
  String get shareErrUnreachable =>
      'Device unreachable: check address and Wi‑Fi';

  @override
  String get shareErrPin => 'Wrong PIN';

  @override
  String get shareErrBlocked => 'Too many attempts: retry in a minute';

  @override
  String get shareErrNotCodecore => 'Not a Codecore device';

  @override
  String get shareErrFailed => 'Transfer failed';

  @override
  String get shareNoNetwork => 'No local network found';

  @override
  String get shareFirewall =>
      'Windows may ask for firewall permission the first time.';

  @override
  String get shareHint =>
      'On the same Wi‑Fi, open “Receive” on the other device and enter address and PIN.';

  @override
  String get shareMenu => 'Share…';

  @override
  String get shareDeviceName => 'Device name';

  @override
  String get sleepTimer => 'Sleep timer';

  @override
  String sleepMinutes(int count) {
    return '$count minutes';
  }

  @override
  String get sleepEndOfTrack => 'At end of track';

  @override
  String get sleepCancel => 'Cancel timer';

  @override
  String get pause => 'Pause';

  @override
  String get nextTrack => 'Next track';

  @override
  String get previousTrack => 'Previous track';

  @override
  String get repeat => 'Repeat';

  @override
  String get moreOptions => 'More options';

  @override
  String get back => 'Back';

  @override
  String get seekPosition => 'Position in the track';

  @override
  String get settingsPlayback => 'Playback';

  @override
  String get normalizeVolume => 'Normalize volume';

  @override
  String get normalizeVolumeHint =>
      'Uses files’ ReplayGain to lower tracks that are too loud';

  @override
  String get nearbyDevices => 'Nearby devices';

  @override
  String get searchingDevices => 'Looking for devices on the network…';

  @override
  String get noDevicesHint =>
      'No device found. Open Sharing on the other device too, on the same network.';

  @override
  String sendToDevice(String name) {
    return 'Send to $name';
  }

  @override
  String offerSent(String name) {
    return 'Request sent to $name';
  }

  @override
  String get offerChooseFirst => 'Choose the tracks to send first';

  @override
  String get sentRequests => 'Sent requests';

  @override
  String get receivedRequests => 'Received requests';

  @override
  String get offerPending => 'Waiting for a reply';

  @override
  String get offerAccepted => 'Accepted';

  @override
  String get offerDeclined => 'Declined';

  @override
  String get offerCancelled => 'Cancelled';

  @override
  String get offerExpired => 'Expired';

  @override
  String get offerDone => 'Completed';

  @override
  String get offerFailed => 'Failed';

  @override
  String incomingTitle(String name) {
    return '$name wants to send you tracks';
  }

  @override
  String incomingBody(int count, String size) {
    return '$count tracks, $size MB';
  }

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String receivingProgress(int done, int total) {
    return 'Receiving $done/$total';
  }

  @override
  String get manualConnection => 'Manual connection (IP and PIN)';

  @override
  String get receiveFromLan => 'Receive from the local network';

  @override
  String get receiveFromLanHint =>
      'Makes this device visible and receives requests even in the background. On Android it shows a permanent notification you can use to turn it off';

  @override
  String get receiveServiceTitle => 'Codecore is visible on the network';

  @override
  String get receiveServiceText =>
      'Ready to receive tracks from nearby devices';

  @override
  String get receiveServiceDisable => 'Turn off';

  @override
  String get jamTitle => 'Jam';

  @override
  String get jamStart => 'Start a Jam';

  @override
  String jamStartWith(String name) {
    return 'Start Jam with $name';
  }

  @override
  String jamWaiting(String name) {
    return 'Waiting for $name to accept…';
  }

  @override
  String jamDeclined(String name) {
    return '$name declined the Jam';
  }

  @override
  String jamBusy(String name) {
    return '$name already has a Jam running';
  }

  @override
  String get jamUnreachable => 'Device unreachable';

  @override
  String jamIncomingTitle(String name) {
    return '$name wants to start a Jam';
  }

  @override
  String get jamIncomingBody => 'Listen together from a shared queue.';

  @override
  String get jamIncomingDialog =>
      'The music plays from this device and you can both add tracks.';

  @override
  String get jamQueue => 'Shared queue';

  @override
  String get jamModeHost => 'Host\'s queue';

  @override
  String get jamModeTogether => 'Shared turns';

  @override
  String get jamModeGuestHint => 'The host chooses the queue mode';

  @override
  String get jamSuggested => 'Suggested';

  @override
  String get jamEmpty => 'Queue tracks from the library or from search';

  @override
  String jamOnlineFailed(String title) {
    return 'Could not add “$title” to the Jam';
  }

  @override
  String jamAddedBy(String name) {
    return 'added by $name';
  }

  @override
  String get jamJumpHere => 'Jump here';

  @override
  String get jamYou => 'you';

  @override
  String get jamGuest => 'Guest';

  @override
  String get jamAddToJam => 'Add to Jam';

  @override
  String jamAdded(int count) {
    return 'Added to the Jam: $count';
  }

  @override
  String get jamOutput => 'Audio output';

  @override
  String get jamOutputHere => 'This device';

  @override
  String jamOutputOther(String name) {
    return '$name';
  }

  @override
  String get jamEnd => 'End Jam';

  @override
  String get jamLeave => 'Leave Jam';

  @override
  String get jamEnded => 'The Jam has ended';

  @override
  String get jamLost => 'Connection lost';

  @override
  String get jamGuestCannotSkip => 'Only the host can change track';

  @override
  String get jamRemoveForbidden => 'You can only remove your own tracks';

  @override
  String get jamNothingPlaying => 'Nothing playing';

  @override
  String jamWith(String name) {
    return 'Jam with $name';
  }

  @override
  String get jamUnavailable => 'Unavailable';

  @override
  String get jamPlaying => 'Jam is active';

  @override
  String get jamOpen => 'Open Jam';

  @override
  String jamSynced(int ms) {
    return 'In sync, offset $ms ms';
  }

  @override
  String get jamSyncing => 'Synchronising…';

  @override
  String jamLatency(int ms) {
    return 'This output\'s latency: $ms ms';
  }

  @override
  String get jamLatencyHint =>
      'For Bluetooth headphones or speakers: raise it until the outputs line up.';

  @override
  String get jamOutputsHint => 'Several outputs play together';

  @override
  String get renamePlaylist => 'Rename playlist';

  @override
  String get confirmDeletePlaylistTitle => 'Delete the playlist?';

  @override
  String confirmDeletePlaylistBody(String name) {
    return '“$name” will be deleted. The tracks stay in your library.';
  }

  @override
  String get confirmRemoveFolderTitle => 'Remove the folder?';

  @override
  String get confirmRemoveFolderBody =>
      'Its tracks leave the library. The files stay on the device.';

  @override
  String get confirmClearCoversTitle => 'Clear the cover cache?';

  @override
  String get confirmClearCoversBody => 'Covers are rebuilt at the next scan.';

  @override
  String get confirmRestoreTitle => 'Restore from the file tags?';

  @override
  String get confirmRestoreBody =>
      'Your edits to this track are replaced with the data in the file.';

  @override
  String get removedFromPlaylist => 'Removed from the playlist';

  @override
  String get removedFromQueue => 'Removed from the queue';

  @override
  String get playNextDone => 'Will play next';

  @override
  String get ytSearchPrompt => 'Search for a track or paste a link';

  @override
  String get loadFailed => 'Couldn\'t load the data.';

  @override
  String get navHome => 'Home';

  @override
  String get navSearch => 'Search';

  @override
  String get devicesTitle => 'Devices';

  @override
  String get devicesJamActive => 'Active Jam';

  @override
  String jamPeople(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Jam, $n people',
      one: 'Jam, 1 person',
    );
    return '$_temp0';
  }

  @override
  String get devicesVisibleTitle => 'Make this device visible';

  @override
  String get devicesVisibleHint =>
      'To receive tracks or start a Jam, other devices need to see you on the network.';

  @override
  String get devicesJamShort => 'Jam';

  @override
  String get devicesSendShort => 'Send';

  @override
  String get devicesMore => 'Sharing and manual connection';

  @override
  String jamParticipantsCount(int n) {
    return '$n people';
  }

  @override
  String get playingFrom => 'Playing from';

  @override
  String get playContextSearch => 'Search';

  @override
  String get allTracks => 'All tracks';

  @override
  String get trackInfo => 'About this track';

  @override
  String get searchCuriosity => 'Look up trivia';

  @override
  String get upNext => 'Up next';

  @override
  String get openQueue => 'Open queue';

  @override
  String get copyLink => 'Copy link';

  @override
  String get moreActions => 'More actions';

  @override
  String get sleepChipEnd => 'end of track';

  @override
  String get yourLibrary => 'Your library';

  @override
  String playlistCountLabel(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Playlist with $n tracks',
      one: 'Playlist with 1 track',
    );
    return '$_temp0';
  }

  @override
  String get sortRecent => 'Recently played';

  @override
  String get sortAlphabetical => 'Alphabetical';

  @override
  String get sortAToZ => 'A–Z';

  @override
  String get sortAddedRecently => 'Recently added';

  @override
  String get sortTitleAToZ => 'Title A–Z';

  @override
  String get sortMostPlayed => 'Most played';

  @override
  String get sortTrackCount => 'Number of tracks';

  @override
  String get sortAscending => 'Ascending';

  @override
  String get sortDescending => 'Descending';

  @override
  String get viewAsGrid => 'Show as grid';

  @override
  String get viewAsList => 'Show as list';

  @override
  String get kindAlbum => 'Album';

  @override
  String get kindArtist => 'Artist';

  @override
  String get kindPlaylist => 'Playlist';

  @override
  String discN(int n) {
    return 'Disc $n';
  }

  @override
  String albumMeta(String details) {
    return 'Album, $details';
  }

  @override
  String durationMinutes(int n) {
    return '$n min';
  }

  @override
  String tracksAndDuration(String tracks, String duration) {
    return '$tracks, $duration';
  }

  @override
  String get mostPlayed => 'Most played';

  @override
  String get albumsSection => 'Albums';

  @override
  String get addAllToQueue => 'Add to queue';

  @override
  String addedNToQueue(int n) {
    return '$n tracks added to the queue';
  }

  @override
  String get editOrder => 'Edit order';

  @override
  String get finishEditing => 'Done';

  @override
  String get removeFromPlaylistAction => 'Remove from playlist';

  @override
  String get noTracksInPlaylist => 'This playlist is empty';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingAfternoon => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String get homeResume => 'Jump back in';

  @override
  String get homeTopTracks => 'Most played';

  @override
  String get homeRediscover => 'Rediscover';

  @override
  String get homeShuffleAll => 'Shuffle everything';

  @override
  String homeShuffleAllSub(String tracks, String hours) {
    return '$tracks, $hours';
  }

  @override
  String hoursCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
      zero: 'under an hour',
    );
    return '$_temp0';
  }

  @override
  String get homeAddedLately => 'Just added';

  @override
  String homeResumeQueue(int n, int m) {
    return 'Track $n of $m';
  }

  @override
  String homeResumeQueueFrom(String source, int n, int m) {
    return '$source: track $n of $m';
  }

  @override
  String homeMinutesLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes left',
      one: '1 minute left',
    );
    return '$_temp0';
  }

  @override
  String get homeFanOpen => 'Show recently added songs';

  @override
  String get showAll => 'All';

  @override
  String get recentSearches => 'Recent searches';

  @override
  String get genresTitle => 'Genres';

  @override
  String downloadsChip(int n) {
    return 'Downloads ($n)';
  }

  @override
  String get gotIt => 'Got it';

  @override
  String get searchEmptyLibrary => 'No results in your library';

  @override
  String get ytInfoTooltip => 'About usage';

  @override
  String removeRecentSearch(String query) {
    return 'Remove “$query” from recent searches';
  }

  @override
  String get groupGoTo => 'Go to';

  @override
  String get goToAlbum => 'Go to album';

  @override
  String get goToArtist => 'Go to artist';

  @override
  String get groupQueue => 'Queue';

  @override
  String get groupCollection => 'Collection';

  @override
  String get groupEdit => 'Edit';

  @override
  String get groupOther => 'More';

  @override
  String get queueNowPlaying => 'Now playing';

  @override
  String get queueNext => 'Next up';

  @override
  String get queueClear => 'Clear';

  @override
  String get queueCleared => 'Queue cleared';

  @override
  String get queueRebuilt => 'Queue rebuilt from what is playing';

  @override
  String get jamOutputsAndSync => 'Outputs and sync';

  @override
  String get jamHostTag => 'host';

  @override
  String get jamSeekInvalid => 'That position is not valid for this track';

  @override
  String get jamEndConfirmTitle => 'End the Jam for everyone?';

  @override
  String jamEndConfirmBody(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'The $n guests will be disconnected and the shared queue closed.',
      one: 'The guest will be disconnected and the shared queue closed.',
    );
    return '$_temp0';
  }

  @override
  String get jamEndConfirmAction => 'End';

  @override
  String jamParticipantsLabel(int n, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n participants: $names',
      one: '1 participant: $names',
    );
    return '$_temp0';
  }

  @override
  String get jamWaitingEmpty => 'No Jam in progress';

  @override
  String get activityTitle => 'Activity';

  @override
  String activityScan(int done, int total) {
    return 'Scanning: $done of $total';
  }

  @override
  String get activityScanIdle => 'Scanning';

  @override
  String activityEnrich(int done, int total) {
    return 'Enriching: $done of $total';
  }

  @override
  String activityDownload(String title) {
    return 'Download, $title';
  }

  @override
  String activityTransfer(String name, int n) {
    return 'Sending to $name, $n tracks';
  }

  @override
  String get activityNone => 'No activity';

  @override
  String get activityCompleted => 'Completed';

  @override
  String get importPhaseSearching => 'Searching…';

  @override
  String importPhaseDownloading(int percent) {
    return 'Downloading $percent %';
  }

  @override
  String importPhaseRetry(int seconds) {
    return 'Trying again in $seconds s';
  }

  @override
  String get importPhaseEnriching => 'Enriching…';

  @override
  String get importPhaseDownloadStart => 'Downloading…';

  @override
  String get importFilterAll => 'All';

  @override
  String get importFilterActive => 'In progress';

  @override
  String get importFilterProblems => 'Need you';

  @override
  String get importFilterDone => 'Done';

  @override
  String get importRowsNone => 'No songs here';

  @override
  String get activityLog => 'Log';

  @override
  String activityLogCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '1 event',
      zero: 'Empty',
    );
    return '$_temp0';
  }

  @override
  String get activityLogEmpty =>
      'Nothing logged yet: finished downloads, imports and transfers show up here.';

  @override
  String logImport(String name) {
    return 'Import «$name»';
  }

  @override
  String importNotificationText(int done, int total) {
    return '$done of $total';
  }

  @override
  String importNotificationPaused(int done, int total) {
    return 'Paused, $done of $total';
  }

  @override
  String importWaitRateLimited(String time) {
    return 'YouTube asked for a break: resuming at $time';
  }

  @override
  String importWaitNetwork(String time) {
    return 'No network: trying again at $time';
  }

  @override
  String importPausedTitle(String name) {
    return 'Import “$name” paused';
  }

  @override
  String get downloadsNotificationTitle => 'Downloading';

  @override
  String downloadsNotificationText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    return '$_temp0';
  }

  @override
  String activityRunning(int n) {
    return '$n activities running';
  }

  @override
  String get settingsLocalNetwork => 'Local network';

  @override
  String get removeAll => 'Remove all';

  @override
  String get confirmRemoveAllTitle => 'Remove all from the library?';

  @override
  String confirmRemoveAllBody(int n) {
    return '$n missing tracks will be removed from the library. Files are not touched; you lose their favourites and playlist entries.';
  }

  @override
  String get csvImportMenu => 'Import from Exportify (CSV)';

  @override
  String get csvImportIntroTitle => 'Import a playlist';

  @override
  String get csvImportIntroSource =>
      'The CSV file is created for free on the Exportify website — exportify.net (no app needed).';

  @override
  String get csvImportStep1 =>
      'Open https://exportify.net in a browser (the phone works too).';

  @override
  String get csvImportStep2 =>
      'Tap “Get Started” and sign in with your Spotify account.';

  @override
  String get csvImportStep3 =>
      'Next to the playlist you want, tap “Export”: a .csv file named after the playlist is downloaded.';

  @override
  String get csvImportStep4 => 'Come back here and tap “Choose CSV file”.';

  @override
  String get csvImportNote =>
      'Codecore looks for the tracks in your library and downloads the others from YouTube Music.';

  @override
  String get csvImportNoteOffline =>
      'Only tracks already in your library will be linked.';

  @override
  String get csvImportCopy => 'Copy address';

  @override
  String get csvImportCopied => 'Address copied';

  @override
  String get csvImportPick => 'Choose file';

  @override
  String get csvImportNotExportify =>
      'Unrecognised format. Choose a CSV (Exportify, TuneMyMusic, Soundiiz, Last.fm) or an M3U/M3U8/XSPF playlist.';

  @override
  String get csvImportReadFailed => 'The file could not be read.';

  @override
  String get csvImportPreviewTitle => 'Import playlist';

  @override
  String get csvImportName => 'Playlist name';

  @override
  String csvImportSummary(int total, int known, int todo) {
    return '$total tracks, $known already in library, $todo to download';
  }

  @override
  String csvImportSkipped(int n) {
    return '$n rows ignored (podcasts or local files)';
  }

  @override
  String csvImportEstimate(int minutes) {
    return 'Estimated time: about $minutes min';
  }

  @override
  String get csvImportExists => 'A playlist with this name already exists';

  @override
  String get csvImportUpdate =>
      'Update the existing one (adds only new tracks)';

  @override
  String get csvImportNew => 'Create a new playlist';

  @override
  String get csvImportGo => 'Import';

  @override
  String get csvImportStarted =>
      'Import started: follow it in the Activity Center';

  @override
  String activityImport(String name, int done, int total) {
    return 'Import “$name”: $done of $total';
  }

  @override
  String activityImportPaused(String name, int done, int total) {
    return 'Import “$name”: paused, $done of $total';
  }

  @override
  String csvImportBanner(int done, int total, int review, int missing) {
    return 'Import: $done of $total, $review to review, $missing not found';
  }

  @override
  String csvImportBannerPaused(int done, int total, int review, int missing) {
    return 'Import paused: $done of $total, $review to review, $missing not found';
  }

  @override
  String get csvImportReview => 'Review';

  @override
  String get csvImportResume => 'Resume';

  @override
  String get csvImportPause => 'Pause';

  @override
  String get csvImportCancelTitle => 'Cancel the import?';

  @override
  String get csvImportCancelBody =>
      'Tracks already downloaded stay in the playlist.';

  @override
  String csvImportDone(int added, int review, int missing) {
    return 'Import finished: $added added, $review to review, $missing not found';
  }

  @override
  String get csvImportFailing => 'Too many errors in a row: import paused';

  @override
  String get csvImportReviewTitle => 'Review';

  @override
  String get csvImportToReview => 'To review';

  @override
  String get csvImportNotFound => 'Not found';

  @override
  String get csvImportErrors => 'With errors';

  @override
  String get csvImportRetryAll => 'Retry all';

  @override
  String get csvImportSkip => 'Skip';

  @override
  String get csvImportManual => 'Search manually';

  @override
  String get csvImportNothing => 'Nothing to review.';

  @override
  String get csvImportSearch => 'Search';

  @override
  String csvImportWanted(String title, String artist, String duration) {
    return 'Wanted: $title, $artist, $duration';
  }

  @override
  String get csvImportDownload => 'Download';

  @override
  String get csvImportCancelGo => 'Cancel import';

  @override
  String get exportLog => 'Export log';

  @override
  String get exportLogHint =>
      'Text file without personal paths, network addresses or PINs';

  @override
  String get exportLogDebugOnly =>
      'Only in the installed version (debug builds don\'t write the log to a file)';

  @override
  String get exportLogNone => 'There is no log to export yet';

  @override
  String get exportLogSaved => 'Log saved';

  @override
  String get exportLogFailed => 'Couldn\'t save the log';

  @override
  String get exportPlaylist => 'Export…';

  @override
  String get exportPlaylistTitle => 'Export playlist';

  @override
  String get exportFormatM3u8 => 'M3U8, for other players';

  @override
  String get exportFormatCsv => 'CSV, like Exportify';

  @override
  String get exportFormatJson => 'JSON, Codecore format';

  @override
  String get exportRelativePaths => 'Relative paths';

  @override
  String get exportRelativeHint =>
      'Relative to the folder shared by all tracks: save the file there';

  @override
  String get exportAction => 'Export';

  @override
  String get exportSaved => 'Playlist exported';

  @override
  String get exportEmpty => 'The playlist is empty';

  @override
  String get exportFailed => 'Couldn\'t export the playlist';

  @override
  String get ytErrToolOutdated =>
      'yt-dlp is too old: update it (Settings, Online and downloads, Update) and try again';

  @override
  String ytDlpOutdatedBanner(String version) {
    return 'yt-dlp $version is too old: downloads may not work';
  }

  @override
  String get settingsDownloads => 'Downloads';

  @override
  String ytDlpVersion(String version) {
    return 'yt-dlp $version';
  }

  @override
  String get ytDlpUnknownVersion => 'yt-dlp not found';

  @override
  String get ytDlpUpdate => 'Update';

  @override
  String ytDlpUpdating(int percent) {
    return 'Updating… $percent%';
  }

  @override
  String ytDlpUpdated(String version) {
    return 'Updated to version $version';
  }

  @override
  String get ytDlpTooOld => 'Too old: tap Update';

  @override
  String get ytDlpUpdateErrNetwork => 'Update failed: network unreachable';

  @override
  String get ytDlpUpdateErrHash =>
      'Update cancelled: the downloaded file failed the integrity check';

  @override
  String get ytDlpUpdateErrOther => 'Update failed (see the log)';

  @override
  String get downloadParallel => 'Simultaneous downloads';

  @override
  String get downloadParallelHint =>
      'More at once is faster, but YouTube may ask you to slow down';

  @override
  String get downloadRateLimit => 'Speed limit';

  @override
  String get downloadRateNone => 'None';

  @override
  String downloadRateKb(int kb) {
    return '$kb KB/s';
  }

  @override
  String downloadRateMb(int mb) {
    return '$mb MB/s';
  }

  @override
  String activityDownloadRetry(
    String title,
    int seconds,
    int attempt,
    int max,
  ) {
    return 'Download, $title, retrying in $seconds s ($attempt/$max)';
  }

  @override
  String get downloadFormat => 'Download format';

  @override
  String get downloadFormatOriginal => 'Original (best quality)';

  @override
  String get downloadFormatOriginalHint =>
      'YouTube\'s audio with no re-encoding, usually Opus ~160 kbps. Not every player or car stereo reads it.';

  @override
  String get downloadFormatM4a => 'M4A (recommended)';

  @override
  String get downloadFormatM4aHint =>
      'Almost as good as the original, no re-encoding: fast, light (~1 MB/min), plays everywhere.';

  @override
  String get downloadFormatMp3High => 'MP3 320 kbps';

  @override
  String get downloadFormatMp3HighHint =>
      'Plays on anything. Re-encoded: slight loss, big files (~2.4 MB/min), slower download.';

  @override
  String get downloadFormatMp3Low => 'MP3 192 kbps (lowest quality)';

  @override
  String get downloadFormatMp3LowHint =>
      'Plays on anything, half the space of MP3 320 (~1.4 MB/min), but the lowest quality.';

  @override
  String get searchCacheClear => 'Clear search cache';

  @override
  String searchCacheCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saved searches',
      one: '1 saved search',
      zero: 'Empty',
    );
    return '$_temp0';
  }

  @override
  String get searchCacheCleared => 'Cache cleared';

  @override
  String csvImportLengthOff(String found, String wanted) {
    return 'Different length: $found instead of $wanted';
  }

  @override
  String get csvImportKeep => 'Keep this one';

  @override
  String get csvImportTooBig =>
      'The file is too big to be a playlist (5 MB and 10,000 tracks at most)';

  @override
  String get csvImportAlsoAccepts =>
      'Also accepted: TuneMyMusic, Soundiiz, Last.fm (CSV), M3U/M3U8, XSPF.';

  @override
  String get csvImportPlanned => 'Matches ready: check them and download';

  @override
  String get csvImportLinkOnly => 'Link only (no downloads)';

  @override
  String get csvImportLinkOnlyHint =>
      'Builds the playlist from what you already have, nothing more';

  @override
  String get csvImportPlanFirst => 'Review before downloading';

  @override
  String get csvImportPlanFirstHint =>
      'Searches everything, then you pick what to download';

  @override
  String get csvImportPlanTitle => 'Matches';

  @override
  String csvImportPlanGo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Download $n songs',
      one: 'Download 1 song',
    );
    return '$_temp0';
  }

  @override
  String get csvImportPlanKnown => 'already downloaded';

  @override
  String get csvImportPlanEmpty => 'Nothing to download';

  @override
  String csvImportBannerPlanned(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n songs to download',
      one: '1 song to download',
    );
    return 'Matches ready: $_temp0';
  }

  @override
  String get settingsAdvanced => 'Advanced';

  @override
  String get importSureThreshold => 'Sure match from';

  @override
  String get importSureThresholdHint =>
      'Above this score an imported song is downloaded without asking';

  @override
  String get importReviewThreshold => 'To review from';

  @override
  String get importReviewThresholdHint =>
      'Between this score and the sure one the song goes to «To review»; below it, to «Not found»';

  @override
  String get importThresholdsReset => 'Restore defaults';

  @override
  String csvImportEstimateHours(int hours, int minutes) {
    return 'Estimated time: about $hours h $minutes min';
  }

  @override
  String csvImportBlocks(int size) {
    return 'Import in blocks of $size';
  }

  @override
  String csvImportBigWarning(int n) {
    return '$n songs to download: it will take hours. In blocks, one after the other, the playlist order stays right and you can stop between blocks.';
  }

  @override
  String get etaLessThanMinute => 'under 1 min';

  @override
  String etaMinutes(int minutes) {
    return 'about $minutes min';
  }

  @override
  String etaHours(int hours, int minutes) {
    return 'about $hours h $minutes min';
  }

  @override
  String get csvImportOwnFolder => 'Folder for this playlist';

  @override
  String get csvImportOwnFolderHint =>
      'Saves the downloads in a sub-folder named after the playlist';

  @override
  String get csvImportNumberFiles => 'Number the files';

  @override
  String get csvImportNumberFilesHint =>
      '07 - Artist - Title: the folder plays in the right order even outside Codecore';

  @override
  String get csvImportFetchCovers => 'Look up covers';

  @override
  String get csvImportFetchCoversHint =>
      'After each download, looks the album cover up on iTunes (album and artist from the file)';

  @override
  String get csvImportExport => 'Export result';

  @override
  String get csvImportExported => 'Result saved';

  @override
  String get csvOutHeaderRow => 'Row';

  @override
  String get csvOutHeaderTitle => 'Title';

  @override
  String get csvOutHeaderArtists => 'Artists';

  @override
  String get csvOutHeaderAlbum => 'Album';

  @override
  String get csvOutHeaderDuration => 'Duration (ms)';

  @override
  String get csvOutHeaderIsrc => 'ISRC';

  @override
  String get csvOutHeaderStatus => 'Result';

  @override
  String get csvOutHeaderNote => 'Reason';

  @override
  String get csvOutHeaderVideo => 'Chosen video';

  @override
  String get csvOutHeaderScore => 'Score';

  @override
  String get importStatusPending => 'To search';

  @override
  String get importStatusQueued => 'Queued';

  @override
  String get importStatusDownloaded => 'Downloaded';

  @override
  String get importStatusLinked => 'Already in library';

  @override
  String get importStatusReview => 'To review';

  @override
  String get importStatusNotFound => 'Not found';

  @override
  String get importStatusFailed => 'Error';

  @override
  String get importStatusSkipped => 'Skipped';

  @override
  String get importStatusPlanned => 'Planned';

  @override
  String get importStatusRemoved => 'Removed from the source';

  @override
  String get importNoteNoResults => 'No results';

  @override
  String get importNoteLowScore => 'Match not sure enough';

  @override
  String get importNoteLinkOnly => 'Link only: not searched';

  @override
  String get importNoteYoutubeOff => 'Downloads are off';

  @override
  String get importNoteDownloadFailed => 'Download failed';

  @override
  String get importNoteLengthOff => 'Length differs from the file';

  @override
  String get importNoteUnchanged => 'Already in the playlist';

  @override
  String get csvImportSync => 'Sync';

  @override
  String csvImportSyncCounts(int added, int removed) {
    return '$added new, $removed removed from the playlist (files stay)';
  }

  @override
  String get csvImportSyncChecking => 'Checking the differences…';

  @override
  String get playbackSpeed => 'Playback speed';

  @override
  String get playbackSpeedHint =>
      'The pitch stays the original one. The sleep timer counts real time, not the song\'s.';

  @override
  String resumeFrom(String time) {
    return 'resume at $time';
  }

  @override
  String get restartFromBeginning => 'Start from the beginning';

  @override
  String get previewTrack => '20 s preview';

  @override
  String get equalizer => 'Equalizer';

  @override
  String get eqOutputSpeaker => 'Speaker';

  @override
  String get eqOutputHeadphones => 'Headphones';

  @override
  String get eqHint =>
      'Each output remembers its own curve: it switches by itself when you plug in headphones.';

  @override
  String get eqPresetFlat => 'Flat';

  @override
  String get eqPresetBass => 'Bass';

  @override
  String get eqPresetVoice => 'Voice';

  @override
  String get eqPresetTreble => 'Treble';

  @override
  String get eqPresetCustom => 'Custom';

  @override
  String get eqReset => 'Reset';

  @override
  String get eqWaiting => 'The bands appear once the first song starts.';

  @override
  String get eqUnavailable => 'The equalizer is not available on this device.';

  @override
  String get transitionMode => 'Between tracks';

  @override
  String get transitionNormal => 'Normal';

  @override
  String get transitionGapless => 'Gapless';

  @override
  String get transitionCrossfade => 'Crossfade';

  @override
  String get transitionHint =>
      'Gapless works best with tracks of the same format (for example all FLAC).';

  @override
  String crossfadeLength(int seconds) {
    return 'Crossfade length: $seconds s';
  }

  @override
  String get crossfadePlainInAlbum => 'Don\'t fade inside an album';

  @override
  String get crossfadePlainInAlbumHint =>
      'Inside an album the tracks follow each other without a gap and without overlapping.';

  @override
  String get selectedRow => 'Selected';

  @override
  String selectedRowAt(int position) {
    return 'Selected, number $position';
  }

  @override
  String get curiositySong => 'About the song';

  @override
  String get curiosityArtist => 'About the artist';

  @override
  String get showMore => 'Show more';

  @override
  String get showLess => 'Show less';

  @override
  String get curiosityNoSong => 'No page about this song';

  @override
  String get curiosityNoArtist => 'No page about the artist';

  @override
  String get themeNew => 'New theme';

  @override
  String get themeEdit => 'Edit';

  @override
  String get themeDuplicate => 'Duplicate';

  @override
  String get themeDelete => 'Delete';

  @override
  String get themeExport => 'Export';

  @override
  String get themeImport => 'Import theme';

  @override
  String get themeName => 'Theme name';

  @override
  String get themeBase => 'Start from';

  @override
  String get themeModeSimple => 'Simple';

  @override
  String get themeModeAdvanced => 'Advanced';

  @override
  String get themeSave => 'Save';

  @override
  String get themeEditorTitle => 'Custom theme';

  @override
  String get themeDiscardTitle => 'Discard the changes?';

  @override
  String get themeDiscardBody =>
      'The changes to this theme have not been saved.';

  @override
  String get themeDiscard => 'Discard';

  @override
  String get themePreview => 'Preview';

  @override
  String get themeResetColor => 'Reset the colour';

  @override
  String get themeContrastTitle => 'Legibility';

  @override
  String get themeContrastLow => 'Hard to read';

  @override
  String get themeContrastOk => 'Readable';

  @override
  String get themeFix => 'Fix';

  @override
  String get themeSaved => 'Theme saved';

  @override
  String get themeLimit => 'You already have 20 themes: delete one';

  @override
  String get themeImported => 'Theme imported';

  @override
  String get themeImportFailed => 'The file is not a valid theme';

  @override
  String get themeDeleted => 'Theme deleted';

  @override
  String get themeMine => 'My themes';

  @override
  String get tokenBg => 'Background';

  @override
  String get tokenSurface1 => 'Surface 1';

  @override
  String get tokenSurface2 => 'Surface 2';

  @override
  String get tokenSurface3 => 'Surface 3';

  @override
  String get tokenAccent => 'Accent';

  @override
  String get tokenAccentSoft => 'Soft accent';

  @override
  String get tokenOnAccent => 'Text on accent';

  @override
  String get tokenText => 'Text';

  @override
  String get tokenTextMuted => 'Secondary text';

  @override
  String get tokenTextFaint => 'Faint text';

  @override
  String get tokenHero => 'Player backdrop';

  @override
  String get tokenError => 'Error';

  @override
  String get pickerHue => 'Hue';

  @override
  String get pickerSv => 'Saturation and brightness';

  @override
  String get pickerAlpha => 'Transparency';

  @override
  String get pickerHex => 'Colour code';

  @override
  String get pickerInvalid => 'Invalid code';

  @override
  String get pickerRecent => 'Recently used';

  @override
  String get contrastTextBg => 'Text on background';

  @override
  String get contrastMutedSurface => 'Secondary text on surface';

  @override
  String get contrastOnAccent => 'Text on accent';

  @override
  String get contrastAccentBg => 'Accent on background';

  @override
  String get themeBackground => 'Page background';

  @override
  String get bgSolid => 'Solid colour';

  @override
  String get bgGradient => 'Gradient';

  @override
  String get bgImage => 'Picture';

  @override
  String get bgGradientEnd => 'End colour';

  @override
  String get bgAngle => 'Direction';

  @override
  String get bgPickImage => 'Choose a picture…';

  @override
  String get bgRemoveImage => 'Remove the picture';

  @override
  String get bgDim => 'Darkening';

  @override
  String get bgBlur => 'Blur';

  @override
  String get bgCoverBackdrop => 'Now playing: tint of the cover';

  @override
  String get blurredChrome => 'Blurred dock and headers';

  @override
  String get blurredChromeHint => 'May slow down less powerful phones';

  @override
  String get bgImageFailed => 'The picture could not be used';

  @override
  String themeCopyName(String name) {
    return '$name (copy)';
  }

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return '$_temp0';
  }

  @override
  String get selectAll => 'Select all';

  @override
  String get exitSelection => 'Exit selection';

  @override
  String get bulkActions => 'Actions';

  @override
  String playNextMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks will play next',
      one: '1 track will play next',
    );
    return '$_temp0';
  }

  @override
  String addedToQueueMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks added to the queue',
      one: '1 track added to the queue',
    );
    return '$_temp0';
  }

  @override
  String addedToPlaylistMany(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks added to “$name”',
      one: '1 track added to “$name”',
    );
    return '$_temp0';
  }

  @override
  String addedToPlaylistSkipped(int added, int skipped, String name) {
    return '$added added to “$name”, $skipped already there';
  }

  @override
  String allAlreadyInPlaylist(String name) {
    return 'They were all in “$name” already';
  }

  @override
  String favoritesAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks added to favorites',
      one: '1 track added to favorites',
    );
    return '$_temp0';
  }

  @override
  String favoritesRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks removed from favorites',
      one: '1 track removed from favorites',
    );
    return '$_temp0';
  }

  @override
  String get bulkAddToFavorites => 'Add to favorites';

  @override
  String get bulkRemoveFromFavorites => 'Remove from favorites';

  @override
  String removeManyFromPlaylistTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Remove $count tracks from the playlist?',
      one: 'Remove 1 track from the playlist?',
    );
    return '$_temp0';
  }

  @override
  String get removeManyFromPlaylistBody =>
      'The files and the library are not touched.';

  @override
  String removedManyFromPlaylist(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks removed',
      one: '1 track removed',
    );
    return '$_temp0';
  }

  @override
  String removeManyFromLibraryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Remove $count tracks from the library?',
      one: 'Remove 1 track from the library?',
    );
    return '$_temp0';
  }

  @override
  String get removeManyFromLibraryBody =>
      'The files no longer exist: they only disappear from the library (you lose these tracks\' favorites and playlist entries).';

  @override
  String removedManyFromLibrary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks removed from the library',
      one: '1 track removed from the library',
    );
    return '$_temp0';
  }

  @override
  String ytDownloadsStarted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count downloads started',
      one: '1 download started',
    );
    return '$_temp0';
  }

  @override
  String ytDownloadsSkipped(int started, int skipped) {
    return '$started downloads started, $skipped already in the library or in progress';
  }

  @override
  String get ytNothingToDownload =>
      'They are all in the library or in progress already';

  @override
  String get themeChiaro => 'Light';

  @override
  String get settingsAccent => 'Accent colour';

  @override
  String get accentViola => 'Violet';

  @override
  String get accentBlu => 'Blue';

  @override
  String get accentAcqua => 'Teal';

  @override
  String get accentVerde => 'Green';

  @override
  String get accentAmbra => 'Amber';

  @override
  String get accentArancio => 'Orange';

  @override
  String get accentRosa => 'Pink';

  @override
  String get accentRosso => 'Red';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStart => 'Get started';

  @override
  String onboardingPageOf(int page, int total) {
    return 'Page $page of $total';
  }

  @override
  String onboardingStepOf(int page, int total) {
    return '$page of $total';
  }

  @override
  String get onboardingWelcomeTitle => 'Welcome to Codecore';

  @override
  String get onboardingWelcomeBody =>
      'Your personal music player: no account, no server. Your music stays on your device.';

  @override
  String get onboardingFoldersTitle => 'Your music';

  @override
  String get onboardingFoldersBody =>
      'Choose the folders where you keep your tracks. Codecore reads them: it never edits or moves them.';

  @override
  String onboardingFoldersAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count folders added',
      one: '1 folder added',
    );
    return '$_temp0';
  }

  @override
  String get onboardingAllowAccess => 'Allow access to audio files';

  @override
  String get onboardingAccessGranted => 'Access granted';

  @override
  String get onboardingOnlineTitle => 'Online features';

  @override
  String get onboardingOnlineBody =>
      'They are off: Codecore never goes online on its own. You can turn them on now or later in Settings.';

  @override
  String get onboardingShareTitle => 'Downloads, Jam and sharing';

  @override
  String get onboardingYoutubeBody =>
      'You can download tracks from YouTube to your device and listen to them like the rest of your music.';

  @override
  String get onboardingJamBody =>
      'With a Jam you listen to the same music together with another device on the same network.';

  @override
  String get onboardingSendBody =>
      'You can send tracks to other nearby devices with a PIN, without going through the Internet.';

  @override
  String get historyTitle => 'History';

  @override
  String get historySubtitle => 'What you listened to';

  @override
  String get historyToday => 'Today';

  @override
  String get historyYesterday => 'Yesterday';

  @override
  String get historyEmpty => 'What you listen to will show up here.';

  @override
  String get historyOff => 'History is off: turn it on in Settings, Playback.';

  @override
  String get historyClear => 'Clear history';

  @override
  String get historyClearTitle => 'Clear the history?';

  @override
  String get historyClearBody =>
      'Only the list of listens is deleted: play counts, favorites and playlists stay as they are.';

  @override
  String get historyCleared => 'History cleared';

  @override
  String get settingsRecordHistory => 'Keep a listening history';

  @override
  String get settingsRecordHistoryHint =>
      'It stays on the device. When off, nothing more is added to the list.';

  @override
  String get statsTitle => 'Statistics';

  @override
  String get statsSubtitle => 'How much and what you listen to';

  @override
  String get statsMonth => 'Month';

  @override
  String get statsYear => 'Year';

  @override
  String get statsPrevious => 'Previous period';

  @override
  String get statsNext => 'Next period';

  @override
  String get statsEmpty => 'No listens in this period.';

  @override
  String statsPlays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count listens',
      one: '1 listen',
    );
    return '$_temp0';
  }

  @override
  String statsDistinct(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count different tracks',
      one: '1 different track',
    );
    return '$_temp0';
  }

  @override
  String statsHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get statsTopTracks => 'Most played tracks';

  @override
  String get statsTopArtists => 'Most played artists';

  @override
  String get statsTopAlbums => 'Most played albums';

  @override
  String get statsFavouriteHour => 'Favorite hour';

  @override
  String get statsFirstListen => 'First listen';

  @override
  String statsFirstValue(String title, String date) {
    return '$title, $date';
  }

  @override
  String get statsYourMonth => 'Your month';

  @override
  String ruleWarning(String term) {
    return 'I don’t understand “$term”: searching it as text.';
  }

  @override
  String get smartPlaylistNew => 'New smart playlist';

  @override
  String get smartPlaylistEdit => 'Edit smart playlist';

  @override
  String get smartPlaylistLabel => 'Smart playlist';

  @override
  String get smartName => 'Name';

  @override
  String get smartNameRequired => 'Enter a name';

  @override
  String get smartRules => 'Rules';

  @override
  String get smartRulesHint => 'artist:\"pink floyd\" -live year:1970..1979';

  @override
  String get smartNoRules =>
      'With no rules the playlist holds the whole library.';

  @override
  String get smartSortBy => 'Sort by';

  @override
  String get smartSortMostPlayed => 'Most played';

  @override
  String get smartSortRandom => 'Random';

  @override
  String get smartLimit => 'Track limit (optional)';

  @override
  String get smartTemplates => 'Templates';

  @override
  String get smartTplNever => 'Never played';

  @override
  String get smartTplRecent => 'Recently added';

  @override
  String get smartTplTop => 'Most played';

  @override
  String get smartTpl90s => 'The ’90s';

  @override
  String get smartConvert => 'Convert to a normal playlist';

  @override
  String smartConverted(String name) {
    return 'Created the playlist “$name” with the current list';
  }

  @override
  String smartDeleteTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String get smartDeleteBody =>
      'Only the rule is deleted: the tracks stay where they are.';

  @override
  String get smartAutoNote => 'The list updates by itself.';

  @override
  String get tagsTitle => 'Tags';

  @override
  String get tagsSubtitle => 'Your own tags';

  @override
  String tagsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tags',
      one: '1 tag',
    );
    return '$_temp0';
  }

  @override
  String get tagsEllipsis => 'Tags…';

  @override
  String get tagNew => 'New tag';

  @override
  String get tagRename => 'Rename tag';

  @override
  String get tagColor => 'Color';

  @override
  String get tagNoColor => 'No color';

  @override
  String get tagNameTaken => 'A tag with this name already exists';

  @override
  String tagDeleteTitle(String name) {
    return 'Delete the tag “$name”?';
  }

  @override
  String get tagDeleteBody =>
      'Only the tag is removed from the tracks: they stay in the library.';

  @override
  String get tagsEmpty => 'No tags yet: create one from a track’s menu.';

  @override
  String get tagAddToSelection => 'Add a tag…';

  @override
  String get tagRemoveFromSelection => 'Remove a tag…';

  @override
  String tagAssigned(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks tagged “$name”',
      one: '1 track tagged “$name”',
    );
    return '$_temp0';
  }

  @override
  String tagUnassigned(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '“$name” removed from $count tracks',
      one: '“$name” removed from 1 track',
    );
    return '$_temp0';
  }

  @override
  String get tagNoneToRemove => 'The chosen tracks have no tags.';

  @override
  String get cleanupSection => 'Library cleanup';

  @override
  String get duplicatesTitle => 'Duplicates';

  @override
  String get duplicatesTileHint =>
      'The same song in several copies or qualities';

  @override
  String get duplicatesIntro =>
      'Looks for the same song in several copies: the same file in two folders, or the same song in two qualities. You see a preview before anything is merged. Favourites, playlists, listens, lyrics and labels move to the track you keep; the others are only hidden, and you can bring them back from “Hidden tracks”. No file is deleted without a double confirmation.';

  @override
  String get duplicatesSearch => 'Find duplicates';

  @override
  String get duplicatesSearchAgain => 'Search again';

  @override
  String get duplicatesReading => 'Reading the library…';

  @override
  String duplicatesHashing(int done, int total) {
    return 'Checking files: $done of $total';
  }

  @override
  String get duplicatesGrouping => 'Comparing tracks…';

  @override
  String get duplicatesFailed => 'The search failed. Try again.';

  @override
  String get duplicatesNone => 'No duplicates found';

  @override
  String duplicatesSummary(int groups, int hidden) {
    String _temp0 = intl.Intl.pluralLogic(
      groups,
      locale: localeName,
      other: '$groups groups',
      one: '1 group',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hidden,
      locale: localeName,
      other: '$hidden tracks to hide',
      one: '1 track to hide',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get duplicatesExactBadge => 'Identical';

  @override
  String get duplicatesProbableBadge => 'Probable';

  @override
  String get duplicatesKeepLabel => 'Keep';

  @override
  String get duplicatesPickKeep => 'Tap a track to keep it';

  @override
  String get duplicatesMerge => 'Merge';

  @override
  String get duplicatesNotDuplicates => 'Not duplicates';

  @override
  String duplicatesMergeAllExact(int count) {
    return 'Merge all identical ($count)';
  }

  @override
  String get duplicatesMergeAllTitle => 'Merge all identical ones?';

  @override
  String duplicatesMergeAllBody(int groups, int hidden) {
    String _temp0 = intl.Intl.pluralLogic(
      groups,
      locale: localeName,
      other: '$groups groups',
      one: '1 group',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hidden,
      locale: localeName,
      other: '$hidden tracks hidden',
      one: '1 track hidden',
    );
    return '$_temp0, $_temp1. Favourites, playlists, listens and lyrics move to the tracks that stay.';
  }

  @override
  String duplicatesMerged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks hidden',
      one: '1 track hidden',
    );
    return 'Merged: $_temp0';
  }

  @override
  String duplicatesDeleteFiles(int count, String size) {
    return 'Also delete the files ($count, $size)';
  }

  @override
  String get duplicatesDeleteListTitle => 'Delete these files?';

  @override
  String get duplicatesDeleteListBody =>
      'They will be erased from the device and cannot be recovered. The tracks you keep stay where they are.';

  @override
  String get duplicatesDeleteContinue => 'Continue';

  @override
  String duplicatesDeleteFinalTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Permanently delete $count files?',
      one: 'Permanently delete 1 file?',
    );
    return '$_temp0';
  }

  @override
  String duplicatesDeleteFinalBody(String size) {
    return 'Space freed: $size. This cannot be undone.';
  }

  @override
  String get duplicatesDeleteGo => 'Delete permanently';

  @override
  String get duplicatesDeleteDoneTitle => 'Done';

  @override
  String duplicatesDeleteDone(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files deleted',
      one: '1 file deleted',
    );
    return '$_temp0 ($size).';
  }

  @override
  String duplicatesDeleteFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files not deleted:',
      one: '1 file not deleted:',
    );
    return '$_temp0';
  }

  @override
  String duplicatesDeleteSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count files left alone: they are the same file as the kept track.',
      one: '1 file left alone: it is the same file as the kept track.',
    );
    return '$_temp0';
  }

  @override
  String get duplicatesDeleteAndroidHint =>
      'On Android only files in folders the app can access can be deleted.';

  @override
  String activityCleanup(int done, int total) {
    return 'Finding duplicates: $done of $total';
  }

  @override
  String get hiddenTracksTitle => 'Hidden tracks';

  @override
  String hiddenTracksCount(int count) {
    return 'Hidden tracks ($count)';
  }

  @override
  String get hiddenTracksEmpty => 'No hidden tracks';

  @override
  String get hiddenTracksHint =>
      'Merged duplicates do not appear in the library. “Restore” puts them back.';

  @override
  String get hiddenRestore => 'Restore';

  @override
  String hiddenRestored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks restored',
      one: '1 track restored',
    );
    return '$_temp0';
  }

  @override
  String get albumMergeWith => 'Merge with…';

  @override
  String get albumMergeTitle => 'Merge albums';

  @override
  String albumMergeIntro(String name) {
    return 'Pick the albums to merge into “$name”. The tracks move to one album with the title and artist you give; the cover stays the one of “$name”.';
  }

  @override
  String get albumMergeSearch => 'Search an album';

  @override
  String get albumMergeNone => 'There are no other albums';

  @override
  String get albumFieldTitle => 'Album title';

  @override
  String get albumFieldArtist => 'Album artist';

  @override
  String get albumMergeAction => 'Merge albums';

  @override
  String albumMerged(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count albums merged into “$name”',
      one: '1 album merged into “$name”',
    );
    return '$_temp0';
  }

  @override
  String get moveToAlbum => 'Move to a new album…';

  @override
  String get moveToAlbumTitle => 'Move to an album';

  @override
  String moveToAlbumBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks will go',
      one: '1 track will go',
    );
    return '$_temp0 to the album you name. If it already exists, they join it.';
  }

  @override
  String get moveToAlbumGo => 'Move';

  @override
  String movedToAlbum(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks moved to “$name”',
      one: '1 track moved to “$name”',
    );
    return '$_temp0';
  }

  @override
  String get searchSourceYoutube => 'YouTube';

  @override
  String get searchSourceYoutubeMusic => 'YouTube Music';

  @override
  String get searchSourceSoundcloud => 'SoundCloud';

  @override
  String get playlistSourceTitle => 'YouTube playlist or channel';

  @override
  String get playlistSourceLoading => 'Reading the list of videos…';

  @override
  String get playlistSourceName => 'Playlist name';

  @override
  String playlistSourceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos',
      one: '1 video',
    );
    return '$_temp0';
  }

  @override
  String playlistSourceUnavailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos unavailable (private or removed)',
      one: '1 video unavailable (private or removed)',
    );
    return '$_temp0';
  }

  @override
  String playlistSourceTruncated(int count) {
    return 'Showing the first $count videos.';
  }

  @override
  String playlistSourceLong(int count, String time) {
    return 'That is $count videos: it will take $time.';
  }

  @override
  String get playlistSourceNone => 'None';

  @override
  String get playlistSourceEmpty => 'There are no videos to download here.';

  @override
  String playlistSourceGo(int count) {
    return 'Download into a playlist ($count)';
  }

  @override
  String playlistSourceStarted(String name) {
    return 'Downloads started in the playlist “$name”';
  }

  @override
  String get podcastsTitle => 'Podcasts';

  @override
  String podcastsSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count podcasts',
      one: '1 podcast',
    );
    return '$_temp0';
  }

  @override
  String get podcastsNotice => 'Podcasts are only refreshed when you ask.';

  @override
  String get podcastsEmpty => 'You are not subscribed to any podcast.';

  @override
  String get podcastAdd => 'Add a podcast';

  @override
  String get podcastRefreshAll => 'Refresh all';

  @override
  String get podcastRefresh => 'Refresh';

  @override
  String podcastRefreshed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new episodes',
      one: '1 new episode',
      zero: 'No new episodes',
    );
    return '$_temp0';
  }

  @override
  String podcastRefreshFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count podcasts could not be refreshed',
      one: '1 podcast could not be refreshed',
    );
    return '$_temp0';
  }

  @override
  String get podcastFeedUrl => 'Feed address';

  @override
  String get podcastSubscribe => 'Subscribe';

  @override
  String get podcastSearchHint => 'Search a podcast by name';

  @override
  String get podcastSearchNone => 'No podcast found';

  @override
  String podcastSubscribed(String name) {
    return 'Subscribed to “$name”';
  }

  @override
  String podcastEpisodesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count episodes',
      one: '1 episode',
    );
    return '$_temp0';
  }

  @override
  String podcastToListen(int count) {
    return '$count to listen to';
  }

  @override
  String get podcastNoEpisodes => 'No episodes.';

  @override
  String get podcastStateDownloaded => 'Downloaded';

  @override
  String podcastStateDownloading(int percent) {
    return 'Downloading… $percent%';
  }

  @override
  String get podcastStateHeard => 'Heard';

  @override
  String podcastStateRemaining(String time) {
    return '$time left';
  }

  @override
  String get podcastMarkHeard => 'Mark as heard';

  @override
  String get podcastMarkNotHeard => 'Mark as not heard';

  @override
  String get podcastDeleteFile => 'Delete the file';

  @override
  String get podcastAutoDelete => 'Delete heard episodes';

  @override
  String get podcastAutoDeleteNever => 'Never';

  @override
  String podcastAutoDeleteAfter(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get podcastUnsubscribe => 'Unsubscribe';

  @override
  String get podcastUnsubscribeTitle => 'Unsubscribe?';

  @override
  String podcastUnsubscribeBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count downloaded episodes',
      one: '1 downloaded episode',
    );
    return 'The podcast and $_temp0 will be deleted from the device.';
  }

  @override
  String podcastLastChecked(String when) {
    return 'Updated $when';
  }

  @override
  String get podcastNeverChecked => 'Never refreshed';

  @override
  String get podcastErrInvalidUrl =>
      'That does not look like a valid web address.';

  @override
  String get podcastErrTooLarge => 'The feed is too big.';

  @override
  String get podcastErrNetwork => 'Could not reach the server.';

  @override
  String get podcastErrNotFeed => 'That address is not a podcast feed.';

  @override
  String get podcastErrUnsupportedFormat => 'Unsupported audio format.';

  @override
  String get syncTitle => 'Sync playlists';

  @override
  String syncAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new',
      one: '1 new',
    );
    return '$_temp0';
  }

  @override
  String syncUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count updated',
      one: '1 updated',
    );
    return '$_temp0';
  }

  @override
  String syncMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks missing',
      one: '1 track missing',
    );
    return '$_temp0';
  }

  @override
  String get syncUpToDate => 'Playlists are already in sync';

  @override
  String syncKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count playlists are newer here and stay as they are',
      one: '1 playlist is newer here and stays as it is',
    );
    return '$_temp0';
  }

  @override
  String get syncReplaceNote =>
      'Updated playlists replace the ones on this device.';

  @override
  String get syncTagNew => 'New';

  @override
  String get syncTagUpdated => 'Updated';

  @override
  String get syncDetailRenamed => 'renamed';

  @override
  String get syncDetailReordered => 'reordered';

  @override
  String syncDetailRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks removed',
      one: '1 track removed',
    );
    return '$_temp0';
  }

  @override
  String get syncAskMissing => 'Ask for the missing tracks';

  @override
  String syncApplied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count playlists synced',
      one: '1 playlist synced',
    );
    return '$_temp0';
  }

  @override
  String get trustedSection => 'Trusted devices';

  @override
  String trustedFingerprint(String fingerprint) {
    return 'Fingerprint $fingerprint';
  }

  @override
  String trustedPairedOn(String date) {
    return 'Paired on $date';
  }

  @override
  String get trustedAutoAccept => 'Accept automatically';

  @override
  String get trustedAutoAcceptHint =>
      'Receive tracks from this device without asking.';

  @override
  String get trustedRevoke => 'Revoke';

  @override
  String trustedRevokeTitle(String name) {
    return 'Revoke “$name”?';
  }

  @override
  String get trustedRevokeBody =>
      'To send without a PIN again you will have to pair again.';

  @override
  String get carMode => 'Car mode';

  @override
  String get carExit => 'Exit';

  @override
  String get carKeepAwake => 'Keep screen on';

  @override
  String get carPlaylists => 'Playlists';

  @override
  String get carNothing => 'Nothing playing';

  @override
  String get updateCheck => 'Check for updates';

  @override
  String get updateCheckHint =>
      'Asks GitHub for the latest version, only when you ask.';

  @override
  String get updateOnStart => 'Check at start-up';

  @override
  String get updateOnStartHint =>
      'At most once a day. Downloads and installs nothing.';

  @override
  String get updateChecking => 'Checking…';

  @override
  String updateAvailable(String version) {
    return 'Version $version is available';
  }

  @override
  String updateUpToDate(String version) {
    return 'You have the latest version ($version)';
  }

  @override
  String get updateRateLimited => 'GitHub asks you to wait: try again later.';

  @override
  String get updateFailed =>
      'I can’t read the latest version. Check your connection.';

  @override
  String get updateCopyLink => 'Copy address';

  @override
  String get updateLinkCopied => 'Address copied';

  @override
  String get backupSection => 'Backup';

  @override
  String get backupCreate => 'Create backup';

  @override
  String get backupCreateHint =>
      'Playlists, favourites, lyrics and edits in a zip file. No music inside.';

  @override
  String get backupRestore => 'Restore from backup';

  @override
  String get backupRestoreHint =>
      'Replace this library or merge the data of another device.';

  @override
  String get backupCreating => 'Creating the backup…';

  @override
  String get backupSaved => 'Backup saved';

  @override
  String get backupFailed => 'Backup failed';

  @override
  String get restoreTitle => 'Restore from backup';

  @override
  String restoreInfo(String date, String version, int tracks, int playlists) {
    return 'From $date, app $version, $tracks tracks, $playlists playlists';
  }

  @override
  String get restoreReplace => 'Replace everything (same device)';

  @override
  String get restoreMerge => 'Merge into this library';

  @override
  String get restoreMergeHint =>
      'Adds favourites, playlists, lyrics and edits to the tracks it finds. Deletes nothing.';

  @override
  String get restoreReplaceConfirmTitle => 'Replace the whole library?';

  @override
  String get restoreReplaceConfirmBody =>
      'At the next start this app’s data becomes the backup’s. The current data stays in a safety copy next to the database.';

  @override
  String get restoreReplaceGo => 'Replace';

  @override
  String get restoreNotBackup =>
      'This file is not a Codecore backup I can read.';

  @override
  String get restoreRestartNeeded =>
      'Ready: close the app and open it again to finish the restore.';

  @override
  String restoreMergeDone(
    int recognized,
    int missing,
    int playlists,
    int favorites,
  ) {
    return 'Merge done: $recognized tracks recognised, $missing not found, $playlists playlists created, $favorites favourites added.';
  }

  @override
  String get restoreNotFound => 'Tracks not found';

  @override
  String get restoreCopyList => 'Copy list';

  @override
  String get restoreFailed => 'Restore failed';

  @override
  String get exportAllPlaylists => 'Export all playlists';

  @override
  String get shareErrIdentity =>
      'This device’s identity has changed: remove it from the trusted ones and pair again.';

  @override
  String get incomingTrustedTag => 'Trusted device';

  @override
  String incomingTrustedTitle(String name) {
    return '$name (trusted)';
  }

  @override
  String get pairAction => 'Pair';

  @override
  String get trustedBadge => 'Trusted';

  @override
  String pairPinTitle(String name) {
    return 'Pairing with $name';
  }

  @override
  String pairPinHint(String name) {
    return 'Type the 6-digit PIN shown on $name.';
  }

  @override
  String pairPinWrong(int count) {
    return 'Wrong PIN. Attempts left: $count.';
  }

  @override
  String pairFingerprint(String fingerprint) {
    return 'Fingerprint: $fingerprint';
  }

  @override
  String get pairCompare =>
      'Check that the fingerprint is the same on the other screen.';

  @override
  String pairRequestTitle(String name) {
    return '$name wants to pair';
  }

  @override
  String get pairRequestBody =>
      'Type this PIN on the other device, then tap Confirm.';

  @override
  String get pairConfirm => 'Confirm';

  @override
  String get pairWaiting => 'Waiting for the confirmation on the other device…';

  @override
  String pairDone(String name) {
    return 'Paired with $name';
  }

  @override
  String get pairBlocked => 'Too many wrong attempts: try again later.';

  @override
  String get pairRejected => 'Pairing refused.';

  @override
  String get pairExpired => 'The request expired: try again.';

  @override
  String get pairFailed => 'Pairing failed.';

  @override
  String get syncDevice => 'Sync playlists';

  @override
  String get syncUnreachable =>
      'The device is not visible on the local network.';

  @override
  String get syncFailed => 'Sync failed.';

  @override
  String syncAsked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Request sent: $count tracks on their way',
      one: 'Request sent: 1 track on its way',
      zero: 'None of the tracks is on the other device',
    );
    return '$_temp0';
  }

  @override
  String get translateLyrics => 'Translate';

  @override
  String get translateLyricsFrom => 'Lyrics language';

  @override
  String get translateLyricsHint =>
      'Translated on the phone, no text is sent over the network.';

  @override
  String get translateRemove => 'Show original only';

  @override
  String translateDownloadTitle(String language) {
    return 'Download the $language model?';
  }

  @override
  String translateDownloadBody(int mb) {
    return 'About $mb MB per language, better on Wi-Fi. It is downloaded once and then works offline too.';
  }

  @override
  String get translateDownload => 'Download';

  @override
  String translateDownloading(String language) {
    return 'Downloading the $language model…';
  }

  @override
  String get translateDownloadFailed =>
      'Model not downloaded. Check the connection and the free space.';

  @override
  String get translateFailed => 'Translation failed.';

  @override
  String get translateSameLanguage =>
      'The lyrics are already in this language.';

  @override
  String get translationModels => 'Translation models';

  @override
  String get translationModelsNone =>
      'No model downloaded. They are downloaded from the lyrics screen, with “Translate”.';

  @override
  String translationModelDelete(String language) {
    return 'Delete the $language model';
  }

  @override
  String get scanCode => 'Scan code';

  @override
  String get scanTitle => 'Point at the QR code';

  @override
  String get scanNotCodecore => 'This code is not from Codecore.';

  @override
  String get scanCameraDenied =>
      'The camera permission is needed to read the code.';

  @override
  String get scanOpenSettings => 'Open settings';

  @override
  String get ownFingerprint => 'This device’s fingerprint';

  @override
  String get ownFingerprintHint =>
      'Compare it with the one shown on the other screen when pairing.';

  @override
  String get writeTagsToFiles => 'Write edits into the files';

  @override
  String get writeTagsToFilesHint =>
      'Title, artist, album, year, genre and track edited here are also written into MP3, FLAC, M4A and OGG files. The original of every file is kept. Off by default.';

  @override
  String get writeTagsAfterDownload => 'Write tags into downloaded files';

  @override
  String get writeTagsAfterDownloadHint =>
      'Only in files Codecore downloaded or received. The ISRC stays in the app.';

  @override
  String get writeTagsWarnTitle => 'Write edits into the files?';

  @override
  String get writeTagsWarnBody =>
      'When you save an edit, the tags are rewritten in the music file too (MP3, FLAC, M4A, OGG). The work is done on a copy, the result is checked, and the file is replaced only if everything matches; the original is saved first in “Tag backups” (the last 200 or 2 GB). Cover, lyrics and ReplayGain are not touched. Before turning this on, make a library backup (Settings, Backup).';

  @override
  String get writeTagsEnable => 'Turn on';

  @override
  String get tagsAlsoInFile => 'Also write to the file';

  @override
  String tagsNoWriteUnsupported(String format) {
    return 'This format cannot be edited ($format): only the library changes';
  }

  @override
  String get tagsNoWriteReadOnly => 'Read-only file: only the library changes';

  @override
  String get tagsNoWriteMissing => 'File not found: only the library changes';

  @override
  String tagsFileWriteFailed(int count, String reason) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files were not changed',
      one: '1 file was not changed',
    );
    return 'Saved in the library, but $_temp0: $reason';
  }

  @override
  String get tagReasonUnsupported => 'unsupported format';

  @override
  String get tagReasonNotFound => 'file not found';

  @override
  String get tagReasonReadOnly => 'read-only file';

  @override
  String get tagReasonVerifyFailed =>
      'the check after writing failed, the file was left as it was';

  @override
  String get tagReasonWriteFailed =>
      'writing failed, the file was left as it was';

  @override
  String get tagReasonBackupFailed =>
      'could not back up the original, the file was left as it was';

  @override
  String get tagReasonIoError => 'disk or permission error';

  @override
  String get tagBackupsTitle => 'Tag backups';

  @override
  String tagBackupsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tag backups ($count)',
      one: 'Tag backups (1)',
      zero: 'Tag backups',
    );
    return '$_temp0';
  }

  @override
  String get tagBackupsHint =>
      'The original of every rewritten file, as it was before the edit. The last 200 or 2 GB are kept.';

  @override
  String get tagBackupsEmpty => 'No backups: no file has been rewritten yet.';

  @override
  String get tagBackupRestore => 'Restore original';

  @override
  String tagBackupRestoreBody(String name) {
    return 'The file “$name” goes back to how it was before the edit. The library keeps the edits made in the app.';
  }

  @override
  String get tagBackupRestored => 'Original restored';

  @override
  String tagBackupRestoreFailed(String reason) {
    return 'Restore failed: $reason';
  }

  @override
  String get tagBackupDelete => 'Delete backup';

  @override
  String get tagBackupDeleteBody =>
      'You will no longer be able to bring the file back to how it was before the edit.';

  @override
  String get tagBackupDeleted => 'Backup deleted';

  @override
  String get deleteFromDevice => 'Delete from device';

  @override
  String deleteTrackTitle(String title) {
    return 'Delete “$title”?';
  }

  @override
  String get deleteTrackBody =>
      'The file is deleted from the device and the track disappears from the library, playlists, favourites and history. This cannot be undone.';

  @override
  String deleteTracksTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count tracks?',
      one: 'Delete 1 track?',
    );
    return '$_temp0';
  }

  @override
  String get deleteTracksBody =>
      'The files are deleted from the device and the tracks disappear from the library, playlists, favourites and history. This cannot be undone.';

  @override
  String get deleteConfirm => 'Delete';

  @override
  String get trackDeleted => 'Track deleted';

  @override
  String trackDeleteFailed(String reason) {
    return 'Could not delete the file: $reason';
  }

  @override
  String tracksDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks deleted',
      one: '1 track deleted',
    );
    return '$_temp0';
  }

  @override
  String tracksDeletedSome(int count, int failed) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks deleted',
      one: '1 track deleted',
    );
    return '$_temp0, $failed not deleted';
  }

  @override
  String get trackDeleteRefused =>
      'Android did not allow the file to be deleted';

  @override
  String get reviewTitle => 'To review';

  @override
  String get reviewFilterAll => 'All';

  @override
  String get reviewFilterNothingFound => 'Nothing found';

  @override
  String get reviewFilterNoLyrics => 'No lyrics';

  @override
  String get reviewFilterNoCover => 'No cover';

  @override
  String get reviewFilterMissingData => 'Missing data';

  @override
  String get reviewEmpty =>
      'Nothing to review: no searched track is missing anything';

  @override
  String get reviewHint =>
      'Tracks missing something. Search again or leave them as they are.';

  @override
  String get reviewRetry => 'Retry';

  @override
  String get reviewDismiss => 'Ignore';

  @override
  String reviewRetryStarted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
    );
    return 'Search started for $_temp0';
  }

  @override
  String reviewDismissed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks removed from the list',
      one: '1 track removed from the list',
    );
    return '$_temp0';
  }

  @override
  String reviewSecondOpinionProgress(int done, int total) {
    return 'Checking with YouTube Music, $done of $total';
  }

  @override
  String get reviewSecondOpinionStop => 'Stop';

  @override
  String reviewSecondOpinionDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Updated $count songs with YouTube Music',
      one: 'Updated 1 song with YouTube Music',
    );
    return '$_temp0';
  }

  @override
  String get reviewSecondOpinionThrottled =>
      'YouTube Music asked to slow down: the remaining songs will be checked later';

  @override
  String activitySecondOpinion(int done, int total) {
    return 'Second opinion: $done of $total';
  }

  @override
  String get secondOpinionLogTitle => 'Second opinion';

  @override
  String get secondOpinionLogEmpty => 'No tracks checked yet';

  @override
  String get secondOpinionConfirmed => 'Confirmed, nothing to add';

  @override
  String secondOpinionConfirmedFields(String fields) {
    return 'Confirmed, added: $fields';
  }

  @override
  String get secondOpinionNotConfirmed => 'Not confirmed';

  @override
  String get secondOpinionNetwork => 'Network unavailable, to retry';

  @override
  String get secondOpinionThrottled => 'YouTube Music asked to slow down';

  @override
  String get sourceYoutubeMusic => 'Source: YouTube Music';

  @override
  String get curiositySourceDiscogs => 'From the album, via Discogs';

  @override
  String get navMemory => 'Storage';

  @override
  String get memoryMusicLabel => 'Music';

  @override
  String get memoryOtherLabel => 'Other';

  @override
  String get memoryFreeLabel => 'Free';

  @override
  String memoryDeviceLine(String free, String total) {
    return '$free free of $total';
  }

  @override
  String get memoryPlaylists => 'Playlists';

  @override
  String get memoryPlaylistsNote =>
      'A track in several playlists counts in each one, so the sum can exceed the total.';

  @override
  String get memoryByFormat => 'Formats';

  @override
  String get memoryByFolder => 'Folders';

  @override
  String get memoryNoFolder => 'Outside the folders';

  @override
  String get memoryHeaviest => 'Heaviest';

  @override
  String get memoryHeaviestTracks => 'Tracks';

  @override
  String get memoryHeaviestAlbums => 'Albums';

  @override
  String get memoryNeverPlayed => 'Never played';

  @override
  String get memoryNeverPlayedHint =>
      'Tracks that were never played. Select some to delete them from the device.';

  @override
  String get memoryNeverPlayedNone => 'You have played all your music';

  @override
  String get memoryAppData => 'App data';

  @override
  String get memoryCovers => 'Covers';

  @override
  String memoryCoversThumbs(String size) {
    return 'of which thumbnails $size';
  }

  @override
  String get memoryDatabase => 'Library';

  @override
  String get memoryImageMemory => 'Images in memory';

  @override
  String get memoryJamCache => 'Jam cache';

  @override
  String get memorySearchCache => 'Search cache';

  @override
  String get memoryCatalogCache => 'Online catalog';

  @override
  String get memoryBlurCopies => 'Blurred backgrounds';

  @override
  String get memoryTagBackups => 'Tag backups';

  @override
  String get memoryLog => 'Log';

  @override
  String get memoryPodcasts => 'Podcast episodes';

  @override
  String get memoryClearCache => 'Clear cache';

  @override
  String memoryCleared(String size) {
    return '$size freed';
  }

  @override
  String memoryClearedJamKept(String size) {
    return '$size freed. The Jam cache is in use and was left alone';
  }

  @override
  String get memoryClearFailed => 'Could not clear the cache';

  @override
  String get memoryOfMusic => 'of music';

  @override
  String get memoryShowAll => 'Show all';

  @override
  String get memoryCache => 'Cache';

  @override
  String get memoryCacheHint => 'Images, searches, Jam';

  @override
  String get memoryDatabaseHint => 'The database with tracks and plays';

  @override
  String get memoryTagBackupsHint => 'Before every change to the files';

  @override
  String get memoryTinyNote => 'Data under 1 MB is not listed.';

  @override
  String memoryClearHint(String size) {
    return 'Frees $size. Tracks, covers and plays stay.';
  }

  @override
  String memoryDuplicateGroups(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString groups',
      one: '1 group',
    );
    return '$_temp0';
  }

  @override
  String get memoryTools => 'Tools';

  @override
  String get memoryUnavailable => 'Not available';

  @override
  String ytmArtistWithAudience(String audience) {
    return 'Artist, $audience';
  }

  @override
  String ytmOffline(String date) {
    return 'Offline, data from $date';
  }

  @override
  String get ytmArtistNotFound => 'Artist not found';

  @override
  String get ytmPageUnreadable =>
      'The page cannot be read (YouTube changed something)';

  @override
  String get ytmArtistUnreadable =>
      'The artist page cannot be read (YouTube changed something)';

  @override
  String ytmSearchSongsOf(String name) {
    return 'Search songs by $name';
  }

  @override
  String get ytmInYourLibrary => 'In your library';

  @override
  String get ytmAbout => 'About';

  @override
  String get ytmMore => 'More';

  @override
  String get ytmLess => 'Less';

  @override
  String get ytmDownloadAlbum => 'Download album';

  @override
  String ytmDownloadAlbumTitle(String album) {
    return 'Download “$album”?';
  }

  @override
  String ytmAlbumConfirmBody(int tracks, String duration, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      tracks,
      locale: localeName,
      other: '$tracks songs',
      one: '1 song',
    );
    return '$_temp0, $duration, about $size';
  }

  @override
  String ytmAlbumConfirmOwned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs are already in your library and will be linked',
      one: '1 song is already in your library and will be linked',
    );
    return '$_temp0';
  }

  @override
  String ytmAlbumStarted(String name) {
    return 'Import “$name” started';
  }

  @override
  String get ytmShowImport => 'Show';

  @override
  String get ytmOnYoutubeMusic => 'On YouTube Music';

  @override
  String get ytmArtistOnYoutubeMusic => 'Artist on YouTube Music';

  @override
  String get ytmSearchingArtist => 'Searching YouTube Music…';

  @override
  String get ytmPickArtist => 'Which artist?';

  @override
  String get ytmArtistNone => 'No artist found on YouTube Music';

  @override
  String get suggestedBadge => 'Suggested';

  @override
  String suggestedSimilarTo(String seed) {
    return 'Suggested: similar to “$seed”';
  }

  @override
  String get suggestionDownloadStarted => 'Download started';

  @override
  String suggestionAddWhenDownloaded(String name) {
    return 'Downloading it and adding it to “$name”';
  }

  @override
  String get suggestionDislike => 'Don’t like it';

  @override
  String get suggestionDisliked => 'It won’t be suggested again';

  @override
  String get removeFromQueueAction => 'Remove from queue';

  @override
  String get shuffleModeOff => 'Shuffle: off';

  @override
  String get shuffleModeOn => 'Shuffle: on';

  @override
  String get shuffleModePlus => 'Shuffle+: on (long press for settings)';

  @override
  String get shufflePlusTitle => 'Shuffle+';

  @override
  String get shufflePlusNote =>
      'Turns on from the shuffle button (third tap). Not available for streaming albums, Jam and radio';

  @override
  String shufflePlusEvery(int n) {
    return 'One suggestion every $n songs';
  }

  @override
  String get shufflePlusUnmeteredOnly => 'Wi‑Fi only';

  @override
  String get shufflePlusUnmeteredOnlyHint =>
      'No suggestions on mobile data or metered networks.';

  @override
  String get shufflePlusData =>
      'Estimated use: about 15 MB an hour with one suggestion every 4 songs.';

  @override
  String get shufflePlusActive => 'On: suggestions arrive while you listen.';

  @override
  String get shufflePlusOff => 'Off: shuffle stays normal.';

  @override
  String get shufflePlusBlockJam => 'Not active during a Jam';

  @override
  String get shufflePlusBlockShort => 'Needs a list of at least 5 songs';

  @override
  String get shufflePlusBlockNoTool => 'yt-dlp not available';

  @override
  String get shufflePlusBlockMetered => 'Paused: metered network';

  @override
  String get shufflePlusBlockStopped =>
      'Off until restart: too many playback errors';

  @override
  String get shufflePlusBlockOnline => 'Not available for a streaming album';

  @override
  String get shufflePlusBlockRadio => 'Not available with radio';

  @override
  String get shufflePlusNoticeRateLimited =>
      'YouTube asks to slow down: suggestions are paused for 15 minutes';

  @override
  String get shufflePlusNoticeTooManyErrors =>
      'Too many playback errors: suggestions are off until restart';

  @override
  String get suggestionsRecentTitle => 'Recently suggested';

  @override
  String get suggestionsRecentEmpty =>
      'Nothing suggested yet. Songs show up here when you use Shuffle+.';

  @override
  String get suggestionsClear => 'Clear history';

  @override
  String get suggestionsClearBody =>
      'Forgets the suggestions and the «Dislike» marks: songs may come back.';

  @override
  String suggestionsRowNote(String seed, String outcome) {
    return 'similar to «$seed», $outcome';
  }

  @override
  String get suggestionOutcomeQueued => 'Queued';

  @override
  String get suggestionOutcomeSkipped => 'Skipped';

  @override
  String get suggestionOutcomeHeard => 'Heard';

  @override
  String get suggestionOutcomeDownloaded => 'Downloaded';

  @override
  String get suggestionOutcomeDisliked => 'Disliked';

  @override
  String get memorySuggestions => 'Shuffle+ suggestions';

  @override
  String searchOnline(String query) {
    return 'Search “$query” online';
  }

  @override
  String get onlineBestResults => 'Best results';

  @override
  String onlineOthersChip(int count) {
    return 'Other results ($count)';
  }

  @override
  String get onlineNoneSure => 'No sure result';

  @override
  String get onlineInLibrary => 'In your library';

  @override
  String onlineShowAllCount(int count) {
    return 'Show all ($count)';
  }

  @override
  String onlineOwnedHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results already in your library hidden',
      one: '1 result already in your library hidden',
    );
    return '$_temp0';
  }

  @override
  String onlineArtistSongs(String artist) {
    return 'Songs by $artist';
  }

  @override
  String get onlineFilterAll => 'All';

  @override
  String get onlineSourceVideo => 'Video';

  @override
  String get onlineAlsoVideo => 'also as a video';

  @override
  String get onlineListenVideo => 'Listen to the video';

  @override
  String onlineNoticeRateLimited(String source, String other) {
    return '$source asked to slow down: results only from $other';
  }

  @override
  String onlineNoticeFailed(String source, String other) {
    return '$source did not answer: results only from $other';
  }

  @override
  String get radioTitle => 'Radio';

  @override
  String radioLibrarySubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saved stations',
      one: '1 saved station',
      zero: 'Live stations',
    );
    return '$_temp0';
  }

  @override
  String get radioSearchHint => 'Search for a station';

  @override
  String radioOnlyCountry(String country) {
    return 'Only $country';
  }

  @override
  String get radioMine => 'My stations';

  @override
  String get radioNearYou => 'Near you';

  @override
  String get radioGenres => 'Genres';

  @override
  String get radioTopListened => 'Most listened';

  @override
  String get radioChooseRegion => 'Choose your region';

  @override
  String get radioRegionHint =>
      'Nearby stations come from the country and region you pick: the app does not use your location.';

  @override
  String radioCountryChip(String country) {
    return 'Country: $country';
  }

  @override
  String get radioChooseCountry => 'Choose a country';

  @override
  String radioOfflineList(String date) {
    return 'Offline, list from $date';
  }

  @override
  String get radioLoadFailed => 'Could not load the stations';

  @override
  String get radioNoResults => 'No stations found';

  @override
  String get radioResults => 'Results';

  @override
  String get radioSave => 'Save to My stations';

  @override
  String get radioUnsave => 'Remove from My stations';

  @override
  String get radioSavedDone => 'Station saved';

  @override
  String get radioRemovedDone => 'Station removed';

  @override
  String get radioNotResponding => 'not responding';

  @override
  String get radioLive => 'Live';

  @override
  String get reasonRadioUnavailable => 'the station is not responding';

  @override
  String radioDataPerHour(String mb) {
    return '≈ $mb MB per hour';
  }

  @override
  String get radioSite => 'Station website';

  @override
  String get radioSiteCopied => 'Website address copied';

  @override
  String get radioSearchSong => 'Search for this song';

  @override
  String get radioRenameTitle => 'Station name';

  @override
  String get radioMobileNotice => 'Radio uses about 1 MB of data per minute.';

  @override
  String get radioAddAddress => 'Add an address';

  @override
  String get radioAddName => 'Name';

  @override
  String get radioAddUrl => 'Stream address';

  @override
  String get radioAddTest => 'Try for 10 seconds';

  @override
  String get radioAddTesting => 'Trying… if you hear it, you can save it.';

  @override
  String get radioLinkEmpty => 'Enter the stream address';

  @override
  String get radioLinkNotAnAddress =>
      'That does not look like an address: write it in full, e.g. https://…';

  @override
  String get radioLinkBadScheme =>
      'The address must start with http:// or https://';

  @override
  String get radioLinkNoEntries => 'The file contains no address to play';

  @override
  String get radioLinkTooBig => 'The file is too big to be a station list';

  @override
  String get radioLinkFetchFailed => 'Could not download the file';

  @override
  String get radioReorder => 'Drag to reorder';

  @override
  String get radioReorderFailed => 'Couldn\'t save the new order';

  @override
  String get memoryRadio => 'Radio (station lists)';

  @override
  String get radioGenrePop => 'Pop';

  @override
  String get radioGenreRock => 'Rock';

  @override
  String get radioGenreClassicRock => 'Classic rock';

  @override
  String get radioGenreJazz => 'Jazz';

  @override
  String get radioGenreBlues => 'Blues';

  @override
  String get radioGenreClassical => 'Classical';

  @override
  String get radioGenreDance => 'Dance';

  @override
  String get radioGenreElectronic => 'Electronic';

  @override
  String get radioGenreHouse => 'House';

  @override
  String get radioGenreHipHop => 'Hip hop';

  @override
  String get radioGenreLoFi => 'Lo-fi';

  @override
  String get radioGenreChillout => 'Chillout';

  @override
  String get radioGenreSixties => '60s';

  @override
  String get radioGenreSeventies => '70s';

  @override
  String get radioGenreEighties => '80s';

  @override
  String get radioGenreNineties => '90s';

  @override
  String get radioGenreOldies => 'Oldies';

  @override
  String get radioGenreMetal => 'Metal';

  @override
  String get radioGenreReggae => 'Reggae';

  @override
  String get radioGenreLatin => 'Latin';

  @override
  String get radioGenreSoul => 'Soul';

  @override
  String get radioGenreNews => 'News';

  @override
  String get radioGenreTalk => 'Talk';

  @override
  String get radioGenreSports => 'Sports';

  @override
  String get newReleasesTitle => 'New releases';

  @override
  String get releasesTopArtists =>
      'Follow your most listened artists automatically';

  @override
  String get releasesTopArtistsHint =>
      'The 15 most played artists of the last 90 days, looked up on YouTube Music.';

  @override
  String get releasesNotify => 'New release notifications';

  @override
  String get releasesNotifyHint => 'At most one a day, Android only.';

  @override
  String get releasesUnmetered => 'Check on Wi‑Fi only';

  @override
  String get releasesUnmeteredHint => 'A daily check uses about 0.5 MB.';

  @override
  String get releasesTopCardTitle =>
      'Want to know when your most listened artists release new music?';

  @override
  String get releasesTopCardYes => 'Turn on';

  @override
  String get releasesTopCardNo => 'No thanks';

  @override
  String get releasesCheckNow => 'Check now';

  @override
  String releasesLastCheck(String when) {
    return 'Last check: $when';
  }

  @override
  String get releasesNeverChecked => 'Never checked';

  @override
  String releasesPaused(String time) {
    return 'YouTube asks for a pause: trying again at $time';
  }

  @override
  String get releasesChecking => 'Checking…';

  @override
  String get releasesCheckNone => 'No new releases';

  @override
  String releasesCheckFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new releases',
      one: '1 new release',
    );
    return '$_temp0';
  }

  @override
  String get releasesCantCheck =>
      'Can’t check now: no network or no followed artist.';

  @override
  String get releasesChanged =>
      'YouTube Music changed its format: trying again next round.';

  @override
  String get releasesEmpty =>
      'No new releases in the last 90 days. Open an artist page and tap “Follow”.';

  @override
  String get releasesAllArtists => 'All';

  @override
  String releasesFollowedTitle(int count) {
    return 'Followed artists ($count)';
  }

  @override
  String get releasesFollowedLibrary => 'Followed artists';

  @override
  String releasesFollowedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artists',
      one: '1 artist',
    );
    return '$_temp0';
  }

  @override
  String get followedEmpty =>
      'You don’t follow any artist yet. Open an artist page and tap “Follow”.';

  @override
  String get followAction => 'Follow';

  @override
  String get followingAction => 'Following';

  @override
  String followStopTitle(String name) {
    return 'Stop following $name?';
  }

  @override
  String get followStopBody => 'You won’t get its new releases any more.';

  @override
  String get followOnYtm => 'Follow on YouTube Music';

  @override
  String get followStop => 'Stop following';

  @override
  String followedNow(String name) {
    return 'You now follow $name';
  }

  @override
  String get followMute => 'Mute notifications';

  @override
  String get followUnmute => 'Unmute notifications';

  @override
  String get followedTopListened => 'Most listened';

  @override
  String get followedToConfirm => 'To confirm';

  @override
  String get followedNotFound => 'Not found';

  @override
  String get followedRetry => 'Retry';

  @override
  String releaseAlbumYear(String year) {
    return 'Album, $year';
  }

  @override
  String releaseSingleYear(String year) {
    return 'Single, $year';
  }

  @override
  String get releaseAlbumPlain => 'Album';

  @override
  String get releaseSinglePlain => 'Single';

  @override
  String releaseVariants(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'and $count other versions',
      one: 'and 1 other version',
    );
    return '$_temp0';
  }

  @override
  String get releaseNewBadge => 'New';

  @override
  String get activityReleases => 'Checking new releases';

  @override
  String releaseNotifyOne(String title, String artist) {
    return 'New release: $title by $artist';
  }

  @override
  String releaseNotifyMany1(int count, String a) {
    return '$count new releases: $a';
  }

  @override
  String releaseNotifyMany2(int count, String a, String b) {
    return '$count new releases: $a and $b';
  }

  @override
  String releaseNotifyManyMore(int count, String a, String b, int others) {
    return '$count new releases: $a, $b and $others more';
  }

  @override
  String get releaseNotifyShow => 'Show';

  @override
  String get reportIssue => 'Report a problem';

  @override
  String get reportIssueHint => 'Opens GitHub with the text already filled in';

  @override
  String get reportKindBug => 'Bug';

  @override
  String get reportKindIdea => 'Idea';

  @override
  String get reportTitleLabel => 'Title';

  @override
  String get reportDescLabel => 'Description';

  @override
  String reportDescHelper(int n) {
    return 'What happened and how to reproduce it (at least $n characters)';
  }

  @override
  String get reportAttach => 'Attach technical information';

  @override
  String get reportAttachPreview => 'Exactly this will be sent:';

  @override
  String get reportOpen => 'Open on GitHub';

  @override
  String get reportCopy => 'Copy text';

  @override
  String get reportCopied => 'Text copied';

  @override
  String get reportGithubNote =>
      'A GitHub account is required; without one, copy the text and send it however you like.';

  @override
  String get reportOpenFailed =>
      'Couldn\'t open the browser: the text was copied';

  @override
  String get reportLogShortened =>
      'The log will be shortened to fit in the address';

  @override
  String get reportNoLog => 'No recent warnings or errors in the log';

  @override
  String get reportUnknown => 'Unknown';

  @override
  String get iconAskTitle => 'Change the app icon too?';

  @override
  String get iconProblems =>
      'The icon changes when you leave the app. Possible problems:\n• the launcher may take a few seconds to update it, or briefly show two icons or none;\n• on some launchers the icon on the Home screen is removed or moved and has to be put back by hand (widgets stay);\n• Home shortcuts made with the old icon may stop working;\n• the app may briefly disappear from recent apps;\n• rarely, Android closes the app and the music stops.\nOn the computer the icon does not change.';

  @override
  String get iconChange => 'Change the icon';

  @override
  String get iconKeep => 'Leave it as it is';

  @override
  String get iconDontAsk => 'Don\'t ask again';

  @override
  String get iconFollowTitle => 'Themed icon';

  @override
  String get iconFollowSubtitle =>
      'The icon follows the theme and colour when you leave the app';

  @override
  String get exportifySyncTitle => 'Sync from Spotify';

  @override
  String exportifySyncChanges(int added, int removed) {
    return '+$added new, −$removed removed';
  }

  @override
  String get exportifySyncNew => 'New playlist';

  @override
  String get exportifySyncChoose => 'To choose';

  @override
  String get exportifySyncNoChanges => 'No changes';

  @override
  String exportifySyncSkipped(int n) {
    return '$n files skipped (not readable playlists)';
  }

  @override
  String exportifySyncGo(int n) {
    return 'Sync $n';
  }

  @override
  String exportifySyncDone(int n) {
    return '$n playlists syncing: follow them in the Activity Center';
  }

  @override
  String get exportifySyncEmpty => 'No playlists in the ZIP';

  @override
  String get exportifySyncPickTitle => 'Choose the playlist';

  @override
  String get csvImportOpenExportify => 'Open exportify.net';

  @override
  String get csvImportOpenFailed => 'Cannot open the browser';

  @override
  String get csvImportZipHint =>
      'With «Export All» you get a ZIP with all your playlists: pick it here and sync them together.';

  @override
  String get exportifySyncFailed => 'Sync failed';

  @override
  String get exportifySyncEntryFailed => 'Cannot read this playlist';

  @override
  String get exportifySyncLoadFailed => 'Cannot read the playlists in the ZIP';

  @override
  String get exportifyRemindTitle => 'Remind me to sync with Spotify';

  @override
  String get exportifyRemindOff => 'Off';

  @override
  String exportifyRemindDays(int days) {
    return '$days days';
  }

  @override
  String get exportifyCardTitle => 'Time to sync your playlists with Spotify';

  @override
  String get exportifyCardOpen => 'Open Exportify';

  @override
  String get exportifyCardLater => 'Later';

  @override
  String get exportifyFoundTitle => 'Exportify export found';

  @override
  String get exportifyFoundSync => 'Sync';

  @override
  String get onboardingSpotifyTitle => 'Playlists from Spotify';

  @override
  String get onboardingSpotifyBody =>
      'On exportify.net you download your Spotify playlists as a file. Codecore picks it up and updates them here.\nNo account to connect: you download the file yourself.';

  @override
  String get deezerMeta => 'Metadata from Deezer';

  @override
  String get deezerMetaHint => 'Data only (covers, track numbers), never music';

  @override
  String get deezerMetaNote =>
      'Private, non-commercial use. Deezer’s terms forbid promoting unauthorised downloading, and Codecore downloads from YouTube: the risk is yours.';

  @override
  String get acoustId => 'Recognise by sound (AcoustID)';

  @override
  String get acoustIdHint =>
      'Only the track\'s fingerprint is sent, never the audio';

  @override
  String get settingsSpinCover => 'Spinning cover';

  @override
  String get settingsSpinCoverHint => 'In the player, while music plays';

  @override
  String get themeLowContrastWarning =>
      'Some text colours are hard to read on the background (under 4.5:1). The theme stays as is.';

  @override
  String get streamCacheTitle => 'Space for streaming';

  @override
  String streamCacheUsage(String used, String limit) {
    return '$used of $limit';
  }

  @override
  String get streamCacheClear => 'Clear';

  @override
  String get streamCacheCleared => 'Streaming cache cleared';

  @override
  String get streamCacheClearFailed => 'Could not clear the streaming cache';

  @override
  String get playerLoading => 'Loading…';

  @override
  String get ytmAlbumQueue => 'Add album to queue';

  @override
  String get addedToLibrary => 'Added to library';

  @override
  String get promoteNoSpace => 'Not enough space to download the track';

  @override
  String get promoteFailed => 'Couldn\'t move the track';

  @override
  String get creditsDetails => 'Credits and details';

  @override
  String get creditsDetailsHint => 'Writers, producers and track details';

  @override
  String get creditsDetailsNote => 'Also uses an unofficial Deezer API';

  @override
  String get creditRoleVocals => 'Vocals';

  @override
  String get creditRoleBackingVocals => 'Backing vocals';

  @override
  String get creditRoleGuitar => 'Guitar';

  @override
  String get creditRoleBassGuitar => 'Bass';

  @override
  String get creditRoleDrums => 'Drums';

  @override
  String get creditRoleKeyboard => 'Keyboards';

  @override
  String get creditRolePiano => 'Piano';

  @override
  String get creditRoleSynthesizer => 'Synthesizer';

  @override
  String get creditRoleComposer => 'Composer';

  @override
  String get creditRoleAuthor => 'Author';

  @override
  String get creditRoleLyricist => 'Lyricist';

  @override
  String get creditRoleArranger => 'Arranger';

  @override
  String get creditRoleProducer => 'Producer';

  @override
  String get creditRoleAdditionalProducer => 'Additional producer';

  @override
  String get creditRoleMix => 'Mixing';

  @override
  String get creditRoleMastering => 'Mastering';

  @override
  String get creditRoleRecording => 'Recording';

  @override
  String get creditRoleEngineer => 'Engineer';

  @override
  String get creditRoleProgramming => 'Programming';

  @override
  String get creditRoleDrumProgrammer => 'Drum programming';

  @override
  String get creditRoleMusicPublisher => 'Music publisher';

  @override
  String get creditsGroupPerformers => 'Performers and instruments';

  @override
  String get creditsGroupWriters => 'Writers';

  @override
  String get creditsGroupProduction => 'Production and engineers';

  @override
  String get creditsGroupOther => 'Other';

  @override
  String get creditsTitle => 'Credits and details';

  @override
  String get creditsShowAll => 'Show all';

  @override
  String get creditsRefresh => 'Refresh';

  @override
  String get creditsAppearsAs => 'Appears as';

  @override
  String get creditsInCredits => 'In the credits';

  @override
  String get creditsRefreshFailed => 'Could not refresh the credits';

  @override
  String get creditsBpm => 'BPM';

  @override
  String get creditsLabel => 'Label';

  @override
  String get creditsDigitalRelease => 'Digital release';

  @override
  String get creditsPhysicalRelease => 'Physical release';

  @override
  String get creditsKindSingle => 'Single';

  @override
  String get creditsKindEp => 'EP';

  @override
  String get creditsRank => 'Chart rank';

  @override
  String get creditsAlbumFans => 'Album fans';

  @override
  String get creditsExplicit => 'Explicit';

  @override
  String creditsOpenArtist(String name) {
    return 'Open $name';
  }

  @override
  String get autoCuriosities => 'Automatic trivia';

  @override
  String get autoCuriositiesHint =>
      'Looks up trivia on Wikipedia for new tracks';

  @override
  String memoryEnrichment(String size) {
    return 'Enrichment: $size';
  }

  @override
  String memoryEnrichmentDetail(
    String lyrics,
    String curiosities,
    String credits,
  ) {
    return 'Lyrics $lyrics, trivia $curiosities, credits $credits';
  }

  @override
  String get activityPodcastRefresh => 'Updating podcasts';

  @override
  String get activityRadio => 'Checking saved radios';

  @override
  String activityEnrichBackground(int done, int total) {
    return 'Completing enrichment: $done of $total';
  }

  @override
  String get enrichRoundTitle => 'Enrichment round';

  @override
  String get enrichRoundUpdated => 'Updated';

  @override
  String get enrichRoundNone => 'No result';

  @override
  String get enrichRoundGone => 'No songs to show';

  @override
  String get enrichPartMeta => 'Song details';

  @override
  String get enrichPartLyrics => 'Lyrics';

  @override
  String get enrichPartSynced => 'Synced lyrics';

  @override
  String get enrichPartCurio => 'Trivia';

  @override
  String get enrichPartCredits => 'Credits';

  @override
  String get coverChange => 'Change cover';

  @override
  String get coverRestoreOriginal => 'Restore original cover';

  @override
  String get coverSourceDevice => 'From device';

  @override
  String get coverSourceLibrary => 'From library';

  @override
  String get coverSourceOnline => 'Online';

  @override
  String coverSizePx(int w, int h) {
    return '$w × $h';
  }

  @override
  String get speakerPermTitle => 'Bluetooth permission';

  @override
  String get speakerPermBody =>
      'To recognise your speaker, Codecore needs to see which Bluetooth devices are connected. It reads nothing else.';

  @override
  String get speakerPermAllow => 'Allow';

  @override
  String get speakerNotNow => 'Not now';

  @override
  String speakerAskTitle(String name) {
    return 'Is $name a speaker?';
  }

  @override
  String get speakerAskBody =>
      'If it is, Codecore opens a Jam by itself when it connects, so others can join.';

  @override
  String get speakerYes => 'Yes';

  @override
  String get speakerNo => 'No';

  @override
  String get speakerJamSection => 'Speaker Jam';

  @override
  String get speakerJamHint =>
      'When a Bluetooth speaker connects, Codecore opens a Jam by itself that others can join.';

  @override
  String get speakerNoDevices => 'No device marked yet';

  @override
  String get speakerIsSpeaker => 'Speaker';

  @override
  String get speakerNotSpeaker => 'Not a speaker';

  @override
  String get speakerPermDenied => 'Bluetooth permission denied';

  @override
  String get speakerPermRetry => 'Tap to ask again';

  @override
  String speakerChange(String name) {
    return 'Change $name';
  }

  @override
  String jamInviteBanner(String name) {
    return 'Join $name\'s Jam';
  }

  @override
  String get jamInviteDismiss => 'Hide';

  @override
  String get speakerAwayNotice => 'Connect a speaker';

  @override
  String get jamFull => 'The Jam is full';

  @override
  String get jamAddFailed => 'Not added to the Jam';

  @override
  String get jamNotFoundOnline => 'Not found online, it can\'t be added';

  @override
  String get jamLeft => 'You left the Jam';

  @override
  String get speakerContinueOnPhone => 'Continue on the phone';

  @override
  String get speakerContinueOnPhoneLabel =>
      'Continue on the phone: the Jam plays from this phone’s speaker, without the speaker';

  @override
  String get speakerOfferTitle => 'Play the Jam on your speaker?';

  @override
  String get speakerOfferBody =>
      'Your speaker is connected and the Jam is paused. If you like, the music restarts from here.';

  @override
  String get jamRemoteTitle => 'Remote Jam';

  @override
  String get jamRemoteHint =>
      'The brokers (servers) for the remote Jam, in order of preference.';

  @override
  String get jamBrokerAdd => 'Add broker';

  @override
  String get jamBrokerHost => 'Address';

  @override
  String get jamBrokerPort => 'Port';

  @override
  String get jamBrokerTls => 'Encrypted connection (TLS)';

  @override
  String get jamBrokerNoTls =>
      'Without TLS anyone on the network can read what goes through the broker. Use it only if you know what you are doing.';

  @override
  String get jamBrokerInvalid => 'Invalid address or port';

  @override
  String get jamBrokerTest => 'Test connection';

  @override
  String jamBrokerTestOk(String broker) {
    return '$broker: connection succeeded';
  }

  @override
  String jamBrokerTestFail(String broker) {
    return '$broker: cannot connect (network, certificate or server unreachable)';
  }

  @override
  String get jamBrokerRestore => 'Restore';

  @override
  String get jamBrokerMoveUp => 'Move up';

  @override
  String get jamBrokerRemove => 'Remove';

  @override
  String get jamSuspend => 'Suspend';

  @override
  String get jamBlock => 'Block';

  @override
  String get jamSuspendTitle => 'Suspend for how long?';

  @override
  String get jamUntilJamEnds => 'Until the Jam ends';

  @override
  String get jamBlockedTitle => 'Blocked devices';

  @override
  String get jamSuspendedTitle => 'Suspended';

  @override
  String get jamUnblock => 'Unblock';

  @override
  String jamSuspendedUntil(String time) {
    return 'Until $time';
  }

  @override
  String get jamTooSoon => 'Wait a moment before trying again';

  @override
  String enrichInterrupted(int updated, int notFound) {
    return 'Enrichment stopped by an error: $updated updated, $notFound not found';
  }

  @override
  String enrichLibraryDue(int count, int minutes) {
    return '$count tracks to complete, about $minutes minutes';
  }

  @override
  String get enrichLibraryComplete => 'Library complete';

  @override
  String get enrichLibraryStop => 'Stop';

  @override
  String get activityEnrichWaiting => 'Completing: waiting';

  @override
  String logRecogSources(String list) {
    return 'Recognized: $list';
  }

  @override
  String get recogSrcTags => 'tags';

  @override
  String get recogSrcVideo => 'video';

  @override
  String get recogSrcText => 'text';

  @override
  String recogIdent(String title, String artist) {
    return '$title – $artist';
  }

  @override
  String recogProposal(String identity) {
    return 'Suggestion: $identity';
  }

  @override
  String get recogAccept => 'Accept';

  @override
  String get recogDiscard => 'Dismiss';

  @override
  String recogAcceptSem(String identity) {
    return 'Accept the suggestion $identity';
  }

  @override
  String recogDiscardSem(String identity) {
    return 'Dismiss the suggestion $identity';
  }

  @override
  String get recogCover => 'Cover';

  @override
  String recogCoverOf(String identity) {
    return 'Cover of $identity';
  }

  @override
  String recogToConfirm(int count) {
    return 'To confirm ($count)';
  }

  @override
  String get recogAcceptAll => 'Accept all';

  @override
  String get recogNoProposals => 'All confirmed';

  @override
  String recogFromTo(String from, String to) {
    return 'From $from to $to';
  }

  @override
  String get logRevert => 'Restore';

  @override
  String get recogActionFailed => 'The action failed';

  @override
  String get logRevertFailed => 'This correction could not be restored';

  @override
  String get jamInviteNearby => 'Invite people nearby';

  @override
  String get jamInviteHint =>
      'Anyone who scans the QR or types the code joins the Jam.';

  @override
  String get jamBridgeConnecting => 'Connecting…';

  @override
  String get jamBridgeRetrying => 'Link interrupted, retrying…';

  @override
  String get jamBridgeUnreachable => 'Broker unreachable';

  @override
  String jamCodeExpiresIn(int seconds) {
    return 'Expires in $seconds s';
  }

  @override
  String get jamEnterCode => 'Join with a code';

  @override
  String get jamCodeLabel => 'Code';

  @override
  String get jamScanQr => 'Scan the QR';

  @override
  String get jamJoinAction => 'Join';

  @override
  String get jamCodeInvalid => 'Invalid code';

  @override
  String get jamCodeExpired => 'Code expired, ask for a new one';

  @override
  String get jamHostNoAnswer => 'The host did not answer';

  @override
  String get jamCustomBroker => 'This Jam uses a custom broker: scan the QR';

  @override
  String get jamLinkReconnecting => 'Connection lost, retrying…';

  @override
  String get jamHostSilent => 'Host unreachable, retrying…';

  @override
  String get jamMemberUnreachable => 'unreachable';

  @override
  String get jamRemoteActive => 'Remote Jam on';

  @override
  String get jamRemoteEnd => 'End';

  @override
  String get jamDeclinedHost => 'The host declined the request';

  @override
  String get jamBusyHost => 'The host already has a Jam running';

  @override
  String get jamWaitingHost => 'Waiting for the host to accept…';

  @override
  String get jamFriendsTitle => 'Jam friends';

  @override
  String get jamFriendsEmpty =>
      'No friends yet. After the first accepted join, the two devices save each other.';

  @override
  String get jamFriendRemove => 'Remove';

  @override
  String jamFriendRemoveTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get jamFriendRemoveBody =>
      'You will no longer recognise each other without asking. This device changes its announce key.';

  @override
  String get jamAutoAcceptFriends => 'Accept friends without asking';

  @override
  String get jamAutoAcceptFriendsHint =>
      'If a friend\'s phone is stolen, whoever has it can join your Jam when nearby.';

  @override
  String get jamFriendBadge => 'Friend';

  @override
  String get jamNearbyJoin => 'Join a Jam nearby';

  @override
  String get jamBleTitle => 'Find nearby Jams';

  @override
  String get jamBleBody12 =>
      'Android asks for the “Nearby devices” permission to look for and announce Jams over Bluetooth. The app does not read where you are.';

  @override
  String get jamBleBody11 =>
      'The location permission is needed: Android requires it to scan over Bluetooth; the app does not read where you are.';

  @override
  String get jamBleAllow => 'Allow';

  @override
  String get jamBleNotNow => 'Not now';

  @override
  String get jamBleLocationOff =>
      'Turn on Android’s location: it is needed to look for Jams over Bluetooth. Meanwhile you can use the code or the QR.';

  @override
  String get jamNearbyScanTitle => 'Look for nearby Jams';

  @override
  String get jamNearbyScanHint => 'Over Bluetooth, only while the app is open';

  @override
  String get streamCardsUnavailable => 'Not available';

  @override
  String get streamCardsUnavailableBody =>
      'Lyrics, trivia and credits for this track did not arrive. It may be the network or the source.';

  @override
  String get closeKeyboard => 'Close keyboard';

  @override
  String get loadingContent => 'Loading…';

  @override
  String shufflePlusChoosing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Shuffle+ is picking $count tracks…',
      one: 'Shuffle+ is picking 1 track…',
    );
    return '$_temp0';
  }

  @override
  String statsBarValue(String when, String time) {
    return '$when, $time';
  }

  @override
  String get homeRadioLive => 'Live';

  @override
  String get closeSearch => 'Close search';

  @override
  String get librarySearchHint => 'Search your library';

  @override
  String get genreMixTag => 'Suggested';

  @override
  String get genreMixOffJam => 'Suggestions off: Jam in progress';

  @override
  String get genreMixOffMetered => 'Suggestions off: metered network';

  @override
  String get genreMixOffOffline => 'Suggestions off: no network';

  @override
  String get genreMixOffNoTool => 'Suggestions off: online tool missing';

  @override
  String get genreMixOffRateLimited => 'Suggestions paused: too many requests';

  @override
  String get playerEmptyTitle => 'Nothing playing';

  @override
  String get playerEmptyHint => 'Choose where to pick up.';

  @override
  String get playerEmptyNoQueue => 'Pick a song to start';

  @override
  String playerLastQueue(String name) {
    return 'Last queue: $name';
  }

  @override
  String get playerResumeLastQueue => 'Resume the last queue';

  @override
  String playerResumeLastQueueSub(String name, String tracks) {
    return '$name, $tracks';
  }

  @override
  String get playerShufflePlusLibrary => 'Shuffle+ of the library';

  @override
  String get playerShufflePlusLibrarySub =>
      'Your library shuffled, with suggested songs';

  @override
  String get playerRecentlyAdded => 'Recently added';

  @override
  String get reviewSearch => 'Search';

  @override
  String get recogTitle => 'To confirm';

  @override
  String recogSuggested(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count suggested fixes. Review them one by one or accept them all.',
      one: '1 suggested fix',
    );
    return '$_temp0';
  }

  @override
  String recogAcceptAllCount(int count) {
    return 'Accept all ($count)';
  }

  @override
  String recogAcceptedAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fixes accepted',
      one: '1 fix accepted',
    );
    return '$_temp0. Files update in the background.';
  }

  @override
  String get recogNoProposalsHint => 'There is nothing left to check.';

  @override
  String get logToday => 'Today';

  @override
  String get logYesterday => 'Yesterday';

  @override
  String logDayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
    );
    return '$_temp0';
  }

  @override
  String get logRetention => 'The log keeps the last 30 days.';

  @override
  String get logNoMatch => 'No entries with this filter.';

  @override
  String get logPickEntry => 'Pick an entry to see its details.';

  @override
  String get logFilterAll => 'All';

  @override
  String get logFilterDownload => 'Downloads';

  @override
  String get logFilterLibrary => 'Library';

  @override
  String get logFilterEnrich => 'Enrichment';

  @override
  String get logFilterCorrections => 'Corrections';

  @override
  String get logFilterErrors => 'Errors';

  @override
  String get logFailedLabel => 'Failed';

  @override
  String get logStoppedLabel => 'Stopped';

  @override
  String get logClearMenu => 'Clear log';

  @override
  String get logClearTitle => 'Clear the log?';

  @override
  String get logClearConfirm => 'Clear';

  @override
  String get logPendingSub => 'Corrections suggested for your songs';

  @override
  String get logPendingReview => 'Review';

  @override
  String logPendingMore(int count) {
    return 'and $count more';
  }

  @override
  String get logHowTitle => 'How to fix it';

  @override
  String get logTechTitle => 'Technical detail';

  @override
  String get logOpenSongs => 'See the songs';

  @override
  String logHowSettings(String settings, String page) {
    return 'Open $settings, then “$page”.';
  }

  @override
  String logHowUpdate(String button) {
    return 'Tap “$button” next to yt-dlp.';
  }

  @override
  String get logHowWait => 'Wait a few minutes.';

  @override
  String get logHowOnline => 'Check that you are online.';

  @override
  String get logDlDone => 'Song downloaded';

  @override
  String get logDlFailed => 'Download failed';

  @override
  String logDlGroup(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs downloaded',
      one: '1 song downloaded',
    );
    return '$_temp0';
  }

  @override
  String get logDlGroupShow => 'Show the songs';

  @override
  String get logDlGroupHide => 'Hide the songs';

  @override
  String get logTransferDone => 'Songs sent';

  @override
  String get logTransferFailed => 'Sending failed';

  @override
  String get logScanDone => 'Library updated';

  @override
  String get logScanDoneSub => 'All folders checked.';

  @override
  String get logScanStopped => 'Scan stopped';

  @override
  String get logScanFailed => 'Scan failed';

  @override
  String get logStoppedSub => 'It stopped before the end.';

  @override
  String get logFailedSub => 'It stopped because of an error.';

  @override
  String get logEnrichDone => 'Enrichment finished';

  @override
  String get logEnrichInterrupted => 'Enrichment interrupted';

  @override
  String get logEnrichInterruptedSub =>
      'It stopped because of an error; the work done is saved.';

  @override
  String get logBgDone => 'Lyrics and covers added';

  @override
  String get logBgDoneSub => 'Background completion.';

  @override
  String get logBgStopped => 'Completion stopped';

  @override
  String get logBgStoppedSub => 'No source is answering right now.';

  @override
  String get logBgFailed => 'Completion failed';

  @override
  String get logBgFailedSub => 'An error stopped it.';

  @override
  String get logSecondOpinion => 'Second opinion from YouTube Music';

  @override
  String get logSecondOpinionSub => 'The uncertain songs were checked.';

  @override
  String get logSecondOpinionFailed => 'Second opinion interrupted';

  @override
  String get logCleanup => 'Duplicates searched';

  @override
  String get logCleanupSub => 'The library songs were compared.';

  @override
  String get logReleases => 'New releases checked';

  @override
  String get logReleasesSub => 'Looked for news from the artists you follow.';

  @override
  String get logPodcasts => 'Podcasts updated';

  @override
  String get logRadio => 'Stations checked';

  @override
  String get logTaskFailed => 'Task failed';

  @override
  String logImportDone(String name) {
    return 'Playlist “$name” imported';
  }

  @override
  String logImportReady(String name) {
    return 'Playlist “$name” ready';
  }

  @override
  String get logImportFailed => 'Import failed';

  @override
  String get logImportRate => 'Import slowed down by YouTube';

  @override
  String get logImportPaused => 'Import paused';

  @override
  String get logWhyToolMissing =>
      'The component that downloads from YouTube is missing.';

  @override
  String get logWhyToolOld =>
      'The component that downloads from YouTube is too old.';

  @override
  String get logWhyNetwork => 'Network not available.';

  @override
  String get logWhyRate => 'YouTube asked to slow down.';

  @override
  String get logWhyFailing => 'Too many errors in a row: I paused it.';

  @override
  String get logCorrectionTitle => 'Title and artist corrected';

  @override
  String logChipSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    return '$_temp0';
  }

  @override
  String logChipSongsOf(int done, int total) {
    return '$done of $total songs';
  }

  @override
  String logChipUpdated(int count) {
    return '$count updated';
  }

  @override
  String logChipNotFound(int count) {
    return '$count not found';
  }

  @override
  String logChipNoResult(int count) {
    return '$count without result';
  }

  @override
  String get logFileTitle => 'Correction saved, file not updated';

  @override
  String get logHowFileMissing => 'Check that the song is still in its folder.';

  @override
  String get logHowFileReadOnly =>
      'Remove read-only from the file or its folder, then correct the song again.';

  @override
  String get logHowFileRetry =>
      'Check that there is free disk space and the file is not in use, then correct the song again.';

  @override
  String get logClearBody =>
      'This deletes every entry and removes finished downloads from the list. You will no longer be able to restore corrections. Your songs stay where they are.';

  @override
  String logHowResume(String button) {
    return 'Tap “$button” on the paused import, in the activity list.';
  }

  @override
  String get logEnrichStopped => 'Enrichment stopped';

  @override
  String logCorrectionSem(String from, String to) {
    return 'From $from to $to';
  }
}
