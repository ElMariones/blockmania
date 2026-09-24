"""Compose and render the BLOCKMANIA soundtrack into assets/audio/music/*.ogg.

Seven original pieces in a calm lofi / ambient-piano style: sparse felt piano, warm pads, soft
electric piano, music-box bells, lofi drums, vinyl and rain. Every note is written below
(chord progressions, hand-written melodies, arrangement per section); the renderer turns that
data into audio with the instruments in dsp.py. Nothing is sampled or borrowed.

Run:  python tools/audio/gen_music.py [song_id ...]
Needs numpy, scipy, soundfile and (for OGG) ffmpeg with libvorbis on PATH.
"""
import os
import re
import subprocess
import sys
import numpy as np
import soundfile as sf

import dsp
from dsp import SR, Track, samples

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "music")

NOTE_PC = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
QUALITY = {
    "": [0, 4, 7], "maj7": [0, 4, 7, 11], "maj9": [0, 4, 7, 11, 14], "add9": [0, 4, 7, 14],
    "6": [0, 4, 7, 9], "m": [0, 3, 7], "m7": [0, 3, 7, 10], "m9": [0, 3, 7, 10, 14],
    "m6": [0, 3, 7, 9], "madd9": [0, 3, 7, 14], "7": [0, 4, 7, 10], "9": [0, 4, 7, 10, 14],
    "13": [0, 4, 7, 10, 14, 21], "sus4": [0, 5, 7], "7sus4": [0, 5, 7, 10], "maj7#11": [0, 4, 7, 11, 18],
}
SCALES = {
    "major": [0, 2, 4, 5, 7, 9, 11], "minor": [0, 2, 3, 5, 7, 8, 10],
    "dorian": [0, 2, 3, 5, 7, 9, 10], "lydian": [0, 2, 4, 6, 7, 9, 11],
}


# --- Music data parsing ----------------------------------------------------------------------

def parse_chord(name: str) -> dict:
    """'Gmaj7/B' -> {'root': pc, 'tones': [intervals], 'bass': pc}."""
    m = re.fullmatch(r"([A-G])([b#]?)([^/]*)(?:/([A-G][b#]?))?", name)
    if not m:
        raise ValueError(name)
    root = (NOTE_PC[m.group(1)] + {"b": -1, "#": 1, "": 0}[m.group(2)]) % 12
    q = m.group(3)
    if q not in QUALITY:
        raise ValueError(f"quality {q!r} in {name}")
    bass = root
    if m.group(4):
        b = m.group(4)
        bass = (NOTE_PC[b[0]] + (1 if b[1:] == "#" else -1 if b[1:] == "b" else 0)) % 12
    return {"name": name, "root": root, "tones": QUALITY[q], "bass": bass}


def parse_bars(prog: str, beats: int) -> list:
    """'Dmaj9 | Asus4 A' -> per bar list of (start_beat, length, chord)."""
    bars = []
    for bar in prog.split("|"):
        names = bar.split()
        ln = beats / len(names)
        bars.append([(i * ln, ln, parse_chord(n)) for i, n in enumerate(names)])
    return bars


def parse_melody(text: str, song: dict) -> list:
    """'3:1.5 2:0.5 5,:1 #1\':2 r:1' -> [(beat, midi or None, dur)]. Degrees follow the song scale;
    ' raises and , lowers an octave; b/# alter by a semitone."""
    scale = SCALES[song["scale"]]
    out = []
    beat = 0.0
    for tok in text.split():
        deg, dur = tok.split(":")
        dur = float(dur)
        if deg == "r":
            out.append((beat, None, dur))
        else:
            m = re.fullmatch(r"([b#]?)([1-7])([',]*)", deg)
            if not m:
                raise ValueError(tok)
            acc = {"b": -1, "#": 1, "": 0}[m.group(1)]
            d = int(m.group(2)) - 1
            octv = m.group(3).count("'") - m.group(3).count(",")
            out.append((beat, song["mel_base"] + scale[d] + acc + 12 * octv, dur))
        beat += dur
    return out


def voice(chord: dict, prev: list, lo: int = 55, hi: int = 74, size: int = 4) -> list:
    """Close-ish voicing of the chord tones (root omitted when there are enough colors) that
    moves as little as possible from the previous voicing."""
    tones = [(chord["root"] + i) % 12 for i in chord["tones"]]
    if len(tones) > size:
        tones = [t for t in tones if t != chord["root"]][:size]
    best, best_cost = None, 1e9
    for base in range(lo, lo + 12):
        v = []
        for pc in tones:
            n = base + ((pc - base) % 12)
            v.append(n)
        v = sorted(v)
        if v[-1] > hi:
            continue
        cost = sum(min(abs(a - b) for b in prev) for a in v) if prev else abs(np.mean(v) - (lo + hi) / 2)
        if cost < best_cost:
            best, best_cost = v, cost
    return best or sorted(lo + ((pc - lo) % 12) for pc in tones)


def bass_note(chord: dict, lo: int = 36) -> int:
    return lo + ((chord["bass"] - lo) % 12)


# --- Songs -----------------------------------------------------------------------------------
# Each section: bars from a progression (repeated), and the layers playing in it.
#   piano: sparse | arp8 | waltz | block | ostinato     ep: comp | pad | offbeat
#   bass: root | lofi | walk | long                     drums: lofi | light | brush | heart | toy
#   bells: counter                                      melody: key into song["melodies"]
#   lead: instruments playing the melody ("piano", "bells", "ep", combinations with +)
#   lp: master low-pass cutoff at section start -> end (Hz), for filtered intros/outros

SONGS = {}

SONGS["blockhead_lullaby"] = {
    "title": "Blockhead Lullaby", "context": "title", "bpm": 64, "beats": 4, "scale": "major",
    "key": 62, "mel_base": 74, "seed": 101, "lofi": 0.6, "rain": 0.0, "vinyl": 0.8, "swing": 0.0,
    "progs": {
        "A": "Dmaj9 | Gmaj7/B | Em9 | Asus4 A",
        "B": "Bm9 | Gmaj7 | Dmaj7/F# | Em7 A7",
        "END": "Dmaj9 | Gmaj7/B | Dmaj9 | Dmaj9",
    },
    "melodies": {
        "m1": "3:1.5 2:0.5 3:1 5:1  6:2 5:1 3:1  2:1.5 3:0.5 2:1 7,:1  1:2 7,:1 r:1 "
              "3:1 5:1 6:1 5:0.5 3:0.5  5:1.5 3:0.5 2:2  1:1 2:1 3:1 5:1  4:1.5 3:0.5 2:2",
        "m2": "6,:1.5 1:0.5 2:1 3:1  5:2 3:1 2:1  3:1.5 2:0.5 1:2  2:1 1:1 7,:1 5,:1 "
              "1':1 7:0.5 6:0.5 5:1 3:1  2:1 3:1 5:2  6:1.5 5:0.5 3:2  2:2 7,:1.5 r:0.5",
        "end": "5:2 3:2  2:4  1:4  r:4",
    },
    "sections": [
        {"prog": "A", "reps": 1, "piano": "sparse", "pad": 0.5, "lp": (1800, 6000)},
        {"prog": "A", "reps": 2, "piano": "sparse", "pad": 0.35, "melody": "m1", "lead": "piano"},
        {"prog": "B", "reps": 2, "piano": "arp8", "pad": 0.4, "bells": "counter", "melody": "m2", "lead": "piano"},
        {"prog": "A", "reps": 2, "piano": "arp8", "pad": 0.45, "melody": "m1", "lead": "bells+piano", "mel_oct": 0},
        {"prog": "END", "reps": 1, "piano": "sparse", "pad": 0.5, "melody": "end", "lead": "piano", "lp": (9000, 2500)},
    ],
}

