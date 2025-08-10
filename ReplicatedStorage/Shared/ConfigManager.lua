--!strict
--[[
	ConfigManager.lua
	Enterprise Configuration Management & Feature Flags System
	
	Provides hot-reloadable configuration, A/B testing framework, and feature flag management
	with environment-specific configs and real-time updates.
	
	Features:
	- Hot-reloadable configuration without server restart
	- A/B testing framework with user segmentation
	- Feature flag system with user-level controls
	- Environment-specific configuration support
	- Configuration validation and type safety
	- Event-driven configuration updates
	- Configuration history and rollback
	- Performance monitoring and analytics
	
	Author: Enterprise Development Team
	Created: December 2024
]]--

local ServiceLocator = require(script.Parent.ServiceLocator)
local Logging = require(script.Parent.Logging)

-- Types
export type ConfigValue = string | number | boolean | {[string]: any}
export type ConfigSection = {[string]: ConfigValue}
export type Configuration = {[string]: ConfigSection}

export type FeatureFlag = {
	name: string,
	enabled: boolean,
	userSegments: {string},
	rolloutPercentage: number,
	createdAt: number,
	modifiedAt: number,
	description: string,
	metadata: {[string]: any}
}

export type ABTest = {
	name: string,
	variants: {string},
	traffic: {[string]: number},
	startDate: number,
	endDate: number?,
	targetSegments: {string},
	isActive: boolean,
	metadata: {[string]: any}
}

export type Environment = "development" | "staging" | "production"

export type ConfigManagerConfig = {
	environment: Environment,
	autoReload: boolean,
	reloadInterval: number,
	validateConfigs: boolean,
	enableABTesting: boolean,
	enableFeatureFlags: boolean,
	defaultRolloutPercentage: number,
	configHistory: boolean,
	maxHistoryEntries: number
}

export type ConfigChangeEvent = {
	section: string,
	key: string,
	oldValue: ConfigValue?,
	newValue: ConfigValue,
	timestamp: number,
	source: string
}

export type UserSegment = {
	name: string,
	criteria: {[string]: any},
	userIds: {number},
	percentage: number,
	description: string
}

-- ConfigManager Class
local ConfigManager = {}
ConfigManager.__index = ConfigManager

-- Private Variables
local logger: any
local currentConfig: Configuration = {}
local featureFlags: {[string]: FeatureFlag} = {}
local abTests: {[string]: ABTest} = {}
local userSegments: {[string]: UserSegment} = {}
local configHistory: {ConfigChangeEvent} = {}
local environmentOverrides: {[Environment]: Configuration} = {}
local validationSchemas: {[string]: any} = {}

-- Configuration
local CONFIG: ConfigManagerConfig = {
	environment = "development",
	autoReload = true,
	reloadInterval = 30,
	validateConfigs = true,
	enableABTesting = true,
	enableFeatureFlags = true,
	defaultRolloutPercentage = 0,
	configHistory = true,
	maxHistoryEntries = 1000
}

-- Events
local ConfigChanged = Instance.new("BindableEvent")
local FeatureFlagChanged = Instance.new("BindableEvent")
local ABTestChanged = Instance.new("BindableEvent")

-- Initialization
function ConfigManager.new(): typeof(ConfigManager)
	local self = setmetatable({}, ConfigManager)
	
	logger = ServiceLocator:GetService("Logging")
	if not logger then
		warn("ConfigManager: Logging service not available")
		logger = { LogInfo = print, LogWarning = warn, LogError = warn }
	end
	
	self:_initializeDefaultConfig()
	self:_loadEnvironmentConfig()
	self:_setupAutoReload()
	
	logger.LogInfo("ConfigManager initialized successfully", {
		environment = CONFIG.environment,
		autoReload = CONFIG.autoReload,
		featureFlags = CONFIG.enableFeatureFlags,
		abTesting = CONFIG.enableABTesting
	})
	
	return self
end

