# Slice 1 spec — "The Street"

`CLAUDE_CODE_BRIEF.md` §4–§7, kept in sync with the build. Where this file and
the brief disagree, the brief wins and this file is wrong — fix it.

Status key: **built** · *in progress* · planned.

| Phase | Deliverable | Status |
|---|---|---|
| P0 | Scaffold, export presets, three workflows, GUT, title screen | **built** |
| P1 | Grey-box street, player, joystick, orbit camera, climb | **built** (fps unverified on device) |
| P2 | `FlagStore`, `GameState`, JSON loaders, choice cards, debug panel | **built** |
| P3 | Tulu, the hum, the `Listen` verb | **built** (blindfold test pending) |
| P4 | The Dry Fountain, all three outcomes | planned |
| P5 | The Glimpse and the feather | planned |
| P6 | End screen, audio bed, lighting, accessibility | planned |

---

## 1. The street block (grey-box) — P1

One block, roughly 120 × 80 m playable, built from primitives by
`tools/gen_street.py`. **Owner decision 2026-10-19: textured, not grey-box** —
procedural tileable textures from `tools/gen_textures.py`, no licensed packs,
nothing from the internet. See `DECISIONS.md`. The fountain is central; the tower is visible from everywhere.

Landmarks that must exist:

- The **dry fountain**. Player spawn is inside its basin, with a short
  rope/ledge climb out.
- **Gopal Seth's shop** beside the fountain, visibly stacked with 10–15 water
  can meshes.
- A **chai stall** with a closed back door. The shrine room is out of scope;
  the door is set dressing.
- A **traffic light** at the one crossing, with a horizontal beam a silhouette
  can sit on.
- The **billboard tower** on the tallest roof, unreachable.
- Two alleys, a bus stop, a few flats with barred windows, fences with
  padlocks as props.
- Ambience only: 4–6 pedestrian capsules on fixed paths who never react to the
  player; 2–3 vehicle boxes on a loop. Nothing is simulated.

**Lighting and palette.** Flat overcast midday. GDD §10 Hollow Vale row: ochre,
dust, timber brown, flat white; rust red on fences and the tower. **Peacock
blue and magenta are forbidden in this scene**, with one exception: the Glimpse
silhouette's backlight and the feather it leaves.

## 2. Player and controls — P1, amended by `BRIEF_AMENDMENT_1.md` §A

- Floating left-thumb joystick in the left 45%; 12% dead zone, cubic
  response; auto-run at 85% deflection after 0.5 s. Side, size and opacity
  from settings.
- Right 55%: drag orbits the camera (soft-follow at 3.5 m, 0.15 s lag, FOV
  65→72 at a run, auto-align after 1.5 s of running); a tap walks there.
- No jump button; approach a ledge → climb; kerbs and low steps are walked
  over. Pause top-left: Controls, Map (off by default).
- One contextual button, lower right, appearing only near something usable and
  labelled with the verb: *Talk*, *Pick up*, *Place*, *Look*, *Listen*, *Sit*.
- **Call**: hold the contextual button with nothing nearby and the character
  hums. Nothing answers until `heard_tulu` is set; after that Tulu's three
  notes reply from wherever he is. The `hummed` count is tracked.
- **Carry**: at most one object (the water can, the feather). Carrying slows
  movement by 15% and changes the idle pose.
- HUD is empty by default. Nothing else is on screen during play.
- Desktop/web fallback: WASD, mouse orbit, `E` for the contextual button, hold
  `E` for Call.

## 3. Tulu and *Listen* — P3

- Tulu stands at the fountain's edge when the player surfaces, humming three
  notes on a loop. Positional, audible within ~15 m, faint beyond.
- Near him the contextual button reads *Listen*. Pressing it plays the notes
  clearly, drifts the camera toward him for ~1.5 s, sets `heard_tulu`, and he
  walks slowly toward the chai stall's back door, pausing when the player falls
  behind. If ignored, he follows the player at a distance.
- *Listen* is **generic**: any node in group `sound_source` exposes it.
  Implemented once.
- **No quest marker, no arrow, no objective text.** The only guide is sound and
  one line in the pause menu: *"Somewhere a boy is humming."*

## 4. Side quest — The Dry Fountain — P4

Defined entirely in `data/quests/dry_fountain.json` and
`data/dialogue/en.json`. All three paths must play through from JSON with no
code change.

- **Giver:** the fountain itself. *Look* at it → a card: *"It's dry. The shop
  beside it is full of water."*
- **Situation:** Gopal Seth has carried every can into his shop because he
  fears the shortage. 6–10 lines, each under 20 words, warm, no preaching
  (GDD §8).

