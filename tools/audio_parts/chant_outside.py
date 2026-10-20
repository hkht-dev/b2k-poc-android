"""The shrine room's chant, heard from outside the chai stall's back door.

GDD §5 "the shrine room leaks a faint drone of Madhuri's chanting under the
traffic" and §7 micro-interaction "Hum near the shrine: Madhuri's chant rises
to meet the note". A very soft two-note drone, 8 s: a low root and its fifth
swelling in and out of each other, filtered until it is more felt than heard.

PLACEHOLDER for GDD §10 "Sound": Madhuri's chanting, recorded by a devotee
with permission and credited; the maha-mantra mixed low under the shrine.
"""

import numpy as np

from gen_audio import RATE, envelope, lowpass, t

SECONDS = 8.0
ROOT_HZ = 146.83  # D3
FIFTH_HZ = 220.0  # A3


def chant_outside() -> np.ndarray:
    x = t(SECONDS)
    # Two voices, each with a slow, slightly different vibrato so they beat
    # gently against each other, as two people chanting do.
    root = np.sin(2 * np.pi * ROOT_HZ * x * (1 + 0.003 * np.sin(2 * np.pi * 0.37 * x)))
    fifth = np.sin(2 * np.pi * FIFTH_HZ * x * (1 + 0.002 * np.sin(2 * np.pi * 0.29 * x)))
    # The fifth comes forward as the root recedes, then back, once over 8 s.
    swell = 0.5 + 0.5 * np.sin(2 * np.pi * x / SECONDS - np.pi / 2)
    drone = root * (0.7 - 0.3 * swell) + fifth * (0.25 + 0.35 * swell)
    drone += 0.08 * np.sin(2 * np.pi * ROOT_HZ * 2 * x)
    soft = lowpass(drone, 420)
    return soft * envelope(len(soft), 1.6, 2.4) * 0.16


SOUNDS = {"chant_outside": chant_outside}
