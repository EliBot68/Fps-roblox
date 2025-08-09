-- Utilities.lua

local Utilities = {}

function Utilities.DegreesToVector3(degX, degY)
	local rx = math.rad(degX)
	local ry = math.rad(degY)
	local cx, sx = math.cos(rx), math.sin(rx)
	local cy, sy = math.cos(ry), math.sin(ry)
	-- Simplified forward vector from Euler
	return Vector3.new(sy * cx, -sx, cy * cx).Unit
end

function Utilities.ApplySpread(direction, spreadDegrees)
	local rand = Random.new()
	local yawOffset = (rand:NextNumber() - 0.5) * spreadDegrees
	local pitchOffset = (rand:NextNumber() - 0.5) * spreadDegrees
	local dir = Utilities.DegreesToVector3(pitchOffset, yawOffset)
	-- Blend with original
	local blended = (direction + dir * 0.15).Unit
	return blended
end

function Utilities.Clamp(num, min, max)
	if num < min then return min end
	if num > max then return max end
	return num
end

function Utilities.DeepCopy(tbl)
	if type(tbl) ~= 'table' then return tbl end
	local t = {}
	for k,v in pairs(tbl) do
		t[k] = Utilities.DeepCopy(v)
	end
	return t
end

-- ELO expected score between a (ra) and b (rb)
function Utilities.EloExpected(ra, rb)
	return 1 / (1 + 10 ^ ((rb - ra) / 400))
end

function Utilities.EloAdjust(rating, expected, score, k)
	return math.floor(rating + k * (score - expected))
end

-- Simple retry wrapper
function Utilities.Retry(attempts, delaySeconds, fn)
	local lastErr
	for i=1,attempts do
		local ok, result = pcall(fn)
		if ok then return true, result end
		lastErr = result
		if i < attempts then task.wait(delaySeconds) end
	end
	return false, lastErr
end

return Utilities
