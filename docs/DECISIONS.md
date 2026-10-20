# Decisions

Every judgement call, dated, with the reason and the section it affects
(`CLAUDE_CODE_BRIEF.md` §10). Newest phase last.

---

## P0 — Scaffold (2026-10-19)

### Godot, not Unity

GDD §12 names Unity as the engine, "confirmed by a one-week bake-off".
`CLAUDE_CODE_BRIEF.md` §1 fixes the stack at Godot 4.3, GDScript only, and the
brief is the newer document and the one scoped to this slice. Built on Godot
4.3. The GDD's §12 architecture table is therefore stale for the slice; its
*intent* (one serializable state object, data-driven quests, local JSON save,
no backend) is what we are following, and that intent is engine-neutral.
Affects GDD §12.

### Direct commits to `main`, not one PR per phase

`CLAUDE_CODE_BRIEF.md` §3 and §8 ask for one PR per phase and branch protection
on `main`. The repository owner asked for the work to land on `main` directly,
so P0 is a direct commit. Branch protection is not enabled. The per-phase gate
(tests green, CI green, an installable artifact, an entry in this file) is kept;
only the pull request is skipped. Affects §3, §8.

### Two import passes

A clean checkout needs `godot --headless --import` run **twice**. GUT's editor
plugin loads `addons/gut/images/*.png` and `addons/gut/fonts/*.ttf` during the
first pass, before the importer has produced them, and prints a wall of
"Failed loading resource" errors ending in "GUT got some new images that are
not imported yet. Please restart Godot." The second pass is clean. Every
workflow and the README do this. Affects §8.

### A `NotYetBuilt` placeholder screen behind *Begin*

P0's gate is "a tester can install an APK that shows a title screen", but a
*Begin* button that does nothing reads as a broken build. *Begin* swaps to a
one-line placeholder screen with a way back, which also proves on-device that
screen swapping and the string table work before any gameplay exists. It is
marked `PLACEHOLDER` and P1 deletes it, pointing `Main.FIRST_PLAY_SCREEN` at
`scenes/street/Street.tscn`. Affects §3 P0, §3 P1.

### Noto Serif added; Noto Serif Devanagari cannot carry headings

`CLAUDE_CODE_BRIEF.md` §5 says to ship "Noto Sans + Noto Serif Devanagari", and
GDD §10 wants "a single serif for headings and a clean sans for body (both with
Devanagari and extended Latin coverage)". Those two cannot both hold: Noto Serif
Devanagari covers 5 of 58 ASCII letters and 0 of 336 Latin Extended codepoints,
so every English heading silently fell back to the sans and the serif never
appeared. Shipped Noto Serif (Latin, 58/58 and 336/336) as the heading base
font with Noto Serif Devanagari as its fallback, and Noto Sans as the body base
font with the same fallback. Three faces, 1.1 MB, all SIL OFL. Dropped Noto
Sans SemiBold, which nothing used. Affects §5, GDD §10, GDD §11.

### Web export is single-threaded

Godot's web export defaults to thread support, which requires the server to
send `Cross-Origin-Opener-Policy` and `Cross-Origin-Embedder-Policy` headers.
GitHub Pages cannot send custom headers, so a threaded build would not boot on
the review URL at all. The Web preset sets `variant/thread_support=false`, and
`project.godot` names `rendering_method.web="gl_compatibility"` rather than
relying on a silent fallback from the Mobile renderer. The Android build is
unaffected and still uses the Mobile renderer. Affects §1, §8.

### The QR code encodes `/releases/latest`, not a build

§8 asks for a QR code "generated in CI with a checked-in script" linking to the
latest APK. Encoding a specific build's URL would mean CI pushing a new image to
`main` on every build. The QR encodes GitHub's permanent `/releases/latest`
URL instead, so one committed image stays correct forever; `tools/gen_qr.py
--check` runs in CI and fails if the committed image drifts from what the script
produces. Verified it decodes to the right URL. Affects §8.

### GitHub Actions pinned by version tag, not commit SHA

§8 says to pin the export action's version. The Godot version is pinned exactly
(`4.3.0`) in all three workflows, which is the part that decides whether a build
is reproducible. The actions themselves are pinned to major tags
(`actions/checkout@v4`, `chickensoft-games/setup-godot@v2`,
`softprops/action-gh-release@v2`). Tighten these to commit SHAs once CI has run
green once and the resolved SHAs are known. Affects §8.

### The release AAB path is written but unexercised

The Android workflow exports a debug-signed APK on every push, and a
release-signed `.aab` only when `ANDROID_KEYSTORE_BASE64` and friends exist. No
such secrets are set on this repository yet, so that step has never run. An AAB
needs Godot's Gradle build, so it uses its own preset (`Android Release (AAB)`,
`use_gradle_build=true`) and the workflow installs the Android build template
first. Expect to debug that path the first time real signing secrets are added.
Affects §8.

### `min_sdk` is left empty on the APK preset

§1 targets Android 9+ (API 28). Setting `gradle_build/min_sdk="28"` on the
non-Gradle APK preset does not quietly do nothing, as first assumed — Godot
refuses the export outright: *"Min SDK" can only be overridden when "Use Gradle
Build" is enabled.* Found by exporting an APK for real, which CI had not yet
managed to do. The APK preset now leaves `min_sdk` and `target_sdk` empty and
the prebuilt template decides (it reports `sdkVersion:'21'`,
`targetSdkVersion:'34'`). The AAB preset keeps `min_sdk="28"` because it does
use the Gradle build. API 28 remains the declared target and the device matrix
enforces it in practice. Affects §1, §8.

### Runners are `ubuntu-latest`

Changed from `ubuntu-22.04` while chasing jobs that would not start. That
diagnosis was wrong — see the next entry; the label was never the problem. The
change is kept because `ubuntu-latest` is the sensible default for a project
with no pinned-image requirement, but it fixed nothing. If reproducibility
later matters more than currency, pin an explicit image and check it still
resolves. Affects §8.

### Why no CI job would start: a GitHub incident, not this repository

Every job from the P0 push sat `queued` with no runner pickup. Two diagnoses
were made and **both were wrong**:

1. *The `ubuntu-22.04` label is retired.* Switching all five jobs to
   `ubuntu-latest` changed nothing.
2. *The repository is private, so Actions bills minutes and none are left.*
   The repository was made public; jobs still sat queued for six minutes.

The actual cause was a GitHub-side incident — "Degraded availability for GitHub
Actions, GitHub Pages and Webhooks", opened 2026-10-19T15:49:25Z, with Actions,
Pages and Webhooks all reporting `degraded_performance`. The first P0 push was
at 15:52:55Z, four minutes after that incident opened. Every queued run is
explained by it.

The lesson worth keeping: when something external will not start at all, check
the provider's status page *before* changing configuration. Two commits were
spent on configuration that was never broken, and the repository's visibility
was changed on a false premise — it can be made private again with no effect on
CI, since public is not load-bearing for anything except the Pages review build.

The workflows remain **unverified**: they have still never executed a step.
Re-run them once the incident clears and treat the first green run as the real
P0 CI gate. Affects §8.

### The first APK was built locally, not by CI

Because CI could not run during the GitHub incident above, the P0 APK was
exported on a developer machine with
Godot 4.3, Android SDK build-tools 34.0.0 and a generated debug keystore —
the same steps `android.yml` performs. Verified: `apksigner verify` passes
v1, v2 and v3 schemes; `arm64-v8a` and `armeabi-v7a` both present; portrait
locked; `data/strings/en.json` present in `assets/`; 46.6 MB against the 60 MB
budget. Not verified: that it launches on a physical device — no emulator is
available here (no KVM), so the first real device run is the playtest. Affects
§3 P0.

### Performance numbers

None for P0: it renders one `Control` screen and has no 3D content, so the §1
budget is not meaningfully exercised. Sizes measured:

| Build | Size | Note |
|---|---|---|
| Web `.pck` | 639 KB | data, scripts and three fonts; `addons/gut` and `tests` excluded |
| Web total | 36 MB | dominated by `index.wasm` (35 MB), which is the engine, not content |
| Android APK | 46 MB | against the 60 MB budget |

---

## P1 — Movement (2026-10-19)

### The climb is automatic; the contextual button ships unused

GDD §6 is explicit — "approach a ledge or ladder and the character climbs; no
jump button" — and the verbs it lists for the contextual button are Talk, Pick
up, Place, Look and Listen. Climb is not among them. So walking into the
fountain wall climbs the player out with no prompt and no press.

That leaves P1's "contextual button scaffold" with nothing to drive it. Rather
than invent a verb to demonstrate it, the button ships complete and covered by
tests but with no consumer: in the P1 build it correctly never appears, which
is also what GDD §11 asks for ("HUD is empty by default"). Its first real verb
is *Listen* in P3. Affects §3 P1, §4.2, GDD §6.

### The ledge only fires when the player walks into it

A bare overlap test sent the player over the wall when they brushed along it.
The climb now also requires the body's velocity to point into the ledge
(dot product ≥ 0.35), so walking along the rim does nothing. Affects §4.2.

### The fountain basin is 14 m across, not 10 m

The first basin was 10 m square. With the camera arm at 3.5 m (GDD §6) the
camera spent the whole opening shot inside the south wall, and once wall
collision was added it pulled all the way in to its 0.6 m minimum and filled
the screen with the player's capsule. Widening the basin to 14 m gives the arm
room to sit at its full length at spawn. The ground is built as four boxes
whose gap is exactly the basin footprint, so there is no seam to fall through.
Affects §4.1.

### The camera pulls in off walls itself, without a SpringArm3D

`SpringArm3D` is the stock answer, but its cast direction is easy to get
backwards and hard to assert in a test. The rig instead raycasts from the pivot
to the ideal camera position against the world collision layer and shortens the
arm to the hit. It snaps in and eases out: popping into a wall reads as a bug,
easing out of one reads as the camera breathing. The player is on collision
layer 2 and the world on layer 1, so the camera never pulls in on the body it
is following. Affects GDD §6.

### Two coordinate-convention bugs, found before the first run

Both would have compiled and run while feeling broken. Written down because
they are the kind of thing that gets re-introduced:

