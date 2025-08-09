-- MatchRecording.server.lua
-- Match recording metadata logs for admin review

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logging = require(ReplicatedStorage.Shared.Logging)

local MatchRecording = {}

-- DataStore for match recordings
local matchRecordingsStore = DataStoreService:GetDataStore("MatchRecordings")

-- Current match state
local currentMatch = nil
local recordingEnabled = true

-- Event tracking
local eventLog = {}
local playerPositions = {}
local weaponStates = {}

function MatchRecording.StartMatch(matchConfig)
	if not recordingEnabled then return end
	
	currentMatch = {
		id = game:GetService("HttpService"):GenerateGUID(false),
		serverId = game.JobId,
		startTime = os.time(),
		endTime = nil,
		config = matchConfig or {},
		players = {},
		events = {},
		positions = {},
		weapons = {},
		statistics = {
			totalKills = 0,
			totalDeaths = 0,
			totalDamage = 0,
			totalShots = 0,
			totalHits = 0
		},
		flags = {
			suspicious = false,
			highActivity = false,
			adminReviewed = false
		}
	}
	
	-- Initialize player data
	for _, player in ipairs(Players:GetPlayers()) do
		MatchRecording.AddPlayer(player)
	end
	
	-- Start position tracking
	MatchRecording.StartPositionTracking()
	
	Logging.Event("MatchRecordingStarted", {
		matchId = currentMatch.id,
		players = #currentMatch.players
	})
end

function MatchRecording.EndMatch(results)
	if not currentMatch then return end
	
	currentMatch.endTime = os.time()
	currentMatch.duration = currentMatch.endTime - currentMatch.startTime
	currentMatch.results = results or {}
	
	-- Calculate final statistics
	MatchRecording.CalculateFinalStats()
	
	-- Check for suspicious activity
	MatchRecording.AnalyzeSuspiciousActivity()
	
	-- Save to DataStore
	MatchRecording.SaveMatch()
	
	Logging.Event("MatchRecordingEnded", {
		matchId = currentMatch.id,
		duration = currentMatch.duration,
		suspicious = currentMatch.flags.suspicious
	})
	
	currentMatch = nil
	eventLog = {}
	playerPositions = {}
	weaponStates = {}
end

function MatchRecording.AddPlayer(player)
	if not currentMatch then return end
	
	local playerData = {
		userId = player.UserId,
		name = player.Name,
		joinTime = os.time(),
		leaveTime = nil,
		statistics = {
			kills = 0,
			deaths = 0,
			damage = 0,
			shots = 0,
			hits = 0,
			headshots = 0,
			accuracy = 0,
			kdr = 0
		},
		weapons = {},
		positions = {},
		flags = {
			speedHacking = false,
			aimbotSuspected = false,
			wallhackSuspected = false,
			highAccuracy = false
		}
	}
	
	currentMatch.players[player.UserId] = playerData
	playerPositions[player.UserId] = {}
end

function MatchRecording.RemovePlayer(player)
	if not currentMatch or not currentMatch.players[player.UserId] then return end
	
	currentMatch.players[player.UserId].leaveTime = os.time()
end

function MatchRecording.LogEvent(eventType, data)
	if not currentMatch then return end
	
	local event = {
		type = eventType,
		timestamp = tick(),
		gameTime = tick() - (currentMatch.startTime or tick()),
		data = data or {}
	}
	
	table.insert(currentMatch.events, event)
	
	-- Update player statistics
	if eventType == "player_kill" and data.killer and data.victim then
		local killerData = currentMatch.players[data.killer]
		local victimData = currentMatch.players[data.victim]
		
		if killerData then
			killerData.statistics.kills = killerData.statistics.kills + 1
			currentMatch.statistics.totalKills = currentMatch.statistics.totalKills + 1
		end
		
		if victimData then
			victimData.statistics.deaths = victimData.statistics.deaths + 1
			currentMatch.statistics.totalDeaths = currentMatch.statistics.totalDeaths + 1
		end
	elseif eventType == "weapon_fire" and data.player then
		local playerData = currentMatch.players[data.player]
		if playerData then
			playerData.statistics.shots = playerData.statistics.shots + 1
			currentMatch.statistics.totalShots = currentMatch.statistics.totalShots + 1
		end
	elseif eventType == "weapon_hit" and data.player then
		local playerData = currentMatch.players[data.player]
		if playerData then
			playerData.statistics.hits = playerData.statistics.hits + 1
			playerData.statistics.damage = playerData.statistics.damage + (data.damage or 0)
			currentMatch.statistics.totalHits = currentMatch.statistics.totalHits + 1
			currentMatch.statistics.totalDamage = currentMatch.statistics.totalDamage + (data.damage or 0)
			
			if data.headshot then
				playerData.statistics.headshots = playerData.statistics.headshots + 1
			end
		end
	end
end

function MatchRecording.StartPositionTracking()
	if not currentMatch then return end
	
	-- Track player positions every second
	local positionTracker = RunService.Heartbeat:Connect(function()
		if not currentMatch then return end
		
		local currentTime = tick() - currentMatch.startTime
		
		for userId, playerData in pairs(currentMatch.players) do
			local player = Players:GetPlayerByUserId(userId)
			if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				local position = player.Character.HumanoidRootPart.Position
				local rotation = player.Character.HumanoidRootPart.CFrame.Rotation
				
				table.insert(playerData.positions, {
					time = currentTime,
					position = { X = position.X, Y = position.Y, Z = position.Z },
					rotation = { X = rotation.X, Y = rotation.Y, Z = rotation.Z }
				})
				
				-- Keep only last 1000 positions to manage memory
				if #playerData.positions > 1000 then
					table.remove(playerData.positions, 1)
				end
			end
		end
	end)
	
	-- Disconnect when match ends
	currentMatch.positionTracker = positionTracker
