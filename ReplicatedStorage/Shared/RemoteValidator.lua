-- RemoteValidator.lua
-- Central validation for RemoteEvent payloads

local RemoteValidator = {}

local MAX_DIRECTION_MAG = 1000
local MAX_ORIGIN_MAG = 5000

function RemoteValidator.ValidateFire(origin, direction)
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then return false, "Type" end
	if direction.Magnitude == 0 then return false, "ZeroDir" end
	if direction.Magnitude > MAX_DIRECTION_MAG then return false, "DirMag" end
	if origin.Magnitude > MAX_ORIGIN_MAG then return false, "OriginMag" end
	return true
end

function RemoteValidator.ValidateWeaponId(id)
	if typeof(id) ~= "string" then return false, "Type" end
	if #id > 24 then return false, "Len" end
	return true
end

return RemoteValidator
