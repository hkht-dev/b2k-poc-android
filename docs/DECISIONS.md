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
