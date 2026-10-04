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
| Griefing / Friendship | A game about teasing a friend has to stay fun for the friend | Built: 5 to 10 a week, he closes; ask Zennit in playtest |
| Visible Progress / Feedback | The season band and answer colours in the hub | Built 1 to 4; the tracker waits for a playtest |
| The Player | One friend group, and one of them (Zennit) is the target | Answered; changes proposed |
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

**Our answer:** "We could go 5 to 10 a week and he will be OK. We can always change it later." Not playing yet, so
Zennit gets asked at the first playtest.

**That changes the recommendation.** With a floor (he can only close once 5 are filed), the versions behave differently
(30,000 simulated weeks each):

| Version | Normal | Trying | Busy (8 dungeon) | All out (10 far-flung) |
|---|---|---|---|---|
| Limit 5, no closing (what was built) | 28% | 64% | 63% | 63% |
| Limit 10, no closing | 27% | 64% | 94% | 99% |
| **Limit 10, he may close after the 5th, free** | **27%** | **63%** | **63%** | **63%** |
| Limit 10, close after the 5th, each cut-off slot 5 points | 27% | 63% | 94% | 99% |

- **A limit of 10 with no way out rewards hounding him** (94% for a busy week): exactly the griefing the lens is about.
- **The price stops helping once the limit is 10.** He either sits through it or pays, so hounding still wins.
- **Free closing after the 5th is the fit.** If he closes at 5, the week plays exactly like the limit-5 rules we already
  judged fair; the exploit only existed because he could close *before* 5. And summons to places on *his list* earn
  him points, so a friendly group gives him a reason to leave it open.
- **Lesson:** a new constraint (the floor of 5) changed which fix was best. Re-run the lens when the design moves.

