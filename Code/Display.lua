local _, ns = ...
local Parrot = ns.addon
local module = Parrot:NewModule("Display")
local L = LibStub("AceLocale-3.0"):GetLocale("Parrot")

local Parrot_AnimationStyles
local Parrot_Suppressions
local Parrot_ScrollAreas

local LibSharedMedia = LibStub("LibSharedMedia-3.0")
local LibCustomGlow = LibStub("LibCustomGlow-1.0", true)
local DEFAULT_FONT_NAME = LibSharedMedia:GetDefault("font")

local Easing = ns.Easing
local DisablePixelSnap = Easing and Easing.DisablePixelSnap or function() end
local SafeNumber = ns.Compat.SafeNumber
local SafeUnitGUID = ns.Compat.SafeUnitGUID
local issecretvalue = _G.issecretvalue

local newList, del = Parrot.newList, Parrot.del
local math_max, math_min, math_sqrt = math.max, math.min, math.sqrt

local WHITE8X8 = [[Interface\BUTTONS\WHITE8X8]]

local ParrotFrame = CreateFrame("Frame", "ParrotFrame", UIParent)
ParrotFrame:Hide()
ParrotFrame:SetFrameStrata("HIGH")
ParrotFrame:SetPoint("CENTER")
ParrotFrame:SetWidth(0.0001)
ParrotFrame:SetHeight(0.0001)
local Display_Update

local db
local defaults = {
	profile = {
		alpha = 1,
		iconAlpha = 1,
		iconsEnabled = true,
		iconBorder = true,
		iconColorBorder = true,
		critGlow = true,
		critGlowStyle = "PIXEL",
		smoothEasing = true,
		critScale = 1.35,
		dynamicScale = true,
		dotScale = 0.88,
		strata = "HIGH",
		useElvUIFont = false,
		font = DEFAULT_FONT_NAME,
		fontSize = 18,
		fontOutline = "THICKOUTLINE",
		fontShadow = true,
		stickyFont = DEFAULT_FONT_NAME,
		stickyFontSize = 26,
		stickyFontOutline = "THICKOUTLINE",
		stickyFontShadow = true,
	},
}

-- ============================================================================
-- Taint-Free Nameplate Screen Coordinate Resolver
-- Never parents frames to NamePlates; only reads screen coordinates safely.
-- ============================================================================
local guidToPlateUnit = {}
local plateUnitToGuid = {}

local function clearNameplateCache()
	wipe(guidToPlateUnit)
	wipe(plateUnitToGuid)
end

function module:NAME_PLATE_UNIT_ADDED(_, unit)
	if type(unit) ~= "string" or ns.Compat.IsSecretValue(unit) then
		return
	end
	local guid = SafeUnitGUID(unit)
	if guid then
		guidToPlateUnit[guid] = unit
		plateUnitToGuid[unit] = guid
	end
end

function module:NAME_PLATE_UNIT_REMOVED(_, unit)
	if type(unit) ~= "string" or ns.Compat.IsSecretValue(unit) then
		return
	end
	local guid = plateUnitToGuid[unit]
	if guid and guidToPlateUnit[guid] == unit then
		guidToPlateUnit[guid] = nil
	end
	plateUnitToGuid[unit] = nil
end

local function isRegionUsable(region)
	if not region then
		return false
	end
	if region.IsForbidden then
		local okForb, forbidden = pcall(region.IsForbidden, region)
		if not okForb or forbidden then
			return false
		end
	end
	if region.IsShown then
		local okShown, shown = pcall(region.IsShown, region)
		if not okShown or not shown then
			return false
		end
	end
	return true
end

local function resolveVisualPlateRegion(plate)
	-- Prefer ElvUI NamePlates oUF visible healthbar (plate.unitFrame.Health),
	-- then ElvUI/Plater unitFrame, then Blizzard UnitFrame.healthBar, then raw plate.
	local okUF, uf = pcall(function() return plate.unitFrame end)
	if okUF and isRegionUsable(uf) then
		local okHealth, health = pcall(function() return uf.Health end)
		if okHealth and isRegionUsable(health) then
			return health
		end
		return uf
	end
	local okBlizzUF, blizzUF = pcall(function() return plate.UnitFrame end)
	if okBlizzUF and isRegionUsable(blizzUF) then
		local okHB, hb = pcall(function() return blizzUF.healthBar end)
		if okHB and isRegionUsable(hb) then
			return hb
		end
		return blizzUF
	end
	return plate
end

local function getUnitPlateCenterOffset(unit, extraX, extraY)
	if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit and unit) then
		return nil, nil
	end
	local okPlate, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
	if not okPlate or not isRegionUsable(plate) then
		return nil, nil
	end
	local visualRegion = resolveVisualPlateRegion(plate)
	local okCenter, px, py = pcall(visualRegion.GetCenter, visualRegion)
	if not okCenter then
		visualRegion = plate
		okCenter, px, py = pcall(plate.GetCenter, plate)
		if not okCenter then
			return nil, nil
		end
	end
	px = SafeNumber(px)
	py = SafeNumber(py)
	if not (px and py) then
		return nil, nil
	end

	local okPS, plateScale = pcall(visualRegion.GetEffectiveScale, visualRegion)
	plateScale = (okPS and SafeNumber(plateScale)) or 1
	local uiScale = SafeNumber(UIParent:GetEffectiveScale()) or 1
	local ratio = (uiScale > 0) and (plateScale / uiScale) or 1

	local uiW = SafeNumber(UIParent:GetWidth()) or GetScreenWidth()
	local uiH = SafeNumber(UIParent:GetHeight()) or GetScreenHeight()

	local offsetX = (px * ratio) - (uiW * 0.5) + (extraX or 0)
	local offsetY = (py * ratio) - (uiH * 0.5) + (extraY or 20)
	return offsetX, offsetY
