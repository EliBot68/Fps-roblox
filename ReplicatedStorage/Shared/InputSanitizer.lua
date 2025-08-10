--!strict
--[[
	InputSanitizer.lua
	Enterprise Input Sanitization & Validation System
	
	Provides comprehensive input sanitization, validation, and exploit prevention
	for all user inputs and data processing throughout the system.
	
	Features:
	- SQL injection prevention
	- Script injection prevention
	- Cross-site scripting (XSS) protection
	- Command injection prevention
	- Path traversal protection
	- Input length and format validation
	- Data type validation and coercion
	- Whitelist and blacklist filtering
	- Regular expression validation
	- Encoding and escaping utilities
	
	Author: Enterprise Development Team
	Created: December 2024
]]--

local ServiceLocator = require(script.Parent.ServiceLocator)

-- Services
local HttpService = game:GetService("HttpService")

-- Types
export type ValidationRule = {
	type: string,
	required: boolean?,
	minLength: number?,
	maxLength: number?,
	pattern: string?,
	whitelist: {string}?,
	blacklist: {string}?,
	customValidator: ((any) -> (boolean, string?))?
}

export type SanitizationOptions = {
	stripHtml: boolean?,
	escapeSpecialChars: boolean?,
	removeControlChars: boolean?,
	normalizeWhitespace: boolean?,
	maxLength: number?,
	allowedChars: string?,
	forbiddenPatterns: {string}?
}

export type ValidationResult = {
	isValid: boolean,
	sanitizedValue: any,
	originalValue: any,
	errors: {string},
	warnings: {string},
	metadata: {[string]: any}?
}

export type SecurityContext = "Chat" | "Username" | "GameData" | "AdminInput" | "Economy" | "Configuration" | "General"

-- Input Sanitizer
local InputSanitizer = {}
InputSanitizer.__index = InputSanitizer

-- Private Variables
local logger: any
local analytics: any
local auditLogger: any

-- Security Patterns (Common exploit patterns to detect and block)
local SECURITY_PATTERNS = {
	-- SQL Injection patterns
	sqlInjection = {
		"'\\s*(OR|AND)\\s*'",
		"'\\s*(or|and)\\s*'",
		"UNION\\s+SELECT",
		"union\\s+select",
		"DROP\\s+TABLE",
		"drop\\s+table",
		"INSERT\\s+INTO",
		"insert\\s+into",
		"DELETE\\s+FROM",
		"delete\\s+from",
		"UPDATE\\s+SET",
		"update\\s+set",
		"--\\s*$",
		"/\\*.*\\*/",
		"'\\s*;\\s*--",
		"'\\s*;\\s*#"
	},
	
	-- Script injection patterns
	scriptInjection = {
		"<script[^>]*>",
		"</script>",
		"javascript:",
		"vbscript:",
		"onload\\s*=",
		"onerror\\s*=",
		"onclick\\s*=",
		"onmouseover\\s*=",
		"eval\\s*\\(",
		"setTimeout\\s*\\(",
		"setInterval\\s*\\(",
		"document\\.cookie",
		"window\\.location",
		"alert\\s*\\(",
		"confirm\\s*\\(",
		"prompt\\s*\\("
	},
	
	-- Command injection patterns
	commandInjection = {
		";\\s*rm\\s+",
		";\\s*del\\s+",
		";\\s*format\\s+",
		"\\|\\s*rm\\s+",
		"\\|\\s*del\\s+",
		"&&\\s*rm\\s+",
		"&&\\s*del\\s+",
		"`.*`",
		"\\$\\(.*\\)",
		"\\${.*}",
		"\\\\x[0-9a-fA-F]{2}",
		"\\\\u[0-9a-fA-F]{4}"
	},
	
	-- Path traversal patterns
	pathTraversal = {
		"\\.\\./",
		"\\.\\.\\\\",
		"/etc/passwd",
		"/etc/shadow",
		"\\\\windows\\\\system32",
		"\\\\boot\\.ini",
		"file://",
		"ftp://",
		"gopher://",
		"ldap://",
		"dict://"
	},
	
	-- Lua injection patterns specific to Roblox
	luaInjection = {
		"getfenv\\s*\\(",
		"setfenv\\s*\\(",
		"loadstring\\s*\\(",
		"loadfile\\s*\\(",
		"dofile\\s*\\(",
		"require\\s*\\(",
		"game:GetService",
		"game%.GetService",
		"workspace%.",
		"Players%.",
		"ReplicatedStorage%.",
		"ServerStorage%.",
		"StarterGui%.",
		"_G%.",
		"shared%.",
		"wait%s*%(%s*%)",
		"spawn%s*%(",
		"delay%s*%("
	}
}