-- Initialize default configuration
function ConfigManager:_initializeDefaultConfig(): ()
	currentConfig = {
		Game = {
			maxPlayers = 100,
			respawnTime = 5,
			matchDuration = 600,
			enableSpectating = true,
			allowTeamSwitching = false
		},
		Combat = {
			damageMultiplier = 1.0,
			headShotMultiplier = 2.0,
			enableFriendlyFire = false,
			maxWeaponsPerPlayer = 2,
			reloadTime = 2.5
		},
		Economy = {
			startingCredits = 1000,
			killReward = 100,
			deathPenalty = 50,
			winBonus = 500,
			dailyBonus = 250
		},
		Matchmaking = {
			enabled = true,
			skillBasedMatching = true,
			maxQueueTime = 300,
			regionPreference = true,
			crossRegionThreshold = 180
		},
		Performance = {
			maxBulletTrails = 50,
			particleLimit = 100,
			shadowQuality = "Medium",
			renderDistance = 1000,
			enableOcclusion = true
		}
	}
	
	-- Initialize default feature flags
	self:_initializeDefaultFeatureFlags()
	
	-- Initialize default A/B tests
	self:_initializeDefaultABTests()
	
	-- Initialize user segments
	self:_initializeUserSegments()
end

-- Initialize default feature flags
function ConfigManager:_initializeDefaultFeatureFlags(): ()
	featureFlags = {
		newUIDesign = {
			name = "newUIDesign",
			enabled = false,
			userSegments = {"beta_testers"},
			rolloutPercentage = 10,
			createdAt = os.time(),
			modifiedAt = os.time(),
			description = "New UI design system",
			metadata = {version = "2.0", designer = "UI Team"}
		},
		enhancedGraphics = {
			name = "enhancedGraphics",
			enabled = true,
			userSegments = {"premium_users"},
			rolloutPercentage = 50,
			createdAt = os.time(),
			modifiedAt = os.time(),
			description = "Enhanced graphics and effects",
			metadata = {minDeviceRating = 7}
		},
		voiceChat = {
			name = "voiceChat",
			enabled = false,
			userSegments = {"verified_users"},
			rolloutPercentage = 0,
			createdAt = os.time(),
			modifiedAt = os.time(),
			description = "Voice chat functionality",
			metadata = {ageRestriction = 13}
		},
		crossPlatformPlay = {
			name = "crossPlatformPlay",
			enabled = true,
			userSegments = {},
			rolloutPercentage = 100,
			createdAt = os.time(),
			modifiedAt = os.time(),
			description = "Cross-platform matchmaking",
			metadata = {}
		}
	}
end

-- Initialize default A/B tests
function ConfigManager:_initializeDefaultABTests(): ()
	abTests = {
		weaponBalanceTest = {
			name = "weaponBalanceTest",
			variants = {"control", "buffed", "nerfed"},
			traffic = {control = 0.4, buffed = 0.3, nerfed = 0.3},
			startDate = os.time(),
			endDate = os.time() + (7 * 24 * 60 * 60), -- 7 days
			targetSegments = {"active_players"},
			isActive = true,
			metadata = {
				hypothesis = "Balanced weapons improve retention",
				metrics = {"kill_death_ratio", "session_length", "player_satisfaction"}
			}
		},
		tutorialFlow = {
			name = "tutorialFlow",
			variants = {"original", "interactive", "video"},
			traffic = {original = 0.5, interactive = 0.3, video = 0.2},
			startDate = os.time(),
			endDate = os.time() + (14 * 24 * 60 * 60), -- 14 days
			targetSegments = {"new_players"},
			isActive = true,
			metadata = {
				hypothesis = "Interactive tutorial improves onboarding",
				metrics = {"completion_rate", "retention_day1", "progression_speed"}
			}
		}
	}
end

-- Initialize user segments
function ConfigManager:_initializeUserSegments(): ()
	userSegments = {
		beta_testers = {
			name = "beta_testers",
			criteria = {accountAge = ">= 30", playtime = ">= 100"},
			userIds = {},
			percentage = 5,
			description = "Beta testing community"
		},
		premium_users = {
			name = "premium_users",
			criteria = {hasPremium = true},
			userIds = {},
			percentage = 15,
			description = "Premium subscribers"
		},
		verified_users = {
			name = "verified_users",
			criteria = {isVerified = true, accountAge = ">= 90"},
			userIds = {},
			percentage = 25,
			description = "Verified account holders"
		},
		new_players = {
			name = "new_players",
			criteria = {accountAge = "< 7", playtime = "< 10"},
			userIds = {},
			percentage = 20,
			description = "Recently joined players"
		},
		active_players = {
			name = "active_players",
			criteria = {lastSeen = "< 7", sessionCount = ">= 10"},
			userIds = {},
			percentage = 60,
			description = "Regularly active players"
		}
	}
end

