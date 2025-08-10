--[[
	Logging.lua
	Enterprise Logging & Analytics Framework
	Phase 2.6: Advanced Logging & Analytics

	Provides centralized logging with structured events, performance metrics,
	error tracking, and player behavior analytics integration.
	
	Features:
	- Structured event logging with context
	- Performance metrics collection
	- Error tracking with stack traces
	- Player behavior analytics
	- Real-time metrics streaming
	- Log aggregation and filtering
	- Memory-efficient log rotation
]]

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Logging = {}
local Metrics = nil
local AnalyticsEngine = nil

-- Types for logging system
export type LogLevel = "TRACE" | "DEBUG" | "INFO" | "WARN" | "ERROR" | "FATAL"
export type LogEntry = {
	id: string,
	level: LogLevel,
	category: string,
	message: string,
	data: {[string]: any}?,
	context: LogContext,
	timestamp: number,
	stackTrace: string?,
	userId: number?,
	sessionId: string?
}

export type LogContext = {
	server: boolean,
	place: string,
	timestamp: string,
	frameTime: number?,
	memoryUsage: number?,
	playerCount: number?
}

export type PerformanceMetric = {
	name: string,
	value: number,
	unit: string,
	timestamp: number,
	category: string,
	tags: {[string]: string}?
}

export type PlayerEvent = {
	userId: number,
	eventType: string,
	eventData: {[string]: any},
	timestamp: number,
	sessionId: string
}

export type ErrorReport = {
	id: string,
	message: string,
	stackTrace: string,
	category: string,
	timestamp: number,
	context: LogContext,
	severity: LogLevel,
	userId: number?
}

-- Log levels with numeric values
local LogLevel = {
	TRACE = 1,
	DEBUG = 2,
	INFO = 3,
	WARN = 4,
	ERROR = 5,
	FATAL = 6
}

local LogLevelNames = {
	[1] = "TRACE",
	[2] = "DEBUG", 
	[3] = "INFO",
	[4] = "WARN",
	[5] = "ERROR",
	[6] = "FATAL"
}

-- Configuration
local CONFIG = {
	currentLogLevel = LogLevel.INFO,
	maxLogHistory = 2000,
	maxErrorHistory = 500,
	maxPerformanceHistory = 1000,
	enableStackTraces = true,
	enablePerformanceMetrics = true,
	enablePlayerAnalytics = true,
	logRotationInterval = 300, -- 5 minutes
	metricsFlushInterval = 60, -- 1 minute
	enableRealTimeStreaming = true
}

-- State management
local state = {
	logHistory = {},
	errorHistory = {},
	performanceHistory = {},
	playerSessions = {}, -- userId -> sessionId
	logFilters = {},
	stats = {
		totalLogs = 0,
		totalErrors = 0,
		totalPerformanceMetrics = 0,
		logsByLevel = {},
		logsByCategory = {},
		startTime = os.time()
	},
	realtimeSubscribers = {}
}

-- Utility: Generate unique ID
local function generateId(): string
	return HttpService:GenerateGUID(false)
end

-- Enhanced timestamp with high precision
local function getTimestamp(): string
	return string.format("%.3f", os.clock())
end

-- Get detailed execution context information
local function getContext(): LogContext
	local context = {
		server = RunService:IsServer(),
		place = tostring(game.PlaceId),
		timestamp = getTimestamp(),
		playerCount = #Players:GetPlayers()
	}
	
	-- Add performance context if enabled
	if CONFIG.enablePerformanceMetrics then
		context.frameTime = 1 / RunService.Heartbeat:Wait()
		
		-- Memory usage estimation (server only)
		if RunService:IsServer() then
			context.memoryUsage = gcinfo()
		end
	end
	
	return context
end

-- Get stack trace for error tracking
local function getStackTrace(level: number?): string?
	if not CONFIG.enableStackTraces then
		return nil
	end
	
	local trace = debug.traceback("", (level or 2) + 1)
	return trace
end

