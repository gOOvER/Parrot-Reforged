local _, ns = ...
local Parrot = ns.addon
local L = LibStub("AceLocale-3.0"):GetLocale("Parrot")

local newDict = Parrot.newDict
local Deformat = Parrot.Deformat

local LOOT_ITEM_SELF = _G.LOOT_ITEM_SELF
local LOOT_ITEM_SELF_MULTIPLE = _G.LOOT_ITEM_SELF_MULTIPLE
local LOOT_ITEM_PUSHED_SELF = _G.LOOT_ITEM_PUSHED_SELF
local LOOT_ITEM_PUSHED_SELF_MULTIPLE = _G.LOOT_ITEM_PUSHED_SELF_MULTIPLE
local LOOT_ITEM_CREATED_SELF = _G.LOOT_ITEM_CREATED_SELF
local LOOT_ITEM_CREATED_SELF_MULTIPLE = _G.LOOT_ITEM_CREATED_SELF_MULTIPLE
local LOOT_ITEM_REFUND = _G.LOOT_ITEM_REFUND
local LOOT_ITEM_REFUND_MULTIPLE = _G.LOOT_ITEM_REFUND_MULTIPLE
local ITEM_QUALITY_COLORS = _G.ITEM_QUALITY_COLORS

local GOLD_ICON_TEX   = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
local SILVER_ICON_TEX = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
local COPPER_ICON_TEX = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"

local function parse_CHAT_MSG_LOOT(chatmsg)
	if not chatmsg or ns.Compat.IsSecretValue(chatmsg) then return end
	-- check for multiple
	local itemLink, amount = Deformat(chatmsg, LOOT_ITEM_SELF_MULTIPLE)
	if not itemLink then
		itemLink, amount = Deformat(chatmsg, LOOT_ITEM_PUSHED_SELF_MULTIPLE)
	end
	if not itemLink then
		itemLink, amount = Deformat(chatmsg, LOOT_ITEM_CREATED_SELF_MULTIPLE)
	end
	if not itemLink then
		itemLink, amount = Deformat(chatmsg, LOOT_ITEM_REFUND_MULTIPLE)
	end

	-- check for single
	if not itemLink then
		itemLink = Deformat(chatmsg, LOOT_ITEM_SELF)
	end
	if not itemLink then
		itemLink = Deformat(chatmsg, LOOT_ITEM_PUSHED_SELF)
	end
	if not itemLink then
		itemLink = Deformat(chatmsg, LOOT_ITEM_CREATED_SELF)
	end
	if not itemLink then
		itemLink = Deformat(chatmsg, LOOT_ITEM_REFUND)
	end

	if itemLink then
		if not amount then
			amount = 1
		end
		local name, _, quality, _, _, _, _, _, _, texture = ns.Compat.GetItemInfo(itemLink)
		if not name then
			name = itemLink:match("%[(.-)%]")
			texture = ns.Compat.GetItemIconByID(itemLink)
		end
		if not name then return end

		local minQuality = (Parrot.db and Parrot.db.profile and tonumber(Parrot.db.profile.minLootQuality)) or 0
		if quality and quality < minQuality then
			return
		end

		local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
		if color and color.hex then
			name = ("%s%s|r"):format(color.hex, name)
		elseif not quality then
			local linkColor = itemLink:match("^(|c%x%x%x%x%x%x%x%x)")
			if linkColor then
				name = ("%s%s|r"):format(linkColor, name)
			end
		end

		local isEpicOrBetter = (quality and quality >= 4) and true or false
		return newDict(
			"name", name,
			"amount", amount,
			"total", ns.Compat.GetItemCount(itemLink) + amount,
			"icon", texture,
			"forceGlow", isEpicOrBetter,
			"glowR", isEpicOrBetter and color and color.r or nil,
			"glowG", isEpicOrBetter and color and color.g or nil,
			"glowB", isEpicOrBetter and color and color.b or nil
		)
	end
end

