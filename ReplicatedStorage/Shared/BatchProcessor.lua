-- BatchProcessor.lua
-- High-performance batch processing system for RemoteEvents and data operations

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local BatchProcessor = {}

-- Batch configuration
local BATCH_CONFIG = {
	maxBatchSize = 50,
	maxBatchTime = 0.1, -- 100ms
	maxMemoryUsage = 1000, -- MB before emergency flush
	
	-- Priority levels
	priorities = {
		critical = 1,  -- Immediate processing
		high = 2,      -- Next frame
		normal = 3,    -- Normal batching
		low = 4        -- Background processing
	}
}

-- Batch queues organized by priority
local batchQueues = {
	critical = {},
	high = {},
	normal = {},
	low = {}
}

-- Processing statistics
local stats = {
	totalProcessed = 0,
	averageLatency = 0,
	currentBatchSize = 0,
	droppedItems = 0
}

-- Initialize batch processor
function BatchProcessor.Initialize()
	BatchProcessor.StartProcessingLoop()
	BatchProcessor.SetupMemoryMonitoring()
	print("[BatchProcessor] Enterprise batch processing system initialized")
end

-- Start the main processing loop
function BatchProcessor.StartProcessingLoop()
	local lastProcess = tick()
	local latencyAccumulator = 0
	local processCount = 0
	
	RunService.Heartbeat:Connect(function()
		local now = tick()
		local deltaTime = now - lastProcess
		
		-- Process critical items immediately
		BatchProcessor.ProcessQueue("critical", math.huge)
		
		-- Process high priority items every frame
		BatchProcessor.ProcessQueue("high", 10)
		
		-- Process normal items in batches
		if deltaTime >= BATCH_CONFIG.maxBatchTime then
			local startTime = tick()
			
			BatchProcessor.ProcessQueue("normal", BATCH_CONFIG.maxBatchSize)
			BatchProcessor.ProcessQueue("low", 5) -- Limited low priority processing
			
			-- Update performance metrics
			local processTime = tick() - startTime
			latencyAccumulator = latencyAccumulator + processTime
			processCount = processCount + 1
			
			if processCount >= 60 then -- Update stats every 60 cycles
				stats.averageLatency = latencyAccumulator / processCount
				latencyAccumulator = 0
				processCount = 0
			end
			
			lastProcess = now
		end
	end)
end

-- Process a specific priority queue
function BatchProcessor.ProcessQueue(priority, maxItems)
	local queue = batchQueues[priority]
	if not queue or #queue == 0 then return end
	
	local processed = 0
	local startIndex = 1
	
	while startIndex <= #queue and processed < maxItems do
		local batch = {}
		local batchSize = 0
		
		-- Build batch
		while startIndex <= #queue and batchSize < BATCH_CONFIG.maxBatchSize and processed < maxItems do
			local item = queue[startIndex]
			if item then
				table.insert(batch, item)
				batchSize = batchSize + 1
				processed = processed + 1
			end
			startIndex = startIndex + 1
		end
		
		-- Process batch
		if #batch > 0 then
			BatchProcessor.ProcessBatch(batch, priority)
			stats.totalProcessed = stats.totalProcessed + #batch
		end
	end
	
	-- Remove processed items
	if processed > 0 then
		for i = processed, 1, -1 do
			table.remove(queue, 1)
		end
	end
	
	stats.currentBatchSize = #queue
end

-- Process a batch of items
function BatchProcessor.ProcessBatch(batch, priority)
	local batchsByType = {}
	
	-- Group by operation type for efficiency
	for _, item in ipairs(batch) do
		local opType = item.operation or "unknown"
		if not batchsByType[opType] then
			batchsByType[opType] = {}
		end
		table.insert(batchsByType[opType], item)
	end
	
	-- Process each operation type
	for opType, items in pairs(batchsByType) do
		local success, error = pcall(function()
			if opType == "remoteEvent" then
				BatchProcessor.ProcessRemoteEventBatch(items)
			elseif opType == "datastore" then
				BatchProcessor.ProcessDataStoreBatch(items)
			elseif opType == "playerUpdate" then
				BatchProcessor.ProcessPlayerUpdateBatch(items)
			elseif opType == "analytics" then
				BatchProcessor.ProcessAnalyticsBatch(items)
			else
				-- Generic processing
				for _, item in ipairs(items) do
					if item.callback then
						item.callback(item.data)
					end
				end
			end
		end)
		
		if not success then
			print("[BatchProcessor] Error processing batch:", error)
			stats.droppedItems = stats.droppedItems + #items
		end
	end
