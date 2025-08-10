--[[
	HitValidation.lua
	Server-authoritative hit detection and validation system
	
	Features:
	- Raycast-based hit validation with trajectory verification
	- Weapon-specific damage calculation and penetration system
	- Anti-cheat validation for shot angles, distances, and timing
	- Comprehensive hit logging for analysis and debugging
	- Integration with SecurityValidator for exploit detection
	
	Enterprise Features:
	- Service Locator integration for dependency injection
	- Comprehensive error handling and logging
	- Performance metrics and monitoring
	- Type-safe interfaces with full documentation
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

-- Import dependencies via Service Locator
local ServiceLocator = require(ReplicatedStorage.Shared.ServiceLocator)

local HitValidation = {}

-- Hit validation configuration
local HIT_CONFIG = {
	-- Maximum shooting distances by weapon type
	maxRange = {
		ASSAULT_RIFLE = 300,
		SNIPER_RIFLE = 500, 
		SHOTGUN = 50,
		PISTOL = 150,
		SMG = 200
	},
	
	-- Damage values by weapon and body part
	baseDamage = {
		ASSAULT_RIFLE = {head = 100, torso = 45, limbs = 35},
		SNIPER_RIFLE = {head = 100, torso = 80, limbs = 60},
		SHOTGUN = {head = 100, torso = 70, limbs = 50},
		PISTOL = {head = 100, torso = 40, limbs = 30},
		SMG = {head = 100, torso = 35, limbs = 25}
	},
	
	-- Weapon penetration capabilities
	penetration = {
		ASSAULT_RIFLE = {maxMaterials = 2, damageReduction = 0.3},
		SNIPER_RIFLE = {maxMaterials = 4, damageReduction = 0.2},
		SHOTGUN = {maxMaterials = 1, damageReduction = 0.5},
		PISTOL = {maxMaterials = 1, damageReduction = 0.4},
		SMG = {maxMaterials = 1, damageReduction = 0.35}
	},
	
	-- Material penetration values
	materialPenetration = {
		[Enum.Material.Wood] = 1,
		[Enum.Material.Plastic] = 1,
		[Enum.Material.Glass] = 0.5,
		[Enum.Material.Concrete] = 2,
		[Enum.Material.Metal] = 3,
		[Enum.Material.CorrodedMetal] = 2,
		[Enum.Material.Brick] = 2,
		[Enum.Material.Rock] = 3
	},
	
	-- Anti-cheat thresholds
	antiCheat = {
		maxShotAngleDeviation = 15, -- degrees
		maxPlayerSpeed = 20, -- studs/second
		maxRapidFireRate = 20, -- shots per second
		minShotInterval = 0.05, -- seconds between shots
		maxLagCompensation = 0.2 -- 200ms
	}
}

-- Hit validation result structure
export type HitResult = {
	isValid: boolean,
	damage: number,
	hitPart: string?,
	penetratedMaterials: {string}?,
	distance: number,
	trajectory: {Vector3}?,
	serverTimestamp: number,
	validationDetails: {
		rangeCheck: boolean,
		trajectoryCheck: boolean,
		speedCheck: boolean,
		angleCheck: boolean,
		rateCheck: boolean
	},
	exploitFlags: {string}?
}

-- Shot data structure for validation
export type ShotData = {
	shooter: Player,
	weapon: string,
	origin: Vector3,
	direction: Vector3,
	targetPosition: Vector3,
	clientTimestamp: number,
	shotId: string
}

-- Player shot tracking for anti-cheat
local playerShotHistory = {}
local playerLastShotTime = {}
local playerPositionHistory = {}

-- Initialize hit validation system
function HitValidation.Initialize()
	-- Register with Service Locator
	ServiceLocator.Register("HitValidation", {
		factory = function(dependencies)
			local Logging = dependencies.Logging
			if Logging then
				Logging.Info("HitValidation", "Hit validation system initialized")
			end
			return HitValidation
		end,
		dependencies = {"Logging"},
		singleton = true,
		priority = 9
	})
	
	print("[HitValidation] ✓ Server-authoritative hit validation system initialized")
end

-- Validate a shot and return hit result
function HitValidation.ValidateShot(shotData: ShotData): HitResult
	local startTime = tick()
	
	-- Initialize result structure
	local result: HitResult = {
		isValid = false,
		damage = 0,
		hitPart = nil,
		penetratedMaterials = {},
		distance = 0,
		trajectory = {},
		serverTimestamp = tick(),
		validationDetails = {
			rangeCheck = false,
			trajectoryCheck = false,
			speedCheck = false,
			angleCheck = false,
			rateCheck = false
		},
		exploitFlags = {}
	}
	
	-- Get dependencies
	local Logging = ServiceLocator.GetService("Logging")
	local SecurityValidator = ServiceLocator.GetService("SecurityValidator")
	
	-- Basic input validation
	if not shotData.shooter or not shotData.weapon or not shotData.origin or not shotData.direction then
		table.insert(result.exploitFlags, "INVALID_SHOT_DATA")
		HitValidation._LogSuspiciousActivity(shotData.shooter, "Invalid shot data", shotData)
		return result
	end
	
	-- Validate weapon type
	if not HIT_CONFIG.baseDamage[shotData.weapon] then
		table.insert(result.exploitFlags, "INVALID_WEAPON")
		HitValidation._LogSuspiciousActivity(shotData.shooter, "Invalid weapon type", shotData)
		return result
	end
	
	-- Rate limiting check
	result.validationDetails.rateCheck = HitValidation._ValidateFireRate(shotData.shooter, shotData.weapon)
	if not result.validationDetails.rateCheck then
		table.insert(result.exploitFlags, "RATE_LIMIT_EXCEEDED")
	end
	
	-- Speed hack detection
	result.validationDetails.speedCheck = HitValidation._ValidatePlayerSpeed(shotData.shooter, shotData.origin)
	if not result.validationDetails.speedCheck then
		table.insert(result.exploitFlags, "SPEED_HACK_DETECTED")
	end
	
	-- Shot angle validation
	result.validationDetails.angleCheck = HitValidation._ValidateShotAngle(shotData)
	if not result.validationDetails.angleCheck then
		table.insert(result.exploitFlags, "INVALID_SHOT_ANGLE")
	end
	
	-- Perform raycast hit detection
	local raycastResult = HitValidation._PerformRaycast(shotData)
	if raycastResult then
		-- Calculate distance
		result.distance = (shotData.origin - raycastResult.Position).Magnitude
		
		-- Range validation
		local maxRange = HIT_CONFIG.maxRange[shotData.weapon] or 100
		result.validationDetails.rangeCheck = result.distance <= maxRange
		
		if not result.validationDetails.rangeCheck then
			table.insert(result.exploitFlags, "SHOT_OUT_OF_RANGE")
		end
		
		-- Trajectory validation
		result.validationDetails.trajectoryCheck = HitValidation._ValidateTrajectory(shotData, raycastResult)
		if not result.validationDetails.trajectoryCheck then
			table.insert(result.exploitFlags, "INVALID_TRAJECTORY")
		end
		
		-- Calculate damage if hit is valid
		if result.validationDetails.rangeCheck and result.validationDetails.trajectoryCheck then
			local hitInfo = HitValidation._AnalyzeHit(raycastResult, shotData.weapon)
			result.damage = hitInfo.damage
			result.hitPart = hitInfo.bodyPart
			result.penetratedMaterials = hitInfo.penetratedMaterials
			result.trajectory = hitInfo.trajectory
			
			-- Mark as valid if no critical exploits detected
			if #result.exploitFlags == 0 or HitValidation._OnlyMinorFlags(result.exploitFlags) then
				result.isValid = true
			end
		end
	else
		-- No hit detected
		result.validationDetails.trajectoryCheck = true -- No trajectory to validate
		result.validationDetails.rangeCheck = true -- No range to validate
		
		-- Still validate for exploits even on misses
		if #result.exploitFlags == 0 or HitValidation._OnlyMinorFlags(result.exploitFlags) then
			result.isValid = true -- Valid miss
		end
	end
	
	-- Log hit validation for analysis
	HitValidation._LogHitValidation(shotData, result, tick() - startTime)
	
	-- Report exploits to SecurityValidator
	if #result.exploitFlags > 0 then
		HitValidation._ReportExploitAttempt(shotData.shooter, result.exploitFlags, shotData)
	end
	
	return result
end

-- Perform raycast hit detection with penetration
function HitValidation._PerformRaycast(shotData: ShotData): RaycastResult?
	local origin = shotData.origin
	local direction = shotData.direction.Unit
	local maxRange = HIT_CONFIG.maxRange[shotData.weapon] or 100
	
	-- Raycast parameters
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	raycastParams.FilterDescendantsInstances = {shotData.shooter.Character}
	
	local penetrationInfo = HIT_CONFIG.penetration[shotData.weapon]
	local remainingPenetration = penetrationInfo.maxMaterials
	local currentDamageMultiplier = 1.0
	local penetratedMaterials = {}
	
	local currentOrigin = origin
	local remainingRange = maxRange
	
	-- Penetration loop
	while remainingPenetration > 0 and remainingRange > 0 do
		local raycastResult = Workspace:Raycast(currentOrigin, direction * remainingRange, raycastParams)
		
		if not raycastResult then
			break -- No more hits
		end
		
		local hitInstance = raycastResult.Instance
		local material = hitInstance.Material
		local materialCost = HIT_CONFIG.materialPenetration[material] or 1
		
		-- Check if we hit a player
		local hitPlayer = Players:GetPlayerFromCharacter(hitInstance.Parent)
		if hitPlayer and hitPlayer ~= shotData.shooter then
			-- Direct player hit - return with penetration info
			return {
				Instance = hitInstance,
				Position = raycastResult.Position,
				Normal = raycastResult.Normal,
				Material = material,
				PenetratedMaterials = penetratedMaterials,
				DamageMultiplier = currentDamageMultiplier
			}
		end
		
		-- Check if we can penetrate this material
		if materialCost > remainingPenetration then
			-- Cannot penetrate - return hit on obstacle
			return nil
		end
		
		-- Penetrate the material
		remainingPenetration = remainingPenetration - materialCost
		currentDamageMultiplier = currentDamageMultiplier * (1 - penetrationInfo.damageReduction)
		table.insert(penetratedMaterials, tostring(material))
		
		-- Update for next raycast
		local penetrationDistance = (raycastResult.Position - currentOrigin).Magnitude
		remainingRange = remainingRange - penetrationDistance - 0.1 -- Small offset to avoid re-hitting same part
		currentOrigin = raycastResult.Position + direction * 0.1
		
		-- Add hit instance to filter
		table.insert(raycastParams.FilterDescendantsInstances, hitInstance)
	end
	
	return nil -- No valid hit after penetration attempts
end

-- Analyze hit for damage calculation
function HitValidation._AnalyzeHit(raycastResult: any, weapon: string): {damage: number, bodyPart: string, penetratedMaterials: {string}, trajectory: {Vector3}}
	local hitInstance = raycastResult.Instance
	local hitPlayer = Players:GetPlayerFromCharacter(hitInstance.Parent)
	
	if not hitPlayer then
		return {damage = 0, bodyPart = "none", penetratedMaterials = {}, trajectory = {}}
	end
	
	-- Determine body part hit
	local bodyPart = HitValidation._GetBodyPart(hitInstance)
	
	-- Get base damage for weapon and body part
	local weaponDamage = HIT_CONFIG.baseDamage[weapon]
	local baseDamage = weaponDamage[bodyPart] or weaponDamage.limbs
	
	-- Apply penetration damage reduction
	local damageMultiplier = raycastResult.DamageMultiplier or 1.0
	local finalDamage = math.floor(baseDamage * damageMultiplier)
	
	return {
		damage = finalDamage,
		bodyPart = bodyPart,
		penetratedMaterials = raycastResult.PenetratedMaterials or {},
		trajectory = {raycastResult.Position}
	}
end

-- Determine body part from hit instance
function HitValidation._GetBodyPart(hitInstance: Instance): string
	local instanceName = hitInstance.Name:lower()
	
	if instanceName:find("head") then
		return "head"
	elseif instanceName:find("torso") or instanceName:find("upperTorso") or instanceName:find("lowerTorso") then
		return "torso"
	else
		return "limbs"
	end
end

-- Validate fire rate to prevent rapid fire exploits
function HitValidation._ValidateFireRate(player: Player, weapon: string): boolean
	local currentTime = tick()
	local playerId = tostring(player.UserId)
	
	-- Initialize tracking if needed
	if not playerShotHistory[playerId] then
		playerShotHistory[playerId] = {}
		playerLastShotTime[playerId] = 0
	end
	
	-- Check minimum interval between shots
	local timeSinceLastShot = currentTime - playerLastShotTime[playerId]
	if timeSinceLastShot < HIT_CONFIG.antiCheat.minShotInterval then
		return false
	end
	
	-- Update shot history
	table.insert(playerShotHistory[playerId], currentTime)
	playerLastShotTime[playerId] = currentTime
	
	-- Keep only recent shots (last second)
	local recentShots = {}
	for _, shotTime in ipairs(playerShotHistory[playerId]) do
		if currentTime - shotTime <= 1.0 then
			table.insert(recentShots, shotTime)
		end
	end
	playerShotHistory[playerId] = recentShots
	
	-- Check if rate limit exceeded
	return #recentShots <= HIT_CONFIG.antiCheat.maxRapidFireRate
end

-- Validate player movement speed to detect speed hacks
function HitValidation._ValidatePlayerSpeed(player: Player, shotOrigin: Vector3): boolean
	local playerId = tostring(player.UserId)
	local currentTime = tick()
	
	-- Initialize position tracking if needed
	if not playerPositionHistory[playerId] then
		playerPositionHistory[playerId] = {
			lastPosition = shotOrigin,
			lastTime = currentTime
		}
		return true -- First shot, assume valid
	end
	
	local lastData = playerPositionHistory[playerId]
	local timeDelta = currentTime - lastData.lastTime
	local positionDelta = (shotOrigin - lastData.lastPosition).Magnitude
	
	-- Update position history
	playerPositionHistory[playerId] = {
		lastPosition = shotOrigin,
		lastTime = currentTime
	}
	
	-- Skip check if time delta is too small or too large
	if timeDelta < 0.01 or timeDelta > 1.0 then
		return true
	end
	
	-- Calculate speed
	local speed = positionDelta / timeDelta
	
	-- Check against maximum allowed speed
	return speed <= HIT_CONFIG.antiCheat.maxPlayerSpeed
end

-- Validate shot angle to detect aim hacks
function HitValidation._ValidateShotAngle(shotData: ShotData): boolean
	-- Get player's character
	local character = shotData.shooter.Character
	if not character then
		return false
	end
	
	local head = character:FindFirstChild("Head")
	if not head then
		return false
	end
	
	-- Calculate expected shot direction from head position
	local expectedDirection = (shotData.targetPosition - head.Position).Unit
	local actualDirection = shotData.direction.Unit
	
	-- Calculate angle between expected and actual direction
	local dotProduct = expectedDirection:Dot(actualDirection)
	local angle = math.deg(math.acos(math.clamp(dotProduct, -1, 1)))
	
	-- Check if angle is within acceptable range
	return angle <= HIT_CONFIG.antiCheat.maxShotAngleDeviation
end

-- Validate shot trajectory for physics consistency
function HitValidation._ValidateTrajectory(shotData: ShotData, raycastResult: any): boolean
	-- Basic trajectory validation - ensure shot follows expected path
	local expectedHitPosition = shotData.origin + shotData.direction.Unit * (shotData.origin - raycastResult.Position).Magnitude
	local actualHitPosition = raycastResult.Position
	
	-- Allow for small discrepancies due to floating point precision
	local tolerance = 2.0 -- studs
	local deviation = (expectedHitPosition - actualHitPosition).Magnitude
	
	return deviation <= tolerance
end

-- Check if exploit flags are only minor (non-critical)
function HitValidation._OnlyMinorFlags(exploitFlags: {string}): boolean
	local criticalFlags = {"INVALID_SHOT_DATA", "INVALID_WEAPON", "SPEED_HACK_DETECTED", "INVALID_TRAJECTORY"}
	
	for _, flag in ipairs(exploitFlags) do
		for _, criticalFlag in ipairs(criticalFlags) do
			if flag == criticalFlag then
				return false
			end
		end
	end
	
	return true
end

-- Log hit validation for analysis
function HitValidation._LogHitValidation(shotData: ShotData, result: HitResult, processingTime: number)
	local Logging = ServiceLocator.GetService("Logging")
	if not Logging then return end
	
	Logging.Info("HitValidation", "Shot validated", {
		shooter = shotData.shooter.Name,
		weapon = shotData.weapon,
		isValid = result.isValid,
		damage = result.damage,
		distance = result.distance,
		exploitFlags = result.exploitFlags,
		processingTime = processingTime,
		shotId = shotData.shotId
	})
end

-- Log suspicious activity
function HitValidation._LogSuspiciousActivity(player: Player, reason: string, shotData: ShotData)
	local Logging = ServiceLocator.GetService("Logging")
	if not Logging then return end
	
	Logging.Warn("HitValidation", "Suspicious shot activity detected", {
		player = player.Name,
		userId = player.UserId,
		reason = reason,
		weapon = shotData.weapon,
		shotId = shotData.shotId,
		timestamp = tick()
	})
end

-- Report exploit attempt to SecurityValidator
function HitValidation._ReportExploitAttempt(player: Player, exploitFlags: {string}, shotData: ShotData)
	local SecurityValidator = ServiceLocator.GetService("SecurityValidator")
	if not SecurityValidator then return end
	
	-- Create threat report
	local threat = {
		playerId = player.UserId,
		threatType = "combat_exploit",
		severity = #exploitFlags >= 2 and 8 or 6, -- Higher severity for multiple flags
		description = string.format("Combat exploit detected: %s", table.concat(exploitFlags, ", ")),
		timestamp = tick(),
		evidence = {
			exploitFlags = exploitFlags,
			weapon = shotData.weapon,
			shotId = shotData.shotId,
			shotOrigin = shotData.origin,
			shotDirection = shotData.direction
		}
	}
	
	-- Report to anti-exploit system
	pcall(function()
		local AntiExploit = ServiceLocator.GetService("AntiExploit")
		if AntiExploit then
			AntiExploit.ProcessSecurityThreat(threat)
		end
	end)
end

-- Get hit validation statistics
function HitValidation.GetValidationStats(): {[string]: any}
	local totalPlayers = 0
	local totalShots = 0
	
	for playerId, shotHistory in pairs(playerShotHistory) do
		totalPlayers = totalPlayers + 1
		totalShots = totalShots + #shotHistory
	end
	
	return {
		totalPlayers = totalPlayers,
		totalShots = totalShots,
		averageShotsPerPlayer = totalPlayers > 0 and (totalShots / totalPlayers) or 0,
		configuredWeapons = 0,
		maxRange = HIT_CONFIG.maxRange,
		antiCheatThresholds = HIT_CONFIG.antiCheat
	}
end

-- Clear old tracking data to prevent memory leaks
function HitValidation.CleanupOldData()
	local currentTime = tick()
	local cleanupThreshold = 300 -- 5 minutes
	
	-- Clean shot history
	for playerId, shotHistory in pairs(playerShotHistory) do
		local recentShots = {}
		for _, shotTime in ipairs(shotHistory) do
			if currentTime - shotTime <= cleanupThreshold then
				table.insert(recentShots, shotTime)
			end
		end
		
		if #recentShots > 0 then
			playerShotHistory[playerId] = recentShots
		else
			playerShotHistory[playerId] = nil
			playerLastShotTime[playerId] = nil
		end
	end
	
	-- Clean position history
	for playerId, positionData in pairs(playerPositionHistory) do
		if currentTime - positionData.lastTime > cleanupThreshold then
			playerPositionHistory[playerId] = nil
		end
	end
end

-- Auto-cleanup old data every 5 minutes
task.spawn(function()
	while true do
		task.wait(300) -- 5 minutes
		HitValidation.CleanupOldData()
	end
end)

return HitValidation
