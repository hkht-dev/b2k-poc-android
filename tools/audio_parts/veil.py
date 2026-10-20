#!/usr/bin/env python3
"""The Song as the Veil mixes it: instruments leaving on the way down, returning
on the way up.

GDD §10 "Music", *Veil*: "the Song with instruments removed one by one
(Act 2) or returned one by one (Act 5). Same recording, mixed differently."
§3 Act 2: "With each few seconds the Song loses an instrument"; Act 5: "with
each few seconds an instrument returns".

PLACEHOLDER for the composer's stem mix of the Song. Three layers stand in
for its flute, tanpura and tabla: a soft triangle melody built on Tulu's
three notes (G A C, tools/gen_audio.py), a low drone, and a plucked
arpeggio. `song_layers_down` is LENGTH seconds in which the melody leaves
first, then the arpeggio, then the drone, down to silence; `song_layers_up`
is the same three layers with the gains mirrored in time, so the drone is
there from the start and the melody is the last to return. Both are marked
as loops by the import; the Veil runs their length once.

Run through tools/gen_audio.py, which finds this file by name (scenegen.load_parts).
"""

from __future__ import annotations

import numpy as np

from gen_audio import RATE, envelope, t

LENGTH = 90.0
## G major without its leading tone, around Tulu's G4 A4 C5. Hz.
G2, G3, B3, D4, E4, G4, A4, C5, D5 = (
    98.0, 196.0, 246.94, 293.66, 329.63, 392.0, 440.0, 523.25, 587.33,
)
## Seconds a melody beat lasts: slow, as a fall is.
BEAT = 1.5
## When each layer leaves on the way down, as shares of LENGTH: whole until
## the first number, gone by the second. The way up mirrors these.
LAYER_FADES = {"melody": (0.12, 0.40), "arpeggio": (0.40, 0.68), "drone": (0.68, 0.97)}
LAYER_GAINS = {"melody": 0.34, "arpeggio": 0.20, "drone": 0.30}
## (frequency, beats); 0 Hz is a rest. 17 beats; tiled to LENGTH.
PHRASE = [
    (G4, 1), (A4, 1), (C5, 1), (D5, 2), (C5, 1), (A4, 1), (G4, 1), (E4, 2),
    (G4, 1), (A4, 1), (C5, 2), (A4, 1), (G4, 1), (0.0, 1),
]
## Half-beat plucks on the G triad, low: the tabla's place, softly.
ARPEGGIO = [G3, D4, G4, B3, D4, G4, B3, D4]


def _samples(seconds: float) -> int:
    return int(RATE * seconds)


def soft_triangle(freq: float, seconds: float) -> np.ndarray:
    """A band-limited triangle (four odd partials) with a slow vibrato: the
    flute's line, without the filter loop gen_audio uses on short notes."""
    x = t(seconds)
    vibrato = freq * (1 + 0.004 * np.sin(2 * np.pi * 5.0 * x))
    phase = 2 * np.pi * np.cumsum(vibrato) / RATE
    wave = np.zeros_like(x)
    for k in range(4):
        n = 2 * k + 1
        wave += ((-1) ** k) / (n * n) * np.sin(n * phase)
    return wave * (8 / np.pi**2)


def melody(seconds: float) -> np.ndarray:
    parts = []
    for freq, beats in PHRASE:
        dur = BEAT * beats
        if freq == 0.0:
            parts.append(np.zeros(_samples(dur)))
            continue
        note = soft_triangle(freq, dur)
        parts.append(note * envelope(len(note), 0.12, 0.45))
    phrase = np.concatenate(parts)
    reps = int(np.ceil(_samples(seconds) / len(phrase)))
    return np.tile(phrase, reps)[: _samples(seconds)]


def drone(seconds: float) -> np.ndarray:
    """Two detuned voices on G2 and G3 with a hint of the fifth, beating
    slowly: the tanpura's place."""
    x = t(seconds)
    out = np.zeros_like(x)
    for freq, amp in ((G2, 0.55), (G2 * 1.004, 0.45), (G3, 0.3), (G3 * 0.997, 0.25), (D4 / 2, 0.18)):
        out += amp * np.sin(2 * np.pi * freq * x)
        out += amp * 0.2 * np.sin(2 * np.pi * 2 * freq * x)
    swell = 0.9 + 0.1 * np.sin(2 * np.pi * 0.07 * x)
    out *= swell
    return out / np.max(np.abs(out))


def pluck(freq: float, seconds: float) -> np.ndarray:
    x = t(seconds)
    wave = np.sin(2 * np.pi * freq * x) * np.exp(-x * 5.0)
    wave += 0.3 * np.sin(2 * np.pi * 2 * freq * x) * np.exp(-x * 9.0)
    attack = _samples(0.006)
    wave[:attack] *= np.linspace(0, 1, attack)
    return wave


def arpeggio(seconds: float) -> np.ndarray:
    bar = np.concatenate([pluck(freq, BEAT / 2) for freq in ARPEGGIO])
    reps = int(np.ceil(_samples(seconds) / len(bar)))
    return np.tile(bar, reps)[: _samples(seconds)]


def gain_down(name: str, share: np.ndarray) -> np.ndarray:
    """1 until the layer starts to leave, eased to 0 by the time it is gone."""
    start, end = LAYER_FADES[name]
    p = np.clip((share - start) / (end - start), 0.0, 1.0)
    return 1.0 - (p * p * (3.0 - 2.0 * p))


def layers(seconds: float) -> dict[str, np.ndarray]:
    return {"melody": melody(seconds), "arpeggio": arpeggio(seconds), "drone": drone(seconds)}


def mix(seconds: float, reverse: bool) -> np.ndarray:
    share = t(seconds) / seconds
    if reverse:
        share = 1.0 - share
    out = np.zeros(_samples(seconds))
    for name, wave in layers(seconds).items():
        out += wave * LAYER_GAINS[name] * gain_down(name, share)
    return out * envelope(len(out), 0.8, 0.8)


def song_layers_down() -> np.ndarray:
    """The Song losing its instruments one by one over 90 s, to silence."""
    return mix(LENGTH, reverse=False)


def song_layers_up() -> np.ndarray:
    """The same three layers returning one by one over 90 s, drone first."""
    return mix(LENGTH, reverse=True)


SOUNDS = {
    "song_layers_down": song_layers_down,
    "song_layers_up": song_layers_up,
}
