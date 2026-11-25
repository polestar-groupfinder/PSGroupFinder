-- Group Finder for Polestar (PSGroupFinder): the players found, and in which order to show them.
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
-- A player counts once they share a quest with you: they searched for it
-- ("asking") or answered your search ("reply"). Best first: more quests in
-- common, Polestar's live step among them, nearer (yards on the same
-- continent, else the same zone), not already grouped, heard from lately.
-- Entries go after MAX_AGE seconds, and when they join your group.

local _, ns = ...

local Matcher = {}
ns.Matcher = Matcher

local MAX_AGE = { reply = 600, asking = 300 } -- seconds before an entry is dropped
local peers = {} -- sender -> entry

local function stepQuests()
	local set = {}
	for _, id in ipairs(ns.PolestarStepQuests and ns.PolestarStepQuests() or {}) do set[id] = true end
	return set
end

function Matcher.Add(sender, m, common, source)
	local e = peers[sender] or { name = sender }
	e.level, e.class, e.size = m.level, m.class, m.size or 0
	e.map, e.x, e.y = m.map, m.x, m.y
	e.quests = common
	e.source = source
	e.sid = m.sid
	e.flags = m.flags or ""
	e.autoGroup = e.flags:find("g", 1, true) ~= nil
	e.faction = e.flags:match("[AH]")
	e.langs = m.langs
	e.langTag = ns.Lang.Summary(m.langs)
	e.at = ns.Now()
	local kinds = {}
	for _, q in ipairs(m.quests or {}) do if q.kind then kinds[q.id] = q.kind end end
	e.kinds = kinds
	local isNew = not peers[sender]
	peers[sender] = e
	if isNew then
		ns.Print(ns.L.FOUND, Ambiguate and Ambiguate(sender, "none") or sender, ns.Quests.Title(common[1]),
			source == "asking" and ns.L.ASKING or "")
	end
	ns.Fire("PEERS")
	if isNew then ns.Fire("PEER_NEW", e) end
	if ns.Group then ns.Group.Consider(e) end
end

function Matcher.Get(sender) return peers[sender] end

function Matcher.Remove(sender)
	if peers[sender] then
		peers[sender] = nil
		ns.Fire("PEERS")
	end
end

