-- Two simulated clients exchanging PSGroupFinder messages, with a
-- stub of the WoW API. Run: lua5.1 tests/sim.lua (from the repo root).
local FILES = { "Locales", "Core", "Lang", "Throttle", "Quests", "Session", "Comm", "Matcher", "Group", "UI", "Polestar" }
local DIR = "PSGroupFinder/"
local bus = {}      -- every client's env
local now = 0
local timers = {}
local party = {}   -- client name -> shared { members... } (first = leader)

local function newClient(name, quests, opts)
	opts = opts or {}
	local env = setmetatable({}, { __index = _G })
	env._G = env
	local frames = {}
	local printed = {}
	env.printed = printed
	env.GetLocale = function() return opts.locale or "frFR" end
	env.GetTime = function() return now end
	env.C_Timer = { After = function(s, fn) timers[#timers + 1] = { at = now + s, fn = fn } end }
	env.UISpecialFrames = {}
	env.SlashCmdList = {}
	env.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
	env.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) printed[#printed + 1] = m end }
	env.GameTooltip = setmetatable({}, { __index = function() return function() end end })
	local function frameStub()
		local f = {}
		return setmetatable(f, { __index = function(t, k)
			if k == "IsShown" then return function() return t._shown end end
			if k == "Show" then return function() t._shown = true end end
			if k == "Hide" then return function() t._shown = false end end
			if k == "GetChecked" then return function() return false end end
			if k == "GetStringWidth" or k == "GetWidth" then return function() return 100 end end
			if k == "GetFrameLevel" then return function() return t._level or 1 end end
			if k == "SetFrameLevel" then return function(_, n) t._level = n end end
			if k == "GetNumChildren" then return function() return #(t._kids or {}) end end
			if k == "GetChildren" then return function() return unpack(t._kids or {}) end end
			if k == "SetParent" then return function(_, par) t._parent = par end end
			if k == "SetPoint" then return function(_, point, rel, relPoint, x, y)
				t._point, t._rel, t._relPoint, t._x, t._y = point, rel, relPoint, x, y
			end end
			if k == "GetPoint" then return function() return t._point or "CENTER", t._rel, t._relPoint, t._x or 0, t._y or 0 end end
			if k == "IsMovable" then return function() return true end end
			if k == "CreateTexture" then return function() return frameStub() end end
			if k == "SetColorTexture" or k == "SetVertexColor" or k == "SetTexture" then return function() end end
			if k == "RegisterForClicks" then return function() end end
			if k == "CreateFontString" or k == "CreateTexture" then return function() return frameStub() end end
			if k == "SetScript" then return function(_, ev, fn) t["_" .. ev] = fn end end
			if k == "RegisterEvent" then return function(_, ev) frames[#frames + 1] = { t, ev } end end
			return function() end
		end })
	end
	env.CreateFrame = function() return frameStub() end
	env.UIParent = frameStub()
	env.C_ChatInfo = {
		RegisterAddonMessagePrefix = function() return true end,
		SendAddonMessage = function(prefix, text, chatType, target)
			if opts.blocked and opts.blocked[chatType] then return 7 end
			for _, other in ipairs(bus) do
				local deliver
				if chatType == "WHISPER" then deliver = other.me == target
				elseif chatType == "GUILD" then deliver = other.guild and other.guild == env.guild
				else deliver = not (other.blocked and other.blocked[chatType]) end
				if deliver then
					timers[#timers + 1] = { at = now + 0.1, fn = function() other.fire("CHAT_MSG_ADDON", prefix, text, chatType, name) end }
				end
			end
			return 0
		end,
	}
	env.Enum = { SendAddonMessageResult = { Success = 0 } }
	env.GetChannelName = function() return env.joined and 5 or 0 end
	env.JoinTemporaryChannel = function() env.joined = true end
	env.LeaveChannelByName = function() env.joined = false end
	env.IsInGuild = function() return env.guild ~= nil end
	env.IsInInstance = function() return false end
	env.UnitLevel = function() return 20 end
	env.UnitClass = function() return "Guerrier", opts.class or "WARRIOR" end
	env.GetNumGroupMembers = function() local p = party[name] return p and #p or 0 end
	env.IsInGroup = function() return party[name] ~= nil end
	env.UnitIsGroupLeader = function() local p = party[name] return p ~= nil and p[1] == name end
	env.UnitInParty = function(n)
		local p = party[name]
		if not p then return false end
		for _, m in ipairs(p) do if m == n then return true end end
		return false
	end
	env.UnitFactionGroup = function() return opts.faction or "Alliance" end
	env.invited = {}
	env.popupShown = false
	env.StaticPopup_Hide = function() env.popupShown = false end
	env.StaticPopup_Visible = function() return env.popupShown and "x" or nil end
	env.AcceptGroup = function()
		if opts.noAccept or env.refuseAccept then return end -- the client refuses (hardware event needed)
		local inviter = env.pendingInviter
		if not inviter then return end
		local p = party[inviter] or { inviter }
		party[inviter] = p
		p[#p + 1] = name
		party[name] = p
		env.pendingInviter = nil
	end
	env.C_PartyInfo = { InviteUnit = function(target)
		env.invited[#env.invited + 1] = target
		for _, other in ipairs(bus) do
			if other.me == target then
				timers[#timers + 1] = { at = now + 0.2, fn = function()
					other.pendingInviter = name
					other.popupShown = true
					other.fire("PARTY_INVITE_REQUEST", name)
				end }
			end
		end
	end, CanInvite = function() local p = party[name] return p == nil or p[1] == name end }
	env.C_Map = {
		GetBestMapForUnit = function() return opts.map or 1436 end,
		GetPlayerMapPosition = function() return { GetXY = function() return opts.x or 0.5, opts.y or 0.5 end } end,
		GetWorldPosFromMapPos = function(map, v) return 0, { GetXY = function() return v.x * 1000 + map, v.y * 1000 end } end,
	}
	env.CreateVector2D = function(x, y) return { x = x, y = y } end
	env.GetNumQuestLogEntries = function() return #quests end
	env.GetQuestLogTitle = function(i) local q = quests[i] return q.title, 20, q.group or 0, false, false, q.complete and 1 or nil, 0, q.id end
	env.GetNumQuestLeaderBoards = function(i) return #(quests[i].obj or {}) end
	env.GetQuestLogLeaderBoard = function(j, i) local o = quests[i].obj[j] return o[1], o[2], o[3] or false end
	env.QuestLogUpdate = function() env.fire("QUEST_LOG_UPDATE") end
	env.Polestar = opts.polestar
	env.quests = quests
	env.me = name
	env.guild = opts.guild
	env.blocked = opts.blocked
	local ns = {}
	for _, f in ipairs(FILES) do
		local chunk = assert(loadfile(DIR .. f .. ".lua"))
		setfenv(chunk, env)
		chunk("PSGroupFinder", ns)
	end
	env.fire = function(ev, ...)
		for _, fr in ipairs(frames) do
			if fr[2] == ev and fr[1]._OnEvent then fr[1]._OnEvent(fr[1], ev, ...) end
		end
	end
	env.ns = ns
	bus[#bus + 1] = env
	env.fire("ADDON_LOADED", "PSGroupFinder")
	env.fire("PLAYER_LOGIN")
	return env
end

local function run(seconds)
	local stop = now + seconds
	while true do
		table.sort(timers, function(a, b) return a.at < b.at end)
		local t = timers[1]
		if not t or t.at > stop then break end
		table.remove(timers, 1)
		now = t.at
		t.fn()
	end
	now = stop
end

local function check(cond, msg) if not cond then error("FAIL: " .. msg, 2) end print("ok  " .. msg) end

-- Ana: Hogger (named kill) + boars (kill). Ben: Hogger too, on the same map.
-- Cid: unrelated quest. Ana's client refuses CHANNEL (like Forever's launch build).
local hogger = { id = 176, title = "Wanted: Hogger", obj = { { "Hogger slain: 0/1", "monster" } } }
local boars = { id = 86, title = "Pie for Billy", obj = { { "Chunk of Boar Meat: 2/4", "item" } } }
local other = { id = 999, title = "Report to Goldshire", obj = {} }
local ana = newClient("Ana Smith", { hogger, boars }, { x = 0.40, y = 0.50, blocked = { CHANNEL = true } })
local ben = newClient("Ben Stone", { hogger }, { x = 0.42, y = 0.51, class = "PRIEST" })
local cid = newClient("Cid Vale", { other }, {})

-- Off by default: nothing is sent.
check(ana.ns.db.enabled == false, "disabled by default")
check(ana.ns.Lang.DefaultCode() == "f" and ana.ns.Lang.Search()[1] == "f" and not ana.ns.Lang.AcceptsAll(),
	"default languages: the client's only (frFR -> FR), not all languages")
check(ana.ns.Lang.Encode() == "f", "language payload is the client letter (f)")
check(ana.ns.Get("headerButton") == true, "header button is on by default")
ana.PSGroupFinder_Search()
run(1)
check(next(ana.ns.Comm.status) == nil, "a search while disabled sends nothing")

for _, c in ipairs({ ana, ben, cid }) do c.ns.SetEnabled(true) end
run(15) -- join delay, then the quiet probe
check(ben.ns.Comm.status.CHANNEL.state == "ok", "Ben: CHANNEL echo detected")
check(ana.ns.Comm.status.CHANNEL.state == "fail" and ana.ns.Comm.status.CHANNEL.code == "InvalidChannel", "Ana: CHANNEL refused, reported as InvalidChannel")

local rel = ana.ns.Quests.Relevant()
check(#rel == 2 and rel[1].id == 176 and rel[1].kind == "n" and rel[2].kind == "l", "Ana's relevant quests: Hogger (named) then boar meat (loot)")

ana.ns.Comm.TestChannels(true) -- from a click: SAY/YELL too
run(6)
check(ana.ns.Comm.status.YELL.state == "ok", "Ana: YELL works as fallback")
check(ana.ns.Comm.BestChannel() == "YELL", "Ana's best channel is YELL")

ana.PSGroupFinder_Search()
run(5)
local list = ana.ns.Matcher.List()
check(#list == 1 and list[1].name == "Ben Stone" and list[1].quests[1] == 176, "Ana finds Ben on Hogger (Ben's whisper reply)")
check(list[1].yards and list[1].yards < 40, "distance computed in yards: " .. tostring(list[1].yards))
check(#ben.ns.Matcher.List() == 1, "Ben sees Ana as also looking")
check(#cid.ns.Matcher.List() == 0, "Cid (no shared quest) sees nobody and answers nothing")

ana.PSGroupFinder_Search()
check(ana.printed[#ana.printed]:find("Attendez"), "search cooldown enforced")

-- The panel builds and refreshes with a session and a player found (stub frames).
ana.ns.UI.Show()
ana.ns.UI.Refresh()
check(ana.ns.UI.IsShown(), "panel builds and refreshes with a search and a player found")

-- Message size and decode round trip.
local many = {}
for i = 1, 40 do many[i] = { id = 100000 + i, kind = "k" } end
local text, n = ana.ns.Comm.EncodeSearch(many)
check(#text <= 255 and n < 40, "search text cut to 255 bytes (" .. #text .. " bytes, " .. n .. " quests)")
local m = ana.ns.Comm.Decode(text)
check(m and m.kind == "S" and #m.quests == n and m.class == "WARRIOR" and m.langs and m.langs.code == "f", "decode round trip (with langs)")
check(ana.ns.Comm.Decode("S|zz|1|2") == nil and ana.ns.Comm.Decode(("x"):rep(300)) == nil, "malformed messages dropped")
local oldS = "S|abc123|1436|400|500|20|WARRIOR|0|gA|176:n,86:l"
local oldm = ana.ns.Comm.Decode(oldS)
check(oldm and oldm.kind == "S" and #oldm.quests == 2 and oldm.langs == nil, "v0.2 messages (no langs field) still decode")
local legacy = ana.ns.Lang.Decode("f/f")
check(legacy and legacy.code == "f" and ana.ns.Lang.Decode("fe/*").code == "f", "legacy spoken/accepted payloads still decode as the client letter")

-- With Polestar: the live step's quest comes first, the panel is themed and
-- the launcher hangs under the guide window.
local handlers, skinned = {}, {}
local window = { HookScript = function() end, IsShown = function() return true end, GetRight = function() return 400 end, GetEffectiveScale = function() return 1 end }
local nav = { GetNumChildren = function() return 0 end, GetChildren = function() end }
nav.Lookup = { GetFrameLevel = function() return 5 end, SetFrameLevel = function() end,
	GetPoint = function() return "RIGHT", nav, "RIGHT", -32, 0 end,
	SetPoint = function() end, Show = function() end, Hide = function() end }
nav.Menu = { GetPoint = function() return "RIGHT", nav, "RIGHT", -8, 0 end, SetPoint = function() end }
local fakePolestar = {
	API = { version = 1 },
	On = function(msg, fn) handlers[msg] = fn end,
	Compat = { IsOnQuest = function(id) return id == 86 end, IsQuestReadyForTurnIn = function() return false end },
	Engine = { GetGuide = function() return { steps = { { goals = { { t = "loot", quest = 86 } } } } } end, GetLiveStep = function() return 1 end },
	Theme = { Skin = function(f, kind) skinned[#skinned + 1] = kind return f end, Font = function() end,
		OnChanged = function() end, HasCapability = function(c) return c == "guideParts" or c == "guideReach" or c == "theme.functions" end,
		Color = function() return 0.85, 0.88, 0.95, 1 end,
		Media = function(name) return name == "white" and "Interface\\Buttons\\WHITE8X8" or name end,
		GuideParts = function() return { window = window, nav = nav } end },
}
local dee = newClient("Dee Moss", { hogger, boars }, { polestar = fakePolestar })
local rel2 = dee.ns.Quests.Relevant()
check(rel2[1].id == 86 and rel2[1].step == true, "Polestar live step quest first (" .. rel2[1].id .. ")")
check(handlers.STEP_CHANGED ~= nil and handlers.GUIDE_CHANGED ~= nil, "subscribed to Polestar STEP_CHANGED / GUIDE_CHANGED")
local hasButton = false
for _, k in ipairs(skinned) do if k == "button" then hasButton = true end end
check(hasButton, "launcher button painted through Polestar.Theme.Skin")
check(dee.ns.headerButtonFrame ~= nil, "header icon created on the step bar (left of Lookup)")
local _, headerRel = dee.ns.headerButtonFrame:GetPoint(1)
check(headerRel == nav.Lookup, "header icon is anchored to Lookup (the magnifying glass)")
fakePolestar.Engine.GetGuide = function() error("internal API moved") end
handlers.STEP_CHANGED()
check(#dee.ns.Quests.Relevant() == 2, "Engine failure falls back to the quest log")


---------------------------------------------------------------------------
-- v0.2: a search is a session, objectives leave it, auto-group
---------------------------------------------------------------------------
local function collect(c) local t = {} for _, q in ipairs(c.ns.Session.List()) do t[#t + 1] = q.id end return t end

-- Eve: three quests (A kill, B kill, C loot); Finn: A and B; Gus: B only.
local qa = { id = 5001, title = "Kobold Camp Cleanup", obj = { { "Kobold Vermin slain: 3/10", "monster" } } }
local qb = { id = 5002, title = "Wolves Across the Border", obj = { { "Tough Wolf Meat: 1/8", "item" } } }
local qc = { id = 5003, title = "Investigate the Camp", obj = { { "Searched: 0/1", "monster" } } }
local function copyQ(q) return { id = q.id, title = q.title, obj = { { q.obj[1][1], q.obj[1][2] } } } end
local eve = newClient("Eve Dawn", { copyQ(qa), copyQ(qb), copyQ(qc) }, { x = 0.30, y = 0.30 })
local finn = newClient("Finn Roe", { copyQ(qa), copyQ(qb) }, { x = 0.31, y = 0.30, class = "MAGE" })
local gus = newClient("Gus Hale", { copyQ(qb) }, { x = 0.32, y = 0.30, class = "ROGUE" })
for _, c in ipairs({ eve, finn, gus }) do c.ns.SetEnabled(true) end
run(15)
eve.ns.Comm.TestChannels(true) run(6)
check(not eve.ns.Session.Active(), "no session before a search")
run(30)
eve.PSGroupFinder_Search()
run(5)
check(eve.ns.Session.Active() and #collect(eve) == 3, "a search opens a session on its 3 quests")
check(#eve.ns.Matcher.List() == 2, "Eve found Finn and Gus")
local function peerQuests(c, who) local e = c.ns.Matcher.Get(who) return e and #e.quests or 0 end
check(peerQuests(eve, "Finn Roe") == 2 and peerQuests(eve, "Gus Hale") == 1, "Finn shares 2 quests with Eve, Gus 1")

-- Objective A done on Eve: removed from the session, Finn's entry shrinks.
eve.quests[1].obj[1][3] = true
eve.QuestLogUpdate()
run(0.5)
check(#collect(eve) == 3, "no pruning before the 1 s debounce")
run(3)
local left = collect(eve)
table.sort(left)
check(#left == 2 and left[1] == 5002 and left[2] == 5003, "quest A removed from the search, B and C stay")
check(eve.printed[#eve.printed - 1]:find("Objectif terminé") ~= nil, "the player is told (objective done)")
check(peerQuests(finn, "Eve Dawn") == 1, "Finn's list of Eve updated to the quests left (B only)")
check(peerQuests(gus, "Eve Dawn") == 1, "Gus still shares B with Eve")

-- Objective B done on Eve (item turned ready): Finn and Gus no longer match.
eve.quests[2].complete = true
eve.QuestLogUpdate()
run(3)
check(#collect(eve) == 1 and collect(eve)[1] == 5003, "quest B removed, only C left")
check(finn.ns.Matcher.Get("Eve Dawn") == nil and gus.ns.Matcher.Get("Eve Dawn") == nil, "players with no quest in common drop Eve")
check(eve.ns.Matcher.Get("Gus Hale") == nil, "Eve's list drops Gus (B is no longer searched)")

-- Last objective: the search ends and X goes out.
eve.quests[3].obj[1][3] = true
eve.QuestLogUpdate()
run(3)
check(not eve.ns.Session.Active(), "last quest done: search stopped")
check(eve.printed[#eve.printed]:find("Tous les objectifs") ~= nil, "the player is told the search is over")

-- Auto group.
local function mk(name, opts, quests)
	local c = newClient(name, quests, opts)
	c.ns.SetEnabled(true)
	return c
end
local function q1() return { copyQ({ id = 6001, title = "Mine Pest Control", obj = { { "Pest slain: 0/6", "monster" } } }) } end
local hal = mk("Hal Orn", { x = 0.60, y = 0.60 }, q1())
local ivy = mk("Ivy Kerr", { x = 0.61, y = 0.60, class = "PRIEST" }, q1())
local jon = mk("Jon Pike", { x = 0.62, y = 0.60, faction = "Horde" }, q1())
run(15)
hal.ns.Comm.TestChannels(true) run(6)
run(30)
-- Option off (default): nothing automatic.
check(hal.ns.Get("autoGroup") == false, "autoGroup is off by default")
hal.PSGroupFinder_Search()
run(8)
check(#hal.invited == 0 and #ivy.invited == 0 and party["Hal Orn"] == nil, "autoGroup off: nobody invited, nobody grouped")
check(#hal.ns.Matcher.List() >= 1, "players still listed for manual Invite")
for _, c in ipairs({ hal, ivy, jon }) do c.ns.Matcher.Clear() c.ns.Session.Stop("x") end

-- Both on: after Hal's search, a group forms with no click on Invite.
hal.ns.Set("autoGroup", true) ivy.ns.Set("autoGroup", true) jon.ns.Set("autoGroup", true)
run(30)
hal.PSGroupFinder_Search()
run(10)
check(party["Hal Orn"] ~= nil and party["Ivy Kerr"] == party["Hal Orn"], "autoGroup on: Hal and Ivy are grouped without a click")
check(party["Jon Pike"] == nil and #hal.invited + #ivy.invited <= 2, "the other faction (Horde) is never invited")
local inviterName = party["Hal Orn"][1]
check(#(inviterName == "Hal Orn" and hal or ivy).invited == 1, "exactly one side invited: the deterministic one (" .. inviterName .. ")")

-- A stranger's invite is not accepted.
local kay = mk("Kay Lund", {}, { copyQ({ id = 7001, title = "Other", obj = { { "x: 0/1", "monster" } } }) })
kay.ns.Set("autoGroup", true)
run(5)
kay.pendingInviter = "Zed Rook"
kay.popupShown = true
kay.fire("PARTY_INVITE_REQUEST", "Zed Rook")
check(party["Kay Lund"] == nil and kay.popupShown, "an invitation from someone unexpected is left to the player")

-- Client refuses AcceptGroup: the player is told to accept by hand.
local lou = mk("Lou Vance", { x = 0.7, y = 0.7 }, { copyQ({ id = 8001, title = "Boar Hunt", obj = { { "Boar slain: 0/8", "monster" } } }) })
local max = mk("Max Teal", { x = 0.71, y = 0.7 }, { copyQ({ id = 8001, title = "Boar Hunt", obj = { { "Boar slain: 0/8", "monster" } } }) })
lou.ns.Set("autoGroup", true) max.ns.Set("autoGroup", true)
-- The one with the higher sid is the one invited: its client refuses AcceptGroup.
local invitee, inviter = lou, max
if lou.ns.Comm.sid < max.ns.Comm.sid then invitee, inviter = max, lou end
invitee.refuseAccept = true
run(30)
inviter.PSGroupFinder_Search()
run(10)
local told = false
for _, p in ipairs(invitee.printed) do if p:find("à la main") then told = true end end
check(party["Lou Vance"] == nil and party["Max Teal"] == nil and told, "AcceptGroup refused by the client: popup stays, the player is told to click")

-- A full party ends the search (5 members).
party["Hal Orn"] = { "Hal Orn", "a", "b", "c", "d" }
hal.fire("GROUP_ROSTER_UPDATE")
check(not hal.ns.Session.Active(), "party of 5: search stopped")

---------------------------------------------------------------------------
-- v1: search languages (default = the client's only; All is opt-in;
-- filtering is unilateral; the payload is the client letter only)
---------------------------------------------------------------------------
local function langClient(name, locale, opts, quests)
	opts = opts or {}
	opts.locale = locale
	local c = newClient(name, quests or { copyQ({ id = 9001, title = "Pest Control", obj = { { "Pest slain: 0/6", "monster" } } }) }, opts)
	c.ns.SetEnabled(true)
	return c
end
local pia = langClient("Pia Lang", "frFR", { x = 0.2, y = 0.2 })
local ned = langClient("Ned Lang", "enUS", { x = 0.21, y = 0.2, class = "MAGE" })
local mia = langClient("Mia Lang", "frFR", { x = 0.22, y = 0.2, class = "PRIEST" })
run(15)
pia.ns.Comm.TestChannels(true) run(6)
run(30)
check(ned.ns.Lang.DefaultCode() == "e" and ned.ns.Lang.Encode() == "e" and ned.ns.Lang.Search()[1] == "e", "an English client defaults to EN only")
check(not pia.ns.Lang.Compatible(ned.ns.Lang.Decode(ned.ns.Lang.Encode())), "FR search does not list an EN client")
check(pia.ns.Lang.Compatible(mia.ns.Lang.Decode(mia.ns.Lang.Encode())), "two FR-only players are compatible")
pia.PSGroupFinder_Search()
run(8)
local function hasPeer(c, who) return c.ns.Matcher.Get(who) ~= nil end
check(not hasPeer(pia, "Ned Lang") and hasPeer(pia, "Mia Lang"), "Pia (FR) finds Mia (FR) and not Ned (EN)")
pia.ns.Lang.SetAcceptAll(true)
check(pia.ns.Lang.Encode() == "f" and pia.ns.Lang.MineSummary() == "Toutes", "accept-all still broadcasts only the client letter")
check(pia.ns.Lang.Compatible(ned.ns.Lang.Decode(ned.ns.Lang.Encode())), "Pia with All lists Ned (unilateral)")
check(not ned.ns.Lang.Compatible(pia.ns.Lang.Decode(pia.ns.Lang.Encode())), "Ned (EN only) still does not list Pia: each side filters alone")
pia.ns.Lang.SetAcceptAll(false)
pia.ns.Lang.SetSearch("e", true)
check(pia.ns.Lang.Encode() == "f" and pia.ns.Lang.MineSummary() == "FR/EN", "adding EN to the search does not change the payload")
check(pia.ns.Lang.Compatible(ned.ns.Lang.Decode("e")) and not ned.ns.Lang.Compatible(pia.ns.Lang.Decode("f")),
	"Pia searching FR+EN lists Ned; Ned still searching EN only does not list Pia")
check(pia.ns.Lang.Summary({ code = "f" }) == "FR", "list label is the peer's client language")
pia.ns.Lang.SetSearch("e", false)
check(not pia.ns.Lang.Compatible(nil), "a v0.2 peer with no language is hidden when we don't accept all")
pia.ns.Lang.SetAcceptAll(true)
check(pia.ns.Lang.Compatible(nil), "a v0.2 peer is visible when we accept all")

ana.ns.SetEnabled(false)
check(#ana.ns.Matcher.List() == 0 and ana.joined == false, "turning off clears the list and leaves the channel")
print("all tests passed")
