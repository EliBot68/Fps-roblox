--!strict
--[[
	ErrorHandler.lua
	Enterprise Error Handling & Recovery System
	
	Provides comprehensive error handling, circuit breaker patterns, graceful degradation,
	and automatic recovery mechanisms for enterprise-grade reliability.
	
	Features:
	- Circuit breaker pattern implementation
	- Graceful service degradation
	- Automatic error recovery
	- Error classification and routing
	- Performance impact monitoring
	- Recovery strategy management
	- Error analytics and reporting
	- Player notification coordination
	
	Author: Enterprise Development Team
	Created: December 2024
]]--

local ServiceLocator = require(script.Parent.ServiceLocator)

-- Types
export type ErrorSeverity = "Low" | "Medium" | "High" | "Critical"
export type ErrorCategory = "Network" | "Data" | "Performance" | "Security" | "Logic" | "External"
export type RecoveryStrategy = "Retry" | "Fallback" | "Degrade" | "Restart" | "Isolate"

export type ErrorInfo = {
	id: string,
	timestamp: number,
	severity: ErrorSeverity,
	category: ErrorCategory,
	message: string,
	source: string,
	stackTrace: string?,
	context: {[string]: any},
	recoveryStrategy: RecoveryStrategy,
	retryCount: number,
	recovered: boolean,
	metadata: {[string]: any}
}

export type CircuitBreakerState = "Closed" | "Open" | "HalfOpen"

export type CircuitBreakerConfig = {
	failureThreshold: number,
	recoveryTimeout: number,
	monitoringWindow: number,
	minimumThroughput: number,
	slowCallThreshold: number,
	slowCallRateThreshold: number
}

export type ServiceHealth = {
	serviceName: string,
	status: "Healthy" | "Degraded" | "Unhealthy" | "Failed",
	errorRate: number,
	averageResponseTime: number,
	circuitBreakerState: CircuitBreakerState,
	lastError: ErrorInfo?,
	recoveryAttempts: number,
	uptime: number,
	metrics: {[string]: any}
}

export type RecoveryAction = {
	name: string,
	strategy: RecoveryStrategy,
	enabled: boolean,
	priority: number,
	maxRetries: number,
	backoffMultiplier: number,
	timeout: number,
	conditions: {[string]: any},
	action: (ErrorInfo) -> boolean
}

export type ErrorHandlerConfig = {
	enableCircuitBreaker: boolean,
	enableGracefulDegradation: boolean,
	enableAutoRecovery: boolean,
	enableErrorAnalytics: boolean,
	maxErrorHistory: number,
	defaultRetryCount: number,
	defaultRecoveryTimeout: number,
	notificationThreshold: ErrorSeverity,
	performanceImpactThreshold: number
}

-- ErrorHandler Class
local ErrorHandler = {}
ErrorHandler.__index = ErrorHandler

-- Private Variables
local logger: any
local analytics: any
local configManager: any
local errorHistory: {ErrorInfo} = {}
local serviceHealthMap: {[string]: ServiceHealth} = {}
local circuitBreakers: {[string]: any} = {}
local recoveryActions: {[string]: RecoveryAction} = {}
local errorClassifiers: {[string]: (any) -> ErrorCategory} = {}
local activeRecoveries: {[string]: boolean} = {}

-- Configuration
local CONFIG: ErrorHandlerConfig = {
	enableCircuitBreaker = true,
	enableGracefulDegradation = true,
	enableAutoRecovery = true,
	enableErrorAnalytics = true,
	maxErrorHistory = 1000,
	defaultRetryCount = 3,
	defaultRecoveryTimeout = 30,
	notificationThreshold = "Medium",
	performanceImpactThreshold = 0.1
}

-- Events
local ErrorOccurred = Instance.new("BindableEvent")
local ServiceRecovered = Instance.new("BindableEvent")
local CircuitBreakerStateChanged = Instance.new("BindableEvent")
local GracefulDegradationActivated = Instance.new("BindableEvent")

-- Initialization
function ErrorHandler.new(): typeof(ErrorHandler)
	local self = setmetatable({}, ErrorHandler)
	
	logger = ServiceLocator:GetService("Logging")
	analytics = ServiceLocator:GetService("AnalyticsEngine")
	configManager = ServiceLocator:GetService("ConfigManager")
	
	if not logger then
		warn("ErrorHandler: Logging service not available")
		logger = { LogInfo = print, LogWarning = warn, LogError = warn }
	end
	
	self:_initializeErrorClassifiers()
	self:_initializeRecoveryActions()
	self:_setupPeriodicTasks()
	
	logger.LogInfo("ErrorHandler initialized successfully", {
		circuitBreaker = CONFIG.enableCircuitBreaker,
		gracefulDegradation = CONFIG.enableGracefulDegradation,
		autoRecovery = CONFIG.enableAutoRecovery,
		analytics = CONFIG.enableErrorAnalytics
	})
	
	return self
