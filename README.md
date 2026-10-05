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
| `/sc` (also `/summoncore`) | Open the Summon Core window: Party (Summary, Tally and Badges), Zennit (his answers), Log, Story, Sync and Tools tabs; the Party tab is closed to Zennit (he gets the "ah ah ah" gag) and Zennit's tab to the party (a gag of its own; the admin can open both); Story is a talent tree: the intro on top, then one trunk for Zennit and one for the group, a chapter per weekly win, with the next win pulsing, the reached chapters lit (click to play) and the rest hidden until the weekly race reaches them (everything below is in it too) |
| `/sc help` | List the commands in chat |
| `/sc panel` | Open the window on the Party tab |
| `/sc log [n]` | Recent summons |
| `/sc tally` | Cast, received and assisted counts and points per player |
| `/sc badges` | Badge list |
| `/sc where` | Current map ID, subzone and how it scores |
| `/sc undo` | Remove the newest summon you cast (earned badges are kept). Nobody can undo someone else's, and the deletion is shared so sync does not bring it back |
| `/sc admin` | What the game reports as this account's BattleTag, and whether it is the admin's or Zennit's |
| `/sc reset [all]` | Wipe this client's summons, badges and story (it asks first). `all` is admin only: it asks everyone else to do the same |
| `/sc export`, `/sc import` | Import / Export window (copy-paste strings of the summon log) |
| `/sc sync` | Send a HELLO to party and guild, show sync status |
| `/sc synctest` | Run the sync self-test with simulated clients (scratch data only) |
| `/sc comic [size]` | Large-image test viewer (generate the textures first, see below) |
| `/sc test` | Diagnostics panel; `/sc test ping <name>` adds a whisper ping |
| `/sc debug` | Toggle detector messages |
| `/sc fake <target> [h1 h2]` | Add a test summon (never broadcast) |
| `/sc fakeprompt <target> <members...>` | Open the assistants prompt without a party |
| `/sc intro [scene\|z1..z5\|g1..g5\|now\|check]` | Play the illustrated story, "Zennit and the Index" (32 scenes, then "The Index today", which follows the season); a scene number starts there, a chapter key plays that chapter, `now` plays only "The Index today", `check` tests the sound files |
| `/sc report` | What the log says about how the race is being played, for a playtest: summons a week, wins by how many summons counted, his answers and how fast, how he spends his dice, the list's hit rate, the helpers, whether he closes. Paste it into the group chat. Also the Tools tab's **Playtest report**; the script is `design/playtest.md` |
| `/sc rules` | The rules of the race on one card, with this week's live numbers (the cap and the close, his dice and edge with the catch-up and the whim, what a helper adds, his list, the points by place). Also the Tools tab's **The rules** |
| `/sc seasons` | The Index's keepsake of each finished season, newest first: how it ended and how long it took, who was in the room (everyone who summoned him or helped), the silver paid, and a moment or two by name. Also the Tools tab's **Past seasons**, and printed in chat when a finale lands |
| `/sc week [z1..z5\|g1..g5]` | The weekly contest and the season: this week and last, whether Zennit is on his week off, and the season standing; a key replays that chapter |
| `/sc clip [category|file]` | List or play voice clips from `Media/clips` |
| `/sc zennit list [add <place>\|remove <n>\|clear]` | Zennit's secret list (this client only, never synced). Toward his week off (draft rules): winning the dice earns him the summon's points, a refusal costs them, and a summon that lands at a place on his list earns them again; refusing a listed place is free. Also editable in the hub's Zennit tab. The list is bounded: at most **5** places of **4 letters or more** (an entry matches any part of a place's name, so a single letter would match most places and decide every week); older entries that are shorter, or past the fifth, stop counting |
| `/sc respond [test]` | Zennit answers a summon of him (accept, refuse, 50 silver or dice); `test` tries it on a pretend summon |
| `/sc gag` | Preview the Zennit gag |
| `/sc zenit` | Toggle Zennit test mode on this character |
| `/sc party` | Toggle party test mode (admin only): this character acts as an ordinary party member, even on the admin's or Zennit's own account, so Zennit's tab gives the party's gag. It turns Zennit test mode off, and the other way round. Both are also switches on the Tools tab |

## How it works

