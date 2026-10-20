# Rigged CC0 characters

## Where it stands (2026-10-20)

The player, Tulu and the pedestrians are Kenney's *Animated Characters
Retro* body (CC0, kenney.nl), fetched by `tools/fetch_kenney.py` and
assembled by `scripts/characters/character_rig.gd` into
`scenes/characters/Character.tscn`. Godot 4.3 imports the pack's FBX files
natively, so there is no Blender step and no browser step: the body, the
`idle`/`run`/`jump` clips and the two human skins are ordinary imported
scenes and textures, each with a row in `docs/RIGHTS_REGISTER.md`.

What the pack lacks is a **walk**. Until a true walk clip is in, the rig
plays the run clip slowed to walking pace (`walk_reference_speed` on the
scene). That is a `PLACEHOLDER` on `Character.tscn`.

## The true walk: Quaternius, via the owner's browser

Quaternius' *Universal Base Characters* and *Universal Animation Library*
(both CC0) share one rig, and the library has a proper Walk, Jog, Sprint,
Idle and more. They are hosted on itch.io, which only serves downloads to a
browser, so this is the one step the owner does:

1. Open https://quaternius.itch.io/universal-base-characters, click
   *Download Now*, choose *No thanks, just take me to the downloads*, and
   download the free zip (not a Pro or Source tier).
2. Do the same at https://quaternius.itch.io/universal-animation-library.
3. Upload both zips, unmodified, to the session or the repository's issue
   tracker, with the two URLs.

Then `tools/fetch_quaternius.py --from <zip>` (to be written in that PR,
like `fetch_kenney.py`'s `FILES` step) unpacks the base character and the
clips under `assets/thirdparty/quaternius/`, writes their register rows,
and `Character.tscn` points `body`, `skin`, `idle_scene`, `walk_scene` and
`run_scene` at them. No code changes: which clip means what is data on the
scene.

## Rules that still bind

`docs/BRIEF_AMENDMENT_1.md` §B2 and `CLAUDE.md`: CC0 only, entered through a
fetch tool that writes the rights register, nothing under
`assets/thirdparty/` by hand. Skinned meshes cannot go through
`scripts/street/model_batch.gd` (a MultiMesh cannot skin), so each human
is its own draw call; eight of them is inside budget.
