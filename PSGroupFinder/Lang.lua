-- Group Finder for Polestar (PSGroupFinder): search languages.
-- Copyright (C) 2026 PSGroupFinder contributors. GPL-3.0-or-later, see LICENSE.
--
-- Each player broadcasts only their client language (GetLocale). The
-- setting "search languages" decides who appears in the list: by default
-- the client's language only; other languages can be ticked one by one;
-- "all languages" is opt-in and greys out the individual boxes. Filtering
-- is unilateral (a peer is kept if their client language is in our search
-- set, or we accept all). A v0.2 peer with no language is visible only if
-- we accept all. Auto-group is applied independently on each side. The
-- payload is one letter (`f`, `e`) so the 255-byte message still has room
-- for quests. Legacy `f/f` / `fe/*` still decode (first letter).

local _, ns = ...
local L = ns.L

local Lang = {}
ns.Lang = Lang

-- One-letter codes, stable order.
-- tag: short label in the list (FR, EN, …).
Lang.ALL = {
	{ code = "f", tag = "FR", locales = { frFR = true } },
	{ code = "e", tag = "EN", locales = { enUS = true, enGB = true } },
	{ code = "d", tag = "DE", locales = { deDE = true } },
	{ code = "s", tag = "ES", locales = { esES = true, esMX = true } },
	{ code = "i", tag = "IT", locales = { itIT = true } },
	{ code = "p", tag = "PT", locales = { ptBR = true, ptPT = true } },
	{ code = "r", tag = "RU", locales = { ruRU = true } },
	{ code = "k", tag = "KO", locales = { koKR = true } },
	{ code = "c", tag = "ZH", locales = { zhCN = true } },
	{ code = "t", tag = "ZHT", locales = { zhTW = true } },
}

local byCode, byLocale = {}, {}
for _, row in ipairs(Lang.ALL) do
	byCode[row.code] = row
	for loc in pairs(row.locales) do byLocale[loc] = row.code end
end

local function valid(code) return byCode[code] ~= nil end

function Lang.DefaultCode()
	local loc = GetLocale and GetLocale() or "enUS"
	return byLocale[loc] or "e"
end

function Lang.Tag(code) return byCode[code] and byCode[code].tag or tostring(code):upper() end
function Lang.Name(code) return L["LANG_" .. Lang.Tag(code)] or Lang.Tag(code) end

local function copyList(src, fallback)
	local out = {}
	if type(src) == "table" then
		for _, c in ipairs(src) do if valid(c) then out[#out + 1] = c end end
	end
	if #out == 0 then out[1] = fallback or Lang.DefaultCode() end
	local seen, ordered = {}, {}
	for _, row in ipairs(Lang.ALL) do
		for _, c in ipairs(out) do
			if c == row.code and not seen[c] then
				seen[c] = true
				ordered[#ordered + 1] = c
			end
		end
	end
	return ordered
end

-- Fills missing settings after a load (default: the client's language).
-- `acceptedLangs` from an earlier local cut is reused as the search set.
function Lang.Init(db)
	if not db then return end
	if db.acceptAll == nil then db.acceptAll = false end
	local src = db.searchLangs
	if type(src) ~= "table" and type(db.acceptedLangs) == "table" then
		src = db.acceptedLangs
	end
	db.searchLangs = copyList(src)
end

function Lang.Search()
	return copyList(ns.Get("searchLangs"))
end

function Lang.AcceptsAll()
	return ns.Get("acceptAll") and true or false
end

local function setList(list)
	ns.Set("searchLangs", copyList(list))
	ns.Fire("LANG")
end

function Lang.SetSearch(code, on)
	if not valid(code) then return end
	ns.Set("acceptAll", false)
	local cur, next = Lang.Search(), {}
	for _, c in ipairs(cur) do if c ~= code then next[#next + 1] = c end end
	if on then next[#next + 1] = code end
	if #next == 0 then next[1] = code end -- at least one
	setList(next)
end

function Lang.SetAcceptAll(on)
	ns.Set("acceptAll", on and true or false)
	if not on and #(ns.Get("searchLangs") or {}) == 0 then
		setList({ Lang.DefaultCode() })
	else
		ns.Fire("LANG")
	end
end

function Lang.HasSearch(code)
	for _, c in ipairs(Lang.Search()) do if c == code then return true end end
end

-- Compact payload: the client's language only (`f`, `e`).
function Lang.Encode()
	return Lang.DefaultCode()
end

-- `their` is { code = "f" }, or nil. Legacy "f/f" / "fe/*" use the first letter.
function Lang.Decode(text)
	if type(text) ~= "string" or text == "" then return nil end
	local code = text:match("^([a-z])")
	if not code or not valid(code) then return nil end
	return { code = code }
end

-- Unilateral: keep a peer if we accept all, or their client language is
-- in our search set. `their` is a Decode() table, or nil (v0.2, no langs).
function Lang.Compatible(their)
	if Lang.AcceptsAll() then return true end
	if not their or not their.code then return false end
	for _, c in ipairs(Lang.Search()) do
		if c == their.code then return true end
	end
	return false
end

-- Short label for a peer: "FR". MineSummary is "FR", "FR/EN", or "Toutes".
function Lang.Summary(their)
	if not their or not their.code then return "?" end
	return Lang.Tag(their.code)
end

function Lang.MineSummary()
	if Lang.AcceptsAll() then
		return L.LANG_ALL_SHORT or L.LANG_ALL
	end
	local parts = {}
	for _, c in ipairs(Lang.Search()) do parts[#parts + 1] = Lang.Tag(c) end
	if #parts == 0 then return Lang.Tag(Lang.DefaultCode()) end
	return table.concat(parts, "/")
end
