# BLOCKMANIA — Task Board

Living backlog. Update it in the same commit as the work. Milestones follow GDD §12.
Legend: `[x]` done · `[~]` partial · `[ ]` open · **(owner)** needs a project-owner decision.

_Last updated: 2026-09-26 — Release playability study (`docs/playtests/2026-09-26_release_study.md`): 4,560 simulated runs; items and Joker repetition confirmed as structural problems; two Warden bugs. Earlier (2026-09-25): translations, ten more UI languages and the languages layout scenario (Owner requests, 2026-09-25 (translations)). Earlier (2026-09-24): Plan items from the review (campaign Hold, round cards, Mk II bosses, Heat 0–5, Joker unlocks, Daily, run history, milestones, tips), boss cinematic and mood shader, 6 new songs, settings/menu redesign (GDD §22). Earlier: persona playtest review (docs/playtests), engine update (interest, overkill, multi-line Mult, scaling Jokers, Rack Extender, 13 Jokers, 4 items, 4 Legendary Jokers, Legends achievement page, targets raised). Earlier today: shop menu, card portraits, Overtime, 48 achievements._

## M0 — Rules prototype

- [x] Pin engine: Godot **4.7.2 stable**, GDScript, Forward+ (see `project.godot`, README).
- [x] Pure rules layer independent of nodes: board, shapes, bag, resolver, run state (`game/rules`, `game/content`, `game/run`).
- [x] Seeded, separate RNG streams (shapes / shop / boss); 64-bit state stored as strings for JSON saves.
- [x] ~~Random tray dealing~~ replaced by the Bag (see below). Legal-at-deal guarantee kept.
- [x] Placement resolution pipeline (GDD §5 steps 1–9) with resolution record + itemized receipt.
- [x] Crossing row/column clears removed once; no gravity; combo 0–4 and reset.
- [x] Target crossing ends the round after full resolution; out-of-placements and no-fit failure; Refresh prompt; Tiny Insurance rescue; Concede.
- [x] Credits payout (base, unused-placement bonus, boss, Spare Parts, Cash Out; cap 99).
- [x] Shop: 3 Joker + 2 item offers, rarity weights by act, reroll price escalation, buy/sell/reorder, slot capacity.
- [x] 12 rounds / 3 acts / boss rounds 4-8-12, bosses chosen per run without repeats.
- [x] Action history + `BMRun.replay()`; determinism, replay, and save/resume tests.
- [x] Headless test runner with runtime-error capture (`tests/run_tests.gd`), now 100 tests.
- [x] Autoplayer (preview-guided, shop policy) + balance probe (`tools/simulate.gd`) + paired-seed experiments (`tools/experiments.gd`).
- [x] Placeholder UI: title, round intro, board, tray, HUD, score preview, receipt, Jokers/items rail, round result, shop, run end, pause.
- [x] Mouse drag-and-release, click-to-hold, right-click/Esc cancel; keyboard 1–3 / arrows+WASD / Enter+Space / R / Esc.
- [x] Local save after every action (atomic temp+rename), Continue on title, finished runs not resumable.
- [ ] Ten reproducible complete seeded runs reviewed by a human (M0 exit criterion) — needs playtesting.
- [x] Tutorial: POPS guides the first session (GDD §23) on top of the contextual tips (§22.9). A scripted first round with fixed offers is not planned unless playtests ask for it.

## The Bag — customizable pieces (GDD §16)

- [x] Persistent bag of pieces (family, orientation, color, material, stamp); 24-piece starter bag; min 12 / max 60.
- [x] Draw/discard piles, shuffles, reshuffle on empty draw pile, legality guarantee by swap (temporary Single as last resort).
- [x] Board remembers each cell's piece and material; clear-triggered effects work on earlier placements.
- [x] Materials: Chrome, Neon, Gold, Glass (with deterministic shatter), Prism. Stamps: Encore, Refund, Tip, Memory. Schematic family levels.
- [x] Workshop: 13 tool cards + Schematics, applied via bag picker; pieces for sale; reroll covers everything.
- [x] 14 bag-era Jokers (38 total) including order-sensitive **Mimic**.
- [x] Bag view (key B / View Bag), tray tooltips, material finishes and stamp badges with non-color cues, receipt lines.
- [x] Save schema 2 (schema-1 prototype saves ignored); replays include bag edits.
- [x] Tests: dealing, pile accounting invariant, guarantee, every material/stamp/tool, new Jokers, save/replay of bag edits.
- [ ] Workshop usable during rounds? Packs with choose-1-of-3? Kit-specific starter bags? (owner, GDD §16.10)
- [ ] Bag-edit feedback animation (piece glides into the bag, shatter effect); basic bag/workshop audio cues are in.
- [ ] Autoplayer: smarter Workshop targeting (it favors large pieces, which are drawn no more often than small ones).

## M1 — Vertical slice (in progress)

