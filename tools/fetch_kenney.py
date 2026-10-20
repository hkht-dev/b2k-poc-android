#!/usr/bin/env python3
"""Fetch named CC0 model kits from kenney.nl, keep the files we use, register them.

docs/BRIEF_AMENDMENT_1.md §B2: Kenney is an allowed CC0 source; every imported
asset gets a row in docs/RIGHTS_REGISTER.md. This script is the only way a
Kenney file enters the repository.

Kenney's download link is a hashed path printed in the kit's page, so the
script reads the page, finds `kenney_<kit>.zip`, downloads it, and copies only
the listed GLB models (plus the kit's licence file) into
assets/thirdparty/kenney/<kit>/. The zip itself is not kept.

    python3 tools/fetch_kenney.py            # fetch the kits below
    python3 tools/fetch_kenney.py --check    # fail if any listed file is missing
"""

from __future__ import annotations

import argparse
import datetime as dt
import io
import json
import re
import struct
import sys
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "thirdparty" / "kenney"
REGISTER = ROOT / "docs" / "RIGHTS_REGISTER.md"
LICENCE = "CC0 1.0 (https://kenney.nl/license)"
USER_AGENT = "b2k-poc-android fetch_kenney.py (https://github.com/hkht-dev/b2k-poc-android)"

# kit slug -> (models to keep: basename without extension, where used)
# kit -> (models, where used, join parts into one mesh). The car kit's body
# and wheels share one material, so joining them costs nothing and saves four
# draw calls a car; the nature kit's two materials stay two surfaces.
KITS = {
    "car-kit": (
        ["sedan", "hatchback-sports", "taxi", "van", "truck", "suv", "delivery"],
        "vehicles on the road and parked at the kerb",
        True,
    ),
    "nature-kit": (
        ["tree_default", "tree_oak", "tree_tall", "tree_simple", "plant_bushLarge", "plant_bush"],
        "trees and bushes along the pavements",
        False,
    ),
}


def fetch(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=300) as r:
        return r.read()


def zip_url(kit: str) -> str:
    page = fetch(f"https://kenney.nl/assets/{kit}").decode("utf-8", "replace")
    match = re.search(rf"https://kenney\.nl/media/pages/assets/{kit}/[^'\"]+/kenney_{kit}\.zip", page)
    if not match:
        raise RuntimeError(f"fetch_kenney: no zip link on the {kit} page")
    return match.group(0)


# Files taken as shipped from a kit, by their path inside the zip:
# kit -> (paths, where used, retarget). Kenney's animated characters are FBX
# (a body, clips, skin PNGs); Godot 4.3 imports FBX natively, so they stay
# FBX. `retarget` names the skeleton node inside each FBX and the BoneMap
# that maps its bones onto Godot's humanoid profile; the tool writes that
# into the file's .import so a clip from another rig plays on the body.
FILES = {
    "animated-characters-retro": (
        [
            "Model/characterMedium.fbx",
            "Animations/idle.fbx",
            "Animations/run.fbx",
            "Animations/jump.fbx",
            "Skins/humanMaleA.png",
            "Skins/humanFemaleA.png",
        ],
        "the player, pedestrians and Tulu: rigged body, clips, skins",
        ("Root/Skeleton3D", "res://assets/characters/kenney_humanoid_map.tres"),
    ),
}

# Retarget options written into a model's .import (Godot's scene importer,
# "retarget/..." on the skeleton node). fix_silhouette is what makes a clip
# from one rig read correctly on another: without it Kenney's own clips
# came out rolling the arms about their length (docs/DECISIONS.md).
RETARGET_SUBRESOURCES = '''_subresources={
"nodes": {
"PATH:%(skeleton)s": {
"retarget/bone_map": Resource("%(bone_map)s"),
"retarget/rest_fixer/fix_silhouette/enable": true
}
}
}'''

