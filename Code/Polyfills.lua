local _, ns = ...

local Compat = {}
ns.Compat = Compat

-- ============================================================================
-- Specialization Stand-ins for Hybrid Clients (e.g. WoW: Forever)
-- Prevents LibDualSpec-1.0 from crashing when WOW_PROJECT_ID == MAINLINE
-- ============================================================================
if not _G.GetNumSpecializationsForClassID then
	function _G.GetNumSpecializationsForClassID()
		return 0
	end
end
if not _G.GetSpecializationInfoForClassID then
	function _G.GetSpecializationInfoForClassID()
		return nil
	end
end
if not _G.GetSpecialization then
	function _G.GetSpecialization()
		return 0
	end
end
if not _G.GetSpecializationInfo then
	function _G.GetSpecializationInfo()
		return nil
	end
end

-- ============================================================================
-- Secret Value & Taint Safety Helpers (Retail 11.0.7+ / 12.0+ Midnight & Forever)
-- ============================================================================
function Compat.IsSecretValue(value)
	local t = type(value)
	if t == "nil" then return false end
	if type(issecretvalue) == "function" then
		local ok, secret = pcall(issecretvalue, value)
		if ok and secret then return true end
	end
	if type(canaccessvalue) == "function" then
		local ok, accessible = pcall(canaccessvalue, value)
		if ok and not accessible then return true end
	end
	if t == "number" then
		local ok = pcall(function() return value > -1 and value == value end)
		if not ok then return true end
	elseif t == "string" then
		local ok = pcall(function() return value == "" end)
		if not ok then return true end
	elseif t == "boolean" then
		local ok = pcall(function() return value == true end)
		if not ok then return true end
	end
	return false
end

function Compat.SafeNumber(value)
	if type(value) ~= "number" then
		return nil
	end
	if Compat.IsSecretValue(value) then
		return nil
	end
	return value
end

function Compat.SafeString(value, fallback)
	if type(value) ~= "string" then
		return fallback
	end
	if Compat.IsSecretValue(value) then
		return fallback
	end
	return value
end

function Compat.SafeUnitName(unit, fallback)
	if not unit then return fallback end
	local ok, name = pcall(UnitName, unit)
	if not ok or type(name) ~= "string" then
		return fallback
	end
	return Compat.SafeString(name, fallback)
end

function Compat.SafeUnitGUID(unit)
	if not unit then return nil end
	local ok, guid = pcall(UnitGUID, unit)
	if not ok or type(guid) ~= "string" then
		return nil
	end
	return Compat.SafeString(guid, nil)
end

-- ============================================================================
-- Lua 5.1 / WoW Chunk Loader
-- ============================================================================
function Compat.LoadChunk(code, chunkName, env)
	local loader = loadstring or load
	if not loader then return nil, "No chunk loader available" end
	local func, err
	if setfenv then
		func, err = loader(code, chunkName)
		if func and env then
			setfenv(func, env)
		end
	else
		func, err = load(code, chunkName, "t", env)
	end
	return func, err
end

-- ============================================================================
-- Spell APIs (Retail C_Spell vs Classic GetSpellInfo / GetSpellCooldown)
-- ============================================================================
function Compat.GetSpellName(spellIDOrName)
	if not spellIDOrName then return nil end
	if C_Spell and C_Spell.GetSpellName then
		local ok, name = pcall(C_Spell.GetSpellName, spellIDOrName)
		if ok and name then return name end
	end
	if GetSpellInfo then
		local name = GetSpellInfo(spellIDOrName)
		return name
	end
	return nil
end

function Compat.GetSpellTexture(spellIDOrName)
	if not spellIDOrName then return nil end
	if C_Spell and C_Spell.GetSpellTexture then
		local ok, tex = pcall(C_Spell.GetSpellTexture, spellIDOrName)
		if ok and tex then return tex end
	end
	if GetSpellTexture then
		local ok, tex = pcall(GetSpellTexture, spellIDOrName)
		if ok and tex then return tex end
	end
	if GetSpellInfo then
		local _, _, tex = GetSpellInfo(spellIDOrName)
		return tex
	end
	return nil
