-- Group Finder for Polestar (PSGroupFinder): the party box, a small floating window for a group
-- formed through the finder.
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
-- Like a quest tracker: the group's quests with your progress and the
-- objectives left. Two moments (Leave.lua fires them):
--   * hello, when the group forms: Say hello (or its key binding) says the
--     hello message (Messages.lua, with the quest links and your progress)
--     in the party, for HELLO_TIME seconds; then the box goes and the chance
--     is gone. Nothing is ever said without the click or the key.
--   * goodbye, when the group's quests are all done: Say goodbye (the
--     goodbye message, then leave the group) for GOODBYE_TIME seconds; then
--     the box goes and you stay. Stay closes it at once.
-- Both have a key binding. The option `partyBox` turns the box off; an empty
-- hello message skips the hello moment.

local _, ns = ...
local L = ns.L
local W = ns.Widgets

local PartyBox = {}
ns.PartyBox = PartyBox

local WIDTH, PAD = 260, 10
local HELLO_TIME = 5
local GOODBYE_TIME = 30
local HELLO_AGAIN = 60     -- seconds before another hello may be offered
local MAX_QUESTS, MAX_OBJECTIVES = 3, 3

local box, mode, remaining
local lastHello = -math.huge
local lines = {}

local function line(i)
	local fs = lines[i]
	if not fs then
		fs = W.Text(box, "small", GameFontHighlightSmall)
		fs:SetJustifyH("LEFT")
		fs:SetWidth(WIDTH - 2 * PAD)
		fs:SetWordWrap(false)
		lines[i] = fs
	end
	return fs
end

