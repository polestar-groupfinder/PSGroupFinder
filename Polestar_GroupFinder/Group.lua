-- Polestar Group Finder: grouping without a click (option `autoGroup`, off
-- by default).
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
-- What the game lets an addon do here, and what this relies on:
--   * InviteUnit (C_PartyInfo.InviteUnit) may be called from an event
--     handler: no hardware event is needed (the Forever auto-inviter addons
--     do it). Only the group leader (or a solo player) may invite, a party
--     holds 5, and both players must be of the same faction.
--   * AcceptGroup on PARTY_INVITE_REQUEST (then StaticPopup_Hide("PARTY_INVITE"),
--     once grouped) accepts an invitation with no click. Documented for Classic; on Forever
--     this is the one call to confirm in game. If the client refuses, the
--     popup stays and a chat line says so: the player clicks Accept.
--   * SAY / YELL need a hardware event, so nothing here relies on them.
--
-- Who invites? Both players know both session ids (sid, in every message).
--   - The one already grouped (and leader, with room) invites the solo one.
--   - Two solo players: the lower sid invites; the other, when it is the one
--     that found the match, whispers "G" so the lower sid's addon invites.
--   - Two groups: nobody (merging groups is not automatic).
-- An invitation is accepted only from a player we expect: one who searched
-- with auto-group on and we answered (or asked with G), and only while the
-- option is on. Nothing is ever accepted from a stranger.

local _, ns = ...
local L = ns.L
local Throttle = ns.Throttle

local Group = {}
ns.Group = Group

local MAX_PARTY = 5
local EXPECT_TTL = 180   -- seconds an expected invitation stays valid
local RETRY_GAP = 90     -- seconds before we invite / ask the same player again
local expect = {}        -- key -> expiry time
local tried = {}         -- key -> time of our last invite / ask
local pending = {}       -- key -> name: invited / asked, not yet grouped

local function key(name)
	return (Ambiguate and Ambiguate(name, "none") or name):lower()
end

local function partySize()
	local n = (GetNumGroupMembers and GetNumGroupMembers()) or 0
	if n == 0 and IsInGroup and IsInGroup() then n = 1 end
	return n
end

local function canInvite()
	if partySize() == 0 then return true end
	if C_PartyInfo and C_PartyInfo.CanInvite then
		local ok, r = pcall(C_PartyInfo.CanInvite)
		if ok then return r and true or false end
	end
	return UnitIsGroupLeader and UnitIsGroupLeader("player") and true or false
end

function Group.Expect(name)
	expect[key(name)] = ns.Now() + EXPECT_TTL
end

local function expected(name)
	local t = expect[key(name)]
	return t ~= nil and t > ns.Now()
end

local function state(e, s)
	e.state = s
	ns.Fire("PEERS")
end

local function invite(e)
	local fn = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
	if not fn then return end
	local k = key(e.name)
	tried[k] = ns.Now()
	pending[k] = e.name
	pcall(fn, e.name)
	state(e, "invited")
	ns.Print(L.AUTO_INVITED, Ambiguate and Ambiguate(e.name, "none") or e.name)
end

local function ask(e)
	local k = key(e.name)
	tried[k] = ns.Now()
	pending[k] = e.name
	Group.Expect(e.name)
	local ids = {}
	for _, id in ipairs(e.quests) do ids[#ids + 1] = id end
	Throttle.Send(ns.Comm.PREFIX, ns.Comm.EncodeGroupRequest(ids), "WHISPER", e.name)
	state(e, "asked")
	ns.Print(L.AUTO_ASKED, Ambiguate and Ambiguate(e.name, "none") or e.name)
end

-- Who acts for the pair (me, e): "me" invites, "peer" is asked to, nil: nobody.
function Group.Decide(e)
	local mine, theirs = partySize(), e.size or 0
	if mine + math.max(theirs, 1) > MAX_PARTY then return nil end
	if mine > 0 and theirs > 0 then return nil end
	if mine > 0 then return canInvite() and "me" or nil end
	if theirs > 0 then return "peer" end
	return (ns.Comm.sid < (e.sid or "")) and "me" or "peer"
end

-- A player was found while we search: invite them, or have them invite us.
function Group.Consider(e)
	if not (ns.Session.Active() and ns.Get("autoGroup") and e.autoGroup) then return end
	if IsInInstance and IsInInstance() then return end
	if ns.Matcher.InGroup(e.name) then return end
	local k = key(e.name)
	if tried[k] and ns.Now() - tried[k] < RETRY_GAP then return end
	local who = Group.Decide(e)
	if who == "me" then invite(e) elseif who == "peer" then ask(e) end
end

-- "G": a player we replied to (or found) asks us to invite them.
function Group.OnRequest(sender, m)
	if not (ns.Get("autoGroup") and ns.Get("enabled")) then return end
	if IsInInstance and IsInInstance() then return end
	local e = ns.Matcher.Get(sender)
	if not (e and e.autoGroup) then return end
	if not (ns.Session.Active() or expected(sender)) then return end
	if ns.Matcher.InGroup(sender) then return end
	local k = key(sender)
	if tried[k] and ns.Now() - tried[k] < RETRY_GAP then return end
	if partySize() + 1 > MAX_PARTY or not canInvite() then return end
	invite(e)
end

local function onInviteRequest(_, inviter)
	inviter = ns.Readable(inviter)
	if type(inviter) ~= "string" then return end
	if not (ns.Get("enabled") and ns.Get("autoGroup") and expected(inviter)) then return end
	if IsInInstance and IsInInstance() then return end
	if partySize() > 0 then return end -- already grouped: leave that choice to the player
	local accept = AcceptGroup or (C_PartyInfo and C_PartyInfo.ConfirmInviteUnit)
	if accept then pcall(accept) end
	-- The popup is closed only once we are in the group, so that a client
	-- that refused AcceptGroup leaves it up for the player to click.
	ns.After(1.5, function()
		if partySize() > 0 then
			if StaticPopup_Hide then pcall(StaticPopup_Hide, "PARTY_INVITE") end
		elseif StaticPopup_Visible and StaticPopup_Visible("PARTY_INVITE") then
			ns.Print(L.AUTO_CLICK, Ambiguate and Ambiguate(inviter, "none") or inviter)
		end
	end)
end
ns.RegisterEvent("PARTY_INVITE_REQUEST", onInviteRequest)

ns.RegisterEvent("GROUP_ROSTER_UPDATE", function()
	for k, name in pairs(pending) do
		if ns.Matcher.InGroup(name) then
			pending[k] = nil
			ns.Print(L.AUTO_JOINED, Ambiguate and Ambiguate(name, "none") or name)
		end
	end
	-- A full party ends the search.
	if ns.Session.Active() and partySize() >= MAX_PARTY then
		ns.Print(L.SESSION_FULL)
		ns.Comm.Stop()
		ns.Session.Stop("full")
	end
end)

ns.On("SESSION", function()
	if not ns.Session.Active() then wipe(pending) end
end)
ns.On("ENABLED", function(on) if not on then wipe(expect) wipe(tried) wipe(pending) end end)