-- Character encoding maps
local HTML_ENTITIES = {
	["&"] = "&amp;",
	["<"] = "&lt;",
	[">"] = "&gt;",
	['"'] = "&quot;",
	["'"] = "&#x27;",
	["/"] = "&#x2F;"
}

local URL_ENCODING = {
	[" "] = "%20",
	["!"] = "%21",
	['"'] = "%22",
	["#"] = "%23",
	["$"] = "%24",
	["%"] = "%25",
	["&"] = "%26",
	["'"] = "%27",
	["("] = "%28",
	[")"] = "%29",
	["*"] = "%2A",
	["+"] = "%2B",
	[","] = "%2C",
	["/"] = "%2F",
	[":"] = "%3A",
	[";"] = "%3B",
	["<"] = "%3C",
	["="] = "%3D",
	[">"] = "%3E",
	["?"] = "%3F",
	["@"] = "%40",
	["["] = "%5B",
	["\\"] = "%5C",
	["]"] = "%5D",
	["^"] = "%5E",
	["`"] = "%60",
	["{"] = "%7B",
	["|"] = "%7C",
	["}"] = "%7D",
	["~"] = "%7E"
}

-- Default validation rules by context
local CONTEXT_RULES = {
	Chat = {
		type = "string",
		required = true,
		minLength = 1,
		maxLength = 200,
		forbiddenPatterns = {"scriptInjection", "luaInjection", "pathTraversal"}
	},
	
	Username = {
		type = "string",
		required = true,
		minLength = 3,
		maxLength = 20,
		pattern = "^[a-zA-Z0-9_]+$",
		forbiddenPatterns = {"scriptInjection", "sqlInjection", "commandInjection"}
	},
	
	GameData = {
		type = "any",
		required = false,
		maxLength = 1000,
		forbiddenPatterns = {"luaInjection", "scriptInjection", "pathTraversal"}
	},
	
	AdminInput = {
		type = "string",
		required = true,
		minLength = 1,
		maxLength = 500,
		forbiddenPatterns = {"sqlInjection", "commandInjection", "pathTraversal"}
	},
	
	Economy = {
		type = "number",
		required = true,
		pattern = "^[0-9]+$",
		forbiddenPatterns = {"sqlInjection", "scriptInjection"}
	},
	
	Configuration = {
		type = "string",
		required = false,
		maxLength = 1000,
		forbiddenPatterns = {"luaInjection", "scriptInjection", "commandInjection", "pathTraversal"}
	}
}

-- Initialization
function InputSanitizer.new(): typeof(InputSanitizer)
	local self = setmetatable({}, InputSanitizer)
	
	-- Get services
	logger = ServiceLocator:GetService("Logging")
	analytics = ServiceLocator:GetService("AnalyticsEngine")
	auditLogger = ServiceLocator:GetService("AuditLogger")
	
	if not logger then
		logger = { LogInfo = print, LogWarning = warn, LogError = warn }
	end
	
	logger.LogInfo("InputSanitizer initialized successfully", {
		patternCategories = self:_getKeys(SECURITY_PATTERNS),
		contextRules = self:_getKeys(CONTEXT_RULES)
	})
	
	return self
end

-- Core Sanitization Functions