SONGS["eight_by_eight"] = {
    "title": "Eight by Eight", "context": "round", "bpm": 76, "beats": 4, "scale": "major",
    "key": 60, "mel_base": 72, "seed": 202, "lofi": 1.0, "rain": 0.0, "vinyl": 1.0, "swing": 0.1,
    "progs": {"A": "Fmaj7 | Em7 | Dm9 | Cmaj7", "B": "Fmaj7 | G6 | Em7 | Am9"},
    "melodies": {
        "m1": "3:1 5:0.5 6:1.5 5:1  5:1.5 3:0.5 2:2  1:1 2:1 3:1 6,:1  5,:2 r:2 "
              "3:1 5:0.5 6:0.5 1':1 7:1  5:2 3:1 5:1  6:1.5 5:0.5 3:1 2:1  3:3 r:1",
        "m2": "1':1.5 7:0.5 6:1 5:1  6:1 5:1 3:1 2:1  3:1.5 2:0.5 7,:2  1:2 6,:2 "
              "6:1 1':1 3':1 2':1  1':1.5 7:0.5 5:2  5:1 6:0.5 5:0.5 3:1 2:1  3:4",
    },
    "sections": [
        {"prog": "A", "reps": 1, "ep": "comp", "lp": (900, 3000)},
        {"prog": "A", "reps": 2, "ep": "comp", "bass": "lofi", "drums": "lofi"},
        {"prog": "A", "reps": 2, "ep": "comp", "bass": "lofi", "drums": "lofi", "melody": "m1", "lead": "piano"},
        {"prog": "B", "reps": 2, "ep": "comp", "bass": "lofi", "drums": "lofi", "melody": "m2", "lead": "piano", "bells": "counter"},
        {"prog": "A", "reps": 2, "ep": "comp", "piano": "arp8", "bass": "lofi", "drums": "lofi", "melody": "m1", "lead": "bells+piano"},
        {"prog": "A", "reps": 1, "ep": "comp", "pad": 0.3, "lp": (6000, 1200)},
    ],
}

SONGS["rainy_arcade"] = {
    "title": "Rainy Arcade", "context": "round", "bpm": 70, "beats": 4, "scale": "dorian",
    "key": 64, "mel_base": 76, "seed": 303, "lofi": 1.0, "rain": 1.0, "vinyl": 0.6, "swing": 0.12,
    "progs": {"A": "Em9 | A13 | Cmaj7 | Bm7", "B": "Cmaj7 | D6 | Bm7 | Em9"},
    "melodies": {
        "m1": "5:1.5 4:0.5 3:1 2:1  1:2 7,:1 6,:1  5,:2 1:2  2:1.5 1:0.5 7,:2 "
              "3:1 5:1 7:1 5:1  6:1.5 5:0.5 4:2  3:1 2:1 1:1 5,:1  2:3 r:1",
        "m2": "3:1.5 5:0.5 7:2  5:1.5 4:0.5 2:2  1:1 2:1 4:2  5:3 r:1 "
              "5:1 7:1 1':1 7:1  4:2 5:1 4:1  2:1.5 4:0.5 2:1 1:1  1:4",
    },
    "sections": [
        {"prog": "A", "reps": 1, "ep": "pad", "pad": 0.35, "lp": (1200, 4000)},
        {"prog": "A", "reps": 2, "ep": "comp", "bass": "root", "drums": "brush", "pad": 0.2},
        {"prog": "A", "reps": 2, "ep": "comp", "bass": "root", "drums": "brush", "melody": "m1", "lead": "piano"},
        {"prog": "B", "reps": 2, "ep": "comp", "bass": "root", "drums": "brush", "melody": "m2", "lead": "piano", "pad": 0.3},
        {"prog": "A", "reps": 2, "piano": "sparse", "bass": "long", "pad": 0.35, "bells": "counter"},
        {"prog": "A", "reps": 2, "ep": "comp", "bass": "root", "drums": "brush", "melody": "m1", "lead": "ep+piano"},
        {"prog": "A", "reps": 1, "ep": "pad", "pad": 0.35, "lp": (5000, 1000)},
    ],
}

SONGS["clear_skies"] = {
    "title": "Clear Skies", "context": "round", "bpm": 84, "beats": 3, "scale": "major",
    "key": 55, "mel_base": 79, "seed": 404, "lofi": 0.5, "rain": 0.0, "vinyl": 0.5, "swing": 0.0,
    "progs": {
        "A": "Gadd9 | Gadd9 | Cmaj7 | Cmaj7 | Em7 | Em7 | Dsus4 | D",
        "B": "Am7 | Bm7 | Cmaj7 | D6 | Em7 | Cmaj7 | Am7 | Dsus4 D",
    },
    "melodies": {
        "m1": "5,:2 1:1  2:2 3:1  3:3  2:1 1:1 5,:1  1:2 7,:1  5,:3  1:2 5,:1  7,:3",
        "m1b": "5,:1 1:1 2:1  3:2 5:1  3:2 2:1  1:3  7,:1 1:1 2:1  3:3  2:3  7,:2 r:1",
        "m2": "2:2 1:1  7,:2 5,:1  3:2 5:1  6:3  5:2 3:1  2:2 1:1  1:1 2:1 3:1  2:1.5 7,:1.5",
        "m2b": "5:2 3:1  2:2 7,:1  3:1 5:1 1':1  7:3  6:2 5:1  3:3  2:1 1:1 7,:1  2:3",
    },
    "sections": [
        {"prog": "A", "reps": 1, "piano": "waltz", "lp": (2500, 9000)},
        {"prog": "A", "reps": 1, "piano": "waltz", "melody": "m1", "lead": "bells"},
        {"prog": "A", "reps": 1, "piano": "waltz", "pad": 0.25, "melody": "m1b", "lead": "bells+piano"},
        {"prog": "B", "reps": 1, "piano": "waltz", "pad": 0.3, "melody": "m2", "lead": "piano"},
        {"prog": "B", "reps": 1, "piano": "waltz", "pad": 0.4, "melody": "m2b", "lead": "bells+piano"},
        {"prog": "A", "reps": 1, "piano": "waltz", "pad": 0.2},
        {"prog": "A", "reps": 1, "piano": "waltz", "melody": "m1", "lead": "bells", "lp": (9000, 2200)},
    ],
}

