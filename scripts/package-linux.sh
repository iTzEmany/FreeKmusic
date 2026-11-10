#!/usr/bin/env bash
# Pacchetto Linux: bundle release + .desktop + icona in uno zip (build/freekmusic-linux-x64.zip);
# con --deb anche build/freekmusic_<versione>_amd64.deb (serve dpkg-deb).
# Prerequisito: flutter build linux --release. Sul sistema serve libmpv (apt install libmpv2).
set -euo pipefail
cd "$(dirname "$0")/.."
DEB=0; [ "${1:-}" = "--deb" ] && DEB=1
DEB=$DEB python3 - <<'PY'
import os, re, shutil, subprocess, textwrap

bundle = "build/linux/x64/release/bundle"
if not os.path.exists(os.path.join(bundle, "freekmusic")):
    raise SystemExit("Esegui prima: flutter build linux --release")

out = "build/freekmusic-linux"
shutil.rmtree(out, ignore_errors=True)
os.makedirs(out)
shutil.copytree(bundle, os.path.join(out, "freekmusic"))
shutil.copy("assets/icon/icon.png", os.path.join(out, "freekmusic", "freekmusic.png"))
desktop = open("packaging/linux/freekmusic.desktop").read()
with open(os.path.join(out, "freekmusic.desktop"), "w") as f:
    f.write(desktop.replace("@EXEC@", """sh -c 'cd "$(dirname "$(readlink -f "%k")")/freekmusic" && ./freekmusic'"""))

if os.environ.get("DEB") == "1":
    version = re.search(r"^version:\s*([0-9.]+)", open("pubspec.yaml").read(), re.M).group(1)
    root = "build/deb-root"
    shutil.rmtree(root, ignore_errors=True)
    shutil.copytree(bundle, os.path.join(root, "opt/freekmusic"))
    shutil.copy("assets/icon/icon.png", os.path.join(root, "opt/freekmusic/freekmusic.png"))
    os.makedirs(os.path.join(root, "usr/bin"))
    os.symlink("/opt/freekmusic/freekmusic", os.path.join(root, "usr/bin/freekmusic"))
    os.makedirs(os.path.join(root, "usr/share/applications"))
    with open(os.path.join(root, "usr/share/applications/freekmusic.desktop"), "w") as f:
        f.write(desktop.replace("@EXEC@", "freekmusic").replace("Icon=freekmusic", "Icon=/opt/freekmusic/freekmusic.png"))
    os.makedirs(os.path.join(root, "DEBIAN"))
    with open(os.path.join(root, "DEBIAN/control"), "w") as f:
        f.write(open("packaging/linux/deb/control.in").read().replace("@VERSION@", version))
    deb = f"build/freekmusic_{version}_amd64.deb"
    subprocess.run(["dpkg-deb", "--root-owner-group", "--build", root, deb], check=True)
    print(deb)
archive = shutil.make_archive("build/freekmusic-linux-x64", "zip", out)
print(archive)
PY
