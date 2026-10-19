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
| Pause | Button top-left | Esc | Start |

There is no jump button. The pause menu has *Controls* (this card, with a
diagram) and *Map*, a plain minimap that is off until you turn it on.

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

**1. The Windows build.** Each hand-built release includes
`journey-back-to-krishna-windows.zip`. Unzip it anywhere and run
`journey-back-to-krishna.exe`. Windows SmartScreen will warn that the
publisher is unknown — *More info → Run anyway*. Controls: **W A S D** or the
arrow keys to walk, **drag the mouse on the right half** of the window to look
around, **E** for the contextual button. The game is portrait on purpose; the
window is tall.

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
| `assets/` | Procedural textures from `tools/gen_textures.py`; CC0 Poly Haven files under `assets/thirdparty/` fetched by `tools/fetch_polyhaven.py` and listed in `docs/RIGHTS_REGISTER.md`; primitive meshes. Each carries a `PLACEHOLDER` comment naming its replacement from GDD §10. |
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
