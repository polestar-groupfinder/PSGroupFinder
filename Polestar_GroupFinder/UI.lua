-- Polestar Group Finder: the panel.
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
-- One panel: the on/off switch and its two options, Find a group, Test
-- channels, what each channel did, and the players found, each with
-- Whisper and Invite (only ever on your click). With Polestar it is painted
-- by Polestar's Theme API (Theme.Skin, Theme.Font, Theme.OnChanged) and sits
-- against the guide window's right edge (Polestar.lua hands that window
-- over); without it, it is a plain movable window of its own.

local _, ns = ...
local L = ns.L

local UI = {}
ns.UI = UI

local WIDTH, ROW_H, ROWS = 300, 38, 7
local panel, rows, host
local widgets = {}

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

local function button(parent, text, width, onClick)
	local b
	if Theme() then
		b = CreateFrame("Button", nil, parent)
		b:SetSize(width, 22)
		b.psTextButton = true
		local fs = b:CreateFontString(nil, "OVERLAY")
		font(fs, "label", GameFontNormalSmall)
		fs:SetPoint("CENTER")
		b:SetFontString(fs)
		skin(b, "button")
	else
		b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
		b:SetSize(width, 22)
	end
	b:SetText(text)
	b:SetScript("OnClick", onClick)
	return b
end

