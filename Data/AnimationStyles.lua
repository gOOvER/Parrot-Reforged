local _, ns = ...
local Parrot = ns.addon
local L = LibStub("AceLocale-3.0"):GetLocale("Parrot")
local Easing = ns.Easing

local math_max, math_min = math.max, math.min
local math_sin, math_cos, math_pi = math.sin, math.cos, math.pi
local math_pow, math_floor = math.pow, math.floor

local validPoints = {
	TOPLEFT = "TOPLEFT",
	TOP = "TOP",
	TOPRIGHT = "TOPRIGHT",
	LEFT = "LEFT",
	RIGHT = "RIGHT",
	CENTER = "CENTER",
	BOTTOMLEFT = "BOTTOMLEFT",
	BOTTOM = "BOTTOM",
	BOTTOMRIGHT = "BOTTOMRIGHT",
}

local function softProgress(frame, percent)
	if frame.smoothEasing then
		return 0.30 * Easing.OutQuad(percent) + 0.70 * percent
	end
	return percent
end

Parrot:RegisterAnimationStyle {
	-- simple vertical
	name = "Straight",
	localName = L["Straight"],
	func = function(frame, xOffset, yOffset, size, percent, direction)
		local p = softProgress(frame, percent)
		local vert, align = (";"):split(direction)
		if vert == "DOWN" then
			p = 1 - p
		end
		local y = yOffset + (p - 0.5) * size
		local x = xOffset
		frame:SetPoint(validPoints[align] or "CENTER", UIParent, "CENTER", x, y)
	end,
	defaultDirection = "DOWN;CENTER",
	directions = {
		["UP;LEFT"] = L["Up, left-aligned"],
		["UP;RIGHT"] = L["Up, right-aligned"],
		["UP;CENTER"] = L["Up, center-aligned"],
		["DOWN;LEFT"] = L["Down, left-aligned"],
		["DOWN;RIGHT"] = L["Down, right-aligned"],
		["DOWN;CENTER"] = L["Down, center-aligned"],
	},
	overlap = true,
}

Parrot:RegisterAnimationStyle {
	-- makes a parabola in the form of x = y^2 - 1
	name = "Parabola",
	localName = L["Parabola"],
	func = function(frame, xOffset, yOffset, size, percent, direction, num, max, uid)
		local p = softProgress(frame, percent)
		local vert, horiz = (";"):split(direction)
		if vert == "DOWN" then
			p = 1 - p
		end
		local xDiff = (1 - 4 * (p - 0.5) ^ 2) * size * (1 / 3)
		local point = "LEFT"
		if horiz == "LEFT" or (horiz == "ALT" and uid % 2 == 0) then
			xDiff = -xDiff
			point = "RIGHT"
		end
		local y = yOffset + (p - 0.5) * size
		local x = xOffset + xDiff
		frame:SetPoint(point, UIParent, "CENTER", x, y)
	end,
	defaultDirection = "DOWN;ALT",
	directions = {
		["UP;LEFT"] = L["Up, left"],
		["UP;RIGHT"] = L["Up, right"],
		["UP;ALT"] = L["Up, alternating"],
		["DOWN;LEFT"] = L["Down, left"],
		["DOWN;RIGHT"] = L["Down, right"],
		["DOWN;ALT"] = L["Down, alternating"],
	},
	overlap = true,
}

Parrot:RegisterAnimationStyle {
	-- makes a semicircle in the form of x = -(-y^2 + 1)^0.5
	name = "Semicircle",
	localName = L["Semicircle"],
	func = function(frame, xOffset, yOffset, size, percent, direction, num, max, uid)
		local p = softProgress(frame, percent)
		local vert, horiz = (";"):split(direction)
		local angle = (90 + 180 * p) * (math_pi / 180)
		local yDiff = (size * 0.5) * math_sin(angle)
		local xDiff = -(size * 0.5) * math_cos(angle)
		if vert == "UP" then
			yDiff = -yDiff
		end
		local point = "LEFT"
		if horiz == "LEFT" or (horiz == "ALT" and uid % 2 == 0) then
			xDiff = -xDiff
			point = "RIGHT"
		end
		local y = yOffset + yDiff
		local x = xOffset + xDiff
		frame:SetPoint(point, UIParent, "CENTER", x, y)
	end,
	defaultDirection = "DOWN;ALT",
	directions = {
		["UP;LEFT"] = L["Up, left"],
		["UP;RIGHT"] = L["Up, right"],
		["UP;ALT"] = L["Up, alternating"],
		["DOWN;LEFT"] = L["Down, left"],
		["DOWN;RIGHT"] = L["Down, right"],
		["DOWN;ALT"] = L["Down, alternating"],
	},
	overlap = true,
}

