-- AnalyticsEngineTests.lua
-- Comprehensive unit tests for Analytics Engine system
-- Part of Phase 2.6: Advanced Logging & Analytics

--[[
	TEST COVERAGE REQUIREMENTS:
	✅ Analytics Engine core functionality
	✅ Real-time event processing
	✅ Metric aggregation and alerting
	✅ Player behavior analytics
	✅ Dashboard integration
	✅ Error handling and edge cases
	✅ Performance benchmarks
	✅ Memory management validation
	✅ Service Locator integration
	✅ Configuration management
--]]

--!strict

-- Test Framework
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TestFramework = require(ReplicatedStorage.Shared.TestFramework)
local ServiceLocator = require(ReplicatedStorage.Shared.ServiceLocator)

-- System Under Test
local AnalyticsEngine = require(script.Parent.Parent.Core.AnalyticsEngine)
local Dashboard = require(script.Parent.Parent.Core.Dashboard) 
local Logging = require(ReplicatedStorage.Shared.Logging)

-- Test Configuration
local TEST_CONFIG = {
	timeout = 5.0,
	performanceThreshold = 0.001, -- 1ms
	memoryThreshold = 1024 * 1024, -- 1MB
	testEventCount = 1000,
	concurrentConnections = 50
}

-- Test Data
local SAMPLE_EVENTS = {
	{
		type = "error",
		source = "TestModule",
		message = "Test error message",
		timestamp = tick(),
		data = {
			stackTrace = "TestModule.test:10",
			severity = "high",
			userId = 123
		}
	},
	{
		type = "performance", 
		source = "TestModule",
		message = "Performance metric",
		timestamp = tick(),
		data = {
			metric = {
				name = "ResponseTime",
				value = 25.5,
				unit = "ms"
			},
			context = "test_operation"
		}
	},
	{
		type = "player",
		source = "TestModule", 
		message = "Player event",
		timestamp = tick(),
		data = {
			event = {
				userId = 123,
				eventType = "player_join",
				gameMode = "competitive",
				mapId = "test_map"
			}
		}
	}
}

-- Test Suite Definition
local AnalyticsEngineTestSuite = TestFramework.CreateTestSuite("AnalyticsEngine")

-- Helper Functions
local function generateTestEvent(eventType: string, overrides: {[string]: any}?): any
	local baseEvent = nil
	for _, event in ipairs(SAMPLE_EVENTS) do
		if event.type == eventType then
			baseEvent = event
			break
		end
	end
	
	if not baseEvent then
		error("Unknown event type: " .. eventType)
	end
	
	local testEvent = {}
	for key, value in pairs(baseEvent) do
		testEvent[key] = value
	end
	
	if overrides then
		for key, value in pairs(overrides) do
			testEvent[key] = value
		end
	end
	
	return testEvent
end

local function waitForCondition(condition: () -> boolean, timeout: number): boolean
	local startTime = tick()
	while tick() - startTime < timeout do
		if condition() then
			return true
		end
		wait(0.1)
	end
	return false
end

-- Test: Analytics Engine Initialization
AnalyticsEngineTestSuite:AddTest("Init_ShouldInitializeSuccessfully", function()
	-- Arrange & Act
	local result = AnalyticsEngine.Init()
	
	-- Assert
	TestFramework.Assert(result == true, "AnalyticsEngine should initialize successfully")
	
	-- Verify service registration
	local service = ServiceLocator.Get("AnalyticsEngine")
	TestFramework.Assert(service ~= nil, "AnalyticsEngine should be registered with ServiceLocator")
	
	-- Verify health check
	local health = AnalyticsEngine.GetHealth()
	TestFramework.Assert(health.status == "healthy", "AnalyticsEngine should be healthy after init")
end)

-- Test: Event Recording
AnalyticsEngineTestSuite:AddTest("RecordEvent_ShouldProcessEventSuccessfully", function()
	-- Arrange
	local testEvent = generateTestEvent("error")
	
	-- Act
	local result = AnalyticsEngine.RecordEvent(testEvent)
	
	-- Assert
	TestFramework.Assert(result == true, "Event should be recorded successfully")
	
	-- Verify event appears in statistics
	wait(0.1) -- Allow processing
	local stats = AnalyticsEngine.GetStatistics()
	TestFramework.Assert(stats.totalEvents > 0, "Total events should be incremented")
end)

