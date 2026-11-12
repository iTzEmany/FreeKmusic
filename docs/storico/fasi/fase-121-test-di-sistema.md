# Fase 121 — Test di sistema completo (build release)

## Obiettivo
Provare l'app da cima a fondo con le **build release** (APK arm64 e bundle Linux), come la usa una persona, e correggere ciò che si rompe. Solo release, perché problemi come quello di R8 della 1.5.1 con le build debug non si vedono (richiesta dell'utente, 11/11).

## Riferimenti
D-568 (ordine del lavoro notturno). Documenti d'area: `../architettura/online.md`, `../architettura/riproduzione-e-coda.md`, `../architettura/piattaforme.md`.

## Requisiti
| ID | Requisito | Verifica |
|---|---|---|
| R-239 | Nessun bug di gravità alta o media resta aperto dopo il test di sistema release su Linux e Android; ognuno ha il suo test di regressione | test mirati dei bug sotto, verdi |

## Come è andata
- **Linux** (Xvfb, HOME finta, dbus privato, audio verso un sink nullo, yt-dlp scaricato dall'app):
  - onboarding, libreria, riproduzione, MPRIS, online, download con tag, arricchimento, Registro, playlist e smart, radio, podcast, temi, backup e «Unisci» due volte (niente doppioni), chiusura durante un download.
- **Mi A3** (APK release): gli stessi flussi più notifica e lockscreen, rotazione, rete che cade, force-stop, Jam come host.
  - Nessun crash né ANR.
- **Redmi: non provato.** MIUI rifiuta `adb install` (INSTALL_FAILED_USER_RESTRICTED: chiede la password di «Installa via USB»). Restano da provare:
  - Jam a due telefoni;
  - «Unisci» su un secondo telefono.

## Bug trovati e corretti
| Gravità | Bug | Correzione |
|---|---|---|
| alta | Il controllo del portale dei file usava `gdbus introspect --timeout`, un'opzione che non esiste: dava sempre «manca il portale» e l'import CSV era bloccato (nato nella fase 118) | `gdbus` senza `--timeout`; il limite di 3 s è lato Dart e il processo viene terminato |
| media | I tag di un download finito poco prima di una chiusura dell'app non venivano mai scritti | `PendingTags`: elenco persistente (`pending-tags.json`, scrittura atomica e in serie) ripreso una volta all'avvio |
| media | Un caricamento interrotto da un altro brano risultava un errore: voce nel Registro e salto | Ignorato solo se il caricamento è superato (token vecchio); un errore sul caricamento corrente segue sempre il percorso normale |
| media | Lo streaming senza rete restava in «Caricamento» per circa 1,5 minuti senza messaggio | Dopo un errore di rete un controllo DNS decide «offline»: fallisce subito con il messaggio, senza ritentare |
| bassa | Un download promosso dalla cache dello streaming non compariva nel Registro | Stream `promoted` di `DownloadsNotifier` ascoltato dal Registro |
| bassa | Permesso audio negato nella guida e dato dopo: la libreria restava vuota fino a «Riscansiona ora» | Su Android, se l'ultima scansione mancava del permesso (pref), all'avvio o al ritorno si riscansiona |
| bassa | Artista preso dal canale («Queen Music videos») e «(official music video)» pulito a metà | `query_cleaner` toglie i suffissi del canale e le varianti di «official video», senza svuotare un titolo |
| bassa | Titolo «Libreria» troncato quando compare il chip delle attività | Il titolo si rimpicciolisce (`FittedBox`) |

## Task
- [x] 121.1 Test di sistema release (Linux, Mi A3) e correzioni (R-239)

## Note di deviazione
- Non corretti, con il motivo:
  - sul desktop col mouse lo swipe per la coda non parte, perché vince il trascinamento verso le playlist della barra laterale (voluto: lo swipe è un gesto touch);
  - Home «Playlist: 1» con una playlist smart in più: la scheda conta e apre solo le playlist normali, quindi è coerente;
  - controlli sotto il dock: il padding c'è già (`withDock`, test `dock_bottom_padding_test`);
  - «primo tocco perso» nelle Impostazioni: causa non trovata, probabile tocco durante l'animazione di entrata;
  - «Dispositivi vicini» mostra il proprio IP: è la vecchia app Codecore installata sullo stesso telefono;
  - log `CanceledException` del canale yt-dlp al cambio brano: rumore, non è un errore per l'utente;
  - un force-stop durante un download non lascia traccia nel Registro: non si perde niente.
- Le review (sonnet, effort alto) hanno portato a un secondo giro di correzioni (commit `bc9f65cd`).

## Tocca a te
- Redmi:
  1. Attiva «Installa via USB» nelle opzioni sviluppatore (chiede la password dell'account Mi), oppure installa a mano `app-release.apk` dal file manager.
  2. Poi chiedimi la prova Jam a due telefoni e «Unisci» con un backup del Mi A3.
