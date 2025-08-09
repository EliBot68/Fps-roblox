-- ServiceBootstrap.server.lua
-- Enterprise service registration and dependency injection setup
-- Place in: ServerScriptService/Core/ServiceBootstrap.server.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServiceLocator = require(ReplicatedStorage.Shared.ServiceLocator)
local Logging = require(ReplicatedStorage.Shared.Logging)

local ServiceBootstrap = {}

--[[
	Register all enterprise services with proper dependency injection
]]
function ServiceBootstrap.RegisterServices()
	Logging.Info("ServiceBootstrap", "🏢 Registering enterprise services...")
	
	-- Register WeaponServer (High Priority - No Dependencies)
	ServiceLocator.Register("WeaponServer", {
		factory = function(deps)
			return require(ServerScriptService.WeaponServer.WeaponServer)
		end,
		singleton = true,
		lazy = false, -- Load immediately
		priority = 10,
		tags = {"weapon", "core", "server"},
		healthCheck = function(instance)
			return instance and type(instance.HandleFireWeapon) == "function"
		end
	})
	
	-- Register PracticeMapManager (Medium Priority - Depends on WeaponServer)
	ServiceLocator.Register("PracticeMapManager", {
		factory = function(deps)
			-- Create a wrapper that provides clean dependency injection
			local PracticeManager = require(ServerScriptService.Core.PracticeMapManager)
			
			-- Inject WeaponServer dependency
			PracticeManager.WeaponServer = deps.WeaponServer
			
			return PracticeManager
		end,
		singleton = true,
		dependencies = {"WeaponServer"},
		priority = 8,
		tags = {"practice", "weapons", "server"},
		healthCheck = function(instance)
			return instance and type(instance.GiveWeapon) == "function"
		end
	})
	
	-- Register LobbyManager (Medium Priority - Depends on PracticeMapManager)
	ServiceLocator.Register("LobbyManager", {
		factory = function(deps)
			local LobbyManager = require(ServerScriptService.Core.LobbyManager)
			
			-- Inject PracticeMapManager dependency
			LobbyManager.PracticeMapManager = deps.PracticeMapManager
			
			return LobbyManager
		end,
		singleton = true,
		dependencies = {"PracticeMapManager"},
		priority = 7,
		tags = {"lobby", "teleport", "server"},
		healthCheck = function(instance)
			return instance and type(instance.HandleTouch) == "function"
		end
	})
	
	-- Register Combat System (High Priority - Depends on WeaponServer)
	ServiceLocator.Register("CombatSystem", {
		factory = function(deps)
			local Combat = require(ServerScriptService.Core.Combat)
			
			-- Inject dependencies
			Combat.WeaponServer = deps.WeaponServer
			
			return Combat
		end,
		singleton = true,
		dependencies = {"WeaponServer"},
		priority = 9,
		tags = {"combat", "weapons", "server"},
		healthCheck = function(instance)
			return instance and instance.GetPlayerState ~= nil
		end
	})
	
	-- Register AntiCheat System (Critical Priority - No Dependencies)
	ServiceLocator.Register("AntiCheat", {
		factory = function(deps)
			return require(ServerScriptService.Core.AntiCheat)
		end,
		singleton = true,
		lazy = false, -- Critical security component
		priority = 10,
		tags = {"security", "anticheat", "critical"},
		healthCheck = function(instance)
			return instance and type(instance.ValidateAction) == "function"
		end
	})
	
	-- Register Economy System (Low Priority - No Dependencies)
	ServiceLocator.Register("CurrencyManager", {
		factory = function(deps)
			return require(ServerScriptService.Economy.CurrencyManager)
		end,
		singleton = true,
		priority = 5,
		tags = {"economy", "currency", "server"},
		healthCheck = function(instance)
			return instance and type(instance.GetPlayerCurrency) == "function"
		end
	})
	
	-- Register Shared Services
	ServiceLocator.Register("RateLimiter", {
		factory = function(deps)
			return require(ReplicatedStorage.Shared.RateLimiter)
		end,
		singleton = true,
		lazy = false,
		priority = 9,
		tags = {"security", "shared", "ratelimit"}
	})
	
	ServiceLocator.Register("NetworkBatcher", {
		factory = function(deps)
			return require(ReplicatedStorage.Shared.NetworkBatcher)
		end,
		singleton = true,
		priority = 8,
		tags = {"network", "performance", "shared"}
	})
	
	ServiceLocator.Register("ObjectPool", {
		factory = function(deps)
			return require(ReplicatedStorage.Shared.ObjectPool)
		end,
		singleton = true,
		priority = 8,
		tags = {"performance", "memory", "shared"}
	})
	
	Logging.Info("ServiceBootstrap", "✅ All enterprise services registered successfully")
end

--[[
	Setup service health monitoring and performance tracking
]]
function ServiceBootstrap.SetupMonitoring()
	-- Add performance monitoring hook
	ServiceLocator.AddLifecycleHook("afterLoad", function(serviceName)
		Logging.Info("ServiceBootstrap", "Service loaded: " .. serviceName)
	end)
	
	-- Add failure monitoring hook
	ServiceLocator.AddLifecycleHook("beforeDispose", function(serviceName)
		Logging.Warn("ServiceBootstrap", "Service disposing: " .. serviceName)
	end)
	
	-- Setup periodic metrics reporting
	task.spawn(function()
		while true do
			task.wait(60) -- Report every minute
			
			local metrics = ServiceLocator.GetMetrics()
			Logging.Info("ServiceBootstrap", "Service Performance Metrics", {
				totalResolutions = metrics.totalResolutions,
				cacheHitRate = string.format("%.1f%%", metrics.cacheHitRate),
				failureRate = string.format("%.1f%%", metrics.failureRate),
				avgResolutionTime = string.format("%.3fs", metrics.averageResolutionTime),
				totalServices = metrics.totalServices,
				loadedServices = metrics.loadedServices
			})
		end
	end)
	
	Logging.Info("ServiceBootstrap", "📊 Service monitoring and metrics enabled")
end

--[[
	Initialize all enterprise services in proper order
]]
function ServiceBootstrap.Initialize()
	Logging.Info("ServiceBootstrap", "🚀 Initializing Enterprise Service Framework...")
	
	-- Step 1: Register all services
	ServiceBootstrap.RegisterServices()
	
	-- Step 2: Setup monitoring
	ServiceBootstrap.SetupMonitoring()
	
	-- Step 3: Pre-load critical services
	local criticalServices = {"AntiCheat", "WeaponServer", "RateLimiter"}
	for _, serviceName in ipairs(criticalServices) do
		local success, service = pcall(function()
			return ServiceLocator.GetService(serviceName)
		end)
		
		if success then
			Logging.Info("ServiceBootstrap", "✅ Critical service loaded: " .. serviceName)
		else
			Logging.Error("ServiceBootstrap", "❌ Failed to load critical service: " .. serviceName, {
				error = service
			})
		end
	end
	
	-- Step 4: Run initial health check
	task.wait(2) -- Allow services to fully initialize
	local healthReport = ServiceLocator.RunHealthChecks()
	
	Logging.Info("ServiceBootstrap", "🏥 Initial health check completed", {
		totalServices = healthReport.totalServices,
		healthyServices = healthReport.healthyServices,
		unhealthyServices = healthReport.unhealthyServices,
		failedServices = healthReport.failedServices
	})
	
	Logging.Info("ServiceBootstrap", "🎯 Enterprise Service Framework initialized successfully!")
	
	return true
end

-- Auto-initialize when script loads
ServiceBootstrap.Initialize()

return ServiceBootstrap
