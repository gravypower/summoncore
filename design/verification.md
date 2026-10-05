# Verification plan: confirming it works in the game

Everything in this addon was built and tested against stubs (a fake WoW for Lua 5.1). Some parts have run in the real game
(ritual detection, the addon messages, the solo tools); a lot has not. This is the plan for finding out, in an order that stops
early when something basic is wrong. The tool is **`/sc check`** (`Check.lua`): it runs what can be run by itself, watches the rest
while you play, remembers each result in your saved variables, and prints a report to paste back.

## How to use it

| Command | What it does |
|---|---|
| The **Tools tab** (`/sc`, then Tools), the CHECKS row | The same, with buttons: RUN AUTO, NEXT (shows the steps for the next check), PASS / FAIL / SKIP (record it and move on), TRACE and REPORT. The label shows how many have passed (3/25) |
| `/sc check` | The list with a result against each, and the next thing to do |
| `/sc check auto` | Runs the automatic checks (nothing to do but read) |
| `/sc check <id>` | The steps for one check, what to expect, and what breaks if it fails |
| `/sc check pass <id> [note]` / `fail` / `skip` | Records what you saw. A note is worth adding on a failure |
| `/sc check trace` | What the summon prompt and the answers did, newest last (the last 40 events) |
| `/sc check report` | Opens a window with the report to copy (Ctrl+A, Ctrl+C), and prints it to chat |
| `/sc check reset` | Clears the results to start again |

The checks marked "the addon marks this itself" (accept, decline, the cost of a second decline, a writ, a dice roll ended by the
prompt, the summoner's name) turn green on their own when they happen for real. Everything else you record by hand.

**What to send back:** `/sc check report` after each phase. It has the counts, every failure with its note, the errors the addon
caught (`/sc errors`) and the trace. That is enough to fix most things without a second round.

## Phase 1: by yourself, ten minutes, any character

1. `/sc check auto`. Eight checks: the game's calls exist (a-api), the prompt hooks installed (a-hooks), every map ID is a real map
   (a-places), the self-tests pass in the game (a-selftest), every tab builds (a-window), the key binding's names exist (a-binding),
   the message prefix is registered (a-prefix) and nothing has thrown (a-errors).
2. **Stop here if a-api, a-hooks or a-selftest fail.** Send the report: the rest depends on them.
3. `/sc check s-popup` (a pretend summons: the form, one-click dice), `s-key` (bind the writ key and press it), `s-fit` (click through
   every tab), `s-lines` (read the chat lines on a test summons), and `s-sound` after a full restart.

## Phase 2: with one friend, an hour, both on the same version

Both run `/sc check auto` first. Decide who is the warlock and who is Zennit (his character, or `/sc zenit` on the admin's).

1. `d-sync`: both `/sc sync`. If this fails nothing else will work; send both reports.
2. `d-ritual`: a real ritual with two helpers: the briefing, the log line, his form.
3. `d-overlap` and `d-name`: look at where the two prompts sit, then `/sc check trace` for the summoner's name.
4. The decisions, one summons each (the addon marks them as they happen): `d-accept`, then `d-decline` (his one free decline), then `d-cost`
   (a second decline), then `d-writ` (a writ armed with the key, then a decline).
5. `d-dice` (one click each) and `d-dice-ends` (accept in the game during a roll).
6. `d-expire`: let the prompt run out and read the trace. This is the one most likely to surprise us.
7. `d-say` (a group), and `d-silver` (trade or mail) if there is time.

## Phase 3: a week with the group

Then `design/playtest.md`: the report each Monday and the questions for people. Nothing in `/sc check` replaces that; it only makes
sure the things the playtest relies on work.

## What each unknown costs, and the fix

| Check | If it fails | The fallback in the addon | The fix |
|---|---|---|---|
| a-api, a-hooks | The game's Accept / Decline is not seen | The Index's form answers as it always did; an unanswered summons counts as accepted | Find what this client calls those functions (`/sc check` lists what is missing) |
| d-name | The summoner's name is hidden | The newest summons waiting is matched | None needed |
| d-expire | An expired prompt counts as a decline | None: it would cost his free decline | Look at `C_SummonInfo.GetSummonConfirmTimeLeft` when the call comes: near zero means it expired, not that he declined |
| d-overlap | The two prompts cover each other | None | Move the Index's form (lenses, Resonance, A) |
| s-key | No key binding | `/sc writ` still works | Check `Bindings.xml` and the names |
| d-say | `SendChatMessage` is blocked | It says so; `/sc week` still works | Use a printed line instead |
| a-places | A map ID is wrong | That place scores as a zone (3) | Fix the ID in `Scoring.lua` (`/sc places` lists them) |
| a-selftest | A rule behaves differently in the game | None | The failing test's name says which |