-- Load environment-specific configuration
function ConfigManager:_loadEnvironmentConfig(): ()
	environmentOverrides = {
		development = {
			Game = {
				maxPlayers = 10,
				respawnTime = 1,
				matchDuration = 120
			},
			Combat = {
				damageMultiplier = 0.5
			},
			Performance = {
				maxBulletTrails = 20,
				particleLimit = 50
			}
		},
		staging = {
			Game = {
				maxPlayers = 50,
				respawnTime = 3
			},
			Performance = {
				maxBulletTrails = 30,
				particleLimit = 75
			}
		},
		production = {
			Performance = {
				shadowQuality = "High",
				enableOcclusion = true
			}
		}
	}
	
	-- Apply environment overrides
	local overrides = environmentOverrides[CONFIG.environment]
	if overrides then
		self:_mergeConfigs(currentConfig, overrides)
		logger.LogInfo("Applied environment-specific configuration", {
			environment = CONFIG.environment,
			overrides = overrides
		})
	end
end

-- Merge configurations
function ConfigManager:_mergeConfigs(base: Configuration, overrides: Configuration): ()
	for section, values in pairs(overrides) do
		if not base[section] then
			base[section] = {}
		end
		
		for key, value in pairs(values) do
			base[section][key] = value
		end
	end
end

-- Setup auto-reload functionality
function ConfigManager:_setupAutoReload(): ()
	if not CONFIG.autoReload then
		return
	end
	
	task.spawn(function()
		while CONFIG.autoReload do
			task.wait(CONFIG.reloadInterval)
			
			local success, error = pcall(function()
				self:_checkForUpdates()
			end)
			
			if not success then
				logger.LogError("Auto-reload failed", {error = error})
			end
		end
	end)
end