-- The names of the players found, for an update whispered to them.
function Matcher.Names()
	local out = {}
	for name in pairs(peers) do out[#out + 1] = name end
	return out
end

function Matcher.Clear()
	wipe(peers)
	if Matcher.QuestClear then Matcher.QuestClear() return end
	ns.Fire("PEERS")
end

local function inMyGroup(name)
	return UnitInParty and (UnitInParty(name) or (UnitInRaid and UnitInRaid(name))) and true or false
end
Matcher.InGroup = function(name) local ok, r = pcall(inMyGroup, name) return ok and r end

-- What counts as "my" quests: those of the active search, else any with an
-- open objective in the log.
function Matcher.Mine(id)
	if ns.Session and ns.Session.Active() then return ns.Session.Has(id) end
	return ns.Quests.Pending(id)
end

-- The list to show: entries with `yards` (or nil), `sameZone` and `score`.
function Matcher.List()
	local now = ns.Now()
	local map, x, y = ns.Quests.Position()
	local step = stepQuests()
	local list = {}
	for name, e in pairs(peers) do
		local ok, grouped = pcall(inMyGroup, name)
		if now - e.at > (MAX_AGE[e.source] or 300) or (ok and grouped) or not ns.Lang.Compatible(e.langs) then
			peers[name] = nil
		else
			-- Quests that left our log since no longer count.
			local still = {}
			for _, id in ipairs(e.quests) do if Matcher.Mine(id) then still[#still + 1] = id end end
			if #still > 0 then
				e.quests = still
				e.yards = ns.Quests.Yards(map, x, y, e.map, e.x, e.y)
				e.sameZone = map ~= nil and map == e.map
				local score = #still * 100
				for _, id in ipairs(still) do if step[id] then score = score + 150 end end
				if e.yards then score = score + math.max(0, 300 - e.yards / 5)
				elseif e.sameZone then score = score + 120 end
				if (e.size or 0) >= 5 then score = score - 500 elseif (e.size or 0) > 0 then score = score - 20 end
				score = score - (now - e.at) / 10
				e.score = score
				list[#list + 1] = e
			else
				peers[name] = nil -- nothing in common any more
			end
		end
	end
	table.sort(list, function(a, b) return a.score > b.score end)
	return list
end

---------------------------------------------------------------------------
-- By quest (v1.1): the players who said they have quest `id`, wherever
-- they are (answers "A" to a quest search), plus those of the main list
-- who share it. Kept apart from `peers`: they do not take part in grouping
-- without a click, and the main list's own rules (a quest of my search) do
-- not apply.
---------------------------------------------------------------------------

local qpeers = {} -- questID -> sender -> entry
local QUEST_AGE = 600

function Matcher.AddQuest(sender, m, id, pct)
	local set = qpeers[id] or {}
	qpeers[id] = set
	local e = set[sender] or { name = sender }
	e.level, e.class, e.size = m.level, m.class, m.size or 0
	e.map, e.x, e.y = m.map, m.x, m.y
	e.quests = { id }
	e.kinds = {}
	e.pct = pct
	e.source = "quest"
	e.sid = m.sid
	e.flags = m.flags or ""
	e.faction = e.flags:match("[AH]")
	e.langs = m.langs
	e.langTag = ns.Lang.Summary(m.langs)
	e.at = ns.Now()
	local isNew = set[sender] == nil
	set[sender] = e
	ns.Fire("PEERS")
	if isNew then ns.Fire("QUEST_PEER_NEW", id, e) end
end

-- Every quest id this player is known to have, from either list.
function Matcher.QuestsOf(sender)
	local out, seen = {}, {}
	local e = peers[sender]
	if e then for _, id in ipairs(e.quests or {}) do if not seen[id] then seen[id] = true out[#out + 1] = id end end end
	for id, set in pairs(qpeers) do
		if set[sender] and not seen[id] then seen[id] = true out[#out + 1] = id end
	end
	return out
end

-- The list for quest `id`: best first (same zone / nearer, then not already
-- grouped, then the freshest). Entries carry `pct` when the player told us.
function Matcher.QuestList(id)
	local now = ns.Now()
	local map, x, y = ns.Quests.Position()
	local merged = {}
	for name, e in pairs(qpeers[id] or {}) do
		if now - e.at > QUEST_AGE or not ns.Lang.Compatible(e.langs) then
			qpeers[id][name] = nil
		else
			merged[name] = e
		end
	end
	for name, e in pairs(peers) do
		if not merged[name] and now - e.at <= (MAX_AGE[e.source] or 300) and ns.Lang.Compatible(e.langs) then
			for _, q in ipairs(e.quests or {}) do
				if q == id then merged[name] = e break end
			end
		end
	end
	local list = {}
	for name, e in pairs(merged) do
		local ok, grouped = pcall(inMyGroup, name)
		if not (ok and grouped) then
			e.yards = ns.Quests.Yards(map, x, y, e.map, e.x, e.y)
			e.sameZone = map ~= nil and map == e.map
			local score = 0
			if e.yards then score = score + math.max(0, 300 - e.yards / 5) elseif e.sameZone then score = score + 120 end
			if (e.size or 0) >= 5 then score = score - 500 elseif (e.size or 0) > 0 then score = score - 20 end
			e.score = score - (now - e.at) / 10
			list[#list + 1] = e
		end
	end
	table.sort(list, function(a, b) return a.score > b.score end)
	return list
end

function Matcher.QuestClear(id)
	if id then qpeers[id] = nil else wipe(qpeers) end
	ns.Fire("PEERS")
end

ns.RegisterEvent("GROUP_ROSTER_UPDATE", function() ns.Fire("PEERS") end)
ns.On("SESSION", function() ns.Fire("PEERS") end)
ns.On("ENABLED", function(on) if not on then Matcher.Clear() end end)