end

local function resolveNameplateOffset(anchorMode, unitGUID, extraX, extraY)
	if not anchorMode or anchorMode == "SCREEN" then
		return nil, nil
	end
	if anchorMode == "TARGET" then
		return getUnitPlateCenterOffset("target", extraX, extraY)
	end

	-- anchorMode == "NAMEPLATE"
	local safeGUID = (type(unitGUID) == "string" and not ns.Compat.IsSecretValue(unitGUID) and unitGUID ~= "") and unitGUID or nil
	if safeGUID then
		local cachedUnit = guidToPlateUnit[safeGUID]
		if cachedUnit then
			local ox, oy = getUnitPlateCenterOffset(cachedUnit, extraX, extraY)
			if ox and oy then
				return ox, oy
			end
		end
		if SafeUnitGUID("target") == safeGUID then
			local ox, oy = getUnitPlateCenterOffset("target", extraX, extraY)
			if ox and oy then
				return ox, oy
			end
		end
		if SafeUnitGUID("mouseover") == safeGUID then
			local ox, oy = getUnitPlateCenterOffset("mouseover", extraX, extraY)
			if ox and oy then
				return ox, oy
			end
		end
		if SafeUnitGUID("focus") == safeGUID then
			local ox, oy = getUnitPlateCenterOffset("focus", extraX, extraY)
			if ox and oy then
				return ox, oy
			end
		end
		return nil, nil
	end

	-- Fallback when GUID is unavailable/secret (e.g. Midnight fallback feed): use current hostile target nameplate
	return getUnitPlateCenterOffset("target", extraX, extraY)
end

-- ============================================================================
-- LibCustomGlow-1.0 Helpers
-- ============================================================================
local hasProcGlowAtlas = nil
local function supportsProcGlow()
	if hasProcGlowAtlas == nil then
		hasProcGlowAtlas = (C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("UI-HUD-ActionBar-Proc-Loop-Flipbook")) ~= nil
	end
	return hasProcGlowAtlas
end

local glowColorScratch = { 1, 0.82, 0.15, 0.95 }

local function guardGlowOnUpdate(holder, fieldName)
	if not issecretvalue or not holder then
		return
	end
	local glowFrame = holder[fieldName]
	if not glowFrame or not glowFrame.GetScript then
		return
	end
	local origOnUpdate = glowFrame:GetScript("OnUpdate")
	if not origOnUpdate or origOnUpdate == glowFrame._parrotWrappedOnUpdate then
		return
	end
	local wrapped = function(self, elapsed)
		local w, h = self:GetSize()
		if issecretvalue(w) or issecretvalue(h) then
			return
		end
		return origOnUpdate(self, elapsed)
	end
	glowFrame._parrotWrappedOnUpdate = wrapped
	glowFrame:SetScript("OnUpdate", wrapped)
end

local function stopIconGlow(holder)
	if not holder or not holder._activeGlowStyle then
		return
	end
	local glow = LibCustomGlow or LibStub("LibCustomGlow-1.0", true)
	local style = holder._activeGlowStyle
	holder._activeGlowStyle = nil
	if not glow then
		return
	end
	if style == "PIXEL" and glow.PixelGlow_Stop then
		pcall(glow.PixelGlow_Stop, holder, "ParrotGlow")
	elseif style == "AUTOCAST" and glow.AutoCastGlow_Stop then
		pcall(glow.AutoCastGlow_Stop, holder, "ParrotGlow")
	elseif style == "BUTTON" and glow.ButtonGlow_Stop then
		pcall(glow.ButtonGlow_Stop, holder)
	elseif style == "PROC" and glow.ProcGlow_Stop then
		pcall(glow.ProcGlow_Stop, holder, "ParrotGlow")
	end
end

local function startIconGlow(holder, r, g, b)
	local glow = LibCustomGlow or LibStub("LibCustomGlow-1.0", true)
	if not glow or not holder or not db.critGlow then
		return
	end
	if issecretvalue then
		local hw, hh = holder:GetSize()
		if issecretvalue(hw) or issecretvalue(hh) then
			return
		end
	end
	stopIconGlow(holder)

	local style = db.critGlowStyle or "PIXEL"
	if style == "NONE" then
		return
	end
	if style == "PROC" and (not glow.ProcGlow_Start or not supportsProcGlow()) then
		style = "PIXEL"
	end

	glowColorScratch[1] = r or 1
	glowColorScratch[2] = g or 0.82
	glowColorScratch[3] = b or 0.15
	glowColorScratch[4] = 0.95

	if style == "AUTOCAST" and glow.AutoCastGlow_Start then
		local ok = pcall(glow.AutoCastGlow_Start, holder, glowColorScratch, 8, 0.25, 1.0, 1, 1, "ParrotGlow")
		if ok then
			holder._activeGlowStyle = "AUTOCAST"
			guardGlowOnUpdate(holder, "_AutoCastGlowParrotGlow")
		end
	elseif style == "BUTTON" and glow.ButtonGlow_Start then
		local ok = pcall(glow.ButtonGlow_Start, holder, glowColorScratch, 0.15)
		if ok then
			holder._activeGlowStyle = "BUTTON"
		end
	elseif style == "PROC" and glow.ProcGlow_Start then
		local ok = pcall(glow.ProcGlow_Start, holder, {
			color = { glowColorScratch[1], glowColorScratch[2], glowColorScratch[3], glowColorScratch[4] },
			startAnim = false,
			key = "ParrotGlow",
		})
		if ok then
			holder._activeGlowStyle = "PROC"
		end
	elseif glow.PixelGlow_Start then
		local ok = pcall(glow.PixelGlow_Start, holder, glowColorScratch, 6, 0.28, nil, 1.5, 1, 1, false, "ParrotGlow")
		if ok then
			holder._activeGlowStyle = "PIXEL"
			guardGlowOnUpdate(holder, "_PixelGlowParrotGlow")
		end
	end
