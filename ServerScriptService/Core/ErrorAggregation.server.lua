-- ErrorAggregation.server.lua
-- Crash and error aggregation with alerting

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Logging = require(ReplicatedStorage.Shared.Logging)

local ErrorAggregation = {}

-- DataStore for error logs
local errorStore = DataStoreService:GetDataStore("ErrorLogs")
local alertStore = DataStoreService:GetDataStore("ErrorAlerts")

-- Error tracking
local errorCounts = {}
local errorHistory = {}
local alertThresholds = {
	error_rate = { threshold = 10, window = 300 }, -- 10 errors in 5 minutes
	crash_rate = { threshold = 3, window = 600 }, -- 3 crashes in 10 minutes
	memory_leak = { threshold = 1000, window = 300 }, -- 1000MB increase in 5 minutes
	performance_drop = { threshold = 5, window = 60 } -- 5 FPS drop in 1 minute
}

-- Alert tracking
local activeAlerts = {}
local lastAlertTime = {}

-- Error classification
local ERROR_TYPES = {
	script_error = { severity = "error", category = "runtime" },
	timeout = { severity = "warning", category = "performance" },
	memory_leak = { severity = "critical", category = "resource" },
	infinite_loop = { severity = "critical", category = "runtime" },
	nil_reference = { severity = "error", category = "runtime" },
	type_error = { severity = "error", category = "runtime" },
	network_error = { severity = "warning", category = "network" },
	datastore_error = { severity = "error", category = "persistence" },
	teleport_error = { severity = "warning", category = "network" },
	remote_error = { severity = "error", category = "security" }
}

function ErrorAggregation.LogError(errorType, message, stackTrace, context)
	local timestamp = os.time()
	local errorId = game:GetService("HttpService"):GenerateGUID(false)
	
	local errorData = {
		id = errorId,
		type = errorType,
		message = message or "Unknown error",
		stackTrace = stackTrace or "",
		context = context or {},
		timestamp = timestamp,
		serverId = game.JobId,
		placeId = game.PlaceId,
		severity = ERROR_TYPES[errorType] and ERROR_TYPES[errorType].severity or "error",
		category = ERROR_TYPES[errorType] and ERROR_TYPES[errorType].category or "unknown"
	}
	
	-- Add server context
	errorData.context.playerCount = #Players:GetPlayers()
	errorData.context.serverUptime = timestamp - (game:GetService("Stats").ElapsedTime or 0)
	errorData.context.memoryUsage = game:GetService("Stats").GetTotalMemoryUsageMb()
	
	-- Store error
	table.insert(errorHistory, errorData)
	
	-- Keep history manageable
	if #errorHistory > 1000 then
		table.remove(errorHistory, 1)
	end
	
	-- Update error counts
	if not errorCounts[errorType] then
		errorCounts[errorType] = {}
	end
	table.insert(errorCounts[errorType], timestamp)
	
	-- Clean old entries
	ErrorAggregation.CleanOldEntries(errorType)
	
	-- Check alert thresholds
	ErrorAggregation.CheckAlerts(errorType)
	
	-- Save to DataStore (with rate limiting)
	ErrorAggregation.SaveErrorToDataStore(errorData)
	
	-- Log for immediate visibility
	Logging.Error("ErrorAggregation", string.format("[%s] %s: %s", errorType, errorData.severity, message))
	
	return errorId
end

function ErrorAggregation.LogCrash(reason, playerData, serverData)
	local crashData = {
		reason = reason,
		playerData = playerData or {},
		serverData = serverData or {},
		timestamp = os.time(),
		serverId = game.JobId,
		recoverable = false
	}
	
	ErrorAggregation.LogError("server_crash", "Server crash detected: " .. reason, "", crashData)
	
	-- Attempt recovery actions
	ErrorAggregation.AttemptRecovery(crashData)
end

function ErrorAggregation.CleanOldEntries(errorType)
	if not errorCounts[errorType] then return end
	
	local now = os.time()
	local threshold = alertThresholds.error_rate.window
	
	-- Remove entries older than threshold
	local i = 1
	while i <= #errorCounts[errorType] do
		if now - errorCounts[errorType][i] > threshold then
			table.remove(errorCounts[errorType], i)
		else
			i = i + 1
		end
	end
end

function ErrorAggregation.CheckAlerts(errorType)
	local now = os.time()
	
	-- Check error rate alerts
	if errorCounts[errorType] then
		local recentErrors = #errorCounts[errorType]
		local threshold = alertThresholds.error_rate.threshold
		
		if recentErrors >= threshold then
			ErrorAggregation.TriggerAlert("error_rate_exceeded", {
				errorType = errorType,
				count = recentErrors,
				threshold = threshold,
				window = alertThresholds.error_rate.window
			})
		end
	end
	
	-- Check performance alerts
	ErrorAggregation.CheckPerformanceAlerts()
	
	-- Check memory alerts
	ErrorAggregation.CheckMemoryAlerts()
