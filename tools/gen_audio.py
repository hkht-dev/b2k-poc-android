#!/usr/bin/env python3
"""Generate the slice's placeholder audio and write it as OGG Vorbis.

CLAUDE_CODE_BRIEF.md §6: Tulu's three notes as a soft triangle melody that
implies a resolution (G4 A4 C5), the player's hum as a filtered tone with
vibrato, a flat street bed (band-passed noise and a low rumble), and a water
loop (filtered noise with amplitude modulation). Every file is a loop and
documented here so the composer can replace it 1:1 (GDD §10 "Music": Tulu's
notes are the first three notes of the Song, sung by a child).

    python3 tools/gen_audio.py            # writes assets/audio/*.ogg
    python3 tools/gen_audio.py --check    # fails if any OGG is stale

Requires numpy and soundfile (libsndfile).
"""

from __future__ import annotations

import argparse
import io
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "audio"
RATE = 44100
SEED = 108


def t(seconds: float) -> np.ndarray:
    return np.arange(int(RATE * seconds)) / RATE


def envelope(n: int, attack: float, release: float) -> np.ndarray:
    env = np.ones(n)
    a, r = int(RATE * attack), int(RATE * release)
    env[:a] = np.linspace(0, 1, a)
    env[n - r :] = np.linspace(1, 0, r)
    return env


def triangle(freq: float, seconds: float) -> np.ndarray:
    x = t(seconds)
    return 2 * np.abs(2 * ((x * freq) % 1) - 1) - 1


def lowpass(signal: np.ndarray, cutoff: float) -> np.ndarray:
    """One-pole lowpass, enough to soften a triangle into something hummed."""
    rc = 1.0 / (2 * np.pi * cutoff)
    alpha = (1.0 / RATE) / (rc + 1.0 / RATE)
    out = np.zeros_like(signal)
    acc = 0.0
    for i, s in enumerate(signal):
        acc += alpha * (s - acc)
        out[i] = acc
    return out


def tulu_three_notes() -> np.ndarray:
    """G4 A4 C5, each 0.55 s, a breath, then silence to make a 4 s loop.

    PLACEHOLDER for GDD §10 "Tulu's three notes — the first three notes of
    the Song, sung by a child".
    """
    notes = [(392.00, 0.55), (440.00, 0.55), (523.25, 0.9)]
    parts = []
    for freq, dur in notes:
        wave = triangle(freq, dur) * 0.5 + triangle(freq * 2.0, dur) * 0.12
        vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t(dur))
        wave = np.interp(t(dur) * vib, t(dur), wave)
        parts.append(lowpass(wave, 1800) * envelope(len(wave), 0.04, 0.12))
        parts.append(np.zeros(int(RATE * 0.08)))
    melody = np.concatenate(parts)
    loop = np.zeros(int(RATE * 4.0))
    loop[: len(melody)] = melody
    return loop * 0.55


def player_hum() -> np.ndarray:
    """A single low tone with vibrato, 1.6 s — the traveler humming (GDD §6 Call)."""
    dur = 1.6
    x = t(dur)
    freq = 196.0 * (1 + 0.006 * np.sin(2 * np.pi * 5.0 * x))
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    wave = np.sin(phase) * 0.6 + np.sin(2 * phase) * 0.15 + np.sin(3 * phase) * 0.05
    return lowpass(wave, 900) * envelope(len(wave), 0.15, 0.4) * 0.5


def street_bed() -> np.ndarray:
    """Band-passed noise plus a low rumble, 8 s loop (GDD §10: wind, hammering)."""
    g = np.random.default_rng(SEED)
    dur = 8.0
    noise = g.standard_normal(int(RATE * dur))
    hiss = lowpass(noise, 1200) - lowpass(noise, 250)
    rumble = np.sin(2 * np.pi * 48 * t(dur)) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.21 * t(dur)))
    bed = hiss * 0.18 + rumble * 0.06
    fade = envelope(len(bed), 0.5, 0.5)
    # cross-fade the ends so the loop has no seam
    n = int(RATE * 0.5)
    bed[:n] = bed[:n] * np.linspace(0, 1, n) + bed[-n:] * np.linspace(1, 0, n)
    return bed[: len(bed) - n] * fade[: len(bed) - n]


def water_loop() -> np.ndarray:
    """Filtered noise with slow amplitude modulation, 6 s loop — the fountain
    running after the give path (CLAUDE_CODE_BRIEF.md §4.4)."""
    g = np.random.default_rng(SEED + 1)
    dur = 6.0
    noise = g.standard_normal(int(RATE * dur))
    water = lowpass(noise, 3500) - lowpass(noise, 600)
    mod = 0.7 + 0.3 * np.sin(2 * np.pi * 1.7 * t(dur)) * np.sin(2 * np.pi * 0.4 * t(dur))
    out = water * mod * 0.22
    n = int(RATE * 0.4)
    out[:n] = out[:n] * np.linspace(0, 1, n) + out[-n:] * np.linspace(1, 0, n)
    return out[: len(out) - n]


SOUNDS = {
    "tulu_three_notes": tulu_three_notes,
    "player_hum": player_hum,
    "street_bed": street_bed,
    "water_loop": water_loop,
}
# tools/audio_parts/<name>.py: more sounds, each module a `SOUNDS` dict of
# name -> function returning samples at RATE (import helpers from gen_audio).
sys.path.insert(0, str(Path(__file__).resolve().parent))
from scenegen import load_parts  # noqa: E402

for _part in load_parts("audio_parts"):
    SOUNDS.update(_part.SOUNDS)


def encode(samples: np.ndarray) -> bytes:
    buf = io.BytesIO()
    sf.write(buf, np.clip(samples, -1, 1).astype(np.float32), RATE, format="OGG", subtype="VORBIS")
    return buf.getvalue()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    stale = []
    for name, make in SOUNDS.items():
        path = OUT / f"{name}.ogg"
        if args.check:
            # Vorbis encoding is not byte-stable across libsndfile builds, so
            # --check only asks that every file exists and is not empty.
            if not path.exists() or path.stat().st_size < 1000:
                stale.append(name)
            continue
        path.write_bytes(encode(make()))
        print(f"gen_audio: wrote {path.relative_to(ROOT)} ({path.stat().st_size // 1024} KB)")
    if args.check:
        if stale:
            print(f"gen_audio: missing: {', '.join(stale)}; run tools/gen_audio.py", file=sys.stderr)
            return 1
        print(f"gen_audio: {len(SOUNDS)} sounds present")
    return 0


if __name__ == "__main__":
    sys.exit(main())
