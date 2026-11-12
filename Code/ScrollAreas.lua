local _, ns = ...
local Parrot = ns.addon
local module = Parrot:NewModule("ScrollAreas", "AceTimer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Parrot")

local Parrot_AnimationStyles = Parrot:GetModule("AnimationStyles")

local db = nil
local defaults = {
	profile = {
		areas = {},
		dbver = 0,
	}
}

local setConfigMode
local scrollAreas

local choices = {}
local rebuildChoices do
	local localizedNames = {
		["Incoming"] = L["Incoming"],
		["Outgoing"] = L["Outgoing"],
		["Notification"] = L["Notification"],
	}
	function rebuildChoices()
		wipe(choices)
		for k, v in next, scrollAreas do
			choices[k] = localizedNames[k] or k
		end
	end
end

local updateFuncs = {
	[1] = function()
		-- Copy the defaults into the db
		local function merge(dst, src)
			for k, v in next, src do
				if not dst[k] then
					if type(v) == "table" then
						dst[k] = CopyTable(v)
					else
						dst[k] = v
					end
				elseif type(v) == "table" then
					if type(dst[k]) ~= "table" then
						dst[k] = {}
					end
					merge(dst[k], v)
				end
			end
		end

		local defaultScrollAreas = {
			["Notification"] = {
				animationStyle = "PopUp",
				direction = "UP;CENTER",
				stickyAnimationStyle = "Impact",
				stickyDirection = "UP;CENTER",
				size = 160,
				xOffset = 0,
				yOffset = 175,
				iconSide = "LEFT",
				anchorMode = "SCREEN",
			},
			["Incoming"] = {
				animationStyle = "Cascade",
				direction = "DOWN;LEFT",
				stickyAnimationStyle = "Impact",
				stickyDirection = "DOWN;RIGHT",
				size = 260,
				xOffset = -110,
				yOffset = -30,
				iconSide = "RIGHT",
				anchorMode = "SCREEN",
			},
			["Outgoing"] = {
				animationStyle = "Fountain",
				direction = "UP;RIGHT",
				stickyAnimationStyle = "Impact",
				stickyDirection = "UP;LEFT",
				size = 260,
				xOffset = 110,
				yOffset = -20,
				iconSide = "LEFT",
				anchorMode = "SCREEN",
				nameplateXOffset = 0,
				nameplateYOffset = 24,
			},
		}
		merge(db.areas, defaultScrollAreas)
	end,
	[2] = function()
		-- Translating the names was a mistake! x_x
		if db.areas[L["Incoming"]] and L["Incoming"] ~= "Incoming" then
			db.areas["Incoming"] = db.areas[L["Incoming"]]
			db.areas[L["Incoming"]] = nil
		end
		if db.areas[L["Outgoing"]] and L["Outgoing"] ~= "Outgoing" then
			db.areas["Outgoing"] = db.areas[L["Outgoing"]]
			db.areas[L["Outgoing"]] = nil
		end
		if db.areas[L["Notification"]] and L["Notification"] ~= "Notification" then
			db.areas["Notification"] = db.areas[L["Notification"]]
			db.areas[L["Notification"]] = nil
		end
	end,
}

local function updateDB()
	if not db.dbver then
		db.dbver = 0
	end
	for i = db.dbver + 1, #updateFuncs do
		updateFuncs[i]()
	end
	db.dbver = #updateFuncs
end

function module:OnProfileChanged()
	setConfigMode(false)
	db = self.db.profile
	updateDB()
	scrollAreas = db.areas

	if Parrot.options.args.scrollAreas then
		Parrot.options.args.scrollAreas = nil
		self:OnOptionsCreate()
	end
	rebuildChoices()
end

function module:OnInitialize()
	self.db = Parrot.db:RegisterNamespace("ScrollAreas", defaults)
	self:OnProfileChanged()
end

function module:OnEnable()
	setConfigMode(false)
end

function module:OnDisable()
	setConfigMode(false)
end