-- Sanitize and validate input with context
function InputSanitizer:SanitizeInput(
	input: any,
	context: SecurityContext,
	customRules: ValidationRule?
): ValidationResult
	local startTime = tick()
	local originalValue = input
	local errors = {}
	local warnings = {}
	
	-- Get validation rules for context
	local rules = customRules or CONTEXT_RULES[context] or CONTEXT_RULES.General
	
	-- Type validation and coercion
	local typeResult = self:_validateAndCoerceType(input, rules.type)
	if not typeResult.success then
		table.insert(errors, typeResult.error)
		
		-- Log security violation
		if auditLogger then
			auditLogger:LogSecurityViolation(
				nil,
				"INPUT_TYPE_VIOLATION",
				"MEDIUM",
				"Invalid input type detected: " .. typeResult.error,
				"SANITIZE_INPUT",
				context,
				{
					originalValue = originalValue,
					expectedType = rules.type,
					actualType = type(input)
				}
			)
		end
		
		return {
			isValid = false,
			sanitizedValue = nil,
			originalValue = originalValue,
			errors = errors,
			warnings = warnings,
			metadata = {
				context = context,
				processingTime = tick() - startTime
			}
		}
	end
	
	local sanitizedValue = typeResult.value
	
	-- Required validation
	if rules.required and (sanitizedValue == nil or sanitizedValue == "") then
		table.insert(errors, "Required field cannot be empty")
	end
	
	-- Skip further validation if value is nil/empty and not required
	if not rules.required and (sanitizedValue == nil or sanitizedValue == "") then
		return {
			isValid = true,
			sanitizedValue = sanitizedValue,
			originalValue = originalValue,
			errors = errors,
			warnings = warnings,
			metadata = {
				context = context,
				processingTime = tick() - startTime
			}
		}
	end
	
	-- String-specific validations
	if type(sanitizedValue) == "string" then
		-- Length validation
		if rules.minLength and #sanitizedValue < rules.minLength then
			table.insert(errors, string.format("Input too short (minimum %d characters)", rules.minLength))
		end
		
		if rules.maxLength and #sanitizedValue > rules.maxLength then
			table.insert(warnings, string.format("Input truncated to %d characters", rules.maxLength))
			sanitizedValue = string.sub(sanitizedValue, 1, rules.maxLength)
		end
		
		-- Pattern validation
		if rules.pattern and not string.match(sanitizedValue, rules.pattern) then
			table.insert(errors, "Input format is invalid")
		end
		
		-- Whitelist validation
		if rules.whitelist then
			local allowed = false
			for _, allowedValue in ipairs(rules.whitelist) do
				if sanitizedValue == allowedValue then
					allowed = true
					break
				end
			end
			if not allowed then
				table.insert(errors, "Input value not in allowed list")
			end
		end
		
		-- Blacklist validation
		if rules.blacklist then
			for _, forbiddenValue in ipairs(rules.blacklist) do
				if sanitizedValue == forbiddenValue then
					table.insert(errors, "Input value is forbidden")
					break
				end
			end
		end
		
		-- Security pattern detection
		if rules.forbiddenPatterns then
			local threatDetected, threatType = self:_detectSecurityThreats(sanitizedValue, rules.forbiddenPatterns)
			if threatDetected then
				table.insert(errors, "Security threat detected: " .. threatType)
				
				-- Log security violation
				if auditLogger then
					auditLogger:LogSecurityViolation(
						nil,
						"INPUT_SECURITY_THREAT",
						"HIGH",
						"Security threat detected in input: " .. threatType,
						"SANITIZE_INPUT",
						context,
						{
							originalValue = originalValue,
							threatType = threatType,
							detectedPatterns = self:_getMatchingPatterns(sanitizedValue, threatType)
						}
					)
				end
			end
		end
		
		-- Apply sanitization
		sanitizedValue = self:_applySanitization(sanitizedValue, {
			stripHtml = context ~= "AdminInput", -- Allow HTML for admin input with caution
			escapeSpecialChars = true,
			removeControlChars = true,
			normalizeWhitespace = true
		})
	end
	
	-- Custom validation
	if rules.customValidator then
		local customValid, customError = rules.customValidator(sanitizedValue)
		if not customValid then
			table.insert(errors, customError or "Custom validation failed")
		end
	end
	
	-- Final validation result
	local isValid = #errors == 0
	
	-- Log validation attempt
	if analytics then
		analytics:RecordEvent(0, "input_validation", {
			context = context,
			isValid = isValid,
			errorCount = #errors,
			warningCount = #warnings,
			processingTime = tick() - startTime,
			inputType = type(originalValue),
			inputLength = type(originalValue) == "string" and #originalValue or nil
		})
	end
	
	-- Log invalid inputs
	if not isValid and logger then
		logger.LogWarning("Input validation failed", {
			context = context,
			errors = errors,
			originalValue = type(originalValue) == "string" and string.sub(tostring(originalValue), 1, 100) or tostring(originalValue)
		})
	end
	
	return {
		isValid = isValid,
		sanitizedValue = isValid and sanitizedValue or nil,
		originalValue = originalValue,
		errors = errors,
		warnings = warnings,
		metadata = {
			context = context,
			processingTime = tick() - startTime,
			inputType = type(originalValue),
			outputType = type(sanitizedValue)
		}
	}
