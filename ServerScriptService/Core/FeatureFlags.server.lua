--!strict
--[[
	FeatureFlags.server.lua
	Enterprise Feature Flag Server Management System
	
	Provides server-side feature flag management, A/B testing coordination,
	and configuration distribution to clients with real-time updates.
	
	Features:
	- Server-side feature flag processing
	- A/B test experiment management
	- Configuration synchronization with clients
	- Admin tools for flag management
	- Real-time flag updates
	- Performance monitoring
	- Experiment analytics
	- User segment management
	
	Author: Enterprise Development Team
	Created: December 2024
]]--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import Services
local ServiceLocator = require(ReplicatedStorage.Shared.ServiceLocator)
local ConfigManager = require(ReplicatedStorage.Shared.ConfigManager)

-- Types
type PlayerExperiment = {
	userId: number,
	testName: string,
	variant: string,
	assignedAt: number,
	metadata: {[string]: any}
}

type ExperimentMetrics = {
	testName: string,
	variant: string,
	userCount: number,
	conversionRate: number,
	averageSessionTime: number,
	retentionRate: number,
	lastUpdated: number
}

type FeatureFlagMetrics = {
	flagName: string,
	enabledUsers: number,
	totalUsers: number,
	rolloutPercentage: number,
	errorRate: number,
	performanceImpact: number,
	lastUpdated: number
}

-- FeatureFlags Server Class
local FeatureFlagsServer = {}
FeatureFlagsServer.__index = FeatureFlagsServer

-- Private Variables
local configManager: any
local logger: any
local analytics: any
local playerExperiments: {[number]: {PlayerExperiment}} = {}
local experimentMetrics: {[string]: ExperimentMetrics} = {}
local flagMetrics: {[string]: FeatureFlagMetrics} = {}
local playerSegmentCache: {[number]: {string}} = {}
local adminUsers: {number} = {}

-- Remote Events
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local featureFlagRemotes = remoteEvents:FindFirstChild("FeatureFlagEvents")
if not featureFlagRemotes then
	featureFlagRemotes = Instance.new("Folder")
	featureFlagRemotes.Name = "FeatureFlagEvents"
	featureFlagRemotes.Parent = remoteEvents
end

local GetFeatureFlagsRemote = Instance.new("RemoteFunction")
GetFeatureFlagsRemote.Name = "GetFeatureFlags"
GetFeatureFlagsRemote.Parent = featureFlagRemotes

local GetABTestVariantRemote = Instance.new("RemoteFunction")
GetABTestVariantRemote.Name = "GetABTestVariant"
GetABTestVariantRemote.Parent = featureFlagRemotes

local UpdateFeatureFlagRemote = Instance.new("RemoteEvent")
UpdateFeatureFlagRemote.Name = "UpdateFeatureFlag"
UpdateFeatureFlagRemote.Parent = featureFlagRemotes

local ConfigUpdatedRemote = Instance.new("RemoteEvent")
ConfigUpdatedRemote.Name = "ConfigUpdated"
ConfigUpdatedRemote.Parent = featureFlagRemotes

local AdminCommandRemote = Instance.new("RemoteEvent")
AdminCommandRemote.Name = "AdminCommand"
AdminCommandRemote.Parent = featureFlagRemotes

-- Configuration
local SERVER_CONFIG = {
	syncInterval = 30, -- seconds
	metricsUpdateInterval = 60, -- seconds
	experimentTimeout = 24 * 60 * 60, -- 24 hours
	maxExperimentsPerUser = 10,
	enableMetricsCollection = true,
	enableAdminTools = true,
	autoSyncClients = true,
	validateExperiments = true
}

-- Initialization
function FeatureFlagsServer.new(): typeof(FeatureFlagsServer)
	local self = setmetatable({}, FeatureFlagsServer)
	
	-- Get required services
	configManager = ConfigManager.new()
	logger = ServiceLocator:GetService("Logging")
	analytics = ServiceLocator:GetService("AnalyticsEngine")
	
	if not logger then
		warn("FeatureFlagsServer: Logging service not available")
		logger = { LogInfo = print, LogWarning = warn, LogError = warn }
	end
	
	-- Register with Service Locator
	ServiceLocator:RegisterService("FeatureFlagsServer", self)
	
	-- Initialize admin users
	self:_initializeAdminUsers()
	
	-- Setup remote event handlers
	self:_setupRemoteHandlers()
	
	-- Setup periodic tasks
	self:_setupPeriodicTasks()
	
	-- Setup player event handlers
	self:_setupPlayerEvents()
	
	-- Setup configuration change handlers
	self:_setupConfigChangeHandlers()
	
	logger.LogInfo("FeatureFlagsServer initialized successfully", {
		adminUsers = #adminUsers,
		syncInterval = SERVER_CONFIG.syncInterval,
		metricsEnabled = SERVER_CONFIG.enableMetricsCollection
	})
	
	return self
