-- Group Finder for Polestar (PSGroupFinder): the small dialogs.
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
--   * "Leave the group?" when the quests a finder group was formed for are
--     done (Leave.lua). Leave.Do (the /p message when asked for, then the
--     game's leave) only ever runs from its Leave button.
--   * The editor of the message said in /p when leaving, opened from the
--     panel's Edit button and from Polestar's page.

local _, ns = ...
local L = ns.L
local W = ns.Widgets
local UI = ns.UI

local PAD = W.PAD
local LEAVE_W, EDIT_W = 320, 330

local lw, ed

local function buildLeave()
	lw = W.Window("PSGroupFinderLeave", { width = LEAVE_W, height = 130, strata = "DIALOG", alpha = 0.95, movable = true })
	lw:SetPoint("TOP", UIParent, "TOP", 0, -170)
	lw.title = W.Text(lw, "title", GameFontNormalLarge)
	lw.title:SetPoint("TOPLEFT", PAD, -10)
	lw.title:SetText(L.LEAVE_TITLE)
	lw.body = W.Text(lw, "body", GameFontHighlight)
	lw.body:SetPoint("TOPLEFT", PAD, -34)
	lw.body:SetWidth(LEAVE_W - 2 * PAD)
	lw.body:SetJustifyH("LEFT")
	lw.body:SetText(L.LEAVE_BODY)
	lw.say = W.Text(lw, "small", GameFontHighlightSmall)
	lw.say:SetPoint("TOPLEFT", PAD, -76)
	lw.say:SetWidth(LEAVE_W - 2 * PAD)
	lw.say:SetJustifyH("LEFT")
	lw.say:SetWordWrap(false)
	lw.yes = W.Button(lw, L.LEAVE_YES, 120, function() lw:Hide() ns.Leave.Do() end, 24)
	lw.yes:SetPoint("BOTTOMLEFT", lw, "BOTTOMLEFT", PAD, PAD)
	lw.stay = W.Button(lw, L.LEAVE_STAY, 120, function() lw:Hide() ns.Leave.Stay() end, 24)
	lw.stay:SetPoint("BOTTOMRIGHT", lw, "BOTTOMRIGHT", -PAD, PAD)
	lw:Hide()
end

function UI.ShowLeave()
	if not lw then buildLeave() end
	local say = ns.Get("leaveMsgOn") and true or false
	lw.say:SetShown(say)
	if say then
		lw.say:SetText(W.Dim() .. string.format(L.LEAVE_WILL_SAY, "\226\128\156" .. ns.Leave.Message() .. "\226\128\157") .. "|r")
	end
	lw:SetHeight(say and 130 or 110)
	lw:Show()
end

function UI.LeaveShown() return lw and lw:IsShown() or false end
-- Tests: the two buttons of the window.
function UI.LeaveButtons() return lw and lw.yes, lw and lw.stay end

local function buildEditor()
	ed = W.Window("PSGroupFinderMessage", { width = EDIT_W, height = 112, strata = "DIALOG", alpha = 0.95 })
	ed:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	local title = W.Text(ed, "title", GameFontNormalLarge)
	title:SetPoint("TOPLEFT", PAD, -10)
	title:SetText(L.LEAVE_DIALOG)
	local useTheme = W.Theme() ~= nil
	local e = CreateFrame("EditBox", nil, ed, (not useTheme) and "InputBoxTemplate" or nil)
	e:SetSize(EDIT_W - 2 * PAD - 8, 22)
	e:SetPoint("TOPLEFT", ed, "TOPLEFT", PAD + 4, -36)
	e:SetAutoFocus(false)
	e:SetMaxLetters(120)
	e:SetFontObject(GameFontHighlight)
	if useTheme then
		e:SetTextInsets(6, 6, 0, 0)
		W.Skin(e, "editbox")
	end
	ed.edit = e
	local function save()
		-- No escape sequences in a chat message; the default text is stored as "unset".
		local text = (e:GetText() or ""):gsub("|", ""):gsub("^%s+", ""):gsub("%s+$", "")
		ns.Set("leaveMsg", (text ~= "" and text ~= L.LEAVE_MSG_DEFAULT) and text or false)
		ed:Hide()
	end
	e:SetScript("OnEnterPressed", save)
	e:SetScript("OnEscapePressed", function() ed:Hide() end)
	ed.save = W.Button(ed, L.LEAVE_SAVE, 96, save, 22)
	ed.save:SetPoint("BOTTOMLEFT", ed, "BOTTOMLEFT", PAD, PAD)
	ed.reset = W.Button(ed, L.LEAVE_RESET, 96, function() e:SetText(L.LEAVE_MSG_DEFAULT) end, 22)
	ed.reset:SetPoint("LEFT", ed.save, "RIGHT", 6, 0)
	ed.cancel = W.Button(ed, L.LEAVE_CANCEL, 96, function() ed:Hide() end, 22)
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
