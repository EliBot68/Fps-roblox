--[[
	Scheduler.lua
	Enterprise task scheduling system to consolidate Heartbeat listeners
	
	Instead of multiple scripts each connecting to Heartbeat, this system
	batches tasks into different frequency tiers for optimal performance.
	
	Usage:
		Scheduler.ScheduleTask("PlayerTracking", function() ... end, 10) -- 10Hz
		Scheduler.ScheduleTask("UIUpdates", function() ... end, 2)       -- 2Hz
]]

local RunService = game:GetService("RunService")

local Scheduler = {}

-- Task frequency tiers
local TASK_TIERS = {
	HIGH_FREQ = 60,    -- 60Hz - Critical real-time tasks (weapon firing, movement)
	MEDIUM_FREQ = 10,  -- 10Hz - Important but not critical (UI updates, animations)
	LOW_FREQ = 2,      -- 2Hz - Background tasks (statistics, cleanup)
	VERY_LOW_FREQ = 0.2 -- Every 5 seconds - Occasional tasks (autosave, metrics)
}

-- Task storage by frequency
local tasksByFreq = {
	[60] = {},
	[10] = {},
	[2] = {},
	[0.2] = {}
}

-- Frame counters for each tier
local frameCounters = {
	[60] = 0,
	[10] = 0, 
	[2] = 0,
	[0.2] = 0
}

-- Target frames per execution for each tier
local frameTargets = {
	[60] = 1,    -- Execute every frame
	[10] = 6,    -- Execute every 6 frames (60/10)
	[2] = 30,    -- Execute every 30 frames (60/2)
	[0.2] = 300  -- Execute every 300 frames (60/0.2)
}

-- Scheduler initialization
local initialized = false
local schedulerConnection

-- Performance metrics
local metrics = {
	totalTasks = 0,
	tasksExecuted = 0,
	avgExecutionTime = 0,
	lastMetricsReset = os.clock()
}

-- Initialize the scheduler system
function Scheduler.Initialize()
	if initialized then
		warn("[Scheduler] Already initialized")
		return
	end
	
	-- Single Heartbeat connection for all scheduled tasks
	schedulerConnection = RunService.Heartbeat:Connect(function(deltaTime)
		Scheduler.ProcessScheduledTasks(deltaTime)
	end)
	
	initialized = true
	print("[Scheduler] ✓ Initialized - Consolidated Heartbeat system active")
end

-- Process all scheduled tasks based on their frequency tiers
function Scheduler.ProcessScheduledTasks(deltaTime: number)
	local executionStart = os.clock()
	local tasksRan = 0
	
	-- Process each frequency tier
	for frequency, tasks in pairs(tasksByFreq) do
		local frameTarget = frameTargets[frequency]
		frameCounters[frequency] = frameCounters[frequency] + 1
		
		-- Execute tasks when frame target is reached
		if frameCounters[frequency] >= frameTarget then
			for taskId, taskData in pairs(tasks) do
				if taskData.enabled then
					local success, err = pcall(taskData.callback, deltaTime)
					if not success then
						warn("[Scheduler] Task error:", taskId, err)
						-- Disable failed task temporarily
						taskData.enabled = false
						task.spawn(function()
							task.wait(5) -- Re-enable after 5 seconds
							if tasks[taskId] then
								tasks[taskId].enabled = true
							end
						end)
					else
						tasksRan = tasksRan + 1
					end
				end
			end
			frameCounters[frequency] = 0 -- Reset counter
		end
	end
	
	-- Update metrics
	metrics.tasksExecuted = metrics.tasksExecuted + tasksRan
	local executionTime = os.clock() - executionStart
	metrics.avgExecutionTime = (metrics.avgExecutionTime + executionTime) / 2
end

