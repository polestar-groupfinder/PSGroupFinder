-- Group Finder for Polestar (PSGroupFinder): fitting into Polestar when it runs.
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
-- What it uses of Polestar, most stable first:
--   Polestar.API (version 1, docs/API.md): Polestar.On("STEP_CHANGED" |
--     "GUIDE_CHANGED" | "TABS_CHANGED") and Polestar.Compat.IsOnQuest /
--     IsQuestReadyForTurnIn. Promised by Polestar's API.
--   Polestar.Theme (Skin API, docs/skins/reference.md): Skin, Font,
--     OnChanged (capability theme.functions) to paint the panel, and
--     GuideParts().window and .nav (capability guideParts) to sit against
--     the guide window. The header icon is parented to nav, just left of
--     nav.Lookup (INTERNAL: the Lookup button is not in the public API;
--     found under pcall, and the button under the window is the fallback).
--   Polestar.RegisterOptions (docs ARCHITECTURE.md, "Options registry": not in
--     docs/API.md): our page in Polestar's settings window, rows with
--     get/set, a binding row, buttons. Called once under pcall; when it is
--     missing or refuses, the panel keeps every option.
--   Polestar.UI.ShowOptions(pageKey): INTERNAL, under pcall, for the
--     panel's Options button, which only shows when it exists.
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
-- Left click: start or restart the search, never open the panel (the
-- search already prints a short chat line; the icon turns accent while
-- a session is active). Right click: open or close the panel.
-- The button argument is required: without RegisterForClicks for the
-- right button, or if OnClick is called without it, a right click would
-- fall through to the left-click action.
local function bindFinderClicks(b)
	if not b then return end
	if b.EnableMouse then b:EnableMouse(true) end
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnClick", function(_, button)
		if button == "RightButton" then
			if ns.TogglePanel then ns.TogglePanel() end
			return
		end
		if ns.Get("enabled") then
			if ns.Search then ns.Search() end
		else
			ns.Print(L.DISABLED)
		end
		if ns.PaintHeader then ns.PaintHeader() end
	end)
end

-- Custom get/set option rows do not fire Polestar SETTING_CHANGED, so a
-- sibling's `disabled` function would not be re-evaluated until the page
-- was rebuilt. RefreshAll is Polestar's native pass (the same one
-- SETTING_CHANGED runs for every `disabled` row).
local function refreshOptionsLangs()
	local W = P and P.Widgets
	if W and W.RefreshAll then pcall(W.RefreshAll) end
end
ns.On("LANG", refreshOptionsLangs)

-- The guide window: an icon in the header (left of Lookup), or the
-- "Find a group" button under the window when the header is off or
-- cannot be attached.

local launcher, header, hostWindow, hostNav, hostLookup
local placing = false

local function guideParts()
	local T = P and P.Theme
	if not (T and T.GuideParts) then return nil end
	if T.HasCapability and not T.HasCapability("guideParts") then return nil end
	local ok, parts = pcall(T.GuideParts)
	return ok and type(parts) == "table" and parts or nil
end

-- nav.Lookup is internal (GF.lua). Walk the step bar if the name moves.
local function findLookup(nav)
	if not nav then return nil end
	if nav.Lookup then return nav.Lookup end
	local ok, n = pcall(function() return nav:GetNumChildren() end)
	if not (ok and n) then return nil end
	for i = 1, n do
		local c = select(i, nav:GetChildren())
		if c and c.psIconName == "search" then return c end
	end
end

-- How far the window's own parts (bottom-edge tabs) stand under it.
local function reach(window)
	local T = P and P.Theme
	if not (T and T.GuideReach) then return 0 end
	if T.HasCapability and not T.HasCapability("guideReach") then return 0 end
	local ok, _, bottom = pcall(T.GuideReach, window)
	if not ok then return 0 end
	-- One number is the bottom's only when the answer has no second one.
	local r = tonumber(bottom) or 0
	return r > 0 and r or 0
end

local function placeLauncher(b, window)
	b:ClearAllPoints()
	b:SetPoint("TOPRIGHT", window, "BOTTOMRIGHT", 0, -2 - reach(window))
