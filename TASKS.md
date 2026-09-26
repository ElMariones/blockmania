# BLOCKMANIA — Task Board

Living backlog. Update it in the same commit as the work. Milestones follow GDD §12.
Legend: `[x]` done · `[~]` partial · `[ ]` open · **(owner)** needs a project-owner decision.

_Last updated: 2026-09-25 — Translations: ten more UI languages, the languages layout scenario (see Owner requests, 2026-09-25). Earlier: Plan items from the review (campaign Hold, round cards, Mk II bosses, Heat 0–5, Joker unlocks, Daily, run history, milestones, tips), boss cinematic and mood shader, 6 new songs, settings/menu redesign (GDD §22). Earlier: persona playtest review (docs/playtests), engine update (interest, overkill, multi-line Mult, scaling Jokers, Rack Extender, 13 Jokers, 4 items, 4 Legendary Jokers, Legends achievement page, targets raised). Earlier today: shop menu, card portraits, Overtime, 48 achievements._

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
- [x] Steam store page kit (owner request, 2026-09-25): About-section and short descriptions in English, Spanish and Simplified Chinese, localized banner/section headers/Joker, finish and achievement panels, framed screenshots, two MP4/WEBM clips and 13 store screenshots in `store/steam/` (`tools/store/capture.py` on a sandboxed profile + `tools/store/build_store.py`; upload guide and glossary in `store/steam/README.md`). Open: capsules, library assets, trailer; confirm the system-font license for the Chinese pixel text.
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

## Owner requests, 2026-09-25 (translations)

- [x] **Eleven UI languages**: English, Spanish, French, Italian, German, Dutch, Polish, Brazilian Portuguese, Japanese, Simplified and Traditional Chinese (all 1,442 messages; `tools/i18n/check.py` clean). Settings > Game > Language (SYSTEM follows the OS); switching rebuilds the screens in place. Rules text stays English in saves and results and is translated for display (`BMLoc.tf`). Blockhead gained the Latin accents; CJK comes from Fusion Pixel 10 px subsets (OFL). Guide and glossary: [docs/localization.md](docs/localization.md).
- [x] **No broken UI in any language**: `tests/e2e/scenario_languages.gd` visits 30 screens and overlays (title popups, every Options tab, Kit picker, trophies, tutorial, round intro, round, bag, pause, round result, shop, round picker, boss intro and cinematic, crate, run end, history, Endless and its style picker and game over) in all eleven languages and fails on missing glyphs, text escaping its panel, controls grown past their rect, cut text without a tooltip, untranslated text and drawn text that does not fit. Fixes: text-measured buttons (RESET PAGE, COPY SEED, Heat/Seed labels, language grid), `BMUI.draw_fit` for code-drawn text, two-line Kit facts and Bag tile labels, fitted price buttons, taller boss panel (+12 px, receipt −12 px), Joker rack text on two lines when there is room, shorter translations where they ran long. Achievement toasts on screen re-show in the new language. Later passes: title menu buttons keep their text clear of the icon, POPS's bubble is really `DIALOG_W` wide and stays on screen (it used to hang 56 px past the right edge in every language), tutorial buttons fit, the Endless block-style button falls back to the style name, bag and reroll buttons step down, no word is split mid-line (Fiskus, Rückgabestempel, Versnipperaar).
- [x] E2E sandbox is per checkout (`user://e2e_sandbox_<hash>`): worktrees share `user://`, and a suite in another checkout was wiping this one's saves mid-run.
- [x] Untranslated text found by the scenario: feat banners, item rack bodies (round and shop), the Legendary Joker pop.
- [ ] Native-speaker review of all ten translations (machine-assisted; terms are consistent with the glossary but unreviewed by native players). **(owner)**
- [ ] Localized Steam store text and capsules for the languages beyond English, Spanish and Chinese, if the store should list them.
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

- [ ] Production art/audio per ASSET_PLAN; original fonts with licenses.
- [ ] Performance profiling on target hardware.
- [x] Windows export preset and a first demo executable (2026-09-23): single exe with embedded pck, original BLOCKMANIA icon (`tools/art/gen_icon.py`) and version info; dev folders excluded. Launch verified off-screen on the owner's machine.
- [ ] Steamworks integration (achievements/cloud optional, never required for play).

## Balance watch (provisional numbers — do not tune silently)

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
