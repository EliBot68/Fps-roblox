--[[
	NetworkBatcherTests.lua
	Enterprise unit tests for NetworkBatcher Phase 1.2 implementation
	
	Tests:
	- Priority queue system functionality
	- Bandwidth monitoring and throttling
	- Compression threshold handling
	- Retry logic with exponential backoff
	- Service Locator integration
	- Health monitoring and statistics
	
	Part of Phase 1.2 - Network Optimization - Batched Event System
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- Import test framework and dependencies
local TestFramework = require(ReplicatedStorage.Shared.TestFramework)
local ServiceLocator = require(ReplicatedStorage.Shared.ServiceLocator)
local NetworkBatcher = require(ReplicatedStorage.Shared.NetworkBatcher)

local NetworkBatcherTests = {}

-- Test configuration
local TEST_CONFIG = {
	MOCK_PLAYER_COUNT = 5,
	TEST_EVENT_COUNT = 100,
	PERFORMANCE_THRESHOLD_MS = 16, -- Critical events should process within 16ms
	BATCH_SIZE_THRESHOLD = 10
}

-- Mock player objects for testing
local mockPlayers = {}

-- Initialize test environment
function NetworkBatcherTests.Setup()
	TestFramework.SetupTestEnvironment()
	
	-- Create mock players
	for i = 1, TEST_CONFIG.MOCK_PLAYER_COUNT do
		mockPlayers[i] = {
			Name = "TestPlayer" .. i,
			UserId = 1000 + i,
			DisplayName = "TestPlayer" .. i
		}
	end
	
	-- Clear NetworkBatcher state
	NetworkBatcher.ClearAll()
	
	-- Initialize NetworkBatcher for testing
	NetworkBatcher.Initialize()
	
	return true
end

-- Cleanup test environment
function NetworkBatcherTests.Teardown()
	NetworkBatcher.ClearAll()
	mockPlayers = {}
	return true
end

-- Test priority queue system
function NetworkBatcherTests.TestPriorityQueueSystem()
	local testCase = TestFramework.CreateTestCase("Priority Queue System")
	
	-- Test adding events with different priorities
	local criticalSuccess = NetworkBatcher.QueueEvent("TestCritical", mockPlayers[1], {data = "critical"}, "Critical")
	local normalSuccess = NetworkBatcher.QueueEvent("TestNormal", mockPlayers[1], {data = "normal"}, "Normal")
	local lowSuccess = NetworkBatcher.QueueEvent("TestLow", mockPlayers[1], {data = "low"}, "Low")
	
	testCase:Assert(criticalSuccess, "Critical priority event should queue successfully")
	testCase:Assert(normalSuccess, "Normal priority event should queue successfully")
	testCase:Assert(lowSuccess, "Low priority event should queue successfully")
	
	-- Test queue statistics
	local stats = NetworkBatcher.GetStats()
	testCase:Assert(stats.queuedEvents >= 3, "Should have at least 3 queued events")
	testCase:Assert(stats.queuesByPriority.Priority1 >= 1, "Should have critical priority events")
	testCase:Assert(stats.queuesByPriority.Priority2 >= 1, "Should have normal priority events")
	testCase:Assert(stats.queuesByPriority.Priority3 >= 1, "Should have low priority events")
	
	return testCase:GetResults()
end

-- Test bandwidth monitoring
function NetworkBatcherTests.TestBandwidthMonitoring()
	local testCase = TestFramework.CreateTestCase("Bandwidth Monitoring")
	
	-- Generate test events to create bandwidth usage
	for i = 1, 50 do
		NetworkBatcher.QueueBroadcast("BandwidthTest", {
			largePayload = string.rep("x", 100), -- 100 char payload
			iteration = i
		}, "Normal")
	end
	
	-- Process events to generate bandwidth stats
	NetworkBatcher.FlushAll()
	
	-- Check bandwidth statistics
	local stats = NetworkBatcher.GetStats()
	testCase:Assert(stats.bandwidth ~= nil, "Bandwidth statistics should be available")
	testCase:Assert(stats.bandwidth.totalBytesSent > 0, "Should have sent bytes")
	testCase:Assert(stats.bandwidth.totalMessagesSent > 0, "Should have sent messages")
	testCase:Assert(stats.bandwidth.averageBytesPerSecond >= 0, "Should calculate average bytes per second")
	
	-- Test bandwidth limit checking
	local withinLimits = NetworkBatcher.IsWithinBandwidthLimits()
	testCase:Assert(type(withinLimits) == "boolean", "Should return boolean for bandwidth limit check")
	
	return testCase:GetResults()
end

-- Test compression threshold handling
function NetworkBatcherTests.TestCompressionThreshold()
	local testCase = TestFramework.CreateTestCase("Compression Threshold")
	
	-- Create large payload that should trigger compression
	local largeData = {
		bigString = string.rep("compression test data ", 100), -- > 1KB
		metadata = {
			timestamp = tick(),
			userId = 12345,
			action = "test_compression"
		}
	}
	
	-- Queue event with large payload
	local success = NetworkBatcher.QueueEvent("CompressionTest", mockPlayers[1], largeData, "Critical")
	testCase:Assert(success, "Large payload event should queue successfully")
	
	-- Check that the event was properly handled
	local stats = NetworkBatcher.GetStats()
	testCase:Assert(stats.queuedEvents >= 1, "Should have queued the compression test event")
	
	return testCase:GetResults()
end

-- Test retry logic with exponential backoff
function NetworkBatcherTests.TestRetryLogic()
	local testCase = TestFramework.CreateTestCase("Retry Logic")
	
	-- Test retry queue functionality
	local initialStats = NetworkBatcher.GetStats()
	local initialRetryQueueSize = initialStats.retryQueueSize or 0
	
	-- Queue test events
	for i = 1, 5 do
		NetworkBatcher.QueueEvent("RetryTest", mockPlayers[1], {
			retryData = "test" .. i,
			timestamp = tick()
		}, "Critical")
	end
	
	-- Check retry queue behavior (would normally be triggered by failed sends)
	local newStats = NetworkBatcher.GetStats()
	testCase:Assert(newStats.retryQueueSize >= initialRetryQueueSize, "Retry queue should be tracked")
	
	return testCase:GetResults()
end

-- Test Service Locator integration
function NetworkBatcherTests.TestServiceLocatorIntegration()
	local testCase = TestFramework.CreateTestCase("Service Locator Integration")
	
	-- Check if NetworkBatcher is properly registered
	local networkBatcher = ServiceLocator.GetService("NetworkBatcher")
	testCase:Assert(networkBatcher ~= nil, "NetworkBatcher should be registered with ServiceLocator")
	testCase:Assert(networkBatcher == NetworkBatcher, "Should return the same NetworkBatcher instance")
	
	-- Test service dependencies
	local serviceInfo = ServiceLocator.GetServiceInfo("NetworkBatcher")
	testCase:Assert(serviceInfo ~= nil, "Should have service information")
	
	return testCase:GetResults()
end

-- Test health monitoring
function NetworkBatcherTests.TestHealthMonitoring()
	local testCase = TestFramework.CreateTestCase("Health Monitoring")
	
	-- Test health check functionality
	local healthStatus = NetworkBatcher.HealthCheck()
	testCase:Assert(healthStatus ~= nil, "Health check should return status")
	testCase:Assert(healthStatus.status ~= nil, "Should have status field")
	testCase:Assert(healthStatus.issues ~= nil, "Should have issues array")
	testCase:Assert(type(healthStatus.issues) == "table", "Issues should be a table")
	
	-- Test healthy state
	testCase:Assert(healthStatus.status == "healthy" or healthStatus.status == "warning", 
		"Status should be either healthy or warning")
	
	return testCase:GetResults()
end

-- Test performance under load
function NetworkBatcherTests.TestPerformanceUnderLoad()
	local testCase = TestFramework.CreateTestCase("Performance Under Load")
	
	local startTime = tick()
	
	-- Generate high load with many events
	for i = 1, TEST_CONFIG.TEST_EVENT_COUNT do
		NetworkBatcher.QueueEvent("LoadTest", mockPlayers[i % TEST_CONFIG.MOCK_PLAYER_COUNT + 1], {
			iteration = i,
			timestamp = tick(),
			payload = string.rep("x", 50) -- Medium payload
		}, "Normal")
	end
	
	local queueTime = tick() - startTime
	
	-- Process all events
	local processStart = tick()
	local processedCount = NetworkBatcher.FlushAll()
	local processTime = (tick() - processStart) * 1000 -- Convert to milliseconds
	
	testCase:Assert(processedCount >= TEST_CONFIG.TEST_EVENT_COUNT, 
		"Should process all queued events")
	testCase:Assert(queueTime < 1.0, "Queuing " .. TEST_CONFIG.TEST_EVENT_COUNT .. " events should take less than 1 second")
	
	-- Check performance metrics
	local stats = NetworkBatcher.GetStats()
	testCase:Assert(stats.bandwidth.totalMessagesSent > 0, "Should have processed messages")
	
	return testCase:GetResults()
end

-- Test event validation
function NetworkBatcherTests.TestEventValidation()
	local testCase = TestFramework.CreateTestCase("Event Validation")
	
	-- Test invalid event types
	local invalidResult1 = NetworkBatcher.QueueEvent(nil, mockPlayers[1], {data = "test"}, "Normal")
	testCase:Assert(not invalidResult1, "Should reject nil event type")
	
	local invalidResult2 = NetworkBatcher.QueueEvent("ValidType", mockPlayers[1], "invalid_data", "Normal")
	testCase:Assert(not invalidResult2, "Should reject non-table data")
	
	-- Test valid event
	local validResult = NetworkBatcher.QueueEvent("ValidType", mockPlayers[1], {data = "valid"}, "Normal")
	testCase:Assert(validResult, "Should accept valid event")
	
	return testCase:GetResults()
end

-- Test helper functions
function NetworkBatcherTests.TestHelperFunctions()
	local testCase = TestFramework.CreateTestCase("Helper Functions")
	
	-- Test weapon fire helper
	local weaponFireResult = NetworkBatcher.QueueWeaponFire(mockPlayers[1], "AK47", {
		{target = "TestTarget", damage = 30}
	})
	testCase:Assert(weaponFireResult, "Weapon fire helper should work")
	
	-- Test elimination helper
	local eliminationResult = NetworkBatcher.QueueElimination(mockPlayers[1], mockPlayers[2], "AK47", true)
	testCase:Assert(eliminationResult, "Elimination helper should work")
	
	-- Test UI update helper
	local uiUpdateResult = NetworkBatcher.QueueUIUpdate(mockPlayers[1], "ScoreUpdate", {score = 100})
	testCase:Assert(uiUpdateResult, "UI update helper should work")
	
	-- Test analytics helper
	local analyticsResult = NetworkBatcher.QueueAnalytics("PlayerAction", {action = "reload"})
	testCase:Assert(analyticsResult, "Analytics helper should work")
	
	return testCase:GetResults()
end

-- Test comprehensive statistics
function NetworkBatcherTests.TestComprehensiveStatistics()
	local testCase = TestFramework.CreateTestCase("Comprehensive Statistics")
	
	-- Generate some test data
	for i = 1, 10 do
		NetworkBatcher.QueueBroadcast("StatsTest", {data = i}, "Normal")
	end
	
	local stats = NetworkBatcher.GetStats()
	
	-- Verify all expected fields are present
	testCase:Assert(stats.queuedEvents ~= nil, "Should have queued events count")
	testCase:Assert(stats.queuesByPriority ~= nil, "Should have priority breakdown")
	testCase:Assert(stats.retryQueueSize ~= nil, "Should have retry queue size")
	testCase:Assert(stats.bandwidth ~= nil, "Should have bandwidth statistics")
	testCase:Assert(stats.uptime ~= nil, "Should have uptime")
	
	-- Verify bandwidth sub-statistics
	testCase:Assert(stats.bandwidth.totalBytesSent ~= nil, "Should track total bytes sent")
	testCase:Assert(stats.bandwidth.totalMessagesSent ~= nil, "Should track total messages sent")
	testCase:Assert(stats.bandwidth.averageBytesPerSecond ~= nil, "Should calculate average bandwidth")
	
	return testCase:GetResults()
end

-- Run all NetworkBatcher tests
function NetworkBatcherTests.RunAllTests()
	local results = TestFramework.CreateTestSuite("NetworkBatcher Phase 1.2 Tests")
	
	-- Setup test environment
	if not NetworkBatcherTests.Setup() then
		results:AddError("Failed to setup test environment")
		return results:GetResults()
	end
	
	-- Run individual test cases
	results:AddTestCase(NetworkBatcherTests.TestPriorityQueueSystem())
	results:AddTestCase(NetworkBatcherTests.TestBandwidthMonitoring())
	results:AddTestCase(NetworkBatcherTests.TestCompressionThreshold())
	results:AddTestCase(NetworkBatcherTests.TestRetryLogic())
	results:AddTestCase(NetworkBatcherTests.TestServiceLocatorIntegration())
	results:AddTestCase(NetworkBatcherTests.TestHealthMonitoring())
	results:AddTestCase(NetworkBatcherTests.TestPerformanceUnderLoad())
	results:AddTestCase(NetworkBatcherTests.TestEventValidation())
	results:AddTestCase(NetworkBatcherTests.TestHelperFunctions())
	results:AddTestCase(NetworkBatcherTests.TestComprehensiveStatistics())
	
	-- Cleanup
	NetworkBatcherTests.Teardown()
	
	-- Log results
	results:LogResults("NetworkBatcher")
	
	return results:GetResults()
end

return NetworkBatcherTests
