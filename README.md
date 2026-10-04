# Summon Core

A Ritual of Summoning logger for WoW Forever (12.0 addon API). It records each summon you complete,
credits the target and both assistants, shares the log with other users of the addon, and scores each
summon by destination, then turns the scores into a weekly contest, a season and a story ("Zennit and the Index").
Status: **v0.18.0, work in progress**. See [Status](#status) for what has and has
not been tested in the live client.

## Install

Copy this folder to `World of Warcraft\_classic_beta_\Interface\AddOns\summoncore\` (the folder name must
match `summoncore.toc`). The TOC uses interface `16001`, which matches client 1.60.1 build 70205. If the
addon does not appear, enable "Load out of date AddOns".

Saved data lives in `WTF\Account\<account>\SavedVariables\summoncore.lua` (`SummonTrackerDB`).

## Commands

| Command | What it does |
|---|---|
| `/st` | Open the Summon Core window: Summary, Log, Answer, Tally, Badges, Story, Sync and Tools tabs; Story lists every chapter with a Play button (everything below is in it too) |
| `/st help` | List the commands in chat |
| `/st panel` | Open the window on the Summary tab |
| `/st log [n]` | Recent summons |
| `/st tally` | Cast, received and assisted counts and points per player |
| `/st badges` | Badge list |
| `/st where` | Current map ID, subzone and how it scores |
| `/st undo` | Remove the newest summon you cast (earned badges are kept). Nobody can undo someone else's, and the deletion is shared so sync does not bring it back |
| `/st admin` | What the game reports as this account's BattleTag, and whether it is the admin's or Zennit's |
| `/st reset [all]` | Wipe this client's summons, badges and story (it asks first). `all` is admin only: it asks everyone else to do the same |
| `/st export`, `/st import` | Import / Export window (copy-paste strings of the summon log) |
| `/st sync` | Send a HELLO to party and guild, show sync status |
| `/st synctest` | Run the sync self-test with simulated clients (scratch data only) |
| `/st comic [size]` | Large-image test viewer (generate the textures first, see below) |
| `/st test` | Diagnostics panel; `/st test ping <name>` adds a whisper ping |
| `/st debug` | Toggle detector messages |
| `/st fake <target> [h1 h2]` | Add a test summon (never broadcast) |
| `/st fakeprompt <target> <members...>` | Open the assistants prompt without a party |
| `/st intro [scene\|z1..z5\|g1..g5\|check]` | Play the illustrated story, "Zennit and the Index" (32 scenes); a scene number starts there, a chapter key plays that chapter, `check` tests the sound files |
| `/st week [z1..z5\|g1..g5]` | The weekly contest and the season: this week and last, whether Zennit is on his week off, and the season standing; a key replays that chapter |
| `/st clip [category|file]` | List or play voice clips from `Media/clips` |
| `/st zennit list [add <place>\|remove <n>\|clear]` | Zennit's secret list (this client only, never synced). Toward his week off (draft rules): winning the dice earns him the summon's points, a refusal costs them, and a summon that lands at a place on his list earns them again; refusing a listed place is free. Also editable in the hub's Answer tab |
| `/st respond [test]` | Zennit answers a summon of him (accept, refuse, 50 silver or dice); `test` tries it on a pretend summon |
| `/st gag` | Preview the Zennit gag |
| `/st zenit` | Toggle Zennit test mode on this character |

## How it works

| File | Module | Job |
|---|---|---|
| `Core.lua` | Core | Load order, SavedVariables setup, slash commands |
| `Detector.lua` | Detector | Watches your Ritual of Summoning casts (spell 698), snapshots target, zone and which party or raid members are channeling |
| `Prompt.lua` | Prompt | Asks you to confirm the two assistants when detection is unclear |
| `Store.lua` | Store | The only code that touches `SummonTrackerDB`; tallies are derived from the event log |
| `Sync.lua` | Sync | The only code that touches the network |
| `Scoring.lua` | Scoring | Zone value table, points, badge rules |
| `Respond.lua` | Respond | Zennit's answer to a summon of him (accept, refuse, 50 silver, dice) |
| `Week.lua` | Week | The weekly contest, his week off, and the season; all derived from the log |
| `Reset.lua` | Reset | `/st reset`: wipe this client, and the admin's request to everyone else |
| `Export.lua` | Export | Import / Export window and the string codec |
| `Intro.lua`, `IntroCues.lua`, `Comic.lua` | Intro | The illustrated story player, its generated timings, and the large-image test viewer |
| `Clips.lua`, `ClipList.lua` | Clips | Voice clips from `Media/clips` (`ClipList.lua` is generated) |
| `Hub.lua`, `Gag.lua` | UI | The one-window hub (tabs for the summary, log, answer, tally, badges, story, sync and tools), and the Zennit access-denied gag |
| `Tests.lua`, `SyncTest.lua` | | Live-client diagnostics and the self-test (`/st synctest`, admin only) |

Only the caster's client needs to see a summon; everyone else is credited from the caster's snapshot.

### Assistants

Exactly two group members seen channeling the ritual are credited automatically, in a party or anywhere in a
raid. With any other count, the prompt opens and you tick up to two names (detected helpers first; in a raid
the list stops at 12). Solo or in a two-person party it saves without asking.

### Scoring

Placeholder values, meant to be argued about. Edit the tables at the top of `Scoring.lua`.

| Kind | Points | Matched by |
|---|---|---|
| city | 1 | `mapKinds` (map ID) |
| zone | 3 | default for unlisted maps |
| dungeon | 5 | `subzoneKinds` (lowercase subzone text) |
| remote | 10 | `mapKinds` (ten far-flung zones, such as Silithus and Winterspring) or `subzoneKinds` |

A dungeon entrance sits inside an ordinary outdoor map, so it is matched by subzone. Stand at the spot and
run `/st where` to read the exact string. Points go to the caster only.

Badges: First Summon, Ten Summons, Fifty Summons, Dungeon Doorman, Far Flung, Well Travelled (five
distinct maps).

### Sync

Sync shares events, not totals, so merging is a set union and nothing is double-counted. Messages use the
`SUMMONSYNC` prefix: `H` (hello), `E` (new event, broadcast), `R` (request, whispered), `B` (batch,
whispered, one record each, about 3 per second). Others: `Z` (Zennit's answer), `D` and `S` (the dice),
`T` (a summon its caster deleted), `A` (Zennit's client names the character he is playing, so others learn his
alts) and `X` (a request to reset). AceComm, LibSerialize and LibDeflate are not used; the addon has its own
small encoder and send queue.

A `H` carries the number of summons, the latest summon time, the version, the time of the newest answer from
Zennit, and the last reset time, so a peer notices a missing summon, a changed answer or a missed reset.

Merge rules:
- Same event ID: keep the confirmed copy; if both are (or neither is), keep the earlier write.
- Your own events are authoritative and nobody can add one against you.
- A live `E` is accepted only if the sender is the caster.
- A `B` is accepted only by whisper and only soon after you sent a `R` to that sender (the window renews with
  each batch message, so a long log still arrives whole).
- A deleted summon stays deleted: only its caster can send the `T`, and a copy of it is refused afterwards.
- Anything from before the last reset is refused.
- Of two answers from Zennit for one summon, the later wins.
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

`/st intro` plays "Zennit and the Index": 32 scenes (scenes 1-10 are chapter 1; the rest are the season's chapters, see
[The season](#the-season)) of 3-frame flipbook art (about six flips a second), narrated, with
a quiet synth music bed. The whole narration is typed out, a sentence at a time and in step with the
voice, in a green-on-black terminal box under the picture, with a chirp and key clicks at each sentence. While the narrator mentions something (the three kinds of ritual, the book, the form, Zennit), a pulsing box lights up that part of the picture. The **Text**
button cycles: `full` (that box), `key` (only the punchlines, flashed over the picture) and `off`. Controls: previous/next scene, play/pause, restart, a Size button (small, medium,
large), a Look button
(`lines`: neon line drawing on black, the default; `storybook`: the original colours), and toggles for Sound and Music. `/st intro 3` starts at
scene 3. `/st intro check` tries every intro sound
file and lists the ones the game cannot play (after adding or replacing media, restart WoW: `/reload` does not pick
up new files). The art lives in `Media/intro_l<n>.blp` (lines) and `intro_<n>.blp` (storybook), one per scene: 2048x1024 sheets, DXT1, about 1.3 MB each.
`tools/intro/render_intro.ps1` rebuilds them from `tools/intro/source.html` using headless Edge or Chrome
(`-Format tga` writes uncompressed TGAs instead if BLPs misbehave in your client).

**Rebuilding the pieces** (needs ffmpeg for the audio, Edge or Chrome for the art):

- `tools/intro/render_intro.ps1 [-Style lines|storybook] [-SceneList 1,2]`: the picture sheets (`intro_l<n>.blp` for lines, `intro_<n>.blp` for storybook).
- `tools/intro/build_audio.ps1`: reads the narration takes in `tools/intro/narration/`, synthesises the music bed
  and the beeps, chirps and key clicks (`Media/sfx/`), mixes `Media/intro_<n>.ogg` (voice plus music, which ducks
  under the voice and swells in the pauses) and `Media/intro_<n>_voice.ogg` (voice only), and writes
  `IntroCues.lua` (scene lengths, key phrases, sentence times, and the highlight boxes: edit `$highlightSpec` in that script to change what lights up and when). The key phrases and what they say are listed in that script; each is timed from where its
  sentence sits in the audio (silence detection between sentences) and where the phrase sits in the sentence.
  Nothing is sampled from any existing recording.

Scenes 9 and 10 explain the weekly challenge: the group earns points by place, Zennit holds a secret list, and he may refuse, ask for fifty silver, or suggest dice. They were rendered here from the draft rules and may need rewording once the rules are final.

The narration is `Media/intro_1.ogg` to `intro_32.ogg` (the "rp" voice takes mixed with the music bed; `intro_<n>_voice.ogg` is voice only), one clip per scene, because
`PlaySoundFile` cannot start partway into a file, so pausing and resuming replays the current scene from its
start. Each clip is the length of its scene. The viewer plays them on the Dialog sound channel; the Sound button
mutes the narration.

### Voice clips

Drop `.ogg` takes into `Media/clips/`, named `<category>_<NN>_<who>.ogg`: `wag_01_aaron`, `zenit_land_02_sam`,
`zenit_refuse_03_sam`, `ritual_02_lewis`, `narrator_weekopen_01_lewis`. AddOns cannot list a folder, so run
`powershell -ExecutionPolicy Bypass -File tools\build_clip_manifest.ps1` (it writes `ClipList.lua` and warns about
badly named files), then `/reload`. `/st clip` lists the categories; `/st clip wag` or a file name plays one. The
addon picks a random clip per category and avoids repeating the last one. Plays on the Dialog sound channel.

- `wag`: used for the Zennit gag instead of the built-in sound.
- `zenit_land`: played on Zennit's client when a friend's live summon of him arrives.
- `zenit_refuse`: when Zennit refuses a summon (his client and the summoner's). `zenit_win`: when he wins the dice. `ritual`: as a ritual begins on your client. `narrator_weekopen`: when a finished week is announced.
  Clips are silent until recorded; none are so far.

`Media/clips/*.ogg` is git-ignored on purpose: some lines are meant to surprise Zennit, and the repo is on GitHub. Add
the files to the release zip by hand, or remove that line from `.gitignore` if you do not mind.

### Zennit's answer

When a live summon of Zennit reaches his client, a dialog gives him four choices:

| Choice | What happens to the summon |
|---|---|
| Accept it | Counts. |
| Refuse | Does not count. |
| Demand 50 silver, in cash, no receipt | Does not count until he says it was paid ("They paid"); until then the log shows "owes 50 silver". |
| Suggest dice | He rolls 1-100 (a real `/roll`, so the party sees it); the summoner gets a prompt to roll back; Zennit adds 10 to his roll, higher wins and a tie goes to him. If Zennit wins, the summon does not count. |

His answer is saved on the event, shown in the Log tab ("Zennit's answer"), and sent to everyone (message `Z`). Only his
own client can answer for him, a newer answer replaces an older one (owes, then paid), and the dice use two more
messages (`D`: his roll to the summoner, `S`: the roll back). Points, tallies and badges only count summons that
land. The same choices are in the hub window's **Answer** tab (`/st`, then Answer): the summons waiting for his answer with Previous/Next, the four choices drawn in the window, and a list of the ones he has already answered. `/st respond` reopens the dialog for the latest summon that is still waiting; `/st respond test` (or the
Tools tab's "Test a summoning") tries it on a pretend summon from "Tester", with a pretend summoner rolling back.

Test summons (`/st fake`, the buttons that add them, and `respond test`) are marked and stay on that client: they
are not counted for sync, not sent in batches and not exported.

### Zennit mode

If the logged-in character is in `settings.zenitNames` (default `Zennit`), the panel, tally and badges are
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
`powershell -ExecutionPolicy Bypass -File tools\make_test_patterns.ps1` (about 16 MB in `Media/`). Addon
textures must be `.tga` or `.blp` with power-of-two sides.

## Status

| Area | State |
|---|---|
| Skeleton, diagnostics panel, store, tallies, scoring, badges, panel, Zennit gag | Verified in the live client (solo, with `/st fake`) |
| Sync merge rules and HELLO/REQUEST/BATCH exchange | Verified with simulated clients (`/st synctest`, 23/23 in the live client on 2026-10-04). Tests added since, for answer resync, deletions, resets, closed weeks, Zennit's alts, test summons and raid candidates, have not been run in the live client yet |
| Real Ritual of Summoning detection | Verified in the live client (with Poogs). A target who declines in game and summons by a warlock without the addon are not handled; raid helpers in other subgroups are checked now but not yet tried in a raid |
| Addon messages between two real clients | Verified: party, guild and whisper pings and replies arrive. Names show as `Name Surname` here (not `Name-Realm`), so the addon compares plain first-word names |
| Zennit's answer and the dice between two real clients | Not tested: the `/roll` text parsing, and whether `RandomRoll` is allowed in this client |
| Intro art and sound loading | Not tested after a full restart (`/st intro check`) |
| A real Monday rollover of the week and season, and `/st reset all` reaching friends | Not tested |
| Scoring tables | No place is marked `remote`, so the Far Flung badge cannot be earned yet; the Deadmines entrance subzone string is a guess |
| Gag and voice clips | Not recorded yet; the gag is still the placeholder sheet |
| Release | None published yet (no git tags); clips are git-ignored, so a release zip has none |

Known limits of the 12.0 API: no combat log, party data may be secret, no web requests. Secret values on
other units (`UnitInRange`, `UnitHealth`) were confirmed, so the addon does not rely on them.

## Development

CI (`.github/workflows/ci.yml`) runs luacheck, installed through luarocks, on every push; `.luacheckrc` currently
reports only syntax errors and undefined or accidental globals. There is no Lua on the CI image to run the self-test,
so `/st synctest` is run in the game. Pushing a tag such as `v0.18.0` (it must match `## Version` in the TOC)
runs `release.yml`, which zips the addon (without `tools/`) and publishes a GitHub release. Test textures
from `tools/` are git-ignored, so release zips do not include them and `/st comic` shows green squares there.

## Parked for later

Challenge import strings, emote bonus challenges, Zennit's objective, a notice when a summon is declined in game, and
catching summons by warlocks who do not run the addon (the target's client could use `CONFIRM_SUMMON`).

## The weekly contest (draft rules)

Weeks run Monday to Monday (UTC) and are worked out from the event log, so every client agrees. The group's score is
the points of the summons that landed. Zennit's score starts at **10** (a head start) and gains the summon's points when he
wins the dice or accepts a summon to a place on his list, and loses them on a plain refusal; his dice roll also gets
**+10**. A tie goes to him. If his score is at least the group's at the end of the week, **Zennit wins the week** and the
next seven days are his: summoning him gets a warning, and `/st week victory` (also offered at login) plays chapter 2 of the
story. The rules are tilted his way on purpose, so he wins more weeks than he loses and the story keeps moving. Change
`Week.HEADSTART` and `Respond.EDGE` to tune it.

### The season

The weekly wins add up to a race: the first side (Zennit or the group) to **5 weekly wins** takes the finale, then the
count starts again. It is worked out from the log, so every client agrees. Each win plays its own chapter of the story:
`z1` to `z5` for Zennit's wins and `g1` to `g5` for the group's, so `/st intro z2` or `/st week g3` replays one. A chapter only plays once the season has reached it (the admin can play any).
All ten chapters are written (scenes 11 to 32). Zennit's track ends with him becoming the clerk of the Index,
the group's with Form 27B/6 turning out to be the receipt for the fifty silver, the Ritual getting its closure and Zennit
being freed. `/st week` shows the standing.

### Admin and Zennit's account

The debug tools (`/st test`, `fake`, `fakeprompt`, `comic`, `synctest`, `debug`, `gag`, `zennit` test mode, `respond test`, and the
matching buttons in the window) and every chapter of the story not yet reached by the season are for the admin's Battle.net
account only (`ST.ADMIN_TAG` in `Core.lua`). `/st admin` says whether this account is the admin. Zennit's own account
(`ST.ZENNIT_TAG`) is treated as Zennit whichever character he plays. The check runs on each player's own computer, so it keeps
things out of the way but is not security.

### Tools tab, BattleTags and reset

The Tools tab now has a button for every command that has no tab of its own: week and season, Battle.net check, undo the last
summon, reset, and (admin only) the sync self-test, a test summon, the BattleTag tests and the debug switches.
`/st admin` (or the Battle.net check button) shows the BattleTag the game reports and whether it is the admin's or Zennit's; the
admin's **Run tag tests** button, and the last two lines of `/st synctest`, check the matching with sample tags.

`/st reset` (or **Reset my data...**) wipes this client's summons, badges and, because the season and story are worked out from
the log, the story too. It asks first. The admin's `/st reset all` also asks everyone else running Summon Core, in the party, raid
and guild, to do the same: each of them gets a prompt and nothing changes on their client until they agree. A reset leaves a mark,
and sync refuses anything older than it, so a client that said no cannot put the old log back.

### Closed weeks and Zennit's alts

A week closes two days after it ends. Its winner is then frozen on each client, so a late answer or a late-synced summon cannot
flip a week that has been announced, and Zennit can no longer answer a summon from a closed week. Zennit's alts are learned over
sync: his own client announces the character he is playing, and everyone else scores a summon of any of them as a summon of
Zennit (up to 10 alts are kept).
