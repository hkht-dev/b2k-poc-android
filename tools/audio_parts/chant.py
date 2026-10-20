"""Madhuri's chant: a soft looping drone with a slow two-note sway, 8 s.

GDD §5 Hollow Vale: "the shrine room leaks a faint drone of Madhuri's
chanting under the traffic"; GDD §10 "Sound": "Madhuri's chanting is recorded
by a devotee with permission and credited. The maha-mantra is mixed low under
the shrine." GDD §7 micro-interaction: "Hum near the shrine: Madhuri's chant
rises to meet the note."

PLACEHOLDER for that recorded maha-mantra. Two sustained voice-like tones a
tone apart (D3, E3) cross-fade once over the loop, over a faint root drone an
octave below; a slow breath swells the whole. Every frequency and modulation
rate fits a whole number of cycles into the 8 s, so the loop has no seam.
"""

from __future__ import annotations

import numpy as np

from gen_audio import RATE, lowpass, t

SECONDS = 8.0
# Loop-safe pitches: k / SECONDS Hz, nearest to D2, D3 and E3.
ROOT = 587 / SECONDS  # 73.4 Hz, D2
LOW = 1175 / SECONDS  # 146.9 Hz, D3
HIGH = 1318 / SECONDS  # 164.8 Hz, E3


def _voice(freq: float, x: np.ndarray, vibrato_cycles: int) -> np.ndarray:
    """A sung tone: a few harmonics with a slow, shallow vibrato."""
    vib = 1.0 + 0.0035 * np.sin(2 * np.pi * vibrato_cycles / SECONDS * x)
    phase = 2 * np.pi * freq * np.cumsum(vib) / RATE
    return (
        np.sin(phase) * 0.55
        + np.sin(2 * phase) * 0.25
        + np.sin(3 * phase) * 0.12
        + np.sin(4 * phase) * 0.05
    )


def madhuri_chant() -> np.ndarray:
    x = t(SECONDS)
    # One full sway per loop: the low note gives way to the high and back.
    sway = 0.5 - 0.5 * np.cos(2 * np.pi * x / SECONDS)
    low = _voice(LOW, x, 40)
    high = _voice(HIGH, x, 44)
    voice = low * (1.0 - sway) + high * sway
    drone = np.sin(2 * np.pi * ROOT * x) * 0.6 + np.sin(2 * np.pi * ROOT * 2 * x) * 0.2
    # Two slow breaths a loop, never fully silent.
    breath = 0.8 + 0.2 * np.sin(2 * np.pi * 2 / SECONDS * x - np.pi / 2)
    mix = voice * 0.5 * breath + drone * 0.22
    return lowpass(mix, 1100) * 0.6


SOUNDS = {"madhuri_chant": madhuri_chant}
