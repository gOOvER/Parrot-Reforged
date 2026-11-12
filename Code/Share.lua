local _, ns = ...
local Parrot = ns.addon
local module = Parrot:NewModule("Share")
local L = LibStub("AceLocale-3.0"):GetLocale("Parrot")

local AceSerializer = LibStub("AceSerializer-3.0", true)
local LibDeflate = LibStub("LibDeflate", true)
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)

local EXPORT_PREFIX_PROFILE  = "!PAR1!P!"
local EXPORT_PREFIX_TRIGGERS = "!PAR1!T!"

local NAMESPACE_NAMES = {
	"Display",
	"ScrollAreas",
	"CombatEvents",
	"Triggers",
	"Cooldowns",
	"Suppressions",
}

local lastExportBuffer = ""
local lastImportBuffer = ""
local lastStatusMessage = ""

local function deepCopy(val)
	if type(val) ~= "table" then
		return val
	end
	local out = {}
	for k, v in next, val do
		out[deepCopy(k)] = deepCopy(v)
	end
	return out
end

local function overwriteTable(dst, src)
	for k in next, dst do
		dst[k] = nil
	end
	for k, v in next, src do
		dst[deepCopy(k)] = deepCopy(v)
	end
end

function module:ExportProfile()
	if not AceSerializer or not LibDeflate then
		return nil, L["Compression libraries not loaded."]
	end

	local payload = {
		v = 1,
		kind = "profile",
		core = deepCopy(Parrot.db.profile),
		namespaces = {},
	}
	if payload.core then
		payload.core.windowPos = nil
	end

	for i = 1, #NAMESPACE_NAMES do
		local nsName = NAMESPACE_NAMES[i]
		local mod = Parrot:GetModule(nsName, true)
		if mod and mod.db and mod.db.profile then
			payload.namespaces[nsName] = deepCopy(mod.db.profile)
		end
	end

	local serialized = AceSerializer:Serialize(payload)
	local compressed = LibDeflate:CompressDeflate(serialized, { level = 6 })
	local encoded = compressed and LibDeflate:EncodeForPrint(compressed)
	if not encoded then
		return nil, L["Failed to encode export string."]
	end
	return EXPORT_PREFIX_PROFILE .. encoded
end