end

-- Initialize admin users
function FeatureFlagsServer:_initializeAdminUsers(): ()
	-- In a real implementation, this would be loaded from configuration
	adminUsers = {
		-- Add admin user IDs here
		123456789, -- Example admin user ID
	}
end

-- Setup remote event handlers
function FeatureFlagsServer:_setupRemoteHandlers(): ()
	-- Get feature flags for player
	GetFeatureFlagsRemote.OnServerInvoke = function(player: Player): {[string]: boolean}
		return self:GetPlayerFeatureFlags(player.UserId)
	end
	
	-- Get A/B test variant for player
	GetABTestVariantRemote.OnServerInvoke = function(player: Player, testName: string): string?
		return self:GetPlayerABTestVariant(player.UserId, testName)
	end
	
	-- Handle admin commands
	AdminCommandRemote.OnServerEvent:Connect(function(player: Player, command: string, data: any)
		if not self:_isAdminUser(player.UserId) then
			logger.LogWarning("Unauthorized admin command attempt", {
				userId = player.UserId,
				command = command
			})
			return
		end
		
		self:_handleAdminCommand(player, command, data)
	end)
end

-- Setup periodic tasks
function FeatureFlagsServer:_setupPeriodicTasks(): ()
	-- Client synchronization
	if SERVER_CONFIG.autoSyncClients then
		task.spawn(function()
			while true do
				task.wait(SERVER_CONFIG.syncInterval)
				self:_syncAllClients()
			end
		end)
	end
	
	-- Metrics collection
	if SERVER_CONFIG.enableMetricsCollection then
		task.spawn(function()
			while true do
				task.wait(SERVER_CONFIG.metricsUpdateInterval)
				self:_updateMetrics()
			end
		end)
	end
	
	-- Experiment cleanup
	task.spawn(function()
		while true do
			task.wait(SERVER_CONFIG.experimentTimeout / 4) -- Check every 6 hours
			self:_cleanupExpiredExperiments()
		end
	end)
end

-- Setup player events
function FeatureFlagsServer:_setupPlayerEvents(): ()
	Players.PlayerAdded:Connect(function(player: Player)
		self:_onPlayerJoined(player)
	end)
	
	Players.PlayerRemoving:Connect(function(player: Player)
		self:_onPlayerLeaving(player)
	end)
end

-- Setup configuration change handlers
function FeatureFlagsServer:_setupConfigChangeHandlers(): ()
	configManager:OnFeatureFlagChanged(function(changeData: any)
		self:_onFeatureFlagChanged(changeData)
	end)
	
	configManager:OnABTestChanged(function(changeData: any)
		self:_onABTestChanged(changeData)
	end)
	
	configManager:OnConfigChanged(function(changeData: any)
		self:_onConfigChanged(changeData)
	end)
end

-- Player joined handler
function FeatureFlagsServer:_onPlayerJoined(player: Player): ()
	local userId = player.UserId
	
	-- Initialize player experiments
	playerExperiments[userId] = {}
	
	-- Cache player segments
	self:_updatePlayerSegmentCache(userId)
	
	-- Assign player to active A/B tests
	self:_assignPlayerToExperiments(userId)
	
	-- Send initial configuration to client
	self:_syncPlayerClient(player)
	
	logger.LogInfo("Player joined - feature flags initialized", {
		userId = userId,
		playerName = player.Name,
		experiments = #playerExperiments[userId]
	})
end

-- Player leaving handler
function FeatureFlagsServer:_onPlayerLeaving(player: Player): ()
	local userId = player.UserId
	
	-- Record experiment participation
	if playerExperiments[userId] then
		self:_recordExperimentParticipation(userId)
	end
	
	-- Cleanup player data
	playerExperiments[userId] = nil
	playerSegmentCache[userId] = nil
	
	logger.LogInfo("Player left - feature flags cleaned up", {
		userId = userId,
		playerName = player.Name
	})
