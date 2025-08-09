--[[
	Logging.lua
	Enterprise logging & telemetry facade with structured logging
	
	Provides centralized logging with levels, context, and metrics integration
]]

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Logging = {}
local Metrics = nil

-- Log levels
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
local currentLogLevel = LogLevel.INFO
local maxLogHistory = 1000
local logHistory = {}

-- Enhanced timestamp with high precision
local function getTimestamp(): string
	return string.format("%.3f", os.clock())
end

-- Get execution context information
local function getContext(): {server: boolean, place: string, timestamp: string}
	return {
		server = RunService:IsServer(),
		place = tostring(game.PlaceId),
		timestamp = getTimestamp()
	}
end

-- Core logging function with levels and structure
local function log(level: number, category: string, message: string, data: {[string]: any}?)
	if level < currentLogLevel then
		return -- Skip logs below current level
	end
	
	local logEntry = {
		level = LogLevelNames[level],
		category = category,
		message = message,
		data = data,
		context = getContext(),
		timestamp = tick()
	}
	
	-- Store in history
	table.insert(logHistory, logEntry)
	if #logHistory > maxLogHistory then
		table.remove(logHistory, 1)
	end
	
	-- Format for console output
	local prefix = string.format("[%s][%s]", logEntry.level, category)
	local output = message
	
	if data then
		local jsonData = HttpService:JSONEncode(data)
		output = output .. " | Data: " .. jsonData
	end
	
	-- Output to console
	if level >= LogLevel.ERROR then
		warn(prefix, output)
	else
		print(prefix, output)
	end
	
	-- Send metrics
	if Metrics then
		Metrics.Inc("Log_" .. logEntry.level)
		Metrics.Inc("Log_Category_" .. category)
	end
	
	return logEntry
end

-- Set metrics integration
function Logging.SetMetrics(metricsInstance)
	Metrics = metricsInstance
end

-- Set minimum log level
function Logging.SetLevel(level: number)
	currentLogLevel = level
end

-- Public logging interface
function Logging.Trace(category: string, message: string, data: {[string]: any}?)
	return log(LogLevel.TRACE, category, message, data)
end

function Logging.Debug(category: string, message: string, data: {[string]: any}?)
	return log(LogLevel.DEBUG, category, message, data)
end

function Logging.Info(category: string, message: string, data: {[string]: any}?)
	return log(LogLevel.INFO, category, message, data)
end

function Logging.Warn(category: string, message: string, data: {[string]: any}?)
	return log(LogLevel.WARN, category, message, data)
end

function Logging.Error(category: string, message: string, data: {[string]: any}?)
	return log(LogLevel.ERROR, category, message, data)
end

function Logging.Fatal(category: string, message: string, data: {[string]: any}?)
	return log(LogLevel.FATAL, category, message, data)
end

-- Legacy compatibility functions
function Logging.Event(name: string, data: {[string]: any}?)
	local payload = { t = getTimestamp(), e = name, d = data }
	return Logging.Info("Event", name, payload)
end

-- Get logging statistics
function Logging.GetStats(): {totalLogs: number, logsByLevel: {[string]: number}, recentLogs: {{level: string, category: string, message: string}}}
	local logsByLevel = {}
	local recentLogs = {}
	
	for _, entry in ipairs(logHistory) do
		logsByLevel[entry.level] = (logsByLevel[entry.level] or 0) + 1
		
		if #recentLogs < 10 then
			table.insert(recentLogs, {
				level = entry.level,
				category = entry.category,
				message = entry.message
			})
		end
	end
	
	return {
		totalLogs = #logHistory,
		logsByLevel = logsByLevel,
		recentLogs = recentLogs
	}
end

-- Export log levels for external use
Logging.LogLevel = LogLevel

return Logging