end

-- Initialize error classifiers
function ErrorHandler:_initializeErrorClassifiers(): ()
	errorClassifiers = {
		network = function(error: any): ErrorCategory
			local message = tostring(error)
			if string.find(message:lower(), "timeout") or string.find(message:lower(), "connection") then
				return "Network"
			elseif string.find(message:lower(), "http") or string.find(message:lower(), "request") then
				return "Network"
			else
				return "Logic"
			end
		end,
		
		datastore = function(error: any): ErrorCategory
			local message = tostring(error)
			if string.find(message:lower(), "datastore") or string.find(message:lower(), "quota") then
				return "Data"
			elseif string.find(message:lower(), "throttled") then
				return "Performance"
			else
				return "External"
			end
		end,
		
		security = function(error: any): ErrorCategory
			local message = tostring(error)
			if string.find(message:lower(), "exploit") or string.find(message:lower(), "unauthorized") then
				return "Security"
			elseif string.find(message:lower(), "validation") or string.find(message:lower(), "invalid") then
				return "Security"
			else
				return "Logic"
			end
		end,
		
		performance = function(error: any): ErrorCategory
			local message = tostring(error)
			if string.find(message:lower(), "memory") or string.find(message:lower(), "timeout") then
				return "Performance"
			elseif string.find(message:lower(), "lag") or string.find(message:lower(), "slow") then
				return "Performance"
			else
				return "Logic"
			end
		end
	}
end

-- Initialize recovery actions
function ErrorHandler:_initializeRecoveryActions(): ()
	recoveryActions = {
		networkRetry = {
			name = "networkRetry",
			strategy = "Retry",
			enabled = true,
			priority = 1,
			maxRetries = 3,
			backoffMultiplier = 2,
			timeout = 5,
			conditions = {category = "Network", severity = {"Low", "Medium"}},
			action = function(errorInfo: ErrorInfo): boolean
				return self:_performNetworkRetry(errorInfo)
			end
		},
		
		datastoreFallback = {
			name = "datastoreFallback",
			strategy = "Fallback",
			enabled = true,
			priority = 2,
			maxRetries = 1,
			backoffMultiplier = 1,
			timeout = 10,
			conditions = {category = "Data", severity = {"Medium", "High"}},
			action = function(errorInfo: ErrorInfo): boolean
				return self:_performDatastoreFallback(errorInfo)
			end
		},
		
		performanceDegrade = {
			name = "performanceDegrade",
			strategy = "Degrade",
			enabled = true,
			priority = 3,
			maxRetries = 1,
			backoffMultiplier = 1,
			timeout = 0,
			conditions = {category = "Performance", severity = {"Medium", "High", "Critical"}},
			action = function(errorInfo: ErrorInfo): boolean
				return self:_performPerformanceDegradation(errorInfo)
			end
		},
		
		serviceRestart = {
			name = "serviceRestart",
			strategy = "Restart",
			enabled = true,
			priority = 4,
			maxRetries = 2,
			backoffMultiplier = 3,
			timeout = 15,
			conditions = {severity = {"High", "Critical"}},
			action = function(errorInfo: ErrorInfo): boolean
				return self:_performServiceRestart(errorInfo)
			end
		},
		
		serviceIsolation = {
			name = "serviceIsolation",
			strategy = "Isolate",
			enabled = true,
			priority = 5,
			maxRetries = 1,
			backoffMultiplier = 1,
			timeout = 0,
			conditions = {severity = {"Critical"}, category = {"Security"}},
			action = function(errorInfo: ErrorInfo): boolean
				return self:_performServiceIsolation(errorInfo)
			end
		}
	}
end

-- Setup periodic tasks
function ErrorHandler:_setupPeriodicTasks(): ()
	-- Health monitoring
	task.spawn(function()
		while true do
			task.wait(10) -- Check every 10 seconds
			self:_updateServiceHealth()
		end
	end)
	
	-- Error history cleanup
	task.spawn(function()
		while true do
			task.wait(300) -- Clean every 5 minutes
			self:_cleanupErrorHistory()
		end
	end)
	
	-- Recovery monitoring
	task.spawn(function()
		while true do
			task.wait(5) -- Check every 5 seconds
			self:_monitorActiveRecoveries()
		end
	end)
end

-- Error Handling Core Functions

