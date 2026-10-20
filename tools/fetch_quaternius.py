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

# Each pack: the zip asset on the release, its itch page, where it is used,
# and what to take out of it —
#   "files":   paths copied as shipped (a rigged .glb/.fbx also gets the
#              retarget .import when "retarget" names its skeleton and map);
#   "obj":     OBJ models converted to one .glb each with trimesh: textures
#              bound by material name ("textures", from the pack's texture
#              folder; "cutout" materials get alpha-mask, double-sided), or
#              the MTL colours baked into vertex colours and every part
#              joined into one mesh ("bake_colours") — one draw call a car.
PACKS = {
    "universal-animation-library": {
        "asset": "Universal.Animation.Library.Standard.zip",
        "page": "https://quaternius.itch.io/universal-animation-library",
        "used": "the walk, idle and jog of every rigged human",
        # One GLB holds all 43 clips on the universal rig (no root motion).
        "files": ["Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb"],
        "retarget": ("Armature/Skeleton3D", "res://assets/characters/quaternius_humanoid_map.tres"),
    },
    "universal-base-characters": {
        "asset": "Universal.Base.Characters.Standard.zip",
        "page": "https://quaternius.itch.io/universal-base-characters",
        "used": "the people: two bodies and eight hairstyles, one look per character",
        # The same universal rig as the animation library above, so the walk,
        # the idle and the jog play on these without a second retarget map.
        # Owner review 2026-10-20: "I hope for everybody who knew not use the
        # same kind of characters" — the Kenney body with a swapped texture
        # was every person in the game.
        "files": [
            "Universal Base Characters[Standard]/Base Characters/Godot - UE/Superhero_Male_FullBody.gltf",
            "Universal Base Characters[Standard]/Base Characters/Godot - UE/Superhero_Male_FullBody.bin",
            "Universal Base Characters[Standard]/Base Characters/Godot - UE/Superhero_Female_FullBody.gltf",
            "Universal Base Characters[Standard]/Base Characters/Godot - UE/Superhero_Female_FullBody.bin",
            "Universal Base Characters[Standard]/Base Characters/Textures/T_Superhero_Male_Dark.png",
            "Universal Base Characters[Standard]/Base Characters/Textures/T_Superhero_Male_Ligh.png",
            "Universal Base Characters[Standard]/Base Characters/Textures/T_Superhero_Female_Dark_BaseColor.png",
            "Universal Base Characters[Standard]/Base Characters/Textures/T_Superhero_Female_Light_BaseColor.png",
            "Universal Base Characters[Standard]/Base Characters/Textures/T_Eye_Brown.png",
        ],
        "retarget": ("Armature/Skeleton3D", "res://assets/characters/quaternius_humanoid_map.tres"),
    },
    "universal-base-hair": {
        "asset": "Universal.Base.Characters.Standard.zip",
        "page": "https://quaternius.itch.io/universal-base-characters",
        "used": "hairstyles and beards, one per named character, worn on the head bone",
        # The "Origin at 0" cut, not the rigged one: a BoneAttachment3D on the
        # body's head bone carries a plain mesh, and the rigged version would
        # bring a second Skeleton3D into every person.
        "files": [
            "Universal Base Characters[Standard]/Hairstyles/Origin at 0/glTF (Godot)/Hair_Beard.gltf",
            "Universal Base Characters[Standard]/Hairstyles/Origin at 0/glTF (Godot)/Hair_Beard.bin",
            "Universal Base Characters[Standard]/Hairstyles/Origin at 0/glTF (Godot)/Hair_Buns.gltf",
            "Universal Base Characters[Standard]/Hairstyles/Origin at 0/glTF (Godot)/Hair_Buns.bin",
            "Universal Base Characters[Standard]/Hairstyles/Origin at 0/glTF (Godot)/Hair_Buzzed.gltf",
            "Universal Base Characters[Standard]/Hairstyles/Origin at 0/glTF (Godot)/Hair_Buzzed.bin",
            "Universal Base Characters[Standard]/Hairstyles/Origin at 0/glTF (Godot)/Hair_BuzzedFemale.gltf",
            "Universal Base Characters[Standard]/Hairstyles/Origin at 0/glTF (Godot)/Hair_BuzzedFemale.bin",
            "Universal Base Characters[Standard]/Hairstyles/Origin at 0/glTF (Godot)/Hair_Long.gltf",
            "Universal Base Characters[Standard]/Hairstyles/Origin at 0/glTF (Godot)/Hair_Long.bin",
            "Universal Base Characters[Standard]/Hairstyles/Origin at 0/glTF (Godot)/Hair_SimpleParted.gltf",
            "Universal Base Characters[Standard]/Hairstyles/Origin at 0/glTF (Godot)/Hair_SimpleParted.bin",
            "Universal Base Characters[Standard]/Hairstyles/Origin at 0/glTF (Godot)/T_Hair_1_BaseColor.png",
            "Universal Base Characters[Standard]/Hairstyles/Origin at 0/glTF (Godot)/T_Hair_2_BaseColor.png",
        ],
    },
    "textured-stylized-trees": {
        "asset": "Textured.Stylized.Trees.-.May.2020.zip",
        "page": "https://quaternius.itch.io/textured-lowpoly-trees",
        "used": "trees along the pavements",
        "obj": {
            "dir": "Textured Stylized Trees - May 2020/OBJ/",
            "texture_dir": "Textured Stylized Trees - May 2020/Textures/",
            "models": ["Tree_1", "Tree_3", "Tree_5", "Birch_1", "Birch_4", "Pine_2"],
            # The pack's blue, cyan, pink and purple leaves stay out (GDD §10).
            "textures": {
                "Bark": "Tree_Bark.jpg",
                "Tree_Leaves": "Tree_Leaves.png",
                "Birch_Bark": "Birch_Bark.png",
                "Birch_Leaves": "Birch_Leaves_Green.png",
                "Pine_Leaves": "Pine_Leaves.png",
            },
            "cutout": ["Tree_Leaves", "Birch_Leaves", "Pine_Leaves"],
        },
    },
    "realistic-car-pack": {
        "asset": "Realistic.Car.Pack.-.Nov.2018-20261020T041719Z-1-001.zip",
        "page": "https://quaternius.itch.io/lowpoly-cars",
        "used": "vehicles on the road and parked at the kerb",
        "obj": {
            "dir": "Realistic Car Pack - Nov 2018/OBJ/",
            "models": ["NormalCar1", "NormalCar2", "SUV", "Taxi", "SportsCar", "SportsCar2"],
            "bake_colours": True,
        },
    },
}
# Blender's OBJ exporter writes Kd as 0.8 x the base colour; undone here.
MTL_KD_SCALE = 1.25
USER_AGENT = "b2k-poc-android fetch_quaternius.py (https://github.com/hkht-dev/b2k-poc-android)"