- [x] 37 of 38 Jokers implemented with per-card tests (all except Patch Panel).
- [x] 5 of 8 consumables usable: Polish, Spark, Second Tray, Extra Turn, Cash Out.
- [x] 5 of 6 bosses active: Cramped Cabinet, Taxman, Color Blind, Lockdown, Last Call.
- [x] **Patch Panel**, **Eraser**, **Lucky Paint**, **Blueprint** now usable (round-play update targeting).
- [x] Joker trigger presentation in resolution order: sequenced card pulses with Chips/Mult pop text (capped at 6 per placement).
- [x] Score count-up (rolling counter, liquid tube) and clear VFX (sweep, wave-delayed bursts, shards, streams, CRT shock).
- [x] **Placement budget rework** (owner: "12 is too short"): Kits start with 15 / 15 / 14 placements, every cleared line gives one back up to the starting count, a clear on the last placement keeps the round alive. Last Call 10 → 12, Extra Turn cap 16 → 20. HUD bulbs show left/cap with a mint refill flash, a +N pop, a receipt/message line, and intro and tooltip text. Save schema 3 (`placement_cap`). Tests added (GDD §5 "Placements and refills").
- [ ] Human playtest of the refill budget: does Act 1 feel too easy now (targets unchanged)? Does the unused-placement Credit bonus and Spare Parts inflate the economy?
- [x] Game speed setting (Normal / Fast / Turbo, campaign only; GDD §22.10). Boss intro skips on any input. [ ] Skip input for the scoring sequence itself.
- [x] Audio: 59 synthesized effect files for UI, pieces, clears, combos, economy, Jokers, bag, and results; seven original lo-fi tracks for title, round, shop and boss contexts.
- [x] Audio options: master/music/effects levels, sound and music switches, background mute, Next Song, and `M` shortcut; settings persist separately from runs.
- [ ] Human listening pass on target speakers/headphones: balance repetitive effects, confirm music pacing and cue comfort; adjust mixes after feedback.
- [x] **UI overhaul** (2026-09-23): original pixel-art kit and Blockhead fonts generated as code, swirl shader background, CRT filter (Off/Soft/Full), particle VFX, new title/round/shop/pause/bag/modals. See ASSET_PLAN §12.
- [x] Image-generator art (`assets/source/generated/`) reviewed by the owner: **not adopted**.
- [x] Layout verified at 1920×1080, 1280×720, 1680×1050 and 2560×1080 with `tools/shoot.py`; stage children checked for minimum-size overflow.
- [x] Title-screen Options (CRT, motion, block patterns, controls) before starting a run.
- [x] Fullscreen toggle and Show FPS in Options (DISPLAY), saved in settings (2026-09-23).
- [x] Launch splash "by Mario Landáburu / made with Godot" replaces the Godot boot image: dancing letters, burst, fade to the title; skippable (2026-09-23).
- [x] Buru Arcade studio logo (owner request, 2026-09-24): `tools/art/gen_studio_logo.py` writes the logo, square mark and Steam creator page avatar/header to `assets/brand/`; the launch splash now builds the logo from blocks, pops a block and bursts it (replaces the "by Mario Landáburu" text).
- [x] Owner feedback batch (2026-09-24): **Veteran** Joker (Chips trained onto the exact piece, copied by Copier, kept after selling); **Kits** with their own bags and a signature perk each (Thrift, Compound Interest, Heavy Lifting, Full House); locked Kits hide their contents behind a padlock; Heat buttons redrawn; **practice seeds** (typed / replayed seeds) earn no achievements, records or unlocks (save schema 8); **custom cursor** with effects (Options > Display, default on); tutorial: glove never under the bubble, POPS ducks during "clear a line", leaves after "see you in the shop" and after the NEXT ROUND hint; **Refresh lever** (pixel art, lamps, pull animation, sounds); the boss hazard frame sized in stage pixels (no more cut HUD text); the boss panel never grows into the board; a full 7-slot Joker rack fits above ITEMS in the shop and round; the shop's next-boss rule uses its free lines. E2E: `scenario_practice_veteran` (new), `scenario_tutorial` (F14-F17).
- [x] Owner follow-up (2026-09-24): Veteran trains only pieces that complete a line (the first version trained every placement: too strong); the Refresh lever lost its hover outline and got a slot-machine pull (casino lever sound, slam shake, coin spray, lamp chase, reels start on the slam). E2E V7 added.
- [x] Steam store page kit (owner request, 2026-09-25): About-section and short descriptions in English, Spanish and Simplified Chinese, localized banner/section headers/Joker, finish and achievement panels, framed screenshots, two MP4/WEBM clips and 13 store screenshots in `store/steam/` (`tools/store/capture.py` on a sandboxed profile + `tools/store/build_store.py`; upload guide and glossary in `store/steam/README.md`). Open: library assets; confirm the system-font license for the Chinese pixel text.
- [x] Steam capsules (owner request, 2026-09-25): header, small, main and vertical capsules in English, Spanish and Simplified Chinese plus the page background, in `store/steam/capsules/` (`node tools/store/capsules.mjs`, drawn with the trailer engine; only the subtitle is localized). Open: owner to confirm "The Block Puzzle Roguelike" as the official subtitle. Library assets (2026-09-25): capsule 600×900, header 920×430, hero 3840×1240 (no text) and transparent logo 1280 wide in `store/steam/library/` (`node tools/store/capsules.mjs library`); title only, so one English file each.
- [x] Steam achievements kit (owner request, 2026-09-25): six Steam achievements mirroring local ones (Crossroads, Boss Buster, Once Upon a Legend, Arcade Regular, BLOCKMANIA!, hidden Broke the Machine) with 256×256 JPG icons (color/grayscale), EN/ES/ZH texts and localization VDF in `store/steam/achievements/` (`tools/store/build_achievements.py`); `BMSteam` (`game/run/steam_bridge.gd`) sets them through GodotSteam when present, never from a sandbox. GodotSteam 4.22.1 installed via `tools/release/install_godotsteam.sh` (loads in 4.7.2). Open: test unlocks with the Steam client, then tick Steam Achievements in Supported features.
- [x] Steam upload kit (owner request, 2026-09-25): `tools/steam/build_steam.sh` exports the three depots (GodotSteam included, dev plugin excluded, macOS 10.15+/11+ universal with the library-validation entitlement), `tools/steam/upload_steam.sh` + the manual **Steam upload** workflow upload them from Linux (keeps executable bits), `store/steam/SUBMIT.md` walks through depots, launch options, upload, set live, testing, store page and review; `store/steam/system_requirements.md` (provisional, EN/ES/ZH). Open (owner): Steamworks setup and upload (Parts A–E); decide the title screen's "prototype build" footer and version before review; measure requirements on low-end hardware.
- [x] Title menu polish (owner request, 2026-09-23): every menu button has an icon with its label centered; clicking a BLOCKMANIA logo letter makes it explode and drop back in (easter egg, cosmetic only). The Continue Endless button is gone: Endless with a game in progress opens a Continue / New Game popup.
- [x] Focus outline appears for keyboard navigation and is hidden after pointer use.
- [x] Owned Jokers reorder by drag and drop in the round and shop; Alt+Up/Down is the keyboard alternative.
- [x] Endless arcade mode: separate seeded rules and save, fair three-piece deals, Hold, no-fit loss, x1/x2/x3/x5/x8/x10 combo with three-miss reset, clean-board bonus, top-ten local scores, pixel infinity icon, and calm/tension/celebration presentation with an added combo music layer.
- [x] Endless includes 2×3 rectangle and 3×3 square offers, line-count callouts, scoreward particles, high-combo trails/pulse/shake, and a right-side Hold well in place of tutorial text.
- [x] No-fit loss triggers immediately when the tray is stuck and Hold is empty; an already stored fitting piece may still rescue the run. Stuck saves created by the old rule resume into the result screen and record their score.
- [x] Storing the last tray piece in an empty Hold deals three fresh fair offers, keeps Hold on cooldown until a placement, and survives seeded save/resume.
- [x] High-score popup rebuilt so its art cannot intercept Back or score-row clicks; run details include score progression and 11 additional statistics. No Room Left shares the same detailed breakdown and graph. Endless save schema 3 tracks stats and active time, and older saves remain readable.
- [x] Endless finish picker: 12 selectable finishes with custom synthesized cues, plus unlockable animated Aurora/Starfall. Complete board clears switch to the bright Fresh Board look and music context.
- [x] Block finish redesign (owner request, 2026-09-23): 14 animated pixel-art finishes in `tools/art/gen_finishes.py` (stained glass, step-cut crystal, neon tube, gilded gold, marble, circuit, toy wood, pinwheel candy, lava, ice, mirror chrome, holographic prism, aurora, starfall), each with its own motion, stepped glow halo, place/clear particles and generated place/clear sounds (`tools/audio/gen_finish_sfx.py`). Prism added as a 15th Endless style. Campaign materials now draw the matching finish face instead of an overlay, with their own sounds on place and clear. Stamps redrawn as animated badges with distinct silhouettes (star, return token, credit coin, bolt gem) and a trigger sound each. `tests/test_finishes.gd` guards the art/sound/catalog contract.
- [ ] Human playtest of Endless shape weights, scoring, combo pacing, and high-score replay value; balance numbers are provisional (GDD §17).
- [ ] Human comfort and listening pass for the new combo percussion and high-combo effects at 720p and on target hardware.
- [ ] Human review of all 15 block styles and their cues: color readability at tray size, glow comfort on busy boards (Neon is the strongest), shine-wave frequency, mix level of material/stamp cues over the clear chime, reduced motion, and Fresh Board transitions on target hardware.
- [x] Joker art: every Joker, item and Workshop tool has its own code-drawn pixel portrait (2026-09-24, `tools/art/gen_cards.py`).
- [ ] Hover and tooltip pass with real mouse playtesting (tooltips are styled; hover lifts are verified in fixtures only).
- [ ] The Joker rack rebuilds on every refresh; keep the hover state across rebuilds.

