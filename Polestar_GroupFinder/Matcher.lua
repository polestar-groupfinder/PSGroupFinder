-- Polestar Group Finder: the players found, and in which order to show them.
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

local MAX_AGE = 600
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
end

function Matcher.Clear()
	wipe(peers)
	ns.Fire("PEERS")
end

local function inMyGroup(name)
	return UnitInParty and (UnitInParty(name) or (UnitInRaid and UnitInRaid(name))) and true or false
end

-- The list to show: entries with `yards` (or nil), `sameZone` and `score`.
function Matcher.List()
	local now = ns.Now()
	local map, x, y = ns.Quests.Position()
	local step = stepQuests()
	local list = {}
	for name, e in pairs(peers) do
		local ok, grouped = pcall(inMyGroup, name)
		if now - e.at > MAX_AGE or (ok and grouped) then
			peers[name] = nil
		else
			-- Quests that left our log since no longer count.
			local still = {}
			for _, id in ipairs(e.quests) do if ns.Quests.Has(id) then still[#still + 1] = id end end
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
			end
		end
	end
	table.sort(list, function(a, b) return a.score > b.score end)
	return list
end

ns.RegisterEvent("GROUP_ROSTER_UPDATE", function() ns.Fire("PEERS") end)
ns.On("ENABLED", function(on) if not on then Matcher.Clear() end end)
