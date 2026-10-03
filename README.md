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
| `/st sync` | Send a HELLO to party and guild, show sync status |
| `/st synctest` | Run the sync self-test with simulated clients (scratch data only) |
| `/st test` | Diagnostics panel; `/st test ping <name>` adds a whisper ping |
| `/st debug` | Toggle detector messages |
| `/st fake <target> [h1 h2]` | Add a test summon (never broadcast) |
| `/st fakeprompt <target> <members...>` | Open the assistants prompt without a party |
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

### Zenit mode

If the logged-in character is in `settings.zenitNames` (default `Zenit`), the panel, tally and badges are
hidden and the gag plays instead, and points and badge messages are hidden when he logs a summon. This is
a joke gate for friends, not security: addon files are plain text.

To add clips, put each short `.ogg` and its square power-of-two textures (`.tga` or `.blp`, 256 or 512 px)
in `Media/` and add an entry to `Gag.clips` in `Gag.lua`. With no clips it falls back to a built-in sound
and a placeholder icon. The diagnostics Sound/flip row looks for `Media/test.ogg`.

## Status

| Area | State |
|---|---|
| Skeleton, diagnostics panel, store, tallies, scoring, badges, panel, Zenit gag | Verified in the live client (solo, with `/st fake`) |
| Sync merge rules and HELLO/REQUEST/BATCH exchange | Verified with simulated clients (`/st synctest`, 13/13) |
| Real Ritual of Summoning detection | **Untested.** Spell ID 698, the target field and whether `SUCCEEDED` fires at start or end are assumptions |
| Addon messages between two real clients | **Untested** |
| Deadmines entrance subzone string | A guess |
| Gag clips | Not recorded yet |

Known limits of the 12.0 API: no combat log, party data may be secret, no web requests. Secret values on
other units (`UnitInRange`, `UnitHealth`) were confirmed, so the addon does not rely on them.

## Parked for later

Challenge import strings, emote bonus challenges, Zenit's side (refusing, roll-off, token payment),
Zenit's secret list and objective, weekly reset and scoreboard, and the story layer. The event log leaves
room to add these as new event types without changing stored summon records.