| File | Module | Job |
|---|---|---|
| `Core.lua` | Core | Load order, SavedVariables setup, slash commands |
| `Detector.lua` | Detector | Watches your Ritual of Summoning casts (spell 698), snapshots target, zone and which party or raid members are channeling |
| `Prompt.lua` | Prompt | Asks you to confirm the two assistants when detection is unclear |
| `Store.lua` | Store | The only code that touches `SummonTrackerDB`; tallies are derived from the event log |
| `Sync.lua` | Sync | The only code that touches the network |
| `Scoring.lua` | Scoring | Zone value table, points, badge rules |
| `Theme.lua` | Theme | The "Neon Index" look: windows, buttons, tabs, text boxes and scroll areas, all drawn from flat colours |
| `Respond.lua` | Respond | Zennit's answer to a summon of him (accept, refuse, 50 silver, dice) |
| `Week.lua` | Week | The weekly contest, his week off, and the season; all derived from the log |
| `Reset.lua` | Reset | `/sc reset`: wipe this client, and the admin's request to everyone else |
| `Export.lua` | Export | Import / Export window and the string codec |
| `Intro.lua`, `IntroCues.lua`, `Comic.lua` | Intro | The illustrated story player, its generated timings, and the large-image test viewer |
| `Voice.lua` | Voice | Pools of lines: the Index says a fact that repeats a few different ways, never the same one twice running |
| `Report.lua` | Report | `/sc report`: the playtest numbers, worked out from the log |
| `Ledger.lua` | Ledger | "The Index today": the intro's last scene, written from the season tree each time it plays; and the log's memory of a season (named moments, the silver, the keepsake) |
| `Clips.lua`, `ClipList.lua` | Clips | Voice clips from `Media/clips` (`ClipList.lua` is generated) |
| `Hub.lua`, `Gag.lua` | UI | The one-window hub (tabs for the party, Zennit, the log, the story, sync and tools), and the Zennit access-denied gag |
| `Tests.lua`, `SyncTest.lua` | | Live-client diagnostics and the self-test (`/sc synctest`, admin only) |

Only the caster's client needs to see a summon; everyone else is credited from the caster's snapshot.

### Look

