# Uploading BLOCKMANIA to Steam and submitting it for review

App **5328810**. Every step, in order. Items marked ✋ need your Steam login or a click in Steamworks. Everything
else is already done in the repository.

What exists already:

| Piece | Where |
|---|---|
| Windows / macOS / Linux builds with GodotSteam | `tools/steam/build_steam.sh` → `build/steam/content/{windows,macos,linux}` |
| SteamPipe upload (scripts generated, SteamCMD run) | `tools/steam/upload_steam.sh`, GitHub workflow **Steam upload** (`.github/workflows/steam.yml`) |
| System requirements | `store/steam/system_requirements.md` |
| Capsules, background, screenshots, description, clips | `store/steam/capsules/`, `store/steam/screenshots/`, `store/steam/README.md` |
| Achievements | `store/steam/achievements/README.md` |

---

## Part A. One-time Steamworks setup

### A1. Depots ✋ (Steamworks > App Admin > SteamPipe > Depots)

The app came with one depot, **5328811**. Add two more, so there is one per OS:

| Depot ID | Name | Settings: Operating system | Architecture | Language |
|---|---|---|---|---|
| 5328811 | BLOCKMANIA Windows | Windows | 64-bit only | All languages |
| 5328812 | BLOCKMANIA macOS | macOS | (any) | All languages |
| 5328813 | BLOCKMANIA Linux | Linux + SteamOS | 64-bit only | All languages |

If Steam gives different ids, set them as GitHub repository **variables** (Settings > Secrets and variables > Actions >
**Variables**: `DEPOT_WINDOWS`, `DEPOT_MACOS`, `DEPOT_LINUX`), or pass them locally: `DEPOT_MACOS=... tools/steam/upload_steam.sh`.
Click **Save**, then **Publish** (A4): an unpublished depot makes the upload fail with "Access Denied".

On the same page, set the **base languages** to the eleven the game ships (English, French, Italian, German,
Spanish - Spain, Dutch, Polish, Portuguese - Brazil, Japanese, Simplified Chinese, Traditional Chinese). That list
fills the Language dropdown in the game's Properties in the Steam client, and the game follows it. Details and the
optional Latin American / European Portuguese entries: [LANGUAGES.md](LANGUAGES.md) step 1.

### A2. Launch options ✋ (App Admin > Installation > General Installation)

- **Install folder**: `BLOCKMANIA`
- **Launch options**, one per OS (**Add new launch option**):

| Executable | Operating system | CPU architecture | Launch type |
|---|---|---|---|
| `BLOCKMANIA.exe` | Windows | 64-bit only | Launch (default) |
| `BLOCKMANIA.app` | macOS | (any) | Launch (default) |
| `BLOCKMANIA.x86_64` | Linux + SteamOS | 64-bit only | Launch (default) |

No arguments, no working directory. Do not add redistributables: the builds are self-contained.

### A3. Achievements ✋

Follow `store/steam/achievements/README.md` (six achievements, icons and translations).

### A3b. Steam Cloud ✋ (App Admin > Application > Steam Cloud)

The game needs no code for this: **Steam Auto-Cloud** copies the save files before launch and after quit. Godot keeps
them in `user://`, which is `Godot/app_userdata/BLOCKMANIA` under the OS data folder (`%APPDATA%` on Windows,
`~/Library/Application Support` on macOS, `~/.local/share` with a lowercase `godot` on Linux and Steam Deck).

1. **Byte quota per user**: `10000000` (10 MB). **Number of files allowed per user**: `20`. Save.
2. **Enable Steam Auto-Cloud**, then add one **Root Path** row per file below. Root `WinAppDataRoaming`,
   Subdirectory `Godot/app_userdata/BLOCKMANIA`, OS **All OSes**, **Recursive unticked**:

| Pattern | Holds |
|---|---|
| `run.json` | The run in progress (written complete, never half a placement) |
| `settings.cfg` | Options, tips and tutorial seen |
| `profile.cfg` | Kit unlocks and progress |
| `history.json` | Past runs |
| `achievements.cfg` | Unlocks, lifetime stats, records |
| `endless.json` | The Endless run in progress |
| `endless_scores.json` | Endless top ten |

   Do not use `*`: the same folder holds `logs/`, `shader_cache/` and the `*.tmp` files of a save in progress.
3. **Root Overrides** (Add Root Override twice):

| Original root | OS | New root | Add/Replace path | Replace path |
|---|---|---|---|---|
| `WinAppDataRoaming` | macOS | `MacAppSupport` | `Godot/app_userdata/BLOCKMANIA` | ticked |
| `WinAppDataRoaming` | Linux + SteamOS | `LinuxXdgDataHome` | `godot/app_userdata/BLOCKMANIA` | ticked |

4. Save, then publish (A4). Test: play a few placements on one machine, quit, and check the Steam client's
   **Properties > General > Steam Cloud** shows it in sync; on a second machine (or after deleting the local folder)
   the run resumes where you left it.

Then tick **Steam Cloud** in the store page's supported features (Part D).

### A4. Publish the setup ✋ (App Admin > Publish)

**Prepare for publishing**, then **Publish to Steam**. Depots, launch options, achievements and Steam Cloud only take effect after this.

### A5. A build account (recommended) ✋

Valve recommends a separate Steam account that only uploads builds, so your main login never goes to a script or
CI. In Steamworks > Users & Permissions, invite that account to your partner group, give it access to app 5328810,
and grant it the permission to **edit app metadata** and **publish app changes to Steam** (these are needed to upload builds). You can also use your own
account; the steps are the same.

---

## Part B. Build and upload

**Why not upload everything from Windows?** Windows does not store the Unix "executable" permission, so a macOS or Linux build
uploaded from Windows can fail to start on those systems. The **GitHub workflow builds on Linux** and keeps those permissions.
That is the recommended path. The local Windows path (B3) is fine for the Windows depot, or once you have a Mac or Linux machine.