IMPORT_TEMPLATE = '''[remap]

importer="scene"
importer_version=1
type="PackedScene"
path="res://.godot/imported/%(name)s-%(digest)s.scn"

[deps]

source_file="res://%(rel)s"
dest_files=["res://.godot/imported/%(name)s-%(digest)s.scn"]

[params]

nodes/root_type=""
nodes/root_name=""
nodes/apply_root_scale=true
nodes/root_scale=1.0
nodes/import_as_skeleton_bones=false
meshes/ensure_tangents=true
meshes/generate_lods=true
meshes/create_shadow_meshes=true
meshes/light_baking=1
meshes/lightmap_texel_size=0.2
meshes/force_disable_compression=false
skins/use_named_skins=true
animation/import=true
animation/fps=30
animation/trimming=true
animation/remove_immutable_tracks=true
animation/import_rest_as_RESET=false
import_script/path=""
%(subresources)s
fbx/importer=0
fbx/allow_geometry_helper_nodes=false
fbx/embedded_image_handling=1
'''


def write_retarget_import(path: Path, skeleton: str, bone_map: str) -> None:
    """Make the model's .import retarget its skeleton through `bone_map`.
    An existing .import keeps its uid and everything else; only the
    `_subresources` block is replaced. A missing one is written whole (Godot
    adds the uid on the next import)."""
    import hashlib  # noqa: PLC0415

    sub = RETARGET_SUBRESOURCES % {"skeleton": skeleton, "bone_map": bone_map}
    import_path = path.with_name(path.name + ".import")
    if import_path.exists():
        text = import_path.read_text()
        start = text.index("_subresources={")
        depth, end = 0, start + len("_subresources=")
        for end in range(start + len("_subresources="), len(text)):
            depth += {"{": 1, "}": -1}.get(text[end], 0)
            if depth == 0:
                break
        import_path.write_text(text[:start] + sub + text[end + 1:])
        return
    rel = path.relative_to(ROOT).as_posix()
    digest = hashlib.md5(("res://" + rel).encode()).hexdigest()
    import_path.write_text(
        IMPORT_TEMPLATE % {"name": path.name, "digest": digest, "rel": rel, "subresources": sub}
    )

# Kenney's palette has a turquoise foliage green; GDD §10 forbids peacock blue
# in the Street, so leaves are set to a dull olive on the way in. Material
# name -> linear RGBA baseColorFactor.
RECOLOUR = {
    "leafsGreen": (0.33, 0.47, 0.22, 1.0),
    "leafsDark": (0.26, 0.38, 0.18, 1.0),
}


def recolour(path: Path) -> list[str]:
    """Rewrite named materials' base colour inside a .glb; returns the names
    it changed. A GLB is a 12-byte header, a JSON chunk, then binary chunks."""
    raw = bytearray(path.read_bytes())
    assert raw[:4] == b"glTF", path
    json_len = struct.unpack_from("<I", raw, 12)[0]
    assert raw[16:20] == b"JSON"
    data = json.loads(raw[20:20 + json_len])
    changed = []
    for material in data.get("materials", []):
        if material.get("name") in RECOLOUR:
            material.setdefault("pbrMetallicRoughness", {})["baseColorFactor"] = list(RECOLOUR[material["name"]])
            changed.append(material["name"])
    if not changed:
        return changed
    body = json.dumps(data, separators=(",", ":")).encode()
    body += b" " * (-len(body) % 4)
    rest = raw[20 + json_len:]
    out = bytearray(b"glTF") + struct.pack("<II", 2, 12 + 8 + len(body) + len(rest))
    out += struct.pack("<I", len(body)) + b"JSON" + body + rest
    path.write_bytes(out)
    return changed


def merge(path: Path) -> int:
    """Join a model's parts into one mesh (same material throughout, as the
    car kit is: a body and four wheels become one draw call). Returns how
    many parts were joined; 0 or 1 leaves the file as shipped. Needs
    `trimesh` (pip); --check does not."""
    import trimesh  # noqa: PLC0415 — optional, fetch only

    scene = trimesh.load(path, force="scene")
    meshes = scene.dump()  # node transforms applied
    if len(meshes) < 2:
        return len(meshes)
    merged = trimesh.util.concatenate(meshes)
    merged.visual.material = meshes[0].visual.material
    out = trimesh.Scene()
    out.add_geometry(merged, geom_name=path.stem)
    path.write_bytes(out.export(file_type="glb", include_normals=True))
    return len(meshes)