-- Get player session ID
local function getPlayerSessionId(userId: number): string
	if not state.playerSessions[userId] then
		state.playerSessions[userId] = generateId()
	end
	return state.playerSessions[userId]
end

-- Core logging function with enhanced structure
local function log(level: number, category: string, message: string, data: {[string]: any}?, userId: number?): LogEntry
	if level < CONFIG.currentLogLevel then
		return nil -- Skip logs below current level
	end
	
	local logEntry: LogEntry = {
		id = generateId(),
		level = LogLevelNames[level],
		category = category,
		message = message,
		data = data,
		context = getContext(),
		timestamp = tick(),
		stackTrace = level >= LogLevel.WARN and getStackTrace(3) or nil,
		userId = userId,
		sessionId = userId and getPlayerSessionId(userId) or nil
	}
	
	-- Store in history with rotation
	table.insert(state.logHistory, logEntry)
	if #state.logHistory > CONFIG.maxLogHistory then
		table.remove(state.logHistory, 1)
	end
	
	-- Update statistics
	state.stats.totalLogs += 1
	state.stats.logsByLevel[logEntry.level] = (state.stats.logsByLevel[logEntry.level] or 0) + 1
	state.stats.logsByCategory[category] = (state.stats.logsByCategory[category] or 0) + 1
	
	-- Store errors separately for error tracking
	if level >= LogLevel.ERROR then
		local errorReport: ErrorReport = {
			id = logEntry.id,
			message = message,
			stackTrace = logEntry.stackTrace or "No stack trace available",
			category = category,
			timestamp = logEntry.timestamp,
			context = logEntry.context,
			severity = logEntry.level,
			userId = userId
		}
		
		table.insert(state.errorHistory, errorReport)
		if #state.errorHistory > CONFIG.maxErrorHistory then
			table.remove(state.errorHistory, 1)
		end
		
		state.stats.totalErrors += 1
	end
	
	-- Format for console output
	local prefix = string.format("[%s][%s]", logEntry.level, category)
	local output = message
	
	if data then
		local success, jsonData = pcall(HttpService.JSONEncode, HttpService, data)
		if success then
			output = output .. " | Data: " .. jsonData
		else
			output = output .. " | Data: [Encoding Error]"
		end
	end
	
	-- Output to console with appropriate method
	if level >= LogLevel.ERROR then
		warn(prefix, output)
	else
		print(prefix, output)
	end
	
	-- Send to metrics system
	if Metrics then
		Metrics.Inc("Log_" .. logEntry.level)
		Metrics.Inc("Log_Category_" .. category)
	end
	
	-- Send to analytics engine
	if AnalyticsEngine then
		AnalyticsEngine.RecordLogEvent(logEntry)
	end
	
	-- Real-time streaming to subscribers
	if CONFIG.enableRealTimeStreaming then
		for _, subscriber in ipairs(state.realtimeSubscribers) do
			task.spawn(function()
				local success, result = pcall(subscriber, logEntry)
				if not success then
					warn("Logging real-time subscriber error:", result)
				end
			end)
		end
	end
	
	return logEntry
end

-- Public: Set analytics engine integration
function Logging.SetAnalyticsEngine(analyticsInstance)
	AnalyticsEngine = analyticsInstance
end

-- Public: Set metrics integration
function Logging.SetMetrics(metricsInstance)
	Metrics = metricsInstance
end

-- Public: Set minimum log level
function Logging.SetLevel(level: number)
	CONFIG.currentLogLevel = level
end

-- Public: Add real-time log subscriber
function Logging.AddRealtimeSubscriber(callback: (LogEntry) -> ())
	table.insert(state.realtimeSubscribers, callback)
end

-- Public: Remove real-time log subscriber
function Logging.RemoveRealtimeSubscriber(callback: (LogEntry) -> ())
	for i, subscriber in ipairs(state.realtimeSubscribers) do
		if subscriber == callback then
			table.remove(state.realtimeSubscribers, i)
			break
		end
	end
end

