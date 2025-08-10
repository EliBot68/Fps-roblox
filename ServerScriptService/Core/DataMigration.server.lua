--[[
	DataMigration.server.lua
	Enterprise Data Migration Framework
	Phase 2.5: Enterprise DataStore System

	Responsibilities:
	- Schema version management and migration
	- Automatic data structure updates
	- Backward compatibility maintenance
	- Migration testing and validation
	- Rollback capabilities for failed migrations
	- Comprehensive migration logging

	Features:
	- Multi-step migration chains
	- Atomic migration operations
	- Migration progress tracking
	- Data integrity verification
	- Automatic rollback on failure
	- Performance optimization
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ServiceLocator = require(ReplicatedStorage.Shared.ServiceLocator)
local Logging = require(ReplicatedStorage.Shared.Logging)
local DataValidator = require(ReplicatedStorage.Shared.DataValidator)

local DataMigration = {}
DataMigration.__index = DataMigration

-- Types for migration system
export type MigrationStep = {
	fromVersion: number,
	toVersion: number,
	migrate: (any) -> any,
	validate: ((any) -> boolean)?,
	rollback: ((any) -> any)?,
	description: string,
	estimatedTimeMs: number?
}

export type MigrationResult = {
	success: boolean,
	fromVersion: number,
	toVersion: number,
	stepsExecuted: number,
	timeTaken: number,
	errors: {string},
	warnings: {string},
	rollbackPerformed: boolean?
}

export type MigrationPlan = {
	steps: {MigrationStep},
	totalSteps: number,
	estimatedTime: number,
	requiresBackup: boolean
}

-- Migration definitions
local MIGRATION_STEPS: {MigrationStep} = {
	-- Migration from 1.0 to 1.5 - Add playtime tracking
	{
		fromVersion = 1.0,
		toVersion = 1.5,
		description = "Add playtime tracking and last seen timestamp",
		estimatedTimeMs = 50,
		migrate = function(data)
			data.playtime = data.playtime or 0
			data.lastSeen = data.lastSeen or os.time()
			data._version = 1.5
			return data
		end,
		validate = function(data)
			return type(data.playtime) == "number" and type(data.lastSeen) == "number"
		end,
		rollback = function(data)
			data.playtime = nil
			data.lastSeen = nil
			data._version = 1.0
			return data
		end
	},
	
	-- Migration from 1.5 to 2.0 - Major schema update
	{
		fromVersion = 1.5,
		toVersion = 2.0,
		description = "Add achievements, premium currency, and extended statistics",
		estimatedTimeMs = 150,
		migrate = function(data)
			-- Add premium currency
			data.premiumCurrency = data.premiumCurrency or 0
			
			-- Extend settings
			if data.settings then
				data.settings.crosshairColor = data.settings.crosshairColor or "White"
				data.settings.fovPreference = data.settings.fovPreference or 90
			end
			
			-- Extend inventory
			if data.inventory then
				data.inventory.attachments = data.inventory.attachments or {}
			end
			
			-- Extend statistics
			if data.statistics then
				data.statistics.damageDealt = data.statistics.damageDealt or 0
				data.statistics.damageTaken = data.statistics.damageTaken or 0
				data.statistics.headshots = data.statistics.headshots or 0
			end
			
			-- Add achievements system
			data.achievements = {
				unlocked = {},
				progress = {}
			}
			
			-- Update level cap
			if data.level and data.level > 100 then
				-- Keep existing level if higher than old cap
			end
			
			data._version = 2.0
			return data
		end,
		validate = function(data)
			return data.premiumCurrency ~= nil and 
				   data.achievements ~= nil and 
				   data.achievements.unlocked ~= nil and
				   data.settings.crosshairColor ~= nil
		end,
		rollback = function(data)
			-- Remove new fields
			data.premiumCurrency = nil
			data.achievements = nil
			
			-- Revert settings
			if data.settings then
				data.settings.crosshairColor = nil
				data.settings.fovPreference = nil
			end
			
			-- Revert inventory
			if data.inventory then
				data.inventory.attachments = nil
			end
			
			-- Revert statistics
			if data.statistics then
				data.statistics.damageDealt = nil
				data.statistics.damageTaken = nil
				data.statistics.headshots = nil
			end
			
			-- Revert level cap if necessary
			if data.level and data.level > 100 then
				data.level = 100
			end
			
			data._version = 1.5
			return data
		end
	}
}

-- Current target version
local CURRENT_VERSION = 2.0

-- Configuration
local CONFIG = {
	enableMigration = true,
	requireBackupBeforeMigration = true,
	maxMigrationTimeMs = 5000,
	enableRollback = true,
	validateAfterMigration = true,
	logMigrationSteps = true
}

-- Migration state
local state = {
	migrationHistory = {}, -- userId -> {migrations performed}
	activeMigrations = {}, -- userId -> migration in progress
	stats = {
		totalMigrations = 0,
		successfulMigrations = 0,
		failedMigrations = 0,
		rollbacksPerformed = 0,
		averageMigrationTime = 0
	}
}

-- Utility: Deep copy for safe data manipulation
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

-- Utility: Get data version
local function getDataVersion(data): number?
	if not data or type(data) ~= "table" then
		return nil
	end
	return data._version
end

-- Utility: Create migration plan
local function createMigrationPlan(fromVersion: number, toVersion: number): MigrationPlan?
	if fromVersion >= toVersion then
		return nil -- No migration needed
	end
	
	local plan = {
		steps = {},
		totalSteps = 0,
		estimatedTime = 0,
		requiresBackup = false
	}
	
	-- Find migration path
	local currentVersion = fromVersion
	while currentVersion < toVersion do
		local nextStep = nil
		
		-- Find the next migration step
		for _, step in ipairs(MIGRATION_STEPS) do
			if step.fromVersion == currentVersion and step.toVersion <= toVersion then
				if not nextStep or step.toVersion > nextStep.toVersion then
					nextStep = step
				end
			end
		end
		
		if not nextStep then
			Logging.Error("DataMigration", "No migration path found", {
				from = currentVersion,
				to = toVersion
			})
			return nil
		end
		
		table.insert(plan.steps, nextStep)
		plan.totalSteps += 1
		plan.estimatedTime += nextStep.estimatedTimeMs or 100
		currentVersion = nextStep.toVersion
		
		-- Check if backup is required for any step
		if nextStep.toVersion - nextStep.fromVersion >= 1.0 then
			plan.requiresBackup = true
		end
	end
	
	return plan
end

-- Core: Execute migration step
local function executeMigrationStep(data: any, step: MigrationStep): (boolean, any, string?)
	local startTime = tick()
	
	Logging.Info("DataMigration", "Executing migration step", {
		from = step.fromVersion,
		to = step.toVersion,
		description = step.description
	})
	
	-- Create backup of data before migration
	local originalData = deepCopy(data)
	
	-- Execute migration
	local success, result = pcall(step.migrate, data)
	
	if not success then
		return false, originalData, "Migration function failed: " .. tostring(result)
	end
	
	-- Validate migrated data if validator provided
	if step.validate then
		local validationSuccess, validationResult = pcall(step.validate, result)
		if not validationSuccess or not validationResult then
			return false, originalData, "Migration validation failed"
		end
	end
	
	-- Additional validation using DataValidator
	local validationResult = DataValidator.ValidateData(result)
	if not validationResult.isValid then
		Logging.Warn("DataMigration", "Migrated data has validation warnings", {
			errors = validationResult.errors,
			warnings = validationResult.warnings
		})
		
		-- Use sanitized data if available
		if validationResult.sanitizedData then
			result = validationResult.sanitizedData
		end
	end
	
	local timeTaken = (tick() - startTime) * 1000
	
	Logging.Info("DataMigration", "Migration step completed", {
		from = step.fromVersion,
		to = step.toVersion,
		timeTaken = timeTaken
	})
	
	return true, result, nil
end

-- Core: Rollback migration step
local function rollbackMigrationStep(data: any, step: MigrationStep): (boolean, any, string?)
	if not step.rollback then
		return false, data, "No rollback function available"
	end
	
	Logging.Warn("DataMigration", "Rolling back migration step", {
		from = step.toVersion,
		to = step.fromVersion,
		description = step.description
	})
	
	local success, result = pcall(step.rollback, data)
	
	if not success then
		return false, data, "Rollback function failed: " .. tostring(result)
	end
	
	return true, result, nil
end

-- Public: Check if migration is needed
function DataMigration.IsMigrationNeeded(data: any): boolean
	local currentVersion = getDataVersion(data)
	if not currentVersion then
		return true -- Need to set initial version
	end
	
	return currentVersion < CURRENT_VERSION
end

-- Public: Get migration plan
function DataMigration.GetMigrationPlan(data: any): MigrationPlan?
	local currentVersion = getDataVersion(data) or 1.0
	return createMigrationPlan(currentVersion, CURRENT_VERSION)
end

-- Public: Execute migration
function DataMigration.MigrateData(userId: number, data: any, targetVersion: number?): MigrationResult
	if not CONFIG.enableMigration then
		return {
			success = false,
			fromVersion = getDataVersion(data) or 0,
			toVersion = targetVersion or CURRENT_VERSION,
			stepsExecuted = 0,
			timeTaken = 0,
			errors = {"Migration is disabled"},
			warnings = {}
		}
	end
	
	local startTime = tick()
	local fromVersion = getDataVersion(data) or 1.0
	local toVersion = targetVersion or CURRENT_VERSION
	
	state.stats.totalMigrations += 1
	state.activeMigrations[userId] = {
		startTime = startTime,
		fromVersion = fromVersion,
		toVersion = toVersion
	}
	
	Logging.Info("DataMigration", "Starting data migration", {
		userId = userId,
		from = fromVersion,
		to = toVersion
	})
	
	-- Create migration plan
	local plan = createMigrationPlan(fromVersion, toVersion)
	if not plan then
		state.stats.failedMigrations += 1
		state.activeMigrations[userId] = nil
		
		return {
			success = fromVersion >= toVersion, -- Success if no migration needed
			fromVersion = fromVersion,
			toVersion = toVersion,
			stepsExecuted = 0,
			timeTaken = (tick() - startTime) * 1000,
			errors = fromVersion < toVersion and {"No migration path available"} or {},
			warnings = {}
		}
	end
	
	-- Check if backup is required
	if plan.requiresBackup and CONFIG.requireBackupBeforeMigration then
		local DataManager = ServiceLocator.Get("DataManager")
		if DataManager then
			local backupSuccess = DataManager.ForceBackup(userId)
			if not backupSuccess then
				Logging.Error("DataMigration", "Failed to create backup before migration", {userId = userId})
			end
		end
	end
	
	-- Execute migration steps
	local currentData = deepCopy(data)
	local stepsExecuted = 0
	local errors = {}
	local warnings = {}
	local rollbackPerformed = false
	
	for i, step in ipairs(plan.steps) do
		local success, migratedData, error = executeMigrationStep(currentData, step)
		
		if success then
			currentData = migratedData
			stepsExecuted += 1
			
			-- Log progress
			if CONFIG.logMigrationSteps then
				Logging.Info("DataMigration", "Migration step successful", {
					userId = userId,
					step = i,
					total = plan.totalSteps,
					from = step.fromVersion,
					to = step.toVersion
				})
			end
		else
			table.insert(errors, error or "Unknown migration error")
			
			-- Attempt rollback if enabled
			if CONFIG.enableRollback and i > 1 then
				Logging.Warn("DataMigration", "Attempting rollback", {userId = userId, failedStep = i})
				
				-- Rollback previous steps in reverse order
				for j = i - 1, 1, -1 do
					local rollbackStep = plan.steps[j]
					local rollbackSuccess, rolledBackData, rollbackError = rollbackMigrationStep(currentData, rollbackStep)
					
					if rollbackSuccess then
						currentData = rolledBackData
					else
						table.insert(warnings, "Rollback failed for step " .. j .. ": " .. (rollbackError or "Unknown error"))
					end
				end
				
				rollbackPerformed = true
				state.stats.rollbacksPerformed += 1
			end
			
			break
		end
	end
	
	-- Final validation
	if CONFIG.validateAfterMigration and stepsExecuted > 0 then
		local validationResult = DataValidator.ValidateData(currentData)
		if not validationResult.isValid then
			for _, validationError in ipairs(validationResult.errors) do
				table.insert(warnings, "Post-migration validation: " .. validationError)
			end
		end
	end
	
	local timeTaken = (tick() - startTime) * 1000
	local success = stepsExecuted == plan.totalSteps and #errors == 0
	
	-- Update statistics
	if success then
		state.stats.successfulMigrations += 1
	else
		state.stats.failedMigrations += 1
	end
	
	state.stats.averageMigrationTime = (state.stats.averageMigrationTime * (state.stats.totalMigrations - 1) + timeTaken) / state.stats.totalMigrations
	
	-- Store migration history
	if not state.migrationHistory[userId] then
		state.migrationHistory[userId] = {}
	end
	
	table.insert(state.migrationHistory[userId], {
		timestamp = os.time(),
		fromVersion = fromVersion,
		toVersion = success and toVersion or currentData._version or fromVersion,
		success = success,
		stepsExecuted = stepsExecuted,
		timeTaken = timeTaken
	})
	
	state.activeMigrations[userId] = nil
	
	Logging.Info("DataMigration", "Migration completed", {
		userId = userId,
		success = success,
		fromVersion = fromVersion,
		toVersion = success and toVersion or (currentData._version or fromVersion),
		stepsExecuted = stepsExecuted,
		timeTaken = timeTaken,
		errorsCount = #errors,
		warningsCount = #warnings
	})
	
	-- Update the original data reference
	if success then
		for key, value in pairs(currentData) do
			data[key] = value
		end
		
		-- Remove any keys that no longer exist
		for key in pairs(data) do
			if currentData[key] == nil then
				data[key] = nil
			end
		end
	end
	
	return {
		success = success,
		fromVersion = fromVersion,
		toVersion = success and toVersion or (currentData._version or fromVersion),
		stepsExecuted = stepsExecuted,
		timeTaken = timeTaken,
		errors = errors,
		warnings = warnings,
		rollbackPerformed = rollbackPerformed
	}
end

-- Public: Test migration without applying changes
function DataMigration.TestMigration(data: any, targetVersion: number?): MigrationResult
	local testData = deepCopy(data)
	local result = DataMigration.MigrateData(-1, testData, targetVersion) -- Use -1 as test userId
	
	-- Remove test entry from history
	state.migrationHistory[-1] = nil
	
	Logging.Info("DataMigration", "Migration test completed", {
		success = result.success,
		fromVersion = result.fromVersion,
		toVersion = result.toVersion,
		timeTaken = result.timeTaken
	})
	
	return result
end

-- Public: Get migration statistics
function DataMigration.GetMigrationStats(): any
	local activeCount = 0
	for _ in pairs(state.activeMigrations) do
		activeCount += 1
	end
	
	local successRate = state.stats.totalMigrations > 0 
		and (state.stats.successfulMigrations / state.stats.totalMigrations * 100) or 0
	
	return {
		total = state.stats.totalMigrations,
		successful = state.stats.successfulMigrations,
		failed = state.stats.failedMigrations,
		successRate = successRate,
		rollbacks = state.stats.rollbacksPerformed,
		averageTime = state.stats.averageMigrationTime,
		activeMigrations = activeCount,
		availableSteps = #MIGRATION_STEPS,
		currentVersion = CURRENT_VERSION
	}
end

-- Public: Get migration history for user
function DataMigration.GetMigrationHistory(userId: number): {any}
	return state.migrationHistory[userId] or {}
end

-- Public: Register custom migration step
function DataMigration.RegisterMigrationStep(step: MigrationStep)
	assert(type(step.fromVersion) == "number", "fromVersion must be number")
	assert(type(step.toVersion) == "number", "toVersion must be number")
	assert(type(step.migrate) == "function", "migrate must be function")
	assert(type(step.description) == "string", "description must be string")
	
	-- Check for conflicts
	for _, existingStep in ipairs(MIGRATION_STEPS) do
		if existingStep.fromVersion == step.fromVersion and existingStep.toVersion == step.toVersion then
			Logging.Warn("DataMigration", "Overriding existing migration step", {
				from = step.fromVersion,
				to = step.toVersion
			})
			break
		end
	end
	
	table.insert(MIGRATION_STEPS, step)
	
	-- Sort steps by version for optimal path finding
	table.sort(MIGRATION_STEPS, function(a, b)
		if a.fromVersion == b.fromVersion then
			return a.toVersion < b.toVersion
		end
		return a.fromVersion < b.fromVersion
	end)
	
	Logging.Info("DataMigration", "Custom migration step registered", {
		from = step.fromVersion,
		to = step.toVersion,
		description = step.description
	})
end

-- Public: Force migration for all loaded players
function DataMigration.ForceGlobalMigration(targetVersion: number?)
	local DataManager = ServiceLocator.Get("DataManager")
	if not DataManager then
		Logging.Error("DataMigration", "DataManager not available for global migration")
		return
	end
	
	local Players = game:GetService("Players")
	local migratedCount = 0
	local failedCount = 0
	
	Logging.Info("DataMigration", "Starting global migration", {
		targetVersion = targetVersion or CURRENT_VERSION,
		playerCount = #Players:GetPlayers()
	})
	
	for _, player in ipairs(Players:GetPlayers()) do
		local loadResult = DataManager.LoadPlayerData(player.UserId)
		if loadResult.success and loadResult.data then
			local migrationResult = DataMigration.MigrateData(player.UserId, loadResult.data, targetVersion)
			
			if migrationResult.success then
				migratedCount += 1
				-- Save migrated data
				DataManager.SavePlayerData(player.UserId, loadResult.data)
			else
				failedCount += 1
				Logging.Error("DataMigration", "Global migration failed for player", {
					userId = player.UserId,
					errors = migrationResult.errors
				})
			end
		end
	end
	
	Logging.Info("DataMigration", "Global migration completed", {
		targetVersion = targetVersion or CURRENT_VERSION,
		migrated = migratedCount,
		failed = failedCount
	})
end

-- ServiceLocator registration
ServiceLocator.Register("DataMigration", {
	factory = function()
		return DataMigration
	end,
	singleton = true,
	lazy = false,
	priority = 3,
	tags = {"data", "migration"},
	healthCheck = function()
		local activeCount = 0
		for _ in pairs(state.activeMigrations) do
			activeCount += 1
		end
		return activeCount < 10 -- Healthy if less than 10 concurrent migrations
	end
})

Logging.Info("DataMigration", "Enterprise Data Migration Framework initialized", {
	availableSteps = #MIGRATION_STEPS,
	currentVersion = CURRENT_VERSION,
	config = CONFIG
})

return DataMigration
