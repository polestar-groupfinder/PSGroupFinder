-- Group Finder for Polestar (PSGroupFinder): the panel.
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
-- One panel, from top to bottom: the switches (the finder, grouping
-- without a click, the header button, sharing the position, answering
-- searches, search languages), Find a group /
-- Stop (/ Options when Polestar's settings have our page), the search in
-- progress (its quests leave it as their objectives are done), the channels
-- with their legend, and the players found, each with Whisper and Invite
-- (only ever on your click). The panel is as tall as what it shows.
-- With Polestar it is painted by Polestar's Theme API (Theme.Skin, Font,
-- Color, OnChanged) and sits against the guide window's right edge (left edge
-- when the right one has no room), following the window when it hides;
-- without it, it is a plain movable window of its own.
--
-- v1.1 adds, in this file: the quest panel (the players who have ONE quest,
-- opened from a quest's button: QuestUI), the window offering to leave a
-- group whose quests are done (UI.ShowLeave) and the dialog that edits the
-- message said before leaving (UI.EditLeaveMessage).

local _, ns = ...
local L = ns.L

local UI = {}
ns.UI = UI

local WIDTH, PAD = 340, 12
local ROW_H, ROWS = 42, 6
local OPT_H = 20          -- pitch of the switches
local NOPT = 7            -- switches
local MSG_H = 22          -- the "message when leaving" line under them
local TOP = 34 + NOPT * OPT_H + MSG_H
local BTN_COL = 84        -- width of the Whisper / Invite column
local SESSION_LINES = 4
local panel, rows, host, qpanel, qrows
local widgets = {}
local checks = {}
local docked = false

---------------------------------------------------------------------------
-- Theme helpers (Polestar's Theme API when it runs, the game's look else)
---------------------------------------------------------------------------

local function Theme()
	local P = Polestar
	local T = P and P.Theme
	if T and T.Skin and T.Font then return T end
	return nil
end

local function skin(frame, kind)
	local T = Theme()
	if T then pcall(T.Skin, frame, kind) end
	return frame
end

local function font(fs, role, fallback)
	local T = Theme()
	if not (T and pcall(T.Font, fs, role)) then fs:SetFontObject(fallback or GameFontHighlightSmall) end
	return fs
end

-- "|cffrrggbb" for a Polestar colour token, else `fallback`.
local function hex(token, fallback)
	local T = Theme()
	if T and T.Hex then
		local ok, h = pcall(T.Hex, token)
		if ok and type(h) == "string" then return "|c" .. h end
	end
	return "|c" .. fallback
end
local function dim() return hex("textMuted", "ff9a9aa6") end
local function soft() return hex("textDim", "ffc8c8d0") end

local function button(parent, text, width, onClick, height)
	local b
	height = height or 22
	if Theme() then
		b = CreateFrame("Button", nil, parent)
		b:SetSize(width, height)
		b.psTextButton = true
		local fs = b:CreateFontString(nil, "OVERLAY")
		font(fs, "label", GameFontNormalSmall)
		fs:SetPoint("CENTER")
		b:SetFontString(fs)
		skin(b, "button")
	else
		b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
		b:SetSize(width, height)
	end
	b:SetText(text)
	b:SetScript("OnClick", onClick)
	return b
end

local function tip(frame, title, body, anchor)
	frame:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, anchor or "ANCHOR_TOP")
		GameTooltip:SetText(title, 1, 1, 1)
		if body then GameTooltip:AddLine(body, nil, nil, nil, true) end
		GameTooltip:Show()
	end)
	frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- A switch: Polestar's own checkbox when it runs, the game's else. The label