## Round-play proposals (awaiting owner approval)

Full specs, odds and reasoning: [docs/design/round_play_update.md](docs/design/round_play_update.md). This includes the review of `ideas.md` (keep / later / discard).

- [x] Tray Hands: Twins / Staircase / Monochrome / Triplets / Grand Slam on natural deals (`BMHands`, `tests/test_hands.gd`), Hot Hand and Card Sharp Jokers. Presentation: every deal spins the tray like slot reels; Hands get a ribbon, chase lights, a callout, particles, and their own fanfare (`tools/audio/gen_sfx_features.py`).
- [x] Item targeting (cells / one cell / color / tray slot / slot + color / slot + shape) with board overlays, keyboard control, and CANCEL/ERASE buttons on the item card. Eraser, Blueprint, Lucky Paint, and Patch Panel are live; new Punch, Color Purge, and **Emergency Brick** (a throwable physics brick: grab and fling it, or click a slot; it bounces off the screen edges and smashes into the slot it hits). Board tools remove cells without scoring (`tests/test_tools.gd`).
- [x] Feats in the resolution record (`BMFeats`): Crossfire, Double Tap, Hat Trick, Clean Board, Needle Threader, Last Breath. They show as gold medal banners and receipt lines.
- [x] 14 new Jokers (52 total): Patience, Locksmith, Countdown, Breakage Bonus, Insurance Policy, Showboat, Full Tank, Overflow, Keystone, Draftsman, Card Sharp, Hot Hand, Periscope, Loan Shark, each with trigger and no-trigger tests. Periscope draws the next pieces on its card; Insurance gets a stamp and a replay dialog; Loan Shark has its own coin sound.
- [x] Bosses: **The Warden** (a barred tray slot until the first clear; deals and Refresh skip it) and **The Undertaker** (a tombstone rises every 4th placement, never completing a line). Both have their own art, animation and sound; Echo Chamber stays out of the pool. Emergency Brick is in the shop. (`tests/test_bosses.gd`)
- [x] Fit indicators (tray "NO ROOM" caption already existed); Bag view statistics (families, colors, upgraded) and exact Tray Hand odds per deal.
- [x] Kit starter bags (Standard 24, Compact 18 without Singles, new Chunky 20 and Tetromino 20). Kit picker on New Run, with bag drawings and unlock progress. Lifetime unlock counters are in `user://profile.cfg`, and the run-end screen announces new Kits.
- [x] Boss Crate: after each boss, pick 1 free from a Joker (uncommon/rare), an item, or 6 Credits. The crate rattles and bursts open; a BOSS CRATE button reopens it until you leave the shop. Crate art redrawn (owner request, 2026-09-23): a detailed 64×60 pixel crate with a hover frame that lifts the lid, plus a matching button icon. A crate Joker or item you have no slot for shows LOCKED (padlock, SLOTS FULL tag, how-to-unlock note); while the crate is unopened the round ticker shortens so the BOSS CRATE button never covers it.
- [x] Combo grace: the campaign combo survives one placement without a clear (`COMBO_GRACE = 1`). Simulated: win rate 10% → 13%, average round 9.98 → 10.28. The HUD shows "x3!" and "HANG ON!".

