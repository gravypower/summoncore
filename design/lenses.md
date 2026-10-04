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
| Essential Experience | Anchors the rest: what should a summon, an answer and a week feel like? | Week answered; summoner and Zennit still open |
| Meaningful Choices | Zennit's four answers are the main decision in the game | Dice limited (3 a week); playtest |
| Fairness | The rules are loaded for Zennit on purpose; is that fair, and does it need to be? | New race built; playtest |
| Griefing / Friendship | A game about teasing a friend has to stay fun for the friend | Findings in; decision open; ask Zennit |
| The Player | One friend group, and one of them (Zennit) is the target | |
| Visible Progress / Feedback | The season band and answer colours in the hub | |
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

### 2026-10-04 · Essential Experience, continued: what "trying" means

**Our answer:** (c) **beating Zennit at his own answers.** Summoning him should be how the group wins, not a risk.
Keep it tongue in cheek.

**Today's rules work against it.** Going all out on him (6 far-flung summons, 2 helpers) won 18% of weeks, less than a
moderate push (31%): more effort, worse odds.

### 2026-10-04 · Lens of Fairness: the new race

Built from the answer above, each rule tied to a finding:

| Rule | Why |
|---|---|
| Only summons of Zennit count in the race (summons of each other still count for the tally and badges) | Essential Experience: he is the target, so volume between friends no longer wins |
| He has **3 dice a week**; then he must accept, refuse or ask for the silver | Meaningful Choices: the dice stop being always right; *when* to roll becomes his decision, and the group can outlast them |
| Each helper (up to two) adds **+5** to the summoner's roll | (c): the group beats his best answer by organising, not luck |
| Only the first **5** summons of him a week count; later ones are "filed under 'enthusiasm'" | Fairness and Friendship: hounding him past five earns nothing |
| Head start **2** (was 10) | The difficulty dial, chosen from the table below |

**Fairness, Zennit's side.** He still needs a real chance at his week off. His list provides it: some summons he
actually needs (his task list), and when one of those lands he gains the points too, so the gap does not move.

The group's chance to win a week (20,000 simulated weeks per cell; 1 in 4 summons lands on his list; he rolls while
he has dice):

| Kind of week | Head start 0 | **2 (chosen)** | 3 | 5 |
|---|---|---|---|---|
| Quiet: 2 zone summons, no helpers | 15% | **15%** | 9% | 9% |
| Normal: 3 zone summons, 1 helper | 27% | **28%** | 8% | 7% |
| Trying: 5 dungeon summons, 2 helpers | 64% | **64%** | 63% | 40% |
| All out: 8 far-flung, 2 helpers (only 5 count) | 64% | **64%** | 63% | 63% |

Effort pays (15% → 28% → 64%), and he still takes about a third of the weeks the group tries hard. The limit means
going all out is no better than trying, which is the point. Head start 2 gives the same curve as 0, but a week where he
wins every roll is clearly his.

**Built** in `Week.lua` (`Week.RULES`), `Respond.lua` and the hub's season band (`FILED 3/5 · DICE 2`), with
self-tests. It starts with the week of Monday 5 October 2026; earlier weeks keep their old rules, so the season and
the chapters already reached do not change.

**To watch in playtests**
- Does the group win about a quarter of normal weeks and two thirds of the weeks they try?
- Does Zennit save his dice for the big summons? (If he always rolls the first three, the choice is still not meaningful.)
- Is five a week the right limit, for the group and for Zennit? That is the Lens of Griefing / Friendship, next.
- Intro scenes 9 and 10 still narrate the draft rules; re-voice them once these settle.

### 2026-10-04 · Lens of Griefing / Friendship: Zennit's power to close the week

**The premise is griefing by design:** the whole group targets one friend. That can't be removed. The questions are
whether Zennit is still having fun, and whether he can say "enough". The limit of 5 a week bounds it, but the group
sets the pace, not him.

**Our idea:** Zennit has the power to cut off how many summons count in a week.

**The lens turned around:** could Zennit use that power to spoil the group's fun? His obvious move is to close the
week the moment he is ahead. The group's chance to win a week (30,000 simulated weeks each; same assumptions as the
Fairness entry):

| Version of the power | Normal week | Trying week |
|---|---|---|
| A. No power (built now) | 28% | 63% |
| B. He closes the week the moment he is ahead | 13% | 16% |
| C. B, but the Index takes one "last call" summon after he closes | 22% | 29% |
| D. He sets the week's limit in advance, before the first summon (his best is 2) | 19% | 24% |
| E. D, plus 2 points to the group for each slot under 5 | 28-100% | 43-100% |
| **F. He closes whenever he likes, but each slot he cuts off is filed as 5 points to the group** | **27%** | **63%** |

**Findings**
- A free "close" button (B) wipes out the last decision: trying drops from 63% to 16%. **The power that protects Zennit
  from griefing would let him grief the group.**
- Choosing the limit in advance (D) is less abusable, because he chooses blind. But a small limit makes the week a
  coin toss: with fewer summons, effort has less room to show. That is the Lens of Skill vs. Chance arriving uninvited.
- **Separate relief from scoring.** In F, closing buys him peace, not a win. Each cut-off slot is filed at 5 points, about
  one well-organised dungeon summon, so closing is neutral for the race (63% either way). He closes when he has had
  enough, or when the week is already decided.

**Recommendation:** F. In the game's voice: "Zennit has closed the Index for the week. The 3 forms left were stamped
APPROVED in his absence: +15 to the group."

**Open**
- Choose: F, or another version.
- **Ask Zennit.** The Lens of Friendship can't be answered from the code. How does five summons a week feel to him? Would
  he use a close button, and would paying for it feel fair or feel like a punishment? His answer goes here.

## Decisions

| Date | Decision | Lens | Why |
|---|---|---|---|
| 2026-10-04 | The group should have to try to beat Zennit; "he wins more weeks than he loses" no longer holds | Essential Experience | A win should be earned and reachable |
| 2026-10-04 | "Trying" means beating him at his own answers; keep it tongue in cheek | Essential Experience | Summoning Zennit should be how to win, not a risk to avoid |
| 2026-10-04 | New race from 5 Oct 2026: only summons of him count, 5 a week, 3 dice a week, +5 per helper, head start 2 | Fairness, Meaningful Choices | See the Fairness entry: effort pays, and his list keeps his week off within reach |
