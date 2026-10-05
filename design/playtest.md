# Playtest script: the first season

The first week on the new rules starts **Monday 5 October 2026 (UTC)**. This is the script for it, built from the "to watch
in playtests" lists in `lenses.md`. The principle: **the log answers the questions that are numbers, so the group is only
asked the ones that are feelings, and nobody keeps notes** (they dislike bookkeeping).

## Smoke test, once, before anything else (10 minutes, in the live client)

**Start with `/sc check`** (`design/verification.md`): it runs the checks that can run by itself and walks through the rest, and
`/sc check report` prints what to send back. The list below is what it grew out of.

Several things have only been run in a stub, never in the game. Fix these before judging the design.

1. `/sc synctest`: every test should pass. Paste any failure.
2. After a full WoW restart: `/sc intro check` (every sound file plays), then `/sc intro`: scene 10 should run on into **The
   Index today**, typed out under the key clicks, with no voice. `/sc intro now` plays it alone.
3. `/sc places`: every city and far-flung map should read as found; any line saying "the client has no such map" or "calls it" is a
   wrong ID in `Scoring.lua` (fix it and say which). Then stand at a dungeon entrance you pass and run `/sc where`: it should say `dungeon`.
4. `/sc rules` (the whole race on one card), `/sc report` and `/sc seasons` (empty until a finale) print to chat; the same three
   are buttons on the Tools tab.
5. About a minute after login, the chat should say how the last week ended (if it did) and **this week's whim** (if it has one).
   This is the first real Monday rollover.
6. A summon of Zennit with two friends helping: the briefing, "Summon logged", "Week:", his popup and the answer line all appear,
   and the dice reach both clients (the `/roll` parsing and `RandomRoll` have never been tried between two real clients).
7. The Zennit tab's list refuses a one-letter entry and a sixth place.

## While playing: say nothing, watch

Play as usual. The report (below) records the numbers. Watch for the things it cannot see:

- Who laughs, who goes quiet, who repeats a line to someone else. Write down the line.
- Does anyone ask what next week's rules will be? Can anyone say the rules back without `/sc rules`?
- Does Zennit say which of the four answers he enjoys, and when he forgets he has dice?
- Does anyone stop reading chat? Which lines?

## Each Monday: one command, three questions, and the counts

The addon also asks everyone one question at their first login of the week (`/sc feelings`, design/lenses.md, Playtesting
revisited). The admin reads the counts with `/sc feelings`; they are never named, so read them as a trend, and act on a "Too much"
from Zennit or "Not for me" twice running.

Anyone runs `/sc report` and pastes it into the group chat. Then ask, out loud or in chat, one line each:

1. What was the best moment of the week?
2. Did anything feel unfair?
3. What would you have wanted to know before you summoned?

## After the first season (or four weeks, whichever comes first)

### What the report answers

| Question (from the lens entries) | Where in the report | A change is worth making when |
|---|---|---|
| Does the group win about a quarter of normal weeks and two thirds of trying ones? | "The group's wins by how many summons counted" | Normal weeks are far below 15% or above 45%, or trying weeks below 45% |
| How do 5, 8 and 10 summons a week feel? | "Summons a week when played" | Almost every week is 1 or 2 (nobody is trying), or 7+ (the cap matters) |
| Does he close the Index, early or late? | "He closed the Index in N weeks" | He always closes at 5 (the extra slots do nothing), or never does |
| Does Zennit save dice, spend them at once, or forget? | "Dice: ... on the first three" and the worth of a rolled vs an unrolled summons | 100% of rolls on the first three summons and the same worth: he rolls what comes first |
| Does the group order its summons around his dice? | "In the weeks he spent every die" | The summons after his last die are no worth more than before it |
| Does Zennit answer, or ignore? | "unanswered", "median time to answer" | More than a few unanswered, or a median of hours |
| How wide is his list? | "The list: N% of his answers" | More than 40% (it is deciding weeks) or 0% (it is never used) |
| Do the helpers' +5 matter? | "Helpers on a summons", "rolls the helpers tipped" | Most summons have no helpers |
| How many weeks is a season, and how many are quiet? | "Weeks: N with a summons, N without" | A season is on course to run past 12 weeks (drop to four wins to a finale) |
| Is the whim doing anything? | "Whim weeks" | Nobody mentions it in a month |

### What only people can answer

Ask each of them separately, so the loudest does not decide.

- **Everyone:** which lines do you quote back to each other (the chapters, the chat, the gags)? Which did you stop reading? Did the
  pooled lines ("Summon logged...") feel varied, or like noise? What does the season make you feel at the end: pride, affection
  for Zennit, or the joke?
- **The warlocks:** did the briefing change when or how you summoned? Did you ever wait for a second helper?
- **The helpers:** did you notice being named when your bonus tipped a roll? Did it start banter?
- **Zennit:** how do 5, 8 and 10 summons a week feel? Is closing the Index a fair way out or giving up? What surprises you, and what
  does not? Which ending would you want, and does being the clerk feel like a prize? Is the list fun, or a chore?

### What the answers decide

| Open decision | Decided by |
|---|---|
| Five wins to a finale, or four (`Week.WINS`) | Weeks per season; whether the group is still interested by week 9 |
| The list's bound (5 places, 4 letters) | List hit rate; whether Zennit says it is fun |
| The cap and the close (10 and 5) | When he closes; whether 5 to 10 a week feels right |
| The whim layer (`Week.RULES.whims`) | Whether anyone notices it |
| Catch-up steps (`Week.RULES.catchup`) | How many seasons are blowouts |
| The Index's voice in chat (pooled lines, or more) | What the group says about the chat |
| New chapters for season 2 | Whether anyone replays a chapter or asks what comes next |
