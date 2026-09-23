# BLOCKMANIA audio manifest

**Status:** original, code-authored first pass (2026-09-23). All notes, timbres, noise, drums, and effects are synthesized by `tools/audio/`; no third-party recording, sample, melody, or game audio was used. The composition scripts and exported files are project-owned. The owner's reference to a lo-fi game composer describes mood only; these are independent compositions.

## Source and export

- `tools/audio/gen_music.py`: seven written arrangements, note events, mix automation, and Ogg Vorbis export. `tools/audio/dsp.py`: synthesis and processing functions. Run `python tools/audio/gen_music.py [song_id ...]` with NumPy, SciPy, SoundFile, and ffmpeg/libvorbis available.
- `tools/audio/gen_sfx.py`: 59 effects in 44.1 kHz, 16-bit PCM WAV. Run `python tools/audio/gen_sfx.py` with NumPy, SciPy, and SoundFile.
- All seven music exports are 44.1 kHz stereo Ogg Vorbis, quality 4. The editable master is the deterministic source code and its song data. Music is rendered to WAV before encoding, then the intermediate WAV is removed.
- Runtime mapping, playlists, rate limits and gain control: `game/audio/audio.gd`. Music and SFX use separate Godot buses routed to Master. There are no external audio licenses to track.

## Music

| ID | In-game title | Context | Length |
|---|---|---|---:|
| `blockhead_lullaby` | Blockhead Lullaby | Title | 2:05 |
| `eight_by_eight` | Eight by Eight | Round | 2:11 |
| `rainy_arcade` | Rainy Arcade | Round | 2:50 |
| `clear_skies` | Clear Skies | Round | 2:05 |
| `night_shift` | Night Shift | Round | 2:05 |
| `the_toybox` | The Toybox | Shop | 1:49 |
| `last_call` | Last Call | Boss | 2:26 |

Godot import has `loop=false`. Each arrangement has a five-second fading tail and playback inserts 2.5–6 seconds before the next title in the active playlist. There are no sample-accurate loop points.

## Effects

59 files live in `assets/audio/sfx/`. The stable runtime IDs and variants are listed in `BMAudio.SFX`: menu hover/click/toggle; selection and movement; three sizes of placement with three variants each; clear/combo levels; cell pop; glass and stamp; Joker Chips/Add Mult/X Mult; coin, buy, sell, reroll and Workshop; item/Refresh/deal/receipt; alert, round/boss stings, and win/loss jingles. Repeated cues have short rate limits and a 20-player pool.

## Review remaining

Listen on target speakers and headphones with music on and off, including repeated placement, clear cascades, and rapid menu navigation. Tune masking and volume after that review; metadata and headless runtime checks alone cannot establish the final mix.