end

-- Process RemoteEvent batch
function BatchProcessor.ProcessRemoteEventBatch(items)
	local eventBatches = {}
	
	-- Group by RemoteEvent
	for _, item in ipairs(items) do
		local eventName = item.eventName
		if not eventBatches[eventName] then
			eventBatches[eventName] = {
				event = item.remoteEvent,
				players = {},
				data = {}
			}
		end
		
		table.insert(eventBatches[eventName].players, item.player)
		table.insert(eventBatches[eventName].data, item.data)
	end
	
	-- Send batched events
	for eventName, batch in pairs(eventBatches) do
		if batch.event then
			if #batch.players == 1 then
				-- Single player - direct send
				batch.event:FireClient(batch.players[1], batch.data[1])
			else
				-- Multiple players - use FireAllClients if data is the same
				local allSameData = true
				local firstData = batch.data[1]
				
				for i = 2, #batch.data do
					if batch.data[i] ~= firstData then
						allSameData = false
						break
					end
				end
				
				if allSameData then
					batch.event:FireAllClients(firstData)
				else
					-- Send individually
					for i, player in ipairs(batch.players) do
						batch.event:FireClient(player, batch.data[i])
					end
				end
			end
		end
	end
end

-- Process DataStore batch
function BatchProcessor.ProcessDataStoreBatch(items)
	-- Group by store and operation type
	local storeOperations = {}
	
	for _, item in ipairs(items) do
		local storeKey = item.storeName or "default"
		local opType = item.operationType or "set"
		
		local key = storeKey .. "_" .. opType
		if not storeOperations[key] then
			storeOperations[key] = {
				store = item.dataStore,
				operations = {}
			}
		end
		
		table.insert(storeOperations[key].operations, item)
	end
	
	-- Execute batched operations
	for key, storeOp in pairs(storeOperations) do
		for _, op in ipairs(storeOp.operations) do
			local success, result = pcall(function()
				if op.operationType == "set" then
					return storeOp.store:SetAsync(op.key, op.value)
				elseif op.operationType == "get" then
					return storeOp.store:GetAsync(op.key)
				elseif op.operationType == "increment" then
					return storeOp.store:IncrementAsync(op.key, op.delta)
				end
			end)
			
			if op.callback then
				op.callback(success, result)
			end
		end
	end
end

-- Process player update batch
function BatchProcessor.ProcessPlayerUpdateBatch(items)
	local playerUpdates = {}
	
	-- Group by player
	for _, item in ipairs(items) do
		local playerId = item.playerId
		if not playerUpdates[playerId] then
			playerUpdates[playerId] = {
				player = item.player,
				updates = {}
			}
		end
		
		table.insert(playerUpdates[playerId].updates, item)
	end
	
	-- Apply batched updates
	for playerId, playerData in pairs(playerUpdates) do
		if playerData.player and playerData.player.Parent then
			for _, update in ipairs(playerData.updates) do
				if update.callback then
					update.callback(playerData.player, update.data)
				end
			end
		end
	end
end

-- Process analytics batch
function BatchProcessor.ProcessAnalyticsBatch(items)
	-- Aggregate analytics data for efficiency
	local aggregatedData = {}
	
	for _, item in ipairs(items) do
		local eventType = item.eventType or "unknown"
		if not aggregatedData[eventType] then
			aggregatedData[eventType] = {
				count = 0,
				data = {}
			}
		end
		
		aggregatedData[eventType].count = aggregatedData[eventType].count + 1
		table.insert(aggregatedData[eventType].data, item.data)
	end
	
	-- Send aggregated analytics
	for eventType, data in pairs(aggregatedData) do
		-- This would integrate with your analytics system
		-- For example, sending to an analytics service or storing in DataStore
	end
end

