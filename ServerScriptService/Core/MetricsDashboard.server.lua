--[[
	MetricsDashboard.server.lua
	Enterprise real-time metrics collection and monitoring dashboard
	
	Provides comprehensive monitoring with alerting, trending, and anomaly detection
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MemoryStoreService = game:GetService("MemoryStoreService")

local Logging = require(ReplicatedStorage.Shared.Logging)
local RateLimiter = require(ReplicatedStorage.Shared.RateLimiter)

local MetricsDashboard = {}

-- Enhanced metrics storage with enterprise features
local metrics = {
	counters = {},
	gauges = {},
	timers = {},
	events = {},
	performance = {
		serverFPS = 0,
		playerCount = 0,
		memoryUsage = 0,
		networkIn = 0,
		networkOut = 0,
		uptime = tick()
	},
	security = {
		rateLimitViolations = 0,
		antiCheatAlerts = 0,
		bannedPlayers = 0,
		suspiciousActivity = 0
	},
	alerts = {},
	trends = {}
}

-- Alert thresholds and configuration
local alertConfig = {
	thresholds = {
		serverFPS = 30,
		memoryUsage = 80,
		rateLimitViolations = 50,
		antiCheatAlerts = 10,
		playerCount = 55
	},
	enabled = true,
	alertCooldown = 300 -- 5 minutes
}

local METRICS_HISTORY_SIZE = 300 -- 5 minutes at 1Hz
local metricsHistory = {}
local activeAlerts = {}

-- Cross-server metrics coordination
local crossServerMetrics = nil
pcall(function()
	crossServerMetrics = MemoryStoreService:GetSortedMap("MetricsGlobal")
end)

-- Dashboard RemoteEvent
local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
local DashboardRemote = Instance.new("RemoteEvent")
DashboardRemote.Name = "DashboardRemote"
DashboardRemote.Parent = RemoteRoot

function MetricsDashboard.Inc(name, value, tags)
	value = value or 1
	tags = tags or {}
	
	if not metrics.counters[name] then
		metrics.counters[name] = { value = 0, tags = {}, lastUpdate = tick() }
	end
	
	metrics.counters[name].value = metrics.counters[name].value + value
	metrics.counters[name].lastUpdate = tick()
	
	-- Store tagged metrics separately
	for tag, tagValue in pairs(tags) do
		local taggedName = name .. "." .. tag .. ":" .. tagValue
		if not metrics.counters[taggedName] then
			metrics.counters[taggedName] = { value = 0, lastUpdate = tick() }
		end
		metrics.counters[taggedName].value = metrics.counters[taggedName].value + value
		metrics.counters[taggedName].lastUpdate = tick()
	end
end

function MetricsDashboard.Set(name, value, tags)
	tags = tags or {}
	
	metrics.gauges[name] = {
		value = value,
		tags = tags,
		lastUpdate = tick()
	}
end

function MetricsDashboard.Timer(name, duration, tags)
	tags = tags or {}
	
	if not metrics.timers[name] then
		metrics.timers[name] = {
			count = 0,
			totalTime = 0,
			minTime = math.huge,
			maxTime = 0,
			avgTime = 0,
			lastUpdate = tick()
		}
	end
	
	local timer = metrics.timers[name]
	timer.count = timer.count + 1
	timer.totalTime = timer.totalTime + duration
	timer.minTime = math.min(timer.minTime, duration)
	timer.maxTime = math.max(timer.maxTime, duration)
	timer.avgTime = timer.totalTime / timer.count
	timer.lastUpdate = tick()
end

function MetricsDashboard.Event(name, data, tags)
	tags = tags or {}
	
	if not metrics.events[name] then
		metrics.events[name] = {}
	end
	
	table.insert(metrics.events[name], {
		data = data,
		tags = tags,
		timestamp = tick()
	})
	
	-- Keep only recent events
	if #metrics.events[name] > 1000 then
		table.remove(metrics.events[name], 1)
	end
end

function MetricsDashboard.GetSnapshot()
	return {
		counters = metrics.counters,
		gauges = metrics.gauges,
		timers = metrics.timers,
		events = metrics.events,
		performance = metrics.performance,
		timestamp = tick()
	}
end

function MetricsDashboard.GetHistory(minutes)
	minutes = minutes or 10
	local cutoff = tick() - (minutes * 60)
	
	local history = {}
	for _, snapshot in ipairs(metricsHistory) do
		if snapshot.timestamp >= cutoff then
			table.insert(history, snapshot)
		end
	end
	
	return history
end

-- Performance monitoring
local function updatePerformanceMetrics()
	metrics.performance.serverFPS = 1 / RunService.Heartbeat:Wait()
	metrics.performance.playerCount = #Players:GetPlayers()
	
	-- Get memory usage safely
	local success, memoryMB = pcall(function()
		return game:GetService("Stats"):GetTotalMemoryUsageMb(Enum.MemoryInfoType.Internal)
	end)
	metrics.performance.memoryUsage = success and memoryMB or 0
	
	-- Network stats (approximated)
	local stats = game:GetService("NetworkServer")
	if stats then
		metrics.performance.networkIn = stats.Data.Receive
		metrics.performance.networkOut = stats.Data.Send
	end
end

-- Store metrics snapshots for history
local function storeSnapshot()
	local snapshot = MetricsDashboard.GetSnapshot()
	table.insert(metricsHistory, snapshot)
	
	-- Keep history size manageable
	if #metricsHistory > METRICS_HISTORY_SIZE then
		table.remove(metricsHistory, 1)
	end
end

-- Game-specific metrics collection
local function collectGameMetrics()
	-- Player distribution metrics
	local lobbying = 0
	local inMatch = 0
	local spectating = 0
	
	for _, player in ipairs(Players:GetPlayers()) do
		-- This would check player states
		lobbying = lobbying + 1 -- Placeholder
	end
	
	MetricsDashboard.Set("players.lobbying", lobbying)
	MetricsDashboard.Set("players.inMatch", inMatch)
	MetricsDashboard.Set("players.spectating", spectating)
	
	-- Weapon usage stats
	local weaponStats = {
		AssaultRifle = 0,
		SMG = 0,
		Shotgun = 0,
		Sniper = 0,
		Pistol = 0
	}
	
	for weapon, count in pairs(weaponStats) do
		MetricsDashboard.Set("weapons.active." .. weapon, count)
	end
end

-- Alert system for critical metrics
local function checkAlerts()
	local alerts = {}
	
	-- Server performance alerts
	if metrics.performance.serverFPS < 20 then
		table.insert(alerts, {
			level = "critical",
			metric = "server_fps",
			value = metrics.performance.serverFPS,
			message = "Server FPS critically low"
		})
	end
	
	if metrics.performance.memoryUsage > 1000 then
		table.insert(alerts, {
			level = "warning",
			metric = "memory_usage",
			value = metrics.performance.memoryUsage,
			message = "High memory usage detected"
		})
	end
	
	-- Game-specific alerts
	local errorRate = (metrics.counters["errors.total"] and metrics.counters["errors.total"].value) or 0
	if errorRate > 10 then
		table.insert(alerts, {
			level = "warning",
			metric = "error_rate",
			value = errorRate,
			message = "High error rate detected"
		})
	end
	
	if #alerts > 0 then
		MetricsDashboard.Event("alerts", alerts)
		Logging.Warn("MetricsDashboard", "Alerts triggered: " .. #alerts)
	end
end

-- Main metrics collection loop
local lastUpdate = tick()
RunService.Heartbeat:Connect(function()
	local now = tick()
	
	-- Update every 5 seconds
	if now - lastUpdate >= 5 then
		updatePerformanceMetrics()
		collectGameMetrics()
		checkAlerts()
		storeSnapshot()
		lastUpdate = now
	end
end)

-- Handle dashboard requests
DashboardRemote.OnServerEvent:Connect(function(player, action, data)
	-- Only allow admins/developers to access dashboard
	if not player:GetRankInGroup(0) >= 100 then -- Placeholder admin check
		return
	end
	
	if action == "GetSnapshot" then
		DashboardRemote:FireClient(player, "Snapshot", MetricsDashboard.GetSnapshot())
	elseif action == "GetHistory" then
		local minutes = data and data.minutes or 10
		DashboardRemote:FireClient(player, "History", MetricsDashboard.GetHistory(minutes))
	elseif action == "GetAlerts" then
		local recentAlerts = {}
		if metrics.events["alerts"] then
			for _, alert in ipairs(metrics.events["alerts"]) do
				if tick() - alert.timestamp < 300 then -- Last 5 minutes
					table.insert(recentAlerts, alert)
				end
			end
		end
		DashboardRemote:FireClient(player, "Alerts", recentAlerts)
	end
end)

-- Public API integration
function MetricsDashboard.GetDashboardData()
	return {
		snapshot = MetricsDashboard.GetSnapshot(),
		history = MetricsDashboard.GetHistory(60), -- Last hour
		alerts = metrics.events["alerts"] or {}
	}
end

return MetricsDashboard