- The joystick's screen-up is `y = +1`, but forward in Godot is `-Z`.
  `stick_to_world` negates y; without it the stick drove the player backwards.
- A `Node3D` faces along its **-Z**, so the yaw that aims it along `wish` is
  `atan2(-wish.x, -wish.z)`. The obvious `atan2(wish.x, wish.z)` faces away.

Both are now pinned by tests in `tests/test_camera_and_controls.gd`.

### A skipped test script is a failing test script

GUT prints a warning and exits 0 when a test script will not compile. Two of
the new P1 test files did exactly that — 40 tests were silently not running
while CI would have reported green. `tools/run_tests.sh` now counts the scripts
GUT ran against the files on disk and fails when they disagree; CI calls the
wrapper instead of `gut_cmdln.gd`. Verified by deliberately breaking a test
file and checking the wrapper exits 1. Affects §8.

### `Main.show_screen` checks the type, not just the path

`ResourceLoader.exists()` is true for any file at that path. A scene whose
script fails to compile loads as `null`, and a non-scene resource loads as the
wrong type — both reached `instantiate()` and took the screen down. It now
casts to `PackedScene` and refuses anything else, leaving the player on the
screen they were already on.

### Performance in the web build

Measured by temporarily printing Godot's own `Performance` monitors from the
Street scene, exporting to Web, and reading the browser console while walking
the block. The instrumentation was removed before commit.

| Metric | Budget (§1) | Measured | |
|---|---|---|---|
| Draw calls per frame | < 150 | median 15, max 22 | well inside |
| Primitives per frame | < 100k | median ~1.0k, max 1.4k | well inside |
| Web `.pck` | — | 716 KB | +77 KB over P0 |

The budget has a lot of room because the block is primitives with flat
materials and Godot culls aggressively — at any moment only a fraction of the
street is on screen.

**Frames per second could not be measured here and is not reported.** The only
browser available in this environment runs SwiftShader, a software rasteriser,
at 1080×1920 in a container; it reported 1 fps, which says nothing about a
phone. P1's gate — "30 fps on a mid-range phone" — is therefore **not yet
met, only un-blocked**: it needs the device matrix in the README, on hardware.
Affects §3 P1, §11.

---

## P2 — Flags and data (2026-10-19)

### Owner overrides of the brief, recorded verbatim in effect

The repository owner, on 2026-10-19, after playing the P1 APK:

1. **"It can't be just grey boxes, it has to have texture."** Overrides
   CLAUDE_CODE_BRIEF.md §4.1 ("no textures, no licensed packs in the slice")
   and §6's grey-box placeholders.
2. **"Don't worry about the under 60 MB rule."** Overrides the §1 install
   budget. The APK size check in `android.yml` now reports but no longer fails.
3. **Controls must be shown, by device,** and movement must not fight the
   camera. Overrides nothing — this was a bug and a missing screen.

What still holds: §6 "do not pull assets from the internet". Every texture is
generated by `tools/gen_textures.py` in the GDD §10 palette, tileable, and
replaceable 1:1 by painted art. No licensed pack was added. GDD §10's painted
stylized direction (not photoreal) is unchanged; GTA-level fidelity was asked
for and declined as out of reach for this slice and this team. Affects §1,
§4.1, §6, §10.

### Every thumb swung the camera: one input path, not two

Android emulates mouse events from touches and the street script treated any
mouse drag as a camera orbit, so a thumb on the joystick also turned the
camera. The mouse-motion path is gone. All pointing input is screen touches;
on desktop the mouse is emulated *into* touches (`emulate_touch_from_mouse`),
so a right-half mouse drag orbits exactly as a thumb would. Drag sensitivity
dropped from 0.006 to 0.0042 rad/px. Affects §4.2.

### A controls card, once per journey, by device

GDD §11 lists a first-launch note; it is now the "How to play" card shown on
*Begin* until *Play again*. It picks touch or keyboard wording from
`DisplayServer.is_touchscreen_available()`. It says how to walk, look and
climb and nothing about where to go (§4.3). The joystick also draws a faint
resting ring for the first eight seconds of play, then the HUD empties.
Affects GDD §11.

### Quest progress is derived, never saved

GDD §12: nothing is conditional on anything but flags and the beat. So the
quest machine stores no step index of its own in the save: on load it
re-walks `complete_when` against the flags and events and lands where it was.
A quest can therefore never disagree with the flags that explain it. Events
(things the world did: a can placed) are a second set beside flags (things the
player chose) because the debug panel and the condition language read them
apart; both persist. Affects §5, GDD §12.

### `end_condition` must not pre-empt a branch

Found by the give-path test: the carry step set `gave_dry_fountain`, and in the
same pass `end_condition` ("gave or took") ended the quest before the *give*
branch had been re-checked, so no journey line was written. A pass now hands
back to `reconcile()` as soon as a step changes a flag, and branches are
checked at the top of every pass before `end_condition`. Affects §5.

### Lines with no cards may carry their own `sets`

The fountain's giver line — "It's dry. The shop beside it is full of water." —
offers no choice, yet looking must leave a mark. A line may carry a line-level
`sets`, applied when it is shown; a tap anywhere dismisses it. The card format
of §5 is otherwise unchanged and a card with `next: ""` ends the conversation.

### Cards are PanelContainers, not Buttons

A Godot `Button` with autowrap measures its minimum height before it has a
width, so it wraps per character and a six-word card came out a thousand
pixels tall. Each card is a `PanelContainer` with a wrapping `Label` and its
own press handling, styled through a `ChoiceCard` theme variation shared by
every card — no icon, no colour, no size difference between them (GDD §6).

### Cards are shown in authored order

§10 forbids an ordering convention that hints at a correct answer. Shuffling
would enforce it mechanically but makes re-reading a line harder for a tester;
the order is the data's, and varying it is the writers' and the review panel's
job (GDD §15). Revisit if playtests show a first-card bias.

### GUT skips a broken test script and still passes — guarded

Two P2 test files failed to parse (an `:=` on a boolean `or` expression, which
GDScript cannot infer) and GUT warned and ran the rest with exit 0.
`tools/run_tests.sh` from P1 caught it. The rule stands: run the suite through
the wrapper, never `gut_cmdln.gd` directly.

### `Street.tscn` is generated, and the generator is committed

P1 generated the scene from a scratch script and committed only the `.tscn`.
With kerbs, lamp posts, window bars, rooftop tanks, fence rails, road markings
and vehicles with wheels, the rules are far easier to read than the 1,300-line
scene they produce. `tools/gen_street.py` is the source; CI fails if the
committed scene is stale (`--check`). Editing the scene in the editor is fine
for trying things, but the change goes into the generator. Affects §2.

### Repeated props are MultiMeshes

Lamp posts, lamp heads, road dashes, window panes, bars and ledges, water
tanks, AC units, fence posts and rails: one draw call each however many there
are. The whole block is ~145 node blocks and 11 MultiMeshes.

### Shadows are on

§1 said no real-time shadows. With textured surfaces, depth was unreadable
without them, and the owner has lifted the budget. One orthogonal 2048
directional shadow, 70 m, hard-filtered on mobile. **This is the biggest
unmeasured cost on the 2020 mid-range target**; if the phone stutters, this
is the first thing to turn off. Affects §1.

### Performance in the web build (textured, shadowed)

| Metric | Budget (§1) | P1 | P2 | |
|---|---|---|---|---|
| Draw calls per frame | < 150 | median 15 | median 72, max 90 | inside |
| Primitives per frame | < 100k | ~1.0k | median 9.6k, max 10.6k | inside |
| Web `.pck` | — | 716 KB | 4.8 MB | textures |

Frames per second is still unmeasured: the only browser here is a software
rasteriser, now at ~1 fps with shadows. Worse, Godot caps physics at eight
steps per rendered frame, so the game *simulated* at about an eighth speed in
that harness — which is why a browser-driven walk no longer reached the
fountain wall in the time the P1 harness allowed. The end-to-end tests run at
full speed and pass. Device testing is the only honest fps measurement.

### First real CI runs (incident cleared)

Once GitHub's incident cleared, the first runs that actually executed showed:

- **CI: green.** Lint, format, data checks, generator checks and 102 tests
  pass on GitHub's runner, not only here.
- **Android: failed in `android-actions/setup-android@v3`** before any step
  of ours — it runs `sdkmanager tools`, a package Google has removed. Dropped
  the action; the runner image already carries an SDK, and we install the
  three packages Godot needs with its own `sdkmanager`.
- **Web: the export succeeded; `configure-pages` failed** because Pages is
  not enabled on the repository. Set `enablement: true` so the action asks
  for it; if the token may not, it is one setting by hand.
Affects §8.

---

## Documents (2026-10-19)

GDD revised 19 Oct: days/lives and §18 added; all out of scope for Slice 1 per
brief §0; chapters have no clock (GDD §16a).

`docs/BRIEF_AMENDMENT_1.md` added. It amends `CLAUDE_CODE_BRIEF.md` and wins
where the two conflict: controls (A), visuals (B), the size budget (C, now
250 MB) and desktop/web testing (D). Its items are applied in their own pull
requests and each is recorded here as it lands.
### Amendment 1 §D: desktop builds as artifacts

`desktop.yml` exports Windows and Linux on every push to `main` and attaches
each as a zipped workflow artifact (30 days). A Linux preset joins the Windows
one. The README's desktop and browser sections now follow §D, including why
the Web preset runs single-threaded. Affects brief §8, amendment §D.
## Amendment 1 — controls and visuals (2026-10-19)

