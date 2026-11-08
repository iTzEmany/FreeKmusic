// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appName => 'Codecore';

  @override
  String get chooseFolder => 'Escolher pasta';

  @override
  String get scan => 'Analisar';

  @override
  String get noTracks => 'Nenhuma faixa. Escolha uma pasta e analise.';

  @override
  String get openSettings => 'Abrir definições';

  @override
  String get permissionDenied => 'Permissão de leitura de áudio recusada';

  @override
  String get permissionExplain =>
      'O Codecore precisa de permissão para ler os ficheiros de áudio e mostrar a sua música.';

  @override
  String get navLibrary => 'Biblioteca';

  @override
  String get navFavorites => 'Favoritos';

  @override
  String get navPlaylists => 'Playlists';

  @override
  String get navSettings => 'Definições';

  @override
  String get tracks => 'Faixas';

  @override
  String get albums => 'Álbuns';

  @override
  String get artists => 'Artistas';

  @override
  String get searchHint => 'Pesquisar';

  @override
  String get clearSearch => 'Limpar pesquisa';

  @override
  String get sortBy => 'Ordenar por';

  @override
  String get addMusicFolder => 'Adicione a sua pasta de música';

  @override
  String get addFolder => 'Adicionar pasta';

  @override
  String get folders => 'Pastas de música';

  @override
  String get refreshLibrary => 'Atualizar biblioteca';

  @override
  String get removeFolder => 'Remover pasta';

  @override
  String get unknownArtist => 'Artista desconhecido';

  @override
  String get unknownAlbum => 'Álbum desconhecido';

  @override
  String get variousArtists => 'Vários artistas';

  @override
  String get play => 'Reproduzir';

  @override
  String get shuffle => 'Aleatório';

  @override
  String get queue => 'Fila';

  @override
  String get nowPlaying => 'A reproduzir';

  @override
  String get nothingPlaying => 'Nenhuma faixa a reproduzir';

  @override
  String get mute => 'Silenciar';

  @override
  String get scanning => 'A analisar…';

  @override
  String get emptyQueue => 'A fila está vazia';

  @override
  String get noResults => 'Sem resultados';

  @override
  String get sortDefault => 'Predefinido';

  @override
  String get sortPersonal => 'Ordem pessoal';

  @override
  String get sortTitle => 'Título';

  @override
  String get sortArtist => 'Artista';

  @override
  String get sortAlbum => 'Álbum';

  @override
  String get sortYear => 'Ano';

  @override
  String get sortAdded => 'Adicionados recentemente';

  @override
  String get sortDuration => 'Duração';

  @override
  String tracksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas',
      one: '1 faixa',
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
      other: '$countString álbuns',
      one: '1 álbum',
    );
    return '$_temp0';
  }

  @override
  String get libraryAll => 'Tudo';

  @override
  String libraryItemsCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString itens',
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
    return '$hours e $minutes';
  }

  @override
  String get collectionNoTracks => 'Nenhuma faixa';

  @override
  String missingTracksCount(int count) {
    return 'Faixas não encontradas ($count)';
  }

  @override
  String get addedToFavorites => 'Adicionada aos favoritos';

  @override
  String get removedFromFavorites => 'Removida dos favoritos';

  @override
  String get undo => 'Anular';

  @override
  String get favoritesEmptyTitle => 'Ainda não há favoritos';

  @override
  String get favoritesEmptyHelp =>
      'Toque no coração de uma música e ela aparece aqui.';

  @override
  String get openAllTracks => 'Abrir todas as músicas';

  @override
  String get newPlaylist => 'Nova playlist';

  @override
  String get newPlaylistEllipsis => 'Nova playlist…';

  @override
  String get playlistName => 'Nome da playlist';

  @override
  String get create => 'Criar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get delete => 'Eliminar';

  @override
  String get rename => 'Mudar o nome';

  @override
  String get noPlaylists => 'Sem playlists. Crie uma.';

  @override
  String get addToPlaylist => 'Adicionar à playlist…';

  @override
  String addedToPlaylist(String name) {
    return 'Adicionada a «$name»';
  }

  @override
  String get playNext => 'Reproduzir a seguir';

  @override
  String get addToQueue => 'Adicionar à fila';

  @override
  String get addedToQueue => 'Adicionada à fila';

  @override
  String get favorite => 'Favorito';

  @override
  String get removeFromFavorites => 'Remover dos favoritos';

  @override
  String get removeFromList => 'Remover';

  @override
  String get editInfo => 'Editar info';

  @override
  String get details => 'Detalhes';

  @override
  String get showInFolder => 'Mostrar na pasta';

  @override
  String get detailPath => 'Caminho';

  @override
  String get detailFormat => 'Formato';

  @override
  String get detailSize => 'Tamanho';

  @override
  String get detailDuration => 'Duração';

  @override
  String get detailAdded => 'Adicionada em';

  @override
  String get detailPlays => 'Reproduções';

  @override
  String get close => 'Fechar';

  @override
  String get fieldTitle => 'Título';

  @override
  String get fieldArtist => 'Artista';

  @override
  String get fieldAlbum => 'Álbum';

  @override
  String get fieldAlbumArtist => 'Artista do álbum';

  @override
  String get fieldYear => 'Ano';

  @override
  String get fieldTrackNumber => 'Número da faixa';

  @override
  String get fieldGenre => 'Género';

  @override
  String get restoreFromFile => 'Restaurar a partir das tags do ficheiro';

  @override
  String get titleRequired => 'O título não pode estar vazio';

  @override
  String get settingsAppearance => 'Aspeto';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get themeNotte => 'Noite violeta';

  @override
  String get themeOled => 'Preto puro';

  @override
  String get settingsTextSize => 'Tamanho do texto';

  @override
  String get textSmall => 'Pequeno';

  @override
  String get textNormal => 'Normal';

  @override
  String get textLarge => 'Grande';

  @override
  String get settingsCompact => 'Modo compacto';

  @override
  String get settingsReducedMotion => 'Animações reduzidas';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsLibrary => 'Biblioteca';

  @override
  String get rescanNow => 'Analisar novamente';

  @override
  String get clearCoverCache => 'Limpar cache das capas';

  @override
  String get coverCacheCleared => 'Cache das capas limpa';

  @override
  String get settingsOnline => 'Online';

  @override
  String get settingsPageAppearance => 'Aspeto e idioma';

  @override
  String get settingsPagePlayback => 'Reprodução';

  @override
  String get settingsPageLibrary => 'Biblioteca';

  @override
  String get settingsPageOnline => 'Online e transferências';

  @override
  String get settingsPageNetwork => 'Rede e dispositivos';

  @override
  String get settingsPageBackup => 'Cópia de segurança';

  @override
  String get settingsPageAdvanced => 'Avançado e informações';

  @override
  String summaryLibrary(int folders, int tracks) {
    String _temp0 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: '$folders pastas',
      one: '1 pasta',
    );
    String _temp1 = intl.Intl.pluralLogic(
      tracks,
      locale: localeName,
      other: '$tracks faixas',
      one: '1 faixa',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String summaryTrusted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dispositivos de confiança',
      one: '1 dispositivo de confiança',
    );
    return '$_temp0';
  }

  @override
  String get summaryNormalizeOn => 'normalização ativada';

  @override
  String get summaryBackup => 'Exportar e restaurar a biblioteca';

  @override
  String summaryCrossfade(int seconds) {
    return '$seconds s';
  }

  @override
  String get openPlaybackSettings => 'Abrir Reprodução';

  @override
  String get autoEnrich => 'Enriquecimento automático';

  @override
  String get autoEnrichHint =>
      'Pesquisa metadados e capas online para as faixas novas';

  @override
  String get autoLyrics => 'Letras automáticas';

  @override
  String get autoLyricsHint =>
      'Descarrega as letras do LRCLIB para as faixas novas';

  @override
  String get settingsAbout => 'Acerca de';

  @override
  String appVersion(String version) {
    return 'Versão $version';
  }

  @override
  String get licenses => 'Licenças';

  @override
  String get personalUse => 'App para uso pessoal';

  @override
  String get missingTracksTitle => 'Faixas não encontradas';

  @override
  String get removeFromLibrary => 'Remover da biblioteca';

  @override
  String get ignore => 'Ignorar';

  @override
  String get confirmRemoveTitle => 'Remover da biblioteca?';

  @override
  String get confirmRemoveBody =>
      'O ficheiro não é alterado; perde os favoritos e as playlists desta faixa.';

  @override
  String get noMissingTracks => 'Nenhuma faixa em falta';

  @override
  String get retry => 'Tentar novamente';

  @override
  String scanFailed(String error) {
    return 'Falha na análise: $error';
  }

  @override
  String playbackError(String reason, String title) {
    return 'Não é possível reproduzir «$title»: $reason';
  }

  @override
  String get reasonFileMissing => 'ficheiro não encontrado';

  @override
  String get reasonUnplayable => 'ficheiro não reproduzível';

  @override
  String get reasonNotInLibrary => 'faixa não presente na biblioteca';

  @override
  String get reasonOnlineUnavailable => 'faixa online não disponível';

  @override
  String get reasonAgeRestricted =>
      'restrito por idade, nenhuma faixa de áudio encontrada';

  @override
  String get searchWeb => 'Pesquisar info na web';

  @override
  String get enrichPreviewTitle => 'Pré-visualização das informações';

  @override
  String get currentValue => 'Atual';

  @override
  String get proposedValue => 'Proposto';

  @override
  String get apply => 'Aplicar';

  @override
  String get nothingFound => 'Nenhuma informação encontrada';

  @override
  String get userEditedLocked => 'Editado por si: não será substituído';

  @override
  String get fieldCover => 'Capa';

  @override
  String get fieldLyrics => 'Letra';

  @override
  String get fieldCuriosity => 'Curiosidades';

  @override
  String get enrichAlbum => 'Enriquecer álbum';

  @override
  String get enrichLibrary => 'Enriquecer toda a biblioteca';

  @override
  String enrichRunning(int done, int total) {
    return 'Enriquecimento $done/$total';
  }

  @override
  String enrichResult(int notFound, int updated) {
    return '$updated atualizadas, $notFound não encontradas';
  }

  @override
  String get enrichBusy => 'Já existe um enriquecimento em curso';

  @override
  String get enrichNothingToDo =>
      'Nada para completar: não falta nada às músicas';

  @override
  String get serviceUnavailable =>
      'Serviço indisponível, tente novamente mais tarde';

  @override
  String get lyrics => 'Letra';

  @override
  String get searchLyrics => 'Pesquisar letra';

  @override
  String get noLyrics => 'Nenhuma letra disponível';

  @override
  String get lyricsNotFound => 'Letra não encontrada';

  @override
  String get copy => 'Copiar';

  @override
  String get copied => 'Copiado';

  @override
  String get sourceWikipedia => 'Fonte: Wikipédia (CC BY-SA)';

  @override
  String get youtube => 'YouTube';

  @override
  String get ytHint => 'Pesquise ou cole um link';

  @override
  String get ytDownload => 'Descarregar';

  @override
  String get listenAction => 'Ouvir';

  @override
  String get ytAlreadyInLibrary => 'Já na biblioteca';

  @override
  String get ytNoResults => 'Sem resultados';

  @override
  String get ytQueued => 'Na fila';

  @override
  String get ytDownloading => 'A descarregar';

  @override
  String get ytDone => 'Concluído';

  @override
  String get ytFailed => 'Falhou';

  @override
  String get ytCancelled => 'Cancelado';

  @override
  String get ytClearCompleted => 'Limpar concluídos';

  @override
  String get ytCancel => 'Cancelar transferência';

  @override
  String get ytErrUnavailable => 'Vídeo indisponível (idade/região/privado)';

  @override
  String get ytErrNetwork => 'Rede indisponível';

  @override
  String get ytErrChanged =>
      'O YouTube mudou alguma coisa: atualize a app ou o pacote';

  @override
  String get ytNoFolder => 'Adicione primeiro uma pasta de música';

  @override
  String get ytLegal =>
      'Apenas para uso pessoal. Respeite os direitos de autor e os termos do YouTube.';

  @override
  String get useDefaultFolder => 'Usar a pasta Música do dispositivo';

  @override
  String get ytErrToolMissing =>
      'yt-dlp não encontrado: instale-o (pip install -U yt-dlp) e tente novamente';

  @override
  String get ytErrRateLimited =>
      'O YouTube pediu para abrandar: tente novamente dentro de alguns minutos';

  @override
  String get playlistChangeCover => 'Alterar capa';

  @override
  String get playlistRemoveCover => 'Remover capa';

  @override
  String get coverTooLarge => 'Imagem demasiado grande (máx. 4 MB)';

  @override
  String get addSongs => 'Adicionar faixas';

  @override
  String addNSongs(int count) {
    return 'Adicionar ($count)';
  }

  @override
  String get allSongsInPlaylist => 'Todas as faixas já estão na playlist';

  @override
  String get shareTitle => 'Partilha';

  @override
  String get shareSend => 'Enviar';

  @override
  String get shareReceive => 'Receber';

  @override
  String get shareAll => 'Toda a biblioteca';

  @override
  String shareSelection(int count) {
    return 'Seleção ($count faixas)';
  }

  @override
  String get sharePick => 'Escolher faixas';

  @override
  String get shareStart => 'Iniciar partilha';

  @override
  String get shareStop => 'Parar';

  @override
  String get shareActive => 'Partilha ativa';

  @override
  String get shareAddress => 'Endereço (IP:porta)';

  @override
  String get sharePin => 'PIN';

  @override
  String get shareConnect => 'Ligar';

  @override
  String shareDownloadSelected(int count) {
    return 'Descarregar selecionadas ($count)';
  }

  @override
  String shareProgress(int done, int total) {
    return 'Faixa $done de $total';
  }

  @override
  String shareDone(int count) {
    return '$count faixas recebidas';
  }

  @override
  String shareConnectedTo(String name) {
    return 'Ligado a $name';
  }

  @override
  String get shareErrUnreachable =>
      'Dispositivo inacessível: verifique o endereço e o Wi‑Fi';

  @override
  String get shareErrPin => 'PIN incorreto';

  @override
  String get shareErrBlocked =>
      'Demasiadas tentativas: tente novamente dentro de um minuto';

  @override
  String get shareErrNotCodecore => 'Não é um dispositivo Codecore';

  @override
  String get shareErrFailed => 'Falha na transferência';

  @override
  String get shareNoNetwork => 'Nenhuma rede local encontrada';

  @override
  String get shareFirewall =>
      'O Windows pode pedir autorização da firewall na primeira partilha.';

  @override
  String get shareHint =>
      'Na mesma rede Wi‑Fi, abra «Receber» no outro dispositivo e introduza o endereço e o PIN.';

  @override
  String get shareMenu => 'Partilhar…';

  @override
  String get shareDeviceName => 'Nome do dispositivo';

  @override
  String get sleepTimer => 'Temporizador de repouso';

  @override
  String sleepMinutes(int count) {
    return '$count minutos';
  }

  @override
  String get sleepEndOfTrack => 'No fim da faixa';

  @override
  String get sleepCancel => 'Cancelar temporizador';

  @override
  String get pause => 'Pausa';

  @override
  String get nextTrack => 'Faixa seguinte';

  @override
  String get previousTrack => 'Faixa anterior';

  @override
  String get repeat => 'Repetir';

  @override
  String get moreOptions => 'Mais opções';

  @override
  String get back => 'Voltar';

  @override
  String get seekPosition => 'Posição na faixa';

  @override
  String get settingsPlayback => 'Reprodução';

  @override
  String get normalizeVolume => 'Normalizar volume';

  @override
  String get normalizeVolumeHint =>
      'Usa o ReplayGain dos ficheiros para reduzir as faixas demasiado altas';

  @override
  String get nearbyDevices => 'Dispositivos próximos';

  @override
  String get searchingDevices => 'A procurar dispositivos na rede…';

  @override
  String get noDevicesHint =>
      'Nenhum dispositivo encontrado. Abra também a Partilha no outro dispositivo, na mesma rede.';

  @override
  String sendToDevice(String name) {
    return 'Enviar para $name';
  }

  @override
  String offerSent(String name) {
    return 'Pedido enviado a $name';
  }

  @override
  String get offerChooseFirst => 'Escolha primeiro as faixas a enviar';

  @override
  String get sentRequests => 'Pedidos enviados';

  @override
  String get receivedRequests => 'Pedidos recebidos';

  @override
  String get offerPending => 'A aguardar resposta';

  @override
  String get offerAccepted => 'Aceite';

  @override
  String get offerDeclined => 'Recusada';

  @override
  String get offerCancelled => 'Cancelada';

  @override
  String get offerExpired => 'Expirada';

  @override
  String get offerDone => 'Concluída';

  @override
  String get offerFailed => 'Falhada';

  @override
  String incomingTitle(String name) {
    return '$name quer enviar-lhe faixas';
  }

  @override
  String incomingBody(int count, String size) {
    return '$count faixas, $size MB';
  }

  @override
  String get accept => 'Aceitar';

  @override
  String get decline => 'Recusar';

  @override
  String receivingProgress(int done, int total) {
    return 'A receber $done/$total';
  }

  @override
  String get manualConnection => 'Ligação manual (IP e PIN)';

  @override
  String get receiveFromLan => 'Receber da rede local';

  @override
  String get receiveFromLanHint =>
      'Torna o dispositivo visível e recebe pedidos mesmo em segundo plano. No Android mostra uma notificação fixa com a qual pode desativá-lo';

  @override
  String get receiveServiceTitle => 'O Codecore está visível na rede';

  @override
  String get receiveServiceText =>
      'Pronto para receber faixas de dispositivos próximos';

  @override
  String get receiveServiceDisable => 'Desativar';

  @override
  String get jamTitle => 'Jam';

  @override
  String get jamStart => 'Iniciar uma Jam';

  @override
  String jamStartWith(String name) {
    return 'Iniciar Jam com $name';
  }

  @override
  String jamWaiting(String name) {
    return 'A aguardar que $name aceite…';
  }

  @override
  String jamDeclined(String name) {
    return '$name recusou a Jam';
  }

  @override
  String jamBusy(String name) {
    return '$name já tem uma Jam em curso';
  }

  @override
  String get jamUnreachable => 'Dispositivo inacessível';

  @override
  String jamIncomingTitle(String name) {
    return '$name quer iniciar uma Jam';
  }

  @override
  String get jamIncomingBody => 'Ouçam juntos a partir de uma fila partilhada.';

  @override
  String get jamIncomingDialog =>
      'A música toca neste dispositivo e ambos podem adicionar faixas.';

  @override
  String get jamQueue => 'Fila partilhada';

  @override
  String get jamModeHost => 'Fila do anfitrião';

  @override
  String get jamModeTogether => 'Fila conjunta';

  @override
  String get jamModeGuestHint => 'O anfitrião escolhe o modo da fila';

  @override
  String get jamSuggested => 'Sugerido';

  @override
  String get jamEmpty =>
      'Ponha faixas na fila a partir da biblioteca ou da pesquisa';

  @override
  String jamOnlineFailed(String title) {
    return 'Não foi possível adicionar «$title» à Jam';
  }

  @override
  String jamAddedBy(String name) {
    return 'adicionada por $name';
  }

  @override
  String get jamJumpHere => 'Saltar para aqui';

  @override
  String get jamYou => 'si';

  @override
  String get jamGuest => 'Convidado';

  @override
  String get jamAddToJam => 'Adicionar à Jam';

  @override
  String jamAdded(int count) {
    return 'Adicionadas à Jam: $count';
  }

  @override
  String get jamOutput => 'Saída de áudio';

  @override
  String get jamOutputHere => 'Este dispositivo';

  @override
  String jamOutputOther(String name) {
    return '$name';
  }

  @override
  String get jamEnd => 'Terminar Jam';

  @override
  String get jamLeave => 'Sair da Jam';

  @override
  String get jamEnded => 'A Jam terminou';

  @override
  String get jamLost => 'Ligação perdida';

  @override
  String get jamGuestCannotSkip => 'Só quem iniciou a Jam pode mudar de faixa';

  @override
  String get jamRemoveForbidden => 'Só pode remover as suas faixas';

  @override
  String get jamNothingPlaying => 'Nada a reproduzir';

  @override
  String jamWith(String name) {
    return 'Jam com $name';
  }

  @override
  String get jamUnavailable => 'Indisponível';

  @override
  String get jamPlaying => 'A Jam está ativa';

  @override
  String get jamOpen => 'Abrir a Jam';

  @override
  String jamSynced(int ms) {
    return 'Sincronizado, desvio $ms ms';
  }

  @override
  String get jamSyncing => 'A sincronizar…';

  @override
  String jamLatency(int ms) {
    return 'Latência desta saída: $ms ms';
  }

  @override
  String get jamLatencyHint =>
      'Para auscultadores ou colunas Bluetooth: aumente até as saídas soarem em sincronia.';

  @override
  String get jamOutputsHint => 'Várias saídas tocam em simultâneo';

  @override
  String get renamePlaylist => 'Mudar o nome da playlist';

  @override
  String get confirmDeletePlaylistTitle => 'Eliminar a playlist?';

  @override
  String confirmDeletePlaylistBody(String name) {
    return '«$name» será eliminada. As faixas permanecem na biblioteca.';
  }

  @override
  String get confirmRemoveFolderTitle => 'Remover a pasta?';

  @override
  String get confirmRemoveFolderBody =>
      'As faixas desta pasta desaparecem da biblioteca. Os ficheiros permanecem no dispositivo.';

  @override
  String get confirmClearCoversTitle => 'Limpar a cache das capas?';

  @override
  String get confirmClearCoversBody =>
      'As capas serão recriadas na próxima análise.';

  @override
  String get confirmRestoreTitle => 'Restaurar a partir das tags do ficheiro?';

  @override
  String get confirmRestoreBody =>
      'As suas alterações a esta faixa serão substituídas pelos dados do ficheiro.';

  @override
  String get removedFromPlaylist => 'Removida da playlist';

  @override
  String get removedFromQueue => 'Removida da fila';

  @override
  String get playNextDone => 'Será reproduzida a seguir';

  @override
  String get ytSearchPrompt => 'Pesquise uma faixa ou cole um link';

  @override
  String get loadFailed => 'Não foi possível carregar os dados.';

  @override
  String get artistLoadingSongs => 'A carregar músicas…';

  @override
  String get artistTopMissing => 'Top indisponível';

  @override
  String get navHome => 'Início';

  @override
  String get navSearch => 'Pesquisar';

  @override
  String get devicesTitle => 'Dispositivos';

  @override
  String get devicesJamActive => 'Jam ativa';

  @override
  String jamPeople(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Jam, $n pessoas',
      one: 'Jam, 1 pessoa',
    );
    return '$_temp0';
  }

  @override
  String get devicesVisibleTitle => 'Tornar este dispositivo visível';

  @override
  String get devicesVisibleHint =>
      'Para receber faixas ou fazer uma Jam, os outros dispositivos têm de o poder ver na rede.';

  @override
  String get devicesJamShort => 'Jam';

  @override
  String get devicesSendShort => 'Enviar';

  @override
  String get devicesMore => 'Partilha e ligação manual';

  @override
  String jamParticipantsCount(int n) {
    return '$n pessoas';
  }

  @override
  String get playingFrom => 'A reproduzir de';

  @override
  String get playContextSearch => 'Pesquisa';

  @override
  String get allTracks => 'Todas as faixas';

  @override
  String get trackInfo => 'Informações da faixa';

  @override
  String get searchCuriosity => 'Pesquisar curiosidades';

  @override
  String get upNext => 'A seguir';

  @override
  String get openQueue => 'Abrir fila';

  @override
  String get copyLink => 'Copiar link';

  @override
  String get moreActions => 'Mais ações';

  @override
  String get sleepChipEnd => 'fim da faixa';

  @override
  String get yourLibrary => 'A sua biblioteca';

  @override
  String playlistCountLabel(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Playlist com $n faixas',
      one: 'Playlist com 1 faixa',
    );
    return '$_temp0';
  }

  @override
  String get sortRecent => 'Ouvidos recentemente';

  @override
  String get sortAlphabetical => 'Alfabética';

  @override
  String get sortAToZ => 'A–Z';

  @override
  String get sortAddedRecently => 'Adicionados recentemente';

  @override
  String get sortTitleAToZ => 'Título A–Z';

  @override
  String get sortMostPlayed => 'Mais ouvidas';

  @override
  String get sortTrackCount => 'Número de faixas';

  @override
  String get sortRecentShort => 'Recentes';

  @override
  String get sortAddedShort => 'Adicionados';

  @override
  String get sortTrackCountShort => 'Faixas';

  @override
  String get sortMostPlayedShort => 'Mais ouvidas';

  @override
  String get sortAscending => 'Crescente';

  @override
  String get sortDescending => 'Decrescente';

  @override
  String get viewAsGrid => 'Ver em grelha';

  @override
  String get viewAsList => 'Ver em lista';

  @override
  String get kindAlbum => 'Álbum';

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
  String get mostPlayed => 'Mais ouvidos';

  @override
  String get albumsSection => 'Álbuns';

  @override
  String get addAllToQueue => 'Adicionar à fila';

  @override
  String addedNToQueue(int n) {
    return '$n faixas adicionadas à fila';
  }

  @override
  String get editOrder => 'Editar ordem';

  @override
  String get finishEditing => 'Concluir';

  @override
  String get removeFromPlaylistAction => 'Remover da playlist';

  @override
  String get noTracksInPlaylist => 'Esta playlist está vazia';

  @override
  String get greetingMorning => 'Bom dia';

  @override
  String get greetingAfternoon => 'Boa tarde';

  @override
  String get greetingEvening => 'Boa noite';

  @override
  String get homeResume => 'Retomar';

  @override
  String get homeTopTracks => 'Os mais ouvidos';

  @override
  String get homeRediscover => 'Para redescobrir';

  @override
  String get homeShuffleAll => 'Aleatório com tudo';

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
      zero: 'menos de uma hora',
    );
    return '$_temp0';
  }

  @override
  String get homeAddedLately => 'Adicionados há pouco';

  @override
  String homeResumeQueue(int n, int m) {
    return 'Faixa $n de $m';
  }

  @override
  String homeResumeQueueFrom(String source, int n, int m) {
    return '$source: faixa $n de $m';
  }

  @override
  String homeMinutesLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Faltam $count minutos',
      one: 'Falta 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String get homeFanOpen => 'Mostrar as músicas adicionadas recentemente';

  @override
  String get showAll => 'Todos';

  @override
  String get recentSearches => 'Pesquisas recentes';

  @override
  String get genresTitle => 'Géneros';

  @override
  String downloadsChip(int n) {
    return 'Transferências ($n)';
  }

  @override
  String get gotIt => 'Entendido';

  @override
  String get searchEmptyLibrary => 'Nenhum resultado na biblioteca';

  @override
  String get ytInfoTooltip => 'Informações sobre a utilização';

  @override
  String removeRecentSearch(String query) {
    return 'Remover «$query» das pesquisas recentes';
  }

  @override
  String get groupGoTo => 'Ir para';

  @override
  String get goToAlbum => 'Ir para o álbum';

  @override
  String get goToArtist => 'Ir para o artista';

  @override
  String get groupQueue => 'Fila';

  @override
  String get groupCollection => 'Coleção';

  @override
  String get groupEdit => 'Editar';

  @override
  String get groupOther => 'Outros';

  @override
  String get queueNowPlaying => 'A reproduzir';

  @override
  String get queueNext => 'A seguir';

  @override
  String get queueClear => 'Limpar';

  @override
  String get queueCleared => 'Fila limpa';

  @override
  String get queueRebuilt => 'Fila recriada a partir da lista em reprodução';

  @override
  String get jamOutputsAndSync => 'Saídas e sincronização';

  @override
  String get jamHostTag => 'anfitrião';

  @override
  String get jamSeekInvalid => 'Posição inválida para esta faixa';

  @override
  String get jamEndConfirmTitle => 'Terminar a Jam para todos?';

  @override
  String jamEndConfirmBody(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other:
          'Os $n convidados serão desconectados e a fila partilhada será fechada.',
      one: 'O convidado será desconectado e a fila partilhada será fechada.',
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
  String get jamWaitingEmpty => 'Nenhuma Jam em curso';

  @override
  String get activityTitle => 'Atividade';

  @override
  String activityScan(int done, int total) {
    return 'Análise: $done de $total';
  }

  @override
  String get activityScanIdle => 'Análise em curso';

  @override
  String activityEnrich(int done, int total) {
    return 'Enriquecimento: $done de $total';
  }

  @override
  String activityDownload(String title) {
    return 'Transferência, $title';
  }

  @override
  String activityTransfer(String name, int n) {
    return 'Envio para $name, $n faixas';
  }

  @override
  String get activityNone => 'Nenhuma atividade';

  @override
  String get activityCompleted => 'Concluídas';

  @override
  String get importPhaseSearching => 'A procurar…';

  @override
  String importPhaseDownloading(int percent) {
    return 'A transferir $percent %';
  }

  @override
  String importPhaseRetry(int seconds) {
    return 'Nova tentativa dentro de $seconds s';
  }

  @override
  String get importPhaseEnriching => 'A enriquecer…';

  @override
  String get importPhaseDownloadStart => 'A transferir…';

  @override
  String get importFilterAll => 'Todos';

  @override
  String get importFilterActive => 'Em curso';

  @override
  String get importFilterProblems => 'Por resolver';

  @override
  String get importFilterDone => 'Feitos';

  @override
  String get importRowsNone => 'Nenhuma faixa aqui';

  @override
  String get activityLog => 'Registo';

  @override
  String activityLogCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count eventos',
      one: '1 evento',
      zero: 'Vazio',
    );
    return '$_temp0';
  }

  @override
  String get activityLogEmpty =>
      'Nada ainda: aqui aparecem transferências, importações e envios terminados.';

  @override
  String logImport(String name) {
    return 'Importação «$name»';
  }

  @override
  String importNotificationText(int done, int total) {
    return '$done de $total';
  }

  @override
  String importNotificationPaused(int done, int total) {
    return 'Em pausa, $done de $total';
  }

  @override
  String importWaitRateLimited(String time) {
    return 'O YouTube pede uma pausa: retomo às $time';
  }

  @override
  String importWaitNetwork(String time) {
    return 'Sem rede: nova tentativa às $time';
  }

  @override
  String importPausedTitle(String name) {
    return 'Importação «$name» em pausa';
  }

  @override
  String get downloadsNotificationTitle => 'Transferências em curso';

  @override
  String downloadsNotificationText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas',
      one: '1 faixa',
    );
    return '$_temp0';
  }

  @override
  String activityRunning(int n) {
    return '$n atividades em curso';
  }

  @override
  String get settingsLocalNetwork => 'Rede local';

  @override
  String get removeAll => 'Remover todas';

  @override
  String get confirmRemoveAllTitle => 'Remover todas da biblioteca?';

  @override
  String confirmRemoveAllBody(int n) {
    return '$n faixas não encontradas serão removidas da biblioteca. Os ficheiros não são alterados; perde os favoritos e as playlists destas faixas.';
  }

  @override
  String get csvImportMenu => 'Importar do Exportify (CSV)';

  @override
  String get csvImportIntroTitle => 'Importar uma playlist';

  @override
  String get csvImportIntroSource =>
      'O ficheiro CSV é criado gratuitamente no site do Exportify — exportify.net (não é necessária nenhuma app).';

  @override
  String get csvImportStep1 =>
      'Abra https://exportify.net no navegador (também a partir do telemóvel).';

  @override
  String get csvImportStep2 =>
      'Toque em «Get Started» e inicie sessão com a sua conta Spotify.';

  @override
  String get csvImportStep3 =>
      'Junto à playlist pretendida, toque em «Export»: é descarregado um ficheiro .csv com o nome da playlist.';

  @override
  String get csvImportStep4 => 'Volte aqui e toque em «Escolher ficheiro CSV».';

  @override
  String get csvImportNote =>
      'O Codecore procura as faixas na sua biblioteca e descarrega as restantes do YouTube Music.';

  @override
  String get csvImportNoteOffline =>
      'Só serão associadas as faixas que já estão na sua biblioteca.';

  @override
  String get csvImportCopy => 'Copiar endereço';

  @override
  String get csvImportCopied => 'Endereço copiado';

  @override
  String get csvImportPick => 'Escolher ficheiro';

  @override
  String get csvImportNotExportify =>
      'Formato não reconhecido. Escolha um CSV (Exportify, TuneMyMusic, Soundiiz, Last.fm) ou uma playlist M3U/M3U8/XSPF.';

  @override
  String get csvImportReadFailed => 'Não foi possível ler o ficheiro.';

  @override
  String get csvImportPreviewTitle => 'Importar playlist';

  @override
  String get csvImportName => 'Nome da playlist';

  @override
  String csvImportSummary(int total, int known, int todo) {
    return '$total faixas, $known já na biblioteca, $todo por descarregar';
  }

  @override
  String csvImportSkipped(int n) {
    return '$n linhas ignoradas (podcasts ou ficheiros locais)';
  }

  @override
  String csvImportEstimate(int minutes) {
    return 'Tempo estimado: cerca de $minutes min';
  }

  @override
  String get csvImportExists => 'Já existe uma playlist com este nome';

  @override
  String get csvImportUpdate =>
      'Atualizar a existente (adiciona apenas as faixas novas)';

  @override
  String get csvImportNew => 'Criar uma nova playlist';

  @override
  String get csvImportGo => 'Importar';

  @override
  String get csvImportStarted =>
      'Importação iniciada: acompanhe-a no Centro de Atividades';

  @override
  String activityImport(String name, int done, int total) {
    return 'Importação «$name»: $done de $total';
  }

  @override
  String activityImportPaused(String name, int done, int total) {
    return 'Importação «$name»: em pausa, $done de $total';
  }

  @override
  String csvImportBanner(int done, int total, int review, int missing) {
    return 'Importação: $done de $total, $review por verificar, $missing não encontradas';
  }

  @override
  String csvImportBannerPaused(int done, int total, int review, int missing) {
    return 'Importação em pausa: $done de $total, $review por verificar, $missing não encontradas';
  }

  @override
  String get csvImportReview => 'Rever';

  @override
  String get csvImportResume => 'Retomar';

  @override
  String get csvImportPause => 'Pausa';

  @override
  String get csvImportCancelTitle => 'Cancelar a importação?';

  @override
  String get csvImportCancelBody =>
      'As faixas já descarregadas permanecem na playlist.';

  @override
  String csvImportDone(int added, int review, int missing) {
    return 'Importação concluída: $added adicionadas, $review por verificar, $missing não encontradas';
  }

  @override
  String get csvImportFailing =>
      'Demasiados erros seguidos: importação em pausa';

  @override
  String get csvImportReviewTitle => 'Rever';

  @override
  String get csvImportToReview => 'Por verificar';

  @override
  String get csvImportNotFound => 'Não encontradas';

  @override
  String get csvImportErrors => 'Com erros';

  @override
  String get csvImportRetryAll => 'Tentar todas novamente';

  @override
  String get csvImportSkip => 'Saltar';

  @override
  String get csvImportManual => 'Pesquisar manualmente';

  @override
  String get csvImportNothing => 'Nada para rever.';

  @override
  String get csvImportSearch => 'Pesquisar';

  @override
  String csvImportWanted(String title, String artist, String duration) {
    return 'Procurada: $title, $artist, $duration';
  }

  @override
  String get csvImportDownload => 'Descarregar';

  @override
  String get csvImportCancelGo => 'Cancelar importação';

  @override
  String get exportLog => 'Exportar registo';

  @override
  String get exportLogHint =>
      'Ficheiro de texto sem caminhos pessoais, endereços de rede nem PIN';

  @override
  String get exportLogDebugOnly =>
      'Disponível apenas na versão instalada (em debug o registo não é gravado em ficheiro)';

  @override
  String get exportLogNone => 'Ainda não há nenhum registo para exportar';

  @override
  String get exportLogSaved => 'Registo guardado';

  @override
  String get exportLogFailed => 'Não foi possível guardar o registo';

  @override
  String get exportPlaylist => 'Exportar…';

  @override
  String get exportPlaylistTitle => 'Exportar playlist';

  @override
  String get exportFormatM3u8 => 'M3U8, para outros leitores';

  @override
  String get exportFormatCsv => 'CSV, como o Exportify';

  @override
  String get exportFormatJson => 'JSON, formato Codecore';

  @override
  String get exportRelativePaths => 'Caminhos relativos';

  @override
  String get exportRelativeHint =>
      'Relativos à pasta comum das faixas: guarde o ficheiro aí';

  @override
  String get exportAction => 'Exportar';

  @override
  String get exportSaved => 'Playlist exportada';

  @override
  String get exportEmpty => 'A playlist está vazia';

  @override
  String get exportFailed => 'Não foi possível exportar a playlist';

  @override
  String get ytErrToolOutdated =>
      'O yt-dlp é demasiado antigo: atualize-o (Definições, Online e transferências, Atualizar) e tente novamente';

  @override
  String ytDlpOutdatedBanner(String version) {
    return 'O yt-dlp $version é demasiado antigo: as transferências podem não funcionar';
  }

  @override
  String get settingsDownloads => 'Transferências';

  @override
  String ytDlpVersion(String version) {
    return 'yt-dlp $version';
  }

  @override
  String get ytDlpUnknownVersion => 'yt-dlp não encontrado';

  @override
  String get ytDlpUpdate => 'Atualizar';

  @override
  String ytDlpUpdating(int percent) {
    return 'A atualizar… $percent%';
  }

  @override
  String ytDlpUpdated(String version) {
    return 'Atualizado para a versão $version';
  }

  @override
  String get ytDlpTooOld => 'Demasiado antigo: toque em Atualizar';

  @override
  String get ytDlpUpdateErrNetwork => 'Falha na atualização: rede inacessível';

  @override
  String get ytDlpUpdateErrHash =>
      'Atualização cancelada: o ficheiro descarregado não passou a verificação de integridade';

  @override
  String get ytDlpUpdateErrOther =>
      'Falha na atualização (detalhes no registo)';

  @override
  String get downloadParallel => 'Transferências em simultâneo';

  @override
  String get downloadParallelHint =>
      'Mais em simultâneo é mais rápido, mas o YouTube pode pedir para abrandar';

  @override
  String get downloadRateLimit => 'Limite de velocidade';

  @override
  String get downloadRateNone => 'Nenhum';

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
    return 'Transferência, $title, nova tentativa em $seconds s ($attempt/$max)';
  }

  @override
  String get downloadFormat => 'Formato das transferências';

  @override
  String get downloadFormatOriginal => 'Original (qualidade máxima)';

  @override
  String get downloadFormatOriginalHint =>
      'O áudio do YouTube sem recodificação, normalmente Opus ~160 kbps. Nem todos os leitores e autorrádios o leem.';

  @override
  String get downloadFormatM4a => 'M4A (recomendado)';

  @override
  String get downloadFormatM4aHint =>
      'Quase igual ao original, sem recodificação: rápido, leve (~1 MB/min), lê-se em todo o lado.';

  @override
  String get downloadFormatMp3High => 'MP3 320 kbps';

  @override
  String get downloadFormatMp3HighHint =>
      'Compatível com tudo. Recodificado: ligeira perda, ficheiros grandes (~2,4 MB/min), transferência mais lenta.';

  @override
  String get downloadFormatMp3Low => 'MP3 192 kbps (qualidade mínima)';

  @override
  String get downloadFormatMp3LowHint =>
      'Compatível com tudo, metade do espaço do MP3 320 (~1,4 MB/min), mas a qualidade mais baixa.';

  @override
  String get searchCacheClear => 'Limpar cache de pesquisas';

  @override
  String searchCacheCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pesquisas guardadas',
      one: '1 pesquisa guardada',
      zero: 'Vazia',
    );
    return '$_temp0';
  }

  @override
  String get searchCacheCleared => 'Cache limpa';

  @override
  String csvImportLengthOff(String found, String wanted) {
    return 'Duração diferente: $found em vez de $wanted';
  }

  @override
  String get csvImportKeep => 'Manter esta';

  @override
  String get csvImportTooBig =>
      'O ficheiro é demasiado grande para ser uma playlist (máximo 5 MB e 10 000 faixas)';

  @override
  String get csvImportAlsoAccepts =>
      'Aceita também: TuneMyMusic, Soundiiz, Last.fm (CSV), M3U/M3U8, XSPF.';

  @override
  String get csvImportPlanned =>
      'Correspondências prontas: verifique-as e descarregue';

  @override
  String get csvImportLinkOnly => 'Só associar (sem transferências)';

  @override
  String get csvImportLinkOnlyHint =>
      'Cria a playlist com o que já tem e mais nada';

  @override
  String get csvImportPlanFirst => 'Rever antes de descarregar';

  @override
  String get csvImportPlanFirstHint =>
      'Procura tudo e depois escolha o que descarregar';

  @override
  String get csvImportPlanTitle => 'Correspondências';

  @override
  String csvImportPlanGo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Descarregar $n faixas',
      one: 'Descarregar 1 faixa',
    );
    return '$_temp0';
  }

  @override
  String get csvImportPlanKnown => 'já descarregada';

  @override
  String get csvImportPlanEmpty => 'Nada para descarregar';

  @override
  String csvImportBannerPlanned(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n faixas por descarregar',
      one: '1 faixa por descarregar',
    );
    return 'Correspondências prontas: $_temp0';
  }

  @override
  String get settingsAdvanced => 'Avançadas';

  @override
  String get importSureThreshold => 'Correspondência segura a partir de';

  @override
  String get importSureThresholdHint =>
      'Acima desta pontuação, uma faixa da importação é descarregada sem perguntar';

  @override
  String get importReviewThreshold => 'Por verificar a partir de';

  @override
  String get importReviewThresholdHint =>
      'Entre esta pontuação e a segura, a faixa vai para «Por verificar»; abaixo, para «Não encontradas»';

  @override
  String get importThresholdsReset => 'Repor os valores predefinidos';

  @override
  String csvImportEstimateHours(int hours, int minutes) {
    return 'Tempo estimado: cerca de $hours h $minutes min';
  }

  @override
  String csvImportBlocks(int size) {
    return 'Importar em blocos de $size';
  }

  @override
  String csvImportBigWarning(int n) {
    return 'São $n faixas a descarregar: vai demorar horas. Em blocos, um a seguir ao outro, a ordem da playlist mantém-se correta e pode parar entre blocos.';
  }

  @override
  String get etaLessThanMinute => 'menos de 1 min';

  @override
  String etaMinutes(int minutes) {
    return 'cerca de $minutes min';
  }

  @override
  String etaHours(int hours, int minutes) {
    return 'cerca de $hours h $minutes min';
  }

  @override
  String get csvImportOwnFolder => 'Pasta para esta playlist';

  @override
  String get csvImportOwnFolderHint =>
      'Guarda as faixas descarregadas numa subpasta com o nome da playlist';

  @override
  String get csvImportNumberFiles => 'Numerar os ficheiros';

  @override
  String get csvImportNumberFilesHint =>
      '07 - Artista - Título: a pasta ouve-se na ordem certa mesmo fora do Codecore';

  @override
  String get csvImportFetchCovers => 'Procurar as capas';

  @override
  String get csvImportFetchCoversHint =>
      'Após cada transferência, procura a capa do álbum no iTunes (álbum e artista do ficheiro)';

  @override
  String get csvImportExport => 'Exportar resultado';

  @override
  String get csvImportExported => 'Resultado guardado';

  @override
  String get csvOutHeaderRow => 'Linha';

  @override
  String get csvOutHeaderTitle => 'Título';

  @override
  String get csvOutHeaderArtists => 'Artistas';

  @override
  String get csvOutHeaderAlbum => 'Álbum';

  @override
  String get csvOutHeaderDuration => 'Duração (ms)';

  @override
  String get csvOutHeaderIsrc => 'ISRC';

  @override
  String get csvOutHeaderStatus => 'Resultado';

  @override
  String get csvOutHeaderNote => 'Motivo';

  @override
  String get csvOutHeaderVideo => 'Vídeo escolhido';

  @override
  String get csvOutHeaderScore => 'Pontuação';

  @override
  String get importStatusPending => 'Por procurar';

  @override
  String get importStatusQueued => 'Na fila';

  @override
  String get importStatusDownloaded => 'Descarregada';

  @override
  String get importStatusLinked => 'Já na biblioteca';

  @override
  String get importStatusReview => 'Por verificar';

  @override
  String get importStatusNotFound => 'Não encontrada';

  @override
  String get importStatusFailed => 'Erro';

  @override
  String get importStatusSkipped => 'Saltada';

  @override
  String get importStatusPlanned => 'Planeada';

  @override
  String get importStatusRemoved => 'Removida da origem';

  @override
  String get importNoteNoResults => 'Sem resultados';

  @override
  String get importNoteLowScore => 'Correspondência pouco segura';

  @override
  String get importNoteLinkOnly => 'Só associação: não pesquisada';

  @override
  String get importNoteYoutubeOff => 'Transferências desativadas';

  @override
  String get importNoteDownloadFailed => 'Falha ao descarregar';

  @override
  String get importNoteLengthOff => 'Duração diferente da do ficheiro';

  @override
  String get importNoteUnchanged => 'Já está na playlist';

  @override
  String get csvImportSync => 'Sincronizar';

  @override
  String csvImportSyncCounts(int added, int removed) {
    return '$added novas, $removed removidas da playlist (os ficheiros permanecem)';
  }

  @override
  String get csvImportSyncChecking => 'A verificar as diferenças…';

  @override
  String get playbackSpeed => 'Velocidade de reprodução';

  @override
  String get playbackSpeedHint =>
      'O tom mantém-se o original. O temporizador de repouso conta o tempo real, não o da faixa.';

  @override
  String resumeFrom(String time) {
    return 'retomar em $time';
  }

  @override
  String get restartFromBeginning => 'Recomeçar do início';

  @override
  String get previewTrack => 'Pré-visualização de 20 s';

  @override
  String get equalizer => 'Equalizador';

  @override
  String get eqOutputSpeaker => 'Altifalante';

  @override
  String get eqOutputHeadphones => 'Auscultadores';

  @override
  String get eqHint =>
      'Cada saída memoriza a sua curva: muda sozinha quando liga os auscultadores.';

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
  String get eqReset => 'Repor';

  @override
  String get eqWaiting => 'As bandas aparecem quando a primeira faixa começa.';

  @override
  String get eqUnavailable =>
      'O equalizador não está disponível neste dispositivo.';

  @override
  String get transitionMode => 'Transição entre faixas';

  @override
  String get transitionNormal => 'Normal';

  @override
  String get transitionGapless => 'Sem pausas';

  @override
  String get transitionCrossfade => 'Fusão cruzada';

  @override
  String get transitionHint =>
      'Sem pausas funciona melhor com faixas do mesmo formato (por exemplo, todas FLAC).';

  @override
  String crossfadeLength(int seconds) {
    return 'Duração da fusão: $seconds s';
  }

  @override
  String get crossfadePlainInAlbum => 'Sem fusão dentro do mesmo álbum';

  @override
  String get crossfadePlainInAlbumHint =>
      'Dentro de um álbum as faixas seguem-se sem pausas e sem se sobreporem.';

  @override
  String get selectedRow => 'Selecionado';

  @override
  String selectedRowAt(int position) {
    return 'Selecionado, número $position';
  }

  @override
  String get curiositySong => 'Sobre a música';

  @override
  String get curiosityArtist => 'Sobre o artista';

  @override
  String get showMore => 'Mostrar mais';

  @override
  String get showLess => 'Mostrar menos';

  @override
  String get curiosityNoSong => 'Nenhuma página sobre esta música';

  @override
  String get curiosityNoArtist => 'Nenhuma página sobre o artista';

  @override
  String get themeNew => 'Novo tema';

  @override
  String get themeEdit => 'Editar';

  @override
  String get themeDuplicate => 'Duplicar';

  @override
  String get themeDelete => 'Excluir';

  @override
  String get themeExport => 'Exportar';

  @override
  String get themeImport => 'Importar tema';

  @override
  String get themeName => 'Nome do tema';

  @override
  String get themeBase => 'Começar de';

  @override
  String get themeModeSimple => 'Simples';

  @override
  String get themeModeAdvanced => 'Avançado';

  @override
  String get themeSave => 'Salvar';

  @override
  String get themeEditorTitle => 'Tema personalizado';

  @override
  String get themeDiscardTitle => 'Descartar as alterações?';

  @override
  String get themeDiscardBody => 'As alterações deste tema não foram salvas.';

  @override
  String get themeDiscard => 'Descartar';

  @override
  String get smartDiscardBody =>
      'As alterações desta playlist não foram salvas.';

  @override
  String get themePreview => 'Pré-visualização';

  @override
  String get themeResetColor => 'Restaurar a cor';

  @override
  String get themeContrastTitle => 'Legibilidade';

  @override
  String get themeContrastLow => 'Pouco legível';

  @override
  String get themeContrastOk => 'Legível';

  @override
  String get themeFix => 'Corrigir';

  @override
  String get themeSaved => 'Tema salvo';

  @override
  String get themeLimit => 'Você já tem 20 temas: exclua um';

  @override
  String get themeImported => 'Tema importado';

  @override
  String get themeImportFailed => 'O arquivo não é um tema válido';

  @override
  String get themeDeleted => 'Tema excluído';

  @override
  String get themeMine => 'Meus temas';

  @override
  String get tokenBg => 'Fundo';

  @override
  String get tokenSurface1 => 'Superfície 1';

  @override
  String get tokenSurface2 => 'Superfície 2';

  @override
  String get tokenSurface3 => 'Superfície 3';

  @override
  String get tokenAccent => 'Destaque';

  @override
  String get tokenAccentSoft => 'Destaque suave';

  @override
  String get tokenOnAccent => 'Texto sobre o destaque';

  @override
  String get tokenText => 'Texto';

  @override
  String get tokenTextMuted => 'Texto secundário';

  @override
  String get tokenTextFaint => 'Texto suave';

  @override
  String get tokenHero => 'Fundo do player';

  @override
  String get tokenError => 'Erro';

  @override
  String get pickerHue => 'Matiz';

  @override
  String get pickerSv => 'Saturação e brilho';

  @override
  String get pickerAlpha => 'Transparência';

  @override
  String get pickerHex => 'Código de cor';

  @override
  String get pickerInvalid => 'Código inválido';

  @override
  String get pickerRecent => 'Usadas recentemente';

  @override
  String get contrastTextBg => 'Texto sobre o fundo';

  @override
  String get contrastMutedSurface => 'Texto secundário sobre superfície';

  @override
  String get contrastOnAccent => 'Texto sobre o destaque';

  @override
  String get contrastAccentBg => 'Destaque sobre o fundo';

  @override
  String get themeBackground => 'Fundo das páginas';

  @override
  String get bgSolid => 'Cor sólida';

  @override
  String get bgGradient => 'Gradiente';

  @override
  String get bgImage => 'Imagem';

  @override
  String get bgGradientEnd => 'Cor final';

  @override
  String get bgAngle => 'Direção';

  @override
  String get bgPickImage => 'Escolher imagem…';

  @override
  String get bgRemoveImage => 'Remover a imagem';

  @override
  String get bgDim => 'Escurecimento';

  @override
  String get bgBlur => 'Desfoque';

  @override
  String get bgCoverBackdrop => 'Tocando: tom da capa';

  @override
  String get blurredChrome => 'Dock e cabeçalhos desfocados';

  @override
  String get blurredChromeHint =>
      'Pode deixar mais lento em telemóveis menos potentes';

  @override
  String get bgImageFailed => 'Não foi possível usar a imagem';

  @override
  String themeCopyName(String name) {
    return '$name (cópia)';
  }

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selecionados',
      one: '1 selecionado',
    );
    return '$_temp0';
  }

  @override
  String get selectAll => 'Selecionar tudo';

  @override
  String get exitSelection => 'Sair da seleção';

  @override
  String get bulkActions => 'Ações';

  @override
  String playNextMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas serão reproduzidas a seguir',
      one: '1 faixa será reproduzida a seguir',
    );
    return '$_temp0';
  }

  @override
  String addedToQueueMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas adicionadas à fila',
      one: '1 faixa adicionada à fila',
    );
    return '$_temp0';
  }

  @override
  String addedToPlaylistMany(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas adicionadas a «$name»',
      one: '1 faixa adicionada a «$name»',
    );
    return '$_temp0';
  }

  @override
  String addedToPlaylistSkipped(int added, int skipped, String name) {
    return '$added adicionadas a «$name», $skipped já presentes';
  }

  @override
  String allAlreadyInPlaylist(String name) {
    return 'Já estavam todas em «$name»';
  }

  @override
  String favoritesAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas nos favoritos',
      one: '1 faixa nos favoritos',
    );
    return '$_temp0';
  }

  @override
  String favoritesRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas removidas dos favoritos',
      one: '1 faixa removida dos favoritos',
    );
    return '$_temp0';
  }

  @override
  String get bulkAddToFavorites => 'Adicionar aos favoritos';

  @override
  String get bulkRemoveFromFavorites => 'Remover dos favoritos';

  @override
  String removeManyFromPlaylistTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Remover $count faixas da playlist?',
      one: 'Remover 1 faixa da playlist?',
    );
    return '$_temp0';
  }

  @override
  String get removeManyFromPlaylistBody =>
      'Os ficheiros e a biblioteca não são alterados.';

  @override
  String removedManyFromPlaylist(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas removidas',
      one: '1 faixa removida',
    );
    return '$_temp0';
  }

  @override
  String removeManyFromLibraryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Remover $count faixas da biblioteca?',
      one: 'Remover 1 faixa da biblioteca?',
    );
    return '$_temp0';
  }

  @override
  String get removeManyFromLibraryBody =>
      'Os ficheiros já não existem: desaparecem apenas da biblioteca (perde os favoritos e as playlists destas faixas).';

  @override
  String removedManyFromLibrary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas removidas da biblioteca',
      one: '1 faixa removida da biblioteca',
    );
    return '$_temp0';
  }

  @override
  String ytDownloadsStarted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transferências iniciadas',
      one: '1 transferência iniciada',
    );
    return '$_temp0';
  }

  @override
  String ytDownloadsSkipped(int started, int skipped) {
    return '$started transferências iniciadas, $skipped já na biblioteca ou em curso';
  }

  @override
  String get ytNothingToDownload => 'Já estão todas na biblioteca ou em curso';

  @override
  String get themeChiaro => 'Claro';

  @override
  String get settingsAccent => 'Cor de destaque';

  @override
  String get accentViola => 'Violeta';

  @override
  String get accentBlu => 'Azul';

  @override
  String get accentAcqua => 'Verde-água';

  @override
  String get accentVerde => 'Verde';

  @override
  String get accentAmbra => 'Âmbar';

  @override
  String get accentArancio => 'Laranja';

  @override
  String get accentRosa => 'Rosa';

  @override
  String get accentRosso => 'Vermelho';

  @override
  String get onboardingSkip => 'Saltar';

  @override
  String get onboardingNext => 'Seguinte';

  @override
  String get onboardingStart => 'Começar';

  @override
  String onboardingPageOf(int page, int total) {
    return 'Página $page de $total';
  }

  @override
  String onboardingStepOf(int page, int total) {
    return '$page de $total';
  }

  @override
  String get onboardingWelcomeTitle => 'Bem-vindo ao Codecore';

  @override
  String get onboardingWelcomeBody =>
      'O seu leitor de música pessoal: sem conta e sem servidor. A sua música fica no seu dispositivo.';

  @override
  String get onboardingFoldersTitle => 'A sua música';

  @override
  String get onboardingFoldersBody =>
      'Escolha as pastas onde guarda as suas faixas. O Codecore apenas as lê: não as altera nem as move.';

  @override
  String onboardingFoldersAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pastas adicionadas',
      one: '1 pasta adicionada',
    );
    return '$_temp0';
  }

  @override
  String get onboardingAllowAccess =>
      'Permitir o acesso aos ficheiros de áudio';

  @override
  String get onboardingAccessGranted => 'Acesso permitido';

  @override
  String get onboardingOnlineTitle => 'Funcionalidades online';

  @override
  String get onboardingOnlineBody =>
      'Estão desligadas: o Codecore nunca se liga à Internet por iniciativa própria. Pode ativá-las agora ou mais tarde nas Definições.';

  @override
  String get onboardingShareTitle => 'Transferências, Jam e partilha';

  @override
  String get onboardingYoutubeBody =>
      'Pode transferir faixas do YouTube para o seu dispositivo e ouvi-las como o resto da sua música.';

  @override
  String get onboardingJamBody =>
      'Com uma Jam ouve a mesma música em conjunto com outro dispositivo na mesma rede.';

  @override
  String get onboardingSendBody =>
      'Pode enviar faixas para outros dispositivos próximos com um PIN, sem passar pela Internet.';

  @override
  String get historyTitle => 'Histórico';

  @override
  String get historySubtitle => 'O que ouviu';

  @override
  String get historyToday => 'Hoje';

  @override
  String get historyYesterday => 'Ontem';

  @override
  String get historyEmpty => 'O que ouvir aparecerá aqui.';

  @override
  String get historyOff =>
      'O histórico está desligado: ative-o em Definições, Reprodução.';

  @override
  String get historyClear => 'Limpar histórico';

  @override
  String get historyClearTitle => 'Limpar o histórico?';

  @override
  String get historyClearBody =>
      'Apenas a lista de reproduções é apagada: os contadores, os favoritos e as playlists ficam como estão.';

  @override
  String get historyCleared => 'Histórico limpo';

  @override
  String get settingsRecordHistory => 'Guardar o histórico de reprodução';

  @override
  String get settingsRecordHistoryHint =>
      'Fica no dispositivo. Desligado, nada mais é adicionado à lista.';

  @override
  String get statsTitle => 'Estatísticas';

  @override
  String get statsSubtitle => 'Quanto e o que ouve';

  @override
  String get statsMonth => 'Mês';

  @override
  String get statsYear => 'Ano';

  @override
  String get statsPrevious => 'Período anterior';

  @override
  String get statsNext => 'Período seguinte';

  @override
  String get statsEmpty => 'Nenhuma reprodução neste período.';

  @override
  String statsPlays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reproduções',
      one: '1 reprodução',
    );
    return '$_temp0';
  }

  @override
  String statsDistinct(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas diferentes',
      one: '1 faixa diferente',
    );
    return '$_temp0';
  }

  @override
  String statsHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get statsTopTracks => 'Faixas mais ouvidas';

  @override
  String get statsTopArtists => 'Artistas mais ouvidos';

  @override
  String get statsTopAlbums => 'Álbuns mais ouvidos';

  @override
  String get statsFavouriteHour => 'Hora preferida';

  @override
  String get statsFirstListen => 'Primeira reprodução';

  @override
  String statsFirstValue(String title, String date) {
    return '$title, $date';
  }

  @override
  String get statsYourMonth => 'O seu mês';

  @override
  String ruleWarning(String term) {
    return 'Não percebo «$term»: procuro-o como texto.';
  }

  @override
  String get smartPlaylistNew => 'Nova playlist inteligente';

  @override
  String get smartPlaylistEdit => 'Editar playlist inteligente';

  @override
  String get smartPlaylistLabel => 'Playlist inteligente';

  @override
  String get smartName => 'Nome';

  @override
  String get smartNameRequired => 'Escreva um nome';

  @override
  String get smartNoRules => 'Sem regras, a playlist contém toda a biblioteca.';

  @override
  String get smartSortBy => 'Ordenar por';

  @override
  String get smartSortMostPlayed => 'Mais ouvidas';

  @override
  String get smartSortRandom => 'Aleatório';

  @override
  String get smartTemplates => 'Modelos';

  @override
  String get smartTplNever => 'Nunca ouvidas';

  @override
  String get smartTplRecent => 'Adicionadas recentemente';

  @override
  String get smartTplTop => 'As mais ouvidas';

  @override
  String get smartTpl90s => 'Anos 90';

  @override
  String get smartConvert => 'Converter em playlist normal';

  @override
  String smartConverted(String name) {
    return 'Criada a playlist «$name» com a lista atual';
  }

  @override
  String smartDeleteTitle(String name) {
    return 'Eliminar «$name»?';
  }

  @override
  String get smartDeleteBody =>
      'Apenas a regra é eliminada: as faixas ficam onde estão.';

  @override
  String get smartAutoNote => 'A lista atualiza-se sozinha.';

  @override
  String get tagsTitle => 'Etiquetas';

  @override
  String get tagsSubtitle => 'As suas etiquetas';

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
  String get tagNew => 'Nova etiqueta';

  @override
  String get tagRename => 'Mudar o nome da etiqueta';

  @override
  String get tagColor => 'Cor';

  @override
  String get tagNoColor => 'Sem cor';

  @override
  String get tagNameTaken => 'Já existe uma etiqueta com este nome';

  @override
  String tagDeleteTitle(String name) {
    return 'Eliminar a etiqueta «$name»?';
  }

  @override
  String get tagDeleteBody =>
      'Apenas a etiqueta é retirada das faixas: continuam na biblioteca.';

  @override
  String get tagsEmpty =>
      'Ainda não há etiquetas: crie uma no menu de uma faixa.';

  @override
  String get tagAddToSelection => 'Adicionar etiqueta…';

  @override
  String get tagRemoveFromSelection => 'Retirar etiqueta…';

  @override
  String tagAssigned(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas etiquetadas «$name»',
      one: '1 faixa etiquetada «$name»',
    );
    return '$_temp0';
  }

  @override
  String tagUnassigned(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '«$name» retirada de $count faixas',
      one: '«$name» retirada de 1 faixa',
    );
    return '$_temp0';
  }

  @override
  String get tagNoneToRemove => 'As faixas escolhidas não têm etiquetas.';

  @override
  String get cleanupSection => 'Limpeza da biblioteca';

  @override
  String get duplicatesTitle => 'Duplicados';

  @override
  String get duplicatesTileHint =>
      'A mesma música em várias cópias ou qualidades';

  @override
  String get duplicatesIntro =>
      'Procura a mesma música em várias cópias: o mesmo ficheiro em duas pastas ou a mesma música em duas qualidades. Antes de unir vês uma pré-visualização. Favoritos, playlists, reproduções, letras e etiquetas passam para a música que manténs; as outras ficam apenas ocultas e restauras em «Músicas ocultas». Nenhum ficheiro é apagado sem dupla confirmação.';

  @override
  String get duplicatesSearch => 'Procurar duplicados';

  @override
  String get duplicatesSearchAgain => 'Procurar de novo';

  @override
  String get duplicatesReading => 'A ler a biblioteca…';

  @override
  String duplicatesHashing(int done, int total) {
    return 'A verificar ficheiros: $done de $total';
  }

  @override
  String get duplicatesGrouping => 'A comparar músicas…';

  @override
  String get duplicatesFailed => 'A pesquisa falhou. Tenta de novo.';

  @override
  String get duplicatesNone => 'Nenhum duplicado encontrado';

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
      other: '$hidden músicas a ocultar',
      one: '1 música a ocultar',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get duplicatesExactBadge => 'Idênticos';

  @override
  String get duplicatesProbableBadge => 'Prováveis';

  @override
  String get duplicatesKeepLabel => 'Manter';

  @override
  String get duplicatesPickKeep => 'Toca numa música para a manter';

  @override
  String get duplicatesMerge => 'Unir';

  @override
  String get duplicatesNotDuplicates => 'Não são duplicados';

  @override
  String duplicatesMergeAllExact(int count) {
    return 'Unir todos os idênticos ($count)';
  }

  @override
  String get duplicatesMergeAllTitle => 'Unir todos os idênticos?';

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
      other: '$hidden músicas ocultas',
      one: '1 música oculta',
    );
    return '$_temp0, $_temp1. Favoritos, playlists, reproduções e letras passam para as músicas que ficam.';
  }

  @override
  String duplicatesMerged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas ocultas',
      one: '1 música oculta',
    );
    return 'Unido: $_temp0';
  }

  @override
  String duplicatesDeleteFiles(int count, String size) {
    return 'Apagar também os ficheiros ($count, $size)';
  }

  @override
  String get duplicatesDeleteListTitle => 'Apagar estes ficheiros?';

  @override
  String get duplicatesDeleteListBody =>
      'Serão apagados do dispositivo e não se podem recuperar. As músicas que manténs ficam onde estão.';

  @override
  String get duplicatesDeleteContinue => 'Continuar';

  @override
  String duplicatesDeleteFinalTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Apagar definitivamente $count ficheiros?',
      one: 'Apagar definitivamente 1 ficheiro?',
    );
    return '$_temp0';
  }

  @override
  String duplicatesDeleteFinalBody(String size) {
    return 'Espaço libertado: $size. Esta ação não se pode anular.';
  }

  @override
  String get duplicatesDeleteGo => 'Apagar definitivamente';

  @override
  String get duplicatesDeleteDoneTitle => 'Concluído';

  @override
  String duplicatesDeleteDone(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ficheiros apagados',
      one: '1 ficheiro apagado',
    );
    return '$_temp0 ($size).';
  }

  @override
  String duplicatesDeleteFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ficheiros não apagados:',
      one: '1 ficheiro não apagado:',
    );
    return '$_temp0';
  }

  @override
  String duplicatesDeleteSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count ficheiros intocados: são o mesmo ficheiro da música mantida.',
      one: '1 ficheiro intocado: é o mesmo ficheiro da música mantida.',
    );
    return '$_temp0';
  }

  @override
  String get duplicatesDeleteAndroidHint =>
      'No Android só se podem apagar ficheiros das pastas a que a app tem acesso.';

  @override
  String activityCleanup(int done, int total) {
    return 'A procurar duplicados: $done de $total';
  }

  @override
  String get hiddenTracksTitle => 'Músicas ocultas';

  @override
  String hiddenTracksCount(int count) {
    return 'Músicas ocultas ($count)';
  }

  @override
  String get hiddenTracksEmpty => 'Nenhuma música oculta';

  @override
  String get hiddenTracksHint =>
      'Os duplicados unidos não aparecem na biblioteca. «Restaurar» volta a pô-los no lugar.';

  @override
  String get hiddenRestore => 'Restaurar';

  @override
  String hiddenRestored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas restauradas',
      one: '1 música restaurada',
    );
    return '$_temp0';
  }

  @override
  String get albumMergeWith => 'Unir com…';

  @override
  String get albumMergeTitle => 'Unir álbuns';

  @override
  String albumMergeIntro(String name) {
    return 'Escolhe os álbuns a unir a «$name». As músicas passam para um só álbum com o título e o artista que indicares; a capa continua a de «$name».';
  }

  @override
  String get albumMergeSearch => 'Procurar um álbum';

  @override
  String get albumMergeNone => 'Não há outros álbuns';

  @override
  String get albumFieldTitle => 'Título do álbum';

  @override
  String get albumFieldArtist => 'Artista do álbum';

  @override
  String get albumMergeAction => 'Unir álbuns';

  @override
  String albumMerged(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count álbuns unidos em «$name»',
      one: '1 álbum unido em «$name»',
    );
    return '$_temp0';
  }

  @override
  String get moveToAlbum => 'Mover para um álbum novo…';

  @override
  String get moveToAlbumTitle => 'Mover para um álbum';

  @override
  String moveToAlbumBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas irão',
      one: '1 música irá',
    );
    return '$_temp0 para o álbum indicado. Se já existir, juntam-se a ele.';
  }

  @override
  String get moveToAlbumGo => 'Mover';

  @override
  String movedToAlbum(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas movidas para «$name»',
      one: '1 música movida para «$name»',
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
  String get playlistSourceTitle => 'Playlist ou canal do YouTube';

  @override
  String get playlistSourceLoading => 'A ler a lista de vídeos…';

  @override
  String get playlistSourceName => 'Nome da playlist';

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
      other: '$count vídeos indisponíveis (privados ou removidos)',
      one: '1 vídeo indisponível (privado ou removido)',
    );
    return '$_temp0';
  }

  @override
  String playlistSourceTruncated(int count) {
    return 'A mostrar os primeiros $count vídeos.';
  }

  @override
  String playlistSourceLong(int count, String time) {
    return 'São $count vídeos: vai demorar $time.';
  }

  @override
  String get playlistSourceNone => 'Nenhum';

  @override
  String get playlistSourceEmpty => 'Não há vídeos para descarregar aqui.';

  @override
  String playlistSourceGo(int count) {
    return 'Descarregar para uma playlist ($count)';
  }

  @override
  String playlistSourceStarted(String name) {
    return 'Descargas iniciadas na playlist «$name»';
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
  String get podcastsNotice => 'Os podcasts só se atualizam quando o pedes.';

  @override
  String get podcastsEmpty => 'Não estás subscrito a nenhum podcast.';

  @override
  String get podcastAdd => 'Adicionar um podcast';

  @override
  String get podcastRefreshAll => 'Atualizar todos';

  @override
  String get podcastRefresh => 'Atualizar';

  @override
  String podcastRefreshed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count episódios novos',
      one: '1 episódio novo',
      zero: 'Nenhum episódio novo',
    );
    return '$_temp0';
  }

  @override
  String podcastRefreshFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count podcasts por atualizar',
      one: '1 podcast por atualizar',
    );
    return '$_temp0';
  }

  @override
  String get podcastFeedUrl => 'Endereço do feed';

  @override
  String get podcastSubscribe => 'Subscrever';

  @override
  String get podcastSearchHint => 'Procura um podcast pelo nome';

  @override
  String get podcastSearchNone => 'Nenhum podcast encontrado';

  @override
  String podcastSubscribed(String name) {
    return 'Subscrito a «$name»';
  }

  @override
  String podcastEpisodesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count episódios',
      one: '1 episódio',
    );
    return '$_temp0';
  }

  @override
  String podcastToListen(int count) {
    return '$count por ouvir';
  }

  @override
  String get podcastNoEpisodes => 'Nenhum episódio.';

  @override
  String get podcastStateDownloaded => 'Descarregado';

  @override
  String podcastStateDownloading(int percent) {
    return 'A descarregar… $percent%';
  }

  @override
  String get podcastStateHeard => 'Ouvido';

  @override
  String podcastStateRemaining(String time) {
    return 'Faltam $time';
  }

  @override
  String get podcastMarkHeard => 'Marcar como ouvido';

  @override
  String get podcastMarkNotHeard => 'Marcar como não ouvido';

  @override
  String get podcastDeleteFile => 'Apagar o ficheiro';

  @override
  String get podcastAutoDelete => 'Apagar os episódios ouvidos';

  @override
  String get podcastAutoDeleteNever => 'Nunca';

  @override
  String podcastAutoDeleteAfter(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dias',
      one: '1 dia',
    );
    return '$_temp0';
  }

  @override
  String get podcastUnsubscribe => 'Cancelar a subscrição';

  @override
  String get podcastUnsubscribeTitle => 'Cancelar a subscrição?';

  @override
  String podcastUnsubscribeBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'O podcast e $count episódios descarregados serão apagados do dispositivo.',
      one: 'O podcast e 1 episódio descarregado serão apagados do dispositivo.',
      zero: 'O podcast será apagado do dispositivo.',
    );
    return '$_temp0';
  }

  @override
  String podcastLastChecked(String when) {
    return 'Atualizado $when';
  }

  @override
  String get podcastNeverChecked => 'Nunca atualizado';

  @override
  String get podcastErrInvalidUrl => 'Isso não parece um endereço web válido.';

  @override
  String get podcastErrTooLarge => 'O feed é demasiado grande.';

  @override
  String get podcastErrNetwork => 'Não consigo alcançar o servidor.';

  @override
  String get podcastErrNotFeed => 'Esse endereço não é um feed de podcast.';

  @override
  String get podcastErrUnsupportedFormat => 'Formato de áudio não suportado.';

  @override
  String get syncTitle => 'Sincronizar playlists';

  @override
  String syncAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count novas',
      one: '1 nova',
    );
    return '$_temp0';
  }

  @override
  String syncUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count atualizadas',
      one: '1 atualizada',
    );
    return '$_temp0';
  }

  @override
  String syncMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas em falta',
      one: '1 faixa em falta',
    );
    return '$_temp0';
  }

  @override
  String get syncUpToDate => 'As playlists já estão sincronizadas';

  @override
  String syncKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count playlists são mais recentes aqui e ficam como estão',
      one: '1 playlist é mais recente aqui e fica como está',
    );
    return '$_temp0';
  }

  @override
  String get syncReplaceNote =>
      'As playlists atualizadas substituem as deste dispositivo.';

  @override
  String get syncTagNew => 'Nova';

  @override
  String get syncTagUpdated => 'Atualizada';

  @override
  String get syncDetailRenamed => 'renomeada';

  @override
  String get syncDetailReordered => 'reordenada';

  @override
  String syncDetailRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas removidas',
      one: '1 faixa removida',
    );
    return '$_temp0';
  }

  @override
  String get syncAskMissing => 'Pedir as faixas em falta';

  @override
  String syncApplied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count playlists sincronizadas',
      one: '1 playlist sincronizada',
    );
    return '$_temp0';
  }

  @override
  String get trustedSection => 'Dispositivos de confiança';

  @override
  String trustedFingerprint(String fingerprint) {
    return 'Impressão digital $fingerprint';
  }

  @override
  String trustedPairedOn(String date) {
    return 'Emparelhado em $date';
  }

  @override
  String get trustedAutoAccept => 'Aceitar automaticamente';

  @override
  String get trustedAutoAcceptHint =>
      'Receber faixas deste dispositivo sem perguntar.';

  @override
  String get trustedRevoke => 'Revogar';

  @override
  String trustedRevokeTitle(String name) {
    return 'Revogar «$name»?';
  }

  @override
  String get trustedRevokeBody =>
      'Para enviar de novo sem PIN terão de emparelhar outra vez.';

  @override
  String get carMode => 'Modo carro';

  @override
  String get carExit => 'Sair';

  @override
  String get carKeepAwake => 'Ecrã sempre ligado';

  @override
  String get carPlaylists => 'Playlists';

  @override
  String get carNothing => 'Nada a tocar';

  @override
  String get updateCheck => 'Procurar atualizações';

  @override
  String get updateCheckHint =>
      'Pergunta ao GitHub a última versão, só quando pedes.';

  @override
  String get updateOnStart => 'Verificar ao iniciar';

  @override
  String get updateOnStartHint =>
      'No máximo uma vez por dia. Não descarrega nem instala nada.';

  @override
  String get updateChecking => 'A verificar…';

  @override
  String updateAvailable(String version) {
    return 'Está disponível a versão $version';
  }

  @override
  String updateUpToDate(String version) {
    return 'Tens a última versão ($version)';
  }

  @override
  String get updateRateLimited =>
      'O GitHub pede para esperar: tenta mais tarde.';

  @override
  String get updateFailed =>
      'Não consigo ler a última versão. Verifica a ligação.';

  @override
  String get updateCopyLink => 'Copiar endereço';

  @override
  String get updateLinkCopied => 'Endereço copiado';

  @override
  String get backupSection => 'Cópia de segurança';

  @override
  String get backupCreate => 'Criar cópia';

  @override
  String get backupCreateHint =>
      'Playlists, favoritos, letras e edições num zip. Sem música.';

  @override
  String get backupRestore => 'Restaurar de cópia';

  @override
  String get backupRestoreHint =>
      'Substituir esta biblioteca ou juntar os dados de outro dispositivo.';

  @override
  String get backupCreating => 'A criar a cópia…';

  @override
  String get backupSaved => 'Cópia guardada';

  @override
  String get backupFailed => 'Falha na cópia';

  @override
  String get restoreTitle => 'Restaurar de cópia';

  @override
  String restoreInfo(String date, String version, int tracks, int playlists) {
    return 'De $date, app $version, $tracks faixas, $playlists playlists';
  }

  @override
  String get restoreReplace => 'Substituir tudo (mesmo dispositivo)';

  @override
  String get restoreMerge => 'Juntar a esta biblioteca';

  @override
  String get restoreMergeHint =>
      'Acrescenta favoritos, playlists, letras e edições às faixas que encontra. Não apaga nada.';

  @override
  String get restoreReplaceConfirmTitle => 'Substituir toda a biblioteca?';

  @override
  String get restoreReplaceConfirmBody =>
      'No próximo arranque, os dados desta app passam a ser os da cópia. Os atuais ficam numa cópia de segurança junto à base de dados.';

  @override
  String get restoreReplaceGo => 'Substituir';

  @override
  String get restoreNotBackup =>
      'Este ficheiro não é uma cópia do Codecore que eu consiga ler.';

  @override
  String get restoreRestartNeeded =>
      'Pronto: fecha a app e abre-a de novo para concluir o restauro.';

  @override
  String restoreMergeDone(
    int recognized,
    int missing,
    int playlists,
    int favorites,
  ) {
    return 'Junção feita: $recognized faixas reconhecidas, $missing não encontradas, $playlists playlists criadas, $favorites favoritos adicionados.';
  }

  @override
  String get restoreNotFound => 'Faixas não encontradas';

  @override
  String get restoreCopyList => 'Copiar lista';

  @override
  String get restoreFailed => 'Falha no restauro';

  @override
  String get exportAllPlaylists => 'Exportar todas as playlists';

  @override
  String get shareErrIdentity =>
      'A identidade deste dispositivo mudou: remove-o dos de confiança e emparelha de novo.';

  @override
  String get incomingTrustedTag => 'Dispositivo de confiança';

  @override
  String incomingTrustedTitle(String name) {
    return '$name (de confiança)';
  }

  @override
  String get pairAction => 'Emparelhar';

  @override
  String get trustedBadge => 'De confiança';

  @override
  String pairPinTitle(String name) {
    return 'Emparelhar com $name';
  }

  @override
  String pairPinHint(String name) {
    return 'Escreve o PIN de 6 dígitos mostrado em $name.';
  }

  @override
  String pairPinWrong(int count) {
    return 'PIN errado. Tentativas restantes: $count.';
  }

  @override
  String pairFingerprint(String fingerprint) {
    return 'Impressão digital: $fingerprint';
  }

  @override
  String get pairCompare =>
      'Confirma que a impressão digital é a mesma no outro ecrã.';

  @override
  String pairRequestTitle(String name) {
    return '$name quer emparelhar';
  }

  @override
  String get pairRequestBody =>
      'Escreve este PIN no outro dispositivo e toca em Confirmar.';

  @override
  String get pairConfirm => 'Confirmar';

  @override
  String get pairWaiting => 'À espera da confirmação no outro dispositivo…';

  @override
  String pairDone(String name) {
    return 'Emparelhado com $name';
  }

  @override
  String get pairBlocked => 'Demasiadas tentativas erradas: tenta mais tarde.';

  @override
  String get pairRejected => 'Emparelhamento recusado.';

  @override
  String get pairExpired => 'O pedido expirou: tenta de novo.';

  @override
  String get pairFailed => 'Falha no emparelhamento.';

  @override
  String get syncDevice => 'Sincronizar playlists';

  @override
  String get syncUnreachable => 'O dispositivo não está visível na rede local.';

  @override
  String get syncFailed => 'Falha na sincronização.';

  @override
  String syncAsked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pedido enviado: $count faixas a caminho',
      one: 'Pedido enviado: 1 faixa a caminho',
      zero: 'Nenhuma das faixas está no outro dispositivo',
    );
    return '$_temp0';
  }

  @override
  String get translateLyrics => 'Traduzir';

  @override
  String get translateLyricsFrom => 'Idioma da letra';

  @override
  String get translateLyricsHint =>
      'Traduzido no telefone, nenhum texto é enviado pela rede.';

  @override
  String get translateRemove => 'Mostrar só o original';

  @override
  String translateDownloadTitle(String language) {
    return 'Baixar o modelo $language?';
  }

  @override
  String translateDownloadBody(int mb) {
    return 'Cerca de $mb MB por idioma, melhor com Wi-Fi. É baixado uma só vez e depois funciona também offline.';
  }

  @override
  String get translateDownload => 'Baixar';

  @override
  String translateDownloading(String language) {
    return 'Baixando o modelo $language…';
  }

  @override
  String get translateDownloadFailed =>
      'Modelo não baixado. Verifique a conexão e o espaço.';

  @override
  String get translateFailed => 'A tradução falhou.';

  @override
  String get translateSameLanguage => 'A letra já está neste idioma.';

  @override
  String get translationModels => 'Modelos de tradução';

  @override
  String get translationModelsNone =>
      'Nenhum modelo baixado. Eles são baixados na tela das letras, com «Traduzir».';

  @override
  String translationModelDelete(String language) {
    return 'Excluir o modelo $language';
  }

  @override
  String get scanCode => 'Ler código';

  @override
  String get scanTitle => 'Aponta ao código QR';

  @override
  String get scanNotCodecore => 'Este código não é do Codecore.';

  @override
  String get scanCameraDenied =>
      'É preciso a permissão da câmara para ler o código.';

  @override
  String get scanOpenSettings => 'Abrir definições';

  @override
  String get ownFingerprint => 'Impressão digital deste dispositivo';

  @override
  String get ownFingerprintHint =>
      'Compara-a com a do outro ecrã ao emparelhar.';

  @override
  String get writeTagsToFiles => 'Gravar as alterações nos ficheiros';

  @override
  String get writeTagsToFilesHint =>
      'O título, artista, álbum, ano, género e faixa editados aqui são também gravados nos ficheiros MP3, FLAC, M4A e OGG. O original de cada ficheiro é guardado. Desligado por defeito.';

  @override
  String get writeTagsAfterDownload =>
      'Gravar as etiquetas nos ficheiros descarregados';

  @override
  String get writeTagsAfterDownloadHint =>
      'Apenas nos ficheiros que o Codecore descarregou ou recebeu. O ISRC fica na aplicação.';

  @override
  String get writeTagsWarnTitle => 'Gravar as alterações nos ficheiros?';

  @override
  String get writeTagsWarnBody =>
      'Ao guardar uma alteração, as etiquetas são também reescritas no ficheiro de música (MP3, FLAC, M4A, OGG). Trabalha-se sobre uma cópia, verifica-se o resultado e o ficheiro só é substituído se tudo coincidir; antes, o original é guardado em «Cópias das etiquetas» (as últimas 200 ou 2 GB). A capa, as letras e o ReplayGain não são tocados. Antes de ativar, convém fazer uma cópia de segurança da biblioteca (Definições, Cópia de segurança).';

  @override
  String get writeTagsEnable => 'Ativar';

  @override
  String get tagsAlsoInFile => 'Gravar também no ficheiro';

  @override
  String tagsNoWriteUnsupported(String format) {
    return 'Formato não editável ($format): só a biblioteca muda';
  }

  @override
  String get tagsNoWriteReadOnly =>
      'Ficheiro só de leitura: só a biblioteca muda';

  @override
  String get tagsNoWriteMissing =>
      'Ficheiro não encontrado: só a biblioteca muda';

  @override
  String tagsFileWriteFailed(int count, String reason) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ficheiros não foram alterados',
      one: '1 ficheiro não foi alterado',
    );
    return 'Guardado na biblioteca, mas $_temp0: $reason';
  }

  @override
  String get tagReasonUnsupported => 'formato não suportado';

  @override
  String get tagReasonNotFound => 'ficheiro não encontrado';

  @override
  String get tagReasonReadOnly => 'ficheiro só de leitura';

  @override
  String get tagReasonVerifyFailed =>
      'a verificação após a gravação falhou, o ficheiro ficou como estava';

  @override
  String get tagReasonWriteFailed =>
      'a gravação falhou, o ficheiro ficou como estava';

  @override
  String get tagReasonBackupFailed =>
      'não foi possível guardar o original, o ficheiro ficou como estava';

  @override
  String get tagReasonIoError => 'erro de disco ou de permissões';

  @override
  String get tagBackupsTitle => 'Cópias das etiquetas';

  @override
  String tagBackupsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cópias das etiquetas ($count)',
      one: 'Cópias das etiquetas (1)',
      zero: 'Cópias das etiquetas',
    );
    return '$_temp0';
  }

  @override
  String get tagBackupsHint =>
      'O original de cada ficheiro reescrito, antes da alteração. Guardam-se os últimos 200 ou 2 GB.';

  @override
  String get tagBackupsEmpty =>
      'Sem cópias: ainda nenhum ficheiro foi reescrito.';

  @override
  String get tagBackupRestore => 'Restaurar original';

  @override
  String tagBackupRestoreBody(String name) {
    return 'O ficheiro «$name» volta a ficar como estava antes da alteração. A biblioteca mantém as alterações feitas na app.';
  }

  @override
  String get tagBackupRestored => 'Original restaurado';

  @override
  String tagBackupRestoreFailed(String reason) {
    return 'Não foi possível restaurar: $reason';
  }

  @override
  String get tagBackupDelete => 'Eliminar cópia';

  @override
  String get tagBackupDeleteBody =>
      'Já não poderá devolver o ficheiro ao estado anterior à alteração.';

  @override
  String get tagBackupDeleted => 'Cópia eliminada';

  @override
  String get deleteFromDevice => 'Eliminar do dispositivo';

  @override
  String deleteTrackTitle(String title) {
    return 'Eliminar «$title»?';
  }

  @override
  String get deleteTrackBody =>
      'O ficheiro é apagado do dispositivo e a faixa desaparece da biblioteca, das playlists, dos favoritos e do histórico. Não é possível anular.';

  @override
  String deleteTracksTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Eliminar $count faixas?',
      one: 'Eliminar 1 faixa?',
    );
    return '$_temp0';
  }

  @override
  String get deleteTracksBody =>
      'Os ficheiros são apagados do dispositivo e as faixas desaparecem da biblioteca, das playlists, dos favoritos e do histórico. Não é possível anular.';

  @override
  String get deleteConfirm => 'Eliminar';

  @override
  String get trackDeleted => 'Faixa eliminada';

  @override
  String trackDeleteFailed(String reason) {
    return 'Não foi possível eliminar o ficheiro: $reason';
  }

  @override
  String tracksDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas eliminadas',
      one: '1 faixa eliminada',
    );
    return '$_temp0';
  }

  @override
  String tracksDeletedSome(int count, int failed) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas eliminadas',
      one: '1 faixa eliminada',
    );
    return '$_temp0, $failed não eliminadas';
  }

  @override
  String get trackDeleteRefused => 'O Android não permitiu eliminar o ficheiro';

  @override
  String get reviewTitle => 'Para rever';

  @override
  String get reviewFilterAll => 'Todas';

  @override
  String get reviewFilterNothingFound => 'Nada encontrado';

  @override
  String get reviewFilterNoLyrics => 'Sem letra';

  @override
  String get reviewFilterNoCover => 'Sem capa';

  @override
  String get reviewFilterMissingData => 'Dados em falta';

  @override
  String get reviewEmpty =>
      'Nada para rever: às faixas pesquisadas não falta nada';

  @override
  String get reviewHint =>
      'Faixas a que falta algo. Pesquise de novo ou deixe como estão.';

  @override
  String get reviewRetry => 'Tentar de novo';

  @override
  String get reviewDismiss => 'Ignorar';

  @override
  String reviewRetryStarted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas',
      one: '1 faixa',
    );
    return 'Pesquisa iniciada para $_temp0';
  }

  @override
  String reviewDismissed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas retiradas da lista',
      one: '1 faixa retirada da lista',
    );
    return '$_temp0';
  }

  @override
  String reviewSecondOpinionProgress(int done, int total) {
    return 'Verificação com o YouTube Music, $done de $total';
  }

  @override
  String get reviewSecondOpinionStop => 'Parar';

  @override
  String reviewSecondOpinionDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas atualizadas com o YouTube Music',
      one: '1 faixa atualizada com o YouTube Music',
    );
    return '$_temp0';
  }

  @override
  String get reviewSecondOpinionThrottled =>
      'O YouTube Music pediu para ir mais devagar: as faixas restantes serão verificadas mais tarde';

  @override
  String activitySecondOpinion(int done, int total) {
    return 'Segunda opinião: $done de $total';
  }

  @override
  String get secondOpinionLogTitle => 'Segunda opinião';

  @override
  String get secondOpinionLogEmpty => 'Nenhuma faixa verificada';

  @override
  String get secondOpinionConfirmed => 'Confirmado, nada a acrescentar';

  @override
  String secondOpinionConfirmedFields(String fields) {
    return 'Confirmado, acrescentado: $fields';
  }

  @override
  String get secondOpinionNotConfirmed => 'Não confirmado';

  @override
  String get secondOpinionNetwork => 'Rede indisponível, para tentar de novo';

  @override
  String get secondOpinionThrottled =>
      'O YouTube Music pediu para ir mais devagar';

  @override
  String get sourceYoutubeMusic => 'Origem: YouTube Music';

  @override
  String get curiositySourceDiscogs => 'Do álbum, via Discogs';

  @override
  String get navMemory => 'Armazenamento';

  @override
  String get memoryMusicLabel => 'Música';

  @override
  String get memoryOtherLabel => 'Outros';

  @override
  String get memoryFreeLabel => 'Livre';

  @override
  String memoryDeviceLine(String free, String total) {
    return '$free livres de $total';
  }

  @override
  String get memoryPlaylists => 'Playlists';

  @override
  String get memoryPlaylistsNote =>
      'Uma faixa em várias playlists conta em cada uma, por isso a soma pode ultrapassar o total.';

  @override
  String get memoryByFormat => 'Formatos';

  @override
  String get memoryByFolder => 'Pastas';

  @override
  String get memoryNoFolder => 'Fora das pastas';

  @override
  String get memoryHeaviest => 'Os mais pesados';

  @override
  String get memoryHeaviestTracks => 'Faixas';

  @override
  String get memoryHeaviestAlbums => 'Álbuns';

  @override
  String get memoryNeverPlayed => 'Nunca ouvidas';

  @override
  String get memoryNeverPlayedHint =>
      'Faixas que nunca foram reproduzidas. Selecione algumas para apagá-las do dispositivo.';

  @override
  String get memoryNeverPlayedNone => 'Você ouviu toda a sua música';

  @override
  String get memoryAppData => 'Dados do app';

  @override
  String get memoryCovers => 'Capas';

  @override
  String memoryCoversThumbs(String size) {
    return 'das quais miniaturas $size';
  }

  @override
  String get memoryDatabase => 'Biblioteca';

  @override
  String get memoryImageMemory => 'Imagens na memória';

  @override
  String get memoryJamCache => 'Cache do Jam';

  @override
  String get memorySearchCache => 'Cache de buscas';

  @override
  String get memoryCatalogCache => 'Catálogo online';

  @override
  String get memoryBlurCopies => 'Fundos desfocados';

  @override
  String get memoryTagBackups => 'Backups das tags';

  @override
  String get memoryLog => 'Registro de log';

  @override
  String get memoryPodcasts => 'Episódios de podcast';

  @override
  String get memoryClearCache => 'Limpar cache';

  @override
  String memoryCleared(String size) {
    return '$size liberados';
  }

  @override
  String memoryClearedJamKept(String size) {
    return '$size liberados. O cache do Jam está em uso e não foi tocado';
  }

  @override
  String get memoryClearFailed => 'Não foi possível limpar o cache';

  @override
  String get memoryOfMusic => 'de música';

  @override
  String get memoryShowAll => 'Mostrar tudo';

  @override
  String get memoryCache => 'Cache';

  @override
  String get memoryCacheHint => 'Imagens, buscas, Jam';

  @override
  String get memoryDatabaseHint => 'O banco de dados com faixas e reproduções';

  @override
  String get memoryTagBackupsHint => 'Antes de cada alteração nos arquivos';

  @override
  String get memoryTinyNote => 'Dados abaixo de 1 MB não são listados.';

  @override
  String memoryClearHint(String size) {
    return 'Libera $size. Faixas, capas e reproduções ficam.';
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
  String get memoryTools => 'Ferramentas';

  @override
  String get memoryUnavailable => 'Indisponível';

  @override
  String ytmArtistWithAudience(String audience) {
    return 'Artista, $audience';
  }

  @override
  String ytmOffline(String date) {
    return 'Offline, dados de $date';
  }

  @override
  String get ytmArtistNotFound => 'Artista não encontrado';

  @override
  String get ytmPageUnreadable =>
      'Não é possível ler a página (o YouTube mudou algo)';

  @override
  String get ytmArtistUnreadable =>
      'Não é possível ler a página do artista (o YouTube mudou algo)';

  @override
  String ytmSearchSongsOf(String name) {
    return 'Buscar músicas de $name';
  }

  @override
  String get ytmInYourLibrary => 'Na sua biblioteca';

  @override
  String get ytmAbout => 'Sobre';

  @override
  String get ytmMore => 'Mais';

  @override
  String get ytmLess => 'Menos';

  @override
  String get ytmDownloadAlbum => 'Baixar álbum';

  @override
  String ytmDownloadAlbumTitle(String album) {
    return 'Baixar “$album”?';
  }

  @override
  String ytmAlbumConfirmBody(int tracks, String duration, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      tracks,
      locale: localeName,
      other: '$tracks faixas',
      one: '1 faixa',
    );
    return '$_temp0, $duration, cerca de $size';
  }

  @override
  String ytmAlbumConfirmOwned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas já estão na biblioteca e serão vinculadas',
      one: '1 faixa já está na biblioteca e será vinculada',
    );
    return '$_temp0';
  }

  @override
  String ytmAlbumStarted(String name) {
    return 'Importação “$name” iniciada';
  }

  @override
  String get ytmShowImport => 'Mostrar';

  @override
  String get ytmOnYoutubeMusic => 'No YouTube Music';

  @override
  String get ytmArtistOnYoutubeMusic => 'Artista no YouTube Music';

  @override
  String get ytmSearchingArtist => 'Buscando no YouTube Music…';

  @override
  String get ytmPickArtist => 'Qual artista?';

  @override
  String get ytmArtistNone => 'Nenhum artista encontrado no YouTube Music';

  @override
  String get suggestedBadge => 'Sugerido';

  @override
  String suggestedSimilarTo(String seed) {
    return 'Sugerido: parecido com «$seed»';
  }

  @override
  String get suggestionDownloadStarted => 'Transferência iniciada';

  @override
  String suggestionAddWhenDownloaded(String name) {
    return 'A transferir e a adicionar a «$name»';
  }

  @override
  String get dislikesTitle => 'Non mi piace';

  @override
  String get dislikesHint =>
      'Cosa non vuoi tra i suggeriti. I brani possono tornare solo se molto vicini a ciò che ascolti; gli artisti mai più.';

  @override
  String dislikesTracksTab(int count) {
    return 'Brani $count';
  }

  @override
  String dislikesArtistsTab(int count) {
    return 'Artisti $count';
  }

  @override
  String get dislikesEmptyTracks => 'Nessun brano escluso';

  @override
  String get dislikesEmptyArtists => 'Nessun artista escluso';

  @override
  String get dislikesEmptyHint =>
      'Quando tocchi «Non mi piace» su un suggerito, lo trovi qui e puoi toglierlo.';

  @override
  String get dislikesRemove => 'Togli';

  @override
  String dislikesRemoveLabel(String name) {
    return 'Togli «$name» dai non mi piace';
  }

  @override
  String dislikesRemoved(String name) {
    return '«$name» tolto dai non mi piace';
  }

  @override
  String get dislikesTileHint => 'Brani e artisti esclusi dai suggeriti';

  @override
  String get dislikePlayerLabel => 'Non mi piace: brano o artista';

  @override
  String get suggestionDislike => 'Não gosto';

  @override
  String get suggestionDisliked => 'Não voltará a ser sugerido';

  @override
  String get removeFromQueueAction => 'Remover da fila';

  @override
  String get shuffleModeOff => 'Aleatório: desligado';

  @override
  String get shuffleModeOn => 'Aleatório: ligado';

  @override
  String get shuffleModePlus =>
      'Aleatório+: ligado (prima longamente para definições)';

  @override
  String get shufflePlusTitle => 'Aleatório+';

  @override
  String get shufflePlusNote =>
      'Ativa-se pelo botão aleatório (terceiro toque). Indisponível para álbuns em streaming, Jam e rádio';

  @override
  String shufflePlusEvery(int n) {
    return 'Uma sugestão a cada $n faixas';
  }

  @override
  String get shufflePlusUnmeteredOnly => 'Apenas por Wi‑Fi';

  @override
  String get shufflePlusUnmeteredOnlyHint =>
      'Sem sugestões com dados móveis ou redes com consumo limitado.';

  @override
  String get shufflePlusData =>
      'Consumo estimado: cerca de 15 MB por hora com uma sugestão a cada 4 faixas.';

  @override
  String get shufflePlusActive => 'Ativo: as sugestões chegam enquanto ouve.';

  @override
  String get shufflePlusOff => 'Desligado: o aleatório fica normal.';

  @override
  String get shufflePlusBlockJam => 'Inativo durante uma Jam';

  @override
  String get shufflePlusBlockShort =>
      'Precisa de uma lista com pelo menos 5 faixas';

  @override
  String get shufflePlusBlockNoTool => 'yt-dlp indisponível';

  @override
  String get shufflePlusBlockMetered => 'Em pausa: rede com consumo limitado';

  @override
  String get shufflePlusBlockStopped =>
      'Desligado até reiniciar: demasiados erros de reprodução';

  @override
  String get shufflePlusBlockOnline =>
      'Indisponível para um álbum em streaming';

  @override
  String get shufflePlusBlockRadio => 'Indisponível com a rádio';

  @override
  String get shufflePlusNoticeRateLimited =>
      'O YouTube pede para abrandar: sugestões em pausa durante 15 minutos';

  @override
  String get shufflePlusNoticeTooManyErrors =>
      'Demasiados erros de reprodução: sugestões desligadas até reiniciar';

  @override
  String get suggestionsRecentTitle => 'Sugeridos recentemente';

  @override
  String get suggestionsRecentEmpty =>
      'Ainda não há sugestões. Aparecem aqui quando usas o Aleatório+.';

  @override
  String get suggestionsClear => 'Limpar histórico';

  @override
  String get suggestionsClearBody =>
      'Esquece as sugestões e os «Não gosto»: as músicas podem voltar.';

  @override
  String suggestionsRowNote(String seed, String outcome) {
    return 'parecido com «$seed», $outcome';
  }

  @override
  String get suggestionOutcomeQueued => 'Na fila';

  @override
  String get suggestionOutcomeSkipped => 'Ignorado';

  @override
  String get suggestionOutcomeHeard => 'Ouvido';

  @override
  String get suggestionOutcomeDownloaded => 'Transferido';

  @override
  String get suggestionOutcomeDisliked => 'Não gosto';

  @override
  String get memorySuggestions => 'Sugestões do Aleatório+';

  @override
  String searchOnline(String query) {
    return 'Pesquisar «$query» online';
  }

  @override
  String get onlineBestResults => 'Melhores resultados';

  @override
  String onlineOthersChip(int count) {
    return 'Outros resultados ($count)';
  }

  @override
  String get onlineNoneSure => 'Nenhum resultado seguro';

  @override
  String get onlineInLibrary => 'Na sua biblioteca';

  @override
  String onlineShowAllCount(int count) {
    return 'Mostrar tudo ($count)';
  }

  @override
  String onlineOwnedHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resultados já na biblioteca ocultos',
      one: '1 resultado já na biblioteca oculto',
    );
    return '$_temp0';
  }

  @override
  String onlineArtistSongs(String artist) {
    return 'Músicas de $artist';
  }

  @override
  String get onlineFilterAll => 'Todas';

  @override
  String onlineFromSource(String source) {
    return 'De $source';
  }

  @override
  String get onlineAlsoVideo => 'também como vídeo';

  @override
  String get onlineListenVideo => 'Ouvir o vídeo';

  @override
  String onlineNoticeRateLimited(String source, String other) {
    return '$source pede uma pausa: resultados só de $other';
  }

  @override
  String onlineNoticeFailed(String source, String other) {
    return '$source não respondeu: resultados só de $other';
  }

  @override
  String get radioTitle => 'Rádio';

  @override
  String radioLibrarySubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count estações guardadas',
      one: '1 estação guardada',
      zero: 'Rádios ao vivo',
    );
    return '$_temp0';
  }

  @override
  String get radioSearchHint => 'Procurar uma estação';

  @override
  String radioOnlyCountry(String country) {
    return 'Só $country';
  }

  @override
  String get radioMine => 'As minhas rádios';

  @override
  String get radioNearYou => 'Perto de si';

  @override
  String get radioGenres => 'Géneros';

  @override
  String get radioTopListened => 'As mais ouvidas';

  @override
  String get radioChooseRegion => 'Escolher a região';

  @override
  String get radioRegionHint =>
      'As rádios próximas vêm do país e da região que escolher: a aplicação não usa a sua localização.';

  @override
  String radioCountryChip(String country) {
    return 'País: $country';
  }

  @override
  String get radioChooseCountry => 'Escolher o país';

  @override
  String radioOfflineList(String date) {
    return 'Sem ligação, lista de $date';
  }

  @override
  String get radioLoadFailed => 'Não foi possível carregar as estações';

  @override
  String get radioNoResults => 'Nenhuma estação encontrada';

  @override
  String get radioResults => 'Resultados';

  @override
  String get radioSave => 'Guardar em As minhas rádios';

  @override
  String get radioUnsave => 'Remover de As minhas rádios';

  @override
  String get radioSavedDone => 'Estação guardada';

  @override
  String get radioRemovedDone => 'Estação removida';

  @override
  String get radioNotResponding => 'não responde';

  @override
  String get radioLive => 'Em direto';

  @override
  String get reasonRadioUnavailable => 'a estação não responde';

  @override
  String radioDataPerHour(String mb) {
    return '≈ $mb MB por hora';
  }

  @override
  String get radioSite => 'Site da estação';

  @override
  String get radioSiteCopied => 'Endereço do site copiado';

  @override
  String get radioSearchSong => 'Procurar esta faixa';

  @override
  String get radioRenameTitle => 'Nome da estação';

  @override
  String get radioMobileNotice =>
      'A rádio usa cerca de 1 MB de dados por minuto.';

  @override
  String get radioAddAddress => 'Adicionar endereço';

  @override
  String get radioAddName => 'Nome';

  @override
  String get radioAddUrl => 'Endereço do stream';

  @override
  String get radioAddTest => 'Testar 10 segundos';

  @override
  String get radioAddTesting => 'A testar… se ouvir, pode guardar.';

  @override
  String get radioLinkEmpty => 'Escreva o endereço do stream';

  @override
  String get radioLinkNotAnAddress =>
      'Não parece um endereço: escreva-o por inteiro, por exemplo https://…';

  @override
  String get radioLinkBadScheme =>
      'O endereço deve começar por http:// ou https://';

  @override
  String get radioLinkNoEntries =>
      'O ficheiro não contém nenhum endereço para reproduzir';

  @override
  String get radioLinkTooBig =>
      'O ficheiro é demasiado grande para ser uma lista de estações';

  @override
  String get radioLinkFetchFailed => 'Não foi possível transferir o ficheiro';

  @override
  String get radioReorder => 'Arraste para reordenar';

  @override
  String get radioReorderFailed => 'Não foi possível guardar a nova ordem';

  @override
  String get memoryRadio => 'Rádio (listas de estações)';

  @override
  String get radioGenrePop => 'Pop';

  @override
  String get radioGenreRock => 'Rock';

  @override
  String get radioGenreClassicRock => 'Rock clássico';

  @override
  String get radioGenreJazz => 'Jazz';

  @override
  String get radioGenreBlues => 'Blues';

  @override
  String get radioGenreClassical => 'Clássica';

  @override
  String get radioGenreDance => 'Dance';

  @override
  String get radioGenreElectronic => 'Eletrónica';

  @override
  String get radioGenreHouse => 'House';

  @override
  String get radioGenreHipHop => 'Hip hop';

  @override
  String get radioGenreLoFi => 'Lo-fi';

  @override
  String get radioGenreChillout => 'Chillout';

  @override
  String get radioGenreSixties => 'Anos 60';

  @override
  String get radioGenreSeventies => 'Anos 70';

  @override
  String get radioGenreEighties => 'Anos 80';

  @override
  String get radioGenreNineties => 'Anos 90';

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
  String get radioGenreNews => 'Notícias';

  @override
  String get radioGenreTalk => 'Conversa';

  @override
  String get radioGenreSports => 'Desporto';

  @override
  String get newReleasesTitle => 'Novidades';

  @override
  String get releasesTopArtists => 'Seguir automaticamente os mais ouvidos';

  @override
  String get releasesTopArtistsHint =>
      'Os 15 artistas mais ouvidos nos últimos 90 dias, procurados no YouTube Music.';

  @override
  String get releasesNotify => 'Notificações de novidades';

  @override
  String get releasesNotifyHint => 'No máximo uma por dia, apenas no Android.';

  @override
  String get releasesUnmetered => 'Verificar apenas no Wi‑Fi';

  @override
  String get releasesUnmeteredHint =>
      'Uma verificação por dia usa cerca de 0,5 MB.';

  @override
  String get releasesTopCardTitle =>
      'Quer saber quando os seus artistas mais ouvidos lançam músicas novas?';

  @override
  String get releasesTopCardYes => 'Ativar';

  @override
  String get releasesTopCardNo => 'Não, obrigado';

  @override
  String get releasesCheckNow => 'Verificar agora';

  @override
  String releasesLastCheck(String when) {
    return 'Última verificação: $when';
  }

  @override
  String get releasesNeverChecked => 'Nunca verificado';

  @override
  String releasesPaused(String time) {
    return 'O YouTube pede uma pausa: tento de novo às $time';
  }

  @override
  String get releasesChecking => 'Verificando…';

  @override
  String get releasesCheckNone => 'Sem novidades';

  @override
  String releasesCheckFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count novidades',
      one: '1 novidade',
    );
    return '$_temp0';
  }

  @override
  String get releasesCantCheck =>
      'Não é possível verificar agora: sem rede ou sem artistas seguidos.';

  @override
  String get releasesChanged =>
      'O YouTube Music mudou de formato: tento de novo na próxima ronda.';

  @override
  String get releasesEmpty =>
      'Sem novidades nos últimos 90 dias. Abra a página de um artista e toque em «Seguir».';

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
      'Ainda não segue nenhum artista. Abra a página de um artista e toque em «Seguir».';

  @override
  String get followAction => 'Seguir';

  @override
  String get followingAction => 'A seguir';

  @override
  String followStopTitle(String name) {
    return 'Deixar de seguir $name?';
  }

  @override
  String get followStopBody => 'As novidades deixarão de ser avisadas.';

  @override
  String get followOnYtm => 'Seguir no YouTube Music';

  @override
  String get followStop => 'Deixar de seguir';

  @override
  String followedNow(String name) {
    return 'Agora segue $name';
  }

  @override
  String get followMute => 'Silenciar notificações';

  @override
  String get followUnmute => 'Reativar notificações';

  @override
  String get followedTopListened => 'Mais ouvido';

  @override
  String get followedToConfirm => 'A confirmar';

  @override
  String get followedNotFound => 'Não encontrado';

  @override
  String get followedRetry => 'Tentar de novo';

  @override
  String releaseAlbumYear(String year) {
    return 'Álbum, $year';
  }

  @override
  String releaseSingleYear(String year) {
    return 'Single, $year';
  }

  @override
  String get releaseAlbumPlain => 'Álbum';

  @override
  String get releaseSinglePlain => 'Single';

  @override
  String releaseVariants(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'e mais $count versões',
      one: 'e mais 1 versão',
    );
    return '$_temp0';
  }

  @override
  String get releaseNewBadge => 'Novo';

  @override
  String get activityReleases => 'Verificando novidades';

  @override
  String releaseNotifyOne(String title, String artist) {
    return 'Novidade: $title de $artist';
  }

  @override
  String releaseNotifyMany1(int count, String a) {
    return '$count novidades: $a';
  }

  @override
  String releaseNotifyMany2(int count, String a, String b) {
    return '$count novidades: $a e $b';
  }

  @override
  String releaseNotifyManyMore(int count, String a, String b, int others) {
    return '$count novidades: $a, $b e mais $others';
  }

  @override
  String get releaseNotifyShow => 'Mostrar';

  @override
  String get reportIssue => 'Comunicar um problema';

  @override
  String get reportIssueHint => 'Abre o GitHub com o texto já preenchido';

  @override
  String get reportKindBug => 'Defeito';

  @override
  String get reportKindIdea => 'Ideia';

  @override
  String get reportTitleLabel => 'Título';

  @override
  String get reportDescLabel => 'Descrição';

  @override
  String reportDescHelper(int n) {
    return 'O que aconteceu e como reproduzir (pelo menos $n caracteres)';
  }

  @override
  String get reportAttach => 'Anexar informações técnicas';

  @override
  String get reportAttachPreview => 'Será enviado exatamente isto:';

  @override
  String get reportOpen => 'Abrir no GitHub';

  @override
  String get reportCopy => 'Copiar texto';

  @override
  String get reportCopied => 'Texto copiado';

  @override
  String get reportGithubNote =>
      'É preciso uma conta do GitHub; sem ela, copie o texto e envie como preferir.';

  @override
  String get reportOpenFailed =>
      'Não foi possível abrir o navegador: o texto foi copiado';

  @override
  String get reportLogShortened =>
      'O registo será encurtado para caber no endereço';

  @override
  String get reportNoLog => 'Sem avisos nem erros recentes no registo';

  @override
  String get reportUnknown => 'Desconhecido';

  @override
  String get iconAskTitle => 'Mudar também o ícone do app?';

  @override
  String get iconProblems =>
      'O ícone muda quando você sai do app. Possíveis problemas:\n• o launcher pode levar alguns segundos para atualizá-lo, ou mostrar por um instante dois ícones ou nenhum;\n• em alguns launchers o ícone da tela inicial é removido ou movido e precisa ser recolocado à mão (os widgets ficam);\n• atalhos da tela inicial criados com o ícone antigo podem parar de funcionar;\n• o app pode sumir por um instante dos apps recentes;\n• raramente o Android fecha o app e a música para.\nNo computador o ícone não muda.';

  @override
  String get iconChange => 'Mudar o ícone';

  @override
  String get iconKeep => 'Deixar como está';

  @override
  String get iconDontAsk => 'Não perguntar de novo';

  @override
  String get iconFollowTitle => 'Ícone do tema';

  @override
  String get iconFollowSubtitle =>
      'O ícone acompanha o tema e a cor quando você sai do app';

  @override
  String get exportifySyncTitle => 'Sincronizar do Spotify';

  @override
  String exportifySyncChanges(int added, int removed) {
    return '+$added novas, −$removed removidas';
  }

  @override
  String get exportifySyncNew => 'Nova playlist';

  @override
  String get exportifySyncChoose => 'A escolher';

  @override
  String get exportifySyncNoChanges => 'Sem alterações';

  @override
  String exportifySyncSkipped(int n) {
    return '$n arquivos ignorados (playlists ilegíveis)';
  }

  @override
  String exportifySyncGo(int n) {
    return 'Sincronizar $n';
  }

  @override
  String exportifySyncDone(int n) {
    return '$n playlists sincronizando: acompanhe no Centro de atividade';
  }

  @override
  String get exportifySyncEmpty => 'Nenhuma playlist no ZIP';

  @override
  String get exportifySyncPickTitle => 'Escolher a playlist';

  @override
  String get csvImportOpenExportify => 'Abrir exportify.net';

  @override
  String get csvImportOpenFailed => 'Não foi possível abrir o navegador';

  @override
  String get csvImportZipHint =>
      'Com «Export All» você obtém um ZIP com todas as playlists: escolha-o aqui e sincronize todas juntas.';

  @override
  String get exportifySyncFailed => 'Falha na sincronização';

  @override
  String get exportifySyncEntryFailed => 'Não foi possível ler esta playlist';

  @override
  String get exportifySyncLoadFailed =>
      'Não foi possível ler as playlists do ZIP';

  @override
  String get exportifyRemindTitle => 'Lembrar-me de sincronizar com o Spotify';

  @override
  String get exportifyRemindOff => 'Desligado';

  @override
  String exportifyRemindDays(int days) {
    return '$days dias';
  }

  @override
  String get exportifyCardTitle =>
      'É hora de sincronizar as playlists com o Spotify';

  @override
  String get exportifyCardOpen => 'Abrir o Exportify';

  @override
  String get exportifyCardLater => 'Mais tarde';

  @override
  String get exportifyFoundTitle => 'Exportação do Exportify encontrada';

  @override
  String get exportifyFoundSync => 'Sincronizar';

  @override
  String get onboardingSpotifyTitle => 'Playlists do Spotify';

  @override
  String get onboardingSpotifyBody =>
      'No exportify.net você baixa as playlists do Spotify em um arquivo. O Codecore o pega e as atualiza aqui.\nNão é preciso ligar nenhuma conta: o arquivo é você quem baixa.';

  @override
  String get deezerMeta => 'Metadados do Deezer';

  @override
  String get deezerMetaHint =>
      'Só dados (capas, números de faixa), nunca música';

  @override
  String get deezerMetaNote =>
      'Uso privado e não comercial. Os termos do Deezer proíbem promover o download não autorizado, e o Codecore baixa do YouTube: o risco é seu.';

  @override
  String get acoustId => 'Reconhecer pelo som (AcoustID)';

  @override
  String get acoustIdHint =>
      'Só a impressão digital da faixa é enviada, nunca o áudio';

  @override
  String get settingsSpinCover => 'Capa giratória';

  @override
  String get settingsSpinCoverHint => 'No player, enquanto a música toca';

  @override
  String get themeLowContrastWarning =>
      'Algumas cores de texto ficam difíceis de ler sobre o fundo (abaixo de 4,5:1). O tema fica como está.';

  @override
  String get streamCacheTitle => 'Espaço para streaming';

  @override
  String streamCacheUsage(String used, String limit) {
    return '$used de $limit';
  }

  @override
  String get streamCacheClear => 'Esvaziar';

  @override
  String get streamCacheCleared => 'Cache de streaming esvaziado';

  @override
  String get streamCacheClearFailed =>
      'Não foi possível esvaziar o cache de streaming';

  @override
  String get playerLoading => 'A carregar…';

  @override
  String get ytmAlbumQueue => 'Adicionar álbum à fila';

  @override
  String get addedToLibrary => 'Adicionada à biblioteca';

  @override
  String get promoteNoSpace => 'Espaço insuficiente para transferir a faixa';

  @override
  String get promoteFailed => 'Não foi possível mover a faixa';

  @override
  String get creditsDetails => 'Créditos e detalhes';

  @override
  String get creditsDetailsHint => 'Autores, produtores e detalhes das faixas';

  @override
  String get creditsDetailsNote => 'Usa também uma API não oficial do Deezer';

  @override
  String get creditRoleVocals => 'Voz';

  @override
  String get creditRoleBackingVocals => 'Vocais de apoio';

  @override
  String get creditRoleGuitar => 'Guitarra';

  @override
  String get creditRoleBassGuitar => 'Baixo';

  @override
  String get creditRoleDrums => 'Bateria';

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
  String get creditRoleArranger => 'Arranjador';

  @override
  String get creditRoleProducer => 'Produtor';

  @override
  String get creditRoleAdditionalProducer => 'Produtor adicional';

  @override
  String get creditRoleMix => 'Mixagem';

  @override
  String get creditRoleMastering => 'Masterização';

  @override
  String get creditRoleRecording => 'Gravação';

  @override
  String get creditRoleEngineer => 'Engenheiro de som';

  @override
  String get creditRoleProgramming => 'Programação';

  @override
  String get creditRoleDrumProgrammer => 'Programação de bateria';

  @override
  String get creditRoleMusicPublisher => 'Editora musical';

  @override
  String get creditsGroupPerformers => 'Intérpretes e instrumentos';

  @override
  String get creditsGroupWriters => 'Autores';

  @override
  String get creditsGroupProduction => 'Produção e técnicos';

  @override
  String get creditsGroupOther => 'Outros';

  @override
  String get creditsTitle => 'Créditos e detalhes';

  @override
  String get creditsShowAll => 'Mostrar tudo';

  @override
  String get creditsRefresh => 'Atualizar';

  @override
  String get creditsAppearsAs => 'Aparece como';

  @override
  String get creditsInCredits => 'Nos créditos';

  @override
  String get creditsRefreshFailed => 'Não foi possível atualizar os créditos';

  @override
  String get creditsBpm => 'BPM';

  @override
  String get creditsLabel => 'Gravadora';

  @override
  String get creditsDigitalRelease => 'Lançamento digital';

  @override
  String get creditsPhysicalRelease => 'Lançamento físico';

  @override
  String get creditsKindSingle => 'Single';

  @override
  String get creditsKindEp => 'EP';

  @override
  String get creditsRank => 'Posição nas paradas';

  @override
  String get creditsAlbumFans => 'Fãs do álbum';

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
      'Procura curiosidades na Wikipédia para as faixas novas';

  @override
  String memoryEnrichment(String size) {
    return 'Enriquecimento: $size';
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
  String get activityPodcastRefresh => 'A atualizar os podcasts';

  @override
  String get activityRadio => 'A verificar as rádios guardadas';

  @override
  String activityEnrichBackground(int done, int total) {
    return 'A completar o enriquecimento: $done de $total';
  }

  @override
  String get enrichRoundTitle => 'Ronda de enriquecimento';

  @override
  String get enrichRoundUpdated => 'Atualizados';

  @override
  String get enrichRoundNone => 'Sem resultado';

  @override
  String get enrichRoundGone => 'Nenhuma música para mostrar';

  @override
  String get enrichPartMeta => 'Dados da música';

  @override
  String get enrichPartLyrics => 'Letra';

  @override
  String get enrichPartSynced => 'Letra sincronizada';

  @override
  String get enrichPartCurio => 'Curiosidades';

  @override
  String get enrichPartCredits => 'Créditos';

  @override
  String get coverChange => 'Alterar capa';

  @override
  String get coverRestoreOriginal => 'Restaurar capa original';

  @override
  String get coverSourceDevice => 'Do dispositivo';

  @override
  String get coverSourceLibrary => 'Da biblioteca';

  @override
  String get coverSourceOnline => 'Online';

  @override
  String coverSizePx(int w, int h) {
    return '$w × $h';
  }

  @override
  String get speakerPermTitle => 'Permissão de Bluetooth';

  @override
  String get speakerPermBody =>
      'Para reconhecer a tua coluna, o Codecore precisa de ver que dispositivos Bluetooth estão ligados. Não lê mais nada.';

  @override
  String get speakerPermAllow => 'Permitir';

  @override
  String get speakerNotNow => 'Agora não';

  @override
  String speakerAskTitle(String name) {
    return '$name é uma coluna?';
  }

  @override
  String get speakerAskBody =>
      'Se for, ao ligar o Codecore abre sozinho uma Jam a que os outros se podem juntar.';

  @override
  String get speakerYes => 'Sim';

  @override
  String get speakerNo => 'Não';

  @override
  String get speakerJamSection => 'Jam na coluna';

  @override
  String get speakerJamHint =>
      'Quando uma coluna Bluetooth se liga, o Codecore abre sozinho uma Jam a que os outros se podem juntar.';

  @override
  String get speakerNoDevices => 'Ainda não há dispositivos marcados';

  @override
  String get speakerIsSpeaker => 'Coluna';

  @override
  String get speakerNotSpeaker => 'Não é uma coluna';

  @override
  String get speakerPermDenied => 'Permissão de Bluetooth recusada';

  @override
  String get speakerPermRetry => 'Toca para pedir de novo';

  @override
  String speakerChange(String name) {
    return 'Alterar $name';
  }

  @override
  String jamInviteBanner(String name) {
    return 'Entrar na Jam de $name';
  }

  @override
  String get jamInviteDismiss => 'Ocultar';

  @override
  String get speakerAwayNotice => 'Liga uma coluna';

  @override
  String get jamFull => 'A Jam está cheia';

  @override
  String get jamAddFailed => 'Não adicionado à Jam';

  @override
  String get jamNotFoundOnline =>
      'Não encontrado online, não pode ser adicionado';

  @override
  String get jamLeft => 'Saiu da Jam';

  @override
  String get speakerContinueOnPhone => 'Continuar no telemóvel';

  @override
  String get speakerContinueOnPhoneLabel =>
      'Continuar no telemóvel: a Jam toca no altifalante deste telemóvel, sem a coluna';

  @override
  String get speakerOfferTitle => 'Tocar a Jam na tua coluna?';

  @override
  String get speakerOfferBody =>
      'A tua coluna está ligada e a Jam está parada. Se quiseres, a música continua a partir daqui.';

  @override
  String get jamRemoteTitle => 'Jam à distância';

  @override
  String get jamRemoteHint =>
      'Os brokers (servidores) da Jam à distância, por ordem de preferência.';

  @override
  String get jamBrokerAdd => 'Adicionar broker';

  @override
  String get jamBrokerHost => 'Endereço';

  @override
  String get jamBrokerPort => 'Porta';

  @override
  String get jamBrokerTls => 'Ligação cifrada (TLS)';

  @override
  String get jamBrokerNoTls =>
      'Sem TLS, qualquer pessoa na rede pode ler o que passa pelo broker. Usa só se souberes o que fazes.';

  @override
  String get jamBrokerInvalid => 'Endereço ou porta inválidos';

  @override
  String get jamBrokerTest => 'Testar ligação';

  @override
  String jamBrokerTestOk(String broker) {
    return '$broker: ligação bem-sucedida';
  }

  @override
  String jamBrokerTestFail(String broker) {
    return '$broker: não consigo ligar (rede, certificado ou servidor inacessível)';
  }

  @override
  String get jamBrokerRestore => 'Repor';

  @override
  String get jamBrokerMoveUp => 'Subir';

  @override
  String get jamBrokerRemove => 'Remover';

  @override
  String get jamSuspend => 'Suspender';

  @override
  String get jamBlock => 'Bloquear';

  @override
  String get jamSuspendTitle => 'Suspender por quanto tempo?';

  @override
  String get jamUntilJamEnds => 'Até ao fim da Jam';

  @override
  String get jamBlockedTitle => 'Dispositivos bloqueados';

  @override
  String get jamSuspendedTitle => 'Suspensos';

  @override
  String get jamUnblock => 'Desbloquear';

  @override
  String jamSuspendedUntil(String time) {
    return 'Até às $time';
  }

  @override
  String get jamTooSoon => 'Espera um momento antes de tentar de novo';

  @override
  String enrichInterrupted(int updated, int notFound) {
    return 'Enriquecimento interrompido por um erro: $updated atualizadas, $notFound não encontradas';
  }

  @override
  String enrichLibraryDue(int count, int minutes) {
    return '$count faixas por completar, cerca de $minutes minutos';
  }

  @override
  String get enrichLibraryComplete => 'Biblioteca completa';

  @override
  String get enrichLibraryStop => 'Interromper';

  @override
  String get activityEnrichWaiting => 'A completar: em espera';

  @override
  String logRecogSources(String list) {
    return 'Reconhecidas: $list';
  }

  @override
  String get recogSrcTags => 'tags';

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
    return 'Sugestão: $identity';
  }

  @override
  String get recogAccept => 'Aceitar';

  @override
  String get recogDiscard => 'Descartar';

  @override
  String recogAcceptSem(String identity) {
    return 'Aceitar a sugestão $identity';
  }

  @override
  String recogDiscardSem(String identity) {
    return 'Descartar a sugestão $identity';
  }

  @override
  String get recogCover => 'Cover';

  @override
  String recogCoverOf(String identity) {
    return 'Cover de $identity';
  }

  @override
  String recogToConfirm(int count) {
    return 'Por confirmar ($count)';
  }

  @override
  String get recogAcceptAll => 'Aceitar todas';

  @override
  String get recogNoProposals => 'Tudo confirmado';

  @override
  String recogFromTo(String from, String to) {
    return 'De $from para $to';
  }

  @override
  String get logRevert => 'Restaurar';

  @override
  String get recogActionFailed => 'A ação falhou';

  @override
  String get logRevertFailed => 'Não foi possível restaurar esta correção';

  @override
  String get jamInviteNearby => 'Convidar quem está por perto';

  @override
  String get jamInviteHint => 'Quem ler o QR ou digitar o código entra na Jam.';

  @override
  String get jamBridgeConnecting => 'Conectando…';

  @override
  String get jamBridgeRetrying => 'Conexão interrompida, tentando de novo…';

  @override
  String get jamBridgeUnreachable => 'Broker inacessível';

  @override
  String jamCodeExpiresIn(int seconds) {
    return 'Expira em $seconds s';
  }

  @override
  String get jamEnterCode => 'Entrar com um código';

  @override
  String get jamCodeLabel => 'Código';

  @override
  String get jamScanQr => 'Ler o QR';

  @override
  String get jamJoinAction => 'Entrar';

  @override
  String get jamCodeInvalid => 'Código inválido';

  @override
  String get jamCodeExpired => 'Código expirado, peça um novo';

  @override
  String get jamHostNoAnswer => 'O anfitrião não respondeu';

  @override
  String get jamCustomBroker =>
      'Esta Jam usa um broker personalizado: leia o QR';

  @override
  String get jamLinkReconnecting => 'Conexão perdida, tentando de novo…';

  @override
  String get jamHostSilent => 'Anfitrião inacessível, tentando de novo…';

  @override
  String get jamMemberUnreachable => 'inacessível';

  @override
  String get jamRemoteActive => 'Jam remota ativa';

  @override
  String get jamRemoteEnd => 'Encerrar';

  @override
  String get jamDeclinedHost => 'O anfitrião recusou o pedido';

  @override
  String get jamBusyHost => 'O anfitrião já tem uma Jam em curso';

  @override
  String get jamWaitingHost => 'À espera de que o anfitrião aceite…';

  @override
  String get jamFriendsTitle => 'Amigos da Jam';

  @override
  String get jamFriendsEmpty =>
      'Ainda sem amigos. Após a primeira entrada aceite, os dois dispositivos guardam-se mutuamente.';

  @override
  String get jamFriendRemove => 'Remover';

  @override
  String jamFriendRemoveTitle(String name) {
    return 'Remover $name?';
  }

  @override
  String get jamFriendRemoveBody =>
      'Deixam de se reconhecer sem perguntar. Este dispositivo muda a sua chave de anúncio.';

  @override
  String get jamAutoAcceptFriends => 'Aceitar amigos sem perguntar';

  @override
  String get jamAutoAcceptFriendsHint =>
      'Se o telemóvel de um amigo for roubado, quem o tiver pode entrar na tua Jam estando perto.';

  @override
  String get jamFriendBadge => 'Amigo';

  @override
  String get jamNearbyJoin => 'Entrar numa Jam por perto';

  @override
  String get jamBleTitle => 'Procurar Jams por perto';

  @override
  String get jamBleBody12 =>
      'O Android pede a permissão «Dispositivos por perto» para procurar e anunciar Jams por Bluetooth. A app não lê onde estás.';

  @override
  String get jamBleBody11 =>
      'É preciso a permissão de localização: o Android exige-a para procurar por Bluetooth; a app não lê onde estás.';

  @override
  String get jamBleAllow => 'Permitir';

  @override
  String get jamBleNotNow => 'Agora não';

  @override
  String get jamBleLocationOff =>
      'Liga a localização do Android: é precisa para procurar Jams por Bluetooth. Entretanto podes usar o código ou o QR.';

  @override
  String get jamNearbyScanTitle => 'Procurar Jams por perto';

  @override
  String get jamNearbyScanHint => 'Por Bluetooth, só com a app aberta';

  @override
  String get streamCardsUnavailable => 'Indisponível';

  @override
  String get streamCardsUnavailableBody =>
      'A letra, as curiosidades e os créditos desta faixa não chegaram. Pode ser da rede ou da fonte.';

  @override
  String get closeKeyboard => 'Fechar teclado';

  @override
  String get loadingContent => 'Carregando…';

  @override
  String shufflePlusChoosing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Shuffle+ está escolhendo $count faixas…',
      one: 'Shuffle+ está escolhendo 1 faixa…',
    );
    return '$_temp0';
  }

  @override
  String statsBarValue(String when, String time) {
    return '$when, $time';
  }

  @override
  String get homeRadioLive => 'Ao vivo';

  @override
  String get closeSearch => 'Fechar a pesquisa';

  @override
  String get librarySearchHint => 'Pesquisar na biblioteca';

  @override
  String get genreMixTag => 'Sugerida';

  @override
  String get genreMixOffJam => 'Sugestões desativadas: Jam em curso';

  @override
  String get genreMixOffMetered =>
      'Sugestões desativadas: rede com consumo limitado';

  @override
  String get genreMixOffOffline => 'Sugestões desativadas: sem rede';

  @override
  String get genreMixOffNoTool =>
      'Sugestões desativadas: ferramenta online ausente';

  @override
  String get genreMixOffRateLimited => 'Sugestões em pausa: demasiados pedidos';

  @override
  String get playerEmptyTitle => 'Nada a tocar';

  @override
  String get playerEmptyHint => 'Escolhe por onde continuar.';

  @override
  String get playerEmptyNoQueue => 'Escolhe uma faixa para começar';

  @override
  String playerLastQueue(String name) {
    return 'Última fila: $name';
  }

  @override
  String get playerResumeLastQueue => 'Retomar a última fila';

  @override
  String playerResumeLastQueueSub(String name, String tracks) {
    return '$name, $tracks';
  }

  @override
  String get playerShufflePlusLibrary => 'Shuffle+ da biblioteca';

  @override
  String get playerShufflePlusLibrarySub =>
      'A tua biblioteca aleatória, com sugestões';

  @override
  String get playerRecentlyAdded => 'Adicionadas há pouco';

  @override
  String get reviewSearch => 'Pesquisar';

  @override
  String get recogTitle => 'Por confirmar';

  @override
  String recogSuggested(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count correções sugeridas. Revê-as uma a uma ou aceita todas.',
      one: '1 correção sugerida',
    );
    return '$_temp0';
  }

  @override
  String recogAcceptAllCount(int count) {
    return 'Aceitar todas ($count)';
  }

  @override
  String recogAcceptedAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count correções aceites',
      one: '1 correção aceite',
    );
    return '$_temp0. Os ficheiros são atualizados em segundo plano.';
  }

  @override
  String get recogNoProposalsHint => 'Já não há nada para verificar.';

  @override
  String get logToday => 'Hoje';

  @override
  String get logYesterday => 'Ontem';

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
  String get logRetention => 'O registo guarda os últimos 30 dias.';

  @override
  String get logNoMatch => 'Nenhuma entrada com este filtro.';

  @override
  String get logPickEntry => 'Escolha uma entrada para ver os detalhes.';

  @override
  String get logFilterAll => 'Tudo';

  @override
  String get logFilterDownload => 'Transferências';

  @override
  String get logFilterLibrary => 'Biblioteca';

  @override
  String get logFilterEnrich => 'Enriquecimento';

  @override
  String get logFilterCorrections => 'Correções';

  @override
  String get logFilterErrors => 'Erros';

  @override
  String get logFailedLabel => 'Falhou';

  @override
  String get logStoppedLabel => 'Parado';

  @override
  String get logClearMenu => 'Limpar registo';

  @override
  String get logClearTitle => 'Limpar o registo?';

  @override
  String get logClearConfirm => 'Limpar';

  @override
  String get logPendingSub => 'Correções sugeridas para as suas músicas';

  @override
  String get logPendingReview => 'Rever';

  @override
  String logPendingMore(int count) {
    return 'e mais $count';
  }

  @override
  String get logHowTitle => 'Como resolver';

  @override
  String get logTechTitle => 'Detalhe técnico';

  @override
  String get logOpenSongs => 'Ver as músicas';

  @override
  String logHowSettings(String settings, String page) {
    return 'Abra $settings e depois «$page».';
  }

  @override
  String logHowUpdate(String button) {
    return 'Toque em «$button» junto ao yt-dlp.';
  }

  @override
  String get logHowWait => 'Aguarde alguns minutos.';

  @override
  String get logHowOnline => 'Verifique se está online.';

  @override
  String get logDlDone => 'Música transferida';

  @override
  String get logDlFailed => 'Transferência falhada';

  @override
  String logDlGroup(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas transferidas',
      one: '1 música transferida',
    );
    return '$_temp0';
  }

  @override
  String get logDlGroupShow => 'Mostrar as músicas';

  @override
  String get logDlGroupHide => 'Ocultar as músicas';

  @override
  String get logTransferDone => 'Músicas enviadas';

  @override
  String get logTransferFailed => 'Envio falhado';

  @override
  String get logScanDone => 'Biblioteca atualizada';

  @override
  String get logScanDoneSub => 'Todas as pastas verificadas.';

  @override
  String get logScanStopped => 'Análise parada';

  @override
  String get logScanFailed => 'Análise falhada';

  @override
  String get logStoppedSub => 'Parou antes do fim.';

  @override
  String get logFailedSub => 'Parou devido a um erro.';

  @override
  String get logEnrichDone => 'Enriquecimento concluído';

  @override
  String get logEnrichInterrupted => 'Enriquecimento interrompido';

  @override
  String get logEnrichInterruptedSub =>
      'Parou devido a um erro; o trabalho feito está guardado.';

  @override
  String get logBgDone => 'Letras e capas adicionadas';

  @override
  String get logBgDoneSub => 'Conclusão em segundo plano.';

  @override
  String get logBgStopped => 'Conclusão parada';

  @override
  String get logBgStoppedSub => 'Nenhuma fonte responde neste momento.';

  @override
  String get logBgFailed => 'Conclusão falhada';

  @override
  String get logBgFailedSub => 'Um erro parou-a.';

  @override
  String get logSecondOpinion => 'Segunda opinião do YouTube Music';

  @override
  String get logSecondOpinionSub => 'As músicas incertas foram verificadas.';

  @override
  String get logSecondOpinionFailed => 'Segunda opinião interrompida';

  @override
  String get logCleanup => 'Duplicados procurados';

  @override
  String get logCleanupSub => 'As músicas da biblioteca foram comparadas.';

  @override
  String get logGenres => 'Géneros das músicas relidos';

  @override
  String get logGenresSub =>
      'As etiquetas das músicas foram lidas para encontrar todos os géneros.';

  @override
  String get logCountries => 'Países dos artistas procurados';

  @override
  String get logCountriesSub =>
      'Foi procurado o país de origem dos artistas da biblioteca.';

  @override
  String get logReleases => 'Novidades verificadas';

  @override
  String get logReleasesSub =>
      'Procuradas as novidades dos artistas que segue.';

  @override
  String get logPodcasts => 'Podcasts atualizados';

  @override
  String get logRadio => 'Rádios verificadas';

  @override
  String get logTaskFailed => 'Tarefa falhada';

  @override
  String logImportDone(String name) {
    return 'Lista «$name» importada';
  }

  @override
  String logImportReady(String name) {
    return 'Lista «$name» pronta';
  }

  @override
  String get logImportFailed => 'Importação falhada';

  @override
  String get logImportRate => 'Importação abrandada pelo YouTube';

  @override
  String get logImportPaused => 'Importação em pausa';

  @override
  String get logWhyToolMissing =>
      'Falta o componente para transferir do YouTube.';

  @override
  String get logWhyToolOld =>
      'O componente para transferir do YouTube é demasiado antigo.';

  @override
  String get logWhyNetwork => 'Rede indisponível.';

  @override
  String get logWhyRate => 'O YouTube pediu para abrandar.';

  @override
  String get logWhyFailing => 'Demasiados erros seguidos: coloquei-a em pausa.';

  @override
  String get logCorrectionTitle => 'Título e artista corrigidos';

  @override
  String logChipSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas',
      one: '1 música',
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
    return '$done de $total músicas';
  }

  @override
  String logChipUpdated(int count) {
    return '$count atualizadas';
  }

  @override
  String logChipNotFound(int count) {
    return '$count não encontradas';
  }

  @override
  String logChipNoResult(int count) {
    return '$count sem resultado';
  }

  @override
  String get logFileTitle => 'Correção guardada, ficheiro não atualizado';

  @override
  String get logHowFileMissing =>
      'Verifique se a música ainda está na sua pasta.';

  @override
  String get logHowFileReadOnly =>
      'Retire o só de leitura do ficheiro ou da sua pasta e corrija a música novamente.';

  @override
  String get logHowFileRetry =>
      'Verifique se há espaço no disco e se o ficheiro não está em uso e corrija a música novamente.';

  @override
  String get logClearBody =>
      'Apaga todas as entradas e tira da lista as transferências concluídas. Depois já não poderá repor as correções. As suas músicas ficam onde estão.';

  @override
  String logHowResume(String button) {
    return 'Toque em «$button» na importação em pausa, na lista de atividades.';
  }

  @override
  String get logEnrichStopped => 'Enriquecimento parado';

  @override
  String logCorrectionSem(String from, String to) {
    return 'De $from para $to';
  }

  @override
  String get smartAll => 'Todas as condições';

  @override
  String get smartAny => 'Pelo menos uma';

  @override
  String get smartAllNote => 'As faixas têm de cumprir todos os filtros.';

  @override
  String get smartAnyNote => 'Basta cumprir um filtro.';

  @override
  String get smartAddFilter => 'Adicionar filtro';

  @override
  String get smartGroupMusic => 'Música';

  @override
  String get smartGroupListening => 'Audição';

  @override
  String get smartGroupFile => 'Ficheiro';

  @override
  String get smartFieldTag => 'Tags';

  @override
  String get smartFieldAlbumArtist => 'Artista do álbum';

  @override
  String get smartFieldCountry => 'Nacionalidade';

  @override
  String get smartFieldPlays => 'Reproduções';

  @override
  String get smartFieldLastPlayed => 'Última reprodução';

  @override
  String get smartFieldAdded => 'Adicionado';

  @override
  String get smartFieldBitrate => 'Taxa de bits';

  @override
  String get smartFieldFolder => 'Pasta';

  @override
  String get smartFlagLyrics => 'Com letra';

  @override
  String get smartEnrichedOnly => 'Só para faixas enriquecidas';

  @override
  String get smartInclude => 'Incluir';

  @override
  String get smartExclude => 'Excluir';

  @override
  String get smartPickValues => 'Escolher valores';

  @override
  String get smartAddValue => 'Adicionar';

  @override
  String get smartValueHint => 'Escreva um valor';

  @override
  String get smartDone => 'Concluído';

  @override
  String get smartIncomplete =>
      'Incompleto: conclua-o ou remova-o para guardar.';

  @override
  String get smartRemoveFilter => 'Remover filtro';

  @override
  String smartRemoveValue(String value) {
    return 'Remover $value';
  }

  @override
  String get smartFrom => 'De';

  @override
  String get smartTo => 'Até';

  @override
  String get smartMoreThan => 'Mais de';

  @override
  String get smartLessThan => 'Menos de';

  @override
  String get smartEqualTo => 'Igual a';

  @override
  String get smartAgeRecent => 'Nos últimos';

  @override
  String get smartAgeOlder => 'Há mais de';

  @override
  String get smartDays => 'dias';

  @override
  String get smartMinutes => 'minutos';

  @override
  String get smartContains => 'Contém';

  @override
  String get smartAdvancedNote => 'O texto da regra, só de leitura.';

  @override
  String get smartNotVisual =>
      'Esta regra é demasiado elaborada para o editor de filtros. Fica como está: vê-la em Avançadas e, se a guardar sem mexer, não muda.';

  @override
  String get smartNoFilters => 'Adicione um filtro para começar.';

  @override
  String get smartLimitShort => 'Máximo';

  @override
  String get smartIs => 'É';

  @override
  String get smartRestart => 'Recomeçar com filtros';

  @override
  String get smartRestarted => 'Regra apagada';

  @override
  String get smartCountError => 'Contagem indisponível';

  @override
  String artistMergedNote(int count) {
    return '$count perfis unidos';
  }

  @override
  String get artistSplit => 'Separar perfis';

  @override
  String get artistMergeWith => 'Unir com…';

  @override
  String artistSameWarn(String name) {
    return 'Parece o mesmo artista de outro perfil ($name).';
  }

  @override
  String get artistMergeYes => 'Unir';

  @override
  String get artistNotSame => 'São diferentes';

  @override
  String get artistMerged => 'Perfis unidos.';

  @override
  String get artistSplitDone => 'Perfis separados.';

  @override
  String get artistNotSameDone =>
      'Certo, não vou perguntar de novo para estes dois perfis.';

  @override
  String get artistMergePick => 'Com qual perfil?';

  @override
  String get mergedSheetTitle => 'Perfis unidos';

  @override
  String get artistMainProfile => 'Principal';

  @override
  String artistOtherProfileOf(String name) {
    return 'Outro perfil de $name';
  }

  @override
  String get artistSeparate => 'Separar';

  @override
  String get artistSeparated => 'Perfil separado.';

  @override
  String get settingsMergedArtists => 'Artistas unidos';

  @override
  String get settingsMergedArtistsHint =>
      'Veja os perfis unidos e separe-os, ou tire as marcas de «diferentes».';

  @override
  String get mergedArtistsEmpty => 'Nenhum artista unido.';

  @override
  String get mergedArtistsEmptyHelp =>
      'Quando une dois perfis do mesmo artista, eles aparecem aqui.';

  @override
  String get mergedArtistsSplitAll => 'Separar tudo';

  @override
  String get notSameTitle => 'Marcados como diferentes';

  @override
  String get notSameRemove => 'Remover';

  @override
  String get notSameEmpty => 'Nenhum par está marcado como diferente.';

  @override
  String get openArtistPage => 'Abrir a página do artista';

  @override
  String get podcastYours => 'Os teus podcasts';

  @override
  String get podcastDiscover => 'Descobrir';

  @override
  String get podcastChartTitle => 'Tabela do Apple Podcasts, Itália';

  @override
  String get podcastGenreAll => 'Todos';

  @override
  String get podcastSearchLens => 'Pesquisar podcasts';

  @override
  String get podcastSubscribedLabel => 'Subscrito';

  @override
  String get podcastOriginApple => 'Apple Podcasts';

  @override
  String get podcastChartError =>
      'A tabela não responde. Acontece, não é culpa tua.';

  @override
  String get podcastNoFeed => 'A Apple não tem feed para este podcast.';

  @override
  String get podcastGenreArts => 'Artes';

  @override
  String get podcastGenreBusiness => 'Negócios';

  @override
  String get podcastGenreComedy => 'Comédia';

  @override
  String get podcastGenreEducation => 'Educação';

  @override
  String get podcastGenreKids => 'Crianças e família';

  @override
  String get podcastGenreHealth => 'Saúde e fitness';

  @override
  String get podcastGenreTvFilm => 'TV e cinema';

  @override
  String get podcastGenreMusic => 'Música';

  @override
  String get podcastGenreNews => 'Notícias';

  @override
  String get podcastGenreReligion => 'Religião e espiritualidade';

  @override
  String get podcastGenreScience => 'Ciência';

  @override
  String get podcastGenreSports => 'Desporto';

  @override
  String get podcastGenreTechnology => 'Tecnologia';

  @override
  String get podcastGenreSociety => 'Sociedade e cultura';

  @override
  String get podcastGenreGovernment => 'Governo';

  @override
  String get podcastGenreHistory => 'História';

  @override
  String get podcastGenreTrueCrime => 'True crime';

  @override
  String podcastSubscribeTo(String name) {
    return 'Subscrever $name';
  }

  @override
  String get searchSimilarLooking => 'A procurar músicas semelhantes…';

  @override
  String searchSimilarQueued(String title) {
    return 'Fila: «$title» e músicas semelhantes';
  }

  @override
  String searchSimilarNone(String title) {
    return 'Sem músicas semelhantes: a tocar só «$title»';
  }

  @override
  String get searchSeeQueue => 'Ver fila';

  @override
  String queueSimilarTo(String title) {
    return 'Semelhantes a «$title»';
  }

  @override
  String get queueSimilarTag => 'rádio do YouTube Music';

  @override
  String queueSimilarCount(int total, int owned) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total músicas',
      one: '1 música',
    );
    return '$_temp0, $owned já na biblioteca';
  }

  @override
  String get queueSimilarSearching => 'A procurar músicas semelhantes…';
}
