# Build brief for Claude Code — *Journey Back to Krishna*, Slice 1 ("The Street")

You are the sole engineer on this project. Build it end to end in this repository: Godot 4 project, GDScript, Android export, GitHub Actions CI that produces a signed APK on every push to `main`. Work in small commits with clear messages. When something in this brief is ambiguous, read `docs/GDD.md` (the full game design document) first; if it is still ambiguous, choose the simpler option and record the decision in `docs/DECISIONS.md`.

## 0. What we are building, and what we are not

This is **not** the full game described in `docs/GDD.md`. It is a 3–4 minute grey-box vertical slice of Act 3 (Hollow Vale, "the Street"), built to answer one question in front of ten strangers:

> Does a player follow sound instead of instructions, notice a figure nobody else sees, and make one choice that feels like it matters — without anyone telling them this is a spiritual game?

**In scope (Slice 1):**
1. Surfacing: the player climbs out of a dry fountain into a city street.
2. Tulu, a boy humming three notes; a *Listen* verb that pulls the camera toward sound.
3. One side quest, *The Dry Fountain*: take a water can / carry it to the fountain with the shopkeeper / ignore. Presented as choice cards.
4. One Glimpse at the traffic light: a backlit silhouette visible for 4–6 s after the player's first give-choice, gone when they arrive, a feather left on the ground that can be picked up.
5. An end screen with the line *"The journey back begins again wherever you are."* and a *Play again* button.
6. A debug panel (hidden behind a 5-tap on the title) listing all flags and allowing a tester to set them.

**Out of scope for Slice 1 (do not build, do not scaffold):** the Grove, the Pool/Veil descent, the main quest *The Forgotten Song*, the tower climb, the Veena, Madhuri, the embrace, wisdom cards, the Garden, lamps, companions, Circles, any backend, analytics, IAP, localization beyond externalized strings, save slots beyond one autosave, rooftop running, cows, Tells. Section 16a of the GDD is explicitly deferred.

Everything must serve the five design pillars in GDD §1. In particular: **no score, meter, points or "correct" answer anywhere**, including the debug panel's wording.

## 1. Tech stack (fixed)

| Layer | Choice |
|---|---|
| Engine | **Godot 4.3** (pin the exact version in `project.godot` and CI). GDScript only. |
| Renderer | **Mobile** renderer (`rendering/renderer/rendering_method.mobile`), forward, one `DirectionalLight3D`, no real-time shadows, baked `LightmapGI` where lighting exists. |
| Target | Android 9+ (API 28), arm64-v8a + armeabi-v7a, portrait locked, 30 fps target on a 2020 mid-range phone (Adreno 610 class). Install size under 60 MB for the slice. |
| Dialogue/choices | A small in-repo system reading JSON (see §5). Do **not** add Ink/Yarn/Dialogic for the slice; keep the data format compatible with GDD §7 "Quest data fields" so a later migration is cheap. |
| Audio | Godot's built-in audio with `AudioStreamPlayer3D` for positional sources. Stems as separate `.ogg` files on a shared bus. |
| CI | GitHub Actions (see §8). |
| Secondary export | **Web (HTML5)** export deployed to GitHub Pages on every push to `main`, so the slice can be played in a desktop browser with WASD/mouse for quick review. Touch remains the primary input. |

Performance budget per frame on target: < 150 draw calls, < 100k triangles, zero GC-relevant allocations in `_process` (pool everything that spawns).

## 2. Repository layout

```
/
├── project.godot
├── export_presets.cfg            # Android + Web presets, no secrets inside
├── CLAUDE.md                     # this file, trimmed to working rules (see §10)
├── README.md                     # how to run, test on device, and what the slice is
├── docs/
│   ├── GDD.md                    # the full design document (already present)
│   ├── SLICE1_SPEC.md            # this brief's §4–§7, kept in sync with the build
│   ├── DECISIONS.md              # every judgement call, dated, with reason
│   └── PLAYTEST_PROTOCOL.md      # the four questions from GDD §16 + the slice-specific ones in §9
├── data/
│   ├── quests/dry_fountain.json
│   ├── dialogue/en.json
│   └── strings/en.json
├── scenes/
│   ├── core/        (Main, GameState, FlagStore, SceneLoader, DebugPanel)
│   ├── street/      (Street.tscn and its sub-scenes)
│   ├── player/
│   ├── npc/
│   ├── ui/
│   └── end/
├── scripts/         (mirror of scenes/, one .gd per scene; shared code in scripts/lib/)
├── assets/
│   ├── models/      (grey-box primitives, .glb)
│   ├── audio/       (generated placeholders, see §6)
│   ├── fonts/
│   └── ui/
├── tests/           (GUT unit tests for FlagStore, quest state machine, dialogue loader)
└── .github/workflows/
    ├── ci.yml       (lint + tests on every PR)
    ├── android.yml  (signed APK on main, artifact + GitHub Release)
    └── web.yml      (HTML5 export to GitHub Pages)
```