-- is part of the hit area, and the tooltip opens above it so it never
-- covers its own label (v0.1's opened beside the box, on top of the text).
local function check(parent, label, help, key, onToggle)
	local c
	if Theme() then
		c = CreateFrame("CheckButton", nil, parent)
		c:SetSize(18, 18)
		skin(c, "checkbox")
	else
		c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
		c:SetSize(22, 22)
	end
	local fs = c:CreateFontString(nil, "OVERLAY")
	font(fs, "label", GameFontHighlightSmall)
	fs:SetPoint("LEFT", c, "RIGHT", 4, 0)
	fs:SetText(label)
	c.label = fs
	c:SetHitRectInsets(0, -(fs:GetStringWidth() + 8), 0, 0)
	c:SetScript("OnClick", function(self)
		local on = self:GetChecked() and true or false
		if onToggle then onToggle(on) else ns.Set(key, on) end
	end)
	if help then tip(c, label, help) end
	c.key = key
	checks[#checks + 1] = c
	return c
end

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------

local function classColor(class)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c and c.colorStr then return c.colorStr end
	return "ffffffff"
end

local function short(name)
	return Ambiguate and Ambiguate(name, "none") or name
end

local function whisper(name)
	if ChatFrame_SendTell then
		ChatFrame_SendTell(name)
	elseif ChatFrame_OpenChat then
		ChatFrame_OpenChat("/w " .. name .. " ")
	end
end

local function invite(name, quests)
	-- Remembered, so that the finder can offer to leave once these quests are done.
	if ns.Leave and quests then ns.Leave.NoteInvite(name, quests) end
	if C_PartyInfo and C_PartyInfo.InviteUnit then
		C_PartyInfo.InviteUnit(name)
	elseif InviteUnit then
		InviteUnit(name)
	end
end

local function kindTag(kind)
	return kind and ("(" .. L["KIND_" .. kind] .. ") ") or ""
end

local function distanceText(e)
	if e.yards then return string.format(L.NEAR_YD, math.floor(e.yards + 0.5)) end
	if e.sameZone then return L.SAME_ZONE end
	return L.OTHER_ZONE
end

---------------------------------------------------------------------------
-- Rows: name and level on the first line, at its right the state (invited,
-- waiting, in a group) or else the distance, the
-- quests on the second, Whisper / Invite stacked in the right column.
---------------------------------------------------------------------------

local function makeRow(_, parent)
	local r = CreateFrame("Frame", nil, parent)
	r:SetSize(WIDTH - 2 * PAD, ROW_H)
	r:EnableMouse(true)
	r.dist = font(r:CreateFontString(nil, "OVERLAY"), "small", GameFontHighlightSmall)
	r.dist:SetPoint("TOPRIGHT", r, "TOPRIGHT", -(BTN_COL + 8), -3)
	r.dist:SetJustifyH("RIGHT")
	r.name = font(r:CreateFontString(nil, "OVERLAY"), "body", GameFontNormal)
	r.name:SetPoint("TOPLEFT", 0, -2)
	r.name:SetPoint("RIGHT", r.dist, "LEFT", -6, 0)
	r.name:SetJustifyH("LEFT")
	r.name:SetWordWrap(false)
	r.info = font(r:CreateFontString(nil, "OVERLAY"), "small", GameFontHighlightSmall)
	r.info:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
	r.info:SetPoint("RIGHT", r, "RIGHT", -(BTN_COL + 8), 0)
	r.info:SetJustifyH("LEFT")
	r.info:SetWordWrap(false)
	r.whisper = button(r, L.WHISPER, BTN_COL, function(self) if self.who then whisper(self.who) end end, 19)
	r.whisper:SetPoint("TOPRIGHT", r, "TOPRIGHT", 0, -1)
	r.invite = button(r, L.INVITE, BTN_COL, function(self) if self.who then invite(self.who, self.quests) end end, 19)
	r.invite:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 0, 1)
	r:SetScript("OnEnter", function(self)
		local e = self.entry
		if not e then return end
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(short(e.name), 1, 1, 1)
		for _, id in ipairs(e.quests) do
			GameTooltip:AddLine(kindTag(e.kinds and e.kinds[id]) .. ns.Quests.Title(id), nil, nil, nil, true)
		end
		GameTooltip:AddLine(distanceText(e), 0.6, 0.6, 0.65)
		GameTooltip:Show()
	end)
	r:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return r
end

-- The right-hand slot of the first line: what is happening with this player
-- (invited, waiting for their invitation, already in a group), else how far.
local function rightText(e)
	if e.state == "invited" then return hex("success", "ff6bd999") .. L.STATE_INVITED .. "|r" end
	if e.state == "asked" then return hex("warning", "fffabf4d") .. L.STATE_ASKED .. "|r" end
	if (e.size or 0) > 0 then return dim() .. L.GROUPED .. "|r" end
	return dim() .. distanceText(e) .. "|r"
end

---------------------------------------------------------------------------
-- Channels: the four names coloured by what each did, with a legend
---------------------------------------------------------------------------

local STATE_COLOR = { ok = "ff40ff40", sent = "ffffd100", fail = "ffff5050", skip = "ff909090" }

local function channelLine()
	local parts = {}
	for _, ct in ipairs(ns.Comm.ORDER) do
		local s = ns.Comm.status[ct]
		local state = s and s.state or "?"
		parts[#parts + 1] = "|c" .. (STATE_COLOR[state] or "ffaaaaaa") .. ct .. "|r"
	end
	return table.concat(parts, "  ")
end

local function channelTip(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText(L.LEGEND_TITLE, 1, 1, 1)
	GameTooltip:AddLine(L.LEGEND_BODY, nil, nil, nil, true)
	local best = ns.Comm.BestChannel()
	if best then GameTooltip:AddLine(string.format(L.LEGEND_BEST, best), 0.25, 1, 0.25) end
	for _, ct in ipairs(ns.Comm.ORDER) do
		local s = ns.Comm.status[ct]
		if s and (s.state == "fail" or s.state == "skip") and s.code then
			GameTooltip:AddLine(ct .. ": " .. tostring(s.code), 1, 0.4, 0.4)
		end
	end
	GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Layout and refresh
---------------------------------------------------------------------------

local function at(frame, y, x, point)
	frame:ClearAllPoints()
	frame:SetPoint(point or "TOPLEFT", panel, point or "TOPLEFT", x or PAD, -y)
end

function UI.Refresh()
	if not (panel and panel:IsShown()) then return end
	local on = ns.Get("enabled") and true or false
	widgets.enable:SetChecked(on)
	widgets.auto:SetChecked(ns.Get("autoGroup") and true or false)
	widgets.header:SetChecked(ns.Get("headerButton") ~= false)
	widgets.coords:SetChecked(ns.Get("shareCoords") and true or false)
	widgets.reply:SetChecked(ns.Get("autoReply") and true or false)
	widgets.leave:SetChecked(ns.Get("leaveOffer") ~= false)
	widgets.leaveMsg:SetChecked(ns.Get("leaveMsgOn") and true or false)
	for _, c in ipairs({ widgets.auto, widgets.header, widgets.coords, widgets.reply, widgets.leave, widgets.leaveMsg }) do
		c:SetEnabled(on or c == widgets.header)
		c:SetAlpha((on or c == widgets.header) and 1 or 0.5)
	end
	widgets.msgText:SetText(dim() .. string.format(L.LEAVE_MSG_LABEL, ns.Leave.Message()) .. "|r")
	widgets.msgText:SetAlpha(ns.Get("leaveMsgOn") and 1 or 0.5)
	if widgets.langValue then
		widgets.langValue:SetText(dim() .. ns.Lang.MineSummary() .. "|r")
	end
	if widgets.langPicker and widgets.langPicker:IsShown() then UI.RefreshLangPicker() end

	-- Buttons.
	local active = ns.Session.Active()
	local cd = ns.Comm.SearchCooldown()
	widgets.search:SetEnabled(on and cd == 0)
	widgets.search:SetText(cd > 0 and string.format("%s (%d)", L.SEARCH, math.ceil(cd)) or (active and L.SEARCH_AGAIN or L.SEARCH))
	widgets.stop:SetShown(active)

	-- Off: only the switches and the buttons; the rest has nothing to say.
	local y = TOP + 22 + 8 + 22 + 10
	local list = ns.Session.List()
	widgets.sessionTitle:SetShown(on)
	widgets.chLabel:SetShown(on)
	widgets.channels:SetShown(on)
	widgets.test:SetShown(on)
	widgets.chHit:SetShown(on)
	for i = 1, SESSION_LINES do widgets.quest[i]:Hide() end
	widgets.none:Hide()
	if on then
		-- The search in progress.
		widgets.sessionTitle:SetText(dim() .. L.SESSION_TITLE .. "|r")
		at(widgets.sessionTitle, y)
		y = y + 14
		for i = 1, SESSION_LINES do
			local fs = widgets.quest[i]
			local q = active and list[i]
			if q then
				if i == SESSION_LINES and #list > SESSION_LINES then
					fs:SetText(dim() .. string.format(L.SESSION_MORE, #list - SESSION_LINES + 1) .. "|r")
				else
					fs:SetText(soft() .. kindTag(q.kind) .. "|r" .. ns.Quests.Title(q.id))
				end
				at(fs, y, PAD + 4)
				fs:Show()
				y = y + 14
			end
		end
		if not active then
			widgets.none:SetText(dim() .. L.SESSION_NONE .. "|r")
			at(widgets.none, y, PAD + 4)
			widgets.none:Show()
			y = y + 14
		end
		y = y + 6

		-- Channels.
		widgets.chLabel:SetText(dim() .. L.CHANNELS .. "|r")
		at(widgets.chLabel, y + 4)
		widgets.channels:SetText(channelLine())
		widgets.channels:ClearAllPoints()
		widgets.channels:SetPoint("LEFT", widgets.chLabel, "RIGHT", 8, 0)
		at(widgets.test, y, WIDTH - PAD - 56, "TOPLEFT")
		widgets.chHit:ClearAllPoints()
		widgets.chHit:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -y)
		widgets.chHit:SetPoint("BOTTOMRIGHT", panel, "TOPLEFT", WIDTH - PAD - 62, -(y + 22))
		y = y + 22 + 6
	end

	-- Players found.
	local found = on and ns.Matcher.List() or {}
	local n = math.min(#found, ROWS)
	rows = rows or {}
	widgets.empty:SetShown(on and n == 0)
	if on and n == 0 then
		widgets.empty:SetText((active and L.EMPTY_SEARCHING or L.EMPTY) or L.EMPTY)
		at(widgets.empty, y + 2, PAD + 2)
		y = y + 38
	end
	for i = 1, ROWS do
		local e = found[i]
		local r = rows[i] or makeRow(i, panel)
		rows[i] = r
		if e and on then
			r.entry = e
			local lang = e.langTag and e.langTag ~= "?" and ("  " .. dim() .. e.langTag .. "|r") or ""
			r.name:SetText(string.format("|c%s%s|r  %s%s", classColor(e.class), short(e.name),
				e.level and e.level > 0 and (dim() .. e.level .. "|r") or "", lang))
			r.dist:SetText(rightText(e))
			local first = e.quests[1]
			local more = #e.quests > 1 and ("  " .. dim() .. "+" .. (#e.quests - 1) .. "|r") or ""
			r.info:SetText(soft() .. kindTag(e.kinds and e.kinds[first]) .. "|r" .. ns.Quests.Title(first) .. more)
			r.whisper.who, r.invite.who, r.invite.quests = e.name, e.name, e.quests
			at(r, y)
			r:Show()
			y = y + ROW_H
		else
			r.entry = nil
			r:Hide()
		end
	end
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
	if panel then placeFrame(panel) end
	if qpanel then placeFrame(qpanel) end
end

-- Polestar.lua: the guide window to sit against (nil: stand alone).
function UI.SetHost(frame)
	host = frame
	UI.Place()
end

-- Polestar.lua: the guide window was shown or hidden. A docked panel is part
-- of the window: it goes with it and comes back with it, instead of jumping
-- to the middle of the screen (v0.1).
function UI.HostShown(shown)
	if shown then
		UI.Place()
	end
	for _, f in ipairs({ panel or false, qpanel or false }) do
		if f then
			if shown then
				if f.psDockHidden then f.psDockHidden = nil f:Show() end
			elseif docked and f:IsShown() then
				f.psDockHidden = true
				f:Hide()
			end
		end
	end
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Language picker (search languages), opened from the compact summary.
---------------------------------------------------------------------------

local function langCheck(parent, label, getter, setter)
	local c = check(parent, label, nil, nil, function(on) setter(on) UI.RefreshLangPicker() UI.Refresh() end)
	c.psGet = getter
	return c
end

function UI.RefreshLangPicker()
	local box = widgets.langPicker
	if not box then return end
	if box.all then box.all:SetChecked(ns.Lang.AcceptsAll()) end
	local locked = ns.Lang.AcceptsAll()
	for _, c in ipairs(box.langs or {}) do
		-- Uniform: memorised ticks stay, every row (on or off) is faded and
		-- not clickable while "All languages" is on.
		c:SetChecked(c.psGet and c.psGet())
		c:SetEnabled(not locked)
		c:SetAlpha(locked and 0.45 or 1)
		if c.EnableMouse then c:EnableMouse(not locked) end
	end
end

function UI.ToggleLangPicker()
	if not panel then return end
	if widgets.langPicker and widgets.langPicker:IsShown() then
		widgets.langPicker:Hide()
		return
	end
	if not widgets.langPicker then
		local box = CreateFrame("Frame", nil, panel)
		box:SetFrameStrata("DIALOG")
		box:SetSize(WIDTH - 16, 24 + 11 * 18 + 16)
		box:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -(TOP + 22))
		local T = Theme()
		if T then pcall(T.Skin, box, "panel")
		elseif box.SetBackdrop then
			box:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
				tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
			box:SetBackdropColor(0.07, 0.08, 0.12, 0.97)
		end
		local title = font(box:CreateFontString(nil, "OVERLAY"), "caption", GameFontNormalSmall)
		title:SetPoint("TOPLEFT", 8, -8)
		title:SetText(L.LANGS)
		box.langs = {}
		box.all = langCheck(box, L.LANG_ALL, function() return ns.Lang.AcceptsAll() end, function(on) ns.Lang.SetAcceptAll(on) end)
		box.all:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -24)
		for i, row in ipairs(ns.Lang.ALL) do
			local code = row.code
			local y = -(24 + i * 18)
			local c = langCheck(box, ns.Lang.Name(code), function() return ns.Lang.HasSearch(code) end, function(on) ns.Lang.SetSearch(code, on) end)
			c:SetPoint("TOPLEFT", box, "TOPLEFT", 6, y)
			box.langs[#box.langs + 1] = c
		end
		widgets.langPicker = box
	end
	widgets.langPicker:Show()
	UI.RefreshLangPicker()
end

local function build()
	local useTheme = Theme() ~= nil
	panel = CreateFrame("Frame", "PSGroupFinderPanel", UIParent, (not useTheme and BackdropTemplateMixin) and "BackdropTemplate" or nil)
	panel:SetSize(WIDTH, 300)
	panel:SetFrameStrata("MEDIUM")
	panel:SetClampedToScreen(true)
	panel:EnableMouse(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", function(self) if self:IsMovable() then self:StartMoving() end end)
	panel:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, _, x, y = self:GetPoint(1)
		ns.Set("panelPos", { point, x, y })
	end)
	if useTheme then
		skin(panel, "window")
	elseif panel.SetBackdrop then
		panel:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
		panel:SetBackdropColor(0.05, 0.05, 0.08, 0.92)
	end
	table.insert(UISpecialFrames, "PSGroupFinderPanel")

	local title = font(panel:CreateFontString(nil, "OVERLAY"), "title", GameFontNormalLarge)
	title:SetPoint("TOPLEFT", PAD, -10)
	title:SetText(L.TITLE)

	local close
	if useTheme then
		close = CreateFrame("Button", nil, panel)
		close:SetSize(18, 18)
		close:SetPoint("TOPRIGHT", -8, -8)
		skin(close, "close")
	else
		close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", 2, 2)
	end
	close:SetScript("OnClick", function() panel:Hide() end)

	-- The switches, 20 units apart, none touching the next.
	widgets.enable = check(panel, L.ENABLE, L.ENABLE_TIP, "enabled", function(on) ns.SetEnabled(on) end)
	widgets.auto = check(panel, L.AUTO_GROUP, L.AUTO_GROUP_TIP, "autoGroup")
	widgets.header = check(panel, L.HEADER_BUTTON, L.HEADER_BUTTON_TIP, "headerButton")
	widgets.coords = check(panel, L.SHARE_COORDS, nil, "shareCoords")
	widgets.reply = check(panel, L.AUTO_REPLY, nil, "autoReply")
	widgets.leave = check(panel, L.LEAVE_OFFER, L.LEAVE_OFFER_TIP, "leaveOffer")
	widgets.leaveMsg = check(panel, L.LEAVE_MSG, L.LEAVE_MSG_TIP, "leaveMsgOn")
	for i, c in ipairs({ widgets.enable, widgets.auto, widgets.header, widgets.coords, widgets.reply, widgets.leave, widgets.leaveMsg }) do
		c:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD - (useTheme and 0 or 4), -(34 + (i - 1) * OPT_H))
	end
	-- The message said when you click Leave: shown, edited in a small dialog.
	widgets.msgEdit = button(panel, L.LEAVE_MSG_EDIT, 70, function() UI.EditLeaveMessage() end, 18)
	widgets.msgEdit:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -(34 + NOPT * OPT_H))
	widgets.msgText = font(panel:CreateFontString(nil, "OVERLAY"), "small", GameFontHighlightSmall)
	widgets.msgText:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + 22, -(34 + NOPT * OPT_H + 3))
	widgets.msgText:SetPoint("RIGHT", widgets.msgEdit, "LEFT", -6, 0)
	widgets.msgText:SetJustifyH("LEFT")
	widgets.msgText:SetWordWrap(false)

	-- Languages: a compact summary; a click opens the picker.
	local ly = TOP + 2
	widgets.langLabel = font(panel:CreateFontString(nil, "OVERLAY"), "small", GameFontHighlightSmall)
	widgets.langLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -ly)
	widgets.langLabel:SetText(L.LANGS)
	widgets.langValue = font(panel:CreateFontString(nil, "OVERLAY"), "small", GameFontHighlightSmall)
	widgets.langValue:SetPoint("LEFT", widgets.langLabel, "RIGHT", 8, 0)
	widgets.langHit = CreateFrame("Button", nil, panel)
	widgets.langHit:SetPoint("TOPLEFT", widgets.langLabel, "TOPLEFT", 0, 4)
	widgets.langHit:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", -PAD, -(ly + 16))
	widgets.langHit:SetScript("OnClick", function() UI.ToggleLangPicker() end)
	widgets.langHit:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(L.LANGS, 1, 1, 1)
		GameTooltip:AddLine(L.LANGS_TIP, nil, nil, nil, true)
		GameTooltip:Show()
	end)
	widgets.langHit:SetScript("OnLeave", function() GameTooltip:Hide() end)

	local by = TOP + 22 + 8
	widgets.search = button(panel, L.SEARCH, 168, function() ns.Search() UI.Refresh() end)
	widgets.search:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -by)
	widgets.stop = button(panel, L.STOP, 70, function()
		ns.Comm.Stop()
		ns.Session.Stop("manual")
		ns.Print(L.SEARCH_STOPPED)
		UI.Refresh()
	end)
	widgets.stop:SetPoint("LEFT", widgets.search, "RIGHT", 6, 0)
	widgets.stop:Hide()
	-- Opens Polestar's settings on our page (Polestar.lua sets ns.OpenOptions).
	widgets.options = button(panel, L.OPTIONS_SHORT, 64, function() if ns.OpenOptions then ns.OpenOptions() end end)
	widgets.options:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -by)
	widgets.options:Hide()

	widgets.sessionTitle = font(panel:CreateFontString(nil, "OVERLAY"), "caption", GameFontNormalSmall)
	widgets.sessionTitle:SetJustifyH("LEFT")
	widgets.quest = {}
	for i = 1, SESSION_LINES do
		local fs = font(panel:CreateFontString(nil, "OVERLAY"), "small", GameFontHighlightSmall)
		fs:SetJustifyH("LEFT")
		fs:SetWordWrap(false)
		fs:SetWidth(WIDTH - 2 * PAD - 4)
		widgets.quest[i] = fs
	end
	widgets.none = font(panel:CreateFontString(nil, "OVERLAY"), "small", GameFontDisableSmall)
	widgets.none:SetJustifyH("LEFT")

	widgets.chLabel = font(panel:CreateFontString(nil, "OVERLAY"), "small", GameFontHighlightSmall)
	widgets.chLabel:SetJustifyH("LEFT")
	widgets.channels = font(panel:CreateFontString(nil, "OVERLAY"), "small", GameFontHighlightSmall)
	widgets.channels:SetJustifyH("LEFT")
	widgets.chHit = CreateFrame("Frame", nil, panel)
	widgets.chHit:EnableMouse(true)
	widgets.chHit:SetScript("OnEnter", channelTip)
	widgets.chHit:SetScript("OnLeave", function() GameTooltip:Hide() end)
	widgets.test = button(panel, L.TEST_SHORT, 56, function() ns.TestChannels(true) end, 20)

	widgets.empty = font(panel:CreateFontString(nil, "OVERLAY"), "note", GameFontDisableSmall)
	widgets.empty:SetWidth(WIDTH - 2 * PAD - 4)
	widgets.empty:SetJustifyH("LEFT")
	widgets.empty:SetText(L.EMPTY)

	local elapsed = 0
	panel:SetScript("OnUpdate", function(_, dt)
		elapsed = elapsed + dt
		if elapsed >= 1 then elapsed = 0 UI.Refresh() end
	end)
	panel:SetScript("OnShow", function() UI.Place() UI.Refresh() end)
	panel:Hide()

	local T = Theme()
	if T and T.OnChanged then pcall(T.OnChanged, function() if panel then UI.Refresh() end end) end
	UI.Place()
