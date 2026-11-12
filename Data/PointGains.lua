local _, ns = ...
local Parrot = ns.addon
local module = Parrot:NewModule("PointGains")
local L = LibStub("AceLocale-3.0"):GetLocale("Parrot")

local newDict, newList = Parrot.newDict, Parrot.newList
local Deformat = Parrot.Deformat

local currentXP = 0

function module:OnEnable()
	currentXP = ns.Compat.SafeNumber(UnitXP("player")) or 0
end

-- Currency
local CURRENCY_GAINED = _G.CURRENCY_GAINED
local CURRENCY_GAINED_MULTIPLE = _G.CURRENCY_GAINED_MULTIPLE
local ITEM_QUALITY_COLORS = _G.ITEM_QUALITY_COLORS

local function parseCurrencyUpdate(chatmsg)
	if not chatmsg or ns.Compat.IsSecretValue(chatmsg) then return end
	local currency, amount = Deformat(chatmsg, CURRENCY_GAINED_MULTIPLE)
	if not currency then
		currency = Deformat(chatmsg, CURRENCY_GAINED)
	end

	if currency then
		local currencyInfo = ns.Compat.GetCurrencyInfoFromLink(currency)
		local name = (currencyInfo and currencyInfo.name ~= "" and currencyInfo.name) or currency:match("%[(.-)%]")
		if not name then return end
		local color = currencyInfo and currencyInfo.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[currencyInfo.quality]
		if color and color.hex then
			name = ("%s%s|r"):format(color.hex, name)
		end
		return newDict(
			"currency", name,
			"amount", amount or 1,
			"total", (currencyInfo and currencyInfo.quantity) or 0,
			"icon", currencyInfo and currencyInfo.iconFileID
		)
	end
end

Parrot:RegisterCombatEvent{
	category = "Notification",
	subCategory = L["Loot"],
	name = "Currency gains",
	localName = L["Currency gains"],
	defaultTag = "+[Amount] [Currency] ([Total])",
	tagTranslations = {
		Amount = "amount",
		Currency = "currency",
		Total = "total",
		Icon = "icon",
	},
	tagTranslationsHelp = {
		Currency = L["Name of the currency"],
		Amount = L["The amount of currency gained."],
		Total = L["Your total amount of the currency."],
	},
	color = "7f7fb2", -- blue-gray
	events = {
		CHAT_MSG_CURRENCY = { parse = parseCurrencyUpdate },
	}
}

-- Honor gains (PvP across Classic, TBC, Wrath, Cata, MoP, Retail)
local HONOR = _G.COMBAT_TEXT_HONOR or _G.HONOR or "Honor"
local honorStrings = {
	_G.COMBAT_HONOR_GAIN,
	_G.COMBAT_HONOR_GAIN_NO_RANK,
	_G.AWARD_HONOR_GAINED,
}

local function getPlayerPvPIcon()
	local factionGroup = UnitFactionGroup and UnitFactionGroup("player")
	if factionGroup == "Horde" then
		return "Interface\\Icons\\INV_BannerPVP_01"
	elseif factionGroup == "Alliance" then
		return "Interface\\Icons\\INV_BannerPVP_02"
	end
	return "Interface\\Icons\\Achievement_PVP_O_01"
end

local function parseHonorGain(chatmsg)
	if not chatmsg or ns.Compat.IsSecretValue(chatmsg) then return end
	for i = 1, #honorStrings do
		local pat = honorStrings[i]
		if pat then
			local a, b, c = Deformat(chatmsg, pat)
			local num = tonumber(c) or tonumber(b) or tonumber(a)
			if num and num > 0 then
				local source = (type(a) == "string" and a) or nil
				return newDict(
					"amount", math.floor(num + 0.5),
					"source", source or "",
					"icon", getPlayerPvPIcon()
				)
			end
		end
	end
	local fallbackNum = tonumber(chatmsg:match("(%d+)"))
	if fallbackNum and fallbackNum > 0 then
		return newDict(
			"amount", fallbackNum,
			"source", "",
			"icon", getPlayerPvPIcon()
		)
	end
end

Parrot:RegisterCombatEvent{
	category = "Notification",
	subCategory = L["Reputation"],
	name = "Honor gains",
	localName = L["Honor gains"],
	defaultTag = "+[Amount] " .. HONOR,
	events = {
		CHAT_MSG_COMBAT_HONOR_GAIN = { parse = parseHonorGain },
	},
	tagTranslations = {
		Amount = "amount",
		Name = "source",
		Icon = "icon",
	},
	tagTranslationsHelp = {
		Amount = L["The amount of honor gained."],
		Name = L["The name of the enemy slain."],
	},
	color = "ffd147",
}

