-- Group Finder for Polestar (PSGroupFinder): fitting into Polestar when it runs.
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
-- What the Polestar/ files use of Polestar, most stable first:
--   Polestar.API (version 1, docs/API.md): Polestar.On("STEP_CHANGED" |
--     "GUIDE_CHANGED" | "TABS_CHANGED") and Polestar.Compat.IsOnQuest /
--     IsQuestReadyForTurnIn.
--   Polestar.Theme (Skin API, docs/skins/reference.md): Skin, Font, Color,
--     Hex, OnChanged to paint our frames; GuideParts().window / .nav / .rows
--     to sit against the guide window (Header.lua, GoalRows.lua).
--   Polestar.RegisterOptions (ARCHITECTURE.md, "Options registry"): our page
--     in Polestar's settings (Options.lua).
--   INTERNAL, always under pcall, with a fallback when missing:
--     Polestar.Engine.GetGuide / GetLiveStep and the step's goals' `quest`
--     (here, to put the live step's quests first), Compat.GetPlayerMapPosition
--     (Quests.lua), nav.Lookup (Header.lua), UI.ShowOptions and the options
--     sidebar (Options.lua), the goal rows' fields and QuestClickTips /
--     QuestRowClick (GoalRows.lua).
-- Without Polestar (or with another API version), none of this runs: the
-- panel stands alone and the quest log is the only source.
--
-- Once Polestar is known usable (at login), ns.Polestar is set and the
-- "POLESTAR" message tells the other files.

local _, ns = ...

local stepCache, stepDirty = {}, true

local function usable()
	local api = Polestar and Polestar.API
	return api and api.version == 1 and Polestar.On and true or false
end

-- The quests of Polestar's live step that are in the log and not ready to
-- hand in (ids, in the step's order). Empty without Polestar.
function ns.PolestarStepQuests()
	local P = ns.Polestar
	if not P then return {} end
	if not stepDirty then return stepCache end
	stepDirty = false
	local out = {}
	local ok = pcall(function()
		local E = P.Engine
		local g = E and E.GetGuide and E.GetGuide()
		local i = g and E.GetLiveStep and E.GetLiveStep()
		local step = i and type(g.steps) == "table" and g.steps[i]
		if type(step) ~= "table" or type(step.goals) ~= "table" then return end
		local C, seen = P.Compat, {}
		for _, goal in ipairs(step.goals) do
			local id = type(goal) == "table" and tonumber(goal.quest)
			if id and not seen[id] and C.IsOnQuest(id) and not C.IsQuestReadyForTurnIn(id) then
				seen[id] = true
				out[#out + 1] = id
			end
		end
	end)
	stepCache = ok and out or {}
	return stepCache
end

ns.On("LOGIN", function()
	if not usable() then return end
	local P = Polestar
	ns.Polestar = P
	for _, msg in ipairs({ "STEP_CHANGED", "GUIDE_CHANGED", "TABS_CHANGED" }) do
		pcall(P.On, msg, function()
			stepDirty = true
			ns.Fire("POLESTAR_STEP")
		end)
	end
	ns.RegisterEvent("QUEST_LOG_UPDATE", function() stepDirty = true end)
	ns.Fire("POLESTAR", P)
end)

ns.On("POLESTAR_STEP", function() if ns.UI then ns.UI.Refresh() end end)
