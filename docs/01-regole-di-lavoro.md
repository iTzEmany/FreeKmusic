# Regole di lavoro (obbligatorie)

Scritte per un agente che lavora a task piccoli e precisi. Seguile alla lettera.

## 1. Metodo
1. Lavora **un task per volta**, nell'ordine del documento di fase.
2. Prima di scrivere codice, leggi i file che stai per modificare (se esistono).
3. Fai solo ciò che il task chiede. Niente refactoring "già che ci sono", niente funzioni extra.
4. A fine task esegui, in questo ordine:
   `dart run build_runner build --delete-conflicting-outputs` (solo se toccate tabelle drift) →
   `flutter analyze` → i test mirati del cambiamento (`flutter test <file…>`). Devono essere puliti.
   La suite completa (`flutter test`) la esegue la CI.
5. Spunta il task nel file della fase (`docs/fasi/fase-N-*.md`) e scrivi **una riga** di nota se hai deviato dal piano.
6. Se un criterio di verifica non è raggiungibile, **fermati e riportalo**: non aggirarlo.

## 2. Quando fermarti e chiedere all'utente
- Serve `sudo`, installare software di sistema, un telefono fisico, o accettare licenze Android.
- Un pacchetto non esiste / ha API diversa da quella descritta e non trovi un'alternativa ovvia.
- Una scelta cambierebbe lo stack o lo schema DB già definito.
- Un test o `flutter analyze` continua a fallire dopo 2 tentativi diversi.

## 3. Pacchetti e API
- Aggiungi pacchetti solo con `flutter pub add <nome>` (così la versione è compatibile). Solo quelli elencati nella fase.
- Non ricordare le API a memoria: se un nome di metodo/campo del pacchetto non compila, apri il
  sorgente in `~/.pub-cache/hosted/pub.dev/<pacchetto>-<versione>/lib` e usa quello vero.
- Ogni pacchetto "fragile" sta dietro un'interfaccia nostra (es. `TagReader`, `AudioBackend`),
  così si sostituisce senza toccare il resto.

## 4. Stile del codice
- Dart idiomatico, `flutter_lints` attivo, nessun warning ignorato.
- File ≤ ~300 righe. Widget piccoli (≤ ~120 righe di `build`); estrai sotto-widget con nome.
- Classi immutabili dove possibile (`final`, `const`).
- Nomi in inglese; testi visibili all'utente **sempre** da ARB (dalla fase 4) — prima della fase 4 in un file `lib/ui/strings_it.dart`.
- Commenti: solo il "perché", mai il "cosa". Niente blocchi commentati.
- Niente `print`. Usa `AppLog.d/i/w/e` (definito in `lib/core/app_log.dart`, fase 0).

## 5. Errori e asincronia
- Mai `catch (_) {}` vuoto. Cattura l'eccezione, `AppLog.e(...)`, e restituisci/mostra un errore utile.
- Operazioni di I/O o CPU lunghe (scansione, lettura tag di molti file, hash) in un
  `Isolate.run` / `compute`. Il thread UI fa solo UI.
- In un `State`: dopo ogni `await` controlla `if (!mounted) return;` prima di usare `context`.
- Cancella `StreamSubscription`, `Timer`, `TextEditingController`, `ScrollController` in `dispose`.
- Nessuna rete senza timeout (`dio`: connect 8 s, receive 15 s) e senza `User-Agent` proprio.

## 6. Stato e dati
- Stato con Riverpod, provider scritti a mano (niente code-generation Riverpod).
- La **coda di riproduzione è separata dalla lista visualizzata**: la UI passa uno *snapshot*
  della lista al player; cambiare filtro/ordinamento non tocca la coda.
- La UI non parla mai direttamente con SQLite né con il pacchetto audio: solo via repository / `PlayerController`.
- Il DB è la fonte di verità per le modifiche dell'utente (titolo, preferiti, testi). I tag nei file si
  scrivono **solo** con l'opzione `writeTagsToFiles` (spenta di default), attraverso `SafeTagWriter`
  (copia, verifica, backup, `rename` atomico), mai direttamente dal `TagWriter`.
- Non si cancellano mai righe utente (preferiti/playlist/testi) automaticamente: file assenti → `missing = true`.

## 7. Test (obbligatori per la logica pura)
Scrivi test unitari per: pulizia query, scoring iTunes, parser LRC, sanitize filename, `PlayQueue`,
chiave album, logica della scansione (con `TagReader` finto e cartella temporanea), repository (DB in memoria).
La UI non ha test obbligatori: basta `flutter analyze` + avvio manuale descritto nella verifica.

## 8. Prestazioni (non negoziabili)
- Liste lunghe: `ListView.builder` / `SliverList` con `itemExtent` fisso. Mai `Column` con N figli.
- Copertine: `Image.file(..., cacheWidth: <px logici × devicePixelRatio>)`; mai decodificare a piena risoluzione.
- Ricerca: debounce 250 ms, query SQL (non filtrare 5000 elementi in memoria a ogni tasto).
- Nessun `setState` globale per aggiornare la posizione di riproduzione: usa uno stream/provider dedicato
  e ricostruisci solo il widget slider.
- Target: 10.000 brani, scroll fluido, avvio < 2 s con DB già popolato.

## 9. Sicurezza e privacy
- Nessuna chiave API nel codice (le API usate sono pubbliche senza chiave).
- Nessuna telemetria. Le richieste web partono **solo** da azioni dell'utente o da opzioni
  di arricchimento esplicitamente attive (default: spente).
- Niente server in ascolto, salvo la fase 6 (e solo mentre la schermata di condivisione è aperta, con PIN).

## 10. Cosa NON fare
- Non riscrivere i tag in-place; non cancellare file musicali dell'utente senza doppia conferma
  esplicita (unica via: pulizia duplicati, Fase 21).
- Non usare `dart:html`, WebView, o plugin non supportati su Linux/Windows/Android.
- Non copiare codice Python riga per riga: porta la **logica** da `04-specifiche-da-python.md`.
- Non creare documentazione extra non richiesta.