-- Test: Metric Aggregation
AnalyticsEngineTestSuite:AddTest("MetricAggregation_ShouldAggregateCorrectly", function()
	-- Arrange
	local responseTimeEvents = {
		generateTestEvent("performance", {data = {metric = {name = "ResponseTime", value = 10}}}),
		generateTestEvent("performance", {data = {metric = {name = "ResponseTime", value = 20}}}),
		generateTestEvent("performance", {data = {metric = {name = "ResponseTime", value = 30}}})
	}
	
	-- Act
	for _, event in ipairs(responseTimeEvents) do
		AnalyticsEngine.RecordEvent(event)
	end
	
	-- Wait for aggregation
	wait(0.2)
	
	-- Assert
	local aggregations = AnalyticsEngine.GetAggregations()
	local hasResponseTimeAgg = false
	
	for _, agg in pairs(aggregations) do
		if agg.name == "ResponseTime" then
			hasResponseTimeAgg = true
			TestFramework.Assert(agg.count == 3, "Should aggregate 3 events")
			TestFramework.Assert(agg.average == 20, "Average should be 20")
			TestFramework.Assert(agg.min == 10, "Min should be 10")
			TestFramework.Assert(agg.max == 30, "Max should be 30")
		end
	end
	
	TestFramework.Assert(hasResponseTimeAgg, "Should have ResponseTime aggregation")
end)

-- Test: Alert Generation
AnalyticsEngineTestSuite:AddTest("AlertGeneration_ShouldTriggerOnThresholds", function()
	-- Arrange - Generate high error rate
	local errorEvents = {}
	for i = 1, 10 do
		table.insert(errorEvents, generateTestEvent("error"))
	end
	
	-- Act
	for _, event in ipairs(errorEvents) do
		AnalyticsEngine.RecordEvent(event)
	end
	
	-- Wait for processing
	wait(0.3)
	
	-- Assert
	local alerts = AnalyticsEngine.GetActiveAlerts()
	local hasErrorRateAlert = false
	
	for _, alert in ipairs(alerts) do
		if alert.type == "high_error_rate" then
			hasErrorRateAlert = true
			TestFramework.Assert(alert.severity == "high", "Error rate alert should be high severity")
		end
	end
	
	TestFramework.Assert(hasErrorRateAlert, "Should generate error rate alert")
end)

-- Test: Player Analytics
AnalyticsEngineTestSuite:AddTest("PlayerAnalytics_ShouldTrackSegmentation", function()
	-- Arrange
	local playerEvents = {
		generateTestEvent("player", {data = {event = {userId = 100, eventType = "player_join"}}}),
		generateTestEvent("player", {data = {event = {userId = 101, eventType = "player_join"}}}),
		generateTestEvent("player", {data = {event = {userId = 100, eventType = "level_complete"}}}),
	}
	
	-- Act
	for _, event in ipairs(playerEvents) do
		AnalyticsEngine.RecordEvent(event)
	end
	
	wait(0.2)
	
	-- Assert
	local segments = AnalyticsEngine.GetPlayerSegments()
	TestFramework.Assert(type(segments) == "table", "Should return player segments")
	
	local hasPlayerSegments = false
	for segmentId in pairs(segments) do
		hasPlayerSegments = true
		break
	end
	TestFramework.Assert(hasPlayerSegments, "Should have player segments")
end)

-- Test: Performance Benchmarks
AnalyticsEngineTestSuite:AddTest("Performance_ShouldMeetResponseTimeThresholds", function()
	-- Arrange
	local testEvent = generateTestEvent("performance")
	
	-- Act & Assert
	local startTime = tick()
	for i = 1, 100 do
		AnalyticsEngine.RecordEvent(testEvent)
	end
	local totalTime = tick() - startTime
	local avgTime = totalTime / 100
	
	TestFramework.Assert(avgTime < TEST_CONFIG.performanceThreshold, 
		string.format("Average event recording time (%.4fms) should be under threshold (%.4fms)", 
		avgTime * 1000, TEST_CONFIG.performanceThreshold * 1000))
end)

-- Test: Memory Management
AnalyticsEngineTestSuite:AddTest("MemoryManagement_ShouldCleanupOldData", function()
	-- Arrange - Generate many events
	local testEvent = generateTestEvent("error")
	
	-- Act - Record many events
	for i = 1, 500 do
		AnalyticsEngine.RecordEvent(testEvent)
	end
	
	wait(0.5) -- Allow processing and cleanup
	
	-- Assert - Memory should be managed
	local health = AnalyticsEngine.GetHealth()
	TestFramework.Assert(health.memoryUsage < TEST_CONFIG.memoryThreshold,
		"Memory usage should be under threshold after cleanup")
end)

