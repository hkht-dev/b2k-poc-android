# Journey Back to Krishna — Slice 1 ("The Street")

A 3–4 minute grey-box vertical slice of Act 3 (Hollow Vale) from
[`docs/GDD.md`](docs/GDD.md), built to answer one question in front of ten
strangers:

> Does a player follow sound instead of instructions, notice a figure nobody
> else sees, and make one choice that feels like it matters — without anyone
> telling them this is a spiritual game?

This is **not** the full game. What is in and out of the slice is listed in
[`CLAUDE_CODE_BRIEF.md`](CLAUDE_CODE_BRIEF.md) §0, and the build order is in §3.

**Current phase: P2 (flags and data).** The street is walkable and textured;
flags, the journey save, quests and dialogue load from `data/`; the debug
panel (five taps on the title) lists and sets every flag. Tulu and *Listen*
arrive in P3.

## Controls

The layout follows the device: touch screens get the joystick and two zones; a desktop browser or build gets the keyboard, with the mouse orbiting anywhere and no joystick; a gamepad hides it too. The controls card on first play shows the scheme in use.

On a phone, the first time you press *Begin* a card tells you this; after that
it stays out of the way:

| | Phone | Desktop | Gamepad |
|---|---|---|---|
| Walk | Left thumb, anywhere on the left 45% | W A S D / arrows | Left stick |
| Run | Hold a full push for half a second | Keep holding | Push all the way, hold |
| Look | Right thumb, drag | Drag the mouse (either button) | Right stick |
| Walk there | Tap a spot on the right | Click the ground | — |
| Climb | Walk into a ledge | Walk into a ledge | Walk into a ledge |
| Use | The one button, lower right, when something is near | E | A |
| Hum | Hold that button with nothing near | Hold E | Hold A |
| Listen | The button says *Listen* beside a sound | E | A |
| Pause | Button top-left | Esc | Start |

There is no jump button. The pause menu has *Controls* (this card, with a
diagram), *Map*, a plain minimap that is off until you turn it on, and
*Settings*: joystick side, size and opacity, camera sensitivity and
inversion, large text, a box behind subtitles, sounds shown as ripples, and
tap-to-walk. Each is saved at once.

A compass strip at the top shows which way you face. Two shops on the
south side of the street can be walked into: stand at the door and the
button says *Go in*; inside, the door says *Go out*. The journey remembers
which side of the door you were on.

Beyond the slice (owner expansion, see `docs/SLICE1_SPEC.md` E1–E4): a car
to drive at the north kerb (*Drive*, the stick steers, *Get out*), a
showroom to try clothes on in, the shrine room behind the chai stall,
Dhanpal's hall and office, Nanda's flat, the community garden, the tower
with its ladder and the Veena at dawn, a rooftop run over the south flats,
two stray cows your hum can lead to the fountain, Sarang's music lesson,
Tells to *Look* at, a lamp you can set down with one of twelve lines, a
garden of what you chose in the pause menu, a tale on a painted scroll, one
new stranger a day, and, through the fountain basin once the give path is
taken, the Grove and the Pool.

The slice ends at the bus stop: walk there after the can has been placed or
taken, or sit there (the button says *Sit*) once you have played a minute
and a half. *Play again* starts a fresh journey.

## Install the build on an Android phone

1. On the phone, open the [latest release][releases], or scan this:

   <img src="docs/assets/qr-latest-release.png" alt="QR code linking to the latest release" width="180">

2. Download the `.apk` asset.
3. Android will ask whether to allow installs from your browser. Allow it —
   the build is debug-signed, not a Play Store build, so this prompt is normal.
4. Open the downloaded file and install.
5. To remove it: Settings → Apps → *Journey Back to Krishna* → Uninstall.

Every push to `main` publishes a new release tagged `slice1-build-<run>`. The
same APK is also on the run's page under the **Actions** tab, as an artifact, if
you would rather pull it from there.

[releases]: https://github.com/hkht-dev/b2k-poc-android/releases/latest

## Testing on a desktop

Three ways, easiest first.

**1. A desktop build, no Godot needed.** Every push to `main` runs the
*Desktop* workflow, which attaches `journey-back-to-krishna-windows-<run>.zip`
and `journey-back-to-krishna-linux-<run>.zip` to the run on the **Actions**
tab. Download, unzip anywhere, run `journey-back-to-krishna.exe` (Windows
SmartScreen will warn that the publisher is unknown — *More info → Run
anyway*) or `./journey-back-to-krishna.x86_64` on Linux. Controls: **W A S D**
or the arrow keys to walk, **drag the mouse** to look around, **E** for the
contextual button. The game is portrait on purpose; the window is tall.