-- Register ConfigMode callback (http://wowpedia.org/ConfigMode)
CONFIGMODE_CALLBACKS = CONFIGMODE_CALLBACKS or {}
CONFIGMODE_CALLBACKS["Parrot"] = function(state)
	setConfigMode(state == "ON")
end

function Parrot:SetConfigMode(state)
	if type(state) ~= "boolean" then
		error(("Bad argument #2 to `SetConfigMode'. Expected %q, got %q."):format("boolean", type(state)), 2)
	end
	setConfigMode(state)
end

local configModeTimer
local offsetBoxes
local function hideAllOffsetBoxes()
	if not offsetBoxes then
		return
	end
	for k, v in next, offsetBoxes do
		v:Hide()
	end
	module:CancelTimer(configModeTimer)
end

local function updateOffsetBoxLabel(offsetBox, k)
	local area = scrollAreas and scrollAreas[k]
	if not area or not offsetBox then return end
	local x = math.floor((area.xOffset or 0) + 0.5)
	local y = math.floor((area.yOffset or 0) + 0.5)
	local localizedArea = choices[k] or k
	local styleTag = area.animationStyle or "Straight"
	offsetBox.topText:SetText("|cffffd100" .. localizedArea .. "|r  |cff9999a8(" .. styleTag .. ")|r")
	offsetBox.bottomText:SetText(L["Position: %d, %d"]:format(x, y))
end

local function nudgeScrollArea(k, dx, dy)
	local area = scrollAreas and scrollAreas[k]
	if not area then return end
	area.xOffset = math.floor((area.xOffset or 0) + dx + 0.5)
	area.yOffset = math.floor((area.yOffset or 0) + dy + 0.5)
	local box = offsetBoxes and offsetBoxes[k]
	if box and box.midPoint then
		box.midPoint:ClearAllPoints()
		box.midPoint:SetPoint("CENTER", UIParent, "CENTER", area.xOffset, area.yOffset)
		updateOffsetBoxLabel(box, k)
	end
	local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
	if AceConfigRegistry then
		AceConfigRegistry:NotifyChange("Parrot")
	end
end

local function createNudgeButton(parent, label, dx, dy, anchorPoint, relTo, relPoint, offX, offY)
	local btn = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	btn:SetSize(20, 18)
	btn:SetPoint(anchorPoint, relTo, relPoint, offX, offY)
	if ns.UIStyle then
		ns.UIStyle.ApplyBox(btn, { 0.14, 0.14, 0.18, 0.95 }, { 0.55, 0.44, 0.16, 0.90 })
	end
	local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	fs:SetPoint("CENTER", 0, 0)
	fs:SetTextColor(1, 0.85, 0.25)
	fs:SetText(label)
	btn:SetScript("OnEnter", function(self)
		if ns.UIStyle then
			ns.UIStyle.ApplyBox(self, { 0.25, 0.20, 0.08, 0.98 }, { 1.0, 0.82, 0.0, 1.0 })
		end
		if GameTooltip then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:AddLine(L["Precision Nudge"], 1, 0.82, 0)
			GameTooltip:AddLine(L["Click: 1 px  |  Shift+Click: 10 px"], 0.9, 0.9, 0.9)
			GameTooltip:Show()
		end
	end)
	btn:SetScript("OnLeave", function(self)
		if ns.UIStyle then
			ns.UIStyle.ApplyBox(self, { 0.14, 0.14, 0.18, 0.95 }, { 0.55, 0.44, 0.16, 0.90 })
		end
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	btn:SetScript("OnClick", function()
		local step = IsShiftKeyDown() and 10 or 1
		nudgeScrollArea(parent.areaKey, dx * step, dy * step)
	end)
	return btn
end

local function showOffsetBox(k)
	if not offsetBoxes then
		offsetBoxes = {}
	end
	local offsetBox = offsetBoxes[k]
	if not offsetBox then
		offsetBox = CreateFrame("Button", "ParrotScrollAreasOffsetBox" .. k, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		offsetBox.areaKey = k
		local midPoint = CreateFrame("Frame", "$parentMidPoint", offsetBox)
		offsetBox.midPoint = midPoint
		midPoint:SetWidth(1)
		midPoint:SetHeight(1)
		offsetBoxes[k] = offsetBox
		offsetBox:SetPoint("CENTER", midPoint, "CENTER")
		offsetBox:SetWidth(290)
		offsetBox:SetHeight(106)
		offsetBox:SetFrameStrata("DIALOG")
		offsetBox:RegisterForClicks("RightButtonUp")

		if _G.ElvUI and offsetBox.SetTemplate then
			offsetBox:SetTemplate("Transparent")
			offsetBox:SetBackdropBorderColor(1, 0.82, 0, 0.92)
		elseif ns.UIStyle and offsetBox.SetBackdrop then
			ns.UIStyle.ApplyBox(offsetBox, { 0.06, 0.06, 0.09, 0.84 }, { 0.88, 0.70, 0.18, 0.95 })
		else
			local bg = offsetBox:CreateTexture("$parentBackground", "BACKGROUND")
			bg:SetColorTexture(0.08, 0.08, 0.11, 0.84)
			bg:SetAllPoints(offsetBox)
			offsetBox.bg = bg
		end

		local mult = (ns.UIStyle and ns.UIStyle.GetMult()) or 1

		-- Subtle center crosshair guides for pixel-accurate alignment
		local hLine = offsetBox:CreateTexture(nil, "BORDER")
		hLine:SetHeight(mult)
		hLine:SetPoint("LEFT", offsetBox, "LEFT", 8, 0)
		hLine:SetPoint("RIGHT", offsetBox, "RIGHT", -8, 0)
		hLine:SetColorTexture(1.0, 0.82, 0.0, 0.22)

		local vLine = offsetBox:CreateTexture(nil, "BORDER")
		vLine:SetWidth(mult)
		vLine:SetPoint("TOP", offsetBox, "TOP", 0, -22)
		vLine:SetPoint("BOTTOM", offsetBox, "BOTTOM", 0, 22)
		vLine:SetColorTexture(1.0, 0.82, 0.0, 0.22)

		local centerDot = offsetBox:CreateTexture(nil, "ARTWORK")
		centerDot:SetSize(5, 5)
		centerDot:SetPoint("CENTER", 0, 0)
		centerDot:SetColorTexture(1.0, 0.82, 0.0, 0.85)

		local topText = offsetBox:CreateFontString("$parentTopText", "OVERLAY", "GameFontNormal")
		offsetBox.topText = topText
		topText:SetPoint("TOP", offsetBox, "TOP", 0, -7)

		local text = offsetBox:CreateFontString("$parentText", "OVERLAY", "GameFontHighlightSmall")
		offsetBox.text = text
		text:SetTextColor(0.82, 0.82, 0.88)
		text:SetText(L["Drag to move  •  Right-click to lock"])
		text:SetPoint("CENTER", 0, 4)

		local bottomText = offsetBox:CreateFontString("$parentBottomText", "OVERLAY", "GameFontHighlightSmall")
		offsetBox.bottomText = bottomText
		bottomText:SetTextColor(1.0, 0.85, 0.35)
		bottomText:SetPoint("BOTTOM", offsetBox, "BOTTOM", -26, 7)

		-- 4 directional 1px / 10px nudge buttons in bottom-right cluster
		local btnRight = createNudgeButton(offsetBox, "►",  1,  0, "BOTTOMRIGHT", offsetBox, "BOTTOMRIGHT", -6, 5)
		local btnDown  = createNudgeButton(offsetBox, "▼",  0, -1, "RIGHT", btnRight, "LEFT", -2, 0)
		local btnUp    = createNudgeButton(offsetBox, "▲",  0,  1, "RIGHT", btnDown,  "LEFT", -2, 0)
		createNudgeButton(offsetBox, "◄", -1,  0, "RIGHT", btnUp,    "LEFT", -2, 0)

		offsetBox:SetScript("OnClick", function(_, button)
			if button == "RightButton" then
				setConfigMode(false)
			end
		end)

		offsetBox:SetScript("OnDragStart", function(this)
			midPoint:StartMoving()
			this.moving = true
		end)

		offsetBox:SetScript("OnDragStop", function(this)
			this:GetScript("OnUpdate")(this)
			this.moving = nil
			midPoint:StopMovingOrSizing()
			local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
			if AceConfigRegistry then
				AceConfigRegistry:NotifyChange("Parrot")
			end
		end)

		offsetBox:SetScript("OnUpdate", function(this)
			if this.moving then
				local x, y = this:GetCenter()
				x = math.floor((x - GetScreenWidth() / 2) + 0.5)
				y = math.floor((y - GetScreenHeight() / 2) + 0.5)
				scrollAreas[k].xOffset = x
				scrollAreas[k].yOffset = y
				updateOffsetBoxLabel(this, k)
			end
		end)

		offsetBox:SetMovable(true)
		offsetBox:RegisterForDrag("LeftButton")
		midPoint:SetMovable(true)
		midPoint:RegisterForDrag("LeftButton")
		offsetBox:Hide()

		midPoint:SetClampedToScreen(true)
	end

	offsetBox:Show()

	local offsetX, offsetY = scrollAreas[k].xOffset or 0, scrollAreas[k].yOffset or 0
	offsetBox.midPoint:ClearAllPoints()
	offsetBox.midPoint:SetPoint("CENTER", UIParent, "CENTER", offsetX, offsetY)
	updateOffsetBoxLabel(offsetBox, k)
end

local DEMO_SAMPLES = {
	Outgoing = {
		normal = {
			{ amount = 14820, suffix = "",      r = 1.00, g = 0.50, b = 0.12, spell = 133,   fallback = "Interface\\Icons\\Spell_Fire_FlameBolt" },
			{ amount = 9240,  suffix = " (x3)", r = 0.68, g = 0.42, b = 1.00, spell = 589,   fallback = "Interface\\Icons\\Spell_Shadow_ShadowWordPain" },
			{ amount = 21350, suffix = "",      r = 0.35, g = 0.78, b = 1.00, spell = 116,   fallback = "Interface\\Icons\\Spell_Frost_FrostBolt02" },
		},
		sticky = {
			{ amount = 74900, suffix = "!",     r = 1.00, g = 0.84, b = 0.18, spell = 11366, fallback = "Interface\\Icons\\Spell_Fire_Fireball02" },
			{ amount = 61200, suffix = "!",     r = 1.00, g = 0.92, b = 0.45, spell = 23922, fallback = "Interface\\Icons\\INV_Shield_05" },
		},
	},
	Incoming = {
		normal = {
			{ textPrefix = "-", amount = 8450,  suffix = "",      r = 0.95, g = 0.25, b = 0.25, spell = 6603, fallback = "Interface\\Icons\\Ability_MeleeDamage" },
			{ textPrefix = "+", amount = 15600, suffix = "",      r = 0.22, g = 0.95, b = 0.38, spell = 774,  fallback = "Interface\\Icons\\Spell_Nature_Rejuvenation" },
		},
		sticky = {
			{ textPrefix = "+", amount = 52400, suffix = "!",     r = 0.35, g = 1.00, b = 0.48, spell = 2061, fallback = "Interface\\Icons\\Spell_Holy_FlashHeal" },
		},
	},
	Notification = {
		normal = {
			{ rawText = "+450 " .. (_G.COMBAT_TEXT_HONOR or "Honor"), r = 0.95, g = 0.78, b = 0.25, fallback = "Interface\\Icons\\Achievement_PVP_O_01" },
		},
		sticky = {
			{ rawText = "[Hot Streak!]", r = 1.00, g = 0.82, b = 0.15, spell = 11366, fallback = "Interface\\Icons\\Spell_Fire_Fireball02" },
		},
	},
}

local sampleCursor = 0
local function test(kind, k)
	sampleCursor = sampleCursor + 1
	local bucket = DEMO_SAMPLES[k] or DEMO_SAMPLES.Outgoing
	local list = (kind == "sticky") and bucket.sticky or bucket.normal
	local entry = list[((sampleCursor - 1) % #list) + 1]
	local isSticky = (kind == "sticky")
	local icon = (entry.spell and ns.Compat.GetSpellTexture(entry.spell)) or entry.fallback
	local msgText
	if entry.rawText then
		msgText = entry.rawText
	else
		msgText = (entry.textPrefix or "") .. Parrot:ShortenAmount(entry.amount) .. (entry.suffix or "")
	end
	Parrot:ShowMessage(msgText, k, isSticky, entry.r, entry.g, entry.b, nil, nil, nil, icon, {
		isCrit = isSticky,
		amount = entry.amount,
		schoolR = entry.r,
		schoolG = entry.g,
		schoolB = entry.b,
	})
end

local configModeMessages
do
	local num = 0
	function configModeMessages()
		num = num % 2 + 1
		for k in next, scrollAreas do
			test("normal", k)
		end
		if num == 2 then
			for k in next, scrollAreas do
				test("sticky", k)
			end
		end
	end
end

local configMode = false
module.configMode = false

function Parrot:GetConfigMode()
	return configMode
end

function setConfigMode(value)
	configMode = not not value
	module.configMode = configMode
	if not configMode then
		hideAllOffsetBoxes()
	else
		for k in next, scrollAreas do
			showOffsetBox(k)
		end
		configModeTimer = module:ScheduleRepeatingTimer(configModeMessages, 1)
		configModeMessages()
	end
	if ns.ConfigWindow and ns.ConfigWindow.RefreshFooter then
		ns.ConfigWindow:RefreshFooter()
	end
end

function module:HasScrollArea(name)
	return not not scrollAreas[name]
end

function module:GetScrollArea(name)
	return scrollAreas[name]
end

function module:GetRandomScrollArea()
	local i = 0
	for k, v in next, scrollAreas do
		i = i + 1
	end
	local num = math.random(1, i)
	i = 0
	for k, v in next, scrollAreas do
		i = i + 1
		if i == num then
			return k, v
		end
	end
	return
end

function module:GetScrollAreasChoices()
	return choices
end
Parrot.GetScrollAreasChoices = module.GetScrollAreasChoices

function module:ApplyModernScrollPreset()
	if not scrollAreas then return end
	if scrollAreas["Outgoing"] then
		scrollAreas["Outgoing"].animationStyle = "Fountain"
		scrollAreas["Outgoing"].direction = "UP;RIGHT"
		scrollAreas["Outgoing"].stickyAnimationStyle = "Impact"
		scrollAreas["Outgoing"].stickyDirection = "UP;LEFT"
	end
	if scrollAreas["Incoming"] then
		scrollAreas["Incoming"].animationStyle = "Cascade"
		scrollAreas["Incoming"].direction = "DOWN;LEFT"
		scrollAreas["Incoming"].stickyAnimationStyle = "Impact"
		scrollAreas["Incoming"].stickyDirection = "DOWN;RIGHT"
	end
	if scrollAreas["Notification"] then
		scrollAreas["Notification"].animationStyle = "PopUp"
		scrollAreas["Notification"].direction = "UP;CENTER"
		scrollAreas["Notification"].stickyAnimationStyle = "Impact"
		scrollAreas["Notification"].stickyDirection = "UP;CENTER"
	end
	if Parrot.options.args.scrollAreas then
		Parrot.options.args.scrollAreas = nil
		self:OnOptionsCreate()
	end
end

function module:OnOptionsCreate()
	local scrollAreas_opt
	local function getName(info)
		local name = info.arg
		return name
	end
	local function setName(info, new)
		local old = info.arg
		if old == new or scrollAreas[new] then
			return
		end
		local shouldConfig = configMode
		if shouldConfig then
			setConfigMode(false)
		end
		local v = scrollAreas[old]
		scrollAreas[old] = nil
		scrollAreas[new] = v
		local opt = scrollAreas_opt.args[tostring(v)]
		choices[old] = nil
		choices[new] = new
		if new == L["New scroll area"] then
			opt.order = -110
		else
			opt.order = -100
		end
		opt.name = new
		opt.args.name.arg = new
		opt.args.remove.arg = new
		opt.args.size.arg = new
		opt.args.test.args.normal.arg[2] = new
		opt.args.test.args.sticky.arg[2] = new
		opt.args.direction.args.normal.arg[2] = new
		opt.args.direction.args.sticky.arg[2] = new
		opt.args.animationStyle.args.normal.arg[2] = new
		opt.args.animationStyle.args.sticky.arg[2] = new
		opt.args.speed.args.normal.arg[2] = new
		opt.args.speed.args.sticky.arg[2] = new
		opt.args.icon.arg = new
		opt.args.anchor.args.anchorMode.arg = new
		opt.args.anchor.args.nameplateXOffset.arg = new
		opt.args.anchor.args.nameplateYOffset.arg = new
		opt.args.positionX.arg = new
		opt.args.positionY.arg = new
		opt.args.font.args.fontface.arg[2] = new
		opt.args.font.args.fontSizeInherit.arg[2] = new
		opt.args.font.args.fontSize.arg[2] = new
		opt.args.font.args.fontOutline.arg[2] = new
		opt.args.font.args.fontShadow.arg[2] = new
		opt.args.font.args.stickyfontface.arg[2] = new
		opt.args.font.args.stickyfontSizeInherit.arg[2] = new
		opt.args.font.args.stickyfontSize.arg[2] = new
		opt.args.font.args.stickyfontOutline.arg[2] = new
		opt.args.font.args.stickyfontShadow.arg[2] = new
		if shouldConfig then
			setConfigMode(true)
		end
		rebuildChoices()
	end
	local function getFontFace(info)
		local kind, k = info.arg[1], info.arg[2]
		local font = scrollAreas[k][kind == "normal" and "font" or "stickyFont"]
		if font == nil then
			return -1
		end
		for i, v in next, Parrot.fontValues do
			if v == font then return i end
		end
	end
	local function setFontFace(info, value)
		local kind, k = info.arg[1], info.arg[2]
		if value == -1 then
			scrollAreas[k][kind == "normal" and "font" or "stickyFont"] = nil
		else
			scrollAreas[k][kind == "normal" and "font" or "stickyFont"] = Parrot.fontValues[value]
		end
		if not configMode then
			test(kind, k)
		end
	end
	local function getFontSize(info)
		local kind, k = info.arg[1], info.arg[2]
		return scrollAreas[k][kind == "normal" and "fontSize" or "stickyFontSize"]
	end
	local function setFontSize(info, value)
		local kind, k = info.arg[1], info.arg[2]
		scrollAreas[k][kind == "normal" and "fontSize" or "stickyFontSize"] = value
		if not configMode then
			test(kind, k)
		end
	end
	local function getFontSizeInherit(info)
		local kind, k = info.arg[1], info.arg[2]
		return scrollAreas[k][kind == "normal" and "fontSize" or "stickyFontSize"] == nil
	end
	local function setFontSizeInherit(info, value)
		local kind, k = info.arg[1], info.arg[2]
		if value then
			scrollAreas[k][kind == "normal" and "fontSize" or "stickyFontSize"] = nil
		else
			scrollAreas[k][kind == "normal" and "fontSize" or "stickyFontSize"] = 18
		end
		if not configMode then
			test(kind, k)
		end
	end
	local function getFontOutline(info)
		local kind, k = info.arg[1], info.arg[2]
		local outline = scrollAreas[k][kind == "normal" and "fontOutline" or "stickyFontOutline"]
		if outline == nil then
			return L["Inherit"]
		else
			return outline
		end
	end
	local function setFontOutline(info, value)
		local kind, k = info.arg[1], info.arg[2]
		if value == L["Inherit"] then
			value = nil
		end
		scrollAreas[k][kind == "normal" and "fontOutline" or "stickyFontOutline"] = value
		if not configMode then
			test(kind, k)
		end
	end
	local fontOutlineChoices = {
		NONE = L["None"],
		MONOCHROME = L["Monochrome"],
		OUTLINE = L["Thin"],
		["OUTLINE,MONOCHROME"] = L["Thin, Monochrome"],
		THICKOUTLINE = L["Thick"],
		[L["Inherit"]] = L["Inherit"],
	}
	local function getFontShadow(info)
		local kind, k = info.arg[1], info.arg[2]
		local value = scrollAreas[k][kind == "normal" and "fontShadow" or "stickyFontShadow"]
		if value == nil then
			return L["Inherit"]
		else
			return tostring(value)
		end
	end
	local function setFontShadow(info, value)
		local kind, k = info.arg[1], info.arg[2]
		if value == L["Inherit"] then
			value = nil
		else
			value = value == "true"
		end
		scrollAreas[k][kind == "normal" and "fontShadow" or "stickyFontShadow"] = value
		if not configMode then
			test(kind, k)
		end
	end
	local fontShadowChoices = {
		["false"] = DISABLE,
		["true"] = ENABLE,
		[L["Inherit"]] = L["Inherit"],
	}
	local function getAnimationStyle(info)
		local kind, k = info.arg[1], info.arg[2]
		return scrollAreas[k][kind == "normal" and "animationStyle" or "stickyAnimationStyle"]
	end
	local function setAnimationStyle(info, value)
		local kind, k = info.arg[1], info.arg[2]
		scrollAreas[k][kind == "normal" and "animationStyle" or "stickyAnimationStyle"] = value
		local opt = scrollAreas_opt.args[tostring(scrollAreas[k])]
		local directionValues = Parrot_AnimationStyles:GetAnimationStyleDirectionChoices(value)
		opt.args.direction.args[kind].values = directionValues
		if not directionValues[scrollAreas[k][kind == "normal" and "direction" or "stickyDirection"]] then
			scrollAreas[k][kind == "normal" and "direction" or "stickyDirection"] = Parrot_AnimationStyles:GetAnimationStyleDefaultDirection(value)
		end
		if not configMode then
			test(kind, k)
			test(kind, k)
			test(kind, k)
		end
	end
	local function getSpeed(info)
		local kind, k = info.arg[1], info.arg[2]
		return scrollAreas[k][kind == "normal" and "speed" or "stickySpeed"] or 3
	end
	local function setSpeed(info, value)
		local kind, k = info.arg[1], info.arg[2]
		if value == 3 then
			value = nil
		end
		scrollAreas[k][kind == "normal" and "speed" or "stickySpeed"] = value
		if not configMode then
			test(kind, k)
		end
	end
	local function getDirection(info)
		local kind, k = info.arg[1], info.arg[2]
		return scrollAreas[k][kind == "normal" and "direction" or "stickyDirection"] or Parrot_AnimationStyles:GetAnimationStyleDefaultDirection(scrollAreas[k][kind == "normal" and "animationStyle" or "stickyAnimationStyle"])
	end
	local function setDirection(info, value)
		local kind, k = info.arg[1], info.arg[2]
		if value == Parrot_AnimationStyles:GetAnimationStyleDefaultDirection(scrollAreas[k][kind == "normal" and "animationStyle" or "stickyAnimationStyle"]) then
			value = nil
		end
		scrollAreas[k][kind == "normal" and "direction" or "stickyDirection"] = value
		if not configMode then
			test(kind, k)
			test(kind, k)
			test(kind, k)
		end
	end
	local function directionDisabled(info)
		local kind, k = info.arg[1], info.arg[2]
		return not Parrot_AnimationStyles:GetAnimationStyleDirectionChoices(scrollAreas[k][kind == "normal" and "animationStyle" or "stickyAnimationStyle"])
	end
	local function getPositionX(info)
		return scrollAreas[info.arg].xOffset
	end
	local function setPositionX(info, value)
		local k = info.arg
		if value > 0 then
			if value > GetScreenWidth()/2 then
				value = GetScreenWidth()/2
			end
		else
			if value < -GetScreenWidth()/2 then
				value = -GetScreenWidth()/2
			end
		end
		scrollAreas[k].xOffset = value
		if not configMode then
			test("normal", k)
			test("sticky", k)
		end
	end
	local function getPositionY(info)
		return scrollAreas[info.arg].yOffset
	end
	local function setPositionY(info, value)
		local k = info.arg
		if value > 0 then
			if value > GetScreenHeight()/2 then
				value = GetScreenHeight()/2
			end
		else
			if value < -GetScreenHeight()/2 then
				value = -GetScreenHeight()/2
			end
		end
		scrollAreas[k].yOffset = value
		if not configMode then
			test("normal", k)
			test("sticky", k)
		end
	end
	local function getSize(info)
		return scrollAreas[info.arg].size
	end
	local function setSize(info, value)
		local k = info.arg
		scrollAreas[k].size = value
		if not configMode then
			test("normal", k)
			test("sticky", k)
		end
	end
	local function remove(info)
		local k = info.arg
		local shouldConfig = configMode
		if shouldConfig then
			setConfigMode(false)
		end
		scrollAreas_opt.args[tostring(scrollAreas[k])] = nil
		scrollAreas[k] = nil
		choices[k] = nil
		if shouldConfig then
			setConfigMode(true)
		end
	end
	local function disableRemove(info)
		return not next(scrollAreas, next(scrollAreas))
	end
	local iconSideChoices = {
		LEFT = L["Left"],
		RIGHT = L["Right"],
		-- CENTER = L["Center of screen"],
		-- EDGE = L["Edge of screen"],
		DISABLE = L["Disable"],
	}
	local function getIconSide(info)
		local value = scrollAreas[info.arg].iconSide
		return iconSideChoices[value] and value or "LEFT"
	end
	local function setIconSide(info, value)
		local k = info.arg
		scrollAreas[k].iconSide = value
		if not configMode then
			test("normal", k)
			test("sticky", k)
		end
	end

	local anchorModeChoices = {
		SCREEN = L["Screen position"],
		NAMEPLATE = L["Unit nameplate (fallback: Screen)"],
		TARGET = L["Target nameplate (fallback: Screen)"],
	}
	local function getAnchorMode(info)
		local value = scrollAreas[info.arg].anchorMode
		return anchorModeChoices[value] and value or "SCREEN"
	end
	local function setAnchorMode(info, value)
		local k = info.arg
		scrollAreas[k].anchorMode = value
		if not configMode then
			test("normal", k)
			test("sticky", k)
		end
	end
	local function isNameplateDisabled(info)
		local mode = scrollAreas[info.arg].anchorMode
		return not mode or mode == "SCREEN"
	end
	local function getNameplateXOffset(info)
		return scrollAreas[info.arg].nameplateXOffset or 0
	end
	local function setNameplateXOffset(info, value)
		local k = info.arg
		scrollAreas[k].nameplateXOffset = value
		if not configMode then
			test("normal", k)
		end
	end
	local function getNameplateYOffset(info)
		local val = scrollAreas[info.arg].nameplateYOffset
		if val == nil then return 24 end
		return val
	end
	local function setNameplateYOffset(info, value)
		local k = info.arg
		scrollAreas[k].nameplateYOffset = value
		if not configMode then
			test("normal", k)
		end
	end

	local function makeOption(k)
		local v = scrollAreas[k]
		local opt = {
			type = 'group',
			name = choices[k],
			desc = L["Options for this scroll area."],
			args = {
				name = {
					type = 'input',
					name = L["Name"],
					desc = L["Name of the scroll area."],
					get = getName,
					set = setName,
					usage = L["<Name>"],
					arg = k,
					order = 1,
				},
				remove = {
					type = 'execute',
					name = L["Remove"],
					desc = L["Remove this scroll area."],
					func = remove,
					disabled = disableRemove,
					arg = k,
					order = -1,
					confirm = true,
					confirmText = L["Are you sure?"],
				},
				icon = {
					type = 'select',
					name = L["Icon side"],
					desc = L["Set the icon side for this scroll area or whether to disable icons entirely."],
					get = getIconSide,
					set = setIconSide,
					values = iconSideChoices,
					arg = k,
				},
				anchor = {
					type = 'group',
					inline = true,
					name = L["Nameplate & screen anchor"],
					args = {
						anchorMode = {
							type = 'select',
							name = L["Anchor target"],
							desc = L["Attach scrolling messages to enemy/friendly nameplates when visible, falling back to screen coordinates."],
							get = getAnchorMode,
							set = setAnchorMode,
							values = anchorModeChoices,
							width = "double",
							arg = k,
							order = 1,
						},
						nameplateXOffset = {
							type = 'range',
							name = L["Nameplate X offset"],
							desc = L["Horizontal pixel offset relative to the nameplate center."],
							get = getNameplateXOffset,
							set = setNameplateXOffset,
							disabled = isNameplateDisabled,
							min = -150,
							max = 150,
							step = 1,
							bigStep = 5,
							arg = k,
							order = 2,
						},
						nameplateYOffset = {
							type = 'range',
							name = L["Nameplate Y offset"],
							desc = L["Vertical pixel offset relative to the nameplate center."],
							get = getNameplateYOffset,
							set = setNameplateYOffset,
							disabled = isNameplateDisabled,
							min = -100,
							max = 150,
							step = 1,
							bigStep = 5,
							arg = k,
							order = 3,
						},
					},
				},
				test = {
					type = 'group',
					inline = true,
					name = L["Test"],
					desc = L["Send a test message through this scroll area."],
					args = {
						normal = {
							type = 'execute',
							name = L["Normal"],
							desc = L["Send a normal test message."],
							func = function(info) test(info.arg[1], info.arg[2]) end,
							arg = {"normal", k},
						},
						sticky = {
							type = 'execute',
							name = L["Sticky"],
							desc = L["Send a sticky test message."],
							func = function(info) test(info.arg[1], info.arg[2]) end,
							arg = {"sticky", k},
						},
					},
					disabled = function() return configMode end
				},
				direction = {
					type = 'group',
					inline = true,
					name = L["Direction"],
					desc = L["Which direction the animations should follow."],
					args = {
						normal = {
							type = 'select',
							name = L["Normal"],
							desc = L["Direction for normal texts."],
							get = getDirection,
							set = setDirection,
							disabled = directionDisabled,
							values = Parrot_AnimationStyles:GetAnimationStyleDirectionChoices(scrollAreas[k].animationStyle) or {},
							arg = {"normal", k},
						},
						sticky = {
							type = 'select',
							name = L["Sticky"],
							desc = L["Direction for sticky texts."],
							get = getDirection,
							set = setDirection,
							disabled = directionDisabled,
							values = Parrot_AnimationStyles:GetAnimationStyleDirectionChoices(scrollAreas[k].stickyAnimationStyle) or {},
							arg = {"sticky", k},
						},
					}
				},
				animationStyle = {
					type = 'group',
					inline = true,
					name = L["Animation style"],
					desc = L["Which animation style to use."],
					args = {
						normal = {
							type = 'select',
							name = L["Normal"],
							desc = L["Animation style for normal texts."],
							get = getAnimationStyle,
							set = setAnimationStyle,
							values = Parrot_AnimationStyles:GetAnimationStylesChoices(),
							arg = {"normal", k},
						},
						sticky = {
							type = 'select',
							name = L["Sticky"],
							desc = L["Animation style for sticky texts."],
							get = getAnimationStyle,
							set = setAnimationStyle,
							values = Parrot_AnimationStyles:GetAnimationStylesChoices(),
							arg = {"sticky", k},
						},
					}
				},
				positionX = {
					type = 'range',
					name = L["Position: horizontal"],
					desc = L["The position of the box across the screen"],
					get = getPositionX,
					set = setPositionX,
					min = math.floor(-GetScreenWidth()/GetScreenHeight()*768 / 0.64 / 2 / 10) * 10,
					max = math.ceil(GetScreenWidth()/GetScreenHeight()*768 / 0.64 / 2 / 10) * 10,
					step = 1,
					bigStep = 10,
					arg = k,
				},
				positionY = {
					type = 'range',
					name = L["Position: vertical"],
					desc = L["The position of the box up-and-down the screen"],
					get = getPositionY,
					set = setPositionY,
					min = math.floor(-768 / 0.64 / 2 / 10) * 10,
					max = math.ceil(768 / 0.64 / 2 / 10) * 10,
					step = 1,
					bigStep = 10,
					arg = k,
				},
				size = {
					type = 'range',
					name = L["Size"],
					desc = L["How large of an area to scroll."],
					get = getSize,
					set = setSize,
					min = 50,
					max = 800,
					step = 1,
					bigStep = 10,
					arg = k,
				},
				speed = {
					type = 'group',
					inline = true,
					name = L["Scrolling speed"],
					desc = L["How fast the text scrolls by."],
					args = {
						normal = {
							type = 'range',
							name = L["Normal"],
							desc = L["Seconds for the text to complete the whole cycle, i.e. larger numbers means slower."],
							min = 1,
							max = 20,
							step = 0.1,
							bigStep = 1,
							get = getSpeed,
							set = setSpeed,
							arg = {"normal", k},
						},
						sticky = {
							type = 'range',
							name = L["Sticky"],
							desc = L["Seconds for the text to complete the whole cycle, i.e. larger numbers means slower."],
							min = 1,
							max = 20,
							step = 0.1,
							bigStep = 1,
							get = getSpeed,
							set = setSpeed,
							arg = {"sticky", k},
						},
					}
				},
				font = {
					type = 'group',
					inline = true,
					name = L["Custom font"],
					args = {
						fontface = {
							type = 'select',
							name = L["Normal font face"],
							values = Parrot.fontWithInheritValues,
							get = getFontFace,
							set = setFontFace,
							itemControl = "DDI-Font",
							arg = {"normal", k},
							order = 1,
						},
						fontSizeInherit = {
							type = 'toggle',
							name = L["Normal inherit font size"],
							get = getFontSizeInherit,
							set = setFontSizeInherit,
							arg = {"normal", k},
							order = 2,
						},
						fontSize = {
							type = 'range',
							name = L["Normal font size"],
							min = 8,
							max = 48,
							step = 1,
							get = getFontSize,
							set = setFontSize,
							disabled = getFontSizeInherit,
							arg = {"normal", k},
							order = 3,
						},
						fontOutline = {
							type = 'select',
							name = L["Normal font outline"],
							get = getFontOutline,
							set = setFontOutline,
							values = fontOutlineChoices,
							arg = {"normal", k},
							order = 4,
						},
						fontShadow = {
							type = 'select',
							name = L["Normal font shadow"],
							get = getFontShadow,
							set = setFontShadow,
							values = fontShadowChoices,
							arg = {"normal", k},
							order = 5,
						},
						sep = {
							type = "description",
							name = "",
							order = 6,
						},
						stickyfontface = {
							type = 'select',
							name = L["Sticky font face"],
							values = Parrot.fontWithInheritValues,
							get = getFontFace,
							set = setFontFace,
							itemControl = "DDI-Font",
							arg = {"sticky", k},
							order = 7,
						},
						stickyfontSizeInherit = {
							type = 'toggle',
							name = L["Sticky inherit font size"],
							get = getFontSizeInherit,
							set = setFontSizeInherit,
							arg = {"sticky", k},
							order = 8,
						},
						stickyfontSize = {
							type = 'range',
							name = L["Sticky font size"],
							min = 8,
							max = 48,
							step = 1,
							get = getFontSize,
							set = setFontSize,
							disabled = getFontSizeInherit,
							arg = {"sticky", k},
							order = 9,
						},
						stickyfontOutline = {
							type = 'select',
							name = L["Sticky font outline"],
							get = getFontOutline,
							set = setFontOutline,
							values = fontOutlineChoices,
							arg = {"sticky", k},
							order = 10,
						},
						stickyfontShadow = {
							type = 'select',
							name = L["Sticky font shadow"],
							get = getFontShadow,
							set = setFontShadow,
							values = fontShadowChoices,
							arg = {"sticky", k},
							order = 11,
						},
					}
				}
			},
			order = -100,
		}
		scrollAreas_opt.args[tostring(v)] = opt
	end

	scrollAreas_opt = {
		type = 'group',
		name = L["Scroll areas"],
		desc = L["Options regarding scroll areas."],
		disabled = function()
			return not self:IsEnabled()
		end,
		order = 5,
		args = {
			config = {
				type = 'toggle',
				name = L["Configuration mode"],
				desc = L["Enter configuration mode, allowing you to move around the scroll areas and see them in action."],
				width = 1.5,
				order = 1,
				get = function()
					return configMode
				end,
				set = function(info, value) setConfigMode(value) end,
			},
			new = {
				type = 'execute',
				name = L["New scroll area"],
				desc = L["Add a new scroll area."],
				order = 2,
				func = function()
					local shouldConfig = configMode
					if shouldConfig then
						setConfigMode(false)
					end
					scrollAreas[L["New scroll area"]] = {
						animationStyle = "Fountain",
						direction = Parrot_AnimationStyles:GetAnimationStyleDefaultDirection("Fountain"),
						stickyAnimationStyle = "Impact",
						stickyDirection = Parrot_AnimationStyles:GetAnimationStyleDefaultDirection("Impact"),
						size = 180,
						xOffset = 0,
						yOffset = 0,
						anchorMode = "SCREEN",
					}
					rebuildChoices()
					makeOption(L["New scroll area"])
					scrollAreas_opt.args[tostring(scrollAreas[L["New scroll area"]])].order = -110
					if shouldConfig then
						setConfigMode(true)
					end
				end,
				disabled = function()
					return scrollAreas[L["New scroll area"]]
				end
			}
		},
	}
	Parrot:AddOption('scrollAreas', scrollAreas_opt)

	for k, v in next, scrollAreas do
		makeOption(k)
		if k == L["New scroll area"] then
			scrollAreas_opt.args[tostring(v)].order = -110
		end
	end
end
