--[[
	EnhancedNetworkClient.client.lua
	Advanced client-side network management with circuit breaker pattern
	
	Features:
	- Exponential backoff with jitter for retry logic
	- Circuit breaker pattern for failed RemoteEvent calls
	- Priority-based retry queues with different strategies
	- Advanced metrics collection and monitoring
	
	Part of Phase 1.2 Network Optimization Enhancement
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- Import dependencies
local ServiceLocator = require(ReplicatedStorage.Shared.ServiceLocator)
local NetworkBatcher = require(ReplicatedStorage.Shared.NetworkBatcher)

local EnhancedNetworkClient = {}
local LocalPlayer = Players.LocalPlayer

-- Enhanced configuration with circuit breaker settings
local CLIENT_CONFIG = {
	PING_TIMEOUT = 5000,           -- 5 seconds max ping wait
	BASE_RETRY_DELAY = 1000,       -- Base retry delay in ms
	MAX_RETRY_DELAY = 30000,       -- Maximum retry delay (30 seconds)
	JITTER_FACTOR = 0.1,           -- 10% jitter to prevent thundering herd
	COMPRESSION_THRESHOLD = 1024,   -- Decompress payloads > 1KB
	STATS_UPDATE_INTERVAL = 5,     -- Update local stats every 5 seconds
	
	-- Circuit breaker configuration
	CIRCUIT_BREAKER = {
		FAILURE_THRESHOLD = 5,      -- Open circuit after 5 failures
		SUCCESS_THRESHOLD = 3,      -- Close circuit after 3 successes
		TIMEOUT = 60000,           -- Circuit breaker timeout (60 seconds)
		HALF_OPEN_MAX_CALLS = 3    -- Max calls in half-open state
	},
	
	-- Priority-based retry strategies
	RETRY_STRATEGIES = {
		Critical = {
			maxAttempts = 5,
			baseDelay = 100,    -- 100ms base delay for critical events
			backoffMultiplier = 1.5,
			jitter = true
		},
		Normal = {
			maxAttempts = 3,
			baseDelay = 1000,   -- 1s base delay for normal events
			backoffMultiplier = 2.0,
			jitter = true
		},
		Low = {
			maxAttempts = 2,
			baseDelay = 5000,   -- 5s base delay for low priority
			backoffMultiplier = 3.0,
			jitter = false
		}
	}
}

-- Circuit breaker states
local CircuitState = {
	Closed = "CLOSED",
	Open = "OPEN",
	HalfOpen = "HALF_OPEN"
}

-- Enhanced client statistics with circuit breaker metrics
local clientStats = {
	messagesReceived = 0,
	bytesReceived = 0,
	eventsProcessed = 0,
	averagePing = 0,
	pingHistory = {},
	connectionQuality = "Unknown",
	startTime = tick(),
	lastPingTime = 0,
	packetsLost = 0,
	
	-- Circuit breaker statistics
	circuitBreakerStats = {
		state = CircuitState.Closed,
		failureCount = 0,
		successCount = 0,
		lastFailureTime = 0,
		lastStateChange = tick(),
		halfOpenCalls = 0
	},
	
	-- Retry statistics by priority
	retryStats = {
		Critical = {attempts = 0, successes = 0, failures = 0},
		Normal = {attempts = 0, successes = 0, failures = 0},
		Low = {attempts = 0, successes = 0, failures = 0}
	}
}

-- Enhanced event handlers registry with priority classification
local eventHandlers = {}
local circuitBreakers = {} -- Per-endpoint circuit breakers
local priorityRetryQueues = {
	Critical = {},
	Normal = {},
	Low = {}
}

-- Metrics integration
local metricsExporter = nil

-- Remote events
local BatchedEventsRemote = ReplicatedStorage:WaitForChild("BatchedEvents")
local NetworkPingRemote = ReplicatedStorage:WaitForChild("NetworkPing")
local NetworkQualityRemote = ReplicatedStorage:WaitForChild("NetworkQuality")

-- Initialize enhanced network client
function EnhancedNetworkClient.Initialize()
	-- Initialize metrics integration
	spawn(function()
		while not metricsExporter do
			wait(0.1)
			metricsExporter = ServiceLocator.GetService("MetricsExporter")
		end
	end)
	
	-- Set up event connections
	BatchedEventsRemote.OnClientEvent:Connect(EnhancedNetworkClient.HandleBatchedEvents)
	NetworkPingRemote.OnClientEvent:Connect(EnhancedNetworkClient.HandlePingRequest)
	NetworkQualityRemote.OnClientEvent:Connect(EnhancedNetworkClient.HandleQualityUpdate)
	
	-- Start enhanced monitoring systems
	EnhancedNetworkClient.StartStatsMonitoring()
	EnhancedNetworkClient.StartRetryProcessor()
	EnhancedNetworkClient.StartPingTimeoutChecker()
	EnhancedNetworkClient.StartCircuitBreakerMonitoring()
	
	-- Register with Service Locator
	ServiceLocator.RegisterService("EnhancedNetworkClient", EnhancedNetworkClient, {})
	
	local logger = ServiceLocator.GetService("Logging")
	if logger then
		logger.Info("EnhancedNetworkClient", "Enhanced client network management initialized")
	else
		print("[EnhancedNetworkClient] ✓ Enhanced client network management initialized")
	end
end

-- Enhanced retry logic with exponential backoff and jitter
function EnhancedNetworkClient.CalculateRetryDelay(priority: string, attemptNumber: number): number
	local strategy = CLIENT_CONFIG.RETRY_STRATEGIES[priority] or CLIENT_CONFIG.RETRY_STRATEGIES.Normal
	
	-- Calculate exponential backoff
	local delay = strategy.baseDelay * (strategy.backoffMultiplier ^ (attemptNumber - 1))
	
	-- Apply maximum delay cap
	delay = math.min(delay, CLIENT_CONFIG.MAX_RETRY_DELAY)
	
	-- Add jitter to prevent thundering herd
	if strategy.jitter then
		local jitterAmount = delay * CLIENT_CONFIG.JITTER_FACTOR
		local jitter = (math.random() * 2 - 1) * jitterAmount -- Random between -jitterAmount and +jitterAmount
		delay = delay + jitter
	end
	
	return delay / 1000 -- Convert to seconds
end

-- Circuit breaker implementation for RemoteEvent calls
function EnhancedNetworkClient.GetCircuitBreaker(endpoint: string): {[string]: any}
	if not circuitBreakers[endpoint] then
		circuitBreakers[endpoint] = {
			state = CircuitState.Closed,
			failureCount = 0,
			successCount = 0,
			lastFailureTime = 0,
			lastStateChange = tick(),
			halfOpenCalls = 0
		}
	end
	return circuitBreakers[endpoint]
end

-- Check if circuit breaker allows the call
function EnhancedNetworkClient.CanExecuteCall(endpoint: string): boolean
	local breaker = EnhancedNetworkClient.GetCircuitBreaker(endpoint)
	local currentTime = tick()
	
	if breaker.state == CircuitState.Closed then
		return true
	elseif breaker.state == CircuitState.Open then
		-- Check if timeout period has passed
		if currentTime - breaker.lastStateChange >= CLIENT_CONFIG.CIRCUIT_BREAKER.TIMEOUT / 1000 then
			breaker.state = CircuitState.HalfOpen
			breaker.halfOpenCalls = 0
			breaker.lastStateChange = currentTime
			return true
		end
		return false
	elseif breaker.state == CircuitState.HalfOpen then
		return breaker.halfOpenCalls < CLIENT_CONFIG.CIRCUIT_BREAKER.HALF_OPEN_MAX_CALLS
	end
	
	return false
end

-- Record circuit breaker call result
function EnhancedNetworkClient.RecordCallResult(endpoint: string, success: boolean)
	local breaker = EnhancedNetworkClient.GetCircuitBreaker(endpoint)
	local currentTime = tick()
	
	if success then
		breaker.successCount = breaker.successCount + 1
		
		if breaker.state == CircuitState.HalfOpen then
			if breaker.successCount >= CLIENT_CONFIG.CIRCUIT_BREAKER.SUCCESS_THRESHOLD then
				breaker.state = CircuitState.Closed
				breaker.failureCount = 0
				breaker.lastStateChange = currentTime
			end
		elseif breaker.state == CircuitState.Closed then
			breaker.failureCount = 0 -- Reset failure count on success
		end
	else
		breaker.failureCount = breaker.failureCount + 1
		breaker.lastFailureTime = currentTime
		
		if breaker.state == CircuitState.Closed then
			if breaker.failureCount >= CLIENT_CONFIG.CIRCUIT_BREAKER.FAILURE_THRESHOLD then
				breaker.state = CircuitState.Open
				breaker.lastStateChange = currentTime
			end
		elseif breaker.state == CircuitState.HalfOpen then
			breaker.state = CircuitState.Open
			breaker.lastStateChange = currentTime
		end
	end
	
	if breaker.state == CircuitState.HalfOpen then
		breaker.halfOpenCalls = breaker.halfOpenCalls + 1
	end
	
	-- Export circuit breaker metrics
	if metricsExporter then
		metricsExporter.SetGauge("network_circuit_breaker_state", 
			breaker.state == CircuitState.Closed and 0 or (breaker.state == CircuitState.HalfOpen and 1 or 2), 
			{endpoint = endpoint})
		metricsExporter.SetGauge("network_circuit_breaker_failures", breaker.failureCount, {endpoint = endpoint})
	end
end

-- Enhanced event processing with circuit breaker protection
function EnhancedNetworkClient.HandleBatchedEvents(batch: {[string]: any})
	local startTime = tick()
	local processedEvents = 0
	local failedEvents = 0
	
	for _, event in ipairs(batch.events or {}) do
		local success = true
		local endpoint = event.eventType
		
		-- Check circuit breaker
		if not EnhancedNetworkClient.CanExecuteCall(endpoint) then
			EnhancedNetworkClient.AddToRetryQueue(event, "Circuit breaker open")
			failedEvents = failedEvents + 1
			continue
		end
		
		-- Process event with error handling
		local eventSuccess, eventError = pcall(function()
			if eventHandlers[event.eventType] then
				eventHandlers[event.eventType](event.data, LocalPlayer)
				processedEvents = processedEvents + 1
			else
				warn("[EnhancedNetworkClient] No handler for event type: " .. tostring(event.eventType))
				failedEvents = failedEvents + 1
				success = false
			end
		end)
		
		if not eventSuccess then
			success = false
			failedEvents = failedEvents + 1
			warn("[EnhancedNetworkClient] Error processing event: " .. tostring(eventError))
		end
		
		-- Record circuit breaker result
		EnhancedNetworkClient.RecordCallResult(endpoint, success)
		
		if not success then
			EnhancedNetworkClient.AddToRetryQueue(event, eventError or "Unknown error")
		end
	end
	
	-- Update statistics
	clientStats.messagesReceived = clientStats.messagesReceived + 1
	clientStats.eventsProcessed = clientStats.eventsProcessed + processedEvents
	
	-- Export metrics
	if metricsExporter then
		metricsExporter.IncrementCounter("network_events_processed", {
			status = "success",
			player_id = tostring(LocalPlayer.UserId)
		}, processedEvents)
		
		if failedEvents > 0 then
			metricsExporter.IncrementCounter("network_events_processed", {
				status = "failed",
				player_id = tostring(LocalPlayer.UserId)
			}, failedEvents)
		end
		
		metricsExporter.ObserveHistogram("network_event_processing_time", (tick() - startTime) * 1000, {
			player_id = tostring(LocalPlayer.UserId)
		})
	end
	
	-- Send batch acknowledgment
	EnhancedNetworkClient.SendBatchAcknowledgment(batch.batchId)
end

-- Enhanced retry queue with priority-based strategies
function EnhancedNetworkClient.AddToRetryQueue(event: {[string]: any}, reason: string)
	local priority = event.priority or "Normal"
	local retryData = {
		event = event,
		reason = reason,
		retryCount = (event.retryCount or 0) + 1,
		nextRetryTime = tick() + EnhancedNetworkClient.CalculateRetryDelay(priority, (event.retryCount or 0) + 1),
		priority = priority,
		firstFailureTime = event.firstFailureTime or tick()
	}
	
	-- Check if max attempts exceeded
	local strategy = CLIENT_CONFIG.RETRY_STRATEGIES[priority] or CLIENT_CONFIG.RETRY_STRATEGIES.Normal
	if retryData.retryCount <= strategy.maxAttempts then
		table.insert(priorityRetryQueues[priority], retryData)
		
		-- Update retry statistics
		clientStats.retryStats[priority].attempts = clientStats.retryStats[priority].attempts + 1
		
		local logger = ServiceLocator.GetService("Logging")
		if logger then
			logger.Info("EnhancedNetworkClient", string.format(
				"Added event to %s priority retry queue (attempt %d/%d): %s - %s", 
				priority, retryData.retryCount, strategy.maxAttempts, event.eventType, reason
			))
		end
		
		-- Export retry metrics
		if metricsExporter then
			metricsExporter.IncrementCounter("network_retry_attempts", {
				priority = priority,
				reason = reason
			})
		end
	else
		-- Event permanently failed
		clientStats.retryStats[priority].failures = clientStats.retryStats[priority].failures + 1
		
		local logger = ServiceLocator.GetService("Logging")
		if logger then
			logger.Error("EnhancedNetworkClient", string.format(
				"Event permanently failed after %d attempts: %s - %s", 
				strategy.maxAttempts, event.eventType, reason
			))
		end
	end
end

-- Enhanced retry processor with priority handling
function EnhancedNetworkClient.StartRetryProcessor()
	spawn(function()
		while true do
			local currentTime = tick()
			
			-- Process each priority queue
			for priority, queue in pairs(priorityRetryQueues) do
				for i = #queue, 1, -1 do
					local retryData = queue[i]
					
					if currentTime >= retryData.nextRetryTime then
						table.remove(queue, i)
						
						-- Check circuit breaker again
						if EnhancedNetworkClient.CanExecuteCall(retryData.event.eventType) then
							-- Retry the event
							local success, error = pcall(function()
								if eventHandlers[retryData.event.eventType] then
									eventHandlers[retryData.event.eventType](retryData.event.data, LocalPlayer)
									return true
								end
								return false
							end)
							
							if success then
								-- Retry succeeded
								clientStats.retryStats[priority].successes = clientStats.retryStats[priority].successes + 1
								EnhancedNetworkClient.RecordCallResult(retryData.event.eventType, true)
							else
								-- Retry failed, add back to queue
								EnhancedNetworkClient.RecordCallResult(retryData.event.eventType, false)
								EnhancedNetworkClient.AddToRetryQueue(retryData.event, error or "Retry failed")
							end
						else
							-- Circuit breaker still open, add back to queue
							EnhancedNetworkClient.AddToRetryQueue(retryData.event, "Circuit breaker open")
						end
					end
				end
			end
			
			wait(0.1) -- Check retry queue every 100ms
		end
	end)
end

-- Circuit breaker monitoring and metrics
function EnhancedNetworkClient.StartCircuitBreakerMonitoring()
	spawn(function()
		while true do
			-- Export circuit breaker statistics
			if metricsExporter then
				for endpoint, breaker in pairs(circuitBreakers) do
					metricsExporter.SetGauge("network_circuit_breaker_state", 
						breaker.state == CircuitState.Closed and 0 or (breaker.state == CircuitState.HalfOpen and 1 or 2), 
						{endpoint = endpoint, player_id = tostring(LocalPlayer.UserId)})
					
					metricsExporter.SetGauge("network_circuit_breaker_failures", breaker.failureCount, 
						{endpoint = endpoint, player_id = tostring(LocalPlayer.UserId)})
				end
				
				-- Export retry queue sizes
				for priority, queue in pairs(priorityRetryQueues) do
					metricsExporter.SetGauge("network_retry_queue_size", #queue, {
						priority = priority,
						player_id = tostring(LocalPlayer.UserId)
					})
				end
			end
			
			wait(5) -- Update every 5 seconds
		end
	end)
end

-- Enhanced ping measurement with jitter detection
function EnhancedNetworkClient.HandlePingRequest(pingId: string, serverTime: number)
	local clientTime = tick()
	local roundTripTime = (clientTime - serverTime) * 1000 -- Convert to milliseconds
	
	-- Update ping history with jitter calculation
	table.insert(clientStats.pingHistory, {
		ping = roundTripTime,
		timestamp = clientTime,
		jitter = 0
	})
	
	-- Calculate jitter if we have previous ping data
	if #clientStats.pingHistory >= 2 then
		local previousPing = clientStats.pingHistory[#clientStats.pingHistory - 1].ping
		local jitter = math.abs(roundTripTime - previousPing)
		clientStats.pingHistory[#clientStats.pingHistory].jitter = jitter
	end
	
	-- Keep only last 20 ping measurements
	if #clientStats.pingHistory > 20 then
		table.remove(clientStats.pingHistory, 1)
	end
	
	-- Calculate average ping
	local totalPing = 0
	local totalJitter = 0
	for _, pingData in ipairs(clientStats.pingHistory) do
		totalPing = totalPing + pingData.ping
		totalJitter = totalJitter + pingData.jitter
	end
	
	clientStats.averagePing = totalPing / #clientStats.pingHistory
	local averageJitter = totalJitter / math.max(#clientStats.pingHistory - 1, 1)
	
	-- Export ping metrics
	if metricsExporter then
		metricsExporter.ObserveHistogram("network_latency_ms", roundTripTime, {
			player_id = tostring(LocalPlayer.UserId)
		})
		metricsExporter.SetGauge("network_jitter_ms", averageJitter, {
			player_id = tostring(LocalPlayer.UserId)
		})
	end
	
	-- Send ping response
	NetworkPingRemote:FireServer(pingId, clientTime)
end

-- Get enhanced statistics including circuit breaker and retry metrics
function EnhancedNetworkClient.GetStats(): {[string]: any}
	local stats = {}
	for key, value in pairs(clientStats) do
		stats[key] = value
	end
	
	-- Add circuit breaker summary
	stats.circuitBreakerSummary = {}
	for endpoint, breaker in pairs(circuitBreakers) do
		stats.circuitBreakerSummary[endpoint] = {
			state = breaker.state,
			failureCount = breaker.failureCount,
			successCount = breaker.successCount
		}
	end
	
	-- Add retry queue summary
	stats.retryQueueSummary = {}
	for priority, queue in pairs(priorityRetryQueues) do
		stats.retryQueueSummary[priority] = #queue
	end
	
	return stats
end

-- Register event handler with priority classification
function EnhancedNetworkClient.RegisterHandler(eventType: string, handler: (any, Player) -> (), priority: string?)
	eventHandlers[eventType] = handler
	
	-- Initialize circuit breaker for this endpoint
	EnhancedNetworkClient.GetCircuitBreaker(eventType)
	
	local logger = ServiceLocator.GetService("Logging")
	if logger then
		logger.Debug("EnhancedNetworkClient", "Registered enhanced handler for event type: " .. eventType)
	end
end

-- Unregister event handler
function EnhancedNetworkClient.UnregisterHandler(eventType: string)
	eventHandlers[eventType] = nil
	
	local logger = ServiceLocator.GetService("Logging")
	if logger then
		logger.Debug("EnhancedNetworkClient", "Unregistered handler for event type: " .. eventType)
	end
end

-- Send batch acknowledgment
function EnhancedNetworkClient.SendBatchAcknowledgment(batchId: string)
	-- Implementation depends on server expecting acknowledgments
	-- For now, we'll prepare the infrastructure
	
	local logger = ServiceLocator.GetService("Logging")
	if logger then
		logger.Debug("EnhancedNetworkClient", "Acknowledged batch: " .. batchId)
	end
end

-- Start enhanced statistics monitoring
function EnhancedNetworkClient.StartStatsMonitoring()
	spawn(function()
		while true do
			wait(CLIENT_CONFIG.STATS_UPDATE_INTERVAL)
			
			-- Export comprehensive client statistics
			if metricsExporter then
				metricsExporter.SetGauge("network_messages_received", clientStats.messagesReceived, {
					player_id = tostring(LocalPlayer.UserId)
				})
				metricsExporter.SetGauge("network_events_processed", clientStats.eventsProcessed, {
					player_id = tostring(LocalPlayer.UserId)
				})
				metricsExporter.SetGauge("network_average_ping", clientStats.averagePing, {
					player_id = tostring(LocalPlayer.UserId)
				})
				
				-- Export retry statistics
				for priority, stats in pairs(clientStats.retryStats) do
					metricsExporter.SetGauge("network_retry_success_rate", 
						stats.attempts > 0 and (stats.successes / stats.attempts) or 1, {
						priority = priority,
						player_id = tostring(LocalPlayer.UserId)
					})
				end
			end
		end
	end)
end

-- Start ping timeout monitoring
function EnhancedNetworkClient.StartPingTimeoutChecker()
	spawn(function()
		while true do
			wait(CLIENT_CONFIG.PING_TIMEOUT / 1000)
			
			local currentTime = tick()
			if currentTime - clientStats.lastPingTime > CLIENT_CONFIG.PING_TIMEOUT / 1000 then
				clientStats.packetsLost = clientStats.packetsLost + 1
				
				if metricsExporter then
					metricsExporter.IncrementCounter("network_ping_timeouts", {
						player_id = tostring(LocalPlayer.UserId)
					})
				end
			end
		end
	end)
end

-- Handle connection quality updates
function EnhancedNetworkClient.HandleQualityUpdate(quality: string, score: number)
	clientStats.connectionQuality = quality
	
	if metricsExporter then
		metricsExporter.SetGauge("connection_quality_scores", score, {
			player_id = tostring(LocalPlayer.UserId),
			quality_tier = quality
		})
	end
end

return EnhancedNetworkClient
