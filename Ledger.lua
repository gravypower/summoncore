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
        return "This week is Zennit's. He is on leave and cannot be summoned, and the Index files the attempts as filler.",
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

----------------------------------------------------------------------
-- What the log remembers (the players, named): the roll a pair of helpers tipped, who has summoned him most, a run of
-- dice he won, and the silver he has been paid. Worked out from the summons of Zennit in a window, so every client
-- tells the same story, and used for the scene, the keepsake of a finished season, and `/sc seasons`.
----------------------------------------------------------------------

local function joined(names)
    if #names <= 1 then return names[1] or "" end
    return table.concat(names, ", ", 1, #names - 1) .. " and " .. names[#names]
end

-- ctx: { isZennit(name), name(name), bonus(ev), edge(ev), resolve(zroll, sroll, bonus, edge), silver, helpersMax }
-- Returns { summons, casters = { name = n }, present = { name = true }, silverPaid, silverOwed (in silver), tipped,
-- streak (his longest run of dice wins), heaviest = { name, n } or nil }.
function Ledger.Collect(events, from, to, ctx)
    local d = { summons = 0, casters = {}, present = {}, silverPaid = 0, silverOwed = 0, streak = 0, usualAsk = ctx.silver,
        -- for the titles and the badges
        assists = {}, helperTips = {}, tipPairs = {}, by = {}, delays = {} }
    local weekOf = ctx.weekStart or function(t) return math.floor(t / (7 * 86400)) end
    local list = {}
    for id, ev in pairs(events) do
        if not ev.fake and ev.time >= from and ev.time < to and ctx.isZennit(ev.target) then list[#list + 1] = { id = id, ev = ev } end
    end
    table.sort(list, function(a, b)
        if a.ev.time ~= b.ev.time then return a.ev.time < b.ev.time end
        return tostring(a.id) < tostring(b.id)
    end)
    local run = 0
    for _, item in ipairs(list) do
        local ev = item.ev
        local caster = ctx.name(ev.caster)
        d.summons = d.summons + 1
        d.casters[caster] = (d.casters[caster] or 0) + 1
        d.present[caster] = true
        local me = d.by[caster]
        if not me then
            me = { summons = 0, weeks = {}, weekCount = 0, tipped = 0, paid = 0, owed = 0 }
            d.by[caster] = me
        end
        me.summons = me.summons + 1
        local week = weekOf(ev.time)
        if not me.weeks[week] then me.weeks[week], me.weekCount = true, me.weekCount + 1 end
        for _, helper in ipairs(ev.assistants or {}) do
            local h = ctx.name(helper)
            d.present[h] = true
            d.assists[h] = (d.assists[h] or 0) + 1
        end
        local r = ev.response
        local result = r and r.result
        local amount = (r and r.amount) or ctx.silver
        if result == "paid" then d.silverPaid, me.paid = d.silverPaid + amount, me.paid + amount end
        if result == "owed" then d.silverOwed, me.owed = d.silverOwed + amount, me.owed + amount end
        if r and (result == "owed" or result == "paid") and not r.card and (not d.maxAsk or amount > d.maxAsk.amount) then
            d.maxAsk = { amount = amount, caster = caster }
        end
        if r and r.time and r.time >= ev.time then d.delays[#d.delays + 1] = r.time - ev.time end
        if result == "won" or result == "lost" then
            run = result == "won" and run + 1 or 0
            d.streak = math.max(d.streak, run)
            local bonus = ctx.bonus(ev)
            -- his roll would have won without the helpers: they tipped it
            if result == "lost" and bonus > 0 and ctx.resolve(r.zroll, r.sroll, 0, ctx.edge(ev)) == "won" then
                d.tippedCount = (d.tippedCount or 0) + 1
                me.tipped = me.tipped + 1
                local names = {}
                for i = 1, math.min(#(ev.assistants or {}), ctx.helpersMax) do names[i] = ctx.name(ev.assistants[i]) end
                local sorted = { unpack(names) }
                table.sort(sorted)
                for _, h in ipairs(sorted) do d.helperTips[h] = (d.helperTips[h] or 0) + 1 end
                if #sorted > 0 then
                    local key = joined(sorted)
                    d.tipPairs[key] = (d.tipPairs[key] or 0) + 1
                end
                d.tipped = { caster = caster, helpers = names, bonus = bonus, sroll = r.sroll, zroll = r.zroll, edge = ctx.edge(ev) }
            end
        end
    end
    local top, tie
    for name, n in pairs(d.casters) do
        if not top or n > top.n then top, tie = { name = name, n = n }, false
        elseif n == top.n then tie = true end
    end
    if top and not tie then d.heaviest = top end
    return d
end

-- The silver line, or nil: what the group has paid Zennit, in cash, with no receipt.
function Ledger.SilverLine(d)
    if d.silverPaid > 0 then
        return string.format("The group has paid Zennit %d silver, in cash, with no receipt. The Ritual has asked to be kept informed.%s",
            d.silverPaid, d.silverOwed > 0 and string.format(" A further %d is owed.", d.silverOwed) or "")
    elseif d.silverOwed > 0 then
        return string.format("Zennit is owed %d silver, and has been very good about not mentioning it.", d.silverOwed)
    end
end

-- Up to two moments worth remembering, as { text, cue }: a tipped roll first, then the heaviest hand, then a run of
-- dice. Each names the players.
function Ledger.Moments(d)
    local found = {}
    local t = d.tipped
    if t then
        local who = #t.helpers > 0 and (joined(t.helpers) .. "'s") or "The helpers'"
        found[#found + 1] = { text = string.format("%s +%d tipped one of %s's rolls: %d+%d against his %d+%d. The Index has framed it.",
            who, t.bonus, t.caster, t.sroll, t.bonus, t.zroll, t.edge), cue = "THE HELPERS TIPPED IT" }
    end
    if d.heaviest and d.heaviest.n >= 3 then
        found[#found + 1] = { text = string.format("%s has summoned Zennit %d times, and the Index has begun to recognise the handwriting.",
            d.heaviest.name, d.heaviest.n), cue = d.heaviest.name:upper() .. " KEEPS COMING BACK" }
    end
    if d.streak >= 3 then
        found[#found + 1] = { text = string.format("He once won the dice %d times in a row. The Index checked the dice. They were dice.",
            d.streak), cue = "THE DICE WERE DICE" }
    end
    while #found > 2 do found[#found] = nil end
    return found
end

-- The leader or leaders of a count map with at least `min`, and who is next: { names, n, next = { names, n } } or nil.
local function leaders(map, min)
    local best, second = 0, 0
    for _, n in pairs(map) do
        if n > best then second, best = best, n elseif n < best and n > second then second = n end
    end
    if best < min then return nil end
    local names, nextNames = {}, {}
    for name, n in pairs(map) do
        if n == best then names[#names + 1] = name elseif second > 0 and n == second then nextNames[#nextNames + 1] = name end
    end
    table.sort(names)
    table.sort(nextNames)
    return { names = names, n = best, next = #nextNames > 0 and { names = nextNames, n = second } or nil }
end

local function median(list)
    if #list == 0 then return nil end
    table.sort(list)
    return list[math.ceil(#list / 2)]
end

local function duration(sec)
    if sec < 120 then return sec .. " seconds" end
    if sec < 7200 then return math.floor(sec / 60) .. " minutes" end
    return math.floor(sec / 3600) .. " hours"
end

-- Titles: praise in words, no points, for what the log shows (design/lenses.md, Reward). The same people can hold several, and
-- Zennit has some too. Each is { id, title, text, next } where `next` says who is close behind (for the mid-season standings).
-- `d` is a Ledger.Collect result.
function Ledger.Titles(d)
    local out = {}
    local function add(id, title, who, sentence, nextText)
        out[#out + 1] = { id = id, title = title, text = title .. ": " .. who .. sentence, next = nextText }
    end
    local function nextOf(l, unit)
        if not l.next then return nil end
        return string.format("%s %s next with %d%s", joined(l.next.names), #l.next.names > 1 and "are" or "is", l.next.n, unit or "")
    end
    local function who(l) return joined(l.names) .. (#l.names > 1 and ", " .. l.n .. " each" or "") end

    local heavy = leaders(d.casters, 3)
    if heavy then
        add("heaviest", "The Heaviest Hand", who(heavy), string.format(", with %d summons of him.", heavy.n), nextOf(heavy))
    end
    local support = leaders(d.assists, 3)
    if support then
        add("support", "The Best Supporting Role", who(support), string.format(", who helped %d times.", support.n), nextOf(support))
    end
    local lucky = leaders(d.tipPairs, 1)
    if lucky then
        add("lucky", "The Lucky Pair", joined(lucky.names), string.format(", whose bonus tipped %d roll%s.", lucky.n, lucky.n == 1 and "" or "s"),
            nextOf(lucky))
    end
    local paid = {}
    for name, e in pairs(d.by) do
        if e.paid > 0 then paid[name] = e.paid end
    end
    local payer = leaders(paid, 50)
    if payer then
        add("payer", "The Prompt Payer", who(payer), string.format(", who paid %d silver.", payer.n), nextOf(payer, " silver"))
    end
    -- Zennit's: kind ones
    if d.streak >= 3 then
        add("goblin", "The Dice Goblin", "Zennit", string.format(", who won the dice %d times in a row.", d.streak))
    end
    if d.maxAsk and d.maxAsk.amount >= 2 * (d.usualAsk or 50) then
        add("bargain", "The Hard Bargain", "Zennit", string.format(", who asked %s for %d silver.", d.maxAsk.caster, d.maxAsk.amount))
    end
    local mid = #d.delays >= 5 and median(d.delays)
    if mid and mid <= 3600 then
        add("quick", "The Quick Reply", "Zennit", string.format(", whose usual answer came within %s.", duration(math.max(mid, 1))))
    end
    return out
end

-- The titles as they stand in the season in progress, for chat: one line each, with who is close behind.
function Ledger.Standings()
    local titles = Ledger.Titles(Ledger.Facts())
    local lines = {}
    for _, t in ipairs(titles) do
        lines[#lines + 1] = t.text .. (t.next and (" (" .. t.next .. ".)") or "")
    end
    if #lines == 0 then lines[1] = "Nothing has been earned yet this season. The Index is watching." end
    return lines
end

-- The Index's keepsake of a finished season: how it ended, how long it took, who was there, the silver and the moments.
-- finale = { start, side, from } from Week.Season; `number` is which season it was. Returns a list of sentences.
function Ledger.Keepsake(number, finale, d)
    local weeks = math.floor((finale.start - finale.from) / (7 * 86400)) + 1
    local out = { string.format("Season %d, %s. %s", number, weeks == 1 and "1 week" or (weeks .. " weeks"),
        finale.side == "group" and "The group took the finale, and Zennit was freed." or
            "Zennit took the finale, and became the clerk of the Index.") }
    local names = {}
    for name in pairs(d.present) do names[#names + 1] = name end
    table.sort(names)
    if #names > 0 then
        local more = #names > 12 and string.format(", and %d more", #names - 12) or ""
        while #names > 12 do names[#names] = nil end
        out[#out + 1] = "In the room: " .. joined(names) .. more .. "."
    end
    local silver = Ledger.SilverLine(d)
    if silver then out[#out + 1] = silver end
    for _, m in ipairs(Ledger.Moments(d)) do out[#out + 1] = m.text end
    for _, t in ipairs(Ledger.Titles(d)) do out[#out + 1] = t.text end
    return out
end

-- What this character has done, for the badges: { weekCount, tipped, paid, owed }, from every summons of Zennit they cast.
function Ledger.CasterStats(name)
    local d = Ledger.Collect(ST.db.events, 0, math.huge, Ledger.Context())
    return d.by[ST.baseName(name) or name] or { weekCount = 0, tipped = 0, paid = 0, owed = 0 }
end

function Ledger.Context()
    local W, R = ST.Week, ST.Respond
    local edges = {}
    return { isZennit = W.IsZennit, name = function(n) return ST.baseName(n) or n end, bonus = W.HelperBonus,
        edge = function(ev)
            local start = W.Start(ev.time)
            if not edges[start] then edges[start] = (W.Edge(start)) end
            return edges[start]
        end,
        resolve = R.Resolve, silver = R.SILVER, helpersMax = W.RULES.helpersMax, weekStart = W.Start }
end

-- The facts for the season in progress.
function Ledger.Facts(season)
    season = season or ST.Week.Season()
    return Ledger.Collect(ST.db.events, season.since or 0, math.huge, Ledger.Context())
end

-- Past seasons, newest first: { { number, side, lines } }.
function Ledger.Seasons()
    local out, finales = {}, ST.Week.Season().finales
    local ctx = Ledger.Context()
    for i = #finales, 1, -1 do
        local f = finales[i]
        local d = Ledger.Collect(ST.db.events, f.from, f.start + 7 * 86400, ctx)
        out[#out + 1] = { number = i, side = f.side, lines = Ledger.Keepsake(i, f, d) }
    end
    return out
end

-- state: { season = Week.Season(), score = Week.Score(this week), immune = bool, wins = Week.WINS, cap = summons a week,
--          edgeMoved, whim (the week's whim as a sentence, or nil), facts = Ledger.Collect result for the season }
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

    -- what the Index remembers of this season, by name, and the silver
    if s.facts then
        local silver = Ledger.SilverLine(s.facts)
        local moments = Ledger.Moments(s.facts)
        for i, m in ipairs(moments) do
            if i <= (silver and 1 or 2) then say(m.text, m.cue) end -- two lines of memory at most, the silver among them
        end
        if silver then say(silver, "THE SILVER") end
    end

    -- the pressure
    if z == wins - 1 and g == wins - 1 then
        say("Both sides are one win from the end. The Index has stopped sleeping.", "ONE WIN FROM THE END")
    elseif g == wins - 1 then
        say("The group is one win from the finale, and the Ritual has started to glow in a meaningful manner.",
            "ONE WIN FROM THE FINALE")
    elseif z == wins - 1 then
        say("Zennit is one win from the clerk's chair, and the kettle is on.", "ONE WIN FROM THE CHAIR")
    end

    -- the Index's thumb on the scale, when the season is lopsided (Week.Edge)
    if s.edgeMoved and s.edgeMoved ~= 0 then
        say(s.edgeMoved < 0 and string.format("The Index, which takes no sides, has noticed that the group is behind, and has taken %d off Zennit's dice this week.", -s.edgeMoved)
            or string.format("The Index, which takes no sides, has noticed that Zennit is behind, and has put %d on his dice this week.", s.edgeMoved),
            "THE INDEX TAKES NO SIDES")
    end

    local text, cue = weekLine(s)
    say(text, cue)
    if s.whim and not s.immune then say("This week's whim: " .. s.whim, "THE WHIM OF THE WEEK") end
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
    local season = W.Season(now)
    return { season = season, facts = Ledger.Facts(season), score = W.Score(start), immune = (W.Immune(now)), wins = W.WINS,
        cap = W.RULES.cap, edgeMoved = select(2, W.Edge(start)), whim = W.WhimLine(start) }
end
