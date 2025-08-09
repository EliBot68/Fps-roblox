-- SecurityValidator.lua
-- Enterprise-grade security validation system with comprehensive input sanitization
-- Compatible with Service Locator pattern and dependency injection

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SecurityValidator = {}
SecurityValidator.__index = SecurityValidator

-- Type definitions for enterprise validation
export type ValidationRule = {
	type: string,
	required: boolean?,
	min: number?,
	max: number?,
	pattern: string?,
	whitelist: {any}?,
	blacklist: {any}?,
	customValidator: ((any) -> (boolean, string?))?
}

export type ValidationSchema = {
	[string]: ValidationRule
}

export type ValidationResult = {
	isValid: boolean,
	errors: {string},
	sanitizedData: {[string]: any}?
}

export type SecurityThreat = {
	playerId: number,
	threatType: string,
	severity: number, -- 1-10 scale
	description: string,
	timestamp: number,
	evidence: {[string]: any}
}

-- Enterprise security configuration
local SECURITY_CONFIG = {
	-- Rate limiting configuration
	rateLimits = {
		default = { maxRequests = 10, timeWindow = 1 }, -- 10 requests per second
		combat = { maxRequests = 20, timeWindow = 1 },   -- Combat needs higher rate
		ui = { maxRequests = 5, timeWindow = 1 },        -- UI interactions
		admin = { maxRequests = 2, timeWindow = 1 }      -- Admin actions very limited
	},
	
	-- Exploit detection thresholds
	exploitDetection = {
		rapidFireThreshold = 50,      -- Shots per second
		speedHackThreshold = 100,     -- Studs per second
		teleportThreshold = 500,      -- Studs in single frame
		invalidDataThreshold = 5,     -- Invalid requests before flagging
		suspiciousPatternThreshold = 3 -- Suspicious patterns before escalation
	},
	
	-- Security threat levels
	threatLevels = {
		LOW = 1,
		MEDIUM = 5,
		HIGH = 8,
		CRITICAL = 10
	},
	
	-- Automatic responses
	autoResponses = {
		kickThreshold = 8,           -- Auto-kick at threat level 8+
		banThreshold = 10,           -- Auto-ban at threat level 10
		alertAdminsThreshold = 5     -- Alert admins at threat level 5+
	}
}

-- Player tracking for rate limiting and exploit detection
local playerTracking = {}

-- Security event handlers
local securityEventHandlers = {}

-- Initialize SecurityValidator class
function SecurityValidator.new()
	local self = setmetatable({}, SecurityValidator)
	
	-- Initialize logging dependency
	self.logger = nil -- Will be injected by Service Locator
	
	-- Initialize rate limiting storage
	self.rateLimitData = {}
	
	-- Initialize threat tracking
	self.threatHistory = {}
	
	-- Initialize validation cache for performance
	self.validationCache = {}
	
	-- Performance metrics
	self.metrics = {
		totalValidations = 0,
		successfulValidations = 0,
		failedValidations = 0,
		threatsDetected = 0,
		averageValidationTime = 0
	}
	
	return self
end

-- Set logger dependency (injected by Service Locator)
function SecurityValidator:SetLogger(logger)
	self.logger = logger
	if self.logger then
		self.logger.Info("SecurityValidator", "Logger dependency injected successfully")
	end
end