def register_row(kit: str, model: str, used: str, path: Path, processing: str = "GLB as shipped") -> None:
    text = REGISTER.read_text() if REGISTER.exists() else ""
    marker = f"| `kenney/{kit}/{model}` |"
    row = (
        f"{marker} model | https://kenney.nl/assets/{kit} | {LICENCE} | "
        f"{dt.date.today().isoformat()} | {used} | `{path.relative_to(ROOT)}` | {processing} |\n"
    )
    lines = [l for l in text.splitlines(keepends=True) if not l.startswith(marker)]
    REGISTER.write_text("".join(lines) + row)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    problems = 0
    for kit, (models, used, merge_parts) in KITS.items():
        kit_dir = OUT / kit
        if args.check:
            for model in models:
                if not (kit_dir / f"{model}.glb").exists():
                    print(f"fetch_kenney: missing {kit}/{model}.glb", file=sys.stderr)
                    problems += 1
            continue
        kit_dir.mkdir(parents=True, exist_ok=True)
        archive = zipfile.ZipFile(io.BytesIO(fetch(zip_url(kit))))
        names = archive.namelist()
        glbs = {Path(n).stem: n for n in names if n.lower().endswith(".glb")}
        for licence in (n for n in names if Path(n).name.lower().startswith("license")):
            (kit_dir / "LICENSE.txt").write_bytes(archive.read(licence))
            break
        for model in models:
            if model not in glbs:
                close = [k for k in glbs if model.split("_")[0] in k][:5]
                print(f"fetch_kenney: {kit} has no '{model}.glb'; similar: {close}", file=sys.stderr)
                problems += 1
                continue
            path = kit_dir / f"{model}.glb"
            path.write_bytes(archive.read(glbs[model]))
            steps = []
            if merge_parts:
                joined = merge(path)
                if joined > 1:
                    steps.append(f"{joined} parts joined into one mesh")
            changed = recolour(path)
            if changed:
                steps.append("base colour of " + ", ".join(changed) + " set to the Hollow Vale palette (RECOLOUR)")
            processing = "GLB as shipped" if not steps else "GLB; " + "; ".join(steps)
            register_row(kit, model, used, path, processing)
            print(f"fetch_kenney: {kit}/{model}.glb ({path.stat().st_size // 1024} KB)")
    for kit, (paths, used, retarget) in FILES.items():
        kit_dir = OUT / kit
        if args.check:
            for rel in paths:
                if not (kit_dir / Path(rel).name).exists():
                    print(f"fetch_kenney: missing {kit}/{Path(rel).name}", file=sys.stderr)
                    problems += 1
            continue
        archive = zipfile.ZipFile(io.BytesIO(fetch(zip_url(kit))))
        kit_dir.mkdir(parents=True, exist_ok=True)
        licence = next((n for n in archive.namelist() if n.lower().endswith("license.txt")), None)
        if licence:
            (kit_dir / "LICENSE.txt").write_bytes(archive.read(licence))
        for rel in paths:
            path = kit_dir / Path(rel).name
            path.write_bytes(archive.read(rel))
            processing = f"as shipped ({rel})"
            if retarget and path.suffix == ".fbx":
                write_retarget_import(path, *retarget)
                processing += "; retargeted onto the humanoid profile at import"
            register_row(kit, Path(rel).stem, used, path, processing)
            print(f"fetch_kenney: {kit}/{path.name} ({path.stat().st_size // 1024} KB)")
    if args.check and not problems:
        total = sum(len(m) for m, _, _ in KITS.values()) + sum(len(f) for f, _, _ in FILES.values())
        print(f"fetch_kenney: {total} files present")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