Parrot:RegisterAnimationStyle {
	-- places in the center, punches scale via hardware SetScale, and applies smooth damped tremor
	name = "Pow",
	localName = L["Pow"],
	func = function(frame, xOffset, yOffset, size, percent, direction, num, max, uid)
		local fsHeight = (frame.fontSize or 20) * 1.12
		local topDiff = (max - 1) * 0.5 * fsHeight
		local currDiff = -(num - 1) * fsHeight
		local yDiff = topDiff + currDiff
		local vert, align = (";"):split(direction)
		if vert == "DOWN" then
			yDiff = -yDiff
		end
		local y = yOffset + yDiff
		local x = xOffset

		local peak = math_max(frame.peakScale or 1.4, 1.55)
		frame.zoomScale = Easing.CritPopScale(percent, peak, 0.18)

		if percent >= 0.12 then
			if frame.smoothEasing then
				local damp = math_max(0, 1 - (percent - 0.12) / 0.65) * 1.6
				local phase = percent * 52 + (uid or 0) * 1.7
				x = x + math_sin(phase) * damp
				y = y + math_cos(phase * 0.83) * damp * 0.65
			else
				local now = GetTime()
				if not frame.nextSquiggle or frame.nextSquiggle < now then
					frame.nextSquiggle = now + 0.05
					frame.squiggleX = math.random(-1, 1)
					frame.squiggleY = math.random(-1, 1)
				end
				x = x + frame.squiggleX
				y = y + frame.squiggleY
			end
		end

		frame:SetPoint(validPoints[align] or "CENTER", UIParent, "CENTER", x, y)
	end,
	cleanup = function(frame)
		frame.nextSquiggle = nil
		frame.squiggleX = nil
		frame.squiggleY = nil
	end,
	defaultDirection = "DOWN;CENTER",
	directions = {
		["UP;LEFT"] = L["Up, left-aligned"],
		["UP;RIGHT"] = L["Up, right-aligned"],
		["UP;CENTER"] = L["Up, center-aligned"],
		["DOWN;LEFT"] = L["Down, left-aligned"],
		["DOWN;RIGHT"] = L["Down, right-aligned"],
		["DOWN;CENTER"] = L["Down, center-aligned"],
	},
}

Parrot:RegisterAnimationStyle {
	-- places in the center and punches scale cleanly without shake
	name = "Pow2",
	localName = L["Pow"] .. " 2",
	func = function(frame, xOffset, yOffset, size, percent, direction, num, max, uid)
		local fsHeight = (frame.fontSize or 20) * 1.12
		local topDiff = (max - 1) * 0.5 * fsHeight
		local currDiff = -(num - 1) * fsHeight
		local yDiff = topDiff + currDiff
		local vert, align = (";"):split(direction)
		if vert == "DOWN" then
			yDiff = -yDiff
		end
		local y = yOffset + yDiff
		local x = xOffset

		local peak = math_max(frame.peakScale or 1.4, 1.55)
		frame.zoomScale = Easing.CritPopScale(percent, peak, 0.18)

		frame:SetPoint(validPoints[align] or "CENTER", UIParent, "CENTER", x, y)
	end,
	defaultDirection = "DOWN;CENTER",
	directions = {
		["UP;LEFT"] = L["Up, left-aligned"],
		["UP;RIGHT"] = L["Up, right-aligned"],
		["UP;CENTER"] = L["Up, center-aligned"],
		["DOWN;LEFT"] = L["Down, left-aligned"],
		["DOWN;RIGHT"] = L["Down, right-aligned"],
		["DOWN;CENTER"] = L["Down, center-aligned"],
	},
}

