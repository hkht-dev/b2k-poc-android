"""One note of the Song, hummed by the Counting Man once he is freed.

GDD §7 "The Counting Man": "he walks off down the street and later hums one
note of the Song." The note is G4, the first of Tulu's three (gen_audio.py:
G4 A4 C5), so the ear can place it. One second, soft, the same hummed
triangle as his.

PLACEHOLDER for GDD §10 "Music": the first note of the Song, sung by a man,
recorded by the composer.
"""

from __future__ import annotations

import numpy as np

from gen_audio import envelope, lowpass, t, triangle

G4 = 392.00


def one_note() -> np.ndarray:
    dur = 1.0
    wave = triangle(G4, dur) * 0.5 + triangle(G4 * 2.0, dur) * 0.1
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.0 * t(dur))
    wave = np.interp(t(dur) * vib, t(dur), wave)
    return lowpass(wave, 1600) * envelope(len(wave), 0.08, 0.35) * 0.45


SOUNDS = {"one_note": one_note}
