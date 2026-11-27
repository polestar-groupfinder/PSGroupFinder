-- Group Finder for Polestar (PSGroupFinder): the main panel.
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
-- Two views in one window. The main view: Find a group / Stop and Announce,
-- Leave the group while in a party, the search in progress (its quests
-- leave it as their objectives are done), and the players found, each with
-- Whisper and Invite (only ever on your click); while the finder is off,
-- only a line saying so and Turn on. The cog in the title bar switches to
-- the settings view: the master switch, the settings by category, the
-- search languages, where Announce speaks, Messages, the channel's test
-- and, with Polestar, its options page. The panel is as tall as what it
-- shows.
-- With Polestar it sits against the guide window's right edge (left edge
-- when the right one has no room) and hides with it; without Polestar it is
-- a movable window of its own. The quest panel (QuestPanel.lua) takes the
-- same place.

local _, ns = ...
local L = ns.L
local W = ns.Widgets

local UI = {}
ns.UI = UI

local WIDTH, PAD = W.WIDTH, W.PAD
local ROWS = 6
local OPT_H = 20 -- pitch of the switches
-- The settings view: the master switch, then the settings by category:
-- { key, label, tooltip } or { header = label }. Polestar's page has the
-- same categories (Polestar/Options.lua).
local MASTER = { "enabled", "ENABLE", "ENABLE_TIP" }
local FOLDED = {
	{ header = "CAT_GROUPING" },
	{ "autoGroup", "AUTO_GROUP", "AUTO_GROUP_TIP" },
	{ "autoReply", "AUTO_REPLY", "AUTO_REPLY_TIP" },
	{ "shareCoords", "SHARE_COORDS", "SHARE_COORDS_TIP" },
	{ header = "CAT_PARTY" },
	{ "partyBox", "PARTY_BOX", "PARTY_BOX_TIP" },
	{ header = "CAT_CHAT" },
	{ "readChat", "READ_CHAT", "READ_CHAT_TIP" },
}
local HEADER_H = 18
local DEFAULT_ON = { partyBox = true } -- read as on unless set to false
local SESSION_LINES = 4
local view = "main" -- or "settings"

local panel
local rows = {}
local switches = {}
local widgets = {}
local docked = false
local host            -- the guide window to sit against, or nil
local dockable = {}   -- the frames that take the panel's place

---------------------------------------------------------------------------
-- Channels: the four names coloured by what each did, with a legend
---------------------------------------------------------------------------

local STATE_COLOR = { ok = "ff40ff40", sent = "ffffd100", fail = "ffff5050", skip = "ff909090" }

