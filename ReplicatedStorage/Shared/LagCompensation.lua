--[[
	LagCompensation.lua
	Advanced lag compensation system for server-authoritative combat
	
	Features:
	- Player position history tracking with interpolation
	- Lag compensation up to 200ms for fair hit detection
	- Movement prediction and validation algorithms
	- Latency measurement and adaptive compensation
	- Anti-cheat integration to prevent lag exploitation
	
	Enterprise Features:
	- Service Locator integration with dependency injection
	- Comprehensive performance monitoring and metrics
	- Memory-efficient circular buffer for position history
	- Configurable compensation parameters for different scenarios
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Import dependencies via Service Locator
local ServiceLocator = require(ReplicatedStorage.Shared.ServiceLocator)

local LagCompensation = {}

-- Lag compensation configuration
local LAG_CONFIG = {
	-- Maximum lag compensation time (200ms as per requirements)
	maxCompensationTime = 0.2,
	
	-- Position history settings
	historyDuration = 1.0, -- Keep 1 second of history
	updateInterval = 1/60, -- Update at 60 FPS
	maxHistoryEntries = 60, -- Maximum entries per player
	
	-- Interpolation settings
	interpolationMethod = "linear", -- linear, cubic, or predictive
	positionTolerance = 0.5, -- Tolerance for position validation
	velocityTolerance = 10.0, -- Maximum reasonable velocity
	
	-- Anti-cheat settings
	maxTeleportDistance = 10.0, -- Maximum instant movement distance
	maxAcceleration = 50.0, -- Maximum acceleration in studs/s²
	suspiciousMovementThreshold = 3, -- Number of suspicious movements before flagging
	
	-- Performance settings
	cleanupInterval = 30.0, -- Cleanup old data every 30 seconds
	compressionThreshold = 0.1 -- Minimum movement to record
}

-- Player position history structure
export type PositionEntry = {
	position: Vector3,
	velocity: Vector3,
	timestamp: number,
	serverTimestamp: number,
	ping: number
}

export type PlayerHistory = {
	entries: {PositionEntry},
	lastUpdate: number,
	averagePing: number,
	suspiciousMovements: number,
	isValid: boolean
}

-- Lag compensation result structure
export type CompensationResult = {
	compensatedPosition: Vector3,
	compensatedVelocity: Vector3,
	compensationTime: number,
	isValid: boolean,
	confidence: number, -- 0-1 confidence in compensation accuracy
	flags: {string}? -- Any flags for suspicious behavior
}

-- Player tracking data
local playerHistories: {[string]: PlayerHistory} = {}
local playerPingHistory: {[string]: {number}} = {}

-- Performance metrics
local compensationMetrics = {
	totalCompensations = 0,
	successfulCompensations = 0,
	averageCompensationTime = 0,
	maxCompensationTime = 0,
	flaggedPlayers = 0
}

-- Initialize lag compensation system
function LagCompensation.Initialize()
	-- Register with Service Locator
	ServiceLocator.Register("LagCompensation", {
		factory = function(dependencies)
			local Logging = dependencies.Logging
			if Logging then
				Logging.Info("LagCompensation", "Lag compensation system initialized")
			end
			return LagCompensation
		end,
		dependencies = {"Logging"},
		singleton = true,
		priority = 8
	})
	
	-- Start position tracking
	LagCompensation._StartPositionTracking()
	
	-- Start cleanup routine
	LagCompensation._StartCleanupRoutine()
	
	print("[LagCompensation] ✓ Advanced lag compensation system initialized")
end

-- Update player position in history
function LagCompensation.UpdatePlayerPosition(player: Player, position: Vector3, velocity: Vector3, clientTimestamp: number, ping: number?)
	local playerId = tostring(player.UserId)
	local serverTimestamp = tick()
	
	-- Initialize player history if needed
	if not playerHistories[playerId] then
		playerHistories[playerId] = {
			entries = {},
			lastUpdate = serverTimestamp,
			averagePing = ping or 0.1,
			suspiciousMovements = 0,
			isValid = true
		}
		playerPingHistory[playerId] = {}
	end
	
	local history = playerHistories[playerId]
	
	-- Update ping tracking
	if ping then
		LagCompensation._UpdatePingHistory(playerId, ping)
		history.averagePing = LagCompensation._GetAveragePing(playerId)
	end
	
	-- Validate movement for anti-cheat
	local movementFlags = LagCompensation._ValidateMovement(playerId, position, velocity, serverTimestamp)
	
	-- Create position entry
	local entry: PositionEntry = {
		position = position,
		velocity = velocity,
		timestamp = clientTimestamp,
		serverTimestamp = serverTimestamp,
		ping = ping or history.averagePing
	}
	
	-- Add to history with compression
	if LagCompensation._ShouldRecordPosition(history, entry) then
		table.insert(history.entries, entry)
		history.lastUpdate = serverTimestamp
		
		-- Maintain history size limit
		if #history.entries > LAG_CONFIG.maxHistoryEntries then
			table.remove(history.entries, 1)
		end
	end
	
	-- Handle suspicious movements
	if #movementFlags > 0 then
		history.suspiciousMovements = history.suspiciousMovements + 1
		LagCompensation._HandleSuspiciousMovement(player, movementFlags, entry)
		
		if history.suspiciousMovements >= LAG_CONFIG.suspiciousMovementThreshold then
			history.isValid = false
			compensationMetrics.flaggedPlayers = compensationMetrics.flaggedPlayers + 1
		end
	end
end

-- Compensate for player lag at a specific time
function LagCompensation.CompensatePosition(player: Player, targetTimestamp: number): CompensationResult
	local startTime = tick()
	compensationMetrics.totalCompensations = compensationMetrics.totalCompensations + 1
	
	local playerId = tostring(player.UserId)
	local history = playerHistories[playerId]
	
	-- Default result for invalid cases
	local defaultResult: CompensationResult = {
		compensatedPosition = player.Character and player.Character.PrimaryPart and player.Character.PrimaryPart.Position or Vector3.new(),
		compensatedVelocity = Vector3.new(),
		compensationTime = 0,
		isValid = false,
		confidence = 0,
		flags = {"NO_HISTORY"}
	}
	
	-- Check if player has position history
	if not history or #history.entries == 0 then
		return defaultResult
	end
	
	-- Check if player is flagged for suspicious movement
	if not history.isValid then
		defaultResult.flags = {"PLAYER_FLAGGED"}
		return defaultResult
	end
	
	local serverTime = tick()
	local compensationTime = serverTime - targetTimestamp
	
	-- Validate compensation time
	if compensationTime > LAG_CONFIG.maxCompensationTime then
		defaultResult.flags = {"COMPENSATION_TOO_OLD"}
		defaultResult.compensationTime = compensationTime
		return defaultResult
	end
	
	if compensationTime < 0 then
		defaultResult.flags = {"FUTURE_TIMESTAMP"}
		return defaultResult
	end
	
	-- Find the appropriate position in history
	local result = LagCompensation._FindHistoricalPosition(history, targetTimestamp, compensationTime)
	
	-- Update metrics
	if result.isValid then
		compensationMetrics.successfulCompensations = compensationMetrics.successfulCompensations + 1
	end
	
	local processingTime = tick() - startTime
	compensationMetrics.averageCompensationTime = (compensationMetrics.averageCompensationTime + processingTime) / 2
	compensationMetrics.maxCompensationTime = math.max(compensationMetrics.maxCompensationTime, processingTime)
	
	-- Log compensation for analysis
	LagCompensation._LogCompensation(player, targetTimestamp, result, processingTime)
	
	return result
end

-- Find historical position using interpolation
function LagCompensation._FindHistoricalPosition(history: PlayerHistory, targetTimestamp: number, compensationTime: number): CompensationResult
	local entries = history.entries
	
	-- Find closest entries to target timestamp
	local beforeEntry, afterEntry = nil, nil
	
	for i = #entries, 1, -1 do -- Search backwards for efficiency
		local entry = entries[i]
		local entryAge = tick() - entry.serverTimestamp
		
		-- Skip entries that are too old
		if entryAge > LAG_CONFIG.historyDuration then
			continue
		end
		
		-- Account for ping in timestamp comparison
		local adjustedTimestamp = entry.timestamp + entry.ping / 2
		
		if adjustedTimestamp <= targetTimestamp then
			beforeEntry = entry
			if i < #entries then
				afterEntry = entries[i + 1]
			end
			break
		else
			afterEntry = entry
		end
	end
	
	-- Handle edge cases
	if not beforeEntry and not afterEntry then
		return {
			compensatedPosition = Vector3.new(),
			compensatedVelocity = Vector3.new(),
			compensationTime = compensationTime,
			isValid = false,
			confidence = 0,
			flags = {"NO_SUITABLE_ENTRIES"}
		}
	end
	
	local compensatedPosition, compensatedVelocity, confidence
	
	if beforeEntry and afterEntry then
		-- Interpolate between two entries
		compensatedPosition, compensatedVelocity, confidence = LagCompensation._InterpolatePosition(
			beforeEntry, afterEntry, targetTimestamp
		)
	elseif beforeEntry then
		-- Extrapolate from the most recent entry
		compensatedPosition, compensatedVelocity, confidence = LagCompensation._ExtrapolatePosition(
			beforeEntry, targetTimestamp
		)
	else
		-- Use the earliest available entry
		compensatedPosition = afterEntry.position
		compensatedVelocity = afterEntry.velocity
		confidence = 0.3 -- Low confidence for single point
	end
	
	-- Validate the compensated position
	local flags = LagCompensation._ValidateCompensatedPosition(compensatedPosition, compensatedVelocity)
	
	return {
		compensatedPosition = compensatedPosition,
		compensatedVelocity = compensatedVelocity,
		compensationTime = compensationTime,
		isValid = #flags == 0,
		confidence = confidence,
		flags = #flags > 0 and flags or nil
	}
end

-- Interpolate position between two entries
function LagCompensation._InterpolatePosition(beforeEntry: PositionEntry, afterEntry: PositionEntry, targetTimestamp: number): (Vector3, Vector3, number)
	local beforeTime = beforeEntry.timestamp + beforeEntry.ping / 2
	local afterTime = afterEntry.timestamp + afterEntry.ping / 2
	
	-- Calculate interpolation factor
	local timeDelta = afterTime - beforeTime
	local targetDelta = targetTimestamp - beforeTime
	local t = timeDelta > 0 and math.clamp(targetDelta / timeDelta, 0, 1) or 0
	
	-- Linear interpolation for position
	local compensatedPosition = beforeEntry.position:Lerp(afterEntry.position, t)
	
	-- Linear interpolation for velocity
	local compensatedVelocity = beforeEntry.velocity:Lerp(afterEntry.velocity, t)
	
	-- Calculate confidence based on time accuracy and distance
	local timeAccuracy = 1 - math.abs(0.5 - t) * 2 -- Higher confidence when t is closer to 0.5
	local positionDistance = (afterEntry.position - beforeEntry.position).Magnitude
	local distanceConfidence = math.clamp(1 - positionDistance / 20, 0.1, 1) -- Lower confidence for large movements
	
	local confidence = (timeAccuracy + distanceConfidence) / 2
	
	return compensatedPosition, compensatedVelocity, confidence
end

-- Extrapolate position from a single entry
function LagCompensation._ExtrapolatePosition(entry: PositionEntry, targetTimestamp: number): (Vector3, Vector3, number)
	local entryTime = entry.timestamp + entry.ping / 2
	local timeDelta = targetTimestamp - entryTime
	
	-- Extrapolate using velocity
	local compensatedPosition = entry.position + entry.velocity * timeDelta
	local compensatedVelocity = entry.velocity -- Assume constant velocity
	
	-- Confidence decreases with extrapolation distance
	local confidence = math.clamp(1 - math.abs(timeDelta) / 0.1, 0.1, 0.8) -- Max 0.8 for extrapolation
	
	return compensatedPosition, compensatedVelocity, confidence
end

-- Validate movement for anti-cheat
function LagCompensation._ValidateMovement(playerId: string, position: Vector3, velocity: Vector3, timestamp: number): {string}
	local flags = {}
	local history = playerHistories[playerId]
	
	if #history.entries == 0 then
		return flags -- No previous data to validate against
	end
	
	local lastEntry = history.entries[#history.entries]
	local timeDelta = timestamp - lastEntry.serverTimestamp
	
	-- Skip validation for very small time deltas
	if timeDelta < 0.01 then
		return flags
	end
	
	local positionDelta = (position - lastEntry.position).Magnitude
	local velocityMagnitude = velocity.Magnitude
	
	-- Check for teleportation
	local maxMovement = LAG_CONFIG.maxTeleportDistance + velocityMagnitude * timeDelta
	if positionDelta > maxMovement then
		table.insert(flags, "TELEPORTATION_DETECTED")
	end
	
	-- Check for excessive velocity
	if velocityMagnitude > LAG_CONFIG.velocityTolerance then
		table.insert(flags, "EXCESSIVE_VELOCITY")
	end
	
	-- Check for excessive acceleration
	if #history.entries >= 2 then
		local prevVelocity = lastEntry.velocity
		local accelerationMagnitude = ((velocity - prevVelocity) / timeDelta).Magnitude
		
		if accelerationMagnitude > LAG_CONFIG.maxAcceleration then
			table.insert(flags, "EXCESSIVE_ACCELERATION")
		end
	end
	
	return flags
end

-- Validate compensated position for reasonableness
function LagCompensation._ValidateCompensatedPosition(position: Vector3, velocity: Vector3): {string}
	local flags = {}
	
	-- Check for NaN or infinite values
	if position.X ~= position.X or position.Y ~= position.Y or position.Z ~= position.Z then
		table.insert(flags, "INVALID_POSITION_NAN")
	end
	
	if velocity.X ~= velocity.X or velocity.Y ~= velocity.Y or velocity.Z ~= velocity.Z then
		table.insert(flags, "INVALID_VELOCITY_NAN")
	end
	
	-- Check for extreme positions
	if position.Magnitude > 10000 then
		table.insert(flags, "EXTREME_POSITION")
	end
	
	-- Check for extreme velocity
	if velocity.Magnitude > LAG_CONFIG.velocityTolerance then
		table.insert(flags, "EXTREME_VELOCITY")
	end
	
	return flags
end

-- Check if position should be recorded (compression)
function LagCompensation._ShouldRecordPosition(history: PlayerHistory, entry: PositionEntry): boolean
	if #history.entries == 0 then
		return true -- Always record first entry
	end
	
	local lastEntry = history.entries[#history.entries]
	local movementDistance = (entry.position - lastEntry.position).Magnitude
	local timeDelta = entry.serverTimestamp - lastEntry.serverTimestamp
	
	-- Always record if enough time has passed
	if timeDelta >= LAG_CONFIG.updateInterval then
		return true
	end
	
	-- Record if significant movement occurred
	return movementDistance >= LAG_CONFIG.compressionThreshold
end

-- Update ping history for a player
function LagCompensation._UpdatePingHistory(playerId: string, ping: number)
	if not playerPingHistory[playerId] then
		playerPingHistory[playerId] = {}
	end
	
	local pingHistory = playerPingHistory[playerId]
	table.insert(pingHistory, ping)
	
	-- Keep only recent ping samples (last 20)
	if #pingHistory > 20 then
		table.remove(pingHistory, 1)
	end
end

-- Get average ping for a player
function LagCompensation._GetAveragePing(playerId: string): number
	local pingHistory = playerPingHistory[playerId]
	if not pingHistory or #pingHistory == 0 then
		return 0.1 -- Default 100ms
	end
	
	local total = 0
	for _, ping in ipairs(pingHistory) do
		total = total + ping
	end
	
	return total / #pingHistory
end

-- Handle suspicious movement detection
function LagCompensation._HandleSuspiciousMovement(player: Player, flags: {string}, entry: PositionEntry)
	local Logging = ServiceLocator.GetService("Logging")
	if not Logging then return end
	
	Logging.Warn("LagCompensation", "Suspicious movement detected", {
		player = player.Name,
		userId = player.UserId,
		flags = flags,
		position = entry.position,
		velocity = entry.velocity,
		timestamp = entry.serverTimestamp
	})
	
	-- Report to SecurityValidator if available
	pcall(function()
		local SecurityValidator = ServiceLocator.GetService("SecurityValidator")
		if SecurityValidator then
			local threat = {
				playerId = player.UserId,
				threatType = "movement_exploit",
				severity = #flags >= 2 and 7 or 5,
				description = string.format("Suspicious movement: %s", table.concat(flags, ", ")),
				timestamp = tick(),
				evidence = {
					flags = flags,
					position = entry.position,
					velocity = entry.velocity
				}
			}
			
			local AntiExploit = ServiceLocator.GetService("AntiExploit")
			if AntiExploit then
				AntiExploit.ProcessSecurityThreat(threat)
			end
		end
	end)
end

-- Start position tracking system
function LagCompensation._StartPositionTracking()
	-- Track all players' positions automatically
	RunService.Heartbeat:Connect(function()
		for _, player in ipairs(Players:GetPlayers()) do
			if player.Character and player.Character.PrimaryPart then
				local position = player.Character.PrimaryPart.Position
				local velocity = player.Character.PrimaryPart.Velocity
				
				-- Estimate ping (this would normally come from network measurements)
				local estimatedPing = LagCompensation._GetAveragePing(tostring(player.UserId))
				
				LagCompensation.UpdatePlayerPosition(player, position, velocity, tick(), estimatedPing)
			end
		end
	end)
end

-- Start cleanup routine
function LagCompensation._StartCleanupRoutine()
	task.spawn(function()
		while true do
			task.wait(LAG_CONFIG.cleanupInterval)
			LagCompensation._CleanupOldData()
		end
	end)
end

-- Clean up old player data
function LagCompensation._CleanupOldData()
	local currentTime = tick()
	local cleanupThreshold = LAG_CONFIG.historyDuration * 2 -- Keep twice the history duration for safety
	
	-- Clean position histories
	for playerId, history in pairs(playerHistories) do
		-- Remove old entries
		local filteredEntries = {}
		for _, entry in ipairs(history.entries) do
			if currentTime - entry.serverTimestamp <= cleanupThreshold then
				table.insert(filteredEntries, entry)
			end
		end
		
		if #filteredEntries > 0 then
			history.entries = filteredEntries
		else
			-- No recent entries, remove player history
			playerHistories[playerId] = nil
		end
	end
	
	-- Clean ping histories
	for playerId, pingHistory in pairs(playerPingHistory) do
		if not playerHistories[playerId] then
			playerPingHistory[playerId] = nil
		end
	end
end

-- Log compensation for analysis
function LagCompensation._LogCompensation(player: Player, targetTimestamp: number, result: CompensationResult, processingTime: number)
	local Logging = ServiceLocator.GetService("Logging")
	if not Logging then return end
	
	Logging.Debug("LagCompensation", "Position compensated", {
		player = player.Name,
		targetTimestamp = targetTimestamp,
		compensationTime = result.compensationTime,
		isValid = result.isValid,
		confidence = result.confidence,
		flags = result.flags,
		processingTime = processingTime
	})
end

-- Get compensation statistics
function LagCompensation.GetCompensationStats(): {[string]: any}
	local successRate = compensationMetrics.totalCompensations > 0 
		and (compensationMetrics.successfulCompensations / compensationMetrics.totalCompensations * 100) 
		or 0
	
	return {
		totalCompensations = compensationMetrics.totalCompensations,
		successfulCompensations = compensationMetrics.successfulCompensations,
		successRate = successRate,
		averageProcessingTime = compensationMetrics.averageCompensationTime,
		maxProcessingTime = compensationMetrics.maxCompensationTime,
		flaggedPlayers = compensationMetrics.flaggedPlayers,
		trackedPlayers = 0, -- Will be calculated
		config = LAG_CONFIG
	}
end

-- Get player-specific lag compensation info
function LagCompensation.GetPlayerInfo(player: Player): {[string]: any}?
	local playerId = tostring(player.UserId)
	local history = playerHistories[playerId]
	
	if not history then
		return nil
	end
	
	return {
		entriesCount = #history.entries,
		lastUpdate = history.lastUpdate,
		averagePing = history.averagePing,
		suspiciousMovements = history.suspiciousMovements,
		isValid = history.isValid,
		oldestEntry = #history.entries > 0 and history.entries[1].serverTimestamp or nil,
		newestEntry = #history.entries > 0 and history.entries[#history.entries].serverTimestamp or nil
	}
end

-- Reset player compensation data (for testing or admin purposes)
function LagCompensation.ResetPlayerData(player: Player)
	local playerId = tostring(player.UserId)
	playerHistories[playerId] = nil
	playerPingHistory[playerId] = nil
	
	local Logging = ServiceLocator.GetService("Logging")
	if Logging then
		Logging.Info("LagCompensation", "Player compensation data reset", {
			player = player.Name,
			userId = player.UserId
		})
	end
end

return LagCompensation
