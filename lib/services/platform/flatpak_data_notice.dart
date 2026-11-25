/// F-214: AppImage and deb keep their data in [oldDir]; the flatpak sandbox has its own [newDir].
/// The sandbox cannot see the old folder, so the notice only suggests; nothing is ever migrated by the app.
const flatpakOldDir = '~/.local/share/com.freekmusic.player';
const flatpakNewDir = '~/.var/app/com.freekmusic.player/data/com.freekmusic.player';

/// Run in a terminal outside the flatpak, with the app closed.
const flatpakCopyCommand = 'mkdir -p ~/.var/app/com.freekmusic.player/data && cp -a $flatpakOldDir ~/.var/app/com.freekmusic.player/data/';

/// True once: inside a flatpak ($FLATPAK_ID set), empty library, notice never shown.
bool flatpakNoticeDue({required Map<String, String> env, required bool libraryEmpty, required bool shown}) =>
    (env['FLATPAK_ID'] ?? '').isNotEmpty && libraryEmpty && !shown;
