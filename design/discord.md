# Discord: the Index's noticeboard (parked)

Researched on 5 October 2026; nothing is built. The question was whether Summon Core could reach into the group's Discord. It can,
but only after the fact: as a noticeboard the Index keeps, not a live feed. This page is the plan, what running code showed, and what
the group has to decide first. Stage 0 below is a fix the playtest needs now; the rest is parked until the first week's playtest
report (`design/playtest.md`) and the group agrees, Zennit above all.

## What is possible

The game cannot reach the internet: the 12.0 addon API has no web requests (README.md, Status). Data leaves it two ways, and both
need a person or a program outside the game:

| Way out | How | When it is fresh |
|---|---|---|
| A copy window | A text box the player selects and copies (Ctrl+C) | Whenever someone copies |
| The saved variables | The addon's file under `WTF/Account/<account>/SavedVariables/`, read by a program on that PC | Only after `/reload`, logout, quitting or a disconnect; never mid-session, and not after a crash (from the wiki; not yet confirmed on Forever) |

So Discord can hear about a week, never about a summons as it happens. Side channels that get closer to live do exist on Forever (an
addon drawing a strip of coloured pixels for a screenshot reader, or padding the chat log until the client flushes it), but they are
fragile and run against Blizzard's stance on out-of-game overlays (the 10.2 combat log change). Not for this.

What running the addon's own code outside the game showed. The prototypes were scratch work and were not kept, so a builder starts
from this page; the self-tests under each stage are the checks to rebuild.

- **An outside program can read the export string.** Two decoders written apart from the addon (Python and Node) matched
  `Codec.Unpack` byte for byte on five export strings, and `Sync.Decode` field for field on all 1,265 records in them. They refused
  28 tampered and cut strings with the same verdict as the addon.
- **The addon's own Lua runs outside WoW** (Lua 5.1, with about ten stand-ins for game functions such as `CreateFrame`, `time` and
  `UnitName`). Every view worked: `/sc week`, `/sc rules`, `/sc titles`, `/sc seasons`, `/sc report`, `/sc tally`. Copying the rules
  into another language instead would mean about 1,500 lines that change every day.
- **Two mock relays** posted to a fake Discord within its limits. A prototype of the stage 2 relay below sent 21 requests, all with
  mentions off, the longest 1,885 characters, and none carried the secret list or the feelings. A second mock, which ran the addon's
  Lua over the whole saved variables (an approach not taken, see Not doing), passed 19 checks and edited a pinned message in place.

Limits worth knowing:

- An export string costs 50 to 110 characters a summons: 25 summons fit a 2,000-character Discord message, and about 100 fit a slash
  command's text box. A real log needs a file.
- The export carries summons and answers only. It has no alts (`settings.zenitAlts`), frozen weeks (`settings.weekFrozen`), cards,
  Zennit's lines, deletions or reset time. Without his alts a week's winner can come out differently (it did, in a test). The saved
  variables have all of them.
- The subzone is cut at 40 bytes (`Sync.Encode`), which can split a letter in two; anything reading it must work on bytes.

## The plan, in stages

Each stage is useful on its own. All the rules and all the wording stay in the addon: Discord only shows what a client has already
worked out, so it cannot disagree with the game.

**Stage 0: a copy window for text that exists.** `/sc report`, `/sc rules` and the "Week:" line (the one `/sc week say` sends,
`Week.StatusLine`) go into the copy window the checks already use (`Check.Copy`, Check.lua:432), and the Tools tab's PLAYTEST REPORT
and THE RULES buttons hand their full text to COPY (`show(text, full)`, Hub.lua:597). No new window and no new wording. The playtest's
Monday routine is "anyone runs `/sc report` and pastes it into the group chat" (`design/playtest.md`), but today the report only
prints to the chat window (`commands.report`, Core.lua:543), which cannot be selected. So this stage is not parked: it is a fix for
what the playtest needs, which the freeze allows ("fixes for what the checks find, and wording, are fine", lenses.md, Playtesting
revisited). It is not Interface D, which would send the report to party chat and stays deferred.