-- Core validation function with comprehensive security checks
function SecurityValidator:ValidateRemoteCall(player: Player, remoteName: string, schema: ValidationSchema, data: {any}): ValidationResult
	local startTime = tick()
	self.metrics.totalValidations += 1
	
	local result: ValidationResult = {
		isValid = true,
		errors = {},
		sanitizedData = {}
	}
	
	-- Critical security checks first
	local securityCheck = self:PerformSecurityChecks(player, remoteName, data)
	if not securityCheck.passed then
		result.isValid = false
		for _, error in ipairs(securityCheck.errors) do
			table.insert(result.errors, error)
		end
		
		-- Log security violation
		self:LogSecurityViolation(player, remoteName, securityCheck.threatType, securityCheck.severity)
		
		self.metrics.failedValidations += 1
		return result
	end
	
	-- Rate limiting check
	if not self:CheckRateLimit(player, remoteName) then
		result.isValid = false
		table.insert(result.errors, "Rate limit exceeded for " .. remoteName)
		self:LogSecurityViolation(player, remoteName, "RATE_LIMIT_EXCEEDED", SECURITY_CONFIG.threatLevels.MEDIUM)
		
		self.metrics.failedValidations += 1
		return result
	end
	
	-- Validate data against schema
	local validationResult = self:ValidateDataSchema(data, schema)
	if not validationResult.isValid then
		result.isValid = false
		for _, error in ipairs(validationResult.errors) do
			table.insert(result.errors, error)
		end
		
		self.metrics.failedValidations += 1
		return result
	end
	
	-- Sanitize and prepare data
	result.sanitizedData = validationResult.sanitizedData
	
	-- Update metrics
	if result.isValid then
		self.metrics.successfulValidations += 1
	end
	
	local validationTime = tick() - startTime
	self.metrics.averageValidationTime = ((self.metrics.averageValidationTime * (self.metrics.totalValidations - 1)) + validationTime) / self.metrics.totalValidations
	
	return result
end

-- Comprehensive security checks for exploit detection
function SecurityValidator:PerformSecurityChecks(player: Player, remoteName: string, data: {any}): {passed: boolean, errors: {string}, threatType: string?, severity: number?}
	local result = {
		passed = true,
		errors = {},
		threatType = nil,
		severity = 0
	}
	
	-- Initialize player tracking if needed
	if not playerTracking[player.UserId] then
		playerTracking[player.UserId] = {
			lastRequestTime = tick(),
			requestHistory = {},
			invalidDataCount = 0,
			suspiciousPatterns = 0,
			lastPosition = nil,
			lastVelocity = Vector3.new(0, 0, 0)
		}
	end
	
	local tracking = playerTracking[player.UserId]
	local currentTime = tick()
	
	-- Check for rapid fire exploits (combat-related remotes)
	if string.match(remoteName:lower(), "shoot") or string.match(remoteName:lower(), "fire") then
		local timeSinceLastShot = currentTime - (tracking.lastShotTime or 0)
		if timeSinceLastShot < (1 / SECURITY_CONFIG.exploitDetection.rapidFireThreshold) then
			result.passed = false
			result.threatType = "RAPID_FIRE_EXPLOIT"
			result.severity = SECURITY_CONFIG.threatLevels.HIGH
			table.insert(result.errors, "Rapid fire exploit detected")
		end
		tracking.lastShotTime = currentTime
	end
	
	-- Check for teleportation exploits
	if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		local currentPosition = player.Character.HumanoidRootPart.Position
		if tracking.lastPosition then
			local distance = (currentPosition - tracking.lastPosition).Magnitude
			local timeDelta = currentTime - tracking.lastRequestTime
			
			if timeDelta > 0 then
				local speed = distance / timeDelta
				if speed > SECURITY_CONFIG.exploitDetection.speedHackThreshold then
					result.passed = false
					result.threatType = "SPEED_HACK"
					result.severity = SECURITY_CONFIG.threatLevels.HIGH
					table.insert(result.errors, "Speed hack detected: " .. tostring(speed) .. " studs/second")
				end
				
				-- Check for instant teleportation
				if distance > SECURITY_CONFIG.exploitDetection.teleportThreshold and timeDelta < 0.1 then
					result.passed = false
					result.threatType = "TELEPORT_EXPLOIT"
					result.severity = SECURITY_CONFIG.threatLevels.CRITICAL
					table.insert(result.errors, "Teleport exploit detected: " .. tostring(distance) .. " studs in " .. tostring(timeDelta) .. " seconds")
				end
			end
		end
		tracking.lastPosition = currentPosition
	end
	
	-- Check for invalid data patterns
	local hasInvalidData = false
	for _, value in pairs(data) do
		if self:IsInvalidData(value) then
			hasInvalidData = true
			break
		end
	end
	
	if hasInvalidData then
		tracking.invalidDataCount += 1
		if tracking.invalidDataCount >= SECURITY_CONFIG.exploitDetection.invalidDataThreshold then
			result.passed = false
			result.threatType = "INVALID_DATA_PATTERN"
			result.severity = SECURITY_CONFIG.threatLevels.MEDIUM
			table.insert(result.errors, "Pattern of invalid data detected")
		end
	end
	
	-- Update tracking
	tracking.lastRequestTime = currentTime
	table.insert(tracking.requestHistory, {
		remoteName = remoteName,
		timestamp = currentTime,
		dataSize = #HttpService:JSONEncode(data)
	})
	
	-- Keep only recent history (last 10 requests)
	if #tracking.requestHistory > 10 then
		table.remove(tracking.requestHistory, 1)
	end
	
	return result
