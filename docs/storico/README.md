# Storico della documentazione

Archivio di ciò che è chiuso. **Non si aggiorna più**; le fasi chiuse nuove si spostano qui (da `docs/fasi/` a `docs/storico/fasi/`, con `git mv`). La documentazione viva è in [`../00-INDICE.md`](../00-INDICE.md).

## Cosa c'è
| Percorso | Contenuto |
|---|---|
| `fasi/` | Un file per fase (127 file): obiettivo, task, verifiche, note di deviazione. Tabella sotto. |
| `feature/` | Specifiche di feature (requisiti R-…, rischi K-…) che hanno originato le fasi: streaming, arricchimento, riconoscimento, Jam a distanza, Jam della cassa, link e Shazam. |
| `refactor/` | Analisi, mockup, misure e rete di sicurezza dei refactor (`ui-fluida`, `superfici-e-ricerca`, …). |
| `superpowers/` | Piani e specifiche di lavoro di agenti (identità «anello» e simili). |
| `PROGRESS.md` | Registro globale dell'avanzamento fino alla fase 116, con le «Note di deviazione» e i «Pacchetti approvati». |
| `02-architettura.md`, `03-modello-dati.md` | Vecchia architettura e modello dati: sostituiti da [`../architettura/`](../architettura/00-panoramica.md). |
| `04-specifiche-da-python.md` | Specifiche della vecchia app Python da portare (portate). |
| `gotchas.md` | Trappole raccolte: ora stanno nelle sezioni «Trappole» dei documenti d'area. |
| `handoff.md`, `audit-ui-anello.md` | Passaggio di consegne e audit di un momento passato. |

## Come cercare
- Per una decisione: `docs/decisioni.md` (indice per area in cima), poi la fase citata qui sotto.
- Per un termine: `grep -ril "<termine>" docs/storico` (o `git log -S"<termine>" -- docs`); la storia dei file spostati si segue con `git log --follow <percorso>`.
- Una fase si trova per numero nella tabella; i riferimenti `D-xxx`, `R-xxx`, `F-xxx` rimandano al registro e alle specifiche in `feature/`.

