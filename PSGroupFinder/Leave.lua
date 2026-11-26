-- Group Finder for Polestar (PSGroupFinder): offering to leave a group once its quests are done.
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
-- Only for a group formed through the finder: you invited a player found by
-- it (the Invite button, or auto-group), or you accepted the invitation of a
-- player it had found. The quest ids you shared at that moment (and that are
-- in your log) are remembered, per character, until the group ends. When
-- none of them has anything left to do (objectives complete, ready to hand
-- in, or handed in) a window asks "Leave / Stay" (UI.ShowLeave).
--
-- Nothing here leaves, speaks or invites by itself. The /p message (opt-in,
-- editable) is sent just before LeaveParty, from Leave.Do (our buttons) and
-- from a pre-hook of LeaveParty / C_PartyInfo.LeaveParty (the game's own
-- leave: portrait menu, /leave, /quit-party). The player always triggers
-- the leave. A guard prevents a double message when our button calls
-- LeaveParty. By default the message is only for a group formed through
-- the finder; leaveMsgAny (off) also covers a group joined by hand.

local _, ns = ...
local L = ns.L

local Leave = {}
ns.Leave = Leave

local WINDOW = 300       -- seconds an invitation stays linked to the group it makes
local READY_AFTER = 8    -- seconds after login before the log counts as read
local CHECK_DELAY = 1.5  -- seconds after the last log update before checking
local outgoing = {}      -- key -> { name, quests, at }
local incoming           -- { name, quests, at }
local ready = false
local token = 0
local waitingCombat = false

local key = ns.NameKey

local function inGroup()
	return (IsInGroup and IsInGroup()) and true or false
end

local function memory()
	return ns.char and ns.char.party or nil
end

local function inParty(name)
	local ok, r = pcall(function() return ns.Matcher.InGroup(name) end)
	return ok and r
end

-- The text to say: the player's own, else the default of the client's language.
function Leave.Message()
	local m = ns.Get("leaveMsg")
	if type(m) == "string" and m:match("%S") then return m end
	return L.LEAVE_MSG_DEFAULT
end

-- Remembers `ids` (the ones in the log) as the reason for the current group.
local function merge(ids)
	if not ns.char then return false end
	local mem = ns.char.party
	local added = false
	for _, id in ipairs(ids or {}) do
		if ns.Quests.Has(id) then
			mem = mem or { quests = {} }
			mem.quests[id] = true
			added = true
		end
	end
	if added then
		mem.dismissed, mem.offered = nil, nil
		mem.at = mem.at or time()
		ns.char.party = mem
		ns.Fire("LEAVE_MEMORY")
	end
	return added
end