-- Enhanced logging interface with user context
function Logging.Trace(category: string, message: string, data: {[string]: any}?, userId: number?)
	return log(LogLevel.TRACE, category, message, data, userId)
end

function Logging.Debug(category: string, message: string, data: {[string]: any}?, userId: number?)
	return log(LogLevel.DEBUG, category, message, data, userId)
end

function Logging.Info(category: string, message: string, data: {[string]: any}?, userId: number?)
	return log(LogLevel.INFO, category, message, data, userId)
end

function Logging.Warn(category: string, message: string, data: {[string]: any}?, userId: number?)
	return log(LogLevel.WARN, category, message, data, userId)
end

function Logging.Error(category: string, message: string, data: {[string]: any}?, userId: number?)
	return log(LogLevel.ERROR, category, message, data, userId)
end

function Logging.Fatal(category: string, message: string, data: {[string]: any}?, userId: number?)
	return log(LogLevel.FATAL, category, message, data, userId)
end

-- Performance metrics logging
function Logging.RecordPerformanceMetric(name: string, value: number, unit: string, category: string?, tags: {[string]: string}?)
	if not CONFIG.enablePerformanceMetrics then
		return
	end
	
	local metric: PerformanceMetric = {
		name = name,
		value = value,
		unit = unit,
		timestamp = tick(),
		category = category or "General",
		tags = tags
	}
	
	table.insert(state.performanceHistory, metric)
	if #state.performanceHistory > CONFIG.maxPerformanceHistory then
		table.remove(state.performanceHistory, 1)
	end
	
	state.stats.totalPerformanceMetrics += 1
	
	-- Send to analytics engine
	if AnalyticsEngine then
		AnalyticsEngine.RecordPerformanceMetric(metric)
	end
	
	-- Log performance metric
	Logging.Debug("Performance", string.format("%s: %s %s", name, tostring(value), unit), {
		metric = metric
	})
end

-- Player behavior event logging
function Logging.RecordPlayerEvent(userId: number, eventType: string, eventData: {[string]: any})
	if not CONFIG.enablePlayerAnalytics then
		return
	end
	
	local playerEvent: PlayerEvent = {
		userId = userId,
		eventType = eventType,
		eventData = eventData,
		timestamp = tick(),
		sessionId = getPlayerSessionId(userId)
	}
	
	-- Send to analytics engine
	if AnalyticsEngine then
		AnalyticsEngine.RecordPlayerEvent(playerEvent)
	end
	
	-- Log player event
	Logging.Info("PlayerAnalytics", string.format("Player %d: %s", userId, eventType), {
		event = playerEvent
	}, userId)
end

-- Legacy compatibility function
function Logging.Event(name: string, data: {[string]: any}?)
	local payload = { t = getTimestamp(), e = name, d = data }
	return Logging.Info("Event", name, payload)
end

