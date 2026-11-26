-- Group Finder for Polestar (PSGroupFinder): the "players on this quest" button on Polestar's
-- goal rows.
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
-- Each goal row of the guide window that names a quest gets a small button
-- (under the row's icon, or left of its checkbox on a one-line row) that
-- opens QuestUI for that quest. Alt-click on the row does the same, and the
-- goal's tooltip gets a help line for it. /psgf quest <id> opens it too.
--
-- What this relies on is INTERNAL to Polestar (not in its public API), so
-- every piece runs under pcall and checks that what it needs exists;
-- /psgf hooks says what was found:
--   * Polestar.Theme.GuideParts().rows (the pooled goal rows, documented in
--     Polestar's skin reference) and row.psGoal / row.Icon / row.Check /
--     row.Alt (internal to its guide window).
--   * Polestar.QuestClickTips(questID, lines) and Polestar.QuestRowClick
--     (questID, button): the functions Polestar's goal tooltip and click
--     handler call by name each time. The wrapper runs the original first
--     and only adds to its answer.

local _, ns = ...
local L = ns.L

local Hooks = {}
ns.Hooks = Hooks

local SIZE = 14
local found = { rows = 0 }
local state = { tips = false, click = false, events = false }

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
	if b.Icon and b.Icon.SetVertexColor then b.Icon:SetVertexColor(r, g, bl, 1) end
end

local function make(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(SIZE, SIZE)
	b:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or 1) + 6)
	b:RegisterForClicks("LeftButtonUp")
	b.Icon = b:CreateTexture(nil, "OVERLAY")
	b.Icon:SetAllPoints()
	ns.ApplyIcon(b.Icon, SIZE)
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

---------------------------------------------------------------------------
-- Polestar's goal rows
---------------------------------------------------------------------------

local function guideParts()
	local T = Polestar and Polestar.Theme
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
	local alpha = ns.Get("enabled") and 1 or 0.55
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
				b:SetAlpha(alpha)
				b:Show()
				n = n + 1
			elseif b then
				b:Hide()
			end
		end
	end
	found.rows = n
end

-- The goal's tooltip lines and the click (Alt-click opens the quest panel;
-- every other click stays with Polestar).
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
-- Keeping them in place: on Polestar's messages, and every 0.5 s while the
-- guide window is shown (its rows are pooled and re-laid out often).
---------------------------------------------------------------------------

local function scan()
	if not (state.tips and state.click) then pcall(wrapPolestar) end
	local parts = guideParts()
	if parts and parts.window and parts.window.IsShown and parts.window:IsShown() then pcall(scanRows) end
end
Hooks.Scan = scan

local ticker = CreateFrame("Frame")
local elapsed = 0
ticker:SetScript("OnUpdate", function(_, dt)
	elapsed = elapsed + dt
	if elapsed < 0.5 then return end
	elapsed = 0
	if type(Polestar) ~= "table" then return end
	local ok, err = pcall(scan)
	if not ok then ns.Debug("quest buttons: %s", tostring(err)) end
end)

function Hooks.Init()
	pcall(wrapPolestar)
	local P = Polestar
	if P and type(P.On) == "function" and not state.events then
		state.events = true
		for _, msg in ipairs({ "STEP_CHANGED", "GUIDE_CHANGED", "TABS_CHANGED", "STEP_UPDATED" }) do
			pcall(P.On, msg, function() ns.After(0, scan) end)
		end
	end
	scan()
end
ns.On("LOGIN", Hooks.Init)
ns.On("ENABLED", function() ns.After(0, scan) end)

-- /psgf hooks: what was found, to report when a button does not show.
function Hooks.Report()
	local function yn(v) return v and "yes" or "NO" end
	ns.Print("Polestar: %s; goal tooltip line: %s; Alt-click: %s; goal rows with a button: %d",
		yn(type(Polestar) == "table"), yn(state.tips), yn(state.click), found.rows)
end
