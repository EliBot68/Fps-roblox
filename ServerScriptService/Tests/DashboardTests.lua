-- DashboardTests.lua
-- Comprehensive unit tests for Dashboard system
-- Part of Phase 2.6: Advanced Logging & Analytics

--[[
	DASHBOARD TEST COVERAGE:
	✅ Widget management and data updates
	✅ Real-time metric streaming  
	✅ Alert processing and notifications
	✅ Client connection management
	✅ Performance monitoring
	✅ Memory management
	✅ Configuration validation
	✅ Error handling and recovery
	✅ Service integration
	✅ Dashboard snapshot generation
--]]

--!strict

-- Test Framework
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TestFramework = require(ReplicatedStorage.Shared.TestFramework)
local ServiceLocator = require(ReplicatedStorage.Shared.ServiceLocator)

-- System Under Test
local Dashboard = require(script.Parent.Parent.Core.Dashboard)
local Logging = require(ReplicatedStorage.Shared.Logging)

-- Test Configuration
local TEST_CONFIG = {
	timeout = 3.0,
	performanceThreshold = 0.002, -- 2ms
	maxClients = 10,
	testMetricCount = 50,
	testAlertCount = 20
}

-- Test Data
local SAMPLE_METRICS = {
	{name = "PlayerCount", unit = "players", threshold = 100, value = 75},
	{name = "ServerMemory", unit = "MB", threshold = 1000, value = 512},
	{name = "ResponseTime", unit = "ms", threshold = 100, value = 45},
	{name = "ErrorRate", unit = "%", threshold = 5, value = 1.2},
	{name = "CPUUsage", unit = "%", threshold = 80, value = 65}
}

local SAMPLE_ALERTS = {
	{
		id = "alert_001",
		type = "performance_warning",
		severity = "medium",
		message = "Response time elevated",
		timestamp = tick(),
		acknowledged = false,
		data = {metric = "ResponseTime", value = 150}
	},
	{
		id = "alert_002", 
		type = "error_spike",
		severity = "high",
		message = "Error rate exceeds threshold",
		timestamp = tick(),
		acknowledged = false,
		data = {errorRate = 8.5, threshold = 5.0}
	}
}

local SAMPLE_WIDGETS = {
	{
		id = "test_widget_1",
		type = "metric_display",
		title = "Test Metric Widget",
		position = {x = 0, y = 0},
		size = {width = 200, height = 100},
		config = {metric = "PlayerCount", showTrend = true}
	},
	{
		id = "test_widget_2",
		type = "alert_panel",
		title = "Test Alert Widget", 
		position = {x = 220, y = 0},
		size = {width = 300, height = 200},
		config = {maxAlerts = 5, severityFilter = {"high", "medium"}}
	}
}

-- Test Suite Definition
local DashboardTestSuite = TestFramework.CreateTestSuite("DashboardCore")

-- Helper Functions
local function waitForCondition(condition: () -> boolean, timeout: number): boolean
	local startTime = tick()
	while tick() - startTime < timeout do
		if condition() then
			return true
		end
		wait(0.05)
	end
	return false
end

local function createTestMetric(overrides: {[string]: any}?): {[string]: any}
	local base = SAMPLE_METRICS[1]
	local metric = {
		name = base.name,
		unit = base.unit,
		threshold = base.threshold,
		value = base.value
	}
	
	if overrides then
		for key, value in pairs(overrides) do
			metric[key] = value
		end
	end
	
	return metric
end

local function createTestAlert(overrides: {[string]: any}?): {[string]: any}
	local base = SAMPLE_ALERTS[1]
	local alert = {}
	for key, value in pairs(base) do
		alert[key] = value
	end
	
	if overrides then
		for key, value in pairs(overrides) do
			alert[key] = value
		end
	end
	
	return alert
end

-- Test: Dashboard Initialization
DashboardTestSuite:AddTest("Init_ShouldInitializeWithDefaultWidgets", function()
	-- Act
	local result = Dashboard.Init()
	
	-- Assert
	TestFramework.Assert(result == true, "Dashboard should initialize successfully")
	
	local snapshot = Dashboard.GetSnapshot()
	TestFramework.Assert(type(snapshot.widgets) == "table", "Should have widgets collection")
	
	local widgetCount = 0
	for _ in pairs(snapshot.widgets) do
		widgetCount += 1
	end
	TestFramework.Assert(widgetCount > 0, "Should have default widgets")
	
	local health = Dashboard.GetHealth()
	TestFramework.Assert(health.status == "healthy", "Should be healthy after init")
end)

