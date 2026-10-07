# Season two: "Zennit and the Audit" (outline, draft)

Status: **premise agreed; narration drafted** ([below](#narration-draft)). Nothing is built in the addon yet. The next steps are
the art in `tools/intro/source.html`, the voice (`zenit-narrator-audio`), and the code that tells the seasons apart (see
[What the code needs](#what-the-code-needs)).

Decided so far (2026-10-06):
- **One arc, two openings.** Season one ends in one of two ways (Zennit in the clerk's chair, or Zennit freed). Season two has one
  story for both, with a short opening for each ending that explains why the race starts again.
- **The audit is the premise**, and **the Auditor stays unnamed** (2026-10-07), the way the clerk stays "the clerk".
- **Zennit is not consulted on season two.** Asking him what he wants from the story is kept for season three.
- **Season three is not planned yet.**
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
| g2 | **Exhibit A** | Someone in the party kept a notebook of every summons of Zennit. It is entered as Exhibit A. The Auditor stamps it *Received*, which the party takes as a compliment. (The notebook is the addon's log, in the story; it works after either opening, where the carbon copy or the cake would not.) |
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
recap_g2 = "The party's notebook of summons has been entered as Exhibit A, and stamped Received."
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

## Narration (draft)

The full text of every chapter scene, written to be read aloud the way season one's are, at about 24 to 30 seconds a scene. The
openings' text is in [The two openings](#the-two-openings) above. Words the narrator says differently from how they are written
follow season one: "Form 27B slash 7", never "27B/7".

### Zennit's trunk

**z1, Gardening leave**
1. *Gardening leave.* Zennit's first week off of the audit was filed, by the Auditor, as gardening leave pending audit. Zennit did
   not have a garden. He spent the week in a borrowed deckchair, beside a patch of earth the Index had provided for the purpose,
   wondering what, exactly, was being audited. On the Friday, he asked to see his file.
2. *The request.* The request was received, stamped, and filed, which is the Index's way of saying yes without committing to
   anything. The Auditor noted that nobody had ever asked to see their own file before. The Auditor noted it twice, in different
   ink, and looked at Zennit for slightly longer than was necessary.

**z2, The missing entry**
1. *The thin file.* His file arrived the following week. It was very thin. It held his name, the sneeze, and a note in the margin
   that said "see also". There was nothing to see also. Zennit, who had studied the syllabus, did what the syllabus had taught him.
   He began to cross-check the Index, one entry at a time, near the letter Z.
2. *The ruled line.* Between two entries, at the place where the sneeze had landed, there was a gap. The line was still ruled. The
   ink had been blown clean off it nine thousand years ago, and nobody had noticed, because nobody had looked. Something had been
   written there once. Zennit put a small pencil tick beside it, and did not sleep particularly well.

**z3, The other casualty**
1. *Whose line.* It took him a week to find out whose line it was. The answer was in the Auditor's own paperwork, on the back of a
   form nobody had ever turned over. The sneeze that had blown Zennit's name to the letter Z had blown another name off the page
   entirely. It was the Auditor's.
2. *Never summoned.* The Auditor had never been summoned. Not once, in nine thousand years. No ritual had ever found the name,
   because the name was not there. The Auditor had never been called away, never been interrupted, and never had a week off.
   Zennit, who had once been summoned to a goat, understood this better than he would have liked.

**z4, The first summons**
1. *In pencil.* In the fourth week, Zennit wrote the Auditor's name back into the ruled line, in pencil, because pencil can be
   argued with. Then he gathered two helpers, who were puzzled but willing, and performed a Ritual of Summoning on a name no ritual
   had ever reached. The Ritual, which had been briefed, did its very best.
2. *The cake.* The Auditor arrived slightly confused, holding a stamp, in the middle of a sentence. Zennit recognised the
   expression. He had worn it for most of his career. He handed the Auditor a small cake, by way of welcome. The Auditor did not
   trust it. The Auditor ate it anyway, and noted, for the record, that it was adequate.

**z5, Persons in good standing (finale)**
1. *In ink.* In the fifth week, the Auditor reviewed the entry in pencil. It was in the right place, in the right order, and spelled
   correctly, which was more than could be said for most of the Index. The Auditor inked it in, with a steady hand, and stamped it.
   The stamp said Correct. It had never been used before.
2. *The audit closes.* Then the Auditor closed the audit. The Index was found sound, apart from one sneeze, now accounted for.
   Zennit was moved from pending review to Persons in Good Standing, a section so rarely used that it had a fine layer of dust. He
   would still be summoned, the Auditor said. That was not a fault. That was what it meant to be findable.
3. *The postcard.* The Auditor took a week off, the first in nine thousand years, and went somewhere very far away, with a beach.
   A postcard arrived for Zennit on the Thursday. It said, in full: "Weather adequate. Have been summoned twice. Both times by
   mistake. Thank you." The Index filed the postcard under correspondence, and, for the first time, under Z.

### The group's trunk

**g1, Called to give evidence**
1. *Witnesses.* The group's first win of the audit was rewarded in an unexpected way. The party was summoned. All of them, at once,
   by a ritual nobody in the room had cast, to a hall with a long table and a small sign that said Witnesses. They arrived slightly
   confused, mid-sentence, one of them still holding a fork.
2. *The leaflet.* The Auditor explained that witnesses are summoned, not invited, because an invitation can be declined. Zennit,
   seated at the far end of the table, was very understanding about it. He passed each of them a glass of water and a leaflet
   titled So You Have Been Summoned. He had written it himself, some time ago, and never had anyone to give it to.

**g2, Exhibit A**
1. *The notebook.* The group's second win produced the evidence. Someone in the party had kept a notebook. In it was every summons
   of Zennit, with the date, the place, the helpers, and what he had said, written down for reasons nobody could quite explain. It
   was produced at the long table, a little sheepishly, and slid across to the Auditor.
2. *Received.* The Auditor read the first page, and the second, and looked up. The notebook was entered as Exhibit A, and stamped
   Received. The party took this as a compliment, which the Auditor allowed, since it was not, strictly speaking, wrong. Zennit
   asked if he could see it. The Auditor said: after the audit. Zennit said he had a feeling about that.

**g3, The character witness**
1. *The Ritual testifies.* On the group's third win, the Ritual of Summoning asked to give evidence. Nobody had called it. It had
   simply turned up, glowing, in the witness chair, which was not built for a spell. It had prepared a statement. The statement was
   about Zennit, and it was mostly kind, and slightly too long.
2. *Three columns.* The Ritual said that Zennit always came, even when he complained, and that he complained very well. It glowed
   in the wrong places when it was nervous, which was throughout. The Auditor noted the statement, the glow and the sincerity, in
   three separate columns. Zennit looked at the ceiling for most of it. Afterwards he said it was fine. It had been fine.

**g4, The question**
1. *The question.* On the group's fourth win, the Auditor closed the notebook, set down the stamp, and asked the party the only
   question the audit had. "Why do you keep summoning him?" It was not unkind. It was the sort of question that had been waiting
   nine thousand years for someone to ask it.
2. *Due.* The party looked at one another. Several answers were offered, none of which were filed. The Auditor said there was no
   hurry: the answer would be due at the close of the audit, in writing, in triplicate. The party went home and thought about it,
   which is more than the Index had ever asked of anyone.

**g5, Summoned out of affection (finale)**
1. *The answer.* On the group's fifth win, the party came back to the long table with their answer, in triplicate. It was one line
   long. They had argued about it for a week and crossed out a great deal, and what was left said: "Because he comes." The Auditor
   read it three times, once per copy, which is procedure.
2. *The finding.* Then the Auditor read the notebook, every summons, to the end. It took an afternoon. The finding was written and
   stamped, in triplicate: that Zennit had been summoned persistently, unreasonably, and to several places with no roads, and that
   all of it had been done out of affection, which is not an offence. The Index accepted the finding.
3. *Form 27B slash 7.* The audit closed. Before the Auditor left, Zennit was handed a new form, Form 27B slash 7, a Request to Be
   Summoned, which he could fill in whenever he liked. He filled it in at once, at the table, and handed it to the party. They
   summoned him to his own celebration. It was, by general agreement, a slightly larger cake.

### Opening C (typed, silent)

*The Index has been changed, and nobody can say how. The bell for audits, which had not rung in nine thousand years, rang. The
Auditor arrived on a Monday, with a stamp, and entered Zennit as pending review: summonable, as evidence, until the audit closes.*