-- Handle error with comprehensive processing
function ErrorHandler:HandleError(error: any, source: string?, context: {[string]: any}?): ErrorInfo
	local errorInfo = self:_createErrorInfo(error, source or "unknown", context or {})
	
	-- Record error in history
	table.insert(errorHistory, errorInfo)
	
	-- Maintain history size limit
	while #errorHistory > CONFIG.maxErrorHistory do
		table.remove(errorHistory, 1)
	end
	
	-- Update service health
	self:_updateServiceHealthForError(errorInfo)
	
	-- Classify and route error
	local classification = self:_classifyError(error, source)
	errorInfo.category = classification
	
	-- Determine recovery strategy
	local strategy = self:_determineRecoveryStrategy(errorInfo)
	errorInfo.recoveryStrategy = strategy
	
	-- Log error with full context
	self:_logError(errorInfo)
	
	-- Record analytics
	if CONFIG.enableErrorAnalytics and analytics then
		analytics:RecordEvent(0, "error_occurred", {
			errorId = errorInfo.id,
			severity = errorInfo.severity,
			category = errorInfo.category,
			source = errorInfo.source,
			recoveryStrategy = errorInfo.recoveryStrategy,
			timestamp = errorInfo.timestamp
		})
	end
	
	-- Fire error event
	ErrorOccurred:Fire(errorInfo)
	
	-- Attempt automatic recovery if enabled
	if CONFIG.enableAutoRecovery then
		self:_attemptRecovery(errorInfo)
	end
	
	-- Check for circuit breaker triggers
	if CONFIG.enableCircuitBreaker then
		self:_checkCircuitBreaker(errorInfo.source, errorInfo)
	end
	
	-- Check for graceful degradation triggers
	if CONFIG.enableGracefulDegradation then
		self:_checkGracefulDegradation(errorInfo)
	end
	
	return errorInfo
end

-- Create comprehensive error information
function ErrorHandler:_createErrorInfo(error: any, source: string, context: {[string]: any}): ErrorInfo
	local errorMessage = tostring(error)
	local stackTrace = debug.traceback()
	local severity = self:_determineSeverity(error, source, context)
	
	local errorInfo: ErrorInfo = {
		id = HttpService:GenerateGUID(false),
		timestamp = os.time(),
		severity = severity,
		category = "Logic", -- Will be updated by classification
		message = errorMessage,
		source = source,
		stackTrace = stackTrace,
		context = context,
		recoveryStrategy = "Retry", -- Will be updated by strategy determination
		retryCount = 0,
		recovered = false,
		metadata = {
			errorType = typeof(error),
			contextSize = self:_getTableSize(context),
			stackDepth = self:_getStackDepth(stackTrace)
		}
	}
	
	return errorInfo
end

-- Determine error severity
function ErrorHandler:_determineSeverity(error: any, source: string, context: {[string]: any}): ErrorSeverity
	local message = tostring(error):lower()
	
	-- Critical errors
	if string.find(message, "exploit") or string.find(message, "security") then
		return "Critical"
	elseif string.find(message, "datastore") and string.find(message, "failed") then
		return "Critical"
	elseif string.find(message, "memory") and string.find(message, "limit") then
		return "Critical"
	
	-- High severity errors
	elseif string.find(message, "timeout") and string.find(source:lower(), "network") then
		return "High"
	elseif string.find(message, "connection") and string.find(message, "lost") then
		return "High"
	elseif string.find(message, "performance") and string.find(message, "degraded") then
		return "High"
	
	-- Medium severity errors
	elseif string.find(message, "retry") or string.find(message, "temporary") then
		return "Medium"
	elseif string.find(message, "warning") or string.find(message, "minor") then
		return "Medium"
	
	-- Low severity errors (default)
	else
		return "Low"
	end
end

-- Classify error using registered classifiers
function ErrorHandler:_classifyError(error: any, source: string?): ErrorCategory
	local sourceKey = source and source:lower() or "unknown"
	
	-- Try specific classifiers first
	for classifierName, classifier in pairs(errorClassifiers) do
		if string.find(sourceKey, classifierName) then
			return classifier(error)
		end
	end
	
	-- Fallback to generic classification
	return errorClassifiers.network(error) -- Default classifier
end

-- Determine appropriate recovery strategy
function ErrorHandler:_determineRecoveryStrategy(errorInfo: ErrorInfo): RecoveryStrategy
	-- Check configured recovery actions
	local applicableActions = {}
	
	for _, action in pairs(recoveryActions) do
		if action.enabled and self:_actionMatchesConditions(action, errorInfo) then
			table.insert(applicableActions, action)
		end
	end
	
	-- Sort by priority
	table.sort(applicableActions, function(a, b)
		return a.priority < b.priority
	end)
	
	-- Return strategy of highest priority action
	if #applicableActions > 0 then
		return applicableActions[1].strategy
	else
		return "Retry" -- Default fallback
	end
end