-- Reputation
Parrot:RegisterThrottleType("Reputation gains", L["Reputation gains"], 0.1, true)

local REPUTATION = _G.REPUTATION
local FACTION_STANDING_INCREASED = _G.FACTION_STANDING_INCREASED
local FACTION_STANDING_INCREASED_ACCOUNT_WIDE = _G.FACTION_STANDING_INCREASED_ACCOUNT_WIDE
local FACTION_STANDING_INCREASED_ACH_BONUS = _G.FACTION_STANDING_INCREASED_ACH_BONUS
local FACTION_STANDING_INCREASED_ACH_BONUS_ACCOUNT_WIDE = _G.FACTION_STANDING_INCREASED_ACH_BONUS_ACCOUNT_WIDE
local FACTION_STANDING_INCREASED_BONUS = _G.FACTION_STANDING_INCREASED_BONUS
local FACTION_STANDING_INCREASED_DOUBLE_BONUS = _G.FACTION_STANDING_INCREASED_DOUBLE_BONUS
local FACTION_STANDING_DECREASED = _G.FACTION_STANDING_DECREASED
local FACTION_STANDING_DECREASED_ACCOUNT_WIDE = _G.FACTION_STANDING_DECREASED_ACCOUNT_WIDE

local function repThrottleFunc(info)
	local num = info.throttleCount or 0
	if num > 1 then
		return (" (%dx)"):format(num)
	end
	return nil
end

local function parseRepGain(chatmsg)
	if not chatmsg or ns.Compat.IsSecretValue(chatmsg) then return end
	local faction, amount = Deformat(chatmsg, FACTION_STANDING_INCREASED)
	if not faction and FACTION_STANDING_INCREASED_ACCOUNT_WIDE then
		faction, amount = Deformat(chatmsg, FACTION_STANDING_INCREASED_ACCOUNT_WIDE)
	end
	if not faction and FACTION_STANDING_INCREASED_ACH_BONUS then
		faction, amount = Deformat(chatmsg, FACTION_STANDING_INCREASED_ACH_BONUS)
	end
	if not faction and FACTION_STANDING_INCREASED_ACH_BONUS_ACCOUNT_WIDE then
		faction, amount = Deformat(chatmsg, FACTION_STANDING_INCREASED_ACH_BONUS_ACCOUNT_WIDE)
	end
	if not faction and FACTION_STANDING_INCREASED_BONUS then
		faction, amount = Deformat(chatmsg, FACTION_STANDING_INCREASED_BONUS)
	end
	if not faction and FACTION_STANDING_INCREASED_DOUBLE_BONUS then
		faction, amount = Deformat(chatmsg, FACTION_STANDING_INCREASED_DOUBLE_BONUS)
	end
	if faction and amount then
		local info = newList()
		info.amount = amount
		info.faction = faction
		return info
	end
	return nil
end

local function parseRepLoss(chatmsg)
	if not chatmsg or ns.Compat.IsSecretValue(chatmsg) then return end
	local faction, amount = Deformat(chatmsg, FACTION_STANDING_DECREASED)
	if not faction and FACTION_STANDING_DECREASED_ACCOUNT_WIDE then
		faction, amount = Deformat(chatmsg, FACTION_STANDING_DECREASED_ACCOUNT_WIDE)
	end
	if faction and amount then
		local info = newList()
		info.amount = amount
		info.faction = faction
		return info
	end
	return nil
end

Parrot:RegisterCombatEvent{
	category = "Notification",
	subCategory = L["Reputation"],
	name = "Reputation gains",
	localName = L["Reputation gains"],
	defaultTag = "+[Amount] " .. REPUTATION .. " ([Faction])",
	events = {
		CHAT_MSG_COMBAT_FACTION_CHANGE = { parse = parseRepGain },
	},
	tagTranslations = {
		Amount = "amount",
		Faction = "faction",
	},
	tagTranslationsHelp = {
		Amount = L["The amount of reputation gained."],
		Faction = L["The name of the faction."],
	},
	color = "7f7fb2", -- blue-gray
	throttle = {
		"Reputation gains",
		"faction",
		{ "throttleCount", repThrottleFunc, },
	},
}

