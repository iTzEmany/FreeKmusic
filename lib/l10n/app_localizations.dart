import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('pt'),
  ];

  /// No description provided for @appName.
  ///
  /// In it, this message translates to:
  /// **'FreeKmusic'**
  String get appName;

  /// No description provided for @chooseFolder.
  ///
  /// In it, this message translates to:
  /// **'Scegli cartella'**
  String get chooseFolder;

  /// No description provided for @scan.
  ///
  /// In it, this message translates to:
  /// **'Scansiona'**
  String get scan;

  /// No description provided for @noTracks.
  ///
  /// In it, this message translates to:
  /// **'Nessun brano. Scegli una cartella e scansiona.'**
  String get noTracks;

  /// No description provided for @openSettings.
  ///
  /// In it, this message translates to:
  /// **'Apri impostazioni'**
  String get openSettings;

  /// No description provided for @permissionDenied.
  ///
  /// In it, this message translates to:
  /// **'Permesso di lettura audio negato'**
  String get permissionDenied;

  /// No description provided for @permissionExplain.
  ///
  /// In it, this message translates to:
  /// **'FreeKmusic ha bisogno del permesso di leggere i file audio per mostrare la tua musica.'**
  String get permissionExplain;

  /// No description provided for @navLibrary.
  ///
  /// In it, this message translates to:
  /// **'Libreria'**
  String get navLibrary;

  /// No description provided for @navFavorites.
  ///
  /// In it, this message translates to:
  /// **'Preferiti'**
  String get navFavorites;

  /// No description provided for @navPlaylists.
  ///
  /// In it, this message translates to:
  /// **'Playlist'**
  String get navPlaylists;

  /// No description provided for @navSettings.
  ///
  /// In it, this message translates to:
  /// **'Impostazioni'**
  String get navSettings;

  /// No description provided for @tracks.
  ///
  /// In it, this message translates to:
  /// **'Brani'**
  String get tracks;

  /// No description provided for @albums.
  ///
  /// In it, this message translates to:
  /// **'Album'**
  String get albums;

  /// No description provided for @artists.
  ///
  /// In it, this message translates to:
  /// **'Artisti'**
  String get artists;

  /// No description provided for @searchHint.
  ///
  /// In it, this message translates to:
  /// **'Cerca'**
  String get searchHint;

  /// No description provided for @clearSearch.
  ///
  /// In it, this message translates to:
  /// **'Cancella ricerca'**
  String get clearSearch;

  /// No description provided for @sortBy.
  ///
  /// In it, this message translates to:
  /// **'Ordina per'**
  String get sortBy;

  /// No description provided for @addMusicFolder.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi la tua cartella musicale'**
  String get addMusicFolder;

  /// No description provided for @addFolder.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi cartella'**
  String get addFolder;

  /// No description provided for @folders.
  ///
  /// In it, this message translates to:
  /// **'Cartelle musicali'**
  String get folders;

  /// No description provided for @refreshLibrary.
  ///
  /// In it, this message translates to:
  /// **'Aggiorna libreria'**
  String get refreshLibrary;

  /// No description provided for @removeFolder.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi cartella'**
  String get removeFolder;

  /// No description provided for @unknownArtist.
  ///
  /// In it, this message translates to:
  /// **'Artista sconosciuto'**
  String get unknownArtist;

  /// No description provided for @unknownAlbum.
  ///
  /// In it, this message translates to:
  /// **'Album sconosciuto'**
  String get unknownAlbum;

  /// No description provided for @variousArtists.
  ///
  /// In it, this message translates to:
  /// **'Artisti vari'**
  String get variousArtists;

  /// No description provided for @play.
  ///
  /// In it, this message translates to:
  /// **'Riproduci'**
  String get play;

  /// No description provided for @shuffle.
  ///
  /// In it, this message translates to:
  /// **'Casuale'**
  String get shuffle;

  /// No description provided for @queue.
  ///
  /// In it, this message translates to:
  /// **'Coda'**
  String get queue;

  /// No description provided for @nowPlaying.
  ///
  /// In it, this message translates to:
  /// **'In riproduzione'**
  String get nowPlaying;

  /// No description provided for @nothingPlaying.
  ///
  /// In it, this message translates to:
  /// **'Nessun brano in riproduzione'**
  String get nothingPlaying;

  /// No description provided for @mute.
  ///
  /// In it, this message translates to:
  /// **'Muto'**
  String get mute;

  /// No description provided for @scanning.
  ///
  /// In it, this message translates to:
  /// **'Scansione in corso…'**
  String get scanning;

  /// No description provided for @emptyQueue.
  ///
  /// In it, this message translates to:
  /// **'La coda è vuota'**
  String get emptyQueue;

  /// No description provided for @noResults.
  ///
  /// In it, this message translates to:
  /// **'Nessun risultato'**
  String get noResults;

  /// No description provided for @sortDefault.
  ///
  /// In it, this message translates to:
  /// **'Predefinito'**
  String get sortDefault;

  /// No description provided for @sortPersonal.
  ///
  /// In it, this message translates to:
  /// **'Ordine personale'**
  String get sortPersonal;

  /// No description provided for @sortTitle.
  ///
  /// In it, this message translates to:
  /// **'Titolo'**
  String get sortTitle;

  /// No description provided for @sortArtist.
  ///
  /// In it, this message translates to:
  /// **'Artista'**
  String get sortArtist;

  /// No description provided for @sortAlbum.
  ///
  /// In it, this message translates to:
  /// **'Album'**
  String get sortAlbum;

  /// No description provided for @sortYear.
  ///
  /// In it, this message translates to:
  /// **'Anno'**
  String get sortYear;

  /// No description provided for @sortAdded.
  ///
  /// In it, this message translates to:
  /// **'Aggiunti di recente'**
  String get sortAdded;

  /// No description provided for @sortDuration.
  ///
  /// In it, this message translates to:
  /// **'Durata'**
  String get sortDuration;

  /// No description provided for @tracksCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 brano} other{{count} brani}}'**
  String tracksCount(int count);

  /// No description provided for @albumsCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 album} other{{count} album}}'**
  String albumsCount(int count);

  /// No description provided for @libraryAll.
  ///
  /// In it, this message translates to:
  /// **'Tutto'**
  String get libraryAll;

  /// No description provided for @libraryItemsCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 elemento} other{{count} elementi}}'**
  String libraryItemsCount(int count);

  /// No description provided for @playlistsCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 playlist} other{{count} playlist}}'**
  String playlistsCount(int count);

  /// No description provided for @artistsCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 artista} other{{count} artisti}}'**
  String artistsCount(int count);

  /// No description provided for @minutesWords.
  ///
  /// In it, this message translates to:
  /// **'{n, plural, one{1 minuto} other{{n} minuti}}'**
  String minutesWords(int n);

  /// No description provided for @hoursWords.
  ///
  /// In it, this message translates to:
  /// **'{n, plural, one{1 ora} other{{n} ore}}'**
  String hoursWords(int n);

  /// No description provided for @hoursAndMinutes.
  ///
  /// In it, this message translates to:
  /// **'{hours} e {minutes}'**
  String hoursAndMinutes(String hours, String minutes);

  /// No description provided for @collectionNoTracks.
  ///
  /// In it, this message translates to:
  /// **'Nessun brano'**
  String get collectionNoTracks;

  /// No description provided for @missingTracksCount.
  ///
  /// In it, this message translates to:
  /// **'Brani non trovati ({count})'**
  String missingTracksCount(int count);

  /// No description provided for @addedToFavorites.
  ///
  /// In it, this message translates to:
  /// **'Aggiunto ai preferiti'**
  String get addedToFavorites;

  /// No description provided for @removedFromFavorites.
  ///
  /// In it, this message translates to:
  /// **'Rimosso dai preferiti'**
  String get removedFromFavorites;

  /// No description provided for @undo.
  ///
  /// In it, this message translates to:
  /// **'Annulla'**
  String get undo;

  /// No description provided for @favoritesEmptyTitle.
  ///
  /// In it, this message translates to:
  /// **'Nessun preferito, per ora'**
  String get favoritesEmptyTitle;

  /// No description provided for @favoritesEmptyHelp.
  ///
  /// In it, this message translates to:
  /// **'Tocca il cuore su un brano e lo trovi qui.'**
  String get favoritesEmptyHelp;

  /// No description provided for @openAllTracks.
  ///
  /// In it, this message translates to:
  /// **'Apri tutti i brani'**
  String get openAllTracks;

  /// No description provided for @newPlaylist.
  ///
  /// In it, this message translates to:
  /// **'Nuova playlist'**
  String get newPlaylist;

  /// No description provided for @newPlaylistEllipsis.
  ///
  /// In it, this message translates to:
  /// **'Nuova playlist…'**
  String get newPlaylistEllipsis;

  /// No description provided for @playlistName.
  ///
  /// In it, this message translates to:
  /// **'Nome della playlist'**
  String get playlistName;

  /// No description provided for @create.
  ///
  /// In it, this message translates to:
  /// **'Crea'**
  String get create;

  /// No description provided for @cancel.
  ///
  /// In it, this message translates to:
  /// **'Annulla'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In it, this message translates to:
  /// **'Salva'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In it, this message translates to:
  /// **'Elimina'**
  String get delete;

  /// No description provided for @rename.
  ///
  /// In it, this message translates to:
  /// **'Rinomina'**
  String get rename;

  /// No description provided for @noPlaylists.
  ///
  /// In it, this message translates to:
  /// **'Nessuna playlist. Creane una.'**
  String get noPlaylists;

  /// No description provided for @addToPlaylist.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi a playlist…'**
  String get addToPlaylist;

  /// No description provided for @addedToPlaylist.
  ///
  /// In it, this message translates to:
  /// **'Aggiunto a «{name}»'**
  String addedToPlaylist(String name);

  /// No description provided for @addToQueue.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi in coda'**
  String get addToQueue;

  /// No description provided for @addedToQueue.
  ///
  /// In it, this message translates to:
  /// **'Aggiunto in coda'**
  String get addedToQueue;

  /// No description provided for @favorite.
  ///
  /// In it, this message translates to:
  /// **'Preferito'**
  String get favorite;

  /// No description provided for @removeFromFavorites.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi dai preferiti'**
  String get removeFromFavorites;

  /// No description provided for @removeFromList.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi'**
  String get removeFromList;

  /// No description provided for @editInfo.
  ///
  /// In it, this message translates to:
  /// **'Modifica info'**
  String get editInfo;

  /// No description provided for @details.
  ///
  /// In it, this message translates to:
  /// **'Dettagli'**
  String get details;

  /// No description provided for @showInFolder.
  ///
  /// In it, this message translates to:
  /// **'Mostra nella cartella'**
  String get showInFolder;

  /// No description provided for @detailPath.
  ///
  /// In it, this message translates to:
  /// **'Percorso'**
  String get detailPath;

  /// No description provided for @detailFormat.
  ///
  /// In it, this message translates to:
  /// **'Formato'**
  String get detailFormat;

  /// No description provided for @detailSize.
  ///
  /// In it, this message translates to:
  /// **'Dimensione'**
  String get detailSize;

  /// No description provided for @detailDuration.
  ///
  /// In it, this message translates to:
  /// **'Durata'**
  String get detailDuration;

  /// No description provided for @detailAdded.
  ///
  /// In it, this message translates to:
  /// **'Aggiunto il'**
  String get detailAdded;

  /// No description provided for @detailPlays.
  ///
  /// In it, this message translates to:
  /// **'Riproduzioni'**
  String get detailPlays;

  /// No description provided for @close.
  ///
  /// In it, this message translates to:
  /// **'Chiudi'**
  String get close;

  /// No description provided for @fieldTitle.
  ///
  /// In it, this message translates to:
  /// **'Titolo'**
  String get fieldTitle;

  /// No description provided for @fieldArtist.
  ///
  /// In it, this message translates to:
  /// **'Artista'**
  String get fieldArtist;

  /// No description provided for @fieldAlbum.
  ///
  /// In it, this message translates to:
  /// **'Album'**
  String get fieldAlbum;

  /// No description provided for @fieldAlbumArtist.
  ///
  /// In it, this message translates to:
  /// **'Artista album'**
  String get fieldAlbumArtist;

  /// No description provided for @fieldYear.
  ///
  /// In it, this message translates to:
  /// **'Anno'**
  String get fieldYear;

  /// No description provided for @fieldTrackNumber.
  ///
  /// In it, this message translates to:
  /// **'Numero traccia'**
  String get fieldTrackNumber;

  /// No description provided for @fieldGenre.
  ///
  /// In it, this message translates to:
  /// **'Genere'**
  String get fieldGenre;

  /// No description provided for @restoreFromFile.
  ///
  /// In it, this message translates to:
  /// **'Ripristina dai tag del file'**
  String get restoreFromFile;

  /// No description provided for @titleRequired.
  ///
  /// In it, this message translates to:
  /// **'Il titolo non può essere vuoto'**
  String get titleRequired;

  /// No description provided for @settingsAppearance.
  ///
  /// In it, this message translates to:
  /// **'Aspetto'**
  String get settingsAppearance;

  /// No description provided for @settingsTheme.
  ///
  /// In it, this message translates to:
  /// **'Tema'**
  String get settingsTheme;

  /// No description provided for @themeNotte.
  ///
  /// In it, this message translates to:
  /// **'Notte viola'**
  String get themeNotte;

  /// No description provided for @themeOled.
  ///
  /// In it, this message translates to:
  /// **'Nero puro'**
  String get themeOled;

  /// No description provided for @settingsTextSize.
  ///
  /// In it, this message translates to:
  /// **'Dimensione testo'**
  String get settingsTextSize;

  /// No description provided for @textSmall.
  ///
  /// In it, this message translates to:
  /// **'Piccolo'**
  String get textSmall;

  /// No description provided for @textNormal.
  ///
  /// In it, this message translates to:
  /// **'Normale'**
  String get textNormal;

  /// No description provided for @textLarge.
  ///
  /// In it, this message translates to:
  /// **'Grande'**
  String get textLarge;

  /// No description provided for @settingsCompact.
  ///
  /// In it, this message translates to:
  /// **'Modalità compatta'**
  String get settingsCompact;

  /// No description provided for @settingsReducedMotion.
  ///
  /// In it, this message translates to:
  /// **'Animazioni ridotte'**
  String get settingsReducedMotion;

  /// No description provided for @settingsLanguage.
  ///
  /// In it, this message translates to:
  /// **'Lingua'**
  String get settingsLanguage;

  /// No description provided for @settingsLibrary.
  ///
  /// In it, this message translates to:
  /// **'Libreria'**
  String get settingsLibrary;

  /// No description provided for @rescanNow.
  ///
  /// In it, this message translates to:
  /// **'Riscansiona ora'**
  String get rescanNow;

  /// No description provided for @clearCoverCache.
  ///
  /// In it, this message translates to:
  /// **'Svuota cache copertine'**
  String get clearCoverCache;

  /// No description provided for @coverCacheCleared.
  ///
  /// In it, this message translates to:
  /// **'Cache copertine svuotata'**
  String get coverCacheCleared;

  /// No description provided for @settingsOnline.
  ///
  /// In it, this message translates to:
  /// **'Online'**
  String get settingsOnline;

  /// No description provided for @settingsPageAppearance.
  ///
  /// In it, this message translates to:
  /// **'Aspetto e lingua'**
  String get settingsPageAppearance;

  /// No description provided for @settingsPagePlayback.
  ///
  /// In it, this message translates to:
  /// **'Riproduzione'**
  String get settingsPagePlayback;

  /// No description provided for @settingsPageLibrary.
  ///
  /// In it, this message translates to:
  /// **'Libreria'**
  String get settingsPageLibrary;

  /// No description provided for @settingsPageOnline.
  ///
  /// In it, this message translates to:
  /// **'Online e download'**
  String get settingsPageOnline;

  /// No description provided for @settingsPageNetwork.
  ///
  /// In it, this message translates to:
  /// **'Rete e dispositivi'**
  String get settingsPageNetwork;

  /// No description provided for @settingsPageBackup.
  ///
  /// In it, this message translates to:
  /// **'Backup'**
  String get settingsPageBackup;

  /// No description provided for @settingsPageAdvanced.
  ///
  /// In it, this message translates to:
  /// **'Avanzate e info'**
  String get settingsPageAdvanced;

  /// No description provided for @summaryLibrary.
  ///
  /// In it, this message translates to:
  /// **'{folders, plural, =1{1 cartella} other{{folders} cartelle}}, {tracks, plural, =1{1 brano} other{{tracks} brani}}'**
  String summaryLibrary(int folders, int tracks);

  /// No description provided for @summaryTrusted.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 dispositivo fidato} other{{count} dispositivi fidati}}'**
  String summaryTrusted(int count);

  /// No description provided for @summaryNormalizeOn.
  ///
  /// In it, this message translates to:
  /// **'normalizzazione accesa'**
  String get summaryNormalizeOn;

  /// No description provided for @summaryBackup.
  ///
  /// In it, this message translates to:
  /// **'Esporta e ripristina la libreria'**
  String get summaryBackup;

  /// No description provided for @summaryCrossfade.
  ///
  /// In it, this message translates to:
  /// **'{seconds} s'**
  String summaryCrossfade(int seconds);

  /// No description provided for @openPlaybackSettings.
  ///
  /// In it, this message translates to:
  /// **'Apri Riproduzione'**
  String get openPlaybackSettings;

  /// No description provided for @autoEnrich.
  ///
  /// In it, this message translates to:
  /// **'Arricchimento automatico'**
  String get autoEnrich;

  /// No description provided for @autoEnrichHint.
  ///
  /// In it, this message translates to:
  /// **'Cerca metadati e copertine online per i brani nuovi'**
  String get autoEnrichHint;

  /// No description provided for @autoLyrics.
  ///
  /// In it, this message translates to:
  /// **'Testi automatici'**
  String get autoLyrics;

  /// No description provided for @autoLyricsHint.
  ///
  /// In it, this message translates to:
  /// **'Scarica i testi da LRCLIB per i brani nuovi'**
  String get autoLyricsHint;

  /// No description provided for @settingsAbout.
  ///
  /// In it, this message translates to:
  /// **'Info'**
  String get settingsAbout;

  /// No description provided for @appVersion.
  ///
  /// In it, this message translates to:
  /// **'Versione {version}'**
  String appVersion(String version);

  /// No description provided for @licenses.
  ///
  /// In it, this message translates to:
  /// **'Licenze'**
  String get licenses;

  /// No description provided for @personalUse.
  ///
  /// In it, this message translates to:
  /// **'App per uso personale'**
  String get personalUse;

  /// No description provided for @missingTracksTitle.
  ///
  /// In it, this message translates to:
  /// **'Brani non trovati'**
  String get missingTracksTitle;

  /// No description provided for @removeFromLibrary.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi dalla libreria'**
  String get removeFromLibrary;

  /// No description provided for @ignore.
  ///
  /// In it, this message translates to:
  /// **'Ignora'**
  String get ignore;

  /// No description provided for @confirmRemoveTitle.
  ///
  /// In it, this message translates to:
  /// **'Rimuovere dalla libreria?'**
  String get confirmRemoveTitle;

  /// No description provided for @confirmRemoveBody.
  ///
  /// In it, this message translates to:
  /// **'Il file non viene toccato; perdi preferiti e playlist di questo brano.'**
  String get confirmRemoveBody;

  /// No description provided for @noMissingTracks.
  ///
  /// In it, this message translates to:
  /// **'Nessun brano mancante'**
  String get noMissingTracks;

  /// No description provided for @retry.
  ///
  /// In it, this message translates to:
  /// **'Riprova'**
  String get retry;

  /// No description provided for @scanFailed.
  ///
  /// In it, this message translates to:
  /// **'Scansione non riuscita: {error}'**
  String scanFailed(String error);

  /// No description provided for @playbackError.
  ///
  /// In it, this message translates to:
  /// **'Impossibile riprodurre «{title}»: {reason}'**
  String playbackError(String reason, String title);

  /// No description provided for @reasonFileMissing.
  ///
  /// In it, this message translates to:
  /// **'file non trovato'**
  String get reasonFileMissing;

  /// No description provided for @reasonUnplayable.
  ///
  /// In it, this message translates to:
  /// **'file non riproducibile'**
  String get reasonUnplayable;

  /// No description provided for @reasonNotInLibrary.
  ///
  /// In it, this message translates to:
  /// **'brano non presente in libreria'**
  String get reasonNotInLibrary;

  /// No description provided for @reasonOnlineUnavailable.
  ///
  /// In it, this message translates to:
  /// **'brano online non disponibile'**
  String get reasonOnlineUnavailable;

  /// No description provided for @reasonEpisodeUnavailable.
  ///
  /// In it, this message translates to:
  /// **'episodio non disponibile, controlla la connessione'**
  String get reasonEpisodeUnavailable;

  /// No description provided for @reasonAgeRestricted.
  ///
  /// In it, this message translates to:
  /// **'vietato ai minori, nessuna traccia audio trovata'**
  String get reasonAgeRestricted;

  /// No description provided for @searchWeb.
  ///
  /// In it, this message translates to:
  /// **'Cerca info sul web'**
  String get searchWeb;

  /// No description provided for @enrichPreviewTitle.
  ///
  /// In it, this message translates to:
  /// **'Anteprima informazioni'**
  String get enrichPreviewTitle;

  /// No description provided for @currentValue.
  ///
  /// In it, this message translates to:
  /// **'Attuale'**
  String get currentValue;

  /// No description provided for @proposedValue.
  ///
  /// In it, this message translates to:
  /// **'Proposto'**
  String get proposedValue;

  /// No description provided for @apply.
  ///
  /// In it, this message translates to:
  /// **'Applica'**
  String get apply;

  /// No description provided for @nothingFound.
  ///
  /// In it, this message translates to:
  /// **'Nessuna informazione trovata'**
  String get nothingFound;

  /// No description provided for @userEditedLocked.
  ///
  /// In it, this message translates to:
  /// **'Modificato da te: non viene sovrascritto'**
  String get userEditedLocked;

  /// No description provided for @fieldCover.
  ///
  /// In it, this message translates to:
  /// **'Copertina'**
  String get fieldCover;

  /// No description provided for @fieldLyrics.
  ///
  /// In it, this message translates to:
  /// **'Testo'**
  String get fieldLyrics;

  /// No description provided for @fieldCuriosity.
  ///
  /// In it, this message translates to:
  /// **'Curiosità'**
  String get fieldCuriosity;

  /// No description provided for @enrichAlbum.
  ///
  /// In it, this message translates to:
  /// **'Arricchisci album'**
  String get enrichAlbum;

  /// No description provided for @enrichLibrary.
  ///
  /// In it, this message translates to:
  /// **'Arricchisci tutta la libreria'**
  String get enrichLibrary;

  /// No description provided for @enrichRunning.
  ///
  /// In it, this message translates to:
  /// **'Arricchimento {done}/{total}'**
  String enrichRunning(int done, int total);

  /// No description provided for @enrichResult.
  ///
  /// In it, this message translates to:
  /// **'{updated} aggiornati, {notFound} non trovati'**
  String enrichResult(int notFound, int updated);

  /// No description provided for @enrichBusy.
  ///
  /// In it, this message translates to:
  /// **'Un arricchimento è già in corso'**
  String get enrichBusy;

  /// No description provided for @enrichNothingToDo.
  ///
  /// In it, this message translates to:
  /// **'Niente da arricchire: ai brani non manca nulla'**
  String get enrichNothingToDo;

  /// No description provided for @serviceUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Servizio non disponibile, riprova più tardi'**
  String get serviceUnavailable;

  /// No description provided for @lyrics.
  ///
  /// In it, this message translates to:
  /// **'Testo'**
  String get lyrics;

  /// No description provided for @searchLyrics.
  ///
  /// In it, this message translates to:
  /// **'Cerca testo'**
  String get searchLyrics;

  /// No description provided for @noLyrics.
  ///
  /// In it, this message translates to:
  /// **'Nessun testo disponibile'**
  String get noLyrics;

  /// No description provided for @lyricsNotFound.
  ///
  /// In it, this message translates to:
  /// **'Testo non trovato'**
  String get lyricsNotFound;

  /// No description provided for @copy.
  ///
  /// In it, this message translates to:
  /// **'Copia'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In it, this message translates to:
  /// **'Copiato'**
  String get copied;

  /// No description provided for @sourceWikipedia.
  ///
  /// In it, this message translates to:
  /// **'Fonte: Wikipedia (CC BY-SA)'**
  String get sourceWikipedia;

  /// No description provided for @youtube.
  ///
  /// In it, this message translates to:
  /// **'YouTube'**
  String get youtube;

  /// No description provided for @ytHint.
  ///
  /// In it, this message translates to:
  /// **'Cerca o incolla un link'**
  String get ytHint;

  /// No description provided for @ytDownload.
  ///
  /// In it, this message translates to:
  /// **'Scarica'**
  String get ytDownload;

  /// No description provided for @listenAction.
  ///
  /// In it, this message translates to:
  /// **'Ascolta'**
  String get listenAction;

  /// No description provided for @ytAlreadyInLibrary.
  ///
  /// In it, this message translates to:
  /// **'Già in libreria'**
  String get ytAlreadyInLibrary;

  /// No description provided for @ytNoResults.
  ///
  /// In it, this message translates to:
  /// **'Nessun risultato'**
  String get ytNoResults;

  /// No description provided for @ytQueued.
  ///
  /// In it, this message translates to:
  /// **'In coda'**
  String get ytQueued;

  /// No description provided for @ytDownloading.
  ///
  /// In it, this message translates to:
  /// **'Download in corso'**
  String get ytDownloading;

  /// No description provided for @ytDone.
  ///
  /// In it, this message translates to:
  /// **'Completato'**
  String get ytDone;

  /// No description provided for @ytFailed.
  ///
  /// In it, this message translates to:
  /// **'Non riuscito'**
  String get ytFailed;

  /// No description provided for @ytCancelled.
  ///
  /// In it, this message translates to:
  /// **'Annullato'**
  String get ytCancelled;

  /// No description provided for @ytClearCompleted.
  ///
  /// In it, this message translates to:
  /// **'Svuota completati'**
  String get ytClearCompleted;

  /// No description provided for @ytCancel.
  ///
  /// In it, this message translates to:
  /// **'Annulla download'**
  String get ytCancel;

  /// No description provided for @ytErrUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Video non disponibile (età/regione/privato)'**
  String get ytErrUnavailable;

  /// No description provided for @ytErrNetwork.
  ///
  /// In it, this message translates to:
  /// **'Rete non disponibile'**
  String get ytErrNetwork;

  /// No description provided for @ytErrChanged.
  ///
  /// In it, this message translates to:
  /// **'YouTube ha cambiato qualcosa: aggiorna l’app o il pacchetto'**
  String get ytErrChanged;

  /// No description provided for @ytNoFolder.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi prima una cartella musicale'**
  String get ytNoFolder;

  /// No description provided for @ytLegal.
  ///
  /// In it, this message translates to:
  /// **'Solo per uso personale. Rispetta i diritti d’autore e i termini di YouTube.'**
  String get ytLegal;

  /// No description provided for @useDefaultFolder.
  ///
  /// In it, this message translates to:
  /// **'Usa la cartella Musica del dispositivo'**
  String get useDefaultFolder;

  /// No description provided for @ytErrToolMissing.
  ///
  /// In it, this message translates to:
  /// **'yt-dlp non trovato: installalo (pip install -U yt-dlp) e riprova'**
  String get ytErrToolMissing;

  /// No description provided for @ytErrRateLimited.
  ///
  /// In it, this message translates to:
  /// **'YouTube ha chiesto di rallentare: riprova tra qualche minuto'**
  String get ytErrRateLimited;

  /// No description provided for @playlistChangeCover.
  ///
  /// In it, this message translates to:
  /// **'Cambia copertina'**
  String get playlistChangeCover;

  /// No description provided for @playlistRemoveCover.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi copertina'**
  String get playlistRemoveCover;

  /// No description provided for @coverTooLarge.
  ///
  /// In it, this message translates to:
  /// **'Immagine troppo grande (max 4 MB)'**
  String get coverTooLarge;

  /// No description provided for @addSongs.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi brani'**
  String get addSongs;

  /// No description provided for @addNSongs.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi ({count})'**
  String addNSongs(int count);

  /// No description provided for @allSongsInPlaylist.
  ///
  /// In it, this message translates to:
  /// **'Tutti i brani sono già nella playlist'**
  String get allSongsInPlaylist;

  /// No description provided for @shareTitle.
  ///
  /// In it, this message translates to:
  /// **'Condivisione'**
  String get shareTitle;

  /// No description provided for @shareSend.
  ///
  /// In it, this message translates to:
  /// **'Invia'**
  String get shareSend;

  /// No description provided for @shareReceive.
  ///
  /// In it, this message translates to:
  /// **'Ricevi'**
  String get shareReceive;

  /// No description provided for @shareAll.
  ///
  /// In it, this message translates to:
  /// **'Tutta la libreria'**
  String get shareAll;

  /// No description provided for @shareSelection.
  ///
  /// In it, this message translates to:
  /// **'Selezione ({count} brani)'**
  String shareSelection(int count);

  /// No description provided for @sharePick.
  ///
  /// In it, this message translates to:
  /// **'Scegli brani'**
  String get sharePick;

  /// No description provided for @shareStart.
  ///
  /// In it, this message translates to:
  /// **'Avvia condivisione'**
  String get shareStart;

  /// No description provided for @shareStop.
  ///
  /// In it, this message translates to:
  /// **'Ferma'**
  String get shareStop;

  /// No description provided for @shareActive.
  ///
  /// In it, this message translates to:
  /// **'Condivisione attiva'**
  String get shareActive;

  /// No description provided for @shareAddress.
  ///
  /// In it, this message translates to:
  /// **'Indirizzo (IP:porta)'**
  String get shareAddress;

  /// No description provided for @sharePin.
  ///
  /// In it, this message translates to:
  /// **'PIN'**
  String get sharePin;

  /// No description provided for @shareConnect.
  ///
  /// In it, this message translates to:
  /// **'Connetti'**
  String get shareConnect;

  /// No description provided for @shareDownloadSelected.
  ///
  /// In it, this message translates to:
  /// **'Scarica selezionati ({count})'**
  String shareDownloadSelected(int count);

  /// No description provided for @shareProgress.
  ///
  /// In it, this message translates to:
  /// **'Brano {done} di {total}'**
  String shareProgress(int done, int total);

  /// No description provided for @shareDone.
  ///
  /// In it, this message translates to:
  /// **'{count} brani ricevuti'**
  String shareDone(int count);

  /// No description provided for @shareConnectedTo.
  ///
  /// In it, this message translates to:
  /// **'Connesso a {name}'**
  String shareConnectedTo(String name);

  /// No description provided for @shareErrUnreachable.
  ///
  /// In it, this message translates to:
  /// **'Dispositivo non raggiungibile: controlla indirizzo e Wi‑Fi'**
  String get shareErrUnreachable;

  /// No description provided for @shareErrPin.
  ///
  /// In it, this message translates to:
  /// **'PIN errato'**
  String get shareErrPin;

  /// No description provided for @shareErrBlocked.
  ///
  /// In it, this message translates to:
  /// **'Troppi tentativi: riprova tra un minuto'**
  String get shareErrBlocked;

  /// No description provided for @shareErrNotCodecore.
  ///
  /// In it, this message translates to:
  /// **'Non è un dispositivo FreeKmusic'**
  String get shareErrNotCodecore;

  /// No description provided for @shareErrFailed.
  ///
  /// In it, this message translates to:
  /// **'Trasferimento non riuscito'**
  String get shareErrFailed;

  /// No description provided for @shareNoNetwork.
  ///
  /// In it, this message translates to:
  /// **'Nessuna rete locale trovata'**
  String get shareNoNetwork;

  /// No description provided for @shareFirewall.
  ///
  /// In it, this message translates to:
  /// **'Windows può chiedere il permesso del firewall alla prima condivisione.'**
  String get shareFirewall;

  /// No description provided for @shareHint.
  ///
  /// In it, this message translates to:
  /// **'Sullo stesso Wi‑Fi, apri «Ricevi» sull’altro dispositivo e inserisci indirizzo e PIN.'**
  String get shareHint;

  /// No description provided for @shareMenu.
  ///
  /// In it, this message translates to:
  /// **'Condividi…'**
  String get shareMenu;

  /// No description provided for @shareDeviceName.
  ///
  /// In it, this message translates to:
  /// **'Nome dispositivo'**
  String get shareDeviceName;

  /// No description provided for @sleepTimer.
  ///
  /// In it, this message translates to:
  /// **'Timer di spegnimento'**
  String get sleepTimer;

  /// No description provided for @sleepMinutes.
  ///
  /// In it, this message translates to:
  /// **'{count} minuti'**
  String sleepMinutes(int count);

  /// No description provided for @sleepEndOfTrack.
  ///
  /// In it, this message translates to:
  /// **'A fine brano'**
  String get sleepEndOfTrack;

  /// No description provided for @sleepCancel.
  ///
  /// In it, this message translates to:
  /// **'Annulla timer'**
  String get sleepCancel;

  /// No description provided for @pause.
  ///
  /// In it, this message translates to:
  /// **'Pausa'**
  String get pause;

  /// No description provided for @nextTrack.
  ///
  /// In it, this message translates to:
  /// **'Brano successivo'**
  String get nextTrack;

  /// No description provided for @previousTrack.
  ///
  /// In it, this message translates to:
  /// **'Brano precedente'**
  String get previousTrack;

  /// No description provided for @repeat.
  ///
  /// In it, this message translates to:
  /// **'Ripeti'**
  String get repeat;

  /// No description provided for @moreOptions.
  ///
  /// In it, this message translates to:
  /// **'Altre opzioni'**
  String get moreOptions;

  /// No description provided for @back.
  ///
  /// In it, this message translates to:
  /// **'Indietro'**
  String get back;

  /// No description provided for @seekPosition.
  ///
  /// In it, this message translates to:
  /// **'Posizione nel brano'**
  String get seekPosition;

  /// No description provided for @settingsPlayback.
  ///
  /// In it, this message translates to:
  /// **'Riproduzione'**
  String get settingsPlayback;

  /// No description provided for @normalizeVolume.
  ///
  /// In it, this message translates to:
  /// **'Normalizza volume'**
  String get normalizeVolume;

  /// No description provided for @normalizeVolumeHint.
  ///
  /// In it, this message translates to:
  /// **'Usa il ReplayGain dei file per ridurre i brani troppo forti'**
  String get normalizeVolumeHint;

  /// No description provided for @nearbyDevices.
  ///
  /// In it, this message translates to:
  /// **'Dispositivi vicini'**
  String get nearbyDevices;

  /// No description provided for @searchingDevices.
  ///
  /// In it, this message translates to:
  /// **'Ricerca di dispositivi sulla rete…'**
  String get searchingDevices;

  /// No description provided for @noDevicesHint.
  ///
  /// In it, this message translates to:
  /// **'Nessun dispositivo trovato. Apri Condivisione anche sull’altro dispositivo, sulla stessa rete.'**
  String get noDevicesHint;

  /// No description provided for @sendToDevice.
  ///
  /// In it, this message translates to:
  /// **'Invia a {name}'**
  String sendToDevice(String name);

  /// No description provided for @offerSent.
  ///
  /// In it, this message translates to:
  /// **'Richiesta inviata a {name}'**
  String offerSent(String name);

  /// No description provided for @offerChooseFirst.
  ///
  /// In it, this message translates to:
  /// **'Scegli prima i brani da inviare'**
  String get offerChooseFirst;

  /// No description provided for @sentRequests.
  ///
  /// In it, this message translates to:
  /// **'Richieste inviate'**
  String get sentRequests;

  /// No description provided for @receivedRequests.
  ///
  /// In it, this message translates to:
  /// **'Richieste ricevute'**
  String get receivedRequests;

  /// No description provided for @offerPending.
  ///
  /// In it, this message translates to:
  /// **'In attesa di risposta'**
  String get offerPending;

  /// No description provided for @offerAccepted.
  ///
  /// In it, this message translates to:
  /// **'Accettata'**
  String get offerAccepted;

  /// No description provided for @offerDeclined.
  ///
  /// In it, this message translates to:
  /// **'Rifiutata'**
  String get offerDeclined;

  /// No description provided for @offerCancelled.
  ///
  /// In it, this message translates to:
  /// **'Annullata'**
  String get offerCancelled;

  /// No description provided for @offerExpired.
  ///
  /// In it, this message translates to:
  /// **'Scaduta'**
  String get offerExpired;

  /// No description provided for @offerDone.
  ///
  /// In it, this message translates to:
  /// **'Completata'**
  String get offerDone;

  /// No description provided for @offerFailed.
  ///
  /// In it, this message translates to:
  /// **'Non riuscita'**
  String get offerFailed;

  /// No description provided for @incomingTitle.
  ///
  /// In it, this message translates to:
  /// **'{name} vuole inviarti dei brani'**
  String incomingTitle(String name);

  /// No description provided for @incomingBody.
  ///
  /// In it, this message translates to:
  /// **'{count} brani, {size} MB'**
  String incomingBody(int count, String size);

  /// No description provided for @accept.
  ///
  /// In it, this message translates to:
  /// **'Accetta'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In it, this message translates to:
  /// **'Rifiuta'**
  String get decline;

  /// No description provided for @receivingProgress.
  ///
  /// In it, this message translates to:
  /// **'Ricezione {done}/{total}'**
  String receivingProgress(int done, int total);

  /// No description provided for @manualConnection.
  ///
  /// In it, this message translates to:
  /// **'Collegamento manuale (IP e PIN)'**
  String get manualConnection;

  /// No description provided for @receiveFromLan.
  ///
  /// In it, this message translates to:
  /// **'Ricevi dalla rete locale'**
  String get receiveFromLan;

  /// No description provided for @receiveFromLanHint.
  ///
  /// In it, this message translates to:
  /// **'Rende il dispositivo visibile e riceve richieste anche in background. Su Android mostra una notifica fissa con cui puoi disattivarlo'**
  String get receiveFromLanHint;

  /// No description provided for @receiveServiceTitle.
  ///
  /// In it, this message translates to:
  /// **'FreeKmusic è visibile sulla rete'**
  String get receiveServiceTitle;

  /// No description provided for @receiveServiceText.
  ///
  /// In it, this message translates to:
  /// **'Pronto a ricevere brani dai dispositivi vicini'**
  String get receiveServiceText;

  /// No description provided for @receiveServiceDisable.
  ///
  /// In it, this message translates to:
  /// **'Disattiva'**
  String get receiveServiceDisable;

  /// No description provided for @jamTitle.
  ///
  /// In it, this message translates to:
  /// **'Jam'**
  String get jamTitle;

  /// No description provided for @jamStart.
  ///
  /// In it, this message translates to:
  /// **'Avvia una Jam'**
  String get jamStart;

  /// No description provided for @jamStartWith.
  ///
  /// In it, this message translates to:
  /// **'Avvia Jam con {name}'**
  String jamStartWith(String name);

  /// No description provided for @jamWaiting.
  ///
  /// In it, this message translates to:
  /// **'In attesa che {name} accetti…'**
  String jamWaiting(String name);

  /// No description provided for @jamDeclined.
  ///
  /// In it, this message translates to:
  /// **'{name} ha rifiutato la Jam'**
  String jamDeclined(String name);

  /// No description provided for @jamBusy.
  ///
  /// In it, this message translates to:
  /// **'{name} ha già una Jam in corso'**
  String jamBusy(String name);

  /// No description provided for @jamUnreachable.
  ///
  /// In it, this message translates to:
  /// **'Dispositivo non raggiungibile'**
  String get jamUnreachable;

  /// No description provided for @jamIncomingTitle.
  ///
  /// In it, this message translates to:
  /// **'{name} vuole avviare una Jam'**
  String jamIncomingTitle(String name);

  /// No description provided for @jamIncomingBody.
  ///
  /// In it, this message translates to:
  /// **'Ascoltate insieme da una coda condivisa.'**
  String get jamIncomingBody;

  /// No description provided for @jamIncomingDialog.
  ///
  /// In it, this message translates to:
  /// **'La musica parte da questo dispositivo e potete aggiungere brani entrambi.'**
  String get jamIncomingDialog;

  /// No description provided for @jamQueue.
  ///
  /// In it, this message translates to:
  /// **'Coda condivisa'**
  String get jamQueue;

  /// No description provided for @jamModeHost.
  ///
  /// In it, this message translates to:
  /// **'Coda dell\'host'**
  String get jamModeHost;

  /// No description provided for @jamModeTogether.
  ///
  /// In it, this message translates to:
  /// **'Coda insieme'**
  String get jamModeTogether;

  /// No description provided for @jamModeGuestHint.
  ///
  /// In it, this message translates to:
  /// **'La modalità della coda la sceglie l\'host'**
  String get jamModeGuestHint;

  /// No description provided for @jamSuggested.
  ///
  /// In it, this message translates to:
  /// **'Suggerito'**
  String get jamSuggested;

  /// No description provided for @jamEmpty.
  ///
  /// In it, this message translates to:
  /// **'Metti in coda dalla libreria o dalla ricerca'**
  String get jamEmpty;

  /// No description provided for @jamOnlineFailed.
  ///
  /// In it, this message translates to:
  /// **'Impossibile aggiungere «{title}» alla Jam'**
  String jamOnlineFailed(String title);

  /// No description provided for @jamAddedBy.
  ///
  /// In it, this message translates to:
  /// **'aggiunto da {name}'**
  String jamAddedBy(String name);

  /// No description provided for @jamJumpHere.
  ///
  /// In it, this message translates to:
  /// **'Salta qui'**
  String get jamJumpHere;

  /// No description provided for @jamYou.
  ///
  /// In it, this message translates to:
  /// **'te'**
  String get jamYou;

  /// No description provided for @jamGuest.
  ///
  /// In it, this message translates to:
  /// **'Ospite'**
  String get jamGuest;

  /// No description provided for @jamAddToJam.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi alla Jam'**
  String get jamAddToJam;

  /// No description provided for @jamAdded.
  ///
  /// In it, this message translates to:
  /// **'Aggiunti alla Jam: {count}'**
  String jamAdded(int count);

  /// No description provided for @jamOutput.
  ///
  /// In it, this message translates to:
  /// **'Uscita audio'**
  String get jamOutput;

  /// No description provided for @jamOutputHere.
  ///
  /// In it, this message translates to:
  /// **'Questo dispositivo'**
  String get jamOutputHere;

  /// No description provided for @jamOutputOther.
  ///
  /// In it, this message translates to:
  /// **'{name}'**
  String jamOutputOther(String name);

  /// No description provided for @jamEnd.
  ///
  /// In it, this message translates to:
  /// **'Termina Jam'**
  String get jamEnd;

  /// No description provided for @jamLeave.
  ///
  /// In it, this message translates to:
  /// **'Esci dalla Jam'**
  String get jamLeave;

  /// No description provided for @jamEnded.
  ///
  /// In it, this message translates to:
  /// **'La Jam è terminata'**
  String get jamEnded;

  /// No description provided for @jamLost.
  ///
  /// In it, this message translates to:
  /// **'Connessione persa'**
  String get jamLost;

  /// No description provided for @jamGuestCannotSkip.
  ///
  /// In it, this message translates to:
  /// **'Solo chi ha avviato la Jam può cambiare brano'**
  String get jamGuestCannotSkip;

  /// No description provided for @jamRemoveForbidden.
  ///
  /// In it, this message translates to:
  /// **'Puoi rimuovere solo i tuoi brani'**
  String get jamRemoveForbidden;

  /// No description provided for @jamNothingPlaying.
  ///
  /// In it, this message translates to:
  /// **'Niente in riproduzione'**
  String get jamNothingPlaying;

  /// No description provided for @jamWith.
  ///
  /// In it, this message translates to:
  /// **'Jam con {name}'**
  String jamWith(String name);

  /// No description provided for @jamUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Non disponibile'**
  String get jamUnavailable;

  /// No description provided for @jamPlaying.
  ///
  /// In it, this message translates to:
  /// **'La Jam è attiva'**
  String get jamPlaying;

  /// No description provided for @jamOpen.
  ///
  /// In it, this message translates to:
  /// **'Apri la Jam'**
  String get jamOpen;

  /// No description provided for @jamSynced.
  ///
  /// In it, this message translates to:
  /// **'Sincronizzato, scarto {ms} ms'**
  String jamSynced(int ms);

  /// No description provided for @jamSyncing.
  ///
  /// In it, this message translates to:
  /// **'Sincronizzazione in corso…'**
  String get jamSyncing;

  /// No description provided for @jamLatency.
  ///
  /// In it, this message translates to:
  /// **'Latenza di questa uscita: {ms} ms'**
  String jamLatency(int ms);

  /// No description provided for @jamLatencyHint.
  ///
  /// In it, this message translates to:
  /// **'Per cuffie o casse Bluetooth: aumenta finché le uscite suonano insieme.'**
  String get jamLatencyHint;

  /// No description provided for @jamOutputsHint.
  ///
  /// In it, this message translates to:
  /// **'Più uscite suonano insieme'**
  String get jamOutputsHint;

  /// No description provided for @renamePlaylist.
  ///
  /// In it, this message translates to:
  /// **'Rinomina playlist'**
  String get renamePlaylist;

  /// No description provided for @confirmDeletePlaylistTitle.
  ///
  /// In it, this message translates to:
  /// **'Eliminare la playlist?'**
  String get confirmDeletePlaylistTitle;

  /// No description provided for @confirmDeletePlaylistBody.
  ///
  /// In it, this message translates to:
  /// **'«{name}» verrà eliminata. I brani restano nella libreria.'**
  String confirmDeletePlaylistBody(String name);

  /// No description provided for @confirmRemoveFolderTitle.
  ///
  /// In it, this message translates to:
  /// **'Rimuovere la cartella?'**
  String get confirmRemoveFolderTitle;

  /// No description provided for @confirmRemoveFolderBody.
  ///
  /// In it, this message translates to:
  /// **'I suoi brani spariscono dalla libreria. I file restano sul dispositivo.'**
  String get confirmRemoveFolderBody;

  /// No description provided for @confirmClearCoversTitle.
  ///
  /// In it, this message translates to:
  /// **'Svuotare la cache delle copertine?'**
  String get confirmClearCoversTitle;

  /// No description provided for @confirmClearCoversBody.
  ///
  /// In it, this message translates to:
  /// **'Le copertine verranno ricreate alla prossima scansione.'**
  String get confirmClearCoversBody;

  /// No description provided for @confirmRestoreTitle.
  ///
  /// In it, this message translates to:
  /// **'Ripristinare dai tag del file?'**
  String get confirmRestoreTitle;

  /// No description provided for @confirmRestoreBody.
  ///
  /// In it, this message translates to:
  /// **'Le tue modifiche a questo brano verranno sostituite con i dati del file.'**
  String get confirmRestoreBody;

  /// No description provided for @removedFromPlaylist.
  ///
  /// In it, this message translates to:
  /// **'Rimosso dalla playlist'**
  String get removedFromPlaylist;

  /// No description provided for @removedFromQueue.
  ///
  /// In it, this message translates to:
  /// **'Rimosso dalla coda'**
  String get removedFromQueue;

  /// No description provided for @ytSearchPrompt.
  ///
  /// In it, this message translates to:
  /// **'Cerca un brano o incolla un link'**
  String get ytSearchPrompt;

  /// No description provided for @loadFailed.
  ///
  /// In it, this message translates to:
  /// **'Non riesco a caricare i dati.'**
  String get loadFailed;

  /// Label of Play on an artist page while the song list loads or the queue starts
  ///
  /// In it, this message translates to:
  /// **'Carico i brani…'**
  String get artistLoadingSongs;

  /// Notice on an artist page when the top songs could not be read: only downloaded songs play
  ///
  /// In it, this message translates to:
  /// **'Top non disponibile'**
  String get artistTopMissing;

  /// No description provided for @navHome.
  ///
  /// In it, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navSearch.
  ///
  /// In it, this message translates to:
  /// **'Cerca'**
  String get navSearch;

  /// No description provided for @devicesTitle.
  ///
  /// In it, this message translates to:
  /// **'Dispositivi'**
  String get devicesTitle;

  /// No description provided for @devicesJamActive.
  ///
  /// In it, this message translates to:
  /// **'Jam attiva'**
  String get devicesJamActive;

  /// No description provided for @jamPeople.
  ///
  /// In it, this message translates to:
  /// **'{n, plural, one{Jam, 1 persona} other{Jam, {n} persone}}'**
  String jamPeople(int n);

  /// No description provided for @devicesVisibleTitle.
  ///
  /// In it, this message translates to:
  /// **'Rendi visibile questo dispositivo'**
  String get devicesVisibleTitle;

  /// No description provided for @devicesVisibleHint.
  ///
  /// In it, this message translates to:
  /// **'Per ricevere brani o fare una Jam, gli altri dispositivi devono poterti vedere sulla rete.'**
  String get devicesVisibleHint;

  /// No description provided for @devicesJamShort.
  ///
  /// In it, this message translates to:
  /// **'Jam'**
  String get devicesJamShort;

  /// No description provided for @devicesSendShort.
  ///
  /// In it, this message translates to:
  /// **'Invia'**
  String get devicesSendShort;

  /// No description provided for @devicesMore.
  ///
  /// In it, this message translates to:
  /// **'Condivisione e collegamento manuale'**
  String get devicesMore;

  /// No description provided for @jamParticipantsCount.
  ///
  /// In it, this message translates to:
  /// **'{n} persone'**
  String jamParticipantsCount(int n);

  /// No description provided for @playingFrom.
  ///
  /// In it, this message translates to:
  /// **'In riproduzione da'**
  String get playingFrom;

  /// No description provided for @playContextSearch.
  ///
  /// In it, this message translates to:
  /// **'Ricerca'**
  String get playContextSearch;

  /// No description provided for @allTracks.
  ///
  /// In it, this message translates to:
  /// **'Tutti i brani'**
  String get allTracks;

  /// No description provided for @trackInfo.
  ///
  /// In it, this message translates to:
  /// **'Info sul brano'**
  String get trackInfo;

  /// No description provided for @searchCuriosity.
  ///
  /// In it, this message translates to:
  /// **'Cerca curiosità'**
  String get searchCuriosity;

  /// No description provided for @upNext.
  ///
  /// In it, this message translates to:
  /// **'Prossimi'**
  String get upNext;

  /// No description provided for @openQueue.
  ///
  /// In it, this message translates to:
  /// **'Apri coda'**
  String get openQueue;

  /// No description provided for @copyLink.
  ///
  /// In it, this message translates to:
  /// **'Copia link'**
  String get copyLink;

  /// No description provided for @moreActions.
  ///
  /// In it, this message translates to:
  /// **'Altre azioni'**
  String get moreActions;

  /// No description provided for @sleepChipEnd.
  ///
  /// In it, this message translates to:
  /// **'fine brano'**
  String get sleepChipEnd;

  /// No description provided for @yourLibrary.
  ///
  /// In it, this message translates to:
  /// **'La tua libreria'**
  String get yourLibrary;

  /// No description provided for @playlistCountLabel.
  ///
  /// In it, this message translates to:
  /// **'{n, plural, one{Playlist di 1 brano} other{Playlist di {n} brani}}'**
  String playlistCountLabel(int n);

  /// No description provided for @sortRecent.
  ///
  /// In it, this message translates to:
  /// **'Ascoltati di recente'**
  String get sortRecent;

  /// No description provided for @sortAlphabetical.
  ///
  /// In it, this message translates to:
  /// **'Alfabetico'**
  String get sortAlphabetical;

  /// No description provided for @sortAToZ.
  ///
  /// In it, this message translates to:
  /// **'A–Z'**
  String get sortAToZ;

  /// No description provided for @sortAddedRecently.
  ///
  /// In it, this message translates to:
  /// **'Aggiunti di recente'**
  String get sortAddedRecently;

  /// No description provided for @sortTitleAToZ.
  ///
  /// In it, this message translates to:
  /// **'Titolo A–Z'**
  String get sortTitleAToZ;

  /// No description provided for @sortMostPlayed.
  ///
  /// In it, this message translates to:
  /// **'Più ascoltati'**
  String get sortMostPlayed;

  /// No description provided for @sortTrackCount.
  ///
  /// In it, this message translates to:
  /// **'Numero di brani'**
  String get sortTrackCount;

  /// No description provided for @sortRecentShort.
  ///
  /// In it, this message translates to:
  /// **'Recenti'**
  String get sortRecentShort;

  /// No description provided for @sortAddedShort.
  ///
  /// In it, this message translates to:
  /// **'Aggiunti'**
  String get sortAddedShort;

  /// No description provided for @sortTrackCountShort.
  ///
  /// In it, this message translates to:
  /// **'N. brani'**
  String get sortTrackCountShort;

  /// No description provided for @sortMostPlayedShort.
  ///
  /// In it, this message translates to:
  /// **'Più ascoltati'**
  String get sortMostPlayedShort;

  /// No description provided for @sortAscending.
  ///
  /// In it, this message translates to:
  /// **'Crescente'**
  String get sortAscending;

  /// No description provided for @sortDescending.
  ///
  /// In it, this message translates to:
  /// **'Decrescente'**
  String get sortDescending;

  /// No description provided for @viewAsGrid.
  ///
  /// In it, this message translates to:
  /// **'Mostra come griglia'**
  String get viewAsGrid;

  /// No description provided for @viewAsList.
  ///
  /// In it, this message translates to:
  /// **'Mostra come elenco'**
  String get viewAsList;

  /// No description provided for @kindAlbum.
  ///
  /// In it, this message translates to:
  /// **'Album'**
  String get kindAlbum;

  /// No description provided for @kindArtist.
  ///
  /// In it, this message translates to:
  /// **'Artista'**
  String get kindArtist;

  /// No description provided for @kindPlaylist.
  ///
  /// In it, this message translates to:
  /// **'Playlist'**
  String get kindPlaylist;

  /// No description provided for @discN.
  ///
  /// In it, this message translates to:
  /// **'Disco {n}'**
  String discN(int n);

  /// No description provided for @albumMeta.
  ///
  /// In it, this message translates to:
  /// **'Album, {details}'**
  String albumMeta(String details);

  /// No description provided for @durationMinutes.
  ///
  /// In it, this message translates to:
  /// **'{n} min'**
  String durationMinutes(int n);

  /// No description provided for @tracksAndDuration.
  ///
  /// In it, this message translates to:
  /// **'{tracks}, {duration}'**
  String tracksAndDuration(String tracks, String duration);

  /// No description provided for @mostPlayed.
  ///
  /// In it, this message translates to:
  /// **'Più ascoltati'**
  String get mostPlayed;

  /// No description provided for @albumsSection.
  ///
  /// In it, this message translates to:
  /// **'Album'**
  String get albumsSection;

  /// No description provided for @addAllToQueue.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi in coda'**
  String get addAllToQueue;

  /// No description provided for @addedNToQueue.
  ///
  /// In it, this message translates to:
  /// **'{n} brani aggiunti in coda'**
  String addedNToQueue(int n);

  /// No description provided for @editOrder.
  ///
  /// In it, this message translates to:
  /// **'Modifica ordine'**
  String get editOrder;

  /// No description provided for @finishEditing.
  ///
  /// In it, this message translates to:
  /// **'Fine'**
  String get finishEditing;

  /// No description provided for @removeFromPlaylistAction.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi dalla playlist'**
  String get removeFromPlaylistAction;

  /// No description provided for @noTracksInPlaylist.
  ///
  /// In it, this message translates to:
  /// **'Questa playlist è vuota'**
  String get noTracksInPlaylist;

  /// No description provided for @greetingMorning.
  ///
  /// In it, this message translates to:
  /// **'Buongiorno'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In it, this message translates to:
  /// **'Buon pomeriggio'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In it, this message translates to:
  /// **'Buonasera'**
  String get greetingEvening;

  /// No description provided for @homeResume.
  ///
  /// In it, this message translates to:
  /// **'Riprendi'**
  String get homeResume;

  /// No description provided for @homeTopTracks.
  ///
  /// In it, this message translates to:
  /// **'I più ascoltati'**
  String get homeTopTracks;

  /// No description provided for @homeRediscover.
  ///
  /// In it, this message translates to:
  /// **'Da riscoprire'**
  String get homeRediscover;

  /// No description provided for @homeShuffleAll.
  ///
  /// In it, this message translates to:
  /// **'Casuale su tutto'**
  String get homeShuffleAll;

  /// No description provided for @homeShuffleAllSub.
  ///
  /// In it, this message translates to:
  /// **'{tracks}, {hours}'**
  String homeShuffleAllSub(String tracks, String hours);

  /// No description provided for @hoursCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =0{meno di un’ora} one{1 ora} other{{count} ore}}'**
  String hoursCount(int count);

  /// No description provided for @homeAddedLately.
  ///
  /// In it, this message translates to:
  /// **'Aggiunti da poco'**
  String get homeAddedLately;

  /// No description provided for @homeResumeQueue.
  ///
  /// In it, this message translates to:
  /// **'Brano {n} di {m}'**
  String homeResumeQueue(int n, int m);

  /// No description provided for @homeResumeQueueFrom.
  ///
  /// In it, this message translates to:
  /// **'{source}: brano {n} di {m}'**
  String homeResumeQueueFrom(String source, int n, int m);

  /// No description provided for @homeMinutesLeft.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{Manca 1 minuto} other{Mancano {count} minuti}}'**
  String homeMinutesLeft(int count);

  /// No description provided for @homeEpisodeLeft.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{manca 1 min} other{mancano {count} min}}'**
  String homeEpisodeLeft(int count);

  /// No description provided for @homeFanOpen.
  ///
  /// In it, this message translates to:
  /// **'Mostra i brani aggiunti da poco'**
  String get homeFanOpen;

  /// No description provided for @showAll.
  ///
  /// In it, this message translates to:
  /// **'Tutti'**
  String get showAll;

  /// No description provided for @recentSearches.
  ///
  /// In it, this message translates to:
  /// **'Ricerche recenti'**
  String get recentSearches;

  /// No description provided for @genresTitle.
  ///
  /// In it, this message translates to:
  /// **'Generi'**
  String get genresTitle;

  /// No description provided for @downloadsChip.
  ///
  /// In it, this message translates to:
  /// **'Download ({n})'**
  String downloadsChip(int n);

  /// No description provided for @gotIt.
  ///
  /// In it, this message translates to:
  /// **'Ho capito'**
  String get gotIt;

  /// No description provided for @searchEmptyLibrary.
  ///
  /// In it, this message translates to:
  /// **'Nessun risultato in libreria'**
  String get searchEmptyLibrary;

  /// No description provided for @ytInfoTooltip.
  ///
  /// In it, this message translates to:
  /// **'Informazioni sull’uso'**
  String get ytInfoTooltip;

  /// No description provided for @removeRecentSearch.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi «{query}» dalle ricerche recenti'**
  String removeRecentSearch(String query);

  /// No description provided for @groupGoTo.
  ///
  /// In it, this message translates to:
  /// **'Vai a'**
  String get groupGoTo;

  /// No description provided for @goToAlbum.
  ///
  /// In it, this message translates to:
  /// **'Vai all’album'**
  String get goToAlbum;

  /// No description provided for @goToArtist.
  ///
  /// In it, this message translates to:
  /// **'Vai all’artista'**
  String get goToArtist;

  /// No description provided for @groupQueue.
  ///
  /// In it, this message translates to:
  /// **'Coda'**
  String get groupQueue;

  /// No description provided for @groupCollection.
  ///
  /// In it, this message translates to:
  /// **'Raccolta'**
  String get groupCollection;

  /// No description provided for @groupEdit.
  ///
  /// In it, this message translates to:
  /// **'Modifica'**
  String get groupEdit;

  /// No description provided for @groupOther.
  ///
  /// In it, this message translates to:
  /// **'Altro'**
  String get groupOther;

  /// No description provided for @queueNowPlaying.
  ///
  /// In it, this message translates to:
  /// **'In riproduzione'**
  String get queueNowPlaying;

  /// No description provided for @queueNext.
  ///
  /// In it, this message translates to:
  /// **'Prossimi'**
  String get queueNext;

  /// No description provided for @queueClear.
  ///
  /// In it, this message translates to:
  /// **'Svuota'**
  String get queueClear;

  /// No description provided for @queueCleared.
  ///
  /// In it, this message translates to:
  /// **'Coda svuotata'**
  String get queueCleared;

  /// No description provided for @queueRebuilt.
  ///
  /// In it, this message translates to:
  /// **'Coda ricreata dalla lista in ascolto'**
  String get queueRebuilt;

  /// No description provided for @jamOutputsAndSync.
  ///
  /// In it, this message translates to:
  /// **'Uscite e sincronia'**
  String get jamOutputsAndSync;

  /// No description provided for @jamHostTag.
  ///
  /// In it, this message translates to:
  /// **'host'**
  String get jamHostTag;

  /// No description provided for @jamSeekInvalid.
  ///
  /// In it, this message translates to:
  /// **'Posizione non valida per questo brano'**
  String get jamSeekInvalid;

  /// No description provided for @jamEndConfirmTitle.
  ///
  /// In it, this message translates to:
  /// **'Terminare la Jam per tutti?'**
  String get jamEndConfirmTitle;

  /// No description provided for @jamEndConfirmBody.
  ///
  /// In it, this message translates to:
  /// **'{n, plural, one{L’ospite verrà disconnesso e la coda condivisa verrà chiusa.} other{I {n} ospiti verranno disconnessi e la coda condivisa verrà chiusa.}}'**
  String jamEndConfirmBody(int n);

  /// No description provided for @jamEndConfirmAction.
  ///
  /// In it, this message translates to:
  /// **'Termina'**
  String get jamEndConfirmAction;

  /// No description provided for @jamParticipantsLabel.
  ///
  /// In it, this message translates to:
  /// **'{n, plural, one{1 partecipante: {names}} other{{n} partecipanti: {names}}}'**
  String jamParticipantsLabel(int n, String names);

  /// No description provided for @jamWaitingEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessuna Jam in corso'**
  String get jamWaitingEmpty;

  /// No description provided for @activityTitle.
  ///
  /// In it, this message translates to:
  /// **'Attività'**
  String get activityTitle;

  /// No description provided for @activityScan.
  ///
  /// In it, this message translates to:
  /// **'Scansione: {done} di {total}'**
  String activityScan(int done, int total);

  /// No description provided for @activityScanIdle.
  ///
  /// In it, this message translates to:
  /// **'Scansione in corso'**
  String get activityScanIdle;

  /// No description provided for @activityEnrich.
  ///
  /// In it, this message translates to:
  /// **'Arricchimento: {done} di {total}'**
  String activityEnrich(int done, int total);

  /// No description provided for @activityDownload.
  ///
  /// In it, this message translates to:
  /// **'Download, {title}'**
  String activityDownload(String title);

  /// No description provided for @activityTransfer.
  ///
  /// In it, this message translates to:
  /// **'Invio a {name}, {n} brani'**
  String activityTransfer(String name, int n);

  /// No description provided for @activityNone.
  ///
  /// In it, this message translates to:
  /// **'Nessuna attività'**
  String get activityNone;

  /// No description provided for @activityCompleted.
  ///
  /// In it, this message translates to:
  /// **'Completate'**
  String get activityCompleted;

  /// No description provided for @importPhaseSearching.
  ///
  /// In it, this message translates to:
  /// **'In ricerca…'**
  String get importPhaseSearching;

  /// No description provided for @importPhaseDownloading.
  ///
  /// In it, this message translates to:
  /// **'Download {percent} %'**
  String importPhaseDownloading(int percent);

  /// No description provided for @importPhaseRetry.
  ///
  /// In it, this message translates to:
  /// **'Nuovo tentativo tra {seconds} s'**
  String importPhaseRetry(int seconds);

  /// No description provided for @importPhaseEnriching.
  ///
  /// In it, this message translates to:
  /// **'Arricchimento…'**
  String get importPhaseEnriching;

  /// No description provided for @importPhaseDownloadStart.
  ///
  /// In it, this message translates to:
  /// **'Download…'**
  String get importPhaseDownloadStart;

  /// No description provided for @importFilterAll.
  ///
  /// In it, this message translates to:
  /// **'Tutti'**
  String get importFilterAll;

  /// No description provided for @importFilterActive.
  ///
  /// In it, this message translates to:
  /// **'In corso'**
  String get importFilterActive;

  /// No description provided for @importFilterProblems.
  ///
  /// In it, this message translates to:
  /// **'Da sistemare'**
  String get importFilterProblems;

  /// No description provided for @importFilterDone.
  ///
  /// In it, this message translates to:
  /// **'Fatti'**
  String get importFilterDone;

  /// No description provided for @importRowsNone.
  ///
  /// In it, this message translates to:
  /// **'Nessun brano qui'**
  String get importRowsNone;

  /// No description provided for @activityLog.
  ///
  /// In it, this message translates to:
  /// **'Registro'**
  String get activityLog;

  /// No description provided for @activityLogCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =0{Vuoto} =1{1 evento} other{{count} eventi}}'**
  String activityLogCount(int count);

  /// No description provided for @activityLogEmpty.
  ///
  /// In it, this message translates to:
  /// **'Niente da registrare per ora: qui compaiono download, importazioni e invii finiti.'**
  String get activityLogEmpty;

  /// No description provided for @logImport.
  ///
  /// In it, this message translates to:
  /// **'Importazione «{name}»'**
  String logImport(String name);

  /// No description provided for @importNotificationText.
  ///
  /// In it, this message translates to:
  /// **'{done} di {total}'**
  String importNotificationText(int done, int total);

  /// No description provided for @importNotificationPaused.
  ///
  /// In it, this message translates to:
  /// **'In pausa, {done} di {total}'**
  String importNotificationPaused(int done, int total);

  /// No description provided for @importWaitRateLimited.
  ///
  /// In it, this message translates to:
  /// **'YouTube chiede una pausa: riprendo alle {time}'**
  String importWaitRateLimited(String time);

  /// No description provided for @importWaitNetwork.
  ///
  /// In it, this message translates to:
  /// **'Rete assente: riprovo alle {time}'**
  String importWaitNetwork(String time);

  /// No description provided for @importPausedTitle.
  ///
  /// In it, this message translates to:
  /// **'Importazione «{name}» in pausa'**
  String importPausedTitle(String name);

  /// No description provided for @downloadsNotificationTitle.
  ///
  /// In it, this message translates to:
  /// **'Download in corso'**
  String get downloadsNotificationTitle;

  /// No description provided for @downloadsNotificationText.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 brano} other{{count} brani}}'**
  String downloadsNotificationText(int count);

  /// No description provided for @activityRunning.
  ///
  /// In it, this message translates to:
  /// **'{n} attività in corso'**
  String activityRunning(int n);

  /// No description provided for @settingsLocalNetwork.
  ///
  /// In it, this message translates to:
  /// **'Rete locale'**
  String get settingsLocalNetwork;

  /// No description provided for @removeAll.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi tutti'**
  String get removeAll;

  /// No description provided for @confirmRemoveAllTitle.
  ///
  /// In it, this message translates to:
  /// **'Rimuovere tutti dalla libreria?'**
  String get confirmRemoveAllTitle;

  /// No description provided for @confirmRemoveAllBody.
  ///
  /// In it, this message translates to:
  /// **'{n} brani non trovati verranno tolti dalla libreria. I file non vengono toccati; perdi preferiti e playlist di questi brani.'**
  String confirmRemoveAllBody(int n);

  /// No description provided for @csvImportMenu.
  ///
  /// In it, this message translates to:
  /// **'Importa da Exportify (CSV)'**
  String get csvImportMenu;

  /// No description provided for @csvImportIntroTitle.
  ///
  /// In it, this message translates to:
  /// **'Importa una playlist'**
  String get csvImportIntroTitle;

  /// No description provided for @csvImportIntroSource.
  ///
  /// In it, this message translates to:
  /// **'Il file CSV si crea gratis dal sito Exportify — exportify.net (non serve nessuna app).'**
  String get csvImportIntroSource;

  /// No description provided for @csvImportStep1.
  ///
  /// In it, this message translates to:
  /// **'Apri https://exportify.net nel browser (anche dal telefono).'**
  String get csvImportStep1;

  /// No description provided for @csvImportStep2.
  ///
  /// In it, this message translates to:
  /// **'Tocca «Get Started» e accedi con il tuo account Spotify.'**
  String get csvImportStep2;

  /// No description provided for @csvImportStep3.
  ///
  /// In it, this message translates to:
  /// **'Accanto alla playlist che vuoi tocca «Export»: si scarica un file .csv col nome della playlist.'**
  String get csvImportStep3;

  /// No description provided for @csvImportStep4.
  ///
  /// In it, this message translates to:
  /// **'Torna qui e tocca «Scegli file CSV».'**
  String get csvImportStep4;

  /// No description provided for @csvImportNote.
  ///
  /// In it, this message translates to:
  /// **'FreeKmusic cerca i brani nella tua libreria e scarica gli altri da YouTube Music.'**
  String get csvImportNote;

  /// No description provided for @csvImportNoteOffline.
  ///
  /// In it, this message translates to:
  /// **'Verranno collegati solo i brani già presenti nella tua libreria.'**
  String get csvImportNoteOffline;

  /// No description provided for @csvImportCopy.
  ///
  /// In it, this message translates to:
  /// **'Copia indirizzo'**
  String get csvImportCopy;

  /// No description provided for @csvImportCopied.
  ///
  /// In it, this message translates to:
  /// **'Indirizzo copiato'**
  String get csvImportCopied;

  /// No description provided for @csvImportPick.
  ///
  /// In it, this message translates to:
  /// **'Scegli file'**
  String get csvImportPick;

  /// No description provided for @csvImportNotExportify.
  ///
  /// In it, this message translates to:
  /// **'Formato non riconosciuto. Scegli un CSV (Exportify, TuneMyMusic, Soundiiz, Last.fm) o una playlist M3U/M3U8/XSPF.'**
  String get csvImportNotExportify;

  /// No description provided for @csvImportReadFailed.
  ///
  /// In it, this message translates to:
  /// **'Impossibile leggere il file.'**
  String get csvImportReadFailed;

  /// No description provided for @csvImportPreviewTitle.
  ///
  /// In it, this message translates to:
  /// **'Importa playlist'**
  String get csvImportPreviewTitle;

  /// No description provided for @csvImportName.
  ///
  /// In it, this message translates to:
  /// **'Nome della playlist'**
  String get csvImportName;

  /// No description provided for @csvImportSummary.
  ///
  /// In it, this message translates to:
  /// **'{total} brani, {known} già in libreria, {todo} da scaricare'**
  String csvImportSummary(int total, int known, int todo);

  /// No description provided for @csvImportSkipped.
  ///
  /// In it, this message translates to:
  /// **'{n} righe ignorate (podcast o file locali)'**
  String csvImportSkipped(int n);

  /// No description provided for @csvImportEstimate.
  ///
  /// In it, this message translates to:
  /// **'Tempo stimato: circa {minutes} min'**
  String csvImportEstimate(int minutes);

  /// No description provided for @csvImportExists.
  ///
  /// In it, this message translates to:
  /// **'Esiste già una playlist con questo nome'**
  String get csvImportExists;

  /// No description provided for @csvImportUpdate.
  ///
  /// In it, this message translates to:
  /// **'Aggiorna quella esistente (aggiunge solo i brani nuovi)'**
  String get csvImportUpdate;

  /// No description provided for @csvImportNew.
  ///
  /// In it, this message translates to:
  /// **'Crea una nuova playlist'**
  String get csvImportNew;

  /// No description provided for @csvImportGo.
  ///
  /// In it, this message translates to:
  /// **'Importa'**
  String get csvImportGo;

  /// No description provided for @csvImportStarted.
  ///
  /// In it, this message translates to:
  /// **'Importazione avviata: la segui nel Centro Attività'**
  String get csvImportStarted;

  /// No description provided for @activityImport.
  ///
  /// In it, this message translates to:
  /// **'Importazione «{name}»: {done} di {total}'**
  String activityImport(String name, int done, int total);

  /// No description provided for @activityImportPaused.
  ///
  /// In it, this message translates to:
  /// **'Importazione «{name}»: in pausa, {done} di {total}'**
  String activityImportPaused(String name, int done, int total);

  /// No description provided for @csvImportBanner.
  ///
  /// In it, this message translates to:
  /// **'Importazione: {done} di {total}, {review} da verificare, {missing} non trovati'**
  String csvImportBanner(int done, int total, int review, int missing);

  /// No description provided for @csvImportBannerPaused.
  ///
  /// In it, this message translates to:
  /// **'Importazione in pausa: {done} di {total}, {review} da verificare, {missing} non trovati'**
  String csvImportBannerPaused(int done, int total, int review, int missing);

  /// No description provided for @csvImportReview.
  ///
  /// In it, this message translates to:
  /// **'Rivedi'**
  String get csvImportReview;

  /// No description provided for @csvImportResume.
  ///
  /// In it, this message translates to:
  /// **'Riprendi'**
  String get csvImportResume;

  /// No description provided for @csvImportPause.
  ///
  /// In it, this message translates to:
  /// **'Pausa'**
  String get csvImportPause;

  /// No description provided for @csvImportCancelTitle.
  ///
  /// In it, this message translates to:
  /// **'Annullare l\'importazione?'**
  String get csvImportCancelTitle;

  /// No description provided for @csvImportCancelBody.
  ///
  /// In it, this message translates to:
  /// **'I brani già scaricati restano nella playlist.'**
  String get csvImportCancelBody;

  /// No description provided for @csvImportDone.
  ///
  /// In it, this message translates to:
  /// **'Importazione completata: {added} aggiunti, {review} da verificare, {missing} non trovati'**
  String csvImportDone(int added, int review, int missing);

  /// No description provided for @csvImportFailing.
  ///
  /// In it, this message translates to:
  /// **'Troppi errori di fila: importazione in pausa'**
  String get csvImportFailing;

  /// No description provided for @csvImportReviewTitle.
  ///
  /// In it, this message translates to:
  /// **'Rivedi'**
  String get csvImportReviewTitle;

  /// No description provided for @csvImportToReview.
  ///
  /// In it, this message translates to:
  /// **'Da verificare'**
  String get csvImportToReview;

  /// No description provided for @csvImportNotFound.
  ///
  /// In it, this message translates to:
  /// **'Non trovati'**
  String get csvImportNotFound;

  /// No description provided for @csvImportErrors.
  ///
  /// In it, this message translates to:
  /// **'Con errori'**
  String get csvImportErrors;

  /// No description provided for @csvImportRetryAll.
  ///
  /// In it, this message translates to:
  /// **'Riprova tutti'**
  String get csvImportRetryAll;

  /// No description provided for @csvImportSkip.
  ///
  /// In it, this message translates to:
  /// **'Salta'**
  String get csvImportSkip;

  /// No description provided for @csvImportManual.
  ///
  /// In it, this message translates to:
  /// **'Cerca a mano'**
  String get csvImportManual;

  /// No description provided for @csvImportNothing.
  ///
  /// In it, this message translates to:
  /// **'Niente da rivedere.'**
  String get csvImportNothing;

  /// No description provided for @csvImportSearch.
  ///
  /// In it, this message translates to:
  /// **'Cerca'**
  String get csvImportSearch;

  /// No description provided for @csvImportWanted.
  ///
  /// In it, this message translates to:
  /// **'Cercato: {title}, {artist}, {duration}'**
  String csvImportWanted(String title, String artist, String duration);

  /// No description provided for @csvImportDownload.
  ///
  /// In it, this message translates to:
  /// **'Scarica'**
  String get csvImportDownload;

  /// No description provided for @csvImportCancelGo.
  ///
  /// In it, this message translates to:
  /// **'Annulla importazione'**
  String get csvImportCancelGo;

  /// No description provided for @exportLog.
  ///
  /// In it, this message translates to:
  /// **'Esporta log'**
  String get exportLog;

  /// No description provided for @exportLogHint.
  ///
  /// In it, this message translates to:
  /// **'File di testo senza percorsi personali, indirizzi di rete né PIN'**
  String get exportLogHint;

  /// No description provided for @exportLogDebugOnly.
  ///
  /// In it, this message translates to:
  /// **'Disponibile solo nella versione installata (in debug il log non viene scritto su file)'**
  String get exportLogDebugOnly;

  /// No description provided for @exportLogNone.
  ///
  /// In it, this message translates to:
  /// **'Non c\'è ancora nessun log da esportare'**
  String get exportLogNone;

  /// No description provided for @exportLogSaved.
  ///
  /// In it, this message translates to:
  /// **'Log salvato'**
  String get exportLogSaved;

  /// No description provided for @exportLogFailed.
  ///
  /// In it, this message translates to:
  /// **'Impossibile salvare il log'**
  String get exportLogFailed;

  /// No description provided for @exportPlaylist.
  ///
  /// In it, this message translates to:
  /// **'Esporta…'**
  String get exportPlaylist;

  /// No description provided for @exportPlaylistTitle.
  ///
  /// In it, this message translates to:
  /// **'Esporta playlist'**
  String get exportPlaylistTitle;

  /// No description provided for @exportFormatM3u8.
  ///
  /// In it, this message translates to:
  /// **'M3U8, per altri lettori'**
  String get exportFormatM3u8;

  /// No description provided for @exportFormatCsv.
  ///
  /// In it, this message translates to:
  /// **'CSV, come Exportify'**
  String get exportFormatCsv;

  /// No description provided for @exportFormatJson.
  ///
  /// In it, this message translates to:
  /// **'JSON, formato FreeKmusic'**
  String get exportFormatJson;

  /// No description provided for @exportRelativePaths.
  ///
  /// In it, this message translates to:
  /// **'Percorsi relativi'**
  String get exportRelativePaths;

  /// No description provided for @exportRelativeHint.
  ///
  /// In it, this message translates to:
  /// **'Rispetto alla cartella comune dei brani: salva il file lì'**
  String get exportRelativeHint;

  /// No description provided for @exportAction.
  ///
  /// In it, this message translates to:
  /// **'Esporta'**
  String get exportAction;

  /// No description provided for @exportSaved.
  ///
  /// In it, this message translates to:
  /// **'Playlist esportata'**
  String get exportSaved;

  /// No description provided for @exportEmpty.
  ///
  /// In it, this message translates to:
  /// **'La playlist è vuota'**
  String get exportEmpty;

  /// No description provided for @exportFailed.
  ///
  /// In it, this message translates to:
  /// **'Impossibile esportare la playlist'**
  String get exportFailed;

  /// No description provided for @ytErrToolOutdated.
  ///
  /// In it, this message translates to:
  /// **'yt-dlp è troppo vecchio: aggiornalo (Impostazioni, Online e download, Aggiorna) e riprova'**
  String get ytErrToolOutdated;

  /// No description provided for @ytDlpOutdatedBanner.
  ///
  /// In it, this message translates to:
  /// **'yt-dlp {version} è troppo vecchio: i download potrebbero non funzionare'**
  String ytDlpOutdatedBanner(String version);

  /// No description provided for @settingsDownloads.
  ///
  /// In it, this message translates to:
  /// **'Download'**
  String get settingsDownloads;

  /// No description provided for @ytDlpVersion.
  ///
  /// In it, this message translates to:
  /// **'yt-dlp {version}'**
  String ytDlpVersion(String version);

  /// No description provided for @ytDlpUnknownVersion.
  ///
  /// In it, this message translates to:
  /// **'yt-dlp non trovato'**
  String get ytDlpUnknownVersion;

  /// No description provided for @ytDlpUpdate.
  ///
  /// In it, this message translates to:
  /// **'Aggiorna'**
  String get ytDlpUpdate;

  /// No description provided for @ytDlpUpdating.
  ///
  /// In it, this message translates to:
  /// **'Aggiornamento… {percent}%'**
  String ytDlpUpdating(int percent);

  /// No description provided for @ytDlpUpdated.
  ///
  /// In it, this message translates to:
  /// **'Aggiornato alla versione {version}'**
  String ytDlpUpdated(String version);

  /// No description provided for @ytDlpTooOld.
  ///
  /// In it, this message translates to:
  /// **'Troppo vecchio: tocca Aggiorna'**
  String get ytDlpTooOld;

  /// No description provided for @ytDlpUpdateErrNetwork.
  ///
  /// In it, this message translates to:
  /// **'Aggiornamento non riuscito: rete non raggiungibile'**
  String get ytDlpUpdateErrNetwork;

  /// No description provided for @ytDlpUpdateErrHash.
  ///
  /// In it, this message translates to:
  /// **'Aggiornamento annullato: il file scaricato non ha superato il controllo di integrità'**
  String get ytDlpUpdateErrHash;

  /// No description provided for @ytDlpUpdateErrOther.
  ///
  /// In it, this message translates to:
  /// **'Aggiornamento non riuscito (dettagli nel log)'**
  String get ytDlpUpdateErrOther;

  /// No description provided for @downloadParallel.
  ///
  /// In it, this message translates to:
  /// **'Download contemporanei'**
  String get downloadParallel;

  /// No description provided for @downloadParallelHint.
  ///
  /// In it, this message translates to:
  /// **'Più insieme è più veloce, ma YouTube può chiedere di rallentare'**
  String get downloadParallelHint;

  /// No description provided for @downloadRateLimit.
  ///
  /// In it, this message translates to:
  /// **'Limite di velocità'**
  String get downloadRateLimit;

  /// No description provided for @downloadRateNone.
  ///
  /// In it, this message translates to:
  /// **'Nessuno'**
  String get downloadRateNone;

  /// No description provided for @downloadRateKb.
  ///
  /// In it, this message translates to:
  /// **'{kb} KB/s'**
  String downloadRateKb(int kb);

  /// No description provided for @downloadRateMb.
  ///
  /// In it, this message translates to:
  /// **'{mb} MB/s'**
  String downloadRateMb(int mb);

  /// No description provided for @activityDownloadRetry.
  ///
  /// In it, this message translates to:
  /// **'Download, {title}, nuovo tentativo tra {seconds} s ({attempt}/{max})'**
  String activityDownloadRetry(String title, int seconds, int attempt, int max);

  /// No description provided for @downloadFormat.
  ///
  /// In it, this message translates to:
  /// **'Formato dei download'**
  String get downloadFormat;

  /// No description provided for @downloadFormatOriginal.
  ///
  /// In it, this message translates to:
  /// **'Originale (qualità massima)'**
  String get downloadFormatOriginal;

  /// No description provided for @downloadFormatOriginalHint.
  ///
  /// In it, this message translates to:
  /// **'L\'audio di YouTube senza ricodifica, di solito Opus ~160 kbps. Non tutti i lettori e le autoradio lo leggono.'**
  String get downloadFormatOriginalHint;

  /// No description provided for @downloadFormatM4a.
  ///
  /// In it, this message translates to:
  /// **'M4A (consigliato)'**
  String get downloadFormatM4a;

  /// No description provided for @downloadFormatM4aHint.
  ///
  /// In it, this message translates to:
  /// **'Quasi come l\'originale, senza ricodifica: veloce, leggero (~1 MB/min), si legge ovunque.'**
  String get downloadFormatM4aHint;

  /// No description provided for @downloadFormatMp3High.
  ///
  /// In it, this message translates to:
  /// **'MP3 320 kbps'**
  String get downloadFormatMp3High;

  /// No description provided for @downloadFormatMp3HighHint.
  ///
  /// In it, this message translates to:
  /// **'Compatibile con tutto. Ricodificato: lieve perdita, file grandi (~2,4 MB/min), download più lento.'**
  String get downloadFormatMp3HighHint;

  /// No description provided for @downloadFormatMp3Low.
  ///
  /// In it, this message translates to:
  /// **'MP3 192 kbps (qualità minima)'**
  String get downloadFormatMp3Low;

  /// No description provided for @downloadFormatMp3LowHint.
  ///
  /// In it, this message translates to:
  /// **'Compatibile con tutto, metà spazio dell\'MP3 320 (~1,4 MB/min), ma la qualità più bassa.'**
  String get downloadFormatMp3LowHint;

  /// No description provided for @searchCacheClear.
  ///
  /// In it, this message translates to:
  /// **'Svuota cache ricerche'**
  String get searchCacheClear;

  /// No description provided for @searchCacheCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =0{Vuota} one{1 ricerca salvata} other{{count} ricerche salvate}}'**
  String searchCacheCount(int count);

  /// No description provided for @searchCacheCleared.
  ///
  /// In it, this message translates to:
  /// **'Cache svuotata'**
  String get searchCacheCleared;

  /// No description provided for @csvImportLengthOff.
  ///
  /// In it, this message translates to:
  /// **'Durata diversa: {found} invece di {wanted}'**
  String csvImportLengthOff(String found, String wanted);

  /// No description provided for @csvImportKeep.
  ///
  /// In it, this message translates to:
  /// **'Tieni questo'**
  String get csvImportKeep;

  /// No description provided for @csvImportTooBig.
  ///
  /// In it, this message translates to:
  /// **'Il file è troppo grande per essere una playlist (massimo 5 MB e 10.000 brani)'**
  String get csvImportTooBig;

  /// No description provided for @csvImportAlsoAccepts.
  ///
  /// In it, this message translates to:
  /// **'Accetta anche: TuneMyMusic, Soundiiz, Last.fm (CSV), M3U/M3U8, XSPF.'**
  String get csvImportAlsoAccepts;

  /// No description provided for @csvImportPlanned.
  ///
  /// In it, this message translates to:
  /// **'Abbinamenti pronti: controllali e scarica'**
  String get csvImportPlanned;

  /// No description provided for @csvImportLinkOnly.
  ///
  /// In it, this message translates to:
  /// **'Solo collega (nessun download)'**
  String get csvImportLinkOnly;

  /// No description provided for @csvImportLinkOnlyHint.
  ///
  /// In it, this message translates to:
  /// **'Crea la playlist con quello che hai già e basta'**
  String get csvImportLinkOnlyHint;

  /// No description provided for @csvImportPlanFirst.
  ///
  /// In it, this message translates to:
  /// **'Rivedi prima di scaricare'**
  String get csvImportPlanFirst;

  /// No description provided for @csvImportPlanFirstHint.
  ///
  /// In it, this message translates to:
  /// **'Cerca tutto, poi scegli cosa scaricare'**
  String get csvImportPlanFirstHint;

  /// No description provided for @csvImportPlanTitle.
  ///
  /// In it, this message translates to:
  /// **'Abbinamenti'**
  String get csvImportPlanTitle;

  /// No description provided for @csvImportPlanGo.
  ///
  /// In it, this message translates to:
  /// **'{n, plural, one{Scarica 1 brano} other{Scarica {n} brani}}'**
  String csvImportPlanGo(int n);

  /// No description provided for @csvImportPlanKnown.
  ///
  /// In it, this message translates to:
  /// **'già scaricato'**
  String get csvImportPlanKnown;

  /// No description provided for @csvImportPlanEmpty.
  ///
  /// In it, this message translates to:
  /// **'Niente da scaricare'**
  String get csvImportPlanEmpty;

  /// No description provided for @csvImportBannerPlanned.
  ///
  /// In it, this message translates to:
  /// **'Abbinamenti pronti: {n, plural, one{1 brano da scaricare} other{{n} brani da scaricare}}'**
  String csvImportBannerPlanned(int n);

  /// No description provided for @settingsAdvanced.
  ///
  /// In it, this message translates to:
  /// **'Avanzate'**
  String get settingsAdvanced;

  /// No description provided for @importSureThreshold.
  ///
  /// In it, this message translates to:
  /// **'Abbinamento sicuro da'**
  String get importSureThreshold;

  /// No description provided for @importSureThresholdHint.
  ///
  /// In it, this message translates to:
  /// **'Sopra questo punteggio un brano dell\'importazione si scarica senza chiedere'**
  String get importSureThresholdHint;

  /// No description provided for @importReviewThreshold.
  ///
  /// In it, this message translates to:
  /// **'Da verificare da'**
  String get importReviewThreshold;

  /// No description provided for @importReviewThresholdHint.
  ///
  /// In it, this message translates to:
  /// **'Tra questo punteggio e quello sicuro il brano finisce in «Da verificare»; sotto, in «Non trovati»'**
  String get importReviewThresholdHint;

  /// No description provided for @importThresholdsReset.
  ///
  /// In it, this message translates to:
  /// **'Ripristina i valori predefiniti'**
  String get importThresholdsReset;

  /// No description provided for @csvImportEstimateHours.
  ///
  /// In it, this message translates to:
  /// **'Tempo stimato: circa {hours} h {minutes} min'**
  String csvImportEstimateHours(int hours, int minutes);

  /// No description provided for @csvImportBlocks.
  ///
  /// In it, this message translates to:
  /// **'Importa a blocchi da {size}'**
  String csvImportBlocks(int size);

  /// No description provided for @csvImportBigWarning.
  ///
  /// In it, this message translates to:
  /// **'Sono {n} brani da scaricare: ci vorranno ore. A blocchi, uno dopo l\'altro, l\'ordine della playlist resta giusto e puoi fermarti tra un blocco e l\'altro.'**
  String csvImportBigWarning(int n);

  /// No description provided for @etaLessThanMinute.
  ///
  /// In it, this message translates to:
  /// **'meno di 1 min'**
  String get etaLessThanMinute;

  /// No description provided for @etaMinutes.
  ///
  /// In it, this message translates to:
  /// **'circa {minutes} min'**
  String etaMinutes(int minutes);

  /// No description provided for @etaHours.
  ///
  /// In it, this message translates to:
  /// **'circa {hours} h {minutes} min'**
  String etaHours(int hours, int minutes);

  /// No description provided for @csvImportOwnFolder.
  ///
  /// In it, this message translates to:
  /// **'Cartella per questa playlist'**
  String get csvImportOwnFolder;

  /// No description provided for @csvImportOwnFolderHint.
  ///
  /// In it, this message translates to:
  /// **'Salva i brani scaricati in una sottocartella col nome della playlist'**
  String get csvImportOwnFolderHint;

  /// No description provided for @csvImportNumberFiles.
  ///
  /// In it, this message translates to:
  /// **'Numera i file'**
  String get csvImportNumberFiles;

  /// No description provided for @csvImportNumberFilesHint.
  ///
  /// In it, this message translates to:
  /// **'07 - Artista - Titolo: la cartella si ascolta nell\'ordine giusto anche fuori da FreeKmusic'**
  String get csvImportNumberFilesHint;

  /// No description provided for @csvImportFetchCovers.
  ///
  /// In it, this message translates to:
  /// **'Cerca le copertine'**
  String get csvImportFetchCovers;

  /// No description provided for @csvImportFetchCoversHint.
  ///
  /// In it, this message translates to:
  /// **'Dopo ogni download cerca la copertina dell\'album su iTunes (album e artista del file)'**
  String get csvImportFetchCoversHint;

  /// No description provided for @csvImportExport.
  ///
  /// In it, this message translates to:
  /// **'Esporta esito'**
  String get csvImportExport;

  /// No description provided for @csvImportExported.
  ///
  /// In it, this message translates to:
  /// **'Esito salvato'**
  String get csvImportExported;

  /// No description provided for @csvOutHeaderRow.
  ///
  /// In it, this message translates to:
  /// **'Riga'**
  String get csvOutHeaderRow;

  /// No description provided for @csvOutHeaderTitle.
  ///
  /// In it, this message translates to:
  /// **'Titolo'**
  String get csvOutHeaderTitle;

  /// No description provided for @csvOutHeaderArtists.
  ///
  /// In it, this message translates to:
  /// **'Artisti'**
  String get csvOutHeaderArtists;

  /// No description provided for @csvOutHeaderAlbum.
  ///
  /// In it, this message translates to:
  /// **'Album'**
  String get csvOutHeaderAlbum;

  /// No description provided for @csvOutHeaderDuration.
  ///
  /// In it, this message translates to:
  /// **'Durata (ms)'**
  String get csvOutHeaderDuration;

  /// No description provided for @csvOutHeaderIsrc.
  ///
  /// In it, this message translates to:
  /// **'ISRC'**
  String get csvOutHeaderIsrc;

  /// No description provided for @csvOutHeaderStatus.
  ///
  /// In it, this message translates to:
  /// **'Esito'**
  String get csvOutHeaderStatus;

  /// No description provided for @csvOutHeaderNote.
  ///
  /// In it, this message translates to:
  /// **'Motivo'**
  String get csvOutHeaderNote;

  /// No description provided for @csvOutHeaderVideo.
  ///
  /// In it, this message translates to:
  /// **'Video scelto'**
  String get csvOutHeaderVideo;

  /// No description provided for @csvOutHeaderScore.
  ///
  /// In it, this message translates to:
  /// **'Punteggio'**
  String get csvOutHeaderScore;

  /// No description provided for @importStatusPending.
  ///
  /// In it, this message translates to:
  /// **'Da cercare'**
  String get importStatusPending;

  /// No description provided for @importStatusQueued.
  ///
  /// In it, this message translates to:
  /// **'In coda'**
  String get importStatusQueued;

  /// No description provided for @importStatusDownloaded.
  ///
  /// In it, this message translates to:
  /// **'Scaricato'**
  String get importStatusDownloaded;

  /// No description provided for @importStatusLinked.
  ///
  /// In it, this message translates to:
  /// **'Già in libreria'**
  String get importStatusLinked;

  /// No description provided for @importStatusReview.
  ///
  /// In it, this message translates to:
  /// **'Da verificare'**
  String get importStatusReview;

  /// No description provided for @importStatusNotFound.
  ///
  /// In it, this message translates to:
  /// **'Non trovato'**
  String get importStatusNotFound;

  /// No description provided for @importStatusFailed.
  ///
  /// In it, this message translates to:
  /// **'Errore'**
  String get importStatusFailed;

  /// No description provided for @importStatusSkipped.
  ///
  /// In it, this message translates to:
  /// **'Saltato'**
  String get importStatusSkipped;

  /// No description provided for @importStatusPlanned.
  ///
  /// In it, this message translates to:
  /// **'Pianificato'**
  String get importStatusPlanned;

  /// No description provided for @importStatusRemoved.
  ///
  /// In it, this message translates to:
  /// **'Rimosso dalla sorgente'**
  String get importStatusRemoved;

  /// No description provided for @importNoteNoResults.
  ///
  /// In it, this message translates to:
  /// **'Nessun risultato'**
  String get importNoteNoResults;

  /// No description provided for @importNoteLowScore.
  ///
  /// In it, this message translates to:
  /// **'Abbinamento poco sicuro'**
  String get importNoteLowScore;

  /// No description provided for @importNoteLinkOnly.
  ///
  /// In it, this message translates to:
  /// **'Solo collegamento: non cercato'**
  String get importNoteLinkOnly;

  /// No description provided for @importNoteYoutubeOff.
  ///
  /// In it, this message translates to:
  /// **'Download disattivato'**
  String get importNoteYoutubeOff;

  /// No description provided for @importNoteDownloadFailed.
  ///
  /// In it, this message translates to:
  /// **'Download non riuscito'**
  String get importNoteDownloadFailed;

  /// No description provided for @importNoteLengthOff.
  ///
  /// In it, this message translates to:
  /// **'Durata diversa dal file'**
  String get importNoteLengthOff;

  /// No description provided for @importNoteUnchanged.
  ///
  /// In it, this message translates to:
  /// **'Già nella playlist'**
  String get importNoteUnchanged;

  /// No description provided for @csvImportSync.
  ///
  /// In it, this message translates to:
  /// **'Sincronizza'**
  String get csvImportSync;

  /// No description provided for @csvImportSyncCounts.
  ///
  /// In it, this message translates to:
  /// **'{added} nuovi, {removed} rimossi dalla playlist (i file restano)'**
  String csvImportSyncCounts(int added, int removed);

  /// No description provided for @csvImportSyncChecking.
  ///
  /// In it, this message translates to:
  /// **'Controllo le differenze…'**
  String get csvImportSyncChecking;

  /// No description provided for @playbackSpeed.
  ///
  /// In it, this message translates to:
  /// **'Velocità di riproduzione'**
  String get playbackSpeed;

  /// No description provided for @playbackSpeedHint.
  ///
  /// In it, this message translates to:
  /// **'Il tono resta quello originale. Il timer di spegnimento conta il tempo reale, non quello del brano.'**
  String get playbackSpeedHint;

  /// No description provided for @resumeFrom.
  ///
  /// In it, this message translates to:
  /// **'riprendi da {time}'**
  String resumeFrom(String time);

  /// No description provided for @restartFromBeginning.
  ///
  /// In it, this message translates to:
  /// **'Ricomincia dall’inizio'**
  String get restartFromBeginning;

  /// No description provided for @previewTrack.
  ///
  /// In it, this message translates to:
  /// **'Anteprima 20 s'**
  String get previewTrack;

  /// No description provided for @equalizer.
  ///
  /// In it, this message translates to:
  /// **'Equalizzatore'**
  String get equalizer;

  /// No description provided for @eqOutputSpeaker.
  ///
  /// In it, this message translates to:
  /// **'Altoparlante'**
  String get eqOutputSpeaker;

  /// No description provided for @eqOutputHeadphones.
  ///
  /// In it, this message translates to:
  /// **'Cuffie'**
  String get eqOutputHeadphones;

  /// No description provided for @eqHint.
  ///
  /// In it, this message translates to:
  /// **'Ogni uscita ricorda la sua curva: cambia da sola quando colleghi le cuffie.'**
  String get eqHint;

  /// No description provided for @eqPresetFlat.
  ///
  /// In it, this message translates to:
  /// **'Piatto'**
  String get eqPresetFlat;

  /// No description provided for @eqPresetBass.
  ///
  /// In it, this message translates to:
  /// **'Bassi'**
  String get eqPresetBass;

  /// No description provided for @eqPresetVoice.
  ///
  /// In it, this message translates to:
  /// **'Voce'**
  String get eqPresetVoice;

  /// No description provided for @eqPresetTreble.
  ///
  /// In it, this message translates to:
  /// **'Acuti'**
  String get eqPresetTreble;

  /// No description provided for @eqPresetCustom.
  ///
  /// In it, this message translates to:
  /// **'Personalizzato'**
  String get eqPresetCustom;

  /// No description provided for @eqReset.
  ///
  /// In it, this message translates to:
  /// **'Reimposta'**
  String get eqReset;

  /// No description provided for @eqWaiting.
  ///
  /// In it, this message translates to:
  /// **'Le bande compaiono quando parte il primo brano.'**
  String get eqWaiting;

  /// No description provided for @eqUnavailable.
  ///
  /// In it, this message translates to:
  /// **'L\'equalizzatore non è disponibile su questo dispositivo.'**
  String get eqUnavailable;

  /// No description provided for @transitionMode.
  ///
  /// In it, this message translates to:
  /// **'Passaggio tra i brani'**
  String get transitionMode;

  /// No description provided for @transitionNormal.
  ///
  /// In it, this message translates to:
  /// **'Normale'**
  String get transitionNormal;

  /// No description provided for @transitionGapless.
  ///
  /// In it, this message translates to:
  /// **'Senza pause'**
  String get transitionGapless;

  /// No description provided for @transitionCrossfade.
  ///
  /// In it, this message translates to:
  /// **'Dissolvenza'**
  String get transitionCrossfade;

  /// No description provided for @transitionHint.
  ///
  /// In it, this message translates to:
  /// **'Senza pause funziona meglio con brani dello stesso formato (per esempio tutti FLAC).'**
  String get transitionHint;

  /// No description provided for @crossfadeLength.
  ///
  /// In it, this message translates to:
  /// **'Durata della dissolvenza: {seconds} s'**
  String crossfadeLength(int seconds);

  /// No description provided for @crossfadePlainInAlbum.
  ///
  /// In it, this message translates to:
  /// **'Non sfumare nello stesso album'**
  String get crossfadePlainInAlbum;

  /// No description provided for @crossfadePlainInAlbumHint.
  ///
  /// In it, this message translates to:
  /// **'Dentro un album i brani si susseguono senza pause, senza sovrapporsi.'**
  String get crossfadePlainInAlbumHint;

  /// No description provided for @selectedRow.
  ///
  /// In it, this message translates to:
  /// **'Selezionato'**
  String get selectedRow;

  /// No description provided for @selectedRowAt.
  ///
  /// In it, this message translates to:
  /// **'Selezionato, numero {position}'**
  String selectedRowAt(int position);

  /// No description provided for @curiositySong.
  ///
  /// In it, this message translates to:
  /// **'Sul brano'**
  String get curiositySong;

  /// No description provided for @curiosityArtist.
  ///
  /// In it, this message translates to:
  /// **'Sull\'artista'**
  String get curiosityArtist;

  /// No description provided for @showMore.
  ///
  /// In it, this message translates to:
  /// **'Mostra tutto'**
  String get showMore;

  /// No description provided for @showLess.
  ///
  /// In it, this message translates to:
  /// **'Mostra meno'**
  String get showLess;

  /// No description provided for @curiosityNoSong.
  ///
  /// In it, this message translates to:
  /// **'Nessuna pagina dedicata a questo brano'**
  String get curiosityNoSong;

  /// No description provided for @curiosityNoArtist.
  ///
  /// In it, this message translates to:
  /// **'Nessuna pagina sull\'artista'**
  String get curiosityNoArtist;

  /// No description provided for @themeNew.
  ///
  /// In it, this message translates to:
  /// **'Nuovo tema'**
  String get themeNew;

  /// No description provided for @themeEdit.
  ///
  /// In it, this message translates to:
  /// **'Modifica'**
  String get themeEdit;

  /// No description provided for @themeDuplicate.
  ///
  /// In it, this message translates to:
  /// **'Duplica'**
  String get themeDuplicate;

  /// No description provided for @themeDelete.
  ///
  /// In it, this message translates to:
  /// **'Elimina'**
  String get themeDelete;

  /// No description provided for @themeExport.
  ///
  /// In it, this message translates to:
  /// **'Esporta'**
  String get themeExport;

  /// No description provided for @themeImport.
  ///
  /// In it, this message translates to:
  /// **'Importa tema'**
  String get themeImport;

  /// No description provided for @themeName.
  ///
  /// In it, this message translates to:
  /// **'Nome del tema'**
  String get themeName;

  /// No description provided for @themeBase.
  ///
  /// In it, this message translates to:
  /// **'Parti da'**
  String get themeBase;

  /// No description provided for @themeModeSimple.
  ///
  /// In it, this message translates to:
  /// **'Semplice'**
  String get themeModeSimple;

  /// No description provided for @themeModeAdvanced.
  ///
  /// In it, this message translates to:
  /// **'Avanzata'**
  String get themeModeAdvanced;

  /// No description provided for @themeSave.
  ///
  /// In it, this message translates to:
  /// **'Salva'**
  String get themeSave;

  /// No description provided for @themeEditorTitle.
  ///
  /// In it, this message translates to:
  /// **'Tema personalizzato'**
  String get themeEditorTitle;

  /// No description provided for @themeDiscardTitle.
  ///
  /// In it, this message translates to:
  /// **'Scartare le modifiche?'**
  String get themeDiscardTitle;

  /// No description provided for @themeDiscardBody.
  ///
  /// In it, this message translates to:
  /// **'Le modifiche a questo tema non sono state salvate.'**
  String get themeDiscardBody;

  /// No description provided for @themeDiscard.
  ///
  /// In it, this message translates to:
  /// **'Scarta'**
  String get themeDiscard;

  /// No description provided for @smartDiscardBody.
  ///
  /// In it, this message translates to:
  /// **'Le modifiche a questa playlist non sono state salvate.'**
  String get smartDiscardBody;

  /// No description provided for @themePreview.
  ///
  /// In it, this message translates to:
  /// **'Anteprima'**
  String get themePreview;

  /// No description provided for @themeResetColor.
  ///
  /// In it, this message translates to:
  /// **'Ripristina il colore'**
  String get themeResetColor;

  /// No description provided for @themeContrastTitle.
  ///
  /// In it, this message translates to:
  /// **'Leggibilità'**
  String get themeContrastTitle;

  /// No description provided for @themeContrastLow.
  ///
  /// In it, this message translates to:
  /// **'Poco leggibile'**
  String get themeContrastLow;

  /// No description provided for @themeContrastOk.
  ///
  /// In it, this message translates to:
  /// **'Leggibile'**
  String get themeContrastOk;

  /// No description provided for @themeFix.
  ///
  /// In it, this message translates to:
  /// **'Correggi'**
  String get themeFix;

  /// No description provided for @themeSaved.
  ///
  /// In it, this message translates to:
  /// **'Tema salvato'**
  String get themeSaved;

  /// No description provided for @themeLimit.
  ///
  /// In it, this message translates to:
  /// **'Hai già 20 temi: eliminane uno'**
  String get themeLimit;

  /// No description provided for @themeImported.
  ///
  /// In it, this message translates to:
  /// **'Tema importato'**
  String get themeImported;

  /// No description provided for @themeImportFailed.
  ///
  /// In it, this message translates to:
  /// **'Il file non è un tema valido'**
  String get themeImportFailed;

  /// No description provided for @themeDeleted.
  ///
  /// In it, this message translates to:
  /// **'Tema eliminato'**
  String get themeDeleted;

  /// No description provided for @themeMine.
  ///
  /// In it, this message translates to:
  /// **'I miei temi'**
  String get themeMine;

  /// No description provided for @tokenBg.
  ///
  /// In it, this message translates to:
  /// **'Sfondo'**
  String get tokenBg;

  /// No description provided for @tokenSurface1.
  ///
  /// In it, this message translates to:
  /// **'Superficie 1'**
  String get tokenSurface1;

  /// No description provided for @tokenSurface2.
  ///
  /// In it, this message translates to:
  /// **'Superficie 2'**
  String get tokenSurface2;

  /// No description provided for @tokenSurface3.
  ///
  /// In it, this message translates to:
  /// **'Superficie 3'**
  String get tokenSurface3;

  /// No description provided for @tokenAccent.
  ///
  /// In it, this message translates to:
  /// **'Accento'**
  String get tokenAccent;

  /// No description provided for @tokenAccentSoft.
  ///
  /// In it, this message translates to:
  /// **'Accento chiaro'**
  String get tokenAccentSoft;

  /// No description provided for @tokenOnAccent.
  ///
  /// In it, this message translates to:
  /// **'Testo sull\'accento'**
  String get tokenOnAccent;

  /// No description provided for @tokenText.
  ///
  /// In it, this message translates to:
  /// **'Testo'**
  String get tokenText;

  /// No description provided for @tokenTextMuted.
  ///
  /// In it, this message translates to:
  /// **'Testo secondario'**
  String get tokenTextMuted;

  /// No description provided for @tokenTextFaint.
  ///
  /// In it, this message translates to:
  /// **'Testo tenue'**
  String get tokenTextFaint;

  /// No description provided for @tokenHero.
  ///
  /// In it, this message translates to:
  /// **'Sfondo del lettore'**
  String get tokenHero;

  /// No description provided for @tokenError.
  ///
  /// In it, this message translates to:
  /// **'Errore'**
  String get tokenError;

  /// No description provided for @pickerHue.
  ///
  /// In it, this message translates to:
  /// **'Tonalità'**
  String get pickerHue;

  /// No description provided for @pickerSv.
  ///
  /// In it, this message translates to:
  /// **'Saturazione e luminosità'**
  String get pickerSv;

  /// No description provided for @pickerAlpha.
  ///
  /// In it, this message translates to:
  /// **'Trasparenza'**
  String get pickerAlpha;

  /// No description provided for @pickerHex.
  ///
  /// In it, this message translates to:
  /// **'Codice colore'**
  String get pickerHex;

  /// No description provided for @pickerInvalid.
  ///
  /// In it, this message translates to:
  /// **'Codice non valido'**
  String get pickerInvalid;

  /// No description provided for @pickerRecent.
  ///
  /// In it, this message translates to:
  /// **'Usati di recente'**
  String get pickerRecent;

  /// No description provided for @contrastTextBg.
  ///
  /// In it, this message translates to:
  /// **'Testo su sfondo'**
  String get contrastTextBg;

  /// No description provided for @contrastMutedSurface.
  ///
  /// In it, this message translates to:
  /// **'Testo secondario su superficie'**
  String get contrastMutedSurface;

  /// No description provided for @contrastOnAccent.
  ///
  /// In it, this message translates to:
  /// **'Testo sull\'accento'**
  String get contrastOnAccent;

  /// No description provided for @contrastAccentBg.
  ///
  /// In it, this message translates to:
  /// **'Accento su sfondo'**
  String get contrastAccentBg;

  /// No description provided for @themeBackground.
  ///
  /// In it, this message translates to:
  /// **'Sfondo delle pagine'**
  String get themeBackground;

  /// No description provided for @bgSolid.
  ///
  /// In it, this message translates to:
  /// **'Tinta unita'**
  String get bgSolid;

  /// No description provided for @bgGradient.
  ///
  /// In it, this message translates to:
  /// **'Sfumatura'**
  String get bgGradient;

  /// No description provided for @bgImage.
  ///
  /// In it, this message translates to:
  /// **'Immagine'**
  String get bgImage;

  /// No description provided for @bgGradientEnd.
  ///
  /// In it, this message translates to:
  /// **'Colore finale'**
  String get bgGradientEnd;

  /// No description provided for @bgAngle.
  ///
  /// In it, this message translates to:
  /// **'Direzione'**
  String get bgAngle;

  /// No description provided for @bgPickImage.
  ///
  /// In it, this message translates to:
  /// **'Scegli immagine…'**
  String get bgPickImage;

  /// No description provided for @bgRemoveImage.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi immagine'**
  String get bgRemoveImage;

  /// No description provided for @bgDim.
  ///
  /// In it, this message translates to:
  /// **'Oscuramento'**
  String get bgDim;

  /// No description provided for @bgBlur.
  ///
  /// In it, this message translates to:
  /// **'Sfocatura'**
  String get bgBlur;

  /// No description provided for @bgCoverBackdrop.
  ///
  /// In it, this message translates to:
  /// **'In riproduzione: tinta della copertina'**
  String get bgCoverBackdrop;

  /// No description provided for @blurredChrome.
  ///
  /// In it, this message translates to:
  /// **'Dock e intestazioni sfocati'**
  String get blurredChrome;

  /// No description provided for @blurredChromeHint.
  ///
  /// In it, this message translates to:
  /// **'Può rallentare sui telefoni meno potenti'**
  String get blurredChromeHint;

  /// No description provided for @bgImageFailed.
  ///
  /// In it, this message translates to:
  /// **'Impossibile usare l\'immagine'**
  String get bgImageFailed;

  /// No description provided for @themeCopyName.
  ///
  /// In it, this message translates to:
  /// **'{name} (copia)'**
  String themeCopyName(String name);

  /// No description provided for @selectedCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 selezionato} other{{count} selezionati}}'**
  String selectedCount(int count);

  /// No description provided for @selectAll.
  ///
  /// In it, this message translates to:
  /// **'Seleziona tutto'**
  String get selectAll;

  /// No description provided for @exitSelection.
  ///
  /// In it, this message translates to:
  /// **'Esci dalla selezione'**
  String get exitSelection;

  /// No description provided for @bulkActions.
  ///
  /// In it, this message translates to:
  /// **'Azioni'**
  String get bulkActions;

  /// No description provided for @addedToQueueMany.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 brano aggiunto in coda} other{{count} brani aggiunti in coda}}'**
  String addedToQueueMany(int count);

  /// No description provided for @addedToPlaylistMany.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 brano aggiunto a «{name}»} other{{count} brani aggiunti a «{name}»}}'**
  String addedToPlaylistMany(int count, String name);

  /// No description provided for @addedToPlaylistSkipped.
  ///
  /// In it, this message translates to:
  /// **'{added} aggiunti a «{name}», {skipped} già presenti'**
  String addedToPlaylistSkipped(int added, int skipped, String name);

  /// No description provided for @allAlreadyInPlaylist.
  ///
  /// In it, this message translates to:
  /// **'Erano già tutti in «{name}»'**
  String allAlreadyInPlaylist(String name);

  /// No description provided for @favoritesAdded.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 brano nei preferiti} other{{count} brani nei preferiti}}'**
  String favoritesAdded(int count);

  /// No description provided for @favoritesRemoved.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 brano tolto dai preferiti} other{{count} brani tolti dai preferiti}}'**
  String favoritesRemoved(int count);

  /// No description provided for @bulkAddToFavorites.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi ai preferiti'**
  String get bulkAddToFavorites;

  /// No description provided for @bulkRemoveFromFavorites.
  ///
  /// In it, this message translates to:
  /// **'Togli dai preferiti'**
  String get bulkRemoveFromFavorites;

  /// No description provided for @removeManyFromPlaylistTitle.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{Rimuovere 1 brano dalla playlist?} other{Rimuovere {count} brani dalla playlist?}}'**
  String removeManyFromPlaylistTitle(int count);

  /// No description provided for @removeManyFromPlaylistBody.
  ///
  /// In it, this message translates to:
  /// **'I file e la libreria non vengono toccati.'**
  String get removeManyFromPlaylistBody;

  /// No description provided for @removedManyFromPlaylist.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 brano rimosso} other{{count} brani rimossi}}'**
  String removedManyFromPlaylist(int count);

  /// No description provided for @removeManyFromLibraryTitle.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{Togliere 1 brano dalla libreria?} other{Togliere {count} brani dalla libreria?}}'**
  String removeManyFromLibraryTitle(int count);

  /// No description provided for @removeManyFromLibraryBody.
  ///
  /// In it, this message translates to:
  /// **'I file non esistono più: spariscono solo dalla libreria (perdi preferiti e playlist di questi brani).'**
  String get removeManyFromLibraryBody;

  /// No description provided for @removedManyFromLibrary.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 brano tolto dalla libreria} other{{count} brani tolti dalla libreria}}'**
  String removedManyFromLibrary(int count);

  /// No description provided for @ytDownloadsStarted.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 download avviato} other{{count} download avviati}}'**
  String ytDownloadsStarted(int count);

  /// No description provided for @ytDownloadsSkipped.
  ///
  /// In it, this message translates to:
  /// **'{started} download avviati, {skipped} già in libreria o in corso'**
  String ytDownloadsSkipped(int started, int skipped);

  /// No description provided for @ytNothingToDownload.
  ///
  /// In it, this message translates to:
  /// **'Sono già tutti in libreria o in corso'**
  String get ytNothingToDownload;

  /// No description provided for @themeChiaro.
  ///
  /// In it, this message translates to:
  /// **'Chiaro'**
  String get themeChiaro;

  /// No description provided for @settingsAccent.
  ///
  /// In it, this message translates to:
  /// **'Colore d\'accento'**
  String get settingsAccent;

  /// No description provided for @accentViola.
  ///
  /// In it, this message translates to:
  /// **'Viola'**
  String get accentViola;

  /// No description provided for @accentBlu.
  ///
  /// In it, this message translates to:
  /// **'Blu'**
  String get accentBlu;

  /// No description provided for @accentAcqua.
  ///
  /// In it, this message translates to:
  /// **'Verde acqua'**
  String get accentAcqua;

  /// No description provided for @accentVerde.
  ///
  /// In it, this message translates to:
  /// **'Verde'**
  String get accentVerde;

  /// No description provided for @accentAmbra.
  ///
  /// In it, this message translates to:
  /// **'Ambra'**
  String get accentAmbra;

  /// No description provided for @accentArancio.
  ///
  /// In it, this message translates to:
  /// **'Arancio'**
  String get accentArancio;

  /// No description provided for @accentRosa.
  ///
  /// In it, this message translates to:
  /// **'Rosa'**
  String get accentRosa;

  /// No description provided for @accentRosso.
  ///
  /// In it, this message translates to:
  /// **'Rosso'**
  String get accentRosso;

  /// No description provided for @onboardingNext.
  ///
  /// In it, this message translates to:
  /// **'Avanti'**
  String get onboardingNext;

  /// No description provided for @onboardingStart.
  ///
  /// In it, this message translates to:
  /// **'Inizia'**
  String get onboardingStart;

  /// No description provided for @onboardingPageOf.
  ///
  /// In it, this message translates to:
  /// **'Pagina {page} di {total}'**
  String onboardingPageOf(int page, int total);

  /// No description provided for @onboardingStepOf.
  ///
  /// In it, this message translates to:
  /// **'{page} di {total}'**
  String onboardingStepOf(int page, int total);

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In it, this message translates to:
  /// **'Benvenuto in FreeKmusic'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In it, this message translates to:
  /// **'Il tuo lettore musicale personale: niente account, niente server. La musica resta sul tuo dispositivo.'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingFoldersTitle.
  ///
  /// In it, this message translates to:
  /// **'La tua musica'**
  String get onboardingFoldersTitle;

  /// No description provided for @onboardingFoldersBody.
  ///
  /// In it, this message translates to:
  /// **'Scegli le cartelle dove tieni i brani. FreeKmusic li legge: non li modifica e non li sposta.'**
  String get onboardingFoldersBody;

  /// No description provided for @onboardingFoldersAdded.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 cartella aggiunta} other{{count} cartelle aggiunte}}'**
  String onboardingFoldersAdded(int count);

  /// No description provided for @onboardingAllowAccess.
  ///
  /// In it, this message translates to:
  /// **'Consenti l’accesso ai file audio'**
  String get onboardingAllowAccess;

  /// No description provided for @onboardingAccessGranted.
  ///
  /// In it, this message translates to:
  /// **'Accesso consentito'**
  String get onboardingAccessGranted;

  /// No description provided for @onboardingOnlineTitle.
  ///
  /// In it, this message translates to:
  /// **'Funzioni online'**
  String get onboardingOnlineTitle;

  /// No description provided for @onboardingOnlineBody.
  ///
  /// In it, this message translates to:
  /// **'Sono accese: arricchiscono i brani con dati online. Puoi spegnerle qui o più tardi dalle Impostazioni.'**
  String get onboardingOnlineBody;

  /// No description provided for @onboardingShareTitle.
  ///
  /// In it, this message translates to:
  /// **'Download, Jam e condivisione'**
  String get onboardingShareTitle;

  /// No description provided for @onboardingYoutubeBody.
  ///
  /// In it, this message translates to:
  /// **'Puoi scaricare brani da YouTube sul tuo dispositivo, per ascoltarli come il resto della tua musica.'**
  String get onboardingYoutubeBody;

  /// No description provided for @onboardingJamBody.
  ///
  /// In it, this message translates to:
  /// **'Con una Jam ascolti la stessa musica insieme a un altro dispositivo sulla stessa rete.'**
  String get onboardingJamBody;

  /// No description provided for @onboardingSendBody.
  ///
  /// In it, this message translates to:
  /// **'Puoi inviare brani ad altri dispositivi vicini, con un PIN, senza passare da Internet.'**
  String get onboardingSendBody;

  /// No description provided for @historyTitle.
  ///
  /// In it, this message translates to:
  /// **'Cronologia'**
  String get historyTitle;

  /// No description provided for @historySubtitle.
  ///
  /// In it, this message translates to:
  /// **'Quello che hai ascoltato'**
  String get historySubtitle;

  /// No description provided for @historyToday.
  ///
  /// In it, this message translates to:
  /// **'Oggi'**
  String get historyToday;

  /// No description provided for @historyYesterday.
  ///
  /// In it, this message translates to:
  /// **'Ieri'**
  String get historyYesterday;

  /// No description provided for @historyEmpty.
  ///
  /// In it, this message translates to:
  /// **'Qui comparirà quello che ascolti.'**
  String get historyEmpty;

  /// No description provided for @historyOff.
  ///
  /// In it, this message translates to:
  /// **'La cronologia è spenta: attivala in Impostazioni, Riproduzione.'**
  String get historyOff;

  /// No description provided for @historyClear.
  ///
  /// In it, this message translates to:
  /// **'Cancella cronologia'**
  String get historyClear;

  /// No description provided for @historyClearTitle.
  ///
  /// In it, this message translates to:
  /// **'Cancellare la cronologia?'**
  String get historyClearTitle;

  /// No description provided for @historyClearBody.
  ///
  /// In it, this message translates to:
  /// **'Si cancella solo l’elenco degli ascolti: contatori, preferiti e playlist restano come sono.'**
  String get historyClearBody;

  /// No description provided for @historyCleared.
  ///
  /// In it, this message translates to:
  /// **'Cronologia cancellata'**
  String get historyCleared;

  /// No description provided for @settingsRecordHistory.
  ///
  /// In it, this message translates to:
  /// **'Registra la cronologia di ascolto'**
  String get settingsRecordHistory;

  /// No description provided for @settingsRecordHistoryHint.
  ///
  /// In it, this message translates to:
  /// **'Resta sul dispositivo. Spenta, non si aggiunge nient’altro all’elenco.'**
  String get settingsRecordHistoryHint;

  /// No description provided for @statsTitle.
  ///
  /// In it, this message translates to:
  /// **'Statistiche'**
  String get statsTitle;

  /// No description provided for @statsSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Ascolti, artisti e giorni più ascoltati'**
  String get statsSubtitle;

  /// No description provided for @statsMonth.
  ///
  /// In it, this message translates to:
  /// **'Mese'**
  String get statsMonth;

  /// No description provided for @statsYear.
  ///
  /// In it, this message translates to:
  /// **'Anno'**
  String get statsYear;

  /// No description provided for @statsPrevious.
  ///
  /// In it, this message translates to:
  /// **'Periodo precedente'**
  String get statsPrevious;

  /// No description provided for @statsNext.
  ///
  /// In it, this message translates to:
  /// **'Periodo successivo'**
  String get statsNext;

  /// No description provided for @statsEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessun ascolto in questo periodo.'**
  String get statsEmpty;

  /// No description provided for @statsPlays.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 ascolto} other{{count} ascolti}}'**
  String statsPlays(int count);

  /// No description provided for @statsDistinct.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 brano diverso} other{{count} brani diversi}}'**
  String statsDistinct(int count);

  /// No description provided for @statsHoursMinutes.
  ///
  /// In it, this message translates to:
  /// **'{hours} h {minutes} min'**
  String statsHoursMinutes(int hours, int minutes);

  /// No description provided for @statsTopTracks.
  ///
  /// In it, this message translates to:
  /// **'Brani più ascoltati'**
  String get statsTopTracks;

  /// No description provided for @statsTopArtists.
  ///
  /// In it, this message translates to:
  /// **'Artisti più ascoltati'**
  String get statsTopArtists;

  /// No description provided for @statsTopAlbums.
  ///
  /// In it, this message translates to:
  /// **'Album più ascoltati'**
  String get statsTopAlbums;

  /// No description provided for @statsFavouriteHour.
  ///
  /// In it, this message translates to:
  /// **'Ora preferita'**
  String get statsFavouriteHour;

  /// No description provided for @statsFirstListen.
  ///
  /// In it, this message translates to:
  /// **'Primo ascolto'**
  String get statsFirstListen;

  /// No description provided for @statsFirstValue.
  ///
  /// In it, this message translates to:
  /// **'{title}, {date}'**
  String statsFirstValue(String title, String date);

  /// No description provided for @statsYourMonth.
  ///
  /// In it, this message translates to:
  /// **'Il tuo mese'**
  String get statsYourMonth;

  /// No description provided for @ruleWarning.
  ///
  /// In it, this message translates to:
  /// **'Non capisco «{term}»: lo cerco come testo.'**
  String ruleWarning(String term);

  /// No description provided for @smartPlaylistNew.
  ///
  /// In it, this message translates to:
  /// **'Nuova playlist intelligente'**
  String get smartPlaylistNew;

  /// No description provided for @smartPlaylistEdit.
  ///
  /// In it, this message translates to:
  /// **'Modifica playlist intelligente'**
  String get smartPlaylistEdit;

  /// No description provided for @smartPlaylistLabel.
  ///
  /// In it, this message translates to:
  /// **'Playlist intelligente'**
  String get smartPlaylistLabel;

  /// No description provided for @smartName.
  ///
  /// In it, this message translates to:
  /// **'Nome'**
  String get smartName;

  /// No description provided for @smartNameRequired.
  ///
  /// In it, this message translates to:
  /// **'Scrivi un nome'**
  String get smartNameRequired;

  /// No description provided for @smartNoRules.
  ///
  /// In it, this message translates to:
  /// **'Senza regole la playlist contiene tutta la libreria.'**
  String get smartNoRules;

  /// No description provided for @smartSortBy.
  ///
  /// In it, this message translates to:
  /// **'Ordina per'**
  String get smartSortBy;

  /// No description provided for @smartSortMostPlayed.
  ///
  /// In it, this message translates to:
  /// **'Più ascoltati'**
  String get smartSortMostPlayed;

  /// No description provided for @smartSortRandom.
  ///
  /// In it, this message translates to:
  /// **'A caso'**
  String get smartSortRandom;

  /// No description provided for @smartTemplates.
  ///
  /// In it, this message translates to:
  /// **'Modelli'**
  String get smartTemplates;

  /// No description provided for @smartTplNever.
  ///
  /// In it, this message translates to:
  /// **'Mai ascoltati'**
  String get smartTplNever;

  /// No description provided for @smartTplRecent.
  ///
  /// In it, this message translates to:
  /// **'Aggiunti di recente'**
  String get smartTplRecent;

  /// No description provided for @smartTplTop.
  ///
  /// In it, this message translates to:
  /// **'I più ascoltati'**
  String get smartTplTop;

  /// No description provided for @smartTpl90s.
  ///
  /// In it, this message translates to:
  /// **'Anni ’90'**
  String get smartTpl90s;

  /// No description provided for @smartConvert.
  ///
  /// In it, this message translates to:
  /// **'Converti in playlist normale'**
  String get smartConvert;

  /// No description provided for @smartConverted.
  ///
  /// In it, this message translates to:
  /// **'Creata la playlist «{name}» con l’elenco attuale'**
  String smartConverted(String name);

  /// No description provided for @smartDeleteTitle.
  ///
  /// In it, this message translates to:
  /// **'Eliminare «{name}»?'**
  String smartDeleteTitle(String name);

  /// No description provided for @smartDeleteBody.
  ///
  /// In it, this message translates to:
  /// **'Si elimina solo la regola: i brani restano dove sono.'**
  String get smartDeleteBody;

  /// No description provided for @smartAutoNote.
  ///
  /// In it, this message translates to:
  /// **'L’elenco si aggiorna da solo.'**
  String get smartAutoNote;

  /// No description provided for @tagsTitle.
  ///
  /// In it, this message translates to:
  /// **'Etichette'**
  String get tagsTitle;

  /// No description provided for @tagsSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Le tue etichette'**
  String get tagsSubtitle;

  /// No description provided for @tagsCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 etichetta} other{{count} etichette}}'**
  String tagsCount(int count);

  /// No description provided for @tagsEllipsis.
  ///
  /// In it, this message translates to:
  /// **'Etichette…'**
  String get tagsEllipsis;

  /// No description provided for @tagNew.
  ///
  /// In it, this message translates to:
  /// **'Nuova etichetta'**
  String get tagNew;

  /// No description provided for @tagRename.
  ///
  /// In it, this message translates to:
  /// **'Rinomina etichetta'**
  String get tagRename;

  /// No description provided for @tagColor.
  ///
  /// In it, this message translates to:
  /// **'Colore'**
  String get tagColor;

  /// No description provided for @tagNoColor.
  ///
  /// In it, this message translates to:
  /// **'Nessun colore'**
  String get tagNoColor;

  /// No description provided for @tagNameTaken.
  ///
  /// In it, this message translates to:
  /// **'Esiste già un’etichetta con questo nome'**
  String get tagNameTaken;

  /// No description provided for @tagDeleteTitle.
  ///
  /// In it, this message translates to:
  /// **'Eliminare l’etichetta «{name}»?'**
  String tagDeleteTitle(String name);

  /// No description provided for @tagDeleteBody.
  ///
  /// In it, this message translates to:
  /// **'Si toglie solo l’etichetta dai brani: i brani restano nella libreria.'**
  String get tagDeleteBody;

  /// No description provided for @tagsEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessuna etichetta: creane una dal menu di un brano.'**
  String get tagsEmpty;

  /// No description provided for @tagAddToSelection.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi etichetta…'**
  String get tagAddToSelection;

  /// No description provided for @tagRemoveFromSelection.
  ///
  /// In it, this message translates to:
  /// **'Togli etichetta…'**
  String get tagRemoveFromSelection;

  /// No description provided for @tagAssigned.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 brano etichettato «{name}»} other{{count} brani etichettati «{name}»}}'**
  String tagAssigned(int count, String name);

  /// No description provided for @tagUnassigned.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{«{name}» tolta da 1 brano} other{«{name}» tolta da {count} brani}}'**
  String tagUnassigned(int count, String name);

  /// No description provided for @tagNoneToRemove.
  ///
  /// In it, this message translates to:
  /// **'I brani scelti non hanno etichette.'**
  String get tagNoneToRemove;

  /// No description provided for @cleanupSection.
  ///
  /// In it, this message translates to:
  /// **'Pulizia libreria'**
  String get cleanupSection;

  /// No description provided for @duplicatesTitle.
  ///
  /// In it, this message translates to:
  /// **'Duplicati'**
  String get duplicatesTitle;

  /// No description provided for @duplicatesTileHint.
  ///
  /// In it, this message translates to:
  /// **'Lo stesso brano in più copie o qualità'**
  String get duplicatesTileHint;

  /// No description provided for @duplicatesIntro.
  ///
  /// In it, this message translates to:
  /// **'Cerca lo stesso brano in più copie: lo stesso file in due cartelle o lo stesso brano in due qualità. Prima di unire vedi un’anteprima. Preferiti, playlist, ascolti, testi ed etichette passano al brano che tieni; gli altri vengono solo nascosti e li ripristini da «Brani nascosti». Nessun file viene cancellato senza una doppia conferma.'**
  String get duplicatesIntro;

  /// No description provided for @duplicatesSearch.
  ///
  /// In it, this message translates to:
  /// **'Cerca duplicati'**
  String get duplicatesSearch;

  /// No description provided for @duplicatesSearchAgain.
  ///
  /// In it, this message translates to:
  /// **'Cerca di nuovo'**
  String get duplicatesSearchAgain;

  /// No description provided for @duplicatesReading.
  ///
  /// In it, this message translates to:
  /// **'Leggo la libreria…'**
  String get duplicatesReading;

  /// No description provided for @duplicatesHashing.
  ///
  /// In it, this message translates to:
  /// **'Controllo i file: {done} di {total}'**
  String duplicatesHashing(int done, int total);

  /// No description provided for @duplicatesGrouping.
  ///
  /// In it, this message translates to:
  /// **'Confronto i brani…'**
  String get duplicatesGrouping;

  /// No description provided for @duplicatesFailed.
  ///
  /// In it, this message translates to:
  /// **'La ricerca non è riuscita. Riprova.'**
  String get duplicatesFailed;

  /// No description provided for @duplicatesNone.
  ///
  /// In it, this message translates to:
  /// **'Nessun duplicato trovato'**
  String get duplicatesNone;

  /// No description provided for @duplicatesSummary.
  ///
  /// In it, this message translates to:
  /// **'{groups, plural, one{1 gruppo} other{{groups} gruppi}}, {hidden, plural, one{1 brano da nascondere} other{{hidden} brani da nascondere}}'**
  String duplicatesSummary(int groups, int hidden);

  /// No description provided for @duplicatesExactBadge.
  ///
  /// In it, this message translates to:
  /// **'Identici'**
  String get duplicatesExactBadge;

  /// No description provided for @duplicatesProbableBadge.
  ///
  /// In it, this message translates to:
  /// **'Probabili'**
  String get duplicatesProbableBadge;

  /// No description provided for @duplicatesKeepLabel.
  ///
  /// In it, this message translates to:
  /// **'Da tenere'**
  String get duplicatesKeepLabel;

  /// No description provided for @duplicatesPickKeep.
  ///
  /// In it, this message translates to:
  /// **'Tocca un brano per tenerlo'**
  String get duplicatesPickKeep;

  /// No description provided for @duplicatesMerge.
  ///
  /// In it, this message translates to:
  /// **'Unisci'**
  String get duplicatesMerge;

  /// No description provided for @duplicatesNotDuplicates.
  ///
  /// In it, this message translates to:
  /// **'Non sono duplicati'**
  String get duplicatesNotDuplicates;

  /// No description provided for @duplicatesMergeAllExact.
  ///
  /// In it, this message translates to:
  /// **'Unisci tutti gli identici ({count})'**
  String duplicatesMergeAllExact(int count);

  /// No description provided for @duplicatesMergeAllTitle.
  ///
  /// In it, this message translates to:
  /// **'Unire tutti gli identici?'**
  String get duplicatesMergeAllTitle;

  /// No description provided for @duplicatesMergeAllBody.
  ///
  /// In it, this message translates to:
  /// **'{groups, plural, one{1 gruppo} other{{groups} gruppi}}, {hidden, plural, one{1 brano nascosto} other{{hidden} brani nascosti}}. Preferiti, playlist, ascolti e testi passano ai brani che restano.'**
  String duplicatesMergeAllBody(int groups, int hidden);

  /// No description provided for @duplicatesMerged.
  ///
  /// In it, this message translates to:
  /// **'Unito: {count, plural, one{1 brano nascosto} other{{count} brani nascosti}}'**
  String duplicatesMerged(int count);

  /// No description provided for @duplicatesDeleteFiles.
  ///
  /// In it, this message translates to:
  /// **'Elimina anche i file ({count}, {size})'**
  String duplicatesDeleteFiles(int count, String size);

  /// No description provided for @duplicatesDeleteListTitle.
  ///
  /// In it, this message translates to:
  /// **'Eliminare questi file?'**
  String get duplicatesDeleteListTitle;

  /// No description provided for @duplicatesDeleteListBody.
  ///
  /// In it, this message translates to:
  /// **'Verranno cancellati dal dispositivo e non si possono recuperare. I brani che tieni restano dove sono.'**
  String get duplicatesDeleteListBody;

  /// No description provided for @duplicatesDeleteContinue.
  ///
  /// In it, this message translates to:
  /// **'Continua'**
  String get duplicatesDeleteContinue;

  /// No description provided for @duplicatesDeleteFinalTitle.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{Eliminare definitivamente 1 file?} other{Eliminare definitivamente {count} file?}}'**
  String duplicatesDeleteFinalTitle(int count);

  /// No description provided for @duplicatesDeleteFinalBody.
  ///
  /// In it, this message translates to:
  /// **'Spazio liberato: {size}. Questa azione non si può annullare.'**
  String duplicatesDeleteFinalBody(String size);

  /// No description provided for @duplicatesDeleteGo.
  ///
  /// In it, this message translates to:
  /// **'Elimina definitivamente'**
  String get duplicatesDeleteGo;

  /// No description provided for @duplicatesDeleteDoneTitle.
  ///
  /// In it, this message translates to:
  /// **'Fatto'**
  String get duplicatesDeleteDoneTitle;

  /// No description provided for @duplicatesDeleteDone.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 file eliminato} other{{count} file eliminati}} ({size}).'**
  String duplicatesDeleteDone(int count, String size);

  /// No description provided for @duplicatesDeleteFailed.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 file non eliminato:} other{{count} file non eliminati:}}'**
  String duplicatesDeleteFailed(int count);

  /// No description provided for @duplicatesDeleteSkipped.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 file non toccato: è lo stesso file del brano tenuto.} other{{count} file non toccati: sono lo stesso file del brano tenuto.}}'**
  String duplicatesDeleteSkipped(int count);

  /// No description provided for @duplicatesDeleteAndroidHint.
  ///
  /// In it, this message translates to:
  /// **'Su Android si possono eliminare solo i file nelle cartelle a cui l’app ha accesso.'**
  String get duplicatesDeleteAndroidHint;

  /// No description provided for @activityCleanup.
  ///
  /// In it, this message translates to:
  /// **'Ricerca duplicati: {done} di {total}'**
  String activityCleanup(int done, int total);

  /// No description provided for @hiddenTracksTitle.
  ///
  /// In it, this message translates to:
  /// **'Brani nascosti'**
  String get hiddenTracksTitle;

  /// No description provided for @hiddenTracksCount.
  ///
  /// In it, this message translates to:
  /// **'Brani nascosti ({count})'**
  String hiddenTracksCount(int count);

  /// No description provided for @hiddenTracksEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessun brano nascosto'**
  String get hiddenTracksEmpty;

  /// No description provided for @hiddenTracksHint.
  ///
  /// In it, this message translates to:
  /// **'I doppioni uniti non compaiono in libreria. «Ripristina» li rimette al loro posto.'**
  String get hiddenTracksHint;

  /// No description provided for @hiddenRestore.
  ///
  /// In it, this message translates to:
  /// **'Ripristina'**
  String get hiddenRestore;

  /// No description provided for @hiddenRestored.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 brano ripristinato} other{{count} brani ripristinati}}'**
  String hiddenRestored(int count);

  /// No description provided for @albumMergeWith.
  ///
  /// In it, this message translates to:
  /// **'Unisci con…'**
  String get albumMergeWith;

  /// No description provided for @albumMergeTitle.
  ///
  /// In it, this message translates to:
  /// **'Unisci album'**
  String get albumMergeTitle;

  /// No description provided for @albumMergeIntro.
  ///
  /// In it, this message translates to:
  /// **'Scegli gli album da unire a «{name}». I brani passano a un solo album con il titolo e l’artista che indichi; la copertina resta quella di «{name}».'**
  String albumMergeIntro(String name);

  /// No description provided for @albumMergeSearch.
  ///
  /// In it, this message translates to:
  /// **'Cerca un album'**
  String get albumMergeSearch;

  /// No description provided for @albumMergeNone.
  ///
  /// In it, this message translates to:
  /// **'Non ci sono altri album'**
  String get albumMergeNone;

  /// No description provided for @albumFieldTitle.
  ///
  /// In it, this message translates to:
  /// **'Titolo dell’album'**
  String get albumFieldTitle;

  /// No description provided for @albumFieldArtist.
  ///
  /// In it, this message translates to:
  /// **'Artista dell’album'**
  String get albumFieldArtist;

  /// No description provided for @albumMergeAction.
  ///
  /// In it, this message translates to:
  /// **'Unisci album'**
  String get albumMergeAction;

  /// No description provided for @albumMerged.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 album unito in «{name}»} other{{count} album uniti in «{name}»}}'**
  String albumMerged(int count, String name);

  /// No description provided for @moveToAlbum.
  ///
  /// In it, this message translates to:
  /// **'Sposta in un nuovo album…'**
  String get moveToAlbum;

  /// No description provided for @moveToAlbumTitle.
  ///
  /// In it, this message translates to:
  /// **'Sposta in un album'**
  String get moveToAlbumTitle;

  /// No description provided for @moveToAlbumBody.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 brano andrà} other{{count} brani andranno}} nell’album indicato. Se esiste già, si uniranno ad esso.'**
  String moveToAlbumBody(int count);

  /// No description provided for @moveToAlbumGo.
  ///
  /// In it, this message translates to:
  /// **'Sposta'**
  String get moveToAlbumGo;

  /// No description provided for @movedToAlbum.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 brano spostato in «{name}»} other{{count} brani spostati in «{name}»}}'**
  String movedToAlbum(int count, String name);

  /// No description provided for @searchSourceYoutube.
  ///
  /// In it, this message translates to:
  /// **'YouTube'**
  String get searchSourceYoutube;

  /// No description provided for @searchSourceYoutubeMusic.
  ///
  /// In it, this message translates to:
  /// **'YouTube Music'**
  String get searchSourceYoutubeMusic;

  /// No description provided for @searchSourceSoundcloud.
  ///
  /// In it, this message translates to:
  /// **'SoundCloud'**
  String get searchSourceSoundcloud;

  /// No description provided for @playlistSourceTitle.
  ///
  /// In it, this message translates to:
  /// **'Playlist o canale YouTube'**
  String get playlistSourceTitle;

  /// No description provided for @playlistSourceLoading.
  ///
  /// In it, this message translates to:
  /// **'Leggo l’elenco dei video…'**
  String get playlistSourceLoading;

  /// No description provided for @playlistSourceName.
  ///
  /// In it, this message translates to:
  /// **'Nome della playlist'**
  String get playlistSourceName;

  /// No description provided for @playlistSourceCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 video} other{{count} video}}'**
  String playlistSourceCount(int count);

  /// No description provided for @playlistSourceUnavailable.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 video non disponibile (privato o rimosso)} other{{count} video non disponibili (privati o rimossi)}}'**
  String playlistSourceUnavailable(int count);

  /// No description provided for @playlistSourceTruncated.
  ///
  /// In it, this message translates to:
  /// **'Mostro i primi {count} video.'**
  String playlistSourceTruncated(int count);

  /// No description provided for @playlistSourceLong.
  ///
  /// In it, this message translates to:
  /// **'Sono {count} video: ci vorrà {time}.'**
  String playlistSourceLong(int count, String time);

  /// No description provided for @playlistSourceNone.
  ///
  /// In it, this message translates to:
  /// **'Nessuno'**
  String get playlistSourceNone;

  /// No description provided for @playlistSourceEmpty.
  ///
  /// In it, this message translates to:
  /// **'Non ci sono video da scaricare qui.'**
  String get playlistSourceEmpty;

  /// No description provided for @playlistSourceGo.
  ///
  /// In it, this message translates to:
  /// **'Scarica in una playlist ({count})'**
  String playlistSourceGo(int count);

  /// No description provided for @playlistSourceStarted.
  ///
  /// In it, this message translates to:
  /// **'Download avviati nella playlist «{name}»'**
  String playlistSourceStarted(String name);

  /// No description provided for @podcastsTitle.
  ///
  /// In it, this message translates to:
  /// **'Podcast'**
  String get podcastsTitle;

  /// No description provided for @podcastsSubtitle.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 podcast} other{{count} podcast}}'**
  String podcastsSubtitle(int count);

  /// No description provided for @podcastsNotice.
  ///
  /// In it, this message translates to:
  /// **'I podcast si aggiornano solo quando lo chiedi.'**
  String get podcastsNotice;

  /// No description provided for @podcastsEmpty.
  ///
  /// In it, this message translates to:
  /// **'Non sei iscritto a nessun podcast.'**
  String get podcastsEmpty;

  /// No description provided for @podcastAdd.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi podcast'**
  String get podcastAdd;

  /// No description provided for @podcastRefreshAll.
  ///
  /// In it, this message translates to:
  /// **'Aggiorna tutti'**
  String get podcastRefreshAll;

  /// No description provided for @podcastRefresh.
  ///
  /// In it, this message translates to:
  /// **'Aggiorna'**
  String get podcastRefresh;

  /// No description provided for @podcastRefreshed.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =0{Nessun episodio nuovo} one{1 episodio nuovo} other{{count} episodi nuovi}}'**
  String podcastRefreshed(int count);

  /// No description provided for @podcastRefreshFailed.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 podcast non aggiornato} other{{count} podcast non aggiornati}}'**
  String podcastRefreshFailed(int count);

  /// No description provided for @podcastFeedUrl.
  ///
  /// In it, this message translates to:
  /// **'URL del feed'**
  String get podcastFeedUrl;

  /// No description provided for @podcastSubscribe.
  ///
  /// In it, this message translates to:
  /// **'Iscriviti'**
  String get podcastSubscribe;

  /// No description provided for @podcastSearchHint.
  ///
  /// In it, this message translates to:
  /// **'Cerca un podcast per nome'**
  String get podcastSearchHint;

  /// No description provided for @podcastSearchNone.
  ///
  /// In it, this message translates to:
  /// **'Nessun podcast trovato'**
  String get podcastSearchNone;

  /// No description provided for @podcastSubscribed.
  ///
  /// In it, this message translates to:
  /// **'Iscritto a «{name}»'**
  String podcastSubscribed(String name);

  /// No description provided for @podcastEpisodesCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 episodio} other{{count} episodi}}'**
  String podcastEpisodesCount(int count);

  /// No description provided for @podcastToListen.
  ///
  /// In it, this message translates to:
  /// **'{count} da ascoltare'**
  String podcastToListen(int count);

  /// No description provided for @podcastNoEpisodes.
  ///
  /// In it, this message translates to:
  /// **'Nessun episodio.'**
  String get podcastNoEpisodes;

  /// No description provided for @podcastStateDownloaded.
  ///
  /// In it, this message translates to:
  /// **'Scaricato'**
  String get podcastStateDownloaded;

  /// No description provided for @podcastStateDownloading.
  ///
  /// In it, this message translates to:
  /// **'Scarico… {percent}%'**
  String podcastStateDownloading(int percent);

  /// No description provided for @podcastStateHeard.
  ///
  /// In it, this message translates to:
  /// **'Ascoltato'**
  String get podcastStateHeard;

  /// No description provided for @podcastStateRemaining.
  ///
  /// In it, this message translates to:
  /// **'Mancano {time}'**
  String podcastStateRemaining(String time);

  /// No description provided for @podcastMarkHeard.
  ///
  /// In it, this message translates to:
  /// **'Segna come ascoltato'**
  String get podcastMarkHeard;

  /// No description provided for @podcastMarkNotHeard.
  ///
  /// In it, this message translates to:
  /// **'Segna come da ascoltare'**
  String get podcastMarkNotHeard;

  /// No description provided for @podcastDeleteFile.
  ///
  /// In it, this message translates to:
  /// **'Elimina il file'**
  String get podcastDeleteFile;

  /// No description provided for @podcastAutoDelete.
  ///
  /// In it, this message translates to:
  /// **'Elimina gli episodi ascoltati'**
  String get podcastAutoDelete;

  /// No description provided for @podcastAutoDeleteNever.
  ///
  /// In it, this message translates to:
  /// **'Mai'**
  String get podcastAutoDeleteNever;

  /// No description provided for @podcastAutoDeleteAfter.
  ///
  /// In it, this message translates to:
  /// **'{days, plural, one{1 giorno} other{{days} giorni}}'**
  String podcastAutoDeleteAfter(int days);

  /// No description provided for @podcastUnsubscribe.
  ///
  /// In it, this message translates to:
  /// **'Elimina podcast'**
  String get podcastUnsubscribe;

  /// No description provided for @podcastUnsubscribeTitle.
  ///
  /// In it, this message translates to:
  /// **'Eliminare il podcast?'**
  String get podcastUnsubscribeTitle;

  /// No description provided for @podcastUnsubscribeBody.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =0{Il podcast verrà eliminato dal dispositivo.} one{Il podcast e 1 episodio scaricato verranno eliminati dal dispositivo.} other{Il podcast e {count} episodi scaricati verranno eliminati dal dispositivo.}}'**
  String podcastUnsubscribeBody(int count);

  /// No description provided for @podcastLastChecked.
  ///
  /// In it, this message translates to:
  /// **'Aggiornato {when}'**
  String podcastLastChecked(String when);

  /// No description provided for @podcastNeverChecked.
  ///
  /// In it, this message translates to:
  /// **'Mai aggiornato'**
  String get podcastNeverChecked;

  /// No description provided for @podcastErrInvalidUrl.
  ///
  /// In it, this message translates to:
  /// **'Questo non sembra un indirizzo web valido.'**
  String get podcastErrInvalidUrl;

  /// No description provided for @podcastErrTooLarge.
  ///
  /// In it, this message translates to:
  /// **'Il feed è troppo grande.'**
  String get podcastErrTooLarge;

  /// No description provided for @podcastErrNetwork.
  ///
  /// In it, this message translates to:
  /// **'Non riesco a raggiungere il server.'**
  String get podcastErrNetwork;

  /// No description provided for @podcastErrNotFeed.
  ///
  /// In it, this message translates to:
  /// **'Questo indirizzo non è un feed di podcast.'**
  String get podcastErrNotFeed;

  /// No description provided for @podcastErrUnsupportedFormat.
  ///
  /// In it, this message translates to:
  /// **'Formato audio non supportato.'**
  String get podcastErrUnsupportedFormat;

  /// No description provided for @syncTitle.
  ///
  /// In it, this message translates to:
  /// **'Sincronizza playlist'**
  String get syncTitle;

  /// No description provided for @syncAdded.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 nuova} other{{count} nuove}}'**
  String syncAdded(int count);

  /// No description provided for @syncUpdated.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 aggiornata} other{{count} aggiornate}}'**
  String syncUpdated(int count);

  /// No description provided for @syncMissing.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 brano mancante} other{{count} brani mancanti}}'**
  String syncMissing(int count);

  /// No description provided for @syncUpToDate.
  ///
  /// In it, this message translates to:
  /// **'Le playlist sono già allineate'**
  String get syncUpToDate;

  /// No description provided for @syncKept.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 playlist è più recente qui e resta com’è} other{{count} playlist sono più recenti qui e restano come sono}}'**
  String syncKept(int count);

  /// No description provided for @syncReplaceNote.
  ///
  /// In it, this message translates to:
  /// **'Le playlist aggiornate sostituiscono quelle di questo dispositivo.'**
  String get syncReplaceNote;

  /// No description provided for @syncTagNew.
  ///
  /// In it, this message translates to:
  /// **'Nuova'**
  String get syncTagNew;

  /// No description provided for @syncTagUpdated.
  ///
  /// In it, this message translates to:
  /// **'Aggiornata'**
  String get syncTagUpdated;

  /// No description provided for @syncDetailRenamed.
  ///
  /// In it, this message translates to:
  /// **'rinominata'**
  String get syncDetailRenamed;

  /// No description provided for @syncDetailReordered.
  ///
  /// In it, this message translates to:
  /// **'riordinata'**
  String get syncDetailReordered;

  /// No description provided for @syncDetailRemoved.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 brano tolto} other{{count} brani tolti}}'**
  String syncDetailRemoved(int count);

  /// No description provided for @syncAskMissing.
  ///
  /// In it, this message translates to:
  /// **'Chiedi i brani mancanti'**
  String get syncAskMissing;

  /// No description provided for @syncApplied.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 playlist sincronizzata} other{{count} playlist sincronizzate}}'**
  String syncApplied(int count);

  /// No description provided for @trustedSection.
  ///
  /// In it, this message translates to:
  /// **'Dispositivi fidati'**
  String get trustedSection;

  /// No description provided for @trustedFingerprint.
  ///
  /// In it, this message translates to:
  /// **'Impronta {fingerprint}'**
  String trustedFingerprint(String fingerprint);

  /// No description provided for @trustedPairedOn.
  ///
  /// In it, this message translates to:
  /// **'Abbinato il {date}'**
  String trustedPairedOn(String date);

  /// No description provided for @trustedAutoAccept.
  ///
  /// In it, this message translates to:
  /// **'Accetta automaticamente'**
  String get trustedAutoAccept;

  /// No description provided for @trustedAutoAcceptHint.
  ///
  /// In it, this message translates to:
  /// **'Ricevi i brani da questo dispositivo senza chiedere.'**
  String get trustedAutoAcceptHint;

  /// No description provided for @trustedRevoke.
  ///
  /// In it, this message translates to:
  /// **'Revoca'**
  String get trustedRevoke;

  /// No description provided for @trustedRevokeTitle.
  ///
  /// In it, this message translates to:
  /// **'Revocare «{name}»?'**
  String trustedRevokeTitle(String name);

  /// No description provided for @trustedRevokeBody.
  ///
  /// In it, this message translates to:
  /// **'Per inviare di nuovo senza PIN dovrete abbinarvi ancora.'**
  String get trustedRevokeBody;

  /// No description provided for @carMode.
  ///
  /// In it, this message translates to:
  /// **'Modalità in auto'**
  String get carMode;

  /// No description provided for @carExit.
  ///
  /// In it, this message translates to:
  /// **'Esci'**
  String get carExit;

  /// No description provided for @carKeepAwake.
  ///
  /// In it, this message translates to:
  /// **'Schermo sempre acceso'**
  String get carKeepAwake;

  /// No description provided for @carPlaylists.
  ///
  /// In it, this message translates to:
  /// **'Playlist'**
  String get carPlaylists;

  /// No description provided for @carNothing.
  ///
  /// In it, this message translates to:
  /// **'Niente in riproduzione'**
  String get carNothing;

  /// No description provided for @updateCheck.
  ///
  /// In it, this message translates to:
  /// **'Controlla aggiornamenti'**
  String get updateCheck;

  /// No description provided for @updateCheckHint.
  ///
  /// In it, this message translates to:
  /// **'Chiede a GitHub l’ultima versione, solo quando lo chiedi.'**
  String get updateCheckHint;

  /// No description provided for @updateOnStart.
  ///
  /// In it, this message translates to:
  /// **'Controlla all’avvio'**
  String get updateOnStart;

  /// No description provided for @updateOnStartHint.
  ///
  /// In it, this message translates to:
  /// **'Al più una volta al giorno. Non scarica né installa niente.'**
  String get updateOnStartHint;

  /// No description provided for @updateChecking.
  ///
  /// In it, this message translates to:
  /// **'Controllo in corso…'**
  String get updateChecking;

  /// No description provided for @updateAvailable.
  ///
  /// In it, this message translates to:
  /// **'Disponibile la versione {version}'**
  String updateAvailable(String version);

  /// No description provided for @updateUpToDate.
  ///
  /// In it, this message translates to:
  /// **'Hai l’ultima versione ({version})'**
  String updateUpToDate(String version);

  /// No description provided for @updateRateLimited.
  ///
  /// In it, this message translates to:
  /// **'GitHub chiede di aspettare: riprova più tardi.'**
  String get updateRateLimited;

  /// No description provided for @updateFailed.
  ///
  /// In it, this message translates to:
  /// **'Non riesco a leggere l’ultima versione. Controlla la connessione.'**
  String get updateFailed;

  /// No description provided for @updateCopyLink.
  ///
  /// In it, this message translates to:
  /// **'Copia indirizzo'**
  String get updateCopyLink;

  /// No description provided for @updateLinkCopied.
  ///
  /// In it, this message translates to:
  /// **'Indirizzo copiato'**
  String get updateLinkCopied;

  /// No description provided for @backupSection.
  ///
  /// In it, this message translates to:
  /// **'Backup'**
  String get backupSection;

  /// No description provided for @backupCreate.
  ///
  /// In it, this message translates to:
  /// **'Crea backup'**
  String get backupCreate;

  /// No description provided for @backupCreateHint.
  ///
  /// In it, this message translates to:
  /// **'Playlist, preferiti, testi e modifiche in un file zip. La musica non c’è.'**
  String get backupCreateHint;

  /// No description provided for @backupRestore.
  ///
  /// In it, this message translates to:
  /// **'Ripristina da backup'**
  String get backupRestore;

  /// No description provided for @backupRestoreHint.
  ///
  /// In it, this message translates to:
  /// **'Sostituisci questa libreria o unisci i dati di un altro dispositivo.'**
  String get backupRestoreHint;

  /// No description provided for @backupCreating.
  ///
  /// In it, this message translates to:
  /// **'Creo il backup…'**
  String get backupCreating;

  /// No description provided for @backupSaved.
  ///
  /// In it, this message translates to:
  /// **'Backup salvato'**
  String get backupSaved;

  /// No description provided for @backupFailed.
  ///
  /// In it, this message translates to:
  /// **'Backup non riuscito'**
  String get backupFailed;

  /// No description provided for @restoreTitle.
  ///
  /// In it, this message translates to:
  /// **'Ripristina da backup'**
  String get restoreTitle;

  /// No description provided for @restoreInfo.
  ///
  /// In it, this message translates to:
  /// **'Del {date}, app {version}, {tracks} brani, {playlists} playlist'**
  String restoreInfo(String date, String version, int tracks, int playlists);

  /// No description provided for @restoreReplace.
  ///
  /// In it, this message translates to:
  /// **'Sostituisci tutto (stesso dispositivo)'**
  String get restoreReplace;

  /// No description provided for @restoreMerge.
  ///
  /// In it, this message translates to:
  /// **'Unisci a questa libreria'**
  String get restoreMerge;

  /// No description provided for @restoreMergeHint.
  ///
  /// In it, this message translates to:
  /// **'Aggiunge preferiti, playlist, testi e modifiche ai brani che trova. Non cancella niente.'**
  String get restoreMergeHint;

  /// No description provided for @restoreReplaceConfirmTitle.
  ///
  /// In it, this message translates to:
  /// **'Sostituire tutta la libreria?'**
  String get restoreReplaceConfirmTitle;

  /// No description provided for @restoreReplaceConfirmBody.
  ///
  /// In it, this message translates to:
  /// **'Al prossimo avvio i dati di questa app diventano quelli del backup. Quelli attuali restano in una copia di sicurezza accanto al database.'**
  String get restoreReplaceConfirmBody;

  /// No description provided for @restoreReplaceGo.
  ///
  /// In it, this message translates to:
  /// **'Sostituisci'**
  String get restoreReplaceGo;

  /// No description provided for @restoreNotBackup.
  ///
  /// In it, this message translates to:
  /// **'Questo file non è un backup di FreeKmusic che posso leggere.'**
  String get restoreNotBackup;

  /// No description provided for @restoreRestartNeeded.
  ///
  /// In it, this message translates to:
  /// **'Pronto: chiudi l’app e riaprila per completare il ripristino.'**
  String get restoreRestartNeeded;

  /// No description provided for @restoreMergeDone.
  ///
  /// In it, this message translates to:
  /// **'Unione fatta: {recognized} brani riconosciuti, {missing} non trovati, {playlists} playlist create, {favorites} preferiti aggiunti.'**
  String restoreMergeDone(
    int recognized,
    int missing,
    int playlists,
    int favorites,
  );

  /// No description provided for @restoreMergePlays.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 ascolto aggiunto allo storico} other{{count} ascolti aggiunti allo storico}}'**
  String restoreMergePlays(int count);

  /// No description provided for @restoreMergeTags.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 tag aggiunto} other{{count} tag aggiunti}}'**
  String restoreMergeTags(int count);

  /// No description provided for @restoreMergeSmart.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 playlist smart aggiunta} other{{count} playlist smart aggiunte}}'**
  String restoreMergeSmart(int count);

  /// No description provided for @restoreMergePodcasts.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 podcast aggiunto} other{{count} podcast aggiunti}}'**
  String restoreMergePodcasts(int count);

  /// No description provided for @restoreMergeUnlinked.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 ascolto non collegato} other{{count} ascolti non collegati}}'**
  String restoreMergeUnlinked(int count);

  /// No description provided for @restoreMergeThemesDropped.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 tema personalizzato non aggiunto: limite raggiunto} other{{count} temi personalizzati non aggiunti: limite raggiunto}}'**
  String restoreMergeThemesDropped(int count);

  /// No description provided for @restoreMergeDbUnreadable.
  ///
  /// In it, this message translates to:
  /// **'Il database del backup non si legge: storico, tag, playlist smart e podcast non sono stati uniti.'**
  String get restoreMergeDbUnreadable;

  /// No description provided for @restoreNotFound.
  ///
  /// In it, this message translates to:
  /// **'Brani non trovati'**
  String get restoreNotFound;

  /// No description provided for @restoreCopyList.
  ///
  /// In it, this message translates to:
  /// **'Copia elenco'**
  String get restoreCopyList;

  /// No description provided for @restoreFailed.
  ///
  /// In it, this message translates to:
  /// **'Ripristino non riuscito'**
  String get restoreFailed;

  /// No description provided for @exportAllPlaylists.
  ///
  /// In it, this message translates to:
  /// **'Esporta tutte le playlist'**
  String get exportAllPlaylists;

  /// No description provided for @shareErrIdentity.
  ///
  /// In it, this message translates to:
  /// **'L’identità di questo dispositivo è cambiata: toglilo dai fidati e abbinalo di nuovo.'**
  String get shareErrIdentity;

  /// No description provided for @incomingTrustedTag.
  ///
  /// In it, this message translates to:
  /// **'Dispositivo fidato'**
  String get incomingTrustedTag;

  /// No description provided for @incomingTrustedTitle.
  ///
  /// In it, this message translates to:
  /// **'{name} (fidato)'**
  String incomingTrustedTitle(String name);

  /// No description provided for @pairAction.
  ///
  /// In it, this message translates to:
  /// **'Abbina'**
  String get pairAction;

  /// No description provided for @trustedBadge.
  ///
  /// In it, this message translates to:
  /// **'Fidato'**
  String get trustedBadge;

  /// No description provided for @pairPinTitle.
  ///
  /// In it, this message translates to:
  /// **'Abbinamento con {name}'**
  String pairPinTitle(String name);

  /// No description provided for @pairPinHint.
  ///
  /// In it, this message translates to:
  /// **'Scrivi il PIN di 6 cifre mostrato su {name}.'**
  String pairPinHint(String name);

  /// No description provided for @pairPinWrong.
  ///
  /// In it, this message translates to:
  /// **'PIN sbagliato. Tentativi rimasti: {count}.'**
  String pairPinWrong(int count);

  /// No description provided for @pairFingerprint.
  ///
  /// In it, this message translates to:
  /// **'Impronta: {fingerprint}'**
  String pairFingerprint(String fingerprint);

  /// No description provided for @pairCompare.
  ///
  /// In it, this message translates to:
  /// **'Controlla che l’impronta sia la stessa sull’altro schermo.'**
  String get pairCompare;

  /// No description provided for @pairRequestTitle.
  ///
  /// In it, this message translates to:
  /// **'{name} vuole abbinarsi'**
  String pairRequestTitle(String name);

  /// No description provided for @pairRequestBody.
  ///
  /// In it, this message translates to:
  /// **'Scrivi questo PIN sull’altro dispositivo, poi tocca Conferma.'**
  String get pairRequestBody;

  /// No description provided for @pairConfirm.
  ///
  /// In it, this message translates to:
  /// **'Conferma'**
  String get pairConfirm;

  /// No description provided for @pairWaiting.
  ///
  /// In it, this message translates to:
  /// **'In attesa della conferma sull’altro dispositivo…'**
  String get pairWaiting;

  /// No description provided for @pairDone.
  ///
  /// In it, this message translates to:
  /// **'Abbinato con {name}'**
  String pairDone(String name);

  /// No description provided for @pairBlocked.
  ///
  /// In it, this message translates to:
  /// **'Troppi tentativi sbagliati: riprova più tardi.'**
  String get pairBlocked;

  /// No description provided for @pairRejected.
  ///
  /// In it, this message translates to:
  /// **'Abbinamento rifiutato.'**
  String get pairRejected;

  /// No description provided for @pairExpired.
  ///
  /// In it, this message translates to:
  /// **'Richiesta scaduta: riprova.'**
  String get pairExpired;

  /// No description provided for @pairFailed.
  ///
  /// In it, this message translates to:
  /// **'Abbinamento non riuscito.'**
  String get pairFailed;

  /// No description provided for @syncDevice.
  ///
  /// In it, this message translates to:
  /// **'Sincronizza playlist'**
  String get syncDevice;

  /// No description provided for @syncUnreachable.
  ///
  /// In it, this message translates to:
  /// **'Il dispositivo non è visibile sulla rete locale.'**
  String get syncUnreachable;

  /// No description provided for @syncFailed.
  ///
  /// In it, this message translates to:
  /// **'Sincronizzazione non riuscita.'**
  String get syncFailed;

  /// No description provided for @syncAsked.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =0{Nessuno dei brani è sull’altro dispositivo} one{Richiesta inviata: 1 brano in arrivo} other{Richiesta inviata: {count} brani in arrivo}}'**
  String syncAsked(int count);

  /// No description provided for @translateLyrics.
  ///
  /// In it, this message translates to:
  /// **'Traduci'**
  String get translateLyrics;

  /// No description provided for @translateLyricsFrom.
  ///
  /// In it, this message translates to:
  /// **'Lingua del testo'**
  String get translateLyricsFrom;

  /// No description provided for @translateLyricsHint.
  ///
  /// In it, this message translates to:
  /// **'Traduzione sul telefono, nessun testo viene inviato in rete.'**
  String get translateLyricsHint;

  /// No description provided for @translateRemove.
  ///
  /// In it, this message translates to:
  /// **'Mostra solo l\'originale'**
  String get translateRemove;

  /// No description provided for @translateDownloadTitle.
  ///
  /// In it, this message translates to:
  /// **'Scaricare il modello {language}?'**
  String translateDownloadTitle(String language);

  /// No description provided for @translateDownloadBody.
  ///
  /// In it, this message translates to:
  /// **'Servono circa {mb} MB per ogni lingua, meglio con il Wi-Fi. Si scarica una volta sola e poi funziona anche offline.'**
  String translateDownloadBody(int mb);

  /// No description provided for @translateDownload.
  ///
  /// In it, this message translates to:
  /// **'Scarica'**
  String get translateDownload;

  /// No description provided for @translateDownloading.
  ///
  /// In it, this message translates to:
  /// **'Scarico il modello {language}…'**
  String translateDownloading(String language);

  /// No description provided for @translateDownloadFailed.
  ///
  /// In it, this message translates to:
  /// **'Modello non scaricato. Controlla la connessione e lo spazio.'**
  String get translateDownloadFailed;

  /// No description provided for @translateFailed.
  ///
  /// In it, this message translates to:
  /// **'Traduzione non riuscita.'**
  String get translateFailed;

  /// No description provided for @translateSameLanguage.
  ///
  /// In it, this message translates to:
  /// **'Il testo è già in questa lingua.'**
  String get translateSameLanguage;

  /// No description provided for @translationModels.
  ///
  /// In it, this message translates to:
  /// **'Modelli di traduzione'**
  String get translationModels;

  /// No description provided for @translationModelsNone.
  ///
  /// In it, this message translates to:
  /// **'Nessun modello scaricato. Si scaricano dalla schermata dei testi, con «Traduci».'**
  String get translationModelsNone;

  /// No description provided for @translationModelDelete.
  ///
  /// In it, this message translates to:
  /// **'Elimina il modello {language}'**
  String translationModelDelete(String language);

  /// No description provided for @scanCode.
  ///
  /// In it, this message translates to:
  /// **'Scansiona codice'**
  String get scanCode;

  /// No description provided for @scanTitle.
  ///
  /// In it, this message translates to:
  /// **'Inquadra il codice QR'**
  String get scanTitle;

  /// No description provided for @scanNotCodecore.
  ///
  /// In it, this message translates to:
  /// **'Questo codice non è di FreeKmusic.'**
  String get scanNotCodecore;

  /// No description provided for @scanCameraDenied.
  ///
  /// In it, this message translates to:
  /// **'Serve il permesso della fotocamera per leggere il codice.'**
  String get scanCameraDenied;

  /// No description provided for @scanOpenSettings.
  ///
  /// In it, this message translates to:
  /// **'Apri impostazioni'**
  String get scanOpenSettings;

  /// No description provided for @ownFingerprint.
  ///
  /// In it, this message translates to:
  /// **'Impronta di questo dispositivo'**
  String get ownFingerprint;

  /// No description provided for @ownFingerprintHint.
  ///
  /// In it, this message translates to:
  /// **'Si confronta con quella mostrata sull’altro schermo quando ci si abbina.'**
  String get ownFingerprintHint;

  /// No description provided for @writeTagsToFiles.
  ///
  /// In it, this message translates to:
  /// **'Scrivi le modifiche nei file'**
  String get writeTagsToFiles;

  /// No description provided for @writeTagsToFilesHint.
  ///
  /// In it, this message translates to:
  /// **'Titolo, artista, album, anno, genere e traccia modificati qui vengono scritti anche in MP3, FLAC, M4A e OGG. Di ogni file si conserva l’originale. Spenta di default.'**
  String get writeTagsToFilesHint;

  /// No description provided for @writeTagsAfterDownload.
  ///
  /// In it, this message translates to:
  /// **'Scrivi i tag nei file scaricati'**
  String get writeTagsAfterDownload;

  /// No description provided for @writeTagsAfterDownloadHint.
  ///
  /// In it, this message translates to:
  /// **'Solo nei file che FreeKmusic ha scaricato o ricevuto. L\'ISRC resta nell\'app.'**
  String get writeTagsAfterDownloadHint;

  /// No description provided for @writeTagsWarnTitle.
  ///
  /// In it, this message translates to:
  /// **'Scrivere le modifiche nei file?'**
  String get writeTagsWarnTitle;

  /// No description provided for @writeTagsWarnBody.
  ///
  /// In it, this message translates to:
  /// **'Salvando una modifica, i tag vengono riscritti anche nel file musicale (MP3, FLAC, M4A, OGG). Si lavora su una copia, si controlla il risultato e il file viene sostituito solo se tutto torna; prima l’originale è salvato in «Backup dei tag» (gli ultimi 200 o 2 GB). Copertina, testi e ReplayGain non vengono toccati. Prima di attivare conviene fare un backup della libreria (Impostazioni, Backup).'**
  String get writeTagsWarnBody;

  /// No description provided for @writeTagsEnable.
  ///
  /// In it, this message translates to:
  /// **'Attiva'**
  String get writeTagsEnable;

  /// No description provided for @tagsAlsoInFile.
  ///
  /// In it, this message translates to:
  /// **'Scrivi anche nel file'**
  String get tagsAlsoInFile;

  /// No description provided for @tagsNoWriteUnsupported.
  ///
  /// In it, this message translates to:
  /// **'Formato non modificabile ({format}): cambia solo la libreria'**
  String tagsNoWriteUnsupported(String format);

  /// No description provided for @tagsNoWriteReadOnly.
  ///
  /// In it, this message translates to:
  /// **'File in sola lettura: cambia solo la libreria'**
  String get tagsNoWriteReadOnly;

  /// No description provided for @tagsNoWriteMissing.
  ///
  /// In it, this message translates to:
  /// **'File non trovato: cambia solo la libreria'**
  String get tagsNoWriteMissing;

  /// No description provided for @tagsFileWriteFailed.
  ///
  /// In it, this message translates to:
  /// **'Salvato nella libreria, ma {count, plural, one{1 file non è stato modificato} other{{count} file non sono stati modificati}}: {reason}'**
  String tagsFileWriteFailed(int count, String reason);

  /// No description provided for @tagReasonUnsupported.
  ///
  /// In it, this message translates to:
  /// **'formato non supportato'**
  String get tagReasonUnsupported;

  /// No description provided for @tagReasonNotFound.
  ///
  /// In it, this message translates to:
  /// **'file non trovato'**
  String get tagReasonNotFound;

  /// No description provided for @tagReasonReadOnly.
  ///
  /// In it, this message translates to:
  /// **'file in sola lettura'**
  String get tagReasonReadOnly;

  /// No description provided for @tagReasonVerifyFailed.
  ///
  /// In it, this message translates to:
  /// **'il controllo dopo la scrittura è fallito, il file è rimasto com’era'**
  String get tagReasonVerifyFailed;

  /// No description provided for @tagReasonWriteFailed.
  ///
  /// In it, this message translates to:
  /// **'scrittura non riuscita, il file è rimasto com’era'**
  String get tagReasonWriteFailed;

  /// No description provided for @tagReasonBackupFailed.
  ///
  /// In it, this message translates to:
  /// **'backup dell’originale non riuscito, il file è rimasto com’era'**
  String get tagReasonBackupFailed;

  /// No description provided for @tagReasonIoError.
  ///
  /// In it, this message translates to:
  /// **'errore del disco o dei permessi'**
  String get tagReasonIoError;

  /// No description provided for @tagBackupsTitle.
  ///
  /// In it, this message translates to:
  /// **'Backup dei tag'**
  String get tagBackupsTitle;

  /// No description provided for @tagBackupsCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =0{Backup dei tag} one{Backup dei tag (1)} other{Backup dei tag ({count})}}'**
  String tagBackupsCount(int count);

  /// No description provided for @tagBackupsHint.
  ///
  /// In it, this message translates to:
  /// **'L’originale di ogni file riscritto, prima della modifica. Si tengono gli ultimi 200 o 2 GB.'**
  String get tagBackupsHint;

  /// No description provided for @tagBackupsEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessun backup: i file non sono ancora stati riscritti.'**
  String get tagBackupsEmpty;

  /// No description provided for @tagBackupRestore.
  ///
  /// In it, this message translates to:
  /// **'Ripristina originale'**
  String get tagBackupRestore;

  /// No description provided for @tagBackupRestoreBody.
  ///
  /// In it, this message translates to:
  /// **'Il file «{name}» torna com’era prima della modifica. La libreria tiene le modifiche fatte nell’app.'**
  String tagBackupRestoreBody(String name);

  /// No description provided for @tagBackupRestored.
  ///
  /// In it, this message translates to:
  /// **'Originale ripristinato'**
  String get tagBackupRestored;

  /// No description provided for @tagBackupRestoreFailed.
  ///
  /// In it, this message translates to:
  /// **'Ripristino non riuscito: {reason}'**
  String tagBackupRestoreFailed(String reason);

  /// No description provided for @tagBackupDelete.
  ///
  /// In it, this message translates to:
  /// **'Elimina backup'**
  String get tagBackupDelete;

  /// No description provided for @tagBackupDeleteBody.
  ///
  /// In it, this message translates to:
  /// **'Non potrai più riportare il file a com’era prima della modifica.'**
  String get tagBackupDeleteBody;

  /// No description provided for @tagBackupDeleted.
  ///
  /// In it, this message translates to:
  /// **'Backup eliminato'**
  String get tagBackupDeleted;

  /// No description provided for @deleteFromDevice.
  ///
  /// In it, this message translates to:
  /// **'Elimina dal dispositivo'**
  String get deleteFromDevice;

  /// No description provided for @deleteTrackTitle.
  ///
  /// In it, this message translates to:
  /// **'Eliminare «{title}»?'**
  String deleteTrackTitle(String title);

  /// No description provided for @deleteTrackBody.
  ///
  /// In it, this message translates to:
  /// **'Il file viene cancellato dal dispositivo e il brano sparisce dalla libreria, dalle playlist, dai preferiti e dalla cronologia. Non si può annullare.'**
  String get deleteTrackBody;

  /// No description provided for @deleteTracksTitle.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{Eliminare 1 brano?} other{Eliminare {count} brani?}}'**
  String deleteTracksTitle(int count);

  /// No description provided for @deleteTracksBody.
  ///
  /// In it, this message translates to:
  /// **'I file vengono cancellati dal dispositivo e i brani spariscono dalla libreria, dalle playlist, dai preferiti e dalla cronologia. Non si può annullare.'**
  String get deleteTracksBody;

  /// No description provided for @deleteConfirm.
  ///
  /// In it, this message translates to:
  /// **'Elimina'**
  String get deleteConfirm;

  /// No description provided for @trackDeleted.
  ///
  /// In it, this message translates to:
  /// **'Brano eliminato'**
  String get trackDeleted;

  /// No description provided for @trackDeleteFailed.
  ///
  /// In it, this message translates to:
  /// **'Impossibile eliminare il file: {reason}'**
  String trackDeleteFailed(String reason);

  /// No description provided for @tracksDeleted.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 brano eliminato} other{{count} brani eliminati}}'**
  String tracksDeleted(int count);

  /// No description provided for @tracksDeletedSome.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 brano eliminato} other{{count} brani eliminati}}, {failed} non eliminati'**
  String tracksDeletedSome(int count, int failed);

  /// No description provided for @trackDeleteRefused.
  ///
  /// In it, this message translates to:
  /// **'Android non ha permesso di eliminare il file'**
  String get trackDeleteRefused;

  /// No description provided for @reviewTitle.
  ///
  /// In it, this message translates to:
  /// **'Da revisionare'**
  String get reviewTitle;

  /// No description provided for @reviewFilterAll.
  ///
  /// In it, this message translates to:
  /// **'Tutti'**
  String get reviewFilterAll;

  /// No description provided for @reviewFilterNothingFound.
  ///
  /// In it, this message translates to:
  /// **'Nessun risultato'**
  String get reviewFilterNothingFound;

  /// No description provided for @reviewFilterNoLyrics.
  ///
  /// In it, this message translates to:
  /// **'Senza testo'**
  String get reviewFilterNoLyrics;

  /// No description provided for @reviewFilterNoCover.
  ///
  /// In it, this message translates to:
  /// **'Senza copertina'**
  String get reviewFilterNoCover;

  /// No description provided for @reviewFilterMissingData.
  ///
  /// In it, this message translates to:
  /// **'Dati mancanti'**
  String get reviewFilterMissingData;

  /// No description provided for @reviewEmpty.
  ///
  /// In it, this message translates to:
  /// **'Niente da revisionare: ai brani cercati non manca nulla'**
  String get reviewEmpty;

  /// No description provided for @reviewHint.
  ///
  /// In it, this message translates to:
  /// **'Brani a cui manca qualcosa. Cerca di nuovo o lascia così.'**
  String get reviewHint;

  /// No description provided for @reviewRetry.
  ///
  /// In it, this message translates to:
  /// **'Riprova'**
  String get reviewRetry;

  /// No description provided for @reviewDismiss.
  ///
  /// In it, this message translates to:
  /// **'Ignora'**
  String get reviewDismiss;

  /// No description provided for @reviewRetryStarted.
  ///
  /// In it, this message translates to:
  /// **'Ricerca avviata per {count, plural, one{1 brano} other{{count} brani}}'**
  String reviewRetryStarted(int count);

  /// No description provided for @reviewDismissed.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 brano tolto dall\'elenco} other{{count} brani tolti dall\'elenco}}'**
  String reviewDismissed(int count);

  /// No description provided for @reviewSecondOpinionProgress.
  ///
  /// In it, this message translates to:
  /// **'Controllo con YouTube Music, {done} di {total}'**
  String reviewSecondOpinionProgress(int done, int total);

  /// No description provided for @reviewSecondOpinionStop.
  ///
  /// In it, this message translates to:
  /// **'Ferma'**
  String get reviewSecondOpinionStop;

  /// No description provided for @reviewSecondOpinionDone.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{Aggiornato 1 brano con YouTube Music} other{Aggiornati {count} brani con YouTube Music}}'**
  String reviewSecondOpinionDone(int count);

  /// No description provided for @reviewSecondOpinionThrottled.
  ///
  /// In it, this message translates to:
  /// **'YouTube Music ha chiesto di rallentare: i brani rimasti si controlleranno più tardi'**
  String get reviewSecondOpinionThrottled;

  /// No description provided for @activitySecondOpinion.
  ///
  /// In it, this message translates to:
  /// **'Secondo parere: {done} di {total}'**
  String activitySecondOpinion(int done, int total);

  /// No description provided for @secondOpinionLogTitle.
  ///
  /// In it, this message translates to:
  /// **'Secondo parere'**
  String get secondOpinionLogTitle;

  /// No description provided for @secondOpinionLogEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessun brano controllato'**
  String get secondOpinionLogEmpty;

  /// No description provided for @secondOpinionConfirmed.
  ///
  /// In it, this message translates to:
  /// **'Confermato, niente da aggiungere'**
  String get secondOpinionConfirmed;

  /// No description provided for @secondOpinionConfirmedFields.
  ///
  /// In it, this message translates to:
  /// **'Confermato, aggiunto: {fields}'**
  String secondOpinionConfirmedFields(String fields);

  /// No description provided for @secondOpinionNotConfirmed.
  ///
  /// In it, this message translates to:
  /// **'Non confermato'**
  String get secondOpinionNotConfirmed;

  /// No description provided for @secondOpinionNetwork.
  ///
  /// In it, this message translates to:
  /// **'Rete non disponibile, da riprovare'**
  String get secondOpinionNetwork;

  /// No description provided for @secondOpinionThrottled.
  ///
  /// In it, this message translates to:
  /// **'YouTube Music ha chiesto di rallentare'**
  String get secondOpinionThrottled;

  /// No description provided for @sourceYoutubeMusic.
  ///
  /// In it, this message translates to:
  /// **'Fonte: YouTube Music'**
  String get sourceYoutubeMusic;

  /// No description provided for @curiositySourceDiscogs.
  ///
  /// In it, this message translates to:
  /// **'Dall\'album, da Discogs'**
  String get curiositySourceDiscogs;

  /// No description provided for @navMemory.
  ///
  /// In it, this message translates to:
  /// **'Memoria'**
  String get navMemory;

  /// No description provided for @memoryMusicLabel.
  ///
  /// In it, this message translates to:
  /// **'Musica'**
  String get memoryMusicLabel;

  /// No description provided for @memoryOtherLabel.
  ///
  /// In it, this message translates to:
  /// **'Altro'**
  String get memoryOtherLabel;

  /// No description provided for @memoryFreeLabel.
  ///
  /// In it, this message translates to:
  /// **'Libero'**
  String get memoryFreeLabel;

  /// No description provided for @memoryDeviceLine.
  ///
  /// In it, this message translates to:
  /// **'{free} liberi su {total}'**
  String memoryDeviceLine(String free, String total);

  /// No description provided for @memoryPlaylists.
  ///
  /// In it, this message translates to:
  /// **'Playlist'**
  String get memoryPlaylists;

  /// No description provided for @memoryPlaylistsNote.
  ///
  /// In it, this message translates to:
  /// **'Un brano presente in più playlist conta in ognuna: la somma può superare il totale.'**
  String get memoryPlaylistsNote;

  /// No description provided for @memoryByFormat.
  ///
  /// In it, this message translates to:
  /// **'Formati'**
  String get memoryByFormat;

  /// No description provided for @memoryByFolder.
  ///
  /// In it, this message translates to:
  /// **'Cartelle'**
  String get memoryByFolder;

  /// No description provided for @memoryNoFolder.
  ///
  /// In it, this message translates to:
  /// **'Fuori dalle cartelle'**
  String get memoryNoFolder;

  /// No description provided for @memoryHeaviest.
  ///
  /// In it, this message translates to:
  /// **'I più pesanti'**
  String get memoryHeaviest;

  /// No description provided for @memoryHeaviestTracks.
  ///
  /// In it, this message translates to:
  /// **'Brani'**
  String get memoryHeaviestTracks;

  /// No description provided for @memoryHeaviestAlbums.
  ///
  /// In it, this message translates to:
  /// **'Album'**
  String get memoryHeaviestAlbums;

  /// No description provided for @memoryNeverPlayed.
  ///
  /// In it, this message translates to:
  /// **'Mai ascoltati'**
  String get memoryNeverPlayed;

  /// No description provided for @memoryNeverPlayedHint.
  ///
  /// In it, this message translates to:
  /// **'Brani senza nemmeno un ascolto. Selezionane alcuni per eliminarli dal dispositivo.'**
  String get memoryNeverPlayedHint;

  /// No description provided for @memoryNeverPlayedNone.
  ///
  /// In it, this message translates to:
  /// **'Hai ascoltato tutta la musica'**
  String get memoryNeverPlayedNone;

  /// No description provided for @memoryAppData.
  ///
  /// In it, this message translates to:
  /// **'Dati dell\'app'**
  String get memoryAppData;

  /// No description provided for @memoryCovers.
  ///
  /// In it, this message translates to:
  /// **'Copertine'**
  String get memoryCovers;

  /// No description provided for @memoryCoversThumbs.
  ///
  /// In it, this message translates to:
  /// **'di cui anteprime {size}'**
  String memoryCoversThumbs(String size);

  /// No description provided for @memoryDatabase.
  ///
  /// In it, this message translates to:
  /// **'Libreria'**
  String get memoryDatabase;

  /// No description provided for @memoryImageMemory.
  ///
  /// In it, this message translates to:
  /// **'Immagini in memoria'**
  String get memoryImageMemory;

  /// No description provided for @memoryJamCache.
  ///
  /// In it, this message translates to:
  /// **'Cache Jam'**
  String get memoryJamCache;

  /// No description provided for @memorySearchCache.
  ///
  /// In it, this message translates to:
  /// **'Cache delle ricerche'**
  String get memorySearchCache;

  /// No description provided for @memoryCatalogCache.
  ///
  /// In it, this message translates to:
  /// **'Catalogo online'**
  String get memoryCatalogCache;

  /// No description provided for @memoryBlurCopies.
  ///
  /// In it, this message translates to:
  /// **'Sfondi sfocati'**
  String get memoryBlurCopies;

  /// No description provided for @memoryTagBackups.
  ///
  /// In it, this message translates to:
  /// **'Backup dei tag'**
  String get memoryTagBackups;

  /// No description provided for @memoryLog.
  ///
  /// In it, this message translates to:
  /// **'Registro'**
  String get memoryLog;

  /// No description provided for @memoryPodcasts.
  ///
  /// In it, this message translates to:
  /// **'Episodi dei podcast'**
  String get memoryPodcasts;

  /// No description provided for @memoryClearCache.
  ///
  /// In it, this message translates to:
  /// **'Svuota cache'**
  String get memoryClearCache;

  /// No description provided for @memoryCleared.
  ///
  /// In it, this message translates to:
  /// **'Liberati {size}'**
  String memoryCleared(String size);

  /// No description provided for @memoryClearedJamKept.
  ///
  /// In it, this message translates to:
  /// **'Liberati {size}. La cache Jam è in uso e non è stata toccata'**
  String memoryClearedJamKept(String size);

  /// No description provided for @memoryClearFailed.
  ///
  /// In it, this message translates to:
  /// **'Impossibile svuotare la cache'**
  String get memoryClearFailed;

  /// No description provided for @memoryOfMusic.
  ///
  /// In it, this message translates to:
  /// **'di musica'**
  String get memoryOfMusic;

  /// No description provided for @memoryShowAll.
  ///
  /// In it, this message translates to:
  /// **'Mostra tutti'**
  String get memoryShowAll;

  /// No description provided for @memoryCache.
  ///
  /// In it, this message translates to:
  /// **'Cache'**
  String get memoryCache;

  /// No description provided for @memoryCacheHint.
  ///
  /// In it, this message translates to:
  /// **'Immagini, ricerche, Jam'**
  String get memoryCacheHint;

  /// No description provided for @memoryDatabaseHint.
  ///
  /// In it, this message translates to:
  /// **'Il database con brani e ascolti'**
  String get memoryDatabaseHint;

  /// No description provided for @memoryTagBackupsHint.
  ///
  /// In it, this message translates to:
  /// **'Prima di ogni modifica ai file'**
  String get memoryTagBackupsHint;

  /// No description provided for @memoryTinyNote.
  ///
  /// In it, this message translates to:
  /// **'I dati sotto 1 MB non sono elencati.'**
  String get memoryTinyNote;

  /// No description provided for @memoryClearHint.
  ///
  /// In it, this message translates to:
  /// **'Libera {size}. Brani, copertine e ascolti restano.'**
  String memoryClearHint(String size);

  /// No description provided for @memoryDuplicateGroups.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 gruppo} other{{count} gruppi}}'**
  String memoryDuplicateGroups(int count);

  /// No description provided for @memoryTools.
  ///
  /// In it, this message translates to:
  /// **'Strumenti'**
  String get memoryTools;

  /// No description provided for @memoryUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Non disponibile'**
  String get memoryUnavailable;

  /// No description provided for @ytmArtistWithAudience.
  ///
  /// In it, this message translates to:
  /// **'Artista, {audience}'**
  String ytmArtistWithAudience(String audience);

  /// No description provided for @ytmOffline.
  ///
  /// In it, this message translates to:
  /// **'Non in linea, dati del {date}'**
  String ytmOffline(String date);

  /// No description provided for @ytmArtistNotFound.
  ///
  /// In it, this message translates to:
  /// **'Artista non trovato'**
  String get ytmArtistNotFound;

  /// No description provided for @ytmPageUnreadable.
  ///
  /// In it, this message translates to:
  /// **'La pagina non si legge (YouTube ha cambiato qualcosa)'**
  String get ytmPageUnreadable;

  /// No description provided for @ytmArtistUnreadable.
  ///
  /// In it, this message translates to:
  /// **'La pagina dell\'artista non si legge (YouTube ha cambiato qualcosa)'**
  String get ytmArtistUnreadable;

  /// No description provided for @ytmSearchSongsOf.
  ///
  /// In it, this message translates to:
  /// **'Cerca i brani di {name}'**
  String ytmSearchSongsOf(String name);

  /// No description provided for @ytmInYourLibrary.
  ///
  /// In it, this message translates to:
  /// **'Nella tua libreria'**
  String get ytmInYourLibrary;

  /// No description provided for @ytmAbout.
  ///
  /// In it, this message translates to:
  /// **'Informazioni'**
  String get ytmAbout;

  /// No description provided for @ytmMore.
  ///
  /// In it, this message translates to:
  /// **'Altro'**
  String get ytmMore;

  /// No description provided for @ytmLess.
  ///
  /// In it, this message translates to:
  /// **'Meno'**
  String get ytmLess;

  /// No description provided for @ytmDownloadAlbum.
  ///
  /// In it, this message translates to:
  /// **'Scarica album'**
  String get ytmDownloadAlbum;

  /// No description provided for @ytmDownloadAlbumTitle.
  ///
  /// In it, this message translates to:
  /// **'Scaricare «{album}»?'**
  String ytmDownloadAlbumTitle(String album);

  /// No description provided for @ytmAlbumConfirmBody.
  ///
  /// In it, this message translates to:
  /// **'{tracks, plural, one{1 brano} other{{tracks} brani}}, {duration}, circa {size}'**
  String ytmAlbumConfirmBody(int tracks, String duration, String size);

  /// No description provided for @ytmAlbumConfirmOwned.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 brano è già in libreria e verrà collegato} other{{count} brani sono già in libreria e verranno collegati}}'**
  String ytmAlbumConfirmOwned(int count);

  /// No description provided for @ytmAlbumStarted.
  ///
  /// In it, this message translates to:
  /// **'Importazione «{name}» avviata'**
  String ytmAlbumStarted(String name);

  /// No description provided for @ytmShowImport.
  ///
  /// In it, this message translates to:
  /// **'Mostra'**
  String get ytmShowImport;

  /// No description provided for @ytmOnYoutubeMusic.
  ///
  /// In it, this message translates to:
  /// **'Su YouTube Music'**
  String get ytmOnYoutubeMusic;

  /// No description provided for @ytmArtistOnYoutubeMusic.
  ///
  /// In it, this message translates to:
  /// **'Artista su YouTube Music'**
  String get ytmArtistOnYoutubeMusic;

  /// No description provided for @ytmSearchingArtist.
  ///
  /// In it, this message translates to:
  /// **'Cerco su YouTube Music…'**
  String get ytmSearchingArtist;

  /// No description provided for @ytmPickArtist.
  ///
  /// In it, this message translates to:
  /// **'Quale artista?'**
  String get ytmPickArtist;

  /// No description provided for @ytmArtistNone.
  ///
  /// In it, this message translates to:
  /// **'Nessun artista trovato su YouTube Music'**
  String get ytmArtistNone;

  /// No description provided for @suggestedBadge.
  ///
  /// In it, this message translates to:
  /// **'Suggerito'**
  String get suggestedBadge;

  /// No description provided for @suggestedSimilarTo.
  ///
  /// In it, this message translates to:
  /// **'Suggerito: simile a «{seed}»'**
  String suggestedSimilarTo(String seed);

  /// No description provided for @suggestionDownloadStarted.
  ///
  /// In it, this message translates to:
  /// **'Download avviato'**
  String get suggestionDownloadStarted;

  /// No description provided for @suggestionAddWhenDownloaded.
  ///
  /// In it, this message translates to:
  /// **'Lo scarico e lo aggiungo a «{name}»'**
  String suggestionAddWhenDownloaded(String name);

  /// No description provided for @dislikesTitle.
  ///
  /// In it, this message translates to:
  /// **'Non mi piace'**
  String get dislikesTitle;

  /// No description provided for @dislikesHint.
  ///
  /// In it, this message translates to:
  /// **'Cosa non vuoi tra i suggeriti. I brani possono tornare solo se molto vicini a ciò che ascolti; gli artisti mai più.'**
  String get dislikesHint;

  /// No description provided for @dislikesTracksTab.
  ///
  /// In it, this message translates to:
  /// **'Brani {count}'**
  String dislikesTracksTab(int count);

  /// No description provided for @dislikesArtistsTab.
  ///
  /// In it, this message translates to:
  /// **'Artisti {count}'**
  String dislikesArtistsTab(int count);

  /// No description provided for @dislikesEmptyTracks.
  ///
  /// In it, this message translates to:
  /// **'Nessun brano escluso'**
  String get dislikesEmptyTracks;

  /// No description provided for @dislikesEmptyArtists.
  ///
  /// In it, this message translates to:
  /// **'Nessun artista escluso'**
  String get dislikesEmptyArtists;

  /// No description provided for @dislikesEmptyHint.
  ///
  /// In it, this message translates to:
  /// **'Quando tocchi «Non mi piace» su un suggerito, lo trovi qui e puoi toglierlo.'**
  String get dislikesEmptyHint;

  /// No description provided for @dislikesRemove.
  ///
  /// In it, this message translates to:
  /// **'Togli'**
  String get dislikesRemove;

  /// No description provided for @dislikesRemoveLabel.
  ///
  /// In it, this message translates to:
  /// **'Togli «{name}» dai non mi piace'**
  String dislikesRemoveLabel(String name);

  /// No description provided for @dislikesRemoved.
  ///
  /// In it, this message translates to:
  /// **'«{name}» tolto dai non mi piace'**
  String dislikesRemoved(String name);

  /// No description provided for @dislikesTileHint.
  ///
  /// In it, this message translates to:
  /// **'Brani e artisti esclusi dai suggeriti'**
  String get dislikesTileHint;

  /// No description provided for @dislikePlayerLabel.
  ///
  /// In it, this message translates to:
  /// **'Non mi piace: brano o artista'**
  String get dislikePlayerLabel;

  /// No description provided for @suggestionDislike.
  ///
  /// In it, this message translates to:
  /// **'Non mi piace'**
  String get suggestionDislike;

  /// No description provided for @suggestionDisliked.
  ///
  /// In it, this message translates to:
  /// **'Non te lo suggerirò più'**
  String get suggestionDisliked;

  /// No description provided for @removeFromQueueAction.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi dalla coda'**
  String get removeFromQueueAction;

  /// No description provided for @shuffleModeOff.
  ///
  /// In it, this message translates to:
  /// **'Casuale: spenta'**
  String get shuffleModeOff;

  /// No description provided for @shuffleModeOn.
  ///
  /// In it, this message translates to:
  /// **'Casuale: attiva'**
  String get shuffleModeOn;

  /// No description provided for @shuffleModePlus.
  ///
  /// In it, this message translates to:
  /// **'Casuale+: attiva (premi a lungo per le impostazioni)'**
  String get shuffleModePlus;

  /// No description provided for @shufflePlusTitle.
  ///
  /// In it, this message translates to:
  /// **'Casuale+'**
  String get shufflePlusTitle;

  /// No description provided for @shufflePlusNote.
  ///
  /// In it, this message translates to:
  /// **'Si attiva dal pulsante shuffle (terzo tocco). Non disponibile per album in streaming, Jam e radio'**
  String get shufflePlusNote;

  /// No description provided for @shufflePlusEvery.
  ///
  /// In it, this message translates to:
  /// **'Un suggerito ogni {n} brani'**
  String shufflePlusEvery(int n);

  /// No description provided for @shufflePlusUnmeteredOnly.
  ///
  /// In it, this message translates to:
  /// **'Solo su Wi‑Fi'**
  String get shufflePlusUnmeteredOnly;

  /// No description provided for @shufflePlusUnmeteredOnlyHint.
  ///
  /// In it, this message translates to:
  /// **'Niente suggeriti con i dati mobili o su reti a consumo.'**
  String get shufflePlusUnmeteredOnlyHint;

  /// No description provided for @shufflePlusData.
  ///
  /// In it, this message translates to:
  /// **'Consumo stimato: circa 15 MB all’ora con un suggerito ogni 4 brani.'**
  String get shufflePlusData;

  /// No description provided for @shufflePlusActive.
  ///
  /// In it, this message translates to:
  /// **'Attivo: i suggeriti arrivano mentre ascolti.'**
  String get shufflePlusActive;

  /// No description provided for @shufflePlusOff.
  ///
  /// In it, this message translates to:
  /// **'Spento: la casuale resta normale.'**
  String get shufflePlusOff;

  /// No description provided for @shufflePlusBlockJam.
  ///
  /// In it, this message translates to:
  /// **'Non attivo durante una Jam'**
  String get shufflePlusBlockJam;

  /// No description provided for @shufflePlusBlockShort.
  ///
  /// In it, this message translates to:
  /// **'Serve una lista di almeno 5 brani'**
  String get shufflePlusBlockShort;

  /// No description provided for @shufflePlusBlockNoTool.
  ///
  /// In it, this message translates to:
  /// **'yt-dlp non disponibile'**
  String get shufflePlusBlockNoTool;

  /// No description provided for @shufflePlusBlockMetered.
  ///
  /// In it, this message translates to:
  /// **'In pausa: rete a consumo'**
  String get shufflePlusBlockMetered;

  /// No description provided for @shufflePlusBlockStopped.
  ///
  /// In it, this message translates to:
  /// **'Spento fino al riavvio: troppi errori di riproduzione'**
  String get shufflePlusBlockStopped;

  /// No description provided for @shufflePlusBlockOnline.
  ///
  /// In it, this message translates to:
  /// **'Non disponibile per un album in streaming'**
  String get shufflePlusBlockOnline;

  /// No description provided for @shufflePlusBlockRadio.
  ///
  /// In it, this message translates to:
  /// **'Non disponibile con la radio'**
  String get shufflePlusBlockRadio;

  /// No description provided for @shufflePlusNoticeRateLimited.
  ///
  /// In it, this message translates to:
  /// **'YouTube chiede di rallentare: i suggeriti sono in pausa per 15 minuti'**
  String get shufflePlusNoticeRateLimited;

  /// No description provided for @shufflePlusNoticeTooManyErrors.
  ///
  /// In it, this message translates to:
  /// **'Troppi errori di riproduzione: i suggeriti sono spenti fino al riavvio'**
  String get shufflePlusNoticeTooManyErrors;

  /// No description provided for @suggestionsRecentTitle.
  ///
  /// In it, this message translates to:
  /// **'Suggeriti di recente'**
  String get suggestionsRecentTitle;

  /// No description provided for @suggestionsRecentEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessun suggerito per ora. Compaiono qui quando usi Casuale+.'**
  String get suggestionsRecentEmpty;

  /// No description provided for @suggestionsClear.
  ///
  /// In it, this message translates to:
  /// **'Svuota registro'**
  String get suggestionsClear;

  /// No description provided for @suggestionsClearBody.
  ///
  /// In it, this message translates to:
  /// **'Dimentica i suggeriti e i «Non mi piace»: potranno tornare.'**
  String get suggestionsClearBody;

  /// No description provided for @suggestionsRowNote.
  ///
  /// In it, this message translates to:
  /// **'simile a «{seed}», {outcome}'**
  String suggestionsRowNote(String seed, String outcome);

  /// No description provided for @suggestionOutcomeQueued.
  ///
  /// In it, this message translates to:
  /// **'In coda'**
  String get suggestionOutcomeQueued;

  /// No description provided for @suggestionOutcomeSkipped.
  ///
  /// In it, this message translates to:
  /// **'Saltato'**
  String get suggestionOutcomeSkipped;

  /// No description provided for @suggestionOutcomeHeard.
  ///
  /// In it, this message translates to:
  /// **'Ascoltato'**
  String get suggestionOutcomeHeard;

  /// No description provided for @suggestionOutcomeDownloaded.
  ///
  /// In it, this message translates to:
  /// **'Scaricato'**
  String get suggestionOutcomeDownloaded;

  /// No description provided for @suggestionOutcomeDisliked.
  ///
  /// In it, this message translates to:
  /// **'Non mi piace'**
  String get suggestionOutcomeDisliked;

  /// No description provided for @memorySuggestions.
  ///
  /// In it, this message translates to:
  /// **'Suggeriti di Casuale+'**
  String get memorySuggestions;

  /// No description provided for @searchOnline.
  ///
  /// In it, this message translates to:
  /// **'Cerca «{query}» online'**
  String searchOnline(String query);

  /// No description provided for @onlineBestResults.
  ///
  /// In it, this message translates to:
  /// **'Migliori risultati'**
  String get onlineBestResults;

  /// No description provided for @onlineOthersChip.
  ///
  /// In it, this message translates to:
  /// **'Altri risultati ({count})'**
  String onlineOthersChip(int count);

  /// No description provided for @onlineNoneSure.
  ///
  /// In it, this message translates to:
  /// **'Nessun risultato sicuro'**
  String get onlineNoneSure;

  /// No description provided for @onlineInLibrary.
  ///
  /// In it, this message translates to:
  /// **'Nella tua libreria'**
  String get onlineInLibrary;

  /// No description provided for @onlineShowAllCount.
  ///
  /// In it, this message translates to:
  /// **'Mostra tutti ({count})'**
  String onlineShowAllCount(int count);

  /// No description provided for @onlineOwnedHidden.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 risultato già in libreria nascosto} other{{count} risultati già in libreria nascosti}}'**
  String onlineOwnedHidden(int count);

  /// No description provided for @onlineArtistSongs.
  ///
  /// In it, this message translates to:
  /// **'Brani di {artist}'**
  String onlineArtistSongs(String artist);

  /// No description provided for @onlineFilterAll.
  ///
  /// In it, this message translates to:
  /// **'Tutte'**
  String get onlineFilterAll;

  /// No description provided for @onlineFromSource.
  ///
  /// In it, this message translates to:
  /// **'Da {source}'**
  String onlineFromSource(String source);

  /// No description provided for @onlineAlsoVideo.
  ///
  /// In it, this message translates to:
  /// **'anche come video'**
  String get onlineAlsoVideo;

  /// No description provided for @onlineListenVideo.
  ///
  /// In it, this message translates to:
  /// **'Ascolta il video'**
  String get onlineListenVideo;

  /// No description provided for @onlineNoticeRateLimited.
  ///
  /// In it, this message translates to:
  /// **'{source} chiede una pausa: risultati solo da {other}'**
  String onlineNoticeRateLimited(String source, String other);

  /// No description provided for @onlineNoticeFailed.
  ///
  /// In it, this message translates to:
  /// **'{source} non ha risposto: risultati solo da {other}'**
  String onlineNoticeFailed(String source, String other);

  /// No description provided for @radioTitle.
  ///
  /// In it, this message translates to:
  /// **'Radio'**
  String get radioTitle;

  /// No description provided for @radioLibrarySubtitle.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =0{Stazioni in diretta} one{1 stazione salvata} other{{count} stazioni salvate}}'**
  String radioLibrarySubtitle(int count);

  /// No description provided for @radioSearchHint.
  ///
  /// In it, this message translates to:
  /// **'Cerca una radio'**
  String get radioSearchHint;

  /// No description provided for @radioOnlyCountry.
  ///
  /// In it, this message translates to:
  /// **'Solo {country}'**
  String radioOnlyCountry(String country);

  /// No description provided for @radioMine.
  ///
  /// In it, this message translates to:
  /// **'Le mie radio'**
  String get radioMine;

  /// No description provided for @radioNearYou.
  ///
  /// In it, this message translates to:
  /// **'Vicino a te'**
  String get radioNearYou;

  /// No description provided for @radioGenres.
  ///
  /// In it, this message translates to:
  /// **'Generi'**
  String get radioGenres;

  /// No description provided for @radioTopListened.
  ///
  /// In it, this message translates to:
  /// **'Le più ascoltate'**
  String get radioTopListened;

  /// No description provided for @radioChooseRegion.
  ///
  /// In it, this message translates to:
  /// **'Scegli la regione'**
  String get radioChooseRegion;

  /// No description provided for @radioRegionHint.
  ///
  /// In it, this message translates to:
  /// **'Le radio vicine si trovano dal paese e dalla regione che scegli: l\'app non usa la tua posizione.'**
  String get radioRegionHint;

  /// No description provided for @radioCountryChip.
  ///
  /// In it, this message translates to:
  /// **'Paese: {country}'**
  String radioCountryChip(String country);

  /// No description provided for @radioChooseCountry.
  ///
  /// In it, this message translates to:
  /// **'Scegli il paese'**
  String get radioChooseCountry;

  /// No description provided for @radioOfflineList.
  ///
  /// In it, this message translates to:
  /// **'Non in linea, elenco del {date}'**
  String radioOfflineList(String date);

  /// No description provided for @radioLoadFailed.
  ///
  /// In it, this message translates to:
  /// **'Non riesco a caricare le radio'**
  String get radioLoadFailed;

  /// No description provided for @radioNoResults.
  ///
  /// In it, this message translates to:
  /// **'Nessuna radio trovata'**
  String get radioNoResults;

  /// No description provided for @radioResults.
  ///
  /// In it, this message translates to:
  /// **'Risultati'**
  String get radioResults;

  /// No description provided for @radioSave.
  ///
  /// In it, this message translates to:
  /// **'Salva in Le mie radio'**
  String get radioSave;

  /// No description provided for @radioUnsave.
  ///
  /// In it, this message translates to:
  /// **'Togli da Le mie radio'**
  String get radioUnsave;

  /// No description provided for @radioSavedDone.
  ///
  /// In it, this message translates to:
  /// **'Radio salvata'**
  String get radioSavedDone;

  /// No description provided for @radioRemovedDone.
  ///
  /// In it, this message translates to:
  /// **'Radio tolta da Le mie radio'**
  String get radioRemovedDone;

  /// No description provided for @radioNotResponding.
  ///
  /// In it, this message translates to:
  /// **'non risponde'**
  String get radioNotResponding;

  /// No description provided for @radioLive.
  ///
  /// In it, this message translates to:
  /// **'In diretta'**
  String get radioLive;

  /// No description provided for @reasonRadioUnavailable.
  ///
  /// In it, this message translates to:
  /// **'la radio non risponde'**
  String get reasonRadioUnavailable;

  /// No description provided for @radioDataPerHour.
  ///
  /// In it, this message translates to:
  /// **'≈ {mb} MB all\'ora'**
  String radioDataPerHour(String mb);

  /// No description provided for @radioSite.
  ///
  /// In it, this message translates to:
  /// **'Sito della stazione'**
  String get radioSite;

  /// No description provided for @radioSiteCopied.
  ///
  /// In it, this message translates to:
  /// **'Indirizzo del sito copiato'**
  String get radioSiteCopied;

  /// No description provided for @radioSearchSong.
  ///
  /// In it, this message translates to:
  /// **'Cerca questo brano'**
  String get radioSearchSong;

  /// No description provided for @radioRenameTitle.
  ///
  /// In it, this message translates to:
  /// **'Nome della radio'**
  String get radioRenameTitle;

  /// No description provided for @radioMobileNotice.
  ///
  /// In it, this message translates to:
  /// **'La radio usa circa 1 MB al minuto di dati.'**
  String get radioMobileNotice;

  /// No description provided for @radioAddAddress.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi indirizzo'**
  String get radioAddAddress;

  /// No description provided for @radioAddName.
  ///
  /// In it, this message translates to:
  /// **'Nome'**
  String get radioAddName;

  /// No description provided for @radioAddUrl.
  ///
  /// In it, this message translates to:
  /// **'Indirizzo dello stream'**
  String get radioAddUrl;

  /// No description provided for @radioAddTest.
  ///
  /// In it, this message translates to:
  /// **'Prova 10 secondi'**
  String get radioAddTest;

  /// No description provided for @radioAddTesting.
  ///
  /// In it, this message translates to:
  /// **'Provo… se la senti, puoi salvarla.'**
  String get radioAddTesting;

  /// No description provided for @radioLinkEmpty.
  ///
  /// In it, this message translates to:
  /// **'Scrivi l\'indirizzo dello stream'**
  String get radioLinkEmpty;

  /// No description provided for @radioLinkNotAnAddress.
  ///
  /// In it, this message translates to:
  /// **'Non sembra un indirizzo: scrivilo per intero, per esempio https://…'**
  String get radioLinkNotAnAddress;

  /// No description provided for @radioLinkBadScheme.
  ///
  /// In it, this message translates to:
  /// **'L\'indirizzo deve iniziare con http:// o https://'**
  String get radioLinkBadScheme;

  /// No description provided for @radioLinkNoEntries.
  ///
  /// In it, this message translates to:
  /// **'Nel file non c\'è nessun indirizzo da ascoltare'**
  String get radioLinkNoEntries;

  /// No description provided for @radioLinkTooBig.
  ///
  /// In it, this message translates to:
  /// **'Il file è troppo grande per essere una lista di radio'**
  String get radioLinkTooBig;

  /// No description provided for @radioLinkFetchFailed.
  ///
  /// In it, this message translates to:
  /// **'Non riesco a scaricare il file'**
  String get radioLinkFetchFailed;

  /// No description provided for @radioReorder.
  ///
  /// In it, this message translates to:
  /// **'Trascina per riordinare'**
  String get radioReorder;

  /// No description provided for @radioReorderFailed.
  ///
  /// In it, this message translates to:
  /// **'Non riesco a salvare il nuovo ordine'**
  String get radioReorderFailed;

  /// No description provided for @memoryRadio.
  ///
  /// In it, this message translates to:
  /// **'Radio (elenco stazioni)'**
  String get memoryRadio;

  /// No description provided for @radioGenrePop.
  ///
  /// In it, this message translates to:
  /// **'Pop'**
  String get radioGenrePop;

  /// No description provided for @radioGenreRock.
  ///
  /// In it, this message translates to:
  /// **'Rock'**
  String get radioGenreRock;

  /// No description provided for @radioGenreClassicRock.
  ///
  /// In it, this message translates to:
  /// **'Rock classico'**
  String get radioGenreClassicRock;

  /// No description provided for @radioGenreJazz.
  ///
  /// In it, this message translates to:
  /// **'Jazz'**
  String get radioGenreJazz;

  /// No description provided for @radioGenreBlues.
  ///
  /// In it, this message translates to:
  /// **'Blues'**
  String get radioGenreBlues;

  /// No description provided for @radioGenreClassical.
  ///
  /// In it, this message translates to:
  /// **'Classica'**
  String get radioGenreClassical;

  /// No description provided for @radioGenreDance.
  ///
  /// In it, this message translates to:
  /// **'Dance'**
  String get radioGenreDance;

  /// No description provided for @radioGenreElectronic.
  ///
  /// In it, this message translates to:
  /// **'Elettronica'**
  String get radioGenreElectronic;

  /// No description provided for @radioGenreHouse.
  ///
  /// In it, this message translates to:
  /// **'House'**
  String get radioGenreHouse;

  /// No description provided for @radioGenreHipHop.
  ///
  /// In it, this message translates to:
  /// **'Hip hop'**
  String get radioGenreHipHop;

  /// No description provided for @radioGenreLoFi.
  ///
  /// In it, this message translates to:
  /// **'Lo-fi'**
  String get radioGenreLoFi;

  /// No description provided for @radioGenreChillout.
  ///
  /// In it, this message translates to:
  /// **'Chillout'**
  String get radioGenreChillout;

  /// No description provided for @radioGenreSixties.
  ///
  /// In it, this message translates to:
  /// **'Anni 60'**
  String get radioGenreSixties;

  /// No description provided for @radioGenreSeventies.
  ///
  /// In it, this message translates to:
  /// **'Anni 70'**
  String get radioGenreSeventies;

  /// No description provided for @radioGenreEighties.
  ///
  /// In it, this message translates to:
  /// **'Anni 80'**
  String get radioGenreEighties;

  /// No description provided for @radioGenreNineties.
  ///
  /// In it, this message translates to:
  /// **'Anni 90'**
  String get radioGenreNineties;

  /// No description provided for @radioGenreOldies.
  ///
  /// In it, this message translates to:
  /// **'Oldies'**
  String get radioGenreOldies;

  /// No description provided for @radioGenreMetal.
  ///
  /// In it, this message translates to:
  /// **'Metal'**
  String get radioGenreMetal;

  /// No description provided for @radioGenreReggae.
  ///
  /// In it, this message translates to:
  /// **'Reggae'**
  String get radioGenreReggae;

  /// No description provided for @radioGenreLatin.
  ///
  /// In it, this message translates to:
  /// **'Latina'**
  String get radioGenreLatin;

  /// No description provided for @radioGenreSoul.
  ///
  /// In it, this message translates to:
  /// **'Soul'**
  String get radioGenreSoul;

  /// No description provided for @radioGenreNews.
  ///
  /// In it, this message translates to:
  /// **'Notizie'**
  String get radioGenreNews;

  /// No description provided for @radioGenreTalk.
  ///
  /// In it, this message translates to:
  /// **'Parlato'**
  String get radioGenreTalk;

  /// No description provided for @radioGenreSports.
  ///
  /// In it, this message translates to:
  /// **'Sport'**
  String get radioGenreSports;

  /// No description provided for @newReleasesTitle.
  ///
  /// In it, this message translates to:
  /// **'Nuove uscite'**
  String get newReleasesTitle;

  /// No description provided for @releasesTopArtists.
  ///
  /// In it, this message translates to:
  /// **'Segui in automatico i più ascoltati'**
  String get releasesTopArtists;

  /// No description provided for @releasesTopArtistsHint.
  ///
  /// In it, this message translates to:
  /// **'I 15 artisti più ascoltati negli ultimi 90 giorni, cercati su YouTube Music.'**
  String get releasesTopArtistsHint;

  /// No description provided for @releasesNotify.
  ///
  /// In it, this message translates to:
  /// **'Notifiche delle nuove uscite'**
  String get releasesNotify;

  /// No description provided for @releasesNotifyHint.
  ///
  /// In it, this message translates to:
  /// **'Una al giorno al massimo, solo su Android.'**
  String get releasesNotifyHint;

  /// No description provided for @releasesUnmetered.
  ///
  /// In it, this message translates to:
  /// **'Controlla solo su Wi‑Fi'**
  String get releasesUnmetered;

  /// No description provided for @releasesUnmeteredHint.
  ///
  /// In it, this message translates to:
  /// **'Un controllo al giorno pesa circa 0,5 MB.'**
  String get releasesUnmeteredHint;

  /// No description provided for @releasesTopCardTitle.
  ///
  /// In it, this message translates to:
  /// **'Vuoi sapere quando escono brani nuovi dei tuoi artisti più ascoltati?'**
  String get releasesTopCardTitle;

  /// No description provided for @releasesTopCardYes.
  ///
  /// In it, this message translates to:
  /// **'Attiva'**
  String get releasesTopCardYes;

  /// No description provided for @releasesTopCardNo.
  ///
  /// In it, this message translates to:
  /// **'No, grazie'**
  String get releasesTopCardNo;

  /// No description provided for @releasesCheckNow.
  ///
  /// In it, this message translates to:
  /// **'Controlla ora'**
  String get releasesCheckNow;

  /// No description provided for @releasesLastCheck.
  ///
  /// In it, this message translates to:
  /// **'Ultimo controllo: {when}'**
  String releasesLastCheck(String when);

  /// No description provided for @releasesNeverChecked.
  ///
  /// In it, this message translates to:
  /// **'Mai controllato'**
  String get releasesNeverChecked;

  /// No description provided for @releasesPaused.
  ///
  /// In it, this message translates to:
  /// **'YouTube chiede una pausa: riprovo alle {time}'**
  String releasesPaused(String time);

  /// No description provided for @releasesChecking.
  ///
  /// In it, this message translates to:
  /// **'Controllo in corso…'**
  String get releasesChecking;

  /// No description provided for @releasesCheckNone.
  ///
  /// In it, this message translates to:
  /// **'Nessuna nuova uscita'**
  String get releasesCheckNone;

  /// No description provided for @releasesCheckFound.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 nuova uscita} other{{count} nuove uscite}}'**
  String releasesCheckFound(int count);

  /// No description provided for @releasesCantCheck.
  ///
  /// In it, this message translates to:
  /// **'Non posso controllare ora: manca la rete o non segui nessun artista.'**
  String get releasesCantCheck;

  /// No description provided for @releasesChanged.
  ///
  /// In it, this message translates to:
  /// **'YouTube Music ha cambiato formato: riprovo al prossimo giro.'**
  String get releasesChanged;

  /// No description provided for @releasesEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessuna nuova uscita negli ultimi 90 giorni. Apri la pagina di un artista e tocca «Segui».'**
  String get releasesEmpty;

  /// No description provided for @releasesAllArtists.
  ///
  /// In it, this message translates to:
  /// **'Tutti'**
  String get releasesAllArtists;

  /// No description provided for @releasesFollowedTitle.
  ///
  /// In it, this message translates to:
  /// **'Artisti seguiti ({count})'**
  String releasesFollowedTitle(int count);

  /// No description provided for @releasesFollowedLibrary.
  ///
  /// In it, this message translates to:
  /// **'Artisti seguiti'**
  String get releasesFollowedLibrary;

  /// No description provided for @releasesFollowedCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 artista} other{{count} artisti}}'**
  String releasesFollowedCount(int count);

  /// No description provided for @followedEmpty.
  ///
  /// In it, this message translates to:
  /// **'Non segui ancora nessun artista. Apri la pagina di un artista e tocca «Segui».'**
  String get followedEmpty;

  /// No description provided for @followAction.
  ///
  /// In it, this message translates to:
  /// **'Segui'**
  String get followAction;

  /// No description provided for @followingAction.
  ///
  /// In it, this message translates to:
  /// **'Segui già'**
  String get followingAction;

  /// No description provided for @followStopTitle.
  ///
  /// In it, this message translates to:
  /// **'Smettere di seguire {name}?'**
  String followStopTitle(String name);

  /// No description provided for @followStopBody.
  ///
  /// In it, this message translates to:
  /// **'Non riceverai più le sue nuove uscite.'**
  String get followStopBody;

  /// No description provided for @followOnYtm.
  ///
  /// In it, this message translates to:
  /// **'Segui su YouTube Music'**
  String get followOnYtm;

  /// No description provided for @followStop.
  ///
  /// In it, this message translates to:
  /// **'Non seguire più'**
  String get followStop;

  /// No description provided for @followedNow.
  ///
  /// In it, this message translates to:
  /// **'Ora segui {name}'**
  String followedNow(String name);

  /// No description provided for @followMute.
  ///
  /// In it, this message translates to:
  /// **'Silenzia notifiche'**
  String get followMute;

  /// No description provided for @followUnmute.
  ///
  /// In it, this message translates to:
  /// **'Riattiva notifiche'**
  String get followUnmute;

  /// No description provided for @followedTopListened.
  ///
  /// In it, this message translates to:
  /// **'Più ascoltato'**
  String get followedTopListened;

  /// No description provided for @followedToConfirm.
  ///
  /// In it, this message translates to:
  /// **'Da confermare'**
  String get followedToConfirm;

  /// No description provided for @followedNotFound.
  ///
  /// In it, this message translates to:
  /// **'Non trovato'**
  String get followedNotFound;

  /// No description provided for @followedRetry.
  ///
  /// In it, this message translates to:
  /// **'Riprova'**
  String get followedRetry;

  /// No description provided for @releaseAlbumYear.
  ///
  /// In it, this message translates to:
  /// **'Album, {year}'**
  String releaseAlbumYear(String year);

  /// No description provided for @releaseSingleYear.
  ///
  /// In it, this message translates to:
  /// **'Singolo, {year}'**
  String releaseSingleYear(String year);

  /// No description provided for @releaseAlbumPlain.
  ///
  /// In it, this message translates to:
  /// **'Album'**
  String get releaseAlbumPlain;

  /// No description provided for @releaseSinglePlain.
  ///
  /// In it, this message translates to:
  /// **'Singolo'**
  String get releaseSinglePlain;

  /// No description provided for @releaseVariants.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{e un’altra versione} other{e altre {count} versioni}}'**
  String releaseVariants(int count);

  /// No description provided for @releaseNewBadge.
  ///
  /// In it, this message translates to:
  /// **'Nuovo'**
  String get releaseNewBadge;

  /// No description provided for @activityReleases.
  ///
  /// In it, this message translates to:
  /// **'Controllo nuove uscite'**
  String get activityReleases;

  /// No description provided for @releaseNotifyOne.
  ///
  /// In it, this message translates to:
  /// **'Nuova uscita: {title} di {artist}'**
  String releaseNotifyOne(String title, String artist);

  /// No description provided for @releaseNotifyMany1.
  ///
  /// In it, this message translates to:
  /// **'{count} nuove uscite: {a}'**
  String releaseNotifyMany1(int count, String a);

  /// No description provided for @releaseNotifyMany2.
  ///
  /// In it, this message translates to:
  /// **'{count} nuove uscite: {a} e {b}'**
  String releaseNotifyMany2(int count, String a, String b);

  /// No description provided for @releaseNotifyManyMore.
  ///
  /// In it, this message translates to:
  /// **'{count} nuove uscite: {a}, {b} e altri {others}'**
  String releaseNotifyManyMore(int count, String a, String b, int others);

  /// No description provided for @releaseNotifyShow.
  ///
  /// In it, this message translates to:
  /// **'Mostra'**
  String get releaseNotifyShow;

  /// No description provided for @reportIssue.
  ///
  /// In it, this message translates to:
  /// **'Segnala un problema'**
  String get reportIssue;

  /// No description provided for @reportIssueHint.
  ///
  /// In it, this message translates to:
  /// **'Apre GitHub con il testo già pronto'**
  String get reportIssueHint;

  /// No description provided for @reportKindBug.
  ///
  /// In it, this message translates to:
  /// **'Difetto'**
  String get reportKindBug;

  /// No description provided for @reportKindIdea.
  ///
  /// In it, this message translates to:
  /// **'Idea'**
  String get reportKindIdea;

  /// No description provided for @reportTitleLabel.
  ///
  /// In it, this message translates to:
  /// **'Titolo'**
  String get reportTitleLabel;

  /// No description provided for @reportDescLabel.
  ///
  /// In it, this message translates to:
  /// **'Descrizione'**
  String get reportDescLabel;

  /// No description provided for @reportDescHelper.
  ///
  /// In it, this message translates to:
  /// **'Cosa è successo e come riprodurlo (almeno {n} caratteri)'**
  String reportDescHelper(int n);

  /// No description provided for @reportAttach.
  ///
  /// In it, this message translates to:
  /// **'Allega informazioni tecniche'**
  String get reportAttach;

  /// No description provided for @reportAttachPreview.
  ///
  /// In it, this message translates to:
  /// **'Verrà inviato esattamente questo:'**
  String get reportAttachPreview;

  /// No description provided for @reportOpen.
  ///
  /// In it, this message translates to:
  /// **'Apri su GitHub'**
  String get reportOpen;

  /// No description provided for @reportCopy.
  ///
  /// In it, this message translates to:
  /// **'Copia testo'**
  String get reportCopy;

  /// No description provided for @reportCopied.
  ///
  /// In it, this message translates to:
  /// **'Testo copiato'**
  String get reportCopied;

  /// No description provided for @reportGithubNote.
  ///
  /// In it, this message translates to:
  /// **'Serve un account GitHub; senza, copia il testo e mandalo come preferisci.'**
  String get reportGithubNote;

  /// No description provided for @reportOpenFailed.
  ///
  /// In it, this message translates to:
  /// **'Impossibile aprire il browser: il testo è stato copiato'**
  String get reportOpenFailed;

  /// No description provided for @reportLogShortened.
  ///
  /// In it, this message translates to:
  /// **'Il log verrà accorciato per stare nell\'indirizzo'**
  String get reportLogShortened;

  /// No description provided for @reportNoLog.
  ///
  /// In it, this message translates to:
  /// **'Nessun avviso o errore recente nel log'**
  String get reportNoLog;

  /// No description provided for @reportUnknown.
  ///
  /// In it, this message translates to:
  /// **'Sconosciuto'**
  String get reportUnknown;

  /// No description provided for @iconAskTitle.
  ///
  /// In it, this message translates to:
  /// **'Cambiare anche l\'icona dell\'app?'**
  String get iconAskTitle;

  /// No description provided for @iconProblems.
  ///
  /// In it, this message translates to:
  /// **'L\'icona cambia quando esci dall\'app. Possibili problemi:\n• il launcher può metterci qualche secondo ad aggiornarla, o mostrare per un attimo due icone o nessuna;\n• su alcuni launcher l\'icona sulla schermata Home viene tolta o spostata e va rimessa a mano (i widget restano);\n• le scorciatoie sulla Home create con la vecchia icona possono smettere di funzionare;\n• l\'app può sparire per un attimo dalle app recenti;\n• raramente Android chiude l\'app e la musica si ferma.\nSul computer l\'icona non cambia.'**
  String get iconProblems;

  /// No description provided for @iconChange.
  ///
  /// In it, this message translates to:
  /// **'Cambia l\'icona'**
  String get iconChange;

  /// No description provided for @iconKeep.
  ///
  /// In it, this message translates to:
  /// **'Lascia com\'è'**
  String get iconKeep;

  /// No description provided for @iconDontAsk.
  ///
  /// In it, this message translates to:
  /// **'Non chiederlo più'**
  String get iconDontAsk;

  /// No description provided for @iconFollowTitle.
  ///
  /// In it, this message translates to:
  /// **'Icona a tema'**
  String get iconFollowTitle;

  /// No description provided for @iconFollowSubtitle.
  ///
  /// In it, this message translates to:
  /// **'L\'icona segue tema e colore quando esci dall\'app'**
  String get iconFollowSubtitle;

  /// No description provided for @exportifySyncTitle.
  ///
  /// In it, this message translates to:
  /// **'Sincronizza da Spotify'**
  String get exportifySyncTitle;

  /// No description provided for @exportifySyncChanges.
  ///
  /// In it, this message translates to:
  /// **'+{added} nuovi, −{removed} rimossi'**
  String exportifySyncChanges(int added, int removed);

  /// No description provided for @exportifySyncNew.
  ///
  /// In it, this message translates to:
  /// **'Nuova playlist'**
  String get exportifySyncNew;

  /// No description provided for @exportifySyncChoose.
  ///
  /// In it, this message translates to:
  /// **'Da scegliere'**
  String get exportifySyncChoose;

  /// No description provided for @exportifySyncNoChanges.
  ///
  /// In it, this message translates to:
  /// **'Senza cambiamenti'**
  String get exportifySyncNoChanges;

  /// No description provided for @exportifySyncSkipped.
  ///
  /// In it, this message translates to:
  /// **'{n} file saltati (non sono playlist leggibili)'**
  String exportifySyncSkipped(int n);

  /// No description provided for @exportifySyncGo.
  ///
  /// In it, this message translates to:
  /// **'Sincronizza {n}'**
  String exportifySyncGo(int n);

  /// No description provided for @exportifySyncDone.
  ///
  /// In it, this message translates to:
  /// **'{n} playlist in sincronizzazione: le segui nel Centro Attività'**
  String exportifySyncDone(int n);

  /// No description provided for @exportifySyncEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessuna playlist nello ZIP'**
  String get exportifySyncEmpty;

  /// No description provided for @exportifySyncPickTitle.
  ///
  /// In it, this message translates to:
  /// **'Scegli la playlist'**
  String get exportifySyncPickTitle;

  /// No description provided for @csvImportOpenExportify.
  ///
  /// In it, this message translates to:
  /// **'Apri exportify.net'**
  String get csvImportOpenExportify;

  /// No description provided for @csvImportOpenFailed.
  ///
  /// In it, this message translates to:
  /// **'Non riesco ad aprire il browser'**
  String get csvImportOpenFailed;

  /// No description provided for @csvImportZipHint.
  ///
  /// In it, this message translates to:
  /// **'Con «Export All» ottieni uno ZIP con tutte le playlist: scegli quello e le sincronizzi insieme.'**
  String get csvImportZipHint;

  /// No description provided for @exportifySyncFailed.
  ///
  /// In it, this message translates to:
  /// **'Sincronizzazione non riuscita'**
  String get exportifySyncFailed;

  /// No description provided for @exportifySyncEntryFailed.
  ///
  /// In it, this message translates to:
  /// **'Non riesco a leggere questa playlist'**
  String get exportifySyncEntryFailed;

  /// No description provided for @exportifySyncLoadFailed.
  ///
  /// In it, this message translates to:
  /// **'Non riesco a leggere le playlist dello ZIP'**
  String get exportifySyncLoadFailed;

  /// No description provided for @exportifyRemindTitle.
  ///
  /// In it, this message translates to:
  /// **'Ricordami di sincronizzare con Spotify'**
  String get exportifyRemindTitle;

  /// No description provided for @exportifyRemindOff.
  ///
  /// In it, this message translates to:
  /// **'Spento'**
  String get exportifyRemindOff;

  /// No description provided for @exportifyRemindDays.
  ///
  /// In it, this message translates to:
  /// **'{days} giorni'**
  String exportifyRemindDays(int days);

  /// No description provided for @exportifyCardTitle.
  ///
  /// In it, this message translates to:
  /// **'È ora di sincronizzare le playlist con Spotify'**
  String get exportifyCardTitle;

  /// No description provided for @exportifyCardOpen.
  ///
  /// In it, this message translates to:
  /// **'Apri Exportify'**
  String get exportifyCardOpen;

  /// No description provided for @exportifyCardLater.
  ///
  /// In it, this message translates to:
  /// **'Più tardi'**
  String get exportifyCardLater;

  /// No description provided for @exportifyFoundTitle.
  ///
  /// In it, this message translates to:
  /// **'Trovata l’esportazione di Exportify'**
  String get exportifyFoundTitle;

  /// No description provided for @exportifyFoundSync.
  ///
  /// In it, this message translates to:
  /// **'Sincronizza'**
  String get exportifyFoundSync;

  /// No description provided for @onboardingSpotifyTitle.
  ///
  /// In it, this message translates to:
  /// **'Playlist da Spotify'**
  String get onboardingSpotifyTitle;

  /// No description provided for @onboardingSpotifyBody.
  ///
  /// In it, this message translates to:
  /// **'Su exportify.net scarichi le tue playlist di Spotify in un file. FreeKmusic lo prende e le aggiorna qui.\nNon serve collegare nessun account: il file lo scarichi tu.'**
  String get onboardingSpotifyBody;

  /// No description provided for @deezerMeta.
  ///
  /// In it, this message translates to:
  /// **'Metadati da Deezer'**
  String get deezerMeta;

  /// No description provided for @deezerMetaHint.
  ///
  /// In it, this message translates to:
  /// **'Solo dati (copertine, numeri di traccia), mai musica'**
  String get deezerMetaHint;

  /// No description provided for @deezerMetaNote.
  ///
  /// In it, this message translates to:
  /// **'Uso privato e non commerciale. Le condizioni di Deezer vietano di promuovere lo scaricamento non autorizzato, e FreeKmusic scarica da YouTube: è un rischio tuo.'**
  String get deezerMetaNote;

  /// No description provided for @acoustId.
  ///
  /// In it, this message translates to:
  /// **'Riconosci dal suono (AcoustID)'**
  String get acoustId;

  /// No description provided for @acoustIdHint.
  ///
  /// In it, this message translates to:
  /// **'Parte solo l\'impronta del brano, mai l\'audio'**
  String get acoustIdHint;

  /// No description provided for @settingsSpinCover.
  ///
  /// In it, this message translates to:
  /// **'Copertina che ruota'**
  String get settingsSpinCover;

  /// No description provided for @settingsSpinCoverHint.
  ///
  /// In it, this message translates to:
  /// **'Nel player, quando la musica suona'**
  String get settingsSpinCoverHint;

  /// No description provided for @themeLowContrastWarning.
  ///
  /// In it, this message translates to:
  /// **'Alcuni colori del testo si leggono male sullo sfondo (sotto 4,5:1). Il tema resta com\'è.'**
  String get themeLowContrastWarning;

  /// No description provided for @streamCacheTitle.
  ///
  /// In it, this message translates to:
  /// **'Spazio per lo streaming'**
  String get streamCacheTitle;

  /// No description provided for @streamCacheUsage.
  ///
  /// In it, this message translates to:
  /// **'{used} su {limit}'**
  String streamCacheUsage(String used, String limit);

  /// No description provided for @streamCacheClear.
  ///
  /// In it, this message translates to:
  /// **'Svuota'**
  String get streamCacheClear;

  /// No description provided for @streamCacheCleared.
  ///
  /// In it, this message translates to:
  /// **'Cache dello streaming svuotata'**
  String get streamCacheCleared;

  /// No description provided for @streamCacheClearFailed.
  ///
  /// In it, this message translates to:
  /// **'Impossibile svuotare la cache dello streaming'**
  String get streamCacheClearFailed;

  /// No description provided for @playerLoading.
  ///
  /// In it, this message translates to:
  /// **'Caricamento…'**
  String get playerLoading;

  /// No description provided for @ytmAlbumQueue.
  ///
  /// In it, this message translates to:
  /// **'Metti in coda l’album'**
  String get ytmAlbumQueue;

  /// No description provided for @addedToLibrary.
  ///
  /// In it, this message translates to:
  /// **'Aggiunto alla libreria'**
  String get addedToLibrary;

  /// No description provided for @promoteNoSpace.
  ///
  /// In it, this message translates to:
  /// **'Spazio insufficiente per scaricare il brano'**
  String get promoteNoSpace;

  /// No description provided for @promoteFailed.
  ///
  /// In it, this message translates to:
  /// **'Impossibile spostare il brano'**
  String get promoteFailed;

  /// No description provided for @creditsDetails.
  ///
  /// In it, this message translates to:
  /// **'Crediti e dettagli'**
  String get creditsDetails;

  /// No description provided for @creditsDetailsHint.
  ///
  /// In it, this message translates to:
  /// **'Autori, produttori e dettagli dei brani'**
  String get creditsDetailsHint;

  /// No description provided for @creditsDetailsNote.
  ///
  /// In it, this message translates to:
  /// **'Usa anche un\'API non ufficiale di Deezer'**
  String get creditsDetailsNote;

  /// No description provided for @creditRoleVocals.
  ///
  /// In it, this message translates to:
  /// **'Voce'**
  String get creditRoleVocals;

  /// No description provided for @creditRoleBackingVocals.
  ///
  /// In it, this message translates to:
  /// **'Cori'**
  String get creditRoleBackingVocals;

  /// No description provided for @creditRoleGuitar.
  ///
  /// In it, this message translates to:
  /// **'Chitarra'**
  String get creditRoleGuitar;

  /// No description provided for @creditRoleBassGuitar.
  ///
  /// In it, this message translates to:
  /// **'Basso'**
  String get creditRoleBassGuitar;

  /// No description provided for @creditRoleDrums.
  ///
  /// In it, this message translates to:
  /// **'Batteria'**
  String get creditRoleDrums;

  /// No description provided for @creditRoleKeyboard.
  ///
  /// In it, this message translates to:
  /// **'Tastiere'**
  String get creditRoleKeyboard;

  /// No description provided for @creditRolePiano.
  ///
  /// In it, this message translates to:
  /// **'Piano'**
  String get creditRolePiano;

  /// No description provided for @creditRoleSynthesizer.
  ///
  /// In it, this message translates to:
  /// **'Sintetizzatore'**
  String get creditRoleSynthesizer;

  /// No description provided for @creditRoleComposer.
  ///
  /// In it, this message translates to:
  /// **'Compositore'**
  String get creditRoleComposer;

  /// No description provided for @creditRoleAuthor.
  ///
  /// In it, this message translates to:
  /// **'Autore'**
  String get creditRoleAuthor;

  /// No description provided for @creditRoleLyricist.
  ///
  /// In it, this message translates to:
  /// **'Paroliere'**
  String get creditRoleLyricist;

  /// No description provided for @creditRoleArranger.
  ///
  /// In it, this message translates to:
  /// **'Arrangiatore'**
  String get creditRoleArranger;

  /// No description provided for @creditRoleProducer.
  ///
  /// In it, this message translates to:
  /// **'Produttore'**
  String get creditRoleProducer;

  /// No description provided for @creditRoleAdditionalProducer.
  ///
  /// In it, this message translates to:
  /// **'Produttore aggiuntivo'**
  String get creditRoleAdditionalProducer;

  /// No description provided for @creditRoleMix.
  ///
  /// In it, this message translates to:
  /// **'Mixaggio'**
  String get creditRoleMix;

  /// No description provided for @creditRoleMastering.
  ///
  /// In it, this message translates to:
  /// **'Mastering'**
  String get creditRoleMastering;

  /// No description provided for @creditRoleRecording.
  ///
  /// In it, this message translates to:
  /// **'Registrazione'**
  String get creditRoleRecording;

  /// No description provided for @creditRoleEngineer.
  ///
  /// In it, this message translates to:
  /// **'Tecnico del suono'**
  String get creditRoleEngineer;

  /// No description provided for @creditRoleProgramming.
  ///
  /// In it, this message translates to:
  /// **'Programmazione'**
  String get creditRoleProgramming;

  /// No description provided for @creditRoleDrumProgrammer.
  ///
  /// In it, this message translates to:
  /// **'Programmazione batteria'**
  String get creditRoleDrumProgrammer;

  /// No description provided for @creditRoleMusicPublisher.
  ///
  /// In it, this message translates to:
  /// **'Editore musicale'**
  String get creditRoleMusicPublisher;

  /// No description provided for @creditsGroupPerformers.
  ///
  /// In it, this message translates to:
  /// **'Interpreti e strumenti'**
  String get creditsGroupPerformers;

  /// No description provided for @creditsGroupWriters.
  ///
  /// In it, this message translates to:
  /// **'Autori'**
  String get creditsGroupWriters;

  /// No description provided for @creditsGroupProduction.
  ///
  /// In it, this message translates to:
  /// **'Produzione e tecnici'**
  String get creditsGroupProduction;

  /// No description provided for @creditsGroupOther.
  ///
  /// In it, this message translates to:
  /// **'Altro'**
  String get creditsGroupOther;

  /// No description provided for @creditsTitle.
  ///
  /// In it, this message translates to:
  /// **'Crediti e dettagli'**
  String get creditsTitle;

  /// No description provided for @creditsShowAll.
  ///
  /// In it, this message translates to:
  /// **'Mostra tutto'**
  String get creditsShowAll;

  /// No description provided for @creditsRefresh.
  ///
  /// In it, this message translates to:
  /// **'Aggiorna'**
  String get creditsRefresh;

  /// No description provided for @creditsAppearsAs.
  ///
  /// In it, this message translates to:
  /// **'Compare come'**
  String get creditsAppearsAs;

  /// No description provided for @creditsInCredits.
  ///
  /// In it, this message translates to:
  /// **'Nei crediti'**
  String get creditsInCredits;

  /// No description provided for @creditsRefreshFailed.
  ///
  /// In it, this message translates to:
  /// **'Impossibile aggiornare i crediti'**
  String get creditsRefreshFailed;

  /// No description provided for @creditsBpm.
  ///
  /// In it, this message translates to:
  /// **'BPM'**
  String get creditsBpm;

  /// No description provided for @creditsLabel.
  ///
  /// In it, this message translates to:
  /// **'Etichetta'**
  String get creditsLabel;

  /// No description provided for @creditsDigitalRelease.
  ///
  /// In it, this message translates to:
  /// **'Uscita digitale'**
  String get creditsDigitalRelease;

  /// No description provided for @creditsPhysicalRelease.
  ///
  /// In it, this message translates to:
  /// **'Uscita fisica'**
  String get creditsPhysicalRelease;

  /// No description provided for @creditsKindSingle.
  ///
  /// In it, this message translates to:
  /// **'Singolo'**
  String get creditsKindSingle;

  /// No description provided for @creditsKindEp.
  ///
  /// In it, this message translates to:
  /// **'EP'**
  String get creditsKindEp;

  /// No description provided for @creditsRank.
  ///
  /// In it, this message translates to:
  /// **'Classifica'**
  String get creditsRank;

  /// No description provided for @creditsAlbumFans.
  ///
  /// In it, this message translates to:
  /// **'Fan dell’album'**
  String get creditsAlbumFans;

  /// No description provided for @creditsExplicit.
  ///
  /// In it, this message translates to:
  /// **'Esplicito'**
  String get creditsExplicit;

  /// No description provided for @creditsOpenArtist.
  ///
  /// In it, this message translates to:
  /// **'Apri {name}'**
  String creditsOpenArtist(String name);

  /// No description provided for @autoCuriosities.
  ///
  /// In it, this message translates to:
  /// **'Curiosità automatiche'**
  String get autoCuriosities;

  /// No description provided for @autoCuriositiesHint.
  ///
  /// In it, this message translates to:
  /// **'Cerca le curiosità su Wikipedia per i brani nuovi'**
  String get autoCuriositiesHint;

  /// No description provided for @memoryEnrichment.
  ///
  /// In it, this message translates to:
  /// **'Arricchimento: {size}'**
  String memoryEnrichment(String size);

  /// No description provided for @memoryEnrichmentDetail.
  ///
  /// In it, this message translates to:
  /// **'Testi {lyrics}, curiosità {curiosities}, crediti {credits}'**
  String memoryEnrichmentDetail(
    String lyrics,
    String curiosities,
    String credits,
  );

  /// No description provided for @activityPodcastRefresh.
  ///
  /// In it, this message translates to:
  /// **'Aggiornamento dei podcast'**
  String get activityPodcastRefresh;

  /// No description provided for @activityRadio.
  ///
  /// In it, this message translates to:
  /// **'Controllo delle radio salvate'**
  String get activityRadio;

  /// No description provided for @activityEnrichBackground.
  ///
  /// In it, this message translates to:
  /// **'Completamento dell\'arricchimento: {done} di {total}'**
  String activityEnrichBackground(int done, int total);

  /// No description provided for @enrichRoundTitle.
  ///
  /// In it, this message translates to:
  /// **'Giro di arricchimento'**
  String get enrichRoundTitle;

  /// No description provided for @enrichRoundUpdated.
  ///
  /// In it, this message translates to:
  /// **'Aggiornati'**
  String get enrichRoundUpdated;

  /// No description provided for @enrichRoundNone.
  ///
  /// In it, this message translates to:
  /// **'Senza risultato'**
  String get enrichRoundNone;

  /// No description provided for @enrichRoundGone.
  ///
  /// In it, this message translates to:
  /// **'Nessun brano da mostrare'**
  String get enrichRoundGone;

  /// No description provided for @enrichPartMeta.
  ///
  /// In it, this message translates to:
  /// **'Dati del brano'**
  String get enrichPartMeta;

  /// No description provided for @enrichPartLyrics.
  ///
  /// In it, this message translates to:
  /// **'Testo'**
  String get enrichPartLyrics;

  /// No description provided for @enrichPartSynced.
  ///
  /// In it, this message translates to:
  /// **'Testo sincronizzato'**
  String get enrichPartSynced;

  /// No description provided for @enrichPartCurio.
  ///
  /// In it, this message translates to:
  /// **'Curiosità'**
  String get enrichPartCurio;

  /// No description provided for @enrichPartCredits.
  ///
  /// In it, this message translates to:
  /// **'Crediti'**
  String get enrichPartCredits;

  /// No description provided for @coverChange.
  ///
  /// In it, this message translates to:
  /// **'Cambia copertina'**
  String get coverChange;

  /// No description provided for @coverRestoreOriginal.
  ///
  /// In it, this message translates to:
  /// **'Ripristina copertina originale'**
  String get coverRestoreOriginal;

  /// No description provided for @artistImageRestore.
  ///
  /// In it, this message translates to:
  /// **'Ripristina immagine automatica'**
  String get artistImageRestore;

  /// No description provided for @coverSourceDevice.
  ///
  /// In it, this message translates to:
  /// **'Dal dispositivo'**
  String get coverSourceDevice;

  /// No description provided for @coverSourceLibrary.
  ///
  /// In it, this message translates to:
  /// **'Dalla libreria'**
  String get coverSourceLibrary;

  /// No description provided for @coverSourceOnline.
  ///
  /// In it, this message translates to:
  /// **'Online'**
  String get coverSourceOnline;

  /// No description provided for @coverSizePx.
  ///
  /// In it, this message translates to:
  /// **'{w} × {h}'**
  String coverSizePx(int w, int h);

  /// No description provided for @speakerPermTitle.
  ///
  /// In it, this message translates to:
  /// **'Permesso Bluetooth'**
  String get speakerPermTitle;

  /// No description provided for @speakerPermBody.
  ///
  /// In it, this message translates to:
  /// **'Per riconoscere la tua cassa, FreeKmusic deve vedere quali dispositivi Bluetooth sono collegati. Non legge altro.'**
  String get speakerPermBody;

  /// No description provided for @speakerPermAllow.
  ///
  /// In it, this message translates to:
  /// **'Consenti'**
  String get speakerPermAllow;

  /// No description provided for @speakerNotNow.
  ///
  /// In it, this message translates to:
  /// **'Non ora'**
  String get speakerNotNow;

  /// No description provided for @speakerAskTitle.
  ///
  /// In it, this message translates to:
  /// **'{name} è una cassa?'**
  String speakerAskTitle(String name);

  /// No description provided for @speakerAskBody.
  ///
  /// In it, this message translates to:
  /// **'Se lo è, quando si collega FreeKmusic apre da solo una Jam a cui gli altri possono unirsi.'**
  String get speakerAskBody;

  /// No description provided for @speakerYes.
  ///
  /// In it, this message translates to:
  /// **'Sì'**
  String get speakerYes;

  /// No description provided for @speakerNo.
  ///
  /// In it, this message translates to:
  /// **'No'**
  String get speakerNo;

  /// No description provided for @speakerJamSection.
  ///
  /// In it, this message translates to:
  /// **'Jam sulla cassa'**
  String get speakerJamSection;

  /// No description provided for @speakerJamHint.
  ///
  /// In it, this message translates to:
  /// **'Quando si collega una cassa Bluetooth, apre da solo una Jam a cui gli altri possono unirsi.'**
  String get speakerJamHint;

  /// No description provided for @speakerNoDevices.
  ///
  /// In it, this message translates to:
  /// **'Nessun dispositivo segnato finora'**
  String get speakerNoDevices;

  /// No description provided for @speakerIsSpeaker.
  ///
  /// In it, this message translates to:
  /// **'Cassa'**
  String get speakerIsSpeaker;

  /// No description provided for @speakerNotSpeaker.
  ///
  /// In it, this message translates to:
  /// **'Non è una cassa'**
  String get speakerNotSpeaker;

  /// No description provided for @speakerPermDenied.
  ///
  /// In it, this message translates to:
  /// **'Permesso Bluetooth negato'**
  String get speakerPermDenied;

  /// No description provided for @speakerPermRetry.
  ///
  /// In it, this message translates to:
  /// **'Tocca per chiederlo di nuovo'**
  String get speakerPermRetry;

  /// No description provided for @speakerChange.
  ///
  /// In it, this message translates to:
  /// **'Cambia {name}'**
  String speakerChange(String name);

  /// No description provided for @jamInviteBanner.
  ///
  /// In it, this message translates to:
  /// **'Unisciti alla Jam di {name}'**
  String jamInviteBanner(String name);

  /// No description provided for @jamInviteDismiss.
  ///
  /// In it, this message translates to:
  /// **'Nascondi'**
  String get jamInviteDismiss;

  /// No description provided for @speakerAwayNotice.
  ///
  /// In it, this message translates to:
  /// **'Collega una cassa'**
  String get speakerAwayNotice;

  /// No description provided for @jamFull.
  ///
  /// In it, this message translates to:
  /// **'La Jam è piena'**
  String get jamFull;

  /// No description provided for @jamAddFailed.
  ///
  /// In it, this message translates to:
  /// **'Non aggiunto alla Jam'**
  String get jamAddFailed;

  /// No description provided for @jamNotFoundOnline.
  ///
  /// In it, this message translates to:
  /// **'Non trovato online, non si può aggiungere'**
  String get jamNotFoundOnline;

  /// No description provided for @jamLeft.
  ///
  /// In it, this message translates to:
  /// **'Sei uscito dalla Jam'**
  String get jamLeft;

  /// No description provided for @speakerContinueOnPhone.
  ///
  /// In it, this message translates to:
  /// **'Continua sul telefono'**
  String get speakerContinueOnPhone;

  /// No description provided for @speakerContinueOnPhoneLabel.
  ///
  /// In it, this message translates to:
  /// **'Continua sul telefono: la Jam suona dall’altoparlante di questo telefono, senza la cassa'**
  String get speakerContinueOnPhoneLabel;

  /// No description provided for @speakerOfferTitle.
  ///
  /// In it, this message translates to:
  /// **'Suonare la Jam sulla tua cassa?'**
  String get speakerOfferTitle;

  /// No description provided for @speakerOfferBody.
  ///
  /// In it, this message translates to:
  /// **'La tua cassa è collegata e la Jam è ferma. Se vuoi, la musica riparte da qui.'**
  String get speakerOfferBody;

  /// No description provided for @jamRemoteTitle.
  ///
  /// In it, this message translates to:
  /// **'Jam a distanza'**
  String get jamRemoteTitle;

  /// No description provided for @jamRemoteHint.
  ///
  /// In it, this message translates to:
  /// **'I broker (server) per la Jam a distanza, in ordine di preferenza.'**
  String get jamRemoteHint;

  /// No description provided for @jamBrokerAdd.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi broker'**
  String get jamBrokerAdd;

  /// No description provided for @jamBrokerHost.
  ///
  /// In it, this message translates to:
  /// **'Indirizzo'**
  String get jamBrokerHost;

  /// No description provided for @jamBrokerPort.
  ///
  /// In it, this message translates to:
  /// **'Porta'**
  String get jamBrokerPort;

  /// No description provided for @jamBrokerTls.
  ///
  /// In it, this message translates to:
  /// **'Connessione cifrata (TLS)'**
  String get jamBrokerTls;

  /// No description provided for @jamBrokerNoTls.
  ///
  /// In it, this message translates to:
  /// **'Senza TLS chiunque sulla rete può leggere ciò che passa dal broker. Usalo solo se sai cosa fai.'**
  String get jamBrokerNoTls;

  /// No description provided for @jamBrokerInvalid.
  ///
  /// In it, this message translates to:
  /// **'Indirizzo o porta non validi'**
  String get jamBrokerInvalid;

  /// No description provided for @jamBrokerTest.
  ///
  /// In it, this message translates to:
  /// **'Prova connessione'**
  String get jamBrokerTest;

  /// No description provided for @jamBrokerTestOk.
  ///
  /// In it, this message translates to:
  /// **'{broker}: connessione riuscita'**
  String jamBrokerTestOk(String broker);

  /// No description provided for @jamBrokerTestFail.
  ///
  /// In it, this message translates to:
  /// **'{broker}: non riesco a collegarmi (rete, certificato o server non raggiungibile)'**
  String jamBrokerTestFail(String broker);

  /// No description provided for @jamBrokerRestore.
  ///
  /// In it, this message translates to:
  /// **'Ripristina'**
  String get jamBrokerRestore;

  /// No description provided for @jamBrokerMoveUp.
  ///
  /// In it, this message translates to:
  /// **'Sposta su'**
  String get jamBrokerMoveUp;

  /// No description provided for @jamBrokerRemove.
  ///
  /// In it, this message translates to:
  /// **'Togli'**
  String get jamBrokerRemove;

  /// No description provided for @jamSuspend.
  ///
  /// In it, this message translates to:
  /// **'Sospendi'**
  String get jamSuspend;

  /// No description provided for @jamBlock.
  ///
  /// In it, this message translates to:
  /// **'Blocca'**
  String get jamBlock;

  /// No description provided for @jamSuspendTitle.
  ///
  /// In it, this message translates to:
  /// **'Sospendi per quanto tempo?'**
  String get jamSuspendTitle;

  /// No description provided for @jamUntilJamEnds.
  ///
  /// In it, this message translates to:
  /// **'Fino alla fine della Jam'**
  String get jamUntilJamEnds;

  /// No description provided for @jamBlockedTitle.
  ///
  /// In it, this message translates to:
  /// **'Dispositivi bloccati'**
  String get jamBlockedTitle;

  /// No description provided for @jamSuspendedTitle.
  ///
  /// In it, this message translates to:
  /// **'Sospesi'**
  String get jamSuspendedTitle;

  /// No description provided for @jamUnblock.
  ///
  /// In it, this message translates to:
  /// **'Sblocca'**
  String get jamUnblock;

  /// No description provided for @jamSuspendedUntil.
  ///
  /// In it, this message translates to:
  /// **'Fino alle {time}'**
  String jamSuspendedUntil(String time);

  /// No description provided for @jamTooSoon.
  ///
  /// In it, this message translates to:
  /// **'Aspetta un momento prima di riprovare'**
  String get jamTooSoon;

  /// No description provided for @enrichInterrupted.
  ///
  /// In it, this message translates to:
  /// **'Arricchimento interrotto da un errore: {updated} aggiornati, {notFound} non trovati'**
  String enrichInterrupted(int updated, int notFound);

  /// No description provided for @enrichLibraryDue.
  ///
  /// In it, this message translates to:
  /// **'{count} brani da completare, circa {minutes} minuti'**
  String enrichLibraryDue(int count, int minutes);

  /// No description provided for @enrichLibraryComplete.
  ///
  /// In it, this message translates to:
  /// **'Libreria completa'**
  String get enrichLibraryComplete;

  /// No description provided for @enrichLibraryStop.
  ///
  /// In it, this message translates to:
  /// **'Interrompi'**
  String get enrichLibraryStop;

  /// No description provided for @activityEnrichWaiting.
  ///
  /// In it, this message translates to:
  /// **'Completamento: in attesa'**
  String get activityEnrichWaiting;

  /// No description provided for @logRecogSources.
  ///
  /// In it, this message translates to:
  /// **'Riconosciuti: {list}'**
  String logRecogSources(String list);

  /// No description provided for @recogSrcTags.
  ///
  /// In it, this message translates to:
  /// **'tag'**
  String get recogSrcTags;

  /// No description provided for @recogSrcVideo.
  ///
  /// In it, this message translates to:
  /// **'video'**
  String get recogSrcVideo;

  /// No description provided for @recogSrcText.
  ///
  /// In it, this message translates to:
  /// **'testo'**
  String get recogSrcText;

  /// No description provided for @recogIdent.
  ///
  /// In it, this message translates to:
  /// **'{title} – {artist}'**
  String recogIdent(String title, String artist);

  /// No description provided for @recogProposal.
  ///
  /// In it, this message translates to:
  /// **'Proposta: {identity}'**
  String recogProposal(String identity);

  /// No description provided for @recogAccept.
  ///
  /// In it, this message translates to:
  /// **'Accetta'**
  String get recogAccept;

  /// No description provided for @recogDiscard.
  ///
  /// In it, this message translates to:
  /// **'Scarta'**
  String get recogDiscard;

  /// No description provided for @recogAcceptSem.
  ///
  /// In it, this message translates to:
  /// **'Accetta la proposta {identity}'**
  String recogAcceptSem(String identity);

  /// No description provided for @recogDiscardSem.
  ///
  /// In it, this message translates to:
  /// **'Scarta la proposta {identity}'**
  String recogDiscardSem(String identity);

  /// No description provided for @recogCover.
  ///
  /// In it, this message translates to:
  /// **'Cover'**
  String get recogCover;

  /// No description provided for @recogCoverOf.
  ///
  /// In it, this message translates to:
  /// **'Cover di {identity}'**
  String recogCoverOf(String identity);

  /// No description provided for @recogToConfirm.
  ///
  /// In it, this message translates to:
  /// **'Da confermare ({count})'**
  String recogToConfirm(int count);

  /// No description provided for @recogAcceptAll.
  ///
  /// In it, this message translates to:
  /// **'Accetta tutte'**
  String get recogAcceptAll;

  /// No description provided for @recogNoProposals.
  ///
  /// In it, this message translates to:
  /// **'Tutto confermato'**
  String get recogNoProposals;

  /// No description provided for @recogFromTo.
  ///
  /// In it, this message translates to:
  /// **'Da {from} a {to}'**
  String recogFromTo(String from, String to);

  /// No description provided for @logRevert.
  ///
  /// In it, this message translates to:
  /// **'Ripristina'**
  String get logRevert;

  /// No description provided for @recogActionFailed.
  ///
  /// In it, this message translates to:
  /// **'Operazione non riuscita'**
  String get recogActionFailed;

  /// No description provided for @logRevertFailed.
  ///
  /// In it, this message translates to:
  /// **'Impossibile ripristinare questa correzione'**
  String get logRevertFailed;

  /// No description provided for @jamInviteNearby.
  ///
  /// In it, this message translates to:
  /// **'Invita chi è vicino'**
  String get jamInviteNearby;

  /// No description provided for @jamInviteHint.
  ///
  /// In it, this message translates to:
  /// **'Chi inquadra il QR o scrive il codice entra nella Jam.'**
  String get jamInviteHint;

  /// No description provided for @jamBridgeConnecting.
  ///
  /// In it, this message translates to:
  /// **'Mi collego…'**
  String get jamBridgeConnecting;

  /// No description provided for @jamBridgeRetrying.
  ///
  /// In it, this message translates to:
  /// **'Ponte interrotto, riprovo…'**
  String get jamBridgeRetrying;

  /// No description provided for @jamBridgeUnreachable.
  ///
  /// In it, this message translates to:
  /// **'Broker irraggiungibile'**
  String get jamBridgeUnreachable;

  /// No description provided for @jamCodeExpiresIn.
  ///
  /// In it, this message translates to:
  /// **'Scade tra {seconds} s'**
  String jamCodeExpiresIn(int seconds);

  /// No description provided for @jamEnterCode.
  ///
  /// In it, this message translates to:
  /// **'Entra con un codice'**
  String get jamEnterCode;

  /// No description provided for @jamCodeLabel.
  ///
  /// In it, this message translates to:
  /// **'Codice'**
  String get jamCodeLabel;

  /// No description provided for @jamScanQr.
  ///
  /// In it, this message translates to:
  /// **'Inquadra il QR'**
  String get jamScanQr;

  /// No description provided for @jamJoinAction.
  ///
  /// In it, this message translates to:
  /// **'Entra'**
  String get jamJoinAction;

  /// No description provided for @jamCodeInvalid.
  ///
  /// In it, this message translates to:
  /// **'Codice non valido'**
  String get jamCodeInvalid;

  /// No description provided for @jamCodeExpired.
  ///
  /// In it, this message translates to:
  /// **'Codice scaduto, chiedi quello nuovo'**
  String get jamCodeExpired;

  /// No description provided for @jamHostNoAnswer.
  ///
  /// In it, this message translates to:
  /// **'L’host non ha risposto'**
  String get jamHostNoAnswer;

  /// No description provided for @jamCustomBroker.
  ///
  /// In it, this message translates to:
  /// **'Questa Jam usa un broker personalizzato: inquadra il QR'**
  String get jamCustomBroker;

  /// No description provided for @jamLinkReconnecting.
  ///
  /// In it, this message translates to:
  /// **'Connessione persa, riprovo…'**
  String get jamLinkReconnecting;

  /// No description provided for @jamHostSilent.
  ///
  /// In it, this message translates to:
  /// **'Host non raggiungibile, riprovo…'**
  String get jamHostSilent;

  /// No description provided for @jamMemberUnreachable.
  ///
  /// In it, this message translates to:
  /// **'non raggiungibile'**
  String get jamMemberUnreachable;

  /// No description provided for @jamRemoteActive.
  ///
  /// In it, this message translates to:
  /// **'Jam a distanza attiva'**
  String get jamRemoteActive;

  /// No description provided for @jamRemoteEnd.
  ///
  /// In it, this message translates to:
  /// **'Termina'**
  String get jamRemoteEnd;

  /// No description provided for @jamDeclinedHost.
  ///
  /// In it, this message translates to:
  /// **'L’host ha rifiutato la richiesta'**
  String get jamDeclinedHost;

  /// No description provided for @jamBusyHost.
  ///
  /// In it, this message translates to:
  /// **'L’host ha già una Jam in corso'**
  String get jamBusyHost;

  /// No description provided for @jamWaitingHost.
  ///
  /// In it, this message translates to:
  /// **'In attesa che l’host accetti…'**
  String get jamWaitingHost;

  /// No description provided for @jamFriendsTitle.
  ///
  /// In it, this message translates to:
  /// **'Amici della Jam'**
  String get jamFriendsTitle;

  /// No description provided for @jamFriendsEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessun amico. Dopo il primo ingresso accettato, i due dispositivi si salvano a vicenda.'**
  String get jamFriendsEmpty;

  /// No description provided for @jamFriendRemove.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi'**
  String get jamFriendRemove;

  /// No description provided for @jamFriendRemoveTitle.
  ///
  /// In it, this message translates to:
  /// **'Rimuovere {name}?'**
  String jamFriendRemoveTitle(String name);

  /// No description provided for @jamFriendRemoveBody.
  ///
  /// In it, this message translates to:
  /// **'Non vi riconoscerete più senza chiedere. Questo dispositivo cambia la sua chiave d’annuncio.'**
  String get jamFriendRemoveBody;

  /// No description provided for @jamAutoAcceptFriends.
  ///
  /// In it, this message translates to:
  /// **'Accetta gli amici senza chiedere'**
  String get jamAutoAcceptFriends;

  /// No description provided for @jamAutoAcceptFriendsHint.
  ///
  /// In it, this message translates to:
  /// **'Se il telefono di un amico viene rubato, chi lo ha può entrare nella tua Jam stando vicino.'**
  String get jamAutoAcceptFriendsHint;

  /// No description provided for @jamFriendBadge.
  ///
  /// In it, this message translates to:
  /// **'Amico'**
  String get jamFriendBadge;

  /// No description provided for @jamNearbyJoin.
  ///
  /// In it, this message translates to:
  /// **'Unisciti a una Jam qui vicino'**
  String get jamNearbyJoin;

  /// No description provided for @jamBleTitle.
  ///
  /// In it, this message translates to:
  /// **'Cerca le Jam vicine'**
  String get jamBleTitle;

  /// No description provided for @jamBleBody12.
  ///
  /// In it, this message translates to:
  /// **'Android chiede il permesso «Dispositivi vicini» per cercare e annunciare le Jam via Bluetooth. L\'app non legge dove sei.'**
  String get jamBleBody12;

  /// No description provided for @jamBleBody11.
  ///
  /// In it, this message translates to:
  /// **'Serve il permesso della posizione: Android la richiede per cercare via Bluetooth; l\'app non legge dove sei.'**
  String get jamBleBody11;

  /// No description provided for @jamBleAllow.
  ///
  /// In it, this message translates to:
  /// **'Consenti'**
  String get jamBleAllow;

  /// No description provided for @jamBleNotNow.
  ///
  /// In it, this message translates to:
  /// **'Non ora'**
  String get jamBleNotNow;

  /// No description provided for @jamBleLocationOff.
  ///
  /// In it, this message translates to:
  /// **'Accendi la posizione di Android: serve per cercare le Jam via Bluetooth. Intanto puoi usare il codice o il QR.'**
  String get jamBleLocationOff;

  /// No description provided for @jamNearbyScanTitle.
  ///
  /// In it, this message translates to:
  /// **'Cerca Jam vicine'**
  String get jamNearbyScanTitle;

  /// No description provided for @jamNearbyScanHint.
  ///
  /// In it, this message translates to:
  /// **'Via Bluetooth, solo con l\'app aperta'**
  String get jamNearbyScanHint;

  /// Title of the single card shown when a streamed track's lyrics, trivia and credits did not arrive in time.
  ///
  /// In it, this message translates to:
  /// **'Non disponibile'**
  String get streamCardsUnavailable;

  /// Body of that card, above the Retry button.
  ///
  /// In it, this message translates to:
  /// **'Testo, curiosità e crediti di questo brano non sono arrivati. Può dipendere dalla rete o dalla fonte.'**
  String get streamCardsUnavailableBody;

  /// Tooltip of the ✕ of an empty, focused search field: it hides the keyboard.
  ///
  /// In it, this message translates to:
  /// **'Chiudi tastiera'**
  String get closeKeyboard;

  /// Single screen-reader label of a skeleton placeholder while content loads.
  ///
  /// In it, this message translates to:
  /// **'Caricamento…'**
  String get loadingContent;

  /// Screen-reader label of the placeholder rows of the queue: Shuffle+ suggestions still on their way.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{Shuffle+ sta scegliendo 1 brano…} other{Shuffle+ sta scegliendo {count} brani…}}'**
  String shufflePlusChoosing(int count);

  /// Label of a stats bar (touch and screen reader): day or month, then the time listened.
  ///
  /// In it, this message translates to:
  /// **'{when}, {time}'**
  String statsBarValue(String when, String time);

  /// No description provided for @homeRadioLive.
  ///
  /// In it, this message translates to:
  /// **'In diretta'**
  String get homeRadioLive;

  /// Tooltip of the ✕ of an empty search field in the Library: it closes the search.
  ///
  /// In it, this message translates to:
  /// **'Chiudi la ricerca'**
  String get closeSearch;

  /// Hint of the Library search field.
  ///
  /// In it, this message translates to:
  /// **'Cerca nella libreria'**
  String get librarySearchHint;

  /// Label of a suggested online song in a genre page, next to the online icon.
  ///
  /// In it, this message translates to:
  /// **'Suggerito'**
  String get genreMixTag;

  /// Short notice of a genre page without suggestions: a Jam is on.
  ///
  /// In it, this message translates to:
  /// **'Suggeriti spenti: Jam in corso'**
  String get genreMixOffJam;

  /// Short notice of a genre page without suggestions: metered network.
  ///
  /// In it, this message translates to:
  /// **'Suggeriti spenti: rete a consumo'**
  String get genreMixOffMetered;

  /// Short notice of a genre page without suggestions: no network.
  ///
  /// In it, this message translates to:
  /// **'Suggeriti spenti: nessuna rete'**
  String get genreMixOffOffline;

  /// Short notice of a genre page without suggestions: the online tool (yt-dlp) is missing.
  ///
  /// In it, this message translates to:
  /// **'Suggeriti spenti: strumento online assente'**
  String get genreMixOffNoTool;

  /// Short notice of a genre page without suggestions: the online service asked to slow down.
  ///
  /// In it, this message translates to:
  /// **'Suggeriti in pausa: troppe richieste'**
  String get genreMixOffRateLimited;

  /// No description provided for @playerEmptyTitle.
  ///
  /// In it, this message translates to:
  /// **'Niente in riproduzione'**
  String get playerEmptyTitle;

  /// No description provided for @playerEmptyHint.
  ///
  /// In it, this message translates to:
  /// **'Scegli da dove ripartire.'**
  String get playerEmptyHint;

  /// No description provided for @playerEmptyNoQueue.
  ///
  /// In it, this message translates to:
  /// **'Scegli un brano per iniziare'**
  String get playerEmptyNoQueue;

  /// No description provided for @playerLastQueue.
  ///
  /// In it, this message translates to:
  /// **'Ultima coda: {name}'**
  String playerLastQueue(String name);

  /// No description provided for @playerResumeLastQueue.
  ///
  /// In it, this message translates to:
  /// **'Riprendi l\'ultima coda'**
  String get playerResumeLastQueue;

  /// No description provided for @playerResumeLastQueueSub.
  ///
  /// In it, this message translates to:
  /// **'{name}, {tracks}'**
  String playerResumeLastQueueSub(String name, String tracks);

  /// No description provided for @playerShufflePlusLibrary.
  ///
  /// In it, this message translates to:
  /// **'Shuffle+ della libreria'**
  String get playerShufflePlusLibrary;

  /// No description provided for @playerShufflePlusLibrarySub.
  ///
  /// In it, this message translates to:
  /// **'Libreria in casuale con brani suggeriti'**
  String get playerShufflePlusLibrarySub;

  /// No description provided for @playerRecentlyAdded.
  ///
  /// In it, this message translates to:
  /// **'Ultimi aggiunti'**
  String get playerRecentlyAdded;

  /// No description provided for @reviewSearch.
  ///
  /// In it, this message translates to:
  /// **'Cerca'**
  String get reviewSearch;

  /// No description provided for @recogTitle.
  ///
  /// In it, this message translates to:
  /// **'Da confermare'**
  String get recogTitle;

  /// No description provided for @recogSuggested.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 correzione suggerita} other{{count} correzioni suggerite. Controllale una per una o accettale tutte.}}'**
  String recogSuggested(int count);

  /// No description provided for @recogAcceptAllCount.
  ///
  /// In it, this message translates to:
  /// **'Accetta tutte ({count})'**
  String recogAcceptAllCount(int count);

  /// No description provided for @recogAcceptedAll.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 correzione accettata} other{{count} correzioni accettate}}. I file si aggiornano in sottofondo.'**
  String recogAcceptedAll(int count);

  /// No description provided for @recogNoProposalsHint.
  ///
  /// In it, this message translates to:
  /// **'Non c\'è più niente da controllare.'**
  String get recogNoProposalsHint;

  /// No description provided for @logToday.
  ///
  /// In it, this message translates to:
  /// **'Oggi'**
  String get logToday;

  /// No description provided for @logYesterday.
  ///
  /// In it, this message translates to:
  /// **'Ieri'**
  String get logYesterday;

  /// No description provided for @logDayCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 voce} other{{count} voci}}'**
  String logDayCount(int count);

  /// No description provided for @logRetention.
  ///
  /// In it, this message translates to:
  /// **'Il registro tiene gli ultimi 30 giorni.'**
  String get logRetention;

  /// No description provided for @logNoMatch.
  ///
  /// In it, this message translates to:
  /// **'Nessuna voce con questo filtro.'**
  String get logNoMatch;

  /// No description provided for @logPickEntry.
  ///
  /// In it, this message translates to:
  /// **'Scegli una voce per vedere i dettagli.'**
  String get logPickEntry;

  /// No description provided for @logFilterAll.
  ///
  /// In it, this message translates to:
  /// **'Tutto'**
  String get logFilterAll;

  /// No description provided for @logFilterDownload.
  ///
  /// In it, this message translates to:
  /// **'Download'**
  String get logFilterDownload;

  /// No description provided for @logFilterLibrary.
  ///
  /// In it, this message translates to:
  /// **'Libreria'**
  String get logFilterLibrary;

  /// No description provided for @logFilterEnrich.
  ///
  /// In it, this message translates to:
  /// **'Arricchimento'**
  String get logFilterEnrich;

  /// No description provided for @logFilterCorrections.
  ///
  /// In it, this message translates to:
  /// **'Correzioni'**
  String get logFilterCorrections;

  /// No description provided for @logFilterErrors.
  ///
  /// In it, this message translates to:
  /// **'Errori'**
  String get logFilterErrors;

  /// No description provided for @logFailedLabel.
  ///
  /// In it, this message translates to:
  /// **'Non riuscito'**
  String get logFailedLabel;

  /// No description provided for @logStoppedLabel.
  ///
  /// In it, this message translates to:
  /// **'Fermato'**
  String get logStoppedLabel;

  /// No description provided for @logClearMenu.
  ///
  /// In it, this message translates to:
  /// **'Pulisci registro'**
  String get logClearMenu;

  /// No description provided for @logClearTitle.
  ///
  /// In it, this message translates to:
  /// **'Pulire il registro?'**
  String get logClearTitle;

  /// No description provided for @logClearConfirm.
  ///
  /// In it, this message translates to:
  /// **'Pulisci'**
  String get logClearConfirm;

  /// No description provided for @logPendingSub.
  ///
  /// In it, this message translates to:
  /// **'Correzioni suggerite ai tuoi brani'**
  String get logPendingSub;

  /// No description provided for @logPendingReview.
  ///
  /// In it, this message translates to:
  /// **'Rivedi'**
  String get logPendingReview;

  /// No description provided for @logPendingMore.
  ///
  /// In it, this message translates to:
  /// **'e altre {count}'**
  String logPendingMore(int count);

  /// No description provided for @logHowTitle.
  ///
  /// In it, this message translates to:
  /// **'Come risolvere'**
  String get logHowTitle;

  /// No description provided for @logTechTitle.
  ///
  /// In it, this message translates to:
  /// **'Dettaglio tecnico'**
  String get logTechTitle;

  /// No description provided for @logOpenSongs.
  ///
  /// In it, this message translates to:
  /// **'Vedi i brani'**
  String get logOpenSongs;

  /// No description provided for @logHowSettings.
  ///
  /// In it, this message translates to:
  /// **'Apri {settings}, poi «{page}».'**
  String logHowSettings(String settings, String page);

  /// No description provided for @logHowUpdate.
  ///
  /// In it, this message translates to:
  /// **'Tocca «{button}» accanto a yt-dlp.'**
  String logHowUpdate(String button);

  /// No description provided for @logHowWait.
  ///
  /// In it, this message translates to:
  /// **'Aspetta qualche minuto.'**
  String get logHowWait;

  /// No description provided for @logHowOnline.
  ///
  /// In it, this message translates to:
  /// **'Controlla di essere online.'**
  String get logHowOnline;

  /// No description provided for @logDlDone.
  ///
  /// In it, this message translates to:
  /// **'Brano scaricato'**
  String get logDlDone;

  /// No description provided for @logDlFailed.
  ///
  /// In it, this message translates to:
  /// **'Download non riuscito'**
  String get logDlFailed;

  /// No description provided for @logDlGroup.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 brano scaricato} other{{count} brani scaricati}}'**
  String logDlGroup(int count);

  /// No description provided for @logDlGroupShow.
  ///
  /// In it, this message translates to:
  /// **'Mostra i brani'**
  String get logDlGroupShow;

  /// No description provided for @logDlGroupHide.
  ///
  /// In it, this message translates to:
  /// **'Nascondi i brani'**
  String get logDlGroupHide;

  /// No description provided for @logTransferDone.
  ///
  /// In it, this message translates to:
  /// **'Brani inviati'**
  String get logTransferDone;

  /// No description provided for @logTransferFailed.
  ///
  /// In it, this message translates to:
  /// **'Invio non riuscito'**
  String get logTransferFailed;

  /// No description provided for @logScanDone.
  ///
  /// In it, this message translates to:
  /// **'Libreria aggiornata'**
  String get logScanDone;

  /// No description provided for @logScanDoneSub.
  ///
  /// In it, this message translates to:
  /// **'Controllate tutte le cartelle.'**
  String get logScanDoneSub;

  /// No description provided for @logScanStopped.
  ///
  /// In it, this message translates to:
  /// **'Scansione fermata'**
  String get logScanStopped;

  /// No description provided for @logScanFailed.
  ///
  /// In it, this message translates to:
  /// **'Scansione non riuscita'**
  String get logScanFailed;

  /// No description provided for @logStoppedSub.
  ///
  /// In it, this message translates to:
  /// **'Si è fermato prima della fine.'**
  String get logStoppedSub;

  /// No description provided for @logFailedSub.
  ///
  /// In it, this message translates to:
  /// **'Si è fermato per un errore.'**
  String get logFailedSub;

  /// No description provided for @logEnrichDone.
  ///
  /// In it, this message translates to:
  /// **'Arricchimento finito'**
  String get logEnrichDone;

  /// No description provided for @logEnrichInterrupted.
  ///
  /// In it, this message translates to:
  /// **'Arricchimento interrotto'**
  String get logEnrichInterrupted;

  /// No description provided for @logEnrichInterruptedSub.
  ///
  /// In it, this message translates to:
  /// **'Si è fermato per un errore; il lavoro fatto è salvo.'**
  String get logEnrichInterruptedSub;

  /// No description provided for @logBgDone.
  ///
  /// In it, this message translates to:
  /// **'Testi e copertine aggiunti'**
  String get logBgDone;

  /// No description provided for @logBgDoneSub.
  ///
  /// In it, this message translates to:
  /// **'Completamento in sottofondo.'**
  String get logBgDoneSub;

  /// No description provided for @logBgStopped.
  ///
  /// In it, this message translates to:
  /// **'Completamento fermato'**
  String get logBgStopped;

  /// No description provided for @logBgStoppedSub.
  ///
  /// In it, this message translates to:
  /// **'Nessuna fonte risponde in questo momento.'**
  String get logBgStoppedSub;

  /// No description provided for @logBgFailed.
  ///
  /// In it, this message translates to:
  /// **'Completamento non riuscito'**
  String get logBgFailed;

  /// No description provided for @logBgFailedSub.
  ///
  /// In it, this message translates to:
  /// **'Un errore lo ha fermato.'**
  String get logBgFailedSub;

  /// No description provided for @logSecondOpinion.
  ///
  /// In it, this message translates to:
  /// **'Secondo parere da YouTube Music'**
  String get logSecondOpinion;

  /// No description provided for @logSecondOpinionSub.
  ///
  /// In it, this message translates to:
  /// **'Controllati i brani incerti.'**
  String get logSecondOpinionSub;

  /// No description provided for @logSecondOpinionFailed.
  ///
  /// In it, this message translates to:
  /// **'Secondo parere interrotto'**
  String get logSecondOpinionFailed;

  /// No description provided for @logCleanup.
  ///
  /// In it, this message translates to:
  /// **'Doppioni cercati'**
  String get logCleanup;

  /// No description provided for @logCleanupSub.
  ///
  /// In it, this message translates to:
  /// **'Confrontati i brani della libreria.'**
  String get logCleanupSub;

  /// No description provided for @logGenres.
  ///
  /// In it, this message translates to:
  /// **'Generi dei brani riletti'**
  String get logGenres;

  /// No description provided for @logGenresSub.
  ///
  /// In it, this message translates to:
  /// **'Letti i tag dei brani per trovare tutti i generi.'**
  String get logGenresSub;

  /// No description provided for @logCountries.
  ///
  /// In it, this message translates to:
  /// **'Paesi degli artisti cercati'**
  String get logCountries;

  /// No description provided for @logCountriesSub.
  ///
  /// In it, this message translates to:
  /// **'Cercato il paese d\'origine degli artisti della libreria.'**
  String get logCountriesSub;

  /// No description provided for @logReleases.
  ///
  /// In it, this message translates to:
  /// **'Nuove uscite controllate'**
  String get logReleases;

  /// No description provided for @logReleasesSub.
  ///
  /// In it, this message translates to:
  /// **'Cercate le novità degli artisti che segui.'**
  String get logReleasesSub;

  /// No description provided for @logPodcasts.
  ///
  /// In it, this message translates to:
  /// **'Podcast aggiornati'**
  String get logPodcasts;

  /// No description provided for @logRadio.
  ///
  /// In it, this message translates to:
  /// **'Radio controllate'**
  String get logRadio;

  /// No description provided for @logTaskFailed.
  ///
  /// In it, this message translates to:
  /// **'Attività non riuscita'**
  String get logTaskFailed;

  /// No description provided for @logImportDone.
  ///
  /// In it, this message translates to:
  /// **'Playlist «{name}» importata'**
  String logImportDone(String name);

  /// No description provided for @logImportReady.
  ///
  /// In it, this message translates to:
  /// **'Playlist «{name}» pronta'**
  String logImportReady(String name);

  /// No description provided for @logImportFailed.
  ///
  /// In it, this message translates to:
  /// **'Importazione non riuscita'**
  String get logImportFailed;

  /// No description provided for @logImportRate.
  ///
  /// In it, this message translates to:
  /// **'Importazione rallentata da YouTube'**
  String get logImportRate;

  /// No description provided for @logImportPaused.
  ///
  /// In it, this message translates to:
  /// **'Importazione in pausa'**
  String get logImportPaused;

  /// No description provided for @logWhyToolMissing.
  ///
  /// In it, this message translates to:
  /// **'Manca il componente per scaricare da YouTube.'**
  String get logWhyToolMissing;

  /// No description provided for @logWhyToolOld.
  ///
  /// In it, this message translates to:
  /// **'Il componente per scaricare da YouTube è troppo vecchio.'**
  String get logWhyToolOld;

  /// No description provided for @logWhyNetwork.
  ///
  /// In it, this message translates to:
  /// **'Rete non disponibile.'**
  String get logWhyNetwork;

  /// No description provided for @logWhyRate.
  ///
  /// In it, this message translates to:
  /// **'YouTube ha chiesto di rallentare.'**
  String get logWhyRate;

  /// No description provided for @logWhyFailing.
  ///
  /// In it, this message translates to:
  /// **'Troppi errori di fila: l’ho messa in pausa.'**
  String get logWhyFailing;

  /// No description provided for @logCorrectionTitle.
  ///
  /// In it, this message translates to:
  /// **'Titolo e artista corretti'**
  String get logCorrectionTitle;

  /// No description provided for @logChipSongs.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 brano} other{{count} brani}}'**
  String logChipSongs(int count);

  /// No description provided for @logChipArtists.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 artista} other{{count} artisti}}'**
  String logChipArtists(int count);

  /// No description provided for @logChipSongsOf.
  ///
  /// In it, this message translates to:
  /// **'{done} di {total} brani'**
  String logChipSongsOf(int done, int total);

  /// No description provided for @logChipUpdated.
  ///
  /// In it, this message translates to:
  /// **'{count} aggiornati'**
  String logChipUpdated(int count);

  /// No description provided for @logChipNotFound.
  ///
  /// In it, this message translates to:
  /// **'{count} non trovati'**
  String logChipNotFound(int count);

  /// No description provided for @logChipNoResult.
  ///
  /// In it, this message translates to:
  /// **'{count} senza risultato'**
  String logChipNoResult(int count);

  /// No description provided for @logFileTitle.
  ///
  /// In it, this message translates to:
  /// **'Correzione salvata, file non aggiornato'**
  String get logFileTitle;

  /// No description provided for @logHowFileMissing.
  ///
  /// In it, this message translates to:
  /// **'Controlla che il brano sia ancora nella sua cartella.'**
  String get logHowFileMissing;

  /// No description provided for @logHowFileReadOnly.
  ///
  /// In it, this message translates to:
  /// **'Togli la sola lettura al file o alla sua cartella, poi correggi di nuovo il brano.'**
  String get logHowFileReadOnly;

  /// No description provided for @logHowFileRetry.
  ///
  /// In it, this message translates to:
  /// **'Controlla che ci sia spazio sul disco e che il file non sia in uso, poi correggi di nuovo il brano.'**
  String get logHowFileRetry;

  /// No description provided for @logClearBody.
  ///
  /// In it, this message translates to:
  /// **'Cancello tutte le voci e tolgo dalla lista i download finiti. Dopo non potrai più ripristinare le correzioni. I brani restano dove sono.'**
  String get logClearBody;

  /// No description provided for @logHowResume.
  ///
  /// In it, this message translates to:
  /// **'Tocca «{button}» sull’importazione in pausa, nell’elenco delle attività.'**
  String logHowResume(String button);

  /// No description provided for @logEnrichStopped.
  ///
  /// In it, this message translates to:
  /// **'Arricchimento fermato'**
  String get logEnrichStopped;

  /// No description provided for @logCorrectionSem.
  ///
  /// In it, this message translates to:
  /// **'Da {from} a {to}'**
  String logCorrectionSem(String from, String to);

  /// No description provided for @smartAll.
  ///
  /// In it, this message translates to:
  /// **'Tutte le condizioni'**
  String get smartAll;

  /// No description provided for @smartAny.
  ///
  /// In it, this message translates to:
  /// **'Almeno una'**
  String get smartAny;

  /// No description provided for @smartAllNote.
  ///
  /// In it, this message translates to:
  /// **'I brani devono rispettare tutti i filtri.'**
  String get smartAllNote;

  /// No description provided for @smartAnyNote.
  ///
  /// In it, this message translates to:
  /// **'Basta che un filtro sia rispettato.'**
  String get smartAnyNote;

  /// No description provided for @smartAddFilter.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi filtro'**
  String get smartAddFilter;

  /// No description provided for @smartGroupMusic.
  ///
  /// In it, this message translates to:
  /// **'Musica'**
  String get smartGroupMusic;

  /// No description provided for @smartGroupListening.
  ///
  /// In it, this message translates to:
  /// **'Ascolto'**
  String get smartGroupListening;

  /// No description provided for @smartGroupFile.
  ///
  /// In it, this message translates to:
  /// **'File'**
  String get smartGroupFile;

  /// No description provided for @smartFieldTag.
  ///
  /// In it, this message translates to:
  /// **'Tag'**
  String get smartFieldTag;

  /// No description provided for @smartFieldAlbumArtist.
  ///
  /// In it, this message translates to:
  /// **'Artista dell’album'**
  String get smartFieldAlbumArtist;

  /// No description provided for @smartFieldCountry.
  ///
  /// In it, this message translates to:
  /// **'Nazionalità'**
  String get smartFieldCountry;

  /// No description provided for @smartFieldPlays.
  ///
  /// In it, this message translates to:
  /// **'Ascolti'**
  String get smartFieldPlays;

  /// No description provided for @smartFieldLastPlayed.
  ///
  /// In it, this message translates to:
  /// **'Ultimo ascolto'**
  String get smartFieldLastPlayed;

  /// No description provided for @smartFieldAdded.
  ///
  /// In it, this message translates to:
  /// **'Aggiunto'**
  String get smartFieldAdded;

  /// No description provided for @smartFieldBitrate.
  ///
  /// In it, this message translates to:
  /// **'Bitrate'**
  String get smartFieldBitrate;

  /// No description provided for @smartFieldFolder.
  ///
  /// In it, this message translates to:
  /// **'Cartella'**
  String get smartFieldFolder;

  /// No description provided for @smartFlagLyrics.
  ///
  /// In it, this message translates to:
  /// **'Con testo'**
  String get smartFlagLyrics;

  /// No description provided for @smartEnrichedOnly.
  ///
  /// In it, this message translates to:
  /// **'Solo per i brani arricchiti'**
  String get smartEnrichedOnly;

  /// No description provided for @smartInclude.
  ///
  /// In it, this message translates to:
  /// **'Includi'**
  String get smartInclude;

  /// No description provided for @smartExclude.
  ///
  /// In it, this message translates to:
  /// **'Escludi'**
  String get smartExclude;

  /// No description provided for @smartPickValues.
  ///
  /// In it, this message translates to:
  /// **'Scegli i valori'**
  String get smartPickValues;

  /// No description provided for @smartAddValue.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi'**
  String get smartAddValue;

  /// No description provided for @smartValueHint.
  ///
  /// In it, this message translates to:
  /// **'Scrivi un valore'**
  String get smartValueHint;

  /// No description provided for @smartDone.
  ///
  /// In it, this message translates to:
  /// **'Fatto'**
  String get smartDone;

  /// No description provided for @smartIncomplete.
  ///
  /// In it, this message translates to:
  /// **'Incompleto: completalo o rimuovilo per salvare.'**
  String get smartIncomplete;

  /// No description provided for @smartRemoveFilter.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi filtro'**
  String get smartRemoveFilter;

  /// No description provided for @smartRemoveValue.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi {value}'**
  String smartRemoveValue(String value);

  /// No description provided for @smartFrom.
  ///
  /// In it, this message translates to:
  /// **'Da'**
  String get smartFrom;

  /// No description provided for @smartTo.
  ///
  /// In it, this message translates to:
  /// **'A'**
  String get smartTo;

  /// No description provided for @smartMoreThan.
  ///
  /// In it, this message translates to:
  /// **'Più di'**
  String get smartMoreThan;

  /// No description provided for @smartLessThan.
  ///
  /// In it, this message translates to:
  /// **'Meno di'**
  String get smartLessThan;

  /// No description provided for @smartEqualTo.
  ///
  /// In it, this message translates to:
  /// **'Uguale a'**
  String get smartEqualTo;

  /// No description provided for @smartAgeRecent.
  ///
  /// In it, this message translates to:
  /// **'Negli ultimi'**
  String get smartAgeRecent;

  /// No description provided for @smartAgeOlder.
  ///
  /// In it, this message translates to:
  /// **'Da più di'**
  String get smartAgeOlder;

  /// No description provided for @smartDays.
  ///
  /// In it, this message translates to:
  /// **'giorni'**
  String get smartDays;

  /// No description provided for @smartMinutes.
  ///
  /// In it, this message translates to:
  /// **'minuti'**
  String get smartMinutes;

  /// No description provided for @smartContains.
  ///
  /// In it, this message translates to:
  /// **'Contiene'**
  String get smartContains;

  /// No description provided for @smartAdvancedNote.
  ///
  /// In it, this message translates to:
  /// **'Il testo della regola, in sola lettura.'**
  String get smartAdvancedNote;

  /// No description provided for @smartNotVisual.
  ///
  /// In it, this message translates to:
  /// **'Questa regola è troppo articolata per l’editor a filtri. Resta com’è: la vedi in Avanzate e, se la salvi senza toccarla, non cambia.'**
  String get smartNotVisual;

  /// No description provided for @smartNoFilters.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi un filtro per iniziare.'**
  String get smartNoFilters;

  /// No description provided for @smartLimitShort.
  ///
  /// In it, this message translates to:
  /// **'Limite'**
  String get smartLimitShort;

  /// No description provided for @smartIs.
  ///
  /// In it, this message translates to:
  /// **'È'**
  String get smartIs;

  /// No description provided for @smartRestart.
  ///
  /// In it, this message translates to:
  /// **'Ricomincia con i filtri'**
  String get smartRestart;

  /// No description provided for @smartRestarted.
  ///
  /// In it, this message translates to:
  /// **'Regola azzerata'**
  String get smartRestarted;

  /// No description provided for @smartCountError.
  ///
  /// In it, this message translates to:
  /// **'Conteggio non disponibile'**
  String get smartCountError;

  /// No description provided for @artistMergedNote.
  ///
  /// In it, this message translates to:
  /// **'{count} profili uniti'**
  String artistMergedNote(int count);

  /// No description provided for @artistSplit.
  ///
  /// In it, this message translates to:
  /// **'Separa profili'**
  String get artistSplit;

  /// No description provided for @artistMergeWith.
  ///
  /// In it, this message translates to:
  /// **'Unisci con…'**
  String get artistMergeWith;

  /// No description provided for @artistSameWarn.
  ///
  /// In it, this message translates to:
  /// **'Sembra lo stesso artista di un altro profilo ({name}).'**
  String artistSameWarn(String name);

  /// No description provided for @artistMergeYes.
  ///
  /// In it, this message translates to:
  /// **'Unisci'**
  String get artistMergeYes;

  /// No description provided for @artistNotSame.
  ///
  /// In it, this message translates to:
  /// **'Sono diversi'**
  String get artistNotSame;

  /// No description provided for @artistMerged.
  ///
  /// In it, this message translates to:
  /// **'Profili uniti.'**
  String get artistMerged;

  /// No description provided for @artistSplitDone.
  ///
  /// In it, this message translates to:
  /// **'Profili separati.'**
  String get artistSplitDone;

  /// No description provided for @artistNotSameDone.
  ///
  /// In it, this message translates to:
  /// **'Va bene, non lo chiederò più per questi due profili.'**
  String get artistNotSameDone;

  /// No description provided for @artistMergePick.
  ///
  /// In it, this message translates to:
  /// **'Con quale profilo?'**
  String get artistMergePick;

  /// No description provided for @mergedSheetTitle.
  ///
  /// In it, this message translates to:
  /// **'Profili uniti'**
  String get mergedSheetTitle;

  /// No description provided for @artistMainProfile.
  ///
  /// In it, this message translates to:
  /// **'Principale'**
  String get artistMainProfile;

  /// No description provided for @artistOtherProfileOf.
  ///
  /// In it, this message translates to:
  /// **'Altro profilo di {name}'**
  String artistOtherProfileOf(String name);

  /// No description provided for @artistSeparate.
  ///
  /// In it, this message translates to:
  /// **'Separa'**
  String get artistSeparate;

  /// No description provided for @artistSeparated.
  ///
  /// In it, this message translates to:
  /// **'Profilo separato.'**
  String get artistSeparated;

  /// No description provided for @settingsMergedArtists.
  ///
  /// In it, this message translates to:
  /// **'Artisti uniti'**
  String get settingsMergedArtists;

  /// No description provided for @settingsMergedArtistsHint.
  ///
  /// In it, this message translates to:
  /// **'Vedi i profili uniti e separali, o togli i «diversi».'**
  String get settingsMergedArtistsHint;

  /// No description provided for @mergedArtistsEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessun artista unito.'**
  String get mergedArtistsEmpty;

  /// No description provided for @mergedArtistsEmptyHelp.
  ///
  /// In it, this message translates to:
  /// **'Quando unisci due profili dello stesso artista, compaiono qui.'**
  String get mergedArtistsEmptyHelp;

  /// No description provided for @mergedArtistsSplitAll.
  ///
  /// In it, this message translates to:
  /// **'Separa tutto'**
  String get mergedArtistsSplitAll;

  /// No description provided for @notSameTitle.
  ///
  /// In it, this message translates to:
  /// **'Segnati come diversi'**
  String get notSameTitle;

  /// No description provided for @notSameRemove.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi'**
  String get notSameRemove;

  /// No description provided for @notSameEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessuna coppia segnata come diversa.'**
  String get notSameEmpty;

  /// No description provided for @openArtistPage.
  ///
  /// In it, this message translates to:
  /// **'Apri la pagina dell’artista'**
  String get openArtistPage;

  /// No description provided for @podcastYours.
  ///
  /// In it, this message translates to:
  /// **'I tuoi podcast'**
  String get podcastYours;

  /// No description provided for @podcastDiscover.
  ///
  /// In it, this message translates to:
  /// **'Scopri'**
  String get podcastDiscover;

  /// No description provided for @podcastChartTitle.
  ///
  /// In it, this message translates to:
  /// **'Classifica italiana di Apple Podcasts'**
  String get podcastChartTitle;

  /// No description provided for @podcastGenreAll.
  ///
  /// In it, this message translates to:
  /// **'Tutti'**
  String get podcastGenreAll;

  /// No description provided for @podcastSearchLens.
  ///
  /// In it, this message translates to:
  /// **'Cerca podcast'**
  String get podcastSearchLens;

  /// No description provided for @podcastSubscribedLabel.
  ///
  /// In it, this message translates to:
  /// **'Iscritto'**
  String get podcastSubscribedLabel;

  /// No description provided for @podcastOriginApple.
  ///
  /// In it, this message translates to:
  /// **'Apple Podcasts'**
  String get podcastOriginApple;

  /// No description provided for @podcastChartError.
  ///
  /// In it, this message translates to:
  /// **'La classifica non risponde. Succede, non è colpa tua.'**
  String get podcastChartError;

  /// No description provided for @podcastNoFeed.
  ///
  /// In it, this message translates to:
  /// **'Apple non ha un feed per questo podcast.'**
  String get podcastNoFeed;

  /// No description provided for @podcastGenreArts.
  ///
  /// In it, this message translates to:
  /// **'Arti'**
  String get podcastGenreArts;

  /// No description provided for @podcastGenreBusiness.
  ///
  /// In it, this message translates to:
  /// **'Economia'**
  String get podcastGenreBusiness;

  /// No description provided for @podcastGenreComedy.
  ///
  /// In it, this message translates to:
  /// **'Comicità'**
  String get podcastGenreComedy;

  /// No description provided for @podcastGenreEducation.
  ///
  /// In it, this message translates to:
  /// **'Educazione'**
  String get podcastGenreEducation;

  /// No description provided for @podcastGenreKids.
  ///
  /// In it, this message translates to:
  /// **'Bambini e famiglia'**
  String get podcastGenreKids;

  /// No description provided for @podcastGenreHealth.
  ///
  /// In it, this message translates to:
  /// **'Salute e benessere'**
  String get podcastGenreHealth;

  /// No description provided for @podcastGenreTvFilm.
  ///
  /// In it, this message translates to:
  /// **'TV e cinema'**
  String get podcastGenreTvFilm;

  /// No description provided for @podcastGenreMusic.
  ///
  /// In it, this message translates to:
  /// **'Musica'**
  String get podcastGenreMusic;

  /// No description provided for @podcastGenreNews.
  ///
  /// In it, this message translates to:
  /// **'Notizie'**
  String get podcastGenreNews;

  /// No description provided for @podcastGenreReligion.
  ///
  /// In it, this message translates to:
  /// **'Religione e spiritualità'**
  String get podcastGenreReligion;

  /// No description provided for @podcastGenreScience.
  ///
  /// In it, this message translates to:
  /// **'Scienza'**
  String get podcastGenreScience;

  /// No description provided for @podcastGenreSports.
  ///
  /// In it, this message translates to:
  /// **'Sport'**
  String get podcastGenreSports;

  /// No description provided for @podcastGenreTechnology.
  ///
  /// In it, this message translates to:
  /// **'Tecnologia'**
  String get podcastGenreTechnology;

  /// No description provided for @podcastGenreSociety.
  ///
  /// In it, this message translates to:
  /// **'Società e cultura'**
  String get podcastGenreSociety;

  /// No description provided for @podcastGenreGovernment.
  ///
  /// In it, this message translates to:
  /// **'Governo'**
  String get podcastGenreGovernment;

  /// No description provided for @podcastGenreHistory.
  ///
  /// In it, this message translates to:
  /// **'Storia'**
  String get podcastGenreHistory;

  /// No description provided for @podcastGenreTrueCrime.
  ///
  /// In it, this message translates to:
  /// **'True crime'**
  String get podcastGenreTrueCrime;

  /// No description provided for @podcastSubscribeTo.
  ///
  /// In it, this message translates to:
  /// **'Iscriviti a {name}'**
  String podcastSubscribeTo(String name);

  /// Snackbar right after a pick in Search: the radio is being asked for similar songs.
  ///
  /// In it, this message translates to:
  /// **'Cerco brani simili…'**
  String get searchSimilarLooking;

  /// Snackbar once the pick plays with similar songs after it.
  ///
  /// In it, this message translates to:
  /// **'Coda: «{title}» e brani simili'**
  String searchSimilarQueued(String title);

  /// Snackbar when no similar song came (offline, source off or none found): only the pick plays.
  ///
  /// In it, this message translates to:
  /// **'Nessun brano simile: suono solo «{title}»'**
  String searchSimilarNone(String title);

  /// Action of the snackbar: opens the queue sheet.
  ///
  /// In it, this message translates to:
  /// **'Vedi coda'**
  String get searchSeeQueue;

  /// Header of the queue sheet above the songs that follow a Search pick.
  ///
  /// In it, this message translates to:
  /// **'Simili a «{title}»'**
  String queueSimilarTo(String title);

  /// Small tag in the queue header after a Search pick: where the similar songs come from.
  ///
  /// In it, this message translates to:
  /// **'radio YouTube Music'**
  String get queueSimilarTag;

  /// Count line of the queue header after a Search pick: songs that follow, and how many are already in the library.
  ///
  /// In it, this message translates to:
  /// **'{total, plural, one{1 brano} other{{total} brani}}, {owned} già in libreria'**
  String queueSimilarCount(int total, int owned);

  /// Line of the queue header while the first similar songs are being asked.
  ///
  /// In it, this message translates to:
  /// **'Cerco i brani simili…'**
  String get queueSimilarSearching;

  /// No description provided for @dislikeSheetTitle.
  ///
  /// In it, this message translates to:
  /// **'Non ti piace il brano o l’artista?'**
  String get dislikeSheetTitle;

  /// No description provided for @dislikeSheetTrack.
  ///
  /// In it, this message translates to:
  /// **'Solo questo brano'**
  String get dislikeSheetTrack;

  /// No description provided for @dislikeSheetTrackHint.
  ///
  /// In it, this message translates to:
  /// **'«{title}» non torna, salvo che sia molto vicino a ciò che ascolti.'**
  String dislikeSheetTrackHint(String title);

  /// No description provided for @dislikeSheetArtist.
  ///
  /// In it, this message translates to:
  /// **'Tutto {artist}'**
  String dislikeSheetArtist(String artist);

  /// No description provided for @dislikeSheetArtistHint.
  ///
  /// In it, this message translates to:
  /// **'Nessun brano di {artist} ti verrà più suggerito.'**
  String dislikeSheetArtistHint(String artist);

  /// No description provided for @dislikeArtistDone.
  ///
  /// In it, this message translates to:
  /// **'{artist} non ti verrà più suggerito'**
  String dislikeArtistDone(String artist);

  /// No description provided for @artistBlockedLabel.
  ///
  /// In it, this message translates to:
  /// **'Artista bloccato'**
  String get artistBlockedLabel;

  /// No description provided for @dislikesBlockedOn.
  ///
  /// In it, this message translates to:
  /// **'Escluso il {date}'**
  String dislikesBlockedOn(String date);

  /// No description provided for @podcastFollow.
  ///
  /// In it, this message translates to:
  /// **'Segui'**
  String get podcastFollow;

  /// No description provided for @podcastFollowing.
  ///
  /// In it, this message translates to:
  /// **'Segui già'**
  String get podcastFollowing;

  /// No description provided for @podcastFollowLabel.
  ///
  /// In it, this message translates to:
  /// **'Segui {name}'**
  String podcastFollowLabel(String name);

  /// No description provided for @podcastUnfollowLabel.
  ///
  /// In it, this message translates to:
  /// **'Smetti di seguire {name}'**
  String podcastUnfollowLabel(String name);

  /// No description provided for @podcastPreviewNote.
  ///
  /// In it, this message translates to:
  /// **'Anteprima: non lo segui ancora. Gli episodi si ascoltano in streaming.'**
  String get podcastPreviewNote;

  /// No description provided for @podcastPreviewFollowed.
  ///
  /// In it, this message translates to:
  /// **'Ora è nei tuoi podcast. Il punto di ripresa resta salvato.'**
  String get podcastPreviewFollowed;

  /// No description provided for @podcastFollowedMsg.
  ///
  /// In it, this message translates to:
  /// **'Aggiunto ai tuoi podcast'**
  String get podcastFollowedMsg;

  /// No description provided for @podcastUnfollowedMsg.
  ///
  /// In it, this message translates to:
  /// **'Non lo segui più. Gli episodi restano ascoltabili'**
  String get podcastUnfollowedMsg;

  /// No description provided for @podcastPlayStream.
  ///
  /// In it, this message translates to:
  /// **'Riproduci in streaming: {title}'**
  String podcastPlayStream(String title);

  /// No description provided for @podcastStreamUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Questo podcast non si ascolta ancora in streaming.'**
  String get podcastStreamUnavailable;

  /// No description provided for @podcastUnfollowTitle.
  ///
  /// In it, this message translates to:
  /// **'Smettere di seguire?'**
  String get podcastUnfollowTitle;

  /// No description provided for @podcastUnfollowBody.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{Hai 1 episodio scaricato. Vuoi tenerlo o cancellarlo?} other{Hai {count} episodi scaricati. Vuoi tenerli o cancellarli?}}'**
  String podcastUnfollowBody(int count);

  /// No description provided for @podcastKeepDownloads.
  ///
  /// In it, this message translates to:
  /// **'Tieni'**
  String get podcastKeepDownloads;

  /// No description provided for @podcastDeleteDownloads.
  ///
  /// In it, this message translates to:
  /// **'Cancella'**
  String get podcastDeleteDownloads;

  /// No description provided for @lyricsWrite.
  ///
  /// In it, this message translates to:
  /// **'Scrivi o incolla'**
  String get lyricsWrite;

  /// No description provided for @lyricsWriteA11y.
  ///
  /// In it, this message translates to:
  /// **'Scrivi o incolla il testo'**
  String get lyricsWriteA11y;

  /// No description provided for @lyricsEdit.
  ///
  /// In it, this message translates to:
  /// **'Modifica testo'**
  String get lyricsEdit;

  /// No description provided for @lyricsDelete.
  ///
  /// In it, this message translates to:
  /// **'Elimina testo'**
  String get lyricsDelete;

  /// No description provided for @lyricsSyncSwitch.
  ///
  /// In it, this message translates to:
  /// **'Testo sincronizzato'**
  String get lyricsSyncSwitch;

  /// No description provided for @lyricsEditorTitle.
  ///
  /// In it, this message translates to:
  /// **'Testo del brano'**
  String get lyricsEditorTitle;

  /// No description provided for @lyricsEditorLabel.
  ///
  /// In it, this message translates to:
  /// **'Incolla o scrivi qui'**
  String get lyricsEditorLabel;

  /// No description provided for @lyricsEditorHint.
  ///
  /// In it, this message translates to:
  /// **'Scrivi o incolla il testo, una riga per verso.'**
  String get lyricsEditorHint;

  /// No description provided for @lyricsEditorInfo.
  ///
  /// In it, this message translates to:
  /// **'Se le righe iniziano con un tempo, come [01:23.45], il testo viene riconosciuto come sincronizzato e scorre con il brano. Altrimenti resta testo semplice. Salvarlo qui impedisce che la ricerca automatica lo sostituisca.'**
  String get lyricsEditorInfo;

  /// No description provided for @lyricsEditorSaveA11y.
  ///
  /// In it, this message translates to:
  /// **'Salva il testo'**
  String get lyricsEditorSaveA11y;

  /// No description provided for @lyricsDetectNone.
  ///
  /// In it, this message translates to:
  /// **'Niente da salvare ancora'**
  String get lyricsDetectNone;

  /// No description provided for @lyricsDetectSynced.
  ///
  /// In it, this message translates to:
  /// **'Riconosciuto come sincronizzato: {count} righe con tempo'**
  String lyricsDetectSynced(int count);

  /// No description provided for @lyricsDetectPlain.
  ///
  /// In it, this message translates to:
  /// **'Testo semplice, senza tempi'**
  String get lyricsDetectPlain;

  /// No description provided for @lyricsEmptyWarn.
  ///
  /// In it, this message translates to:
  /// **'Scrivi qualcosa prima di salvare'**
  String get lyricsEmptyWarn;

  /// No description provided for @lyricsSavedSynced.
  ///
  /// In it, this message translates to:
  /// **'Testo salvato, sincronizzato'**
  String get lyricsSavedSynced;

  /// No description provided for @lyricsSavedPlain.
  ///
  /// In it, this message translates to:
  /// **'Testo salvato, testo semplice'**
  String get lyricsSavedPlain;

  /// No description provided for @lyricsDeleted.
  ///
  /// In it, this message translates to:
  /// **'Testo eliminato'**
  String get lyricsDeleted;

  /// No description provided for @lyricsSyncedKept.
  ///
  /// In it, this message translates to:
  /// **'La versione sincronizzata è conservata: riattivala dal menu.'**
  String get lyricsSyncedKept;

  /// No description provided for @memoryOpenFolder.
  ///
  /// In it, this message translates to:
  /// **'apri'**
  String get memoryOpenFolder;

  /// No description provided for @memoryOpenFolderLabel.
  ///
  /// In it, this message translates to:
  /// **'Apri la cartella {name} nel file manager. {path}'**
  String memoryOpenFolderLabel(String name, String path);

  /// No description provided for @memoryOpenFolderFailed.
  ///
  /// In it, this message translates to:
  /// **'Non riesco ad aprire la cartella: percorso copiato'**
  String get memoryOpenFolderFailed;

  /// No description provided for @lyricsSyncStateOn.
  ///
  /// In it, this message translates to:
  /// **'attivo'**
  String get lyricsSyncStateOn;

  /// No description provided for @lyricsSyncStateOff.
  ///
  /// In it, this message translates to:
  /// **'disattivo'**
  String get lyricsSyncStateOff;

  /// No description provided for @lyricsDeleteFailed.
  ///
  /// In it, this message translates to:
  /// **'Impossibile eliminare il testo'**
  String get lyricsDeleteFailed;

  /// No description provided for @lyricsSaveFailed.
  ///
  /// In it, this message translates to:
  /// **'Impossibile salvare il testo'**
  String get lyricsSaveFailed;

  /// No description provided for @daylistSlot0.
  ///
  /// In it, this message translates to:
  /// **'Mattina presto'**
  String get daylistSlot0;

  /// No description provided for @daylistSlot1.
  ///
  /// In it, this message translates to:
  /// **'Tarda mattinata'**
  String get daylistSlot1;

  /// No description provided for @daylistSlot2.
  ///
  /// In it, this message translates to:
  /// **'Primo pomeriggio'**
  String get daylistSlot2;

  /// No description provided for @daylistSlot3.
  ///
  /// In it, this message translates to:
  /// **'Tardo pomeriggio'**
  String get daylistSlot3;

  /// No description provided for @daylistSlot4.
  ///
  /// In it, this message translates to:
  /// **'Sera'**
  String get daylistSlot4;

  /// No description provided for @daylistSlot5.
  ///
  /// In it, this message translates to:
  /// **'Tarda sera'**
  String get daylistSlot5;

  /// No description provided for @daylistSlot6.
  ///
  /// In it, this message translates to:
  /// **'Notte'**
  String get daylistSlot6;

  /// No description provided for @daylistSlot7.
  ///
  /// In it, this message translates to:
  /// **'Tarda notte'**
  String get daylistSlot7;

  /// No description provided for @daylistMoodEnergetic.
  ///
  /// In it, this message translates to:
  /// **'Energico'**
  String get daylistMoodEnergetic;

  /// No description provided for @daylistMoodCheerful.
  ///
  /// In it, this message translates to:
  /// **'Allegro'**
  String get daylistMoodCheerful;

  /// No description provided for @daylistMoodCalm.
  ///
  /// In it, this message translates to:
  /// **'Tranquillo'**
  String get daylistMoodCalm;

  /// No description provided for @daylistMoodRelaxing.
  ///
  /// In it, this message translates to:
  /// **'Rilassante'**
  String get daylistMoodRelaxing;

  /// No description provided for @daylistMoodMelancholic.
  ///
  /// In it, this message translates to:
  /// **'Malinconico'**
  String get daylistMoodMelancholic;

  /// No description provided for @daylistMoodFocus.
  ///
  /// In it, this message translates to:
  /// **'Concentrazione'**
  String get daylistMoodFocus;

  /// No description provided for @daylistTitle.
  ///
  /// In it, this message translates to:
  /// **'Daylist'**
  String get daylistTitle;

  /// No description provided for @daylistNow.
  ///
  /// In it, this message translates to:
  /// **'Daylist, adesso'**
  String get daylistNow;

  /// No description provided for @daylistCardMeta.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 brano} other{{count} brani}}, cambia alle {time}'**
  String daylistCardMeta(num count, Object time);

  /// No description provided for @daylistCardLabel.
  ///
  /// In it, this message translates to:
  /// **'Daylist: {name}. {count, plural, one{1 brano} other{{count} brani}}. Si aggiorna alle {time}'**
  String daylistCardLabel(num count, Object name, Object time);

  /// No description provided for @daylistPlay.
  ///
  /// In it, this message translates to:
  /// **'Riproduci la daylist'**
  String get daylistPlay;

  /// No description provided for @daylistUpdates.
  ///
  /// In it, this message translates to:
  /// **'Si aggiorna alle {time} con «{slot}»'**
  String daylistUpdates(Object slot, Object time);

  /// No description provided for @daylistShortNote.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{Solo 1 brano: la libreria ne ha pochi per questa fascia.} other{Solo {count} brani: la libreria ne ha pochi per questa fascia.}}'**
  String daylistShortNote(num count);

  /// No description provided for @daylistSuggestedCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 suggerito} other{{count} suggeriti}} da YouTube Music'**
  String daylistSuggestedCount(num count);

  /// No description provided for @daylistGenres.
  ///
  /// In it, this message translates to:
  /// **'Generi della daylist'**
  String get daylistGenres;

  /// No description provided for @daylistSettingsOpen.
  ///
  /// In it, this message translates to:
  /// **'Impostazioni daylist'**
  String get daylistSettingsOpen;

  /// No description provided for @daylistEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessuna daylist in questa fascia'**
  String get daylistEmpty;

  /// No description provided for @settingsPageDaylist.
  ///
  /// In it, this message translates to:
  /// **'Daylist'**
  String get settingsPageDaylist;

  /// No description provided for @daylistIntro.
  ///
  /// In it, this message translates to:
  /// **'Una playlist da 50 brani che cambia a ogni fascia del giorno. Tocca una fascia per sceglierne generi e umori.'**
  String get daylistIntro;

  /// No description provided for @daylistSummaryPage.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 fascia accesa} other{{count} fasce accese}}'**
  String daylistSummaryPage(num count);

  /// No description provided for @daylistSlotSummary.
  ///
  /// In it, this message translates to:
  /// **'{genres}, quota {percent}%'**
  String daylistSlotSummary(Object genres, Object percent);

  /// No description provided for @daylistSlotOff.
  ///
  /// In it, this message translates to:
  /// **'Spenta'**
  String get daylistSlotOff;

  /// No description provided for @daylistTooFewWarn.
  ///
  /// In it, this message translates to:
  /// **'Meno di 15 brani: la daylist non si crea'**
  String get daylistTooFewWarn;

  /// No description provided for @daylistSlotRowLabel.
  ///
  /// In it, this message translates to:
  /// **'{name}, {time}, {summary}'**
  String daylistSlotRowLabel(Object name, Object summary, Object time);

  /// No description provided for @daylistSwitchOn.
  ///
  /// In it, this message translates to:
  /// **'{name}, acceso'**
  String daylistSwitchOn(Object name);

  /// No description provided for @daylistSwitchOff.
  ///
  /// In it, this message translates to:
  /// **'{name}, spento'**
  String daylistSwitchOff(Object name);

  /// No description provided for @daylistMoodTable.
  ///
  /// In it, this message translates to:
  /// **'Genere e umore'**
  String get daylistMoodTable;

  /// No description provided for @daylistMoodTableSub.
  ///
  /// In it, this message translates to:
  /// **'Come ogni genere si lega agli umori'**
  String get daylistMoodTableSub;

  /// No description provided for @daylistResetAll.
  ///
  /// In it, this message translates to:
  /// **'Ripristina i valori di serie'**
  String get daylistResetAll;

  /// No description provided for @daylistResetTitle.
  ///
  /// In it, this message translates to:
  /// **'Ripristinare tutto?'**
  String get daylistResetTitle;

  /// No description provided for @daylistResetBody.
  ///
  /// In it, this message translates to:
  /// **'Orari, generi, umori e quote di tutte le fasce e la tabella genere e umore tornano ai valori di serie. Le daylist già generate restano fino al prossimo cambio.'**
  String get daylistResetBody;

  /// No description provided for @daylistResetGo.
  ///
  /// In it, this message translates to:
  /// **'Ripristina'**
  String get daylistResetGo;

  /// No description provided for @daylistSlotSwitch.
  ///
  /// In it, this message translates to:
  /// **'Daylist in questa fascia'**
  String get daylistSlotSwitch;

  /// No description provided for @daylistRegenAt.
  ///
  /// In it, this message translates to:
  /// **'Si rigenera alle {time}'**
  String daylistRegenAt(Object time);

  /// No description provided for @daylistNoCard.
  ///
  /// In it, this message translates to:
  /// **'Nessuna card in Home'**
  String get daylistNoCard;

  /// No description provided for @daylistStartsAt.
  ///
  /// In it, this message translates to:
  /// **'Inizia alle'**
  String get daylistStartsAt;

  /// No description provided for @daylistEndsAt.
  ///
  /// In it, this message translates to:
  /// **'Finisce alle {time}'**
  String daylistEndsAt(Object time);

  /// No description provided for @daylistEarlier.
  ///
  /// In it, this message translates to:
  /// **'Anticipa di un’ora'**
  String get daylistEarlier;

  /// No description provided for @daylistLater.
  ///
  /// In it, this message translates to:
  /// **'Posticipa di un’ora'**
  String get daylistLater;

  /// No description provided for @daylistPrefer.
  ///
  /// In it, this message translates to:
  /// **'Generi da preferire'**
  String get daylistPrefer;

  /// No description provided for @daylistAvoid.
  ///
  /// In it, this message translates to:
  /// **'Generi da evitare'**
  String get daylistAvoid;

  /// No description provided for @daylistAdd.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi'**
  String get daylistAdd;

  /// No description provided for @daylistAddPrefer.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi un genere da preferire'**
  String get daylistAddPrefer;

  /// No description provided for @daylistAddAvoid.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi un genere da evitare'**
  String get daylistAddAvoid;

  /// No description provided for @daylistAddNamed.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi {genre}'**
  String daylistAddNamed(Object genre);

  /// No description provided for @daylistRemovePrefer.
  ///
  /// In it, this message translates to:
  /// **'{genre}, da preferire, tocca per togliere'**
  String daylistRemovePrefer(Object genre);

  /// No description provided for @daylistRemoveAvoid.
  ///
  /// In it, this message translates to:
  /// **'{genre}, da evitare, tocca per togliere'**
  String daylistRemoveAvoid(Object genre);

  /// No description provided for @daylistMoods.
  ///
  /// In it, this message translates to:
  /// **'Umori'**
  String get daylistMoods;

  /// No description provided for @daylistShare.
  ///
  /// In it, this message translates to:
  /// **'Quota di suggeriti online'**
  String get daylistShare;

  /// No description provided for @daylistShareFrom.
  ///
  /// In it, this message translates to:
  /// **'Suggeriti da YouTube Music'**
  String get daylistShareFrom;

  /// No description provided for @daylistShareSlider.
  ///
  /// In it, this message translates to:
  /// **'Quota di suggeriti, percento'**
  String get daylistShareSlider;

  /// No description provided for @daylistShareOwn.
  ///
  /// In it, this message translates to:
  /// **'0% solo miei'**
  String get daylistShareOwn;

  /// No description provided for @daylistShareSplit.
  ///
  /// In it, this message translates to:
  /// **'{own} brani miei + {suggested} suggeriti'**
  String daylistShareSplit(Object own, Object suggested);

  /// No description provided for @daylistResetSlot.
  ///
  /// In it, this message translates to:
  /// **'Riporta questa fascia ai valori di serie'**
  String get daylistResetSlot;

  /// No description provided for @daylistMoodHelp.
  ///
  /// In it, this message translates to:
  /// **'Gli umori di ogni genere. Servono a scegliere i brani delle fasce con un certo umore.'**
  String get daylistMoodHelp;

  /// No description provided for @daylistGenreSearch.
  ///
  /// In it, this message translates to:
  /// **'Cerca un genere'**
  String get daylistGenreSearch;

  /// No description provided for @daylistGenreCount.
  ///
  /// In it, this message translates to:
  /// **'{n} di {total} generi'**
  String daylistGenreCount(Object n, Object total);

  /// No description provided for @daylistNoMood.
  ///
  /// In it, this message translates to:
  /// **'nessun umore'**
  String get daylistNoMood;

  /// No description provided for @daylistMoodCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 umore} other{{count} umori}}'**
  String daylistMoodCount(num count);

  /// No description provided for @daylistNoGenre.
  ///
  /// In it, this message translates to:
  /// **'Nessun genere con «{query}». I generi nuovi della libreria compaiono qui senza umore.'**
  String daylistNoGenre(Object query);

  /// No description provided for @daylistGenreMoodLabel.
  ///
  /// In it, this message translates to:
  /// **'{genre}, {mood}'**
  String daylistGenreMoodLabel(Object genre, Object mood);

  /// No description provided for @romanization.
  ///
  /// In it, this message translates to:
  /// **'Traslitterazione'**
  String get romanization;

  /// No description provided for @romanizationEdit.
  ///
  /// In it, this message translates to:
  /// **'Modifica traslitterazione'**
  String get romanizationEdit;

  /// No description provided for @romanizationDelete.
  ///
  /// In it, this message translates to:
  /// **'Elimina traslitterazione'**
  String get romanizationDelete;

  /// No description provided for @romanizationDeleted.
  ///
  /// In it, this message translates to:
  /// **'Traslitterazione eliminata'**
  String get romanizationDeleted;

  /// No description provided for @romanizationDeleteFailed.
  ///
  /// In it, this message translates to:
  /// **'Impossibile eliminare la traslitterazione'**
  String get romanizationDeleteFailed;

  /// No description provided for @romanizationSaveFailed.
  ///
  /// In it, this message translates to:
  /// **'Impossibile salvare la traslitterazione'**
  String get romanizationSaveFailed;

  /// No description provided for @romanizationEditorTitle.
  ///
  /// In it, this message translates to:
  /// **'Traslitterazione del testo'**
  String get romanizationEditorTitle;

  /// No description provided for @romanizationEditorLabel.
  ///
  /// In it, this message translates to:
  /// **'Una riga per ogni riga del testo'**
  String get romanizationEditorLabel;

  /// No description provided for @romanizationEditorHint.
  ///
  /// In it, this message translates to:
  /// **'Scrivi la traslitterazione, una riga per ogni riga del testo.'**
  String get romanizationEditorHint;

  /// No description provided for @romanizationEditorInfo.
  ///
  /// In it, this message translates to:
  /// **'Le righe seguono l’ordine del testo; lascia vuota una riga senza traslitterazione. Quella scritta qui ha la precedenza su quella trovata.'**
  String get romanizationEditorInfo;

  /// No description provided for @romanizationEmptyWarn.
  ///
  /// In it, this message translates to:
  /// **'Niente da salvare'**
  String get romanizationEmptyWarn;

  /// No description provided for @romanizationSaveA11y.
  ///
  /// In it, this message translates to:
  /// **'Salva la traslitterazione'**
  String get romanizationSaveA11y;

  /// No description provided for @romanizationSaved.
  ///
  /// In it, this message translates to:
  /// **'Traslitterazione salvata'**
  String get romanizationSaved;

  /// No description provided for @romanizationUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Traslitterazione non disponibile per questo testo'**
  String get romanizationUnavailable;

  /// No description provided for @romanizationDownloading.
  ///
  /// In it, this message translates to:
  /// **'Scarico il dizionario cinese…'**
  String get romanizationDownloading;

  /// No description provided for @chineseDictionary.
  ///
  /// In it, this message translates to:
  /// **'Dizionario cinese'**
  String get chineseDictionary;

  /// No description provided for @chineseDictionaryHint.
  ///
  /// In it, this message translates to:
  /// **'Serve per la traslitterazione dei testi cinesi quando non se ne trova una online.'**
  String get chineseDictionaryHint;

  /// No description provided for @chineseDictionaryNone.
  ///
  /// In it, this message translates to:
  /// **'Non scaricato'**
  String get chineseDictionaryNone;

  /// No description provided for @chineseDictionaryDownload.
  ///
  /// In it, this message translates to:
  /// **'Scarica'**
  String get chineseDictionaryDownload;

  /// No description provided for @chineseDictionaryDownloading.
  ///
  /// In it, this message translates to:
  /// **'Scarico…'**
  String get chineseDictionaryDownloading;

  /// No description provided for @chineseDictionaryError.
  ///
  /// In it, this message translates to:
  /// **'Download non riuscito'**
  String get chineseDictionaryError;

  /// No description provided for @chineseDictionaryDelete.
  ///
  /// In it, this message translates to:
  /// **'Elimina il dizionario cinese'**
  String get chineseDictionaryDelete;

  /// No description provided for @chineseDictionaryDeleteTitle.
  ///
  /// In it, this message translates to:
  /// **'Eliminare il dizionario cinese?'**
  String get chineseDictionaryDeleteTitle;

  /// No description provided for @chineseDictionaryDeleteBody.
  ///
  /// In it, this message translates to:
  /// **'Si può scaricare di nuovo da qui.'**
  String get chineseDictionaryDeleteBody;

  /// No description provided for @aboutCedictBody.
  ///
  /// In it, this message translates to:
  /// **'CC-CEDICT, dizionario cinese di MDBG usato per la traslitterazione. Licenza CC BY-SA 4.0: https://creativecommons.org/licenses/by-sa/4.0/ Fonte: https://www.mdbg.net/chinese/dictionary?page=cedict'**
  String get aboutCedictBody;

  /// No description provided for @chineseDictionaryDeleteFailed.
  ///
  /// In it, this message translates to:
  /// **'Impossibile eliminare il dizionario cinese'**
  String get chineseDictionaryDeleteFailed;

  /// No description provided for @editorDiscardBody.
  ///
  /// In it, this message translates to:
  /// **'Le modifiche non sono state salvate.'**
  String get editorDiscardBody;

  /// No description provided for @queueUpNext.
  ///
  /// In it, this message translates to:
  /// **'Prossimi in coda'**
  String get queueUpNext;

  /// No description provided for @queueThen.
  ///
  /// In it, this message translates to:
  /// **'Poi'**
  String get queueThen;

  /// No description provided for @downloadedNoPlaylist.
  ///
  /// In it, this message translates to:
  /// **'Scaricati senza playlist'**
  String get downloadedNoPlaylist;

  /// No description provided for @downloadedNoPlaylistEmpty.
  ///
  /// In it, this message translates to:
  /// **'Tutti i brani scaricati stanno già in una playlist'**
  String get downloadedNoPlaylistEmpty;

  /// No description provided for @pauseOnZeroVolume.
  ///
  /// In it, this message translates to:
  /// **'Metti in pausa quando il volume è a zero'**
  String get pauseOnZeroVolume;

  /// No description provided for @extMatching.
  ///
  /// In it, this message translates to:
  /// **'in abbinamento'**
  String get extMatching;

  /// No description provided for @extFindByHand.
  ///
  /// In it, this message translates to:
  /// **'Cerca a mano'**
  String get extFindByHand;

  /// No description provided for @extNotFoundLabel.
  ///
  /// In it, this message translates to:
  /// **'non trovato, cerca a mano'**
  String get extNotFoundLabel;

  /// No description provided for @extDownloadAll.
  ///
  /// In it, this message translates to:
  /// **'Scarica tutto'**
  String get extDownloadAll;

  /// No description provided for @extNotPublic.
  ///
  /// In it, this message translates to:
  /// **'Questa playlist non è pubblica o non esiste'**
  String get extNotPublic;

  /// No description provided for @extUnreadable.
  ///
  /// In it, this message translates to:
  /// **'Non riesco a leggere questa playlist (la pagina è cambiata)'**
  String get extUnreadable;

  /// No description provided for @extExportifyFull.
  ///
  /// In it, this message translates to:
  /// **'Importa la playlist completa con Exportify'**
  String get extExportifyFull;

  /// No description provided for @extTruncated.
  ///
  /// In it, this message translates to:
  /// **'Mostro i primi {count} brani.'**
  String extTruncated(int count);

  /// No description provided for @pauseOnZeroVolumeHelp.
  ///
  /// In it, this message translates to:
  /// **'Alzando di nuovo il volume la musica riparte da sola, solo se l’ha fermata questa funzione.'**
  String get pauseOnZeroVolumeHelp;

  /// Count at the end of the queue's «Poi» / «Prossimi» header while shuffle is on.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 brano, Casuale} other{{count} brani, Casuale}}'**
  String queueCountShuffle(int count);

  /// Spoken for a row of the queue block: its place among the entries added by the user.
  ///
  /// In it, this message translates to:
  /// **'Posizione {n} di {total}'**
  String queueBlockPosition(int n, int total);

  /// Name of the drag handle of a queue row, for TalkBack.
  ///
  /// In it, this message translates to:
  /// **'Trascina per riordinare'**
  String get queueReorderHandle;

  /// Number of rows a search in a list found.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, one{1 risultato} other{{count} risultati}}'**
  String resultsCount(int count);

  /// No description provided for @extSaveToLibrary.
  ///
  /// In it, this message translates to:
  /// **'Salva in Libreria'**
  String get extSaveToLibrary;

  /// No description provided for @extSavedAs.
  ///
  /// In it, this message translates to:
  /// **'Salvata come «{name}»'**
  String extSavedAs(String name);

  /// No description provided for @extSaveNothing.
  ///
  /// In it, this message translates to:
  /// **'Nessun brano pronto da salvare'**
  String get extSaveNothing;

  /// No description provided for @extRefresh.
  ///
  /// In it, this message translates to:
  /// **'Aggiorna'**
  String get extRefresh;

  /// No description provided for @shazamAutoDownload.
  ///
  /// In it, this message translates to:
  /// **'Scarica i brani da Shazam'**
  String get shazamAutoDownload;

  /// No description provided for @shazamAutoDownloadHint.
  ///
  /// In it, this message translates to:
  /// **'Ogni brano aggiunto a «Da Shazam» si scarica anche.'**
  String get shazamAutoDownloadHint;

  /// Snackbar of a song shared from Shazam.
  ///
  /// In it, this message translates to:
  /// **'Aggiunto a Da Shazam: {title}'**
  String shazamAdded(String title);

  /// Snackbar of a song shared from Shazam.
  ///
  /// In it, this message translates to:
  /// **'Già in Da Shazam: {title}'**
  String shazamDuplicate(String title);

  /// Snackbar of a song shared from Shazam.
  ///
  /// In it, this message translates to:
  /// **'Non trovato su YouTube Music: {title}'**
  String shazamNotFound(String title);

  /// No description provided for @shazamOffline.
  ///
  /// In it, this message translates to:
  /// **'Nessuna connessione: il brano di Shazam non è stato aggiunto.'**
  String get shazamOffline;

  /// No description provided for @ytErrInternal.
  ///
  /// In it, this message translates to:
  /// **'Errore interno dell’app (non di YouTube): riavvia l’app e riprova'**
  String get ytErrInternal;

  /// No description provided for @activityYtDlp.
  ///
  /// In it, this message translates to:
  /// **'Scarico yt-dlp'**
  String get activityYtDlp;

  /// No description provided for @ytDlpMissingBanner.
  ///
  /// In it, this message translates to:
  /// **'Manca yt-dlp: serve per cercare e scaricare online'**
  String get ytDlpMissingBanner;

  /// No description provided for @csvImportNoPortal.
  ///
  /// In it, this message translates to:
  /// **'Il selettore file non risponde: installa xdg-desktop-portal-gtk (o xdg-desktop-portal-kde) e riavvia la sessione'**
  String get csvImportNoPortal;

  /// No description provided for @logPlayFailed.
  ///
  /// In it, this message translates to:
  /// **'Riproduzione non riuscita'**
  String get logPlayFailed;

  /// No description provided for @logPlayFailedSub.
  ///
  /// In it, this message translates to:
  /// **'{title}: {reason}'**
  String logPlayFailedSub(String title, String reason);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'it',
    'pt',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