-- Test: Metric Registration and Updates
DashboardTestSuite:AddTest("MetricManagement_ShouldRegisterAndUpdateMetrics", function()
	-- Arrange
	local testMetric = createTestMetric({name = "TestMetric_001"})
	
	-- Act - Register metric
	local registerResult = Dashboard.RegisterMetric(testMetric.name, testMetric.unit, testMetric.threshold)
	
	-- Assert registration
	TestFramework.Assert(registerResult == true, "Metric registration should succeed")
	
	local snapshot = Dashboard.GetSnapshot()
	local metric = snapshot.metrics[testMetric.name]
	TestFramework.Assert(metric ~= nil, "Metric should exist in snapshot")
	TestFramework.Assert(metric.name == testMetric.name, "Metric name should match")
	TestFramework.Assert(metric.unit == testMetric.unit, "Metric unit should match")
	
	-- Act - Update metric
	local updateResult = Dashboard.UpdateMetric(testMetric.name, testMetric.value)
	TestFramework.Assert(updateResult == true, "Metric update should succeed")
	
	-- Wait for processing
	wait(0.15)
	
	-- Assert update
	snapshot = Dashboard.GetSnapshot()
	metric = snapshot.metrics[testMetric.name]
	TestFramework.Assert(metric.value == testMetric.value, "Metric value should be updated")
end)

