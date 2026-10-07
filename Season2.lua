-- Season2: the scenes of season two, "Zennit and the Audit" (design/season-two.md). Intro.lua adds them to the story
-- after "The Index today", so season one's scene numbers, pictures and recordings do not move.
-- A chapter's key carries its season: 2a and 2b are the season's opening (after Zennit's finale of season one, or the
-- group's), 2z<n> and 2g<n> the chapters for each side's nth win. Nothing here is recorded or drawn yet: every scene is
-- typed and silent, and borrows the picture of a season-one scene (`art`, a scene number) until its own is rendered.
local ADDON, ST = ...

ST.seasonScenes = ST.seasonScenes or {}
ST.seasonScenes[2] = {
    -- the opening after Zennit's finale of season one (he became the clerk)
    { chapter = "2a", label = "Additions", art = 29, text = [=[For nine thousand years, nobody added anything to the Index. Then Zennit, newly Clerk, added an entire party, in alphabetical order, with notes of thanks. Somewhere in a building that does not appear on any map, a bell rang that had never rung before. It was the bell for audits. Nobody saw who rang it.]=] },
    { chapter = "2a", label = "Pending review", art = 1, text = [=[The Auditor arrived on a Monday, with a stamp and a hat slightly too large. The Auditor found the chair in order, the pen in order, and the clerk not in order at all, having been entered in the wrong book. Zennit was moved, gently, to pending review. Until the audit closed, he was to present himself whenever summoned, as evidence. He accepted. He accepts everything now. He has been asked to stop apologising.]=] },
    -- the opening after the group's finale of season one (Zennit was freed)
    { chapter = "2b", label = "The receipt, examined", art = 31, text = [=[A receipt issued by a spell is, in the Index's view, irregular. A receipt issued by a spell to itself is a matter for audit. The bell for audits, which had not rung in nine thousand years, rang. Nobody saw who rang it.]=] },
    { chapter = "2b", label = "Pending review", art = 1, text = [=[The Auditor arrived on a Monday, with a stamp and a hat slightly too large, and suspended the receipt pending review. Zennit, who had been free for almost a week and was just getting used to it, felt the small click again, in reverse. He was entered as pending review, summonable as evidence until the audit closed. The Ritual apologised. The Auditor noted the apology as evidence too.]=] },

    -- Zennit's trunk: he works out who the Auditor is
    { chapter = "2z1", label = "Gardening leave", art = 12, text = [=[Zennit's first week off of the audit was filed, by the Auditor, as gardening leave pending audit. Zennit did not have a garden. He spent the week in a borrowed deckchair, beside a patch of earth the Index had provided for the purpose, wondering what, exactly, was being audited. On the Friday, he asked to see his file.]=] },
    { chapter = "2z1", label = "By heart", art = 6, text = [=[The Auditor did not open the file. The Auditor recited it: every summons of Zennit, with the date, the place, and what he had said, without once looking down. Zennit found this impressive. He also found it odd, in the way that a dog knowing your birthday is odd. He said nothing, and made a note.]=] },
    { chapter = "2z2", label = "The thin file", art = 4, text = [=[His file, when it came, was very thin. It held his name, the sneeze, and a note in the margin that said see also. There was nothing to see also. Zennit, who had studied the syllabus, did what the syllabus had taught him. He looked the Auditor up in the Index, under A.]=] },
    { chapter = "2z2", label = "Not under A", art = 1, text = [=[There was no Auditor under A. There was no Auditor under Z, or under the sneeze, or anywhere at all. The Index had never had an Auditor. It had a bell for audits, because it had a bell for everything, but nobody had ever been appointed to answer it. Zennit wrote one question at the top of a clean page. Who rang the bell?]=] },
    { chapter = "2z3", label = "The rope", art = 16, text = [=[The bell for audits hung at the end of a corridor nobody used. Its rope was new. It had been frayed, recently, at the height of an ordinary person, by someone who had pulled it with feeling. The dust beneath it had been disturbed by a pair of ordinary boots, which had walked in, and stood, and walked out again, in a hurry.]=] },
    { chapter = "2z3", label = "The shard", art = 3, text = [=[In the dust, where the boots had stood, was a soul shard. It was small, and purple, and faintly warm, the kind warlocks keep in a bag and lose down the back of the sofa. Zennit picked it up and turned it over. He knew several warlocks. He knew most of them rather well. He put the shard in his pocket, and went to see the Auditor.]=] },
    { chapter = "2z4", label = "For the evidence", art = 3, text = [=[In the fourth week, Zennit asked the Auditor for a favour. Would the Auditor summon him, he asked, for the evidence? The Auditor hesitated, which auditors do not do. Then the Auditor stepped outside, gathered two helpers, and began. No book was opened. No notes were consulted. The ritual was cast from memory, in under a minute.]=] },
    { chapter = "2z4", label = "Recognised", art = 7, text = [=[Zennit arrived where he always arrived, slightly confused, and then not confused at all. He knew that ritual. He had been on the other end of it every week for a season: the same pace, the same flourish at the end, the same small impatience in the middle. He thanked the Auditor, politely. He said nothing else. He did not need to.]=] },
    { chapter = "2z5", label = "The hat", art = 27, text = [=[In the fifth week, Zennit closed the audit himself, by procedure. An audit, the syllabus said, closes when the auditor is entered in the Index. He uncapped the pen and asked the Auditor, politely, to spell their name. The Auditor looked at the pen for a long time. Then the Auditor took off the hat, which had always been slightly too large. It was Poogs.]=] },
    { chapter = "2z5", label = "Why", art = 7, text = [=[Poogs explained. When the last season ended, he had worked out that Zennit would never be summoned again, and he had not been ready for that. So he had rung the bell himself, borrowed a stamp, and bought a hat. Pending review meant summonable. That was all he had wanted. He was very sorry. He was not, entirely, sorry.]=] },
    { chapter = "2z5", label = "Under P", art = 28, text = [=[Zennit wrote a new entry, under P, in ink. It said: Poogs. Summons Zennit, persistently. Not an offence. He stamped it Correct, a stamp that had never been used before. Then he handed Poogs back his hat, and his soul shard, and said: same time next week. The Index wrote that down.]=] },

    -- the group's trunk: the party as witnesses, while the clues pile up in front of them
    { chapter = "2g1", label = "Witnesses", art = 7, text = [=[The group's first win of the audit was rewarded in an unexpected way. The party was summoned, all at once, by a ritual nobody in the room had cast, to a hall with a long table and a small sign that said Witnesses. They arrived slightly confused, one of them still holding a fork. All of them, that is, but Poogs, who sent apologies.]=] },
    { chapter = "2g1", label = "The leaflet", art = 13, text = [=[The Auditor accepted the apologies without looking up. Witnesses, the Auditor explained, are summoned, not invited, because an invitation can be declined. Zennit, at the far end of the table, was very understanding about it. He handed round a leaflet titled So You Have Been Summoned. He had written it himself, years ago, and never had anyone to give it to.]=] },
    { chapter = "2g2", label = "The notebook", art = 17, text = [=[The group's second win produced the evidence: a notebook. In it was every summons of Zennit, with the date, the place, the helpers, and what he had said. Nobody at the table remembered keeping it. The handwriting was neat, and slanted, and familiar, and nobody could quite say why. Poogs, once again, had sent apologies.]=] },
    { chapter = "2g2", label = "Received", art = 18, text = [=[The Auditor stamped the notebook Received, rather quickly, and entered it as Exhibit A. The party took this as a compliment, which the Auditor allowed. Zennit asked if he could see it. The Auditor said: after the audit. Zennit said he had a feeling about that. He did. It was the same feeling he had about most things, but stronger.]=] },
    { chapter = "2g3", label = "The Ritual testifies", art = 21, text = [=[On the group's third win, the Ritual of Summoning asked to give evidence. Nobody had called it. It turned up, glowing, in the witness chair, which was not built for a spell, with a statement about Zennit. The statement was mostly kind, and slightly too long. He always came, it said, even when he complained, and he complained very well.]=] },
    { chapter = "2g3", label = "Old friends", art = 5, text = [=[Halfway through, the Ritual noticed the Auditor, and glowed warmly, the way it glows at people it knows well. "Oh, hello," it said. "We work together most Tuesdays." The Auditor coughed, and wrote something down. The Ritual, realising it had said something, glowed in the wrong places for the rest of the afternoon. The party noted the glow. They did not note the cough.]=] },
    { chapter = "2g4", label = "The question", art = 23, text = [=[On the group's fourth win, the Auditor closed the notebook, set down the stamp, and asked the party the only question the audit had. "Why do you keep summoning him?" It was not unkind. For a moment, it sounded less like a question than a confession, though nobody at the table could have said whose.]=] },
    { chapter = "2g4", label = "Due", art = 8, text = [=[The party looked at one another. Several answers were offered, none of which were filed. The Auditor said there was no hurry: the answer would be due at the close of the audit, in writing, in triplicate. The party went home and thought about it. So, they would later realise, did the Auditor.]=] },
    { chapter = "2g5", label = "The answer", art = 30, text = [=[On the group's fifth win, the party came back to the long table with their answer, in triplicate. It was one line long. They had argued about it for a week and crossed out a great deal, and what was left said: "Because he comes." The Auditor read it three times, once per copy, which is procedure. Then the Auditor took off the hat.]=] },
    { chapter = "2g5", label = "Unmasked", art = 27, text = [=[It was Poogs. He had missed every session as a witness because he had been at every session as the Auditor. When the last season ended, he explained, he had not been ready to stop summoning Zennit. So he had rung the bell himself. The party said they had suspected since the notebook. They had not. Zennit said he had. He had.]=] },
    { chapter = "2g5", label = "Form 27B slash 7", art = 32, text = [=[Poogs wrote the finding himself, and stamped it, in triplicate: Zennit had been summoned persistently, unreasonably, and out of affection, which is not an offence. He filed himself under it first. Then Zennit was handed a new form, a Request to Be Summoned. He filled it in at once and gave it to Poogs. It was, by general agreement, a slightly larger cake.]=] },
}

-- The Story tab's short titles for season two's trunks (hidden as "???" until the race reaches them).
ST.seasonTrees = ST.seasonTrees or {}
ST.seasonTrees[2] = {
    zennit = { "gardening leave", "no such entry", "the bell", "from memory", "the Auditor unmasked" },
    group = { "called to give evidence", "Exhibit A", "the character witness", "the question", "summoned out of affection" },
}

-- "The Index today" in season two. Season one's lines (Ledger.LINES) are recorded; these are not yet, so they are typed and
-- silent. To record them, move them into Ledger.LINES with a season suffix and run tools/intro/build_ledger_audio.py.
ST.seasonLines = ST.seasonLines or {}
ST.seasonLines[2] = {
    recap_z1 = "Zennit is on gardening leave pending audit. He has no garden, and has asked for his file.",
    recap_z2 = "Zennit has looked the Auditor up in the Index, and found no such entry.",
    recap_z3 = "Zennit has found the bell for audits, a new rope, and a soul shard in the dust.",
    recap_z4 = "The Auditor has summoned Zennit from memory, and he recognised the ritual.",
    recap_g1 = "The party has been called to give evidence. Poogs sent apologies.",
    recap_g2 = "A notebook of summons, in familiar handwriting, has been entered as Exhibit A.",
    recap_g3 = "The Ritual has given Zennit a character reference, and greeted the Auditor like an old friend.",
    recap_g4 = "The Auditor has asked the party why they keep summoning him. The answer is due.",
    -- how season two ended, said in season three
    last_zennit = "Last season ended with the Auditor unmasked as Poogs, and entered in the Index under P, in ink.",
    last_group = "Last season ended with Poogs unmasked, a finding of affection, and Zennit holding Form 27B slash 7.",
    end_zennit = "Zennit is one win from closing the audit, and would like the Auditor to spell their name.",
    end_group = "The party is one win from answering the question, and has started rehearsing.",
    empty_fresh = "The audit is open, and its file is empty. Nobody has won a week.",
}
