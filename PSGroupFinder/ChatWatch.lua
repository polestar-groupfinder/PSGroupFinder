-- Group Finder for Polestar (PSGroupFinder): reading public chat for players who look for a
-- group on one of your quests, and who do not run the finder.
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
-- Listens to the public channels (General, looking for group, trade...),
-- /say and /yell while the finder is on and `readChat` is set. A line counts
-- for one of your quests that still has something to do when:
--   1. it carries a link to that quest (exact, whatever the language), or
--   2. it contains the quest's whole title (accents, case and punctuation
--      aside); a short title also needs a looking-for-group word, or
--   3. it has a looking-for-group word and a distinctive word of the title
--      (5 letters or more, in no other quest of yours, not a common word).
-- The players found this way are listed "via chat" for a few minutes, with
-- their line in the tooltip: Whisper and Invite work as for the others,
-- but nothing is ever sent to them on its own and they never take part in
-- auto-grouping. Nothing is read inside an instance.

local _, ns = ...

local ChatWatch = {}
ns.ChatWatch = ChatWatch

local MAX_AGE = 300  -- seconds a chat entry stays listed
local SHORT = 8      -- a normalized title shorter than this needs an LFG word
local MIN_WORD = 5   -- length of a distinctive title word

local ZONE_CHANNELS = { general = true, allgemein = true, generale = true, geral = true }
local peers = {}     -- sender -> entry
local index          -- { { id, title, words = {} } } of the pending quests, rebuilt on log changes
local dirty = true

-- Accented letters folded to plain ones (the frequent Latin ones), so that
-- "Élite" in a title matches "elite" typed in chat.
local FOLD = {
	["à"] = "a", ["á"] = "a", ["â"] = "a", ["ä"] = "a", ["ã"] = "a", ["À"] = "a", ["Á"] = "a", ["Â"] = "a", ["Ä"] = "a",
	["ç"] = "c", ["Ç"] = "c",
	["è"] = "e", ["é"] = "e", ["ê"] = "e", ["ë"] = "e", ["È"] = "e", ["É"] = "e", ["Ê"] = "e", ["Ë"] = "e",
	["ì"] = "i", ["í"] = "i", ["î"] = "i", ["ï"] = "i", ["Î"] = "i", ["Ï"] = "i",
	["ñ"] = "n", ["Ñ"] = "n",
	["ò"] = "o", ["ó"] = "o", ["ô"] = "o", ["ö"] = "o", ["õ"] = "o", ["Ô"] = "o", ["Ö"] = "o",
	["ù"] = "u", ["ú"] = "u", ["û"] = "u", ["ü"] = "u", ["Û"] = "u", ["Ü"] = "u",
	["ß"] = "ss", ["œ"] = "oe", ["Œ"] = "oe",
}

-- Words that say "I look for a group", in the client languages most played.
local LFG_WORDS = {}
for w in ([[lfg lfm lf lf1 lf2 lf3 lf4 lf1m lf2m lf3m lf4m group grp party need anyone help
	groupe grpe cherche cherchons recherche besoin aide
	gruppe suche suchen hilfe grupo busco buscamos ayuda gruppo cerco cerchiamo aiuto]]):gmatch("%S+") do
	LFG_WORDS[w] = true
end

-- Frequent title words that say nothing about which quest it is.
local COMMON = {}
for w in ([[wanted report return deliver supplies missing found again first second third under after
	before about other their there these those where which while forest north south east west
	recherche retour rapport livraison perdu perdue premier premiere encore contre entre leurs
	gesucht bericht zuruck lieferung]]):gmatch("%S+") do
	COMMON[w] = true
end

-- Lower case, links reduced to their text, accents folded, punctuation as spaces.
function ChatWatch.Normalize(text)
	text = tostring(text or "")
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	text = text:gsub("|H.-|h(.-)|h", "%1")
	text = text:gsub("[\195\197][\128-\191]", FOLD)
	text = text:lower():gsub("%p", " "):gsub("%s+", " ")
	return (text:gsub("^ ", ""):gsub(" $", ""))
end

