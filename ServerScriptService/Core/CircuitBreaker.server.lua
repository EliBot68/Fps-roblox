--!strict
--[[
	CircuitBreaker.server.lua
	Enterprise Circuit Breaker Pattern Implementation
	
	Provides comprehensive circuit breaker functionality to prevent cascading failures
	and maintain system resilience through automatic failure detection and recovery.
	
	Features:
	- Multiple circuit breaker states (Closed, Open, Half-Open)
	- Configurable failure thresholds and recovery timeouts
	- Sliding window failure detection
	- Automatic state transitions
	- Service health monitoring integration
	- Real-time metrics and analytics
	- Player notification coordination
	- Performance impact monitoring
	
	Author: Enterprise Development Team
	Created: December 2024
]]--

local ServiceLocator = require(script.Parent.Parent.ReplicatedStorage.Shared.ServiceLocator)
local ErrorHandler = require(script.Parent.Parent.ReplicatedStorage.Shared.ErrorHandler)

-- Services
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Types
export type CircuitBreakerState = "Closed" | "Open" | "HalfOpen"

export type CircuitBreakerConfig = {
	name: string,
	failureThreshold: number,
	successThreshold: number,
	timeout: number,
	monitoringWindowSize: number,
	slowCallDurationThreshold: number,
	slowCallRateThreshold: number,
	minimumNumberOfCalls: number,
	enableMetrics: boolean,
	enableNotifications: boolean
}

export type CallResult = {
	success: boolean,
	duration: number,
	timestamp: number,
	error: string?,
	metadata: {[string]: any}?
}

export type CircuitBreakerMetrics = {
	totalCalls: number,
	successfulCalls: number,
	failedCalls: number,
	slowCalls: number,
	averageResponseTime: number,
	errorRate: number,
	slowCallRate: number,
	lastFailureTime: number?,
	lastSuccessTime: number?,
	stateChangeCount: number,
	totalDowntime: number
}

export type CircuitBreakerInstance = {
	config: CircuitBreakerConfig,
	state: CircuitBreakerState,
	metrics: CircuitBreakerMetrics,
	callHistory: {CallResult},
	lastStateChange: number,
	stateChangeReason: string,
	
	-- Methods
	execute: (self: CircuitBreakerInstance, operation: () -> any) -> (boolean, any),
	recordSuccess: (self: CircuitBreakerInstance, duration: number, metadata: {[string]: any}?) -> (),
	recordFailure: (self: CircuitBreakerInstance, duration: number, error: string, metadata: {[string]: any}?) -> (),
	getState: (self: CircuitBreakerInstance) -> CircuitBreakerState,
	getMetrics: (self: CircuitBreakerInstance) -> CircuitBreakerMetrics,
	reset: (self: CircuitBreakerInstance) -> (),
	forceOpen: (self: CircuitBreakerInstance) -> (),
	forceClose: (self: CircuitBreakerInstance) -> (),
	isCallAllowed: (self: CircuitBreakerInstance) -> boolean
}

-- Circuit Breaker Manager
local CircuitBreakerManager = {}
CircuitBreakerManager.__index = CircuitBreakerManager

-- Private Variables
local logger: any
local analytics: any
local errorHandler: any
local configManager: any
local circuitBreakers: {[string]: CircuitBreakerInstance} = {}
local globalMetrics = {
	totalCircuitBreakers = 0,
	activeCircuitBreakers = 0,
	openCircuitBreakers = 0,
	totalCallsAllowed = 0,
	totalCallsRejected = 0,
	totalFailuresPrevented = 0
}

-- Configuration
local DEFAULT_CONFIG: CircuitBreakerConfig = {
	name = "default",
	failureThreshold = 5,
	successThreshold = 3,
	timeout = 30000, -- 30 seconds in milliseconds
	monitoringWindowSize = 100,
	slowCallDurationThreshold = 5000, -- 5 seconds
	slowCallRateThreshold = 0.5, -- 50%
	minimumNumberOfCalls = 10,
	enableMetrics = true,
	enableNotifications = true
}

-- Events
local CircuitBreakerStateChanged = Instance.new("BindableEvent")
local CircuitBreakerTripped = Instance.new("BindableEvent")
local CircuitBreakerRecovered = Instance.new("BindableEvent")
local CircuitBreakerMetricsUpdated = Instance.new("BindableEvent")