-- Get comprehensive logging statistics
function Logging.GetStats(): {[string]: any}
	local logsByLevel = {}
	local logsByCategory = {}
	local recentLogs = {}
	local recentErrors = {}
	
	-- Analyze log history
	for _, entry in ipairs(state.logHistory) do
		logsByLevel[entry.level] = (logsByLevel[entry.level] or 0) + 1
		logsByCategory[entry.category] = (logsByCategory[entry.category] or 0) + 1
		
		if #recentLogs < 10 then
			table.insert(recentLogs, {
				id = entry.id,
				level = entry.level,
				category = entry.category,
				message = entry.message,
				timestamp = entry.timestamp
			})
		end
	end
	
	-- Get recent errors
	for i = math.max(1, #state.errorHistory - 9), #state.errorHistory do
		if state.errorHistory[i] then
			table.insert(recentErrors, {
				id = state.errorHistory[i].id,
				message = state.errorHistory[i].message,
				category = state.errorHistory[i].category,
				severity = state.errorHistory[i].severity,
				timestamp = state.errorHistory[i].timestamp
			})
		end
	end
	
	local uptime = os.time() - state.stats.startTime
	
	return {
		totalLogs = state.stats.totalLogs,
		totalErrors = state.stats.totalErrors,
		totalPerformanceMetrics = state.stats.totalPerformanceMetrics,
		logsByLevel = logsByLevel,
		logsByCategory = logsByCategory,
		recentLogs = recentLogs,
		recentErrors = recentErrors,
		errorRate = state.stats.totalLogs > 0 and (state.stats.totalErrors / state.stats.totalLogs * 100) or 0,
		uptime = uptime,
		logsPerSecond = uptime > 0 and (state.stats.totalLogs / uptime) or 0,
		config = CONFIG,
		historySize = {
			logs = #state.logHistory,
			errors = #state.errorHistory,
			performance = #state.performanceHistory
		}
	}
end

-- Get filtered logs
function Logging.GetLogs(filter: {level: LogLevel?, category: string?, userId: number?, limit: number?}?): {LogEntry}
	local results = {}
	local limit = filter and filter.limit or 100
	
	for i = math.max(1, #state.logHistory - limit + 1), #state.logHistory do
		local entry = state.logHistory[i]
		if entry then
			local include = true
			
			if filter then
				if filter.level and entry.level ~= filter.level then
					include = false
				end
				
				if filter.category and entry.category ~= filter.category then
					include = false
				end
				
				if filter.userId and entry.userId ~= filter.userId then
					include = false
				end
			end
			
			if include then
				table.insert(results, entry)
			end
		end
	end
	
	return results
end

-- Get error reports
function Logging.GetErrors(limit: number?): {ErrorReport}
	local maxErrors = limit or 50
	local results = {}
	
	for i = math.max(1, #state.errorHistory - maxErrors + 1), #state.errorHistory do
		if state.errorHistory[i] then
			table.insert(results, state.errorHistory[i])
		end
	end
	
	return results
end

-- Get performance metrics
function Logging.GetPerformanceMetrics(category: string?, limit: number?): {PerformanceMetric}
	local maxMetrics = limit or 100
	local results = {}
	
	for i = math.max(1, #state.performanceHistory - maxMetrics + 1), #state.performanceHistory do
		local metric = state.performanceHistory[i]
		if metric and (not category or metric.category == category) then
			table.insert(results, metric)
		end
	end
	
	return results
end

-- Cleanup old logs (called periodically)
function Logging.Cleanup()
	local now = tick()
	local cutoffTime = now - CONFIG.logRotationInterval
	
	-- Remove old logs
	local newLogHistory = {}
	for _, entry in ipairs(state.logHistory) do
		if entry.timestamp > cutoffTime then
			table.insert(newLogHistory, entry)
		end
	end
	state.logHistory = newLogHistory
	
	-- Remove old errors
	local newErrorHistory = {}
	for _, error in ipairs(state.errorHistory) do
		if error.timestamp > cutoffTime then
			table.insert(newErrorHistory, error)
		end
	end
	state.errorHistory = newErrorHistory
	
	-- Remove old performance metrics
	local newPerformanceHistory = {}
	for _, metric in ipairs(state.performanceHistory) do
		if metric.timestamp > cutoffTime then
			table.insert(newPerformanceHistory, metric)
		end
	end
	state.performanceHistory = newPerformanceHistory
	
	Logging.Debug("Logging", "Log cleanup completed", {
		logsRemaining = #state.logHistory,
		errorsRemaining = #state.errorHistory,
		metricsRemaining = #state.performanceHistory
	})
end

-- Initialize periodic cleanup
task.spawn(function()
	while true do
		wait(CONFIG.logRotationInterval)
		Logging.Cleanup()
	end
end)

-- Export log levels and types for external use
Logging.LogLevel = LogLevel
Logging.CONFIG = CONFIG

Logging.Info("Logging", "Enhanced Enterprise Logging System initialized", {
	features = {
		"Structured Logging",
		"Error Tracking", 
		"Performance Metrics",
		"Player Analytics",
		"Real-time Streaming",
		"Log Rotation"
	},
	config = CONFIG
})

return Logging
