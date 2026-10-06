# Discord: the Index's noticeboard (parked)

Researched on 5 October 2026; nothing is built. The question was whether Summon Core could reach into the group's Discord. It can,
but only after the fact: as a noticeboard the Index keeps, not a live feed. This page is the plan, what was proved by running code,
and what the group has to decide first. It is parked until the first week's playtest report (`design/playtest.md`) and the group's
say, Zennit's first.

## What is possible

The game cannot reach the internet: the 12.0 addon API has no web requests (README.md, Status). Data leaves it two ways, and both
need a person or a program outside the game:

| Way out | How | When it is fresh |
|---|---|---|
| The copy box | The Import / Export window (`Export.Open`), then Ctrl+C | Whenever someone copies |
| The saved variables | `WTF/Account/<account>/SavedVariables/summoncore.lua`, read by a program on that PC | Only after `/reload`, logout, quitting or a disconnect; never mid-session, and not after a crash (from the wiki; not yet confirmed on Forever) |

So Discord can hear about a week, never about a summons as it happens. Side channels that get closer to live do exist on Forever (an
addon drawing a strip of coloured pixels for a screenshot reader, or padding the chat log until the client flushes it), but they are
fragile and run against Blizzard's stance on out-of-game overlays (the 10.2 combat log change). Not for this.

What running the addon's own code outside the game showed (scratch work, not in the repo):

- **An outside program can read the export string.** Two decoders written apart from the addon (Python and Node) matched
  `Codec.Unpack` byte for byte on 1,265 records, and refused tampered and cut strings the same way it does.
- **The addon's own Lua runs outside WoW** (Lua 5.1, with about ten stand-ins such as `CreateFrame`, `time` and `UnitName`). Every
  view worked: `/sc week`, `/sc rules`, `/sc titles`, `/sc seasons`, `/sc report`, `/sc tally`. Copying the rules into another
  language instead would mean about 1,500 lines that change every day.
- **A mock relay** posted the Index's own lines to a fake webhook within Discord's limits, edited a pinned message in place, and never
  posted the secret list or the feelings (19 checks).

Limits worth knowing:

- An export string costs 50 to 110 characters a summons: 25 summons fit a 2,000-character Discord message, and about 100 fit a
  slash-command option. A real log needs a file.
- The export carries summons and answers only. It has no alts (`settings.zenitAlts`), frozen weeks (`settings.weekFrozen`), cards,
  Zennit's lines, deletions or reset time. Without his alts a week's winner can come out differently (it did, in a test). The saved
  variables have all of them.
- The subzone is cut at 40 bytes (`Sync.Encode`), which can split a letter in two; anything reading it must work on bytes.

## The plan, in stages

Each stage is useful on its own. All the rules and all the wording stay in the addon: Discord only shows what a client has already
worked out, so it cannot disagree with the game.

**Stage 0: the copy box for text that exists.** `/sc report`, `/sc rules` and the week's line open in the Import / Export window,
ready to copy. The playtest script already says to paste the report into the group chat (`design/playtest.md`), but `/sc report` only
prints to the chat window (`commands.report`, Core.lua:543), which cannot be selected. No new wording.

**Stage 1: `/sc discord`.** A new `Discord.lua` rewords views every player already sees into Discord's markdown and puts them in the
copy box: the week's result (provisional or final), the season, a newly reached chapter as an invitation to watch it at the raid, and
`/sc discord record` for the pinned Record. It works from an allowlist of views, so what may be posted is decided in the addon.

- Deadlines as `<t:unix:F>`, which Discord shows in each reader's own time.
- Names and places escaped, including `[ ] ( ) # - <` and a number at the start of a line: subzones and Zennit's lines arrive from
  other clients unchecked, and a forged one must not turn into a link posted as the Index.
- At most 1,900 characters a message; postcards as place names only.
- A stamp, "from <name>'s copy", since two clients can differ (frozen weeks, alts).
- Self-tests: no message over the limit, and a digest built with feelings, a secret list, a test summons and test mode on contains
  none of them.

