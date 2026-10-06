# Season two: "Zennit and the Audit" (outline, draft)

Status: **an outline for review**. Nothing here is built. Once the premise and the beats are agreed, the next steps are the full
narration (same length and style as season one's scenes), the art in `tools/intro/source.html`, the voice
(`zenit-narrator-audio`), and the code that tells the seasons apart (see [What the code needs](#what-the-code-needs)).

Decided so far (2026-10-06):
- **One arc, two openings.** Season one ends in one of two ways (Zennit in the clerk's chair, or Zennit freed). Season two has one
  story for both, with a short opening for each ending that explains why the race starts again.
- **Mechanics wait for the beta.** This outline is story only. New rules or a new mechanic are decided around week 2 or 3 of the
  beta, once `/sc report` has real numbers. The [hooks](#hooks-for-mechanics-not-decided) below are places a rule *could* echo the
  story, not decisions.

## Why the timing matters

The group could take season one's finale in **5 weeks** if it won every week. Zennit needs at least **9**, because each of his wins
is followed by his week off. A typical season is about 10 to 11 weeks. Season two has to be in a release, and installed by the group,
**by about week 4 of the beta**.

## The premise

The Cosmic Index of Summonable Persons has never been audited. In nine thousand years nothing in it changed, apart from one sneeze,
so nobody thought it needed checking. Season one changed it:
- if **Zennit won**, a clerk *added entries* (the party, in alphabetical order, with notes of thanks);
- if **the group won**, a spell *issued a receipt* (the Ritual stamped Form 27B slash 6).

Either is unheard of, and either sets off the audit. **The Auditor** arrives. The Auditor is more procedural than the clerk ever was,
and carries a stamp that reads *Under Review*. Until the audit closes, Zennit is entered as "pending review", which means summonable
again, and every summons is filed as **evidence**. The race is the audit: each week is a session of it.

The twist, revealed halfway down Zennit's trunk: the sneeze that blew Zennit's name to the letter Z also blew another entry out of
the Index altogether. That entry was the Auditor's. The Auditor has never been summoned, not once, and has never had a week off.

The tone stays the same as season one: deadpan, paperwork, and **both endings kind to Zennit** (`design/lenses.md`, Griefing /
Friendship). This time the group is in the story by name. They are called as witnesses.

## The two openings

Each opening is two scenes. It plays once, when season two starts, and comes back with "Previously on". The client picks the
opening from how the last season ended (`Week.Season().finales`).

### Opening A: after the clerk ending (Zennit won season one)

1. **"Additions"** (about 24 s). Draft narration: *For nine thousand years, nobody added anything to the Index. Then Zennit, newly
   Clerk, added an entire party, in alphabetical order, with notes of thanks. Somewhere in a building that does not appear on any
   map, a bell rang that had never rung before. It was the bell for audits.*
2. **"Pending review"** (about 26 s). *The Auditor arrived on a Monday, with a stamp. The Auditor found the chair in order, the pen in
   order, and the clerk not in order at all, having been entered in the wrong book. Zennit was moved, gently, to "pending review".
   Until the audit closed, he was to present himself whenever summoned, as evidence. He accepted. He accepts everything now. He has
   been asked to stop apologising.*

### Opening B: after the freeing (the group won season one)

1. **"The receipt, examined"** (about 24 s). *A receipt issued by a spell is, in the Index's view, irregular. A receipt issued by a
   spell to itself is a matter for audit. The bell for audits, which had not rung in nine thousand years, rang.*
2. **"Pending review"** (about 26 s). *The Auditor arrived on a Monday, with a stamp, and suspended the receipt pending review.
   Zennit, who had been free for almost a week and was just getting used to it, felt the small click again, in reverse. He was
   entered as "pending review", summonable as evidence until the audit closed. The Ritual apologised. The Auditor noted the apology
   as evidence too.*

### Opening C: after a season the admin stopped

A season stopped with `/sc season stop` has no finale. Season two then plays a neutral opening: Opening B's first scene without the
receipt ("The Index has been changed, and nobody can say how. The bell for audits rang."), followed by "Pending review". This could
also be one scene, typed and silent, like "The Index today".

## Zennit's trunk: the audit, from his side (z1 to z5)

Two scenes each, three for the finale, as in season one.

| Key | Title | Beats |
|---|---|---|
| z1 | **Gardening leave** | His week off is filed as "gardening leave pending audit". He has no garden. He requests his own file, to see what is being audited. The request is filed. |
| z2 | **The missing entry** | His file arrives, very thin. Using the syllabus (season one's modules), he cross-checks the Index and finds a gap near the sneeze: one entry missing entirely, its line still ruled. The name has been blown off the page. |
| z3 | **The other casualty** | The missing name is the Auditor's. The sneeze took it, so the Auditor has never been summoned, and has never had a week off. Zennit understands the Auditor better than he would like to. |
| z4 | **The first summons** | Zennit writes the Auditor's name back in, in pencil, and summons the Auditor, a ritual no one has ever done. The Auditor arrives slightly confused, which Zennit recognises, and is handed a small cake, which the Auditor does not trust. |
| z5 | **Persons in good standing** (finale) | 1. The Auditor reviews the pencilled entry and inks it in. 2. The audit closes: the Auditor signs off the Index, and Zennit, as "Persons in Good Standing". 3. The Auditor takes a week off, the first in nine thousand years, and sends Zennit a postcard. The postcard is from one of the far-flung places. |

## The group's trunk: the party as witnesses (g1 to g5)

| Key | Title | Beats |
|---|---|---|
| g1 | **Called to give evidence** | The party is summoned for once, as witnesses, by a ritual nobody in the room cast. They arrive slightly confused. Zennit is very understanding about it. |
| g2 | **Exhibit A** | The party's evidence from season one (the carbon copy, or the cake box, depending on the opening) is entered as Exhibit A. The Auditor stamps it *Received*, which the party takes as a compliment. |
| g3 | **The character witness** | The Ritual of Summoning testifies for Zennit. It is nervous, glows in the wrong places, and is very sincere. The Auditor notes all three. |
| g4 | **The question** | The Auditor asks the party the only question the audit has: "Why do you keep summoning him?" The party considers this. The answer is due at the finale. |
| g5 | **Summoned out of affection** (finale) | 1. The party answers: "Because he comes." 2. The Auditor reads the whole log of summons, every one, and finds that being summoned out of affection is not an offence. The finding is stamped, in triplicate. 3. The audit closes. Zennit is given Form 27B slash 7, a Request to Be Summoned, which he may fill in whenever he likes. He fills it in at once. It was, by general agreement, a slightly larger cake. |

**The players by name.** g1 and g5 are where the witnesses are named: the list of who summoned him or helped this season, as the
keepsake already works it out (`Ledger.Seasons`). Names cannot be in the recorded narration, so they are typed over the picture or
added to "The Index today", the way the silver is in season one.

## "The Index today": new lines for season two

These follow `Ledger.LINES` (one fixed sentence each, so each can be recorded).

```
recap_z1 = "Zennit is on gardening leave pending audit. He has no garden, and has asked for his file."
recap_z2 = "Zennit has found a gap in the Index near the sneeze, with the line still ruled."
recap_z3 = "Zennit knows whose entry the sneeze blew away, and wishes he did not."
recap_z4 = "Zennit has summoned the Auditor, which nobody had ever done. The Auditor did not trust the cake."
recap_g1 = "The party has been called to give evidence, and arrived slightly confused."
recap_g2 = "The party's evidence has been entered as Exhibit A, and stamped Received."
recap_g3 = "The Ritual has given a character reference for Zennit, and glowed in the wrong places."
recap_g4 = "The Auditor has asked the party why they keep summoning him. The answer is due."
last_zennit_2 = "Last season ended with the audit closed, and the Auditor on leave for the first time. Zennit has a postcard."
last_group_2 = "Last season ended with a finding of affection, stamped in triplicate. Zennit holds Form 27B slash 7."
end_zennit_2 = "Zennit is one win from closing the audit himself, and the Auditor is looking at a calendar."
end_group_2 = "The party is one win from answering the question, and has started rehearsing."
empty_audit = "The audit is open, and its file is empty. Nobody has won a week."
```

## The size of it

| Piece | Count | Notes |
|---|---|---|
| Narrated scenes | 26 | 4 for the openings (A and B), 11 for each trunk. Season one has 32 |
| Narration | about 11 minutes | At season one's pace, about 25 s a scene |
| Art | 26 scenes | New scenes in `source.html`, rendered by `render_intro.ps1` (on Aaron's PC). The Auditor needs a design. Some backgrounds can be reused: the corridor, the desk, the cellar |
| Ledger lines | 13 | Recorded the way season one's are |
| Opening C | 1 | Typed and silent, so no art or voice of its own |

## What the code needs

This is separate from the story, and can be built before the story is final.

- **A season number**, worked out from the log so every client agrees: count the finales and the admin's season starts in
  `Week.Season`.
- **Chapters per season**: keys such as `2z1` or a `season` field on each scene, the opening chosen by the last finale, and
  `CHAPTER_KEYS`, the Story tab, "Previously on", "Show the group" and the `V` sync message made season-aware.
- **A client without season two** must not replay season one's chapters as if they were new. It should say that the season has moved
  on and the addon needs updating.
- **The intro for a newcomer**: season one's intro is still the setup (who Zennit is, the sneeze, the rules), so a newcomer plays it,
  then this season's opening. Check that `/sc tour`, which waits for the intro, still waits for the right thing.
- **The Ledger** takes its lines by season (`recap_*`, `last_*`, `end_*`).

## Hooks for mechanics (not decided)

These are places where a rule could echo the story. They are listed so the beta data has something to be held against, not as
plans. Each would still have to earn its place in `design/lenses.md`.
- **Evidence**: a summons to a far-flung place could be "entered into evidence" (the postcards already do this in season one).
- **Witnesses**: the helpers are the witnesses; a helper pair that tips a roll could be named in the chapter's typed text.
- **Form 27B slash 7**: in g5, Zennit gains the right to summon the party. In play, that could be one week where his summons of the
  group count. This is a big rule change, and only if he wants it.
- **The Auditor's postcard** (z5) points at the parked "Index's request of the week" (`README.md`, Parked for later).

## Questions for you

1. Is the audit the right premise, or does it repeat season one's paperwork too closely? Another option is a new place (a second
   Index, for the Horde) or a new character with a different problem.
2. Should the Auditor have a name, or stay "the Auditor", the way "the clerk" stays the clerk?
3. Does Zennit see the outline? The story is partly his: season one's open question was which ending he wants. Asking him what he'd
   like from season two (without spoilers) could feed the z trunk.
4. Should season three be planned now? Season two's endings would need openings of their own, and the same one-arc design would
   work again.
