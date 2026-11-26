-- Two simulated clients exchanging PSGroupFinder messages, with a
-- stub of the WoW API. Run: lua5.1 tests/sim.lua (from the repo root).
local FILES = { "Locales", "Core", "Lang", "Throttle", "Quests", "Session", "Comm", "Matcher", "Group", "Leave", "UI", "Hooks", "Polestar" }
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
	env.GetLocale = function() return opts.locale or "enUS" end
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
			if k == "IsShown" then return function() return rawget(t, "_shown") and true or false end end
			if k == "Show" then return function() t._shown = true end end
			if k == "Hide" then return function() t._shown = false end end
			if k == "SetShown" then return function(_, v) t._shown = v and true or false end end
			if k == "GetChecked" then return function() return false end end
			if k == "GetStringWidth" then return function() return 100 end end
			if k == "GetWidth" then return function() return rawget(t, "_w") or 100 end end
			if k == "GetHeight" then return function() return rawget(t, "_h") or 100 end end
			if k == "SetSize" then return function(_, w, h) t._w, t._h = w, h end end
			if k == "SetWidth" then return function(_, w) t._w = w end end
			if k == "SetHeight" then return function(_, h) t._h = h end end
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
			if k == "SetColorTexture" then return function() end end
			if k == "SetVertexColor" then return function() end end
			if k == "SetTexture" then return function(_, path) t._texture = path end end
			if k == "GetTexture" then return function() return t._texture end end
			if k == "RegisterForClicks" then return function() end end
			if k == "CreateFontString" or k == "CreateTexture" then return function() return frameStub() end end
			if k == "SetText" then return function(_, s) t._text = s end end
			if k == "GetText" then return function() return t._text end end
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
	env.time = os.time
	env.InCombatLockdown = function() return false end
	env.chat = {}
	env.SendChatMessage = function(m, t) env.chat[#env.chat + 1] = { m, t } end
	env.leaves = 0
	env.LeaveParty = function()
		env.leaves = env.leaves + 1
		local p = party[name]
		party[name] = nil
		if p then
			for i, m in ipairs(p) do if m == name then table.remove(p, i) break end end
			if #p < 2 then for _, m in ipairs(p) do party[m] = nil end end
		end
	end
	env.IsAltKeyDown = function() return env.altDown end
	env.hooksecurefunc = function(fname, fn)
		local orig = env[fname]
		env[fname] = function(...) local r = orig(...) fn(...) return r end
	end
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
check(ana.ns.Lang.DefaultCode() == "e" and ana.ns.Lang.Search()[1] == "e" and not ana.ns.Lang.AcceptsAll(),
	"default languages: the client's only (enUS -> EN), not all languages")
check(ana.ns.Lang.Encode() == "e", "language payload is the client letter (e)")
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
check(ana.printed[#ana.printed]:find("Wait"), "search cooldown enforced")

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
check(m and m.kind == "S" and #m.quests == n and m.class == "WARRIOR" and m.langs and m.langs.code == "e", "decode round trip (with langs)")
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
check(dee.ns.HeaderIcon() and dee.ns.HeaderIcon():find("PSGroupFinder") and dee.ns.HeaderIcon():find("icon%-eye"),
	"the header icon is a full path to our Media/icon-eye texture")
check(dee.ns.headerButtonFrame.psIconName == dee.ns.HeaderIcon() and dee.ns.headerButtonFrame.psIconName ~= "search",
	"the header button uses the eye, not Polestar's search/loupe icon")
-- Clicks: left starts a search without opening the panel; right toggles it.
dee.ns.SetEnabled(true)
run(15)
dee.ns.Comm.TestChannels(true)
run(6)
check(not dee.ns.UI.IsShown(), "panel is closed before a header click")
local hdr = dee.ns.headerButtonFrame
check(type(hdr._OnClick) == "function", "header OnClick is set (RegisterForClicks Left/Right)")
hdr:_OnClick("LeftButton")
check(dee.ns.Session.Active(), "left click on the header starts a search")
check(not dee.ns.UI.IsShown(), "left click does not open the panel")
local sawSent = false
for _, p in ipairs(dee.printed) do
	if p:find("Search sent") or p:find("Recherche envoyée") then sawSent = true end
end
check(sawSent, "left click prints a short search confirmation in chat")
if dee.ns.UI.IsShown() then dee.ns.UI.Toggle() end
hdr:_OnClick("RightButton")
check(dee.ns.UI.IsShown(), "right click opens the panel")
hdr:_OnClick("RightButton")
check(not dee.ns.UI.IsShown(), "right click again closes the panel")
-- Active search, no one found yet: a lone player with a unique quest.
local loneQ = { id = 4242, title = "Supplies to Auberdine", obj = { { "Bundle of Furs: 0/1", "item" } } }
local lea = newClient("Lea Grove", { loneQ }, { x = 0.5, y = 0.5 })
lea.ns.SetEnabled(true)
run(15)
lea.ns.Comm.TestChannels(true)
run(6)
lea.PSGroupFinder_Search()
lea.ns.UI.Show()
lea.ns.UI.Refresh()
check(lea.ns.Session.Active() and #lea.ns.Matcher.List() == 0, "Lea is searching and has no one yet")
check(lea.ns.UI.EmptyCaption() == "Searching… no player found yet.",
	"active search with no one found uses the searching-empty caption")
lea.ns.Session.Stop("manual")
lea.ns.UI.Refresh()
check(lea.ns.UI.EmptyCaption() == "No one yet. Press Find a group.",
	"with no search in progress the empty caption invites to search")
lea.ns.UI.Toggle()
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
check(eve.printed[#eve.printed - 1]:find("Objective done") ~= nil, "the player is told (objective done)")
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
check(eve.printed[#eve.printed]:find("Every objective") ~= nil, "the player is told the search is over")

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
for _, p in ipairs(invitee.printed) do if p:find("by hand") then told = true end end
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

---------------------------------------------------------------------------
-- v1.1: quest search by quest id, the quest buttons, leaving a group
---------------------------------------------------------------------------
local kc = { id = 12345, title = "Kobold Camp Cleanup", obj = { { "Kobold Vermin slain: 8/10", "monster" } } }
local function kq(have) return { id = 12345, title = kc.title, obj = { { "Kobold Vermin slain: " .. have .. "/10", "monster" } } } end
local qua = newClient("Qua Dell", {}, { map = 1436, locale = "frFR" })
local rex = newClient("Rex Holt", { kq(8) }, { map = 1429, class = "HUNTER", locale = "frFR" })
local sue = newClient("Sue Park", { kq(2) }, { map = 1436, locale = "enUS" })
local tom = newClient("Tom Gray", { { id = 31337, title = "Else", obj = { { "x: 0/1", "monster" } } } }, { map = 1436 })
local uma = newClient("Uma Wood", { kq(1) }, { map = 1436 })
for _, c in ipairs({ qua, rex, sue, tom, uma }) do c.ns.SetEnabled(true) end
uma.ns.Set("autoReply", false)
run(15)
for _, c in ipairs({ qua, rex }) do c.ns.Comm.TestChannels(true) end
run(6)
run(30)

-- Wire format: the new messages are invisible to a v1.0 reader and decode here.
local qtext = qua.ns.Comm.EncodeQuestSearch(12345)
check(qtext:match("^Q|") and #qtext < 80 and not qtext:match("^([SR])|"), "Q is a new message type a v1.0 client does not read")
local qm = qua.ns.Comm.Decode(qtext)
check(qm and qm.kind == "Q" and #qm.quests == 1 and qm.quests[1].id == 12345 and qm.langs and qm.langs.code == "f", "Q decodes with its quest and language")
local am = qua.ns.Comm.Decode(qua.ns.Comm.EncodeQuestReply(12345, 80))
check(am and am.kind == "A" and am.quests[1].id == 12345 and am.quests[1].pct == 80, "A decodes with the percent")
check(qua.ns.Comm.Decode("S|abc123|1436|400|500|20|WARRIOR|0|gA|f|176:n").quests[1].pct == nil, "S quests carry no percent")

-- Quest panel: opened with no result yet.
qua.ns.QuestUI.Open(12345)
check(qua.ns.QuestUI.IsShown() and qua.ns.QuestUI.Quest() == 12345 and not qua.ns.UI.IsShown(), "quest panel opens in quest mode, the main panel is not shown")
check(qua.ns.QuestUI.EmptyCaption() == "Personne pour l'instant. Appuyez sur Rechercher pour cette quête.", "quest panel: empty caption before any search (frFR client)")
check(#qua.ns.Matcher.QuestList(12345) == 0, "nobody known on the quest before searching")

-- A targeted search by quest id: found in ANOTHER zone, language filter applied.
check(qua.ns.Comm.SearchQuest(12345), "quest search goes out")
run(6)
local ql = qua.ns.Matcher.QuestList(12345)
local byName = {}
for _, e in ipairs(ql) do byName[e.name] = e end
check(byName["Rex Holt"] and byName["Rex Holt"].map == 1429 and byName["Rex Holt"].pct == 80 and byName["Rex Holt"].class == "HUNTER",
	"Rex answers from another zone (1429) with class and 80% progress")
check(not byName["Sue Park"], "Sue (EN client) is not listed by a FR-only searcher")
check(not byName["Tom Gray"] and not byName["Uma Wood"], "no answer from a player without the quest, or with replies off")
check(not (byName["Rex Holt"].sameZone), "the other-zone answer is not flagged same zone")
check(qua.ns.QuestUI.EmptyCaption() == nil or qua.ns.QuestUI.EmptyCaption() ~= "Personne pour l'instant. Appuyez sur Rechercher pour cette quête.", "panel no longer says nobody")
qua.ns.QuestUI.Refresh()
local qrowFrames = qua.ns.QuestUI.RowFrames()
check(qrowFrames[1] and qrowFrames[1].entry and qrowFrames[1].entry.name ~= nil and qrowFrames[1].invite.who ~= nil, "quest panel shows a row with Whisper / Invite for the player")

-- Throttle: one quest search every 15 s; replies answered once per asker.
check(not qua.ns.Comm.SearchQuest(12345) and (qua.printed[#qua.printed]:find("Wait") or qua.printed[#qua.printed]:find("Patientez")), "second quest search within 15 s is refused")
local rexAnswers = 0
local sentA = rex.C_ChatInfo.SendAddonMessage
rex.C_ChatInfo.SendAddonMessage = function(prefix, txt, chatType, target)
	if txt:sub(1, 2) == "A|" then rexAnswers = rexAnswers + 1 end
	return sentA(prefix, txt, chatType, target)
end
run(10)
check(qua.ns.Comm.SearchQuest(12345), "after 15 s a new quest search goes out")
run(6)
check(rexAnswers == 0, "the same asker is not answered twice within the reply gap")
run(25)
qua.ns.Comm.SearchQuest(12345)
run(6)
check(rexAnswers == 1, "...and again after the gap")

-- Language rules are unilateral on both sides: an EN-only player does not
-- answer a FR asker (as for a search); once she accepts FR she answers, but a
-- FR-only asker still does not list her, and one with All languages does.
sue.ns.Lang.SetSearch("f", true)
run(16)
qua.ns.Comm.SearchQuest(12345)
run(6)
check(not qua.ns.Matcher.QuestList(12345)[2] or qua.ns.Matcher.QuestList(12345)[2].name ~= "Sue Park", "FR-only asker does not list Sue even though she answered")
qua.ns.Lang.SetAcceptAll(true)
run(25)
qua.ns.Comm.SearchQuest(12345)
run(6)
local withAll = {}
for _, e in ipairs(qua.ns.Matcher.QuestList(12345)) do withAll[e.name] = true end
check(withAll["Sue Park"] and withAll["Rex Holt"], "with All languages the EN player is listed")
qua.ns.Lang.SetAcceptAll(false)
check(#qua.ns.Matcher.QuestList(12345) == 1, "back to FR only: the EN player drops out again")

-- Answers nobody asked for, or whispered Q, are ignored.
local before = #qua.ns.Matcher.QuestList(12345)
qua.fire("CHAT_MSG_ADDON", "PSGF", qua.ns.Comm.EncodeQuestReply(777, 50):gsub("^A|%x+", "A|abcdef"), "WHISPER", "Zed Nobody")
check(#qua.ns.Matcher.QuestList(777) == 0, "an answer to a quest we did not ask about is dropped")
local rexAnswersBefore = rexAnswers
rex.fire("CHAT_MSG_ADDON", "PSGF", qtext:gsub("^Q|%x+", "Q|abcdef"), "WHISPER", "Zed Nobody")
run(5)
check(rexAnswers == rexAnswersBefore, "a whispered Q is never answered")
check(#qua.ns.Matcher.QuestList(12345) == before, "nothing changed")

-- Disabled: nothing is sent.
qua.ns.SetEnabled(false)
check(not qua.ns.Comm.SearchQuest(12345), "quest search refused while the finder is off")
qua.ns.SetEnabled(true)
run(15)

---------------------------------------------------------------------------
-- The quest buttons (Polestar rows, tooltip + Alt-click, game quest log)
---------------------------------------------------------------------------
local gRows = {}
local function fakeRow(goal, height, shown)
	return { psGoal = goal, IsShown = function() return shown end, GetHeight = function() return height end,
		Icon = {}, Check = {}, Alt = { IsShown = function() return false end } }
end
gRows[1] = fakeRow({ quest = 12345, status = "active", t = "kill" }, 40, true)  -- two-line row
gRows[2] = fakeRow({ status = "active", t = "goto" }, 40, true)                 -- no quest
gRows[3] = fakeRow({ quest = 5, status = "done", t = "kill" }, 40, true)        -- done
gRows[4] = fakeRow({ quest = 12345, status = "active", t = "kill" }, 24, true)  -- one line
gRows[5] = fakeRow({ quest = 12345, status = "active", t = "kill" }, 40, false) -- hidden (pooled)
local origTipCalls, origClickCalls = 0, 0
local fp2 = {}
for k, v in pairs(fakePolestar) do fp2[k] = v end
fp2.Theme = {}
for k, v in pairs(fakePolestar.Theme) do fp2.Theme[k] = v end
fp2.Theme.GuideParts = function() return { window = window, nav = nav, rows = gRows } end
fp2.QuestClickTips = function(_, lines) origTipCalls = origTipCalls + 1 lines[#lines + 1] = { "Middle-click: show in quest log." } return lines end
fp2.QuestRowClick = function(_, button) origClickCalls = origClickCalls + 1 return button == "MiddleButton" end
local hal2 = newClient("Hal Two", { kq(3) }, { polestar = fp2 })
hal2.ns.Hooks.Scan()
check(gRows[1].psgfBtn and gRows[1].psgfBtn.questID == 12345, "a button on the goal row that names a quest")
check(gRows[2].psgfBtn == nil and gRows[3].psgfBtn == nil and gRows[5].psgfBtn == nil, "none on a row without quest, a done goal or a pooled hidden row")
check(gRows[4].psgfBtn and gRows[4].psgfBtn.questID == 12345, "one-line row gets one too (left of its checkbox)")
local lines = fp2.QuestClickTips(12345, {})
check(origTipCalls == 1 and #lines == 2 and lines[2][1] == "Alt-click: see the players on this quest", "tooltip: Polestar's lines kept, our Alt-click help line added")
check(#fp2.QuestClickTips("x", {}) == 1, "no help line for a goal without a quest id")
hal2.altDown = false
check(fp2.QuestRowClick(12345, "LeftButton") == false and origClickCalls == 1, "plain click: Polestar's own handler answers")
check(fp2.QuestRowClick(12345, "MiddleButton") == true and origClickCalls == 2, "middle-click still goes to Polestar")
check(not hal2.ns.QuestUI.IsShown(), "no quest panel without Alt")
hal2.altDown = true
check(fp2.QuestRowClick(12345, "LeftButton") == true and origClickCalls == 2, "Alt-click is consumed: Polestar's arrow handler does not run")
check(hal2.ns.QuestUI.IsShown() and hal2.ns.QuestUI.Quest() == 12345, "Alt-click opens the quest panel on that quest")
hal2.altDown = false
check(type(gRows[1].psgfBtn._OnClick) == "function", "the row button has a click handler")
hal2.ns.QuestUI.Close()
gRows[1].psgfBtn._OnClick(gRows[1].psgfBtn)
check(hal2.ns.QuestUI.IsShown(), "clicking the row button opens the quest panel")
check(gRows[1].psgfBtn.Icon and gRows[1].psgfBtn.Icon._texture and gRows[1].psgfBtn.Icon._texture:find("icon%-eye"),
	"the goal-row button uses our eye texture, not the two silhouettes")
-- Toggle: a second click on the same quest closes; another quest switches.
gRows[1].psgfBtn._OnClick(gRows[1].psgfBtn)
check(not hal2.ns.QuestUI.IsShown(), "a second click on the same goal-row button closes the quest panel")
gRows[1].psgfBtn._OnClick(gRows[1].psgfBtn)
check(hal2.ns.QuestUI.IsShown() and hal2.ns.QuestUI.Quest() == 12345, "a third click opens it again")
hal2.ns.QuestUI.Open(5001)
check(hal2.ns.QuestUI.IsShown() and hal2.ns.QuestUI.Quest() == 5001, "opening a different quest switches the list, it does not close")
hal2.ns.QuestUI.Open(5001)
check(not hal2.ns.QuestUI.IsShown(), "opening the same quest again closes the list")
hal2.altDown = true
fp2.QuestRowClick(12345, "LeftButton")
check(hal2.ns.QuestUI.IsShown() and hal2.ns.QuestUI.Quest() == 12345, "Alt-click opens the list")
fp2.QuestRowClick(12345, "LeftButton")
check(not hal2.ns.QuestUI.IsShown(), "a second Alt-click on the same quest closes the list")
hal2.altDown = false

-- The game's quest log: the pool of title buttons, Checkbox, recycled rows, hooks.
local function titleButton(id, shown)
	local check = { IsShown = function() return true end }
	local text = { SetPoint = function(self, p, rel, rp, x, y) self._p, self._rel, self._rp, self._x, self._y = p, rel, rp, x, y end, SetWordWrap = function() end }
	return { questID = id, IsShown = function() return shown end, Checkbox = check, Text = text,
		GetRight = function() return 200 end }
end
local active = { titleButton(12345, true), titleButton(5001, true) }
hal2.QuestScrollFrame = { titleFramePool = { EnumerateActive = function()
	local i = 0
	return function() i = i + 1 return active[i] end
end } }
hal2.QuestMapFrame = { IsVisible = function() return true end, HookScript = function() end }
hal2.QuestLogQuests_Update = function() end
hal2.ns.Hooks.Scan()
check(active[1].psgfLogBtn and active[1].psgfLogBtn.questID == 12345 and active[2].psgfLogBtn.questID == 5001, "quest log (pool): a button on each quest title, any zone")
-- The pool recycles a title button for another quest: our button follows its quest.
active[1].questID = 777
hal2.QuestLogQuests_Update()
check(active[1].psgfLogBtn.questID == 777, "after the log's own update (hooksecurefunc) the recycled row's button points at its new quest")
-- A header takes the recycled button: no quest, ours is hidden.
active[1].questID = nil
hal2.ns.Hooks.Scan()
check(active[1].psgfLogBtn._shown == false, "a row that no longer holds a quest hides our button")
-- Other builds: the children of the scroll contents, then the classic log.
local child88 = titleButton(88, true)
hal2.QuestScrollFrame = { Contents = { GetNumChildren = function() return 1 end, GetChildren = function() return child88 end } }
hal2.ns.Hooks.Scan()
check(child88.psgfLogBtn and child88.psgfLogBtn.questID == 88, "quest log (other build): title buttons found among the scroll contents' children")
hal2.QuestScrollFrame = nil
hal2.QuestMapFrame = nil
hal2.QuestLogFrame = { IsVisible = function() return true end }
hal2.QuestLogTitle1 = { IsShown = function() return true end, GetID = function() return 1 end }
hal2.ns.Hooks.Scan()
check(hal2.QuestLogTitle1.psgfLogBtn and hal2.QuestLogTitle1.psgfLogBtn.questID == 12345, "classic log: QuestLogTitle1's quest id is read from the log index")
-- Placement: always to the right of the tracking checkbox, title trimmed short of the box.
-- Re-scan the pool so placeInLog runs on title buttons that have Checkbox + Text.
hal2.QuestLogTitle1 = nil
hal2.QuestLogFrame = nil
active[1].questID = 12345
hal2.QuestScrollFrame = { titleFramePool = { EnumerateActive = function()
	local i = 0
	return function() i = i + 1 return active[i] end
end } }
hal2.QuestMapFrame = { IsVisible = function() return true end, HookScript = function() end }
hal2.ns.Hooks.Scan()
local logBtn, logCheck, logText = active[1].psgfLogBtn, active[1].Checkbox, active[1].Text
check(logBtn and logBtn._rel == logCheck and logBtn._point == "LEFT" and logBtn._relPoint == "RIGHT" and logBtn._x == 3,
	"the log button sits 3 px to the right of the tracking checkbox")
check(logText._rel == logCheck and logText._p == "RIGHT" and logText._rp == "LEFT",
	"the quest title is anchored short of the checkbox, so it never runs under our button")
-- A row with no checkbox keeps the same right-hand column (just past the title button).
local plain = { questID = 42, IsShown = function() return true end, Text = { SetPoint = function(self, p, rel, rp, x, y) self._p, self._rel, self._rp = p, rel, rp end, SetWordWrap = function() end } }
hal2.QuestScrollFrame = { titleFramePool = { EnumerateActive = function()
	local i = 0
	return function() i = i + 1 if i == 1 then return plain end end
end } }
hal2.ns.Hooks.Scan()
check(plain.psgfLogBtn and plain.psgfLogBtn._point == "LEFT" and plain.psgfLogBtn._rel == plain and plain.psgfLogBtn._relPoint == "RIGHT" and plain.psgfLogBtn._x == 3,
	"with no checkbox the button stays in the right-hand column, just past the row")

-- Quest details pane (Forever / Retail): eye button next to Back.
local details = { IsShown = function() return true end, questID = 12345, HookScript = function() return true end }
details.BackButton = { GetParent = function() return details end }
hal2.QuestMapFrame = { IsVisible = function() return true end, HookScript = function() end, DetailsFrame = details }
hal2.QuestMapFrame_ShowQuestDetails = function() end
hal2.ns.QuestUI.Close()
hal2.ns.Hooks.Scan()
local dbtn = hal2.ns.Hooks.DetailsButton()
check(dbtn and dbtn.questID == 12345 and dbtn:IsShown(), "the details pane has an eye button for the displayed quest")
check(dbtn._rel == details.BackButton and dbtn._point == "RIGHT" and dbtn._relPoint == "LEFT",
	"the details button sits just left of Back")
check(dbtn.Icon and dbtn.Icon._texture and dbtn.Icon._texture:find("icon%-eye"),
	"the details button uses our eye texture")
dbtn._OnClick(dbtn)
check(hal2.ns.QuestUI.IsShown() and hal2.ns.QuestUI.Quest() == 12345, "clicking the details button opens the quest list")
dbtn._OnClick(dbtn)
check(not hal2.ns.QuestUI.IsShown(), "a second click on the details button closes the quest list")
-- Log-row button uses the same Open() toggle.
active[1].questID = 88
hal2.QuestScrollFrame = { titleFramePool = { EnumerateActive = function()
	local i = 0
	return function() i = i + 1 return active[i] end
end } }
hal2.ns.Hooks.Scan()
active[1].psgfLogBtn._OnClick(active[1].psgfLogBtn)
check(hal2.ns.QuestUI.IsShown() and hal2.ns.QuestUI.Quest() == 88, "clicking the log button opens the quest list")
active[1].psgfLogBtn._OnClick(active[1].psgfLogBtn)
check(not hal2.ns.QuestUI.IsShown(), "a second click on the same log button closes the quest list")
active[1].psgfLogBtn._OnClick(active[1].psgfLogBtn)
active[2].psgfLogBtn._OnClick(active[2].psgfLogBtn)
check(hal2.ns.QuestUI.IsShown() and hal2.ns.QuestUI.Quest() == 5001, "a log button for another quest switches the list")

hal2.ns.Hooks.Report()

-- Without Polestar and without any quest log, nothing breaks.
rex.ns.Hooks.Scan()
check(true, "scan with no Polestar and no quest log does nothing")

---------------------------------------------------------------------------
-- Leaving a group formed through the finder
---------------------------------------------------------------------------
local function lq(id, have) return { id = id, title = "Quest " .. id, obj = { { "Thing slain: " .. have .. "/6", "monster" } } } end
local rae = newClient("Rae Fox", { lq(11001, 0), lq(11002, 0) }, { x = 0.1, y = 0.1, locale = "frFR" })
local sam = newClient("Sam Lee", { lq(11001, 0), lq(11002, 0) }, { x = 0.11, y = 0.1, locale = "frFR" })
local noa = newClient("Noa Bell", { lq(11001, 0) }, { x = 0.12, y = 0.1 })
for _, c in ipairs({ rae, sam, noa }) do c.ns.SetEnabled(true) end
run(15)
rae.ns.Comm.TestChannels(true) run(6)
run(30)
check(sam.ns.Leave.Message() == "Merci pour le groupe, bon jeu !", "default leave message in French for a French client")
check(ned.ns.Leave.Message() == "Thanks for the group, have fun!", "default leave message in English for an English client")
check(rae.ns.Get("leaveOffer") == true and rae.ns.Get("leaveMsgOn") == false and not rae.ns.Get("leaveMsgAny"),
	"defaults: offer on, /p message off, not for groups formed by hand")
rae.PSGroupFinder_Search()
run(8)
check(rae.ns.Matcher.Get("Sam Lee") ~= nil, "Rae found Sam")
-- Rae clicks Invite on Sam's row (the handler records the quests); Sam accepts by hand.
rae.ns.UI.Show()
rae.ns.UI.Refresh()
local inviteBtn
for _, r in ipairs(rae.ns.UI.RowFrames()) do if r.invite.who == "Sam Lee" then inviteBtn = r.invite end end
check(inviteBtn ~= nil, "Sam's row exists with its Invite button")
inviteBtn._OnClick(inviteBtn)
run(1)
sam.AcceptGroup()
rae.fire("GROUP_ROSTER_UPDATE") sam.fire("GROUP_ROSTER_UPDATE")
run(2)
local function qset(c) local t = {} for id in pairs((c.ns.char.party or { quests = {} }).quests) do t[#t + 1] = id end table.sort(t) return t end
local rs, ss = qset(rae), qset(sam)
check(#rs == 2 and rs[1] == 11001 and rs[2] == 11002, "inviter remembers the shared quests of the group")
check(#ss == 2, "the player who accepted the invitation remembers them too")
check(rae.ns.UI.LeaveShown() == false and rae.leaves == 0, "nothing offered while quests are open")

-- One quest done: still one open, no offer. Both done: the offer, no automatic leave.
rae.quests[1].obj[1][3] = true
rae.QuestLogUpdate()
run(5)
check(not rae.ns.UI.LeaveShown(), "one quest of two done: no offer yet")
rae.quests[2].complete = true
rae.QuestLogUpdate()
run(5)
check(rae.ns.UI.LeaveShown(), "all the group's quests done (objectives / ready): the Leave / Stay window appears")
run(120)
check(rae.leaves == 0 and #rae.chat == 0, "nothing left and nothing said automatically (no click yet)")
check(not sam.ns.UI.LeaveShown(), "Sam still has open quests: no window for him")
-- Stay: not asked again.
local _, stay = rae.ns.UI.LeaveButtons()
stay._OnClick(stay)
check(not rae.ns.UI.LeaveShown() and rae.leaves == 0 and #rae.chat == 0, "Stay closes the window and does nothing else")
rae.QuestLogUpdate() run(5)
check(not rae.ns.UI.LeaveShown(), "after Stay it is not offered again for this group")

-- A second group: the /p message is said on the click, then the party is left.
local tia = newClient("Tia Moon", { lq(11001, 0) }, { x = 0.1, y = 0.2 })
tia.ns.SetEnabled(true) run(15) tia.ns.Comm.TestChannels(true) run(6) run(30)
tia.ns.Set("leaveMsgOn", true)
tia.ns.Set("leaveMsg", "Thanks, take care!")
noa.PSGroupFinder_Search() run(8)
check(noa.ns.Matcher.Get("Tia Moon") ~= nil, "Noa found Tia")
noa.ns.Leave.NoteInvite("Tia Moon", noa.ns.Matcher.Get("Tia Moon").quests)
noa.C_PartyInfo.InviteUnit("Tia Moon")
run(1)
tia.AcceptGroup()
noa.fire("GROUP_ROSTER_UPDATE") tia.fire("GROUP_ROSTER_UPDATE") run(2)
check(#qset(tia) == 1 and qset(tia)[1] == 11001, "Tia remembers quest 11001")
tia.quests[1].obj[1][3] = true
tia.QuestLogUpdate() run(5)
check(tia.ns.UI.LeaveShown() and tia.leaves == 0 and #tia.chat == 0, "window shown, still nothing said or left")
local tyes = tia.ns.UI.LeaveButtons()
tyes._OnClick(tyes)
check(#tia.chat == 1 and tia.chat[1][1] == "Thanks, take care!" and tia.chat[1][2] == "PARTY", "Leave click: the /p message is sent first (PARTY)")
check(tia.leaves == 1 and party["Tia Moon"] == nil, "...then the party is left")
check(tia.ns.char.party == nil, "the memory of the group is cleared")

-- Without the message option the click only leaves.
local uri = newClient("Uri Cole", { lq(11001, 0) }, { x = 0.1, y = 0.3 })
uri.ns.SetEnabled(true) run(15) uri.ns.Comm.TestChannels(true) run(6) run(30)
uri.PSGroupFinder_Search() run(8)
local noaE = uri.ns.Matcher.Get("Noa Bell")
check(noaE ~= nil, "Uri found Noa")
party["Noa Bell"] = nil
uri.ns.Leave.NoteInvite("Noa Bell", noaE.quests)
uri.C_PartyInfo.InviteUnit("Noa Bell") run(1)
noa.AcceptGroup()
uri.fire("GROUP_ROSTER_UPDATE") noa.fire("GROUP_ROSTER_UPDATE") run(2)
uri.quests[1].complete = true
uri.QuestLogUpdate() run(5)
local uyes = uri.ns.UI.LeaveButtons()
uyes._OnClick(uyes)
check(#uri.chat == 0 and uri.leaves == 1, "message option off: Leave only leaves, nothing is said")

-- A group NOT formed through the finder is never offered, even with quests done.
local vic = newClient("Vic Hale", { lq(11001, 0) }, {})
local wyn = newClient("Wyn Cass", { lq(11001, 0) }, {})
vic.ns.SetEnabled(true) wyn.ns.SetEnabled(true) run(15)
party["Vic Hale"] = { "Vic Hale", "Wyn Cass" } party["Wyn Cass"] = party["Vic Hale"]
vic.fire("GROUP_ROSTER_UPDATE") run(2)
vic.quests[1].complete = true vic.QuestLogUpdate() run(5)
check(vic.ns.char.party == nil and not vic.ns.UI.LeaveShown(), "a group formed by hand is not remembered or offered")

-- Option off: nothing shown. Abandoned quests do not count as done.
local xan = newClient("Xan Dyle", { lq(11001, 0), lq(11002, 0) }, { x = 0.1, y = 0.4 })
local yui = newClient("Yui Reed", { lq(11001, 0), lq(11002, 0) }, { x = 0.1, y = 0.41 })
xan.ns.SetEnabled(true) yui.ns.SetEnabled(true) run(15) xan.ns.Comm.TestChannels(true) run(6) run(30)
xan.PSGroupFinder_Search() run(8)
xan.ns.Leave.NoteInvite("Yui Reed", yui.ns.Matcher.Get("Xan Dyle") and { 11001, 11002 } or { 11001, 11002 })
xan.C_PartyInfo.InviteUnit("Yui Reed") run(1)
yui.AcceptGroup()
xan.fire("GROUP_ROSTER_UPDATE") yui.fire("GROUP_ROSTER_UPDATE") run(2)
xan.ns.Set("leaveOffer", false)
xan.quests[1].complete = true xan.quests[2].complete = true
xan.QuestLogUpdate() run(5)
check(not xan.ns.UI.LeaveShown(), "leaveOffer off: no window")
xan.ns.Set("leaveOffer", true)
xan.QuestLogUpdate() run(5)
check(xan.ns.UI.LeaveShown(), "...and back on, it is offered")
-- Abandon: a quest that left the log without being done drops out of the memory.
yui.quests[2] = nil
yui.QuestLogUpdate() run(5)
check(#qset(yui) == 1 and qset(yui)[1] == 11001, "an abandoned quest is forgotten, the other still counts")
check(not yui.ns.UI.LeaveShown(), "...and nothing is offered while the other is open")
-- Group ends: memory cleared.
party["Yui Reed"] = nil
yui.fire("GROUP_ROSTER_UPDATE") run(2)
check(yui.ns.char.party == nil, "the memory goes when the group ends")

-- The message editor saves, strips escapes, and the default comes back on empty.
sam.ns.UI.EditLeaveMessage()
check(sam.ns.UI.EditorShown(), "message dialog opens")
sam.ns.Set("leaveMsg", "Hi |cffff0000!")
check(sam.ns.Leave.Message() == "Hi |cffff0000!", "a saved message is used as is by Message()")
sam.ns.Set("leaveMsg", false)
check(sam.ns.Leave.Message() == "Merci pour le groupe, bon jeu !", "false brings the default text back")

-- Leaving through the game (LeaveParty / portrait / /leave): same /p message,
-- no double send when our button also calls LeaveParty, only for a finder group
-- unless leaveMsgAny is on. The panel's Leave button uses the same path.
local pip = newClient("Pip Wren", { lq(11001, 0) }, { x = 0.2, y = 0.2 })
local kit = newClient("Kit Vale", { lq(11001, 0) }, { x = 0.21, y = 0.2 })
pip.ns.SetEnabled(true) kit.ns.SetEnabled(true) run(15)
pip.ns.Comm.TestChannels(true) run(6) run(30)
pip.ns.Set("leaveMsgOn", true)
pip.ns.Set("leaveMsg", "Have fun, thanks!")
pip.PSGroupFinder_Search() run(8)
check(pip.ns.Matcher.Get("Kit Vale") ~= nil, "Pip found Kit")
pip.ns.Leave.NoteInvite("Kit Vale", pip.ns.Matcher.Get("Kit Vale").quests)
pip.C_PartyInfo.InviteUnit("Kit Vale") run(1)
kit.AcceptGroup()
pip.fire("GROUP_ROSTER_UPDATE") kit.fire("GROUP_ROSTER_UPDATE") run(2)
check(pip.ns.char.party ~= nil, "Pip remembers the finder group")
-- Game leave (the hooked LeaveParty), not our window.
pip.LeaveParty()
check(#pip.chat == 1 and pip.chat[1][1] == "Have fun, thanks!" and pip.chat[1][2] == "PARTY",
	"leaving via the game (LeaveParty) sends the /p message first")
check(pip.leaves == 1, "LeaveParty then leaves the group")

-- Our Leave.Do must not send twice (it also calls LeaveParty, already hooked).
local jo = newClient("Jo Pike", { lq(11001, 0) }, { x = 0.22, y = 0.2 })
local mo = newClient("Mo Pike", { lq(11001, 0) }, { x = 0.23, y = 0.2 })
jo.ns.SetEnabled(true) mo.ns.SetEnabled(true) run(15)
jo.ns.Comm.TestChannels(true) run(6) run(30)
jo.ns.Set("leaveMsgOn", true)
jo.ns.Set("leaveMsg", "See you!")
jo.PSGroupFinder_Search() run(8)
jo.ns.Leave.NoteInvite("Mo Pike", { 11001 })
jo.C_PartyInfo.InviteUnit("Mo Pike") run(1)
mo.AcceptGroup()
jo.fire("GROUP_ROSTER_UPDATE") mo.fire("GROUP_ROSTER_UPDATE") run(2)
jo.ns.Leave.Do()
check(#jo.chat == 1 and jo.chat[1][1] == "See you!" and jo.leaves == 1,
	"Leave.Do sends the /p message once, even though LeaveParty is pre-hooked")

-- A group formed by hand: no message unless leaveMsgAny is on.
local abb = newClient("Abb Cole", { lq(11001, 0) }, {})
local bea = newClient("Bea Cole", { lq(11001, 0) }, {})
abb.ns.SetEnabled(true) bea.ns.SetEnabled(true) run(15)
abb.ns.Set("leaveMsgOn", true)
abb.ns.Set("leaveMsg", "Bye")
party["Abb Cole"] = { "Abb Cole", "Bea Cole" } party["Bea Cole"] = party["Abb Cole"]
abb.fire("GROUP_ROSTER_UPDATE") run(1)
check(abb.ns.char.party == nil, "a hand-formed group is not in the finder's memory")
abb.LeaveParty()
check(#abb.chat == 0 and abb.leaves == 1, "LeaveParty on a hand-formed group says nothing by default")
party["Abb Cole"] = { "Abb Cole", "Bea Cole" } party["Bea Cole"] = party["Abb Cole"]
abb.ns.Set("leaveMsgAny", true)
abb.LeaveParty()
check(#abb.chat == 1 and abb.chat[1][1] == "Bye" and abb.leaves == 2,
	"with leaveMsgAny, leaving a hand-formed group also sends the /p message")

-- Panel "Leave the group" button: visible only in a party, same Leave.Do path.
local cy = newClient("Cy Moss", { lq(11001, 0) }, { x = 0.25, y = 0.2 })
local dy = newClient("Dy Moss", { lq(11001, 0) }, { x = 0.26, y = 0.2 })
cy.ns.SetEnabled(true) dy.ns.SetEnabled(true) run(15)
cy.ns.Comm.TestChannels(true) run(6) run(30)
cy.ns.Set("leaveMsgOn", true)
cy.ns.Set("leaveMsg", "Goodbye")
cy.ns.UI.Show()
cy.ns.UI.Refresh()
check(not (cy.ns.UI.LeaveGroupButton() and cy.ns.UI.LeaveGroupButton():IsShown()),
	"the Leave the group button is hidden when not in a party")
cy.PSGroupFinder_Search() run(8)
cy.ns.Leave.NoteInvite("Dy Moss", { 11001 })
cy.C_PartyInfo.InviteUnit("Dy Moss") run(1)
dy.AcceptGroup()
cy.fire("GROUP_ROSTER_UPDATE") dy.fire("GROUP_ROSTER_UPDATE") run(2)
cy.ns.UI.Show()
cy.ns.UI.Refresh()
local lg = cy.ns.UI.LeaveGroupButton()
check(lg and lg:IsShown(), "the Leave the group button appears while in a party")
lg._OnClick(lg)
check(#cy.chat == 1 and cy.chat[1][1] == "Goodbye" and cy.leaves == 1,
	"the panel Leave button sends the /p message then leaves")
cy.ns.UI.Refresh()
check(not cy.ns.UI.LeaveGroupButton():IsShown(), "the Leave button hides again once out of the group")

-- Header right-click closes the quest list if it is the pane on screen (toggle).
hal2.ns.QuestUI.Open(12345)
check(hal2.ns.QuestUI.IsShown(), "quest list is open before a header toggle")
-- This client has no header frame of its own; UI.Toggle is what the header calls.
hal2.ns.UI.Toggle()
check(not hal2.ns.QuestUI.IsShown() and not hal2.ns.UI.IsShown(),
	"toggling the panel (header right-click) closes the open quest list and does not open the main panel")

---------------------------------------------------------------------------
-- Options sidebar icon (RegisterOptions `icon`, plus a hook if the
-- grouped layout's nav omits it)
---------------------------------------------------------------------------
local capturedOpts = {}
local fp3 = {}
for k, v in pairs(fakePolestar) do fp3[k] = v end
fp3.RegisterOptions = function(spec) capturedOpts[#capturedOpts + 1] = spec return true end
fp3.UI = { Options = { Kit = { pages = { { key = "groupfinder", name = "Group Finder" } } },
	Grouped = { NavItems = function()
		return {
			{ key = "guide", label = "Guide", icon = "icon-note", indent = true },
			{ key = "groupfinder", label = "Group Finder", indent = true },
		}
	end } }, ShowOptions = function() end }
local navPainted = { other = 0 }
fp3.Widgets = {
	NavRowAfter = function(_, item)
		if item and item.key ~= "groupfinder" then navPainted.other = navPainted.other + 1 end
	end,
	RefreshAll = function() end,
	Media = function() end,
}
local ico = newClient("Ico Vale", { hogger }, { polestar = fp3 })
check(ico.ns.OptionsIcon():find("PSGroupFinder") and ico.ns.OptionsIcon():find("icon%-eye"),
	"the sidebar icon is a full path to our Media/icon-eye texture")
check(ico.ns.OptionsIcon() == ico.ns.HeaderIcon() and ico.ns.Icon() == ico.ns.OptionsIcon(),
	"the sidebar, the header and ns.Icon() all use the same eye")
check(#capturedOpts >= 1 and capturedOpts[1].icon == ico.ns.OptionsIcon() and capturedOpts[1].key == "groupfinder",
	"RegisterOptions (public API) receives our icon on the Group Finder page")
check(fp3.UI.Options.Kit.pages[1].icon == ico.ns.OptionsIcon(),
	"the registered page's icon is set (internal Kit.pages, under pcall)")
local items = fp3.UI.Options.Grouped.NavItems()
check(items[1].icon == "icon-note" and items[2].key == "groupfinder" and items[2].icon == ico.ns.OptionsIcon(),
	"Grouped.NavItems fills our icon when the layout omitted it, and leaves the others alone")
local painted
local row = { Icon = { SetTexture = function(_, path) painted = path end, SetSize = function() end, Show = function() end } }
fp3.Widgets.NavRowAfter(row, { key = "groupfinder" }, false)
check(painted == ico.ns.OptionsIcon(), "NavRowAfter (internal) paints our 16px icon on the Group Finder row")
painted = nil
fp3.Widgets.NavRowAfter(row, { key = "guide", icon = "icon-note" }, false)
check(painted == nil and navPainted.other >= 1, "NavRowAfter does not rewrite another page's icon")
-- Without the options window, the hook is a no-op (the public icon field remains).
local fp4 = {}
for k, v in pairs(fakePolestar) do fp4[k] = v end
fp4.RegisterOptions = function() return true end
local ico2 = newClient("Ico Two", { hogger }, { polestar = fp4 })
check(ico2.ns.HookOptionsIcon and (function() ico2.ns.HookOptionsIcon() return true end)(),
	"the icon hook is silent when the grouped layout is absent")

-- Header eye stays on the button when SetIconState / a Painter would have
-- restored Polestar's "search" icon (the binoculars/loupe the player saw).
local iconBtnName, setIconStateOn
local fpEye = {}
for k, v in pairs(fakePolestar) do fpEye[k] = v end
fpEye.Widgets = {
	IconButton = function(parent, icon, size)
		iconBtnName = icon
		local b = parent -- reuse a stub-like frame
		b = (parent and parent) or {}
		-- a fresh button
		local btn = { Icon = { SetTexture = function(_, path) btn.Icon._texture = path end, Show = function() end, Hide = function() end, SetSize = function() end, SetPoint = function() end },
			SetAlpha = function() end, SetScript = function(self, ev, fn) self["_" .. ev] = fn end,
			SetSize = function() end, EnableMouse = function() end, RegisterForClicks = function() end,
			ClearAllPoints = function() end, SetPoint = function() end, SetFrameLevel = function() end,
			GetFrameLevel = function() return 1 end, Show = function() end, Hide = function() end,
			GetPoint = function() return "RIGHT", nil, "LEFT", 0, 0 end,
			GetCenter = function() return 1, 1 end,
		}
		btn.Icon.SetTexture(btn.Icon, icon)
		btn.psIconName = icon
		return btn
	end,
	SetIconState = function(b, active, enabled)
		setIconStateOn = { active = active, enabled = enabled, name = b.psIconName }
		-- must not rewrite the texture; only tint
	end,
	Color = function() end,
	RefreshAll = function() end,
}
-- GuideParts on the copied Theme still returns dee's window; attach() would
-- skip a new header if lookup is already bound. Give this client its own nav.
local eyeNav = { Lookup = { psIconName = "search", GetFrameLevel = function() return 5 end, SetPoint = function() end, GetPoint = function() return "RIGHT", nil, "RIGHT", 0, 0 end, GetNumChildren = function() return 0 end, GetChildren = function() end } }
local eyeWin = { HookScript = function() end, SetPoint = function() end, GetFrameLevel = function() return 1 end, IsShown = function() return true end }
fpEye.Theme = {}
for k, v in pairs(fakePolestar.Theme) do fpEye.Theme[k] = v end
fpEye.Theme.GuideParts = function() return { window = eyeWin, nav = eyeNav } end
local eyeCli = newClient("Eye Vale", { hogger }, { polestar = fpEye })
check(iconBtnName == eyeCli.ns.HeaderIcon(), "IconButton is constructed with our eye path, not \"search\"")
check(eyeCli.ns.headerButtonFrame and eyeCli.ns.headerButtonFrame.psIconName == eyeCli.ns.HeaderIcon(),
	"header psIconName stays on the eye so a Painter cannot restore the loupe")
eyeCli.ns.PaintHeader()
check(setIconStateOn and setIconStateOn.enabled == true and setIconStateOn.name == eyeCli.ns.HeaderIcon(),
	"SetIconState tints the eye and is not given the search icon")
check(eyeCli.ns.headerButtonFrame.psIconName ~= "search", "paintHeader does not retarget the button to search")

-- Every RegisterOptions control has a non-empty help (tooltip).
local missingHelp = {}
for _, spec in ipairs(capturedOpts) do
	for _, c in ipairs(spec.controls or {}) do
		if type(c.help) ~= "string" or c.help == "" then
			missingHelp[#missingHelp + 1] = tostring(c.label or c.kind or c.action or "?")
		end
	end
end
check(#missingHelp == 0, "every options control has a tooltip (help): " .. table.concat(missingHelp, ", "))

-- Language accordion: needs hides the rows while All is on; Relayout is
-- called so the section shrinks (disabled remains as a last-resort grey).
local langSpec
for _, spec in ipairs(capturedOpts) do
	if spec.section == ico.ns.L.LANGS then langSpec = spec end
end
check(langSpec and #langSpec.controls >= 2, "the languages section is registered")
check(langSpec.controls[1].help and langSpec.controls[1].help ~= "", "All languages has a tooltip")
local relayouts = 0
fp3.UI.Options.Relayout = function() relayouts = relayouts + 1 end
ico.ns.Lang.SetAcceptAll(true)
check(relayouts >= 1, "toggling All languages calls Options.Relayout (under pcall)")
for i = 2, #langSpec.controls do
	local c = langSpec.controls[i]
	check(type(c.needs) == "function" and c.needs() == false, "needs hides " .. tostring(c.label) .. " when All is on")
	check(type(c.disabled) == "function" and c.disabled() == true, "disabled still greys " .. tostring(c.label) .. " as a last resort")
	check(type(c.help) == "string" and c.help ~= "", "each language has a tooltip (" .. tostring(c.label) .. ")")
end
ico.ns.Lang.SetAcceptAll(false)
for i = 2, #langSpec.controls do
	local c = langSpec.controls[i]
	check(c.needs() == true and c.disabled() == false, "needs shows " .. tostring(c.label) .. " when All is off")
end

-- Panel language picker: folded hides the language checks and shrinks the box.
ico.ns.UI.Show()
ico.ns.Lang.SetAcceptAll(true)
ico.ns.UI.ToggleLangPicker()
local box = ico.ns.UI.LangPicker()
check(box and box:IsShown(), "the language picker opens")
local foldedH = box:GetHeight()
local hidden = 0
for _, c in ipairs(box.langs or {}) do
	if not c:IsShown() then hidden = hidden + 1 end
end
check(hidden == #box.langs and #box.langs > 0, "when All is on the language list is hidden, not greyed")
ico.ns.Lang.SetAcceptAll(false)
ico.ns.UI.RefreshLangPicker()
local shown = 0
for _, c in ipairs(box.langs or {}) do
	if c:IsShown() then shown = shown + 1 end
end
check(shown == #box.langs, "when All is off the language list is shown")
check(box:GetHeight() > foldedH, "the picker grows when the list unfolds, with no leftover gap")


ana.ns.SetEnabled(false)
check(#ana.ns.Matcher.List() == 0 and ana.joined == false, "turning off clears the list and leaves the channel")
print("all tests passed")