**Stage 2: a relay on the admin's PC (optional).** On the admin's client only, after `/sc discord feed on` (or `quiet`, or `off`),
the addon also writes the same posts into a second saved variable, `SummonCoreOutbox`, at login (after the week check) and at logout.
Each post has a stable id (`week:<monday>`, `record`, `lastcall:<monday>`). A small Python script (`tools/sc_relay.py`, standard
library only), run every ten minutes by Task Scheduler, reads only that block and talks to one Discord webhook: a new id is posted,
a changed one is edited in place (provisional becomes final, and the pinned Record stays current). It never reads `SummonTrackerDB`,
which on the admin's PC holds the feelings.

- It waits until the file has been still for 15 minutes, so a `/reload` mid-raid posts nothing during play.
- It holds a post, and says why, if the file goes backwards: an older write time, fewer weeks in the season without a reset, or a
  final week's winner changing. A new season, or the launch, needs `--accept-reset`.
- A result that flips after it was posted is never edited quietly: the old line is struck through, and one short reply says the
  Index has amended its entry.
- Mentions are always off (`allowed_mentions` empty); nobody is pinged.
- It finds the file with a glob over the game folders and is told which one to use: at launch the beta's `_classic_beta_` folder
  and the launch folder will both exist.
- The webhook URL is the only secret. It stays in `sc_relay.ini`, out of the repo. Webhooks cannot pin, so a person pins the Record
  once.

Freshness is the admin's next logout or `/reload`, plus ten minutes. If the admin does not play that week, nothing posts; stage 1
still works.

**Stage 3: later, if asked.** A flag for answers heard live from Zennit (see Trust); a second trusted client for weeks the admin does
not play (one at a time, never merged); postcards in Zennit's own words, if he says yes.

## What gets posted

| Post | When | Example |
|---|---|---|
| The week's result | Monday, provisional; edited to final once the week closes | The group won the week (group 52, Zennit 10 (including a 10 point head start)). Zennit is back on the list. Season: Zennit 0 of 5, the group 4 of 5. **Provisional:** 3 summons of him are still waiting for his answer, and the week closes on \<t:…:F\>. The Index will say again if it changes. |
| A reached chapter | Inside the result, never on its own, never the art | The story: `/sc intro g4 group` shows it to the group, at the raid perhaps. |
| The Record | Pinned once by a person, then edited | The season, the chapters reached, the titles, the postcards so far, and for a newcomer: `/sc rules` is the race in a minute. |
| Last call | The week's final day (not in quiet mode, not on his week off) | Last call. The Index closes the week of 12 Oct \<t:…:R\>. Where it stands is in the game (`/sc week`). |
| The season's keepsake | Once the finale is final | The keepsake the game prints (`Ledger.Seasons`). |

The first two are the addon's own lines from the mock run (the login line, `checkLastWeek`), not new prose.

## Never posted