Parrot:RegisterCombatEvent{
	category = "Notification",
	subCategory = L["Reputation"],
	name = "Reputation losses",
	localName = L["Reputation losses"],
	defaultTag = "-[Amount] " .. REPUTATION .. " ([Faction])",
	events = {
		CHAT_MSG_COMBAT_FACTION_CHANGE = { parse = parseRepLoss },
	},
	tagTranslations = {
		Amount = function(info) return info.amount end,
		Faction = "faction",
	},
	tagTranslationsHelp = {
		Amount = L["The amount of reputation lost."],
		Faction = L["The name of the faction."],
	},
	color = "7f7fb2", -- blue-gray
}

-- Major Faction Renown rank-up (Retail Dragonflight / War Within / Midnight)
if C_MajorFactions and C_MajorFactions.GetMajorFactionData then
	local RENOWN_LABEL = _G.RENOWN_LEVEL_LABEL or L["Renown %d"]
	local function parseRenownRankUp(majorFactionID, newRenownLevel)
		local fID = ns.Compat.SafeNumber(majorFactionID, nil)
		local level = ns.Compat.SafeNumber(newRenownLevel, nil)
		if not fID or not level then return nil end
		local ok, data = pcall(C_MajorFactions.GetMajorFactionData, fID)
		local factionName = (ok and data and ns.Compat.SafeString(data.name, nil)) or REPUTATION
		return newDict(
			"faction", factionName,
			"amount", level,
			"icon", "Interface\\Icons\\UI_MajorFaction_Centaur",
			"forceGlow", true,
			"glowR", 1.0,
			"glowG", 0.84,
			"glowB", 0.18
		)
	end

	Parrot:RegisterCombatEvent{
		category = "Notification",
		subCategory = L["Reputation"],
		name = "Renown rank-up",
		localName = L["Renown rank-up"],
		defaultTag = "[Faction] — " .. (RENOWN_LABEL:find("%%d") and RENOWN_LABEL:gsub("%%d", "[Amount]") or (L["Renown"] .. " [Amount]!")) ,
		events = {
			MAJOR_FACTION_RENOWN_LEVEL_CHANGED = { parse = parseRenownRankUp },
		},
		tagTranslations = {
			Faction = "faction",
			Amount = "amount",
			Icon = "icon",
		},
		tagTranslationsHelp = {
			Faction = L["The name of the faction."],
			Amount = L["New renown level reached."],
		},
		color = "ffd100",
		sticky = true,
		forceGlow = true,
	}
end

-- Skill gains
local SKILL_RANK_UP = _G.SKILL_RANK_UP

local function retrieveAbilityName(info)
	return Parrot:GetAbbreviatedSpell(info.abilityName)
end

local function parseSkillGain(chatmsg)
	if not chatmsg or ns.Compat.IsSecretValue(chatmsg) then return end
	local skill, amount = Deformat(chatmsg, SKILL_RANK_UP)
	if skill and amount then
		local info = newList()
		info.abilityName = skill
		info.amount = amount
		return info
	end
end

Parrot:RegisterCombatEvent{
	category = "Notification",
	name = "Skill gains",
	localName = L["Skill gains"],
	defaultTag = "[Skillname]: [Amount]",
	events = {
		CHAT_MSG_SKILL = { parse = parseSkillGain },
	},
	tagTranslations = {
		Skillname = retrieveAbilityName,
		Amount = "amount",
	},
	tagTranslationsHelp = {
		Skill = L["The skill which experienced a gain."],
		Amount = L["The amount of skill points currently."]
	},
	color = "5555ff", -- semi-light blue
}

-- XP gains
local XP = _G.XP

local function parseXPUpdate()
	local newXP = ns.Compat.SafeNumber(UnitXP("player"))
	if not newXP then return end
	local delta = newXP - currentXP
	if delta > 0 then
		local info = newDict("amount", delta)
		currentXP = newXP
		return info
	end
end

Parrot:RegisterCombatEvent{
	category = "Notification",
	name = "Experience gains",
	localName = L["Experience gains"],
	defaultTag = "[Amount] " .. XP,
	tagTranslations = {
		Amount = "amount",
	},
	tagTranslationsHelp = {
		Amount = L["The amount of experience points gained."]
	},
	color = "bf4ccc", -- magenta
	sticky = true,
	defaultDisabled = true,
	events = {
		PLAYER_XP_UPDATE = { parse = parseXPUpdate },
	},
}