**2. The Godot editor** (any OS). Install
[Godot 4.3](https://godotengine.org/download/archive/#4.3-stable) — exactly
4.3 — then *Import* this folder's `project.godot` and press **F5**. Import it
twice the first time (see below). Same controls as above, and you can edit
anything.

**3. A local web build.** With Godot 4.3 and its export templates installed:

```sh
mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html
python3 -m http.server 8000 --directory build/web
```

Then open <http://localhost:8000> in Chrome or Firefox. It must be served over
HTTP like this — opening `index.html` straight from the disk will not run.

Why the Web preset has *thread support* off: GitHub Pages does not send the
`Cross-Origin-Opener-Policy` / `Cross-Origin-Embedder-Policy` headers that
Godot 4's threaded web export needs, so a default export shows a blank page.
With threads off (Godot 4.3+) it runs anywhere; audio uses the sample-playback
fallback, which is fine for the slice.

## Play it in a browser

The web build of `main` is at
<https://hkht-dev.github.io/b2k-poc-android/>, with WASD and the mouse
standing in for touch.

It exists so the team can look at a change quickly. **Touch feel and
performance are judged on Android, never here** — the web build runs Godot's
Compatibility renderer, not the Mobile renderer the phone build uses.

## Test devices

Record frames per second on all three. The slice must hold a steady 30 fps on
the 2020 mid-range phone (`CLAUDE_CODE_BRIEF.md` §11).

| Class | Device | Android | Build tested | Median fps | Lowest fps | Crashes | Notes |
|---|---|---|---|---|---|---|---|
| 2019 low-end | _to be chosen_ | | | | | | the floor |
| 2020 mid-range | _to be chosen_ (Adreno 610 class) | | | | | | **the target** |
| Recent flagship | _to be chosen_ | | | | | | headroom |

## Working on it

You need [Godot 4.3](https://godotengine.org/download/archive/#4.3-stable) —
exactly 4.3, pinned in `project.godot` and in all three workflows.

```sh
# First open: import twice. GUT's editor plugin loads images and fonts during
# the first pass, before they have been imported. See docs/DECISIONS.md.
godot --headless --import --path . || true
godot --headless --import --path .

# Tests (not gut_cmdln directly — see CLAUDE.md)
tools/run_tests.sh

# Format and lint exactly as CI does
pip install "gdtoolkit==4.3.*"
gdformat $(git ls-files '*.gd' | grep -v '^addons/')
gdlint   $(git ls-files '*.gd' | grep -v '^addons/')

# Data files
python3 tools/check_data.py
```

Or open the project in the Godot editor and press F5.

### Building an APK yourself

`tools/build_apk.sh` does what `.github/workflows/android.yml` does, on your
machine. You need Godot 4.3, a JDK 17 or newer, and an Android SDK with
`build-tools;34.0.0` and `platforms;android-34`.

```sh
export ANDROID_HOME=/path/to/android-sdk
export GODOT=/path/to/godot        # if it is not on PATH as `godot`
tools/build_apk.sh                 # writes build/android/*.apk, verifies the signature
```

It generates a debug keystore on first run. The keystore is gitignored and only
ever signs sideload builds.

> **The three workflows are still unverified.** They have never executed a
> step: a GitHub-wide Actions incident on 2026-10-19 held every run in the
> queue. See `docs/DECISIONS.md`. This script is how builds get made meanwhile,
> and it is worth keeping regardless — it is the fastest way to get an APK onto
> a phone without waiting on CI.

### Layout

| Path | What lives there |
|---|---|
| `data/` | Every quest, line of dialogue and player-facing string. No text is baked into a scene. |
| `scenes/`, `scripts/` | Mirror each other; one `.gd` per scene, shared code in `scripts/lib/`. |
| `assets/` | Procedural textures from `tools/gen_textures.py`; CC0 Poly Haven textures and models and Kenney kits (cars, trees, the rigged animated characters) under `assets/thirdparty/`, fetched by `tools/fetch_polyhaven.py` and `tools/fetch_kenney.py` (decimated and stylised on the way in) and listed in `docs/RIGHTS_REGISTER.md`; primitive meshes elsewhere. Each carries a `PLACEHOLDER` comment naming its replacement from GDD §10. |
| `tests/` | GUT tests. |
| `tools/` | Checked-in scripts CI runs. |
| `docs/` | The GDD, the slice spec, every decision, the playtest protocol. |

### House rules

The full list is in [`CLAUDE.md`](CLAUDE.md). The two that get broken most:

- **No score, meter, points, badge, map marker, timer or "correct" answer**
  anywhere — including debug UI wording.
- **Flags and string ids are data, never literals.** If you are about to write
  `if path == "compete"`, stop and use a flag.

## Releases and secrets

`main` publishes a debug-signed APK on every push. If the repository secrets
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and
`ANDROID_KEY_PASSWORD` are set, the same workflow also exports a release-signed
`.aab` for the Play Console. Without them that step is skipped and the APK still
builds.

Keystores, passwords and export templates are never committed.

## Licensing

Fonts are Noto Sans, Noto Serif and Noto Serif Devanagari under the SIL Open
Font License; the licence text sits beside them in `assets/fonts/`. The test
framework in `addons/gut/` is [GUT](https://github.com/bitwes/Gut) 9.3.0, MIT.