end

-- ============================================================================
-- Dynamic Hit-Size Rolling Average
-- ============================================================================
local rollingAvgAmount = nil

local function computeDynamicScale(meta, sticky)
	if not db.dynamicScale or not meta then
		if meta and meta.isPeriodic and db.dotScale and db.dotScale ~= 1 then
			return db.dotScale
		end
		return 1
	end

	local amt = SafeNumber(meta.amount)
	if not amt or amt <= 0 then
		if meta.isPeriodic then
			return db.dotScale or 0.88
		end
		return 1
	end

	if not meta.isPeriodic then
		if not rollingAvgAmount or rollingAvgAmount <= 0 then
			rollingAvgAmount = amt
		else
			rollingAvgAmount = rollingAvgAmount * 0.88 + amt * 0.12
		end
	elseif not rollingAvgAmount then
		rollingAvgAmount = amt * 2
	end

	local baseAvg = (rollingAvgAmount and rollingAvgAmount > 0) and rollingAvgAmount or amt
	local ratio = amt / baseAvg
	if meta.isPeriodic then
		local baseDot = db.dotScale or 0.88
		return Easing.Clamp(baseDot * (0.90 + 0.10 * math_sqrt(ratio)), 0.75, 1.08)
	end

	local scale = 0.88 + 0.12 * math_sqrt(ratio)
	if sticky or meta.isCrit then
		return Easing.Clamp(scale, 0.95, 1.28)
	end
	return Easing.Clamp(scale, 0.85, 1.22)
end

-- ============================================================================
-- Lifecycle & Options
-- ============================================================================
function module:OnProfileChanged()
	db = self.db.profile
	ParrotFrame:SetFrameStrata(db.strata)
end

function module:OnInitialize()
	self.db = Parrot.db:RegisterNamespace("Display", defaults)
	self:OnProfileChanged()

	Parrot_AnimationStyles = Parrot:GetModule("AnimationStyles")
	Parrot_Suppressions = Parrot:GetModule("Suppressions")
	Parrot_ScrollAreas = Parrot:GetModule("ScrollAreas")
end

function module:OnEnable()
	pcall(self.RegisterEvent, self, "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_ADDED")
	pcall(self.RegisterEvent, self, "NAME_PLATE_UNIT_REMOVED", "NAME_PLATE_UNIT_REMOVED")
	pcall(self.RegisterEvent, self, "PLAYER_ENTERING_WORLD", clearNameplateCache)
end