end

-- Polestar.lua: whether Polestar's settings have our page (shows Options).
function UI.SetHasOptions(has)
	UI.hasOptions = has and true or false
	if widgets.options then widgets.options:SetShown(UI.hasOptions) end
end

function UI.Show()
	if qpanel then qpanel:Hide() qpanel.psDockHidden = nil end
	if not panel then build() end
	widgets.options:SetShown(UI.hasOptions == true)
	UI.Place()
	panel:Show()
	UI.Refresh()
end

function UI.Toggle()
	if qpanel and qpanel:IsShown() then qpanel:Hide() return end -- the quest panel is in the main panel's place
	if panel and panel:IsShown() then panel:Hide() else UI.Show() end
end

function UI.IsShown() return panel and panel:IsShown() or false end

function UI.EmptyCaption()
	return widgets.empty and widgets.empty.GetText and widgets.empty:GetText() or nil
end

---------------------------------------------------------------------------
-- The quest panel (v1.1): the players who have ONE quest, wherever they
-- are. Opened by the quest buttons (Hooks.lua), Alt-click on a Polestar
-- goal and /psgf quest <id>. It takes the main panel's place; Back brings
-- the main panel back. "Search for this quest" asks everyone (Comm.SearchQuest).
---------------------------------------------------------------------------

