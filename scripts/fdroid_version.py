#!/usr/bin/env python3
"""Writes the pubspec version into packaging/fdroid/com.freekmusic.player.yml.

  fdroid_version.py [pubspec] [yml]          rewrite versionName, versionCode, commit
  fdroid_version.py --check [pubspec] [yml]  exit 1 if they differ (CI)
"""
import re
import sys

args = [a for a in sys.argv[1:] if a != "--check"]
check = "--check" in sys.argv
pubspec = args[0] if args else "pubspec.yaml"
path = args[1] if len(args) > 1 else "packaging/fdroid/com.freekmusic.player.yml"

m = re.search(r"^version:\s*([0-9.]+)\+([0-9]+)", open(pubspec).read(), re.M)
if not m:
    sys.exit(f"{pubspec}: no 'version: x.y.z+n'")
name, code = m.groups()
old = open(path).read()
new = re.sub(r"(versionName:\s*)\S+", rf"\g<1>{name}", old, count=1)
new = re.sub(r"(versionCode:\s*)\S+", rf"\g<1>{code}", new, count=1)
new = re.sub(r"(\n\s+commit:\s*)v\S+", rf"\g<1>v{name}", new, count=1)
if check:
    got = [re.search(rf"{k}:\s*(\S+)", old) for k in ("versionName", "versionCode", "commit")]
    if None in got:
        sys.exit(f"{path}: versionName, versionCode or commit is missing")
if new == old:
    sys.exit(0)
if check:
    sys.exit(f"{path} does not match {pubspec} ({name}+{code}): run python3 scripts/fdroid_version.py")
open(path, "w").write(new)
print(f"{path}: {name}+{code}")
