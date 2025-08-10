--[[
	NetworkClient.client.lua
	Enterprise client-side network management for batched event handling
	
	Features:
	- Receive and process batched events from server
	- Client-side ping measurement and quality monitoring
	- Network compression handling
	- Event retry logic for failed messages
	- Local network statistics tracking
	
	Part of Phase 1.2 - Network Optimization - Batched Event System
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- Import dependencies
local ServiceLocator = require(ReplicatedStorage.Shared.ServiceLocator)
local NetworkBatcher = require(ReplicatedStorage.Shared.NetworkBatcher)

local NetworkClient = {}
local LocalPlayer = Players.LocalPlayer

-- Client network configuration
local CLIENT_CONFIG = {
	PING_TIMEOUT = 5000,           -- 5 seconds max ping wait
	RETRY_ATTEMPTS = 3,            -- Max retry attempts for failed events
	RETRY_DELAY = 1000,            -- Base retry delay in ms
	COMPRESSION_THRESHOLD = 1024,   -- Decompress payloads > 1KB
	STATS_UPDATE_INTERVAL = 5      -- Update local stats every 5 seconds
}

-- Client-side network statistics
local clientStats = {
	messagesReceived = 0,
	bytesReceived = 0,
	eventsProcessed = 0,
	averagePing = 0,
	pingHistory = {},
	connectionQuality = "Unknown",
	startTime = tick(),
	lastPingTime = 0,
	packetsLost = 0
}

-- Event handlers registry
local eventHandlers = {}

-- Pending ping requests
local pendingPings = {}

-- Failed event retry queue
local retryQueue = {}

-- Remote events
local BatchedEventsRemote = ReplicatedStorage:WaitForChild("BatchedEvents")
local NetworkPingRemote = ReplicatedStorage:WaitForChild("NetworkPing")
local NetworkQualityRemote = ReplicatedStorage:WaitForChild("NetworkQuality")
local RetryEventsRemote = ReplicatedStorage:WaitForChild("RetryEvents")

-- Initialize client network management
function NetworkClient.Initialize()
	-- Set up event listeners
	BatchedEventsRemote.OnClientEvent:Connect(NetworkClient.HandleBatchedEvents)
	NetworkPingRemote.OnClientEvent:Connect(NetworkClient.HandlePingRequest)
	NetworkQualityRemote.OnClientEvent:Connect(NetworkClient.HandleQualityUpdate)
	
	-- Start client-side monitoring
	NetworkClient.StartStatsMonitoring()
	NetworkClient.StartRetryProcessor()
	NetworkClient.StartPingTimeoutChecker()
	
	-- Register with Service Locator
	ServiceLocator.RegisterService("NetworkClient", NetworkClient, {})
	
	local logger = ServiceLocator.GetService("Logging")
	if logger then
		logger.Info("NetworkClient", "Client network management initialized")
	else
		print("[NetworkClient] ✓ Client network management initialized")
	end
end

-- Handle batched events from server
function NetworkClient.HandleBatchedEvents(batch: {[string]: any})
	if not batch or type(batch) ~= "table" then
		warn("[NetworkClient] Invalid batch received")
		return
	end
	
	local startTime = tick()
	local eventsProcessed = 0
	
	-- Handle compression if present
	if batch.compressed then
		-- Note: Actual decompression would require external library
		-- For now, we just track when decompression should occur
		clientStats.bytesReceived = clientStats.bytesReceived + (batch.originalSize or 0)
	else
		-- Estimate size for uncompressed batches
		local estimatedSize = #HttpService:JSONEncode(batch)
		clientStats.bytesReceived = clientStats.bytesReceived + estimatedSize
	end
	
	-- Process each event in the batch
	if batch.events then
		for _, event in ipairs(batch.events) do
			if NetworkClient.ProcessEvent(event, batch.priority) then
				eventsProcessed = eventsProcessed + 1
			end
		end
	end
	
	-- Update statistics
	clientStats.messagesReceived = clientStats.messagesReceived + 1
	clientStats.eventsProcessed = clientStats.eventsProcessed + eventsProcessed
	
	-- Log performance if processing took too long
	local processingTime = (tick() - startTime) * 1000
	if processingTime > 16 and batch.priority == 1 then -- Critical events should process within 16ms
		local logger = ServiceLocator.GetService("Logging")
		if logger then
			logger.Warn("NetworkClient", string.format("Critical batch processing took %.1fms (target: 16ms)", processingTime))
		end
	end
	
	-- Send acknowledgment for critical batches
	if batch.priority == 1 and batch.batchId then
		NetworkClient.SendBatchAcknowledgment(batch.batchId)
	end
end

-- Process individual event from batch
function NetworkClient.ProcessEvent(event: {[string]: any}, priority: number?): boolean
	if not event or not event.eventType then
		return false
	end
	
	local eventType = event.eventType
	local handler = eventHandlers[eventType]
	
	if handler then
		-- Execute event handler
		local success, errorMessage = pcall(handler, event.data, priority)
		
		if not success then
			local logger = ServiceLocator.GetService("Logging")
			if logger then
				logger.Error("NetworkClient", "Event handler failed for " .. eventType .. ": " .. tostring(errorMessage))
			end
			
			-- Add to retry queue for important events
			if priority and priority <= 2 then -- Critical and Normal priority
				NetworkClient.AddToRetryQueue(event)
			end
			
			return false
		end
		
		return true
	else
		-- No handler registered for this event type
		local logger = ServiceLocator.GetService("Logging")
		if logger then
			logger.Warn("NetworkClient", "No handler registered for event type: " .. eventType)
		end
		
		return false
	end
end

-- Handle ping request from server
function NetworkClient.HandlePingRequest(pingData: {[string]: any})
	if not pingData or not pingData.pingId then return end
	
	local clientTime = tick()
	
	-- Respond to server with ping data
	NetworkPingRemote:FireServer(pingData.pingId, clientTime)
	
	-- Calculate and store ping if we have the server time
	if pingData.serverTime then
		local rtt = (clientTime - pingData.serverTime) * 1000 -- Convert to milliseconds
		NetworkClient.UpdatePingStats(rtt)
	end
end

-- Handle connection quality update from server
function NetworkClient.HandleQualityUpdate(qualityData: {[string]: any})
	if not qualityData then return end
	
	clientStats.connectionQuality = qualityData.quality or "Unknown"
	
	-- Update local ping if provided
	if qualityData.ping then
		clientStats.averagePing = qualityData.ping
	end
	
	-- Log quality changes
	local logger = ServiceLocator.GetService("Logging")
	if logger then
		logger.Info("NetworkClient", "Connection quality updated: " .. clientStats.connectionQuality)
	end
end

-- Update ping statistics
function NetworkClient.UpdatePingStats(rtt: number)
	-- Add to ping history
	table.insert(clientStats.pingHistory, rtt)
	
	-- Keep only last 20 pings
	if #clientStats.pingHistory > 20 then
		table.remove(clientStats.pingHistory, 1)
	end
	
	-- Calculate average ping
	local totalPing = 0
	for _, ping in ipairs(clientStats.pingHistory) do
		totalPing = totalPing + ping
	end
	clientStats.averagePing = #clientStats.pingHistory > 0 and (totalPing / #clientStats.pingHistory) or 0
	
	-- Update connection quality based on ping
	if clientStats.averagePing < 50 then
		clientStats.connectionQuality = "Excellent"
	elseif clientStats.averagePing < 100 then
		clientStats.connectionQuality = "Good"
	elseif clientStats.averagePing < 200 then
		clientStats.connectionQuality = "Fair"
	else
		clientStats.connectionQuality = "Poor"
	end
end

-- Register event handler
function NetworkClient.RegisterEventHandler(eventType: string, handler: (data: any, priority: number?) -> boolean)
	if type(handler) ~= "function" then
		error("Event handler must be a function")
	end
	
	eventHandlers[eventType] = handler
	
	local logger = ServiceLocator.GetService("Logging")
	if logger then
		logger.Debug("NetworkClient", "Registered handler for event type: " .. eventType)
	end
end

-- Unregister event handler
function NetworkClient.UnregisterEventHandler(eventType: string)
	eventHandlers[eventType] = nil
	
	local logger = ServiceLocator.GetService("Logging")
	if logger then
		logger.Debug("NetworkClient", "Unregistered handler for event type: " .. eventType)
	end
end

-- Send batch acknowledgment to server
function NetworkClient.SendBatchAcknowledgment(batchId: string)
	-- For critical batches, send acknowledgment
	-- This could be expanded to include delivery confirmation
	local logger = ServiceLocator.GetService("Logging")
	if logger then
		logger.Debug("NetworkClient", "Acknowledged batch: " .. batchId)
	end
end

-- Add failed event to retry queue
function NetworkClient.AddToRetryQueue(event: {[string]: any})
	if not event.retryCount then
		event.retryCount = 0
	end
	
	event.retryCount = event.retryCount + 1
	
	if event.retryCount <= CLIENT_CONFIG.RETRY_ATTEMPTS then
		local retryDelay = CLIENT_CONFIG.RETRY_DELAY * (2 ^ (event.retryCount - 1)) -- Exponential backoff
		event.nextRetryTime = tick() + (retryDelay / 1000)
		
		table.insert(retryQueue, event)
		
		local logger = ServiceLocator.GetService("Logging")
		if logger then
			logger.Info("NetworkClient", string.format("Added event to retry queue (attempt %d/%d): %s", 
				event.retryCount, CLIENT_CONFIG.RETRY_ATTEMPTS, event.eventType))
		end
	else
		-- Permanent failure
		local logger = ServiceLocator.GetService("Logging")
		if logger then
			logger.Error("NetworkClient", "Event permanently failed after " .. CLIENT_CONFIG.RETRY_ATTEMPTS .. " attempts: " .. event.eventType)
		end
	end
end

-- Start statistics monitoring
function NetworkClient.StartStatsMonitoring()
	spawn(function()
		while true do
			wait(CLIENT_CONFIG.STATS_UPDATE_INTERVAL)
			NetworkClient.UpdateNetworkStats()
		end
	end)
end

-- Start retry queue processor
function NetworkClient.StartRetryProcessor()
	RunService.Heartbeat:Connect(function()
		local currentTime = tick()
		
		-- Process retry queue
		for i = #retryQueue, 1, -1 do
			local event = retryQueue[i]
			
			if currentTime >= event.nextRetryTime then
				-- Retry event processing
				if NetworkClient.ProcessEvent(event) then
					-- Success - remove from retry queue
					table.remove(retryQueue, i)
				else
					-- Failed again - add back to retry queue
					table.remove(retryQueue, i)
					NetworkClient.AddToRetryQueue(event)
				end
			end
		end
	end)
end

-- Start ping timeout checker
function NetworkClient.StartPingTimeoutChecker()
	spawn(function()
		while true do
			wait(1)
			
			local currentTime = tick()
			
			-- Check for ping timeouts
			for pingId, pingData in pairs(pendingPings) do
				if currentTime - pingData.startTime > (CLIENT_CONFIG.PING_TIMEOUT / 1000) then
					-- Ping timeout
					clientStats.packetsLost = clientStats.packetsLost + 1
					pendingPings[pingId] = nil
					
					local logger = ServiceLocator.GetService("Logging")
					if logger then
						logger.Warn("NetworkClient", "Ping timeout for ID: " .. pingId)
					end
				end
			end
		end
	end)
end

-- Update network statistics
function NetworkClient.UpdateNetworkStats()
	local uptime = tick() - clientStats.startTime
	
	-- Calculate rates
	local messagesPerSecond = uptime > 0 and (clientStats.messagesReceived / uptime) or 0
	local bytesPerSecond = uptime > 0 and (clientStats.bytesReceived / uptime) or 0
	
	-- Log stats periodically
	local logger = ServiceLocator.GetService("Logging")
	if logger then
		logger.Debug("NetworkClient", string.format(
			"Network Stats - Ping: %.1fms, Quality: %s, Messages/s: %.1f, Bytes/s: %.0f",
			clientStats.averagePing, clientStats.connectionQuality, messagesPerSecond, bytesPerSecond
		))
	end
end

-- Get comprehensive client network statistics
function NetworkClient.GetStats(): {[string]: any}
	local uptime = tick() - clientStats.startTime
	
	return {
		uptime = uptime,
		ping = clientStats.averagePing,
		connectionQuality = clientStats.connectionQuality,
		messagesReceived = clientStats.messagesReceived,
		eventsProcessed = clientStats.eventsProcessed,
		bytesReceived = clientStats.bytesReceived,
		packetsLost = clientStats.packetsLost,
		retryQueueSize = #retryQueue,
		eventHandlers = {},  -- Don't expose actual handlers for security
		rates = {
			messagesPerSecond = uptime > 0 and (clientStats.messagesReceived / uptime) or 0,
			bytesPerSecond = uptime > 0 and (clientStats.bytesReceived / uptime) or 0,
			eventsPerSecond = uptime > 0 and (clientStats.eventsProcessed / uptime) or 0
		}
	}
end

-- Test network performance
function NetworkClient.TestNetworkPerformance(): {[string]: any}
	local testResults = {
		pingTest = NetworkClient.RunPingTest(),
		bandwidthTest = NetworkClient.EstimateBandwidth(),
		qualityScore = NetworkClient.CalculateQualityScore()
	}
	
	return testResults
end

-- Run ping test
function NetworkClient.RunPingTest(): number
	-- Return current average ping
	return clientStats.averagePing
end

-- Estimate available bandwidth
function NetworkClient.EstimateBandwidth(): number
	local uptime = tick() - clientStats.startTime
	return uptime > 0 and (clientStats.bytesReceived / uptime) or 0
end

-- Calculate connection quality score
function NetworkClient.CalculateQualityScore(): number
	local score = 100
	
	-- Deduct based on ping
	if clientStats.averagePing > 200 then
		score = score - 40
	elseif clientStats.averagePing > 100 then
		score = score - 20
	elseif clientStats.averagePing > 50 then
		score = score - 10
	end
	
	-- Deduct based on packet loss
	local packetLossRate = clientStats.packetsLost / math.max(1, clientStats.messagesReceived)
	score = score - (packetLossRate * 50)
	
	return math.max(0, math.min(100, score))
end

-- Health check
function NetworkClient.HealthCheck(): {status: string, issues: {string}}
	local issues = {}
	
	-- Check ping
	if clientStats.averagePing > 200 then
		table.insert(issues, "High ping: " .. math.floor(clientStats.averagePing) .. "ms")
	end
	
	-- Check packet loss
	local packetLossRate = clientStats.packetsLost / math.max(1, clientStats.messagesReceived)
	if packetLossRate > 0.05 then -- 5% packet loss threshold
		table.insert(issues, "High packet loss: " .. math.floor(packetLossRate * 100) .. "%")
	end
	
	-- Check retry queue
	if #retryQueue > 10 then
		table.insert(issues, "High retry queue size: " .. #retryQueue)
	end
	
	local status = #issues == 0 and "healthy" or "warning"
	return {status = status, issues = issues}
end

-- Initialize when script loads
NetworkClient.Initialize()

return NetworkClient