## Owner requests, 2026-09-24

- [x] **Shop menu:** Esc (or the new MENU button) in the shop opens the pause menu; "SAVE & MAIN MENU" returns to the title and CONTINUE RUN resumes in the shop. Esc still closes shop popups first.
- [x] **Card portraits:** an original 16×16 pixel sprite for each of the 52 Jokers, 11 items and 5 Workshop tools (materials and stamps keep their live finish drawing), generated by `tools/art/gen_cards.py` with an auto ink outline and an 8-frame sheet (rest, 6-frame glint, silhouette). Emblems keep the phase color tile; portraits glint now and then (Rares more often, with twinkles) and hop on hover. Reduced Motion shows the rest pose.
- [x] **Overtime** (GDD §19): KEEP PLAYING after the round-12 win; rounds 13+ with fast-rising targets, a boss per act, compact M/B/T/Q numbers, OVERTIME tags, run-end "OVERTIME OVER". The machine's limit (10^15 per placement) ends the run as MACHINE BROKEN. Personal records (furthest round, best placement, best round, machine broken) with NEW RECORD lines. Save schema 5; the Kit profile never double-counts a run. Tests: `tests/test_overtime.gd`.
- [x] **Achievements** (GDD §20): 48 badges on 4 pages (8 secret), tiered medal art and 48 pixel icons, unlock toasts with tiered fanfares/particles, the Trophy Case (cabinet, meter, tabs, page flips, hover cards, NEW tags, records plaque), 12 new sounds (`tools/audio/gen_sfx_achievements.py`). Tests: `tests/test_achievements.gd`.
- [ ] Human playtest: Overtime curve (bot: 12 of 16 winners fell in round 13), toast frequency early in a first run (many bronze badges come fast), listening pass for the new fanfares and the machine-break crash.
- [ ] Steam achievements mirror of the local ids (later, optional).

## Owner requests, 2026-09-24 (review and engine update)

- [x] **Persona playtests and design report:** `tools/playtest.gd` (15 personas: random, newcomer, steady, a whole-tray search planner, seven build archetypes, four Kits, ceiling and opportunity probes) + `tools/playtest_report.py`; 770+ baseline runs. Report with verdict, diagnosis, changes and plan: `docs/playtests/2026-09-24_persona_playtest.md` (tables beside it).
- [x] **Engine update** (GDD §21): multi-line base Mult, interest, overkill, Rack Extender (7 slots), run-long scaling Jokers (`BMRun.joker_state`), 13 new Jokers, 4 new items (Turbo, Tune-Up, Coffee Break, Coin Roll), 6 retuned cards, targets for rounds 3–12 raised ~25%. Save schema 6.
- [x] **Legendary Jokers** (rarity 4, unique, cost 12): The Avalanche (gravity chain waves), Hall of Mirrors (Jokers trigger twice), Philosopher's Stone (doubled materials, transmutation), Supernova (per-round line Mult). Boss Crates from act 2 (12% / 20% / 30% Overtime) and late shops (1% / 3%). Lilac frames, reveal/get stings, callouts, receipt lines per wave.
- [x] **Achievements page 5 "Legends"** (12 badges, 2 secret, icons): Legendary finds, Pantheon (lifetime), Chain Reaction, Mirror World, Going Nova, Billionaire, and more. 60 achievements in total.
- [x] Tests: `tests/test_engine.gd`, `tests/test_legendary.gd`, new cases in `test_achievements.gd`; retuned card tests updated.
- [ ] Human playtest of the engine update: do Legendaries feel special or mandatory? Is the Avalanche readable (blocks do not animate their fall yet)? Does interest make players hoard?
- [x] Animate the Avalanche fall: blocks fall with gravity and squash between waves (GDD §22.11).
- [x] Plan items from the report (§7): see the next section.

## Owner requests, 2026-09-24 (plan items, boss spectacle, menus)

