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
local SafeNumber = ns.Compat.SafeNumber
local SafeString = ns.Compat.SafeString
local SafeUnitName = ns.Compat.SafeUnitName
local SafeUnitGUID = ns.Compat.SafeUnitGUID

local spellSchoolCache = {}

local function fire(category, name, amount, placeholderSpellID, isCrit, recipientGUID, recipientName, sourceGUID, sourceName, abilityName, schoolMask)
	local isSecret = IsSecretValue(amount)
	if not isSecret and (type(amount) ~= "number" or amount <= 0) then return end
	local cleanSchool = (not IsSecretValue(schoolMask) and type(schoolMask) == "number" and schoolMask > 0) and schoolMask or nil
	if not cleanSchool and placeholderSpellID and not IsSecretValue(placeholderSpellID) then
		cleanSchool = spellSchoolCache[placeholderSpellID]
	end
	local info = Parrot.newList()
	info.uid = nextFallbackUID()
	info.amount = amount
	info.abilityName = abilityName or (placeholderSpellID and ns.Compat.GetSpellName(placeholderSpellID)) or ""
	info.realAmount = amount
	info.spellID = placeholderSpellID
	info.damageType = cleanSchool
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

local function fireMiss(category, name, missType, amount, placeholderSpellID, recipientGUID, recipientName, sourceGUID, sourceName)
	local info = Parrot.newList()
	info.uid = nextFallbackUID()
	info.missType = missType
	info.amount = (not IsSecretValue(amount) and type(amount) == "number" and amount > 0) and amount or 0
	info.abilityName = (placeholderSpellID and ns.Compat.GetSpellName(placeholderSpellID)) or ""
	info.spellID = placeholderSpellID
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

local function fireAura(eventName, spellID, spellName, stacks, auraType, recipientGUID, recipientName)
	if spellID == 450552 then return end -- suppress Monk Jade Walk refresh spam
	local info = Parrot.newList()
	info.uid = nextFallbackUID()
	info.spellID = spellID
	info.abilityName = spellName or (spellID and ns.Compat.GetSpellName(spellID)) or ""
	info.amount = stacks or 1
	info.auraType = auraType
	info.hideCaster = false
	info.recipientID = recipientGUID or ""
	info.recipientName = recipientName or ""
	info.destFlags = 0
	pcall(Parrot.TriggerCombatEvent, Parrot, "Notification", eventName, info)
	Parrot.del(info)
end

local DAMAGE_ACTIONS = { WOUND = true }
local HEAL_ACTIONS = { HEAL = true }
local MISS_ACTION_MAP = {
	ABSORB  = "absorbs",
	BLOCK   = "blocks",
	DEFLECT = "deflects",
	DODGE   = "dodges",
	EVADE   = "evades",
	IMMUNE  = "immunes",
	MISS    = "misses",
	PARRY   = "parries",
	REFLECT = "reflects",
	RESIST  = "resists",
}

local ATTRIBUTION_WINDOW = 3.5
local PERIODIC_AURA_WINDOW = 30
local lastPlayerSpellID, lastPlayerSpellTime
local recentPlayerCasts = {}

local function recordRecentCast(spellID)
	local now = GetTime()
	for i = #recentPlayerCasts, 1, -1 do
		if recentPlayerCasts[i].spellID == spellID or (now - recentPlayerCasts[i].time) > PERIODIC_AURA_WINDOW then
			table.remove(recentPlayerCasts, i)
		end
	end
	table.insert(recentPlayerCasts, 1, { spellID = spellID, time = now })
	while #recentPlayerCasts > 8 do
		table.remove(recentPlayerCasts)
	end
end

function module:OnUnitSpellcastSucceeded(uid, event, unit, castGUID, spellID)
	if IsSecretValue(unit) or unit ~= "player" then return end
	local cleanSpellID = SafeNumber(spellID, nil)
	if not cleanSpellID then return end
	if C_MountJournal and C_MountJournal.GetMountFromSpell then
		local mountOk, mountID = pcall(C_MountJournal.GetMountFromSpell, cleanSpellID)
		if mountOk and mountID and mountID ~= 0 then return end
	end
	lastPlayerSpellID = cleanSpellID
	lastPlayerSpellTime = GetTime()
	recordRecentCast(cleanSpellID)
