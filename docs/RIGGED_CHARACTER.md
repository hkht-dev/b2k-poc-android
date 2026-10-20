# Rigged CC0 characters

## Where it stands (2026-10-20)

The player, Tulu and the pedestrians are Kenney's *Animated Characters
Retro* body (CC0, kenney.nl, `tools/fetch_kenney.py`) playing Quaternius'
*Universal Animation Library* clips (CC0, itch.io, `tools/fetch_quaternius.py`):
`Idle`, `Walk` and `Jog_Fwd` out of its 43. Both go through Godot's humanoid
profile at import (`assets/characters/*_humanoid_map.tres`, written into
each file's `.import` by the fetch tools), so the clips of one rig play on
the body of the other; `scripts/characters/character_rig.gd` assembles
them and `scenes/characters/Character.tscn` says which clip is which.

## How a Quaternius pack gets in

Quaternius hosts on itch.io, which only serves downloads to a browser. The
owner downloads a pack and attaches the zip, unmodified, to the GitHub
release `quaternius-packs-2026-10-20` of this repository (issue attachments
are not reachable from the build environment; release assets are). Then
`tools/fetch_quaternius.py` lists the files it takes from the zip, downloads
the asset, writes the retarget `.import` for rigged files and the rows in
`docs/RIGHTS_REGISTER.md`. The release also carries the owner's uploads of
*Universal Base Characters*, *Downtown City MegaKit*, *Realistic Car Pack*
and *Textured Stylized Trees*, all CC0 per their licence files; the city
kit, cars and trees are candidates for the street's buildings and dressing
in a later PR.

## Rules that still bind

`docs/BRIEF_AMENDMENT_1.md` §B2 and `CLAUDE.md`: CC0 only, entered through a
fetch tool that writes the rights register, nothing under
`assets/thirdparty/` by hand. Skinned meshes cannot go through
`scripts/street/model_batch.gd` (a MultiMesh cannot skin), so each human
is its own draw call; eight of them is inside budget.
