local _, ns = ...
local Parrot = ns.addon
if not Parrot then return end

local module = Parrot:NewModule("CombatFeedFallback")

local uidCounter = 0
local function nextFallbackUID()
	uidCounter = uidCounter + 1
	return uidCounter
end

local IsSecretValue = ns.Compat.IsSecretValue
local SafeUnitName = ns.Compat.SafeUnitName

local function fire(category, name, amount, placeholderSpellID, isCrit, recipientGUID, recipientName, sourceGUID, sourceName, abilityName)
	local isSecret = IsSecretValue(amount)
	if not isSecret and (type(amount) ~= "number" or amount <= 0) then return end
	local info = Parrot.newList()
	info.uid = nextFallbackUID()
	info.amount = amount
	info.abilityName = abilityName or ""
	info.realAmount = amount
	info.spellID = placeholderSpellID
	info.isCrit = not not isCrit
	info.hideCaster = false
	info.sourceName = sourceName or ""
	info.sourceID = sourceGUID or ""
	info.sourceFlags = 0
	info.recipientName = recipientName or ""
	info.recipientID = recipientGUID or ""
	info.destFlags = 0
	pcall(Parrot.TriggerCombatEvent, Parrot, category, name, info)
	Parrot.del(info)
end

local DAMAGE_ACTIONS = { WOUND = true }
local HEAL_ACTIONS = { HEAL = true }

local ATTRIBUTION_WINDOW = 4
local lastPlayerSpellID, lastPlayerSpellTime

local DOT_SPELLS = {
	[589] = 589, -- Shadow Word: Pain (Priest)
}
local dotCastSpellID

function module:OnUnitSpellcastSucceeded(uid, event, unit, castGUID, spellID)
	if unit ~= "player" or not spellID then return end
	if DOT_SPELLS[spellID] then
		dotCastSpellID = spellID
	end
	if C_MountJournal and C_MountJournal.GetMountFromSpell then
		local mountOk, mountID = pcall(C_MountJournal.GetMountFromSpell, spellID)
		if mountOk and mountID and mountID ~= 0 then return end
	end
	lastPlayerSpellID = spellID
	lastPlayerSpellTime = GetTime()
end

local function hasRecentCast()
	return lastPlayerSpellID and lastPlayerSpellTime and (GetTime() - lastPlayerSpellTime) <= ATTRIBUTION_WINDOW
end

local function incomingHealSpell()
	if hasRecentCast() then
		return lastPlayerSpellID
	end
	return nil
end

local function activeDotSpell()
	if not dotCastSpellID then return nil end
	local auraSpellID = DOT_SPELLS[dotCastSpellID]
	if AuraUtil and AuraUtil.FindAuraBySpellID then
		local ok, aura = pcall(AuraUtil.FindAuraBySpellID, auraSpellID, "target", "HARMFUL|PLAYER")
		if ok and aura then
			return dotCastSpellID
		end
	elseif ns.Compat.FindAura then
		local ok, name = pcall(ns.Compat.FindAura, "target", auraSpellID, "HARMFUL|PLAYER")
		if ok and name then
			return dotCastSpellID
		end
	end
	dotCastSpellID = nil
	return nil
end

local AUTO_ATTACK_SPELL = 6603
local IsCurrentSpellCompat = (C_Spell and C_Spell.IsCurrentSpell) or IsCurrentSpell

local function isAutoAttacking()
	if IsCurrentSpellCompat then
		local ok, current = pcall(IsCurrentSpellCompat, AUTO_ATTACK_SPELL)
		if ok and current then return true end
	end
	if IsAutoRepeatSpell then
		local ok, autoRepeat = pcall(IsAutoRepeatSpell)
		if ok and autoRepeat then return true end
	end
	return false
end

local function outgoingDamageSpell()
	if hasRecentCast() then
		return lastPlayerSpellID
	end
	local dot = activeDotSpell()
	if dot then
		return dot
	end
	if isAutoAttacking() then
		return AUTO_ATTACK_SPELL
	end
	return nil