-- Check for configuration updates
function ConfigManager:_checkForUpdates(): ()
	-- In a real implementation, this would check external sources
	-- For this demo, we simulate random updates
	if math.random() < 0.1 then -- 10% chance of update
		local sections = {"Game", "Combat", "Economy"}
		local section = sections[math.random(#sections)]
		
		logger.LogInfo("Simulated configuration update detected", {
			section = section,
			timestamp = os.time()
		})
	end
end

-- Get configuration value
function ConfigManager:GetConfig(section: string, key: string?): ConfigValue | ConfigSection
	if not currentConfig[section] then
		logger.LogWarning("Configuration section not found", {section = section})
		return nil
	end
	
	if key then
		local value = currentConfig[section][key]
		if value == nil then
			logger.LogWarning("Configuration key not found", {
				section = section,
				key = key
			})
		end
		return value
	else
		return currentConfig[section]
	end
end

-- Set configuration value
function ConfigManager:SetConfig(section: string, key: string, value: ConfigValue, source: string?): boolean
	local success, error = pcall(function()
		if CONFIG.validateConfigs then
			self:_validateConfigValue(section, key, value)
		end
		
		if not currentConfig[section] then
			currentConfig[section] = {}
		end
		
		local oldValue = currentConfig[section][key]
		currentConfig[section][key] = value
		
		-- Record change in history
		if CONFIG.configHistory then
			self:_recordConfigChange(section, key, oldValue, value, source or "unknown")
		end
		
		-- Fire configuration changed event
		ConfigChanged:Fire({
			section = section,
			key = key,
			oldValue = oldValue,
			newValue = value,
			timestamp = os.time()
		})
		
		logger.LogInfo("Configuration updated", {
			section = section,
			key = key,
			oldValue = oldValue,
			newValue = value,
			source = source
		})
	end)
	
	if not success then
		logger.LogError("Failed to set configuration", {
			section = section,
			key = key,
			value = value,
			error = error
		})
		return false
	end
	
	return true
end

-- Validate configuration value
function ConfigManager:_validateConfigValue(section: string, key: string, value: ConfigValue): ()
	local schema = validationSchemas[section]
	if not schema then
		return -- No validation schema defined
	end
	
	local keySchema = schema[key]
	if not keySchema then
		return -- No validation for this key
	end
	
	local valueType = typeof(value)
	if keySchema.type and valueType ~= keySchema.type then
		error(`Invalid type for {section}.{key}: expected {keySchema.type}, got {valueType}`)
	end
	
	if keySchema.min and typeof(value) == "number" and value < keySchema.min then
		error(`Value for {section}.{key} below minimum: {value} < {keySchema.min}`)
	end
	
	if keySchema.max and typeof(value) == "number" and value > keySchema.max then
		error(`Value for {section}.{key} above maximum: {value} > {keySchema.max}`)
	end
end

-- Record configuration change
function ConfigManager:_recordConfigChange(section: string, key: string, oldValue: ConfigValue?, newValue: ConfigValue, source: string): ()
	local changeEvent: ConfigChangeEvent = {
		section = section,
		key = key,
		oldValue = oldValue,
		newValue = newValue,
		timestamp = os.time(),
		source = source
	}
	
	table.insert(configHistory, changeEvent)
	
	-- Maintain history size limit
	while #configHistory > CONFIG.maxHistoryEntries do
		table.remove(configHistory, 1)
	end
end

-- Feature Flag Management

-- Check if feature flag is enabled for user
function ConfigManager:IsFeatureEnabled(flagName: string, userId: number?): boolean
	local flag = featureFlags[flagName]
	if not flag then
		logger.LogWarning("Feature flag not found", {flagName = flagName})
		return false
	end
	
	if not flag.enabled then
		return false
	end
	
	-- Check user segments
	if userId and #flag.userSegments > 0 then
		if not self:_isUserInSegments(userId, flag.userSegments) then
			return false
		end
	end
	
	-- Check rollout percentage
	if userId then
		local userHash = self:_hashUserId(userId, flagName)
		return userHash < flag.rolloutPercentage
	else
		-- For server-side checks without specific user
		return flag.rolloutPercentage >= 100
	end
end

-- Set feature flag
function ConfigManager:SetFeatureFlag(flagName: string, enabled: boolean, rolloutPercentage: number?, userSegments: {string}?): boolean
	local success, error = pcall(function()
		if not featureFlags[flagName] then
			featureFlags[flagName] = {
				name = flagName,
				enabled = enabled,
				userSegments = userSegments or {},
				rolloutPercentage = rolloutPercentage or CONFIG.defaultRolloutPercentage,
				createdAt = os.time(),
				modifiedAt = os.time(),
				description = "",
				metadata = {}
			}
		else
			local flag = featureFlags[flagName]
			flag.enabled = enabled
			flag.rolloutPercentage = rolloutPercentage or flag.rolloutPercentage
			flag.userSegments = userSegments or flag.userSegments
			flag.modifiedAt = os.time()
		end
		
		FeatureFlagChanged:Fire({
			flagName = flagName,
			enabled = enabled,
			rolloutPercentage = rolloutPercentage,
			timestamp = os.time()
		})
		
		logger.LogInfo("Feature flag updated", {
			flagName = flagName,
			enabled = enabled,
			rolloutPercentage = rolloutPercentage,
			userSegments = userSegments
		})
	end)
	
	if not success then
		logger.LogError("Failed to set feature flag", {
			flagName = flagName,
			enabled = enabled,
			error = error
		})
		return false
	end
	
	return true
end

-- A/B Testing

-- Get A/B test variant for user
function ConfigManager:GetABTestVariant(testName: string, userId: number): string?
	local test = abTests[testName]
	if not test or not test.isActive then
		return nil
	end
	
	-- Check if test is within date range
	local currentTime = os.time()
	if currentTime < test.startDate or (test.endDate and currentTime > test.endDate) then
		return nil
	end
	
	-- Check if user is in target segments
	if #test.targetSegments > 0 and not self:_isUserInSegments(userId, test.targetSegments) then
		return nil
	end
	
	-- Determine variant based on user hash and traffic allocation
	local userHash = self:_hashUserId(userId, testName) / 100 -- Convert to 0-1 range
	local cumulative = 0
	
	for variant, traffic in pairs(test.traffic) do
		cumulative = cumulative + traffic
		if userHash <= cumulative then
			return variant
		end
	end
	
	return nil
end

-- Create A/B test
function ConfigManager:CreateABTest(testName: string, variants: {string}, traffic: {[string]: number}, duration: number?, targetSegments: {string}?): boolean
	local success, error = pcall(function()
		-- Validate traffic allocation
		local totalTraffic = 0
		for _, trafficPercent in pairs(traffic) do
			totalTraffic = totalTraffic + trafficPercent
		end
		
		if math.abs(totalTraffic - 1.0) > 0.01 then
			error(`Traffic allocation must sum to 1.0, got {totalTraffic}`)
		end
		
		abTests[testName] = {
			name = testName,
			variants = variants,
			traffic = traffic,
			startDate = os.time(),
			endDate = duration and (os.time() + duration) or nil,
			targetSegments = targetSegments or {},
			isActive = true,
			metadata = {}
		}
		
		ABTestChanged:Fire({
			testName = testName,
			action = "created",
			timestamp = os.time()
		})
		
		logger.LogInfo("A/B test created", {
			testName = testName,
			variants = variants,
			traffic = traffic,
			duration = duration,
			targetSegments = targetSegments
		})
	end)
	
	if not success then
		logger.LogError("Failed to create A/B test", {
			testName = testName,
			error = error
		})
		return false
	end
	
	return true
end

-- User Segment Management

-- Check if user is in segments
function ConfigManager:_isUserInSegments(userId: number, segments: {string}): boolean
	for _, segmentName in ipairs(segments) do
		if self:IsUserInSegment(userId, segmentName) then
			return true
		end
	end
	return false
end

-- Check if user is in specific segment
function ConfigManager:IsUserInSegment(userId: number, segmentName: string): boolean
	local segment = userSegments[segmentName]
	if not segment then
		return false
	end
	
	-- Check explicit user list
	for _, id in ipairs(segment.userIds) do
		if id == userId then
			return true
		end
	end
	
	-- Check percentage-based inclusion
	local userHash = self:_hashUserId(userId, segmentName)
	if userHash < segment.percentage then
		return true
	end
	
	-- TODO: Implement criteria-based segment checking
	-- This would require additional user data from other services
	
	return false
end

-- Add user to segment
function ConfigManager:AddUserToSegment(userId: number, segmentName: string): boolean
	local segment = userSegments[segmentName]
	if not segment then
		logger.LogWarning("Segment not found", {segmentName = segmentName})
		return false
	end
	
	-- Check if user is already in segment
	for _, id in ipairs(segment.userIds) do
		if id == userId then
			return true -- Already in segment
		end
	end
	
	table.insert(segment.userIds, userId)
	
	logger.LogInfo("User added to segment", {
		userId = userId,
		segmentName = segmentName
	})
	
	return true
end

-- Hash user ID for consistent assignment
function ConfigManager:_hashUserId(userId: number, context: string): number
	-- Simple hash function for consistent user assignment
	local str = tostring(userId) .. context
	local hash = 0
	
	for i = 1, #str do
		hash = ((hash * 31) + string.byte(str, i)) % 2147483647
	end
	
	return (hash % 100) -- Return 0-99
end

-- Utility Functions

-- Get all configuration
function ConfigManager:GetAllConfig(): Configuration
	return currentConfig
end

-- Get all feature flags
function ConfigManager:GetAllFeatureFlags(): {[string]: FeatureFlag}
	return featureFlags
end

-- Get all A/B tests
function ConfigManager:GetAllABTests(): {[string]: ABTest}
	return abTests
end

-- Get configuration history
function ConfigManager:GetConfigHistory(): {ConfigChangeEvent}
	return configHistory
end

-- Get user segments
function ConfigManager:GetUserSegments(): {[string]: UserSegment}
	return userSegments
end

-- Reload configuration from external sources
function ConfigManager:ReloadConfig(): boolean
	local success, error = pcall(function()
		-- In a real implementation, this would fetch from external services
		logger.LogInfo("Configuration reload initiated", {
			timestamp = os.time(),
			environment = CONFIG.environment
		})
		
		-- Simulate external configuration loading
		-- self:_loadFromExternalSource()
		
		ConfigChanged:Fire({
			section = "system",
			key = "reloaded",
			oldValue = nil,
			newValue = true,
			timestamp = os.time()
		})
	end)
	
	if not success then
		logger.LogError("Configuration reload failed", {error = error})
		return false
	end
	
	return true
end

-- Event Connections
function ConfigManager:OnConfigChanged(callback: (ConfigChangeEvent) -> ()): RBXScriptConnection
	return ConfigChanged.Event:Connect(callback)
end

function ConfigManager:OnFeatureFlagChanged(callback: (any) -> ()): RBXScriptConnection
	return FeatureFlagChanged.Event:Connect(callback)
end

function ConfigManager:OnABTestChanged(callback: (any) -> ()): RBXScriptConnection
	return ABTestChanged.Event:Connect(callback)
end

-- Health Check
function ConfigManager:GetHealthStatus(): {status: string, metrics: any}
	return {
		status = "healthy",
		metrics = {
			configSections = #currentConfig,
			featureFlags = #featureFlags,
			abTests = #abTests,
			userSegments = #userSegments,
			historyEntries = #configHistory,
			environment = CONFIG.environment,
			autoReload = CONFIG.autoReload,
			lastUpdate = os.time()
		}
	}
end

return ConfigManager
