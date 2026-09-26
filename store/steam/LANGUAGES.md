# BLOCKMANIA on Steam in eleven languages

This guide covers every Steamworks setting that makes the languages on the store page true and lets players pick
their language through Steam. The game side is already done. Steps marked ✋ happen in the Steamworks partner site.

**What ships (true today):** English, Spanish, French, Italian, German, Dutch, Polish, Brazilian Portuguese,
Japanese, Simplified Chinese and Traditional Chinese. Every menu, card, tip and tutorial line is translated (1,443
messages each, `python tools/i18n/check.py` finds 0 problems). The E2E scenario `languages` opens 32 screens in each
language and fails on text that overflows, is cut off or is left in English. All languages are in the one download
per OS; a player never downloads anything extra.

## How Steam handles languages

Steam keeps three separate language settings. All three have to agree with the game.

| Where (Steamworks) | What it controls | BLOCKMANIA |
|---|---|---|
| **Store page admin > Basic Info > Languages** ("Supported Languages") | The language table on the store page: a tick per language for **Interface**, **Full Audio** and **Subtitles**. Players filter the store by it. | Interface for the eleven languages. No Full Audio or Subtitles: the game has no voice acting (POPS's gibberish has no words; his lines are on-screen interface text). |
| **App Admin > SteamPipe > Depots > base languages** | The **Language** dropdown in the game's **Properties > General** in the Steam client, and what the game reads back from Steam. | The eleven languages. Depots stay on **All languages**: the translations and the Japanese/Chinese fonts add about 2 MB, so no language-specific depots. |
| **Store text, images, capsules, achievements** (a language dropdown on each Steamworks editor) | What a player sees in their Steam language. Anything missing falls back to English. | Descriptions and description images for all eleven, plus copies for Latin American Spanish and European Portuguese. Achievements in every language. Capsules in English, Spanish and Simplified Chinese. |

**In the game.** The language setting defaults to SYSTEM. Under Steam, SYSTEM means the language picked for BLOCKMANIA in
the Steam client (Properties > General > Language). The game reads it with `ISteamApps::GetCurrentGameLanguage`, which
returns Steam's own interface language if the player never picked one for the game. Without Steam, SYSTEM means the
computer's language. A language the player picks in the game's Options wins over both. Steam's language codes map to
the game's languages like this (`BMLoc.STEAM_CODES`):

| Steam API code | Game language | Steam API code | Game language |
|---|---|---|---|
| `english` | English | `polish` | Polski |
| `spanish`, `latam` | Español | `brazilian`, `portuguese` | Português (BR) |
| `french` | Français | `japanese` | 日本語 |
| `italian` | Italiano | `schinese` | 简体中文 |
| `german` | Deutsch | `tchinese` | 繁體中文 |
| `dutch` | Nederlands | anything else | the computer's language, else English |

Saves never contain translated text, so a player can switch languages at any time. The Options menu switches at once,
and changing the language in Steam applies the next time the game starts.

Sources (Steamworks documentation): [Localization and Languages](https://partner.steamgames.com/doc/store/localization),
[Languages Supported on Steam](https://partner.steamgames.com/doc/store/localization/languages) (API codes),
[ISteamApps::GetCurrentGameLanguage](https://partner.steamgames.com/doc/api/ISteamApps),
[Depots](https://partner.steamgames.com/doc/store/application/depots).

---

## 1. Base languages ✋ (App Admin > SteamPipe > Depots)

On the Depots page, in the section for the base game's languages ("Managing base languages"), tick:

- English, French, Italian, German, **Spanish - Spain**, Dutch, Polish, **Portuguese - Brazil**, Japanese,
  **Simplified Chinese**, **Traditional Chinese**.

Leave the three depots (Windows, macOS, Linux) on **All languages**, as in SUBMIT.md A1. Click **Save**, then
publish (App Admin > Publish). The Language dropdown then appears in the game's Properties in the Steam client.

Optional: tick **Spanish - Latin America** and **Portuguese - Portugal** too. The game gives those players its Spanish
and Brazilian Portuguese (Castilian and Brazilian wording, fully understandable). Tick them only if you are happy to
present those as the Latin American and European versions. The store page itself already has text for both.

## 2. Supported languages on the store page ✋ (Store page admin > Basic Info > Languages)

For each of the eleven languages above, tick **Interface** only. Leave **Full Audio** and **Subtitles** unticked for
every language: the game has no spoken dialogue, so there is nothing to dub or subtitle. Ticking them would be a false
claim. Make the same optional choice for Latin American Spanish and European Portuguese as in step 1.

This replaces SUBMIT.md Part D item 5 ("English only"), which predates the localization.

## 3. Store text and images ✋ (Store page admin > Description)

Each text editor has a **language dropdown** at the top right. For every language:

1. Upload **all of `store/steam/images/`** once in the custom images box. The `_english`, `_french`, `_japanese`...
   suffix assigns each file to its language automatically. The screenshots and clips without a suffix are shared.
2. Pick the language in the dropdown, and paste `description_<lang>.txt` into **About This Game** and
   `short_<lang>.txt` into the short description.

| Steam language | Files |
|---|---|
| English | `description_english.txt`, `short_english.txt` |
| Spanish - Spain | `description_spanish.txt`, `short_spanish.txt` |
| Spanish - Latin America | `description_latam.txt`, `short_latam.txt` (copies of Spanish) |
| French | `description_french.txt`, `short_french.txt` |
| Italian | `description_italian.txt`, `short_italian.txt` |
| German | `description_german.txt`, `short_german.txt` |
| Dutch | `description_dutch.txt`, `short_dutch.txt` |
| Polish | `description_polish.txt`, `short_polish.txt` |
| Portuguese - Brazil | `description_brazilian.txt`, `short_brazilian.txt` |
| Portuguese - Portugal | `description_portuguese.txt`, `short_portuguese.txt` (copies of Brazilian) |
| Japanese | `description_japanese.txt`, `short_japanese.txt` |
| Simplified Chinese | `description_schinese.txt`, `short_schinese.txt` |
| Traditional Chinese | `description_tchinese.txt`, `short_tchinese.txt` |

Each description ends its "play your way" list with the eleven languages and the fact that the game follows the
Steam language, so the page states what the build does. Rebuild the images with
`python tools/store/build_store.py text` (all languages; it fails if any text is too wide for its slot or has a
character its font lacks) or `python tools/store/build_store.py` (everything, needs the captures).

**System requirements** (`system_requirements.md`) exist in English, Spanish and Simplified Chinese; the other
languages show the English tab, which is fine. **Capsules** (`capsules/`) exist in English, Spanish and Simplified
Chinese; the other languages show the English capsules. Only the subtitle differs, so this is optional.

## 4. Achievements ✋ (Stats & Achievements > Achievements)

The six Steam achievements have names and descriptions in every language, taken from the game's own texts. Either
upload `achievements/achievements_loc.vdf` in the **Achievement Localization** section (download Steam's file first
and check that its token names match, as `achievements/README.md` explains), or type them in from
`achievements/texts.md`, one language at a time. Rebuild both with `python tools/store/build_achievements.py`.
Then **Publish**.

## 5. Check it before review ✋

1. **The build has every language.** `tools/steam/build_steam.sh` runs the exported game with `-- --lang-report` and
   fails unless it reports `missing=none cjk_fonts=3/3`. By hand:
   `BLOCKMANIA.exe --headless -- --lang-report --no-steam` prints
   `LANG_REPORT current=... loaded=10/10 ok=es,fr,... missing=none cjk_fonts=3/3`.
2. **Steam picks the language.** In the Steam client: right-click BLOCKMANIA > Properties > General > **Language**,
   choose Japanese, start the game. It opens in Japanese, and Options > Game > Language shows SYSTEM, with a tooltip
   saying it follows the language chosen in Steam. Try one Latin language too (e.g. German). With the dropdown back on
   your own language, the game follows it again.
3. **An in-game choice wins.** In Options, pick French, quit and restart: still French, whatever Steam says. Pick
   SYSTEM to follow Steam again.
4. **The store page.** Preview the store page with the Steam client or the website in a couple of languages (Steam's
   language setting) and check the text, images and language table.

## Keeping it true

- New or changed text: `python tools/i18n/extract.py && python tools/i18n/update_po.py`, translate the new entries in
  every `locale/*.po`, `python tools/art/gen_cjk_fonts.py` if Japanese or Chinese text changed,
  `python tools/i18n/check.py`, then the `languages` E2E scenario (`docs/localization.md`).
- The store list, the base languages and `BMLoc.LANGUAGES` must name the same languages. Adding a language means: a
  `locale/<code>.po`, a `LANGUAGES` entry, its Steam code in `STEAM_CODES` (the isolated test
  `test_language_choice` fails if one is missing), `STEAM_LANGS` in `tools/store/build_achievements.py`, `LANGS` and
  `T` in `tools/store/build_store.py`, a store description, and the two Steamworks lists above.
- Removing or leaving a language unfinished: untick it in both Steamworks lists before the build that ships it.