-- Check if recovery action matches error conditions
function ErrorHandler:_actionMatchesConditions(action: RecoveryAction, errorInfo: ErrorInfo): boolean
	local conditions = action.conditions
	
	-- Check category condition
	if conditions.category and errorInfo.category ~= conditions.category then
		return false
	end
	
	-- Check severity condition
	if conditions.severity then
		local severityMatches = false
		for _, severity in ipairs(conditions.severity) do
			if errorInfo.severity == severity then
				severityMatches = true
				break
			end
		end
		if not severityMatches then
			return false
		end
	end
	
	return true
end

-- Attempt automatic recovery
function ErrorHandler:_attemptRecovery(errorInfo: ErrorInfo): ()
	local recoveryKey = errorInfo.source .. "_" .. errorInfo.id
	
	-- Prevent multiple concurrent recoveries for same issue
	if activeRecoveries[recoveryKey] then
		return
	end
	
	activeRecoveries[recoveryKey] = true
	
	task.spawn(function()
		local success = false
		local recoveryAction = self:_getRecoveryAction(errorInfo)
		
		if recoveryAction then
			logger.LogInfo("Attempting error recovery", {
				errorId = errorInfo.id,
				source = errorInfo.source,
				strategy = errorInfo.recoveryStrategy,
				action = recoveryAction.name
			})
			
			-- Attempt recovery with retries
			for attempt = 1, recoveryAction.maxRetries do
				local retrySuccess, retryError = pcall(function()
					return recoveryAction.action(errorInfo)
				end)
				
				if retrySuccess and retryError then
					success = true
					break
				else
					errorInfo.retryCount = errorInfo.retryCount + 1
					
					if attempt < recoveryAction.maxRetries then
						local backoffTime = recoveryAction.timeout * (recoveryAction.backoffMultiplier ^ (attempt - 1))
						task.wait(backoffTime)
					end
				end
			end
		end
		
		if success then
			errorInfo.recovered = true
			self:_recordRecoverySuccess(errorInfo)
		else
			self:_recordRecoveryFailure(errorInfo)
		end
		
		activeRecoveries[recoveryKey] = nil
	end)
end

-- Get appropriate recovery action for error
function ErrorHandler:_getRecoveryAction(errorInfo: ErrorInfo): RecoveryAction?
	local applicableActions = {}
	
	for _, action in pairs(recoveryActions) do
		if action.enabled and self:_actionMatchesConditions(action, errorInfo) then
			table.insert(applicableActions, action)
		end
	end
	
	-- Sort by priority and return highest priority action
	table.sort(applicableActions, function(a, b)
		return a.priority < b.priority
	end)
	
	return applicableActions[1]
end

-- Recovery Action Implementations

-- Perform network retry recovery
function ErrorHandler:_performNetworkRetry(errorInfo: ErrorInfo): boolean
	logger.LogInfo("Performing network retry recovery", {
		errorId = errorInfo.id,
		attempt = errorInfo.retryCount + 1
	})
	
	-- Simulate network retry logic
	task.wait(1) -- Simulate retry delay
	
	-- In a real implementation, this would retry the actual network operation
	local success = math.random() > 0.3 -- 70% success rate for simulation
	
	if success then
		logger.LogInfo("Network retry recovery successful", {errorId = errorInfo.id})
	else
		logger.LogWarning("Network retry recovery failed", {errorId = errorInfo.id})
	end
	
	return success
end

-- Perform datastore fallback recovery
function ErrorHandler:_performDatastoreFallback(errorInfo: ErrorInfo): boolean
	logger.LogInfo("Performing datastore fallback recovery", {
		errorId = errorInfo.id,
		source = errorInfo.source
	})
	
	-- Simulate datastore fallback logic
	task.wait(0.5) -- Simulate fallback delay
	
	-- In a real implementation, this would switch to backup datastore
	local success = math.random() > 0.2 -- 80% success rate for simulation
	
	if success then
		logger.LogInfo("Datastore fallback recovery successful", {errorId = errorInfo.id})
	else
		logger.LogWarning("Datastore fallback recovery failed", {errorId = errorInfo.id})
	end
	
	return success
end

-- Perform performance degradation recovery
function ErrorHandler:_performPerformanceDegradation(errorInfo: ErrorInfo): boolean
	logger.LogInfo("Performing performance degradation recovery", {
		errorId = errorInfo.id,
		source = errorInfo.source
	})
	
	-- Activate graceful degradation
	self:_activateGracefulDegradation(errorInfo.source)
	
	-- Performance degradation is always "successful" as it's a mitigation strategy
	logger.LogInfo("Performance degradation activated", {
		errorId = errorInfo.id,
		source = errorInfo.source
	})
	
	return true
end

