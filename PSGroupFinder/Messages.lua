-- Group Finder for Polestar (PSGroupFinder): the messages the finder can say for you, each
-- an editable text; an empty text is never sent.
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
--   announce said in public chat (General by default) on the Announce click
--   invite   whispered when you click Invite on a player (solo)
--   ask      whispered when you click Ask on a player already in a group
--            (you cannot invite them: you ask them to invite you)
--   hello    said in the party from the party box's Say hello button (or its
--            key binding), offered for a few seconds when a group formed
--            through the finder gets together
--   goodbye  said in the party just before leaving a group formed through
--            the finder: the party box's Goodbye & leave, the panel's Leave
--            button, the key binding
-- The defaults are in English for every client (the other players may read
-- any language); the player edits them freely. In a text:
--   {quests}   the quests concerned, as the client's quest links when they
--              name the right quest, else their titles
--   {progress} the same quests, each followed by your progress ("(40%)",
--              "(done)") when the log has it
-- Texts are kept without escape sequences. The default text is stored as
-- "unset" (false); an empty text ("") turns the message off.

local _, ns = ...
local L = ns.L

local Messages = {}
ns.Messages = Messages

local MAX_LEN = 255
local MAX_QUESTS = 3

-- kind -> { setting holding the text, default text }
Messages.KINDS = {
	announce = { text = "announceMsg", default = "LFG {quests}, whisper me!" },
	invite = { text = "inviteMsg", default = "Hi! I'm on {quests} too, I've sent you an invite." },
	ask = { text = "askMsg", default = "Hi! I'm on {quests} too, could you invite me to your group?" },
	hello = { text = "helloMsg", default = "Hi all! I'm on {progress}." },
	goodbye = { text = "leaveMsg", default = "Thanks for the group, have fun!" },
}
Messages.ORDER = { "announce", "invite", "ask", "hello", "goodbye" }

function Messages.Default(kind)
	return Messages.KINDS[kind].default
end

-- The text to use: the player's own ("" when turned off), else the default.
function Messages.Template(kind)
	local m = ns.Get(Messages.KINDS[kind].text)
	if type(m) == "string" then return m end
	return Messages.Default(kind)
end

function Messages.Save(kind, text)
	text = tostring(text or ""):gsub("|", ""):gsub("^%s+", ""):gsub("%s+$", "")
	ns.Set(Messages.KINDS[kind].text, text ~= Messages.Default(kind) and text or false)
end

function Messages.On(kind)
	return Messages.Template(kind) ~= ""
end

-- A quest as written in chat: the client's link when it names this quest
-- (some clients take a log index, not an id), else the title.
function Messages.QuestText(id)
	if GetQuestLink then
		local ok, link = pcall(GetQuestLink, id)
		link = ok and ns.Readable(link)
		if type(link) == "string" and link:find("|Hquest:" .. id .. ":", 1, true) then return link end
	end
	return ns.Quests.Title(id)
end

local function progress(id)
	local pct = ns.Quests.Progress(id)
	if not pct then return "" end
	return " (" .. (pct >= 100 and "done" or (pct .. "%")) .. ")"
end

-- The list for {quests} or {progress} from `ids` (at most MAX_QUESTS).
local function list(ids, count, withProgress)
	local names = {}
	for i = 1, math.min(#(ids or {}), count) do
		names[i] = Messages.QuestText(ids[i]) .. (withProgress and progress(ids[i]) or "")
	end
	return #names > 0 and table.concat(names, ", ") or L.MSG_NO_QUEST
end

-- `kind`'s text with {quests} and {progress} filled from `ids`, at most 255
-- bytes (quests dropped from the end until it fits). "" when the message is
-- turned off.
function Messages.Expand(kind, ids)
	return Messages.Fill(Messages.Template(kind), ids)
end

-- Any text `tpl` with {quests} and {progress} filled (the live preview).
function Messages.Fill(tpl, ids)
	tpl = tostring(tpl or ""):gsub("|", "")
	if tpl == "" then return "" end
	for count = math.min(#(ids or {}), MAX_QUESTS), 0, -1 do
		local text = tpl:gsub("{quests}", function() return list(ids, math.max(count, 1), false) end)
		text = text:gsub("{progress}", function() return list(ids, math.max(count, 1), true) end)
		if #text <= MAX_LEN or count <= 1 then return text:sub(1, MAX_LEN) end
	end
	return tpl:sub(1, MAX_LEN)
end

-- PARTY, or INSTANCE_CHAT in an instance group.
function Messages.PartyChat()
	local instance = IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
	return instance and "INSTANCE_CHAT" or "PARTY"
end

local function send(text, chatType, target)
	local fn = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
	if not (fn and type(text) == "string" and text ~= "") then return false end
	return pcall(fn, text, chatType, nil, target) and true or false
end

function Messages.Whisper(kind, name, ids)
	if not Messages.On(kind) then return false end
	return send(Messages.Expand(kind, ids), "WHISPER", name)
end

function Messages.SayParty(kind, ids)
	if not (IsInGroup and IsInGroup()) or not Messages.On(kind) then return false end
	return send(Messages.Expand(kind, ids), Messages.PartyChat())
end