end

-- Sanitize text for chat
function InputSanitizer:SanitizeChat(message: string): ValidationResult
	return self:SanitizeInput(message, "Chat")
end

-- Sanitize username
function InputSanitizer:SanitizeUsername(username: string): ValidationResult
	return self:SanitizeInput(username, "Username")
end

-- Sanitize game data
function InputSanitizer:SanitizeGameData(data: any): ValidationResult
	return self:SanitizeInput(data, "GameData")
end

-- Sanitize admin input
function InputSanitizer:SanitizeAdminInput(input: string): ValidationResult
	return self:SanitizeInput(input, "AdminInput")
end

-- Sanitize economic values
function InputSanitizer:SanitizeEconomicValue(value: any): ValidationResult
	return self:SanitizeInput(value, "Economy")
end

-- Sanitize configuration data
function InputSanitizer:SanitizeConfiguration(config: any): ValidationResult
	return self:SanitizeInput(config, "Configuration")
end

-- Type Validation and Coercion

-- Validate and coerce input type
function InputSanitizer:_validateAndCoerceType(input: any, expectedType: string): {success: boolean, value: any, error: string?}
	if expectedType == "any" then
		return {success = true, value = input}
	end
	
	local inputType = type(input)
	
	-- Direct type match
	if inputType == expectedType then
		return {success = true, value = input}
	end
	
	-- Type coercion attempts
	if expectedType == "string" then
		if inputType == "number" or inputType == "boolean" then
			return {success = true, value = tostring(input)}
		end
	elseif expectedType == "number" then
		if inputType == "string" then
			local num = tonumber(input)
			if num then
				return {success = true, value = num}
			else
				return {success = false, error = "Cannot convert string to number"}
			end
		elseif inputType == "boolean" then
			return {success = true, value = input and 1 or 0}
		end
	elseif expectedType == "boolean" then
		if inputType == "string" then
			local lower = string.lower(input)
			if lower == "true" or lower == "1" or lower == "yes" then
				return {success = true, value = true}
			elseif lower == "false" or lower == "0" or lower == "no" then
				return {success = true, value = false}
			else
				return {success = false, error = "Cannot convert string to boolean"}
			end
		elseif inputType == "number" then
			return {success = true, value = input ~= 0}
		end
	end
	
	return {
		success = false,
		error = string.format("Expected %s, got %s", expectedType, inputType)
	}
end

-- Security Threat Detection