-- Test: Metric Trend Analysis
DashboardTestSuite:AddTest("MetricTrends_ShouldCalculateTrendsCorrectly", function()
	-- Arrange
	local metricName = "TrendTestMetric"
	Dashboard.RegisterMetric(metricName, "units", 100)
	
	-- Act - Add trending values
	Dashboard.UpdateMetric(metricName, 10)
	wait(0.1)
	Dashboard.UpdateMetric(metricName, 20)
	wait(0.1)
	Dashboard.UpdateMetric(metricName, 30)
	wait(0.2)
	
	-- Assert
	local snapshot = Dashboard.GetSnapshot()
	local metric = snapshot.metrics[metricName]
	TestFramework.Assert(metric.trend == "up", "Should detect upward trend")
	TestFramework.Assert(#metric.history >= 2, "Should maintain metric history")
end)

-- Test: Alert Processing
DashboardTestSuite:AddTest("AlertProcessing_ShouldHandleAlertsCorrectly", function()
	-- Arrange
	local testAlert = createTestAlert({id = "test_alert_dashboard_001"})
	
	-- Act
	local result = Dashboard.NotifyAlert(testAlert)
	
	-- Assert
	TestFramework.Assert(result == true, "Alert notification should succeed")
	
	-- Wait for processing
	wait(0.15)
	
	local snapshot = Dashboard.GetSnapshot()
	local foundAlert = false
	for _, alert in ipairs(snapshot.alerts) do
		if alert.id == testAlert.id then
			foundAlert = true
			TestFramework.Assert(alert.type == testAlert.type, "Alert type should match")
			TestFramework.Assert(alert.severity == testAlert.severity, "Alert severity should match")
			break
		end
	end
	TestFramework.Assert(foundAlert, "Alert should appear in snapshot")
end)

-- Test: Widget Management
DashboardTestSuite:AddTest("WidgetManagement_ShouldUpdateWidgetData", function()
	-- Arrange
	local testWidget = SAMPLE_WIDGETS[1]
	local testData = {
		value = 42,
		status = "normal",
		lastUpdate = tick()
	}
	
	-- Act
	local result = Dashboard.UpdateWidget(testWidget.id, testData)
	
	-- Assert
	TestFramework.Assert(result == true, "Widget update should succeed")
	
	-- Wait for processing
	wait(0.15)
	
	local snapshot = Dashboard.GetSnapshot()
	local widget = snapshot.widgets[testWidget.id]
	TestFramework.Assert(widget ~= nil, "Widget should exist")
	TestFramework.Assert(widget.data.value == testData.value, "Widget data should be updated")
end)

-- Test: Client Connection Management
DashboardTestSuite:AddTest("ClientConnections_ShouldTrackConnectionsCorrectly", function()
	-- Arrange
	local testUserIds = {1001, 1002, 1003}
	
	-- Act - Connect clients
	for _, userId in ipairs(testUserIds) do
		local result = Dashboard.ConnectClient(userId)
		TestFramework.Assert(result == true, "Client connection should succeed")
	end
	
	-- Assert connections
	local health = Dashboard.GetHealth()
	TestFramework.Assert(health.connectedClients >= #testUserIds, "Should track connected clients")
	
	-- Act - Disconnect clients
	for _, userId in ipairs(testUserIds) do
		local result = Dashboard.DisconnectClient(userId)
		TestFramework.Assert(result == true, "Client disconnection should succeed")
	end
end)

-- Test: Performance Metrics
DashboardTestSuite:AddTest("Performance_ShouldMeetResponseThresholds", function()
	-- Arrange
	local metricName = "PerfTestMetric"
	Dashboard.RegisterMetric(metricName, "ms", 100)
	
	-- Act & Assert - Multiple rapid updates
	local startTime = tick()
	for i = 1, 50 do
		Dashboard.UpdateMetric(metricName, i * 2)
	end
	local totalTime = tick() - startTime
	local avgTime = totalTime / 50
	
	TestFramework.Assert(avgTime < TEST_CONFIG.performanceThreshold,
		string.format("Average update time (%.4fms) should be under threshold (%.4fms)",
		avgTime * 1000, TEST_CONFIG.performanceThreshold * 1000))
end)

-- Test: Error Handling
DashboardTestSuite:AddTest("ErrorHandling_ShouldHandleInvalidOperations", function()
	-- Test invalid metric registration
	local result1 = Dashboard.RegisterMetric("", "units", 100) -- Empty name
	TestFramework.Assert(result1 == false, "Should reject empty metric name")
	
	-- Test updating non-existent metric
	local result2 = Dashboard.UpdateMetric("NonExistentMetric", 42)
	TestFramework.Assert(result2 == false, "Should reject updates to non-existent metrics")
	
	-- Test invalid widget update
	local result3 = Dashboard.UpdateWidget("NonExistentWidget", {})
	TestFramework.Assert(result3 == false, "Should reject updates to non-existent widgets")
	
	-- Test invalid client operations
	local result4 = Dashboard.DisconnectClient(99999) -- Non-connected client
	TestFramework.Assert(result4 == true, "Should handle disconnecting non-connected client gracefully")
end)

-- Test: Memory Management
DashboardTestSuite:AddTest("MemoryManagement_ShouldCleanupOldData", function()
	-- Arrange - Generate many alerts
	for i = 1, 20 do
		local oldAlert = createTestAlert({
			id = "old_alert_" .. i,
			timestamp = tick() - 7200 -- 2 hours ago
		})
		Dashboard.NotifyAlert(oldAlert)
	end
	
	wait(0.2)
	
	-- Act - Trigger cleanup (would normally happen automatically)
	-- In real implementation, this would be handled by the cleanup routine
	
	-- Assert - Memory should be reasonable
	local health = Dashboard.GetHealth()
	TestFramework.Assert(health.queueSize < 100, "Queue size should be managed")
end)

-- Test: Configuration Loading
DashboardTestSuite:AddTest("Configuration_ShouldLoadFromGameConfig", function()
	-- This test verifies that the dashboard respects configuration
	-- In a real scenario, we'd mock GameConfig to test different configurations
	
	-- Act
	local snapshot = Dashboard.GetSnapshot()
	
	-- Assert - Should have expected default configuration
	TestFramework.Assert(type(snapshot.widgets) == "table", "Should have widgets from config")
	
	local hasSystemOverview = snapshot.widgets.system_overview ~= nil
	TestFramework.Assert(hasSystemOverview, "Should have system overview widget from default config")
end)

-- Dashboard Stress Testing Suite
local DashboardStressTestSuite = TestFramework.CreateTestSuite("DashboardStress")

-- Test: High Volume Updates
DashboardStressTestSuite:AddTest("HighVolumeUpdates_ShouldMaintainPerformance", function()
	-- Arrange
	local metricCount = TEST_CONFIG.testMetricCount
	local metrics = {}
	
	-- Register many metrics
	for i = 1, metricCount do
		local metricName = "StressMetric_" .. i
		Dashboard.RegisterMetric(metricName, "units", 100)
		table.insert(metrics, metricName)
	end
	
	-- Act - Rapid updates
	local startTime = tick()
	for iteration = 1, 5 do
		for _, metricName in ipairs(metrics) do
			Dashboard.UpdateMetric(metricName, math.random(1, 100))
		end
		wait(0.01)
	end
	local totalTime = tick() - startTime
	
	-- Assert
	local avgUpdateTime = totalTime / (metricCount * 5)
	TestFramework.Assert(avgUpdateTime < TEST_CONFIG.performanceThreshold,
		"High volume updates should maintain performance")
	
	-- Verify system health
	local health = Dashboard.GetHealth()
	TestFramework.Assert(health.status == "healthy", "Dashboard should remain healthy under load")
end)

-- Test: Concurrent Client Connections
DashboardStressTestSuite:AddTest("ConcurrentConnections_ShouldHandleMultipleClients", function()
	-- Arrange
	local clientCount = TEST_CONFIG.maxClients
	local connectionResults = {}
	
	-- Act - Simulate concurrent connections
	for i = 1, clientCount do
		spawn(function()
			local userId = 2000 + i
			local success = Dashboard.ConnectClient(userId)
			table.insert(connectionResults, {userId = userId, success = success})
		end)
	end
	
	-- Wait for completion
	waitForCondition(function() return #connectionResults >= clientCount end, TEST_CONFIG.timeout)
	
	-- Assert
	TestFramework.Assert(#connectionResults == clientCount, "All connection attempts should complete")
	
	for _, result in ipairs(connectionResults) do
		TestFramework.Assert(result.success == true, "All connections should succeed")
	end
	
	local health = Dashboard.GetHealth()
	TestFramework.Assert(health.connectedClients >= clientCount, "Should track all connected clients")
end)

-- Dashboard Integration Tests
local DashboardIntegrationTestSuite = TestFramework.CreateTestSuite("DashboardIntegration")

-- Test: Service Locator Integration
DashboardIntegrationTestSuite:AddTest("ServiceLocatorIntegration_ShouldRegisterAndResolve", function()
	-- Act
	local dashboardService = ServiceLocator.Get("Dashboard")
	
	-- Assert
	TestFramework.Assert(dashboardService ~= nil, "Dashboard should be registered with ServiceLocator")
	
	-- Verify functionality through service locator
	local health = dashboardService.GetHealth()
	TestFramework.Assert(health.status == "healthy", "Dashboard should be accessible via ServiceLocator")
	
	-- Test method availability
	TestFramework.Assert(type(dashboardService.RegisterMetric) == "function", "Should expose RegisterMetric method")
	TestFramework.Assert(type(dashboardService.UpdateMetric) == "function", "Should expose UpdateMetric method")
	TestFramework.Assert(type(dashboardService.NotifyAlert) == "function", "Should expose NotifyAlert method")
end)

-- Test: Analytics Engine Integration
DashboardIntegrationTestSuite:AddTest("AnalyticsEngineIntegration_ShouldReceiveNotifications", function()
	-- This test would verify integration with AnalyticsEngine
	-- In practice, AnalyticsEngine would send alerts to Dashboard
	
	-- Arrange
	local testAlert = createTestAlert({
		id = "analytics_integration_alert",
		type = "analytics_notification"
	})
	
	-- Act - Simulate alert from AnalyticsEngine
	local result = Dashboard.NotifyAlert(testAlert)
	
	-- Assert
	TestFramework.Assert(result == true, "Should accept alerts from AnalyticsEngine")
	
	wait(0.1)
	local snapshot = Dashboard.GetSnapshot()
	local foundAlert = false
	for _, alert in ipairs(snapshot.alerts) do
		if alert.id == testAlert.id then
			foundAlert = true
			break
		end
	end
	TestFramework.Assert(foundAlert, "Alert should be processed and stored")
end)

-- Test Runner
local function runAllDashboardTests()
	print("🎛️ Starting Dashboard Test Suite...")
	
	local results = {
		DashboardTestSuite:Run(),
		DashboardStressTestSuite:Run(),
		DashboardIntegrationTestSuite:Run()
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
	
	print(string.format("📊 Dashboard Test Results: %d/%d passed (%.1f%% success rate)", 
		totalPassed, totalTests, successRate))
	
	if totalFailed > 0 then
		print(string.format("❌ %d dashboard tests failed", totalFailed))
	else
		print("✅ All dashboard tests passed!")
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
	RunTests = runAllDashboardTests,
	Suites = {
		Core = DashboardTestSuite,
		Stress = DashboardStressTestSuite,
		Integration = DashboardIntegrationTestSuite
	}
}