end

function ErrorAggregation.CheckPerformanceAlerts()
	local currentFPS = 1 / RunService.Heartbeat:Wait()
	local memoryUsage = game:GetService("Stats").GetTotalMemoryUsageMb()
	
	-- Track performance metrics
	if not ErrorAggregation.performanceHistory then
		ErrorAggregation.performanceHistory = { fps = {}, memory = {} }
	end
	
	local history = ErrorAggregation.performanceHistory
	table.insert(history.fps, { time = os.time(), value = currentFPS })
	table.insert(history.memory, { time = os.time(), value = memoryUsage })
	
	-- Keep only recent history
	local cutoff = os.time() - 300 -- 5 minutes
	
	local i = 1
	while i <= #history.fps do
		if history.fps[i].time < cutoff then
			table.remove(history.fps, i)
		else
			i = i + 1
		end
	end
	
	i = 1
	while i <= #history.memory do
		if history.memory[i].time < cutoff then
			table.remove(history.memory, i)
		else
			i = i + 1
		end
	end
	
	-- Check for performance drops
	if #history.fps >= 10 then
		local recentFPS = 0
		local count = math.min(5, #history.fps)
		
		for i = #history.fps - count + 1, #history.fps do
			recentFPS = recentFPS + history.fps[i].value
		end
		recentFPS = recentFPS / count
		
		if recentFPS < 15 then -- Critical FPS threshold
			ErrorAggregation.TriggerAlert("performance_critical", {
				averageFPS = recentFPS,
				memoryUsage = memoryUsage
			})
		end
	end
end

function ErrorAggregation.CheckMemoryAlerts()
	if not ErrorAggregation.performanceHistory or not ErrorAggregation.performanceHistory.memory then
		return
	end
	
	local history = ErrorAggregation.performanceHistory.memory
	if #history < 10 then return end
	
	-- Check for memory leaks (rapid increase)
	local recent = history[#history].value
	local older = history[math.max(1, #history - 10)].value
	local increase = recent - older
	
	if increase > alertThresholds.memory_leak.threshold then
		ErrorAggregation.TriggerAlert("memory_leak_detected", {
			currentMemory = recent,
			increase = increase,
			timeWindow = history[#history].time - history[math.max(1, #history - 10)].time
		})
	end
end

function ErrorAggregation.TriggerAlert(alertType, data)
	local now = os.time()
	
	-- Rate limit alerts (don't spam)
	if lastAlertTime[alertType] and now - lastAlertTime[alertType] < 300 then
		return
	end
	
	lastAlertTime[alertType] = now
	
	local alert = {
		id = game:GetService("HttpService"):GenerateGUID(false),
		type = alertType,
		severity = ErrorAggregation.GetAlertSeverity(alertType),
		data = data,
		timestamp = now,
		serverId = game.JobId,
		acknowledged = false,
		resolved = false
	}
	
	activeAlerts[alert.id] = alert
	
	-- Save alert
	pcall(function()
		alertStore:SetAsync(alert.id, alert)
	end)
	
	-- Send alert notifications
	ErrorAggregation.SendAlertNotifications(alert)
	
	Logging.Warn("ErrorAggregation", string.format("Alert triggered: %s [%s]", alertType, alert.severity))
end

function ErrorAggregation.GetAlertSeverity(alertType)
	local severityMap = {
		error_rate_exceeded = "warning",
		performance_critical = "critical",
		memory_leak_detected = "critical",
		server_crash = "critical",
		datastore_failure = "critical",
		security_breach = "critical"
	}
	
	return severityMap[alertType] or "warning"
end

function ErrorAggregation.SendAlertNotifications(alert)
	-- Send to admin players
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetRankInGroup(0) >= 100 then -- Admin check
			-- Send alert to admin UI
			-- This would integrate with an admin panel
		end
	end
	
	-- Send cross-server alert
	pcall(function()
		MessagingService:PublishAsync("AdminAlerts", {
			type = "error_alert",
			alert = alert
		})
	end)
	
	-- For critical alerts, attempt external notifications
	if alert.severity == "critical" then
		ErrorAggregation.SendExternalAlert(alert)
	end
end

function ErrorAggregation.SendExternalAlert(alert)
	-- This would integrate with external services like Discord, Slack, etc.
	-- For now, just log the critical alert
	Logging.Error("CRITICAL_ALERT", string.format(
		"Critical alert: %s in server %s - %s",
		alert.type,
		alert.serverId,
		game:GetService("HttpService"):JSONEncode(alert.data)
	))
end

function ErrorAggregation.SaveErrorToDataStore(errorData)
	-- Rate limit DataStore writes
	if not ErrorAggregation.lastSave then
		ErrorAggregation.lastSave = 0
		ErrorAggregation.pendingErrors = {}
	end
	
	table.insert(ErrorAggregation.pendingErrors, errorData)
	
	local now = os.time()
	if now - ErrorAggregation.lastSave >= 30 then -- Batch every 30 seconds
		ErrorAggregation.FlushPendingErrors()
		ErrorAggregation.lastSave = now
	end
end

function ErrorAggregation.FlushPendingErrors()
	if not ErrorAggregation.pendingErrors or #ErrorAggregation.pendingErrors == 0 then
		return
	end
	
	local batch = ErrorAggregation.pendingErrors
	ErrorAggregation.pendingErrors = {}
	
	pcall(function()
		local batchId = game:GetService("HttpService"):GenerateGUID(false)
		errorStore:SetAsync("batch_" .. batchId, {
			errors = batch,
			timestamp = os.time(),
			serverId = game.JobId
		})
	end)
end

function ErrorAggregation.AttemptRecovery(crashData)
	-- Attempt basic recovery actions
	local recoveryActions = {
		"garbage_collect",
		"clear_connections",
		"reset_modules",
		"restart_services"
	}
	
	for _, action in ipairs(recoveryActions) do
		local success = ErrorAggregation.ExecuteRecoveryAction(action)
		if success then
			crashData.recoverable = true
			crashData.recoveryAction = action
			break
		end
	end
end

function ErrorAggregation.ExecuteRecoveryAction(action)
	if action == "garbage_collect" then
		-- Force garbage collection
		collectgarbage("collect")
		return true
	elseif action == "clear_connections" then
		-- Clear unnecessary connections
		-- This would be game-specific
		return true
	elseif action == "reset_modules" then
		-- Reset module caches
		-- This would require careful implementation
		return false
	elseif action == "restart_services" then
		-- Restart non-critical services
		-- This would be very game-specific
		return false
	end
	
	return false
end

function ErrorAggregation.GetErrorSummary(timeWindow)
	timeWindow = timeWindow or 3600 -- Default 1 hour
	local cutoff = os.time() - timeWindow
	
	local summary = {
		totalErrors = 0,
		errorsByType = {},
		errorsBySeverity = {},
		timeWindow = timeWindow,
		generatedAt = os.time()
	}
	
	for _, error in ipairs(errorHistory) do
		if error.timestamp >= cutoff then
			summary.totalErrors = summary.totalErrors + 1
			
			-- Count by type
			summary.errorsByType[error.type] = (summary.errorsByType[error.type] or 0) + 1
			
			-- Count by severity
			summary.errorsBySeverity[error.severity] = (summary.errorsBySeverity[error.severity] or 0) + 1
		end
	end
	
	return summary
end

function ErrorAggregation.GetActiveAlerts()
	local alerts = {}
	for _, alert in pairs(activeAlerts) do
		if not alert.resolved then
			table.insert(alerts, alert)
		end
	end
	
	-- Sort by severity and timestamp
	table.sort(alerts, function(a, b)
		if a.severity ~= b.severity then
			local severityOrder = { critical = 3, warning = 2, info = 1 }
			return (severityOrder[a.severity] or 0) > (severityOrder[b.severity] or 0)
		end
		return a.timestamp > b.timestamp
	end)
	
	return alerts
end

-- Hook into Roblox error reporting
local function onErrorOccurred(message, stackTrace, script)
	local errorType = "script_error"
	
	-- Classify error type based on message
	if string.find(message:lower(), "timeout") then
		errorType = "timeout"
	elseif string.find(message:lower(), "nil") then
		errorType = "nil_reference"
	elseif string.find(message:lower(), "attempt to") then
		errorType = "type_error"
	elseif string.find(message:lower(), "memory") then
		errorType = "memory_leak"
	end
	
	ErrorAggregation.LogError(errorType, message, stackTrace, {
		script = script and script.Name or "Unknown",
		scriptParent = script and script.Parent and script.Parent.Name or "Unknown"
	})
end

-- Connect to error events
if game:GetService("ScriptContext") then
	game:GetService("ScriptContext").Error:Connect(onErrorOccurred)
end

-- Periodic cleanup and monitoring
spawn(function()
	while true do
		wait(60) -- Every minute
		
		-- Clean old error counts
		for errorType, _ in pairs(errorCounts) do
			ErrorAggregation.CleanOldEntries(errorType)
		end
		
		-- Flush pending errors
		ErrorAggregation.FlushPendingErrors()
		
		-- Check system health
		ErrorAggregation.CheckPerformanceAlerts()
		ErrorAggregation.CheckMemoryAlerts()
	end
end)

-- Initialize
ErrorAggregation.performanceHistory = { fps = {}, memory = {} }

return ErrorAggregation
