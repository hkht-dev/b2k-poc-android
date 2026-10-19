#!/usr/bin/env python3
"""Fetch named CC0 assets from Poly Haven, register them, and stylise them.

docs/BRIEF_AMENDMENT_1.md §B2 allows CC0 libraries (Poly Haven among them) on
two conditions: every imported asset gets a row in docs/RIGHTS_REGISTER.md,
and nothing from any other licence ships. This script is the only way a Poly
Haven file enters the repository, so both conditions are met by construction.

    python3 tools/fetch_polyhaven.py            # fetch the list below
    python3 tools/fetch_polyhaven.py --check    # fail if any file is missing

Textures: the 1K Diffuse JPG only — albedo is all the game uses — run through
the painted-look pass in tools/gen_textures.py (stylise) and saved as PNG.
HDRIs: the 1K .hdr as-is, for the sky.
"""

from __future__ import annotations

import argparse
import datetime as dt
import io
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_textures import stylise  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "thirdparty" / "polyhaven"
REGISTER = ROOT / "docs" / "RIGHTS_REGISTER.md"
API = "https://api.polyhaven.com"
LICENCE = "CC0 1.0 (https://polyhaven.com/license)"

# (asset id, kind, where it is used in the slice)
ASSETS = [
    ("overcast_soil_puresky", "hdri", "Street sky (WorldEnvironment)"),
    ("asphalt_02", "texture", "the two roads"),
    ("concrete_wall_001", "texture", "pavements, kerbs, the fountain stone"),
    ("clay_plaster", "texture", "rendered walls on the flats and the shop"),
    ("brick_wall_001", "texture", "exposed brick flats and the tower base"),
    ("corrugated_iron", "texture", "roofs of the shop and the chai stall"),
]
RES = "1k"


# Poly Haven's CDN refuses the default Python user agent.
USER_AGENT = "b2k-poc-android fetch_polyhaven.py (https://github.com/hkht-dev/b2k-poc-android)"


def fetch_bytes(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=300) as r:
            return r.read()
    except urllib.error.HTTPError as error:
        if error.code != 403:
            raise
    # Some proxies only pass curl through; it honours the same proxy settings.
    import subprocess
    return subprocess.run(
        ["curl", "-sSL", "--fail", "-A", USER_AGENT, url], check=True, capture_output=True
    ).stdout


def fetch_json(url: str) -> dict:
    return json.loads(fetch_bytes(url).decode("utf-8"))


def texture_url(files: dict) -> str | None:
    for key in ("Diffuse", "diffuse", "Albedo", "albedo", "diff"):
        if key in files and RES in files[key] and "jpg" in files[key][RES]:
            return files[key][RES]["jpg"]["url"]
    return None


def register_row(asset: str, kind: str, source: str, used: str, path: Path) -> None:
    REGISTER.parent.mkdir(parents=True, exist_ok=True)
    if not REGISTER.exists():
        REGISTER.write_text(
            "# Rights register\n\n"
            "Every third-party asset in the repository, as docs/BRIEF_AMENDMENT_1.md §B2\n"
            "requires: source, licence, date, where used. Rows are written by the tool\n"
            "that fetched the asset; do not add files to assets/thirdparty/ by hand.\n\n"
            "| Asset | Kind | Source | Licence | Fetched | Used for | File | Processing |\n"
            "|---|---|---|---|---|---|---|---|\n"
        )
    text = REGISTER.read_text()
    marker = f"| `{asset}` |"
    processing = "none" if kind == "hdri" else "1K Diffuse only; gen_textures.stylise() albedo pass; PNG"
    row = (
        f"{marker} {kind} | {source} | {LICENCE} | {dt.date.today().isoformat()} | {used} | "
        f"`{path.relative_to(ROOT)}` | {processing} |\n"
    )
    lines = [l for l in text.splitlines(keepends=True) if not l.startswith(marker)]
    REGISTER.write_text("".join(lines) + row)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    problems = 0
    for asset, kind, used in ASSETS:
        ext = "hdr" if kind == "hdri" else "png"
        path = OUT / f"{asset}.{ext}"
        if args.check:
            if not path.exists():
                print(f"fetch_polyhaven: missing {path.relative_to(ROOT)}", file=sys.stderr)
                problems += 1
            continue
        files = fetch_json(f"{API}/files/{asset}")
        source = f"https://polyhaven.com/a/{asset}"
        if kind == "hdri":
            url = files["hdri"][RES]["hdr"]["url"]
            path.write_bytes(fetch_bytes(url))
        else:
            url = texture_url(files)
            if url is None:
                print(f"fetch_polyhaven: {asset} has no {RES} diffuse JPG; keys {list(files)}", file=sys.stderr)
                problems += 1
                continue
            img = Image.open(io.BytesIO(fetch_bytes(url))).convert("RGB")
            arr = np.asarray(img).astype(np.float64) / 255.0
            out = (stylise(arr, strength=1.0) * 255).astype(np.uint8)
            Image.fromarray(out, "RGB").save(path, format="PNG", optimize=True)
        register_row(asset, kind, source, used, path)
        print(f"fetch_polyhaven: {asset} -> {path.relative_to(ROOT)} ({path.stat().st_size // 1024} KB)")
    if args.check:
        if problems:
            return 1
        print(f"fetch_polyhaven: {len(ASSETS)} assets present")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