local function channelLine()
	local parts = {}
	for _, ct in ipairs(ns.Channels.ORDER) do
		local s = ns.Channels.status[ct]
		parts[#parts + 1] = "|c" .. (STATE_COLOR[s and s.state] or "ffaaaaaa") .. ct .. "|r"
	end
	return table.concat(parts, "  ")
end

local function channelTip(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText(L.LEGEND_TITLE, 1, 1, 1)
	GameTooltip:AddLine(L.LEGEND_BODY, nil, nil, nil, true)
	local best = ns.Channels.Best()
	if best then GameTooltip:AddLine(string.format(L.LEGEND_BEST, best), 0.25, 1, 0.25) end
	for _, ct in ipairs(ns.Channels.ORDER) do
		local s = ns.Channels.status[ct]
		if s and (s.state == "fail" or s.state == "skip") and s.code then
			GameTooltip:AddLine(ct .. ": " .. tostring(s.code), 1, 0.4, 0.4)
		end
	end
	GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------

local function at(frame, y, x, point)
	frame:ClearAllPoints()
	frame:SetPoint(point or "TOPLEFT", panel, point or "TOPLEFT", x or PAD, -y)
end

local function setting(key)
	if DEFAULT_ON[key] then return ns.Get(key) ~= false end
	return ns.Get(key) and true or false
end

-- The search in progress, from `y`; returns the new y.
local function layoutSession(y, active)
	widgets.sessionTitle:SetText(W.Dim() .. L.SESSION_TITLE .. "|r")
	widgets.sessionTitle:Show()
	at(widgets.sessionTitle, y)
	y = y + 14
	local list = ns.Session.List()
	for i = 1, SESSION_LINES do
		local fs = widgets.quest[i]
		local q = active and list[i]
		if q then
			if i == SESSION_LINES and #list > SESSION_LINES then
				fs:SetText(W.Dim() .. string.format(L.SESSION_MORE, #list - SESSION_LINES + 1) .. "|r")
			else
				fs:SetText(W.Soft() .. W.KindTag(q.kind) .. "|r" .. ns.Quests.Title(q.id))
			end
			at(fs, y, PAD + 4)
			fs:Show()
			y = y + 14
		end
	end
	return y + 6
end

-- The second line of a row: the first shared quest, their progress on it
-- (small, dim), how many more, or where a chat player asked.
local function playerInfo(e)
	local first = e.quests[1]
	local left = W.PeerProgress(e, first)
	local progress = left ~= "" and ("  " .. W.Dim() .. left .. "|r") or ""
	local more = #e.quests > 1 and ("  " .. W.Dim() .. "+" .. (#e.quests - 1) .. "|r") or ""
	local where = e.where and ("  " .. W.Dim() .. e.where .. "|r") or ""
	return W.Soft() .. ns.Quests.Title(first) .. "|r" .. progress .. more .. where
end

-- The players to list: those found through the finder, then those spotted
-- in public chat.
local function playersFound()
	local list = ns.Matcher.List()
	for _, e in ipairs(ns.ChatWatch.List()) do list[#list + 1] = e end
	return list
end

local MAIN, SETTINGS = {}, {} -- the widgets of each view

local function show(list, on)
	for _, w in ipairs(list) do w:SetShown(on) end
end

-- The settings view, from the top; returns its height.
local function layoutSettings(on)
	local x = PAD - (W.Theme() and 0 or 4)
	local y = 34
	for i, c in ipairs(switches) do
		if c.key then
			c:SetChecked(setting(c.key))
			local usable = on or c.key == "enabled"
			c:SetEnabled(usable)
			c:SetAlpha(usable and 1 or 0.5)
		end
		at(c, y + (c.psHeader and 4 or 0), c.psHeader and PAD or x)
		y = y + (c.psHeader and HEADER_H or OPT_H) + (i == 1 and 4 or 0)
	end
	y = y + 8
	at(widgets.langLabel, y + 2)
	widgets.langValue:SetText(W.Dim() .. ns.Lang.MineSummary() .. "|r")
	y = y + 24
	at(widgets.annLabel, y + 5)
	widgets.annTo:Refresh()
	at(widgets.annTo, y, WIDTH - PAD - widgets.annTo:GetWidth())
	y = y + 28
	widgets.chLabel:SetText(W.Dim() .. L.CHANNELS .. "|r  " .. channelLine())
	at(widgets.chLabel, y + 5)
	at(widgets.test, y, WIDTH - PAD - 56)
	widgets.chHit:ClearAllPoints()
	widgets.chHit:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -y)
	widgets.chHit:SetPoint("BOTTOMRIGHT", panel, "TOPLEFT", WIDTH - PAD - 62, -(y + 22))
	y = y + 30
	at(widgets.messages, y)
	widgets.options:SetShown(UI.hasOptions == true)
	at(widgets.options, y, WIDTH - PAD - widgets.options:GetWidth())
	return y + 22 + PAD
end

-- The main view, from the top; returns its height.
local function layoutMain(on)
	local y = 34
	widgets.offText:SetShown(not on)
	widgets.turnOn:SetShown(not on)
	for _, w in ipairs({ widgets.search, widgets.stop, widgets.announce, widgets.leaveGroup, widgets.warn }) do w:SetShown(on) end
	widgets.sessionTitle:Hide()
	for i = 1, SESSION_LINES do widgets.quest[i]:Hide() end
	if not on then
		widgets.empty:Hide()
		for _, r in ipairs(rows) do r.entry = nil r:Hide() end
		at(widgets.offText, y)
		at(widgets.turnOn, y + 38)
		return y + 38 + 26 + PAD
	end
	-- Find a group / Stop, Announce at the right.
	local active = ns.Session.Active()
	local cd = ns.Comm.SearchCooldown()
	widgets.search:SetEnabled(cd == 0)
	widgets.search:SetText(cd > 0 and string.format("%s (%d)", L.SEARCH, math.ceil(cd)) or (active and L.SEARCH_AGAIN or L.SEARCH))
	at(widgets.search, y)
	widgets.stop:SetShown(active)
	local acd = ns.Announce.Cooldown()
	widgets.announce:SetEnabled(acd == 0)
	widgets.announce:SetText(acd > 0 and string.format("%s (%d)", L.ANNOUNCE, math.ceil(acd)) or L.ANNOUNCE)
	at(widgets.announce, y, WIDTH - PAD - widgets.announce:GetWidth())
	y = y + 28
	local inParty = (IsInGroup and IsInGroup()) and true or false
	widgets.leaveGroup:SetShown(inParty)
	if inParty then
		at(widgets.leaveGroup, y)
		y = y + 26
	end
	-- The channel, only when it does not work.
	local broken = ns.Channels.Best() == nil
	widgets.warn:SetShown(broken)
	if broken then
		at(widgets.warn, y + 2)
		y = y + 20
	end
	if active then y = layoutSession(y + 4, true) end
	-- Players found.
	local found = playersFound()
	widgets.empty:SetShown(#found == 0)
	if #found == 0 then
		widgets.empty:SetText(active and L.EMPTY_SEARCHING or L.EMPTY)
		at(widgets.empty, y + 4, PAD + 2)
		y = y + 34
	end
	y = W.LayoutRows(panel, rows, found, y + 2, playerInfo)
	return y + PAD - 2
end

function UI.Refresh()
	if not (panel and panel:IsShown()) then return end
	local on = ns.Get("enabled") and true or false
	local settings = view == "settings"
	widgets.title:SetText(settings and L.SETTINGS or L.TITLE)
	widgets.gear.psActive = settings
	widgets.gear.psPaint(false)
	show(SETTINGS, settings)
	show(MAIN, not settings)
	if settings then
		if widgets.langPicker and widgets.langPicker:IsShown() then UI.RefreshLangPicker() end
		for _, r in ipairs(rows) do r:Hide() end
		panel:SetHeight(layoutSettings(on))
	else
		if widgets.langPicker then widgets.langPicker:Hide() end
		panel:SetHeight(layoutMain(on))
	end
end

-- The cog: the settings view, or back to the main view.
function UI.ToggleSettings()
	view = view == "settings" and "main" or "settings"
	UI.Refresh()
end
function UI.SettingsShown() return view == "settings" and UI.IsShown() end

---------------------------------------------------------------------------
-- Placement
---------------------------------------------------------------------------

local function placeFrame(f)
	f:ClearAllPoints()
	if host and host:IsShown() then
		docked = true
		-- Right of the guide window; left of it when the screen has no room.
		local right, scale = host.GetRight and host:GetRight(), host.GetEffectiveScale and host:GetEffectiveScale() or 1
		local room = UIParent:GetWidth() - ((right or 0) * scale) / (UIParent:GetEffectiveScale() or 1)
		if right and room < WIDTH + 10 then
			f:SetPoint("TOPRIGHT", host, "TOPLEFT", -6, 0)
		else
			f:SetPoint("TOPLEFT", host, "TOPRIGHT", 6, 0)
		end
		f:SetMovable(false)
		return
	end
	docked = false
	local pos = ns.Get("panelPos")
	if type(pos) == "table" then
		f:SetPoint(pos[1] or "CENTER", UIParent, pos[1] or "CENTER", pos[2] or 0, pos[3] or 0)
	else
		f:SetPoint("CENTER", UIParent, "CENTER", 260, 60)
	end
	f:SetMovable(true)
end

function UI.Place()
	for _, f in ipairs(dockable) do placeFrame(f) end
end

-- QuestPanel.lua: a frame that takes the panel's place.
function UI.Dockable(f)
	dockable[#dockable + 1] = f
	placeFrame(f)
end

-- Saves where a standalone panel was dragged.
function UI.SavePosition(f)
	local point, _, _, x, y = f:GetPoint(1)
	ns.Set("panelPos", { point, x, y })
end

-- Polestar.lua: the guide window to sit against (nil: stand alone).
function UI.SetHost(frame)
	host = frame
	UI.Place()
end

-- Polestar.lua: the guide window was shown or hidden. A docked panel is part
-- of the window: it goes and comes back with it.
function UI.HostShown(shown)
	if shown then UI.Place() end
	for _, f in ipairs(dockable) do
		if shown then
			if f.psDockHidden then f.psDockHidden = nil f:Show() end
		elseif docked and f:IsShown() then
			f.psDockHidden = true
			f:Hide()
		end
	end
end

---------------------------------------------------------------------------
-- Language picker, opened from the compact summary
---------------------------------------------------------------------------

-- Title + "All languages" + the language grid (two columns) when unfolded.
local function langPickerHeight(folded, nLangs)
	local lines = 1
	if not folded then lines = lines + math.ceil((nLangs or 0) / 2) end
	return 24 + lines * 18 + 16
end

local function langCheck(parent, label, getter, setter, help)
	local c = W.Check(parent, label, help, nil, function(on) setter(on) UI.RefreshLangPicker() UI.Refresh() end)
	c.psGet = getter
	return c
end

function UI.RefreshLangPicker()
	local box = widgets.langPicker
	if not box then return end
	local folded = ns.Lang.AcceptsAll()
	box.all:SetChecked(folded)
	for _, c in ipairs(box.langs) do
		c:SetChecked(c.psGet())
		c:SetShown(not folded)
	end
	box:SetHeight(langPickerHeight(folded, #box.langs))
end

local function buildLangPicker()
	local box = W.Box(panel)
	box:SetFrameStrata("DIALOG")
	box:SetSize(WIDTH - 16, langPickerHeight(ns.Lang.AcceptsAll(), #ns.Lang.ALL))
	box:SetPoint("TOPLEFT", widgets.langLabel, "BOTTOMLEFT", 8 - PAD, -6)
	local title = W.Text(box, "caption", GameFontNormalSmall)
	title:SetPoint("TOPLEFT", 8, -8)
	title:SetText(L.LANGS)
	box.all = langCheck(box, L.LANG_ALL, ns.Lang.AcceptsAll, ns.Lang.SetAcceptAll, L.LANGS_TIP)
	box.all:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -24)
	box.langs = {}
	local colW = math.floor((WIDTH - 16) / 2)
	for i, row in ipairs(ns.Lang.ALL) do
		local code = row.code
		local name = ns.Lang.Name(code)
		local c = langCheck(box, name, function() return ns.Lang.HasSearch(code) end,
			function(on) ns.Lang.SetSearch(code, on) end, string.format(L.LANG_ONE_TIP, name))
		c:SetPoint("TOPLEFT", box, "TOPLEFT", 6 + ((i - 1) % 2) * colW, -(42 + math.floor((i - 1) / 2) * 18))
		box.langs[#box.langs + 1] = c
	end
	return box
end

function UI.ToggleLangPicker()
	if not panel then return end
	if widgets.langPicker and widgets.langPicker:IsShown() then
		widgets.langPicker:Hide()
		return
	end
	widgets.langPicker = widgets.langPicker or buildLangPicker()
	widgets.langPicker:Show()
	UI.RefreshLangPicker()
end

function UI.LangPicker() return widgets.langPicker end

---------------------------------------------------------------------------
-- Announce (Announce.lua): the choices and the preview
---------------------------------------------------------------------------

function UI.AnnounceTargets()
	local out = {}
	for _, t in ipairs(ns.Announce.TARGETS) do out[#out + 1] = { value = t, label = ns.Announce.TargetName(t) } end
	return out
end

-- The tooltip shows the exact line that would go out. `self.questID`: one quest.
function UI.AnnounceTip(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText(L.ANNOUNCE, 1, 1, 1)
	local text = ns.Announce.Text(ns.Announce.Quests(self.questID))
	if text then
		GameTooltip:AddLine(string.format(L.ANNOUNCE_TIP, ns.Announce.TargetName(ns.Announce.Target())), nil, nil, nil, true)
		GameTooltip:AddLine(text, 1, 1, 1, true)
	else
		GameTooltip:AddLine(L.ANNOUNCE_NONE, nil, nil, nil, true)
	end
	GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------

local function text(role, fallback, justify)
	local fs = W.Text(panel, role, fallback)
	if justify then fs:SetJustifyH(justify) end
	return fs
end

local function add(list, w) list[#list + 1] = w return w end

local function build()
	panel = W.Window("PSGroupFinderPanel", { width = WIDTH, height = 300, movable = true, onMoved = UI.SavePosition })
	widgets.title = W.Title(panel, L.TITLE)
	W.CloseButton(panel)
	-- The cog, left of the close button.
	widgets.gear = W.IconButton(panel, "icon-gear", L.SETTINGS_TIP, UI.ToggleSettings)
	widgets.gear:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -32, -6)

	-------------------------------------------------------------------------
	-- Main view
	-------------------------------------------------------------------------
	widgets.offText = add(MAIN, text("small", GameFontHighlightSmall, "LEFT"))
	widgets.offText:SetWidth(WIDTH - 2 * PAD)
	widgets.offText:SetText(W.Dim() .. L.OFF_TEXT .. "|r")
	widgets.turnOn = add(MAIN, W.Button(panel, L.TURN_ON, 120, function() ns.SetEnabled(true) end))
	widgets.search = add(MAIN, W.Button(panel, L.SEARCH, 168, function() ns.Search() UI.Refresh() end))
	widgets.stop = add(MAIN, W.Button(panel, L.STOP, 70, function() ns.Comm.StopSearch() UI.Refresh() end))
	widgets.stop:SetPoint("LEFT", widgets.search, "RIGHT", 6, 0)
	widgets.announce = add(MAIN, W.Button(panel, L.ANNOUNCE, 96, function() ns.Announce.Send() UI.Refresh() end))
	widgets.announce:SetScript("OnEnter", UI.AnnounceTip)
	widgets.announce:SetScript("OnLeave", function() GameTooltip:Hide() end)
	widgets.leaveGroup = add(MAIN, W.Button(panel, L.LEAVE_GROUP, 140, function() ns.Leave.Do() end))
	W.Tip(widgets.leaveGroup, L.LEAVE_GROUP, L.LEAVE_GROUP_TIP)
	widgets.warn = add(MAIN, text("small", GameFontHighlightSmall, "LEFT"))
	widgets.warn:SetWidth(WIDTH - 2 * PAD)
	widgets.warn:SetText(W.Hex("warning", "fffabf4d") .. L.CHANNEL_BROKEN .. "|r")
	widgets.sessionTitle = add(MAIN, text("caption", GameFontNormalSmall, "LEFT"))
	widgets.quest = {}
	for i = 1, SESSION_LINES do
		local fs = add(MAIN, text("small", GameFontHighlightSmall, "LEFT"))
		fs:SetWordWrap(false)
		fs:SetWidth(WIDTH - 2 * PAD - 4)
		widgets.quest[i] = fs
	end
	widgets.empty = add(MAIN, text("note", GameFontDisableSmall, "LEFT"))
	widgets.empty:SetWidth(WIDTH - 2 * PAD - 4)
	for i = 1, ROWS do rows[i] = W.PlayerRow(panel) end

	-------------------------------------------------------------------------
	-- Settings view
	-------------------------------------------------------------------------
	switches[1] = add(SETTINGS, W.Check(panel, L[MASTER[2]], L[MASTER[3]], MASTER[1], ns.SetEnabled))
	switches[1].psHeader = false
	for _, sw in ipairs(FOLDED) do
		local c
		if sw.header then
			c = W.Text(panel, "caption", GameFontNormalSmall)
			c:SetText(W.Dim() .. L[sw.header] .. "|r")
			c.psHeader, c.key = true, false
		else
			c = W.Check(panel, L[sw[2]], L[sw[3]], sw[1])
			c.psHeader = false
		end
		switches[#switches + 1] = add(SETTINGS, c)
	end
	-- Languages: a compact summary; a click opens the picker.
	widgets.langLabel = add(SETTINGS, text("small", GameFontHighlightSmall))
	widgets.langLabel:SetText(L.LANGS)
	widgets.langValue = add(SETTINGS, text("small", GameFontHighlightSmall))
	widgets.langValue:SetPoint("LEFT", widgets.langLabel, "RIGHT", 8, 0)
	local langHit = add(SETTINGS, CreateFrame("Button", nil, panel))
	langHit:SetPoint("TOPLEFT", widgets.langLabel, "TOPLEFT", 0, 4)
	langHit:SetPoint("BOTTOMRIGHT", widgets.langLabel, "BOTTOMLEFT", WIDTH - 2 * PAD, -4)
	langHit:SetScript("OnClick", UI.ToggleLangPicker)
	W.Tip(langHit, L.LANGS, L.LANGS_TIP)
	-- Where Announce speaks.
	widgets.annLabel = add(SETTINGS, text("small", GameFontHighlightSmall))
	widgets.annLabel:SetText(L.ANN_TO)
	widgets.annTo = add(SETTINGS, W.Choice(panel, 170, {
		items = UI.AnnounceTargets, get = ns.Announce.Target, set = function(v) ns.Set("announceTo", v) end,
		title = L.ANN_TO, help = L.ANN_TO_TIP,
	}))
	-- The channel and its test.
	widgets.chLabel = add(SETTINGS, text("small", GameFontHighlightSmall, "LEFT"))
	widgets.chHit = add(SETTINGS, CreateFrame("Frame", nil, panel))
	widgets.chHit:EnableMouse(true)
	widgets.chHit:SetScript("OnEnter", channelTip)
	widgets.chHit:SetScript("OnLeave", function() GameTooltip:Hide() end)
	widgets.test = add(SETTINGS, W.Button(panel, L.TEST_SHORT, 56, function() ns.TestChannels() end, 20))
	-- Messages, and Polestar's options page.
	widgets.messages = add(SETTINGS, W.Button(panel, L.MESSAGES .. "…", 120, function() UI.ShowMessages() end, 22))
	W.Tip(widgets.messages, L.MESSAGES, L.MESSAGES_TIP)
	widgets.options = add(SETTINGS, W.Button(panel, L.OPTIONS_SHORT, 150, function() if ns.OpenOptions then ns.OpenOptions() end end, 22))
	W.Tip(widgets.options, L.OPTIONS_SHORT, L.OPTIONS_TIP)

	W.EverySecond(panel, UI.Refresh)
	panel:SetScript("OnShow", function() UI.Place() UI.Refresh() end)
	panel:Hide()
	local T = W.Theme()
	if T and T.OnChanged then pcall(T.OnChanged, UI.Refresh) end
	UI.Dockable(panel)
end

-- Polestar.lua: whether Polestar's settings have our page (shows Options).
function UI.SetHasOptions(has)
	UI.hasOptions = has and true or false
	if widgets.options and view == "settings" then widgets.options:SetShown(UI.hasOptions) end
end

function UI.Show()
	if ns.QuestUI then ns.QuestUI.Close() end
	if not panel then build() end
	UI.Place()
	panel:Show()
	UI.Refresh()
end

function UI.Hide()
	if panel then panel:Hide() panel.psDockHidden = nil end
end

function UI.Toggle()
	-- The quest panel stands in the main panel's place: close it first.
	if ns.QuestUI and ns.QuestUI.IsShown() then ns.QuestUI.Close() return end
	if panel and panel:IsShown() then panel:Hide() else UI.Show() end
end

function UI.IsShown() return panel and panel:IsShown() or false end

-- Tests.
function UI.EmptyCaption() return widgets.empty and widgets.empty:GetText() or nil end
function UI.RowFrames() return rows end
function UI.LeaveGroupButton() return widgets.leaveGroup end
function UI.AnnounceWidgets() return widgets.announce, widgets.annTo end
function UI.GearButton() return widgets.gear end
function UI.Switch(key)
	for _, c in ipairs(switches) do if c.key == key then return c end end
end

ns.TogglePanel = UI.Toggle
ns.ResetPanel = UI.Place

for _, msg in ipairs({ "PEERS", "CHANNELS", "SETTING", "ENABLED", "SEARCHED", "SESSION", "LANG", "QUEST_SEARCHED", "ANNOUNCED" }) do
	ns.On(msg, UI.Refresh)
end

-- Someone new found within OPEN_AFTER seconds of your own search, while the
-- panel is closed: open it. Never on other players' searches alone.
local OPEN_AFTER = 120
ns.On("PEER_NEW", function()
	if ns.Get("enabled") and not UI.IsShown() and ns.searchedAt and ns.Now() - ns.searchedAt < OPEN_AFTER then UI.Show() end
end)