function module:ExportCustomTriggers()
	if not AceSerializer or not LibDeflate then
		return nil, L["Compression libraries not loaded."]
	end

	local trigMod = Parrot:GetModule("Triggers", true)
	local triggers2 = trigMod and trigMod.db and trigMod.db.profile and trigMod.db.profile.triggers2
	local customTriggers = {}
	local count = 0

	if type(triggers2) == "table" then
		for id, trig in next, triggers2 do
			-- Custom user triggers use IDs <= 1000 (built-in class triggers start above 1000)
			if type(id) == "number" and id <= 1000 and type(trig) == "table" then
				customTriggers[#customTriggers + 1] = deepCopy(trig)
				count = count + 1
			end
		end
	end

	local payload = {
		v = 1,
		kind = "triggers",
		triggers = customTriggers,
		autoProcs = trigMod and trigMod.db and trigMod.db.profile and trigMod.db.profile.autoProcs,
	}

	local serialized = AceSerializer:Serialize(payload)
	local compressed = LibDeflate:CompressDeflate(serialized, { level = 6 })
	local encoded = compressed and LibDeflate:EncodeForPrint(compressed)
	if not encoded then
		return nil, L["Failed to encode export string."]
	end
	return EXPORT_PREFIX_TRIGGERS .. encoded, count
end

function module:ImportString(raw)
	if not AceSerializer or not LibDeflate then
		return false, L["Compression libraries not loaded."]
	end
	if type(raw) ~= "string" then
		return false, L["Import string is empty."]
	end

	local trimmed = raw:gsub("^%s+", ""):gsub("%s+$", "")
	if trimmed == "" then
		return false, L["Import string is empty."]
	end

	local encoded
	if trimmed:sub(1, #EXPORT_PREFIX_PROFILE) == EXPORT_PREFIX_PROFILE then
		encoded = trimmed:sub(#EXPORT_PREFIX_PROFILE + 1)
	elseif trimmed:sub(1, #EXPORT_PREFIX_TRIGGERS) == EXPORT_PREFIX_TRIGGERS then
		encoded = trimmed:sub(#EXPORT_PREFIX_TRIGGERS + 1)
	else
		return false, L["Invalid Parrot export string (expected !PAR1! header)."]
	end

	local decoded = LibDeflate:DecodeForPrint(encoded)
	if not decoded then
		return false, L["Corrupted export string (decode failed)."]
	end

	local decompressed = LibDeflate:DecompressDeflate(decoded)
	if not decompressed then
		return false, L["Corrupted export string (decompression failed)."]
	end

	local ok, data = AceSerializer:Deserialize(decompressed)
	if not ok or type(data) ~= "table" then
		return false, L["Corrupted export string (deserialize failed)."]
	end

	if data.kind == "profile" then
		if type(data.core) == "table" then
			local savedWinPos = Parrot.db.profile.windowPos
			overwriteTable(Parrot.db.profile, data.core)
			Parrot.db.profile.windowPos = savedWinPos
		end
		if type(data.namespaces) == "table" then
			for i = 1, #NAMESPACE_NAMES do
				local nsName = NAMESPACE_NAMES[i]
				local srcNs = data.namespaces[nsName]
				local mod = Parrot:GetModule(nsName, true)
				if type(srcNs) == "table" and mod and mod.db and mod.db.profile then
					overwriteTable(mod.db.profile, srcNs)
				end
			end
		end
		Parrot:OnProfileChanged("OnProfileCopied", Parrot.db)
		if AceConfigRegistry then
			AceConfigRegistry:NotifyChange("Parrot")
		end
		return true, L["Full profile imported successfully!"]
	elseif data.kind == "triggers" then
		local trigMod = Parrot:GetModule("Triggers", true)
		if not trigMod or not trigMod.db or not trigMod.db.profile then
			return false, L["Triggers module is not available."]
		end
		trigMod.db.profile.triggers2 = trigMod.db.profile.triggers2 or {}
		local dst = trigMod.db.profile.triggers2
		local nextId = 1
		for id in next, dst do
			if type(id) == "number" and id <= 1000 and id >= nextId then
				nextId = id + 1
			end
		end
		local importedCount = 0
		if type(data.triggers) == "table" then
			for i = 1, #data.triggers do
				local trig = data.triggers[i]
				if type(trig) == "table" and nextId <= 1000 then
					dst[nextId] = deepCopy(trig)
					nextId = nextId + 1
					importedCount = importedCount + 1
				end
			end
		end
		trigMod:OnProfileChanged()
		if AceConfigRegistry then
			AceConfigRegistry:NotifyChange("Parrot")
		end
		return true, L["Imported %d custom trigger(s)!"]:format(importedCount)
	end

	return false, L["Unknown export payload type."]
end

function module:OnOptionsCreate()
	Parrot:AddOption("sharing", {
		type = "group",
		name = L["Import / Export"],
		desc = L["Share full Parrot profiles or custom triggers via compressed strings."],
		order = 90,
		args = {
			intro = {
				type = "description",
				name = L["Export your current Parrot profile or custom triggers as a compact !PAR1! string to share with friends or back up your setup."],
				fontSize = "medium",
				order = 1,
			},
			exportGroup = {
				type = "group",
				inline = true,
				name = L["Export"],
				order = 10,
				args = {
					genProfile = {
						type = "execute",
						name = L["Generate Profile String"],
						desc = L["Export all settings of the active profile (Display, Scroll Areas, Events, Triggers, Cooldowns & Suppressions)."],
						order = 1,
						func = function()
							local str, err = self:ExportProfile()
							if str then
								lastExportBuffer = str
								lastStatusMessage = "|cff33ff99" .. L["Profile export string generated. Copy it below (Ctrl+C)."] .. "|r"
							else
								lastStatusMessage = "|cffff5555" .. tostring(err) .. "|r"
							end
						end,
					},
					genTriggers = {
						type = "execute",
						name = L["Generate Custom Triggers String"],
						desc = L["Export only your custom user-created triggers so others can merge them into their own profile."],
						order = 2,
						func = function()
							local str, countOrErr = self:ExportCustomTriggers()
							if str then
								lastExportBuffer = str
								lastStatusMessage = "|cff33ff99" .. L["Exported %d custom trigger(s). Copy the string below (Ctrl+C)."]:format(tonumber(countOrErr) or 0) .. "|r"
							else
								lastStatusMessage = "|cffff5555" .. tostring(countOrErr) .. "|r"
							end
						end,
					},
					exportBox = {
						type = "input",
						multiline = 6,
						width = "full",
						name = L["Export String"],
						desc = L["Click inside, press Ctrl+A then Ctrl+C to copy."],
						order = 3,
						get = function() return lastExportBuffer end,
						set = function(_, val) lastExportBuffer = val or "" end,
					},
				},
			},
			importGroup = {
				type = "group",
				inline = true,
				name = L["Import"],
				order = 20,
				args = {
					importBox = {
						type = "input",
						multiline = 6,
						width = "full",
						name = L["Paste !PAR1! String"],
						desc = L["Paste a Parrot Reforged profile or trigger string here, then click Apply Import."],
						order = 1,
						get = function() return lastImportBuffer end,
						set = function(_, val) lastImportBuffer = val or "" end,
					},
					applyImport = {
						type = "execute",
						name = L["Apply Import"],
						desc = L["Import the pasted !PAR1! string into your current profile."],
						confirm = function()
							return lastImportBuffer:sub(1, #EXPORT_PREFIX_PROFILE) == EXPORT_PREFIX_PROFILE
						end,
						confirmText = L["Importing a full profile will overwrite settings in your currently active profile. Continue?"],
						order = 2,
						func = function()
							local ok, msg = self:ImportString(lastImportBuffer)
							if ok then
								lastImportBuffer = ""
								lastStatusMessage = "|cff33ff99" .. tostring(msg) .. "|r"
								Parrot:Print(msg)
							else
								lastStatusMessage = "|cffff5555" .. tostring(msg) .. "|r"
								Parrot:Print("|cffff5555" .. tostring(msg) .. "|r")
							end
						end,
					},
					clearImport = {
						type = "execute",
						name = L["Clear"],
						desc = L["Clear the import/export text fields."],
						order = 3,
						func = function()
							lastImportBuffer = ""
							lastExportBuffer = ""
							lastStatusMessage = ""
						end,
					},
				},
			},
			statusLine = {
				type = "description",
				name = function() return lastStatusMessage end,
				fontSize = "medium",
				order = 30,
			},
		},
	})
end

