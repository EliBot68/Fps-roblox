--!strict
--[[
	Logger.lua
	Structured logging system with levels and analytics integration
]]

local AnalyticsService = require(script.Parent.Parent.Parent.ServerStorage.Services.AnalyticsService)

export type LogLevel = "TRACE" | "DEBUG" | "INFO" | "WARN" | "ERROR" | "FATAL"

local Logger = {}

-- Configuration
local LOG_CONFIG = {
	enabledLevels = {
		TRACE = false,
		DEBUG = false,
		INFO = true,
		WARN = true,
		ERROR = true,
		FATAL = true
	},
	maxLogHistory = 1000,
	logToAnalytics = true,
	logToConsole = true
}

-- Log history for debugging
local logHistory: {{timestamp: number, level: LogLevel, module: string, message: string, data: any?}} = {}

-- Log level priorities (higher = more important)
local LOG_PRIORITIES = {
	TRACE = 1,
	DEBUG = 2,
	INFO = 3,
	WARN = 4,
	ERROR = 5,
	FATAL = 6
}

-- Create logger for specific module
function Logger.new(moduleName: string)
	local logger = {}
	
	function logger:trace(message: string, data: any?)
		Logger._log("TRACE", moduleName, message, data)
	end
	
	function logger:debug(message: string, data: any?)
		Logger._log("DEBUG", moduleName, message, data)
	end
	
	function logger:info(message: string, data: any?)
		Logger._log("INFO", moduleName, message, data)
	end
	
	function logger:warn(message: string, data: any?)
		Logger._log("WARN", moduleName, message, data)
	end
	
	function logger:error(message: string, data: any?)
		Logger._log("ERROR", moduleName, message, data)
	end
	
	function logger:fatal(message: string, data: any?)
		Logger._log("FATAL", moduleName, message, data)
	end
	
	return logger
end

-- Internal logging function
function Logger._log(level: LogLevel, module: string, message: string, data: any?)
	-- Check if level is enabled
	if not LOG_CONFIG.enabledLevels[level] then
		return
	end
	
	local timestamp = tick()
	local logEntry = {
		timestamp = timestamp,
		level = level,
		module = module,
		message = message,
		data = data
	}
	
	-- Add to history
	table.insert(logHistory, logEntry)
	
	-- Trim history if too large
	if #logHistory > LOG_CONFIG.maxLogHistory then
		table.remove(logHistory, 1)
	end
	
	-- Log to console
	if LOG_CONFIG.logToConsole then
		local prefix = string.format("[%s][%s] ", level, module)
		local fullMessage = prefix .. message
		
		if level == "ERROR" or level == "FATAL" then
			warn(fullMessage)
		else
			print(fullMessage)
		end
		
		-- Print data if provided
		if data then
			print("  Data:", data)
		end
	end
	
	-- Log to analytics for ERROR and above
	if LOG_CONFIG.logToAnalytics and LOG_PRIORITIES[level] >= LOG_PRIORITIES.ERROR then
		-- Safely attempt analytics logging
		local success, err = pcall(function()
			AnalyticsService.LogEvent(nil, "system_log", {
				level = level,
				module = module,
				message = message,
				data = data,
				timestamp = timestamp
			})
		end)
		
		if not success then
			warn("[Logger] Failed to log to analytics:", err)
		end
	end
end

-- Set log level enabled/disabled
function Logger.setLevel(level: LogLevel, enabled: boolean)
	LOG_CONFIG.enabledLevels[level] = enabled
end

-- Get recent logs
function Logger.getRecentLogs(count: number?): {{timestamp: number, level: LogLevel, module: string, message: string, data: any?}}
	local requestedCount = count or 50
	local startIndex = math.max(1, #logHistory - requestedCount + 1)
	
	local recentLogs = {}
	for i = startIndex, #logHistory do
		table.insert(recentLogs, logHistory[i])
	end
	
	return recentLogs
end

-- Get logs by level
function Logger.getLogsByLevel(level: LogLevel): {{timestamp: number, level: LogLevel, module: string, message: string, data: any?}}
	local filteredLogs = {}
	
	for _, log in ipairs(logHistory) do
		if log.level == level then
			table.insert(filteredLogs, log)
		end
	end
	
	return filteredLogs
end

-- Clear log history
function Logger.clearHistory()
	logHistory = {}
end

-- Get logging statistics
function Logger.getStatistics(): {totalLogs: number, logsByLevel: {[LogLevel]: number}}
	local stats = {
		totalLogs = #logHistory,
		logsByLevel = {}
	}
	
	-- Initialize level counts
	for level, _ in pairs(LOG_PRIORITIES) do
		stats.logsByLevel[level] = 0
	end
	
	-- Count logs by level
	for _, log in ipairs(logHistory) do
		stats.logsByLevel[log.level] = stats.logsByLevel[log.level] + 1
	end
	
	return stats
end

return Logger
