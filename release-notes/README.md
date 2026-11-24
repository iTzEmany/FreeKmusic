# Note di rilascio

Prima del tag `vX.Y.Z` si scrive `release-notes/X.Y.Z.md`: il job `publish` di `release.yml` lo mette in cima alla Release (prima del «What's Changed» di GitHub) e fallisce se manca. L'app mostra solo questo blocco, in italiano.

```
## Novità
- evidenza | mic | Titolo | Testo (al massimo una riga «evidenza»)
- play | Titolo | Testo
## Correzioni
- Una riga per correzione
```

Formato di una novità: `- [evidenza |] <icona> | <titolo> | <testo>`. Righe rotte e tutto il resto sono ignorati.

Icone: mic, play, home, sync, heart, share, download, settings, bug, search, music, playlist, queue, lyrics, cloud, shield, speed, palette, language, star (un nome sconosciuto dà `star`).