def fetch(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=600) as response:
        return response.read()


def register_row(pack: str, name: str, page: str, used: str, path: Path, processing: str) -> None:
    text = REGISTER.read_text() if REGISTER.exists() else ""
    marker = f"| `quaternius/{pack}/{name}` |"
    row = (
        f"{marker} model | {page} | {LICENCE} | {dt.date.today().isoformat()} | {used} | "
        f"`{path.relative_to(ROOT)}` | {processing} |\n"
    )
    lines = [l for l in text.splitlines(keepends=True) if not l.startswith(marker)]
    REGISTER.write_text("".join(lines) + row)


def convert_obj(archive: zipfile.ZipFile, spec: dict, model: str, out: Path) -> str:
    """One OBJ (with its MTL and, if named, textures) to one .glb. Returns
    the processing note for the register."""
    import tempfile  # noqa: PLC0415

    import numpy as np  # noqa: PLC0415
    import trimesh  # noqa: PLC0415 — optional, fetch only
    from PIL import Image  # noqa: PLC0415

    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        for ext in (".obj", ".mtl"):
            (work / f"{model}{ext}").write_bytes(archive.read(f"{spec['dir']}{model}{ext}"))
        scene = trimesh.load(work / f"{model}.obj", force="scene")
        if spec.get("bake_colours"):
            parts = []
            for geom in scene.geometry.values():
                colour = np.asarray(geom.visual.material.diffuse, dtype=np.float64)[:3]
                colour = np.clip(colour * MTL_KD_SCALE, 0, 255).astype(np.uint8)
                mesh = trimesh.Trimesh(geom.vertices, geom.faces, process=False)
                mesh.visual = trimesh.visual.ColorVisuals(
                    mesh, vertex_colors=np.tile(np.append(colour, 255), (len(mesh.vertices), 1))
                )
                parts.append(mesh)
            merged = trimesh.util.concatenate(parts)
            result = trimesh.Scene()
            result.add_geometry(merged, geom_name=model)
            note = "OBJ; MTL colours baked into vertex colours, parts joined into one mesh; .glb"
        else:
            result = trimesh.Scene()
            images = {}
            for geom_name, geom in scene.geometry.items():
                material_name = getattr(geom.visual.material, "name", geom_name)
                texture = spec["textures"].get(material_name)
                if texture is None:
                    raise SystemExit(f"fetch_quaternius: {model} material '{material_name}' has no texture named")
                if texture not in images:
                    data = archive.read(f"{spec['texture_dir']}{texture}")
                    images[texture] = Image.open(io.BytesIO(data)).convert("RGBA")
                cutout = material_name in spec.get("cutout", [])
                material = trimesh.visual.material.PBRMaterial(
                    baseColorTexture=images[texture],
                    metallicFactor=0.0,
                    roughnessFactor=0.95,
                    alphaMode="MASK" if cutout else "OPAQUE",
                    doubleSided=cutout,
                    name=material_name,
                )
                mesh = trimesh.Trimesh(geom.vertices, geom.faces, process=False)
                mesh.visual = trimesh.visual.TextureVisuals(uv=geom.visual.uv, material=material)
                result.add_geometry(mesh, geom_name=f"{model}_{material_name}")
            note = "OBJ; textures bound by material name (" + ", ".join(
                sorted(set(spec["textures"].values()))) + "); leaves alpha-masked, double-sided; .glb"
        out.write_bytes(result.export(file_type="glb", include_normals=True))
    return note


