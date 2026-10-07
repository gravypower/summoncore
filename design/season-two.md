# Season two: "Zennit and the Audit" (outline, draft)

Status: **premise and twist agreed; narration drafted** ([below](#narration-draft)); **the code is built** (v0.26.0, see
[The code](#the-code)); **the art and the voice are rendered** (v0.27.0): 26 scenes drawn in `tools/intro/source.html` and narrated,
and the 13 "Index today" lines recorded. Nothing has been seen or heard in the game yet.

Decided so far (2026-10-06):
- **One arc, two openings.** Season one ends in one of two ways (Zennit in the clerk's chair, or Zennit freed). Season two has one
  story for both, with a short opening for each ending that explains why the race starts again.
- **The audit is the premise** (2026-10-07).
- **The Auditor is Poogs in disguise** (2026-10-07). He wanted to keep summoning Zennit. He is unmasked at the end of **both**
  trunks, so the reveal lands whichever side takes the season. Until then the story calls him only "the Auditor", with no
  pronouns that would give him away.
- **Zennit is not consulted on season two.** Asking him what he wants from the story is kept for season three.
- **Season three is not planned yet.**
- **Only a finale moves the story to its next season** (2026-10-07). A season the admin stops and starts again is the same season,
  so a test season before the beta cannot skip season one's story. That leaves no "season stopped with no finale" opening to
  write, so Opening C is dropped.
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

**The twist: the Auditor is Poogs.** When season one ended, Zennit was going to stop being summoned, either because he was too
busy being the clerk or because he was free. Poogs was not ready for that. So he rang the bell for audits himself, borrowed a stamp,
and bought a hat slightly too large. Pending review means summonable, and summonable was all he wanted. He is unmasked in the
finale of both trunks: by Zennit, who works it out (z5), or in front of the whole party, when the Auditor reads their answer (g5).

**The clues**, so a second viewing plays fair:
- Poogs is never at the long table with the Auditor. He always sends apologies (g1, g2).
- The Auditor is not in the Index. There is no entry for any Auditor, anywhere (z2).
- The bell's rope is new, and there is a soul shard in the dust beneath it, the kind a warlock loses (z3).
- The Auditor's ink is a faint green, the colour of a warlock's fire.
- The Auditor knows Zennit's summons by heart without opening the file (z1).
- The notebook entered as Exhibit A is in neat, slanted, familiar handwriting, and nobody at the table remembers keeping it (g2).
- The Ritual greets the Auditor like an old friend: "we work together most Tuesdays" (g3).
- The Auditor can cast a Ritual of Summoning from memory, in under a minute, and Zennit recognises it from the receiving end (z4).

The tone stays the same as season one: deadpan, paperwork, and **both endings kind to Zennit** (`design/lenses.md`, Griefing /
Friendship). The twist is kind as well: the only crime in the audit is wanting to keep summoning a friend. This time the group
is in the story by name. They are called as witnesses, and one of them is the Auditor.

## The two openings

Each opening is two scenes. It plays once, when season two starts, and comes back with "Previously on". The client picks the
opening from how the last season ended (`Week.Season().finales`).

### Opening A: after the clerk ending (Zennit won season one)

1. **"Additions"** (about 24 s). Draft narration: *For nine thousand years, nobody added anything to the Index. Then Zennit, newly
   Clerk, added an entire party, in alphabetical order, with notes of thanks. Somewhere in a building that does not appear on any
   map, a bell rang that had never rung before. It was the bell for audits. Nobody saw who rang it.*
2. **"Pending review"** (about 26 s). *The Auditor arrived on a Monday, with a stamp and a hat slightly too large. The Auditor found the chair in order, the pen in
   order, and the clerk not in order at all, having been entered in the wrong book. Zennit was moved, gently, to "pending review".
   Until the audit closed, he was to present himself whenever summoned, as evidence. He accepted. He accepts everything now. He has
   been asked to stop apologising.*

### Opening B: after the freeing (the group won season one)

1. **"The receipt, examined"** (about 24 s). *A receipt issued by a spell is, in the Index's view, irregular. A receipt issued by a
   spell to itself is a matter for audit. The bell for audits, which had not rung in nine thousand years, rang. Nobody saw who rang
   it.*
2. **"Pending review"** (about 26 s). *The Auditor arrived on a Monday, with a stamp and a hat slightly too large, and suspended the
   receipt pending review.
   Zennit, who had been free for almost a week and was just getting used to it, felt the small click again, in reverse. He was
   entered as "pending review", summonable as evidence until the audit closed. The Ritual apologised. The Auditor noted the apology
   as evidence too.*

## Zennit's trunk: the audit, from his side (z1 to z5)

Zennit's side is the detective story: he works out who the Auditor is. Two scenes each, three for the finale, as in season one.

| Key | Title | Beats |
|---|---|---|
| z1 | **Gardening leave** | His week off is filed as "gardening leave pending audit". He has no garden. He asks to see his file. The Auditor recites his summons without opening it. |
| z2 | **No such entry** | His file is very thin. Using the syllabus, he looks the Auditor up in the Index. There is no Auditor, under A or anywhere else. Then who rang the bell? |
| z3 | **The bell** | He finds the bell for audits. The rope is new, frayed at the height of an ordinary person, and in the dust beneath it is a soul shard, the kind a warlock loses. |
| z4 | **From memory** | He asks the Auditor to summon him, "for the evidence". The Auditor casts the ritual from memory, in under a minute. Zennit arrives and says nothing. He knows that ritual. He has been on the other end of it every week. |
| z5 | **Unmasked** (finale) | 1. Zennit closes the audit by procedure: it needs the Auditor's name, for the entry. The Auditor takes off the hat. It is Poogs. 2. Poogs explains: he was not ready to stop summoning Zennit, so he rang the bell himself. He is very sorry, though not entirely. 3. Zennit enters him under P, in ink ("Poogs. Summons Zennit, persistently. Not an offence."), stamps it Correct, hands back the hat, and says: same time next week. |

## The group's trunk: the party as witnesses (g1 to g5)

The group's side is the courtroom: the clues pile up in front of them, and they do not see it.

| Key | Title | Beats |
|---|---|---|
| g1 | **Called to give evidence** | The party is summoned as witnesses, all but one: Poogs sends apologies. Zennit hands round a leaflet, So You Have Been Summoned. |
| g2 | **Exhibit A** | A notebook of every summons of Zennit is entered as Exhibit A. Nobody at the table remembers keeping it; the handwriting is familiar. The Auditor stamps it *Received*, rather quickly. Poogs sends apologies again. (The notebook is the addon's log, in the story, and works after either opening.) |
| g3 | **The character witness** | The Ritual testifies for Zennit, nervous and sincere, and greets the Auditor like an old friend: "we work together most Tuesdays". The Auditor coughs. |
| g4 | **The question** | The Auditor asks the party: "Why do you keep summoning him?" For a moment it sounds less like a question than a confession. The answer is due at the finale. |
| g5 | **Summoned out of affection** (finale) | 1. The party answers: "Because he comes." The Auditor reads it three times, and takes off the hat. 2. It is Poogs, who missed every session as a witness because he was at every session as the Auditor. He explains. The party says they suspected since the notebook. They did not. 3. Poogs writes the finding (summoned out of affection, not an offence) and files himself under it first. Zennit is given Form 27B slash 7, a Request to Be Summoned, fills it in at once, and hands it to Poogs. A slightly larger cake. |

**The players by name.** Poogs is named in the recorded narration: his name is fixed, so it can be recorded. The rest of the
witnesses are named in g1 and g5 from the list of who summoned him or helped this season, as the keepsake already works it out
(`Ledger.Seasons`). Those names change from group to group, so they are typed over the picture or added to "The Index today", the
way the silver is in season one.

## "The Index today": new lines for season two

These follow `Ledger.LINES` (one fixed sentence each, so each can be recorded).

```
recap_z1 = "Zennit is on gardening leave pending audit. He has no garden, and has asked for his file."
recap_z2 = "Zennit has looked the Auditor up in the Index, and found no such entry."
recap_z3 = "Zennit has found the bell for audits, a new rope, and a soul shard in the dust."
recap_z4 = "The Auditor has summoned Zennit from memory, and he recognised the ritual."
recap_g1 = "The party has been called to give evidence. Poogs sent apologies."
recap_g2 = "A notebook of summons, in familiar handwriting, has been entered as Exhibit A."
recap_g3 = "The Ritual has given Zennit a character reference, and greeted the Auditor like an old friend."
recap_g4 = "The Auditor has asked the party why they keep summoning him. The answer is due."
last_zennit_2 = "Last season ended with the Auditor unmasked as Poogs, and entered in the Index under P, in ink."
last_group_2 = "Last season ended with Poogs unmasked, a finding of affection, and Zennit holding Form 27B slash 7."
end_zennit_2 = "Zennit is one win from closing the audit, and would like the Auditor to spell their name."
end_group_2 = "The party is one win from answering the question, and has started rehearsing."
empty_audit = "The audit is open, and its file is empty. Nobody has won a week."
```

## The size of it

| Piece | Count | Notes |
|---|---|---|
| Narrated scenes | 26 | 4 for the openings (A and B), 11 for each trunk. Season one has 32 |
| Narration | about 11 minutes | At season one's pace, about 25 s a scene |
| Art | 26 scenes | New scenes in `source.html`, rendered by `render_intro.ps1` (on Aaron's PC). The Auditor needs a design: a disguise (the hat, spectacles, the stamp) with Poogs recognisable underneath once you know. Some backgrounds can be reused: the corridor, the desk, the cellar |
| Ledger lines | 13 | Recorded the way season one's are |

## The code

Built in v0.26.0 (README, [Season two](../README.md#season-two)):
- **A season number**: `Week.Season().number`, worked out from the log, so every client agrees. Each finale adds one.
- **Keys by season**: `Week.ChapterKey` gives `z3` in season one and `2z3` in season two; `Week.OpeningKey` gives `2a` or `2b`, and
  `Week.Season().openings` lists each season's opening. The story player, the Story tab, "Previously on", "Show the group", the
  `V` sync message and `/sc week <key>` all take the new keys.
- **The scenes** are in `Season2.lua` and follow "The Index today" (scene 33), so season one's numbers do not move. Each borrows a
  season-one picture (`art`) and is typed and silent, timed to be read, until it is drawn and recorded.
- **A season with no story in this version** (season three, for now) shows its chapters as not written and says an update will
  have them; a client shown a chapter it does not have says the same.
- **"The Index today"** takes its story lines by season (`ST.seasonLines`). Season two's are typed and silent until recorded.
- **Self-test**: "season two: a finale opens the next season..." in `/sc synctest`.

Finished in v0.27.0: the scenes are drawn in `source.html` (the Auditor, Poogs, and the props: a hat, a stamp, the audit bell, a
soul shard) and rendered as `Media/intro_<n>.blp` and `intro_l<n>.blp` for scenes 34 to 59; the narration is rendered as
`tools/intro/narration/voice_<n>.ogg` and mixed into `Media/intro_<n>.ogg`; the cues, sentences and highlights are in
`IntroCues.lua`; the Ledger lines are in `Ledger.LINES` as `recap_z1_2` and so on, with their recordings in `Media/ledger`. A scene
is "recorded" when `IntroCues.lua` has a length for it, so a scene without a clip falls back to being typed and silent.
Poogs is the "horns" hero of the party (rust robe, grey horned cap); the Auditor's over-large hat covers that cap, and two white
horn tips show under its brim.

## Hooks for mechanics (not decided)

These are places where a rule could echo the story. They are listed so the beta data has something to be held against, not as
plans. Each would still have to earn its place in `design/lenses.md`.
- **Evidence**: a summons to a far-flung place could be "entered into evidence" (the postcards already do this in season one).
- **Witnesses**: the helpers are the witnesses; a helper pair that tips a roll could be named in the chapter's typed text.
- **Form 27B slash 7**: in g5, Zennit gains the right to summon the party. In play, that could be one week where his summons of the
  group count. This is a big rule change, and only if he wants it.

## Narration (draft)

The full text of every chapter scene, written to be read aloud the way season one's are, at about 24 to 30 seconds a scene. The
openings' text is in [The two openings](#the-two-openings) above. Words the narrator says differently from how they are written
follow season one: "Form 27B slash 7", never "27B/7".

### Zennit's trunk

**z1, Gardening leave**
1. *Gardening leave.* Zennit's first week off of the audit was filed, by the Auditor, as gardening leave pending audit. Zennit did
   not have a garden. He spent the week in a borrowed deckchair, beside a patch of earth the Index had provided for the purpose,
   wondering what, exactly, was being audited. On the Friday, he asked to see his file.
2. *By heart.* The Auditor did not open the file. The Auditor recited it: every summons of Zennit, with the date, the place, and
   what he had said, without once looking down. Zennit found this impressive. He also found it odd, in the way that a dog knowing
   your birthday is odd. He said nothing, and made a note.

**z2, No such entry**
1. *The thin file.* His file, when it came, was very thin. It held his name, the sneeze, and a note in the margin that said "see
   also". There was nothing to see also. Zennit, who had studied the syllabus, did what the syllabus had taught him. He looked the
   Auditor up in the Index, under A.
2. *Not under A.* There was no Auditor under A. There was no Auditor under Z, or under the sneeze, or anywhere at all. The Index
   had never had an Auditor. It had a bell for audits, because it had a bell for everything, but nobody had ever been appointed to
   answer it. Zennit wrote one question at the top of a clean page. Who rang the bell?

**z3, The bell**
1. *The rope.* The bell for audits hung at the end of a corridor nobody used. Its rope was new. It had been frayed, recently, at
   the height of an ordinary person, by someone who had pulled it with feeling. The dust beneath it had been disturbed by a pair of
   ordinary boots, which had walked in, and stood, and walked out again, in a hurry.
2. *The shard.* In the dust, where the boots had stood, was a soul shard. It was small, and purple, and faintly warm, the kind
   warlocks keep in a bag and lose down the back of the sofa. Zennit picked it up and turned it over. He knew several warlocks. He
   knew most of them rather well. He put the shard in his pocket, and went to see the Auditor.

**z4, From memory**
1. *For the evidence.* In the fourth week, Zennit asked the Auditor for a favour. Would the Auditor summon him, he asked, for the
   evidence? The Auditor hesitated, which auditors do not do. Then the Auditor stepped outside, gathered two helpers, and began. No
   book was opened. No notes were consulted. The ritual was cast from memory, in under a minute.
2. *Recognised.* Zennit arrived where he always arrived, slightly confused, and then not confused at all. He knew that ritual. He
   had been on the other end of it every week for a season: the same pace, the same flourish at the end, the same small impatience
   in the middle. He thanked the Auditor, politely. He said nothing else. He did not need to.

**z5, Unmasked (finale)**
1. *The hat.* In the fifth week, Zennit closed the audit himself, by procedure. An audit, the syllabus said, closes when the auditor
   is entered in the Index. He uncapped the pen and asked the Auditor, politely, to spell their name. The Auditor looked at the pen
   for a long time. Then the Auditor took off the hat, which had always been slightly too large. It was Poogs.
2. *Why.* Poogs explained. When the last season ended, he had worked out that Zennit would never be summoned again, and he had not
   been ready for that. So he had rung the bell himself, borrowed a stamp, and bought a hat. Pending review meant summonable. That
   was all he had wanted. He was very sorry. He was not, entirely, sorry.
3. *Under P.* Zennit wrote a new entry, under P, in ink. It said: Poogs. Summons Zennit, persistently. Not an offence. He stamped
   it Correct, a stamp that had never been used before. Then he handed Poogs back his hat, and his soul shard, and said: same time
   next week. The Index wrote that down.

### The group's trunk

**g1, Called to give evidence**
1. *Witnesses.* The group's first win of the audit was rewarded in an unexpected way. The party was summoned, all at once, by a
   ritual nobody in the room had cast, to a hall with a long table and a small sign that said Witnesses. They arrived slightly
   confused, one of them still holding a fork. All of them, that is, but Poogs, who sent apologies.
2. *The leaflet.* The Auditor accepted the apologies without looking up. Witnesses, the Auditor explained, are summoned, not
   invited, because an invitation can be declined. Zennit, at the far end of the table, was very understanding about it. He handed
   round a leaflet titled So You Have Been Summoned. He had written it himself, years ago, and never had anyone to give it to.

**g2, Exhibit A**
1. *The notebook.* The group's second win produced the evidence: a notebook. In it was every summons of Zennit, with the date, the
   place, the helpers, and what he had said. Nobody at the table remembered keeping it. The handwriting was neat, and slanted, and
   familiar, and nobody could quite say why. Poogs, once again, had sent apologies.
2. *Received.* The Auditor stamped the notebook Received, rather quickly, and entered it as Exhibit A. The party took this as a
   compliment, which the Auditor allowed. Zennit asked if he could see it. The Auditor said: after the audit. Zennit said he had a
   feeling about that. He did. It was the same feeling he had about most things, but stronger.

**g3, The character witness**
1. *The Ritual testifies.* On the group's third win, the Ritual of Summoning asked to give evidence. Nobody had called it. It turned
   up, glowing, in the witness chair, which was not built for a spell, with a statement about Zennit. The statement was mostly kind,
   and slightly too long. He always came, it said, even when he complained, and he complained very well.
2. *Old friends.* Halfway through, the Ritual noticed the Auditor, and glowed warmly, the way it glows at people it knows well. "Oh,
   hello," it said. "We work together most Tuesdays." The Auditor coughed, and wrote something down. The Ritual, realising it had
   said something, glowed in the wrong places for the rest of the afternoon. The party noted the glow. They did not note the cough.

**g4, The question**
1. *The question.* On the group's fourth win, the Auditor closed the notebook, set down the stamp, and asked the party the only
   question the audit had. "Why do you keep summoning him?" It was not unkind. For a moment, it sounded less like a question than
   a confession, though nobody at the table could have said whose.
2. *Due.* The party looked at one another. Several answers were offered, none of which were filed. The Auditor said there was no
   hurry: the answer would be due at the close of the audit, in writing, in triplicate. The party went home and thought about it.
   So, they would later realise, did the Auditor.

**g5, Summoned out of affection (finale)**
1. *The answer.* On the group's fifth win, the party came back to the long table with their answer, in triplicate. It was one line
   long. They had argued about it for a week and crossed out a great deal, and what was left said: "Because he comes." The Auditor
   read it three times, once per copy, which is procedure. Then the Auditor took off the hat.
2. *Unmasked.* It was Poogs. He had missed every session as a witness because he had been at every session as the Auditor. When
   the last season ended, he explained, he had not been ready to stop summoning Zennit. So he had rung the bell himself. The party
   said they had suspected since the notebook. They had not. Zennit said he had. He had.
3. *Form 27B slash 7.* Poogs wrote the finding himself, and stamped it, in triplicate: Zennit had been summoned persistently,
   unreasonably, and out of affection, which is not an offence. He filed himself under it first. Then Zennit was handed a new form,
   a Request to Be Summoned. He filled it in at once and gave it to Poogs. It was, by general agreement, a slightly larger cake.