SONGS["night_shift"] = {
    "title": "Night Shift", "context": "round", "bpm": 80, "beats": 4, "scale": "lydian",
    "key": 53, "mel_base": 77, "seed": 505, "lofi": 1.0, "rain": 0.0, "vinyl": 1.0, "swing": 0.1,
    "progs": {"A": "Fmaj9 | G/F | Em7 | Am7", "B": "Dm9 | G13 | Em7 | Am9"},
    "melodies": {
        "m1": "5:1.5 3:0.5 2:1 1:1  2:1.5 4:0.5 6:2  7,:1 2:1 4:1 2:1  3:2 5:1 r:1 "
              "7:1 5:1 3:1 5:1  6:1.5 5:0.5 4:2  2:1 4:1 6:1 7:1  5:4",
        "m2": "6,:1 1:1 3:1 5:1  7:2 6:1 4:1  2:1.5 4:0.5 2:2  3:2 4:1 3:1 "
              "1':1 7:1 5:1 3:1  6:1 4:1 2:2  7,:1 2:1 4:2  3:4",
    },
    "sections": [
        {"prog": "A", "reps": 1, "ep": "comp", "lp": (800, 2500)},
        {"prog": "A", "reps": 2, "ep": "comp", "bass": "lofi", "drums": "lofi"},
        {"prog": "A", "reps": 2, "ep": "comp", "bass": "lofi", "drums": "lofi", "melody": "m1", "lead": "piano"},
        {"prog": "B", "reps": 2, "ep": "comp", "bass": "lofi", "drums": "lofi", "melody": "m2", "lead": "piano", "pad": 0.25},
        {"prog": "A", "reps": 2, "ep": "comp", "bass": "lofi", "drums": "lofi", "melody": "m1", "lead": "bells+piano"},
        {"prog": "A", "reps": 1, "ep": "comp", "pad": 0.3, "lp": (5000, 900)},
    ],
}

SONGS["the_toybox"] = {
    "title": "The Toybox", "context": "shop", "bpm": 92, "beats": 4, "scale": "major",
    "key": 60, "mel_base": 72, "seed": 606, "lofi": 0.8, "rain": 0.0, "vinyl": 0.8, "swing": 0.14,
    "progs": {"A": "Cmaj7 | Am7 | Dm7 | G7", "B": "Fmaj7 | Em7 A7 | Dm7 | G7sus4 G7"},
    "melodies": {
        "m1": "5:0.5 r:0.5 3:0.5 5:0.5 6:1 5:1  3:0.5 r:0.5 1:0.5 3:0.5 2:1 1:1  "
              "4:0.5 r:0.5 2:0.5 4:0.5 6:1 5:1  4:1 2:1 7,:2 "
              "5:0.5 r:0.5 3:0.5 5:0.5 1':1 7:1  6:1 5:0.5 3:0.5 1:2  "
              "2:0.5 3:0.5 4:0.5 6:0.5 1':1 6:1  5:2 r:2",
        "m2": "3:1 6:1 1':1 6:1  5:1 3:1 3:1 #1:1  2:1.5 4:0.5 6:2  5:1 4:1 2:1 7,:1 "
              "1':0.5 7:0.5 6:0.5 5:0.5 6:1 1':1  7:1 5:1 3:1 #1:1  2:1 4:1 6:1 1':1  2':2 7:2",
    },
    "sections": [
        {"prog": "A", "reps": 1, "ep": "offbeat", "bass": "walk", "drums": "toy", "lp": (1500, 8000)},
        {"prog": "A", "reps": 2, "ep": "offbeat", "bass": "walk", "drums": "toy", "melody": "m1", "lead": "bells"},
        {"prog": "B", "reps": 2, "ep": "offbeat", "bass": "walk", "drums": "toy", "melody": "m2", "lead": "piano"},
        {"prog": "A", "reps": 2, "ep": "offbeat", "piano": "block", "bass": "walk", "drums": "toy", "melody": "m1", "lead": "bells+piano"},
        {"prog": "B", "reps": 2, "ep": "offbeat", "bass": "walk", "drums": "lofi", "melody": "m2", "lead": "bells+ep"},
        {"prog": "A", "reps": 1, "ep": "offbeat", "bass": "walk", "lp": (8000, 1500)},
    ],
}

SONGS["last_call"] = {
    "title": "Last Call", "context": "boss", "bpm": 68, "beats": 4, "scale": "minor",
    "key": 62, "mel_base": 74, "seed": 707, "lofi": 0.8, "rain": 0.35, "vinyl": 0.7, "swing": 0.0,
    "progs": {"A": "Dmadd9 | Bbmaj7 | Gm6 | A7sus4 A7", "B": "Fmaj7 | C/E | Dm7 | Bbmaj7 A7"},
    "melodies": {
        "m1": "5:2 4:1 3:1  3:1.5 2:0.5 1:2  4:1.5 3:0.5 2:2  1:2 #7,:2 "
              "1:1 3:1 5:1 1':1  7:1.5 6:0.5 5:2  6:1 5:1 4:1 2:1  1:2 #7,:1 5,:1",
        "m2": "3:2 5:1 7:1  1':1.5 7:0.5 5:2  4:1 3:1 1:2  1:2 #7,:2 "
              "5:1 6:1 7:2  7:1 5:1 7:2  5:1.5 4:0.5 3:1 1:1  3:2 2:1 #7,:1",
    },
    "sections": [
        {"prog": "A", "reps": 1, "piano": "ostinato", "pad": 0.5, "lp": (700, 2500)},
        {"prog": "A", "reps": 2, "piano": "ostinato", "pad": 0.45, "drums": "heart", "bass": "long"},
        {"prog": "A", "reps": 2, "piano": "ostinato", "pad": 0.4, "drums": "heart", "bass": "long", "melody": "m1", "lead": "piano"},
        {"prog": "B", "reps": 2, "piano": "ostinato", "pad": 0.45, "drums": "heart", "bass": "long", "melody": "m2", "lead": "piano", "bells": "counter"},
        {"prog": "A", "reps": 2, "piano": "sparse", "pad": 0.55, "bass": "long", "melody": "m1", "lead": "bells"},
        {"prog": "A", "reps": 1, "piano": "ostinato", "pad": 0.5, "lp": (4000, 700)},
    ],
}


# --- New tracks (2026-09-24): an alternate title waltz, a second shop tune, a Mk II boss theme,
# a harder late-round track, an Overtime rush and a bright arcade tune. Same instruments; the
# faster pieces add a 16th-note piano arpeggio and the "drive" / "march" drum patterns.