## Fasi
| Fase | Titolo | File |
|---|---|---|
| 0 | Setup | [`fase-0-setup.md`](fasi/fase-0-setup.md) |
| 1 | Dati e scansione | [`fase-1-dati-e-scansione.md`](fasi/fase-1-dati-e-scansione.md) |
| 2 | Player | [`fase-2-player.md`](fasi/fase-2-player.md) |
| 3 | Interfaccia | [`fase-3-interfaccia.md`](fasi/fase-3-interfaccia.md) |
| 4 | Funzioni libreria | [`fase-4-funzioni-libreria.md`](fasi/fase-4-funzioni-libreria.md) |
| 5 | Online | [`fase-5-online.md`](fasi/fase-5-online.md) |
| 6 | Condivisione lan | [`fase-6-condivisione-lan.md`](fasi/fase-6-condivisione-lan.md) |
| 7 | Rifinitura | [`fase-7-rifinitura.md`](fasi/fase-7-rifinitura.md) |
| 8 | Jam | [`fase-8-jam.md`](fasi/fase-8-jam.md) |
| 9 | Jam multi | [`fase-9-jam-multi.md`](fasi/fase-9-jam-multi.md) |
| 10 | Jam sincronia | [`fase-10-jam-sincronia.md`](fasi/fase-10-jam-sincronia.md) |
| 11 | Interfaccia nuova | [`fase-11-interfaccia-nuova.md`](fasi/fase-11-interfaccia-nuova.md) |
| 12 | Import csv | [`fase-12-import-csv.md`](fasi/fase-12-import-csv.md) |
| 13 | Backup export | [`fase-13-backup-export.md`](fasi/fase-13-backup-export.md) |
| 14 | Download robusti | [`fase-14-download-robusti.md`](fasi/fase-14-download-robusti.md) |
| 15 | Importazione 2 | [`fase-15-importazione-2.md`](fasi/fase-15-importazione-2.md) |
| 16 | Ci test | [`fase-16-ci-test.md`](fasi/fase-16-ci-test.md) |
| 17 | Riproduzione | [`fase-17-riproduzione.md`](fasi/fase-17-riproduzione.md) |
| 18 | Gapless crossfade | [`fase-18-gapless-crossfade.md`](fasi/fase-18-gapless-crossfade.md) |
| 19 | Interfaccia | [`fase-19-interfaccia.md`](fasi/fase-19-interfaccia.md) |
| 20 | Libreria intelligente | [`fase-20-libreria-intelligente.md`](fasi/fase-20-libreria-intelligente.md) |
| 21 | Pulizia tag | [`fase-21-pulizia-tag.md`](fasi/fase-21-pulizia-tag.md) |
| 22 | Nuove fonti | [`fase-22-nuove-fonti.md`](fasi/fase-22-nuove-fonti.md) |
| 23 | Podcast | [`fase-23-podcast.md`](fasi/fase-23-podcast.md) |
| 24 | Dispositivi fidati | [`fase-24-dispositivi-fidati.md`](fasi/fase-24-dispositivi-fidati.md) |
| 25 | Android esteso | [`fase-25-android-esteso.md`](fasi/fase-25-android-esteso.md) |
| 26 | Distribuzione | [`fase-26-distribuzione.md`](fasi/fase-26-distribuzione.md) |
| 27 | Selezione ordinata e tema libero | [`fase-27-selezione-ordinata-e-tema-libero.md`](fasi/fase-27-selezione-ordinata-e-tema-libero.md) |
| 28 | Misure | [`fase-28-misure.md`](fasi/fase-28-misure.md) |
| 28 | Prestazioni e fluidita | [`fase-28-prestazioni-e-fluidita.md`](fasi/fase-28-prestazioni-e-fluidita.md) |
| 30 | Pagina artista | [`fase-30-pagina-artista.md`](fasi/fase-30-pagina-artista.md) |
| 31 | Shuffle plus | [`fase-31-shuffle-plus.md`](fasi/fase-31-shuffle-plus.md) |
| 32 | Ricerca intelligente | [`fase-32-ricerca-intelligente.md`](fasi/fase-32-ricerca-intelligente.md) |
| 33 | Radio | [`fase-33-radio.md`](fasi/fase-33-radio.md) |
| 34 | Nuove uscite | [`fase-34-nuove-uscite.md`](fasi/fase-34-nuove-uscite.md) |
| 35 | Secondo parere ytm | [`fase-35-secondo-parere-ytm.md`](fasi/fase-35-secondo-parere-ytm.md) |
| 36 | Deezer ed exportify | [`fase-36-deezer-ed-exportify.md`](fasi/fase-36-deezer-ed-exportify.md) |
| 37 | Metadati che viaggiano | [`fase-37-metadati-che-viaggiano.md`](fasi/fase-37-metadati-che-viaggiano.md) |
| 38 | Rete ui fluida | [`fase-38-rete-ui-fluida.md`](fasi/fase-38-rete-ui-fluida.md) |
| 39 | Fluidita | [`fase-39-fluidita.md`](fasi/fase-39-fluidita.md) |
| 40 | Accessibilita e token | [`fase-40-accessibilita-e-token.md`](fasi/fase-40-accessibilita-e-token.md) |
| 41 | Mattoni condivisi | [`fase-41-mattoni-condivisi.md`](fasi/fase-41-mattoni-condivisi.md) |
| 42 | Livelli e tipi | [`fase-42-livelli-e-tipi.md`](fasi/fase-42-livelli-e-tipi.md) |
| 43 | Nuovo aspetto | [`fase-43-nuovo-aspetto.md`](fasi/fase-43-nuovo-aspetto.md) |
| 44 | Chiusura ui fluida | [`fase-44-chiusura-ui-fluida.md`](fasi/fase-44-chiusura-ui-fluida.md) |
| 45 | Cache streaming | [`fase-45-cache-streaming.md`](fasi/fase-45-cache-streaming.md) |
| 46 | Streaming ricerca | [`fase-46-streaming-ricerca.md`](fasi/fase-46-streaming-ricerca.md) |
| 47 | Jam online | [`fase-47-jam-online.md`](fasi/fase-47-jam-online.md) |
| 48 | Shuffle tre stati | [`fase-48-shuffle-tre-stati.md`](fasi/fase-48-shuffle-tre-stati.md) |
| 49 | Artisti ospiti | [`fase-49-artisti-ospiti.md`](fasi/fase-49-artisti-ospiti.md) |
| 50 | Dati e fonti crediti | [`fase-50-dati-e-fonti-crediti.md`](fasi/fase-50-dati-e-fonti-crediti.md) |
| 51 | Crediti a schermo | [`fase-51-crediti-a-schermo.md`](fasi/fase-51-crediti-a-schermo.md) |
| 52 | Testo e curiosita | [`fase-52-testo-e-curiosita.md`](fasi/fase-52-testo-e-curiosita.md) |
| 53 | Completamento e registro | [`fase-53-completamento-e-registro.md`](fasi/fase-53-completamento-e-registro.md) |
| 54 | Copertina a mano | [`fase-54-copertina-a-mano.md`](fasi/fase-54-copertina-a-mano.md) |
| 55 | Misura streaming | [`fase-55-misura-streaming.md`](fasi/fase-55-misura-streaming.md) |
| 56 | Partenza da url | [`fase-56-partenza-da-url.md`](fasi/fase-56-partenza-da-url.md) |
| 57 | Coda e transizioni | [`fase-57-coda-e-transizioni.md`](fasi/fase-57-coda-e-transizioni.md) |
| 58 | Rete jam ricerca | [`fase-58-rete-jam-ricerca.md`](fasi/fase-58-rete-jam-ricerca.md) |
| 59 | Player e seek | [`fase-59-player-e-seek.md`](fasi/fase-59-player-e-seek.md) |
| 60 | Ricerca e dock | [`fase-60-ricerca-e-dock.md`](fasi/fase-60-ricerca-e-dock.md) |
| 61 | Fogli ovunque | [`fase-61-fogli-ovunque.md`](fasi/fase-61-fogli-ovunque.md) |
| 62 | Home aggiunti | [`fase-62-home-aggiunti.md`](fasi/fase-62-home-aggiunti.md) |
| 63 | Jam come player | [`fase-63-jam-come-player.md`](fasi/fase-63-jam-come-player.md) |
| 64 | Chiusura jam ricerca | [`fase-64-chiusura-jam-ricerca.md`](fasi/fase-64-chiusura-jam-ricerca.md) |
| 65 | Rilievi jam | [`fase-65-rilievi-jam.md`](fasi/fase-65-rilievi-jam.md) |
| 66 | Coda insieme | [`fase-66-coda-insieme.md`](fasi/fase-66-coda-insieme.md) |
| 67 | Jam della cassa | [`fase-67-jam-della-cassa.md`](fasi/fase-67-jam-della-cassa.md) |
| 68 | Scoperta e chiusura jam | [`fase-68-scoperta-e-chiusura-jam.md`](fasi/fase-68-scoperta-e-chiusura-jam.md) |
| 69 | Fondamenta jam distanza | [`fase-69-fondamenta-jam-distanza.md`](fasi/fase-69-fondamenta-jam-distanza.md) |
| 69a | Coda arricchimento | [`fase-69a-coda-arricchimento.md`](fasi/fase-69a-coda-arricchimento.md) |
| 69b | Arricchimento unico | [`fase-69b-arricchimento-unico.md`](fasi/fase-69b-arricchimento-unico.md) |
| 69c | Fondamenta riconoscimento | [`fase-69c-fondamenta-riconoscimento.md`](fasi/fase-69c-fondamenta-riconoscimento.md) |
| 69d | Cascata riconoscimento | [`fase-69d-cascata-riconoscimento.md`](fasi/fase-69d-cascata-riconoscimento.md) |
| 69e | Correzioni e cover | [`fase-69e-correzioni-e-cover.md`](fasi/fase-69e-correzioni-e-cover.md) |
| 70 | Ponte jam distanza | [`fase-70-ponte-jam-distanza.md`](fasi/fase-70-ponte-jam-distanza.md) |
| 71 | Coda remota | [`fase-71-coda-remota.md`](fasi/fase-71-coda-remota.md) |
| 72 | Bluetooth e amici | [`fase-72-bluetooth-e-amici.md`](fasi/fase-72-bluetooth-e-amici.md) |
| 73 | Chiusura jam distanza | [`fase-73-chiusura-jam-distanza.md`](fasi/fase-73-chiusura-jam-distanza.md) |
| 74 | Coda jam e rifinitura | [`fase-74-coda-jam-e-rifinitura.md`](fasi/fase-74-coda-jam-e-rifinitura.md) |
| 75 | Arricchimento stream | [`fase-75-arricchimento-stream.md`](fasi/fase-75-arricchimento-stream.md) |
| 76 | Suggeriti veloci | [`fase-76-suggeriti-veloci.md`](fasi/fase-76-suggeriti-veloci.md) |
| 77 | Rete e componenti | [`fase-77-rete-e-componenti.md`](fasi/fase-77-rete-e-componenti.md) |
| 78 | Home radio statistiche | [`fase-78-home-radio-statistiche.md`](fasi/fase-78-home-radio-statistiche.md) |
| 79 | Libreria e tutti i brani | [`fase-79-libreria-e-tutti-i-brani.md`](fasi/fase-79-libreria-e-tutti-i-brani.md) |
| 80 | Cerca online e generi | [`fase-80-cerca-online-e-generi.md`](fasi/fase-80-cerca-online-e-generi.md) |
| 81 | Player e streaming | [`fase-81-player-e-streaming.md`](fasi/fase-81-player-e-streaming.md) |
| 82 | Registro e revisione | [`fase-82-registro-e-revisione.md`](fasi/fase-82-registro-e-revisione.md) |
| 83 | Chiusura uso quotidiano | [`fase-83-chiusura-uso-quotidiano.md`](fasi/fase-83-chiusura-uso-quotidiano.md) |
| 84 | Broker e debito jam | [`fase-84-broker-e-debito-jam.md`](fasi/fase-84-broker-e-debito-jam.md) |
| 85 | Debito review 83 | [`fase-85-debito-review-83.md`](fasi/fase-85-debito-review-83.md) |
| 86 | Jam media | [`fase-86-jam-media.md`](fasi/fase-86-jam-media.md) |
| 87 | Rete superfici | [`fase-87-rete-superfici.md`](fasi/fase-87-rete-superfici.md) |
| 88 | Ritocchi rapidi | [`fase-88-ritocchi-rapidi.md`](fasi/fase-88-ritocchi-rapidi.md) |
| 89 | Dock e sezioni | [`fase-89-dock-e-sezioni.md`](fasi/fase-89-dock-e-sezioni.md) |
| 90 | Intestazioni che scorrono | [`fase-90-intestazioni-che-scorrono.md`](fasi/fase-90-intestazioni-che-scorrono.md) |
| 91 | Ordinamenti e playlist | [`fase-91-ordinamenti-e-playlist.md`](fasi/fase-91-ordinamenti-e-playlist.md) |
| 92 | Cerca libreria e artisti | [`fase-92-cerca-libreria-e-artisti.md`](fasi/fase-92-cerca-libreria-e-artisti.md) |
| 93 | Dati per i filtri | [`fase-93-dati-per-i-filtri.md`](fasi/fase-93-dati-per-i-filtri.md) |
| 94 | Playlist intelligenti | [`fase-94-playlist-intelligenti.md`](fasi/fase-94-playlist-intelligenti.md) |
| 95 | Artisti uniti | [`fase-95-artisti-uniti.md`](fasi/fase-95-artisti-uniti.md) |
| 96 | Podcast scopri | [`fase-96-podcast-scopri.md`](fasi/fase-96-podcast-scopri.md) |
| 97 | Chiusura superfici | [`fase-97-chiusura-superfici.md`](fasi/fase-97-chiusura-superfici.md) |
| 98 | Rete ascolto | [`fase-98-rete-ascolto.md`](fasi/fase-98-rete-ascolto.md) |
| 99 | Debito artisti | [`fase-99-debito-artisti.md`](fasi/fase-99-debito-artisti.md) |
| 100 | Coda simili artista | [`fase-100-coda-simili-artista.md`](fasi/fase-100-coda-simili-artista.md) |
| 101 | Non mi piace | [`fase-101-non-mi-piace.md`](fasi/fase-101-non-mi-piace.md) |
| 102 | Podcast senza iscrizione | [`fase-102-podcast-senza-iscrizione.md`](fasi/fase-102-podcast-senza-iscrizione.md) |
| 103 | Testi e memoria | [`fase-103-testi-e-memoria.md`](fasi/fase-103-testi-e-memoria.md) |
| 104 | Daylist | [`fase-104-daylist.md`](fasi/fase-104-daylist.md) |
| 105 | Chiusura ascolto | [`fase-105-chiusura-ascolto.md`](fasi/fase-105-chiusura-ascolto.md) |
| 106 | Testi traslitterati | [`fase-106-testi-traslitterati.md`](fasi/fase-106-testi-traslitterati.md) |
| 107 | Rete coda libreria | [`fase-107-rete-coda-libreria.md`](fasi/fase-107-rete-coda-libreria.md) |
| 108 | Coda blocco utente | [`fase-108-coda-blocco-utente.md`](fasi/fase-108-coda-blocco-utente.md) |
| 109 | Titoli che scorrono | [`fase-109-titoli-che-scorrono.md`](fasi/fase-109-titoli-che-scorrono.md) |
| 110 | Libreria e playlist | [`fase-110-libreria-e-playlist.md`](fasi/fase-110-libreria-e-playlist.md) |
| 111 | Pausa volume zero | [`fase-111-pausa-volume-zero.md`](fasi/fase-111-pausa-volume-zero.md) |
| 112 | Link in cerca | [`fase-112-link-in-cerca.md`](fasi/fase-112-link-in-cerca.md) |
| 113 | Chiusura coda libreria | [`fase-113-chiusura-coda-libreria.md`](fasi/fase-113-chiusura-coda-libreria.md) |
| 114 | Link spotify deezer | [`fase-114-link-spotify-deezer.md`](fasi/fase-114-link-spotify-deezer.md) |
| 115 | Salva e condividi | [`fase-115-salva-e-condividi.md`](fasi/fase-115-salva-e-condividi.md) |
| 116 | Brani da shazam | [`fase-116-brani-da-shazam.md`](fasi/fase-116-brani-da-shazam.md) |
| 117 | Ripristino completo | [`fase-117-ripristino-completo.md`](fasi/fase-117-ripristino-completo.md) |
| 118 | Guardrail e correzioni | [`fase-118-guardrail-e-correzioni.md`](fasi/fase-118-guardrail-e-correzioni.md) |
| 119 | Ritocchi e 1.6.0 | [`fase-119-ritocchi-e-1-6-0.md`](fasi/fase-119-ritocchi-e-1-6-0.md) |
| 120 | CI Windows | [`fase-120-ci-windows.md`](fasi/fase-120-ci-windows.md) |
| 121 | Test di sistema | [`fase-121-test-di-sistema.md`](fasi/fase-121-test-di-sistema.md) |
| 122 | CI di tutti i sistemi | [`fase-122-ci-tutti-i-sistemi.md`](fasi/fase-122-ci-tutti-i-sistemi.md) |
