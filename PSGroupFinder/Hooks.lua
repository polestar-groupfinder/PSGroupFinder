-- Group Finder for Polestar (PSGroupFinder): the quest buttons (v1.1).
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
-- A small "players on this quest" button in three places, each opening
-- QuestUI for that quest's id:
--   1. Polestar's guide window: on each goal row that names a quest, under
--      the row's icon (left of its sub-line); on a one-line row, left of its
--      checkbox. Also Alt-click on the row, and an Alt-click help line in
--      the goal's tooltip.
--   2. The game's quest log (Map & Quest Log on Forever, the classic log
--      else): after the tracking checkbox of each quest, any zone.
--   3. /psgf quest <id>.
--
-- What this relies on, from most to least stable. EVERYTHING BELOW IS
-- INTERNAL to Polestar or to the game's UI, none of it is in Polestar's
-- public API, so each piece runs under pcall, checks that what it needs
-- exists, and the others keep working when one is missing (/psgf hooks says
-- what was found):
--   * Polestar.Theme.GuideParts().rows (documented in Polestar's skin
--     reference: "the goal rows, pooled") and row.psGoal / row.Icon /
--     row.Sub / row.Check / row.Alt (internal to its guide window).
--   * Polestar.QuestClickTips(questID, lines) and Polestar.QuestRowClick
--     (questID, button): the functions Polestar's goal tooltip and click
--     handler call by name each time, so wrapping them (the original runs
--     first, unchanged) adds our help line and the Alt-click.
--   * The game's quest log: QuestScrollFrame.titleFramePool (the pool of
--     title buttons: .questID, .Checkbox), else the children of the log's
--     scroll contents that carry a questID, else the classic QuestLogTitleN
--     buttons. Our button is a child of the title button (it hides and
--     moves with it, whatever the pool does), re-placed after the log's own
--     update functions (hooksecurefunc: never replaced, nothing of the
--     game's secure code is touched, and the game's own openers such as
--     QuestMapFrame_OpenToQuestDetails are never called) and by a 0.5 s
--     check while a log is on screen, which also covers recycled rows.

local _, ns = ...
local L = ns.L

local Hooks = {}
ns.Hooks = Hooks

local SIZE = 14
local found = { rows = 0, log = 0, logKind = "none" }
local state = { tips = false, click = false, events = false, logHooks = {} }

---------------------------------------------------------------------------
-- The button
---------------------------------------------------------------------------

local function themeColor(token, r, g, b)
	local T = Polestar and Polestar.Theme
	if T and T.Color then
		local ok, cr, cg, cb = pcall(T.Color, token)
		if ok and type(cr) == "number" then return cr, cg, cb end
	end
	return r, g, b
end

local function paint(b, hover)
	local r, g, bl
	if hover then r, g, bl = themeColor("accent", 1, 0.82, 0)
	else r, g, bl = themeColor("icon", 0.85, 0.88, 0.95) end
	for _, t in ipairs(b.psGlyph) do t:SetVertexColor(r, g, bl, 1) end
end

local function whiteTexture(t)
	local T = Polestar and Polestar.Theme
	if T and T.Media then
		local ok, path = pcall(T.Media, "white")
		if ok and path then t:SetTexture(path) return end
	end
	t:SetColorTexture(1, 1, 1, 1)
end

local function make(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(SIZE, SIZE)
	b:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or 1) + 6)
	b:RegisterForClicks("LeftButtonUp")
	b.psgfQuestButton = true
	local function tex(w, h, x, y)
		local t = b:CreateTexture(nil, "OVERLAY")
		whiteTexture(t)
		t:SetSize(w, h)
		t:SetPoint("CENTER", b, "CENTER", x, y)
		return t
	end
	-- Two people, as in Polestar's header icon, at 14 units.
	b.psGlyph = { tex(3, 3, -2.5, 3), tex(4, 5, -2.5, -2), tex(3, 3, 2.5, 3), tex(4, 5, 2.5, -2) }
	paint(b, false)
	b:SetScript("OnClick", function(self)
		if self.questID and ns.QuestUI then ns.QuestUI.Open(self.questID) end
	end)
	b:SetScript("OnEnter", function(self)
		paint(self, true)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(L.QUEST_BTN, 1, 1, 1)
		GameTooltip:AddLine(L.QUEST_BTN_TIP, nil, nil, nil, true)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function(self)
		paint(self, false)
		GameTooltip:Hide()
	end)
	return b
end

local function dimmed(b)
	b:SetAlpha(ns.Get("enabled") and 1 or 0.55)
end

---------------------------------------------------------------------------
-- 1. Polestar's goal rows
---------------------------------------------------------------------------

local function guideParts()
	local P = Polestar
	local T = P and P.Theme
	if not (T and T.GuideParts) then return nil end
	local ok, parts = pcall(T.GuideParts)
	return ok and type(parts) == "table" and parts or nil
end