Applied from `docs/BRIEF_AMENDMENT_1.md` §A, §B and §C in one feature PR
(§D's CI changes went separately).

### §A controls, as built

- **Zones** 45 / 55 by touch index; the joystick floats under the first
  left-zone finger. A touch on the contextual or pause button never reaches
  a zone.
- **Dead zone 12%, cubic response, auto-run at 85% raw deflection after
  0.5 s.** The run timer reads the raw deflection, not the curved vector, or
  the cube would hide a full push from it.
- **Tap-to-walk**: under 200 ms and 10 px on the right zone; raycast through
  the camera to the world; the stick cancels it. On desktop a click is a tap.
- **Camera auto-align** after 1.5 s of running with no drag; touch
  sensitivity defaults to half of desktop; follow lag 0.15 s; FOV 65→72;
  head-bob at a run.
- **Controls card** by scheme (touch / desktop / gamepad, gamepad winning when
  one is connected) with a drawn diagram, on first *Begin* and always from the
  pause menu. A pulsing "drag here to walk" sits in the left zone until the
  first move, at most 60 s.
- **Settings** (joystick side/size/opacity, sensitivity, inversion,
  tap-to-walk) are read from `GameState.settings` with device defaults; the
  screen that edits them is still P6.
- **Not done:** §A's acceptance test ("two people, 60 seconds, no
  instruction") needs people. Owner, please run it with the APK.

### §B visuals, as built

- 1024 px procedural textures with a painted pass (`stylise()` in
  `tools/gen_textures.py`); CC0 Poly Haven textures through the same pass via
  `tools/fetch_polyhaven.py`, each with a row in `docs/RIGHTS_REGISTER.md`;
  the `overcast_soil_puresky` HDRI as the sky. Nothing from any other source.
- Density: kerbs, markings, lamp posts, barred windows, tanks, AC units,
  awning and shop signs in an invented script, cables, six trees, two parked
  cars. Repeated props as MultiMeshes.
- Characters: a jointed low-poly humanoid of primitives with a procedural
  walk/idle (`figure_animator.gd`) for the player and pedestrians. A **CC0
  rigged model was tried and not landed**: Quaternius's packs are CC0 but ship
  FBX/OBJ/Blend behind an itch.io download widget, and this environment has
  no FBX importer; Kenney's pages were not reachable by slug. Revisit with a
  GLB source or by converting once on a workstation.
- **Lighting: real-time shadow as a stand-in.** §B5 wants baked LightmapGI;
  Godot 4.3 cannot bake headless, so the `LightmapGI` node is in the scene
  ready to bake in the editor and `REALTIME_SHADOW_STANDIN` in the generator
  keeps one directional shadow until then. First thing to flip if a phone
  stutters.

### §C budget, as measured in the web build

| Metric | Limit | Measured |
|---|---|---|
| Draw calls per frame | < 200 | median 114, max 140 |
| Primitives per frame | < 150k | median 16.5k, max 17.9k |
| APK | 250 MB | 61 MB |

`tools/` carries a `.gdignore` so generators never ship.

### Fixes from the P2 phone playtest

- **Stuck at the kerb.** A `CharacterBody3D` has no step-up; the 16 cm kerb
  was a wall. `_step_up()` sweeps ahead, up and ahead-again with `test_move`
  and lifts the body over anything under 0.36 m. Walls stay walls (tested).
- **People and cars walked through the player.** Brief §4.1 made ambience
  non-reactive; in play it read as broken. Movers now carry a collision body
  and **yield**: a pedestrian stops 1.6 m short of a player in its lane, a
  vehicle 9 m, both go on when the lane clears. They still never speak,
  follow or notice the player otherwise. Affects §4.1.
- **Minimap, off by default.** Owner request. GDD §6 rules out a map with
  markers; this one has none — the block's footprints and the player's dot,
  built from the scene at runtime — and is toggled from the pause menu, which
  also lists the controls. A pause button sits top-left (GDD §11).

---

## P3 — Listen and Tulu (2026-10-19)

### Amendment §A acceptance test: passed

The owner ran the two-person, sixty-second, no-instruction test with the
amendment-1 APK and reported it through. Recorded here as the gate for §A.

### Audio placeholders are generated, as OGG

`tools/gen_audio.py` (numpy + soundfile) writes Tulu's three notes (G4 A4 C5,
a soft triangle with vibrato, on a 4 s loop), the player's hum, a street bed
and a water loop, each documented in the script for the composer to replace
1:1 (brief §6). Vorbis encoding is not byte-stable across libsndfile builds,
so `--check` asserts the files exist and are not empty rather than comparing
bytes. The loop flags live in the `.import` files, which are committed.

### The contextual button idles as a faint mark

GDD §11 says the button "appears only near something usable"; GDD §6's Call is
"hold the interact button with nothing nearby". Both cannot hold at once. The
button now idles at 35% opacity labelled "…" (a string id, `verb.idle`), takes
its verb when something is near, and a half-second hold with no verb showing
is the hum. On desktop E does the same. Affects GDD §6, §11.

### `hum_count` is a field on the journey

Brief §4.2 says "Track hummed count"; GDD §6 sets the flag `hummed` at three.
A count is not a flag, so `GameState` carries one integer, `hum_count`,
persisted with the rest, and sets `hummed` on the third. It is never shown to
the player and is not a score. Affects §5, GDD §12.

### *Listen* is generic; Tulu is its first consumer

`Interactable` (an Area3D with a verb id) is the one mechanism behind the
button. Any node in group `sound_source` that owns one gets the camera drift
and the subtitle for free. The street scans the player's overlapping
interactables each physics frame and shows the nearest's verb.

### Tulu's behaviour, as built

Waits at the fountain's edge humming (positional, `max_distance` 24 m, faint
past ~15 m). *Listen* plays the notes clearly, sets `heard_tulu`, drifts the
camera for 1.5 s and sends him along four pavement waypoints to the chai
stall's back door, pausing whenever the player is more than 8 m behind. Ignored
for 20 s, he follows at about 5 m. After `heard_tulu`, a hum anywhere within
40 m is answered with his notes from wherever he is (GDD §6 "Call"). He does
not path-find: the waypoints go round the stall, not through it.

### The pause menu's one line

GDD §6: "A single line at the top of the pause menu says what the player is
doing now." Until `heard_tulu` it is *Somewhere a boy is humming.* (brief
§4.3); after, the active quest step's objective text in the character's voice;
with nothing active, *The boy went behind the chai stall.* Still no marker,
arrow or objective on the HUD — a test holds that line.

### Performance in the web build (P3)

| Metric | Limit (amendment §C) | Measured |
|---|---|---|
| Draw calls per frame | < 200 | median 141, max 171 |
| Primitives per frame | < 150k | median 18.2k, max 19.8k |
| Web `.pck` | — | 27 MB |

Tulu adds one figure and two audio players; the rise from P2 (114 → 141) is
mostly the camera angle of the measured walk. Frames per second remain a
device measurement.

## 2026-10-19 — Visual assets: a fountain that reads as one, CC0 models for the dressing

After the P3 acceptance test the owner said the arrival area did not look
like a fountain and asked for every graphic element — cars, people, the
street furniture — to be improved with free assets from the internet.
`docs/BRIEF_AMENDMENT_1.md` §B2 limits that to CC0 (Kenney, Poly Haven,
ambientCG), entered only through a fetch tool that writes the rights
register. Affects GDD §4 (Hollow Vale), §10 (look), amendment §B3, §C.

### The fountain (GDD §4: "climbs out of the dry basin of a public fountain")

Was a 14 m square pit with 1.8 m walls and a stub in the middle: a tank, not a
fountain. Now, in `tools/gen_street.py`: a round sunk basin (radius 5.6 m,
floor 0.5 m below the street) with a stone lip (a squashed torus, the only
curved primitive Godot gives us), a tiered column — pedestal, shaft, two dry
bowls on cone undersides, a spout, a finial — a step of pavement 0.15 m down
round the lip that fills the square ground gap to its corners so no seam
shows, rusted cans on the dry floor, and benches facing it east and west.
The player surfaces beside the column (2.4 m east of it), so due north is
clear floor up to the lip and the climb out; the climb point and its exit
marker are unchanged in meaning. The lip is 1.1 m above the basin floor:
above the step-up (0.36 m), so the climb stays the only way out.

### CC0 models and how they enter

- `tools/fetch_kenney.py` (new): Kenney *Car Kit* (seven cars) and *Nature
  Kit* (four trees, two bushes) as `.glb`, from kenney.nl's zips, with their
  `LICENSE.txt` beside them and a row each in `docs/RIGHTS_REGISTER.md`.
- `tools/fetch_polyhaven.py` now fetches models too: street lamp, modular
  bench, fire hydrant, covered car, rusted can, plastic crate, manhole cover.
  A Poly Haven model is a photoscan — the hydrant alone was 86k triangles
  and 5 MB of maps — so the tool keeps only what the game renders: the
  albedo at 512 px through the same `stylise()` pass as the textures,
  normal/roughness/AO maps dropped, the mesh decimated
  (`fast-simplification`, multi-pass, gentle aggressiveness because the
  aggressive setting ate the bottom metre of the lamp post) to the budget
  in `MODEL_TRIANGLES`, written as one `.glb`. Seven models: 840 KB,
  13k triangles in total. `island_tree_01` (64 MB) was dropped for the
  Kenney trees. `--check` needs none of the extra libraries.
- `scripts/street/model_batch.gd` (new): a `.glb` instanced twenty times is
  twenty sets of draw calls; `ModelBatch` instantiates it once, lifts out its
  meshes and draws each as a MultiMesh with the placements the generator
  writes — one draw call per surface for every lamp post, tree, hydrant and
  can. Moving cars and one-off parked cars are direct instances. Collision
  stays the generator's business: plain box colliders beside each batch.
- The vehicles on loops are now Kenney's taxi, van and sedan (scaled 1.6×,
  turned half round because the kit faces +Z); parked: SUV, hatchback,
  delivery van outside the shop, a truck on the north road, and Poly Haven's
  car under a tarp.

Not done, and why: a rigged, animated human. The CC0 packs that have one
ship FBX or sit behind a download widget; there is no FBX importer or
editor in the cloud. The steps for the owner are in
`docs/RIGGED_CHARACTER.md`; the figures stay primitives until then.

### Lighting

Shaded faces went near-black under the HDRI on the phone: the overcast sky
lights from above and the soil below it gives the undersides nothing.
Ambient is now a flat grey (0.64, 0.66, 0.70) at 1.3 with 45% sky
contribution, the sun 0.95 with shadows at 65% opacity, exposure 1.0. A
first try — sky ambient at 1.35 — washed the whole street white in the
browser build. Still real-time shadow, still the lightmap waiting for an
editor bake (amendment §B5).

### Performance in the web build (this change)

