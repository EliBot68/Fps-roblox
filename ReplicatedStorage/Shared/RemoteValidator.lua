-- RemoteValidator.lua
-- Enterprise-grade validation for RemoteEvent payloads with comprehensive security

local WeaponConfig = require(script.Parent.WeaponConfig)
local Utilities = require(script.Parent.Utilities)

local RemoteValidator = {}

-- Security constants
local MAX_DIRECTION_MAG = 1000
local MAX_ORIGIN_MAG = 5000
local MAX_STRING_LENGTH = 50
local MAX_ARRAY_SIZE = 100
local MAX_NUMBER_VALUE = 1e6

-- Rate limiting buckets per validation type
local rateLimits = {}

-- Validation schemas for different RemoteEvents
local ValidationSchemas = {
	FireWeapon = {
		{ name = "origin", type = "Vector3", validator = "ValidatePosition" },
		{ name = "direction", type = "Vector3", validator = "ValidateDirection" },
		{ name = "weaponId", type = "string", validator = "ValidateWeaponId" }
	},
	ReportHit = {
		{ name = "origin", type = "Vector3", validator = "ValidatePosition" },
		{ name = "direction", type = "Vector3", validator = "ValidateDirection" },
		{ name = "hitPosition", type = "Vector3", validator = "ValidatePosition" },
		{ name = "hitPart", type = "string", validator = "ValidatePartName" },
		{ name = "distance", type = "number", validator = "ValidateDistance" }
	},
	RequestMatch = {
		{ name = "gameMode", type = "string", validator = "ValidateGameMode" },
		{ name = "mapPreference", type = "string", validator = "ValidateMapName", optional = true }
	},
	PurchaseItem = {
		{ name = "itemId", type = "string", validator = "ValidateItemId" },
		{ name = "quantity", type = "number", validator = "ValidateQuantity" }
	}
}

-- Core validation functions
function RemoteValidator.ValidateFire(origin, direction, weaponId)
	local valid, reason = RemoteValidator.ValidatePosition(origin)
	if not valid then return false, "Origin_" .. reason end
	
	valid, reason = RemoteValidator.ValidateDirection(direction)
	if not valid then return false, "Direction_" .. reason end
	
	valid, reason = RemoteValidator.ValidateWeaponId(weaponId)
	if not valid then return false, "Weapon_" .. reason end
	
	return true
end

function RemoteValidator.ValidatePosition(position)
	if typeof(position) ~= "Vector3" then return false, "Type" end
	if position.Magnitude > MAX_ORIGIN_MAG then return false, "Magnitude" end
	
	-- Additional spatial validation
	if math.abs(position.X) > 2500 or math.abs(position.Z) > 2500 then
		return false, "OutOfBounds"
	end
	if position.Y < -500 or position.Y > 500 then
		return false, "InvalidHeight"
	end
	
	return true
end

function RemoteValidator.ValidateDirection(direction)
	if typeof(direction) ~= "Vector3" then return false, "Type" end
	if direction.Magnitude == 0 then return false, "ZeroMagnitude" end
	if direction.Magnitude > MAX_DIRECTION_MAG then return false, "TooLarge" end
	
	-- Ensure it's a unit vector (approximately)
	if math.abs(direction.Magnitude - 1) > 0.1 then
		return false, "NotUnit"
	end
	
	return true
end

function RemoteValidator.ValidateWeaponId(id)
	if typeof(id) ~= "string" then return false, "Type" end
	if #id > MAX_STRING_LENGTH then return false, "TooLong" end
	if #id == 0 then return false, "Empty" end
	
	-- Check if weapon exists in config
	if not WeaponConfig[id] then return false, "Unknown" end
	
	-- Validate string contains only alphanumeric characters
	if not string.match(id, "^[%w_]+$") then return false, "InvalidChars" end
	
	return true
end

