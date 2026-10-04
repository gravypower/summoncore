# Design journal: Summon Core through the lenses

Working through Jesse Schell's *The Art of Game Design: A Book of Lenses* on this addon, one lens at a time.
Lenses are named, not numbered (the numbers differ between editions). The book's questions are paraphrased
here; read the lens in the book first.

## How we use a lens

1. Pick one lens. Read it in the book.
2. Answer its questions in writing, about what is **built**, not what was meant. Use the code and real numbers.
3. Write down the gap between the answer and the build, and anything that surprised us.
4. Turn one finding into one change (or a decision not to change), and log it under Decisions.
5. Playtest with the group, and come back to the lens with what happened.

Lenses will disagree with each other. Choosing between them is the design work, so the reasoning goes in here too.

## The path

| Lens | Why here | Status |
|---|---|---|
| Essential Experience | Anchors the rest: what should a summon, an answer and a week feel like? | In progress |
| Meaningful Choices | Zennit's four answers are the main decision in the game | Findings in, decision open |
| Fairness | The rules are loaded for Zennit on purpose; is that fair, and does it need to be? | Next |
| The Player | One friend group, and one of them (Zennit) is the target | |
| Visible Progress / Feedback | The season band and answer colours in the hub | |
| Griefing / Friendship | A game about teasing a friend has to stay fun for the friend | |
| The Interest Curve | A season of five weekly wins, with story chapters as the rewards | |

## Entries

### 2026-10-04 · Lens of Meaningful Choices: Zennit's four answers

**Rules as built** (`Store.lua`, `Respond.lua`, `Week.lua`). For a summon worth P points:

| Answer | Group's points | Zennit's points | Gap (Zennit minus group) |
|---|---|---|---|
| Accept | +P | 0 | -P |
| Refuse | 0 | -P | -P |
| 50 silver (once paid) | +P | 0 | -P |
| Dice (he adds 10, ties are his: he wins 59.95%) | 0 if he wins, +P if not | +P if he wins | **+0.2P on average** |

On a place from his list: accept and refuse both leave the gap at 0, while dice average **+0.6P**.

**Findings**
- The dice are a **dominant strategy**: for any summon, of any value, rolling is his best answer for the race.
- Accept, refuse and 50 silver are **the same choice** as far as the scores go. Silver only delays the points and
  costs the summoner money.
- So the choice is meaningful only outside the scores: does he want to go there, and which answer is funniest.

**Open decision:** should the scores make the choice matter too? Ideas so far, none chosen:
- Make refusing cheaper than accepting (for example -P/2).
- Let paid silver earn Zennit something (the Ritual "accepts silver as a gesture").
- Limit the dice to a few rolls a week, so rolling becomes a decision about when.

### 2026-10-04 · Lens of Essential Experience: the group at the end of a week

**Our answer:** the group should have to *try* to beat him. A win is earned, not given, and not out of reach.

**What the build does today.** Zennit starts each week with 10 points. Every landed summon counts for the group,
not only summons of Zennit, and he rolls the dice on every summon of him (his best answer, above). The chance
that the group wins a week, with every summon in a zone (3 points), from 20,000 simulated weeks per cell:

| Summons of Zennit ↓ / of each other → | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 0% | 0% | 0% | 0% | 100% | 100% | 100% | 100% | 100% |
| 1 | 0% | 0% | 0% | 40% | 40% | 100% | 100% | 100% | 100% |
| 2 | 0% | 0% | 16% | 16% | 64% | 64% | 100% | 100% | 100% |
| 3 | 0% | 7% | 6% | 35% | 35% | 78% | 79% | 100% | 100% |
| 4 | 3% | 3% | 18% | 18% | 52% | 52% | 87% | 87% | 100% |

**The gap**
- "Trying" today means **volume**: four zone summons between friends beat the head start every time, and Zennit
  has no say in it.
- **Summoning Zennit makes it harder.** Each summon of him is a bet the group loses about 60% of the time. The
  group's best strategy is to leave him alone, the opposite of the joke the addon is built around.
- The code comment in `Week.lua` says the rules are tuned so that he "wins more weeks than he loses". That was
  the old intent; our answer above replaces it.

**Open questions**
- What should "trying" mean? Summoning more often, summoning to harder places (dungeons, far-flung zones), or
  beating Zennit at his own answers (the dice, his list)? Our answer decides which numbers to change.
- How active is the group in a normal week? Real weeks from the log (the Tools tab's "Week and season") will
  show where the head start sits now, instead of guessing.
- Still to answer: what a summon should feel like for the **summoner**, and for **Zennit** when the popup appears.

## Decisions

| Date | Decision | Lens | Why |
|---|---|---|---|
| 2026-10-04 | The group should have to try to beat Zennit; "he wins more weeks than he loses" no longer holds | Essential Experience | A win should be earned and reachable |