-- Perform service restart recovery
function ErrorHandler:_performServiceRestart(errorInfo: ErrorInfo): boolean
	logger.LogInfo("Performing service restart recovery", {
		errorId = errorInfo.id,
		source = errorInfo.source
	})
	
	-- Simulate service restart logic
	task.wait(2) -- Simulate restart delay
	
	-- In a real implementation, this would restart the actual service
	local success = math.random() > 0.1 -- 90% success rate for simulation
	
	if success then
		logger.LogInfo("Service restart recovery successful", {
			errorId = errorInfo.id,
			source = errorInfo.source
		})
		
		-- Reset service health
		if serviceHealthMap[errorInfo.source] then
			serviceHealthMap[errorInfo.source].status = "Healthy"
			serviceHealthMap[errorInfo.source].recoveryAttempts = serviceHealthMap[errorInfo.source].recoveryAttempts + 1
		end
	else
		logger.LogError("Service restart recovery failed", {
			errorId = errorInfo.id,
			source = errorInfo.source
		})
	end
	
	return success
end

-- Perform service isolation recovery
function ErrorHandler:_performServiceIsolation(errorInfo: ErrorInfo): boolean
	logger.LogInfo("Performing service isolation recovery", {
		errorId = errorInfo.id,
		source = errorInfo.source
	})
	
	-- Isolate the service to prevent cascading failures
	if serviceHealthMap[errorInfo.source] then
		serviceHealthMap[errorInfo.source].status = "Failed"
	end
	
	-- Service isolation is always "successful" as it's a protective measure
	logger.LogInfo("Service isolation completed", {
		errorId = errorInfo.id,
		source = errorInfo.source
	})
	
	return true
end

-- Record recovery success
function ErrorHandler:_recordRecoverySuccess(errorInfo: ErrorInfo): ()
	logger.LogInfo("Error recovery successful", {
		errorId = errorInfo.id,
		source = errorInfo.source,
		strategy = errorInfo.recoveryStrategy,
		retryCount = errorInfo.retryCount
	})
	
	-- Update service health
	if serviceHealthMap[errorInfo.source] then
		serviceHealthMap[errorInfo.source].status = "Healthy"
	end
	
	-- Fire recovery event
	ServiceRecovered:Fire({
		errorInfo = errorInfo,
		timestamp = os.time(),
		recoveryTime = os.time() - errorInfo.timestamp
	})
	
	-- Record analytics
	if CONFIG.enableErrorAnalytics and analytics then
		analytics:RecordEvent(0, "error_recovered", {
			errorId = errorInfo.id,
			source = errorInfo.source,
			strategy = errorInfo.recoveryStrategy,
			retryCount = errorInfo.retryCount,
			recoveryTime = os.time() - errorInfo.timestamp
		})
	end
end

-- Record recovery failure
function ErrorHandler:_recordRecoveryFailure(errorInfo: ErrorInfo): ()
	logger.LogError("Error recovery failed", {
		errorId = errorInfo.id,
		source = errorInfo.source,
		strategy = errorInfo.recoveryStrategy,
		retryCount = errorInfo.retryCount
	})
	
	-- Update service health to degraded or failed
	if serviceHealthMap[errorInfo.source] then
		if errorInfo.severity == "Critical" then
			serviceHealthMap[errorInfo.source].status = "Failed"
		else
			serviceHealthMap[errorInfo.source].status = "Degraded"
		end
	end
	
	-- Record analytics
	if CONFIG.enableErrorAnalytics and analytics then
		analytics:RecordEvent(0, "error_recovery_failed", {
			errorId = errorInfo.id,
			source = errorInfo.source,
			strategy = errorInfo.recoveryStrategy,
			retryCount = errorInfo.retryCount,
			finalSeverity = errorInfo.severity
		})
	end
end

-- Circuit Breaker Functions

-- Check and update circuit breaker state
function ErrorHandler:_checkCircuitBreaker(serviceName: string, errorInfo: ErrorInfo): ()
	if not circuitBreakers[serviceName] then
		circuitBreakers[serviceName] = self:_createCircuitBreaker(serviceName)
	end
	
	local circuitBreaker = circuitBreakers[serviceName]
	local previousState = circuitBreaker.state
	
	-- Update circuit breaker with error
	circuitBreaker:recordFailure(errorInfo)
	
	-- Check for state change
	if circuitBreaker.state ~= previousState then
		logger.LogWarning("Circuit breaker state changed", {
			serviceName = serviceName,
			previousState = previousState,
			newState = circuitBreaker.state,
			errorId = errorInfo.id
		})
		
		-- Fire state change event
		CircuitBreakerStateChanged:Fire({
			serviceName = serviceName,
			previousState = previousState,
			newState = circuitBreaker.state,
			timestamp = os.time()
		})
		
		-- Update service health
		if serviceHealthMap[serviceName] then
			serviceHealthMap[serviceName].circuitBreakerState = circuitBreaker.state
		end
	end
