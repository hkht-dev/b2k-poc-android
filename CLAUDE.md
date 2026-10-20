# Working rules

Copied from `CLAUDE_CODE_BRIEF.md` §10. These bind every change in this
repository.

- Read `docs/GDD.md` §1, §3a, §6, §7, §11, §12 before writing any gameplay
  code. Cite the section in the PR description for every feature.
- One PR per phase; small commits; conventional commit messages
  (`feat(street): ...`, `fix(ci): ...`).
- Every flag, every string id and every quest step is data, never a literal in
  code. If you find yourself writing `if path == "compete"`, stop: use flags.
- Never add: a score, a meter, a badge, a checklist quest log, a map marker, a
  timer, a notification, an ad SDK, analytics, a network call. If a library you
  want to add does any of these, do not add it.
- Never add a "correct answer" cue to a card: no icons, no colour difference,
  no ordering convention.
- Keep draw calls and triangles in budget; profile in the web build each phase
  and record numbers in `docs/DECISIONS.md`.
- Every placeholder asset carries a `PLACEHOLDER` comment naming its final
  replacement from the GDD.
- Do not scaffold out-of-scope systems "for later". Keep the data formats
  forward-compatible instead.
- When unsure, pick the simpler thing and write it in `docs/DECISIONS.md` with
  the date and the GDD section it affects.

## Owner overrides (2026-10-19)

The repository owner lifted two of the brief's rules after playing P1; see
`docs/DECISIONS.md` "P2 — Owner overrides". The slice is **textured** (not
grey-box) and the **60 MB install budget no longer binds**. Everything else in
the brief still holds, in particular: no asset is pulled from the internet.
Textures come from `tools/gen_textures.py`; the street scene comes from
`tools/gen_street.py`; placeholder audio from `tools/gen_audio.py`. Edit the generators, not their output, and run them
before committing — CI checks both with `--check`.

`docs/BRIEF_AMENDMENT_1.md` wins over the brief where they conflict. Third-
party assets are **CC0 only** (Kenney, Poly Haven, ambientCG) and enter the
repository only through `tools/fetch_polyhaven.py` or `tools/fetch_kenney.py` (or a sibling tool), which
writes their row in `docs/RIGHTS_REGISTER.md`. Never add a file under
`assets/thirdparty/` by hand.

## Owner expansion (2026-10-20)

After playing P6 the owner asked for the world to grow past the slice: a
heading compass, shops the player can walk into (each inside its own place
behind a door), a car to drive, a showroom to try clothes on in, and then the
macro design of `docs/GDD.md` developed in parallel: the Grove, the Pool, the
main quest, the side quests, Tells, Glimpse points, wisdom cards, the Garden,
lamps (local only), tales, vignettes, the tower, the Song, Act 4 and Act 5.
`docs/DECISIONS.md` "The world grows" records it. The slice's out-of-scope
list below is therefore lifted for those systems; everything else in this
file still holds, in particular: no backend, no analytics, no network call,
no IAP, no score or meter, every flag and string in data, CC0 assets only.

Scenes are generated: the street by `tools/gen_street.py` plus one file per
feature under `tools/street_parts/`; interiors by `tools/gen_interiors.py`
plus `tools/interiors/`; sounds and textures likewise take parts
(`tools/audio_parts/`, `tools/texture_parts/`). A walkable place extends
`scripts/places/place.gd`; doors and spawn points are data on the scene and
`data/places.json` maps a place id to its scene.

## The slice

Out of scope for Slice 1, and not to be scaffolded: the Grove, the Pool/Veil
descent, *The Forgotten Song*, the tower climb, the Veena, Madhuri, the
embrace, wisdom cards, the Garden, lamps, companions, Circles, any backend,
analytics, IAP, localization beyond externalized strings, save slots beyond one
autosave, rooftop running, cows, Tells. GDD §16a is deferred.

The forbidden colours in the Street are **peacock blue and magenta** (GDD §10,
Hollow Vale row). The single exception is the Glimpse silhouette's backlight
and the feather it leaves behind.

## Before you push

CI runs exactly this. Run it first.

```sh
gdformat --check $(git ls-files '*.gd' | grep -v '^addons/')
gdlint          $(git ls-files '*.gd' | grep -v '^addons/')
python3 tools/check_data.py
tools/run_tests.sh
```

Run the suite through `tools/run_tests.sh`, never `gut_cmdln.gd` directly:
GUT skips a test script that will not compile and still exits 0, so a broken
test file looks exactly like a passing one. The wrapper fails when fewer
scripts ran than exist on disk.

`addons/` is vendored third-party code. Do not format, lint or edit it.

Import the project twice after a clean checkout: GUT's editor plugin loads
images and fonts during the first pass, before they have been imported.
