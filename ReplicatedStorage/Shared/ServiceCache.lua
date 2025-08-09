--[[
	ServiceCache.lua
	Enterprise service and instance caching to eliminate redundant WaitForChild calls
	
	Caches frequently accessed services and instances to improve performance
	and reduce the overhead of repeated WaitForChild operations.
]]

local ServiceCache = {}

-- Service cache
local services = {}
local instances = {}
local instancePromises = {} -- Track pending WaitForChild calls

-- Common services preloaded
local commonServices = {
	"Players", "RunService", "ReplicatedStorage", "Debris", 
	"TweenService", "SoundService", "Lighting", "UserInputService",
	"ContentProvider", "DataStoreService", "HttpService"
}

-- Initialize service cache
function ServiceCache.Initialize()
	-- Preload common services
	for _, serviceName in ipairs(commonServices) do
		local success, service = pcall(game.GetService, game, serviceName)
		if success then
			services[serviceName] = service
		else
			warn("[ServiceCache] Failed to preload service:", serviceName)
		end
	end
	
	print("[ServiceCache] ✓ Preloaded", #commonServices, "common services")
end

-- Get a service (cached)
function ServiceCache.GetService(serviceName: string): Instance?
	if not services[serviceName] then
		local success, service = pcall(game.GetService, game, serviceName)
		if success then
			services[serviceName] = service
		else
			warn("[ServiceCache] Failed to get service:", serviceName)
			return nil
		end
	end
	
	return services[serviceName]
end

-- Get an instance with caching (replaces WaitForChild in hot paths)
function ServiceCache.GetInstance(parent: Instance, name: string, timeout: number?): Instance?
	timeout = timeout or 5
	
	-- Create cache key
	local cacheKey = tostring(parent) .. "." .. name
	
	-- Return cached instance if available
	if instances[cacheKey] then
		return instances[cacheKey]
	end
	
	-- Check if there's already a pending promise for this instance
	if instancePromises[cacheKey] then
		-- Wait for existing promise to resolve
		local startTime = tick()
		while instancePromises[cacheKey] and (tick() - startTime) < timeout do
			task.wait(0.1)
		end
		return instances[cacheKey]
	end
	
	-- Start new promise
	instancePromises[cacheKey] = true
	
	-- Try to get instance immediately first
	local instance = parent:FindFirstChild(name)
	if instance then
		instances[cacheKey] = instance
		instancePromises[cacheKey] = nil
		return instance
	end
	
	-- Wait for instance with timeout
	local startTime = tick()
	while not instance and (tick() - startTime) < timeout do
		instance = parent:FindFirstChild(name)
		if not instance then
			task.wait(0.1)
		end
	end
	
	-- Cache result (even if nil to avoid repeated attempts)
	if instance then
		instances[cacheKey] = instance
	end
	
	instancePromises[cacheKey] = nil
	return instance
end

-- Preload common ReplicatedStorage paths
function ServiceCache.PreloadCommonPaths()
	local replicatedStorage = ServiceCache.GetService("ReplicatedStorage")
	if not replicatedStorage then return end
	
	-- Common paths to preload
	local commonPaths = {
		{replicatedStorage, "Shared"},
		{replicatedStorage, "WeaponSystem"},
		{replicatedStorage, "RemoteEvents"},
		{replicatedStorage, "WeaponSystem.Modules"},
		{replicatedStorage, "Shared.RateLimiter"},
		{replicatedStorage, "Shared.ObjectPool"},
		{replicatedStorage, "Shared.NetworkBatcher"},
		{replicatedStorage, "Shared.Scheduler"}
	}
	
	for _, pathData in ipairs(commonPaths) do
		local parent, childName = pathData[1], pathData[2]
		
		-- Handle nested paths (e.g., "WeaponSystem.Modules")
		if childName:find("%.") then
			local parts = childName:split(".")
			local currentParent = parent
			
			for _, part in ipairs(parts) do
				currentParent = ServiceCache.GetInstance(currentParent, part, 2)
				if not currentParent then break end
			end
		else
			ServiceCache.GetInstance(parent, childName, 2)
		end
	end
	
	print("[ServiceCache] ✓ Preloaded common ReplicatedStorage paths")
end

-- Get ReplicatedStorage child (most common use case)
function ServiceCache.GetShared(moduleName: string): Instance?
	local replicatedStorage = ServiceCache.GetService("ReplicatedStorage")
	if not replicatedStorage then return nil end
	
	local shared = ServiceCache.GetInstance(replicatedStorage, "Shared")
	if not shared then return nil end
	
	return ServiceCache.GetInstance(shared, moduleName)
end

-- Get WeaponSystem module
function ServiceCache.GetWeaponModule(moduleName: string): Instance?
	local replicatedStorage = ServiceCache.GetService("ReplicatedStorage")
	if not replicatedStorage then return nil end
	
	local weaponSystem = ServiceCache.GetInstance(replicatedStorage, "WeaponSystem")
	if not weaponSystem then return nil end
	
	local modules = ServiceCache.GetInstance(weaponSystem, "Modules")
	if not modules then return nil end
	
	return ServiceCache.GetInstance(modules, moduleName)
end

-- Clear cache (for testing/debugging)
function ServiceCache.ClearCache()
	instances = {}
	instancePromises = {}
	-- Don't clear services as they don't change
	print("[ServiceCache] ✓ Instance cache cleared")
end

-- Get cache statistics
function ServiceCache.GetStats(): {cachedServices: number, cachedInstances: number, pendingPromises: number}
	local serviceCount = 0
	for _ in pairs(services) do serviceCount = serviceCount + 1 end
	
	local instanceCount = 0
	for _ in pairs(instances) do instanceCount = instanceCount + 1 end
	
	local promiseCount = 0
	for _ in pairs(instancePromises) do promiseCount = promiseCount + 1 end
	
	return {
		cachedServices = serviceCount,
		cachedInstances = instanceCount,
		pendingPromises = promiseCount
	}
end

-- Invalidate specific cache entry (when instance might have been destroyed)
function ServiceCache.InvalidateInstance(parent: Instance, name: string)
	local cacheKey = tostring(parent) .. "." .. name
	instances[cacheKey] = nil
	print("[ServiceCache] ✓ Invalidated cache for:", cacheKey)
end

-- Batch invalidation for parent destruction
function ServiceCache.InvalidateParent(parent: Instance)
	local parentKey = tostring(parent)
	local invalidatedCount = 0
	
	for cacheKey in pairs(instances) do
		if cacheKey:sub(1, #parentKey) == parentKey then
			instances[cacheKey] = nil
			invalidatedCount = invalidatedCount + 1
		end
	end
	
	if invalidatedCount > 0 then
		print("[ServiceCache] ✓ Invalidated", invalidatedCount, "cache entries for parent")
	end
end

-- Auto-initialize on require
ServiceCache.Initialize()

-- Preload common paths after a short delay
task.spawn(function()
	task.wait(1) -- Wait for game to load
	ServiceCache.PreloadCommonPaths()
end)

return ServiceCache
