-- Group Finder for Polestar (PSGroupFinder): the building blocks shared by every window.
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
-- With Polestar, frames are painted by its Theme API (Theme.Skin, Font,
-- Color, Hex, OnChanged); without it, they use the game's own templates.

local _, ns = ...
local L = ns.L

local W = {}
ns.Widgets = W

W.WIDTH, W.PAD = 340, 12 -- the panels' width and inner margin
W.ROW_H = 42             -- a player row
W.BTN_COL = 84           -- width of the Whisper / Invite column

local BACKDROP = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

---------------------------------------------------------------------------
-- Theme
---------------------------------------------------------------------------

function W.Theme()
	local T = Polestar and Polestar.Theme
	if T and T.Skin and T.Font then return T end
	return nil
end

function W.Skin(frame, kind)
	local T = W.Theme()
	if T then pcall(T.Skin, frame, kind) end
	return frame
end

function W.Font(fs, role, fallback)
	local T = W.Theme()
	if not (T and pcall(T.Font, fs, role)) then fs:SetFontObject(fallback or GameFontHighlightSmall) end
	return fs
end

-- A font string on `parent`, painted for `role`.
function W.Text(parent, role, fallback)
	return W.Font(parent:CreateFontString(nil, "OVERLAY"), role, fallback)
end

-- "|cffrrggbb" for a Polestar colour token, else `fallback`.
function W.Hex(token, fallback)
	local T = W.Theme()
	if T and T.Hex then
		local ok, h = pcall(T.Hex, token)
		if ok and type(h) == "string" then return "|c" .. h end
	end
	return "|c" .. fallback
end
function W.Dim() return W.Hex("textMuted", "ff9a9aa6") end
function W.Soft() return W.Hex("textDim", "ffc8c8d0") end

---------------------------------------------------------------------------
-- Controls
---------------------------------------------------------------------------

function W.Button(parent, text, width, onClick, height)
	local b
	height = height or 22
	if W.Theme() then
		b = CreateFrame("Button", nil, parent)
		b:SetSize(width, height)
		b.psTextButton = true
		local fs = W.Text(b, "label", GameFontNormalSmall)
		fs:SetPoint("CENTER")
		b:SetFontString(fs)
		W.Skin(b, "button")
	else
		b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
		b:SetSize(width, height)
	end
	b:SetText(text)
	b:SetScript("OnClick", onClick)
	return b
end

function W.Tip(frame, title, body, anchor)
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
-- covers its own label. A click sets `key`, or calls onToggle(on).
function W.Check(parent, label, help, key, onToggle)
	local c
	if W.Theme() then
		c = CreateFrame("CheckButton", nil, parent)
		c:SetSize(18, 18)
		W.Skin(c, "checkbox")
	else
		c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
		c:SetSize(22, 22)
	end
	local fs = W.Text(c, "label", GameFontHighlightSmall)
	fs:SetPoint("LEFT", c, "RIGHT", 4, 0)
	fs:SetText(label)
	c.label = fs
	c:SetHitRectInsets(0, -(fs:GetStringWidth() + 8), 0, 0)
	c:SetScript("OnClick", function(self)
		local on = self:GetChecked() and true or false
		if onToggle then onToggle(on) else ns.Set(key, on) end
	end)
	if help then W.Tip(c, label, help) end
	c.key = key
	return c
end

-- A window: themed (or the tooltip backdrop), closed by Escape.
-- `opts`: width, height, strata, alpha (backdrop), movable.
function W.Window(name, opts)
	local useTheme = W.Theme() ~= nil
	local f = CreateFrame("Frame", name, UIParent, (not useTheme and BackdropTemplateMixin) and "BackdropTemplate" or nil)
	f:SetSize(opts.width, opts.height)
	f:SetFrameStrata(opts.strata or "MEDIUM")
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	if useTheme then
		W.Skin(f, "window")
	elseif f.SetBackdrop then
		f:SetBackdrop(BACKDROP)
		f:SetBackdropColor(0.05, 0.05, 0.08, opts.alpha or 0.92)
	end
	if opts.movable then
		f:SetMovable(true)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", function(self) if self:IsMovable() then self:StartMoving() end end)
		f:SetScript("OnDragStop", function(self)
			self:StopMovingOrSizing()
			if opts.onMoved then opts.onMoved(self) end
		end)
	end
	table.insert(UISpecialFrames, name)
	return f
end

