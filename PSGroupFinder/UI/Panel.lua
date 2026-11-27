-- Group Finder for Polestar (PSGroupFinder): the main panel.
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
-- From top to bottom: the master switch; Settings (folded by default: the
-- other switches) and Messages; the search languages; Find a group / Stop
-- (/ Options when Polestar's settings have our page); Announce with its
-- channel; Leave the group while in a party; the search in progress
-- (its quests leave it as their objectives are done), the channels with
-- their legend, and the players found, each with Whisper and Invite (only
-- ever on your click). The panel is as tall as what it shows.
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
-- The master switch, always shown, then the settings that fold under
-- Settings, by category: { key, label, tooltip } or { header = label }.
-- Polestar's page has the same categories (Polestar/Options.lua).
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
local HEADER_H = 16
local DEFAULT_ON = { partyBox = true } -- read as on unless set to false
local SESSION_LINES = 4
local settingsOpen = false

local function foldedHeight()
	local h = 0
	for _, f in ipairs(FOLDED) do h = h + (f.header and HEADER_H or OPT_H) end
	return h
end

-- Where the part under the switches starts.
local function contentTop()
	return 34 + OPT_H + 22 + (settingsOpen and foldedHeight() or 0)
end

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
	if not active then
		widgets.none:SetText(W.Dim() .. L.SESSION_NONE .. "|r")
		at(widgets.none, y, PAD + 4)
		widgets.none:Show()
		y = y + 14
	end
	return y + 6
end

-- The channel line and Test, from `y`; returns the new y.
local function layoutChannels(y)
	widgets.chLabel:SetText(W.Dim() .. L.CHANNELS .. "|r")
	at(widgets.chLabel, y + 4)
	widgets.channels:SetText(channelLine())
	widgets.channels:ClearAllPoints()
	widgets.channels:SetPoint("LEFT", widgets.chLabel, "RIGHT", 8, 0)
	at(widgets.test, y, WIDTH - PAD - 56)
	widgets.chHit:ClearAllPoints()
	widgets.chHit:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -y)
	widgets.chHit:SetPoint("BOTTOMRIGHT", panel, "TOPLEFT", WIDTH - PAD - 62, -(y + 22))
	return y + 28
end

local function playerInfo(e)
	local first = e.quests[1]
	local more = #e.quests > 1 and ("  " .. W.Dim() .. "+" .. (#e.quests - 1) .. "|r") or ""
	local where = e.where and ("  " .. W.Dim() .. e.where .. "|r") or ""
	return W.Soft() .. W.KindTag(e.kinds and e.kinds[first]) .. "|r" .. ns.Quests.Title(first) .. more .. where
end

