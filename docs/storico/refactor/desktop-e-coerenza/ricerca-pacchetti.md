# Ricerca: pacchetti per F-206, F-207, F-208 (24/11/2026)
Fonti: pub.dev e GitHub dei pacchetti, consultati il 24/11/2026 (pub.dev mostra solo «N giorni fa»: date ricavate).

| Pacchetto | Versione | Data | Licenza | Piattaforme | Dipendenze native | Note |
|---|---|---|---|---|---|---|
| desktop_drop | 0.9.2 | ~20/10/2026 | Apache-2.0 | Linux, Windows, macOS | nessuna | gestisce il portal FileTransfer (percorsi validi anche in flatpak, `/run/user/UID/doc/`); `localPath` può essere null. **Richiede Flutter ≥ 3.47.7** (il progetto è su 3.47.1): alzare Flutter o usare una 0.8.x compatibile |
| super_drag_and_drop | 0.9.1 | ~06/2025 | MIT | tutte | Rust (binari precompilati) | fermo da 17 mesi, API pesante: scartato |
| tray_manager | 0.8.3 (0.9.x vuole Flutter 3.50) | ~22/11/2026 | MIT | Linux, Windows, macOS | `libgtk-3-dev libx11-dev libxi-dev`; niente appindicator dalla 0.7 | Linux = StatusNotifierItem su D-Bus: niente clic sull'icona, solo menu (`setContextMenu`). GNOME mostra la tray solo con l'estensione AppIndicator (Ubuntu sì, Fedora/Debian puri no). In flatpak serve probabilmente `--talk-name=org.kde.StatusNotifierWatcher` (dedotto, da provare) |
| system_tray | 2.0.3 | ~2023 | MIT | Linux, Windows, macOS | appindicator | abbandonato: scartato |
| window_manager | 0.7.1 | ~22/11/2026 | MIT | Linux, Windows, macOS | `libgtk-3-dev libx11-dev libxi-dev` | `hide/show`, `setPreventClose`, `onWindowClose`, `getBounds/setBounds`; su Wayland la posizione non si imposta dall'app |

## Raccomandazione
- **Trascinare file** (F-208): `desktop_drop`, nella versione compatibile con il Flutter del progetto; prova vera in flatpak.
- **Tray** (F-208): `tray_manager ^0.8.3`, menu con riproduci/pausa, successivo, mostra/nascondi, esci. «Chiudi nella tray» solo se la tray è disponibile; su Linux spento di default.
- **Finestra ricordata** (F-206): `window_manager` (serve comunque alla tray per nascondere la finestra e intercettare la chiusura); su Wayland si ricorda solo la dimensione.
- **Istanza unica e «Apri con»** (F-207): nel runner, senza pacchetti: GApplication senza `G_APPLICATION_NON_UNIQUE` e `gtk_window_present` in `activate` su Linux (funziona anche in flatpak); mutex e `SetForegroundWindow` su Windows; macOS lo fa il sistema.

## Non verificato
Comportamento reale in flatpak e su Wayland; compatibilità esatta di tray_manager 0.8.x con Flutter 3.47.