SONGS["paper_lanterns"] = {
    "snap": True,
    "title": "Paper Lanterns", "context": "title", "bpm": 72, "beats": 3, "scale": "lydian",
    "key": 53, "mel_base": 77, "seed": 808, "lofi": 0.5, "rain": 0.0, "vinyl": 0.6, "swing": 0.0,
    "progs": {"A": "Fmaj7 | G/F | Em7 | Am7 | Dm9 | G13 | Cmaj7 | Cmaj7"},
    "melodies": {
        "m1": "5:2 6:1  7:3  6:1 5:1 3:1  5:3  4:2 3:1  2:2 1:1  3:3  r:3",
        "m2": "1':2 7:1  6:3  5:1 6:1 7:1  1':3  2':2 1':1  7:2 5:1  6:3  5:3",
    },
    "sections": [
        {"prog": "A", "reps": 1, "piano": "waltz", "pad": 0.3, "lp": (2000, 8000)},
        {"prog": "A", "reps": 1, "piano": "waltz", "melody": "m1", "lead": "bells"},
        {"prog": "A", "reps": 1, "piano": "waltz", "pad": 0.3, "melody": "m2", "lead": "bells+piano"},
        {"prog": "A", "reps": 1, "piano": "waltz", "pad": 0.35, "melody": "m1", "lead": "piano", "bells": "counter"},
        {"prog": "A", "reps": 1, "piano": "waltz", "pad": 0.4, "lp": (8000, 2000)},
    ],
}

SONGS["pocket_change"] = {
    "snap": True,
    "title": "Pocket Change", "context": "shop", "bpm": 104, "beats": 4, "scale": "major",
    "key": 55, "mel_base": 79, "seed": 909, "lofi": 0.7, "rain": 0.0, "vinyl": 0.7, "swing": 0.16,
    "progs": {"A": "Gmaj7 | Em7 | Am7 | D7", "B": "Cmaj7 | Bm7 E7 | Am7 | D7sus4 D7"},
    "melodies": {
        "m1": "5:0.5 6:0.5 5:0.5 3:0.5 2:1 1:1  3:1 5:1 6:2  6:0.5 5:0.5 4:0.5 3:0.5 2:1 4:1  3:2 r:2  "
              "5:0.5 6:0.5 5:0.5 3:0.5 2:1 1:1  3:1 5:1 1':2  7:1 6:1 5:1 2:1  1:2 r:2",
        "m2": "3:1 4:1 5:2  6:1 5:1 3:2  4:1 5:1 6:1 1':1  7:2 5:2  "
              "3:1 4:1 5:1 6:1  7:1.5 6:0.5 5:2  4:1 6:1 1':1 7:1  1':3 r:1",
    },
    "sections": [
        {"prog": "A", "reps": 1, "ep": "offbeat", "bass": "walk", "drums": "toy", "lp": (1500, 8000)},
        {"prog": "A", "reps": 2, "ep": "offbeat", "bass": "walk", "drums": "toy", "melody": "m1", "lead": "bells+piano"},
        {"prog": "B", "reps": 2, "ep": "offbeat", "bass": "walk", "drums": "lofi", "melody": "m2", "lead": "piano"},
        {"prog": "A", "reps": 2, "ep": "offbeat", "piano": "block", "bass": "walk", "drums": "toy", "melody": "m1", "lead": "bells"},
        {"prog": "B", "reps": 2, "ep": "offbeat", "bass": "walk", "drums": "lofi", "melody": "m2", "lead": "bells+ep", "bells": "counter"},
        {"prog": "A", "reps": 1, "ep": "offbeat", "bass": "walk", "lp": (8000, 1500)},
    ],
}

SONGS["iron_curtain"] = {
    "snap": True,
    "title": "Iron Curtain", "context": "boss", "bpm": 88, "beats": 4, "scale": "minor",
    "key": 64, "mel_base": 76, "seed": 1010, "lofi": 0.6, "rain": 0.2, "vinyl": 0.5, "swing": 0.0,
    "progs": {"A": "Em | Cmaj7 | Am7 | B7sus4 B7", "B": "Cmaj7 | D6 | Bm7 | Em"},
    "melodies": {
        "m1": "1:1 2:1 3:2  5:1.5 4:0.5 3:2  6:1 5:1 4:1 3:1  2:3 #7,:1  "
              "1:1 3:1 5:1 1':1  7:1.5 6:0.5 5:2  4:1 3:1 2:1 4:1  3:2 2:1 #7,:1",
        "m2": "5:2 6:1 5:1  4:2 6:1 4:1  3:1 4:1 5:1 3:1  1:3 r:1  "
              "5:1 7:1 1':2  2':1.5 1':0.5 7:2  6:1 5:1 4:1 6:1  5:4",
    },
    "sections": [
        {"prog": "A", "reps": 1, "piano": "ostinato", "pad": 0.45, "drums": "heart", "lp": (700, 3000)},
        {"prog": "A", "reps": 2, "piano": "ostinato", "pad": 0.35, "drums": "march", "bass": "lofi"},
        {"prog": "A", "reps": 2, "piano": "ostinato", "pad": 0.35, "drums": "march", "bass": "lofi", "melody": "m1", "lead": "piano"},
        {"prog": "B", "reps": 2, "piano": "arp16", "pad": 0.4, "drums": "drive", "bass": "lofi", "melody": "m2", "lead": "bells+piano"},
        {"prog": "A", "reps": 2, "piano": "ostinato", "pad": 0.45, "drums": "march", "bass": "long", "melody": "m1", "lead": "bells"},
        {"prog": "A", "reps": 1, "piano": "ostinato", "pad": 0.5, "lp": (4000, 600)},
    ],
}

SONGS["cascade"] = {
    "snap": True,
    "title": "Cascade", "context": "round_hard", "bpm": 96, "beats": 4, "scale": "dorian",
    "key": 62, "mel_base": 74, "seed": 1111, "lofi": 0.8, "rain": 0.0, "vinyl": 0.8, "swing": 0.08,
    "progs": {"A": "Dm9 | G13 | Dm9 | G13", "B": "Bbmaj7 | C6 | Am7 | Dm9"},
    "melodies": {
        "m1": "5:0.5 4:0.5 3:0.5 1:0.5 2:2  3:1 5:1 7:2  6:0.5 5:0.5 4:0.5 3:0.5 2:2  1:3 r:1  "
              "5:0.5 6:0.5 7:0.5 1':0.5 7:2  6:1 5:1 4:2  3:1 4:1 5:1 6:1  5:4",
        "m2": "3:1 5:1 7:1 1':1  6:2 5:2  4:1 6:1 1':1 2':1  1':3 r:1  "
              "7:1 6:1 5:1 4:1  3:2 5:2  4:1 3:1 2:1 7,:1  1:4",
    },
    "sections": [
        {"prog": "A", "reps": 1, "ep": "comp", "piano": "arp16", "lp": (900, 5000)},
        {"prog": "A", "reps": 2, "ep": "comp", "piano": "arp16", "bass": "lofi", "drums": "lofi"},
        {"prog": "A", "reps": 2, "ep": "comp", "bass": "lofi", "drums": "drive", "melody": "m1", "lead": "piano"},
        {"prog": "B", "reps": 2, "ep": "comp", "piano": "arp8", "bass": "lofi", "drums": "drive", "melody": "m2", "lead": "bells+piano", "pad": 0.25},
        {"prog": "A", "reps": 2, "ep": "comp", "piano": "arp16", "bass": "lofi", "drums": "lofi", "melody": "m1", "lead": "bells+ep"},
        {"prog": "A", "reps": 1, "ep": "comp", "pad": 0.3, "lp": (6000, 1000)},
    ],
}