-- Add item to batch queue
function BatchProcessor.AddToBatch(operation, data, priority)
	priority = priority or "normal"
	
	local item = {
		operation = operation,
		data = data,
		timestamp = tick(),
		priority = priority
	}
	
	-- Add additional fields based on operation type
	if operation == "remoteEvent" then
		item.eventName = data.eventName
		item.remoteEvent = data.remoteEvent
		item.player = data.player
		item.data = data.eventData
	elseif operation == "datastore" then
		item.storeName = data.storeName
		item.dataStore = data.dataStore
		item.operationType = data.operationType
		item.key = data.key
		item.value = data.value
		item.callback = data.callback
	elseif operation == "playerUpdate" then
		item.playerId = data.playerId
		item.player = data.player
		item.callback = data.callback
		item.data = data.updateData
	elseif operation == "analytics" then
		item.eventType = data.eventType
		item.data = data.analyticsData
	end
	
	-- Check memory usage before adding
	local memoryUsage = BatchProcessor.GetMemoryUsage()
	if memoryUsage > BATCH_CONFIG.maxMemoryUsage then
		-- Emergency flush
		BatchProcessor.EmergencyFlush()
	end
	
	table.insert(batchQueues[priority], item)
	return true
end

-- Memory monitoring
function BatchProcessor.SetupMemoryMonitoring()
	spawn(function()
		while true do
			wait(10) -- Check every 10 seconds
			
			local memoryUsage = BatchProcessor.GetMemoryUsage()
			if memoryUsage > BATCH_CONFIG.maxMemoryUsage * 0.8 then
				-- Proactive processing when memory is high
				BatchProcessor.ProcessQueue("low", math.huge)
				BatchProcessor.ProcessQueue("normal", math.huge)
			end
		end
	end)
end

-- Get current memory usage
function BatchProcessor.GetMemoryUsage()
	local stats = game:GetService("Stats")
	return stats:GetTotalMemoryUsageMb()
end

-- Emergency flush all queues
function BatchProcessor.EmergencyFlush()
	print("[BatchProcessor] Emergency flush triggered")
	
	for priority, queue in pairs(batchQueues) do
		BatchProcessor.ProcessQueue(priority, math.huge)
	end
	
	-- Force garbage collection
	collectgarbage("collect")
end

-- Get processing statistics
function BatchProcessor.GetStats()
	local totalQueued = 0
	for _, queue in pairs(batchQueues) do
		totalQueued = totalQueued + #queue
	end
	
	return {
		totalProcessed = stats.totalProcessed,
		totalQueued = totalQueued,
		averageLatency = stats.averageLatency,
		currentBatchSize = stats.currentBatchSize,
		droppedItems = stats.droppedItems,
		memoryUsage = BatchProcessor.GetMemoryUsage()
	}
end

-- Quality of life functions
function BatchProcessor.FireRemoteEventBatched(remoteEvent, player, data, priority)
	return BatchProcessor.AddToBatch("remoteEvent", {
		eventName = remoteEvent.Name,
		remoteEvent = remoteEvent,
		player = player,
		eventData = data
	}, priority)
end

function BatchProcessor.SetDataStoreBatched(dataStore, key, value, callback, priority)
	return BatchProcessor.AddToBatch("datastore", {
		storeName = dataStore.Name,
		dataStore = dataStore,
		operationType = "set",
		key = key,
		value = value,
		callback = callback
	}, priority)
end

function BatchProcessor.UpdatePlayerBatched(player, updateCallback, updateData, priority)
	return BatchProcessor.AddToBatch("playerUpdate", {
		playerId = player.UserId,
		player = player,
		callback = updateCallback,
		updateData = updateData
	}, priority)
end

function BatchProcessor.RecordAnalyticsBatched(eventType, data, priority)
	return BatchProcessor.AddToBatch("analytics", {
		eventType = eventType,
		analyticsData = data
	}, priority or "low")
end

-- Set maximum batch size dynamically
function BatchProcessor.SetMaxBatchSize(size)
	BATCH_CONFIG.maxBatchSize = math.max(1, size)
	print("[BatchProcessor] Set max batch size to " .. size)
end

return BatchProcessor