def unpack(pack: str, archive: zipfile.ZipFile) -> int:
    spec = PACKS[pack]
    pack_dir = OUT / pack
    pack_dir.mkdir(parents=True, exist_ok=True)
    licence = next((n for n in archive.namelist() if "license" in n.lower()), None)
    if licence:
        (pack_dir / "LICENSE.txt").write_bytes(archive.read(licence))
    problems = 0
    for rel in spec.get("files", []):
        if rel not in archive.namelist():
            print(f"fetch_quaternius: {spec['asset']} has no '{rel}'", file=sys.stderr)
            problems += 1
            continue
        path = pack_dir / Path(rel).name
        path.write_bytes(archive.read(rel))
        note = f"as shipped ({rel})"
        if spec.get("retarget") and path.suffix in (".glb", ".gltf", ".fbx"):
            write_retarget_import(ROOT, path, *spec["retarget"])
            note += "; retargeted onto the humanoid profile at import"
        register_row(pack, Path(rel).stem, spec["page"], spec["used"], path, note)
        print(f"fetch_quaternius: {pack}/{path.name} ({path.stat().st_size // 1024} KB)")
    obj = spec.get("obj")
    for model in (obj or {}).get("models", []):
        if f"{obj['dir']}{model}.obj" not in archive.namelist():
            print(f"fetch_quaternius: {spec['asset']} has no '{obj['dir']}{model}.obj'", file=sys.stderr)
            problems += 1
            continue
        path = pack_dir / f"{model}.glb"
        note = convert_obj(archive, obj, model, path)
        register_row(pack, model, spec["page"], spec["used"], path, note)
        print(f"fetch_quaternius: {pack}/{path.name} ({path.stat().st_size // 1024} KB)")
    return problems


def expected_files() -> list[tuple[str, str]]:
    """(pack, file name) for everything the packs above produce."""
    out = []
    for pack, spec in PACKS.items():
        out += [(pack, Path(rel).name) for rel in spec.get("files", [])]
        out += [(pack, f"{model}.glb") for model in spec.get("obj", {}).get("models", [])]
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--from", dest="local", help="a local copy of the pack's zip")
    parser.add_argument("pack", nargs="?", help="with --from: which pack the zip is")
    args = parser.parse_args()
    problems = 0
    if args.check:
        for pack, name in expected_files():
            if not (OUT / pack / name).exists():
                print(f"fetch_quaternius: missing {pack}/{name}", file=sys.stderr)
                problems += 1
        if not problems:
            print(f"fetch_quaternius: {len(expected_files())} files present")
        return 1 if problems else 0
    if args.local:
        if args.pack not in PACKS:
            parser.error(f"name the pack: {', '.join(PACKS)}")
        return unpack(args.pack, zipfile.ZipFile(args.local))
    for pack, spec in PACKS.items():
        print(f"fetch_quaternius: downloading {spec['asset']} from the release")
        problems += unpack(pack, zipfile.ZipFile(io.BytesIO(fetch(f"{RELEASE}/{spec['asset']}"))))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