Parrot:RegisterAnimationStyle {
	-- places in the center
	name = "Static",
	localName = L["Static"],
	func = function(frame, xOffset, yOffset, size, percent, direction, num, max, uid)
		local fsHeight = math_max(12, (frame.fontSize or 18) * 1.12)
		local maxShow = size / fsHeight
		if num > maxShow then
			frame:Hide()
			return
		end
		local topDiff = (math_min(max, maxShow) - 1) * 0.5 * fsHeight
		local currDiff = -(num - 1) * fsHeight
		local yDiff = topDiff + currDiff
		local vert, align = (";"):split(direction)
		if vert == "DOWN" then
			yDiff = -yDiff
		end
		local y = yOffset + yDiff
		local x = xOffset
		frame:SetPoint(validPoints[align] or "CENTER", UIParent, "CENTER", x, y)
	end,
	defaultDirection = "DOWN;CENTER",
	directions = {
		["UP;LEFT"] = L["Up, left-aligned"],
		["UP;RIGHT"] = L["Up, right-aligned"],
		["UP;CENTER"] = L["Up, center-aligned"],
		["DOWN;LEFT"] = L["Down, left-aligned"],
		["DOWN;RIGHT"] = L["Down, right-aligned"],
		["DOWN;CENTER"] = L["Down, center-aligned"],
	},
}

Parrot:RegisterAnimationStyle {
	-- static anchor
	name = "Static2",
	localName = L["Static"] .. " 2",
	func = function(frame, xOffset, yOffset, size, percent, direction, num, max, uid)
		local fsHeight = math_max(12, (frame.fontSize or 18) * 1.12)
		if num > (size / fsHeight) then
			frame:Hide()
			return
		end
		local yDiff = (num - 1) * fsHeight
		local vert, align = (";"):split(direction)
		if vert == "DOWN" then
			yDiff = -yDiff
		end
		local y = yOffset + yDiff
		local x = xOffset
		frame:SetPoint(validPoints[align] or "CENTER", UIParent, "CENTER", x, y)
	end,
	defaultDirection = "DOWN;CENTER",
	directions = {
		["UP;LEFT"] = L["Up, left-aligned"],
		["UP;RIGHT"] = L["Up, right-aligned"],
		["UP;CENTER"] = L["Up, center-aligned"],
		["DOWN;LEFT"] = L["Down, left-aligned"],
		["DOWN;RIGHT"] = L["Down, right-aligned"],
		["DOWN;CENTER"] = L["Down, center-aligned"],
	},
}

Parrot:RegisterAnimationStyle {
	-- makes a parabola in the form of y = (-x - 1)(-x + 0.5) + 1
	name = "Rainbow",
	localName = L["Rainbow"],
	init = function(frame)
		frame.leftRoot = 1 + (math.random() - 0.5) / 5
		frame.rightRoot = -0.5 + (math.random() - 0.5) / 5
	end,
	func = function(frame, xOffset, yOffset, size, percent, direction, num, max, uid)
		local p = softProgress(frame, percent)
		local xDiff = size * 0.5 * p
		local yDiff = size * (-16 / 9 * (p - (frame.leftRoot or 1)) * (p - (frame.rightRoot or -0.5)) - 0.5)
		local vert, horiz = (";"):split(direction)
		if vert == "UP" then
			yDiff = -yDiff
		end
		local point = "LEFT"
		if horiz == "LEFT" or (horiz == "ALT" and uid % 2 == 0) then
			xDiff = -xDiff
			point = "RIGHT"
		end
		local y = yOffset + yDiff
		local x = xOffset + xDiff
		frame:SetPoint(point, UIParent, "CENTER", x, y)
	end,
	cleanup = function(frame)
		frame.leftRoot = nil
		frame.rightRoot = nil
	end,
	overlap = false,
	defaultDirection = "DOWN;ALT",
	directions = {
		["UP;LEFT"] = L["Up, left"],
		["UP;RIGHT"] = L["Up, right"],
		["UP;ALT"] = L["Up, alternating"],
		["DOWN;LEFT"] = L["Down, left"],
		["DOWN;RIGHT"] = L["Down, right"],
		["DOWN;ALT"] = L["Down, alternating"],
	},
}

Parrot:RegisterAnimationStyle {
	-- makes a path going straight to the right/left with a random y.
	name = "Horizontal",
	localName = L["Horizontal"],
	init = function(frame)
		frame.y = math.random() - 0.5
	end,
	func = function(frame, xOffset, yOffset, size, percent, direction, num, max, uid)
		local p = softProgress(frame, percent)
		local xDiff = size * p
		local point = "LEFT"
		if direction == "LEFT" or (direction == "ALT" and uid % 2 == 0) then
			xDiff = -xDiff
			point = "RIGHT"
		end
		local y = yOffset + size * (frame.y or 0)
		local x = xOffset + xDiff
		frame:SetPoint(point, UIParent, "CENTER", x, y)
	end,
	cleanup = function(frame)
		frame.y = nil
	end,
	overlap = false,
	defaultDirection = "ALT",
	directions = {
		["LEFT"] = L["Left"],
		["RIGHT"] = L["Right"],
		["ALT"] = L["Alternating"],
	},
}

