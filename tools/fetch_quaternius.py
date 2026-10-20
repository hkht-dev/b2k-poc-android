#!/usr/bin/env python3
"""Fetch named CC0 Quaternius packs from this repository's own release, register them.

Quaternius' packs are CC0 but hosted on itch.io, which only serves downloads
to a browser. The owner downloads a pack and attaches the zip, unmodified,
to the GitHub release `quaternius-packs-2026-10-20` of this repository; this
script takes the listed files out of that zip into assets/thirdparty/
quaternius/<pack>/ and writes their rows in docs/RIGHTS_REGISTER.md, so the
two conditions of docs/BRIEF_AMENDMENT_1.md §B2 hold by construction.

    python3 tools/fetch_quaternius.py            # fetch every pack below
    python3 tools/fetch_quaternius.py --check    # fail if any file is missing
    python3 tools/fetch_quaternius.py --from pack.zip universal-animation-library
                                                 # unpack a local copy instead
"""

from __future__ import annotations

import argparse
import datetime as dt
import io
import sys
import urllib.request
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from retarget_import import write_retarget_import  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "thirdparty" / "quaternius"
REGISTER = ROOT / "docs" / "RIGHTS_REGISTER.md"
LICENCE = "CC0 1.0 (License_Standard.txt in the pack; https://quaternius.com)"
RELEASE = "https://github.com/hkht-dev/b2k-poc-android/releases/download/quaternius-packs-2026-10-20"

# pack -> (zip asset name on the release, itch page, [paths inside the zip],
#          where used, retarget (skeleton node, BoneMap) for .glb/.fbx files)
PACKS = {
    "universal-animation-library": (
        "Universal.Animation.Library.Standard.zip",
        "https://quaternius.itch.io/universal-animation-library",
        # One GLB holds all 43 clips on the universal rig (no root motion).
        ["Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb"],
        "the walk, idle and jog of every rigged human",
        ("Armature/Skeleton3D", "res://assets/characters/quaternius_humanoid_map.tres"),
    ),
}
USER_AGENT = "b2k-poc-android fetch_quaternius.py (https://github.com/hkht-dev/b2k-poc-android)"


def fetch(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=600) as response:
        return response.read()


def register_row(pack: str, name: str, page: str, used: str, path: Path, rel: str) -> None:
    text = REGISTER.read_text() if REGISTER.exists() else ""
    marker = f"| `quaternius/{pack}/{name}` |"
    row = (
        f"{marker} model | {page} | {LICENCE} | {dt.date.today().isoformat()} | {used} | "
        f"`{path.relative_to(ROOT)}` | as shipped ({rel}); retargeted onto the humanoid profile at import |\n"
    )
    lines = [l for l in text.splitlines(keepends=True) if not l.startswith(marker)]
    REGISTER.write_text("".join(lines) + row)


def unpack(pack: str, archive: zipfile.ZipFile) -> int:
    asset, page, paths, used, retarget = PACKS[pack]
    pack_dir = OUT / pack
    pack_dir.mkdir(parents=True, exist_ok=True)
    licence = next((n for n in archive.namelist() if "license" in n.lower()), None)
    if licence:
        (pack_dir / "LICENSE.txt").write_bytes(archive.read(licence))
    problems = 0
    for rel in paths:
        if rel not in archive.namelist():
            print(f"fetch_quaternius: {asset} has no '{rel}'", file=sys.stderr)
            problems += 1
            continue
        path = pack_dir / Path(rel).name
        path.write_bytes(archive.read(rel))
        if retarget and path.suffix in (".glb", ".gltf", ".fbx"):
            write_retarget_import(ROOT, path, *retarget)
        register_row(pack, Path(rel).stem, page, used, path, rel)
        print(f"fetch_quaternius: {pack}/{path.name} ({path.stat().st_size // 1024} KB)")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--from", dest="local", help="a local copy of the pack's zip")
    parser.add_argument("pack", nargs="?", help="with --from: which pack the zip is")
    args = parser.parse_args()
    problems = 0
    if args.check:
        for pack, (_, _, paths, _, _) in PACKS.items():
            for rel in paths:
                if not (OUT / pack / Path(rel).name).exists():
                    print(f"fetch_quaternius: missing {pack}/{Path(rel).name}", file=sys.stderr)
                    problems += 1
        if not problems:
            print(f"fetch_quaternius: {sum(len(p[2]) for p in PACKS.values())} files present")
        return 1 if problems else 0
    if args.local:
        if args.pack not in PACKS:
            parser.error(f"name the pack: {', '.join(PACKS)}")
        return unpack(args.pack, zipfile.ZipFile(args.local))
    for pack, (asset, _, _, _, _) in PACKS.items():
        print(f"fetch_quaternius: downloading {asset} from the release")
        problems += unpack(pack, zipfile.ZipFile(io.BytesIO(fetch(f"{RELEASE}/{asset}"))))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
