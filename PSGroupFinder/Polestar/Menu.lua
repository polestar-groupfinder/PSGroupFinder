-- Group Finder for Polestar (PSGroupFinder): our row in the guide window's menu, and the panel
-- docked beside the guide window.
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
-- Polestar's guide window has no slot for another addon's header icon, so
-- the finder lives in the window's menu (the "..." button): one row,
-- "Community Group Finder", opens the panel, where Find a group, the
-- players found and the settings are. The goal-row button (GoalRows.lua) stays on
-- the current step's objectives.
-- The menu is built anew at each opening and shown by
-- Polestar.Widgets.ShowMenu(anchor, items, opts) (INTERNAL, Theme/Widgets.lua,
-- the same in every release since 0.4.2). We wrap it under pcall: when the
-- anchor is the guide window's menu button (UI.GuideFrame.menuButton, else a
-- short menu holding Settings and a danger row), our row goes in at the end
-- of the quest log group, just before Quick settings / Settings. Without it,
-- the panel's own button, the key bindings and /psgf remain.
-- The panel docks against Theme.GuideParts().window (public Skin API) and
-- hides and comes back with it.

local _, ns = ...
local L = ns.L

local Menu = {}
ns.PolestarMenu = Menu

local P -- Polestar, set on "POLESTAR"
local hostWindow
local wrapped -- our wrapper of Polestar.Widgets.ShowMenu, while in place

-- Our row, in Polestar's menu item format: one entry for the whole finder,
-- which opens the panel (Find a group, the players found, the settings).
function Menu.Items()
	return {
		{ text = L.TITLE, icon = "icon-group", tip = L.MENU_PANEL_TIP, psgf = true, onClick = function() ns.UI.Show() end },
	}
end

-- Is this the guide window's menu?
local function isGuideMenu(anchor, items, opts)
	local GF = P and P.UI and P.UI.GuideFrame
	local button = type(GF) == "table" and rawget(GF, "menuButton")
	if button then return anchor == button end
	if not (type(opts) == "table" and opts.short) then return false end
	local gear, danger = false, false
	for _, it in ipairs(items) do
		if type(it) == "table" then
			if it.icon == "gear" then gear = true end
			if it.color == "danger" then danger = true end
		end
	end
	return gear and danger
end

-- Our row before the settings group (or last), once.
function Menu.AddTo(items)
	for _, it in ipairs(items) do
		if type(it) == "table" and it.psgf then return end
	end
	local at
	for i, it in ipairs(items) do
		if type(it) == "table" and (it.icon == "sliders" or it.icon == "gear") then at = i break end
	end
	if at and type(items[at - 1]) == "table" and items[at - 1].separator then at = at - 1 end
	table.insert(items, at or (#items + 1), Menu.Items()[1])
end

local function wrapMenu()
	local W = P and P.Widgets
	if type(W) ~= "table" or type(W.ShowMenu) ~= "function" or W.ShowMenu == wrapped then return end
	local orig = W.ShowMenu
	wrapped = function(anchor, items, opts, ...)
		if type(items) == "table" then
			pcall(function()
				if isGuideMenu(anchor, items, opts) then Menu.AddTo(items) end
			end)
		end
		return orig(anchor, items, opts, ...)
	end
	W.ShowMenu = wrapped
end
Menu.Wrap = wrapMenu
function Menu.Wrapped() return wrapped ~= nil and P and P.Widgets and P.Widgets.ShowMenu == wrapped end

local function guideWindow()
	local T = P and P.Theme
	if not (T and T.GuideParts) then return nil end
	if T.HasCapability and not T.HasCapability("guideParts") then return nil end
	local ok, parts = pcall(T.GuideParts)
	return ok and type(parts) == "table" and parts.window or nil
end

-- Dock the panel against the guide window, once it exists.
local function attach()
	wrapMenu()
	local window = guideWindow()
	if not window or window == hostWindow then return window ~= nil end
	hostWindow = window
	window:HookScript("OnShow", function() ns.UI.HostShown(true) end)
	window:HookScript("OnHide", function() ns.UI.HostShown(false) end)
	ns.UI.SetHost(window)
	return true
end

ns.On("POLESTAR", function(polestar)
	P = polestar
	ns.On("POLESTAR_STEP", attach)
	-- The guide window is built late (at its first show): try now and a few times after.
	local tries = 0
	local function retry()
		if attach() or tries >= 10 then return end
		tries = tries + 1
		ns.After(3, retry)
	end
	retry()
end)
-- Polestar's settings addon loads on demand: check the wrap again after it.
ns.RegisterEvent("ADDON_LOADED", function(_, name)
	if P and type(name) == "string" and name:find("^Polestar") then ns.After(0, wrapMenu) end
end)
