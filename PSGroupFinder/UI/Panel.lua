-- Group Finder for Polestar (PSGroupFinder): the main panel.
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
-- Two views in one window. The main view: Find a group (and Stop during a
-- search), Announce under it, their waits draining their accent fill; Leave
-- the group while in a party; the players found, each with Whisper and
-- Invite (only ever on your click). The quests searched are not listed:
-- Polestar's guide window shows the step. While the finder is off, only a
-- line saying so and Turn on. The cog in the title bar switches to the
-- settings view: the master switch, the settings by category and Options
-- (Polestar's page, which holds the search languages, where Announce speaks
-- and the messages; without Polestar those are in the settings view). The
-- panel is as tall as what it shows.
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
	{ "openNear", "OPEN_NEAR", "OPEN_NEAR_TIP" },
	{ header = "CAT_PARTY" },
	{ "partyBox", "PARTY_BOX", "PARTY_BOX_TIP" },
}
local HEADER_H = 18
local DEFAULT_ON = { partyBox = true } -- read as on unless set to false
local view = "main" -- or "settings"

local panel
local rows = {}
local switches = {}
local widgets = {}
local docked = false
local host            -- the guide window to sit against, or nil
local dockable = {}   -- the frames that take the panel's place

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

-- The second line of a row: the first shared quest, their progress on it
-- (small, dim) and how many more.
local function playerInfo(e)
	local first = e.quests[1]
	local left = W.PeerProgress(e, first)
	local progress = left ~= "" and ("  " .. W.Dim() .. left .. "|r") or ""
	local more = #e.quests > 1 and ("  " .. W.Dim() .. "+" .. (#e.quests - 1) .. "|r") or ""
	return W.Soft() .. ns.Quests.Title(first) .. "|r" .. progress .. more
end

-- The players to list.
local function playersFound()
	local list = ns.Matcher.List()
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
	-- The search languages live on Polestar's options page; here only
	-- without it (no other place to set them).
	local langs = not UI.hasOptions
	for _, w in ipairs(widgets.langWidgets) do w:SetShown(langs) end
	if langs then
		at(widgets.langLabel, y + 2)
		widgets.langValue:SetText(W.Dim() .. ns.Lang.MineSummary() .. "|r")
		y = y + 24
	elseif widgets.langPicker then
		widgets.langPicker:Hide()
	end
	-- Where Announce speaks and the Messages window: on Polestar's options
	-- page (its Messages tab); here only without it.
	local own = not UI.hasOptions
	for _, w in ipairs({ widgets.annLabel, widgets.annTo, widgets.messages }) do w:SetShown(own) end
	widgets.options:SetShown(not own)
	if own then
		at(widgets.annLabel, y + 5)
		widgets.annTo:Refresh()
		at(widgets.annTo, y, WIDTH - PAD - widgets.annTo:GetWidth())
		y = y + 32
		at(widgets.messages, y)
	else
		at(widgets.options, y)
	end
	return y + 22 + PAD
end

