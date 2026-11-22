# Handoff
Aggiornato: 2026-11-22 · Stato: fase 135 fusa (#210: permesso audio revocato, errori senza raffica, karaoke alla riapertura, correzioni sulle righe stream); fasi 136-147 in `docs/fasi/`; schema DB v20, ultima decisione D-699.

## Prossima sessione
Prompt di avvio: `/obiettivo fase 136`

## Prossimi obiettivi
1. Fase 136 «Arricchimento unico e leggero» (MusicBrainz in coda con cooldown, righe stream sul motore unico, strumentali, migrazione v21); poi 137 → 147 nell'ordine di D-672 (una PR per fase, un commit per task). Dalla 135 restano due task aggiunti: 140.10b (uscita unica dei caricamenti falliti) e 146.11 (debounce alla chiusura).
1b. Per vedere la 135 sul Motorola serve una nuova versione: la prova completa è nella 147, ma una Release intermedia (1.6.5) si può chiedere quando vuoi.
2. Le fasi 143, 145 e 146 hanno task «proponi all'utente prima di decidere» (dove vive il Worker; pagina statica e limite m3u8; sync automatico e MQTT); la 147 chiede come mettere la build sul Motorola.

## Tocca a te
- [ ] Fase 143: creare l'account Cloudflare, il token GitHub fine-grained `issues:write` e l'etichetta `da-triage` (D-669).
- [ ] Fase 145: attivare GitHub Pages e pubblicare `assetlinks.json` con il fingerprint della chiave di firma (D-569); `share_plus` è già approvato (D-670), lo aggiunge la fase con `flutter pub add`.
- [ ] Fase 147: telefono collegato; concedere o togliere il permesso `READ_MEDIA_AUDIO` quando richiesto; backup completo dall'app prima di «Sostituisci».

## Da sapere
- Documenti: analisi e rilievi F-01..F-41 in `docs/refactor/grande-revisione/analisi.md`; rete di test, golden e metriche per fase in `docs/refactor/grande-revisione/rete.md`; scansioni di dettaglio nella stessa cartella; mockup approvati (D-693) in `docs/refactor/grande-revisione/mockup/` (`home.html`, `collezione.html`, `modelli-dizionari.html`, `segnalazione.html`, `player-download.html`; testi e dimensioni inventati: si ricavano da codice e ARB). Decisioni D-662..D-699 vincolanti.
- Prove dal log del telefono (analisi.md): L1 permesso `READ_MEDIA_AUDIO` revocato, L2 daylist non riproducibile (stessa causa), L3 raffica di popup al ripristino, L4 karaoke separa all'avvio, L5 «Correzione salvata, file non aggiornato», L6 MusicBrainz 503, L7 backup non verificabile dal log.
- Il Motorola edge 40 (ZY22HKD85K) è il telefono dell'utente, non di prova: niente disinstallazioni, nessun file toccato, firma di release (un APK di debug non si installa sopra). Il log si esporta da Impostazioni › Avanzate › Esporta log; logcat non serve. Il permesso `READ_MEDIA_AUDIO` lo concede solo l'utente. Mi A3 e Redmi restano i telefoni di test (volume 0, ripulire a fine prova).
- Fasi a rischio (135, 136, 137, 139, 140, 146): il task N.1 sono i test di caratterizzazione, committati verdi prima del resto; le parti su handler, query su `tracks`, backup, `EnrichEngine`, Jam e sync chiedono `/code-review high`.
- Migrazioni: una per fase, in un solo task: v21 (136), v22 (140), v23 (141), v24 (146).
- Stringhe nuove nelle 6 lingue con `scripts/arb_add.py`, poi `flutter gen-l10n`.