- [x] **Campaign Hold** (GDD §22.1): store or swap one piece between placements; a fitting held piece keeps a round alive; the Lockdown Mk II disables it. Autoplayer uses it as a rescue.
- [x] **Round cards** (§22.2): Standard + two seeded twists before every non-boss round (Gold Rush, Tight Budget, Rush Hour, Double or Nothing, Mult Fever, Treasure Hunt, Scholarship), picked on a CHOOSE ROUND overlay (keys 1–3).
- [x] **Mk II bosses** (§22.3) from act 2, every boss at Heat 4+, the final boss in Overtime.
- [x] **Tray Hands and Kits rebalanced** (§22.4): Twins +1 Mult, Triplets x1.5, Monochrome x2, Grand Slam x2; unlockable Kits at 14 placements, Chunky 19 pieces.
- [x] **Heat 0–5** (§22.5) on the Kit screen; each win unlocks the next level.
- [x] **Joker unlocks** (§22.6): 14 Jokers gated by achievements, NEW JOKER UNLOCKED toast, Trophy Case hover lines.
- [x] **Daily run and RUN HISTORY** (§22.7), **Overtime milestones** at 1M / 1B / 1T (§22.8), **contextual tips** (§22.9).
- [x] **Boss spectacle** (§22.11): boss cinematic, mood shader (hazard frame, danger vignette + heartbeat, heat haze and embers), board chase bulbs, new swirl moods, Avalanche fall animation, act-start fanfare.
- [x] **Music**: six new original songs (13 total) and round_hard / boss_mk2 / overtime playlists; eight new cues (`tools/audio/gen_sfx_bosses.py`).
- [x] **Menus** (§22.10): title reorganized (DAILY, HISTORY), Kit screen with Heat and seed, tabbed Pause/Options (`BMSettingsMenu`) with a RUN page and new accessibility settings.
- [x] Tests: `tests/test_features.gd` (17), `tests/test_menu.gd` (6). 234 tests pass.
- [ ] Human playtest: round-card pick rates (is one twist always right?), Heat 1–5 difficulty steps, Mk II spikes in act 2, whether Hold makes rounds too safe, tip timing and wording for a first-time player.
- [ ] Human comfort pass: boss cinematic length, heartbeat annoyance, hazard frame and heat haze at 720p and with the CRT on, flash strength (the Flashes setting defaults to Full).
- [ ] Human listening pass for the six new songs (checked for loudness only, not by ear).
- [x] First-session tutorial: POPS (GDD §23).

## Owner requests, 2026-09-24 (README)

- [x] README rebuilt as a store-style page: banner, badges, gameplay and boss GIFs, feature rows with screenshots, Joker/finish/achievement galleries, screenshot grid, "how it is made", tech stack, architecture and commands for developers. Media in `docs/media/`, reproducible with `tools/readme/shoot_all.py` (real game, off-screen, seeded run + staged board) and `tools/readme/build_media.py` (Pillow, game fonts and art only). Raw captures are git-ignored.
- [ ] Refresh README media and the test badge count when the UI or content changes noticeably.

## Owner requests, 2026-09-24 (testing policy, tutorial)

- [x] **E2E suite** (`tests/e2e/`): the real app with a sandboxed profile; campaign (3 seeds, 3 Kits, Heat 0/2/4, save/resume, replay, preview = result on every placement), Endless (Hold rescue, resume, high score) and menus (every popup, every setting persisted, game speed scope). Artifacts in `build/e2e/` with a gameplay fingerprint that repeats run to run.
- [x] **Unit test triage** (six parallel reviews): 39 of 234 isolated tests deleted (catalog restatements, trivial wrappers, duplicates, and checks the E2E now asserts: full-run determinism, save/resume, bag accounting in normal play, run completion). 195 remain, each pinning a number, trigger or edge case the E2E cannot see.
- [x] **Testing policy** in AGENTS.md: no unit tests after code, E2E first with repeatable artifacts, failure modes written before any isolated test.
- [x] **Tutorial with POPS** (GDD §23): a pixel-art caretaker bot (rainbow afro, beard, bow tie, antenna bulb) in the screen corners with a speech bubble, gibberish vowel voice, pointing arm, bobbing glove and spotlight; 14 steps through round 1 and the first shop; SKIP and REPLAY TUTORIAL. Written test-first: `tests/e2e/scenario_tutorial.gd` (13 failure modes).
- [ ] Human playtest of the tour: wording, pacing (42 cps), whether the "clear a line" step feels forced, voice pitch and volume.
- [x] Flaky `test_store_unlocks_once_and_grants_the_meta_badge`: root cause found through the E2E runs. `BMAchievementStore.reload()` resolved to the built-in `Script.reload()`, which re-parsed the class and put `path` back to the real `user://achievements.cfg`, so redirected stores (tests, the E2E sandbox) read and wrote real player data and the test's cleanup deleted it. Renamed to `forget_cache()`.
- [ ] The E2E seeds never win the campaign, so Overtime is only covered by isolated tests; find a winning seed or script a win.
- [ ] docs/design/round_play_update.md §2 still says Twins gives +30 Chips (the code gives +1 Mult since the Hands rebalance, GDD §22.4).

## Owner requests, 2026-09-24 (downloadable builds)

- [x] **Downloadable builds**: Windows (x86_64), macOS (universal, ad-hoc signed) and Linux (x86_64) presets; `tools/release/build_release.sh` + `install_templates.sh`; `.github/workflows/release.yml` publishes a GitHub Release on a `v*` tag with fixed asset names; README download buttons point at `releases/latest/download/...`. ETC2/ASTC import enabled (required for Apple Silicon). Linux export smoke-tested (900 frames, no script errors); Windows and macOS builds exported but not launched here.
- [ ] Launch-test the Windows and macOS downloads on real machines (the Mac build is unsigned and not notarized: right-click → Open).
- [ ] Code signing / notarization before a wider release (Windows SmartScreen, macOS Gatekeeper).

## Owner requests, 2026-09-25 (Steam trailer)

