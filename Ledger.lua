-- Ledger: "The Index today", the part of the story that follows the season. The intro's ten fixed scenes are
-- narrated and drawn once; this is the last scene of them, written fresh from the season tree every time it plays:
-- who leads, how far down each trunk the race has got (only chapters already reached, so nothing is spoiled),
-- how the season ended before this one, and how this week stands. Build is pure (state in, sentences out) so it
-- can be tried without the game; State reads the live season.
local ADDON, ST = ...
local Ledger = {}
ST.Ledger = Ledger

-- Where each trunk stands after its nth win of the season (the fifth is the finale, told as the last season's end).
local RECAP = {
    z1 = "Zennit has had his week off, and has not yet decided whether he liked it.",
    z2 = "Zennit holds a brass key to a side door, and has ticked the first item on his list.",
    z3 = "Zennit has found that his list is a syllabus, and is studying it in a corridor, with a kettle.",
    z4 = "The clerk has shown Zennit the desk, and is looking everywhere for his hat.",
    g1 = "The group has had its cake, which Zennit did not trust.",
    g2 = "The group keeps a carbon copy of Form 27B slash 6, and the Index would like it back.",
    g3 = "The Ritual has handed up Form 27B slash 6, after sitting on it beneath a tavern.",
    g4 = "The Ritual has named its price: fifty silver, in cash, and the third copy of the form.",
}

local LAST_SEASON = {
    zennit = "Last season ended with Zennit in the clerk's chair. He accepts every summons, and the Index has asked him to stop apologising.",
    group = "Last season ended with a receipt, and Zennit free. The Index was asked to carry on regardless, and agreed, with misgivings.",
}

local function weeks(n)
    return n == 1 and "1 week" or (n .. " weeks")
end

-- The week's standing in a few words, from a Week.Score result.
local function weekLine(s)
    local w = s.score
    if s.immune then
        return "This week is Zennit's. He is on leave and cannot be summoned, and the Index has noted the attempts.",
            "ZENNIT IS ON LEAVE"
    elseif w.closed then
        return "Zennit has closed the Index for the week. Anything more is filed under enthusiasm.", "THE INDEX IS CLOSED"
    elseif w.summons == 0 then
        return "Nobody has summoned Zennit this week. The Index is patient.", "NO SUMMONS YET"
    end
    local lead
    if w.group > w.zennit then
        lead = string.format("the group leads by %d", w.group - w.zennit)
    elseif w.group == w.zennit then
        lead = "it is level, and a tie is Zennit's"
    else
        lead = string.format("Zennit leads by %d", w.zennit - w.group)
    end
    if w.new then
        return string.format("This week, %d of %d summons are filed, and %s.", w.counted, s.cap, lead), "THIS WEEK: " .. lead:upper()
    end
    return string.format("This week, the group has %d points to Zennit's %d.", w.group, w.zennit), "THIS WEEK: " .. lead:upper()
end

-- state: { season = Week.Season(), score = Week.Score(this week), immune = bool, wins = Week.WINS, cap = summons a week }
-- Returns a list of { text, cue }, where cue is the punchline for the Text: key mode (or nil).
function Ledger.Build(s)
    local out = {}
    local function say(text, cue) out[#out + 1] = { text = text, cue = cue } end
    local z, g, wins = s.season.zennit, s.season.group, s.wins
    local finales = s.season.finales
    local number = #finales + 1

    -- how the season began, or how the last one ended
    if number > 1 then
        say(LAST_SEASON[finales[#finales].side], "SEASON " .. number)
    end

    -- the standing
    if z == 0 and g == 0 then
        say(number > 1 and "The Index has opened a fresh file, and it is empty." or
            "The Index has opened a file on the season, and it is empty. Nobody has won a week.", "NOBODY HAS WON A WEEK")
        say("The Index is prepared to wait.")
    elseif z == g then
        say(string.format("The season stands level at %s each. The Index would like it noted that it is not taking sides.",
            weeks(z)), "LEVEL AT " .. z)
    elseif g > z then
        say(string.format("The group leads the season, %d to %d.", g, z), "THE GROUP LEADS, " .. g .. " TO " .. z)
    else
        say(string.format("Zennit leads the season, %d to %d, which nobody expected, least of all Zennit.", z, g),
            "ZENNIT LEADS, " .. z .. " TO " .. g)
    end

    -- how far down each trunk
    if z > 0 and RECAP["z" .. z] then say(RECAP["z" .. z]) end
    if g > 0 and RECAP["g" .. g] then say(RECAP["g" .. g]) end

    -- the pressure
    if z == wins - 1 and g == wins - 1 then
        say("Both sides are one win from the end. The Index has stopped sleeping.", "ONE WIN FROM THE END")
    elseif g == wins - 1 then
        say("The group is one win from the finale, and the Ritual has started to glow in a meaningful manner.",
            "ONE WIN FROM THE FINALE")
    elseif z == wins - 1 then
        say("Zennit is one win from the clerk's chair, and the kettle is on.", "ONE WIN FROM THE CHAIR")
    end

    local text, cue = weekLine(s)
    say(text, cue)
    say("The Index is accepting further evidence.")
    return out
end

-- Reading speed of the typed-out lines: a sentence stays up for a second and a bit, plus a share of its length.
local LEAD, PER_CHAR = 1.2, 1 / 16

-- Times the sentences for the viewer. Returns sentences { { t, text } }, cues { { t, text } } and the total length.
function Ledger.Timed(list)
    local sentences, cues, t = {}, {}, 0
    for _, item in ipairs(list) do
        sentences[#sentences + 1] = { t = t, text = item.text }
        if item.cue then cues[#cues + 1] = { t = t + 0.3, text = item.cue } end
        t = t + LEAD + #item.text * PER_CHAR
    end
    return sentences, cues, t
end

-- The chapter key whose picture the scene borrows: the latest win of the season, or nil before any.
function Ledger.ArtKey(season)
    local last = season.chapters[#season.chapters]
    return last and last.key or nil
end

function Ledger.State()
    local W = ST.Week
    local now = time()
    local start = W.Start(now)
    return { season = W.Season(now), score = W.Score(start), immune = (W.Immune(now)), wins = W.WINS,
        cap = W.RULES.cap }
end
