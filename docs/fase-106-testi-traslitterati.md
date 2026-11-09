# Fase 106 — Testi traslitterati (refactor «testi-traslitterati»)

**Obiettivo:** sotto ogni riga di un testo giapponese, cinese o coreano, la stessa riga in alfabeto latino. **Funzione nuova** (D-456..D-462).

**Prerequisiti:** fase 103 chiusa (editor e menu del testo). Analisi: `refactor/testi-traslitterati/analisi.md` (F-123..F-128, «Arrivo», «Rete»). Mockup approvato: `refactor/testi-traslitterati/mockup/testo-traslitterato.html`. Aree a rischio: backup (traslitterazione a mano e segno «scritto a mano» in `settings.json`, D-475), niente schema né coda. Nessun pacchetto nuovo.

**Comando mirato:** `flutter test test/services/lyrics/ test/services/online/netease_lyrics_client_test.dart test/services/online/lyrics_chain_test.dart test/ui/lyrics_view_test.dart`

## Task

### 106.1 — Scrittura e coreano (logica pura)
- `lib/services/lyrics/script_detect.dart`: `hasCjk`, lingua prevalente (kana → giapponese, hangul → coreano, solo hanzi → cinese).
- `lib/services/lyrics/hangul_romanizer.dart`: romanizzazione riveduta per decomposizione Unicode (U+AC00–U+D7A3) con legamento e assimilazioni comuni (D-460); caratteri non hangul invariati.
- Test: tabella dell'analisi «Rete» (안녕하세요, 국물, 신라, 같이, 좋아) e testo misto.

### 106.2 — `romalrc` di NetEase (F-124)
- `NeteaseLyricsClient`: query con `rv=-1`, legge `romalrc.lyric` oltre a `lrc.lyric`; metodo per chiedere solo la traslitterazione di un brano (ricerca, poi lyric). `LyricsChain` restituisce gli stessi `plain`/`synced` di oggi (test esistenti verdi senza modifiche).
- Parser LRC tollerante a `mm:ss:xx`; abbinamento delle righe per tempo più vicino (±1,5 s), poi per indice a parità di righe; i crediti `[by:…]` si scartano.
- Test con risposte finte (con e senza `romalrc`, tempi sfasati di 70 ms, righe mancanti).

### 106.3 — Cache e provider (D-458)
- `romanization_cache.dart`: JSON nella cartella dati, fuori dal backup; «nessuna» ritentata dopo 30 giorni. `romanizationProvider.family(trackId)`: coreano → calcolata; altrimenti cache → NetEase (stesse regole di rete dei testi) → non disponibile. Niente I/O sul thread UI.
- Test della cache e del provider (coreano senza rete; giapponese da cache; non disponibile).

### 106.4 — Vista e menu (F-123, F-126, D-459, D-461)
- `_LyricRow`: riga `romanization` fra originale e traduzione, stile e sfumature del mockup. Ramo non sincronizzato: coppie riga/traslitterazione quando è attiva, `SelectableText` di oggi quando è spenta. Avviso «Traslitterazione non disponibile per questo testo» come nel mockup.
- Menu del testo: interruttore «Traslitterazione» (impostazione unica in `SettingsStore`), visibile solo se `hasCjk`. Pannello laterale desktop incluso (riusa `LyricsScreen`); card del player esclusa (F-127). Stringhe ARB it/en/de/es, etichette TalkBack.
- Widget test `test/ui/lyrics_view_test.dart`: traslitterazione + traduzione insieme; ramo non sincronizzato a coppie; interruttore assente su un testo senza CJK.

### 106.5 — Cinese con il dizionario scaricato (D-476)
- `lib/services/lyrics/pinyin_dictionary.dart`: legge CC-CEDICT (`.txt.gz`, gzip di `dart:io`) in una mappa parola → pinyin con i toni, in un isolate; ricerca della parola più lunga sulla riga (fino a 8 caratteri), carattere singolo come ripiego, caratteri sconosciuti lasciati come sono.
- Download alla prima richiesta (testo cinese senza `romalrc`), con `dio`, dalla copia nelle release del repo GitHub (da caricare con `gh release` all'inizio della fase, dopo conferma dell'utente); stesse regole di rete dell'arricchimento dei testi; mentre scarica «Scarico il dizionario cinese…», se fallisce «Traslitterazione non disponibile» e si riprova alla prossima apertura.
- Impostazioni, accanto ai modelli di traduzione (`translation_models_tiles.dart`): «Dizionario cinese» con dimensione ed «Elimina». Informazioni dell'app: citazione di CC-CEDICT (CC BY-SA 4.0).
- `romanizationProvider`: coreano → calcolata; poi cache → NetEase; poi, per il cinese, il dizionario.
- Test: tabella (银行 → yínháng, 音乐 → yīnyuè, 我爱你 → wǒ ài nǐ, carattere ignoto), file gzip finto, download fallito → «non disponibile».

