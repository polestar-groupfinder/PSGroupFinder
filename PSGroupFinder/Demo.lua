-- Group Finder for Polestar (PSGroupFinder): a demo mode for trying the whole flow alone in
-- game. TEMPORARY: removed before the port to Polestar.
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
-- /psgf demo turns it on for this session (a /reload turns it off). While it
-- is on, NOTHING leaves your client: every addon message, whisper, party
-- line, announce, invite and leave is printed in the chat instead, as
-- "[demo] -> ...". Three made-up players answer through the real receiving
-- code (their messages are built as theirs and handed to our CHAT_MSG_ADDON,
-- PARTY_INVITE_REQUEST and GROUP_ROSTER_UPDATE handlers), and react to what
-- you send:
--   your search (Find a group)      they answer, whispered
--   your quest search               two of them say they have the quest
--   Invite on a player              they join your pretend group: hello box
--   Ask / auto-group's request      they invite you, then you join
--   Leave the group                 the pretend group is gone
-- The players: Aelyra (solo, auto-group on), Brannok (in a group of 2,
-- auto-group on: Ask instead of Invite), Tibbs (solo, farther, first quest
-- only, auto-group off).

local _, ns = ...

local Demo = {}
ns.Demo = Demo

local FAKES = {
	{ name = "Aelyra", sid = "fffff1", class = "MAGE", size = 0, auto = true, dx = 0.015, dy = 0.01, lvl = 0 },
	{ name = "Brannok", sid = "000001", class = "WARRIOR", size = 2, auto = true, dx = -0.03, dy = 0.02, lvl = 1 },
	{ name = "Tibbs", sid = "8a8a8a", class = "PRIEST", size = 0, auto = false, dx = 0.09, dy = -0.07, lvl = -1, firstOnly = true },
}

local active = false
local members = {}  -- name key -> name: the pretend group
local counts = {}   -- fake name -> questID -> { { have, need }, ... }
local distance      -- yards Nearby reads while set
local leader = false -- you lead the pretend group (you invited), or not (you were invited)

local HELP = {
	"|cff66ccff/psgf demo|r on or off. While on, nothing is sent: it is printed. Then:",
	"  |cffffd100search|r   your search (same as Find a group); the 3 players answer",
	"  |cffffd100players|r  the 3 players search for your quests (they show as asking)",
	"  |cffffd100progress|r the players found move on in their objectives",
	"  |cffffd100stop|r     Tibbs ends their search (leaves your list)",
	"  |cffffd100invite|r   Aelyra invites you, you join (you do not lead): hello box",
	"  |cffffd100hello|r    you invite Aelyra (you lead): hello box at once",
	"  |cffffd100done|r     the group's quests count as done: the box offers to leave",
	"  |cffffd100near|r     Polestar's arrow pretends you are 50 m from the objective",
	"  |cffffd100reset|r    clears the players and the pretend group",
	"Or click as usual: Invite, Ask, Search for this quest, Announce, Leave the group, /psgf test.",
}

local function note(fmt, ...)
	ns.Print("|cff66ccff[demo]|r " .. fmt, ...)
end
Demo.Note = note

function Demo.Active() return active end
function Demo.Distance() return distance end
function Demo.IsMember(name)
	return active and type(name) == "string" and members[ns.NameKey(name)] ~= nil
end
function Demo.Members()
	local n = 0
	for _ in pairs(members) do n = n + 1 end
	return n
end
function Demo.InGroup() return Demo.Members() > 0 end
function Demo.IsLeader() return leader end

local function fake(name)
	if type(name) ~= "string" then return nil end
	local k = ns.NameKey(name)
	for _, f in ipairs(FAKES) do
		if f.name:lower() == k then return f end
	end
end

local function me()
	return (UnitName and UnitName("player")) or "You"
end

---------------------------------------------------------------------------
-- The players' messages, in the real format (Protocol.lua)
---------------------------------------------------------------------------

