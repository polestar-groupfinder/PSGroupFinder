-- Group Finder for Polestar (PSGroupFinder): our row in the guide window's menu, and the panel
-- docked beside the guide window.
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
-- Polestar's guide window has no slot for another addon's header icon, so
-- the finder lives in the window's menu (the "..." button): one row,
-- "Community Group Finder", opens the panel, where Find a group, the
-- players found and the settings are. The goal-row button (GoalRows.lua) stays on
-- the current step's objectives.
-- The menu is built anew at each opening from a fixed list; its Free mode
-- rows come from Polestar.Free.MenuItems() (INTERNAL, Lookup/Free.lua), which
-- we wrap under pcall to add ours after them. Polestar_FreeMode replaces
-- that function when it loads, so the wrap is checked again on each scan.
-- Without it, the panel's own button, the key bindings and /psgf remain.
-- The panel docks against Theme.GuideParts().window (public Skin API) and
-- hides and comes back with it.

local _, ns = ...
local L = ns.L

local Menu = {}
ns.PolestarMenu = Menu

local P -- Polestar, set on "POLESTAR"
local hostWindow
local wrapped -- our wrapper of Polestar.Free.MenuItems, while in place

-- Our row, in Polestar's menu item format: one entry for the whole finder,
-- which opens the panel (Find a group, the players found, the settings).
function Menu.Items()
	return {
		{ text = L.TITLE, icon = "icon-group", tip = L.MENU_PANEL_TIP, onClick = function() ns.UI.Show() end },
	}
end

local function wrapMenu()
	local Free = P and P.Free
	if type(Free) ~= "table" or type(Free.MenuItems) ~= "function" or Free.MenuItems == wrapped then return end
	local orig = Free.MenuItems
	wrapped = function(...)
		local items = orig(...)
		pcall(function()
			items = type(items) == "table" and items or {}
			for _, it in ipairs(Menu.Items()) do items[#items + 1] = it end
		end)
		return items
	end
	Free.MenuItems = wrapped
end
Menu.Wrap = wrapMenu
function Menu.Wrapped() return wrapped ~= nil and P and P.Free and P.Free.MenuItems == wrapped end

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
-- Polestar_FreeMode may load later and replace Free.MenuItems: wrap again.
ns.RegisterEvent("ADDON_LOADED", function(_, name) if name == "Polestar_FreeMode" then ns.After(0, wrapMenu) end end)