SONGS["overtime_rush"] = {
    "snap": True,
    "title": "Overtime Rush", "context": "overtime", "bpm": 116, "beats": 4, "scale": "minor",
    "key": 57, "mel_base": 81, "seed": 1212, "lofi": 0.5, "rain": 0.0, "vinyl": 0.4, "swing": 0.0,
    "progs": {"A": "Am9 | Fmaj7 | Cmaj7 | G6", "B": "Dm9 | Em7 | Fmaj7 | E7sus4 E7"},
    "melodies": {
        "m1": "1:1 3:1 5:1.5 4:0.5  3:2 2:1 1:1  5:1 6:1 7:1 1':1  7:2 5:2  "
              "4:1 5:1 6:1 4:1  3:1.5 2:0.5 1:2  2:1 3:1 4:1 6:1  5,:2 #7,:2",
        "m2": "5:1 6:1 7:2  1':1 7:1 5:2  6:1 5:1 4:1 3:1  2:2 5,:2  "
              "3:1 4:1 5:1 6:1  7:1.5 1':0.5 2':2  1':1 7:1 6:1 5:1  5:2 #7:2",
    },
    "sections": [
        {"prog": "A", "reps": 1, "piano": "arp16", "drums": "drive", "lp": (1200, 9000)},
        {"prog": "A", "reps": 2, "piano": "arp16", "ep": "comp", "bass": "lofi", "drums": "drive", "melody": "m1", "lead": "piano"},
        {"prog": "B", "reps": 2, "piano": "arp16", "ep": "comp", "bass": "lofi", "drums": "drive", "melody": "m2", "lead": "bells+piano", "bells": "counter"},
        {"prog": "A", "reps": 2, "piano": "ostinato", "pad": 0.3, "bass": "long", "drums": "march"},
        {"prog": "A", "reps": 2, "piano": "arp16", "ep": "comp", "bass": "lofi", "drums": "drive", "melody": "m1", "lead": "bells+piano"},
        {"prog": "B", "reps": 2, "piano": "arp16", "ep": "comp", "bass": "lofi", "drums": "drive", "melody": "m2", "lead": "piano", "pad": 0.3},
        {"prog": "A", "reps": 1, "piano": "arp16", "pad": 0.3, "lp": (9000, 1200)},
    ],
}

SONGS["high_score"] = {
    "snap": True,
    "title": "High Score", "context": "round", "bpm": 100, "beats": 4, "scale": "major",
    "key": 60, "mel_base": 72, "seed": 1313, "lofi": 0.8, "rain": 0.0, "vinyl": 0.8, "swing": 0.12,
    "progs": {"A": "Cmaj7 | Fmaj7 | Am7 | G6", "B": "Dm7 | Em7 | Fmaj7 | Gsus4 G"},
    "melodies": {
        "m1": "3:1 5:1 1':2  7:1 6:1 5:2  3:1 5:1 6:1 5:1  2:3 r:1  "
              "3:1 5:1 1':1 2':1  3':2 2':1 1':1  6:1 5:1 3:1 2:1  1:3 r:1",
        "m2": "6:1.5 5:0.5 4:2  5:1.5 4:0.5 3:2  4:1 5:1 6:1 1':1  5:4  "
              "6:1 1':1 2':1 1':1  7:2 5:2  4:1 3:1 2:1 5:1  5:4",
    },
    "sections": [
        {"prog": "A", "reps": 1, "ep": "comp", "lp": (1000, 4000)},
        {"prog": "A", "reps": 2, "ep": "comp", "piano": "arp8", "bass": "lofi", "drums": "lofi", "melody": "m1", "lead": "piano"},
        {"prog": "B", "reps": 2, "ep": "comp", "bass": "lofi", "drums": "lofi", "melody": "m2", "lead": "bells+piano"},
        {"prog": "A", "reps": 2, "ep": "comp", "piano": "arp8", "bass": "lofi", "drums": "drive", "melody": "m1", "lead": "bells+ep", "bells": "counter"},
        {"prog": "B", "reps": 2, "ep": "comp", "bass": "lofi", "drums": "lofi", "melody": "m2", "lead": "piano", "pad": 0.25},
        {"prog": "A", "reps": 1, "ep": "comp", "pad": 0.3, "lp": (6000, 1200)},
    ],
}


# --- Arrangement -> note events --------------------------------------------------------------

class Ev:
    __slots__ = ("t", "inst", "midi", "dur", "vel", "pan")

    def __init__(self, t, inst, midi, dur, vel, pan=0.0):
        self.t, self.inst, self.midi, self.dur, self.vel, self.pan = t, inst, midi, dur, vel, pan