end

local function makeLauncher(window)
	local T = P.Theme
	local b = CreateFrame("Button", "PSGroupFinderLauncher", window)
	b:SetSize(132, 20)
	placeLauncher(b, window)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b.psTextButton = true
	local fs = b:CreateFontString(nil, "OVERLAY")
	if not (T.Font and pcall(T.Font, fs, "caption")) then fs:SetFontObject(GameFontNormalSmall) end
	fs:SetPoint("CENTER")
	b:SetFontString(fs)
	b:SetText(L.SEARCH)
	if T.Skin then pcall(T.Skin, b, "button") end
	bindFinderClicks(b)
	-- Greyed while the finder is off: a click then only opens the panel.
	local function dimmed() b:SetAlpha(ns.Get("enabled") and 1 or 0.55) end
	ns.On("ENABLED", dimmed)
	ns.On("SETTING", dimmed)
	dimmed()
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


-- A 24x24 group glyph (two people), tinted with a Theme colour token.
-- No addon texture file: Theme.Media("white") or a solid colour.
local function paintGlyph(b, token, alpha)
	local r, g, bl, a = 0.85, 0.88, 0.95, alpha or 1
	local T = P and P.Theme
	if T and T.Color then
		local ok, cr, cg, cb, ca = pcall(T.Color, token)
		if ok and cr then r, g, bl, a = cr, cg, cb, (ca or 1) * (alpha or 1) end
	end
	for _, t in ipairs(b.psGlyph or {}) do
		t:SetVertexColor(r, g, bl, a)
	end
end

local function makeGlyph(b)
	local function tex(w, h, x, y)
		local t = b:CreateTexture(nil, "ARTWORK")
		local T = P and P.Theme
		if T and T.Media then
			local ok, path = pcall(T.Media, "white")
			if ok and path then t:SetTexture(path) else t:SetColorTexture(1, 1, 1, 1) end
		else
			t:SetColorTexture(1, 1, 1, 1)
		end
		t:SetSize(w, h)
		t:SetPoint("CENTER", b, "CENTER", x, y)
		return t
	end
	-- Two people, readable at 24 px: heads + short bodies.
	b.psGlyph = {
		tex(4, 4, -3.5, 3.5), tex(5, 6, -3.5, -2),
		tex(4, 4, 3.5, 3.5), tex(5, 6, 3.5, -2),
	}
	paintGlyph(b, "icon", 1)
end

local function paintHeader()
	if not header then return end
	local on = ns.Get("enabled") and true or false
	local active = ns.Session and ns.Session.Active()
	local W = P and P.Widgets
	if W and W.SetIconState then
		pcall(W.SetIconState, header, active, true)
		if not on and not active then header:SetAlpha(0.45) else header:SetAlpha(1) end
		return
	end
	header:SetAlpha(1)
	if not on and not active then paintGlyph(header, "textMuted", 0.55)
	elseif active then paintGlyph(header, "accent", 1)
	else paintGlyph(header, "icon", 1) end
end

local function makeHeader(nav)
	local b
	local W = P and P.Widgets
	-- Same constructor as Lookup / Menu when it exists, then we draw our
	-- own glyph over it so we do not depend on a Polestar icon file.
	if W and W.IconButton then
		local ok, btn = pcall(W.IconButton, nav, "search", 24, L.TITLE, nil)
		if ok and btn then
			b = btn
			if b.Icon then b.Icon:Hide() end
		end
	end
	if not b then
		b = CreateFrame("Button", "PSGroupFinderHeader", nav)
		b:SetSize(24, 24)
		local T = P and P.Theme
		if T and T.Skin then pcall(T.Skin, b, "button") end
	end
	makeGlyph(b)
	bindFinderClicks(b)
	b:SetScript("OnEnter", function(self)
		if ns.Session and ns.Session.Active() then paintGlyph(self, "accent", 1)
		else paintGlyph(self, "iconHover", 1) end
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:SetText(L.TITLE, 1, 1, 1)
		GameTooltip:AddLine(L.BINDING_SEARCH .. " (clic gauche / left click)", nil, nil, nil, true)
		GameTooltip:AddLine(L.BINDING_PANEL .. " (clic droit / right click)", nil, nil, nil, true)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function()
		paintHeader()
		GameTooltip:Hide()
	end)
	return b
