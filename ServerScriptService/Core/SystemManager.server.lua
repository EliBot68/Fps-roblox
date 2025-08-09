-- SystemManager.server.lua
-- Enterprise system coordinator and health monitoring

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Logging = require(ReplicatedStorage.Shared.Logging)

local SystemManager = {}

-- Core system references
local systems = {
	Combat = require(script.Parent.Combat),
	Matchmaker = require(script.Parent.Matchmaker),
	DataStore = require(script.Parent.DataStore),
	RankManager = require(script.Parent.RankManager),
	AntiCheat = require(script.Parent.AntiCheat),
	MapManager = require(script.Parent.MapManager),
	ShopManager = require(script.Parent.ShopManager),
	ClanBattles = require(script.Parent.ClanBattles),
	KillStreakManager = require(script.Parent.KillStreakManager),
	ABTesting = require(script.Parent.ABTesting),
	MetricsDashboard = require(script.Parent.MetricsDashboard),
	ErrorAggregation = require(script.Parent.ErrorAggregation),
	SessionMigration = require(script.Parent.SessionMigration),
	StatisticsAnalytics = require(script.Parent.StatisticsAnalytics),
	RankedSeasons = require(script.Parent.RankedSeasons),
	AdminReviewTool = require(script.Parent.AdminReviewTool),
	FeatureFlags = require(script.Parent.FeatureFlags),
	Tournament = require(script.Parent.Tournament),
	RankRewards = require(script.Parent.RankRewards),
	CurrencyManager = require(script.Parent.Parent.Economy.CurrencyManager),
	DailyChallenges = require(script.Parent.Parent.Events.DailyChallenges),
}

-- System health monitoring
local systemHealth = {}
local healthCheckInterval = 30
local lastHealthCheck = 0

-- Performance metrics
local performanceMetrics = {
	fps = 60,
	memory = 0,
	playerCount = 0,
	activeMatches = 0,
	systemErrors = 0,
	lastUpdate = 0
}

function SystemManager.Initialize()
	Logging.Info("SystemManager initializing all enterprise systems...")
	
	-- Initialize all systems in proper order
	local initOrder = {
		"DataStore",
		"MapManager", 
		"AntiCheat",
		"RankManager",
		"CurrencyManager",
		"ShopManager",
		"Combat",
		"KillStreakManager",
		"Matchmaker",
		"ClanBattles",
		"RankedSeasons",
		"DailyChallenges",
		"ABTesting",
		"FeatureFlags",
		"Tournament",
		"RankRewards",
		"MetricsDashboard",
		"StatisticsAnalytics",
		"ErrorAggregation",
		"SessionMigration",
		"AdminReviewTool"
	}
	
	for _, systemName in ipairs(initOrder) do
		local success, err = pcall(function()
			local system = systems[systemName]
			if system and system.Initialize then
				system.Initialize()
				systemHealth[systemName] = {
					status = "healthy",
					lastCheck = os.time(),
					errorCount = 0,
					initialized = true
				}
				Logging.Info("✓ " .. systemName .. " initialized successfully")
			elseif system then
				systemHealth[systemName] = {
					status = "healthy",
					lastCheck = os.time(),
					errorCount = 0,
					initialized = true
				}
				Logging.Info("✓ " .. systemName .. " loaded (no init required)")
			end
		end)
		
		if not success then
			systemHealth[systemName] = {
				status = "error",
				lastError = err,
				errorCount = 1,
				initialized = false
			}
			Logging.Error("SystemManager", "Failed to initialize " .. systemName .. ": " .. tostring(err))
		end
	end
	
	-- Start monitoring
	SystemManager.StartHealthMonitoring()
	SystemManager.StartPerformanceMonitoring()
	
	Logging.Info("SystemManager initialization complete - All systems online")
end

function SystemManager.StartHealthMonitoring()
	spawn(function()
		while true do
			wait(healthCheckInterval)
			SystemManager.PerformHealthCheck()
		end
	end)
end

function SystemManager.StartPerformanceMonitoring()
	spawn(function()
		while true do
			wait(GameConfig.Performance.MetricsIntervalSeconds)
			SystemManager.UpdatePerformanceMetrics()
		end
	end)
end