Parrot:RegisterAnimationStyle {
	-- Zoom in from the center, linger, zoom out towards the edge
	name = "Action",
	localName = L["Action"],
	init = function(frame)
		frame.startY = math.random() - 0.5
	end,
	func = function(frame, xOffset, yOffset, size, percent, direction, num, max, uid)
		local mod_percent = math_pow(percent, 6)
		local xDiff = size * mod_percent * 6
		local point = "LEFT"
		if direction == "LEFT" or (direction == "ALT" and uid % 2 == 0) then
			xDiff = -xDiff
			point = "RIGHT"
		end
		local x = xOffset + xDiff
		local y = yOffset + ((frame.startY or 0) * size)
		frame.zoomScale = math_max(0.15, math_min(percent / 0.1, 1))
		frame:SetPoint(point, UIParent, "CENTER", x, y)
	end,
	cleanup = function(frame)
		frame.startY = nil
	end,
	overlap = false,
	defaultDirection = "ALT",
	directions = {
		["LEFT"] = L["Left"],
		["RIGHT"] = L["Right"],
		["ALT"] = L["Alternating"],
	},
}

Parrot:RegisterAnimationStyle {
	-- Zoom in from the corner, linger, zoom out towards the edge
	name = "Action Sticky",
	localName = L["Action Sticky"],
	init = function(frame)
		frame.startY = math.random() - 0.5
	end,
	func = function(frame, xOffset, yOffset, size, percent, direction, num, max, uid)
		local mod_percent = math_pow(percent, 6)
		local xDiff = size * mod_percent * 6
		local point = "LEFT"
		if direction == "LEFT" or (direction == "ALT" and uid % 2 == 0) then
			xDiff = -xDiff
			point = "RIGHT"
		end
		local x = xOffset + xDiff
		local y = yOffset + ((frame.startY or 0) * size)
		frame.zoomScale = math_max(1, 1 + ((0.12 - percent) / 0.12))
		frame:SetPoint(point, UIParent, "CENTER", x, y)
	end,
	cleanup = function(frame)
		frame.startY = nil
	end,
	overlap = false,
	defaultDirection = "ALT",
	directions = {
		["LEFT"] = L["Left"],
		["RIGHT"] = L["Right"],
		["ALT"] = L["Alternating"],
	},
}

Parrot:RegisterAnimationStyle {
	name = "Angled",
	localName = L["Angled"],
	init = function(frame, xOffset, yOffset, size)
		frame.finishX = size * 0.5 * (math.random() * 0.5 + 0.75)
		frame.finishY = size * 0.5 * (math.random() * 0.5 + 0.75)
	end,
	func = function(frame, xOffset, yOffset, size, percent, direction, num, max, uid)
		local fx = frame.finishX or (size * 0.5)
		local fy = frame.finishY or (size * 0.5)
		local xDiff, yDiff
		if percent < 0.3 then
			local k = frame.smoothEasing and Easing.OutCubic(percent / 0.3) or (percent / 0.3)
			xDiff = k * fx
			yDiff = -k * fy
		elseif percent < 0.8 then
			if frame.smoothEasing then
				local damp = math_max(0, 1 - (percent - 0.3) / 0.5) * 1.2
				local phase = percent * 45 + (uid or 0)
				xDiff = fx + math_sin(phase) * damp
				yDiff = -fy + math_cos(phase * 0.9) * damp
			else
				local now = GetTime()
				if not frame.nextSquiggle or now > frame.nextSquiggle then
					frame.nextSquiggle = now + 0.05
					frame.squiggleX = math.random(-1, 1)
					frame.squiggleY = math.random(-1, 1)
				end
				xDiff = fx + frame.squiggleX
				yDiff = -fy + frame.squiggleY
			end
		else
			local k = frame.smoothEasing and Easing.InQuad((percent - 0.8) / 0.2) or ((percent - 0.8) / 0.2)
			xDiff = (k + 1) * fx
			yDiff = -(1 - k) * fy
		end

		local vert, horiz = (";"):split(direction)
		if vert == "UP" then
			yDiff = -yDiff
		end
		local point = "LEFT"
		if horiz == "LEFT" or (horiz == "ALT" and uid % 2 == 0) then
			xDiff = -xDiff
			point = "RIGHT"
		end
		local y = yOffset + yDiff
		local x = xOffset + xDiff
		frame:SetPoint(point, UIParent, "CENTER", x, y)
	end,
	cleanup = function(frame)
		frame.nextSquiggle = nil
		frame.squiggleX = nil
		frame.squiggleY = nil
		frame.finishX = nil
		frame.finishY = nil
	end,
	overlap = false,
	defaultDirection = "DOWN;ALT",
	directions = {
		["UP;LEFT"] = L["Up, left"],
		["UP;RIGHT"] = L["Up, right"],
		["UP;ALT"] = L["Up, alternating"],
		["DOWN;LEFT"] = L["Down, left"],
		["DOWN;RIGHT"] = L["Down, right"],
		["DOWN;ALT"] = L["Down, alternating"],
	},
}

