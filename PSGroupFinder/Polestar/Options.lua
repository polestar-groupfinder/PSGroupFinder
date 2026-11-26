-- Group Finder for Polestar (PSGroupFinder): our page in Polestar's settings window.
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
-- Polestar.RegisterOptions (ARCHITECTURE.md, "Options registry") takes our
-- page: toggles with get/set and a tooltip (`help`), key binding rows and
-- buttons, then the search languages, whose rows fold away (`needs`) while
-- "All languages" is on. Called under pcall; when it is missing or refuses,
-- the panel keeps every option.
-- INTERNAL, under pcall: UI.ShowOptions (the panel's Options button, shown
-- only when it exists), Widgets.RefreshAll / Options.Relayout (so the
-- language card shrinks at once) and the grouped sidebar (our icon on an
-- indented row, if Polestar leaves it blank).

local _, ns = ...
local L = ns.L

local P -- Polestar, set on "POLESTAR"
local KEY = "groupfinder"
local registered = false

-- Custom get/set rows do not fire Polestar's SETTING_CHANGED, so the
-- language rows would stay stale until the page is rebuilt.
local function refreshLangs()
	local W = P and P.Widgets
	if W and W.RefreshAll then pcall(W.RefreshAll) end
	local O = P and P.UI and P.UI.Options
	if O and O.Relayout then pcall(O.Relayout) end
end

-- The grouped settings layout builds its sidebar from Grouped.NavItems,
-- whose indented rows may get no `icon`, and NavRowAfter may hide the
-- texture on them. If so, we fill the field and show our texture. The
-- public `icon` on RegisterOptions still stands when all of this is missing.
local function hookSidebarIcon()
	local O = P and P.UI and P.UI.Options
	local W = P and P.Widgets
	local icon = ns.ICON
	pcall(function()
		for _, page in ipairs(O.Kit.pages) do
			if page.key == KEY then page.icon = icon end
		end
	end)
	pcall(function()
		local G = O.Grouped
		if type(G.NavItems) ~= "function" or G.psgfIconHook then return end
		G.psgfIconHook = true
		local orig = G.NavItems
		G.NavItems = function(...)
			local items = orig(...)
			pcall(function()
				for _, it in ipairs(items) do
					if it.key == KEY then it.icon = it.icon or icon end
				end
			end)
			return items
		end
	end)
	pcall(function()
		if type(W.NavRowAfter) ~= "function" or W.psgfIconHook then return end
		W.psgfIconHook = true
		local orig = W.NavRowAfter
		W.NavRowAfter = function(b, item, on, pad)
			orig(b, item, on, pad)
			pcall(function()
				if not (item and item.key == KEY and b and b.Icon) then return end
				local path = icon
				local T = P.Theme
				if T and T.Media then
					local ok, r = pcall(T.Media, icon)
					if ok and type(r) == "string" then path = r end
				end
				b.Icon:SetTexture(path)
				b.Icon:SetSize(16, 16)
				if b.Icon.Show then b.Icon:Show() end
			end)
		end
	end)
end

local function toggle(labelKey, key, onSet)
	return {
		kind = "toggle", label = L[labelKey], help = L[labelKey .. "_TIP"], search = "group finder party quest lfg groupe",
		get = function() return ns.Get(key) and true or false end,
		set = function(v) if onSet then onSet(v and true or false) else ns.Set(key, v and true or false) end end,
	}
end

local function register(spec)
	local ok, res, err = pcall(P.RegisterOptions, spec)
	if not (ok and res ~= false) then ns.Debug("RegisterOptions: %s", tostring(ok and err or res)) end
	return ok and res ~= false
end

local function registerOptions()
	if registered or type(P.RegisterOptions) ~= "function" then return end
	local page = { page = L.OPT_SECTION, key = KEY, icon = ns.ICON, group = "guiding", order = 45,
		tab = L.OPT_SECTION, section = L.OPT_SECTION, controls = {
			toggle("ENABLE", "enabled", ns.SetEnabled),
			toggle("AUTO_GROUP", "autoGroup"),
			toggle("HEADER_BUTTON", "headerButton"),
			toggle("SHARE_COORDS", "shareCoords"),
			toggle("AUTO_REPLY", "autoReply"),
			toggle("READ_CHAT", "readChat"),
			toggle("LEAVE_OFFER", "leaveOffer"),
			toggle("LEAVE_MSG", "leaveMsgOn"),
			toggle("LEAVE_MSG_ANY", "leaveMsgAny"),
			{ kind = "button", label = L.LEAVE_DIALOG .. "…", help = L.LEAVE_DIALOG_TIP, onClick = function() ns.UI.EditLeaveMessage() end },
			{ kind = "binding", action = "PSGF_SEARCH", label = L.BINDING_SEARCH, help = L.BINDING_SEARCH_TIP },
			{ kind = "binding", action = "PSGF_TOGGLE_PANEL", label = L.BINDING_PANEL, help = L.BINDING_PANEL_TIP },
			{ kind = "binding", action = "PSGF_ANNOUNCE", label = L.BINDING_ANNOUNCE, help = L.BINDING_ANNOUNCE_TIP },
			{ kind = "button", label = L.TEST, help = L.TEST_TIP, onClick = function() ns.TestChannels(true) end },
			{ kind = "button", label = L.OPEN_PANEL, help = L.OPEN_PANEL_TIP, onClick = function() ns.UI.Show() end },
		} }
	if not register(page) then return end
	registered = true
	local langs = { page = L.OPT_SECTION, key = KEY, icon = ns.ICON, tab = L.OPT_SECTION, section = L.LANGS, controls = {
		{ kind = "toggle", label = L.LANG_ALL, help = L.LANGS_TIP, search = "language langue",
			get = ns.Lang.AcceptsAll, set = ns.Lang.SetAcceptAll },
	} }
	for _, row in ipairs(ns.Lang.ALL) do
		local code = row.code
		langs.controls[#langs.controls + 1] = {
			kind = "toggle", label = ns.Lang.Name(code), help = string.format(L.LANG_ONE_TIP, ns.Lang.Name(code)),
			search = "language langue",
			get = function() return ns.Lang.HasSearch(code) end,
			set = function(v) ns.Lang.SetSearch(code, v) end,
			-- `needs` folds the row away; `disabled` greys it on a Polestar that ignores needs.
			needs = function() return not ns.Lang.AcceptsAll() end,
			disabled = function() return ns.Lang.AcceptsAll() end,
		}
	end
	register(langs)
end

-- The panel's Options button: Polestar's settings window on our page.
function ns.OpenOptions()
	hookSidebarIcon()
	local U = P and P.UI
	if U and type(U.ShowOptions) == "function" and pcall(U.ShowOptions, KEY) then
		hookSidebarIcon()
		return true
	end
	return false
end

ns.On("POLESTAR", function(polestar)
	P = polestar
	registerOptions()
	hookSidebarIcon()
	ns.RegisterEvent("ADDON_LOADED", function(_, name)
		if name == "Polestar_Options" then hookSidebarIcon() end
	end)
	ns.On("LANG", refreshLangs)
	local U = P.UI
	if registered and U and type(U.ShowOptions) == "function" then ns.UI.SetHasOptions(true) end
end)