local function place(b, row)
	b:ClearAllPoints()
	local tall = row.GetHeight and (row:GetHeight() or 0) >= 36
	if tall and row.Icon then
		-- Under the icon, left of the sub-line.
		b:SetPoint("TOP", row.Icon, "BOTTOM", 0, -1)
	else
		local anchor = (row.Alt and row.Alt.IsShown and row.Alt:IsShown() and row.Alt) or row.Check
		if anchor then
			b:SetPoint("RIGHT", anchor, "LEFT", -4, 0)
		else
			b:SetPoint("RIGHT", row, "RIGHT", -6, 0)
		end
	end
end

local function scanRows()
	local parts = guideParts()
	local rows = parts and parts.rows
	if type(rows) ~= "table" then found.rows = 0 return end
	local n = 0
	for _, row in ipairs(rows) do
		if type(row) == "table" and row.IsShown then
			local goal = row.psGoal
			local quest = type(goal) == "table" and tonumber(goal.quest) or nil
			local b = row.psgfBtn
			if quest and row:IsShown() and goal.status ~= "done" and goal.status ~= "na" then
				if not b then
					b = make(row)
					row.psgfBtn = b
				end
				b.questID = quest
				place(b, row)
				dimmed(b)
				b:Show()
				n = n + 1
			elseif b then
				b:Hide()
			end
		end
	end
	found.rows = n
end

