-- Group Finder for Polestar (PSGroupFinder): announcing your search in public chat, for the
-- players who do not run the finder.
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
-- One short line such as "LFG Thandol Span, whisper me!" said in the zone's
-- General channel (the default), the looking-for-group channel, /say or
-- /yell. It only ever goes out from a click, a key press or a slash command:
-- the game requires a hardware event to speak in a channel, and the finder
-- never speaks for you on its own. The language of the line is chosen
-- apart from the client's (announceLang). Quests are named by the client's
-- own quest link when it gives one (each reader sees it in their language),
-- else by their title.

local _, ns = ...
local L = ns.L

local Announce = {}
ns.Announce = Announce

local GAP = 60        -- seconds between two announces
local MAX_QUESTS = 3  -- quests named in one line
local MAX_LEN = 255

-- One line per language code (Lang.lua); %s is the quest list.
Announce.TEMPLATES = {
	f = "Cherche groupe pour %s, /w moi !",
	e = "LFG %s, whisper me!",
	d = "Suche Gruppe für %s, /w mich!",
	s = "Busco grupo para %s, ¡susurradme!",
	i = "Cerco gruppo per %s, sussurratemi!",
	p = "Procuro grupo para %s, me sussurre!",
	r = "Ищу группу на %s, пишите в личку!",
	k = "%s 파티 구합니다, 귓속말 주세요!",
	c = "%s 求组，请密我！",
	t = "%s 徵求隊伍，請密我！",
}

-- Where the line goes. CHANNEL targets are found by name among the joined
-- channels (names differ by client language).
Announce.TARGETS = { "GENERAL", "LFG", "SAY", "YELL" }
local CHANNEL_NAMES = {
	GENERAL = { "general", "général", "allgemein", "generale", "geral", "общий", "일반", "综合", "綜合" },
	LFG = { "lookingforgroup", "recherchedegroupe", "suchenachgruppe", "buscargrupo", "cercagruppo",
		"procurargrupo", "поискспутников", "파티찾기", "寻求组队", "尋求組隊" },
}

local last = -math.huge

function Announce.Lang()
	local code = ns.Get("announceLang")
	if Announce.TEMPLATES[code] then return code end
	return ns.Lang.DefaultCode()
end

function Announce.Target()
	local t = ns.Get("announceTo")
	for _, v in ipairs(Announce.TARGETS) do if v == t then return t end end
	return "GENERAL"
end

function Announce.Cooldown()
	return math.max(0, GAP - (ns.Now() - last))
end

local function normalize(name)
	-- "General - Elwynn Forest" -> "general"; "Looking For Group" -> "lookingforgroup"
	name = tostring(name):gsub("%s+%-%s+.*$", "")
	return (name:lower():gsub("%s+", ""))
end

-- The id of a joined channel whose name is one of `names`, or nil.
local function findChannel(names)
	if not GetChannelList then return nil end
	local list = { GetChannelList() }
	for i = 1, #list - 1 do
		local id, name = list[i], list[i + 1]
		if type(id) == "number" and type(name) == "string" then
			local n = normalize(name)
			for _, want in ipairs(names) do
				if n == want then return id end
			end
		end
	end
	return nil
end

-- chatType, channel id for `target`; nil plus why when it cannot be used.
function Announce.Resolve(target)
	if target == "SAY" or target == "YELL" then return target end
	local id = findChannel(CHANNEL_NAMES[target] or {})
	if not id and target == "GENERAL" and GetChannelName then
		-- General is the first channel the game joins.
		local first = ns.Readable(GetChannelName(1))
		if type(first) == "number" and first > 0 then id = first end
	end
	if not id then return nil, target == "LFG" and L.ANN_NO_LFG or L.ANN_NO_GENERAL end
	return "CHANNEL", id
end

-- A quest as written in the line: the client's link, else its title.
local function questText(id)
	if GetQuestLink then
		local ok, link = pcall(GetQuestLink, id)
		link = ok and ns.Readable(link)
		-- Some clients take a log index, not an id: keep the link only if it names this quest.
		if type(link) == "string" and link:find("|Hquest:" .. id .. ":", 1, true) then return link end
	end
	return ns.Quests.Title(id)
end

-- The quests to name: those of the search in progress, else the relevant
-- ones of the log; `id` names one quest only (the quest panel).
function Announce.Quests(id)
	if id then return { tonumber(id) } end
	local out = {}
	local list = ns.Session.Active() and ns.Session.List() or ns.Quests.Relevant()
	for i = 1, math.min(#list, MAX_QUESTS) do out[i] = list[i].id end
	return out
end

-- The line for `ids` in language `code`, at most 255 bytes (quests dropped
-- from the end until it fits); nil when there is no quest.
function Announce.Text(ids, code)
	if not ids or #ids == 0 then return nil end
	local tpl = Announce.TEMPLATES[code] or Announce.TEMPLATES.e
	local names = {}
	for i, id in ipairs(ids) do names[i] = questText(id) end
	while true do
		local text = tpl:format(table.concat(names, " / "))
		if #text <= MAX_LEN then return text end
		if #names == 1 then
			-- One very long name: fall back to the plain title, cut.
			return tpl:format(ns.Quests.Title(ids[1])):sub(1, MAX_LEN)
		end
		table.remove(names)
	end
end

-- From a click, a key press or a slash command only. `id`: one quest.
function Announce.Send(id)
	if not ns.Get("enabled") then ns.Print(L.DISABLED) return false end
	if IsInInstance and IsInInstance() then ns.Print(L.INSTANCE) return false end
	local wait = Announce.Cooldown()
	if wait > 0 then ns.Print(L.ANN_COOLDOWN, math.ceil(wait)) return false end
	local text = Announce.Text(Announce.Quests(id), Announce.Lang())
	if not text then ns.Print(L.NO_QUESTS) return false end
	local chatType, target = Announce.Resolve(Announce.Target())
	if not chatType then ns.Print(target) return false end
	local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
	if not (send and pcall(send, text, chatType, nil, target)) then return false end
	last = ns.Now()
	ns.Fire("ANNOUNCED", text, chatType)
	return true
end

function Announce.TargetName(target)
	return L["ANN_TO_" .. target] or target
end

function PSGroupFinder_Announce()
	if ns.db then Announce.Send() end
end
