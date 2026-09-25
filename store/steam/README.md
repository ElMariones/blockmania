# Steam store page kit

Text and media for the BLOCKMANIA store page (app 5328810), in English, Spanish and Simplified Chinese.
Everything here is rebuilt from the game itself:

```bash
python tools/store/capture.py       # real-game captures on a sandboxed profile -> build/store/ (needs Godot)
python tools/store/build_store.py   # compose -> store/steam/images and store/steam/screenshots
```

## Where each file goes in Steamworks

| Steamworks field | File |
|---|---|
| Store page > Description > **About this game** (Acerca de este juego) | `description_english.txt`, `description_spanish.txt`, `description_schinese.txt` (Steam BBCode; pick the language in the dropdown on the right) |
| Store page > Description > **Short description** (Descripción breve) | `short_english.txt` (238 characters), `short_spanish.txt` (252), `short_schinese.txt` (107); Steam allows 300 |
| Store page > Description > **Custom images** (Cargar imágenes personalizadas) | every file in `images/` |
| Graphical assets > **Screenshots** (5 or more) | `screenshots/*.jpg`, 1920×1080, numbered in the suggested order |

## Capsules and page background (Graphical assets)

```bash
cd tools/trailer && npm install   # once: puppeteer-core, shared with the trailer
node tools/store/capsules.mjs     # -> store/steam/capsules/ (optional filter: header small main vertical background)
```

Code-authored key art: the block logo, the 8x8 board a beat before a gold T piece clears a row and a column,
Legendary Joker portraits, POPS, the swirl and a soft CRT, drawn by the trailer engine (`tools/store/capsules.html`
+ `capsules.js`). Steam allows only game art, the game name and an official subtitle on base capsules, so the only
localized element is the subtitle (the trailer's line). Upload each file in its Steamworks slot; the `_english`,
`_spanish`, `_schinese` suffix assigns the language automatically.

| Steamworks slot | Size | Files | Localized text |
|---|---|---|---|
| Header capsule | 920×430 | `capsule_header_<lang>.png` | THE BLOCK PUZZLE ROGUELIKE / EL ROGUELIKE DE PUZLE DE BLOQUES / 方块拼图 ROGUELIKE |
| Small capsule | 462×174 | `capsule_small_<lang>.png` | none: the logo fills the capsule, so the three files are identical |
| Main capsule | 1232×706 | `capsule_main_<lang>.png` | subtitle |
| Vertical capsule | 748×896 | `capsule_vertical_<lang>.png` | subtitle |
| Page background | 1438×810 | `page_background.png` | none (Steam tints it blue and fades the edges) |

The subtitle counts as the official subtitle only if you use it as one: keep it consistent with the trailer and the
store text, or remove it from `SUBTITLE` in `tools/store/capsules.js` if review objects.

## Uploading the description images

1. Upload all of `images/` in the custom images box. Files ending in `_english`, `_spanish` and `_schinese` are
   grouped by Steam, which matches the files to each language.
2. Paste each description into its language. The image tags already point at
   `{STEAM_APP_IMAGE}/extras/<file name>`, which is where Steam stores the custom images. If the preview shows a broken image,
   delete that tag, place the cursor there and use the editor's **Insert image** button on the same file.
3. The two clips (`clip_gameplay`, `clip_boss`) come as MP4 (H.264) and WEBM (VP9), 1280×720, 30 fps, under
   Steam's 12-second limit. Upload both formats. If Steam's editor writes its own tag for an inserted video, use that
   tag instead of the `[video ...]` tag in the text files.
4. Check the preview in each language before submitting for review.

| Image | Width | Words in it |
|---|---|---|
| `banner_<lang>.jpg` | 1600 | genre tags and tagline |
| `hdr_how/features/modes/options_<lang>.png` | 1600 | section title (transparent PNG for Steam's dark page) |
| `loop_<lang>.png` | 1600 | the four-step core loop |
| `jokers_<lang>.png`, `finishes_<lang>.png`, `badges_<lang>.png` | 1556 / 1550 / 1232 | titles, rarity legend and finish names |
| `shot_*.jpg` | 1600 | none: framed in-game screenshots (the game's UI is English) |
| `clip_*.mp4` / `.webm` | 1280 | none |

Every image is 1600 px wide or less. Steam's description column is 780 px, and only images wider than 1600 px open in the
enlarged viewer when clicked.

## Glossary (keep the game's localization consistent with the store)

| English | Español | 简体中文 |
|---|---|---|
| Chips × Mult | Fichas × Multi | 筹码 × 倍率 |
| Joker | comodín | 小丑牌 |
| Credits | Créditos | 代币 |
| bag / tray / placement | bolsa / bandeja / colocación | 方块袋 / 托盘 / 放置 |
| Toybox / Workshop | Juguetería / Taller | 玩具箱 / 工坊 |
| Refresh / Hold | Recarga / Reservar | 刷新 / 暂存 |
| boss / Mk II | jefe / Mk II | 首领 / Mk II |
| Kit / Heat | kit / Calor | 套组 / 热度 |
| Overtime / Endless / Daily run | Prórroga / Infinito / Partida diaria | 加时赛 / 无尽模式 / 每日挑战 |
| Kits: Standard, Compact, High Roller, Chunky, Tetromino | Estándar, Compacto, Gran Apostador, Robusto, Tetrominó | 标准、紧凑、豪赌客、厚重、四格 |
| The Avalanche, Hall of Mirrors, Philosopher's Stone, Supernova | La Avalancha, Sala de los Espejos, Piedra Filosofal, Supernova | 雪崩、镜厅、贤者之石、超新星 |
| Double or Nothing, Gold Rush, Rush Hour, Mult Fever, Treasure Hunt | Doble o Nada, Fiebre del Oro, Hora Punta, Fiebre de Multi, Caza del Tesoro | 加倍或归零、淘金热、高峰时段、倍率狂热、寻宝 |
| Emergency Brick, Eraser, Second Tray | Ladrillo de Emergencia, Goma, Segunda Bandeja | 应急砖块、橡皮擦、第二托盘 |
| Reduced Motion | Movimiento Reducido | 减少动态效果 |

## Things to check before submitting

- **Language support.** A Spanish or Chinese store page is fine while the game is English only, but in Steamworks list only the languages the build actually supports (interface / audio / subtitles). Add Spanish and Chinese there once the game's localization (`locale/`) ships.
- **Claims match the build.** The text describes the current build: 70 Jokers (4 Legendary), 12 rounds in three acts, Mk II bosses, 5 Kits, Heat 0–5, Daily, Overtime, Endless (15 styles), 60 achievements (10 secret), POPS. They are *local* achievements: do not tick "Steam Achievements" or "Steam Cloud" until they are integrated. Controller support is not claimed.
- **Chinese pixel text.** The Chinese words in the images are drawn with Microsoft YaHei Bold (a Windows system font) at 16 px, without antialiasing. Microsoft generally allows fonts shipped with Windows in static images, but confirm that for commercial use, or swap in an open font (for example an OFL pixel CJK font) by changing `CJK` in `tools/store/build_store.py`.
- **No links or social images** in the About section (Steam rule); the texts contain none.