end

function MatchRecording.CalculateFinalStats()
	if not currentMatch then return end
	
	for userId, playerData in pairs(currentMatch.players) do
		local stats = playerData.statistics
		
		-- Calculate accuracy
		if stats.shots > 0 then
			stats.accuracy = (stats.hits / stats.shots) * 100
		end
		
		-- Calculate K/D ratio
		if stats.deaths > 0 then
			stats.kdr = stats.kills / stats.deaths
		else
			stats.kdr = stats.kills
		end
		
		-- Flag high accuracy
		if stats.accuracy > 85 and stats.shots > 20 then
			playerData.flags.highAccuracy = true
			currentMatch.flags.suspicious = true
		end
	end
end

function MatchRecording.AnalyzeSuspiciousActivity()
	if not currentMatch then return end
	
	for userId, playerData in pairs(currentMatch.players) do
		local stats = playerData.statistics
		local flags = playerData.flags
		
		-- Check for impossible statistics
		if stats.accuracy > 95 and stats.shots > 50 then
			flags.aimbotSuspected = true
			currentMatch.flags.suspicious = true
		end
		
		if stats.headshots > stats.kills * 0.8 and stats.kills > 5 then
			flags.aimbotSuspected = true
			currentMatch.flags.suspicious = true
		end
		
		-- Analyze movement patterns for speed hacking
		local suspiciousMovement = MatchRecording.AnalyzeMovement(playerData.positions)
		if suspiciousMovement then
			flags.speedHacking = true
			currentMatch.flags.suspicious = true
		end
	end
	
	-- Check overall match statistics
	local avgAccuracy = 0
	local playerCount = 0
	
	for _, playerData in pairs(currentMatch.players) do
		avgAccuracy = avgAccuracy + playerData.statistics.accuracy
		playerCount = playerCount + 1
	end
	
	if playerCount > 0 then
		avgAccuracy = avgAccuracy / playerCount
		if avgAccuracy > 70 then
			currentMatch.flags.highActivity = true
		end
	end
end

function MatchRecording.AnalyzeMovement(positions)
	if #positions < 10 then return false end
	
	local maxSpeed = 50 -- Maximum reasonable speed
	local suspiciousCount = 0
	
	for i = 2, #positions do
		local prev = positions[i-1]
		local curr = positions[i]
		
		local distance = math.sqrt(
			(curr.position.X - prev.position.X)^2 +
			(curr.position.Y - prev.position.Y)^2 +
			(curr.position.Z - prev.position.Z)^2
		)
		
		local timeDiff = curr.time - prev.time
		if timeDiff > 0 then
			local speed = distance / timeDiff
			if speed > maxSpeed then
				suspiciousCount = suspiciousCount + 1
			end
		end
	end
	
	-- If more than 10% of movements are suspicious
	return suspiciousCount > (#positions * 0.1)
end

function MatchRecording.SaveMatch()
	if not currentMatch then return end
	
	-- Compress position data to save space
	for userId, playerData in pairs(currentMatch.players) do
		-- Only keep every 5th position for storage
		local compressedPositions = {}
		for i = 1, #playerData.positions, 5 do
			table.insert(compressedPositions, playerData.positions[i])
		end
		playerData.positions = compressedPositions
	end
	
	-- Save to DataStore
	pcall(function()
		matchRecordingsStore:SetAsync(currentMatch.id, currentMatch)
	end)
	
	Logging.Event("MatchRecordingSaved", {
		matchId = currentMatch.id,
		suspicious = currentMatch.flags.suspicious,
		players = #currentMatch.players
	})
end

function MatchRecording.GetMatch(matchId)
	local success, result = pcall(function()
		return matchRecordingsStore:GetAsync(matchId)
	end)
	
	return success and result or nil
end

function MatchRecording.GetSuspiciousMatches(limit)
	limit = limit or 10
	-- This would typically use a sorted DataStore in production
	-- For now, return a placeholder structure
	return {}
end

function MatchRecording.FlagForReview(matchId, reason)
	local match = MatchRecording.GetMatch(matchId)
	if not match then return false end
	
	match.flags.adminReviewed = false
	match.flags.flagReason = reason
	match.flags.flagTime = os.time()
	
	pcall(function()
		matchRecordingsStore:SetAsync(matchId, match)
	end)
	
	Logging.Event("MatchFlaggedForReview", {
		matchId = matchId,
		reason = reason
	})
	
	return true
end

-- Integration hooks
function MatchRecording.OnPlayerKill(killer, victim, weapon, headshot)
	MatchRecording.LogEvent("player_kill", {
		killer = killer.UserId,
		victim = victim.UserId,
		weapon = weapon,
		headshot = headshot or false
	})
end

function MatchRecording.OnWeaponFire(player, weapon, position, direction)
	MatchRecording.LogEvent("weapon_fire", {
		player = player.UserId,
		weapon = weapon,
		position = { X = position.X, Y = position.Y, Z = position.Z },
		direction = { X = direction.X, Y = direction.Y, Z = direction.Z }
	})
end

function MatchRecording.OnWeaponHit(player, target, weapon, damage, headshot)
	MatchRecording.LogEvent("weapon_hit", {
		player = player.UserId,
		target = target and target.UserId,
		weapon = weapon,
		damage = damage,
		headshot = headshot or false
	})
end

-- Player event handlers
Players.PlayerAdded:Connect(function(player)
	if currentMatch then
		MatchRecording.AddPlayer(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	if currentMatch then
		MatchRecording.RemovePlayer(player)
	end
end)

return MatchRecording
