-- Two simulated clients exchanging PSGroupFinder messages, with a
-- stub of the WoW API. Run: lua5.1 tests/sim.lua (from the repo root).
local FILES = { "Locales", "Core", "Lang", "Throttle", "Quests", "Session", "Protocol", "Channels", "ChatFilter", "Comm", "Matcher", "Group", "Messages", "Leave", "Announce",
	"UI/Widgets", "UI/Panel", "UI/QuestPanel", "UI/MessagesWindow", "UI/PartyBox",
	"Polestar/Polestar", "Polestar/Menu", "Polestar/Options", "Polestar/Nearby", "Polestar/GoalRows", "Demo" }
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
			if k == "SetAlpha" then return function(_, a) t._alpha = a end end
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
	env.SendChatMessage = function(m, t, _, target) env.chat[#env.chat + 1] = { m, t, target } end
	env.channels = { 1, "General", false, 2, "Trade", false }
	env.GetChannelList = function() return unpack(env.channels) end
	env.UnitName = function() return name end
	env.GetPlayerInfoByGUID = function(guid) if guid == "Player-1-MAGE" then return "Mage", "MAGE" end end
	env.ERR_CHAT_PLAYER_NOT_FOUND_S = "No player named '%s' is currently playing."
	env.chatFilters = {}
	env.ChatFrame_AddMessageEventFilter = function(ev, fn) env.chatFilters[ev] = fn end
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
	-- Most scenarios need answers; the real default (off) is checked on its own.
	if not opts.defaults then ns.db.autoReply = true end
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
-- Cid: unrelated quest.
local hogger = { id = 176, title = "Wanted: Hogger", obj = { { "Hogger slain: 0/1", "monster" } } }
local boars = { id = 86, title = "Pie for Billy", obj = { { "Chunk of Boar Meat: 2/4", "item" } } }
local other = { id = 999, title = "Report to Goldshire", obj = {} }
local ana = newClient("Ana Smith", { hogger, boars }, { x = 0.40, y = 0.50 })
local ben = newClient("Ben Stone", { hogger }, { x = 0.42, y = 0.51, class = "PRIEST" })
local cid = newClient("Cid Vale", { other }, {})

-- Off by default: nothing is sent, nothing answers on its own.
check(ana.ns.db.enabled == false, "disabled by default")
local dft = newClient("Dft Vale", { hogger }, { defaults = true })
check(dft.ns.Get("autoReply") == false and dft.ns.Get("autoGroup") == false,
	"every automatism is off by default (answers, auto-group)")
check(ana.ns.Lang.DefaultCode() == "e" and ana.ns.Lang.Search()[1] == "e" and not ana.ns.Lang.AcceptsAll(),
	"default languages: the client's only (enUS -> EN), not all languages")
check(ana.ns.Lang.Encode() == "e", "language payload is the client letter (e)")
ana.PSGroupFinder_Search()
run(1)
check(next(ana.ns.Channels.status) == nil, "a search while disabled sends nothing")

for _, c in ipairs({ ana, ben, cid, dft }) do c.ns.SetEnabled(true) end
run(15) -- join delay
check(next(ana.ns.Channels.status) == nil, "enabling joins the channel but sends no probe")
check(ana.ns.Channels.ORDER[1] == "CHANNEL" and #ana.ns.Channels.ORDER == 1,
	"searches use the finder's hidden channel only (no SAY / YELL / GUILD)")

local rel = ana.ns.Quests.Relevant()
check(#rel == 2 and rel[1].id == 176 and rel[1].kind == "n" and rel[2].kind == "l", "Ana's relevant quests: Hogger (named) then boar meat (loot)")

ana.ns.Channels.Test()
run(6)
check(ana.ns.Channels.status.CHANNEL.state == "ok", "Test (on request): CHANNEL echo detected")
check(ana.ns.Channels.status.YELL == nil and ana.ns.Channels.status.GUILD == nil, "the test tries nothing but the channel")

ana.PSGroupFinder_Search()
run(5)
local list = ana.ns.Matcher.List()
check(#list == 1 and list[1].name == "Ben Stone" and list[1].quests[1] == 176, "Ana finds Ben on Hogger (Ben's whisper reply)")
check(list[1].yards and list[1].yards < 40, "distance computed in yards: " .. tostring(list[1].yards))
check(#ben.ns.Matcher.List() == 1, "Ben sees Ana as also looking")
check(#cid.ns.Matcher.List() == 0, "Cid (no shared quest) sees nobody and answers nothing")
check(dft.ns.Matcher.Get("Ana Smith") ~= nil and ana.ns.Matcher.Get("Dft Vale") == nil,
	"with answers off (the default) a player sees the searcher but sends no answer")

ana.PSGroupFinder_Search()
check(ana.printed[#ana.printed]:find("Wait"), "search cooldown enforced")

-- A client that refuses the hidden channel cannot search, even in a guild.
local blk = newClient("Blk Hart", { hogger }, { blocked = { CHANNEL = true }, guild = "Wardens" })
local gmate = newClient("Gm Hart", { hogger }, { guild = "Wardens" })
blk.ns.SetEnabled(true) gmate.ns.SetEnabled(true) run(15)
blk.ns.Comm.Search() run(5)
check(blk.printed[#blk.printed]:find("cannot send") and gmate.ns.Matcher.Get("Blk Hart") == nil,
	"a client that refuses the channel says so; nothing goes to the guild")


-- The panel builds and refreshes with a session and a player found (stub frames).
ana.ns.UI.Show()
ana.ns.UI.Refresh()
check(ana.ns.UI.IsShown(), "panel builds and refreshes with a search and a player found")

-- Message size and decode round trip.
local many = {}
for i = 1, 40 do many[i] = { id = 100000 + i, kind = "k" } end
local text, n = ana.ns.Protocol.Search(many)
check(#text <= 255 and n < 40, "search text cut to 255 bytes (" .. #text .. " bytes, " .. n .. " quests)")
local m = ana.ns.Protocol.Decode(text)
check(m and m.kind == "S" and #m.quests == n and m.class == "WARRIOR" and m.langs and m.langs.code == "e", "decode round trip (with langs)")
check(ana.ns.Protocol.Decode("S|zz|1|2") == nil and ana.ns.Protocol.Decode(("x"):rep(300)) == nil, "malformed messages dropped")
check(ana.ns.Protocol.Decode("S|abc123|1436|400|500|20|WARRIOR|0|gA|176:n,86:l") == nil,
	"a search without the language field is malformed")
local unknown = ana.ns.Protocol.Decode("S|abc123|1436|400|500|20|WARRIOR|0|gA|z|176:n")
check(unknown and unknown.langs == nil and #unknown.quests == 1, "an unknown language letter decodes with no language")
check(ana.ns.Lang.Decode("f").code == "f" and ana.ns.Lang.Decode("f/f") == nil, "language payload is exactly one known letter")

-- With Polestar: the live step's quest comes first, the panel docks beside
-- the guide window, and the guide menu gets our rows.
local handlers, skinned = {}, {}
local window = { HookScript = function() end, IsShown = function() return true end, GetRight = function() return 400 end, GetEffectiveScale = function() return 1 end }
local nav = { GetNumChildren = function() return 0 end, GetChildren = function() end }
nav.Lookup = { GetFrameLevel = function() return 5 end, SetFrameLevel = function() end,
	GetPoint = function() return "RIGHT", nav, "RIGHT", -32, 0 end,
	SetPoint = function() end, Show = function() end, Hide = function() end }
nav.Menu = { GetPoint = function() return "RIGHT", nav, "RIGHT", -8, 0 end, SetPoint = function() end }
local shownMenu
local function guideMenuItems()
	return { { bar = {} }, { separator = true }, { text = "Choose guide", icon = "search" }, { separator = true },
		{ text = "Clean up quest log", icon = "cross" }, { separator = true }, { text = "Quick settings", icon = "sliders" },
		{ text = "Settings", icon = "gear" }, { separator = true }, { text = "Reset guide progress", icon = "reset", color = "danger" } }
end
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
	Free = { MenuItems = function() return { { text = "Free mode" } } end },
	Widgets = { ShowMenu = function(_, items) shownMenu = items end },
	UI = { GuideFrame = { menuButton = nav.Menu } },
}
local dee = newClient("Dee Moss", { hogger, boars }, { polestar = fakePolestar })
local rel2 = dee.ns.Quests.Relevant()
check(rel2[1].id == 86 and rel2[1].step == true, "Polestar live step quest first (" .. rel2[1].id .. ")")
check(handlers.STEP_CHANGED ~= nil and handlers.GUIDE_CHANGED ~= nil, "subscribed to Polestar STEP_CHANGED / GUIDE_CHANGED")
check(dee.ns.headerButtonFrame == nil, "no icon is added to the guide window's header")
fakePolestar.Widgets.ShowMenu(nav.Menu, guideMenuItems(), { short = true })
local items = shownMenu
check(#items == 11 and items[6].text == "Group Finder" and items[7].separator and items[8].text == "Quick settings",
	"the guide menu gets one row, Group Finder, at the end of the quest log group, before the settings")
dee.ns.SetEnabled(true)
run(15)
check(not dee.ns.UI.IsShown(), "panel is closed before using the menu")
items[6].onClick()
check(dee.ns.UI.IsShown(), "the menu row opens the panel, where Find a group is")
dee.ns.UI.Toggle()
fakePolestar.Widgets.ShowMenu({}, guideMenuItems(), { short = true })
check(#shownMenu == 10, "another anchor's menu is left alone")
local twice = guideMenuItems()
dee.ns.PolestarMenu.AddTo(twice)
fakePolestar.Widgets.ShowMenu(nav.Menu, twice, { short = true })
check(#shownMenu == 11, "our row is added once")
local orig = fakePolestar.Widgets.ShowMenu
fakePolestar.Widgets.ShowMenu = function(_, it) shownMenu = it end
dee.fire("ADDON_LOADED", "Polestar_Options") run(1)
check(fakePolestar.Widgets.ShowMenu ~= orig and dee.ns.PolestarMenu.Wrapped(), "when Polestar replaces ShowMenu, the wrap comes back")
-- Active search, no one found yet: a lone player with a unique quest.
local loneQ = { id = 4242, title = "Supplies to Auberdine", obj = { { "Bundle of Furs: 0/1", "item" } } }
local lea = newClient("Lea Grove", { loneQ }, { x = 0.5, y = 0.5 })
lea.ns.SetEnabled(true)
run(15)
lea.ns.Channels.Test()
run(6)
lea.PSGroupFinder_Search()
lea.ns.UI.Show()
lea.ns.UI.Refresh()
check(lea.ns.Session.Active() and #lea.ns.Matcher.List() == 0, "Lea is searching and has no one yet")
check(lea.ns.UI.EmptyCaption() == "Searching…",
	"active search with no one found, while answers come: Searching…")
run(21) lea.ns.UI.Refresh()
check(lea.ns.Session.Active() and lea.ns.UI.EmptyCaption():find("later show up here", 1, true),
	"after the wait, still nobody: later searches will show up here")
lea.ns.Session.Stop("manual")
lea.ns.UI.Refresh()
check(lea.ns.UI.EmptyCaption() == "No one yet. Press Find a group.",
	"with no search in progress the empty caption invites to search")
lea.ns.UI.Toggle()
fakePolestar.Engine.GetGuide = function() error("internal API moved") end
handlers.STEP_CHANGED()
check(#dee.ns.Quests.Relevant() == 2, "Engine failure falls back to the quest log")


---------------------------------------------------------------------------
-- A search is a session, objectives leave it, auto-group
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
eve.ns.Channels.Test() run(6)
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
check(eve.printed[#eve.printed]:find("Objective done") ~= nil and eve.printed[#eve.printed]:find("2 quest"), "the player is told in one line (objective done, 2 quests left)")
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
hal.ns.Channels.Test() run(6)
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
if lou.ns.Protocol.sid < max.ns.Protocol.sid then invitee, inviter = max, lou end
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
pia.ns.Channels.Test() run(6)
run(30)
check(ned.ns.Lang.DefaultCode() == "e" and ned.ns.Lang.Encode() == "e" and ned.ns.Lang.Search()[1] == "e", "an English client defaults to EN only")
check(not pia.ns.Lang.Compatible(ned.ns.Lang.Decode(ned.ns.Lang.Encode())), "FR search does not list an EN client")
check(pia.ns.Lang.Compatible(mia.ns.Lang.Decode(mia.ns.Lang.Encode())), "two FR-only players are compatible")
pia.PSGroupFinder_Search()
run(8)
local function hasPeer(c, who) return c.ns.Matcher.Get(who) ~= nil end
check(not hasPeer(pia, "Ned Lang") and hasPeer(pia, "Mia Lang"), "Pia (FR) finds Mia (FR) and not Ned (EN)")
pia.ns.Lang.SetAcceptAll(true)
check(pia.ns.Lang.Encode() == "f" and pia.ns.Lang.MineSummary() == "All", "accept-all still broadcasts only the client letter")
check(pia.ns.Lang.Compatible(ned.ns.Lang.Decode(ned.ns.Lang.Encode())), "Pia with All lists Ned (unilateral)")
check(not ned.ns.Lang.Compatible(pia.ns.Lang.Decode(pia.ns.Lang.Encode())), "Ned (EN only) still does not list Pia: each side filters alone")
pia.ns.Lang.SetAcceptAll(false)
pia.ns.Lang.SetSearch("e", true)
check(pia.ns.Lang.Encode() == "f" and pia.ns.Lang.MineSummary() == "FR/EN", "adding EN to the search does not change the payload")
check(pia.ns.Lang.Compatible(ned.ns.Lang.Decode("e")) and not ned.ns.Lang.Compatible(pia.ns.Lang.Decode("f")),
	"Pia searching FR+EN lists Ned; Ned still searching EN only does not list Pia")
check(pia.ns.Lang.Summary({ code = "f" }) == "FR", "list label is the peer's client language")
pia.ns.Lang.SetSearch("e", false)
check(not pia.ns.Lang.Compatible(nil), "a peer with no known language is hidden when we don't accept all")
pia.ns.Lang.SetAcceptAll(true)
check(pia.ns.Lang.Compatible(nil), "a peer with no known language is visible when we accept all")

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
for _, c in ipairs({ qua, rex }) do c.ns.Channels.Test() end
run(6)
run(30)

-- Wire format: the new messages are invisible to a v1.0 reader and decode here.
local qtext = qua.ns.Protocol.QuestSearch(12345)
check(qtext:match("^Q|") and #qtext < 80 and not qtext:match("^([SR])|"), "Q is a new message type a v1.0 client does not read")
local qm = qua.ns.Protocol.Decode(qtext)
check(qm and qm.kind == "Q" and #qm.quests == 1 and qm.quests[1].id == 12345 and qm.langs and qm.langs.code == "f", "Q decodes with its quest and language")
local am = qua.ns.Protocol.Decode(qua.ns.Protocol.QuestReply(12345, 80))
check(am and am.kind == "A" and am.quests[1].id == 12345 and am.quests[1].pct == 80, "A decodes with the percent")
check(qua.ns.Protocol.Decode("S|abc123|1436|400|500|20|WARRIOR|0|gA|f|176:n").quests[1].pct == nil, "S quests carry no percent")

-- Quest panel: opened with no result yet.
qua.ns.QuestUI.Open(12345)
check(qua.ns.QuestUI.IsShown() and qua.ns.QuestUI.Quest() == 12345 and not qua.ns.UI.IsShown(), "quest panel opens in quest mode, the main panel is not shown")
check(qua.ns.QuestUI.EmptyCaption() == "No one yet. Press Search for this quest.", "quest panel: empty caption before any search")
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
check(qua.ns.QuestUI.EmptyCaption() == nil or qua.ns.QuestUI.EmptyCaption() ~= "No one yet. Press Search for this quest.", "panel no longer says nobody")
qua.ns.QuestUI.Refresh()
local qrowFrames = qua.ns.QuestUI.RowFrames()
check(qrowFrames[1] and qrowFrames[1].entry and qrowFrames[1].entry.name ~= nil and qrowFrames[1].invite ~= nil, "quest panel shows a row with Whisper / Invite for the player")

-- Throttle: one quest search every 15 s; replies answered once per asker.
check(not qua.ns.Comm.SearchQuest(12345) and qua.printed[#qua.printed]:find("Wait"), "second quest search within 15 s is refused")
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
qua.fire("CHAT_MSG_ADDON", "PSGF", qua.ns.Protocol.QuestReply(777, 50):gsub("^A|%x+", "A|abcdef"), "WHISPER", "Zed Nobody")
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
-- The quest buttons (Polestar rows, tooltip + Alt-click)
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
hal2.ns.GoalRows.Scan()
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
check(gRows[1].psgfBtn.Icon and gRows[1].psgfBtn.Icon._texture and gRows[1].psgfBtn.Icon._texture:find("icon%-group"),
	"the goal-row button uses our group texture")
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

hal2.ns.GoalRows.Report()

-- Without Polestar and without any quest log, nothing breaks.
rex.ns.GoalRows.Scan()
check(true, "scan with no Polestar does nothing")

---------------------------------------------------------------------------
-- Leaving a group formed through the finder
---------------------------------------------------------------------------
local function lq(id, have) return { id = id, title = "Quest " .. id, obj = { { "Thing slain: " .. have .. "/6", "monster" } } } end
local function lastOf(c, chatType)
	for i = #c.chat, 1, -1 do if c.chat[i][2] == chatType then return c.chat[i] end end
end
local function count(c, chatType)
	local n = 0
	for _, m in ipairs(c.chat) do if m[2] == chatType then n = n + 1 end end
	return n
end
local function tickBox(c, seconds)
	local f = c.ns.PartyBox.Frame()
	if f and f._OnUpdate then f._OnUpdate(f, seconds) end
end
local rae = newClient("Rae Fox", { lq(11001, 0), lq(11002, 0) }, { x = 0.1, y = 0.1, locale = "frFR" })
local sam = newClient("Sam Lee", { lq(11001, 0), lq(11002, 0) }, { x = 0.11, y = 0.1, locale = "frFR" })
local noa = newClient("Noa Bell", { lq(11001, 0) }, { x = 0.12, y = 0.1 })
for _, c in ipairs({ rae, sam, noa }) do c.ns.SetEnabled(true) end
run(15)
rae.ns.Channels.Test() run(6)
run(30)
check(sam.ns.Leave.Message() == "Thanks for the group, have fun!", "messages default to English, also on a French client")
check(ned.ns.Leave.Message() == "Thanks for the group, have fun!", "default goodbye message in English for an English client")
check(rae.ns.Get("partyBox") == true, "default: the party box (hello, goodbye) is on")
rae.PSGroupFinder_Search()
run(8)
check(rae.ns.Matcher.Get("Sam Lee") ~= nil, "Rae found Sam")
-- Rae clicks Invite on Sam's row: invitation, and the invite message whispered.
rae.ns.UI.Show()
rae.ns.UI.Refresh()
local inviteBtn
for _, r in ipairs(rae.ns.UI.RowFrames()) do if type(r.entry) == "table" and r.entry.name == "Sam Lee" then inviteBtn = r.invite end end
check(inviteBtn ~= nil and inviteBtn.psTip() == "Invite" and inviteBtn.Icon._texture:find("icon%-invite"),
	"Sam's row exists with its Invite icon button")
local samRow
for _, r in ipairs(rae.ns.UI.RowFrames()) do if type(r.entry) == "table" and r.entry.name == "Sam Lee" then samRow = r end end
check(samRow.whisper.Icon._texture:find("icon%-whisper") and samRow.whisper.psTip == "Whisper", "...and a Whisper icon (speech bubble)")
check(samRow.info._text:find("Quest 11001") and samRow.info._text:find("0/6 Thing slain"),
	"the row shows the quest and the player's progress on it, small (x/y from their counts)")
inviteBtn._OnClick(inviteBtn)
local w = lastOf(rae, "WHISPER")
check(w and w[3] == "Sam Lee" and w[1] == "Hi! I'm on Quest 11001, Quest 11002 too, I've sent you an invite.",
	"Invite whispers the invite message, naming the shared quests")
run(1)
sam.AcceptGroup()
rae.fire("GROUP_ROSTER_UPDATE") sam.fire("GROUP_ROSTER_UPDATE")
run(2)
local function qset(c) local t = {} for id in pairs((c.ns.char.party or { quests = {} }).quests) do t[#t + 1] = id end table.sort(t) return t end
local rs, ss = qset(rae), qset(sam)
check(#rs == 2 and rs[1] == 11001 and rs[2] == 11002, "inviter remembers the shared quests of the group")
check(#ss == 2, "the player who accepted the invitation remembers them too")
-- Hello: the box offers Say hello for 5 s; only a click (or the key) says it.
check(rae.ns.PartyBox.Mode() == "hello" and sam.ns.PartyBox.Mode() == "hello", "the group formed: both get the hello box")
check(rae.ns.PartyBox.Remaining() == 5, "Say hello is offered for 5 s")
rae.ns.PartyBox.Main()
local hi = lastOf(rae, "PARTY")
check(hi and hi[1] == "Hi all! I'm on Quest 11001 0/6 Thing slain / Quest 11002 0/6 Thing slain.",
	"Say hello says the hello message in /p with the quest links and what is left (x/y)")
check(rae.ns.PartyBox.Mode() == nil, "the box closes once hello is said")
tickBox(sam, 6)
check(count(sam, "PARTY") == 0 and sam.ns.PartyBox.Mode() == nil, "after 5 s without a click the box goes and nothing is said")
sam.PSGroupFinder_Hello()
check(count(sam, "PARTY") == 0, "the Say hello key does nothing once the chance is gone")
check(rae.leaves == 0, "nothing else happens while quests are open")

-- One quest done: nothing. Both done: the goodbye box, no automatic leave.
rae.quests[1].obj[1][3] = true
rae.QuestLogUpdate()
run(5)
check(rae.ns.PartyBox.Mode() == nil, "one quest of two done: no goodbye yet")
rae.quests[2].complete = true
rae.QuestLogUpdate()
run(5)
check(rae.ns.PartyBox.Mode() == "goodbye", "all the group's quests done: the goodbye box appears")
check(rae.ns.PartyBox.Remaining() == 30, "it stays 30 s")
check(sam.ns.PartyBox.Mode() == nil, "Sam still has open quests: no goodbye for him")
-- Time out: the box goes, you stay, and it is not offered again.
tickBox(rae, 31)
check(rae.ns.PartyBox.Mode() == nil and rae.leaves == 0 and count(rae, "PARTY") == 1, "after 30 s the box goes; nothing said, nobody left")
rae.QuestLogUpdate() run(5)
check(rae.ns.PartyBox.Mode() == nil, "goodbye is not offered again for this group")

-- A second group: Goodbye & leave says the message, then leaves.
local tia = newClient("Tia Moon", { lq(11001, 0) }, { x = 0.1, y = 0.2 })
tia.ns.SetEnabled(true) run(15) tia.ns.Channels.Test() run(6) run(30)
tia.ns.Messages.Save("goodbye", "Thanks, take care!")
noa.PSGroupFinder_Search() run(8)
check(noa.ns.Matcher.Get("Tia Moon") ~= nil, "Noa found Tia")
noa.ns.Leave.NoteInvite("Tia Moon", noa.ns.Matcher.Get("Tia Moon").quests)
noa.C_PartyInfo.InviteUnit("Tia Moon")
run(1)
tia.AcceptGroup()
noa.fire("GROUP_ROSTER_UPDATE") tia.fire("GROUP_ROSTER_UPDATE") run(2)
check(#qset(tia) == 1 and qset(tia)[1] == 11001, "Tia remembers quest 11001")
tia.ns.PartyBox.Other()
tia.quests[1].obj[1][3] = true
tia.QuestLogUpdate() run(5)
check(tia.ns.PartyBox.Mode() == "goodbye" and tia.leaves == 0, "goodbye box shown, still nothing said or left")
tia.ns.PartyBox.Main()
check(lastOf(tia, "PARTY")[1] == "Thanks, take care!", "Goodbye & leave: the goodbye message first (PARTY)")
check(tia.leaves == 1 and party["Tia Moon"] == nil, "...then the party is left")
check(tia.ns.char.party == nil, "the memory of the group is cleared")

-- An empty goodbye message: the button only leaves.
local uri = newClient("Uri Cole", { lq(11001, 0) }, { x = 0.1, y = 0.3 })
uri.ns.SetEnabled(true) run(15) uri.ns.Channels.Test() run(6) run(30)
uri.ns.Messages.Save("goodbye", "")
uri.ns.Messages.Save("hello", "")
check(not uri.ns.Messages.On("goodbye"), "an empty message is turned off")
uri.PSGroupFinder_Search() run(8)
local noaE = uri.ns.Matcher.Get("Noa Bell")
check(noaE ~= nil, "Uri found Noa")
party["Noa Bell"] = nil
uri.ns.Leave.NoteInvite("Noa Bell", noaE.quests)
uri.C_PartyInfo.InviteUnit("Noa Bell") run(1)
noa.AcceptGroup()
uri.fire("GROUP_ROSTER_UPDATE") noa.fire("GROUP_ROSTER_UPDATE") run(2)
check(uri.ns.PartyBox.Mode() == nil, "an empty hello message: no hello box")
uri.quests[1].complete = true
uri.QuestLogUpdate() run(5)
uri.ns.PartyBox.Main()
check(count(uri, "PARTY") == 0 and uri.leaves == 1, "empty goodbye message: the button only leaves")

-- A group NOT formed through the finder: no box, nothing remembered.
local vic = newClient("Vic Hale", { lq(11001, 0) }, {})
local wyn = newClient("Wyn Cass", { lq(11001, 0) }, {})
vic.ns.SetEnabled(true) wyn.ns.SetEnabled(true) run(15)
party["Vic Hale"] = { "Vic Hale", "Wyn Cass" } party["Wyn Cass"] = party["Vic Hale"]
vic.fire("GROUP_ROSTER_UPDATE") run(2)
vic.quests[1].complete = true vic.QuestLogUpdate() run(5)
check(vic.ns.char.party == nil and vic.ns.PartyBox.Mode() == nil, "a group formed by hand gets no hello and no goodbye")

-- Option off: no box. Abandoned quests do not count as done.
local xan = newClient("Xan Dyle", { lq(11001, 0), lq(11002, 0) }, { x = 0.1, y = 0.4 })
local yui = newClient("Yui Reed", { lq(11001, 0), lq(11002, 0) }, { x = 0.1, y = 0.41 })
xan.ns.SetEnabled(true) yui.ns.SetEnabled(true) run(15) xan.ns.Channels.Test() run(6) run(30)
xan.ns.Set("partyBox", false)
xan.PSGroupFinder_Search() run(8)
xan.ns.Leave.NoteInvite("Yui Reed", { 11001, 11002 })
xan.C_PartyInfo.InviteUnit("Yui Reed") run(1)
yui.AcceptGroup()
xan.fire("GROUP_ROSTER_UPDATE") yui.fire("GROUP_ROSTER_UPDATE") run(2)
check(xan.ns.PartyBox.Mode() == nil, "partyBox off: no hello box")
yui.ns.PartyBox.Other()
xan.quests[1].complete = true xan.quests[2].complete = true
xan.QuestLogUpdate() run(5)
check(xan.ns.PartyBox.Mode() == nil, "partyBox off: no goodbye box")
xan.ns.Set("partyBox", true)
xan.QuestLogUpdate() run(5)
check(xan.ns.PartyBox.Mode() == "goodbye", "...and back on, goodbye is offered")
-- Abandon: a quest that left the log without being done drops out of the memory.
yui.quests[2] = nil
yui.QuestLogUpdate() run(5)
check(#qset(yui) == 1 and qset(yui)[1] == 11001, "an abandoned quest is forgotten, the other still counts")
check(yui.ns.PartyBox.Mode() == nil, "...and nothing is offered while the other is open")
-- Group ends: memory cleared, box closed.
party["Yui Reed"] = nil party["Xan Dyle"] = nil
yui.fire("GROUP_ROSTER_UPDATE") xan.fire("GROUP_ROSTER_UPDATE") run(2)
check(yui.ns.char.party == nil and xan.ns.PartyBox.Mode() == nil, "the memory and the box go when the group ends")

-- Messages: saved texts, default, off; the Messages window and its previews.
local M = sam.ns.Messages
M.Save("goodbye", "Hi |cffff0000!")
check(sam.ns.Get("leaveMsg") == "Hi cffff0000!", "escape sequences are stripped from a saved message")
M.Save("goodbye", "Thanks for the group, have fun!")
check(sam.ns.Get("leaveMsg") == false and M.Template("goodbye") == "Thanks for the group, have fun!", "saving the default text stores it as unset")
check(M.Expand("ask", { 11001 }) == "Hi! I'm on Quest 11001 too, could you invite me to your group?", "{quests} is filled in")
check(M.Fill("On {quests}: {progress}", { 11001 }) == "On Quest 11001: Quest 11001 0/6 Thing slain", "{progress} adds what is left of each quest as x/y")
check(M.ObjectiveText({ text = "4/12 Defias Pillager slain" }) == "4/12 Defias Pillager slain" and M.ObjectiveText({ text = "Defias Pillager slain: 4/12" }) == "4/12 Defias Pillager slain", "objectives read the same whichever way the client writes them")
sam.ns.UI.ShowMessages()
check(sam.ns.UI.MessagesShown() and #sam.ns.UI.MessageBlocks() == 5, "the Messages window opens with its five messages")
local blocks = sam.ns.UI.MessageBlocks()
check(blocks[4].preview._text:find("Hi all!") and blocks[4].preview._text:find("0/6 Thing slain"), "the hello preview shows the quests with progress")
blocks[2].edit._text = "Yo {quests}"
blocks[2].edit._OnTextChanged(blocks[2].edit, true)
check(blocks[2].preview._text:find("Yo Quest 11001"), "the preview follows the text as it is typed")
blocks[2].edit._text = ""
blocks[2].edit._OnEnterPressed(blocks[2].edit)
check(not M.On("invite") and blocks[2].preview._text:find("not sent"), "emptying a text turns it off, the preview says so")
blocks[2].reset._OnClick(blocks[2].reset)
check(M.On("invite") and sam.ns.Get("inviteMsg") == false, "Default brings the default text back")
sam.ns.UI.ShowMessages()

-- Ask: a player already in a group cannot be invited; we ask them by whisper.
local ola = newClient("Ola Dunn", { lq(11003, 0) }, { x = 0.3, y = 0.3 })
local pam = newClient("Pam Dunn", { lq(11003, 0) }, { x = 0.31, y = 0.3 })
local quin = newClient("Quin Dunn", {}, {})
ola.ns.SetEnabled(true) pam.ns.SetEnabled(true) run(15) ola.ns.Channels.Test() run(6) run(30)
party["Pam Dunn"] = { "Pam Dunn", "Quin Dunn" } party["Quin Dunn"] = party["Pam Dunn"]
ola.PSGroupFinder_Search() run(8)
ola.ns.UI.Show() ola.ns.UI.Refresh()
local askBtn
for _, r in ipairs(ola.ns.UI.RowFrames()) do if type(r.entry) == "table" and r.entry.name == "Pam Dunn" then askBtn = r.invite end end
check(askBtn and askBtn.psTip():find("^Ask to join"), "a player already in a group: the invite icon asks to join (tooltip)")
local invitedBefore = #ola.invited
askBtn._OnClick(askBtn)
local aw = lastOf(ola, "WHISPER")
check(#ola.invited == invitedBefore and aw and aw[3] == "Pam Dunn" and aw[1]:find("could you invite me"),
	"Ask whispers the ask message and sends no invitation")
party["Pam Dunn"] = nil party["Quin Dunn"] = nil

-- Leaving through the game says nothing; our Leave says goodbye for a finder group only.
local pip = newClient("Pip Wren", { lq(11001, 0) }, { x = 0.2, y = 0.2 })
local kit = newClient("Kit Vale", { lq(11001, 0) }, { x = 0.21, y = 0.2 })
pip.ns.SetEnabled(true) kit.ns.SetEnabled(true) run(15)
pip.ns.Channels.Test() run(6) run(30)
pip.ns.Messages.Save("goodbye", "Have fun, thanks!")
pip.PSGroupFinder_Search() run(8)
check(pip.ns.Matcher.Get("Kit Vale") ~= nil, "Pip found Kit")
pip.ns.Leave.NoteInvite("Kit Vale", pip.ns.Matcher.Get("Kit Vale").quests)
pip.C_PartyInfo.InviteUnit("Kit Vale") run(1)
kit.AcceptGroup()
pip.fire("GROUP_ROSTER_UPDATE") kit.fire("GROUP_ROSTER_UPDATE") run(2)
pip.ns.PartyBox.Other()
check(pip.ns.char.party ~= nil, "Pip remembers the finder group")
pip.LeaveParty()
check(count(pip, "PARTY") == 0 and pip.leaves == 1, "leaving via the game (LeaveParty) says nothing in /p")

local abb = newClient("Abb Cole", { lq(11001, 0) }, {})
local bea = newClient("Bea Cole", { lq(11001, 0) }, {})
abb.ns.SetEnabled(true) bea.ns.SetEnabled(true) run(15)
party["Abb Cole"] = { "Abb Cole", "Bea Cole" } party["Bea Cole"] = party["Abb Cole"]
abb.fire("GROUP_ROSTER_UPDATE") run(1)
check(abb.ns.char.party == nil, "a hand-formed group is not in the finder's memory")
abb.ns.Leave.Do()
check(count(abb, "PARTY") == 0 and abb.leaves == 1, "our Leave on a hand-formed group says nothing")

-- Panel "Leave the group" button: visible only in a party; says goodbye for a finder group.
local cy = newClient("Cy Moss", { lq(11001, 0) }, { x = 0.25, y = 0.2 })
local dy = newClient("Dy Moss", { lq(11001, 0) }, { x = 0.26, y = 0.2 })
cy.ns.SetEnabled(true) dy.ns.SetEnabled(true) run(15)
cy.ns.Channels.Test() run(6) run(30)
cy.ns.Messages.Save("goodbye", "Goodbye")
cy.ns.UI.Show()
cy.ns.UI.Refresh()
check(not (cy.ns.UI.LeaveGroupButton() and cy.ns.UI.LeaveGroupButton():IsShown()),
	"the Leave the group button is hidden when not in a party")
cy.PSGroupFinder_Search() run(8)
cy.ns.Leave.NoteInvite("Dy Moss", { 11001 })
cy.C_PartyInfo.InviteUnit("Dy Moss") run(1)
dy.AcceptGroup()
cy.fire("GROUP_ROSTER_UPDATE") dy.fire("GROUP_ROSTER_UPDATE") run(2)
-- Key binding: Say hello now, while the box counts down.
cy.PSGroupFinder_Hello()
check(lastOf(cy, "PARTY") and lastOf(cy, "PARTY")[1]:find("^Hi all!") and cy.ns.PartyBox.Mode() == nil,
	"the Say hello key says hello at once and closes the box")
cy.ns.UI.Show()
cy.ns.UI.Refresh()
local lg = cy.ns.UI.LeaveGroupButton()
check(lg and lg:IsShown(), "the Leave the group button appears while in a party")
check(cy.ns.UI.LeaveQuietButton():IsShown() and lg:GetText() == "Goodbye & leave",
	"with the goodbye message on: two choices, Goodbye & leave and Leave")
cy.ns.Messages.SetEnabled("goodbye", false) cy.ns.UI.Refresh()
check(not cy.ns.UI.LeaveQuietButton():IsShown() and lg:GetText() == "Leave the group",
	"with the goodbye message off: one Leave the group")
cy.ns.Messages.SetEnabled("goodbye", true) cy.ns.UI.Refresh()
lg._OnClick(lg)
check(lastOf(cy, "PARTY")[1] == "Goodbye" and cy.leaves == 1, "the panel Leave button says goodbye then leaves")
cy.ns.UI.Refresh()
check(not cy.ns.UI.LeaveGroupButton():IsShown(), "the Leave button hides again once out of the group")
-- Key binding: Say goodbye and leave.
dy.ns.PartyBox.Other()
party["Dy Moss"] = { "Dy Moss", "Eve X" } party["Eve X"] = party["Dy Moss"]
dy.PSGroupFinder_Goodbye()
check(dy.leaves == 1, "the goodbye key leaves the group")

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
check(ico.ns.ICON:find("PSGroupFinder") and ico.ns.ICON:find("icon%-group"),
	"the sidebar icon is a full path to our Media/icon-group texture")
check(#capturedOpts >= 1 and capturedOpts[1].icon == ico.ns.ICON and capturedOpts[1].key == "groupfinder",
	"RegisterOptions (public API) receives our icon on the Group Finder page")
check(fp3.UI.Options.Kit.pages[1].icon == ico.ns.ICON,
	"the registered page's icon is set (internal Kit.pages, under pcall)")
local items = fp3.UI.Options.Grouped.NavItems()
check(items[1].icon == "icon-note" and items[2].key == "groupfinder" and items[2].icon == ico.ns.ICON,
	"Grouped.NavItems fills our icon when the layout omitted it, and leaves the others alone")
local painted
local row = { Icon = { SetTexture = function(_, path) painted = path end, SetSize = function() end, Show = function() end } }
fp3.Widgets.NavRowAfter(row, { key = "groupfinder" }, false)
check(painted == ico.ns.ICON, "NavRowAfter (internal) paints our 16px icon on the Group Finder row")
painted = nil
fp3.Widgets.NavRowAfter(row, { key = "guide", icon = "icon-note" }, false)
check(painted == nil and navPainted.other >= 1, "NavRowAfter does not rewrite another page's icon")
-- Without the options window, the hook is a no-op (the public icon field remains).
local fp4 = {}
for k, v in pairs(fakePolestar) do fp4[k] = v end
fp4.RegisterOptions = function() return true end
local ico2 = newClient("Ico Two", { hogger }, { polestar = fp4 })
check(ico2.ns.OpenOptions() == false, "without Polestar's options window, the icon hook and Options are silent no-ops")

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

---------------------------------------------------------------------------
-- Chat noise: the game's notices about our own traffic are hidden, unless
-- debug is on.
---------------------------------------------------------------------------
local zoe = newClient("Zoe Hart", { hogger }, {})
zoe.ns.SetEnabled(true)
run(15)
local sys, notice = zoe.chatFilters.CHAT_MSG_SYSTEM, zoe.chatFilters.CHAT_MSG_CHANNEL_NOTICE
check(type(sys) == "function" and type(notice) == "function", "chat filters registered for system lines and channel notices")
zoe.ns.Channels.Whisper("X|abc123", "Gone Player")
check(sys(nil, "CHAT_MSG_SYSTEM", "No player named 'Gone Player' is currently playing.") == true,
	"'no player named' after our addon whisper is hidden")
check(sys(nil, "CHAT_MSG_SYSTEM", "No player named 'Someone Else' is currently playing.") == false,
	"'no player named' for a name we did not whisper stays")
check(sys(nil, "CHAT_MSG_SYSTEM", "Ana Smith has come online.") == false, "other system lines stay")
run(11)
check(sys(nil, "CHAT_MSG_SYSTEM", "No player named 'Gone Player' is currently playing.") == false,
	"the hiding only lasts a few seconds after our whisper")
check(notice(nil, "CHAT_MSG_CHANNEL_NOTICE", "YOU_CHANGED", "", "", "5. PSGroupFinder") == true,
	"notices of the hidden channel are hidden")
check(notice(nil, "CHAT_MSG_CHANNEL_NOTICE", "YOU_CHANGED", "", "", "1. General - Elwynn Forest") == false,
	"notices of other channels stay")
zoe.SlashCmdList.PSGROUPFINDER("debug")
check(zoe.printed[#zoe.printed]:find("Debug mode on"), "/psgf debug says what it does")
zoe.ns.Channels.Whisper("X|abc123", "Gone Player")
check(sys(nil, "CHAT_MSG_SYSTEM", "No player named 'Gone Player' is currently playing.") == false
	and notice(nil, "CHAT_MSG_CHANNEL_NOTICE", "YOU_CHANGED", "", "", "5. PSGroupFinder") == false,
	"with debug on, nothing is hidden")
local before = #zoe.printed
zoe.ns.Comm.Search()
check(#zoe.printed > before + 1, "with debug on, the messages sent are traced in chat")
zoe.SlashCmdList.PSGROUPFINDER("debug")
before = #zoe.printed
zoe.ns.Channels.Test()
run(6)
check(zoe.printed[before + 1]:find("Testing") and zoe.printed[#zoe.printed]:find("channel in use"), "the test, on request, reports each channel and the one in use")

---------------------------------------------------------------------------
-- Announce: a looking-for-group line in public chat, only on a click
---------------------------------------------------------------------------
local longQ = { id = 7001, title = ("Very long quest title "):rep(8), obj = { { "Thing slain: 0/5", "monster" } } }
local amy = newClient("Amy Rook", { hogger, boars }, {})
check(amy.ns.Announce.Target() == "GENERAL", "announce default: the zone's General channel")
check(amy.ns.Announce.Text({ 176, 86 }) == "LFG Wanted: Hogger, Pie for Billy, whisper me!", "the English line names the quests")
check(amy.ns.Announce.Send() == false and #amy.chat == 0, "nothing is announced while the finder is off")
amy.ns.SetEnabled(true)
run(15)
check(amy.ns.Announce.Send() == true, "announce goes out from a click")
check(#amy.chat == 1 and amy.chat[1][2] == "CHANNEL" and amy.chat[1][3] == 1
	and amy.chat[1][1] == "LFG Wanted: Hogger, Pie for Billy, whisper me!",
	"the line goes to General (channel 1) and names the relevant quests")
check(amy.ns.Announce.Send() == false and #amy.chat == 1 and amy.printed[#amy.printed]:find("Wait"),
	"a second announce within a minute is refused")
run(61)
amy.ns.Set("announceTo", "LFG")
check(amy.ns.Announce.Send() == false and #amy.chat == 1 and amy.printed[#amy.printed]:find("looking%-for%-group"),
	"the LFG channel, not joined, is refused with a hint")
amy.channels = { 1, "General", false, 4, "LookingForGroup", false }
check(amy.ns.Announce.Send() == true and amy.chat[2][3] == 4, "the LFG channel is found by name once joined")
run(61)
amy.ns.Set("announceTo", "YELL")
amy.ns.Messages.Save("announce", "Need help on {quests}!")
check(amy.ns.Announce.Send() == true and amy.chat[3][2] == "YELL" and amy.chat[3][1] == "Need help on Wanted: Hogger, Pie for Billy!",
	"yell, with the player's own announce text")
run(61)
amy.ns.Messages.Save("announce", "")
check(amy.ns.Announce.Send() == false and amy.printed[#amy.printed]:find("Messages"), "an empty announce message is not sent, with a hint")
amy.ns.Messages.Save("announce", amy.ns.Messages.Default("announce"))
-- Quest links: used only when the client's link names this very quest.
amy.GetQuestLink = function(id) return "|cffffff00|Hquest:" .. id .. ":10|h[Hogger]|h|r" end
check(amy.ns.Announce.Text({ 176 }):find("|Hquest:176:", 1, true), "the client's quest link is used when it names the quest")
amy.GetQuestLink = function() return "|cffffff00|Hquest:999:10|h[Other]|h|r" end
check(amy.ns.Announce.Text({ 176 }) == "LFG Wanted: Hogger, whisper me!", "a link for another quest (log index API) is not used")
amy.GetQuestLink = nil
-- Long titles: quests are dropped from the end, the line stays within 255 bytes.
local ally = newClient("Al Rook", { longQ, hogger }, {})
local t = ally.ns.Announce.Text({ 7001, 7001, 176 })
check(#t <= 255 and select(2, t:gsub(", ", "")) < 2, "a long line drops quests to fit 255 bytes (" .. #t .. " bytes)")
-- During a search, the line names the quests of the search.
run(61)
amy.ns.Set("announceTo", "GENERAL")
amy.ns.Channels.Test() run(6)
amy.ns.Session.Start({ { id = 86, kind = "l" } })
check(amy.ns.Announce.Text(amy.ns.Announce.Quests()) == "LFG Pie for Billy, whisper me!", "during a search, the line names its quests")
amy.ns.Session.Stop("manual")
-- The panel: Announce, then the channel selector.
amy.ns.UI.Show()
local annBtn, annTo = amy.ns.UI.AnnounceWidgets()
check(annBtn and annTo, "the panel has Announce with a channel selector")
annTo._OnClick(annTo)
local list, trows = annTo.List()
check(list and list:IsShown() and #trows == 4, "the channel selector lists General, LFG, Say, Yell")
trows[3]._OnClick(trows[3])
check(amy.ns.Get("announceTo") == "SAY" and not list:IsShown(), "choosing Say sets the target and closes the list")
annBtn._OnClick(annBtn)
check(amy.chat[#amy.chat][2] == "SAY" and amy.chat[#amy.chat][1]:find("^LFG"), "the panel's Announce sends the line")
-- The quest panel announces that quest only.
run(61)
amy.ns.QuestUI.Open(176)
local qa = amy.ns.QuestUI.AnnounceButton()
qa._OnClick(qa)
check(amy.chat[#amy.chat][1] == "LFG Wanted: Hogger, whisper me!", "the quest panel's Announce names that quest only")
-- Slash command and key binding share the same path.
run(61)
amy.SlashCmdList.PSGROUPFINDER("announce")
check(amy.chat[#amy.chat][1]:find("Wanted: Hogger, Pie for Billy"), "/psgf announce sends the line")

-- The panel: a main view, and a settings view behind the cog in the title bar.
local fy = newClient("Fy Lark", { hogger }, {})
fy.ns.UI.Show()
check(not fy.ns.UI.Switch("autoGroup"):IsShown() and not fy.ns.UI.SettingsShown(), "the panel opens on its main view, no settings in sight")
local gear = fy.ns.UI.GearButton()
check(gear.Icon._texture:find("icon%-gear"), "the title bar has a cog")
gear._OnClick(gear)
check(fy.ns.UI.SettingsShown() and fy.ns.UI.Switch("enabled"):IsShown() and fy.ns.UI.Switch("autoGroup"):IsShown()
	and fy.ns.UI.Switch("partyBox"):IsShown(), "the cog shows the settings view, every switch by category")
check(fy.ns.UI.LangLine():IsShown(), "without Polestar's options page, the search languages are in the settings view")
gear._OnClick(gear)
check(not fy.ns.UI.SettingsShown() and not fy.ns.UI.Switch("autoGroup"):IsShown(), "the cog again goes back to the main view")
ico.ns.UI.Show()
ico.ns.UI.ToggleSettings()
check(ico.ns.UI.SettingsShown() and not ico.ns.UI.LangLine():IsShown(), "with Polestar's options page, the search languages are only there")
ico.ns.UI.ToggleSettings()
fy.ns.SetEnabled(true) run(15)
fy.ns.UI.Refresh()
local annBtn = fy.ns.UI.AnnounceWidgets()
check(annBtn:IsShown(), "on: the main view has Find a group and Announce")

-- Progress counts travel with searches and answers; the reader names them.
local prg = newClient("Prg Lee", { { id = 7301, title = "The Defias Brotherhood",
	obj = { { "Defias Pillager slain: 4/12", "monster" }, { "Defias Looter slain: 0/5", "monster" } } } }, {})
check(prg.ns.Protocol.Counts(7301) == "@4/12;0/5", "a quest's counts are encoded as numbers only (@4/12;0/5)")
local enc = prg.ns.Protocol.Search({ { id = 7301, kind = "k" } })
local dec = prg.ns.Protocol.Decode(enc)
check(dec.quests[1].id == 7301 and dec.quests[1].kind == "k" and dec.quests[1].counts[1][1] == 4 and dec.quests[1].counts[2][2] == 5,
	"search entries decode with their counts")
local rdec = prg.ns.Protocol.Decode(prg.ns.Protocol.Reply({ 7301 }))
check(rdec.quests[1].counts and rdec.quests[1].counts[1][2] == 12, "replies carry the counts too")
local adec = prg.ns.Protocol.Decode(prg.ns.Protocol.QuestReply(7301, 33))
check(adec.quests[1].pct == 33 and adec.quests[1].counts[1][1] == 4, "quest answers carry the percent and the counts")
local W = prg.ns.Widgets
check(W.PeerProgress({ counts = { [7301] = { { 4, 12 }, { 0, 5 } } } }, 7301) == "4/12 Defias Pillager slain",
	"their first open objective, named from our own log")
check(W.PeerProgress({ counts = { [7301] = { { 12, 12 }, { 2, 5 } } } }, 7301) == "2/5 Defias Looter slain",
	"a finished objective is skipped")
check(W.PeerProgress({ counts = { [7301] = { { 12, 12 }, { 5, 5 } } } }, 7301) == "done" and W.PeerProgress({ pct = 40 }, 7301) == "40%",
	"done when all are; the percent when only that is known")

-- Search languages: only those played in the game's region, plus the client's own.
local reg = newClient("Reg Vale", { hogger }, { locale = "frFR" })
reg.GetCurrentRegion = function() return 3 end
local codes = {}
for _, row in ipairs(reg.ns.Lang.Offered()) do codes[row.code] = true end
check(codes.f and codes.e and codes.d and codes.r and not codes.k and not codes.c and not codes.t,
	"Europe offers EN, FR, DE, ... but no Korean or Chinese")
reg.GetCurrentRegion = function() return 1 end
codes = {}
for _, row in ipairs(reg.ns.Lang.Offered()) do codes[row.code] = true end
check(codes.e and codes.s and codes.p and codes.f and not codes.d,
	"the Americas offer EN, ES, PT, and the client's own language (FR) stays")
reg.GetCurrentRegion = nil
check(#reg.ns.Lang.Offered() == #reg.ns.Lang.ALL, "an unknown region offers every language")

-- Each message has its own switch.
local msw = newClient("Msw Vale", { hogger }, {})
check(msw.ns.Messages.Enabled("hello") and msw.ns.Messages.Enabled("announce"), "every message is on by default")
msw.ns.Messages.SetEnabled("announce", false)
msw.ns.SetEnabled(true) run(15)
check(msw.ns.Announce.Send() == false and msw.printed[#msw.printed]:find("turned off"), "announce off: nothing is said, with a hint")
msw.ns.UI.Show() msw.ns.UI.Refresh()
check(not msw.ns.UI.AnnounceWidgets():IsShown(), "announce off: the Announce button is hidden")
msw.ns.Messages.SetEnabled("invite", false)
local before = #msw.chat
msw.ns.Widgets.Invite({ name = "Ben Stone", quests = { 176 }, size = 0 })
check(#msw.chat == before and msw.invited[#msw.invited] == "Ben Stone", "invite message off: the invitation goes, no whisper")
msw.ns.Messages.SetEnabled("hello", false)
msw.ns.Leave.NoteInvite("Ben Stone", { 176 })
msw.ns.PartyBox.ShowHello()
check(msw.ns.PartyBox.Mode() == nil, "hello off: the message box does not offer it")

-- The message box has two styles.
local sty = newClient("Sty Vale", { lq(11001, 0) }, {})
sty.ns.SetEnabled(true) run(15)
check(sty.ns.PartyBox.Style() == "polestar", "the message box style is Polestar by default")
sty.ns.Messages.SetEnabled("goodbye", false)
sty.ns.PartyBox.ShowGoodbye()
local f = sty.ns.PartyBox.Frame()
check(f.main._text:find("^Leave the group"), "goodbye off: the box offers only to leave")
sty.ns.Set("partyBoxStyle", "compact")
sty.ns.PartyBox.Refresh()
check(sty.ns.PartyBox.Style() == "compact", "the compact style can be chosen")

-- Polestar's page: an Essentials tab and a Messages tab.
local tabs = {}
for _, spec in ipairs(capturedOpts) do tabs[spec.tab] = (tabs[spec.tab] or 0) + 1 end
check(tabs.Essentials and tabs.Messages and tabs.Messages >= 7, "the options page has an Essentials tab and a Messages tab (box, its style, five messages)")
local helloSpec
for _, spec in ipairs(capturedOpts) do if spec.section == "Hello" then helloSpec = spec end end
check(helloSpec and helloSpec.controls[1].kind == "toggle" and helloSpec.controls[2].action == "PSGF_HELLO"
	and helloSpec.controls[3].kind == "button" and helloSpec.controls[3].wide,
	"a message's section: its switch and its key binding on one line, its text on a whole line")
local boxSpec, styleCtl
for _, spec in ipairs(capturedOpts) do if spec.section == "Message box style" then boxSpec = spec end end
for _, c in ipairs(boxSpec and boxSpec.controls or {}) do if c.kind == "cards" then styleCtl = c end end
check(styleCtl and #styleCtl.choices == 2, "the box style is two picture cards")
check(styleCtl.disabled() == false and helloSpec.controls[1].disabled() == false, "box on: the style cards and Hello are usable")
local card = ico.CreateFrame("Frame")
local mini = styleCtl.choices[1].draw(card) or ico.ns.PartyBox.DrawPreview(card, "polestar")
ico.ns.Set("partyBox", false)
check(mini and mini._alpha == 0.35, "box off: the style cards' pictures are dimmed")
check(styleCtl.disabled() == true and helloSpec.controls[1].disabled() == true and helloSpec.controls[3].disabled() == true,
	"box off: the style cards and the Hello rows are greyed")
ico.ns.Set("partyBox", true)
local drew, why = pcall(styleCtl.choices[1].draw, ico.CreateFrame("Frame"))
if drew then drew, why = pcall(styleCtl.choices[2].draw, ico.CreateFrame("Frame")) end
if not drew then print(why) end
check(drew, "each card draws a miniature of the box")
-- The text box laid over the wide row (Polestar's ActionRow, internal).
fp3.Widgets.ActionRow = function()
	local row = ico.CreateFrame("Button")
	row.Button = ico.CreateFrame("Button")
	return row
end
ico.fire("ADDON_LOADED", "Polestar_Options")
local trow = fp3.Widgets.ActionRow()
trow.psControl = helloSpec.controls[3]
local other = fp3.Widgets.ActionRow()
run(0.1)
local tb = ico.ns.OptionsTextBox("hello")
check(tb and rawget(trow, "psgfEdit") == tb and rawget(other, "psgfEdit") == nil, "our wide text row gets an edit box, other rows do not")
check(tb:GetText() == "Hi all! I'm on {progress}.", "the edit box holds the message's text")
tb:SetText("Yo {quests}!")
tb._OnEnterPressed()
check(ico.ns.Messages.Template("hello") == "Yo {quests}!", "Enter saves the text at once")
helloSpec.controls[3].onClick()
check(ico.ns.Messages.Template("hello") == "Hi all! I'm on {progress}." and tb:GetText() == "Hi all! I'm on {progress}.",
	"the row's button puts the default text back")
check(ico.ns.Messages.Preview("On {progress}") == "On [Red Linen Goods] 0/6 Red Linen Bandana" or #ico.ns.Messages.SampleIds() > 0,
	"with no quest worth a group, the preview uses the example quest")
local noq = newClient("Noq Fen", {}, {})
check(noq.ns.Messages.Preview("On {progress}") == "On [Red Linen Goods] 0/6 Red Linen Bandana", "the example quest: Red Linen Goods, 0/6 Red Linen Bandana")

-- Opening the panel near the live step's objective (option, off by default).
local fpN = {}
for k, v in pairs(fakePolestar) do fpN[k] = v end
fpN.Engine = { GetGuide = function() return { steps = { { goals = { { t = "loot", quest = 86 } } } } } end, GetLiveStep = function() return 1 end }
local dist = 500
fpN.Nav = { GetDistance = function() return dist end }
local nea = newClient("Nea Vale", { hogger, boars }, { polestar = fpN })
nea.ns.SetEnabled(true) run(15)
check(nea.ns.Get("openNear") == false, "opening near a quest is off by default")
dist = 50
check(nea.ns.Nearby.Check() == false and not nea.ns.UI.IsShown(), "off: nothing opens near the objective")
nea.ns.Set("openNear", true)
dist = 500
check(nea.ns.Nearby.Check() == false and not nea.ns.UI.IsShown(), "on, but far from the objective: nothing opens")
dist = 80
check(nea.ns.Nearby.Check() == true and nea.ns.UI.IsShown(), "on, near the objective of a quest worth a group: the panel opens")
check(next(nea.ns.Channels.status) == nil, "...and nothing is sent: the search stays a click")
nea.ns.UI.Toggle()
check(nea.ns.Nearby.Check() == false and not nea.ns.UI.IsShown(), "once per step: closed, it does not open again")

-- Demo mode (TEMPORARY): made-up players through the real receiving code,
-- and nothing leaves the client.
local dem = newClient("Dem Oak", { hogger, boars }, { polestar = fpN })
local demSent = 0
local demOrig = dem.C_ChatInfo.SendAddonMessage
dem.C_ChatInfo.SendAddonMessage = function(...) demSent = demSent + 1 return demOrig(...) end
local function demPrinted(pat)
	for _, m in ipairs(dem.printed) do if m:find(pat, 1, true) then return true end end
	return false
end
dem.SlashCmdList.PSGROUPFINDER("demo search")
check(demPrinted("Turn the demo on first"), "demo: subcommands wait for /psgf demo")
dem.SlashCmdList.PSGROUPFINDER("demo")
check(dem.ns.Demo.Active() and dem.ns.Get("enabled") and dem.ns.UI.IsShown(), "demo on: the finder turns on and the panel opens")
run(10)
demSent = 0
dem.SlashCmdList.PSGROUPFINDER("demo search") run(6)
check(demSent == 0, "demo: the search is not sent")
check(demPrinted("[demo]|r -> CHANNEL: search"), "demo: the search is printed instead")
check(#dem.ns.Matcher.List() == 3, "demo: the three made-up players answer the search")
local bran = dem.ns.Matcher.Get("Brannok")
check(bran and bran.size == 2 and dem.ns.Widgets.CanOnlyAsk(bran), "demo: Brannok is in a group, so the row offers Ask")
check(#dem.ns.Matcher.Get("Tibbs").quests == 1, "demo: Tibbs shares the first quest only")
local aely = dem.ns.Matcher.Get("Aelyra")
check(aely.counts and aely.counts[176], "demo: their progress comes with their answer")
-- Invite Aelyra: she joins, the hello box comes up.
dem.ns.Widgets.Invite(aely) run(4)
check(#dem.invited == 0 and count(dem, "WHISPER") == 0, "demo: the invite and its whisper are printed, not done")
check(dem.ns.InGroup() and dem.ns.Demo.IsMember("Aelyra"), "demo: Aelyra joins the pretend group")
check(dem.ns.PartyBox.Mode() == "hello", "demo: the hello box comes up")
dem.ns.PartyBox.Main()
check(count(dem, "PARTY") == 0 and demPrinted("-> PARTY: \"Hi all!"), "demo: Say hello prints the line instead of saying it")
-- Ask Brannok: he invites you.
dem.ns.Widgets.Invite(bran) run(5)
check(dem.ns.Demo.IsMember("Brannok"), "demo: after Ask, Brannok invites you and you join")
-- Progress, stop, goodbye, leave.
dem.SlashCmdList.PSGROUPFINDER("demo players") run(4)
dem.SlashCmdList.PSGROUPFINDER("demo stop") run(1)
check(dem.ns.Matcher.Get("Tibbs") == nil, "demo: Tibbs ends their search and leaves the list")
dem.SlashCmdList.PSGROUPFINDER("demo goodbye") run(3)
check(dem.ns.PartyBox.Mode() == "goodbye", "demo: the goodbye box comes up")
dem.ns.PartyBox.Main() run(1)
check(not dem.ns.InGroup() and dem.leaves == 0 and demPrinted("-> leave the party"), "demo: Goodbye & leave breaks up the pretend group, the real party is not left")
-- The channel test answers with its echo.
dem.SlashCmdList.PSGROUPFINDER("test") run(5)
check(dem.ns.Channels.status.CHANNEL and dem.ns.Channels.status.CHANNEL.state == "ok", "demo: /psgf test hears its echo")
-- Near the objective.
dem.ns.Set("openNear", true)
dem.SlashCmdList.PSGROUPFINDER("demo near") run(1)
check(dem.ns.UI.IsShown() and demPrinted("Pretending you are 50 m"), "demo near: the panel opens as if 50 m from the objective")
dem.SlashCmdList.PSGROUPFINDER("demo hello") run(2)
check(dem.ns.PartyBox.Mode() == "hello", "demo hello: the hello box at once")
dem.SlashCmdList.PSGROUPFINDER("demo")
check(not dem.ns.Demo.Active() and not dem.ns.InGroup(), "demo off: the pretend group is gone")
check(demSent == 0 and count(dem, "WHISPER") == 0 and count(dem, "PARTY") == 0, "demo: nothing at all was sent")

print("all tests passed")
