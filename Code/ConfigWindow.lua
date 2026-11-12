local _, ns = ...
local Parrot = ns.addon
local UIStyle = ns.UIStyle
local L = LibStub("AceLocale-3.0"):GetLocale("Parrot")

local AceGUI = LibStub("AceGUI-3.0", true)
local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
local LibWindow = LibStub("LibWindow-1.1", true)

-- Register a clean full-bleed AceGUI container so AceConfigDialog automatically
-- wraps flat groups in a ScrollFrame while rendering TreeGroup/TabGroup sections natively.
if AceGUI and (AceGUI:GetWidgetVersion("ParrotConfigHost") or 0) < 1 then
	local function Constructor()
		local frame = CreateFrame("Frame", nil, UIParent)
		frame:Hide()
		local content = CreateFrame("Frame", nil, frame)
		content:SetPoint("TOPLEFT", 0, 0)
		content:SetPoint("BOTTOMRIGHT", 0, 0)

		local widget = {
			frame = frame,
			content = content,
			type = "ParrotConfigHost",
			OnAcquire = function(self)
				self.frame:Show()
			end,
			OnRelease = function(self)
				self.frame:ClearAllPoints()
				self.frame:Hide()
			end,
			OnWidthSet = function(self, width)
				self.content:SetWidth(width)
				self.content.width = width
			end,
			OnHeightSet = function(self, height)
				self.content:SetHeight(height)
				self.content.height = height
			end,
			SetStatusTable = function() end,
			SetTitle = function() end,
		}
		return AceGUI:RegisterAsContainer(widget)
	end
	AceGUI:RegisterWidgetType("ParrotConfigHost", Constructor, 1)
end

local ConfigWindow = {}
ns.ConfigWindow = ConfigWindow

local mainFrame
local hostWidget
local navButtons = {}
local activeSection = "general"
local refreshPending = false
local refreshWatcher = CreateFrame("Frame")
refreshWatcher:Hide()

local NAV_ITEMS = {
	{ key = "general",      labelKey = "General",         icon = "Interface\\Icons\\INV_Gizmo_02" },
	{ key = "scrollAreas",  labelKey = "Scroll areas",    icon = "Interface\\Icons\\Ability_Hunter_EagleEye" },
	{ key = "events",       labelKey = "Events",          icon = "Interface\\Icons\\Spell_Fire_FlameBolt" },
	{ key = "triggers",     labelKey = "Triggers",        icon = "Interface\\Icons\\Spell_Nature_Lightning" },
	{ key = "cooldowns",    labelKey = "Cooldowns",       icon = "Interface\\Icons\\Spell_Holy_BorrowedTime" },
	{ key = "suppressions", labelKey = "Suppressions",    icon = "Interface\\Icons\\Spell_Holy_Silence" },
	{ key = "sharing",      labelKey = "Import / Export", icon = "Interface\\Icons\\INV_Scroll_03" },
	{ key = "profiles",     labelKey = "Profiles",        icon = "Interface\\Icons\\INV_Misc_Book_09" },
}

local function UpdateFooterStates()
	if not mainFrame then return end
	if mainFrame.profileBadge and Parrot.db then
		local prof = Parrot.db:GetCurrentProfile() or "Default"
		local modeTag = Parrot.combatLogBlocked and ("  |cffffaa33[" .. L["Fallback Mode"] .. "]|r") or ""
		mainFrame.profileBadge:SetText("|cff888894" .. L["Profile"] .. ":|r |cffffd100" .. prof .. "|r" .. modeTag)
	end
	if mainFrame.btnAnchors then
		local unlocked = Parrot.GetConfigMode and Parrot:GetConfigMode()
		mainFrame.btnAnchors.text:SetText(unlocked and L["Lock Anchors"] or L["Unlock Anchors"])
		mainFrame.btnAnchors:SetActiveState(unlocked)
	end
	if mainFrame.btnToggle then
		local enabled = Parrot:IsEnabled()
		mainFrame.btnToggle.text:SetText(enabled and ("|cff55ff55" .. L["Enabled"] .. "|r") or ("|cffff5555" .. L["Disabled"] .. "|r"))
		mainFrame.btnToggle:SetActiveState(enabled)
	end
end