**Stage 1: `/sc discord`.** A new `Discord.lua` rewords views every player already sees into Discord's formatting and puts them in
the copy window: the week's result (provisional or final), the season, a newly reached chapter as an invitation to watch it at the
raid, and `/sc discord record` for the pinned Record. It posts only from a fixed list of views written into the addon, so what may be
posted is decided there.

- Deadlines as Discord time tags (`<t:1792368000:F>`), which show in each reader's own time.
- Names and places escaped, including `[ ] ( ) # - <` and a number at the start of a line: subzones and Zennit's lines arrive from
  other clients unchecked, and a forged one must not turn into a link posted as the Index.
- At most 1,900 characters a message; postcards as place names only.
- A stamp, "from <name>'s copy", since two clients can differ (frozen weeks, alts).
- Self-tests: no message over the limit; a digest built with feelings, a secret list, a test summons and test mode on contains none
  of them; a result whose week has not closed says Provisional; no chapter the race has not reached is named.

**Stage 2: a relay on the admin's PC (optional).** The admin turns it on with `/sc discord feed on` (or `quiet`, or `off`); it
refuses to run on one of Zennit's characters. From then on Summon Core also writes the same posts into an outbox, and a small Python
script on the admin's PC posts them to one Discord webhook (a private web address, made in the channel's settings, that lets a program
post into that one channel).

- **The outbox has its own file.** It lives in a tiny companion addon, `SummonCore_Outbox` (a TOC with
  `## SavedVariables: SummonCoreOutbox` and an empty Lua file), installed on the admin's PC only. Summon Core writes into that global,
  so the relay opens `SavedVariables/SummonCore_Outbox.lua` and never the file that holds `SummonTrackerDB`, the feelings or, on
  Zennit's PC, his list.
- Summon Core writes it at login (after the week check) and on `PLAYER_LOGOUT`, before the game saves. Each post has a stable id
  (`week:<monday>`, `record`, `lastcall:<monday>`) and may carry a not-before time: the last call is written early and the relay
  holds it until then. The outbox is emptied when the feed is off or test mode is on.
- The script (`tools/sc_relay.py`, Python's standard library only) runs every ten minutes from Task Scheduler. It reads the
  `SummonCoreOutbox = {` block with a small parser for the plain tables the addon writes (strings, numbers, nested tables) and stops
  if it finds anything else. A new id is posted (with `?wait=true`, so Discord returns the message id); a changed one is edited in
  place. It keeps each id's message id and last text in `sc_relay_state.json`, next to `sc_relay.ini`.
- It waits until the file has been still for 15 minutes, so a `/reload` mid-raid posts nothing during play.
- It holds a post, and says why, if the file goes backwards: an older write time, fewer weeks in the season without a reset, or a
  final week's winner changing. A new season, or the launch, needs `--accept-reset`.
- A result that flips after it was posted is never edited quietly: the old line is struck through, and one short reply says the
  Index has amended its entry.
- Mentions are always off (`allowed_mentions` empty); nobody is pinged.
- It searches the game folders for the file and is told which one to use: at launch the beta's `_classic_beta_` folder and the
  launch folder will both exist.
- The webhook address is the only secret. It stays in `sc_relay.ini`, out of the repo. Webhooks cannot pin, so a person pins the
  Record once.

Freshness is the admin's next logout or `/reload`, plus ten minutes. If the admin does not play that week, nothing posts; stage 1
still works.

**Stage 3: later, if asked.** A flag for answers heard live from Zennit (see Trust); a second trusted client for weeks the admin does
not play (one at a time, never merged); postcards in Zennit's own words, if he says yes.

## What gets posted

| Post | When | Comes from | Example |
|---|---|---|---|
| The week's result | Monday, provisional; edited to final once the week closes | The login line, `checkLastWeek` (Week.lua:491); final once `Week.Closed` | The group won the week (group 27, Zennit 20 (including a 2 point head start); 6 of up to 10 summons of Zennit filed). Zennit is back on the list. Season: Zennit 0 of 5, the group 4 of 5. **Provisional:** 3 summons of him are still waiting for his answer, and the week closes on \<t:…:F\>. The Index will say again if it changes. |
| A reached chapter | Inside the result, never on its own, never the art | The same login line | The story: `/sc intro g4 group` shows it to the group, at the raid perhaps. |
| The Record | Pinned once by a person, then edited | `Week.Season`, the reached chapters, `Ledger.Standings` (titles the group agreed to), `Ledger.PostcardsLine`, `Week.RulesCard` | The season, the chapters reached, the titles, the postcards so far, and for a newcomer: `/sc rules` is the race in a minute. |
| Last call | The week's final day (not in quiet mode, not on his week off) | The login's last call (Week.lua:601, `Week.RULES.lastCall`) | Last call: the Index closes the week \<t:…:R\>. The group leads by 4, 6 of 10 summons filed. |
| The season's keepsake | Once the finale is final | `Ledger.Keepsake` (Ledger.lua:312) | The keepsake the game prints, minus any title the group has not agreed to post. |

These reuse the addon's own wording. The only change is the deadline: the game prints a weekday or "in 3 hours"; Discord gets a time
tag, which counts down and shows in each reader's own time.

## Never posted

- Zennit's list, its size, which places were on it, or when they were added (`settings.zennitList`, `zennitListAdded`, on his PC
  only).
