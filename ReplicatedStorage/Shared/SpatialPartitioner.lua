--[[
	SpatialPartitioner.lua
	Enterprise spatial partitioning system for efficient event replication
	
	Implements Interest Zones to reduce unnecessary network updates by only
	sending events to players within relevant spatial regions.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Scheduler = require(script.Parent.Scheduler)
local NetworkBatcher = require(script.Parent.NetworkBatcher)

local SpatialPartitioner = {}

-- Spatial partitioning configuration
local ZONE_SIZE = 200 -- Each zone is 200x200 studs
local UPDATE_FREQUENCY = 10 -- Update player zones at 10Hz
local MAX_INTEREST_DISTANCE = 300 -- Maximum distance for interest
local ZONE_CACHE_DURATION = 5 -- Cache zone calculations for 5 seconds

-- Zone storage and player tracking
local zones = {} -- [zoneKey] = {players = {}, events = {}}
local playerZones = {} -- [player] = {currentZone, nearbyZones}
local zoneCache = {} -- [zoneKey] = {lastUpdate, playerCount}

-- Event types that support spatial partitioning
local SPATIAL_EVENT_TYPES = {
	"WeaponFired",
	"PlayerEliminated", 
	"EffectSpawn",
	"PlayerMovement",
	"ItemPickup"
}

-- Initialize spatial partitioning system
function SpatialPartitioner.Initialize()
	-- Schedule zone updates using the consolidated Scheduler
	Scheduler.ScheduleTask("SpatialZoneUpdates", function()
		SpatialPartitioner.UpdatePlayerZones()
	end, UPDATE_FREQUENCY)
	
	-- Schedule zone cleanup
	Scheduler.ScheduleTask("SpatialZoneCleanup", function()
		SpatialPartitioner.CleanupEmptyZones()
	end, 2) -- Clean every 30 frames (2Hz)
	
	print("[SpatialPartitioner] ✓ Initialized with", ZONE_SIZE, "stud zones")
end

-- Get zone key from world position
function SpatialPartitioner.GetZoneKey(position: Vector3): string
	local zoneX = math.floor(position.X / ZONE_SIZE)
	local zoneZ = math.floor(position.Z / ZONE_SIZE)
	return string.format("%d,%d", zoneX, zoneZ)
end

-- Get all zone keys within interest distance of a position
function SpatialPartitioner.GetNearbyZones(position: Vector3): {string}
	local centerZone = SpatialPartitioner.GetZoneKey(position)
	local nearbyZones = {centerZone}
	
	-- Calculate how many zones to check in each direction
	local zoneRadius = math.ceil(MAX_INTEREST_DISTANCE / ZONE_SIZE)
	
	local centerX, centerZ = centerZone:match("([^,]+),([^,]+)")
	centerX, centerZ = tonumber(centerX), tonumber(centerZ)
	
	-- Add adjacent zones within interest distance
	for offsetX = -zoneRadius, zoneRadius do
		for offsetZ = -zoneRadius, zoneRadius do
			if offsetX ~= 0 or offsetZ ~= 0 then -- Skip center zone (already added)
				local zoneKey = string.format("%d,%d", centerX + offsetX, centerZ + offsetZ)
				
				-- Calculate actual distance to zone center
				local zoneWorldX = (centerX + offsetX) * ZONE_SIZE + ZONE_SIZE/2
				local zoneWorldZ = (centerZ + offsetZ) * ZONE_SIZE + ZONE_SIZE/2
				local zoneCenter = Vector3.new(zoneWorldX, 0, zoneWorldZ)
				
				if (zoneCenter - position).Magnitude <= MAX_INTEREST_DISTANCE then
					table.insert(nearbyZones, zoneKey)
				end
			end
		end
	end
	
	return nearbyZones
end

-- Update player zone assignments
function SpatialPartitioner.UpdatePlayerZones()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
			if humanoidRootPart then
				SpatialPartitioner.UpdatePlayerZone(player, humanoidRootPart.Position)
			end
		end
	end
end

-- Update a specific player's zone assignment
function SpatialPartitioner.UpdatePlayerZone(player: Player, position: Vector3)
	local newZoneKey = SpatialPartitioner.GetZoneKey(position)
	local nearbyZones = SpatialPartitioner.GetNearbyZones(position)
	
	local currentData = playerZones[player]
	
	-- Check if player changed zones
	if not currentData or currentData.currentZone ~= newZoneKey then
		-- Remove from old zone
		if currentData and currentData.currentZone then
			SpatialPartitioner.RemovePlayerFromZone(player, currentData.currentZone)
		end
		
		-- Add to new zone
		SpatialPartitioner.AddPlayerToZone(player, newZoneKey)
		
		-- Update player data
		playerZones[player] = {
			currentZone = newZoneKey,
			nearbyZones = nearbyZones,
			lastUpdate = os.clock()
		}
	else
		-- Update nearby zones (may have changed due to movement)
		playerZones[player].nearbyZones = nearbyZones
		playerZones[player].lastUpdate = os.clock()
	end
end

-- Add player to a zone
function SpatialPartitioner.AddPlayerToZone(player: Player, zoneKey: string)
	if not zones[zoneKey] then
		zones[zoneKey] = {
			players = {},
			events = {},
			createdAt = os.clock()
		}
	end
	
	zones[zoneKey].players[player] = true
	
	-- Update zone cache
	if not zoneCache[zoneKey] then
		zoneCache[zoneKey] = {lastUpdate = 0, playerCount = 0}
	end
	zoneCache[zoneKey].playerCount = zoneCache[zoneKey].playerCount + 1
	zoneCache[zoneKey].lastUpdate = os.clock()
end

-- Remove player from a zone
function SpatialPartitioner.RemovePlayerFromZone(player: Player, zoneKey: string)
	if zones[zoneKey] then
		zones[zoneKey].players[player] = nil
		
		-- Update cache
		if zoneCache[zoneKey] then
			zoneCache[zoneKey].playerCount = math.max(0, zoneCache[zoneKey].playerCount - 1)
		end
	end
end

-- Broadcast event to players in relevant zones
function SpatialPartitioner.BroadcastToZones(eventType: string, eventData: any, sourcePosition: Vector3)
	-- Check if this event type supports spatial partitioning
	if not table.find(SPATIAL_EVENT_TYPES, eventType) then
		-- Fallback to global broadcast
		NetworkBatcher.QueueBroadcast(eventType, eventData)
		return
	end
	
	local relevantZones = SpatialPartitioner.GetNearbyZones(sourcePosition)
	local notifiedPlayers = {}
	
	-- Send to players in all relevant zones
	for _, zoneKey in ipairs(relevantZones) do
		local zone = zones[zoneKey]
		if zone then
			for player, _ in pairs(zone.players) do
				if not notifiedPlayers[player] then
					NetworkBatcher.QueueEvent(eventType, player, eventData)
					notifiedPlayers[player] = true
				end
			end
		end
	end
	
	local playerCount = 0
	for _ in pairs(notifiedPlayers) do
		playerCount = playerCount + 1
	end
	
	-- Debug logging for optimization tracking
	if playerCount < #Players:GetPlayers() then
		print(string.format("[SpatialPartitioner] ✓ Optimized %s event: %d/%d players notified", 
			eventType, playerCount, #Players:GetPlayers()))
	end
end

-- Clean up empty zones to prevent memory leaks
function SpatialPartitioner.CleanupEmptyZones()
	local cleanedZones = 0
	local currentTime = os.clock()
	
	for zoneKey, zone in pairs(zones) do
		local hasPlayers = false
		for player, _ in pairs(zone.players) do
			if Players:FindFirstChild(player.Name) then
				hasPlayers = true
				break
			else
				-- Player left, clean up reference
				zone.players[player] = nil
			end
		end
		
		-- Remove zones with no players and no recent activity
		if not hasPlayers and (currentTime - zone.createdAt) > ZONE_CACHE_DURATION then
			zones[zoneKey] = nil
			zoneCache[zoneKey] = nil
			cleanedZones = cleanedZones + 1
		end
	end
	
	if cleanedZones > 0 then
		print("[SpatialPartitioner] ✓ Cleaned up", cleanedZones, "empty zones")
	end
end

-- Handle player leaving
function SpatialPartitioner.OnPlayerLeaving(player: Player)
	local currentData = playerZones[player]
	if currentData and currentData.currentZone then
		SpatialPartitioner.RemovePlayerFromZone(player, currentData.currentZone)
	end
	playerZones[player] = nil
end

-- Get spatial partitioning statistics
function SpatialPartitioner.GetStats(): {activeZones: number, totalPlayers: number, avgPlayersPerZone: number}
	local activeZones = 0
	local totalPlayersInZones = 0
	
	for zoneKey, zone in pairs(zones) do
		activeZones = activeZones + 1
		for player, _ in pairs(zone.players) do
			totalPlayersInZones = totalPlayersInZones + 1
		end
	end
	
	return {
		activeZones = activeZones,
		totalPlayers = #Players:GetPlayers(),
		playersInZones = totalPlayersInZones,
		avgPlayersPerZone = activeZones > 0 and (totalPlayersInZones / activeZones) or 0
	}
end

-- Get player's current zone info (for debugging)
function SpatialPartitioner.GetPlayerZoneInfo(player: Player): {currentZone: string?, nearbyZones: {string}?, position: Vector3?}
	local data = playerZones[player]
	if not data then return {} end
	
	local character = player.Character
	local position = nil
	if character then
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then position = hrp.Position end
	end
	
	return {
		currentZone = data.currentZone,
		nearbyZones = data.nearbyZones,
		position = position
	}
end

-- Connect to player events
Players.PlayerRemoving:Connect(SpatialPartitioner.OnPlayerLeaving)

return SpatialPartitioner