end

function Compat.DoesSpellExist(spellID)
	local id = tonumber(spellID)
	if not id then return false end
	if C_Spell and C_Spell.DoesSpellExist then
		local ok, exists = pcall(C_Spell.DoesSpellExist, id)
		if ok and exists then
			return Compat.GetSpellName(id) ~= nil
		end
	end
	return Compat.GetSpellName(id) ~= nil
end

function Compat.GetSpellCooldown(spell)
	if not spell then return nil, nil, false end
	if C_Spell and C_Spell.GetSpellCooldown then
		local ok, info = pcall(C_Spell.GetSpellCooldown, spell)
		if ok and info then
			local start = Compat.SafeNumber(info.startTime)
			local duration = Compat.SafeNumber(info.duration)
			if start and duration then
				return start, duration, info.isEnabled
			end
			return nil, nil, false
		end
	end
	if GetSpellCooldown then
		local ok, start, duration, enabled = pcall(GetSpellCooldown, spell)
		if ok then
			start = Compat.SafeNumber(start)
			duration = Compat.SafeNumber(duration)
			if start and duration then
				return start, duration, enabled
			end
			return nil, nil, false
		end
	end
	return nil, nil, false
end

function Compat.IsSpellUsable(spell)
	if not spell then return false end
	if C_Spell and C_Spell.IsSpellUsable then
		local ok, usable, noMana = pcall(C_Spell.IsSpellUsable, spell)
		if ok then return usable, noMana end
	end
	if IsUsableSpell then
		local ok, usable, noMana = pcall(IsUsableSpell, spell)
		if ok then return usable, noMana end
	end
	return false
end

function Compat.IsSpellBookItemPassive(index)
	if C_SpellBook and C_SpellBook.IsSpellBookItemPassive then
		local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
		local ok, passive = pcall(C_SpellBook.IsSpellBookItemPassive, index, bank)
		if ok then return not not passive end
	elseif IsPassiveSpell then
		local ok, passive = pcall(IsPassiveSpell, index, BOOKTYPE_SPELL or "spell")
		if ok then return not not passive end
	end
	return false
end

-- ============================================================================
-- SpellBook APIs (Retail C_SpellBook vs Classic GetSpellTabInfo)
-- ============================================================================
function Compat.GetNumSpellBookSkillLines()
	if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
		return C_SpellBook.GetNumSpellBookSkillLines() or 0
	elseif GetNumSpellTabs then
		return GetNumSpellTabs() or 0
	end
	return 0
end

function Compat.GetSpellBookSkillLineInfo(tab)
	if C_SpellBook and C_SpellBook.GetSpellBookSkillLineInfo then
		return C_SpellBook.GetSpellBookSkillLineInfo(tab)
	elseif GetSpellTabInfo then
		local name, texture, offset, numSlots = GetSpellTabInfo(tab)
		if name then
			return {
				name = name,
				iconID = texture,
				itemIndexOffset = offset or 0,
				numSpellBookItems = numSlots or 0,
			}
		end
	end
	return nil
end

function Compat.GetSpellBookItemName(index)
	if C_SpellBook and C_SpellBook.GetSpellBookItemName then
		local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
		return C_SpellBook.GetSpellBookItemName(index, bank)
	elseif GetSpellBookItemName then
		return GetSpellBookItemName(index, BOOKTYPE_SPELL or "spell")
	elseif GetSpellName then
		return GetSpellName(index, BOOKTYPE_SPELL or "spell")
	end
	return nil, nil
end

