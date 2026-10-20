"""Write Godot's retarget settings into a model's .import file.

Shared by the fetch tools. A body or clip imported through a BoneMap onto
Godot's SkeletonProfileHumanoid gets the profile's bone names, so a clip
from one rig plays on a body from another (scripts/characters/
character_rig.gd). `fix_silhouette` is required: with the map alone the
clips rolled the arms about their length axis (docs/DECISIONS.md).
"""

from __future__ import annotations

import hashlib
from pathlib import Path

SUBRESOURCES = """_subresources={
"nodes": {
"PATH:%(skeleton)s": {
"retarget/bone_map": Resource("%(bone_map)s"),
"retarget/rest_fixer/fix_silhouette/enable": true
}
}
}"""

TEMPLATE = """[remap]

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
%(format_lines)s
"""

FORMAT_LINES = {
    ".fbx": "fbx/importer=0\nfbx/allow_geometry_helper_nodes=false\nfbx/embedded_image_handling=1",
    ".glb": "gltf/naming_version=1\ngltf/embedded_image_handling=1",
    ".gltf": "gltf/naming_version=1\ngltf/embedded_image_handling=1",
}


def write_retarget_import(root: Path, path: Path, skeleton: str, bone_map: str) -> None:
    """Make `path`'s .import retarget the skeleton node `skeleton` through the
    BoneMap resource at `bone_map`. An existing .import keeps its uid and
    everything else; only the `_subresources` block is replaced. A missing
    one is written whole (Godot adds the uid on the next import)."""
    sub = SUBRESOURCES % {"skeleton": skeleton, "bone_map": bone_map}
    import_path = path.with_name(path.name + ".import")
    if import_path.exists():
        text = import_path.read_text()
        start = text.index("_subresources={")
        depth, end = 0, start
        for end in range(start + len("_subresources="), len(text)):
            depth += {"{": 1, "}": -1}.get(text[end], 0)
            if depth == 0:
                break
        import_path.write_text(text[:start] + sub + text[end + 1:])
        return
    rel = path.relative_to(root).as_posix()
    import_path.write_text(
        TEMPLATE
        % {
            "name": path.name,
            "digest": hashlib.md5(("res://" + rel).encode()).hexdigest(),
            "rel": rel,
            "subresources": sub,
            "format_lines": FORMAT_LINES[path.suffix.lower()],
        }
    )
