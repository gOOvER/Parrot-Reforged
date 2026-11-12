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

local elvBackdropCache

function UIStyle.GetElvUI()
	local elv = _G.ElvUI
	if type(elv) ~= "table" then
		return nil, nil
	end
	local E = elv[1]
	if type(E) ~= "table" then
		return nil, nil
	end
	local okS, S = pcall(E.GetModule, E, "Skins", true)
	return E, (okS and S or nil)
end

function UIStyle.GetMult()
	local E = UIStyle.GetElvUI()
	local mult = E and tonumber(E.mult)
	if mult and mult > 0 then
		return mult
	end
	return 1
end

local function GetActiveBackdrop()
	local E = UIStyle.GetElvUI()
	if E and tonumber(E.mult) and E.mult > 0 then
		if not elvBackdropCache or elvBackdropCache.edgeSize ~= E.mult then
			elvBackdropCache = {
				bgFile = (E.Media and E.Media.Textures and E.Media.Textures.White8x8) or "Interface\\Buttons\\WHITE8X8",
				edgeFile = (E.Media and E.Media.Textures and E.Media.Textures.White8x8) or "Interface\\Buttons\\WHITE8X8",
				tile = false,
				tileSize = 0,
				edgeSize = E.mult,
				insets = { left = 0, right = 0, top = 0, bottom = 0 },
			}
		end
		return elvBackdropCache
	end
	return UIStyle.BACKDROP_BOX
end

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
	local E = UIStyle.GetElvUI()
	local preferredFont = (E and E.media and E.media.normFont) or fs:GetFont() or STANDARD_FONT
	pcall(fs.SetFont, fs, preferredFont, sz, flags or "")
end

function UIStyle.ApplyBox(frame, bgOverride, borderOverride)
	if not frame or not frame.SetBackdrop then return end
	frame:SetBackdrop(GetActiveBackdrop())
	local E = UIStyle.GetElvUI()
	local bg = bgOverride or UIStyle.COLORS.boxBg
	local br = borderOverride
	if not br then
		if E and E.media and type(E.media.bordercolor) == "table" then
			br = { E.media.bordercolor[1] or 0.2, E.media.bordercolor[2] or 0.2, E.media.bordercolor[3] or 0.2, 1 }
		else
			br = UIStyle.COLORS.boxBorder
		end
	end
	frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
	frame:SetBackdropBorderColor(br[1], br[2], br[3], br[4] or 1)
end

function UIStyle.ApplyElvUIWindowSkin(frame)
	if not frame then return false end
	local E = UIStyle.GetElvUI()
	if not E then
		UIStyle.ApplyBox(frame, UIStyle.COLORS.mainBg, UIStyle.COLORS.mainBorder)
		return false
	end

	if frame.SetTemplate then
		pcall(frame.SetTemplate, frame, "Transparent")
	else
		UIStyle.ApplyBox(frame, UIStyle.COLORS.mainBg, nil)
	end

	-- ElvUI_WindTools outer shadow support if installed
	local wt = _G.ElvUI_WindTools
	local W = type(wt) == "table" and wt[1]
	if W and W.Modules and W.Modules.Skins and W.Modules.Skins.CreateShadow then
		pcall(W.Modules.Skins.CreateShadow, W.Modules.Skins, frame)
	end

	-- ElvUI_BenikUI style accent if installed
	local bui = _G.ElvUI_BenikUI
	local BUI = type(bui) == "table" and bui[1]
	if BUI and frame.BUIStyle then
		pcall(frame.BUIStyle, frame, "Outside")
	end

	return true
end

function UIStyle.StyleTooltip(tip)
	if not tip then return end
	local E = UIStyle.GetElvUI()
	if E and E.private and E.private.skins and E.private.skins.blizzard
		and E.private.skins.blizzard.enable and E.private.skins.blizzard.tooltip then
		-- If ElvUI_WindTools already hooks LibQTip, let it handle SetStyle/shadow cleanly;
		-- otherwise apply ElvUI's Tooltip:SetStyle directly so borders & fonts match ElvUI.
		local wt = _G.ElvUI_WindTools
		local W = type(wt) == "table" and wt[1]
		local wtHandlesQTip = W and E.private.WT and E.private.WT.skins
			and E.private.WT.skins.libraries and E.private.WT.skins.libraries.libQTip
		if not wtHandlesQTip then
			local okTT, TT = pcall(E.GetModule, E, "Tooltip", true)
			if okTT and TT and TT.SetStyle then
				pcall(TT.SetStyle, TT, tip)
				return
			elseif tip.SetTemplate then
				pcall(tip.SetTemplate, tip, "Transparent")
				return
			end
		else
			return
		end
	end
	if tip.SetBackdrop then
		UIStyle.ApplyBox(tip, { 0.06, 0.06, 0.09, 0.96 }, { 0.72, 0.58, 0.18, 0.95 })
	end
end

function UIStyle.CreateButton(parent, label, width, height)
	local btn = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	btn:SetSize(width or 110, height or 24)
	UIStyle.ApplyBox(btn, UIStyle.COLORS.btnBg, nil)
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
			UIStyle.ApplyBox(self, UIStyle.COLORS.btnBg, nil)
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
			UIStyle.ApplyBox(self, UIStyle.COLORS.btnBg, nil)
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

	local E = UIStyle.GetElvUI()
	local texCoords = (E and E.TexCoords) or { 0.08, 0.92, 0.08, 0.92 }

	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetSize(18, 18)
	icon:SetPoint("LEFT", 10, 0)
	icon:SetTexture(iconPath or "Interface\\Icons\\INV_Misc_QuestionMark")
	icon:SetTexCoord(unpack(texCoords))
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
			UIStyle.ApplyBox(self, { 0.07, 0.07, 0.09, 0.45 }, { 0.16, 0.16, 0.20, 0.45 })
			self.accentBar:Hide()
			self.text:SetTextColor(0.84, 0.84, 0.88)
		end
	end

	btn:SetScript("OnEnter", function(self)
		if not self.isSelected then
			UIStyle.ApplyBox(self, UIStyle.COLORS.btnHover, nil)
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
	local mult = UIStyle.GetMult()
	local header = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
	header:SetPoint("TOPLEFT", mult, -mult)
	header:SetPoint("TOPRIGHT", -mult, -mult)
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

	local E = UIStyle.GetElvUI()
	local texCoords = (E and E.TexCoords) or { 0.08, 0.92, 0.08, 0.92 }

	local logo = header:CreateTexture(nil, "ARTWORK")
	logo:SetSize(20, 20)
	logo:SetPoint("LEFT", 10, 0)
	logo:SetTexture("Interface\\Icons\\Spell_Nature_ForceOfNature")
	logo:SetTexCoord(unpack(texCoords))

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
	goldLine:SetHeight(mult)
	goldLine:SetPoint("BOTTOMLEFT", 0, 0)
	goldLine:SetPoint("BOTTOMRIGHT", 0, 0)
	goldLine:SetColorTexture(0.78, 0.62, 0.16, 0.85)

	header.title = title
	header.subtitle = sub
	header.closeBtn = closeBtn
	return header
end
