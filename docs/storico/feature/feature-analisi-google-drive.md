# Analisi — collegare FreeKmusic a Google Drive

Scritta durante il kickoff del 15/11/2026 su richiesta dell'utente («analizza le problematiche del collegamento di
Google all'app, in base alla licenza del progetto: rischi, cause ed effetti, non tralasciare nulla»). Esito: **Google
Drive scartato** (D-572); il problema dello spazio si risolve con la libreria in streaming (D-574..D-581) e il backup in
una cartella scelta (D-588). Questo documento resta come base se un giorno si riapre la questione.

Non è una consulenza legale. Le fonti sono state controllate il 15/11/2026; i testi di legge italiani sono stati letti
su Brocardi e vanno riscontrati su Normattiva prima di qualsiasi uso.

## 1. Cosa si voleva fare
L'utente entra con il suo account Google; i brani scaricati finiscono nel suo Drive (solo Drive, solo dispositivo o
entrambi); l'app li suona da Drive con una smart cache locale di 1 GB regolabile; il collegamento si propone
nell'onboarding e si trova nelle impostazioni.

## 2. Situazione di partenza del progetto (fatti)
| Fatto | Fonte |
|---|---|
| Repo `iTzEmany/FreeKmusic` **pubblico**, campo `license` nullo: nessuna licenza, cioè «tutti i diritti riservati» | api.github.com, 15/11/2026 |
| Nessun file LICENSE, nessuna voce in `pubspec.yaml` (`publish_to: none`) né nel README | codice |
| L'app distribuisce codice **GPLv3**: NewPipeExtractor (Android) e youtubedl-android (GPL-3.0, flavor full); yt-dlp è Unlicense; metadata_god è MIT | jitpack, api.github.com, `third_party/metadata_god/LICENSE` |
| Nessun codice OAuth, nessun archivio sicuro dei segreti (solo `JamSecretStore` su SharedPreferences/file) | codice |
| Distribuzione: APK su GitHub Releases firmati con chiave fissa (D-569), Flatpak, zip Windows/macOS; niente Play Store | D-569, release.yml |
| Scopo principale dell'app: scaricare e suonare audio da YouTube | — |

## 3. Requisiti tecnici di Google (cosa sarebbe servito)
| Tema | Dettaglio | Fonte |
|---|---|---|
| Permesso (scope) | `drive.file` (solo file creati dall'app o scelti con il Picker) e `drive.appdata` sono **non sensibili**; `drive` e `drive.readonly` sono **restricted** (verifica + valutazione di sicurezza CASA a pagamento) | developers.google.com/workspace/drive/api/guides/api-specific-auth |
| Schermata di consenso | In «Testing»: massimo 100 utenti di prova e **token che scadono dopo 7 giorni**. In «Production» con soli scope non sensibili: niente verifica dei dati, ma per mostrare nome e logo serve la brand verification: homepage pubblica, privacy policy sullo stesso dominio, dominio verificato in Search Console | support.google.com/cloud/answer/15549945; …/production-readiness/brand-verification |
| Client per piattaforma | Android: un client per pacchetto + impronta SHA-1 di **ogni** chiave (release fissa, debug, perf) e `serverClientId`; desktop: client «installed app», segreto non confidenziale per definizione, PKCE e redirect loopback `127.0.0.1` | developers.google.com/identity/protocols/oauth2/native-app; README google_sign_in_android |
| Pacchetti Flutter | `google_sign_in` 7.2.0 (BSD-3) **non supporta Linux né Windows**; su desktop serviva `google_sign_in_all_platforms` 2.0.3 (comunità) o `googleapis_auth` 2.3.7 con server loopback; token da custodire con `flutter_secure_storage` 11.2.0 (Linux: libsecret e un portachiavi attivo) | pub.dev, 15/11/2026 |
| Quote | 325.000 unità/min per utente, download 200 unità, upload 750 GB/giorno, egress 1 TB/giorno per progetto (Google ha annunciato possibili costi dal 2026 con 90 giorni di preavviso); `Range` con `alt=media` supportato | developers.google.com/workspace/drive/api/guides/limits (agg. 1/5/2026) |
| Privacy | Privacy policy pubblica obbligatoria e collegata al client OAuth; regole «Limited Use» | developers.google.com/terms/api-services-user-data-policy (15/2/2024) |

## 4. Rischi: cause ed effetti
| # | Causa | Effetto | Chi lo subisce | Probabilità | Rimedio possibile |
|---|---|---|---|---|---|
| G-1 | L'app esiste per scaricare da YouTube, vietato dai Termini di YouTube; i Termini delle API Google (§2b rispetto delle leggi e degli altri termini Google, §3a sospensione senza preavviso) | Google sospende il progetto Cloud: l'accesso con Google smette di funzionare **per tutti, di colpo**; chi ha scelto «solo Drive» non raggiunge più la sua libreria dall'app | tutti gli utenti, soprattutto chi ha poco spazio (il caso per cui nasceva la funzione) | alta (precedente: Vanced, diffida di Google nel 2022) | nessuno davvero: ogni nuovo progetto è esposto allo stesso motivo |
| G-2 | Termini delle API Google §4b1: «Developer credentials may not be embedded in open source projects» | Il repo è pubblico: un client ID/segreto nel codice viola i termini e può essere revocato; chiunque può riusarlo | sviluppatore | certa se lo si committa | iniettare le credenziali dalla CI con i segreti (restano comunque estraibili dall'APK) o far usare a ogni utente il proprio client («bring your own client», macchinoso) |
| G-3 | App in «Testing» | Login che scade ogni 7 giorni, massimo 100 utenti | tutti | certa finché non si pubblica | passare in «Production» (vedi G-4) |
| G-4 | Brand verification | Servono un sito con dominio proprio, privacy policy e verifica del dominio: costi e manutenzione per un progetto personale | sviluppatore | certa | — |
| G-5 | Contenuti protetti da diritto d'autore su Drive (regole del programma Drive: «repeated infringement … will result in account termination») | Rimozione dei file; nei casi ripetuti chiusura dell'account Google dell'utente (Gmail, foto, tutto) | utente | media se condivide i file, bassa se restano privati | non condividere; avvisare nell'app |
| G-6 | Accesso diverso per piattaforma (google_sign_in senza Linux/Windows) | Due flussi di login da mantenere, più punti di rottura (Credential Manager su Android, portachiavi su Linux/Flatpak) | sviluppatore | certa | — |
| G-7 | Quote ed egress per progetto, possibili costi dal 2026 | Con molti utenti che ascoltano da Drive il progetto supera le soglie; l'app non ha un backend né un budget | sviluppatore | bassa oggi, cresce con gli utenti | — |
| G-8 | Latenza di Drive e file segnalati come abusivi (`acknowledgeAbuse`) | Avvio lento dei brani non in cache; file bloccati | utente | media | smart cache |
| G-9 | Token di accesso salvati sul dispositivo | Furto del token = accesso al Drive dell'utente (limitato ai file dell'app con `drive.file`) | utente | bassa | archivio sicuro di sistema |

## 5. Licenza del progetto (indipendente da Google)
- **Problema già presente oggi.** Il repo non ha licenza ma l'app distribuisce codice GPLv3 (NewPipeExtractor,
  youtubedl-android). La GPLv3 chiede che chi distribuisce i binari renda disponibile il sorgente sotto GPLv3.
