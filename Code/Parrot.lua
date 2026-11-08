local _, ns = ...
ns.addon = {}
local Parrot = LibStub("AceAddon-3.0"):NewAddon(ns.addon, "Parrot", "LibSink-2.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Parrot")

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

-- Private event dispatcher to isolate Parrot from session-shared AceEvent-3.0 taint
local Events = {}
do
	local frame = CreateFrame("Frame")
	local registry = {}

	frame:SetScript("OnEvent", function(_, event, ...)
		local t = registry[event]
		if not t then return end
		for target, handler in next, t do
			if handler == true then
				target[event](target, event, ...)
			elseif type(handler) == "string" then
				target[handler](target, event, ...)
			else
				handler(event, ...)
			end
		end
	end)

	function Events.RegisterEvent(target, event, handler)
		local t = registry[event]
		if not t then
			t = {}
			registry[event] = t
			pcall(frame.RegisterEvent, frame, event)
		end
		t[target] = handler or true
	end

	function Events.UnregisterEvent(target, event)
		local t = registry[event]
		if not t then return end
		t[target] = nil
		if not next(t) then
			registry[event] = nil
			pcall(frame.UnregisterEvent, frame, event)
		end
	end

	function Events.UnregisterAllEvents(target)
		for event, t in next, registry do
			if t[target] ~= nil then
				t[target] = nil
				if not next(t) then
					registry[event] = nil
					pcall(frame.UnregisterEvent, frame, event)
				end
			end
		end
	end

	function Events.Embed(target)
		target.RegisterEvent = Events.RegisterEvent
		target.UnregisterEvent = Events.UnregisterEvent
		target.UnregisterAllEvents = Events.UnregisterAllEvents
		return target
	end
end
Parrot.Events = Events
Events.Embed(Parrot)

do
	local _NewModule = Parrot.NewModule
	function Parrot:NewModule(name, ...)
		local libs = {}
		local n = 0
		for i = 1, select("#", ...) do
			local lib = select(i, ...)
			if lib ~= "AceEvent-3.0" then
				n = n + 1
				libs[n] = lib
			end
		end
		local mod = Events.Embed(_NewModule(self, name, unpack(libs, 1, n)))
		mod.OnDisable = mod.OnDisable or function(m)
			Events.UnregisterAllEvents(m)
		end
		return mod
	end
end

-- Debug
local debug = function() end
--@debug@
do
	local PARROT_DEBUG_FRAME = _G.ChatFrame4
	local function nilCacheFunc() return nil end
	local function writeFunc(self, msg) PARROT_DEBUG_FRAME:AddMessage(msg) end

	function debug(arg1, ...)
		if type(arg1) == "table" then
			local loadAddOn = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
			local loaded = loadAddOn and loadAddOn("Blizzard_DebugTools")
			if not loaded then
				PARROT_DEBUG_FRAME:AddMessage("|cff00ff00Parrot|r: !!! table-dump skipped")
				return debug(...)
			end

			local context = {
				depth = 2,
				GetTableName = nilCacheFunc,
				GetFunctionName = nilCacheFunc,
				GetUserdataName = nilCacheFunc,
				Write = writeFunc,
			}
			PARROT_DEBUG_FRAME:AddMessage("|cff00ff00Parrot|r: +++ table-dump")
			_G.DevTools_RunDump(arg1, context)
			PARROT_DEBUG_FRAME:AddMessage("|cff00ff00Parrot|r: --- end of table-dump")
			return debug(...)
		else
			local text = strjoin(" ", tostringall(arg1, ...))
			PARROT_DEBUG_FRAME:AddMessage("|cff00ff00Parrot|r: " .. text)
		end
	end
end
--@end-debug@
Parrot.debug = debug

