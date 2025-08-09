-- NetworkManager.server.lua
-- Enterprise network optimization and connection management

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Logging = require(ReplicatedStorage.Shared.Logging)

local NetworkManager = {}

-- Connection tracking
local connectionMetrics = {}
local networkOptimization = {
	batchSize = 10,
	updateFrequency = 30, -- Hz
	compressionEnabled = true,
	deltaCompression = true
}

-- Remote event batching
local eventBatches = {}
local batchTimer = 0
local BATCH_INTERVAL = 1/30 -- 30Hz

-- Bandwidth monitoring
local bandwidthUsage = {
	incoming = 0,
	outgoing = 0,
	peak = 0,
	lastReset = os.time()
}

function NetworkManager.Initialize()
	-- Set up player connection monitoring
	Players.PlayerAdded:Connect(NetworkManager.OnPlayerJoined)
	Players.PlayerRemoving:Connect(NetworkManager.OnPlayerLeft)
	
	-- Start network optimization systems
	NetworkManager.StartBatchProcessor()
	NetworkManager.StartBandwidthMonitoring()
	NetworkManager.StartLatencyMonitoring()
	
	Logging.Info("NetworkManager initialized - Network optimization active")
end

function NetworkManager.OnPlayerJoined(player)
	connectionMetrics[player.UserId] = {
		joinTime = os.time(),
		ping = 0,
		packetLoss = 0,
		bandwidth = 0,
		lastUpdate = os.time(),
		quality = "unknown"
	}
	
	-- Start monitoring this player's connection
	spawn(function()
		NetworkManager.MonitorPlayerConnection(player)
	end)
	
	Logging.Event("PlayerNetworkJoin", {
		u = player.UserId,
		joinTime = os.time()
	})
end

function NetworkManager.OnPlayerLeft(player)
	local metrics = connectionMetrics[player.UserId]
	if metrics then
		local sessionDuration = os.time() - metrics.joinTime
		
		Logging.Event("PlayerNetworkLeave", {
			u = player.UserId,
			sessionDuration = sessionDuration,
			avgPing = metrics.ping,
			quality = metrics.quality
		})
	end
	
	connectionMetrics[player.UserId] = nil
end

function NetworkManager.MonitorPlayerConnection(player)
	while player.Parent and connectionMetrics[player.UserId] do
		wait(5) -- Check every 5 seconds
		
		local metrics = connectionMetrics[player.UserId]
		if not metrics then break end
		
		-- Simulate ping measurement (would use actual network stats in production)
		local ping = NetworkManager.MeasurePing(player)
		metrics.ping = ping
		metrics.lastUpdate = os.time()
		
		-- Determine connection quality
		if ping < 50 then
			metrics.quality = "excellent"
		elseif ping < 100 then
			metrics.quality = "good"
		elseif ping < 200 then
			metrics.quality = "fair"
		else
			metrics.quality = "poor"
		end
		
		-- Alert if connection is poor
		if ping > GameConfig.Performance.MaxLatencyMS then
			NetworkManager.HandlePoorConnection(player, ping)
		end
	end
end

function NetworkManager.MeasurePing(player)
	-- In a real implementation, this would measure actual network latency
	-- For now, return a simulated value based on various factors
	local basePing = math.random(20, 120)
	local serverLoad = #Players:GetPlayers() / Players.MaxPlayers
	local loadPenalty = serverLoad * 50
	
	return math.floor(basePing + loadPenalty)
end

function NetworkManager.HandlePoorConnection(player, ping)
	Logging.Warn("NetworkManager", player.Name .. " has high latency: " .. ping .. "ms")
	
	-- Offer connection optimization
	NetworkManager.OptimizePlayerConnection(player)
	
	-- Consider suggesting server migration for extremely poor connections
	if ping > 500 then
		local SessionMigration = require(script.Parent.SessionMigration)
		SessionMigration.SuggestServerMigration(player, "high_latency")
	end
end

function NetworkManager.OptimizePlayerConnection(player)
	local metrics = connectionMetrics[player.UserId]
	if not metrics then return end
	
	-- Reduce update frequency for high latency players
	if metrics.ping > 150 then
		NetworkManager.SetPlayerUpdateRate(player, 20) -- 20Hz instead of 30Hz
	end
	
	-- Enable additional compression
	NetworkManager.EnableCompressionForPlayer(player)
end

function NetworkManager.SetPlayerUpdateRate(player, rate)
	-- This would configure per-player update rates in a real implementation
	Logging.Info("NetworkManager", "Set update rate for " .. player.Name .. " to " .. rate .. "Hz")
end

function NetworkManager.EnableCompressionForPlayer(player)
	-- This would enable additional data compression for specific players
	Logging.Info("NetworkManager", "Enabled enhanced compression for " .. player.Name)
end

function NetworkManager.StartBatchProcessor()
	RunService.Heartbeat:Connect(function()
		batchTimer = batchTimer + RunService.Heartbeat:Wait()
		
		if batchTimer >= BATCH_INTERVAL then
			NetworkManager.ProcessEventBatches()
			batchTimer = 0
		end
	end)
end

function NetworkManager.ProcessEventBatches()
	for eventName, batch in pairs(eventBatches) do
		if #batch > 0 then
			-- Process batched events
			NetworkManager.SendBatchedEvents(eventName, batch)
			eventBatches[eventName] = {} -- Clear batch
		end
	end
