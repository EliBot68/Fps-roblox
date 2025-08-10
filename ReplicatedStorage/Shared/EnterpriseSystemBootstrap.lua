--[[
	EnterpriseSystemBootstrap.lua
	Central bootstrap for all enterprise systems with proper initialization order
	
	Initializes in dependency order:
	1. Core systems (Logging, ServiceLocator) 
	2. Security systems (SecurityValidator, AntiExploit)
	3. Network systems (NetworkBatcher, EnhancedNetworkClient)
	4. Monitoring systems (MetricsExporter, PerformanceMonitoringDashboard)
	5. Testing systems (LoadTester, APIDocGenerator, IntegrationTestSuite)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Import core dependencies
local ServiceLocator = require(ReplicatedStorage.Shared.ServiceLocator)
local Logging = require(ReplicatedStorage.Shared.Logging)

local EnterpriseSystemBootstrap = {}

-- System initialization order and configuration
local SYSTEM_INITIALIZATION_ORDER = {
	{
		phase = "Core",
		systems = {
			{
				name = "SecurityValidator",
				module = "SecurityValidator",
				dependencies = {"Logging"},
				priority = 10,
				critical = true
			},
			{
				name = "NetworkBatcher", 
				module = "NetworkBatcher",
				dependencies = {"Logging"},
				priority = 9,
				critical = true
			},
			{
				name = "MetricsExporter",
				module = "MetricsExporter", 
				dependencies = {"Logging"},
				priority = 8,
				critical = false
			}
		}
	},
	{
		phase = "Security",
		systems = {
			{
				name = "AntiExploit",
				module = "AntiExploit",
				dependencies = {"SecurityValidator", "Logging"},
				priority = 10,
				critical = true,
				serverOnly = true
			}
		}
	},
	{
		phase = "Documentation", 
		systems = {
			{
				name = "APIDocGenerator",
				module = "APIDocGenerator",
				dependencies = {"Logging"},
				priority = 3,
				critical = false
			}
		}
	},
	{
		phase = "Testing",
		systems = {
			{
				name = "LoadTester",
				module = "LoadTester", 
				dependencies = {"MetricsExporter", "SecurityValidator", "NetworkBatcher", "Logging"},
				priority = 2,
				critical = false,
				serverOnly = true
			},
			{
				name = "IntegrationTestSuite",
				module = "IntegrationTestSuite",
				dependencies = {"Logging"},
				priority = 1,
				critical = false
			}
		}
	}
}

-- Bootstrap state tracking
local bootstrapState = {
	started = false,
	completed = false,
	currentPhase = "",
	initializedSystems = {},
	failedSystems = {},
	startTime = 0,
	endTime = 0
}

-- Initialize enterprise system bootstrap
function EnterpriseSystemBootstrap.Initialize()
	if bootstrapState.started then
		print("[EnterpriseBootstrap] ⚠️ Bootstrap already started")
		return
	end
	
	print("[EnterpriseBootstrap] 🚀 Starting enterprise system bootstrap...")
	bootstrapState.started = true
	bootstrapState.startTime = tick()
	
	-- Register all systems with ServiceLocator first
	EnterpriseSystemBootstrap.RegisterAllSystems()
	
	-- Initialize systems in order
	EnterpriseSystemBootstrap.InitializeSystemsInOrder()
	
	bootstrapState.completed = true
	bootstrapState.endTime = tick()
	
	local totalDuration = bootstrapState.endTime - bootstrapState.startTime
	print(string.format("[EnterpriseBootstrap] ✅ Bootstrap completed in %.3f seconds", totalDuration))
	print(string.format("[EnterpriseBootstrap] Initialized: %d systems, Failed: %d systems",
		#bootstrapState.initializedSystems, #bootstrapState.failedSystems))
	
	-- Run post-bootstrap validation
	EnterpriseSystemBootstrap.ValidateSystemHealth()
end

-- Register all systems with ServiceLocator
function EnterpriseSystemBootstrap.RegisterAllSystems()
	print("[EnterpriseBootstrap] 📋 Registering systems with ServiceLocator...")
	
	for _, phase in ipairs(SYSTEM_INITIALIZATION_ORDER) do
		for _, system in ipairs(phase.systems) do
			-- Skip server-only systems on client
			if system.serverOnly and not RunService:IsServer() then
				print(string.format("[EnterpriseBootstrap] ⏭️ Skipping server-only system: %s", system.name))
				continue
			end
			
			-- Create factory function for the system
			local factory = function(dependencies)
				local moduleRef = ReplicatedStorage.Shared[system.module]
				if not moduleRef then
					error(string.format("Module not found: %s", system.module))
				end
				
				local systemModule = require(moduleRef)
				
				-- Initialize system if it has an Initialize method
				if systemModule.Initialize then
					systemModule.Initialize()
				end
				
				return systemModule
			end
			
			-- Health check function
			local healthCheck = function(instance)
				-- Basic health check - ensure the instance exists and has expected properties
				if not instance then
					return false
				end
				
				-- System-specific health checks
				if system.name == "SecurityValidator" then
					return type(instance.ValidateRemoteCall) == "function"
				elseif system.name == "NetworkBatcher" then
					return type(instance.QueueEvent) == "function"
				elseif system.name == "MetricsExporter" then
					return type(instance.RegisterMetric) == "function"
				elseif system.name == "LoadTester" then
					return type(instance.RunStressTest) == "function"
				elseif system.name == "APIDocGenerator" then
					return type(instance.GenerateDocumentation) == "function"
				elseif system.name == "IntegrationTestSuite" then
					return type(instance.RunAllTests) == "function"
				end
				
				return true
			end
			
			-- Register with ServiceLocator
			ServiceLocator.Register(system.name, {
				factory = factory,
				singleton = true,
				dependencies = system.dependencies,
				lazy = false, -- Eager loading for enterprise systems
				priority = system.priority,
				healthCheck = healthCheck,
				tags = {"enterprise", phase.phase:lower()}
			})
			
			print(string.format("[EnterpriseBootstrap] ✓ Registered: %s (Priority: %d)", system.name, system.priority))
		end
	end
end

-- Initialize systems in dependency order
function EnterpriseSystemBootstrap.InitializeSystemsInOrder()
	print("[EnterpriseBootstrap] 🔄 Initializing systems in dependency order...")
	
	for _, phase in ipairs(SYSTEM_INITIALIZATION_ORDER) do
		bootstrapState.currentPhase = phase.phase
		print(string.format("[EnterpriseBootstrap] 📦 Initializing %s phase...", phase.phase))
		
		for _, system in ipairs(phase.systems) do
			-- Skip server-only systems on client
			if system.serverOnly and not RunService:IsServer() then
				continue
			end
			
			local success, result = pcall(function()
				print(string.format("[EnterpriseBootstrap] 🔧 Initializing %s...", system.name))
				
				-- Get service instance (this triggers initialization)
				local instance = ServiceLocator.GetService(system.name)
				
				-- Verify instance was created successfully
				if not instance then
					error("Service instance is nil")
				end
				
				return instance
			end)
			
			if success then
				table.insert(bootstrapState.initializedSystems, {
					name = system.name,
					phase = phase.phase,
					critical = system.critical,
					instance = result
				})
				print(string.format("[EnterpriseBootstrap] ✅ %s initialized successfully", system.name))
			else
				local errorMessage = tostring(result)
				table.insert(bootstrapState.failedSystems, {
					name = system.name,
					phase = phase.phase,
					critical = system.critical,
					error = errorMessage
				})
				
				if system.critical then
					print(string.format("[EnterpriseBootstrap] ❌ CRITICAL SYSTEM FAILED: %s - %s", system.name, errorMessage))
					-- Don't halt bootstrap for critical failures, log and continue
				else
					print(string.format("[EnterpriseBootstrap] ⚠️ Non-critical system failed: %s - %s", system.name, errorMessage))
				end
			end
		end
		
		print(string.format("[EnterpriseBootstrap] ✅ %s phase completed", phase.phase))
	end
end

-- Validate system health post-bootstrap
function EnterpriseSystemBootstrap.ValidateSystemHealth()
	print("[EnterpriseBootstrap] 🏥 Running post-bootstrap health validation...")
	
	-- Run ServiceLocator health checks
	local healthReport = ServiceLocator.RunHealthChecks()
	
	if healthReport then
		print(string.format("[EnterpriseBootstrap] Health Report: %d/%d systems healthy", 
			healthReport.healthyServices, healthReport.totalServices))
		
		if healthReport.unhealthyServices > 0 then
			print(string.format("[EnterpriseBootstrap] ⚠️ %d systems reporting unhealthy", healthReport.unhealthyServices))
		end
		
		if healthReport.failedServices > 0 then
			print(string.format("[EnterpriseBootstrap] ❌ %d systems failed", healthReport.failedServices))
		end
	end
	
	-- Validate critical system integration
	local criticalSystems = {"SecurityValidator", "NetworkBatcher"}
	local allCriticalHealthy = true
	
	for _, systemName in ipairs(criticalSystems) do
		local health = ServiceLocator.GetServiceHealth(systemName)
		if not health or health.state ~= "LOADED" then
			allCriticalHealthy = false
			print(string.format("[EnterpriseBootstrap] ❌ Critical system unhealthy: %s", systemName))
		end
	end
	
	if allCriticalHealthy then
		print("[EnterpriseBootstrap] ✅ All critical systems healthy")
	else
		print("[EnterpriseBootstrap] ⚠️ Some critical systems are unhealthy")
	end
end

-- Get bootstrap status
function EnterpriseSystemBootstrap.GetBootstrapStatus()
	return {
		started = bootstrapState.started,
		completed = bootstrapState.completed,
		currentPhase = bootstrapState.currentPhase,
		initializedSystems = #bootstrapState.initializedSystems,
		failedSystems = #bootstrapState.failedSystems,
		duration = bootstrapState.endTime > 0 and (bootstrapState.endTime - bootstrapState.startTime) or (tick() - bootstrapState.startTime),
		successRate = (#bootstrapState.initializedSystems / (#bootstrapState.initializedSystems + #bootstrapState.failedSystems)) * 100
	}
end

-- Get detailed system status
function EnterpriseSystemBootstrap.GetSystemStatus()
	local systemStatus = {}
	
	for _, system in ipairs(bootstrapState.initializedSystems) do
		local health = ServiceLocator.GetServiceHealth(system.name)
		systemStatus[system.name] = {
			status = "initialized",
			phase = system.phase,
			critical = system.critical,
			health = health
		}
	end
	
	for _, system in ipairs(bootstrapState.failedSystems) do
		systemStatus[system.name] = {
			status = "failed",
			phase = system.phase,
			critical = system.critical,
			error = system.error
		}
	end
	
	return systemStatus
end

-- Run integration test after bootstrap
function EnterpriseSystemBootstrap.RunPostBootstrapTests()
	if not bootstrapState.completed then
		print("[EnterpriseBootstrap] ⚠️ Cannot run tests - bootstrap not completed")
		return false
	end
	
	print("[EnterpriseBootstrap] 🧪 Running post-bootstrap integration tests...")
	
	-- Try to get IntegrationTestSuite
	local success, IntegrationTestSuite = pcall(function()
		return ServiceLocator.GetService("IntegrationTestSuite")
	end)
	
	if not success or not IntegrationTestSuite then
		print("[EnterpriseBootstrap] ⚠️ IntegrationTestSuite not available, skipping tests")
		return false
	end
	
	-- Run basic system integration tests
	local testResults = IntegrationTestSuite.RunAllTests()
	
	print(string.format("[EnterpriseBootstrap] 🧪 Integration tests completed: %.1f%% success rate", 
		testResults.successRate))
	
	return testResults.successRate >= 80 -- 80% success rate threshold
end

-- Console commands for bootstrap management
_G.Enterprise_Bootstrap = function()
	EnterpriseSystemBootstrap.Initialize()
end

_G.Enterprise_Status = function()
	return EnterpriseSystemBootstrap.GetBootstrapStatus()
end

_G.Enterprise_SystemStatus = function()
	return EnterpriseSystemBootstrap.GetSystemStatus()
end

_G.Enterprise_Test = function()
	return EnterpriseSystemBootstrap.RunPostBootstrapTests()
end

_G.Enterprise_HealthCheck = function()
	return ServiceLocator.RunHealthChecks()
end

-- Auto-initialize on server
if RunService:IsServer() then
	print("[EnterpriseBootstrap] 🌟 Enterprise System Bootstrap loaded - use _G.Enterprise_Bootstrap() to initialize")
else
	print("[EnterpriseBootstrap] 🌟 Enterprise System Bootstrap loaded (Client) - use _G.Enterprise_Bootstrap() to initialize")
end

return EnterpriseSystemBootstrap