function RemoteValidator.ValidatePartName(partName)
	if typeof(partName) ~= "string" then return false, "Type" end
	if #partName > MAX_STRING_LENGTH then return false, "TooLong" end
	if #partName == 0 then return false, "Empty" end
	
	-- Validate against known body parts
	local validParts = { "Head", "Torso", "UpperTorso", "LowerTorso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }
	if not Utilities.TableContains(validParts, partName) then
		return false, "InvalidPart"
	end
	
	return true
end

function RemoteValidator.ValidateDistance(distance)
	if typeof(distance) ~= "number" then return false, "Type" end
	if distance < 0 then return false, "Negative" end
	if distance > 2000 then return false, "TooFar" end
	if distance ~= distance then return false, "NaN" end -- Check for NaN
	
	return true
end

function RemoteValidator.ValidateGameMode(mode)
	if typeof(mode) ~= "string" then return false, "Type" end
	
	local validModes = { "Deathmatch", "TeamDeathmatch", "Competitive", "Casual" }
	if not Utilities.TableContains(validModes, mode) then
		return false, "InvalidMode"
	end
	
	return true
end

function RemoteValidator.ValidateMapName(mapName)
	if typeof(mapName) ~= "string" then return false, "Type" end
	if #mapName > MAX_STRING_LENGTH then return false, "TooLong" end
	
	-- Basic map name validation (alphanumeric + spaces)
	if not string.match(mapName, "^[%w%s_-]+$") then return false, "InvalidChars" end
	
	return true
end

function RemoteValidator.ValidateItemId(itemId)
	if typeof(itemId) ~= "string" then return false, "Type" end
	if #itemId > MAX_STRING_LENGTH then return false, "TooLong" end
	if #itemId == 0 then return false, "Empty" end
	
	-- Validate format (category_item_id)
	if not string.match(itemId, "^%w+_%w+_%w+$") then return false, "InvalidFormat" end
	
	return true
end

function RemoteValidator.ValidateQuantity(quantity)
	if typeof(quantity) ~= "number" then return false, "Type" end
	if quantity < 1 then return false, "TooSmall" end
	if quantity > 100 then return false, "TooLarge" end
	if quantity ~= math.floor(quantity) then return false, "NotInteger" end
	
	return true
end

-- Schema-based validation
function RemoteValidator.ValidateRemoteCall(eventName, args)
	local schema = ValidationSchemas[eventName]
	if not schema then return false, "UnknownEvent" end
	
	if #args ~= #schema then
		-- Check for optional parameters
		local requiredCount = 0
		for _, field in ipairs(schema) do
			if not field.optional then
				requiredCount = requiredCount + 1
			end
		end
		
		if #args < requiredCount then
			return false, "TooFewArgs"
		elseif #args > #schema then
			return false, "TooManyArgs"
		end
	end
	
	-- Validate each argument
	for i, field in ipairs(schema) do
		if i <= #args then
			local arg = args[i]
			
			-- Type check
			if typeof(arg) ~= field.type then
				return false, "Type_" .. field.name
			end
			
			-- Custom validation
			if field.validator and RemoteValidator[field.validator] then
				local valid, reason = RemoteValidator[field.validator](arg)
				if not valid then
					return false, field.name .. "_" .. reason
				end
			end
		elseif not field.optional then
			return false, "Missing_" .. field.name
		end
	end
	
	return true
end

-- Rate limiting per player
function RemoteValidator.CheckRateLimit(userId, eventType, limit, windowSeconds)
	local now = tick()
	local key = userId .. "_" .. eventType
	
	if not rateLimits[key] then
		rateLimits[key] = { count = 0, window = now }
	end
	
	local bucket = rateLimits[key]
	
	-- Reset window if expired
	if now - bucket.window > windowSeconds then
		bucket.count = 0
		bucket.window = now
	end
	
	-- Check if limit exceeded
	if bucket.count >= limit then
		return false, "RateLimitExceeded"
	end
	
	bucket.count = bucket.count + 1
	return true
end

-- Sanitization functions
function RemoteValidator.SanitizeString(input, maxLength)
	if typeof(input) ~= "string" then return "" end
	
	-- Remove control characters and limit length
	local sanitized = string.gsub(input, "[%c%z]", "")
	if maxLength and #sanitized > maxLength then
		sanitized = string.sub(sanitized, 1, maxLength)
	end
	
	return sanitized
end

function RemoteValidator.SanitizeNumber(input, min, max)
	if typeof(input) ~= "number" then return min or 0 end
	if input ~= input then return min or 0 end -- NaN check
	
	return Utilities.Clamp(input, min or -math.huge, max or math.huge)
end

-- Comprehensive validation for enterprise security
function RemoteValidator.ValidatePlayerAction(player, eventName, args)
	-- Basic player validation
	if not player or not player.Parent then
		return false, "InvalidPlayer"
	end
	
	-- Rate limiting
	local rateOk, rateReason = RemoteValidator.CheckRateLimit(
		player.UserId, eventName, 30, 1 -- 30 calls per second max
	)
	if not rateOk then
		return false, rateReason
	end
	
	-- Schema validation
	local schemaOk, schemaReason = RemoteValidator.ValidateRemoteCall(eventName, args)
	if not schemaOk then
		return false, schemaReason
	end
	
	return true
end

return RemoteValidator
