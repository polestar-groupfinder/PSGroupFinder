-- Polestar Group Finder: talking to other players who run it.
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
-- Prefix "PSGF". Messages (fields split by "|", at most 255 bytes):
--   S|<sid>|<map>|<x>|<y>|<level>|<class>|<group size>|<flags>|<quest>:<kind>,...
--       a search, broadcast from a click or a key press; sent again (Update)
--       with the quests left whenever an objective is done, from the channels
--       that need no key press and by whisper to the players found
--   R|<sid>|<map>|<x>|<y>|<level>|<class>|<group size>|<flags>|<quest>,...
--       the answer, whispered to the searcher, naming only the quests both
--       have
--   X|<sid>
--       the search is over (last objective done, stopped, group full): the
--       players who listed us drop us
--   G|<sid>|<quest>,...
--       whispered when auto-group is on and the other player should invite
--       us (see Group.lua)
-- <flags>: "g" auto-group is on, "A" / "H" the faction (Alliance / Horde),
-- empty when unknown. A search with no quest in common with the receiver
-- removes the sender from the receiver's list.
--   T|<sid>|<nonce>
--       a channel probe: nobody answers it, we only listen for our own echo
-- <sid> is a random id for this session: a message carrying ours is our
-- own echo, which tells us the channel works. <x> and <y> are 0-1000, empty
-- when the player does not share them (shareCoords off).
--
-- Channels, tried in this order: CHANNEL (a hidden custom channel,
-- CHANNEL_NAME; Classic clients refuse addon messages there, Forever's
-- launch build did too: InvalidChannel), YELL, SAY (nearby players only,
-- throttled hard), GUILD. WHISPER carries the answers. Comm.status says
-- what each one did: "ok" (our message came back), "sent" (the client took
-- it, no echo yet), "fail" (refused, with the code) or "skip" (cannot be
-- tried now: no guild, channel not joined).

local _, ns = ...
local L = ns.L
local Throttle = ns.Throttle

local Comm = {}
ns.Comm = Comm

