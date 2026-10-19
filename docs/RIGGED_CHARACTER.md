# Bringing in a rigged CC0 character

The player and the pedestrians are still humanoids built from primitives with
a procedural walk (`scripts/player/figure_animator.gd`). A rigged, animated
character cannot be produced in the cloud session: the CC0 packs that have one
(Quaternius, Kenney's character kits) ship as FBX or behind a download widget,
and the pipeline here has no FBX importer and no editor. These are the steps
for the owner to do once on a desktop; after that, wiring the character in is
an ordinary PR.

Rules that still bind (`docs/BRIEF_AMENDMENT_1.md` §B2, `CLAUDE.md`): the
licence must be **CC0**, the file enters only through a fetch tool that writes
its row in `docs/RIGHTS_REGISTER.md`, and nothing is placed under
`assets/thirdparty/` by hand.

## 1. Pick a pack

Any of these is CC0 and has a rigged humanoid with idle and walk clips:

| Pack | Where | Notes |
|---|---|---|
| Quaternius, *Universal Animation Library* + *Ultimate Modular Men/Women* | quaternius.com | Low-poly, textured by a palette, many clips. FBX and GLB in the zip. |
| Kenney, *Character Kit* / *Blocky Characters* | kenney.nl/assets | Blocky style; GLB included; fewer clips. |
| Poly Pizza (filter licence = CC0) | poly.pizza | Mixed sources; check each model's licence badge says CC0. |

Choose a character whose look fits GDD §10 (an ordinary coat, a face, no
glow). Note the exact download URL and the file names you use; the register
row needs them.

## 2. Convert to one GLB (desktop, Blender 4.x, free)

Skip this step if the pack already ships `.glb`.

1. *File → Import → FBX*, pick the character (with its armature).
2. For each animation clip you want (idle, walk, carry), import its FBX too,
   or use the pack's "all animations" file; in the *Nonlinear Animation*
   editor make sure each clip is a separate action named `idle`, `walk`,
   `carry`.
3. Select armature + mesh. *File → Export → glTF 2.0*: format **glTF Binary
   (.glb)**, *Include → Selected Objects*, *Animation → Group by NLA Track*,
   *Export Deformation Bones Only*. Textures embedded.
4. Keep it small: under 10k triangles, one 1024 px texture. The street's
   budget is 150k triangles for everything (amendment §C).

## 3. Put it in the repository through a tool

Do **not** copy the file into `assets/thirdparty/` yourself. Either:

- Host nothing, pass the local file: `python3 tools/fetch_character.py
  --from ~/Downloads/character.glb --source "<download URL>" --licence CC0`
  (this tool does not exist yet; ask for it in the PR and it will be written
  like `tools/fetch_kenney.py`: it copies the file to
  `assets/thirdparty/<pack>/`, writes the `RIGHTS_REGISTER.md` row with the
  URL, licence and date, and supports `--check` for CI), or
- if the pack has a stable public URL (Kenney does), extend
  `tools/fetch_kenney.py`'s `KITS` with the kit and the `.glb` names; it does
  the rest.

Commit the `.glb` and its `.import` file after importing the project twice.

## 4. What gets wired afterwards (not your step)

- `scenes/player/Player.tscn` gets the character as a child in place of the
  primitives; `figure_animator.gd` is replaced by an `AnimationTree` that
  blends `idle`/`walk` on speed and switches to `carry` on the
  `carrying` flag (the hum keeps its hold gesture).
- Pedestrians in `tools/gen_street.py` use the same scene through
  `scripts/street/model_batch.gd` is **not** possible for skinned meshes
  (a MultiMesh cannot skin), so they stay direct instances: six pedestrians,
  one draw call each, inside budget.
- `docs/DECISIONS.md` records the choice with the date and GDD §10.
