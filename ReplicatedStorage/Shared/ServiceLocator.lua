-- ServiceLocator.lua
-- Enterprise-grade service locator with dependency injection, lazy loading, and health monitoring
-- Replaces scattered require() calls with centralized, testable service management

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logging = require(ReplicatedStorage.Shared.Logging)

local ServiceLocator = {}

-- Service registry with metadata
local services = {}
local serviceInstances = {}
local serviceDependencies = {}
local serviceHealth = {}
local serviceMetrics = {
	totalResolutions = 0,
	cacheHits = 0,
	failedResolutions = 0,
	averageResolutionTime = 0
}

-- Service states
local SERVICE_STATES = {
	UNREGISTERED = "UNREGISTERED",
	REGISTERED = "REGISTERED", 
	LOADING = "LOADING",
	LOADED = "LOADED",
	FAILED = "FAILED",
	DISPOSED = "DISPOSED"
}

-- Service lifecycle hooks
local lifecycleHooks = {
	beforeLoad = {},
	afterLoad = {},
	beforeDispose = {},
	afterDispose = {}
}

-- Enterprise configuration
local CONFIG = {
	maxResolutionDepth = 10,
	circularDependencyTimeout = 5,
	healthCheckInterval = 30,
	cacheEnabled = true,
	metricsEnabled = true,
	securityValidation = true
}

--[[
	Register a service with the locator
	
	@param serviceName: string - Unique service identifier
	@param serviceConfig: table - Service configuration
		- factory: function - Factory function to create service instance
		- singleton: boolean - Whether service should be singleton (default: true)
		- dependencies: table - Array of dependency service names
		- lazy: boolean - Whether to load on-demand (default: true)
		- priority: number - Loading priority (1-10, default: 5)
		- healthCheck: function - Optional health check function
		- dispose: function - Optional cleanup function
		- tags: table - Service tags for categorization
]]
function ServiceLocator.Register(serviceName: string, serviceConfig: table)
	assert(type(serviceName) == "string" and serviceName ~= "", "Service name must be a non-empty string")
	assert(type(serviceConfig) == "table", "Service config must be a table")
	assert(type(serviceConfig.factory) == "function", "Service factory must be a function")
	
	if services[serviceName] then
		Logging.Warn("ServiceLocator", "Service already registered, replacing: " .. serviceName)
	end
	
	-- Default configuration
	local config = {
		factory = serviceConfig.factory,
		singleton = serviceConfig.singleton ~= false, -- Default to singleton
		dependencies = serviceConfig.dependencies or {},
		lazy = serviceConfig.lazy ~= false, -- Default to lazy
		priority = serviceConfig.priority or 5,
		healthCheck = serviceConfig.healthCheck,
		dispose = serviceConfig.dispose,
		tags = serviceConfig.tags or {},
		registeredAt = tick()
	}
	
	-- Validate dependencies
	for _, dep in ipairs(config.dependencies) do
		assert(type(dep) == "string", "Dependency must be a string: " .. tostring(dep))
	end
	
	services[serviceName] = config
	serviceDependencies[serviceName] = config.dependencies
	serviceHealth[serviceName] = {
		state = SERVICE_STATES.REGISTERED,
		lastCheck = tick(),
		failures = 0,
		lastError = nil
	}
	
	Logging.Info("ServiceLocator", "Service registered: " .. serviceName, {
		singleton = config.singleton,
		lazy = config.lazy,
		dependencies = config.dependencies,
		tags = config.tags
	})
	
	-- Auto-load if not lazy and no dependencies
	if not config.lazy and #config.dependencies == 0 then
		task.spawn(function()
			ServiceLocator.GetService(serviceName)
		end)
	end
end

--[[
	Get service instance with dependency resolution
	
	@param serviceName: string - Service name to resolve
	@return any - Service instance
]]
function ServiceLocator.GetService(serviceName: string)
	local startTime = tick()
	serviceMetrics.totalResolutions = serviceMetrics.totalResolutions + 1
	
	-- Input validation
	if type(serviceName) ~= "string" or serviceName == "" then
		serviceMetrics.failedResolutions = serviceMetrics.failedResolutions + 1
		error("Invalid service name: " .. tostring(serviceName))
	end
	
	-- Check if service is registered
	if not services[serviceName] then
		serviceMetrics.failedResolutions = serviceMetrics.failedResolutions + 1
		error("Service not registered: " .. serviceName)
	end
	
	-- Return cached instance if singleton and already loaded
	if services[serviceName].singleton and serviceInstances[serviceName] then
		serviceMetrics.cacheHits = serviceMetrics.cacheHits + 1
		ServiceLocator._UpdateMetrics(startTime)
		return serviceInstances[serviceName]
	end
	
	-- Check for circular dependencies
	local resolutionStack = {}
	return ServiceLocator._ResolveService(serviceName, resolutionStack, startTime)