-- Detect security threats in input
function InputSanitizer:_detectSecurityThreats(input: string, forbiddenPatterns: {string}): (boolean, string?)
	for _, patternCategory in ipairs(forbiddenPatterns) do
		local patterns = SECURITY_PATTERNS[patternCategory]
		if patterns then
			for _, pattern in ipairs(patterns) do
				if string.match(string.lower(input), string.lower(pattern)) then
					return true, patternCategory
				end
			end
		end
	end
	return false, nil
end

-- Get matching patterns for logging
function InputSanitizer:_getMatchingPatterns(input: string, threatType: string): {string}
	local matchingPatterns = {}
	local patterns = SECURITY_PATTERNS[threatType]
	
	if patterns then
		for _, pattern in ipairs(patterns) do
			if string.match(string.lower(input), string.lower(pattern)) then
				table.insert(matchingPatterns, pattern)
			end
		end
	end
	
	return matchingPatterns
end

-- Text Sanitization

-- Apply sanitization transformations
function InputSanitizer:_applySanitization(input: string, options: SanitizationOptions): string
	local result = input
	
	-- Remove control characters
	if options.removeControlChars then
		result = self:_removeControlCharacters(result)
	end
	
	-- Strip HTML tags
	if options.stripHtml then
		result = self:_stripHtmlTags(result)
	end
	
	-- Escape special characters
	if options.escapeSpecialChars then
		result = self:_escapeHtmlEntities(result)
	end
	
	-- Normalize whitespace
	if options.normalizeWhitespace then
		result = self:_normalizeWhitespace(result)
	end
	
	-- Apply length limit
	if options.maxLength and #result > options.maxLength then
		result = string.sub(result, 1, options.maxLength)
	end
	
	-- Filter allowed characters
	if options.allowedChars then
		result = self:_filterAllowedCharacters(result, options.allowedChars)
	end
	
	-- Remove forbidden patterns
	if options.forbiddenPatterns then
		result = self:_removeForbiddenPatterns(result, options.forbiddenPatterns)
	end
	
	return result
end

-- Remove control characters
function InputSanitizer:_removeControlCharacters(input: string): string
	-- Remove ASCII control characters (0-31) except whitespace (9, 10, 13)
	return string.gsub(input, "[\1-\8\11\12\14-\31\127]", "")
end

-- Strip HTML tags
function InputSanitizer:_stripHtmlTags(input: string): string
	-- Remove HTML tags
	local result = string.gsub(input, "<[^>]*>", "")
	-- Remove HTML comments
	result = string.gsub(result, "<!--.*-->", "")
	return result
end

-- Escape HTML entities
function InputSanitizer:_escapeHtmlEntities(input: string): string
	local result = input
	for char, entity in pairs(HTML_ENTITIES) do
		result = string.gsub(result, char, entity)
	end
	return result
end

-- Normalize whitespace
function InputSanitizer:_normalizeWhitespace(input: string): string
	-- Replace multiple whitespace with single space
	local result = string.gsub(input, "%s+", " ")
	-- Trim leading and trailing whitespace
	result = string.gsub(result, "^%s*(.-)%s*$", "%1")
	return result
end

-- Filter allowed characters
function InputSanitizer:_filterAllowedCharacters(input: string, allowedPattern: string): string
	local result = ""
	for i = 1, #input do
		local char = string.sub(input, i, i)
		if string.match(char, allowedPattern) then
			result = result .. char
		end
	end
	return result
end

-- Remove forbidden patterns
function InputSanitizer:_removeForbiddenPatterns(input: string, patterns: {string}): string
	local result = input
	for _, patternCategory in ipairs(patterns) do
		local categoryPatterns = SECURITY_PATTERNS[patternCategory]
		if categoryPatterns then
			for _, pattern in ipairs(categoryPatterns) do
				result = string.gsub(result, pattern, "")
			end
		end
	end
	return result
end

-- Encoding and Escaping Utilities

-- URL encode string
function InputSanitizer:UrlEncode(input: string): string
	local result = input
	for char, encoded in pairs(URL_ENCODING) do
		result = string.gsub(result, char, encoded)
	end
	return result