end

local function hasRecentCast()
	return lastPlayerSpellID and lastPlayerSpellTime and (GetTime() - lastPlayerSpellTime) <= ATTRIBUTION_WINDOW
end

local function findActiveRecentAura(unitTarget, filter)
	local now = GetTime()
	for i = 1, #recentPlayerCasts do
		local entry = recentPlayerCasts[i]
		if (now - entry.time) <= PERIODIC_AURA_WINDOW then
			if AuraUtil and AuraUtil.FindAuraBySpellID then
				local ok, aura = pcall(AuraUtil.FindAuraBySpellID, entry.spellID, unitTarget, filter)
				if ok and aura then
					return entry.spellID
				end
			elseif ns.Compat.FindAura then
				local ok, name = pcall(ns.Compat.FindAura, unitTarget, entry.spellID, filter)
				if ok and name then
					return entry.spellID
				end
			end
		end
	end
	return nil
end

local function incomingHealSpell()
	if hasRecentCast() then
		return lastPlayerSpellID
	end
	return findActiveRecentAura("player", "HELPFUL|PLAYER")
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
	local dot = findActiveRecentAura("target", "HARMFUL|PLAYER")
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
	if IsSecretValue(unitTarget) or IsSecretValue(action) then return end

	local isCrit = (not IsSecretValue(flagText)) and (flagText == "CRITICAL") or false
	local cleanSchool = (not IsSecretValue(schoolMask) and type(schoolMask) == "number" and schoolMask > 0) and schoolMask or nil
	local missSuffix = MISS_ACTION_MAP[action]

	if unitTarget == "player" then
		local pGUID = SafeUnitGUID("player") or "player"
		local pName = SafeUnitName("player", UNKNOWN)
		if DAMAGE_ACTIONS[action] then
			fire("Incoming", "Melee damage", amount, nil, isCrit, pGUID, pName, nil, nil, nil, cleanSchool)
		elseif HEAL_ACTIONS[action] then
			local spellID = incomingHealSpell()
			if spellID and cleanSchool then
				spellSchoolCache[spellID] = cleanSchool
			end
			fire("Incoming", "Self heals", amount, spellID, isCrit, pGUID, pName, pGUID, pName, nil, cleanSchool)
		elseif missSuffix then
			fireMiss("Incoming", "Melee " .. missSuffix, action, amount, nil, pGUID, pName, nil, nil)
		end
	elseif unitTarget == "target" then
		if UnitExists("target") and UnitCanAttack("player", "target") then
			local tGUID = SafeUnitGUID("target") or "target"
			local tName = SafeUnitName("target", UNKNOWNOBJECT)
			local pGUID = SafeUnitGUID("player") or "player"
			local pName = SafeUnitName("player", UNKNOWN)
			if DAMAGE_ACTIONS[action] then
				local spellID = outgoingDamageSpell()
				if spellID and cleanSchool then
					spellSchoolCache[spellID] = cleanSchool
				end
				fire("Outgoing", "Melee damage", amount, spellID, isCrit, tGUID, tName, pGUID, pName, nil, cleanSchool)
			elseif missSuffix then
				local spellID = hasRecentCast() and lastPlayerSpellID or nil
				if spellID then
					fireMiss("Outgoing", "Skill " .. missSuffix, action, amount, spellID, tGUID, tName, pGUID, pName)
				else
					fireMiss("Outgoing", "Melee " .. missSuffix, action, amount, nil, tGUID, tName, pGUID, pName)
				end
			end
		end
	elseif unitTarget == "pet" then
		local petGUID = SafeUnitGUID("pet") or "pet"
		local petName = SafeUnitName("pet", _G.PET or "Pet")
		if DAMAGE_ACTIONS[action] then
			fire("Incoming", "Pet melee damage", amount, nil, isCrit, petGUID, petName, nil, nil, nil, cleanSchool)
		elseif HEAL_ACTIONS[action] then
			fire("Incoming", "Pet heals", amount, nil, isCrit, petGUID, petName, nil, nil, nil, cleanSchool)
		elseif missSuffix then
			fireMiss("Incoming", "Pet melee " .. missSuffix, action, amount, nil, petGUID, petName, nil, nil)
		end
	end
