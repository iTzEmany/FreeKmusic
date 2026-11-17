# Fase 129 — Karaoke nella Jam

## Obiettivo
Il karaoke fa parte della Jam e vale per tutti quelli che ascoltano: l'host decide con «Gli ospiti possono usare il
karaoke» (spento di partenza) se gli ospiti lo comandano; nella Jam a distanza ogni uscita applica lo stesso livello e
chi ascolta può scegliere «Ignora per me». Le versioni vecchie dell'app ignorano il campo nuovo. «Alta qualità» solo
se la base è sul dispositivo che suona, altrimenti il filtro (D-587).

## Riferimenti
D-586, D-587; specifica [`../storico/feature/feature-libreria-leggera-karaoke-cerca.md`](../storico/feature/feature-libreria-leggera-karaoke-cerca.md)
§ Architettura D («Jam»). Area a rischio: protocollo Jam e Jam a distanza (review Opus del protocollo). Documento
d'area: `../architettura/sync-backup-jam.md`.

## Mockup
```text
Jam (host)                           Jam a distanza (ospite)
+--------------------------------+   +--------------------------------+
| Jam                            |   | Jam                            |
| Host · impostazioni della Jam  |   | Ospite in una Jam a distanza   |
| Gli ospiti possono usare       |   | +----------------------------+ |
|   il karaoke             [off] |   | | Karaoke acceso da Marco ·  | |
|                                |   | |   voce 10 %                | |
| Nella Jam in casa suona un     |   | | Ignora per me        [off] | |
| solo dispositivo: il karaoke   |   | +----------------------------+ |
| vale per tutti.                |   |                                |
| Home   Cerca   Libreria Impost.|   | Home   Cerca   Libreria Impost.|
+--------------------------------+   +--------------------------------+
```

## Task
- [x] 129.1 Protocollo: campo e comando del karaoke (R-246, D-587) — review Opus del protocollo
  - File: `lib/services/jam/jam_models.dart` (`JamState.toJson` `:287`: `'kar': {'l': livello, 'g': ospitiAmmessi}` solo
    se acceso, come `'spk'`; `tryParse` lo legge se c'è; `JamCommandType.karaoke`), `lib/services/jam/jam_state.dart`
    (`applyCommand` `:19`), `test/jam/jam_state_test.dart`, `test/jam/remote/jam_protocol_test.dart`.
  - Passi:
    1. **Prima** i test: uno stato con `'kar'` letto dal parser di oggi senza errori; un comando `karaoke` letto da una
       versione che non lo conosce → `JamCommand.tryParse` torna `null` (`:465`) e la Jam continua; `applyCommand` rifiuta
       il comando da un ospite col permesso spento e lo applica col permesso acceso; l'host lo applica sempre.
    2. Campo e comando; il messaggio passa anche dalla Jam a distanza (`lib/services/jam/remote/`) senza cambiare la
       crittografia.
  - Comando mirato: `flutter test test/jam/jam_state_test.dart test/jam/remote/jam_protocol_test.dart test/jam/remote/remote_jam_guest_test.dart test/jam/jam_host_test.dart` (più `flutter analyze`)
  - Fatto quando: test verdi; review Opus del diff del protocollo senza problemi aperti.

- [x] 129.2 Karaoke della Jam su chi suona e interfaccia (R-246, D-587) — `/code-review high`
  - File: `lib/providers/karaoke_providers.dart` (il controller segue lo stato della Jam quando ce n'è una),
    preferenza locale «Ignora per me», `VoiceFilter` per il player che suona la Jam a distanza (in fase 127 è `null`: da
    verificare in `lib/ui/screens/jam/jam_player.dart` e `lib/services/jam/jam_output.dart`), voce dell'host accanto a
    `lib/ui/screens/settings/jam_gate_tiles.dart`, riquadro dell'ospite in `lib/ui/screens/jam/`, ARB, test in
    `test/services/karaoke/` e `test/ui/`.
  - Passi:
    1. Test prima: in Jam il livello arriva dallo stato della Jam; con «Ignora per me» il dispositivo resta senza filtro
       e la Jam non cambia; microfono dell'ospite disabilitato col permesso spento; «Alta qualità» solo se la base è sul
       dispositivo che suona.
    2. Voce dell'host, riquadro «Karaoke acceso da <nome> · voce N %» con «Ignora per me»; etichette TalkBack.
    3. Prova con una Jam vera: Mi A3 host e un'istanza Linux ospite (`xvfb-run`), in casa e a distanza.
  - Comando mirato: `flutter test <test nuovi> test/services/karaoke/karaoke_controller_test.dart test/ui/no_separator_literals_test.dart test/ui/architecture_test.dart` (più `flutter analyze`)
  - Fatto quando: test verdi; nella Jam vera l'ospite senza permesso non cambia il livello, col permesso sì, e
    per l'ospite a distanza con «Ignora per me» il filtro della sua uscita resta spento (log).

## Tocca a te
Niente di obbligatorio: se vuoi, a fase chiusa prova il karaoke in una Jam col tuo telefono e quello di un amico.

## Note di deviazione
- 129.1: `'kar'` viaggia anche a karaoke spento se gli ospiti sono ammessi (`{'g': true}`, senza `l`): serve all'ospite per sapere del permesso. Il livello è arrotondato a passi di 0,05 in `applyCommand` (un trascinamento dello slider non genera una versione per decimale). Un `l` esplicitamente `null` nel comando vale «spento».
- 129.2: «Alta qualità» non c'è ancora (la fase 128 aspetta la scelta dell'utente): niente da fare qui, si aggiunge con la 128. Nel riquadro dell'ospite il separatore «·» del mockup è la virgola (separatore della casa, niente «·» nel codice, D-481): «Karaoke acceso da Marco, voce 10 %». L'impostazione dell'host sta nel foglio «Uscita audio» della Jam (l'unico posto con le opzioni dell'host durante la Jam; `jam_gate_tiles` è nelle Impostazioni, fuori dalla Jam). In Jam il bypass di episodi/radio non c'è (le voci della Jam sono brani); resta sul player locale. Il microfono dell'host in una Jam in casa si nasconde se il dispositivo non ha il filtro (Windows, macOS); in una Jam a distanza c'è sempre. Correzione dopo la review e la prova con due telefoni: un ospite remoto non suona mai (R-157: non è mai in `outputs`, il suo `JamOutput` non parte), quindi «Ignora per me» non gli è mai utile e non compare: il riquadro «Karaoke acceso da…» si mostra a ogni ospite di una Jam con ospiti remoti con il karaoke acceso, «Ignora» solo a un'uscita in LAN non host di una Jam mista (`JamUiState.remoteJam`). L'host che invita conta come Jam a distanza (`inviting`): il microfono c'è sempre, niente nota della Jam in casa. La nota dell'host ora dice «Nella Jam in casa il karaoke vale per tutte le uscite che lo supportano» (più uscite sincronizzate, un'uscita Windows lascia la voce). Lo slider in Jam agisce solo sulla Jam (disabilitato col karaoke della Jam spento), tiene il valore del trascinamento finché lo stato dell'host non lo riporta, `forbidden` mostra uno snackbar. Il passo 3 (prova con una Jam vera) è della prova di fase.