-- Schedule a new task
function Scheduler.ScheduleTask(taskId: string, callback: (number) -> (), frequency: number?): boolean
	if not initialized then
		Scheduler.Initialize()
	end
	
	-- Default to medium frequency if not specified
	frequency = frequency or TASK_TIERS.MEDIUM_FREQ
	
	-- Validate frequency tier exists
	if not tasksByFreq[frequency] then
		warn("[Scheduler] Invalid frequency tier:", frequency)
		return false
	end
	
	-- Check if task already exists
	if tasksByFreq[frequency][taskId] then
		warn("[Scheduler] Task already scheduled:", taskId)
		return false
	end
	
	-- Add task to appropriate frequency tier
	tasksByFreq[frequency][taskId] = {
		callback = callback,
		enabled = true,
		scheduledAt = os.clock(),
		frequency = frequency
	}
	
	metrics.totalTasks = metrics.totalTasks + 1
	print("[Scheduler] ✓ Scheduled task:", taskId, "at", frequency, "Hz")
	
	return true
end

-- Remove a scheduled task
function Scheduler.UnscheduleTask(taskId: string, frequency: number?): boolean
	-- Search all frequencies if not specified
	if not frequency then
		for freq, tasks in pairs(tasksByFreq) do
			if tasks[taskId] then
				tasks[taskId] = nil
				metrics.totalTasks = metrics.totalTasks - 1
				print("[Scheduler] ✓ Unscheduled task:", taskId)
				return true
			end
		end
		return false
	end
	
	-- Remove from specific frequency
	if tasksByFreq[frequency] and tasksByFreq[frequency][taskId] then
		tasksByFreq[frequency][taskId] = nil
		metrics.totalTasks = metrics.totalTasks - 1
		print("[Scheduler] ✓ Unscheduled task:", taskId)
		return true
	end
	
	return false
end

-- Pause/resume a task
function Scheduler.SetTaskEnabled(taskId: string, enabled: boolean, frequency: number?): boolean
	-- Search all frequencies if not specified
	if not frequency then
		for freq, tasks in pairs(tasksByFreq) do
			if tasks[taskId] then
				tasks[taskId].enabled = enabled
				print("[Scheduler] ✓ Task", taskId, enabled and "enabled" or "paused")
				return true
			end
		end
		return false
	end
	
	-- Update specific frequency
	if tasksByFreq[frequency] and tasksByFreq[frequency][taskId] then
		tasksByFreq[frequency][taskId].enabled = enabled
		print("[Scheduler] ✓ Task", taskId, enabled and "enabled" or "paused")
		return true
	end
	
	return false
end

-- Get scheduler performance metrics
function Scheduler.GetMetrics(): {totalTasks: number, tasksExecuted: number, avgExecutionTime: number, uptime: number}
	return {
		totalTasks = metrics.totalTasks,
		tasksExecuted = metrics.tasksExecuted,
		avgExecutionTime = math.floor(metrics.avgExecutionTime * 1000000) / 1000, -- Convert to microseconds
		uptime = os.clock() - metrics.lastMetricsReset
	}
end

-- Get all scheduled tasks for debugging
function Scheduler.GetScheduledTasks(): {[number]: {[string]: any}}
	local result = {}
	for frequency, tasks in pairs(tasksByFreq) do
		result[frequency] = {}
		for taskId, taskData in pairs(tasks) do
			result[frequency][taskId] = {
				enabled = taskData.enabled,
				scheduledAt = taskData.scheduledAt,
				frequency = taskData.frequency
			}
		end
	end
	return result
end

-- Cleanup scheduler (for testing)
function Scheduler.Cleanup()
	if schedulerConnection then
		schedulerConnection:Disconnect()
		schedulerConnection = nil
	end
	
	-- Clear all tasks
	for frequency in pairs(tasksByFreq) do
		tasksByFreq[frequency] = {}
		frameCounters[frequency] = 0
	end
	
	metrics.totalTasks = 0
	metrics.tasksExecuted = 0
	metrics.avgExecutionTime = 0
	metrics.lastMetricsReset = os.clock()
	
	initialized = false
	print("[Scheduler] ✓ Cleanup complete")
end

-- Predefined frequency constants for easy use
Scheduler.Frequency = TASK_TIERS

return Scheduler
