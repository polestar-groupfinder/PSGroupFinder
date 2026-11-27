-- Group Finder for Polestar (PSGroupFinder): the quest panel, the players who have ONE quest,
-- wherever they are.
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
-- Opened by the goal-row button and Alt-click (Hooks.lua) and by
-- /psgf quest <id>. It takes the main panel's place; Back brings the main
-- panel back. "Search for this quest" asks everyone (Comm.SearchQuest);
-- "Announce" says a looking-for-group line for this quest (Announce.lua).

local _, ns = ...
local L = ns.L
local W = ns.Widgets

local QuestUI = {}
ns.QuestUI = QuestUI

local WIDTH, PAD = W.WIDTH, W.PAD
local ROWS = 6
local SEARCHED_FOR = 180 -- seconds a quest search counts as "waiting for answers"

local qpanel, qid
local rows = {}
local qw = {}
local searched = {} -- questID -> time of our last quest search

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

local function playerInfo(e)
	local zone = zoneName(e.map)
	local left = W.PeerProgress(e, qid)
	return W.Soft() .. (zone and (zone .. "  ") or "") .. "|r" .. W.Dim() .. (left ~= "" and left or progressText(e.pct)) .. "|r"
end

function QuestUI.Refresh()
	if not (qpanel and qpanel:IsShown() and qid) then return end
	local on = ns.Get("enabled") and true or false
	qw.quest:SetText("|cffffd100" .. ns.Quests.Title(qid) .. "|r")
	local pct = ns.Quests.Progress(qid)
	qw.mine:SetText(W.Dim() .. (pct and string.format(L.QUEST_MINE, progressText(pct)) or L.QUEST_NOT_MINE) .. "|r")
	-- Their waits drain their accent fill (W.Drain), no number to read.
	local cd = ns.Comm.QuestCooldown()
	qw.search:SetEnabled(on and cd == 0)
	qw.search:SetText(cd > 0 and L.SEARCHING or L.QUEST_SEARCH)
	local y = 100
	local ann = ns.Messages.Enabled("announce")
	qw.announce:SetShown(ann)
	if ann then
		qw.announce.questID = qid
		qw.announce:SetEnabled(on and ns.Announce.Cooldown() == 0)
		y = y + 28
	end
	local found = on and ns.Matcher.QuestList(qid) or {}
	qw.empty:SetShown(#found == 0)
	if #found == 0 then
		local waiting = searched[qid] and ns.Now() - searched[qid] < SEARCHED_FOR
		qw.empty:SetText(not on and L.QUEST_OFF or (cd > 0 and L.QUEST_EMPTY_SEARCHING or (waiting and L.QUEST_EMPTY_WAITING or L.QUEST_EMPTY)))
		qw.empty:ClearAllPoints()
		qw.empty:SetPoint("TOPLEFT", qpanel, "TOPLEFT", PAD + 2, -(y + 2))
		y = y + 38
	end
	y = W.LayoutRows(qpanel, rows, found, y, playerInfo)
	qpanel:SetHeight(y + PAD - 2)
end

local function line(role, fallback, y)
	local fs = W.Text(qpanel, role, fallback)
	fs:SetPoint("TOPLEFT", qpanel, "TOPLEFT", PAD, -y)
	fs:SetWidth(WIDTH - 2 * PAD)
	fs:SetJustifyH("LEFT")
	fs:SetWordWrap(false)
	return fs
end

local function build()
	qpanel = W.Window("PSGroupFinderQuestPanel", { width = WIDTH, height = 200, movable = true, onMoved = ns.UI.SavePosition })
	W.Title(qpanel, L.QUEST_TITLE)
	W.CloseButton(qpanel)
	qw.quest = line("body", GameFontNormal, 34)
	qw.mine = line("small", GameFontHighlightSmall, 52)
	qw.back = W.Button(qpanel, L.QUEST_BACK, 70, function() qpanel:Hide() ns.UI.Show() end)
	qw.back:SetPoint("TOPLEFT", qpanel, "TOPLEFT", PAD, -72)
	qw.search = W.Button(qpanel, L.QUEST_SEARCH, WIDTH - 2 * PAD - 76, function()
		if qid then ns.Comm.SearchQuest(qid) end
		QuestUI.Refresh()
	end)
	qw.search:SetPoint("LEFT", qw.back, "RIGHT", 6, 0)
	W.Drain(qw.search, function() return ns.Comm.QuestCooldown() / ns.Comm.QUEST_GAP end)
	-- Announce under them, the whole width.
	qw.announce = W.Button(qpanel, L.ANNOUNCE_QUEST, WIDTH - 2 * PAD, function()
		if qid then ns.Announce.Send(qid) end
		QuestUI.Refresh()
	end)
	qw.announce:SetPoint("TOPLEFT", qpanel, "TOPLEFT", PAD, -100)
	W.Drain(qw.announce, function() return ns.Announce.Cooldown() / ns.Announce.GAP end)
	qw.announce:SetScript("OnEnter", ns.UI.AnnounceTip)
	qw.announce:SetScript("OnLeave", function() GameTooltip:Hide() end)
	qw.empty = W.Text(qpanel, "note", GameFontDisableSmall)
	qw.empty:SetWidth(WIDTH - 2 * PAD - 4)
	qw.empty:SetJustifyH("LEFT")
	for i = 1, ROWS do rows[i] = W.PlayerRow(qpanel) end
	W.EverySecond(qpanel, QuestUI.Refresh)
	qpanel:SetScript("OnShow", function() ns.UI.Place() QuestUI.Refresh() end)
	qpanel:Hide()
	ns.UI.Dockable(qpanel)
end

-- Opens the list for quest `id`, in the main panel's place. A second click
-- for the same quest closes it; a click for another quest switches to it.
function QuestUI.Open(id)
	id = tonumber(id)
	if not id or id <= 0 then return false end
	if QuestUI.IsShown() and qid == id then
		QuestUI.Close()
		return false
	end
	qid = id
	if not qpanel then build() end
	ns.UI.Hide()
	ns.UI.Place()
	qpanel:Show()
	QuestUI.Refresh()
	return true
end

function QuestUI.Close()
	if qpanel then qpanel:Hide() qpanel.psDockHidden = nil end
end

function QuestUI.Quest() return qid end
function QuestUI.IsShown() return qpanel and qpanel:IsShown() or false end

-- Tests.
function QuestUI.EmptyCaption() return qw.empty and qw.empty:GetText() or nil end
function QuestUI.RowFrames() return rows end
function QuestUI.AnnounceButton() return qw.announce end

ns.On("QUEST_SEARCHED", function(id) searched[id] = ns.Now() end)
for _, msg in ipairs({ "PEERS", "CHANNELS", "SETTING", "ENABLED", "SEARCHED", "SESSION", "LANG", "QUEST_SEARCHED", "ANNOUNCED" }) do
	ns.On(msg, QuestUI.Refresh)
end
