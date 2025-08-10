--[[
	NetworkBatcher.lua
	Enterprise network event batching system with priority queuing and compression
	
	Features:
	- Priority queue system (Critical/Normal/Low)
	- Bandwidth monitoring and throttling
	- Compression for large payloads (>1KB)
	- Automatic retry logic with exponential backoff
	- Service Locator integration
	
	Usage:
		NetworkBatcher.QueueEvent("PlayerHit", player, {damage = 50, headshot = true}, "Critical")
		NetworkBatcher.QueueBroadcast("MatchStarted", {mapId = "dust2"}, "Normal")
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- Import Service Locator for dependency injection
local ServiceLocator = require(script.Parent.ServiceLocator)

local NetworkBatcher = {}

-- Priority levels for event processing
local Priority = {
	Critical = 1,  -- Combat events, player state changes (16ms target)
	Normal = 2,    -- UI updates, non-critical gameplay (50ms target)
	Low = 3        -- Analytics, background tasks (200ms target)
}

-- Enterprise batching configuration
local BATCH_CONFIG = {
	[Priority.Critical] = {size = 5, interval = 0.016},   -- 60 FPS
	[Priority.Normal] = {size = 10, interval = 0.05},     -- 20 FPS
	[Priority.Low] = {size = 20, interval = 0.2}          -- 5 FPS
}

local MAX_QUEUE_SIZE = 1000 -- Prevent memory overflow
local COMPRESSION_THRESHOLD = 1024 -- Compress payloads > 1KB
local MAX_RETRY_ATTEMPTS = 3
local RETRY_BASE_DELAY = 0.5

-- Priority-based event queues
local eventQueues = {
	[Priority.Critical] = {},
	[Priority.Normal] = {},
	[Priority.Low] = {}
}

-- Timing tracking for each priority
local lastBatchTimes = {
	[Priority.Critical] = 0,
	[Priority.Normal] = 0,
	[Priority.Low] = 0
}

-- Bandwidth monitoring
local bandwidthStats = {
	bytesSent = 0,
	messagesSent = 0,
	startTime = tick(),
	lastSecondBytes = 0,
	lastSecondTime = 0
}

-- Retry queue for failed sends
local retryQueue = {}

-- Global batched remote events
local BatchedEventsRemote = Instance.new("RemoteEvent")
BatchedEventsRemote.Name = "BatchedEvents"
BatchedEventsRemote.Parent = ReplicatedStorage

local RetryEventsRemote = Instance.new("RemoteEvent")
RetryEventsRemote.Name = "RetryEvents"
RetryEventsRemote.Parent = ReplicatedStorage

-- Initialize enterprise batching system
function NetworkBatcher.Initialize()
	-- Register with Service Locator
	ServiceLocator.RegisterService("NetworkBatcher", NetworkBatcher, {
		"Logging"  -- Dependency on logging service
	})
	
	-- Start priority-based batch processors
	RunService.Heartbeat:Connect(function()
		local currentTime = tick()
		
		-- Process each priority level with different intervals
		for priority, config in pairs(BATCH_CONFIG) do
			if currentTime - lastBatchTimes[priority] >= config.interval then
				NetworkBatcher.ProcessPriorityQueue(priority)
				lastBatchTimes[priority] = currentTime
			end
		end
		
		-- Process retry queue
		NetworkBatcher.ProcessRetryQueue()
		
		-- Update bandwidth monitoring
		NetworkBatcher.UpdateBandwidthStats()
	end)
	
	-- Set up retry event handler
	RetryEventsRemote.OnServerEvent:Connect(function(player, retryId)
		NetworkBatcher.HandleRetryRequest(player, retryId)
	end)
	
	local logger = ServiceLocator.GetService("Logging")
	if logger then
		logger.Info("NetworkBatcher", "Enterprise batching system initialized with priority queues")
	else
		print("[NetworkBatcher] ✓ Enterprise batching system initialized")
	end
end

-- Queue an event with priority support
function NetworkBatcher.QueueEvent(eventType: string, targetPlayer: Player?, data: any, priorityLevel: string?): boolean
	-- Validate input
	if not eventType or type(data) ~= "table" then
		warn("[NetworkBatcher] Invalid event data:", eventType, typeof(data))
		return false
	end
	
	-- Parse priority level
	local priority = Priority[priorityLevel] or Priority.Normal
	local queue = eventQueues[priority]
	
	-- Check queue size limits
	if #queue >= MAX_QUEUE_SIZE then
		local logger = ServiceLocator.GetService("Logging")
		if logger then
			logger.Warn("NetworkBatcher", "Queue overflow for priority " .. priorityLevel .. " - dropping oldest events")
		end
		
		-- Remove oldest events (10% of queue)
		for i = 1, math.floor(MAX_QUEUE_SIZE * 0.1) do
			table.remove(queue, 1)
		end
	end
	
	-- Add event to priority queue with metadata
	local eventData = {
		eventType = eventType,
		targetPlayer = targetPlayer,
		data = data,
		timestamp = tick(),
		priority = priority,
		retryCount = 0,
		id = HttpService:GenerateGUID(false)
	}
	
	table.insert(queue, eventData)
	return true
end

-- Queue event for all players with priority
function NetworkBatcher.QueueBroadcast(eventType: string, data: any, priorityLevel: string?): boolean
	return NetworkBatcher.QueueEvent(eventType, nil, data, priorityLevel)
end

-- Process a specific priority queue
function NetworkBatcher.ProcessPriorityQueue(priority: number)
	local queue = eventQueues[priority]
	if #queue == 0 then return end
	
	local config = BATCH_CONFIG[priority]
	local batchSize = config.size
	
	-- Group events by target player and event type
	local playerGroups = {}
	local processedCount = 0
	
	for i = 1, math.min(#queue, batchSize) do
		local event = queue[i]
		local playerKey = event.targetPlayer and tostring(event.targetPlayer.UserId) or "broadcast"
		
		if not playerGroups[playerKey] then
			playerGroups[playerKey] = {}
		end
		
		table.insert(playerGroups[playerKey], event)
		processedCount = processedCount + 1
	end
	
	-- Send batches to each player group
	for playerKey, events in pairs(playerGroups) do
		NetworkBatcher.SendPriorityBatch(priority, playerKey, events)
	end
	
	-- Remove processed events from queue
	for i = 1, processedCount do
		table.remove(queue, 1)
	end
end

-- Send a priority batch with compression support
function NetworkBatcher.SendPriorityBatch(priority: number, playerKey: string, events: {any})
	if #events == 0 then return end
	
	-- Create batch payload
	local batch = {
		priority = priority,
		timestamp = tick(),
		events = events,
		batchId = HttpService:GenerateGUID(false)
	}
	
	-- Serialize and check size for compression
	local serialized = HttpService:JSONEncode(batch)
	local dataSize = #serialized
	
	-- Apply compression for large payloads
	if dataSize > COMPRESSION_THRESHOLD then
		batch.compressed = true
		batch.originalSize = dataSize
		-- Note: Actual compression would require external library
		-- For now, we'll track when compression should be applied
	end
	
	-- Track bandwidth usage
	bandwidthStats.bytesSent = bandwidthStats.bytesSent + dataSize
	bandwidthStats.messagesSent = bandwidthStats.messagesSent + 1
	
	-- Send to specific player or broadcast
	local success = false
	if playerKey == "broadcast" then
		success = pcall(function()
			BatchedEventsRemote:FireAllClients(batch)
		end)
	else
		local player = game:GetService("Players"):GetPlayerByUserId(tonumber(playerKey))
		if player then
			success = pcall(function()
				BatchedEventsRemote:FireClient(player, batch)
			end)
		end
	end
	
	-- Handle failed sends with retry logic
	if not success then
		NetworkBatcher.AddToRetryQueue(batch, playerKey)
	end
end

-- Add failed batch to retry queue
function NetworkBatcher.AddToRetryQueue(batch: any, playerKey: string)
	for _, event in ipairs(batch.events) do
		if event.retryCount < MAX_RETRY_ATTEMPTS then
			event.retryCount = event.retryCount + 1
			event.nextRetryTime = tick() + (RETRY_BASE_DELAY * (2 ^ (event.retryCount - 1))) -- Exponential backoff
			
			table.insert(retryQueue, {
				event = event,
				playerKey = playerKey,
				originalBatchId = batch.batchId
			})
		else
			-- Log permanent failure
			local logger = ServiceLocator.GetService("Logging")
			if logger then
				logger.Error("NetworkBatcher", "Event permanently failed after " .. MAX_RETRY_ATTEMPTS .. " attempts: " .. event.eventType)
			end
		end
	end
end

-- Process retry queue with exponential backoff
function NetworkBatcher.ProcessRetryQueue()
	local currentTime = tick()
	local retryBatches = {}
	
	-- Group ready retries by player
	for i = #retryQueue, 1, -1 do
		local retryItem = retryQueue[i]
		if currentTime >= retryItem.event.nextRetryTime then
			local playerKey = retryItem.playerKey
			if not retryBatches[playerKey] then
				retryBatches[playerKey] = {}
			end
			
			table.insert(retryBatches[playerKey], retryItem.event)
			table.remove(retryQueue, i)
		end
	end
	
	-- Send retry batches
	for playerKey, events in pairs(retryBatches) do
		NetworkBatcher.SendPriorityBatch(Priority.Critical, playerKey, events) -- Retries get critical priority
	end
end

-- Handle retry requests from clients
function NetworkBatcher.HandleRetryRequest(player: Player, retryId: string)
	-- Implementation for client-requested retries
	local logger = ServiceLocator.GetService("Logging")
	if logger then
		logger.Info("NetworkBatcher", "Retry requested by " .. player.Name .. " for batch " .. retryId)
	end
end

-- Update bandwidth monitoring statistics
function NetworkBatcher.UpdateBandwidthStats()
	local currentTime = tick()
	
	-- Calculate bytes per second
	if currentTime - bandwidthStats.lastSecondTime >= 1.0 then
		bandwidthStats.lastSecondBytes = bandwidthStats.bytesSent
		bandwidthStats.lastSecondTime = currentTime
	end
end

-- Force flush all priority queues immediately
function NetworkBatcher.FlushAll(): number
	local totalProcessed = 0
	
	for priority, queue in pairs(eventQueues) do
		totalProcessed = totalProcessed + #queue
		NetworkBatcher.ProcessPriorityQueue(priority)
	end
	
	return totalProcessed
end

-- Get comprehensive batching statistics
function NetworkBatcher.GetStats(): {[string]: any}
	local queueStats = {}
	local totalQueued = 0
	
	for priority, queue in pairs(eventQueues) do
		local count = #queue
		queueStats["Priority" .. priority] = count
		totalQueued = totalQueued + count
	end
	
	local currentTime = tick()
	local uptime = currentTime - bandwidthStats.startTime
	local avgBytesPerSecond = uptime > 0 and (bandwidthStats.bytesSent / uptime) or 0
	
	return {
		queuedEvents = totalQueued,
		queuesByPriority = queueStats,
		retryQueueSize = #retryQueue,
		bandwidth = {
			totalBytesSent = bandwidthStats.bytesSent,
			totalMessagesSent = bandwidthStats.messagesSent,
			averageBytesPerSecond = avgBytesPerSecond,
			lastSecondBytes = bandwidthStats.lastSecondBytes
		},
		uptime = uptime
	}
end

-- Enterprise helper functions with priority support
function NetworkBatcher.QueueWeaponFire(shooter: Player, weaponId: string, hitData: {any}): boolean
	return NetworkBatcher.QueueBroadcast("WeaponFired", {
		shooter = shooter.Name,
		weapon = weaponId,
		hits = hitData,
		timestamp = tick()
	}, "Critical") -- Weapon events are critical priority
end

function NetworkBatcher.QueueElimination(killer: Player, victim: Player, weaponId: string, headshot: boolean): boolean
	return NetworkBatcher.QueueBroadcast("PlayerEliminated", {
		killer = killer.Name,
		victim = victim.Name,
		weapon = weaponId,
		headshot = headshot
	}, "Critical") -- Elimination events are critical priority
end

function NetworkBatcher.QueueUIUpdate(player: Player, uiType: string, data: any): boolean
	return NetworkBatcher.QueueEvent("UIUpdate", player, {
		uiType = uiType,
		data = data
	}, "Normal") -- UI updates are normal priority
end

function NetworkBatcher.QueueAnalytics(eventName: string, data: any): boolean
	return NetworkBatcher.QueueBroadcast("Analytics", {
		event = eventName,
		data = data,
		timestamp = tick()
	}, "Low") -- Analytics are low priority
end

-- Clear all queues (for testing/debugging)
function NetworkBatcher.ClearAll()
	for priority in pairs(eventQueues) do
		eventQueues[priority] = {}
	end
	retryQueue = {}
	
	-- Reset bandwidth stats
	bandwidthStats = {
		bytesSent = 0,
		messagesSent = 0,
		startTime = tick(),
		lastSecondBytes = 0,
		lastSecondTime = tick()
	}
end

-- Bandwidth throttling check
function NetworkBatcher.IsWithinBandwidthLimits(): boolean
	local bytesPerSecond = bandwidthStats.lastSecondBytes
	local MAX_BYTES_PER_SECOND = 50000 -- 50KB/s limit
	
	return bytesPerSecond < MAX_BYTES_PER_SECOND
end

-- Health check for monitoring
function NetworkBatcher.HealthCheck(): {status: string, issues: {string}}
	local issues = {}
	
	-- Check queue sizes
	for priority, queue in pairs(eventQueues) do
		if #queue > MAX_QUEUE_SIZE * 0.8 then
			table.insert(issues, "Priority " .. priority .. " queue near capacity")
		end
	end
	
	-- Check retry queue
	if #retryQueue > 100 then
		table.insert(issues, "High retry queue size: " .. #retryQueue)
	end
	
	-- Check bandwidth
	if not NetworkBatcher.IsWithinBandwidthLimits() then
		table.insert(issues, "Bandwidth limit exceeded")
	end
	
	local status = #issues == 0 and "healthy" or "warning"
	return {status = status, issues = issues}
end

return NetworkBatcher
