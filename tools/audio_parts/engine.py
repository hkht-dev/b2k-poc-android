"""The driveable car's engine: one low loop the car pitches with its speed.

tools/street_parts/car.py parks the car; scripts/vehicles/car.gd plays this
from 0.8x at rest to 1.6x at top speed, so a single three-second loop is the
whole engine. Found by tools/gen_audio.py through scenegen.load_parts.

PLACEHOLDER for a recorded engine in GDD §10's Hollow Vale sound bed
("wind, hammering and counting" under "traffic that never stops", GDD §2).
"""

from __future__ import annotations

import numpy as np

from gen_audio import RATE, lowpass, t

# The loop is this long once the ends are cross-faded away.
LOOP_SECONDS = 3.0
FADE_SECONDS = 0.25
# An idling engine: firing pulses at this rate. 24 x 3 is a whole number of
# cycles, so every harmonic meets itself at the join.
FIRING_HZ = 24.0
SEED = 1108


def engine_loop() -> np.ndarray:
    x = t(LOOP_SECONDS + FADE_SECONDS)
    # Firing pulses as a bright harmonic stack, then a sub-tone at half the
    # rate for the body of the sound.
    wave = np.zeros_like(x)
    for n in range(1, 9):
        wave += np.sin(2 * np.pi * FIRING_HZ * n * x) / n
    wave += 0.6 * np.sin(2 * np.pi * FIRING_HZ * 0.5 * x)
    # One slow breath per loop so the idle is not a fixed tone.
    wave *= 0.85 + 0.15 * np.sin(2 * np.pi * x / LOOP_SECONDS)
    g = np.random.default_rng(SEED)
    rattle = lowpass(g.standard_normal(len(x)), 900) * 0.25
    out = lowpass(wave * 0.35 + rattle, 500)
    # Cross-fade the ends so the loop has no seam (the rattle is not periodic).
    n = int(RATE * FADE_SECONDS)
    out[:n] = out[:n] * np.linspace(0, 1, n) + out[-n:] * np.linspace(1, 0, n)
    out = out[: len(out) - n]
    return out / np.max(np.abs(out)) * 0.6


SOUNDS = {"engine_loop": engine_loop}