end

--[[
	Internal service resolution with circular dependency detection
]]
function ServiceLocator._ResolveService(serviceName: string, resolutionStack: table, startTime: number)
	-- Check resolution depth
	if #resolutionStack > CONFIG.maxResolutionDepth then
		serviceMetrics.failedResolutions = serviceMetrics.failedResolutions + 1
		error("Maximum resolution depth exceeded for service: " .. serviceName)
	end
	
	-- Check for circular dependency
	for _, stackService in ipairs(resolutionStack) do
		if stackService == serviceName then
			serviceMetrics.failedResolutions = serviceMetrics.failedResolutions + 1
			local cycle = table.concat(resolutionStack, " -> ") .. " -> " .. serviceName
			error("Circular dependency detected: " .. cycle)
		end
	end
	
	table.insert(resolutionStack, serviceName)
	
	local serviceConfig = services[serviceName]
	local health = serviceHealth[serviceName]
	
	-- Update service state
	health.state = SERVICE_STATES.LOADING
	
	-- Execute before load hooks
	ServiceLocator._ExecuteHooks("beforeLoad", serviceName)
	
	local success, result = pcall(function()
		-- Resolve dependencies first
		local dependencies = {}
		for _, depName in ipairs(serviceConfig.dependencies) do
			dependencies[depName] = ServiceLocator._ResolveService(depName, resolutionStack, startTime)
		end
		
		-- Create service instance
		local instance = serviceConfig.factory(dependencies)
		
		-- Validate instance
		if instance == nil then
			error("Service factory returned nil for: " .. serviceName)
		end
		
		-- Cache singleton instances
		if serviceConfig.singleton then
			serviceInstances[serviceName] = instance
		end
		
		return instance
	end)
	
	table.remove(resolutionStack) -- Remove from stack
	
	if success then
		-- Update health status
		health.state = SERVICE_STATES.LOADED
		health.lastCheck = tick()
		health.failures = 0
		health.lastError = nil
		
		-- Execute after load hooks
		ServiceLocator._ExecuteHooks("afterLoad", serviceName)
		
		ServiceLocator._UpdateMetrics(startTime)
		
		Logging.Info("ServiceLocator", "Service resolved successfully: " .. serviceName)
		return result
	else
		-- Handle failure
		health.state = SERVICE_STATES.FAILED
		health.failures = health.failures + 1
		health.lastError = result
		
		serviceMetrics.failedResolutions = serviceMetrics.failedResolutions + 1
		
		Logging.Error("ServiceLocator", "Service resolution failed: " .. serviceName, {
			error = result,
			failures = health.failures,
			resolutionStack = resolutionStack
		})
		
		error("Failed to resolve service '" .. serviceName .. "': " .. tostring(result))
	end
end

--[[
	Update performance metrics
]]
function ServiceLocator._UpdateMetrics(startTime: number)
	if not CONFIG.metricsEnabled then return end
	
	local resolutionTime = tick() - startTime
	serviceMetrics.averageResolutionTime = (serviceMetrics.averageResolutionTime + resolutionTime) / 2
end

--[[
	Execute lifecycle hooks
]]
function ServiceLocator._ExecuteHooks(hookType: string, serviceName: string)
	local hooks = lifecycleHooks[hookType]
	if not hooks then return end
	
	for _, hook in ipairs(hooks) do
		local success, error = pcall(hook, serviceName)
		if not success then
			Logging.Warn("ServiceLocator", "Hook execution failed", {
				hookType = hookType,
				serviceName = serviceName,
				error = error
			})
		end
	end
end

--[[
	Check if service is registered
]]
function ServiceLocator.IsRegistered(serviceName: string): boolean
	return services[serviceName] ~= nil
end

--[[
	Get service health status
]]
function ServiceLocator.GetServiceHealth(serviceName: string): table?
	return serviceHealth[serviceName]
end

--[[
	Get all registered services
]]
function ServiceLocator.GetRegisteredServices(): table
	local serviceList = {}
	for name, config in pairs(services) do
		serviceList[name] = {
			name = name,
			singleton = config.singleton,
			lazy = config.lazy,
			dependencies = config.dependencies,
			tags = config.tags,
			health = serviceHealth[name]
		}
	end
	return serviceList