end

-- Advanced rate limiting with per-remote-type limits
function SecurityValidator:CheckRateLimit(player: Player, remoteName: string): boolean
	local userId = player.UserId
	local currentTime = tick()
	
	-- Determine rate limit category
	local category = "default"
	if string.match(remoteName:lower(), "combat") or string.match(remoteName:lower(), "shoot") then
		category = "combat"
	elseif string.match(remoteName:lower(), "ui") or string.match(remoteName:lower(), "menu") then
		category = "ui"
	elseif string.match(remoteName:lower(), "admin") then
		category = "admin"
	end
	
	local limits = SECURITY_CONFIG.rateLimits[category]
	
	-- Initialize rate limit data if needed
	if not self.rateLimitData[userId] then
		self.rateLimitData[userId] = {}
	end
	
	if not self.rateLimitData[userId][category] then
		self.rateLimitData[userId][category] = {
			requests = {},
			windowStart = currentTime
		}
	end
	
	local rateLimitInfo = self.rateLimitData[userId][category]
	
	-- Clean old requests outside the time window
	for i = #rateLimitInfo.requests, 1, -1 do
		if currentTime - rateLimitInfo.requests[i] > limits.timeWindow then
			table.remove(rateLimitInfo.requests, i)
		end
	end
	
	-- Check if limit exceeded
	if #rateLimitInfo.requests >= limits.maxRequests then
		return false
	end
	
	-- Add current request
	table.insert(rateLimitInfo.requests, currentTime)
	
	return true
end

-- Data schema validation with comprehensive type checking
function SecurityValidator:ValidateDataSchema(data: {any}, schema: ValidationSchema): ValidationResult
	local result: ValidationResult = {
		isValid = true,
		errors = {},
		sanitizedData = {}
	}
	
	-- Validate each field in schema
	for fieldName, rule in pairs(schema) do
		local value = data[fieldName]
		local fieldResult = self:ValidateField(fieldName, value, rule)
		
		if not fieldResult.isValid then
			result.isValid = false
			for _, error in ipairs(fieldResult.errors) do
				table.insert(result.errors, error)
			end
		else
			result.sanitizedData[fieldName] = fieldResult.sanitizedValue
		end
	end
	
	-- Check for unexpected fields (potential exploit attempt)
	for fieldName, _ in pairs(data) do
		if not schema[fieldName] then
			result.isValid = false
			table.insert(result.errors, "Unexpected field: " .. tostring(fieldName))
		end
	end
	
	return result
end

