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
Models: the 1K GLTF, reduced to what the game renders — albedo only (512 px,
stylised), the mesh decimated to the triangle budget in MODEL_TRIANGLES — and
written as one .glb per model. Decimation needs `trimesh` and
`fast-simplification` (pip); --check needs neither.
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
    # Models: 1K GLTF with its bin and textures, kept under models/<id>/.
    ("street_lamp_01", "model", "lamp posts along the pavements"),
    ("modular_street_seating", "model", "the bus stop bench"),
    ("fire_hydrant", "model", "pavement dressing"),
    ("covered_car", "model", "a car under a tarp at the kerb"),
    ("can_rusted", "model", "litter"),
    ("plastic_crate_01", "model", "stacked outside the shop"),
    ("water_manhole_cover", "model", "road dressing"),
]
RES = "1k"

# Triangle budget per model after decimation. Amendment §C allows 150k per
# frame for the whole street; a prop that appears many times must be cheap.
MODEL_TRIANGLES = {
    "street_lamp_01": 1500,
    "modular_street_seating": 2500,
    "fire_hydrant": 2500,
    "covered_car": 3000,
    "can_rusted": 400,
    "plastic_crate_01": 1200,
    "water_manhole_cover": 600,
}


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


MODEL_TEXTURE_PX = 512


def prune_model(gltf_path: Path) -> None:
    """Keep what the game renders: geometry and albedo.

    The slice ships no normal, roughness or occlusion maps (docs/DECISIONS.md),
    so those references are removed from the GLTF and their files deleted;
    the albedo is downscaled to 512 px and run through the painted pass so a
    photoscanned prop sits in the same register as the generated surfaces.
    """
    data = json.loads(gltf_path.read_text())
    for material in data.get("materials", []):
        material.pop("normalTexture", None)
        material.pop("occlusionTexture", None)
        pbr = material.get("pbrMetallicRoughness", {})
        pbr.pop("metallicRoughnessTexture", None)
        pbr.setdefault("metallicFactor", 0.0)
        pbr.setdefault("roughnessFactor", 0.95)
    used_textures = set()
    for material in data.get("materials", []):
        base = material.get("pbrMetallicRoughness", {}).get("baseColorTexture")
        if base is not None:
            used_textures.add(base["index"])
    used_images = {data["textures"][i]["source"] for i in used_textures if "textures" in data}
    kept_images = []
    remap = {}
    for index, image in enumerate(data.get("images", [])):
        uri = image.get("uri", "")
        file = gltf_path.parent / uri
        if index in used_images:
            remap[index] = len(kept_images)
            kept_images.append(image)
            if file.exists():
                img = Image.open(file).convert("RGB")
                if max(img.size) > MODEL_TEXTURE_PX:
                    img.thumbnail((MODEL_TEXTURE_PX, MODEL_TEXTURE_PX))
                arr = np.asarray(img).astype(np.float64) / 255.0
                out = (stylise(arr, strength=0.7) * 255).astype(np.uint8)
                Image.fromarray(out, "RGB").save(file, quality=88)
        elif file.exists():
            file.unlink()
    data["images"] = kept_images
    kept_textures = []
    tex_remap = {}
    for index, texture in enumerate(data.get("textures", [])):
        if index in used_textures:
            texture["source"] = remap[texture["source"]]
            tex_remap[index] = len(kept_textures)
            kept_textures.append(texture)
    data["textures"] = kept_textures
    for material in data.get("materials", []):
        base = material.get("pbrMetallicRoughness", {}).get("baseColorTexture")
        if base is not None:
            base["index"] = tex_remap[base["index"]]
    gltf_path.write_text(json.dumps(data, separators=(",", ":")))


