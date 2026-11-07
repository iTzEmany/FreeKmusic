// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appName => 'Codecore';

  @override
  String get chooseFolder => 'Scegli cartella';

  @override
  String get scan => 'Scansiona';

  @override
  String get noTracks => 'Nessun brano. Scegli una cartella e scansiona.';

  @override
  String get openSettings => 'Apri impostazioni';

  @override
  String get permissionDenied => 'Permesso di lettura audio negato';

  @override
  String get permissionExplain =>
      'Codecore ha bisogno del permesso di leggere i file audio per mostrare la tua musica.';

  @override
  String get navLibrary => 'Libreria';

  @override
  String get navFavorites => 'Preferiti';

  @override
  String get navPlaylists => 'Playlist';

  @override
  String get navSettings => 'Impostazioni';

  @override
  String get tracks => 'Brani';

  @override
  String get albums => 'Album';

  @override
  String get artists => 'Artisti';

  @override
  String get searchHint => 'Cerca';

  @override
  String get clearSearch => 'Cancella ricerca';

  @override
  String get sortBy => 'Ordina per';

  @override
  String get addMusicFolder => 'Aggiungi la tua cartella musicale';

  @override
  String get addFolder => 'Aggiungi cartella';

  @override
  String get folders => 'Cartelle musicali';

  @override
  String get refreshLibrary => 'Aggiorna libreria';

  @override
  String get removeFolder => 'Rimuovi cartella';

  @override
  String get unknownArtist => 'Artista sconosciuto';

  @override
  String get unknownAlbum => 'Album sconosciuto';

  @override
  String get variousArtists => 'Artisti vari';

  @override
  String get play => 'Riproduci';

  @override
  String get shuffle => 'Casuale';

  @override
  String get queue => 'Coda';

  @override
  String get nowPlaying => 'In riproduzione';

  @override
  String get nothingPlaying => 'Nessun brano in riproduzione';

  @override
  String get mute => 'Muto';

  @override
  String get scanning => 'Scansione in corso…';

  @override
  String get emptyQueue => 'La coda è vuota';

  @override
  String get noResults => 'Nessun risultato';

  @override
  String get sortDefault => 'Predefinito';

  @override
  String get sortPersonal => 'Ordine personale';

  @override
  String get sortTitle => 'Titolo';

  @override
  String get sortArtist => 'Artista';

  @override
  String get sortAlbum => 'Album';

  @override
  String get sortYear => 'Anno';

  @override
  String get sortAdded => 'Aggiunti di recente';

  @override
  String get sortDuration => 'Durata';

  @override
  String tracksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani',
      one: '1 brano',
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
      other: '$countString album',
      one: '1 album',
    );
    return '$_temp0';
  }

  @override
  String get libraryAll => 'Tutto';

  @override
  String libraryItemsCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString elementi',
      one: '1 elemento',
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
      other: '$countString playlist',
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
      other: '$countString artisti',
      one: '1 artista',
    );
    return '$_temp0';
  }

  @override
  String minutesWords(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n minuti',
      one: '1 minuto',
    );
    return '$_temp0';
  }

  @override
  String hoursWords(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ore',
      one: '1 ora',
    );
    return '$_temp0';
  }

  @override
  String hoursAndMinutes(String hours, String minutes) {
    return '$hours e $minutes';
  }

  @override
  String get collectionNoTracks => 'Nessun brano';

  @override
  String missingTracksCount(int count) {
    return 'Brani non trovati ($count)';
  }

  @override
  String get addedToFavorites => 'Aggiunto ai preferiti';

  @override
  String get removedFromFavorites => 'Rimosso dai preferiti';

  @override
  String get undo => 'Annulla';

  @override
  String get favoritesEmptyTitle => 'Nessun preferito, per ora';

  @override
  String get favoritesEmptyHelp => 'Tocca il cuore su un brano e lo trovi qui.';

  @override
  String get openAllTracks => 'Apri tutti i brani';

  @override
  String get newPlaylist => 'Nuova playlist';

  @override
  String get newPlaylistEllipsis => 'Nuova playlist…';

  @override
  String get playlistName => 'Nome della playlist';

  @override
  String get create => 'Crea';

  @override
  String get cancel => 'Annulla';

  @override
  String get save => 'Salva';

  @override
  String get delete => 'Elimina';

  @override
  String get rename => 'Rinomina';

  @override
  String get noPlaylists => 'Nessuna playlist. Creane una.';

  @override
  String get addToPlaylist => 'Aggiungi a playlist…';

  @override
  String addedToPlaylist(String name) {
    return 'Aggiunto a «$name»';
  }

  @override
  String get playNext => 'Riproduci dopo';

  @override
  String get addToQueue => 'Aggiungi in coda';

  @override
  String get addedToQueue => 'Aggiunto in coda';

  @override
  String get favorite => 'Preferito';

  @override
  String get removeFromFavorites => 'Rimuovi dai preferiti';

  @override
  String get removeFromList => 'Rimuovi';

  @override
  String get editInfo => 'Modifica info';

  @override
  String get details => 'Dettagli';

  @override
  String get showInFolder => 'Mostra nella cartella';

  @override
  String get detailPath => 'Percorso';

  @override
  String get detailFormat => 'Formato';

  @override
  String get detailSize => 'Dimensione';

  @override
  String get detailDuration => 'Durata';

  @override
  String get detailAdded => 'Aggiunto il';

  @override
  String get detailPlays => 'Riproduzioni';

  @override
  String get close => 'Chiudi';

  @override
  String get fieldTitle => 'Titolo';

  @override
  String get fieldArtist => 'Artista';

  @override
  String get fieldAlbum => 'Album';

  @override
  String get fieldAlbumArtist => 'Artista album';

  @override
  String get fieldYear => 'Anno';

  @override
  String get fieldTrackNumber => 'Numero traccia';

  @override
  String get fieldGenre => 'Genere';

  @override
  String get restoreFromFile => 'Ripristina dai tag del file';

  @override
  String get titleRequired => 'Il titolo non può essere vuoto';

  @override
  String get settingsAppearance => 'Aspetto';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get themeNotte => 'Notte viola';

  @override
  String get themeOled => 'Nero puro';

  @override
  String get settingsTextSize => 'Dimensione testo';

  @override
  String get textSmall => 'Piccolo';

  @override
  String get textNormal => 'Normale';

  @override
  String get textLarge => 'Grande';

  @override
  String get settingsCompact => 'Modalità compatta';

  @override
  String get settingsReducedMotion => 'Animazioni ridotte';

  @override
  String get settingsLanguage => 'Lingua';

  @override
  String get settingsLibrary => 'Libreria';

  @override
  String get rescanNow => 'Riscansiona ora';

  @override
  String get clearCoverCache => 'Svuota cache copertine';

  @override
  String get coverCacheCleared => 'Cache copertine svuotata';

  @override
  String get settingsOnline => 'Online';

  @override
  String get settingsPageAppearance => 'Aspetto e lingua';

  @override
  String get settingsPagePlayback => 'Riproduzione';

  @override
  String get settingsPageLibrary => 'Libreria';

  @override
  String get settingsPageOnline => 'Online e download';

  @override
  String get settingsPageNetwork => 'Rete e dispositivi';

  @override
  String get settingsPageBackup => 'Backup';

  @override
  String get settingsPageAdvanced => 'Avanzate e info';

  @override
  String summaryLibrary(int folders, int tracks) {
    String _temp0 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: '$folders cartelle',
      one: '1 cartella',
    );
    String _temp1 = intl.Intl.pluralLogic(
      tracks,
      locale: localeName,
      other: '$tracks brani',
      one: '1 brano',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String summaryTrusted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dispositivi fidati',
      one: '1 dispositivo fidato',
    );
    return '$_temp0';
  }

  @override
  String get summaryNormalizeOn => 'normalizzazione accesa';

  @override
  String get summaryBackup => 'Esporta e ripristina la libreria';

  @override
  String summaryCrossfade(int seconds) {
    return '$seconds s';
  }

  @override
  String get openPlaybackSettings => 'Apri Riproduzione';

  @override
  String get autoEnrich => 'Arricchimento automatico';

  @override
  String get autoEnrichHint =>
      'Cerca metadati e copertine online per i brani nuovi';

  @override
  String get autoLyrics => 'Testi automatici';

  @override
  String get autoLyricsHint => 'Scarica i testi da LRCLIB per i brani nuovi';

  @override
  String get settingsAbout => 'Info';

  @override
  String appVersion(String version) {
    return 'Versione $version';
  }

  @override
  String get licenses => 'Licenze';

  @override
  String get personalUse => 'App per uso personale';

  @override
  String get missingTracksTitle => 'Brani non trovati';

  @override
  String get removeFromLibrary => 'Rimuovi dalla libreria';

  @override
  String get ignore => 'Ignora';

  @override
  String get confirmRemoveTitle => 'Rimuovere dalla libreria?';

  @override
  String get confirmRemoveBody =>
      'Il file non viene toccato; perdi preferiti e playlist di questo brano.';

  @override
  String get noMissingTracks => 'Nessun brano mancante';

  @override
  String get retry => 'Riprova';

  @override
  String scanFailed(String error) {
    return 'Scansione non riuscita: $error';
  }

  @override
  String playbackError(String reason, String title) {
    return 'Impossibile riprodurre «$title»: $reason';
  }

  @override
  String get reasonFileMissing => 'file non trovato';

  @override
  String get reasonUnplayable => 'file non riproducibile';

  @override
  String get reasonNotInLibrary => 'brano non presente in libreria';

  @override
  String get reasonOnlineUnavailable => 'brano online non disponibile';

  @override
  String get reasonAgeRestricted =>
      'vietato ai minori, nessuna traccia audio trovata';

  @override
  String get searchWeb => 'Cerca info sul web';

  @override
  String get enrichPreviewTitle => 'Anteprima informazioni';

  @override
  String get currentValue => 'Attuale';

  @override
  String get proposedValue => 'Proposto';

  @override
  String get apply => 'Applica';

  @override
  String get nothingFound => 'Nessuna informazione trovata';

  @override
  String get userEditedLocked => 'Modificato da te: non viene sovrascritto';

  @override
  String get fieldCover => 'Copertina';

  @override
  String get fieldLyrics => 'Testo';

  @override
  String get fieldCuriosity => 'Curiosità';

  @override
  String get enrichAlbum => 'Arricchisci album';

  @override
  String get enrichLibrary => 'Arricchisci tutta la libreria';

  @override
  String enrichRunning(int done, int total) {
    return 'Arricchimento $done/$total';
  }

  @override
  String enrichResult(int notFound, int updated) {
    return '$updated aggiornati, $notFound non trovati';
  }

  @override
  String get enrichBusy => 'Un arricchimento è già in corso';

  @override
  String get enrichNothingToDo =>
      'Niente da arricchire: ai brani non manca nulla';

  @override
  String get serviceUnavailable =>
      'Servizio non disponibile, riprova più tardi';

  @override
  String get lyrics => 'Testo';

  @override
  String get searchLyrics => 'Cerca testo';

  @override
  String get noLyrics => 'Nessun testo disponibile';

  @override
  String get lyricsNotFound => 'Testo non trovato';

  @override
  String get copy => 'Copia';

  @override
  String get copied => 'Copiato';

  @override
  String get sourceWikipedia => 'Fonte: Wikipedia (CC BY-SA)';

  @override
  String get youtube => 'YouTube';

  @override
  String get ytHint => 'Cerca o incolla un link';

  @override
  String get ytDownload => 'Scarica';

  @override
  String get listenAction => 'Ascolta';

  @override
  String get ytAlreadyInLibrary => 'Già in libreria';

  @override
  String get ytNoResults => 'Nessun risultato';

  @override
  String get ytQueued => 'In coda';

  @override
  String get ytDownloading => 'Download in corso';

  @override
  String get ytDone => 'Completato';

  @override
  String get ytFailed => 'Non riuscito';

  @override
  String get ytCancelled => 'Annullato';

  @override
  String get ytClearCompleted => 'Svuota completati';

  @override
  String get ytCancel => 'Annulla download';

  @override
  String get ytErrUnavailable => 'Video non disponibile (età/regione/privato)';

  @override
  String get ytErrNetwork => 'Rete non disponibile';

  @override
  String get ytErrChanged =>
      'YouTube ha cambiato qualcosa: aggiorna l’app o il pacchetto';

  @override
  String get ytNoFolder => 'Aggiungi prima una cartella musicale';

  @override
  String get ytLegal =>
      'Solo per uso personale. Rispetta i diritti d’autore e i termini di YouTube.';

  @override
  String get useDefaultFolder => 'Usa la cartella Musica del dispositivo';

  @override
  String get ytErrToolMissing =>
      'yt-dlp non trovato: installalo (pip install -U yt-dlp) e riprova';

  @override
  String get ytErrRateLimited =>
      'YouTube ha chiesto di rallentare: riprova tra qualche minuto';

  @override
  String get playlistChangeCover => 'Cambia copertina';

  @override
  String get playlistRemoveCover => 'Rimuovi copertina';

  @override
  String get coverTooLarge => 'Immagine troppo grande (max 4 MB)';

  @override
  String get addSongs => 'Aggiungi brani';

  @override
  String addNSongs(int count) {
    return 'Aggiungi ($count)';
  }

  @override
  String get allSongsInPlaylist => 'Tutti i brani sono già nella playlist';

  @override
  String get shareTitle => 'Condivisione';

  @override
  String get shareSend => 'Invia';

  @override
  String get shareReceive => 'Ricevi';

  @override
  String get shareAll => 'Tutta la libreria';

  @override
  String shareSelection(int count) {
    return 'Selezione ($count brani)';
  }

  @override
  String get sharePick => 'Scegli brani';

  @override
  String get shareStart => 'Avvia condivisione';

  @override
  String get shareStop => 'Ferma';

  @override
  String get shareActive => 'Condivisione attiva';

  @override
  String get shareAddress => 'Indirizzo (IP:porta)';

  @override
  String get sharePin => 'PIN';

  @override
  String get shareConnect => 'Connetti';

  @override
  String shareDownloadSelected(int count) {
    return 'Scarica selezionati ($count)';
  }

  @override
  String shareProgress(int done, int total) {
    return 'Brano $done di $total';
  }

  @override
  String shareDone(int count) {
    return '$count brani ricevuti';
  }

  @override
  String shareConnectedTo(String name) {
    return 'Connesso a $name';
  }

  @override
  String get shareErrUnreachable =>
      'Dispositivo non raggiungibile: controlla indirizzo e Wi‑Fi';

  @override
  String get shareErrPin => 'PIN errato';

  @override
  String get shareErrBlocked => 'Troppi tentativi: riprova tra un minuto';

  @override
  String get shareErrNotCodecore => 'Non è un dispositivo Codecore';

  @override
  String get shareErrFailed => 'Trasferimento non riuscito';

  @override
  String get shareNoNetwork => 'Nessuna rete locale trovata';

  @override
  String get shareFirewall =>
      'Windows può chiedere il permesso del firewall alla prima condivisione.';

  @override
  String get shareHint =>
      'Sullo stesso Wi‑Fi, apri «Ricevi» sull’altro dispositivo e inserisci indirizzo e PIN.';

  @override
  String get shareMenu => 'Condividi…';

  @override
  String get shareDeviceName => 'Nome dispositivo';

  @override
  String get sleepTimer => 'Timer di spegnimento';

  @override
  String sleepMinutes(int count) {
    return '$count minuti';
  }

  @override
  String get sleepEndOfTrack => 'A fine brano';

  @override
  String get sleepCancel => 'Annulla timer';

  @override
  String get pause => 'Pausa';

  @override
  String get nextTrack => 'Brano successivo';

  @override
  String get previousTrack => 'Brano precedente';

  @override
  String get repeat => 'Ripeti';

  @override
  String get moreOptions => 'Altre opzioni';

  @override
  String get back => 'Indietro';

  @override
  String get seekPosition => 'Posizione nel brano';

  @override
  String get settingsPlayback => 'Riproduzione';

  @override
  String get normalizeVolume => 'Normalizza volume';

  @override
  String get normalizeVolumeHint =>
      'Usa il ReplayGain dei file per ridurre i brani troppo forti';

  @override
  String get nearbyDevices => 'Dispositivi vicini';

  @override
  String get searchingDevices => 'Ricerca di dispositivi sulla rete…';

  @override
  String get noDevicesHint =>
      'Nessun dispositivo trovato. Apri Condivisione anche sull’altro dispositivo, sulla stessa rete.';

  @override
  String sendToDevice(String name) {
    return 'Invia a $name';
  }

  @override
  String offerSent(String name) {
    return 'Richiesta inviata a $name';
  }

  @override
  String get offerChooseFirst => 'Scegli prima i brani da inviare';

  @override
  String get sentRequests => 'Richieste inviate';

  @override
  String get receivedRequests => 'Richieste ricevute';

  @override
  String get offerPending => 'In attesa di risposta';

  @override
  String get offerAccepted => 'Accettata';

  @override
  String get offerDeclined => 'Rifiutata';

  @override
  String get offerCancelled => 'Annullata';

  @override
  String get offerExpired => 'Scaduta';

  @override
  String get offerDone => 'Completata';

  @override
  String get offerFailed => 'Non riuscita';

  @override
  String incomingTitle(String name) {
    return '$name vuole inviarti dei brani';
  }

  @override
  String incomingBody(int count, String size) {
    return '$count brani, $size MB';
  }

  @override
  String get accept => 'Accetta';

  @override
  String get decline => 'Rifiuta';

  @override
  String receivingProgress(int done, int total) {
    return 'Ricezione $done/$total';
  }

  @override
  String get manualConnection => 'Collegamento manuale (IP e PIN)';

  @override
  String get receiveFromLan => 'Ricevi dalla rete locale';

  @override
  String get receiveFromLanHint =>
      'Rende il dispositivo visibile e riceve richieste anche in background. Su Android mostra una notifica fissa con cui puoi disattivarlo';

  @override
  String get receiveServiceTitle => 'Codecore è visibile sulla rete';

  @override
  String get receiveServiceText =>
      'Pronto a ricevere brani dai dispositivi vicini';

  @override
  String get receiveServiceDisable => 'Disattiva';

  @override
  String get jamTitle => 'Jam';

  @override
  String get jamStart => 'Avvia una Jam';

  @override
  String jamStartWith(String name) {
    return 'Avvia Jam con $name';
  }

  @override
  String jamWaiting(String name) {
    return 'In attesa che $name accetti…';
  }

  @override
  String jamDeclined(String name) {
    return '$name ha rifiutato la Jam';
  }

  @override
  String jamBusy(String name) {
    return '$name ha già una Jam in corso';
  }

  @override
  String get jamUnreachable => 'Dispositivo non raggiungibile';

  @override
  String jamIncomingTitle(String name) {
    return '$name vuole avviare una Jam';
  }

  @override
  String get jamIncomingBody => 'Ascoltate insieme da una coda condivisa.';

  @override
  String get jamIncomingDialog =>
      'La musica parte da questo dispositivo e potete aggiungere brani entrambi.';

  @override
  String get jamQueue => 'Coda condivisa';

  @override
  String get jamModeHost => 'Coda dell\'host';

  @override
  String get jamModeTogether => 'Coda insieme';

  @override
  String get jamModeGuestHint => 'La modalità della coda la sceglie l\'host';

  @override
  String get jamSuggested => 'Suggerito';

  @override
  String get jamEmpty => 'Metti in coda dalla libreria o dalla ricerca';

  @override
  String jamOnlineFailed(String title) {
    return 'Impossibile aggiungere «$title» alla Jam';
  }

  @override
  String jamAddedBy(String name) {
    return 'aggiunto da $name';
  }

  @override
  String get jamJumpHere => 'Salta qui';

  @override
  String get jamYou => 'te';

  @override
  String get jamGuest => 'Ospite';

  @override
  String get jamAddToJam => 'Aggiungi alla Jam';

  @override
  String jamAdded(int count) {
    return 'Aggiunti alla Jam: $count';
  }

  @override
  String get jamOutput => 'Uscita audio';

  @override
  String get jamOutputHere => 'Questo dispositivo';

  @override
  String jamOutputOther(String name) {
    return '$name';
  }

  @override
  String get jamEnd => 'Termina Jam';

  @override
  String get jamLeave => 'Esci dalla Jam';

  @override
  String get jamEnded => 'La Jam è terminata';

  @override
  String get jamLost => 'Connessione persa';

  @override
  String get jamGuestCannotSkip =>
      'Solo chi ha avviato la Jam può cambiare brano';

  @override
  String get jamRemoveForbidden => 'Puoi rimuovere solo i tuoi brani';

  @override
  String get jamNothingPlaying => 'Niente in riproduzione';

  @override
  String jamWith(String name) {
    return 'Jam con $name';
  }

  @override
  String get jamUnavailable => 'Non disponibile';

  @override
  String get jamPlaying => 'La Jam è attiva';

  @override
  String get jamOpen => 'Apri la Jam';

  @override
  String jamSynced(int ms) {
    return 'Sincronizzato, scarto $ms ms';
  }

  @override
  String get jamSyncing => 'Sincronizzazione in corso…';

  @override
  String jamLatency(int ms) {
    return 'Latenza di questa uscita: $ms ms';
  }

  @override
  String get jamLatencyHint =>
      'Per cuffie o casse Bluetooth: aumenta finché le uscite suonano insieme.';

  @override
  String get jamOutputsHint => 'Più uscite suonano insieme';

  @override
  String get renamePlaylist => 'Rinomina playlist';

  @override
  String get confirmDeletePlaylistTitle => 'Eliminare la playlist?';

  @override
  String confirmDeletePlaylistBody(String name) {
    return '«$name» verrà eliminata. I brani restano nella libreria.';
  }

  @override
  String get confirmRemoveFolderTitle => 'Rimuovere la cartella?';

  @override
  String get confirmRemoveFolderBody =>
      'I suoi brani spariscono dalla libreria. I file restano sul dispositivo.';

  @override
  String get confirmClearCoversTitle => 'Svuotare la cache delle copertine?';

  @override
  String get confirmClearCoversBody =>
      'Le copertine verranno ricreate alla prossima scansione.';

  @override
  String get confirmRestoreTitle => 'Ripristinare dai tag del file?';

  @override
  String get confirmRestoreBody =>
      'Le tue modifiche a questo brano verranno sostituite con i dati del file.';

  @override
  String get removedFromPlaylist => 'Rimosso dalla playlist';

  @override
  String get removedFromQueue => 'Rimosso dalla coda';

  @override
  String get playNextDone => 'Verrà riprodotto dopo';

  @override
  String get ytSearchPrompt => 'Cerca un brano o incolla un link';

  @override
  String get loadFailed => 'Non riesco a caricare i dati.';

  @override
  String get navHome => 'Home';

  @override
  String get navSearch => 'Cerca';

  @override
  String get devicesTitle => 'Dispositivi';

  @override
  String get devicesJamActive => 'Jam attiva';

  @override
  String jamPeople(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Jam, $n persone',
      one: 'Jam, 1 persona',
    );
    return '$_temp0';
  }

  @override
  String get devicesVisibleTitle => 'Rendi visibile questo dispositivo';

  @override
  String get devicesVisibleHint =>
      'Per ricevere brani o fare una Jam, gli altri dispositivi devono poterti vedere sulla rete.';

  @override
  String get devicesJamShort => 'Jam';

  @override
  String get devicesSendShort => 'Invia';

  @override
  String get devicesMore => 'Condivisione e collegamento manuale';

  @override
  String jamParticipantsCount(int n) {
    return '$n persone';
  }

  @override
  String get playingFrom => 'In riproduzione da';

  @override
  String get playContextSearch => 'Ricerca';

  @override
  String get allTracks => 'Tutti i brani';

  @override
  String get trackInfo => 'Info sul brano';

  @override
  String get searchCuriosity => 'Cerca curiosità';

  @override
  String get upNext => 'Prossimi';

  @override
  String get openQueue => 'Apri coda';

  @override
  String get copyLink => 'Copia link';

  @override
  String get moreActions => 'Altre azioni';

  @override
  String get sleepChipEnd => 'fine brano';

  @override
  String get yourLibrary => 'La tua libreria';

  @override
  String playlistCountLabel(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Playlist di $n brani',
      one: 'Playlist di 1 brano',
    );
    return '$_temp0';
  }

  @override
  String get sortRecent => 'Ascoltati di recente';

  @override
  String get sortAlphabetical => 'Alfabetico';

  @override
  String get sortAToZ => 'A–Z';

  @override
  String get sortAddedRecently => 'Aggiunti di recente';

  @override
  String get sortTitleAToZ => 'Titolo A–Z';

  @override
  String get sortMostPlayed => 'Più ascoltati';

  @override
  String get sortTrackCount => 'Numero di brani';

  @override
  String get sortAscending => 'Crescente';

  @override
  String get sortDescending => 'Decrescente';

  @override
  String get viewAsGrid => 'Mostra come griglia';

  @override
  String get viewAsList => 'Mostra come elenco';

  @override
  String get kindAlbum => 'Album';

  @override
  String get kindArtist => 'Artista';

  @override
  String get kindPlaylist => 'Playlist';

  @override
  String discN(int n) {
    return 'Disco $n';
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
  String get mostPlayed => 'Più ascoltati';

  @override
  String get albumsSection => 'Album';

  @override
  String get addAllToQueue => 'Aggiungi in coda';

  @override
  String addedNToQueue(int n) {
    return '$n brani aggiunti in coda';
  }

  @override
  String get editOrder => 'Modifica ordine';

  @override
  String get finishEditing => 'Fine';

  @override
  String get removeFromPlaylistAction => 'Rimuovi dalla playlist';

  @override
  String get noTracksInPlaylist => 'Questa playlist è vuota';

  @override
  String get greetingMorning => 'Buongiorno';

  @override
  String get greetingAfternoon => 'Buon pomeriggio';

  @override
  String get greetingEvening => 'Buonasera';

  @override
  String get homeResume => 'Riprendi';

  @override
  String get homeTopTracks => 'I più ascoltati';

  @override
  String get homeRediscover => 'Da riscoprire';

  @override
  String get homeShuffleAll => 'Casuale su tutto';

  @override
  String homeShuffleAllSub(String tracks, String hours) {
    return '$tracks, $hours';
  }

  @override
  String hoursCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ore',
      one: '1 ora',
      zero: 'meno di un’ora',
    );
    return '$_temp0';
  }

  @override
  String get homeAddedLately => 'Aggiunti da poco';

  @override
  String homeResumeQueue(int n, int m) {
    return 'Brano $n di $m';
  }

  @override
  String homeResumeQueueFrom(String source, int n, int m) {
    return '$source: brano $n di $m';
  }

  @override
  String homeMinutesLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mancano $count minuti',
      one: 'Manca 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String get homeFanOpen => 'Mostra i brani aggiunti da poco';

  @override
  String get showAll => 'Tutti';

  @override
  String get recentSearches => 'Ricerche recenti';

  @override
  String get genresTitle => 'Generi';

  @override
  String downloadsChip(int n) {
    return 'Download ($n)';
  }

  @override
  String get gotIt => 'Ho capito';

  @override
  String get searchEmptyLibrary => 'Nessun risultato in libreria';

  @override
  String get ytInfoTooltip => 'Informazioni sull’uso';

  @override
  String removeRecentSearch(String query) {
    return 'Rimuovi «$query» dalle ricerche recenti';
  }

  @override
  String get groupGoTo => 'Vai a';

  @override
  String get goToAlbum => 'Vai all’album';

  @override
  String get goToArtist => 'Vai all’artista';

  @override
  String get groupQueue => 'Coda';

  @override
  String get groupCollection => 'Raccolta';

  @override
  String get groupEdit => 'Modifica';

  @override
  String get groupOther => 'Altro';

  @override
  String get queueNowPlaying => 'In riproduzione';

  @override
  String get queueNext => 'Prossimi';

  @override
  String get queueClear => 'Svuota';

  @override
  String get queueCleared => 'Coda svuotata';

  @override
  String get queueRebuilt => 'Coda ricreata dalla lista in ascolto';

  @override
  String get jamOutputsAndSync => 'Uscite e sincronia';

  @override
  String get jamHostTag => 'host';

  @override
  String get jamSeekInvalid => 'Posizione non valida per questo brano';

  @override
  String get jamEndConfirmTitle => 'Terminare la Jam per tutti?';

  @override
  String jamEndConfirmBody(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other:
          'I $n ospiti verranno disconnessi e la coda condivisa verrà chiusa.',
      one: 'L’ospite verrà disconnesso e la coda condivisa verrà chiusa.',
    );
    return '$_temp0';
  }

  @override
  String get jamEndConfirmAction => 'Termina';

  @override
  String jamParticipantsLabel(int n, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n partecipanti: $names',
      one: '1 partecipante: $names',
    );
    return '$_temp0';
  }

  @override
  String get jamWaitingEmpty => 'Nessuna Jam in corso';

  @override
  String get activityTitle => 'Attività';

  @override
  String activityScan(int done, int total) {
    return 'Scansione: $done di $total';
  }

  @override
  String get activityScanIdle => 'Scansione in corso';

  @override
  String activityEnrich(int done, int total) {
    return 'Arricchimento: $done di $total';
  }

  @override
  String activityDownload(String title) {
    return 'Download, $title';
  }

  @override
  String activityTransfer(String name, int n) {
    return 'Invio a $name, $n brani';
  }

  @override
  String get activityNone => 'Nessuna attività';

  @override
  String get activityCompleted => 'Completate';

  @override
  String get importPhaseSearching => 'In ricerca…';

  @override
  String importPhaseDownloading(int percent) {
    return 'Download $percent %';
  }

  @override
  String importPhaseRetry(int seconds) {
    return 'Nuovo tentativo tra $seconds s';
  }

  @override
  String get importPhaseEnriching => 'Arricchimento…';

  @override
  String get importPhaseDownloadStart => 'Download…';

  @override
  String get importFilterAll => 'Tutti';

  @override
  String get importFilterActive => 'In corso';

  @override
  String get importFilterProblems => 'Da sistemare';

  @override
  String get importFilterDone => 'Fatti';

  @override
  String get importRowsNone => 'Nessun brano qui';

  @override
  String get activityLog => 'Registro';

  @override
  String activityLogCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count eventi',
      one: '1 evento',
      zero: 'Vuoto',
    );
    return '$_temp0';
  }

  @override
  String get activityLogEmpty =>
      'Niente da registrare per ora: qui compaiono download, importazioni e invii finiti.';

  @override
  String logImport(String name) {
    return 'Importazione «$name»';
  }

  @override
  String importNotificationText(int done, int total) {
    return '$done di $total';
  }

  @override
  String importNotificationPaused(int done, int total) {
    return 'In pausa, $done di $total';
  }

  @override
  String importWaitRateLimited(String time) {
    return 'YouTube chiede una pausa: riprendo alle $time';
  }

  @override
  String importWaitNetwork(String time) {
    return 'Rete assente: riprovo alle $time';
  }

  @override
  String importPausedTitle(String name) {
    return 'Importazione «$name» in pausa';
  }

  @override
  String get downloadsNotificationTitle => 'Download in corso';

  @override
  String downloadsNotificationText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani',
      one: '1 brano',
    );
    return '$_temp0';
  }

  @override
  String activityRunning(int n) {
    return '$n attività in corso';
  }

  @override
  String get settingsLocalNetwork => 'Rete locale';

  @override
  String get removeAll => 'Rimuovi tutti';

  @override
  String get confirmRemoveAllTitle => 'Rimuovere tutti dalla libreria?';

  @override
  String confirmRemoveAllBody(int n) {
    return '$n brani non trovati verranno tolti dalla libreria. I file non vengono toccati; perdi preferiti e playlist di questi brani.';
  }

  @override
  String get csvImportMenu => 'Importa da Exportify (CSV)';

  @override
  String get csvImportIntroTitle => 'Importa una playlist';

  @override
  String get csvImportIntroSource =>
      'Il file CSV si crea gratis dal sito Exportify — exportify.net (non serve nessuna app).';

  @override
  String get csvImportStep1 =>
      'Apri https://exportify.net nel browser (anche dal telefono).';

  @override
  String get csvImportStep2 =>
      'Tocca «Get Started» e accedi con il tuo account Spotify.';

  @override
  String get csvImportStep3 =>
      'Accanto alla playlist che vuoi tocca «Export»: si scarica un file .csv col nome della playlist.';

  @override
  String get csvImportStep4 => 'Torna qui e tocca «Scegli file CSV».';

  @override
  String get csvImportNote =>
      'Codecore cerca i brani nella tua libreria e scarica gli altri da YouTube Music.';

  @override
  String get csvImportNoteOffline =>
      'Verranno collegati solo i brani già presenti nella tua libreria.';

  @override
  String get csvImportCopy => 'Copia indirizzo';

  @override
  String get csvImportCopied => 'Indirizzo copiato';

  @override
  String get csvImportPick => 'Scegli file';

  @override
  String get csvImportNotExportify =>
      'Formato non riconosciuto. Scegli un CSV (Exportify, TuneMyMusic, Soundiiz, Last.fm) o una playlist M3U/M3U8/XSPF.';

  @override
  String get csvImportReadFailed => 'Impossibile leggere il file.';

  @override
  String get csvImportPreviewTitle => 'Importa playlist';

  @override
  String get csvImportName => 'Nome della playlist';

  @override
  String csvImportSummary(int total, int known, int todo) {
    return '$total brani, $known già in libreria, $todo da scaricare';
  }

  @override
  String csvImportSkipped(int n) {
    return '$n righe ignorate (podcast o file locali)';
  }

  @override
  String csvImportEstimate(int minutes) {
    return 'Tempo stimato: circa $minutes min';
  }

  @override
  String get csvImportExists => 'Esiste già una playlist con questo nome';

  @override
  String get csvImportUpdate =>
      'Aggiorna quella esistente (aggiunge solo i brani nuovi)';

  @override
  String get csvImportNew => 'Crea una nuova playlist';

  @override
  String get csvImportGo => 'Importa';

  @override
  String get csvImportStarted =>
      'Importazione avviata: la segui nel Centro Attività';

  @override
  String activityImport(String name, int done, int total) {
    return 'Importazione «$name»: $done di $total';
  }

  @override
  String activityImportPaused(String name, int done, int total) {
    return 'Importazione «$name»: in pausa, $done di $total';
  }

  @override
  String csvImportBanner(int done, int total, int review, int missing) {
    return 'Importazione: $done di $total, $review da verificare, $missing non trovati';
  }

  @override
  String csvImportBannerPaused(int done, int total, int review, int missing) {
    return 'Importazione in pausa: $done di $total, $review da verificare, $missing non trovati';
  }

  @override
  String get csvImportReview => 'Rivedi';

  @override
  String get csvImportResume => 'Riprendi';

  @override
  String get csvImportPause => 'Pausa';

  @override
  String get csvImportCancelTitle => 'Annullare l\'importazione?';

  @override
  String get csvImportCancelBody =>
      'I brani già scaricati restano nella playlist.';

  @override
  String csvImportDone(int added, int review, int missing) {
    return 'Importazione completata: $added aggiunti, $review da verificare, $missing non trovati';
  }

  @override
  String get csvImportFailing => 'Troppi errori di fila: importazione in pausa';

  @override
  String get csvImportReviewTitle => 'Rivedi';

  @override
  String get csvImportToReview => 'Da verificare';

  @override
  String get csvImportNotFound => 'Non trovati';

  @override
  String get csvImportErrors => 'Con errori';

  @override
  String get csvImportRetryAll => 'Riprova tutti';

  @override
  String get csvImportSkip => 'Salta';

  @override
  String get csvImportManual => 'Cerca a mano';

  @override
  String get csvImportNothing => 'Niente da rivedere.';

  @override
  String get csvImportSearch => 'Cerca';

  @override
  String csvImportWanted(String title, String artist, String duration) {
    return 'Cercato: $title, $artist, $duration';
  }

  @override
  String get csvImportDownload => 'Scarica';

  @override
  String get csvImportCancelGo => 'Annulla importazione';

  @override
  String get exportLog => 'Esporta log';

  @override
  String get exportLogHint =>
      'File di testo senza percorsi personali, indirizzi di rete né PIN';

  @override
  String get exportLogDebugOnly =>
      'Disponibile solo nella versione installata (in debug il log non viene scritto su file)';

  @override
  String get exportLogNone => 'Non c\'è ancora nessun log da esportare';

  @override
  String get exportLogSaved => 'Log salvato';

  @override
  String get exportLogFailed => 'Impossibile salvare il log';

  @override
  String get exportPlaylist => 'Esporta…';

  @override
  String get exportPlaylistTitle => 'Esporta playlist';

  @override
  String get exportFormatM3u8 => 'M3U8, per altri lettori';

  @override
  String get exportFormatCsv => 'CSV, come Exportify';

  @override
  String get exportFormatJson => 'JSON, formato Codecore';

  @override
  String get exportRelativePaths => 'Percorsi relativi';

  @override
  String get exportRelativeHint =>
      'Rispetto alla cartella comune dei brani: salva il file lì';

  @override
  String get exportAction => 'Esporta';

  @override
  String get exportSaved => 'Playlist esportata';

  @override
  String get exportEmpty => 'La playlist è vuota';

  @override
  String get exportFailed => 'Impossibile esportare la playlist';

  @override
  String get ytErrToolOutdated =>
      'yt-dlp è troppo vecchio: aggiornalo (Impostazioni, Online e download, Aggiorna) e riprova';

  @override
  String ytDlpOutdatedBanner(String version) {
    return 'yt-dlp $version è troppo vecchio: i download potrebbero non funzionare';
  }

  @override
  String get settingsDownloads => 'Download';

  @override
  String ytDlpVersion(String version) {
    return 'yt-dlp $version';
  }

  @override
  String get ytDlpUnknownVersion => 'yt-dlp non trovato';

  @override
  String get ytDlpUpdate => 'Aggiorna';

  @override
  String ytDlpUpdating(int percent) {
    return 'Aggiornamento… $percent%';
  }

  @override
  String ytDlpUpdated(String version) {
    return 'Aggiornato alla versione $version';
  }

  @override
  String get ytDlpTooOld => 'Troppo vecchio: tocca Aggiorna';

  @override
  String get ytDlpUpdateErrNetwork =>
      'Aggiornamento non riuscito: rete non raggiungibile';

  @override
  String get ytDlpUpdateErrHash =>
      'Aggiornamento annullato: il file scaricato non ha superato il controllo di integrità';

  @override
  String get ytDlpUpdateErrOther =>
      'Aggiornamento non riuscito (dettagli nel log)';

  @override
  String get downloadParallel => 'Download contemporanei';

  @override
  String get downloadParallelHint =>
      'Più insieme è più veloce, ma YouTube può chiedere di rallentare';

  @override
  String get downloadRateLimit => 'Limite di velocità';

  @override
  String get downloadRateNone => 'Nessuno';

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
    return 'Download, $title, nuovo tentativo tra $seconds s ($attempt/$max)';
  }

  @override
  String get downloadFormat => 'Formato dei download';

  @override
  String get downloadFormatOriginal => 'Originale (qualità massima)';

  @override
  String get downloadFormatOriginalHint =>
      'L\'audio di YouTube senza ricodifica, di solito Opus ~160 kbps. Non tutti i lettori e le autoradio lo leggono.';

  @override
  String get downloadFormatM4a => 'M4A (consigliato)';

  @override
  String get downloadFormatM4aHint =>
      'Quasi come l\'originale, senza ricodifica: veloce, leggero (~1 MB/min), si legge ovunque.';

  @override
  String get downloadFormatMp3High => 'MP3 320 kbps';

  @override
  String get downloadFormatMp3HighHint =>
      'Compatibile con tutto. Ricodificato: lieve perdita, file grandi (~2,4 MB/min), download più lento.';

  @override
  String get downloadFormatMp3Low => 'MP3 192 kbps (qualità minima)';

  @override
  String get downloadFormatMp3LowHint =>
      'Compatibile con tutto, metà spazio dell\'MP3 320 (~1,4 MB/min), ma la qualità più bassa.';

  @override
  String get searchCacheClear => 'Svuota cache ricerche';

  @override
  String searchCacheCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ricerche salvate',
      one: '1 ricerca salvata',
      zero: 'Vuota',
    );
    return '$_temp0';
  }

  @override
  String get searchCacheCleared => 'Cache svuotata';

  @override
  String csvImportLengthOff(String found, String wanted) {
    return 'Durata diversa: $found invece di $wanted';
  }

  @override
  String get csvImportKeep => 'Tieni questo';

  @override
  String get csvImportTooBig =>
      'Il file è troppo grande per essere una playlist (massimo 5 MB e 10.000 brani)';

  @override
  String get csvImportAlsoAccepts =>
      'Accetta anche: TuneMyMusic, Soundiiz, Last.fm (CSV), M3U/M3U8, XSPF.';

  @override
  String get csvImportPlanned => 'Abbinamenti pronti: controllali e scarica';

  @override
  String get csvImportLinkOnly => 'Solo collega (nessun download)';

  @override
  String get csvImportLinkOnlyHint =>
      'Crea la playlist con quello che hai già e basta';

  @override
  String get csvImportPlanFirst => 'Rivedi prima di scaricare';

  @override
  String get csvImportPlanFirstHint => 'Cerca tutto, poi scegli cosa scaricare';

  @override
  String get csvImportPlanTitle => 'Abbinamenti';

  @override
  String csvImportPlanGo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Scarica $n brani',
      one: 'Scarica 1 brano',
    );
    return '$_temp0';
  }

  @override
  String get csvImportPlanKnown => 'già scaricato';

  @override
  String get csvImportPlanEmpty => 'Niente da scaricare';

  @override
  String csvImportBannerPlanned(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n brani da scaricare',
      one: '1 brano da scaricare',
    );
    return 'Abbinamenti pronti: $_temp0';
  }

  @override
  String get settingsAdvanced => 'Avanzate';

  @override
  String get importSureThreshold => 'Abbinamento sicuro da';

  @override
  String get importSureThresholdHint =>
      'Sopra questo punteggio un brano dell\'importazione si scarica senza chiedere';

  @override
  String get importReviewThreshold => 'Da verificare da';

  @override
  String get importReviewThresholdHint =>
      'Tra questo punteggio e quello sicuro il brano finisce in «Da verificare»; sotto, in «Non trovati»';

  @override
  String get importThresholdsReset => 'Ripristina i valori predefiniti';

  @override
  String csvImportEstimateHours(int hours, int minutes) {
    return 'Tempo stimato: circa $hours h $minutes min';
  }

  @override
  String csvImportBlocks(int size) {
    return 'Importa a blocchi da $size';
  }

  @override
  String csvImportBigWarning(int n) {
    return 'Sono $n brani da scaricare: ci vorranno ore. A blocchi, uno dopo l\'altro, l\'ordine della playlist resta giusto e puoi fermarti tra un blocco e l\'altro.';
  }

  @override
  String get etaLessThanMinute => 'meno di 1 min';

  @override
  String etaMinutes(int minutes) {
    return 'circa $minutes min';
  }

  @override
  String etaHours(int hours, int minutes) {
    return 'circa $hours h $minutes min';
  }

  @override
  String get csvImportOwnFolder => 'Cartella per questa playlist';

  @override
  String get csvImportOwnFolderHint =>
      'Salva i brani scaricati in una sottocartella col nome della playlist';

  @override
  String get csvImportNumberFiles => 'Numera i file';

  @override
  String get csvImportNumberFilesHint =>
      '07 - Artista - Titolo: la cartella si ascolta nell\'ordine giusto anche fuori da Codecore';

  @override
  String get csvImportFetchCovers => 'Cerca le copertine';

  @override
  String get csvImportFetchCoversHint =>
      'Dopo ogni download cerca la copertina dell\'album su iTunes (album e artista del file)';

  @override
  String get csvImportExport => 'Esporta esito';

  @override
  String get csvImportExported => 'Esito salvato';

  @override
  String get csvOutHeaderRow => 'Riga';

  @override
  String get csvOutHeaderTitle => 'Titolo';

  @override
  String get csvOutHeaderArtists => 'Artisti';

  @override
  String get csvOutHeaderAlbum => 'Album';

  @override
  String get csvOutHeaderDuration => 'Durata (ms)';

  @override
  String get csvOutHeaderIsrc => 'ISRC';

  @override
  String get csvOutHeaderStatus => 'Esito';

  @override
  String get csvOutHeaderNote => 'Motivo';

  @override
  String get csvOutHeaderVideo => 'Video scelto';

  @override
  String get csvOutHeaderScore => 'Punteggio';

  @override
  String get importStatusPending => 'Da cercare';

  @override
  String get importStatusQueued => 'In coda';

  @override
  String get importStatusDownloaded => 'Scaricato';

  @override
  String get importStatusLinked => 'Già in libreria';

  @override
  String get importStatusReview => 'Da verificare';

  @override
  String get importStatusNotFound => 'Non trovato';

  @override
  String get importStatusFailed => 'Errore';

  @override
  String get importStatusSkipped => 'Saltato';

  @override
  String get importStatusPlanned => 'Pianificato';

  @override
  String get importStatusRemoved => 'Rimosso dalla sorgente';

  @override
  String get importNoteNoResults => 'Nessun risultato';

  @override
  String get importNoteLowScore => 'Abbinamento poco sicuro';

  @override
  String get importNoteLinkOnly => 'Solo collegamento: non cercato';

  @override
  String get importNoteYoutubeOff => 'Download disattivato';

  @override
  String get importNoteDownloadFailed => 'Download non riuscito';

  @override
  String get importNoteLengthOff => 'Durata diversa dal file';

  @override
  String get importNoteUnchanged => 'Già nella playlist';

  @override
  String get csvImportSync => 'Sincronizza';

  @override
  String csvImportSyncCounts(int added, int removed) {
    return '$added nuovi, $removed rimossi dalla playlist (i file restano)';
  }

  @override
  String get csvImportSyncChecking => 'Controllo le differenze…';

  @override
  String get playbackSpeed => 'Velocità di riproduzione';

  @override
  String get playbackSpeedHint =>
      'Il tono resta quello originale. Il timer di spegnimento conta il tempo reale, non quello del brano.';

  @override
  String resumeFrom(String time) {
    return 'riprendi da $time';
  }

  @override
  String get restartFromBeginning => 'Ricomincia dall’inizio';

  @override
  String get previewTrack => 'Anteprima 20 s';

  @override
  String get equalizer => 'Equalizzatore';

  @override
  String get eqOutputSpeaker => 'Altoparlante';

  @override
  String get eqOutputHeadphones => 'Cuffie';

  @override
  String get eqHint =>
      'Ogni uscita ricorda la sua curva: cambia da sola quando colleghi le cuffie.';

  @override
  String get eqPresetFlat => 'Piatto';

  @override
  String get eqPresetBass => 'Bassi';

  @override
  String get eqPresetVoice => 'Voce';

  @override
  String get eqPresetTreble => 'Acuti';

  @override
  String get eqPresetCustom => 'Personalizzato';

  @override
  String get eqReset => 'Reimposta';

  @override
  String get eqWaiting => 'Le bande compaiono quando parte il primo brano.';

  @override
  String get eqUnavailable =>
      'L\'equalizzatore non è disponibile su questo dispositivo.';

  @override
  String get transitionMode => 'Passaggio tra i brani';

  @override
  String get transitionNormal => 'Normale';

  @override
  String get transitionGapless => 'Senza pause';

  @override
  String get transitionCrossfade => 'Dissolvenza';

  @override
  String get transitionHint =>
      'Senza pause funziona meglio con brani dello stesso formato (per esempio tutti FLAC).';

  @override
  String crossfadeLength(int seconds) {
    return 'Durata della dissolvenza: $seconds s';
  }

  @override
  String get crossfadePlainInAlbum => 'Non sfumare nello stesso album';

  @override
  String get crossfadePlainInAlbumHint =>
      'Dentro un album i brani si susseguono senza pause, senza sovrapporsi.';

  @override
  String get selectedRow => 'Selezionato';

  @override
  String selectedRowAt(int position) {
    return 'Selezionato, numero $position';
  }

  @override
  String get curiositySong => 'Sul brano';

  @override
  String get curiosityArtist => 'Sull\'artista';

  @override
  String get showMore => 'Mostra tutto';

  @override
  String get showLess => 'Mostra meno';

  @override
  String get curiosityNoSong => 'Nessuna pagina dedicata a questo brano';

  @override
  String get curiosityNoArtist => 'Nessuna pagina sull\'artista';

  @override
  String get themeNew => 'Nuovo tema';

  @override
  String get themeEdit => 'Modifica';

  @override
  String get themeDuplicate => 'Duplica';

  @override
  String get themeDelete => 'Elimina';

  @override
  String get themeExport => 'Esporta';

  @override
  String get themeImport => 'Importa tema';

  @override
  String get themeName => 'Nome del tema';

  @override
  String get themeBase => 'Parti da';

  @override
  String get themeModeSimple => 'Semplice';

  @override
  String get themeModeAdvanced => 'Avanzata';

  @override
  String get themeSave => 'Salva';

  @override
  String get themeEditorTitle => 'Tema personalizzato';

  @override
  String get themeDiscardTitle => 'Scartare le modifiche?';

  @override
  String get themeDiscardBody =>
      'Le modifiche a questo tema non sono state salvate.';

  @override
  String get themeDiscard => 'Scarta';

  @override
  String get smartDiscardBody =>
      'Le modifiche a questa playlist non sono state salvate.';

  @override
  String get themePreview => 'Anteprima';

  @override
  String get themeResetColor => 'Ripristina il colore';

  @override
  String get themeContrastTitle => 'Leggibilità';

  @override
  String get themeContrastLow => 'Poco leggibile';

  @override
  String get themeContrastOk => 'Leggibile';

  @override
  String get themeFix => 'Correggi';

  @override
  String get themeSaved => 'Tema salvato';

  @override
  String get themeLimit => 'Hai già 20 temi: eliminane uno';

  @override
  String get themeImported => 'Tema importato';

  @override
  String get themeImportFailed => 'Il file non è un tema valido';

  @override
  String get themeDeleted => 'Tema eliminato';

  @override
  String get themeMine => 'I miei temi';

  @override
  String get tokenBg => 'Sfondo';

  @override
  String get tokenSurface1 => 'Superficie 1';

  @override
  String get tokenSurface2 => 'Superficie 2';

  @override
  String get tokenSurface3 => 'Superficie 3';

  @override
  String get tokenAccent => 'Accento';

  @override
  String get tokenAccentSoft => 'Accento chiaro';

  @override
  String get tokenOnAccent => 'Testo sull\'accento';

  @override
  String get tokenText => 'Testo';

  @override
  String get tokenTextMuted => 'Testo secondario';

  @override
  String get tokenTextFaint => 'Testo tenue';

  @override
  String get tokenHero => 'Sfondo del lettore';

  @override
  String get tokenError => 'Errore';

  @override
  String get pickerHue => 'Tonalità';

  @override
  String get pickerSv => 'Saturazione e luminosità';

  @override
  String get pickerAlpha => 'Trasparenza';

  @override
  String get pickerHex => 'Codice colore';

  @override
  String get pickerInvalid => 'Codice non valido';

  @override
  String get pickerRecent => 'Usati di recente';

  @override
  String get contrastTextBg => 'Testo su sfondo';

  @override
  String get contrastMutedSurface => 'Testo secondario su superficie';

  @override
  String get contrastOnAccent => 'Testo sull\'accento';

  @override
  String get contrastAccentBg => 'Accento su sfondo';

  @override
  String get themeBackground => 'Sfondo delle pagine';

  @override
  String get bgSolid => 'Tinta unita';

  @override
  String get bgGradient => 'Sfumatura';

  @override
  String get bgImage => 'Immagine';

  @override
  String get bgGradientEnd => 'Colore finale';

  @override
  String get bgAngle => 'Direzione';

  @override
  String get bgPickImage => 'Scegli immagine…';

  @override
  String get bgRemoveImage => 'Rimuovi immagine';

  @override
  String get bgDim => 'Oscuramento';

  @override
  String get bgBlur => 'Sfocatura';

  @override
  String get bgCoverBackdrop => 'In riproduzione: tinta della copertina';

  @override
  String get blurredChrome => 'Dock e intestazioni sfocati';

  @override
  String get blurredChromeHint => 'Può rallentare sui telefoni meno potenti';

  @override
  String get bgImageFailed => 'Impossibile usare l\'immagine';

  @override
  String themeCopyName(String name) {
    return '$name (copia)';
  }

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selezionati',
      one: '1 selezionato',
    );
    return '$_temp0';
  }

  @override
  String get selectAll => 'Seleziona tutto';

  @override
  String get exitSelection => 'Esci dalla selezione';

  @override
  String get bulkActions => 'Azioni';

  @override
  String playNextMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani verranno riprodotti dopo',
      one: '1 brano verrà riprodotto dopo',
    );
    return '$_temp0';
  }

  @override
  String addedToQueueMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani aggiunti in coda',
      one: '1 brano aggiunto in coda',
    );
    return '$_temp0';
  }

  @override
  String addedToPlaylistMany(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani aggiunti a «$name»',
      one: '1 brano aggiunto a «$name»',
    );
    return '$_temp0';
  }

  @override
  String addedToPlaylistSkipped(int added, int skipped, String name) {
    return '$added aggiunti a «$name», $skipped già presenti';
  }

  @override
  String allAlreadyInPlaylist(String name) {
    return 'Erano già tutti in «$name»';
  }

  @override
  String favoritesAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani nei preferiti',
      one: '1 brano nei preferiti',
    );
    return '$_temp0';
  }

  @override
  String favoritesRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani tolti dai preferiti',
      one: '1 brano tolto dai preferiti',
    );
    return '$_temp0';
  }

  @override
  String get bulkAddToFavorites => 'Aggiungi ai preferiti';

  @override
  String get bulkRemoveFromFavorites => 'Togli dai preferiti';

  @override
  String removeManyFromPlaylistTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Rimuovere $count brani dalla playlist?',
      one: 'Rimuovere 1 brano dalla playlist?',
    );
    return '$_temp0';
  }

  @override
  String get removeManyFromPlaylistBody =>
      'I file e la libreria non vengono toccati.';

  @override
  String removedManyFromPlaylist(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani rimossi',
      one: '1 brano rimosso',
    );
    return '$_temp0';
  }

  @override
  String removeManyFromLibraryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Togliere $count brani dalla libreria?',
      one: 'Togliere 1 brano dalla libreria?',
    );
    return '$_temp0';
  }

  @override
  String get removeManyFromLibraryBody =>
      'I file non esistono più: spariscono solo dalla libreria (perdi preferiti e playlist di questi brani).';

  @override
  String removedManyFromLibrary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani tolti dalla libreria',
      one: '1 brano tolto dalla libreria',
    );
    return '$_temp0';
  }

  @override
  String ytDownloadsStarted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count download avviati',
      one: '1 download avviato',
    );
    return '$_temp0';
  }

  @override
  String ytDownloadsSkipped(int started, int skipped) {
    return '$started download avviati, $skipped già in libreria o in corso';
  }

  @override
  String get ytNothingToDownload => 'Sono già tutti in libreria o in corso';

  @override
  String get themeChiaro => 'Chiaro';

  @override
  String get settingsAccent => 'Colore d\'accento';

  @override
  String get accentViola => 'Viola';

  @override
  String get accentBlu => 'Blu';

  @override
  String get accentAcqua => 'Verde acqua';

  @override
  String get accentVerde => 'Verde';

  @override
  String get accentAmbra => 'Ambra';

  @override
  String get accentArancio => 'Arancio';

  @override
  String get accentRosa => 'Rosa';

  @override
  String get accentRosso => 'Rosso';

  @override
  String get onboardingSkip => 'Salta';

  @override
  String get onboardingNext => 'Avanti';

  @override
  String get onboardingStart => 'Inizia';

  @override
  String onboardingPageOf(int page, int total) {
    return 'Pagina $page di $total';
  }

  @override
  String onboardingStepOf(int page, int total) {
    return '$page di $total';
  }

  @override
  String get onboardingWelcomeTitle => 'Benvenuto in Codecore';

  @override
  String get onboardingWelcomeBody =>
      'Il tuo lettore musicale personale: niente account, niente server. La musica resta sul tuo dispositivo.';

  @override
  String get onboardingFoldersTitle => 'La tua musica';

  @override
  String get onboardingFoldersBody =>
      'Scegli le cartelle dove tieni i brani. Codecore li legge: non li modifica e non li sposta.';

  @override
  String onboardingFoldersAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cartelle aggiunte',
      one: '1 cartella aggiunta',
    );
    return '$_temp0';
  }

  @override
  String get onboardingAllowAccess => 'Consenti l’accesso ai file audio';

  @override
  String get onboardingAccessGranted => 'Accesso consentito';

  @override
  String get onboardingOnlineTitle => 'Funzioni online';

  @override
  String get onboardingOnlineBody =>
      'Sono spente: Codecore non si collega a Internet per conto suo. Puoi accenderle ora o più tardi dalle Impostazioni.';

  @override
  String get onboardingShareTitle => 'Download, Jam e condivisione';

  @override
  String get onboardingYoutubeBody =>
      'Puoi scaricare brani da YouTube sul tuo dispositivo, per ascoltarli come il resto della tua musica.';

  @override
  String get onboardingJamBody =>
      'Con una Jam ascolti la stessa musica insieme a un altro dispositivo sulla stessa rete.';

  @override
  String get onboardingSendBody =>
      'Puoi inviare brani ad altri dispositivi vicini, con un PIN, senza passare da Internet.';

  @override
  String get historyTitle => 'Cronologia';

  @override
  String get historySubtitle => 'Quello che hai ascoltato';

  @override
  String get historyToday => 'Oggi';

  @override
  String get historyYesterday => 'Ieri';

  @override
  String get historyEmpty => 'Qui comparirà quello che ascolti.';

  @override
  String get historyOff =>
      'La cronologia è spenta: attivala in Impostazioni, Riproduzione.';

  @override
  String get historyClear => 'Cancella cronologia';

  @override
  String get historyClearTitle => 'Cancellare la cronologia?';

  @override
  String get historyClearBody =>
      'Si cancella solo l’elenco degli ascolti: contatori, preferiti e playlist restano come sono.';

  @override
  String get historyCleared => 'Cronologia cancellata';

  @override
  String get settingsRecordHistory => 'Registra la cronologia di ascolto';

  @override
  String get settingsRecordHistoryHint =>
      'Resta sul dispositivo. Spenta, non si aggiunge nient’altro all’elenco.';

  @override
  String get statsTitle => 'Statistiche';

  @override
  String get statsSubtitle => 'Quanto e cosa ascolti';

  @override
  String get statsMonth => 'Mese';

  @override
  String get statsYear => 'Anno';

  @override
  String get statsPrevious => 'Periodo precedente';

  @override
  String get statsNext => 'Periodo successivo';

  @override
  String get statsEmpty => 'Nessun ascolto in questo periodo.';

  @override
  String statsPlays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ascolti',
      one: '1 ascolto',
    );
    return '$_temp0';
  }

  @override
  String statsDistinct(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani diversi',
      one: '1 brano diverso',
    );
    return '$_temp0';
  }

  @override
  String statsHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get statsTopTracks => 'Brani più ascoltati';

  @override
  String get statsTopArtists => 'Artisti più ascoltati';

  @override
  String get statsTopAlbums => 'Album più ascoltati';

  @override
  String get statsFavouriteHour => 'Ora preferita';

  @override
  String get statsFirstListen => 'Primo ascolto';

  @override
  String statsFirstValue(String title, String date) {
    return '$title, $date';
  }

  @override
  String get statsYourMonth => 'Il tuo mese';

  @override
  String ruleWarning(String term) {
    return 'Non capisco «$term»: lo cerco come testo.';
  }

  @override
  String get smartPlaylistNew => 'Nuova playlist intelligente';

  @override
  String get smartPlaylistEdit => 'Modifica playlist intelligente';

  @override
  String get smartPlaylistLabel => 'Playlist intelligente';

  @override
  String get smartName => 'Nome';

  @override
  String get smartNameRequired => 'Scrivi un nome';

  @override
  String get smartNoRules =>
      'Senza regole la playlist contiene tutta la libreria.';

  @override
  String get smartSortBy => 'Ordina per';

  @override
  String get smartSortMostPlayed => 'Più ascoltati';

  @override
  String get smartSortRandom => 'A caso';

  @override
  String get smartTemplates => 'Modelli';

  @override
  String get smartTplNever => 'Mai ascoltati';

  @override
  String get smartTplRecent => 'Aggiunti di recente';

  @override
  String get smartTplTop => 'I più ascoltati';

  @override
  String get smartTpl90s => 'Anni ’90';

  @override
  String get smartConvert => 'Converti in playlist normale';

  @override
  String smartConverted(String name) {
    return 'Creata la playlist «$name» con l’elenco attuale';
  }

  @override
  String smartDeleteTitle(String name) {
    return 'Eliminare «$name»?';
  }

  @override
  String get smartDeleteBody =>
      'Si elimina solo la regola: i brani restano dove sono.';

  @override
  String get smartAutoNote => 'L’elenco si aggiorna da solo.';

  @override
  String get tagsTitle => 'Etichette';

  @override
  String get tagsSubtitle => 'Le tue etichette';

  @override
  String tagsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count etichette',
      one: '1 etichetta',
    );
    return '$_temp0';
  }

  @override
  String get tagsEllipsis => 'Etichette…';

  @override
  String get tagNew => 'Nuova etichetta';

  @override
  String get tagRename => 'Rinomina etichetta';

  @override
  String get tagColor => 'Colore';

  @override
  String get tagNoColor => 'Nessun colore';

  @override
  String get tagNameTaken => 'Esiste già un’etichetta con questo nome';

  @override
  String tagDeleteTitle(String name) {
    return 'Eliminare l’etichetta «$name»?';
  }

  @override
  String get tagDeleteBody =>
      'Si toglie solo l’etichetta dai brani: i brani restano nella libreria.';

  @override
  String get tagsEmpty => 'Nessuna etichetta: creane una dal menu di un brano.';

  @override
  String get tagAddToSelection => 'Aggiungi etichetta…';

  @override
  String get tagRemoveFromSelection => 'Togli etichetta…';

  @override
  String tagAssigned(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani etichettati «$name»',
      one: '1 brano etichettato «$name»',
    );
    return '$_temp0';
  }

  @override
  String tagUnassigned(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '«$name» tolta da $count brani',
      one: '«$name» tolta da 1 brano',
    );
    return '$_temp0';
  }

  @override
  String get tagNoneToRemove => 'I brani scelti non hanno etichette.';

  @override
  String get cleanupSection => 'Pulizia libreria';

  @override
  String get duplicatesTitle => 'Duplicati';

  @override
  String get duplicatesTileHint => 'Lo stesso brano in più copie o qualità';

  @override
  String get duplicatesIntro =>
      'Cerca lo stesso brano in più copie: lo stesso file in due cartelle o lo stesso brano in due qualità. Prima di unire vedi un’anteprima. Preferiti, playlist, ascolti, testi ed etichette passano al brano che tieni; gli altri vengono solo nascosti e li ripristini da «Brani nascosti». Nessun file viene cancellato senza una doppia conferma.';

  @override
  String get duplicatesSearch => 'Cerca duplicati';

  @override
  String get duplicatesSearchAgain => 'Cerca di nuovo';

  @override
  String get duplicatesReading => 'Leggo la libreria…';

  @override
  String duplicatesHashing(int done, int total) {
    return 'Controllo i file: $done di $total';
  }

  @override
  String get duplicatesGrouping => 'Confronto i brani…';

  @override
  String get duplicatesFailed => 'La ricerca non è riuscita. Riprova.';

  @override
  String get duplicatesNone => 'Nessun duplicato trovato';

  @override
  String duplicatesSummary(int groups, int hidden) {
    String _temp0 = intl.Intl.pluralLogic(
      groups,
      locale: localeName,
      other: '$groups gruppi',
      one: '1 gruppo',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hidden,
      locale: localeName,
      other: '$hidden brani da nascondere',
      one: '1 brano da nascondere',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get duplicatesExactBadge => 'Identici';

  @override
  String get duplicatesProbableBadge => 'Probabili';

  @override
  String get duplicatesKeepLabel => 'Da tenere';

  @override
  String get duplicatesPickKeep => 'Tocca un brano per tenerlo';

  @override
  String get duplicatesMerge => 'Unisci';

  @override
  String get duplicatesNotDuplicates => 'Non sono duplicati';

  @override
  String duplicatesMergeAllExact(int count) {
    return 'Unisci tutti gli identici ($count)';
  }

  @override
  String get duplicatesMergeAllTitle => 'Unire tutti gli identici?';

  @override
  String duplicatesMergeAllBody(int groups, int hidden) {
    String _temp0 = intl.Intl.pluralLogic(
      groups,
      locale: localeName,
      other: '$groups gruppi',
      one: '1 gruppo',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hidden,
      locale: localeName,
      other: '$hidden brani nascosti',
      one: '1 brano nascosto',
    );
    return '$_temp0, $_temp1. Preferiti, playlist, ascolti e testi passano ai brani che restano.';
  }

  @override
  String duplicatesMerged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani nascosti',
      one: '1 brano nascosto',
    );
    return 'Unito: $_temp0';
  }

  @override
  String duplicatesDeleteFiles(int count, String size) {
    return 'Elimina anche i file ($count, $size)';
  }

  @override
  String get duplicatesDeleteListTitle => 'Eliminare questi file?';

  @override
  String get duplicatesDeleteListBody =>
      'Verranno cancellati dal dispositivo e non si possono recuperare. I brani che tieni restano dove sono.';

  @override
  String get duplicatesDeleteContinue => 'Continua';

  @override
  String duplicatesDeleteFinalTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Eliminare definitivamente $count file?',
      one: 'Eliminare definitivamente 1 file?',
    );
    return '$_temp0';
  }

  @override
  String duplicatesDeleteFinalBody(String size) {
    return 'Spazio liberato: $size. Questa azione non si può annullare.';
  }

  @override
  String get duplicatesDeleteGo => 'Elimina definitivamente';

  @override
  String get duplicatesDeleteDoneTitle => 'Fatto';

  @override
  String duplicatesDeleteDone(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file eliminati',
      one: '1 file eliminato',
    );
    return '$_temp0 ($size).';
  }

  @override
  String duplicatesDeleteFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file non eliminati:',
      one: '1 file non eliminato:',
    );
    return '$_temp0';
  }

  @override
  String duplicatesDeleteSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file non toccati: sono lo stesso file del brano tenuto.',
      one: '1 file non toccato: è lo stesso file del brano tenuto.',
    );
    return '$_temp0';
  }

  @override
  String get duplicatesDeleteAndroidHint =>
      'Su Android si possono eliminare solo i file nelle cartelle a cui l’app ha accesso.';

  @override
  String activityCleanup(int done, int total) {
    return 'Ricerca duplicati: $done di $total';
  }

  @override
  String get hiddenTracksTitle => 'Brani nascosti';

  @override
  String hiddenTracksCount(int count) {
    return 'Brani nascosti ($count)';
  }

  @override
  String get hiddenTracksEmpty => 'Nessun brano nascosto';

  @override
  String get hiddenTracksHint =>
      'I doppioni uniti non compaiono in libreria. «Ripristina» li rimette al loro posto.';

  @override
  String get hiddenRestore => 'Ripristina';

  @override
  String hiddenRestored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani ripristinati',
      one: '1 brano ripristinato',
    );
    return '$_temp0';
  }

  @override
  String get albumMergeWith => 'Unisci con…';

  @override
  String get albumMergeTitle => 'Unisci album';

  @override
  String albumMergeIntro(String name) {
    return 'Scegli gli album da unire a «$name». I brani passano a un solo album con il titolo e l’artista che indichi; la copertina resta quella di «$name».';
  }

  @override
  String get albumMergeSearch => 'Cerca un album';

  @override
  String get albumMergeNone => 'Non ci sono altri album';

  @override
  String get albumFieldTitle => 'Titolo dell’album';

  @override
  String get albumFieldArtist => 'Artista dell’album';

  @override
  String get albumMergeAction => 'Unisci album';

  @override
  String albumMerged(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count album uniti in «$name»',
      one: '1 album unito in «$name»',
    );
    return '$_temp0';
  }

  @override
  String get moveToAlbum => 'Sposta in un nuovo album…';

  @override
  String get moveToAlbumTitle => 'Sposta in un album';

  @override
  String moveToAlbumBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani andranno',
      one: '1 brano andrà',
    );
    return '$_temp0 nell’album indicato. Se esiste già, si uniranno ad esso.';
  }

  @override
  String get moveToAlbumGo => 'Sposta';

  @override
  String movedToAlbum(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani spostati in «$name»',
      one: '1 brano spostato in «$name»',
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
  String get playlistSourceTitle => 'Playlist o canale YouTube';

  @override
  String get playlistSourceLoading => 'Leggo l’elenco dei video…';

  @override
  String get playlistSourceName => 'Nome della playlist';

  @override
  String playlistSourceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count video',
      one: '1 video',
    );
    return '$_temp0';
  }

  @override
  String playlistSourceUnavailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count video non disponibili (privati o rimossi)',
      one: '1 video non disponibile (privato o rimosso)',
    );
    return '$_temp0';
  }

  @override
  String playlistSourceTruncated(int count) {
    return 'Mostro i primi $count video.';
  }

  @override
  String playlistSourceLong(int count, String time) {
    return 'Sono $count video: ci vorrà $time.';
  }

  @override
  String get playlistSourceNone => 'Nessuno';

  @override
  String get playlistSourceEmpty => 'Non ci sono video da scaricare qui.';

  @override
  String playlistSourceGo(int count) {
    return 'Scarica in una playlist ($count)';
  }

  @override
  String playlistSourceStarted(String name) {
    return 'Download avviati nella playlist «$name»';
  }

  @override
  String get podcastsTitle => 'Podcast';

  @override
  String podcastsSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count podcast',
      one: '1 podcast',
    );
    return '$_temp0';
  }

  @override
  String get podcastsNotice => 'I podcast si aggiornano solo quando lo chiedi.';

  @override
  String get podcastsEmpty => 'Non sei iscritto a nessun podcast.';

  @override
  String get podcastAdd => 'Aggiungi podcast';

  @override
  String get podcastRefreshAll => 'Aggiorna tutti';

  @override
  String get podcastRefresh => 'Aggiorna';

  @override
  String podcastRefreshed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count episodi nuovi',
      one: '1 episodio nuovo',
      zero: 'Nessun episodio nuovo',
    );
    return '$_temp0';
  }

  @override
  String podcastRefreshFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count podcast non aggiornati',
      one: '1 podcast non aggiornato',
    );
    return '$_temp0';
  }

  @override
  String get podcastFeedUrl => 'URL del feed';

  @override
  String get podcastSubscribe => 'Iscriviti';

  @override
  String get podcastSearchHint => 'Cerca un podcast per nome';

  @override
  String get podcastSearchNone => 'Nessun podcast trovato';

  @override
  String podcastSubscribed(String name) {
    return 'Iscritto a «$name»';
  }

  @override
  String podcastEpisodesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count episodi',
      one: '1 episodio',
    );
    return '$_temp0';
  }

  @override
  String podcastToListen(int count) {
    return '$count da ascoltare';
  }

  @override
  String get podcastNoEpisodes => 'Nessun episodio.';

  @override
  String get podcastStateDownloaded => 'Scaricato';

  @override
  String podcastStateDownloading(int percent) {
    return 'Scarico… $percent%';
  }

  @override
  String get podcastStateHeard => 'Ascoltato';

  @override
  String podcastStateRemaining(String time) {
    return 'Mancano $time';
  }

  @override
  String get podcastMarkHeard => 'Segna come ascoltato';

  @override
  String get podcastMarkNotHeard => 'Segna come da ascoltare';

  @override
  String get podcastDeleteFile => 'Elimina il file';

  @override
  String get podcastAutoDelete => 'Elimina gli episodi ascoltati';

  @override
  String get podcastAutoDeleteNever => 'Mai';

  @override
  String podcastAutoDeleteAfter(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days giorni',
      one: '1 giorno',
    );
    return '$_temp0';
  }

  @override
  String get podcastUnsubscribe => 'Annulla l’iscrizione';

  @override
  String get podcastUnsubscribeTitle => 'Annullare l’iscrizione?';

  @override
  String podcastUnsubscribeBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Il podcast e $count episodi scaricati verranno eliminati dal dispositivo.',
      one: 'Il podcast e 1 episodio scaricato verranno eliminati dal dispositivo.',
      zero: 'Il podcast verrà eliminato dal dispositivo.',
    );
    return '$_temp0';
  }

  @override
  String podcastLastChecked(String when) {
    return 'Aggiornato $when';
  }

  @override
  String get podcastNeverChecked => 'Mai aggiornato';

  @override
  String get podcastErrInvalidUrl =>
      'Questo non sembra un indirizzo web valido.';

  @override
  String get podcastErrTooLarge => 'Il feed è troppo grande.';

  @override
  String get podcastErrNetwork => 'Non riesco a raggiungere il server.';

  @override
  String get podcastErrNotFeed => 'Questo indirizzo non è un feed di podcast.';

  @override
  String get podcastErrUnsupportedFormat => 'Formato audio non supportato.';

  @override
  String get syncTitle => 'Sincronizza playlist';

  @override
  String syncAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nuove',
      one: '1 nuova',
    );
    return '$_temp0';
  }

  @override
  String syncUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aggiornate',
      one: '1 aggiornata',
    );
    return '$_temp0';
  }

  @override
  String syncMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani mancanti',
      one: '1 brano mancante',
    );
    return '$_temp0';
  }

  @override
  String get syncUpToDate => 'Le playlist sono già allineate';

  @override
  String syncKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count playlist sono più recenti qui e restano come sono',
      one: '1 playlist è più recente qui e resta com’è',
    );
    return '$_temp0';
  }

  @override
  String get syncReplaceNote =>
      'Le playlist aggiornate sostituiscono quelle di questo dispositivo.';

  @override
  String get syncTagNew => 'Nuova';

  @override
  String get syncTagUpdated => 'Aggiornata';

  @override
  String get syncDetailRenamed => 'rinominata';

  @override
  String get syncDetailReordered => 'riordinata';

  @override
  String syncDetailRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani tolti',
      one: '1 brano tolto',
    );
    return '$_temp0';
  }

  @override
  String get syncAskMissing => 'Chiedi i brani mancanti';

  @override
  String syncApplied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count playlist sincronizzate',
      one: '1 playlist sincronizzata',
    );
    return '$_temp0';
  }

  @override
  String get trustedSection => 'Dispositivi fidati';

  @override
  String trustedFingerprint(String fingerprint) {
    return 'Impronta $fingerprint';
  }

  @override
  String trustedPairedOn(String date) {
    return 'Abbinato il $date';
  }

  @override
  String get trustedAutoAccept => 'Accetta automaticamente';

  @override
  String get trustedAutoAcceptHint =>
      'Ricevi i brani da questo dispositivo senza chiedere.';

  @override
  String get trustedRevoke => 'Revoca';

  @override
  String trustedRevokeTitle(String name) {
    return 'Revocare «$name»?';
  }

  @override
  String get trustedRevokeBody =>
      'Per inviare di nuovo senza PIN dovrete abbinarvi ancora.';

  @override
  String get carMode => 'Modalità in auto';

  @override
  String get carExit => 'Esci';

  @override
  String get carKeepAwake => 'Schermo sempre acceso';

  @override
  String get carPlaylists => 'Playlist';

  @override
  String get carNothing => 'Niente in riproduzione';

  @override
  String get updateCheck => 'Controlla aggiornamenti';

  @override
  String get updateCheckHint =>
      'Chiede a GitHub l’ultima versione, solo quando lo chiedi.';

  @override
  String get updateOnStart => 'Controlla all’avvio';

  @override
  String get updateOnStartHint =>
      'Al più una volta al giorno. Non scarica né installa niente.';

  @override
  String get updateChecking => 'Controllo in corso…';

  @override
  String updateAvailable(String version) {
    return 'Disponibile la versione $version';
  }

  @override
  String updateUpToDate(String version) {
    return 'Hai l’ultima versione ($version)';
  }

  @override
  String get updateRateLimited =>
      'GitHub chiede di aspettare: riprova più tardi.';

  @override
  String get updateFailed =>
      'Non riesco a leggere l’ultima versione. Controlla la connessione.';

  @override
  String get updateCopyLink => 'Copia indirizzo';

  @override
  String get updateLinkCopied => 'Indirizzo copiato';

  @override
  String get backupSection => 'Backup';

  @override
  String get backupCreate => 'Crea backup';

  @override
  String get backupCreateHint =>
      'Playlist, preferiti, testi e modifiche in un file zip. La musica non c’è.';

  @override
  String get backupRestore => 'Ripristina da backup';

  @override
  String get backupRestoreHint =>
      'Sostituisci questa libreria o unisci i dati di un altro dispositivo.';

  @override
  String get backupCreating => 'Creo il backup…';

  @override
  String get backupSaved => 'Backup salvato';

  @override
  String get backupFailed => 'Backup non riuscito';

  @override
  String get restoreTitle => 'Ripristina da backup';

  @override
  String restoreInfo(String date, String version, int tracks, int playlists) {
    return 'Del $date, app $version, $tracks brani, $playlists playlist';
  }

  @override
  String get restoreReplace => 'Sostituisci tutto (stesso dispositivo)';

  @override
  String get restoreMerge => 'Unisci a questa libreria';

  @override
  String get restoreMergeHint =>
      'Aggiunge preferiti, playlist, testi e modifiche ai brani che trova. Non cancella niente.';

  @override
  String get restoreReplaceConfirmTitle => 'Sostituire tutta la libreria?';

  @override
  String get restoreReplaceConfirmBody =>
      'Al prossimo avvio i dati di questa app diventano quelli del backup. Quelli attuali restano in una copia di sicurezza accanto al database.';

  @override
  String get restoreReplaceGo => 'Sostituisci';

  @override
  String get restoreNotBackup =>
      'Questo file non è un backup di Codecore che posso leggere.';

  @override
  String get restoreRestartNeeded =>
      'Pronto: chiudi l’app e riaprila per completare il ripristino.';

  @override
  String restoreMergeDone(
    int recognized,
    int missing,
    int playlists,
    int favorites,
  ) {
    return 'Unione fatta: $recognized brani riconosciuti, $missing non trovati, $playlists playlist create, $favorites preferiti aggiunti.';
  }

  @override
  String get restoreNotFound => 'Brani non trovati';

  @override
  String get restoreCopyList => 'Copia elenco';

  @override
  String get restoreFailed => 'Ripristino non riuscito';

  @override
  String get exportAllPlaylists => 'Esporta tutte le playlist';

  @override
  String get shareErrIdentity =>
      'L’identità di questo dispositivo è cambiata: toglilo dai fidati e abbinalo di nuovo.';

  @override
  String get incomingTrustedTag => 'Dispositivo fidato';

  @override
  String incomingTrustedTitle(String name) {
    return '$name (fidato)';
  }

  @override
  String get pairAction => 'Abbina';

  @override
  String get trustedBadge => 'Fidato';

  @override
  String pairPinTitle(String name) {
    return 'Abbinamento con $name';
  }

  @override
  String pairPinHint(String name) {
    return 'Scrivi il PIN di 6 cifre mostrato su $name.';
  }

  @override
  String pairPinWrong(int count) {
    return 'PIN sbagliato. Tentativi rimasti: $count.';
  }

  @override
  String pairFingerprint(String fingerprint) {
    return 'Impronta: $fingerprint';
  }

  @override
  String get pairCompare =>
      'Controlla che l’impronta sia la stessa sull’altro schermo.';

  @override
  String pairRequestTitle(String name) {
    return '$name vuole abbinarsi';
  }

  @override
  String get pairRequestBody =>
      'Scrivi questo PIN sull’altro dispositivo, poi tocca Conferma.';

  @override
  String get pairConfirm => 'Conferma';

  @override
  String get pairWaiting => 'In attesa della conferma sull’altro dispositivo…';

  @override
  String pairDone(String name) {
    return 'Abbinato con $name';
  }

  @override
  String get pairBlocked => 'Troppi tentativi sbagliati: riprova più tardi.';

  @override
  String get pairRejected => 'Abbinamento rifiutato.';

  @override
  String get pairExpired => 'Richiesta scaduta: riprova.';

  @override
  String get pairFailed => 'Abbinamento non riuscito.';

  @override
  String get syncDevice => 'Sincronizza playlist';

  @override
  String get syncUnreachable =>
      'Il dispositivo non è visibile sulla rete locale.';

  @override
  String get syncFailed => 'Sincronizzazione non riuscita.';

  @override
  String syncAsked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Richiesta inviata: $count brani in arrivo',
      one: 'Richiesta inviata: 1 brano in arrivo',
      zero: 'Nessuno dei brani è sull’altro dispositivo',
    );
    return '$_temp0';
  }

  @override
  String get translateLyrics => 'Traduci';

  @override
  String get translateLyricsFrom => 'Lingua del testo';

  @override
  String get translateLyricsHint =>
      'Traduzione sul telefono, nessun testo viene inviato in rete.';

  @override
  String get translateRemove => 'Mostra solo l\'originale';

  @override
  String translateDownloadTitle(String language) {
    return 'Scaricare il modello $language?';
  }

  @override
  String translateDownloadBody(int mb) {
    return 'Servono circa $mb MB per ogni lingua, meglio con il Wi-Fi. Si scarica una volta sola e poi funziona anche offline.';
  }

  @override
  String get translateDownload => 'Scarica';

  @override
  String translateDownloading(String language) {
    return 'Scarico il modello $language…';
  }

  @override
  String get translateDownloadFailed =>
      'Modello non scaricato. Controlla la connessione e lo spazio.';

  @override
  String get translateFailed => 'Traduzione non riuscita.';

  @override
  String get translateSameLanguage => 'Il testo è già in questa lingua.';

  @override
  String get translationModels => 'Modelli di traduzione';

  @override
  String get translationModelsNone =>
      'Nessun modello scaricato. Si scaricano dalla schermata dei testi, con «Traduci».';

  @override
  String translationModelDelete(String language) {
    return 'Elimina il modello $language';
  }

  @override
  String get scanCode => 'Scansiona codice';

  @override
  String get scanTitle => 'Inquadra il codice QR';

  @override
  String get scanNotCodecore => 'Questo codice non è di Codecore.';

  @override
  String get scanCameraDenied =>
      'Serve il permesso della fotocamera per leggere il codice.';

  @override
  String get scanOpenSettings => 'Apri impostazioni';

  @override
  String get ownFingerprint => 'Impronta di questo dispositivo';

  @override
  String get ownFingerprintHint =>
      'Si confronta con quella mostrata sull’altro schermo quando ci si abbina.';

  @override
  String get writeTagsToFiles => 'Scrivi le modifiche nei file';

  @override
  String get writeTagsToFilesHint =>
      'Titolo, artista, album, anno, genere e traccia modificati qui vengono scritti anche in MP3, FLAC, M4A e OGG. Di ogni file si conserva l’originale. Spenta di default.';

  @override
  String get writeTagsAfterDownload => 'Scrivi i tag nei file scaricati';

  @override
  String get writeTagsAfterDownloadHint =>
      'Solo nei file che Codecore ha scaricato o ricevuto. L\'ISRC resta nell\'app.';

  @override
  String get writeTagsWarnTitle => 'Scrivere le modifiche nei file?';

  @override
  String get writeTagsWarnBody =>
      'Salvando una modifica, i tag vengono riscritti anche nel file musicale (MP3, FLAC, M4A, OGG). Si lavora su una copia, si controlla il risultato e il file viene sostituito solo se tutto torna; prima l’originale è salvato in «Backup dei tag» (gli ultimi 200 o 2 GB). Copertina, testi e ReplayGain non vengono toccati. Prima di attivare conviene fare un backup della libreria (Impostazioni, Backup).';

  @override
  String get writeTagsEnable => 'Attiva';

  @override
  String get tagsAlsoInFile => 'Scrivi anche nel file';

  @override
  String tagsNoWriteUnsupported(String format) {
    return 'Formato non modificabile ($format): cambia solo la libreria';
  }

  @override
  String get tagsNoWriteReadOnly =>
      'File in sola lettura: cambia solo la libreria';

  @override
  String get tagsNoWriteMissing => 'File non trovato: cambia solo la libreria';

  @override
  String tagsFileWriteFailed(int count, String reason) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file non sono stati modificati',
      one: '1 file non è stato modificato',
    );
    return 'Salvato nella libreria, ma $_temp0: $reason';
  }

  @override
  String get tagReasonUnsupported => 'formato non supportato';

  @override
  String get tagReasonNotFound => 'file non trovato';

  @override
  String get tagReasonReadOnly => 'file in sola lettura';

  @override
  String get tagReasonVerifyFailed =>
      'il controllo dopo la scrittura è fallito, il file è rimasto com’era';

  @override
  String get tagReasonWriteFailed =>
      'scrittura non riuscita, il file è rimasto com’era';

  @override
  String get tagReasonBackupFailed =>
      'backup dell’originale non riuscito, il file è rimasto com’era';

  @override
  String get tagReasonIoError => 'errore del disco o dei permessi';

  @override
  String get tagBackupsTitle => 'Backup dei tag';

  @override
  String tagBackupsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Backup dei tag ($count)',
      one: 'Backup dei tag (1)',
      zero: 'Backup dei tag',
    );
    return '$_temp0';
  }

  @override
  String get tagBackupsHint =>
      'L’originale di ogni file riscritto, prima della modifica. Si tengono gli ultimi 200 o 2 GB.';

  @override
  String get tagBackupsEmpty =>
      'Nessun backup: i file non sono ancora stati riscritti.';

  @override
  String get tagBackupRestore => 'Ripristina originale';

  @override
  String tagBackupRestoreBody(String name) {
    return 'Il file «$name» torna com’era prima della modifica. La libreria tiene le modifiche fatte nell’app.';
  }

  @override
  String get tagBackupRestored => 'Originale ripristinato';

  @override
  String tagBackupRestoreFailed(String reason) {
    return 'Ripristino non riuscito: $reason';
  }

  @override
  String get tagBackupDelete => 'Elimina backup';

  @override
  String get tagBackupDeleteBody =>
      'Non potrai più riportare il file a com’era prima della modifica.';

  @override
  String get tagBackupDeleted => 'Backup eliminato';

  @override
  String get deleteFromDevice => 'Elimina dal dispositivo';

  @override
  String deleteTrackTitle(String title) {
    return 'Eliminare «$title»?';
  }

  @override
  String get deleteTrackBody =>
      'Il file viene cancellato dal dispositivo e il brano sparisce dalla libreria, dalle playlist, dai preferiti e dalla cronologia. Non si può annullare.';

  @override
  String deleteTracksTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Eliminare $count brani?',
      one: 'Eliminare 1 brano?',
    );
    return '$_temp0';
  }

  @override
  String get deleteTracksBody =>
      'I file vengono cancellati dal dispositivo e i brani spariscono dalla libreria, dalle playlist, dai preferiti e dalla cronologia. Non si può annullare.';

  @override
  String get deleteConfirm => 'Elimina';

  @override
  String get trackDeleted => 'Brano eliminato';

  @override
  String trackDeleteFailed(String reason) {
    return 'Impossibile eliminare il file: $reason';
  }

  @override
  String tracksDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani eliminati',
      one: '1 brano eliminato',
    );
    return '$_temp0';
  }

  @override
  String tracksDeletedSome(int count, int failed) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani eliminati',
      one: '1 brano eliminato',
    );
    return '$_temp0, $failed non eliminati';
  }

  @override
  String get trackDeleteRefused =>
      'Android non ha permesso di eliminare il file';

  @override
  String get reviewTitle => 'Da revisionare';

  @override
  String get reviewFilterAll => 'Tutti';

  @override
  String get reviewFilterNothingFound => 'Nessun risultato';

  @override
  String get reviewFilterNoLyrics => 'Senza testo';

  @override
  String get reviewFilterNoCover => 'Senza copertina';

  @override
  String get reviewFilterMissingData => 'Dati mancanti';

  @override
  String get reviewEmpty =>
      'Niente da revisionare: ai brani cercati non manca nulla';

  @override
  String get reviewHint =>
      'Brani a cui manca qualcosa. Cerca di nuovo o lascia così.';

  @override
  String get reviewRetry => 'Riprova';

  @override
  String get reviewDismiss => 'Ignora';

  @override
  String reviewRetryStarted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani',
      one: '1 brano',
    );
    return 'Ricerca avviata per $_temp0';
  }

  @override
  String reviewDismissed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani tolti dall\'elenco',
      one: '1 brano tolto dall\'elenco',
    );
    return '$_temp0';
  }

  @override
  String reviewSecondOpinionProgress(int done, int total) {
    return 'Controllo con YouTube Music, $done di $total';
  }

  @override
  String get reviewSecondOpinionStop => 'Ferma';

  @override
  String reviewSecondOpinionDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Aggiornati $count brani con YouTube Music',
      one: 'Aggiornato 1 brano con YouTube Music',
    );
    return '$_temp0';
  }

  @override
  String get reviewSecondOpinionThrottled =>
      'YouTube Music ha chiesto di rallentare: i brani rimasti si controlleranno più tardi';

  @override
  String activitySecondOpinion(int done, int total) {
    return 'Secondo parere: $done di $total';
  }

  @override
  String get secondOpinionLogTitle => 'Secondo parere';

  @override
  String get secondOpinionLogEmpty => 'Nessun brano controllato';

  @override
  String get secondOpinionConfirmed => 'Confermato, niente da aggiungere';

  @override
  String secondOpinionConfirmedFields(String fields) {
    return 'Confermato, aggiunto: $fields';
  }

  @override
  String get secondOpinionNotConfirmed => 'Non confermato';

  @override
  String get secondOpinionNetwork => 'Rete non disponibile, da riprovare';

  @override
  String get secondOpinionThrottled => 'YouTube Music ha chiesto di rallentare';

  @override
  String get sourceYoutubeMusic => 'Fonte: YouTube Music';

  @override
  String get curiositySourceDiscogs => 'Dall\'album, da Discogs';

  @override
  String get navMemory => 'Memoria';

  @override
  String get memoryMusicLabel => 'Musica';

  @override
  String get memoryOtherLabel => 'Altro';

  @override
  String get memoryFreeLabel => 'Libero';

  @override
  String memoryDeviceLine(String free, String total) {
    return '$free liberi su $total';
  }

  @override
  String get memoryPlaylists => 'Playlist';

  @override
  String get memoryPlaylistsNote =>
      'Un brano presente in più playlist conta in ognuna: la somma può superare il totale.';

  @override
  String get memoryByFormat => 'Formati';

  @override
  String get memoryByFolder => 'Cartelle';

  @override
  String get memoryNoFolder => 'Fuori dalle cartelle';

  @override
  String get memoryHeaviest => 'I più pesanti';

  @override
  String get memoryHeaviestTracks => 'Brani';

  @override
  String get memoryHeaviestAlbums => 'Album';

  @override
  String get memoryNeverPlayed => 'Mai ascoltati';

  @override
  String get memoryNeverPlayedHint =>
      'Brani senza nemmeno un ascolto. Selezionane alcuni per eliminarli dal dispositivo.';

  @override
  String get memoryNeverPlayedNone => 'Hai ascoltato tutta la musica';

  @override
  String get memoryAppData => 'Dati dell\'app';

  @override
  String get memoryCovers => 'Copertine';

  @override
  String memoryCoversThumbs(String size) {
    return 'di cui anteprime $size';
  }

  @override
  String get memoryDatabase => 'Libreria';

  @override
  String get memoryImageMemory => 'Immagini in memoria';

  @override
  String get memoryJamCache => 'Cache Jam';

  @override
  String get memorySearchCache => 'Cache delle ricerche';

  @override
  String get memoryCatalogCache => 'Catalogo online';

  @override
  String get memoryBlurCopies => 'Sfondi sfocati';

  @override
  String get memoryTagBackups => 'Backup dei tag';

  @override
  String get memoryLog => 'Registro';

  @override
  String get memoryPodcasts => 'Episodi dei podcast';

  @override
  String get memoryClearCache => 'Svuota cache';

  @override
  String memoryCleared(String size) {
    return 'Liberati $size';
  }

  @override
  String memoryClearedJamKept(String size) {
    return 'Liberati $size. La cache Jam è in uso e non è stata toccata';
  }

  @override
  String get memoryClearFailed => 'Impossibile svuotare la cache';

  @override
  String get memoryOfMusic => 'di musica';

  @override
  String get memoryShowAll => 'Mostra tutti';

  @override
  String get memoryCache => 'Cache';

  @override
  String get memoryCacheHint => 'Immagini, ricerche, Jam';

  @override
  String get memoryDatabaseHint => 'Il database con brani e ascolti';

  @override
  String get memoryTagBackupsHint => 'Prima di ogni modifica ai file';

  @override
  String get memoryTinyNote => 'I dati sotto 1 MB non sono elencati.';

  @override
  String memoryClearHint(String size) {
    return 'Libera $size. Brani, copertine e ascolti restano.';
  }

  @override
  String memoryDuplicateGroups(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString gruppi',
      one: '1 gruppo',
    );
    return '$_temp0';
  }

  @override
  String get memoryTools => 'Strumenti';

  @override
  String get memoryUnavailable => 'Non disponibile';

  @override
  String ytmArtistWithAudience(String audience) {
    return 'Artista, $audience';
  }

  @override
  String ytmOffline(String date) {
    return 'Non in linea, dati del $date';
  }

  @override
  String get ytmArtistNotFound => 'Artista non trovato';

  @override
  String get ytmPageUnreadable =>
      'La pagina non si legge (YouTube ha cambiato qualcosa)';

  @override
  String get ytmArtistUnreadable =>
      'La pagina dell\'artista non si legge (YouTube ha cambiato qualcosa)';

  @override
  String ytmSearchSongsOf(String name) {
    return 'Cerca i brani di $name';
  }

  @override
  String get ytmInYourLibrary => 'Nella tua libreria';

  @override
  String get ytmAbout => 'Informazioni';

  @override
  String get ytmMore => 'Altro';

  @override
  String get ytmLess => 'Meno';

  @override
  String get ytmDownloadAlbum => 'Scarica album';

  @override
  String ytmDownloadAlbumTitle(String album) {
    return 'Scaricare «$album»?';
  }

  @override
  String ytmAlbumConfirmBody(int tracks, String duration, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      tracks,
      locale: localeName,
      other: '$tracks brani',
      one: '1 brano',
    );
    return '$_temp0, $duration, circa $size';
  }

  @override
  String ytmAlbumConfirmOwned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani sono già in libreria e verranno collegati',
      one: '1 brano è già in libreria e verrà collegato',
    );
    return '$_temp0';
  }

  @override
  String ytmAlbumStarted(String name) {
    return 'Importazione «$name» avviata';
  }

  @override
  String get ytmShowImport => 'Mostra';

  @override
  String get ytmOnYoutubeMusic => 'Su YouTube Music';

  @override
  String get ytmArtistOnYoutubeMusic => 'Artista su YouTube Music';

  @override
  String get ytmSearchingArtist => 'Cerco su YouTube Music…';

  @override
  String get ytmPickArtist => 'Quale artista?';

  @override
  String get ytmArtistNone => 'Nessun artista trovato su YouTube Music';

  @override
  String get suggestedBadge => 'Suggerito';

  @override
  String suggestedSimilarTo(String seed) {
    return 'Suggerito: simile a «$seed»';
  }

  @override
  String get suggestionDownloadStarted => 'Download avviato';

  @override
  String suggestionAddWhenDownloaded(String name) {
    return 'Lo scarico e lo aggiungo a «$name»';
  }

  @override
  String get suggestionDislike => 'Non mi piace';

  @override
  String get suggestionDisliked => 'Non te lo suggerirò più';

  @override
  String get removeFromQueueAction => 'Rimuovi dalla coda';

  @override
  String get shuffleModeOff => 'Casuale: spenta';

  @override
  String get shuffleModeOn => 'Casuale: attiva';

  @override
  String get shuffleModePlus =>
      'Casuale+: attiva (premi a lungo per le impostazioni)';

  @override
  String get shufflePlusTitle => 'Casuale+';

  @override
  String get shufflePlusNote =>
      'Si attiva dal pulsante shuffle (terzo tocco). Non disponibile per album in streaming, Jam e radio';

  @override
  String shufflePlusEvery(int n) {
    return 'Un suggerito ogni $n brani';
  }

  @override
  String get shufflePlusUnmeteredOnly => 'Solo su Wi‑Fi';

  @override
  String get shufflePlusUnmeteredOnlyHint =>
      'Niente suggeriti con i dati mobili o su reti a consumo.';

  @override
  String get shufflePlusData =>
      'Consumo stimato: circa 15 MB all’ora con un suggerito ogni 4 brani.';

  @override
  String get shufflePlusActive =>
      'Attivo: i suggeriti arrivano mentre ascolti.';

  @override
  String get shufflePlusOff => 'Spento: la casuale resta normale.';

  @override
  String get shufflePlusBlockJam => 'Non attivo durante una Jam';

  @override
  String get shufflePlusBlockShort => 'Serve una lista di almeno 5 brani';

  @override
  String get shufflePlusBlockNoTool => 'yt-dlp non disponibile';

  @override
  String get shufflePlusBlockMetered => 'In pausa: rete a consumo';

  @override
  String get shufflePlusBlockStopped =>
      'Spento fino al riavvio: troppi errori di riproduzione';

  @override
  String get shufflePlusBlockOnline =>
      'Non disponibile per un album in streaming';

  @override
  String get shufflePlusBlockRadio => 'Non disponibile con la radio';

  @override
  String get shufflePlusNoticeRateLimited =>
      'YouTube chiede di rallentare: i suggeriti sono in pausa per 15 minuti';

  @override
  String get shufflePlusNoticeTooManyErrors =>
      'Troppi errori di riproduzione: i suggeriti sono spenti fino al riavvio';

  @override
  String get suggestionsRecentTitle => 'Suggeriti di recente';

  @override
  String get suggestionsRecentEmpty =>
      'Nessun suggerito per ora. Compaiono qui quando usi Casuale+.';

  @override
  String get suggestionsClear => 'Svuota registro';

  @override
  String get suggestionsClearBody =>
      'Dimentica i suggeriti e i «Non mi piace»: potranno tornare.';

  @override
  String suggestionsRowNote(String seed, String outcome) {
    return 'simile a «$seed», $outcome';
  }

  @override
  String get suggestionOutcomeQueued => 'In coda';

  @override
  String get suggestionOutcomeSkipped => 'Saltato';

  @override
  String get suggestionOutcomeHeard => 'Ascoltato';

  @override
  String get suggestionOutcomeDownloaded => 'Scaricato';

  @override
  String get suggestionOutcomeDisliked => 'Non mi piace';

  @override
  String get memorySuggestions => 'Suggeriti di Casuale+';

  @override
  String searchOnline(String query) {
    return 'Cerca «$query» online';
  }

  @override
  String get onlineBestResults => 'Migliori risultati';

  @override
  String onlineOthersChip(int count) {
    return 'Altri risultati ($count)';
  }

  @override
  String get onlineNoneSure => 'Nessun risultato sicuro';

  @override
  String get onlineInLibrary => 'Nella tua libreria';

  @override
  String onlineShowAllCount(int count) {
    return 'Mostra tutti ($count)';
  }

  @override
  String onlineOwnedHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count risultati già in libreria nascosti',
      one: '1 risultato già in libreria nascosto',
    );
    return '$_temp0';
  }

  @override
  String onlineArtistSongs(String artist) {
    return 'Brani di $artist';
  }

  @override
  String get onlineFilterAll => 'Tutte';

  @override
  String onlineFromSource(String source) {
    return 'Da $source';
  }

  @override
  String get onlineAlsoVideo => 'anche come video';

  @override
  String get onlineListenVideo => 'Ascolta il video';

  @override
  String onlineNoticeRateLimited(String source, String other) {
    return '$source chiede una pausa: risultati solo da $other';
  }

  @override
  String onlineNoticeFailed(String source, String other) {
    return '$source non ha risposto: risultati solo da $other';
  }

  @override
  String get radioTitle => 'Radio';

  @override
  String radioLibrarySubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stazioni salvate',
      one: '1 stazione salvata',
      zero: 'Stazioni in diretta',
    );
    return '$_temp0';
  }

  @override
  String get radioSearchHint => 'Cerca una radio';

  @override
  String radioOnlyCountry(String country) {
    return 'Solo $country';
  }

  @override
  String get radioMine => 'Le mie radio';

  @override
  String get radioNearYou => 'Vicino a te';

  @override
  String get radioGenres => 'Generi';

  @override
  String get radioTopListened => 'Le più ascoltate';

  @override
  String get radioChooseRegion => 'Scegli la regione';

  @override
  String get radioRegionHint =>
      'Le radio vicine si trovano dal paese e dalla regione che scegli: l\'app non usa la tua posizione.';

  @override
  String radioCountryChip(String country) {
    return 'Paese: $country';
  }

  @override
  String get radioChooseCountry => 'Scegli il paese';

  @override
  String radioOfflineList(String date) {
    return 'Non in linea, elenco del $date';
  }

  @override
  String get radioLoadFailed => 'Non riesco a caricare le radio';

  @override
  String get radioNoResults => 'Nessuna radio trovata';

  @override
  String get radioResults => 'Risultati';

  @override
  String get radioSave => 'Salva in Le mie radio';

  @override
  String get radioUnsave => 'Togli da Le mie radio';

  @override
  String get radioSavedDone => 'Radio salvata';

  @override
  String get radioRemovedDone => 'Radio tolta da Le mie radio';

  @override
  String get radioNotResponding => 'non risponde';

  @override
  String get radioLive => 'In diretta';

  @override
  String get reasonRadioUnavailable => 'la radio non risponde';

  @override
  String radioDataPerHour(String mb) {
    return '≈ $mb MB all\'ora';
  }

  @override
  String get radioSite => 'Sito della stazione';

  @override
  String get radioSiteCopied => 'Indirizzo del sito copiato';

  @override
  String get radioSearchSong => 'Cerca questo brano';

  @override
  String get radioRenameTitle => 'Nome della radio';

  @override
  String get radioMobileNotice => 'La radio usa circa 1 MB al minuto di dati.';

  @override
  String get radioAddAddress => 'Aggiungi indirizzo';

  @override
  String get radioAddName => 'Nome';

  @override
  String get radioAddUrl => 'Indirizzo dello stream';

  @override
  String get radioAddTest => 'Prova 10 secondi';

  @override
  String get radioAddTesting => 'Provo… se la senti, puoi salvarla.';

  @override
  String get radioLinkEmpty => 'Scrivi l\'indirizzo dello stream';

  @override
  String get radioLinkNotAnAddress =>
      'Non sembra un indirizzo: scrivilo per intero, per esempio https://…';

  @override
  String get radioLinkBadScheme =>
      'L\'indirizzo deve iniziare con http:// o https://';

  @override
  String get radioLinkNoEntries =>
      'Nel file non c\'è nessun indirizzo da ascoltare';

  @override
  String get radioLinkTooBig =>
      'Il file è troppo grande per essere una lista di radio';

  @override
  String get radioLinkFetchFailed => 'Non riesco a scaricare il file';

  @override
  String get radioReorder => 'Trascina per riordinare';

  @override
  String get radioReorderFailed => 'Non riesco a salvare il nuovo ordine';

  @override
  String get memoryRadio => 'Radio (elenco stazioni)';

  @override
  String get radioGenrePop => 'Pop';

  @override
  String get radioGenreRock => 'Rock';

  @override
  String get radioGenreClassicRock => 'Rock classico';

  @override
  String get radioGenreJazz => 'Jazz';

  @override
  String get radioGenreBlues => 'Blues';

  @override
  String get radioGenreClassical => 'Classica';

  @override
  String get radioGenreDance => 'Dance';

  @override
  String get radioGenreElectronic => 'Elettronica';

  @override
  String get radioGenreHouse => 'House';

  @override
  String get radioGenreHipHop => 'Hip hop';

  @override
  String get radioGenreLoFi => 'Lo-fi';

  @override
  String get radioGenreChillout => 'Chillout';

  @override
  String get radioGenreSixties => 'Anni 60';

  @override
  String get radioGenreSeventies => 'Anni 70';

  @override
  String get radioGenreEighties => 'Anni 80';

  @override
  String get radioGenreNineties => 'Anni 90';

  @override
  String get radioGenreOldies => 'Oldies';

  @override
  String get radioGenreMetal => 'Metal';

  @override
  String get radioGenreReggae => 'Reggae';

  @override
  String get radioGenreLatin => 'Latina';

  @override
  String get radioGenreSoul => 'Soul';

  @override
  String get radioGenreNews => 'Notizie';

  @override
  String get radioGenreTalk => 'Parlato';

  @override
  String get radioGenreSports => 'Sport';

  @override
  String get newReleasesTitle => 'Nuove uscite';

  @override
  String get releasesTopArtists => 'Segui in automatico i più ascoltati';

  @override
  String get releasesTopArtistsHint =>
      'I 15 artisti più ascoltati negli ultimi 90 giorni, cercati su YouTube Music.';

  @override
  String get releasesNotify => 'Notifiche delle nuove uscite';

  @override
  String get releasesNotifyHint => 'Una al giorno al massimo, solo su Android.';

  @override
  String get releasesUnmetered => 'Controlla solo su Wi‑Fi';

  @override
  String get releasesUnmeteredHint =>
      'Un controllo al giorno pesa circa 0,5 MB.';

  @override
  String get releasesTopCardTitle =>
      'Vuoi sapere quando escono brani nuovi dei tuoi artisti più ascoltati?';

  @override
  String get releasesTopCardYes => 'Attiva';

  @override
  String get releasesTopCardNo => 'No, grazie';

  @override
  String get releasesCheckNow => 'Controlla ora';

  @override
  String releasesLastCheck(String when) {
    return 'Ultimo controllo: $when';
  }

  @override
  String get releasesNeverChecked => 'Mai controllato';

  @override
  String releasesPaused(String time) {
    return 'YouTube chiede una pausa: riprovo alle $time';
  }

  @override
  String get releasesChecking => 'Controllo in corso…';

  @override
  String get releasesCheckNone => 'Nessuna nuova uscita';

  @override
  String releasesCheckFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nuove uscite',
      one: '1 nuova uscita',
    );
    return '$_temp0';
  }

  @override
  String get releasesCantCheck =>
      'Non posso controllare ora: manca la rete o non segui nessun artista.';

  @override
  String get releasesChanged =>
      'YouTube Music ha cambiato formato: riprovo al prossimo giro.';

  @override
  String get releasesEmpty =>
      'Nessuna nuova uscita negli ultimi 90 giorni. Apri la pagina di un artista e tocca «Segui».';

  @override
  String get releasesAllArtists => 'Tutti';

  @override
  String releasesFollowedTitle(int count) {
    return 'Artisti seguiti ($count)';
  }

  @override
  String get releasesFollowedLibrary => 'Artisti seguiti';

  @override
  String releasesFollowedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artisti',
      one: '1 artista',
    );
    return '$_temp0';
  }

  @override
  String get followedEmpty =>
      'Non segui ancora nessun artista. Apri la pagina di un artista e tocca «Segui».';

  @override
  String get followAction => 'Segui';

  @override
  String get followingAction => 'Segui già';

  @override
  String followStopTitle(String name) {
    return 'Smettere di seguire $name?';
  }

  @override
  String get followStopBody => 'Non riceverai più le sue nuove uscite.';

  @override
  String get followOnYtm => 'Segui su YouTube Music';

  @override
  String get followStop => 'Non seguire più';

  @override
  String followedNow(String name) {
    return 'Ora segui $name';
  }

  @override
  String get followMute => 'Silenzia notifiche';

  @override
  String get followUnmute => 'Riattiva notifiche';

  @override
  String get followedTopListened => 'Più ascoltato';

  @override
  String get followedToConfirm => 'Da confermare';

  @override
  String get followedNotFound => 'Non trovato';

  @override
  String get followedRetry => 'Riprova';

  @override
  String releaseAlbumYear(String year) {
    return 'Album, $year';
  }

  @override
  String releaseSingleYear(String year) {
    return 'Singolo, $year';
  }

  @override
  String get releaseAlbumPlain => 'Album';

  @override
  String get releaseSinglePlain => 'Singolo';

  @override
  String releaseVariants(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'e altre $count versioni',
      one: 'e un’altra versione',
    );
    return '$_temp0';
  }

  @override
  String get releaseNewBadge => 'Nuovo';

  @override
  String get activityReleases => 'Controllo nuove uscite';

  @override
  String releaseNotifyOne(String title, String artist) {
    return 'Nuova uscita: $title di $artist';
  }

  @override
  String releaseNotifyMany1(int count, String a) {
    return '$count nuove uscite: $a';
  }

  @override
  String releaseNotifyMany2(int count, String a, String b) {
    return '$count nuove uscite: $a e $b';
  }

  @override
  String releaseNotifyManyMore(int count, String a, String b, int others) {
    return '$count nuove uscite: $a, $b e altri $others';
  }

  @override
  String get releaseNotifyShow => 'Mostra';

  @override
  String get reportIssue => 'Segnala un problema';

  @override
  String get reportIssueHint => 'Apre GitHub con il testo già pronto';

  @override
  String get reportKindBug => 'Difetto';

  @override
  String get reportKindIdea => 'Idea';

  @override
  String get reportTitleLabel => 'Titolo';

  @override
  String get reportDescLabel => 'Descrizione';

  @override
  String reportDescHelper(int n) {
    return 'Cosa è successo e come riprodurlo (almeno $n caratteri)';
  }

  @override
  String get reportAttach => 'Allega informazioni tecniche';

  @override
  String get reportAttachPreview => 'Verrà inviato esattamente questo:';

  @override
  String get reportOpen => 'Apri su GitHub';

  @override
  String get reportCopy => 'Copia testo';

  @override
  String get reportCopied => 'Testo copiato';

  @override
  String get reportGithubNote =>
      'Serve un account GitHub; senza, copia il testo e mandalo come preferisci.';

  @override
  String get reportOpenFailed =>
      'Impossibile aprire il browser: il testo è stato copiato';

  @override
  String get reportLogShortened =>
      'Il log verrà accorciato per stare nell\'indirizzo';

  @override
  String get reportNoLog => 'Nessun avviso o errore recente nel log';

  @override
  String get reportUnknown => 'Sconosciuto';

  @override
  String get iconAskTitle => 'Cambiare anche l\'icona dell\'app?';

  @override
  String get iconProblems =>
      'L\'icona cambia quando esci dall\'app. Possibili problemi:\n• il launcher può metterci qualche secondo ad aggiornarla, o mostrare per un attimo due icone o nessuna;\n• su alcuni launcher l\'icona sulla schermata Home viene tolta o spostata e va rimessa a mano (i widget restano);\n• le scorciatoie sulla Home create con la vecchia icona possono smettere di funzionare;\n• l\'app può sparire per un attimo dalle app recenti;\n• raramente Android chiude l\'app e la musica si ferma.\nSul computer l\'icona non cambia.';

  @override
  String get iconChange => 'Cambia l\'icona';

  @override
  String get iconKeep => 'Lascia com\'è';

  @override
  String get iconDontAsk => 'Non chiederlo più';

  @override
  String get iconFollowTitle => 'Icona a tema';

  @override
  String get iconFollowSubtitle =>
      'L\'icona segue tema e colore quando esci dall\'app';

  @override
  String get exportifySyncTitle => 'Sincronizza da Spotify';

  @override
  String exportifySyncChanges(int added, int removed) {
    return '+$added nuovi, −$removed rimossi';
  }

  @override
  String get exportifySyncNew => 'Nuova playlist';

  @override
  String get exportifySyncChoose => 'Da scegliere';

  @override
  String get exportifySyncNoChanges => 'Senza cambiamenti';

  @override
  String exportifySyncSkipped(int n) {
    return '$n file saltati (non sono playlist leggibili)';
  }

  @override
  String exportifySyncGo(int n) {
    return 'Sincronizza $n';
  }

  @override
  String exportifySyncDone(int n) {
    return '$n playlist in sincronizzazione: le segui nel Centro Attività';
  }

  @override
  String get exportifySyncEmpty => 'Nessuna playlist nello ZIP';

  @override
  String get exportifySyncPickTitle => 'Scegli la playlist';

  @override
  String get csvImportOpenExportify => 'Apri exportify.net';

  @override
  String get csvImportOpenFailed => 'Non riesco ad aprire il browser';

  @override
  String get csvImportZipHint =>
      'Con «Export All» ottieni uno ZIP con tutte le playlist: scegli quello e le sincronizzi insieme.';

  @override
  String get exportifySyncFailed => 'Sincronizzazione non riuscita';

  @override
  String get exportifySyncEntryFailed => 'Non riesco a leggere questa playlist';

  @override
  String get exportifySyncLoadFailed =>
      'Non riesco a leggere le playlist dello ZIP';

  @override
  String get exportifyRemindTitle => 'Ricordami di sincronizzare con Spotify';

  @override
  String get exportifyRemindOff => 'Spento';

  @override
  String exportifyRemindDays(int days) {
    return '$days giorni';
  }

  @override
  String get exportifyCardTitle =>
      'È ora di sincronizzare le playlist con Spotify';

  @override
  String get exportifyCardOpen => 'Apri Exportify';

  @override
  String get exportifyCardLater => 'Più tardi';

  @override
  String get exportifyFoundTitle => 'Trovata l’esportazione di Exportify';

  @override
  String get exportifyFoundSync => 'Sincronizza';

  @override
  String get onboardingSpotifyTitle => 'Playlist da Spotify';

  @override
  String get onboardingSpotifyBody =>
      'Su exportify.net scarichi le tue playlist di Spotify in un file. Codecore lo prende e le aggiorna qui.\nNon serve collegare nessun account: il file lo scarichi tu.';

  @override
  String get deezerMeta => 'Metadati da Deezer';

  @override
  String get deezerMetaHint =>
      'Solo dati (copertine, numeri di traccia), mai musica';

  @override
  String get deezerMetaNote =>
      'Uso privato e non commerciale. Le condizioni di Deezer vietano di promuovere lo scaricamento non autorizzato, e Codecore scarica da YouTube: è un rischio tuo.';

  @override
  String get acoustId => 'Riconosci dal suono (AcoustID)';

  @override
  String get acoustIdHint => 'Parte solo l\'impronta del brano, mai l\'audio';

  @override
  String get settingsSpinCover => 'Copertina che ruota';

  @override
  String get settingsSpinCoverHint => 'Nel player, quando la musica suona';

  @override
  String get themeLowContrastWarning =>
      'Alcuni colori del testo si leggono male sullo sfondo (sotto 4,5:1). Il tema resta com\'è.';

  @override
  String get streamCacheTitle => 'Spazio per lo streaming';

  @override
  String streamCacheUsage(String used, String limit) {
    return '$used su $limit';
  }

  @override
  String get streamCacheClear => 'Svuota';

  @override
  String get streamCacheCleared => 'Cache dello streaming svuotata';

  @override
  String get streamCacheClearFailed =>
      'Impossibile svuotare la cache dello streaming';

  @override
  String get playerLoading => 'Caricamento…';

  @override
  String get ytmAlbumQueue => 'Metti in coda l’album';

  @override
  String get addedToLibrary => 'Aggiunto alla libreria';

  @override
  String get promoteNoSpace => 'Spazio insufficiente per scaricare il brano';

  @override
  String get promoteFailed => 'Impossibile spostare il brano';

  @override
  String get creditsDetails => 'Crediti e dettagli';

  @override
  String get creditsDetailsHint => 'Autori, produttori e dettagli dei brani';

  @override
  String get creditsDetailsNote => 'Usa anche un\'API non ufficiale di Deezer';

  @override
  String get creditRoleVocals => 'Voce';

  @override
  String get creditRoleBackingVocals => 'Cori';

  @override
  String get creditRoleGuitar => 'Chitarra';

  @override
  String get creditRoleBassGuitar => 'Basso';

  @override
  String get creditRoleDrums => 'Batteria';

  @override
  String get creditRoleKeyboard => 'Tastiere';

  @override
  String get creditRolePiano => 'Piano';

  @override
  String get creditRoleSynthesizer => 'Sintetizzatore';

  @override
  String get creditRoleComposer => 'Compositore';

  @override
  String get creditRoleAuthor => 'Autore';

  @override
  String get creditRoleLyricist => 'Paroliere';

  @override
  String get creditRoleArranger => 'Arrangiatore';

  @override
  String get creditRoleProducer => 'Produttore';

  @override
  String get creditRoleAdditionalProducer => 'Produttore aggiuntivo';

  @override
  String get creditRoleMix => 'Mixaggio';

  @override
  String get creditRoleMastering => 'Mastering';

  @override
  String get creditRoleRecording => 'Registrazione';

  @override
  String get creditRoleEngineer => 'Tecnico del suono';

  @override
  String get creditRoleProgramming => 'Programmazione';

  @override
  String get creditRoleDrumProgrammer => 'Programmazione batteria';

  @override
  String get creditRoleMusicPublisher => 'Editore musicale';

  @override
  String get creditsGroupPerformers => 'Interpreti e strumenti';

  @override
  String get creditsGroupWriters => 'Autori';

  @override
  String get creditsGroupProduction => 'Produzione e tecnici';

  @override
  String get creditsGroupOther => 'Altro';

  @override
  String get creditsTitle => 'Crediti e dettagli';

  @override
  String get creditsShowAll => 'Mostra tutto';

  @override
  String get creditsRefresh => 'Aggiorna';

  @override
  String get creditsAppearsAs => 'Compare come';

  @override
  String get creditsInCredits => 'Nei crediti';

  @override
  String get creditsRefreshFailed => 'Impossibile aggiornare i crediti';

  @override
  String get creditsBpm => 'BPM';

  @override
  String get creditsLabel => 'Etichetta';

  @override
  String get creditsDigitalRelease => 'Uscita digitale';

  @override
  String get creditsPhysicalRelease => 'Uscita fisica';

  @override
  String get creditsKindSingle => 'Singolo';

  @override
  String get creditsKindEp => 'EP';

  @override
  String get creditsRank => 'Classifica';

  @override
  String get creditsAlbumFans => 'Fan dell’album';

  @override
  String get creditsExplicit => 'Esplicito';

  @override
  String creditsOpenArtist(String name) {
    return 'Apri $name';
  }

  @override
  String get autoCuriosities => 'Curiosità automatiche';

  @override
  String get autoCuriositiesHint =>
      'Cerca le curiosità su Wikipedia per i brani nuovi';

  @override
  String memoryEnrichment(String size) {
    return 'Arricchimento: $size';
  }

  @override
  String memoryEnrichmentDetail(
    String lyrics,
    String curiosities,
    String credits,
  ) {
    return 'Testi $lyrics, curiosità $curiosities, crediti $credits';
  }

  @override
  String get activityPodcastRefresh => 'Aggiornamento dei podcast';

  @override
  String get activityRadio => 'Controllo delle radio salvate';

  @override
  String activityEnrichBackground(int done, int total) {
    return 'Completamento dell\'arricchimento: $done di $total';
  }

  @override
  String get enrichRoundTitle => 'Giro di arricchimento';

  @override
  String get enrichRoundUpdated => 'Aggiornati';

  @override
  String get enrichRoundNone => 'Senza risultato';

  @override
  String get enrichRoundGone => 'Nessun brano da mostrare';

  @override
  String get enrichPartMeta => 'Dati del brano';

  @override
  String get enrichPartLyrics => 'Testo';

  @override
  String get enrichPartSynced => 'Testo sincronizzato';

  @override
  String get enrichPartCurio => 'Curiosità';

  @override
  String get enrichPartCredits => 'Crediti';

  @override
  String get coverChange => 'Cambia copertina';

  @override
  String get coverRestoreOriginal => 'Ripristina copertina originale';

  @override
  String get coverSourceDevice => 'Dal dispositivo';

  @override
  String get coverSourceLibrary => 'Dalla libreria';

  @override
  String get coverSourceOnline => 'Online';

  @override
  String coverSizePx(int w, int h) {
    return '$w × $h';
  }

  @override
  String get speakerPermTitle => 'Permesso Bluetooth';

  @override
  String get speakerPermBody =>
      'Per riconoscere la tua cassa, Codecore deve vedere quali dispositivi Bluetooth sono collegati. Non legge altro.';

  @override
  String get speakerPermAllow => 'Consenti';

  @override
  String get speakerNotNow => 'Non ora';

  @override
  String speakerAskTitle(String name) {
    return '$name è una cassa?';
  }

  @override
  String get speakerAskBody =>
      'Se lo è, quando si collega Codecore apre da solo una Jam a cui gli altri possono unirsi.';

  @override
  String get speakerYes => 'Sì';

  @override
  String get speakerNo => 'No';

  @override
  String get speakerJamSection => 'Jam sulla cassa';

  @override
  String get speakerJamHint =>
      'Quando si collega una cassa Bluetooth, apre da solo una Jam a cui gli altri possono unirsi.';

  @override
  String get speakerNoDevices => 'Nessun dispositivo segnato finora';

  @override
  String get speakerIsSpeaker => 'Cassa';

  @override
  String get speakerNotSpeaker => 'Non è una cassa';

  @override
  String get speakerPermDenied => 'Permesso Bluetooth negato';

  @override
  String get speakerPermRetry => 'Tocca per chiederlo di nuovo';

  @override
  String speakerChange(String name) {
    return 'Cambia $name';
  }

  @override
  String jamInviteBanner(String name) {
    return 'Unisciti alla Jam di $name';
  }

  @override
  String get jamInviteDismiss => 'Nascondi';

  @override
  String get speakerAwayNotice => 'Collega una cassa';

  @override
  String get jamFull => 'La Jam è piena';

  @override
  String get jamAddFailed => 'Non aggiunto alla Jam';

  @override
  String get jamNotFoundOnline => 'Non trovato online, non si può aggiungere';

  @override
  String get jamLeft => 'Sei uscito dalla Jam';

  @override
  String get speakerContinueOnPhone => 'Continua sul telefono';

  @override
  String get speakerContinueOnPhoneLabel =>
      'Continua sul telefono: la Jam suona dall’altoparlante di questo telefono, senza la cassa';

  @override
  String get speakerOfferTitle => 'Suonare la Jam sulla tua cassa?';

  @override
  String get speakerOfferBody =>
      'La tua cassa è collegata e la Jam è ferma. Se vuoi, la musica riparte da qui.';

  @override
  String get jamRemoteTitle => 'Jam a distanza';

  @override
  String get jamRemoteHint =>
      'I broker (server) per la Jam a distanza, in ordine di preferenza.';

  @override
  String get jamBrokerAdd => 'Aggiungi broker';

  @override
  String get jamBrokerHost => 'Indirizzo';

  @override
  String get jamBrokerPort => 'Porta';

  @override
  String get jamBrokerTls => 'Connessione cifrata (TLS)';

  @override
  String get jamBrokerNoTls =>
      'Senza TLS chiunque sulla rete può leggere ciò che passa dal broker. Usalo solo se sai cosa fai.';

  @override
  String get jamBrokerInvalid => 'Indirizzo o porta non validi';

  @override
  String get jamBrokerTest => 'Prova connessione';

  @override
  String jamBrokerTestOk(String broker) {
    return '$broker: connessione riuscita';
  }

  @override
  String jamBrokerTestFail(String broker) {
    return '$broker: non riesco a collegarmi (rete, certificato o server non raggiungibile)';
  }

  @override
  String get jamBrokerRestore => 'Ripristina';

  @override
  String get jamBrokerMoveUp => 'Sposta su';

  @override
  String get jamBrokerRemove => 'Togli';

  @override
  String get jamSuspend => 'Sospendi';

  @override
  String get jamBlock => 'Blocca';

  @override
  String get jamSuspendTitle => 'Sospendi per quanto tempo?';

  @override
  String get jamUntilJamEnds => 'Fino alla fine della Jam';

  @override
  String get jamBlockedTitle => 'Dispositivi bloccati';

  @override
  String get jamSuspendedTitle => 'Sospesi';

  @override
  String get jamUnblock => 'Sblocca';

  @override
  String jamSuspendedUntil(String time) {
    return 'Fino alle $time';
  }

  @override
  String get jamTooSoon => 'Aspetta un momento prima di riprovare';

  @override
  String enrichInterrupted(int updated, int notFound) {
    return 'Arricchimento interrotto da un errore: $updated aggiornati, $notFound non trovati';
  }

  @override
  String enrichLibraryDue(int count, int minutes) {
    return '$count brani da completare, circa $minutes minuti';
  }

  @override
  String get enrichLibraryComplete => 'Libreria completa';

  @override
  String get enrichLibraryStop => 'Interrompi';

  @override
  String get activityEnrichWaiting => 'Completamento: in attesa';

  @override
  String logRecogSources(String list) {
    return 'Riconosciuti: $list';
  }

  @override
  String get recogSrcTags => 'tag';

  @override
  String get recogSrcVideo => 'video';

  @override
  String get recogSrcText => 'testo';

  @override
  String recogIdent(String title, String artist) {
    return '$title – $artist';
  }

  @override
  String recogProposal(String identity) {
    return 'Proposta: $identity';
  }

  @override
  String get recogAccept => 'Accetta';

  @override
  String get recogDiscard => 'Scarta';

  @override
  String recogAcceptSem(String identity) {
    return 'Accetta la proposta $identity';
  }

  @override
  String recogDiscardSem(String identity) {
    return 'Scarta la proposta $identity';
  }

  @override
  String get recogCover => 'Cover';

  @override
  String recogCoverOf(String identity) {
    return 'Cover di $identity';
  }

  @override
  String recogToConfirm(int count) {
    return 'Da confermare ($count)';
  }

  @override
  String get recogAcceptAll => 'Accetta tutte';

  @override
  String get recogNoProposals => 'Tutto confermato';

  @override
  String recogFromTo(String from, String to) {
    return 'Da $from a $to';
  }

  @override
  String get logRevert => 'Ripristina';

  @override
  String get recogActionFailed => 'Operazione non riuscita';

  @override
  String get logRevertFailed => 'Impossibile ripristinare questa correzione';

  @override
  String get jamInviteNearby => 'Invita chi è vicino';

  @override
  String get jamInviteHint =>
      'Chi inquadra il QR o scrive il codice entra nella Jam.';

  @override
  String get jamBridgeConnecting => 'Mi collego…';

  @override
  String get jamBridgeRetrying => 'Ponte interrotto, riprovo…';

  @override
  String get jamBridgeUnreachable => 'Broker irraggiungibile';

  @override
  String jamCodeExpiresIn(int seconds) {
    return 'Scade tra $seconds s';
  }

  @override
  String get jamEnterCode => 'Entra con un codice';

  @override
  String get jamCodeLabel => 'Codice';

  @override
  String get jamScanQr => 'Inquadra il QR';

  @override
  String get jamJoinAction => 'Entra';

  @override
  String get jamCodeInvalid => 'Codice non valido';

  @override
  String get jamCodeExpired => 'Codice scaduto, chiedi quello nuovo';

  @override
  String get jamHostNoAnswer => 'L’host non ha risposto';

  @override
  String get jamCustomBroker =>
      'Questa Jam usa un broker personalizzato: inquadra il QR';

  @override
  String get jamLinkReconnecting => 'Connessione persa, riprovo…';

  @override
  String get jamHostSilent => 'Host non raggiungibile, riprovo…';

  @override
  String get jamMemberUnreachable => 'non raggiungibile';

  @override
  String get jamRemoteActive => 'Jam a distanza attiva';

  @override
  String get jamRemoteEnd => 'Termina';

  @override
  String get jamDeclinedHost => 'L’host ha rifiutato la richiesta';

  @override
  String get jamBusyHost => 'L’host ha già una Jam in corso';

  @override
  String get jamWaitingHost => 'In attesa che l’host accetti…';

  @override
  String get jamFriendsTitle => 'Amici della Jam';

  @override
  String get jamFriendsEmpty =>
      'Nessun amico. Dopo il primo ingresso accettato, i due dispositivi si salvano a vicenda.';

  @override
  String get jamFriendRemove => 'Rimuovi';

  @override
  String jamFriendRemoveTitle(String name) {
    return 'Rimuovere $name?';
  }

  @override
  String get jamFriendRemoveBody =>
      'Non vi riconoscerete più senza chiedere. Questo dispositivo cambia la sua chiave d’annuncio.';

  @override
  String get jamAutoAcceptFriends => 'Accetta gli amici senza chiedere';

  @override
  String get jamAutoAcceptFriendsHint =>
      'Se il telefono di un amico viene rubato, chi lo ha può entrare nella tua Jam stando vicino.';

  @override
  String get jamFriendBadge => 'Amico';

  @override
  String get jamNearbyJoin => 'Unisciti a una Jam qui vicino';

  @override
  String get jamBleTitle => 'Cerca le Jam vicine';

  @override
  String get jamBleBody12 =>
      'Android chiede il permesso «Dispositivi vicini» per cercare e annunciare le Jam via Bluetooth. L\'app non legge dove sei.';

  @override
  String get jamBleBody11 =>
      'Serve il permesso della posizione: Android la richiede per cercare via Bluetooth; l\'app non legge dove sei.';

  @override
  String get jamBleAllow => 'Consenti';

  @override
  String get jamBleNotNow => 'Non ora';

  @override
  String get jamBleLocationOff =>
      'Accendi la posizione di Android: serve per cercare le Jam via Bluetooth. Intanto puoi usare il codice o il QR.';

  @override
  String get jamNearbyScanTitle => 'Cerca Jam vicine';

  @override
  String get jamNearbyScanHint => 'Via Bluetooth, solo con l\'app aperta';

  @override
  String get streamCardsUnavailable => 'Non disponibile';

  @override
  String get streamCardsUnavailableBody =>
      'Testo, curiosità e crediti di questo brano non sono arrivati. Può dipendere dalla rete o dalla fonte.';

  @override
  String get closeKeyboard => 'Chiudi tastiera';

  @override
  String get loadingContent => 'Caricamento…';

  @override
  String shufflePlusChoosing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Shuffle+ sta scegliendo $count brani…',
      one: 'Shuffle+ sta scegliendo 1 brano…',
    );
    return '$_temp0';
  }

  @override
  String statsBarValue(String when, String time) {
    return '$when, $time';
  }

  @override
  String get homeRadioLive => 'In diretta';

  @override
  String get closeSearch => 'Chiudi la ricerca';

  @override
  String get librarySearchHint => 'Cerca nella libreria';

  @override
  String get genreMixTag => 'Suggerito';

  @override
  String get genreMixOffJam => 'Suggeriti spenti: Jam in corso';

  @override
  String get genreMixOffMetered => 'Suggeriti spenti: rete a consumo';

  @override
  String get genreMixOffOffline => 'Suggeriti spenti: nessuna rete';

  @override
  String get genreMixOffNoTool => 'Suggeriti spenti: strumento online assente';

  @override
  String get genreMixOffRateLimited => 'Suggeriti in pausa: troppe richieste';

  @override
  String get playerEmptyTitle => 'Niente in riproduzione';

  @override
  String get playerEmptyHint => 'Scegli da dove ripartire.';

  @override
  String get playerEmptyNoQueue => 'Scegli un brano per iniziare';

  @override
  String playerLastQueue(String name) {
    return 'Ultima coda: $name';
  }

  @override
  String get playerResumeLastQueue => 'Riprendi l\'ultima coda';

  @override
  String playerResumeLastQueueSub(String name, String tracks) {
    return '$name, $tracks';
  }

  @override
  String get playerShufflePlusLibrary => 'Shuffle+ della libreria';

  @override
  String get playerShufflePlusLibrarySub =>
      'Libreria in casuale con brani suggeriti';

  @override
  String get playerRecentlyAdded => 'Ultimi aggiunti';

  @override
  String get reviewSearch => 'Cerca';

  @override
  String get recogTitle => 'Da confermare';

  @override
  String recogSuggested(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count correzioni suggerite. Controllale una per una o accettale tutte.',
      one: '1 correzione suggerita',
    );
    return '$_temp0';
  }

  @override
  String recogAcceptAllCount(int count) {
    return 'Accetta tutte ($count)';
  }

  @override
  String recogAcceptedAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count correzioni accettate',
      one: '1 correzione accettata',
    );
    return '$_temp0. I file si aggiornano in sottofondo.';
  }

  @override
  String get recogNoProposalsHint => 'Non c\'è più niente da controllare.';

  @override
  String get logToday => 'Oggi';

  @override
  String get logYesterday => 'Ieri';

  @override
  String logDayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voci',
      one: '1 voce',
    );
    return '$_temp0';
  }

  @override
  String get logRetention => 'Il registro tiene gli ultimi 30 giorni.';

  @override
  String get logNoMatch => 'Nessuna voce con questo filtro.';

  @override
  String get logPickEntry => 'Scegli una voce per vedere i dettagli.';

  @override
  String get logFilterAll => 'Tutto';

  @override
  String get logFilterDownload => 'Download';

  @override
  String get logFilterLibrary => 'Libreria';

  @override
  String get logFilterEnrich => 'Arricchimento';

  @override
  String get logFilterCorrections => 'Correzioni';

  @override
  String get logFilterErrors => 'Errori';

  @override
  String get logFailedLabel => 'Non riuscito';

  @override
  String get logStoppedLabel => 'Fermato';

  @override
  String get logClearMenu => 'Pulisci registro';

  @override
  String get logClearTitle => 'Pulire il registro?';

  @override
  String get logClearConfirm => 'Pulisci';

  @override
  String get logPendingSub => 'Correzioni suggerite ai tuoi brani';

  @override
  String get logPendingReview => 'Rivedi';

  @override
  String logPendingMore(int count) {
    return 'e altre $count';
  }

  @override
  String get logHowTitle => 'Come risolvere';

  @override
  String get logTechTitle => 'Dettaglio tecnico';

  @override
  String get logOpenSongs => 'Vedi i brani';

  @override
  String logHowSettings(String settings, String page) {
    return 'Apri $settings, poi «$page».';
  }

  @override
  String logHowUpdate(String button) {
    return 'Tocca «$button» accanto a yt-dlp.';
  }

  @override
  String get logHowWait => 'Aspetta qualche minuto.';

  @override
  String get logHowOnline => 'Controlla di essere online.';

  @override
  String get logDlDone => 'Brano scaricato';

  @override
  String get logDlFailed => 'Download non riuscito';

  @override
  String logDlGroup(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani scaricati',
      one: '1 brano scaricato',
    );
    return '$_temp0';
  }

  @override
  String get logDlGroupShow => 'Mostra i brani';

  @override
  String get logDlGroupHide => 'Nascondi i brani';

  @override
  String get logTransferDone => 'Brani inviati';

  @override
  String get logTransferFailed => 'Invio non riuscito';

  @override
  String get logScanDone => 'Libreria aggiornata';

  @override
  String get logScanDoneSub => 'Controllate tutte le cartelle.';

  @override
  String get logScanStopped => 'Scansione fermata';

  @override
  String get logScanFailed => 'Scansione non riuscita';

  @override
  String get logStoppedSub => 'Si è fermato prima della fine.';

  @override
  String get logFailedSub => 'Si è fermato per un errore.';

  @override
  String get logEnrichDone => 'Arricchimento finito';

  @override
  String get logEnrichInterrupted => 'Arricchimento interrotto';

  @override
  String get logEnrichInterruptedSub =>
      'Si è fermato per un errore; il lavoro fatto è salvo.';

  @override
  String get logBgDone => 'Testi e copertine aggiunti';

  @override
  String get logBgDoneSub => 'Completamento in sottofondo.';

  @override
  String get logBgStopped => 'Completamento fermato';

  @override
  String get logBgStoppedSub => 'Nessuna fonte risponde in questo momento.';

  @override
  String get logBgFailed => 'Completamento non riuscito';

  @override
  String get logBgFailedSub => 'Un errore lo ha fermato.';

  @override
  String get logSecondOpinion => 'Secondo parere da YouTube Music';

  @override
  String get logSecondOpinionSub => 'Controllati i brani incerti.';

  @override
  String get logSecondOpinionFailed => 'Secondo parere interrotto';

  @override
  String get logCleanup => 'Doppioni cercati';

  @override
  String get logCleanupSub => 'Confrontati i brani della libreria.';

  @override
  String get logGenres => 'Generi dei brani riletti';

  @override
  String get logGenresSub =>
      'Letti i tag dei brani per trovare tutti i generi.';

  @override
  String get logCountries => 'Paesi degli artisti cercati';

  @override
  String get logCountriesSub =>
      'Cercato il paese d\'origine degli artisti della libreria.';

  @override
  String get logReleases => 'Nuove uscite controllate';

  @override
  String get logReleasesSub => 'Cercate le novità degli artisti che segui.';

  @override
  String get logPodcasts => 'Podcast aggiornati';

  @override
  String get logRadio => 'Radio controllate';

  @override
  String get logTaskFailed => 'Attività non riuscita';

  @override
  String logImportDone(String name) {
    return 'Playlist «$name» importata';
  }

  @override
  String logImportReady(String name) {
    return 'Playlist «$name» pronta';
  }

  @override
  String get logImportFailed => 'Importazione non riuscita';

  @override
  String get logImportRate => 'Importazione rallentata da YouTube';

  @override
  String get logImportPaused => 'Importazione in pausa';

  @override
  String get logWhyToolMissing =>
      'Manca il componente per scaricare da YouTube.';

  @override
  String get logWhyToolOld =>
      'Il componente per scaricare da YouTube è troppo vecchio.';

  @override
  String get logWhyNetwork => 'Rete non disponibile.';

  @override
  String get logWhyRate => 'YouTube ha chiesto di rallentare.';

  @override
  String get logWhyFailing => 'Troppi errori di fila: l’ho messa in pausa.';

  @override
  String get logCorrectionTitle => 'Titolo e artista corretti';

  @override
  String logChipSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani',
      one: '1 brano',
    );
    return '$_temp0';
  }

  @override
  String logChipArtists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artisti',
      one: '1 artista',
    );
    return '$_temp0';
  }

  @override
  String logChipSongsOf(int done, int total) {
    return '$done di $total brani';
  }

  @override
  String logChipUpdated(int count) {
    return '$count aggiornati';
  }

  @override
  String logChipNotFound(int count) {
    return '$count non trovati';
  }

  @override
  String logChipNoResult(int count) {
    return '$count senza risultato';
  }

  @override
  String get logFileTitle => 'Correzione salvata, file non aggiornato';

  @override
  String get logHowFileMissing =>
      'Controlla che il brano sia ancora nella sua cartella.';

  @override
  String get logHowFileReadOnly =>
      'Togli la sola lettura al file o alla sua cartella, poi correggi di nuovo il brano.';

  @override
  String get logHowFileRetry =>
      'Controlla che ci sia spazio sul disco e che il file non sia in uso, poi correggi di nuovo il brano.';

  @override
  String get logClearBody =>
      'Cancello tutte le voci e tolgo dalla lista i download finiti. Dopo non potrai più ripristinare le correzioni. I brani restano dove sono.';

  @override
  String logHowResume(String button) {
    return 'Tocca «$button» sull’importazione in pausa, nell’elenco delle attività.';
  }

  @override
  String get logEnrichStopped => 'Arricchimento fermato';

  @override
  String logCorrectionSem(String from, String to) {
    return 'Da $from a $to';
  }

  @override
  String get smartAll => 'Tutte le condizioni';

  @override
  String get smartAny => 'Almeno una';

  @override
  String get smartAllNote => 'I brani devono rispettare tutti i filtri.';

  @override
  String get smartAnyNote => 'Basta che un filtro sia rispettato.';

  @override
  String get smartAddFilter => 'Aggiungi filtro';

  @override
  String get smartGroupMusic => 'Musica';

  @override
  String get smartGroupListening => 'Ascolto';

  @override
  String get smartGroupFile => 'File';

  @override
  String get smartFieldTag => 'Tag';

  @override
  String get smartFieldAlbumArtist => 'Artista dell’album';

  @override
  String get smartFieldCountry => 'Nazionalità';

  @override
  String get smartFieldPlays => 'Ascolti';

  @override
  String get smartFieldLastPlayed => 'Ultimo ascolto';

  @override
  String get smartFieldAdded => 'Aggiunto';

  @override
  String get smartFieldBitrate => 'Bitrate';

  @override
  String get smartFieldFolder => 'Cartella';

  @override
  String get smartFlagLyrics => 'Con testo';

  @override
  String get smartEnrichedOnly => 'Solo per i brani arricchiti';

  @override
  String get smartInclude => 'Includi';

  @override
  String get smartExclude => 'Escludi';

  @override
  String get smartPickValues => 'Scegli i valori';

  @override
  String get smartAddValue => 'Aggiungi';

  @override
  String get smartValueHint => 'Scrivi un valore';

  @override
  String get smartDone => 'Fatto';

  @override
  String get smartIncomplete =>
      'Incompleto: completalo o rimuovilo per salvare.';

  @override
  String get smartRemoveFilter => 'Rimuovi filtro';

  @override
  String smartRemoveValue(String value) {
    return 'Rimuovi $value';
  }

  @override
  String get smartFrom => 'Da';

  @override
  String get smartTo => 'A';

  @override
  String get smartMoreThan => 'Più di';

  @override
  String get smartLessThan => 'Meno di';

  @override
  String get smartEqualTo => 'Uguale a';

  @override
  String get smartAgeRecent => 'Negli ultimi';

  @override
  String get smartAgeOlder => 'Da più di';

  @override
  String get smartDays => 'giorni';

  @override
  String get smartMinutes => 'minuti';

  @override
  String get smartContains => 'Contiene';

  @override
  String get smartAdvancedNote => 'Il testo della regola, in sola lettura.';

  @override
  String get smartNotVisual =>
      'Questa regola è troppo articolata per l’editor a filtri. Resta com’è: la vedi in Avanzate e, se la salvi senza toccarla, non cambia.';

  @override
  String get smartNoFilters => 'Aggiungi un filtro per iniziare.';

  @override
  String get smartLimitShort => 'Limite';

  @override
  String get smartIs => 'È';

  @override
  String get smartRestart => 'Ricomincia con i filtri';

  @override
  String get smartRestarted => 'Regola azzerata';

  @override
  String get smartCountError => 'Conteggio non disponibile';

  @override
  String artistMergedNote(int count) {
    return '$count profili uniti';
  }

  @override
  String get artistSplit => 'Separa profili';

  @override
  String get artistMergeWith => 'Unisci con…';

  @override
  String artistSameWarn(String name) {
    return 'Sembra lo stesso artista di un altro profilo ($name).';
  }

  @override
  String get artistMergeYes => 'Unisci';

  @override
  String get artistNotSame => 'Sono diversi';

  @override
  String get artistMerged => 'Profili uniti.';

  @override
  String get artistSplitDone => 'Profili separati.';

  @override
  String get artistNotSameDone =>
      'Va bene, non lo chiederò più per questi due profili.';

  @override
  String get artistMergePick => 'Con quale profilo?';

  @override
  String get mergedSheetTitle => 'Profili uniti';

  @override
  String get artistMainProfile => 'Principale';

  @override
  String artistOtherProfileOf(String name) {
    return 'Altro profilo di $name';
  }

  @override
  String get artistSeparate => 'Separa';

  @override
  String get artistSeparated => 'Profilo separato.';

  @override
  String get settingsMergedArtists => 'Artisti uniti';

  @override
  String get settingsMergedArtistsHint =>
      'Vedi i profili uniti e separali, o togli i «diversi».';

  @override
  String get mergedArtistsEmpty => 'Nessun artista unito.';

  @override
  String get mergedArtistsEmptyHelp =>
      'Quando unisci due profili dello stesso artista, compaiono qui.';

  @override
  String get mergedArtistsSplitAll => 'Separa tutto';

  @override
  String get notSameTitle => 'Segnati come diversi';

  @override
  String get notSameRemove => 'Rimuovi';

  @override
  String get notSameEmpty => 'Nessuna coppia segnata come diversa.';

  @override
  String get openArtistPage => 'Apri la pagina dell’artista';

  @override
  String get podcastYours => 'I tuoi podcast';

  @override
  String get podcastDiscover => 'Scopri';

  @override
  String get podcastChartTitle => 'Classifica italiana di Apple Podcasts';

  @override
  String get podcastGenreAll => 'Tutti';

  @override
  String get podcastSearchLens => 'Cerca podcast';

  @override
  String get podcastSubscribedLabel => 'Iscritto';

  @override
  String get podcastOriginApple => 'Apple Podcasts';

  @override
  String get podcastChartError =>
      'La classifica non risponde. Succede, non è colpa tua.';

  @override
  String get podcastNoFeed => 'Apple non ha un feed per questo podcast.';

  @override
  String get podcastGenreArts => 'Arti';

  @override
  String get podcastGenreBusiness => 'Economia';

  @override
  String get podcastGenreComedy => 'Comicità';

  @override
  String get podcastGenreEducation => 'Educazione';

  @override
  String get podcastGenreKids => 'Bambini e famiglia';

  @override
  String get podcastGenreHealth => 'Salute e benessere';

  @override
  String get podcastGenreTvFilm => 'TV e cinema';

  @override
  String get podcastGenreMusic => 'Musica';

  @override
  String get podcastGenreNews => 'Notizie';

  @override
  String get podcastGenreReligion => 'Religione e spiritualità';

  @override
  String get podcastGenreScience => 'Scienza';

  @override
  String get podcastGenreSports => 'Sport';

  @override
  String get podcastGenreTechnology => 'Tecnologia';

  @override
  String get podcastGenreSociety => 'Società e cultura';

  @override
  String get podcastGenreGovernment => 'Governo';

  @override
  String get podcastGenreHistory => 'Storia';

  @override
  String get podcastGenreTrueCrime => 'True crime';

  @override
  String podcastSubscribeTo(String name) {
    return 'Iscriviti a $name';
  }
}
