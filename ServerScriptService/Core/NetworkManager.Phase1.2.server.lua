--[[
	NetworkManager.server.lua
	Enterprise server-side network management with monitoring and optimization
	
	Features:
	- Network traffic monitoring and analytics
	- Bandwidth throttling and rate limiting
	- Connection quality assessment
	- Network event validation and routing
	- Performance metrics collection
	
	Part of Phase 1.2 - Network Optimization - Batched Event System
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- Import dependencies
local ServiceLocator = require(ReplicatedStorage.Shared.ServiceLocator)
local NetworkBatcher = require(ReplicatedStorage.Shared.NetworkBatcher)

local NetworkManager = {}

-- Network monitoring configuration
local NETWORK_CONFIG = {
	MAX_BANDWIDTH_PER_PLAYER = 50000, -- 50KB/s per player
	MAX_EVENTS_PER_SECOND = 100,      -- Rate limit per player
	CONNECTION_TIMEOUT = 30,          -- Seconds before considering disconnected
	PING_INTERVAL = 5,                -- Ping check interval
	QUALITY_CHECK_INTERVAL = 10       -- Connection quality assessment interval
}

-- Player network statistics
local playerNetworkStats = {}
local connectionQualities = {}
local rateLimiters = {}

-- Global network metrics
local networkMetrics = {
	totalBandwidthUsed = 0,
	totalEventsProcessed = 0,
	averagePing = 0,
	activeConnections = 0,
	startTime = tick()
}

-- Remote events for network management
local NetworkPingRemote = Instance.new("RemoteEvent")
NetworkPingRemote.Name = "NetworkPing"
NetworkPingRemote.Parent = ReplicatedStorage

local NetworkQualityRemote = Instance.new("RemoteEvent")
NetworkQualityRemote.Name = "NetworkQuality"
NetworkQualityRemote.Parent = ReplicatedStorage

-- Initialize network management system
function NetworkManager.Initialize()
	-- Register with Service Locator
	ServiceLocator.RegisterService("NetworkManager", NetworkManager, {
		"NetworkBatcher",
		"Logging"
	})
	
	-- Initialize player tracking
	Players.PlayerAdded:Connect(NetworkManager.OnPlayerAdded)
	Players.PlayerRemoving:Connect(NetworkManager.OnPlayerRemoving)
	
	-- Set up existing players
	for _, player in ipairs(Players:GetPlayers()) do
		NetworkManager.OnPlayerAdded(player)
	end
	
	-- Start monitoring systems
	NetworkManager.StartNetworkMonitoring()
	NetworkManager.StartPingSystem()
	NetworkManager.StartQualityAssessment()
	
	-- Initialize NetworkBatcher
	NetworkBatcher.Initialize()
	
	local logger = ServiceLocator.GetService("Logging")
	if logger then
		logger.Info("NetworkManager", "Enterprise network management system initialized")
	else
		print("[NetworkManager] ✓ Enterprise network management system initialized")
	end
end

-- Handle new player connections
function NetworkManager.OnPlayerAdded(player: Player)
	-- Initialize player network statistics
	playerNetworkStats[player.UserId] = {
		bytesSent = 0,
		bytesReceived = 0,
		eventsSent = 0,
		eventsReceived = 0,
		joinTime = tick(),
		lastActivity = tick(),
		averagePing = 0,
		connectionQuality = "Unknown"
	}
	
	-- Initialize rate limiter for player
	rateLimiters[player.UserId] = {
		events = {},
		lastResetTime = tick()
	}
	
	-- Initialize connection quality tracking
	connectionQualities[player.UserId] = {
		pingHistory = {},
		qualityScore = 100,
		lastPingTime = 0,
		packetLoss = 0
	}
	
	networkMetrics.activeConnections = networkMetrics.activeConnections + 1
	
	local logger = ServiceLocator.GetService("Logging")
	if logger then
		logger.Info("NetworkManager", "Player network profile created: " .. player.Name)
	end
end

-- Handle player disconnections
function NetworkManager.OnPlayerRemoving(player: Player)
	-- Clean up player data
	playerNetworkStats[player.UserId] = nil
	rateLimiters[player.UserId] = nil
	connectionQualities[player.UserId] = nil
	
	networkMetrics.activeConnections = math.max(0, networkMetrics.activeConnections - 1)
	
	local logger = ServiceLocator.GetService("Logging")
	if logger then
		logger.Info("NetworkManager", "Player network profile cleaned up: " .. player.Name)
	end
end

-- Start comprehensive network monitoring
function NetworkManager.StartNetworkMonitoring()
	RunService.Heartbeat:Connect(function()
		NetworkManager.UpdateNetworkMetrics()
		NetworkManager.CheckBandwidthLimits()
		NetworkManager.UpdateRateLimiters()
	end)
end

-- Start ping monitoring system
function NetworkManager.StartPingSystem()
	-- Set up ping response handler
	NetworkPingRemote.OnServerEvent:Connect(function(player, pingId, clientTime)
		NetworkManager.HandlePingResponse(player, pingId, clientTime)
	end)
	
	-- Send periodic ping requests
	spawn(function()
		while true do
			for _, player in ipairs(Players:GetPlayers()) do
				NetworkManager.SendPingRequest(player)
			end
			wait(NETWORK_CONFIG.PING_INTERVAL)
		end
	end)
end

-- Start connection quality assessment
function NetworkManager.StartQualityAssessment()
	spawn(function()
		while true do
			for _, player in ipairs(Players:GetPlayers()) do
				NetworkManager.AssessConnectionQuality(player)
			end
			wait(NETWORK_CONFIG.QUALITY_CHECK_INTERVAL)
		end
	end)
end

-- Send ping request to player
function NetworkManager.SendPingRequest(player: Player)
	local pingId = HttpService:GenerateGUID(false)
	local sendTime = tick()
	
	-- Store ping data for response tracking
	local quality = connectionQualities[player.UserId]
	if quality then
		quality.lastPingTime = sendTime
		quality.currentPingId = pingId
	end
	
	-- Send ping via NetworkBatcher with Critical priority
	NetworkBatcher.QueueEvent("NetworkPing", player, {
		pingId = pingId,
		serverTime = sendTime
	}, "Critical")
end

-- Handle ping response from client
function NetworkManager.HandlePingResponse(player: Player, pingId: string, clientTime: number)
	local currentTime = tick()
	local quality = connectionQualities[player.UserId]
	local stats = playerNetworkStats[player.UserId]
	
	if not quality or not stats then return end
	
	-- Calculate round-trip time
	local rtt = (currentTime - quality.lastPingTime) * 1000 -- Convert to milliseconds
	
	-- Update ping history
	table.insert(quality.pingHistory, rtt)
	if #quality.pingHistory > 10 then
		table.remove(quality.pingHistory, 1) -- Keep only last 10 pings
	end
	
	-- Calculate average ping
	local totalPing = 0
	for _, ping in ipairs(quality.pingHistory) do
		totalPing = totalPing + ping
	end
	stats.averagePing = totalPing / #quality.pingHistory
	
	-- Update global average ping
	NetworkManager.UpdateGlobalPingAverage()
	
	-- Log ping data
	local logger = ServiceLocator.GetService("Logging")
	if logger then
		logger.Debug("NetworkManager", string.format("Ping from %s: %.1fms", player.Name, rtt))
	end
end

-- Assess connection quality for a player
function NetworkManager.AssessConnectionQuality(player: Player)
	local quality = connectionQualities[player.UserId]
	local stats = playerNetworkStats[player.UserId]
	
	if not quality or not stats then return end
	
	local qualityScore = 100
	local qualityLevel = "Excellent"
	
	-- Factor in ping
	if stats.averagePing > 200 then
		qualityScore = qualityScore - 30
		qualityLevel = "Poor"
	elseif stats.averagePing > 100 then
		qualityScore = qualityScore - 15
		qualityLevel = "Fair"
	elseif stats.averagePing > 50 then
		qualityScore = qualityScore - 5
		qualityLevel = "Good"
	end
	
	-- Factor in packet loss (simulated based on ping consistency)
	if #quality.pingHistory >= 5 then
		local pingVariance = 0
		local avgPing = stats.averagePing
		
		for _, ping in ipairs(quality.pingHistory) do
			pingVariance = pingVariance + math.abs(ping - avgPing)
		end
		pingVariance = pingVariance / #quality.pingHistory
		
		if pingVariance > 50 then
			qualityScore = qualityScore - 20
			qualityLevel = "Unstable"
		end
	end
	
	quality.qualityScore = qualityScore
	stats.connectionQuality = qualityLevel
	
	-- Send quality update to client
	NetworkBatcher.QueueEvent("ConnectionQuality", player, {
		quality = qualityLevel,
		score = qualityScore,
		ping = stats.averagePing
	}, "Normal")
end

-- Update global network metrics
function NetworkManager.UpdateNetworkMetrics()
	local totalPing = 0
	local playerCount = 0
	
	for userId, stats in pairs(playerNetworkStats) do
		if stats.averagePing > 0 then
			totalPing = totalPing + stats.averagePing
			playerCount = playerCount + 1
		end
	end
	
	networkMetrics.averagePing = playerCount > 0 and (totalPing / playerCount) or 0
end

-- Update global ping average
function NetworkManager.UpdateGlobalPingAverage()
	NetworkManager.UpdateNetworkMetrics()
end

-- Check bandwidth limits for all players
function NetworkManager.CheckBandwidthLimits()
	for userId, stats in pairs(playerNetworkStats) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			local sessionTime = tick() - stats.joinTime
			local avgBandwidth = sessionTime > 0 and (stats.bytesSent / sessionTime) or 0
			
			if avgBandwidth > NETWORK_CONFIG.MAX_BANDWIDTH_PER_PLAYER then
				-- Implement bandwidth throttling
				NetworkManager.ThrottlePlayer(player, "bandwidth")
			end
		end
	end
end

-- Update rate limiters for all players
function NetworkManager.UpdateRateLimiters()
	local currentTime = tick()
	
	for userId, limiter in pairs(rateLimiters) do
		-- Reset rate limiter every second
		if currentTime - limiter.lastResetTime >= 1.0 then
			limiter.events = {}
			limiter.lastResetTime = currentTime
		end
	end
end

-- Check if player exceeds rate limits
function NetworkManager.CheckRateLimit(player: Player, eventType: string): boolean
	local limiter = rateLimiters[player.UserId]
	if not limiter then return false end
	
	-- Count events in current second
	local eventCount = 0
	for _, event in pairs(limiter.events) do
		if event == eventType then
			eventCount = eventCount + 1
		end
	end
	
	if eventCount >= NETWORK_CONFIG.MAX_EVENTS_PER_SECOND then
		NetworkManager.ThrottlePlayer(player, "rate_limit")
		return true -- Rate limit exceeded
	end
	
	-- Add event to rate limiter
	table.insert(limiter.events, eventType)
	return false
end

-- Throttle player for exceeding limits
function NetworkManager.ThrottlePlayer(player: Player, reason: string)
	local logger = ServiceLocator.GetService("Logging")
	if logger then
		logger.Warn("NetworkManager", string.format("Throttling player %s for %s", player.Name, reason))
	end
	
	-- Send throttling notification to player
	NetworkBatcher.QueueEvent("NetworkThrottle", player, {
		reason = reason,
		timestamp = tick()
	}, "Critical")
end

-- Get comprehensive network statistics
function NetworkManager.GetNetworkStats(): {[string]: any}
	local playerStats = {}
	
	for userId, stats in pairs(playerNetworkStats) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			playerStats[player.Name] = {
				ping = stats.averagePing,
				quality = stats.connectionQuality,
				bytesSent = stats.bytesSent,
				eventsProcessed = stats.eventsSent,
				sessionTime = tick() - stats.joinTime
			}
		end
	end
	
	local uptime = tick() - networkMetrics.startTime
	
	return {
		global = {
			uptime = uptime,
			activeConnections = networkMetrics.activeConnections,
			averagePing = networkMetrics.averagePing,
			totalBandwidthUsed = networkMetrics.totalBandwidthUsed,
			totalEventsProcessed = networkMetrics.totalEventsProcessed
		},
		players = playerStats,
		batcher = NetworkBatcher.GetStats()
	}
end

-- Validate network event before processing
function NetworkManager.ValidateNetworkEvent(player: Player, eventType: string, data: any): boolean
	-- Check rate limits
	if NetworkManager.CheckRateLimit(player, eventType) then
		return false
	end
	
	-- Validate event data structure
	if not data or type(data) ~= "table" then
		return false
	end
	
	-- Update player statistics
	local stats = playerNetworkStats[player.UserId]
	if stats then
		stats.eventsReceived = stats.eventsReceived + 1
		stats.lastActivity = tick()
	end
	
	return true
end

-- Health check for monitoring
function NetworkManager.HealthCheck(): {status: string, issues: {string}}
	local issues = {}
	
	-- Check average ping
	if networkMetrics.averagePing > 150 then
		table.insert(issues, "High average ping: " .. math.floor(networkMetrics.averagePing) .. "ms")
	end
	
	-- Check connection stability
	local unstableConnections = 0
	for _, stats in pairs(playerNetworkStats) do
		if stats.connectionQuality == "Poor" or stats.connectionQuality == "Unstable" then
			unstableConnections = unstableConnections + 1
		end
	end
	
	if unstableConnections > networkMetrics.activeConnections * 0.3 then
		table.insert(issues, "High number of unstable connections: " .. unstableConnections)
	end
	
	-- Check NetworkBatcher health
	local batcherHealth = NetworkBatcher.HealthCheck()
	if batcherHealth.status ~= "healthy" then
		for _, issue in ipairs(batcherHealth.issues) do
			table.insert(issues, "NetworkBatcher: " .. issue)
		end
	end
	
	local status = #issues == 0 and "healthy" or "warning"
	return {status = status, issues = issues}
end

-- Graceful shutdown
function NetworkManager.Shutdown()
	-- Flush all pending network batches
	NetworkBatcher.FlushAll()
	
	-- Notify all players of shutdown
	for _, player in ipairs(Players:GetPlayers()) do
		NetworkBatcher.QueueEvent("ServerShutdown", player, {
			reason = "Maintenance",
			timestamp = tick()
		}, "Critical")
	end
	
	-- Process final batches
	wait(0.5)
	NetworkBatcher.FlushAll()
	
	local logger = ServiceLocator.GetService("Logging")
	if logger then
		logger.Info("NetworkManager", "Network management system gracefully shut down")
	end
end

return NetworkManager