-- A player was invited from the finder (Invite button or auto-group).
function Leave.NoteInvite(name, quests)
	if type(name) ~= "string" or not quests then return end
	local ids = {}
	for _, id in ipairs(quests) do ids[#ids + 1] = type(id) == "table" and id.id or id end
	outgoing[key(name)] = { name = name, quests = ids, at = ns.Now() }
end

function Leave.Forget()
	if ns.char then ns.char.party = nil end
	wipe(outgoing)
	incoming = nil
	ns.Fire("LEAVE_MEMORY")
end

local function resolve()
	local now = ns.Now()
	for k, o in pairs(outgoing) do
		if now - o.at > WINDOW then
			outgoing[k] = nil
		elseif inParty(o.name) then
			outgoing[k] = nil
			merge(o.quests)
		end
	end
	if incoming then
		if now - incoming.at > WINDOW then
			incoming = nil
		elseif inParty(incoming.name) then
			local ids = incoming.quests
			incoming = nil
			merge(ids)
		end
	end
end

local function onInvite(_, inviter)
	inviter = ns.Readable(inviter)
	if type(inviter) ~= "string" or not ns.Get("enabled") then return end
	local ids = ns.Matcher.QuestsOf(inviter)
	if #ids == 0 then return end -- not a player the finder found
	incoming = { name = inviter, quests = ids, at = ns.Now() }
end
ns.RegisterEvent("PARTY_INVITE_REQUEST", onInvite)

-- Quests of the memory with nothing left to do; drops abandoned ones.
-- Returns true when there is a memory and every quest in it is done.
function Leave.AllDone()
	local mem = memory()
	if not (mem and mem.quests) then return false end
	local any, open = false, false
	for id in pairs(mem.quests) do
		local state = ns.Quests.State(id)
		if state == "gone" then
			mem.quests[id] = nil
		else
			any = true
			if state == "open" then open = true end
		end
	end
	if not any then
		ns.char.party = nil
		return false
	end
	return not open
end

function Leave.Check()
	local mem = memory()
	if not mem then return end
	if not inGroup() then
		Leave.Forget()
		return
	end
	if not ready or not (ns.Get("enabled") and ns.Get("leaveOffer")) then return end
	if mem.dismissed or mem.offered then return end
	if IsInInstance and IsInInstance() then return end
	if not Leave.AllDone() then return end
	if InCombatLockdown and InCombatLockdown() then
		waitingCombat = true
		return
	end
	mem.offered = true
	if ns.UI and ns.UI.ShowLeave then ns.UI.ShowLeave() end
end

local function schedule()
	token = token + 1
	local mine = token
	ns.After(CHECK_DELAY, function() if mine == token then Leave.Check() end end)
end

ns.RegisterEvent("GROUP_ROSTER_UPDATE", function()
	resolve()
	if not inGroup() and memory() then Leave.Forget() return end
	schedule()
end)
for _, ev in ipairs({ "QUEST_LOG_UPDATE", "QUEST_TURNED_IN", "QUEST_REMOVED", "ZONE_CHANGED_NEW_AREA" }) do
	ns.RegisterEvent(ev, function() if memory() then schedule() end end)
end
ns.RegisterEvent("PLAYER_REGEN_ENABLED", function()
	if waitingCombat then waitingCombat = false schedule() end
end)
ns.On("LOGIN", function() ns.After(READY_AFTER, function() ready = true schedule() end) end)

-- Say the /p message if the option is on and this group is one we may
-- speak for. Safe to call twice in the same leave (pre-hook + Leave.Do).
local announced = false
local function resetAnnounced()
	announced = false
end

function Leave.Announce()
	if announced then return false end
	if not ns.Get("leaveMsgOn") then return false end
	if not inGroup() then return false end
	if not memory() and not ns.Get("leaveMsgAny") then return false end
	local msg = Leave.Message()
	if type(msg) ~= "string" or msg == "" then return false end
	announced = true
	local chat = (IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) and "INSTANCE_CHAT" or "PARTY"
	local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
	if send then pcall(send, msg, chat) end
	-- The game's LeaveParty (or ours) will have us out of the group in a
	-- moment; allow a later, separate leave to speak again.
	ns.After(1, resetAnnounced)
	return true
end

-- Pre-hook, not hooksecurefunc: the message must go out while we are still
-- in the party. Wrapping the API is acceptable because the player is the
-- one leaving (portrait, slash command, or our button).
local hookedLeave = false
local function hookLeaveAPI()
	if hookedLeave then return end
	local function wrap(orig)
		if type(orig) ~= "function" then return orig end
		return function(...)
			pcall(Leave.Announce)
			return orig(...)
		end
	end
	pcall(function()
		if type(LeaveParty) == "function" then
			LeaveParty = wrap(LeaveParty)
			if _G then _G.LeaveParty = LeaveParty end
			hookedLeave = true
		end
	end)
	pcall(function()
		if C_PartyInfo and type(C_PartyInfo.LeaveParty) == "function" then
			C_PartyInfo.LeaveParty = wrap(C_PartyInfo.LeaveParty)
			hookedLeave = true
		end
	end)
end
Leave.HookLeave = hookLeaveAPI

-- "Leave": our button (panel or the quests-done window). The message first
-- (when the option is on), then the party. The pre-hook also runs and is
-- a no-op thanks to `announced`.
function Leave.Do()
	Leave.Announce()
	local leave = (C_PartyInfo and C_PartyInfo.LeaveParty) or LeaveParty
	if leave then pcall(leave) end
	Leave.Forget()
	ns.Print(L.LEAVE_LEFT)
end

-- "Stay": the question is not asked again for this group.
function Leave.Stay()
	local mem = memory()
	if mem then mem.dismissed = true end
	ns.Print(L.LEAVE_STAYED)
end

Leave.IsReady = function() return ready end
-- Tests: skip the post-login wait.
function Leave.SetReady(v) ready = v and true or false end

hookLeaveAPI()
ns.On("LOGIN", hookLeaveAPI)