function ConfigWindow:SelectSection(sectionKey)
	if not mainFrame or not hostWidget or not AceConfigDialog then return end
	Parrot:EnsureOptionsLoaded()

	if not Parrot.options or not Parrot.options.args or not Parrot.options.args[sectionKey] then
		sectionKey = "general"
	end
	activeSection = sectionKey

	for key, btn in pairs(navButtons) do
		btn:SetSelected(key == activeSection)
	end

	local bodyW = math.max(400, (mainFrame.contentArea:GetWidth() or 700) - 16)
	local bodyH = math.max(300, (mainFrame.contentArea:GetHeight() or 540) - 16)
	hostWidget:SetWidth(bodyW)
	hostWidget:SetHeight(bodyH)

	AceConfigDialog:Open("Parrot", hostWidget, activeSection)
	UpdateFooterStates()
end

refreshWatcher:SetScript("OnUpdate", function(self)
	self:Hide()
	if not refreshPending then return end
	refreshPending = false
	if mainFrame and mainFrame:IsShown() then
		ConfigWindow:SelectSection(activeSection)
	end
end)

if AceConfigRegistry then
	AceConfigRegistry.RegisterCallback(ConfigWindow, "ConfigTableChange", function(_, appName)
		if appName == "Parrot" and mainFrame and mainFrame:IsShown() then
			refreshPending = true
			refreshWatcher:Show()
		end
	end)
end