-- A box inside a window (the language picker).
function W.Box(parent)
	local box = CreateFrame("Frame", nil, parent, (not W.Theme() and BackdropTemplateMixin) and "BackdropTemplate" or nil)
	if W.Theme() then
		W.Skin(box, "panel")
	elseif box.SetBackdrop then
		box:SetBackdrop(BACKDROP)
		box:SetBackdropColor(0.07, 0.08, 0.12, 0.97)
	end
	return box
end

function W.CloseButton(parent, onClick)
	local close
	if W.Theme() then
		close = CreateFrame("Button", nil, parent)
		close:SetSize(18, 18)
		close:SetPoint("TOPRIGHT", -8, -8)
		W.Skin(close, "close")
	else
		close = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", 2, 2)
	end
	close:SetScript("OnClick", onClick or function() parent:Hide() end)
	return close
end

-- Our icon, then `text`, at the top left of a window.
function W.Title(parent, text)
	local icon = parent:CreateTexture(nil, "ARTWORK")
	ns.ApplyIcon(icon, 16)
	icon:SetPoint("TOPLEFT", W.PAD, -10)
	local T = W.Theme()
	if T and T.Color then pcall(T.Color, icon, "icon") end
	local title = W.Text(parent, "title", GameFontNormalLarge)
	title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
	title:SetPoint("TOP", parent, "TOP", 0, -10)
	title:SetText(text)
	return title
end

-- A selector: a button showing the current choice; a click opens a small
-- list under it. `opts`: items() -> { { value, label } }, get(), set(value),
-- title and help (tooltip). b:Refresh() updates the label.
local ARROW = " |TInterface\\ChatFrame\\ChatFrameExpandArrow:12:12|t"

function W.Choice(parent, width, opts)
	local b = W.Button(parent, "", width, nil, 20)
	local list
	local rows = {}
	local function labelOf(value)
		for _, it in ipairs(opts.items()) do
			if it.value == value then return it.label end
		end
		return tostring(value)
	end
	function b:Refresh()
		self:SetText(labelOf(opts.get()) .. ARROW)
	end
	local function open()
		list = list or W.Box(parent)
		list:SetFrameStrata("DIALOG")
		local items = opts.items()
		for i, it in ipairs(items) do
			local row = rows[i] or W.Button(list, "", width - 8, nil, 18)
			rows[i] = row
			row:SetText(it.label)
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", list, "TOPLEFT", 4, -(4 + (i - 1) * 19))
			row:SetScript("OnClick", function()
				opts.set(it.value)
				list:Hide()
				b:Refresh()
			end)
			row:Show()
		end
		for i = #items + 1, #rows do rows[i]:Hide() end
		list:SetSize(width, 8 + #items * 19)
		list:ClearAllPoints()
		list:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -2)
		list:Show()
	end
	b:SetScript("OnClick", function()
		if list and list:IsShown() then list:Hide() else open() end
	end)
	b:SetScript("OnHide", function() if list then list:Hide() end end)
	if opts.title then W.Tip(b, opts.title, (opts.help and (opts.help .. " ") or "") .. L.CHOOSE) end
	-- Tests: the open list and its rows.
	b.List = function() return list, rows end
	b:Refresh()
	return b
end

-- Calls fn about once a second while `frame` is shown.
function W.EverySecond(frame, fn)
	local elapsed = 0
	frame:SetScript("OnUpdate", function(_, dt)
		elapsed = elapsed + dt
		if elapsed >= 1 then elapsed = 0 fn() end
	end)
end

---------------------------------------------------------------------------
-- Players
---------------------------------------------------------------------------

local function classColor(class)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c and c.colorStr then return c.colorStr end
	return "ffffffff"
end

function W.Whisper(name)
	if ChatFrame_SendTell then
		ChatFrame_SendTell(name)
	elseif ChatFrame_OpenChat then
		ChatFrame_OpenChat("/w " .. name .. " ")
	end
end

-- A player already in a group cannot be invited: we ask them to invite us.
function W.CanOnlyAsk(e)
	return (e.size or 0) > 0
end

-- The Invite / Ask click on a player row: invites (or asks to join) and
-- whispers the matching message (Messages.lua), only on this click.
function W.Invite(e)
	local name, quests = e.name, e.quests
	-- Remembered, so that the finder can say hello, then goodbye once these quests are done.
	if ns.Leave and quests then ns.Leave.NoteInvite(name, quests) end
	if W.CanOnlyAsk(e) then
		ns.Messages.Whisper("ask", name, quests)
		return
	end
	if C_PartyInfo and C_PartyInfo.InviteUnit then
		C_PartyInfo.InviteUnit(name)
	elseif InviteUnit then
		InviteUnit(name)
	end
	ns.Messages.Whisper("invite", name, quests)
end