Parrot:RegisterAnimationStyle {
	name = "Angled2",
	localName = L["Angled"] .. " 2",
	init = function(frame, xOffset, yOffset, size)
		frame.finishX = size * 0.5 * (math.random() * 0.5 + 0.75)
		frame.finishY = size * 0.5 * (math.random() * 0.5 + 0.75)
	end,
	func = function(frame, xOffset, yOffset, size, percent, direction, num, max, uid)
		local fx = frame.finishX or (size * 0.5)
		local fy = frame.finishY or (size * 0.5)
		local xDiff, yDiff
		if percent < 0.3 then
			local k = frame.smoothEasing and Easing.OutCubic(percent / 0.3) or (percent / 0.3)
			xDiff = k * fx
			yDiff = -k * fy
		elseif percent < 0.8 then
			xDiff = fx
			yDiff = -fy
		else
			local k = frame.smoothEasing and Easing.InQuad((percent - 0.8) / 0.2) or ((percent - 0.8) / 0.2)
			xDiff = (k + 1) * fx
			yDiff = -(1 - k) * fy
		end

		local vert, horiz = (";"):split(direction)
		if vert == "UP" then
			yDiff = -yDiff
		end
		local point = "LEFT"
		if horiz == "LEFT" or (horiz == "ALT" and uid % 2 == 0) then
			xDiff = -xDiff
			point = "RIGHT"
		end
		local y = yOffset + yDiff
		local x = xOffset + xDiff
		frame:SetPoint(point, UIParent, "CENTER", x, y)
	end,
	cleanup = function(frame)
		frame.finishX = nil
		frame.finishY = nil
	end,
	overlap = false,
	defaultDirection = "DOWN;ALT",
	directions = {
		["UP;LEFT"] = L["Up, left"],
		["UP;RIGHT"] = L["Up, right"],
		["UP;ALT"] = L["Up, alternating"],
		["DOWN;LEFT"] = L["Down, left"],
		["DOWN;RIGHT"] = L["Down, right"],
		["DOWN;ALT"] = L["Down, alternating"],
	},
}

