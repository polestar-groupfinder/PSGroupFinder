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
		kind = "toggle", label = L[labelKey], help = L[labelKey .. "_TIP"], search = "group finder party quest lfg",
		get = function() return ns.Get(key) and true or false end,
		set = function(v) if onSet then onSet(v and true or false) else ns.Set(key, v and true or false) end end,
	}
end

local function register(spec)
	local ok, res, err = pcall(P.RegisterOptions, spec)
	if not (ok and res ~= false) then ns.Debug("RegisterOptions: %s", tostring(ok and err or res)) end
	return ok and res ~= false
end

local function binding(action, labelKey)
	return { kind = "binding", action = action, label = L[labelKey], help = L[labelKey .. "_TIP"] }
end

-- One section per category, the same as the panel's Settings.
local function sections()
	local langs = {
		{ kind = "toggle", label = L.LANG_ALL, help = L.LANGS_TIP, search = "language",
			get = ns.Lang.AcceptsAll, set = ns.Lang.SetAcceptAll },
	}
	for _, row in ipairs(ns.Lang.ALL) do
		local code = row.code
		langs[#langs + 1] = {
			kind = "toggle", label = ns.Lang.Name(code), help = string.format(L.LANG_ONE_TIP, ns.Lang.Name(code)),
			search = "language",
			get = function() return ns.Lang.HasSearch(code) end,
			set = function(v) ns.Lang.SetSearch(code, v) end,
			-- `needs` folds the row away; `disabled` greys it on a Polestar that ignores needs.
			needs = function() return not ns.Lang.AcceptsAll() end,
			disabled = function() return ns.Lang.AcceptsAll() end,
		}
	end
	return {
		{ L.OPT_SECTION, {
			toggle("ENABLE", "enabled", ns.SetEnabled),
			{ kind = "button", label = L.MESSAGES .. "…", help = L.MESSAGES_TIP, onClick = function() ns.UI.ShowMessages() end },
			{ kind = "button", label = L.TEST, help = L.TEST_TIP, onClick = function() ns.TestChannels(true) end },
		} },
		{ L.CAT_GROUPING, {
			toggle("AUTO_GROUP", "autoGroup"),
			toggle("AUTO_REPLY", "autoReply"),
			toggle("SHARE_COORDS", "shareCoords"),
		} },
		{ L.LANGS, langs },
		{ L.CAT_PARTY, {
			toggle("PARTY_BOX", "partyBox"),
			binding("PSGF_HELLO", "BINDING_HELLO"),
			binding("PSGF_GOODBYE", "BINDING_GOODBYE"),
		} },
		{ L.CAT_CHAT, { toggle("READ_CHAT", "readChat") } },
		{ L.CAT_INTERFACE, {
			toggle("HEADER_BUTTON", "headerButton"),
			binding("PSGF_SEARCH", "BINDING_SEARCH"),
			binding("PSGF_TOGGLE_PANEL", "BINDING_PANEL"),
			binding("PSGF_ANNOUNCE", "BINDING_ANNOUNCE"),
		} },
	}
end

local function registerOptions()
	if registered or type(P.RegisterOptions) ~= "function" then return end
	for i, sec in ipairs(sections()) do
		local spec = { page = L.OPT_SECTION, key = KEY, icon = ns.ICON, tab = L.OPT_SECTION, section = sec[1], controls = sec[2] }
		if i == 1 then spec.group, spec.order = "guiding", 45 end
		if not register(spec) then
			if i == 1 then return end
		else
			registered = true
		end
	end
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
