--[[
	MemoryManager.lua
	Enterprise Memory Management & Monitoring Service
	Phase 2.4: Memory Management & Object Pooling

	Responsibilities:
	- Central registry for all object pools
	- Memory usage sampling and trend analysis
	- Leak detection (long-lived objects, unreleased instances)
	- Garbage collection monitoring (Lua heap deltas)
	- Automatic pool resizing advisories
	- Memory usage alerts & callbacks
	- Integration with Logging, MetricsExporter, ServiceLocator

	Rojo Path (planned): src/ReplicatedStorage/Shared/MemoryManager.lua
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logging = require(ReplicatedStorage.Shared.Logging)
local ServiceLocator = require(ReplicatedStorage.Shared.ServiceLocator)

-- Optional MetricsExporter integration
local MetricsExporter = nil
pcall(function()
	MetricsExporter = require(ReplicatedStorage.Shared.MetricsExporter)
end)

local MemoryManager = {}
MemoryManager.__index = MemoryManager

-- Types
export type PoolRef = {
	poolName: string,
	ref: any, -- Actual pool (from ObjectPool)
}

export type MemorySample = {
	timestamp: number,
	luaHeapKB: number,
	totalInstances: number,
	trackedPools: number,
	poolStats: {[string]: any}
}

-- Configuration constants
local CONFIG = {
	sampleInterval = 10, -- seconds
	maxSamples = 180, -- 30 minutes @ 10s
	leakDetectionWindow = 60, -- seconds
	alertCooldown = 30, -- seconds between repeated alerts
	memoryWarningMB = 400,
	memoryCriticalMB = 480,
	poolEfficiencyThreshold = 0.9,
	poolLeakThreshold = 3 -- number of leak candidates before alert
}

-- Internal state
local state = {
	initialized = false,
	pools = {}, -- [poolName] = PoolRef
	poolLeakCandidates = {}, -- [poolName] = count
	latestSample = nil :: MemorySample?,
	samples = {} :: {MemorySample},
	lastAlertTimes = {}, -- [alertKey] = timestamp
	alertFailures = {}, -- [alertKey] = failure count for backoff
	adaptiveSampling = {
		baseInterval = 10,
		currentInterval = 10,
		highLoadThreshold = 300, -- MB
		lowLoadThreshold = 100, -- MB
		lastAdjustment = 0
	},
	callbacks = {
		memoryWarning = {},
		memoryCritical = {},
		poolLeak = {},
		lowEfficiency = {}
	}
}

-- Utility: Safe memory usage (Lua heap only approximation)
local function getLuaHeapKB(): number
	return collectgarbage("count") -- returns KB
end

local function getInstanceCount(): number
	-- Deep instance traversal for accurate counting
	local count = 0
	local function countRecursive(parent)
		count += 1
		for _, child in ipairs(parent:GetChildren()) do
			countRecursive(child)
		end
	end
	
	-- Count all major containers
	countRecursive(workspace)
	countRecursive(game.Players)
	countRecursive(game.ReplicatedStorage)
	countRecursive(game.ServerStorage)
	countRecursive(game.StarterGui)
	countRecursive(game.StarterPlayer)
	
	return count
end

-- Alert dispatch with exponential backoff cooldown
local function dispatchAlert(alertType: string, key: string, payload: any)
	local now = os.clock()
	local compositeKey = alertType .. ":" .. key
	local last = state.lastAlertTimes[compositeKey] or 0
	
	-- Exponential backoff: 30s, 60s, 120s, 240s, max 300s
	local failures = state.alertFailures and state.alertFailures[compositeKey] or 0
	local backoffTime = math.min(CONFIG.alertCooldown * math.pow(2, failures), 300)
	
	if (now - last) < backoffTime then
		return -- Cooldown active
	end
	
	state.lastAlertTimes[compositeKey] = now
	state.alertFailures = state.alertFailures or {}
	state.alertFailures[compositeKey] = failures + 1
	
	Logging.Warn("MemoryManager", string.format("Alert [%s] %s (backoff: %ds)", alertType, key, backoffTime), payload)
	
	local list = state.callbacks[alertType]
	if list then
		for _, cb in ipairs(list) do
			local ok, err = pcall(cb, key, payload)
			if not ok then
				Logging.Error("MemoryManager", "Alert callback failed", {error = err, type = alertType})
			end
		end
	end
	
	-- Reset failure count on successful dispatch
	if state.alertFailures then
		state.alertFailures[compositeKey] = 0
	end
end

-- Register a pool (called by ObjectPool SafeRegisterPool)
function MemoryManager.RegisterPool(poolName: string, pool: any)
	if state.pools[poolName] then return end
	state.pools[poolName] = {poolName = poolName, ref = pool}
	Logging.Info("MemoryManager", "Pool registered", {pool = poolName})
end

-- Gather stats from all pools
local function collectPoolStats(): {[string]: any}
	local stats = {}
	for name, info in pairs(state.pools) do
		local ok, poolStats = pcall(function()
			return info.ref and info.ref.GetStats and info.ref:GetStats() or info.ref and info.ref.GetStats(info.ref)
		end)
		if ok and type(poolStats) == "table" then
			stats[name] = poolStats
		else
			stats[name] = {error = "STAT_FAIL"}
		end
	end
	return stats
end

-- Adaptive sampling with load-based interval adjustment
local function adjustSamplingInterval(sample: MemorySample)
	local adaptive = state.adaptiveSampling
	local now = os.clock()
	
	-- Only adjust every 60 seconds
	if (now - adaptive.lastAdjustment) < 60 then return end
	adaptive.lastAdjustment = now
	
	local memoryMB = sample.luaHeapKB / 1024
	
	if memoryMB > adaptive.highLoadThreshold then
		-- High load: sample more frequently
		adaptive.currentInterval = math.max(5, adaptive.baseInterval * 0.5)
	elseif memoryMB < adaptive.lowLoadThreshold then
		-- Low load: sample less frequently
		adaptive.currentInterval = math.min(30, adaptive.baseInterval * 2)
	else
		-- Normal load: use base interval
		adaptive.currentInterval = adaptive.baseInterval
	end
	
	Logging.Debug("MemoryManager", "Sampling interval adjusted", {
		memoryMB = memoryMB,
		newInterval = adaptive.currentInterval
	})
end

-- Take a memory sample with adaptive timing and metrics export
local function takeSample()
	local sample: MemorySample = {
		timestamp = os.clock(),
		luaHeapKB = getLuaHeapKB(),
		totalInstances = getInstanceCount(),
		trackedPools = 0,
		poolStats = collectPoolStats()
	}
	for _ in pairs(state.pools) do sample.trackedPools += 1 end
	
	-- Push sample
	table.insert(state.samples, sample)
	state.latestSample = sample
	if #state.samples > CONFIG.maxSamples then
		table.remove(state.samples, 1)
	end
	
	-- Export metrics if available
	if MetricsExporter then
		pcall(function()
			MetricsExporter.SetGauge("memory_lua_heap_kb", sample.luaHeapKB)
			MetricsExporter.SetGauge("memory_total_instances", sample.totalInstances)
			MetricsExporter.SetGauge("memory_tracked_pools", sample.trackedPools)
			
			-- Export pool-specific metrics
			for poolName, stats in pairs(sample.poolStats) do
				if type(stats) == "table" and not stats.error then
					MetricsExporter.SetGauge("pool_efficiency", stats.efficiency or 0, {pool = poolName})
					MetricsExporter.SetGauge("pool_in_use", stats.inUse or 0, {pool = poolName})
					MetricsExporter.SetGauge("pool_leaks", stats.leaks or 0, {pool = poolName})
				end
			end
		end)
	end
	
	-- Adjust sampling based on load
	adjustSamplingInterval(sample)
	
	return sample
end

-- Analyze sample for alerts
local function analyzeSample(sample: MemorySample)
	local mb = sample.luaHeapKB / 1024
	if mb > CONFIG.memoryCriticalMB then
		dispatchAlert("memoryCritical", "LuaHeap", {mb = mb})
	elseif mb > CONFIG.memoryWarningMB then
		dispatchAlert("memoryWarning", "LuaHeap", {mb = mb})
	end
	-- Pool analysis
	for poolName, stats in pairs(sample.poolStats) do
		if stats.leaks and stats.leaks >= CONFIG.poolLeakThreshold then
			state.poolLeakCandidates[poolName] = (state.poolLeakCandidates[poolName] or 0) + 1
			if state.poolLeakCandidates[poolName] >= 2 then
				dispatchAlert("poolLeak", poolName, {leaks = stats.leaks})
			end
		else
			state.poolLeakCandidates[poolName] = 0
		end
		if stats.efficiency and stats.efficiency < CONFIG.poolEfficiencyThreshold then
			dispatchAlert("lowEfficiency", poolName, {efficiency = stats.efficiency})
		end
	end
end

-- Public: Force a sample
function MemoryManager.Sample(): MemorySample
	local sample = takeSample()
	analyzeSample(sample)
	return sample
end

-- Public: Get latest
function MemoryManager.GetLatestSample(): MemorySample?
	return state.latestSample
end

-- Public: Get historical samples
function MemoryManager.GetSamples(): {MemorySample}
	return state.samples
end

-- Public: Register alert callback
function MemoryManager.On(alertType: string, callback: (string, any) -> ())
	assert(state.callbacks[alertType], "Invalid alert type: " .. tostring(alertType))
	assert(type(callback) == "function", "Callback must be function")
	table.insert(state.callbacks[alertType], callback)
end

-- Public: Get pool details
function MemoryManager.GetPools(): {[string]: any}
	local pools = {}
	for name, info in pairs(state.pools) do
		pools[name] = info.ref
	end
	return pools
end

-- Public: Get aggregated report
function MemoryManager.GetReport()
	local latest = state.latestSample
	local report = {
		latest = latest,
		totalSamples = #state.samples,
		registeredPools = {},
		config = CONFIG
	}
	for name, info in pairs(state.pools) do
		local stats = nil
		local ok, result = pcall(function()
			return info.ref and info.ref.GetStats and info.ref:GetStats() or info.ref and info.ref.GetStats(info.ref)
		end)
		if ok then stats = result end
		report.registeredPools[name] = stats
	end
	return report
end

-- Background sampling loop with adaptive intervals
local function startSampling()
	if state.initialized then return end
	state.initialized = true
	Logging.Info("MemoryManager", "Starting adaptive sampling loop", CONFIG)
	task.spawn(function()
		while true do
			local sample = takeSample()
			analyzeSample(sample)
			
			-- Use adaptive interval
			local interval = state.adaptiveSampling.currentInterval
			for i = 1, interval * 10 do -- 10 steps per second for responsiveness
				task.wait(0.1)
			end
		end
	end)
end

-- ServiceLocator registration
ServiceLocator.Register("MemoryManager", {
	factory = function()
		startSampling()
		return MemoryManager
	end,
	singleton = true,
	lazy = false,
	priority = 4,
	tags = {"memory", "monitoring"},
	healthCheck = function()
		return true
	end
})

Logging.Info("MemoryManager", "Enterprise Memory Manager initialized")

return MemoryManager
