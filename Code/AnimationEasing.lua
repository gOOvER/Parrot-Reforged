local _, ns = ...
local Parrot = ns.addon

local Easing = {}
ns.Easing = Easing
if Parrot then
	Parrot.Easing = Easing
end

local math_cos = math.cos
local math_sin = math.sin
local math_pow = math.pow
local math_pi = math.pi
local HALF_PI = math_pi * 0.5

local function clamp01(t)
	if t <= 0 then
		return 0
	elseif t >= 1 then
		return 1
	end
	return t
end

function Easing.Clamp(x, minVal, maxVal)
	if x < minVal then
		return minVal
	elseif x > maxVal then
		return maxVal
	end
	return x
end

function Easing.Linear(t)
	return clamp01(t)
end

function Easing.InQuad(t)
	t = clamp01(t)
	return t * t
end

function Easing.OutQuad(t)
	t = clamp01(t)
	local inv = 1 - t
	return 1 - inv * inv
end

function Easing.InOutQuad(t)
	t = clamp01(t)
	if t < 0.5 then
		return 2 * t * t
	end
	local inv = -2 * t + 2
	return 1 - (inv * inv) * 0.5
end

function Easing.InCubic(t)
	t = clamp01(t)
	return t * t * t
end

function Easing.OutCubic(t)
	t = clamp01(t)
	local inv = 1 - t
	return 1 - inv * inv * inv
end

function Easing.InOutCubic(t)
	t = clamp01(t)
	if t < 0.5 then
		return 4 * t * t * t
	end
	local inv = -2 * t + 2
	return 1 - (inv * inv * inv) * 0.5
end

function Easing.InQuart(t)
	t = clamp01(t)
	local t2 = t * t
	return t2 * t2
end

function Easing.OutQuart(t)
	t = clamp01(t)
	local inv = 1 - t
	local inv2 = inv * inv
	return 1 - inv2 * inv2
end

function Easing.OutExpo(t)
	t = clamp01(t)
	if t >= 1 then
		return 1
	end
	return 1 - math_pow(2, -10 * t)
end

function Easing.InSine(t)
	t = clamp01(t)
	return 1 - math_cos(t * HALF_PI)
end

function Easing.OutSine(t)
	t = clamp01(t)
	return math_sin(t * HALF_PI)
end

function Easing.InOutSine(t)
	t = clamp01(t)
	return -(math_cos(math_pi * t) - 1) * 0.5
end

function Easing.OutBack(t, overshoot)
	t = clamp01(t)
	local c1 = overshoot or 1.70158
	local c3 = c1 + 1
	local tm1 = t - 1
	return 1 + c3 * tm1 * tm1 * tm1 + c1 * tm1 * tm1
end

function Easing.OutElastic(t)
	t = clamp01(t)
	if t == 0 or t == 1 then
		return t
	end
	local c4 = (2 * math_pi) / 3
	return math_pow(2, -10 * t) * math_sin((t * 10 - 0.75) * c4) + 1
end

-- Smooth punch-pop curve for critical strikes & sticky notifications:
-- Rapidly punches up to `peakScale`, then settles smoothly back to 1.0 without font re-rasterization.
function Easing.CritPopScale(percent, peakScale, popDuration)
	peakScale = peakScale or 1.4
	popDuration = popDuration or 0.22
	if percent <= 0 then
		return 0.72
	elseif percent >= popDuration then
		return 1
	end

	local attackEnd = popDuration * 0.28
	if percent < attackEnd then
		local k = Easing.OutQuad(percent / attackEnd)
		return 0.72 + (peakScale - 0.72) * k
	end

	local decay = (percent - attackEnd) / (popDuration - attackEnd)
	local k = Easing.OutCubic(decay)
	return peakScale + (1 - peakScale) * k
end

-- Subtle crisp pop-in for normal combat text so numbers feel responsive rather than static.
function Easing.NormalPopScale(percent, popDuration)
	popDuration = popDuration or 0.07
	if percent >= popDuration then
		return 1
	elseif percent <= 0 then
		return 0.88
	end
	return 0.88 + 0.12 * Easing.OutQuad(percent / popDuration)
end

-- Smooth sine fade-in & cosine fade-out envelope.
function Easing.SmoothAlpha(percent, fadeInEnd, fadeOutStart)
	fadeInEnd = fadeInEnd or 0.06
	fadeOutStart = fadeOutStart or 0.76
	if percent <= 0 then
		return 0
	elseif percent < fadeInEnd then
		return Easing.OutSine(percent / fadeInEnd)
	elseif percent >= 1 then
		return 0
	elseif percent > fadeOutStart then
		local t = (percent - fadeOutStart) / (1 - fadeOutStart)
		return 0.5 * (1 + math_cos(t * math_pi))
	end
	return 1
end

-- Disables WoW's integer pixel-grid snapping so text and icons glide at sub-pixel precision on 120-240Hz monitors.
function Easing.DisablePixelSnap(region)
	if not region then
		return
	end
	if region.SetSnapToPixelGrid then
		pcall(region.SetSnapToPixelGrid, region, false)
	end
	if region.SetTexelSnappingBias then
		pcall(region.SetTexelSnappingBias, region, 0)
	end
end