def arrange(song: dict) -> tuple:
    r = dsp.rng(song["seed"])
    beat = 60.0 / song["bpm"]
    bpb = song["beats"]
    evs = []
    lp_points = []  # (time, cutoff)
    t_bar = 0.0
    prev_voicing = []
    warnings = []
    swing = song["swing"]

    def when(bar_t, b):
        """Beat position -> seconds, with swing on off-beat eighths and a little humanization."""
        frac = b % 1.0
        sw = swing * beat if abs(frac - 0.5) < 1e-6 else 0.0
        return bar_t + b * beat + sw + r.normal(0, 0.006)

    for sec in song["sections"]:
        bars = parse_bars(song["progs"][sec["prog"]], bpb) * sec.get("reps", 1)
        sec_start = t_bar
        mel = parse_melody(song["melodies"][sec["melody"]], song) if sec.get("melody") else []
        if mel:
            total = sum(d for _, _, d in mel)
            if abs(total - len(bars) * bpb) > 1e-6:
                raise ValueError(f"{song['title']} melody {sec['melody']}: {total} beats for {len(bars) * bpb}")
        for bi, bar in enumerate(bars):
            for (cb, cl, chord) in bar:
                v = voice(chord, prev_voicing)
                prev_voicing = v
                root = bass_note(chord)
                ct = t_bar + cb * beat
                # Piano accompaniment.
                pat = sec.get("piano")
                if pat == "sparse":
                    evs.append(Ev(when(t_bar, cb), "piano", root, cl * beat, 0.42, -0.2))
                    for pos, idx in ((0.5, 0), (1.5, 2), (2.5, 1), (3.25, 3)):
                        if pos < cl and r.random() > 0.25:
                            evs.append(Ev(when(t_bar, cb + pos), "piano", v[idx % len(v)], (cl - pos) * beat, r.uniform(0.28, 0.4), 0.15))
                elif pat == "arp8":
                    evs.append(Ev(when(t_bar, cb), "piano", root, cl * beat, 0.45, -0.25))
                    order = [0, 1, 2, 3, 2, 1, 2, 3]
                    for k in range(int(cl * 2)):
                        if k == 0:
                            continue
                        evs.append(Ev(when(t_bar, cb + k * 0.5), "piano", v[order[k % 8] % len(v)], (cl - k * 0.5) * beat,
                                      r.uniform(0.24, 0.36) * (1.1 if k % 2 == 0 else 0.9), 0.2))
                elif pat == "waltz":
                    evs.append(Ev(when(t_bar, cb), "piano", root, cl * beat, 0.45, -0.2))
                    seq = [(1.0, 0), (1.5, 1), (2.0, 2), (2.5, 1)] if cl >= 3 else [(0.5, 0), (1.0, 1)]
                    for pos, idx in seq:
                        if pos < cl:
                            evs.append(Ev(when(t_bar, cb + pos), "piano", v[idx % len(v)], (cl - pos) * beat, r.uniform(0.25, 0.35), 0.2))
                elif pat == "arp16":
                    # Driving 16th-note arpeggio over the voicing (energetic tracks).
                    evs.append(Ev(when(t_bar, cb), "piano", root, cl * beat, 0.42, -0.25))
                    order = [0, 1, 2, 3, 2, 1, 2, 3]
                    for k in range(int(cl * 4)):
                        if k == 0:
                            continue
                        n = v[order[k % 8] % len(v)] + (12 if k % 8 == 3 else 0)
                        evs.append(Ev(when(t_bar, cb + k * 0.25), "piano", n, 0.35 * beat,
                                      (0.28 if k % 4 == 0 else 0.2) + r.uniform(-0.02, 0.02), 0.2))
                elif pat == "block":
                    for k, n in enumerate(v):
                        evs.append(Ev(when(t_bar, cb) + k * 0.012, "piano", n, cl * beat * 0.9, 0.3, 0.1))
                elif pat == "ostinato":
                    third = 3 if 3 in chord["tones"] else 4
                    seq = [0, 7, third + 12, 7]
                    base = 50 + ((chord["root"] - 50) % 12)
                    for k in range(int(cl * 2)):
                        evs.append(Ev(when(t_bar, cb + k * 0.5), "piano", base + seq[k % 4], 0.5 * beat * 1.6,
                                      (0.36 if k % 4 == 0 else 0.26) + r.uniform(-0.03, 0.03), -0.1))
                    evs.append(Ev(when(t_bar, cb), "piano", base - 12, cl * beat, 0.4, -0.2))
                # Electric piano.
                ep = sec.get("ep")
                if ep == "comp":
                    hits = [(0.0, 1.4), (1.75, 0.6), (2.5, 1.4)] if cl >= 4 else [(0.0, cl * 0.8)]
                    for pos, d in hits:
                        if pos < cl and (pos == 0 or r.random() > 0.2):
                            for k, n in enumerate(v):
                                evs.append(Ev(when(t_bar, cb + pos) + k * 0.008, "ep", n, d * beat, 0.34 if pos == 0 else 0.27, 0.0))
                elif ep == "pad":
                    for n in v:
                        evs.append(Ev(when(t_bar, cb), "ep", n, cl * beat, 0.3, 0.0))
                elif ep == "offbeat":
                    for k in range(int(cl)):
                        for n in v:
                            evs.append(Ev(when(t_bar, cb + k + 0.5), "ep", n, 0.35 * beat, 0.26, 0.0))
                # Bass.
                bp = sec.get("bass")
                if bp == "root":
                    evs.append(Ev(when(t_bar, cb), "bass", root, min(cl, 2.0) * beat * 0.9, 0.7))
                    if cl >= 4:
                        evs.append(Ev(when(t_bar, cb + 2.5), "bass", root + (7 if r.random() > 0.5 else 12), 1.2 * beat, 0.55))
                elif bp == "lofi":
                    evs.append(Ev(when(t_bar, cb), "bass", root, 0.9 * beat, 0.75))
                    if cl >= 4:
                        evs.append(Ev(when(t_bar, cb + 1.5), "bass", root, 0.4 * beat, 0.5))
                        evs.append(Ev(when(t_bar, cb + 2.5), "bass", root + 7 if root + 7 < 50 else root - 5, 1.1 * beat, 0.65))
                elif bp == "walk":
                    steps = [0, chord["tones"][1], 9 if chord["tones"][1] == 4 else 10, 7]
                    for k in range(int(cl)):
                        evs.append(Ev(when(t_bar, cb + k), "bass", root + steps[k % 4], 0.8 * beat, 0.62 if k == 0 else 0.5))
                elif bp == "long":
                    evs.append(Ev(when(t_bar, cb), "bass", root, cl * beat * 0.95, 0.55))
                # Pad.
                if sec.get("pad"):
                    evs.append(Ev(ct, "pad", tuple([root + 12] + [n - 12 for n in v]), cl * beat, sec["pad"]))
                # Bells counter-line.
                if sec.get("bells") == "counter":
                    for pos in (0.0, 1.5, 3.0):
                        if pos < cl and r.random() > 0.3:
                            evs.append(Ev(when(t_bar, cb + pos), "bells", v[r.integers(0, len(v))] + 24, 1.5 * beat, 0.22, r.uniform(-0.6, 0.6)))
            # Drums (per bar).
            dp = sec.get("drums")
            if dp:
                evs.extend(drum_bar(dp, t_bar, beat, bpb, r, when, last=(bi == len(bars) - 1)))
            t_bar += bpb * beat
        # Melody.
        if mel:
            chords_at = []
            tb = sec_start
            for bar in bars:
                for (cb, cl, chord) in bar:
                    chords_at.append((tb + cb * beat, tb + (cb + cl) * beat, chord))
                tb += bpb * beat
            leads = sec.get("lead", "piano").split("+")
            oct_shift = 12 * sec.get("mel_oct", 0)
            for (b, n, d) in mel:
                if n is None:
                    continue
                t0 = sec_start + b * beat
                n += oct_shift
                strong = (b % bpb == 0) or (bpb == 4 and b % bpb == 2) or d >= 1.5
                ch = next((c for c in chords_at if c[0] - 1e-6 <= t0 < c[1]), chords_at[-1])[2]
                pcs = {(ch["root"] + i) % 12 for i in ch["tones"]}
                clash = min(min((n - p) % 12, (p - n) % 12) for p in pcs)
                if song.get("snap") and strong and clash == 1:
                    # Songs with "snap" resolve a semitone rub on a strong beat to the nearest
                    # chord tone (below first), keeping the written contour.
                    for delta in (-1, 1, -2, 2):
                        if (n + delta) % 12 in pcs:
                            n += delta
                            break
                    clash = 0
                if strong and clash == 1 and d >= 1.0:
                    warnings.append(f"{song['title']}: strong clash {n} over {ch['name']} at beat {b} of '{sec['melody']}'")
                vel = 0.55 if strong else 0.45
                for li, lead in enumerate(leads):
                    tt = t0 + r.normal(0, 0.004) + li * 0.004
                    if lead == "piano":
                        evs.append(Ev(tt, "lead_piano", n, d * beat * 1.1, vel, 0.05))
                    elif lead == "bells":
                        evs.append(Ev(tt, "bells", n + (12 if "piano" in leads or n < 76 else 0), max(1.2, d * beat), vel * 0.75, 0.1))
                    elif lead == "ep":
                        evs.append(Ev(tt, "lead_ep", n, d * beat, vel * 0.9, -0.05))
        # Filter automation stays continuous: an lp section ramps from wherever the previous
        # section ended (its own start value is used only for the opening section), and a
        # normal section opens back up to full range over its first bar.
        if "lp" in sec:
            if not lp_points:
                lp_points.append((sec_start, sec["lp"][0]))
            lp_points.append((t_bar, sec["lp"][1]))
        else:
            if not lp_points:
                lp_points.append((sec_start, 18000))
            lp_points.append((sec_start + bpb * beat, 18000))
            lp_points.append((t_bar, 18000))
    return evs, t_bar, lp_points, warnings


