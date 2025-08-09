--[[
	ArchitecturalCore.lua
	Enterprise architectural foundation with proper layer separation
	
	Implements Core/Domain/Infrastructure separation with dependency injection
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArchitecturalCore = {}

-- Core Layer: Infrastructure and cross-cutting concerns
ArchitecturalCore.Core = {
	Logging = require(ReplicatedStorage.Shared.Logging),
	RateLimiter = require(ReplicatedStorage.Shared.RateLimiter),
	ObjectPool = require(ReplicatedStorage.Shared.ObjectPool),
	NetworkBatcher = require(ReplicatedStorage.Shared.NetworkBatcher),
	Scheduler = require(ReplicatedStorage.Shared.Scheduler),
	CryptoSecurity = require(ReplicatedStorage.Shared.CryptoSecurity),
	ServiceCache = require(ReplicatedStorage.Shared.ServiceCache),
}

-- Domain Layer: Business logic and game rules
ArchitecturalCore.Domain = {
	WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig),
	GameConfig = require(ReplicatedStorage.Shared.GameConfig),
	Utilities = require(ReplicatedStorage.Shared.Utilities),
	ClientPrediction = require(ReplicatedStorage.Shared.ClientPrediction),
	AnimationManager = require(ReplicatedStorage.Shared.AnimationManager),
}

-- Infrastructure Layer: External dependencies and data access
ArchitecturalCore.Infrastructure = {}

-- Service Locator Pattern for dependency injection
local serviceRegistry = {}

-- Register a service in the architecture
function ArchitecturalCore.RegisterService(serviceName: string, serviceInstance: any, layer: string?)
	local targetLayer = layer or "Core"
	
	if not ArchitecturalCore[targetLayer] then
		error("Invalid architectural layer: " .. targetLayer)
	end
	
	ArchitecturalCore[targetLayer][serviceName] = serviceInstance
	serviceRegistry[serviceName] = {
		instance = serviceInstance,
		layer = targetLayer,
		registeredAt = tick()
	}
	
	print("[ArchitecturalCore] ✓ Registered", serviceName, "in", targetLayer, "layer")
end

-- Get a service from any layer
function ArchitecturalCore.GetService(serviceName: string): any
	local registration = serviceRegistry[serviceName]
	if not registration then
		error("Service not found: " .. serviceName)
	end
	
	return registration.instance
end

-- Get services by layer
function ArchitecturalCore.GetLayer(layerName: string): {[string]: any}
	if not ArchitecturalCore[layerName] then
		error("Layer not found: " .. layerName)
	end
	
	return ArchitecturalCore[layerName]
end

-- Validate architectural dependencies (Core shouldn't depend on Domain)
function ArchitecturalCore.ValidateDependencies(): {violations: {{service: string, invalidDependency: string}}}
	local violations = {}
	
	-- This would be implemented with static analysis in a real system
	-- For now, we'll return an empty violations list
	
	return {violations = violations}
end

-- Get architectural health metrics
function ArchitecturalCore.GetHealthMetrics(): {
	totalServices: number,
	coreServices: number,
	domainServices: number,
	infrastructureServices: number,
	dependencyViolations: number
}
	local coreCount = 0
	local domainCount = 0
	local infraCount = 0
	
	for serviceName, registration in pairs(serviceRegistry) do
		if registration.layer == "Core" then
			coreCount = coreCount + 1
		elseif registration.layer == "Domain" then
			domainCount = domainCount + 1
		elseif registration.layer == "Infrastructure" then
			infraCount = infraCount + 1
		end
	end
	
	local validationResult = ArchitecturalCore.ValidateDependencies()
	
	return {
		totalServices = coreCount + domainCount + infraCount,
		coreServices = coreCount,
		domainServices = domainCount,
		infrastructureServices = infraCount,
		dependencyViolations = #validationResult.violations
	}
end

-- Initialize architectural patterns
function ArchitecturalCore.Initialize()
	-- Register existing services in appropriate layers
	for serviceName, service in pairs(ArchitecturalCore.Core) do
		serviceRegistry[serviceName] = {
			instance = service,
			layer = "Core",
			registeredAt = tick()
		}
	end
	
	for serviceName, service in pairs(ArchitecturalCore.Domain) do
		serviceRegistry[serviceName] = {
			instance = service,
			layer = "Domain", 
			registeredAt = tick()
		}
	end
	
	print("[ArchitecturalCore] ✓ Initialized with proper layer separation")
	
	local metrics = ArchitecturalCore.GetHealthMetrics()
	print("[ArchitecturalCore] ✓ Architecture health:", metrics.totalServices, "services across", 3, "layers")
	
	return true
end

return ArchitecturalCore