local function words(normalized)
	local out = {}
	for w in normalized:gmatch("%S+") do out[#out + 1] = w end
	return out
end

local function buildIndex()
	index = {}
	local count = {} -- word -> how many of my titles have it
	for id, q in pairs(ns.Quests.Log()) do
		if ns.Quests.Pending(id) and type(q.title) == "string" then
			local title = ChatWatch.Normalize(q.title)
			if title ~= "" then
				local entry = { id = id, title = title, words = {} }
				local seen = {}
				for _, w in ipairs(words(title)) do
					if #w >= MIN_WORD and not COMMON[w] and not LFG_WORDS[w] and not seen[w] then
						seen[w] = true
						entry.words[#entry.words + 1] = w
						count[w] = (count[w] or 0) + 1
					end
				end
				index[#index + 1] = entry
			end
		end
	end
	-- A word shared by two of my quests does not say which one.
	for _, entry in ipairs(index) do
		local unique = {}
		for _, w in ipairs(entry.words) do if count[w] == 1 then unique[#unique + 1] = w end end
		entry.words = unique
	end
	dirty = false
end

-- The ids of my pending quests that chat line `text` is about.
function ChatWatch.Match(text)
	if type(text) ~= "string" or text == "" then return {} end
	local found, seen = {}, {}
	local function add(id) if not seen[id] then seen[id] = true found[#found + 1] = id end end
	for id in text:gmatch("|Hquest:(%d+)") do
		id = tonumber(id)
		if id and ns.Quests.Pending(id) then add(id) end
	end
	if dirty or not index then buildIndex() end
	local norm = " " .. ChatWatch.Normalize(text) .. " "
	local lfg = false
	for w in norm:gmatch("%S+") do if LFG_WORDS[w] then lfg = true break end end
	for _, entry in ipairs(index) do
		if norm:find(" " .. entry.title .. " ", 1, true) then
			if #entry.title >= SHORT or lfg then add(entry.id) end
		elseif lfg then
			for _, w in ipairs(entry.words) do
				if norm:find(" " .. w .. " ", 1, true) then add(entry.id) break end
			end
		end
	end
	return found
end

---------------------------------------------------------------------------
-- The players found
---------------------------------------------------------------------------

local function channelLabel(event, channelName)
	if event == "CHAT_MSG_SAY" then return ns.L.ANN_TO_SAY end
	if event == "CHAT_MSG_YELL" then return ns.L.ANN_TO_YELL end
	-- "1. General - Elwynn Forest" -> "General"
	local name = tostring(channelName or ""):gsub("^%d+%.%s*", ""):gsub("%s+%-%s+.*$", "")
	return name ~= "" and name or "?"
end

local function classOf(guid)
	if not (guid and GetPlayerInfoByGUID) then return nil end
	local ok, _, class = pcall(GetPlayerInfoByGUID, guid)
	class = ok and ns.Readable(class)
	return type(class) == "string" and class or nil
end

local function isMe(sender)
	local me = UnitName and ns.Readable(UnitName("player"))
	return me and ns.NameKey(sender) == ns.NameKey(me)
end

local function ignored(sender)
	if not (C_FriendList and C_FriendList.IsIgnored) then return false end
	local ok, r = pcall(C_FriendList.IsIgnored, sender)
	return ok and r and true or false
end

local function onChat(event, text, sender, _, channelName, _, _, _, _, channelBase, _, _, guid)
	if not (ns.Get("enabled") and ns.Get("readChat")) then return end
	if IsInInstance and IsInInstance() then return end
	text, sender = ns.Readable(text), ns.Readable(sender)
	if type(text) ~= "string" or type(sender) ~= "string" or sender == "" then return end
	if event == "CHAT_MSG_CHANNEL" then
		local base = ns.Readable(channelBase) or ns.Readable(channelName) or ""
		if tostring(base):find(ns.Channels.NAME, 1, true) then return end
	end
	if isMe(sender) or ignored(sender) or ns.Matcher.Get(sender) or ns.Matcher.InGroup(sender) then return end
	local ids = ChatWatch.Match(text)
	if #ids == 0 then return end
	local e = peers[sender] or { name = sender, source = "chat", size = 0, flags = "", quests = {} }
	local isNew = peers[sender] == nil
	e.quests = ids
	e.said = text
	e.where = channelLabel(event, ns.Readable(channelName))
	-- General, /say and /yell are heard in this zone only.
	e.sameZone = event ~= "CHAT_MSG_CHANNEL" or ZONE_CHANNELS[ChatWatch.Normalize(e.where)] == true
	e.class = classOf(ns.Readable(guid)) or e.class
	e.at = ns.Now()
	peers[sender] = e
	ns.Debug("chat: %s on %s (%s)", sender, ns.Quests.Title(ids[1]), e.where)
	ns.Fire("PEERS")
	if isNew then ns.Fire("CHAT_PEER_NEW", e) end
end

local function has(list, value)
	for _, v in ipairs(list) do if v == value then return true end end
	return false
end

-- The players found in chat, freshest first; `questID` keeps only those
-- about that quest. Expired entries, players now found through the
-- finder and players in my group are dropped.
function ChatWatch.List(questID)
	local now, list = ns.Now(), {}
	for name, e in pairs(peers) do
		local keep = now - e.at <= MAX_AGE and not ns.Matcher.Get(name) and not ns.Matcher.InGroup(name)
		if keep then
			local still = {}
			for _, id in ipairs(e.quests) do if ns.Quests.Pending(id) then still[#still + 1] = id end end
			e.quests = still
			keep = #still > 0
		end
		if not keep then
			peers[name] = nil
		elseif not questID or has(e.quests, questID) then
			list[#list + 1] = e
		end
	end
	table.sort(list, function(a, b) return a.at > b.at end)
	return list
end

function ChatWatch.Get(name) return peers[name] end

function ChatWatch.Clear()
	wipe(peers)
	ns.Fire("PEERS")
end

for _, ev in ipairs({ "CHAT_MSG_CHANNEL", "CHAT_MSG_SAY", "CHAT_MSG_YELL" }) do
	ns.RegisterEvent(ev, onChat)
end
for _, ev in ipairs({ "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED" }) do
	ns.RegisterEvent(ev, function() dirty = true end)
end
ns.On("ENABLED", function(on) if not on then ChatWatch.Clear() end end)
ns.On("SETTING", function(key, value) if key == "readChat" and not value then ChatWatch.Clear() end end)