def drum_bar(kind, t_bar, beat, bpb, r, when, last=False):
    evs = []
    if kind == "lofi":
        for pos in (0.0, 1.75, 2.5):
            if pos == 0 or r.random() > 0.25:
                evs.append(Ev(when(t_bar, pos), "kick", 0, 0, 0.8 if pos == 0 else 0.6))
        for pos in (1.0, 3.0):
            evs.append(Ev(when(t_bar, pos), "snare", 0, 0, 0.55))
        for k in range(8):
            if last and k >= 6:
                continue
            evs.append(Ev(when(t_bar, k * 0.5), "hat", 0, 0, 0.35 if k % 2 == 0 else 0.22, 0.3))
        if last:
            evs.append(Ev(when(t_bar, 3.5), "ohat", 0, 0, 0.3, 0.3))
    elif kind == "brush":
        for pos in (0.0, 2.5):
            evs.append(Ev(when(t_bar, pos), "kick", 0, 0, 0.55))
        for pos in (1.0, 3.0):
            evs.append(Ev(when(t_bar, pos), "brush", 0, 0, 0.5))
        for k in range(8):
            evs.append(Ev(when(t_bar, k * 0.5), "shaker", 0, 0, 0.3 if k % 2 == 0 else 0.18, -0.3))
    elif kind == "heart":
        evs.append(Ev(when(t_bar, 0.0), "kick_low", 0, 0, 0.5))
        evs.append(Ev(when(t_bar, 0.45), "kick_low", 0, 0, 0.32))
    elif kind == "toy":
        for pos in (0.0, 2.0):
            evs.append(Ev(when(t_bar, pos), "kick", 0, 0, 0.6))
        for pos in (1.0, 3.0):
            evs.append(Ev(when(t_bar, pos), "rim", 0, 0, 0.5, 0.2))
        for k in range(8):
            evs.append(Ev(when(t_bar, k * 0.5), "shaker", 0, 0, 0.26 if k % 2 == 0 else 0.16, -0.25))
    elif kind == "drive":
        for pos in (0.0, 1.0, 2.0, 2.5, 3.0):
            evs.append(Ev(when(t_bar, pos), "kick", 0, 0, 0.75 if pos in (0.0, 2.0) else 0.5))
        for pos in (1.0, 3.0):
            evs.append(Ev(when(t_bar, pos), "snare", 0, 0, 0.6))
        for k in range(16):
            if last and k >= 14:
                continue
            evs.append(Ev(when(t_bar, k * 0.25), "hat", 0, 0, 0.3 if k % 4 == 0 else (0.22 if k % 2 == 0 else 0.14), 0.3))
        if last:
            evs.append(Ev(when(t_bar, 3.5), "ohat", 0, 0, 0.35, 0.3))
    elif kind == "march":
        for pos in (0.0, 1.5, 2.0):
            evs.append(Ev(when(t_bar, pos), "kick_low", 0, 0, 0.6 if pos == 0 else 0.42))
        evs.append(Ev(when(t_bar, 3.0), "snare", 0, 0, 0.5))
        for k in range(4):
            evs.append(Ev(when(t_bar, 3.0 + k * 0.25), "rim", 0, 0, 0.2 + 0.05 * k, 0.15))
        for k in range(8):
            evs.append(Ev(when(t_bar, k * 0.5), "shaker", 0, 0, 0.2 if k % 2 == 0 else 0.12, -0.25))
    return evs


# --- Rendering -------------------------------------------------------------------------------

class Renderer:
    def __init__(self, seed: int):
        self.cache = {}
        self.seed = seed

    def clip(self, e: Ev) -> np.ndarray:
        if e.inst in ("piano", "lead_piano"):
            key = ("p", int(e.midi), round(e.dur * 4) / 4, round(e.vel * 20) / 20, int(e.t * 7) % 3)
            if key not in self.cache:
                self.cache[key] = dsp.piano(key[1], max(0.25, key[2]), key[3], seed=key[1] * 131 + int(key[2] * 4) * 7 + key[4])
            return self.cache[key]
        if e.inst in ("ep", "lead_ep"):
            key = ("e", int(e.midi), round(e.dur * 4) / 4, round(e.vel * 20) / 20)
            if key not in self.cache:
                self.cache[key] = dsp.epiano(key[1], max(0.15, key[2]), key[3])
            return self.cache[key]
        if e.inst == "bass":
            key = ("b", int(e.midi), round(e.dur * 8) / 8, round(e.vel * 20) / 20)
            if key not in self.cache:
                self.cache[key] = dsp.bass(key[1], max(0.1, key[2]), key[3])
            return self.cache[key]
        if e.inst == "bells":
            key = ("l", int(e.midi), round(e.dur * 2) / 2, round(e.vel * 20) / 20)
            if key not in self.cache:
                self.cache[key] = dsp.bell(key[1], max(1.0, key[2] + 0.8), key[3])
            return self.cache[key]
        if e.inst == "pad":
            key = ("pad", e.midi, round(e.dur * 2) / 2)
            if key not in self.cache:
                self.cache[key] = dsp.pad(list(e.midi), key[2], 1300, seed=sum(e.midi), attack=min(1.6, key[2] * 0.4), release=1.6)
            return self.cache[key]
        drum = {"kick": lambda: dsp.kick(1.0), "kick_low": lambda: dsp.lowpass(dsp.kick(1.0, 0.8), 400, 2),
                "snare": lambda: dsp.snare(1.0, 3), "brush": lambda: dsp.snare(1.0, 4, brushed=True),
                "hat": lambda: dsp.hat(1.0, False, 5), "ohat": lambda: dsp.hat(1.0, True, 6),
                "rim": lambda: dsp.rim(1.0), "shaker": lambda: dsp.shaker(1.0, 7)}
        if e.inst in drum:
            key = ("d", e.inst)
            if key not in self.cache:
                self.cache[key] = drum[e.inst]()
            return self.cache[key]
        raise ValueError(e.inst)


