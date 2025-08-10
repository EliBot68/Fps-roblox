--[[
	ObjectPool.lua
	Enterprise-grade object pooling system for bullets, effects, and UI elements
	
	Usage:
		local pool = ObjectPool.new("Part", function() return Instance.new("Part") end)
		local obj = pool:Get()
		-- Use object...
		pool:Return(obj)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logging = require(ReplicatedStorage.Shared.Logging)

local ObjectPool = {}

-- Pool configuration
local DEFAULT_POOL_SIZE = 50
local MAX_POOL_SIZE = 200
local CLEANUP_INTERVAL = 60 -- Clean up every 60 seconds

-- Add enhanced configuration constants
local MIN_POOL_SIZE = 10
local RESIZE_CHECK_INTERVAL = 15 -- seconds
local LEAK_THRESHOLD = 30 -- seconds an object can stay checked out before flagged
local RESIZE_GROW_FACTOR = 1.5
local RESIZE_SHRINK_FACTOR = 0.5

-- Global pools registry
local activePools = {}

export type Pool = {
	objects: {any},
	inUse: {[any]: boolean},
	inUseTimestamps: {[any]: number},
	createFunction: () -> any,
	resetFunction: ((any) -> ())?,
	maxSize: number,
	minSize: number,
	totalCreated: number,
	totalReused: number,
	peakInUse: number,
	poolName: string,
	autoResize: boolean,
	lastCleanup: number,
	lastResizeCheck: number,
	leakThreshold: number
}

-- Forward declaration for MemoryManager integration (optional)
local memoryManagerSafe

-- Utility: safe call into MemoryManager if present
local function SafeRegisterPool(poolName: string, pool: Pool)
	if not memoryManagerSafe then
		local ok, mm = pcall(function()
			return require(game:GetService("ReplicatedStorage").Shared.MemoryManager)
		end)
		if ok and type(mm) == "table" then
			memoryManagerSafe = mm
		else
			memoryManagerSafe = false
		end
	end
	if memoryManagerSafe and memoryManagerSafe.RegisterPool then
		pcall(function()
			memoryManagerSafe.RegisterPool(poolName, pool)
		end)
	end
end

-- Create a new object pool (enhanced)
function ObjectPool.new(poolName: string, createFunc: () -> any, resetFunc: ((any) -> ())?, config: {[string]: any}?): Pool
	assert(type(poolName) == "string" and poolName ~= "", "Pool name required")
	local cfg = config or {}
	local initialMax = cfg.maxSize or MAX_POOL_SIZE
	local pool: Pool = {
		objects = {},
		inUse = {},
		inUseTimestamps = {},
		createFunction = createFunc,
		resetFunction = resetFunc,
		maxSize = initialMax,
		minSize = cfg.minSize or MIN_POOL_SIZE,
		totalCreated = 0,
		totalReused = 0,
		peakInUse = 0,
		poolName = poolName,
		autoResize = if cfg.autoResize == nil then true else cfg.autoResize,
		lastCleanup = os.clock(),
		lastResizeCheck = os.clock(),
		leakThreshold = cfg.leakThreshold or LEAK_THRESHOLD
	}
	-- Pre-populate baseline
	local prepopulate = math.min(cfg.prepopulate or 10, pool.maxSize)
	for i = 1, prepopulate do
		local ok, obj = pcall(createFunc)
		if ok and obj then
			pool.totalCreated += 1
			pool.objects[i] = obj
		end
	end
	activePools[poolName] = pool
	SafeRegisterPool(poolName, pool)
	return pool
end

-- Get an object (enhanced tracking)
function ObjectPool.Get(pool: Pool): any
	local obj
	if #pool.objects > 0 then
		obj = table.remove(pool.objects)
		pool.totalReused += 1
	else
		if (pool.totalCreated - pool.totalReused) >= pool.maxSize then
			-- Hard cap reached; create anyway but warn (temporary overflow)
			warn(string.format("[ObjectPool] Pool '%s' at max size (%d). Creating overflow instance.", pool.poolName, pool.maxSize))
		end
		local ok, created = pcall(pool.createFunction)
		if ok and created then
			obj = created
			pool.totalCreated += 1
		else
			error("[ObjectPool] Failed to create pooled object: " .. tostring(created))
		end
	end
	pool.inUse[obj] = true
	pool.inUseTimestamps[obj] = os.clock()
	-- Update peak usage
	local currentInUse = 0
	for _ in pairs(pool.inUse) do currentInUse += 1 end
	if currentInUse > pool.peakInUse then
		pool.peakInUse = currentInUse
	end
	return obj
end

-- Return object (unchanged parts retained)
function ObjectPool.Return(pool: Pool, obj: any): boolean
	if not pool.inUse[obj] then
		warn("[ObjectPool] Attempted to return object not from this pool", pool.poolName)
		return false
	end
	pool.inUse[obj] = nil
	pool.inUseTimestamps[obj] = nil
	if pool.resetFunction then
		local ok, err = pcall(pool.resetFunction, obj)
		if not ok then
			warn("[ObjectPool] Reset failed", err)
			if obj.Destroy then pcall(function() obj:Destroy() end) end
			return false
		end
	end
	if #pool.objects < pool.maxSize then
		table.insert(pool.objects, obj)
		return true
	else
		if obj.Destroy then pcall(function() obj:Destroy() end) end
		return false
	end
end

-- Efficiency & leak aware stats
function ObjectPool.GetStats(pool: Pool): {available: number, inUse: number, totalCreated: number, totalReused: number, efficiency: number, peakInUse: number, maxSize: number, leaks: number}
	local inUseCount = 0
	local now = os.clock()
	local leaks = 0
	for o, _ in pairs(pool.inUse) do
		inUseCount += 1
		local t = pool.inUseTimestamps[o]
		if t and (now - t) > pool.leakThreshold then
			leaks += 1
		end
	end
	local efficiency = 0
	if (pool.totalCreated + pool.totalReused) > 0 then
		efficiency = pool.totalReused / (pool.totalCreated + pool.totalReused)
	end
	return {
		available = #pool.objects,
		inUse = inUseCount,
		totalCreated = pool.totalCreated,
		totalReused = pool.totalReused,
		efficiency = math.floor(efficiency * 10000) / 10000,
		peakInUse = pool.peakInUse,
		maxSize = pool.maxSize,
		leaks = leaks
	}
end

-- Auto-resize logic with configurable parameters
local function EvaluateResize(pool: Pool)
	if not pool.autoResize then return end
	local now = os.clock()
	if (now - pool.lastResizeCheck) < RESIZE_CHECK_INTERVAL then return end
	pool.lastResizeCheck = now
	
	local stats = ObjectPool.GetStats(pool)
	local oldMaxSize = pool.maxSize
	
	-- Grow: if peak usage near capacity
	if stats.peakInUse >= math.floor(pool.maxSize * 0.9) and pool.maxSize < MAX_POOL_SIZE then
		pool.maxSize = math.min(MAX_POOL_SIZE, math.floor(pool.maxSize * RESIZE_GROW_FACTOR))
		Logging.Info("ObjectPool", string.format("Auto-grow '%s' %d -> %d (peak: %d)", 
			pool.poolName, oldMaxSize, pool.maxSize, stats.peakInUse))
		-- Don't reset peak immediately - use sliding window
		pool.peakInUse = math.floor(stats.peakInUse * 0.8)
	end
	
	-- Shrink: low utilization & many available
	local utilization = stats.inUse / math.max(1, pool.maxSize)
	if utilization < 0.25 and #pool.objects > (pool.maxSize * 0.75) and pool.maxSize > pool.minSize then
		pool.maxSize = math.max(pool.minSize, math.floor(pool.maxSize * RESIZE_SHRINK_FACTOR))
		Logging.Info("ObjectPool", string.format("Auto-shrink '%s' %d -> %d (util: %.2f)", 
			pool.poolName, oldMaxSize, pool.maxSize, utilization))
	end
end

-- Clean up unused objects in pool
function ObjectPool.Cleanup(pool: Pool): number
	EvaluateResize(pool)
	local currentTime = os.clock()
	if currentTime - pool.lastCleanup < CLEANUP_INTERVAL then
		return 0
	end
	local destroyed = 0
	local targetSize = math.max(pool.minSize, math.floor(pool.maxSize * 0.3))
	
	-- Keep only target number of objects
	while #pool.objects > targetSize do
		local obj = table.remove(pool.objects)
		if obj and obj.Destroy then pcall(function() obj:Destroy() end) end
		destroyed += 1
	end
	
	pool.lastCleanup = currentTime
	return destroyed
end

-- Global cleanup for all pools
function ObjectPool.CleanupAll(): {[string]: number}
	local results = {}
	
	for poolName, pool in pairs(activePools) do
		results[poolName] = ObjectPool.Cleanup(pool)
	end
	
	return results
end

-- Get stats for all pools
function ObjectPool.GetAllStats(): {[string]: any}
	local stats = {}
	
	for poolName, pool in pairs(activePools) do
		stats[poolName] = ObjectPool.GetStats(pool)
	end
	
	return stats
end

-- Force return all objects (for cleanup)
function ObjectPool.ReturnAll(pool: Pool): number
	local returned = 0
	local toReturn = {}
	
	-- Collect all in-use objects first (avoid iterator invalidation)
	for obj, _ in pairs(pool.inUse) do
		table.insert(toReturn, obj)
	end
	
	-- Return each object
	for _, obj in ipairs(toReturn) do
		if ObjectPool.Return(pool, obj) then
			returned = returned + 1
		end
	end
	
	return returned
end

-- Destroy a pool completely
function ObjectPool.DestroyPool(poolName: string): boolean
	local pool = activePools[poolName]
	if not pool then return false end
	
	-- Return all in-use objects
	ObjectPool.ReturnAll(pool)
	
	-- Destroy all pooled objects
	for _, obj in ipairs(pool.objects) do
		if obj and obj.Destroy then
			pcall(function() obj:Destroy() end)
		end
	end
	
	-- Remove from registry
	activePools[poolName] = nil
	return true
end

return ObjectPool