Parrot:RegisterCombatEvent{
	category = "Notification",
	subCategory = L["Loot"],
	name = "Loot items",
	localName = L["Loot items"],
	defaultTag = L["Loot [Name] +[Amount]([Total])"],
	tagTranslations = {
		Name = "name",
		Amount = "amount",
		Total = "total",
		Icon = "icon",
	},
	tagTranslationsHelp = {
		Name = L["The name of the item."],
		Amount = L["The amount of items looted."],
		Total = L["The total amount of items in inventory."],
	},
	events = {
		CHAT_MSG_LOOT = { parse = parse_CHAT_MSG_LOOT, },
	},
	color = "ffffff", -- white
}

local moneyStrings = {
	_G.LOOT_MONEY_SPLIT,
	_G.LOOT_MONEY_SPLIT_GUILD,
	_G.YOU_LOOT_MONEY,
	_G.YOU_LOOT_MONEY_GUILD,
	_G.LOOT_MONEY_REFUND,
}
local GOLD_AMOUNT_inv = _G.GOLD_AMOUNT:gsub("%%d", "(%1+)")
local SILVER_AMOUNT_inv = _G.SILVER_AMOUNT:gsub("%%d", "(%1+)")
local COPPER_AMOUNT_inv = _G.COPPER_AMOUNT:gsub("%%d", "(%1+)")
local GOLD_AMOUNT_SYMBOL = _G.GOLD_AMOUNT_SYMBOL
local SILVER_AMOUNT_SYMBOL = _G.SILVER_AMOUNT_SYMBOL
local COPPER_AMOUNT_SYMBOL = _G.COPPER_AMOUNT_SYMBOL

local function parse_CHAT_MSG_MONEY(chatmsg)
	if not chatmsg or ns.Compat.IsSecretValue(chatmsg) then return end
	for _, moneyString in ipairs(moneyStrings) do
		if moneyString then
			local amount = Deformat(chatmsg, moneyString)
			if amount then
				local gold = tonumber(chatmsg:match(GOLD_AMOUNT_inv)) or 0
				local silver = tonumber(chatmsg:match(SILVER_AMOUNT_inv)) or 0
				local copper = tonumber(chatmsg:match(COPPER_AMOUNT_inv)) or 0
				local totalCopper = 10000 * gold + 100 * silver + copper
				if totalCopper > 0 then
					return newDict(
						"amount", totalCopper,
						"icon", "Interface\\Icons\\INV_Misc_Coin_01"
					)
				end
			end
		end
	end
end

Parrot:RegisterCombatEvent{
	category = "Notification",
	subCategory = L["Loot"],
	name = "Loot money",
	localName = L["Loot money"],
	defaultTag = L["Loot +[Amount]"],
	tagTranslations = {
		Icon = "icon",
		Amount = function(info)
			local value = math.floor(tonumber(info.amount) or 0)
			local gold = math.floor(value / 10000)
			local silver = math.floor((value / 100) % 100)
			local copper = value % 100
			local useIcons = not (Parrot.db and Parrot.db.profile and Parrot.db.profile.lootCoinIcons == false)

			if useIcons then
				local parts = {}
				if gold > 0 then
					parts[#parts + 1] = ("%d%s"):format(gold, GOLD_ICON_TEX)
				end
				if silver > 0 or (gold > 0 and copper > 0) then
					parts[#parts + 1] = ("%d%s"):format(silver, SILVER_ICON_TEX)
				end
				if copper > 0 or #parts == 0 then
					parts[#parts + 1] = ("%d%s"):format(copper, COPPER_ICON_TEX)
				end
				return table.concat(parts, " ")
			end

			if value >= 10000 then
				return ("%d|cffffd700%s|r%d|cffc7c7cf%s|r%d|cffeda55f%s|r"):format(gold, GOLD_AMOUNT_SYMBOL, silver, SILVER_AMOUNT_SYMBOL, copper, COPPER_AMOUNT_SYMBOL)
			elseif value >= 100 then
				return ("%d|cffc7c7cf%s|r%d|cffeda55f%s|r"):format(silver, SILVER_AMOUNT_SYMBOL, copper, COPPER_AMOUNT_SYMBOL)
			else
				return ("%d|cffeda55f%s|r"):format(copper, COPPER_AMOUNT_SYMBOL)
			end
		end,
	},
	tagTranslationsHelp = {
		Amount = L["The amount of gold looted."],
	},
	events = {
		CHAT_MSG_MONEY = { parse = parse_CHAT_MSG_MONEY, },
	},
	color = "ffffff", -- white
}