-- Test: Error Handling
AnalyticsEngineTestSuite:AddTest("ErrorHandling_ShouldHandleInvalidEvents", function()
	-- Arrange
	local invalidEvents = {
		nil,
		{}, -- Missing required fields
		{type = "unknown_type"}, -- Invalid type
		{type = "error", source = nil}, -- Invalid source
	}
	
	-- Act & Assert
	for _, event in ipairs(invalidEvents) do
		local result = AnalyticsEngine.RecordEvent(event)
		TestFramework.Assert(result == false, "Should reject invalid events")
	end
end)

-- Test: Concurrent Access
AnalyticsEngineTestSuite:AddTest("ConcurrentAccess_ShouldHandleMultipleClients", function()
	-- Arrange
	local testEvent = generateTestEvent("performance")
	local results = {}
	
	-- Act - Simulate concurrent access
	for i = 1, 10 do
		spawn(function()
			local success = AnalyticsEngine.RecordEvent(testEvent)
			table.insert(results, success)
		end)
	end
	
	-- Wait for completion
	waitForCondition(function() return #results >= 10 end, TEST_CONFIG.timeout)
	
	-- Assert
	TestFramework.Assert(#results == 10, "All concurrent requests should complete")
	for _, result in ipairs(results) do
		TestFramework.Assert(result == true, "All concurrent requests should succeed")
	end
end)

-- Dashboard Test Suite
local DashboardTestSuite = TestFramework.CreateTestSuite("Dashboard")

-- Test: Dashboard Initialization
DashboardTestSuite:AddTest("Init_ShouldInitializeSuccessfully", function()
	-- Act
	local result = Dashboard.Init()
	
	-- Assert
	TestFramework.Assert(result == true, "Dashboard should initialize successfully")
	
	-- Verify service registration
	local service = ServiceLocator.Get("Dashboard")
	TestFramework.Assert(service ~= nil, "Dashboard should be registered with ServiceLocator")
	
	-- Verify health
	local health = Dashboard.GetHealth()
	TestFramework.Assert(health.status == "healthy", "Dashboard should be healthy")
end)

-- Test: Metric Registration
DashboardTestSuite:AddTest("RegisterMetric_ShouldRegisterSuccessfully", function()
	-- Act
	local result = Dashboard.RegisterMetric("TestMetric", "units", 100)
	
	-- Assert
	TestFramework.Assert(result == true, "Metric should register successfully")
	
	-- Verify in snapshot
	local snapshot = Dashboard.GetSnapshot()
	TestFramework.Assert(snapshot.metrics["TestMetric"] ~= nil, "Metric should appear in snapshot")
end)

-- Test: Metric Updates
DashboardTestSuite:AddTest("UpdateMetric_ShouldUpdateSuccessfully", function()
	-- Arrange
	Dashboard.RegisterMetric("UpdateTestMetric", "units", 50)
	
	-- Act
	local result = Dashboard.UpdateMetric("UpdateTestMetric", 75)
	
	-- Assert
	TestFramework.Assert(result == true, "Metric update should succeed")
	
	wait(0.1) -- Allow processing
	local snapshot = Dashboard.GetSnapshot()
	local metric = snapshot.metrics["UpdateTestMetric"]
	TestFramework.Assert(metric.value == 75, "Metric value should be updated")
end)

-- Test: Alert Notifications
DashboardTestSuite:AddTest("NotifyAlert_ShouldProcessAlerts", function()
	-- Arrange
	local testAlert = {
		id = "test_alert_123",
		type = "test_alert",
		severity = "high",
		message = "Test alert message",
		timestamp = tick(),
		acknowledged = false,
		data = {test = true}
	}
	
	-- Act
	local result = Dashboard.NotifyAlert(testAlert)
	
	-- Assert
	TestFramework.Assert(result == true, "Alert notification should succeed")
	
	wait(0.1) -- Allow processing
	local snapshot = Dashboard.GetSnapshot()
	local hasAlert = false
	for _, alert in ipairs(snapshot.alerts) do
		if alert.id == testAlert.id then
			hasAlert = true
			break
		end
	end
	TestFramework.Assert(hasAlert, "Alert should appear in snapshot")
end)

-- Test: Client Connections
DashboardTestSuite:AddTest("ClientConnection_ShouldTrackConnections", function()
	-- Act
	local connectResult = Dashboard.ConnectClient(12345)
	
	-- Assert
	TestFramework.Assert(connectResult == true, "Client connection should succeed")
	
	local health = Dashboard.GetHealth()
	TestFramework.Assert(health.connectedClients > 0, "Should track connected clients")
	
	-- Test disconnection
	local disconnectResult = Dashboard.DisconnectClient(12345)
	TestFramework.Assert(disconnectResult == true, "Client disconnection should succeed")
end)

-- Integration Test Suite
local IntegrationTestSuite = TestFramework.CreateTestSuite("AnalyticsIntegration")

-- Test: End-to-End Event Flow
IntegrationTestSuite:AddTest("EndToEndFlow_ShouldProcessEventThroughDashboard", function()
	-- Arrange
	local testEvent = generateTestEvent("performance", {
		data = {
			metric = {
				name = "IntegrationTestMetric",
				value = 42,
				unit = "ms"
			}
		}
	})
	
	Dashboard.RegisterMetric("IntegrationTestMetric", "ms", 50)
	
	-- Act
	AnalyticsEngine.RecordEvent(testEvent)
	
	-- Wait for processing
	wait(0.3)
	
	-- Assert
	local dashboardSnapshot = Dashboard.GetSnapshot()
	local analyticsStats = AnalyticsEngine.GetStatistics()
	
	TestFramework.Assert(analyticsStats.totalEvents > 0, "Analytics should process event")
	TestFramework.Assert(dashboardSnapshot.metrics["IntegrationTestMetric"] ~= nil, 
		"Dashboard should have metric")
end)

-- Test: Service Locator Integration
IntegrationTestSuite:AddTest("ServiceLocatorIntegration_ShouldResolveServices", function()
	-- Act
	local analyticsService = ServiceLocator.Get("AnalyticsEngine")
	local dashboardService = ServiceLocator.Get("Dashboard")
	
	-- Assert
	TestFramework.Assert(analyticsService ~= nil, "Should resolve AnalyticsEngine service")
	TestFramework.Assert(dashboardService ~= nil, "Should resolve Dashboard service")
	
	-- Verify functionality through service locator
	local health1 = analyticsService.GetHealth()
	local health2 = dashboardService.GetHealth()
	
	TestFramework.Assert(health1.status == "healthy", "AnalyticsEngine should be healthy via ServiceLocator")
	TestFramework.Assert(health2.status == "healthy", "Dashboard should be healthy via ServiceLocator")
end)

-- Performance Test Suite
local PerformanceTestSuite = TestFramework.CreateTestSuite("AnalyticsPerformance")

-- Test: High-Volume Event Processing
PerformanceTestSuite:AddTest("HighVolumeProcessing_ShouldMaintainPerformance", function()
	-- Arrange
	local eventCount = TEST_CONFIG.testEventCount
	local testEvent = generateTestEvent("performance")
	
	-- Act
	local startTime = tick()
	for i = 1, eventCount do
		AnalyticsEngine.RecordEvent(testEvent)
	end
	local totalTime = tick() - startTime
	
	-- Assert
	local avgTime = totalTime / eventCount
	TestFramework.Assert(avgTime < TEST_CONFIG.performanceThreshold,
		string.format("High volume processing average time (%.4fms) should be under threshold", 
		avgTime * 1000))
	
	-- Verify all events processed
	wait(1.0) -- Allow processing
	local stats = AnalyticsEngine.GetStatistics()
	TestFramework.Assert(stats.totalEvents >= eventCount, 
		"All events should be processed")
end)

-- Test Runner
local function runAllTests()
	print("🚀 Starting Analytics Engine Test Suite...")
	
	local results = {
		AnalyticsEngineTestSuite:Run(),
		DashboardTestSuite:Run(),
		IntegrationTestSuite:Run(),
		PerformanceTestSuite:Run()
	}
	
	local totalTests = 0
	local totalPassed = 0
	local totalFailed = 0
	
	for _, result in ipairs(results) do
		totalTests += result.totalTests
		totalPassed += result.passed
		totalFailed += result.failed
	end
	
	local successRate = totalTests > 0 and (totalPassed / totalTests * 100) or 0
	
	print(string.format("📊 Test Results: %d/%d passed (%.1f%% success rate)", 
		totalPassed, totalTests, successRate))
	
	if totalFailed > 0 then
		print(string.format("❌ %d tests failed", totalFailed))
	else
		print("✅ All tests passed!")
	end
	
	return {
		totalTests = totalTests,
		passed = totalPassed,
		failed = totalFailed,
		successRate = successRate
	}
end

-- Export test runner
return {
	RunTests = runAllTests,
	Suites = {
		AnalyticsEngine = AnalyticsEngineTestSuite,
		Dashboard = DashboardTestSuite,
		Integration = IntegrationTestSuite,
		Performance = PerformanceTestSuite
	}
}
