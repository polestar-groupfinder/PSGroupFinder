-- Group Finder for Polestar (PSGroupFinder): our page in Polestar's settings window.
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
-- Polestar.RegisterOptions (ARCHITECTURE.md, "Options registry") takes our
-- page, two tabs: Essentials (on/off, grouping, the search languages, whose
-- rows fold away (`needs`) while "All languages" is on, key bindings) and
-- Messages (the message box and its style, then each message: its switch,
-- a button to edit its text, its key binding). Called under pcall; when it is missing or refuses,
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

---------------------------------------------------------------------------
-- The messages' text boxes. Polestar's registry has no text field, so each
-- message's text row is a wide button row (its button: Default) and we lay
-- an edit box over its free middle. INTERNAL, under pcall:
-- Polestar.Widgets.ActionRow (Polestar_Options) builds the row, and
-- Options.lua's makeControl stamps it with `psControl` (our control table)
-- right after; a frame later we know which rows are ours.
---------------------------------------------------------------------------

local textRows = {} -- our text row control -> message kind

-- Hello is only ever offered by the message box: with the box off, its rows
-- and the style cards are greyed (a control's `disabled`).
local function boxOff() return ns.Get("partyBox") == false end
local NEEDS_BOX = { hello = true }
local function offFor(kind)
	return not ns.Messages.Enabled(kind) or (NEEDS_BOX[kind] and boxOff())
end
local boxes = {}    -- message kind -> its edit box (the last one built)

local function tip(e, kind)
	GameTooltip:SetOwner(e, "ANCHOR_TOP")
	GameTooltip:SetText(L.MSG_VARS_TITLE, 1, 1, 1)
	GameTooltip:AddLine(L.MSG_VARS, nil, nil, nil, true)
	local said = ns.Messages.Preview(e:GetText())
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(#ns.Messages.SampleIds() > 0 and L.MSG_WILL_SAY or L.MSG_WILL_SAY_EXAMPLE)
	GameTooltip:AddLine(said ~= "" and said or L.MSG_OFF, 1, 1, 1, true)
	GameTooltip:Show()
end

local function textBox(row, kind)
	if rawget(row, "psgfEdit") or not rawget(row, "Button") then return end
	local W = ns.Widgets
	-- Polestar's own button stands in its control column (compact layout):
	-- ours goes to the row's right end, the box takes the whole width between.
	-- Polestar repaints its button (alpha, shown) on each refresh: keep it
	-- hidden for good, whatever brings it back.
	local theirs = row.Button
	theirs:Hide()
	if theirs.EnableMouse then theirs:EnableMouse(false) end
	if theirs.HookScript then theirs:HookScript("OnShow", function(b) b:Hide() end) end
	if hooksecurefunc then
		pcall(hooksecurefunc, theirs, "SetAlpha", function(b, a) if a ~= 0 then b:SetAlpha(0) end end)
	end
	theirs:SetAlpha(0)
	local reset = W.Button(row, L.MSG_RESET, 90, function()
		ns.Messages.Save(kind, ns.Messages.Default(kind))
		if boxes[kind] then boxes[kind]:SetText(ns.Messages.Template(kind)) end
	end, 22)
	reset:SetPoint("RIGHT", row, "RIGHT", -12, 0)
	reset:SetFrameLevel((tonumber(row:GetFrameLevel()) or 1) + 3)
	W.Tip(reset, L.MSG_RESET, L.MSG_RESET_TIP)
	row.psgfReset = reset
	local e = CreateFrame("EditBox", nil, row, (not W.Theme()) and "InputBoxTemplate" or nil)
	e:SetHeight(24)
	e:SetPoint("LEFT", row, "LEFT", 120, 0)
	e:SetPoint("RIGHT", reset, "LEFT", -10, 0)
	e:SetAutoFocus(false)
	e:SetMaxLetters(200)
	e:SetFontObject(GameFontHighlightSmall)
	if W.Theme() then
		e:SetTextInsets(8, 8, 0, 0)
		W.Skin(e, "editbox")
	end
	e:SetFrameLevel((tonumber(row:GetFrameLevel()) or 1) + 3)
	-- Polestar's compact layout sizes a row to its label and control: ours
	-- spans its section, as wide as the row's left inset in the view mirrored.
	local function widen()
		local _, rel, _, px = row:GetPoint(1)
		if type(rel) == "table" and type(px) == "number" then row:SetPoint("RIGHT", rel, "RIGHT", -px, 0) end
	end
	local function sync()
		widen()
		if theirs:IsShown() then theirs:Hide() end
		if not e:HasFocus() then e:SetText(ns.Messages.Template(kind)) end
		local off = offFor(kind)
		e:SetAlpha(off and 0.5 or 1)
		reset:SetAlpha(NEEDS_BOX[kind] and boxOff() and 0.5 or 1)
		if e.SetEnabled then e:SetEnabled(not (NEEDS_BOX[kind] and boxOff())) end
	end
	e:SetScript("OnEnterPressed", function() ns.Messages.Save(kind, e:GetText()) e:ClearFocus() end)
	e:SetScript("OnEditFocusLost", function() ns.Messages.Save(kind, e:GetText()) sync() end)
	e:SetScript("OnEscapePressed", function() e:ClearFocus() e:SetText(ns.Messages.Template(kind)) end)
	e:SetScript("OnEnter", function() tip(e, kind) end)
	e:SetScript("OnLeave", function() GameTooltip:Hide() end)
	e:SetScript("OnTextChanged", function(_, user)
		if user and GameTooltip:IsOwned(e) then tip(e, kind) end
	end)
	local refresh = row.Refresh
	row.Refresh = function(self, ...)
		if refresh then refresh(self, ...) end
		sync()
	end
	row.psgfEdit = e
	boxes[kind] = e
	sync()
end

local wrappedRow
local function hookTextRows()
	local W = P and P.Widgets
	if type(W) ~= "table" or type(rawget(W, "ActionRow")) ~= "function" or W.ActionRow == wrappedRow then return end
	local orig = W.ActionRow
	wrappedRow = function(...)
		local row = orig(...)
		ns.After(0, function()
			pcall(function()
				local kind = row and textRows[row.psControl]
				if kind then textBox(row, kind) end
			end)
		end)
		return row
	end
	W.ActionRow = wrappedRow
end
-- Tests.
function ns.OptionsTextBox(kind) return boxes[kind] end
ns.HookTextRows = function() hookTextRows() end
ns.TextRows = textRows

local function toggle(labelKey, key, onSet)
	return {
		kind = "toggle", label = L[labelKey], help = L[labelKey .. "_TIP"], search = "group finder party quest lfg",
		get = function() return ns.Get(key) and true or false end,
		set = function(v) if onSet then onSet(v and true or false) else ns.Set(key, v and true or false) end end,
	}
end

-- A row alone on its line takes the whole line: no half and no hairline
-- in the middle of the section.
local function wide(c)
	c.wide = true
	return c
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
		{ kind = "toggle", wide = true, label = L.LANG_ALL, help = L.LANGS_TIP, search = "language",
			get = ns.Lang.AcceptsAll, set = ns.Lang.SetAcceptAll },
	}
	for _, row in ipairs(ns.Lang.Offered()) do
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
	-- One section per message: its switch and its key binding on one line,
	-- then its text on a whole line (a wide button row that gets our text box,
	-- see textBox below; its button puts the default back).
	local function message(kind)
		local K = kind:upper()
		local controls = {
			{ kind = "toggle", label = L["MSG_" .. K .. "_ON"], help = L["MSG_" .. K .. "_ON_TIP"], search = "message",
				get = function() return ns.Messages.Enabled(kind) end,
				set = function(v) ns.Messages.SetEnabled(kind, v) end },
		}
		local b = ns.Messages.KINDS[kind].binding
		if b then controls[#controls + 1] = { kind = "binding", action = b, label = L["BINDING_" .. K], help = L["BINDING_" .. K .. "_TIP"] } end
		-- Without a key binding, the switch is alone on its line.
		if not b then controls[1].wide = true end
		if kind == "announce" then
			controls[#controls + 1] = { kind = "dropdown", wide = true, label = L.ANN_TO, help = L.ANN_TO_TIP, search = "announce channel general",
				choices = ns.UI.AnnounceTargets(), get = ns.Announce.Target, set = function(v) ns.Set("announceTo", v) end }
		end
		local text = { kind = "button", wide = true, label = L.MSG_TEXT, button = L.MSG_RESET, search = "message text edit default",
			help = L.MSG_VARS,
			onClick = function()
				-- Without our text box (Polestar changed its rows), the Messages window.
				if not boxes[kind] then return ns.UI.ShowMessages(kind) end
				ns.Messages.Save(kind, ns.Messages.Default(kind))
				boxes[kind]:SetText(ns.Messages.Template(kind))
			end }
		textRows[text] = kind
		controls[#controls + 1] = text
		if NEEDS_BOX[kind] then
			for _, c in ipairs(controls) do c.disabled = boxOff end
		end
		return { L["MSG_" .. K], controls, L.TAB_MESSAGES }
	end
	return {
		{ L.OPT_SECTION, {
			-- The channel test is a command (/psgf test), listed in the tooltip.
			wide(toggle("ENABLE", "enabled", ns.SetEnabled)),
		} },
		{ L.CAT_GROUPING, {
			toggle("AUTO_GROUP", "autoGroup"),
			toggle("AUTO_REPLY", "autoReply"),
			toggle("SHARE_COORDS", "shareCoords"),
			toggle("OPEN_NEAR", "openNear"),
			toggle("AUTO_RETRY", "autoRetry"),
		} },
		{ L.LANGS, langs },
		{ L.CAT_KEYS, {
			binding("PSGF_SEARCH", "BINDING_SEARCH"),
			binding("PSGF_TOGGLE_PANEL", "BINDING_PANEL"),
		} },
		-- The Messages tab: the message box, then each message.
		-- The box's switch on its own, then its style: picture cards showing
		-- the box itself at its real size (it is small), as the guide window's
		-- presets stand in their own section.
		{ L.BOX_SECTION, {
			wide(toggle("PARTY_BOX", "partyBox")),
		}, L.TAB_MESSAGES },
		{ L.BOX_STYLE_SECTION, {
			{ kind = "cards", label = L.BOX_STYLE, help = L.BOX_STYLE_TIP, search = "style compact preview", disabled = boxOff,
				art = { ns.PartyBox.PREVIEW_W, ns.PartyBox.PREVIEW_H },
				choices = {
					{ value = "polestar", label = L.BOX_STYLE_POLESTAR, draw = function(art) ns.PartyBox.DrawPreview(art, "polestar") end },
					{ value = "compact", label = L.BOX_STYLE_COMPACT, draw = function(art) ns.PartyBox.DrawPreview(art, "compact") end },
				},
				get = function() return ns.PartyBox.Style() end,
				set = function(v) ns.Set("partyBoxStyle", v) end },
		}, L.TAB_MESSAGES },
		message("hello"),
		message("goodbye"),
		message("announce"),
		message("invite"),
		message("ask"),
	}
end

local function registerOptions()
	if registered or type(P.RegisterOptions) ~= "function" then return end
	for i, sec in ipairs(sections()) do
		local spec = { page = L.OPT_SECTION, key = KEY, icon = ns.ICON, tab = sec[3] or L.TAB_ESSENTIALS, section = sec[1], controls = sec[2] }
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
	pcall(hookTextRows)
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
	pcall(hookTextRows)
	ns.RegisterEvent("ADDON_LOADED", function(_, name)
		if name == "Polestar_Options" then hookSidebarIcon() pcall(hookTextRows) end
	end)
	ns.On("LANG", refreshLangs)
	ns.On("SETTING", function(key)
		-- Our get/set rows fire no SETTING_CHANGED: repaint the page so the
		-- rows that hang on the box grey or come back.
		if key == "partyBox" then refreshLangs() end
		if type(key) ~= "string" or not (key:find("Msg$") or key:find("On$") or key == "partyBox") then return end
		for kind, e in pairs(boxes) do
			if not e:HasFocus() then e:SetText(ns.Messages.Template(kind)) end
			e:SetAlpha(offFor(kind) and 0.5 or 1)
		end
	end)
	local U = P.UI
	if registered and U and type(U.ShowOptions) == "function" then ns.UI.SetHasOptions(true) end
end)