local function CreateMainWindow()
	if mainFrame then return mainFrame end

	local f = CreateFrame("Frame", "ParrotConfigFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(960, 660)
	f:SetPoint("CENTER")
	f:SetFrameStrata("HIGH")
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	UIStyle.ApplyBox(f, UIStyle.COLORS.mainBg, UIStyle.COLORS.mainBorder)

	-- Allow closing with ESC
	if type(UISpecialFrames) == "table" then
		local found = false
		for i = 1, #UISpecialFrames do
			if UISpecialFrames[i] == "ParrotConfigFrame" then
				found = true
				break
			end
		end
		if not found then
			table.insert(UISpecialFrames, "ParrotConfigFrame")
		end
	end

	if LibWindow and Parrot.db and Parrot.db.profile then
		Parrot.db.profile.windowPos = Parrot.db.profile.windowPos or {}
		LibWindow.RegisterConfig(f, Parrot.db.profile.windowPos)
		LibWindow.RestorePosition(f)
		function f:SaveWindowPosition()
			LibWindow.SavePosition(self)
		end
	end

	local versionText = "v1.0.0"
	if C_AddOns and C_AddOns.GetAddOnMetadata then
		versionText = "v" .. (C_AddOns.GetAddOnMetadata("Parrot", "Version") or "1.0.0")
	elseif GetAddOnMetadata then
		versionText = "v" .. (GetAddOnMetadata("Parrot", "Version") or "1.0.0")
	end

	local header = UIStyle.CreateHeader(f, "Parrot Reforged", versionText, function()
		f:Hide()
	end)

	-- Footer bar with Quick Actions
	local footer = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
	footer:SetPoint("BOTTOMLEFT", 1, 1)
	footer:SetPoint("BOTTOMRIGHT", -1, 1)
	footer:SetHeight(38)
	UIStyle.ApplyBox(footer, UIStyle.COLORS.footerBg, { 0.30, 0.25, 0.12, 0.85 })

	local btnTest = UIStyle.CreateButton(footer, L["Demo Burst"], 116, 24)
	btnTest:SetPoint("LEFT", 10, 0)
	btnTest.tooltipTitle = L["Demo Burst"]
	btnTest.tooltipText = L["Fire realistic sample combat text across all scroll areas."]
	btnTest:SetScript("OnClick", function()
		Parrot:TestMessages()
	end)

	local btnAnchors = UIStyle.CreateButton(footer, L["Unlock Anchors"], 136, 24)
	btnAnchors:SetPoint("LEFT", btnTest, "RIGHT", 6, 0)
	btnAnchors.tooltipTitle = L["Unlock Anchors"]
	btnAnchors.tooltipText = L["Unlock scroll area movers with crosshair guides and 1px nudge buttons."]
	btnAnchors:SetScript("OnClick", function()
		local cur = Parrot.GetConfigMode and Parrot:GetConfigMode()
		Parrot:SetConfigMode(not cur)
		UpdateFooterStates()
	end)
	f.btnAnchors = btnAnchors

	local btnPreset = UIStyle.CreateButton(footer, L["Modern Preset"], 124, 24)
	btnPreset:SetPoint("LEFT", btnAnchors, "RIGHT", 6, 0)
	btnPreset.tooltipTitle = L["Apply Modern Style Preset"]
	btnPreset.tooltipText = L["Configures Fountain/Cascade/Impact animations, crisp outlines, crit glow, and spell-school coloring in one click."]
	btnPreset:SetScript("OnClick", function()
		local displayMod = Parrot:GetModule("Display", true)
		if displayMod and displayMod.ApplyModernPreset then
			displayMod:ApplyModernPreset()
			ConfigWindow:SelectSection(activeSection)
		end
	end)

	local btnToggle = UIStyle.CreateButton(footer, L["Enabled"], 98, 24)
	btnToggle:SetPoint("LEFT", btnPreset, "RIGHT", 6, 0)
	btnToggle.tooltipTitle = L["Toggle Parrot"]
	btnToggle.tooltipText = L["Enable or disable Parrot combat text output."]
	btnToggle:SetScript("OnClick", function()
		if Parrot:IsEnabled() then
			Parrot:Disable()
		else
			Parrot:Enable()
		end
		UpdateFooterStates()
		ConfigWindow:SelectSection(activeSection)
	end)
	f.btnToggle = btnToggle

	local btnClose = UIStyle.CreateButton(footer, _G.CLOSE or L["Close"], 92, 24)
	btnClose:SetPoint("RIGHT", -10, 0)
	btnClose:SetScript("OnClick", function()
		f:Hide()
	end)

	local profileBadge = footer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	profileBadge:SetPoint("RIGHT", btnClose, "LEFT", -14, 0)
	profileBadge:SetJustifyH("RIGHT")
	UIStyle.ApplyFont(profileBadge, -1)
	f.profileBadge = profileBadge

	UIStyle.RegisterFontListener(function()
		UIStyle.ApplyFont(profileBadge, -1)
	end)

	-- Left Sidebar Navigation
	local sidebar = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
	sidebar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
	sidebar:SetPoint("BOTTOMLEFT", footer, "TOPLEFT", 0, 0)
	sidebar:SetWidth(212)
	UIStyle.ApplyBox(sidebar, UIStyle.COLORS.sidebarBg, { 0.25, 0.22, 0.14, 0.85 })

	local yOff = -10
	for i = 1, #NAV_ITEMS do
		local item = NAV_ITEMS[i]
		if item.key == "sharing" then
			local sep = sidebar:CreateTexture(nil, "ARTWORK")
			sep:SetHeight(1)
			sep:SetPoint("TOPLEFT", 12, yOff - 3)
			sep:SetPoint("TOPRIGHT", -12, yOff - 3)
			sep:SetColorTexture(0.45, 0.36, 0.14, 0.55)
			yOff = yOff - 10
		end
		local navBtn = UIStyle.CreateNavButton(sidebar, L[item.labelKey] or item.labelKey, item.icon, 34)
		navBtn:SetPoint("TOPLEFT", 8, yOff)
		navBtn:SetPoint("TOPRIGHT", -8, yOff)
		navBtn:SetScript("OnClick", function()
			ConfigWindow:SelectSection(item.key)
		end)
		navButtons[item.key] = navBtn
		yOff = yOff - 38
	end

	-- Right Content Area
	local contentArea = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
	contentArea:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 0, 0)
	contentArea:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 0)
	UIStyle.ApplyBox(contentArea, { 0.05, 0.05, 0.07, 0.70 }, { 0.20, 0.20, 0.24, 0.70 })
	f.contentArea = contentArea

	hostWidget = AceGUI:Create("ParrotConfigHost")
	hostWidget.frame:SetParent(contentArea)
	hostWidget.frame:ClearAllPoints()
	hostWidget.frame:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 8, -8)
	hostWidget.frame:SetPoint("BOTTOMRIGHT", contentArea, "BOTTOMRIGHT", -8, 8)
	hostWidget.frame:Show()

	f:SetScript("OnShow", function()
		UpdateFooterStates()
	end)

	f:SetScript("OnHide", function()
		if hostWidget then
			hostWidget:ReleaseChildren()
		end
	end)

	mainFrame = f
	return f
end

function ConfigWindow:Toggle(sectionKey)
	local f = CreateMainWindow()
	if f:IsShown() and not sectionKey then
		f:Hide()
		return
	end
	f:Show()
	self:SelectSection(sectionKey or activeSection or "general")
end

function ConfigWindow:Open(sectionKey)
	local f = CreateMainWindow()
	f:Show()
	self:SelectSection(sectionKey or activeSection or "general")
end

function ConfigWindow:RefreshFooter()
	UpdateFooterStates()
end

