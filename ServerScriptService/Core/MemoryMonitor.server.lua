--[[
	MemoryMonitor.server.lua
	Server-side orchestration for Memory & Pool Monitoring
	Phase 2.4 Implementation Component

	Responsibilities:
	- Periodically log memory status summaries
	- Trigger proactive pool cleanups & resizing evaluations
	- Provide admin command hooks (placeholder)
	- Expose runtime diagnostics via a simple API table
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ServiceLocator = require(ReplicatedStorage.Shared.ServiceLocator)
local Logging = require(ReplicatedStorage.Shared.Logging)

local MemoryMonitor = {}
MemoryMonitor.__index = MemoryMonitor

local UPDATE_INTERVAL = 30 -- seconds
local CLEANUP_INTERVAL = 120 -- seconds
local lastCleanup = 0

-- Authentication for admin commands
local ADMIN_USERS = {
	[123456789] = true, -- Replace with actual admin UserIds
	[987654321] = true,
}

-- Lazy service references
local memoryManager
local objectPoolModule

local function resolveServices()
	if not memoryManager then
		local ok, svc = pcall(function()
			return ServiceLocator.GetService("MemoryManager")
		end)
		if ok then memoryManager = svc end
	end
	if not objectPoolModule then
		local ok2, pool = pcall(function()
			return require(ReplicatedStorage.Shared.ObjectPool)
		end)
		if ok2 then objectPoolModule = pool end
	end
end

-- Admin command interface with authentication
function MemoryMonitor.ExecuteCommand(player: Player?, command: string, args: {string}?): any
	-- Authenticate admin user
	if player and not ADMIN_USERS[player.UserId] then
		return {success = false, error = "Unauthorized"}
	end
	
	resolveServices()
	args = args or {}
	
	if command == "cleanup" then
		if objectPoolModule and objectPoolModule.CleanupAll then
			local results = objectPoolModule.CleanupAll()
			return {success = true, data = results}
		end
		return {success = false, error = "ObjectPool not available"}
		
	elseif command == "sample" then
		if memoryManager and memoryManager.Sample then
			local sample = memoryManager.Sample()
			return {success = true, data = sample}
		end
		return {success = false, error = "MemoryManager not available"}
		
	elseif command == "report" then
		local diagnostics = MemoryMonitor.GetDiagnostics()
		return {success = true, data = diagnostics}
		
	elseif command == "pools" then
		if memoryManager and memoryManager.GetPools then
			local pools = memoryManager.GetPools()
			local poolStats = {}
			for name, pool in pairs(pools) do
				if pool.GetStats then
					poolStats[name] = pool:GetStats()
				end
			end
			return {success = true, data = poolStats}
		end
		return {success = false, error = "MemoryManager not available"}
		
	elseif command == "gc" then
		-- Force garbage collection
		collectgarbage("collect")
		local memAfter = collectgarbage("count")
		return {success = true, data = {luaHeapKB = memAfter}}
		
	else
		return {success = false, error = "Unknown command: " .. command}
	end
end

-- Periodic maintenance
local function maintenanceLoop()
	resolveServices()
	if not memoryManager then return end
	local sample = memoryManager.Sample()
	if sample and sample.poolStats then
		Logging.Debug("MemoryMonitor", "Memory sample", {
			luaHeapKB = sample.luaHeapKB,
			trackedPools = sample.trackedPools
		})
	end
	-- Cleanup pools occasionally
	if objectPoolModule and (os.clock() - lastCleanup) > CLEANUP_INTERVAL then
		lastCleanup = os.clock()
		local stats = objectPoolModule.CleanupAll and objectPoolModule.CleanupAll()
		Logging.Info("MemoryMonitor", "Performed global pool cleanup", {destroyed = stats})
	end
end

-- Diagnostics API
function MemoryMonitor.GetDiagnostics()
	resolveServices()
	local report
	if memoryManager then
		local ok, r = pcall(function() return memoryManager.GetReport() end)
		if ok then report = r end
	end
	return {
		memoryReport = report,
		timestamp = os.clock()
	}
end

-- Initialize loop
local function init()
	Logging.Info("MemoryMonitor", "Initializing memory monitoring loop")
	task.spawn(function()
		while true do
			maintenanceLoop()
			for _ = 1, UPDATE_INTERVAL do
				RunService.Heartbeat:Wait()
			end
		end
	end)
end

init()

-- ServiceLocator registration (optional facade)
ServiceLocator.Register("MemoryMonitor", {
	factory = function()
		return MemoryMonitor
	end,
	singleton = true,
	lazy = true,
	priority = 5,
	tags = {"memory", "monitoring"}
})

return MemoryMonitor