| Metric | Limit (amendment §C) | P3 | This change |
|---|---|---|---|
| Draw calls per frame | < 200 | median 141, max 171 | median 155, max 227 |
| Primitives per frame | < 150k | median 18.2k, max 19.8k | median 40.8k, max 48.8k |
| Web `.pck` | — | 27 MB | 30 MB |
| Models on disk | — | — | 7 Poly Haven 0.8 MB, 13 Kenney 0.4 MB |

Measured on the same walk as P3 (surface, look round, climb out, look
round) with the parts-per-material join in place; before it the median was
222. The maximum, 227, is the one angle looking south along the road past
every car, lamp and flat with their shadow passes — over the budget there,
inside it elsewhere. Cutting the directional shadow distance from 70 m to
45 m was tried next and re-measured: median 155, max 224 — no real change,
because what crowds that angle is within 45 m anyway. Left at 45 m (it
costs nothing). The remedy for the peak is the lightmap bake (§B5), which
removes the shadow pass altogether, not fewer props.

## 2026-10-20 — Rigged humans: Kenney's animated characters through Godot's FBX importer

The owner asked for real hands and legs on the people and, after the visual
pass, for a rigged character with a true walk. Affects GDD §4 (people on the
street), §6 (the player's body), amendment §B4.

### What was tried first, and why it changed

The earlier note (`docs/RIGGED_CHARACTER.md`, now rewritten) said a rigged
CC0 human needed a desktop: the packs are FBX and there was no importer
here. Wrong on the second half: Godot 4.3's built-in FBX importer (ufbx)
reads Kenney's files headless — the body as a skinned mesh on a 58-bone
skeleton, each clip as an AnimationPlayer. Verified before building.

### What was built

- `tools/fetch_kenney.py` gained `FILES`: paths taken as shipped from a kit.
  *Animated Characters Retro*: the body, `idle`/`run`/`jump`, two human
  skins. FBX stays FBX; Godot imports it.
- `scripts/characters/character_rig.gd` (`CharacterRig`): instances the
  body, scales it to a given height (Kenney's is 3.7 m tall at scale 1,
  turned half round because it faces +Z), paints the skin on its one
  material, and fills an AnimationPlayer rooted at the body with the clips,
  looped and shared through a cache so eight humans hold one copy of each.
  It reads motion from its own position delta, as the procedural walk did,
  so the player, Tulu and the pedestrians drive it identically; idle, walk
  and run are chosen by ground speed, with the clip's `speed_scale`
  following the speed so feet do not slide.
- `scenes/characters/Character.tscn` holds the data: which scene and
  animation is idle, walk and run, the reference speeds, the height. The
  player, Tulu (scaled 0.72) and the six pedestrians instance it with a
  `skin`. `figure_animator.gd` and the primitive figures are gone.

### The walk

Kenney's pack has idle, run and jump — no walk. The walk is the run clip
at `walk_reference_speed` 2.4 m/s, so at the player's 2.2 m/s it plays at
0.9×: a brisk jog rather than a stroll, honest about being a placeholder.
A true walk comes from Quaternius' *Universal Animation Library* on the
*Universal Base Characters* rig (CC0), which only itch.io serves to a
browser; the owner is fetching those (steps in `docs/RIGGED_CHARACTER.md`),
and swapping them in is a change to `Character.tscn`, not to code.

### Budget

Skinned meshes cannot be batched: eight humans are eight draw calls each
frame (plus shadow). Numbers below.

| Metric | Limit (amendment §C) | Visual pass | This change |
|---|---|---|---|
| Draw calls per frame | < 200 | median 155, max 224 | median 108, max 176 |
| Primitives per frame | < 150k | median 40.8k, max 48.7k | median 44.6k, max 53.3k |
| Web `.pck` | — | 30 MB | 32 MB |

Same walk as before. Fewer draw calls, not more: each primitive figure was
fifteen boxes and spheres, each a draw call with its shadow; a skinned
human is one mesh. The peak angle along the road is now inside the budget.
Checked in the browser build: the body faces the way it walks, stands
1.75 m, wears its skin, and pedestrians play the run clip on their loops.


## 2026-10-20 — Retargeting: one humanoid profile for every body and clip

The true walk comes from a different rig than the body (Quaternius'
animation library on Kenney's human), so bodies and clips now go through
Godot's `SkeletonProfileHumanoid` at import. Affects amendment §B4.

- `assets/characters/kenney_humanoid_map.tres` and
  `quaternius_humanoid_map.tres` are hand-written BoneMaps (Mixamo-style
  names and Unreal-mannequin names respectively onto the profile). The
  fetch tools write them into each model's `.import` under
  `retarget/bone_map`, so the setting survives a refetch; the importer
  renames the bones to the profile's names and the skeleton node to
  `GeneralSkeleton`.
- `CharacterRig` re-points each clip's bone tracks at the body's skeleton
  node and drops non-bone tracks (a clip's own root node means nothing on
  another body).
- **`fix_silhouette` is required.** With the bone map alone (the default
  `overwrite_axis` on, silhouette off) Kenney's own clips came out rolling
  the arms about their length axis: the characters stood in a T-pose and
  the hands moved 0.16 m over a run cycle against 1.21 m unretargeted.
  Measured in a scratch project across settings, run clip on each body:

  | Setting | Kenney body, hand swing | Quaternius body, hand swing |
  |---|---|---|
  | no retarget | 1.21 m | — |
  | bone map only | 0.16 m | 0.05 m |
  | + fix_silhouette | 1.11 m | 0.59 m |
  | overwrite_axis off | 1.21 m | 0.59 m |

  (The Quaternius body is 1.6 m to Kenney's 3.7 m, so 0.59 m is the same
  swing.) `fix_silhouette` is the documented path for cross-rig clips and
  keeps the axes normalised, so it is the one used.


## 2026-10-20 — The true walk: Quaternius' Universal Animation Library on Kenney's body

The owner asked for a true walk and fetched Quaternius' packs through a
browser (itch.io serves nothing else) onto a release of this repository.
Affects amendment §B4; GDD §6 (the player's body language).

- `tools/fetch_quaternius.py` (new): takes the listed files out of a release
  asset, writes the retarget `.import` for rigged files
  (`tools/retarget_import.py`, now shared with `fetch_kenney.py`) and the
  rights-register rows. The library is one GLB with 43 clips on the
  universal rig; Godot drops the `_Loop` suffix on import, so the names are
  `Idle`, `Walk`, `Jog_Fwd`, `Sprint`, `Interact`, `PickUp_Table`, …
- `Character.tscn` now points idle, walk and run at that GLB. Kenney's own
  `idle`/`run`/`jump` clips left the repository with the slowed-run
  placeholder: nothing used them.
- The free *Universal Base Characters* tier has superhero suits only, so
  the body stays Kenney's human in a shirt and jeans (GDD §10: "an ordinary
  coat"). The library's walk reaches it through the humanoid profile.
- `CharacterRig` keeps only bone **rotation** tracks from a clip. Position
  tracks carry the source rig's offsets: the library's hips height, applied
  under Kenney's hips-control bone, lifted the body 1.5 m off the ground.
  Rotations alone carry the walk; the vertical bob is lost, which at this
  size is not visible.
- Reference speeds: Walk at 1.5 m/s (its 1.33 s cycle at the player's
  2.2 m/s plays at 1.5×, a brisk walk), Jog_Fwd at 3.6 m/s; the run
  threshold stays 3.2 m/s.

### Performance in the web build (this change)

| Metric | Limit (amendment §C) | Rigged (Kenney clips) | This change |
|---|---|---|---|
| Draw calls per frame | < 200 | median 108, max 176 | median 108, max 169 |
| Primitives per frame | < 150k | median 44.6k, max 53.3k | median 44.6k, max 56.6k |
| Web `.pck` | — | 32 MB | 32 MB |

Same walk as before. The library GLB (7.4 MB on disk) replaces three Kenney
clips of 1.7 MB; the `.pck` size held because the Kenney clips' skeletons
went with them. Checked in the browser: idle stands relaxed, the walk
strides, the jog runs, feet on the ground.


## 2026-10-20 — People dressed differently; a desktop scheme without the joystick

Two owner reports after the walk landed. Affects GDD §4 (the crowd),
amendment §A5 (schemes).

### Skins

Everyone wore one of two outfits. Kenney's *Protagonists* and *Survivors*
packs share the body, so their human skins come in through
`tools/fetch_kenney.py` (zombies and the cyborg stay out): seven skins now,
the player in `humanMaleA`, Tulu in the skater, the pedestrians cycling
the other six. `tools/gen_street.py` carries the list (`SKIN_PACKS`,
`PEDESTRIAN_SKINS`); a test holds that at least six outfits are on the
street.

### Pedestrians walked backwards

The path mover turned +Z toward its travel while the rig's body faces -Z
(as the player's and Tulu's do). Fixed in `path_mover.gd`; a test holds
that forward (-Z) points along the travel.

### Desktop web and mobile web differ now

`ControlsHint.detect_scheme()` already told touch, desktop and gamepad
apart for the controls card; the controls themselves showed the joystick
everywhere. `TouchControls.apply_scheme()` now hides the joystick on
desktop (a browser on a PC included: `web` without a touchscreen) and
gamepad, and the hidden joystick claims nothing, so a drag anywhere orbits
and W A S D or the left stick move. Touch is unchanged. The scheme is
re-read when a gamepad connects or disconnects. Tests that drive the
joystick opt into touch explicitly, because the test runner has no
touchscreen and would otherwise get the desktop scheme.


## 2026-10-20 — Quaternius trees and cars replace the Kenney kits

The owner fetched Quaternius' *Textured Stylized Trees* and *Realistic Car
Pack* (both CC0) onto the release and asked whether they beat what was in.
They do: the trees are textured and real-size where Kenney's were
114-triangle blocks; the cars are life-size with real proportions where
Kenney's were toy-scaled 1.6×. Affects amendment §B3; GDD §4 (traffic).

- Both packs ship FBX and OBJ, no glTF. The FBX trees reference no
  textures (Godot imported them white) and the FBX cars carry six surfaces
  and four wheel nodes each. So `tools/fetch_quaternius.py` converts the
  OBJ with trimesh: trees get their textures bound by material name from
  the pack's texture folder (`Bark` → `Tree_Bark.jpg`, leaves alpha-masked
  and double-sided); cars get their MTL colours baked into vertex colours
  (×1.25, undoing Blender's 0.8 Kd export factor) and every part joined, so
  a car is one draw call as before. One `.glb` per model, 1.2 MB for six
  cars, 3.5 MB for six trees.
- The pack's blue, cyan, pink and purple leaf textures stay out (GDD §10,
  peacock blue and magenta forbidden); green, birch and pine are used.
- The Kenney car kit and its trees left the repository; the bush stays.
  `tests/test_model_batch.gd` now exercises a Quaternius car and the bush.
- Trees are 2 surfaces each in 3 kinds (6 draw calls plus shadows) against
  2 kinds before; cars unchanged at one. Numbers below.

### Performance in the web build (this change)

| Metric | Limit (amendment §C) | Before (Kenney kits) | This change |
|---|---|---|---|
| Draw calls per frame | < 200 | median 108, max 169 | median 112, max 177 |
| Primitives per frame | < 150k | median 44.6k, max 56.6k | median 55.6k, max 68.3k |
| Web `.pck` | — | 32 MB | 36 MB |

Same walk as before. The textured trees cost ten thousand triangles and four
draw calls more than the blocks; still well inside. Checked in the browser:
the birches and broadleaf trees read as trees at street distance, the cars
sit at the kerb at real size.


## 2026-10-20 — P4: The Dry Fountain

CLAUDE_CODE_BRIEF.md §4.4, GDD §7 "The Dry Fountain", §12 (the flag model).
All three outcomes play from `data/quests/dry_fountain.json` and
`data/dialogue/en.json`; no code reads a path.

### What was built

- **The fountain as a giver** (`scenes/quest/FountainPoint.tscn`,
  `scripts/quest/fountain_point.gd`): *Look* opens the fountain's one line,
  whose `sets` marks `looked_dry_fountain`. *Place* is an Interactable with
  `requires = ["gopal_will_carry"]` — a new, data-only field on
  `Interactable`: the verb is offered only while the flags hold — and is
  enabled only while the player carries. It fires `can_placed_at_fountain`;
  the quest's carry step sets `gave_dry_fountain`; the water plane rises over
  six seconds from the basin floor and the water loop starts. A can taken
  without him can never be placed: the fountain stays dry on that path.
- **Gopal Seth** (`scenes/npc/Gopal.tscn`, `scripts/npc/gopal.gd`) behind
  his counter, the survivor skin. *Talk* opens the first of `entry_lines`
  (data on the scene: after-give, hurt, agree, decline, greet) whose
  `requires` the flags meet; two lines gained `requires` in the dialogue
  file so the order works. Once he has agreed and the player picks up a
  can, he walks with them holding his own can, and goes back behind the
  counter after the placing.
- **The cans** (`scripts/quest/can_stack.gd`, generated into the shop): a
  row on the pavement in front of the counter the player can *Pick up*
  from, one at a time; the rest stay stacked behind. Picking up fires
  `can_taken_from_shop`; the quest's `take` branch (`event and not
  flag:gopal_will_carry`) sets `took_dry_fountain` and writes the journey
  line. Carrying is the flag `carrying_can`, so it survives an autosave;
  the body shows the can in the right hand (`CharacterRig.carry()`, a
  `BoneAttachment3D`; the item is scaled back to world size).
- **The light answers** (`street.gd`, `MOODS` data): a taken can cools the
  sun and drops ambient to 0.85×; a given can warms it and lifts ambient
  to 1.12×, easing over four seconds; a loaded journey applies it at once.
- **Choice cards** are now bound to the dialogue in the street (they were
  only in the debug panel). No icon, colour or order marks an answer.

### Decisions

- The quest's first step, *notice*, also completes on
  `gopal_admitted_fear`: a player who talks to Gopal before looking at the
  fountain has noticed it. Steps are sequential by design (the runner
  re-derives progress from flags); this keeps the give path reachable in
  either order without a path variable.
- The ignore path needs nothing: no flag, no timer. The end of the slice
  (bus stop, P6) is where it resolves.
- Water is a dull grey-green (`assets/materials/water.tres`): peacock blue
  is forbidden in the Street.

### Performance in the web build (this change)

| Metric | Limit (amendment §C) | Before | This change |
|---|---|---|---|
| Draw calls per frame | < 200 | median 112, max 177 | median 112, max 182 |
| Primitives per frame | < 150k | median 55.6k, max 68.3k | median 56.2k, max 70.4k |

Same walk as before. Gopal (one skinned mesh), the fountain point and the
cans on the pavement add a handful of draw calls at the shop angle.


## 2026-10-20 — P5: the Glimpse and the feather

CLAUDE_CODE_BRIEF.md §4.5, GDD §6 "Glimpses", §10 (the one peacock blue).

- `scenes/quest/Glimpse.tscn` sits on the traffic-light beam, placed by the
  generator. The figure is the shared rigged body painted with an unlit
  near-black material (`CharacterRig.paint_all`), playing the library's
  `Sitting_Idle`, a flute in the hand through the same carry mechanism the
  can uses, a feather quad in the hair, and an OmniLight behind it in a
  warm orange nothing else in the scene has. PLACEHOLDER for the extruded
  silhouette of GDD §10.
- Trigger: the flag `gave_dry_fountain` being set while
  `glimpsed_traffic_light` is not. Never a timer, never `took_`. The scene
  itself sets `glimpsed_traffic_light` when it ends, so it happens once per
  journey; a test holds that a long wait and the took path do nothing.
- Ends after `seconds` (5) or when the player is within `end_distance`
  (6 m): the silhouette fades over 0.5 s, the feather pick-up on the
  pavement below the pole becomes visible, *Your journey* gets exactly
  *"You thought you saw someone on the traffic light."* The feather is the
  only peacock blue in the Street (`assets/materials/peacock_feather.tres`).
- Tulu looks up: `look_up_at()` turns him to the point and tilts him back
  for 2.5 s. Pedestrians have no such method and do not react.
- Carrying became general: the player's `carryables` (data on
  `Player.tscn`: `can`, `feather`) map an item id to the scene shown in the
  hand, each a flag `carrying_<item>`; one thing at a time. Picking the
  feather up fires `feather_picked_up` so a loaded journey does not lay it
  down again, and sets nothing else: nothing happens, as the brief says.
- The pause menu now lists *Your journey* (GDD §6; the brief names the pause
  menu as where the line is recorded), hidden until it has a line.

### Budget, as measured in the web build

| Metric | Limit (amendment §C) | P4 | This change |
|---|---|---|---|
| Draw calls per frame | < 200 | median 112, max 182 | median 112, max 178 |
| Primitives per frame | < 150k | median 56.2k, max 70.4k | median 56.1k, max 68.2k |
| Web `.pck` | — | 36 MB | 36 MB |

Same walk as P4, with the Glimpse not showing (it is the single skinned
mesh and one omni light for five seconds once a journey, and the measured
walk never sets `gave_dry_fountain`). The numbers are within noise of P4's:
the silhouette scene, hidden, costs nothing, and the feather pick-up is one
quad. Frames per second remain unmeasured here (software renderer only).


## 2026-10-20 — P6: the end of the slice, settings and sound cues

CLAUDE_CODE_BRIEF.md §4.6 and §7, GDD §11. Affects §3 (the bus stop as the
end), §11 (accessibility), §12 (`settings` on the journey).

### The ending is a place, with its conditions as data

- `scenes/quest/BusStopPoint.tscn` sits at the bus stop (generator id
  `15_bus_stop`). An `Area3D` ends the slice when the player walks in with
  any of `ending_flags` set (`gave_dry_fountain`, `took_dry_fountain` on the
  scene, not in code); an `Interactable` *Sit* appears once
  `GameState.play_seconds` passes `sit_after` (90). Both are exports, so the
  playtest can change them without a code change.
- Play time is counted by the street while it is not paused and saved with
  the journey (`play_seconds`), so a resumed journey keeps its ninety
  seconds. It is not shown anywhere: it is not a timer in the brief's sense
  (nothing counts down, nothing is lost), it only unlocks a verb.
- The bus stop says "it is over" and nothing more. The street stops input,
  sits the player if they sat (`CharacterRig.hold_pose("Sitting_Idle")`, the
  same clip the Glimpse uses), fades a full-screen `ColorRect` to black over
  1.6 s and emits `slice_ended(reason)`; `Main` swaps the street for
  `scenes/ui/EndScreen.tscn`. One line, white, 24 px, *Play again* and
  nothing else. *Play again* calls `GameState.wipe()` and returns to the
  title screen, which starts the street afresh.
- No ending screen is a score, a summary or a list: the line is the only
  text (brief §4.6).

### Settings as rows of data

- `scripts/ui/settings_screen.gd` holds `ROWS`: key, kind, default and
  range. The screen builds a label and a `CheckButton` or `HSlider` per row
  from it, reads `GameState.settings` and writes back on every change, which
  autosaves. The street listens for `changed` and re-applies everything in
  `_apply_settings()`, the one place settings become behaviour.
- Joystick side is stored as `"left"`/`"right"` (what the joystick reads);
  the toggle shows "right-handed". Large text sets the root
  `content_scale_factor` to 1.2 rather than per-label sizes: one knob, every
  label, the layouts already flex. The subtitle box is a `StyleBoxFlat` on
  the subtitle label, 70 % dark, 10 px padding.
- Screen-reader labels: Godot 4.3 has no accessibility tree (it arrives in
  4.5). Every control carries its row's label as `tooltip_text`, the one
  field assistive tools on the desktop can read today, and the label sits
  beside it. Recorded as a known gap for the engine upgrade, not a workaround
  to defend.

### Sound cues as ripples

- `scenes/ui/SoundRipple.tscn` is a flat unlit ring (`sound_ripple.tres`,
  additive, warm white) that scales from 0.4 m to 2.4 m and fades over 1.4 s.
  Tulu's is `continuous` (his hum loops); the player's pulses once per hum.
  Every ripple is in the `sound_cue` group and the street turns the group on
  or off from the setting; off by default, invisible when off.
- 1.4 s a ring is 0.7 Hz, well below the 3 Hz flashing limit (GDD §11); a
  test pins the constant.
- Not a marker: it sits at the sound, at ground level, only while the sound
  plays, and only when the player asked for it. The brief's rule against
  markers is about guidance; this is the sound itself made visible.

### What P6 does not do

- The audio bed and the lighting steps were built in P3 and P4
  (`street_bed.ogg`, `MOODS`); nothing more was needed for the gate.
- The lightmap bake (§B5) stays editor-only and is not in this PR; the web
  budget still holds without it (table below).
- "Crash-free on three test devices (document which)" is the owner's to run
  from the release APK; `PLAYTEST_PROTOCOL.md` has the room for it.

### Budget, as measured in the web build

| Metric | Limit (amendment §C) | P5 | This change |
|---|---|---|---|
| Draw calls per frame | < 200 | median 112, max 178 | median 112, max 177 |
| Primitives per frame | < 150k | median 56.1k, max 68.2k | median 56.0k, max 71.4k |
| Web `.pck` | — | 36 MB | 36 MB |

Same walk as P5, sound cues off (the default): the two ripple nodes are
hidden and cost nothing, the bus stop point is an area and a hidden verb,
and the fade rectangle is transparent until the end. The primitive peak
moved by 3k at the south-facing angle, within the run-to-run noise seen
across P4 and P5. Frames per second remain unmeasured here (software
renderer only); the gate's 30 fps on a 2020 mid-range phone is the owner's
device run.

## 2026-10-20 — The world grows: places, doors, a compass (owner expansion, E1)

The owner, after P6: "environment & capabilities should extend", a heading on
the navigation, "different screens of the game's interface", shops to go
into, cars to drive, a showroom to try clothes on, an interface that is easy
on every device; then the whole macro design (docs/GDD.md) built in parallel.
This lifts the brief's "do not scaffold out-of-scope systems" for those
systems. The rules that are about the game's nature (no score, meter, badge,
marker, timer, notification; every flag and string in data; no network) stay.
Affects GDD §5 (four enterable interiors), §6, §11.

### A place is a screen

- `scripts/places/place.gd` is what `street.gd` was: the seam between input
  and the player, the camera and the HUD, pause, settings, the hum, and now
  doors. The street extends it and keeps only its own (bed, moods, the bus
  stop). Every walkable place has the same `%Player`, `%CameraRig`,
  `UI/%TouchControls` footer, written by its generator.
- A door is a node (`scenes/places/Door.tscn`) carrying the place it leads
  to, the spawn point to land on and its verb; a spawn point is a marker
  with an id. Both are data from the generators. Using a door fades to black
  in 0.45 s, records `GameState.place`/`spawn`, and Main swaps the scene
  named in `data/places.json`. The next place fades in from black and puts
  the player on the spawn point facing the marker's way, camera behind.
- The journey remembers the place and the last spawn, so an autosave inside
  a shop resumes inside it, and *Play again* resets both. A fresh journey
  has no spawn and starts in the basin as before.
- One scene at a time: the street is freed while the player is inside a
  shop and rebuilt on the way out. It costs a load, and it keeps every place
  independent (an interior has no sun, no bed, no Tulu). If the load shows
  on a phone, the alternative is to hide the street instead of freeing it.

### Two shop interiors, generated

- `tools/gen_interiors.py` writes `scenes/places/Showroom.tscn` and
  `Store.tscn` from the same textures and CC0 models as the street through
  the shared `tools/scenegen.py` (the street generator was refactored onto
  it; its output is unchanged). Shop fronts on the south flats come from
  `tools/street_parts/shop_fronts.py`.
- Signs are `Label3D` nodes with `scripts/lib/label_from_id.gd`: the words
  come from the string table at run time, so no text is baked into a scene
  and a locale changes the signs too.
- A storekeeper and a tailor with a line each (`scenes/npc/Shopkeeper.tscn`,
  generic: Talk and `entry_lines`), two or three cards, nothing for sale.
  PLACEHOLDER for the people of GDD §4.

### The compass is a heading, not a marker

- GDD §6 rules out "a map with markers". The compass strip
  (`scripts/ui/compass.gd`) shows which way the player faces, nothing else:
  no destination, no distance, no objective. It is the same information as
  the minimap's facing line, readable without opening the map. On by
  default; a settings row hides it. Letters from the string table.

### Generators take parts

- Twenty-odd features are being built in parallel. A registration line in
  one generator would be the one line every branch edits, so the generators
  discover parts instead: `tools/street_parts/*.py` (`build(b)`, optional
  `EXT`), `tools/interiors/*.py`, `tools/audio_parts/*.py`,
  `tools/texture_parts/*.py`, loaded in name order by
  `scenegen.load_parts`. One feature, one file, no line to collide on.


## 2026-10-20 — Daylight: the Street's light moves with the story

GDD §5 (Hollow Vale row: "Arrival: overcast midday, flat, no pink anywhere,
sodium-orange street lamps. Shifts toward dusk as quests complete. Dawn
climb: cold blue to warm. Act 4: dusk, lamplit, the first rose tint allowed
into the sky"), §10 (palette), §12 (flags only). Affects §5 lighting and the
P4 light steps (`MOODS`).

### Stages as data, chosen by flags

- `data/daylight.json` holds ordered stages: `arrival` (`true`),
  `after_fountain` (either Dry Fountain flag), `evening`, `dawn`
  (`on_the_tower`), `remembrance` (`played_for_others or kept_veena`). Each
  carries the sun's colour, energy, elevation and azimuth, the ambient
  energy, the fog colour and density, a sky tint and `lamps_on`. The latest
  stage whose condition holds is the light. Conditions use the quest grammar
  (`scripts/lib/condition.gd`), so the debug panel's flags move the hour.
- "Two or more of" `garden_open`, `counting_man_freed`,
  `bhima_medicine_given`, `rukma_heard` is written as the six pairs joined
  by `or`: the grammar has no counting, and GDD §12 allows nothing but flags
  to decide. `dawn` and `remembrance` reference flags no slice-1 quest sets;
  they are rows of data, not scaffolding, and cost nothing until set.
- `scripts/street/daylight.gd` (`Daylight`, a Node the street adds at
  ready) eases the `DirectionalLight3D` (colour, energy, orientation by
  quaternion slerp), the `Environment` (ambient energy, fog colour and
  density), the sky tint and the lamps over `transition_seconds` (6) when
  the stage changes; a journey loaded mid-story is set at once, no easing
  from midday. There is no clock: no `_process`, no `Timer`; only
  `GameState.flag_changed` moves it, and a test holds that half a second of
  waiting changes nothing.
- The P4 `MOODS` stay in `street.gd` as data and are now a multiplier on the
  stage: sun colour × mood colour, ambient × mood factor. A taken can still
  steps the hour darker and a given one warmer. Because the fountain flags
  set both the stage and the mood, that transition runs over `MOOD_SECONDS`
  (4 s); every other stage change takes the data's 6 s.
- `arrival` reproduces the generator's hand-placed sun exactly (elevation
  44.4°, azimuth 150°, the same colour and energy, the same fog), so P1–P6
  look as they did at the start of a journey; a test checks the light's
  travel vector against the old transform.

### The sky and the ambient

- `PanoramaSkyMaterial` has no tint in Godot 4.3, so the sky is now
  `assets/shaders/sky_tint.gdshader`: the same three-line shader the
  material generates plus a `tint` uniform. Sky reflections (`reflected_light
  _source` = sky) pick the tint up as well. While the tint eases (6 s) the
  sky's radiance map re-renders; outside a transition it is static as
  before.
- `ambient_light_source` was `1`, which is `AMBIENT_SOURCE_DISABLED`: the
  ambient colour, energy and sky contribution in the scene, and P4's ambient
  factor, did nothing. It is now `3` (sky, blended 45 % with the grey) with
  the arrival energy at 1.0 rather than 1.3. **This brightens the base look;
  check it in the web build** and, if the owner prefers the old contrast,
  the one-line revert is `ambient_light_source = 1` in `tools/gen_street.py`
  (the stages then move the sun, fog, sky tint and lamps only).

### The lamps

- `tools/street_parts/lamp_lights.py` puts an `OmniLight3D` (sodium orange
  `(1, 0.62, 0.22)`, range 9 m, energy 1.5, no shadow) on the six lamp posts
  nearest the fountain, group `street_lamp`, hidden until a stage says
  `lamps_on`; `Daylight` fades them in and hides them again when dark, so an
  unlit lamp costs nothing. The posts' positions come from the generator as
  `b.lamp_posts`, so the lights follow the posts if the rows move.
- The six nearest by distance are `(0, 8.2)`, `(±14, 8.2)`, `(±7, 23.8)` and
  `(22.2, -10)` by the chai stall. The brief's `|x| <= 20` rule picks five;
  the sixth is the north pavement's nearest post, so the stall is lit too.
- Six omni lights, hidden by default, is the mobile budget (amendment §C,
  one real-time directional light). Not measured in the web build here (no
  export on the shared machine); the integrator's run should show the same
  draw calls at arrival and at most six more light passes once lit.

### Colour

- No pink before `remembrance`: `evening` is amber (blue below green), `dawn`
  a desaturated grey-blue `(0.78, 0.84, 0.92)` far from peacock blue, and
  `remembrance`'s sky tint `(1.0, 0.86, 0.84)` is the first rose Act 4
  allows (GDD §10: "the first time any pink appears in Hollow Vale is at
  beat 12"). A test guards both rules over every colour in the data.
- "Dawn climb: cold blue to warm" cannot happen inside one stage without a
  clock; `dawn` is the cold start and `remembrance` the warmth, by flags.

### Placeholders

- `assets/shaders/sky_tint.gdshader`: the HDR panorama stands in for the
  painted sky of GDD §10; the tint stays.
- The lamp lights are bare points; the painted lamp head adds an emissive
  glass when the posts are modelled.


## 2026-10-20 — Dawn vignettes: one new stranger a day, from a pool in the build

GDD §16a "Dawn vignettes" ("Every real day, the Street has one new 2–4
minute encounter from a rotating pool ... Missed days queue; nothing is
lost"), §8 (the voice), §6 "Choice" (cards), §12 (flags, one journey
object). Affects §16a (delivery is a folder in the build, not the backend
the section's table names: "No backend" is the rule for the slice) and §12
(one field on the journey).

### What was built

- `data/vignettes/<id>.json`, ten of them: a stranger's name id, a Kenney
  skin, one of three fixed spots (`a`/`b`/`c`), the vignette's own dialogue
  lines in exactly the shape of `data/dialogue/en.json`, the flags its cards
  set (`outcomes`, each `vignette_<id>_<outcome>`) and one journey line. Ten
  short moral situations in the voice of §8: a found ring, a vendor who
  overcharged, a kite in a tree, a letter to carry, a cinema that is no
  longer there, marigolds at dusk, a dog nobody feeds, a parking spot, a
  stopped watch, a notice an old man cannot read. Every line under 20 words,
  two or three cards or none, every line `draft`.
- `scripts/core/vignettes.gd` (`Vignettes`, static like `Places`): loads the
  pool sorted by id; `id_for_date` indexes it by the day count since
  1970-01-01 modulo the pool, so the same date gives the same vignette on
  every device and consecutive days walk the pool in order; `grant_today`
  writes today's date, and every missed day's since the last grant, into
  `GameState.vignette_days`; `pending` is the granted dates, oldest first,
  each vignette once, minus those whose `vignette_<id>_done` flag is set;
  `complete` writes that flag and the journey line.
- `scenes/quest/VignetteSpot.tscn` + `scripts/quest/vignette_spot.gd`: at
  ready it grants today, takes the oldest pending vignette for its letter,
  instances `Character.tscn` with the vignette's skin, adds the vignette's
  lines to the running `Content.dialogue` and offers *Talk*, which opens
  the first line. A card setting an outcome finishes the vignette and closes
  Talk; a conversation left without an outcome leaves it pending.
- `tools/street_parts/vignette_spots.py`: the three spots, at (−3, 0.16,
  9.5) between the fountain and the road, (26, 0.16, 21) by the crossing,
  (−36, 0, 12) along the fence. Empty when nothing is pending.
- `Dialogue.add_lines(dict, source)`: lines in the same shape, added to a
  table already built; `from_dict` now builds through it. The cards UI is
  bound to the one runner and needed no change.

### Decisions

- **Calendar-true, never a timer.** The pick is a pure function of the
  date string (`Time.get_date_string_from_system`). Nothing counts down,
  nothing expires: a vignette granted waits until it is played, and a day
  that passes unplayed is simply another date in the queue (§16a: "No
  streaks, no energy, no countdown timers").
- **The queue is dates, the record is flags.** `vignette_days` says which
  real days were granted; which vignettes were played is a flag like every
  other mark on the journey, so the debug panel, the save file and *Play
  again* already know about it. The backfill after an absence reaches at
  most one pool's worth of days, because older missed days could only repeat
  vignettes already waiting; with the slice's pool of ten, a long absence
  queues all ten, each once.
- **One journey line per vignette, outcome-neutral.** It says who the
  player stopped for ("You stopped for a woman holding someone else's
  ring."), not what they chose: the choice itself is in `choice_history`,
  and no line praises or regrets a card (§6, no correct answer).
- **The stranger's name is a speaker.** `giver_name_id` is
  `speaker.vignette_<id>`, the convention the cards already resolve, so the
  stranger's name appears over their lines like Gopal's does.
- **Spot positions as given.** Spots `b` and `c` stand on the road's edge
  by the generator's layout (the kerbs are 3 m wide); they read as people on
  the kerb line. Nudge in `tools/street_parts/vignette_spots.py` if the
  playtest minds.

### Placeholders

- The stranger's body: Kenney's rigged character with a Kenney skin, named
  by the vignette (`PLACEHOLDER` in the scene and the script); replaced by
  the painted strangers of GDD §10. The ten vignettes are the first ten of
  §16a's 120; the format carries the rest unchanged.


## 2026-10-20 — Stray cows, the slice's smallest form

GDD §3a Act 3 ("Walk ahead of two cows and hum to steer them through
traffic", *Stray cows*: care for what nobody else sees) and §16a "Stray
cows" (guiding them through traffic to the fountain is a timing-and-path
puzzle; the forty handmade layouts and the generator are not this). Affects
§6 (the hum has a second answerer), §7 (one more quest file), §12 (two
events, one flag).

### Two cows, one road, the hum as the only guide

- `scenes/street/Cow.tscn` + `scripts/street/cow.gd` (`class_name Cow`, a
  `CharacterBody3D` on layer 1 so the player bumps into it, groups `cow` and
  `sound_source`). A cow grazes within 3 m of a home spot. The player's hum
  (`Place.hum`, through `sound_source`) calls it: it walks toward where the
  player stood, at most 8 m, then settles there and grazes again, so each
  hum is one leg of the path and the player walks ahead, as the GDD says.
  Reaching within 9 m of the fountain (its outer step) fires
  `cow_reached_fountain_<n>`, an export on the node, and the cow stays: it
  has arrived and later hums do not move it.
- `tools/street_parts/cows.py` places them at (40, 5) and (42.5, 2.5): the
  north pavement east of the north-south road, so the shortest way to the
  fountain crosses one road. `rest_position` on each node is where a loaded
  journey puts a cow whose event has fired (positions are not saved; events
  are).
- `data/quests/stray_cows.json`: no giver (`"street"`), starts on
  `heard_tulu`, one step waiting on both events, ends setting `cows_home`
  with the journey line *"You walked two cows through the traffic to the
  fountain."* The pause menu's one line says *"Two cows nobody sees. Hum,
  and walk them to the fountain."* while it is the first active quest
  (`dry_fountain` sorts first and wins while it is active).

### Lanes are where the traffic drives; nobody waits on anybody

- The roads are not written into the cow. A path mover whose
  `yield_distance` is 5 m or more (the three cars; pedestrians stop at
  1.6 m) joins the `vehicle` group in `_ready`, and a lane is the strip 4 m
  either side of a vehicle's loop. With the two east-west cars at z = 14.5
  and 17.5 that is exactly the road's 11 m; the north-south car gives the
  other road. Move a car's loop and the cows respect the new lane.
- A cow does not step off the kerb while any vehicle is within 6 m (its
  nose, 1 m ahead of its centre, is where it looks). Once in the road it
  keeps walking: if a called walk would end in a lane it goes on, a metre at
  a time, until it is out. Vehicles yield to cows exactly as to the player
  (`YIELD_GROUPS` in `path_mover.gd`). The two rules together mean a cow and
  a car never wait on each other: a cow only waits on the pavement, where
  no car yields to it, and a car only yields to a cow that is moving.
- A grazing cow rejects grazing spots inside a lane, so it never drifts
  into traffic on its own; a called cow that cannot get on (a wall, a parked
  car) gives up after 2 s standing still and settles.

### Placeholders and budget

- The cow is boxes: body, four legs, head, muzzle, tail and two horns,
  2.2 m long, 1.3 m to the head and 1.5 m to the horn tips. The hide is
  `cloth_pale` tinted a dusty cream (ochre/dust palette, GDD §10 Hollow Vale
  row) in a material inside the scene; the horns are the street's `timber`.
  Each cow is two `MultiMeshInstance3D`s, so two draw calls a cow, four in
  all. PLACEHOLDER for the licensed cow model of GDD §10 "Asset sourcing
  plan".
- No sound: a cow hears, turns and walks, which is the whole answer. A low
  or a cowbell (GDD §10 lists cowbells as the Grove's bed, not the Vale's)
  can come with the asset.
- The web budget was not re-measured in this change (no export from the
  parallel worktrees); the addition is four draw calls and some two hundred
  triangles, against a measured max of 177 calls in P6.


## 2026-10-20 — The Garden as a data model and a drawn plot

GDD §6 "The Garden: seeds, fruit and the creeper", §16a "Days and lives".
Affects §6 (the garden exists; fruit vignettes do not yet), §11 (a screen
reached from the pause menu for now), §12 (`garden` on the journey).

### What

- `data/garden.json` says which sources plant which seeds: a source is
  `flag:<name>` or `choice:<line_id>:<card_index>`, a kind is `sweet`,
  `bitter` or `weed`, and each carries the id of the sentence it came from
  (`seed.*` in the string table). The same file names the creeper's flag
  (`creeper_given`, set by another feature; a debug flag for now), the
  watering flags (hearing, chanting, remembering, service: `heard_tulu`,
  `hummed`, `glimpsed_traffic_light`, `gave_dry_fountain`, `saw_shrine`,
  `nanda_listened`, `played_for_others`), how many steps shade (3) and how
  many play-days a seed takes to sapling (1) and to fruit (2).
- `scripts/core/garden.gd` (`Garden`, static) keeps the plot in
  `GameState.garden`: `seeds[{id, kind, day_planted}]`, `pulled[ids]`,
  `creeper{given, watered_days}`, `days`, `last_date`. `GameState` calls it
  when a flag is set, when a choice is recorded and at launch; the plot can
  also be rebuilt from flags and `choice_history` alone (`reconcile`), so a
  journey saved before the garden existed grows one on its next play-day.
- `scenes/ui/GardenScreen.tscn` draws the plot in `_draw`: rows of soil,
  seeds as dots, saplings as stems, fruit as warm circles, weeds as grey
  tufts, a pulled weed's scar as a fleck, the creeper as a vine up a plaster
  wall on the right. Touching a plant shows its sentence; a weed offers
  *Pull*. Opened from the pause menu (*The garden*).

### Decisions

- **A play-day is a calendar date, not a timer.** `advance_day` compares
  `Time.get_date_string_from_system()` with the saved `last_date` at launch
  and when the garden is opened; a flag set across midnight in one sitting
  belongs to the day the sitting began (§16a: "a session is a day"). Nothing
  grows, climbs or withers between plays: absence costs nothing.
- **Each seed is its own plant; thickness is the habit's.** Every planting
  keeps its own sentence and its own stage. "Repeating the same kind of
  choice feeds the same sapling" is drawn as stem width: every stem of a kind
  is as thick as that kind's living count. The count is never written.
- **Seeds look alike, and so does fruit.** Sweet and bitter seeds are the
  same dot and sweet and bitter fruit the same warm circle. The GDD's rule
  against a correct-answer cue is about cards, but painting a kind onto a
  plant would be the designer's verdict the garden exists to avoid; the
  sentence says what was planted, and both kinds of fruit bind.
- **Watering is a flag newly set on that day,** through the data list, and
  `Garden.water(GameState)` is public so the hum, *Listen* or a tale can
  water directly later without a new flag. A day is watered once.
- **Pulled weeds stay in the record** as `pulled` ids: the scar is drawn,
  the sentence still reads, and `reconcile` does not replant it (§6
  "Regrowth" keeps the scar visible).
- **Interim way in: the pause menu.** The GDD puts the plot in the Grove,
  which another agent is building. The pause menu's *The garden* button
  opens the screen as its own child overlay, so no place script changes;
  when the Grove exists, the button goes and the Grove instances the same
  scene.

### Not built (GDD §6, deferred, data kept forward-compatible)

Fruit vignettes and tasting (`Garden.ripe_fruit()` is the hook), weeds
wrapping the creeper, roots and knots, regrowth from tasting, neglect
pulling the creeper down, the next life. `GameState.garden` is a plain
Dictionary so each can add a key.

### Placeholders

None: the plot is drawn with primitives and is its own final form until the
Grove gives it a place.


## 2026-10-20 — The other four Glimpse points

GDD §6 "Glimpses" (five fixed points; conditions tied to state, never a
timer; approaching ends it and leaves a feather or a jasmine flower; never
counted), §3 (sitting on a rooftop, standing on the tower's beam, leaning in
a doorway), §10 (jasmine white; the feather the one peacock blue). Affects
§6 and §12 (four seen flags, four pick-up events).

### One scene, five instances, everything that differs as data

- `scenes/quest/Glimpse.tscn` is now the generic point. New exports on
  `scripts/quest/glimpse.gd`: `trigger_condition` (a string in the grammar
  of `scripts/lib/condition.gd`, so `flag:rukma_heard and not
  flag:rukma_key_taken` is one line of scene data), `leaves` (`feather` or
  `jasmine`), `leaves_offset` (where it lies, in the node's space),
  `pickup_event` (the pick-up's own event, so two jasmine points do not
  hide each other on reload), `pose` (`Sitting_Idle` or `Idle`, held
  through `CharacterRig.hold_pose`) and `witnessed` (Tulu looks up; true at
  the traffic light and nowhere else, GDD §6 "once"). The P5 exports keep
  working: an empty `trigger_condition` reads `flag:<trigger_flag>`.
- The scene holds both pick-ups (`FeatherPickup`, `JasminePickup`); on load
  the script moves the one named by `leaves` to `leaves_offset` and frees
  the other. Simpler than instancing at run time, and `%FeatherPickup`
  still resolves for the P5 tests.
- The four points are `tools/street_parts/glimpses.py`, one table: the top
  of the billboard frame at 25.8 m (`flag:heard_tulu`, standing, feather at
  the tower's foot), the doorway of Nanda's stairwell at (-29, 0, -12)
  (`flag:rukma_heard and not flag:rukma_key_taken`, standing, jasmine on the
  threshold), the far end of the garden at (-42, 0, 1) (`flag:garden_open`,
  standing, jasmine on the spot) and the chai stall's roof (`flag:saw_shrine`,
  sitting, feather on the pavement by the hatch). Seen flags
  `glimpsed_<point>`, lines `journey.glimpse.<point>`.
- The condition is read whole on every flag and event change, and once on
  `_ready`: `Main` frees the Street when the player goes through a door, so
  a flag set inside the shrine would otherwise never reach the roof above
  its back door. A Glimpse that is due when the Street loads appears as the
  player steps out. The P5 behaviour (edge on `gave_dry_fountain`) is a
  special case of this and its tests pass unchanged.
- `end_distance` is now measured across the ground (XZ), not in 3D: a
  figure 26 m up is "arrived at" from the pavement beneath it, which a 3D
  radius could only express as a sphere that also covered the far pavement.
  The traffic light keeps its 6 m, which on the ground is a touch wider than
  before; the P5 approach test still passes.
- `scenes/quest/Jasmine.tscn`: six white ellipsoid petals round a pale
  centre on a short green stem, primitives, inline materials; the player's
  third carryable (`Player.tscn`, flag `carrying_jasmine`). PLACEHOLDER for
  the painted jasmine of GDD §10. `scenes/quest/JasminePickup.tscn` is the
  feather pick-up with `item = "jasmine"`.

### Two things found on the way

- `scenegen.xf(pos, yaw)` writes the basis row by row, which is how Godot
  reads `Transform3D(...)` in a scene file; the node it places therefore has
  forward `(sin yaw, 0, -cos yaw)`, the mirror of what `rotation.y = yaw`
  gives. Noted here rather than changed: every yaw in the generators was
  tuned against what the scene shows. `glimpses.py` has `facing()` and
  `local_offset()` for this convention, and a test pins where the pick-ups
  land in world space.
- The traffic-light Glimpse was placed with yaw `pi/2`, which faces east,
  away from the fountain, and put its feather under the lamp housing; its
  comment said the opposite. Now `-pi/2`: the figure faces the fountain and
  the feather lies on the road below the pole, as the comment always said.
  The P5 tests place the player relative to the node and pass unchanged.

### Not done here

- The stairwell doorway itself, the garden's gate opening, the shrine and
  the roof key are other features; this change only reads their flags. The
  stairwell point stands on open pavement until the doorway is built there
  and may need nudging to its threshold. The shrine's back door is within
  the chai-stall point's 4 m, so a player stepping out beneath it sees the
  roof empty and the feather already fallen; whether that is the right
  staging is a playtest question, and `end_distance` is data.
- Budget not re-measured: four more hidden skinned meshes and four hidden
  omni lights that are off until their moment, one at a time, once each.


## 2026-10-20 — The Counting Man (GDD §7)

GDD §7 "The Counting Man", §3a Act 3 ("Tap coins in a 30-second count, or
sit"), §11 ("No timed input anywhere; the counting mini-game can be
skipped"). Affects §7 (the side quest's data), §11 (the one overlay screen).

### What was built

- `tools/street_parts/counting_man.py` seats him at the east end of the
  bus-stop bench (`scenes/npc/CountingMan.tscn`, criminalMaleA skin, the
  library's `Sitting_Idle`) with one MultiMesh of coins on the seat beside
  him: four short stacks and fourteen loose. The route he walks when freed is
  data on the node (`walk_points`), as Tulu's waypoints are.
- Three ways out, all data: the card *Let me count them with you* sets
  `counting_man_counting`, on which his script opens
  `scenes/ui/CountScreen.tscn`; the card *Here's one more* sets
  `counting_man_given_coin`; *Sit* on the seat beside him sits the player
  (the bus stop's own pose) for `sit_seconds` (3), then he laughs
  (subtitled) and fires `counting_man_laughed`. Tapping the last coin fires
  `counting_man_counted`. `data/quests/counting_man.json` ends on one of
  three branches, each setting `counting_man_freed` and its own *Your
  journey* line; the end condition is the flag, so a tester setting it in
  the debug panel ends the quest too (with the quest-level line).
- Freed, he waits until the screen or his line is out of the way, stands,
  takes the coins (the MultiMesh hides), walks four points east and then
  south down the kerb of the north-south road, hums one note on reaching the
  second point (`assets/audio/one_note.ogg`, G4, the first of Tulu's three,
  from `tools/audio_parts/one_note.py`, subtitled), and is hidden at the
  last. A loaded journey with `counting_man_freed` set has an empty bench.

### Decisions

- **No number, no timer.** The count screen is a grid of a hundred and eight
  identical brass buttons; a tapped coin dims and stays dimmed. Nothing
  counts down and nothing is shown until the last coin, when the hint line
  becomes *"...a hundred and eight."* from the string table. The GDD's
  "30-second" is the time a hundred and eight taps take, not a limit. A
  *Stop counting* button (and Escape / B) closes it with nothing lost; the
  card's flag is cleared on close so the count starts over next time.
  Enter, Space and the gamepad's A tap the next coin: the screen takes
  `ui_accept`, `ui_cancel` and the existing `contextual` action in
  `_input()` and marks them handled so a press never reaches the contextual
  button underneath. No new input actions.
- **A count interrupted by quitting is not resumed.** His script clears a
  stale `counting_man_counting` on load; the player starts again from the
  card. Progress inside the count is not state worth saving.
- **Sitting with him is meeting him.** The quest starts on
  `flag:counting_man_met or event:counting_man_laughed`, so a player who
  never talks to him and simply sits still frees him through the data. The
  quest does not start on `true` (as the Dry Fountain does) so that its
  objective does not take over the pause menu's *now* line before the
  player has found him; once met, `counting_man` sorts before
  `dry_fountain` and the line reads *"A man at the bus stop has lost
  count."* until he is freed.
- **He waits for the player to look.** On the coin path his line is on
  screen when the quest ends; on the count path the screen is. He stands
  only once `Content.dialogue` is idle and the screen is closed.
- **The count screen lives on the place's `UI` layer**, found by walking up
  to the nearest ancestor with a `CanvasLayer` child named `UI` (where the
  choice cards also live), so the pause menu, added later to the same layer,
  still draws above it. Alone in a test the man makes a layer of his own.
  Subtitles go through the place's `%TouchControls`, found the same way; no
  shared file was edited for either.
- **Seat height is eyeballed.** The clips keep the hips at standing height
  (position tracks are dropped, see "The true walk"), so the seated figure
  hangs `seated_drop` (−0.46 m) below his node, which stands on the kerb;
  the coins sit at kerb + 0.45 m. Both are exports/constants to tune in the
  editor; this was built headless.
- **The bus stop is still the end.** Arriving here with `gave_` or `took_`
  set ends the slice (P6) before he can be talked to; the quest is for the
  stretch of the journey before the fountain is settled, or the ignore
  path. Not changed here; noted for the owner.

### Placeholders

- The body: the shared Kenney rig (GDD §10 painted characters replace it).
- The coins: scaled unit cylinders in `plaster_ochre`.
- `one_note.ogg`: a hummed triangle G4; the composer's sung note replaces it.

### Budget

Not re-measured (the brief for this change forbids export builds): one more
skinned mesh at the bus stop, one MultiMesh (one draw call) that hides when
he leaves, and an overlay of plain Controls shown only while counting.