-- Remote Events for client communication
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local uiEvents = remoteEvents:WaitForChild("UIEvents")
local circuitBreakerNotification = uiEvents:WaitForChild("CircuitBreakerNotification")

-- Initialization
function CircuitBreakerManager.new(): typeof(CircuitBreakerManager)
	local self = setmetatable({}, CircuitBreakerManager)
	
	-- Get services
	logger = ServiceLocator:GetService("Logging")
	analytics = ServiceLocator:GetService("AnalyticsEngine")
	errorHandler = ServiceLocator:GetService("ErrorHandler")
	configManager = ServiceLocator:GetService("ConfigManager")
	
	if not logger then
		logger = { LogInfo = print, LogWarning = warn, LogError = warn }
	end
	
	-- Setup periodic tasks
	self:_setupMetricsCollection()
	self:_setupStateMonitoring()
	self:_setupPlayerNotifications()
	
	logger.LogInfo("CircuitBreakerManager initialized successfully", {
		defaultConfig = DEFAULT_CONFIG
	})
	
	return self
end

-- Circuit Breaker Creation and Management

-- Create new circuit breaker
function CircuitBreakerManager:CreateCircuitBreaker(name: string, config: CircuitBreakerConfig?): CircuitBreakerInstance
	local circuitBreakerConfig = config or table.clone(DEFAULT_CONFIG)
	circuitBreakerConfig.name = name
	
	local circuitBreaker = self:_createCircuitBreakerInstance(circuitBreakerConfig)
	circuitBreakers[name] = circuitBreaker
	
	globalMetrics.totalCircuitBreakers = globalMetrics.totalCircuitBreakers + 1
	globalMetrics.activeCircuitBreakers = globalMetrics.activeCircuitBreakers + 1
	
	logger.LogInfo("Circuit breaker created", {
		name = name,
		config = circuitBreakerConfig
	})
	
	-- Record analytics
	if analytics then
		analytics:RecordEvent(0, "circuit_breaker_created", {
			name = name,
			config = circuitBreakerConfig
		})
	end
	
	return circuitBreaker
end

-- Get circuit breaker by name
function CircuitBreakerManager:GetCircuitBreaker(name: string): CircuitBreakerInstance?
	return circuitBreakers[name]
end

-- Remove circuit breaker
function CircuitBreakerManager:RemoveCircuitBreaker(name: string): boolean
	local circuitBreaker = circuitBreakers[name]
	if not circuitBreaker then
		return false
	end
	
	circuitBreakers[name] = nil
	globalMetrics.activeCircuitBreakers = globalMetrics.activeCircuitBreakers - 1
	
	logger.LogInfo("Circuit breaker removed", {name = name})
	
	return true
end

-- Execute operation with circuit breaker protection
function CircuitBreakerManager:ExecuteWithProtection(name: string, operation: () -> any, config: CircuitBreakerConfig?): (boolean, any)
	local circuitBreaker = circuitBreakers[name]
	
	-- Create circuit breaker if it doesn't exist
	if not circuitBreaker then
		circuitBreaker = self:CreateCircuitBreaker(name, config)
	end
	
	return circuitBreaker:execute(operation)
end

-- Circuit Breaker Instance Implementation

