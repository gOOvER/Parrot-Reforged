local _, ns = ...
local Parrot = ns.addon

local UIStyle = {}
ns.UIStyle = UIStyle

local STANDARD_FONT = _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

UIStyle.BACKDROP_BOX = {
	bgFile = "Interface\\Buttons\\WHITE8X8",
	edgeFile = "Interface\\Buttons\\WHITE8X8",
	tile = false,
	tileSize = 0,
	edgeSize = 1,
	insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

UIStyle.COLORS = {
	mainBg     = { 0.06, 0.06, 0.08, 0.96 },
	mainBorder = { 0.48, 0.39, 0.16, 0.95 },
	headerBg   = { 0.11, 0.10, 0.09, 0.98 },
	sidebarBg  = { 0.04, 0.04, 0.06, 0.92 },
	boxBg      = { 0.08, 0.08, 0.10, 0.88 },
	boxBorder  = { 0.25, 0.25, 0.30, 0.85 },
	footerBg   = { 0.08, 0.08, 0.10, 0.95 },
	gold       = { 1.00, 0.82, 0.00, 1.00 },
	goldMuted  = { 0.85, 0.68, 0.18, 0.95 },
	text       = { 0.92, 0.92, 0.94, 1.00 },
	textMuted  = { 0.62, 0.62, 0.68, 1.00 },
	btnBg      = { 0.13, 0.13, 0.16, 0.92 },
	btnHover   = { 0.20, 0.18, 0.12, 0.96 },
	btnActive  = { 0.24, 0.19, 0.08, 0.96 },
}

UIStyle.FONT_MIN = 10
UIStyle.FONT_MAX = 18
UIStyle.FONT_DEFAULT = 13

local fontListeners = {}

function UIStyle.GetFontSize()
	local db = Parrot and Parrot.db and Parrot.db.profile
	local sz = db and tonumber(db.uiFontSize) or UIStyle.FONT_DEFAULT
	if sz < UIStyle.FONT_MIN then sz = UIStyle.FONT_MIN end
	if sz > UIStyle.FONT_MAX then sz = UIStyle.FONT_MAX end
	return sz
end

function UIStyle.SetFontSize(sz)
	sz = math.max(UIStyle.FONT_MIN, math.min(UIStyle.FONT_MAX, math.floor((tonumber(sz) or UIStyle.FONT_DEFAULT) + 0.5)))
	if Parrot and Parrot.db and Parrot.db.profile then
		Parrot.db.profile.uiFontSize = sz
	end
	for i = 1, #fontListeners do
		pcall(fontListeners[i], sz)
	end
end

function UIStyle.RegisterFontListener(fn)
	if type(fn) == "function" then
		fontListeners[#fontListeners + 1] = fn
	end
end

function UIStyle.ApplyFont(fs, delta, flags)
	if not fs or not fs.SetFont then return end
	local sz = math.max(9, UIStyle.GetFontSize() + (delta or 0))
	local curFont = fs:GetFont()
	fs:SetFont(curFont or STANDARD_FONT, sz, flags or "")
end

function UIStyle.ApplyBox(frame, bgOverride, borderOverride)
	if not frame or not frame.SetBackdrop then return end
	frame:SetBackdrop(UIStyle.BACKDROP_BOX)
	local bg = bgOverride or UIStyle.COLORS.boxBg
	local br = borderOverride or UIStyle.COLORS.boxBorder
	frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
	frame:SetBackdropBorderColor(br[1], br[2], br[3], br[4] or 1)
end

function UIStyle.CreateButton(parent, label, width, height)
	local btn = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	btn:SetSize(width or 110, height or 24)
	UIStyle.ApplyBox(btn, UIStyle.COLORS.btnBg, UIStyle.COLORS.boxBorder)
	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	fs:SetPoint("CENTER", 0, 0)
	fs:SetTextColor(0.95, 0.85, 0.50)
	fs:SetText(label or "")
	UIStyle.ApplyFont(fs, -1)
	btn.text = fs

	UIStyle.RegisterFontListener(function()
		UIStyle.ApplyFont(fs, -1)
	end)

	btn:SetScript("OnEnter", function(self)
		if self.isActive then
			UIStyle.ApplyBox(self, UIStyle.COLORS.btnActive, UIStyle.COLORS.gold)
		else
			UIStyle.ApplyBox(self, UIStyle.COLORS.btnHover, UIStyle.COLORS.goldMuted)
		end
		if self.tooltipText and GameTooltip then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			if self.tooltipTitle then
				GameTooltip:AddLine(self.tooltipTitle, 1, 0.82, 0)
			end
			GameTooltip:AddLine(self.tooltipText, 0.9, 0.9, 0.9, true)
			GameTooltip:Show()
		end
	end)

	btn:SetScript("OnLeave", function(self)
		if self.isActive then
			UIStyle.ApplyBox(self, UIStyle.COLORS.btnActive, UIStyle.COLORS.goldMuted)
		else
			UIStyle.ApplyBox(self, UIStyle.COLORS.btnBg, UIStyle.COLORS.boxBorder)
		end
		if self.tooltipText and GameTooltip then
			GameTooltip:Hide()
		end
	end)

	function btn:SetActiveState(active)
		self.isActive = not not active
		if self.isActive then
			UIStyle.ApplyBox(self, UIStyle.COLORS.btnActive, UIStyle.COLORS.goldMuted)
			self.text:SetTextColor(1, 0.88, 0.25)
		else
			UIStyle.ApplyBox(self, UIStyle.COLORS.btnBg, UIStyle.COLORS.boxBorder)
			self.text:SetTextColor(0.92, 0.84, 0.55)
		end
	end

	return btn
end

function UIStyle.CreateNavButton(parent, label, iconPath, height)
	local btn = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	btn:SetHeight(height or 32)
	UIStyle.ApplyBox(btn, { 0, 0, 0, 0 }, { 0, 0, 0, 0 })

	local bar = btn:CreateTexture(nil, "OVERLAY")
	bar:SetWidth(3)
	bar:SetPoint("TOPLEFT", 0, -2)
	bar:SetPoint("BOTTOMLEFT", 0, 2)
	bar:SetColorTexture(1.0, 0.82, 0.0, 1.0)
	bar:Hide()
	btn.accentBar = bar

	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetSize(18, 18)
	icon:SetPoint("LEFT", 10, 0)
	icon:SetTexture(iconPath or "Interface\\Icons\\INV_Misc_QuestionMark")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	btn.icon = icon

	local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	fs:SetPoint("LEFT", icon, "RIGHT", 8, 0)
	fs:SetPoint("RIGHT", -8, 0)
	fs:SetJustifyH("LEFT")
	fs:SetWordWrap(false)
	fs:SetText(label or "")
	UIStyle.ApplyFont(fs, 0)
	btn.text = fs

	UIStyle.RegisterFontListener(function()
		UIStyle.ApplyFont(fs, 0)
	end)

	function btn:SetSelected(selected)
		self.isSelected = not not selected
		if self.isSelected then
			UIStyle.ApplyBox(self, UIStyle.COLORS.btnActive, UIStyle.COLORS.goldMuted)
			self.accentBar:Show()
			self.text:SetTextColor(1.0, 0.86, 0.18)
		else
			UIStyle.ApplyBox(self, { 0.07, 0.07, 0.09, 0.45 }, { 0.16, 0.16, 0.20, 0.55 })
			self.accentBar:Hide()
			self.text:SetTextColor(0.84, 0.84, 0.88)
		end
	end

	btn:SetScript("OnEnter", function(self)
		if not self.isSelected then
			UIStyle.ApplyBox(self, UIStyle.COLORS.btnHover, UIStyle.COLORS.boxBorder)
			self.text:SetTextColor(1.0, 0.94, 0.72)
		end
	end)

	btn:SetScript("OnLeave", function(self)
		self:SetSelected(self.isSelected)
	end)

	btn:SetSelected(false)
	return btn
end

function UIStyle.CreateHeader(frame, titleText, subtitleText, onClose)
	local header = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
	header:SetPoint("TOPLEFT", 1, -1)
	header:SetPoint("TOPRIGHT", -1, -1)
	header:SetHeight(36)
	UIStyle.ApplyBox(header, UIStyle.COLORS.headerBg, { 0.35, 0.28, 0.12, 0.90 })
	header:EnableMouse(true)
	header:RegisterForDrag("LeftButton")
	header:SetScript("OnDragStart", function()
		if frame:IsMovable() then
			frame:StartMoving()
		end
	end)
	header:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		if frame.SaveWindowPosition then
			frame:SaveWindowPosition()
		end
	end)

	local logo = header:CreateTexture(nil, "ARTWORK")
	logo:SetSize(20, 20)
	logo:SetPoint("LEFT", 10, 0)
	logo:SetTexture("Interface\\Icons\\Spell_Nature_ForceOfNature")
	logo:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("LEFT", logo, "RIGHT", 8, 0)
	title:SetTextColor(1.0, 0.82, 0.0)
	title:SetText(titleText or "Parrot Reforged")
	UIStyle.ApplyFont(title, 2)

	local sub = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	sub:SetPoint("LEFT", title, "RIGHT", 10, -1)
	sub:SetTextColor(0.65, 0.65, 0.72)
	sub:SetText(subtitleText or "")
	UIStyle.ApplyFont(sub, -2)

	local closeBtn = UIStyle.CreateButton(header, "×", 24, 22)
	closeBtn:SetPoint("RIGHT", -6, 0)
	closeBtn.text:SetTextColor(0.95, 0.55, 0.55)
	closeBtn:SetScript("OnClick", function()
		if onClose then
			onClose()
		else
			frame:Hide()
		end
	end)

	local btnPlus = UIStyle.CreateButton(header, "A+", 26, 20)
	btnPlus:SetPoint("RIGHT", closeBtn, "LEFT", -8, 0)

	local lblSize = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	lblSize:SetPoint("RIGHT", btnPlus, "LEFT", -5, 0)
	lblSize:SetTextColor(0.85, 0.76, 0.45)
	lblSize:SetText(UIStyle.GetFontSize() .. "pt")

	local btnMinus = UIStyle.CreateButton(header, "A-", 26, 20)
	btnMinus:SetPoint("RIGHT", lblSize, "LEFT", -5, 0)

	btnMinus:SetScript("OnClick", function()
		UIStyle.SetFontSize(UIStyle.GetFontSize() - 1)
	end)
	btnPlus:SetScript("OnClick", function()
		UIStyle.SetFontSize(UIStyle.GetFontSize() + 1)
	end)

	UIStyle.RegisterFontListener(function(sz)
		lblSize:SetText(sz .. "pt")
		UIStyle.ApplyFont(title, 2)
		UIStyle.ApplyFont(sub, -2)
	end)

	local goldLine = header:CreateTexture(nil, "OVERLAY")
	goldLine:SetHeight(1)
	goldLine:SetPoint("BOTTOMLEFT", 0, 0)
	goldLine:SetPoint("BOTTOMRIGHT", 0, 0)
	goldLine:SetColorTexture(0.78, 0.62, 0.16, 0.85)

	header.title = title
	header.subtitle = sub
	header.closeBtn = closeBtn
	return header
end