end

-- Insert our icon immediately left of Lookup, and move whatever Polestar
-- had anchored to Lookup (the bug, Nearby, All steps, Skip) one slot left.
-- Polestar re-anchors on every layout, so this runs again after SetPoint.
local function placeHeader()
	if placing or not (header and hostLookup) then return end
	placing = true
	header:ClearAllPoints()
	header:SetPoint("RIGHT", hostLookup, "LEFT", 0, 0)
	header:SetFrameLevel((hostLookup.GetFrameLevel and hostLookup:GetFrameLevel() or 1))
	local function retarget(frame)
		if not frame or frame == header then return end
		local ok, point, rel, relPoint, x, y = pcall(function()
			local p, r, rp, xx, yy = frame:GetPoint(1)
			return p, r, rp, xx, yy
		end)
		if ok and rel == hostLookup then
			frame:ClearAllPoints()
			frame:SetPoint(point or "RIGHT", header, relPoint or "LEFT", x or 0, y or 0)
		end
	end
	if hostNav then
		for _, name in ipairs({ "Report", "Nearby", "AllSteps", "Skip" }) do
			retarget(hostNav[name])
		end
		local ok, n = pcall(function() return hostNav:GetNumChildren() end)
		if ok and n then
			for i = 1, n do retarget(select(i, hostNav:GetChildren())) end
		end
	end
	placing = false
end

local function hookSetPoint(frame)
	if not frame or frame.psgfHooked then return end
	frame.psgfHooked = true
	local orig = frame.SetPoint
	if type(orig) ~= "function" then return end
	frame.SetPoint = function(self, ...)
		orig(self, ...)
		if not placing then placeHeader() end
	end
end

local function syncButtons()
	local wantHeader = ns.Get("headerButton") ~= false
	local haveHeader = header and hostLookup
	if wantHeader and haveHeader then
		placeHeader()
		header:Show()
		paintHeader()
		if launcher then launcher:Hide() end
	else
		if header then header:Hide() end
		if launcher then
			if hostWindow then placeLauncher(launcher, hostWindow) end
			launcher:Show()
		end
	end
end

local function attach()
	if not P then return false end
	local parts = guideParts()
	local window = parts and parts.window
	if not window then return false end
	if window ~= hostWindow then
		hostWindow = window
		if not launcher then
			launcher = makeLauncher(window)
		else
			launcher:SetParent(window)
			placeLauncher(launcher, window)
		end
		window:HookScript("OnShow", function()
			syncButtons()
			if ns.UI then ns.UI.HostShown(true) end
		end)
		window:HookScript("OnHide", function() if ns.UI then ns.UI.HostShown(false) end end)
		if ns.UI then ns.UI.SetHost(window) end
	end
	-- Header: sits on the step bar, just left of Lookup (the magnifying glass).
	local nav, lookup
	pcall(function()
		nav = parts and parts.nav
		lookup = findLookup(nav)
	end)
	if nav and lookup and lookup ~= hostLookup then
		hostNav, hostLookup = nav, lookup
		if not header then
			header = makeHeader(nav)
			ns.headerButtonFrame = header
		else
			header:SetParent(nav)
		end
		hookSetPoint(lookup)
		for _, name in ipairs({ "Report", "Nearby", "AllSteps", "Skip" }) do
			if nav[name] then hookSetPoint(nav[name]) end
		end
		placeHeader()
	end
	syncButtons()
	return true
end

ns.SyncButtons = syncButtons
ns.PaintHeader = paintHeader

-- The guide window is built late (at its first show): try at login, on
-- Polestar's messages and a few times after.
local tries = 0
local function retry()
	if attach() or tries >= 10 then return end
	tries = tries + 1
	ns.After(3, retry)
end

---------------------------------------------------------------------------
-- Our page in Polestar's settings window
---------------------------------------------------------------------------

local optionsRegistered = false