local QuestUI = {}
ns.QuestUI = QuestUI
local qid
local qw = {}
local QROWS = 6
local qSearched = {} -- questID -> time of our last quest search

local function zoneName(map)
	if not (map and C_Map and C_Map.GetMapInfo) then return nil end
	local ok, info = pcall(C_Map.GetMapInfo, map)
	local name = ok and info and ns.Readable(info.name)
	return type(name) == "string" and name ~= "" and name or nil
end

local function progressText(pct)
	if pct == nil then return L.PROGRESS_NONE end
	if pct >= 100 then return L.PROGRESS_READY end
	return string.format(L.PROGRESS_PCT, pct)
end

function QuestUI.Quest() return qid end
function QuestUI.IsShown() return qpanel and qpanel:IsShown() or false end

function QuestUI.EmptyCaption()
	return qw.empty and qw.empty.GetText and qw.empty:GetText() or nil
end

function QuestUI.Refresh()
	if not (qpanel and qpanel:IsShown() and qid) then return end
	local on = ns.Get("enabled") and true or false
	qw.quest:SetText("|cffffd100" .. ns.Quests.Title(qid) .. "|r")
	local pct = ns.Quests.Progress(qid)
	qw.mine:SetText(dim() .. (pct and string.format(L.QUEST_MINE, progressText(pct)) or L.QUEST_NOT_MINE) .. "|r")
	local cd = ns.Comm.QuestCooldown()
	qw.search:SetEnabled(on and cd == 0)
	qw.search:SetText(cd > 0 and string.format("%s (%d)", L.QUEST_SEARCH, math.ceil(cd)) or L.QUEST_SEARCH)

	local y = 102
	local found = on and ns.Matcher.QuestList(qid) or {}
	local n = math.min(#found, QROWS)
	qw.empty:SetShown(n == 0)
	if n == 0 then
		local searched = qSearched[qid] and ns.Now() - qSearched[qid] < 180
		qw.empty:SetText(not on and L.QUEST_OFF or (searched and L.QUEST_EMPTY_SEARCHING or L.QUEST_EMPTY))
		qw.empty:ClearAllPoints()
		qw.empty:SetPoint("TOPLEFT", qpanel, "TOPLEFT", PAD + 2, -(y + 2))
		y = y + 38
	end
	qrows = qrows or {}
	for i = 1, QROWS do
		local e = found[i]
		local r = qrows[i] or makeRow(i, qpanel)
		qrows[i] = r
		if e then
			r.entry = e
			local lang = e.langTag and e.langTag ~= "?" and ("  " .. dim() .. e.langTag .. "|r") or ""
			r.name:SetText(string.format("|c%s%s|r  %s%s", classColor(e.class), short(e.name),
				e.level and e.level > 0 and (dim() .. e.level .. "|r") or "", lang))
			r.dist:SetText(rightText(e))
			local zone = zoneName(e.map)
			r.info:SetText(soft() .. (zone and (zone .. "  ") or "") .. "|r" .. dim() .. progressText(e.pct) .. "|r")
			r.whisper.who, r.invite.who, r.invite.quests = e.name, e.name, e.quests
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", qpanel, "TOPLEFT", PAD, -y)
			r:Show()
			y = y + ROW_H
		else
			r.entry = nil
			r:Hide()
		end
	end
	qpanel:SetHeight(y + PAD - 2)
end

local function buildQuest()
	local useTheme = Theme() ~= nil
	qpanel = CreateFrame("Frame", "PSGroupFinderQuestPanel", UIParent, (not useTheme and BackdropTemplateMixin) and "BackdropTemplate" or nil)
	qpanel:SetSize(WIDTH, 200)
	qpanel:SetFrameStrata("MEDIUM")
	qpanel:SetClampedToScreen(true)
	qpanel:EnableMouse(true)
	qpanel:RegisterForDrag("LeftButton")
	qpanel:SetScript("OnDragStart", function(self) if self:IsMovable() then self:StartMoving() end end)
	qpanel:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, _, x, y = self:GetPoint(1)
		ns.Set("panelPos", { point, x, y })
	end)
	if useTheme then
		skin(qpanel, "window")
	elseif qpanel.SetBackdrop then
		qpanel:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
		qpanel:SetBackdropColor(0.05, 0.05, 0.08, 0.92)
	end
	table.insert(UISpecialFrames, "PSGroupFinderQuestPanel")

	qw.title = font(qpanel:CreateFontString(nil, "OVERLAY"), "title", GameFontNormalLarge)
	qw.title:SetPoint("TOPLEFT", PAD, -10)
	qw.title:SetText(L.QUEST_TITLE)

	local close
	if useTheme then
		close = CreateFrame("Button", nil, qpanel)
		close:SetSize(18, 18)
		close:SetPoint("TOPRIGHT", -8, -8)
		skin(close, "close")
	else
		close = CreateFrame("Button", nil, qpanel, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", 2, 2)
	end
	close:SetScript("OnClick", function() qpanel:Hide() end)

	qw.quest = font(qpanel:CreateFontString(nil, "OVERLAY"), "body", GameFontNormal)
	qw.quest:SetPoint("TOPLEFT", qpanel, "TOPLEFT", PAD, -34)
	qw.quest:SetWidth(WIDTH - 2 * PAD)
	qw.quest:SetJustifyH("LEFT")
	qw.quest:SetWordWrap(false)
	qw.mine = font(qpanel:CreateFontString(nil, "OVERLAY"), "small", GameFontHighlightSmall)
	qw.mine:SetPoint("TOPLEFT", qpanel, "TOPLEFT", PAD, -52)
	qw.mine:SetWidth(WIDTH - 2 * PAD)
	qw.mine:SetJustifyH("LEFT")
	qw.mine:SetWordWrap(false)

	qw.back = button(qpanel, L.QUEST_BACK, 70, function() qpanel:Hide() UI.Show() end)
	qw.back:SetPoint("TOPLEFT", qpanel, "TOPLEFT", PAD, -72)
	qw.search = button(qpanel, L.QUEST_SEARCH, 190, function()
		if qid and ns.Comm.SearchQuest(qid) then qSearched[qid] = ns.Now() end
		QuestUI.Refresh()
	end)
	qw.search:SetPoint("LEFT", qw.back, "RIGHT", 6, 0)

	qw.empty = font(qpanel:CreateFontString(nil, "OVERLAY"), "note", GameFontDisableSmall)
	qw.empty:SetWidth(WIDTH - 2 * PAD - 4)
	qw.empty:SetJustifyH("LEFT")

	local elapsed = 0
	qpanel:SetScript("OnUpdate", function(_, dt)
		elapsed = elapsed + dt
		if elapsed >= 1 then elapsed = 0 QuestUI.Refresh() end
	end)
	qpanel:SetScript("OnShow", function() UI.Place() QuestUI.Refresh() end)
	qpanel:Hide()
	UI.Place()
end

-- Opens the list for quest `id` (a number), in the main panel's place.
function QuestUI.Open(id)
	id = tonumber(id)
	if not id or id <= 0 then return false end
	qid = id
	if not qpanel then buildQuest() end
	if panel then panel:Hide() panel.psDockHidden = nil end
	UI.Place()
	qpanel:Show()
	QuestUI.Refresh()
	return true
end

function QuestUI.Close()
	if qpanel then qpanel:Hide() end
end

ns.On("QUEST_SEARCHED", function(id) qSearched[id] = ns.Now() end)

---------------------------------------------------------------------------
-- "Leave the group?" (v1.1): a small window, two buttons. Both buttons are
-- clicks; Leave.Do (the /p message when asked for, then LeaveParty) only
-- ever runs from the Leave button.
---------------------------------------------------------------------------

local lw

local function buildLeave()
	local useTheme = Theme() ~= nil
	lw = CreateFrame("Frame", "PSGroupFinderLeave", UIParent, (not useTheme and BackdropTemplateMixin) and "BackdropTemplate" or nil)
	lw:SetSize(320, 130)
	lw:SetFrameStrata("DIALOG")
	lw:SetClampedToScreen(true)
	lw:EnableMouse(true)
	lw:SetMovable(true)
	lw:RegisterForDrag("LeftButton")
	lw:SetScript("OnDragStart", function(self) self:StartMoving() end)
	lw:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	lw:SetPoint("TOP", UIParent, "TOP", 0, -170)
	if useTheme then
		skin(lw, "window")
	elseif lw.SetBackdrop then
		lw:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
		lw:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
	end
	table.insert(UISpecialFrames, "PSGroupFinderLeave")
	lw.title = font(lw:CreateFontString(nil, "OVERLAY"), "title", GameFontNormalLarge)
	lw.title:SetPoint("TOPLEFT", PAD, -10)
	lw.title:SetText(L.LEAVE_TITLE)
	lw.body = font(lw:CreateFontString(nil, "OVERLAY"), "body", GameFontHighlight)
	lw.body:SetPoint("TOPLEFT", PAD, -34)
	lw.body:SetWidth(320 - 2 * PAD)
	lw.body:SetJustifyH("LEFT")
	lw.body:SetText(L.LEAVE_BODY)
	lw.say = font(lw:CreateFontString(nil, "OVERLAY"), "small", GameFontHighlightSmall)
	lw.say:SetPoint("TOPLEFT", PAD, -76)
	lw.say:SetWidth(320 - 2 * PAD)
	lw.say:SetJustifyH("LEFT")
	lw.say:SetWordWrap(false)
	lw.yes = button(lw, L.LEAVE_YES, 120, function()
		lw:Hide()
		ns.Leave.Do()
	end, 24)
	lw.yes:SetPoint("BOTTOMLEFT", lw, "BOTTOMLEFT", PAD, PAD)
	lw.stay = button(lw, L.LEAVE_STAY, 120, function()
		lw:Hide()
		ns.Leave.Stay()
	end, 24)
	lw.stay:SetPoint("BOTTOMRIGHT", lw, "BOTTOMRIGHT", -PAD, PAD)
	lw:Hide()
end

function UI.ShowLeave()
	if not lw then buildLeave() end
	local say = ns.Get("leaveMsgOn") and true or false
	lw.say:SetShown(say)
	if say then lw.say:SetText(dim() .. string.format(L.LEAVE_WILL_SAY, "\226\128\156" .. ns.Leave.Message() .. "\226\128\157") .. "|r") end
	lw:SetHeight(say and 130 or 110)
	lw:Show()
end

function UI.LeaveShown() return lw and lw:IsShown() or false end
-- Tests: the two buttons of the window.
function UI.LeaveButtons() return lw and lw.yes, lw and lw.stay end
-- Tests: the player rows of the main panel and of the quest panel.
function UI.RowFrames() return rows or {} end
function QuestUI.RowFrames() return qrows or {} end

---------------------------------------------------------------------------
-- The message said in /p when you click Leave: edited here (a small
-- dialog), from the panel's Edit button and from Polestar's page.
---------------------------------------------------------------------------

local ed

local function buildEditor()
	local useTheme = Theme() ~= nil
	ed = CreateFrame("Frame", "PSGroupFinderMessage", UIParent, (not useTheme and BackdropTemplateMixin) and "BackdropTemplate" or nil)
	ed:SetSize(330, 112)
	ed:SetFrameStrata("DIALOG")
	ed:SetClampedToScreen(true)
	ed:EnableMouse(true)
	ed:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	if useTheme then
		skin(ed, "window")
	elseif ed.SetBackdrop then
		ed:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
		ed:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
	end
	table.insert(UISpecialFrames, "PSGroupFinderMessage")
	local title = font(ed:CreateFontString(nil, "OVERLAY"), "title", GameFontNormalLarge)
	title:SetPoint("TOPLEFT", PAD, -10)
	title:SetText(L.LEAVE_DIALOG)
	local e = CreateFrame("EditBox", nil, ed, (not useTheme) and "InputBoxTemplate" or nil)
	e:SetSize(330 - 2 * PAD - 8, 22)
	e:SetPoint("TOPLEFT", ed, "TOPLEFT", PAD + 4, -36)
	e:SetAutoFocus(false)
	e:SetMaxLetters(120)
	e:SetFontObject(GameFontHighlight)
	if useTheme then
		e:SetTextInsets(6, 6, 0, 0)
		skin(e, "editbox")
	end
	ed.edit = e
	local function save()
		local text = (e:GetText() or ""):gsub("|", ""):gsub("^%s+", ""):gsub("%s+$", "")
		if text == "" or text == L.LEAVE_MSG_DEFAULT then ns.Set("leaveMsg", false) else ns.Set("leaveMsg", text) end
		ed:Hide()
	end
	e:SetScript("OnEnterPressed", save)
	e:SetScript("OnEscapePressed", function() ed:Hide() end)
	ed.save = button(ed, L.LEAVE_SAVE, 96, save, 22)
	ed.save:SetPoint("BOTTOMLEFT", ed, "BOTTOMLEFT", PAD, PAD)
	ed.reset = button(ed, L.LEAVE_RESET, 96, function() e:SetText(L.LEAVE_MSG_DEFAULT) end, 22)
	ed.reset:SetPoint("LEFT", ed.save, "RIGHT", 6, 0)
	ed.cancel = button(ed, L.LEAVE_CANCEL, 96, function() ed:Hide() end, 22)
	ed.cancel:SetPoint("BOTTOMRIGHT", ed, "BOTTOMRIGHT", -PAD, PAD)
	ed:Hide()
end

function UI.EditLeaveMessage()
	if not ed then buildEditor() end
	ed.edit:SetText(ns.Leave.Message())
	ed:Show()
	if ed.edit.SetFocus then ed.edit:SetFocus() end
end

function UI.EditorShown() return ed and ed:IsShown() or false end

ns.TogglePanel = UI.Toggle
ns.ResetPanel = UI.Place

for _, msg in ipairs({ "PEERS", "CHANNELS", "SETTING", "ENABLED", "SEARCHED", "SESSION", "LANG", "QUEST_SEARCHED" }) do
	ns.On(msg, function() UI.Refresh() ns.QuestUI.Refresh() end)
end
-- Someone new found within OPEN_AFTER seconds of your own search, while the
-- panel is closed: open it. Never on other players' searches alone.
local OPEN_AFTER = 120
ns.On("PEER_NEW", function()
	if ns.Get("enabled") and not UI.IsShown() and ns.searchedAt and ns.Now() - ns.searchedAt < OPEN_AFTER then UI.Show() end
end)