Every window the players use (the hub, the assistants prompt, Zennit's answer popup, the dice prompt, Import / Export,
and the intro's buttons) is drawn in one style, the "Neon Index": green-on-black terminal panels, cyan for the summoners,
pink for Zennit and amber for his answers. The hub shows the season race (each side's weekly wins out of five, and this
week's score) above every tab, and a command prompt with the log and sync counts along the bottom. `Theme.lua` holds the
colours and the pieces; there is no art to rebuild. The font is VT323 (`Media/fonts/VT323-Regular.ttf`, SIL Open Font
License, `Media/fonts/VT323-OFL.txt`); if the game cannot load it, the standard font is used instead. The admin tools
(Diagnostics, the large-image test) keep the standard Blizzard look.

### Assistants

Exactly two group members seen channeling the ritual are credited automatically, in a party or anywhere in a
raid. With any other count, the prompt opens with the detected helpers ticked (listed first; in a raid the list
stops at 12). It saves itself as ticked after 20 seconds, so you only need to touch it to correct the names;
changing a tick stops the countdown. Solo or in a two-person party it saves without asking.

### Scoring

Placeholder values, meant to be argued about. Edit the tables at the top of `Scoring.lua`.

| Kind | Points | Matched by |
|---|---|---|
| city | 1 | `mapKinds` (map ID) |
| zone | 3 | default for unlisted maps |
| dungeon | 5 | `subzoneKinds` (lowercase subzone text) |
| remote | 10 | `mapKinds` (ten far-flung zones, such as Silithus and Winterspring) or `subzoneKinds` |

A dungeon entrance sits inside an ordinary outdoor map, so it is matched by subzone. Stand at the spot and
run `/sc where` to read the exact string. Points go to the caster only.

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

`/sc export` opens a window with the whole log as a string (compressed and base64-encoded, starting `!ST1!`);
`Export mine` limits it to summons you cast. To import, paste a string, press **Preview** to see how many are
new, would replace an existing copy, are already known or are rejected, then press **Import**. Imports use
the same merge rules as sync, with one difference: because you are doing it yourself, your own events missing
from your log can be restored, but an event you already have is never overwritten. Damaged, truncated or
newer-version strings are refused. This is the manual fallback if addon messages turn out to be restricted.

### Intro

`/sc intro` plays "Zennit and the Index": 32 scenes (scenes 1-10 are chapter 1; the rest are the season's chapters, see
[The season](#the-season)) of 3-frame flipbook art (about six flips a second), narrated, with
a quiet synth music bed. The whole narration is typed out, a sentence at a time and in step with the
voice, in a green-on-black terminal box under the picture, with a chirp and key clicks at each sentence. While the narrator mentions something (the three kinds of ritual, the book, the form, Zennit), a pulsing box lights up that part of the picture. The **Text**
button cycles: `full` (that box), `key` (only the punchlines, flashed over the picture) and `off`. Controls: previous/next scene, play/pause, restart, a Size button (small, medium,
large), a Look button
(`lines`: neon line drawing on black, the default; `storybook`: the original colours), and toggles for Sound and Music. `/sc intro 3` starts at
scene 3. `/sc intro check` tries every intro sound
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

The intro does not end where the recording does. After scene 10 it plays **The Index today** (`Ledger.lua`), a scene
written from the season each time it plays, so the story moves with the tree: who leads the season, how far down each
trunk the race has got (a line for the latest win on each side, and only for chapters already reached, so nothing is
spoiled), a warning when a side is one win from its finale, how the last season ended once there has been one, and how
this week stands (his week off, the Index closed, or the lead and the summons filed). Its picture is the latest chapter
reached, or "The week" before any. It is typed out under the key clicks with no voice, because it is never the same
twice, and it now tells the season's named moments (the roll a helper pair tipped, who has summoned him most, a run of dice he won) and the silver he has been paid, all worked out from the log; `/sc intro now` plays it alone. Tune the wording in `Ledger.lua` (`RECAP`, `LAST_SEASON` and `Ledger.Build`).

Scenes 9 and 10 explain the weekly challenge: only summons of Zennit count (summons between friends count for nothing), the group earns points by place, ten summons a week count, Zennit holds a secret list of five places that pays him too, and he may refuse, ask for fifty silver, suggest dice (three a week, which helpers can lean on), close the Index once five are filed, go on leave when he wins a week (summons of him are then filler), and the Index leans toward the side that is behind, with a whim some weeks. The first to five weeks takes the season. **The wording was brought up to date, but the takes have not been re-rendered yet**: `Intro.lua` and `render_takes.py` have the new text, while `Media/intro_9.ogg` and `intro_10.ogg` (and their `_voice` twins) and `IntroCues.lua` are still the old recording until `.claude/skills/zenit-narrator-audio` has been run for scenes 9 and 10 (`render_takes.py --only 9,10`, copy to `tools/intro/narration/voice_09.ogg` and `voice_10.ogg`, then `tools/intro/build_audio.ps1`), after which WoW needs a full restart.

The narration is `Media/intro_1.ogg` to `intro_32.ogg` (the "rp" voice takes mixed with the music bed; `intro_<n>_voice.ogg` is voice only), one clip per scene, because
`PlaySoundFile` cannot start partway into a file, so pausing and resuming replays the current scene from its
start. Each clip is the length of its scene. The viewer plays them on the Dialog sound channel; the Sound button
mutes the narration.

### Voice clips

Drop `.ogg` takes into `Media/clips/`, named `<category>_<NN>_<who>.ogg`: `wag_01_aaron`, `zenit_land_02_sam`,
`zenit_refuse_03_sam`, `ritual_02_lewis`, `narrator_weekopen_01_lewis`. AddOns cannot list a folder, so run
`powershell -ExecutionPolicy Bypass -File tools\build_clip_manifest.ps1` (it writes `ClipList.lua` and warns about
badly named files), then `/reload`. `/sc clip` lists the categories; `/sc clip wag` or a file name plays one. The
addon picks a random clip per category and avoids repeating the last one. Plays on the Dialog sound channel.

- `wag`: used for the Zennit gag instead of the built-in sound.
- `zenit_land`: played on Zennit's client when a friend's live summon of him arrives.
- `zenit_refuse`: when Zennit refuses a summon (his client and the summoner's). `zenit_win`: when he wins the dice. `ritual`: as a ritual begins on your client. `narrator_weekopen`: when a finished week is announced.
  Clips are silent until recorded; none are so far.

`design/recording-sheet.md` lists lines to record for each category and how to convert and name the takes (it is in the repo, so treat its lines as prompts: Zennit can read them).

The clips are committed with the rest of the addon (and so go into the release zip), which means Zennit can listen to them in the
repo: the lines meant to surprise him will not be a surprise if he looks. Run the manifest script after adding clips and commit
`ClipList.lua` with them.

### Zennit's answer

When a live summon of Zennit reaches his client, a dialog gives him four choices:

| Choice | What happens to the summon |
|---|---|
| Accept it | Counts. |
| Refuse | Does not count. |
| Demand 50 silver, in cash, no receipt | Does not count until he says it was paid ("They paid"); until then the log shows "owes 50 silver". |
| Suggest dice | He rolls 1-100 (a real `/roll`, so the party sees it); the summoner gets a prompt to roll back; Zennit adds 10 to his roll, each of the summoner's helpers (up to two) adds 5 to theirs, higher wins and a tie goes to him. If Zennit wins, the summon does not count. He has 3 dice a week. |

His answer is saved on the event, shown in the Log tab ("Zennit's answer"), and sent to everyone (message `Z`). Only his
own client can answer for him, a newer answer replaces an older one (owes, then paid), and the dice use two more
messages (`D`: his roll to the summoner, `S`: the roll back). Points, tallies and badges only count summons that
land. The same choices are in the hub window's **Answer** tab (`/sc`, then Answer): the summons waiting for his answer with Previous/Next, the four choices drawn in the window, and a list of the ones he has already answered. `/sc respond` reopens the dialog for the latest summon that is still waiting; `/sc respond test` (or the
Tools tab's "Test a summoning") tries it on a pretend summon from "Tester", with a pretend summoner rolling back.

Test summons (`/sc fake`, the buttons that add them, and `respond test`) are marked and stay on that client: they
are not counted for sync, not sent in batches and not exported.

### Zennit mode

If the logged-in character is in `settings.zenitNames` (default `Zennit`), the panel, tally and badges are
hidden and the gag plays instead, and points and badge messages are hidden when he logs a summon. This is
a joke gate for friends, not security: addon files are plain text.

Each clip is a sprite sheet: all frames in one power-of-two texture (`.tga` or `.blp`), played left to right,
top to bottom, plus an optional short `.ogg`. Add an entry to `Gag.clips` in `Gag.lua`:
`{ sheet = { file = ..., cols = 4, rows = 2, frames = 8, fps = 8 }, sound = ... }`. One is picked at random
each time (add `duration = <seconds>` to keep a clip up as long as its recording). The bundled sheet, `Media/gag_wag_sheet.tga` (1024x512, 8 frames of 256), is a neon line-art cartoon man wagging his finger with "AH AH AH!" beside him, in the addon's look (an original drawing), made by
`tools/make_gag_sheet.ps1`; replace it with your friends' frames. Zennit's gag plays `Media/gag_zennit.ogg`, a recording of his voice line (normalised, trimmed and converted from `tools/gag/gag_zennit_source.m4a` with ffmpeg: highpass 80 Hz, loudnorm, limiter, mono Ogg Vorbis); the party's gag on his tab uses the same animation without the recording. The diagnostics Sound/flip row looks for `Media/test.ogg`.

### Large images

`/sc comic` shows generated test textures at 256 to 2048 px, at several on-screen sizes or tiled 2x2, and
reports texels per screen pixel. The textures are git-ignored; create them with
`powershell -ExecutionPolicy Bypass -File tools\make_test_patterns.ps1` (about 16 MB in `Media/`). Addon
textures must be `.tga` or `.blp` with power-of-two sides.

## Status

| Area | State |
|---|---|
| Skeleton, diagnostics panel, store, tallies, scoring, badges, panel, Zennit gag | Verified in the live client (solo, with `/sc fake`) |
| Sync merge rules and HELLO/REQUEST/BATCH exchange | Verified with simulated clients (`/sc synctest`, 23/23 in the live client on 2026-10-04). Tests added since, for answer resync, deletions, resets, closed weeks, Zennit's alts, test summons and raid candidates, have not been run in the live client yet |
| Real Ritual of Summoning detection | Verified in the live client (with Poogs). A target who declines in game and summons by a warlock without the addon are not handled; raid helpers in other subgroups are checked now but not yet tried in a raid |
| Addon messages between two real clients | Verified: party, guild and whisper pings and replies arrive. Names show as `Name Surname` here (not `Name-Realm`), so the addon compares plain first-word names |
| Zennit's answer and the dice between two real clients | Not tested: the `/roll` text parsing, and whether `RandomRoll` is allowed in this client |
| Intro art and sound loading | Not tested after a full restart (`/sc intro check`) |
| A real Monday rollover of the week and season, and `/sc reset all` reaching friends | Not tested |
| Scoring tables | Ten far-flung places are marked `remote` from memory (Silithus, Winterspring and so on) and the dungeon entrance subzone strings are guesses; confirm each with `/sc where` |
| Gag and voice clips | Not recorded yet; the gag is still the placeholder sheet |
| Release | None published yet (no git tags); a release zip carries whatever clips are committed |

Known limits of the 12.0 API: no combat log, party data may be secret, no web requests. Secret values on
other units (`UnitInRange`, `UnitHealth`) were confirmed, so the addon does not rely on them.

## Development

CI (`.github/workflows/ci.yml`) runs luacheck, installed through luarocks, on every push; `.luacheckrc` currently
reports only syntax errors and undefined or accidental globals. There is no Lua on the CI image to run the self-test,
so `/sc synctest` is run in the game. Pushing a tag such as `v0.18.0` (it must match `## Version` in the TOC)
runs `release.yml`, which zips the addon (without `tools/`) and publishes a GitHub release. Test textures
from `tools/` are git-ignored, so release zips do not include them and `/sc comic` shows green squares there.

## Parked for later

Challenge import strings, emote bonus challenges, Zennit's objective, a notice when a summon is declined in game, and
catching summons by warlocks who do not run the addon (the target's client could use `CONFIRM_SUMMON`).

## The weekly contest

Weeks run Monday to Monday (UTC) and are worked out from the event log, so every client agrees. If Zennit's score is at
least the group's at the end of the week, **Zennit wins the week** and the next seven days are his: summoning him gets a
warning, and `/sc week victory` (also offered at login) plays chapter 2 of the story.

From the week of **Monday 5 October 2026** the group has to beat Zennit at his own answers (the reasoning, with the
numbers behind it, is in `design/lenses.md`):

- **Only summons of Zennit count**, up to **10** of them each week. Any after that are logged as usual but "filed under
  'enthusiasm'": the race ignores them. Summons of each other still count for the tally and badges.
- **The Index keeps the season close.** Zennit's edge on the dice (the +10) moves with the season's lead, worked out from
  the weeks before the current one. At a lead of two weekly wins it is **+5** for the side behind: his edge shrinks when
  he is ahead (to +5), and grows when the group is ahead (to +15). At three or more it moves by **10** (to +0, or +20);
  a lead of one changes nothing. The briefing, the "Week:" line, his popup, the dice prompts and "The Index today" say
  so ("The Index, which takes no sides, has cut his edge on the dice to +5 this week"). Tune it in `Week.RULES.catchup`.
- **A whim of the week.** About half the weeks, the Index draws one small twist, the same on every client (it follows from the week
  number, so nothing is synced or kept): **The Index is distracted** (his dice edge is 5 lower), **attentive** (5 higher), **a
  helpers' feast** (each helper adds +8 instead of +5) or **the helpers are tired** (+2). Each moves a normal week's chance by
  about 5 or 6 points, so no week is much easier than another, and the group can plan around it. It is said at login, in the
  briefing as a ritual on Zennit begins, in "The Index today" and in `/sc week`; never in a week off. `Week.RULES.whims = false`
  turns it off, and `Week.WHIMS` and the deck in `Week.lua` are where to add more.
- **His week off is real.** After a week Zennit wins, the next week is his: summons of him are still logged, answered and
  gagged as usual (the warnings, his popup, the dice), but they are filed as **filler**: the race ignores them, nobody
  wins the week, and no chapter is unlocked. So a win for Zennit is a pause for the group, not a head start; the week
  after it is a normal one. His leave ends with a line at login.
- **Zennit can close the Index** for the rest of the week once **5** have been filed and the latest of them answered:
  a "Close the Index" button after his answer, and in the hub's Zennit tab. It is free, and it travels with his answer,
  so every client agrees. Summons after that are filed under 'enthusiasm', and their casters are told.
- The group's score is the points of those summons that landed. Zennit's starts at **2** (a head start), gains the
  summon's points when he wins the dice or accepts a summon to a place on his list, and loses them on a plain refusal.
- **Zennit has 3 dice a week.** When they are gone he has to accept, refuse or ask for the silver. His roll gets **+10**;
  each helper on the summon (up to two) adds **+5** to the summoner's roll; a tie goes to him.
- **Where the week stands is shown when it changes**, not only in the hub:
  - as a ritual on Zennit begins, the caster is told whether it will count, who leads, his dice left and what helpers add;
  - after each summon of him and each of his answers, a chat line: "Week: the group leads by 1, 4 of 10 filed, 1 die left.";
  - his answer popup says the same, worded for him ("you lead by 2"), and reminds him that ignoring a summon
    counts as accepting it;
  - when the helpers' bonus is what beat him on the dice, the line names them ("Al and Cy's +10 tipped it.");
  - lines that repeat (his answers, "Summon logged", "Week:", the last die, the week's result) come in three variants with the same facts;
  - a place on his list that comes up again is noticed ("Darnassus again. The Index is beginning to see a pattern."), never the first time, so the list keeps its secret until it hits;
  - when his third die is spent, everyone is told that every summon from there is certain ("That was Zennit's last die this week…");
  - the hub's season band shows the lead (`WEEK: GROUP +1 · FILED 4/10 · DICE 1`, or `CLOSED`).

Earlier weeks keep the rules they were played under (his head start of 10, a week off that was only a warning, every landed summon counting for the group,
unlimited dice), so the season and the chapters already reached do not change. Tune the race in `Week.RULES`
(head start, the minimum before he can close and the limit, dice, helper bonus, the catch-up steps, and the week it starts) and `Respond.EDGE`. Scenes 9 and 10 of the intro
narrate these rules; if they change, re-voice those two scenes (`.claude/skills/zenit-narrator-audio`).

### The season

The weekly wins add up to a race: the first side (Zennit or the group) to **5 weekly wins** takes the finale, then the
count starts again. It is worked out from the log, so every client agrees. Each win plays its own chapter of the story:
`z1` to `z5` for Zennit's wins and `g1` to `g5` for the group's, so `/sc intro z2` or `/sc week g3` replays one. A chapter only plays once the season has reached it (the admin can play any).
All ten chapters are written (scenes 11 to 32). Zennit's track ends with him becoming the clerk of the Index,
the group's with Form 27B/6 turning out to be the receipt for the fifty silver, the Ritual getting its closure and Zennit
being freed. `/sc week` shows the standing.

### Admin and Zennit's account

The debug tools (`/sc test`, `fake`, `fakeprompt`, `comic`, `synctest`, `debug`, `gag`, `zennit` test mode, `respond test`, and the
matching buttons in the window) and every chapter of the story not yet reached by the season are for the admin's Battle.net
account only (`ST.ADMIN_TAG` in `Core.lua`). `/sc admin` says whether this account is the admin. Zennit's own account
(`ST.ZENNIT_TAG`) is treated as Zennit whichever character he plays. The check runs on each player's own computer, so it keeps
things out of the way but is not security.

### Tools tab, BattleTags and reset

The Tools tab now has a button for every command that has no tab of its own: week and season, Battle.net check, undo the last
summon, reset, and (admin only) the sync self-test, a test summon, the BattleTag tests and the debug switches.
`/sc admin` (or the Battle.net check button) shows the BattleTag the game reports and whether it is the admin's or Zennit's; the
admin's **Run tag tests** button, and the last two lines of `/sc synctest`, check the matching with sample tags.

`/sc reset` (or **Reset my data...**) wipes this client's summons, badges and, because the season and story are worked out from
the log, the story too. It asks first. The admin's `/sc reset all` also asks everyone else running Summon Core, in the party, raid
and guild, to do the same: each of them gets a prompt and nothing changes on their client until they agree. A reset leaves a mark,
and sync refuses anything older than it, so a client that said no cannot put the old log back.

### Closed weeks and Zennit's alts

A week closes two days after it ends. Its winner is then frozen on each client, so a late answer or a late-synced summon cannot
flip a week that has been announced, and Zennit can no longer answer a summon from a closed week. Zennit's alts are learned over
sync: his own client announces the character he is playing, and everyone else scores a summon of any of them as a summon of
Zennit (up to 10 alts are kept).