| | Outcome | Flag | What changes |
|---|---|---|---|
| (a) | **Take** a can from the shop stack and walk off with it | `took_dry_fountain` | Gopal says one hurt line; the street's lighting steps slightly darker; the fountain stays dry |
| (b) | **Give**: talk through 2–3 card exchanges until he admits the fear, then carry a can *with him* to the fountain and *Place* it | `gave_dry_fountain` | The basin fills (water plane rises); ambience gains a soft water loop; lighting steps slightly warmer. The slice's "first watering" |
| (c) | **Ignore** | — | Nothing happens; the end screen is still reachable by sitting at the bus stop |

The option is chosen by what the player does, never by a menu. No option is
labelled good or bad. Cards use full sentences, no icons, no timer. The flag
set is the only conditional thing — **no path variable** (GDD §12).

## 5. The Glimpse — P5

- One Glimpse point: the traffic-light beam.
- **Trigger:** the first time `gave_dry_fountain` is set. Never on a timer,
  never on `took_dry_fountain`.
- A backlit humanoid silhouette with flute, feather and cloth outline sits on
  the beam for 4–6 s, lit by a warm rim light nothing else in the scene has.
  Pedestrians do not react. Tulu, if in view, looks up and smiles.
- Approaching within 6 m ends it: the silhouette fades over 0.5 s. On the
  pavement beneath lies a single peacock feather — the only peacock blue in the
  scene. The player can *Pick up* and carry it. **Nothing happens.** It is
  proof.
- *Your journey* records exactly: *"You thought you saw someone on the traffic
  light."*
- Never counted, never rewarded, never required.

## 6. End of the slice — P6

Reached by any of:

- placing the can (b), then walking to the bus stop;
- taking the can (a), then walking to the bus stop;
- sitting at the bus stop at any time after 90 s of play.

Fade to black. One line in white, 24 dp:

> The journey back begins again wherever you are.

Below it, *Play again* and nothing else. *Play again* wipes `GameState`.

The tester questionnaire is **not** in the build. It is
[`PLAYTEST_PROTOCOL.md`](PLAYTEST_PROTOCOL.md).

## 7. Data formats — P2

**Quest JSON** — fields per GDD §7: `id`, `giver`, `start_condition`, `steps[]`
(`id`, `objective_text_id`, `complete_when`, `flags_set`), `branches[]`,
`end_condition`, `flags_set_on_end`, `journey_line_id`. `complete_when` is a
small expression over flags and world events, e.g.
`"event:can_placed_at_fountain"`, `"flag:heard_tulu"`. A tiny evaluator reads
it — no scripting language.

**Dialogue JSON** —

```json
{
  "line_id": {
    "speaker": "gopal",
    "text_id": "...",
    "cards": [{ "text_id": "...", "sets": ["flag"], "next": "line_id" }],
    "requires": ["flag"],
    "review_status": "draft"
  }
}
```

Every line carries `review_status` (`draft` / `panel_approved` / `final`,
GDD §8).

**Strings JSON** — every player-facing string keyed by id. No text baked into a
scene. *(Built in P0: `data/strings/en.json` and the `Strings` autoload.)*

*(All of §7 is built in P2: `scripts/core/quest.gd`, `dialogue.gd`,
`game_state.gd`, `content.gd`; the condition language is in
`scripts/lib/condition.gd`; `data/quests/dry_fountain.json` and
`data/dialogue/en.json` hold The Dry Fountain, review_status `draft`.)*

**GameState** — one object: `beat`, `flags: Array[String]`, `choice_history`,
`journey_lines`, `settings`. Autosaved to `user://journey.json` on every flag
and beat change. One slot. *Play again* wipes it.

## 8. Accessibility — P6 (GDD §11)

- Subtitles for every vocal sound including hums (`[Tulu hums three notes]`),
  with speaker labels and an optional background box.
- *Sound cues as visuals*: a soft expanding ripple at an active `sound_source`.
- No flashing above 3 Hz. No timed input anywhere.
- Settings, persisted in `GameState.settings`: joystick side / size / opacity,
  camera sensitivity and inversion, large text (16 dp → 22 dp), subtitle box,
  sound-cue visuals.
- *Auto-walk to target*: tap a destination to walk there.
- Screen-reader labels on every menu control.

## 9. Definition of done

- A stranger installs the APK from Releases and plays fountain → end screen in
  3–4 minutes with no instructions, on a 2020 mid-range phone at a steady
  30 fps.
- All three Dry Fountain paths work from JSON alone; the Glimpse fires only on
  the give path; the feather can be carried; *Your journey* shows the right
  lines.
- The debug panel lists and sets every flag, and is invisible in normal play.
- `DECISIONS.md`, this file, `PLAYTEST_PROTOCOL.md` and `README.md` are
  current.
- CI green on `main`; the web build live on Pages; the latest APK on Releases
  with the QR code in the README.