-- Individual field validation with comprehensive type checking
function SecurityValidator:ValidateField(fieldName: string, value: any, rule: ValidationRule): {isValid: boolean, errors: {string}, sanitizedValue: any}
	local result = {
		isValid = true,
		errors = {},
		sanitizedValue = value
	}
	
	-- Check if required field is missing
	if rule.required and (value == nil or value == "") then
		result.isValid = false
		table.insert(result.errors, fieldName .. " is required")
		return result
	end
	
	-- Skip validation if field is optional and not provided
	if not rule.required and (value == nil or value == "") then
		return result
	end
	
	-- Type validation
	local expectedType = rule.type
	local actualType = typeof(value)
	
	if expectedType == "number" and actualType ~= "number" then
		-- Try to convert string to number
		if actualType == "string" then
			local numValue = tonumber(value)
			if numValue then
				result.sanitizedValue = numValue
				value = numValue
				actualType = "number"
			else
				result.isValid = false
				table.insert(result.errors, fieldName .. " must be a number")
				return result
			end
		else
			result.isValid = false
			table.insert(result.errors, fieldName .. " must be a number")
			return result
		end
	elseif expectedType == "string" and actualType ~= "string" then
		-- Convert to string if possible
		result.sanitizedValue = tostring(value)
		value = result.sanitizedValue
	elseif expectedType == "boolean" and actualType ~= "boolean" then
		result.isValid = false
		table.insert(result.errors, fieldName .. " must be a boolean")
		return result
	elseif expectedType ~= actualType and not (expectedType == "any") then
		result.isValid = false
		table.insert(result.errors, fieldName .. " must be of type " .. expectedType)
		return result
	end
	
	-- Range validation for numbers
	if expectedType == "number" and actualType == "number" then
		if rule.min and value < rule.min then
			result.isValid = false
			table.insert(result.errors, fieldName .. " must be at least " .. tostring(rule.min))
		end
		if rule.max and value > rule.max then
			result.isValid = false
			table.insert(result.errors, fieldName .. " must be at most " .. tostring(rule.max))
		end
	end
	
	-- Length validation for strings
	if expectedType == "string" and actualType == "string" then
		if rule.min and #value < rule.min then
			result.isValid = false
			table.insert(result.errors, fieldName .. " must be at least " .. tostring(rule.min) .. " characters")
		end
		if rule.max and #value > rule.max then
			result.isValid = false
			table.insert(result.errors, fieldName .. " must be at most " .. tostring(rule.max) .. " characters")
		end
	end
	
	-- Pattern validation for strings
	if rule.pattern and expectedType == "string" and actualType == "string" then
		if not string.match(value, rule.pattern) then
			result.isValid = false
			table.insert(result.errors, fieldName .. " does not match required pattern")
		end
	end
	
	-- Whitelist validation
	if rule.whitelist then
		local found = false
		for _, allowedValue in ipairs(rule.whitelist) do
			if value == allowedValue then
				found = true
				break
			end
		end
		if not found then
			result.isValid = false
			table.insert(result.errors, fieldName .. " must be one of the allowed values")
		end
	end
	
	-- Blacklist validation
	if rule.blacklist then
		for _, forbiddenValue in ipairs(rule.blacklist) do
			if value == forbiddenValue then
				result.isValid = false
				table.insert(result.errors, fieldName .. " contains forbidden value")
				break
			end
		end
	end
	
	-- Custom validation
	if rule.customValidator then
		local isValid, customError = rule.customValidator(value)
		if not isValid then
			result.isValid = false
			table.insert(result.errors, customError or (fieldName .. " failed custom validation"))
		end
	end
	
	return result
end

-- Check for invalid/malicious data patterns
function SecurityValidator:IsInvalidData(value: any): boolean
	local valueType = typeof(value)
	
	-- Check for extremely large numbers (potential overflow exploit)
	if valueType == "number" then
		if value > 1e10 or value < -1e10 or value ~= value then -- NaN check
			return true
		end
	end
	
	-- Check for malicious strings
	if valueType == "string" then
		-- Check for script injection attempts
		local maliciousPatterns = {
			"require%s*%(",
			"loadstring%s*%(",
			"getfenv%s*%(",
			"setfenv%s*%(",
			"debug%.",
			"game%.Players%.LocalPlayer%.Parent",
			"_G%.",
			"shared%.",
			"%%00", -- Null byte
			"javascript:",
			"<script",
			"eval%s*%("
		}
		
		local lowerValue = string.lower(value)
		for _, pattern in ipairs(maliciousPatterns) do
			if string.match(lowerValue, pattern) then
				return true
			end
		end
		
		-- Check for extremely long strings (potential DoS)
		if #value > 10000 then
			return true
		end
	end
	
	-- Check for suspicious table structures
	if valueType == "table" then
		-- Check for circular references or extremely deep nesting
		local function checkTableDepth(tbl, depth)
			if depth > 50 then return false end -- Too deep
			for _, v in pairs(tbl) do
				if typeof(v) == "table" then
					if not checkTableDepth(v, depth + 1) then
						return false
					end
				end
			end
			return true
		end
		
		if not checkTableDepth(value, 0) then
			return true
		end
	end
	
	return false
