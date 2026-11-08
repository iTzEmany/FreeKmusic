# Fase 106 — Testi traslitterati (refactor «testi-traslitterati»)

**Obiettivo:** sotto ogni riga di un testo giapponese, cinese o coreano, la stessa riga in alfabeto latino. **Funzione nuova** (D-456..D-462).

**Prerequisiti:** fase 103 chiusa (editor e menu del testo). Analisi: `refactor/testi-traslitterati/analisi.md` (F-123..F-128, «Arrivo», «Rete»). Mockup approvato: `refactor/testi-traslitterati/mockup/testo-traslitterato.html`. Aree a rischio: nessuna (niente schema, backup o coda). Nessun pacchetto nuovo.

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

### 106.5 — Controlli di fase
`flutter analyze`; comando mirato; `git diff origin/master -- pubspec.yaml` vuoto; review del diff (Sonnet); scheggia passo e fase; prova sul Mi A3 via adb contro il mockup (un brano giapponese con `romalrc`, uno coreano, uno cinese senza traslitterazione, interruttore spento = schermata di oggi) e su Linux nello schermo virtuale (pannello laterale). Ripulire il telefono.

**Fatto quando:** i tre casi del mockup funzionano sul telefono, con l'interruttore spento nulla cambia, nessun pacchetto nuovo.

## Scelte dell'utente (8/11, dopo la fase 99)
- **D-475** (106.2, 106.4): accesa di serie per i testi CJK; sotto metà delle righe abbinate «Traslitterazione non disponibile»; sui testi scritti a mano solo il coreano calcolato; «Modifica traslitterazione» nel menu, che vince su quella trovata e va nel backup come i testi a mano. È un task in più: va aggiunto al piano della fase prima di cominciarla.

## Esiti