-- The main view, from the top; returns its height.
local function layoutMain(on)
	local y = 34
	widgets.offText:SetShown(not on)
	widgets.turnOn:SetShown(not on)
	for _, w in ipairs({ widgets.search, widgets.stop, widgets.announce, widgets.leaveGroup, widgets.leaveQuiet, widgets.warn }) do w:SetShown(on) end
	if not on then
		widgets.empty:Hide()
		for _, r in ipairs(rows) do r.entry = nil r:Hide() end
		at(widgets.offText, y)
		at(widgets.turnOn, y + 38)
		return y + 38 + 26 + PAD
	end
	-- Find a group (Stop at its right during a search), Announce under it.
	-- Their wait drains their accent fill (W.Drain), no number to read.
	local active = ns.Session.Active()
	local cd = ns.Comm.SearchCooldown()
	widgets.search:SetEnabled(cd == 0)
	widgets.search:SetText(cd > 0 and L.SEARCHING or (active and L.SEARCH_AGAIN or L.SEARCH))
	widgets.search:SetWidth(WIDTH - 2 * PAD - (active and 76 or 0))
	at(widgets.search, y)
	widgets.stop:SetShown(active)
	y = y + 28
	local ann = ns.Messages.Enabled("announce")
	widgets.announce:SetShown(ann)
	if ann then
		widgets.announce:SetEnabled(ns.Announce.Cooldown() == 0)
		at(widgets.announce, y)
		y = y + 28
	end
	local inParty = ns.InGroup()
	-- Leaving: with the goodbye message on (a finder group), two choices,
	-- Say goodbye & leave or just Leave; else one Leave the group.
	local speaks = inParty and ns.Leave.Speaks()
	widgets.leaveGroup:SetShown(inParty)
	widgets.leaveQuiet:SetShown(speaks and true or false)
	if inParty then
		widgets.leaveGroup:SetText(speaks and L.BOX_SAY_GOODBYE or L.LEAVE_GROUP)
		widgets.leaveGroup:SetWidth(WIDTH - 2 * PAD - (speaks and 106 or 0))
		at(widgets.leaveGroup, y)
		y = y + 28
	end
	-- The channel, only when it does not work.
	local broken = ns.Channels.Best() == nil
	widgets.warn:SetShown(broken)
	if broken then
		at(widgets.warn, y + 2)
		y = y + 20
	end
	-- Players found.
	local found = playersFound()
	widgets.empty:SetShown(#found == 0)
	if #found == 0 then
		widgets.empty:SetText(not active and L.EMPTY or (cd > 0 and L.EMPTY_SEARCHING or L.EMPTY_WAITING))
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
	widgets.title:SetText((settings and L.SETTINGS or L.TITLE) .. (ns.Demo and ns.Demo.Active() and " |cff66ccff(demo)|r" or ""))
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
	box:SetSize(WIDTH - 16, langPickerHeight(ns.Lang.AcceptsAll(), #ns.Lang.Offered()))
	box:SetPoint("TOPLEFT", widgets.langLabel, "BOTTOMLEFT", 8 - PAD, -6)
	local title = W.Text(box, "caption", GameFontNormalSmall)
	title:SetPoint("TOPLEFT", 8, -8)
	title:SetText(L.LANGS)
	box.all = langCheck(box, L.LANG_ALL, ns.Lang.AcceptsAll, ns.Lang.SetAcceptAll, L.LANGS_TIP)
	box.all:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -24)
	box.langs = {}
	local colW = math.floor((WIDTH - 16) / 2)
	for i, row in ipairs(ns.Lang.Offered()) do
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
-- Tests: the search languages line of the settings view.
function UI.LangLine() return widgets.langLabel end

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
	widgets.search = add(MAIN, W.Button(panel, L.SEARCH, WIDTH - 2 * PAD, function() ns.Search() UI.Refresh() end))
	W.Drain(widgets.search, function() return ns.Comm.SearchCooldown() / ns.Comm.SEARCH_GAP end)
	widgets.stop = add(MAIN, W.Button(panel, L.STOP, 70, function() ns.Comm.StopSearch() UI.Refresh() end))
	widgets.stop:SetPoint("LEFT", widgets.search, "RIGHT", 6, 0)
	widgets.announce = add(MAIN, W.Button(panel, L.ANNOUNCE, WIDTH - 2 * PAD, function() ns.Announce.Send() UI.Refresh() end))
	W.Drain(widgets.announce, function() return ns.Announce.Cooldown() / ns.Announce.GAP end)
	widgets.announce:SetScript("OnEnter", UI.AnnounceTip)
	widgets.announce:SetScript("OnLeave", function() GameTooltip:Hide() end)
	widgets.leaveGroup = add(MAIN, W.Button(panel, L.LEAVE_GROUP, WIDTH - 2 * PAD, function() ns.Leave.Do() end))
	W.Tip(widgets.leaveGroup, L.LEAVE_GROUP, L.LEAVE_GROUP_TIP)
	widgets.leaveQuiet = add(MAIN, W.Button(panel, L.LEAVE_QUIET, 100, function() ns.Leave.Do(true) end))
	widgets.leaveQuiet:SetPoint("LEFT", widgets.leaveGroup, "RIGHT", 6, 0)
	W.Tip(widgets.leaveQuiet, L.LEAVE_QUIET, L.LEAVE_QUIET_TIP)
	widgets.warn = add(MAIN, text("small", GameFontHighlightSmall, "LEFT"))
	widgets.warn:SetWidth(WIDTH - 2 * PAD)
	widgets.warn:SetText(W.Hex("warning", "fffabf4d") .. L.CHANNEL_BROKEN .. "|r")
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
	widgets.langWidgets = { widgets.langLabel, widgets.langValue, langHit }
	-- Where Announce speaks.
	widgets.annLabel = add(SETTINGS, text("small", GameFontHighlightSmall))
	widgets.annLabel:SetText(L.ANN_TO)
	widgets.annTo = add(SETTINGS, W.Choice(panel, 170, {
		items = UI.AnnounceTargets, get = ns.Announce.Target, set = function(v) ns.Set("announceTo", v) end,
		title = L.ANN_TO, help = L.ANN_TO_TIP,
	}))
	-- Messages, and Polestar's options page.
	widgets.messages = add(SETTINGS, W.Button(panel, L.MESSAGES .. "…", 120, function() UI.ShowMessages() end, 22))
	W.Tip(widgets.messages, L.MESSAGES, L.MESSAGES_TIP)
	widgets.options = add(SETTINGS, W.Button(panel, L.OPTIONS_SHORT, 120, function() if ns.OpenOptions then ns.OpenOptions() end end, 22))
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
	if view == "settings" then UI.Refresh() end
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
function UI.LeaveQuietButton() return widgets.leaveQuiet end
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
