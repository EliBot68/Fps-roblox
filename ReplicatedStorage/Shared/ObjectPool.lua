--[[
	ObjectPool.lua
	Enterprise-grade object pooling system for bullets, effects, and UI elements
	
	Usage:
		local pool = ObjectPool.new("Part", function() return Instance.new("Part") end)
		local obj = pool:Get()
		-- Use object...
		pool:Return(obj)
]]

local ObjectPool = {}

-- Pool configuration
local DEFAULT_POOL_SIZE = 50
local MAX_POOL_SIZE = 200
local CLEANUP_INTERVAL = 60 -- Clean up every 60 seconds

-- Global pools registry
local activePools = {}

export type Pool = {
	objects: {any},
	inUse: {[any]: boolean},
	createFunction: () -> any,
	resetFunction: ((any) -> ())?,
	maxSize: number,
	totalCreated: number,
	totalReused: number,
	lastCleanup: number
}

-- Create a new object pool
function ObjectPool.new(poolName: string, createFunc: () -> any, resetFunc: ((any) -> ())?): Pool
	local pool = {
		objects = {},
		inUse = {},
		createFunction = createFunc,
		resetFunction = resetFunc,
		maxSize = DEFAULT_POOL_SIZE,
		totalCreated = 0,
		totalReused = 0,
		lastCleanup = os.clock()
	}
	
	-- Pre-populate pool
	for i = 1, math.min(10, DEFAULT_POOL_SIZE) do
		local obj = createFunc()
		table.insert(pool.objects, obj)
	end
	
	activePools[poolName] = pool
	return pool
end

-- Get an object from the pool
function ObjectPool.Get(pool: Pool): any
	local obj
	
	-- Try to reuse from pool first
	if #pool.objects > 0 then
		obj = table.remove(pool.objects)
		pool.totalReused = pool.totalReused + 1
	else
		-- Create new object if pool is empty
		obj = pool.createFunction()
		pool.totalCreated = pool.totalCreated + 1
	end
	
	-- Mark as in use
	pool.inUse[obj] = true
	return obj
end

-- Return an object to the pool
function ObjectPool.Return(pool: Pool, obj: any): boolean
	-- Validate object is from this pool
	if not pool.inUse[obj] then
		warn("[ObjectPool] Attempted to return object not from this pool")
		return false
	end
	
	-- Remove from in-use tracking
	pool.inUse[obj] = nil
	
	-- Reset object if reset function provided
	if pool.resetFunction then
		local success, err = pcall(pool.resetFunction, obj)
		if not success then
			warn("[ObjectPool] Reset function failed:", err)
			-- Don't return to pool if reset failed
			obj:Destroy()
			return false
		end
	end
	
	-- Return to pool if not full
	if #pool.objects < pool.maxSize then
		table.insert(pool.objects, obj)
		return true
	else
		-- Pool is full, destroy excess object
		obj:Destroy()
		return false
	end
end

-- Force return all objects (for cleanup)
function ObjectPool.ReturnAll(pool: Pool): number
	local returned = 0
	
	for obj, _ in pairs(pool.inUse) do
		if ObjectPool.Return(pool, obj) then
			returned = returned + 1
		end
	end
	
	return returned
end

-- Get pool statistics
function ObjectPool.GetStats(pool: Pool): {available: number, inUse: number, totalCreated: number, totalReused: number, efficiency: number}
	local inUseCount = 0
	for _, _ in pairs(pool.inUse) do
		inUseCount = inUseCount + 1
	end
	
	local efficiency = 0
	if pool.totalCreated > 0 then
		efficiency = pool.totalReused / (pool.totalCreated + pool.totalReused)
	end
	
	return {
		available = #pool.objects,
		inUse = inUseCount,
		totalCreated = pool.totalCreated,
		totalReused = pool.totalReused,
		efficiency = math.floor(efficiency * 100) / 100
	}
end

-- Clean up unused objects in pool
function ObjectPool.Cleanup(pool: Pool): number
	local currentTime = os.clock()
	if currentTime - pool.lastCleanup < CLEANUP_INTERVAL then
		return 0
	end
	
	local destroyed = 0
	local targetSize = math.max(10, math.floor(pool.maxSize * 0.3))
	
	-- Keep only target number of objects
	while #pool.objects > targetSize do
		local obj = table.remove(pool.objects)
		obj:Destroy()
		destroyed = destroyed + 1
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

-- Destroy a pool completely
function ObjectPool.DestroyPool(poolName: string): boolean
	local pool = activePools[poolName]
	if not pool then return false end
	
	-- Return all in-use objects
	ObjectPool.ReturnAll(pool)
	
	-- Destroy all pooled objects
	for _, obj in ipairs(pool.objects) do
		obj:Destroy()
	end
	
	-- Remove from registry
	activePools[poolName] = nil
	return true
end

return ObjectPool