## 3. Build phases — do them in this order, one PR each

Each phase ends with: tests green, CI green, a playable APK attached to the PR as an artifact, and a 5–10 line entry in `docs/DECISIONS.md`. Do not start the next phase until the previous one is merged.

| Phase | Deliverable | Done when |
|---|---|---|
| P0 Scaffold | Empty Godot 4.3 project, Mobile renderer, portrait, Android + Web export presets, all three workflows green, GUT installed with one passing test, `README.md` explaining how to sideload the APK. | A tester can install an APK from the Actions tab that shows a title screen. |
| P1 Movement | Grey-box street block (§4.1), player capsule, virtual joystick, right-thumb orbit camera, auto-run, context-sensitive climb out of the fountain, contextual button scaffold. | Player climbs out of the fountain and walks the block at 30 fps on a mid-range phone (verify with the Godot profiler in a web build and document numbers). |
| P2 Flags + data | `FlagStore`, `GameState` (single serializable object, autosave as local JSON), JSON quest/dialogue/string loaders, choice-card UI, debug panel. Unit tests for all of it. | A quest defined only in JSON can be stepped through with cards and sets flags; the debug panel shows them. |
| P3 Listen + Tulu | Tulu NPC with a 3-note hum loop (positional audio), `Listen` verb that plays the source and drifts the camera toward it, `heard_tulu` flag. | A blindfolded tester (audio only) can locate Tulu. |
| P4 The Dry Fountain | Gopal Seth, the water-can carry, the three outcomes, fountain fill state, `gave_dry_fountain` / `took_dry_fountain` flags. | All three paths play through from JSON without code changes. |
| P5 Glimpse | The traffic-light Glimpse (§4.5), the feather pickup, `Your journey` line. | Glimpse triggers once, only on the flag condition, never on a timer. |
| P6 End + polish | End screen, Play again (resets `GameState`), ambient street audio bed, lighting pass within budget, accessibility items in §7. | Full slice plays start to end in 3–4 min with no debug UI visible; crash-free on three test devices (document which). |

## 4. The slice, scene by scene (source: GDD §3, §3a, §5, §6, §7)

### 4.1 The street block (grey-box)
One block, roughly 120 × 80 m playable. Build it from primitives and `CSGBox3D`/`MeshInstance3D` with flat coloured materials — no textures, no licensed packs in the slice. Landmarks that must exist, placed so the fountain is central and the tower is visible from everywhere:

- The **dry fountain** (player spawn is inside its basin; a short rope/ledge climb out).
- **Gopal Seth's shop** beside the fountain, visibly stacked with water cans (10–15 can meshes).
- A **chai stall** with a closed back door (the shrine room is out of scope; the door is set dressing).
- A **traffic light** at the one crossing, with a horizontal beam Krishna can be silhouetted on.
- The **billboard tower** on the tallest roof, unreachable.
- Two alleys, a bus stop, a few flats with barred windows (bars as simple grilles), fences with padlocks as props.
- Looping ambience only: 4–6 "pedestrian" capsules walking fixed paths who never react to the player; 2–3 vehicle boxes on a loop. Nothing is simulated.

Lighting: flat overcast midday, no pink or magenta anywhere in the palette. Palette from GDD §10 Hollow Vale row: ochre, dust, timber brown, flat white; rust red on fences and tower. **Peacock blue and magenta are forbidden** in this scene except on the Glimpse silhouette's backlight.

### 4.2 Player and controls (GDD §6, §11)
- Left-thumb virtual joystick (fades in on touch, side/size/opacity adjustable in settings).
- Right-thumb drag orbits the camera; soft-follow third person at 3.5 m.
- Auto-run after 0.5 s of full tilt. No jump button; approach a ledge → climb.
- One contextual button, lower right, appears only near something usable, labelled with the verb: *Talk*, *Pick up*, *Place*, *Look*, *Listen*.
- **Call**: hold the contextual button with nothing nearby → the character hums (a short placeholder hum). In this slice nothing answers until `heard_tulu` is set; after that Tulu's three notes reply from wherever he is. Track `hummed` count.
- Carry: the player holds at most one object (the water can, the feather). Carrying slows movement by 15% and changes the idle pose (a simple tilt is fine).
- HUD is empty by default. Nothing else on screen during play.
- Desktop/web fallback: WASD + mouse orbit + E for the contextual button + hold E for Call.