end

-- URL decode string
function InputSanitizer:UrlDecode(input: string): string
	local result = input
	for char, encoded in pairs(URL_ENCODING) do
		result = string.gsub(result, encoded, char)
	end
	return result
end

-- HTML encode string
function InputSanitizer:HtmlEncode(input: string): string
	return self:_escapeHtmlEntities(input)
end

-- HTML decode string
function InputSanitizer:HtmlDecode(input: string): string
	local result = input
	for char, entity in pairs(HTML_ENTITIES) do
		result = string.gsub(result, entity, char)
	end
	return result
end

-- Base64 encode (simple implementation)
function InputSanitizer:Base64Encode(input: string): string
	-- This would use a proper Base64 implementation in production
	-- For demonstration, return a simple encoded version
	local encoded = ""
	for i = 1, #input do
		local byte = string.byte(input, i)
		encoded = encoded .. string.format("%02x", byte)
	end
	return encoded
end

-- Escape SQL string (for database operations)
function InputSanitizer:EscapeSql(input: string): string
	-- Escape single quotes and other SQL special characters
	local result = string.gsub(input, "'", "''")
	result = string.gsub(result, "\\", "\\\\")
	result = string.gsub(result, "\0", "\\0")
	result = string.gsub(result, "\n", "\\n")
	result = string.gsub(result, "\r", "\\r")
	result = string.gsub(result, "\t", "\\t")
	return result
end

-- Validation Utilities

-- Validate email format
function InputSanitizer:ValidateEmail(email: string): boolean
	local pattern = "^[%w%._%+%-]+@[%w%._%+%-]+%.%w+$"
	return string.match(email, pattern) ~= nil
end

-- Validate IP address
function InputSanitizer:ValidateIpAddress(ip: string): boolean
	local pattern = "^(%d+)%.(%d+)%.(%d+)%.(%d+)$"
	local a, b, c, d = string.match(ip, pattern)
	
	if not a then
		return false
	end
	
	a, b, c, d = tonumber(a), tonumber(b), tonumber(c), tonumber(d)
	return a and b and c and d and
		   a >= 0 and a <= 255 and
		   b >= 0 and b <= 255 and
		   c >= 0 and c <= 255 and
		   d >= 0 and d <= 255
end

-- Validate URL format
function InputSanitizer:ValidateUrl(url: string): boolean
	local pattern = "^https?://[%w%._%+%-]+[%w%._%+%-/]*$"
	return string.match(url, pattern) ~= nil
end

-- Validate UUID format
function InputSanitizer:ValidateUuid(uuid: string): boolean
	local pattern = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"
	return string.match(uuid, pattern) ~= nil
end

-- Validate alphanumeric string
function InputSanitizer:ValidateAlphanumeric(input: string): boolean
	return string.match(input, "^[%w]+$") ~= nil
end

-- Validate numeric string
function InputSanitizer:ValidateNumeric(input: string): boolean
	return string.match(input, "^[%d]+$") ~= nil and tonumber(input) ~= nil
end

-- Batch Processing

-- Sanitize multiple inputs
function InputSanitizer:SanitizeBatch(
	inputs: {[string]: any},
	context: SecurityContext,
	rules: {[string]: ValidationRule}?
): {[string]: ValidationResult}
	local results = {}
	
	for key, value in pairs(inputs) do
		local customRule = rules and rules[key]
		results[key] = self:SanitizeInput(value, context, customRule)
	end
	
	return results
end

-- Validate form data
function InputSanitizer:ValidateForm(
	formData: {[string]: any},
	formRules: {[string]: ValidationRule}
): {isValid: boolean, results: {[string]: ValidationResult}, errors: {string}}
	local results = {}
	local allErrors = {}
	local overallValid = true
	
	for fieldName, rules in pairs(formRules) do
		local value = formData[fieldName]
		local result = self:SanitizeInput(value, "General", rules)
		
		results[fieldName] = result
		
		if not result.isValid then
			overallValid = false
			for _, error in ipairs(result.errors) do
				table.insert(allErrors, fieldName .. ": " .. error)
			end
		end
	end
	
	return {
		isValid = overallValid,
		results = results,
		errors = allErrors
	}