-- Create circuit breaker instance
function CircuitBreakerManager:_createCircuitBreakerInstance(config: CircuitBreakerConfig): CircuitBreakerInstance
	local instance = {
		config = config,
		state = "Closed",
		metrics = {
			totalCalls = 0,
			successfulCalls = 0,
			failedCalls = 0,
			slowCalls = 0,
			averageResponseTime = 0,
			errorRate = 0,
			slowCallRate = 0,
			lastFailureTime = nil,
			lastSuccessTime = nil,
			stateChangeCount = 0,
			totalDowntime = 0
		},
		callHistory = {},
		lastStateChange = tick() * 1000,
		stateChangeReason = "Initial state"
	}
	
	-- Execute operation with circuit breaker protection
	function instance:execute(operation: () -> any): (boolean, any)
		local startTime = tick() * 1000
		
		-- Check if call is allowed
		if not self:isCallAllowed() then
			globalMetrics.totalCallsRejected = globalMetrics.totalCallsRejected + 1
			
			-- Simulate fast failure
			return false, "Circuit breaker is OPEN - calls rejected"
		end
		
		globalMetrics.totalCallsAllowed = globalMetrics.totalCallsAllowed + 1
		
		-- Execute operation
		local success, result = pcall(operation)
		local duration = (tick() * 1000) - startTime
		
		-- Record result
		if success then
			self:recordSuccess(duration, {result = result})
		else
			self:recordFailure(duration, tostring(result), {error = result})
		end
		
		return success, result
	end
	
	-- Record successful operation
	function instance:recordSuccess(duration: number, metadata: {[string]: any}?)
		local callResult: CallResult = {
			success = true,
			duration = duration,
			timestamp = tick() * 1000,
			error = nil,
			metadata = metadata
		}
		
		self:_addCallResult(callResult)
		self:_updateMetrics()
		self:_checkStateTransition()
		
		if self.config.enableMetrics and analytics then
			analytics:RecordEvent(0, "circuit_breaker_call_success", {
				circuitBreakerName = self.config.name,
				duration = duration,
				state = self.state
			})
		end
	end
	
	-- Record failed operation
	function instance:recordFailure(duration: number, error: string, metadata: {[string]: any}?)
		local callResult: CallResult = {
			success = false,
			duration = duration,
			timestamp = tick() * 1000,
			error = error,
			metadata = metadata
		}
		
		self:_addCallResult(callResult)
		self:_updateMetrics()
		self:_checkStateTransition()
		
		-- Report error to error handler
		if errorHandler then
			errorHandler:HandleError(error, "CircuitBreaker:" .. self.config.name, {
				duration = duration,
				state = self.state,
				metadata = metadata
			})
		end
		
		if self.config.enableMetrics and analytics then
			analytics:RecordEvent(0, "circuit_breaker_call_failure", {
				circuitBreakerName = self.config.name,
				duration = duration,
				error = error,
				state = self.state
			})
		end
	end
	
	-- Check if call is allowed based on current state
	function instance:isCallAllowed(): boolean
		local currentTime = tick() * 1000
		
		if self.state == "Closed" then
			return true
		elseif self.state == "Open" then
			-- Check if timeout has elapsed
			if currentTime - self.lastStateChange >= self.config.timeout then
				self:_transitionToHalfOpen()
				return true
			else
				return false
			end
		elseif self.state == "HalfOpen" then
			return true
		end
		
		return false
	end
	
	-- Get current state
	function instance:getState(): CircuitBreakerState
		return self.state
	end
	
	-- Get current metrics
	function instance:getMetrics(): CircuitBreakerMetrics
		return table.clone(self.metrics)
	end
	
	-- Reset circuit breaker to closed state
	function instance:reset(): ()
		self.state = "Closed"
		self.callHistory = {}
		self.metrics = {
			totalCalls = 0,
			successfulCalls = 0,
			failedCalls = 0,
			slowCalls = 0,
			averageResponseTime = 0,
			errorRate = 0,
			slowCallRate = 0,
			lastFailureTime = nil,
			lastSuccessTime = nil,
			stateChangeCount = self.metrics.stateChangeCount + 1,
			totalDowntime = self.metrics.totalDowntime
		}
		self.lastStateChange = tick() * 1000
		self.stateChangeReason = "Manual reset"
		
		self:_notifyStateChange("Reset")
		
		logger.LogInfo("Circuit breaker reset", {
			name = self.config.name,
			newState = self.state
		})
	end
	
	-- Force circuit breaker to open state
	function instance:forceOpen(): ()
		local previousState = self.state
		self.state = "Open"
		self.lastStateChange = tick() * 1000
		self.stateChangeReason = "Forced open"
		self.metrics.stateChangeCount = self.metrics.stateChangeCount + 1
		
		if previousState ~= "Open" then
			globalMetrics.openCircuitBreakers = globalMetrics.openCircuitBreakers + 1
		end
		
		self:_notifyStateChange("ForcedOpen")
		
		logger.LogWarning("Circuit breaker forced open", {
			name = self.config.name,
			previousState = previousState
		})
	end
	
	-- Force circuit breaker to closed state
	function instance:forceClose(): ()
		local previousState = self.state
		self.state = "Closed"
		self.lastStateChange = tick() * 1000
		self.stateChangeReason = "Forced closed"
		self.metrics.stateChangeCount = self.metrics.stateChangeCount + 1
		
		if previousState == "Open" then
			globalMetrics.openCircuitBreakers = globalMetrics.openCircuitBreakers - 1
		end
		
		self:_notifyStateChange("ForcedClosed")
		
		logger.LogInfo("Circuit breaker forced closed", {
			name = self.config.name,
			previousState = previousState
		})
	end
	
	-- Add call result to history
	function instance:_addCallResult(callResult: CallResult): ()
		table.insert(self.callHistory, callResult)
		
		-- Maintain sliding window size
		while #self.callHistory > self.config.monitoringWindowSize do
			table.remove(self.callHistory, 1)
		end
	end
	
	-- Update metrics based on call history
	function instance:_updateMetrics(): ()
		local totalCalls = #self.callHistory
		local successfulCalls = 0
		local failedCalls = 0
		local slowCalls = 0
		local totalDuration = 0
		local lastFailureTime = nil
		local lastSuccessTime = nil
		
		for _, call in ipairs(self.callHistory) do
			if call.success then
				successfulCalls = successfulCalls + 1
				lastSuccessTime = call.timestamp
			else
				failedCalls = failedCalls + 1
				lastFailureTime = call.timestamp
			end
			
			if call.duration >= self.config.slowCallDurationThreshold then
				slowCalls = slowCalls + 1
			end
			
			totalDuration = totalDuration + call.duration
		end
		
		self.metrics.totalCalls = totalCalls
		self.metrics.successfulCalls = successfulCalls
		self.metrics.failedCalls = failedCalls
		self.metrics.slowCalls = slowCalls
		self.metrics.averageResponseTime = totalCalls > 0 and (totalDuration / totalCalls) or 0
		self.metrics.errorRate = totalCalls > 0 and (failedCalls / totalCalls) or 0
		self.metrics.slowCallRate = totalCalls > 0 and (slowCalls / totalCalls) or 0
		self.metrics.lastFailureTime = lastFailureTime
		self.metrics.lastSuccessTime = lastSuccessTime
		
		-- Fire metrics updated event
		CircuitBreakerMetricsUpdated:Fire({
			circuitBreakerName = self.config.name,
			metrics = self.metrics
		})
	end
	
	-- Check for state transitions
	function instance:_checkStateTransition(): ()
		local currentState = self.state
		local newState = self:_calculateNewState()
		
		if newState ~= currentState then
			self:_transitionTo(newState)
		end
	end
	
	-- Calculate new state based on current metrics
	function instance:_calculateNewState(): CircuitBreakerState
		local totalCalls = self.metrics.totalCalls
		
		-- Not enough calls to make decision
		if totalCalls < self.config.minimumNumberOfCalls then
			return self.state
		end
		
		if self.state == "Closed" then
			-- Check if we should open
			local shouldOpen = false
			
			-- Check failure rate
			if self.metrics.errorRate >= (self.config.failureThreshold / self.config.monitoringWindowSize) then
				shouldOpen = true
			end
			
			-- Check slow call rate
			if self.metrics.slowCallRate >= self.config.slowCallRateThreshold then
				shouldOpen = true
			end
			
			if shouldOpen then
				return "Open"
			end
			
		elseif self.state == "HalfOpen" then
			local recentCalls = math.min(self.config.successThreshold + self.config.failureThreshold, #self.callHistory)
			local recentSuccesses = 0
			local recentFailures = 0
			
			-- Check recent calls only
			for i = math.max(1, #self.callHistory - recentCalls + 1), #self.callHistory do
				local call = self.callHistory[i]
				if call.success then
					recentSuccesses = recentSuccesses + 1
				else
					recentFailures = recentFailures + 1
				end
			end
			
			-- Transition to closed if we have enough successes
			if recentSuccesses >= self.config.successThreshold then
				return "Closed"
			end
			
			-- Transition to open if we have any failures
			if recentFailures > 0 then
				return "Open"
			end
		end
		
		return self.state
	end
	
	-- Transition to new state
	function instance:_transitionTo(newState: CircuitBreakerState): ()
		local previousState = self.state
		local currentTime = tick() * 1000
		
		-- Update downtime if transitioning from open
		if previousState == "Open" and newState ~= "Open" then
			local downtime = currentTime - self.lastStateChange
			self.metrics.totalDowntime = self.metrics.totalDowntime + downtime
			globalMetrics.openCircuitBreakers = globalMetrics.openCircuitBreakers - 1
		end
		
		-- Update open circuit breakers count
		if newState == "Open" and previousState ~= "Open" then
			globalMetrics.openCircuitBreakers = globalMetrics.openCircuitBreakers + 1
		end
		
		self.state = newState
		self.lastStateChange = currentTime
		self.metrics.stateChangeCount = self.metrics.stateChangeCount + 1
		
		-- Set transition reason
		if newState == "Open" then
			self.stateChangeReason = "Failure threshold exceeded"
		elseif newState == "Closed" then
			self.stateChangeReason = "Success threshold met"
		elseif newState == "HalfOpen" then
			self.stateChangeReason = "Timeout elapsed"
		end
		
		-- Notify state change
		self:_notifyStateChange("AutoTransition")
		
		logger.LogInfo("Circuit breaker state transition", {
			name = self.config.name,
			previousState = previousState,
			newState = newState,
			reason = self.stateChangeReason,
			metrics = self.metrics
		})
	end
	
	-- Transition to half-open state
	function instance:_transitionToHalfOpen(): ()
		if self.state == "Open" then
			self:_transitionTo("HalfOpen")
		end
	end
	
	-- Notify state change
	function instance:_notifyStateChange(changeType: string): ()
		local eventData = {
			circuitBreakerName = self.config.name,
			previousState = self.state,
			newState = self.state,
			changeType = changeType,
			reason = self.stateChangeReason,
			timestamp = tick() * 1000,
			metrics = self.metrics
		}
		
		-- Fire appropriate events
		CircuitBreakerStateChanged:Fire(eventData)
		
		if self.state == "Open" then
			CircuitBreakerTripped:Fire(eventData)
			globalMetrics.totalFailuresPrevented = globalMetrics.totalFailuresPrevented + 1
		elseif self.state == "Closed" and changeType == "AutoTransition" then
			CircuitBreakerRecovered:Fire(eventData)
		end
		
		-- Send player notifications if enabled
		if self.config.enableNotifications then
			self:_sendPlayerNotifications(eventData)
		end
		
		-- Record analytics
		if analytics then
			analytics:RecordEvent(0, "circuit_breaker_state_changed", eventData)
		end
	end
	
	-- Send player notifications
	function instance:_sendPlayerNotifications(eventData: any): ()
		-- Only notify for significant state changes
		if eventData.newState == "Open" or (eventData.newState == "Closed" and eventData.previousState == "Open") then
			local message = ""
			local severity = "info"
			
			if eventData.newState == "Open" then
				message = "Service temporarily unavailable due to high error rate. Attempting recovery..."
				severity = "warning"
			else
				message = "Service has recovered and is operating normally."
				severity = "success"
			end
			
			-- Send to all players
			for _, player in ipairs(Players:GetPlayers()) do
				circuitBreakerNotification:FireClient(player, {
					serviceName = self.config.name,
					message = message,
					severity = severity,
					state = eventData.newState,
					timestamp = eventData.timestamp
				})
			end
		end
	end
	
	return instance
end

-- Monitoring and Management

-- Setup metrics collection
function CircuitBreakerManager:_setupMetricsCollection(): ()
	-- Collect metrics every 30 seconds
	task.spawn(function()
		while true do
			task.wait(30)
			self:_collectAndReportMetrics()
		end
	end)
end

-- Setup state monitoring
function CircuitBreakerManager:_setupStateMonitoring(): ()
	-- Monitor states every 10 seconds
	task.spawn(function()
		while true do
			task.wait(10)
			self:_monitorCircuitBreakerStates()
		end
	end)
end

-- Setup player notifications
function CircuitBreakerManager:_setupPlayerNotifications(): ()
	-- Handle player joining for state updates
	Players.PlayerAdded:Connect(function(player)
		task.wait(1) -- Wait for player to load
		
		-- Send current circuit breaker states
		for name, circuitBreaker in pairs(circuitBreakers) do
			if circuitBreaker.state ~= "Closed" then
				circuitBreakerNotification:FireClient(player, {
					serviceName = name,
					message = "Service currently in " .. circuitBreaker.state .. " state",
					severity = "info",
					state = circuitBreaker.state,
					timestamp = tick() * 1000
				})
			end
		end
	end)
end

-- Collect and report comprehensive metrics
function CircuitBreakerManager:_collectAndReportMetrics(): ()
	local allMetrics = {
		global = globalMetrics,
		circuitBreakers = {}
	}
	
	-- Collect individual circuit breaker metrics
	for name, circuitBreaker in pairs(circuitBreakers) do
		allMetrics.circuitBreakers[name] = {
			name = name,
			state = circuitBreaker.state,
			metrics = circuitBreaker:getMetrics(),
			config = circuitBreaker.config,
			stateChangeReason = circuitBreaker.stateChangeReason,
			lastStateChange = circuitBreaker.lastStateChange
		}
	end
	
	-- Report to analytics
	if analytics then
		analytics:RecordEvent(0, "circuit_breaker_metrics_collected", allMetrics)
	end
	
	-- Log summary
	logger.LogInfo("Circuit breaker metrics collected", {
		totalCircuitBreakers = globalMetrics.totalCircuitBreakers,
		activeCircuitBreakers = globalMetrics.activeCircuitBreakers,
		openCircuitBreakers = globalMetrics.openCircuitBreakers,
		totalCallsAllowed = globalMetrics.totalCallsAllowed,
		totalCallsRejected = globalMetrics.totalCallsRejected
	})
end

-- Monitor circuit breaker states for issues
function CircuitBreakerManager:_monitorCircuitBreakerStates(): ()
	local currentTime = tick() * 1000
	local issuesDetected = false
	
	for name, circuitBreaker in pairs(circuitBreakers) do
		-- Check for circuit breakers stuck in open state
		if circuitBreaker.state == "Open" then
			local timeInOpen = currentTime - circuitBreaker.lastStateChange
			
			-- Alert if open for more than 5 minutes
			if timeInOpen > 300000 then
				logger.LogWarning("Circuit breaker stuck in open state", {
					name = name,
					timeInOpen = timeInOpen,
					reason = circuitBreaker.stateChangeReason
				})
				issuesDetected = true
			end
		end
		
		-- Check for high error rates even when closed
		if circuitBreaker.state == "Closed" and circuitBreaker.metrics.errorRate > 0.3 then
			logger.LogWarning("High error rate detected", {
				name = name,
				errorRate = circuitBreaker.metrics.errorRate,
				state = circuitBreaker.state
			})
			issuesDetected = true
		end
	end
	
	-- Report system health
	if not issuesDetected and globalMetrics.openCircuitBreakers == 0 then
		-- System is healthy, no action needed
	else
		logger.LogWarning("Circuit breaker system issues detected", {
			openCircuitBreakers = globalMetrics.openCircuitBreakers,
			totalCircuitBreakers = globalMetrics.activeCircuitBreakers
		})
	end
end

-- Public API

-- Get all circuit breakers
function CircuitBreakerManager:GetAllCircuitBreakers(): {[string]: CircuitBreakerInstance}
	return table.clone(circuitBreakers)
end

-- Get circuit breaker names
function CircuitBreakerManager:GetCircuitBreakerNames(): {string}
	local names = {}
	for name in pairs(circuitBreakers) do
		table.insert(names, name)
	end
	return names
end

-- Get global metrics
function CircuitBreakerManager:GetGlobalMetrics(): typeof(globalMetrics)
	return table.clone(globalMetrics)
end

-- Get circuit breakers by state
function CircuitBreakerManager:GetCircuitBreakersByState(state: CircuitBreakerState): {[string]: CircuitBreakerInstance}
	local filtered = {}
	for name, circuitBreaker in pairs(circuitBreakers) do
		if circuitBreaker.state == state then
			filtered[name] = circuitBreaker
		end
	end
	return filtered
end

-- Reset all circuit breakers
function CircuitBreakerManager:ResetAllCircuitBreakers(): ()
	for name, circuitBreaker in pairs(circuitBreakers) do
		circuitBreaker:reset()
	end
	
	logger.LogInfo("All circuit breakers reset", {
		count = globalMetrics.activeCircuitBreakers
	})
end

-- Force all circuit breakers to specific state
function CircuitBreakerManager:ForceAllToState(state: CircuitBreakerState): ()
	for name, circuitBreaker in pairs(circuitBreakers) do
		if state == "Open" then
			circuitBreaker:forceOpen()
		elseif state == "Closed" then
			circuitBreaker:forceClose()
		end
	end
	
	logger.LogInfo("All circuit breakers forced to state", {
		state = state,
		count = globalMetrics.activeCircuitBreakers
	})
end

-- Event Connections
function CircuitBreakerManager:OnStateChanged(callback: (any) -> ()): RBXScriptConnection
	return CircuitBreakerStateChanged.Event:Connect(callback)
end

function CircuitBreakerManager:OnCircuitBreakerTripped(callback: (any) -> ()): RBXScriptConnection
	return CircuitBreakerTripped.Event:Connect(callback)
end

function CircuitBreakerManager:OnCircuitBreakerRecovered(callback: (any) -> ()): RBXScriptConnection
	return CircuitBreakerRecovered.Event:Connect(callback)
end

function CircuitBreakerManager:OnMetricsUpdated(callback: (any) -> ()): RBXScriptConnection
	return CircuitBreakerMetricsUpdated.Event:Connect(callback)
end

-- Health Check
function CircuitBreakerManager:GetHealthStatus(): {status: string, metrics: any}
	local openCount = globalMetrics.openCircuitBreakers
	local totalCount = globalMetrics.activeCircuitBreakers
	local rejectionRate = globalMetrics.totalCallsAllowed > 0 and 
		(globalMetrics.totalCallsRejected / (globalMetrics.totalCallsAllowed + globalMetrics.totalCallsRejected)) or 0
	
	local status = "healthy"
	if openCount > totalCount * 0.5 then
		status = "critical"
	elseif openCount > totalCount * 0.2 then
		status = "degraded"
	elseif rejectionRate > 0.1 then
		status = "warning"
	end
	
	return {
		status = status,
		metrics = {
			totalCircuitBreakers = totalCount,
			openCircuitBreakers = openCount,
			healthyCircuitBreakers = totalCount - openCount,
			callsAllowed = globalMetrics.totalCallsAllowed,
			callsRejected = globalMetrics.totalCallsRejected,
			rejectionRate = rejectionRate,
			failuresPrevented = globalMetrics.totalFailuresPrevented
		}
	}
end

-- Initialize and register service
local circuitBreakerManager = CircuitBreakerManager.new()

-- Register with ServiceLocator
task.wait(1) -- Ensure ServiceLocator is ready
ServiceLocator:RegisterService("CircuitBreaker", circuitBreakerManager)

-- Example usage and testing
task.spawn(function()
	task.wait(5) -- Wait for system to initialize
	
	-- Create example circuit breakers for critical services
	local datascoreCircuitBreaker = circuitBreakerManager:CreateCircuitBreaker("DataStore", {
		name = "DataStore",
		failureThreshold = 3,
		successThreshold = 2,
		timeout = 60000, -- 1 minute
		monitoringWindowSize = 50,
		slowCallDurationThreshold = 3000,
		slowCallRateThreshold = 0.4,
		minimumNumberOfCalls = 5,
		enableMetrics = true,
		enableNotifications = true
	})
	
	local networkCircuitBreaker = circuitBreakerManager:CreateCircuitBreaker("Network", {
		name = "Network",
		failureThreshold = 5,
		successThreshold = 3,
		timeout = 30000, -- 30 seconds
		monitoringWindowSize = 100,
		slowCallDurationThreshold = 5000,
		slowCallRateThreshold = 0.5,
		minimumNumberOfCalls = 10,
		enableMetrics = true,
		enableNotifications = true
	})
	
	logger.LogInfo("Circuit breaker examples created successfully")
end)

return circuitBreakerManager