local function check(parent, label, tip, key, onToggle)
	local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	c:SetSize(22, 22)
	local fs = c:CreateFontString(nil, "OVERLAY")
	font(fs, "label", GameFontHighlightSmall)
	fs:SetPoint("LEFT", c, "RIGHT", 2, 0)
	fs:SetText(label)
	c:SetScript("OnClick", function(self)
		local on = self:GetChecked() and true or false
		if onToggle then onToggle(on) else ns.Set(key, on) end
	end)
	if tip then
		c:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(label, 1, 1, 1)
			GameTooltip:AddLine(tip, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		c:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end
	c.key = key
	return c
end

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

local function invite(name)
	if C_PartyInfo and C_PartyInfo.InviteUnit then
		C_PartyInfo.InviteUnit(name)
	elseif InviteUnit then
		InviteUnit(name)
	end
end

local function makeRow(i)
	local r = CreateFrame("Frame", nil, panel)
	r:SetSize(WIDTH - 20, ROW_H)
	r:SetPoint("TOPLEFT", widgets.listTop, "BOTTOMLEFT", 0, -(i - 1) * ROW_H - 4)
	r.name = font(r:CreateFontString(nil, "OVERLAY"), "body", GameFontNormal)
	r.name:SetPoint("TOPLEFT", 0, -2)
	r.name:SetPoint("RIGHT", r, "RIGHT", -120, 0)
	r.name:SetJustifyH("LEFT")
	r.info = font(r:CreateFontString(nil, "OVERLAY"), "small", GameFontHighlightSmall)
	r.info:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
	r.info:SetPoint("RIGHT", r, "RIGHT", -120, 0)
	r.info:SetJustifyH("LEFT")
	r.info:SetWordWrap(false)
	r.invite = button(r, L.INVITE, 56, function(self) if self.who then invite(self.who) end end)
	r.invite:SetPoint("RIGHT", r, "RIGHT", 0, 0)
	r.whisper = button(r, L.WHISPER, 60, function(self) if self.who then whisper(self.who) end end)
	r.whisper:SetPoint("RIGHT", r.invite, "LEFT", -4, 0)
	return r
end

local function questLine(e)
	local parts = {}
	for i, id in ipairs(e.quests) do
		if i > 2 then parts[#parts + 1] = "+" .. (#e.quests - 2) break end
		local kind = e.kinds and e.kinds[id]
		parts[#parts + 1] = ns.Quests.Title(id) .. (kind and (" (" .. L["KIND_" .. kind] .. ")") or "")
	end
	local where
	if e.yards then where = string.format(L.NEAR_YD, math.floor(e.yards + 0.5))
	elseif e.sameZone then where = L.SAME_ZONE
	else where = L.OTHER_ZONE end
	return table.concat(parts, ", ") .. " · " .. where
end

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

function UI.Refresh()
	if not (panel and panel:IsShown()) then return end
	local on = ns.Get("enabled") and true or false
	widgets.enable:SetChecked(on)
	widgets.coords:SetChecked(ns.Get("shareCoords") and true or false)
	widgets.reply:SetChecked(ns.Get("autoReply") and true or false)
	widgets.coords:SetEnabled(on)
	widgets.reply:SetEnabled(on)
	local cd = ns.Comm.SearchCooldown()
	widgets.search:SetEnabled(on and cd == 0)
	widgets.search:SetText(cd > 0 and string.format("%s (%d)", L.SEARCH, math.ceil(cd)) or L.SEARCH)
	widgets.test:SetEnabled(on)
	widgets.channels:SetText(on and channelLine() or "")
	local list = on and ns.Matcher.List() or {}
	widgets.empty:SetShown(on and #list == 0)
	rows = rows or {}
	for i = 1, ROWS do
		local e = list[i]
		local r = rows[i] or makeRow(i)
		rows[i] = r
		if e then
			r.name:SetText(string.format("|c%s%s|r  %s%s", classColor(e.class), short(e.name),
				e.level and e.level > 0 and ("|cffaaaaaa" .. e.level .. "|r") or "",
				(e.size or 0) > 0 and (" |cffaaaaaa· " .. L.GROUPED .. "|r") or ""))
			r.info:SetText(questLine(e))
			r.whisper.who, r.invite.who = e.name, e.name
			r:Show()
		else
			r:Hide()
		end
	end
end

function UI.Place()
	if not panel then return end
	panel:ClearAllPoints()
	if host and host:IsShown() then
		panel:SetPoint("TOPLEFT", host, "TOPRIGHT", 6, 0)
		panel:SetMovable(false)
		return
	end
	local pos = ns.Get("panelPos")
	if type(pos) == "table" then
		panel:SetPoint(pos[1] or "CENTER", UIParent, pos[1] or "CENTER", pos[2] or 0, pos[3] or 0)
	else
		panel:SetPoint("CENTER", UIParent, "CENTER", 260, 60)
	end
	panel:SetMovable(true)
end

-- Polestar.lua: the guide window to sit against (nil: stand alone).
function UI.SetHost(frame)
	host = frame
	UI.Place()
end

local function build()
	local useTheme = Theme() ~= nil
	panel = CreateFrame("Frame", "PolestarGroupFinderPanel", UIParent, (not useTheme and BackdropTemplateMixin) and "BackdropTemplate" or nil)
	panel:SetSize(WIDTH, 168 + ROWS * ROW_H)
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
	table.insert(UISpecialFrames, "PolestarGroupFinderPanel")

	local title = font(panel:CreateFontString(nil, "OVERLAY"), "title", GameFontNormalLarge)
	title:SetPoint("TOPLEFT", 12, -10)
	title:SetText(L.TITLE)

	local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)
	close:SetScript("OnClick", function() panel:Hide() end)

	widgets.enable = check(panel, L.ENABLE, L.ENABLE_TIP, "enabled", function(on) ns.SetEnabled(on) end)
	widgets.enable:SetPoint("TOPLEFT", 10, -32)
	widgets.coords = check(panel, L.SHARE_COORDS, nil, "shareCoords")
	widgets.coords:SetPoint("TOPLEFT", widgets.enable, "BOTTOMLEFT", 0, 2)
	widgets.reply = check(panel, L.AUTO_REPLY, nil, "autoReply")
	widgets.reply:SetPoint("TOPLEFT", widgets.coords, "BOTTOMLEFT", 0, 2)

	widgets.search = button(panel, L.SEARCH, 160, function() ns.Search() UI.Refresh() end)
	widgets.search:SetPoint("TOPLEFT", widgets.reply, "BOTTOMLEFT", 2, -6)
	widgets.test = button(panel, L.TEST, 110, function() ns.TestChannels(true) end)
	widgets.test:SetPoint("LEFT", widgets.search, "RIGHT", 6, 0)

	widgets.channels = font(panel:CreateFontString(nil, "OVERLAY"), "small", GameFontHighlightSmall)
	widgets.channels:SetPoint("TOPLEFT", widgets.search, "BOTTOMLEFT", 0, -6)

	widgets.listTop = CreateFrame("Frame", nil, panel)
	widgets.listTop:SetSize(1, 1)
	widgets.listTop:SetPoint("TOPLEFT", widgets.channels, "BOTTOMLEFT", 0, -4)

	widgets.empty = font(panel:CreateFontString(nil, "OVERLAY"), "note", GameFontDisableSmall)
	widgets.empty:SetPoint("TOPLEFT", widgets.listTop, "BOTTOMLEFT", 0, -8)
	widgets.empty:SetWidth(WIDTH - 24)
	widgets.empty:SetJustifyH("LEFT")
	widgets.empty:SetText(L.EMPTY)

	local elapsed = 0
	panel:SetScript("OnUpdate", function(_, dt)
		elapsed = elapsed + dt
		if elapsed >= 1 then elapsed = 0 UI.Refresh() end
	end)
	panel:SetScript("OnShow", UI.Refresh)
	panel:Hide()

	local T = Theme()
	if T and T.OnChanged then pcall(T.OnChanged, function() if panel then UI.Refresh() end end) end
	UI.Place()
end

function UI.Show()
	if not panel then build() end
	UI.Place()
	panel:Show()
	UI.Refresh()
end

function UI.Toggle()
	if panel and panel:IsShown() then panel:Hide() else UI.Show() end
end

function UI.IsShown() return panel and panel:IsShown() or false end

ns.TogglePanel = UI.Toggle
ns.ResetPanel = UI.Place

for _, msg in ipairs({ "PEERS", "CHANNELS", "SETTING", "ENABLED", "SEARCHED" }) do
	ns.On(msg, function() UI.Refresh() end)
end
-- Someone new found within OPEN_AFTER seconds of your own search, while the
-- panel is closed: open it. Never on other players' searches alone.
local OPEN_AFTER = 120
ns.On("PEER_NEW", function()
	if ns.Get("enabled") and not UI.IsShown() and ns.searchedAt and ns.Now() - ns.searchedAt < OPEN_AFTER then UI.Show() end
end)