function W.KindTag(kind)
	return kind and ("(" .. L["KIND_" .. kind] .. ") ") or ""
end

function W.Distance(e)
	if e.yards then return string.format(L.NEAR_YD, math.floor(e.yards + 0.5)) end
	if e.sameZone then return L.SAME_ZONE end
	return L.OTHER_ZONE
end

-- What is happening with this player (invited, waiting for their
-- invitation, already in a group), else how far.
local function stateText(e)
	if e.source == "chat" then return W.Hex("accent", "ffffd100") .. L.VIA_CHAT .. "|r" end
	if e.state == "invited" then return W.Hex("success", "ff6bd999") .. L.STATE_INVITED .. "|r" end
	if e.state == "asked" then return W.Hex("warning", "fffabf4d") .. L.STATE_ASKED .. "|r" end
	if (e.size or 0) > 0 then return W.Dim() .. L.GROUPED .. "|r" end
	return W.Dim() .. W.Distance(e) .. "|r"
end

-- A player row: name, level and language on the first line, the state or
-- distance at its right, `info` on the second, Whisper / Invite stacked in
-- the right column. The tooltip lists every shared quest.
function W.PlayerRow(parent)
	local PAD, BTN_COL = W.PAD, W.BTN_COL
	local r = CreateFrame("Frame", nil, parent)
	r:SetSize(W.WIDTH - 2 * PAD, W.ROW_H)
	r:EnableMouse(true)
	r.dist = W.Text(r, "small", GameFontHighlightSmall)
	r.dist:SetPoint("TOPRIGHT", r, "TOPRIGHT", -(BTN_COL + 8), -3)
	r.dist:SetJustifyH("RIGHT")
	r.name = W.Text(r, "body", GameFontNormal)
	r.name:SetPoint("TOPLEFT", 0, -2)
	r.name:SetPoint("RIGHT", r.dist, "LEFT", -6, 0)
	r.name:SetJustifyH("LEFT")
	r.name:SetWordWrap(false)
	r.info = W.Text(r, "small", GameFontHighlightSmall)
	r.info:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
	r.info:SetPoint("RIGHT", r, "RIGHT", -(BTN_COL + 8), 0)
	r.info:SetJustifyH("LEFT")
	r.info:SetWordWrap(false)
	r.whisper = W.Button(r, L.WHISPER, BTN_COL, function() if r.entry then W.Whisper(r.entry.name) end end, 19)
	r.whisper:SetPoint("TOPRIGHT", r, "TOPRIGHT", 0, -1)
	r.invite = W.Button(r, L.INVITE, BTN_COL, function() if r.entry then W.Invite(r.entry) end end, 19)
	r.invite:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 0, 1)
	r:SetScript("OnEnter", function(self)
		local e = self.entry
		if not e then return end
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(ns.ShortName(e.name), 1, 1, 1)
		for _, id in ipairs(e.quests) do
			GameTooltip:AddLine(W.KindTag(e.kinds and e.kinds[id]) .. ns.Quests.Title(id), nil, nil, nil, true)
		end
		if e.said then
			-- Found in public chat: where, and what they said.
			GameTooltip:AddLine(string.format(L.SAID_IN, e.where or "?"), 0.6, 0.6, 0.65)
			GameTooltip:AddLine(e.said, 1, 1, 1, true)
		else
			GameTooltip:AddLine(W.Distance(e), 0.6, 0.6, 0.65)
		end
		GameTooltip:Show()
	end)
	r:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return r
end

-- Shows entry `e` on row `r`, with `info` as the second line.
function W.FillRow(r, e, info)
	r.entry = e
	local lang = e.langTag and e.langTag ~= "?" and ("  " .. W.Dim() .. e.langTag .. "|r") or ""
	local level = e.level and e.level > 0 and (W.Dim() .. e.level .. "|r") or ""
	r.name:SetText(string.format("|c%s%s|r  %s%s", classColor(e.class), ns.ShortName(e.name), level, lang))
	r.dist:SetText(stateText(e))
	r.info:SetText(info)
	r.invite:SetText(W.CanOnlyAsk(e) and L.ASK or L.INVITE)
end

-- Lays out up to #rows entries of `list` from `y` down; returns the new y.
function W.LayoutRows(parent, rows, list, y, info)
	for i = 1, #rows do
		local r, e = rows[i], list[i]
		if e then
			W.FillRow(r, e, info(e))
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", parent, "TOPLEFT", W.PAD, -y)
			r:Show()
			y = y + W.ROW_H
		else
			r.entry = nil
			r:Hide()
		end
	end
	return y
end
