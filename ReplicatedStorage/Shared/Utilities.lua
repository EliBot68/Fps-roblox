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
	local blended = (direction + dir * 0.1).Unit
	return blended
end

return Utilities
