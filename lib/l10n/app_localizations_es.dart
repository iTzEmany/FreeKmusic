// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Codecore';

  @override
  String get chooseFolder => 'Elegir carpeta';

  @override
  String get scan => 'Escanear';

  @override
  String get noTracks => 'Sin canciones. Elige una carpeta y escanea.';

  @override
  String get openSettings => 'Abrir ajustes';

  @override
  String get permissionDenied => 'Permiso de lectura de audio denegado';

  @override
  String get permissionExplain =>
      'Codecore necesita permiso para leer archivos de audio y mostrar tu música.';

  @override
  String get navLibrary => 'Biblioteca';

  @override
  String get navFavorites => 'Favoritos';

  @override
  String get navPlaylists => 'Listas';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get tracks => 'Canciones';

  @override
  String get albums => 'Álbumes';

  @override
  String get artists => 'Artistas';

  @override
  String get searchHint => 'Buscar';

  @override
  String get clearSearch => 'Borrar búsqueda';

  @override
  String get sortBy => 'Ordenar por';

  @override
  String get addMusicFolder => 'Añade tu carpeta de música';

  @override
  String get addFolder => 'Añadir carpeta';

  @override
  String get folders => 'Carpetas de música';

  @override
  String get refreshLibrary => 'Actualizar biblioteca';

  @override
  String get removeFolder => 'Quitar carpeta';

  @override
  String get unknownArtist => 'Artista desconocido';

  @override
  String get unknownAlbum => 'Álbum desconocido';

  @override
  String get variousArtists => 'Varios artistas';

  @override
  String get play => 'Reproducir';

  @override
  String get shuffle => 'Aleatorio';

  @override
  String get queue => 'Cola';

  @override
  String get nowPlaying => 'Reproduciendo';

  @override
  String get nothingPlaying => 'Nada en reproducción';

  @override
  String get mute => 'Silenciar';

  @override
  String get scanning => 'Escaneando…';

  @override
  String get emptyQueue => 'La cola está vacía';

  @override
  String get noResults => 'Sin resultados';

  @override
  String get sortDefault => 'Predeterminado';

  @override
  String get sortPersonal => 'Orden personal';

  @override
  String get sortTitle => 'Título';

  @override
  String get sortArtist => 'Artista';

  @override
  String get sortAlbum => 'Álbum';

  @override
  String get sortYear => 'Año';

  @override
  String get sortAdded => 'Añadidos recientemente';

  @override
  String get sortDuration => 'Duración';

  @override
  String tracksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones',
      one: '1 canción',
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
      other: '$countString álbumes',
      one: '1 álbum',
    );
    return '$_temp0';
  }

  @override
  String get libraryAll => 'Todo';

  @override
  String libraryItemsCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString elementos',
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
      other: '$countString listas',
      one: '1 lista',
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
      other: '$countString artistas',
      one: '1 artista',
    );
    return '$_temp0';
  }

  @override
  String minutesWords(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n minutos',
      one: '1 minuto',
    );
    return '$_temp0';
  }

  @override
  String hoursWords(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n horas',
      one: '1 hora',
    );
    return '$_temp0';
  }

  @override
  String hoursAndMinutes(String hours, String minutes) {
    return '$hours y $minutes';
  }

  @override
  String get collectionNoTracks => 'Ninguna canción';

  @override
  String missingTracksCount(int count) {
    return 'Canciones no encontradas ($count)';
  }

  @override
  String get addedToFavorites => 'Añadido a favoritos';

  @override
  String get removedFromFavorites => 'Quitado de favoritos';

  @override
  String get undo => 'Deshacer';

  @override
  String get favoritesEmptyTitle => 'Aún no hay favoritos';

  @override
  String get favoritesEmptyHelp =>
      'Toca el corazón en una canción y aparecerá aquí.';

  @override
  String get openAllTracks => 'Abrir todas las canciones';

  @override
  String get newPlaylist => 'Nueva lista';

  @override
  String get newPlaylistEllipsis => 'Nueva lista…';

  @override
  String get playlistName => 'Nombre de la lista';

  @override
  String get create => 'Crear';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get delete => 'Eliminar';

  @override
  String get rename => 'Renombrar';

  @override
  String get noPlaylists => 'Sin listas. Crea una.';

  @override
  String get addToPlaylist => 'Añadir a lista…';

  @override
  String addedToPlaylist(String name) {
    return 'Añadido a «$name»';
  }

  @override
  String get playNext => 'Reproducir después';

  @override
  String get addToQueue => 'Añadir a la cola';

  @override
  String get addedToQueue => 'Añadido a la cola';

  @override
  String get favorite => 'Favorito';

  @override
  String get removeFromFavorites => 'Quitar de favoritos';

  @override
  String get removeFromList => 'Quitar';

  @override
  String get editInfo => 'Editar info';

  @override
  String get details => 'Detalles';

  @override
  String get showInFolder => 'Mostrar en carpeta';

  @override
  String get detailPath => 'Ruta';

  @override
  String get detailFormat => 'Formato';

  @override
  String get detailSize => 'Tamaño';

  @override
  String get detailDuration => 'Duración';

  @override
  String get detailAdded => 'Añadido el';

  @override
  String get detailPlays => 'Reproducciones';

  @override
  String get close => 'Cerrar';

  @override
  String get fieldTitle => 'Título';

  @override
  String get fieldArtist => 'Artista';

  @override
  String get fieldAlbum => 'Álbum';

  @override
  String get fieldAlbumArtist => 'Artista del álbum';

  @override
  String get fieldYear => 'Año';

  @override
  String get fieldTrackNumber => 'Número de pista';

  @override
  String get fieldGenre => 'Género';

  @override
  String get restoreFromFile => 'Restaurar desde etiquetas del archivo';

  @override
  String get titleRequired => 'El título no puede estar vacío';

  @override
  String get settingsAppearance => 'Apariencia';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get themeNotte => 'Noche violeta';

  @override
  String get themeOled => 'Negro puro';

  @override
  String get settingsTextSize => 'Tamaño del texto';

  @override
  String get textSmall => 'Pequeño';

  @override
  String get textNormal => 'Normal';

  @override
  String get textLarge => 'Grande';

  @override
  String get settingsCompact => 'Modo compacto';

  @override
  String get settingsReducedMotion => 'Reducir animaciones';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsLibrary => 'Biblioteca';

  @override
  String get rescanNow => 'Reescanear ahora';

  @override
  String get clearCoverCache => 'Vaciar caché de carátulas';

  @override
  String get coverCacheCleared => 'Caché de carátulas vaciada';

  @override
  String get settingsOnline => 'En línea';

  @override
  String get settingsPageAppearance => 'Apariencia e idioma';

  @override
  String get settingsPagePlayback => 'Reproducción';

  @override
  String get settingsPageLibrary => 'Biblioteca';

  @override
  String get settingsPageOnline => 'En línea y descargas';

  @override
  String get settingsPageNetwork => 'Red y dispositivos';

  @override
  String get settingsPageBackup => 'Copia de seguridad';

  @override
  String get settingsPageAdvanced => 'Avanzado e información';

  @override
  String summaryLibrary(int folders, int tracks) {
    String _temp0 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: '$folders carpetas',
      one: '1 carpeta',
    );
    String _temp1 = intl.Intl.pluralLogic(
      tracks,
      locale: localeName,
      other: '$tracks canciones',
      one: '1 canción',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String summaryTrusted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dispositivos de confianza',
      one: '1 dispositivo de confianza',
    );
    return '$_temp0';
  }

  @override
  String get summaryNormalizeOn => 'normalización activada';

  @override
  String get summaryBackup => 'Exporta y restaura la biblioteca';

  @override
  String summaryCrossfade(int seconds) {
    return '$seconds s';
  }

  @override
  String get openPlaybackSettings => 'Abrir Reproducción';

  @override
  String get autoEnrich => 'Enriquecimiento automático';

  @override
  String get autoEnrichHint =>
      'Busca metadatos y carátulas en línea para canciones nuevas';

  @override
  String get autoLyrics => 'Letras automáticas';

  @override
  String get autoLyricsHint =>
      'Descarga letras de LRCLIB para canciones nuevas';

  @override
  String get settingsAbout => 'Acerca de';

  @override
  String appVersion(String version) {
    return 'Versión $version';
  }

  @override
  String get licenses => 'Licencias';

  @override
  String get personalUse => 'App de uso personal';

  @override
  String get missingTracksTitle => 'Canciones no encontradas';

  @override
  String get removeFromLibrary => 'Quitar de la biblioteca';

  @override
  String get ignore => 'Ignorar';

  @override
  String get confirmRemoveTitle => '¿Quitar de la biblioteca?';

  @override
  String get confirmRemoveBody =>
      'El archivo no se toca; pierdes favoritos y listas de esta canción.';

  @override
  String get noMissingTracks => 'Sin canciones perdidas';

  @override
  String get retry => 'Reintentar';

  @override
  String scanFailed(String error) {
    return 'Error al escanear: $error';
  }

  @override
  String playbackError(String reason, String title) {
    return 'No se puede reproducir «$title»: $reason';
  }

  @override
  String get reasonFileMissing => 'archivo no encontrado';

  @override
  String get reasonUnplayable => 'archivo no reproducible';

  @override
  String get reasonNotInLibrary => 'canción no está en la biblioteca';

  @override
  String get reasonOnlineUnavailable => 'canción en línea no disponible';

  @override
  String get reasonAgeRestricted =>
      'restringido por edad, no se encontró pista de audio';

  @override
  String get searchWeb => 'Buscar info en la web';

  @override
  String get enrichPreviewTitle => 'Vista previa de información';

  @override
  String get currentValue => 'Actual';

  @override
  String get proposedValue => 'Propuesto';

  @override
  String get apply => 'Aplicar';

  @override
  String get nothingFound => 'No se encontró nada';

  @override
  String get userEditedLocked => 'Editado por ti: no se sobrescribirá';

  @override
  String get fieldCover => 'Carátula';

  @override
  String get fieldLyrics => 'Letra';

  @override
  String get fieldCuriosity => 'Curiosidades';

  @override
  String get enrichAlbum => 'Enriquecer álbum';

  @override
  String get enrichLibrary => 'Enriquecer toda la biblioteca';

  @override
  String enrichRunning(int done, int total) {
    return 'Enriqueciendo $done/$total';
  }

  @override
  String enrichResult(int notFound, int updated) {
    return '$updated actualizados, $notFound no encontrados';
  }

  @override
  String get enrichBusy => 'Ya hay un enriquecimiento en curso';

  @override
  String get enrichNothingToDo =>
      'Nada que completar: a ninguna canción le falta nada';

  @override
  String get serviceUnavailable =>
      'Servicio no disponible, inténtalo más tarde';

  @override
  String get lyrics => 'Letra';

  @override
  String get searchLyrics => 'Buscar letra';

  @override
  String get noLyrics => 'Sin letra disponible';

  @override
  String get lyricsNotFound => 'Letra no encontrada';

  @override
  String get copy => 'Copiar';

  @override
  String get copied => 'Copiado';

  @override
  String get sourceWikipedia => 'Fuente: Wikipedia (CC BY-SA)';

  @override
  String get youtube => 'YouTube';

  @override
  String get ytHint => 'Busca o pega un enlace';

  @override
  String get ytDownload => 'Descargar';

  @override
  String get listenAction => 'Escuchar';

  @override
  String get ytAlreadyInLibrary => 'Ya en la biblioteca';

  @override
  String get ytNoResults => 'Sin resultados';

  @override
  String get ytQueued => 'En cola';

  @override
  String get ytDownloading => 'Descargando';

  @override
  String get ytDone => 'Completado';

  @override
  String get ytFailed => 'Fallido';

  @override
  String get ytCancelled => 'Cancelado';

  @override
  String get ytClearCompleted => 'Vaciar completados';

  @override
  String get ytCancel => 'Cancelar descarga';

  @override
  String get ytErrUnavailable => 'Vídeo no disponible (edad/región/privado)';

  @override
  String get ytErrNetwork => 'Red no disponible';

  @override
  String get ytErrChanged =>
      'YouTube cambió algo: actualiza la app o el paquete';

  @override
  String get ytNoFolder => 'Añade primero una carpeta de música';

  @override
  String get ytLegal =>
      'Solo para uso personal. Respeta los derechos de autor y los términos de YouTube.';

  @override
  String get useDefaultFolder => 'Usar la carpeta Música del dispositivo';

  @override
  String get ytErrToolMissing =>
      'yt-dlp no encontrado: instálalo (pip install -U yt-dlp) y reintenta';

  @override
  String get ytErrRateLimited =>
      'YouTube pide ir más despacio: inténtalo de nuevo en unos minutos';

  @override
  String get playlistChangeCover => 'Cambiar carátula';

  @override
  String get playlistRemoveCover => 'Quitar carátula';

  @override
  String get coverTooLarge => 'Imagen demasiado grande (máx. 4 MB)';

  @override
  String get addSongs => 'Añadir canciones';

  @override
  String addNSongs(int count) {
    return 'Añadir ($count)';
  }

  @override
  String get allSongsInPlaylist => 'Todas las canciones ya están en la lista';

  @override
  String get shareTitle => 'Compartir';

  @override
  String get shareSend => 'Enviar';

  @override
  String get shareReceive => 'Recibir';

  @override
  String get shareAll => 'Toda la biblioteca';

  @override
  String shareSelection(int count) {
    return 'Selección ($count canciones)';
  }

  @override
  String get sharePick => 'Elegir canciones';

  @override
  String get shareStart => 'Iniciar compartición';

  @override
  String get shareStop => 'Detener';

  @override
  String get shareActive => 'Compartición activa';

  @override
  String get shareAddress => 'Dirección (IP:puerto)';

  @override
  String get sharePin => 'PIN';

  @override
  String get shareConnect => 'Conectar';

  @override
  String shareDownloadSelected(int count) {
    return 'Descargar seleccionadas ($count)';
  }

  @override
  String shareProgress(int done, int total) {
    return 'Canción $done de $total';
  }

  @override
  String shareDone(int count) {
    return '$count canciones recibidas';
  }

  @override
  String shareConnectedTo(String name) {
    return 'Conectado a $name';
  }

  @override
  String get shareErrUnreachable =>
      'Dispositivo inaccesible: revisa la dirección y el Wi‑Fi';

  @override
  String get shareErrPin => 'PIN incorrecto';

  @override
  String get shareErrBlocked => 'Demasiados intentos: reintenta en un minuto';

  @override
  String get shareErrNotCodecore => 'No es un dispositivo Codecore';

  @override
  String get shareErrFailed => 'Transferencia fallida';

  @override
  String get shareNoNetwork => 'No se encontró red local';

  @override
  String get shareFirewall =>
      'Windows puede pedir permiso del firewall la primera vez.';

  @override
  String get shareHint =>
      'En la misma Wi‑Fi, abre «Recibir» en el otro dispositivo e introduce dirección y PIN.';

  @override
  String get shareMenu => 'Compartir…';

  @override
  String get shareDeviceName => 'Nombre del dispositivo';

  @override
  String get sleepTimer => 'Temporizador de apagado';

  @override
  String sleepMinutes(int count) {
    return '$count minutos';
  }

  @override
  String get sleepEndOfTrack => 'Al final de la canción';

  @override
  String get sleepCancel => 'Cancelar temporizador';

  @override
  String get pause => 'Pausa';

  @override
  String get nextTrack => 'Siguiente canción';

  @override
  String get previousTrack => 'Canción anterior';

  @override
  String get repeat => 'Repetir';

  @override
  String get moreOptions => 'Más opciones';

  @override
  String get back => 'Atrás';

  @override
  String get seekPosition => 'Posición en la canción';

  @override
  String get settingsPlayback => 'Reproducción';

  @override
  String get normalizeVolume => 'Normalizar volumen';

  @override
  String get normalizeVolumeHint =>
      'Usa el ReplayGain de los archivos para bajar canciones muy fuertes';

  @override
  String get nearbyDevices => 'Dispositivos cercanos';

  @override
  String get searchingDevices => 'Buscando dispositivos en la red…';

  @override
  String get noDevicesHint =>
      'No se encontró ningún dispositivo. Abre Compartir también en el otro dispositivo, en la misma red.';

  @override
  String sendToDevice(String name) {
    return 'Enviar a $name';
  }

  @override
  String offerSent(String name) {
    return 'Solicitud enviada a $name';
  }

  @override
  String get offerChooseFirst => 'Elige primero las canciones a enviar';

  @override
  String get sentRequests => 'Solicitudes enviadas';

  @override
  String get receivedRequests => 'Solicitudes recibidas';

  @override
  String get offerPending => 'Esperando respuesta';

  @override
  String get offerAccepted => 'Aceptada';

  @override
  String get offerDeclined => 'Rechazada';

  @override
  String get offerCancelled => 'Cancelada';

  @override
  String get offerExpired => 'Caducada';

  @override
  String get offerDone => 'Completada';

  @override
  String get offerFailed => 'Fallida';

  @override
  String incomingTitle(String name) {
    return '$name quiere enviarte canciones';
  }

  @override
  String incomingBody(int count, String size) {
    return '$count canciones, $size MB';
  }

  @override
  String get accept => 'Aceptar';

  @override
  String get decline => 'Rechazar';

  @override
  String receivingProgress(int done, int total) {
    return 'Recibiendo $done/$total';
  }

  @override
  String get manualConnection => 'Conexión manual (IP y PIN)';

  @override
  String get receiveFromLan => 'Recibir de la red local';

  @override
  String get receiveFromLanHint =>
      'Hace visible el dispositivo y recibe solicitudes también en segundo plano. En Android muestra una notificación fija para desactivarlo';

  @override
  String get receiveServiceTitle => 'Codecore es visible en la red';

  @override
  String get receiveServiceText =>
      'Listo para recibir canciones de dispositivos cercanos';

  @override
  String get receiveServiceDisable => 'Desactivar';

  @override
  String get jamTitle => 'Jam';

  @override
  String get jamStart => 'Iniciar una Jam';

  @override
  String jamStartWith(String name) {
    return 'Iniciar Jam con $name';
  }

  @override
  String jamWaiting(String name) {
    return 'Esperando a que $name acepte…';
  }

  @override
  String jamDeclined(String name) {
    return '$name rechazó la Jam';
  }

  @override
  String jamBusy(String name) {
    return '$name ya tiene una Jam en curso';
  }

  @override
  String get jamUnreachable => 'Dispositivo no accesible';

  @override
  String jamIncomingTitle(String name) {
    return '$name quiere iniciar una Jam';
  }

  @override
  String get jamIncomingBody => 'Escuchad juntos desde una cola compartida.';

  @override
  String get jamIncomingDialog =>
      'La música suena en este dispositivo y los dos podéis añadir canciones.';

  @override
  String get jamQueue => 'Cola compartida';

  @override
  String get jamModeHost => 'Cola del anfitrión';

  @override
  String get jamModeTogether => 'Cola conjunta';

  @override
  String get jamModeGuestHint => 'El anfitrión elige el modo de la cola';

  @override
  String get jamSuggested => 'Sugerido';

  @override
  String get jamEmpty =>
      'Pon canciones en cola desde la biblioteca o la búsqueda';

  @override
  String jamOnlineFailed(String title) {
    return 'No se pudo añadir «$title» a la Jam';
  }

  @override
  String jamAddedBy(String name) {
    return 'añadido por $name';
  }

  @override
  String get jamJumpHere => 'Saltar aquí';

  @override
  String get jamYou => 'ti';

  @override
  String get jamGuest => 'Invitado';

  @override
  String get jamAddToJam => 'Añadir a la Jam';

  @override
  String jamAdded(int count) {
    return 'Añadidas a la Jam: $count';
  }

  @override
  String get jamOutput => 'Salida de audio';

  @override
  String get jamOutputHere => 'Este dispositivo';

  @override
  String jamOutputOther(String name) {
    return '$name';
  }

  @override
  String get jamEnd => 'Terminar Jam';

  @override
  String get jamLeave => 'Salir de la Jam';

  @override
  String get jamEnded => 'La Jam ha terminado';

  @override
  String get jamLost => 'Conexión perdida';

  @override
  String get jamGuestCannotSkip => 'Solo el anfitrión puede cambiar de canción';

  @override
  String get jamRemoveForbidden => 'Solo puedes quitar tus canciones';

  @override
  String get jamNothingPlaying => 'Nada en reproducción';

  @override
  String jamWith(String name) {
    return 'Jam con $name';
  }

  @override
  String get jamUnavailable => 'No disponible';

  @override
  String get jamPlaying => 'La Jam está activa';

  @override
  String get jamOpen => 'Abrir Jam';

  @override
  String jamSynced(int ms) {
    return 'Sincronizado, desvío $ms ms';
  }

  @override
  String get jamSyncing => 'Sincronizando…';

  @override
  String jamLatency(int ms) {
    return 'Latencia de esta salida: $ms ms';
  }

  @override
  String get jamLatencyHint =>
      'Para auriculares o altavoces Bluetooth: súbela hasta que las salidas coincidan.';

  @override
  String get jamOutputsHint => 'Varias salidas suenan juntas';

  @override
  String get renamePlaylist => 'Renombrar lista';

  @override
  String get confirmDeletePlaylistTitle => '¿Eliminar la lista?';

  @override
  String confirmDeletePlaylistBody(String name) {
    return '«$name» se eliminará. Las canciones siguen en la biblioteca.';
  }

  @override
  String get confirmRemoveFolderTitle => '¿Quitar la carpeta?';

  @override
  String get confirmRemoveFolderBody =>
      'Sus canciones salen de la biblioteca. Los archivos siguen en el dispositivo.';

  @override
  String get confirmClearCoversTitle => '¿Vaciar la caché de carátulas?';

  @override
  String get confirmClearCoversBody =>
      'Las carátulas se recrean en el próximo escaneo.';

  @override
  String get confirmRestoreTitle =>
      '¿Restaurar desde las etiquetas del archivo?';

  @override
  String get confirmRestoreBody =>
      'Tus cambios en esta canción se sustituyen por los datos del archivo.';

  @override
  String get removedFromPlaylist => 'Quitada de la lista';

  @override
  String get removedFromQueue => 'Quitada de la cola';

  @override
  String get playNextDone => 'Sonará a continuación';

  @override
  String get ytSearchPrompt => 'Busca una canción o pega un enlace';

  @override
  String get loadFailed => 'No se pudieron cargar los datos.';

  @override
  String get artistLoadingSongs => 'Cargando canciones…';

  @override
  String get artistTopMissing => 'Top no disponible';

  @override
  String get navHome => 'Inicio';

  @override
  String get navSearch => 'Buscar';

  @override
  String get devicesTitle => 'Dispositivos';

  @override
  String get devicesJamActive => 'Jam activa';

  @override
  String jamPeople(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Jam, $n personas',
      one: 'Jam, 1 persona',
    );
    return '$_temp0';
  }

  @override
  String get devicesVisibleTitle => 'Hacer visible este dispositivo';

  @override
  String get devicesVisibleHint =>
      'Para recibir canciones o iniciar una Jam, los demás dispositivos deben verte en la red.';

  @override
  String get devicesJamShort => 'Jam';

  @override
  String get devicesSendShort => 'Enviar';

  @override
  String get devicesMore => 'Compartir y conexión manual';

  @override
  String jamParticipantsCount(int n) {
    return '$n personas';
  }

  @override
  String get playingFrom => 'Reproduciendo desde';

  @override
  String get playContextSearch => 'Búsqueda';

  @override
  String get allTracks => 'Todas las canciones';

  @override
  String get trackInfo => 'Información de la canción';

  @override
  String get searchCuriosity => 'Buscar curiosidades';

  @override
  String get upNext => 'A continuación';

  @override
  String get openQueue => 'Abrir cola';

  @override
  String get copyLink => 'Copiar enlace';

  @override
  String get moreActions => 'Más acciones';

  @override
  String get sleepChipEnd => 'fin de la canción';

  @override
  String get yourLibrary => 'Tu biblioteca';

  @override
  String playlistCountLabel(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Lista de $n canciones',
      one: 'Lista de 1 canción',
    );
    return '$_temp0';
  }

  @override
  String get sortRecent => 'Escuchados recientemente';

  @override
  String get sortAlphabetical => 'Alfabético';

  @override
  String get sortAToZ => 'A–Z';

  @override
  String get sortAddedRecently => 'Añadidos recientemente';

  @override
  String get sortTitleAToZ => 'Título A–Z';

  @override
  String get sortMostPlayed => 'Más escuchadas';

  @override
  String get sortTrackCount => 'Número de canciones';

  @override
  String get sortRecentShort => 'Recientes';

  @override
  String get sortAddedShort => 'Añadidos';

  @override
  String get sortTrackCountShort => 'Temas';

  @override
  String get sortMostPlayedShort => 'Más escuchadas';

  @override
  String get sortAscending => 'Ascendente';

  @override
  String get sortDescending => 'Descendente';

  @override
  String get viewAsGrid => 'Ver como cuadrícula';

  @override
  String get viewAsList => 'Ver como lista';

  @override
  String get kindAlbum => 'Álbum';

  @override
  String get kindArtist => 'Artista';

  @override
  String get kindPlaylist => 'Lista';

  @override
  String discN(int n) {
    return 'Disco $n';
  }

  @override
  String albumMeta(String details) {
    return 'Álbum, $details';
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
  String get mostPlayed => 'Más escuchadas';

  @override
  String get albumsSection => 'Álbumes';

  @override
  String get addAllToQueue => 'Añadir a la cola';

  @override
  String addedNToQueue(int n) {
    return '$n canciones añadidas a la cola';
  }

  @override
  String get editOrder => 'Editar orden';

  @override
  String get finishEditing => 'Listo';

  @override
  String get removeFromPlaylistAction => 'Quitar de la lista';

  @override
  String get noTracksInPlaylist => 'Esta lista está vacía';

  @override
  String get greetingMorning => 'Buenos días';

  @override
  String get greetingAfternoon => 'Buenas tardes';

  @override
  String get greetingEvening => 'Buenas noches';

  @override
  String get homeResume => 'Continuar';

  @override
  String get homeTopTracks => 'Más escuchadas';

  @override
  String get homeRediscover => 'Para redescubrir';

  @override
  String get homeShuffleAll => 'Aleatorio con todo';

  @override
  String homeShuffleAllSub(String tracks, String hours) {
    return '$tracks, $hours';
  }

  @override
  String hoursCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count horas',
      one: '1 hora',
      zero: 'menos de una hora',
    );
    return '$_temp0';
  }

  @override
  String get homeAddedLately => 'Añadidos hace poco';

  @override
  String homeResumeQueue(int n, int m) {
    return 'Canción $n de $m';
  }

  @override
  String homeResumeQueueFrom(String source, int n, int m) {
    return '$source: canción $n de $m';
  }

  @override
  String homeMinutesLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Faltan $count minutos',
      one: 'Falta 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String get homeFanOpen => 'Mostrar las canciones añadidas recientemente';

  @override
  String get showAll => 'Todos';

  @override
  String get recentSearches => 'Búsquedas recientes';

  @override
  String get genresTitle => 'Géneros';

  @override
  String downloadsChip(int n) {
    return 'Descargas ($n)';
  }

  @override
  String get gotIt => 'Entendido';

  @override
  String get searchEmptyLibrary => 'Sin resultados en la biblioteca';

  @override
  String get ytInfoTooltip => 'Información de uso';

  @override
  String removeRecentSearch(String query) {
    return 'Quitar «$query» de búsquedas recientes';
  }

  @override
  String get groupGoTo => 'Ir a';

  @override
  String get goToAlbum => 'Ir al álbum';

  @override
  String get goToArtist => 'Ir al artista';

  @override
  String get groupQueue => 'Cola';

  @override
  String get groupCollection => 'Colección';

  @override
  String get groupEdit => 'Editar';

  @override
  String get groupOther => 'Más';

  @override
  String get queueNowPlaying => 'Reproduciendo';

  @override
  String get queueNext => 'A continuación';

  @override
  String get queueClear => 'Vaciar';

  @override
  String get queueCleared => 'Cola vaciada';

  @override
  String get queueRebuilt =>
      'Cola recreada a partir de la lista en reproducción';

  @override
  String get jamOutputsAndSync => 'Salidas y sincronía';

  @override
  String get jamHostTag => 'anfitrión';

  @override
  String get jamSeekInvalid => 'Posición no válida para esta pista';

  @override
  String get jamEndConfirmTitle => '¿Terminar la Jam para todos?';

  @override
  String jamEndConfirmBody(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other:
          'Los $n invitados serán desconectados y la cola compartida se cerrará.',
      one: 'El invitado será desconectado y la cola compartida se cerrará.',
    );
    return '$_temp0';
  }

  @override
  String get jamEndConfirmAction => 'Terminar';

  @override
  String jamParticipantsLabel(int n, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n participantes: $names',
      one: '1 participante: $names',
    );
    return '$_temp0';
  }

  @override
  String get jamWaitingEmpty => 'No hay ninguna Jam en curso';

  @override
  String get activityTitle => 'Actividad';

  @override
  String activityScan(int done, int total) {
    return 'Escaneo: $done de $total';
  }

  @override
  String get activityScanIdle => 'Escaneando';

  @override
  String activityEnrich(int done, int total) {
    return 'Enriquecimiento: $done de $total';
  }

  @override
  String activityDownload(String title) {
    return 'Descarga, $title';
  }

  @override
  String activityTransfer(String name, int n) {
    return 'Envío a $name, $n canciones';
  }

  @override
  String get activityNone => 'Sin actividad';

  @override
  String get activityCompleted => 'Completadas';

  @override
  String get importPhaseSearching => 'Buscando…';

  @override
  String importPhaseDownloading(int percent) {
    return 'Descargando $percent %';
  }

  @override
  String importPhaseRetry(int seconds) {
    return 'Nuevo intento en $seconds s';
  }

  @override
  String get importPhaseEnriching => 'Enriqueciendo…';

  @override
  String get importPhaseDownloadStart => 'Descargando…';

  @override
  String get importFilterAll => 'Todos';

  @override
  String get importFilterActive => 'En curso';

  @override
  String get importFilterProblems => 'Por revisar';

  @override
  String get importFilterDone => 'Hechos';

  @override
  String get importRowsNone => 'Ninguna canción aquí';

  @override
  String get activityLog => 'Registro';

  @override
  String activityLogCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count eventos',
      one: '1 evento',
      zero: 'Vacío',
    );
    return '$_temp0';
  }

  @override
  String get activityLogEmpty =>
      'Nada todavía: aquí aparecen descargas, importaciones y envíos terminados.';

  @override
  String logImport(String name) {
    return 'Importación «$name»';
  }

  @override
  String importNotificationText(int done, int total) {
    return '$done de $total';
  }

  @override
  String importNotificationPaused(int done, int total) {
    return 'En pausa, $done de $total';
  }

  @override
  String importWaitRateLimited(String time) {
    return 'YouTube pide una pausa: sigo a las $time';
  }

  @override
  String importWaitNetwork(String time) {
    return 'Sin red: reintento a las $time';
  }

  @override
  String importPausedTitle(String name) {
    return 'Importación «$name» en pausa';
  }

  @override
  String get downloadsNotificationTitle => 'Descargas en curso';

  @override
  String downloadsNotificationText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones',
      one: '1 canción',
    );
    return '$_temp0';
  }

  @override
  String activityRunning(int n) {
    return '$n actividades en curso';
  }

  @override
  String get settingsLocalNetwork => 'Red local';

  @override
  String get removeAll => 'Quitar todas';

  @override
  String get confirmRemoveAllTitle => '¿Quitar todas de la biblioteca?';

  @override
  String confirmRemoveAllBody(int n) {
    return 'Se quitarán $n canciones no encontradas de la biblioteca. Los archivos no se tocan; pierdes favoritos y listas de estas canciones.';
  }

  @override
  String get csvImportMenu => 'Importar desde Exportify (CSV)';

  @override
  String get csvImportIntroTitle => 'Importar una lista';

  @override
  String get csvImportIntroSource =>
      'El archivo CSV se crea gratis en el sitio Exportify — exportify.net (no hace falta ninguna app).';

  @override
  String get csvImportStep1 =>
      'Abre https://exportify.net en el navegador (también desde el móvil).';

  @override
  String get csvImportStep2 =>
      'Toca «Get Started» e inicia sesión con tu cuenta de Spotify.';

  @override
  String get csvImportStep3 =>
      'Junto a la lista que quieras toca «Export»: se descarga un archivo .csv con el nombre de la lista.';

  @override
  String get csvImportStep4 => 'Vuelve aquí y toca «Elegir archivo CSV».';

  @override
  String get csvImportNote =>
      'Codecore busca las canciones en tu biblioteca y descarga las demás de YouTube Music.';

  @override
  String get csvImportNoteOffline =>
      'Solo se enlazarán las canciones que ya están en tu biblioteca.';

  @override
  String get csvImportCopy => 'Copiar dirección';

  @override
  String get csvImportCopied => 'Dirección copiada';

  @override
  String get csvImportPick => 'Elegir archivo';

  @override
  String get csvImportNotExportify =>
      'Formato no reconocido. Elige un CSV (Exportify, TuneMyMusic, Soundiiz, Last.fm) o una lista M3U/M3U8/XSPF.';

  @override
  String get csvImportReadFailed => 'No se pudo leer el archivo.';

  @override
  String get csvImportPreviewTitle => 'Importar lista';

  @override
  String get csvImportName => 'Nombre de la lista';

  @override
  String csvImportSummary(int total, int known, int todo) {
    return '$total canciones, $known ya en la biblioteca, $todo por descargar';
  }

  @override
  String csvImportSkipped(int n) {
    return '$n filas ignoradas (podcasts o archivos locales)';
  }

  @override
  String csvImportEstimate(int minutes) {
    return 'Tiempo estimado: unos $minutes min';
  }

  @override
  String get csvImportExists => 'Ya existe una lista con este nombre';

  @override
  String get csvImportUpdate =>
      'Actualizar la existente (solo añade las nuevas)';

  @override
  String get csvImportNew => 'Crear una lista nueva';

  @override
  String get csvImportGo => 'Importar';

  @override
  String get csvImportStarted =>
      'Importación iniciada: síguela en el Centro de actividad';

  @override
  String activityImport(String name, int done, int total) {
    return 'Importación «$name»: $done de $total';
  }

  @override
  String activityImportPaused(String name, int done, int total) {
    return 'Importación «$name»: en pausa, $done de $total';
  }

  @override
  String csvImportBanner(int done, int total, int review, int missing) {
    return 'Importación: $done de $total, $review por revisar, $missing no encontradas';
  }

  @override
  String csvImportBannerPaused(int done, int total, int review, int missing) {
    return 'Importación en pausa: $done de $total, $review por revisar, $missing no encontradas';
  }

  @override
  String get csvImportReview => 'Revisar';

  @override
  String get csvImportResume => 'Reanudar';

  @override
  String get csvImportPause => 'Pausar';

  @override
  String get csvImportCancelTitle => '¿Cancelar la importación?';

  @override
  String get csvImportCancelBody =>
      'Las canciones ya descargadas se quedan en la lista.';

  @override
  String csvImportDone(int added, int review, int missing) {
    return 'Importación terminada: $added añadidas, $review por revisar, $missing no encontradas';
  }

  @override
  String get csvImportFailing =>
      'Demasiados errores seguidos: importación en pausa';

  @override
  String get csvImportReviewTitle => 'Revisar';

  @override
  String get csvImportToReview => 'Por revisar';

  @override
  String get csvImportNotFound => 'No encontradas';

  @override
  String get csvImportErrors => 'Con errores';

  @override
  String get csvImportRetryAll => 'Reintentar todas';

  @override
  String get csvImportSkip => 'Omitir';

  @override
  String get csvImportManual => 'Buscar a mano';

  @override
  String get csvImportNothing => 'Nada que revisar.';

  @override
  String get csvImportSearch => 'Buscar';

  @override
  String csvImportWanted(String title, String artist, String duration) {
    return 'Buscada: $title, $artist, $duration';
  }

  @override
  String get csvImportDownload => 'Descargar';

  @override
  String get csvImportCancelGo => 'Cancelar importación';

  @override
  String get exportLog => 'Exportar registro';

  @override
  String get exportLogHint =>
      'Archivo de texto sin rutas personales, direcciones de red ni PIN';

  @override
  String get exportLogDebugOnly =>
      'Solo en la versión instalada (en depuración el registro no se escribe en un archivo)';

  @override
  String get exportLogNone => 'Todavía no hay ningún registro para exportar';

  @override
  String get exportLogSaved => 'Registro guardado';

  @override
  String get exportLogFailed => 'No se pudo guardar el registro';

  @override
  String get exportPlaylist => 'Exportar…';

  @override
  String get exportPlaylistTitle => 'Exportar lista';

  @override
  String get exportFormatM3u8 => 'M3U8, para otros reproductores';

  @override
  String get exportFormatCsv => 'CSV, como Exportify';

  @override
  String get exportFormatJson => 'JSON, formato Codecore';

  @override
  String get exportRelativePaths => 'Rutas relativas';

  @override
  String get exportRelativeHint =>
      'Relativas a la carpeta común de las canciones: guarda el archivo allí';

  @override
  String get exportAction => 'Exportar';

  @override
  String get exportSaved => 'Lista exportada';

  @override
  String get exportEmpty => 'La lista está vacía';

  @override
  String get exportFailed => 'No se pudo exportar la lista';

  @override
  String get ytErrToolOutdated =>
      'yt-dlp es demasiado antiguo: actualízalo (Ajustes, En línea y descargas, Actualizar) e inténtalo de nuevo';

  @override
  String ytDlpOutdatedBanner(String version) {
    return 'yt-dlp $version es demasiado antiguo: puede que las descargas no funcionen';
  }

  @override
  String get settingsDownloads => 'Descargas';

  @override
  String ytDlpVersion(String version) {
    return 'yt-dlp $version';
  }

  @override
  String get ytDlpUnknownVersion => 'yt-dlp no encontrado';

  @override
  String get ytDlpUpdate => 'Actualizar';

  @override
  String ytDlpUpdating(int percent) {
    return 'Actualizando… $percent%';
  }

  @override
  String ytDlpUpdated(String version) {
    return 'Actualizado a la versión $version';
  }

  @override
  String get ytDlpTooOld => 'Demasiado antiguo: toca Actualizar';

  @override
  String get ytDlpUpdateErrNetwork => 'Error al actualizar: red inaccesible';

  @override
  String get ytDlpUpdateErrHash =>
      'Actualización cancelada: el archivo descargado no pasó la comprobación de integridad';

  @override
  String get ytDlpUpdateErrOther =>
      'Error al actualizar (consulta el registro)';

  @override
  String get downloadParallel => 'Descargas simultáneas';

  @override
  String get downloadParallelHint =>
      'Más a la vez es más rápido, pero YouTube puede pedir que vayas más despacio';

  @override
  String get downloadRateLimit => 'Límite de velocidad';

  @override
  String get downloadRateNone => 'Sin límite';

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
    return 'Descarga, $title, nuevo intento en $seconds s ($attempt/$max)';
  }

  @override
  String get downloadFormat => 'Formato de descarga';

  @override
  String get downloadFormatOriginal => 'Original (máxima calidad)';

  @override
  String get downloadFormatOriginalHint =>
      'El audio de YouTube sin recodificar, normalmente Opus ~160 kbps. No todos los reproductores ni autorradios lo leen.';

  @override
  String get downloadFormatM4a => 'M4A (recomendado)';

  @override
  String get downloadFormatM4aHint =>
      'Casi como el original, sin recodificar: rápido, ligero (~1 MB/min), se reproduce en todas partes.';

  @override
  String get downloadFormatMp3High => 'MP3 320 kbps';

  @override
  String get downloadFormatMp3HighHint =>
      'Compatible con todo. Recodificado: ligera pérdida, archivos grandes (~2,4 MB/min), descarga más lenta.';

  @override
  String get downloadFormatMp3Low => 'MP3 192 kbps (calidad mínima)';

  @override
  String get downloadFormatMp3LowHint =>
      'Compatible con todo, la mitad de espacio que MP3 320 (~1,4 MB/min), pero la calidad más baja.';

  @override
  String get searchCacheClear => 'Vaciar caché de búsquedas';

  @override
  String searchCacheCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count búsquedas guardadas',
      one: '1 búsqueda guardada',
      zero: 'Vacía',
    );
    return '$_temp0';
  }

  @override
  String get searchCacheCleared => 'Caché vaciada';

  @override
  String csvImportLengthOff(String found, String wanted) {
    return 'Duración distinta: $found en lugar de $wanted';
  }

  @override
  String get csvImportKeep => 'Quedarme con este';

  @override
  String get csvImportTooBig =>
      'El archivo es demasiado grande para una lista (máximo 5 MB y 10.000 canciones)';

  @override
  String get csvImportAlsoAccepts =>
      'También se aceptan: TuneMyMusic, Soundiiz, Last.fm (CSV), M3U/M3U8, XSPF.';

  @override
  String get csvImportPlanned => 'Coincidencias listas: revísalas y descarga';

  @override
  String get csvImportLinkOnly => 'Solo enlazar (sin descargas)';

  @override
  String get csvImportLinkOnlyHint =>
      'Crea la lista con lo que ya tienes y nada más';

  @override
  String get csvImportPlanFirst => 'Revisar antes de descargar';

  @override
  String get csvImportPlanFirstHint =>
      'Busca todo y luego eliges qué descargar';

  @override
  String get csvImportPlanTitle => 'Coincidencias';

  @override
  String csvImportPlanGo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Descargar $n canciones',
      one: 'Descargar 1 canción',
    );
    return '$_temp0';
  }

  @override
  String get csvImportPlanKnown => 'ya descargada';

  @override
  String get csvImportPlanEmpty => 'Nada que descargar';

  @override
  String csvImportBannerPlanned(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n canciones por descargar',
      one: '1 canción por descargar',
    );
    return 'Coincidencias listas: $_temp0';
  }

  @override
  String get settingsAdvanced => 'Avanzado';

  @override
  String get importSureThreshold => 'Coincidencia segura desde';

  @override
  String get importSureThresholdHint =>
      'Por encima de esta puntuación una canción importada se descarga sin preguntar';

  @override
  String get importReviewThreshold => 'Por revisar desde';

  @override
  String get importReviewThresholdHint =>
      'Entre esta puntuación y la segura la canción va a «Por revisar»; por debajo, a «No encontradas»';

  @override
  String get importThresholdsReset => 'Restablecer valores predeterminados';

  @override
  String csvImportEstimateHours(int hours, int minutes) {
    return 'Tiempo estimado: unas $hours h $minutes min';
  }

  @override
  String csvImportBlocks(int size) {
    return 'Importar en bloques de $size';
  }

  @override
  String csvImportBigWarning(int n) {
    return '$n canciones por descargar: tardará horas. En bloques, uno tras otro, el orden de la lista se mantiene y puedes parar entre bloques.';
  }

  @override
  String get etaLessThanMinute => 'menos de 1 min';

  @override
  String etaMinutes(int minutes) {
    return 'unos $minutes min';
  }

  @override
  String etaHours(int hours, int minutes) {
    return 'unas $hours h $minutes min';
  }

  @override
  String get csvImportOwnFolder => 'Carpeta para esta lista';

  @override
  String get csvImportOwnFolderHint =>
      'Guarda las descargas en una subcarpeta con el nombre de la lista';

  @override
  String get csvImportNumberFiles => 'Numerar los archivos';

  @override
  String get csvImportNumberFilesHint =>
      '07 - Artista - Título: la carpeta suena en el orden correcto incluso fuera de Codecore';

  @override
  String get csvImportFetchCovers => 'Buscar carátulas';

  @override
  String get csvImportFetchCoversHint =>
      'Tras cada descarga busca la carátula del álbum en iTunes (álbum y artista del archivo)';

  @override
  String get csvImportExport => 'Exportar resultado';

  @override
  String get csvImportExported => 'Resultado guardado';

  @override
  String get csvOutHeaderRow => 'Fila';

  @override
  String get csvOutHeaderTitle => 'Título';

  @override
  String get csvOutHeaderArtists => 'Artistas';

  @override
  String get csvOutHeaderAlbum => 'Álbum';

  @override
  String get csvOutHeaderDuration => 'Duración (ms)';

  @override
  String get csvOutHeaderIsrc => 'ISRC';

  @override
  String get csvOutHeaderStatus => 'Resultado';

  @override
  String get csvOutHeaderNote => 'Motivo';

  @override
  String get csvOutHeaderVideo => 'Vídeo elegido';

  @override
  String get csvOutHeaderScore => 'Puntuación';

  @override
  String get importStatusPending => 'Por buscar';

  @override
  String get importStatusQueued => 'En cola';

  @override
  String get importStatusDownloaded => 'Descargada';

  @override
  String get importStatusLinked => 'Ya en la biblioteca';

  @override
  String get importStatusReview => 'Por revisar';

  @override
  String get importStatusNotFound => 'No encontrada';

  @override
  String get importStatusFailed => 'Error';

  @override
  String get importStatusSkipped => 'Omitida';

  @override
  String get importStatusPlanned => 'Planificada';

  @override
  String get importStatusRemoved => 'Quitada de la fuente';

  @override
  String get importNoteNoResults => 'Sin resultados';

  @override
  String get importNoteLowScore => 'Coincidencia poco segura';

  @override
  String get importNoteLinkOnly => 'Solo enlazar: no se buscó';

  @override
  String get importNoteYoutubeOff => 'Descargas desactivadas';

  @override
  String get importNoteDownloadFailed => 'Error al descargar';

  @override
  String get importNoteLengthOff => 'Duración distinta de la del archivo';

  @override
  String get importNoteUnchanged => 'Ya está en la lista';

  @override
  String get csvImportSync => 'Sincronizar';

  @override
  String csvImportSyncCounts(int added, int removed) {
    return '$added nuevas, $removed quitadas de la lista (los archivos se quedan)';
  }

  @override
  String get csvImportSyncChecking => 'Comprobando las diferencias…';

  @override
  String get playbackSpeed => 'Velocidad de reproducción';

  @override
  String get playbackSpeedHint =>
      'El tono se mantiene. El temporizador de apagado cuenta tiempo real, no el de la canción.';

  @override
  String resumeFrom(String time) {
    return 'continuar en $time';
  }

  @override
  String get restartFromBeginning => 'Empezar desde el principio';

  @override
  String get previewTrack => 'Vista previa de 20 s';

  @override
  String get equalizer => 'Ecualizador';

  @override
  String get eqOutputSpeaker => 'Altavoz';

  @override
  String get eqOutputHeadphones => 'Auriculares';

  @override
  String get eqHint =>
      'Cada salida recuerda su curva: cambia sola al conectar auriculares.';

  @override
  String get eqPresetFlat => 'Plano';

  @override
  String get eqPresetBass => 'Graves';

  @override
  String get eqPresetVoice => 'Voz';

  @override
  String get eqPresetTreble => 'Agudos';

  @override
  String get eqPresetCustom => 'Personalizado';

  @override
  String get eqReset => 'Restablecer';

  @override
  String get eqWaiting =>
      'Las bandas aparecen cuando empieza la primera canción.';

  @override
  String get eqUnavailable =>
      'El ecualizador no está disponible en este dispositivo.';

  @override
  String get transitionMode => 'Transición entre canciones';

  @override
  String get transitionNormal => 'Normal';

  @override
  String get transitionGapless => 'Sin pausas';

  @override
  String get transitionCrossfade => 'Fundido cruzado';

  @override
  String get transitionHint =>
      'Sin pausas funciona mejor con canciones del mismo formato (por ejemplo, todas en FLAC).';

  @override
  String crossfadeLength(int seconds) {
    return 'Duración del fundido: $seconds s';
  }

  @override
  String get crossfadePlainInAlbum => 'No fundir dentro de un álbum';

  @override
  String get crossfadePlainInAlbumHint =>
      'Dentro de un álbum las canciones se suceden sin pausas y sin solaparse.';

  @override
  String get selectedRow => 'Seleccionado';

  @override
  String selectedRowAt(int position) {
    return 'Seleccionado, número $position';
  }

  @override
  String get curiositySong => 'Sobre la canción';

  @override
  String get curiosityArtist => 'Sobre el artista';

  @override
  String get showMore => 'Mostrar más';

  @override
  String get showLess => 'Mostrar menos';

  @override
  String get curiosityNoSong => 'No hay página sobre esta canción';

  @override
  String get curiosityNoArtist => 'No hay página sobre el artista';

  @override
  String get themeNew => 'Nuevo tema';

  @override
  String get themeEdit => 'Editar';

  @override
  String get themeDuplicate => 'Duplicar';

  @override
  String get themeDelete => 'Eliminar';

  @override
  String get themeExport => 'Exportar';

  @override
  String get themeImport => 'Importar tema';

  @override
  String get themeName => 'Nombre del tema';

  @override
  String get themeBase => 'Partir de';

  @override
  String get themeModeSimple => 'Sencillo';

  @override
  String get themeModeAdvanced => 'Avanzado';

  @override
  String get themeSave => 'Guardar';

  @override
  String get themeEditorTitle => 'Tema personalizado';

  @override
  String get themeDiscardTitle => '¿Descartar los cambios?';

  @override
  String get themeDiscardBody => 'Los cambios de este tema no se han guardado.';

  @override
  String get themeDiscard => 'Descartar';

  @override
  String get smartDiscardBody =>
      'Los cambios de esta lista no se han guardado.';

  @override
  String get themePreview => 'Vista previa';

  @override
  String get themeResetColor => 'Restablecer el color';

  @override
  String get themeContrastTitle => 'Legibilidad';

  @override
  String get themeContrastLow => 'Difícil de leer';

  @override
  String get themeContrastOk => 'Legible';

  @override
  String get themeFix => 'Corregir';

  @override
  String get themeSaved => 'Tema guardado';

  @override
  String get themeLimit => 'Ya tienes 20 temas: elimina uno';

  @override
  String get themeImported => 'Tema importado';

  @override
  String get themeImportFailed => 'El archivo no es un tema válido';

  @override
  String get themeDeleted => 'Tema eliminado';

  @override
  String get themeMine => 'Mis temas';

  @override
  String get tokenBg => 'Fondo';

  @override
  String get tokenSurface1 => 'Superficie 1';

  @override
  String get tokenSurface2 => 'Superficie 2';

  @override
  String get tokenSurface3 => 'Superficie 3';

  @override
  String get tokenAccent => 'Acento';

  @override
  String get tokenAccentSoft => 'Acento suave';

  @override
  String get tokenOnAccent => 'Texto sobre el acento';

  @override
  String get tokenText => 'Texto';

  @override
  String get tokenTextMuted => 'Texto secundario';

  @override
  String get tokenTextFaint => 'Texto tenue';

  @override
  String get tokenHero => 'Fondo del reproductor';

  @override
  String get tokenError => 'Error';

  @override
  String get pickerHue => 'Tono';

  @override
  String get pickerSv => 'Saturación y brillo';

  @override
  String get pickerAlpha => 'Transparencia';

  @override
  String get pickerHex => 'Código de color';

  @override
  String get pickerInvalid => 'Código no válido';

  @override
  String get pickerRecent => 'Usados recientemente';

  @override
  String get contrastTextBg => 'Texto sobre fondo';

  @override
  String get contrastMutedSurface => 'Texto secundario sobre superficie';

  @override
  String get contrastOnAccent => 'Texto sobre el acento';

  @override
  String get contrastAccentBg => 'Acento sobre fondo';

  @override
  String get themeBackground => 'Fondo de las páginas';

  @override
  String get bgSolid => 'Color liso';

  @override
  String get bgGradient => 'Degradado';

  @override
  String get bgImage => 'Imagen';

  @override
  String get bgGradientEnd => 'Color final';

  @override
  String get bgAngle => 'Dirección';

  @override
  String get bgPickImage => 'Elegir imagen…';

  @override
  String get bgRemoveImage => 'Quitar la imagen';

  @override
  String get bgDim => 'Oscurecimiento';

  @override
  String get bgBlur => 'Desenfoque';

  @override
  String get bgCoverBackdrop => 'Reproduciendo: tono de la carátula';

  @override
  String get blurredChrome => 'Dock y cabeceras desenfocados';

  @override
  String get blurredChromeHint =>
      'Puede ralentizar los teléfonos menos potentes';

  @override
  String get bgImageFailed => 'No se pudo usar la imagen';

  @override
  String themeCopyName(String name) {
    return '$name (copia)';
  }

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seleccionadas',
      one: '1 seleccionada',
    );
    return '$_temp0';
  }

  @override
  String get selectAll => 'Seleccionar todo';

  @override
  String get exitSelection => 'Salir de la selección';

  @override
  String get bulkActions => 'Acciones';

  @override
  String playNextMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones sonarán a continuación',
      one: '1 canción sonará a continuación',
    );
    return '$_temp0';
  }

  @override
  String addedToQueueMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones añadidas a la cola',
      one: '1 canción añadida a la cola',
    );
    return '$_temp0';
  }

  @override
  String addedToPlaylistMany(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones añadidas a «$name»',
      one: '1 canción añadida a «$name»',
    );
    return '$_temp0';
  }

  @override
  String addedToPlaylistSkipped(int added, int skipped, String name) {
    return '$added añadidas a «$name», $skipped ya estaban';
  }

  @override
  String allAlreadyInPlaylist(String name) {
    return 'Ya estaban todas en «$name»';
  }

  @override
  String favoritesAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones añadidas a favoritos',
      one: '1 canción añadida a favoritos',
    );
    return '$_temp0';
  }

  @override
  String favoritesRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones quitadas de favoritos',
      one: '1 canción quitada de favoritos',
    );
    return '$_temp0';
  }

  @override
  String get bulkAddToFavorites => 'Añadir a favoritos';

  @override
  String get bulkRemoveFromFavorites => 'Quitar de favoritos';

  @override
  String removeManyFromPlaylistTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '¿Quitar $count canciones de la lista?',
      one: '¿Quitar 1 canción de la lista?',
    );
    return '$_temp0';
  }

  @override
  String get removeManyFromPlaylistBody =>
      'Los archivos y la biblioteca no se tocan.';

  @override
  String removedManyFromPlaylist(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones quitadas',
      one: '1 canción quitada',
    );
    return '$_temp0';
  }

  @override
  String removeManyFromLibraryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '¿Quitar $count canciones de la biblioteca?',
      one: '¿Quitar 1 canción de la biblioteca?',
    );
    return '$_temp0';
  }

  @override
  String get removeManyFromLibraryBody =>
      'Los archivos ya no existen: solo desaparecen de la biblioteca (pierdes los favoritos y las listas de estas canciones).';

  @override
  String removedManyFromLibrary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones quitadas de la biblioteca',
      one: '1 canción quitada de la biblioteca',
    );
    return '$_temp0';
  }

  @override
  String ytDownloadsStarted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count descargas iniciadas',
      one: '1 descarga iniciada',
    );
    return '$_temp0';
  }

  @override
  String ytDownloadsSkipped(int started, int skipped) {
    return '$started descargas iniciadas, $skipped ya en la biblioteca o en curso';
  }

  @override
  String get ytNothingToDownload =>
      'Ya están todos en la biblioteca o en curso';

  @override
  String get themeChiaro => 'Claro';

  @override
  String get settingsAccent => 'Color de acento';

  @override
  String get accentViola => 'Violeta';

  @override
  String get accentBlu => 'Azul';

  @override
  String get accentAcqua => 'Turquesa';

  @override
  String get accentVerde => 'Verde';

  @override
  String get accentAmbra => 'Ámbar';

  @override
  String get accentArancio => 'Naranja';

  @override
  String get accentRosa => 'Rosa';

  @override
  String get accentRosso => 'Rojo';

  @override
  String get onboardingSkip => 'Omitir';

  @override
  String get onboardingNext => 'Siguiente';

  @override
  String get onboardingStart => 'Empezar';

  @override
  String onboardingPageOf(int page, int total) {
    return 'Página $page de $total';
  }

  @override
  String onboardingStepOf(int page, int total) {
    return '$page de $total';
  }

  @override
  String get onboardingWelcomeTitle => 'Te damos la bienvenida a Codecore';

  @override
  String get onboardingWelcomeBody =>
      'Tu reproductor de música personal: sin cuenta y sin servidor. Tu música se queda en tu dispositivo.';

  @override
  String get onboardingFoldersTitle => 'Tu música';

  @override
  String get onboardingFoldersBody =>
      'Elige las carpetas donde guardas tus canciones. Codecore solo las lee: no las modifica ni las mueve.';

  @override
  String onboardingFoldersAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count carpetas añadidas',
      one: '1 carpeta añadida',
    );
    return '$_temp0';
  }

  @override
  String get onboardingAllowAccess =>
      'Permitir el acceso a los archivos de audio';

  @override
  String get onboardingAccessGranted => 'Acceso permitido';

  @override
  String get onboardingOnlineTitle => 'Funciones en línea';

  @override
  String get onboardingOnlineBody =>
      'Están desactivadas: Codecore nunca se conecta a Internet por su cuenta. Puedes activarlas ahora o más tarde en Ajustes.';

  @override
  String get onboardingShareTitle => 'Descargas, Jam y compartir';

  @override
  String get onboardingYoutubeBody =>
      'Puedes descargar canciones de YouTube en tu dispositivo y escucharlas como el resto de tu música.';

  @override
  String get onboardingJamBody =>
      'Con una Jam escuchas la misma música junto con otro dispositivo de la misma red.';

  @override
  String get onboardingSendBody =>
      'Puedes enviar canciones a otros dispositivos cercanos con un PIN, sin pasar por Internet.';

  @override
  String get historyTitle => 'Historial';

  @override
  String get historySubtitle => 'Lo que has escuchado';

  @override
  String get historyToday => 'Hoy';

  @override
  String get historyYesterday => 'Ayer';

  @override
  String get historyEmpty => 'Aquí aparecerá lo que escuches.';

  @override
  String get historyOff =>
      'El historial está desactivado: actívalo en Ajustes, Reproducción.';

  @override
  String get historyClear => 'Borrar historial';

  @override
  String get historyClearTitle => '¿Borrar el historial?';

  @override
  String get historyClearBody =>
      'Solo se borra la lista de reproducciones: los contadores, los favoritos y las listas se quedan como están.';

  @override
  String get historyCleared => 'Historial borrado';

  @override
  String get settingsRecordHistory => 'Guardar el historial de escucha';

  @override
  String get settingsRecordHistoryHint =>
      'Se queda en el dispositivo. Si se apaga, no se añade nada más a la lista.';

  @override
  String get statsTitle => 'Estadísticas';

  @override
  String get statsSubtitle => 'Cuánto y qué escuchas';

  @override
  String get statsMonth => 'Mes';

  @override
  String get statsYear => 'Año';

  @override
  String get statsPrevious => 'Periodo anterior';

  @override
  String get statsNext => 'Periodo siguiente';

  @override
  String get statsEmpty => 'No hay reproducciones en este periodo.';

  @override
  String statsPlays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reproducciones',
      one: '1 reproducción',
    );
    return '$_temp0';
  }

  @override
  String statsDistinct(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones distintas',
      one: '1 canción distinta',
    );
    return '$_temp0';
  }

  @override
  String statsHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get statsTopTracks => 'Canciones más escuchadas';

  @override
  String get statsTopArtists => 'Artistas más escuchados';

  @override
  String get statsTopAlbums => 'Álbumes más escuchados';

  @override
  String get statsFavouriteHour => 'Hora favorita';

  @override
  String get statsFirstListen => 'Primera reproducción';

  @override
  String statsFirstValue(String title, String date) {
    return '$title, $date';
  }

  @override
  String get statsYourMonth => 'Tu mes';

  @override
  String ruleWarning(String term) {
    return 'No entiendo «$term»: lo busco como texto.';
  }

  @override
  String get smartPlaylistNew => 'Nueva lista inteligente';

  @override
  String get smartPlaylistEdit => 'Editar lista inteligente';

  @override
  String get smartPlaylistLabel => 'Lista inteligente';

  @override
  String get smartName => 'Nombre';

  @override
  String get smartNameRequired => 'Escribe un nombre';

  @override
  String get smartNoRules =>
      'Sin reglas, la lista contiene toda la biblioteca.';

  @override
  String get smartSortBy => 'Ordenar por';

  @override
  String get smartSortMostPlayed => 'Más escuchadas';

  @override
  String get smartSortRandom => 'Al azar';

  @override
  String get smartTemplates => 'Plantillas';

  @override
  String get smartTplNever => 'Nunca escuchadas';

  @override
  String get smartTplRecent => 'Añadidas recientemente';

  @override
  String get smartTplTop => 'Las más escuchadas';

  @override
  String get smartTpl90s => 'Los años 90';

  @override
  String get smartConvert => 'Convertir en lista normal';

  @override
  String smartConverted(String name) {
    return 'Creada la lista «$name» con la lista actual';
  }

  @override
  String smartDeleteTitle(String name) {
    return '¿Eliminar «$name»?';
  }

  @override
  String get smartDeleteBody =>
      'Solo se elimina la regla: las canciones se quedan donde están.';

  @override
  String get smartAutoNote => 'La lista se actualiza sola.';

  @override
  String get tagsTitle => 'Etiquetas';

  @override
  String get tagsSubtitle => 'Tus propias etiquetas';

  @override
  String tagsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count etiquetas',
      one: '1 etiqueta',
    );
    return '$_temp0';
  }

  @override
  String get tagsEllipsis => 'Etiquetas…';

  @override
  String get tagNew => 'Nueva etiqueta';

  @override
  String get tagRename => 'Renombrar etiqueta';

  @override
  String get tagColor => 'Color';

  @override
  String get tagNoColor => 'Sin color';

  @override
  String get tagNameTaken => 'Ya existe una etiqueta con ese nombre';

  @override
  String tagDeleteTitle(String name) {
    return '¿Eliminar la etiqueta «$name»?';
  }

  @override
  String get tagDeleteBody =>
      'Solo se quita la etiqueta de las canciones: siguen en la biblioteca.';

  @override
  String get tagsEmpty =>
      'Aún no hay etiquetas: crea una desde el menú de una canción.';

  @override
  String get tagAddToSelection => 'Añadir etiqueta…';

  @override
  String get tagRemoveFromSelection => 'Quitar etiqueta…';

  @override
  String tagAssigned(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones etiquetadas «$name»',
      one: '1 canción etiquetada «$name»',
    );
    return '$_temp0';
  }

  @override
  String tagUnassigned(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '«$name» quitada de $count canciones',
      one: '«$name» quitada de 1 canción',
    );
    return '$_temp0';
  }

  @override
  String get tagNoneToRemove => 'Las canciones elegidas no tienen etiquetas.';

  @override
  String get cleanupSection => 'Limpieza de la biblioteca';

  @override
  String get duplicatesTitle => 'Duplicados';

  @override
  String get duplicatesTileHint =>
      'La misma canción en varias copias o calidades';

  @override
  String get duplicatesIntro =>
      'Busca la misma canción en varias copias: el mismo archivo en dos carpetas o la misma canción en dos calidades. Antes de unir ves una vista previa. Favoritos, listas, reproducciones, letras y etiquetas pasan a la canción que conservas; las demás solo se ocultan y puedes recuperarlas desde «Canciones ocultas». Ningún archivo se borra sin una doble confirmación.';

  @override
  String get duplicatesSearch => 'Buscar duplicados';

  @override
  String get duplicatesSearchAgain => 'Buscar de nuevo';

  @override
  String get duplicatesReading => 'Leyendo la biblioteca…';

  @override
  String duplicatesHashing(int done, int total) {
    return 'Comprobando archivos: $done de $total';
  }

  @override
  String get duplicatesGrouping => 'Comparando canciones…';

  @override
  String get duplicatesFailed => 'La búsqueda ha fallado. Inténtalo de nuevo.';

  @override
  String get duplicatesNone => 'No se han encontrado duplicados';

  @override
  String duplicatesSummary(int groups, int hidden) {
    String _temp0 = intl.Intl.pluralLogic(
      groups,
      locale: localeName,
      other: '$groups grupos',
      one: '1 grupo',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hidden,
      locale: localeName,
      other: '$hidden canciones por ocultar',
      one: '1 canción por ocultar',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get duplicatesExactBadge => 'Idénticos';

  @override
  String get duplicatesProbableBadge => 'Probables';

  @override
  String get duplicatesKeepLabel => 'Conservar';

  @override
  String get duplicatesPickKeep => 'Toca una canción para conservarla';

  @override
  String get duplicatesMerge => 'Unir';

  @override
  String get duplicatesNotDuplicates => 'No son duplicados';

  @override
  String duplicatesMergeAllExact(int count) {
    return 'Unir todos los idénticos ($count)';
  }

  @override
  String get duplicatesMergeAllTitle => '¿Unir todos los idénticos?';

  @override
  String duplicatesMergeAllBody(int groups, int hidden) {
    String _temp0 = intl.Intl.pluralLogic(
      groups,
      locale: localeName,
      other: '$groups grupos',
      one: '1 grupo',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hidden,
      locale: localeName,
      other: '$hidden canciones ocultas',
      one: '1 canción oculta',
    );
    return '$_temp0, $_temp1. Favoritos, listas, reproducciones y letras pasan a las canciones que se quedan.';
  }

  @override
  String duplicatesMerged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones ocultas',
      one: '1 canción oculta',
    );
    return 'Unido: $_temp0';
  }

  @override
  String duplicatesDeleteFiles(int count, String size) {
    return 'Eliminar también los archivos ($count, $size)';
  }

  @override
  String get duplicatesDeleteListTitle => '¿Eliminar estos archivos?';

  @override
  String get duplicatesDeleteListBody =>
      'Se borrarán del dispositivo y no se pueden recuperar. Las canciones que conservas se quedan donde están.';

  @override
  String get duplicatesDeleteContinue => 'Continuar';

  @override
  String duplicatesDeleteFinalTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '¿Eliminar definitivamente $count archivos?',
      one: '¿Eliminar definitivamente 1 archivo?',
    );
    return '$_temp0';
  }

  @override
  String duplicatesDeleteFinalBody(String size) {
    return 'Espacio liberado: $size. Esta acción no se puede deshacer.';
  }

  @override
  String get duplicatesDeleteGo => 'Eliminar definitivamente';

  @override
  String get duplicatesDeleteDoneTitle => 'Hecho';

  @override
  String duplicatesDeleteDone(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos eliminados',
      one: '1 archivo eliminado',
    );
    return '$_temp0 ($size).';
  }

  @override
  String duplicatesDeleteFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos no eliminados:',
      one: '1 archivo no eliminado:',
    );
    return '$_temp0';
  }

  @override
  String duplicatesDeleteSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count archivos sin tocar: son el mismo archivo que la canción conservada.',
      one:
          '1 archivo sin tocar: es el mismo archivo que la canción conservada.',
    );
    return '$_temp0';
  }

  @override
  String get duplicatesDeleteAndroidHint =>
      'En Android solo se pueden eliminar archivos de las carpetas a las que la app tiene acceso.';

  @override
  String activityCleanup(int done, int total) {
    return 'Buscando duplicados: $done de $total';
  }

  @override
  String get hiddenTracksTitle => 'Canciones ocultas';

  @override
  String hiddenTracksCount(int count) {
    return 'Canciones ocultas ($count)';
  }

  @override
  String get hiddenTracksEmpty => 'No hay canciones ocultas';

  @override
  String get hiddenTracksHint =>
      'Los duplicados unidos no aparecen en la biblioteca. «Restaurar» los devuelve a su sitio.';

  @override
  String get hiddenRestore => 'Restaurar';

  @override
  String hiddenRestored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones restauradas',
      one: '1 canción restaurada',
    );
    return '$_temp0';
  }

  @override
  String get albumMergeWith => 'Unir con…';

  @override
  String get albumMergeTitle => 'Unir álbumes';

  @override
  String albumMergeIntro(String name) {
    return 'Elige los álbumes que se unirán a «$name». Las canciones pasan a un solo álbum con el título y el artista que indiques; la portada sigue siendo la de «$name».';
  }

  @override
  String get albumMergeSearch => 'Buscar un álbum';

  @override
  String get albumMergeNone => 'No hay otros álbumes';

  @override
  String get albumFieldTitle => 'Título del álbum';

  @override
  String get albumFieldArtist => 'Artista del álbum';

  @override
  String get albumMergeAction => 'Unir álbumes';

  @override
  String albumMerged(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count álbumes unidos en «$name»',
      one: '1 álbum unido en «$name»',
    );
    return '$_temp0';
  }

  @override
  String get moveToAlbum => 'Mover a un álbum nuevo…';

  @override
  String get moveToAlbumTitle => 'Mover a un álbum';

  @override
  String moveToAlbumBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones irán',
      one: '1 canción irá',
    );
    return '$_temp0 al álbum indicado. Si ya existe, se unirán a él.';
  }

  @override
  String get moveToAlbumGo => 'Mover';

  @override
  String movedToAlbum(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones movidas a «$name»',
      one: '1 canción movida a «$name»',
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
  String get playlistSourceTitle => 'Lista o canal de YouTube';

  @override
  String get playlistSourceLoading => 'Leyendo la lista de vídeos…';

  @override
  String get playlistSourceName => 'Nombre de la lista';

  @override
  String playlistSourceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vídeos',
      one: '1 vídeo',
    );
    return '$_temp0';
  }

  @override
  String playlistSourceUnavailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vídeos no disponibles (privados o eliminados)',
      one: '1 vídeo no disponible (privado o eliminado)',
    );
    return '$_temp0';
  }

  @override
  String playlistSourceTruncated(int count) {
    return 'Se muestran los primeros $count vídeos.';
  }

  @override
  String playlistSourceLong(int count, String time) {
    return 'Son $count vídeos: tardará $time.';
  }

  @override
  String get playlistSourceNone => 'Ninguno';

  @override
  String get playlistSourceEmpty => 'Aquí no hay vídeos para descargar.';

  @override
  String playlistSourceGo(int count) {
    return 'Descargar en una lista ($count)';
  }

  @override
  String playlistSourceStarted(String name) {
    return 'Descargas iniciadas en la lista «$name»';
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
      'Los podcasts solo se actualizan cuando tú lo pides.';

  @override
  String get podcastsEmpty => 'No estás suscrito a ningún podcast.';

  @override
  String get podcastAdd => 'Añadir un podcast';

  @override
  String get podcastRefreshAll => 'Actualizar todos';

  @override
  String get podcastRefresh => 'Actualizar';

  @override
  String podcastRefreshed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count episodios nuevos',
      one: '1 episodio nuevo',
      zero: 'Ningún episodio nuevo',
    );
    return '$_temp0';
  }

  @override
  String podcastRefreshFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count podcasts sin actualizar',
      one: '1 podcast sin actualizar',
    );
    return '$_temp0';
  }

  @override
  String get podcastFeedUrl => 'Dirección del feed';

  @override
  String get podcastSubscribe => 'Suscribirse';

  @override
  String get podcastSearchHint => 'Busca un podcast por nombre';

  @override
  String get podcastSearchNone => 'No se ha encontrado ningún podcast';

  @override
  String podcastSubscribed(String name) {
    return 'Suscrito a «$name»';
  }

  @override
  String podcastEpisodesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count episodios',
      one: '1 episodio',
    );
    return '$_temp0';
  }

  @override
  String podcastToListen(int count) {
    return '$count por escuchar';
  }

  @override
  String get podcastNoEpisodes => 'Ningún episodio.';

  @override
  String get podcastStateDownloaded => 'Descargado';

  @override
  String podcastStateDownloading(int percent) {
    return 'Descargando… $percent %';
  }

  @override
  String get podcastStateHeard => 'Escuchado';

  @override
  String podcastStateRemaining(String time) {
    return 'Faltan $time';
  }

  @override
  String get podcastMarkHeard => 'Marcar como escuchado';

  @override
  String get podcastMarkNotHeard => 'Marcar como no escuchado';

  @override
  String get podcastDeleteFile => 'Eliminar el archivo';

  @override
  String get podcastAutoDelete => 'Eliminar los episodios escuchados';

  @override
  String get podcastAutoDeleteNever => 'Nunca';

  @override
  String podcastAutoDeleteAfter(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days días',
      one: '1 día',
    );
    return '$_temp0';
  }

  @override
  String get podcastUnsubscribe => 'Cancelar la suscripción';

  @override
  String get podcastUnsubscribeTitle => '¿Cancelar la suscripción?';

  @override
  String podcastUnsubscribeBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'El podcast y $count episodios descargados se eliminarán del dispositivo.',
      one: 'El podcast y 1 episodio descargado se eliminarán del dispositivo.',
      zero: 'El podcast se eliminará del dispositivo.',
    );
    return '$_temp0';
  }

  @override
  String podcastLastChecked(String when) {
    return 'Actualizado $when';
  }

  @override
  String get podcastNeverChecked => 'Nunca actualizado';

  @override
  String get podcastErrInvalidUrl => 'Eso no parece una dirección web válida.';

  @override
  String get podcastErrTooLarge => 'El feed es demasiado grande.';

  @override
  String get podcastErrNetwork => 'No se puede llegar al servidor.';

  @override
  String get podcastErrNotFeed => 'Esa dirección no es un feed de podcast.';

  @override
  String get podcastErrUnsupportedFormat => 'Formato de audio no compatible.';

  @override
  String get syncTitle => 'Sincronizar listas';

  @override
  String syncAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nuevas',
      one: '1 nueva',
    );
    return '$_temp0';
  }

  @override
  String syncUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count actualizadas',
      one: '1 actualizada',
    );
    return '$_temp0';
  }

  @override
  String syncMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones que faltan',
      one: '1 canción que falta',
    );
    return '$_temp0';
  }

  @override
  String get syncUpToDate => 'Las listas ya están sincronizadas';

  @override
  String syncKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count listas son más recientes aquí y se quedan como están',
      one: '1 lista es más reciente aquí y se queda como está',
    );
    return '$_temp0';
  }

  @override
  String get syncReplaceNote =>
      'Las listas actualizadas sustituyen a las de este dispositivo.';

  @override
  String get syncTagNew => 'Nueva';

  @override
  String get syncTagUpdated => 'Actualizada';

  @override
  String get syncDetailRenamed => 'renombrada';

  @override
  String get syncDetailReordered => 'reordenada';

  @override
  String syncDetailRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones quitadas',
      one: '1 canción quitada',
    );
    return '$_temp0';
  }

  @override
  String get syncAskMissing => 'Pedir las canciones que faltan';

  @override
  String syncApplied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count listas sincronizadas',
      one: '1 lista sincronizada',
    );
    return '$_temp0';
  }

  @override
  String get trustedSection => 'Dispositivos de confianza';

  @override
  String trustedFingerprint(String fingerprint) {
    return 'Huella $fingerprint';
  }

  @override
  String trustedPairedOn(String date) {
    return 'Emparejado el $date';
  }

  @override
  String get trustedAutoAccept => 'Aceptar automáticamente';

  @override
  String get trustedAutoAcceptHint =>
      'Recibe canciones de este dispositivo sin preguntar.';

  @override
  String get trustedRevoke => 'Revocar';

  @override
  String trustedRevokeTitle(String name) {
    return '¿Revocar «$name»?';
  }

  @override
  String get trustedRevokeBody =>
      'Para enviar de nuevo sin PIN tendréis que emparejaros otra vez.';

  @override
  String get carMode => 'Modo coche';

  @override
  String get carExit => 'Salir';

  @override
  String get carKeepAwake => 'Pantalla siempre encendida';

  @override
  String get carPlaylists => 'Listas';

  @override
  String get carNothing => 'Nada en reproducción';

  @override
  String get updateCheck => 'Buscar actualizaciones';

  @override
  String get updateCheckHint =>
      'Pregunta a GitHub por la última versión, solo cuando lo pides.';

  @override
  String get updateOnStart => 'Comprobar al iniciar';

  @override
  String get updateOnStartHint =>
      'Como máximo una vez al día. No descarga ni instala nada.';

  @override
  String get updateChecking => 'Comprobando…';

  @override
  String updateAvailable(String version) {
    return 'Hay una versión $version disponible';
  }

  @override
  String updateUpToDate(String version) {
    return 'Tienes la última versión ($version)';
  }

  @override
  String get updateRateLimited => 'GitHub pide esperar: inténtalo más tarde.';

  @override
  String get updateFailed =>
      'No puedo leer la última versión. Revisa la conexión.';

  @override
  String get updateCopyLink => 'Copiar dirección';

  @override
  String get updateLinkCopied => 'Dirección copiada';

  @override
  String get backupSection => 'Copia de seguridad';

  @override
  String get backupCreate => 'Crear copia';

  @override
  String get backupCreateHint =>
      'Listas, favoritos, letras y ediciones en un zip. Sin música.';

  @override
  String get backupRestore => 'Restaurar desde copia';

  @override
  String get backupRestoreHint =>
      'Sustituye esta biblioteca o une los datos de otro dispositivo.';

  @override
  String get backupCreating => 'Creando la copia…';

  @override
  String get backupSaved => 'Copia guardada';

  @override
  String get backupFailed => 'La copia ha fallado';

  @override
  String get restoreTitle => 'Restaurar desde copia';

  @override
  String restoreInfo(String date, String version, int tracks, int playlists) {
    return 'Del $date, app $version, $tracks canciones, $playlists listas';
  }

  @override
  String get restoreReplace => 'Sustituir todo (mismo dispositivo)';

  @override
  String get restoreMerge => 'Unir a esta biblioteca';

  @override
  String get restoreMergeHint =>
      'Añade favoritos, listas, letras y ediciones a las canciones que encuentra. No borra nada.';

  @override
  String get restoreReplaceConfirmTitle => '¿Sustituir toda la biblioteca?';

  @override
  String get restoreReplaceConfirmBody =>
      'En el próximo inicio los datos de esta app serán los de la copia. Los actuales quedan en una copia de seguridad junto a la base de datos.';

  @override
  String get restoreReplaceGo => 'Sustituir';

  @override
  String get restoreNotBackup =>
      'Este archivo no es una copia de Codecore que pueda leer.';

  @override
  String get restoreRestartNeeded =>
      'Listo: cierra la app y ábrela de nuevo para terminar la restauración.';

  @override
  String restoreMergeDone(
    int recognized,
    int missing,
    int playlists,
    int favorites,
  ) {
    return 'Unión hecha: $recognized canciones reconocidas, $missing no encontradas, $playlists listas creadas, $favorites favoritos añadidos.';
  }

  @override
  String get restoreNotFound => 'Canciones no encontradas';

  @override
  String get restoreCopyList => 'Copiar lista';

  @override
  String get restoreFailed => 'La restauración ha fallado';

  @override
  String get exportAllPlaylists => 'Exportar todas las listas';

  @override
  String get shareErrIdentity =>
      'La identidad de este dispositivo ha cambiado: quítalo de los de confianza y empareja de nuevo.';

  @override
  String get incomingTrustedTag => 'Dispositivo de confianza';

  @override
  String incomingTrustedTitle(String name) {
    return '$name (de confianza)';
  }

  @override
  String get pairAction => 'Emparejar';

  @override
  String get trustedBadge => 'De confianza';

  @override
  String pairPinTitle(String name) {
    return 'Emparejar con $name';
  }

  @override
  String pairPinHint(String name) {
    return 'Escribe el PIN de 6 cifras que aparece en $name.';
  }

  @override
  String pairPinWrong(int count) {
    return 'PIN incorrecto. Intentos restantes: $count.';
  }

  @override
  String pairFingerprint(String fingerprint) {
    return 'Huella: $fingerprint';
  }

  @override
  String get pairCompare =>
      'Comprueba que la huella sea la misma en la otra pantalla.';

  @override
  String pairRequestTitle(String name) {
    return '$name quiere emparejarse';
  }

  @override
  String get pairRequestBody =>
      'Escribe este PIN en el otro dispositivo y toca Confirmar.';

  @override
  String get pairConfirm => 'Confirmar';

  @override
  String get pairWaiting => 'Esperando la confirmación en el otro dispositivo…';

  @override
  String pairDone(String name) {
    return 'Emparejado con $name';
  }

  @override
  String get pairBlocked =>
      'Demasiados intentos fallidos: inténtalo más tarde.';

  @override
  String get pairRejected => 'Emparejamiento rechazado.';

  @override
  String get pairExpired => 'La solicitud caducó: inténtalo de nuevo.';

  @override
  String get pairFailed => 'El emparejamiento ha fallado.';

  @override
  String get syncDevice => 'Sincronizar listas';

  @override
  String get syncUnreachable =>
      'El dispositivo no está visible en la red local.';

  @override
  String get syncFailed => 'La sincronización ha fallado.';

  @override
  String syncAsked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Solicitud enviada: $count canciones en camino',
      one: 'Solicitud enviada: 1 canción en camino',
      zero: 'Ninguna de las canciones está en el otro dispositivo',
    );
    return '$_temp0';
  }

  @override
  String get translateLyrics => 'Traducir';

  @override
  String get translateLyricsFrom => 'Idioma de la letra';

  @override
  String get translateLyricsHint =>
      'Se traduce en el teléfono, no se envía ningún texto por la red.';

  @override
  String get translateRemove => 'Mostrar solo el original';

  @override
  String translateDownloadTitle(String language) {
    return '¿Descargar el modelo $language?';
  }

  @override
  String translateDownloadBody(int mb) {
    return 'Unos $mb MB por idioma, mejor con Wi-Fi. Se descarga una sola vez y luego funciona también sin conexión.';
  }

  @override
  String get translateDownload => 'Descargar';

  @override
  String translateDownloading(String language) {
    return 'Descargando el modelo $language…';
  }

  @override
  String get translateDownloadFailed =>
      'Modelo no descargado. Revisa la conexión y el espacio.';

  @override
  String get translateFailed => 'No se pudo traducir.';

  @override
  String get translateSameLanguage => 'La letra ya está en este idioma.';

  @override
  String get translationModels => 'Modelos de traducción';

  @override
  String get translationModelsNone =>
      'Ningún modelo descargado. Se descargan desde la pantalla de letras, con «Traducir».';

  @override
  String translationModelDelete(String language) {
    return 'Eliminar el modelo $language';
  }

  @override
  String get scanCode => 'Escanear código';

  @override
  String get scanTitle => 'Apunta al código QR';

  @override
  String get scanNotCodecore => 'Este código no es de Codecore.';

  @override
  String get scanCameraDenied =>
      'Hace falta el permiso de la cámara para leer el código.';

  @override
  String get scanOpenSettings => 'Abrir ajustes';

  @override
  String get ownFingerprint => 'Huella de este dispositivo';

  @override
  String get ownFingerprintHint =>
      'Compárala con la que aparece en la otra pantalla al emparejar.';

  @override
  String get writeTagsToFiles => 'Escribir los cambios en los archivos';

  @override
  String get writeTagsToFilesHint =>
      'El título, artista, álbum, año, género y pista editados aquí se escriben también en archivos MP3, FLAC, M4A y OGG. Se conserva el original de cada archivo. Desactivado de serie.';

  @override
  String get writeTagsAfterDownload =>
      'Escribir las etiquetas en los archivos descargados';

  @override
  String get writeTagsAfterDownloadHint =>
      'Solo en los archivos que Codecore ha descargado o recibido. El ISRC se queda en la app.';

  @override
  String get writeTagsWarnTitle => '¿Escribir los cambios en los archivos?';

  @override
  String get writeTagsWarnBody =>
      'Al guardar un cambio, las etiquetas se reescriben también en el archivo de música (MP3, FLAC, M4A, OGG). Se trabaja sobre una copia, se comprueba el resultado y el archivo se sustituye solo si todo coincide; antes el original se guarda en «Copias de etiquetas» (las últimas 200 o 2 GB). La carátula, las letras y el ReplayGain no se tocan. Antes de activarlo conviene hacer una copia de seguridad de la biblioteca (Ajustes, Copia de seguridad).';

  @override
  String get writeTagsEnable => 'Activar';

  @override
  String get tagsAlsoInFile => 'Escribir también en el archivo';

  @override
  String tagsNoWriteUnsupported(String format) {
    return 'Formato no modificable ($format): solo cambia la biblioteca';
  }

  @override
  String get tagsNoWriteReadOnly =>
      'Archivo de solo lectura: solo cambia la biblioteca';

  @override
  String get tagsNoWriteMissing =>
      'Archivo no encontrado: solo cambia la biblioteca';

  @override
  String tagsFileWriteFailed(int count, String reason) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos no se modificaron',
      one: '1 archivo no se modificó',
    );
    return 'Guardado en la biblioteca, pero $_temp0: $reason';
  }

  @override
  String get tagReasonUnsupported => 'formato no admitido';

  @override
  String get tagReasonNotFound => 'archivo no encontrado';

  @override
  String get tagReasonReadOnly => 'archivo de solo lectura';

  @override
  String get tagReasonVerifyFailed =>
      'falló la comprobación tras escribir, el archivo quedó como estaba';

  @override
  String get tagReasonWriteFailed =>
      'falló la escritura, el archivo quedó como estaba';

  @override
  String get tagReasonBackupFailed =>
      'no se pudo copiar el original, el archivo quedó como estaba';

  @override
  String get tagReasonIoError => 'error de disco o de permisos';

  @override
  String get tagBackupsTitle => 'Copias de etiquetas';

  @override
  String tagBackupsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Copias de etiquetas ($count)',
      one: 'Copias de etiquetas (1)',
      zero: 'Copias de etiquetas',
    );
    return '$_temp0';
  }

  @override
  String get tagBackupsHint =>
      'El original de cada archivo reescrito, antes del cambio. Se guardan los últimos 200 o 2 GB.';

  @override
  String get tagBackupsEmpty =>
      'Sin copias: aún no se ha reescrito ningún archivo.';

  @override
  String get tagBackupRestore => 'Restaurar original';

  @override
  String tagBackupRestoreBody(String name) {
    return 'El archivo «$name» vuelve a como estaba antes del cambio. La biblioteca conserva los cambios hechos en la app.';
  }

  @override
  String get tagBackupRestored => 'Original restaurado';

  @override
  String tagBackupRestoreFailed(String reason) {
    return 'No se pudo restaurar: $reason';
  }

  @override
  String get tagBackupDelete => 'Eliminar copia';

  @override
  String get tagBackupDeleteBody =>
      'Ya no podrás devolver el archivo a como estaba antes del cambio.';

  @override
  String get tagBackupDeleted => 'Copia eliminada';

  @override
  String get deleteFromDevice => 'Eliminar del dispositivo';

  @override
  String deleteTrackTitle(String title) {
    return '¿Eliminar «$title»?';
  }

  @override
  String get deleteTrackBody =>
      'El archivo se borra del dispositivo y la canción desaparece de la biblioteca, las listas, los favoritos y el historial. No se puede deshacer.';

  @override
  String deleteTracksTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '¿Eliminar $count canciones?',
      one: '¿Eliminar 1 canción?',
    );
    return '$_temp0';
  }

  @override
  String get deleteTracksBody =>
      'Los archivos se borran del dispositivo y las canciones desaparecen de la biblioteca, las listas, los favoritos y el historial. No se puede deshacer.';

  @override
  String get deleteConfirm => 'Eliminar';

  @override
  String get trackDeleted => 'Canción eliminada';

  @override
  String trackDeleteFailed(String reason) {
    return 'No se pudo eliminar el archivo: $reason';
  }

  @override
  String tracksDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones eliminadas',
      one: '1 canción eliminada',
    );
    return '$_temp0';
  }

  @override
  String tracksDeletedSome(int count, int failed) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones eliminadas',
      one: '1 canción eliminada',
    );
    return '$_temp0, $failed sin eliminar';
  }

  @override
  String get trackDeleteRefused => 'Android no permitió eliminar el archivo';

  @override
  String get reviewTitle => 'Por revisar';

  @override
  String get reviewFilterAll => 'Todas';

  @override
  String get reviewFilterNothingFound => 'Sin resultados';

  @override
  String get reviewFilterNoLyrics => 'Sin letra';

  @override
  String get reviewFilterNoCover => 'Sin portada';

  @override
  String get reviewFilterMissingData => 'Datos que faltan';

  @override
  String get reviewEmpty =>
      'Nada que revisar: a las canciones buscadas no les falta nada';

  @override
  String get reviewHint =>
      'Canciones a las que les falta algo. Busca de nuevo o déjalas así.';

  @override
  String get reviewRetry => 'Reintentar';

  @override
  String get reviewDismiss => 'Ignorar';

  @override
  String reviewRetryStarted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones',
      one: '1 canción',
    );
    return 'Búsqueda iniciada para $_temp0';
  }

  @override
  String reviewDismissed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones quitadas de la lista',
      one: '1 canción quitada de la lista',
    );
    return '$_temp0';
  }

  @override
  String reviewSecondOpinionProgress(int done, int total) {
    return 'Comprobando con YouTube Music, $done de $total';
  }

  @override
  String get reviewSecondOpinionStop => 'Detener';

  @override
  String reviewSecondOpinionDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones actualizadas con YouTube Music',
      one: '1 canción actualizada con YouTube Music',
    );
    return '$_temp0';
  }

  @override
  String get reviewSecondOpinionThrottled =>
      'YouTube Music pidió ir más despacio: las canciones restantes se comprobarán más tarde';

  @override
  String activitySecondOpinion(int done, int total) {
    return 'Segunda opinión: $done de $total';
  }

  @override
  String get secondOpinionLogTitle => 'Segunda opinión';

  @override
  String get secondOpinionLogEmpty => 'Ninguna canción comprobada';

  @override
  String get secondOpinionConfirmed => 'Confirmado, nada que añadir';

  @override
  String secondOpinionConfirmedFields(String fields) {
    return 'Confirmado, añadido: $fields';
  }

  @override
  String get secondOpinionNotConfirmed => 'No confirmado';

  @override
  String get secondOpinionNetwork => 'Red no disponible, para reintentar';

  @override
  String get secondOpinionThrottled => 'YouTube Music pidió ir más despacio';

  @override
  String get sourceYoutubeMusic => 'Fuente: YouTube Music';

  @override
  String get curiositySourceDiscogs => 'Del álbum, de Discogs';

  @override
  String get navMemory => 'Almacenamiento';

  @override
  String get memoryMusicLabel => 'Música';

  @override
  String get memoryOtherLabel => 'Otros';

  @override
  String get memoryFreeLabel => 'Libre';

  @override
  String memoryDeviceLine(String free, String total) {
    return '$free libres de $total';
  }

  @override
  String get memoryPlaylists => 'Listas';

  @override
  String get memoryPlaylistsNote =>
      'Una canción en varias listas cuenta en cada una, así que la suma puede superar el total.';

  @override
  String get memoryByFormat => 'Formatos';

  @override
  String get memoryByFolder => 'Carpetas';

  @override
  String get memoryNoFolder => 'Fuera de las carpetas';

  @override
  String get memoryHeaviest => 'Los más pesados';

  @override
  String get memoryHeaviestTracks => 'Canciones';

  @override
  String get memoryHeaviestAlbums => 'Álbumes';

  @override
  String get memoryNeverPlayed => 'Nunca escuchadas';

  @override
  String get memoryNeverPlayedHint =>
      'Canciones sin una sola reproducción. Selecciona algunas para borrarlas del dispositivo.';

  @override
  String get memoryNeverPlayedNone => 'Has escuchado toda tu música';

  @override
  String get memoryAppData => 'Datos de la app';

  @override
  String get memoryCovers => 'Carátulas';

  @override
  String memoryCoversThumbs(String size) {
    return 'de las cuales miniaturas $size';
  }

  @override
  String get memoryDatabase => 'Biblioteca';

  @override
  String get memoryImageMemory => 'Imágenes en memoria';

  @override
  String get memoryJamCache => 'Caché de Jam';

  @override
  String get memorySearchCache => 'Caché de búsquedas';

  @override
  String get memoryCatalogCache => 'Catálogo en línea';

  @override
  String get memoryBlurCopies => 'Fondos desenfocados';

  @override
  String get memoryTagBackups => 'Copias de etiquetas';

  @override
  String get memoryLog => 'Archivo de registro';

  @override
  String get memoryPodcasts => 'Episodios de podcast';

  @override
  String get memoryClearCache => 'Vaciar caché';

  @override
  String memoryCleared(String size) {
    return '$size liberados';
  }

  @override
  String memoryClearedJamKept(String size) {
    return '$size liberados. La caché de Jam está en uso y no se ha tocado';
  }

  @override
  String get memoryClearFailed => 'No se pudo vaciar la caché';

  @override
  String get memoryOfMusic => 'de música';

  @override
  String get memoryShowAll => 'Mostrar todos';

  @override
  String get memoryCache => 'Caché';

  @override
  String get memoryCacheHint => 'Imágenes, búsquedas, Jam';

  @override
  String get memoryDatabaseHint =>
      'La base de datos con canciones y reproducciones';

  @override
  String get memoryTagBackupsHint => 'Antes de cada cambio en los archivos';

  @override
  String get memoryTinyNote => 'Los datos de menos de 1 MB no se muestran.';

  @override
  String memoryClearHint(String size) {
    return 'Libera $size. Las canciones, las portadas y las reproducciones se quedan.';
  }

  @override
  String memoryDuplicateGroups(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString grupos',
      one: '1 grupo',
    );
    return '$_temp0';
  }

  @override
  String get memoryTools => 'Herramientas';

  @override
  String get memoryUnavailable => 'No disponible';

  @override
  String ytmArtistWithAudience(String audience) {
    return 'Artista, $audience';
  }

  @override
  String ytmOffline(String date) {
    return 'Sin conexión, datos del $date';
  }

  @override
  String get ytmArtistNotFound => 'Artista no encontrado';

  @override
  String get ytmPageUnreadable =>
      'No se puede leer la página (YouTube cambió algo)';

  @override
  String get ytmArtistUnreadable =>
      'No se puede leer la página del artista (YouTube cambió algo)';

  @override
  String ytmSearchSongsOf(String name) {
    return 'Buscar canciones de $name';
  }

  @override
  String get ytmInYourLibrary => 'En tu biblioteca';

  @override
  String get ytmAbout => 'Información';

  @override
  String get ytmMore => 'Más';

  @override
  String get ytmLess => 'Menos';

  @override
  String get ytmDownloadAlbum => 'Descargar álbum';

  @override
  String ytmDownloadAlbumTitle(String album) {
    return '¿Descargar «$album»?';
  }

  @override
  String ytmAlbumConfirmBody(int tracks, String duration, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      tracks,
      locale: localeName,
      other: '$tracks canciones',
      one: '1 canción',
    );
    return '$_temp0, $duration, unos $size';
  }

  @override
  String ytmAlbumConfirmOwned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones ya están en la biblioteca y se enlazarán',
      one: '1 canción ya está en la biblioteca y se enlazará',
    );
    return '$_temp0';
  }

  @override
  String ytmAlbumStarted(String name) {
    return 'Importación «$name» iniciada';
  }

  @override
  String get ytmShowImport => 'Mostrar';

  @override
  String get ytmOnYoutubeMusic => 'En YouTube Music';

  @override
  String get ytmArtistOnYoutubeMusic => 'Artista en YouTube Music';

  @override
  String get ytmSearchingArtist => 'Buscando en YouTube Music…';

  @override
  String get ytmPickArtist => '¿Qué artista?';

  @override
  String get ytmArtistNone => 'No se encontró ningún artista en YouTube Music';

  @override
  String get suggestedBadge => 'Sugerido';

  @override
  String suggestedSimilarTo(String seed) {
    return 'Sugerido: parecido a «$seed»';
  }

  @override
  String get suggestionDownloadStarted => 'Descarga iniciada';

  @override
  String suggestionAddWhenDownloaded(String name) {
    return 'Lo descargo y lo añado a «$name»';
  }

  @override
  String get dislikesTitle => 'No me gusta';

  @override
  String get dislikesHint =>
      'Lo que no quieres entre las sugerencias. Las canciones solo vuelven si se parecen mucho a lo que escuchas; los artistas, nunca.';

  @override
  String dislikesTracksTab(int count) {
    return 'Canciones $count';
  }

  @override
  String dislikesArtistsTab(int count) {
    return 'Artistas $count';
  }

  @override
  String get dislikesEmptyTracks => 'Ninguna canción excluida';

  @override
  String get dislikesEmptyArtists => 'Ningún artista excluido';

  @override
  String get dislikesEmptyHint =>
      'Cuando tocas «No me gusta» en una sugerencia, aparece aquí y puedes quitarla.';

  @override
  String get dislikesRemove => 'Quitar';

  @override
  String dislikesRemoveLabel(String name) {
    return 'Quitar «$name» de No me gusta';
  }

  @override
  String dislikesRemoved(String name) {
    return '«$name» quitado de No me gusta';
  }

  @override
  String get dislikesTileHint =>
      'Canciones y artistas excluidos de las sugerencias';

  @override
  String get dislikePlayerLabel => 'No me gusta: canción o artista';

  @override
  String get suggestionDislike => 'No me gusta';

  @override
  String get suggestionDisliked => 'No te lo sugeriré más';

  @override
  String get removeFromQueueAction => 'Quitar de la cola';

  @override
  String get shuffleModeOff => 'Aleatorio: desactivado';

  @override
  String get shuffleModeOn => 'Aleatorio: activado';

  @override
  String get shuffleModePlus =>
      'Aleatorio+: activado (mantén pulsado para ajustes)';

  @override
  String get shufflePlusTitle => 'Aleatorio+';

  @override
  String get shufflePlusNote =>
      'Se activa desde el botón aleatorio (tercer toque). No disponible para álbumes en streaming, Jam y radio';

  @override
  String shufflePlusEvery(int n) {
    return 'Una sugerencia cada $n canciones';
  }

  @override
  String get shufflePlusUnmeteredOnly => 'Solo con Wi‑Fi';

  @override
  String get shufflePlusUnmeteredOnlyHint =>
      'Sin sugerencias con datos móviles ni redes de pago por uso.';

  @override
  String get shufflePlusData =>
      'Consumo estimado: unos 15 MB por hora con una sugerencia cada 4 canciones.';

  @override
  String get shufflePlusActive =>
      'Activo: las sugerencias llegan mientras escuchas.';

  @override
  String get shufflePlusOff => 'Desactivado: el aleatorio sigue normal.';

  @override
  String get shufflePlusBlockJam => 'No activo durante una Jam';

  @override
  String get shufflePlusBlockShort =>
      'Necesita una lista de al menos 5 canciones';

  @override
  String get shufflePlusBlockNoTool => 'yt-dlp no disponible';

  @override
  String get shufflePlusBlockMetered => 'En pausa: red de pago por uso';

  @override
  String get shufflePlusBlockStopped =>
      'Apagado hasta reiniciar: demasiados errores de reproducción';

  @override
  String get shufflePlusBlockOnline =>
      'No disponible para un álbum en streaming';

  @override
  String get shufflePlusBlockRadio => 'No disponible con la radio';

  @override
  String get shufflePlusNoticeRateLimited =>
      'YouTube pide ir más despacio: sugerencias en pausa durante 15 minutos';

  @override
  String get shufflePlusNoticeTooManyErrors =>
      'Demasiados errores de reproducción: sugerencias apagadas hasta reiniciar';

  @override
  String get suggestionsRecentTitle => 'Sugeridos recientes';

  @override
  String get suggestionsRecentEmpty =>
      'Aún no hay sugerencias. Aparecen aquí cuando usas Aleatorio+.';

  @override
  String get suggestionsClear => 'Vaciar historial';

  @override
  String get suggestionsClearBody =>
      'Olvida las sugerencias y los «No me gusta»: podrán volver.';

  @override
  String suggestionsRowNote(String seed, String outcome) {
    return 'parecido a «$seed», $outcome';
  }

  @override
  String get suggestionOutcomeQueued => 'En la cola';

  @override
  String get suggestionOutcomeSkipped => 'Saltado';

  @override
  String get suggestionOutcomeHeard => 'Escuchado';

  @override
  String get suggestionOutcomeDownloaded => 'Descargado';

  @override
  String get suggestionOutcomeDisliked => 'No me gusta';

  @override
  String get memorySuggestions => 'Sugeridos de Aleatorio+';

  @override
  String searchOnline(String query) {
    return 'Buscar «$query» en línea';
  }

  @override
  String get onlineBestResults => 'Mejores resultados';

  @override
  String onlineOthersChip(int count) {
    return 'Otros resultados ($count)';
  }

  @override
  String get onlineNoneSure => 'Ningún resultado seguro';

  @override
  String get onlineInLibrary => 'En tu biblioteca';

  @override
  String onlineShowAllCount(int count) {
    return 'Mostrar todo ($count)';
  }

  @override
  String onlineOwnedHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resultados que ya están en la biblioteca, ocultos',
      one: '1 resultado que ya está en la biblioteca, oculto',
    );
    return '$_temp0';
  }

  @override
  String onlineArtistSongs(String artist) {
    return 'Canciones de $artist';
  }

  @override
  String get onlineFilterAll => 'Todas';

  @override
  String onlineFromSource(String source) {
    return 'De $source';
  }

  @override
  String get onlineAlsoVideo => 'también como vídeo';

  @override
  String get onlineListenVideo => 'Escuchar el vídeo';

  @override
  String onlineNoticeRateLimited(String source, String other) {
    return '$source pide una pausa: resultados solo de $other';
  }

  @override
  String onlineNoticeFailed(String source, String other) {
    return '$source no respondió: resultados solo de $other';
  }

  @override
  String get radioTitle => 'Radio';

  @override
  String radioLibrarySubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count emisoras guardadas',
      one: '1 emisora guardada',
      zero: 'Emisoras en directo',
    );
    return '$_temp0';
  }

  @override
  String get radioSearchHint => 'Buscar una emisora';

  @override
  String radioOnlyCountry(String country) {
    return 'Solo $country';
  }

  @override
  String get radioMine => 'Mis emisoras';

  @override
  String get radioNearYou => 'Cerca de ti';

  @override
  String get radioGenres => 'Géneros';

  @override
  String get radioTopListened => 'Las más escuchadas';

  @override
  String get radioChooseRegion => 'Elige la región';

  @override
  String get radioRegionHint =>
      'Las emisoras cercanas salen del país y la región que elijas: la app no usa tu ubicación.';

  @override
  String radioCountryChip(String country) {
    return 'País: $country';
  }

  @override
  String get radioChooseCountry => 'Elige el país';

  @override
  String radioOfflineList(String date) {
    return 'Sin conexión, lista del $date';
  }

  @override
  String get radioLoadFailed => 'No se pudieron cargar las emisoras';

  @override
  String get radioNoResults => 'No se encontró ninguna emisora';

  @override
  String get radioResults => 'Resultados';

  @override
  String get radioSave => 'Guardar en Mis emisoras';

  @override
  String get radioUnsave => 'Quitar de Mis emisoras';

  @override
  String get radioSavedDone => 'Emisora guardada';

  @override
  String get radioRemovedDone => 'Emisora quitada';

  @override
  String get radioNotResponding => 'no responde';

  @override
  String get radioLive => 'En directo';

  @override
  String get reasonRadioUnavailable => 'la emisora no responde';

  @override
  String radioDataPerHour(String mb) {
    return '≈ $mb MB por hora';
  }

  @override
  String get radioSite => 'Sitio de la emisora';

  @override
  String get radioSiteCopied => 'Dirección del sitio copiada';

  @override
  String get radioSearchSong => 'Buscar esta canción';

  @override
  String get radioRenameTitle => 'Nombre de la emisora';

  @override
  String get radioMobileNotice => 'La radio usa unos 1 MB de datos por minuto.';

  @override
  String get radioAddAddress => 'Añadir dirección';

  @override
  String get radioAddName => 'Nombre';

  @override
  String get radioAddUrl => 'Dirección del stream';

  @override
  String get radioAddTest => 'Probar 10 segundos';

  @override
  String get radioAddTesting => 'Probando… si la oyes, puedes guardarla.';

  @override
  String get radioLinkEmpty => 'Escribe la dirección del stream';

  @override
  String get radioLinkNotAnAddress =>
      'No parece una dirección: escríbela completa, por ejemplo https://…';

  @override
  String get radioLinkBadScheme =>
      'La dirección debe empezar por http:// o https://';

  @override
  String get radioLinkNoEntries =>
      'El archivo no contiene ninguna dirección que reproducir';

  @override
  String get radioLinkTooBig =>
      'El archivo es demasiado grande para ser una lista de emisoras';

  @override
  String get radioLinkFetchFailed => 'No se pudo descargar el archivo';

  @override
  String get radioReorder => 'Arrastra para reordenar';

  @override
  String get radioReorderFailed => 'No se pudo guardar el nuevo orden';

  @override
  String get memoryRadio => 'Radio (listas de emisoras)';

  @override
  String get radioGenrePop => 'Pop';

  @override
  String get radioGenreRock => 'Rock';

  @override
  String get radioGenreClassicRock => 'Rock clásico';

  @override
  String get radioGenreJazz => 'Jazz';

  @override
  String get radioGenreBlues => 'Blues';

  @override
  String get radioGenreClassical => 'Clásica';

  @override
  String get radioGenreDance => 'Dance';

  @override
  String get radioGenreElectronic => 'Electrónica';

  @override
  String get radioGenreHouse => 'House';

  @override
  String get radioGenreHipHop => 'Hip hop';

  @override
  String get radioGenreLoFi => 'Lo-fi';

  @override
  String get radioGenreChillout => 'Chillout';

  @override
  String get radioGenreSixties => 'Años 60';

  @override
  String get radioGenreSeventies => 'Años 70';

  @override
  String get radioGenreEighties => 'Años 80';

  @override
  String get radioGenreNineties => 'Años 90';

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
  String get radioGenreNews => 'Noticias';

  @override
  String get radioGenreTalk => 'Tertulia';

  @override
  String get radioGenreSports => 'Deportes';

  @override
  String get newReleasesTitle => 'Novedades';

  @override
  String get releasesTopArtists =>
      'Seguir automáticamente a los más escuchados';

  @override
  String get releasesTopArtistsHint =>
      'Los 15 artistas más escuchados de los últimos 90 días, buscados en YouTube Music.';

  @override
  String get releasesNotify => 'Avisos de novedades';

  @override
  String get releasesNotifyHint => 'Como máximo una al día, solo en Android.';

  @override
  String get releasesUnmetered => 'Comprobar solo con Wi‑Fi';

  @override
  String get releasesUnmeteredHint =>
      'Una comprobación diaria consume unos 0,5 MB.';

  @override
  String get releasesTopCardTitle =>
      '¿Quieres saber cuándo publican música nueva tus artistas más escuchados?';

  @override
  String get releasesTopCardYes => 'Activar';

  @override
  String get releasesTopCardNo => 'No, gracias';

  @override
  String get releasesCheckNow => 'Comprobar ahora';

  @override
  String releasesLastCheck(String when) {
    return 'Última comprobación: $when';
  }

  @override
  String get releasesNeverChecked => 'Nunca comprobado';

  @override
  String releasesPaused(String time) {
    return 'YouTube pide una pausa: reintento a las $time';
  }

  @override
  String get releasesChecking => 'Comprobando…';

  @override
  String get releasesCheckNone => 'Sin novedades';

  @override
  String releasesCheckFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count novedades',
      one: '1 novedad',
    );
    return '$_temp0';
  }

  @override
  String get releasesCantCheck =>
      'No se puede comprobar ahora: sin red o sin artistas seguidos.';

  @override
  String get releasesChanged =>
      'YouTube Music cambió de formato: reintento en la próxima ronda.';

  @override
  String get releasesEmpty =>
      'Sin novedades en los últimos 90 días. Abre la página de un artista y toca «Seguir».';

  @override
  String get releasesAllArtists => 'Todos';

  @override
  String releasesFollowedTitle(int count) {
    return 'Artistas seguidos ($count)';
  }

  @override
  String get releasesFollowedLibrary => 'Artistas seguidos';

  @override
  String releasesFollowedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artistas',
      one: '1 artista',
    );
    return '$_temp0';
  }

  @override
  String get followedEmpty =>
      'Aún no sigues a ningún artista. Abre la página de un artista y toca «Seguir».';

  @override
  String get followAction => 'Seguir';

  @override
  String get followingAction => 'Siguiendo';

  @override
  String followStopTitle(String name) {
    return '¿Dejar de seguir a $name?';
  }

  @override
  String get followStopBody => 'Ya no recibirás sus novedades.';

  @override
  String get followOnYtm => 'Seguir en YouTube Music';

  @override
  String get followStop => 'Dejar de seguir';

  @override
  String followedNow(String name) {
    return 'Ahora sigues a $name';
  }

  @override
  String get followMute => 'Silenciar avisos';

  @override
  String get followUnmute => 'Reactivar avisos';

  @override
  String get followedTopListened => 'Más escuchado';

  @override
  String get followedToConfirm => 'Por confirmar';

  @override
  String get followedNotFound => 'No encontrado';

  @override
  String get followedRetry => 'Reintentar';

  @override
  String releaseAlbumYear(String year) {
    return 'Álbum, $year';
  }

  @override
  String releaseSingleYear(String year) {
    return 'Sencillo, $year';
  }

  @override
  String get releaseAlbumPlain => 'Álbum';

  @override
  String get releaseSinglePlain => 'Sencillo';

  @override
  String releaseVariants(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'y $count versiones más',
      one: 'y 1 versión más',
    );
    return '$_temp0';
  }

  @override
  String get releaseNewBadge => 'Nuevo';

  @override
  String get activityReleases => 'Comprobando novedades';

  @override
  String releaseNotifyOne(String title, String artist) {
    return 'Novedad: $title de $artist';
  }

  @override
  String releaseNotifyMany1(int count, String a) {
    return '$count novedades: $a';
  }

  @override
  String releaseNotifyMany2(int count, String a, String b) {
    return '$count novedades: $a y $b';
  }

  @override
  String releaseNotifyManyMore(int count, String a, String b, int others) {
    return '$count novedades: $a, $b y $others más';
  }

  @override
  String get releaseNotifyShow => 'Mostrar';

  @override
  String get reportIssue => 'Informar de un problema';

  @override
  String get reportIssueHint => 'Abre GitHub con el texto ya preparado';

  @override
  String get reportKindBug => 'Fallo';

  @override
  String get reportKindIdea => 'Idea';

  @override
  String get reportTitleLabel => 'Título';

  @override
  String get reportDescLabel => 'Descripción';

  @override
  String reportDescHelper(int n) {
    return 'Qué pasó y cómo reproducirlo (al menos $n caracteres)';
  }

  @override
  String get reportAttach => 'Adjuntar información técnica';

  @override
  String get reportAttachPreview => 'Se enviará exactamente esto:';

  @override
  String get reportOpen => 'Abrir en GitHub';

  @override
  String get reportCopy => 'Copiar texto';

  @override
  String get reportCopied => 'Texto copiado';

  @override
  String get reportGithubNote =>
      'Hace falta una cuenta de GitHub; sin ella, copia el texto y envíalo como prefieras.';

  @override
  String get reportOpenFailed =>
      'No se pudo abrir el navegador: el texto se copió';

  @override
  String get reportLogShortened =>
      'El registro se acortará para caber en la dirección';

  @override
  String get reportNoLog => 'Sin avisos ni errores recientes en el registro';

  @override
  String get reportUnknown => 'Desconocido';

  @override
  String get iconAskTitle => '¿Cambiar también el icono de la app?';

  @override
  String get iconProblems =>
      'El icono cambia cuando sales de la app. Posibles problemas:\n• el launcher puede tardar unos segundos en actualizarlo, o mostrar un momento dos iconos o ninguno;\n• en algunos launchers el icono de la pantalla de inicio se quita o se mueve y hay que volver a ponerlo a mano (los widgets se quedan);\n• los accesos directos de inicio creados con el icono anterior pueden dejar de funcionar;\n• la app puede desaparecer un momento de las apps recientes;\n• rara vez Android cierra la app y la música se para.\nEn el ordenador el icono no cambia.';

  @override
  String get iconChange => 'Cambiar el icono';

  @override
  String get iconKeep => 'Dejarlo como está';

  @override
  String get iconDontAsk => 'No volver a preguntar';

  @override
  String get iconFollowTitle => 'Icono según el tema';

  @override
  String get iconFollowSubtitle =>
      'El icono sigue el tema y el color cuando sales de la app';

  @override
  String get exportifySyncTitle => 'Sincronizar desde Spotify';

  @override
  String exportifySyncChanges(int added, int removed) {
    return '+$added nuevas, −$removed quitadas';
  }

  @override
  String get exportifySyncNew => 'Lista nueva';

  @override
  String get exportifySyncChoose => 'Por elegir';

  @override
  String get exportifySyncNoChanges => 'Sin cambios';

  @override
  String exportifySyncSkipped(int n) {
    return '$n archivos omitidos (no son listas legibles)';
  }

  @override
  String exportifySyncGo(int n) {
    return 'Sincronizar $n';
  }

  @override
  String exportifySyncDone(int n) {
    return '$n listas sincronizándose: sigue el avance en el Centro de actividad';
  }

  @override
  String get exportifySyncEmpty => 'No hay listas en el ZIP';

  @override
  String get exportifySyncPickTitle => 'Elige la lista';

  @override
  String get csvImportOpenExportify => 'Abrir exportify.net';

  @override
  String get csvImportOpenFailed => 'No se puede abrir el navegador';

  @override
  String get csvImportZipHint =>
      'Con «Export All» obtienes un ZIP con todas tus listas: elígelo aquí y sincronízalas juntas.';

  @override
  String get exportifySyncFailed => 'Error al sincronizar';

  @override
  String get exportifySyncEntryFailed => 'No se puede leer esta lista';

  @override
  String get exportifySyncLoadFailed => 'No se pueden leer las listas del ZIP';

  @override
  String get exportifyRemindTitle => 'Recuérdame sincronizar con Spotify';

  @override
  String get exportifyRemindOff => 'Desactivado';

  @override
  String exportifyRemindDays(int days) {
    return '$days días';
  }

  @override
  String get exportifyCardTitle =>
      'Es hora de sincronizar tus listas con Spotify';

  @override
  String get exportifyCardOpen => 'Abrir Exportify';

  @override
  String get exportifyCardLater => 'Más tarde';

  @override
  String get exportifyFoundTitle => 'Exportación de Exportify encontrada';

  @override
  String get exportifyFoundSync => 'Sincronizar';

  @override
  String get onboardingSpotifyTitle => 'Listas de Spotify';

  @override
  String get onboardingSpotifyBody =>
      'En exportify.net descargas tus listas de Spotify en un archivo. Codecore lo recoge y las actualiza aquí.\nNo hace falta conectar ninguna cuenta: el archivo lo descargas tú.';

  @override
  String get deezerMeta => 'Metadatos de Deezer';

  @override
  String get deezerMetaHint =>
      'Solo datos (carátulas, números de pista), nunca música';

  @override
  String get deezerMetaNote =>
      'Uso privado y no comercial. Las condiciones de Deezer prohíben promover la descarga no autorizada, y Codecore descarga de YouTube: el riesgo es tuyo.';

  @override
  String get acoustId => 'Reconocer por el sonido (AcoustID)';

  @override
  String get acoustIdHint => 'Solo se envía la huella del tema, nunca el audio';

  @override
  String get settingsSpinCover => 'Carátula giratoria';

  @override
  String get settingsSpinCoverHint =>
      'En el reproductor, mientras suena la música';

  @override
  String get themeLowContrastWarning =>
      'Algunos colores de texto se leen mal sobre el fondo (menos de 4,5:1). El tema se queda como está.';

  @override
  String get streamCacheTitle => 'Espacio para el streaming';

  @override
  String streamCacheUsage(String used, String limit) {
    return '$used de $limit';
  }

  @override
  String get streamCacheClear => 'Vaciar';

  @override
  String get streamCacheCleared => 'Caché de streaming vaciada';

  @override
  String get streamCacheClearFailed =>
      'No se pudo vaciar la caché de streaming';

  @override
  String get playerLoading => 'Cargando…';

  @override
  String get ytmAlbumQueue => 'Añadir álbum a la cola';

  @override
  String get addedToLibrary => 'Añadida a la biblioteca';

  @override
  String get promoteNoSpace =>
      'No hay espacio suficiente para descargar la canción';

  @override
  String get promoteFailed => 'No se pudo mover la canción';

  @override
  String get creditsDetails => 'Créditos y detalles';

  @override
  String get creditsDetailsHint =>
      'Autores, productores y detalles de las canciones';

  @override
  String get creditsDetailsNote => 'Usa también una API no oficial de Deezer';

  @override
  String get creditRoleVocals => 'Voz';

  @override
  String get creditRoleBackingVocals => 'Coros';

  @override
  String get creditRoleGuitar => 'Guitarra';

  @override
  String get creditRoleBassGuitar => 'Bajo';

  @override
  String get creditRoleDrums => 'Batería';

  @override
  String get creditRoleKeyboard => 'Teclados';

  @override
  String get creditRolePiano => 'Piano';

  @override
  String get creditRoleSynthesizer => 'Sintetizador';

  @override
  String get creditRoleComposer => 'Compositor';

  @override
  String get creditRoleAuthor => 'Autor';

  @override
  String get creditRoleLyricist => 'Letrista';

  @override
  String get creditRoleArranger => 'Arreglista';

  @override
  String get creditRoleProducer => 'Productor';

  @override
  String get creditRoleAdditionalProducer => 'Productor adicional';

  @override
  String get creditRoleMix => 'Mezcla';

  @override
  String get creditRoleMastering => 'Masterización';

  @override
  String get creditRoleRecording => 'Grabación';

  @override
  String get creditRoleEngineer => 'Ingeniero de sonido';

  @override
  String get creditRoleProgramming => 'Programación';

  @override
  String get creditRoleDrumProgrammer => 'Programación de batería';

  @override
  String get creditRoleMusicPublisher => 'Editorial musical';

  @override
  String get creditsGroupPerformers => 'Intérpretes e instrumentos';

  @override
  String get creditsGroupWriters => 'Autores';

  @override
  String get creditsGroupProduction => 'Producción y técnicos';

  @override
  String get creditsGroupOther => 'Otros';

  @override
  String get creditsTitle => 'Créditos y detalles';

  @override
  String get creditsShowAll => 'Mostrar todo';

  @override
  String get creditsRefresh => 'Actualizar';

  @override
  String get creditsAppearsAs => 'Aparece como';

  @override
  String get creditsInCredits => 'En los créditos';

  @override
  String get creditsRefreshFailed => 'No se pudieron actualizar los créditos';

  @override
  String get creditsBpm => 'BPM';

  @override
  String get creditsLabel => 'Sello';

  @override
  String get creditsDigitalRelease => 'Lanzamiento digital';

  @override
  String get creditsPhysicalRelease => 'Lanzamiento físico';

  @override
  String get creditsKindSingle => 'Sencillo';

  @override
  String get creditsKindEp => 'EP';

  @override
  String get creditsRank => 'Posición en listas';

  @override
  String get creditsAlbumFans => 'Fans del álbum';

  @override
  String get creditsExplicit => 'Explícito';

  @override
  String creditsOpenArtist(String name) {
    return 'Abrir $name';
  }

  @override
  String get autoCuriosities => 'Curiosidades automáticas';

  @override
  String get autoCuriositiesHint =>
      'Busca curiosidades en Wikipedia para las canciones nuevas';

  @override
  String memoryEnrichment(String size) {
    return 'Enriquecimiento: $size';
  }

  @override
  String memoryEnrichmentDetail(
    String lyrics,
    String curiosities,
    String credits,
  ) {
    return 'Letras $lyrics, curiosidades $curiosities, créditos $credits';
  }

  @override
  String get activityPodcastRefresh => 'Actualizando los podcasts';

  @override
  String get activityRadio => 'Comprobando las radios guardadas';

  @override
  String activityEnrichBackground(int done, int total) {
    return 'Completando el enriquecimiento: $done de $total';
  }

  @override
  String get enrichRoundTitle => 'Ronda de enriquecimiento';

  @override
  String get enrichRoundUpdated => 'Actualizados';

  @override
  String get enrichRoundNone => 'Sin resultado';

  @override
  String get enrichRoundGone => 'Ninguna canción que mostrar';

  @override
  String get enrichPartMeta => 'Datos de la canción';

  @override
  String get enrichPartLyrics => 'Letra';

  @override
  String get enrichPartSynced => 'Letra sincronizada';

  @override
  String get enrichPartCurio => 'Curiosidades';

  @override
  String get enrichPartCredits => 'Créditos';

  @override
  String get coverChange => 'Cambiar carátula';

  @override
  String get coverRestoreOriginal => 'Restaurar carátula original';

  @override
  String get coverSourceDevice => 'Del dispositivo';

  @override
  String get coverSourceLibrary => 'De la biblioteca';

  @override
  String get coverSourceOnline => 'En línea';

  @override
  String coverSizePx(int w, int h) {
    return '$w × $h';
  }

  @override
  String get speakerPermTitle => 'Permiso de Bluetooth';

  @override
  String get speakerPermBody =>
      'Para reconocer tu altavoz, Codecore necesita ver qué dispositivos Bluetooth están conectados. No lee nada más.';

  @override
  String get speakerPermAllow => 'Permitir';

  @override
  String get speakerNotNow => 'Ahora no';

  @override
  String speakerAskTitle(String name) {
    return '¿$name es un altavoz?';
  }

  @override
  String get speakerAskBody =>
      'Si lo es, al conectarse Codecore abre solo una Jam a la que otros pueden unirse.';

  @override
  String get speakerYes => 'Sí';

  @override
  String get speakerNo => 'No';

  @override
  String get speakerJamSection => 'Jam en el altavoz';

  @override
  String get speakerJamHint =>
      'Cuando se conecta un altavoz Bluetooth, Codecore abre solo una Jam a la que otros pueden unirse.';

  @override
  String get speakerNoDevices => 'Aún no hay dispositivos marcados';

  @override
  String get speakerIsSpeaker => 'Altavoz';

  @override
  String get speakerNotSpeaker => 'No es un altavoz';

  @override
  String get speakerPermDenied => 'Permiso de Bluetooth denegado';

  @override
  String get speakerPermRetry => 'Toca para pedirlo de nuevo';

  @override
  String speakerChange(String name) {
    return 'Cambiar $name';
  }

  @override
  String jamInviteBanner(String name) {
    return 'Unirte a la Jam de $name';
  }

  @override
  String get jamInviteDismiss => 'Ocultar';

  @override
  String get speakerAwayNotice => 'Conecta un altavoz';

  @override
  String get jamFull => 'La Jam está llena';

  @override
  String get jamAddFailed => 'No añadido a la Jam';

  @override
  String get jamNotFoundOnline => 'No encontrado en línea, no se puede añadir';

  @override
  String get jamLeft => 'Has salido de la Jam';

  @override
  String get speakerContinueOnPhone => 'Seguir en el teléfono';

  @override
  String get speakerContinueOnPhoneLabel =>
      'Seguir en el teléfono: la Jam suena por el altavoz de este teléfono, sin la caja';

  @override
  String get speakerOfferTitle => '¿Reproducir la Jam en tu altavoz?';

  @override
  String get speakerOfferBody =>
      'Tu altavoz está conectado y la Jam está en pausa. Si quieres, la música sigue desde aquí.';

  @override
  String get jamRemoteTitle => 'Jam a distancia';

  @override
  String get jamRemoteHint =>
      'Los brokers (servidores) de la Jam a distancia, por orden de preferencia.';

  @override
  String get jamBrokerAdd => 'Añadir broker';

  @override
  String get jamBrokerHost => 'Dirección';

  @override
  String get jamBrokerPort => 'Puerto';

  @override
  String get jamBrokerTls => 'Conexión cifrada (TLS)';

  @override
  String get jamBrokerNoTls =>
      'Sin TLS cualquiera en la red puede leer lo que pasa por el broker. Úsalo solo si sabes lo que haces.';

  @override
  String get jamBrokerInvalid => 'Dirección o puerto no válidos';

  @override
  String get jamBrokerTest => 'Probar conexión';

  @override
  String jamBrokerTestOk(String broker) {
    return '$broker: conexión correcta';
  }

  @override
  String jamBrokerTestFail(String broker) {
    return '$broker: no se puede conectar (red, certificado o servidor inaccesible)';
  }

  @override
  String get jamBrokerRestore => 'Restaurar';

  @override
  String get jamBrokerMoveUp => 'Subir';

  @override
  String get jamBrokerRemove => 'Quitar';

  @override
  String get jamSuspend => 'Suspender';

  @override
  String get jamBlock => 'Bloquear';

  @override
  String get jamSuspendTitle => '¿Suspender por cuánto tiempo?';

  @override
  String get jamUntilJamEnds => 'Hasta que termine la Jam';

  @override
  String get jamBlockedTitle => 'Dispositivos bloqueados';

  @override
  String get jamSuspendedTitle => 'Suspendidos';

  @override
  String get jamUnblock => 'Desbloquear';

  @override
  String jamSuspendedUntil(String time) {
    return 'Hasta: $time';
  }

  @override
  String get jamTooSoon => 'Espera un momento antes de volver a intentarlo';

  @override
  String enrichInterrupted(int updated, int notFound) {
    return 'Enriquecimiento interrumpido por un error: $updated actualizadas, $notFound no encontradas';
  }

  @override
  String enrichLibraryDue(int count, int minutes) {
    return '$count canciones por completar, unos $minutes minutos';
  }

  @override
  String get enrichLibraryComplete => 'Biblioteca completa';

  @override
  String get enrichLibraryStop => 'Detener';

  @override
  String get activityEnrichWaiting => 'Completando: en espera';

  @override
  String logRecogSources(String list) {
    return 'Reconocidas: $list';
  }

  @override
  String get recogSrcTags => 'etiquetas';

  @override
  String get recogSrcVideo => 'vídeo';

  @override
  String get recogSrcText => 'texto';

  @override
  String recogIdent(String title, String artist) {
    return '$title – $artist';
  }

  @override
  String recogProposal(String identity) {
    return 'Propuesta: $identity';
  }

  @override
  String get recogAccept => 'Aceptar';

  @override
  String get recogDiscard => 'Descartar';

  @override
  String recogAcceptSem(String identity) {
    return 'Aceptar la propuesta $identity';
  }

  @override
  String recogDiscardSem(String identity) {
    return 'Descartar la propuesta $identity';
  }

  @override
  String get recogCover => 'Versión';

  @override
  String recogCoverOf(String identity) {
    return 'Versión de $identity';
  }

  @override
  String recogToConfirm(int count) {
    return 'Por confirmar ($count)';
  }

  @override
  String get recogAcceptAll => 'Aceptar todas';

  @override
  String get recogNoProposals => 'Todo confirmado';

  @override
  String recogFromTo(String from, String to) {
    return 'De $from a $to';
  }

  @override
  String get logRevert => 'Restaurar';

  @override
  String get recogActionFailed => 'La acción falló';

  @override
  String get logRevertFailed => 'No se pudo restaurar esta corrección';

  @override
  String get jamInviteNearby => 'Invitar a quien está cerca';

  @override
  String get jamInviteHint =>
      'Quien escanee el QR o escriba el código entra en la Jam.';

  @override
  String get jamBridgeConnecting => 'Conectando…';

  @override
  String get jamBridgeRetrying => 'Conexión interrumpida, reintentando…';

  @override
  String get jamBridgeUnreachable => 'Broker inaccesible';

  @override
  String jamCodeExpiresIn(int seconds) {
    return 'Caduca en $seconds s';
  }

  @override
  String get jamEnterCode => 'Entrar con un código';

  @override
  String get jamCodeLabel => 'Código';

  @override
  String get jamScanQr => 'Escanear el QR';

  @override
  String get jamJoinAction => 'Entrar';

  @override
  String get jamCodeInvalid => 'Código no válido';

  @override
  String get jamCodeExpired => 'Código caducado, pide uno nuevo';

  @override
  String get jamHostNoAnswer => 'El anfitrión no respondió';

  @override
  String get jamCustomBroker =>
      'Esta Jam usa un broker personalizado: escanea el QR';

  @override
  String get jamLinkReconnecting => 'Conexión perdida, reintentando…';

  @override
  String get jamHostSilent => 'Anfitrión inaccesible, reintentando…';

  @override
  String get jamMemberUnreachable => 'inaccesible';

  @override
  String get jamRemoteActive => 'Jam a distancia activa';

  @override
  String get jamRemoteEnd => 'Terminar';

  @override
  String get jamDeclinedHost => 'El anfitrión rechazó la solicitud';

  @override
  String get jamBusyHost => 'El anfitrión ya tiene una Jam en curso';

  @override
  String get jamWaitingHost => 'Esperando a que el anfitrión acepte…';

  @override
  String get jamFriendsTitle => 'Amigos de la Jam';

  @override
  String get jamFriendsEmpty =>
      'Aún no hay amigos. Tras la primera entrada aceptada, los dos dispositivos se guardan mutuamente.';

  @override
  String get jamFriendRemove => 'Quitar';

  @override
  String jamFriendRemoveTitle(String name) {
    return '¿Quitar a $name?';
  }

  @override
  String get jamFriendRemoveBody =>
      'Ya no os reconoceréis sin preguntar. Este dispositivo cambia su clave de anuncio.';

  @override
  String get jamAutoAcceptFriends => 'Aceptar amigos sin preguntar';

  @override
  String get jamAutoAcceptFriendsHint =>
      'Si roban el móvil de un amigo, quien lo tenga puede entrar en tu Jam estando cerca.';

  @override
  String get jamFriendBadge => 'Amigo';

  @override
  String get jamNearbyJoin => 'Unirse a una Jam cercana';

  @override
  String get jamBleTitle => 'Buscar Jams cercanas';

  @override
  String get jamBleBody12 =>
      'Android pide el permiso «Dispositivos cercanos» para buscar y anunciar Jams por Bluetooth. La app no lee dónde estás.';

  @override
  String get jamBleBody11 =>
      'Hace falta el permiso de ubicación: Android lo exige para buscar por Bluetooth; la app no lee dónde estás.';

  @override
  String get jamBleAllow => 'Permitir';

  @override
  String get jamBleNotNow => 'Ahora no';

  @override
  String get jamBleLocationOff =>
      'Activa la ubicación de Android: hace falta para buscar Jams por Bluetooth. Mientras tanto puedes usar el código o el QR.';

  @override
  String get jamNearbyScanTitle => 'Buscar Jams cercanas';

  @override
  String get jamNearbyScanHint => 'Por Bluetooth, solo con la app abierta';

  @override
  String get streamCardsUnavailable => 'No disponible';

  @override
  String get streamCardsUnavailableBody =>
      'La letra, las curiosidades y los créditos de esta canción no llegaron. Puede deberse a la red o a la fuente.';

  @override
  String get closeKeyboard => 'Cerrar teclado';

  @override
  String get loadingContent => 'Cargando…';

  @override
  String shufflePlusChoosing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Shuffle+ está eligiendo $count canciones…',
      one: 'Shuffle+ está eligiendo 1 canción…',
    );
    return '$_temp0';
  }

  @override
  String statsBarValue(String when, String time) {
    return '$when, $time';
  }

  @override
  String get homeRadioLive => 'En directo';

  @override
  String get closeSearch => 'Cerrar la búsqueda';

  @override
  String get librarySearchHint => 'Buscar en la biblioteca';

  @override
  String get genreMixTag => 'Sugerida';

  @override
  String get genreMixOffJam => 'Sugerencias desactivadas: Jam en curso';

  @override
  String get genreMixOffMetered =>
      'Sugerencias desactivadas: red de pago por uso';

  @override
  String get genreMixOffOffline => 'Sugerencias desactivadas: sin red';

  @override
  String get genreMixOffNoTool =>
      'Sugerencias desactivadas: falta la herramienta en línea';

  @override
  String get genreMixOffRateLimited =>
      'Sugerencias en pausa: demasiadas solicitudes';

  @override
  String get playerEmptyTitle => 'Nada en reproducción';

  @override
  String get playerEmptyHint => 'Elige por dónde seguir.';

  @override
  String get playerEmptyNoQueue => 'Elige una canción para empezar';

  @override
  String playerLastQueue(String name) {
    return 'Última cola: $name';
  }

  @override
  String get playerResumeLastQueue => 'Reanudar la última cola';

  @override
  String playerResumeLastQueueSub(String name, String tracks) {
    return '$name, $tracks';
  }

  @override
  String get playerShufflePlusLibrary => 'Shuffle+ de la biblioteca';

  @override
  String get playerShufflePlusLibrarySub =>
      'Tu biblioteca al azar, con canciones sugeridas';

  @override
  String get playerRecentlyAdded => 'Añadidas hace poco';

  @override
  String get reviewSearch => 'Buscar';

  @override
  String get recogTitle => 'Por confirmar';

  @override
  String recogSuggested(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count correcciones sugeridas. Revísalas una a una o acéptalas todas.',
      one: '1 corrección sugerida',
    );
    return '$_temp0';
  }

  @override
  String recogAcceptAllCount(int count) {
    return 'Aceptar todas ($count)';
  }

  @override
  String recogAcceptedAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count correcciones aceptadas',
      one: '1 corrección aceptada',
    );
    return '$_temp0. Los archivos se actualizan en segundo plano.';
  }

  @override
  String get recogNoProposalsHint => 'Ya no queda nada por revisar.';

  @override
  String get logToday => 'Hoy';

  @override
  String get logYesterday => 'Ayer';

  @override
  String logDayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entradas',
      one: '1 entrada',
    );
    return '$_temp0';
  }

  @override
  String get logRetention => 'El registro guarda los últimos 30 días.';

  @override
  String get logNoMatch => 'No hay entradas con este filtro.';

  @override
  String get logPickEntry => 'Elige una entrada para ver los detalles.';

  @override
  String get logFilterAll => 'Todo';

  @override
  String get logFilterDownload => 'Descargas';

  @override
  String get logFilterLibrary => 'Biblioteca';

  @override
  String get logFilterEnrich => 'Enriquecimiento';

  @override
  String get logFilterCorrections => 'Correcciones';

  @override
  String get logFilterErrors => 'Errores';

  @override
  String get logFailedLabel => 'No se pudo';

  @override
  String get logStoppedLabel => 'Detenido';

  @override
  String get logClearMenu => 'Vaciar registro';

  @override
  String get logClearTitle => '¿Vaciar el registro?';

  @override
  String get logClearConfirm => 'Vaciar';

  @override
  String get logPendingSub => 'Correcciones sugeridas para tus canciones';

  @override
  String get logPendingReview => 'Revisar';

  @override
  String logPendingMore(int count) {
    return 'y $count más';
  }

  @override
  String get logHowTitle => 'Cómo resolverlo';

  @override
  String get logTechTitle => 'Detalle técnico';

  @override
  String get logOpenSongs => 'Ver las canciones';

  @override
  String logHowSettings(String settings, String page) {
    return 'Abre $settings y luego «$page».';
  }

  @override
  String logHowUpdate(String button) {
    return 'Toca «$button» junto a yt-dlp.';
  }

  @override
  String get logHowWait => 'Espera unos minutos.';

  @override
  String get logHowOnline => 'Comprueba que tienes conexión.';

  @override
  String get logDlDone => 'Canción descargada';

  @override
  String get logDlFailed => 'Descarga fallida';

  @override
  String logDlGroup(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones descargadas',
      one: '1 canción descargada',
    );
    return '$_temp0';
  }

  @override
  String get logDlGroupShow => 'Mostrar las canciones';

  @override
  String get logDlGroupHide => 'Ocultar las canciones';

  @override
  String get logTransferDone => 'Canciones enviadas';

  @override
  String get logTransferFailed => 'Envío fallido';

  @override
  String get logScanDone => 'Biblioteca actualizada';

  @override
  String get logScanDoneSub => 'Se revisaron todas las carpetas.';

  @override
  String get logScanStopped => 'Escaneo detenido';

  @override
  String get logScanFailed => 'Escaneo fallido';

  @override
  String get logStoppedSub => 'Se detuvo antes de terminar.';

  @override
  String get logFailedSub => 'Se detuvo por un error.';

  @override
  String get logEnrichDone => 'Enriquecimiento terminado';

  @override
  String get logEnrichInterrupted => 'Enriquecimiento interrumpido';

  @override
  String get logEnrichInterruptedSub =>
      'Se detuvo por un error; lo hecho está guardado.';

  @override
  String get logBgDone => 'Letras y portadas añadidas';

  @override
  String get logBgDoneSub => 'Completado en segundo plano.';

  @override
  String get logBgStopped => 'Completado detenido';

  @override
  String get logBgStoppedSub => 'Ninguna fuente responde en este momento.';

  @override
  String get logBgFailed => 'Completado fallido';

  @override
  String get logBgFailedSub => 'Un error lo detuvo.';

  @override
  String get logSecondOpinion => 'Segunda opinión de YouTube Music';

  @override
  String get logSecondOpinionSub => 'Se revisaron las canciones dudosas.';

  @override
  String get logSecondOpinionFailed => 'Segunda opinión interrumpida';

  @override
  String get logCleanup => 'Duplicados buscados';

  @override
  String get logCleanupSub => 'Se compararon las canciones de la biblioteca.';

  @override
  String get logGenres => 'Géneros de las canciones releídos';

  @override
  String get logGenresSub =>
      'Se leyeron las etiquetas de las canciones para hallar todos los géneros.';

  @override
  String get logCountries => 'Países de los artistas buscados';

  @override
  String get logCountriesSub =>
      'Se buscó el país de origen de los artistas de la biblioteca.';

  @override
  String get logReleases => 'Novedades revisadas';

  @override
  String get logReleasesSub =>
      'Se buscaron novedades de los artistas que sigues.';

  @override
  String get logPodcasts => 'Pódcast actualizados';

  @override
  String get logRadio => 'Radios revisadas';

  @override
  String get logTaskFailed => 'Tarea fallida';

  @override
  String logImportDone(String name) {
    return 'Lista «$name» importada';
  }

  @override
  String logImportReady(String name) {
    return 'Lista «$name» lista';
  }

  @override
  String get logImportFailed => 'Importación fallida';

  @override
  String get logImportRate => 'Importación frenada por YouTube';

  @override
  String get logImportPaused => 'Importación en pausa';

  @override
  String get logWhyToolMissing =>
      'Falta el componente para descargar de YouTube.';

  @override
  String get logWhyToolOld =>
      'El componente para descargar de YouTube es demasiado antiguo.';

  @override
  String get logWhyNetwork => 'Red no disponible.';

  @override
  String get logWhyRate => 'YouTube pidió ir más despacio.';

  @override
  String get logWhyFailing => 'Demasiados errores seguidos: la puse en pausa.';

  @override
  String get logCorrectionTitle => 'Título y artista corregidos';

  @override
  String logChipSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones',
      one: '1 canción',
    );
    return '$_temp0';
  }

  @override
  String logChipArtists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artistas',
      one: '1 artista',
    );
    return '$_temp0';
  }

  @override
  String logChipSongsOf(int done, int total) {
    return '$done de $total canciones';
  }

  @override
  String logChipUpdated(int count) {
    return '$count actualizadas';
  }

  @override
  String logChipNotFound(int count) {
    return '$count no encontradas';
  }

  @override
  String logChipNoResult(int count) {
    return '$count sin resultado';
  }

  @override
  String get logFileTitle => 'Corrección guardada, archivo sin actualizar';

  @override
  String get logHowFileMissing =>
      'Comprueba que la canción sigue en su carpeta.';

  @override
  String get logHowFileReadOnly =>
      'Quita el modo de solo lectura del archivo o de su carpeta y corrige la canción otra vez.';

  @override
  String get logHowFileRetry =>
      'Comprueba que hay espacio en el disco y que el archivo no está en uso, y corrige la canción otra vez.';

  @override
  String get logClearBody =>
      'Se borran todas las entradas y se quitan de la lista las descargas terminadas. Después ya no podrás restaurar las correcciones. Tus canciones se quedan donde están.';

  @override
  String logHowResume(String button) {
    return 'Toca «$button» en la importación en pausa, en la lista de actividades.';
  }

  @override
  String get logEnrichStopped => 'Enriquecimiento detenido';

  @override
  String logCorrectionSem(String from, String to) {
    return 'De $from a $to';
  }

  @override
  String get smartAll => 'Todas las condiciones';

  @override
  String get smartAny => 'Al menos una';

  @override
  String get smartAllNote => 'Las canciones deben cumplir todos los filtros.';

  @override
  String get smartAnyNote => 'Basta con que se cumpla un filtro.';

  @override
  String get smartAddFilter => 'Añadir filtro';

  @override
  String get smartGroupMusic => 'Música';

  @override
  String get smartGroupListening => 'Escucha';

  @override
  String get smartGroupFile => 'Archivo';

  @override
  String get smartFieldTag => 'Etiquetas';

  @override
  String get smartFieldAlbumArtist => 'Artista del álbum';

  @override
  String get smartFieldCountry => 'Nacionalidad';

  @override
  String get smartFieldPlays => 'Reproducciones';

  @override
  String get smartFieldLastPlayed => 'Última reproducción';

  @override
  String get smartFieldAdded => 'Añadido';

  @override
  String get smartFieldBitrate => 'Tasa de bits';

  @override
  String get smartFieldFolder => 'Carpeta';

  @override
  String get smartFlagLyrics => 'Con letra';

  @override
  String get smartEnrichedOnly => 'Solo para canciones enriquecidas';

  @override
  String get smartInclude => 'Incluir';

  @override
  String get smartExclude => 'Excluir';

  @override
  String get smartPickValues => 'Elegir valores';

  @override
  String get smartAddValue => 'Añadir';

  @override
  String get smartValueHint => 'Escribe un valor';

  @override
  String get smartDone => 'Hecho';

  @override
  String get smartIncomplete =>
      'Incompleto: complétalo o quítalo para guardar.';

  @override
  String get smartRemoveFilter => 'Quitar filtro';

  @override
  String smartRemoveValue(String value) {
    return 'Quitar $value';
  }

  @override
  String get smartFrom => 'Desde';

  @override
  String get smartTo => 'Hasta';

  @override
  String get smartMoreThan => 'Más de';

  @override
  String get smartLessThan => 'Menos de';

  @override
  String get smartEqualTo => 'Igual a';

  @override
  String get smartAgeRecent => 'En los últimos';

  @override
  String get smartAgeOlder => 'Hace más de';

  @override
  String get smartDays => 'días';

  @override
  String get smartMinutes => 'minutos';

  @override
  String get smartContains => 'Que contenga';

  @override
  String get smartAdvancedNote => 'El texto de la regla, solo lectura.';

  @override
  String get smartNotVisual =>
      'Esta regla es demasiado compleja para el editor de filtros. Se queda como está: la ves en Avanzado y, si la guardas sin tocarla, no cambia.';

  @override
  String get smartNoFilters => 'Añade un filtro para empezar.';

  @override
  String get smartLimitShort => 'Límite';

  @override
  String get smartIs => 'Es';

  @override
  String get smartRestart => 'Empezar de nuevo con filtros';

  @override
  String get smartRestarted => 'Regla borrada';

  @override
  String get smartCountError => 'Recuento no disponible';

  @override
  String artistMergedNote(int count) {
    return '$count perfiles unidos';
  }

  @override
  String get artistSplit => 'Separar perfiles';

  @override
  String get artistMergeWith => 'Unir con…';

  @override
  String artistSameWarn(String name) {
    return 'Parece el mismo artista que otro perfil ($name).';
  }

  @override
  String get artistMergeYes => 'Unir';

  @override
  String get artistNotSame => 'Son distintos';

  @override
  String get artistMerged => 'Perfiles unidos.';

  @override
  String get artistSplitDone => 'Perfiles separados.';

  @override
  String get artistNotSameDone =>
      'De acuerdo, no volveré a preguntar por estos dos perfiles.';

  @override
  String get artistMergePick => '¿Con qué perfil?';

  @override
  String get mergedSheetTitle => 'Perfiles unidos';

  @override
  String get artistMainProfile => 'Principal';

  @override
  String artistOtherProfileOf(String name) {
    return 'Otro perfil de $name';
  }

  @override
  String get artistSeparate => 'Separar';

  @override
  String get artistSeparated => 'Perfil separado.';

  @override
  String get settingsMergedArtists => 'Artistas unidos';

  @override
  String get settingsMergedArtistsHint =>
      'Ve los perfiles unidos y sepáralos, o quita las marcas de «distintos».';

  @override
  String get mergedArtistsEmpty => 'Ningún artista unido.';

  @override
  String get mergedArtistsEmptyHelp =>
      'Cuando unes dos perfiles del mismo artista, aparecen aquí.';

  @override
  String get mergedArtistsSplitAll => 'Separar todo';

  @override
  String get notSameTitle => 'Marcados como distintos';

  @override
  String get notSameRemove => 'Quitar';

  @override
  String get notSameEmpty => 'Ningún par está marcado como distinto.';

  @override
  String get openArtistPage => 'Abrir la página del artista';

  @override
  String get podcastYours => 'Tus podcasts';

  @override
  String get podcastDiscover => 'Descubrir';

  @override
  String get podcastChartTitle => 'Lista de Apple Podcasts, Italia';

  @override
  String get podcastGenreAll => 'Todos';

  @override
  String get podcastSearchLens => 'Buscar podcasts';

  @override
  String get podcastSubscribedLabel => 'Suscrito';

  @override
  String get podcastOriginApple => 'Apple Podcasts';

  @override
  String get podcastChartError =>
      'La lista no responde. Pasa, no es culpa tuya.';

  @override
  String get podcastNoFeed => 'Apple no tiene un feed para este podcast.';

  @override
  String get podcastGenreArts => 'Arte';

  @override
  String get podcastGenreBusiness => 'Negocios';

  @override
  String get podcastGenreComedy => 'Comedia';

  @override
  String get podcastGenreEducation => 'Educación';

  @override
  String get podcastGenreKids => 'Niños y familia';

  @override
  String get podcastGenreHealth => 'Salud y bienestar';

  @override
  String get podcastGenreTvFilm => 'TV y cine';

  @override
  String get podcastGenreMusic => 'Música';

  @override
  String get podcastGenreNews => 'Noticias';

  @override
  String get podcastGenreReligion => 'Religión y espiritualidad';

  @override
  String get podcastGenreScience => 'Ciencia';

  @override
  String get podcastGenreSports => 'Deportes';

  @override
  String get podcastGenreTechnology => 'Tecnología';

  @override
  String get podcastGenreSociety => 'Sociedad y cultura';

  @override
  String get podcastGenreGovernment => 'Gobierno';

  @override
  String get podcastGenreHistory => 'Historia';

  @override
  String get podcastGenreTrueCrime => 'True crime';

  @override
  String podcastSubscribeTo(String name) {
    return 'Suscribirse a $name';
  }

  @override
  String get searchSimilarLooking => 'Buscando canciones similares…';

  @override
  String searchSimilarQueued(String title) {
    return 'Cola: «$title» y canciones similares';
  }

  @override
  String searchSimilarNone(String title) {
    return 'Sin canciones similares: suena solo «$title»';
  }

  @override
  String get searchSeeQueue => 'Ver cola';

  @override
  String queueSimilarTo(String title) {
    return 'Similares a «$title»';
  }

  @override
  String get queueSimilarTag => 'radio de YouTube Music';

  @override
  String queueSimilarCount(int total, int owned) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total canciones',
      one: '1 canción',
    );
    return '$_temp0, $owned ya en la biblioteca';
  }

  @override
  String get queueSimilarSearching => 'Buscando canciones similares…';

  @override
  String get dislikeSheetTitle => '¿No te gusta la canción o el artista?';

  @override
  String get dislikeSheetTrack => 'Solo esta canción';

  @override
  String dislikeSheetTrackHint(String title) {
    return '«$title» no vuelve, salvo que se parezca mucho a lo que escuchas.';
  }

  @override
  String dislikeSheetArtist(String artist) {
    return 'Todo $artist';
  }

  @override
  String dislikeSheetArtistHint(String artist) {
    return 'Ninguna canción de $artist se te sugerirá más.';
  }

  @override
  String dislikeArtistDone(String artist) {
    return '$artist no se te sugerirá más';
  }

  @override
  String get artistBlockedLabel => 'Artista bloqueado';

  @override
  String dislikesBlockedOn(String date) {
    return 'Excluido el $date';
  }

  @override
  String get podcastFollow => 'Seguir';

  @override
  String get podcastFollowing => 'Siguiendo';

  @override
  String podcastFollowLabel(String name) {
    return 'Seguir $name';
  }

  @override
  String podcastUnfollowLabel(String name) {
    return 'Dejar de seguir $name';
  }

  @override
  String get podcastPreviewNote =>
      'Vista previa: aún no lo sigues. Los episodios se escuchan en streaming.';

  @override
  String get podcastPreviewFollowed =>
      'Ahora está en tus podcasts. El punto de reanudación sigue guardado.';

  @override
  String get podcastFollowedMsg => 'Añadido a tus podcasts';

  @override
  String get podcastUnfollowedMsg =>
      'Ya no lo sigues. Los episodios se siguen pudiendo escuchar';

  @override
  String podcastPlayStream(String title) {
    return 'Reproducir en streaming: $title';
  }

  @override
  String get podcastStreamUnavailable =>
      'Este podcast aún no se puede escuchar en streaming.';

  @override
  String get podcastUnfollowTitle => '¿Dejar de seguir?';

  @override
  String podcastUnfollowBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Tienes $count episodios descargados. ¿Quieres conservarlos o borrarlos?',
      one: 'Tienes 1 episodio descargado. ¿Quieres conservarlo o borrarlo?',
    );
    return '$_temp0';
  }

  @override
  String get podcastKeepDownloads => 'Conservar';

  @override
  String get podcastDeleteDownloads => 'Borrar';
}
