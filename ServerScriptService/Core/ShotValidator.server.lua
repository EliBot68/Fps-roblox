--[[
	ShotValidator.lua
	Server-side shot vector validation and camera snapshot tracking
	
	Prevents aimbot and impossible shot angles by tracking player camera snapshots
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logging = require(ReplicatedStorage.Shared.Logging)
local RateLimiter = require(ReplicatedStorage.Shared.RateLimiter)

local ShotValidator = {}

-- Player camera tracking
local playerCameraSnapshots = {} -- [player] = {lastDirection: Vector3, timestamp: number, snapshots: {}}
local MAX_ANGLE_DEVIATION = 35 -- degrees
local MAX_SNAP_SPEED = 180 -- degrees per second
local CAMERA_SNAPSHOT_INTERVAL = 0.1 -- 10Hz camera updates
local MAX_SNAPSHOTS = 50 -- Keep last 50 camera snapshots

-- Initialize camera tracking for player
function ShotValidator.InitializePlayer(player: Player)
	playerCameraSnapshots[player] = {
		lastDirection = Vector3.new(0, 0, -1),
		timestamp = tick(),
		snapshots = {},
		violations = 0
	}
	
	print("[ShotValidator] ✓ Initialized tracking for", player.Name)
end

-- Update player camera snapshot (called from client)
function ShotValidator.UpdateCameraSnapshot(player: Player, lookDirection: Vector3)
	local cameraData = playerCameraSnapshots[player]
	if not cameraData then
		ShotValidator.InitializePlayer(player)
		cameraData = playerCameraSnapshots[player]
	end
	
	local currentTime = tick()
	local deltaTime = currentTime - cameraData.timestamp
	
	-- Rate limit camera updates
	if not RateLimiter.CheckLimit(player, "CameraUpdate", 15) then -- 15 updates per second max
		return false
	end
	
	-- Validate look direction
	if lookDirection.Magnitude < 0.9 or lookDirection.Magnitude > 1.1 then
		warn("[ShotValidator] Invalid look direction magnitude for", player.Name, ":", lookDirection.Magnitude)
		return false
	end
	
	-- Check for impossible camera snap speed
	if cameraData.lastDirection then
		local angleDifference = math.deg(math.acos(cameraData.lastDirection:Dot(lookDirection)))
		local snapSpeed = angleDifference / deltaTime
		
		if snapSpeed > MAX_SNAP_SPEED and deltaTime > 0.01 then -- Ignore very small deltaTime
			warn("[ShotValidator] Impossible camera snap for", player.Name, ":", snapSpeed, "deg/s")
			cameraData.violations = cameraData.violations + 1
			
			if cameraData.violations > 5 then
				player:Kick("Detected impossible camera movements")
				return false
			end
		end
	end
	
	-- Store snapshot
	table.insert(cameraData.snapshots, {
		direction = lookDirection,
		timestamp = currentTime
	})
	
	-- Limit snapshot history
	if #cameraData.snapshots > MAX_SNAPSHOTS then
		table.remove(cameraData.snapshots, 1)
	end
	
	-- Update tracking data
	cameraData.lastDirection = lookDirection
	cameraData.timestamp = currentTime
	
	return true
end

-- Validate shot vector against recent camera snapshots
function ShotValidator.ValidateShotVector(player: Player, shotOrigin: Vector3, shotDirection: Vector3): boolean
	local cameraData = playerCameraSnapshots[player]
	if not cameraData or #cameraData.snapshots == 0 then
		warn("[ShotValidator] No camera data for", player.Name)
		return false
	end
	
	-- Validate shot direction magnitude
	if shotDirection.Magnitude < 0.9 or shotDirection.Magnitude > 1.1 then
		warn("[ShotValidator] Invalid shot direction magnitude for", player.Name)
		return false
	end
	
	-- Find closest camera snapshot in time
	local shotTime = tick()
	local closestSnapshot = nil
	local minTimeDiff = math.huge
	
	for _, snapshot in ipairs(cameraData.snapshots) do
		local timeDiff = math.abs(shotTime - snapshot.timestamp)
		if timeDiff < minTimeDiff then
			minTimeDiff = timeDiff
			closestSnapshot = snapshot
		end
	end
	
	if not closestSnapshot then
		warn("[ShotValidator] No camera snapshot found for", player.Name)
		return false
	end
	
	-- Check if shot was taken too long after camera update
	if minTimeDiff > 0.5 then -- 500ms tolerance
		warn("[ShotValidator] Shot too far from camera snapshot for", player.Name, ":", minTimeDiff, "seconds")
		return false
	end
	
	-- Calculate angle between shot direction and camera direction
	local dotProduct = shotDirection:Dot(closestSnapshot.direction)
	dotProduct = math.max(-1, math.min(1, dotProduct)) -- Clamp for acos
	local angleDifference = math.deg(math.acos(dotProduct))
	
	-- Check if shot deviates too much from camera direction
	if angleDifference > MAX_ANGLE_DEVIATION then
		warn("[ShotValidator] Shot angle deviation too large for", player.Name, ":", angleDifference, "degrees")
		
		cameraData.violations = cameraData.violations + 1
		
		-- Log violation
		Logging.Event("ShotVectorViolation", {
			userId = player.UserId,
			angleDiff = angleDifference,
			timeDiff = minTimeDiff,
			violations = cameraData.violations
		})
		
		-- Progressive punishment
		if cameraData.violations > 10 then
			player:Kick("Detected impossible shot angles")
		elseif cameraData.violations > 5 then
			-- Send warning to player
			local UIEvents = ReplicatedStorage.RemoteEvents.UIEvents
			local warningRemote = UIEvents:FindFirstChild("AntiCheatWarning")
			if warningRemote then
				warningRemote:FireClient(player, "Warning: Suspicious aiming detected")
			end
		end
		
		return false
	end
	
	return true
end

-- Get shot validation statistics for player
function ShotValidator.GetPlayerStats(player: Player): {violations: number, snapshots: number, lastUpdate: number}
	local cameraData = playerCameraSnapshots[player]
	if not cameraData then
		return {violations = 0, snapshots = 0, lastUpdate = 0}
	end
	
	return {
		violations = cameraData.violations,
		snapshots = #cameraData.snapshots,
		lastUpdate = cameraData.timestamp
	}
end

-- Clean up player data on leave
local function onPlayerLeaving(player)
	playerCameraSnapshots[player] = nil
end

-- Connect events
Players.PlayerRemoving:Connect(onPlayerLeaving)

return ShotValidator
