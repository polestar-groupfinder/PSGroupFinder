-- Group Finder for Polestar (PSGroupFinder): searches, and what to do with the messages of
-- other players who run it.
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
-- The message formats are in Protocol.lua, the channels in Channels.lua.
-- A search of your own only ever goes out from a click or a key press, and
-- its updates (a quest left it, it ended) go to the same players. An answer
-- to someone else's search goes out without a click only while `autoReply`
-- is on (off by default), and only for quests you have.

local _, ns = ...
local L = ns.L
local Protocol = ns.Protocol
local Channels = ns.Channels

local Comm = {}
ns.Comm = Comm

local SEARCH_GAP = 20     -- seconds between two searches of yours
local REPLY_GAP = 20      -- seconds between two answers to the same player (a searcher's own gap)
local QUEST_GAP = 15      -- seconds between two quest searches of yours
local QUEST_ASK_TTL = 180 -- seconds an answer to a quest search is still wanted
local QUEST_ANSWERS = 6   -- answers to other players' quest searches per QUEST_WINDOW
local QUEST_WINDOW = 30

local lastSearch = -math.huge
local lastQuestSearch = -math.huge
local lastReply = {} -- sender (or sender#quest) -> time
local asked = {}     -- questID -> time of our quest search
local answered = {}  -- times of our recent answers to quest searches

-- Why a search cannot go out now (printed), or nil.
local function blocked()
	if not ns.Get("enabled") then return L.DISABLED end
	if IsInInstance and IsInInstance() then return L.INSTANCE end
end

---------------------------------------------------------------------------
-- Searches
---------------------------------------------------------------------------

function Comm.SearchCooldown()
	return math.max(0, SEARCH_GAP - (ns.Now() - lastSearch))
end

-- Your quests near you: a session (Session.lua) that lasts until they are done.
function Comm.Search()
	local why = blocked()
	if why then ns.Print(why) return false end
	local wait = Comm.SearchCooldown()
	if wait > 0 then ns.Print(L.COOLDOWN, math.ceil(wait)) return false end
	local quests = ns.Quests.Relevant()
	if #quests == 0 then ns.Print(L.NO_QUESTS) return false end
	local text, count = Protocol.Search(quests)
	local sentOn = Channels.SendPublic(text)
	if #sentOn == 0 then ns.Print(L.NO_CHANNEL) return false end
	lastSearch = ns.Now()
	ns.searchedAt = lastSearch
	ns.Session.Start(quests)
	ns.Print(L.SENT, table.concat(sentOn, ", "), count)
	ns.Fire("SEARCHED", quests, sentOn)
	return true
end

function Comm.QuestCooldown()
	return math.max(0, QUEST_GAP - (ns.Now() - lastQuestSearch))
end

-- Who has quest `id`, in any zone? Same channels and language rules as a
-- search; the answers come whispered and are kept per quest
-- (Matcher.QuestList). Not a session: nothing is repeated, nobody invited.
function Comm.SearchQuest(id)
	id = tonumber(id)
	if not id or id <= 0 then return false end
	local why = blocked()
	if why then ns.Print(why) return false end
	local wait = Comm.QuestCooldown()
	if wait > 0 then ns.Print(L.QUEST_COOLDOWN, math.ceil(wait)) return false end
	local sentOn = Channels.SendPublic(Protocol.QuestSearch(id))
	if #sentOn == 0 then ns.Print(L.NO_CHANNEL) return false end
	lastQuestSearch = ns.Now()
	asked[id] = lastQuestSearch
	ns.Print(L.QUEST_SENT, table.concat(sentOn, ", "), ns.Quests.Title(id))
	ns.Fire("QUEST_SEARCHED", id, sentOn)
	return true
end

-- The search changed (an objective is done): say what is left.
function Comm.Update()
	if not (ns.Get("enabled") and ns.Session.Active()) then return end
	Channels.SendQuiet((Protocol.Search(ns.Session.List())))
end

-- The search is over: tell the players who listed us.
function Comm.Stop()
	if not ns.Get("enabled") then return end
	Channels.SendQuiet(Protocol.Stop())
end

-- Stop from a click or /psgf stop.
function Comm.StopSearch()
	if not ns.Session.Active() then return end
	Comm.Stop()
	ns.Session.Stop("manual")
	ns.Print(L.SEARCH_STOPPED)
end

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------

local ACCEPTED = { CHANNEL = true, GUILD = true, WHISPER = true }

local function ignored(sender)
	if C_FriendList and C_FriendList.IsIgnored then
		local ok, r = pcall(C_FriendList.IsIgnored, sender)
		if ok and r then return true end
	end
	return false
end

-- Answers wait a moment at random, so that a crowd does not answer at once.
local function answerLater(text, sender)
	ns.After(0.5 + math.random() * 2, function() Channels.Whisper(text, sender) end)
end

-- Q: "who has quest N?" An A goes back if we have it, within limits.
local function onQuestSearch(sender, q, chatType)
	-- A Q is never whispered.
	if chatType == "WHISPER" or not ns.Get("autoReply") or not ns.Quests.Has(q.id) then return end
	local now = ns.Now()
	local k = sender .. "#" .. q.id
	if now - (lastReply[k] or -math.huge) < REPLY_GAP then return end
	-- A crowd of askers cannot make us whisper without end.
	local recent = {}
	for _, t in ipairs(answered) do if now - t < QUEST_WINDOW then recent[#recent + 1] = t end end
	answered = recent
	if #answered >= QUEST_ANSWERS then return end
	answered[#answered + 1] = now
	lastReply[k] = now
	local id = q.id
	ns.After(0.5 + math.random() * 2, function()
		Channels.Whisper(Protocol.QuestReply(id, ns.Quests.Progress(id) or 0), sender)
	end)
end

-- A: an answer to a quest search of ours, whispered, still wanted.
local function onQuestReply(sender, m, q, chatType)
	if chatType == "WHISPER" and asked[q.id] and ns.Now() - asked[q.id] <= QUEST_ASK_TTL then
		ns.Matcher.AddQuest(sender, m, q.id, q.pct)
	end
end

-- S and R. `listed`: quests of my active search (else any open one) they
-- share; `answer`: every open quest of mine they look for.
local function onSearchOrReply(sender, m, chatType)
	local Matcher = ns.Matcher
	local listed, answer = {}, {}
	for _, q in ipairs(m.quests) do
		if ns.Quests.Pending(q.id) then
			answer[#answer + 1] = q.id
			if Matcher.Mine(q.id) then listed[#listed + 1] = q.id end
		end
	end
	if m.kind == "R" then
		if #listed > 0 then Matcher.Add(sender, m, listed, "reply") end
		return
	end
	if #listed == 0 then
		-- Their search no longer covers anything we look for.
		Matcher.Remove(sender)
	else
		Matcher.Add(sender, m, listed, "asking")
	end
	if #answer == 0 then return end
	if ns.Get("autoGroup") and m.flags:find("g", 1, true) then ns.Group.Expect(sender) end
	-- A whispered search is an update to a player already found: no new answer.
	if ns.Get("autoReply") and chatType ~= "WHISPER" and ns.Now() - (lastReply[sender] or -math.huge) >= REPLY_GAP then
		lastReply[sender] = ns.Now()
		answerLater(Protocol.Reply(answer), sender)
	end
end

local function onMessage(_, prefix, text, chatType, sender)
	if prefix ~= Protocol.PREFIX or not ns.Get("enabled") or not ACCEPTED[chatType] then return end
	sender = ns.Readable(sender)
	text = ns.Readable(text)
	if type(sender) ~= "string" or sender == "" then return end
	local m = Protocol.Decode(text)
	if not m then return end
	if m.sid == Protocol.sid then
		-- Our own message came back: this channel works.
		Channels.SetStatus(chatType, "ok")
		return
	end
	ns.Debug("<- %s from %s on %s", m.kind, sender, chatType)
	if m.kind == "T" or ignored(sender) then return end
	if IsInInstance and IsInInstance() then return end
	if m.kind == "X" then ns.Matcher.Remove(sender) return end
	if m.kind == "G" then ns.Group.OnRequest(sender, m) return end
	-- A player of the other faction cannot group with us.
	local theirs, mine = m.flags:match("[AH]"), Protocol.Flags():match("[AH]")
	if theirs and mine and theirs ~= mine then return end
	if not ns.Lang.Compatible(m.langs) then
		if m.kind == "S" or m.kind == "R" then ns.Matcher.Remove(sender) end
		return
	end
	if m.kind == "Q" or m.kind == "A" then
		local q = m.quests[1]
		if not q then return end
		if m.kind == "Q" then onQuestSearch(sender, q, chatType) else onQuestReply(sender, m, q, chatType) end
		return
	end
	onSearchOrReply(sender, m, chatType)
end

ns.RegisterEvent("CHAT_MSG_ADDON", onMessage)

ns.Search = Comm.Search
ns.TestChannels = Channels.Test