-- The quests to talk about: those of your search, else your relevant ones.
local function myQuests(f)
	local list = ns.Session.Active() and ns.Session.List() or ns.Quests.Relevant()
	local out = {}
	for _, q in ipairs(list) do
		out[#out + 1] = { id = q.id, kind = q.kind or ns.Quests.Kind(q.id) or "k" }
		if f and f.firstOnly then break end
	end
	return out
end

-- Their progress on quest `id`, behind yours or ahead, kept per player.
local function countsOf(f, id)
	counts[f.name] = counts[f.name] or {}
	local c = counts[f.name][id]
	if not c then
		c = {}
		local q = ns.Quests.Log()[id]
		for i, o in ipairs(q and q.objectives or {}) do
			if i > 4 then break end
			local need = tonumber(o.need) or 1
			if need < 1 then need = 1 end
			c[i] = { math.random(0, need - 1), need }
		end
		counts[f.name][id] = c
	end
	local parts = {}
	for i, hn in ipairs(c) do parts[i] = hn[1] .. "/" .. hn[2] end
	return #parts > 0 and ("@" .. table.concat(parts, ";")) or ""
end

local function header(f, kind)
	local map, x, y = ns.Quests.Position()
	local function at(v, d)
		if not v then return "" end
		return tostring(math.floor(math.max(0, math.min(1, v + d)) * 1000 + 0.5))
	end
	local xs, ys = at(x, f.dx), at(y, f.dy)
	if xs == "" or ys == "" then xs, ys = "", "" end
	local level = math.max(1, ((UnitLevel and UnitLevel("player")) or 10) + f.lvl)
	local flags = (f.auto and "g" or "") .. (ns.Protocol.Flags():match("[AH]") or "")
	return table.concat({ kind, f.sid, tostring(map or 0), xs, ys, tostring(level), f.class,
		tostring(f.size), flags, ns.Lang.Encode() }, "|") .. "|"
end

local function searchText(f)
	local entries = {}
	for i, q in ipairs(myQuests(f)) do entries[i] = q.id .. ":" .. q.kind .. countsOf(f, q.id) end
	return header(f, "S") .. table.concat(entries, ",")
end

local function replyText(f)
	local entries = {}
	for i, q in ipairs(myQuests(f)) do entries[i] = q.id .. countsOf(f, q.id) end
	return header(f, "R") .. table.concat(entries, ",")
end

local function questReplyText(f, id)
	return header(f, "A") .. id .. ":" .. math.random(15, 85) .. countsOf(f, id)
end

-- A message from player `f` (or from you: the channel test's echo) reaches us.
local function deliver(text, chatType, sender)
	if not active then return end
	ns.Dispatch("CHAT_MSG_ADDON", ns.Protocol.PREFIX, text, chatType, sender)
end

local function hasQuests()
	if #myQuests() > 0 then return true end
	note("You need an open quest with an objective (kill, loot, named or group) in your log.")
	return false
end

---------------------------------------------------------------------------
-- The pretend group
---------------------------------------------------------------------------

-- The pretend group breaks up, silently.
local function disband()
	if not next(members) then return end
	wipe(members)
	leader = false
	ns.Dispatch("GROUP_ROSTER_UPDATE")
end

-- `asLeader`: you invited them (you lead), else they invited you.
local function join(f, asLeader)
	if not active or members[ns.NameKey(f.name)] then return end
	if not next(members) then leader = asLeader and true or false end
	members[ns.NameKey(f.name)] = f.name
	note("%s joins your party (pretend). You %s the group.", f.name, leader and "lead" or "do not lead")
	ns.Dispatch("GROUP_ROSTER_UPDATE")
end

-- Player `f` invites you: the real invitation handlers run (auto-group may
-- accept), then you are in.
local function inviteYou(f)
	if not active then return end
	note("%s invites you. (In game: the invitation popup. Taken as accepted.)", f.name)
	ns.Dispatch("PARTY_INVITE_REQUEST", f.name)
	ns.After(1.5, function() join(f, false) end)
end

---------------------------------------------------------------------------
-- What you send: printed, and the players react
---------------------------------------------------------------------------

local WHAT = {
	S = "search", R = "answer to a search", Q = "who has this quest?", A = "I have this quest",
	X = "my search is over", G = "please invite me (auto-group)", T = "channel test",
}

local function describe(m)
	local what = WHAT[m.kind] or m.kind
	local names = {}
	for i, q in ipairs(m.quests or {}) do
		if i > 3 then names[#names + 1] = "..." break end
		names[#names + 1] = ns.Quests.Title(q.id) .. (q.counts and (" " .. q.counts[1][1] .. "/" .. q.counts[1][2]) or "")
	end
	if #names > 0 then what = what .. ": " .. table.concat(names, ", ") end
	return what
end

local function react(m, text, chatType, target)
	if m.kind == "T" then
		ns.After(0.5, function() deliver(text, chatType, me()) end)
	elseif m.kind == "S" and chatType == "CHANNEL" then
		for i, f in ipairs(FAKES) do
			ns.After(1 + i, function() deliver(replyText(f), "WHISPER", f.name) end)
		end
	elseif m.kind == "Q" and m.quests[1] then
		local id = m.quests[1].id
		for i = 1, 2 do
			local f = FAKES[i]
			ns.After(1 + i, function() deliver(questReplyText(f, id), "WHISPER", f.name) end)
		end
	elseif m.kind == "G" then
		local f = fake(target)
		if f then ns.After(2, function() inviteYou(f) end) end
	end
end

-- An addon message (Channels.lua). Returns true, as the client would.
function Demo.Outgoing(chatType, text, target)
	local m = ns.Protocol.Decode(text)
	note("-> %s%s: %s", chatType, target and (" to " .. ns.ShortName(target)) or "", m and describe(m) or text)
	ns.Debug("   %s", text)
	if m then react(m, text, chatType, target) end
	return true
end

-- A chat line: whisper, party, announce.
function Demo.Chat(text, chatType, target)
	note("-> %s%s: \"%s\"", chatType, target and (" to " .. ns.ShortName(target)) or "", text)
	local f = chatType == "WHISPER" and fake(target)
	-- A player in a group got your Ask: they invite you.
	if f and (f.size or 0) > 0 and not Demo.IsMember(f.name) then
		ns.After(2.5, function() inviteYou(f) end)
	end
	return true
end

function Demo.Invite(name)
	note("-> invite %s", ns.ShortName(name))
	local f = fake(name)
	if f then ns.After(2, function() join(f, true) end) end
end

function Demo.Leave()
	note("-> leave the party")
	wipe(members)
	leader = false
	ns.Dispatch("GROUP_ROSTER_UPDATE")
end

---------------------------------------------------------------------------
-- Commands
---------------------------------------------------------------------------

local function found(f)
	return ns.Matcher.Get(f.name) ~= nil
end

local function setActive(on)
	active = on and true or false
	if not active then
		disband()
		distance = nil
	end
	ns.Fire("SETTING", "demo", active)
	ns.Fire("PEERS")
end

local function groupWith(f)
	local ids = {}
	for _, q in ipairs(myQuests()) do ids[#ids + 1] = q.id end
	if not found(f) then deliver(searchText(f), "CHANNEL", f.name) end
	ns.Leave.NoteInvite(f.name, ids)
	join(f, true)
end

local COMMANDS = {}

function COMMANDS.search()
	if ns.Search then ns.Search() end
end

function COMMANDS.players()
	if not hasQuests() then return end
	for i, f in ipairs(FAKES) do
		ns.After(i * 0.8, function() deliver(searchText(f), "CHANNEL", f.name) end)
	end
	note("The 3 players search on the finder's channel...")
end

function COMMANDS.progress()
	local any = false
	for _, f in ipairs(FAKES) do
		if found(f) and counts[f.name] then
			any = true
			for _, c in pairs(counts[f.name]) do
				for _, hn in ipairs(c) do hn[1] = math.min(hn[2], hn[1] + math.random(1, 3)) end
			end
			deliver(searchText(f), "WHISPER", f.name)
		end
	end
	if not any then note("Nobody found yet: /psgf demo search or /psgf demo players first.") end
end

function COMMANDS.stop()
	local f = FAKES[3]
	if not found(f) then note("Tibbs is not on your list.") return end
	deliver("X|" .. f.sid, "WHISPER", f.name)
	note("Tibbs ended their search.")
end

function COMMANDS.invite()
	if not hasQuests() then return end
	local f = FAKES[1]
	if Demo.IsMember(f.name) then note("Aelyra is already in your party.") return end
	if not found(f) then deliver(searchText(f), "CHANNEL", f.name) end
	inviteYou(f)
end

function COMMANDS.hello()
	if not hasQuests() then return end
	if not (ns.Get("partyBox") and ns.Messages.On("hello")) then
		note("Turn on \"Show the message box when grouping\" and the hello message first.")
	end
	ns.PartyBox.ResetHello()
	disband()
	ns.Leave.Forget()
	groupWith(FAKES[1])
end

function COMMANDS.done()
	if not hasQuests() then return end
	if not ns.Get("partyBox") then note("Turn on \"Show the message box when grouping\" first.") return end
	if not (ns.Leave.Active() and Demo.InGroup()) then
		ns.PartyBox.ResetHello(ns.Now()) -- straight to goodbye
		groupWith(FAKES[1])
	end
	ns.After(1.5, function()
		if not ns.Leave.Active() then return end
		note("Your group's quests are done (pretend).")
		ns.Fire("GROUP_DONE")
	end)
end

function COMMANDS.near()
	if not ns.Get("openNear") then note("Turn on \"Open the finder near my quest\" first.") return end
	local P = ns.PolestarStepQuests and ns.PolestarStepQuests() or {}
	local worth = false
	for _, id in ipairs(P) do if ns.Quests.Kind(id) then worth = true end end
	if not worth then
		note("Polestar's live step has no kill, named, loot or group quest of your log: nothing would open.")
		return
	end
	distance = 50
	if ns.Nearby.Reset then ns.Nearby.Reset() end
	if ns.QuestUI then ns.QuestUI.Close() end
	ns.UI.Hide()
	note("Pretending you are 50 m from the objective...")
	ns.After(0.5, function()
		if not ns.Nearby.Check() then note("It did not open (in combat, in an instance, or the panel is open).") end
		distance = nil
	end)
end

function COMMANDS.reset()
	disband()
	wipe(counts)
	ns.Leave.Forget()
	ns.Matcher.Clear()
	note("Cleared.")
end

function Demo.Command(arg)
	arg = (arg or ""):lower()
	if arg == "" or arg == "on" or arg == "off" then
		local on = arg == "on" or (arg == "" and not active)
		if not on then
			setActive(false)
			note("Demo off: the finder works for real again.")
			return
		end
		setActive(true)
		if not ns.Get("enabled") then ns.SetEnabled(true) end
		for _, line in ipairs(HELP) do ns.Print(line) end
		ns.UI.Show()
		return
	end
	if arg == "help" then
		for _, line in ipairs(HELP) do ns.Print(line) end
		return
	end
	if not active then
		note("Turn the demo on first: /psgf demo")
		return
	end
	if arg == "goodbye" then arg = "done" end
	local fn = COMMANDS[arg]
	if fn then fn() else for _, line in ipairs(HELP) do ns.Print(line) end end
end

-- Tests.
Demo.FAKES = FAKES
