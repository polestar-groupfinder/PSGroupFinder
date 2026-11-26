-- Group Finder for Polestar (PSGroupFinder): our button on Polestar's guide window.
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
-- By default an icon in the guide window's header, immediately left of
-- Lookup (the magnifying glass), drawn like Polestar's own header icons.
-- With the "header button" option off, or when Lookup cannot be found, a
-- "Find a group" button hangs under the window instead.
-- Left click starts or restarts the search, never opens the panel (the
-- search prints a short chat line; the icon turns accent while a session is
-- active). Right click opens or closes the panel. While the finder is off
-- the button stays, dimmed, and a left click says so.
-- nav.Lookup and the other nav buttons are INTERNAL to Polestar's guide
-- window: found under pcall, the button under the window is the fallback.

local _, ns = ...
local L = ns.L

local P -- Polestar, set on "POLESTAR"
local launcher, header, hostWindow, hostNav, hostLookup
local placing = false
local NAV_NEIGHBOURS = { "Report", "Nearby", "AllSteps", "Skip" }

-- The button argument matters: a right click must not fall through to the
-- left-click action (hence RegisterForClicks for both).
local function bindClicks(b)
	if b.EnableMouse then b:EnableMouse(true) end
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnClick", function(_, button)
		if button == "RightButton" then
			ns.TogglePanel()
			return
		end
		if ns.Get("enabled") then ns.Search() else ns.Print(L.DISABLED) end
		ns.PaintHeader()
	end)
end

local function tooltip(self, anchor)
	GameTooltip:SetOwner(self, anchor)
	GameTooltip:SetText(L.TITLE, 1, 1, 1)
	GameTooltip:AddLine(L.CLICK_SEARCH, nil, nil, nil, true)
	GameTooltip:AddLine(L.CLICK_PANEL, nil, nil, nil, true)
	if not ns.Get("enabled") then GameTooltip:AddLine(L.DISABLED, 1, 0.4, 0.4, true) end
	GameTooltip:Show()
end

local function guideParts()
	local T = P and P.Theme
	if not (T and T.GuideParts) then return nil end
	if T.HasCapability and not T.HasCapability("guideParts") then return nil end
	local ok, parts = pcall(T.GuideParts)
	return ok and type(parts) == "table" and parts or nil
end

---------------------------------------------------------------------------
-- The button under the window (fallback)
---------------------------------------------------------------------------

-- How far the window's own parts (bottom-edge tabs) stand under it.
local function reach(window)
	local T = P and P.Theme
	if not (T and T.GuideReach) then return 0 end
	if T.HasCapability and not T.HasCapability("guideReach") then return 0 end
	local ok, _, bottom = pcall(T.GuideReach, window)
	local r = ok and tonumber(bottom) or 0
	return r > 0 and r or 0
end

local function placeLauncher(b, window)
	b:ClearAllPoints()
	b:SetPoint("TOPRIGHT", window, "BOTTOMRIGHT", 0, -2 - reach(window))
end