- **Effetto.** Violazione della licenza di quei progetti: rischio civile (diffida, rimozione da GitHub, inibitoria).
  GPLv3 §8: la licenza decade alla violazione; se è il primo avviso e si sana entro 30 giorni, i diritti tornano in
  modo definitivo (parafrasi da opensource.com; testo da riscontrare su gnu.org).
- **Rimedio consigliato.** Pubblicare il progetto sotto GPLv3 (D-573, scelta al giro 3 del kickoff).
- **Relazione con Google.** Google non chiede né vieta una licenza; ma con un repo pubblico e libero le credenziali non
  possono restare riservate (G-2).

## 6. Profilo legale (Italia e UE)
| Chi | Tipo di rischio | Probabilità | Perché |
|---|---|---|---|
| Sviluppatore | penale | bassa | L'art. 171-ter c.1 lett. f-bis L. 633/1941 (strumenti per eludere misure tecnologiche) richiede scopi commerciali o di lucro; l'app è gratuita |
| Sviluppatore | civile | media | Diffida, rimozione da GitHub, inibitoria. In Germania LG/OLG Amburgo hanno ritenuto il «rolling cipher» di YouTube una misura tecnologica efficace e condannato Uberspace, che ospitava youtube-dl (lto.de, netzpolitik.org 2024). Negli USA il DMCA della RIAA contro youtube-dl (2020) fu ritirato da GitHub il 16/11/2020 (eff.org). In Italia l'AGCOM blocca siti commerciali di stream ripping (ytmp3.cc 2019 … ytmp3.gg 19/2/2026); nessuna azione nota contro app gratuite |
| Sviluppatore | contrattuale con Google | alta per la perdita dell'accesso, bassa per una causa | Vanced (3/2022): solo diffida e chiusura volontaria; nessuna causa nota contro sviluppatori gratuiti per OAuth |
| Sviluppatore | licenza GPL | media, rimediabile | § 5 |
| Sviluppatore | privacy (GDPR) | bassa | Senza backend la qualifica di titolare è dubbia; la privacy policy serve comunque per Google |
| Utente | amministrativo o penale | bassa | La copia privata (art. 71-sexies c.3) non vale per opere on demand protette da misure tecnologiche, quindi il download da YouTube non è coperto; la sanzione è amministrativa (art. 174-ter: 154 €, fino a 5.000 € se grave o ripetuto); il penale (art. 171-ter) richiede lucro o uso non personale |
| Utente | account Google | media | § 4, G-5 |

**Gratuità.** Riduce il rischio penale (manca il lucro) ma non quello civile né quello contrattuale con Google.
**Drive non aggiunge un rischio penale nuovo**: il rischio legale nasce dal download da YouTube, che l'app fa già. Drive
aggiunge un punto di rottura (G-1) e obblighi (G-2, G-4).

## 7. Perché la scelta è caduta sulla libreria in streaming
- Il problema vero è che l'app tiene come mp3 ciò che si può ascoltare in streaming: lo streaming con smart cache lo
  risolve senza account, credenziali, sito o privacy policy.
- Drive non aiuta senza rete (serve la connessione come lo streaming).
- Ciò che Drive dava in più si copre in modo più sicuro: backup in una cartella scelta, che un'app cloud già installata
  può sincronizzare senza che FreeKmusic parli con Google (R-241); sostituzione dei brani spariti da YouTube (R-242);
  sincronizzazione delle playlist in rete locale (c'è già).

## 8. Se un giorno si riapre
Prerequisiti, in ordine: licenza GPLv3; privacy policy su un dominio proprio; scope `drive.file`; credenziali fuori dal
repo (segreti della CI) oppure «usa il tuo client»; login su desktop con loopback e PKCE; Drive solo come copia, mai
come unico posto dei brani (per G-1); avviso all'utente su copyright e condivisione.