end

-- Taint-safe UNIT_AURA diffing for Retail Midnight when COMBAT_LOG_EVENT_UNFILTERED is blocked
local playerAuraState = {}
local playerAuraInitialized = false

local function scanPlayerAuras(emitDiffs)
	if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then return end
	local seen = {}
	local pGUID = SafeUnitGUID("player") or "player"
	local pName = SafeUnitName("player", UNKNOWN)

	for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
		local auraType = (filter == "HELPFUL") and "BUFF" or "DEBUFF"
		for idx = 1, 40 do
			local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", idx, filter)
			if not ok or not aura then break end

			local instID = SafeNumber(aura.auraInstanceID, nil)
			local spellID = SafeNumber(aura.spellId, nil)
			local name = SafeString(aura.name, nil)
			local apps = SafeNumber(aura.applications, 0) or 0

			local key = instID or (spellID and (auraType .. ":" .. spellID)) or (name and (auraType .. ":" .. name))
			if key and name and name ~= "" then
				seen[key] = true
				local prev = playerAuraState[key]
				if not prev then
					playerAuraState[key] = {
						spellID = spellID,
						name = name,
						apps = apps,
						auraType = auraType,
					}
					if emitDiffs then
						if apps > 1 then
							fireAura(auraType == "BUFF" and "Buff stack gains" or "Debuff stack gains", spellID, name, apps, auraType, pGUID, pName)
						else
							fireAura(auraType == "BUFF" and "Buff gains" or "Debuff gains", spellID, name, 1, auraType, pGUID, pName)
						end
					end
				elseif apps > (prev.apps or 0) and apps > 1 then
					prev.apps = apps
					if emitDiffs then
						fireAura(auraType == "BUFF" and "Buff stack gains" or "Debuff stack gains", spellID, name, apps, auraType, pGUID, pName)
					end
				else
					prev.apps = apps
				end
			end
		end
	end

	for key, prev in pairs(playerAuraState) do
		if not seen[key] then
			playerAuraState[key] = nil
			if emitDiffs and prev and prev.name then
				fireAura(prev.auraType == "BUFF" and "Buff fades" or "Debuff fades", prev.spellID, prev.name, 0, prev.auraType, pGUID, pName)
			end
		end
	end
end

function module:OnUnitAura(uid, event, unitTarget)
	if not Parrot.combatLogBlocked then return end
	if IsSecretValue(unitTarget) or unitTarget ~= "player" then return end
	if not playerAuraInitialized then
		playerAuraInitialized = true
		scanPlayerAuras(false)
		return
	end
	scanPlayerAuras(true)
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
		local schoolMask = safeAddZero(entry.spellSchool) or (spellID and spellSchoolCache[spellID]) or nil
		if spellID and schoolMask then
			spellSchoolCache[spellID] = schoolMask
		end
		if spellID and totalAmount and totalAmount > 0 then
			local key = meterType .. ":" .. spellID
			local previous = damageMeterLastTotals[key] or 0
			local delta = totalAmount - previous
			if delta < 0 then delta = totalAmount end
			damageMeterLastTotals[key] = totalAmount

			if delta > 0 then
				fire(category, name, delta, spellID, false, nil, nil, "player",
					SafeUnitName("player", UNKNOWN), ns.Compat.GetSpellName(spellID), schoolMask)
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
	Parrot:RegisterBlizzardEvent(self, "UNIT_AURA", "OnUnitAura")
	Parrot:RegisterBlizzardEvent(self, "UNIT_SPELLCAST_SUCCEEDED", "OnUnitSpellcastSucceeded")
	Parrot:RegisterBlizzardEvent(self, "PLAYER_REGEN_DISABLED", "StartDamageMeterPolling")
	Parrot:RegisterBlizzardEvent(self, "PLAYER_REGEN_ENABLED", "StopDamageMeterPolling")
end
