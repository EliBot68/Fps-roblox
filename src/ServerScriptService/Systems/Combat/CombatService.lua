--!strict
--[[
	CombatService.lua
	Server-authoritative combat orchestration system
	
	Handles all combat interactions with security, performance, and scalability
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import types and dependencies
local CombatTypes = require(ReplicatedStorage.Shared.CombatTypes)
local CombatConstants = require(ReplicatedStorage.Shared.CombatConstants)
local Logger = require(ReplicatedStorage.Shared.Logger)
local WeaponService = require(script.Parent.WeaponService)
local HitDetection = require(script.Parent.HitDetection)
local AntiCheatValidator = require(script.Parent.AntiCheatValidator)
local BallisticsEngine = require(script.Parent.BallisticsEngine)

local ServiceLocator = require(ReplicatedStorage.Shared.ServiceLocator)
local Analytics = ServiceLocator:GetService("Analytics")
local NetworkBatcher = ServiceLocator:GetService("NetworkBatcher")

type CombatState = CombatTypes.CombatState
type WeaponInstance = CombatTypes.WeaponInstance
type ShotData = CombatTypes.ShotData
type HitInfo = CombatTypes.HitInfo

local CombatService = {}
local logger = Logger.new("CombatService")

-- Configuration using centralized constants
local COMBAT_CONFIG = {
	maxShotDistance = CombatConstants.MAX_SHOT_DISTANCE,
	hitValidationWindow = CombatConstants.HIT_VALIDATION_WINDOW,
	maxShotsPerSecond = CombatConstants.MAX_SHOTS_PER_SECOND,
	lagCompensationWindow = CombatConstants.LAG_COMPENSATION_WINDOW,
	antiCheatSensitivity = 0.8,
	performanceMode = false
}

-- State tracking
local playerCombatStates: {[number]: CombatState} = {}
local activeShots: {[string]: ShotData} = {}
local combatEvents: {CombatTypes.CombatEvent} = {}
local lastCleanup = tick()

-- Latency tracking for improved statistics
local playerLatencies: {[number]: {number}} = {} -- Rolling latency samples per player
local latencyStats: {[number]: {average: number, min: number, max: number}} = {}

-- Remote events
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("CombatEvents")
local fireWeaponRemote = remoteEvents:WaitForChild("FireWeapon")
local reloadWeaponRemote = remoteEvents:WaitForChild("ReloadWeapon")
local equipWeaponRemote = remoteEvents:WaitForChild("EquipWeapon")

-- Initialize combat service
function CombatService.Initialize()
	-- Set up remote event handlers
	fireWeaponRemote.OnServerInvoke = CombatService.HandleWeaponFire
	reloadWeaponRemote.OnServerInvoke = CombatService.HandleWeaponReload
	equipWeaponRemote.OnServerEvent:Connect(CombatService.HandleWeaponEquip)
	
	-- Set up periodic tasks
	RunService.Heartbeat:Connect(CombatService.Update)
	
	-- Set up player management
	Players.PlayerAdded:Connect(CombatService.OnPlayerAdded)
	Players.PlayerRemoving:Connect(CombatService.OnPlayerRemoving)
	
	logger:info("Combat service initialized with anti-cheat validation")
end

-- Handle player joining
function CombatService.OnPlayerAdded(player: Player)
	local userId = player.UserId
	playerCombatStates[userId] = {
		equippedWeapons = {},
		activeSlot = 1,
		isInCombat = false,
		lastDamageTime = 0,
		health = 100,
		maxHealth = 100,
		shield = 0,
		maxShield = 100,
		kills = 0,
		deaths = 0,
		assists = 0,
		damageDealt = 0,
		damageTaken = 0,
		accuracy = 0,
		headshotRate = 0
	}
	
	-- Initialize latency tracking
	playerLatencies[userId] = {}
	latencyStats[userId] = {average = 0, min = math.huge, max = 0}
	
	logger:debug("Player added to combat system", {playerId = userId, playerName = player.Name})
end

-- Handle player leaving
function CombatService.OnPlayerRemoving(player: Player)
	local userId = player.UserId
	playerCombatStates[userId] = nil
	playerLatencies[userId] = nil
	latencyStats[userId] = nil
	AntiCheatValidator.CleanupPlayer(userId)
	
	logger:debug("Player removed from combat system", {playerId = userId, playerName = player.Name})
end

-- Main update loop
function CombatService.Update()
	local currentTime = tick()
	
	-- Process ballistics
	BallisticsEngine.Update()
	
	-- Update latency tracking
	CombatService.UpdateLatencyTracking()
	
	-- Cleanup old data periodically
	if currentTime - lastCleanup > CombatConstants.CLEANUP_INTERVAL then
		CombatService.CleanupOldData()
		lastCleanup = currentTime
	end
	
	-- Update anti-cheat
	AntiCheatValidator.Update()
end

local DEBUG = false
local function Debug(...)
	if DEBUG then
		print("[CombatService]", ...)
	end
end

-- Handle weapon fire request from client
function CombatService.HandleWeaponFire(player: Player, weaponId: string, targetPosition: Vector3, clientTimestamp: number): {success: boolean, hitTarget: Player?, damage: number?}
	local userId = player.UserId
	local currentTime = tick()
	
	-- Track latency for this request
	CombatService.RecordLatency(userId, currentTime - clientTimestamp)
	
	-- Validate player state
	local combatState = playerCombatStates[userId]
	if not combatState then
		logger:warn("Invalid player state in weapon fire", {playerId = userId})
		return {success = false, reason = "Invalid player state"}
	end
	
	-- Rate limiting check
	if not AntiCheatValidator.CheckFireRate(userId, weaponId, currentTime) then
		return {success = false, reason = "Rate limit exceeded"}
	end
	
	-- Get equipped weapon (source of truth from WeaponService)
	local weaponInstance = WeaponService.GetPlayerWeapon(player, combatState.activeSlot)
	if not weaponInstance or weaponInstance.config.id ~= weaponId then
		return {success = false, reason = "Weapon not equipped"}
	end
	
	-- Server-side fire rate enforcement (in addition to AntiCheat)
	local minInterval = 60 / weaponInstance.config.stats.fireRate
	if weaponInstance.lastFired > 0 and (currentTime - weaponInstance.lastFired) < (minInterval * 0.95) then
		return {success = false, reason = "Fire rate enforcement"}
	end
	
	-- Check ammunition
	if weaponInstance.currentAmmo <= 0 then
		return {success = false, reason = "No ammunition"}
	end
	
	-- Validate shot distance early
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then
		return {success = false, reason = "No character"}
	end
	if (targetPosition - char.HumanoidRootPart.Position).Magnitude > COMBAT_CONFIG.maxShotDistance then
		return {success = false, reason = "Out of range"}
	end
	
	-- Validate shot with lag compensation
	local playerPosition = CombatService.GetLagCompensatedPosition(player, clientTimestamp)
	if not playerPosition then
		return {success = false, reason = "Invalid position"}
	end
	
	-- Create shot data
	local shotData: ShotData = {
		shooter = userId,
		weapon = weaponId,
		origin = playerPosition + Vector3.new(0, 1.5, 0), -- eye level
		direction = (targetPosition - playerPosition).Unit,
		timestamp = currentTime,
		clientTimestamp = clientTimestamp,
		spread = CombatService.CalculateSpread(weaponInstance),
		prediction = false
	}
	
	-- Validate shot legitimacy
	if not AntiCheatValidator.ValidateShot(shotData) then
		return {success = false, reason = "Shot validation failed"}
	end
	
	-- Process hit detection
	local hitResult = HitDetection.ProcessShot(shotData)
	
	-- Consume ammunition
	weaponInstance.currentAmmo -= 1
	weaponInstance.lastFired = currentTime
	
	-- Update combat state
	combatState.isInCombat = true
	combatState.lastDamageTime = currentTime
	
	-- Send result to clients
	if hitResult.hit then
		CombatService.ProcessHit(hitResult)
		NetworkBatcher.QueueCombatEvent("Hit", {
			shooter = userId,
			target = hitResult.target,
			damage = hitResult.damage,
			position = hitResult.hitPosition,
			weapon = weaponId
		})
	else
		NetworkBatcher.QueueCombatEvent("Miss", {
			shooter = userId,
			position = targetPosition,
			weapon = weaponId
		})
	end
	
	-- Analytics
	Analytics.RecordEvent("WeaponFire", {
		playerId = userId,
		weaponId = weaponId,
		hit = hitResult.hit,
		distance = hitResult.distance or 0
	})
	
	return {
		success = true,
		hitTarget = hitResult.target and Players:GetPlayerByUserId(hitResult.target),
		damage = hitResult.damage
	}
end

-- Handle weapon reload request
function CombatService.HandleWeaponReload(player: Player, weaponId: string): {success: boolean, ammoCount: number?}
	local userId = player.UserId
	local combatState = playerCombatStates[userId]
	
	if not combatState then
		return {success = false, reason = "Invalid player state"}
	end
	
	local weaponInstance = WeaponService.GetPlayerWeapon(player, combatState.activeSlot)
	if not weaponInstance or weaponInstance.config.id ~= weaponId then
		return {success = false, reason = "Weapon not equipped"}
	end
	
	if weaponInstance.currentAmmo >= weaponInstance.config.stats.magazineSize then
		return {success = false, reason = "Magazine full"}
	end
	
	-- Check total ammo
	if weaponInstance.totalAmmo <= 0 then
		return {success = false, reason = "No ammo remaining"}
	end
	
	-- Prevent reload spam
	if weaponInstance.isReloading then
		return {success = false, reason = "Already reloading"}
	end
	
	-- Start reload
	weaponInstance.isReloading = true
	
	-- Calculate reload time with modifiers
	local reloadTime = weaponInstance.config.stats.reloadTime
	-- Apply attachment modifiers, condition, etc.
	
	-- Schedule reload completion
	task.wait(reloadTime)
	
	-- Complete reload
	local ammoNeeded = weaponInstance.config.stats.magazineSize - weaponInstance.currentAmmo
	local ammoToAdd = math.min(ammoNeeded, weaponInstance.totalAmmo)
	
	weaponInstance.currentAmmo = weaponInstance.currentAmmo + ammoToAdd
	weaponInstance.totalAmmo = weaponInstance.totalAmmo - ammoToAdd
	weaponInstance.isReloading = false
	
	-- Notify clients
	NetworkBatcher.QueueCombatEvent("Reload", {
		playerId = userId,
		weaponId = weaponId,
		ammoCount = weaponInstance.currentAmmo
	})
	
	return {success = true, ammoCount = weaponInstance.currentAmmo}
end

-- Handle weapon equip request
function CombatService.HandleWeaponEquip(player: Player, weaponId: string, slot: number)
	local userId = player.UserId
	local combatState = playerCombatStates[userId]
	if not combatState then return end
	if slot < 1 or slot > 3 then return end
	-- Retrieve weapon from WeaponService (slot-based)
	local weaponInstance = WeaponService.GetPlayerWeapon(player, slot)
	if not weaponInstance or weaponInstance.config.id ~= weaponId then
		-- Weapon not present in that slot yet; attempt to locate by ID in any slot
		for s = 1, 3 do
			local w = WeaponService.GetPlayerWeapon(player, s)
			if w and w.config.id == weaponId then
				weaponInstance = w
				break
			end
		end
	end
	if not weaponInstance then return end
	combatState.equippedWeapons[slot] = weaponInstance
	combatState.activeSlot = slot
	NetworkBatcher.QueueCombatEvent("Equip", { playerId = userId, weaponId = weaponId, slot = slot })
end

-- Process hit damage and effects
function CombatService.ProcessHit(hitInfo: HitInfo)
	local targetPlayer = Players:GetPlayerByUserId(hitInfo.target)
	if not targetPlayer then return end
	
	local targetState = playerCombatStates[hitInfo.target]
	if not targetState then return end
	
	-- Apply damage
	local finalDamage = hitInfo.damage
	
	-- Check shields first
	if targetState.shield > 0 then
		local shieldDamage = math.min(finalDamage, targetState.shield)
		targetState.shield = targetState.shield - shieldDamage
		finalDamage = finalDamage - shieldDamage
	end
	
	-- Apply remaining damage to health
	targetState.health = targetState.health - finalDamage
	targetState.damageTaken = targetState.damageTaken + hitInfo.damage
	
	-- Update shooter stats
	local shooterState = playerCombatStates[hitInfo.shooter]
	if shooterState then
		shooterState.damageDealt = shooterState.damageDealt + hitInfo.damage
	end
	
	-- Check for elimination
	if targetState.health <= 0 then
		CombatService.HandleElimination(hitInfo.shooter, hitInfo.target)
	end
end

-- Handle player elimination
function CombatService.HandleElimination(shooterId: number, targetId: number)
	local shooterState = playerCombatStates[shooterId]
	local targetState = playerCombatStates[targetId]
	
	if shooterState then
		shooterState.kills = shooterState.kills + 1
	end
	
	if targetState then
		targetState.deaths = targetState.deaths + 1
		targetState.health = 0
	end
	
	-- Notify all clients of elimination
	NetworkBatcher.QueueCombatEvent("Elimination", {
		shooter = shooterId,
		target = targetId,
		weapon = "unknown" -- TODO: track weapon used
	})
	
	-- Analytics
	Analytics.RecordEvent("PlayerElimination", {
		shooter = shooterId,
		target = targetId,
		time = tick()
	})
end

-- Get lag-compensated player position
function CombatService.GetLagCompensatedPosition(player: Player, clientTimestamp: number): Vector3?
	local character = player.Character
	if not character then return nil end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return nil end
	
	-- Simple lag compensation - in production would use proper interpolation
	local latency = tick() - clientTimestamp
	if latency > COMBAT_CONFIG.lagCompensationWindow then
		latency = COMBAT_CONFIG.lagCompensationWindow
	end
	
	-- Estimate position based on velocity
	local velocity = humanoidRootPart.AssemblyLinearVelocity
	local compensatedPosition = humanoidRootPart.Position - (velocity * latency)
	
	return compensatedPosition
end

-- Calculate weapon spread
function CombatService.CalculateSpread(weaponInstance: WeaponInstance): number
	local baseAccuracy = weaponInstance.config.stats.accuracy
	local condition = weaponInstance.condition
	
	-- Apply condition penalty
	local accuracyPenalty = (1 - condition) * 0.2
	local finalAccuracy = math.max(0.1, baseAccuracy - accuracyPenalty)
	
	-- Convert accuracy to spread (lower accuracy = higher spread)
	return (1 - finalAccuracy) * 0.1 -- radians
end

-- Cleanup old data
function CombatService.CleanupOldData()
	local currentTime = tick()
	local cleanupThreshold = 30 -- seconds
	
	-- Cleanup old shots
	for shotId, shotData in pairs(activeShots) do
		if currentTime - shotData.timestamp > cleanupThreshold then
			activeShots[shotId] = nil
		end
	end
	
	-- Cleanup old combat events
	for i = #combatEvents, 1, -1 do
		local event = combatEvents[i]
		if currentTime - event.timestamp > cleanupThreshold then
			table.remove(combatEvents, i)
		end
	end
end

-- Get player combat state
function CombatService.GetPlayerCombatState(userId: number): CombatState?
	return playerCombatStates[userId]
end

-- Get service statistics
function CombatService.GetStatistics(): {activePlayers: number, shotsPerSecond: number, averageLatency: number}
	local activePlayers = 0
	local recentShots = 0
	local totalLatency = 0
	local latencyCount = 0
	local currentTime = tick()
	
	for userId, state in pairs(playerCombatStates) do
		activePlayers = activePlayers + 1
		
		-- Add latency data
		local playerLatencyStats = latencyStats[userId]
		if playerLatencyStats and playerLatencyStats.average > 0 then
			totalLatency = totalLatency + playerLatencyStats.average
			latencyCount = latencyCount + 1
		end
	end
	
	-- Count shots in last second
	for _, shotData in pairs(activeShots) do
		if currentTime - shotData.timestamp < 1.0 then
			recentShots = recentShots + 1
		end
	end
	
	local averageLatency = latencyCount > 0 and (totalLatency / latencyCount) or 0
	
	return {
		activePlayers = activePlayers,
		shotsPerSecond = recentShots,
		averageLatency = averageLatency
	}
end

-- Record latency sample for player
function CombatService.RecordLatency(userId: number, latency: number)
	if not playerLatencies[userId] then
		playerLatencies[userId] = {}
	end
	
	local samples = playerLatencies[userId]
	table.insert(samples, latency)
	
	-- Keep only recent samples
	if #samples > CombatConstants.LATENCY_SAMPLE_SIZE then
		table.remove(samples, 1)
	end
	
	-- Update rolling statistics
	CombatService.UpdatePlayerLatencyStats(userId)
end

-- Update latency statistics for a player
function CombatService.UpdatePlayerLatencyStats(userId: number)
	local samples = playerLatencies[userId]
	if not samples or #samples == 0 then return end
	
	local total = 0
	local min = math.huge
	local max = 0
	
	for _, latency in ipairs(samples) do
		total = total + latency
		min = math.min(min, latency)
		max = math.max(max, latency)
	end
	
	latencyStats[userId] = {
		average = total / #samples,
		min = min,
		max = max
	}
end

-- Update latency tracking for all players
function CombatService.UpdateLatencyTracking()
	-- This could be expanded to actively ping players for more accurate latency
	-- For now, we rely on request timestamps
end

return CombatService
