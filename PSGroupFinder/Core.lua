-- Group Finder for Polestar (PSGroupFinder): settings, events, slash commands and the key
-- binding entry points.
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
-- Everything is opt-in: with `enabled` false (the default) the addon joins
-- no channel, registers no addon prefix listener and sends nothing. Turning
-- it on joins the finder's hidden channel and answers other players'
-- searches for quests you share (`autoReply`); a search of your own only
-- ever goes out from a click or a key press.

local ADDON, ns = ...
local L = ns.L

ns.name = ADDON
ns.version = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata or function() end)(ADDON, "Version") or "dev"

local DEFAULTS = {
	enabled = false,     -- the whole feature, off until the player turns it on
	autoReply = true,    -- answer searches for quests we have (only while enabled)
	autoGroup = false,   -- invite / accept without a click after a search (opt-in)
	shareCoords = true,  -- send x/y with the map; off: the map only
	headerButton = true, -- icon in Polestar's header (false: under the window)
	searchLangs = false, -- filled in Lang.Init: the client's language
	acceptAll = false,   -- search every language (opt-in; greys out the individual boxes)
	panelPos = false,    -- { point, x, y } of the standalone panel
	leaveOffer = true,   -- offer to leave the group when its quests are done (never leaves by itself)
	leaveMsgOn = false,  -- say leaveMsg in /p when you click Leave (opt-in)
	leaveMsg = false,    -- false: the default text of the client's language
	debug = false,
}

local function copyDefaults(dst, src)
	for k, v in pairs(src) do if dst[k] == nil then dst[k] = v end end
	return dst
end

function ns.Get(key) return ns.db and ns.db[key] end
function ns.Set(key, value)
	if not ns.db then return end
	ns.db[key] = value
	ns.Fire("SETTING", key, value)
end

function ns.Print(fmt, ...)
	local text = select("#", ...) > 0 and string.format(fmt, ...) or fmt
	local out = DEFAULT_CHAT_FRAME or ChatFrame1
	if out then out:AddMessage("|cffffd100Group Finder|r " .. text) end
end

function ns.Debug(fmt, ...)
	if ns.db and ns.db.debug then ns.Print("|cff888888" .. fmt .. "|r", ...) end
end

-- A tiny message bus inside the addon.
local listeners = {}
function ns.On(msg, fn)
	listeners[msg] = listeners[msg] or {}
	table.insert(listeners[msg], fn)
end
function ns.Fire(msg, ...)
	for _, fn in ipairs(listeners[msg] or {}) do
		local ok, err = pcall(fn, ...)
		if not ok then ns.Debug("%s: %s", msg, tostring(err)) end
	end
end

function ns.After(seconds, fn)
	if C_Timer and C_Timer.After then C_Timer.After(seconds, fn) else fn() end
end

function ns.Now() return GetTime and GetTime() or 0 end

-- Secret values (Forever inherits the client's restricted values): never
-- compare or send them.
function ns.Readable(v)
	if v ~= nil and issecretvalue and issecretvalue(v) then return nil end
	return v
end

-- Game events.
local frame = CreateFrame("Frame")
ns.eventFrame = frame
local handlers = {}
function ns.RegisterEvent(event, fn)
	if not handlers[event] then
		handlers[event] = {}
		pcall(frame.RegisterEvent, frame, event)
	end
	table.insert(handlers[event], fn)
end
frame:SetScript("OnEvent", function(_, event, ...)
	for _, fn in ipairs(handlers[event] or {}) do
		local ok, err = pcall(fn, event, ...)
		if not ok then ns.Debug("%s: %s", event, tostring(err)) end
	end
end)

ns.RegisterEvent("ADDON_LOADED", function(_, name)
	if name ~= ADDON then return end
	-- v0.x used the folder Polestar_GroupFinder and these globals. They
	-- live in another saved-variables file, so they are only present if
	-- that addon was also loaded. Copy them when we have nothing of our own.
	if PSGroupFinderDB == nil and type(PolestarGroupFinderDB) == "table" then
		PSGroupFinderDB = PolestarGroupFinderDB
	end
	if PSGroupFinderCharDB == nil and type(PolestarGroupFinderCharDB) == "table" then
		PSGroupFinderCharDB = PolestarGroupFinderCharDB
	end
	PSGroupFinderDB = copyDefaults(PSGroupFinderDB or {}, DEFAULTS)
	PSGroupFinderCharDB = PSGroupFinderCharDB or {}
	ns.db = PSGroupFinderDB
	ns.char = PSGroupFinderCharDB
	if ns.Lang then ns.Lang.Init(ns.db) end
	ns.Fire("LOADED")
end)

ns.RegisterEvent("PLAYER_LOGIN", function()
	ns.Fire("LOGIN")
	if ns.db.enabled then ns.Fire("ENABLED", true) end
end)

function ns.SetEnabled(on)
	on = on and true or false
	if ns.db.enabled == on then return end
	ns.Set("enabled", on)
	ns.Fire("ENABLED", on)
end

-- Key bindings (Bindings.xml) and other addons call these.
function PSGroupFinder_Search()
	if not ns.db then return end
	if not ns.db.enabled then
		ns.Print(ns.L.DISABLED)
		if ns.UI then ns.UI.Show() end
		return
	end
	if ns.Search then ns.Search() end
end

function PSGroupFinder_TogglePanel()
	if ns.TogglePanel then ns.TogglePanel() end
end

SLASH_PSGROUPFINDER1 = "/psgf"
SLASH_PSGROUPFINDER2 = "/pgf"
SLASH_PSGROUPFINDER3 = "/psgroupfinder"
SlashCmdList.PSGROUPFINDER = function(msg)
	local cmd = (msg or ""):lower():match("^%s*(%S*)")
	if cmd == "" then
		PSGroupFinder_TogglePanel()
	elseif cmd == "search" then
		PSGroupFinder_Search()
	elseif cmd == "stop" then
		if ns.Session and ns.Session.Active() then
			ns.Comm.Stop()
			ns.Session.Stop("manual")
			ns.Print(L.SEARCH_STOPPED)
		end
	elseif cmd == "on" then
		ns.SetEnabled(true)
	elseif cmd == "off" then
		ns.SetEnabled(false)
	elseif cmd == "test" then
		if ns.TestChannels then ns.TestChannels(true) end
	elseif cmd == "reset" then
		ns.Set("panelPos", false)
		if ns.ResetPanel then ns.ResetPanel() end
	elseif cmd == "quest" then
		local id = tonumber((msg or ""):match("%d+"))
		if id and ns.QuestUI then ns.QuestUI.Open(id) else ns.Print(L.QUEST_USAGE) end
	elseif cmd == "hooks" then
		if ns.Hooks then ns.Hooks.Report() end
	elseif cmd == "debug" then
		ns.Set("debug", not ns.db.debug)
		ns.Print("debug %s", ns.db.debug and "on" or "off")
	else
		ns.Print(L.HELP)
	end
end