local function registerOptions()
	if optionsRegistered or type(P.RegisterOptions) ~= "function" then return end
	local function toggle(label, help, key, onSet)
		return {
			kind = "toggle", label = label, help = help, search = "group finder party quest lfg groupe",
			get = function() return ns.Get(key) and true or false end,
			set = function(v) if onSet then onSet(v and true or false) else ns.Set(key, v and true or false) end end,
		}
	end
	local spec = {
		page = L.OPT_SECTION, key = "groupfinder", icon = "icon-group", group = "guiding", order = 45,
		tab = L.OPT_SECTION, section = L.OPT_SECTION,
		controls = {
			toggle(L.ENABLE, L.ENABLE_TIP, "enabled", ns.SetEnabled),
			toggle(L.AUTO_GROUP, L.AUTO_GROUP_TIP, "autoGroup"),
			toggle(L.HEADER_BUTTON, L.HEADER_BUTTON_TIP, "headerButton"),
			toggle(L.SHARE_COORDS, nil, "shareCoords"),
			toggle(L.AUTO_REPLY, nil, "autoReply"),
			{ kind = "binding", action = "PSGF_SEARCH", label = L.BINDING_SEARCH },
			{ kind = "binding", action = "PSGF_TOGGLE_PANEL", label = L.BINDING_PANEL },
			{ kind = "button", label = L.TEST, onClick = function() if ns.TestChannels then ns.TestChannels(true) end end },
			{ kind = "button", label = L.OPEN_PANEL, onClick = function() ns.UI.Show() end },
		},
	}
	local function register(extra)
		local ok, res, err = pcall(P.RegisterOptions, extra)
		if not (ok and res ~= false) then ns.Debug("RegisterOptions: %s", tostring(ok and err or res)) end
		return ok and res ~= false
	end
	if register(spec) then optionsRegistered = true end
	-- Search languages: one toggle a row (no multi-select control).
	-- "All languages" greys out the individual boxes (disabled = true).
	local langs = {
		page = L.OPT_SECTION, key = "groupfinder", tab = L.OPT_SECTION, section = L.LANGS,
		controls = {
			{ kind = "toggle", label = L.LANG_ALL, help = L.LANGS_TIP, search = "language langue language",
				get = function() return ns.Lang.AcceptsAll() end,
				set = function(v) ns.Lang.SetAcceptAll(v) end },
		},
	}
	for _, row in ipairs(ns.Lang.ALL) do
		local code = row.code
		langs.controls[#langs.controls + 1] = {
			kind = "toggle", label = ns.Lang.Name(code), search = "language langue",
			get = function() return ns.Lang.HasSearch(code) end,
			set = function(v) ns.Lang.SetSearch(code, v) end,
			disabled = function() return ns.Lang.AcceptsAll() end,
		}
	end
	if optionsRegistered then register(langs) end
end

-- The panel's Options button: Polestar's settings window on our page.
function ns.OpenOptions()
	local U = P and P.UI
	if U and type(U.ShowOptions) == "function" then
		local ok = pcall(U.ShowOptions, "groupfinder")
		if ok then return true end
	end
	return false
end

ns.On("LOGIN", function()
	if not usable() then return end
	P = Polestar
	registerOptions()
	local U = P.UI
	if ns.UI and optionsRegistered and U and type(U.ShowOptions) == "function" then ns.UI.SetHasOptions(true) end
	local function changed()
		stepDirty = true
		attach()
		if ns.UI then ns.UI.Refresh() end
	end
	for _, msg in ipairs({ "STEP_CHANGED", "GUIDE_CHANGED", "TABS_CHANGED" }) do
		pcall(P.On, msg, changed)
	end
	ns.RegisterEvent("QUEST_LOG_UPDATE", function() stepDirty = true end)
	local function buttons() attach() if ns.PaintHeader then ns.PaintHeader() end if ns.SyncButtons then ns.SyncButtons() end end
	ns.On("SETTING", buttons)
	ns.On("ENABLED", buttons)
	ns.On("SESSION", function() if ns.PaintHeader then ns.PaintHeader() end end)
	if P.Theme and P.Theme.OnChanged then pcall(P.Theme.OnChanged, buttons) end
	retry()
end)
