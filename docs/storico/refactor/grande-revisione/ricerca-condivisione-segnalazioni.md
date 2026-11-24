# Ricerca: condivisione e segnalazioni anonime (22/11, sonnet, fonti web del 22/11/2026)

## Condividere
- **Oggi**: nessuna condivisione verso l'esterno; `share_plus` non è in pubspec. «Condividi…» (app_it.arb:415) è il trasferimento LAN con PIN e QR (lib/services/share/share_link.dart:5-26). In ingresso c'è già `SharedText` (lib/services/online/shared_text.dart) con `handleShazamShare`.
- **Alternative**:
  1. Testo con link YouTube Music: 0 €, livello S; vale solo per brani, album e playlist pubblici.
  2. song.link/Odesli: 10 richieste/min senza chiave, ma un caso del 3/10/2026 riporta `PUBLIC_API_ACCESS_DEPRECATED`; dipendenza incerta.
  3. Pagina statica su GitHub Pages che legge i dati compressi nel frammento `#` dell'URL (il frammento non arriva al server): 0 €, livello M; l'anteprima su WhatsApp è generica.
  4. App Link https verificato con `assetlinks.json` su Pages: se l'app c'è la apre, altrimenti mostra la pagina 3.
  5. File m3u8/json: serve solo a chi ha l'app.
  6. Cartolina con copertina e QR (`qr_flutter` c'è già): adatta solo a poche tracce.
- **Playlist lunghe**: ID YouTube compressi con gzip e base64url, circa 13 caratteri per brano (100 brani ≈ 1,3 KB). Oltre 50-100 brani meglio passare al file.
- **Raccomandata**: 1 + 3 + 4. Testo leggibile più un link https alla pagina Pages, che mostra i link YouTube e «Apri in FreeKmusic»; l'app sa importare lo stesso link. Pacchetto: `share_plus` (nuovo, va approvato dall'utente), oppure un canale nativo Android `ACTION_SEND` più gli appunti su desktop, senza pacchetti.

## Segnalazioni anonime
- **Oggi**: lib/core/issue_report.dart:107 apre `github.com/iTzEmany/FreeKmusic/issues/new?...` (URL limitato a 7000 caratteri, :70), con le ultime 20 righe redatte (log_export.dart). Schermata: lib/ui/screens/settings/report_issue_screen.dart. Serve un account GitHub.
- **Alternative**:
  1. Cloudflare Worker che crea la issue GitHub con un token fine-grained (`issues:write`) salvato come segreto del Worker. Piano free: 100k richieste/giorno; Turnstile gratuito (serve una WebView); 0 €, livello M. Nessun segreto nell'APK, cronologia leggibile, si risponde con un commento.
  2. Web3Forms: 250 invii/mese gratis, chiave pubblica nell'APK, arriva un'email; livello S, più spam.
  3. Google Apps Script con un foglio.
  4. ntfy.sh: il topic nell'APK è l'unico «segreto».
  5. Bot Telegram: token nell'APK, da evitare.
  6. Sentry/GlitchTip: eccessivo.
  7. Broker MQTT della Jam: mescola due funzioni.
- **Raccomandata**: Worker → GitHub Issue (etichetta `da-triage`, limite per IP, limite di lunghezza, nessun IP inoltrato). La più semplice: Web3Forms. Nella UI va detto che l'IP è visibile al servizio intermedio. Resta compatibile con «nessuna telemetria», perché l'invio parte solo da un tasto esplicito.
- **Non verificato**: quote di Sentry e Telegram, limite di ntfy, chiave Odesli, lunghezza massima degli URL su WhatsApp.
