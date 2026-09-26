# Steam achievements (app 5328810)

Six Steam achievements. Each one mirrors an achievement the game already tracks locally, so unlocking it in game
also unlocks it on Steam (`game/run/steam_bridge.gd`). Rebuild the icons and localization with:

```bash
python tools/store/build_achievements.py
```

## 1. Create them in Steamworks

Steamworks > your app > **Stats & Achievements > Achievements** > **New Achievement**. Create them **in this
order**: Steam names the localization tokens by creation order, and `achievements_loc.vdf` assumes this order.

| # | API name | Progress stat | Display name (English) | Description (English) | Set by | Hidden | Unlocked icon | Locked icon |
|---|---|---|---|---|---|---|---|---|
| 1 | `ACH_CROSSROADS` | none | Crossroads | Clear a row and a column with one placement. | Client | No | `ACH_CROSSROADS_unlocked.jpg` | `ACH_CROSSROADS_locked.jpg` |
| 2 | `ACH_BOSS_BUSTER` | none | Boss Buster | Defeat a boss. | Client | No | `ACH_BOSS_BUSTER_unlocked.jpg` | `ACH_BOSS_BUSTER_locked.jpg` |
| 3 | `ACH_LEGEND_FOUND` | none | Once Upon a Legend | Own a Legendary Joker. | Client | No | `ACH_LEGEND_FOUND_unlocked.jpg` | `ACH_LEGEND_FOUND_locked.jpg` |
| 4 | `ACH_ARCADE_REGULAR` | none | Arcade Regular | Score 25,000 points in one Endless game. | Client | No | `ACH_ARCADE_REGULAR_unlocked.jpg` | `ACH_ARCADE_REGULAR_locked.jpg` |
| 5 | `ACH_BLOCKMANIA` | none | BLOCKMANIA! | Beat the game: win round 12. | Client | No | `ACH_BLOCKMANIA_unlocked.jpg` | `ACH_BLOCKMANIA_locked.jpg` |
| 6 | `ACH_BROKE_THE_MACHINE` | none | Broke the Machine | Score a single placement past the machine's limit (1,000,000,000,000,000 points). | Client | **Yes** | `ACH_BROKE_THE_MACHINE_unlocked.jpg` | `ACH_BROKE_THE_MACHINE_locked.jpg` |

- **API name** is what the game sends. Never change it after the achievements are published.
- **Progress stat**: leave it empty. These are one-shot unlocks, so no stats are needed.
- **Set by: Client**, because the game unlocks them itself, without a game server.
- Icons are 256×256 JPG, which is Steam's recommended size. Unlocked icons are in color; locked icons are grayscale. The hidden
  achievement's locked icon is a "?" medal, so it gives nothing away.
- In game, the local ids behind them are `crossroads`, `boss_buster`, `legend_found`, `arcade_regular`,
  `champion` and `broke_machine` (`game/content/achievements.gd`).

## 2. Every other language

The names and descriptions come from the game's own translations (`game/content/achievements.gd` and `locale/*.po`),
so Steam and the game say the same thing. `texts.md` lists them per Steam language; `achievements_loc.vdf` holds them
all: English, Spanish (also as `latam`), French, Italian, German, Dutch, Polish, Brazilian Portuguese (also as
`portuguese`), Japanese, Simplified and Traditional Chinese. Enter them in either of two ways:

- **By hand:** on the Achievements page, switch the language dropdown to each language and fill in each
  achievement's name and description from `texts.md`.
- **By file:** in the **Achievement Localization** section, download Steam's current localization file first. If its token names
  match `achievements_loc.vdf` (`NEW_ACHIEVEMENT_1_0_NAME` ... `NEW_ACHIEVEMENT_1_5_DESC`, in the order above), upload
  `achievements_loc.vdf`. If Steam used different token names, copy the texts from this file into Steam's file and upload that.

## 3. Publish

1. Click **Publish** under Steamworks > Publish (achievements are not live until published).
2. Store page > **Supported features**: tick **Steam Achievements**. Do this only once a build that includes
   GodotSteam (step 4) is uploaded to Steam.

## 4. Game side: GodotSteam

The game talks to Steam through the **GodotSteam GDExtension** (MIT license, https://godotsteam.com), a Godot
binding of the Steamworks SDK. `BMSteam` works with or without it: when it is missing, or Steam is not running,
every call does nothing.

1. Install the GodotSteam GDExtension build that matches Godot 4.7 (Asset Library "GodotSteam GDExtension 4.x",
   or the release zip from GitHub) into `addons/godotsteam/`. It ships the Steamworks redistributables
   (`steam_api64.dll`, `libsteam_api.so`, `libsteam_api.dylib`).
2. Record it in `THIRD_PARTY.md` (MIT, and the Steamworks SDK redistributable terms).
3. For local testing, run the game with the Steam client open. Steam must know the app id: GodotSteam reads
   `steam_appid.txt` (containing `5328810`) next to the executable or the project. Never ship that file in the Steam build.
4. On start, the game initializes Steam (`steamInitEx(5328810)`), sets any of the six that are already unlocked
   locally (players who earned them offline or before Steam), and after that sets each one the moment it unlocks.
   It calls `storeStats()` after every change and pumps `run_callbacks()` every frame.

Safety: the bridge never reports from a sandboxed profile (the E2E suite, `tools/shoot.py` with `BM_SANDBOX=1`) or
from a `--script` tool, so tests cannot unlock achievements on a real Steam account. While testing, use
Steamworks' **Reset** button or `Steam.clearAchievement("ACH_...")` to lock them again.

## Files

| File | Use |
|---|---|
| `ACH_*_unlocked.jpg` / `ACH_*_locked.jpg` | the icons, 256×256 JPG |
| `achievements_loc.vdf` | names and descriptions in every Steam language the game ships (Steam localization format) |
| `texts.md` | the same texts as tables, one per language, for entering them by hand |
| `achievements.json` | the same data, for tools |
| `contact_sheet.png` | preview: unlocked row over locked row |