### 106.6 — Traslitterazione scritta a mano (D-475)
- «Modifica traslitterazione» nel menu del testo, come «Modifica testo» della 103 (una riga per riga del testo); vince su quella trovata; «Elimina» la toglie. Salvata come i testi a mano e nel backup (solo aggiunte al formato, test del backup verde con un campo in più).
- Test: salva/rilegge, vince su NetEase, backup con e senza il campo.

### 106.7 — Controlli di fase
`flutter analyze`; comando mirato; `git diff origin/master -- pubspec.yaml` vuoto; review del diff (Sonnet); scheggia passo e fase; prova sul Mi A3 via adb contro il mockup (un brano giapponese con `romalrc`, uno coreano, uno cinese senza traslitterazione, interruttore spento = schermata di oggi) e su Linux nello schermo virtuale (pannello laterale). Ripulire il telefono.

**Fatto quando:** i tre casi del mockup funzionano sul telefono, il cinese senza `romalrc` ha il pinyin dal dizionario, la traslitterazione si scrive a mano, con l'interruttore spento nulla cambia, nessun pacchetto nuovo.

## Scelte dell'utente (8/11, dopo la fase 99)
- **D-475** (106.2, 106.4): accesa di serie per i testi CJK; sotto metà delle righe abbinate «Traslitterazione non disponibile»; sui testi scritti a mano solo il coreano calcolato; «Modifica traslitterazione» nel menu, che vince su quella trovata e va nel backup come i testi a mano. Task 106.6.
- **D-476**: cinese senza `romalrc` dal dizionario CC-CEDICT scaricato alla prima richiesta (task 106.5).

## Esiti
- 106.1–106.3 (2026-11-09):
  - Servizi puri in `lib/services/lyrics/`: `script_detect`, `hangul_romanizer`, `romanization_match`, `romanization_cache`, `romanization_resolver`, `lyrics_shown`.
  - `NeteaseLyricsClient.romanized` (`rv=-1`). `LyricsChain` è invariata.
  - `romanizationProvider(id)` con chiave a record: una chiave nuova fa un giro nuovo, mai righe vecchie.
- 106.4: righe traslitterate fra originale e traduzione. Un testo non sincronizzato si mostra a coppie; avvisi «non disponibile» e «Scarico il dizionario cinese…». Interruttore e «Modifica/Elimina traslitterazione» nel menu, solo con CJK; anche nel pannello laterale.
- 106.5: `pinyin_dictionary` (CC-CEDICT in un isolate, 198 mila voci in meno di 1 s; preferisce la lettura comune a quella del cognome) e `cedict_download` (release `data-cedict-2026-11-08`, controllo sha256).
  - Download automatico solo con `autoLyrics`. Dopo un errore si ritenta con una pausa crescente da 5 minuti a 1 ora.
  - Tile «Dizionario cinese» nelle Impostazioni; citazione CC BY-SA 4.0 nelle Informazioni, con i link come testo (niente `url_launcher`).
- 106.6: la traslitterazione scritta a mano si abbina per indice alle righe mostrate. Il segno `handWrittenLyrics` lo mette solo l'editor del testo (D-482); un testo scelto con Cerca riceve NetEase come gli altri. Entrambi viaggiano nel backup: la sostituzione totale li rimette, l'unione li aggiunge solo con lo stesso testo.
- 106.7: `flutter analyze` pulito, test mirati verdi.
  - Review Opus della parte dati (10 rilievi) e della fase (1 bug, 8 voci di debito), review Sonnet della UI (6 rilievi), scheggia di passo (5 bug, test rinforzati sui mutanti sopravvissuti): tutto corretto con i test, il debito è in `prossimi-lavori.md`.
  - Scheggia di fase sul Mi A3 e su Linux: i tre casi del mockup vanno; monkey di 1200 eventi senza crash. Corretti dopo la prova: pinyin con la maiuscola del cognome, download automatico mai ritentato, editor coperti dalla tastiera, modifiche scartate senza conferma.
  - Non provato: il download vero del dizionario sul telefono, perché il Wi-Fi si bloccava a ~400 KB e il file è stato copiato via adb; su Linux il download vero è riuscito.