Parrot:RegisterAnimationStyle {
	name = "Sprinkler",
	localName = L["Sprinkler"],
	init = function(frame, xOffset, yOffset, size, direction, uid)
		local dir, clock = (";"):split(direction)
		local base
		if dir == "RIGHT" then
			base = 0
		elseif dir == "UP" then
			base = 90
		elseif dir == "LEFT" then
			base = 180
		else
			base = 270
		end
		local h = math_max(12, frame.fontSize or 18)
		local slices = math_max(2, math_floor(size / h / 2))
		local diff = (uid % slices) * (120 / (slices - 1)) - 60
		if clock == "CCW" then
			diff = -diff
		end
		frame.angle = (base + diff) * (math_pi / 180)
	end,
	func = function(frame, xOffset, yOffset, size, percent, direction, num, max, uid)
		local angle = frame.angle or 0
		local cosA, sinA = math_cos(angle), math_sin(angle)
		local xDiff, yDiff
		if percent < 0.3 then
			local k = frame.smoothEasing and Easing.OutCubic(percent / 0.3) or (percent / 0.3)
			xDiff = k * size * 0.5 * cosA
			yDiff = k * size * 0.5 * sinA
		elseif percent < 0.8 then
			if frame.smoothEasing then
				local damp = math_max(0, 1 - (percent - 0.3) / 0.5)
				xDiff = size * 0.5 * cosA + math_sin(percent * 45 + uid) * damp
				yDiff = size * 0.5 * sinA + math_cos(percent * 41 + uid) * damp
			else
				local now = GetTime()
				if not frame.nextSquiggle or now > frame.nextSquiggle then
					frame.nextSquiggle = now + 0.05
					frame.squiggleX = math.random(-1, 1)
					frame.squiggleY = math.random(-1, 1)
				end
				xDiff = size * 0.5 * cosA + frame.squiggleX
				yDiff = size * 0.5 * sinA + frame.squiggleY
			end
		else
			local k = frame.smoothEasing and Easing.InQuad((percent - 0.8) / 0.2) or ((percent - 0.8) / 0.2)
			xDiff = (k + 1) * size * 0.5 * cosA
			yDiff = (k + 1) * size * 0.5 * sinA
		end

		local y = yOffset + yDiff
		local x = xOffset + xDiff
		local dir = (";"):split(direction)
		local point = "CENTER"
		if dir == "LEFT" then
			point = "RIGHT"
		elseif dir == "RIGHT" then
			point = "LEFT"
		end
		frame:SetPoint(point, UIParent, "CENTER", x, y)
	end,
	cleanup = function(frame)
		frame.nextSquiggle = nil
		frame.squiggleX = nil
		frame.squiggleY = nil
		frame.angle = nil
	end,
	overlap = false,
	defaultDirection = "UP;CCW",
	directions = {
		["UP;CW"] = L["Up, clockwise"],
		["DOWN;CW"] = L["Down, clockwise"],
		["LEFT;CW"] = L["Left, clockwise"],
		["RIGHT;CW"] = L["Right, clockwise"],
		["UP;CCW"] = L["Up, counter-clockwise"],
		["DOWN;CCW"] = L["Down, counter-clockwise"],
		["LEFT;CCW"] = L["Left, counter-clockwise"],
		["RIGHT;CCW"] = L["Right, counter-clockwise"],
	},
}

Parrot:RegisterAnimationStyle {
	name = "Sprinkler2",
	localName = L["Sprinkler"] .. " 2",
	init = function(frame, xOffset, yOffset, size, direction, uid)
		local dir, clock = (";"):split(direction)
		local base
		if dir == "RIGHT" then
			base = 0
		elseif dir == "UP" then
			base = 90
		elseif dir == "LEFT" then
			base = 180
		else
			base = 270
		end
		local h = math_max(12, frame.fontSize or 18)
		local slices = math_max(2, math_floor(size / h / 2))
		local diff = (uid % slices) * (120 / (slices - 1)) - 60
		if clock == "CCW" then
			diff = -diff
		end
		frame.angle = (base + diff) * (math_pi / 180)
	end,
	func = function(frame, xOffset, yOffset, size, percent, direction, num, max, uid)
		local angle = frame.angle or 0
		local cosA, sinA = math_cos(angle), math_sin(angle)
		local xDiff, yDiff
		if percent < 0.3 then
			local k = frame.smoothEasing and Easing.OutCubic(percent / 0.3) or (percent / 0.3)
			xDiff = k * size * 0.5 * cosA
			yDiff = k * size * 0.5 * sinA
		elseif percent < 0.8 then
			xDiff = size * 0.5 * cosA
			yDiff = size * 0.5 * sinA
		else
			local k = frame.smoothEasing and Easing.InQuad((percent - 0.8) / 0.2) or ((percent - 0.8) / 0.2)
			xDiff = (k + 1) * size * 0.5 * cosA
			yDiff = (k + 1) * size * 0.5 * sinA
		end

		local y = yOffset + yDiff
		local x = xOffset + xDiff
		local dir = (";"):split(direction)
		local point = "CENTER"
		if dir == "LEFT" then
			point = "RIGHT"
		elseif dir == "RIGHT" then
			point = "LEFT"
		end
		frame:SetPoint(point, UIParent, "CENTER", x, y)
	end,
	cleanup = function(frame)
		frame.angle = nil
	end,
	overlap = false,
	defaultDirection = "UP;CCW",
	directions = {
		["UP;CW"] = L["Up, clockwise"],
		["DOWN;CW"] = L["Down, clockwise"],
		["LEFT;CW"] = L["Left, clockwise"],
		["RIGHT;CW"] = L["Right, clockwise"],
		["UP;CCW"] = L["Up, counter-clockwise"],
		["DOWN;CCW"] = L["Down, counter-clockwise"],
		["LEFT;CCW"] = L["Left, counter-clockwise"],
		["RIGHT;CCW"] = L["Right, counter-clockwise"],
	},
}