function SystemManager.PerformHealthCheck()
	local now = os.time()
	local unhealthySystems = {}
	
	for systemName, health in pairs(systemHealth) do
		if health.status == "error" or (now - health.lastCheck) > healthCheckInterval * 2 then
			table.insert(unhealthySystems, systemName)
			
			-- Attempt to recover critical systems
			if SystemManager.IsCriticalSystem(systemName) then
				SystemManager.AttemptSystemRecovery(systemName)
			end
		end
	end
	
	if #unhealthySystems > 0 then
		Logging.Warn("SystemManager", "Unhealthy systems detected: " .. table.concat(unhealthySystems, ", "))
		
		-- Alert admins if too many systems are down
		if #unhealthySystems >= 3 then
			SystemManager.AlertAdmins("Critical system failure", unhealthySystems)
		end
	end
	
	lastHealthCheck = now
end

function SystemManager.UpdatePerformanceMetrics()
	local stats = game:GetService("Stats")
	
	performanceMetrics.fps = math.floor(1 / RunService.Heartbeat:Wait())
	performanceMetrics.memory = stats:GetTotalMemoryUsageMb()
	performanceMetrics.playerCount = #Players:GetPlayers()
	performanceMetrics.lastUpdate = os.time()
	
	-- Check if we're exceeding thresholds
	if performanceMetrics.memory > GameConfig.Performance.MaxServerMemoryMB then
		Logging.Warn("SystemManager", "High memory usage: " .. performanceMetrics.memory .. "MB")
		SystemManager.TriggerGarbageCollection()
	end
	
	if performanceMetrics.fps < GameConfig.Performance.MinServerFPS then
		Logging.Warn("SystemManager", "Low server FPS: " .. performanceMetrics.fps)
	end
	
	-- Update metrics dashboard
	if systems.MetricsDashboard then
		systems.MetricsDashboard.UpdateSystemMetrics(performanceMetrics)
	end
end

function SystemManager.IsCriticalSystem(systemName)
	local criticalSystems = {
		"DataStore", "Combat", "AntiCheat", "Matchmaker", "ErrorAggregation"
	}
	
	for _, critical in ipairs(criticalSystems) do
		if critical == systemName then
			return true
		end
	end
	
	return false
end

function SystemManager.AttemptSystemRecovery(systemName)
	Logging.Info("SystemManager", "Attempting to recover system: " .. systemName)
	
	local success, err = pcall(function()
		local system = systems[systemName]
		if system and system.Initialize then
			system.Initialize()
		end
	end)
	
	if success then
		systemHealth[systemName].status = "healthy"
		systemHealth[systemName].lastCheck = os.time()
		systemHealth[systemName].errorCount = 0
		Logging.Info("SystemManager", "Successfully recovered system: " .. systemName)
	else
		systemHealth[systemName].errorCount = systemHealth[systemName].errorCount + 1
		systemHealth[systemName].lastError = err
		Logging.Error("SystemManager", "Failed to recover system " .. systemName .. ": " .. tostring(err))
	end
end

function SystemManager.TriggerGarbageCollection()
	collectgarbage("collect")
	Logging.Info("SystemManager", "Triggered garbage collection")
end

function SystemManager.AlertAdmins(message, data)
	-- Send alerts to admin systems
	if systems.AdminReviewTool then
		systems.AdminReviewTool.SendSystemAlert(message, data)
	end
	
	-- Log critical alert
	Logging.Error("SystemManager", "CRITICAL ALERT: " .. message .. " - Data: " .. game:GetService("HttpService"):JSONEncode(data or {}))
end

function SystemManager.GetSystemStatus()
	return {
		health = systemHealth,
		performance = performanceMetrics,
		uptime = os.time() - (systemHealth.DataStore and systemHealth.DataStore.lastCheck or os.time()),
		lastHealthCheck = lastHealthCheck
	}
end

function SystemManager.GetSystem(systemName)
	return systems[systemName]
end

function SystemManager.RestartSystem(systemName)
	if not systems[systemName] then
		return false, "System not found"
	end
	
	local success, err = pcall(function()
		-- Stop system if it has a cleanup method
		if systems[systemName].Cleanup then
			systems[systemName].Cleanup()
		end
		
		-- Restart system
		if systems[systemName].Initialize then
			systems[systemName].Initialize()
		end
	end)
	
	if success then
		systemHealth[systemName] = {
			status = "healthy",
			lastCheck = os.time(),
			errorCount = 0,
			initialized = true
		}
		return true
	else
		return false, err
	end
end

-- Initialize on script load
SystemManager.Initialize()

return SystemManager