local function setOption(info, value)
	local name = info[#info]
	db[name] = value
end
local function getOption(info)
	local name = info[#info]
	return db[name]
end

local function getFontFace(info)
	local font = db[info[#info]]
	if font == nil then
		return -1
	end
	for i, v in next, Parrot.fontValues do
		if v == font then return i end
	end
	return font
end
local function setFontFace(info, value)
	if value == -1 then
		db[info[#info]] = nil
	else
		db[info[#info]] = Parrot.fontValues[value]
	end
end

function module:ApplyModernPreset()
	db.smoothEasing = true
	db.iconBorder = true
	db.iconColorBorder = true
	db.critGlow = true
	db.critGlowStyle = "PIXEL"
	db.critScale = 1.35
	db.dynamicScale = true
	db.dotScale = 0.88
	db.fontOutline = "THICKOUTLINE"
	db.stickyFontOutline = "THICKOUTLINE"

	if Parrot_ScrollAreas and Parrot_ScrollAreas.ApplyModernScrollPreset then
		Parrot_ScrollAreas:ApplyModernScrollPreset()
	end
	local ceMod = Parrot:GetModule("CombatEvents", true)
	if ceMod and ceMod.ApplyModernEventPreset then
		ceMod:ApplyModernEventPreset()
	end
end

function module:OnOptionsCreate()
	local outlineChoices = {
		NONE = L["None"],
		MONOCHROME = L["Monochrome"],
		OUTLINE = L["Thin"],
		["OUTLINE,MONOCHROME"] = L["Thin, Monochrome"],
		THICKOUTLINE = L["Thick"],
	}

	local glowStyleChoices = {
		NONE = L["None"],
		PIXEL = L["Pixel glow"],
		AUTOCAST = L["Sparkle glow"],
		BUTTON = L["Spell alert glow"],
		PROC = L["Proc glow"],
	}

	local generalArgs = Parrot.options.args.general.args
	local interfaceArgs = (generalArgs.interfaceGroup and generalArgs.interfaceGroup.args) or generalArgs

	interfaceArgs.iconsEnabled = {
		type = "toggle",
		name = L["Enable icons"],
		desc = L["Set whether icons should be enabled or disabled altogether."],
		width = 1.7,
		order = 2,
		get = getOption,
		set = setOption,
	}
	interfaceArgs.alpha = {
		type = "range",
		name = L["Text transparency"],
		desc = L["How opaque/transparent the text should be."],
		min = 0.25,
		max = 1,
		step = 0.01,
		bigStep = 0.05,
		isPercent = true,
		width = 1.7,
		order = 3,
		get = getOption,
		set = setOption,
	}
	interfaceArgs.iconAlpha = {
		type = "range",
		name = L["Icon transparency"],
		desc = L["How opaque/transparent icons should be."],
		min = 0.25,
		max = 1,
		step = 0.01,
		bigStep = 0.05,
		isPercent = true,
		width = 1.7,
		order = 4,
		get = getOption,
		set = setOption,
	}
	interfaceArgs.strata = {
		type = "select",
		name = L["Strata"],
		desc = L["Layering of the scrolling text relative to other frames."],
		values = {
			BACKGROUND = "BACKGROUND",
			LOW = "LOW",
			MEDIUM = "MEDIUM",
			HIGH = "HIGH",
			DIALOG = "DIALOG",
			TOOLTIP = "TOOLTIP",
		},
		sorting = {
			"BACKGROUND",
			"LOW",
			"MEDIUM",
			"HIGH",
			"DIALOG",
			"TOOLTIP",
		},
		width = 1.7,
		order = 5,
		get = getOption,
		set = function(info, value)
			setOption(info, value)
			ParrotFrame:SetFrameStrata(value)
		end,
	}
	Parrot.options.args.general.args.font = {
		type = "group",
		inline = true,
		name = L["Master font settings"],
		order = 10,
		get = getOption,
		set = setOption,
		args = {
			useElvUIFont = {
				type = "toggle",
				name = L["Use ElvUI font"],
				desc = L["Automatically use ElvUI's configured general/combat font for floating combat text."],
				width = "full",
				order = 0,
				hidden = function()
					return not _G.ElvUI
				end,
			},
			font = {
				type = "select",
				name = L["Normal font face"],
				values = Parrot.fontValues,
				get = getFontFace,
				set = setFontFace,
				itemControl = "DDI-Font",
				width = 1.7,
				order = 1,
			},
			fontSize = {
				type = "range",
				name = L["Normal font size"],
				min = 8,
				max = 48,
				step = 1,
				width = 1.7,
				order = 2,
			},
			fontOutline = {
				type = "select",
				name = L["Normal font outline"],
				values = outlineChoices,
				width = 1.7,
				order = 3,
			},
			fontShadow = {
				type = "toggle",
				name = L["Normal font shadow"],
				width = 1.7,
				order = 4,
			},
			stickySpacer = {
				type = "description",
				name = " ",
				width = "full",
				order = 5,
			},
			stickyFont = {
				type = "select",
				name = L["Sticky font face"],
				values = Parrot.fontValues,
				get = getFontFace,
				set = setFontFace,
				itemControl = "DDI-Font",
				width = 1.7,
				order = 6,
			},
			stickyFontSize = {
				type = "range",
				name = L["Sticky font size"],
				min = 8,
				max = 48,
				step = 1,
				width = 1.7,
				order = 7,
			},
			stickyFontOutline = {
				type = "select",
				name = L["Sticky font outline"],
				values = outlineChoices,
				width = 1.7,
				order = 8,
			},
			stickyFontShadow = {
				type = "toggle",
				name = L["Sticky font shadow"],
				width = 1.7,
				order = 9,
			},
		},
	}
	Parrot.options.args.general.args.visualEffects = {
		type = "group",
		inline = true,
		name = L["Visual effects & animations"],
		order = 20,
		get = getOption,
		set = setOption,
		args = {
			smoothEasing = {
				type = "toggle",
				name = L["Smooth sub-pixel animations"],
				desc = L["Enables sub-pixel rendering, smooth easing curves, soft fade-in/out, and damped anti-overlap movement."],
				width = 1.7,
				order = 1,
			},
			dynamicScale = {
				type = "toggle",
				name = L["Dynamic hit scaling"],
				desc = L["Automatically scales numbers based on hit magnitude so big hits stand out and small ticks stay compact."],
				width = 1.7,
				order = 2,
			},
			critScale = {
				type = "range",
				name = L["Crit pop scale"],
				desc = L["Peak zoom multiplier during the initial pop of critical strikes and sticky alerts."],
				min = 1.0,
				max = 2.0,
				step = 0.05,
				isPercent = true,
				width = 1.7,
				order = 3,
			},
			dotScale = {
				type = "range",
				name = L["DoT / HoT tick scale"],
				desc = L["Relative size multiplier for periodic damage and healing ticks."],
				min = 0.60,
				max = 1.10,
				step = 0.02,
				isPercent = true,
				width = 1.7,
				order = 4,
			},
			iconBorder = {
				type = "toggle",
				name = L["Styled icon borders"],
				desc = L["Draws a crisp dark border around spell and item icons."],
				disabled = function() return not db.iconsEnabled end,
				width = 1.7,
				order = 5,
			},
			iconColorBorder = {
				type = "toggle",
				name = L["Color icon border by damage school"],
				desc = L["Tints the icon border with the spell school or event color (golden accent on crits)."],
				disabled = function() return not db.iconsEnabled or not db.iconBorder end,
				width = 1.7,
				order = 6,
			},
			critGlow = {
				type = "toggle",
				name = L["Glow icons on crits & triggers"],
				desc = L["Highlights spell icons with an animated LibCustomGlow effect on critical hits and triggers."],
				disabled = function() return not db.iconsEnabled end,
				width = 1.85,
				order = 7,
			},
			critGlowStyle = {
				type = "select",
				name = L["Icon glow style"],
				desc = L["Visual glow style applied to icons on critical strikes and triggers."],
				values = glowStyleChoices,
				disabled = function() return not db.iconsEnabled or not db.critGlow end,
				width = 1.5,
				order = 8,
			},
			applyModernPreset = {
				type = "execute",
				name = L["Apply Modern Preset"],
				desc = L["Configures animations (Fountain & Impact), smooth sub-pixel rendering, icon borders/glows, and compact damage formatting."],
				confirm = true,
				confirmText = L["Apply modern animation styles (Fountain / Impact) and number formatting to this profile?"],
				func = function()
					module:ApplyModernPreset()
				end,
				width = "double",
				order = 9,
			},
		},
	}
end

-- ============================================================================
-- Frame, FontString & Styled Icon Pools
-- ============================================================================
local freeFrames = {}
local wildFrames = {}
local frame_num = 0
local frameIDs = {}
local freeIconHolders = {}
local texture_num = 0
local freeFontStrings = {}
local fontString_num = 0

local function acquireIconHolder(parent)
	local holder = next(freeIconHolders)
	if holder then
		freeIconHolders[holder] = nil
		holder:SetParent(parent)
		holder:ClearAllPoints()
		holder:Show()
		return holder
	end

	texture_num = texture_num + 1
	holder = CreateFrame("Frame", "ParrotFrameIconHolder" .. texture_num, parent)

	local outerBorder = holder:CreateTexture(nil, "BACKGROUND", nil, -2)
	outerBorder:SetTexture(WHITE8X8)
	outerBorder:SetVertexColor(0.04, 0.04, 0.06, 0.92)
	outerBorder:SetPoint("TOPLEFT", holder, "TOPLEFT", -1.5, 1.5)
	outerBorder:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 1.5, -1.5)
	DisablePixelSnap(outerBorder)
	holder.outerBorder = outerBorder

	local colorRim = holder:CreateTexture(nil, "BACKGROUND", nil, -1)
	colorRim:SetTexture(WHITE8X8)
	colorRim:SetPoint("TOPLEFT", holder, "TOPLEFT", -0.8, 0.8)
	colorRim:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0.8, -0.8)
	DisablePixelSnap(colorRim)
	holder.colorRim = colorRim

	local tex = holder:CreateTexture("ParrotFrameTexture" .. texture_num, "ARTWORK", nil, 0)
	tex:SetAllPoints(holder)
	DisablePixelSnap(tex)
	holder.tex = tex

	local gloss = holder:CreateTexture(nil, "OVERLAY", nil, 1)
	gloss:SetTexture(WHITE8X8)
	gloss:SetVertexColor(1, 1, 1, 0.07)
	gloss:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
	gloss:SetPoint("BOTTOMRIGHT", holder, "TOPRIGHT", 0, -4)
	DisablePixelSnap(gloss)
	holder.gloss = gloss

	return holder
end

local function releaseIconHolder(holder)
	if not holder then
		return
	end
	stopIconGlow(holder)
	holder:Hide()
	holder.tex:SetTexture(nil)
	holder:ClearAllPoints()
	holder:SetParent(ParrotFrame)
	freeIconHolders[holder] = true
end

local function releaseFrame(f, scrollArea, animationStyle)
	local cleanup = animationStyle and animationStyle.cleanup
	if cleanup then
		cleanup(f, scrollArea.xOffset, scrollArea.yOffset, scrollArea.size, scrollArea[f.sticky and "stickyDirection" or "direction"] or animationStyle.defaultDirection, f.id)
	end
	f:SetScale(1)
	if f.content then
		f.content:SetScale(1)
	end
	f.zoomScale = nil
	f.baseScale = nil
	f.useNameplate = nil
	f.targetGUID = nil
	f.plateX = nil
	f.plateY = nil
	f.plateJitterX = nil
	f:Hide()
	freeFrames[f] = true

	local fs = f.fs
	if fs then
		fs:Hide()
		fs:SetParent(ParrotFrame)
		freeFontStrings[fs] = true
		f.fs = nil
	end

	if f.iconHolder then
		releaseIconHolder(f.iconHolder)
		f.iconHolder = nil
	end
	f.icon = nil
end

--[[----------------------------------------------------------------------------------
Arguments:
	string - the text you wish to show.
	[optional] string - the scroll area to show in. Default: "Notification"
	[optional] boolean - whether to show in the sticky-style, e.g. crits. Default: false
	[optional] number - [0, 1] the red part of the color. Default: 1
	[optional] number - [0, 1] the green part of the color. Default: 1
	[optional] number - [0, 1] the blue part of the color. Default: 1
	[optional] string - the font to use (as determined by LibSharedMedia-3.0). Defaults to the scroll area's setting.
	[optional] number - the font size to use. Defaults to the scroll area's setting.
	[optional] string - the font outline to use. Defaults to the scroll area's setting.
	[optional] string|number - the icon texture to show alongside the message.
	[optional] table - optional metadata (amount, isCrit, isTrigger, isPeriodic, unitGUID, schoolR, schoolG, schoolB).
------------------------------------------------------------------------------------]]
function module:ShowMessage(text, area, sticky, r, g, b, font, fontSize, outline, icon, meta)
	if not module:IsEnabled() then return end
	if Parrot_Suppressions:ShouldSuppress(text) then return end

	if not Parrot_ScrollAreas:HasScrollArea(area) then
		if Parrot_ScrollAreas:HasScrollArea("Notification") then
			area = "Notification"
		else
			area = Parrot_ScrollAreas:GetRandomScrollArea()
			if not area then
				return
			end
		end
	end

	local scrollArea = Parrot_ScrollAreas:GetScrollArea(area)
	local shadow = nil
	if not sticky then
		if not font then
			font = scrollArea.font or db.font
		end
		if not fontSize then
			fontSize = scrollArea.fontSize or db.fontSize
		end
		if not outline then
			outline = scrollArea.fontOutline or db.fontOutline
		end
		shadow = scrollArea.fontShadow
		if shadow == nil then
			shadow = db.fontShadow
		end
	else
		if not font then
			font = scrollArea.stickyFont or db.stickyFont
		end
		if not fontSize then
			fontSize = scrollArea.stickyFontSize or db.stickyFontSize
		end
		if not outline then
			outline = scrollArea.stickyFontOutline or db.stickyFontOutline
		end
		shadow = scrollArea.stickyFontShadow
		if shadow == nil then
			shadow = db.stickyFontShadow
		end
	end
	if outline == "NONE" then
		outline = ""
	end

	local frame = next(freeFrames)
	if frame then
		frame:ClearAllPoints()
		frame:SetScale(1)
		freeFrames[frame] = nil
	else
		frame_num = frame_num + 1
		frame = CreateFrame("Frame", "ParrotFrameFrame" .. frame_num, ParrotFrame)
		local content = CreateFrame("Frame", nil, frame)
		content:SetPoint("CENTER", frame, "CENTER", 0, 0)
		frame.content = content
	end
	local content = frame.content
	content:SetScale(1)

	local fs = next(freeFontStrings)
	if fs then
		fs:ClearAllPoints()
		freeFontStrings[fs] = nil
		fs:SetParent(content)
	else
		fontString_num = fontString_num + 1
		fs = content:CreateFontString("ParrotFrameFontString" .. fontString_num, "ARTWORK", "SystemFont_Shadow_Small")
	end
	if db.smoothEasing ~= false then
		DisablePixelSnap(fs)
	end

	local fontPath = nil
	if db.useElvUIFont and _G.ElvUI then
		local E = _G.ElvUI[1]
		if E then
			if E.db and E.db.general and E.db.general.font then
				fontPath = LibSharedMedia:Fetch("font", E.db.general.font, true)
			end
			if not fontPath and E.media then
				fontPath = E.media.combatFont or E.media.normFont
			end
		end
	end
	if not fontPath then
		fontPath = LibSharedMedia:Fetch("font", font, true)
	end
	if not fontPath and _G.ElvUI then
		local E = _G.ElvUI[1]
		if E and E.db and E.db.general and E.db.general.font then
			fontPath = LibSharedMedia:Fetch("font", E.db.general.font, true)
		end
		if not fontPath and E and E.media and E.media.normFont then
			fontPath = E.media.normFont
		end
	end
	fs:SetFont(fontPath or LibSharedMedia:Fetch("font", font) or _G.STANDARD_TEXT_FONT, fontSize, outline)
	if shadow then
		local so = sticky and 2 or 1.5
		fs:SetShadowOffset(so, -so)
		fs:SetShadowColor(0, 0, 0, 0.9)
	else
		fs:SetShadowColor(0, 0, 0, 0)
	end
	frame.fs = fs

	local isCrit = sticky or (meta and meta.isCrit) or false
	local isTrigger = meta and meta.isTrigger or false

	local holder, texture
	if icon and db.iconsEnabled and scrollArea.iconSide ~= "DISABLE" then
		if type(icon) == "number" or icon ~= "Interface\\Icons\\Temp" then
			holder = acquireIconHolder(content)
			texture = holder.tex
			texture:SetTexture(icon)
			if _G.ElvUI then
				local E = _G.ElvUI[1]
				local texCoords = (E and E.TexCoords) or { 0.08, 0.92, 0.08, 0.92 }
				texture:SetTexCoord(unpack(texCoords))
			else
				texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			end
			local iconSize = math_max(12, math.floor(fontSize * 1.05 + 0.5))
			holder:SetWidth(iconSize)
			holder:SetHeight(iconSize)
			holder.gloss:SetHeight(math_max(2, iconSize * 0.28))

			if db.iconBorder ~= false then
				local mult = (ns.UIStyle and ns.UIStyle.GetElvUI() and ns.UIStyle.GetMult()) or nil
				local outerOff = mult and (2 * mult) or 1.5
				local rimOff = mult and (1 * mult) or 0.8
				holder.outerBorder:ClearAllPoints()
				holder.outerBorder:SetPoint("TOPLEFT", holder, "TOPLEFT", -outerOff, outerOff)
				holder.outerBorder:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", outerOff, -outerOff)
				holder.colorRim:ClearAllPoints()
				holder.colorRim:SetPoint("TOPLEFT", holder, "TOPLEFT", -rimOff, rimOff)
				holder.colorRim:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", rimOff, -rimOff)
				holder.outerBorder:Show()
				holder.colorRim:Show()
				holder.gloss:Show()
				if db.iconColorBorder ~= false then
					local br = (meta and meta.schoolR) or r or 1
					local bg = (meta and meta.schoolG) or g or 1
					local bb = (meta and meta.schoolB) or b or 1
					if isCrit and not isTrigger then
						br = br * 0.45 + 0.55
						bg = bg * 0.45 + 0.45
						bb = bb * 0.30 + 0.08
					end
					holder.colorRim:SetVertexColor(br, bg, bb, 0.95)
				else
					holder.colorRim:SetVertexColor(0.24, 0.24, 0.28, 0.95)
				end
			else
				holder.outerBorder:Hide()
				holder.colorRim:Hide()
				holder.gloss:Hide()
			end

			if isCrit or isTrigger then
				local gr = (meta and meta.schoolR) or r or 1
				local gg = (meta and meta.schoolG) or g or 0.82
				local gb = (meta and meta.schoolB) or b or 0.2
				if isCrit and not isTrigger then
					gr = gr * 0.35 + 0.65
					gg = gg * 0.35 + 0.53
					gb = gb * 0.25 + 0.10
				end
				startIconGlow(holder, gr, gg, gb)
			end

			frame.iconHolder = holder
			frame.icon = holder
		end
	end

	if holder then
		local gap = db.iconBorder ~= false and 5 or 3
		if scrollArea.iconSide == "RIGHT" then
			holder:SetPoint("LEFT", fs, "RIGHT", gap, 0)
			fs:SetPoint("LEFT", content, "LEFT", 0, 0)
		else
			holder:SetPoint("LEFT", content, "LEFT", 0, 0)
			fs:SetPoint("LEFT", holder, "RIGHT", gap, 0)
		end
	else
		fs:SetPoint("LEFT", content, "LEFT", 0, 0)
	end

	if r and g and b then
		fs:SetTextColor(r, g, b)
	else
		fs:SetTextColor(1, 1, 1)
	end
	fs:SetText(text)

	frame.start = GetTime()
	frame.scrollArea = scrollArea
	frame.sticky = sticky
	frame.baseScale = computeDynamicScale(meta, sticky)
	frame.zoomScale = nil
	frame.peakScale = db.critScale or 1.35
	frame.smoothEasing = (db.smoothEasing ~= false)

	-- Optional Nameplate coordinate tracking
	local anchorMode = scrollArea.anchorMode
	if anchorMode and anchorMode ~= "SCREEN" then
		local unitGUID = meta and meta.unitGUID or nil
		local npX, npY = resolveNameplateOffset(anchorMode, unitGUID, scrollArea.nameplateXOffset, scrollArea.nameplateYOffset)
		if npX and npY then
			frame.useNameplate = true
			frame.anchorMode = anchorMode
			frame.targetGUID = unitGUID
			frame.plateX = npX
			frame.plateY = npY
			frame.plateJitterX = (math.random() - 0.5) * 14
		end
	end

	if sticky then
		frame:SetFrameLevel(3)
	else
		frame:SetFrameLevel(1)
	end

	local animationStyle = sticky and scrollArea.stickyAnimationStyle or scrollArea.animationStyle
	local aniStyle = Parrot_AnimationStyles:GetAnimationStyle(animationStyle)
	if not next(wildFrames) then
		ParrotFrame:Show()
	end
	local wildFrames_scrollArea = wildFrames[scrollArea]
	if not wildFrames_scrollArea then
		wildFrames_scrollArea = newList()
		wildFrames[scrollArea] = wildFrames_scrollArea
	end
	local wildFrames_scrollArea_aniStyle = wildFrames_scrollArea[aniStyle]
	if not wildFrames_scrollArea_aniStyle then
		wildFrames_scrollArea_aniStyle = newList()
		wildFrames_scrollArea[aniStyle] = wildFrames_scrollArea_aniStyle
	end
	wildFrames_scrollArea_aniStyle.length = scrollArea[sticky and "stickySpeed" or "speed"] or 3

	local frameIDs_scrollArea = frameIDs[scrollArea]
	if not frameIDs_scrollArea then
		frameIDs_scrollArea = newList()
		frameIDs[scrollArea] = frameIDs_scrollArea
	end
	local frameIDs_scrollArea_aniStyle = (frameIDs_scrollArea[aniStyle] or 0) + 1
	frameIDs_scrollArea[aniStyle] = frameIDs_scrollArea_aniStyle
	frame.id = frameIDs_scrollArea_aniStyle

	table.insert(wildFrames_scrollArea_aniStyle, 1, frame)
	fs:Show()
	frame:Show()
	frame.font, frame.fontSize, frame.fontOutline = fs:GetFont()

	local initX = frame.useNameplate and (frame.plateX + frame.plateJitterX) or scrollArea.xOffset
	local initY = frame.useNameplate and frame.plateY or scrollArea.yOffset
	local init = aniStyle.init
	if init then
		init(frame, initX, initY, scrollArea.size, scrollArea[sticky and "stickyDirection" or "direction"] or aniStyle.defaultDirection, frameIDs_scrollArea_aniStyle)
	end

	local startAlpha = (db.smoothEasing ~= false) and 0.15 or 1
	fs:SetAlpha(db.alpha * startAlpha)
	if holder then
		holder:SetAlpha(db.iconAlpha * startAlpha)
	end
	Display_Update()
end
Parrot.ShowMessage = module.ShowMessage

local function getSafeFrameSize(fs, icon, fontSize, iconBorder)
	local fallbackH = fontSize or 18
	local w = SafeNumber(fs:GetWidth()) or (fallbackH * 6)
	local h = SafeNumber(fs:GetHeight()) or fallbackH
	local iconW = icon and (SafeNumber(icon:GetWidth()) or fallbackH) or 0
	local iconH = icon and (SafeNumber(icon:GetHeight()) or fallbackH) or 0
	local gap = icon and (iconBorder and 5 or 3) or 0
	return w + iconW + gap, math_max(h, iconH)
end

local function isOverlapping(alpha, bravo, pad)
	local aL, aR, aB, aT = SafeNumber(alpha:GetLeft()), SafeNumber(alpha:GetRight()), SafeNumber(alpha:GetBottom()), SafeNumber(alpha:GetTop())
	local bL, bR, bB, bT = SafeNumber(bravo:GetLeft()), SafeNumber(bravo:GetRight()), SafeNumber(bravo:GetBottom()), SafeNumber(bravo:GetTop())
	if not (aL and aR and aB and aT and bL and bR and bB and bT) then
		return false
	end
	pad = pad or 0
	if aL <= bR and bL <= aR and (aB - pad) <= bT and (bB - pad) <= aT then
		return true
	end
	return false
end

local lastUpdateTime = 0

function Display_Update()
	local now = GetTime()
	local dt = now - lastUpdateTime
	if dt <= 0 or dt > 0.25 then
		dt = 0.016
	end
	lastUpdateTime = now

	local smooth = (db.smoothEasing ~= false)
	local overlapPad = smooth and 2 or 0
	local hasBorder = (db.iconBorder ~= false)

	for scrollArea, u in next, wildFrames do
		for animationStyle, t in next, u do
			local t_len = #t
			local lastFrame = animationStyle.overlap and newList()
			for i, frame in ipairs(t) do
				local start, length = frame.start, t.length
				if start + length <= now then
					for j = i, t_len do
						local f = t[j]
						t[j] = nil
						releaseFrame(f, scrollArea, animationStyle)
					end
					break
				end

				local percent = (now - start) / length
				if percent < 0 then
					percent = 0
				end

				-- Alpha envelope (smooth fade-in + cosine fade-out vs classic linear tail)
				local alphaFactor
				if smooth then
					alphaFactor = Easing.SmoothAlpha(percent, 0.055, 0.76)
				else
					alphaFactor = (percent >= 0.8) and ((1 - percent) * 5) or 1
				end
				frame.fs:SetAlpha(alphaFactor * db.alpha)
				if frame.iconHolder then
					frame.iconHolder:SetAlpha(alphaFactor * db.iconAlpha)
				end

				-- Update live Nameplate coordinates if still visible on screen
				local effX = scrollArea.xOffset
				local effY = scrollArea.yOffset
				if frame.useNameplate then
					local npX, npY = resolveNameplateOffset(frame.anchorMode, frame.targetGUID, scrollArea.nameplateXOffset, scrollArea.nameplateYOffset)
					if npX and npY then
						frame.plateX = npX
						frame.plateY = npY
					end
					effX = frame.plateX + (frame.plateJitterX or 0)
					effY = frame.plateY
				end

				local dir = scrollArea[frame.sticky and "stickyDirection" or "direction"] or animationStyle.defaultDirection
				frame.zoomScale = nil
				frame:ClearAllPoints()
				animationStyle.func(frame, effX, effY, scrollArea.size, percent, dir, i, t_len, frame.id)

				-- Compute unified content scale (base dynamic scale * style zoom or default pop)
				local baseScale = frame.baseScale or 1
				local zoomScale = frame.zoomScale
				if not zoomScale then
					if smooth then
						if frame.sticky then
							zoomScale = Easing.CritPopScale(percent, frame.peakScale or 1.35, 0.20)
						else
							zoomScale = Easing.NormalPopScale(percent, 0.065)
						end
					else
						zoomScale = 1
					end
				end
				local totalScale = math_max(0.1, baseScale * zoomScale)
				frame.content:SetScale(totalScale)

				local fw, fh = getSafeFrameSize(frame.fs, frame.iconHolder, frame.fontSize, hasBorder)
				frame.content:SetWidth(fw)
				frame.content:SetHeight(fh)
				frame:SetWidth(fw * totalScale)
				frame:SetHeight(fh * totalScale)

				if lastFrame then
					for h = #lastFrame, 1, -1 do
						if isOverlapping(lastFrame[h], frame, overlapPad) then
							local minimum = percent
							local maximum = 1
							local current = (percent + maximum) * 0.5
							while maximum - minimum > 0.01 do
								animationStyle.func(frame, effX, effY, scrollArea.size, current, dir, i, t_len, frame.id)
								fw, fh = getSafeFrameSize(frame.fs, frame.iconHolder, frame.fontSize, hasBorder)
								frame:SetWidth(fw * totalScale)
								frame:SetHeight(fh * totalScale)
								if isOverlapping(lastFrame[h], frame, overlapPad) then
									minimum = current
								else
									maximum = current
								end
								current = (maximum + minimum) * 0.5
							end
							current = current + 0.01
							local targetStart = -current * length + now
							if smooth and (now - start) > 0.03 then
								local blend = math_min(1, dt * 24)
								frame.start = frame.start + (targetStart - frame.start) * blend
								current = (now - frame.start) / length
							else
								frame.start = targetStart
							end
							animationStyle.func(frame, effX, effY, scrollArea.size, current, dir, i, t_len, frame.id)
							fw, fh = getSafeFrameSize(frame.fs, frame.iconHolder, frame.fontSize, hasBorder)
							frame:SetWidth(fw * totalScale)
							frame:SetHeight(fh * totalScale)
							for j = i + 1, t_len do
								local v = t[j]
								if v.start > frame.start then
									v.start = frame.start
								end
							end
						end
					end
					lastFrame[#lastFrame + 1] = frame
				end
			end
			if lastFrame then
				lastFrame = del(lastFrame)
			end
			if not t[1] then
				u[animationStyle] = del(t)
			end
		end
		if not next(u) then
			wildFrames[scrollArea] = del(u)
		end
	end
	if not next(wildFrames) then
		ParrotFrame:Hide()
	end
end
ParrotFrame:SetScript("OnUpdate", Display_Update)

local flasher = nil
local function makeflasher()
	flasher = CreateFrame("Frame", "ParrotFlash", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	if BackdropTemplateMixin and not flasher.SetBackdrop then
		Mixin(flasher, BackdropTemplateMixin)
	end
	flasher:SetFrameStrata("BACKGROUND")
	flasher:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
	flasher:SetAllPoints(UIParent)
	flasher:SetScript("OnShow", function(self)
		self.elapsed = 0
		self:SetAlpha(0)
	end)
	flasher:SetScript("OnUpdate", function(self, elapsed)
		elapsed = self.elapsed + elapsed
		if elapsed >= 0.85 then
			self:Hide()
			self:SetAlpha(0)
			return
		end
		local t = elapsed / 0.85
		local alpha = math.sin(t * math.pi)
		self:SetAlpha(alpha * 0.55)
		self.elapsed = elapsed
	end)
	flasher:Hide()
end

function module:Flash(r, g, b)
	if not flasher then makeflasher() end
	flasher:SetBackdropColor(r, g, b, 1)
	flasher:Show()
end
Parrot.Flash = module.Flash
