# Fase 62 — Home «aggiunti da poco» (refactor «ui-jam-ricerca»)

**Obiettivo:** aperto, il blocco diventa una riga che scorre di lato con quadrati larghi che non si rimpiccioliscono, con titolo e artista.

**Prerequisiti:** fase 61 chiusa. Intoccabili e dispositivi: `fase-58-rete-jam-ricerca.md`. Decisione D-152.
Mockup: `docs/refactor/ui-jam-ricerca/mockup/home-aggiunti.html`.

**Comando mirato:** `flutter test test/ui/cover_fan_test.dart test/ui/home_test.dart test/ui/home_screen_test.dart`.

## Task

### 62.1 — 20 album (F-33)
`recentlyAddedAlbums(limit: 20)` (`home_blocks.dart:227`); chiuso il ventaglio di oggi mostra i primi 5 (`_maxCovers` vale solo per il ventaglio).

**Fatto quando:** il caso «chiuso con i primi 5» di 58.5 verde; test nuovo: aperto ci sono 20 album.

### 62.2 — Aperto = riga che scorre (F-31, F-32, F-36)
`cover_fan.dart`: aperto niente scala `spread/size`; `ListView.builder` orizzontale con quadrati da 84 dp fissi, copertine decodificate a misura
(`cacheWidth`), titolo (2 righe) e artista sotto. L'animazione di apertura riguarda solo i primi 5.

**Fatto quando:** test nuovo: aperto ogni quadrato misura 84 dp su 360 dp di larghezza, con titolo e artista; `cover_fan_test:11` riscritto di proposito.

### 62.3 — Accessibilità e desktop (F-35, F-38)
Etichetta «titolo, artista» su ogni copertina; il ventaglio si apre con Enter/Spazio. Su desktop l'hover apre e si chiude solo con un tocco fuori o un secondo tocco, non uscendo con il mouse.

**Fatto quando:** test nuovi «etichetta», «Enter apre», «hover apre e lo scroll non chiude».

### 62.4 — Mockup di ui-fluida (F-34)
Aggiungere lo stato aperto a `docs/refactor/ui-fluida/mockup/home.html` (o un link a `home-aggiunti.html`), così i due mockup non si contraddicono.

**Fatto quando:** il file è aggiornato.

### 62.5 — Controlli di fase
**Fatto quando:** `flutter analyze` pulito; comando mirato e `flutter test test/goldens` verdi (golden `home` e quello di 58.6 rigenerati una volta); review del diff; CI verde.
