# Refactor «invia-playlist-completa» — analisi

Tipo: `structure` (logica di condivisione LAN, con un ritocco ai messaggi). Data: 2026-11-28.

## Richiesta dell'utente
«Invia a un dispositivo» di una playlist manda solo i brani locali: deve mandarli **tutti**, altrimenti non ha senso.

È un **cambio di comportamento** voluto (regola 1 di `/refactor`): va nel file decisioni come tale. Va nella direzione
già decisa da D-674 («brani in streaming supportati ovunque: condivisione LAN, il brano arriva come salvato in streaming»),
che per le playlist non è mai stata applicata.

## Ambito
- Mittente: `lib/ui/screens/playlists/playlist_detail_screen.dart` (`_PlaylistAction.sendToDevice`),
  `lib/ui/screens/devices/devices_sheet.dart` (`_send`), `lib/providers/share_hub.dart` (`sendOffer`),
  `lib/providers/share_providers.dart` (`buildShareEntries`), `lib/services/share/offers.dart` (`offerPayload`, `maxOfferItems`).
- Ricevente: `lib/services/share/offers.dart` (`POST /` dell'offerta), `lib/providers/share_hub.dart` (`accept`),
  `lib/services/share/received_meta.dart` (`saveReceivedStreams`).
- Altri chiamanti di `DevicesSheet.show(trackIds:)`: `album_detail_screen.dart:383`, `track_actions.dart:461` (non filtrano).

Misure di base: non servono (nessun percorso caldo). Test esistenti: `test/services/share/offers_test.dart`,
`meta_travel_test.dart`, `received_meta_test.dart`, `offer_node_tls_test.dart`, `test/data/stream_rows_hidden_test.dart`,
`test/ui/incoming_offer_test.dart`. Nessun test sul menu della playlist né sul foglio Dispositivi.

## Risultati (per priorità)

F-01 · logica · La playlist toglie a priori tutti i brani in streaming · `playlist_detail_screen.dart:114`
(`trackIds: [for (final t in tracks) if (t.kind != kStreamKind) t.id]`) · dal 22/11 (D-665) ogni aggiunta crea brani in streaming,
quindi una playlist recente arriva quasi vuota; album e singolo brano invece li mandano (D-674) · impatto H · rischio L · costo S ·
passare tutti gli id e lasciare la scelta a `buildShareEntries`, come fanno gli altri chiamanti.

F-02 · logica · Le righe ombra (streaming non salvato) non partono mai · `share_providers.dart:95`
(`t.kind == kStreamKind && (!t.saved || …) → continue`) · una playlist può contenerle (D-524: pagina salvata come playlist,
`PlaylistRepository.addStreamTracks`); anche corretto F-01 sparirebbero in silenzio · impatto H · rischio M (sul ricevente
diventano brani «salvati in streaming»: compaiono in libreria) · costo S · farle viaggiare come `StreamOffer` quando la chiave è YouTube.

F-03 · UI · Nessun avviso sui brani scartati, e messaggio sbagliato quando non parte nulla · `devices_sheet.dart:96-98`,
`share_hub.dart:477-478` (`entries.isEmpty → false`) · con 40 brani di cui 10 scartati dice «Inviato a X»; con tutti scartati dice
«dispositivo non raggiungibile» (`shareErrUnreachable`), che è falso · impatto M · rischio L · costo S · dire quanti brani partono
e perché gli altri no; un messaggio proprio per «niente da inviare».

F-04 · protocollo · Arrivano i brani, non la playlist · `offers.dart:281-316` (`offerPayload`: solo `items` e `streams`,
nessun nome né ordine) · sul ricevente i brani finiscono sciolti in libreria (file nella cartella dei ricevuti, streaming come salvati):
chi riceve deve rifare la playlist a mano · impatto H · rischio M (input non fidato, compatibilità con versioni vecchie) · costo M ·
campo facoltativo `playlist` (nome + ordine dei brani), ignorato dalle versioni vecchie come già `streams`; il ricevente crea la playlist
dopo l'accettazione (streaming subito, file a fine download).

F-05 · protocollo · Oltre 500 brani l'offerta è rifiutata intera · `offers.dart:23` (`maxOfferItems = 500`), controllo a `offers.dart:386`
(`400 bad request`) · una playlist grande non parte e l'utente legge «non raggiungibile» · impatto M · rischio M · costo M ·
spezzare in più offerte da 500 (con F-04: stessa playlist, aggiunta in coda) oppure avvisare prima di inviare.

F-06 · limite reale · Non partono i brani con file mancante né lo streaming SoundCloud · `share_providers.dart:95`
(`t.missing`, `!streamKey.startsWith('youtube:')`) · SoundCloud non ha un indirizzo che il ricevente sappia riprodurre
(`stream_key.dart:27`, shortcut già annotato) · impatto L · rischio L · costo S · lasciare com'è, ma contarli nell'avviso di F-03.

## Riassunto
Il protocollo sa già trasportare lo streaming (D-674): il difetto segnalato è un filtro rimasto nella schermata della playlist (F-01),
più uno più profondo sulle righe ombra (F-02). Intorno ci sono due lacune che rendono «invia playlist» poco sensato anche corretto
il filtro: la playlist non arriva come playlist (F-04) e le grandi falliscono con un messaggio sbagliato (F-03, F-05).

## Scelte
Diagnosi confermata dall'utente. Affrontati tutti: F-01, F-03, F-06 (piccoli, inclusi d'ufficio), F-02, F-04, F-05 (scelte dell'utente).
Nessuno rinviato o scartato. Decisioni: le sei righe del 28/11 in `../../decisioni.md` dopo D-758 (invio di tutti i brani, playlist come
playlist, righe ombra, oltre 500, intoccabili, niente mockup).

Intoccabili: schema del DB (v24); limite di 500 elementi per offerta sul ricevente; sync delle playlist fra fidati; invio di album e singolo
brano (salvo il messaggio); compatibilità con le versioni vecchie in entrambe le direzioni; nessun pacchetto nuovo.

## Direzione
Prima → dopo:

| Parte | Oggi | Dopo |
|---|---|---|
| Menu della playlist | filtra via lo streaming | passa tutti gli id, più nome e ordine della playlist |
| `buildShareEntries` | scarta le righe ombra | con una playlist le fa viaggiare marcate (`shadow`); senza playlist come oggi |
| `sendOffer` | `bool` | un esito: inviati / scartati per motivo / niente da inviare / non raggiungibile |
| Offerta | `items` + `streams` | in più `playlist`: `{key, name, part, parts, order}`; `order` = lista di `{item: id}` o `{stream: key}` |
| Oltre 500 | 400 dal ricevente | parti da 500 con la stessa `key` |
| `accept` del ricevente | file + streaming salvati | in più, a fine ricezione, la playlist creata (o la parte aggiunta in coda) |

Percorso a piccoli passi, codice funzionante dopo ognuno: (1) caratterizzazione; (2) mittente: tutti gli id + esito e messaggi (nessun
cambio di protocollo); (3) campo `playlist` nell'offerta, letto e ignorato dal ricevente; (4) ricevente che crea la playlist e le righe ombra;
(5) parti oltre 500 e loro raggruppamento; (6) prova a due telefoni. Il campo `playlist` è facoltativo e tollerante come `streams`: un campo
rovinato si ignora, l'offerta resta valida.

Riuso: la risoluzione dei brani già presenti sul ricevente usa `PlaylistSyncRepository.resolver()` (già usato da `_offerWanted`);
le righe ombra `TrackRepository.ensureStreamRow` + `PlaylistRepository.addStreamTracks` (D-524; `deleteUnplayedStreamRows` già non tocca
le righe in una playlist). Architettura da aggiornare: `../../architettura/sync-backup-jam.md` (regola 6: le righe ombra di una playlist
ricevuta entrano da `ensureStreamRow`, non da `ingestStream`; campo `playlist` fra le stringhe di protocollo).

## Rete
Test di caratterizzazione prima di toccare il codice (fase 165.1): cosa passa oggi `buildShareEntries` (file, salvato YouTube, salvato SoundCloud,
riga ombra, file mancante); `offerPayload` e il parse del `POST /` di oggi (un'offerta senza `playlist` resta identica byte per byte nei campi
esistenti); il ricevente salva gli streaming come oggi; l'invio di un album e di un brano passa gli stessi id di oggi.

Metriche, ognuna col suo comando: `flutter analyze` pulito; test mirati verdi (comandi nelle fasi); nessun campo esistente dell'offerta cambia
(test di andata e ritorno di `offerPayload` senza playlist); prova a due telefoni (Mi A3 e Redmi, volume 0) con una playlist mista di file,
streaming salvati e righe ombra, e una da oltre 500 brani.

«Comportamento invariato» qui: invio di album e singolo brano, sync fra fidati, ricezione da e verso versioni vecchie, Jam: stessi test verdi.