end

-- Feature Flag Management

-- Get feature flags for player
function FeatureFlagsServer:GetPlayerFeatureFlags(userId: number): {[string]: boolean}
	local flags = {}
	local allFlags = configManager:GetAllFeatureFlags()
	
	for flagName, flagData in pairs(allFlags) do
		flags[flagName] = configManager:IsFeatureEnabled(flagName, userId)
	end
	
	-- Update metrics
	self:_updateFlagMetrics(userId, flags)
	
	return flags
end

-- Check if specific feature is enabled for player
function FeatureFlagsServer:IsFeatureEnabledForPlayer(userId: number, flagName: string): boolean
	return configManager:IsFeatureEnabled(flagName, userId)
end

-- A/B Testing Management

-- Get A/B test variant for player
function FeatureFlagsServer:GetPlayerABTestVariant(userId: number, testName: string): string?
	local variant = configManager:GetABTestVariant(testName, userId)
	
	if variant then
		-- Record experiment assignment
		self:_recordExperimentAssignment(userId, testName, variant)
	end
	
	return variant
end

-- Assign player to active experiments
function FeatureFlagsServer:_assignPlayerToExperiments(userId: number): ()
	local allTests = configManager:GetAllABTests()
	
	for testName, testData in pairs(allTests) do
		if testData.isActive then
			local variant = configManager:GetABTestVariant(testName, userId)
			if variant then
				self:_recordExperimentAssignment(userId, testName, variant)
			end
		end
	end
end

-- Record experiment assignment
function FeatureFlagsServer:_recordExperimentAssignment(userId: number, testName: string, variant: string): ()
	if not playerExperiments[userId] then
		playerExperiments[userId] = {}
	end
	
	-- Check if already assigned
	for _, experiment in ipairs(playerExperiments[userId]) do
		if experiment.testName == testName then
			return -- Already assigned
		end
	end
	
	-- Check experiment limit
	if #playerExperiments[userId] >= SERVER_CONFIG.maxExperimentsPerUser then
		logger.LogWarning("Player experiment limit reached", {
			userId = userId,
			testName = testName,
			currentExperiments = #playerExperiments[userId]
		})
		return
	end
	
	local experiment: PlayerExperiment = {
		userId = userId,
		testName = testName,
		variant = variant,
		assignedAt = os.time(),
		metadata = {}
	}
	
	table.insert(playerExperiments[userId], experiment)
	
	-- Record analytics event
	if analytics then
		analytics:RecordEvent(userId, "experiment_assigned", {
			testName = testName,
			variant = variant,
			assignedAt = experiment.assignedAt
		})
	end
	
	logger.LogInfo("Player assigned to experiment", {
		userId = userId,
		testName = testName,
		variant = variant
	})
end

-- Record experiment participation
function FeatureFlagsServer:_recordExperimentParticipation(userId: number): ()
	local experiments = playerExperiments[userId]
	if not experiments then
		return
	end
	
	for _, experiment in ipairs(experiments) do
		if analytics then
			analytics:RecordEvent(userId, "experiment_participation", {
				testName = experiment.testName,
				variant = experiment.variant,
				duration = os.time() - experiment.assignedAt,
				metadata = experiment.metadata
			})
		end
	end
end

-- User Segment Management

-- Update player segment cache
function FeatureFlagsServer:_updatePlayerSegmentCache(userId: number): ()
	local segments = {}
	local allSegments = configManager:GetUserSegments()
	
	for segmentName, _ in pairs(allSegments) do
		if configManager:IsUserInSegment(userId, segmentName) then
			table.insert(segments, segmentName)
		end
	end
	
	playerSegmentCache[userId] = segments
	
	logger.LogInfo("Player segments updated", {
		userId = userId,
		segments = segments
	})
end

-- Get player segments
function FeatureFlagsServer:GetPlayerSegments(userId: number): {string}
	return playerSegmentCache[userId] or {}
end

-- Client Synchronization

-- Sync all clients
function FeatureFlagsServer:_syncAllClients(): ()
	local success, error = pcall(function()
		for _, player in ipairs(Players:GetPlayers()) do
			self:_syncPlayerClient(player)
		end
	end)
	
	if not success then
		logger.LogError("Failed to sync all clients", {error = error})
	end
end