- The weekly question's answers, not even counts (`settings.feelings`, on the admin's and Zennit's PCs).
- What any one person owes (`Silver.Statement`, and the silver part of the week's line). The keepsake's total for the group is
  already public in the game.
- A titled amount (the Prompt Payer, the Hard Bargain) or anyone's name in a title, unless the group agreed to it.
- A result before its week closes without the word Provisional, in the copy window as well as the feed.
- Single summons, the dice, writs before they are played, his free declines left.
- Whether Zennit is at his keyboard, or anything mid-session.
- Chapters the race has not reached. The admin's Story tab shows every title, so this is a self-test, not a habit.
- Test summons, `/sc errors` and the admin tools.
- Words for Zennit he did not write.
- Mentions, DMs, or anything outside the one channel.

And nothing comes back from Discord into the game.

## Not doing, and why

| Idea | Why not |
|---|---|
| Live posts as summons happen | Impossible without the side channels above |
| A hosted Discord bot with slash commands | Its data is no fresher, it needs accounts and secrets, and the addon's Lua does not fit Cloudflare's free plan (measured locally at 115 to 160 ms of CPU warm and 230 to 280 ms cold, against a 10 ms limit). It would need the $5 plan, where loading it is untested, or a server. Standings on demand also make Discord a place where Zennit is chased |
| Pasting strings or commands from Discord into the game | An import checks nothing (`Export.Apply` merges with no sender); a test forged answers and summons this way |
| Playing the story in Discord (images, video or an Activity, Discord's in-app games) | It competes with watching it together at the raid, and the art would need converting from WoW's own image format (BLP) |
| A program running the addon's Lua over the whole saved variables | It works, but its stand-ins drift as the addon changes, and the feelings would pass through it. The outbox's own file keeps both out of the relay's reach |
| Forking GuildLink or Guild Milestones (Forever addons that already post to Discord) | Neither has a licence, and the relay is a few hundred lines anyway |

## Check in the game first

1. **Do saved variables survive a restart on the 1.60.1 client?** GuildLink's README says the Forever beta writes them at logout but
   does not load them at the next start (unconfirmed). If so, Summon Core loses its own log too, which matters far more than Discord.
   `/reload`, then `/sc log`: the summons should still be there. Then the same after quitting the game.
2. **Is Blizzard's own Discord link on for Forever?** The 1.60.1 client has the 12.1 guild-chat-to-Discord bridge (`C_Discord`),
   switched on per server: look under Options > Social. Even if it is on, nobody knows whether lines an addon sends cross over, and
   `/sc week say` only speaks to the party or raid.

## For the group to decide

Stage 0 needs none of these. Stage 1 needs the week's name, everyone named and quiet weeks. Stage 2 also needs Zennit's choice, the
admin as the one trusted client, and the channel.

- **Is the group chat in Discord, and is Zennit in it?** He chooses on, quiet or off, asked in person. Quiet drops the last call, and
  the provisional line says only that the result may change, not how many summons wait for him. The journal protects his right to step
  away (lenses.md, Freedom: "is everyone free to just be a person for a while?"), and a feed on his phone reaches him when the game
  cannot. On his week off the race is off but the game is not (Inner Contradiction), so quiet is worth more then. His choice is kept
  in the admin's settings, not sent on his sync line: anyone can claim to be his alt (`A` is not checked, Sync.lua:701).
- **Everyone named agrees.** Titles and the keepsake name characters and amounts: the Prompt Payer and the Hard Bargain name silver
  ("The Hard Bargain: Zennit, who asked Velwyn for 120 silver"), the Process Server names whose writs cost him how many points, the
  Quick Reply gives his usual time to answer, and the keepsake says who disturbed his leave most (Ledger.lua:270-294, 325-329). Which
  of these go in the Record and the keepsake post?
- **The report.** May a pasted `/sc report` say what share of his answers were on his list (Report.lua:164)?
- **Quiet weeks.** What does the feed say after his week off, or a week nobody won? The login line handles both on their own paths
  and sets no `weekAnnounced` (Week.lua:496-501), so the outbox needs a rule of its own.
- **The week's name.** The game names a week by its Monday in the reader's local time (Week.lua:481, 484), while weeks start at
  00:00 UTC. In the Americas that Monday is still Sunday. Pick one, and use it in both places.
- **How far.** Stop at the copy window, or also run the relay? Is the admin the one trusted client?
- **Where.** One channel that only the Index posts in (#the-index), so muting it is opting out.
- **When.** After the first week's report: the playtest asks when people hear a week's result (lenses.md, Pleasure), and a feed would
  change the answer. And before or after the launch on 4 November: the beta's saved variables live in the `_classic_beta_` folder
  and will probably not carry over to the launch folder (not confirmed).

The journal keeps chat in the game a person's choice: "neither sends chat on its own" (lenses.md, Pleasure). Stage 1 keeps that.
Stage 2 is a deliberate exception, for the group to agree to.

## Trust

The posts are as honest as the admin's client. That matches the addon's stance elsewhere (its Zennit gate is "a joke gate for
friends, not security", README, Zennit mode), but it is worth saying plainly: an answer that arrives in a sync batch is not checked
against who sent it (`Sync.Merge`), a caster can pre-answer their own summons, anyone can claim to be Zennit's alt, and an import
checks nothing (Export.lua:225). None of it leaves a trace in the log. One trusted client narrows that to whatever reached it; it
does not prove it.

If the feed's numbers ever need to be trusted, the smallest change found: when a `Z` arrives live from one of Zennit's own names
(`settings.zenitNames`, not learned alts), keep a copy of the answer on the summons (`ev.heard`), which sync never carries, and have
the feed mark an answer without it as unverified. About five lines in `Sync.lua` and one in each of Respond's answer paths. Tried in a
stub, not built.

## Sources

- Discord's API docs (github.com/discord/discord-api-docs): webhooks (2,000 characters a message, editing a webhook's own message,
  no pinning), slash command text (6,000 characters), pop-up forms (4,000 a box). Battle.net connections stopped being readable
  through Discord on 22 September 2026, so linking a Discord user to a character is a claim, not a proof.
- Cloudflare's Workers limits (github.com/cloudflare/cloudflare-docs): 10 ms of CPU a request on the free plan.
- Forever addons that already post to Discord: GuildLink (Soche/guildlink-addon, Soche/guildlink-companion), Guild Milestones
  (MihailoJovic/Guild-Milestones), Guilded (kevincaron28/Guilded). The pixel and chat-log channels: rdimascio/wow-ai.
- Blizzard's UI source for Forever 1.60.1 (Gethe/wow-ui-source, `forever` branch): `C_Discord`, and `Blizzard_DeprecatedChatInfo`,
  which is why `/sc week say` now uses `C_ChatInfo.SendChatMessage`.