**Built:** up to 10 summons of him count; once 5 are filed and the latest answered, he can close the Index for free
(after his answer, or from the hub's Answer tab). It travels as a flag on his answer, so every client agrees; later
summons are filed under 'enthusiasm', and their casters are told. A changed answer keeps the Index closed.

**Found while building:** an answer changed within the same second as the one before it (owes, then paid) never
reached other clients, because sync keeps the later of two answers and a tie keeps the old one. A new answer is now
always timestamped after the one it replaces. The closing self-test caught it: the two clients disagreed, 15 to 12.

**Ask Zennit at the first playtest**
- How do 5, 8 and 10 summons in a week feel?
- Does he use the close button? Early, late, never? If he always closes at 5, the extra five slots do nothing.
- Does closing feel like a fair way out, or like giving up?

### 2026-10-04 · Lens of Visible Progress, with the Lens of Feedback

**The questions (paraphrased):** what progress matters to the players, and can they see it at the moment they care?
After acting, what do they need to know, and does the game tell them clearly and quickly?

**What a player sees, moment by moment, as built:**

| Moment | They want to know | They see |
|---|---|---|
| Deciding to summon Zennit | Worth it now? Dice left, filed, will helpers matter? | Nothing, unless they open `/st` |
| The ritual begins (caster) | Same | A voice clip |
| The summon is logged | Did that count? | "Summon logged: Zennit in X (+5, dungeon)": tally points, not the race |
| Zennit's popup | How close is his week off? | The summon, the cost of refusing, dice left; no week score |
| His answer arrives | Who is ahead now? | "+5 points", but not where the week stands |
| End of the week | Who won, where is the season? | A chat line about a minute after the next login |
| The hub's season band | Everything | Season wins, then `GROUP 9 / ZENNIT 8 · FILED 4/10 · DICE 1` |

**Findings**
1. **Progress is only visible where nobody is looking.** The race changes when a summon of Zennit is logged and when he
   answers; at both moments players are in the world, not in `/st`.
2. **Feedback arrives too late to help decide.** Dice left and the helper bonus should decide whether and how to summon
   him now; the summoner only learns the bonus from the dice prompt, after the ritual.
3. **Totals, not distance to the goal.** "GROUP 9 / ZENNIT 8" makes you subtract; "GROUP LEADS BY 1" tells you whether to
   push.
4. **A legibility problem we introduced.** Fitting FILED and DICE into the band dropped the "THIS WEEK" label, so two
   ZENNIT/GROUP scoreboards (season wins, week points) sit side by side. The lens works on recent decisions too.

**Proposed changes**

| # | Change | Fixes |
|---|---|---|
| 1 | After each summon of Zennit and each answer, a chat line: "Week: group leads by 1 · 4 of 10 filed · 1 die left." | 1 |
| 2 | The band shows the lead, not two totals: `WEEK: GROUP +1 · FILED 4/10 · DICE 1` | 3, 4 |
| 3 | When a ritual on Zennit begins, brief the caster: filed, dice left, what two helpers add | 2 |
| 4 | Zennit's popup shows where the week stands | 1, for Zennit |
| 5 | An optional on-screen tracker | 1; held back: clutter is a cost, wait for a playtest to ask for it |

**Built: 1 to 4.**
- As a ritual on Zennit begins: "Summoning Zennit: summon 3 of 10 this week, and the group leads by 3. He has 3 dice
  left; each helper adds +5 to your roll if he suggests dice (two helpers at most)." Or that it won't count, or that
  he is on his week off.
- After each summon of him and each answer, everyone gets "Week: the group leads by 3, 2 of 10 filed, 3 dice left."
- Zennit's popup ends with the same line in his words ("Week: you lead by 2, …"); the separate dice count it replaced
  is gone, so the number appears once.
- The band reads `WEEK: GROUP +3 · FILED 2/10 · DICE 3`; a tie reads `ZENNIT (TIE)`, because a tie is his.

**To watch in playtests**
- Do people read the chat lines, or do they scroll past? If they scroll past, that is the case for the tracker (5).
- Two lines per answer, for everyone in the guild: welcome, or noise?
- Does the briefing change behaviour: do people wait for a second helper when he still has dice?

### 2026-10-04 · Lens of the Player

**The questions (paraphrased):** what do these players like, dislike and expect? In their place, what would I want?
Unlike the other lenses, this one is about real people, so the code can only show what each kind of player gets.

**What the game offers each kind of player, as built** (`Store.Tallies`, `Store.Stats`, `Scoring.badges`):

| Player | What they do | What they get back |
|---|---|---|
| Summoner (warlocks only: Ritual of Summoning is a warlock spell) | Casts, rolls back against his dice | Points, all six badges, the Tally, the briefing, the dice prompt, their name in every line |
| Helper (anyone who clicks the portal) | Makes the ritual possible; now +5 each to the summoner's roll | An "assisted" count in the Tally; no points, no badges, no mention when their +5 wins the roll |
| Zennit | Answers every summon, guards his list, spends dice, can close the Index | His week off, the story, his own wording; Summary, Tally and Badges are hidden from him (the gag) |
| Friends who are offline | Nothing in the moment | Chat lines at login, the hub, the story |
| The designer (also a player, and the admin) | All of the above, plus the admin tools | See finding 4 |

**Findings**
1. **The role the new rules made most important gets the least back.** Helpers decide the dice now; the game never
   names them when they do.
2. **The main action is warlock-only.** Everyone else can only be a helper: the role with no rewards.
3. **Zennit answers every summon himself.** Up to 10 popups a week: the best part of his week, or a chore?
4. **The designer is one of the players.** Watch for features that exist because *we* find them fun.

**Questions about the group, answered**

| Question | Answer | What it means |
|---|---|---|
| How many are warlocks? | Two or three | Most of the group plays as helpers, so that role matters a lot |
| Do helpers enjoy it? | Yes | They don't need paying (points, badges); they are happy to be there |
| What do they enjoy in WoW? | Banter, and doing things together (not achievements, not competing) | Badges and the friend-vs-friend Tally matter less than assumed; the group-vs-Zennit race and funny lines matter more. Helpers should be part of the story, not rewarded with badges |
| What would annoy them? | Bookkeeping (not chat spam, not popups) | The "Week:" lines are fine. Hunt down anything that makes people tick boxes or remember to click |
| What is Zennit like? | Not sure yet | Playtest |

**Where the build asks for bookkeeping**
- **The assistants prompt.** When detection is unsure, the summon is not saved until the caster ticks names and
  clicks, with no timeout. Since the new rules, those names also set the dice bonus.
- **Zennit's popup** never says that ignoring a summon is fine (an unanswered summon already counts as accepted).
- **"They paid"** relies on Zennit remembering; if he forgets, the group never gets the points.

**Proposed changes**

| | Change | From |
|---|---|---|
| A | When the helpers' bonus decides a roll, name them: "Al and Cy's +10 tipped it: 58+10 beats 63." | Banter; helpers in the story |
| B | The assistants prompt saves itself after 20 seconds with the detected helpers (a countdown on the button) | Bookkeeping |
| C | Zennit's popup says that ignoring a summon counts as accepting | Bookkeeping |
| — | "They paid": watch at the playtest first; it depends on how Zennit plays | Not sure yet |
| — | Dropped: helper badges or points | The group is not achievement-driven |

**A lesson about this lens:** I expected the answer to be "reward helpers". Asking showed the group doesn't care
about rewards; it cares about banter and not doing chores. Assumptions about players are exactly what this lens
exists to test.

## Decisions

| Date | Decision | Lens | Why |
|---|---|---|---|
| 2026-10-04 | The group should have to try to beat Zennit; "he wins more weeks than he loses" no longer holds | Essential Experience | A win should be earned and reachable |
| 2026-10-04 | "Trying" means beating him at his own answers; keep it tongue in cheek | Essential Experience | Summoning Zennit should be how to win, not a risk to avoid |
| 2026-10-04 | New race from 5 Oct 2026: only summons of him count, 5 a week, 3 dice a week, +5 per helper, head start 2 | Fairness, Meaningful Choices | See the Fairness entry: effort pays, and his list keeps his week off within reach |
| 2026-10-04 | 5 to 10 summons of him count a week; he can close the Index for free once 5 are filed | Griefing / Friendship | He gets a way out; closing can't lock in a lead before the fair minimum |
| 2026-10-04 | Show where the week stands when it changes: briefing at the ritual, a chat line after summons and answers, in his popup, and the lead in the band | Visible Progress, Feedback | Progress was only in the hub, and the facts that decide how to summon him came too late |
