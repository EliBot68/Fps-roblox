--[[
	NetworkBatcher.lua
	Enterprise network event batching system to reduce bandwidth and improve performance
	
	Usage:
		NetworkBatcher.QueueEvent("PlayerHit", player, {damage = 50, headshot = true})
		-- Events are automatically batched and sent efficiently
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetworkBatcher = {}

-- Batching configuration
local BATCH_SIZE = 10 -- Maximum events per batch
local BATCH_INTERVAL = 0.1 -- Send batches every 100ms
local MAX_QUEUE_SIZE = 500 -- Prevent memory overflow

-- Batch queues by event type
local eventQueues = {}
local lastBatchTime = 0

-- Global batched remote event
local BatchedEventsRemote = Instance.new("RemoteEvent")
BatchedEventsRemote.Name = "BatchedEvents"
BatchedEventsRemote.Parent = ReplicatedStorage

-- Initialize batching system
function NetworkBatcher.Initialize()
	-- Start batch processor
	RunService.Heartbeat:Connect(function()
		local currentTime = tick()
		
		if currentTime - lastBatchTime >= BATCH_INTERVAL then
			NetworkBatcher.ProcessBatches()
			lastBatchTime = currentTime
		end
	end)
	
	print("[NetworkBatcher] ✓ Initialized with", BATCH_INTERVAL * 1000, "ms interval")
end

-- Queue an event for batching
function NetworkBatcher.QueueEvent(eventType: string, targetPlayer: Player?, data: any)
	-- Validate input
	if not eventType or type(data) ~= "table" then
		warn("[NetworkBatcher] Invalid event data:", eventType, typeof(data))
		return false
	end
	
	-- Initialize queue for event type if needed
	if not eventQueues[eventType] then
		eventQueues[eventType] = {}
	end
	
	local queue = eventQueues[eventType]
	
	-- Check queue size limits
	if #queue >= MAX_QUEUE_SIZE then
		warn("[NetworkBatcher] Queue overflow for", eventType, "- dropping oldest events")
		-- Remove oldest events to make room
		for i = 1, math.floor(MAX_QUEUE_SIZE * 0.1) do
			table.remove(queue, 1)
		end
	end
	
	-- Add event to queue with timestamp
	table.insert(queue, {
		targetPlayer = targetPlayer,
		data = data,
		timestamp = tick()
	})
	
	return true
end

-- Queue event for all players
function NetworkBatcher.QueueBroadcast(eventType: string, data: any)
	return NetworkBatcher.QueueEvent(eventType, nil, data)
end

-- Process and send all queued batches
function NetworkBatcher.ProcessBatches()
	local totalSent = 0
	
	for eventType, queue in pairs(eventQueues) do
		if #queue > 0 then
			totalSent = totalSent + NetworkBatcher.ProcessEventQueue(eventType, queue)
		end
	end
	
	return totalSent
end

-- Process a specific event queue
function NetworkBatcher.ProcessEventQueue(eventType: string, queue: {any}): number
	if #queue == 0 then return 0 end
	
	-- Group events by target player
	local playerGroups = {
		broadcast = {} -- Events for all players
	}
	
	for _, event in ipairs(queue) do
		local key = event.targetPlayer and tostring(event.targetPlayer.UserId) or "broadcast"
		
		if not playerGroups[key] then
			playerGroups[key] = {}
		end
		
		table.insert(playerGroups[key], event.data)
	end
	
	-- Send batches to each player group
	local totalSent = 0
	for playerKey, events in pairs(playerGroups) do
		totalSent = totalSent + NetworkBatcher.SendBatch(eventType, playerKey, events)
	end
	
	-- Clear processed queue
	eventQueues[eventType] = {}
	
	return totalSent
end

-- Send a batch of events
function NetworkBatcher.SendBatch(eventType: string, playerKey: string, events: {any}): number
	if #events == 0 then return 0 end
	
	-- Create batch payload
	local batch = {
		eventType = eventType,
		timestamp = tick(),
		events = events
	}
	
	-- Send to specific player or broadcast
	if playerKey == "broadcast" then
		BatchedEventsRemote:FireAllClients(batch)
	else
		local player = game:GetService("Players"):GetPlayerByUserId(tonumber(playerKey))
		if player then
			BatchedEventsRemote:FireClient(player, batch)
		end
	end
	
	return #events
end

-- Force flush all queues immediately
function NetworkBatcher.FlushAll(): number
	return NetworkBatcher.ProcessBatches()
end

-- Get batching statistics
function NetworkBatcher.GetStats(): {queuedEvents: number, queuesByType: {[string]: number}}
	local totalQueued = 0
	local queuesByType = {}
	
	for eventType, queue in pairs(eventQueues) do
		local count = #queue
		queuesByType[eventType] = count
		totalQueued = totalQueued + count
	end
	
	return {
		queuedEvents = totalQueued,
		queuesByType = queuesByType
	}
end

-- Clear all queues (for testing/debugging)
function NetworkBatcher.ClearAll()
	eventQueues = {}
end

-- Helper: Queue weapon fire events efficiently  
function NetworkBatcher.QueueWeaponFire(shooter: Player, weaponId: string, hitData: {any})
	return NetworkBatcher.QueueBroadcast("WeaponFired", {
		shooter = shooter.Name,
		weapon = weaponId,
		hits = hitData,
		timestamp = tick()
	})
end

-- Helper: Queue player elimination efficiently
function NetworkBatcher.QueueElimination(killer: Player, victim: Player, weaponId: string, headshot: boolean)
	return NetworkBatcher.QueueBroadcast("PlayerEliminated", {
		killer = killer.Name,
		victim = victim.Name,
		weapon = weaponId,
		headshot = headshot
	})
end

-- Helper: Queue UI updates for specific player
function NetworkBatcher.QueueUIUpdate(player: Player, uiType: string, data: any)
	return NetworkBatcher.QueueEvent("UIUpdate", player, {
		uiType = uiType,
		data = data
	})
end

return NetworkBatcher
