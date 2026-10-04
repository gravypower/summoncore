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
| The Player | One friend group, and one of them (Zennit) is the target | Built A to C; Zennit and "They paid" wait for the playtest |
| The Interest Curve | A season of five weekly wins, with story chapters as the rewards | Answered; C (his week off) and A (catch-up) built; playtest |
| Skill and Chance | Surfaced twice uninvited: the dice, the helpers' +5 and the catch-up edge are all luck dials | Answered; the last-die line built; playtest |
| Story and Emotion | The story now follows the tree; does it make the group feel something, or is it only a reward track? | Answered; A, C and D built; playtest |
| Surprise | A season is about 11 weeks of the same rules and the same lines; what will still surprise this group in week 9? | Answered; A, B, C and D built; playtest |
| Elegance | Twelve or so rules have piled up; which ones earn their place? | Answered; the change waits for a decision (below) |

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
(after his answer, or from the hub's Zennit tab). It travels as a flag on his answer, so every client agrees; later
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
| Deciding to summon Zennit | Worth it now? Dice left, filed, will helpers matter? | Nothing, unless they open `/sc` |
| The ritual begins (caster) | Same | A voice clip |
| The summon is logged | Did that count? | "Summon logged: Zennit in X (+5, dungeon)": tally points, not the race |
| Zennit's popup | How close is his week off? | The summon, the cost of refusing, dice left; no week score |
| His answer arrives | Who is ahead now? | "+5 points", but not where the week stands |
| End of the week | Who won, where is the season? | A chat line about a minute after the next login |
| The hub's season band | Everything | Season wins, then `GROUP 9 / ZENNIT 8 · FILED 4/10 · DICE 1` |

**Findings**
1. **Progress is only visible where nobody is looking.** The race changes when a summon of Zennit is logged and when he
   answers; at both moments players are in the world, not in `/sc`.
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

**Built: A to C.**
- A: "Zennit lost the dice (55 to 58+10): the summon counts. +5 points. Al and Cy's +10 tipped it." Only when the
  bonus decided the roll; a roll the summoner would have won anyway names nobody.
- B: Confirm counts down from 20 and saves with the ticked names (the detected helpers), marked unconfirmed because
  nobody confirmed them; ticking or unticking anything stops the countdown.
- C: the popup's question ends "(Ignore it and it counts as accepted.)"

**To watch in playtests**
- Do the helpers notice, and enjoy, being named? Does it start banter?
- Does anyone still have to touch the prompt? If the detected names are usually wrong, the countdown saves wrong names.
- Does Zennit answer, or ignore? If he ignores most summons, the dice and the list never come into play.

**A lesson about this lens:** I expected the answer to be "reward helpers". Asking showed the group doesn't care
about rewards; it cares about banter and not doing chores. Assumptions about players are exactly what this lens
exists to test.

### 2026-10-04 · Lens of the Interest Curve: a season

**The questions (paraphrased):** is there a hook to start? Does interest rise and fall with rests between the peaks,
rather than staying flat or peaking early? Is there a climax, and does it come last? Is the ending worth reaching? The
lens applies at every scale, so: a summon, a week, a season, and the story across seasons.

**The curve as built** (`Week.lua`, `Intro.lua`, `Hub.lua`; the season numbers are from 100,000 simulated seasons
using the Fairness entry's chance of the group winning a week: 15% quiet, 28% normal, 64% trying; he wins the rest)

| Scale | What the curve does | Verdict |
|---|---|---|
| A summon | Briefing, the ritual, his popup, his roll, the group's roll back, "Week: …" | A real peak at the dice; good |
| A week | Flat from Monday to Sunday (counters tick), then the result about a minute after the next login | **No climax inside the week** |
| A season | The race to five wins: 5 to 10 weeks, one chapter per win | Depends on how hard the group tries (below) |
| The story | The intro (3.6 minutes), then about a minute per chapter, 10 chapters in all | **Runs out after the first finale** |

**Findings**

1. **The hook is the intro; the first reward is a week away.** A new player gets 3.6 minutes of narration, then nothing
   from the story until the first week closes. In between the only feedback is numbers.
2. **The climax depends on the group's effort, not on the design.** A season ends 5 to 0 or 5 to 1 (a blowout) in
   **77%** of seasons when the group is quiet (15% a week), **47%** at normal effort (28%), and still **23%** at 45%.
   A close finish (the loser has 3 or more wins) is at best **53%**. Almost nothing makes a late lead change: 0.5 a
   season at normal effort.
3. **Zennit's side gets the rising action; the group's barely gets seen.** At normal effort the group wins 1.9 weeks a
   season and sees chapter g3 or later in **31%** of seasons; Zennit's trunk runs the full five in nearly all of them
   (4.9 chapters). So the best group chapters (the Ritual naming its price, the receipt, the freeing) are rarely played.
4. **The week off is a story beat with no mechanics.** The ending of chapter 2 says no ritual can find him, but
   `Week.Immune` only drives a warning: summons during it still count, and he still answers. A win for Zennit changes
   nothing in the next week, so his victories do not feel like one. (A season is 6.7 weeks for an active group; with a
   quarter of the weeks quiet, 9.)
5. **The story ends once.** All 10 chapters are written and the tree shows every reached chapter lit, so season 2
   replays season 1. "The Index today" now follows the season, but it is one scene, not new rising action.
6. **A result can be announced and then flip.** The Monday announcement uses the week's score, which is frozen only
   two days after the week ends, and Zennit can still answer into the week until then. A late answer can reverse a win
   after the chat line and the chapter have been given out.

**Proposed changes** (none built yet)

| # | Change | Fixes | Cost |
|---|---|---|---|
| A | **Catch-up**: the side two wins behind gets a small edge for the weeks it trails (for example, the group's helpers add more when Zennit leads by 2 or more; his head start or his dice shrink when the group leads by 2 or more). In the simulation, a 10 point shift in the weekly chance cuts blowouts from 47% to 35% and raises close seasons from 29% to 39% at normal effort; 20 points gives 25% and 49% | 2 | Rules, a README paragraph, a few numbers to playtest |
| B | **A beat inside the week**: a line of story at the moments that already exist: the first summon of him, the fifth filed (he may close), the lead changing hands, him closing, the last hour | 1, 4 | Wording only (no art, no voice) |
| C | **The week off is a week off**: while Zennit is on leave, summons of him are filed under "enthusiasm" and do not count, so winning is a pause and the story beat is real | 4 | A rule change; the group then wins nothing that week |
| D | **A match-point week**: when either side is one win from its finale, the week is announced as the deciding one (the Ledger already says it) and plays under one extra rule, such as a fourth die for him | 2 | A rule; needs the dice simulation |
| E | **Season 2 is new**: new chapters, or the old ones return changed (the Ledger's idea, per chapter) | 5 | Writing, art, voice: the largest |
| F | **Hold the announcement until the week is frozen**, or word it as provisional | 6 | Pacing: the payoff arrives two days later |

**Our answer:** build **C**, and keep the gags going: the week off is filler, not a rule that silences the joke, so his
popup, the dice, the warnings and the gag all carry on. A close finish is the goal, so **A** (catch-up) is next.

**Built: C.** Under the new rules, after a week Zennit wins, summons of him are filed as **filler**: logged, answered and
gagged as usual (the briefing and the warning say so), but the race ignores them, **nobody wins the week** and no chapter
unlocks. The week after is a normal one. A first simulation of the cost: with no week off a season is about 6.7 weeks at
normal effort (28% a week); with a rest after each of his wins it is **10.7**, and at 45% it goes from 7.5 to 11
(simulated, 100,000 seasons each). That is long: C and the season's five wins need to be looked at together (see below).

**Built: A, catch-up.** The lever is Zennit's edge on the dice, because it is the one dial that moves a week smoothly (his
head start does not: 2 and 0 are the same, and 3 drops a normal week from 28% to 8%). From the weekly model that reproduces the
Fairness table (15%, 28%, 64% at edge 10), his edge moves the group's chance like this:

| His edge | -10 | 0 | 5 | **10 (now)** | 15 | 20 |
|---|---|---|---|---|---|---|
| Quiet week | 32% | 23% | 19% | **15%** | 12% | 9% |
| Normal week | 50% | 39% | 33% | **27%** | 23% | 18% |
| Trying week | 82% | 74% | 69% | **63%** | 58% | 52% |

The rule: a lead of 2 weekly wins moves it by 5 for the side behind, and 3 or more by 10 (so it is +5 or +15, then +0 or
+20; never below 0, and a lead of 1 changes nothing). Simulated seasons (60,000 each):

| | Quiet | Normal | Trying |
|---|---|---|---|
| Blowout (loser has 0 or 1 win): without / with | 78% / 69% | 49% / 39% | 32% / 23% |
| Close finish (loser has 3 or more): without / with | 7% / 10% | 27% / 34% | 43% / 52% |
| Weeks to a finale | 5.9 / 6.1 | 6.7 / 6.9 | 7.2 / 7.5 |

It is gentle on purpose: it narrows the lopsided seasons without deciding them, and the group's effort still matters most.
A stronger version (steps of 5 at a lead of 1 and 10 from 2) gets normal-effort blowouts to 33% and close finishes to 41%,
but it penalises the side for leading by one win, which feels like punishment. Not chosen; `Week.RULES.catchup` is one line.
It shows in the briefing, the "Week:" line, his popup, the dice prompts and "The Index today", in the Index's voice:
"The Index, which takes no sides, has cut his edge on the dice to +5 this week."

**Found while building:** the week off had no effect on the score at all (only `Week.Warn` and `Week.Briefing` mentioned it),
so a win for Zennit left the group's next week unchanged. And a new week off must not become a free win for him: with
no summons counted his head start of 2 would beat 0, so a week off has no winner at all.

**To decide before building**
- Is a close finish the goal, or is a lopsided season fine when the group simply tries harder (or less hard)?
- Does a win for Zennit have to *cost* the group something, or is the story enough?
- How long should a season last? With C, about 11 weeks (nearly three months) at normal effort. Options: fewer wins to a
  finale (4), or letting the group win during his week off (no). **Decided: keep five wins for now**; revisit after the
  first real season shows how many weeks are quiet.

**To watch in playtests**
- How many weeks does a first season really take, and how many are quiet?
- Does anyone replay a chapter, or ask what comes next?
- Do the "Week:" lines build any excitement during the week, or is it only the Monday result?

### 2026-10-04 · Lens of Skill, with the Lens of Chance: what the group controls

**The questions (paraphrased):** what skills does the game ask of its players, and are they the ones we want? Is there room
for a better player to do better? Where does chance enter, and does it make skill matter or swamp it? (Chance averages out
over a long game, so the answer can differ by scale.)

**Who decides what, as built**

| | Decided by people (skill) | Decided by dice or luck (chance) |
|---|---|---|
| The group | How many summons (2 to 10), to which places (1, 3, 5 or 10 points), how many helpers (0 to 2), and the **order** of the summons against his dice left; getting 2 or 3 friends to the same spot in WoW | The summoner's roll back |
| Zennit | Accept, refuse, silver or dice; **when** to spend 3 dice; his secret list; when to close the Index | His roll; whether a place is on his list (the group cannot see this) |

**Numbers** (a weekly model that reproduces the Fairness table; 40,000 weeks per cell)

| Question | Answer |
|---|---|
| How much does a helper matter? | +5 each is worth about **6 points** of a week's win chance (five dungeons: 52%, 58%, 64%; three zone summons: 22%, 27%, 33%) |
| How much of a week is the group's plan, and how much dice? | Across 300 plausible plans, the plan explains **25%** of the variance in the result if he rolls the first three summons, **16%** if he saves dice for dungeons, **9%** if he rolls at random. The rest is dice and his choices |
| Does skill show up over a season? | Yes: a group that moves from a 39% to a 63% weekly chance goes from **25% to 79%** to take the finale (race to 5) |
| Is there a best order for the group? | **No: it depends on what he does.** One mixed week (three cheap summons, then three dungeons, 2 helpers): *cheap first* wins **97%** if he rolls the first three, **39%** if he saves for dungeons; *big first* wins **39%** and **97%** (the second against someone who rolls only on the last ones). Neither order beats every policy |

**Findings**
1. **A week is mostly chance; a season is mostly skill.** The best plan we sampled still loses 37% of weeks, and the group's
   plan explains at most a quarter of one week. But the same plan decides about three in four seasons. For a group that
   plays weekly, the drama sits in the week and the fairness in the season, which suits it.
2. **The deep skill is a guessing game, and it is the one we wanted.** Limiting the dice to three made *when to roll* his
   decision (the Meaningful Choices entry) and *what order to summon in* theirs. Each side's best move depends on the other's,
   so neither has a dominant play: the aim of that change.
3. **The moment skill pays is invisible.** When his last die is spent, every later summon is certain, which is exactly
   when a group that sent its cheap summons first collects. Nothing said so; only the "Week:" line's "0 dice left".
4. **The Fairness table assumed he rolls whatever comes first.** That is the best policy against a group that sends zone
   summons, and a poor one against a group that baits. The playtest should record how he really spends dice.
5. **Helpers are the dependable skill.** They are the one lever that needs no guess about the other side, and they ask for
   togetherness, not bookkeeping: what this group likes (the Player entry).

**Decision: no rule change.** Chance in a week is what makes the dice banter, and skill compounds across the season.
**Built: the last-die line.** When his third die is spent, everyone gets "That was Zennit's last die this week. Every summon
from here is certain: he can only accept, refuse or ask for the silver." (Zennit's own client: "That was your last die this
week. From here you can only accept, refuse or ask for the silver.") It also begins to answer the Interest Curve's flat week,
by giving the week one beat that comes from play.

**To watch in playtests**
- Does Zennit save dice, spend them at once, or forget he has them? Does his policy change after the first season?
- Does the group learn to send cheap summons first? Does anyone say so out loud?
- When the last-die line comes up, does the order of the summons change?
- Do the helpers' +5 get noticed, or does the group still treat them as optional?

### 2026-10-04 · Lens of Story, with the Lens of Emotion: does the group feel it?

**The questions (paraphrased):** does the game tell a story, and does the story give the players' actions meaning (and the
actions move the story)? What do I want players to feel, what do they feel, and at which moments? From the Player entry the
target is **banter and doing things together, with no bookkeeping**, and Zennit has to enjoy being the target.

**The feelings we want, and what the build gives at each moment** (`Detector.lua`, `Respond.lua`, `Week.lua`, `Intro.lua`)

| Moment | Feeling we want | What the build gives |
|---|---|---|
| The ritual begins | Mischief, anticipation | A briefing in facts ("summon 3 of 10 this week, the group leads by 3") |
| His popup | Dread, played for laughs; agency for him | Four buttons, his own wording, the gag: **works** |
| The dice | Tension, shared | A real `/roll` the party sees in chat: **the best moment in play** |
| The result | Triumph or a groan | "+5 points", the lead, the dice left |
| End of a week | Suspense, then release | One chat line a minute after the next login |
| A chapter | Warmth, curiosity | Narrated, drawn, typed out: **the strongest moment, and it is outside play** |
| A finale | Catharsis, affection | Chapters 10 and 11 (75 and 72 seconds); both end with Zennit welcome at a very small cake |
| His week off | Relief, a little missing him | A line at login |

**Findings**
1. **The story lives in a viewer; the play lives in chat, and the two do not talk.** A normal summon of Zennit prints five
   lines (the briefing, "Summon logged", "Week:", his answer, "Week:") and none is in the Index's voice. The voice shows up
   only in the warnings, the closure and the catch-up line. The group dislikes bookkeeping, and that is the tone of most of
   what they read while playing.
2. **Both endings are kind to Zennit.** If he wins he becomes the clerk, and if the group wins he is freed; each finale ends with
   him invited and the party at his table. The group gets a story for losing a week (his chapters) and he gets one for
   winning it (theirs). That meets the Griefing / Friendship entry; it is worth keeping.
3. **The players are not in it.** The 32 scenes name only Zennit; the group is "the party". The personal material exists in
   the log (who tipped a roll, who summoned him most, how many dice he won in a row) and surfaces only as a chat line that
   scrolls away. That is the part a friend group would repeat to each other.
4. **The story and the rules echo in places, not in others.** His list is the syllabus (z3), the fifty silver is the Ritual's
   price (g4), the week off is real now (z1). But the cake, the carbon copy and the cellar have no counterpart in play, and
   the silver Zennit asks for and marks paid ("They paid") never reaches chapter g5, where the group pays the Ritual.
5. **It runs out.** A normal season shows about 6.7 of the 10 chapters (about 6 minutes of story over 11 weeks, 33 seconds a
   week), and season 2 replays them; "The Index today" varies, but it is one scene.
6. **We do not know what Zennit wants.** The z chapters give him agency, but which ending he would pick, and whether being the
   clerk is the better one, is for the playtest.

**Proposed changes** (none built yet)

| # | Change | Fixes | Cost |
|---|---|---|---|
| A | **The Index remembers**: "The Index today" tells a moment or two from this season, named: the roll a helper pair tipped, who has summoned him most, a run of dice he won. Worked out from the log, so every client agrees | 3, 5 | Wording and one function; no art or voice |
| B | **The Index's voice in the five lines**: the same facts, said as the Index would ("The Index has noted a summons to Deadmines; he has been told") | 1 | Wording; risk of more reading in chat |
| C | **Silver reaches the story**: the silver paid to Zennit in a season is counted, and chapter g5 (or the Ledger) uses the number | 4 | A tally, and re-voicing scene 30 if the number is spoken |
| D | **A season keepsake**: when a finale lands, record it with who was there (a list of past seasons in the Tools tab, and a line in chat) | 3, 5 | Small; stored in the log or settings |
| E | **New chapters for season 2** | 5 | The largest: writing, art, voice |

**Our answer:** build **A, C and D**, and **name the players** by character name.

**Built** (`Ledger.lua`; every line is worked out from the log, so all clients tell the same story)
- **A, the Index remembers.** "The Index today" now tells up to two moments of the season: the roll a pair of helpers tipped
  ("Al and Cy's +10 tipped one of Bo's rolls: 52+10 against his 45+10. The Index has framed it."), who has summoned him most
  (three or more, and no tie), and a run of three or more dice he won. A tipped roll is the same test the chat line uses:
  he would have won without the bonus.
- **C, the silver reaches the story.** The silver Zennit marks as paid is counted for the season ("The group has paid Zennit
  100 silver, in cash, with no receipt. The Ritual has asked to be kept informed."), with what is still owed. It shows in the
  scene, in the keepsake, and on the tooltips of the group's last two chapters, where the Ritual names its price (g4) and
  receives it (g5). The recorded narration is unchanged: the number is not spoken.
- **D, the keepsake.** When a finale lands, the chat gets the Index's record of that season, and `/sc seasons` (or the Tools
  tab's **Past seasons**) lists them all: how it ended, how many weeks it took, who was in the room, the silver, the moments.
  Nothing is stored: each season is recomputed from the log, so a client that syncs later still gets it.

The scene grew, so it is capped at two lines of memory (the silver counts as one). `Week.Season` now gives each finale a
`from` (the first week of that season) and the season in progress a `since`.

**Not built.** B (the Index's voice in the five lines of a normal summon) and E (new chapters for season 2) wait for the
playtest: B adds reading to chat the group may not want, and E is the largest piece of work.

**To decide before building**
- Which feeling matters most at the end of a season: the group's pride, affection for Zennit, or the joke? (Asked at the playtest.)

**To watch in playtests**
- Which lines does the group quote back to each other: the chapters, the chat, or the gags?
- Does Zennit say which ending he wanted? Does the clerk ending feel like a prize to him?
- Do people replay chapters, or skip them once heard?

### 2026-10-04 · Lens of Surprise, with the Lens of Curiosity: week 9

**The questions (paraphrased):** what will surprise the players, in the rules, the story and the people? What questions
does the game put in their heads, and are they worth answering? Surprise wears off, so the real test is a surprise that
still works the tenth time.

**Where surprise comes from, as built** (`Respond.lua`, `Gag.lua`, `Clips.lua`, `Intro.lua`, `Ledger.lua`)

| Source | Who it surprises | Variants shipped | Shelf life |
|---|---|---|---|
| Zennit's choice of answer (accept, refuse, silver, dice) | The summoner | Four, picked by a person | **Does not wear off**: it is a friend |
| The dice | Everyone in chat | A fresh pair of numbers each time | Long, but only the numbers change |
| A place on his secret list | The group, when it hits ("It is on his list: +3") | One per place on the list | Each place once, then it is known |
| A chapter | Everyone | 10, hidden as "???" until the race reaches them | Once each; season 2 is a replay |
| "The Index today": a named moment, the silver | The group | Worked out from the log | Fresh each time the facts change |
| The gag on the wrong tab | Zennit, or the party | **1** animation, 1 recording | A few viewings |
| Voice clips: `wag`, `zenit_land`, `zenit_refuse`, `zenit_win`, `ritual`, `narrator_weekopen` | The player who triggers them | **0** recorded (`ClipList.lua` is empty) | None yet: every random pick picks silence |
| The Index's chat lines | Nobody | About 11 templates | See finding 3 |

**Findings**
1. **The surprises are in the people and the story, which is where a friend group wants them.** Zennit's answers and the
   reveals in the story are the two sources that do not run out in a season, and neither is a random table.
2. **The authored randomness is empty.** The addon picks a random clip per category and avoids repeating, but no clip is
   recorded and only one gag exists, so a random pick is the same pick. The README says some lines are meant to surprise
   Zennit; none can yet.
3. **The lines that repeat are wallpaper by week 9.** A normal season has about 6.7 weeks of play and 3 summons of him a
   week, so about 20 summons. Each prints five lines (the briefing, "Summon logged", "Week:", his answer, "Week:") from
   fewer than a dozen templates: about 100 lines, each template seen 10 to 20 times, none varying but the numbers.
4. **Every week plays under the same rules.** Apart from the catch-up edge, week 9 is week 1 with different dice. The
   Interest Curve entry found the same thing from the other side (a flat week); a surprise inside the rules would help both.
5. **The list is the best-designed surprise we have and it is a one-shot.** It is secret, it reveals itself in front of
   the group at the moment it hits, and it gives Zennit something to lose and win. After a place is revealed the group
   knows it, and nothing in the game remembers.
6. **We do not know what surprises Zennit.** He sees every summon from the receiving end; the one thing he does not choose
   is who, where and when. The playtest should ask.

**Stale note found in passing:** the README's Status table said no place is marked `remote`, so the Far Flung badge could not
be earned. Ten far-flung maps have been marked for a while (from memory, to be confirmed with `/sc where`); the row is fixed.

**Proposed changes** (none built yet)

| # | Change | Fixes | Cost |
|---|---|---|---|
| A | **Pools of lines**: three to five variants for each line that repeats most (his answers, "Summon logged", the week's result, the last die), same facts, picked at random without an immediate repeat | 2, 3 | Wording and one small helper; more flavour in chat |
| B | **A whim of the week**: each Monday the Index draws one of about eight small rule twists (dungeons count double, ties go to the group, a helper adds +10), announced at login and shown in the briefing; it follows from the week number, so every client agrees and nobody keeps books | 4 | A rule layer: wording, the balance simulation, and a toggle |
| C | **A recording sheet**: the lines to record for each clip category, so the group can fill `Media/clips` in one evening | 2 | A page of wording; no code |
| D | **The list remembers**: when a place on his list hits a second time, the Index says so ("Darnassus again. The Index is beginning to see a pattern.") | 5 | Wording and a counter on the log |

**Our answer:** build all four.

**Built**
- **A, pools of lines** (`Voice.lua`). His seven answers, "Summon logged", the "Week:" line, the last die and the week's result
  each come in three variants with the same facts; one is picked at random and never the one before. The self-test checks that a
  variant is never repeated, that all three get used, and that every answer variant still names its numbers.
- **B, the whim of the week.** About half the weeks the Index draws one of four twists from the week number (the same on every
  client, nothing synced): *distracted* (his edge 5 lower), *attentive* (5 higher), *a helpers' feast* (+8 a helper) or *the
  helpers are tired* (+2). I measured each in the week model before choosing the size (group's chance, quiet / normal / trying):

  | Whim | Quiet | Normal | Trying |
  |---|---|---|---|
  | A plain week | 15% | 27% | 63% |
  | Distracted (edge 5) | 19% | 32% | 69% |
  | Attentive (edge 15) | 12% | 23% | 58% |
  | A helpers' feast (+8) | 15% | 31% | 70% |
  | The helpers are tired (+2) | 15% | 24% | 56% |

  Each moves a normal week 3 to 5 points either way, so the deck is about neutral and no week is much easier than another. I
  left out whims that change the dice (a fourth die moves a trying week from 63% to 45%, a second from 63% to 83%): too large for
  a week to survive, and he can already close the Index. Weeks off have none. `Week.RULES.whims = false` turns the layer off.
  It is said at login, in the briefing, in "The Index today" and in `/sc week`.
- **C, the recording sheet** (`design/recording-sheet.md`): the six clip categories, what triggers each and who hears it, and six
  or so lines to start from, with how to convert, name and install the takes. It makes the dormant random picks real. It is in
  the repo so it is not lost, and so are the takes, which means Zennit can read and hear them there.
- **D, the list remembers.** When a place on his list comes up a second time, the answer line adds "Darnassus again. The Index is
  beginning to see a pattern." (then "for the third time"). Never the first time, so the list keeps its secret until it hits. It
  reads only what his answers already say (`listed`), so every client agrees.

**To decide before building**
- How much extra flavour in chat before it becomes the reading the group dislikes? (Asked at the playtest.)

**To watch in playtests**
- Which lines does the group stop reading? Which do they repeat to each other?
- Does Zennit use his list to surprise, or does he forget it is there?
- Does anyone ask what next week's rules will be?

### 2026-10-04 · Lens of Elegance, with the Lens of Balance: which rules earn their place

**The questions (paraphrased):** what does each rule do for the game? Could it go without changing the experience? Do the
rules interact in ways the players cannot see? Is there a small core a player can hold in their head? We have added a rule
or two with every lens, so this is the moment to take stock.

**An ablation of the weekly race.** The weekly model that reproduces the Fairness table (15%, 28%, 64%), with one rule changed
at a time. The group's chance of winning a week: quiet (2 summons, no helpers), normal (3, one helper), trying (5 dungeons, 2 helpers).

| Rule changed | Quiet | Normal | Trying |
|---|---|---|---|
| **As built** | 15% | 27% | 63% |
| No head start (0 instead of 2) | 15% | 28% | 63% |
| No helper bonus | 15% | 23% | 52% |
| No edge for him on the dice (the most catch-up can give) | 23% | 39% | 74% |
| His edge at +20 (the most it can take) | 9% | 18% | 52% |
| No dice limit | 15% | 27% | **30%** |
| No secret list | 16% | **42%** | **87%** |
| The list on half of all places | 12% | 16% | 42% |
| The list on three places in four | 7% | 7% | 20% |
| **The list on every place** | **0%** | **0%** | **0%** |

**The rules, and what each is worth** (the numbers are points of a normal week's chance)

| Rule | What it does | Worth | Verdict |
|---|---|---|---|
| Only summons of him count | He is the target (Essential Experience) | The premise | Core |
| Three dice a week | Makes *when to roll* a choice | 33 points on a trying week | Core |
| His +10 edge, with catch-up and the whim | The one smooth dial | 12 points either way | Core |
| Helpers add +5 (two at most) | Gives the helpers a part | 4 to 11 points | Core: it is the helpers' story |
| Cap of 10, he may close after 5 | His way out, neutral by design (Griefing entry) | About 0 | Keep |
| His week off is filler | Makes his wins a pause | 0 a week, 4 weeks a season | Keep |
| Whims | Variety | 3 to 5 points, on purpose | Keep |
| **Head start of 2** | Was the difficulty dial | **0 to 1 point** | **Dead weight** |
| **His secret list** | Something for him to win | **15 to 24 points, unbounded** | **The strongest rule, and the one with no limit** |

**Findings**
1. **The list is the strongest rule and has no bound.** At the 1 in 4 we assumed, it is worth 15 points of a normal week. But it
   is whatever Zennit makes it: an entry matches any place whose subzone or zone name contains its text, with no minimum length and
   no limit on entries, so a single letter matches most places. At every place the group's chance is 0% at any effort.
   The design (Griefing entry) was that he can say "enough", not that he can decide the week; this decides it.
2. **The head start does nothing.** From 2 to 0 the chance moves by a point, because it only matters in a week of one or two
   points of summons (a city). It is still printed in several lines ("including a 2 point head start") and the season band.
3. **The rules are a dozen, and no line says them all.** A player has to hold what counts, the cap and the close, the dice,
   the edge, the helpers, the list, the week off, the catch-up, the whim, the season and the points by place. The intro narrates
   eight of them and was written before the catch-up, the whim, the filler and the last die; the README is the only whole list.
4. **Two edges stack.** The whim (5 either way) and the catch-up (5 or 10) both move his edge, so it ranges from 0 to 25 and
   the group's trying week from about 47% to over 74%. The floor at 0 stops it being a handicap; nothing else bounds it.

**Proposed changes** (none built yet)

| # | Change | Fixes | Cost |
|---|---|---|---|
| A | **Bound the list**: at most 5 entries, each at least 4 letters (a place, not a letter). Entries beyond the fifth or shorter than four letters stop matching | 1 | Two constants and a check |
| B | **Drop the head start** (0 for the new rules; the old weeks keep theirs): the lines and the band no longer mention it | 2 | One constant, a few strings, the Fairness table's note |
| C | **A rules card**: `/sc rules` (and a Tools button) prints this week's rules with the live numbers: what counts, the cap and the close, his dice, his edge with its catch-up and whim, what a helper adds, the list's size, the week off. One source of truth, never stale | 3, 4 | A function that reads the same numbers the game does |
| D | **Re-voice intro scenes 9 and 10** to the current rules | 3 | Wording, then re-recording: the largest |

**To decide before building**
- Bound the list, and how tightly? (Five entries of four letters or more is the proposal.)
- Is the head start worth keeping for its tie-breaking, or does it go?

**To watch in playtests**
- How wide does Zennit make his list, and how often does the Index say "again"?
- Can the group say the rules back? (If not, the card is not enough and the intro needs redoing.)

## Decisions

| Date | Decision | Lens | Why |
|---|---|---|---|
| 2026-10-04 | The group should have to try to beat Zennit; "he wins more weeks than he loses" no longer holds | Essential Experience | A win should be earned and reachable |
| 2026-10-04 | "Trying" means beating him at his own answers; keep it tongue in cheek | Essential Experience | Summoning Zennit should be how to win, not a risk to avoid |
| 2026-10-04 | New race from 5 Oct 2026: only summons of him count, 5 a week, 3 dice a week, +5 per helper, head start 2 | Fairness, Meaningful Choices | See the Fairness entry: effort pays, and his list keeps his week off within reach |
| 2026-10-04 | 5 to 10 summons of him count a week; he can close the Index for free once 5 are filed | Griefing / Friendship | He gets a way out; closing can't lock in a lead before the fair minimum |
| 2026-10-04 | Show where the week stands when it changes: briefing at the ritual, a chat line after summons and answers, in his popup, and the lead in the band | Visible Progress, Feedback | Progress was only in the hub, and the facts that decide how to summon him came too late |
| 2026-10-04 | Helpers named when their bonus wins a roll; the assistants prompt saves itself; Zennit told he can ignore a summon; no helper badges | The Player | The group likes banter and doing things together, and hates bookkeeping; rewards don't motivate them |
| 2026-10-04 | His week off is real: summons of him are filler, the race skips the week, and the gags carry on | Interest Curve | His wins were a story beat with no effect; a pause makes them count without silencing the joke |
| 2026-10-04 | Catch-up: Zennit's dice edge moves 5 (a lead of 2 wins) or 10 (3 or more) toward the side that is behind | Interest Curve | Blowouts were 49% of seasons at normal effort; the Index now leans on the scale, gently |
| 2026-10-04 | Keep five weekly wins to a finale (a season of about 11 weeks at normal effort) until a real season shows how long it takes | Interest Curve | Simulated length is long, but the group's real pace is unknown; shortening later is one constant (`Week.WINS`) |
| 2026-10-04 | No rule change for Skill and Chance; say so when his last die is spent | Skill and Chance | A week is mostly chance and a season mostly skill, and the group's best order depends on how he rolls; the moment their ordering pays off was invisible |
| 2026-10-04 | The Index remembers named moments, the silver he is paid, and a keepsake of each finished season; players named by character | Story and Emotion | The personal material was in the log and scrolled away; naming players is what a friend group repeats |
| 2026-10-04 | Pools of lines, a whim of the week (four small twists, about half the weeks), a recording sheet and a list that remembers | Surprise | The surprises were in the people and the story only; the repeating lines were wallpaper by week 9 and every week played under the same rules |