Comm.PREFIX = "PSGF"
Comm.CHANNEL_NAME = "PSGroupFinder"
Comm.ORDER = { "CHANNEL", "YELL", "SAY", "GUILD" }
Comm.status = {}   -- chatType -> { state, code, at }
local SEARCH_GAP = 20       -- seconds between two searches of yours
local REPLY_GAP = 20        -- seconds between two answers to the same player (a searcher's own gap)
local PROBE_WAIT = 4        -- seconds to wait for a probe's echo
local JOIN_DELAY = 6        -- seconds after login before joining the channel (keeps /1, /2 for the game's)

local sid = string.format("%06x", math.random(0, 0xffffff))
Comm.sid = sid
local prefixReady = false
local lastSearch = -math.huge
local lastReply = {} -- sender -> time

local function setStatus(chatType, state, code)
	local old = Comm.status[chatType]
	-- An echo is proof: a later "sent" does not take it back.
	if old and old.state == "ok" and state == "sent" then return end
	Comm.status[chatType] = { state = state, code = code, at = ns.Now() }
	ns.Fire("CHANNELS")
end

local function registerPrefix()
	if prefixReady or not (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) then return end
	local ok = pcall(C_ChatInfo.RegisterAddonMessagePrefix, Comm.PREFIX)
	prefixReady = ok
end

---------------------------------------------------------------------------
-- The hidden channel
---------------------------------------------------------------------------

function Comm.ChannelId()
	if not GetChannelName then return nil end
	local id = GetChannelName(Comm.CHANNEL_NAME)
	id = ns.Readable(id)
	return (type(id) == "number" and id > 0) and id or nil
end

local function hideChannel()
	if not ChatFrame_RemoveChannel then return end
	for i = 1, (NUM_CHAT_WINDOWS or 10) do
		local f = _G["ChatFrame" .. i]
		if f then pcall(ChatFrame_RemoveChannel, f, Comm.CHANNEL_NAME) end
	end
end

function Comm.JoinChannel()
	if Comm.ChannelId() then hideChannel() return end
	local join = JoinTemporaryChannel or JoinChannelByName
	if join then pcall(join, Comm.CHANNEL_NAME) end
	ns.After(1, hideChannel)
end

function Comm.LeaveChannel()
	if Comm.ChannelId() and LeaveChannelByName then pcall(LeaveChannelByName, Comm.CHANNEL_NAME) end
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------

-- The target argument for a chat type, or nil plus why it cannot be used.
local function targetFor(chatType)
	if chatType == "CHANNEL" then
		local id = Comm.ChannelId()
		if not id then return nil, L.NOT_JOINED end
		return id
	elseif chatType == "GUILD" then
		if not (IsInGuild and IsInGuild()) then return nil, L.NOT_IN_GUILD end
	end
	return false
end

local function trySend(chatType, text)
	local target, why = targetFor(chatType)
	if target == nil then
		setStatus(chatType, "skip", why)
		return false
	end
	local ok, code = Throttle.SendNow(Comm.PREFIX, text, chatType, target or nil)
	if ok then setStatus(chatType, "sent") else setStatus(chatType, "fail", Throttle.ResultName(code)) end
	return ok
end

-- The channels a search goes out on: the best that worked (an echo first,
-- then one the client took), else every one not known to fail; plus the
-- guild beside a public one.
local function searchChannels()
	local best
	for _, state in ipairs({ "ok", "sent" }) do
		for _, ct in ipairs(Comm.ORDER) do
			local s = Comm.status[ct]
			if not best and s and s.state == state then best = ct end
		end
	end
	if best then
		local list = { best }
		if best ~= "GUILD" and IsInGuild and IsInGuild() then
			local g = Comm.status.GUILD
			if not (g and g.state == "fail") then list[2] = "GUILD" end
		end
		return list
	end
	local list = {}
	for _, ct in ipairs(Comm.ORDER) do
		local s = Comm.status[ct]
		if not (s and s.state == "fail") then list[#list + 1] = ct end
	end
	return list
end

function Comm.BestChannel()
	return searchChannels()[1]
end

local function coords(x)
	if not (x and ns.Get("shareCoords")) then return "" end
	return tostring(math.floor(x * 1000 + 0.5))
end

local function flags()
	local f = ns.Get("autoGroup") and "g" or ""
	local faction = UnitFactionGroup and select(1, UnitFactionGroup("player"))
	if faction == "Alliance" then f = f .. "A" elseif faction == "Horde" then f = f .. "H" end
	return f
end

local function me()
	local map, x, y = ns.Quests.Position()
	local level = UnitLevel and UnitLevel("player") or 0
	local class
	if UnitClass then class = select(2, UnitClass("player")) end
	local size = (GetNumGroupMembers and GetNumGroupMembers()) or 0
	return tostring(map or 0), coords(x), coords(y), tostring(level or 0), class or "", tostring(size), flags()
end

-- Builds the search text for `quests` ({ id, kind }), cutting quests until
-- it fits 255 bytes.
function Comm.EncodeSearch(quests)
	local map, x, y, lvl, class, size, fl = me()
	local head = table.concat({ "S", sid, map, x, y, lvl, class, size, fl }, "|") .. "|"
	local parts = {}
	for _, q in ipairs(quests) do
		local entry = q.id .. ":" .. q.kind
		if #head + #table.concat(parts, ",") + #entry + 1 > 255 then break end
		parts[#parts + 1] = entry
	end
	return head .. table.concat(parts, ","), #parts
end

function Comm.EncodeGroupRequest(ids)
	local parts = {}
	for _, id in ipairs(ids) do
		if 2 + #sid + 2 + #table.concat(parts, ",") + #tostring(id) + 1 > 255 then break end
		parts[#parts + 1] = tostring(id)
	end
	return "G|" .. sid .. "|" .. table.concat(parts, ",")
end

function Comm.EncodeReply(ids)
	local map, x, y, lvl, class, size, fl = me()
	local head = table.concat({ "R", sid, map, x, y, lvl, class, size, fl }, "|") .. "|"
	local parts = {}
	for _, id in ipairs(ids) do
		if #head + #table.concat(parts, ",") + #tostring(id) + 1 > 255 then break end
		parts[#parts + 1] = tostring(id)
	end
	return head .. table.concat(parts, ",")
end

-- Splits a message; nil for anything malformed.
function Comm.Decode(text)
	if type(text) ~= "string" or #text > 255 then return nil end
	local kind, msid, map, x, y, lvl, class, size, fl, list = text:match("^([SR])|(%x+)|(%d+)|(%d*)|(%d*)|(%d+)|(%u*)|(%d+)|([gAH]*)|(.*)$")
	if not kind then
		local tsid, nonce = text:match("^T|(%x+)|(%w+)$")
		if tsid then return { kind = "T", sid = tsid, nonce = nonce } end
		local xsid = text:match("^X|(%x+)$")
		if xsid then return { kind = "X", sid = xsid } end
		local gsid, ids = text:match("^G|(%x+)|([%d,]*)$")
		if gsid then
			local m = { kind = "G", sid = gsid, quests = {} }
			for id in ids:gmatch("%d+") do m.quests[#m.quests + 1] = { id = tonumber(id) } end
			return m
		end
		return nil
	end
	local m = { kind = kind, sid = msid, map = tonumber(map), level = tonumber(lvl), class = class, size = tonumber(size), flags = fl, quests = {} }
	if m.map == 0 then m.map = nil end
	if x ~= "" and y ~= "" then m.x, m.y = tonumber(x) / 1000, tonumber(y) / 1000 end
	for entry in list:gmatch("[^,]+") do
		local id, k = entry:match("^(%d+):?([gnkl]?)$")
		id = tonumber(id)
		if id then m.quests[#m.quests + 1] = { id = id, kind = k ~= "" and k or nil } end
	end
	return m
end

---------------------------------------------------------------------------
-- The search
---------------------------------------------------------------------------

function Comm.Search()
	if not ns.Get("enabled") then ns.Print(L.DISABLED) return false end
	if IsInInstance and IsInInstance() then ns.Print(L.INSTANCE) return false end
	local wait = SEARCH_GAP - (ns.Now() - lastSearch)
	if wait > 0 then ns.Print(L.COOLDOWN, math.ceil(wait)) return false end
	local quests = ns.Quests.Relevant()
	if #quests == 0 then ns.Print(L.NO_QUESTS) return false end
	registerPrefix()
	local text, count = Comm.EncodeSearch(quests)
	local sentOn, public = {}, false
	-- Sent here, in the click's or key's call: SAY and YELL may need it.
	-- One public channel is enough; the guild may come beside it.
	for _, ct in ipairs(searchChannels()) do
		if (ct == "GUILD" or not public) and trySend(ct, text) then
			sentOn[#sentOn + 1] = ct
			if ct ~= "GUILD" then public = true end
		end
	end
	if #sentOn == 0 then ns.Print(L.NO_CHANNEL) return false end
	lastSearch = ns.Now()
	ns.searchedAt = lastSearch
	ns.Session.Start(quests)
	ns.Print(L.SENT, table.concat(sentOn, ", "), count)
	ns.Fire("SEARCHED", quests, sentOn)
	return true
end

function Comm.SearchCooldown()
	return math.max(0, SEARCH_GAP - (ns.Now() - lastSearch))
end

-- Sends `text` with no key press behind it: only the channels that need
-- none (CHANNEL, GUILD) and a whisper to each player found. SAY and YELL
-- need a hardware event, so the players only they reached keep the old
-- list until their entry expires.
local MAX_WHISPERS = 8
local function broadcastQuiet(text)
	registerPrefix()
	local sent = false
	for _, ct in ipairs(searchChannels()) do
		if ct == "CHANNEL" or ct == "GUILD" then
			if trySend(ct, text) then sent = true end
			if ct == "CHANNEL" then break end
		end
	end
	local names = ns.Matcher.Names()
	for i = 1, math.min(#names, MAX_WHISPERS) do
		Throttle.Send(Comm.PREFIX, text, "WHISPER", names[i])
		sent = true
	end
	return sent
end

-- The search changed (an objective is done): say what is left.
function Comm.Update()
	if not (ns.Get("enabled") and ns.Session.Active()) then return end
	local text = Comm.EncodeSearch(ns.Session.List())
	broadcastQuiet(text)
end

-- The search is over: tell the players who listed us.
function Comm.Stop()
	if not ns.Get("enabled") then return end
	broadcastQuiet("X|" .. sid)
end

---------------------------------------------------------------------------
-- Channel test
---------------------------------------------------------------------------

-- `hardware`: called from a click, a key or a slash command, so SAY and
-- YELL can be tried too; the quiet probe after joining (a timer) tries only
-- CHANNEL and GUILD.
local probing = false
function Comm.TestChannels(hardware)
	if probing then return end
	if not ns.Get("enabled") then ns.Print(L.DISABLED) return end
	registerPrefix()
	probing = true
	local nonce = string.format("%x", math.random(0, 0xfffff))
	local text = "T|" .. sid .. "|" .. nonce
	if hardware then ns.Print(L.TESTING, PROBE_WAIT) end
	for _, ct in ipairs(Comm.ORDER) do
		if hardware or ct == "CHANNEL" or ct == "GUILD" then
			local s = Comm.status[ct]
			if s and s.state == "ok" then s.state = "sent" end -- prove it again
			trySend(ct, text)
		end
	end
	ns.After(PROBE_WAIT, function()
		probing = false
		Comm.Report(hardware)
	end)
end

function Comm.Report(verbose)
	local any = false
	for _, ct in ipairs(Comm.ORDER) do
		local s = Comm.status[ct]
		if s then
			if s.state == "ok" then any = true end
			if verbose then
				if s.state == "ok" then ns.Print(L.CHANNEL_OK, ct)
				elseif s.state == "sent" then ns.Print(L.CHANNEL_SENT, ct)
				elseif s.state == "fail" then ns.Print(L.CHANNEL_FAIL, ct, tostring(s.code))
				else ns.Print(L.CHANNEL_SKIP, ct, tostring(s.code)) end
			end
		end
	end
	local best = Comm.BestChannel()
	if best then ns.Print(L.CHANNEL_BEST, best) elseif not any then ns.Print(L.CHANNEL_NONE) end
	ns.Fire("CHANNELS")
end

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------

local ACCEPTED = { CHANNEL = true, YELL = true, SAY = true, GUILD = true, WHISPER = true }

local function ignored(sender)
	if C_FriendList and C_FriendList.IsIgnored then
		local ok, r = pcall(C_FriendList.IsIgnored, sender)
		if ok and r then return true end
	end
	return false
end

local function onMessage(_, prefix, text, chatType, sender)
	if prefix ~= Comm.PREFIX or not ns.Get("enabled") or not ACCEPTED[chatType] then return end
	sender = ns.Readable(sender)
	text = ns.Readable(text)
	if type(sender) ~= "string" or sender == "" then return end
	local m = Comm.Decode(text)
	if not m then return end
	if m.sid == sid then
		-- Our own message came back: this channel works.
		setStatus(chatType, "ok")
		return
	end
	if m.kind == "T" or ignored(sender) then return end
	if IsInInstance and IsInInstance() then return end
	local Matcher = ns.Matcher
	-- A player of the other faction cannot group with us (Forever).
	local theirs, mine = m.flags and m.flags:match("[AH]"), flags():match("[AH]")
	if theirs and mine and theirs ~= mine then return end
	if m.kind == "X" then
		Matcher.Remove(sender)
		return
	elseif m.kind == "G" then
		ns.Group.OnRequest(sender, m)
		return
	end
	-- `listed`: quests of my active search (else any open one) they share;
	-- `answer`: every open quest of mine they look for, which is worth a reply.
	local listed, answer = {}, {}
	for _, q in ipairs(m.quests) do
		if ns.Quests.Pending(q.id) then
			answer[#answer + 1] = q.id
			if Matcher.Mine(q.id) then listed[#listed + 1] = q.id end
		end
	end
	if m.kind == "S" then
		if #listed == 0 then
			-- Their search no longer covers anything we look for.
			Matcher.Remove(sender)
		else
			Matcher.Add(sender, m, listed, "asking")
		end
		if #answer == 0 then return end
		if ns.Get("autoGroup") and m.flags and m.flags:find("g", 1, true) then ns.Group.Expect(sender) end
		-- A whispered search is an update to a player already found: no new answer.
		if ns.Get("autoReply") and chatType ~= "WHISPER" and ns.Now() - (lastReply[sender] or -math.huge) >= REPLY_GAP then
			lastReply[sender] = ns.Now()
			registerPrefix()
			-- A short random wait spreads the answers of a crowd.
			ns.After(0.5 + math.random() * 2, function()
				Throttle.Send(Comm.PREFIX, Comm.EncodeReply(answer), "WHISPER", sender)
			end)
		end
	elseif m.kind == "R" then
		if #listed > 0 then Matcher.Add(sender, m, listed, "reply") end
	end
end

ns.RegisterEvent("CHAT_MSG_ADDON", onMessage)

ns.On("ENABLED", function(on)
	if on then
		registerPrefix()
		ns.After(JOIN_DELAY, function()
			if not ns.Get("enabled") then return end
			Comm.JoinChannel()
			-- A quiet probe once joined, so the panel can say what works.
			ns.After(3, function() if ns.Get("enabled") then Comm.TestChannels(false) end end)
		end)
	else
		Comm.LeaveChannel()
		wipe(Comm.status)
		ns.Fire("CHANNELS")
	end
end)

ns.Search = Comm.Search
ns.TestChannels = Comm.TestChannels
