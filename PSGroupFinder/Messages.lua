-- Group Finder for Polestar (PSGroupFinder): the messages the finder can say for you, each
-- an editable text; an empty text is never sent.
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
--   invite   whispered when you click Invite on a player (solo)
--   ask      whispered when you click Ask on a player already in a group
--            (you cannot invite them: you ask them to invite you)
--   hello    said in the party when a group formed through the finder is
--            joined: by the party box after a short countdown (or at once
--            on its button, or the key binding); closing the box cancels it
--   goodbye  said in the party just before leaving a group formed through
--            the finder: the party box's Say goodbye, the panel's Leave
--            button, the key binding
-- In a text, {quests} stands for the quests concerned: the client's quest
-- link when it names the right quest, else the title; in hello, each with
-- your progress. Texts are kept without escape sequences. The default text
-- is stored as "unset" (false) so that it follows the client's language;
-- an empty text ("") turns the message off.

local _, ns = ...
local L = ns.L

local Messages = {}
ns.Messages = Messages

local MAX_LEN = 255
local MAX_QUESTS = 3

-- kind -> { setting holding the text, locale key of the default, add progress }
Messages.KINDS = {
	invite = { text = "inviteMsg", default = "MSG_INVITE_DEFAULT" },
	ask = { text = "askMsg", default = "MSG_ASK_DEFAULT" },
	hello = { text = "helloMsg", default = "MSG_HELLO_DEFAULT", progress = true },
	goodbye = { text = "leaveMsg", default = "LEAVE_MSG_DEFAULT" },
}
Messages.ORDER = { "invite", "ask", "hello", "goodbye" }

function Messages.Default(kind)
	return L[Messages.KINDS[kind].default]
end

-- The text to use: the player's own ("" when turned off), else the default
-- of the client's language.
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
	return " (" .. (pct >= 100 and L.PROGRESS_DONE_SHORT or (pct .. "%")) .. ")"
end

-- `kind`'s text with {quests} filled from `ids`, at most 255 bytes (quests
-- dropped from the end until it fits). hello adds each quest's progress,
-- "(40%)". "" when the message is turned off.
function Messages.Expand(kind, ids)
	local tpl = Messages.Template(kind)
	if tpl == "" then return "" end
	local withProgress = Messages.KINDS[kind].progress
	local names = {}
	for i = 1, math.min(#(ids or {}), MAX_QUESTS) do
		local id = ids[i]
		names[i] = Messages.QuestText(id) .. (withProgress and progress(id) or "")
	end
	while true do
		local list = #names > 0 and table.concat(names, ", ") or L.MSG_NO_QUEST
		local text = tpl:gsub("{quests}", function() return list end)
		if #text <= MAX_LEN or #names <= 1 then return text:sub(1, MAX_LEN) end
		table.remove(names)
	end
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
