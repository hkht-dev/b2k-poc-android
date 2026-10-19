# Brief amendment 1 — controls, visuals, size budget, desktop and web testing

This amends `CLAUDE_CODE_BRIEF.md`. Where the two conflict, this file wins. Apply it during P1 (controls, visuals) and P0-level CI changes (desktop export, web headers); record each item in `docs/DECISIONS.md`.

## A. Controls on phone (replaces brief §4.2 touch section)

The current build routes almost every touch to the camera. Fix the input model and make the controls discoverable.

1. **Split the screen into two touch zones.** Left 45% of the screen: the first touch spawns the virtual joystick under the finger (floating joystick, not fixed) and that finger owns movement until it lifts. Right 55%: a drag orbits the camera. Track touches by `index` so one finger on each side works at the same time. A touch on the contextual button is consumed by the button and never reaches either zone.
2. **Dead zone and curve.** 12% joystick dead zone; cubic response curve; auto-run at 85% deflection after 0.5 s. Movement direction is camera-relative.
3. **Tap-to-walk is on by default on touch devices.** A single tap (no drag, under 200 ms, under 10 px movement) on the right zone walks the player to that point on the ground; the joystick still works. Dragging never walks.
4. **Camera auto-align.** When the player runs for more than 1.5 s without a camera drag, the camera eases back behind the player. Camera sensitivity default on touch is half the desktop default.
5. **Controls screen, per device.** Detect the platform (`OS.has_feature("mobile")`, `web`, else desktop; detect a connected gamepad with `Input.get_connected_joypads()`) and show the matching scheme:
   - On first launch, a one-screen overlay (skippable, "Got it" button) with a simple diagram: left thumb = move, right thumb = look, tap = walk there, button = the verb shown, hold button = hum.
   - The same screen is always available from the pause menu under *Controls*.
   - During the first 60 seconds of play, if the player has not moved, show a soft pulsing hint in the left zone ("drag here to walk") that disappears on first movement. No other tutorial text.
   - Desktop/web scheme: WASD move, mouse drag (hold right or left button) to look, E = verb, hold E = hum, click on ground = walk there, Esc = pause. Gamepad: left stick, right stick, A, hold A, Start.
6. **Settings keep** joystick side/size/opacity, camera sensitivity and inversion, tap-to-walk on/off.

Acceptance: a new tester on a phone can walk out of the fountain and reach Tulu within 60 seconds with no verbal instruction. Test this with two people before merging P1.

## B. Visuals (replaces brief §4.1 "no textures" and §6 asset rules)

Grey boxes are no longer acceptable. The target for Slice 1 is a **textured, stylized, readable city block** in the GDD §10 palette. Not photoreal; the GDD's painted-stylized direction stands.

1. **Textures are required** on every surface: road, pavement, kerbs, walls, roofs, shutters, the fountain, the tower. Use tiling textures with a stylized/hand-painted look, 1024 or 2048 atlases, GPU-compressed (ETC2/ASTC on Android).
2. **Allowed sources, in this order:**
   - Procedurally generated in-repo (a checked-in `tools/gen_textures.py` producing brick, plaster, concrete, asphalt, corrugated metal, wood, with colour variation and grime masks). Prefer this for tiling surfaces.
   - **CC0 asset libraries are now allowed**: Kenney (kenney.nl), Poly Haven, ambientCG. Each imported asset gets a row in `docs/RIGHTS_REGISTER.md` (source URL, licence, date, where used). Nothing from any other licence. No AI-generated textures ship.
   - Models: low-poly stylized building/prop kits from the same CC0 sources, re-coloured to the palette. Kenney's city kits are a good base.
3. **Density pass** (as proposed): kerbs, road markings, lamp posts, awnings, rooftop water tanks, AC units, shop signs in an invented script, parked cars with wheels, cables between buildings, a few trees. Batch static geometry with `MultiMeshInstance3D` or merged meshes so draw calls stay under 200.
4. **Characters** may stay simple but not capsules: a low-poly humanoid with a textured coat for the player, a smaller one for Tulu, a broader one for Gopal, each with a walk, idle and carry animation (CC0 rigs and Mixamo-style clips are acceptable if CC0; otherwise simple procedural bob). Faces can be flat-shaded.
5. **Lighting**: baked `LightmapGI` for the block, one directional light, a subtle `WorldEnvironment` with SSAO off, tonemapping on, slight fog toward the overcast white. Still no pink, magenta or peacock blue in the Street except the Glimpse backlight and the feather.
6. **Camera feel**: FOV widens from 65 to 72 when running; camera lags the player by ~0.15 s; a small head-bob on run. This is the "GTA vibe" that is in scope. Photoreal materials, real-time shadows on mid-range, and large PBR asset sets are not.

## C. Size and performance budget (replaces brief §1 install size)

- Install size limit for Slice 1 is lifted to **250 MB** APK. Keep textures compressed and do not ship source PSD/PNG masters in the APK (`.gdignore` the `tools/` folder and any `*_src` directories).
- Frame budget stays: 30 fps on a 2020 mid-range Android phone, under 200 draw calls, under 150k triangles. If textures push a device below 30 fps, add a quality tier (half texture resolution, foliage off) rather than cutting the look.

## D. Testing on desktop and in a browser (add to README.md)

**Desktop (fastest way to iterate):**
1. Install Godot 4.3 (standard build, not .NET) from godotengine.org.
2. Clone the repo; open Godot; *Import* → select `project.godot`; press F5 (Run Project) or F6 (run the current scene).
3. Add a desktop export preset (Linux/Windows/macOS) and a `desktop.yml` workflow that uploads a zipped desktop build as a workflow artifact on every push to `main`, so a build can be downloaded and run without installing Godot.

**Web browser:**
1. The `web.yml` workflow deploys to GitHub Pages at `https://<org>.github.io/<repo>/`.
2. GitHub Pages does not send the `Cross-Origin-Opener-Policy` / `Cross-Origin-Embedder-Policy` headers that Godot 4's threaded web export requires, so a default export shows a blank page. Fix it by exporting with **thread support disabled** (`variant/thread_support = false` in the Web preset; available since Godot 4.3). Audio uses the sample-playback fallback in that mode; that is fine for the slice.
3. The web build is for desktop browsers (Chrome or Firefox). It is review-only; touch feel and performance are judged on Android.

**Android:**
- Debug APK from the Releases page (QR code in the README); enable *Install unknown apps* for the browser used; install; launch.

## E. Unchanged

Everything else in the brief stands: scope (§0), flags-only conditionals, no score/meter/marker, data-driven quests, one PR per phase, placeholders tagged with their GDD replacement (now applies to CC0 stand-ins too).