end

-- Utility Functions

-- Get table keys
function InputSanitizer:_getKeys(t: {[any]: any}): {any}
	local keys = {}
	for key in pairs(t) do
		table.insert(keys, key)
	end
	return keys
end

-- Deep clone table
function InputSanitizer:_deepClone(original: any): any
	if type(original) ~= "table" then
		return original
	end
	
	local copy = {}
	for key, value in pairs(original) do
		copy[self:_deepClone(key)] = self:_deepClone(value)
	end
	
	return copy
end

-- Configuration Management

-- Add custom security pattern
function InputSanitizer:AddSecurityPattern(category: string, patterns: {string}): ()
	if not SECURITY_PATTERNS[category] then
		SECURITY_PATTERNS[category] = {}
	end
	
	for _, pattern in ipairs(patterns) do
		table.insert(SECURITY_PATTERNS[category], pattern)
	end
	
	logger.LogInfo("Custom security patterns added", {
		category = category,
		patternCount = #patterns
	})
end

-- Add context rules
function InputSanitizer:AddContextRules(context: string, rules: ValidationRule): ()
	CONTEXT_RULES[context] = rules
	
	logger.LogInfo("Context rules added", {
		context = context,
		rules = rules
	})
end

-- Get security patterns
function InputSanitizer:GetSecurityPatterns(): {[string]: {string}}
	return self:_deepClone(SECURITY_PATTERNS)
end

-- Get context rules
function InputSanitizer:GetContextRules(): {[string]: ValidationRule}
	return self:_deepClone(CONTEXT_RULES)
end

-- Testing and Validation

-- Test input against all security patterns
function InputSanitizer:TestInputSecurity(input: string): {[string]: {string}}
	local threats = {}
	
	for category, patterns in pairs(SECURITY_PATTERNS) do
		local matchingPatterns = {}
		for _, pattern in ipairs(patterns) do
			if string.match(string.lower(input), string.lower(pattern)) then
				table.insert(matchingPatterns, pattern)
			end
		end
		
		if #matchingPatterns > 0 then
			threats[category] = matchingPatterns
		end
	end
	
	return threats
end

-- Benchmark sanitization performance
function InputSanitizer:BenchmarkPerformance(
	testInputs: {string},
	context: SecurityContext,
	iterations: number?
): {averageTime: number, totalTime: number, throughput: number}
	local iterCount = iterations or 1000
	local startTime = tick()
	
	for i = 1, iterCount do
		for _, input in ipairs(testInputs) do
			self:SanitizeInput(input, context)
		end
	end
	
	local totalTime = tick() - startTime
	local operationCount = iterCount * #testInputs
	
	return {
		averageTime = totalTime / operationCount,
		totalTime = totalTime,
		throughput = operationCount / totalTime
	}
end

-- Health Check
function InputSanitizer:GetHealthStatus(): {status: string, metrics: any}
	local patternCategoryCount = 0
	local totalPatterns = 0
	
	for category, patterns in pairs(SECURITY_PATTERNS) do
		patternCategoryCount = patternCategoryCount + 1
		totalPatterns = totalPatterns + #patterns
	end
	
	local contextCount = 0
	for _ in pairs(CONTEXT_RULES) do
		contextCount = contextCount + 1
	end
	
	return {
		status = "healthy",
		metrics = {
			patternCategories = patternCategoryCount,
			totalPatterns = totalPatterns,
			contextRules = contextCount,
			supportedValidations = {
				"typeCoercion",
				"lengthValidation",
				"patternMatching",
				"securityThreatDetection",
				"htmlSanitization",
				"specialCharEscaping",
				"whitelistFiltering",
				"blacklistFiltering"
			}
		}
	}
end

return InputSanitizer