end

function module:OnUnitCombat(uid, event, unitTarget, action, flagText, amount, schoolMask)
	if not Parrot.combatLogBlocked then return end
	if not IsSecretValue(amount) and (type(amount) ~= "number" or amount <= 0) then return end
	if IsSecretValue(unitTarget) or IsSecretValue(action) then return end

	local isCrit = (not IsSecretValue(flagText)) and (flagText == "CRITICAL") or false

	if unitTarget == "player" then
		if DAMAGE_ACTIONS[action] then
			fire("Incoming", "Melee damage", amount, nil, isCrit, "player", SafeUnitName("player", UNKNOWN))
		elseif HEAL_ACTIONS[action] then
			fire("Incoming", "Self heals", amount, incomingHealSpell(), isCrit, "player", SafeUnitName("player", UNKNOWN))
		end
	elseif unitTarget == "target" and DAMAGE_ACTIONS[action] then
		if UnitExists("target") and UnitCanAttack("player", "target") then
			fire("Outgoing", "Melee damage", amount, outgoingDamageSpell(), isCrit, "target", SafeUnitName("target", UNKNOWNOBJECT))
		end
	end
end

local damageMeterLastTotals = {}
local damageMeterTicker

local function damageMeterAvailable()
	return C_DamageMeter and Enum and Enum.DamageMeterType and true or false
end

local function safeAddZero(value)
	local ok, result = pcall(function() return value + 0 end)
	if ok and type(result) == "number" then
		return result
	end
	return nil
end

local function pollDamageMeterType(meterType, category, name)
	local ok, playerGUID = pcall(UnitGUID, "player")
	if not ok or not playerGUID then return end

	local okSource, source = pcall(C_DamageMeter.GetCombatSessionSourceFromType, 0, meterType, playerGUID)
	if not okSource or not source then return end

	local okSpells, combatSpells = pcall(function() return source.combatSpells end)
	if not okSpells or type(combatSpells) ~= "table" then return end

	for _, entry in ipairs(combatSpells) do
		local spellID = safeAddZero(entry.spellID)
		local totalAmount = safeAddZero(entry.totalAmount)
		if spellID and totalAmount and totalAmount > 0 then
			local key = meterType .. ":" .. spellID
			local previous = damageMeterLastTotals[key] or 0
			local delta = totalAmount - previous
			if delta < 0 then delta = totalAmount end
			damageMeterLastTotals[key] = totalAmount

			if delta > 0 then
				fire(category, name, delta, spellID, false, nil, nil, "player",
					SafeUnitName("player", UNKNOWN), ns.Compat.GetSpellName(spellID))
			end
		end
	end
end

local function pollDamageMeter()
	pollDamageMeterType(Enum.DamageMeterType.DamageDone, "Outgoing", "Melee damage")
	pollDamageMeterType(Enum.DamageMeterType.HealingDone, "Outgoing", "Heals")
end

function module:StartDamageMeterPolling()
	if not Parrot.combatLogBlocked or not damageMeterAvailable() or damageMeterTicker then return end
	wipe(damageMeterLastTotals)
	damageMeterTicker = C_Timer.NewTicker(0.5, pollDamageMeter)
end

function module:StopDamageMeterPolling()
	if damageMeterTicker then
		damageMeterTicker:Cancel()
		damageMeterTicker = nil
	end
end

function module:OnEnable()
	Parrot:RegisterBlizzardEvent(self, "UNIT_COMBAT", "OnUnitCombat")
	Parrot:RegisterBlizzardEvent(self, "UNIT_SPELLCAST_SUCCEEDED", "OnUnitSpellcastSucceeded")
	Parrot:RegisterBlizzardEvent(self, "PLAYER_REGEN_DISABLED", "StartDamageMeterPolling")
	Parrot:RegisterBlizzardEvent(self, "PLAYER_REGEN_ENABLED", "StopDamageMeterPolling")
end