end

-- Log security violations with comprehensive details
function SecurityValidator:LogSecurityViolation(player: Player, remoteName: string, threatType: string, severity: number)
	local threat: SecurityThreat = {
		playerId = player.UserId,
		threatType = threatType,
		severity = severity,
		description = string.format("Security violation: %s in %s by %s", threatType, remoteName, player.Name),
		timestamp = tick(),
		evidence = {
			playerName = player.Name,
			remoteName = remoteName,
			playerPosition = player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character.HumanoidRootPart.Position or Vector3.new(0, 0, 0),
			accountAge = player.AccountAge,
			userId = player.UserId
		}
	}
	
	-- Store threat in history
	if not self.threatHistory[player.UserId] then
		self.threatHistory[player.UserId] = {}
	end
	table.insert(self.threatHistory[player.UserId], threat)
	
	-- Update metrics
	self.metrics.threatsDetected += 1
	
	-- Log with appropriate severity
	if self.logger then
		if severity >= SECURITY_CONFIG.threatLevels.CRITICAL then
			self.logger.Error("SecurityValidator", threat.description, threat.evidence)
		elseif severity >= SECURITY_CONFIG.threatLevels.HIGH then
			self.logger.Warn("SecurityValidator", threat.description, threat.evidence)
		else
			self.logger.Info("SecurityValidator", threat.description, threat.evidence)
		end
	end
	
	-- Trigger security event handlers
	for _, handler in pairs(securityEventHandlers) do
		task.spawn(function()
			local success, error = pcall(handler, threat)
			if not success and self.logger then
				self.logger.Error("SecurityValidator", "Security event handler failed", { error = error })
			end
		end)
	end
	
	-- Automatic responses based on severity
	if severity >= SECURITY_CONFIG.autoResponses.banThreshold then
		-- Trigger ban (handled by AntiExploit system)
		self:TriggerSecurityAction(player, "BAN", threat)
	elseif severity >= SECURITY_CONFIG.autoResponses.kickThreshold then
		-- Trigger kick
		self:TriggerSecurityAction(player, "KICK", threat)
	elseif severity >= SECURITY_CONFIG.autoResponses.alertAdminsThreshold then
		-- Alert administrators
		self:TriggerSecurityAction(player, "ALERT_ADMINS", threat)
	end
end

-- Trigger security actions (to be handled by AntiExploit system)
function SecurityValidator:TriggerSecurityAction(player: Player, actionType: string, threat: SecurityThreat)
	-- Fire security action event for AntiExploit system to handle
	local success, error = pcall(function()
		-- This will be connected to AntiExploit system
		if securityEventHandlers.actionHandler then
			securityEventHandlers.actionHandler(player, actionType, threat)
		end
	end)
	
	if not success and self.logger then
		self.logger.Error("SecurityValidator", "Failed to trigger security action", {
			actionType = actionType,
			player = player.Name,
			error = error
		})
	end
end

-- Register security event handlers
function SecurityValidator:RegisterSecurityEventHandler(handlerName: string, handler: (SecurityThreat) -> ())
	securityEventHandlers[handlerName] = handler
	if self.logger then
		self.logger.Info("SecurityValidator", "Security event handler registered: " .. handlerName)
	end
end

-- Get player threat level
function SecurityValidator:GetPlayerThreatLevel(player: Player): number
	local threats = self.threatHistory[player.UserId]
	if not threats then return 0 end
	
	local totalThreatLevel = 0
	local recentThreats = 0
	local currentTime = tick()
	
	-- Calculate threat level based on recent threats (last 5 minutes)
	for _, threat in ipairs(threats) do
		if currentTime - threat.timestamp < 300 then -- 5 minutes
			totalThreatLevel += threat.severity
			recentThreats += 1
		end
	end
	
	-- Average threat level with recency weighting
	return recentThreats > 0 and (totalThreatLevel / recentThreats) or 0