-- The goal's tooltip lines (Polestar.QuestClickTips adds its click help) and
-- the click (Polestar.QuestRowClick: middle / shift). The original runs
-- first and its answer stands; we only add.
local function wrapPolestar()
	local P = Polestar
	if type(P) ~= "table" then return end
	if type(P.QuestClickTips) == "function" and not state.tips then
		local orig = P.QuestClickTips
		P.QuestClickTips = function(questID, lines)
			local out = orig(questID, lines)
			pcall(function()
				local t = type(out) == "table" and out or lines
				if type(questID) == "number" and type(t) == "table" then
					local r, g, b = themeColor("textDim", 0.8, 0.8, 0.85)
					t[#t + 1] = { L.QUEST_ALT_HELP, r, g, b }
				end
			end)
			return out
		end
		state.tips = true
	end
	if type(P.QuestRowClick) == "function" and not state.click then
		local orig = P.QuestRowClick
		P.QuestRowClick = function(questID, button)
			if type(questID) == "number" and button ~= "RightButton" and button ~= "MiddleButton"
				and IsAltKeyDown and IsAltKeyDown() and ns.QuestUI then
				ns.QuestUI.Open(questID)
				return true
			end
			return orig(questID, button)
		end
		state.click = true
	end
end

---------------------------------------------------------------------------
-- 2. The game's quest log
---------------------------------------------------------------------------

local function questOf(button)
	local id = tonumber(button.questID) or (type(button.info) == "table" and tonumber(button.info.questID)) or nil
	if id and id > 0 then return id end
	return nil
end

-- { { host, questID, check } } of the quest titles on screen, and the way found.
local function logTitles()
	local out = {}
	local function add(button, id)
		if id and button and button.IsShown and button:IsShown() then
			out[#out + 1] = { host = button, questID = id, check = button.Checkbox or button.Check or button.TrackCheck }
		end
	end
	local qsf = _G.QuestScrollFrame
	local pool = qsf and qsf.titleFramePool
	if pool and pool.EnumerateActive then
		local ok = pcall(function()
			for button in pool:EnumerateActive() do add(button, questOf(button)) end
		end)
		if ok and #out > 0 then return out, "pool" end
		out = {}
	end
	-- Another build of the same log: look for title buttons in its scroll contents.
	local contents = (qsf and qsf.Contents)
		or (_G.QuestMapFrame and _G.QuestMapFrame.QuestsFrame and _G.QuestMapFrame.QuestsFrame.ScrollFrame
			and _G.QuestMapFrame.QuestsFrame.ScrollFrame.Contents)
	if contents and contents.GetChildren then
		local function walk(frame, depth)
			for i = 1, (frame.GetNumChildren and frame:GetNumChildren() or 0) do
				local child = select(i, frame:GetChildren())
				if child and not child.psgfQuestButton then
					local id = questOf(child)
					if id then add(child, id) elseif depth < 3 then walk(child, depth + 1) end
				end
			end
		end
		pcall(walk, contents, 1)
		if #out > 0 then return out, "contents" end
	end
	-- The classic log: QuestLogTitle1..N, the button's id is the log index.
	if _G.QuestLogTitle1 then
		for i = 1, 40 do
			local button = _G["QuestLogTitle" .. i]
			if not button then break end
			if button:IsShown() then
				local index = button.GetID and button:GetID()
				local id
				if index and index > 0 then
					if C_QuestLog and C_QuestLog.GetQuestIDForLogIndex then
						local ok, r = pcall(C_QuestLog.GetQuestIDForLogIndex, index)
						id = ok and r or nil
					elseif GetQuestLogTitle then
						local ok, _, _, _, isHeader, _, _, _, qid = pcall(GetQuestLogTitle, index)
						id = ok and not isHeader and qid or nil
					end
				end
				if id and id > 0 then add(button, id) end
			end
		end
		if #out > 0 then return out, "classic" end
	end
	return out, "none"
end

local function placeInLog(b, entry)
	b:ClearAllPoints()
	local host, check = entry.host, entry.check
	if check and check.IsShown then
		-- After the checkbox when the title button has room to its right,
		-- else just before it.
		local hr, cr = host.GetRight and host:GetRight(), check.GetRight and check:GetRight()
		if hr and cr and hr - cr >= SIZE + 4 then
			b:SetPoint("LEFT", check, "RIGHT", 3, 0)
		else
			b:SetPoint("RIGHT", check, "LEFT", -3, 0)
		end
	else
		b:SetPoint("RIGHT", host, "RIGHT", -4, 0)
	end
end

local function scanLog()
	local list, kind = logTitles()
	found.log, found.logKind = #list, kind
	local live = {}
	for _, entry in ipairs(list) do
		local host = entry.host
		local b = host.psgfLogBtn
		if not b then
			b = make(host)
			host.psgfLogBtn = b
		end
		b.questID = entry.questID
		placeInLog(b, entry)
		dimmed(b)
		b:Show()
		live[b] = true
	end
	-- Title buttons that went back to the pool or now show a header: nothing to hide
	-- here (we are their child), but a recycled one with no quest must not keep ours.
	for _, regionName in ipairs({ "QuestScrollFrame" }) do
		local qsf = _G[regionName]
		local pool = qsf and qsf.titleFramePool
		if pool and pool.EnumerateActive then
			pcall(function()
				for button in pool:EnumerateActive() do
					if button.psgfLogBtn and not live[button.psgfLogBtn] then button.psgfLogBtn:Hide() end
				end
			end)
		end
	end
end

local function logShown()
	for _, name in ipairs({ "QuestMapFrame", "QuestScrollFrame", "QuestLogFrame" }) do
		local f = _G[name]
		if f and f.IsVisible and f:IsVisible() then return true end
	end
	return false
end

-- hooksecurefunc on the log's own update functions, once each, as they appear.
local function hookLog()
	if not hooksecurefunc then return end
	for _, name in ipairs({ "QuestLogQuests_Update", "QuestMapFrame_UpdateAll", "QuestLog_Update", "QuestLogFrame_Update" }) do
		if not state.logHooks[name] and type(_G[name]) == "function" then
			local ok = pcall(hooksecurefunc, name, function()
				pcall(scanLog)
				-- The log lays its rows out on the next frame.
				ns.After(0, function() pcall(scanLog) end)
			end)
			if ok then state.logHooks[name] = true end
		end
	end
	local qmf = _G.QuestMapFrame
	if qmf and not state.logHooks.QuestMapFrame and qmf.HookScript then
		if pcall(qmf.HookScript, qmf, "OnShow", function() ns.After(0, function() pcall(scanLog) end) end) then
			state.logHooks.QuestMapFrame = true
		end
	end
end

---------------------------------------------------------------------------
-- Keeping them in place
---------------------------------------------------------------------------

local function scanAll()
	if not (state.tips and state.click) then pcall(wrapPolestar) end
	local parts = guideParts()
	if parts and parts.window and parts.window.IsShown and parts.window:IsShown() then pcall(scanRows) end
	hookLog()
	if logShown() then pcall(scanLog) end
end
Hooks.Scan = scanAll

local ticker = CreateFrame("Frame")
local elapsed = 0
ticker:SetScript("OnUpdate", function(_, dt)
	elapsed = elapsed + dt
	if elapsed < 0.5 then return end
	elapsed = 0
	local ok, err = pcall(scanAll)
	if not ok then ns.Debug("quest buttons: %s", tostring(err)) end
end)

function Hooks.Init()
	pcall(wrapPolestar)
	local P = Polestar
	if P and type(P.On) == "function" and not state.events then
		state.events = true
		for _, msg in ipairs({ "STEP_CHANGED", "GUIDE_CHANGED", "TABS_CHANGED", "STEP_UPDATED" }) do
			pcall(P.On, msg, function() ns.After(0, scanAll) end)
		end
	end
	scanAll()
end
ns.On("LOGIN", function() Hooks.Init() end)
ns.On("ENABLED", function() ns.After(0, scanAll) end)

-- /psgf hooks: what was found, to report when a button does not show.
function Hooks.Report()
	local function yn(v) return v and "yes" or "NO" end
	ns.Print("Polestar: %s; goal tooltip line: %s; Alt-click: %s; goal rows with a button: %d",
		yn(type(Polestar) == "table"), yn(state.tips), yn(state.click), found.rows)
	local names = {}
	for name in pairs(state.logHooks) do names[#names + 1] = name end
	table.sort(names)
	ns.Print("Quest log: QuestMapFrame %s, QuestScrollFrame %s, QuestLogFrame %s; buttons: %d (found by: %s); hooks: %s",
		yn(_G.QuestMapFrame), yn(_G.QuestScrollFrame), yn(_G.QuestLogFrame), found.log, found.logKind,
		#names > 0 and table.concat(names, ", ") or "none")
end