STEM_GAIN = {"piano": 0.55, "lead_piano": 0.8, "ep": 0.34, "lead_ep": 0.4, "bass": 0.5, "bells": 0.42, "pad": 0.3,
             "kick": 0.5, "kick_low": 0.55, "snare": 0.26, "brush": 0.26, "hat": 0.12, "ohat": 0.1, "rim": 0.2, "shaker": 0.14}
STEMS = {"keys": ("piano", "lead_piano", "bells"), "ep": ("ep", "lead_ep"), "low": ("bass",), "pad": ("pad",),
         "drums": ("kick", "kick_low", "snare", "brush", "hat", "ohat", "rim", "shaker")}


def render(song_id: str) -> None:
    song = SONGS[song_id]
    evs, length, lp_points, warnings = arrange(song)
    for w in warnings:
        print("  WARN", w)
    tail = 5.0
    total = length + tail
    rd = Renderer(song["seed"])
    stems = {k: Track(total) for k in STEMS}
    for e in evs:
        stem = next(k for k, v in STEMS.items() if e.inst in v)
        c = rd.clip(e)
        g = STEM_GAIN[e.inst] * (e.vel if e.inst in ("kick", "kick_low", "snare", "brush", "hat", "ohat", "rim", "shaker", "pad") else 1.0)
        stems[stem].add(c, max(0.0, e.t), g, e.pan)
    lofi = song["lofi"]
    # Per-stem tone and space.
    keys = dsp.reverb(dsp.lowpass(stems["keys"].buf, 10000 - 2500 * lofi, 2), mix=0.5, t60=3.2, predelay=0.02, bright=5500, seed=1)
    ep = dsp.reverb(dsp.lowpass(stems["ep"].buf, 5000, 2), mix=0.35, t60=2.2, seed=2)
    low = dsp.lowpass(stems["low"].buf, 900, 2)
    padb = dsp.reverb(stems["pad"].buf, mix=0.4, t60=3.5, seed=3)
    drums = dsp.lowpass(dsp.highpass(stems["drums"].buf, 35, 2), 9000 - 2500 * lofi, 2)
    drums = dsp.reverb(drums, mix=0.12, t60=0.8, seed=4)
    mixb = keys + ep + low + padb + drums
    # Beds.
    if song["vinyl"] > 0:
        mixb += dsp.vinyl(total, song["vinyl"], seed=song["seed"]) * 0.9
    if song["rain"] > 0:
        mixb += dsp.rain(total, song["rain"], seed=song["seed"] + 1) * 0.8
    # Tape: gentle wobble, warmth and a soft top end.
    mixb = dsp.wow_flutter(mixb, wow=0.0012 * lofi + 0.0003, flutter=0.00025 * lofi, seed=song["seed"])
    mixb = dsp.highpass(mixb, 30, 2)
    mixb = dsp.peaking(mixb, 110, -2.0, 0.9)  # less low-mid mud
    mixb = dsp.peaking(mixb, 3000, 3.5, 0.6)  # presence for the melody
    mixb = dsp.saturate(mixb * 1.2, 1.1)
    # Section filter automation (filtered intros/outros).
    mixb = automate_lowpass(mixb, lp_points, total)
    # Loudness: target RMS about -19 dBFS, peaks limited to -1 dBFS.
    mixb *= dsp.db(-19.0 - dsp.rms_db(mixb[: samples(length)]))
    mixb = dsp.limiter(mixb, -1.0)
    # Fade in / out.
    fi = samples(1.0)
    mixb[:fi] *= np.linspace(0, 1, fi)[:, None]
    fo = samples(tail)
    mixb[-fo:] *= np.linspace(1, 0, fo)[:, None] ** 1.5
    os.makedirs(OUT, exist_ok=True)
    wav = os.path.join(OUT, song_id + ".wav")
    ogg = os.path.join(OUT, song_id + ".ogg")
    sf.write(wav, mixb.astype(np.float32), SR, subtype="PCM_16")
    try:
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", ogg], check=True)
        os.remove(wav)
    except (OSError, subprocess.CalledProcessError) as ex:
        # No ffmpeg: libsndfile's own Vorbis encoder (quality ~0.4, like -q:a 4).
        try:
            data = mixb.astype(np.float32)
            with sf.SoundFile(ogg, "w", SR, data.shape[1], format="OGG", subtype="VORBIS") as f:
                # libsndfile's Vorbis writer fails on very large single writes: stream in blocks.
                for i in range(0, len(data), 8192):
                    f.write(data[i:i + 8192])
            os.remove(wav)
            print("  (encoded with libsndfile; ffmpeg not found)")
        except Exception as ex2:  # noqa: BLE001
            print("  OGG encoding failed, keeping WAV:", ex, ex2)
    peak = 20 * np.log10(np.abs(mixb).max() + 1e-9)
    print(f"  {song['title']}: {total:.1f}s, {len(evs)} events, peak {peak:.1f} dBFS, rms {dsp.rms_db(mixb):.1f} dBFS")


def automate_lowpass(x: np.ndarray, points: list, total: float) -> np.ndarray:
    """Block-wise low-pass following linear-in-log cutoff ramps between (time, Hz) points."""
    from scipy import signal as sg
    times = np.array([p[0] for p in points] + [total])
    cuts = np.array([p[1] for p in points] + [points[-1][1]])
    block = samples(0.05)
    out = np.empty_like(x)
    zi = None
    for s in range(0, len(x), block):
        t = s / SR
        fc = float(np.exp(np.interp(t, times, np.log(cuts))))
        sos = dsp._sos("lowpass", min(fc, 19000), 2)
        if zi is None:
            zi = np.zeros((sos.shape[0], 2, 2))
        seg, zi = sg.sosfilt(sos, x[s:s + block], axis=0, zi=zi)
        out[s:s + block] = seg
    return out


def main() -> None:
    ids = sys.argv[1:] or list(SONGS)
    for sid in ids:
        print("rendering", sid)
        render(sid)


if __name__ == "__main__":
    main()