-- The group's quests, each with its progress and the objectives left.
local function questLines()
	local out = {}
	local log = ns.Quests.Log()
	for i, id in ipairs(ns.Leave.Quests()) do
		if i > MAX_QUESTS then break end
		local pct = ns.Quests.Progress(id)
		local state = pct and (pct >= 100 and L.PROGRESS_DONE_SHORT or (pct .. "%")) or ""
		out[#out + 1] = "|cffffd100" .. ns.Quests.Title(id) .. "|r  " .. W.Dim() .. state .. "|r"
		local n = 0
		for _, o in ipairs(log[id] and log[id].objectives or {}) do
			if not o.done and o.text and n < MAX_OBJECTIVES then
				n = n + 1
				out[#out + 1] = "   " .. W.Soft() .. ns.Messages.ObjectiveText(o) .. "|r"
			end
		end
	end
	return out
end

function PartyBox.Refresh()
	if not (box and box:IsShown()) then return end
	local hello = mode == "hello"
	box.title:SetText(hello and L.BOX_HELLO_TITLE or L.BOX_GOODBYE_TITLE)
	local y = 32
	local qs = questLines()
	for i, text in ipairs(qs) do
		local fs = line(i)
		fs:SetText(text)
		fs:ClearAllPoints()
		fs:SetPoint("TOPLEFT", box, "TOPLEFT", PAD, -y)
		fs:Show()
		y = y + 14
	end
	for i = #qs + 1, #lines do lines[i]:Hide() end
	-- What will be said, then the buttons.
	local kind = hello and "hello" or "goodbye"
	local said = ns.Messages.On(kind) and ns.Messages.Expand(kind, ns.Leave.Quests()) or L.MSG_OFF
	box.preview:SetText(W.Dim() .. "\226\128\156" .. said .. "\226\128\157|r")
	box.preview:ClearAllPoints()
	box.preview:SetPoint("TOPLEFT", box, "TOPLEFT", PAD, -(y + 4))
	y = y + 4 + math.max(14, box.preview:GetStringHeight() or 14) + 8
	local secs = math.max(0, math.ceil(remaining or 0))
	box.main:SetText(string.format("%s (%d)", hello and L.BOX_SAY_HELLO or L.BOX_SAY_GOODBYE, secs))
	box.other:SetText(hello and L.BOX_CANCEL or L.BOX_STAY)
	box.main:ClearAllPoints()
	box.main:SetPoint("TOPLEFT", box, "TOPLEFT", PAD, -y)
	box:SetHeight(y + 22 + PAD)
end

local function close()
	mode, remaining = nil, nil
	if box then box:Hide() end
end

local function build()
	local pos = ns.Get("partyBoxPos")
	box = W.Window("PSGroupFinderPartyBox", { width = WIDTH, height = 120, strata = "MEDIUM", movable = true,
		onMoved = function(f)
			local point, _, _, x, y = f:GetPoint(1)
			ns.Set("partyBoxPos", { point, x, y })
		end })
	if type(pos) == "table" then
		box:SetPoint(pos[1] or "TOP", UIParent, pos[1] or "TOP", pos[2] or 0, pos[3] or 0)
	else
		box:SetPoint("TOP", UIParent, "TOP", 0, -140)
	end
	box.title = W.Title(box, L.BOX_HELLO_TITLE)
	W.CloseButton(box, function() PartyBox.Other() end)
	box.preview = W.Text(box, "small", GameFontHighlightSmall)
	box.preview:SetJustifyH("LEFT")
	box.preview:SetWidth(WIDTH - 2 * PAD)
	box.main = W.Button(box, L.BOX_SAY_HELLO, 160, function() PartyBox.Main() end, 22)
	box.other = W.Button(box, L.BOX_CANCEL, WIDTH - 2 * PAD - 166, function() PartyBox.Other() end, 22)
	box.other:SetPoint("LEFT", box.main, "RIGHT", 6, 0)
	local tick = 0
	box:SetScript("OnUpdate", function(_, dt)
		if not remaining then return end
		remaining = remaining - dt
		tick = tick + dt
		if remaining <= 0 then
			PartyBox.Other()
		elseif tick >= 0.25 then
			tick = 0
			PartyBox.Refresh()
		end
	end)
	box:Hide()
end

local function show(m, seconds)
	if not box then build() end
	mode, remaining = m, seconds
	box:Show()
	PartyBox.Refresh()
end

function PartyBox.ShowHello()
	if not (ns.Get("enabled") and ns.Get("partyBox") and ns.Messages.On("hello")) then return end
	if ns.Now() - lastHello < HELLO_AGAIN then return end
	lastHello = ns.Now()
	show("hello", HELLO_TIME)
end

function PartyBox.ShowGoodbye()
	if not (ns.Get("enabled") and ns.Get("partyBox")) then return end
	show("goodbye", GOODBYE_TIME)
end

-- Say hello now / say goodbye and leave.
function PartyBox.Main()
	local m = mode
	close()
	if m == "hello" then
		ns.Messages.SayParty("hello", ns.Leave.Quests())
	elseif m == "goodbye" then
		ns.Leave.Do()
	end
end

-- Cancel the hello / stay in the group.
function PartyBox.Other()
	local m = mode
	close()
	if m == "goodbye" then ns.Leave.Stay() end
end

function PartyBox.Mode() return box and box:IsShown() and mode or nil end
function PartyBox.Remaining() return remaining end
-- Tests: the frame, to drive its countdown.
function PartyBox.Frame() return box end

-- Key bindings. Say hello works only while the box offers it.
function PSGroupFinder_Hello()
	if PartyBox.Mode() == "hello" then PartyBox.Main() end
end

function PSGroupFinder_Goodbye()
	if PartyBox.Mode() then close() end
	if IsInGroup and IsInGroup() then ns.Leave.Do() end
end

-- The roster settles a moment after the join: then say hello.
ns.On("GROUP_FORMED", function() ns.After(1, PartyBox.ShowHello) end)
ns.On("GROUP_DONE", PartyBox.ShowGoodbye)
ns.RegisterEvent("GROUP_ROSTER_UPDATE", function()
	if PartyBox.Mode() and not (IsInGroup and IsInGroup()) then close() end
end)
ns.RegisterEvent("QUEST_LOG_UPDATE", function() PartyBox.Refresh() end)
ns.On("ENABLED", function(on) if not on then close() end end)
ns.On("SETTING", function(key) if key == "partyBox" and not ns.Get("partyBox") then close() end end)