function Compat.GetSpellBookItemCooldown(index)
	if C_SpellBook and C_SpellBook.GetSpellBookItemCooldown then
		local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
		local ok, info = pcall(C_SpellBook.GetSpellBookItemCooldown, index, bank)
		if ok and info then
			local start = Compat.SafeNumber(info.startTime)
			local duration = Compat.SafeNumber(info.duration)
			if start and duration then
				return start, duration
			end
			return nil, nil
		end
	elseif GetSpellBookItemCooldown then
		local ok, start, duration = pcall(GetSpellBookItemCooldown, index, BOOKTYPE_SPELL or "spell")
		if ok then
			return Compat.SafeNumber(start), Compat.SafeNumber(duration)
		end
	elseif GetSpellCooldown then
		local ok, start, duration = pcall(GetSpellCooldown, index, BOOKTYPE_SPELL or "spell")
		if ok then
			return Compat.SafeNumber(start), Compat.SafeNumber(duration)
		end
	end
	return nil, nil
end

-- ============================================================================
-- Item & Currency APIs
-- ============================================================================
function Compat.GetItemInfo(item)
	if not item then return nil end
	if C_Item and C_Item.GetItemInfo then
		return C_Item.GetItemInfo(item)
	elseif GetItemInfo then
		return GetItemInfo(item)
	end
	return nil
end

function Compat.GetItemIconByID(item)
	if not item then return nil end
	if C_Item and C_Item.GetItemIconByID then
		local ok, icon = pcall(C_Item.GetItemIconByID, item)
		if ok and icon then return icon end
	end
	if GetItemIcon then
		local ok, icon = pcall(GetItemIcon, item)
		if ok and icon then return icon end
	end
	if GetItemInfoInstant then
		local _, _, _, _, icon = GetItemInfoInstant(item)
		return icon
	end
	return nil
end

function Compat.GetItemCount(item)
	if not item then return 0 end
	if C_Item and C_Item.GetItemCount then
		return C_Item.GetItemCount(item) or 0
	elseif GetItemCount then
		return GetItemCount(item) or 0
	end
	return 0
end

function Compat.GetInventoryItemLink(unit, slot)
	if C_Item and C_Item.GetInventoryItemLink then
		return C_Item.GetInventoryItemLink(unit, slot)
	elseif GetInventoryItemLink then
		return GetInventoryItemLink(unit, slot)
	end
	return nil
end

function Compat.GetInventoryItemCooldown(unit, slot)
	if C_Item and C_Item.GetInventoryItemCooldown then
		local ok, start, duration, enable = pcall(C_Item.GetInventoryItemCooldown, unit, slot)
		if ok then
			return Compat.SafeNumber(start), Compat.SafeNumber(duration), enable
		end
	elseif GetInventoryItemCooldown then
		local ok, start, duration, enable = pcall(GetInventoryItemCooldown, unit, slot)
		if ok then
			return Compat.SafeNumber(start), Compat.SafeNumber(duration), enable
		end
	end
	return nil, nil, 0
end

function Compat.GetCurrencyInfoFromLink(link)
	if not link then return nil end
	if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfoFromLink then
		local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfoFromLink, link)
		if ok and info then return info end
	end
	return nil
end

-- ============================================================================
-- Aura APIs (Retail C_UnitAuras vs Classic UnitAura)
-- ============================================================================
function Compat.FindAura(unit, aura, filter)
	if not unit or not aura then return nil end
	filter = filter or "HELPFUL"

	if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
		for i = 1, 40 do
			local auraData = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
			if not auraData then break end
			local match = false
			if type(aura) == "number" then
				match = (auraData.spellId == aura)
			else
				match = (auraData.name == aura)
			end
			if match then
				return auraData.name, auraData.icon, auraData.applications,
					auraData.dispelName, auraData.duration, auraData.expirationTime,
					auraData.sourceUnit
			end
		end
		return nil
	end

	if UnitAura then
		for i = 1, 40 do
			local name, icon, count, dispelType, duration, expirationTime, sourceUnit, _, _, spellId = UnitAura(unit, i, filter)
			if not name then break end
			local match = false
			if type(aura) == "number" then
				match = (spellId == aura)
			else
				match = (name == aura)
			end
			if match then
				return name, icon, count, dispelType, duration, expirationTime, sourceUnit
			end
		end
	end
	return nil
end

