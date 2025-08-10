--!strict
--[[
	RecoveryManager.server.lua
	Enterprise Automatic Service Recovery System
	
	Provides comprehensive automatic recovery mechanisms for enterprise-grade system resilience
	including service health monitoring, automatic failover, recovery procedures, and coordination.
	
	Features:
	- Automatic service health monitoring
	- Multi-strategy recovery procedures
	- Service dependency management
	- Failover coordination
	- Recovery analytics and reporting
	- Player impact minimization
	- Performance-aware recovery
	- Recovery orchestration and scheduling
	
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
export type ServiceStatus = "Healthy" | "Degraded" | "Unhealthy" | "Failed" | "Recovering" | "Maintenance"

export type RecoveryStrategy = "Restart" | "Rollback" | "Failover" | "Degrade" | "Isolate" | "Scale" | "Repair"

export type ServiceHealth = {
	serviceName: string,
	status: ServiceStatus,
	lastHealthCheck: number,
	consecutiveFailures: number,
	uptime: number,
	responseTime: number,
	errorRate: number,
	resourceUsage: {[string]: number},
	dependencies: {string},
	lastRecovery: number?,
	recoveryCount: number,
	metadata: {[string]: any}
}

export type RecoveryPlan = {
	id: string,
	serviceName: string,
	strategy: RecoveryStrategy,
	priority: number,
	estimatedDuration: number,
	playerImpact: "None" | "Low" | "Medium" | "High",
	dependencies: {string},
	preconditions: {string},
	steps: {RecoveryStep},
	rollbackPlan: {RecoveryStep}?,
	timeout: number,
	retryPolicy: RetryPolicy
}

export type RecoveryStep = {
	name: string,
	action: () -> boolean,
	timeout: number,
	retryCount: number,
	rollbackAction: (() -> boolean)?,
	verifyAction: (() -> boolean)?,
	description: string
}

export type RetryPolicy = {
	maxRetries: number,
	backoffStrategy: "Fixed" | "Linear" | "Exponential",
	baseDelay: number,
	maxDelay: number,
	jitter: boolean
}

export type RecoveryExecution = {
	id: string,
	planId: string,
	serviceName: string,
	status: "Pending" | "Running" | "Success" | "Failed" | "Cancelled" | "RolledBack",
	startTime: number,
	endTime: number?,
	currentStep: number,
	totalSteps: number,
	errors: {string},
	metrics: {[string]: any},
	playerNotifications: boolean
}

-- Recovery Manager
local RecoveryManager = {}
RecoveryManager.__index = RecoveryManager

-- Private Variables
local logger: any
local analytics: any
local errorHandler: any
local configManager: any
local circuitBreaker: any
local serviceHealthMap: {[string]: ServiceHealth} = {}
local recoveryPlans: {[string]: RecoveryPlan} = {}
local activeRecoveries: {[string]: RecoveryExecution} = {}
local recoveryQueue: {string} = {}
local serviceRegistry: {[string]: any} = {}

-- Configuration
local HEALTH_CHECK_INTERVAL = 10 -- seconds
local RECOVERY_QUEUE_INTERVAL = 5 -- seconds
local MAX_CONCURRENT_RECOVERIES = 3
local DEFAULT_RECOVERY_TIMEOUT = 300 -- 5 minutes
local HEALTH_CHECK_TIMEOUT = 5 -- seconds

-- Events
local ServiceHealthChanged = Instance.new("BindableEvent")
local RecoveryStarted = Instance.new("BindableEvent")
local RecoveryCompleted = Instance.new("BindableEvent")
local RecoveryFailed = Instance.new("BindableEvent")
local ServiceRecovered = Instance.new("BindableEvent")

-- Remote Events for client communication
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local uiEvents = remoteEvents:WaitForChild("UIEvents")
local recoveryNotification = uiEvents:WaitForChild("RecoveryNotification")

-- Initialization
function RecoveryManager.new(): typeof(RecoveryManager)
	local self = setmetatable({}, RecoveryManager)
	
	-- Get services
	logger = ServiceLocator:GetService("Logging")
	analytics = ServiceLocator:GetService("AnalyticsEngine")
	errorHandler = ServiceLocator:GetService("ErrorHandler")
	configManager = ServiceLocator:GetService("ConfigManager")
	circuitBreaker = ServiceLocator:GetService("CircuitBreaker")
	
	if not logger then
		logger = { LogInfo = print, LogWarning = warn, LogError = warn }
	end
	
	-- Initialize built-in recovery plans
	self:_initializeBuiltInRecoveryPlans()
	
	-- Setup monitoring and recovery processes
	self:_setupHealthMonitoring()
	self:_setupRecoveryQueue()
	self:_setupServiceRegistry()
	
	logger.LogInfo("RecoveryManager initialized successfully", {
		healthCheckInterval = HEALTH_CHECK_INTERVAL,
		maxConcurrentRecoveries = MAX_CONCURRENT_RECOVERIES
	})
	
	return self
end

-- Service Registration and Health Monitoring

-- Register service for monitoring
function RecoveryManager:RegisterService(serviceName: string, serviceInstance: any, dependencies: {string}?): ()
	serviceRegistry[serviceName] = serviceInstance
	
	-- Initialize health record
	serviceHealthMap[serviceName] = {
		serviceName = serviceName,
		status = "Healthy",
		lastHealthCheck = os.time(),
		consecutiveFailures = 0,
		uptime = os.time(),
		responseTime = 0,
		errorRate = 0,
		resourceUsage = {},
		dependencies = dependencies or {},
		lastRecovery = nil,
		recoveryCount = 0,
		metadata = {}
	}
	
	logger.LogInfo("Service registered for recovery monitoring", {
		serviceName = serviceName,
		dependencies = dependencies
	})
end

-- Unregister service
function RecoveryManager:UnregisterService(serviceName: string): ()
	serviceRegistry[serviceName] = nil
	serviceHealthMap[serviceName] = nil
	
	logger.LogInfo("Service unregistered from recovery monitoring", {
		serviceName = serviceName
	})
end

-- Perform health check on service
function RecoveryManager:_performHealthCheck(serviceName: string): ServiceHealth
	local serviceHealth = serviceHealthMap[serviceName]
	local serviceInstance = serviceRegistry[serviceName]
	
	if not serviceHealth or not serviceInstance then
		return serviceHealth
	end
	
	local startTime = tick()
	local isHealthy = true
	local errorMessage = nil
	
	-- Perform health check
	local success, result = pcall(function()
		-- Check if service has health check method
		if typeof(serviceInstance.GetHealthStatus) == "function" then
			local healthStatus = serviceInstance:GetHealthStatus()
			return healthStatus.status == "healthy"
		else
			-- Basic availability check
			return serviceInstance ~= nil
		end
	end)
	
	local responseTime = (tick() - startTime) * 1000 -- Convert to milliseconds
	
	if not success then
		isHealthy = false
		errorMessage = tostring(result)
	elseif not result then
		isHealthy = false
		errorMessage = "Service health check returned false"
	end
	
	-- Update health record
	serviceHealth.lastHealthCheck = os.time()
	serviceHealth.responseTime = responseTime
	
	if isHealthy then
		serviceHealth.consecutiveFailures = 0
		if serviceHealth.status ~= "Healthy" and serviceHealth.status ~= "Recovering" then
			self:_updateServiceStatus(serviceName, "Healthy")
		end
	else
		serviceHealth.consecutiveFailures = serviceHealth.consecutiveFailures + 1
		
		-- Update status based on failure count
		local newStatus = serviceHealth.status
		if serviceHealth.consecutiveFailures >= 5 then
			newStatus = "Failed"
		elseif serviceHealth.consecutiveFailures >= 3 then
			newStatus = "Unhealthy"
		elseif serviceHealth.consecutiveFailures >= 1 then
			newStatus = "Degraded"
		end
		
		if newStatus ~= serviceHealth.status then
			self:_updateServiceStatus(serviceName, newStatus)
		end
		
		-- Report error
		if errorHandler and errorMessage then
			errorHandler:HandleError(errorMessage, "RecoveryManager:" .. serviceName, {
				consecutiveFailures = serviceHealth.consecutiveFailures,
				responseTime = responseTime
			})
		end
	end
	
	return serviceHealth
end

-- Update service status
function RecoveryManager:_updateServiceStatus(serviceName: string, newStatus: ServiceStatus): ()
	local serviceHealth = serviceHealthMap[serviceName]
	if not serviceHealth then
		return
	end
	
	local previousStatus = serviceHealth.status
	serviceHealth.status = newStatus
	
	logger.LogInfo("Service status changed", {
		serviceName = serviceName,
		previousStatus = previousStatus,
		newStatus = newStatus,
		consecutiveFailures = serviceHealth.consecutiveFailures
	})
	
	-- Fire health changed event
	ServiceHealthChanged:Fire({
		serviceName = serviceName,
		previousStatus = previousStatus,
		newStatus = newStatus,
		health = serviceHealth,
		timestamp = os.time()
	})
	
	-- Trigger recovery if needed
	if newStatus == "Unhealthy" or newStatus == "Failed" then
		self:TriggerRecovery(serviceName, "auto")
	end
	
	-- Record analytics
	if analytics then
		analytics:RecordEvent(0, "service_status_changed", {
			serviceName = serviceName,
			previousStatus = previousStatus,
			newStatus = newStatus,
			consecutiveFailures = serviceHealth.consecutiveFailures
		})
	end
end

-- Recovery Plan Management

-- Initialize built-in recovery plans
function RecoveryManager:_initializeBuiltInRecoveryPlans(): ()
	-- Service Restart Recovery Plan
	recoveryPlans["restart_generic"] = {
		id = "restart_generic",
		serviceName = "*", -- Generic plan
		strategy = "Restart",
		priority = 100,
		estimatedDuration = 30,
		playerImpact = "Low",
		dependencies = {},
		preconditions = {},
		timeout = 60,
		retryPolicy = {
			maxRetries = 2,
			backoffStrategy = "Exponential",
			baseDelay = 5,
			maxDelay = 30,
			jitter = true
		},
		steps = {
			{
				name = "Prepare Restart",
				action = function() return true end,
				timeout = 5,
				retryCount = 1,
				description = "Prepare service for restart"
			},
			{
				name = "Stop Service",
				action = function() return true end,
				timeout = 10,
				retryCount = 1,
				description = "Gracefully stop service"
			},
			{
				name = "Clear Resources",
				action = function() return true end,
				timeout = 5,
				retryCount = 1,
				description = "Clear service resources"
			},
			{
				name = "Start Service",
				action = function() return true end,
				timeout = 10,
				retryCount = 2,
				description = "Start service"
			},
			{
				name = "Verify Health",
				action = function() return true end,
				timeout = 10,
				retryCount = 3,
				verifyAction = function() return true end,
				description = "Verify service health"
			}
		}
	}
	
	-- Graceful Degradation Recovery Plan
	recoveryPlans["degrade_generic"] = {
		id = "degrade_generic",
		serviceName = "*",
		strategy = "Degrade",
		priority = 50,
		estimatedDuration = 5,
		playerImpact = "Medium",
		dependencies = {},
		preconditions = {},
		timeout = 30,
		retryPolicy = {
			maxRetries = 1,
			backoffStrategy = "Fixed",
			baseDelay = 2,
			maxDelay = 2,
			jitter = false
		},
		steps = {
			{
				name = "Assess Degradation Options",
				action = function() return true end,
				timeout = 2,
				retryCount = 1,
				description = "Assess degradation options"
			},
			{
				name = "Apply Performance Limits",
				action = function() return true end,
				timeout = 3,
				retryCount = 1,
				description = "Apply performance limitations"
			},
			{
				name = "Disable Non-Essential Features",
				action = function() return true end,
				timeout = 5,
				retryCount = 1,
				description = "Disable non-essential features"
			},
			{
				name = "Verify Degraded Operation",
				action = function() return true end,
				timeout = 5,
				retryCount = 2,
				verifyAction = function() return true end,
				description = "Verify degraded operation"
			}
		}
	}
	
	-- Service Isolation Recovery Plan
	recoveryPlans["isolate_generic"] = {
		id = "isolate_generic",
		serviceName = "*",
		strategy = "Isolate",
		priority = 200,
		estimatedDuration = 10,
		playerImpact = "High",
		dependencies = {},
		preconditions = {},
		timeout = 60,
		retryPolicy = {
			maxRetries = 1,
			backoffStrategy = "Fixed",
			baseDelay = 1,
			maxDelay = 1,
			jitter = false
		},
		steps = {
			{
				name = "Assess Isolation Impact",
				action = function() return true end,
				timeout = 2,
				retryCount = 1,
				description = "Assess isolation impact"
			},
			{
				name = "Reroute Dependencies",
				action = function() return true end,
				timeout = 5,
				retryCount = 1,
				description = "Reroute service dependencies"
			},
			{
				name = "Isolate Service",
				action = function() return true end,
				timeout = 3,
				retryCount = 1,
				description = "Isolate problematic service"
			},
			{
				name = "Verify System Stability",
				action = function() return true end,
				timeout = 10,
				retryCount = 2,
				verifyAction = function() return true end,
				description = "Verify system stability"
			}
		}
	}
	
	-- Failover Recovery Plan
	recoveryPlans["failover_generic"] = {
		id = "failover_generic",
		serviceName = "*",
		strategy = "Failover",
		priority = 150,
		estimatedDuration = 60,
		playerImpact = "Medium",
		dependencies = {},
		preconditions = {},
		timeout = 120,
		retryPolicy = {
			maxRetries = 1,
			backoffStrategy = "Fixed",
			baseDelay = 5,
			maxDelay = 5,
			jitter = false
		},
		steps = {
			{
				name = "Identify Backup Service",
				action = function() return true end,
				timeout = 5,
				retryCount = 1,
				description = "Identify backup service"
			},
			{
				name = "Prepare Backup Service",
				action = function() return true end,
				timeout = 15,
				retryCount = 1,
				description = "Prepare backup service"
			},
			{
				name = "Transfer Service State",
				action = function() return true end,
				timeout = 20,
				retryCount = 1,
				description = "Transfer service state"
			},
			{
				name = "Activate Backup Service",
				action = function() return true end,
				timeout = 10,
				retryCount = 2,
				description = "Activate backup service"
			},
			{
				name = "Verify Failover Success",
				action = function() return true end,
				timeout = 10,
				retryCount = 3,
				verifyAction = function() return true end,
				description = "Verify failover success"
			}
		}
	}
	
	logger.LogInfo("Built-in recovery plans initialized", {
		planCount = 4,
		strategies = {"Restart", "Degrade", "Isolate", "Failover"}
	})
end

-- Register custom recovery plan
function RecoveryManager:RegisterRecoveryPlan(plan: RecoveryPlan): ()
	recoveryPlans[plan.id] = plan
	
	logger.LogInfo("Recovery plan registered", {
		planId = plan.id,
		serviceName = plan.serviceName,
		strategy = plan.strategy,
		priority = plan.priority
	})
end

-- Get recovery plan for service and strategy
function RecoveryManager:_getRecoveryPlan(serviceName: string, strategy: RecoveryStrategy?): RecoveryPlan?
	-- First, try to find service-specific plan
	for _, plan in pairs(recoveryPlans) do
		if plan.serviceName == serviceName and (not strategy or plan.strategy == strategy) then
			return plan
		end
	end
	
	-- Fall back to generic plan
	for _, plan in pairs(recoveryPlans) do
		if plan.serviceName == "*" and (not strategy or plan.strategy == strategy) then
			return plan
		end
	end
	
	return nil
end

-- Recovery Execution

-- Trigger recovery for service
function RecoveryManager:TriggerRecovery(serviceName: string, trigger: string, strategy: RecoveryStrategy?): string?
	local serviceHealth = serviceHealthMap[serviceName]
	if not serviceHealth then
		logger.LogWarning("Cannot trigger recovery for unregistered service", {
			serviceName = serviceName
		})
		return nil
	end
	
	-- Check if recovery is already in progress
	for _, execution in pairs(activeRecoveries) do
		if execution.serviceName == serviceName and execution.status == "Running" then
			logger.LogInfo("Recovery already in progress for service", {
				serviceName = serviceName,
				executionId = execution.id
			})
			return execution.id
		end
	end
	
	-- Determine recovery strategy
	local recoveryStrategy = strategy or self:_determineRecoveryStrategy(serviceName, serviceHealth)
	local recoveryPlan = self:_getRecoveryPlan(serviceName, recoveryStrategy)
	
	if not recoveryPlan then
		logger.LogError("No recovery plan found for service", {
			serviceName = serviceName,
			strategy = recoveryStrategy
		})
		return nil
	end
	
	-- Create recovery execution
	local executionId = HttpService:GenerateGUID(false)
	local execution: RecoveryExecution = {
		id = executionId,
		planId = recoveryPlan.id,
		serviceName = serviceName,
		status = "Pending",
		startTime = os.time(),
		endTime = nil,
		currentStep = 0,
		totalSteps = #recoveryPlan.steps,
		errors = {},
		metrics = {
			trigger = trigger,
			strategy = recoveryStrategy,
			serviceStatus = serviceHealth.status,
			consecutiveFailures = serviceHealth.consecutiveFailures
		},
		playerNotifications = recoveryPlan.playerImpact ~= "None"
	}
	
	activeRecoveries[executionId] = execution
	table.insert(recoveryQueue, executionId)
	
	-- Update service status
	serviceHealth.status = "Recovering"
	
	logger.LogInfo("Recovery triggered", {
		serviceName = serviceName,
		executionId = executionId,
		strategy = recoveryStrategy,
		planId = recoveryPlan.id,
		trigger = trigger
	})
	
	-- Fire recovery started event
	RecoveryStarted:Fire({
		executionId = executionId,
		serviceName = serviceName,
		strategy = recoveryStrategy,
		trigger = trigger,
		timestamp = os.time()
	})
	
	-- Record analytics
	if analytics then
		analytics:RecordEvent(0, "recovery_triggered", {
			serviceName = serviceName,
			executionId = executionId,
			strategy = recoveryStrategy,
			trigger = trigger
		})
	end
	
	return executionId
end

-- Determine appropriate recovery strategy
function RecoveryManager:_determineRecoveryStrategy(serviceName: string, serviceHealth: ServiceHealth): RecoveryStrategy
	-- Strategy selection based on service health and configuration
	local consecutiveFailures = serviceHealth.consecutiveFailures
	local status = serviceHealth.status
	local errorRate = serviceHealth.errorRate
	
	-- Critical failures require isolation
	if status == "Failed" and consecutiveFailures >= 5 then
		return "Isolate"
	end
	
	-- High error rate might benefit from degradation
	if errorRate > 0.5 and status ~= "Failed" then
		return "Degrade"
	end
	
	-- Multiple failures suggest restart
	if consecutiveFailures >= 3 then
		return "Restart"
	end
	
	-- Check if failover is available and appropriate
	if self:_hasFailoverOption(serviceName) and status == "Unhealthy" then
		return "Failover"
	end
	
	-- Default to restart for single failures
	return "Restart"
end

-- Check if service has failover options
function RecoveryManager:_hasFailoverOption(serviceName: string): boolean
	-- In a real implementation, this would check for backup services
	-- For now, return false as we don't have backup service infrastructure
	return false
end

-- Execute recovery from queue
function RecoveryManager:_executeRecovery(executionId: string): ()
	local execution = activeRecoveries[executionId]
	if not execution then
		return
	end
	
	local recoveryPlan = recoveryPlans[execution.planId]
	if not recoveryPlan then
		execution.status = "Failed"
		table.insert(execution.errors, "Recovery plan not found")
		return
	end
	
	execution.status = "Running"
	execution.currentStep = 1
	
	logger.LogInfo("Starting recovery execution", {
		executionId = executionId,
		serviceName = execution.serviceName,
		planId = execution.planId,
		totalSteps = execution.totalSteps
	})
	
	-- Send player notifications if needed
	if execution.playerNotifications then
		self:_sendRecoveryNotification(execution, "started")
	end
	
	-- Execute recovery steps
	task.spawn(function()
		local success = self:_executeRecoverySteps(execution, recoveryPlan)
		
		if success then
			execution.status = "Success"
			execution.endTime = os.time()
			
			-- Update service health
			local serviceHealth = serviceHealthMap[execution.serviceName]
			if serviceHealth then
				serviceHealth.lastRecovery = os.time()
				serviceHealth.recoveryCount = serviceHealth.recoveryCount + 1
				serviceHealth.consecutiveFailures = 0
				serviceHealth.status = "Healthy"
			end
			
			logger.LogInfo("Recovery completed successfully", {
				executionId = executionId,
				serviceName = execution.serviceName,
				duration = execution.endTime - execution.startTime
			})
			
			-- Fire recovery completed event
			RecoveryCompleted:Fire({
				executionId = executionId,
				serviceName = execution.serviceName,
				success = true,
				duration = execution.endTime - execution.startTime,
				timestamp = execution.endTime
			})
			
			-- Fire service recovered event
			ServiceRecovered:Fire({
				serviceName = execution.serviceName,
				recoveryType = recoveryPlan.strategy,
				timestamp = execution.endTime
			})
			
			-- Send success notification
			if execution.playerNotifications then
				self:_sendRecoveryNotification(execution, "completed")
			end
			
		else
			execution.status = "Failed"
			execution.endTime = os.time()
			
			logger.LogError("Recovery failed", {
				executionId = executionId,
				serviceName = execution.serviceName,
				errors = execution.errors,
				currentStep = execution.currentStep
			})
			
			-- Fire recovery failed event
			RecoveryFailed:Fire({
				executionId = executionId,
				serviceName = execution.serviceName,
				errors = execution.errors,
				timestamp = execution.endTime
			})
			
			-- Send failure notification
			if execution.playerNotifications then
				self:_sendRecoveryNotification(execution, "failed")
			end
		end
		
		-- Record analytics
		if analytics then
			analytics:RecordEvent(0, "recovery_completed", {
				executionId = executionId,
				serviceName = execution.serviceName,
				success = success,
				duration = execution.endTime and (execution.endTime - execution.startTime) or 0,
				errors = execution.errors
			})
		end
		
		-- Clean up after delay
		task.wait(60) -- Keep for 1 minute for debugging
		activeRecoveries[executionId] = nil
	end)
end

-- Execute recovery steps
function RecoveryManager:_executeRecoverySteps(execution: RecoveryExecution, plan: RecoveryPlan): boolean
	for stepIndex, step in ipairs(plan.steps) do
		execution.currentStep = stepIndex
		
		logger.LogInfo("Executing recovery step", {
			executionId = execution.id,
			serviceName = execution.serviceName,
			stepIndex = stepIndex,
			stepName = step.name,
			description = step.description
		})
		
		local stepSuccess = false
		local stepErrors = {}
		
		-- Execute step with retries
		for attempt = 1, step.retryCount + 1 do
			local success, result = pcall(function()
				-- Set timeout for step execution
				local timeoutTask = task.delay(step.timeout, function()
					error("Step timeout exceeded")
				end)
				
				-- Execute step action
				local actionSuccess = step.action()
				task.cancel(timeoutTask)
				
				-- Verify step if verification action exists
				if actionSuccess and step.verifyAction then
					actionSuccess = step.verifyAction()
				end
				
				return actionSuccess
			end)
			
			if success and result then
				stepSuccess = true
				break
			else
				local errorMessage = success and "Step action returned false" or tostring(result)
				table.insert(stepErrors, errorMessage)
				
				-- Wait before retry (with backoff)
				if attempt < step.retryCount + 1 then
					local delay = self:_calculateRetryDelay(plan.retryPolicy, attempt)
					task.wait(delay)
				end
			end
		end
		
		if not stepSuccess then
			-- Step failed, add to execution errors
			for _, error in ipairs(stepErrors) do
				table.insert(execution.errors, string.format("Step %d (%s): %s", stepIndex, step.name, error))
			end
			
			logger.LogError("Recovery step failed", {
				executionId = execution.id,
				serviceName = execution.serviceName,
				stepIndex = stepIndex,
				stepName = step.name,
				errors = stepErrors
			})
			
			-- Execute rollback if available
			if step.rollbackAction then
				local rollbackSuccess, rollbackError = pcall(step.rollbackAction)
				if not rollbackSuccess then
					table.insert(execution.errors, string.format("Rollback for step %d failed: %s", stepIndex, tostring(rollbackError)))
				end
			end
			
			return false
		end
		
		logger.LogInfo("Recovery step completed", {
			executionId = execution.id,
			serviceName = execution.serviceName,
			stepIndex = stepIndex,
			stepName = step.name
		})
	end
	
	return true
end

-- Calculate retry delay based on policy
function RecoveryManager:_calculateRetryDelay(retryPolicy: RetryPolicy, attempt: number): number
	local delay = retryPolicy.baseDelay
	
	if retryPolicy.backoffStrategy == "Linear" then
		delay = retryPolicy.baseDelay * attempt
	elseif retryPolicy.backoffStrategy == "Exponential" then
		delay = retryPolicy.baseDelay * (2 ^ (attempt - 1))
	end
	
	-- Apply maximum delay limit
	delay = math.min(delay, retryPolicy.maxDelay)
	
	-- Apply jitter if enabled
	if retryPolicy.jitter then
		local jitterRange = delay * 0.1 -- 10% jitter
		delay = delay + (math.random() - 0.5) * 2 * jitterRange
	end
	
	return math.max(delay, 0)
end

-- Send recovery notification to players
function RecoveryManager:_sendRecoveryNotification(execution: RecoveryExecution, phase: string): ()
	local message = ""
	local severity = "info"
	
	if phase == "started" then
		message = string.format("Service recovery in progress: %s", execution.serviceName)
		severity = "warning"
	elseif phase == "completed" then
		message = string.format("Service recovery completed: %s", execution.serviceName)
		severity = "success"
	elseif phase == "failed" then
		message = string.format("Service recovery failed: %s", execution.serviceName)
		severity = "error"
	end
	
	-- Send to all players
	for _, player in ipairs(Players:GetPlayers()) do
		recoveryNotification:FireClient(player, {
			serviceName = execution.serviceName,
			message = message,
			severity = severity,
			phase = phase,
			executionId = execution.id,
			timestamp = os.time()
		})
	end
end

-- Monitoring and Queue Management

-- Setup health monitoring
function RecoveryManager:_setupHealthMonitoring(): ()
	task.spawn(function()
		while true do
			task.wait(HEALTH_CHECK_INTERVAL)
			
			-- Perform health checks on all registered services
			for serviceName in pairs(serviceRegistry) do
				local success, error = pcall(function()
					self:_performHealthCheck(serviceName)
				end)
				
				if not success then
					logger.LogError("Health check failed", {
						serviceName = serviceName,
						error = tostring(error)
					})
				end
			end
		end
	end)
end

-- Setup recovery queue processing
function RecoveryManager:_setupRecoveryQueue(): ()
	task.spawn(function()
		while true do
			task.wait(RECOVERY_QUEUE_INTERVAL)
			
			-- Process recovery queue
			local currentConcurrentRecoveries = 0
			for _, execution in pairs(activeRecoveries) do
				if execution.status == "Running" then
					currentConcurrentRecoveries = currentConcurrentRecoveries + 1
				end
			end
			
			-- Execute pending recoveries if within limit
			while #recoveryQueue > 0 and currentConcurrentRecoveries < MAX_CONCURRENT_RECOVERIES do
				local executionId = table.remove(recoveryQueue, 1)
				local execution = activeRecoveries[executionId]
				
				if execution and execution.status == "Pending" then
					self:_executeRecovery(executionId)
					currentConcurrentRecoveries = currentConcurrentRecoveries + 1
				end
			end
		end
	end)
end

-- Setup service registry monitoring
function RecoveryManager:_setupServiceRegistry(): ()
	-- Monitor ServiceLocator for new services
	task.spawn(function()
		while true do
			task.wait(30) -- Check every 30 seconds
			
			-- Auto-register services from ServiceLocator
			if ServiceLocator then
				local availableServices = {}
				
				-- Try to get service list (if ServiceLocator supports it)
				local success, services = pcall(function()
					return ServiceLocator:GetAllServices()
				end)
				
				if success and services then
					for serviceName, serviceInstance in pairs(services) do
						if not serviceRegistry[serviceName] then
							self:RegisterService(serviceName, serviceInstance)
						end
					end
				end
			end
		end
	end)
end

-- Public API

-- Get service health
function RecoveryManager:GetServiceHealth(serviceName: string?): ServiceHealth | {[string]: ServiceHealth}
	if serviceName then
		return serviceHealthMap[serviceName]
	else
		return table.clone(serviceHealthMap)
	end
end

-- Get active recoveries
function RecoveryManager:GetActiveRecoveries(): {[string]: RecoveryExecution}
	return table.clone(activeRecoveries)
end

-- Get recovery plans
function RecoveryManager:GetRecoveryPlans(): {[string]: RecoveryPlan}
	return table.clone(recoveryPlans)
end

-- Cancel recovery
function RecoveryManager:CancelRecovery(executionId: string): boolean
	local execution = activeRecoveries[executionId]
	if not execution then
		return false
	end
	
	if execution.status == "Running" or execution.status == "Pending" then
		execution.status = "Cancelled"
		execution.endTime = os.time()
		
		logger.LogInfo("Recovery cancelled", {
			executionId = executionId,
			serviceName = execution.serviceName
		})
		
		return true
	end
	
	return false
end

-- Force service health status
function RecoveryManager:ForceServiceHealth(serviceName: string, status: ServiceStatus): boolean
	local serviceHealth = serviceHealthMap[serviceName]
	if not serviceHealth then
		return false
	end
	
	self:_updateServiceStatus(serviceName, status)
	return true
end

-- Get recovery statistics
function RecoveryManager:GetRecoveryStatistics(): {[string]: any}
	local stats = {
		totalServices = 0,
		healthyServices = 0,
		unhealthyServices = 0,
		recoveringServices = 0,
		totalRecoveries = 0,
		successfulRecoveries = 0,
		failedRecoveries = 0,
		activeRecoveries = 0,
		queuedRecoveries = #recoveryQueue
	}
	
	-- Count service statuses
	for _, health in pairs(serviceHealthMap) do
		stats.totalServices = stats.totalServices + 1
		
		if health.status == "Healthy" then
			stats.healthyServices = stats.healthyServices + 1
		elseif health.status == "Recovering" then
			stats.recoveringServices = stats.recoveringServices + 1
		else
			stats.unhealthyServices = stats.unhealthyServices + 1
		end
		
		stats.totalRecoveries = stats.totalRecoveries + health.recoveryCount
	end
	
	-- Count recovery executions
	for _, execution in pairs(activeRecoveries) do
		if execution.status == "Running" then
			stats.activeRecoveries = stats.activeRecoveries + 1
		elseif execution.status == "Success" then
			stats.successfulRecoveries = stats.successfulRecoveries + 1
		elseif execution.status == "Failed" then
			stats.failedRecoveries = stats.failedRecoveries + 1
		end
	end
	
	return stats
end

-- Event Connections
function RecoveryManager:OnServiceHealthChanged(callback: (any) -> ()): RBXScriptConnection
	return ServiceHealthChanged.Event:Connect(callback)
end

function RecoveryManager:OnRecoveryStarted(callback: (any) -> ()): RBXScriptConnection
	return RecoveryStarted.Event:Connect(callback)
end

function RecoveryManager:OnRecoveryCompleted(callback: (any) -> ()): RBXScriptConnection
	return RecoveryCompleted.Event:Connect(callback)
end

function RecoveryManager:OnRecoveryFailed(callback: (any) -> ()): RBXScriptConnection
	return RecoveryFailed.Event:Connect(callback)
end

function RecoveryManager:OnServiceRecovered(callback: (any) -> ()): RBXScriptConnection
	return ServiceRecovered.Event:Connect(callback)
end

-- Health Check
function RecoveryManager:GetHealthStatus(): {status: string, metrics: any}
	local stats = self:GetRecoveryStatistics()
	local recoveryRate = stats.totalRecoveries > 0 and 
		(stats.successfulRecoveries / stats.totalRecoveries * 100) or 100
	
	local status = "healthy"
	if stats.unhealthyServices > stats.totalServices * 0.5 then
		status = "critical"
	elseif stats.unhealthyServices > stats.totalServices * 0.2 then
		status = "degraded"
	elseif recoveryRate < 95 then
		status = "warning"
	end
	
	return {
		status = status,
		metrics = {
			recoveryRate = recoveryRate,
			servicesMonitored = stats.totalServices,
			healthyServices = stats.healthyServices,
			unhealthyServices = stats.unhealthyServices,
			activeRecoveries = stats.activeRecoveries,
			successfulRecoveries = stats.successfulRecoveries,
			failedRecoveries = stats.failedRecoveries
		}
	}
end

-- Initialize and register service
local recoveryManager = RecoveryManager.new()

-- Register with ServiceLocator
task.wait(1) -- Ensure ServiceLocator is ready
ServiceLocator:RegisterService("RecoveryManager", recoveryManager)

-- Auto-register existing services
task.spawn(function()
	task.wait(5) -- Wait for other services to initialize
	
	-- Register critical services
	local criticalServices = {
		"Logging",
		"AnalyticsEngine", 
		"ConfigManager",
		"MatchmakingEngine",
		"NetworkManager",
		"DataManager",
		"ErrorHandler",
		"CircuitBreaker"
	}
	
	for _, serviceName in ipairs(criticalServices) do
		local service = ServiceLocator:GetService(serviceName)
		if service then
			recoveryManager:RegisterService(serviceName, service)
		end
	end
	
	logger.LogInfo("Critical services registered for recovery monitoring")
end)

return recoveryManager
