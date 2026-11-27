-- Group Finder for Polestar (PSGroupFinder): the Messages window, where the texts the finder
-- can say for you are edited and previewed.
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
-- One block per message (Messages.lua): its name and when it is said, its
-- switch (On), the text ({quests} and {progress}, explained in the text box's tooltip), and a
-- preview with your current quests, live while you type. Empty: never sent.
-- Default: back to the English default text.
-- Opened from the panel's Messages button and from Polestar's page.

local _, ns = ...
local L = ns.L
local W = ns.Widgets
local UI = ns.UI

local WIDTH, PAD = 420, 12
local BLOCK_H = 78

local win
local blocks = {}

-- The quests a preview is written for: those of the finder group, else of
-- the search, else the relevant ones.
local function preview(kind)
	if not ns.Messages.On(kind) then return W.Dim() .. L.MSG_OFF .. "|r" end
	return W.Soft() .. ns.Messages.Preview(ns.Messages.Template(kind)) .. "|r"
end

function UI.RefreshMessages()
	if not (win and win:IsShown()) then return end
	for _, b in ipairs(blocks) do
		if not b.edit:HasFocus() then b.edit:SetText(ns.Messages.Template(b.kind)) end
		b.preview:SetText(preview(b.kind))
		b.on:SetChecked(ns.Messages.Enabled(b.kind))
		b.edit:SetAlpha(ns.Messages.Enabled(b.kind) and 1 or 0.5)
	end
end

local function makeBlock(kind, i)
	local b = { kind = kind }
	local top = 34 + (i - 1) * BLOCK_H
	b.label = W.Text(win, "label", GameFontNormalSmall)
	b.label:SetPoint("TOPLEFT", win, "TOPLEFT", PAD, -top)
	b.label:SetText(L["MSG_" .. kind:upper()])
	b.hint = W.Text(win, "small", GameFontDisableSmall)
	b.hint:SetPoint("LEFT", b.label, "RIGHT", 6, 0)
	b.hint:SetText(L["MSG_" .. kind:upper() .. "_WHEN"])
	b.on = W.Check(win, L.MSG_ON, L["MSG_" .. kind:upper() .. "_ON_TIP"], nil, function(on)
		ns.Messages.SetEnabled(kind, on)
		UI.RefreshMessages()
	end)
	b.on:SetPoint("TOPRIGHT", win, "TOPRIGHT", -PAD - 30, -(top - 2))
	b.hint:SetPoint("RIGHT", b.on, "LEFT", -8, 0)
	b.hint:SetJustifyH("LEFT")
	b.hint:SetWordWrap(false)
	local useTheme = W.Theme() ~= nil
	local e = CreateFrame("EditBox", nil, win, (not useTheme) and "InputBoxTemplate" or nil)
	e:SetSize(WIDTH - 2 * PAD - 76, 20)
	e:SetPoint("TOPLEFT", win, "TOPLEFT", PAD + 4, -(top + 16))
	e:SetAutoFocus(false)
	e:SetMaxLetters(200)
	e:SetFontObject(GameFontHighlightSmall)
	if useTheme then
		e:SetTextInsets(6, 6, 0, 0)
		W.Skin(e, "editbox")
	end
	local function save()
		ns.Messages.Save(kind, e:GetText())
		e:ClearFocus()
		UI.RefreshMessages()
	end
	e:SetScript("OnEnterPressed", save)
	e:SetScript("OnEditFocusLost", function() ns.Messages.Save(kind, e:GetText()) UI.RefreshMessages() end)
	e:SetScript("OnEscapePressed", function() e:ClearFocus() UI.RefreshMessages() end)
	e:SetScript("OnTextChanged", function(_, user)
		if not user then return end
		local text = ns.Messages.Preview(e:GetText())
		b.preview:SetText(text == "" and (W.Dim() .. L.MSG_OFF .. "|r") or (W.Soft() .. text .. "|r"))
	end)
	W.Tip(e, L.MSG_VARS_TITLE, L.MSG_VARS)
	b.edit = e
	b.reset = W.Button(win, L.MSG_RESET, 64, function()
		ns.Messages.Save(kind, ns.Messages.Default(kind))
		e:SetText(ns.Messages.Template(kind))
		UI.RefreshMessages()
	end, 20)
	b.reset:SetPoint("LEFT", e, "RIGHT", 6, 0)
	b.preview = W.Text(win, "small", GameFontHighlightSmall)
	b.preview:SetPoint("TOPLEFT", win, "TOPLEFT", PAD + 4, -(top + 40))
	b.preview:SetWidth(WIDTH - 2 * PAD - 4)
	b.preview:SetJustifyH("LEFT")
	return b
end

local function build()
	win = W.Window("PSGroupFinderMessages", { width = WIDTH, height = 34 + #ns.Messages.ORDER * BLOCK_H + 34,
		strata = "DIALOG", alpha = 0.95, movable = true })
	win:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
	W.Title(win, L.MESSAGES)
	W.CloseButton(win)
	for i, kind in ipairs(ns.Messages.ORDER) do blocks[i] = makeBlock(kind, i) end
	local help = W.Text(win, "small", GameFontDisableSmall)
	help:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", PAD, PAD)
	help:SetWidth(WIDTH - 2 * PAD)
	help:SetJustifyH("LEFT")
	help:SetText(L.MSG_VARS)
	win:SetScript("OnShow", UI.RefreshMessages)
	win:Hide()
end

-- Opens the window (a second call closes it); `kind` puts the cursor in
-- that message's text.
function UI.ShowMessages(kind)
	if not win then build() end
	if win:IsShown() and not kind then win:Hide() return end
	win:Show()
	UI.RefreshMessages()
	for _, b in ipairs(blocks) do
		if b.kind == kind and b.edit.SetFocus then b.edit:SetFocus() end
	end
end

-- Tests.
function UI.MessagesShown() return win and win:IsShown() or false end
function UI.MessageBlocks() return blocks end

ns.On("SETTING", UI.RefreshMessages)