-- ============================================================================
-- Modern Animation Styles (Parrot Reforged)
-- ============================================================================

Parrot:RegisterAnimationStyle {
	-- Modern ARPG / NameplateSCT ballistic fountain arc
	name = "Fountain",
	localName = L["Fountain"],
	init = function(frame, xOffset, yOffset, size, direction, uid)
		-- Slight organic variation per hit so rapid multi-hits fan out naturally
		frame.fountainSpreadX = 0.38 + (math.random() * 0.26)
		frame.fountainPeakY = 0.42 + (math.random() * 0.20)
	end,
	func = function(frame, xOffset, yOffset, size, percent, direction, num, max, uid)
		local vert, horiz = (";"):split(direction)
		local spreadX = (frame.fountainSpreadX or 0.5) * size
		local peakY = (frame.fountainPeakY or 0.5) * size

		-- Horizontal travel decelerates gently via OutSine
		local xProgress = Easing.OutSine(percent)
		local xDiff = spreadX * xProgress

		-- Ballistic vertical arc: launches swiftly, crests around t=0.42, falls smoothly
		local apex = 0.42
		local yNorm
		if percent <= apex then
			yNorm = Easing.OutQuad(percent / apex)
		else
			local fall = (percent - apex) / (1 - apex)
			yNorm = 1 - 1.35 * Easing.InQuad(fall)
		end
		local yDiff = peakY * yNorm

		if vert == "DOWN" then
			-- Inverted fountain (launches slightly up then cascades downward)
			yDiff = peakY * (0.28 * math_sin(percent * math_pi) - 0.95 * Easing.InQuad(percent))
		end

		local point = "CENTER"
		if horiz == "LEFT" or (horiz == "ALT" and uid % 2 == 0) then
			xDiff = -xDiff
		end

		frame:SetPoint(point, UIParent, "CENTER", xOffset + xDiff, yOffset + yDiff)
	end,
	cleanup = function(frame)
		frame.fountainSpreadX = nil
		frame.fountainPeakY = nil
	end,
	overlap = false,
	defaultDirection = "UP;ALT",
	directions = {
		["UP;ALT"] = L["Up, alternating"],
		["UP;LEFT"] = L["Up, left"],
		["UP;RIGHT"] = L["Up, right"],
		["DOWN;ALT"] = L["Down, alternating"],
		["DOWN;LEFT"] = L["Down, left"],
		["DOWN;RIGHT"] = L["Down, right"],
	},
}

Parrot:RegisterAnimationStyle {
	-- Modern crisp Sticky / Crit Impact Pop (punchy zoom, clean stacking, gentle drift, zero continuous jitter)
	name = "Impact",
	localName = L["Impact"],
	func = function(frame, xOffset, yOffset, size, percent, direction, num, max, uid)
		local fsHeight = math_max(14, (frame.fontSize or 24) * 1.18)
		local stackOffset = (num - 1) * fsHeight
		local drift = Easing.OutCubic(percent) * (size * 0.16)

		local vert, align = (";"):split(direction)
		local yDiff = stackOffset + drift
		if vert == "DOWN" then
			yDiff = -yDiff
		end

		local peak = math_max(frame.peakScale or 1.45, 1.50)
		frame.zoomScale = Easing.CritPopScale(percent, peak, 0.22)

		-- Brief crisp impact recoil in the first 100ms only
		local recoilX = 0
		if percent < 0.09 then
			local k = 1 - (percent / 0.09)
			recoilX = math_sin(percent * 90 + (uid or 0)) * 2.5 * k
		end

		frame:SetPoint(validPoints[align] or "CENTER", UIParent, "CENTER", xOffset + recoilX, yOffset + yDiff)
	end,
	overlap = false,
	defaultDirection = "UP;CENTER",
	directions = {
		["UP;CENTER"] = L["Up, center-aligned"],
		["UP;LEFT"] = L["Up, left-aligned"],
		["UP;RIGHT"] = L["Up, right-aligned"],
		["DOWN;CENTER"] = L["Down, center-aligned"],
		["DOWN;LEFT"] = L["Down, left-aligned"],
		["DOWN;RIGHT"] = L["Down, right-aligned"],
	},
}