end

--[[
	Dispose service and cleanup resources
]]
function ServiceLocator.DisposeService(serviceName: string)
	if not services[serviceName] then
		Logging.Warn("ServiceLocator", "Cannot dispose unregistered service: " .. serviceName)
		return
	end
	
	ServiceLocator._ExecuteHooks("beforeDispose", serviceName)
	
	local config = services[serviceName]
	local instance = serviceInstances[serviceName]
	
	-- Call custom dispose function if provided
	if config.dispose and instance then
		local success, error = pcall(config.dispose, instance)
		if not success then
			Logging.Error("ServiceLocator", "Service dispose failed: " .. serviceName, {error = error})
		end
	end
	
	-- Remove from cache
	serviceInstances[serviceName] = nil
	serviceHealth[serviceName].state = SERVICE_STATES.DISPOSED
	
	ServiceLocator._ExecuteHooks("afterDispose", serviceName)
	
	Logging.Info("ServiceLocator", "Service disposed: " .. serviceName)
end

--[[
	Dispose all services
]]
function ServiceLocator.DisposeAll()
	Logging.Info("ServiceLocator", "Disposing all services...")
	
	for serviceName in pairs(services) do
		ServiceLocator.DisposeService(serviceName)
	end
	
	-- Clear registrations
	services = {}
	serviceInstances = {}
	serviceDependencies = {}
	serviceHealth = {}
end

--[[
	Run health checks on all services
]]
function ServiceLocator.RunHealthChecks()
	if not CONFIG.metricsEnabled then return end
	
	local healthReport = {
		totalServices = 0,
		healthyServices = 0,
		unhealthyServices = 0,
		failedServices = 0,
		timestamp = tick()
	}
	
	for serviceName, config in pairs(services) do
		healthReport.totalServices = healthReport.totalServices + 1
		local health = serviceHealth[serviceName]
		
		if config.healthCheck and serviceInstances[serviceName] then
			local success, result = pcall(config.healthCheck, serviceInstances[serviceName])
			
			if success and result then
				healthReport.healthyServices = healthReport.healthyServices + 1
				health.lastCheck = tick()
			else
				healthReport.unhealthyServices = healthReport.unhealthyServices + 1
				health.failures = health.failures + 1
				health.lastError = result or "Health check returned false"
			end
		elseif health.state == SERVICE_STATES.FAILED then
			healthReport.failedServices = healthReport.failedServices + 1
		end
	end
	
	Logging.Info("ServiceLocator", "Health check completed", healthReport)
	return healthReport
end

--[[
	Get performance metrics
]]
function ServiceLocator.GetMetrics(): table
	local cacheHitRate = serviceMetrics.totalResolutions > 0 
		and (serviceMetrics.cacheHits / serviceMetrics.totalResolutions * 100) 
		or 0
		
	local failureRate = serviceMetrics.totalResolutions > 0 
		and (serviceMetrics.failedResolutions / serviceMetrics.totalResolutions * 100) 
		or 0
	
	return {
		totalResolutions = serviceMetrics.totalResolutions,
		cacheHits = serviceMetrics.cacheHits,
		cacheHitRate = cacheHitRate,
		failedResolutions = serviceMetrics.failedResolutions,
		failureRate = failureRate,
		averageResolutionTime = serviceMetrics.averageResolutionTime,
		totalServices = table.getn(services),
		loadedServices = table.getn(serviceInstances)
	}
end

--[[
	Add lifecycle hook
]]
function ServiceLocator.AddLifecycleHook(hookType: string, hookFunction)
	assert(lifecycleHooks[hookType], "Invalid hook type: " .. hookType)
	assert(type(hookFunction) == "function", "Hook must be a function")
	
	table.insert(lifecycleHooks[hookType], hookFunction)
end

-- Initialize periodic health checks
if RunService:IsServer() and CONFIG.metricsEnabled then
	task.spawn(function()
		while true do
			task.wait(CONFIG.healthCheckInterval)
			ServiceLocator.RunHealthChecks()
		end
	end)
end

-- Graceful shutdown
game.BindToClose(function()
	Logging.Info("ServiceLocator", "Graceful shutdown initiated")
	ServiceLocator.DisposeAll()
end)

Logging.Info("ServiceLocator", "Enterprise Service Locator initialized", {
	config = CONFIG,
	features = {"Dependency Injection", "Lazy Loading", "Health Monitoring", "Circular Detection", "Performance Metrics"}
})

return ServiceLocator
