# Summon Core

A Ritual of Summoning logger for WoW Forever (12.0 addon API). It records each summon you complete,
credits the target and both assistants, shares the log with other users of the addon, and scores each
summon by destination. Status: **v0.4.0, work in progress**. See [Status](#status) for what has and has
not been tested in the live client.

## Install

Copy this folder to `World of Warcraft\_classic_beta_\Interface\AddOns\summoncore\` (the folder name must
match `summoncore.toc`). The TOC uses interface `16001`, which matches client 1.60.1 build 70205. If the
addon does not appear, enable "Load out of date AddOns".

Saved data lives in `WTF\Account\<account>\SavedVariables\summoncore.lua` (`SummonTrackerDB`).

## Commands

| Command | What it does |
|---|---|
| `/st` | List commands |
| `/st panel` | Tally and badge window |
| `/st log [n]` | Recent summons |
| `/st tally` | Cast, received and assisted counts and points per player |
| `/st badges` | Badge list |
| `/st where` | Current map ID, subzone and how it scores |
| `/st undo` | Remove the latest summon (earned badges are kept) |
| `/st export`, `/st import` | Import / Export window (copy-paste strings of the summon log) |
| `/st sync` | Send a HELLO to party and guild, show sync status |
| `/st synctest` | Run the sync self-test with simulated clients (scratch data only) |
| `/st comic [size]` | Large-image test viewer (generate the textures first, see below) |
| `/st test` | Diagnostics panel; `/st test ping <name>` adds a whisper ping |
| `/st debug` | Toggle detector messages |
| `/st fake <target> [h1 h2]` | Add a test summon (never broadcast) |
| `/st fakeprompt <target> <members...>` | Open the assistants prompt without a party |
| `/st intro [scene]` | Play the illustrated intro, "Zenit and the Index" |
| `/st clip [category|file]` | List or play voice clips from `Media/clips` |
| `/st gag` | Preview the Zenit gag |
| `/st zenit` | Toggle Zenit test mode on this character |

## How it works

| File | Module | Job |
|---|---|---|
| `Core.lua` | Core | Load order, SavedVariables setup, slash commands |
| `Detector.lua` | Detector | Watches your Ritual of Summoning casts (spell 698), snapshots target, zone and which party members are channeling |
| `Prompt.lua` | Prompt | Asks you to confirm the two assistants when detection is unclear |
| `Store.lua` | Store | The only code that touches `SummonTrackerDB`; tallies are derived from the event log |
| `Sync.lua` | Sync | The only code that touches the network |
| `Scoring.lua` | Scoring | Zone value table, points, badge rules |
| `UI.lua`, `Gag.lua` | UI | Panel, and the Zenit access-denied gag |
| `Tests.lua`, `SyncTest.lua` | | Live-client diagnostics and the sync self-test |

Only the caster's client needs to see a summon; everyone else is credited from the caster's snapshot.

### Assistants

Exactly two party members seen channeling the ritual are credited automatically. With any other count,
the prompt opens and you tick up to two names. Solo or in a two-person party it saves without asking.

### Scoring

Placeholder values, meant to be argued about. Edit the tables at the top of `Scoring.lua`.

| Kind | Points | Matched by |
|---|---|---|
| city | 1 | `mapKinds` (map ID) |
| zone | 3 | default for unlisted maps |
| dungeon | 5 | `subzoneKinds` (lowercase subzone text) |
| remote | 10 | `mapKinds` or `subzoneKinds` |

A dungeon entrance sits inside an ordinary outdoor map, so it is matched by subzone. Stand at the spot and
run `/st where` to read the exact string. Points go to the caster only.

Badges: First Summon, Ten Summons, Fifty Summons, Dungeon Doorman, Far Flung, Well Travelled (five
distinct maps).

### Sync

Sync shares events, not totals, so merging is a set union and nothing is double-counted. Messages use the
`SUMMONSYNC` prefix: `H` (hello), `E` (new event, broadcast), `R` (request, whispered), `B` (batch,
whispered, one record each, about 3 per second). AceComm, LibSerialize and LibDeflate are not used; the
addon has its own small encoder and send queue.

Merge rules:
- Same event ID: keep the confirmed copy; if both are (or neither is), keep the earlier write.
- Your own events are authoritative and nobody can add one against you.
- A live `E` is accepted only if the sender is the caster.
- A `B` is accepted only by whisper and only soon after you sent a `R` to that sender.
- Points and kind are recomputed locally, never read from the wire.
- Messages from a newer protocol major version are ignored.

### Export and import

`/st export` opens a window with the whole log as a string (compressed and base64-encoded, starting `!ST1!`);
`Export mine` limits it to summons you cast. To import, paste a string, press **Preview** to see how many are
new, would replace an existing copy, are already known or are rejected, then press **Import**. Imports use
the same merge rules as sync, with one difference: because you are doing it yourself, your own events missing
from your log can be restored, but an event you already have is never overwritten. Damaged, truncated or
newer-version strings are refused. This is the manual fallback if addon messages turn out to be restricted.

### Intro

`/st intro` plays "Zenit and the Index": 8 scenes of 3-frame flipbook art (about six flips a second) with the
narration as captions, about 2:22 in all. Controls: previous/next scene, play/pause, restart. `/st intro 3` starts at
scene 3. The art lives in `Media/intro_1.blp` to `intro_8.blp` (2048x1024 sheets, DXT1, about 1.3 MB each);
`tools/intro/render_intro.ps1` rebuilds them from `tools/intro/source.html` using headless Edge or Chrome
(`-Format tga` writes uncompressed TGAs instead if BLPs misbehave in your client).

The narration is `Media/intro_1.ogg` to `intro_8.ogg` (the "George" takes), one clip per scene, because
`PlaySoundFile` cannot start partway into a file, so pausing and resuming replays the current scene from its
start. Each clip is the length of its scene. The viewer plays them on the Dialog sound channel; the Sound button
mutes the narration.

### Voice clips

Drop `.ogg` takes into `Media/clips/`, named `<category>_<NN>_<who>.ogg`: `wag_01_aaron`, `zenit_land_02_sam`,
`zenit_refuse_03_sam`, `ritual_02_lewis`, `narrator_weekopen_01_lewis`. AddOns cannot list a folder, so run
`powershell -ExecutionPolicy Bypass -File toolsuild_clip_manifest.ps1` (it writes `ClipList.lua` and warns about
badly named files), then `/reload`. `/st clip` lists the categories; `/st clip wag` or a file name plays one. The
addon picks a random clip per category and avoids repeating the last one. Plays on the Dialog sound channel.

- `wag`: used for the Zenit gag instead of the built-in sound.
- `zenit_land`: played on Zenit's client when a friend's live summon of him arrives.
- Other categories (refuse, win, ritual, narrator stings) are loaded and playable with `/st clip` now; they will be
  wired in with the challenge and weekly features.

`Media/clips/*.ogg` is git-ignored on purpose: some lines are meant to surprise Zenit, and the repo is on GitHub. Add
the files to the release zip by hand, or remove that line from `.gitignore` if you do not mind.

### Zenit mode

If the logged-in character is in `settings.zenitNames` (default `Zenit`), the panel, tally and badges are
hidden and the gag plays instead, and points and badge messages are hidden when he logs a summon. This is
a joke gate for friends, not security: addon files are plain text.

Each clip is a sprite sheet: all frames in one power-of-two texture (`.tga` or `.blp`), played left to right,
top to bottom, plus an optional short `.ogg`. Add an entry to `Gag.clips` in `Gag.lua`:
`{ sheet = { file = ..., cols = 4, rows = 2, frames = 8, fps = 8 }, sound = ... }`. One is picked at random
each time. The bundled placeholder, `Media/gag_wag_sheet.tga` (1024x512, 8 frames of 256), is made by
`tools/make_gag_sheet.ps1`; replace it with your friends' frames. The diagnostics Sound/flip row looks for `Media/test.ogg`.

### Large images

`/st comic` shows generated test textures at 256 to 2048 px, at several on-screen sizes or tiled 2x2, and
reports texels per screen pixel. The textures are git-ignored; create them with
`powershell -ExecutionPolicy Bypass -File toolsmake_test_patterns.ps1` (about 16 MB in `Media/`). Addon
textures must be `.tga` or `.blp` with power-of-two sides.

## Status

| Area | State |
|---|---|
| Skeleton, diagnostics panel, store, tallies, scoring, badges, panel, Zenit gag | Verified in the live client (solo, with `/st fake`) |
| Sync merge rules and HELLO/REQUEST/BATCH exchange | Verified with simulated clients (`/st synctest`, 13/13; the 7 export, import and clip tests added since are unrun) |
| Real Ritual of Summoning detection | **Untested.** Spell ID 698, the target field and whether `SUCCEEDED` fires at start or end are assumptions |
| Addon messages between two real clients | **Untested** |
| Deadmines entrance subzone string | A guess |
| Gag clips | Not recorded yet |

Known limits of the 12.0 API: no combat log, party data may be secret, no web requests. Secret values on
other units (`UnitInRange`, `UnitHealth`) were confirmed, so the addon does not rely on them.

## Development

CI (`.github/workflows/ci.yml`) runs luacheck on every push; `.luacheckrc` currently reports only syntax errors
and undefined or accidental globals. Pushing a tag such as `v0.7.0` (it must match `## Version` in the TOC)
runs `release.yml`, which zips the addon (without `tools/`) and publishes a GitHub release. Test textures
from `tools/` are git-ignored, so release zips do not include them and `/st comic` shows green squares there.

## Parked for later

Challenge import strings, emote bonus challenges, Zenit's side (refusing, roll-off, token payment),
Zenit's secret list and objective, weekly reset and scoreboard, and the story layer. The event log leaves
room to add these as new event types without changing stored summon records.
