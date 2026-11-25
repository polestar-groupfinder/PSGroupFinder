-- Polestar Group Finder: fitting into Polestar when it runs.
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
-- What it uses of Polestar, most stable first:
--   Polestar.API (version 1, docs/API.md): Polestar.On("STEP_CHANGED" |
--     "GUIDE_CHANGED" | "TABS_CHANGED") and Polestar.Compat.IsOnQuest /
--     IsQuestReadyForTurnIn. Promised by Polestar's API.
--   Polestar.Theme (Skin API, docs/skins/reference.md): Skin, Font,
--     OnChanged (capability theme.functions) to paint the panel, and
--     GuideParts().window (capability guideParts) to sit against the guide
--     window and hang the "Find a group" button under it. Promised by the
--     Skin API within its API_VERSION.
--   Polestar.Engine.GetGuide / GetLiveStep and the step's goals' `quest`:
--     INTERNAL (not in docs/API.md), read under pcall, to know the quests
--     of the live step. When they move, the addon falls back to the quest
--     log alone.
--   Polestar.Compat.GetPlayerMapPosition: internal too (Quests.lua, pcall).
-- Without Polestar (or an API version this was not written for), none of
-- this runs: the panel stands alone and the quest log is the only source.

local _, ns = ...
local L = ns.L

local P -- Polestar, once known usable
local stepCache, stepDirty = {}, true

local function usable()
	local api = Polestar and Polestar.API
	return api and api.version == 1 and Polestar.On and true or false
end

-- The quests of Polestar's live step that are in the log and not ready to
-- hand in (ids, in the step's order). Empty without Polestar.
function ns.PolestarStepQuests()
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
	if not ok then out = {} end
	stepCache = out
	return out
end

---------------------------------------------------------------------------
-- The guide window: the launcher button under it, the panel beside it
---------------------------------------------------------------------------

local launcher, hostWindow

local function guideWindow()
	local T = P and P.Theme
	if not (T and T.GuideParts) then return nil end
	if T.HasCapability and not T.HasCapability("guideParts") then return nil end
	local ok, parts = pcall(T.GuideParts)
	return ok and type(parts) == "table" and parts.window or nil
end

local function makeLauncher(window)
	local T = P.Theme
	local b = CreateFrame("Button", "PolestarGroupFinderLauncher", window)
	b:SetSize(132, 20)
	b:SetPoint("TOPRIGHT", window, "BOTTOMRIGHT", 0, -2)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b.psTextButton = true
	local fs = b:CreateFontString(nil, "OVERLAY")
	if not (T.Font and pcall(T.Font, fs, "caption")) then fs:SetFontObject(GameFontNormalSmall) end
	fs:SetPoint("CENTER")
	b:SetFontString(fs)
	b:SetText(L.SEARCH)
	if T.Skin then pcall(T.Skin, b, "button") end
	b:SetScript("OnClick", function(_, mouse)
		if mouse == "RightButton" then
			ns.TogglePanel()
		else
			if ns.Get("enabled") then ns.Search() end
			ns.UI.Show()
		end
	end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
		GameTooltip:SetText(L.TITLE, 1, 1, 1)
		GameTooltip:AddLine(L.BINDING_SEARCH .. " (clic gauche / left click)", nil, nil, nil, true)
		GameTooltip:AddLine(L.BINDING_PANEL .. " (clic droit / right click)", nil, nil, nil, true)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return b
end

local function attach()
	if not P then return false end
	local window = guideWindow()
	if not window then return false end
	if window ~= hostWindow then
		hostWindow = window
		if not launcher then
			launcher = makeLauncher(window)
		else
			launcher:SetParent(window)
			launcher:ClearAllPoints()
			launcher:SetPoint("TOPRIGHT", window, "BOTTOMRIGHT", 0, -2)
		end
		window:HookScript("OnShow", function() if ns.UI then ns.UI.Place() end end)
		window:HookScript("OnHide", function() if ns.UI then ns.UI.Place() end end)
		if ns.UI then ns.UI.SetHost(window) end
	end
	return true
end

-- The guide window is built late (at its first show): try at login, on
-- Polestar's messages and a few times after.
local tries = 0
local function retry()
	if attach() or tries >= 10 then return end
	tries = tries + 1
	ns.After(3, retry)
end

ns.On("LOGIN", function()
	if not usable() then return end
	P = Polestar
	local function changed()
		stepDirty = true
		attach()
		if ns.UI then ns.UI.Refresh() end
	end
	for _, msg in ipairs({ "STEP_CHANGED", "GUIDE_CHANGED", "TABS_CHANGED" }) do
		pcall(P.On, msg, changed)
	end
	ns.RegisterEvent("QUEST_LOG_UPDATE", function() stepDirty = true end)
	retry()
end)