end

-- Get security metrics for monitoring
function SecurityValidator:GetSecurityMetrics(): {[string]: any}
	return {
		validation = self.metrics,
		threatCounts = {
			total = self.metrics.threatsDetected,
			byType = self:GetThreatCountsByType(),
			bySeverity = self:GetThreatCountsBySeverity()
		},
		rateLimiting = {
			activeRateLimits = self:GetActiveRateLimitCount(),
			totalRateLimitedRequests = self:GetTotalRateLimitedRequests()
		},
		performance = {
			averageValidationTime = self.metrics.averageValidationTime,
			cacheHitRate = self:GetCacheHitRate()
		}
	}
end

-- Helper functions for metrics
function SecurityValidator:GetThreatCountsByType(): {[string]: number}
	local counts = {}
	for _, playerThreats in pairs(self.threatHistory) do
		for _, threat in ipairs(playerThreats) do
			counts[threat.threatType] = (counts[threat.threatType] or 0) + 1
		end
	end
	return counts
end

function SecurityValidator:GetThreatCountsBySeverity(): {[string]: number}
	local counts = {}
	for _, playerThreats in pairs(self.threatHistory) do
		for _, threat in ipairs(playerThreats) do
			local severityName = "UNKNOWN"
			if threat.severity >= 10 then severityName = "CRITICAL"
			elseif threat.severity >= 8 then severityName = "HIGH"
			elseif threat.severity >= 5 then severityName = "MEDIUM"
			elseif threat.severity >= 1 then severityName = "LOW"
			end
			
			counts[severityName] = (counts[severityName] or 0) + 1
		end
	end
	return counts
end

function SecurityValidator:GetActiveRateLimitCount(): number
	local count = 0
	for _, playerData in pairs(self.rateLimitData) do
		for _, categoryData in pairs(playerData) do
			if #categoryData.requests > 0 then
				count += 1
			end
		end
	end
	return count
end

function SecurityValidator:GetTotalRateLimitedRequests(): number
	-- This would be tracked in a real implementation
	return 0
end

function SecurityValidator:GetCacheHitRate(): number
	-- Cache hit rate calculation would be implemented here
	return 0.95 -- Placeholder
end

-- Cleanup old data to prevent memory leaks
function SecurityValidator:CleanupOldData()
	local currentTime = tick()
	local maxAge = 3600 -- 1 hour
	
	-- Cleanup old threat history
	for userId, threats in pairs(self.threatHistory) do
		for i = #threats, 1, -1 do
			if currentTime - threats[i].timestamp > maxAge then
				table.remove(threats, i)
			end
		end
		
		-- Remove empty threat histories
		if #threats == 0 then
			self.threatHistory[userId] = nil
		end
	end
	
	-- Cleanup old rate limit data
	for userId, playerData in pairs(self.rateLimitData) do
		for category, categoryData in pairs(playerData) do
			for i = #categoryData.requests, 1, -1 do
				if currentTime - categoryData.requests[i] > SECURITY_CONFIG.rateLimits[category].timeWindow then
					table.remove(categoryData.requests, i)
				end
			end
			
			-- Remove empty rate limit data
			if #categoryData.requests == 0 then
				playerData[category] = nil
			end
		end
		
		-- Remove empty player data
		if next(playerData) == nil then
			self.rateLimitData[userId] = nil
		end
	end
	
	-- Cleanup old player tracking
	for userId, tracking in pairs(playerTracking) do
		if currentTime - tracking.lastRequestTime > maxAge then
			playerTracking[userId] = nil
		end
	end
end

-- Start periodic cleanup
local SecurityValidators = {}

task.spawn(function()
	while true do
		task.wait(300) -- Clean up every 5 minutes
		for _, validator in pairs(SecurityValidators) do
			if validator.CleanupOldData then
				validator:CleanupOldData()
			end
		end
	end
end)

return SecurityValidator
