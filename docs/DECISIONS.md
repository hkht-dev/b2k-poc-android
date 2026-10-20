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


## 2026-10-20 — Trying clothes on in the showroom

Owner request: "go to showroom and try on different clothes". Affects GDD
§6 "Interaction" (one contextual button, the thing's verb on it), §11
(screens: this is not the shop the MVP rules out), §12 (`outfit` on the
journey). Built on `feat/e1-places` (the Showroom is a Place).

### What

- A fitting dais in front of the showroom's mirror (`tools/gen_interiors.py`
  `showroom()`): a round plinth 0.2 m high, under the player's step height,
  so the body walks up onto it. Standing there the button reads *Try on*
  (`scenes/quest/TryOnStand.tscn`, `scripts/quest/try_on_stand.gd`). The
  counter moved west and the mannequins north to clear the mirror's corner.
- *Try on* opens `scenes/ui/WardrobeScreen.tscn` over the view: a panel
  along the bottom with one 96 px button per outfit and *Done*; the body
  stays on the dais (`Player.hold_still`), the camera comes round to its
  front (`CameraRig.drift_toward` aimed at a point behind the body), and
  the view above the panel stays live, so a choice is seen on the body at
  once. Touch and mouse press the buttons; keyboard and gamepad move focus
  along the row and *Prev*/*Next* step it (and scroll the row for a thumb);
  B or Esc closes it. The panel hides while the tree is paused.
- Outfits are data: `data/outfits.json` lists every Kenney skin
  (`tools/scenegen.py` `SKIN_PATH`) with an id, a name string id and the
  texture path; `scripts/core/outfits.gd` (`Outfits`) reads it once, like
  `Places`. `GameState.outfit` holds the id, `""` meaning the skin the
  player scene carries (humanMaleA, the data's `default`); it is saved with
  the journey, loaded back, and wiped by *Play again*. The player's body
  applies it at `_ready` and on `GameState.outfit_changed`, so the street
  and every interior dress the traveler the same (`CharacterRig.set_skin`
  repaints a built body).

### Why this shape

- No price, no badge, no "owned" state, no "worn" mark: everything is free
  and every button is drawn the same (the GDD §6 rule for cards, applied to
  clothes). Focus lands on the worn outfit when the wardrobe opens, which
  a gamepad needs anyway; nothing else distinguishes it.
- The screen touches only `GameState`; the body listens. The stand owns the
  overlay (its own `CanvasLayer`, above the HUD) rather than `Place`, so
  the Place seam stays as it is and a stand instanced alone still works.
- The outfit is cosmetic and Street-only. The GDD's coat (§3, Act 5: "the
  coat falling away") is story, not this; nothing reads `outfit` but the
  body.
- Outfit names are plain words for what the cloth looks like ("Brown coat",
  "Pale shirt"), never the pack's labels.

### Placeholders

- The skins are Kenney's CC0 character textures (docs/RIGHTS_REGISTER.md),
  stand-ins for the hand-painted cloth of GDD §10 "Characters"; the data
  file says so, and a final art pass replaces the `skin` paths and names.
- The dais and the mirror are primitives in the street's materials, as the
  rest of the interiors are, for the painted set dressing of GDD §10.


## 2026-10-20 — The Forgotten Song as data, and Dhanpal at the hall

GDD §7 "Main quest: The Forgotten Song", §8 Scene C, §4 Dhanpal, §6
"Remembering Krishna". Affects §7 (the quest file's shape), §11 (the pause
menu's one line).

### The spine is one file; the approaches are flags

- `data/quests/forgotten_song.json`: giver `dhanpal`; it starts on
  `heard_tulu` or `met_dhanpal`, so following the boy and meeting the
  landlord both open it. It ends on `played_for_others` or `kept_veena`,
  each a branch with its own line in *Your journey*
  (`journey.forgotten_song.played` / `.kept`). No flag of its own is set by
  the quest: the tower, the competitors, the shrine and the Veena set theirs,
  and the quest only reads them.
- The runner walks steps in order and re-derives progress from flags, so
  three approaches that can run in any order and mix are written as one
  ordered list of ten steps whose `complete_when` say "this approach's next
  milestone, *or* the player is on another approach, *or* they are on the
  tower". Order: hear of it, the tower waits, Compete (key, shortcut),
  Mediate (a second competitor, all four), Investigate (lamp, Sarang's bar),
  climb, dawn. Compete steps give way to any Mediate or Investigate flag;
  Mediate steps give way to the shrine or to a finished Compete; Investigate
  steps give way to a finished Compete or a finished Mediate; `on_the_tower`
  clears every preparation. So under a mix the one line follows Investigate
  over Mediate over Compete, and a finished approach wins over a begun one
  (GDD §7: "a player who starts competing can switch to mediating after one
  taken item"). Every condition is monotone (no `not`), so a loaded journey
  lands on the same step; a test holds that.
- "Two competitors before accepting" has no counter in the condition
  language, so it is the six pairs written out. Long, but it is data, and
  the alternative was a path variable or a counter in code.
- Objective texts (`quest.forgotten_song.*`) are the pause menu's one line in
  the character's voice: "Dawn is coming. The tower is waiting." is the
  GDD's "Be on the tower at dawn" said by the traveler.

### Dhanpal

- `scenes/npc/Dhanpal.tscn` is the shared body in the criminalMaleA skin, a
  little taller and broadened; `scripts/npc/dhanpal.gd` is the shopkeeper
  pattern (first available of `entry_lines`) plus one thing of his own: he
  turns to whoever comes within 5 m of the hall and back to the street when
  they go. He never follows. His lines after each dawn are chosen by
  `requires`, not judged in code.
- Scene C's cards: *Count me in* (sets `accepted_contest`), *Who else is
  climbing?*, *Not today*; the first line's `sets` is `met_dhanpal`. "Why
  does the name matter?" follows *Who else*, so the GDD's line about Nanda
  and his brother is reachable without accepting.
- The hall is the last south flat given a front by
  `tools/street_parts/dhanpal.py`: a step at the pavement's road edge, two
  pillars, a fascia with the `sign.hall` label, a roof back to the face, a
  doorway between two windows. The pedestrians' loop (z 23 and 24.4) passes
  under the roof between the pillars and the door, a colonnade people walk
  through, which is why the step and pillars stop short of z 22.7. The task
  named "x 46, z 27"; z 27 is inside the flat, so the front sits on its
  street face (z 24.9) and the pavement in front, centred on x 46.
- PLACEHOLDER: the hall front is primitives in the street's textures,
  replaced by the hall of GDD §5; Dhanpal's body by GDD §4's.

### For the integrator

- `scripts/ui/pause_menu.gd` `now_line()` reads the first ACTIVE quest in
  id order, and `dry_fountain` (active from the start) sorts before
  `forgotten_song`; it also returns *Somewhere a boy is humming* until
  `heard_tulu`, even once Dhanpal has been met. The main quest's line should
  win: either a `priority`/`main` field on the quest file read by `now_line`,
  or the main quest first. Left untouched here (shared file).
- `tools/check_data.py` `REQUIRED_STRING_IDS`: add `speaker.dhanpal` and
  `sign.hall` (the sign is referenced only by the generated scene).


## 2026-10-20 — Lamps: the player's own (GDD §16a "Social: lamps")

Owner expansion 2026-10-20 (the macro design, built in parallel). GDD §16a:
"Anywhere in the Street ... the player can set down a lamp with one of twelve
preset lines ... Others see lamps as small lights, can sit by them and leave
a flower. No free text ... lamps fade after thirty days unless re-lit."
Affects §6 (one more thing to *Sit* by), §11 (one more pause-menu button),
§12 (`lamps` on the journey), §15 ("lamps are preset lines only"). The
brief's slice list deferred §16a; the owner asked for this half of it now.

### What is built

- `data/lamp_lines.json`: the twelve line ids (`lamp.line.<id>`), `days`
  (30), `max_per_place` (8) and `seconds_per_day` (900). The texts live in
  the string table; a lamp record carries an id, never text. The GDD's four
  lines come first; the other eight are in the same voice, written for any
  place, none naming a quest. `scripts/core/lamp_lines.gd` reads the file
  once, like `places.gd`.
- *Set a lamp here* on the pause menu opens `scenes/ui/LampLinesScreen.tscn`:
  twelve buttons in the data's order, one style, the focus starting on the
  first (keyboard, gamepad), each carrying its text as tooltip; *Not now* or
  the cancel action goes back to the pause menu. Choosing a line records
  `{place, x, z, line_id, lit_day}` in `GameState.lamps` (place from the
  Place's `place_id`, x and z from the player's feet) and resumes play.
- `scenes/quest/Lamp.tscn` (`scripts/quest/lamp.gd`): a low clay cylinder,
  a small unlit warm sphere for the flame, an `OmniLight3D` (range 3 m, the
  Glimpse's warm orange `(1, .72, .42)`, no shadow) and an Interactable
  *Sit*. Sitting shows the lamp's line as a subtitle for 4 s and holds
  `Sitting_Idle` on the player's rig (the bus stop's clip) until the
  player's horizontal speed passes 0.15 m/s, which the lamp watches in the
  player's velocity; *Sit* is withheld while sitting. PLACEHOLDER: the
  hand-painted clay diya of GDD §10 replaces the primitives.
- The Place base spawns one Lamp per record of its own place that still
  burns, at ready and whenever a lamp is set (`GameState.lamp_set`), in a
  delimited block at the end of `scripts/places/place.gd` (two one-line
  hooks in `_ready` and `pause`, marked `# lamps`). The record keeps no
  height: the lamp finds the ground beneath its x, z with one ray on its
  first physics tick, so a lamp set on a kerb comes back on the kerb.
- Eight lamps to a place: the ninth puts out the oldest there
  (`GameState.set_lamp`); other places are untouched.
- Fading: a play-day is `floor(play_seconds / seconds_per_day)`; a lamp with
  `play_day - lit_day >= days` is not spawned. Fifteen minutes to a day
  follows §16a "Days and lives" ("about fifteen minutes from dawn to dusk").
  Nothing shows the day and nothing counts down (§15: the sun is never a
  timer). A faded record stays in the journey until the eight-per-place rule
  replaces it; "re-lit" is not built.

### What is not built, and why

- Other people's lamps, and the flower left at one. Both need the lamps
  store of §16a and §12 ("a minimal backend"), and the brief forbids any
  network call or backend in this repository. The record is the shape such a
  store would hold (place, position, line id, day), so the client half is
  ready; the "others" half is future work for the integrator's backend
  decision.
- No count of lamps anywhere, and *Your journey* does not list them
  (§16a's *Noticed* list is not in the slice).

### Strings, data, state, tests

- Strings: `pause.set_lamp`, `lamp.title`, `lamp.cancel`, twelve
  `lamp.line.*`.
- `GameState.lamps: Array[Dictionary]`, `set_lamp()`, `lamps_in()`, signal
  `lamp_set`; saved, loaded and wiped with the rest of the journey.
- `tests/test_lamps.gd` holds the data, the pause-menu path, setting,
  sitting, save and load, the ninth lamp, the fade, and a read of every
  lamp file for network words.
- `tools/check_data.py` should learn `data/lamp_lines.json` (twelve ids,
  each in the string table, `days` a positive integer) and the new required
  string ids; the integrator owns that file.


## 2026-10-20 — Tells and the *Noticed* list

GDD §6 "Tells", §16a "Noticed" (the owner asked for the macro design to be
built in parallel; this supersedes the brief's Slice 1 exclusion of Tells).
Affects §3a (the Street's *Look* row), §6, §11 (the pause menu), §12 (the
journey gains a list).

### What a Tell is here

- A Tell is a small, silent wrongness the player can *Look* at and nothing
  more: `scenes/quest/Tell.tscn` is an `Interactable` with `verb.look` and a
  1.8 m reach; which tell it is, is `tell_id` on the node, a row of
  `data/tells.json` (`{id, sentence_id, place, requires_humming?}`), read by
  the static loader `scripts/core/tells.gd` (`Tells`) the way `Places` reads
  places. Twelve for the Street, every sentence `tell.<id>` in the string
  table, written in the GDD's tone: affectionate, unexplained.
- *Look* calls `GameState.notice(id)`, which appends the id to `noticed`
  (a plain `Array[String]`, saved with the journey, wiped by *Play again*)
  once and only once, and shows the sentence as a subtitle for four
  seconds. It sets no flag, fires no event, adds no journey line: the
  journey tests hold that the flag and event counts do not move. *Look*
  stays offered after noticing, so the poster can be looked at twice.
- The clock over the chai stall "stops while the hum is held": its row has
  `requires_humming`, and the tell offers *Look* only while the Place's hum
  player is playing (`Place.is_humming()`, new). The hum is 1.6 s, so the
  player hums and looks; nothing times them.
- `Place.subtitle(text_id, seconds)` is new and tiny: the HUD's subtitle
  reached from a node that is not the Place.

### Nothing counts them

- The pause menu gains *Noticed* under *Your journey*: the title string
  `pause.noticed` and the sentences, in the order seen, hidden until there
  is one, built exactly as the journey list is. No total, no "x of 12", no
  number anywhere; a test searches the section for digits. The data file's
  `tells` list is the only place twelve appears, and the game never reads
  its length for the player.
- Tells are not Glimpses: they have no flag, no feather and no journey
  line, and the Glimpse is unchanged.

### Where they stand

- `tools/street_parts/tells.py` places each tell with a prop built from
  primitives: the clock (rim, face, two stopped hands) on the chai stall's
  front; a puddle (`water.tres`) with two small spheres turning in it west
  of Gopal Seth's shop; a warm unlit quad in front of a flat's barred
  window; a poster (the sign texture) with a figure and a timber sliver of
  a feather; a dark doorway in the tower's foot with a cow-shaped decal
  lying out of it; a kite on two spars over the crossing; a bird on the
  westernmost cable; a lamp post's shadow lying toward the sun; three
  chalk marks north of the fountain; a jasmine flower by the fence; wet
  footprints over the south kerb; a tarpaulin corner under a brick by the
  covered car. All kept clear of the fountain's *Look*, the shop's *Pick
  up*, Tulu's route and the bus stop's *Sit*, and at least four metres
  apart, so the one button never has to choose.
- Two new materials, `assets/materials/tell_shadow.tres` (dark, unlit,
  translucent: shadows and wet marks) and `tell_glow.tres` (warm, unlit,
  faint). No peacock blue, no magenta, no pink: the poster's feather is
  timber and only the sentence says what it is.
- The part carries its own transform helpers (`yaw_xf`, `roll_xf`,
  `face_xf`) because `scenegen.xf` writes a yaw with a non-uniform size as
  a sheared basis (Godot's `.tscn` lists the basis row by row); the street
  only ever used it with yaw on uniform sizes or yaw 0, so nothing there
  changes. Worth folding into `scenegen.py` when it is next touched.
- PLACEHOLDER: every prop is primitives with the street's procedural
  textures, replaced by the painted props and decals of GDD §10.

### Not done

- Tulu "acknowledging" a Tell (GDD §6) is not built: no Tulu line exists
  for it in Slice 1 and it would need dialogue data; nothing here stops it
  being added as a line with `requires`.
- `tools/check_data.py` does not yet check `data/tells.json`; the
  integrator owns that file (see the report).

## 2026-10-20 — Tulu at the door, the chai stall's front (owner expansion)

GDD §3 Act 3 "Arrival" (Tulu leads to the shrine room behind the chai
stall), §4 "Tulu ... follows the player if ignored", §5 "the shrine room is
tucked behind the chai stall, found by following Tulu or Sarang's music"
and "leaks a faint drone of Madhuri's chanting", §7 micro-interaction "Hum
near the shrine: Madhuri's chant rises to meet the note". Affects §3, §5,
§6 (Listen, Call), §7. The shrine interior and the door that opens are
another feature's; this is the thread up to the door and the stall's front.

### Arriving is a sound and a look, not a prompt

- When Tulu reaches his last waypoint (`is_at_the_door()`) he hums once
  more through the Reply player, turns to face the player and keeps facing
  them, and the HUD shows *[Tulu looks at the door, then at you]* for 4 s.
  The flag `tulu_at_door` is set; both the flag and the subtitle id are
  exports on `Tulu.tscn`. `GameState.set_flag` returning false (already
  set) is what keeps the subtitle to once per journey: the flag is the
  record, nothing else counts.
- A loaded journey with `tulu_at_door` set finds him at the last waypoint
  rather than walking the route from the fountain again, so the saved state
  and the verb beside him agree.
- Tulu finds the HUD through `owner` (the place that instanced him owns its
  `%TouchControls`). A bare Tulu, or one in a place with no HUD, says
  nothing and errors nowhere. Chosen over a signal the street would have to
  wire so `street.gd` stays untouched.

### Talk takes Listen's place at the door

- `Tulu.tscn` gains a Talk `Interactable` with `requires = ["tulu_at_door"]`
  (data), opening `entry_lines` (`tulu_door`, data on the scene) the way
  the shopkeeper does. His Listen area is switched off while he is at the
  door: both areas sit on him and the place offers the nearer, so only one
  may be open, and once he has led the player here the button's work is to
  let them ask. The hum loop still plays; sound still leads.
- The Talk area hangs off a plain `TalkMount` node because the place treats
  any verb whose parent is a `sound_source` as *Listen* (camera drift and
  the hum subtitle). A mount is smaller than a change to `place.gd`.
- `tulu_door` offers two cards: *What's in there?* → *She keeps a lamp. She
  knows the whole song.*, and *Go on, then* which ends it. The line itself
  `requires` the flag, a second gate behind the verb's.

### The chant answers a hum at the door

- `tools/street_parts/chai_front.py` places `ChantOutside`, an
  `AudioStreamPlayer3D` at the back door (group `chant_outside`; the group
  name is an export on Tulu), unit size 3 m, inaudible past 14 m, silent
  until a hum. When the player hums within 10 m of Tulu while he stands at
  the door, he answers as before and Tulu starts the chant if it is not
  already playing. The chant is stirred even while his own reply cools
  down, so every hum at the door reaches the room.
- `tools/audio_parts/chant_outside.py` makes the sound: a D3 root and its
  fifth, each with a slow vibrato so they beat against each other, swelling
  into one another once over 8 s, lowpassed at 420 Hz, peak 0.16. Only this
  file was encoded (through `gen_audio`'s own helpers); re-encoding the
  other four would have churned their bytes for no change. PLACEHOLDER for
  GDD §10: Madhuri's chanting recorded by a devotee with permission.

### The chai stall's front

- Amma (`speaker.chai_seller`, `scenes/npc/Shopkeeper.tscn`, skin
  humanFemaleA) stands beside the shelf at the hatch's west end facing the
  street, because the stall's body is a solid box and the hatch a panel on
  it; her `entry_lines` is `chai_greet`. Three cards: about the boy (*Tulu.
  He hums all day. His grandmother ran the shrine behind here.*), about the
  back door (*That's Madhuri's. Knock if you like; she won't mind.*, whose
  line sets `told_about_shrine` so either route to it sets the flag), and
  just a chai. The Tulu branch also leads to the door line.
- A kettle (body, lid, handle, laid spout), eight cups in one MultiMesh,
  and a `Label3D` sign `sign.chai` through `label_from_id.gd`.
- Steam is `scripts/street/steam.gd` on one MeshInstance3D: an unshaded,
  alpha-blended cylinder that scales from its base size to twice it, rises
  0.6 m and fades over 2.4 s, then starts again. One transparent draw call,
  no particle system; warm white, so the Hollow Vale palette (no peacock
  blue, no magenta) holds. PLACEHOLDER for the painted wisp of GDD §10.

### Budget

Not measured in the web build here (the brief for parallel agents forbids
exports on the shared machine). Added per frame: Amma's rig (one skinned
mesh), five small opaque primitives, one MultiMesh, one transparent mesh,
one Label3D: about eight draw calls and under 2k triangles against the P6
headroom (median 112 of 200 draw calls). The integrator's next measured
walk should confirm.


## 2026-10-20 — Dhanpal's office and Nanda's flat

GDD §5 (Hollow Vale: "four enterable interiors ... Dhanpal's office, Nanda's
flat at the end of the alley"; "Locks, grilles, CCTV cameras and phones
appear in every household and shop"), §4 (Dhanpal, Old Nanda), §7
("Mediate", step 3: "bring him the broken instrument's missing string (found
at Nanda's flat)"; "Micro-interactions": a one-line thought, no giver, no
reward). Affects §5, §7.

### Two more rooms, through the same seam

- `tools/interiors/office.py` → `scenes/places/Office.tscn`, place `office`
  ("Dhanpal's office"): 9 x 7 m, the desk and leather chair, filing
  cabinets, three framed photographs of the tower on the east wall, the
  room's windows onto the street, a brass plaque (`sign.office`), a camera
  high in the corner and a second door in the south wall with two locks on
  it. `tools/interiors/nanda_flat.py` → `scenes/places/NandaFlat.tscn`,
  place `nanda_flat` ("Nanda's flat"): 6 x 5 m, dim (one amber lamp, half
  the shops' ambient), a bed, a shelf of old things, one photograph on the
  wall, bolts on the inside of the door. Both use `room()`, `lights()` and
  `assemble()` from `gen_interiors.py` unchanged; the flat's dimness is a
  one-string replacement of the ambient energy `assemble()` writes, asserted
  so a change there fails loudly.
- Street side: `tools/street_parts/office_door.py` (the door at
  (46, 0, 25.9) at the hall front, a frame, leaf, step and the plaque, the
  spawn `office_door` a metre north of it facing north) and
  `tools/street_parts/nanda_door.py` (the door at (-29, 0, -13.5) facing
  south into the west alley, a leaf with a barred peephole, the spawn
  `nanda_door` just south of it facing south). Neither builds the hall or
  the alley; those are other parts'. The office door's reach runs 2.4 m deep
  so *Go in* is offered from the pavement wherever the hall's front wall
  lands.
- The door back in each room names the same spawn id as the door outside,
  as the shops do.

### Look, as a scene

- `scenes/places/LookPoint.tscn` + `scripts/places/look_point.gd`: an
  `Interactable` *Look* in a box (`reach`) that opens one dialogue line
  (`line_id`). Which flags a look leaves behind is the line's own `sets`
  (data/dialogue/en.json), so the script knows no flag. The office's three
  photographs, camera and lock, and the flat's photograph, are six of these;
  every line is speaker `thought` (`speaker.thought` is empty, as the
  fountain's is: a thought has no name over it), has no cards, is under 20
  words. The lock's sets `noticed_office_lock`; the brothers' photograph
  sets `saw_brothers_photo`.
- The photographs are pictograms in dark print on a pale card: a shaft, a
  crane, the billboard, a figure. PLACEHOLDER for the painted photographs
  of GDD §10; the pictogram is enough for the thought to land.

### The string

- `scenes/quest/InstrumentString.tscn` (three thin rings in the street's
  dull metal; PLACEHOLDER for the wound string of GDD §10, and deliberately
  not peacock blue: §10 lets that colour appear first on the Veena's
  strings at dawn) is the third entry in the player's `carryables`
  ("string"). `scenes/quest/StringPickup.tscn` lies on the shelf's third
  board: *Pick up* through `pickup_item.gd`, which gained an optional `flag`
  export (set on pick-up; the feather leaves it empty) beside its `event`.
  Picking the string up sets `has_sarang_string` and fires
  `sarang_string_picked_up`, so a loaded journey does not lay it down again.
  The giving happens at Sarang's corner, which reads `sarang_string_given`;
  nothing of that is in the flat.

### Noted, not fixed

- A `Label3D`'s front is its +Z, so `b.label(..., NORTH)` with `NORTH = 0`
  on a south wall faces into the wall and is unreadable from the room with
  `double_sided = false`. The office plaque and the street plaque use a yaw
  of π (`FACE_NORTH`) so they read from the north. The shops' inside signs
  (`gen_interiors.py`) still use `NORTH`; theirs to turn.


## 2026-10-20 — The shrine room behind the chai stall, and Madhuri

GDD §5 Hollow Vale (the shrine room: "old photographs, a lamp, a stone
basin", tucked behind the chai stall, leaking "a faint drone of Madhuri's
chanting"), §7 main quest "Investigate" steps 1–3, §8 Scene D, §6
"Remembering Krishna" (`saw_shrine`), §7 micro-interaction "Hum near the
shrine: Madhuri's chant rises to meet the note". Affects §3a Act 3 ("Carry a
can into the shrine room; set it by the lamp").

### The place

- `tools/interiors/shrine.py` generates `scenes/places/Shrine.tscn`, place
  id `shrine` (`data/places.json`, name `place.shrine`): 6 x 5 m, a low
  timber ceiling, plaster walls, no windows. It uses `assemble()` from the
  interiors generator but not `room()`: the shops' room comes with windows
  and ceiling lamps, and this one is lit by its single lamp. The shops'
  ambient light is taken down by replacing the two lines `assemble()`
  writes; each replacement is asserted, so if the generator changes, the
  shrine's build fails rather than quietly turning bright.
- `tools/street_parts/shrine_door.py` turns the chai stall's existing
  `BackDoor` mesh into a door (`verb.enter` → `shrine`, spawn `shrine_door`)
  with the spawn outside facing north, and puts the chant at the door,
  faint, 12 m reach: the room is found by sound (GDD §5), not by a marker.
  `gen_street.py` is untouched; Tulu's waypoints already end here.
- Inside, `DoorOut` (`verb.leave`) returns to `street` on `shrine_door`, as
  the two shops do.

### Madhuri and her chant

- `scenes/npc/Madhuri.tscn` + `scripts/npc/madhuri.gd`: the shared rigged
  body in `humanFemaleA`, idle, by the lamp with her empty jar, facing it
  (Scene D: she does not turn round). *Talk* opens the first of
  `entry_lines` whose `requires` hold: `madhuri_after_water` (needs
  `lamp_watered`), `madhuri_ask_water` (needs `met_madhuri`, set by the
  greeting's own `sets`), `madhuri_greet`. So she greets once, then asks for
  water each time until she has it, then says it will see the dawn. No
  negated requirement was needed: the order of the list does it.
- Lines are Scene D's, trimmed under 20 words, with the Veena left out (out
  of scope for the slice); what was played at the fountain is "something
  this street sang every dawn". Two cards each; no card is marked.
- The chant is its own node (`scripts/npc/madhuri_chant.gd`, in
  `sound_source`) rather than Madhuri's root: `Place._on_verb_used` shows
  Tulu's subtitle for any verb used on a sound source or its child, and
  *Talk* on Madhuri must not say "[Tulu hums three notes]". On `hear_hum()`
  the loop comes up 7 dB over 0.6 s, holds 4 s, settles over 1.2 s, and the
  HUD shows `sub.madhuri_chant` (GDD §11: every vocal sound subtitled). A
  sound answering a sound: no flag, no reward.
- `tools/audio_parts/chant.py` → `assets/audio/madhuri_chant.ogg`: 8 s,
  two sung tones a tone apart (D3/E3) cross-fading once a loop over a root
  drone, every rate a whole number of cycles per loop so it has no seam.
  PLACEHOLDER for the recorded maha-mantra of GDD §10 "Sound".

### The photographs and `saw_shrine`

- `scenes/quest/Photograph.tscn` + `scripts/quest/photograph.gd`, three
  instances on the east wall. *Look* opens the first of the photo's
  `entry_lines` whose `requires` hold. Each photograph has two lines with
  the same words: `photo_<x>` sets `saw_photo_<x>`; `photo_<x>_last`
  requires the other two and also sets `saw_shrine`. Whichever is looked at
  last marks the shrine seen, in data; nothing counts in code. The GDD's
  `saw_shrine` is "visits the shrine"; the owner's brief for this feature
  asked for all three photographs, which is what the data does.
- The speaker `photo` has an empty name, like `fountain`: a narrator line.

### Water for the lamp

- `scenes/quest/LampPoint.tscn` + `scripts/quest/lamp_point.gd`, mirroring
  the fountain point. *Place* is offered only while `carrying_can` is set
  (the `requires` on the Interactable); using it puts the can down, fires
  `event_id` (`can_placed_at_shrine`) and sets `sets` (`lamp_watered`), all
  exports set in the scene. The lamp (the room's one `OmniLight3D`, inside
  this scene so it can answer) comes up from 0.8 to 1.6 over 4 s and the
  can appears by the stand; a loaded journey with `lamp_watered` starts lit.
- No quest file: *The Forgotten Song* is out of scope for the slice and not
  to be scaffolded. The flags and the event are there for it; a later quest
  file can wait on `event:can_placed_at_shrine` the way the fountain's does.

### Placeholders

Primitives in the street's textures for the room, the stand, the basin and
the cushion (GDD §5 "custom work is limited to ... the shrine interior");
pale panes in timber frames for the photographs; the shared Kenney body for
Madhuri (GDD §4); a synthesised drone for the chant (GDD §10).


## 2026-10-20 — Optional wisdom: the lotus and the cards

GDD §6 "Optional wisdom", §9 "Wisdom encounters", §11 (HUD, accessibility),
§10 (the lotus as the UI's one ornament; the forbidden colours), §15 (the
rule on verse text). Affects §6, §9, §11.

### What was built

- `data/wisdom.json` is GDD §9's table, transcribed: seven cards, in its
  order, each with its beat, a `trigger` in the condition grammar of
  `scripts/lib/condition.gd`, four string ids (verse, meaning, Read more
  note, source line), the verse reference and `review_status: draft`.
  `scripts/core/wisdom.gd` is the static loader (like `places.gd`); a bad
  row is reported by id and skipped.
- The lotus (`scripts/ui/wisdom_prompt.gd`, `%Lotus` in
  `TouchControls.tscn`) is a Control drawn with `_draw`: five petals in the
  UI's parchment and ink with an ochre heart and a faint warm glow, no
  image, nothing when hidden. It sits at the right screen edge, mid-height,
  clear of the minimap and the contextual button, breathes at 0.5 Hz (GDD
  §11's 3 Hz limit) for eight seconds, fades over 0.6 s and is gone. Its
  countdown holds while the tree is paused (a dialogue, the pause menu, a
  card), so an offer is never eaten by a menu.
- `scenes/ui/WisdomCard.tscn` is §9's card format: the verse in the heading
  font, the source line, the two-sentence meaning, *Read more* (the note
  unfolds in a ScrollContainer in place; the button has done its work and
  goes), *Close*. Focus lands on *Read more*, then on *Close*; Escape or
  the pause action closes. The tree pauses while a card is open ("the game
  pauses while one is open", §9) and the card processes always.
- The Place base connects `GameState.flag_changed` to
  `_on_wisdom_trigger`: when a flag is set, the cards whose trigger *reads
  that flag* are evaluated, and the first unseen one whose trigger holds is
  offered and recorded in `GameState.wisdom_seen` (a new persisted Array of
  card ids; to_dict/from_dict/wipe). Only cards naming the changed flag are
  considered, so a card appears at the moment of its own beat and never
  later on an unrelated flag change (§9: "tied to a beat the player has just
  lived through"). One card per flag change (§9: never more than one per
  beat); a newer offer replaces an older lotus. Loading emits nothing per
  flag, so a resumed journey re-offers nothing. `wisdom_seen` records that
  the lotus was *offered*, not that the card was opened: ignoring it has no
  effect, and nothing is counted (§6).
- The contextual action (E, A) opens the offered card only when nothing
  usable is near; near something, the thing's verb wins. The card is
  optional; the world is not. A tap or click on the lotus always opens it.

### This is the GDD's own prompt, not a notification

The brief forbids notifications, timers, markers and badges. The lotus is
none of these and the GDD asks for it by name (§6, §11: "the lotus icon
pulses only when a card is available"). It is in-world and silent: no
sound, no number, no badge, no push, no record of how many were missed. It
is dismissible by doing nothing. Nothing in the game depends on it: no
flag, quest, line or ending reads `wisdom_seen`, and the debug panel does
not need it. Its eight seconds are a window, not a countdown the player
sees; nothing is lost when it closes.

### Verse text: plain renderings, labelled as such, until the panel approves

GDD §9: "The verse text itself is not written here: the published
translation must be chosen and licensed ... the exact wording goes in only
after panel approval." GDD §15: "Scriptural text appears only as a licensed
translation with edition named; the game never paraphrases a verse as if it
were the verse." So every `wisdom.<id>.verse` is the game's own plain
rendering of the verse's sense, and the card's source line says so in as
many words ("told here in plain words, not the verse itself. The licensed
translation, with its edition, goes here after the panel approves it").
Quoting a public-domain translation from memory and naming its edition
risked a misquotation under a real scholar's name, which §15 forbids more
sharply than a labelled rendering. PLACEHOLDER: the licensed translation
(BBT permission, §15) and edition replace the verse and source strings at
the week-12 review; the string ids do not change. The meanings are §9's
draft glosses, kept to two sentences; the *Read more* notes are 245–266
words each, written for someone with no background, say which game ideas
are fiction (the Grove, Hollow Vale, the Song, the Veena, the embrace), and
carry the maha-mantra once, as text, in card 6 with a one-line explanation
(§9 rules). A test holds that no card contains "you chose".

### Triggers, as data

| Card | GDD beat | Trigger in the data | In Slice 1 |
|---|---|---|---|
| whisper (Bg 2.13) | After the whisper (Act 1) | `flag:heard_whisper` | never: Act 1 is out of the slice; the Grove sets the flag |
| arrival (Bg 15.7) | Arrival in Hollow Vale | `flag:heard_tulu` | the first *Listen*, the arrival beat's first act |
| take (Bg 2.62–63) | After any take choice | `flag:took_dry_fountain` | yes |
| give (Bg 3.9) | After any give choice | `flag:gave_dry_fountain` | yes |
| shrine_water (Bg 9.26) | At the shrine, after carrying water | `flag:saw_shrine` | when the shrine lands; its carry flag may replace this one string |
| melody (Bg 18.66) | After beat 12 (the melody) | `flag:played_for_others or flag:kept_veena` | never: the dawn choice is out of the slice |
| embrace (Bg 9.22) | After the embrace (credits) | `flag:embraced` | never: Act 5 is out of the slice |

Later quests extend a trigger with `or` (`flag:took_dry_fountain or
flag:took_fence`); nothing in code changes. The out-of-slice cards are
content transcribed from §9, not scaffolding: the data format is the same
for all seven and a flag no scene sets is simply never set.

### Not built

- §9's *Learn more* link to a team page: the page is an open decision (§17)
  and the slice makes no network call. The note is offline, as §6 asks.
- Localised verse translations (§11: licensed per language) wait on the
  English one.

### Budget

UI only, no web build exported for this change (the machine is shared).
The lotus is one Control: hidden, it draws nothing; showing, it is six
polygons and two circles for eight seconds. The card is a panel of labels
that exists only while open.


## 2026-10-20 — Three competitors on the Street: Rukma, Bhima Lal, Old Nanda

GDD §4 (the competitors), §7 main quest table (the Compete and Mediate steps
that happen on the Street), §8 (voice). Sarang is the music agent's; Dhanpal
the hall's; the dawn climb reads the flags set here and is not built here.

### Where they are, and how

- `tools/street_parts/competitors.py` places three `Shopkeeper.tscn`
  instances under `Competitors`: Rukma on the bus stop bench facing the
  road (skaterFemaleA), Bhima Lal on the pavement at the east end of
  Gopal's shop looking at the dry fountain (survivorMaleB, 1.95 m against
  everyone's 1.75), Old Nanda at a door in the tower block's south face
  (humanMaleA). The brief's "west alley at x ≈ -29" is where the tower
  block now stands, so Nanda's flat is at its foot, which is also why he
  knows the back stairs. Nothing new in code: skins, heights, the idle clip
  and the lines each tries are properties on the instanced nodes.
- Rukma asleep is the library's `Sitting_Idle` on `idle_animation` (as the
  Glimpse sits), her origin 0.59 m below the seat because the rig keeps
  rotation tracks only and the shared body's hips rest at 0.59 m (measured).
  PLACEHOLDER: a sleeping clip replaces the sitting one.
- Nanda's door is a slab, a frame, a step and a `Label3D` sign (`sign.nanda`)
  with a *Look* in front: `scripts/quest/look_line.gd`, an `Interactable`
  whose verb opens the one dialogue line named on the node (a micro-
  interaction, GDD §7: no giver, no reward). It is not a `Door`: it leads
  nowhere in this slice, and the stairwell Glimpse point (GDD §6) is not
  built.

### The lines are the quest

- Dialogue only; no quest file. The steps of GDD §7 that touch these three
  are each a flag a card or a line sets: `rukma_heard`, `rukma_key_taken`,
  `rukma_key_traded`, `bhima_asked`, `bhima_medicine_given`,
  `nanda_listened`, `nanda_told_shortcut`. Nothing is cleared: the trade
  leaves `carrying_can` set (the brief says flags only set); whoever builds
  the dawn climb decides what the can becomes.
- "Not already taken" and "needs a can" are expressed with the one tool the
  dialogue has, positive `requires` on lines plus the order of
  `entry_lines`, exactly as Gopal's after-lines work: `rukma_after_key`
  (requires the key) is tried before `rukma_greet`, so the greeting with the
  take card never opens again; `rukma_greet_can` (requires `carrying_can`)
  is tried before the greeting, so the trade card appears only with water in
  hand. No negated requirement was added to the format.
- Taking the key is a card ("Her bag is open. Take the roof key.") on the
  line where she talks in her sleep, as the task asked. GDD §3a prefers an
  approach "chosen by what you do next, never by menu": a *Take* verb on her
  bag would be the stricter reading, and swapping to it later is a scene
  change, not a data change. Recorded, not done.
- Every mix of paths stays open (GDD §7 "Approaches can mix"): after the
  key is taken or traded she can still be woken and heard; after Nanda has
  told the shortcut he still offers the sitting; the stairs card is on the
  competitor's greeting (`requires accepted_contest`), so a listener who
  later accepts still finds it.
- `speaker.thought` ("") is the empty speaker label for the player's own
  one-line thoughts (the key in the hand, the door), as `speaker.fountain`
  is for the fountain.

### Budget

Three more skinned bodies and a dozen primitives; not measured in the web
build here (shared machine, per the agents' brief). The integrator's walk
should carry the numbers.


## 2026-10-20 — The Pool of Worlds: the way down and the way up

GDD §3 Act 2 "Falling" and Act 5 "Rising", §3a Act 2 ("Nothing but tilting
the view"), §5 "The Pool of Worlds" (a 90-second descent, one particle
system, two directions), §8 Scene B, §10 Pool row, §11 (accessibility).
Affects §5 (the Veil is a place in `data/places.json`), §12 (nothing new on
the journey).

### One scene, two places

- `scenes/places/Veil.tscn` + `scripts/places/veil.gd` is **not a Place**:
  nothing walks here and nothing can be used, so it does not carry the
  player, the camera rig, doors or spawn points. It is a `Node3D` with the
  same `place_requested(place_id, spawn_id)` signal a Place has, so `Main`'s
  existing wiring swaps the next scene without knowing the difference.
- `VeilDown.tscn` and `VeilUp.tscn` instance it with the exports set
  (`direction`, `next_place`, `next_spawn`, `seconds` 90, `early_end_after`
  20, `hold_seconds` 1, `line_ids`); `data/places.json` names them
  `veil_down` and `veil_up`. The Grove's *Dive* and the shrine's basin are
  doors onto those ids; the Veil's own exports say where it lands:
  `street` / `fountain_basin` on the way down, `grove` / `pool_bank` on the
  way up. Both are data to be pointed elsewhere; neither spawn point exists
  yet (the Street puts the player in the basin by default, which is where
  the fall ends).
- The two ways are one scene because GDD §5 asks for "one particle system,
  two directions": every constant is shared and `direction` only flips the
  sign of the stream, the start and end colours, the glow and the Song.
- At the end: a fade to black over 1.2 s, the Song fading with it, then
  `GameState.set_place(next_place, next_spawn)` and `place_requested`, in
  that order, as a door does.

### What is on screen

- **Stars**: two `MultiMeshInstance3D` segments sharing one `MultiMesh` of
  180 billboard quads each (360 points, 720 triangles, two draw calls),
  stacked 60 m apart and leapfrogging past the camera, so the field is
  endless with no per-point work per frame. Built from a seeded RNG in
  `_ready`, uniform over the ring's area. Star white with a little nebula
  violet, never warm (GDD §10). Four low-poly spheres are the bubbles; they
  rise through the water, so they overtake the stars on the way down and
  lag them on the way up.
- **Camera**: at the origin, looking a little down the fall (up the rise),
  swaying slowly on its own. A drag or the right stick tilts it through
  `TouchControls.camera_dragged`, the same seam the Place uses, with the rig's
  radians-per-pixel and the journey's sensitivity and inversion settings.
  The HUD is instanced and then emptied: joystick, button, pause, map and
  compass hidden (GDD §11 "HUD: empty by default"). A tap does nothing.
- **Colour**: a `ColorRect` vignette (a radial mask in a canvas shader) drains
  from nebula violet to blue-black over the descent and warms from blue-black
  to rose-gold over the ascent; the sky behind the stars follows it at a
  third of the brightness. A second rect with the mask inverted is the
  player's own glow, fading out on the way down and in on the way up.
  Rose-gold here is `(0.92, 0.64, 0.50)`: copper rather than pink, so it is
  nowhere near magenta; blue-black `(0.02, 0.03, 0.09)` is nowhere near
  peacock blue.
- **Lines** (§8 Scene B, "one line at a time"): `line_ids` on the Veil, three
  on the way down (`veil.line.easy`, `veil.line.harder`,
  `veil.line.never_closed`), none on the way up. Each has its share of the
  middle of the sequence and fades in, holds and fades out.

### The early end (accessibility)

- No *Skip* is offered; the first fall is meant to be sat through. After
  `early_end_after` (20 s) a touch held still for `hold_seconds` (1 s) ends
  it, as does holding the `contextual` action (E, gamepad A) for desktop and
  gamepad parity. GDD §11: "No timed input anywhere"; a player who cannot
  wait, or whose assistive setup needs to move on, is not held in a
  cinematic. A finger that moves more than the tap slop is a drag, not a
  hold, and letting go cancels.
- There is no meter: the view darkens as the finger stays, and the ending
  is simply the darkening completing. Releasing brings the view back over
  0.3 s. This is the hold's own feedback, not a progress bar.

### The Song

- `tools/audio_parts/veil.py` writes `song_layers_down.ogg` and
  `song_layers_up.ogg` through `tools/gen_audio.py`: three PLACEHOLDER
  layers (a band-limited triangle melody on Tulu's G A C, a low drone, a
  plucked arpeggio) standing in for the Song's flute, tanpura and tabla
  (GDD §10 *Veil*: "same recording, mixed differently"). The way down loses
  the melody, then the arpeggio, then the drone, to silence by 97 %; the
  way up mirrors the gains in time. 90 s each, 44.1 kHz, about 210 KB each.
- The import leaves `loop` off: each file is exactly as long as the
  sequence, and a loop would bring the full Song back after the silence (or
  the silence back after the full Song). A longer `seconds` wants a longer
  file, not a loop.
- `gen_audio.encode` now feeds libsndfile ten seconds at a time: its Vorbis
  encoder segfaults when handed more than about two million frames in a
  single write, which these are the first sounds to do. Short sounds are
  unaffected and their committed files were left as they were.

### Budget

Not measured in a web build (no exports this phase). Statically: two
MultiMesh draw calls (720 triangles), four spheres (about 580 triangles),
three full-screen `ColorRect`s with a tiny shader, one label and the HUD.
No lights, no shadows, no environment effects.


## 2026-10-20 — The Fence (side quest)

GDD §7 "The Fence", §4 Vasanti, §6 "Carry" and "Choice", §12 (the flag
model). All three outcomes play from `data/quests/the_fence.json` and
`data/dialogue/en.json`; no code reads a path.

### What was built

- **The garden** (`tools/street_parts/garden.py`, generated into the
  street as `Garden`): north of the padlocked fence, six timber beds with
  dusty soil and a few plants (Kenney's bush, small), a water drum, a path
  from the gate, a white sign board whose words come from the string table
  (`sign.garden`, `sign.garden_rule`), and the fruit tree: Quaternius'
  Tree_5 at 0.7 with five warm-orange fruit on the higher branches
  (`assets/materials/fruit.tres`; the low branch is bare, which is the
  quest). The one shared-file edit: `tools/gen_street.py` leaves the gate's
  span of fence rail out (`GATE_SPAN`), so the part can hang a gate in it.
- **The gate** (`scripts/quest/garden_gate.gd` on `GardenGate`): a leaf of
  rails and bars hinged on the fence post west of the opening, hanging ajar
  into the garden (yaw 0.45) so the padlock on the gate post keeps nobody
  out — GDD §4: she *wants* to fence the tree; she has not managed it.
  *Mend* (`verb.fix`) is an Interactable with `requires = ["talked_vasanti"]`
  (data), enabled only with free hands; it fires `fence_mended` and the leaf
  swings true. When `garden_open` is set the padlock — the street's own
  `Fences/Padlock`, named by `padlock_path` — disappears and the leaf swings
  wide. The flag and the event are exports on the node.
- **The tree** (`scripts/quest/fruit_tree.gd`): *Pick up* hands the player
  a `fruit`, hides one sphere and fires `fruit_picked`. `fruit` joined the
  player's `carryables` (`scenes/quest/Fruit.tscn`, held in the palm).
- **Vasanti** (`scenes/npc/Vasanti.tscn`, `scripts/npc/vasanti.gd`, the
  skaterFemaleA skin) on the kerb at the gate. *Talk* opens the first of
  `entry_lines` whose `requires` hold (gift, opens, after-fixed, hum clue,
  again, greet). While the player holds a fruit she offers *Place* instead
  (`requires = ["carrying_fruit"]`); placing fires `fruit_given` and she holds
  the fruit from then on. When the quest sets `has_fruit` she puts a fruit
  in the player's hand and says so.
- **The quest** starts on `talked_vasanti` or `fruit_picked` (she is the
  giver; a player who never meets her never sees its line in the pause
  menu). Branches: `fixed` on `event:fence_mended` → `has_fruit`,
  *"You lifted Vasanti's gate back onto its hinge; she gave you fruit."*;
  `open_told` on `flag:told_vasanti_thief` and `open_gift` on
  `event:fruit_given` → `garden_open` (and `fruit_received` for the gift),
  both *"Vasanti took the padlock off the garden gate."*

### Decisions

- **Finding the thief** is Tulu (GDD §7: hungry; he gave it to Nanda), but
  Tulu has only *Listen* in the slice. The clue comes from Vasanti's second
  visit, and only once the player has heard Tulu: `vasanti_hum_clue`
  requires `heard_tulu` and `sets` `fence_thief_known` as it is shown; the
  card that names him sets `told_vasanti_thief`, which the quest turns into
  `garden_open`, so her answer (`vasanti_opens`, requires `garden_open`) is
  available in the same breath. A player who has not heard Tulu gets
  `vasanti_again` instead, with nothing to accuse anyone of.
- The three endings exclude each other through the gate and her hands,
  not through code that knows the paths: *Mend* is gone once the gate is
  settled (mended or open); *Place* is gone once a fruit has changed hands
  either way (`fruit_given` or `has_fruit`).
- The fence has no collision (it never had); the gate is a picture, not a
  wall. Making it a wall would make (c) impossible while locked.
- `garden_open` is set by the quest, not by the card, so both open paths
  set it in one place (as `gave_dry_fountain` is set by the Dry Fountain's
  step, not by the fountain).
- Orange is an albedo here, not a light: the Glimpse's warm backlight stays
  the only warm *source* in the scene (GDD §10).
- Placeholders: the body (GDD §4 Vasanti), the beds, drum, sign and gate
  (GDD §10 props), Tree_5 and the sphere fruit (GDD §10 "fruit").

### Budget

Not measured in a web build here (the parallel-agent brief forbids exports
on the shared machine). Added to the street at the garden angle: five
MultiMesh/batch draws (planks, soil, stakes, plants, tree ×2 surfaces),
five fruit spheres, eight gate solids, a board, two labels, two posts, a
drum and one more skinned body — on the order of twenty-five draw calls and
a few thousand triangles, against P6's median 112 / max 177 and 56k.
The integrator should record the numbers with the next web build.


## 2026-10-20 — A car to drive on the Street

Owner request ("enter inside cars, drive"). GDD §6 names movement as the
first of the five things the player does; this is that at another pace.
Affects §6 (movement and camera), §11 (the controls card), §12 (nothing of
it is saved). CLAUDE.md's "never a meter" binds: no speedometer, no fuel, no
damage, no lap, no number anywhere, and a test looks for one.

### One car, one verb, the Place at the wheel

- `scenes/vehicles/Car.tscn` with `scripts/vehicles/car.gd` (`DriveableCar`):
  a `CharacterBody3D` wearing Quaternius' SportsCar2 (CC0, already in the
  rights register; it faces +Z in the file and is turned half round so the
  body faces -Z like everything that moves). An `Interactable` `%Enter`
  round it offers *Drive* (`verb.drive`); the verb the button shows while
  driving is data on the car (`exit_verb_id`, `verb.exit` "Get out").
- Arcade kinematics, no wheels simulated: the raw stick's Y is the
  throttle, its X the wheel. 11 m/s forward, 3 m/s in reverse; 6 m/s² on the
  throttle, 12 m/s² braking, 3 m/s² coasting, and the brake again when
  nobody is at the wheel, so a left car does not roll. The yaw rate is
  1.5 rad/s at full lock from 4 m/s up and proportional below: a standing car
  does not spin on the spot, and reversing swings the nose the other way.
  The player's three-sweep step-up, at 0.25 m, takes kerbs; walls, the
  fountain's lip and the parked cars stop it, keeping only what the wall
  left (a head-on halt, or a scrape along).
- Collision layers 1 and 2, mask 1. Layer 2 so it meets the world as the
  player does; layer 1 as well so the player and the camera meet it as a
  wall rather than walking through it (the parked cars' collider boxes are
  on layer 1 for the same reason). The task said layer 2; the extra bit is
  the whole difference.
- `scripts/places/place.gd` owns the seat, in one delimited block.
  `board(car)` hides the player (invisible, `PROCESS_MODE_DISABLED` so the
  body leaves the physics space, carried along inside), points the camera
  rig at the car and feeds it the raw stick; `leave_car()` stands them beside
  the left door (the right if the left is against something), visible and
  solid again. The button says *Get out* throughout; the compass heading is
  the car's; the hum, tap-to-walk and the doors are off the table from the
  seat; pause works as it always did. The desktop key fires the button
  whenever a verb shows, so E gets out too.
- The camera rig has two follow profiles (`set_follow_profile`). Walking is
  GDD §6's 3.5 m at shoulder height; the car is seen from 6 m at 1.6 m, and
  the rig eases round behind the nose whenever the car rolls (the run's
  auto-align without the run), so steering reads. A drag still orbits and
  the ease resumes 1.5 s later.
- Not saved. The journey knows places and spawn points, never a seat (GDD
  §12: one object to save), so a reloaded journey is on foot and the car is
  back at the kerb. The car's position is not saved either: it is set
  dressing with a verb, not state. A test holds that boarding changes
  nothing in `GameState.to_dict()`.

### The street

- `tools/street_parts/car.py` parks the car at the north kerb of the
  east-west road, nose east, where `gen_street.py`'s `PARKED` list stood the
  same SportsCar2; that entry and its collider box are gone from the list,
  the one edit to the generator. It also raises four invisible walls
  (`StaticBody3D` boxes, 6 m tall) just outside the ground slabs (x ±65,
  z ±45): a car at 11 m/s can never leave the block, and nor can a walker
  fall off its edge now.
- `tools/audio_parts/engine.py` makes `engine_loop.ogg`, a 3 s synthesized
  idle (a 24 Hz firing stack over a 12 Hz sub, low-passed at 500 Hz, ends
  cross-faded; `loop=true` set by hand in the `.import` as the other beds
  have it). The car pitches it from 0.8 at rest to 1.6 at top speed: one
  loop is the whole engine.
- Strings `verb.drive`, `verb.exit`, `controls.<scheme>.drive`. The controls
  card's keys are a const `LINE_KEYS` on `controls_hint.gd` now, with
  `drive` added; its test counts that const rather than five.

### Placeholders

- The SportsCar2 body: a generic stylised vehicle of GDD §5 ("vehicles and
  clothes are generic") replaces it.
- `engine_loop.ogg`: a recorded engine under GDD §10's Hollow Vale bed.

### Budget

Not re-measured in this change (no web build in the agent's run). The car
is one more instance of a model already in the scene (one draw call), the
walls are colliders with no mesh, and the engine is one 3D stream; the next
web-build pass should confirm against P6's numbers.
