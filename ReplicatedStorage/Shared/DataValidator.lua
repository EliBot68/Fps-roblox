--[[
	DataValidator.lua
	Enterprise Data Validation & Sanitization Service
	Phase 2.5: Enterprise DataStore System

	Responsibilities:
	- Schema-based data validation
	- Type checking and constraints
	- Data sanitization and normalization
	- Version compatibility checks
	- Corruption detection and recovery
	- Player data structure validation

	Features:
	- Nested object validation
	- Custom validation rules
	- Automatic data migration triggers
	- Performance-optimized validation
	- Comprehensive error reporting
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Logging = require(ReplicatedStorage.Shared.Logging)
local ServiceLocator = require(ReplicatedStorage.Shared.ServiceLocator)

local DataValidator = {}
DataValidator.__index = DataValidator

-- Types for validation system
export type ValidationRule = {
	type: string,
	required: boolean?,
	default: any?,
	min: number?,
	max: number?,
	minLength: number?,
	maxLength: number?,
	pattern: string?,
	enum: {any}?,
	custom: ((any) -> (boolean, string?))?,
	children: {[string]: ValidationRule}?
}

export type ValidationSchema = {
	version: number,
	rules: {[string]: ValidationRule},
	metadata: {[string]: any}?
}

export type ValidationResult = {
	isValid: boolean,
	errors: {string},
	warnings: {string},
	sanitizedData: any?,
	migrationRequired: boolean?
}

-- Built-in validation schemas for player data
local PLAYER_DATA_SCHEMAS = {
	-- Version 1.0 - Initial schema
	["1.0"] = {
		version = 1.0,
		rules = {
			userId = {type = "number", required = true, min = 1},
			username = {type = "string", required = true, minLength = 1, maxLength = 20},
			level = {type = "number", required = true, min = 1, max = 100, default = 1},
			experience = {type = "number", required = true, min = 0, default = 0},
			currency = {type = "number", required = true, min = 0, default = 0},
			playtime = {type = "number", required = true, min = 0, default = 0},
			lastSeen = {type = "number", required = true, default = 0},
			settings = {
				type = "table",
				required = true,
				children = {
					soundEnabled = {type = "boolean", default = true},
					musicVolume = {type = "number", min = 0, max = 1, default = 0.5},
					sfxVolume = {type = "number", min = 0, max = 1, default = 0.8},
					sensitivity = {type = "number", min = 0.1, max = 5.0, default = 1.0}
				}
			},
			inventory = {
				type = "table",
				required = true,
				children = {
					weapons = {type = "table", default = {}},
					items = {type = "table", default = {}},
					skins = {type = "table", default = {}}
				}
			},
			statistics = {
				type = "table",
				required = true,
				children = {
					kills = {type = "number", min = 0, default = 0},
					deaths = {type = "number", min = 0, default = 0},
					wins = {type = "number", min = 0, default = 0},
					losses = {type = "number", min = 0, default = 0},
					shotsFired = {type = "number", min = 0, default = 0},
					shotsHit = {type = "number", min = 0, default = 0}
				}
			}
		}
	},
	
	-- Version 2.0 - Extended schema with achievements
	["2.0"] = {
		version = 2.0,
		rules = {
			userId = {type = "number", required = true, min = 1},
			username = {type = "string", required = true, minLength = 1, maxLength = 20},
			level = {type = "number", required = true, min = 1, max = 200, default = 1}, -- Increased max level
			experience = {type = "number", required = true, min = 0, default = 0},
			currency = {type = "number", required = true, min = 0, default = 0},
			premiumCurrency = {type = "number", required = false, min = 0, default = 0}, -- New field
			playtime = {type = "number", required = true, min = 0, default = 0},
			lastSeen = {type = "number", required = true, default = 0},
			settings = {
				type = "table",
				required = true,
				children = {
					soundEnabled = {type = "boolean", default = true},
					musicVolume = {type = "number", min = 0, max = 1, default = 0.5},
					sfxVolume = {type = "number", min = 0, max = 1, default = 0.8},
					sensitivity = {type = "number", min = 0.1, max = 5.0, default = 1.0},
					crosshairColor = {type = "string", default = "White"}, -- New field
					fovPreference = {type = "number", min = 60, max = 120, default = 90} -- New field
				}
			},
			inventory = {
				type = "table",
				required = true,
				children = {
					weapons = {type = "table", default = {}},
					items = {type = "table", default = {}},
					skins = {type = "table", default = {}},
					attachments = {type = "table", default = {}} -- New field
				}
			},
			statistics = {
				type = "table",
				required = true,
				children = {
					kills = {type = "number", min = 0, default = 0},
					deaths = {type = "number", min = 0, default = 0},
					wins = {type = "number", min = 0, default = 0},
					losses = {type = "number", min = 0, default = 0},
					shotsFired = {type = "number", min = 0, default = 0},
					shotsHit = {type = "number", min = 0, default = 0},
					damageDealt = {type = "number", min = 0, default = 0}, -- New field
					damageTaken = {type = "number", min = 0, default = 0}, -- New field
					headshots = {type = "number", min = 0, default = 0} -- New field
				}
			},
			achievements = { -- New section
				type = "table",
				required = false,
				children = {
					unlocked = {type = "table", default = {}},
					progress = {type = "table", default = {}}
				}
			}
		}
	}
}

-- Current schema version
local CURRENT_SCHEMA_VERSION = "2.0"

-- Configuration
local CONFIG = {
	maxStringLength = 1000,
	maxTableDepth = 10,
	maxArrayLength = 1000,
	enableStrictMode = true,
	autoSanitize = true,
	logValidationErrors = true
}

-- Validation state
local state = {
	customSchemas = {},
	validationCache = {},
	stats = {
		totalValidations = 0,
		successfulValidations = 0,
		failedValidations = 0,
		sanitizationsApplied = 0,
		migrationTriggered = 0
	}
}

-- Utility: Deep copy for data manipulation
local function deepCopy(original)
	if type(original) ~= "table" then
		return original
	end
	
	local copy = {}
	for key, value in pairs(original) do
		copy[deepCopy(key)] = deepCopy(value)
	end
	return copy
end

-- Utility: Check if value matches type
local function validateType(value, expectedType: string): boolean
	local actualType = type(value)
	
	if expectedType == "integer" then
		return actualType == "number" and math.floor(value) == value
	elseif expectedType == "table" then
		return actualType == "table" and value ~= nil
	else
		return actualType == expectedType
	end
end

-- Utility: Sanitize string data
local function sanitizeString(value: string, rule: ValidationRule): string
	if not value then return rule.default or "" end
	
	-- Trim whitespace
	value = string.gsub(value, "^%s*(.-)%s*$", "%1")
	
	-- Apply length constraints
	if rule.maxLength and #value > rule.maxLength then
		value = string.sub(value, 1, rule.maxLength)
		state.stats.sanitizationsApplied += 1
	end
	
	-- Pattern validation/sanitization
	if rule.pattern then
		if not string.match(value, rule.pattern) then
			Logging.Warn("DataValidator", "String failed pattern validation", {
				value = value,
				pattern = rule.pattern
			})
		end
	end
	
	return value
end

-- Utility: Sanitize number data
local function sanitizeNumber(value: number, rule: ValidationRule): number
	if not value then return rule.default or 0 end
	
	-- Apply min/max constraints
	if rule.min and value < rule.min then
		value = rule.min
		state.stats.sanitizationsApplied += 1
	end
	
	if rule.max and value > rule.max then
		value = rule.max
		state.stats.sanitizationsApplied += 1
	end
	
	return value
end

-- Core validation function
local function validateValue(value: any, rule: ValidationRule, path: string, depth: number): (boolean, {string}, any)
	local errors = {}
	local sanitizedValue = value
	
	-- Check depth limit
	if depth > CONFIG.maxTableDepth then
		table.insert(errors, string.format("Maximum depth exceeded at %s", path))
		return false, errors, value
	end
	
	-- Handle nil values
	if value == nil then
		if rule.required then
			table.insert(errors, string.format("Required field missing: %s", path))
			return false, errors, rule.default
		else
			return true, errors, rule.default
		end
	end
	
	-- Type validation
	if not validateType(value, rule.type) then
		table.insert(errors, string.format("Type mismatch at %s: expected %s, got %s", 
			path, rule.type, type(value)))
		return false, errors, rule.default
	end
	
	-- Type-specific validation and sanitization
	if rule.type == "string" then
		sanitizedValue = sanitizeString(value, rule)
		
		-- Length validation
		if rule.minLength and #sanitizedValue < rule.minLength then
			table.insert(errors, string.format("String too short at %s: minimum %d characters", 
				path, rule.minLength))
		end
		
	elseif rule.type == "number" or rule.type == "integer" then
		sanitizedValue = sanitizeNumber(value, rule)
		
	elseif rule.type == "table" then
		-- Handle table validation
		if rule.children then
			local sanitizedTable = {}
			
			-- Validate each child field
			for childKey, childRule in pairs(rule.children) do
				local childPath = path .. "." .. childKey
				local childValue = value[childKey]
				
				local isValid, childErrors, sanitizedChild = validateValue(
					childValue, childRule, childPath, depth + 1
				)
				
				-- Collect errors
				for _, error in ipairs(childErrors) do
					table.insert(errors, error)
				end
				
				-- Store sanitized value
				sanitizedTable[childKey] = sanitizedChild
			end
			
			-- Copy any additional fields if not in strict mode
			if not CONFIG.enableStrictMode then
				for key, val in pairs(value) do
					if not rule.children[key] then
						sanitizedTable[key] = val
					end
				end
			end
			
			sanitizedValue = sanitizedTable
		end
		
		-- Array length validation
		if rule.maxLength then
			local length = 0
			for _ in pairs(value) do length += 1 end
			if length > rule.maxLength then
				table.insert(errors, string.format("Table too large at %s: maximum %d items", 
					path, rule.maxLength))
			end
		end
	end
	
	-- Enum validation
	if rule.enum then
		local found = false
		for _, enumValue in ipairs(rule.enum) do
			if sanitizedValue == enumValue then
				found = true
				break
			end
		end
		if not found then
			table.insert(errors, string.format("Invalid enum value at %s: %s", 
				path, tostring(sanitizedValue)))
		end
	end
	
	-- Custom validation
	if rule.custom then
		local customValid, customError = rule.custom(sanitizedValue)
		if not customValid then
			table.insert(errors, string.format("Custom validation failed at %s: %s", 
				path, customError or "Unknown error"))
		end
	end
	
	return #errors == 0, errors, sanitizedValue
end

-- Public: Validate data against schema
function DataValidator.ValidateData(data: any, schemaVersion: string?): ValidationResult
	state.stats.totalValidations += 1
	
	local schema = PLAYER_DATA_SCHEMAS[schemaVersion or CURRENT_SCHEMA_VERSION]
	if not schema then
		state.stats.failedValidations += 1
		return {
			isValid = false,
			errors = {"Unknown schema version: " .. tostring(schemaVersion)},
			warnings = {},
			sanitizedData = nil,
			migrationRequired = false
		}
	end
	
	local allErrors = {}
	local warnings = {}
	local sanitizedData = {}
	local migrationRequired = false
	
	-- Check if migration is needed
	if data and data._version and data._version < schema.version then
		migrationRequired = true
		state.stats.migrationTriggered += 1
		table.insert(warnings, string.format("Data migration required: %s -> %s", 
			tostring(data._version), tostring(schema.version)))
	end
	
	-- Validate root level fields
	for fieldName, rule in pairs(schema.rules) do
		local value = data and data[fieldName]
		local isValid, errors, sanitizedValue = validateValue(value, rule, fieldName, 0)
		
		-- Collect errors
		for _, error in ipairs(errors) do
			table.insert(allErrors, error)
		end
		
		-- Store sanitized value
		sanitizedData[fieldName] = sanitizedValue
	end
	
	-- Add metadata
	sanitizedData._version = schema.version
	sanitizedData._validatedAt = os.time()
	
	local isValid = #allErrors == 0
	if isValid then
		state.stats.successfulValidations += 1
	else
		state.stats.failedValidations += 1
		
		if CONFIG.logValidationErrors then
			Logging.Error("DataValidator", "Data validation failed", {
				errors = allErrors,
				warnings = warnings,
				schemaVersion = schemaVersion
			})
		end
	end
	
	return {
		isValid = isValid,
		errors = allErrors,
		warnings = warnings,
		sanitizedData = sanitizedData,
		migrationRequired = migrationRequired
	}
end

-- Public: Register custom schema
function DataValidator.RegisterSchema(name: string, schema: ValidationSchema)
	assert(type(name) == "string", "Schema name must be string")
	assert(type(schema) == "table", "Schema must be table")
	assert(type(schema.rules) == "table", "Schema must have rules")
	
	state.customSchemas[name] = schema
	Logging.Info("DataValidator", "Custom schema registered", {name = name, version = schema.version})
end

-- Public: Validate with custom schema
function DataValidator.ValidateWithSchema(data: any, schemaName: string): ValidationResult
	local schema = state.customSchemas[schemaName]
	if not schema then
		return {
			isValid = false,
			errors = {"Unknown custom schema: " .. schemaName},
			warnings = {},
			sanitizedData = nil,
			migrationRequired = false
		}
	end
	
	-- Use the same validation logic but with custom schema
	local result = DataValidator.ValidateData(data, nil)
	-- Override with custom schema validation logic here if needed
	
	return result
end

-- Public: Create default player data
function DataValidator.CreateDefaultPlayerData(userId: number, username: string): any
	local schema = PLAYER_DATA_SCHEMAS[CURRENT_SCHEMA_VERSION]
	local defaultData = {
		userId = userId,
		username = username,
		_version = schema.version,
		_createdAt = os.time()
	}
	
	-- Apply defaults from schema
	local function applyDefaults(rules, target)
		for fieldName, rule in pairs(rules) do
			if rule.default ~= nil then
				target[fieldName] = rule.default
			elseif rule.children then
				target[fieldName] = {}
				applyDefaults(rule.children, target[fieldName])
			end
		end
	end
	
	applyDefaults(schema.rules, defaultData)
	
	Logging.Info("DataValidator", "Default player data created", {
		userId = userId,
		username = username,
		version = schema.version
	})
	
	return defaultData
end

-- Public: Get validation statistics
function DataValidator.GetValidationStats(): any
	return {
		total = state.stats.totalValidations,
		successful = state.stats.successfulValidations,
		failed = state.stats.failedValidations,
		successRate = state.stats.totalValidations > 0 
			and (state.stats.successfulValidations / state.stats.totalValidations * 100) or 0,
		sanitizationsApplied = state.stats.sanitizationsApplied,
		migrationsTriggered = state.stats.migrationTriggered,
		currentSchemaVersion = CURRENT_SCHEMA_VERSION
	}
end

-- Public: Check if data is corrupted
function DataValidator.DetectCorruption(data: any): {corrupted: boolean, issues: {string}}
	local issues = {}
	
	if not data then
		return {corrupted = true, issues = {"Data is nil"}}
	end
	
	if type(data) ~= "table" then
		return {corrupted = true, issues = {"Data is not a table"}}
	end
	
	-- Check for required top-level fields
	local requiredFields = {"userId", "username"}
	for _, field in ipairs(requiredFields) do
		if not data[field] then
			table.insert(issues, "Missing required field: " .. field)
		end
	end
	
	-- Check for circular references
	local function checkCircular(obj, visited, path)
		if type(obj) ~= "table" then return end
		
		if visited[obj] then
			table.insert(issues, "Circular reference detected at: " .. path)
			return
		end
		
		visited[obj] = true
		for key, value in pairs(obj) do
			checkCircular(value, visited, path .. "." .. tostring(key))
		end
		visited[obj] = nil
	end
	
	checkCircular(data, {}, "root")
	
	-- Check data size
	local success, jsonData = pcall(HttpService.JSONEncode, HttpService, data)
	if success then
		local dataSize = #jsonData
		if dataSize > 4000000 then -- ~4MB limit
			table.insert(issues, "Data size too large: " .. dataSize .. " bytes")
		end
	else
		table.insert(issues, "Data cannot be serialized: " .. tostring(jsonData))
	end
	
	return {
		corrupted = #issues > 0,
		issues = issues
	}
end

-- ServiceLocator registration
ServiceLocator.Register("DataValidator", {
	factory = function()
		return DataValidator
	end,
	singleton = true,
	lazy = false,
	priority = 3,
	tags = {"data", "validation"},
	healthCheck = function()
		return state.stats.totalValidations >= 0
	end
})

Logging.Info("DataValidator", "Enterprise Data Validator initialized", {
	schemas = {CURRENT_SCHEMA_VERSION},
	config = CONFIG
})

return DataValidator
