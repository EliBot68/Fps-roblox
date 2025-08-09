--[[
	TeleportValidator.lua
	Teleport whitelist and rate validation system
	
	Prevents teleport exploits by maintaining a whitelist of valid teleport locations
	and enforcing rate limits on teleportation
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RateLimiter = require(ReplicatedStorage.Shared.RateLimiter)
local Logging = require(ReplicatedStorage.Shared.Logging)

local TeleportValidator = {}

-- Teleport whitelist - valid teleport destinations
local TELEPORT_WHITELIST = {
	-- Lobby spawn points
	["LobbySpawn1"] = Vector3.new(0, 5, 0),
	["LobbySpawn2"] = Vector3.new(10, 5, 0),
	["LobbySpawn3"] = Vector3.new(-10, 5, 0),
	
	-- Map spawn points (these would be populated dynamically)
	["MapSpawn_Factory_1"] = Vector3.new(100, 10, 100),
	["MapSpawn_Factory_2"] = Vector3.new(120, 10, 100),
	["MapSpawn_Rooftops_1"] = Vector3.new(200, 50, 200),
	["MapSpawn_Rooftops_2"] = Vector3.new(220, 50, 200),
	
	-- Shop and UI interaction points
	["ShopTeleport"] = Vector3.new(5, 5, 15),
	["LeaderboardArea"] = Vector3.new(-5, 5, 15),
	["TrainingArea"] = Vector3.new(0, 5, 25),
}

-- Dynamic teleport zones (areas where teleportation is allowed)
local TELEPORT_ZONES = {
	{
		name = "LobbyZone",
		center = Vector3.new(0, 5, 0),
		radius = 50,
		allowDynamic = true -- Allow teleports within this zone
	},
	{
		name = "TrainingZone", 
		center = Vector3.new(0, 5, 25),
		radius = 20,
		allowDynamic = true
	}
}

-- Player teleport tracking
local playerTeleportData = {} -- [player] = {lastTeleport: number, teleportCount: number, violations: number}

-- Rate limiting for teleports
local TELEPORT_COOLDOWN = 2.0 -- 2 seconds between teleports
local MAX_TELEPORTS_PER_MINUTE = 10
local MAX_TELEPORT_DISTANCE = 200 -- Max distance for a single teleport

-- Initialize teleport tracking for player
function TeleportValidator.InitializePlayer(player: Player)
	playerTeleportData[player] = {
		lastTeleport = 0,
		teleportCount = 0,
		violations = 0,
		lastPosition = nil
	}
	
	print("[TeleportValidator] ✓ Initialized tracking for", player.Name)
end

-- Add dynamic teleport location to whitelist
function TeleportValidator.AddTeleportLocation(locationName: string, position: Vector3)
	TELEPORT_WHITELIST[locationName] = position
	Logging.Event("TeleportWhitelistAdd", {location = locationName, position = position})
end

-- Remove teleport location from whitelist
function TeleportValidator.RemoveTeleportLocation(locationName: string)
	TELEPORT_WHITELIST[locationName] = nil
	Logging.Event("TeleportWhitelistRemove", {location = locationName})
end

-- Check if position is within any teleport zone
local function isInTeleportZone(position: Vector3): boolean
	for _, zone in ipairs(TELEPORT_ZONES) do
		local distance = (position - zone.center).Magnitude
		if distance <= zone.radius then
			return zone.allowDynamic
		end
	end
	return false
end

-- Check if teleport destination is in whitelist
local function isWhitelistedDestination(destination: Vector3, tolerance: number?): boolean
	local maxDistance = tolerance or 5 -- 5 stud tolerance
	
	for locationName, whitelistPos in pairs(TELEPORT_WHITELIST) do
		local distance = (destination - whitelistPos).Magnitude
		if distance <= maxDistance then
			return true, locationName
		end
	end
	
	return false, nil
end

-- Validate teleport request
function TeleportValidator.ValidateTeleport(player: Player, destination: Vector3, teleportType: string?): boolean
	local teleportData = playerTeleportData[player]
	if not teleportData then
		TeleportValidator.InitializePlayer(player)
		teleportData = playerTeleportData[player]
	end
	
	local currentTime = tick()
	
	-- Rate limiting check
	if not RateLimiter.CheckLimit(player, "Teleport", MAX_TELEPORTS_PER_MINUTE / 60) then
		warn("[TeleportValidator] Rate limit exceeded for", player.Name)
		return false
	end
	
	-- Cooldown check
	if currentTime - teleportData.lastTeleport < TELEPORT_COOLDOWN then
		warn("[TeleportValidator] Teleport cooldown not met for", player.Name)
		return false
	end
	
	-- Distance validation (prevent impossible teleports)
	if teleportData.lastPosition then
		local teleportDistance = (destination - teleportData.lastPosition).Magnitude
		if teleportDistance > MAX_TELEPORT_DISTANCE then
			warn("[TeleportValidator] Teleport distance too large for", player.Name, ":", teleportDistance)
			teleportData.violations = teleportData.violations + 1
			
			if teleportData.violations > 3 then
				player:Kick("Detected impossible teleportation")
				return false
			end
		end
	end
	
	-- Whitelist validation
	local isWhitelisted, locationName = isWhitelistedDestination(destination, 10)
	local inZone = isInTeleportZone(destination)
	
	if not isWhitelisted and not inZone then
		warn("[TeleportValidator] Non-whitelisted teleport attempted by", player.Name, "to", destination)
		teleportData.violations = teleportData.violations + 1
		
		-- Log violation
		Logging.Event("TeleportViolation", {
			userId = player.UserId,
			destination = destination,
			violations = teleportData.violations,
			type = "non_whitelisted"
		})
		
		-- Progressive punishment
		if teleportData.violations > 5 then
			player:Kick("Detected teleport exploits")
		elseif teleportData.violations > 2 then
			-- Send warning
			local UIEvents = ReplicatedStorage.RemoteEvents.UIEvents
			local warningRemote = UIEvents:FindFirstChild("AntiCheatWarning")
			if warningRemote then
				warningRemote:FireClient(player, "Warning: Invalid teleport detected")
			end
		end
		
		return false
	end
	
	-- Update tracking data
	teleportData.lastTeleport = currentTime
	teleportData.teleportCount = teleportData.teleportCount + 1
	teleportData.lastPosition = destination
	
	-- Log successful teleport
	Logging.Event("ValidTeleport", {
		userId = player.UserId,
		destination = destination,
		locationName = locationName,
		type = teleportType or "unknown"
	})
	
	return true
end

-- Force teleport a player (admin/system use)
function TeleportValidator.ForceTeleport(player: Player, destination: Vector3, reason: string)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return false
	end
	
	character.HumanoidRootPart.CFrame = CFrame.new(destination)
	
	-- Update tracking without validation
	local teleportData = playerTeleportData[player]
	if teleportData then
		teleportData.lastPosition = destination
	end
	
	Logging.Event("ForceTeleport", {
		userId = player.UserId,
		destination = destination,
		reason = reason
	})
	
	return true
end

-- Get teleport statistics for player
function TeleportValidator.GetPlayerStats(player: Player): {teleportCount: number, violations: number, lastTeleport: number}
	local teleportData = playerTeleportData[player]
	if not teleportData then
		return {teleportCount = 0, violations = 0, lastTeleport = 0}
	end
	
	return {
		teleportCount = teleportData.teleportCount,
		violations = teleportData.violations,
		lastTeleport = teleportData.lastTeleport
	}
end

-- Get current whitelist (for admin tools)
function TeleportValidator.GetWhitelist(): {[string]: Vector3}
	return TELEPORT_WHITELIST
end

-- Clean up player data on leave
local function onPlayerLeaving(player)
	playerTeleportData[player] = nil
end

-- Connect events
Players.PlayerRemoving:Connect(onPlayerLeaving)

return TeleportValidator
