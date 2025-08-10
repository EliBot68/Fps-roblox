--!strict
--[[
	HitDetection.lua
	Server-side hit detection and validation system
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

-- Import dependencies
local CombatTypes = require(ReplicatedStorage.Shared.CombatTypes)
local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)
local AntiCheatService = require(ServerStorage.Services.AntiCheatService)
local AnalyticsService = require(ServerStorage.Services.AnalyticsService)

type HitInfo = CombatTypes.HitInfo
type WeaponStats = CombatTypes.WeaponStats

local HitDetection = {}

-- Configuration
local HIT_CONFIG = {
	maxHitDistance = 1000, -- Maximum valid hit distance
	hitboxExpansion = 0.2, -- Studs to expand hitboxes for lag compensation
	maxLagCompensation = 0.2, -- Maximum seconds to compensate for lag
	headHitboxMultiplier = 1.2,
	penaltyMultiplier = 0.9, -- Damage reduction for penetration
	minPenetrationThickness = 0.1 -- Minimum thickness to count as penetration
}

-- Hit validation cache
local recentHits: {[Player]: {[number]: {time: number, position: Vector3}}} = {}

-- Initialize hit detection
function HitDetection.Initialize()
	-- Clean up old hit cache periodically
	task.spawn(function()
		while true do
			task.wait(1)
			HitDetection.CleanupHitCache()
		end
	end)
	
	print("[HitDetection] ✓ Initialized")
end

-- Process and validate hit from client
function HitDetection.ProcessHit(
	shooter: Player,
	weapon: WeaponStats,
	targetPosition: Vector3,
	fireTime: number
): HitInfo
	
	local hitInfo: HitInfo = {
		hit = false,
		target = nil,
		damage = 0,
		distance = 0,
		isHeadshot = false,
		penetrationCount = 0,
		hitPosition = targetPosition,
		serverTime = tick()
	}
	
	-- Get shooter character and position
	local shooterCharacter = shooter.Character
	if not shooterCharacter or not shooterCharacter:FindFirstChild("HumanoidRootPart") then
		return hitInfo
	end
	
	local shooterPosition = shooterCharacter.HumanoidRootPart.Position
	
	-- Validate shot distance
	local distance = (targetPosition - shooterPosition).Magnitude
	if distance > HIT_CONFIG.maxHitDistance then
		AntiCheatService.LogSuspiciousActivity(shooter, "impossible_shot_distance", {
			distance = distance,
			maxDistance = HIT_CONFIG.maxHitDistance
		})
		return hitInfo
	end
	
	-- Perform server-side raycast with lag compensation
	local raycastResult = HitDetection.PerformLagCompensatedRaycast(
		shooterPosition,
		targetPosition,
		shooter,
		fireTime
	)
	
	if raycastResult.hit then
		hitInfo.hit = true
		hitInfo.hitPosition = raycastResult.position
		hitInfo.distance = distance
		hitInfo.penetrationCount = raycastResult.penetrationCount
		
		-- Check if hit a player
		local hitCharacter = raycastResult.character
		if hitCharacter then
			local hitPlayer = Players:GetPlayerFromCharacter(hitCharacter)
			if hitPlayer and hitPlayer ~= shooter then
				hitInfo.target = hitPlayer
				hitInfo.isHeadshot = raycastResult.isHeadshot
				
				-- Calculate damage
				hitInfo.damage = HitDetection.CalculateDamage(
					weapon,
					distance,
					hitInfo.isHeadshot,
					hitInfo.penetrationCount
				)
				
				-- Apply damage
				HitDetection.ApplyDamage(hitPlayer, hitInfo.damage, shooter, weapon.id)
				
				-- Log hit for analytics
				AnalyticsService.LogEvent(shooter, "player_hit", {
					weaponId = weapon.id,
					damage = hitInfo.damage,
					distance = math.floor(distance),
					isHeadshot = hitInfo.isHeadshot,
					penetrationCount = hitInfo.penetrationCount
				})
			end
		end
	end
	
	-- Cache hit for validation
	HitDetection.CacheHit(shooter, hitInfo)
	
	return hitInfo
end

-- Perform raycast with lag compensation
function HitDetection.PerformLagCompensatedRaycast(
	startPosition: Vector3,
	targetPosition: Vector3,
	shooter: Player,
	fireTime: number
): {hit: boolean, position: Vector3, character: Model?, isHeadshot: boolean, penetrationCount: number}
	
	local result = {
		hit = false,
		position = targetPosition,
		character = nil,
		isHeadshot = false,
		penetrationCount = 0
	}
	
	-- Calculate lag compensation
	local ping = HitDetection.GetPlayerPing(shooter)
	local lagCompensation = math.min(ping / 2000, HIT_CONFIG.maxLagCompensation)
	
	-- Get all player positions at fire time (with lag compensation)
	local playerPositions = HitDetection.GetHistoricalPlayerPositions(fireTime - lagCompensation)
	
	-- Create raycast parameters
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	raycastParams.FilterDescendantsInstances = {shooter.Character}
	
	local direction = (targetPosition - startPosition).Unit
	local maxDistance = (targetPosition - startPosition).Magnitude
	
	-- Perform raycast with penetration
	local currentPosition = startPosition
	local remainingDistance = maxDistance
	local penetrationCount = 0
	
	while remainingDistance > 0 and penetrationCount < 3 do
		local raycast = workspace:Raycast(currentPosition, direction * remainingDistance, raycastParams)
		
		if raycast then
			result.hit = true
			result.position = raycast.Position
			
			-- Check if hit a player
			local hitPart = raycast.Instance
			local hitCharacter = hitPart.Parent
			
			if hitCharacter:FindFirstChild("Humanoid") then
				-- Hit a player
				result.character = hitCharacter
				result.isHeadshot = HitDetection.IsHeadshot(hitPart)
				break
			else
				-- Hit environment - check for penetration
				if HitDetection.CanPenetrate(hitPart) then
					penetrationCount = penetrationCount + 1
					result.penetrationCount = penetrationCount
					
					-- Continue raycast through object
					local thickness = HitDetection.CalculateThickness(hitPart, raycast.Position, direction)
					currentPosition = raycast.Position + direction * (thickness + 0.1)
					remainingDistance = remainingDistance - (raycast.Position - currentPosition).Magnitude
					
					-- Add penetrated object to filter
					table.insert(raycastParams.FilterDescendantsInstances, hitPart)
				else
					-- Cannot penetrate - stop here
					break
				end
			end
		else
			-- No hit
			break
		end
	end
	
	return result
end

-- Check if body part counts as headshot
function HitDetection.IsHeadshot(bodyPart: BasePart): boolean
	local partName = bodyPart.Name:lower()
	return partName == "head" or partName:find("head") ~= nil
end

-- Check if part can be penetrated
function HitDetection.CanPenetrate(part: BasePart): boolean
	-- Check material penetrability
	local material = part.Material
	local penetrableMaterials = {
		Enum.Material.Wood,
		Enum.Material.Plastic,
		Enum.Material.Glass,
		Enum.Material.Ice,
		Enum.Material.Cardboard
	}
	
	for _, penetrableMaterial in pairs(penetrableMaterials) do
		if material == penetrableMaterial then
			return true
		end
	end
	
	-- Check thickness (thin parts can be penetrated)
	local thickness = math.min(part.Size.X, part.Size.Y, part.Size.Z)
	return thickness < 2 -- Can penetrate parts thinner than 2 studs
end

-- Calculate object thickness for penetration
function HitDetection.CalculateThickness(part: BasePart, hitPosition: Vector3, direction: Vector3): number
	-- Simple thickness calculation based on part size
	local size = part.Size
	local thickness = math.min(size.X, size.Y, size.Z)
	return math.max(thickness, HIT_CONFIG.minPenetrationThickness)
end

-- Calculate final damage
function HitDetection.CalculateDamage(
	weapon: WeaponStats,
	distance: number,
	isHeadshot: boolean,
	penetrationCount: number
): number
	
	-- Base damage calculation
	local damage = WeaponConfig.CalculateDamageAtDistance(weapon.id, distance, isHeadshot)
	
	-- Apply penetration penalty
	if penetrationCount > 0 then
		damage = damage * (HIT_CONFIG.penaltyMultiplier ^ penetrationCount)
	end
	
	return math.max(1, math.floor(damage))
end

-- Apply damage to player
function HitDetection.ApplyDamage(player: Player, damage: number, attacker: Player, weaponId: string)
	local character = player.Character
	if not character then return end
	
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end
	
	-- Apply damage
	humanoid.Health = math.max(0, humanoid.Health - damage)
	
	-- Check for elimination
	if humanoid.Health <= 0 then
		HitDetection.HandleElimination(player, attacker, weaponId)
	end
	
	-- Visual damage indicator
	HitDetection.ShowDamageIndicator(player, damage, attacker)
end

-- Handle player elimination
function HitDetection.HandleElimination(victim: Player, killer: Player, weaponId: string)
	-- Log elimination
	AnalyticsService.LogEvent(killer, "player_eliminated", {
		victimId = victim.UserId,
		weaponId = weaponId
	})
	
	AnalyticsService.LogEvent(victim, "player_eliminated_by", {
		killerId = killer.UserId,
		weaponId = weaponId
	})
	
	-- Award points/currency
	-- TODO: Implement scoring system
	
	-- Respawn victim after delay
	task.wait(3)
	if victim.Character then
		victim:LoadCharacter()
	end
end

-- Show damage indicator to player
function HitDetection.ShowDamageIndicator(player: Player, damage: number, attacker: Player)
	-- TODO: Implement damage indicator UI
	-- Show floating damage number and screen effect
end

-- Get player ping (simplified)
function HitDetection.GetPlayerPing(player: Player): number
	-- Get network stats if available
	local networkStats = player:FindFirstChild("NetworkStats")
	if networkStats then
		return networkStats.ServerStatsItem["Data Ping"]:GetValue()
	end
	
	-- Fallback to estimated ping
	return 50 -- milliseconds
end

-- Get historical player positions for lag compensation
function HitDetection.GetHistoricalPlayerPositions(timestamp: number): {[Player]: Vector3}
	local positions = {}
	
	-- For now, use current positions (future: implement position history)
	for _, player in pairs(Players:GetPlayers()) do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			positions[player] = player.Character.HumanoidRootPart.Position
		end
	end
	
	return positions
end

-- Cache hit for validation
function HitDetection.CacheHit(player: Player, hitInfo: HitInfo)
	if not recentHits[player] then
		recentHits[player] = {}
	end
	
	local hitId = #recentHits[player] + 1
	recentHits[player][hitId] = {
		time = tick(),
		position = hitInfo.hitPosition
	}
	
	-- Limit cache size
	if #recentHits[player] > 100 then
		table.remove(recentHits[player], 1)
	end
end

-- Clean up old hit cache entries
function HitDetection.CleanupHitCache()
	local currentTime = tick()
	local cacheTimeout = 10 -- seconds
	
	for player, hits in pairs(recentHits) do
		for i = #hits, 1, -1 do
			if currentTime - hits[i].time > cacheTimeout then
				table.remove(hits, i)
			end
		end
	end
end

-- Validate hit for anti-cheat
function HitDetection.ValidateHit(player: Player, hitInfo: HitInfo): boolean
	-- Check if hit is physically possible
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return false
	end
	
	local playerPosition = character.HumanoidRootPart.Position
	local distance = (hitInfo.hitPosition - playerPosition).Magnitude
	
	-- Check maximum possible distance
	if distance > HIT_CONFIG.maxHitDistance then
		return false
	end
	
	-- Check hit rate (prevent spam)
	local playerHits = recentHits[player]
	if playerHits then
		local recentHitCount = 0
		local currentTime = tick()
		
		for _, hit in pairs(playerHits) do
			if currentTime - hit.time < 1 then -- Last second
				recentHitCount = recentHitCount + 1
			end
		end
		
		-- Maximum 20 hits per second (generous for automatic weapons)
		if recentHitCount > 20 then
			return false
		end
	end
	
	return true
end

-- Get hit statistics for player
function HitDetection.GetHitStats(player: Player): {totalHits: number, accuracy: number, headshotRate: number}
	-- TODO: Implement hit statistics tracking
	return {
		totalHits = 0,
		accuracy = 0,
		headshotRate = 0
	}
end

return HitDetection