-- ============================================================================
-- Specialization & Talent Tree Compatibility (Retail + MoP + Cata + Wrath + TBC + Classic)
-- ============================================================================
local fallbackSpecNames = {
	[250] = "Blood", [251] = "Frost", [252] = "Unholy",
	[577] = "Havoc", [581] = "Vengeance",
	[102] = "Balance", [103] = "Feral", [104] = "Guardian", [105] = "Restoration",
	[253] = "Beast Mastery", [254] = "Marksmanship", [255] = "Survival",
	[62]  = "Arcane", [63] = "Fire", [64] = "Frost",
	[268] = "Brewmaster", [269] = "Windwalker", [270] = "Mistweaver",
	[65]  = "Holy", [66] = "Protection", [70] = "Retribution",
	[256] = "Discipline", [257] = "Holy", [258] = "Shadow",
	[259] = "Assassination", [260] = "Combat / Outlaw", [261] = "Subtlety",
	[262] = "Elemental", [263] = "Enhancement", [264] = "Restoration",
	[265] = "Affliction", [266] = "Demonology", [267] = "Destruction",
	[71]  = "Arms", [72] = "Fury", [73] = "Protection",
	[1467] = "Devastation", [1468] = "Preservation", [1473] = "Augmentation",
}

function Compat.GetCurrentSpecID(playerClass, specChoices)
	-- 1. Retail / Modern PlayerUtil
	if PlayerUtil and PlayerUtil.GetCurrentSpecID then
		local specId = PlayerUtil.GetCurrentSpecID()
		if specId and specId > 0 then
			return tostring(specId)
		end
	end

	-- 2. MoP / Retail GetSpecialization + GetSpecializationInfo
	if GetSpecialization and GetSpecializationInfo then
		local specIndex = GetSpecialization()
		if specIndex and specIndex > 0 then
			local specId = GetSpecializationInfo(specIndex)
			if specId and specId > 0 then
				return tostring(specId)
			end
		end
	end

	-- 3. Classic Era / TBC / Wrath / Cata: map primary talent tab (1..3) to class specChoices
	local classSpecs = specChoices and playerClass and specChoices[playerClass]
	if classSpecs then
		local activeTab = 1
		if GetPrimaryTalentTree then
			activeTab = GetPrimaryTalentTree() or 1
		elseif GetNumTalentTabs and GetTalentTabInfo then
			local maxPts = -1
			for i = 1, GetNumTalentTabs() do
				local a, b, c, d, e = GetTalentTabInfo(i)
				-- Classic/TBC: name, iconTexture, pointsSpent
				-- Wrath/Cata: id, name, description, iconTexture, pointsSpent
				local pts = (type(c) == "number" and c) or (type(e) == "number" and e) or 0
				if pts > maxPts then
					maxPts = pts
					activeTab = i
				end
			end
		end
		-- For Druid in Classic/TBC/Wrath/Cata (3 tabs: Balance=1, Feral=2, Resto=3),
		-- specChoices has 4 entries (102 Balance, 103 Feral, 104 Guardian, 105 Resto).
		if playerClass == "DRUID" and #classSpecs == 4 and (not GetNumSpecializations or GetNumSpecializations() == 3) then
			if activeTab == 1 then return "102"
			elseif activeTab == 2 then return "103"
			elseif activeTab == 3 then return "105"
			end
		end
		local mapped = classSpecs[activeTab] or classSpecs[1]
		if mapped then
			return tostring(mapped)
		end
	end

	return "0"
end

function Compat.GetSpecInfoByID(class, tabIndex, specID)
	if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfoByID then
		local info = C_SpecializationInfo.GetSpecializationInfoByID(specID)
		if info and info.name and info.name ~= "" then
			return info.name, info.description or ""
		end
	end
	if GetSpecializationInfoByID then
		local _, name, desc = GetSpecializationInfoByID(specID)
		if name and name ~= "" then
			return name, desc or ""
		end
	end
	local _, playerClass = UnitClass("player")
	if class == playerClass and GetTalentTabInfo then
		local tIdx = tabIndex
		if class == "DRUID" then
			if specID == 102 then tIdx = 1
			elseif specID == 103 or specID == 104 then tIdx = 2
			elseif specID == 105 then tIdx = 3
			end
		end
		local a, b, c = GetTalentTabInfo(tIdx)
		if type(a) == "string" and a ~= "" then
			return a, ""
		elseif type(b) == "string" and b ~= "" then
			return b, (type(c) == "string" and c) or ""
		end
	end
	local fallback = fallbackSpecNames[specID] or ("Spec " .. tostring(specID))
	return fallback, fallback