-- The players to list: those found through the finder, then those spotted
-- in public chat.
local function playersFound()
	local list = ns.Matcher.List()
	for _, e in ipairs(ns.ChatWatch.List()) do list[#list + 1] = e end
	return list
end

function UI.Refresh()
	if not (panel and panel:IsShown()) then return end
	local on = ns.Get("enabled") and true or false

	-- Switches: only the master switch works while off.
	local x = PAD - (W.Theme() and 0 or 4)
	local fy = 34 + OPT_H + 22
	for _, c in ipairs(switches) do
		if c.key then
			c:SetChecked(setting(c.key))
			local usable = on or c.key == "enabled"
			c:SetEnabled(usable)
			c:SetAlpha(usable and 1 or 0.5)
		end
		if c ~= switches[1] then
			c:SetShown(settingsOpen)
			if settingsOpen then
				at(c, fy + (c.psHeader and 3 or 0), c.psHeader and PAD or x)
				fy = fy + (c.psHeader and HEADER_H or OPT_H)
			end
		end
	end
	widgets.settings:SetText((settingsOpen and L.SETTINGS_OPEN or L.SETTINGS_CLOSED))
	local top = contentTop()
	at(widgets.below, top)
	widgets.langValue:SetText(W.Dim() .. ns.Lang.MineSummary() .. "|r")
	widgets.annTo:Refresh()
	if widgets.langPicker and widgets.langPicker:IsShown() then UI.RefreshLangPicker() end

	-- Buttons.
	local active = ns.Session.Active()
	local cd = ns.Comm.SearchCooldown()
	widgets.search:SetEnabled(on and cd == 0)
	widgets.search:SetText(cd > 0 and string.format("%s (%d)", L.SEARCH, math.ceil(cd)) or (active and L.SEARCH_AGAIN or L.SEARCH))
	widgets.stop:SetShown(active)
	local acd = ns.Announce.Cooldown()
	widgets.announce:SetEnabled(on and acd == 0)
	widgets.announce:SetText(acd > 0 and string.format("%s (%d)", L.ANNOUNCE, math.ceil(acd)) or L.ANNOUNCE)
	local inParty = (IsInGroup and IsInGroup()) and true or false
	widgets.leaveGroup:SetShown(inParty)

	-- Off: only the switches and the buttons; the rest has nothing to say.
	local y = top + 86 + (inParty and 24 or 0)
	for _, w in ipairs({ widgets.sessionTitle, widgets.chLabel, widgets.channels, widgets.test, widgets.chHit }) do
		w:SetShown(on)
	end
	for i = 1, SESSION_LINES do widgets.quest[i]:Hide() end
	widgets.none:Hide()
	if on then
		y = layoutSession(y, active)
		y = layoutChannels(y)
	end

	-- Players found.
	local found = on and playersFound() or {}
	widgets.empty:SetShown(on and #found == 0)
	if on and #found == 0 then
		widgets.empty:SetText(active and L.EMPTY_SEARCHING or L.EMPTY)
		at(widgets.empty, y + 2, PAD + 2)
		y = y + 38
	end
	y = W.LayoutRows(panel, rows, found, y, playerInfo)
	panel:SetHeight(y + PAD - 2)
end

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
	box:SetPoint("TOPLEFT", widgets.below, "TOPLEFT", 8 - PAD, -22)
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

local function build()
	panel = W.Window("PSGroupFinderPanel", { width = WIDTH, height = 300, movable = true, onMoved = UI.SavePosition })
	W.Title(panel, L.TITLE)
	W.CloseButton(panel)

	-- The switches (placed in UI.Refresh: all but the first fold away).
	switches[1] = W.Check(panel, L[MASTER[2]], L[MASTER[3]], MASTER[1], ns.SetEnabled)
	switches[1].psHeader = false
	for _, s in ipairs(FOLDED) do
		local c
		if s.header then
			c = W.Text(panel, "caption", GameFontNormalSmall)
			c:SetText(W.Dim() .. L[s.header] .. "|r")
			c.psHeader, c.key = true, false
		else
			c = W.Check(panel, L[s[2]], L[s[3]], s[1])
			c.psHeader = false
		end
		switches[#switches + 1] = c
	end
	switches[1]:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD - (W.Theme() and 0 or 4), -34)
	widgets.settings = W.Button(panel, L.SETTINGS_CLOSED, 110, function()
		settingsOpen = not settingsOpen
		UI.Refresh()
	end, 18)
	widgets.settings:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -(34 + OPT_H + 2))
	W.Tip(widgets.settings, L.SETTINGS, L.SETTINGS_TIP)
	widgets.messages = W.Button(panel, L.MESSAGES .. "…", 96, function() UI.ShowMessages() end, 18)
	widgets.messages:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -(34 + OPT_H + 2))
	W.Tip(widgets.messages, L.MESSAGES, L.MESSAGES_TIP)

	-- Everything below hangs from this point, moved when Settings unfolds.
	widgets.below = CreateFrame("Frame", nil, panel)
	widgets.below:SetSize(1, 1)

	-- Languages: a compact summary; a click opens the picker.
	widgets.langLabel = text("small", GameFontHighlightSmall)
	widgets.langLabel:SetPoint("TOPLEFT", widgets.below, "TOPLEFT", 0, -2)
	widgets.langLabel:SetText(L.LANGS)
	widgets.langValue = text("small", GameFontHighlightSmall)
	widgets.langValue:SetPoint("LEFT", widgets.langLabel, "RIGHT", 8, 0)
	local langHit = CreateFrame("Button", nil, panel)
	langHit:SetPoint("TOPLEFT", widgets.langLabel, "TOPLEFT", 0, 4)
	langHit:SetPoint("BOTTOMRIGHT", widgets.langLabel, "BOTTOMLEFT", WIDTH - 2 * PAD, -4)
	langHit:SetScript("OnClick", UI.ToggleLangPicker)
	W.Tip(langHit, L.LANGS, L.LANGS_TIP)

	-- Find a group / Stop / Options, then Leave the group on its own row.
	widgets.search = W.Button(panel, L.SEARCH, 168, function() ns.Search() UI.Refresh() end)
	widgets.search:SetPoint("TOPLEFT", widgets.below, "TOPLEFT", 0, -30)
	widgets.stop = W.Button(panel, L.STOP, 70, function() ns.Comm.StopSearch() UI.Refresh() end)
	widgets.stop:SetPoint("LEFT", widgets.search, "RIGHT", 6, 0)
	widgets.stop:Hide()
	widgets.options = W.Button(panel, L.OPTIONS_SHORT, 64, function() if ns.OpenOptions then ns.OpenOptions() end end)
	widgets.options:SetPoint("TOPLEFT", widgets.search, "TOPLEFT", WIDTH - 2 * PAD - 64, 0)
	widgets.options:SetShown(UI.hasOptions == true)
	-- Announce in public chat, with the line's language and channel.
	widgets.announce = W.Button(panel, L.ANNOUNCE, 110, function() ns.Announce.Send() UI.Refresh() end)
	widgets.announce:SetPoint("TOPLEFT", widgets.search, "BOTTOMLEFT", 0, -2)
	widgets.announce:SetScript("OnEnter", UI.AnnounceTip)
	widgets.announce:SetScript("OnLeave", function() GameTooltip:Hide() end)
	widgets.annTo = W.Choice(panel, WIDTH - 2 * PAD - 110 - 6, {
		items = UI.AnnounceTargets, get = ns.Announce.Target, set = function(v) ns.Set("announceTo", v) end,
		title = L.ANN_TO, help = L.ANN_TO_TIP,
	})
	widgets.annTo:SetPoint("LEFT", widgets.announce, "RIGHT", 6, 0)

	widgets.leaveGroup = W.Button(panel, L.LEAVE_GROUP, 140, function() ns.Leave.Do() end)
	W.Tip(widgets.leaveGroup, L.LEAVE_GROUP, L.LEAVE_GROUP_TIP)
	widgets.leaveGroup:SetPoint("TOPLEFT", widgets.announce, "BOTTOMLEFT", 0, -2)
	widgets.leaveGroup:Hide()

	-- The search in progress.
	widgets.sessionTitle = text("caption", GameFontNormalSmall, "LEFT")
	widgets.quest = {}
	for i = 1, SESSION_LINES do
		local fs = text("small", GameFontHighlightSmall, "LEFT")
		fs:SetWordWrap(false)
		fs:SetWidth(WIDTH - 2 * PAD - 4)
		widgets.quest[i] = fs
	end
	widgets.none = text("small", GameFontDisableSmall, "LEFT")

	-- Channels.
	widgets.chLabel = text("small", GameFontHighlightSmall, "LEFT")
	widgets.channels = text("small", GameFontHighlightSmall, "LEFT")
	widgets.chHit = CreateFrame("Frame", nil, panel)
	widgets.chHit:EnableMouse(true)
	widgets.chHit:SetScript("OnEnter", channelTip)
	widgets.chHit:SetScript("OnLeave", function() GameTooltip:Hide() end)
	widgets.test = W.Button(panel, L.TEST_SHORT, 56, function() ns.TestChannels() end, 20)

	-- Players found.
	widgets.empty = text("note", GameFontDisableSmall, "LEFT")
	widgets.empty:SetWidth(WIDTH - 2 * PAD - 4)
	for i = 1, ROWS do rows[i] = W.PlayerRow(panel) end

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
	if widgets.options then widgets.options:SetShown(UI.hasOptions) end
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
function UI.SettingsButton() return widgets.settings end
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