Parrot:RegisterAnimationStyle {
	-- Smooth eased S-curve cascade, ideal for heals & DoT/HoT streams
	name = "Cascade",
	localName = L["Cascade"],
	func = function(frame, xOffset, yOffset, size, percent, direction, num, max, uid)
		local p = 0.45 * Easing.OutCubic(percent) + 0.55 * percent
		local vert, horiz = (";"):split(direction)
		if vert == "DOWN" then
			p = 1 - p
		end

		local wave = math_sin(percent * math_pi * 1.5) * (size * 0.14)
		local point = "CENTER"
		if horiz == "LEFT" or (horiz == "ALT" and uid % 2 == 0) then
			wave = -wave
			point = "RIGHT"
		elseif horiz == "RIGHT" or horiz == "ALT" then
			point = "LEFT"
		end

		local y = yOffset + (p - 0.5) * size
		local x = xOffset + wave
		frame:SetPoint(point, UIParent, "CENTER", x, y)
	end,
	overlap = true,
	defaultDirection = "UP;ALT",
	directions = {
		["UP;ALT"] = L["Up, alternating"],
		["UP;LEFT"] = L["Up, left"],
		["UP;RIGHT"] = L["Up, right"],
		["DOWN;ALT"] = L["Down, alternating"],
		["DOWN;LEFT"] = L["Down, left"],
		["DOWN;RIGHT"] = L["Down, right"],
	},
}

Parrot:RegisterAnimationStyle {
	-- Rises swiftly with OutBack bounce, lingers stationary for effortless reading, then floats away
	name = "PopUp",
	localName = L["Pop-Up"],
	func = function(frame, xOffset, yOffset, size, percent, direction)
		local vert, align = (";"):split(direction)
		local yNorm
		if percent < 0.22 then
			local t = percent / 0.22
			yNorm = Easing.OutBack(t, 1.35) * 0.45
			frame.zoomScale = 0.80 + 0.20 * Easing.OutBack(t, 1.6)
		elseif percent < 0.76 then
			local t = (percent - 0.22) / 0.54
			yNorm = 0.45 + t * 0.15
			frame.zoomScale = 1
		else
			local t = (percent - 0.76) / 0.24
			yNorm = 0.60 + Easing.InQuad(t) * 0.40
			frame.zoomScale = 1
		end

		local yDiff = (yNorm - 0.35) * size
		if vert == "DOWN" then
			yDiff = -yDiff
		end
		frame:SetPoint(validPoints[align] or "CENTER", UIParent, "CENTER", xOffset, yOffset + yDiff)
	end,
	overlap = true,
	defaultDirection = "UP;CENTER",
	directions = {
		["UP;CENTER"] = L["Up, center-aligned"],
		["UP;LEFT"] = L["Up, left-aligned"],
		["UP;RIGHT"] = L["Up, right-aligned"],
		["DOWN;CENTER"] = L["Down, center-aligned"],
		["DOWN;LEFT"] = L["Down, left-aligned"],
		["DOWN;RIGHT"] = L["Down, right-aligned"],
	},
}

Parrot:RegisterAnimationStyle {
	-- Radial explosion outward with OutQuart deceleration & subtle gravity droop
	name = "Splash",
	localName = L["Splash"],
	init = function(frame, xOffset, yOffset, size, direction, uid)
		local baseAngle
		if direction == "UP" then
			baseAngle = 90 + ((uid * 47) % 130 - 65)
		elseif direction == "DOWN" then
			baseAngle = 270 + ((uid * 47) % 130 - 65)
		else
			baseAngle = (uid * 67 + math.random(-18, 18)) % 360
		end
		frame.splashAngle = baseAngle * (math_pi / 180)
		frame.splashDist = size * (0.35 + math.random() * 0.22)
	end,
	func = function(frame, xOffset, yOffset, size, percent, direction)
		local angle = frame.splashAngle or 0
		local dist = (frame.splashDist or (size * 0.45)) * Easing.OutQuart(percent)
		local droop = Easing.InQuad(percent) * (size * 0.10)
		local x = xOffset + math_cos(angle) * dist
		local y = yOffset + math_sin(angle) * dist - droop
		frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
	end,
	cleanup = function(frame)
		frame.splashAngle = nil
		frame.splashDist = nil
	end,
	overlap = false,
	defaultDirection = "UP",
	directions = {
		["UP"] = L["Up"],
		["DOWN"] = L["Down"],
		["ALT"] = L["Alternating"],
	},
}