-- Table recycling
local new, del
do
	local pool = setmetatable({}, {__mode = 'kv'})

	function new()
		local t = next(pool)
		if t then
			pool[t] = nil
		else
			t = {}
		end
		return t
	end

	function del(t)
		if not t then
			error(("Bad argument #1 to 'del'. Expected %q, got %q."):format("table", type(t)), 2)
		end
		setmetatable(t, nil)
		wipe(t)
		pool[t] = true
		return nil
	end
end

local function newList(...)
	local t = new()
	for i = 1, select('#', ...) do
		t[i] = select(i, ...)
	end
	return t
end

local function newDict(...)
	local t = new()
	for i = 1, select('#', ...), 2 do
		local k, v = select(i, ...)
		t[k] = v
	end
	return t
end

Parrot.newList = newList
Parrot.newDict = newDict
Parrot.del = del

-- LibDeformat-3.0 replacement
-- This is Jerry's GetPattern function from LibItemBonus-2.0.
local GetPattern
do
	-- This is very much a ripoff of Deformat, simplified in that it does not
	-- handle merged patterns

	local next, ipairs, assert = next, ipairs, assert
	local tconcat = table.concat
	local function donothing() end

	local cache = {}
	local sequences = {
		["%d*d"] = "%%-?%%d+",
		["s"] = ".+",
		["[fg]"] = "%%-?%%d+%%.?%%d*",
		["%%%.%d[fg]"] = "%%-?%%d+%%.?%%d*",
		["c"] = ".",
	}

	local function get_first_pattern(s)
		local first_pos, first_pattern
		for pattern in next, sequences do
			local pos = s:find("%%%%"..pattern)
			if pos and (not first_pos or pos < first_pos) then
				first_pos, first_pattern = pos, pattern
			end
		end
		return first_pattern
	end

	local function get_indexed_pattern(s, i)
		for pattern in next, sequences do
			if s:find("%%%%" .. i .. "%%%$" .. pattern) then
				return pattern
			end
		end
	end

	local function unpattern_unordered(unpattern, f)
		local i = 1
		while true do
			local pattern = get_first_pattern(unpattern)
			if not pattern then return unpattern, i > 1 end

			unpattern = unpattern:gsub("%%%%" .. pattern, "(" .. sequences[pattern] .. ")", 1)
			f[i] = (pattern ~= "c" and pattern ~= "s")
			i = i + 1
		end
	end

	local function unpattern_ordered(unpattern, f)
		local i = 1
		while true do
			local pattern = get_indexed_pattern(unpattern, i)
			if not pattern then return unpattern, i > 1 end

			unpattern = unpattern:gsub("%%%%" .. i .. "%%%$" .. pattern, "(" .. sequences[pattern] .. ")", 1)
			f[i] = (pattern ~= "c" and pattern ~= "s")
			i = i + 1
		end
	end

	function GetPattern(pattern)
		local unpattern, f, matched = '^' .. pattern:gsub("([%(%)%.%*%+%-%[%]%?%^%$%%])", "%%%1") .. '$', {}
		if not pattern:find("%1$", nil, true) then
			unpattern, matched = unpattern_unordered(unpattern, f)
			if not matched then
				return donothing
			else
				local locals, returns = {}, {}
				for index, number in ipairs(f) do
					local l = ("v%d"):format(index)
					locals[index] = l
					if number then
						returns[#returns + 1] = "n("..l..")"
					else
						returns[#returns + 1] = l
					end
				end
				locals = tconcat(locals, ",")
				returns = tconcat(returns, ",")
				local code = ("local m, n = string.match, tonumber return function(s) local %s = m(s, %q) return %s end"):format(locals, unpattern, returns)
				return assert(ns.Compat.LoadChunk(code, "GetPattern"))()
			end
		else
			unpattern, matched = unpattern_ordered(unpattern, f)
			if not matched then
				return donothing
			else
				local i, o = 1, {}
				pattern:gsub("%%(%d)%$", function(w) o[i] = tonumber(w); i = i + 1; end)
				local sorted_locals, returns = {}, {}
				for index, number in ipairs(f) do
					local l = ("v%d"):format(index)
					sorted_locals[index] = ("v%d"):format(o[index])
					if number then
						returns[#returns + 1] = "n("..l..")"
					else
						returns[#returns + 1] = l
					end
				end
				sorted_locals = tconcat(sorted_locals, ",")
				returns = tconcat(returns, ",")
				local code =("local m, n = string.match, tonumber return function(s) local %s = m(s, %q) return %s end"):format(sorted_locals, unpattern, returns)
				return assert(ns.Compat.LoadChunk(code, "GetPattern"))()
			end
		end
	end

	function Parrot.Deformat(text, pattern)
		if not text or not pattern or ns.Compat.IsSecretValue(text) then return nil end
		local func = cache[pattern]
		if not func then
			func = GetPattern(pattern)
			cache[pattern] = func
		end
		return func(text)
	end
end

-- Init
local db = nil
local defaults = {
	profile = {
		gameText = true,
		gameSelf = false,
		gameDamage = false,
		gamePetDamage = false,
		gameHealing = false,
		gameLowHealth = false,
		gameReactives = false,
		minimap = {
			hide = false,
		},
	}
}

Parrot.errors = {}
function Parrot:SafeCall(where, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		local e = self.errors
		e[#e + 1] = ("|cffff8080%s|r  %s"):format(where, tostring(err))
		if #e > 40 then table.remove(e, 1) end
		if geterrorhandler then
			geterrorhandler()("Parrot Reforged: " .. where .. "\n" .. tostring(err))
		end
	end
	return ok
end

function Parrot:Print(...)
	local n = select("#", ...)
	local msg
	if n <= 1 then
		msg = tostring((...))
	else
		local t = {}
		for i = 1, n do t[i] = tostring(select(i, ...)) end
		msg = table.concat(t, " ")
	end
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Parrot Reforged|r: " .. msg)
	end
end

function Parrot:TestMessages()
	if not self:IsEnabled() then
		self:Print("Addon is disabled - use /parrot toggle to enable it")
		return
	end
	local count = 0
	for area in next, self:GetScrollAreasChoices() do
		count = count + 1
		self:ShowMessage(("Parrot test %d"):format(count), area, false, math.random(), math.random(), math.random())
		self:ShowMessage(("Crit %d!"):format(count), area, true, 1, 1, 0)
	end
	if count == 0 then
		self:ShowMessage("Parrot test", "Notification", false, 1, 1, 1)
	end
end

function Parrot:OnProfileChanged(event, database)
	db = self.db.profile
	for _, mod in self:IterateModules() do
		if type(mod.OnProfileChanged) == "function" then
			self:SafeCall("module '" .. (mod.moduleName or "?") .. "':OnProfileChanged",
				mod.OnProfileChanged, mod, event, database)
		end
	end
	self:UpdateFCT()

	local LDBIcon = LibStub("LibDBIcon-1.0", true)
	if LDBIcon and LDBIcon:IsRegistered("Parrot") then
		self.db.profile.minimap = self.db.profile.minimap or {}
		LDBIcon:Refresh("Parrot", self.db.profile.minimap)
	end
end

function Parrot:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("ParrotDB", defaults, true)
	local LibDualSpec = LibStub("LibDualSpec-1.0", true)
	if LibDualSpec then
		LibDualSpec:EnhanceDatabase(self.db, "Parrot")
	end
	db = self.db.profile

	self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
	self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
	self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")

	self.options = {
		name = "Parrot Reforged",
		desc = L["Floating Combat Text of awesomeness. Caw. It'll eat your crackers."],
		type = "group",
		icon = [[Interface\Icons\Spell_Nature_ForceOfNature]],
		args = {},
	}

	-- stub options table to show in Interface Options
	local options = CopyTable(self.options)
	options.args.load = {
		type = "execute",
		name = L["Load config"],
		desc = L["Load configuration options"],
		func = "ShowConfig",
		handler = self,
	}
	AceConfig:RegisterOptionsTable("Parrot/Blizzard", options)
	AceConfigDialog:AddToBlizOptions("Parrot/Blizzard", "Parrot Reforged")

	SLASH_PARROT1 = "/parrot"
	SLASH_PARROT2 = "/par"
	function SlashCmdList.PARROT(input)
		input = (input or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
		if input == "test" then
			self:TestMessages()
		elseif input == "toggle" then
			if self:IsEnabled() then self:Disable() else self:Enable() end
			self:Print(self:IsEnabled() and "enabled" or "disabled")
		elseif input == "errors" then
			if #self.errors == 0 then
				self:Print("no captured errors.")
			else
				self:Print(("captured errors (%d):"):format(#self.errors))
				for _, line in ipairs(self.errors) do
					if DEFAULT_CHAT_FRAME then
						DEFAULT_CHAT_FRAME:AddMessage("  " .. line)
					end
				end
			end
		elseif input == "" or input == "config" or input == "options" then
			self:ShowConfig()
		else
			self:Print("|cffffffff/parrot|r open config   |cffffffff/parrot test|r sample messages   |cffffffff/parrot toggle|r enable/disable   |cffffffff/parrot errors|r show captured errors")
		end
	end

	local LibSink = LibStub("LibSink-2.0", true)
	if LibSink then
		local function sink(addon, text, r, g, b, font, size, outline, sticky, location, icon)
			local storage = LibSink.storageForAddon[addon]
			if storage then
				location = storage.sink20ScrollArea or location or "Notification"
				sticky = storage.sink20Sticky or sticky
			end
			self:ShowMessage(text, location, sticky, r, g, b, font, size, outline, icon)
		end
		local function getScrollAreasChoices()
			local tmp = {}
			for k, v in next, self:GetScrollAreasChoices() do
				tmp[#tmp+1] = v
			end
			return tmp
		end
		self:RegisterSink("Parrot", "Parrot Reforged", nil, sink, getScrollAreasChoices, true)
	end

	local LDB = LibStub("LibDataBroker-1.1", true)
	if LDB then
		local dataObj = LDB:NewDataObject("Parrot", {
			type = "launcher",
			icon = "Interface\\Icons\\Spell_Nature_ForceOfNature",
			OnClick = function(_, button)
				if button == "LeftButton" then
					Parrot:ShowConfig()
				elseif button == "RightButton" then
					local sa = Parrot:GetModule("ScrollAreas", true)
					if sa and Parrot.SetConfigMode then
						Parrot:SetConfigMode(not sa.configMode)
					end
				end
			end,
			OnTooltipShow = function(tooltip)
				if not tooltip or not tooltip.AddLine then return end
				tooltip:AddLine("|cffffd100Parrot Reforged|r")
				tooltip:AddLine(L["Floating Combat Text of awesomeness. Caw. It'll eat your crackers."], 0.8, 0.8, 0.8, true)
				tooltip:AddLine(" ")
				tooltip:AddLine("|cffeda55fLeft-Click:|r " .. (L["Load config"] or "Open Options"), 0.2, 1, 0.2)
			end,
			label = "Parrot Reforged",
		})
		local LDBIcon = LibStub("LibDBIcon-1.0", true)
		if LDBIcon and dataObj then
			LDBIcon:Register("Parrot", dataObj, self.db.profile.minimap)
		end
	end

end

function Parrot_OnAddonCompartmentClick(_, buttonName)
	if buttonName == "RightButton" then
		if Parrot:IsEnabled() then Parrot:Disable() else Parrot:Enable() end
		Parrot:Print(Parrot:IsEnabled() and "enabled" or "disabled")
	else
		Parrot:ShowConfig()
	end
end

function Parrot_OnAddonCompartmentEnter(_, menuButtonFrame)
	if not GameTooltip then return end
	GameTooltip:SetOwner(menuButtonFrame, "ANCHOR_LEFT")
	GameTooltip:AddLine("|cffffd100Parrot Reforged|r")
	GameTooltip:AddLine(L["Floating Combat Text of awesomeness. Caw. It'll eat your crackers."], 0.8, 0.8, 0.8, true)
	GameTooltip:Show()
end

function Parrot_OnAddonCompartmentLeave()
	if GameTooltip then
		GameTooltip:Hide()
	end
end

do
	local fct = {
		"enableFloatingCombatText",
		"floatingCombatTextCombatDamage",
		"floatingCombatTextCombatDamageAllAutos",
		"floatingCombatTextCombatLogPeriodicSpells",
		"floatingCombatTextPetMeleeDamage",
		"floatingCombatTextPetSpellDamage",
		"floatingCombatTextCombatHealing",
		"floatingCombatTextCombatHealingAbsorbTarget",
		"floatingCombatTextCombatHealingAbsorbSelf",
		"floatingCombatTextReactives",
		"floatingCombatTextLowManaHealth",
		"floatingCombatTextDodgeParryMiss",
		"floatingCombatTextCombatState",
		"floatingCombatTextDamageReduction",
	}

	local GLOBAL_FOR_CVAR = {
		enableFloatingCombatText = "SHOW_COMBAT_TEXT",
		floatingCombatTextLowManaHealth = "COMBAT_TEXT_SHOW_LOW_HEALTH_MANA",
		floatingCombatTextCombatState = "COMBAT_TEXT_SHOW_COMBAT_STATE",
		floatingCombatTextDodgeParryMiss = "COMBAT_TEXT_SHOW_DODGE_PARRY_MISS",
		floatingCombatTextDamageReduction = "COMBAT_TEXT_SHOW_RESISTANCES",
		floatingCombatTextReactives = "COMBAT_TEXT_SHOW_REACTIVES",
	}

	local LEGACY_CVAR_ALIASES = {
		floatingCombatTextCombatDamage = { "CombatDamage" },
		floatingCombatTextCombatLogPeriodicSpells = { "CombatLogPeriodicSpells" },
		floatingCombatTextPetMeleeDamage = { "PetMeleeDamage" },
		floatingCombatTextPetSpellDamage = { "PetSpellDamage" },
		floatingCombatTextCombatHealing = { "CombatHealing" },
	}

	local function cvarExists(name)
		if C_CVar and C_CVar.GetCVarDefault then
			local ok, val = pcall(C_CVar.GetCVarDefault, name)
			if ok and val ~= nil then return true end
		end
		if GetCVarDefault then
			local ok, val = pcall(GetCVarDefault, name)
			if ok and val ~= nil then return true end
		end
		return false
	end

	local function SafeSetCVar(var, val)
		if cvarExists(var) then
			if C_CVar and C_CVar.SetCVar then
				pcall(C_CVar.SetCVar, var, val)
			elseif SetCVar then
				pcall(SetCVar, var, val)
			end
		end
	end

	local function setFCT(cvar, on)
		local val = on and "1" or "0"
		SafeSetCVar(cvar, val)
		SafeSetCVar(cvar .. "_v2", val)
		local aliases = LEGACY_CVAR_ALIASES[cvar]
		if aliases then
			for _, alias in ipairs(aliases) do
				SafeSetCVar(alias, val)
				SafeSetCVar(alias .. "_v2", val)
			end
		end
		local gvar = GLOBAL_FOR_CVAR[cvar]
		if gvar then
			_G[gvar] = val
		end
	end

	local function forceApplyEnableFCT(on)
		setFCT("enableFloatingCombatText", on)
		if not on and _G.CombatText then
			pcall(function()
				_G.CombatText:UnregisterAllEvents()
				_G.CombatText:Hide()
			end)
		end
	end

	local function refreshBlizzardCombatText()
		if CombatText_UpdateDisplayedMessages then
			pcall(CombatText_UpdateDisplayedMessages)
		end
		if db and db.gameText and not db.gameSelf and _G.CombatText then
			pcall(function()
				_G.CombatText:UnregisterAllEvents()
				_G.CombatText:Hide()
			end)
		end
	end

	local pendingFCTUpdate = false
	local pendingFCTReset = false

	function Parrot:ResetFCT()
		if InCombatLockdown and InCombatLockdown() then
			pendingFCTReset = true
			pendingFCTUpdate = false
			return
		end
		pendingFCTReset = false
		for _, var in next, fct do
			local default = GetCVarDefault and GetCVarDefault(var)
			if default ~= nil then
				pcall(SetCVar, var, default)
			end
			if cvarExists(var .. "_v2") then
				pcall(SetCVar, var .. "_v2", GetCVarDefault(var .. "_v2"))
			end
		end
		forceApplyEnableFCT(true)
		_G.COMBAT_TEXT_SHOW_LOW_HEALTH_MANA = "1"
		_G.COMBAT_TEXT_SHOW_COMBAT_STATE = "1"
		_G.COMBAT_TEXT_SHOW_DODGE_PARRY_MISS = "1"
		_G.COMBAT_TEXT_SHOW_RESISTANCES = "1"
		_G.COMBAT_TEXT_SHOW_REACTIVES = "1"
		refreshBlizzardCombatText()
	end

	function Parrot:UpdateFCT()
		if InCombatLockdown and InCombatLockdown() then
			pendingFCTUpdate = true
			return
		end
		pendingFCTUpdate = false
		if db and db.gameText then
			forceApplyEnableFCT(db.gameSelf)
			setFCT("floatingCombatTextDodgeParryMiss", db.gameSelf)
			setFCT("floatingCombatTextCombatState", db.gameSelf)
			setFCT("floatingCombatTextDamageReduction", db.gameSelf)
			setFCT("floatingCombatTextReactives", db.gameReactives)
			setFCT("floatingCombatTextLowManaHealth", db.gameLowHealth)

			setFCT("floatingCombatTextCombatDamage", db.gameDamage)
			setFCT("floatingCombatTextCombatDamageAllAutos", db.gameDamage)
			setFCT("floatingCombatTextCombatLogPeriodicSpells", db.gameDamage)

			setFCT("floatingCombatTextPetMeleeDamage", db.gamePetDamage)
			setFCT("floatingCombatTextPetSpellDamage", db.gamePetDamage)

			setFCT("floatingCombatTextCombatHealing", db.gameHealing)
			setFCT("floatingCombatTextCombatHealingAbsorbTarget", db.gameHealing)
			setFCT("floatingCombatTextCombatHealingAbsorbSelf", db.gameHealing)

			refreshBlizzardCombatText()
		end
	end

	Parrot:RegisterEvent("PLAYER_REGEN_ENABLED", function()
		if pendingFCTReset then
			Parrot:ResetFCT()
		elseif pendingFCTUpdate then
			Parrot:UpdateFCT()
		end
	end)

	Parrot:RegisterEvent("PLAYER_ENTERING_WORLD", function()
		Parrot:UpdateFCT()
	end)
end

function Parrot:OnEnable()
	if db and not db.fctDefaultsMigratedV1 then
		db.fctDefaultsMigratedV1 = true
		db.gameText = true
		db.gameSelf = false
		db.gameDamage = false
		db.gamePetDamage = false
		db.gameHealing = false
	end
	self:UpdateFCT()
end

-- Event handling
local nextUID
do
	local uid = 0
	function nextUID()
		uid = uid + 1
		return uid
	end
end

do
	local combatLogHandlers = {}
	local cleuFrame = CreateFrame("Frame")
	local cleuRegistered = false

	cleuFrame:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
			if not cleuRegistered then
				cleuRegistered = true
				cleuFrame:UnregisterEvent("PLAYER_LOGIN")
				cleuFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
				if not issecure or issecure() then
					pcall(cleuFrame.RegisterEvent, cleuFrame, "COMBAT_LOG_EVENT_UNFILTERED")
				end
				if cleuFrame.IsEventRegistered and not cleuFrame:IsEventRegistered("COMBAT_LOG_EVENT_UNFILTERED") then
					Parrot.combatLogBlocked = true
				end
			end
			return
		end
		if not next(combatLogHandlers) then return end
		local uid = nextUID()
		for mod in next, combatLogHandlers do
			mod:HandleCombatlogEvent(uid, CombatLogGetCurrentEventInfo())
		end
	end)
	cleuFrame:RegisterEvent("PLAYER_LOGIN")
	cleuFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

	function Parrot:RegisterCombatLog(mod)
		if type(mod.HandleCombatlogEvent) ~= "function" then
			error("Bad argument #1 for 'RegisterCombatLog'. Module must contain a function named HandleCombatlogEvent")
		end
		combatLogHandlers[mod] = true
	end

	function Parrot:UnregisterCombatLog(mod)
		combatLogHandlers[mod] = nil
	end
end

do
	local blizzardEventHandlers = {}

	local function OnBlizzardEvent(event, ...)
		local uid = nextUID()
		for mod, func in next, blizzardEventHandlers[event] do
			mod[func](mod, uid, event, ...)
		end
	end

	function Parrot:RegisterBlizzardEvent(mod, event, func)
		if func then
			if type(mod[func]) ~= "function" then
				error(("Bad argument #3 for 'RegisterBlizzardEvent'. Module must contain a function named %s"):format(func))
			end
		elseif type(mod[event]) ~= "function" then
			error(("Bad argument #2 for 'RegisterBlizzardEvent'. Module must contain a function named %s"):format(event))
		end

		if not blizzardEventHandlers[event] then
			local ok = pcall(self.RegisterEvent, self, event, OnBlizzardEvent)
			if not ok then
				return
			end
			blizzardEventHandlers[event] = {}
		end
		if not blizzardEventHandlers[event][mod] then
			blizzardEventHandlers[event][mod] = {}
		end
		blizzardEventHandlers[event][mod] = func or event
	end

	function Parrot:UnregisterBlizzardEvent(mod, event)
		if not blizzardEventHandlers[event] then return end
		blizzardEventHandlers[event][mod] = nil
		if not next(blizzardEventHandlers[event]) then
			pcall(self.UnregisterEvent, self, event)
			blizzardEventHandlers[event] = nil
		end
	end

	function Parrot:UnregisterAllBlizzardEvents(mod)
		for _, modules in next, blizzardEventHandlers do
			modules[mod] = nil
		end
	end
end

-- Config
do
	local LibSharedMedia = LibStub("LibSharedMedia-3.0")

	Parrot.soundValues = LibSharedMedia:List("sound")
	Parrot.fontValues = LibSharedMedia:List("font")
	Parrot.fontWithInheritValues = {}

	local function rebuild(_, mediatype)
		if mediatype == "font" then
			wipe(Parrot.fontWithInheritValues)
			for i, v in next, Parrot.fontValues do
				Parrot.fontWithInheritValues[i] = v
			end
			Parrot.fontWithInheritValues[-1] = L["Inherit"]
		end
	end
	rebuild(nil, "font")

	LibSharedMedia.RegisterCallback(Parrot, "LibSharedMedia_Registered", rebuild)
end

function Parrot:ShowConfig()
	if self.OnOptionsCreate then
		self:SafeCall("Parrot:OnOptionsCreate", self.OnOptionsCreate, self)

		for _, mod in self:IterateModules() do
			if type(mod.OnOptionsCreate) == "function" then
				self:SafeCall("module '" .. (mod.moduleName or "?") .. "':OnOptionsCreate",
					mod.OnOptionsCreate, mod)
			end
		end
		AceConfig:RegisterOptionsTable("Parrot", self.options)
		if AceConfigDialog and AceConfigDialog.SetDefaultSize then
			AceConfigDialog:SetDefaultSize("Parrot", 880, 620)
		end

		self.OnOptionsCreate = nil
	end

	AceConfigDialog:Open("Parrot")
end

function Parrot:AddOption(name, args)
	self.options.args[name] = args
end

function Parrot:OnOptionsCreate()
	local function setCVarOption(info, value)
		db[info[#info]] = value
		self:UpdateFCT()
	end
	local function disabled()
		return not db.gameText
	end

	self:AddOption("profiles", LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db))
	self.options.args.profiles.order = -1
	local LibDualSpec = LibStub("LibDualSpec-1.0", true)
	if LibDualSpec then
		LibDualSpec:EnhanceOptions(self.options.args.profiles, self.db)
	end

	self:AddOption("general", {
		type = "group",
		name = L["General"],
		desc = L["General settings"],
		disabled = function() return not self:IsEnabled() end,
		order = 1,
		args = {
			minimap = {
				type = "toggle",
				name = L["Minimap icon"] or "Minimap icon",
				desc = L["Show the minimap icon"] or "Show the minimap icon",
				get = function()
					return not (db.minimap and db.minimap.hide)
				end,
				set = function(_, value)
					db.minimap = db.minimap or {}
					db.minimap.hide = not value
					local LDBIcon = LibStub("LibDBIcon-1.0", true)
					if LDBIcon and LDBIcon:IsRegistered("Parrot") then
						LDBIcon:Refresh("Parrot", db.minimap)
					end
				end,
				order = 0,
			},
			gameText = {
				type = "group",
				inline = true,
				name = _G.COMBAT_TEXT_LABEL or "Floating Combat Text",
				get = function(info) return db[info[#info]] end,
				set = setCVarOption,
				args = {
					gameText = {
						type = "toggle",
						name = L["Control game options"],
						desc = L["Whether Parrot should control the default interface's options below.\nThese settings always override manual changes to the default interface options."],
						descStyle = "inline",
						set = function(info, value)
							db[info[#info]] = value
							if value then
								self:UpdateFCT()
							else
								self:ResetFCT()
							end
						end,
						order = 0,
						width = "full",
					},
					gameSelf = {
						type = "toggle",
						name = _G.COMBAT_SELF or "Scrolling Combat Text for Self",
						desc = _G.OPTION_TOOLTIP_SHOW_COMBAT_TEXT or "",
						disabled = disabled,
						order = 1,
					},
					gameDamage = {
						type = "toggle",
						name = _G.SHOW_DAMAGE_TEXT or _G.DAMAGE or "Damage",
						desc = _G.OPTION_TOOLTIP_SHOW_DAMAGE or "",
						disabled = disabled,
						order = 2,
					},
					gamePetDamage = {
						type = "toggle",
						name = _G.SHOW_PET_MELEE_DAMAGE or _G.PET or "Pet Damage",
						desc = _G.OPTION_TOOLTIP_SHOW_PET_MELEE_DAMAGE or "",
						disabled = disabled,
						order = 3,
					},
					gameHealing = {
						type = "toggle",
						name = _G.SHOW_COMBAT_HEALING or _G.HEALS or "Healing",
						desc = _G.OPTION_TOOLTIP_SHOW_COMBAT_HEALING or "",
						disabled = disabled,
						order = 4,
					},
					gameLowHealth = {
						type = "toggle",
						name = _G.COMBAT_TEXT_SHOW_LOW_HEALTH_MANA_TEXT or "Low Mana & Health",
						desc = _G.OPTION_TOOLTIP_COMBAT_TEXT_SHOW_LOW_HEALTH_MANA or "",
						disabled = disabled,
						order = 5,
					},
					gameReactives = {
						type = "toggle",
						name = _G.COMBAT_TEXT_SHOW_REACTIVES_TEXT or "Spell Alerts",
						desc = _G.OPTION_TOOLTIP_COMBAT_TEXT_SHOW_REACTIVES or "",
						disabled = disabled,
						order = 6,
					},
				},
			},
		}
	})
end

_G.Parrot = Parrot
