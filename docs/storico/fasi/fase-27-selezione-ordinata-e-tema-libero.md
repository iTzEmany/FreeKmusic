# Fase 27 — Selezione multipla ordinata e tema totalmente personalizzabile

**Obiettivo (due richieste dell'utente, 2026-10-19):**
1. **Selezione ordinata.** Oggi, selezionando più brani e scegliendo «Aggiungi alla coda», «Riproduci dopo» o
   «Aggiungi a una playlist», i brani vanno **nell'ordine in cui compaiono in lista**, non in quello in cui sono stati
   toccati. Deve valere l'ordine di selezione, e deve essere **visibile** (numeri 1, 2, 3… sulle righe).
2. **Tema libero.** Oggi ci sono 3 temi fissi (Notte, OLED, Chiaro) × 8 accenti. Ogni colore — **sfondo**, superfici,
   accento, testi, errore, sfondo del lettore — deve poter essere scelto a piacere, salvato con un nome e (opzionale)
   avere un'immagine di sfondo.
**Prerequisiti:** Fase 11 (sistema visivo, `CcColors`), Fase 19 (tema chiaro e accenti), Fase 13 (le impostazioni sono già
nel backup: `settingsToJson` copia ogni chiave di `SharedPreferences`).
**Principio:** nessun colore scelto dall'utente può rendere l'app inutilizzabile: l'editor mostra il contrasto e propone
una correzione, ma **non vieta**; «Ripristina» è sempre a un tocco. Nessuna rete, nessun pacchetto nuovo.

## Stato di partenza (verificato nel codice)
**Selezione**
- `Selection` (`lib/providers/selection_providers.dart`) tiene `Set<int> ids`. Un `Set` letterale di Dart mantiene
  l'ordine d'inserimento, quindi **l'ordine dei tocchi esiste già nei dati**; viene buttato via dai consumatori:
  - `SelectionBar.build` costruisce `picked = [for (t in tracks) if (selection.contains(t.id)) t]` → ordine della lista;
  - `bulkActions` dichiara «`tracks` must be in the order of the list, not of the clicks» e usa quell'elenco per
    coda, «riproduci dopo» (con `reversed`), playlist, Jam, preferiti;
  - `TrackRow` (trascinamento desktop) e `youtube_results.dart` (download multiplo) usano `inOrderOf(visibleIds)`.
- `selectRange` (Maiusc+clic) aggiunge l'intervallo sempre in ordine di lista, anche se si va dal basso verso l'alto.
- Le righe in modalità selezione mostrano solo la spunta (`track_row_selection.dart`), nessun numero.
**Tema**
- `AppThemeId {notte, oled, chiaro}` + `CcAccent` (8 colori fissi, «lista chiusa» per garantire il contrasto);
  `buildPalette(theme, accent)` → `CcColors` (12 token: `bg`, `surface1-3`, `accent`, `accentSoft`, `onAccent`,
  `text`, `textMuted`, `textFaint`, `heroBase`, `error`, `isLight`); `buildTheme` in `app_theme.dart` ne ricava
  `ThemeData`; `context.cc` li legge ovunque. Impostazioni: `theme` e `accent` (stringhe) in `SettingsStore`.
- `heroBase` e `CoverBackdrop` colorano Ora in riproduzione/Testi/Auto con la tinta della copertina (`cover_tint.dart`).
- Fuori da `lib/ui/theme/` ci sono solo 2 usi di `Colors.*` (da eliminare) e `tags_sheet.dart` che chiama
  `buildPalette` per i colori delle etichette. Widget Android e tile leggono `flutter.widget.*` (nessun colore oggi).

## Decisioni
| Tema | Scelta |
|---|---|
| Ordine | **Sempre ordine di selezione**, senza interruttore: se si seleziona dall'alto in basso coincide con la lista. «Seleziona tutto» e l'intervallo restano in ordine di lista (l'intervallo nel verso del gesto: dal punto di partenza al clic, anche all'indietro). Deselezionare un brano al centro rinumera quelli dopo |
| Modello | `Selection` diventa una **lista ordinata** (`List<int> order` + `Set<int>` per il test di appartenenza). `ids` resta per compatibilità; nuovo getter `orderedIds`. `inOrderOf(visibleIds)` resta per i pochi casi che vogliono davvero l'ordine di lista (nessuno oggi) |
| Consumatori | `SelectionBar` costruisce `picked` da `order` (saltando i brani non più visibili); la regola «`tracks` nell'ordine della lista» di `bulkActions` diventa «nell'ordine di selezione»; trascinamento e download YouTube idem |
| Segnale visivo | Sulla copertina della riga selezionata un **cerchietto numerato** (1, 2, 3…) al posto della spunta; la barra dice «N selezionati» come oggi |
| Tema: modello | Nuovo `CustomTheme { id, name, baseId (notte/oled/chiaro), overrides: Map<token, ARGB>, background }` salvato come JSON in una chiave di `SharedPreferences` (`customThemes`) → entra da solo nel backup. `theme` accetta anche `custom:<id>` (i valori vecchi restano validi) |
| Tema: token | Tutti i 12 di `CcColors`. Modalità **semplice** (scegli sfondo, accento, testo: le superfici, i testi attenuati, `accentSoft`, `onAccent` e `heroBase` si **derivano**) e **avanzata** (ogni token a mano; un token modificato a mano non viene più ricalcolato) |
| Selettore colore | Fatto in casa (nessun pacchetto): ruota/quadrato HSV con tre cursori + campo esadecimale + colori recenti. `file_picker` (già presente) solo per l'immagine di sfondo |
| Contrasto | Indicatore WCAG per le coppie che contano (testo/sfondo, testo attenuato/superficie, `onAccent`/accento, accento/sfondo); sotto 4,5:1 un avviso con «Correggi» (sposta il colore di testo finché passa). **Non blocca** il salvataggio |
| `isLight` | Dedotto dalla luminanza di `bg` (non più dal preset di base): decide icone della barra di stato, ombre e tinte |
| Sfondo | Tre modi: **tinta unita**, **sfumatura** (2 colori + angolo) o **immagine** (copiata nella cartella dati dell'app, oscuramento e sfocatura regolabili); l'immagine sta dietro alle liste con le superfici semitrasparenti. Per Ora in riproduzione si può scegliere «tinta della copertina» (oggi) o «sfondo del tema» |
| Anteprima | L'editor mostra un'anteprima viva (riga brano, mini-player, barra, scheda, pulsante, interruttore) con il tema in modifica, senza applicarlo finché non si salva |
| Condivisione | «Esporta tema» / «Importa tema» come file `.json` piccolo (nessuna rete, nessun invio) |
| Accessi | Impostazioni → Aspetto: elenco dei temi (3 predefiniti + i miei) con pastiglie; «Personalizza» parte da una copia del tema in uso; i predefiniti non si modificano, si duplicano |
| Android | Il widget e la tile non hanno colori propri: nessuna modifica. La barra di stato/navigazione segue `isLight` |
| Pacchetti nuovi | **Nessuno.** (`file_picker` c'è già) |

## Task

### Parte A — Selezione ordinata
**27.1 — Modello e test (puro).** `Selection`: lista ordinata + insieme; `toggle` (aggiunge in coda, toglie e
mantiene l'ordine degli altri), `selectRange` nel verso del gesto, `selectAll` in ordine di lista, `retainWhere`
che conserva l'ordine, `orderedIds`. Test in `test/providers/selection_test.dart`: tocco 3→1→2 dà [3,1,2]; togliere
l'1 dà [3,2]; intervallo all'indietro; il filtro nasconde un brano e l'ordine degli altri resta; `selectAll`.

**27.2 — Consumatori.** `SelectionBar` (`picked` da `order`), `bulkActions` (commento e uso: coda, «riproduci
dopo» — dove oggi c'è `reversed` per «ordine di lista = ordine di ascolto», resta il `reversed` ma sull'elenco in
ordine di selezione —, playlist, Jam), trascinamento desktop (`track_row.dart`), download YouTube
(`youtube_results.dart`), e controllo di `send_tab.dart`, `tags_sheet.dart`, `move_to_album_dialog.dart` (che
potrebbero avere un loro ordine). `PlaylistRepository.addTracks` deve rispettare l'ordine ricevuto: verificare e,
se serve, correggere (posizione crescente in quell'ordine).
**Test:** per ognuna delle azioni, selezione 3→1→2 di una lista [1,2,3] dà coda/playlist [3,1,2];
selezione dall'alto in basso invariata.

**27.3 — Numeri sulle righe.** `track_row_selection.dart`: cerchietto con la posizione (1-based) al posto della
spunta, stesse dimensioni (la riga non cambia altezza); da 100 in su «99+» o numero più piccolo; etichetta
semantica «selezionato, posizione N». **Test:** widget test della riga (numero giusto, scompare alla
deselezione, i successivi scalano).

**27.4 — Prova a mano.** Sul telefono: seleziona 3 brani non adiacenti in ordine sparso → «Aggiungi alla coda» →
la coda è nell'ordine dei tocchi; stessa cosa con «Aggiungi a playlist» e «Riproduci dopo»; trascinamento sul
desktop. Scatti con adb come per 11.19.

### Parte B — Tema totalmente personalizzabile
**27.5 — Modello del tema (puro).** `CustomTheme` + JSON (versione 1, token sconosciuti ignorati, colori non validi
scartati), `buildCustomPalette(CustomTheme)` con la **derivazione automatica** (superfici da `bg` a passi di
luminanza, testi attenuati per miscela testo/sfondo, `accentSoft`, `onAccent` per contrasto migliore, `heroBase`
dalla tinta dell'accento), `isLight` da luminanza. Un override esplicito vince sempre sul derivato.
**Test:** derivazione su sfondi scuro/chiaro/colorato, override rispettati, JSON round trip, nome mancante,
colore corrotto, `bg` con trasparenza (si forza opaco), `buildPalette` dei temi predefiniti **invariato**
(i test esistenti di `contrast_test.dart` restano).

**27.6 — Salvataggio e scelta.** `SettingsStore`: chiave `customThemes` (lista JSON, tetto 20) e `theme` =
`custom:<id>`; `buildTheme` accetta un `CcColors` già pronto; `app.dart` risolve il tema attivo; un id che non
esiste più ricade su `notte`. Controllo che `settingsToJson`/ripristino li portino (backup) e che il ripristino di
un backup con un tema personalizzato lo mostri subito. **Test:** persistenza, id orfano, backup/ripristino.

**27.7 — Selettore colore.** `lib/ui/widgets/color_picker.dart`: quadrato saturazione/luminosità + cursore tinta +
cursore trasparenza (solo dove serve) + campo `#RRGGBB` + colori recenti; tastiera e valore accessibili (non solo
il tocco). **Test:** hex valido/non valido, i cursori producono il colore atteso, il campo e i cursori restano
allineati.

**27.8 — Editor del tema.** `lib/ui/screens/settings/theme_editor_screen.dart`: nome, modalità semplice/avanzata,
elenco dei token con pastiglia + selettore, «ripristina questo colore», anteprima viva (riga, mini-player, barra,
scheda, pulsante, interruttore, testo attenuato), indicatore di contrasto con «Correggi», «Annulla modifiche»,
«Salva». Anteprima in un `Theme` annidato (non cambia l'app finché non si salva).
**Test:** costruzione senza eccezioni; modificare lo sfondo cambia l'anteprima ma non il tema attivo; «Correggi»
porta il contrasto a ≥ 4,5; salva → il tema compare nell'elenco.

**27.9 — Elenco e gestione (Impostazioni → Aspetto).** Pastiglie dei 3 predefiniti + i miei; «Nuovo tema» (copia del
tema in uso), modifica, duplica, rinomina, elimina (con annulla), «Esporta/Importa tema» come `.json`. La vecchia
scelta Accento resta per i predefiniti. **Test:** crea → applica → riavvio simulato → è ancora attivo; elimina quello
attivo → si torna a Notte; importa un file rotto → messaggio, nessun cambiamento.

**27.10 — Sfondo.** Tinta unita / sfumatura / immagine (`file_picker`, copia in `<dati>/theme/`, ridimensionata
a ≤ 1920 px per non pesare, oscuramento 0–80 %, sfocatura 0–20); `ThemeBackground` dietro il `Scaffold` principale e
le pagine a schermo intero; superfici con trasparenza solo quando c'è un'immagine; opzione «Ora in riproduzione:
tinta della copertina / sfondo del tema» (`CoverBackdrop`). Immagine illeggibile o cancellata → tinta unita senza
errori. **Test:** ricadute sugli errori, oscuramento applicato, nessun I/O sul thread UI (decodifica con
`compute`/`Isolate`, regola «lavoro pesante fuori dalla UI»).

**27.11 — Pulizia dei colori fuori dai token.** Eliminare i 2 `Colors.*` rimasti fuori da `lib/ui/theme/`; un
**test di regressione** che cerca nel sorgente `Color(0x` e `Colors.` fuori da `lib/ui/theme/` (con una lista di
eccezioni motivate, es. `tags_sheet.dart` per i colori delle etichette). Verifica a schermo di tutte le schermate con
tre temi estremi (bianco su bianco evitato dal contrasto, giallo acceso, quasi-nero su nero) con gli scatti
dei golden/`test_shots/`.

**27.12 — Rifinitura, documentazione e prova a mano.** Guida utente (`docs/guida/`) con la sezione «Colori e sfondo»;
`PROGRESS.md`, `02-architettura.md`; prova su Mi A3 (720×1560) e Motorola (1080×2400) e su Linux: crea un tema,
cambia sfondo e accento, immagine di sfondo, riavvia, ripristina da backup; leggibilità al sole del tema scelto
(si lega alla prova ancora aperta di 11.19).

## Ordine e stime
La parte A è piccola (≈ mezza giornata): 27.1 → 27.2 → 27.3 → 27.4. La parte B è la più grande: 27.5–27.9 sono il nucleo
(tema + editor), 27.10 (immagine di sfondo) si può rimandare senza bloccare il resto, 27.11–27.12 chiudono.
Si consiglia di consegnare la parte A da sola (tag `fase-27a-ok`) e poi la B (`fase-27-ok`).

## Rischi
- **Contrasto/illeggibilità:** l'utente può scegliere colori brutti. Mitigazione: indicatore + «Correggi», anteprima
  prima di salvare, «Ripristina predefinito» sempre raggiungibile anche con testo invisibile (il pulsante sta nella
  barra del sistema/Impostazioni con colori di emergenza fissi).
- **Prestazioni con l'immagine:** decodifica e sfocatura costose → ridimensionare al salvataggio, sfocatura con
  `ImageFiltered` solo sull'immagine già ridotta, niente ricalcolo a ogni frame.
- **Tinte delle copertine** (`cover_tint.dart`, test di contrasto a 7:1 su `notte`/`chiaro`): vanno estesi al
  tema libero, altrimenti il testo sulla tinta può diventare illeggibile (tema con testo scuro su sfondo chiaro).
- **Numeri di selezione** su righe già dense (copertina 48–56 px): il cerchietto deve restare leggibile con testo di
  sistema grande (prova con scala 1,3).