### B1. Log in to SteamCMD once, on your PC ✋

SteamCMD is already unpacked in `build/steamcmd/`. In a terminal at the project folder:

```bash
build/steamcmd/steamcmd.exe +login YOUR_BUILD_ACCOUNT +quit
```

The first run updates SteamCMD itself (a minute or two). Type the password and the Steam Guard code when asked. This saves a login token in
`build/steamcmd/config/config.vdf`. Never commit or share that file: it works like a password.

### B2. Upload with GitHub Actions (recommended) ✋

1. Encode the login file (Git Bash, from the project folder):

   ```bash
   base64 -w0 build/steamcmd/config/config.vdf > build/steam/config_vdf.b64
   ```

2. GitHub > the repository > **Settings > Secrets and variables > Actions > New repository secret**:
   - `STEAM_USERNAME`: the build account name.
   - `STEAM_CONFIG_VDF`: the contents of `build/steam/config_vdf.b64`. Then delete that file.
3. **Actions > Steam upload > Run workflow** on `main`. Leave *branch* empty and give an optional description.
   It installs Godot 4.7.2, the export templates and GodotSteam, builds the three depots, and uploads them.
4. If the log says Steam Guard is needed again, the saved login has expired: repeat B1 and update the secret.

### B3. Or upload from this PC

```bash
GODOT="C:/Users/mario/Downloads/Godot_v4.7.2-stable_win64_console.exe" tools/steam/build_steam.sh
STEAM_USER=YOUR_BUILD_ACCOUNT tools/steam/upload_steam.sh
```

`PREVIEW=1` in front of the second line checks everything without uploading. Only the Windows depot is safe this way;
see the note at the top of Part B.

### B4. Set the build live ✋ (App Admin > SteamPipe > Builds)

The new build appears at the top with its description (for example "BLOCKMANIA 0.1.0 (abc1234)").
In **Set build live on branch**, choose **default**, click **Preview Change**, then **Set Build Live Now**.
Before release, the default branch is only available to your team and to people with keys, so this does not make the game public.

---

## Part C. Test before submitting ✋

1. In the Steam client, the game appears in your Library (you own it as the developer). **Install** and **Play**.
2. Check on Windows, and on a Mac and a Linux machine or a Steam Deck if you can borrow one: the game starts, a run
   plays, it quits and resumes, and the Steam overlay opens with Shift+Tab.
3. Achievements: clear a row and a column with one placement, and **Crossroads** should pop in the Steam overlay.
   Afterwards, reset your test unlocks in Steamworks (Stats & Achievements > the achievement > reset for a user), or run in the dev build
   `Steam.clearAchievement("ACH_CROSSROADS")`.
4. Controller: Valve checks what the store page claims. The page must **not** claim controller support.
5. Languages: in the game's Properties > General > **Language**, pick Japanese and start the game (it opens in
   Japanese), then one Latin language. Full checklist: [LANGUAGES.md](LANGUAGES.md) step 5.

---

## Part D. Store page ✋ (Store page admin)

1. **Description**: `store/steam/README.md` (About, short description, custom images and clips) and
   [LANGUAGES.md](LANGUAGES.md) step 3: text and images for all eleven languages.
2. **Graphical assets**: the capsules and background in `store/steam/capsules/`, the library assets in `store/steam/library/`, screenshots in `store/steam/screenshots/`.
3. **Trailer**: upload `tools/trailer/build/BLOCKMANIA_trailer.mp4`.
4. **System requirements**: `store/steam/system_requirements.md`, one tab per OS, for English, Spanish and
   Simplified Chinese.
5. **Supported languages**: **Interface** for the eleven languages, no Full Audio, no Subtitles (the game has no
   spoken dialogue). See [LANGUAGES.md](LANGUAGES.md) step 2.
6. **Supported features**: Single-player, **Steam Achievements**, **Steam Cloud** (once A3b is published). Leave
   controller support, Remote Play and Trading Cards unticked (none is implemented).
   **Controller support description** (checklist item): answer that the game has **no controller support**. Every
   controller family (Xbox, PlayStation, Nintendo/other) = **not supported**, and do not say it uses the Steam Input API.
   The game is played with mouse (keyboard works for menus, board and shop). Optional, for Steam Deck players:
   App Admin > Application > Steam Input, default configuration **Keyboard (WASD) and Mouse**; this does not claim
   controller support.
7. **Content survey** (age ratings, IARC): answer it. The game has no violence, gambling with real money, or user
   content. Jokers and Credits are fictional game items, and nothing is bought with real money.
8. **Release date**: the page must be public as **Coming Soon** for at least two weeks before release.

## Part E. Submit for review ✋ (App Admin > Release checklist, or "View checklist" at the top)

1. Complete every item of the **Store page** checklist, then **Submit for review**. This takes about 3–5 business days.
2. Complete the **Game build** checklist (depots, launch options and a build live on default all come from Parts A and B), then
   **Submit for review**. This also takes about 3–5 business days; Valve suggests planning for 7.
3. Reviewers check that the game **starts on every OS you list**, and that everything the store page claims (achievements,
   languages, features) exists. If they reject it, the email says why. Fix it, upload a new build (Part B), and resubmit.
4. After both are approved, choose **Release** once the Coming Soon period has run. Updates after that need no review:
   upload and set live (Part B).

## Before you submit: decide

- The title screen still says **"prototype build"** in the footer (`game/ui/title_screen.gd`), and the version is `0.1.0`.
  Change them if this is the build you want players to see.
- Early Access or full release: the store text describes the current content. If you choose Early Access, fill in the Early Access
  questions on the store page.
