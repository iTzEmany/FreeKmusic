# Refactor «testi-traslitterati» — analisi

Avvio 2026-11-08. Tipo: **tutto** (funzione nuova chiesta dall'utente: sotto ogni riga di un testo giapponese, cinese o coreano la stessa riga in alfabeto latino). Cambio di comportamento voluto.

## Perimetro
`lib/services/online/` (catena dei testi, NetEase), `lib/ui/screens/lyrics/` (vista e schermata del testo, pannello laterale desktop che la riusa), servizio nuovo di traslitterazione. Fuori: card del testo nel player (5 righe fisse), Jam, widget Android.

## Misure di partenza
- Nessun codice di riconoscimento della scrittura o di traslitterazione in `lib` (grep su intervalli CJK, kana, hangul, pinyin, romaji: zero).
- Unica dipendenza linguistica: `google_mlkit_translation` (traduzione, solo Android).

## Rilievi in ordine di priorità
- **F-123** · testi · Nessuna traslitterazione · `lib/ui/screens/lyrics/lyrics_view.dart:226-296` (`_LyricRow`) · la riga ha già una seconda riga opzionale per la traduzione (`translation`, `titleMedium`, `textMuted`), abbinata per indice con `lyricsLinesOf` (`lyrics_translate_flow.dart:15-28`) · chi ascolta musica asiatica non può leggere il testo · A · B · S · terza riga opzionale `romanization` nella stessa colonna; lo scorrimento non si rompe (`_reveal` usa `ensureVisible`, righe ad altezza variabile già oggi, `lyrics_view.dart:67-100`).
- **F-124** · fonti · NetEase ha la traslitterazione ma non la chiediamo · `netease_lyrics_client.dart:41-43,70-76`: query `{'id', 'lv': '1'}`, legge solo `lrc.lyric` · prova dal vivo (8/11): con `rv=-1` la risposta ha `romalrc` (LRC con tempi propri, es. originale `[00:11:95]` e romaji `[00:12.025]`); coperta a macchia (giapponese spesso, cinese spesso vuoto, cantonese in jyutping, coreano non provato), endpoint non ufficiale · si perde una fonte gratuita · A · M · S · chiedere `rv=-1`, leggere `romalrc`, abbinare le righe per tempo più vicino (non uguaglianza), parser tollerante a `mm:ss:xx`.
- **F-125** · fonti · Traslitterazione offline: costi diversi per lingua · coreano: algoritmo noto (decomposizione Unicode U+AC00–U+D7A3, 19 iniziali × 21 vocali × 28 finali + tabelle della romanizzazione riveduta), ~40 righe senza pacchetti, regole di pronuncia fra sillabe a parte; cinese: serve un dizionario carattere → pinyin (pacchetto `pinyin` 3.3.0, BSD-2, Dart puro, ~2 anni fa; `lpinyin` 2.0.3 fermo da ~5 anni); giapponese: i kana si fanno con tabelle (o `kana_kit` 2.1.1, MIT), i **kanji** richiedono un analizzatore con dizionario (`kuromoji` 1.0.5: 376 download, consegna del dizionario non verificata; `romanize` 0.0.3: avvio «costoso»; `mecab_for_dart`: nativo) · pacchetti nuovi = scelta dell'utente (CLAUDE.md) · A · M · M–L · coreano in casa; cinese e kanji solo se l'utente approva un pacchetto.
- **F-126** · UI · Il testo non sincronizzato è un unico `SelectableText` · `lyrics_view.dart:172-195` (la traduzione va sotto un divisore, non riga per riga) · la traslitterazione «sotto ogni riga» non ci sta · M · B · S · colonna di coppie riga/traslitterazione quando è attiva, `SelectableText` com'è oggi quando è spenta.
- **F-127** · UI · La card del testo nel player ha 5 righe fisse · `now_playing_cards.dart:67-160` (altezza = `_lyricsRowHeight*5`, `maxLines: 1`, D-161) · una seconda riga romperebbe l'altezza · B · B · S · lasciarla fuori (solo schermata del testo e pannello laterale).
- **F-128** · piano · Stessi file della fase 103 · `docs/fase-103-testi-e-memoria.md`: editor del testo e interruttore «Testo sincronizzato» nel menu di `lyrics_screen.dart` e nel ramo iniziale di `LyricsView.build` · conflitti se fatte insieme · M · M · S · fase nuova dopo la 103, con l'interruttore nello stesso menu.

## Sintesi
La parte di interfaccia è piccola perché lo spazio per una seconda riga c'è già. Il nodo sono le fonti: NetEase gratis ma a macchia, coreano facile in casa, cinese con un pacchetto leggero, kanji giapponesi difficili offline.

## Scelte (giro 2, 2026-11-08)
Tutti i rilievi affrontati (D-456). Fonte: `romalrc` di NetEase + coreano in casa, nessun pacchetto (D-457). Cache a parte, fuori dal backup, schema invariato (D-458). Interruttore unico nel menu, solo con caratteri CJK (D-459). Coreano con le regole di pronuncia principali (D-460). Schermata del testo e pannello laterale, non la card del player (D-461). Fase 106 dopo la 103 (D-462).
**Intoccabili:** schema DB, formato del backup, pacchetti, card del testo nel player, traduzione esistente (resta com'è, sotto la traslitterazione), catena dei testi (stesso ordine delle fonti e stesso risultato per `plain`/`synced`).

## Arrivo (giro 3, 2026-11-08)
| Oggi | Arrivo |
|---|---|
| NetEase chiede solo `lv=1` | `NeteaseLyricsClient` chiede anche `rv=-1` e restituisce `romalrc` accanto a `lrc`; un metodo `romanized(track)` per chiederla anche quando il testo viene da LRCLIB (ricerca del brano su NetEase, poi solo `romalrc`) |
| — | `lib/services/lyrics/script_detect.dart`: `hasCjk(String)` e lingua prevalente (kana → giapponese, hangul → coreano, solo hanzi → cinese) |
| — | `lib/services/lyrics/hangul_romanizer.dart`: romanizzazione riveduta con legamento e assimilazioni comuni (puro, senza pacchetti) |
| — | `lib/services/lyrics/romanization_cache.dart`: file JSON nella cartella dati (id brano → LRC traslitterato o «nessuna» con data), fuori dal backup; voce «nessuna» ritentata dopo 30 giorni |
| — | `romanizationProvider.family(trackId)`: coreano → calcolata; altrimenti cache → NetEase (solo con le regole di rete dell'arricchimento dei testi) → «non disponibile». Abbinamento delle righe per tempo più vicino (tolleranza ±1,5 s), poi per indice se le righe sono uguali in numero; parser LRC tollerante a `mm:ss:xx` |
| `_LyricRow` con `translation` | in più `romanization` fra originale e traduzione (mockup); ramo non sincronizzato a coppie riga/traslitterazione quando è attiva |
| menu del testo (103) | voce «Traslitterazione» (interruttore in `SettingsStore`, `shared_preferences`), visibile solo se `hasCjk` |

## Rete (giro 4, 2026-11-08)
**Comportamento invariato:** con l'interruttore spento la schermata del testo è identica; `lyrics_chain` restituisce gli stessi `plain`/`synced` di oggi (test esistenti verdi senza modifiche).
Test: unità per `hasCjk`/lingua, `hangul_romanizer` (tabella: 안녕하세요 → annyeonghaseyo, 국물 → gungmul, 신라 → silla, 같이 → gachi, 좋아 → joa), parser LRC tollerante, abbinamento per tempo (scarto di 70 ms, righe mancanti), `romanization_cache` (scrittura, «nessuna» ritentata dopo 30 giorni), client NetEase con risposta finta (con e senza `romalrc`); widget test di `_LyricRow` con traslitterazione e traduzione insieme e del ramo non sincronizzato a coppie.
**Metriche:** `flutter analyze` pulito; nessun pacchetto nuovo (`git diff origin/master -- pubspec.yaml` vuoto); `kSchemaVersion` invariato; `grep -rn "romalrc" lib` solo nel client NetEase.