end

-- ============================================================================
-- Built-in LibDDI-1.0 Fallback Widgets (DDI-Font & DDI-Sound for AceGUI-3.0)
-- ============================================================================
do
	local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
	local IBLib = LibStub and LibStub("AceGUI-3.0-DropDown-ItemBase", true)
	local SharedMedia = LibStub and LibStub("LibSharedMedia-3.0", true)
	if AceGUI and IBLib and IBLib.GetItemBase then
		local ItemBase = IBLib.GetItemBase()

		if not AceGUI:GetWidgetVersion("DDI-Font") then
			local widgetType = "DDI-Font"
			local widgetVersion = 1

			local function UpdateToggle(self)
				if self.value then
					self.check:Show()
				else
					self.check:Hide()
				end
			end

			local function OnRelease(self)
				ItemBase.OnRelease(self)
				self:SetValue(nil)
			end

			local function Frame_OnClick(this)
				local self = this.obj
				if self.disabled then return end
				self.value = not self.value
				UpdateToggle(self)
				self:Fire("OnValueChanged", self.value)
			end

			local function SetValue(self, value)
				self.value = value
				UpdateToggle(self)
			end

			local function GetValue(self)
				return self.value
			end

			local function SetText(self, text)
				ItemBase.SetText(self, text)
				local defaultFont, size, flags = GameFontNormalSmall:GetFont()
				local fontFile = (SharedMedia and text and SharedMedia:Fetch("font", text, true)) or defaultFont
				if fontFile then
					pcall(self.text.SetFont, self.text, fontFile, size or 12, flags or "")
				end
			end

			local function Constructor()
				local self = ItemBase.Create(widgetType)
				self.frame:SetScript("OnClick", Frame_OnClick)
				self.SetValue = SetValue
				self.GetValue = GetValue
				self.SetText = SetText
				self.OnRelease = OnRelease
				AceGUI:RegisterAsWidget(self)
				return self
			end

			AceGUI:RegisterWidgetType(widgetType, Constructor, widgetVersion + ItemBase.version)
		end

		if not AceGUI:GetWidgetVersion("DDI-Sound") then
			local widgetType = "DDI-Sound"
			local widgetVersion = 1

			local function UpdateToggle(self)
				if self.value then
					self.check:Show()
				else
					self.check:Hide()
				end
			end

			local function OnRelease(self)
				ItemBase.OnRelease(self)
				self:SetValue(nil)
			end

			local function Frame_OnClick(this)
				local self = this.obj
				if self.disabled then return end
				self.value = not self.value
				if SharedMedia then
					local soundName = self:GetText()
					local soundFile = soundName and SharedMedia:Fetch("sound", soundName, true)
					if soundFile and PlaySoundFile then
						pcall(PlaySoundFile, soundFile, "Master")
					end
				end
				UpdateToggle(self)
				self:Fire("OnValueChanged", self.value)
			end

			local function SetValue(self, value)
				self.value = value
				UpdateToggle(self)
			end

			local function GetValue(self)
				return self.value
			end

			local function Constructor()
				local self = ItemBase.Create(widgetType)
				self.frame:SetScript("OnClick", Frame_OnClick)
				self.SetValue = SetValue
				self.GetValue = GetValue
				self.OnRelease = OnRelease
				AceGUI:RegisterAsWidget(self)
				return self
			end

			AceGUI:RegisterWidgetType(widgetType, Constructor, widgetVersion + ItemBase.version)
		end
	end
end