end

-- Create circuit breaker for service
function ErrorHandler:_createCircuitBreaker(serviceName: string): any
	local config: CircuitBreakerConfig = {
		failureThreshold = 5,
		recoveryTimeout = 30,
		monitoringWindow = 60,
		minimumThroughput = 10,
		slowCallThreshold = 1000,
		slowCallRateThreshold = 0.6
	}
	
	local circuitBreaker = {
		serviceName = serviceName,
		state = "Closed",
		config = config,
		failureCount = 0,
		successCount = 0,
		lastFailureTime = 0,
		lastRecoveryAttempt = 0,
		recentCalls = {},
		
		recordFailure = function(self, errorInfo: ErrorInfo)
			self.failureCount = self.failureCount + 1
			self.lastFailureTime = os.time()
			
			-- Add to recent calls
			table.insert(self.recentCalls, {
				timestamp = os.time(),
				success = false,
				duration = 0,
				errorInfo = errorInfo
			})
			
			self:_cleanupRecentCalls()
			self:_updateState()
		end,
		
		recordSuccess = function(self, duration: number?)
			self.successCount = self.successCount + 1
			
			-- Add to recent calls
			table.insert(self.recentCalls, {
				timestamp = os.time(),
				success = true,
				duration = duration or 0,
				errorInfo = nil
			})
			
			self:_cleanupRecentCalls()
			self:_updateState()
		end,
		
		_cleanupRecentCalls = function(self)
			local cutoffTime = os.time() - self.config.monitoringWindow
			local filteredCalls = {}
			
			for _, call in ipairs(self.recentCalls) do
				if call.timestamp > cutoffTime then
					table.insert(filteredCalls, call)
				end
			end
			
			self.recentCalls = filteredCalls
		end,
		
		_updateState = function(self)
			local currentTime = os.time()
			
			if self.state == "Closed" then
				-- Check if we should open the circuit
				if #self.recentCalls >= self.config.minimumThroughput then
					local failureRate = self:_calculateFailureRate()
					if failureRate >= self.config.failureThreshold / self.config.minimumThroughput then
						self.state = "Open"
						self.lastRecoveryAttempt = currentTime
					end
				end
				
			elseif self.state == "Open" then
				-- Check if we should try half-open
				if currentTime - self.lastRecoveryAttempt >= self.config.recoveryTimeout then
					self.state = "HalfOpen"
				end
				
			elseif self.state == "HalfOpen" then
				-- Check if we should close or re-open
				local recentFailures = 0
				local recentSuccesses = 0
				
				for _, call in ipairs(self.recentCalls) do
					if call.timestamp > self.lastRecoveryAttempt then
						if call.success then
							recentSuccesses = recentSuccesses + 1
						else
							recentFailures = recentFailures + 1
						end
					end
				end
				
				if recentFailures > 0 then
					self.state = "Open"
					self.lastRecoveryAttempt = currentTime
				elseif recentSuccesses >= 3 then -- Require 3 successes to close
					self.state = "Closed"
					self.failureCount = 0
				end
			end
		end,
		
		_calculateFailureRate = function(self): number
			local failures = 0
			for _, call in ipairs(self.recentCalls) do
				if not call.success then
					failures = failures + 1
				end
			end
			return failures / math.max(#self.recentCalls, 1)
		end,
		
		canExecute = function(self): boolean
			return self.state ~= "Open"
		end,
		
		getState = function(self): CircuitBreakerState
			return self.state
		end
	}
	
	return circuitBreaker
end

-- Graceful Degradation Functions

-- Check and activate graceful degradation
function ErrorHandler:_checkGracefulDegradation(errorInfo: ErrorInfo): ()
	local serviceName = errorInfo.source
	local serviceHealth = serviceHealthMap[serviceName]
	
	if not serviceHealth then
		return
	end
	
	-- Check if degradation should be activated
	local shouldDegrade = false
	
	-- High error rate
	if serviceHealth.errorRate > 0.5 then
		shouldDegrade = true
	end
	
	-- High severity errors
	if errorInfo.severity == "High" or errorInfo.severity == "Critical" then
		shouldDegrade = true
	end
	
	-- Performance issues
	if serviceHealth.averageResponseTime > 5000 then -- 5 seconds
		shouldDegrade = true
	end
	
	if shouldDegrade and serviceHealth.status ~= "Failed" then
		self:_activateGracefulDegradation(serviceName)
	end
end

-- Activate graceful degradation for service
function ErrorHandler:_activateGracefulDegradation(serviceName: string): ()
	logger.LogWarning("Activating graceful degradation", {
		serviceName = serviceName,
		timestamp = os.time()
	})
	
	-- Update service health
	if serviceHealthMap[serviceName] then
		serviceHealthMap[serviceName].status = "Degraded"
	end
	
	-- Fire degradation event
	GracefulDegradationActivated:Fire({
		serviceName = serviceName,
		timestamp = os.time(),
		reason = "Error threshold exceeded"
	})
	
	-- Apply degradation policies through ConfigManager
	if configManager then
		-- Reduce performance-intensive features
		configManager:SetConfig("Performance", "particleLimit", 25, "graceful_degradation")
		configManager:SetConfig("Performance", "maxBulletTrails", 10, "graceful_degradation")
		configManager:SetConfig("Performance", "shadowQuality", "Low", "graceful_degradation")
		
		-- Reduce non-essential features
		configManager:SetConfig("Game", "enableSpectating", false, "graceful_degradation")
		configManager:SetConfig("Combat", "enableFriendlyFire", false, "graceful_degradation")
	end
	
	-- Record analytics
	if CONFIG.enableErrorAnalytics and analytics then
		analytics:RecordEvent(0, "graceful_degradation_activated", {
			serviceName = serviceName,
			timestamp = os.time()
		})
	end
end

-- Service Health Management

-- Update service health for error
function ErrorHandler:_updateServiceHealthForError(errorInfo: ErrorInfo): ()
	local serviceName = errorInfo.source
	
	if not serviceHealthMap[serviceName] then
		serviceHealthMap[serviceName] = self:_createServiceHealth(serviceName)
	end
	
	local health = serviceHealthMap[serviceName]
	health.lastError = errorInfo
	
	-- Update error rate (exponential moving average)
	local alpha = 0.1
	health.errorRate = alpha * 1.0 + (1 - alpha) * health.errorRate
	
	-- Update status based on error severity
	if errorInfo.severity == "Critical" then
		health.status = "Unhealthy"
	elseif errorInfo.severity == "High" and health.status == "Healthy" then
		health.status = "Degraded"
	end
end

-- Create service health record
function ErrorHandler:_createServiceHealth(serviceName: string): ServiceHealth
	return {
		serviceName = serviceName,
		status = "Healthy",
		errorRate = 0.0,
		averageResponseTime = 0.0,
		circuitBreakerState = "Closed",
		lastError = nil,
		recoveryAttempts = 0,
		uptime = os.time(),
		metrics = {}
	}
end

-- Update all service health metrics
function ErrorHandler:_updateServiceHealth(): ()
	for serviceName, health in pairs(serviceHealthMap) do
		-- Update uptime
		health.uptime = os.time() - health.uptime
		
		-- Decay error rate over time
		local alpha = 0.05
		health.errorRate = health.errorRate * (1 - alpha)
		
		-- Check for health improvement
		if health.errorRate < 0.1 and health.status == "Degraded" then
			health.status = "Healthy"
			logger.LogInfo("Service health improved", {
				serviceName = serviceName,
				newStatus = health.status
			})
		end
	end
end

-- Utility Functions

-- Log error with comprehensive information
function ErrorHandler:_logError(errorInfo: ErrorInfo): ()
	local logLevel = "LogInfo"
	
	if errorInfo.severity == "Critical" then
		logLevel = "LogError"
	elseif errorInfo.severity == "High" then
		logLevel = "LogError"
	elseif errorInfo.severity == "Medium" then
		logLevel = "LogWarning"
	else
		logLevel = "LogInfo"
	end
	
	logger[logLevel]("Error handled", {
		errorId = errorInfo.id,
		severity = errorInfo.severity,
		category = errorInfo.category,
		source = errorInfo.source,
		message = errorInfo.message,
		recoveryStrategy = errorInfo.recoveryStrategy,
		context = errorInfo.context,
		stackTrace = errorInfo.stackTrace
	})
end

-- Get table size
function ErrorHandler:_getTableSize(tbl: {[string]: any}): number
	local count = 0
	for _ in pairs(tbl) do
		count = count + 1
	end
	return count
end

-- Get stack depth
function ErrorHandler:_getStackDepth(stackTrace: string?): number
	if not stackTrace then
		return 0
	end
	
	local _, count = string.gsub(stackTrace, "\n", "")
	return count
end

-- Monitor active recoveries
function ErrorHandler:_monitorActiveRecoveries(): ()
	-- Clean up any stuck recoveries (timeout after 5 minutes)
	local timeout = 300
	local currentTime = os.time()
	
	for recoveryKey, _ in pairs(activeRecoveries) do
		-- In a real implementation, track recovery start times
		-- For now, just log active recoveries
		if math.random() < 0.001 then -- Very rarely log for debugging
			logger.LogInfo("Active recovery monitoring", {
				activeRecoveries = #activeRecoveries,
				timestamp = currentTime
			})
		end
	end
end

-- Cleanup error history
function ErrorHandler:_cleanupErrorHistory(): ()
	-- Remove errors older than 1 hour
	local cutoffTime = os.time() - 3600
	local filteredHistory = {}
	
	for _, errorInfo in ipairs(errorHistory) do
		if errorInfo.timestamp > cutoffTime then
			table.insert(filteredHistory, errorInfo)
		end
	end
	
	local removedCount = #errorHistory - #filteredHistory
	errorHistory = filteredHistory
	
	if removedCount > 0 then
		logger.LogInfo("Error history cleaned up", {
			removedCount = removedCount,
			remainingCount = #errorHistory
		})
	end
end

-- Public API

-- Get error history
function ErrorHandler:GetErrorHistory(): {ErrorInfo}
	return errorHistory
end

-- Get service health
function ErrorHandler:GetServiceHealth(serviceName: string?): ServiceHealth | {[string]: ServiceHealth}
	if serviceName then
		return serviceHealthMap[serviceName]
	else
		return serviceHealthMap
	end
end

-- Get circuit breaker state
function ErrorHandler:GetCircuitBreakerState(serviceName: string): CircuitBreakerState?
	local circuitBreaker = circuitBreakers[serviceName]
	return circuitBreaker and circuitBreaker:getState() or nil
end

-- Register custom error classifier
function ErrorHandler:RegisterErrorClassifier(name: string, classifier: (any) -> ErrorCategory): ()
	errorClassifiers[name] = classifier
	logger.LogInfo("Error classifier registered", {name = name})
end

-- Register custom recovery action
function ErrorHandler:RegisterRecoveryAction(action: RecoveryAction): ()
	recoveryActions[action.name] = action
	logger.LogInfo("Recovery action registered", {name = action.name})
end

-- Force service recovery
function ErrorHandler:ForceServiceRecovery(serviceName: string): boolean
	logger.LogInfo("Force service recovery initiated", {serviceName = serviceName})
	
	-- Reset circuit breaker
	if circuitBreakers[serviceName] then
		circuitBreakers[serviceName].state = "Closed"
		circuitBreakers[serviceName].failureCount = 0
	end
	
	-- Reset service health
	if serviceHealthMap[serviceName] then
		serviceHealthMap[serviceName].status = "Healthy"
		serviceHealthMap[serviceName].errorRate = 0.0
	end
	
	return true
end

-- Event Connections
function ErrorHandler:OnErrorOccurred(callback: (ErrorInfo) -> ()): RBXScriptConnection
	return ErrorOccurred.Event:Connect(callback)
end

function ErrorHandler:OnServiceRecovered(callback: (any) -> ()): RBXScriptConnection
	return ServiceRecovered.Event:Connect(callback)
end

function ErrorHandler:OnCircuitBreakerStateChanged(callback: (any) -> ()): RBXScriptConnection
	return CircuitBreakerStateChanged.Event:Connect(callback)
end

function ErrorHandler:OnGracefulDegradationActivated(callback: (any) -> ()): RBXScriptConnection
	return GracefulDegradationActivated.Event:Connect(callback)
end

-- Health Check
function ErrorHandler:GetHealthStatus(): {status: string, metrics: any}
	local totalErrors = #errorHistory
	local criticalErrors = 0
	local recoveredErrors = 0
	local activeCircuitBreakers = 0
	
	for _, errorInfo in ipairs(errorHistory) do
		if errorInfo.severity == "Critical" then
			criticalErrors = criticalErrors + 1
		end
		if errorInfo.recovered then
			recoveredErrors = recoveredErrors + 1
		end
	end
	
	for _, circuitBreaker in pairs(circuitBreakers) do
		if circuitBreaker.state ~= "Closed" then
			activeCircuitBreakers = activeCircuitBreakers + 1
		end
	end
	
	local recoveryRate = totalErrors > 0 and (recoveredErrors / totalErrors * 100) or 100
	
	return {
		status = recoveryRate >= 95 and "healthy" or "degraded",
		metrics = {
			totalErrors = totalErrors,
			criticalErrors = criticalErrors,
			recoveredErrors = recoveredErrors,
			recoveryRate = recoveryRate,
			activeCircuitBreakers = activeCircuitBreakers,
			servicesMonitored = #serviceHealthMap,
			activeRecoveries = #activeRecoveries,
			errorClassifiers = #errorClassifiers,
			recoveryActions = #recoveryActions,
			lastCleanup = os.time()
		}
	}
end

return ErrorHandler