local function makeLauncher(window)
	local b = ns.Widgets.Button(window, L.SEARCH, 132, nil, 20)
	placeLauncher(b, window)
	bindClicks(b)
	local function dimmed() b:SetAlpha(ns.Get("enabled") and 1 or 0.55) end
	ns.On("ENABLED", dimmed)
	ns.On("SETTING", dimmed)
	dimmed()
	b:SetScript("OnEnter", function(self) tooltip(self, "ANCHOR_BOTTOMRIGHT") end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return b
end

---------------------------------------------------------------------------
-- The header icon
---------------------------------------------------------------------------

local function colorIcon(b, token, alpha)
	if not (b and b.Icon) then return end
	local W = P and P.Widgets
	if W and W.Color then pcall(W.Color, b.Icon, token, alpha or 1) return end
	local T = P and P.Theme
	if T and T.Color then
		local ok, cr, cg, cb, ca = pcall(T.Color, token)
		if ok and cr then b.Icon:SetVertexColor(cr, cg, cb, (ca or 1) * (alpha or 1)) end
	end
end

-- Our texture by its full addon path, so Polestar's IconButton painter keeps
-- it (a short name such as "search" would be remapped to Polestar's loupe).
local function applyIcon(b)
	b.psIconName = ns.ICON
	if b.Icon and b.Icon.SetTexture then
		b.Icon:SetTexture(ns.ICON)
		if b.Icon.Show then b.Icon:Show() end
	end
end

function ns.PaintHeader()
	if not header then return end
	local on = ns.Get("enabled") and true or false
	local active = ns.Session.Active()
	applyIcon(header)
	-- SetIconState is what Polestar uses on its own header icons (accent
	-- while the tool is in use).
	local W = P and P.Widgets
	if W and W.SetIconState then
		pcall(W.SetIconState, header, active, true)
	else
		colorIcon(header, active and "accent" or (on and "icon" or "textMuted"), (on or active) and 1 or 0.55)
	end
	header:SetAlpha((on or active) and 1 or 0.45)
end

local function makeHeader(nav)
	local b
	local W = P and P.Widgets
	if W and W.IconButton then
		local ok, btn = pcall(W.IconButton, nav, ns.ICON, 24, L.TITLE, nil)
		if ok then b = btn end
	end
	if not b then
		b = CreateFrame("Button", "PSGroupFinderHeader", nav)
		b:SetSize(24, 24)
		b.Icon = b:CreateTexture(nil, "ARTWORK")
		b.Icon:SetSize(14, 14)
		b.Icon:SetPoint("CENTER")
		ns.Widgets.Skin(b, "button")
	end
	applyIcon(b)
	bindClicks(b)
	b:SetScript("OnEnter", function(self)
		colorIcon(self, ns.Session.Active() and "accent" or "iconHover", 1)
		self:SetAlpha(1)
		tooltip(self, "ANCHOR_BOTTOM")
	end)
	b:SetScript("OnLeave", function()
		ns.PaintHeader()
		GameTooltip:Hide()
	end)
	return b
end

-- nav.Lookup is internal. Walk the step bar if the name moves.
local function findLookup(nav)
	if not nav then return nil end
	if nav.Lookup then return nav.Lookup end
	local ok, n = pcall(function() return nav:GetNumChildren() end)
	if not (ok and n) then return nil end
	for i = 1, n do
		local c = select(i, nav:GetChildren())
		if c and c.psIconName == "search" then return c end
	end
end

-- Our icon goes immediately left of Lookup, and whatever Polestar had
-- anchored to Lookup moves one slot left. Polestar re-anchors on every
-- layout, so this runs again after their SetPoint.
local function placeHeader()
	if placing or not (header and hostLookup) then return end
	placing = true
	header:ClearAllPoints()
	header:SetPoint("RIGHT", hostLookup, "LEFT", 0, 0)
	header:SetFrameLevel(hostLookup.GetFrameLevel and hostLookup:GetFrameLevel() or 1)
	local function retarget(frame)
		if not frame or frame == header then return end
		local ok, point, rel, relPoint, x, y = pcall(frame.GetPoint, frame, 1)
		if ok and rel == hostLookup then
			frame:ClearAllPoints()
			frame:SetPoint(point or "RIGHT", header, relPoint or "LEFT", x or 0, y or 0)
		end
	end
	if hostNav then
		for _, name in ipairs(NAV_NEIGHBOURS) do retarget(hostNav[name]) end
		local ok, n = pcall(function() return hostNav:GetNumChildren() end)
		if ok and n then
			for i = 1, n do retarget(select(i, hostNav:GetChildren())) end
		end
	end
	placing = false
end

local function hookSetPoint(frame)
	if not frame or frame.psgfHooked or type(frame.SetPoint) ~= "function" then return end
	frame.psgfHooked = true
	local orig = frame.SetPoint
	frame.SetPoint = function(self, ...)
		orig(self, ...)
		if not placing then placeHeader() end
	end
end

---------------------------------------------------------------------------
-- Attaching
---------------------------------------------------------------------------

local function syncButtons()
	if ns.Get("headerButton") ~= false and header and hostLookup then
		placeHeader()
		header:Show()
		ns.PaintHeader()
		if launcher then launcher:Hide() end
	else
		if header then header:Hide() end
		if launcher then
			if hostWindow then placeLauncher(launcher, hostWindow) end
			launcher:Show()
		end
	end
end

local function attach()
	local parts = guideParts()
	local window = parts and parts.window
	if not window then return false end
	if window ~= hostWindow then
		hostWindow = window
		if not launcher then
			launcher = makeLauncher(window)
		else
			launcher:SetParent(window)
			placeLauncher(launcher, window)
		end
		window:HookScript("OnShow", function()
			syncButtons()
			ns.UI.HostShown(true)
		end)
		window:HookScript("OnHide", function() ns.UI.HostShown(false) end)
		ns.UI.SetHost(window)
	end
	local nav = parts.nav
	local ok, lookup = pcall(findLookup, nav)
	lookup = ok and lookup or nil
	if nav and lookup and lookup ~= hostLookup then
		hostNav, hostLookup = nav, lookup
		if not header then
			header = makeHeader(nav)
			ns.headerButtonFrame = header
		else
			header:SetParent(nav)
		end
		hookSetPoint(lookup)
		for _, name in ipairs(NAV_NEIGHBOURS) do hookSetPoint(nav[name]) end
		placeHeader()
	end
	syncButtons()
	return true
end

local function refresh()
	attach()
	ns.PaintHeader()
end

ns.On("POLESTAR", function(polestar)
	P = polestar
	ns.On("POLESTAR_STEP", attach)
	ns.On("SETTING", refresh)
	ns.On("ENABLED", refresh)
	ns.On("SESSION", ns.PaintHeader)
	if P.Theme and P.Theme.OnChanged then pcall(P.Theme.OnChanged, refresh) end
	-- The guide window is built late (at its first show): try now and a few
	-- times after.
	local tries = 0
	local function retry()
		if attach() or tries >= 10 then return end
		tries = tries + 1
		ns.After(3, retry)
	end
	retry()
end)
