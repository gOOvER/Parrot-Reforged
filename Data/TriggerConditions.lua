local _, ns = ...
local Parrot = ns.addon
local module = Parrot:NewModule("TriggerConditionsData", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Parrot")

local newList = Parrot.newList

local GetSpellName = ns.Compat.GetSpellName
local SafeNumber = ns.Compat.SafeNumber
local SafeUnitName = ns.Compat.SafeUnitName
local SafeUnitGUID = ns.Compat.SafeUnitGUID
local IsSecretValue = ns.Compat.IsSecretValue

local function safeUnitIsFriend(unit1, unit2)
	local ok, val = pcall(UnitIsFriend, unit1, unit2)
	if not ok or IsSecretValue(val) then return nil end
	return val and 1 or 0
end

local playerGUID = UnitGUID("player")

function module:OnEnable()
	self:RegisterEvent("PLAYER_TARGET_CHANGED")
	pcall(self.RegisterEvent, self, "PLAYER_FOCUS_CHANGED")
	self:RegisterEvent("UNIT_PET")
end

local unitChoices = {
	["player"] = _G.PLAYER,
	["focus"] = _G.FOCUS,
	["target"] = _G.TARGET,
	["pet"] = _G.PET,
}

local comparatorChoices = {
	["<"] = "<",
	["<="] = "<=",
	["=="] = "==",
	[">="] = ">=",
	[">"] = ">",
	--	["~="] = "~=",
}
local friendlyChoices = {
	[1] = _G.FRIENDLY,
	[0] = _G.HOSTILE,
	[-1] = L["Any"],
}

local comparatorFunc = {
	["<"] = function(arg1, arg2) return arg1 < arg2 end,
	["<="] = function(arg1, arg2) return arg1 <= arg2 end,
	["=="] = function(arg1, arg2) return arg1 == arg2 end,
	[">="] = function(arg1, arg2) return arg1 >= arg2 end,
	[">"] = function(arg1, arg2) return arg1 > arg2 end,
	--	["~="] = function(arg1, arg2) return arg1 ~= arg2 end,
}

local function ret(arg)
	return arg
end

local function compare(val1, comparator, val2)
	val1 = SafeNumber(val1)
	val2 = SafeNumber(val2)
	if not val1 or not val2 or not comparatorFunc[comparator] then
		return false
	end
	return comparatorFunc[comparator](val1, val2)
end

local unitHealthStates = {
	player = {},
	target = {},
	pet = {},
	focus = {},
}


local function parseAmount(arg)
	if not arg then
		return ""
	elseif arg <= 1 then
		return (arg*100) .. "%"
	else
		return tostring(arg)
	end
end

local function saveAmount(arg)
	if arg:match("%d+%%") then
		local percent = tonumber(arg:sub(1,arg:len()-1))
		if percent then
			return percent/100
		end
		return
	else
		return tonumber(arg)
	end
end

Parrot:RegisterPrimaryTriggerCondition {
	name = "Unit health",
	localName = L["Unit health"],
	defaultParam = {
		unit = "player",
		friendly = -1,
		amount = 0.5,
		comparator = "<=",
	},
	param = {
		type = 'group',
		args = {
			unit = {
				name = L["Unit"],
				desc = L["The unit that is affected"],
				type = 'select',
				values = unitChoices,
			},
			friendly = {
				type = 'select',
				name = L["Hostility"],
				desc = L["Whether the unit should be friendly or hostile"],
				values = friendlyChoices,
			},
			amount = {
				type = 'string',
				name = L["Amount"],
				desc = L["Amount of health to compare"],
				parse = parseAmount,
				save = saveAmount,
			},
			comparator = {
				type = 'select',
				name = L["Comparator Type"],
				desc = L["How to compare actual value with parameter"],
				values = comparatorChoices,
			},
		},
	},
	events = {
		UNIT_HEALTH = ret,
		UNIT_MAXHEALTH = ret,
		UNIT_FACTION = ret,
	},
	check = function(ref, info)
		-- check if ref is complete
		if not ref.unit or not ref.amount or not ref.friendly or not ref.comparator or ref.unit ~= info then
			return false
		end
		-- check the friendly-flag
		if ref.friendly >= 0 then
			local friendly = safeUnitIsFriend("player", info)
			if friendly == nil or ref.friendly ~= friendly then
				return false
			end
		end
		-- everything fits, check the amount
		local curHealth = SafeNumber(UnitHealth(info))
		local maxHealth = SafeNumber(UnitHealthMax(info))
		if not curHealth or not maxHealth or maxHealth <= 0 then
			return false
		end
		local amount = ref.amount
		if amount <= 1 then
			amount = maxHealth * ref.amount
		end
		local good = compare(curHealth, ref.comparator, amount)
		-- check if the state has changed
		if good ~= unitHealthStates[ref.unit][ref] then
			unitHealthStates[ref.unit][ref] = good
			return good
		end
	end,
}

local powerTypeChoices = {
	[-1] = L["Any"],
	[0] = _G.MANA,
	[1] = _G.RAGE,
	[2] = _G.FOCUS,
	[3] = _G.ENERGY,
	[4] = _G.COMBO_POINTS,
	[5] = _G.RUNES,
	[6] = _G.RUNIC_POWER,
	[7] = _G.SOUL_SHARDS,
	[8] = _G.LUNAR_POWER,
	[9] = _G.HOLY_POWER,
	[11] = _G.MAELSTROM,
	[12] = _G.CHI,
	[13] = _G.INSANITY,
	[16] = _G.ARCANE_CHARGES,
	[17] = _G.FURY,
	[18] = _G.PAIN,
}

local unitPowerStates = {
	player = {},
	target = {},
	pet = {},
	focus = {},
}

--[[
-- wipe the states for units that can change when they are changed
--]]

function module:PLAYER_TARGET_CHANGED()
	wipe(unitHealthStates.target)
	wipe(unitPowerStates.target)
end

function module:PLAYER_FOCUS_CHANGED()
	wipe(unitHealthStates.focus)
	wipe(unitPowerStates.focus)
end

function module:UNIT_PET(_, unit)
	if unit == "player" then
		wipe(unitHealthStates.pet)
		wipe(unitPowerStates.pet)
	end
end


local function checkPower(ref)
	local powerType = ref.powerType
	if powerType == -1 then
		powerType = nil
	end
	local unit = ref.unit
	-- check the friendly-flag
	if ref.friendly >= 0 then
		local friendly = safeUnitIsFriend("player", unit)
		if friendly == nil or ref.friendly ~= friendly then
			return false
		end
	end
	-- everything fits, check the amount
	local actualAmount = SafeNumber(UnitPower(unit, powerType))
	local maxAmount = SafeNumber(UnitPowerMax(unit, powerType))
	if not actualAmount or not maxAmount then
		return false
	end
	local amount, percent = tostring(ref.amount):match("(%d+)(%%)")
	if percent then
		if maxAmount <= 0 then return false end
		amount = maxAmount * tonumber(amount) / 100
	else
		amount = tonumber(ref.amount)
	end
	return compare(actualAmount, ref.comparator, amount)
end

Parrot:RegisterPrimaryTriggerCondition {
	name = "Unit power",
	localName = L["Unit power"],
	defaultParam = {
		unit = "player",
		friendly = -1,
		amount = "50%",
		comparator = "<=",
	},
	param = {
		type = 'group',
		args = {
			unit = {
				name = L["Unit"],
				desc = L["The unit that is affected"],
				type = 'select',
				values = unitChoices,
			},
			friendly = {
				type = 'select',
				name = L["Hostility"],
				desc = L["Whether the unit should be friendly or hostile"],
				values = friendlyChoices,
			},
			amount = {
				type = 'string',
				name = L["Amount"],
				desc = L["Amount of health to compare"],
			},
			comparator = {
				type = 'select',
				name = L["Comparator Type"],
				desc = L["How to compare actual value with parameter"],
				values = comparatorChoices,
			},
			powerType = {
				type = 'select',
				name = L["Power type"],
				desc = L["Type of power"],
				values = powerTypeChoices,
			},
		},
	},
	events = {
		UNIT_POWER_UPDATE = ret,
		UNIT_MAXPOWER = ret,
	},
	check = function(ref, info)
		-- check if ref is complete
		if not ref.unit or not ref.amount or not ref.friendly or not ref.comparator or not ref.powerType or ref.unit ~= info then
			return false
		end
		local state = checkPower(ref)
		if state ~= unitPowerStates[ref.unit][ref] then
			unitPowerStates[ref.unit][ref] = state
			return state
		end
		return false
	end,
}

local missTypeChoices = {
	["ABSORB"] = _G.ABSORB,
	["BLOCK"] = _G.BLOCK,
	["DEFLECT"] = _G.DEFLECT,
	["DODGE"] = _G.DODGE,
	["EVADE"] = _G.EVADE,
	["IMMUNE"] = _G.IMMUNE,
	["MISS"] = _G.MISS,
	["PARRY"] = _G.PARRY,
	["REFLECT"] = _G.REFLECT,
	["RESIST"] = _G.RESIST,
}

Parrot:RegisterPrimaryTriggerCondition {
	name = "Incoming miss",
	localName = L["Incoming miss"],
	combatLogEvents = {
		{
			eventType = "SWING_MISSED",
			triggerData = function( srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, missType )
				if dstGUID ~= playerGUID then
					return nil
				end
				return missType
			end,
		},
		{
			eventType = "SPELL_MISSED",
			triggerData = function( srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName, spellSchool, missType )
					if dstGUID ~= playerGUID then
							return nil
					end
					return missType
			end,
		},
		{
			eventType = "RANGE_MISSED",
			triggerData = function( srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName, spellSchool, missType )
					if dstGUID ~= playerGUID then
							return nil
					end
					return missType
			end,
		},
	},
	param = {
		type = 'select',
		name = L["Miss type"],
		desc = L["Reason for the miss"],
		values = missTypeChoices,
	}
}

Parrot:RegisterPrimaryTriggerCondition {
	name = "Outgoing miss",
	localName = L["Outgoing miss"],
	combatLogEvents = {
		{
			eventType = "SWING_MISSED",
			triggerData = function( srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, missType )
				if srcGUID ~= playerGUID then
					return nil
				end
				return missType
			end,
		},
		{
			eventType = "SPELL_MISSED",
			triggerData = function( srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName, spellSchool, missType, amountMissed )
				if srcGUID ~= playerGUID then
						return nil
				end
				return missType
			end,
		},
		{
			eventType = "RANGE_MISSED",
			triggerData = function( srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName, spellSchool, missType )
					if srcGUID ~= playerGUID then
							return nil
					end
					return missType
			end,
		},
	},
	param = {
		type = 'select',
		name = L["Miss type"],
		desc = L["Reason for the miss"],
		values = missTypeChoices,
	},
}

Parrot:RegisterPrimaryTriggerCondition {
	name = "Incoming crit",
	localName = L["Incoming crit"],
	combatLogEvents = {
		{
			eventType = "SPELL_DAMAGE",
			triggerData = function(srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName, spellSchool, amount, school, resisted, blocked, absorbed, critical, glancing, crushing)
				if dstGUID ~= playerGUID or not critical then
					return nil
				end
				return true
			end,
		},
		{
			eventType = "SWING_DAMAGE",
			triggerData = function(srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, amount, school, resisted, blocked, absorbed, critical, glancing, crushing)
				if dstGUID ~= playerGUID or not critical then
					return nil
				end
				return true
			end,
		},
		{
			eventType = "RANGE_DAMAGE",
			triggerData = function(srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName, spellSchool, amount, school, resisted, blocked, absorbed, critical, glancing, crushing)
				if dstGUID ~= playerGUID or not critical then
					return nil
				end
				return true
			end,
		},
	},
	exclusive = true,
}

Parrot:RegisterPrimaryTriggerCondition {
	name = "Outgoing crit",
	localName = L["Outgoing crit"],
	combatLogEvents = {
		{
			eventType = "SPELL_DAMAGE",
			triggerData = function(srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName, spellSchool, amount, school, resisted, blocked, absorbed, critical, glancing, crushing)
				if srcGUID ~= playerGUID or not critical then
					return nil
				end
				return true
			end,
		},
		{
			eventType = "SWING_DAMAGE",
			triggerData = function(srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, amount, school, resisted, blocked, absorbed, critical, glancing, crushing)
				if srcGUID ~= playerGUID or not critical then
					return nil
				end
				return true
			end,
		},
		{
			eventType = "RANGE_DAMAGE",
			triggerData = function(srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName, spellSchool, amount, school, resisted, blocked, absorbed, critical, glancing, crushing)
				if srcGUID ~= playerGUID or not critical then
					return nil
				end
				return true
			end,
		},
	},
	exclusive = true,
}

Parrot:RegisterPrimaryTriggerCondition {
	name = "Outgoing cast",
	localName = L["Outgoing cast"],
	combatLogEvents = {
		{
			eventType = "SPELL_CAST_SUCCESS",
			triggerData = function(srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName)
				if srcGUID ~= playerGUID then
					return nil
				end
				return spellName
			end,
		},
		{
			eventType = "SPELL_DAMAGE",
			triggerData = function(srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName, spellSchool, amount, school, resisted, blocked, absorbed, critical, glancing, crushing)
				if srcGUID ~= playerGUID then
					return nil
				end
				return spellName
			end,
		},
		{
			eventType = "SPELL_PERIODIC_DAMAGE",
			triggerData = function(srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName, spellSchool, amount, school, resisted, blocked, absorbed, critical, glancing, crushing)
				if srcGUID ~= playerGUID then
					return nil
				end
				return spellName
			end,
		},
	},
	param = {
		type = 'string',
		-- usage = L["<Skill name>"],
	},
}

Parrot:RegisterPrimaryTriggerCondition {
	name = "Incoming cast",
	localName = L["Incoming cast"],
	combatLogEvents = {
		{
			eventType = "SPELL_CAST_SUCCESS",
			triggerData = function(srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName)
				if dstGUID ~= playerGUID then
					return nil
				end
				return spellName
			end,
		},
		{
			eventType = "SPELL_DAMAGE",
			triggerData = function(srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName, spellSchool, amount, school, resisted, blocked, absorbed, critical, glancing, crushing)
				if dstGUID ~= playerGUID then
					return nil
				end
				return spellName
			end,
		},
		{
			eventType = "SPELL_PERIODIC_DAMAGE",
			triggerData = function(srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName, spellSchool, amount, school, resisted, blocked, absorbed, critical, glancing, crushing)
				if dstGUID ~= playerGUID then
					return nil
				end
				return spellName
			end,
		},
	},
	param = {
		type = 'string',
		-- usage = L["<Skill name>"],
	},
}

Parrot:RegisterPrimaryTriggerCondition {
	name = "Cast started",
	localName = L["Cast started"],
	combatLogEvents = {
		{
			eventType = "SPELL_CAST_START",
			triggerData = function (_, srcName, _, _, dstName, _, spellId, spellName)
				local data = newList()
				data.srcName = srcName
				data.spellName = spellName
				data.spellId = spellId
				return data
			end,
		},
	},
	defaultParam = {
		unit = "target",
		spell = "",
	},
	param = {
		type = 'group',
		args = {
			unit = {
				name = L["Unit"],
				desc = L["The unit that started the cast"],
				type = 'select',
				values = unitChoices,
			},
			spell = {
				name = L["Spell"],
				desc = L["Spell name or spell id"],
				type = 'input',
			},
		},
	},
	check = function(ref, info)
		if not ref.unit or info.srcName ~= SafeUnitName(ref.unit) then
			return false
		end
		local spellid = tonumber(ref.spell)
		if spellid then
			return info.spellId == spellid
		else
			return info.spellName == ref.spell
		end
	end,
}

local function parseSpellDamage(_, srcName, _, _, dstName, _, spellId, spellName, _, amount, _, _, _, _, critical)
	local data = newList()
	data.dstName = dstName
	data.srcName = srcName
	data.amount = amount
	data.critical = not not critical
	data.spellName = spellName
	data.spellId = spellId
	return data
end

local function parseSwingDamage(_, srcName, _, _, dstName, _, amount, _, _, _, _, _, critical)
	local data = newList()
	data.dstName = dstName
	data.srcName = srcName
	data.amount = amount
	data.critical = not not critical
	return data
end

Parrot:RegisterPrimaryTriggerCondition {
	name = "Incoming damage",
	localName = L["Incoming damage"],
	combatLogEvents = {
		{
			eventType = "SWING_DAMAGE",
			check = function(_, _, _, dstGUID)
				return dstGUID == playerGUID
			end,
			triggerData = parseSwingDamage,
		},
		{
			eventType = "SPELL_PERIODIC_DAMAGE",
			check = function(_, _, _, dstGUID)
				return dstGUID == playerGUID
			end,
			triggerData = parseSpellDamage,
		},
		{
			eventType = "SPELL_DAMAGE",
			check = function(_, _, _, dstGUID)
				return dstGUID == playerGUID
			end,
			triggerData = parseSpellDamage,
		},
		{
			eventType = "RANGE_DAMAGE",
			check = function(_, _, _, dstGUID)
				return dstGUID == playerGUID
			end,
			triggerData = parseSpellDamage,
		},
	},
	defaultParam = {
		unit = "target",
		comparator = ">",
		amount = 0,
	},
	param = {
		type = 'group',
		args = {
			unit = {
				name = L["Unit"],
				desc = L["The unit that attacked you"],
				type = 'input',
				usage = "\"player\" or \"target\" or \"<unit name>\"", -- TODO L[]
			},
			amount = {
				name = L["Amount"],
				desc = L["Amount of damage to compare with"],
				type = 'input',
				save = function(value) return tonumber(value) end,
				parse = function(value) return tostring(value or "") end,
			},
			comparator = {
				type = 'select',
				name = L["Comparator Type"],
				desc = L["How to compare actual value with parameter"],
				values = comparatorChoices,
			},
		},
	},
	check = function(ref, info)
		if not ref.unit or not ref.amount or not ref.comparator then
			return false
		end
		if ref.unit == info.srcName or info.srcName == SafeUnitName(ref.unit) then
			return compare(info.amount, ref.comparator, ref.amount)
		end
		return false
	end,
}

Parrot:RegisterPrimaryTriggerCondition {
	name = "Outgoing damage",
	localName = L["Outgoing damage"],
	combatLogEvents = {
		{
			eventType = "SWING_DAMAGE",
			check = function(srcGUID)
				return srcGUID == playerGUID
			end,
			triggerData = parseSwingDamage,
		},
		{
			eventType = "SPELL_PERIODIC_DAMAGE",
			check = function(srcGUID)
				return srcGUID == playerGUID
			end,
			triggerData = parseSpellDamage,
		},
		{
			eventType = "SPELL_DAMAGE",
			check = function(srcGUID)
				return srcGUID == playerGUID
			end,
			triggerData = parseSpellDamage,
		},
		{
			eventType = "RANGE_DAMAGE",
			check = function(srcGUID)
				return srcGUID == playerGUID
			end,
			triggerData = parseSpellDamage,
		},
	},
	defaultParam = {
		unit = "target",
		comparator = ">",
		amount = 0,
	},
	param = {
		type = 'group',
		args = {
			unit = {
				name = L["Unit"],
				desc = L["The unit that you attacked"],
				type = 'input',
				usage = "\"player\" or \"target\" or \"<unit name>\"", -- TODO L[]
			},
			amount = {
				name = L["Amount"],
				desc = L["Amount of damage to compare with"],
				type = 'input',
				save = function(value) return tonumber(value) end,
				parse = function(value) return tostring(value or "") end,
			},
			comparator = {
				type = 'select',
				name = L["Comparator Type"],
				desc = L["How to compare actual value with parameter"],
				values = comparatorChoices,
			},
		},
	},
	check = function(ref, info)
		if not ref.unit or not ref.amount or not ref.comparator then
			return false
		end
		if ref.unit == info.dstName or info.dstName == SafeUnitName(ref.unit) then
			return compare(info.amount, ref.comparator, ref.amount)
		end
		return false
	end,
}

Parrot:RegisterSecondaryTriggerCondition {
	name = "Unit power",
	localName = L["Unit power"],
	defaultParam = {
		unit = "player",
		comparator = "<=",
		amount = "40%",
		friendly = -1,
	},
	param = {
		type = 'group',
		args = {
			unit = {
				name = L["Unit"],
				desc = L["The unit that is affected"],
				type = 'select',
				values = unitChoices,
			},
			friendly = {
				type = 'select',
				name = L["Hostility"],
				desc = L["Whether the unit should be friendly or hostile"],
				values = friendlyChoices,
			},
			amount = {
				type = 'string',
				name = L["Amount"],
				desc = L["Amount of power to compare"],
			},
			powerType = {
				type = 'select',
				name = L["Power type"],
				desc = L["Type of power"],
				values = powerTypeChoices,
			},
			comparator = {
				type = 'select',
				name = L["Comparator Type"],
				desc = L["How to compare actual value with parameter"],
				values = comparatorChoices,
			},
		},
	},
	check = function(ref)
		-- check if ref is complete
		if not ref.unit or not ref.amount or not ref.friendly or not ref.comparator or not ref.powerType then
			return false
		end
		return checkPower(ref)
	end,
}

Parrot:RegisterSecondaryTriggerCondition {
	name = "Unit health",
	localName = L["Unit health"],
	defaultParam = {
		unit = "player",
		comparator = "<=",
		amount = 0.5,
		friendly = -1,
	},
	param = {
		type = 'group',
		args = {
			unit = {
				name = L["Unit"],
				desc = L["The unit that is affected"],
				type = 'select',
				values = unitChoices,
			},
			friendly = {
				type = 'select',
				name = L["Hostility"],
				desc = L["Whether the unit should be friendly or hostile"],
				values = friendlyChoices,
			},
			amount = {
				type = 'string',
				name = L["Amount"],
				desc = L["Amount of health to compare"],
				save = saveAmount,
				parse = parseAmount,
			},
			comparator = {
				type = 'select',
				name = L["Comparator Type"],
				desc = L["How to compare actual value with parameter"],
				values = comparatorChoices,
			},
		},
	},
	check = function(ref)
		if not ref.unit or not ref.amount or not ref.friendly or not ref.comparator then
			return false
		end
		if ref.friendly >= 0 then
			local friendly = safeUnitIsFriend("player", ref.unit)
			if friendly == nil or ref.friendly ~= friendly then
				return false
			end
		end
		local curHealth = SafeNumber(UnitHealth(ref.unit))
		local maxHealth = SafeNumber(UnitHealthMax(ref.unit))
		if not curHealth or not maxHealth or maxHealth <= 0 then
			return false
		end
		local amount = ref.amount
		if amount <= 1 then
			amount = maxHealth * ref.amount
		end
		return compare(curHealth, ref.comparator, amount)
	end,
}

Parrot:RegisterSecondaryTriggerCondition {
	name = "Druid Form",
	localName = L["Druid Form"],
	notLocalName = L["Not in Druid Form"],
	param = {
		type = 'select',
		values = {
			["Bear Form"] = GetSpellName(5487) or "Bear Form",
			["Cat Form"] = GetSpellName(768) or "Cat Form",
			["Travel Form"] = GetSpellName(783) or "Travel Form",
			["Moonkin Form"] = GetSpellName(24858) or "Moonkin Form",
		}
	},
	check = function(param)
		if select(2,UnitClass("player")) ~= "DRUID" then
			return true
		end

		local form = GetShapeshiftForm and GetShapeshiftForm() or 0
		if form == 1 then
			return param == "Bear Form"
		elseif form == 2 then
			return param == "Cat Form"
		elseif form == 3 then
			return param == "Travel Form"
		elseif form == 4 then
			return param == "Moonkin Form"
		end
		return false
	end,
}

Parrot:RegisterSecondaryTriggerCondition {
	name = "Warrior Stance",
	localName = L["Warrior Stance"] or "Warrior Stance",
	notLocalName = L["Not in Warrior Stance"] or "Not in Warrior Stance",
	param = {
		type = 'select',
		values = {
			["Battle Stance"] = GetSpellName(2457) or "Battle Stance",
			["Defensive Stance"] = GetSpellName(71) or "Defensive Stance",
			["Berserker Stance"] = GetSpellName(2458) or "Berserker Stance",
		}
	},
	check = function(param)
		if select(2, UnitClass("player")) ~= "WARRIOR" then
			return true
		end

		local form = GetShapeshiftForm and GetShapeshiftForm() or 0
		if form == 1 then
			return param == "Battle Stance"
		elseif form == 2 then
			return param == "Defensive Stance"
		elseif form == 3 then
			return param == "Berserker Stance"
		end
		return false
	end,
}

Parrot:RegisterSecondaryTriggerCondition {
	name = "Grouped",
	localName = L["In a group"],
	check = function()
		return IsInGroup and IsInGroup() or false
	end,
	exclusive = true,
}

Parrot:RegisterSecondaryTriggerCondition {
	name = "Mounted",
	localName = L["Mounted"],
	notLocalName = L["Not mounted"],
	check = function()
		return IsMounted and IsMounted() or false
	end,
	exclusive = true,
}

Parrot:RegisterSecondaryTriggerCondition {
	name = "InVehicle",
	localName = L["In vehicle"],
	notLocalName = L["Not in vehicle"],
	check = function()
		return UnitInVehicle and UnitInVehicle("player") or false
	end,
	exclusive = true
}

Parrot:RegisterPrimaryTriggerCondition {
	name = "Successful spell cast",
	localName = L["Successful spell cast"],
	combatLogEvents = {
		{
			eventType = "SPELL_CAST_SUCCESS",
			triggerData = function( srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName )
				local info = newList()
				info.srcGUID = srcGUID
				info.spellId = spellId
				info.spellName = spellName
				return info
			end,
		},
	},
	param = {
		type = 'group',
		args = {
			unit = {
				name = L["Unit"],
				desc = L["The unit that casted the spell"],
				type = 'select',
				values = unitChoices,
			},
			friendly = {
				type = 'select',
				name = L["Hostility"],
				desc = L["Whether the unit should be friendly or hostile"],
				values = friendlyChoices,
			},
			spell = {
				name = L["Spell"],
				desc = L["Spell name or spell id"],
				type = 'input',
			},
		},
	},
	check = function(ref, info)
		local unitGUID = ref.unit and SafeUnitGUID(ref.unit)
		if not ref.unit or not ref.friendly or not ref.spell or not unitGUID or unitGUID ~= info.srcGUID then
			return false
		end
		if ref.friendly >= 0 then
			local friendly = safeUnitIsFriend("player", ref.unit)
			if friendly == nil or ref.friendly ~= friendly then
				return false
			end
		end
		local spell = tonumber(ref.spell)
		if spell then
			return info.spellId == spell
		else
			return info.spellName == ref.spell
		end
	end,
}

Parrot:RegisterSecondaryTriggerCondition {
	name = "Target is player",
	localName = L["Target is player"],
	notLocalName = L["Target is NPC"],
	check = function()
		if UnitIsDeadOrGhost("target") then
			return false
		end
		return UnitIsPlayer("target")
	end,
	exclusive = true
}


local luacache = {}

Parrot:RegisterSecondaryTriggerCondition {
	name = "Lua function",
	localName = L["Lua function"],
	defaultParam = "return true",
	param = {
		type = 'string',
		multiline = true,
		width = 'full',
	},
	check = function(param)
		local func = luacache[param]
		if not func then
			-- It's not there yet. build it+
			if type(param) ~= 'string' then
				return false
			end
			local lua_string = 'return function() '..param..' end'
			local create_func, err = ns.Compat.LoadChunk(lua_string, "ParrotLuaTrigger")
			if create_func then
				func = create_func()
				-- and put it in the cache
				luacache[param] = func
			else
				geterrorhandler()(err)
				return false
			end
		end
		return func()
	end,
}

Parrot:RegisterPrimaryTriggerCondition {
	name = "Spell overlay",
	localName = L["Spell overlay"],
	param = {
		type = "input",
		usage = L["<SpellId>"],
	},
	events = {
		SPELL_ACTIVATION_OVERLAY_SHOW = ret, -- hidden aura spell id
		SPELL_ACTIVATION_OVERLAY_GLOW_SHOW = ret, -- button spell id
	},
	check = function(ref, info)
		return tonumber(ref) == info
	end,
}