-- Sync specific player client
function FeatureFlagsServer:_syncPlayerClient(player: Player): ()
	local success, error = pcall(function()
		local userId = player.UserId
		local flags = self:GetPlayerFeatureFlags(userId)
		local experiments = playerExperiments[userId] or {}
		
		ConfigUpdatedRemote:FireClient(player, {
			featureFlags = flags,
			experiments = experiments,
			timestamp = os.time()
		})
	end)
	
	if not success then
		logger.LogError("Failed to sync player client", {
			userId = player.UserId,
			error = error
		})
	end
end

-- Event Handlers

-- Feature flag changed handler
function FeatureFlagsServer:_onFeatureFlagChanged(changeData: any): ()
	logger.LogInfo("Feature flag changed", changeData)
	
	-- Notify all clients of the change
	UpdateFeatureFlagRemote:FireAllClients(changeData)
	
	-- Update metrics
	self:_updateFlagMetricsForFlag(changeData.flagName)
end

-- A/B test changed handler
function FeatureFlagsServer:_onABTestChanged(changeData: any): ()
	logger.LogInfo("A/B test changed", changeData)
	
	-- If test was activated, assign existing players
	if changeData.action == "created" or changeData.action == "activated" then
		for _, player in ipairs(Players:GetPlayers()) do
			local variant = configManager:GetABTestVariant(changeData.testName, player.UserId)
			if variant then
				self:_recordExperimentAssignment(player.UserId, changeData.testName, variant)
			end
		end
	end
end

-- Configuration changed handler
function FeatureFlagsServer:_onConfigChanged(changeData: any): ()
	logger.LogInfo("Configuration changed", changeData)
	
	-- Sync all clients with new configuration
	self:_syncAllClients()
end

-- Metrics and Analytics

-- Update all metrics
function FeatureFlagsServer:_updateMetrics(): ()
	local success, error = pcall(function()
		self:_updateExperimentMetrics()
		self:_updateFeatureFlagMetrics()
	end)
	
	if not success then
		logger.LogError("Failed to update metrics", {error = error})
	end
end

-- Update experiment metrics
function FeatureFlagsServer:_updateExperimentMetrics(): ()
	local allTests = configManager:GetAllABTests()
	
	for testName, testData in pairs(allTests) do
		if testData.isActive then
			local metrics = self:_calculateExperimentMetrics(testName)
			experimentMetrics[testName] = metrics
		end
	end
end

-- Calculate experiment metrics
function FeatureFlagsServer:_calculateExperimentMetrics(testName: string): ExperimentMetrics
	local variants = {}
	local totalUsers = 0
	
	-- Count users in each variant
	for _, experiments in pairs(playerExperiments) do
		for _, experiment in ipairs(experiments) do
			if experiment.testName == testName then
				local variant = experiment.variant
				variants[variant] = (variants[variant] or 0) + 1
				totalUsers = totalUsers + 1
			end
		end
	end
	
	-- Calculate primary variant metrics
	local primaryVariant = next(variants) or "control"
	
	return {
		testName = testName,
		variant = primaryVariant,
		userCount = variants[primaryVariant] or 0,
		conversionRate = 0.5, -- TODO: Calculate from analytics
		averageSessionTime = 300, -- TODO: Calculate from analytics
		retentionRate = 0.7, -- TODO: Calculate from analytics
		lastUpdated = os.time()
	}
end

-- Update feature flag metrics
function FeatureFlagsServer:_updateFeatureFlagMetrics(): ()
	local allFlags = configManager:GetAllFeatureFlags()
	
	for flagName, _ in pairs(allFlags) do
		self:_updateFlagMetricsForFlag(flagName)
	end
end

-- Update metrics for specific flag
function FeatureFlagsServer:_updateFlagMetricsForFlag(flagName: string): ()
	local enabledUsers = 0
	local totalUsers = #Players:GetPlayers()
	
	for _, player in ipairs(Players:GetPlayers()) do
		if self:IsFeatureEnabledForPlayer(player.UserId, flagName) then
			enabledUsers = enabledUsers + 1
		end
	end
	
	local flag = configManager:GetAllFeatureFlags()[flagName]
	if flag then
		flagMetrics[flagName] = {
			flagName = flagName,
			enabledUsers = enabledUsers,
			totalUsers = totalUsers,
			rolloutPercentage = flag.rolloutPercentage,
			errorRate = 0.01, -- TODO: Calculate from error logs
			performanceImpact = 0.05, -- TODO: Calculate from performance metrics
			lastUpdated = os.time()
		}
	end