end

function NetworkManager.SendBatchedEvents(eventName, events)
	-- In a real implementation, this would send batched events to reduce network overhead
	if #events > 0 then
		bandwidthUsage.outgoing = bandwidthUsage.outgoing + (#events * 50) -- Estimate 50 bytes per event
	end
end

function NetworkManager.BatchEvent(eventName, data, targetPlayer)
	if not eventBatches[eventName] then
		eventBatches[eventName] = {}
	end
	
	table.insert(eventBatches[eventName], {
		data = data,
		target = targetPlayer,
		timestamp = os.time()
	})
	
	-- Force send if batch is full
	if #eventBatches[eventName] >= networkOptimization.batchSize then
		NetworkManager.SendBatchedEvents(eventName, eventBatches[eventName])
		eventBatches[eventName] = {}
	end
end

function NetworkManager.StartBandwidthMonitoring()
	spawn(function()
		while true do
			wait(60) -- Monitor every minute
			NetworkManager.UpdateBandwidthMetrics()
		end
	end)
end

function NetworkManager.UpdateBandwidthMetrics()
	local currentTime = os.time()
	local timeSinceReset = currentTime - bandwidthUsage.lastReset
	
	if timeSinceReset >= 60 then -- Reset every minute
		-- Calculate peak bandwidth
		local totalBandwidth = bandwidthUsage.incoming + bandwidthUsage.outgoing
		if totalBandwidth > bandwidthUsage.peak then
			bandwidthUsage.peak = totalBandwidth
		end
		
		-- Log bandwidth usage
		Logging.Event("BandwidthUsage", {
			incoming = bandwidthUsage.incoming,
			outgoing = bandwidthUsage.outgoing,
			total = totalBandwidth,
			playerCount = #Players:GetPlayers()
		})
		
		-- Reset counters
		bandwidthUsage.incoming = 0
		bandwidthUsage.outgoing = 0
		bandwidthUsage.lastReset = currentTime
	end
end

function NetworkManager.StartLatencyMonitoring()
	spawn(function()
		while true do
			wait(30) -- Check every 30 seconds
			NetworkManager.UpdateLatencyStatistics()
		end
	end)
end

function NetworkManager.UpdateLatencyStatistics()
	local totalPing = 0
	local playerCount = 0
	local highLatencyPlayers = 0
	
	for userId, metrics in pairs(connectionMetrics) do
		totalPing = totalPing + metrics.ping
		playerCount = playerCount + 1
		
		if metrics.ping > GameConfig.Performance.MaxLatencyMS then
			highLatencyPlayers = highLatencyPlayers + 1
		end
	end
	
	if playerCount > 0 then
		local averagePing = totalPing / playerCount
		
		Logging.Event("LatencyStatistics", {
			averagePing = averagePing,
			highLatencyPlayers = highLatencyPlayers,
			totalPlayers = playerCount
		})
		
		-- Alert if too many players have high latency
		if highLatencyPlayers / playerCount > 0.3 then -- 30% threshold
			Logging.Warn("NetworkManager", "High percentage of players with poor connections: " .. 
				math.floor((highLatencyPlayers / playerCount) * 100) .. "%")
		end
	end
end

function NetworkManager.GetConnectionQuality(player)
	local metrics = connectionMetrics[player.UserId]
	return metrics and metrics.quality or "unknown"
end

function NetworkManager.GetNetworkStatistics()
	local stats = {
		connectedPlayers = #Players:GetPlayers(),
		averagePing = 0,
		poorConnections = 0,
		bandwidthUsage = bandwidthUsage,
		optimization = networkOptimization
	}
	
	local totalPing = 0
	local playerCount = 0
	
	for userId, metrics in pairs(connectionMetrics) do
		totalPing = totalPing + metrics.ping
		playerCount = playerCount + 1
		
		if metrics.quality == "poor" then
			stats.poorConnections = stats.poorConnections + 1
		end
	end
	
	if playerCount > 0 then
		stats.averagePing = totalPing / playerCount
	end
	
	return stats
end

function NetworkManager.OptimizeForServerLoad()
	local serverLoad = #Players:GetPlayers() / Players.MaxPlayers
	
	if serverLoad > 0.8 then -- High load
		networkOptimization.updateFrequency = 20 -- Reduce to 20Hz
		networkOptimization.batchSize = 15 -- Larger batches
		Logging.Info("NetworkManager", "Optimized for high server load")
	elseif serverLoad < 0.3 then -- Low load
		networkOptimization.updateFrequency = 30 -- Standard 30Hz
		networkOptimization.batchSize = 10 -- Standard batches
	end
end

-- Priority system for network messages
function NetworkManager.SendPriorityMessage(remoteEvent, player, data, priority)
	priority = priority or "normal"
	
	if priority == "critical" then
		-- Send immediately
		remoteEvent:FireClient(player, data)
	elseif priority == "high" then
		-- Small delay batching
		NetworkManager.BatchEvent(remoteEvent.Name, data, player)
	else
		-- Normal batching
		NetworkManager.BatchEvent(remoteEvent.Name, data, player)
	end
end

function NetworkManager.GetPlayerMetrics(player)
	return connectionMetrics[player.UserId]
end

return NetworkManager
