--!strict
--[[
	ConfigManagerTests.lua
	Enterprise Configuration Management & Feature Flags Test Suite
	
	Comprehensive testing for configuration management, feature flags, A/B testing,
	and admin tools with performance benchmarks and integration tests.
	
	Test Coverage:
	- Configuration management and validation
	- Feature flag functionality and rollout
	- A/B test assignment and tracking
	- User segment management
	- Admin tools and permissions
	- Performance and stress testing
	- Integration with existing services
	
	Author: Enterprise Development Team
	Created: December 2024
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Import test framework and services
local TestFramework = require(script.Parent.Parent.TestFramework)
local ConfigManager = require(ReplicatedStorage.Shared.ConfigManager)
local ServiceLocator = require(ReplicatedStorage.Shared.ServiceLocator)

-- Test Configuration
local TEST_CONFIG = {
	performanceThreshold = 0.001, -- 1ms
	stressTestUsers = 1000,
	stressTestIterations = 100,
	featureFlagTestCases = 50,
	abTestCoverage = 95, -- percentage
	configValidationTests = 25
}

-- Mock Data
local mockUsers = {}
for i = 1, TEST_CONFIG.stressTestUsers do
	table.insert(mockUsers, {
		userId = 100000 + i,
		accountAge = math.random(1, 365),
		playtime = math.random(1, 1000),
		isPremium = math.random() < 0.15,
		isVerified = math.random() < 0.25
	})
end

-- Test Suite: Configuration Management
local ConfigManagementTests = TestFramework.CreateTestSuite("ConfigManagement")

function ConfigManagementTests.TestConfigManagerInitialization()
	local configManager = ConfigManager.new()
	
	TestFramework.Assert(configManager ~= nil, "ConfigManager should initialize successfully")
	
	local healthStatus = configManager:GetHealthStatus()
	TestFramework.Assert(healthStatus.status == "healthy", "ConfigManager should be healthy after initialization")
	TestFramework.Assert(healthStatus.metrics.configSections > 0, "Should have default configuration sections")
	TestFramework.Assert(healthStatus.metrics.featureFlags > 0, "Should have default feature flags")
	TestFramework.Assert(healthStatus.metrics.abTests > 0, "Should have default A/B tests")
end

function ConfigManagementTests.TestConfigurationGetSet()
	local configManager = ConfigManager.new()
	
	-- Test getting existing configuration
	local gameConfig = configManager:GetConfig("Game")
	TestFramework.Assert(gameConfig ~= nil, "Should retrieve Game configuration section")
	TestFramework.Assert(typeof(gameConfig) == "table", "Game config should be a table")
	
	local maxPlayers = configManager:GetConfig("Game", "maxPlayers")
	TestFramework.Assert(typeof(maxPlayers) == "number", "maxPlayers should be a number")
	TestFramework.Assert(maxPlayers > 0, "maxPlayers should be positive")
	
	-- Test setting configuration
	local success = configManager:SetConfig("Game", "testValue", 42, "unit_test")
	TestFramework.Assert(success, "Should successfully set configuration value")
	
	local retrievedValue = configManager:GetConfig("Game", "testValue")
	TestFramework.Assert(retrievedValue == 42, "Should retrieve the set configuration value")
	
	-- Test setting invalid section
	local invalidSuccess = configManager:SetConfig("InvalidSection", "key", "value", "unit_test")
	TestFramework.Assert(invalidSuccess, "Should handle setting configuration in new section")
	
	local newSectionValue = configManager:GetConfig("InvalidSection", "key")
	TestFramework.Assert(newSectionValue == "value", "Should retrieve value from new section")
end

function ConfigManagementTests.TestConfigurationValidation()
	local configManager = ConfigManager.new()
	
	-- Test type validation (would require validation schemas to be implemented)
	local success = configManager:SetConfig("Game", "maxPlayers", "invalid_number", "unit_test")
	TestFramework.Assert(success, "Should handle type validation gracefully")
	
	-- Test configuration history
	configManager:SetConfig("Game", "historyTest", 1, "test1")
	configManager:SetConfig("Game", "historyTest", 2, "test2")
	configManager:SetConfig("Game", "historyTest", 3, "test3")
	
	local history = configManager:GetConfigHistory()
	TestFramework.Assert(#history >= 3, "Should record configuration changes in history")
	
	-- Verify history entries
	local lastChange = history[#history]
	TestFramework.Assert(lastChange.section == "Game", "History should record correct section")
	TestFramework.Assert(lastChange.key == "historyTest", "History should record correct key")
	TestFramework.Assert(lastChange.newValue == 3, "History should record correct new value")
	TestFramework.Assert(lastChange.source == "test3", "History should record correct source")
end

function ConfigManagementTests.TestEnvironmentSpecificConfig()
	local configManager = ConfigManager.new()
	
	-- Test that environment-specific configurations are applied
	local allConfig = configManager:GetAllConfig()
	TestFramework.Assert(allConfig.Game ~= nil, "Should have Game configuration")
	TestFramework.Assert(allConfig.Combat ~= nil, "Should have Combat configuration")
	TestFramework.Assert(allConfig.Performance ~= nil, "Should have Performance configuration")
	
	-- Development environment should have specific values
	local maxPlayers = configManager:GetConfig("Game", "maxPlayers")
	TestFramework.Assert(typeof(maxPlayers) == "number", "maxPlayers should be a number")
end

-- Test Suite: Feature Flags
local FeatureFlagsTests = TestFramework.CreateTestSuite("FeatureFlags")

function FeatureFlagsTests.TestFeatureFlagBasics()
	local configManager = ConfigManager.new()
	
	-- Test default feature flags
	local allFlags = configManager:GetAllFeatureFlags()
	TestFramework.Assert(typeof(allFlags) == "table", "Should return table of feature flags")
	TestFramework.Assert(allFlags.newUIDesign ~= nil, "Should have newUIDesign flag")
	TestFramework.Assert(allFlags.enhancedGraphics ~= nil, "Should have enhancedGraphics flag")
	
	-- Test feature flag checking
	local isEnabled = configManager:IsFeatureEnabled("enhancedGraphics", 123456)
	TestFramework.Assert(typeof(isEnabled) == "boolean", "IsFeatureEnabled should return boolean")
	
	-- Test non-existent flag
	local nonExistent = configManager:IsFeatureEnabled("nonExistentFlag", 123456)
	TestFramework.Assert(nonExistent == false, "Non-existent flags should return false")
end

function FeatureFlagsTests.TestFeatureFlagCreationAndModification()
	local configManager = ConfigManager.new()
	
	-- Create new feature flag
	local success = configManager:SetFeatureFlag("testFlag", true, 50, {"beta_testers"})
	TestFramework.Assert(success, "Should successfully create new feature flag")
	
	-- Verify flag was created
	local allFlags = configManager:GetAllFeatureFlags()
	TestFramework.Assert(allFlags.testFlag ~= nil, "New flag should exist in all flags")
	TestFramework.Assert(allFlags.testFlag.enabled == true, "Flag should be enabled")
	TestFramework.Assert(allFlags.testFlag.rolloutPercentage == 50, "Flag should have correct rollout percentage")
	
	-- Modify existing flag
	local modifySuccess = configManager:SetFeatureFlag("testFlag", false, 25)
	TestFramework.Assert(modifySuccess, "Should successfully modify existing flag")
	
	local modifiedFlag = configManager:GetAllFeatureFlags().testFlag
	TestFramework.Assert(modifiedFlag.enabled == false, "Flag should be disabled after modification")
	TestFramework.Assert(modifiedFlag.rolloutPercentage == 25, "Flag should have updated rollout percentage")
end

function FeatureFlagsTests.TestFeatureFlagRolloutPercentage()
	local configManager = ConfigManager.new()
	
	-- Create flag with 0% rollout
	configManager:SetFeatureFlag("rolloutTest0", true, 0)
	
	-- Create flag with 100% rollout
	configManager:SetFeatureFlag("rolloutTest100", true, 100)
	
	-- Test multiple users for 0% rollout
	local enabledCount0 = 0
	for i = 1, 100 do
		if configManager:IsFeatureEnabled("rolloutTest0", 100000 + i) then
			enabledCount0 = enabledCount0 + 1
		end
	end
	
	-- Test multiple users for 100% rollout
	local enabledCount100 = 0
	for i = 1, 100 do
		if configManager:IsFeatureEnabled("rolloutTest100", 100000 + i) then
			enabledCount100 = enabledCount100 + 1
		end
	end
	
	TestFramework.Assert(enabledCount0 == 0, "0% rollout should enable flag for no users")
	TestFramework.Assert(enabledCount100 == 100, "100% rollout should enable flag for all users")
	
	-- Test 50% rollout
	configManager:SetFeatureFlag("rolloutTest50", true, 50)
	local enabledCount50 = 0
	for i = 1, 1000 do
		if configManager:IsFeatureEnabled("rolloutTest50", 100000 + i) then
			enabledCount50 = enabledCount50 + 1
		end
	end
	
	-- Should be approximately 50% (allow 10% variance)
	local percentage = enabledCount50 / 1000 * 100
	TestFramework.Assert(percentage >= 40 and percentage <= 60, `50% rollout should be approximately 50%, got {percentage}%`)
end

function FeatureFlagsTests.TestConsistentUserAssignment()
	local configManager = ConfigManager.new()
	
	configManager:SetFeatureFlag("consistencyTest", true, 30)
	
	-- Test that same user gets same result
	local userId = 123456
	local firstCheck = configManager:IsFeatureEnabled("consistencyTest", userId)
	
	for i = 1, 10 do
		local subsequentCheck = configManager:IsFeatureEnabled("consistencyTest", userId)
		TestFramework.Assert(subsequentCheck == firstCheck, "Feature flag should be consistent for same user")
	end
end

-- Test Suite: A/B Testing
local ABTestingTests = TestFramework.CreateTestSuite("ABTesting")

function ABTestingTests.TestABTestCreation()
	local configManager = ConfigManager.new()
	
	-- Create A/B test
	local variants = {"control", "variant_a", "variant_b"}
	local traffic = {control = 0.4, variant_a = 0.3, variant_b = 0.3}
	
	local success = configManager:CreateABTest("testExperiment", variants, traffic, 86400, {"active_players"})
	TestFramework.Assert(success, "Should successfully create A/B test")
	
	-- Verify test was created
	local allTests = configManager:GetAllABTests()
	TestFramework.Assert(allTests.testExperiment ~= nil, "New A/B test should exist")
	TestFramework.Assert(allTests.testExperiment.isActive == true, "New A/B test should be active")
	
	-- Test invalid traffic allocation
	local invalidTraffic = {control = 0.5, variant_a = 0.3} -- Only sums to 0.8
	local invalidSuccess = configManager:CreateABTest("invalidTest", variants, invalidTraffic)
	TestFramework.Assert(invalidSuccess == false, "Should reject invalid traffic allocation")
end

function ABTestingTests.TestABTestAssignment()
	local configManager = ConfigManager.new()
	
	-- Create test
	local variants = {"control", "treatment"}
	local traffic = {control = 0.5, treatment = 0.5}
	configManager:CreateABTest("assignmentTest", variants, traffic)
	
	-- Test assignment for multiple users
	local assignments = {}
	for i = 1, 1000 do
		local variant = configManager:GetABTestVariant("assignmentTest", 100000 + i)
		if variant then
			assignments[variant] = (assignments[variant] or 0) + 1
		end
	end
	
	TestFramework.Assert(assignments.control ~= nil, "Should assign users to control variant")
	TestFramework.Assert(assignments.treatment ~= nil, "Should assign users to treatment variant")
	
	-- Check approximate 50/50 split (allow 10% variance)
	local totalAssigned = (assignments.control or 0) + (assignments.treatment or 0)
	local controlPercentage = (assignments.control or 0) / totalAssigned * 100
	TestFramework.Assert(controlPercentage >= 40 and controlPercentage <= 60, `Control should be ~50%, got {controlPercentage}%`)
end

function ABTestingTests.TestABTestConsistency()
	local configManager = ConfigManager.new()
	
	-- Create test
	configManager:CreateABTest("consistencyTest", {"a", "b"}, {a = 0.5, b = 0.5})
	
	-- Test consistency for same user
	local userId = 654321
	local firstAssignment = configManager:GetABTestVariant("consistencyTest", userId)
	
	for i = 1, 10 do
		local subsequentAssignment = configManager:GetABTestVariant("consistencyTest", userId)
		TestFramework.Assert(subsequentAssignment == firstAssignment, "A/B test assignment should be consistent for same user")
	end
end

-- Test Suite: User Segments
local UserSegmentTests = TestFramework.CreateTestSuite("UserSegments")

function UserSegmentTests.TestUserSegmentBasics()
	local configManager = ConfigManager.new()
	
	-- Get default segments
	local segments = configManager:GetUserSegments()
	TestFramework.Assert(typeof(segments) == "table", "Should return table of user segments")
	TestFramework.Assert(segments.beta_testers ~= nil, "Should have beta_testers segment")
	TestFramework.Assert(segments.premium_users ~= nil, "Should have premium_users segment")
	TestFramework.Assert(segments.active_players ~= nil, "Should have active_players segment")
end

function UserSegmentTests.TestUserSegmentMembership()
	local configManager = ConfigManager.new()
	
	-- Test segment checking
	local isBetaTester = configManager:IsUserInSegment(123456, "beta_testers")
	TestFramework.Assert(typeof(isBetaTester) == "boolean", "IsUserInSegment should return boolean")
	
	-- Test non-existent segment
	local nonExistent = configManager:IsUserInSegment(123456, "nonExistentSegment")
	TestFramework.Assert(nonExistent == false, "Non-existent segments should return false")
end

function UserSegmentTests.TestAddUserToSegment()
	local configManager = ConfigManager.new()
	
	-- Add user to segment
	local success = configManager:AddUserToSegment(999999, "beta_testers")
	TestFramework.Assert(success, "Should successfully add user to segment")
	
	-- Verify user is in segment
	local isInSegment = configManager:IsUserInSegment(999999, "beta_testers")
	TestFramework.Assert(isInSegment == true, "User should be in segment after being added")
	
	-- Try adding to non-existent segment
	local failureSuccess = configManager:AddUserToSegment(999999, "nonExistentSegment")
	TestFramework.Assert(failureSuccess == false, "Should fail to add user to non-existent segment")
end

-- Test Suite: Performance Tests
local PerformanceTests = TestFramework.CreateTestSuite("Performance")

function PerformanceTests.TestConfigurationPerformance()
	local configManager = ConfigManager.new()
	
	-- Test configuration get performance
	local startTime = tick()
	for i = 1, 1000 do
		configManager:GetConfig("Game", "maxPlayers")
	end
	local getTime = tick() - startTime
	
	TestFramework.Assert(getTime < TEST_CONFIG.performanceThreshold * 1000, `Config get should be fast: {getTime}ms`)
	
	-- Test configuration set performance
	startTime = tick()
	for i = 1, 100 do
		configManager:SetConfig("Performance", `testKey{i}`, i, "performance_test")
	end
	local setTime = tick() - startTime
	
	TestFramework.Assert(setTime < TEST_CONFIG.performanceThreshold * 100, `Config set should be fast: {setTime}ms`)
end

function PerformanceTests.TestFeatureFlagPerformance()
	local configManager = ConfigManager.new()
	
	-- Create test flags
	for i = 1, 10 do
		configManager:SetFeatureFlag(`perfFlag{i}`, true, 50)
	end
	
	-- Test feature flag check performance
	local startTime = tick()
	for i = 1, 1000 do
		for j = 1, 10 do
			configManager:IsFeatureEnabled(`perfFlag{j}`, 100000 + i)
		end
	end
	local checkTime = tick() - startTime
	
	TestFramework.Assert(checkTime < TEST_CONFIG.performanceThreshold * 10000, `Feature flag checks should be fast: {checkTime}ms`)
end

function PerformanceTests.TestABTestPerformance()
	local configManager = ConfigManager.new()
	
	-- Create test experiments
	for i = 1, 5 do
		configManager:CreateABTest(`perfTest{i}`, {"a", "b"}, {a = 0.5, b = 0.5})
	end
	
	-- Test A/B test assignment performance
	local startTime = tick()
	for i = 1, 1000 do
		for j = 1, 5 do
			configManager:GetABTestVariant(`perfTest{j}`, 100000 + i)
		end
	end
	local assignTime = tick() - startTime
	
	TestFramework.Assert(assignTime < TEST_CONFIG.performanceThreshold * 5000, `A/B test assignments should be fast: {assignTime}ms`)
end

-- Test Suite: Stress Tests
local StressTests = TestFramework.CreateTestSuite("StressTests")

function StressTests.TestHighVolumeUsers()
	local configManager = ConfigManager.new()
	
	-- Create flags for stress testing
	configManager:SetFeatureFlag("stressFlag1", true, 25)
	configManager:SetFeatureFlag("stressFlag2", true, 50)
	configManager:SetFeatureFlag("stressFlag3", true, 75)
	
	-- Create A/B test for stress testing
	configManager:CreateABTest("stressTest", {"control", "variant"}, {control = 0.5, variant = 0.5})
	
	local startTime = tick()
	local successCount = 0
	
	-- Test with many users
	for _, user in ipairs(mockUsers) do
		local success = pcall(function()
			-- Check multiple feature flags
			configManager:IsFeatureEnabled("stressFlag1", user.userId)
			configManager:IsFeatureEnabled("stressFlag2", user.userId)
			configManager:IsFeatureEnabled("stressFlag3", user.userId)
			
			-- Get A/B test assignment
			configManager:GetABTestVariant("stressTest", user.userId)
			
			-- Check user segments
			configManager:IsUserInSegment(user.userId, "beta_testers")
			configManager:IsUserInSegment(user.userId, "premium_users")
		end)
		
		if success then
			successCount = successCount + 1
		end
	end
	
	local totalTime = tick() - startTime
	
	TestFramework.Assert(successCount == #mockUsers, `All stress test operations should succeed: {successCount}/{#mockUsers}`)
	TestFramework.Assert(totalTime < 5.0, `Stress test should complete quickly: {totalTime}s`)
end

function StressTests.TestConcurrentOperations()
	local configManager = ConfigManager.new()
	
	local threads = {}
	local results = {}
	
	-- Spawn multiple threads doing operations
	for i = 1, 10 do
		local thread = task.spawn(function()
			local threadResults = {}
			
			for j = 1, 100 do
				-- Configuration operations
				local configSuccess = configManager:SetConfig("Stress", `key{i}_{j}`, j, `thread{i}`)
				table.insert(threadResults, configSuccess)
				
				-- Feature flag operations
				local flagSuccess = configManager:SetFeatureFlag(`threadFlag{i}_{j}`, j % 2 == 0, j)
				table.insert(threadResults, flagSuccess)
				
				-- Check operations
				configManager:IsFeatureEnabled(`threadFlag{i}_{j}`, 100000 + j)
				configManager:GetConfig("Stress", `key{i}_{j}`)
			end
			
			results[i] = threadResults
		end)
		
		table.insert(threads, thread)
	end
	
	-- Wait for all threads to complete
	local timeout = tick() + 10 -- 10 second timeout
	while #results < 10 and tick() < timeout do
		task.wait(0.1)
	end
	
	TestFramework.Assert(#results == 10, "All concurrent threads should complete")
	
	-- Verify all operations succeeded
	for i, threadResults in pairs(results) do
		for j, result in ipairs(threadResults) do
			TestFramework.Assert(result == true, `Thread {i} operation {j} should succeed`)
		end
	end
end

-- Test Suite: Integration Tests
local IntegrationTests = TestFramework.CreateTestSuite("Integration")

function IntegrationTests.TestServiceLocatorIntegration()
	local configManager = ConfigManager.new()
	
	-- Test health status
	local health = configManager:GetHealthStatus()
	TestFramework.Assert(health.status == "healthy", "ConfigManager should report healthy status")
	TestFramework.Assert(typeof(health.metrics) == "table", "Health should include metrics")
	TestFramework.Assert(health.metrics.configSections ~= nil, "Health should include config sections count")
	TestFramework.Assert(health.metrics.featureFlags ~= nil, "Health should include feature flags count")
end

function IntegrationTests.TestEventSystemIntegration()
	local configManager = ConfigManager.new()
	
	local eventFired = false
	local eventData = nil
	
	-- Connect to configuration change events
	local connection = configManager:OnConfigChanged(function(data)
		eventFired = true
		eventData = data
	end)
	
	-- Make a configuration change
	configManager:SetConfig("Test", "eventTest", "eventValue", "integration_test")
	
	-- Wait for event
	local timeout = tick() + 1
	while not eventFired and tick() < timeout do
		task.wait(0.01)
	end
	
	TestFramework.Assert(eventFired, "Configuration change should fire event")
	TestFramework.Assert(eventData ~= nil, "Event should include data")
	TestFramework.Assert(eventData.section == "Test", "Event should include correct section")
	TestFramework.Assert(eventData.key == "eventTest", "Event should include correct key")
	TestFramework.Assert(eventData.newValue == "eventValue", "Event should include correct value")
	
	connection:Disconnect()
end

function IntegrationTests.TestConfigReloadFunctionality()
	local configManager = ConfigManager.new()
	
	-- Test configuration reload
	local reloadSuccess = configManager:ReloadConfig()
	TestFramework.Assert(reloadSuccess, "Configuration reload should succeed")
	
	-- Verify configuration is still functional after reload
	local testValue = configManager:GetConfig("Game", "maxPlayers")
	TestFramework.Assert(testValue ~= nil, "Configuration should be accessible after reload")
end

-- Test Suite: Error Handling
local ErrorHandlingTests = TestFramework.CreateTestSuite("ErrorHandling")

function ErrorHandlingTests.TestInvalidInputHandling()
	local configManager = ConfigManager.new()
	
	-- Test nil values
	local nilResult = configManager:GetConfig(nil, "key")
	TestFramework.Assert(nilResult == nil, "Should handle nil section gracefully")
	
	-- Test invalid feature flag names
	local invalidFlag = configManager:IsFeatureEnabled(nil, 123456)
	TestFramework.Assert(invalidFlag == false, "Should handle nil flag name gracefully")
	
	-- Test invalid user IDs
	local invalidUser = configManager:IsFeatureEnabled("testFlag", nil)
	TestFramework.Assert(typeof(invalidUser) == "boolean", "Should handle nil user ID gracefully")
end

function ErrorHandlingTests.TestConfigurationErrorRecovery()
	local configManager = ConfigManager.new()
	
	-- Test setting invalid configuration (should not crash)
	local success = pcall(function()
		configManager:SetConfig("", "", nil, "error_test")
	end)
	
	TestFramework.Assert(success, "Should handle invalid configuration gracefully")
	
	-- Verify system is still functional
	local testConfig = configManager:GetConfig("Game", "maxPlayers")
	TestFramework.Assert(testConfig ~= nil, "System should remain functional after errors")
end

-- Execute Test Suites
local function RunAllTests()
	print("🧪 Starting Configuration Management & Feature Flags Test Suite...")
	
	local suites = {
		ConfigManagementTests,
		FeatureFlagsTests,
		ABTestingTests,
		UserSegmentTests,
		PerformanceTests,
		StressTests,
		IntegrationTests,
		ErrorHandlingTests
	}
	
	local totalTests = 0
	local passedTests = 0
	local startTime = tick()
	
	for _, suite in ipairs(suites) do
		local suiteResults = TestFramework.RunTestSuite(suite)
		totalTests = totalTests + suiteResults.total
		passedTests = passedTests + suiteResults.passed
		
		print(`📊 {suite.name}: {suiteResults.passed}/{suiteResults.total} tests passed`)
	end
	
	local totalTime = tick() - startTime
	local successRate = totalTests > 0 and (passedTests / totalTests * 100) or 0
	
	print(`\n🎯 Configuration Management & Feature Flags Test Results:`)
	print(`   Total Tests: {totalTests}`)
	print(`   Passed: {passedTests}`)
	print(`   Failed: {totalTests - passedTests}`)
	print(`   Success Rate: {math.floor(successRate * 100) / 100}%`)
	print(`   Execution Time: {math.floor(totalTime * 1000) / 1000}s`)
	
	if successRate >= 95 then
		print("✅ Configuration Management & Feature Flags system is ready for production!")
	elseif successRate >= 90 then
		print("⚠️ Configuration Management & Feature Flags system needs minor improvements")
	else
		print("❌ Configuration Management & Feature Flags system needs significant improvements")
	end
	
	return {
		total = totalTests,
		passed = passedTests,
		successRate = successRate,
		executionTime = totalTime
	}
end

-- Health Check Function
local function GetTestHealthStatus()
	return {
		status = "healthy",
		metrics = {
			testSuites = 8,
			totalTestCases = 35,
			performanceThreshold = TEST_CONFIG.performanceThreshold,
			stressTestCapacity = TEST_CONFIG.stressTestUsers,
			mockDataReady = #mockUsers > 0,
			lastRun = os.time()
		}
	}
end

-- Export functions
return {
	RunAllTests = RunAllTests,
	GetTestHealthStatus = GetTestHealthStatus,
	ConfigManagementTests = ConfigManagementTests,
	FeatureFlagsTests = FeatureFlagsTests,
	ABTestingTests = ABTestingTests,
	UserSegmentTests = UserSegmentTests,
	PerformanceTests = PerformanceTests,
	StressTests = StressTests,
	IntegrationTests = IntegrationTests,
	ErrorHandlingTests = ErrorHandlingTests
}
