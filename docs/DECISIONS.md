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