### 4.3 Tulu and Listen (GDD §3 Act 3 arrival, §6 Interaction)
- Tulu stands at the fountain's edge when the player surfaces, humming three notes on a loop (positional, audible within ~15 m, faint beyond).
- Near Tulu the contextual button reads *Listen*. Pressing it plays the notes clearly, drifts the camera toward him for ~1.5 s, sets `heard_tulu`, and he walks slowly toward the chai stall's back door, pausing when the player falls behind. If ignored, he follows the player at a distance.
- The *Listen* verb is generic: any node in group `sound_source` exposes it. Implement it once.
- Rule: no quest marker, no arrow, no objective text. The only guide is sound and the one line in the pause menu: *"Somewhere a boy is humming."*

### 4.4 Side quest — The Dry Fountain (GDD §7)
Defined entirely in `data/quests/dry_fountain.json` and `data/dialogue/en.json`.

- **Giver:** the fountain itself (*Look* at it → a card: *"It's dry. The shop beside it is full of water."*).
- **Situation:** Gopal Seth has carried every can into his shop because he fears the shortage. Lines under 20 words, warm, no preaching (GDD §8 writing rules). Write 6–10 lines for him.
- **Options, chosen by what the player does, never by a menu:**
  - (a) *Take:* pick up a can from the shop stack and walk off with it. Sets `took_dry_fountain`. Gopal says one hurt line; the street's lighting steps slightly darker; the fountain stays dry.
  - (b) *Give:* talk to Gopal through 2–3 card exchanges until he admits the fear, then carry one can **with him** to the fountain and *Place* it. Sets `gave_dry_fountain`. The fountain basin fills (animate water plane rising), ambience gains a soft water loop, lighting steps slightly warmer. This is the slice's "first watering".
  - (c) *Ignore:* nothing happens; the end screen can still be reached by walking to the bus stop and sitting (contextual *Sit*).
- No option is labelled good or bad; cards use full sentences; no icons; no timer.
- The flag model is the only thing that is conditional (GDD §12 Flag model): a set of strings. No path variable.

### 4.5 Glimpse (GDD §6 Glimpses)
- One Glimpse point: the traffic-light beam.
- Trigger: first time `gave_dry_fountain` is set (never on a timer, never on `took_`).
- Presentation: a backlit humanoid silhouette with flute, feather and cloth outline (a simple extruded 2D silhouette or low-poly placeholder is fine) sits on the beam for 4–6 s, lit by a warm rim light that nothing else in the scene has. Pedestrians do not react. Tulu, if within view, looks up and smiles (a head-tilt is enough).
- Approaching within 6 m ends it: the silhouette fades over 0.5 s. On the pavement beneath lies a single peacock feather (a flat mesh with the only peacock-blue in the scene). The player can *Pick up* and carry it. Nothing happens. It is proof.
- `Your journey` (pause menu) records exactly: *"You thought you saw someone on the traffic light."*
- Never counted, never rewarded, never required.

### 4.6 End of slice
- Ending is reached by: placing the can (b) and then walking to the bus stop; or taking the can (a) and walking to the bus stop; or sitting at the bus stop at any time after 90 s of play.
- Fade to black; one line in white, 24 dp: *"The journey back begins again wherever you are."*; below it *Play again* only.
- Under *Play again*, a one-screen (skippable) tester questionnaire is **not** built into the game; it lives in `docs/PLAYTEST_PROTOCOL.md`.

## 5. Data formats

**Quest JSON** — fields per GDD §7: `id, giver, start_condition, steps[] (id, objective_text_id, complete_when, flags_set), branches[], end_condition, flags_set_on_end, journey_line_id`. `complete_when` is a small expression over flags and world events (e.g. `"event:can_placed_at_fountain"`, `"flag:heard_tulu"`). Write a tiny evaluator; no scripting language.

**Dialogue JSON** — `{ "line_id": { "speaker": "gopal", "text_id": "...", "cards": [ { "text_id": "...", "sets": ["flag"], "next": "line_id" } ], "requires": ["flag"], "review_status": "draft" } }`. Every line carries `review_status` as in GDD §8.

**Strings JSON** — every player-facing string lives here keyed by id. No text baked into scenes. Fonts must cover Latin extended and Devanagari (ship Noto Sans + Noto Serif Devanagari).

**GameState** — one Resource/Dictionary: `beat`, `flags: Array[String]`, `choice_history`, `journey_lines`, `settings`. Autosave on every flag change and beat change to `user://journey.json`. One slot. *Play again* wipes it.

## 6. Placeholder art and audio (what Claude Code can and cannot make)

You cannot produce the final painted art or the real Song. Do not try, and do not pull assets from the internet. Make deliberate placeholders:

- **Models:** primitives and simple `.glb` built from `ArrayMesh`/CSG. The player is a capsule with a flat "coat" colour; Tulu a smaller capsule; Gopal a wider one; the Glimpse a dark silhouette plane. Give every placeholder a `# PLACEHOLDER: replace with <asset name from GDD §10>` comment in its scene.
- **Audio:** generate placeholders procedurally in a script under `tools/gen_audio.py` (numpy + soundfile, checked in) and commit the resulting `.ogg`: Tulu's three notes as a soft sine/triangle melody (choose three notes that imply a resolution: e.g. G4 A4 C5), the player's hum as a filtered single tone with vibrato, a flat street bed (band-passed noise + low rumble), a water loop (filtered noise with amplitude modulation). Document the generation so the composer can replace them 1:1.
- **UI:** cream parchment panels (`#F4ECD8`), one serif heading font, one sans body font, 16 dp minimum text, large-text option to 22 dp. The lotus icon is not in the slice.

## 7. Accessibility and settings (GDD §11, slice subset)
- Subtitles for every vocal sound, including hums (`[Tulu hums three notes]`), with speaker labels and an optional background box.
- *Sound cues as visuals*: when a `sound_source` is active, a soft expanding ripple at its origin.
- No flashing above 3 Hz. No timed input anywhere.
- Joystick side/size/opacity, camera sensitivity and inversion, large text, subtitle box, sound-cue visuals — all in a settings screen, persisted in `GameState.settings`.
- *Auto-walk to target*: tap a destination on screen to walk there.
- Screen-reader labels on all menu controls.

## 8. GitHub and CI (the project lives entirely in the cloud)

- Branch protection on `main`: PRs only, CI must pass.
- `ci.yml`: on every PR — `gdformat --check`, `gdlint`, GUT tests headless, project import check (`godot --headless --import`).
- `android.yml`: on push to `main` — export a **debug-signed** APK by default so testers can sideload immediately; if the repository secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` exist, also export a release-signed AAB. Upload both as workflow artifacts and attach the APK to a GitHub Release tagged `slice1-build-<run_number>`. Use a maintained Godot export action (e.g. `chickensoft-games/setup-godot` with export templates, or `firebelley/godot-export`); pin its version. Use a JDK 17 and the Android SDK/NDK versions Godot 4.3 documents.
- `web.yml`: on push to `main` — HTML5 export to GitHub Pages so the slice is playable in a desktop browser at `https://<org>.github.io/<repo>/`. Note in README that the web build is for review only; touch and performance are judged on Android.
- README must include: a QR code image (generated in CI with a checked-in script) linking to the latest APK release, sideload steps for Android, and the three test devices the team should use (one 2019 low-end, one 2020 mid-range, one recent flagship) with a table to record fps.
- Never commit secrets, keystores, or export templates. `.gitignore` the Godot cache.

## 9. Playtest protocol (`docs/PLAYTEST_PROTOCOL.md`)
Write it from GDD §16: observe silently on the tester's own phone; "play until you want to stop"; then ask verbatim and record:
1. What was this game about, in your own words?
2. Did any choice feel like it mattered? Which one?
3. Did you notice anyone unusual? What did you think they were?
4. How did you know where to go?

Add the "signals that mean a redesign" list from GDD §16, plus: *if more than 3 of 10 testers say "religious game" before "story" or "mystery", pillar 1 is failing.*

## 10. Working rules (copy this section into `CLAUDE.md`)
- Read `docs/GDD.md` §1, §3a, §6, §7, §11, §12 before writing any gameplay code. Cite the section in the PR description for every feature.
- One PR per phase; small commits; conventional commit messages (`feat(street): ...`, `fix(ci): ...`).
- Every flag, every string id and every quest step is data, never a literal in code. If you find yourself writing `if path == "compete"`, stop: use flags.
- Never add: a score, a meter, a badge, a checklist quest log, a map marker, a timer, a notification, an ad SDK, analytics, a network call. If a library you want to add does any of these, do not add it.
- Never add a "correct answer" cue to a card: no icons, no colour difference, no ordering convention.
- Keep draw calls and triangles in budget; profile in the web build each phase and record numbers in `docs/DECISIONS.md`.
- Every placeholder asset carries a `PLACEHOLDER` comment naming its final replacement from the GDD.
- Do not scaffold out-of-scope systems "for later". Keep the data formats forward-compatible instead.
- When unsure, pick the simpler thing and write it in `docs/DECISIONS.md` with the date and the GDD section it affects.

## 11. Definition of done for Slice 1
- A stranger can install the APK from the Releases page, play from fountain to end screen in 3–4 minutes with no instructions, on a 2020 mid-range Android phone at a steady 30 fps.
- All three Dry Fountain paths work from JSON alone; the Glimpse fires only on the give-path; the feather can be carried; *Your journey* shows the right lines.
- Debug panel lists and sets every flag; it is invisible in normal play.
- `docs/DECISIONS.md`, `docs/SLICE1_SPEC.md`, `docs/PLAYTEST_PROTOCOL.md` and `README.md` are current.
- CI green on `main`; web build live on Pages; latest APK on Releases with a QR code in the README.

Start with P0. Before writing code, post a short plan for P0 as the first PR description, then execute it.