- [x] **Steam trailer v2** (64 s, owner feedback: gameplay by 6 s, Legendaries inside the Joker wall, shop REROLL button replaces all offers, pixel Steam mark on the wishlist button; `steam_icon.png` is pixelated from the Steam client's own logo). v1 was 72 s, 1080p60, H.264 + AAC, -14 LUFS): authored as code in `tools/trailer/`. The picture is a deterministic canvas/WebGL render (`trailer.html`, `engine.js`, `scenes.js`) with the game's own sprites, fonts, swirl and CRT look plus real `docs/media` screenshots; the music is synthesized (`gen_score.py`, B minor so the game's D-major SFX sit in key) with the game's SFX on the picture cues. Style sheet and shot plan: `tools/trailer/STYLE.md`. Build: `cd tools/trailer && npm install && node render.mjs cues && python gen_score.py && node render.mjs video 8 && ./mux.sh` (output `tools/trailer/build/BLOCKMANIA_trailer.mp4`, git-ignored).
- [ ] Owner listening pass on the score (mixed by measurement only: stem levels, spectrogram, loudness), especially the formant "BLOCK-MA-NI-A" chant and the SFX levels.
- [ ] Re-render when content changes: the trailer states 70 Jokers, 14 finishes, 60 achievements, 5 Kits, Heat 0–5 (`data.js` is generated from `game/content`).
- [ ] README still says "69 Jokers" (the catalog has 70 since Veteran).

## Owner requests, 2026-09-26 (release playability study)

- [x] **Release-style study:** `tools/study.gd` (600 synthetic participants in 5 archetypes with sampled item, shop, round-card and duplicate habits, 3 runs each, plus 23 paired-seed arms × 120 seeds; full ledger of every offer, purchase, item and round) + `tools/study_report.py`. Report: `docs/playtests/2026-09-26_release_study.md`, tables beside it.
- [x] **P0 bug:** Tiny Insurance can put its rescue Single into the Warden's barred slot, so the round stays `PLAYING` with no legal move and Concede is refused (soft-lock; reproduced with participant 201, seed 53417, round 8). Fixed (2026-09-26): the Single goes into the first unbarred slot (`BMRun._insurance_slot`). E2E `scenario_warden` (W1–W7) and a new campaign invariant: a `PLAYING` round always has a legal move.
- [x] **P0 bug / rule:** Warden Mk II never freed its second barred slot. Decided (owner delegated, 2026-09-26): **each clearing placement frees one barred slot**. Code, Mk II rule text, round-start message ("BARRED SLOTS %d AND %d") and GDD §22.3 aligned; `scenario_warden` W3–W7.
- [ ] **(owner) Items rework:** no item habit beats never buying items (79% vs 75–78%, paired). The rescue items answer a no-fit state seen in 0.2% of rounds (95% of losses are "out of placements"); Spark and Polish shrink to 4–8% of a target by act 3. Proposals in report §4 items 3–7 (merge rescue items, scaling boosts, value preview on drag, sell or refund unused items).
- [ ] **(owner) Shop repetition:** a bought Joker returns in a later shop 33% of the time; one Joker is offered 3+ times in 70–76% of runs; stacking copies loses (85% avoid vs 76% stack, p = 0.02). Not offering owned Jokers is balance-neutral (80% vs 80%); also skipping the last visit's Jokers cuts "3+ offers" to 37%. Proposal: report §4 items 8–11.
- [ ] **(owner) Round cards are free money:** twists clear as often as Standard (96%), and picking them sensibly lifts wins 79% → 89% (p = 0.03) with 44 Credits banked at the end. Retune (report §4 items 12–13).
- [ ] Late-game Credit sink, sharper act bosses (5 of 6 cleared 91–98%), rarer Tray Hands more often, first-timer build guidance (report §4 items 14–18).
- [x] GDD §22.4 said Compact/Chunky/Tetromino start with 14 placements and Chunky lost its 3×3; aligned to the code and §6 (Compact 16, Chunky 13 with its 3×3). §6 rarity text now says 40/40/19/1.
- [ ] `scenario_menus` failed once (vsync / show_fps not saved) right after a long simulation batch, then passed twice with the same fingerprint: watch for flakiness.
- [x] **Overtime study** (owner request, 2026-09-26): 1,439 runs continued past round 12 (population + `ot_*` arms + Legendary probe; `tools/overtime_report.py`). Report: `docs/playtests/2026-09-26_overtime_study.md`.
- [ ] **(owner) Overtime pacing:** Avalanche chain-wave lines refill placements, so deep rounds rarely run out and grind on (medians 36–57 placements, longest 1,359). Proposal: wave lines give no refill, or cap Overtime refills or placements per round (report §4.1).
- [ ] **(owner) Overtime curve:** targets jump from ~1.3x per round to 1.8–2.2x at rounds 13–16; clear rates 69% / 57% / 47%, median final round 15 for every competent group. Depth depends on Legendaries (deep runs hold 1.5, shallow 0.19). Proposal: gentler first Overtime act or a guaranteed Legendary crate after round 12 (report §4.3).
- [ ] Color Blind Mk II clears 34% in Overtime (other Mk IIs 51–70%). Hot Streak copies share one value and all reset on a Refresh: document it on the card or soften the reset.
- [ ] Overtime Credit sink (40–75 Credits unused per shop); decide the role of the machine limit (never reached in ~1,440 runs; targets hit 10^15 at round 55).
- [ ] Human playtest to confirm what the bots cannot judge: Turntable (never bought by bots), Periscope, Card Sharp, Patch Panel, Draftsman, Locksmith, and real item-use friction.

## Owner requests, 2026-09-26 (study follow-up)

- [x] **Receipt overflow** (owner bug): a long receipt grew the tape past its rect, under the Hold box and cards. The tape now keeps its rect; lines scroll inside it, the newest stays in view, and the player can scroll back up (following resumes at the bottom or on the next placement). E2E `scenario_receipt` (R1–R4; the old tape grew to 416 px of its 292).

## Owner requests, 2026-09-25 (translations)

- [x] **Eleven UI languages**: English, Spanish, French, Italian, German, Dutch, Polish, Brazilian Portuguese, Japanese, Simplified and Traditional Chinese (all 1,442 messages; `tools/i18n/check.py` clean). Settings > Game > Language (SYSTEM follows the OS); switching rebuilds the screens in place. Rules text stays English in saves and results and is translated for display (`BMLoc.tf`). Blockhead gained the Latin accents; CJK comes from Fusion Pixel 10 px subsets (OFL). Guide and glossary: [docs/localization.md](docs/localization.md).
- [x] **No broken UI in any language**: `tests/e2e/scenario_languages.gd` visits 30 screens and overlays (title popups, every Options tab, Kit picker, trophies, tutorial, round intro, round, bag, pause, round result, shop, round picker, boss intro and cinematic, crate, run end, history, Endless and its style picker and game over) in all eleven languages and fails on missing glyphs, text escaping its panel, controls grown past their rect, cut text without a tooltip, untranslated text and drawn text that does not fit. Fixes: text-measured buttons (RESET PAGE, COPY SEED, Heat/Seed labels, language grid), `BMUI.draw_fit` for code-drawn text, two-line Kit facts and Bag tile labels, fitted price buttons, taller boss panel (+12 px, receipt −12 px), Joker rack text on two lines when there is room, shorter translations where they ran long. Achievement toasts on screen re-show in the new language. Later passes: title menu buttons keep their text clear of the icon, POPS's bubble is really `DIALOG_W` wide and stays on screen (it used to hang 56 px past the right edge in every language), tutorial buttons fit, the Endless block-style button falls back to the style name, bag and reroll buttons step down, no word is split mid-line (Fiskus, Rückgabestempel, Versnipperaar).
- [x] E2E sandbox is per checkout (`user://e2e_sandbox_<hash>`): worktrees share `user://`, and a suite in another checkout was wiping this one's saves mid-run.
- [x] Untranslated text found by the scenario: feat banners, item rack bodies (round and shop), the Legendary Joker pop.
- [ ] Native-speaker review of all ten translations (machine-assisted; terms are consistent with the glossary but unreviewed by native players). **(owner)**
- [x] **Steam languages** (owner request, 2026-09-26): SYSTEM follows the language picked for the game in Steam (`ISteamApps::GetCurrentGameLanguage` through GodotSteam, Steam codes mapped in `BMLoc.STEAM_CODES`, isolated test `test_language_choice`); `-- --lang-report` build check wired into `tools/steam/build_steam.sh` (a Windows release export reported 10/10 translations and 3/3 CJK fonts); Steam achievements in every language from the game's texts; store descriptions, short descriptions and text images in all eleven languages (plus `latam`/`portuguese` copies), CJK store images now drawn with Fusion Pixel (no system-font license); Steamworks guide [store/steam/LANGUAGES.md](store/steam/LANGUAGES.md).
- [ ] **(owner)** Steamworks: base languages, store Supported Languages (Interface only), store text and images per language, achievement localization, then test with the Properties > Language dropdown ([store/steam/LANGUAGES.md](store/steam/LANGUAGES.md)).
- [ ] Optional: localized capsules and system requirements beyond English, Spanish and Simplified Chinese (Steam shows the English ones).
- [ ] Fixed-size cards still shorten some longer translations with an ellipsis (full text in the tooltip); the scenario counts them (`shortened_with_tooltip`). Trim the translations further if playtests show players miss them.

## M2 — Content complete

- [x] Kit selection screen + unlock tracking (see Round-play proposals).
- [ ] Practice mode (choose seed, Kit, bosses, Jokers; Undo; no records).
- [~] Collection / run history / discovery: the Trophy Case (achievements + personal records) and RUN HISTORY (last 40 runs, replay a seed) are in; a Joker/item collection view remains.
- [~] Settings screen redesigned (GDD §22.10): tabs, segmented controls, RUN page, game speed, tips, boss intros, V-Sync, screen effects, shake and flash strength, heartbeat. Remaining: UI scale 75–150%, input remapping, colorblind presets, high-contrast grid.
- [ ] Save schema migrations (`BMSaveStore.load_run` has the hook) + corruption recovery UI.
- [x] Daily run (local, one seed per date, standard rules; GDD §22.7).
- [ ] Remove or gate the `_mcp_game_helper` autoload in release exports (dev-only tooling).

## M3 / M4 — Polish, balance, Steam

### Marketing launch plan (owner, 2026-09-25)

- [x] Draft a dated solo-developer marketing strategy, creator outreach, store-page positioning, calendar, measurement plan, and assumption-based sales scenarios in `docs/marketing/LAUNCH_PLAN_2026.md`. Owner confirms 0 wishlists before page publication, €7–12 intended price, ~€100 marketing budget, late-October target, and no October Next Fest registration.
- [ ] Publish the approved Steam Coming Soon page as soon as review permits; record the publication date and check the two-week minimum before release.
- [ ] Capture a gameplay-first 15–20 second clip and a press kit; test the live page's first media with five genre-fit players.
- [ ] Build a list of 40–60 relevant creators; send 10–15 personalized pitches per week with tagged Steam links and track replies, coverage, and wishlists.
- [ ] Decide exact release date and final €7–12 price after page traffic, external playtests, and build review. Consider the February 2027 Next Fest route if maximizing launch reach outweighs the late-October date.

- [ ] Production art/audio per ASSET_PLAN; original fonts with licenses.
- [ ] Performance profiling on target hardware.
- [x] Windows export preset and a first demo executable (2026-09-23): single exe with embedded pck, original BLOCKMANIA icon (`tools/art/gen_icon.py`) and version info; dev folders excluded. Launch verified off-screen on the owner's machine.
- [ ] Steamworks integration (achievements/cloud optional, never required for play). Achievements done (GodotSteam); Steam Cloud via Auto-Cloud, no code (setup in `store/steam/SUBMIT.md` A3b, owner to configure).

## Balance watch (provisional numbers — do not tune silently)

- 2026-09-26: **Overtime study** (same seeds as the release study): median final round 15 for engaged, expert and all `ot_*` arms; 17% of entrants reach round 17, 6.4% round 20, 1.4% round 30; deepest fair run lost in round 60 (best placement 1.17 × 10^14); machine never broken. Clear rates by round: 13 86%, 14 69%, 15 57%, 16 47%.

- 2026-09-26: **release study** (build `292051f`, no Overtime). Population (600 participants, 1,800 runs): first-timer 1% wins (dies ~round 6), casual regular 22%, engaged 78%, expert 85%, item lover 86%. Paired arms (120 seeds): skill casual 2.5% / smart 29% / planner-lite 77% / planner 85%; items never 79% vs 75–78% with any item habit; round cards Standard 79% vs sensible twists 89%; duplicates avoid 85% vs stack 76%; shop without owned re-offers 80% (= current). Bosses: Last Call 84%, others 91–98%. Report: `docs/playtests/2026-09-26_release_study.md`.

- 2026-09-24: **Kit perks + Veteran** (persona playtest, 40 runs each, seeds 1001+; Veteran is in the shop pool): steady (Standard) **35%** wins; planner Standard **80%**, Compact (Thrift) **90%**, High Roller (Compound Interest) **83%**, Chunky (Heavy Lifting, +10 Chips per block on 5+ block pieces, 13 placements) **98%**, Tetromino (Full House) **90%**. Every unlockable Kit still beats Standard for the planner, Chunky most of all: if human play agrees, trim Heavy Lifting to +5 per block or Chunky to 12 placements. A first Chunky draft (2 placements back per cleared line) was dropped: a round could run forever, and with Veteran that is unbounded.

- 2026-09-24: **after the plan items** (Hold, round cards, Mk II bosses, Hands/Kits rebalance; the bot always picks Standard and uses Hold only as a rescue): `simulate.gd -- 200 1` gives **30% wins** (was 16% of 100 before), 51% of runs end in round 12 (the final boss is now the wall: 102 of 200), 11 in round 11, avg 283 points per placement. Persona playtests (`steady`, `planner`) still to re-run on this build; Heat 1–5 not yet simulated.

- 2026-09-24: **Engine update + targets 450 / 650 / 900 / 1,200 / 1,800 / 2,400 / 3,300 / 4,400 / 5,700 / 7,300 / 9,300 / 12,500.** Persona playtest (seeds 1001+): steady 10% → 37% wins with the engine and old targets → **18%** with the new targets; newcomer avg round 6.0 → 6.6; planner 82% → 83% (builds grow instead: best placement 34k → 434k, deepest Overtime 15 → 20); multi-line build 38% → 63%; painter 82% → 90%. Legendary probe (three Legendaries from round 1, 7 seeds): Overtime rounds 15–32, and one seed reached round 60 with a 1.2 × 10^14 placement (machine limit 10^15). Watch: planner still clears rounds 1–11 almost always; every unlockable Kit beats Standard (Chunky 100%); late Credits pile up for the greedy bot (33 at round 12). Report: `docs/playtests/2026-09-24_persona_playtest.md` §6.

- 2026-09-24: **Overtime** targets `10,000 × 1.6^k × (1 + 0.08k²)`. Autoplayer, 100 seeds: 16 wins; Overtime ended in round 13 for 12 and round 14 for 4. Human playtests with strong builds decide the curve.

- 2026-09-22: greedy bot with the original targets failed round 1 in 30% of runs and round 2 in 62%; survivors cleared later rounds easily.
- 2026-09-23: **targets retuned** to 450 / 650 / 850 / 1,150 / 1,600 / 2,100 / 2,800 / 3,700 / 4,700 / 6,000 / 7,500 / 10,000 (GDD §5, §16.9). The bot now reaches round ~4.5 on average with gradual attrition. Human playtests must confirm.
- 2026-09-23: **placement budget** 12 flat → 15 with a +1-per-line refill up to the cap. Bot average round 4.3 → 9.3, round 3 clear 71% → 100%, round 8 boss 81%, final boss 11%. Every baseline loss had been "out of placements". Variants compared in docs/design/round_play_update.md §1; the full report is `docs/balance/experiments_v2.md`. New outlier: **Foundry + 6 Chrome 65% wins** (was 13%). Trim Foundry if human play confirms it.
- 2026-09-23: after the round-play update the bot reaches round 10.3 on average and wins 13% (was 9.3 / 2%). **Foundry trimmed +8 → +5** (53% → 27% wins alone). Targets unchanged: human playtest needed. Tool and setup Jokers (Keystone, Locksmith, Draftsman, Overflow…) cannot be judged by the bot. Report: `docs/balance/experiments_v3.md`.
- Per-Joker and per-upgrade impact tables: `docs/balance/experiments_v1.md`. Tuning actions taken from them are listed in GDD §16.9.

## Open owner decisions

- **(owner)** **The Echo Chamber** has no effect with current content (no card creates extra clear waves). It is withheld from the boss pool. Options: rework its rule, add After Clear Jokers that create waves, or replace it. *Proposal: replace it with The Warden (round_play_update.md §5).*
- ~~Joker order never changes a result~~: resolved by **Mimic** (copies the Joker below it). Add more order-sensitive cards? (owner)
- **(owner)** Interpretations made where the GDD was ambiguous are listed in GDD §15 — confirm or adjust.
