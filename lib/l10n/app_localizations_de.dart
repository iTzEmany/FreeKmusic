// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'Codecore';

  @override
  String get chooseFolder => 'Ordner wählen';

  @override
  String get scan => 'Scannen';

  @override
  String get noTracks => 'Keine Titel. Ordner wählen und scannen.';

  @override
  String get openSettings => 'Einstellungen öffnen';

  @override
  String get permissionDenied => 'Leseberechtigung für Audio verweigert';

  @override
  String get permissionExplain =>
      'Codecore benötigt die Berechtigung, Audiodateien zu lesen, um deine Musik anzuzeigen.';

  @override
  String get navLibrary => 'Bibliothek';

  @override
  String get navFavorites => 'Favoriten';

  @override
  String get navPlaylists => 'Playlists';

  @override
  String get navSettings => 'Einstellungen';

  @override
  String get tracks => 'Titel';

  @override
  String get albums => 'Alben';

  @override
  String get artists => 'Künstler';

  @override
  String get searchHint => 'Suchen';

  @override
  String get clearSearch => 'Suche löschen';

  @override
  String get sortBy => 'Sortieren nach';

  @override
  String get addMusicFolder => 'Füge deinen Musikordner hinzu';

  @override
  String get addFolder => 'Ordner hinzufügen';

  @override
  String get folders => 'Musikordner';

  @override
  String get refreshLibrary => 'Bibliothek aktualisieren';

  @override
  String get removeFolder => 'Ordner entfernen';

  @override
  String get unknownArtist => 'Unbekannter Künstler';

  @override
  String get unknownAlbum => 'Unbekanntes Album';

  @override
  String get variousArtists => 'Verschiedene Künstler';

  @override
  String get play => 'Wiedergabe';

  @override
  String get shuffle => 'Zufall';

  @override
  String get queue => 'Warteschlange';

  @override
  String get nowPlaying => 'Wiedergabe läuft';

  @override
  String get nothingPlaying => 'Keine Wiedergabe';

  @override
  String get mute => 'Stumm';

  @override
  String get scanning => 'Scanvorgang läuft…';

  @override
  String get emptyQueue => 'Die Warteschlange ist leer';

  @override
  String get noResults => 'Keine Ergebnisse';

  @override
  String get sortDefault => 'Standard';

  @override
  String get sortPersonal => 'Eigene Reihenfolge';

  @override
  String get sortTitle => 'Titel';

  @override
  String get sortArtist => 'Künstler';

  @override
  String get sortAlbum => 'Album';

  @override
  String get sortYear => 'Jahr';

  @override
  String get sortAdded => 'Zuletzt hinzugefügt';

  @override
  String get sortDuration => 'Dauer';

  @override
  String tracksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel',
      one: '1 Titel',
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
      other: '$countString Alben',
      one: '1 Album',
    );
    return '$_temp0';
  }

  @override
  String get libraryAll => 'Alles';

  @override
  String libraryItemsCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Einträge',
      one: '1 Eintrag',
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
      other: '$countString Playlists',
      one: '1 Playlist',
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
      other: '$countString Künstler',
      one: '1 Künstler',
    );
    return '$_temp0';
  }

  @override
  String minutesWords(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Minuten',
      one: '1 Minute',
    );
    return '$_temp0';
  }

  @override
  String hoursWords(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Stunden',
      one: '1 Stunde',
    );
    return '$_temp0';
  }

  @override
  String hoursAndMinutes(String hours, String minutes) {
    return '$hours und $minutes';
  }

  @override
  String get collectionNoTracks => 'Keine Titel';

  @override
  String missingTracksCount(int count) {
    return 'Fehlende Titel ($count)';
  }

  @override
  String get addedToFavorites => 'Zu Favoriten hinzugefügt';

  @override
  String get removedFromFavorites => 'Aus Favoriten entfernt';

  @override
  String get undo => 'Rückgängig';

  @override
  String get favoritesEmptyTitle => 'Noch keine Favoriten';

  @override
  String get favoritesEmptyHelp =>
      'Tippe auf das Herz bei einem Titel, dann findest du ihn hier.';

  @override
  String get openAllTracks => 'Alle Titel öffnen';

  @override
  String get newPlaylist => 'Neue Playlist';

  @override
  String get newPlaylistEllipsis => 'Neue Playlist…';

  @override
  String get playlistName => 'Name der Playlist';

  @override
  String get create => 'Erstellen';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get save => 'Speichern';

  @override
  String get delete => 'Löschen';

  @override
  String get rename => 'Umbenennen';

  @override
  String get noPlaylists => 'Keine Playlists. Erstelle eine.';

  @override
  String get addToPlaylist => 'Zu Playlist hinzufügen…';

  @override
  String addedToPlaylist(String name) {
    return 'Zu „$name“ hinzugefügt';
  }

  @override
  String get playNext => 'Als Nächstes spielen';

  @override
  String get addToQueue => 'Zur Warteschlange hinzufügen';

  @override
  String get addedToQueue => 'Zur Warteschlange hinzugefügt';

  @override
  String get favorite => 'Favorit';

  @override
  String get removeFromFavorites => 'Aus Favoriten entfernen';

  @override
  String get removeFromList => 'Entfernen';

  @override
  String get editInfo => 'Infos bearbeiten';

  @override
  String get details => 'Details';

  @override
  String get showInFolder => 'Im Ordner anzeigen';

  @override
  String get detailPath => 'Pfad';

  @override
  String get detailFormat => 'Format';

  @override
  String get detailSize => 'Größe';

  @override
  String get detailDuration => 'Dauer';

  @override
  String get detailAdded => 'Hinzugefügt am';

  @override
  String get detailPlays => 'Wiedergaben';

  @override
  String get close => 'Schließen';

  @override
  String get fieldTitle => 'Titel';

  @override
  String get fieldArtist => 'Künstler';

  @override
  String get fieldAlbum => 'Album';

  @override
  String get fieldAlbumArtist => 'Albumkünstler';

  @override
  String get fieldYear => 'Jahr';

  @override
  String get fieldTrackNumber => 'Titelnummer';

  @override
  String get fieldGenre => 'Genre';

  @override
  String get restoreFromFile => 'Aus Datei-Tags wiederherstellen';

  @override
  String get titleRequired => 'Der Titel darf nicht leer sein';

  @override
  String get settingsAppearance => 'Darstellung';

  @override
  String get settingsTheme => 'Design';

  @override
  String get themeNotte => 'Violette Nacht';

  @override
  String get themeOled => 'Reines Schwarz';

  @override
  String get settingsTextSize => 'Textgröße';

  @override
  String get textSmall => 'Klein';

  @override
  String get textNormal => 'Normal';

  @override
  String get textLarge => 'Groß';

  @override
  String get settingsCompact => 'Kompaktmodus';

  @override
  String get settingsReducedMotion => 'Animationen reduzieren';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get settingsLibrary => 'Bibliothek';

  @override
  String get rescanNow => 'Jetzt neu scannen';

  @override
  String get clearCoverCache => 'Cover-Cache leeren';

  @override
  String get coverCacheCleared => 'Cover-Cache geleert';

  @override
  String get settingsOnline => 'Online';

  @override
  String get settingsPageAppearance => 'Darstellung und Sprache';

  @override
  String get settingsPagePlayback => 'Wiedergabe';

  @override
  String get settingsPageLibrary => 'Bibliothek';

  @override
  String get settingsPageOnline => 'Online und Downloads';

  @override
  String get settingsPageNetwork => 'Netzwerk und Geräte';

  @override
  String get settingsPageBackup => 'Backup';

  @override
  String get settingsPageAdvanced => 'Erweitert und Info';

  @override
  String summaryLibrary(int folders, int tracks) {
    String _temp0 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: '$folders Ordner',
      one: '1 Ordner',
    );
    String _temp1 = intl.Intl.pluralLogic(
      tracks,
      locale: localeName,
      other: '$tracks Titel',
      one: '1 Titel',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String summaryTrusted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vertraute Geräte',
      one: '1 vertrautes Gerät',
    );
    return '$_temp0';
  }

  @override
  String get summaryNormalizeOn => 'Normalisierung an';

  @override
  String get summaryBackup => 'Bibliothek exportieren und wiederherstellen';

  @override
  String summaryCrossfade(int seconds) {
    return '$seconds s';
  }

  @override
  String get openPlaybackSettings => 'Wiedergabe öffnen';

  @override
  String get autoEnrich => 'Automatische Anreicherung';

  @override
  String get autoEnrichHint =>
      'Metadaten und Cover für neue Titel online suchen';

  @override
  String get autoLyrics => 'Automatische Songtexte';

  @override
  String get autoLyricsHint => 'Songtexte von LRCLIB für neue Titel laden';

  @override
  String get settingsAbout => 'Info';

  @override
  String appVersion(String version) {
    return 'Version $version';
  }

  @override
  String get licenses => 'Lizenzen';

  @override
  String get personalUse => 'App für den persönlichen Gebrauch';

  @override
  String get missingTracksTitle => 'Fehlende Titel';

  @override
  String get removeFromLibrary => 'Aus Bibliothek entfernen';

  @override
  String get ignore => 'Ignorieren';

  @override
  String get confirmRemoveTitle => 'Aus Bibliothek entfernen?';

  @override
  String get confirmRemoveBody =>
      'Die Datei bleibt unverändert; Favoriten und Playlists dieses Titels gehen verloren.';

  @override
  String get noMissingTracks => 'Keine fehlenden Titel';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String scanFailed(String error) {
    return 'Scan fehlgeschlagen: $error';
  }

  @override
  String playbackError(String reason, String title) {
    return '„$title“ kann nicht abgespielt werden: $reason';
  }

  @override
  String get reasonFileMissing => 'Datei nicht gefunden';

  @override
  String get reasonUnplayable => 'Datei nicht abspielbar';

  @override
  String get reasonNotInLibrary => 'Titel nicht in der Bibliothek';

  @override
  String get reasonOnlineUnavailable => 'Online-Titel nicht verfügbar';

  @override
  String get reasonEpisodeUnavailable =>
      'Folge nicht verfügbar, prüfe die Verbindung';

  @override
  String get reasonAgeRestricted =>
      'altersbeschränkt, keine Audiospur gefunden';

  @override
  String get searchWeb => 'Infos im Web suchen';

  @override
  String get enrichPreviewTitle => 'Vorschau der Informationen';

  @override
  String get currentValue => 'Aktuell';

  @override
  String get proposedValue => 'Vorschlag';

  @override
  String get apply => 'Anwenden';

  @override
  String get nothingFound => 'Nichts gefunden';

  @override
  String get userEditedLocked => 'Von dir bearbeitet: wird nicht überschrieben';

  @override
  String get fieldCover => 'Cover';

  @override
  String get fieldLyrics => 'Songtext';

  @override
  String get fieldCuriosity => 'Wissenswertes';

  @override
  String get enrichAlbum => 'Album anreichern';

  @override
  String get enrichLibrary => 'Gesamte Bibliothek anreichern';

  @override
  String enrichRunning(int done, int total) {
    return 'Anreicherung $done/$total';
  }

  @override
  String enrichResult(int notFound, int updated) {
    return '$updated aktualisiert, $notFound nicht gefunden';
  }

  @override
  String get enrichBusy => 'Eine Anreicherung läuft bereits';

  @override
  String get enrichNothingToDo =>
      'Nichts zu ergänzen: keinem Titel fehlt etwas';

  @override
  String get serviceUnavailable =>
      'Dienst nicht verfügbar, später erneut versuchen';

  @override
  String get lyrics => 'Songtext';

  @override
  String get searchLyrics => 'Songtext suchen';

  @override
  String get noLyrics => 'Kein Songtext verfügbar';

  @override
  String get lyricsNotFound => 'Songtext nicht gefunden';

  @override
  String get copy => 'Kopieren';

  @override
  String get copied => 'Kopiert';

  @override
  String get sourceWikipedia => 'Quelle: Wikipedia (CC BY-SA)';

  @override
  String get youtube => 'YouTube';

  @override
  String get ytHint => 'Suchen oder Link einfügen';

  @override
  String get ytDownload => 'Herunterladen';

  @override
  String get listenAction => 'Anhören';

  @override
  String get ytAlreadyInLibrary => 'Bereits in der Bibliothek';

  @override
  String get ytNoResults => 'Keine Ergebnisse';

  @override
  String get ytQueued => 'In Warteschlange';

  @override
  String get ytDownloading => 'Wird heruntergeladen';

  @override
  String get ytDone => 'Fertig';

  @override
  String get ytFailed => 'Fehlgeschlagen';

  @override
  String get ytCancelled => 'Abgebrochen';

  @override
  String get ytClearCompleted => 'Abgeschlossene entfernen';

  @override
  String get ytCancel => 'Download abbrechen';

  @override
  String get ytErrUnavailable => 'Video nicht verfügbar (Alter/Region/privat)';

  @override
  String get ytErrNetwork => 'Netzwerk nicht verfügbar';

  @override
  String get ytErrChanged =>
      'YouTube hat etwas geändert: App oder Paket aktualisieren';

  @override
  String get ytNoFolder => 'Füge zuerst einen Musikordner hinzu';

  @override
  String get ytLegal =>
      'Nur für den persönlichen Gebrauch. Urheberrecht sowie die Bedingungen von YouTube beachten.';

  @override
  String get useDefaultFolder => 'Musikordner des Geräts verwenden';

  @override
  String get ytErrToolMissing =>
      'yt-dlp nicht gefunden: installieren (pip install -U yt-dlp) und erneut versuchen';

  @override
  String get ytErrRateLimited =>
      'YouTube verlangt eine Pause: versuche es in einigen Minuten erneut';

  @override
  String get playlistChangeCover => 'Cover ändern';

  @override
  String get playlistRemoveCover => 'Cover entfernen';

  @override
  String get coverTooLarge => 'Bild zu groß (max. 4 MB)';

  @override
  String get addSongs => 'Titel hinzufügen';

  @override
  String addNSongs(int count) {
    return 'Hinzufügen ($count)';
  }

  @override
  String get allSongsInPlaylist => 'Alle Titel sind bereits in der Playlist';

  @override
  String get shareTitle => 'Teilen';

  @override
  String get shareSend => 'Senden';

  @override
  String get shareReceive => 'Empfangen';

  @override
  String get shareAll => 'Ganze Bibliothek';

  @override
  String shareSelection(int count) {
    return 'Auswahl ($count Titel)';
  }

  @override
  String get sharePick => 'Titel wählen';

  @override
  String get shareStart => 'Freigabe starten';

  @override
  String get shareStop => 'Stopp';

  @override
  String get shareActive => 'Freigabe aktiv';

  @override
  String get shareAddress => 'Adresse (IP:Port)';

  @override
  String get sharePin => 'PIN';

  @override
  String get shareConnect => 'Verbinden';

  @override
  String shareDownloadSelected(int count) {
    return 'Auswahl herunterladen ($count)';
  }

  @override
  String shareProgress(int done, int total) {
    return 'Titel $done von $total';
  }

  @override
  String shareDone(int count) {
    return '$count Titel empfangen';
  }

  @override
  String shareConnectedTo(String name) {
    return 'Verbunden mit $name';
  }

  @override
  String get shareErrUnreachable =>
      'Gerät nicht erreichbar: Adresse und WLAN prüfen';

  @override
  String get shareErrPin => 'Falsche PIN';

  @override
  String get shareErrBlocked =>
      'Zu viele Versuche: in einer Minute erneut versuchen';

  @override
  String get shareErrNotCodecore => 'Kein Codecore-Gerät';

  @override
  String get shareErrFailed => 'Übertragung fehlgeschlagen';

  @override
  String get shareNoNetwork => 'Kein lokales Netzwerk gefunden';

  @override
  String get shareFirewall =>
      'Windows fragt beim ersten Mal ggf. nach der Firewall-Freigabe.';

  @override
  String get shareHint =>
      'Im selben WLAN auf dem anderen Gerät „Empfangen“ öffnen und Adresse und PIN eingeben.';

  @override
  String get shareMenu => 'Teilen…';

  @override
  String get shareDeviceName => 'Gerätename';

  @override
  String get sleepTimer => 'Schlaftimer';

  @override
  String sleepMinutes(int count) {
    return '$count Minuten';
  }

  @override
  String get sleepEndOfTrack => 'Am Ende des Titels';

  @override
  String get sleepCancel => 'Timer abbrechen';

  @override
  String get pause => 'Pause';

  @override
  String get nextTrack => 'Nächster Titel';

  @override
  String get previousTrack => 'Vorheriger Titel';

  @override
  String get repeat => 'Wiederholen';

  @override
  String get moreOptions => 'Weitere Optionen';

  @override
  String get back => 'Zurück';

  @override
  String get seekPosition => 'Position im Titel';

  @override
  String get settingsPlayback => 'Wiedergabe';

  @override
  String get normalizeVolume => 'Lautstärke normalisieren';

  @override
  String get normalizeVolumeHint =>
      'Nutzt ReplayGain der Dateien, um zu laute Titel zu senken';

  @override
  String get nearbyDevices => 'Geräte in der Nähe';

  @override
  String get searchingDevices => 'Suche nach Geräten im Netzwerk…';

  @override
  String get noDevicesHint =>
      'Kein Gerät gefunden. Öffne Teilen auch auf dem anderen Gerät im selben Netzwerk.';

  @override
  String sendToDevice(String name) {
    return 'An $name senden';
  }

  @override
  String offerSent(String name) {
    return 'Anfrage an $name gesendet';
  }

  @override
  String get offerChooseFirst => 'Wähle zuerst die zu sendenden Titel';

  @override
  String get sentRequests => 'Gesendete Anfragen';

  @override
  String get receivedRequests => 'Empfangene Anfragen';

  @override
  String get offerPending => 'Warte auf Antwort';

  @override
  String get offerAccepted => 'Akzeptiert';

  @override
  String get offerDeclined => 'Abgelehnt';

  @override
  String get offerCancelled => 'Abgebrochen';

  @override
  String get offerExpired => 'Abgelaufen';

  @override
  String get offerDone => 'Abgeschlossen';

  @override
  String get offerFailed => 'Fehlgeschlagen';

  @override
  String incomingTitle(String name) {
    return '$name möchte dir Titel senden';
  }

  @override
  String incomingBody(int count, String size) {
    return '$count Titel, $size MB';
  }

  @override
  String get accept => 'Annehmen';

  @override
  String get decline => 'Ablehnen';

  @override
  String receivingProgress(int done, int total) {
    return 'Empfang $done/$total';
  }

  @override
  String get manualConnection => 'Manuelle Verbindung (IP und PIN)';

  @override
  String get receiveFromLan => 'Aus dem lokalen Netzwerk empfangen';

  @override
  String get receiveFromLanHint =>
      'Macht das Gerät sichtbar und empfängt Anfragen auch im Hintergrund. Unter Android erscheint eine feste Benachrichtigung zum Ausschalten';

  @override
  String get receiveServiceTitle => 'Codecore ist im Netzwerk sichtbar';

  @override
  String get receiveServiceText =>
      'Bereit, Titel von Geräten in der Nähe zu empfangen';

  @override
  String get receiveServiceDisable => 'Ausschalten';

  @override
  String get jamTitle => 'Jam';

  @override
  String get jamStart => 'Jam starten';

  @override
  String jamStartWith(String name) {
    return 'Jam mit $name starten';
  }

  @override
  String jamWaiting(String name) {
    return 'Warte, bis $name annimmt…';
  }

  @override
  String jamDeclined(String name) {
    return '$name hat die Jam abgelehnt';
  }

  @override
  String jamBusy(String name) {
    return '$name hat bereits eine Jam';
  }

  @override
  String get jamUnreachable => 'Gerät nicht erreichbar';

  @override
  String jamIncomingTitle(String name) {
    return '$name möchte eine Jam starten';
  }

  @override
  String get jamIncomingBody =>
      'Gemeinsam aus einer geteilten Warteschlange hören.';

  @override
  String get jamIncomingDialog =>
      'Die Musik läuft auf diesem Gerät und ihr könnt beide Titel hinzufügen.';

  @override
  String get jamQueue => 'Gemeinsame Warteschlange';

  @override
  String get jamModeHost => 'Warteschlange des Hosts';

  @override
  String get jamModeTogether => 'Gemeinsam';

  @override
  String get jamModeGuestHint => 'Der Host wählt den Warteschlangenmodus';

  @override
  String get jamSuggested => 'Vorgeschlagen';

  @override
  String get jamEmpty => 'Reihe Titel aus der Bibliothek oder der Suche ein';

  @override
  String jamOnlineFailed(String title) {
    return '„$title“ konnte nicht zur Jam hinzugefügt werden';
  }

  @override
  String jamAddedBy(String name) {
    return 'hinzugefügt von $name';
  }

  @override
  String get jamJumpHere => 'Hier abspielen';

  @override
  String get jamYou => 'dir';

  @override
  String get jamGuest => 'Gast';

  @override
  String get jamAddToJam => 'Zur Jam hinzufügen';

  @override
  String jamAdded(int count) {
    return 'Zur Jam hinzugefügt: $count';
  }

  @override
  String get jamOutput => 'Audioausgabe';

  @override
  String get jamOutputHere => 'Dieses Gerät';

  @override
  String jamOutputOther(String name) {
    return '$name';
  }

  @override
  String get jamEnd => 'Jam beenden';

  @override
  String get jamLeave => 'Jam verlassen';

  @override
  String get jamEnded => 'Die Jam ist beendet';

  @override
  String get jamLost => 'Verbindung verloren';

  @override
  String get jamGuestCannotSkip => 'Nur der Host kann den Titel wechseln';

  @override
  String get jamRemoveForbidden => 'Du kannst nur eigene Titel entfernen';

  @override
  String get jamNothingPlaying => 'Nichts läuft';

  @override
  String jamWith(String name) {
    return 'Jam mit $name';
  }

  @override
  String get jamUnavailable => 'Nicht verfügbar';

  @override
  String get jamPlaying => 'Jam ist aktiv';

  @override
  String get jamOpen => 'Jam öffnen';

  @override
  String jamSynced(int ms) {
    return 'Synchron, Abweichung $ms ms';
  }

  @override
  String get jamSyncing => 'Synchronisierung…';

  @override
  String jamLatency(int ms) {
    return 'Latenz dieser Ausgabe: $ms ms';
  }

  @override
  String get jamLatencyHint =>
      'Für Bluetooth-Kopfhörer oder -Lautsprecher: erhöhen, bis die Ausgaben zusammenpassen.';

  @override
  String get jamOutputsHint => 'Mehrere Ausgaben spielen gleichzeitig';

  @override
  String get renamePlaylist => 'Playlist umbenennen';

  @override
  String get confirmDeletePlaylistTitle => 'Playlist löschen?';

  @override
  String confirmDeletePlaylistBody(String name) {
    return '„$name“ wird gelöscht. Die Titel bleiben in der Bibliothek.';
  }

  @override
  String get confirmRemoveFolderTitle => 'Ordner entfernen?';

  @override
  String get confirmRemoveFolderBody =>
      'Die Titel verschwinden aus der Bibliothek. Die Dateien bleiben auf dem Gerät.';

  @override
  String get confirmClearCoversTitle => 'Cover-Cache leeren?';

  @override
  String get confirmClearCoversBody =>
      'Die Cover werden beim nächsten Scan neu erstellt.';

  @override
  String get confirmRestoreTitle => 'Aus den Datei-Tags wiederherstellen?';

  @override
  String get confirmRestoreBody =>
      'Deine Änderungen an diesem Titel werden durch die Daten der Datei ersetzt.';

  @override
  String get removedFromPlaylist => 'Aus der Playlist entfernt';

  @override
  String get removedFromQueue => 'Aus der Warteschlange entfernt';

  @override
  String get playNextDone => 'Wird als Nächstes gespielt';

  @override
  String get ytSearchPrompt => 'Titel suchen oder Link einfügen';

  @override
  String get loadFailed => 'Die Daten konnten nicht geladen werden.';

  @override
  String get artistLoadingSongs => 'Songs werden geladen…';

  @override
  String get artistTopMissing => 'Top-Songs nicht verfügbar';

  @override
  String get navHome => 'Start';

  @override
  String get navSearch => 'Suche';

  @override
  String get devicesTitle => 'Geräte';

  @override
  String get devicesJamActive => 'Aktive Jam';

  @override
  String jamPeople(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Jam, $n Personen',
      one: 'Jam, 1 Person',
    );
    return '$_temp0';
  }

  @override
  String get devicesVisibleTitle => 'Dieses Gerät sichtbar machen';

  @override
  String get devicesVisibleHint =>
      'Um Titel zu empfangen oder eine Jam zu starten, müssen andere Geräte dich im Netzwerk sehen.';

  @override
  String get devicesJamShort => 'Jam';

  @override
  String get devicesSendShort => 'Senden';

  @override
  String get devicesMore => 'Teilen und manuelle Verbindung';

  @override
  String jamParticipantsCount(int n) {
    return '$n Personen';
  }

  @override
  String get playingFrom => 'Wiedergabe von';

  @override
  String get playContextSearch => 'Suche';

  @override
  String get allTracks => 'Alle Titel';

  @override
  String get trackInfo => 'Infos zum Titel';

  @override
  String get searchCuriosity => 'Wissenswertes suchen';

  @override
  String get upNext => 'Als Nächstes';

  @override
  String get openQueue => 'Warteschlange öffnen';

  @override
  String get copyLink => 'Link kopieren';

  @override
  String get moreActions => 'Weitere Aktionen';

  @override
  String get sleepChipEnd => 'Titelende';

  @override
  String get yourLibrary => 'Deine Bibliothek';

  @override
  String playlistCountLabel(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Playlist mit $n Titel',
      one: 'Playlist mit 1 Titel',
    );
    return '$_temp0';
  }

  @override
  String get sortRecent => 'Zuletzt gehört';

  @override
  String get sortAlphabetical => 'Alphabetisch';

  @override
  String get sortAToZ => 'A–Z';

  @override
  String get sortAddedRecently => 'Zuletzt hinzugefügt';

  @override
  String get sortTitleAToZ => 'Titel A–Z';

  @override
  String get sortMostPlayed => 'Am häufigsten gespielt';

  @override
  String get sortTrackCount => 'Anzahl der Titel';

  @override
  String get sortRecentShort => 'Zuletzt';

  @override
  String get sortAddedShort => 'Hinzugefügt';

  @override
  String get sortTrackCountShort => 'Anzahl';

  @override
  String get sortMostPlayedShort => 'Meistgespielt';

  @override
  String get sortAscending => 'Aufsteigend';

  @override
  String get sortDescending => 'Absteigend';

  @override
  String get viewAsGrid => 'Als Raster anzeigen';

  @override
  String get viewAsList => 'Als Liste anzeigen';

  @override
  String get kindAlbum => 'Album';

  @override
  String get kindArtist => 'Künstler';

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
    return '$n Min.';
  }

  @override
  String tracksAndDuration(String tracks, String duration) {
    return '$tracks, $duration';
  }

  @override
  String get mostPlayed => 'Meistgespielt';

  @override
  String get albumsSection => 'Alben';

  @override
  String get addAllToQueue => 'Zur Warteschlange hinzufügen';

  @override
  String addedNToQueue(int n) {
    return '$n Titel zur Warteschlange hinzugefügt';
  }

  @override
  String get editOrder => 'Reihenfolge ändern';

  @override
  String get finishEditing => 'Fertig';

  @override
  String get removeFromPlaylistAction => 'Aus Playlist entfernen';

  @override
  String get noTracksInPlaylist => 'Diese Playlist ist leer';

  @override
  String get greetingMorning => 'Guten Morgen';

  @override
  String get greetingAfternoon => 'Guten Tag';

  @override
  String get greetingEvening => 'Guten Abend';

  @override
  String get homeResume => 'Weiterhören';

  @override
  String get homeTopTracks => 'Meistgespielt';

  @override
  String get homeRediscover => 'Wiederentdecken';

  @override
  String get homeShuffleAll => 'Alles zufällig';

  @override
  String homeShuffleAllSub(String tracks, String hours) {
    return '$tracks, $hours';
  }

  @override
  String hoursCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Stunden',
      one: '1 Stunde',
      zero: 'weniger als eine Stunde',
    );
    return '$_temp0';
  }

  @override
  String get homeAddedLately => 'Neu hinzugefügt';

  @override
  String homeResumeQueue(int n, int m) {
    return 'Titel $n von $m';
  }

  @override
  String homeResumeQueueFrom(String source, int n, int m) {
    return '$source: Titel $n von $m';
  }

  @override
  String homeMinutesLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Noch $count Minuten',
      one: 'Noch 1 Minute',
    );
    return '$_temp0';
  }

  @override
  String homeEpisodeLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'noch $count Min.',
      one: 'noch 1 Min.',
    );
    return '$_temp0';
  }

  @override
  String get homeFanOpen => 'Kürzlich hinzugefügte Titel anzeigen';

  @override
  String get showAll => 'Alle';

  @override
  String get recentSearches => 'Letzte Suchen';

  @override
  String get genresTitle => 'Genres';

  @override
  String downloadsChip(int n) {
    return 'Downloads ($n)';
  }

  @override
  String get gotIt => 'Verstanden';

  @override
  String get searchEmptyLibrary => 'Keine Ergebnisse in der Bibliothek';

  @override
  String get ytInfoTooltip => 'Hinweis zur Nutzung';

  @override
  String removeRecentSearch(String query) {
    return '„$query“ aus letzten Suchen entfernen';
  }

  @override
  String get groupGoTo => 'Gehe zu';

  @override
  String get goToAlbum => 'Zum Album';

  @override
  String get goToArtist => 'Zum Künstler';

  @override
  String get groupQueue => 'Warteschlange';

  @override
  String get groupCollection => 'Sammlung';

  @override
  String get groupEdit => 'Bearbeiten';

  @override
  String get groupOther => 'Mehr';

  @override
  String get queueNowPlaying => 'Wiedergabe';

  @override
  String get queueNext => 'Als Nächstes';

  @override
  String get queueClear => 'Leeren';

  @override
  String get queueCleared => 'Warteschlange geleert';

  @override
  String get queueRebuilt =>
      'Warteschlange aus der laufenden Liste neu erstellt';

  @override
  String get jamOutputsAndSync => 'Ausgänge und Sync';

  @override
  String get jamHostTag => 'Host';

  @override
  String get jamSeekInvalid => 'Ungültige Position für diesen Titel';

  @override
  String get jamEndConfirmTitle => 'Die Jam für alle beenden?';

  @override
  String jamEndConfirmBody(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other:
          'Die $n Gäste werden getrennt und die gemeinsame Warteschlange wird geschlossen.',
      one: 'Der Gast wird getrennt und die gemeinsame Warteschlange geschlossen.',
    );
    return '$_temp0';
  }

  @override
  String get jamEndConfirmAction => 'Beenden';

  @override
  String jamParticipantsLabel(int n, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Teilnehmer: $names',
      one: '1 Teilnehmer: $names',
    );
    return '$_temp0';
  }

  @override
  String get jamWaitingEmpty => 'Keine Jam aktiv';

  @override
  String get activityTitle => 'Aktivität';

  @override
  String activityScan(int done, int total) {
    return 'Scan: $done von $total';
  }

  @override
  String get activityScanIdle => 'Scan läuft';

  @override
  String activityEnrich(int done, int total) {
    return 'Anreichern: $done von $total';
  }

  @override
  String activityDownload(String title) {
    return 'Download, $title';
  }

  @override
  String activityTransfer(String name, int n) {
    return 'Senden an $name, $n Titel';
  }

  @override
  String get activityNone => 'Keine Aktivität';

  @override
  String get activityCompleted => 'Abgeschlossen';

  @override
  String get importPhaseSearching => 'Wird gesucht…';

  @override
  String importPhaseDownloading(int percent) {
    return 'Download $percent %';
  }

  @override
  String importPhaseRetry(int seconds) {
    return 'Neuer Versuch in $seconds s';
  }

  @override
  String get importPhaseEnriching => 'Wird angereichert…';

  @override
  String get importPhaseDownloadStart => 'Download…';

  @override
  String get importFilterAll => 'Alle';

  @override
  String get importFilterActive => 'Laufend';

  @override
  String get importFilterProblems => 'Zu prüfen';

  @override
  String get importFilterDone => 'Fertig';

  @override
  String get importRowsNone => 'Hier keine Titel';

  @override
  String get activityLog => 'Protokoll';

  @override
  String activityLogCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ereignisse',
      one: '1 Ereignis',
      zero: 'Leer',
    );
    return '$_temp0';
  }

  @override
  String get activityLogEmpty =>
      'Noch nichts: beendete Downloads, Importe und Übertragungen erscheinen hier.';

  @override
  String logImport(String name) {
    return 'Import «$name»';
  }

  @override
  String importNotificationText(int done, int total) {
    return '$done von $total';
  }

  @override
  String importNotificationPaused(int done, int total) {
    return 'Pausiert, $done von $total';
  }

  @override
  String importWaitRateLimited(String time) {
    return 'YouTube bittet um eine Pause: weiter um $time';
  }

  @override
  String importWaitNetwork(String time) {
    return 'Kein Netz: neuer Versuch um $time';
  }

  @override
  String importPausedTitle(String name) {
    return 'Import „$name“ pausiert';
  }

  @override
  String get downloadsNotificationTitle => 'Downloads laufen';

  @override
  String downloadsNotificationText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel',
      one: '1 Titel',
    );
    return '$_temp0';
  }

  @override
  String activityRunning(int n) {
    return '$n Aktivitäten laufen';
  }

  @override
  String get settingsLocalNetwork => 'Lokales Netzwerk';

  @override
  String get removeAll => 'Alle entfernen';

  @override
  String get confirmRemoveAllTitle => 'Alle aus der Bibliothek entfernen?';

  @override
  String confirmRemoveAllBody(int n) {
    return '$n fehlende Titel werden aus der Bibliothek entfernt. Die Dateien bleiben unberührt; Favoriten und Playlist-Einträge gehen verloren.';
  }

  @override
  String get csvImportMenu => 'Aus Exportify importieren (CSV)';

  @override
  String get csvImportIntroTitle => 'Playlist importieren';

  @override
  String get csvImportIntroSource =>
      'Die CSV-Datei erstellst du kostenlos auf der Website Exportify — exportify.net (keine App nötig).';

  @override
  String get csvImportStep1 =>
      'Öffne https://exportify.net im Browser (auch am Handy).';

  @override
  String get csvImportStep2 =>
      'Tippe auf „Get Started“ und melde dich mit deinem Spotify-Konto an.';

  @override
  String get csvImportStep3 =>
      'Tippe neben der gewünschten Playlist auf „Export“: eine .csv-Datei mit dem Namen der Playlist wird heruntergeladen.';

  @override
  String get csvImportStep4 =>
      'Komm hierher zurück und tippe auf „CSV-Datei wählen“.';

  @override
  String get csvImportNote =>
      'Codecore sucht die Titel in deiner Bibliothek und lädt die übrigen von YouTube Music.';

  @override
  String get csvImportNoteOffline =>
      'Es werden nur Titel verknüpft, die bereits in deiner Bibliothek sind.';

  @override
  String get csvImportCopy => 'Adresse kopieren';

  @override
  String get csvImportCopied => 'Adresse kopiert';

  @override
  String get csvImportPick => 'Datei wählen';

  @override
  String get csvImportNotExportify =>
      'Format nicht erkannt. Wähle ein CSV (Exportify, TuneMyMusic, Soundiiz, Last.fm) oder eine M3U/M3U8/XSPF-Playlist.';

  @override
  String get csvImportReadFailed => 'Die Datei konnte nicht gelesen werden.';

  @override
  String get csvImportPreviewTitle => 'Playlist importieren';

  @override
  String get csvImportName => 'Name der Playlist';

  @override
  String csvImportSummary(int total, int known, int todo) {
    return '$total Titel, $known schon in der Bibliothek, $todo herunterzuladen';
  }

  @override
  String csvImportSkipped(int n) {
    return '$n Zeilen ignoriert (Podcasts oder lokale Dateien)';
  }

  @override
  String csvImportEstimate(int minutes) {
    return 'Geschätzte Dauer: etwa $minutes Min.';
  }

  @override
  String get csvImportExists =>
      'Eine Playlist mit diesem Namen existiert bereits';

  @override
  String get csvImportUpdate => 'Bestehende aktualisieren (nur neue Titel)';

  @override
  String get csvImportNew => 'Neue Playlist anlegen';

  @override
  String get csvImportGo => 'Importieren';

  @override
  String get csvImportStarted =>
      'Import gestartet: im Aktivitätscenter verfolgen';

  @override
  String activityImport(String name, int done, int total) {
    return 'Import „$name“: $done von $total';
  }

  @override
  String activityImportPaused(String name, int done, int total) {
    return 'Import „$name“: pausiert, $done von $total';
  }

  @override
  String csvImportBanner(int done, int total, int review, int missing) {
    return 'Import: $done von $total, $review zu prüfen, $missing nicht gefunden';
  }

  @override
  String csvImportBannerPaused(int done, int total, int review, int missing) {
    return 'Import pausiert: $done von $total, $review zu prüfen, $missing nicht gefunden';
  }

  @override
  String get csvImportReview => 'Prüfen';

  @override
  String get csvImportResume => 'Fortsetzen';

  @override
  String get csvImportPause => 'Pausieren';

  @override
  String get csvImportCancelTitle => 'Import abbrechen?';

  @override
  String get csvImportCancelBody =>
      'Bereits geladene Titel bleiben in der Playlist.';

  @override
  String csvImportDone(int added, int review, int missing) {
    return 'Import abgeschlossen: $added hinzugefügt, $review zu prüfen, $missing nicht gefunden';
  }

  @override
  String get csvImportFailing =>
      'Zu viele Fehler hintereinander: Import pausiert';

  @override
  String get csvImportReviewTitle => 'Prüfen';

  @override
  String get csvImportToReview => 'Zu prüfen';

  @override
  String get csvImportNotFound => 'Nicht gefunden';

  @override
  String get csvImportErrors => 'Mit Fehlern';

  @override
  String get csvImportRetryAll => 'Alle wiederholen';

  @override
  String get csvImportSkip => 'Überspringen';

  @override
  String get csvImportManual => 'Manuell suchen';

  @override
  String get csvImportNothing => 'Nichts zu prüfen.';

  @override
  String get csvImportSearch => 'Suchen';

  @override
  String csvImportWanted(String title, String artist, String duration) {
    return 'Gesucht: $title, $artist, $duration';
  }

  @override
  String get csvImportDownload => 'Herunterladen';

  @override
  String get csvImportCancelGo => 'Import abbrechen';

  @override
  String get exportLog => 'Protokoll exportieren';

  @override
  String get exportLogHint =>
      'Textdatei ohne persönliche Pfade, Netzwerkadressen oder PINs';

  @override
  String get exportLogDebugOnly =>
      'Nur in der installierten Version (im Debug-Modus wird das Protokoll nicht in eine Datei geschrieben)';

  @override
  String get exportLogNone => 'Es gibt noch kein Protokoll zum Exportieren';

  @override
  String get exportLogSaved => 'Protokoll gespeichert';

  @override
  String get exportLogFailed => 'Protokoll konnte nicht gespeichert werden';

  @override
  String get exportPlaylist => 'Exportieren…';

  @override
  String get exportPlaylistTitle => 'Playlist exportieren';

  @override
  String get exportFormatM3u8 => 'M3U8, für andere Player';

  @override
  String get exportFormatCsv => 'CSV, wie Exportify';

  @override
  String get exportFormatJson => 'JSON, Codecore-Format';

  @override
  String get exportRelativePaths => 'Relative Pfade';

  @override
  String get exportRelativeHint =>
      'Relativ zum gemeinsamen Ordner aller Titel: Datei dort speichern';

  @override
  String get exportAction => 'Exportieren';

  @override
  String get exportSaved => 'Playlist exportiert';

  @override
  String get exportEmpty => 'Die Playlist ist leer';

  @override
  String get exportFailed => 'Playlist konnte nicht exportiert werden';

  @override
  String get ytErrToolOutdated =>
      'yt-dlp ist zu alt: aktualisiere es (Einstellungen, Online und Downloads, Aktualisieren) und versuche es erneut';

  @override
  String ytDlpOutdatedBanner(String version) {
    return 'yt-dlp $version ist zu alt: Downloads funktionieren möglicherweise nicht';
  }

  @override
  String get settingsDownloads => 'Downloads';

  @override
  String ytDlpVersion(String version) {
    return 'yt-dlp $version';
  }

  @override
  String get ytDlpUnknownVersion => 'yt-dlp nicht gefunden';

  @override
  String get ytDlpUpdate => 'Aktualisieren';

  @override
  String ytDlpUpdating(int percent) {
    return 'Aktualisierung… $percent%';
  }

  @override
  String ytDlpUpdated(String version) {
    return 'Auf Version $version aktualisiert';
  }

  @override
  String get ytDlpTooOld => 'Zu alt: Aktualisieren tippen';

  @override
  String get ytDlpUpdateErrNetwork =>
      'Aktualisierung fehlgeschlagen: Netzwerk nicht erreichbar';

  @override
  String get ytDlpUpdateErrHash =>
      'Aktualisierung abgebrochen: Die heruntergeladene Datei hat die Integritätsprüfung nicht bestanden';

  @override
  String get ytDlpUpdateErrOther =>
      'Aktualisierung fehlgeschlagen (siehe Protokoll)';

  @override
  String get downloadParallel => 'Gleichzeitige Downloads';

  @override
  String get downloadParallelHint =>
      'Mehr gleichzeitig ist schneller, aber YouTube kann bremsen';

  @override
  String get downloadRateLimit => 'Geschwindigkeitslimit';

  @override
  String get downloadRateNone => 'Keins';

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
    return 'Download, $title, neuer Versuch in $seconds s ($attempt/$max)';
  }

  @override
  String get downloadFormat => 'Download-Format';

  @override
  String get downloadFormatOriginal => 'Original (beste Qualität)';

  @override
  String get downloadFormatOriginalHint =>
      'Das Audio von YouTube ohne Neukodierung, meist Opus ~160 kbps. Nicht jeder Player und jedes Autoradio spielt es ab.';

  @override
  String get downloadFormatM4a => 'M4A (empfohlen)';

  @override
  String get downloadFormatM4aHint =>
      'Fast wie das Original, ohne Neukodierung: schnell, klein (~1 MB/min), läuft überall.';

  @override
  String get downloadFormatMp3High => 'MP3 320 kbps';

  @override
  String get downloadFormatMp3HighHint =>
      'Läuft auf allem. Neu kodiert: leichter Verlust, große Dateien (~2,4 MB/min), langsamerer Download.';

  @override
  String get downloadFormatMp3Low => 'MP3 192 kbps (niedrigste Qualität)';

  @override
  String get downloadFormatMp3LowHint =>
      'Läuft auf allem, halb so groß wie MP3 320 (~1,4 MB/min), aber die niedrigste Qualität.';

  @override
  String get searchCacheClear => 'Suchcache leeren';

  @override
  String searchCacheCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gespeicherte Suchen',
      one: '1 gespeicherte Suche',
      zero: 'Leer',
    );
    return '$_temp0';
  }

  @override
  String get searchCacheCleared => 'Cache geleert';

  @override
  String csvImportLengthOff(String found, String wanted) {
    return 'Andere Länge: $found statt $wanted';
  }

  @override
  String get csvImportKeep => 'Diesen behalten';

  @override
  String get csvImportTooBig =>
      'Die Datei ist zu groß für eine Playlist (höchstens 5 MB und 10.000 Titel)';

  @override
  String get csvImportAlsoAccepts =>
      'Auch akzeptiert: TuneMyMusic, Soundiiz, Last.fm (CSV), M3U/M3U8, XSPF.';

  @override
  String get csvImportPlanned => 'Treffer bereit: prüfen und herunterladen';

  @override
  String get csvImportLinkOnly => 'Nur verknüpfen (keine Downloads)';

  @override
  String get csvImportLinkOnlyHint =>
      'Erstellt die Playlist nur aus dem, was du schon hast';

  @override
  String get csvImportPlanFirst => 'Vor dem Download prüfen';

  @override
  String get csvImportPlanFirstHint =>
      'Sucht alles, dann wählst du, was geladen wird';

  @override
  String get csvImportPlanTitle => 'Treffer';

  @override
  String csvImportPlanGo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Titel laden',
      one: '1 Titel laden',
    );
    return '$_temp0';
  }

  @override
  String get csvImportPlanKnown => 'bereits geladen';

  @override
  String get csvImportPlanEmpty => 'Nichts herunterzuladen';

  @override
  String csvImportBannerPlanned(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Titel zum Laden',
      one: '1 Titel zum Laden',
    );
    return 'Treffer bereit: $_temp0';
  }

  @override
  String get settingsAdvanced => 'Erweitert';

  @override
  String get importSureThreshold => 'Sicherer Treffer ab';

  @override
  String get importSureThresholdHint =>
      'Über dieser Punktzahl wird ein importierter Titel ohne Rückfrage geladen';

  @override
  String get importReviewThreshold => 'Zur Prüfung ab';

  @override
  String get importReviewThresholdHint =>
      'Zwischen dieser und der sicheren Punktzahl landet der Titel in «Zu prüfen», darunter in «Nicht gefunden»';

  @override
  String get importThresholdsReset => 'Standardwerte wiederherstellen';

  @override
  String csvImportEstimateHours(int hours, int minutes) {
    return 'Geschätzte Zeit: etwa $hours Std. $minutes Min.';
  }

  @override
  String csvImportBlocks(int size) {
    return 'In Blöcken zu $size importieren';
  }

  @override
  String csvImportBigWarning(int n) {
    return '$n Titel zum Laden: das dauert Stunden. In Blöcken, einer nach dem anderen, bleibt die Reihenfolge richtig und du kannst zwischen den Blöcken anhalten.';
  }

  @override
  String get etaLessThanMinute => 'unter 1 Min.';

  @override
  String etaMinutes(int minutes) {
    return 'etwa $minutes Min.';
  }

  @override
  String etaHours(int hours, int minutes) {
    return 'etwa $hours Std. $minutes Min.';
  }

  @override
  String get csvImportOwnFolder => 'Ordner für diese Playlist';

  @override
  String get csvImportOwnFolderHint =>
      'Speichert die Downloads in einem Unterordner mit dem Namen der Playlist';

  @override
  String get csvImportNumberFiles => 'Dateien nummerieren';

  @override
  String get csvImportNumberFilesHint =>
      '07 - Interpret - Titel: der Ordner spielt auch außerhalb von Codecore in der richtigen Reihenfolge';

  @override
  String get csvImportFetchCovers => 'Cover suchen';

  @override
  String get csvImportFetchCoversHint =>
      'Sucht nach jedem Download das Albumcover bei iTunes (Album und Interpret aus der Datei)';

  @override
  String get csvImportExport => 'Ergebnis exportieren';

  @override
  String get csvImportExported => 'Ergebnis gespeichert';

  @override
  String get csvOutHeaderRow => 'Zeile';

  @override
  String get csvOutHeaderTitle => 'Titel';

  @override
  String get csvOutHeaderArtists => 'Interpreten';

  @override
  String get csvOutHeaderAlbum => 'Album';

  @override
  String get csvOutHeaderDuration => 'Dauer (ms)';

  @override
  String get csvOutHeaderIsrc => 'ISRC';

  @override
  String get csvOutHeaderStatus => 'Ergebnis';

  @override
  String get csvOutHeaderNote => 'Grund';

  @override
  String get csvOutHeaderVideo => 'Gewähltes Video';

  @override
  String get csvOutHeaderScore => 'Punktzahl';

  @override
  String get importStatusPending => 'Zu suchen';

  @override
  String get importStatusQueued => 'In Warteschlange';

  @override
  String get importStatusDownloaded => 'Geladen';

  @override
  String get importStatusLinked => 'Schon in der Bibliothek';

  @override
  String get importStatusReview => 'Zu prüfen';

  @override
  String get importStatusNotFound => 'Nicht gefunden';

  @override
  String get importStatusFailed => 'Fehler';

  @override
  String get importStatusSkipped => 'Übersprungen';

  @override
  String get importStatusPlanned => 'Geplant';

  @override
  String get importStatusRemoved => 'Aus der Quelle entfernt';

  @override
  String get importNoteNoResults => 'Keine Ergebnisse';

  @override
  String get importNoteLowScore => 'Treffer nicht sicher genug';

  @override
  String get importNoteLinkOnly => 'Nur verknüpfen: nicht gesucht';

  @override
  String get importNoteYoutubeOff => 'Downloads sind aus';

  @override
  String get importNoteDownloadFailed => 'Download fehlgeschlagen';

  @override
  String get importNoteLengthOff => 'Länge weicht von der Datei ab';

  @override
  String get importNoteUnchanged => 'Schon in der Playlist';

  @override
  String get csvImportSync => 'Synchronisieren';

  @override
  String csvImportSyncCounts(int added, int removed) {
    return '$added neu, $removed aus der Playlist entfernt (Dateien bleiben)';
  }

  @override
  String get csvImportSyncChecking => 'Unterschiede werden geprüft…';

  @override
  String get playbackSpeed => 'Wiedergabegeschwindigkeit';

  @override
  String get playbackSpeedHint =>
      'Die Tonhöhe bleibt original. Der Einschlaf-Timer zählt echte Zeit, nicht die des Titels.';

  @override
  String resumeFrom(String time) {
    return 'weiter bei $time';
  }

  @override
  String get restartFromBeginning => 'Von vorn beginnen';

  @override
  String get previewTrack => '20-s-Vorschau';

  @override
  String get equalizer => 'Equalizer';

  @override
  String get eqOutputSpeaker => 'Lautsprecher';

  @override
  String get eqOutputHeadphones => 'Kopfhörer';

  @override
  String get eqHint =>
      'Jeder Ausgang merkt sich seine Kurve: sie wechselt von selbst, wenn du Kopfhörer anschließt.';

  @override
  String get eqPresetFlat => 'Flach';

  @override
  String get eqPresetBass => 'Bass';

  @override
  String get eqPresetVoice => 'Stimme';

  @override
  String get eqPresetTreble => 'Höhen';

  @override
  String get eqPresetCustom => 'Eigene';

  @override
  String get eqReset => 'Zurücksetzen';

  @override
  String get eqWaiting =>
      'Die Bänder erscheinen, sobald der erste Titel läuft.';

  @override
  String get eqUnavailable =>
      'Der Equalizer ist auf diesem Gerät nicht verfügbar.';

  @override
  String get transitionMode => 'Übergang zwischen Titeln';

  @override
  String get transitionNormal => 'Normal';

  @override
  String get transitionGapless => 'Lückenlos';

  @override
  String get transitionCrossfade => 'Überblenden';

  @override
  String get transitionHint =>
      'Lückenlos funktioniert am besten mit Titeln im selben Format (zum Beispiel alle FLAC).';

  @override
  String crossfadeLength(int seconds) {
    return 'Dauer der Überblendung: $seconds s';
  }

  @override
  String get crossfadePlainInAlbum =>
      'Innerhalb eines Albums nicht überblenden';

  @override
  String get crossfadePlainInAlbumHint =>
      'Innerhalb eines Albums folgen die Titel lückenlos aufeinander, ohne sich zu überlagern.';

  @override
  String get selectedRow => 'Ausgewählt';

  @override
  String selectedRowAt(int position) {
    return 'Ausgewählt, Nummer $position';
  }

  @override
  String get curiositySong => 'Zum Lied';

  @override
  String get curiosityArtist => 'Zum Künstler';

  @override
  String get showMore => 'Mehr anzeigen';

  @override
  String get showLess => 'Weniger anzeigen';

  @override
  String get curiosityNoSong => 'Keine Seite zu diesem Lied';

  @override
  String get curiosityNoArtist => 'Keine Seite zum Künstler';

  @override
  String get themeNew => 'Neues Design';

  @override
  String get themeEdit => 'Bearbeiten';

  @override
  String get themeDuplicate => 'Duplizieren';

  @override
  String get themeDelete => 'Löschen';

  @override
  String get themeExport => 'Exportieren';

  @override
  String get themeImport => 'Design importieren';

  @override
  String get themeName => 'Name des Designs';

  @override
  String get themeBase => 'Ausgehend von';

  @override
  String get themeModeSimple => 'Einfach';

  @override
  String get themeModeAdvanced => 'Erweitert';

  @override
  String get themeSave => 'Speichern';

  @override
  String get themeEditorTitle => 'Eigenes Design';

  @override
  String get themeDiscardTitle => 'Änderungen verwerfen?';

  @override
  String get themeDiscardBody =>
      'Die Änderungen an diesem Design wurden nicht gespeichert.';

  @override
  String get themeDiscard => 'Verwerfen';

  @override
  String get smartDiscardBody =>
      'Die Änderungen an dieser Playlist wurden nicht gespeichert.';

  @override
  String get themePreview => 'Vorschau';

  @override
  String get themeResetColor => 'Farbe zurücksetzen';

  @override
  String get themeContrastTitle => 'Lesbarkeit';

  @override
  String get themeContrastLow => 'Schwer lesbar';

  @override
  String get themeContrastOk => 'Lesbar';

  @override
  String get themeFix => 'Korrigieren';

  @override
  String get themeSaved => 'Design gespeichert';

  @override
  String get themeLimit => 'Du hast schon 20 Designs: lösche eines';

  @override
  String get themeImported => 'Design importiert';

  @override
  String get themeImportFailed => 'Die Datei ist kein gültiges Design';

  @override
  String get themeDeleted => 'Design gelöscht';

  @override
  String get themeMine => 'Meine Designs';

  @override
  String get tokenBg => 'Hintergrund';

  @override
  String get tokenSurface1 => 'Fläche 1';

  @override
  String get tokenSurface2 => 'Fläche 2';

  @override
  String get tokenSurface3 => 'Fläche 3';

  @override
  String get tokenAccent => 'Akzent';

  @override
  String get tokenAccentSoft => 'Heller Akzent';

  @override
  String get tokenOnAccent => 'Text auf Akzent';

  @override
  String get tokenText => 'Text';

  @override
  String get tokenTextMuted => 'Sekundärer Text';

  @override
  String get tokenTextFaint => 'Blasser Text';

  @override
  String get tokenHero => 'Player-Hintergrund';

  @override
  String get tokenError => 'Fehler';

  @override
  String get pickerHue => 'Farbton';

  @override
  String get pickerSv => 'Sättigung und Helligkeit';

  @override
  String get pickerAlpha => 'Transparenz';

  @override
  String get pickerHex => 'Farbcode';

  @override
  String get pickerInvalid => 'Ungültiger Code';

  @override
  String get pickerRecent => 'Zuletzt verwendet';

  @override
  String get contrastTextBg => 'Text auf Hintergrund';

  @override
  String get contrastMutedSurface => 'Sekundärer Text auf Fläche';

  @override
  String get contrastOnAccent => 'Text auf Akzent';

  @override
  String get contrastAccentBg => 'Akzent auf Hintergrund';

  @override
  String get themeBackground => 'Seitenhintergrund';

  @override
  String get bgSolid => 'Einfarbig';

  @override
  String get bgGradient => 'Farbverlauf';

  @override
  String get bgImage => 'Bild';

  @override
  String get bgGradientEnd => 'Endfarbe';

  @override
  String get bgAngle => 'Richtung';

  @override
  String get bgPickImage => 'Bild wählen …';

  @override
  String get bgRemoveImage => 'Bild entfernen';

  @override
  String get bgDim => 'Abdunklung';

  @override
  String get bgBlur => 'Unschärfe';

  @override
  String get bgCoverBackdrop => 'Wiedergabe: Farbton des Covers';

  @override
  String get blurredChrome => 'Unscharfes Dock und Kopfzeilen';

  @override
  String get blurredChromeHint => 'Kann auf schwächeren Handys bremsen';

  @override
  String get bgImageFailed => 'Das Bild konnte nicht verwendet werden';

  @override
  String themeCopyName(String name) {
    return '$name (Kopie)';
  }

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ausgewählt',
      one: '1 ausgewählt',
    );
    return '$_temp0';
  }

  @override
  String get selectAll => 'Alle auswählen';

  @override
  String get exitSelection => 'Auswahl beenden';

  @override
  String get bulkActions => 'Aktionen';

  @override
  String playNextMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel werden als Nächstes gespielt',
      one: '1 Titel wird als Nächstes gespielt',
    );
    return '$_temp0';
  }

  @override
  String addedToQueueMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel zur Warteschlange hinzugefügt',
      one: '1 Titel zur Warteschlange hinzugefügt',
    );
    return '$_temp0';
  }

  @override
  String addedToPlaylistMany(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel zu „$name“ hinzugefügt',
      one: '1 Titel zu „$name“ hinzugefügt',
    );
    return '$_temp0';
  }

  @override
  String addedToPlaylistSkipped(int added, int skipped, String name) {
    return '$added zu „$name“ hinzugefügt, $skipped schon vorhanden';
  }

  @override
  String allAlreadyInPlaylist(String name) {
    return 'Alle waren schon in „$name“';
  }

  @override
  String favoritesAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel zu den Favoriten hinzugefügt',
      one: '1 Titel zu den Favoriten hinzugefügt',
    );
    return '$_temp0';
  }

  @override
  String favoritesRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel aus den Favoriten entfernt',
      one: '1 Titel aus den Favoriten entfernt',
    );
    return '$_temp0';
  }

  @override
  String get bulkAddToFavorites => 'Zu Favoriten hinzufügen';

  @override
  String get bulkRemoveFromFavorites => 'Aus Favoriten entfernen';

  @override
  String removeManyFromPlaylistTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel aus der Playlist entfernen?',
      one: '1 Titel aus der Playlist entfernen?',
    );
    return '$_temp0';
  }

  @override
  String get removeManyFromPlaylistBody =>
      'Die Dateien und die Bibliothek bleiben unberührt.';

  @override
  String removedManyFromPlaylist(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel entfernt',
      one: '1 Titel entfernt',
    );
    return '$_temp0';
  }

  @override
  String removeManyFromLibraryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel aus der Bibliothek entfernen?',
      one: '1 Titel aus der Bibliothek entfernen?',
    );
    return '$_temp0';
  }

  @override
  String get removeManyFromLibraryBody =>
      'Die Dateien existieren nicht mehr: Sie verschwinden nur aus der Bibliothek (Favoriten und Playlist-Einträge dieser Titel gehen verloren).';

  @override
  String removedManyFromLibrary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel aus der Bibliothek entfernt',
      one: '1 Titel aus der Bibliothek entfernt',
    );
    return '$_temp0';
  }

  @override
  String ytDownloadsStarted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Downloads gestartet',
      one: '1 Download gestartet',
    );
    return '$_temp0';
  }

  @override
  String ytDownloadsSkipped(int started, int skipped) {
    return '$started Downloads gestartet, $skipped bereits in der Bibliothek oder in Arbeit';
  }

  @override
  String get ytNothingToDownload =>
      'Alle sind schon in der Bibliothek oder in Arbeit';

  @override
  String get themeChiaro => 'Hell';

  @override
  String get settingsAccent => 'Akzentfarbe';

  @override
  String get accentViola => 'Violett';

  @override
  String get accentBlu => 'Blau';

  @override
  String get accentAcqua => 'Türkis';

  @override
  String get accentVerde => 'Grün';

  @override
  String get accentAmbra => 'Bernstein';

  @override
  String get accentArancio => 'Orange';

  @override
  String get accentRosa => 'Rosa';

  @override
  String get accentRosso => 'Rot';

  @override
  String get onboardingSkip => 'Überspringen';

  @override
  String get onboardingNext => 'Weiter';

  @override
  String get onboardingStart => 'Los geht’s';

  @override
  String onboardingPageOf(int page, int total) {
    return 'Seite $page von $total';
  }

  @override
  String onboardingStepOf(int page, int total) {
    return '$page von $total';
  }

  @override
  String get onboardingWelcomeTitle => 'Willkommen bei Codecore';

  @override
  String get onboardingWelcomeBody =>
      'Dein persönlicher Musikplayer: kein Konto, kein Server. Deine Musik bleibt auf deinem Gerät.';

  @override
  String get onboardingFoldersTitle => 'Deine Musik';

  @override
  String get onboardingFoldersBody =>
      'Wähle die Ordner mit deinen Titeln. Codecore liest sie nur: Es ändert oder verschiebt sie nie.';

  @override
  String onboardingFoldersAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ordner hinzugefügt',
      one: '1 Ordner hinzugefügt',
    );
    return '$_temp0';
  }

  @override
  String get onboardingAllowAccess => 'Zugriff auf Audiodateien erlauben';

  @override
  String get onboardingAccessGranted => 'Zugriff erlaubt';

  @override
  String get onboardingOnlineTitle => 'Online-Funktionen';

  @override
  String get onboardingOnlineBody =>
      'Sie sind aus: Codecore geht nie von allein online. Du kannst sie jetzt oder später in den Einstellungen einschalten.';

  @override
  String get onboardingShareTitle => 'Downloads, Jam und Teilen';

  @override
  String get onboardingYoutubeBody =>
      'Du kannst Titel von YouTube auf dein Gerät laden und wie den Rest deiner Musik hören.';

  @override
  String get onboardingJamBody =>
      'Mit einer Jam hörst du dieselbe Musik gemeinsam mit einem anderen Gerät im selben Netzwerk.';

  @override
  String get onboardingSendBody =>
      'Du kannst Titel mit einer PIN an andere Geräte in der Nähe senden, ohne Umweg über das Internet.';

  @override
  String get historyTitle => 'Verlauf';

  @override
  String get historySubtitle => 'Was du gehört hast';

  @override
  String get historyToday => 'Heute';

  @override
  String get historyYesterday => 'Gestern';

  @override
  String get historyEmpty => 'Hier erscheint, was du hörst.';

  @override
  String get historyOff =>
      'Der Verlauf ist aus: Schalte ihn unter Einstellungen, Wiedergabe ein.';

  @override
  String get historyClear => 'Verlauf löschen';

  @override
  String get historyClearTitle => 'Verlauf löschen?';

  @override
  String get historyClearBody =>
      'Gelöscht wird nur die Liste der Wiedergaben: Zähler, Favoriten und Playlists bleiben unverändert.';

  @override
  String get historyCleared => 'Verlauf gelöscht';

  @override
  String get settingsRecordHistory => 'Hörverlauf speichern';

  @override
  String get settingsRecordHistoryHint =>
      'Bleibt auf dem Gerät. Wenn aus, wird nichts mehr hinzugefügt.';

  @override
  String get statsTitle => 'Statistiken';

  @override
  String get statsSubtitle => 'Wie viel und was du hörst';

  @override
  String get statsMonth => 'Monat';

  @override
  String get statsYear => 'Jahr';

  @override
  String get statsPrevious => 'Voriger Zeitraum';

  @override
  String get statsNext => 'Nächster Zeitraum';

  @override
  String get statsEmpty => 'Keine Wiedergaben in diesem Zeitraum.';

  @override
  String statsPlays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Wiedergaben',
      one: '1 Wiedergabe',
    );
    return '$_temp0';
  }

  @override
  String statsDistinct(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count verschiedene Titel',
      one: '1 anderer Titel',
    );
    return '$_temp0';
  }

  @override
  String statsHoursMinutes(int hours, int minutes) {
    return '$hours Std. $minutes Min.';
  }

  @override
  String get statsTopTracks => 'Meistgespielte Titel';

  @override
  String get statsTopArtists => 'Meistgespielte Künstler';

  @override
  String get statsTopAlbums => 'Meistgespielte Alben';

  @override
  String get statsFavouriteHour => 'Lieblingsstunde';

  @override
  String get statsFirstListen => 'Erste Wiedergabe';

  @override
  String statsFirstValue(String title, String date) {
    return '$title, $date';
  }

  @override
  String get statsYourMonth => 'Dein Monat';

  @override
  String ruleWarning(String term) {
    return '„$term“ verstehe ich nicht: ich suche es als Text.';
  }

  @override
  String get smartPlaylistNew => 'Neue intelligente Playlist';

  @override
  String get smartPlaylistEdit => 'Intelligente Playlist bearbeiten';

  @override
  String get smartPlaylistLabel => 'Intelligente Playlist';

  @override
  String get smartName => 'Name';

  @override
  String get smartNameRequired => 'Gib einen Namen ein';

  @override
  String get smartNoRules =>
      'Ohne Regeln enthält die Playlist die ganze Bibliothek.';

  @override
  String get smartSortBy => 'Sortieren nach';

  @override
  String get smartSortMostPlayed => 'Meistgespielt';

  @override
  String get smartSortRandom => 'Zufällig';

  @override
  String get smartTemplates => 'Vorlagen';

  @override
  String get smartTplNever => 'Nie gespielt';

  @override
  String get smartTplRecent => 'Kürzlich hinzugefügt';

  @override
  String get smartTplTop => 'Meistgespielte';

  @override
  String get smartTpl90s => 'Die 90er';

  @override
  String get smartConvert => 'In normale Playlist umwandeln';

  @override
  String smartConverted(String name) {
    return 'Playlist „$name“ mit der aktuellen Liste erstellt';
  }

  @override
  String smartDeleteTitle(String name) {
    return '„$name“ löschen?';
  }

  @override
  String get smartDeleteBody =>
      'Gelöscht wird nur die Regel: Die Titel bleiben, wo sie sind.';

  @override
  String get smartAutoNote => 'Die Liste aktualisiert sich von selbst.';

  @override
  String get tagsTitle => 'Labels';

  @override
  String get tagsSubtitle => 'Deine eigenen Labels';

  @override
  String tagsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Labels',
      one: '1 Label',
    );
    return '$_temp0';
  }

  @override
  String get tagsEllipsis => 'Labels …';

  @override
  String get tagNew => 'Neues Label';

  @override
  String get tagRename => 'Label umbenennen';

  @override
  String get tagColor => 'Farbe';

  @override
  String get tagNoColor => 'Keine Farbe';

  @override
  String get tagNameTaken => 'Ein Label mit diesem Namen gibt es schon';

  @override
  String tagDeleteTitle(String name) {
    return 'Das Label „$name“ löschen?';
  }

  @override
  String get tagDeleteBody =>
      'Nur das Label wird von den Titeln entfernt: Sie bleiben in der Bibliothek.';

  @override
  String get tagsEmpty =>
      'Noch keine Labels: Lege eines im Menü eines Titels an.';

  @override
  String get tagAddToSelection => 'Label hinzufügen …';

  @override
  String get tagRemoveFromSelection => 'Label entfernen …';

  @override
  String tagAssigned(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel mit „$name“ versehen',
      one: '1 Titel mit „$name“ versehen',
    );
    return '$_temp0';
  }

  @override
  String tagUnassigned(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '„$name“ von $count Titeln entfernt',
      one: '„$name“ von 1 Titel entfernt',
    );
    return '$_temp0';
  }

  @override
  String get tagNoneToRemove => 'Die gewählten Titel haben keine Labels.';

  @override
  String get cleanupSection => 'Mediathek aufräumen';

  @override
  String get duplicatesTitle => 'Duplikate';

  @override
  String get duplicatesTileHint =>
      'Derselbe Titel in mehreren Kopien oder Qualitäten';

  @override
  String get duplicatesIntro =>
      'Sucht denselben Titel in mehreren Kopien: dieselbe Datei in zwei Ordnern oder denselben Titel in zwei Qualitäten. Vor dem Zusammenführen siehst du eine Vorschau. Favoriten, Playlists, Wiedergaben, Texte und Labels gehen auf den Titel über, den du behältst; die anderen werden nur ausgeblendet und lassen sich unter „Ausgeblendete Titel“ wiederherstellen. Keine Datei wird ohne doppelte Bestätigung gelöscht.';

  @override
  String get duplicatesSearch => 'Duplikate suchen';

  @override
  String get duplicatesSearchAgain => 'Erneut suchen';

  @override
  String get duplicatesReading => 'Mediathek wird gelesen …';

  @override
  String duplicatesHashing(int done, int total) {
    return 'Dateien werden geprüft: $done von $total';
  }

  @override
  String get duplicatesGrouping => 'Titel werden verglichen …';

  @override
  String get duplicatesFailed =>
      'Die Suche ist fehlgeschlagen. Versuche es erneut.';

  @override
  String get duplicatesNone => 'Keine Duplikate gefunden';

  @override
  String duplicatesSummary(int groups, int hidden) {
    String _temp0 = intl.Intl.pluralLogic(
      groups,
      locale: localeName,
      other: '$groups Gruppen',
      one: '1 Gruppe',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hidden,
      locale: localeName,
      other: '$hidden Titel auszublenden',
      one: '1 Titel auszublenden',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get duplicatesExactBadge => 'Identisch';

  @override
  String get duplicatesProbableBadge => 'Wahrscheinlich';

  @override
  String get duplicatesKeepLabel => 'Behalten';

  @override
  String get duplicatesPickKeep => 'Tippe auf einen Titel, um ihn zu behalten';

  @override
  String get duplicatesMerge => 'Zusammenführen';

  @override
  String get duplicatesNotDuplicates => 'Keine Duplikate';

  @override
  String duplicatesMergeAllExact(int count) {
    return 'Alle identischen zusammenführen ($count)';
  }

  @override
  String get duplicatesMergeAllTitle => 'Alle identischen zusammenführen?';

  @override
  String duplicatesMergeAllBody(int groups, int hidden) {
    String _temp0 = intl.Intl.pluralLogic(
      groups,
      locale: localeName,
      other: '$groups Gruppen',
      one: '1 Gruppe',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hidden,
      locale: localeName,
      other: '$hidden Titel ausgeblendet',
      one: '1 Titel ausgeblendet',
    );
    return '$_temp0, $_temp1. Favoriten, Playlists, Wiedergaben und Texte gehen auf die Titel über, die bleiben.';
  }

  @override
  String duplicatesMerged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel ausgeblendet',
      one: '1 Titel ausgeblendet',
    );
    return 'Zusammengeführt: $_temp0';
  }

  @override
  String duplicatesDeleteFiles(int count, String size) {
    return 'Auch die Dateien löschen ($count, $size)';
  }

  @override
  String get duplicatesDeleteListTitle => 'Diese Dateien löschen?';

  @override
  String get duplicatesDeleteListBody =>
      'Sie werden vom Gerät gelöscht und lassen sich nicht wiederherstellen. Die Titel, die du behältst, bleiben, wo sie sind.';

  @override
  String get duplicatesDeleteContinue => 'Weiter';

  @override
  String duplicatesDeleteFinalTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien endgültig löschen?',
      one: '1 Datei endgültig löschen?',
    );
    return '$_temp0';
  }

  @override
  String duplicatesDeleteFinalBody(String size) {
    return 'Freigegebener Speicher: $size. Das lässt sich nicht rückgängig machen.';
  }

  @override
  String get duplicatesDeleteGo => 'Endgültig löschen';

  @override
  String get duplicatesDeleteDoneTitle => 'Fertig';

  @override
  String duplicatesDeleteDone(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien gelöscht',
      one: '1 Datei gelöscht',
    );
    return '$_temp0 ($size).';
  }

  @override
  String duplicatesDeleteFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien nicht gelöscht:',
      one: '1 Datei nicht gelöscht:',
    );
    return '$_temp0';
  }

  @override
  String duplicatesDeleteSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Dateien unberührt: Es ist dieselbe Datei wie der behaltene Titel.',
      one: '1 Datei unberührt: Es ist dieselbe Datei wie der behaltene Titel.',
    );
    return '$_temp0';
  }

  @override
  String get duplicatesDeleteAndroidHint =>
      'Unter Android lassen sich nur Dateien in Ordnern löschen, auf die die App Zugriff hat.';

  @override
  String activityCleanup(int done, int total) {
    return 'Duplikatsuche: $done von $total';
  }

  @override
  String get hiddenTracksTitle => 'Ausgeblendete Titel';

  @override
  String hiddenTracksCount(int count) {
    return 'Ausgeblendete Titel ($count)';
  }

  @override
  String get hiddenTracksEmpty => 'Keine ausgeblendeten Titel';

  @override
  String get hiddenTracksHint =>
      'Zusammengeführte Duplikate erscheinen nicht in der Mediathek. „Wiederherstellen“ bringt sie zurück.';

  @override
  String get hiddenRestore => 'Wiederherstellen';

  @override
  String hiddenRestored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel wiederhergestellt',
      one: '1 Titel wiederhergestellt',
    );
    return '$_temp0';
  }

  @override
  String get albumMergeWith => 'Zusammenführen mit …';

  @override
  String get albumMergeTitle => 'Alben zusammenführen';

  @override
  String albumMergeIntro(String name) {
    return 'Wähle die Alben, die mit „$name“ zusammengeführt werden. Die Titel wandern in ein einziges Album mit dem angegebenen Titel und Interpreten; das Cover bleibt das von „$name“.';
  }

  @override
  String get albumMergeSearch => 'Album suchen';

  @override
  String get albumMergeNone => 'Es gibt keine anderen Alben';

  @override
  String get albumFieldTitle => 'Albumtitel';

  @override
  String get albumFieldArtist => 'Albuminterpret';

  @override
  String get albumMergeAction => 'Alben zusammenführen';

  @override
  String albumMerged(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Alben mit „$name“ zusammengeführt',
      one: '1 Album mit „$name“ zusammengeführt',
    );
    return '$_temp0';
  }

  @override
  String get moveToAlbum => 'In ein neues Album verschieben …';

  @override
  String get moveToAlbumTitle => 'In ein Album verschieben';

  @override
  String moveToAlbumBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel wandern',
      one: '1 Titel wandert',
    );
    return '$_temp0 in das angegebene Album. Existiert es schon, werden sie dort eingeordnet.';
  }

  @override
  String get moveToAlbumGo => 'Verschieben';

  @override
  String movedToAlbum(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel nach „$name“ verschoben',
      one: '1 Titel nach „$name“ verschoben',
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
  String get playlistSourceTitle => 'YouTube-Playlist oder -Kanal';

  @override
  String get playlistSourceLoading => 'Videoliste wird gelesen …';

  @override
  String get playlistSourceName => 'Name der Playlist';

  @override
  String playlistSourceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Videos',
      one: '1 Video',
    );
    return '$_temp0';
  }

  @override
  String playlistSourceUnavailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Videos nicht verfügbar (privat oder entfernt)',
      one: '1 Video nicht verfügbar (privat oder entfernt)',
    );
    return '$_temp0';
  }

  @override
  String playlistSourceTruncated(int count) {
    return 'Es werden die ersten $count Videos angezeigt.';
  }

  @override
  String playlistSourceLong(int count, String time) {
    return 'Das sind $count Videos: Es dauert $time.';
  }

  @override
  String get playlistSourceNone => 'Keines';

  @override
  String get playlistSourceEmpty =>
      'Hier gibt es keine Videos zum Herunterladen.';

  @override
  String playlistSourceGo(int count) {
    return 'In eine Playlist herunterladen ($count)';
  }

  @override
  String playlistSourceStarted(String name) {
    return 'Downloads in der Playlist „$name“ gestartet';
  }

  @override
  String get podcastsTitle => 'Podcasts';

  @override
  String podcastsSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Podcasts',
      one: '1 Podcast',
    );
    return '$_temp0';
  }

  @override
  String get podcastsNotice =>
      'Podcasts werden nur aktualisiert, wenn du es verlangst.';

  @override
  String get podcastsEmpty => 'Du hast keinen Podcast abonniert.';

  @override
  String get podcastAdd => 'Podcast hinzufügen';

  @override
  String get podcastRefreshAll => 'Alle aktualisieren';

  @override
  String get podcastRefresh => 'Aktualisieren';

  @override
  String podcastRefreshed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neue Folgen',
      one: '1 neue Folge',
      zero: 'Keine neuen Folgen',
    );
    return '$_temp0';
  }

  @override
  String podcastRefreshFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Podcasts konnten nicht aktualisiert werden',
      one: '1 Podcast konnte nicht aktualisiert werden',
    );
    return '$_temp0';
  }

  @override
  String get podcastFeedUrl => 'Feed-Adresse';

  @override
  String get podcastSubscribe => 'Abonnieren';

  @override
  String get podcastSearchHint => 'Podcast nach Namen suchen';

  @override
  String get podcastSearchNone => 'Kein Podcast gefunden';

  @override
  String podcastSubscribed(String name) {
    return '„$name“ abonniert';
  }

  @override
  String podcastEpisodesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Folgen',
      one: '1 Folge',
    );
    return '$_temp0';
  }

  @override
  String podcastToListen(int count) {
    return '$count zum Anhören';
  }

  @override
  String get podcastNoEpisodes => 'Keine Folgen.';

  @override
  String get podcastStateDownloaded => 'Heruntergeladen';

  @override
  String podcastStateDownloading(int percent) {
    return 'Wird geladen … $percent %';
  }

  @override
  String get podcastStateHeard => 'Gehört';

  @override
  String podcastStateRemaining(String time) {
    return 'Noch $time';
  }

  @override
  String get podcastMarkHeard => 'Als gehört markieren';

  @override
  String get podcastMarkNotHeard => 'Als ungehört markieren';

  @override
  String get podcastDeleteFile => 'Datei löschen';

  @override
  String get podcastAutoDelete => 'Gehörte Folgen löschen';

  @override
  String get podcastAutoDeleteNever => 'Nie';

  @override
  String podcastAutoDeleteAfter(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tage',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get podcastUnsubscribe => 'Podcast löschen';

  @override
  String get podcastUnsubscribeTitle => 'Podcast löschen?';

  @override
  String podcastUnsubscribeBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Der Podcast und $count heruntergeladene Folgen werden vom Gerät gelöscht.',
      one:
          'Der Podcast und 1 heruntergeladene Folge werden vom Gerät gelöscht.',
      zero: 'Der Podcast wird vom Gerät gelöscht.',
    );
    return '$_temp0';
  }

  @override
  String podcastLastChecked(String when) {
    return 'Aktualisiert $when';
  }

  @override
  String get podcastNeverChecked => 'Nie aktualisiert';

  @override
  String get podcastErrInvalidUrl =>
      'Das sieht nicht nach einer gültigen Webadresse aus.';

  @override
  String get podcastErrTooLarge => 'Der Feed ist zu groß.';

  @override
  String get podcastErrNetwork => 'Der Server ist nicht erreichbar.';

  @override
  String get podcastErrNotFeed => 'Diese Adresse ist kein Podcast-Feed.';

  @override
  String get podcastErrUnsupportedFormat => 'Nicht unterstütztes Audioformat.';

  @override
  String get syncTitle => 'Playlists abgleichen';

  @override
  String syncAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neue',
      one: '1 neue',
    );
    return '$_temp0';
  }

  @override
  String syncUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aktualisiert',
      one: '1 aktualisiert',
    );
    return '$_temp0';
  }

  @override
  String syncMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel fehlen',
      one: '1 Titel fehlt',
    );
    return '$_temp0';
  }

  @override
  String get syncUpToDate => 'Die Playlists sind bereits abgeglichen';

  @override
  String syncKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Playlists sind hier neuer und bleiben unverändert',
      one: '1 Playlist ist hier neuer und bleibt unverändert',
    );
    return '$_temp0';
  }

  @override
  String get syncReplaceNote =>
      'Aktualisierte Playlists ersetzen die auf diesem Gerät.';

  @override
  String get syncTagNew => 'Neu';

  @override
  String get syncTagUpdated => 'Aktualisiert';

  @override
  String get syncDetailRenamed => 'umbenannt';

  @override
  String get syncDetailReordered => 'neu sortiert';

  @override
  String syncDetailRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel entfernt',
      one: '1 Titel entfernt',
    );
    return '$_temp0';
  }

  @override
  String get syncAskMissing => 'Fehlende Titel anfordern';

  @override
  String syncApplied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Playlists abgeglichen',
      one: '1 Playlist abgeglichen',
    );
    return '$_temp0';
  }

  @override
  String get trustedSection => 'Vertrauenswürdige Geräte';

  @override
  String trustedFingerprint(String fingerprint) {
    return 'Fingerabdruck $fingerprint';
  }

  @override
  String trustedPairedOn(String date) {
    return 'Gekoppelt am $date';
  }

  @override
  String get trustedAutoAccept => 'Automatisch annehmen';

  @override
  String get trustedAutoAcceptHint =>
      'Titel von diesem Gerät ohne Nachfrage empfangen.';

  @override
  String get trustedRevoke => 'Widerrufen';

  @override
  String trustedRevokeTitle(String name) {
    return '„$name“ widerrufen?';
  }

  @override
  String get trustedRevokeBody =>
      'Um wieder ohne PIN zu senden, müsst ihr euch neu koppeln.';

  @override
  String get carMode => 'Automodus';

  @override
  String get carExit => 'Beenden';

  @override
  String get carKeepAwake => 'Bildschirm anlassen';

  @override
  String get carPlaylists => 'Playlists';

  @override
  String get carNothing => 'Keine Wiedergabe';

  @override
  String get updateCheck => 'Nach Updates suchen';

  @override
  String get updateCheckHint =>
      'Fragt GitHub nach der neuesten Version, nur auf Anfrage.';

  @override
  String get updateOnStart => 'Beim Start prüfen';

  @override
  String get updateOnStartHint =>
      'Höchstens einmal am Tag. Lädt nichts herunter und installiert nichts.';

  @override
  String get updateChecking => 'Prüfe…';

  @override
  String updateAvailable(String version) {
    return 'Version $version ist verfügbar';
  }

  @override
  String updateUpToDate(String version) {
    return 'Du hast die neueste Version ($version)';
  }

  @override
  String get updateRateLimited =>
      'GitHub bittet um Geduld: versuche es später erneut.';

  @override
  String get updateFailed =>
      'Die neueste Version lässt sich nicht lesen. Prüfe die Verbindung.';

  @override
  String get updateCopyLink => 'Adresse kopieren';

  @override
  String get updateLinkCopied => 'Adresse kopiert';

  @override
  String get backupSection => 'Backup';

  @override
  String get backupCreate => 'Backup erstellen';

  @override
  String get backupCreateHint =>
      'Playlists, Favoriten, Texte und Änderungen in einer Zip-Datei. Ohne Musik.';

  @override
  String get backupRestore => 'Aus Backup wiederherstellen';

  @override
  String get backupRestoreHint =>
      'Diese Bibliothek ersetzen oder Daten eines anderen Geräts zusammenführen.';

  @override
  String get backupCreating => 'Backup wird erstellt…';

  @override
  String get backupSaved => 'Backup gespeichert';

  @override
  String get backupFailed => 'Backup fehlgeschlagen';

  @override
  String get restoreTitle => 'Aus Backup wiederherstellen';

  @override
  String restoreInfo(String date, String version, int tracks, int playlists) {
    return 'Vom $date, App $version, $tracks Titel, $playlists Playlists';
  }

  @override
  String get restoreReplace => 'Alles ersetzen (gleiches Gerät)';

  @override
  String get restoreMerge => 'Mit dieser Bibliothek zusammenführen';

  @override
  String get restoreMergeHint =>
      'Fügt Favoriten, Playlists, Texte und Änderungen zu gefundenen Titeln hinzu. Löscht nichts.';

  @override
  String get restoreReplaceConfirmTitle => 'Gesamte Bibliothek ersetzen?';

  @override
  String get restoreReplaceConfirmBody =>
      'Beim nächsten Start werden die Daten dieser App durch die des Backups ersetzt. Die aktuellen bleiben als Sicherheitskopie neben der Datenbank.';

  @override
  String get restoreReplaceGo => 'Ersetzen';

  @override
  String get restoreNotBackup =>
      'Diese Datei ist kein lesbares Codecore-Backup.';

  @override
  String get restoreRestartNeeded =>
      'Bereit: App schließen und neu öffnen, um die Wiederherstellung abzuschließen.';

  @override
  String restoreMergeDone(
    int recognized,
    int missing,
    int playlists,
    int favorites,
  ) {
    return 'Zusammengeführt: $recognized Titel erkannt, $missing nicht gefunden, $playlists Playlists erstellt, $favorites Favoriten hinzugefügt.';
  }

  @override
  String get restoreNotFound => 'Nicht gefundene Titel';

  @override
  String get restoreCopyList => 'Liste kopieren';

  @override
  String get restoreFailed => 'Wiederherstellung fehlgeschlagen';

  @override
  String get exportAllPlaylists => 'Alle Playlists exportieren';

  @override
  String get shareErrIdentity =>
      'Die Identität dieses Geräts hat sich geändert: aus den vertrauenswürdigen entfernen und neu koppeln.';

  @override
  String get incomingTrustedTag => 'Vertrauenswürdiges Gerät';

  @override
  String incomingTrustedTitle(String name) {
    return '$name (vertrauenswürdig)';
  }

  @override
  String get pairAction => 'Koppeln';

  @override
  String get trustedBadge => 'Vertrauenswürdig';

  @override
  String pairPinTitle(String name) {
    return 'Koppeln mit $name';
  }

  @override
  String pairPinHint(String name) {
    return 'Gib die 6-stellige PIN ein, die auf $name angezeigt wird.';
  }

  @override
  String pairPinWrong(int count) {
    return 'Falsche PIN. Verbleibende Versuche: $count.';
  }

  @override
  String pairFingerprint(String fingerprint) {
    return 'Fingerabdruck: $fingerprint';
  }

  @override
  String get pairCompare =>
      'Prüfe, dass der Fingerabdruck auf dem anderen Bildschirm derselbe ist.';

  @override
  String pairRequestTitle(String name) {
    return '$name möchte sich koppeln';
  }

  @override
  String get pairRequestBody =>
      'Gib diese PIN auf dem anderen Gerät ein und tippe dann auf Bestätigen.';

  @override
  String get pairConfirm => 'Bestätigen';

  @override
  String get pairWaiting => 'Warte auf die Bestätigung auf dem anderen Gerät…';

  @override
  String pairDone(String name) {
    return 'Mit $name gekoppelt';
  }

  @override
  String get pairBlocked =>
      'Zu viele falsche Versuche: versuche es später erneut.';

  @override
  String get pairRejected => 'Kopplung abgelehnt.';

  @override
  String get pairExpired => 'Die Anfrage ist abgelaufen: versuche es erneut.';

  @override
  String get pairFailed => 'Kopplung fehlgeschlagen.';

  @override
  String get syncDevice => 'Playlists abgleichen';

  @override
  String get syncUnreachable =>
      'Das Gerät ist im lokalen Netzwerk nicht sichtbar.';

  @override
  String get syncFailed => 'Abgleich fehlgeschlagen.';

  @override
  String syncAsked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Anfrage gesendet: $count Titel unterwegs',
      one: 'Anfrage gesendet: 1 Titel unterwegs',
      zero: 'Keiner der Titel ist auf dem anderen Gerät',
    );
    return '$_temp0';
  }

  @override
  String get translateLyrics => 'Übersetzen';

  @override
  String get translateLyricsFrom => 'Sprache des Textes';

  @override
  String get translateLyricsHint =>
      'Wird auf dem Telefon übersetzt, es wird kein Text über das Netzwerk gesendet.';

  @override
  String get translateRemove => 'Nur das Original zeigen';

  @override
  String translateDownloadTitle(String language) {
    return 'Modell $language herunterladen?';
  }

  @override
  String translateDownloadBody(int mb) {
    return 'Etwa $mb MB pro Sprache, am besten über WLAN. Der Download erfolgt nur einmal, danach geht es auch offline.';
  }

  @override
  String get translateDownload => 'Herunterladen';

  @override
  String translateDownloading(String language) {
    return 'Modell $language wird geladen…';
  }

  @override
  String get translateDownloadFailed =>
      'Modell nicht geladen. Prüfe Verbindung und Speicherplatz.';

  @override
  String get translateFailed => 'Übersetzung fehlgeschlagen.';

  @override
  String get translateSameLanguage => 'Der Text ist bereits in dieser Sprache.';

  @override
  String get translationModels => 'Übersetzungsmodelle';

  @override
  String get translationModelsNone =>
      'Kein Modell geladen. Sie werden im Textbildschirm über „Übersetzen“ geladen.';

  @override
  String translationModelDelete(String language) {
    return 'Modell $language löschen';
  }

  @override
  String get scanCode => 'Code scannen';

  @override
  String get scanTitle => 'QR-Code anvisieren';

  @override
  String get scanNotCodecore => 'Dieser Code ist nicht von Codecore.';

  @override
  String get scanCameraDenied =>
      'Zum Lesen des Codes wird die Kameraberechtigung benötigt.';

  @override
  String get scanOpenSettings => 'Einstellungen öffnen';

  @override
  String get ownFingerprint => 'Fingerabdruck dieses Geräts';

  @override
  String get ownFingerprintHint =>
      'Vergleiche ihn beim Koppeln mit dem auf dem anderen Bildschirm.';

  @override
  String get writeTagsToFiles => 'Änderungen in die Dateien schreiben';

  @override
  String get writeTagsToFilesHint =>
      'Hier geänderte Titel, Interpret, Album, Jahr, Genre und Titelnummer werden auch in MP3-, FLAC-, M4A- und OGG-Dateien geschrieben. Das Original jeder Datei bleibt erhalten. Standardmäßig aus.';

  @override
  String get writeTagsAfterDownload =>
      'Tags in heruntergeladene Dateien schreiben';

  @override
  String get writeTagsAfterDownloadHint =>
      'Nur in Dateien, die Codecore heruntergeladen oder empfangen hat. Die ISRC bleibt in der App.';

  @override
  String get writeTagsWarnTitle => 'Änderungen in die Dateien schreiben?';

  @override
  String get writeTagsWarnBody =>
      'Beim Speichern einer Änderung werden die Tags auch in die Musikdatei geschrieben (MP3, FLAC, M4A, OGG). Es wird auf einer Kopie gearbeitet, das Ergebnis geprüft und die Datei nur ersetzt, wenn alles stimmt; vorher wird das Original unter „Tag-Backups“ gesichert (die letzten 200 oder 2 GB). Cover, Liedtexte und ReplayGain bleiben unberührt. Vor dem Aktivieren sollten Sie ein Bibliotheks-Backup erstellen (Einstellungen, Backup).';

  @override
  String get writeTagsEnable => 'Aktivieren';

  @override
  String get tagsAlsoInFile => 'Auch in die Datei schreiben';

  @override
  String tagsNoWriteUnsupported(String format) {
    return 'Dieses Format ist nicht beschreibbar ($format): nur die Bibliothek ändert sich';
  }

  @override
  String get tagsNoWriteReadOnly =>
      'Schreibgeschützte Datei: nur die Bibliothek ändert sich';

  @override
  String get tagsNoWriteMissing =>
      'Datei nicht gefunden: nur die Bibliothek ändert sich';

  @override
  String tagsFileWriteFailed(int count, String reason) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien wurden nicht geändert',
      one: '1 Datei wurde nicht geändert',
    );
    return 'In der Bibliothek gespeichert, aber $_temp0: $reason';
  }

  @override
  String get tagReasonUnsupported => 'Format nicht unterstützt';

  @override
  String get tagReasonNotFound => 'Datei nicht gefunden';

  @override
  String get tagReasonReadOnly => 'schreibgeschützte Datei';

  @override
  String get tagReasonVerifyFailed =>
      'die Prüfung nach dem Schreiben ist fehlgeschlagen, die Datei blieb unverändert';

  @override
  String get tagReasonWriteFailed =>
      'Schreiben fehlgeschlagen, die Datei blieb unverändert';

  @override
  String get tagReasonBackupFailed =>
      'Sicherung des Originals fehlgeschlagen, die Datei blieb unverändert';

  @override
  String get tagReasonIoError => 'Festplatten- oder Berechtigungsfehler';

  @override
  String get tagBackupsTitle => 'Tag-Backups';

  @override
  String tagBackupsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tag-Backups ($count)',
      one: 'Tag-Backups (1)',
      zero: 'Tag-Backups',
    );
    return '$_temp0';
  }

  @override
  String get tagBackupsHint =>
      'Das Original jeder umgeschriebenen Datei vor der Änderung. Die letzten 200 oder 2 GB bleiben erhalten.';

  @override
  String get tagBackupsEmpty =>
      'Keine Backups: Es wurde noch keine Datei umgeschrieben.';

  @override
  String get tagBackupRestore => 'Original wiederherstellen';

  @override
  String tagBackupRestoreBody(String name) {
    return 'Die Datei „$name“ wird auf den Stand vor der Änderung zurückgesetzt. Die Bibliothek behält die in der App vorgenommenen Änderungen.';
  }

  @override
  String get tagBackupRestored => 'Original wiederhergestellt';

  @override
  String tagBackupRestoreFailed(String reason) {
    return 'Wiederherstellung fehlgeschlagen: $reason';
  }

  @override
  String get tagBackupDelete => 'Backup löschen';

  @override
  String get tagBackupDeleteBody =>
      'Sie können die Datei dann nicht mehr auf den Stand vor der Änderung zurücksetzen.';

  @override
  String get tagBackupDeleted => 'Backup gelöscht';

  @override
  String get deleteFromDevice => 'Vom Gerät löschen';

  @override
  String deleteTrackTitle(String title) {
    return '„$title“ löschen?';
  }

  @override
  String get deleteTrackBody =>
      'Die Datei wird vom Gerät gelöscht und der Titel verschwindet aus Bibliothek, Playlists, Favoriten und Verlauf. Das lässt sich nicht rückgängig machen.';

  @override
  String deleteTracksTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel löschen?',
      one: '1 Titel löschen?',
    );
    return '$_temp0';
  }

  @override
  String get deleteTracksBody =>
      'Die Dateien werden vom Gerät gelöscht und die Titel verschwinden aus Bibliothek, Playlists, Favoriten und Verlauf. Das lässt sich nicht rückgängig machen.';

  @override
  String get deleteConfirm => 'Löschen';

  @override
  String get trackDeleted => 'Titel gelöscht';

  @override
  String trackDeleteFailed(String reason) {
    return 'Die Datei konnte nicht gelöscht werden: $reason';
  }

  @override
  String tracksDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel gelöscht',
      one: '1 Titel gelöscht',
    );
    return '$_temp0';
  }

  @override
  String tracksDeletedSome(int count, int failed) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel gelöscht',
      one: '1 Titel gelöscht',
    );
    return '$_temp0, $failed nicht gelöscht';
  }

  @override
  String get trackDeleteRefused =>
      'Android hat das Löschen der Datei nicht erlaubt';

  @override
  String get reviewTitle => 'Zu prüfen';

  @override
  String get reviewFilterAll => 'Alle';

  @override
  String get reviewFilterNothingFound => 'Nichts gefunden';

  @override
  String get reviewFilterNoLyrics => 'Ohne Songtext';

  @override
  String get reviewFilterNoCover => 'Ohne Cover';

  @override
  String get reviewFilterMissingData => 'Fehlende Daten';

  @override
  String get reviewEmpty =>
      'Nichts zu prüfen: bei den gesuchten Titeln fehlt nichts';

  @override
  String get reviewHint =>
      'Titel, denen etwas fehlt. Erneut suchen oder so lassen.';

  @override
  String get reviewRetry => 'Erneut versuchen';

  @override
  String get reviewDismiss => 'Ignorieren';

  @override
  String reviewRetryStarted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel',
      one: '1 Titel',
    );
    return 'Suche gestartet für $_temp0';
  }

  @override
  String reviewDismissed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel aus der Liste entfernt',
      one: '1 Titel aus der Liste entfernt',
    );
    return '$_temp0';
  }

  @override
  String reviewSecondOpinionProgress(int done, int total) {
    return 'Prüfung mit YouTube Music, $done von $total';
  }

  @override
  String get reviewSecondOpinionStop => 'Stopp';

  @override
  String reviewSecondOpinionDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel mit YouTube Music aktualisiert',
      one: '1 Titel mit YouTube Music aktualisiert',
    );
    return '$_temp0';
  }

  @override
  String get reviewSecondOpinionThrottled =>
      'YouTube Music hat um langsamere Anfragen gebeten: die übrigen Titel werden später geprüft';

  @override
  String activitySecondOpinion(int done, int total) {
    return 'Zweite Meinung: $done von $total';
  }

  @override
  String get secondOpinionLogTitle => 'Zweite Meinung';

  @override
  String get secondOpinionLogEmpty => 'Noch keine Titel geprüft';

  @override
  String get secondOpinionConfirmed => 'Bestätigt, nichts zu ergänzen';

  @override
  String secondOpinionConfirmedFields(String fields) {
    return 'Bestätigt, ergänzt: $fields';
  }

  @override
  String get secondOpinionNotConfirmed => 'Nicht bestätigt';

  @override
  String get secondOpinionNetwork =>
      'Netzwerk nicht verfügbar, später erneut versuchen';

  @override
  String get secondOpinionThrottled =>
      'YouTube Music hat um Verlangsamung gebeten';

  @override
  String get sourceYoutubeMusic => 'Quelle: YouTube Music';

  @override
  String get curiositySourceDiscogs => 'Vom Album, über Discogs';

  @override
  String get navMemory => 'Speicher';

  @override
  String get memoryMusicLabel => 'Musik';

  @override
  String get memoryOtherLabel => 'Sonstiges';

  @override
  String get memoryFreeLabel => 'Frei';

  @override
  String memoryDeviceLine(String free, String total) {
    return '$free frei von $total';
  }

  @override
  String get memoryPlaylists => 'Playlists';

  @override
  String get memoryPlaylistsNote =>
      'Ein Titel in mehreren Playlists zählt in jeder davon, die Summe kann daher die Gesamtgröße übersteigen.';

  @override
  String get memoryByFormat => 'Formate';

  @override
  String get memoryByFolder => 'Ordner';

  @override
  String get memoryNoFolder => 'Außerhalb der Ordner';

  @override
  String get memoryHeaviest => 'Die größten';

  @override
  String get memoryHeaviestTracks => 'Titel';

  @override
  String get memoryHeaviestAlbums => 'Alben';

  @override
  String get memoryNeverPlayed => 'Nie gespielt';

  @override
  String get memoryNeverPlayedHint =>
      'Titel, die nie abgespielt wurden. Wähle welche aus, um sie vom Gerät zu löschen.';

  @override
  String get memoryNeverPlayedNone => 'Du hast alle Musik gehört';

  @override
  String get memoryAppData => 'App-Daten';

  @override
  String get memoryCovers => 'Cover';

  @override
  String memoryCoversThumbs(String size) {
    return 'davon Vorschaubilder $size';
  }

  @override
  String get memoryDatabase => 'Bibliothek';

  @override
  String get memoryImageMemory => 'Bilder im Arbeitsspeicher';

  @override
  String get memoryJamCache => 'Jam-Cache';

  @override
  String get memorySearchCache => 'Such-Cache';

  @override
  String get memoryCatalogCache => 'Online-Katalog';

  @override
  String get memoryBlurCopies => 'Unscharfe Hintergründe';

  @override
  String get memoryTagBackups => 'Tag-Sicherungen';

  @override
  String get memoryLog => 'Protokoll';

  @override
  String get memoryPodcasts => 'Podcast-Folgen';

  @override
  String get memoryClearCache => 'Cache leeren';

  @override
  String memoryCleared(String size) {
    return '$size freigegeben';
  }

  @override
  String memoryClearedJamKept(String size) {
    return '$size freigegeben. Der Jam-Cache wird gerade benutzt und blieb unberührt';
  }

  @override
  String get memoryClearFailed => 'Cache konnte nicht geleert werden';

  @override
  String get memoryOfMusic => 'Musik';

  @override
  String get memoryShowAll => 'Alle anzeigen';

  @override
  String get memoryCache => 'Cache';

  @override
  String get memoryCacheHint => 'Bilder, Suchen, Jam';

  @override
  String get memoryDatabaseHint => 'Die Datenbank mit Titeln und Wiedergaben';

  @override
  String get memoryTagBackupsHint => 'Vor jeder Änderung an den Dateien';

  @override
  String get memoryTinyNote => 'Daten unter 1 MB werden nicht aufgelistet.';

  @override
  String memoryClearHint(String size) {
    return 'Gibt $size frei. Titel, Cover und Wiedergaben bleiben erhalten.';
  }

  @override
  String memoryDuplicateGroups(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Gruppen',
      one: '1 Gruppe',
    );
    return '$_temp0';
  }

  @override
  String get memoryTools => 'Werkzeuge';

  @override
  String get memoryUnavailable => 'Nicht verfügbar';

  @override
  String ytmArtistWithAudience(String audience) {
    return 'Künstler, $audience';
  }

  @override
  String ytmOffline(String date) {
    return 'Offline, Daten vom $date';
  }

  @override
  String get ytmArtistNotFound => 'Künstler nicht gefunden';

  @override
  String get ytmPageUnreadable =>
      'Die Seite lässt sich nicht lesen (YouTube hat etwas geändert)';

  @override
  String get ytmArtistUnreadable =>
      'Die Künstlerseite lässt sich nicht lesen (YouTube hat etwas geändert)';

  @override
  String ytmSearchSongsOf(String name) {
    return 'Songs von $name suchen';
  }

  @override
  String get ytmInYourLibrary => 'In deiner Bibliothek';

  @override
  String get ytmAbout => 'Info';

  @override
  String get ytmMore => 'Mehr';

  @override
  String get ytmLess => 'Weniger';

  @override
  String get ytmDownloadAlbum => 'Album herunterladen';

  @override
  String ytmDownloadAlbumTitle(String album) {
    return '„$album“ herunterladen?';
  }

  @override
  String ytmAlbumConfirmBody(int tracks, String duration, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      tracks,
      locale: localeName,
      other: '$tracks Titel',
      one: '1 Titel',
    );
    return '$_temp0, $duration, ca. $size';
  }

  @override
  String ytmAlbumConfirmOwned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel sind schon in der Bibliothek und werden verknüpft',
      one: '1 Titel ist schon in der Bibliothek und wird verknüpft',
    );
    return '$_temp0';
  }

  @override
  String ytmAlbumStarted(String name) {
    return 'Import „$name“ gestartet';
  }

  @override
  String get ytmShowImport => 'Anzeigen';

  @override
  String get ytmOnYoutubeMusic => 'Auf YouTube Music';

  @override
  String get ytmArtistOnYoutubeMusic => 'Künstler auf YouTube Music';

  @override
  String get ytmSearchingArtist => 'Suche auf YouTube Music …';

  @override
  String get ytmPickArtist => 'Welcher Künstler?';

  @override
  String get ytmArtistNone => 'Kein Künstler auf YouTube Music gefunden';

  @override
  String get suggestedBadge => 'Vorgeschlagen';

  @override
  String suggestedSimilarTo(String seed) {
    return 'Vorgeschlagen: ähnlich wie „$seed“';
  }

  @override
  String get suggestionDownloadStarted => 'Download gestartet';

  @override
  String suggestionAddWhenDownloaded(String name) {
    return 'Wird geladen und zu „$name“ hinzugefügt';
  }

  @override
  String get dislikesTitle => 'Gefällt mir nicht';

  @override
  String get dislikesHint =>
      'Was du bei den Vorschlägen nicht willst. Titel können nur zurückkehren, wenn sie sehr nah an deinem Hörverhalten liegen; Künstler nie wieder.';

  @override
  String dislikesTracksTab(int count) {
    return 'Titel $count';
  }

  @override
  String dislikesArtistsTab(int count) {
    return 'Künstler $count';
  }

  @override
  String get dislikesEmptyTracks => 'Keine Titel ausgeschlossen';

  @override
  String get dislikesEmptyArtists => 'Keine Künstler ausgeschlossen';

  @override
  String get dislikesEmptyHint =>
      'Wenn du bei einem Vorschlag auf „Gefällt mir nicht“ tippst, erscheint er hier und du kannst ihn entfernen.';

  @override
  String get dislikesRemove => 'Entfernen';

  @override
  String dislikesRemoveLabel(String name) {
    return '„$name“ aus „Gefällt mir nicht“ entfernen';
  }

  @override
  String dislikesRemoved(String name) {
    return '„$name“ aus „Gefällt mir nicht“ entfernt';
  }

  @override
  String get dislikesTileHint =>
      'Von Vorschlägen ausgeschlossene Titel und Künstler';

  @override
  String get dislikePlayerLabel => 'Gefällt mir nicht: Titel oder Künstler';

  @override
  String get suggestionDislike => 'Gefällt mir nicht';

  @override
  String get suggestionDisliked => 'Wird nicht mehr vorgeschlagen';

  @override
  String get removeFromQueueAction => 'Aus der Warteschlange entfernen';

  @override
  String get shuffleModeOff => 'Zufall: aus';

  @override
  String get shuffleModeOn => 'Zufall: an';

  @override
  String get shuffleModePlus => 'Zufall+: an (lange drücken für Einstellungen)';

  @override
  String get shufflePlusTitle => 'Shuffle+';

  @override
  String get shufflePlusNote =>
      'Wird über die Shuffle-Taste aktiviert (dritter Tipp). Nicht verfügbar für Streaming-Alben, Jam und Radio';

  @override
  String shufflePlusEvery(int n) {
    return 'Ein Vorschlag alle $n Titel';
  }

  @override
  String get shufflePlusUnmeteredOnly => 'Nur über WLAN';

  @override
  String get shufflePlusUnmeteredOnlyHint =>
      'Keine Vorschläge über mobile Daten oder getaktete Netze.';

  @override
  String get shufflePlusData =>
      'Geschätzter Verbrauch: etwa 15 MB pro Stunde bei einem Vorschlag alle 4 Titel.';

  @override
  String get shufflePlusActive =>
      'Aktiv: Vorschläge kommen während des Hörens.';

  @override
  String get shufflePlusOff => 'Aus: Zufall bleibt normal.';

  @override
  String get shufflePlusBlockJam => 'Während einer Jam nicht aktiv';

  @override
  String get shufflePlusBlockShort =>
      'Braucht eine Liste mit mindestens 5 Titeln';

  @override
  String get shufflePlusBlockNoTool => 'yt-dlp nicht verfügbar';

  @override
  String get shufflePlusBlockMetered => 'Pausiert: getaktetes Netz';

  @override
  String get shufflePlusBlockStopped =>
      'Aus bis zum Neustart: zu viele Wiedergabefehler';

  @override
  String get shufflePlusBlockOnline =>
      'Für ein Streaming-Album nicht verfügbar';

  @override
  String get shufflePlusBlockRadio => 'Mit dem Radio nicht verfügbar';

  @override
  String get shufflePlusNoticeRateLimited =>
      'YouTube bittet um Verlangsamung: Vorschläge pausieren 15 Minuten';

  @override
  String get shufflePlusNoticeTooManyErrors =>
      'Zu viele Wiedergabefehler: Vorschläge sind bis zum Neustart aus';

  @override
  String get suggestionsRecentTitle => 'Zuletzt vorgeschlagen';

  @override
  String get suggestionsRecentEmpty =>
      'Noch nichts vorgeschlagen. Titel erscheinen hier, sobald du Shuffle+ nutzt.';

  @override
  String get suggestionsClear => 'Verlauf leeren';

  @override
  String get suggestionsClearBody =>
      'Vergisst die Vorschläge und die „Gefällt mir nicht“-Markierungen: Titel können wiederkommen.';

  @override
  String suggestionsRowNote(String seed, String outcome) {
    return 'ähnlich wie „$seed“, $outcome';
  }

  @override
  String get suggestionOutcomeQueued => 'In der Warteschlange';

  @override
  String get suggestionOutcomeSkipped => 'Übersprungen';

  @override
  String get suggestionOutcomeHeard => 'Gehört';

  @override
  String get suggestionOutcomeDownloaded => 'Heruntergeladen';

  @override
  String get suggestionOutcomeDisliked => 'Gefällt mir nicht';

  @override
  String get memorySuggestions => 'Shuffle+-Vorschläge';

  @override
  String searchOnline(String query) {
    return '„$query“ online suchen';
  }

  @override
  String get onlineBestResults => 'Beste Ergebnisse';

  @override
  String onlineOthersChip(int count) {
    return 'Weitere Ergebnisse ($count)';
  }

  @override
  String get onlineNoneSure => 'Kein sicheres Ergebnis';

  @override
  String get onlineInLibrary => 'In deiner Bibliothek';

  @override
  String onlineShowAllCount(int count) {
    return 'Alle anzeigen ($count)';
  }

  @override
  String onlineOwnedHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Ergebnisse, die schon in der Bibliothek sind, ausgeblendet',
      one: '1 Ergebnis, das schon in der Bibliothek ist, ausgeblendet',
    );
    return '$_temp0';
  }

  @override
  String onlineArtistSongs(String artist) {
    return 'Titel von $artist';
  }

  @override
  String get onlineFilterAll => 'Alle';

  @override
  String onlineFromSource(String source) {
    return 'Von $source';
  }

  @override
  String get onlineAlsoVideo => 'auch als Video';

  @override
  String get onlineListenVideo => 'Video anhören';

  @override
  String onlineNoticeRateLimited(String source, String other) {
    return '$source bittet um eine Pause: Ergebnisse nur von $other';
  }

  @override
  String onlineNoticeFailed(String source, String other) {
    return '$source hat nicht geantwortet: Ergebnisse nur von $other';
  }

  @override
  String get radioTitle => 'Radio';

  @override
  String radioLibrarySubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gespeicherte Sender',
      one: '1 gespeicherter Sender',
      zero: 'Live-Sender',
    );
    return '$_temp0';
  }

  @override
  String get radioSearchHint => 'Sender suchen';

  @override
  String radioOnlyCountry(String country) {
    return 'Nur $country';
  }

  @override
  String get radioMine => 'Meine Sender';

  @override
  String get radioNearYou => 'In deiner Nähe';

  @override
  String get radioGenres => 'Genres';

  @override
  String get radioTopListened => 'Am meisten gehört';

  @override
  String get radioChooseRegion => 'Region wählen';

  @override
  String get radioRegionHint =>
      'Sender in der Nähe richten sich nach Land und Region, die du wählst: die App nutzt deinen Standort nicht.';

  @override
  String radioCountryChip(String country) {
    return 'Land: $country';
  }

  @override
  String get radioChooseCountry => 'Land wählen';

  @override
  String radioOfflineList(String date) {
    return 'Offline, Liste vom $date';
  }

  @override
  String get radioLoadFailed => 'Die Sender konnten nicht geladen werden';

  @override
  String get radioNoResults => 'Keine Sender gefunden';

  @override
  String get radioResults => 'Ergebnisse';

  @override
  String get radioSave => 'In Meine Sender speichern';

  @override
  String get radioUnsave => 'Aus Meine Sender entfernen';

  @override
  String get radioSavedDone => 'Sender gespeichert';

  @override
  String get radioRemovedDone => 'Sender entfernt';

  @override
  String get radioNotResponding => 'antwortet nicht';

  @override
  String get radioLive => 'Live';

  @override
  String get reasonRadioUnavailable => 'der Sender antwortet nicht';

  @override
  String radioDataPerHour(String mb) {
    return '≈ $mb MB pro Stunde';
  }

  @override
  String get radioSite => 'Website des Senders';

  @override
  String get radioSiteCopied => 'Adresse der Website kopiert';

  @override
  String get radioSearchSong => 'Diesen Titel suchen';

  @override
  String get radioRenameTitle => 'Name des Senders';

  @override
  String get radioMobileNotice =>
      'Radio verbraucht etwa 1 MB Daten pro Minute.';

  @override
  String get radioAddAddress => 'Adresse hinzufügen';

  @override
  String get radioAddName => 'Name';

  @override
  String get radioAddUrl => 'Stream-Adresse';

  @override
  String get radioAddTest => '10 Sekunden testen';

  @override
  String get radioAddTesting =>
      'Test läuft … wenn du es hörst, kannst du speichern.';

  @override
  String get radioLinkEmpty => 'Gib die Stream-Adresse ein';

  @override
  String get radioLinkNotAnAddress =>
      'Das sieht nicht nach einer Adresse aus – bitte vollständig eingeben, z. B. https://…';

  @override
  String get radioLinkBadScheme =>
      'Die Adresse muss mit http:// oder https:// beginnen';

  @override
  String get radioLinkNoEntries =>
      'Die Datei enthält keine abspielbare Adresse';

  @override
  String get radioLinkTooBig => 'Die Datei ist zu groß für eine Senderliste';

  @override
  String get radioLinkFetchFailed => 'Die Datei konnte nicht geladen werden';

  @override
  String get radioReorder => 'Zum Sortieren ziehen';

  @override
  String get radioReorderFailed =>
      'Die neue Reihenfolge konnte nicht gespeichert werden';

  @override
  String get memoryRadio => 'Radio (Senderlisten)';

  @override
  String get radioGenrePop => 'Pop';

  @override
  String get radioGenreRock => 'Rock';

  @override
  String get radioGenreClassicRock => 'Classic Rock';

  @override
  String get radioGenreJazz => 'Jazz';

  @override
  String get radioGenreBlues => 'Blues';

  @override
  String get radioGenreClassical => 'Klassik';

  @override
  String get radioGenreDance => 'Dance';

  @override
  String get radioGenreElectronic => 'Elektronik';

  @override
  String get radioGenreHouse => 'House';

  @override
  String get radioGenreHipHop => 'Hip-Hop';

  @override
  String get radioGenreLoFi => 'Lo-Fi';

  @override
  String get radioGenreChillout => 'Chillout';

  @override
  String get radioGenreSixties => '60er';

  @override
  String get radioGenreSeventies => '70er';

  @override
  String get radioGenreEighties => '80er';

  @override
  String get radioGenreNineties => '90er';

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
  String get radioGenreNews => 'Nachrichten';

  @override
  String get radioGenreTalk => 'Talk';

  @override
  String get radioGenreSports => 'Sport';

  @override
  String get newReleasesTitle => 'Neuerscheinungen';

  @override
  String get releasesTopArtists => 'Meistgehörte Künstler automatisch folgen';

  @override
  String get releasesTopArtistsHint =>
      'Die 15 meistgehörten Künstler der letzten 90 Tage, gesucht auf YouTube Music.';

  @override
  String get releasesNotify => 'Benachrichtigungen für Neuerscheinungen';

  @override
  String get releasesNotifyHint => 'Höchstens eine pro Tag, nur auf Android.';

  @override
  String get releasesUnmetered => 'Nur im WLAN prüfen';

  @override
  String get releasesUnmeteredHint =>
      'Eine tägliche Prüfung braucht etwa 0,5 MB.';

  @override
  String get releasesTopCardTitle =>
      'Möchtest du wissen, wann deine meistgehörten Künstler neue Musik veröffentlichen?';

  @override
  String get releasesTopCardYes => 'Aktivieren';

  @override
  String get releasesTopCardNo => 'Nein, danke';

  @override
  String get releasesCheckNow => 'Jetzt prüfen';

  @override
  String releasesLastCheck(String when) {
    return 'Letzte Prüfung: $when';
  }

  @override
  String get releasesNeverChecked => 'Noch nie geprüft';

  @override
  String releasesPaused(String time) {
    return 'YouTube bittet um eine Pause: neuer Versuch um $time';
  }

  @override
  String get releasesChecking => 'Prüfung läuft…';

  @override
  String get releasesCheckNone => 'Keine Neuerscheinungen';

  @override
  String releasesCheckFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Neuerscheinungen',
      one: '1 Neuerscheinung',
    );
    return '$_temp0';
  }

  @override
  String get releasesCantCheck =>
      'Prüfung gerade nicht möglich: kein Netz oder keine gefolgten Künstler.';

  @override
  String get releasesChanged =>
      'YouTube Music hat sein Format geändert: neuer Versuch bei der nächsten Runde.';

  @override
  String get releasesEmpty =>
      'Keine Neuerscheinungen in den letzten 90 Tagen. Öffne die Seite eines Künstlers und tippe auf „Folgen“.';

  @override
  String get releasesAllArtists => 'Alle';

  @override
  String releasesFollowedTitle(int count) {
    return 'Gefolgte Künstler ($count)';
  }

  @override
  String get releasesFollowedLibrary => 'Gefolgte Künstler';

  @override
  String releasesFollowedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Künstler',
      one: '1 Künstler',
    );
    return '$_temp0';
  }

  @override
  String get followedEmpty =>
      'Du folgst noch keinem Künstler. Öffne die Seite eines Künstlers und tippe auf „Folgen“.';

  @override
  String get followAction => 'Folgen';

  @override
  String get followingAction => 'Gefolgt';

  @override
  String followStopTitle(String name) {
    return '$name nicht mehr folgen?';
  }

  @override
  String get followStopBody => 'Neuerscheinungen werden nicht mehr gemeldet.';

  @override
  String get followOnYtm => 'Auf YouTube Music folgen';

  @override
  String get followStop => 'Nicht mehr folgen';

  @override
  String followedNow(String name) {
    return 'Du folgst jetzt $name';
  }

  @override
  String get followMute => 'Benachrichtigungen stummschalten';

  @override
  String get followUnmute => 'Benachrichtigungen aktivieren';

  @override
  String get followedTopListened => 'Meistgehört';

  @override
  String get followedToConfirm => 'Zu bestätigen';

  @override
  String get followedNotFound => 'Nicht gefunden';

  @override
  String get followedRetry => 'Erneut versuchen';

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
      other: 'und $count weitere Versionen',
      one: 'und 1 weitere Version',
    );
    return '$_temp0';
  }

  @override
  String get releaseNewBadge => 'Neu';

  @override
  String get activityReleases => 'Prüfe Neuerscheinungen';

  @override
  String releaseNotifyOne(String title, String artist) {
    return 'Neuerscheinung: $title von $artist';
  }

  @override
  String releaseNotifyMany1(int count, String a) {
    return '$count Neuerscheinungen: $a';
  }

  @override
  String releaseNotifyMany2(int count, String a, String b) {
    return '$count Neuerscheinungen: $a und $b';
  }

  @override
  String releaseNotifyManyMore(int count, String a, String b, int others) {
    return '$count Neuerscheinungen: $a, $b und $others weitere';
  }

  @override
  String get releaseNotifyShow => 'Anzeigen';

  @override
  String get reportIssue => 'Problem melden';

  @override
  String get reportIssueHint => 'Öffnet GitHub mit vorausgefülltem Text';

  @override
  String get reportKindBug => 'Fehler';

  @override
  String get reportKindIdea => 'Idee';

  @override
  String get reportTitleLabel => 'Titel';

  @override
  String get reportDescLabel => 'Beschreibung';

  @override
  String reportDescHelper(int n) {
    return 'Was ist passiert und wie lässt es sich nachstellen (mindestens $n Zeichen)';
  }

  @override
  String get reportAttach => 'Technische Informationen anhängen';

  @override
  String get reportAttachPreview => 'Genau das wird gesendet:';

  @override
  String get reportOpen => 'Auf GitHub öffnen';

  @override
  String get reportCopy => 'Text kopieren';

  @override
  String get reportCopied => 'Text kopiert';

  @override
  String get reportGithubNote =>
      'Ein GitHub-Konto ist nötig; ohne Konto den Text kopieren und beliebig weitergeben.';

  @override
  String get reportOpenFailed =>
      'Browser konnte nicht geöffnet werden: Der Text wurde kopiert';

  @override
  String get reportLogShortened =>
      'Das Protokoll wird gekürzt, damit es in die Adresse passt';

  @override
  String get reportNoLog =>
      'Keine aktuellen Warnungen oder Fehler im Protokoll';

  @override
  String get reportUnknown => 'Unbekannt';

  @override
  String get iconAskTitle => 'Auch das App-Symbol ändern?';

  @override
  String get iconProblems =>
      'Das Symbol wechselt, wenn du die App verlässt. Mögliche Probleme:\n• der Launcher braucht ein paar Sekunden zum Aktualisieren oder zeigt kurz zwei Symbole oder keines;\n• bei manchen Launchern wird das Symbol auf dem Startbildschirm entfernt oder verschoben und muss von Hand wieder platziert werden (Widgets bleiben);\n• Verknüpfungen auf dem Startbildschirm, die mit dem alten Symbol erstellt wurden, funktionieren eventuell nicht mehr;\n• die App kann kurz aus den zuletzt verwendeten Apps verschwinden;\n• selten beendet Android die App und die Musik stoppt.\nAm Computer ändert sich das Symbol nicht.';

  @override
  String get iconChange => 'Symbol ändern';

  @override
  String get iconKeep => 'So lassen';

  @override
  String get iconDontAsk => 'Nicht mehr fragen';

  @override
  String get iconFollowTitle => 'Symbol passend zum Thema';

  @override
  String get iconFollowSubtitle =>
      'Das Symbol folgt Thema und Farbe, wenn du die App verlässt';

  @override
  String get exportifySyncTitle => 'Mit Spotify synchronisieren';

  @override
  String exportifySyncChanges(int added, int removed) {
    return '+$added neu, −$removed entfernt';
  }

  @override
  String get exportifySyncNew => 'Neue Playlist';

  @override
  String get exportifySyncChoose => 'Auswählen';

  @override
  String get exportifySyncNoChanges => 'Keine Änderungen';

  @override
  String exportifySyncSkipped(int n) {
    return '$n Dateien übersprungen (keine lesbaren Playlists)';
  }

  @override
  String exportifySyncGo(int n) {
    return '$n synchronisieren';
  }

  @override
  String exportifySyncDone(int n) {
    return '$n Playlists werden synchronisiert: im Aktivitätszentrum verfolgen';
  }

  @override
  String get exportifySyncEmpty => 'Keine Playlists in der ZIP-Datei';

  @override
  String get exportifySyncPickTitle => 'Playlist auswählen';

  @override
  String get csvImportOpenExportify => 'exportify.net öffnen';

  @override
  String get csvImportOpenFailed => 'Browser kann nicht geöffnet werden';

  @override
  String get csvImportZipHint =>
      'Mit «Export All» erhältst du eine ZIP-Datei mit allen Playlists: wähle sie hier und synchronisiere alle zusammen.';

  @override
  String get exportifySyncFailed => 'Synchronisierung fehlgeschlagen';

  @override
  String get exportifySyncEntryFailed =>
      'Diese Playlist kann nicht gelesen werden';

  @override
  String get exportifySyncLoadFailed =>
      'Die Playlists der ZIP-Datei können nicht gelesen werden';

  @override
  String get exportifyRemindTitle => 'Erinnere mich an den Spotify-Abgleich';

  @override
  String get exportifyRemindOff => 'Aus';

  @override
  String exportifyRemindDays(int days) {
    return '$days Tage';
  }

  @override
  String get exportifyCardTitle =>
      'Zeit, deine Playlists mit Spotify abzugleichen';

  @override
  String get exportifyCardOpen => 'Exportify öffnen';

  @override
  String get exportifyCardLater => 'Später';

  @override
  String get exportifyFoundTitle => 'Exportify-Export gefunden';

  @override
  String get exportifyFoundSync => 'Abgleichen';

  @override
  String get onboardingSpotifyTitle => 'Playlists von Spotify';

  @override
  String get onboardingSpotifyBody =>
      'Auf exportify.net lädst du deine Spotify-Playlists als Datei herunter. Codecore übernimmt sie und aktualisiert sie hier.\nEs ist kein Konto nötig: Die Datei lädst du selbst herunter.';

  @override
  String get deezerMeta => 'Metadaten von Deezer';

  @override
  String get deezerMetaHint => 'Nur Daten (Cover, Titelnummern), nie Musik';

  @override
  String get deezerMetaNote =>
      'Nur privat und nicht kommerziell. Die Bedingungen von Deezer verbieten die Förderung nicht autorisierter Downloads, und Codecore lädt von YouTube: das Risiko trägst du.';

  @override
  String get acoustId => 'Per Klang erkennen (AcoustID)';

  @override
  String get acoustIdHint =>
      'Nur der Fingerabdruck des Titels wird gesendet, nie das Audio';

  @override
  String get settingsSpinCover => 'Drehendes Cover';

  @override
  String get settingsSpinCoverHint => 'Im Player, während Musik läuft';

  @override
  String get themeLowContrastWarning =>
      'Einige Textfarben sind auf dem Hintergrund schlecht lesbar (unter 4,5:1). Das Theme bleibt unverändert.';

  @override
  String get streamCacheTitle => 'Speicher für Streaming';

  @override
  String streamCacheUsage(String used, String limit) {
    return '$used von $limit';
  }

  @override
  String get streamCacheClear => 'Leeren';

  @override
  String get streamCacheCleared => 'Streaming-Cache geleert';

  @override
  String get streamCacheClearFailed =>
      'Streaming-Cache konnte nicht geleert werden';

  @override
  String get playerLoading => 'Wird geladen…';

  @override
  String get ytmAlbumQueue => 'Album zur Warteschlange hinzufügen';

  @override
  String get addedToLibrary => 'Zur Bibliothek hinzugefügt';

  @override
  String get promoteNoSpace => 'Nicht genug Speicherplatz für den Download';

  @override
  String get promoteFailed => 'Titel konnte nicht verschoben werden';

  @override
  String get creditsDetails => 'Credits und Details';

  @override
  String get creditsDetailsHint => 'Autoren, Produzenten und Titeldetails';

  @override
  String get creditsDetailsNote => 'Nutzt auch eine inoffizielle Deezer-API';

  @override
  String get creditRoleVocals => 'Gesang';

  @override
  String get creditRoleBackingVocals => 'Backgroundgesang';

  @override
  String get creditRoleGuitar => 'Gitarre';

  @override
  String get creditRoleBassGuitar => 'Bass';

  @override
  String get creditRoleDrums => 'Schlagzeug';

  @override
  String get creditRoleKeyboard => 'Keyboard';

  @override
  String get creditRolePiano => 'Klavier';

  @override
  String get creditRoleSynthesizer => 'Synthesizer';

  @override
  String get creditRoleComposer => 'Komponist';

  @override
  String get creditRoleAuthor => 'Autor';

  @override
  String get creditRoleLyricist => 'Texter';

  @override
  String get creditRoleArranger => 'Arrangeur';

  @override
  String get creditRoleProducer => 'Produzent';

  @override
  String get creditRoleAdditionalProducer => 'Zusätzlicher Produzent';

  @override
  String get creditRoleMix => 'Mischung';

  @override
  String get creditRoleMastering => 'Mastering';

  @override
  String get creditRoleRecording => 'Aufnahme';

  @override
  String get creditRoleEngineer => 'Toningenieur';

  @override
  String get creditRoleProgramming => 'Programmierung';

  @override
  String get creditRoleDrumProgrammer => 'Drum-Programmierung';

  @override
  String get creditRoleMusicPublisher => 'Musikverlag';

  @override
  String get creditsGroupPerformers => 'Interpreten und Instrumente';

  @override
  String get creditsGroupWriters => 'Autoren';

  @override
  String get creditsGroupProduction => 'Produktion und Technik';

  @override
  String get creditsGroupOther => 'Sonstiges';

  @override
  String get creditsTitle => 'Credits und Details';

  @override
  String get creditsShowAll => 'Alle anzeigen';

  @override
  String get creditsRefresh => 'Aktualisieren';

  @override
  String get creditsAppearsAs => 'Tritt auf als';

  @override
  String get creditsInCredits => 'In den Credits';

  @override
  String get creditsRefreshFailed =>
      'Credits konnten nicht aktualisiert werden';

  @override
  String get creditsBpm => 'BPM';

  @override
  String get creditsLabel => 'Label';

  @override
  String get creditsDigitalRelease => 'Digitale Veröffentlichung';

  @override
  String get creditsPhysicalRelease => 'Physische Veröffentlichung';

  @override
  String get creditsKindSingle => 'Single';

  @override
  String get creditsKindEp => 'EP';

  @override
  String get creditsRank => 'Chartplatzierung';

  @override
  String get creditsAlbumFans => 'Fans des Albums';

  @override
  String get creditsExplicit => 'Explizit';

  @override
  String creditsOpenArtist(String name) {
    return '$name öffnen';
  }

  @override
  String get autoCuriosities => 'Automatisches Wissenswertes';

  @override
  String get autoCuriositiesHint =>
      'Sucht Wissenswertes auf Wikipedia für neue Titel';

  @override
  String memoryEnrichment(String size) {
    return 'Anreicherung: $size';
  }

  @override
  String memoryEnrichmentDetail(
    String lyrics,
    String curiosities,
    String credits,
  ) {
    return 'Songtexte $lyrics, Wissenswertes $curiosities, Credits $credits';
  }

  @override
  String get activityPodcastRefresh => 'Podcasts werden aktualisiert';

  @override
  String get activityRadio => 'Gespeicherte Sender werden geprüft';

  @override
  String activityEnrichBackground(int done, int total) {
    return 'Anreicherung wird vervollständigt: $done von $total';
  }

  @override
  String get enrichRoundTitle => 'Anreicherungsdurchlauf';

  @override
  String get enrichRoundUpdated => 'Aktualisiert';

  @override
  String get enrichRoundNone => 'Ohne Ergebnis';

  @override
  String get enrichRoundGone => 'Keine Titel zum Anzeigen';

  @override
  String get enrichPartMeta => 'Titeldaten';

  @override
  String get enrichPartLyrics => 'Songtext';

  @override
  String get enrichPartSynced => 'Synchronisierter Songtext';

  @override
  String get enrichPartCurio => 'Wissenswertes';

  @override
  String get enrichPartCredits => 'Credits';

  @override
  String get coverChange => 'Cover ändern';

  @override
  String get coverRestoreOriginal => 'Originalcover wiederherstellen';

  @override
  String get coverSourceDevice => 'Vom Gerät';

  @override
  String get coverSourceLibrary => 'Aus der Mediathek';

  @override
  String get coverSourceOnline => 'Online';

  @override
  String coverSizePx(int w, int h) {
    return '$w × $h';
  }

  @override
  String get speakerPermTitle => 'Bluetooth-Berechtigung';

  @override
  String get speakerPermBody =>
      'Um deinen Lautsprecher zu erkennen, muss Codecore sehen, welche Bluetooth-Geräte verbunden sind. Sonst wird nichts gelesen.';

  @override
  String get speakerPermAllow => 'Erlauben';

  @override
  String get speakerNotNow => 'Nicht jetzt';

  @override
  String speakerAskTitle(String name) {
    return 'Ist $name ein Lautsprecher?';
  }

  @override
  String get speakerAskBody =>
      'Wenn ja, öffnet Codecore beim Verbinden von selbst eine Jam, der andere beitreten können.';

  @override
  String get speakerYes => 'Ja';

  @override
  String get speakerNo => 'Nein';

  @override
  String get speakerJamSection => 'Jam auf dem Lautsprecher';

  @override
  String get speakerJamHint =>
      'Verbindet sich ein Bluetooth-Lautsprecher, öffnet Codecore von selbst eine Jam, der andere beitreten können.';

  @override
  String get speakerNoDevices => 'Noch kein Gerät markiert';

  @override
  String get speakerIsSpeaker => 'Lautsprecher';

  @override
  String get speakerNotSpeaker => 'Kein Lautsprecher';

  @override
  String get speakerPermDenied => 'Bluetooth-Berechtigung verweigert';

  @override
  String get speakerPermRetry => 'Tippen, um erneut zu fragen';

  @override
  String speakerChange(String name) {
    return '$name ändern';
  }

  @override
  String jamInviteBanner(String name) {
    return 'Der Jam von $name beitreten';
  }

  @override
  String get jamInviteDismiss => 'Ausblenden';

  @override
  String get speakerAwayNotice => 'Lautsprecher verbinden';

  @override
  String get jamFull => 'Die Jam ist voll';

  @override
  String get jamAddFailed => 'Nicht zur Jam hinzugefügt';

  @override
  String get jamNotFoundOnline =>
      'Online nicht gefunden, kann nicht hinzugefügt werden';

  @override
  String get jamLeft => 'Du hast die Jam verlassen';

  @override
  String get speakerContinueOnPhone => 'Auf dem Handy weiter';

  @override
  String get speakerContinueOnPhoneLabel =>
      'Auf dem Handy weiter: Die Jam spielt über den Lautsprecher dieses Handys, ohne Box';

  @override
  String get speakerOfferTitle => 'Den Jam auf deinem Lautsprecher abspielen?';

  @override
  String get speakerOfferBody =>
      'Dein Lautsprecher ist verbunden und der Jam pausiert. Wenn du möchtest, startet die Musik von hier.';

  @override
  String get jamRemoteTitle => 'Jam aus der Ferne';

  @override
  String get jamRemoteHint =>
      'Die Broker (Server) für die Jam aus der Ferne, nach Vorrang geordnet.';

  @override
  String get jamBrokerAdd => 'Broker hinzufügen';

  @override
  String get jamBrokerHost => 'Adresse';

  @override
  String get jamBrokerPort => 'Port';

  @override
  String get jamBrokerTls => 'Verschlüsselte Verbindung (TLS)';

  @override
  String get jamBrokerNoTls =>
      'Ohne TLS kann jeder im Netzwerk mitlesen, was über den Broker läuft. Nur nutzen, wenn du weißt, was du tust.';

  @override
  String get jamBrokerInvalid => 'Ungültige Adresse oder ungültiger Port';

  @override
  String get jamBrokerTest => 'Verbindung testen';

  @override
  String jamBrokerTestOk(String broker) {
    return '$broker: Verbindung erfolgreich';
  }

  @override
  String jamBrokerTestFail(String broker) {
    return '$broker: keine Verbindung möglich (Netzwerk, Zertifikat oder Server nicht erreichbar)';
  }

  @override
  String get jamBrokerRestore => 'Zurücksetzen';

  @override
  String get jamBrokerMoveUp => 'Nach oben';

  @override
  String get jamBrokerRemove => 'Entfernen';

  @override
  String get jamSuspend => 'Pausieren';

  @override
  String get jamBlock => 'Blockieren';

  @override
  String get jamSuspendTitle => 'Wie lange pausieren?';

  @override
  String get jamUntilJamEnds => 'Bis die Jam endet';

  @override
  String get jamBlockedTitle => 'Blockierte Geräte';

  @override
  String get jamSuspendedTitle => 'Pausiert';

  @override
  String get jamUnblock => 'Entsperren';

  @override
  String jamSuspendedUntil(String time) {
    return 'Bis $time';
  }

  @override
  String get jamTooSoon => 'Warte einen Moment, bevor du es erneut versuchst';

  @override
  String enrichInterrupted(int updated, int notFound) {
    return 'Anreicherung durch einen Fehler unterbrochen: $updated aktualisiert, $notFound nicht gefunden';
  }

  @override
  String enrichLibraryDue(int count, int minutes) {
    return '$count Titel zu ergänzen, etwa $minutes Minuten';
  }

  @override
  String get enrichLibraryComplete => 'Bibliothek vollständig';

  @override
  String get enrichLibraryStop => 'Abbrechen';

  @override
  String get activityEnrichWaiting => 'Vervollständigung: wartet';

  @override
  String logRecogSources(String list) {
    return 'Erkannt: $list';
  }

  @override
  String get recogSrcTags => 'Tags';

  @override
  String get recogSrcVideo => 'Video';

  @override
  String get recogSrcText => 'Text';

  @override
  String recogIdent(String title, String artist) {
    return '$title – $artist';
  }

  @override
  String recogProposal(String identity) {
    return 'Vorschlag: $identity';
  }

  @override
  String get recogAccept => 'Annehmen';

  @override
  String get recogDiscard => 'Verwerfen';

  @override
  String recogAcceptSem(String identity) {
    return 'Vorschlag $identity annehmen';
  }

  @override
  String recogDiscardSem(String identity) {
    return 'Vorschlag $identity verwerfen';
  }

  @override
  String get recogCover => 'Cover';

  @override
  String recogCoverOf(String identity) {
    return 'Cover von $identity';
  }

  @override
  String recogToConfirm(int count) {
    return 'Zu bestätigen ($count)';
  }

  @override
  String get recogAcceptAll => 'Alle annehmen';

  @override
  String get recogNoProposals => 'Alles bestätigt';

  @override
  String recogFromTo(String from, String to) {
    return 'Von $from zu $to';
  }

  @override
  String get logRevert => 'Wiederherstellen';

  @override
  String get recogActionFailed => 'Aktion fehlgeschlagen';

  @override
  String get logRevertFailed =>
      'Diese Korrektur konnte nicht wiederhergestellt werden';

  @override
  String get jamInviteNearby => 'Nahestehende einladen';

  @override
  String get jamInviteHint =>
      'Wer den QR-Code scannt oder den Code eingibt, tritt der Jam bei.';

  @override
  String get jamBridgeConnecting => 'Verbinde…';

  @override
  String get jamBridgeRetrying => 'Verbindung unterbrochen, neuer Versuch…';

  @override
  String get jamBridgeUnreachable => 'Broker nicht erreichbar';

  @override
  String jamCodeExpiresIn(int seconds) {
    return 'Läuft in $seconds s ab';
  }

  @override
  String get jamEnterCode => 'Mit Code beitreten';

  @override
  String get jamCodeLabel => 'Code';

  @override
  String get jamScanQr => 'QR-Code scannen';

  @override
  String get jamJoinAction => 'Beitreten';

  @override
  String get jamCodeInvalid => 'Ungültiger Code';

  @override
  String get jamCodeExpired => 'Code abgelaufen, bitte einen neuen anfragen';

  @override
  String get jamHostNoAnswer => 'Der Host hat nicht geantwortet';

  @override
  String get jamCustomBroker =>
      'Diese Jam nutzt einen eigenen Broker: QR-Code scannen';

  @override
  String get jamLinkReconnecting => 'Verbindung verloren, neuer Versuch…';

  @override
  String get jamHostSilent => 'Host nicht erreichbar, neuer Versuch…';

  @override
  String get jamMemberUnreachable => 'nicht erreichbar';

  @override
  String get jamRemoteActive => 'Fern-Jam aktiv';

  @override
  String get jamRemoteEnd => 'Beenden';

  @override
  String get jamDeclinedHost => 'Der Host hat die Anfrage abgelehnt';

  @override
  String get jamBusyHost => 'Der Host hat bereits eine Jam laufen';

  @override
  String get jamWaitingHost => 'Warten, bis der Host annimmt…';

  @override
  String get jamFriendsTitle => 'Jam-Freunde';

  @override
  String get jamFriendsEmpty =>
      'Noch keine Freunde. Nach dem ersten angenommenen Beitritt speichern sich beide Geräte gegenseitig.';

  @override
  String get jamFriendRemove => 'Entfernen';

  @override
  String jamFriendRemoveTitle(String name) {
    return '$name entfernen?';
  }

  @override
  String get jamFriendRemoveBody =>
      'Ihr erkennt euch nicht mehr ohne Nachfrage. Dieses Gerät ändert seinen Ankündigungsschlüssel.';

  @override
  String get jamAutoAcceptFriends => 'Freunde ohne Nachfrage annehmen';

  @override
  String get jamAutoAcceptFriendsHint =>
      'Wird das Handy eines Freundes gestohlen, kann der Dieb in der Nähe deiner Jam beitreten.';

  @override
  String get jamFriendBadge => 'Freund';

  @override
  String get jamNearbyJoin => 'Einer Jam in der Nähe beitreten';

  @override
  String get jamBleTitle => 'Jams in der Nähe finden';

  @override
  String get jamBleBody12 =>
      'Android fragt nach der Berechtigung „Geräte in der Nähe“, um Jams per Bluetooth zu suchen und anzukündigen. Die App liest nicht, wo du bist.';

  @override
  String get jamBleBody11 =>
      'Die Standortberechtigung ist nötig: Android verlangt sie für die Bluetooth-Suche; die App liest nicht, wo du bist.';

  @override
  String get jamBleAllow => 'Erlauben';

  @override
  String get jamBleNotNow => 'Nicht jetzt';

  @override
  String get jamBleLocationOff =>
      'Schalte den Standort von Android ein: Er wird für die Bluetooth-Suche gebraucht. Bis dahin kannst du den Code oder den QR nutzen.';

  @override
  String get jamNearbyScanTitle => 'Jams in der Nähe suchen';

  @override
  String get jamNearbyScanHint => 'Per Bluetooth, nur bei geöffneter App';

  @override
  String get streamCardsUnavailable => 'Nicht verfügbar';

  @override
  String get streamCardsUnavailableBody =>
      'Text, Wissenswertes und Credits zu diesem Titel sind nicht angekommen. Das kann am Netz oder an der Quelle liegen.';

  @override
  String get closeKeyboard => 'Tastatur schließen';

  @override
  String get loadingContent => 'Wird geladen…';

  @override
  String shufflePlusChoosing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Shuffle+ wählt $count Titel aus…',
      one: 'Shuffle+ wählt 1 Titel aus…',
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
  String get closeSearch => 'Suche schließen';

  @override
  String get librarySearchHint => 'Bibliothek durchsuchen';

  @override
  String get genreMixTag => 'Vorgeschlagen';

  @override
  String get genreMixOffJam => 'Vorschläge aus: Jam läuft';

  @override
  String get genreMixOffMetered => 'Vorschläge aus: getaktetes Netz';

  @override
  String get genreMixOffOffline => 'Vorschläge aus: kein Netz';

  @override
  String get genreMixOffNoTool => 'Vorschläge aus: Online-Werkzeug fehlt';

  @override
  String get genreMixOffRateLimited => 'Vorschläge pausiert: zu viele Anfragen';

  @override
  String get playerEmptyTitle => 'Nichts in Wiedergabe';

  @override
  String get playerEmptyHint => 'Wähle, womit es weitergeht.';

  @override
  String get playerEmptyNoQueue => 'Wähle einen Titel zum Starten';

  @override
  String playerLastQueue(String name) {
    return 'Letzte Warteschlange: $name';
  }

  @override
  String get playerResumeLastQueue => 'Letzte Warteschlange fortsetzen';

  @override
  String playerResumeLastQueueSub(String name, String tracks) {
    return '$name, $tracks';
  }

  @override
  String get playerShufflePlusLibrary => 'Shuffle+ der Bibliothek';

  @override
  String get playerShufflePlusLibrarySub =>
      'Deine Bibliothek zufällig, mit Vorschlägen';

  @override
  String get playerRecentlyAdded => 'Zuletzt hinzugefügt';

  @override
  String get reviewSearch => 'Suchen';

  @override
  String get recogTitle => 'Zu bestätigen';

  @override
  String recogSuggested(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Korrekturvorschläge. Prüfe sie einzeln oder nimm alle an.',
      one: '1 Korrekturvorschlag',
    );
    return '$_temp0';
  }

  @override
  String recogAcceptAllCount(int count) {
    return 'Alle annehmen ($count)';
  }

  @override
  String recogAcceptedAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Korrekturen angenommen',
      one: '1 Korrektur angenommen',
    );
    return '$_temp0. Dateien werden im Hintergrund aktualisiert.';
  }

  @override
  String get recogNoProposalsHint => 'Es gibt nichts mehr zu prüfen.';

  @override
  String get logToday => 'Heute';

  @override
  String get logYesterday => 'Gestern';

  @override
  String logDayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge',
      one: '1 Eintrag',
    );
    return '$_temp0';
  }

  @override
  String get logRetention => 'Das Protokoll behält die letzten 30 Tage.';

  @override
  String get logNoMatch => 'Keine Einträge mit diesem Filter.';

  @override
  String get logPickEntry => 'Wähle einen Eintrag, um Details zu sehen.';

  @override
  String get logFilterAll => 'Alle';

  @override
  String get logFilterDownload => 'Downloads';

  @override
  String get logFilterLibrary => 'Mediathek';

  @override
  String get logFilterEnrich => 'Anreicherung';

  @override
  String get logFilterCorrections => 'Korrekturen';

  @override
  String get logFilterErrors => 'Fehler';

  @override
  String get logFailedLabel => 'Fehlgeschlagen';

  @override
  String get logStoppedLabel => 'Angehalten';

  @override
  String get logClearMenu => 'Protokoll leeren';

  @override
  String get logClearTitle => 'Protokoll leeren?';

  @override
  String get logClearConfirm => 'Leeren';

  @override
  String get logPendingSub => 'Korrekturvorschläge für deine Titel';

  @override
  String get logPendingReview => 'Prüfen';

  @override
  String logPendingMore(int count) {
    return 'und $count weitere';
  }

  @override
  String get logHowTitle => 'So behebst du es';

  @override
  String get logTechTitle => 'Technische Details';

  @override
  String get logOpenSongs => 'Titel ansehen';

  @override
  String logHowSettings(String settings, String page) {
    return 'Öffne $settings, dann „$page“.';
  }

  @override
  String logHowUpdate(String button) {
    return 'Tippe neben yt-dlp auf „$button“.';
  }

  @override
  String get logHowWait => 'Warte ein paar Minuten.';

  @override
  String get logHowOnline => 'Prüfe, ob du online bist.';

  @override
  String get logDlDone => 'Titel heruntergeladen';

  @override
  String get logDlFailed => 'Download fehlgeschlagen';

  @override
  String logDlGroup(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel heruntergeladen',
      one: '1 Titel heruntergeladen',
    );
    return '$_temp0';
  }

  @override
  String get logDlGroupShow => 'Titel anzeigen';

  @override
  String get logDlGroupHide => 'Titel ausblenden';

  @override
  String get logTransferDone => 'Titel gesendet';

  @override
  String get logTransferFailed => 'Senden fehlgeschlagen';

  @override
  String get logScanDone => 'Mediathek aktualisiert';

  @override
  String get logScanDoneSub => 'Alle Ordner geprüft.';

  @override
  String get logScanStopped => 'Scan angehalten';

  @override
  String get logScanFailed => 'Scan fehlgeschlagen';

  @override
  String get logStoppedSub => 'Es wurde vor dem Ende angehalten.';

  @override
  String get logFailedSub => 'Es wurde wegen eines Fehlers angehalten.';

  @override
  String get logEnrichDone => 'Anreicherung beendet';

  @override
  String get logEnrichInterrupted => 'Anreicherung unterbrochen';

  @override
  String get logEnrichInterruptedSub =>
      'Er wurde wegen eines Fehlers angehalten; das Erledigte bleibt gespeichert.';

  @override
  String get logBgDone => 'Texte und Cover hinzugefügt';

  @override
  String get logBgDoneSub => 'Vervollständigung im Hintergrund.';

  @override
  String get logBgStopped => 'Vervollständigung angehalten';

  @override
  String get logBgStoppedSub => 'Im Moment antwortet keine Quelle.';

  @override
  String get logBgFailed => 'Vervollständigung fehlgeschlagen';

  @override
  String get logBgFailedSub => 'Ein Fehler hat sie angehalten.';

  @override
  String get logSecondOpinion => 'Zweite Meinung von YouTube Music';

  @override
  String get logSecondOpinionSub => 'Die unsicheren Titel wurden geprüft.';

  @override
  String get logSecondOpinionFailed => 'Zweite Meinung unterbrochen';

  @override
  String get logCleanup => 'Duplikate gesucht';

  @override
  String get logCleanupSub => 'Die Titel der Mediathek wurden verglichen.';

  @override
  String get logGenres => 'Genres der Titel neu gelesen';

  @override
  String get logGenresSub =>
      'Die Tags der Titel wurden gelesen, um alle Genres zu finden.';

  @override
  String get logCountries => 'Länder der Künstler gesucht';

  @override
  String get logCountriesSub =>
      'Das Herkunftsland der Künstler in der Mediathek wurde gesucht.';

  @override
  String get logReleases => 'Neuerscheinungen geprüft';

  @override
  String get logReleasesSub =>
      'Neuigkeiten der Künstler, denen du folgst, gesucht.';

  @override
  String get logPodcasts => 'Podcasts aktualisiert';

  @override
  String get logRadio => 'Sender geprüft';

  @override
  String get logTaskFailed => 'Aufgabe fehlgeschlagen';

  @override
  String logImportDone(String name) {
    return 'Playlist „$name“ importiert';
  }

  @override
  String logImportReady(String name) {
    return 'Playlist „$name“ bereit';
  }

  @override
  String get logImportFailed => 'Import fehlgeschlagen';

  @override
  String get logImportRate => 'Import von YouTube gebremst';

  @override
  String get logImportPaused => 'Import pausiert';

  @override
  String get logWhyToolMissing => 'Die Komponente zum Laden von YouTube fehlt.';

  @override
  String get logWhyToolOld =>
      'Die Komponente zum Laden von YouTube ist zu alt.';

  @override
  String get logWhyNetwork => 'Netzwerk nicht verfügbar.';

  @override
  String get logWhyRate => 'YouTube hat darum gebeten, langsamer zu machen.';

  @override
  String get logWhyFailing =>
      'Zu viele Fehler hintereinander: Ich habe sie pausiert.';

  @override
  String get logCorrectionTitle => 'Titel und Künstler korrigiert';

  @override
  String logChipSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel',
      one: '1 Titel',
    );
    return '$_temp0';
  }

  @override
  String logChipArtists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Künstler',
      one: '1 Künstler',
    );
    return '$_temp0';
  }

  @override
  String logChipSongsOf(int done, int total) {
    return '$done von $total Titeln';
  }

  @override
  String logChipUpdated(int count) {
    return '$count aktualisiert';
  }

  @override
  String logChipNotFound(int count) {
    return '$count nicht gefunden';
  }

  @override
  String logChipNoResult(int count) {
    return '$count ohne Ergebnis';
  }

  @override
  String get logFileTitle => 'Korrektur gespeichert, Datei nicht aktualisiert';

  @override
  String get logHowFileMissing =>
      'Prüfe, ob der Titel noch in seinem Ordner liegt.';

  @override
  String get logHowFileReadOnly =>
      'Hebe den Schreibschutz der Datei oder ihres Ordners auf und korrigiere den Titel erneut.';

  @override
  String get logHowFileRetry =>
      'Prüfe, ob genug Speicherplatz frei ist und die Datei nicht benutzt wird, und korrigiere den Titel erneut.';

  @override
  String get logClearBody =>
      'Alle Einträge werden gelöscht und fertige Downloads aus der Liste entfernt. Korrekturen lassen sich danach nicht mehr wiederherstellen. Deine Titel bleiben, wo sie sind.';

  @override
  String logHowResume(String button) {
    return 'Tippe in der Aktivitätsliste beim pausierten Import auf „$button“.';
  }

  @override
  String get logEnrichStopped => 'Anreicherung angehalten';

  @override
  String logCorrectionSem(String from, String to) {
    return 'Von $from zu $to';
  }

  @override
  String get smartAll => 'Alle Bedingungen';

  @override
  String get smartAny => 'Mindestens eine';

  @override
  String get smartAllNote => 'Titel müssen allen Filtern entsprechen.';

  @override
  String get smartAnyNote => 'Ein passender Filter genügt.';

  @override
  String get smartAddFilter => 'Filter hinzufügen';

  @override
  String get smartGroupMusic => 'Musik';

  @override
  String get smartGroupListening => 'Hören';

  @override
  String get smartGroupFile => 'Datei';

  @override
  String get smartFieldTag => 'Tags';

  @override
  String get smartFieldAlbumArtist => 'Albuminterpret';

  @override
  String get smartFieldCountry => 'Nationalität';

  @override
  String get smartFieldPlays => 'Wiedergaben';

  @override
  String get smartFieldLastPlayed => 'Zuletzt gespielt';

  @override
  String get smartFieldAdded => 'Hinzugefügt';

  @override
  String get smartFieldBitrate => 'Datenrate';

  @override
  String get smartFieldFolder => 'Ordner';

  @override
  String get smartFlagLyrics => 'Mit Text';

  @override
  String get smartEnrichedOnly => 'Nur für angereicherte Titel';

  @override
  String get smartInclude => 'Einschließen';

  @override
  String get smartExclude => 'Ausschließen';

  @override
  String get smartPickValues => 'Werte wählen';

  @override
  String get smartAddValue => 'Hinzufügen';

  @override
  String get smartValueHint => 'Wert eingeben';

  @override
  String get smartDone => 'Fertig';

  @override
  String get smartIncomplete =>
      'Unvollständig: ergänze oder entferne ihn, um zu speichern.';

  @override
  String get smartRemoveFilter => 'Filter entfernen';

  @override
  String smartRemoveValue(String value) {
    return '$value entfernen';
  }

  @override
  String get smartFrom => 'Von';

  @override
  String get smartTo => 'Bis';

  @override
  String get smartMoreThan => 'Mehr als';

  @override
  String get smartLessThan => 'Weniger als';

  @override
  String get smartEqualTo => 'Gleich';

  @override
  String get smartAgeRecent => 'In den letzten';

  @override
  String get smartAgeOlder => 'Seit mehr als';

  @override
  String get smartDays => 'Tage';

  @override
  String get smartMinutes => 'Minuten';

  @override
  String get smartContains => 'Enthält';

  @override
  String get smartAdvancedNote => 'Der Regeltext, nur zum Lesen.';

  @override
  String get smartNotVisual =>
      'Diese Regel ist für den Filter-Editor zu verschachtelt. Sie bleibt, wie sie ist: Du siehst sie unter Erweitert, und unverändert gespeichert ändert sie sich nicht.';

  @override
  String get smartNoFilters => 'Füge einen Filter hinzu, um zu beginnen.';

  @override
  String get smartLimitShort => 'Limit';

  @override
  String get smartIs => 'Ist';

  @override
  String get smartRestart => 'Mit Filtern neu beginnen';

  @override
  String get smartRestarted => 'Regel geleert';

  @override
  String get smartCountError => 'Anzahl nicht verfügbar';

  @override
  String artistMergedNote(int count) {
    return '$count Profile zusammengeführt';
  }

  @override
  String get artistSplit => 'Profile trennen';

  @override
  String get artistMergeWith => 'Zusammenführen mit…';

  @override
  String artistSameWarn(String name) {
    return 'Das scheint derselbe Künstler wie ein anderes Profil zu sein ($name).';
  }

  @override
  String get artistMergeYes => 'Zusammenführen';

  @override
  String get artistNotSame => 'Sind verschieden';

  @override
  String get artistMerged => 'Profile zusammengeführt.';

  @override
  String get artistSplitDone => 'Profile getrennt.';

  @override
  String get artistNotSameDone =>
      'Okay, ich frage für diese beiden Profile nicht mehr nach.';

  @override
  String get artistMergePick => 'Welches Profil?';

  @override
  String get mergedSheetTitle => 'Vereinte Profile';

  @override
  String get artistMainProfile => 'Haupt';

  @override
  String artistOtherProfileOf(String name) {
    return 'Weiteres Profil von $name';
  }

  @override
  String get artistSeparate => 'Trennen';

  @override
  String get artistSeparated => 'Profil getrennt.';

  @override
  String get settingsMergedArtists => 'Vereinte Künstler';

  @override
  String get settingsMergedArtistsHint =>
      'Vereinte Profile ansehen und trennen oder die „Verschieden“-Markierungen entfernen.';

  @override
  String get mergedArtistsEmpty => 'Keine vereinten Künstler.';

  @override
  String get mergedArtistsEmptyHelp =>
      'Wenn du zwei Profile desselben Künstlers vereinst, erscheinen sie hier.';

  @override
  String get mergedArtistsSplitAll => 'Alle trennen';

  @override
  String get notSameTitle => 'Als verschieden markiert';

  @override
  String get notSameRemove => 'Entfernen';

  @override
  String get notSameEmpty => 'Kein Paar ist als verschieden markiert.';

  @override
  String get openArtistPage => 'Künstlerseite öffnen';

  @override
  String get podcastYours => 'Deine Podcasts';

  @override
  String get podcastDiscover => 'Entdecken';

  @override
  String get podcastChartTitle => 'Apple-Podcasts-Charts, Italien';

  @override
  String get podcastGenreAll => 'Alle';

  @override
  String get podcastSearchLens => 'Podcasts suchen';

  @override
  String get podcastSubscribedLabel => 'Abonniert';

  @override
  String get podcastOriginApple => 'Apple Podcasts';

  @override
  String get podcastChartError =>
      'Die Charts antworten nicht. Das passiert, es liegt nicht an dir.';

  @override
  String get podcastNoFeed => 'Apple hat keinen Feed für diesen Podcast.';

  @override
  String get podcastGenreArts => 'Kunst';

  @override
  String get podcastGenreBusiness => 'Wirtschaft';

  @override
  String get podcastGenreComedy => 'Comedy';

  @override
  String get podcastGenreEducation => 'Bildung';

  @override
  String get podcastGenreKids => 'Kinder & Familie';

  @override
  String get podcastGenreHealth => 'Gesundheit & Fitness';

  @override
  String get podcastGenreTvFilm => 'TV & Film';

  @override
  String get podcastGenreMusic => 'Musik';

  @override
  String get podcastGenreNews => 'Nachrichten';

  @override
  String get podcastGenreReligion => 'Religion & Spiritualität';

  @override
  String get podcastGenreScience => 'Wissenschaft';

  @override
  String get podcastGenreSports => 'Sport';

  @override
  String get podcastGenreTechnology => 'Technologie';

  @override
  String get podcastGenreSociety => 'Gesellschaft & Kultur';

  @override
  String get podcastGenreGovernment => 'Regierung';

  @override
  String get podcastGenreHistory => 'Geschichte';

  @override
  String get podcastGenreTrueCrime => 'True Crime';

  @override
  String podcastSubscribeTo(String name) {
    return '$name abonnieren';
  }

  @override
  String get searchSimilarLooking => 'Suche ähnliche Titel …';

  @override
  String searchSimilarQueued(String title) {
    return 'Warteschlange: «$title» und ähnliche Titel';
  }

  @override
  String searchSimilarNone(String title) {
    return 'Keine ähnlichen Titel: nur «$title» läuft';
  }

  @override
  String get searchSeeQueue => 'Warteschlange ansehen';

  @override
  String queueSimilarTo(String title) {
    return 'Ähnlich wie «$title»';
  }

  @override
  String get queueSimilarTag => 'YouTube-Music-Radio';

  @override
  String queueSimilarCount(int total, int owned) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total Titel',
      one: '1 Titel',
    );
    return '$_temp0, $owned schon in der Mediathek';
  }

  @override
  String get queueSimilarSearching => 'Suche ähnliche Titel …';

  @override
  String get dislikeSheetTitle =>
      'Gefällt dir der Titel oder der Künstler nicht?';

  @override
  String get dislikeSheetTrack => 'Nur dieser Titel';

  @override
  String dislikeSheetTrackHint(String title) {
    return '„$title“ kommt nicht wieder, außer er ist sehr nah an dem, was du hörst.';
  }

  @override
  String dislikeSheetArtist(String artist) {
    return 'Alles von $artist';
  }

  @override
  String dislikeSheetArtistHint(String artist) {
    return 'Kein Titel von $artist wird dir mehr vorgeschlagen.';
  }

  @override
  String dislikeArtistDone(String artist) {
    return '$artist wird dir nicht mehr vorgeschlagen';
  }

  @override
  String get artistBlockedLabel => 'Künstler blockiert';

  @override
  String dislikesBlockedOn(String date) {
    return 'Ausgeschlossen am $date';
  }

  @override
  String get podcastFollow => 'Folgen';

  @override
  String get podcastFollowing => 'Gefolgt';

  @override
  String podcastFollowLabel(String name) {
    return '$name folgen';
  }

  @override
  String podcastUnfollowLabel(String name) {
    return '$name nicht mehr folgen';
  }

  @override
  String get podcastPreviewNote =>
      'Vorschau: Du folgst dem Podcast noch nicht. Folgen werden gestreamt.';

  @override
  String get podcastPreviewFollowed =>
      'Jetzt in deinen Podcasts. Deine Hörposition bleibt gespeichert.';

  @override
  String get podcastFollowedMsg => 'Zu deinen Podcasts hinzugefügt';

  @override
  String get podcastUnfollowedMsg =>
      'Du folgst dem Podcast nicht mehr. Folgen bleiben abspielbar';

  @override
  String podcastPlayStream(String title) {
    return 'Als Stream abspielen: $title';
  }

  @override
  String get podcastStreamUnavailable =>
      'Dieser Podcast lässt sich noch nicht streamen.';

  @override
  String get podcastUnfollowTitle => 'Nicht mehr folgen?';

  @override
  String podcastUnfollowBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Du hast $count heruntergeladene Folgen. Behalten oder löschen?',
      one: 'Du hast 1 heruntergeladene Folge. Behalten oder löschen?',
    );
    return '$_temp0';
  }

  @override
  String get podcastKeepDownloads => 'Behalten';

  @override
  String get podcastDeleteDownloads => 'Löschen';
}
