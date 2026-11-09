// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'Codecore';

  @override
  String get chooseFolder => 'Choisir un dossier';

  @override
  String get scan => 'Analyser';

  @override
  String get noTracks =>
      'Aucun titre. Choisissez un dossier et lancez l’analyse.';

  @override
  String get openSettings => 'Ouvrir les paramètres';

  @override
  String get permissionDenied => 'Autorisation de lecture audio refusée';

  @override
  String get permissionExplain =>
      'Codecore a besoin de l’autorisation de lire les fichiers audio pour afficher votre musique.';

  @override
  String get navLibrary => 'Bibliothèque';

  @override
  String get navFavorites => 'Favoris';

  @override
  String get navPlaylists => 'Playlists';

  @override
  String get navSettings => 'Paramètres';

  @override
  String get tracks => 'Titres';

  @override
  String get albums => 'Albums';

  @override
  String get artists => 'Artistes';

  @override
  String get searchHint => 'Rechercher';

  @override
  String get clearSearch => 'Effacer la recherche';

  @override
  String get sortBy => 'Trier par';

  @override
  String get addMusicFolder => 'Ajoutez votre dossier de musique';

  @override
  String get addFolder => 'Ajouter un dossier';

  @override
  String get folders => 'Dossiers de musique';

  @override
  String get refreshLibrary => 'Actualiser la bibliothèque';

  @override
  String get removeFolder => 'Retirer le dossier';

  @override
  String get unknownArtist => 'Artiste inconnu';

  @override
  String get unknownAlbum => 'Album inconnu';

  @override
  String get variousArtists => 'Artistes divers';

  @override
  String get play => 'Lire';

  @override
  String get shuffle => 'Aléatoire';

  @override
  String get queue => 'File d’attente';

  @override
  String get nowPlaying => 'Lecture en cours';

  @override
  String get nothingPlaying => 'Aucun titre en cours de lecture';

  @override
  String get mute => 'Muet';

  @override
  String get scanning => 'Analyse en cours…';

  @override
  String get emptyQueue => 'La file d’attente est vide';

  @override
  String get noResults => 'Aucun résultat';

  @override
  String get sortDefault => 'Par défaut';

  @override
  String get sortPersonal => 'Ordre personnel';

  @override
  String get sortTitle => 'Titre';

  @override
  String get sortArtist => 'Artiste';

  @override
  String get sortAlbum => 'Album';

  @override
  String get sortYear => 'Année';

  @override
  String get sortAdded => 'Ajoutés récemment';

  @override
  String get sortDuration => 'Durée';

  @override
  String tracksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres',
      one: '1 titre',
      zero: '0 titre',
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
      zero: '0 album',
    );
    return '$_temp0';
  }

  @override
  String get libraryAll => 'Tout';

  @override
  String libraryItemsCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString éléments',
      one: '1 élément',
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
      other: '$countString artistes',
      one: '1 artiste',
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
      other: '$n heures',
      one: '1 heure',
    );
    return '$_temp0';
  }

  @override
  String hoursAndMinutes(String hours, String minutes) {
    return '$hours et $minutes';
  }

  @override
  String get collectionNoTracks => 'Aucun titre';

  @override
  String missingTracksCount(int count) {
    return 'Titres introuvables ($count)';
  }

  @override
  String get addedToFavorites => 'Ajouté aux favoris';

  @override
  String get removedFromFavorites => 'Retiré des favoris';

  @override
  String get undo => 'Annuler';

  @override
  String get favoritesEmptyTitle => 'Aucun favori pour l’instant';

  @override
  String get favoritesEmptyHelp =>
      'Touchez le cœur sur un titre et il apparaîtra ici.';

  @override
  String get openAllTracks => 'Ouvrir tous les titres';

  @override
  String get newPlaylist => 'Nouvelle playlist';

  @override
  String get newPlaylistEllipsis => 'Nouvelle playlist…';

  @override
  String get playlistName => 'Nom de la playlist';

  @override
  String get create => 'Créer';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get delete => 'Supprimer';

  @override
  String get rename => 'Renommer';

  @override
  String get noPlaylists => 'Aucune playlist. Créez-en une.';

  @override
  String get addToPlaylist => 'Ajouter à une playlist…';

  @override
  String addedToPlaylist(String name) {
    return 'Ajouté à « $name »';
  }

  @override
  String get playNext => 'Lire ensuite';

  @override
  String get addToQueue => 'Ajouter à la file d’attente';

  @override
  String get addedToQueue => 'Ajouté à la file d’attente';

  @override
  String get favorite => 'Favori';

  @override
  String get removeFromFavorites => 'Retirer des favoris';

  @override
  String get removeFromList => 'Retirer';

  @override
  String get editInfo => 'Modifier les infos';

  @override
  String get details => 'Détails';

  @override
  String get showInFolder => 'Afficher dans le dossier';

  @override
  String get detailPath => 'Chemin';

  @override
  String get detailFormat => 'Format';

  @override
  String get detailSize => 'Taille';

  @override
  String get detailDuration => 'Durée';

  @override
  String get detailAdded => 'Ajouté le';

  @override
  String get detailPlays => 'Lectures';

  @override
  String get close => 'Fermer';

  @override
  String get fieldTitle => 'Titre';

  @override
  String get fieldArtist => 'Artiste';

  @override
  String get fieldAlbum => 'Album';

  @override
  String get fieldAlbumArtist => 'Artiste de l’album';

  @override
  String get fieldYear => 'Année';

  @override
  String get fieldTrackNumber => 'Numéro de piste';

  @override
  String get fieldGenre => 'Genre';

  @override
  String get restoreFromFile => 'Restaurer depuis les tags du fichier';

  @override
  String get titleRequired => 'Le titre ne peut pas être vide';

  @override
  String get settingsAppearance => 'Apparence';

  @override
  String get settingsTheme => 'Thème';

  @override
  String get themeNotte => 'Nuit violette';

  @override
  String get themeOled => 'Noir pur';

  @override
  String get settingsTextSize => 'Taille du texte';

  @override
  String get textSmall => 'Petit';

  @override
  String get textNormal => 'Normal';

  @override
  String get textLarge => 'Grand';

  @override
  String get settingsCompact => 'Mode compact';

  @override
  String get settingsReducedMotion => 'Animations réduites';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsLibrary => 'Bibliothèque';

  @override
  String get rescanNow => 'Réanalyser maintenant';

  @override
  String get clearCoverCache => 'Vider le cache des pochettes';

  @override
  String get coverCacheCleared => 'Cache des pochettes vidé';

  @override
  String get settingsOnline => 'En ligne';

  @override
  String get settingsPageAppearance => 'Apparence et langue';

  @override
  String get settingsPagePlayback => 'Lecture';

  @override
  String get settingsPageLibrary => 'Bibliothèque';

  @override
  String get settingsPageOnline => 'En ligne et téléchargements';

  @override
  String get settingsPageNetwork => 'Réseau et appareils';

  @override
  String get settingsPageBackup => 'Sauvegarde';

  @override
  String get settingsPageAdvanced => 'Avancé et infos';

  @override
  String summaryLibrary(int folders, int tracks) {
    String _temp0 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: '$folders dossiers',
      one: '1 dossier',
    );
    String _temp1 = intl.Intl.pluralLogic(
      tracks,
      locale: localeName,
      other: '$tracks titres',
      one: '1 titre',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String summaryTrusted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count appareils de confiance',
      one: '1 appareil de confiance',
    );
    return '$_temp0';
  }

  @override
  String get summaryNormalizeOn => 'normalisation activée';

  @override
  String get summaryBackup => 'Exporter et restaurer la bibliothèque';

  @override
  String summaryCrossfade(int seconds) {
    return '$seconds s';
  }

  @override
  String get openPlaybackSettings => 'Ouvrir Lecture';

  @override
  String get autoEnrich => 'Enrichissement automatique';

  @override
  String get autoEnrichHint =>
      'Recherche en ligne les métadonnées et les pochettes des nouveaux titres';

  @override
  String get autoLyrics => 'Paroles automatiques';

  @override
  String get autoLyricsHint =>
      'Télécharge les paroles depuis LRCLIB pour les nouveaux titres';

  @override
  String get settingsAbout => 'À propos';

  @override
  String appVersion(String version) {
    return 'Version $version';
  }

  @override
  String get licenses => 'Licences';

  @override
  String get personalUse => 'Application à usage personnel';

  @override
  String get missingTracksTitle => 'Titres introuvables';

  @override
  String get removeFromLibrary => 'Retirer de la bibliothèque';

  @override
  String get ignore => 'Ignorer';

  @override
  String get confirmRemoveTitle => 'Retirer de la bibliothèque ?';

  @override
  String get confirmRemoveBody =>
      'Le fichier n’est pas modifié ; les favoris et playlists de ce titre seront perdus.';

  @override
  String get noMissingTracks => 'Aucun titre manquant';

  @override
  String get retry => 'Réessayer';

  @override
  String scanFailed(String error) {
    return 'Échec de l’analyse : $error';
  }

  @override
  String playbackError(String reason, String title) {
    return 'Impossible de lire « $title » : $reason';
  }

  @override
  String get reasonFileMissing => 'fichier introuvable';

  @override
  String get reasonUnplayable => 'fichier illisible';

  @override
  String get reasonNotInLibrary => 'titre absent de la bibliothèque';

  @override
  String get reasonOnlineUnavailable => 'titre en ligne non disponible';

  @override
  String get reasonEpisodeUnavailable =>
      'épisode non disponible, vérifie la connexion';

  @override
  String get reasonAgeRestricted =>
      'restreint aux mineurs, aucune piste audio trouvée';

  @override
  String get searchWeb => 'Rechercher des infos sur le web';

  @override
  String get enrichPreviewTitle => 'Aperçu des informations';

  @override
  String get currentValue => 'Actuel';

  @override
  String get proposedValue => 'Proposé';

  @override
  String get apply => 'Appliquer';

  @override
  String get nothingFound => 'Aucune information trouvée';

  @override
  String get userEditedLocked => 'Modifié par vous : ne sera pas écrasé';

  @override
  String get fieldCover => 'Pochette';

  @override
  String get fieldLyrics => 'Paroles';

  @override
  String get fieldCuriosity => 'Anecdotes';

  @override
  String get enrichAlbum => 'Enrichir l’album';

  @override
  String get enrichLibrary => 'Enrichir toute la bibliothèque';

  @override
  String enrichRunning(int done, int total) {
    return 'Enrichissement $done/$total';
  }

  @override
  String enrichResult(int notFound, int updated) {
    return '$updated mis à jour, $notFound introuvables';
  }

  @override
  String get enrichBusy => 'Un enrichissement est déjà en cours';

  @override
  String get enrichNothingToDo =>
      'Rien à compléter : il ne manque rien aux morceaux';

  @override
  String get serviceUnavailable => 'Service indisponible, réessayez plus tard';

  @override
  String get lyrics => 'Paroles';

  @override
  String get searchLyrics => 'Rechercher les paroles';

  @override
  String get noLyrics => 'Aucune parole disponible';

  @override
  String get lyricsNotFound => 'Paroles introuvables';

  @override
  String get copy => 'Copier';

  @override
  String get copied => 'Copié';

  @override
  String get sourceWikipedia => 'Source : Wikipédia (CC BY-SA)';

  @override
  String get youtube => 'YouTube';

  @override
  String get ytHint => 'Rechercher ou coller un lien';

  @override
  String get ytDownload => 'Télécharger';

  @override
  String get listenAction => 'Écouter';

  @override
  String get ytAlreadyInLibrary => 'Déjà dans la bibliothèque';

  @override
  String get ytNoResults => 'Aucun résultat';

  @override
  String get ytQueued => 'En attente';

  @override
  String get ytDownloading => 'Téléchargement en cours';

  @override
  String get ytDone => 'Terminé';

  @override
  String get ytFailed => 'Échec';

  @override
  String get ytCancelled => 'Annulé';

  @override
  String get ytClearCompleted => 'Effacer les terminés';

  @override
  String get ytCancel => 'Annuler le téléchargement';

  @override
  String get ytErrUnavailable => 'Vidéo indisponible (âge/région/privée)';

  @override
  String get ytErrNetwork => 'Réseau indisponible';

  @override
  String get ytErrChanged =>
      'YouTube a changé quelque chose : mettez à jour l’application ou le paquet';

  @override
  String get ytNoFolder => 'Ajoutez d’abord un dossier de musique';

  @override
  String get ytLegal =>
      'Usage personnel uniquement. Respectez les droits d’auteur et les conditions d’utilisation de YouTube.';

  @override
  String get useDefaultFolder => 'Utiliser le dossier Musique de l’appareil';

  @override
  String get ytErrToolMissing =>
      'yt-dlp introuvable : installez-le (pip install -U yt-dlp) puis réessayez';

  @override
  String get ytErrRateLimited =>
      'YouTube demande de ralentir : réessayez dans quelques minutes';

  @override
  String get playlistChangeCover => 'Changer la pochette';

  @override
  String get playlistRemoveCover => 'Retirer la pochette';

  @override
  String get coverTooLarge => 'Image trop volumineuse (max 4 MB)';

  @override
  String get addSongs => 'Ajouter des titres';

  @override
  String addNSongs(int count) {
    return 'Ajouter ($count)';
  }

  @override
  String get allSongsInPlaylist => 'Tous les titres sont déjà dans la playlist';

  @override
  String get shareTitle => 'Partage';

  @override
  String get shareSend => 'Envoyer';

  @override
  String get shareReceive => 'Recevoir';

  @override
  String get shareAll => 'Toute la bibliothèque';

  @override
  String shareSelection(int count) {
    return 'Sélection ($count titres)';
  }

  @override
  String get sharePick => 'Choisir des titres';

  @override
  String get shareStart => 'Démarrer le partage';

  @override
  String get shareStop => 'Arrêter';

  @override
  String get shareActive => 'Partage actif';

  @override
  String get shareAddress => 'Adresse (IP:port)';

  @override
  String get sharePin => 'PIN';

  @override
  String get shareConnect => 'Se connecter';

  @override
  String shareDownloadSelected(int count) {
    return 'Télécharger la sélection ($count)';
  }

  @override
  String shareProgress(int done, int total) {
    return 'Titre $done sur $total';
  }

  @override
  String shareDone(int count) {
    return '$count titres reçus';
  }

  @override
  String shareConnectedTo(String name) {
    return 'Connecté à $name';
  }

  @override
  String get shareErrUnreachable =>
      'Appareil injoignable : vérifiez l’adresse et le Wi‑Fi';

  @override
  String get shareErrPin => 'PIN incorrect';

  @override
  String get shareErrBlocked =>
      'Trop de tentatives : réessayez dans une minute';

  @override
  String get shareErrNotCodecore => 'Ce n’est pas un appareil Codecore';

  @override
  String get shareErrFailed => 'Échec du transfert';

  @override
  String get shareNoNetwork => 'Aucun réseau local trouvé';

  @override
  String get shareFirewall =>
      'Windows peut demander l’autorisation du pare-feu lors du premier partage.';

  @override
  String get shareHint =>
      'Sur le même Wi‑Fi, ouvrez « Recevoir » sur l’autre appareil et saisissez l’adresse et le PIN.';

  @override
  String get shareMenu => 'Partager…';

  @override
  String get shareDeviceName => 'Nom de l’appareil';

  @override
  String get sleepTimer => 'Minuteur d’arrêt';

  @override
  String sleepMinutes(int count) {
    return '$count minutes';
  }

  @override
  String get sleepEndOfTrack => 'À la fin du titre';

  @override
  String get sleepCancel => 'Annuler le minuteur';

  @override
  String get pause => 'Pause';

  @override
  String get nextTrack => 'Titre suivant';

  @override
  String get previousTrack => 'Titre précédent';

  @override
  String get repeat => 'Répéter';

  @override
  String get moreOptions => 'Plus d’options';

  @override
  String get back => 'Retour';

  @override
  String get seekPosition => 'Position dans le morceau';

  @override
  String get settingsPlayback => 'Lecture';

  @override
  String get normalizeVolume => 'Normaliser le volume';

  @override
  String get normalizeVolumeHint =>
      'Utilise le ReplayGain des fichiers pour atténuer les titres trop forts';

  @override
  String get nearbyDevices => 'Appareils à proximité';

  @override
  String get searchingDevices => 'Recherche d’appareils sur le réseau…';

  @override
  String get noDevicesHint =>
      'Aucun appareil trouvé. Ouvrez aussi Partage sur l’autre appareil, sur le même réseau.';

  @override
  String sendToDevice(String name) {
    return 'Envoyer à $name';
  }

  @override
  String offerSent(String name) {
    return 'Demande envoyée à $name';
  }

  @override
  String get offerChooseFirst => 'Choisissez d’abord les titres à envoyer';

  @override
  String get sentRequests => 'Demandes envoyées';

  @override
  String get receivedRequests => 'Demandes reçues';

  @override
  String get offerPending => 'En attente de réponse';

  @override
  String get offerAccepted => 'Acceptée';

  @override
  String get offerDeclined => 'Refusée';

  @override
  String get offerCancelled => 'Annulée';

  @override
  String get offerExpired => 'Expirée';

  @override
  String get offerDone => 'Terminée';

  @override
  String get offerFailed => 'Échec';

  @override
  String incomingTitle(String name) {
    return '$name souhaite vous envoyer des titres';
  }

  @override
  String incomingBody(int count, String size) {
    return '$count titres, $size MB';
  }

  @override
  String get accept => 'Accepter';

  @override
  String get decline => 'Refuser';

  @override
  String receivingProgress(int done, int total) {
    return 'Réception $done/$total';
  }

  @override
  String get manualConnection => 'Connexion manuelle (IP et PIN)';

  @override
  String get receiveFromLan => 'Recevoir depuis le réseau local';

  @override
  String get receiveFromLanHint =>
      'Rend l’appareil visible et reçoit les demandes même en arrière-plan. Sur Android, une notification permanente permet de le désactiver';

  @override
  String get receiveServiceTitle => 'Codecore est visible sur le réseau';

  @override
  String get receiveServiceText =>
      'Prêt à recevoir des titres des appareils à proximité';

  @override
  String get receiveServiceDisable => 'Désactiver';

  @override
  String get jamTitle => 'Jam';

  @override
  String get jamStart => 'Démarrer une Jam';

  @override
  String jamStartWith(String name) {
    return 'Démarrer une Jam avec $name';
  }

  @override
  String jamWaiting(String name) {
    return 'En attente de l’acceptation de $name…';
  }

  @override
  String jamDeclined(String name) {
    return '$name a refusé la Jam';
  }

  @override
  String jamBusy(String name) {
    return '$name a déjà une Jam en cours';
  }

  @override
  String get jamUnreachable => 'Appareil injoignable';

  @override
  String jamIncomingTitle(String name) {
    return '$name souhaite démarrer une Jam';
  }

  @override
  String get jamIncomingBody =>
      'Écoutez ensemble depuis une file d’attente partagée.';

  @override
  String get jamIncomingDialog =>
      'La musique est diffusée depuis cet appareil et vous pouvez tous les deux ajouter des titres.';

  @override
  String get jamQueue => 'File d’attente partagée';

  @override
  String get jamModeHost => 'File de l’hôte';

  @override
  String get jamModeTogether => 'File commune';

  @override
  String get jamModeGuestHint => 'L’hôte choisit le mode de la file';

  @override
  String get jamSuggested => 'Suggéré';

  @override
  String get jamEmpty =>
      'Ajoutez des titres à la file depuis la bibliothèque ou la recherche';

  @override
  String jamOnlineFailed(String title) {
    return 'Impossible d’ajouter « $title » à la Jam';
  }

  @override
  String jamAddedBy(String name) {
    return 'ajouté par $name';
  }

  @override
  String get jamJumpHere => 'Passer ici';

  @override
  String get jamYou => 'vous';

  @override
  String get jamGuest => 'Invité';

  @override
  String get jamAddToJam => 'Ajouter à la Jam';

  @override
  String jamAdded(int count) {
    return 'Ajoutés à la Jam : $count';
  }

  @override
  String get jamOutput => 'Sortie audio';

  @override
  String get jamOutputHere => 'Cet appareil';

  @override
  String jamOutputOther(String name) {
    return '$name';
  }

  @override
  String get jamEnd => 'Terminer la Jam';

  @override
  String get jamLeave => 'Quitter la Jam';

  @override
  String get jamEnded => 'La Jam est terminée';

  @override
  String get jamLost => 'Connexion perdue';

  @override
  String get jamGuestCannotSkip =>
      'Seul l’hôte de la Jam peut changer de titre';

  @override
  String get jamRemoveForbidden =>
      'Vous ne pouvez retirer que vos propres titres';

  @override
  String get jamNothingPlaying => 'Rien en cours de lecture';

  @override
  String jamWith(String name) {
    return 'Jam avec $name';
  }

  @override
  String get jamUnavailable => 'Indisponible';

  @override
  String get jamPlaying => 'La Jam est active';

  @override
  String get jamOpen => 'Ouvrir la Jam';

  @override
  String jamSynced(int ms) {
    return 'Synchronisé, décalage $ms ms';
  }

  @override
  String get jamSyncing => 'Synchronisation en cours…';

  @override
  String jamLatency(int ms) {
    return 'Latence de cette sortie : $ms ms';
  }

  @override
  String get jamLatencyHint =>
      'Pour casques ou enceintes Bluetooth : augmentez jusqu’à ce que les sorties soient synchronisées.';

  @override
  String get jamOutputsHint => 'Plusieurs sorties jouent en même temps';

  @override
  String get renamePlaylist => 'Renommer la playlist';

  @override
  String get confirmDeletePlaylistTitle => 'Supprimer la playlist ?';

  @override
  String confirmDeletePlaylistBody(String name) {
    return '« $name » sera supprimée. Les titres restent dans la bibliothèque.';
  }

  @override
  String get confirmRemoveFolderTitle => 'Retirer le dossier ?';

  @override
  String get confirmRemoveFolderBody =>
      'Ses titres disparaissent de la bibliothèque. Les fichiers restent sur l’appareil.';

  @override
  String get confirmClearCoversTitle => 'Vider le cache des pochettes ?';

  @override
  String get confirmClearCoversBody =>
      'Les pochettes seront recréées à la prochaine analyse.';

  @override
  String get confirmRestoreTitle => 'Restaurer depuis les tags du fichier ?';

  @override
  String get confirmRestoreBody =>
      'Vos modifications de ce titre seront remplacées par les données du fichier.';

  @override
  String get removedFromPlaylist => 'Retiré de la playlist';

  @override
  String get removedFromQueue => 'Retiré de la file d’attente';

  @override
  String get playNextDone => 'Sera lu ensuite';

  @override
  String get ytSearchPrompt => 'Recherchez un titre ou collez un lien';

  @override
  String get loadFailed => 'Impossible de charger les données.';

  @override
  String get artistLoadingSongs => 'Chargement des titres…';

  @override
  String get artistTopMissing => 'Top indisponible';

  @override
  String get navHome => 'Accueil';

  @override
  String get navSearch => 'Rechercher';

  @override
  String get devicesTitle => 'Appareils';

  @override
  String get devicesJamActive => 'Jam active';

  @override
  String jamPeople(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Jam, $n personnes',
      one: 'Jam, 1 personne',
    );
    return '$_temp0';
  }

  @override
  String get devicesVisibleTitle => 'Rendre cet appareil visible';

  @override
  String get devicesVisibleHint =>
      'Pour recevoir des titres ou lancer une Jam, les autres appareils doivent pouvoir vous voir sur le réseau.';

  @override
  String get devicesJamShort => 'Jam';

  @override
  String get devicesSendShort => 'Envoyer';

  @override
  String get devicesMore => 'Partage et connexion manuelle';

  @override
  String jamParticipantsCount(int n) {
    return '$n personnes';
  }

  @override
  String get playingFrom => 'Lecture depuis';

  @override
  String get playContextSearch => 'Recherche';

  @override
  String get allTracks => 'Tous les titres';

  @override
  String get trackInfo => 'Infos sur le titre';

  @override
  String get searchCuriosity => 'Rechercher des anecdotes';

  @override
  String get upNext => 'À suivre';

  @override
  String get openQueue => 'Ouvrir la file d’attente';

  @override
  String get copyLink => 'Copier le lien';

  @override
  String get moreActions => 'Autres actions';

  @override
  String get sleepChipEnd => 'fin du titre';

  @override
  String get yourLibrary => 'Votre bibliothèque';

  @override
  String playlistCountLabel(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Playlist de $n titres',
      one: 'Playlist de 1 titre',
      zero: 'Playlist de 0 titre',
    );
    return '$_temp0';
  }

  @override
  String get sortRecent => 'Écoutés récemment';

  @override
  String get sortAlphabetical => 'Alphabétique';

  @override
  String get sortAToZ => 'A–Z';

  @override
  String get sortAddedRecently => 'Ajoutés récemment';

  @override
  String get sortTitleAToZ => 'Titre A–Z';

  @override
  String get sortMostPlayed => 'Les plus écoutés';

  @override
  String get sortTrackCount => 'Nombre de titres';

  @override
  String get sortRecentShort => 'Récents';

  @override
  String get sortAddedShort => 'Ajoutés';

  @override
  String get sortTrackCountShort => 'Titres';

  @override
  String get sortMostPlayedShort => 'Plus écoutés';

  @override
  String get sortAscending => 'Croissant';

  @override
  String get sortDescending => 'Décroissant';

  @override
  String get viewAsGrid => 'Afficher en grille';

  @override
  String get viewAsList => 'Afficher en liste';

  @override
  String get kindAlbum => 'Album';

  @override
  String get kindArtist => 'Artiste';

  @override
  String get kindPlaylist => 'Playlist';

  @override
  String discN(int n) {
    return 'Disque $n';
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
  String get mostPlayed => 'Les plus écoutés';

  @override
  String get albumsSection => 'Albums';

  @override
  String get addAllToQueue => 'Ajouter à la file d’attente';

  @override
  String addedNToQueue(int n) {
    return '$n titres ajoutés à la file d’attente';
  }

  @override
  String get editOrder => 'Modifier l’ordre';

  @override
  String get finishEditing => 'Terminé';

  @override
  String get removeFromPlaylistAction => 'Retirer de la playlist';

  @override
  String get noTracksInPlaylist => 'Cette playlist est vide';

  @override
  String get greetingMorning => 'Bonjour';

  @override
  String get greetingAfternoon => 'Bon après-midi';

  @override
  String get greetingEvening => 'Bonsoir';

  @override
  String get homeResume => 'Reprendre';

  @override
  String get homeTopTracks => 'Les plus écoutés';

  @override
  String get homeRediscover => 'À redécouvrir';

  @override
  String get homeShuffleAll => 'Tout en aléatoire';

  @override
  String homeShuffleAllSub(String tracks, String hours) {
    return '$tracks, $hours';
  }

  @override
  String hoursCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count heures',
      one: '1 heure',
      zero: 'moins d’une heure',
    );
    return '$_temp0';
  }

  @override
  String get homeAddedLately => 'Ajoutés depuis peu';

  @override
  String homeResumeQueue(int n, int m) {
    return 'Titre $n sur $m';
  }

  @override
  String homeResumeQueueFrom(String source, int n, int m) {
    return '$source : titre $n sur $m';
  }

  @override
  String homeMinutesLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Il reste $count minutes',
      one: 'Il reste 1 minute',
    );
    return '$_temp0';
  }

  @override
  String homeEpisodeLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il reste $count min',
      one: 'il reste 1 min',
    );
    return '$_temp0';
  }

  @override
  String get homeFanOpen => 'Afficher les titres ajoutés récemment';

  @override
  String get showAll => 'Tout';

  @override
  String get recentSearches => 'Recherches récentes';

  @override
  String get genresTitle => 'Genres';

  @override
  String downloadsChip(int n) {
    return 'Téléchargements ($n)';
  }

  @override
  String get gotIt => 'Compris';

  @override
  String get searchEmptyLibrary => 'Aucun résultat dans la bibliothèque';

  @override
  String get ytInfoTooltip => 'Informations sur l’utilisation';

  @override
  String removeRecentSearch(String query) {
    return 'Retirer « $query » des recherches récentes';
  }

  @override
  String get groupGoTo => 'Aller à';

  @override
  String get goToAlbum => 'Aller à l’album';

  @override
  String get goToArtist => 'Aller à l’artiste';

  @override
  String get groupQueue => 'File d’attente';

  @override
  String get groupCollection => 'Collection';

  @override
  String get groupEdit => 'Modifier';

  @override
  String get groupOther => 'Autre';

  @override
  String get queueNowPlaying => 'Lecture en cours';

  @override
  String get queueNext => 'À suivre';

  @override
  String get queueClear => 'Vider';

  @override
  String get queueCleared => 'File d’attente vidée';

  @override
  String get queueRebuilt =>
      'File d’attente recréée depuis la liste en lecture';

  @override
  String get jamOutputsAndSync => 'Sorties et synchro';

  @override
  String get jamHostTag => 'hôte';

  @override
  String get jamSeekInvalid => 'Position non valide pour ce titre';

  @override
  String get jamEndConfirmTitle => 'Terminer la Jam pour tous ?';

  @override
  String jamEndConfirmBody(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other:
          'Les $n invités seront déconnectés et la file partagée sera fermée.',
      one: 'L’invité sera déconnecté et la file partagée sera fermée.',
    );
    return '$_temp0';
  }

  @override
  String get jamEndConfirmAction => 'Terminer';

  @override
  String jamParticipantsLabel(int n, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n participants : $names',
      one: '1 participant : $names',
    );
    return '$_temp0';
  }

  @override
  String get jamWaitingEmpty => 'Aucune Jam en cours';

  @override
  String get activityTitle => 'Activité';

  @override
  String activityScan(int done, int total) {
    return 'Analyse : $done sur $total';
  }

  @override
  String get activityScanIdle => 'Analyse en cours';

  @override
  String activityEnrich(int done, int total) {
    return 'Enrichissement : $done sur $total';
  }

  @override
  String activityDownload(String title) {
    return 'Téléchargement, $title';
  }

  @override
  String activityTransfer(String name, int n) {
    return 'Envoi à $name, $n titres';
  }

  @override
  String get activityNone => 'Aucune activité';

  @override
  String get activityCompleted => 'Terminées';

  @override
  String get importPhaseSearching => 'Recherche…';

  @override
  String importPhaseDownloading(int percent) {
    return 'Téléchargement $percent %';
  }

  @override
  String importPhaseRetry(int seconds) {
    return 'Nouvel essai dans $seconds s';
  }

  @override
  String get importPhaseEnriching => 'Enrichissement…';

  @override
  String get importPhaseDownloadStart => 'Téléchargement…';

  @override
  String get importFilterAll => 'Tous';

  @override
  String get importFilterActive => 'En cours';

  @override
  String get importFilterProblems => 'À régler';

  @override
  String get importFilterDone => 'Faits';

  @override
  String get importRowsNone => 'Aucun titre ici';

  @override
  String get activityLog => 'Journal';

  @override
  String activityLogCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count événements',
      one: '1 événement',
      zero: 'Vide',
    );
    return '$_temp0';
  }

  @override
  String get activityLogEmpty =>
      'Rien pour l’instant : les téléchargements, imports et envois terminés apparaissent ici.';

  @override
  String logImport(String name) {
    return 'Import «$name»';
  }

  @override
  String importNotificationText(int done, int total) {
    return '$done sur $total';
  }

  @override
  String importNotificationPaused(int done, int total) {
    return 'En pause, $done sur $total';
  }

  @override
  String importWaitRateLimited(String time) {
    return 'YouTube demande une pause : reprise à $time';
  }

  @override
  String importWaitNetwork(String time) {
    return 'Pas de réseau : nouvel essai à $time';
  }

  @override
  String importPausedTitle(String name) {
    return 'Importation « $name » en pause';
  }

  @override
  String get downloadsNotificationTitle => 'Téléchargements en cours';

  @override
  String downloadsNotificationText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres',
      one: '1 titre',
    );
    return '$_temp0';
  }

  @override
  String activityRunning(int n) {
    return '$n activités en cours';
  }

  @override
  String get settingsLocalNetwork => 'Réseau local';

  @override
  String get removeAll => 'Tout retirer';

  @override
  String get confirmRemoveAllTitle => 'Tout retirer de la bibliothèque ?';

  @override
  String confirmRemoveAllBody(int n) {
    return '$n titres introuvables seront retirés de la bibliothèque. Les fichiers ne sont pas modifiés ; les favoris et playlists de ces titres seront perdus.';
  }

  @override
  String get csvImportMenu => 'Importer depuis Exportify (CSV)';

  @override
  String get csvImportIntroTitle => 'Importer une playlist';

  @override
  String get csvImportIntroSource =>
      'Le fichier CSV se crée gratuitement sur le site Exportify — exportify.net (aucune application nécessaire).';

  @override
  String get csvImportStep1 =>
      'Ouvrez https://exportify.net dans le navigateur (même depuis le téléphone).';

  @override
  String get csvImportStep2 =>
      'Appuyez sur « Get Started » et connectez-vous avec votre compte Spotify.';

  @override
  String get csvImportStep3 =>
      'À côté de la playlist souhaitée, appuyez sur « Export » : un fichier .csv portant le nom de la playlist est téléchargé.';

  @override
  String get csvImportStep4 =>
      'Revenez ici et appuyez sur « Choisir un fichier CSV ».';

  @override
  String get csvImportNote =>
      'Codecore recherche les titres dans votre bibliothèque et télécharge les autres depuis YouTube Music.';

  @override
  String get csvImportNoteOffline =>
      'Seuls les titres déjà présents dans votre bibliothèque seront liés.';

  @override
  String get csvImportCopy => 'Copier l’adresse';

  @override
  String get csvImportCopied => 'Adresse copiée';

  @override
  String get csvImportPick => 'Choisir un fichier';

  @override
  String get csvImportNotExportify =>
      'Format non reconnu. Choisissez un CSV (Exportify, TuneMyMusic, Soundiiz, Last.fm) ou une playlist M3U/M3U8/XSPF.';

  @override
  String get csvImportReadFailed => 'Impossible de lire le fichier.';

  @override
  String get csvImportPreviewTitle => 'Importer la playlist';

  @override
  String get csvImportName => 'Nom de la playlist';

  @override
  String csvImportSummary(int total, int known, int todo) {
    return '$total titres, $known déjà dans la bibliothèque, $todo à télécharger';
  }

  @override
  String csvImportSkipped(int n) {
    return '$n lignes ignorées (podcasts ou fichiers locaux)';
  }

  @override
  String csvImportEstimate(int minutes) {
    return 'Durée estimée : environ $minutes min';
  }

  @override
  String get csvImportExists => 'Une playlist portant ce nom existe déjà';

  @override
  String get csvImportUpdate =>
      'Mettre à jour l’existante (n’ajoute que les nouveaux titres)';

  @override
  String get csvImportNew => 'Créer une nouvelle playlist';

  @override
  String get csvImportGo => 'Importer';

  @override
  String get csvImportStarted =>
      'Importation lancée : suivez-la dans le Centre d’activité';

  @override
  String activityImport(String name, int done, int total) {
    return 'Importation « $name » : $done sur $total';
  }

  @override
  String activityImportPaused(String name, int done, int total) {
    return 'Importation « $name » : en pause, $done sur $total';
  }

  @override
  String csvImportBanner(int done, int total, int review, int missing) {
    return 'Importation : $done sur $total, $review à vérifier, $missing introuvables';
  }

  @override
  String csvImportBannerPaused(int done, int total, int review, int missing) {
    return 'Importation en pause : $done sur $total, $review à vérifier, $missing introuvables';
  }

  @override
  String get csvImportReview => 'Revoir';

  @override
  String get csvImportResume => 'Reprendre';

  @override
  String get csvImportPause => 'Pause';

  @override
  String get csvImportCancelTitle => 'Annuler l’importation ?';

  @override
  String get csvImportCancelBody =>
      'Les titres déjà téléchargés restent dans la playlist.';

  @override
  String csvImportDone(int added, int review, int missing) {
    return 'Importation terminée : $added ajoutés, $review à vérifier, $missing introuvables';
  }

  @override
  String get csvImportFailing =>
      'Trop d’erreurs consécutives : importation en pause';

  @override
  String get csvImportReviewTitle => 'Revoir';

  @override
  String get csvImportToReview => 'À vérifier';

  @override
  String get csvImportNotFound => 'Introuvables';

  @override
  String get csvImportErrors => 'Avec erreurs';

  @override
  String get csvImportRetryAll => 'Tout réessayer';

  @override
  String get csvImportSkip => 'Passer';

  @override
  String get csvImportManual => 'Rechercher manuellement';

  @override
  String get csvImportNothing => 'Rien à revoir.';

  @override
  String get csvImportSearch => 'Rechercher';

  @override
  String csvImportWanted(String title, String artist, String duration) {
    return 'Recherché : $title, $artist, $duration';
  }

  @override
  String get csvImportDownload => 'Télécharger';

  @override
  String get csvImportCancelGo => 'Annuler l’importation';

  @override
  String get exportLog => 'Exporter le journal';

  @override
  String get exportLogHint =>
      'Fichier texte sans chemins personnels, adresses réseau ni PIN';

  @override
  String get exportLogDebugOnly =>
      'Disponible uniquement dans la version installée (en debug, le journal n’est pas écrit dans un fichier)';

  @override
  String get exportLogNone => 'Aucun journal à exporter pour l’instant';

  @override
  String get exportLogSaved => 'Journal enregistré';

  @override
  String get exportLogFailed => 'Impossible d’enregistrer le journal';

  @override
  String get exportPlaylist => 'Exporter…';

  @override
  String get exportPlaylistTitle => 'Exporter la playlist';

  @override
  String get exportFormatM3u8 => 'M3U8, pour d’autres lecteurs';

  @override
  String get exportFormatCsv => 'CSV, comme Exportify';

  @override
  String get exportFormatJson => 'JSON, format Codecore';

  @override
  String get exportRelativePaths => 'Chemins relatifs';

  @override
  String get exportRelativeHint =>
      'Relatifs au dossier commun des titres : enregistrez-y le fichier';

  @override
  String get exportAction => 'Exporter';

  @override
  String get exportSaved => 'Playlist exportée';

  @override
  String get exportEmpty => 'La playlist est vide';

  @override
  String get exportFailed => 'Impossible d’exporter la playlist';

  @override
  String get ytErrToolOutdated =>
      'yt-dlp est trop ancien : mettez-le à jour (Paramètres, En ligne et téléchargements, Mettre à jour) et réessayez';

  @override
  String ytDlpOutdatedBanner(String version) {
    return 'yt-dlp $version est trop ancien : les téléchargements pourraient ne pas fonctionner';
  }

  @override
  String get settingsDownloads => 'Téléchargements';

  @override
  String ytDlpVersion(String version) {
    return 'yt-dlp $version';
  }

  @override
  String get ytDlpUnknownVersion => 'yt-dlp introuvable';

  @override
  String get ytDlpUpdate => 'Mettre à jour';

  @override
  String ytDlpUpdating(int percent) {
    return 'Mise à jour… $percent %';
  }

  @override
  String ytDlpUpdated(String version) {
    return 'Mis à jour vers la version $version';
  }

  @override
  String get ytDlpTooOld => 'Trop ancien : appuyez sur Mettre à jour';

  @override
  String get ytDlpUpdateErrNetwork =>
      'Échec de la mise à jour : réseau injoignable';

  @override
  String get ytDlpUpdateErrHash =>
      'Mise à jour annulée : le fichier téléchargé n’a pas réussi la vérification d’intégrité';

  @override
  String get ytDlpUpdateErrOther =>
      'Échec de la mise à jour (détails dans le journal)';

  @override
  String get downloadParallel => 'Téléchargements simultanés';

  @override
  String get downloadParallelHint =>
      'Plus à la fois, c’est plus rapide, mais YouTube peut demander de ralentir';

  @override
  String get downloadRateLimit => 'Limite de vitesse';

  @override
  String get downloadRateNone => 'Aucune';

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
    return 'Téléchargement, $title, nouvelle tentative dans $seconds s ($attempt/$max)';
  }

  @override
  String get downloadFormat => 'Format des téléchargements';

  @override
  String get downloadFormatOriginal => 'Original (meilleure qualité)';

  @override
  String get downloadFormatOriginalHint =>
      'L’audio de YouTube sans réencodage, souvent Opus ~160 kbps. Tous les lecteurs et autoradios ne le lisent pas.';

  @override
  String get downloadFormatM4a => 'M4A (recommandé)';

  @override
  String get downloadFormatM4aHint =>
      'Presque comme l’original, sans réencodage : rapide, léger (~1 Mo/min), se lit partout.';

  @override
  String get downloadFormatMp3High => 'MP3 320 kbps';

  @override
  String get downloadFormatMp3HighHint =>
      'Se lit partout. Réencodé : légère perte, gros fichiers (~2,4 Mo/min), téléchargement plus lent.';

  @override
  String get downloadFormatMp3Low => 'MP3 192 kbps (qualité minimale)';

  @override
  String get downloadFormatMp3LowHint =>
      'Se lit partout, moitié moins lourd que le MP3 320 (~1,4 Mo/min), mais la qualité la plus basse.';

  @override
  String get searchCacheClear => 'Vider le cache des recherches';

  @override
  String searchCacheCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recherches enregistrées',
      one: '1 recherche enregistrée',
      zero: 'Vide',
    );
    return '$_temp0';
  }

  @override
  String get searchCacheCleared => 'Cache vidé';

  @override
  String csvImportLengthOff(String found, String wanted) {
    return 'Durée différente : $found au lieu de $wanted';
  }

  @override
  String get csvImportKeep => 'Garder celui-ci';

  @override
  String get csvImportTooBig =>
      'Le fichier est trop volumineux pour une playlist (5 MB et 10 000 titres maximum)';

  @override
  String get csvImportAlsoAccepts =>
      'Également acceptés : TuneMyMusic, Soundiiz, Last.fm (CSV), M3U/M3U8, XSPF.';

  @override
  String get csvImportPlanned =>
      'Correspondances prêtes : vérifiez-les et téléchargez';

  @override
  String get csvImportLinkOnly => 'Lier uniquement (aucun téléchargement)';

  @override
  String get csvImportLinkOnlyHint =>
      'Crée la playlist avec ce que vous avez déjà, sans plus';

  @override
  String get csvImportPlanFirst => 'Vérifier avant de télécharger';

  @override
  String get csvImportPlanFirstHint =>
      'Recherche tout, puis vous choisissez quoi télécharger';

  @override
  String get csvImportPlanTitle => 'Correspondances';

  @override
  String csvImportPlanGo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Télécharger $n titres',
      one: 'Télécharger 1 titre',
      zero: 'Télécharger 0 titre',
    );
    return '$_temp0';
  }

  @override
  String get csvImportPlanKnown => 'déjà téléchargé';

  @override
  String get csvImportPlanEmpty => 'Rien à télécharger';

  @override
  String csvImportBannerPlanned(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n titres à télécharger',
      one: '1 titre à télécharger',
      zero: '0 titre à télécharger',
    );
    return 'Correspondances prêtes : $_temp0';
  }

  @override
  String get settingsAdvanced => 'Avancé';

  @override
  String get importSureThreshold => 'Correspondance sûre à partir de';

  @override
  String get importSureThresholdHint =>
      'Au-dessus de ce score, un titre importé est téléchargé sans demander';

  @override
  String get importReviewThreshold => 'À vérifier à partir de';

  @override
  String get importReviewThresholdHint =>
      'Entre ce score et le score sûr, le titre va dans « À vérifier » ; en dessous, dans « Introuvables »';

  @override
  String get importThresholdsReset => 'Rétablir les valeurs par défaut';

  @override
  String csvImportEstimateHours(int hours, int minutes) {
    return 'Durée estimée : environ $hours h $minutes min';
  }

  @override
  String csvImportBlocks(int size) {
    return 'Importer par blocs de $size';
  }

  @override
  String csvImportBigWarning(int n) {
    return '$n titres à télécharger : cela prendra des heures. Par blocs, l’un après l’autre, l’ordre de la playlist reste correct et vous pouvez vous arrêter entre deux blocs.';
  }

  @override
  String get etaLessThanMinute => 'moins de 1 min';

  @override
  String etaMinutes(int minutes) {
    return 'environ $minutes min';
  }

  @override
  String etaHours(int hours, int minutes) {
    return 'environ $hours h $minutes min';
  }

  @override
  String get csvImportOwnFolder => 'Dossier pour cette playlist';

  @override
  String get csvImportOwnFolderHint =>
      'Enregistre les titres téléchargés dans un sous-dossier portant le nom de la playlist';

  @override
  String get csvImportNumberFiles => 'Numéroter les fichiers';

  @override
  String get csvImportNumberFilesHint =>
      '07 - Artiste - Titre : le dossier se lit dans le bon ordre, même en dehors de Codecore';

  @override
  String get csvImportFetchCovers => 'Rechercher les pochettes';

  @override
  String get csvImportFetchCoversHint =>
      'Après chaque téléchargement, recherche la pochette de l’album sur iTunes (album et artiste du fichier)';

  @override
  String get csvImportExport => 'Exporter le résultat';

  @override
  String get csvImportExported => 'Résultat enregistré';

  @override
  String get csvOutHeaderRow => 'Ligne';

  @override
  String get csvOutHeaderTitle => 'Titre';

  @override
  String get csvOutHeaderArtists => 'Artistes';

  @override
  String get csvOutHeaderAlbum => 'Album';

  @override
  String get csvOutHeaderDuration => 'Durée (ms)';

  @override
  String get csvOutHeaderIsrc => 'ISRC';

  @override
  String get csvOutHeaderStatus => 'Résultat';

  @override
  String get csvOutHeaderNote => 'Motif';

  @override
  String get csvOutHeaderVideo => 'Vidéo choisie';

  @override
  String get csvOutHeaderScore => 'Score';

  @override
  String get importStatusPending => 'À rechercher';

  @override
  String get importStatusQueued => 'En attente';

  @override
  String get importStatusDownloaded => 'Téléchargé';

  @override
  String get importStatusLinked => 'Déjà dans la bibliothèque';

  @override
  String get importStatusReview => 'À vérifier';

  @override
  String get importStatusNotFound => 'Introuvable';

  @override
  String get importStatusFailed => 'Erreur';

  @override
  String get importStatusSkipped => 'Ignoré';

  @override
  String get importStatusPlanned => 'Planifié';

  @override
  String get importStatusRemoved => 'Retiré de la source';

  @override
  String get importNoteNoResults => 'Aucun résultat';

  @override
  String get importNoteLowScore => 'Correspondance peu sûre';

  @override
  String get importNoteLinkOnly => 'Liaison seule : non recherché';

  @override
  String get importNoteYoutubeOff => 'Téléchargement désactivé';

  @override
  String get importNoteDownloadFailed => 'Échec du téléchargement';

  @override
  String get importNoteLengthOff => 'Durée différente de celle du fichier';

  @override
  String get importNoteUnchanged => 'Déjà dans la playlist';

  @override
  String get csvImportSync => 'Synchroniser';

  @override
  String csvImportSyncCounts(int added, int removed) {
    return '$added nouveaux, $removed retirés de la playlist (les fichiers restent)';
  }

  @override
  String get csvImportSyncChecking => 'Vérification des différences…';

  @override
  String get playbackSpeed => 'Vitesse de lecture';

  @override
  String get playbackSpeedHint =>
      'La hauteur du son reste inchangée. Le minuteur d’arrêt compte le temps réel, pas celui du titre.';

  @override
  String resumeFrom(String time) {
    return 'reprendre à $time';
  }

  @override
  String get restartFromBeginning => 'Recommencer depuis le début';

  @override
  String get previewTrack => 'Aperçu de 20 s';

  @override
  String get equalizer => 'Égaliseur';

  @override
  String get eqOutputSpeaker => 'Haut-parleur';

  @override
  String get eqOutputHeadphones => 'Casque';

  @override
  String get eqHint =>
      'Chaque sortie mémorise sa courbe : elle change toute seule quand vous branchez un casque.';

  @override
  String get eqPresetFlat => 'Plat';

  @override
  String get eqPresetBass => 'Basses';

  @override
  String get eqPresetVoice => 'Voix';

  @override
  String get eqPresetTreble => 'Aigus';

  @override
  String get eqPresetCustom => 'Personnalisé';

  @override
  String get eqReset => 'Réinitialiser';

  @override
  String get eqWaiting =>
      'Les bandes apparaissent au démarrage du premier titre.';

  @override
  String get eqUnavailable =>
      'L’égaliseur n’est pas disponible sur cet appareil.';

  @override
  String get transitionMode => 'Transition entre les titres';

  @override
  String get transitionNormal => 'Normal';

  @override
  String get transitionGapless => 'Sans pause';

  @override
  String get transitionCrossfade => 'Fondu enchaîné';

  @override
  String get transitionHint =>
      'Le mode Sans pause fonctionne mieux avec des titres du même format (par exemple tous en FLAC).';

  @override
  String crossfadeLength(int seconds) {
    return 'Durée du fondu enchaîné : $seconds s';
  }

  @override
  String get crossfadePlainInAlbum => 'Pas de fondu dans un même album';

  @override
  String get crossfadePlainInAlbumHint =>
      'Dans un album, les titres s’enchaînent sans pause et sans chevauchement.';

  @override
  String get selectedRow => 'Sélectionné';

  @override
  String selectedRowAt(int position) {
    return 'Sélectionné, numéro $position';
  }

  @override
  String get curiositySong => 'Sur le morceau';

  @override
  String get curiosityArtist => 'Sur l’artiste';

  @override
  String get showMore => 'Tout afficher';

  @override
  String get showLess => 'Afficher moins';

  @override
  String get curiosityNoSong => 'Aucune page sur ce morceau';

  @override
  String get curiosityNoArtist => 'Aucune page sur l’artiste';

  @override
  String get themeNew => 'Nouveau thème';

  @override
  String get themeEdit => 'Modifier';

  @override
  String get themeDuplicate => 'Dupliquer';

  @override
  String get themeDelete => 'Supprimer';

  @override
  String get themeExport => 'Exporter';

  @override
  String get themeImport => 'Importer un thème';

  @override
  String get themeName => 'Nom du thème';

  @override
  String get themeBase => 'Partir de';

  @override
  String get themeModeSimple => 'Simple';

  @override
  String get themeModeAdvanced => 'Avancé';

  @override
  String get themeSave => 'Enregistrer';

  @override
  String get themeEditorTitle => 'Thème personnalisé';

  @override
  String get themeDiscardTitle => 'Abandonner les modifications ?';

  @override
  String get themeDiscardBody =>
      'Les modifications de ce thème ne sont pas enregistrées.';

  @override
  String get themeDiscard => 'Abandonner';

  @override
  String get smartDiscardBody =>
      'Les modifications de cette playlist n’ont pas été enregistrées.';

  @override
  String get themePreview => 'Aperçu';

  @override
  String get themeResetColor => 'Rétablir la couleur';

  @override
  String get themeContrastTitle => 'Lisibilité';

  @override
  String get themeContrastLow => 'Peu lisible';

  @override
  String get themeContrastOk => 'Lisible';

  @override
  String get themeFix => 'Corriger';

  @override
  String get themeSaved => 'Thème enregistré';

  @override
  String get themeLimit => 'Vous avez déjà 20 thèmes : supprimez-en un';

  @override
  String get themeImported => 'Thème importé';

  @override
  String get themeImportFailed => 'Le fichier n’est pas un thème valide';

  @override
  String get themeDeleted => 'Thème supprimé';

  @override
  String get themeMine => 'Mes thèmes';

  @override
  String get tokenBg => 'Arrière-plan';

  @override
  String get tokenSurface1 => 'Surface 1';

  @override
  String get tokenSurface2 => 'Surface 2';

  @override
  String get tokenSurface3 => 'Surface 3';

  @override
  String get tokenAccent => 'Accent';

  @override
  String get tokenAccentSoft => 'Accent doux';

  @override
  String get tokenOnAccent => 'Texte sur l’accent';

  @override
  String get tokenText => 'Texte';

  @override
  String get tokenTextMuted => 'Texte secondaire';

  @override
  String get tokenTextFaint => 'Texte discret';

  @override
  String get tokenHero => 'Fond du lecteur';

  @override
  String get tokenError => 'Erreur';

  @override
  String get pickerHue => 'Teinte';

  @override
  String get pickerSv => 'Saturation et luminosité';

  @override
  String get pickerAlpha => 'Transparence';

  @override
  String get pickerHex => 'Code couleur';

  @override
  String get pickerInvalid => 'Code non valide';

  @override
  String get pickerRecent => 'Utilisées récemment';

  @override
  String get contrastTextBg => 'Texte sur arrière-plan';

  @override
  String get contrastMutedSurface => 'Texte secondaire sur surface';

  @override
  String get contrastOnAccent => 'Texte sur l’accent';

  @override
  String get contrastAccentBg => 'Accent sur l’arrière-plan';

  @override
  String get themeBackground => 'Arrière-plan des pages';

  @override
  String get bgSolid => 'Couleur unie';

  @override
  String get bgGradient => 'Dégradé';

  @override
  String get bgImage => 'Image';

  @override
  String get bgGradientEnd => 'Couleur finale';

  @override
  String get bgAngle => 'Direction';

  @override
  String get bgPickImage => 'Choisir une image…';

  @override
  String get bgRemoveImage => 'Retirer l’image';

  @override
  String get bgDim => 'Assombrissement';

  @override
  String get bgBlur => 'Flou';

  @override
  String get bgCoverBackdrop => 'Lecture : teinte de la pochette';

  @override
  String get blurredChrome => 'Dock et en-têtes floutés';

  @override
  String get blurredChromeHint =>
      'Peut ralentir les téléphones moins puissants';

  @override
  String get bgImageFailed => 'Impossible d’utiliser l’image';

  @override
  String themeCopyName(String name) {
    return '$name (copie)';
  }

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sélectionnés',
      one: '1 sélectionné',
      zero: '0 sélectionné',
    );
    return '$_temp0';
  }

  @override
  String get selectAll => 'Tout sélectionner';

  @override
  String get exitSelection => 'Quitter la sélection';

  @override
  String get bulkActions => 'Actions';

  @override
  String playNextMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres seront lus ensuite',
      one: '1 titre sera lu ensuite',
      zero: '0 titre sera lu ensuite',
    );
    return '$_temp0';
  }

  @override
  String addedToQueueMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres ajoutés à la file d’attente',
      one: '1 titre ajouté à la file d’attente',
      zero: '0 titre ajouté à la file d’attente',
    );
    return '$_temp0';
  }

  @override
  String addedToPlaylistMany(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres ajoutés à « $name »',
      one: '1 titre ajouté à « $name »',
      zero: '0 titre ajouté à « $name »',
    );
    return '$_temp0';
  }

  @override
  String addedToPlaylistSkipped(int added, int skipped, String name) {
    return '$added ajoutés à « $name », $skipped déjà présents';
  }

  @override
  String allAlreadyInPlaylist(String name) {
    return 'Ils étaient déjà tous dans « $name »';
  }

  @override
  String favoritesAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres ajoutés aux favoris',
      one: '1 titre ajouté aux favoris',
      zero: '0 titre ajouté aux favoris',
    );
    return '$_temp0';
  }

  @override
  String favoritesRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres retirés des favoris',
      one: '1 titre retiré des favoris',
      zero: '0 titre retiré des favoris',
    );
    return '$_temp0';
  }

  @override
  String get bulkAddToFavorites => 'Ajouter aux favoris';

  @override
  String get bulkRemoveFromFavorites => 'Retirer des favoris';

  @override
  String removeManyFromPlaylistTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Retirer $count titres de la playlist ?',
      one: 'Retirer 1 titre de la playlist ?',
      zero: 'Retirer 0 titre de la playlist ?',
    );
    return '$_temp0';
  }

  @override
  String get removeManyFromPlaylistBody =>
      'Les fichiers et la bibliothèque ne sont pas modifiés.';

  @override
  String removedManyFromPlaylist(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres retirés',
      one: '1 titre retiré',
      zero: '0 titre retiré',
    );
    return '$_temp0';
  }

  @override
  String removeManyFromLibraryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Retirer $count titres de la bibliothèque ?',
      one: 'Retirer 1 titre de la bibliothèque ?',
      zero: 'Retirer 0 titre de la bibliothèque ?',
    );
    return '$_temp0';
  }

  @override
  String get removeManyFromLibraryBody =>
      'Les fichiers n’existent plus : ils disparaissent seulement de la bibliothèque (les favoris et playlists de ces titres seront perdus).';

  @override
  String removedManyFromLibrary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres retirés de la bibliothèque',
      one: '1 titre retiré de la bibliothèque',
      zero: '0 titre retiré de la bibliothèque',
    );
    return '$_temp0';
  }

  @override
  String ytDownloadsStarted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count téléchargements lancés',
      one: '1 téléchargement lancé',
      zero: '0 téléchargement lancé',
    );
    return '$_temp0';
  }

  @override
  String ytDownloadsSkipped(int started, int skipped) {
    return '$started téléchargements lancés, $skipped déjà dans la bibliothèque ou en cours';
  }

  @override
  String get ytNothingToDownload =>
      'Tous sont déjà dans la bibliothèque ou en cours';

  @override
  String get themeChiaro => 'Clair';

  @override
  String get settingsAccent => 'Couleur d’accent';

  @override
  String get accentViola => 'Violet';

  @override
  String get accentBlu => 'Bleu';

  @override
  String get accentAcqua => 'Turquoise';

  @override
  String get accentVerde => 'Vert';

  @override
  String get accentAmbra => 'Ambre';

  @override
  String get accentArancio => 'Orange';

  @override
  String get accentRosa => 'Rose';

  @override
  String get accentRosso => 'Rouge';

  @override
  String get onboardingSkip => 'Passer';

  @override
  String get onboardingNext => 'Suivant';

  @override
  String get onboardingStart => 'Commencer';

  @override
  String onboardingPageOf(int page, int total) {
    return 'Page $page sur $total';
  }

  @override
  String onboardingStepOf(int page, int total) {
    return '$page sur $total';
  }

  @override
  String get onboardingWelcomeTitle => 'Bienvenue dans Codecore';

  @override
  String get onboardingWelcomeBody =>
      'Votre lecteur de musique personnel : sans compte et sans serveur. Votre musique reste sur votre appareil.';

  @override
  String get onboardingFoldersTitle => 'Votre musique';

  @override
  String get onboardingFoldersBody =>
      'Choisissez les dossiers où se trouvent vos titres. Codecore les lit seulement : il ne les modifie ni ne les déplace.';

  @override
  String onboardingFoldersAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dossiers ajoutés',
      one: '1 dossier ajouté',
    );
    return '$_temp0';
  }

  @override
  String get onboardingAllowAccess => 'Autoriser l’accès aux fichiers audio';

  @override
  String get onboardingAccessGranted => 'Accès autorisé';

  @override
  String get onboardingOnlineTitle => 'Fonctions en ligne';

  @override
  String get onboardingOnlineBody =>
      'Elles sont désactivées : Codecore ne se connecte jamais à Internet de lui-même. Vous pouvez les activer maintenant ou plus tard dans les Paramètres.';

  @override
  String get onboardingShareTitle => 'Téléchargements, Jam et partage';

  @override
  String get onboardingYoutubeBody =>
      'Vous pouvez télécharger des titres depuis YouTube sur votre appareil et les écouter comme le reste de votre musique.';

  @override
  String get onboardingJamBody =>
      'Avec une Jam, vous écoutez la même musique avec un autre appareil du même réseau.';

  @override
  String get onboardingSendBody =>
      'Vous pouvez envoyer des titres à d’autres appareils proches avec un PIN, sans passer par Internet.';

  @override
  String get historyTitle => 'Historique';

  @override
  String get historySubtitle => 'Ce que vous avez écouté';

  @override
  String get historyToday => 'Aujourd’hui';

  @override
  String get historyYesterday => 'Hier';

  @override
  String get historyEmpty => 'Ce que vous écoutez apparaîtra ici.';

  @override
  String get historyOff =>
      'L’historique est désactivé : activez-le dans Paramètres, Lecture.';

  @override
  String get historyClear => 'Effacer l’historique';

  @override
  String get historyClearTitle => 'Effacer l’historique ?';

  @override
  String get historyClearBody =>
      'Seule la liste des écoutes est effacée : les compteurs, les favoris et les playlists restent tels quels.';

  @override
  String get historyCleared => 'Historique effacé';

  @override
  String get settingsRecordHistory => 'Enregistrer l’historique d’écoute';

  @override
  String get settingsRecordHistoryHint =>
      'Il reste sur l’appareil. Désactivé, plus rien n’est ajouté à la liste.';

  @override
  String get statsTitle => 'Statistiques';

  @override
  String get statsSubtitle => 'Combien et quoi vous écoutez';

  @override
  String get statsMonth => 'Mois';

  @override
  String get statsYear => 'Année';

  @override
  String get statsPrevious => 'Période précédente';

  @override
  String get statsNext => 'Période suivante';

  @override
  String get statsEmpty => 'Aucune écoute sur cette période.';

  @override
  String statsPlays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count écoutes',
      one: '1 écoute',
      zero: '0 écoute',
    );
    return '$_temp0';
  }

  @override
  String statsDistinct(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres différents',
      one: '1 titre différent',
      zero: '0 titre différent',
    );
    return '$_temp0';
  }

  @override
  String statsHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get statsTopTracks => 'Titres les plus écoutés';

  @override
  String get statsTopArtists => 'Artistes les plus écoutés';

  @override
  String get statsTopAlbums => 'Albums les plus écoutés';

  @override
  String get statsFavouriteHour => 'Heure préférée';

  @override
  String get statsFirstListen => 'Première écoute';

  @override
  String statsFirstValue(String title, String date) {
    return '$title, $date';
  }

  @override
  String get statsYourMonth => 'Votre mois';

  @override
  String ruleWarning(String term) {
    return 'Je ne comprends pas « $term » : je le cherche comme du texte.';
  }

  @override
  String get smartPlaylistNew => 'Nouvelle playlist intelligente';

  @override
  String get smartPlaylistEdit => 'Modifier la playlist intelligente';

  @override
  String get smartPlaylistLabel => 'Playlist intelligente';

  @override
  String get smartName => 'Nom';

  @override
  String get smartNameRequired => 'Saisissez un nom';

  @override
  String get smartNoRules =>
      'Sans règles, la playlist contient toute la bibliothèque.';

  @override
  String get smartSortBy => 'Trier par';

  @override
  String get smartSortMostPlayed => 'Les plus écoutés';

  @override
  String get smartSortRandom => 'Aléatoire';

  @override
  String get smartTemplates => 'Modèles';

  @override
  String get smartTplNever => 'Jamais écoutés';

  @override
  String get smartTplRecent => 'Ajoutés récemment';

  @override
  String get smartTplTop => 'Les plus écoutés';

  @override
  String get smartTpl90s => 'Les années 90';

  @override
  String get smartConvert => 'Convertir en playlist normale';

  @override
  String smartConverted(String name) {
    return 'Playlist « $name » créée avec la liste actuelle';
  }

  @override
  String smartDeleteTitle(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get smartDeleteBody =>
      'Seule la règle est supprimée : les titres restent où ils sont.';

  @override
  String get smartAutoNote => 'La liste se met à jour toute seule.';

  @override
  String get tagsTitle => 'Étiquettes';

  @override
  String get tagsSubtitle => 'Vos propres étiquettes';

  @override
  String tagsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count étiquettes',
      one: '1 étiquette',
      zero: '0 étiquette',
    );
    return '$_temp0';
  }

  @override
  String get tagsEllipsis => 'Étiquettes…';

  @override
  String get tagNew => 'Nouvelle étiquette';

  @override
  String get tagRename => 'Renommer l’étiquette';

  @override
  String get tagColor => 'Couleur';

  @override
  String get tagNoColor => 'Aucune couleur';

  @override
  String get tagNameTaken => 'Une étiquette porte déjà ce nom';

  @override
  String tagDeleteTitle(String name) {
    return 'Supprimer l’étiquette « $name » ?';
  }

  @override
  String get tagDeleteBody =>
      'Seule l’étiquette est retirée des titres : ils restent dans la bibliothèque.';

  @override
  String get tagsEmpty =>
      'Pas encore d’étiquettes : créez-en une depuis le menu d’un titre.';

  @override
  String get tagAddToSelection => 'Ajouter une étiquette…';

  @override
  String get tagRemoveFromSelection => 'Retirer une étiquette…';

  @override
  String tagAssigned(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres étiquetés « $name »',
      one: '1 titre étiqueté « $name »',
      zero: '0 titre étiqueté « $name »',
    );
    return '$_temp0';
  }

  @override
  String tagUnassigned(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '« $name » retirée de $count titres',
      one: '« $name » retirée de 1 titre',
      zero: '« $name » retirée de 0 titre',
    );
    return '$_temp0';
  }

  @override
  String get tagNoneToRemove => 'Les titres choisis n’ont pas d’étiquettes.';

  @override
  String get cleanupSection => 'Nettoyage de la bibliothèque';

  @override
  String get duplicatesTitle => 'Doublons';

  @override
  String get duplicatesTileHint =>
      'Le même morceau en plusieurs copies ou qualités';

  @override
  String get duplicatesIntro =>
      'Cherche le même morceau en plusieurs copies : le même fichier dans deux dossiers ou le même morceau en deux qualités. Un aperçu s’affiche avant toute fusion. Favoris, playlists, écoutes, paroles et étiquettes passent au morceau conservé ; les autres sont seulement masqués et se rétablissent depuis « Morceaux masqués ». Aucun fichier n’est supprimé sans une double confirmation.';

  @override
  String get duplicatesSearch => 'Chercher les doublons';

  @override
  String get duplicatesSearchAgain => 'Chercher à nouveau';

  @override
  String get duplicatesReading => 'Lecture de la bibliothèque…';

  @override
  String duplicatesHashing(int done, int total) {
    return 'Vérification des fichiers : $done sur $total';
  }

  @override
  String get duplicatesGrouping => 'Comparaison des morceaux…';

  @override
  String get duplicatesFailed => 'La recherche a échoué. Réessaie.';

  @override
  String get duplicatesNone => 'Aucun doublon trouvé';

  @override
  String duplicatesSummary(int groups, int hidden) {
    String _temp0 = intl.Intl.pluralLogic(
      groups,
      locale: localeName,
      other: '$groups groupes',
      one: '1 groupe',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hidden,
      locale: localeName,
      other: '$hidden morceaux à masquer',
      one: '1 morceau à masquer',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get duplicatesExactBadge => 'Identiques';

  @override
  String get duplicatesProbableBadge => 'Probables';

  @override
  String get duplicatesKeepLabel => 'À garder';

  @override
  String get duplicatesPickKeep => 'Touche un morceau pour le garder';

  @override
  String get duplicatesMerge => 'Fusionner';

  @override
  String get duplicatesNotDuplicates => 'Pas des doublons';

  @override
  String duplicatesMergeAllExact(int count) {
    return 'Fusionner tous les identiques ($count)';
  }

  @override
  String get duplicatesMergeAllTitle => 'Fusionner tous les identiques ?';

  @override
  String duplicatesMergeAllBody(int groups, int hidden) {
    String _temp0 = intl.Intl.pluralLogic(
      groups,
      locale: localeName,
      other: '$groups groupes',
      one: '1 groupe',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hidden,
      locale: localeName,
      other: '$hidden morceaux masqués',
      one: '1 morceau masqué',
    );
    return '$_temp0, $_temp1. Favoris, playlists, écoutes et paroles passent aux morceaux conservés.';
  }

  @override
  String duplicatesMerged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux masqués',
      one: '1 morceau masqué',
    );
    return 'Fusionné : $_temp0';
  }

  @override
  String duplicatesDeleteFiles(int count, String size) {
    return 'Supprimer aussi les fichiers ($count, $size)';
  }

  @override
  String get duplicatesDeleteListTitle => 'Supprimer ces fichiers ?';

  @override
  String get duplicatesDeleteListBody =>
      'Ils seront effacés de l’appareil et ne pourront pas être récupérés. Les morceaux conservés restent où ils sont.';

  @override
  String get duplicatesDeleteContinue => 'Continuer';

  @override
  String duplicatesDeleteFinalTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Supprimer définitivement $count fichiers ?',
      one: 'Supprimer définitivement 1 fichier ?',
    );
    return '$_temp0';
  }

  @override
  String duplicatesDeleteFinalBody(String size) {
    return 'Espace libéré : $size. Cette action est irréversible.';
  }

  @override
  String get duplicatesDeleteGo => 'Supprimer définitivement';

  @override
  String get duplicatesDeleteDoneTitle => 'Terminé';

  @override
  String duplicatesDeleteDone(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers supprimés',
      one: '1 fichier supprimé',
    );
    return '$_temp0 ($size).';
  }

  @override
  String duplicatesDeleteFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers non supprimés :',
      one: '1 fichier non supprimé :',
    );
    return '$_temp0';
  }

  @override
  String duplicatesDeleteSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count fichiers laissés tels quels : c’est le même fichier que le morceau conservé.',
      one: '1 fichier laissé tel quel : c’est le même fichier que le morceau conservé.',
    );
    return '$_temp0';
  }

  @override
  String get duplicatesDeleteAndroidHint =>
      'Sur Android, seuls les fichiers des dossiers accessibles à l’appli peuvent être supprimés.';

  @override
  String activityCleanup(int done, int total) {
    return 'Recherche de doublons : $done sur $total';
  }

  @override
  String get hiddenTracksTitle => 'Morceaux masqués';

  @override
  String hiddenTracksCount(int count) {
    return 'Morceaux masqués ($count)';
  }

  @override
  String get hiddenTracksEmpty => 'Aucun morceau masqué';

  @override
  String get hiddenTracksHint =>
      'Les doublons fusionnés n’apparaissent pas dans la bibliothèque. « Rétablir » les remet en place.';

  @override
  String get hiddenRestore => 'Rétablir';

  @override
  String hiddenRestored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux rétablis',
      one: '1 morceau rétabli',
    );
    return '$_temp0';
  }

  @override
  String get albumMergeWith => 'Fusionner avec…';

  @override
  String get albumMergeTitle => 'Fusionner des albums';

  @override
  String albumMergeIntro(String name) {
    return 'Choisis les albums à fusionner avec « $name ». Les morceaux passent dans un seul album, avec le titre et l’artiste indiqués ; la pochette reste celle de « $name ».';
  }

  @override
  String get albumMergeSearch => 'Chercher un album';

  @override
  String get albumMergeNone => 'Il n’y a pas d’autres albums';

  @override
  String get albumFieldTitle => 'Titre de l’album';

  @override
  String get albumFieldArtist => 'Artiste de l’album';

  @override
  String get albumMergeAction => 'Fusionner les albums';

  @override
  String albumMerged(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count albums fusionnés dans « $name »',
      one: '1 album fusionné dans « $name »',
    );
    return '$_temp0';
  }

  @override
  String get moveToAlbum => 'Déplacer vers un nouvel album…';

  @override
  String get moveToAlbumTitle => 'Déplacer vers un album';

  @override
  String moveToAlbumBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux iront',
      one: '1 morceau ira',
    );
    return '$_temp0 dans l’album indiqué. S’il existe déjà, ils le rejoindront.';
  }

  @override
  String get moveToAlbumGo => 'Déplacer';

  @override
  String movedToAlbum(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux déplacés vers « $name »',
      one: '1 morceau déplacé vers « $name »',
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
  String get playlistSourceTitle => 'Playlist ou chaîne YouTube';

  @override
  String get playlistSourceLoading => 'Lecture de la liste des vidéos…';

  @override
  String get playlistSourceName => 'Nom de la playlist';

  @override
  String playlistSourceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vidéos',
      one: '1 vidéo',
    );
    return '$_temp0';
  }

  @override
  String playlistSourceUnavailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vidéos indisponibles (privées ou supprimées)',
      one: '1 vidéo indisponible (privée ou supprimée)',
    );
    return '$_temp0';
  }

  @override
  String playlistSourceTruncated(int count) {
    return 'Affichage des $count premières vidéos.';
  }

  @override
  String playlistSourceLong(int count, String time) {
    return 'Cela fait $count vidéos : il faudra $time.';
  }

  @override
  String get playlistSourceNone => 'Aucune';

  @override
  String get playlistSourceEmpty => 'Il n’y a aucune vidéo à télécharger ici.';

  @override
  String playlistSourceGo(int count) {
    return 'Télécharger dans une playlist ($count)';
  }

  @override
  String playlistSourceStarted(String name) {
    return 'Téléchargements lancés dans la playlist « $name »';
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
  String get podcastsNotice =>
      'Les podcasts ne se mettent à jour que lorsque tu le demandes.';

  @override
  String get podcastsEmpty => 'Tu n’es abonné à aucun podcast.';

  @override
  String get podcastAdd => 'Ajouter un podcast';

  @override
  String get podcastRefreshAll => 'Tout actualiser';

  @override
  String get podcastRefresh => 'Actualiser';

  @override
  String podcastRefreshed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouveaux épisodes',
      one: '1 nouvel épisode',
      zero: 'Aucun nouvel épisode',
    );
    return '$_temp0';
  }

  @override
  String podcastRefreshFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count podcasts non actualisés',
      one: '1 podcast non actualisé',
    );
    return '$_temp0';
  }

  @override
  String get podcastFeedUrl => 'Adresse du flux';

  @override
  String get podcastSubscribe => 'S’abonner';

  @override
  String get podcastSearchHint => 'Chercher un podcast par nom';

  @override
  String get podcastSearchNone => 'Aucun podcast trouvé';

  @override
  String podcastSubscribed(String name) {
    return 'Abonné à « $name »';
  }

  @override
  String podcastEpisodesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count épisodes',
      one: '1 épisode',
    );
    return '$_temp0';
  }

  @override
  String podcastToListen(int count) {
    return '$count à écouter';
  }

  @override
  String get podcastNoEpisodes => 'Aucun épisode.';

  @override
  String get podcastStateDownloaded => 'Téléchargé';

  @override
  String podcastStateDownloading(int percent) {
    return 'Téléchargement… $percent %';
  }

  @override
  String get podcastStateHeard => 'Écouté';

  @override
  String podcastStateRemaining(String time) {
    return 'Il reste $time';
  }

  @override
  String get podcastMarkHeard => 'Marquer comme écouté';

  @override
  String get podcastMarkNotHeard => 'Marquer comme non écouté';

  @override
  String get podcastDeleteFile => 'Supprimer le fichier';

  @override
  String get podcastAutoDelete => 'Supprimer les épisodes écoutés';

  @override
  String get podcastAutoDeleteNever => 'Jamais';

  @override
  String podcastAutoDeleteAfter(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours',
      one: '1 jour',
    );
    return '$_temp0';
  }

  @override
  String get podcastUnsubscribe => 'Supprimer le podcast';

  @override
  String get podcastUnsubscribeTitle => 'Supprimer le podcast ?';

  @override
  String podcastUnsubscribeBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Le podcast et $count épisodes téléchargés seront supprimés de l’appareil.',
      one: 'Le podcast et 1 épisode téléchargé seront supprimés de l’appareil.',
      zero: 'Le podcast sera supprimé de l’appareil.',
    );
    return '$_temp0';
  }

  @override
  String podcastLastChecked(String when) {
    return 'Actualisé $when';
  }

  @override
  String get podcastNeverChecked => 'Jamais actualisé';

  @override
  String get podcastErrInvalidUrl =>
      'Cela ne ressemble pas à une adresse web valide.';

  @override
  String get podcastErrTooLarge => 'Le flux est trop volumineux.';

  @override
  String get podcastErrNetwork => 'Impossible de joindre le serveur.';

  @override
  String get podcastErrNotFeed => 'Cette adresse n’est pas un flux de podcast.';

  @override
  String get podcastErrUnsupportedFormat => 'Format audio non pris en charge.';

  @override
  String get syncTitle => 'Synchroniser les playlists';

  @override
  String syncAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouvelles',
      one: '1 nouvelle',
    );
    return '$_temp0';
  }

  @override
  String syncUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mises à jour',
      one: '1 mise à jour',
    );
    return '$_temp0';
  }

  @override
  String syncMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres manquants',
      one: '1 titre manquant',
    );
    return '$_temp0';
  }

  @override
  String get syncUpToDate => 'Les playlists sont déjà synchronisées';

  @override
  String syncKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count playlists sont plus récentes ici et restent telles quelles',
      one: '1 playlist est plus récente ici et reste telle quelle',
    );
    return '$_temp0';
  }

  @override
  String get syncReplaceNote =>
      'Les playlists mises à jour remplacent celles de cet appareil.';

  @override
  String get syncTagNew => 'Nouvelle';

  @override
  String get syncTagUpdated => 'Mise à jour';

  @override
  String get syncDetailRenamed => 'renommée';

  @override
  String get syncDetailReordered => 'réordonnée';

  @override
  String syncDetailRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres retirés',
      one: '1 titre retiré',
    );
    return '$_temp0';
  }

  @override
  String get syncAskMissing => 'Demander les titres manquants';

  @override
  String syncApplied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count playlists synchronisées',
      one: '1 playlist synchronisée',
    );
    return '$_temp0';
  }

  @override
  String get trustedSection => 'Appareils de confiance';

  @override
  String trustedFingerprint(String fingerprint) {
    return 'Empreinte $fingerprint';
  }

  @override
  String trustedPairedOn(String date) {
    return 'Associé le $date';
  }

  @override
  String get trustedAutoAccept => 'Accepter automatiquement';

  @override
  String get trustedAutoAcceptHint =>
      'Recevoir les titres de cet appareil sans demander.';

  @override
  String get trustedRevoke => 'Révoquer';

  @override
  String trustedRevokeTitle(String name) {
    return 'Révoquer « $name » ?';
  }

  @override
  String get trustedRevokeBody =>
      'Pour envoyer de nouveau sans PIN, il faudra vous associer à nouveau.';

  @override
  String get carMode => 'Mode voiture';

  @override
  String get carExit => 'Quitter';

  @override
  String get carKeepAwake => 'Écran toujours allumé';

  @override
  String get carPlaylists => 'Playlists';

  @override
  String get carNothing => 'Rien en lecture';

  @override
  String get updateCheck => 'Rechercher des mises à jour';

  @override
  String get updateCheckHint =>
      'Demande à GitHub la dernière version, seulement quand tu le demandes.';

  @override
  String get updateOnStart => 'Vérifier au démarrage';

  @override
  String get updateOnStartHint =>
      'Au plus une fois par jour. Ne télécharge ni n’installe rien.';

  @override
  String get updateChecking => 'Vérification…';

  @override
  String updateAvailable(String version) {
    return 'La version $version est disponible';
  }

  @override
  String updateUpToDate(String version) {
    return 'Tu as la dernière version ($version)';
  }

  @override
  String get updateRateLimited =>
      'GitHub demande d’attendre : réessaie plus tard.';

  @override
  String get updateFailed =>
      'Impossible de lire la dernière version. Vérifie la connexion.';

  @override
  String get updateCopyLink => 'Copier l’adresse';

  @override
  String get updateLinkCopied => 'Adresse copiée';

  @override
  String get backupSection => 'Sauvegarde';

  @override
  String get backupCreate => 'Créer une sauvegarde';

  @override
  String get backupCreateHint =>
      'Playlists, favoris, paroles et modifications dans un zip. Sans musique.';

  @override
  String get backupRestore => 'Restaurer une sauvegarde';

  @override
  String get backupRestoreHint =>
      'Remplacer cette bibliothèque ou fusionner les données d’un autre appareil.';

  @override
  String get backupCreating => 'Création de la sauvegarde…';

  @override
  String get backupSaved => 'Sauvegarde enregistrée';

  @override
  String get backupFailed => 'Échec de la sauvegarde';

  @override
  String get restoreTitle => 'Restaurer une sauvegarde';

  @override
  String restoreInfo(String date, String version, int tracks, int playlists) {
    return 'Du $date, app $version, $tracks titres, $playlists playlists';
  }

  @override
  String get restoreReplace => 'Tout remplacer (même appareil)';

  @override
  String get restoreMerge => 'Fusionner avec cette bibliothèque';

  @override
  String get restoreMergeHint =>
      'Ajoute favoris, playlists, paroles et modifications aux titres trouvés. Ne supprime rien.';

  @override
  String get restoreReplaceConfirmTitle => 'Remplacer toute la bibliothèque ?';

  @override
  String get restoreReplaceConfirmBody =>
      'Au prochain démarrage, les données de l’app deviennent celles de la sauvegarde. Les actuelles restent dans une copie de sécurité à côté de la base.';

  @override
  String get restoreReplaceGo => 'Remplacer';

  @override
  String get restoreNotBackup =>
      'Ce fichier n’est pas une sauvegarde Codecore lisible.';

  @override
  String get restoreRestartNeeded =>
      'Prêt : ferme l’app et rouvre-la pour terminer la restauration.';

  @override
  String restoreMergeDone(
    int recognized,
    int missing,
    int playlists,
    int favorites,
  ) {
    return 'Fusion faite : $recognized titres reconnus, $missing introuvables, $playlists playlists créées, $favorites favoris ajoutés.';
  }

  @override
  String get restoreNotFound => 'Titres introuvables';

  @override
  String get restoreCopyList => 'Copier la liste';

  @override
  String get restoreFailed => 'Échec de la restauration';

  @override
  String get exportAllPlaylists => 'Exporter toutes les playlists';

  @override
  String get shareErrIdentity =>
      'L’identité de cet appareil a changé : retire-le des appareils de confiance et associe-le à nouveau.';

  @override
  String get incomingTrustedTag => 'Appareil de confiance';

  @override
  String incomingTrustedTitle(String name) {
    return '$name (de confiance)';
  }

  @override
  String get pairAction => 'Associer';

  @override
  String get trustedBadge => 'De confiance';

  @override
  String pairPinTitle(String name) {
    return 'Association avec $name';
  }

  @override
  String pairPinHint(String name) {
    return 'Saisis le code PIN à 6 chiffres affiché sur $name.';
  }

  @override
  String pairPinWrong(int count) {
    return 'Code PIN incorrect. Essais restants : $count.';
  }

  @override
  String pairFingerprint(String fingerprint) {
    return 'Empreinte : $fingerprint';
  }

  @override
  String get pairCompare =>
      'Vérifie que l’empreinte est la même sur l’autre écran.';

  @override
  String pairRequestTitle(String name) {
    return '$name veut s’associer';
  }

  @override
  String get pairRequestBody =>
      'Saisis ce code PIN sur l’autre appareil, puis touche Confirmer.';

  @override
  String get pairConfirm => 'Confirmer';

  @override
  String get pairWaiting =>
      'En attente de la confirmation sur l’autre appareil…';

  @override
  String pairDone(String name) {
    return 'Associé avec $name';
  }

  @override
  String get pairBlocked => 'Trop d’essais incorrects : réessaie plus tard.';

  @override
  String get pairRejected => 'Association refusée.';

  @override
  String get pairExpired => 'La demande a expiré : réessaie.';

  @override
  String get pairFailed => 'Échec de l’association.';

  @override
  String get syncDevice => 'Synchroniser les playlists';

  @override
  String get syncUnreachable =>
      'L’appareil n’est pas visible sur le réseau local.';

  @override
  String get syncFailed => 'Échec de la synchronisation.';

  @override
  String syncAsked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Demande envoyée : $count titres en route',
      one: 'Demande envoyée : 1 titre en route',
      zero: 'Aucun des titres n’est sur l’autre appareil',
    );
    return '$_temp0';
  }

  @override
  String get translateLyrics => 'Traduire';

  @override
  String get translateLyricsFrom => 'Langue des paroles';

  @override
  String get translateLyricsHint =>
      'Traduit sur le téléphone, aucun texte n’est envoyé sur le réseau.';

  @override
  String get translateRemove => 'Afficher seulement l’original';

  @override
  String translateDownloadTitle(String language) {
    return 'Télécharger le modèle $language ?';
  }

  @override
  String translateDownloadBody(int mb) {
    return 'Environ $mb Mo par langue, de préférence en Wi-Fi. Il se télécharge une seule fois, puis fonctionne aussi hors ligne.';
  }

  @override
  String get translateDownload => 'Télécharger';

  @override
  String translateDownloading(String language) {
    return 'Téléchargement du modèle $language…';
  }

  @override
  String get translateDownloadFailed =>
      'Modèle non téléchargé. Vérifie la connexion et l’espace libre.';

  @override
  String get translateFailed => 'La traduction a échoué.';

  @override
  String get translateSameLanguage =>
      'Les paroles sont déjà dans cette langue.';

  @override
  String get translationModels => 'Modèles de traduction';

  @override
  String get translationModelsNone =>
      'Aucun modèle téléchargé. Ils se téléchargent depuis l’écran des paroles, avec « Traduire ».';

  @override
  String translationModelDelete(String language) {
    return 'Supprimer le modèle $language';
  }

  @override
  String get scanCode => 'Scanner le code';

  @override
  String get scanTitle => 'Vise le code QR';

  @override
  String get scanNotCodecore => 'Ce code n’est pas de Codecore.';

  @override
  String get scanCameraDenied =>
      'L’autorisation de la caméra est nécessaire pour lire le code.';

  @override
  String get scanOpenSettings => 'Ouvrir les réglages';

  @override
  String get ownFingerprint => 'Empreinte de cet appareil';

  @override
  String get ownFingerprintHint =>
      'Compare-la avec celle de l’autre écran lors de l’association.';

  @override
  String get writeTagsToFiles => 'Écrire les modifications dans les fichiers';

  @override
  String get writeTagsToFilesHint =>
      'Le titre, l’artiste, l’album, l’année, le genre et la piste modifiés ici sont aussi écrits dans les fichiers MP3, FLAC, M4A et OGG. L’original de chaque fichier est conservé. Désactivé par défaut.';

  @override
  String get writeTagsAfterDownload =>
      'Écrire les tags dans les fichiers téléchargés';

  @override
  String get writeTagsAfterDownloadHint =>
      'Uniquement dans les fichiers que Codecore a téléchargés ou reçus. L’ISRC reste dans l’appli.';

  @override
  String get writeTagsWarnTitle =>
      'Écrire les modifications dans les fichiers ?';

  @override
  String get writeTagsWarnBody =>
      'À l’enregistrement d’une modification, les tags sont aussi réécrits dans le fichier musical (MP3, FLAC, M4A, OGG). On travaille sur une copie, on vérifie le résultat et le fichier n’est remplacé que si tout concorde ; l’original est d’abord sauvegardé dans « Sauvegardes des tags » (les 200 derniers ou 2 Go). La pochette, les paroles et le ReplayGain ne sont pas touchés. Avant d’activer, faites une sauvegarde de la bibliothèque (Réglages, Sauvegarde).';

  @override
  String get writeTagsEnable => 'Activer';

  @override
  String get tagsAlsoInFile => 'Écrire aussi dans le fichier';

  @override
  String tagsNoWriteUnsupported(String format) {
    return 'Format non modifiable ($format) : seule la bibliothèque change';
  }

  @override
  String get tagsNoWriteReadOnly =>
      'Fichier en lecture seule : seule la bibliothèque change';

  @override
  String get tagsNoWriteMissing =>
      'Fichier introuvable : seule la bibliothèque change';

  @override
  String tagsFileWriteFailed(int count, String reason) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers n’ont pas été modifiés',
      one: '1 fichier n’a pas été modifié',
    );
    return 'Enregistré dans la bibliothèque, mais $_temp0 : $reason';
  }

  @override
  String get tagReasonUnsupported => 'format non pris en charge';

  @override
  String get tagReasonNotFound => 'fichier introuvable';

  @override
  String get tagReasonReadOnly => 'fichier en lecture seule';

  @override
  String get tagReasonVerifyFailed =>
      'la vérification après l’écriture a échoué, le fichier est resté tel quel';

  @override
  String get tagReasonWriteFailed =>
      'l’écriture a échoué, le fichier est resté tel quel';

  @override
  String get tagReasonBackupFailed =>
      'la sauvegarde de l’original a échoué, le fichier est resté tel quel';

  @override
  String get tagReasonIoError => 'erreur de disque ou de droits';

  @override
  String get tagBackupsTitle => 'Sauvegardes des tags';

  @override
  String tagBackupsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sauvegardes des tags ($count)',
      one: 'Sauvegardes des tags (1)',
      zero: 'Sauvegardes des tags',
    );
    return '$_temp0';
  }

  @override
  String get tagBackupsHint =>
      'L’original de chaque fichier réécrit, avant la modification. Les 200 derniers ou 2 Go sont conservés.';

  @override
  String get tagBackupsEmpty =>
      'Aucune sauvegarde : aucun fichier n’a encore été réécrit.';

  @override
  String get tagBackupRestore => 'Restaurer l’original';

  @override
  String tagBackupRestoreBody(String name) {
    return 'Le fichier « $name » revient tel qu’il était avant la modification. La bibliothèque garde les modifications faites dans l’appli.';
  }

  @override
  String get tagBackupRestored => 'Original restauré';

  @override
  String tagBackupRestoreFailed(String reason) {
    return 'Échec de la restauration : $reason';
  }

  @override
  String get tagBackupDelete => 'Supprimer la sauvegarde';

  @override
  String get tagBackupDeleteBody =>
      'Vous ne pourrez plus remettre le fichier tel qu’il était avant la modification.';

  @override
  String get tagBackupDeleted => 'Sauvegarde supprimée';

  @override
  String get deleteFromDevice => 'Supprimer de l’appareil';

  @override
  String deleteTrackTitle(String title) {
    return 'Supprimer « $title » ?';
  }

  @override
  String get deleteTrackBody =>
      'Le fichier est supprimé de l’appareil et le titre disparaît de la bibliothèque, des playlists, des favoris et de l’historique. Cette action est irréversible.';

  @override
  String deleteTracksTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Supprimer $count titres ?',
      one: 'Supprimer 1 titre ?',
      zero: 'Supprimer 0 titre ?',
    );
    return '$_temp0';
  }

  @override
  String get deleteTracksBody =>
      'Les fichiers sont supprimés de l’appareil et les titres disparaissent de la bibliothèque, des playlists, des favoris et de l’historique. Cette action est irréversible.';

  @override
  String get deleteConfirm => 'Supprimer';

  @override
  String get trackDeleted => 'Titre supprimé';

  @override
  String trackDeleteFailed(String reason) {
    return 'Impossible de supprimer le fichier : $reason';
  }

  @override
  String tracksDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres supprimés',
      one: '1 titre supprimé',
      zero: '0 titre supprimé',
    );
    return '$_temp0';
  }

  @override
  String tracksDeletedSome(int count, int failed) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres supprimés',
      one: '1 titre supprimé',
      zero: '0 titre supprimé',
    );
    return '$_temp0, $failed non supprimés';
  }

  @override
  String get trackDeleteRefused =>
      'Android n’a pas autorisé la suppression du fichier';

  @override
  String get reviewTitle => 'À vérifier';

  @override
  String get reviewFilterAll => 'Tous';

  @override
  String get reviewFilterNothingFound => 'Rien trouvé';

  @override
  String get reviewFilterNoLyrics => 'Sans paroles';

  @override
  String get reviewFilterNoCover => 'Sans pochette';

  @override
  String get reviewFilterMissingData => 'Données manquantes';

  @override
  String get reviewEmpty =>
      'Rien à vérifier : aucun titre recherché n’a de lacune';

  @override
  String get reviewHint =>
      'Titres auxquels il manque quelque chose. Cherchez à nouveau ou laissez-les ainsi.';

  @override
  String get reviewRetry => 'Réessayer';

  @override
  String get reviewDismiss => 'Ignorer';

  @override
  String reviewRetryStarted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres',
      one: '1 titre',
    );
    return 'Recherche lancée pour $_temp0';
  }

  @override
  String reviewDismissed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres retirés de la liste',
      one: '1 titre retiré de la liste',
    );
    return '$_temp0';
  }

  @override
  String reviewSecondOpinionProgress(int done, int total) {
    return 'Vérification avec YouTube Music, $done sur $total';
  }

  @override
  String get reviewSecondOpinionStop => 'Arrêter';

  @override
  String reviewSecondOpinionDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres mis à jour avec YouTube Music',
      one: '1 titre mis à jour avec YouTube Music',
    );
    return '$_temp0';
  }

  @override
  String get reviewSecondOpinionThrottled =>
      'YouTube Music a demandé de ralentir : les titres restants seront vérifiés plus tard';

  @override
  String activitySecondOpinion(int done, int total) {
    return 'Second avis : $done sur $total';
  }

  @override
  String get secondOpinionLogTitle => 'Second avis';

  @override
  String get secondOpinionLogEmpty => 'Aucun titre vérifié';

  @override
  String get secondOpinionConfirmed => 'Confirmé, rien à ajouter';

  @override
  String secondOpinionConfirmedFields(String fields) {
    return 'Confirmé, ajouté : $fields';
  }

  @override
  String get secondOpinionNotConfirmed => 'Non confirmé';

  @override
  String get secondOpinionNetwork => 'Réseau indisponible, à réessayer';

  @override
  String get secondOpinionThrottled => 'YouTube Music a demandé de ralentir';

  @override
  String get sourceYoutubeMusic => 'Source : YouTube Music';

  @override
  String get curiositySourceDiscogs => 'De l’album, via Discogs';

  @override
  String get navMemory => 'Stockage';

  @override
  String get memoryMusicLabel => 'Musique';

  @override
  String get memoryOtherLabel => 'Autre';

  @override
  String get memoryFreeLabel => 'Libre';

  @override
  String memoryDeviceLine(String free, String total) {
    return '$free libres sur $total';
  }

  @override
  String get memoryPlaylists => 'Playlists';

  @override
  String get memoryPlaylistsNote =>
      'Un titre présent dans plusieurs playlists compte dans chacune : la somme peut dépasser le total.';

  @override
  String get memoryByFormat => 'Formats';

  @override
  String get memoryByFolder => 'Dossiers';

  @override
  String get memoryNoFolder => 'Hors des dossiers';

  @override
  String get memoryHeaviest => 'Les plus lourds';

  @override
  String get memoryHeaviestTracks => 'Titres';

  @override
  String get memoryHeaviestAlbums => 'Albums';

  @override
  String get memoryNeverPlayed => 'Jamais écoutés';

  @override
  String get memoryNeverPlayedHint =>
      'Titres jamais lus. Sélectionnez-en pour les supprimer de l’appareil.';

  @override
  String get memoryNeverPlayedNone => 'Vous avez tout écouté';

  @override
  String get memoryAppData => 'Données de l’app';

  @override
  String get memoryCovers => 'Pochettes';

  @override
  String memoryCoversThumbs(String size) {
    return 'dont miniatures $size';
  }

  @override
  String get memoryDatabase => 'Bibliothèque';

  @override
  String get memoryImageMemory => 'Images en mémoire';

  @override
  String get memoryJamCache => 'Cache du Jam';

  @override
  String get memorySearchCache => 'Cache des recherches';

  @override
  String get memoryCatalogCache => 'Catalogue en ligne';

  @override
  String get memoryBlurCopies => 'Arrière-plans floutés';

  @override
  String get memoryTagBackups => 'Sauvegardes des tags';

  @override
  String get memoryLog => 'Journal';

  @override
  String get memoryPodcasts => 'Épisodes de podcast';

  @override
  String get memoryClearCache => 'Vider le cache';

  @override
  String memoryCleared(String size) {
    return '$size libérés';
  }

  @override
  String memoryClearedJamKept(String size) {
    return '$size libérés. Le cache Jam est utilisé et n’a pas été touché';
  }

  @override
  String get memoryClearFailed => 'Impossible de vider le cache';

  @override
  String get memoryOfMusic => 'de musique';

  @override
  String get memoryShowAll => 'Tout afficher';

  @override
  String get memoryCache => 'Cache';

  @override
  String get memoryCacheHint => 'Images, recherches, Jam';

  @override
  String get memoryDatabaseHint =>
      'La base de données avec les titres et les écoutes';

  @override
  String get memoryTagBackupsHint => 'Avant chaque modification des fichiers';

  @override
  String get memoryTinyNote =>
      'Les données de moins de 1 Mo ne sont pas listées.';

  @override
  String memoryClearHint(String size) {
    return 'Libère $size. Les titres, les pochettes et les écoutes restent.';
  }

  @override
  String memoryDuplicateGroups(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString groupes',
      one: '1 groupe',
    );
    return '$_temp0';
  }

  @override
  String get memoryTools => 'Outils';

  @override
  String get memoryUnavailable => 'Indisponible';

  @override
  String ytmArtistWithAudience(String audience) {
    return 'Artiste, $audience';
  }

  @override
  String ytmOffline(String date) {
    return 'Hors ligne, données du $date';
  }

  @override
  String get ytmArtistNotFound => 'Artiste introuvable';

  @override
  String get ytmPageUnreadable =>
      'La page est illisible (YouTube a changé quelque chose)';

  @override
  String get ytmArtistUnreadable =>
      'La page de l’artiste est illisible (YouTube a changé quelque chose)';

  @override
  String ytmSearchSongsOf(String name) {
    return 'Chercher les titres de $name';
  }

  @override
  String get ytmInYourLibrary => 'Dans ta bibliothèque';

  @override
  String get ytmAbout => 'À propos';

  @override
  String get ytmMore => 'Plus';

  @override
  String get ytmLess => 'Moins';

  @override
  String get ytmDownloadAlbum => 'Télécharger l’album';

  @override
  String ytmDownloadAlbumTitle(String album) {
    return 'Télécharger « $album » ?';
  }

  @override
  String ytmAlbumConfirmBody(int tracks, String duration, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      tracks,
      locale: localeName,
      other: '$tracks titres',
      one: '1 titre',
    );
    return '$_temp0, $duration, environ $size';
  }

  @override
  String ytmAlbumConfirmOwned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres sont déjà dans la bibliothèque et seront liés',
      one: '1 titre est déjà dans la bibliothèque et sera lié',
    );
    return '$_temp0';
  }

  @override
  String ytmAlbumStarted(String name) {
    return 'Import « $name » démarré';
  }

  @override
  String get ytmShowImport => 'Afficher';

  @override
  String get ytmOnYoutubeMusic => 'Sur YouTube Music';

  @override
  String get ytmArtistOnYoutubeMusic => 'Artiste sur YouTube Music';

  @override
  String get ytmSearchingArtist => 'Recherche sur YouTube Music…';

  @override
  String get ytmPickArtist => 'Quel artiste ?';

  @override
  String get ytmArtistNone => 'Aucun artiste trouvé sur YouTube Music';

  @override
  String get suggestedBadge => 'Suggéré';

  @override
  String suggestedSimilarTo(String seed) {
    return 'Suggéré: proche de « $seed »';
  }

  @override
  String get suggestionDownloadStarted => 'Téléchargement lancé';

  @override
  String suggestionAddWhenDownloaded(String name) {
    return 'Je le télécharge et l’ajoute à « $name »';
  }

  @override
  String get dislikesTitle => 'Je n’aime pas';

  @override
  String get dislikesHint =>
      'Ce que tu ne veux pas dans les suggestions. Les titres ne reviennent que s’ils sont très proches de ce que tu écoutes ; les artistes, jamais.';

  @override
  String dislikesTracksTab(int count) {
    return 'Titres $count';
  }

  @override
  String dislikesArtistsTab(int count) {
    return 'Artistes $count';
  }

  @override
  String get dislikesEmptyTracks => 'Aucun titre exclu';

  @override
  String get dislikesEmptyArtists => 'Aucun artiste exclu';

  @override
  String get dislikesEmptyHint =>
      'Quand tu touches « Je n’aime pas » sur une suggestion, elle apparaît ici et tu peux la retirer.';

  @override
  String get dislikesRemove => 'Retirer';

  @override
  String dislikesRemoveLabel(String name) {
    return 'Retirer « $name » de Je n’aime pas';
  }

  @override
  String dislikesRemoved(String name) {
    return '« $name » retiré de Je n’aime pas';
  }

  @override
  String get dislikesTileHint => 'Titres et artistes exclus des suggestions';

  @override
  String get dislikePlayerLabel => 'Je n’aime pas : titre ou artiste';

  @override
  String get suggestionDislike => 'Je n’aime pas';

  @override
  String get suggestionDisliked => 'Il ne sera plus suggéré';

  @override
  String get removeFromQueueAction => 'Retirer de la file';

  @override
  String get shuffleModeOff => 'Aléatoire : désactivé';

  @override
  String get shuffleModeOn => 'Aléatoire : activé';

  @override
  String get shuffleModePlus =>
      'Aléatoire+ : activé (appui long pour les réglages)';

  @override
  String get shufflePlusTitle => 'Aléatoire+';

  @override
  String get shufflePlusNote =>
      'S’active depuis le bouton aléatoire (troisième appui). Indisponible pour les albums en streaming, Jam et radio';

  @override
  String shufflePlusEvery(int n) {
    return 'Une suggestion tous les $n titres';
  }

  @override
  String get shufflePlusUnmeteredOnly => 'Wi‑Fi uniquement';

  @override
  String get shufflePlusUnmeteredOnlyHint =>
      'Aucune suggestion en données mobiles ou sur un réseau limité.';

  @override
  String get shufflePlusData =>
      'Consommation estimée : environ 15 Mo par heure avec une suggestion tous les 4 titres.';

  @override
  String get shufflePlusActive =>
      'Actif : les suggestions arrivent pendant l’écoute.';

  @override
  String get shufflePlusOff => 'Désactivé : l’aléatoire reste normal.';

  @override
  String get shufflePlusBlockJam => 'Inactif pendant une Jam';

  @override
  String get shufflePlusBlockShort => 'Il faut une liste d’au moins 5 titres';

  @override
  String get shufflePlusBlockNoTool => 'yt-dlp indisponible';

  @override
  String get shufflePlusBlockMetered => 'En pause : réseau limité';

  @override
  String get shufflePlusBlockStopped =>
      'Désactivé jusqu’au redémarrage : trop d’erreurs de lecture';

  @override
  String get shufflePlusBlockOnline =>
      'Indisponible pour un album en streaming';

  @override
  String get shufflePlusBlockRadio => 'Indisponible avec la radio';

  @override
  String get shufflePlusNoticeRateLimited =>
      'YouTube demande de ralentir : suggestions en pause pendant 15 minutes';

  @override
  String get shufflePlusNoticeTooManyErrors =>
      'Trop d’erreurs de lecture : suggestions désactivées jusqu’au redémarrage';

  @override
  String get suggestionsRecentTitle => 'Suggestions récentes';

  @override
  String get suggestionsRecentEmpty =>
      'Aucune suggestion pour l’instant. Les titres apparaissent ici quand vous utilisez Aléatoire+.';

  @override
  String get suggestionsClear => 'Vider l’historique';

  @override
  String get suggestionsClearBody =>
      'Oublie les suggestions et les « Je n’aime pas » : les titres pourront revenir.';

  @override
  String suggestionsRowNote(String seed, String outcome) {
    return 'proche de « $seed », $outcome';
  }

  @override
  String get suggestionOutcomeQueued => 'Dans la file';

  @override
  String get suggestionOutcomeSkipped => 'Passé';

  @override
  String get suggestionOutcomeHeard => 'Écouté';

  @override
  String get suggestionOutcomeDownloaded => 'Téléchargé';

  @override
  String get suggestionOutcomeDisliked => 'Je n’aime pas';

  @override
  String get memorySuggestions => 'Suggestions d’Aléatoire+';

  @override
  String searchOnline(String query) {
    return 'Rechercher « $query » en ligne';
  }

  @override
  String get onlineBestResults => 'Meilleurs résultats';

  @override
  String onlineOthersChip(int count) {
    return 'Autres résultats ($count)';
  }

  @override
  String get onlineNoneSure => 'Aucun résultat sûr';

  @override
  String get onlineInLibrary => 'Dans votre bibliothèque';

  @override
  String onlineShowAllCount(int count) {
    return 'Tout afficher ($count)';
  }

  @override
  String onlineOwnedHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count résultats déjà dans la bibliothèque masqués',
      one: '1 résultat déjà dans la bibliothèque masqué',
    );
    return '$_temp0';
  }

  @override
  String onlineArtistSongs(String artist) {
    return 'Titres de $artist';
  }

  @override
  String get onlineFilterAll => 'Toutes';

  @override
  String onlineFromSource(String source) {
    return 'Depuis $source';
  }

  @override
  String get onlineAlsoVideo => 'aussi en vidéo';

  @override
  String get onlineListenVideo => 'Écouter la vidéo';

  @override
  String onlineNoticeRateLimited(String source, String other) {
    return '$source demande une pause : résultats uniquement de $other';
  }

  @override
  String onlineNoticeFailed(String source, String other) {
    return '$source n’a pas répondu : résultats uniquement de $other';
  }

  @override
  String get radioTitle => 'Radio';

  @override
  String radioLibrarySubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stations enregistrées',
      one: '1 station enregistrée',
      zero: 'Radios en direct',
    );
    return '$_temp0';
  }

  @override
  String get radioSearchHint => 'Rechercher une station';

  @override
  String radioOnlyCountry(String country) {
    return 'Seulement $country';
  }

  @override
  String get radioMine => 'Mes radios';

  @override
  String get radioNearYou => 'Près de chez vous';

  @override
  String get radioGenres => 'Genres';

  @override
  String get radioTopListened => 'Les plus écoutées';

  @override
  String get radioChooseRegion => 'Choisir la région';

  @override
  String get radioRegionHint =>
      'Les stations proches viennent du pays et de la région que vous choisissez : l’application n’utilise pas votre position.';

  @override
  String radioCountryChip(String country) {
    return 'Pays : $country';
  }

  @override
  String get radioChooseCountry => 'Choisir le pays';

  @override
  String radioOfflineList(String date) {
    return 'Hors ligne, liste du $date';
  }

  @override
  String get radioLoadFailed => 'Impossible de charger les stations';

  @override
  String get radioNoResults => 'Aucune station trouvée';

  @override
  String get radioResults => 'Résultats';

  @override
  String get radioSave => 'Enregistrer dans Mes radios';

  @override
  String get radioUnsave => 'Retirer de Mes radios';

  @override
  String get radioSavedDone => 'Station enregistrée';

  @override
  String get radioRemovedDone => 'Station retirée';

  @override
  String get radioNotResponding => 'ne répond pas';

  @override
  String get radioLive => 'En direct';

  @override
  String get reasonRadioUnavailable => 'la station ne répond pas';

  @override
  String radioDataPerHour(String mb) {
    return '≈ $mb Mo par heure';
  }

  @override
  String get radioSite => 'Site de la station';

  @override
  String get radioSiteCopied => 'Adresse du site copiée';

  @override
  String get radioSearchSong => 'Rechercher ce titre';

  @override
  String get radioRenameTitle => 'Nom de la station';

  @override
  String get radioMobileNotice =>
      'La radio utilise environ 1 Mo de données par minute.';

  @override
  String get radioAddAddress => 'Ajouter une adresse';

  @override
  String get radioAddName => 'Nom';

  @override
  String get radioAddUrl => 'Adresse du flux';

  @override
  String get radioAddTest => 'Essayer 10 secondes';

  @override
  String get radioAddTesting =>
      'Essai en cours… si vous l’entendez, enregistrez-la.';

  @override
  String get radioLinkEmpty => 'Saisissez l’adresse du flux';

  @override
  String get radioLinkNotAnAddress =>
      'Cela ne ressemble pas à une adresse : saisissez-la en entier, par exemple https://…';

  @override
  String get radioLinkBadScheme =>
      'L’adresse doit commencer par http:// ou https://';

  @override
  String get radioLinkNoEntries =>
      'Le fichier ne contient aucune adresse à lire';

  @override
  String get radioLinkTooBig =>
      'Le fichier est trop volumineux pour être une liste de stations';

  @override
  String get radioLinkFetchFailed => 'Impossible de télécharger le fichier';

  @override
  String get radioReorder => 'Faites glisser pour réorganiser';

  @override
  String get radioReorderFailed => 'Impossible d’enregistrer le nouvel ordre';

  @override
  String get memoryRadio => 'Radio (listes de stations)';

  @override
  String get radioGenrePop => 'Pop';

  @override
  String get radioGenreRock => 'Rock';

  @override
  String get radioGenreClassicRock => 'Rock classique';

  @override
  String get radioGenreJazz => 'Jazz';

  @override
  String get radioGenreBlues => 'Blues';

  @override
  String get radioGenreClassical => 'Classique';

  @override
  String get radioGenreDance => 'Dance';

  @override
  String get radioGenreElectronic => 'Électro';

  @override
  String get radioGenreHouse => 'House';

  @override
  String get radioGenreHipHop => 'Hip-hop';

  @override
  String get radioGenreLoFi => 'Lo-fi';

  @override
  String get radioGenreChillout => 'Chillout';

  @override
  String get radioGenreSixties => 'Années 60';

  @override
  String get radioGenreSeventies => 'Années 70';

  @override
  String get radioGenreEighties => 'Années 80';

  @override
  String get radioGenreNineties => 'Années 90';

  @override
  String get radioGenreOldies => 'Oldies';

  @override
  String get radioGenreMetal => 'Metal';

  @override
  String get radioGenreReggae => 'Reggae';

  @override
  String get radioGenreLatin => 'Latino';

  @override
  String get radioGenreSoul => 'Soul';

  @override
  String get radioGenreNews => 'Infos';

  @override
  String get radioGenreTalk => 'Talk';

  @override
  String get radioGenreSports => 'Sport';

  @override
  String get newReleasesTitle => 'Nouveautés';

  @override
  String get releasesTopArtists => 'Suivre automatiquement les plus écoutés';

  @override
  String get releasesTopArtistsHint =>
      'Les 15 artistes les plus écoutés ces 90 derniers jours, cherchés sur YouTube Music.';

  @override
  String get releasesNotify => 'Notifications de nouveautés';

  @override
  String get releasesNotifyHint =>
      'Une par jour au maximum, sur Android uniquement.';

  @override
  String get releasesUnmetered => 'Vérifier uniquement en Wi‑Fi';

  @override
  String get releasesUnmeteredHint =>
      'Une vérification par jour pèse environ 0,5 Mo.';

  @override
  String get releasesTopCardTitle =>
      'Tu veux savoir quand tes artistes les plus écoutés sortent de nouveaux titres ?';

  @override
  String get releasesTopCardYes => 'Activer';

  @override
  String get releasesTopCardNo => 'Non merci';

  @override
  String get releasesCheckNow => 'Vérifier maintenant';

  @override
  String releasesLastCheck(String when) {
    return 'Dernière vérification : $when';
  }

  @override
  String get releasesNeverChecked => 'Jamais vérifié';

  @override
  String releasesPaused(String time) {
    return 'YouTube demande une pause : nouvel essai à $time';
  }

  @override
  String get releasesChecking => 'Vérification en cours…';

  @override
  String get releasesCheckNone => 'Aucune nouveauté';

  @override
  String releasesCheckFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouveautés',
      one: '1 nouveauté',
    );
    return '$_temp0';
  }

  @override
  String get releasesCantCheck =>
      'Impossible de vérifier maintenant : pas de réseau ou aucun artiste suivi.';

  @override
  String get releasesChanged =>
      'YouTube Music a changé de format : nouvel essai au prochain tour.';

  @override
  String get releasesEmpty =>
      'Aucune nouveauté ces 90 derniers jours. Ouvre la page d’un artiste et touche « Suivre ».';

  @override
  String get releasesAllArtists => 'Tous';

  @override
  String releasesFollowedTitle(int count) {
    return 'Artistes suivis ($count)';
  }

  @override
  String get releasesFollowedLibrary => 'Artistes suivis';

  @override
  String releasesFollowedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artistes',
      one: '1 artiste',
    );
    return '$_temp0';
  }

  @override
  String get followedEmpty =>
      'Tu ne suis encore aucun artiste. Ouvre la page d’un artiste et touche « Suivre ».';

  @override
  String get followAction => 'Suivre';

  @override
  String get followingAction => 'Suivi';

  @override
  String followStopTitle(String name) {
    return 'Ne plus suivre $name ?';
  }

  @override
  String get followStopBody => 'Ses nouveautés ne seront plus signalées.';

  @override
  String get followOnYtm => 'Suivre sur YouTube Music';

  @override
  String get followStop => 'Ne plus suivre';

  @override
  String followedNow(String name) {
    return 'Tu suis maintenant $name';
  }

  @override
  String get followMute => 'Couper les notifications';

  @override
  String get followUnmute => 'Réactiver les notifications';

  @override
  String get followedTopListened => 'Le plus écouté';

  @override
  String get followedToConfirm => 'À confirmer';

  @override
  String get followedNotFound => 'Introuvable';

  @override
  String get followedRetry => 'Réessayer';

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
      other: 'et $count autres versions',
      one: 'et 1 autre version',
    );
    return '$_temp0';
  }

  @override
  String get releaseNewBadge => 'Nouveau';

  @override
  String get activityReleases => 'Vérification des nouveautés';

  @override
  String releaseNotifyOne(String title, String artist) {
    return 'Nouveauté : $title de $artist';
  }

  @override
  String releaseNotifyMany1(int count, String a) {
    return '$count nouveautés : $a';
  }

  @override
  String releaseNotifyMany2(int count, String a, String b) {
    return '$count nouveautés : $a et $b';
  }

  @override
  String releaseNotifyManyMore(int count, String a, String b, int others) {
    return '$count nouveautés : $a, $b et $others autres';
  }

  @override
  String get releaseNotifyShow => 'Afficher';

  @override
  String get reportIssue => 'Signaler un problème';

  @override
  String get reportIssueHint => 'Ouvre GitHub avec le texte déjà prêt';

  @override
  String get reportKindBug => 'Défaut';

  @override
  String get reportKindIdea => 'Idée';

  @override
  String get reportTitleLabel => 'Titre';

  @override
  String get reportDescLabel => 'Description';

  @override
  String reportDescHelper(int n) {
    return 'Ce qui s’est passé et comment le reproduire (au moins $n caractères)';
  }

  @override
  String get reportAttach => 'Joindre les informations techniques';

  @override
  String get reportAttachPreview => 'Voici exactement ce qui sera envoyé :';

  @override
  String get reportOpen => 'Ouvrir sur GitHub';

  @override
  String get reportCopy => 'Copier le texte';

  @override
  String get reportCopied => 'Texte copié';

  @override
  String get reportGithubNote =>
      'Un compte GitHub est nécessaire ; sinon, copiez le texte et envoyez-le comme vous voulez.';

  @override
  String get reportOpenFailed =>
      'Impossible d’ouvrir le navigateur : le texte a été copié';

  @override
  String get reportLogShortened =>
      'Le journal sera raccourci pour tenir dans l’adresse';

  @override
  String get reportNoLog =>
      'Aucun avertissement ni erreur récente dans le journal';

  @override
  String get reportUnknown => 'Inconnu';

  @override
  String get iconAskTitle => 'Changer aussi l’icône de l’app ?';

  @override
  String get iconProblems =>
      'L’icône change quand tu quittes l’app. Problèmes possibles :\n• le launcher peut mettre quelques secondes à la mettre à jour, ou afficher un instant deux icônes ou aucune ;\n• sur certains launchers, l’icône de l’écran d’accueil est retirée ou déplacée et doit être remise à la main (les widgets restent) ;\n• les raccourcis d’accueil créés avec l’ancienne icône peuvent cesser de fonctionner ;\n• l’app peut disparaître un instant des apps récentes ;\n• rarement, Android ferme l’app et la musique s’arrête.\nSur l’ordinateur, l’icône ne change pas.';

  @override
  String get iconChange => 'Changer l’icône';

  @override
  String get iconKeep => 'Laisser tel quel';

  @override
  String get iconDontAsk => 'Ne plus demander';

  @override
  String get iconFollowTitle => 'Icône assortie au thème';

  @override
  String get iconFollowSubtitle =>
      'L’icône suit le thème et la couleur quand tu quittes l’app';

  @override
  String get exportifySyncTitle => 'Synchroniser depuis Spotify';

  @override
  String exportifySyncChanges(int added, int removed) {
    return '+$added nouveaux, −$removed retirés';
  }

  @override
  String get exportifySyncNew => 'Nouvelle playlist';

  @override
  String get exportifySyncChoose => 'À choisir';

  @override
  String get exportifySyncNoChanges => 'Aucun changement';

  @override
  String exportifySyncSkipped(int n) {
    return '$n fichiers ignorés (playlists illisibles)';
  }

  @override
  String exportifySyncGo(int n) {
    return 'Synchroniser $n';
  }

  @override
  String exportifySyncDone(int n) {
    return '$n playlists en cours de synchronisation : suivez-les dans le Centre d’activité';
  }

  @override
  String get exportifySyncEmpty => 'Aucune playlist dans le ZIP';

  @override
  String get exportifySyncPickTitle => 'Choisir la playlist';

  @override
  String get csvImportOpenExportify => 'Ouvrir exportify.net';

  @override
  String get csvImportOpenFailed => 'Impossible d’ouvrir le navigateur';

  @override
  String get csvImportZipHint =>
      'Avec « Export All » vous obtenez un ZIP avec toutes vos playlists : choisissez-le ici et synchronisez-les ensemble.';

  @override
  String get exportifySyncFailed => 'Échec de la synchronisation';

  @override
  String get exportifySyncEntryFailed => 'Impossible de lire cette playlist';

  @override
  String get exportifySyncLoadFailed =>
      'Impossible de lire les playlists du ZIP';

  @override
  String get exportifyRemindTitle => 'Me rappeler de synchroniser avec Spotify';

  @override
  String get exportifyRemindOff => 'Désactivé';

  @override
  String exportifyRemindDays(int days) {
    return '$days jours';
  }

  @override
  String get exportifyCardTitle =>
      'Il est temps de synchroniser vos playlists avec Spotify';

  @override
  String get exportifyCardOpen => 'Ouvrir Exportify';

  @override
  String get exportifyCardLater => 'Plus tard';

  @override
  String get exportifyFoundTitle => 'Export Exportify trouvé';

  @override
  String get exportifyFoundSync => 'Synchroniser';

  @override
  String get onboardingSpotifyTitle => 'Playlists de Spotify';

  @override
  String get onboardingSpotifyBody =>
      'Sur exportify.net, vous téléchargez vos playlists Spotify dans un fichier. Codecore le récupère et les met à jour ici.\nAucun compte à relier : le fichier, c’est vous qui le téléchargez.';

  @override
  String get deezerMeta => 'Métadonnées de Deezer';

  @override
  String get deezerMetaHint =>
      'Données seulement (pochettes, numéros de piste), jamais de musique';

  @override
  String get deezerMetaNote =>
      'Usage privé et non commercial. Les conditions de Deezer interdisent de promouvoir le téléchargement non autorisé, et Codecore télécharge depuis YouTube : le risque est le vôtre.';

  @override
  String get acoustId => 'Reconnaître au son (AcoustID)';

  @override
  String get acoustIdHint =>
      'Seule l’empreinte du morceau est envoyée, jamais l’audio';

  @override
  String get settingsSpinCover => 'Pochette qui tourne';

  @override
  String get settingsSpinCoverHint => 'Dans le lecteur, pendant la lecture';

  @override
  String get themeLowContrastWarning =>
      'Certaines couleurs de texte se lisent mal sur le fond (moins de 4,5:1). Le thème reste tel quel.';

  @override
  String get streamCacheTitle => 'Espace pour le streaming';

  @override
  String streamCacheUsage(String used, String limit) {
    return '$used sur $limit';
  }

  @override
  String get streamCacheClear => 'Vider';

  @override
  String get streamCacheCleared => 'Cache du streaming vidé';

  @override
  String get streamCacheClearFailed =>
      'Impossible de vider le cache du streaming';

  @override
  String get playerLoading => 'Chargement…';

  @override
  String get ytmAlbumQueue => 'Ajouter l’album à la file';

  @override
  String get addedToLibrary => 'Ajouté à la bibliothèque';

  @override
  String get promoteNoSpace => 'Espace insuffisant pour télécharger le titre';

  @override
  String get promoteFailed => 'Impossible de déplacer le titre';

  @override
  String get creditsDetails => 'Crédits et détails';

  @override
  String get creditsDetailsHint => 'Auteurs, producteurs et détails des titres';

  @override
  String get creditsDetailsNote =>
      'Utilise aussi une API Deezer non officielle';

  @override
  String get creditRoleVocals => 'Chant';

  @override
  String get creditRoleBackingVocals => 'Chœurs';

  @override
  String get creditRoleGuitar => 'Guitare';

  @override
  String get creditRoleBassGuitar => 'Basse';

  @override
  String get creditRoleDrums => 'Batterie';

  @override
  String get creditRoleKeyboard => 'Claviers';

  @override
  String get creditRolePiano => 'Piano';

  @override
  String get creditRoleSynthesizer => 'Synthétiseur';

  @override
  String get creditRoleComposer => 'Compositeur';

  @override
  String get creditRoleAuthor => 'Auteur';

  @override
  String get creditRoleLyricist => 'Parolier';

  @override
  String get creditRoleArranger => 'Arrangeur';

  @override
  String get creditRoleProducer => 'Producteur';

  @override
  String get creditRoleAdditionalProducer => 'Producteur additionnel';

  @override
  String get creditRoleMix => 'Mixage';

  @override
  String get creditRoleMastering => 'Mastering';

  @override
  String get creditRoleRecording => 'Enregistrement';

  @override
  String get creditRoleEngineer => 'Ingénieur du son';

  @override
  String get creditRoleProgramming => 'Programmation';

  @override
  String get creditRoleDrumProgrammer => 'Programmation de batterie';

  @override
  String get creditRoleMusicPublisher => 'Éditeur musical';

  @override
  String get creditsGroupPerformers => 'Interprètes et instruments';

  @override
  String get creditsGroupWriters => 'Auteurs';

  @override
  String get creditsGroupProduction => 'Production et techniciens';

  @override
  String get creditsGroupOther => 'Autres';

  @override
  String get creditsTitle => 'Crédits et détails';

  @override
  String get creditsShowAll => 'Tout afficher';

  @override
  String get creditsRefresh => 'Actualiser';

  @override
  String get creditsAppearsAs => 'Apparaît comme';

  @override
  String get creditsInCredits => 'Dans les crédits';

  @override
  String get creditsRefreshFailed => 'Impossible d’actualiser les crédits';

  @override
  String get creditsBpm => 'BPM';

  @override
  String get creditsLabel => 'Label';

  @override
  String get creditsDigitalRelease => 'Sortie numérique';

  @override
  String get creditsPhysicalRelease => 'Sortie physique';

  @override
  String get creditsKindSingle => 'Single';

  @override
  String get creditsKindEp => 'EP';

  @override
  String get creditsRank => 'Classement';

  @override
  String get creditsAlbumFans => 'Fans de l’album';

  @override
  String get creditsExplicit => 'Explicite';

  @override
  String creditsOpenArtist(String name) {
    return 'Ouvrir $name';
  }

  @override
  String get autoCuriosities => 'Anecdotes automatiques';

  @override
  String get autoCuriositiesHint =>
      'Cherche des anecdotes sur Wikipédia pour les nouveaux titres';

  @override
  String memoryEnrichment(String size) {
    return 'Enrichissement : $size';
  }

  @override
  String memoryEnrichmentDetail(
    String lyrics,
    String curiosities,
    String credits,
  ) {
    return 'Paroles $lyrics, anecdotes $curiosities, crédits $credits';
  }

  @override
  String get activityPodcastRefresh => 'Mise à jour des podcasts';

  @override
  String get activityRadio => 'Vérification des radios enregistrées';

  @override
  String activityEnrichBackground(int done, int total) {
    return 'Complétion de l’enrichissement : $done sur $total';
  }

  @override
  String get enrichRoundTitle => 'Passage d’enrichissement';

  @override
  String get enrichRoundUpdated => 'Mis à jour';

  @override
  String get enrichRoundNone => 'Sans résultat';

  @override
  String get enrichRoundGone => 'Aucun morceau à afficher';

  @override
  String get enrichPartMeta => 'Infos du morceau';

  @override
  String get enrichPartLyrics => 'Paroles';

  @override
  String get enrichPartSynced => 'Paroles synchronisées';

  @override
  String get enrichPartCurio => 'Anecdotes';

  @override
  String get enrichPartCredits => 'Crédits';

  @override
  String get coverChange => 'Changer la pochette';

  @override
  String get coverRestoreOriginal => 'Rétablir la pochette d’origine';

  @override
  String get coverSourceDevice => 'Depuis l’appareil';

  @override
  String get coverSourceLibrary => 'Depuis la bibliothèque';

  @override
  String get coverSourceOnline => 'En ligne';

  @override
  String coverSizePx(int w, int h) {
    return '$w × $h';
  }

  @override
  String get speakerPermTitle => 'Autorisation Bluetooth';

  @override
  String get speakerPermBody =>
      'Pour reconnaître ton enceinte, Codecore doit voir quels appareils Bluetooth sont connectés. Il ne lit rien d’autre.';

  @override
  String get speakerPermAllow => 'Autoriser';

  @override
  String get speakerNotNow => 'Pas maintenant';

  @override
  String speakerAskTitle(String name) {
    return '$name est-elle une enceinte ?';
  }

  @override
  String get speakerAskBody =>
      'Si oui, Codecore ouvre tout seul une Jam à la connexion, que les autres peuvent rejoindre.';

  @override
  String get speakerYes => 'Oui';

  @override
  String get speakerNo => 'Non';

  @override
  String get speakerJamSection => 'Jam sur l’enceinte';

  @override
  String get speakerJamHint =>
      'Quand une enceinte Bluetooth se connecte, Codecore ouvre tout seul une Jam que les autres peuvent rejoindre.';

  @override
  String get speakerNoDevices => 'Aucun appareil enregistré pour l’instant';

  @override
  String get speakerIsSpeaker => 'Enceinte';

  @override
  String get speakerNotSpeaker => 'Pas une enceinte';

  @override
  String get speakerPermDenied => 'Autorisation Bluetooth refusée';

  @override
  String get speakerPermRetry => 'Touche pour la redemander';

  @override
  String speakerChange(String name) {
    return 'Modifier $name';
  }

  @override
  String jamInviteBanner(String name) {
    return 'Rejoindre la Jam de $name';
  }

  @override
  String get jamInviteDismiss => 'Masquer';

  @override
  String get speakerAwayNotice => 'Connecte une enceinte';

  @override
  String get jamFull => 'La Jam est pleine';

  @override
  String get jamAddFailed => 'Non ajouté à la Jam';

  @override
  String get jamNotFoundOnline => 'Introuvable en ligne, impossible à ajouter';

  @override
  String get jamLeft => 'Vous avez quitté la Jam';

  @override
  String get speakerContinueOnPhone => 'Continuer sur le téléphone';

  @override
  String get speakerContinueOnPhoneLabel =>
      'Continuer sur le téléphone : la Jam joue sur le haut-parleur de ce téléphone, sans l’enceinte';

  @override
  String get speakerOfferTitle => 'Jouer la Jam sur ton enceinte ?';

  @override
  String get speakerOfferBody =>
      'Ton enceinte est connectée et la Jam est en pause. Si tu veux, la musique repart d’ici.';

  @override
  String get jamRemoteTitle => 'Jam à distance';

  @override
  String get jamRemoteHint =>
      'Les brokers (serveurs) de la Jam à distance, par ordre de préférence.';

  @override
  String get jamBrokerAdd => 'Ajouter un broker';

  @override
  String get jamBrokerHost => 'Adresse';

  @override
  String get jamBrokerPort => 'Port';

  @override
  String get jamBrokerTls => 'Connexion chiffrée (TLS)';

  @override
  String get jamBrokerNoTls =>
      'Sans TLS, n’importe qui sur le réseau peut lire ce qui passe par le broker. À n’utiliser que si tu sais ce que tu fais.';

  @override
  String get jamBrokerInvalid => 'Adresse ou port non valides';

  @override
  String get jamBrokerTest => 'Tester la connexion';

  @override
  String jamBrokerTestOk(String broker) {
    return '$broker : connexion réussie';
  }

  @override
  String jamBrokerTestFail(String broker) {
    return '$broker : connexion impossible (réseau, certificat ou serveur injoignable)';
  }

  @override
  String get jamBrokerRestore => 'Rétablir';

  @override
  String get jamBrokerMoveUp => 'Monter';

  @override
  String get jamBrokerRemove => 'Retirer';

  @override
  String get jamSuspend => 'Suspendre';

  @override
  String get jamBlock => 'Bloquer';

  @override
  String get jamSuspendTitle => 'Suspendre pour combien de temps ?';

  @override
  String get jamUntilJamEnds => 'Jusqu’à la fin de la Jam';

  @override
  String get jamBlockedTitle => 'Appareils bloqués';

  @override
  String get jamSuspendedTitle => 'Suspendus';

  @override
  String get jamUnblock => 'Débloquer';

  @override
  String jamSuspendedUntil(String time) {
    return 'Jusqu’à $time';
  }

  @override
  String get jamTooSoon => 'Attends un instant avant de réessayer';

  @override
  String enrichInterrupted(int updated, int notFound) {
    return 'Enrichissement interrompu par une erreur : $updated mis à jour, $notFound introuvables';
  }

  @override
  String enrichLibraryDue(int count, int minutes) {
    return '$count morceaux à compléter, environ $minutes minutes';
  }

  @override
  String get enrichLibraryComplete => 'Bibliothèque complète';

  @override
  String get enrichLibraryStop => 'Interrompre';

  @override
  String get activityEnrichWaiting => 'Complétion : en attente';

  @override
  String logRecogSources(String list) {
    return 'Reconnus : $list';
  }

  @override
  String get recogSrcTags => 'tags';

  @override
  String get recogSrcVideo => 'vidéo';

  @override
  String get recogSrcText => 'texte';

  @override
  String recogIdent(String title, String artist) {
    return '$title – $artist';
  }

  @override
  String recogProposal(String identity) {
    return 'Proposition : $identity';
  }

  @override
  String get recogAccept => 'Accepter';

  @override
  String get recogDiscard => 'Ignorer';

  @override
  String recogAcceptSem(String identity) {
    return 'Accepter la proposition $identity';
  }

  @override
  String recogDiscardSem(String identity) {
    return 'Ignorer la proposition $identity';
  }

  @override
  String get recogCover => 'Reprise';

  @override
  String recogCoverOf(String identity) {
    return 'Reprise de $identity';
  }

  @override
  String recogToConfirm(int count) {
    return 'À confirmer ($count)';
  }

  @override
  String get recogAcceptAll => 'Tout accepter';

  @override
  String get recogNoProposals => 'Tout est confirmé';

  @override
  String recogFromTo(String from, String to) {
    return 'De $from à $to';
  }

  @override
  String get logRevert => 'Rétablir';

  @override
  String get recogActionFailed => 'L’action a échoué';

  @override
  String get logRevertFailed => 'Impossible de rétablir cette correction';

  @override
  String get jamInviteNearby => 'Inviter les personnes à proximité';

  @override
  String get jamInviteHint =>
      'Quiconque scanne le QR ou saisit le code rejoint la Jam.';

  @override
  String get jamBridgeConnecting => 'Connexion…';

  @override
  String get jamBridgeRetrying => 'Liaison interrompue, nouvel essai…';

  @override
  String get jamBridgeUnreachable => 'Broker injoignable';

  @override
  String jamCodeExpiresIn(int seconds) {
    return 'Expire dans $seconds s';
  }

  @override
  String get jamEnterCode => 'Rejoindre avec un code';

  @override
  String get jamCodeLabel => 'Code';

  @override
  String get jamScanQr => 'Scanner le QR';

  @override
  String get jamJoinAction => 'Rejoindre';

  @override
  String get jamCodeInvalid => 'Code non valide';

  @override
  String get jamCodeExpired => 'Code expiré, demandez-en un nouveau';

  @override
  String get jamHostNoAnswer => 'L’hôte n’a pas répondu';

  @override
  String get jamCustomBroker =>
      'Cette Jam utilise un broker personnalisé : scannez le QR';

  @override
  String get jamLinkReconnecting => 'Connexion perdue, nouvel essai…';

  @override
  String get jamHostSilent => 'Hôte injoignable, nouvel essai…';

  @override
  String get jamMemberUnreachable => 'injoignable';

  @override
  String get jamRemoteActive => 'Jam à distance active';

  @override
  String get jamRemoteEnd => 'Terminer';

  @override
  String get jamDeclinedHost => 'L’hôte a refusé la demande';

  @override
  String get jamBusyHost => 'L’hôte a déjà une Jam en cours';

  @override
  String get jamWaitingHost => 'En attente de l’acceptation de l’hôte…';

  @override
  String get jamFriendsTitle => 'Amis de la Jam';

  @override
  String get jamFriendsEmpty =>
      'Aucun ami. Après la première entrée acceptée, les deux appareils s’enregistrent mutuellement.';

  @override
  String get jamFriendRemove => 'Retirer';

  @override
  String jamFriendRemoveTitle(String name) {
    return 'Retirer $name ?';
  }

  @override
  String get jamFriendRemoveBody =>
      'Vous ne vous reconnaîtrez plus sans demander. Cet appareil change sa clé d’annonce.';

  @override
  String get jamAutoAcceptFriends => 'Accepter les amis sans demander';

  @override
  String get jamAutoAcceptFriendsHint =>
      'Si le téléphone d’un ami est volé, son détenteur peut entrer dans ta Jam à proximité.';

  @override
  String get jamFriendBadge => 'Ami';

  @override
  String get jamNearbyJoin => 'Rejoindre une Jam à proximité';

  @override
  String get jamBleTitle => 'Chercher des Jams à proximité';

  @override
  String get jamBleBody12 =>
      'Android demande l’autorisation « Appareils à proximité » pour chercher et annoncer des Jams en Bluetooth. L’app ne lit pas où vous êtes.';

  @override
  String get jamBleBody11 =>
      'L’autorisation de localisation est nécessaire : Android l’exige pour chercher en Bluetooth ; l’app ne lit pas où vous êtes.';

  @override
  String get jamBleAllow => 'Autoriser';

  @override
  String get jamBleNotNow => 'Pas maintenant';

  @override
  String get jamBleLocationOff =>
      'Activez la localisation d’Android : elle est nécessaire pour chercher des Jams en Bluetooth. En attendant, utilisez le code ou le QR.';

  @override
  String get jamNearbyScanTitle => 'Chercher des Jams proches';

  @override
  String get jamNearbyScanHint => 'En Bluetooth, uniquement app ouverte';

  @override
  String get streamCardsUnavailable => 'Indisponible';

  @override
  String get streamCardsUnavailableBody =>
      'Les paroles, les anecdotes et les crédits de ce titre ne sont pas arrivés. Cela peut venir du réseau ou de la source.';

  @override
  String get closeKeyboard => 'Fermer le clavier';

  @override
  String get loadingContent => 'Chargement…';

  @override
  String shufflePlusChoosing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Shuffle+ choisit $count titres…',
      one: 'Shuffle+ choisit 1 titre…',
    );
    return '$_temp0';
  }

  @override
  String statsBarValue(String when, String time) {
    return '$when, $time';
  }

  @override
  String get homeRadioLive => 'En direct';

  @override
  String get closeSearch => 'Fermer la recherche';

  @override
  String get librarySearchHint => 'Rechercher dans la bibliothèque';

  @override
  String get genreMixTag => 'Suggéré';

  @override
  String get genreMixOffJam => 'Suggestions désactivées : Jam en cours';

  @override
  String get genreMixOffMetered => 'Suggestions désactivées : réseau limité';

  @override
  String get genreMixOffOffline => 'Suggestions désactivées : pas de réseau';

  @override
  String get genreMixOffNoTool =>
      'Suggestions désactivées : outil en ligne absent';

  @override
  String get genreMixOffRateLimited =>
      'Suggestions en pause : trop de requêtes';

  @override
  String get playerEmptyTitle => 'Rien en lecture';

  @override
  String get playerEmptyHint => 'Choisis par où reprendre.';

  @override
  String get playerEmptyNoQueue => 'Choisis un titre pour commencer';

  @override
  String playerLastQueue(String name) {
    return 'Dernière file d’attente : $name';
  }

  @override
  String get playerResumeLastQueue => 'Reprendre la dernière file d’attente';

  @override
  String playerResumeLastQueueSub(String name, String tracks) {
    return '$name, $tracks';
  }

  @override
  String get playerShufflePlusLibrary => 'Shuffle+ de la bibliothèque';

  @override
  String get playerShufflePlusLibrarySub =>
      'Ta bibliothèque en aléatoire, avec des suggestions';

  @override
  String get playerRecentlyAdded => 'Ajoutés depuis peu';

  @override
  String get reviewSearch => 'Chercher';

  @override
  String get recogTitle => 'À confirmer';

  @override
  String recogSuggested(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count corrections suggérées. Passez-les en revue une par une ou acceptez-les toutes.',
      one: '1 correction suggérée',
    );
    return '$_temp0';
  }

  @override
  String recogAcceptAllCount(int count) {
    return 'Tout accepter ($count)';
  }

  @override
  String recogAcceptedAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count corrections acceptées',
      one: '1 correction acceptée',
    );
    return '$_temp0. Les fichiers se mettent à jour en arrière-plan.';
  }

  @override
  String get recogNoProposalsHint => 'Il n’y a plus rien à vérifier.';

  @override
  String get logToday => 'Aujourd’hui';

  @override
  String get logYesterday => 'Hier';

  @override
  String logDayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entrées',
      one: '1 entrée',
    );
    return '$_temp0';
  }

  @override
  String get logRetention => 'Le journal garde les 30 derniers jours.';

  @override
  String get logNoMatch => 'Aucune entrée avec ce filtre.';

  @override
  String get logPickEntry => 'Choisissez une entrée pour voir les détails.';

  @override
  String get logFilterAll => 'Tout';

  @override
  String get logFilterDownload => 'Téléchargements';

  @override
  String get logFilterLibrary => 'Bibliothèque';

  @override
  String get logFilterEnrich => 'Enrichissement';

  @override
  String get logFilterCorrections => 'Corrections';

  @override
  String get logFilterErrors => 'Erreurs';

  @override
  String get logFailedLabel => 'Échec';

  @override
  String get logStoppedLabel => 'Arrêté';

  @override
  String get logClearMenu => 'Vider le journal';

  @override
  String get logClearTitle => 'Vider le journal ?';

  @override
  String get logClearConfirm => 'Vider';

  @override
  String get logPendingSub => 'Corrections proposées pour vos titres';

  @override
  String get logPendingReview => 'Examiner';

  @override
  String logPendingMore(int count) {
    return 'et $count autres';
  }

  @override
  String get logHowTitle => 'Comment corriger';

  @override
  String get logTechTitle => 'Détail technique';

  @override
  String get logOpenSongs => 'Voir les titres';

  @override
  String logHowSettings(String settings, String page) {
    return 'Ouvrez $settings, puis « $page ».';
  }

  @override
  String logHowUpdate(String button) {
    return 'Touchez « $button » à côté de yt-dlp.';
  }

  @override
  String get logHowWait => 'Attendez quelques minutes.';

  @override
  String get logHowOnline => 'Vérifiez que vous êtes en ligne.';

  @override
  String get logDlDone => 'Titre téléchargé';

  @override
  String get logDlFailed => 'Téléchargement échoué';

  @override
  String logDlGroup(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres téléchargés',
      one: '1 titre téléchargé',
    );
    return '$_temp0';
  }

  @override
  String get logDlGroupShow => 'Afficher les titres';

  @override
  String get logDlGroupHide => 'Masquer les titres';

  @override
  String get logTransferDone => 'Titres envoyés';

  @override
  String get logTransferFailed => 'Envoi échoué';

  @override
  String get logScanDone => 'Bibliothèque mise à jour';

  @override
  String get logScanDoneSub => 'Tous les dossiers ont été vérifiés.';

  @override
  String get logScanStopped => 'Analyse arrêtée';

  @override
  String get logScanFailed => 'Analyse échouée';

  @override
  String get logStoppedSub => 'Il s’est arrêté avant la fin.';

  @override
  String get logFailedSub => 'Il s’est arrêté à cause d’une erreur.';

  @override
  String get logEnrichDone => 'Enrichissement terminé';

  @override
  String get logEnrichInterrupted => 'Enrichissement interrompu';

  @override
  String get logEnrichInterruptedSub =>
      'Il s’est arrêté à cause d’une erreur ; le travail fait est sauvegardé.';

  @override
  String get logBgDone => 'Paroles et pochettes ajoutées';

  @override
  String get logBgDoneSub => 'Complétion en arrière-plan.';

  @override
  String get logBgStopped => 'Complétion arrêtée';

  @override
  String get logBgStoppedSub => 'Aucune source ne répond pour le moment.';

  @override
  String get logBgFailed => 'Complétion échouée';

  @override
  String get logBgFailedSub => 'Une erreur l’a arrêtée.';

  @override
  String get logSecondOpinion => 'Second avis de YouTube Music';

  @override
  String get logSecondOpinionSub => 'Les titres incertains ont été vérifiés.';

  @override
  String get logSecondOpinionFailed => 'Second avis interrompu';

  @override
  String get logCleanup => 'Doublons recherchés';

  @override
  String get logCleanupSub => 'Les titres de la bibliothèque ont été comparés.';

  @override
  String get logGenres => 'Genres des titres relus';

  @override
  String get logGenresSub =>
      'Les tags des titres ont été relus pour trouver tous les genres.';

  @override
  String get logCountries => 'Pays des artistes recherchés';

  @override
  String get logCountriesSub =>
      'Le pays d’origine des artistes de la bibliothèque a été recherché.';

  @override
  String get logReleases => 'Nouveautés vérifiées';

  @override
  String get logReleasesSub =>
      'Nouveautés des artistes que vous suivez recherchées.';

  @override
  String get logPodcasts => 'Podcasts mis à jour';

  @override
  String get logRadio => 'Radios vérifiées';

  @override
  String get logTaskFailed => 'Tâche échouée';

  @override
  String logImportDone(String name) {
    return 'Playlist « $name » importée';
  }

  @override
  String logImportReady(String name) {
    return 'Playlist « $name » prête';
  }

  @override
  String get logImportFailed => 'Import échoué';

  @override
  String get logImportRate => 'Import ralenti par YouTube';

  @override
  String get logImportPaused => 'Import en pause';

  @override
  String get logWhyToolMissing =>
      'Le composant pour télécharger depuis YouTube est absent.';

  @override
  String get logWhyToolOld =>
      'Le composant pour télécharger depuis YouTube est trop ancien.';

  @override
  String get logWhyNetwork => 'Réseau indisponible.';

  @override
  String get logWhyRate => 'YouTube a demandé de ralentir.';

  @override
  String get logWhyFailing =>
      'Trop d’erreurs d’affilée : je l’ai mise en pause.';

  @override
  String get logCorrectionTitle => 'Titre et artiste corrigés';

  @override
  String logChipSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres',
      one: '1 titre',
    );
    return '$_temp0';
  }

  @override
  String logChipArtists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artistes',
      one: '1 artiste',
    );
    return '$_temp0';
  }

  @override
  String logChipSongsOf(int done, int total) {
    return '$done sur $total titres';
  }

  @override
  String logChipUpdated(int count) {
    return '$count mis à jour';
  }

  @override
  String logChipNotFound(int count) {
    return '$count introuvables';
  }

  @override
  String logChipNoResult(int count) {
    return '$count sans résultat';
  }

  @override
  String get logFileTitle => 'Correction enregistrée, fichier non mis à jour';

  @override
  String get logHowFileMissing =>
      'Vérifiez que le titre est toujours dans son dossier.';

  @override
  String get logHowFileReadOnly =>
      'Retirez la lecture seule du fichier ou de son dossier, puis corrigez de nouveau le titre.';

  @override
  String get logHowFileRetry =>
      'Vérifiez qu’il reste de la place sur le disque et que le fichier n’est pas utilisé, puis corrigez de nouveau le titre.';

  @override
  String get logClearBody =>
      'Toutes les entrées sont supprimées et les téléchargements terminés quittent la liste. Vous ne pourrez plus rétablir les corrections. Vos titres restent où ils sont.';

  @override
  String logHowResume(String button) {
    return 'Touchez « $button » sur l’import en pause, dans la liste des activités.';
  }

  @override
  String get logEnrichStopped => 'Enrichissement arrêté';

  @override
  String logCorrectionSem(String from, String to) {
    return 'De $from à $to';
  }

  @override
  String get smartAll => 'Toutes les conditions';

  @override
  String get smartAny => 'Au moins une';

  @override
  String get smartAllNote => 'Les titres doivent respecter tous les filtres.';

  @override
  String get smartAnyNote => 'Un seul filtre suffit.';

  @override
  String get smartAddFilter => 'Ajouter un filtre';

  @override
  String get smartGroupMusic => 'Musique';

  @override
  String get smartGroupListening => 'Écoute';

  @override
  String get smartGroupFile => 'Fichier';

  @override
  String get smartFieldTag => 'Tags';

  @override
  String get smartFieldAlbumArtist => 'Artiste de l’album';

  @override
  String get smartFieldCountry => 'Nationalité';

  @override
  String get smartFieldPlays => 'Écoutes';

  @override
  String get smartFieldLastPlayed => 'Dernière écoute';

  @override
  String get smartFieldAdded => 'Ajouté';

  @override
  String get smartFieldBitrate => 'Débit';

  @override
  String get smartFieldFolder => 'Dossier';

  @override
  String get smartFlagLyrics => 'Avec paroles';

  @override
  String get smartEnrichedOnly => 'Seulement pour les titres enrichis';

  @override
  String get smartInclude => 'Inclure';

  @override
  String get smartExclude => 'Exclure';

  @override
  String get smartPickValues => 'Choisir des valeurs';

  @override
  String get smartAddValue => 'Ajouter';

  @override
  String get smartValueHint => 'Saisissez une valeur';

  @override
  String get smartDone => 'Terminé';

  @override
  String get smartIncomplete =>
      'Incomplet : terminez-le ou retirez-le pour enregistrer.';

  @override
  String get smartRemoveFilter => 'Retirer le filtre';

  @override
  String smartRemoveValue(String value) {
    return 'Retirer $value';
  }

  @override
  String get smartFrom => 'De';

  @override
  String get smartTo => 'À';

  @override
  String get smartMoreThan => 'Plus de';

  @override
  String get smartLessThan => 'Moins de';

  @override
  String get smartEqualTo => 'Égal à';

  @override
  String get smartAgeRecent => 'Dans les derniers';

  @override
  String get smartAgeOlder => 'Depuis plus de';

  @override
  String get smartDays => 'jours';

  @override
  String get smartMinutes => 'minutes';

  @override
  String get smartContains => 'Contient';

  @override
  String get smartAdvancedNote => 'Le texte de la règle, en lecture seule.';

  @override
  String get smartNotVisual =>
      'Cette règle est trop élaborée pour l’éditeur de filtres. Elle reste telle quelle : vous la voyez dans Avancé et, enregistrée sans modification, elle ne change pas.';

  @override
  String get smartNoFilters => 'Ajoutez un filtre pour commencer.';

  @override
  String get smartLimitShort => 'Maximum';

  @override
  String get smartIs => 'Est';

  @override
  String get smartRestart => 'Recommencer avec des filtres';

  @override
  String get smartRestarted => 'Règle effacée';

  @override
  String get smartCountError => 'Décompte indisponible';

  @override
  String artistMergedNote(int count) {
    return '$count profils réunis';
  }

  @override
  String get artistSplit => 'Séparer les profils';

  @override
  String get artistMergeWith => 'Réunir avec…';

  @override
  String artistSameWarn(String name) {
    return 'Il semble s’agir du même artiste qu’un autre profil ($name).';
  }

  @override
  String get artistMergeYes => 'Réunir';

  @override
  String get artistNotSame => 'Ils sont différents';

  @override
  String get artistMerged => 'Profils réunis.';

  @override
  String get artistSplitDone => 'Profils séparés.';

  @override
  String get artistNotSameDone =>
      'D’accord, je ne redemanderai plus pour ces deux profils.';

  @override
  String get artistMergePick => 'Avec quel profil ?';

  @override
  String get mergedSheetTitle => 'Profils réunis';

  @override
  String get artistMainProfile => 'Principal';

  @override
  String artistOtherProfileOf(String name) {
    return 'Autre profil de $name';
  }

  @override
  String get artistSeparate => 'Séparer';

  @override
  String get artistSeparated => 'Profil séparé.';

  @override
  String get settingsMergedArtists => 'Artistes réunis';

  @override
  String get settingsMergedArtistsHint =>
      'Voir les profils réunis et les séparer, ou retirer les marques « différents ».';

  @override
  String get mergedArtistsEmpty => 'Aucun artiste réuni.';

  @override
  String get mergedArtistsEmptyHelp =>
      'Quand vous réunissez deux profils du même artiste, ils apparaissent ici.';

  @override
  String get mergedArtistsSplitAll => 'Tout séparer';

  @override
  String get notSameTitle => 'Marqués comme différents';

  @override
  String get notSameRemove => 'Retirer';

  @override
  String get notSameEmpty => 'Aucune paire n’est marquée comme différente.';

  @override
  String get openArtistPage => 'Ouvrir la page de l’artiste';

  @override
  String get podcastYours => 'Vos podcasts';

  @override
  String get podcastDiscover => 'Découvrir';

  @override
  String get podcastChartTitle => 'Classement Apple Podcasts, Italie';

  @override
  String get podcastGenreAll => 'Tous';

  @override
  String get podcastSearchLens => 'Chercher un podcast';

  @override
  String get podcastSubscribedLabel => 'Abonné';

  @override
  String get podcastOriginApple => 'Apple Podcasts';

  @override
  String get podcastChartError =>
      'Le classement ne répond pas. Cela arrive, ce n’est pas de votre faute.';

  @override
  String get podcastNoFeed => 'Apple n’a pas de flux pour ce podcast.';

  @override
  String get podcastGenreArts => 'Arts';

  @override
  String get podcastGenreBusiness => 'Économie';

  @override
  String get podcastGenreComedy => 'Humour';

  @override
  String get podcastGenreEducation => 'Éducation';

  @override
  String get podcastGenreKids => 'Enfants et famille';

  @override
  String get podcastGenreHealth => 'Santé et forme';

  @override
  String get podcastGenreTvFilm => 'TV et cinéma';

  @override
  String get podcastGenreMusic => 'Musique';

  @override
  String get podcastGenreNews => 'Actualités';

  @override
  String get podcastGenreReligion => 'Religion et spiritualité';

  @override
  String get podcastGenreScience => 'Sciences';

  @override
  String get podcastGenreSports => 'Sport';

  @override
  String get podcastGenreTechnology => 'Technologie';

  @override
  String get podcastGenreSociety => 'Société et culture';

  @override
  String get podcastGenreGovernment => 'Gouvernement';

  @override
  String get podcastGenreHistory => 'Histoire';

  @override
  String get podcastGenreTrueCrime => 'True crime';

  @override
  String podcastSubscribeTo(String name) {
    return 'S’abonner à $name';
  }

  @override
  String get searchSimilarLooking => 'Recherche de morceaux similaires…';

  @override
  String searchSimilarQueued(String title) {
    return 'File : «$title» et morceaux similaires';
  }

  @override
  String searchSimilarNone(String title) {
    return 'Aucun morceau similaire : lecture de «$title» seul';
  }

  @override
  String get searchSeeQueue => 'Voir la file';

  @override
  String queueSimilarTo(String title) {
    return 'Similaires à «$title»';
  }

  @override
  String get queueSimilarTag => 'radio de YouTube Music';

  @override
  String queueSimilarCount(int total, int owned) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total morceaux',
      one: '1 morceau',
    );
    return '$_temp0, $owned déjà dans la bibliothèque';
  }

  @override
  String get queueSimilarSearching => 'Recherche de morceaux similaires…';

  @override
  String get dislikeSheetTitle => 'Vous n’aimez pas le titre ou l’artiste ?';

  @override
  String get dislikeSheetTrack => 'Seulement ce titre';

  @override
  String dislikeSheetTrackHint(String title) {
    return '« $title » ne reviendra pas, sauf s’il est très proche de ce que vous écoutez.';
  }

  @override
  String dislikeSheetArtist(String artist) {
    return 'Tout $artist';
  }

  @override
  String dislikeSheetArtistHint(String artist) {
    return 'Aucun titre de $artist ne vous sera plus suggéré.';
  }

  @override
  String dislikeArtistDone(String artist) {
    return '$artist ne vous sera plus suggéré';
  }

  @override
  String get artistBlockedLabel => 'Artiste bloqué';

  @override
  String dislikesBlockedOn(String date) {
    return 'Exclu le $date';
  }

  @override
  String get podcastFollow => 'Suivre';

  @override
  String get podcastFollowing => 'Suivi';

  @override
  String podcastFollowLabel(String name) {
    return 'Suivre $name';
  }

  @override
  String podcastUnfollowLabel(String name) {
    return 'Ne plus suivre $name';
  }

  @override
  String get podcastPreviewNote =>
      'Aperçu : vous ne le suivez pas encore. Les épisodes se lisent en streaming.';

  @override
  String get podcastPreviewFollowed =>
      'Il est maintenant dans vos podcasts. Votre position de reprise reste enregistrée.';

  @override
  String get podcastFollowedMsg => 'Ajouté à vos podcasts';

  @override
  String get podcastUnfollowedMsg =>
      'Vous ne le suivez plus. Les épisodes restent lisibles';

  @override
  String podcastPlayStream(String title) {
    return 'Lire en streaming : $title';
  }

  @override
  String get podcastStreamUnavailable =>
      'Ce podcast ne peut pas encore être lu en streaming.';

  @override
  String get podcastUnfollowTitle => 'Ne plus suivre ?';

  @override
  String podcastUnfollowBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Vous avez $count épisodes téléchargés. Les garder ou les supprimer ?',
      one: 'Vous avez 1 épisode téléchargé. Le garder ou le supprimer ?',
    );
    return '$_temp0';
  }

  @override
  String get podcastKeepDownloads => 'Garder';

  @override
  String get podcastDeleteDownloads => 'Supprimer';

  @override
  String get lyricsWrite => 'Écrire ou coller';

  @override
  String get lyricsWriteA11y => 'Écrire ou coller les paroles';

  @override
  String get lyricsEdit => 'Modifier les paroles';

  @override
  String get lyricsDelete => 'Supprimer les paroles';

  @override
  String get lyricsSyncSwitch => 'Paroles synchronisées';

  @override
  String get lyricsEditorTitle => 'Paroles du morceau';

  @override
  String get lyricsEditorLabel => 'Collez ou écrivez ici';

  @override
  String get lyricsEditorHint =>
      'Écrivez ou collez les paroles, une ligne par vers.';

  @override
  String get lyricsEditorInfo =>
      'Si les lignes commencent par un temps, comme [01:23.45], le texte est reconnu comme synchronisé et suit le morceau. Sinon il reste du texte simple. L’enregistrer ici empêche la recherche automatique de le remplacer.';

  @override
  String get lyricsEditorSaveA11y => 'Enregistrer les paroles';

  @override
  String get lyricsDetectNone => 'Rien à enregistrer pour l’instant';

  @override
  String lyricsDetectSynced(int count) {
    return 'Reconnu comme synchronisé : $count lignes avec temps';
  }

  @override
  String get lyricsDetectPlain => 'Texte simple, sans temps';

  @override
  String get lyricsEmptyWarn => 'Écrivez quelque chose avant d’enregistrer';

  @override
  String get lyricsSavedSynced => 'Paroles enregistrées, synchronisées';

  @override
  String get lyricsSavedPlain => 'Paroles enregistrées, texte simple';

  @override
  String get lyricsDeleted => 'Paroles supprimées';

  @override
  String get lyricsSyncedKept =>
      'La version synchronisée est conservée : réactivez-la depuis le menu.';
}
