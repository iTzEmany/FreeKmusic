# Handoff
Aggiornato: 2026-11-24 · Stato: le fasi 135-147 della grande revisione sono chiuse (la 147 nella parte documentale e nelle misure); schema DB v24; pianificato il refactor «desktop-e-coerenza» (fasi 150-161), ultima decisione D-740.

## Prossima sessione
Release 1.7.0 uscita il 24/11 (tag `v1.7.0`, con la fase 148 «video karaoke nella Jam»). Worker pubblicato e `kReportEndpoint` impostato (24/11). Dopo il tag restano le prove su telefono della fase 147 (147.3-147.6) e la lista «Tocca a te» di quella fase. Prossima fase: 149 «Novità dell'aggiornamento e scheda di condivisione» (`fasi/fase-149-novita-e-scheda-di-condivisione.md`, D-711, D-712, mockup in `feature/`). Dopo la 149: refactor «desktop-e-coerenza», fasi 150-161 in ordine (D-735), prompt `/obiettivo fase 150`.

## Cosa resta
- Rinvii di codice delle review 142-146: [`prossimi-lavori.md`](prossimi-lavori.md), sezione «Dalla grande revisione (fasi 135-147)».
- Prese in autonomia: D-707 (review 144), D-708 e D-709 (review 146); vedi [`decisioni.md`](decisioni.md).

## Tocca a te
- [ ] Dopo il merge: tag `v1.7.0` (versione già alzata) e Release dalla CI; poi l'aggiornamento dall'app sul Motorola.
- [ ] Prove su telefono, account e pubblicazioni: elenco completo in «Tocca a te» di [`fasi/fase-147-verifica-finale.md`](fasi/fase-147-verifica-finale.md); resta aperto il deploy del Worker Cloudflare con il token (D-669).

## Da sapere
- Refactor «desktop-e-coerenza» (D-714..D-740): analisi e rilievi in `refactor/desktop-e-coerenza/analisi.md`, rete di test e metriche in `refactor/desktop-e-coerenza/rete.md`, specifica visiva approvata in `refactor/desktop-e-coerenza/mockup/index.html` (17 pagine), pacchetti nuovi decisi in `refactor/desktop-e-coerenza/ricerca-pacchetti.md` (solo `window_manager`, `tray_manager ^0.8.3`, `desktop_drop`). PR #231 ha già chiuso F-201, F-203, F-212, F-216 (flatpak).
- Analisi e rilievi F-01..F-41, rete di test, scansioni e mockup della grande revisione sono archiviati in `docs/storico/refactor/grande-revisione/`. Decisioni D-662..D-699 vincolanti.
- Il Motorola edge 40 (ZY22HKD85K) è il telefono dell'utente, non di prova: niente disinstallazioni, nessun file toccato, firma di release. Il log si esporta da Impostazioni › Avanzate › Esporta log. Il permesso `READ_MEDIA_AUDIO` lo concede solo l'utente. Mi A3 e Redmi sono i telefoni di test (volume 0, ripulire a fine prova).
- Stringhe nuove nelle 6 lingue con `scripts/arb_add.py`, poi `flutter gen-l10n`.
