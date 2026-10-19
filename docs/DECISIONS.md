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