end

-- Update flag metrics for specific user
function FeatureFlagsServer:_updateFlagMetrics(userId: number, flags: {[string]: boolean}): ()
	-- Record flag usage analytics
	if analytics then
		for flagName, enabled in pairs(flags) do
			analytics:RecordEvent(userId, "feature_flag_check", {
				flagName = flagName,
				enabled = enabled,
				timestamp = os.time()
			})
		end
	end
end

-- Admin Tools

-- Check if user is admin
function FeatureFlagsServer:_isAdminUser(userId: number): boolean
	for _, adminId in ipairs(adminUsers) do
		if adminId == userId then
			return true
		end
	end
	return false
end

-- Handle admin command
function FeatureFlagsServer:_handleAdminCommand(player: Player, command: string, data: any): ()
	local success, error = pcall(function()
		if command == "setFeatureFlag" then
			local flagName = data.flagName
			local enabled = data.enabled
			local rollout = data.rolloutPercentage
			local segments = data.userSegments
			
			configManager:SetFeatureFlag(flagName, enabled, rollout, segments)
			
		elseif command == "createABTest" then
			local testName = data.testName
			local variants = data.variants
			local traffic = data.traffic
			local duration = data.duration
			local segments = data.targetSegments
			
			configManager:CreateABTest(testName, variants, traffic, duration, segments)
			
		elseif command == "getMetrics" then
			-- Return current metrics to admin
			local metricsData = {
				experiments = experimentMetrics,
				featureFlags = flagMetrics,
				serverHealth = self:GetHealthStatus(),
				timestamp = os.time()
			}
			
			-- Send metrics to admin client
			ConfigUpdatedRemote:FireClient(player, {
				type = "metrics",
				data = metricsData
			})
			
		elseif command == "forceSync" then
			-- Force sync all clients
			self:_syncAllClients()
			
		else
			logger.LogWarning("Unknown admin command", {
				command = command,
				userId = player.UserId
			})
		end
	end)
	
	if not success then
		logger.LogError("Admin command failed", {
			command = command,
			userId = player.UserId,
			error = error
		})
	end
end

-- Cleanup

-- Cleanup expired experiments
function FeatureFlagsServer:_cleanupExpiredExperiments(): ()
	local currentTime = os.time()
	local cleanedCount = 0
	
	for userId, experiments in pairs(playerExperiments) do
		local validExperiments = {}
		
		for _, experiment in ipairs(experiments) do
			if currentTime - experiment.assignedAt < SERVER_CONFIG.experimentTimeout then
				table.insert(validExperiments, experiment)
			else
				cleanedCount = cleanedCount + 1
			end
		end
		
		playerExperiments[userId] = validExperiments
	end
	
	if cleanedCount > 0 then
		logger.LogInfo("Cleaned up expired experiments", {
			cleanedCount = cleanedCount,
			timestamp = currentTime
		})
	end
end

-- Health Check and Status

-- Get health status
function FeatureFlagsServer:GetHealthStatus(): {status: string, metrics: any}
	local configHealth = configManager:GetHealthStatus()
	
	return {
		status = "healthy",
		metrics = {
			configManager = configHealth,
			activeExperiments = #experimentMetrics,
			flagMetrics = #flagMetrics,
			connectedPlayers = #Players:GetPlayers(),
			totalPlayerExperiments = #playerExperiments,
			adminUsers = #adminUsers,
			lastSync = os.time(),
			serverConfig = SERVER_CONFIG
		}
	}
end

-- Public API

-- Get experiment metrics
function FeatureFlagsServer:GetExperimentMetrics(): {[string]: ExperimentMetrics}
	return experimentMetrics
end

-- Get feature flag metrics
function FeatureFlagsServer:GetFeatureFlagMetrics(): {[string]: FeatureFlagMetrics}
	return flagMetrics
end

-- Force client sync
function FeatureFlagsServer:ForceClientSync(userId: number?): ()
	if userId then
		local player = Players:GetPlayerByUserId(userId)
		if player then
			self:_syncPlayerClient(player)
		end
	else
		self:_syncAllClients()
	end
end

-- Add admin user
function FeatureFlagsServer:AddAdminUser(userId: number): ()
	table.insert(adminUsers, userId)
	logger.LogInfo("Admin user added", {userId = userId})
end

return FeatureFlagsServer.new()