- Zennit's list, its size, or which places were on it (`settings.zennitList`, on his PC only).
- The weekly question's answers, not even counts (`settings.feelings`, on the admin's and Zennit's PCs).
- What anyone owes (`Silver.Statement`, and the silver part of the week's line).
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
| A hosted Discord bot with slash commands | Its data is no fresher, it needs accounts and secrets, and the addon's Lua does not fit Cloudflare's free plan (measured at 115 to 280 ms of CPU against a 10 ms limit; it would need the $5 plan or a server). Standings on demand also make Discord a place where Zennit is chased |
| Pasting strings or commands from Discord into the game | An import checks nothing (`Export.Apply` merges with no sender); a test forged answers and summons this way |
| Playing the story in Discord (images, video or an Activity) | It competes with watching it together at the raid, and the art would need converting from BLP |
| A program running the addon's Lua over the whole saved variables | It works, but its stand-ins drift as the addon changes, and the feelings would pass through it. The outbox keeps both inside the game |
| Forking GuildLink or Guild Milestones (Forever addons that already post to Discord) | Neither has a licence, and the relay is a few hundred lines anyway |

## Check in the game first

1. **Do saved variables survive a restart on the 1.60.1 client?** GuildLink's README says the Forever beta writes them at logout but
   does not load them at the next start (unconfirmed). If so, Summon Core loses its own log too, which matters far more than Discord.
   `/reload`, then `/sc log`: the summons should still be there. Then the same after quitting the game.
2. **Is Blizzard's own Discord link on for Forever?** The 1.60.1 client has the 12.1 guild-chat-to-Discord bridge (`C_Discord`),
   switched on per server: look under Options > Social. Even if it is on, nobody knows whether lines an addon sends cross over, and
   `/sc week say` only speaks to the party or raid.

## For the group to decide

- **Is the group chat in Discord, and is Zennit in it?** He chooses on, quiet (no last call) or off, asked in person. His prize for a
  week is time away from the game (lenses.md, Inner Contradiction), and a feed on his phone eats into it. His answer is kept in the
  admin's settings, not sent on his sync line: anyone can claim to be his alt (`A` is not checked, Sync.lua:701).
- **Everyone named agrees.** Titles name characters and amounts: "The Hard Bargain: Zennit, who asked Velwyn for 120 silver", and
  the Process Server names whose writs cost him how many points (Ledger.lua:270, 286). Leave those two out of the Record, or keep them?
- **The report.** May a pasted `/sc report` say what share of his answers were on his list (Report.lua:164)?
- **Quiet weeks.** What does the feed say after his week off, or a week nobody won? The login line handles both on their own paths
  and sets no `weekAnnounced` (Week.lua:496-501), so the outbox needs a rule of its own.
- **The week's name.** The game names a week by its Monday in the reader's local time (Week.lua:481, 484), while weeks start at
  00:00 UTC. In the Americas that Monday is still Sunday. Pick one, and use it in both places.
- **How far.** Stop at the copy box, or also run the relay? Is the admin the one trusted client?
- **Where.** One read-mostly channel (#the-index), so muting it is opting out.
- **When.** After the first week's report: the playtest asks when people hear a week's result (lenses.md, Pleasure), and a feed would
  change the answer. And before or after the launch on 4 November: the beta's season and saved variables do not carry over.

The journal keeps chat in the game a person's choice: "neither sends chat on its own" (lenses.md, Pleasure). Stage 1 keeps that.
Stage 2 is a deliberate exception, for the group to agree to.

## Trust

The posts are as honest as the admin's client. That is the game's own standard ("friends, not security"), but worth saying plainly:
an answer that arrives in a sync batch is not checked against who sent it (`Sync.Merge`), a caster can pre-answer their own summons,
anyone can claim to be Zennit's alt, and an import checks nothing (Export.lua:225). None of it leaves a trace in the log. One trusted
client narrows that to whatever reached it; it does not prove it.

If the feed's numbers ever need to be trusted, the smallest change found: when a `Z` arrives live from one of Zennit's own names
(`settings.zenitNames`, not learned alts), keep a copy of the answer on the summons (`ev.heard`), which sync never carries, and have
the feed mark an answer without it as unverified. About five lines in `Sync.lua` and one in each of Respond's answer paths. Tried in a
stub, not built.

## Sources

- Discord's API docs (github.com/discord/discord-api-docs): webhooks (2,000 characters, 10 embeds, editing a webhook's own message,
  no pinning), slash-command options (6,000 characters), modals (4,000 a box). Battle.net connections stopped being readable through
  Discord on 22 September 2026, so linking a Discord user to a character is a claim, not a proof.
- Cloudflare's Workers limits (github.com/cloudflare/cloudflare-docs): 10 ms of CPU a request on the free plan.
- Forever addons that already post to Discord: GuildLink (Soche/guildlink-addon, Soche/guildlink-companion), Guild Milestones
  (MihailoJovic/Guild-Milestones), Guilded (kevincaron28/Guilded). The pixel and chat-log channels: rdimascio/wow-ai.
- Blizzard's UI source for Forever 1.60.1 (Gethe/wow-ui-source, `forever` branch): `C_Discord`, and `Blizzard_DeprecatedChatInfo`,
  which is why `/sc week say` now uses `C_ChatInfo.SendChatMessage`.
