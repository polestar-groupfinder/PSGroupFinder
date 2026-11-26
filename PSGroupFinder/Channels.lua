-- Group Finder for Polestar (PSGroupFinder): which channels carry our messages, and sending
-- on them.
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
-- Tried in this order: CHANNEL (a hidden custom channel; Classic clients
-- refuse addon messages there, Forever's launch build did too:
-- InvalidChannel), YELL, SAY (nearby players only), GUILD. WHISPER carries
-- the answers. Channels.status says what each one did: "ok" (our message
-- came back), "sent" (the client took it, no echo yet), "fail" (refused,
-- with the code) or "skip" (cannot be tried now: no guild, not joined).
-- SAY and YELL need a hardware event, so only a click or a key press may
-- use them; updates sent with no key press go on CHANNEL, GUILD and by
-- whisper (Channels.SendQuiet).

local _, ns = ...
local L = ns.L
local Throttle = ns.Throttle
local Protocol = ns.Protocol

local Channels = {}
ns.Channels = Channels

Channels.NAME = "PSGroupFinder"
Channels.ORDER = { "CHANNEL", "YELL", "SAY", "GUILD" }
Channels.status = {} -- chatType -> { state, code, at }

local PROBE_WAIT = 4   -- seconds to wait for a probe's echo
local JOIN_DELAY = 6   -- seconds after login before joining (keeps /1, /2 for the game's)
local MAX_WHISPERS = 8 -- players told by whisper when a search changes
local prefixReady = false

function Channels.SetStatus(chatType, state, code)
	local old = Channels.status[chatType]
	-- An echo is proof: a later "sent" does not take it back.
	if old and old.state == "ok" and state == "sent" then return end
	Channels.status[chatType] = { state = state, code = code, at = ns.Now() }
	ns.Fire("CHANNELS")
end

function Channels.RegisterPrefix()
	if prefixReady or not (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) then return end
	prefixReady = pcall(C_ChatInfo.RegisterAddonMessagePrefix, Protocol.PREFIX)
end

---------------------------------------------------------------------------
-- The hidden channel
---------------------------------------------------------------------------

function Channels.ChannelId()
	if not GetChannelName then return nil end
	local id = ns.Readable(GetChannelName(Channels.NAME))
	return (type(id) == "number" and id > 0) and id or nil
end

local function hideChannel()
	if not ChatFrame_RemoveChannel then return end
	for i = 1, (NUM_CHAT_WINDOWS or 10) do
		local f = _G["ChatFrame" .. i]
		if f then pcall(ChatFrame_RemoveChannel, f, Channels.NAME) end
	end
end

function Channels.Join()
	if Channels.ChannelId() then hideChannel() return end
	local join = JoinTemporaryChannel or JoinChannelByName
	if join then pcall(join, Channels.NAME) end
	ns.After(1, hideChannel)
end

function Channels.Leave()
	if Channels.ChannelId() and LeaveChannelByName then pcall(LeaveChannelByName, Channels.NAME) end
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------

-- The target argument for a chat type, or nil plus why it cannot be used.
local function targetFor(chatType)
	if chatType == "CHANNEL" then
		local id = Channels.ChannelId()
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
		Channels.SetStatus(chatType, "skip", why)
		return false
	end
	local ok, code = Throttle.SendNow(Protocol.PREFIX, text, chatType, target or nil)
	if ok then Channels.SetStatus(chatType, "sent") else Channels.SetStatus(chatType, "fail", Throttle.ResultName(code)) end
	ns.Debug("-> %s on %s: %s", text:sub(1, 1), chatType, ok and "ok" or Throttle.ResultName(code))
	return ok
end

-- The channels a search goes out on: the best that worked (an echo first,
-- then one the client took), else every one not known to fail; plus the
-- guild beside a public one.
local function candidates()
	local best
	for _, state in ipairs({ "ok", "sent" }) do
		for _, ct in ipairs(Channels.ORDER) do
			local s = Channels.status[ct]
			if not best and s and s.state == state then best = ct end
		end
	end
	if best then
		local list = { best }
		if best ~= "GUILD" and IsInGuild and IsInGuild() then
			local g = Channels.status.GUILD
			if not (g and g.state == "fail") then list[2] = "GUILD" end
		end
		return list
	end
	local list = {}
	for _, ct in ipairs(Channels.ORDER) do
		local s = Channels.status[ct]
		if not (s and s.state == "fail") then list[#list + 1] = ct end
	end
	return list
end

function Channels.Best()
	return candidates()[1]
end

-- From a click or a key press: one public channel (the first that takes
-- it) plus the guild. Returns the chat types it went out on.
function Channels.SendPublic(text)
	Channels.RegisterPrefix()
	local sentOn, public = {}, false
	for _, ct in ipairs(candidates()) do
		if (ct == "GUILD" or not public) and trySend(ct, text) then
			sentOn[#sentOn + 1] = ct
			if ct ~= "GUILD" then public = true end
		end
	end
	return sentOn
end

-- With no key press behind it: CHANNEL and GUILD only, plus a whisper to
-- each player found. The players only SAY or YELL reached keep the old
-- list until their entry expires.
function Channels.SendQuiet(text)
	Channels.RegisterPrefix()
	local sent = false
	for _, ct in ipairs(candidates()) do
		if ct == "CHANNEL" or ct == "GUILD" then
			if trySend(ct, text) then sent = true end
			if ct == "CHANNEL" then break end
		end
	end
	local names = ns.Matcher.Names()
	for i = 1, math.min(#names, MAX_WHISPERS) do
		Channels.Whisper(text, names[i])
		sent = true
	end
	return sent
end

-- Through the queue: answers, group requests, updates.
function Channels.Whisper(text, name)
	Channels.RegisterPrefix()
	ns.Debug("-> %s whispered to %s", text:sub(1, 1), name)
	if ns.ChatFilter then ns.ChatFilter.NoteWhisper(name) end
	return Throttle.Send(Protocol.PREFIX, text, "WHISPER", name)
end

---------------------------------------------------------------------------
-- Channel test
---------------------------------------------------------------------------

-- `hardware`: from a click, a key or a slash command, so SAY and YELL can be
-- tried too; the quiet probe after joining (a timer) tries CHANNEL and GUILD.
local probing = false
function Channels.Test(hardware)
	if probing then return end
	if not ns.Get("enabled") then ns.Print(L.DISABLED) return end
	Channels.RegisterPrefix()
	probing = true
	local text = Protocol.Probe(string.format("%x", math.random(0, 0xfffff)))
	if hardware then ns.Print(L.TESTING, PROBE_WAIT) end
	for _, ct in ipairs(Channels.ORDER) do
		if hardware or ct == "CHANNEL" or ct == "GUILD" then
			local s = Channels.status[ct]
			if s and s.state == "ok" then s.state = "sent" end -- prove it again
			trySend(ct, text)
		end
	end
	ns.After(PROBE_WAIT, function()
		probing = false
		Channels.Report(hardware)
	end)
end

-- `verbose`: one chat line per channel and the one in use. The quiet probe
-- only reports in debug mode; the panel shows the colours either way.
function Channels.Report(verbose)
	local say = verbose and ns.Print or ns.Debug
	local any = false
	for _, ct in ipairs(Channels.ORDER) do
		local s = Channels.status[ct]
		if s then
			if s.state == "ok" then any = true end
			if s.state == "ok" then say(L.CHANNEL_OK, ct)
			elseif s.state == "sent" then say(L.CHANNEL_SENT, ct)
			elseif s.state == "fail" then say(L.CHANNEL_FAIL, ct, tostring(s.code))
			else say(L.CHANNEL_SKIP, ct, tostring(s.code)) end
		end
	end
	local best = Channels.Best()
	if best then say(L.CHANNEL_BEST, best) elseif not any then say(L.CHANNEL_NONE) end
	ns.Fire("CHANNELS")
end

ns.On("ENABLED", function(on)
	if on then
		Channels.RegisterPrefix()
		ns.After(JOIN_DELAY, function()
			if not ns.Get("enabled") then return end
			Channels.Join()
			-- A quiet probe once joined, so the panel can say what works.
			ns.After(3, function() if ns.Get("enabled") then Channels.Test(false) end end)
		end)
	else
		Channels.Leave()
		wipe(Channels.status)
		ns.Fire("CHANNELS")
	end
end)