def decimate_to_glb(gltf_path: Path, target: int) -> Path:
    """Decimate every mesh in the GLTF to `target` triangles in total, keep
    its albedo UVs, and write one .glb beside it; the GLTF, bin and loose
    textures are then deleted. Returns the .glb path."""
    import fast_simplification as fs  # noqa: PLC0415 — optional, fetch only
    import trimesh  # noqa: PLC0415

    scene = trimesh.load(gltf_path, force="scene")
    total = sum(len(g.faces) for g in scene.geometry.values())
    out = trimesh.Scene()
    materials: dict[bytes, object] = {}  # one material per distinct albedo
    for name, geom in scene.geometry.items():
        share = max(1, int(target * len(geom.faces) / max(total, 1)))
        verts = np.asarray(geom.vertices, dtype=np.float64)
        faces = np.asarray(geom.faces, dtype=np.int64)
        visual = geom.visual
        uv = np.asarray(visual.uv) if hasattr(visual, "uv") and visual.uv is not None else None
        # One pass stops short of a deep target (the library's quality floor),
        # so pass again on the result until the budget is met or it stalls.
        # Gentle aggressiveness: at 7+ a thin post loses its bottom metre.
        for attempt in range(8):
            if len(faces) <= share:
                break
            agg = 3 if attempt < 4 or len(faces) < 1.5 * share else 5
            _, _, collapses = fs.simplify(verts, faces, target_count=share, agg=agg, return_collapses=True)
            new_verts, new_faces, mapping = fs.replay_simplification(verts, faces, collapses)
            if len(new_faces) >= len(faces):
                break
            if uv is not None:
                # Each new vertex takes the UV of the first old vertex that
                # collapsed into it (-1 marks a vertex that was dropped);
                # seams may open by a texel, no more.
                kept = mapping >= 0
                new_uv = np.zeros((len(new_verts), 2))
                old_index = np.arange(len(mapping))[kept]
                new_index = mapping[kept]
                # Later writes win in fancy assignment; reverse so the first wins.
                new_uv[new_index[::-1]] = uv[old_index[::-1]]
                uv = new_uv
            verts, faces = new_verts, new_faces
        image = getattr(getattr(visual, "material", None), "baseColorTexture", None)
        if image is None:
            image = getattr(getattr(visual, "material", None), "image", None)
        key = image.tobytes() if image is not None else b""
        if key not in materials:
            materials[key] = trimesh.visual.material.PBRMaterial(
                baseColorTexture=image, metallicFactor=0.0, roughnessFactor=0.95,
                name=f"{gltf_path.parent.name}_{len(materials)}",
            )
        material = materials[key]
        mesh = trimesh.Trimesh(verts, faces, process=False)
        if uv is not None:
            mesh.visual = trimesh.visual.TextureVisuals(uv=uv, material=material)
        for node_name in scene.graph.nodes_geometry:
            if scene.graph[node_name][1] == name:
                out.add_geometry(mesh, node_name=node_name, geom_name=name, transform=scene.graph[node_name][0])
                break
        else:
            out.add_geometry(mesh, geom_name=name)
    glb = gltf_path.parent / f"{gltf_path.parent.name}.glb"
    glb.write_bytes(out.export(file_type="glb", include_normals=True))
    for stale in gltf_path.parent.rglob("*"):
        if stale.is_file() and stale != glb:
            stale.unlink()
    for stale in sorted(gltf_path.parent.rglob("*"), reverse=True):
        if stale.is_dir():
            stale.rmdir()
    return glb


def triangle_count(path: Path) -> int:
    if path.suffix == ".glb":
        import struct  # noqa: PLC0415

        raw = path.read_bytes()
        length = struct.unpack_from("<I", raw, 12)[0]
        data = json.loads(raw[20:20 + length])
    else:
        data = json.loads(path.read_text())
    total = 0
    for mesh in data.get("meshes", []):
        for prim in mesh.get("primitives", []):
            if "indices" in prim:
                total += data["accessors"][prim["indices"]]["count"] // 3
    return total


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
    processing = {
        "hdri": "none",
        "model": "1K GLTF decimated (fast-simplification) to the budget in MODEL_TRIANGLES; albedo only, 512 px, gen_textures.stylise(); normal/roughness maps removed; written as .glb",
    }.get(kind, "1K Diffuse only; gen_textures.stylise() albedo pass; PNG")
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
        if kind == "model":
            path = OUT / "models" / asset / f"{asset}.glb"
        else:
            ext = "hdr" if kind == "hdri" else "png"
            path = OUT / f"{asset}.{ext}"
        if args.check:
            if not path.exists():
                print(f"fetch_polyhaven: missing {path.relative_to(ROOT)}", file=sys.stderr)
                problems += 1
            continue
        files = fetch_json(f"{API}/files/{asset}")
        source = f"https://polyhaven.com/a/{asset}"
        if kind == "model":
            entry = files["gltf"][RES]["gltf"]
            gltf = path.parent / f"{asset}_{RES}.gltf"
            path.parent.mkdir(parents=True, exist_ok=True)
            gltf.write_bytes(fetch_bytes(entry["url"]))
            for rel, inc in entry.get("include", {}).items():
                target = path.parent / rel
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(fetch_bytes(inc["url"]))
            prune_model(gltf)
            assert decimate_to_glb(gltf, MODEL_TRIANGLES[asset]) == path
        elif kind == "hdri":
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
        extra = f", {triangle_count(path)} triangles" if kind == "model" else ""
        print(f"fetch_polyhaven: {asset} -> {path.relative_to(ROOT)} ({path.stat().st_size // 1024} KB{extra})")
    if args.check:
        if problems:
            return 1
        print(f"fetch_polyhaven: {len(ASSETS)} assets present")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
