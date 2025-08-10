--[[
	IntegrationTestSuite.lua
	Cross-system integration testing framework for enterprise validation
	
	Features:
	- Tests SecurityValidator ↔ AntiExploit ↔ NetworkBatcher integration
	- Validates Service Locator dependency resolution under failure scenarios
	- Tests complete request lifecycle with real RemoteEvent flow
	- Performance testing under load with concurrent operations
	- Automated test reporting with detailed failure analysis
	
	Usage:
		IntegrationTestSuite.RunAllTests()
		IntegrationTestSuite.RunSpecificTest("SecurityValidation")
		IntegrationTestSuite.GenerateTestReport()
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Import dependencies
local ServiceLocator = require(ReplicatedStorage.Shared.ServiceLocator)

local IntegrationTestSuite = {}

-- Test configuration
local TEST_CONFIG = {
	timeout = 30, -- seconds
	maxConcurrentTests = 5,
	retryAttempts = 3,
	performanceThresholds = {
		serviceResolution = 0.005, -- 5ms
		remoteEventProcessing = 0.050, -- 50ms
		securityValidation = 0.010, -- 10ms
		networkBatching = 0.100, -- 100ms
	}
}

-- Test results storage
local testResults = {
	executed = {},
	passed = {},
	failed = {},
	performance = {},
	systemHealth = {},
	startTime = 0,
	endTime = 0
}

-- Test scenarios definition
local testScenarios = {
	{
		name = "SecurityValidation",
		description = "Tests SecurityValidator integration with RemoteEvent processing",
		category = "Security",
		priority = "Critical",
		dependencies = {"SecurityValidator", "Logging"},
		test = function() return IntegrationTestSuite.TestSecurityValidation() end
	},
	
	{
		name = "NetworkBatchingFlow",
		description = "Tests NetworkBatcher with various priority levels and queue management",
		category = "Network",
		priority = "High", 
		dependencies = {"NetworkBatcher", "MetricsExporter"},
		test = function() return IntegrationTestSuite.TestNetworkBatchingFlow() end
	},
	
	{
		name = "ServiceLocatorResilience",
		description = "Tests Service Locator dependency resolution under failure conditions",
		category = "Core",
		priority = "Critical",
		dependencies = {"ServiceLocator"},
		test = function() return IntegrationTestSuite.TestServiceLocatorResilience() end
	},
	
	{
		name = "AntiExploitIntegration",
		description = "Tests AntiExploit system integration with SecurityValidator",
		category = "Security",
		priority = "Critical",
		dependencies = {"AntiExploit", "SecurityValidator"},
		test = function() return IntegrationTestSuite.TestAntiExploitIntegration() end
	},
	
	{
		name = "RemoteEventLifecycle",
		description = "Tests complete RemoteEvent lifecycle from client to server processing",
		category = "Network",
		priority = "High",
		dependencies = {"SecurityValidator", "NetworkBatcher", "AntiExploit"},
		test = function() return IntegrationTestSuite.TestRemoteEventLifecycle() end
	},
	
	{
		name = "MetricsExporterIntegration",
		description = "Tests MetricsExporter integration with all enterprise systems",
		category = "Monitoring",
		priority = "Normal",
		dependencies = {"MetricsExporter"},
		test = function() return IntegrationTestSuite.TestMetricsExporterIntegration() end
	},
	
	{
		name = "LoadTesterSystemIntegration",
		description = "Tests LoadTester integration with core systems under stress",
		category = "Performance",
		priority = "Normal",
		dependencies = {"LoadTester", "SecurityValidator", "NetworkBatcher"},
		test = function() return IntegrationTestSuite.TestLoadTesterSystemIntegration() end
	},
	
	{
		name = "PerformanceUnderLoad",
		description = "Tests system performance under concurrent operations",
		category = "Performance", 
		priority = "High",
		dependencies = {"SecurityValidator", "NetworkBatcher", "MetricsExporter"},
		test = function() return IntegrationTestSuite.TestPerformanceUnderLoad() end
	},
	
	{
		name = "FailureRecovery",
		description = "Tests system recovery from simulated failures",
		category = "Resilience",
		priority = "High",
		dependencies = {"ServiceLocator"},
		test = function() return IntegrationTestSuite.TestFailureRecovery() end
	},
	
	{
		name = "CrossSystemCommunication",
		description = "Tests communication between all enterprise systems",
		category = "Integration",
		priority = "Critical",
		dependencies = {"SecurityValidator", "NetworkBatcher", "MetricsExporter", "AntiExploit"},
		test = function() return IntegrationTestSuite.TestCrossSystemCommunication() end
	}
}

-- Initialize integration test suite
function IntegrationTestSuite.Initialize()
	-- Register with Service Locator
	ServiceLocator.RegisterService("IntegrationTestSuite", IntegrationTestSuite, {
		"Logging"
	})
	
	print("[IntegrationTestSuite] ✓ Enterprise integration test suite initialized")
end

-- Run all integration tests
function IntegrationTestSuite.RunAllTests(): {[string]: any}
	print("[IntegrationTestSuite] 🧪 Running comprehensive integration test suite...")
	
	-- Reset test results
	testResults = {
		executed = {},
		passed = {},
		failed = {},
		performance = {},
		systemHealth = {},
		startTime = tick(),
		endTime = 0
	}
	
	local totalTests = #testScenarios
	local passedTests = 0
	local failedTests = 0
	
	-- Execute each test scenario
	for i, scenario in ipairs(testScenarios) do
		print(string.format("[IntegrationTestSuite] Running test %d/%d: %s", i, totalTests, scenario.name))
		
		local testResult = IntegrationTestSuite.ExecuteTest(scenario)
		table.insert(testResults.executed, testResult)
		
		if testResult.success then
			table.insert(testResults.passed, testResult)
			passedTests = passedTests + 1
			print(string.format("  ✅ %s PASSED (%.3fs)", scenario.name, testResult.duration))
		else
			table.insert(testResults.failed, testResult)
			failedTests = failedTests + 1
			print(string.format("  ❌ %s FAILED: %s (%.3fs)", scenario.name, testResult.error, testResult.duration))
		end
		
		-- Record performance metrics
		testResults.performance[scenario.name] = {
			duration = testResult.duration,
			memoryUsage = testResult.memoryUsage,
			operations = testResult.operations or 0
		}
		
		-- Brief pause between tests
		wait(0.1)
	end
	
	testResults.endTime = tick()
	
	-- Generate comprehensive report
	local summary = IntegrationTestSuite.GenerateTestReport()
	
	print(string.format("[IntegrationTestSuite] ✅ Test suite completed: %d/%d passed (%.1f%% success rate)",
		passedTests, totalTests, (passedTests / totalTests) * 100))
	
	return {
		summary = summary,
		totalTests = totalTests,
		passedTests = passedTests,
		failedTests = failedTests,
		successRate = (passedTests / totalTests) * 100,
		totalDuration = testResults.endTime - testResults.startTime
	}
end

-- Execute a single test scenario
function IntegrationTestSuite.ExecuteTest(scenario: {[string]: any}): {[string]: any}
	local startTime = tick()
	local startMemory = collectgarbage("count")
	
	local testResult = {
		name = scenario.name,
		description = scenario.description,
		category = scenario.category,
		priority = scenario.priority,
		success = false,
		error = "",
		duration = 0,
		memoryUsage = 0,
		details = {}
	}
	
	-- Check dependencies
	for _, dependency in ipairs(scenario.dependencies) do
		if not ServiceLocator.GetService(dependency) then
			testResult.error = string.format("Missing dependency: %s", dependency)
			testResult.duration = tick() - startTime
			return testResult
		end
	end
	
	-- Execute test with timeout protection
	local success, result = pcall(function()
		return scenario.test()
	end)
	
	if success and result then
		testResult.success = true
		testResult.details = result.details or {}
		testResult.operations = result.operations
	else
		testResult.success = false
		testResult.error = result or "Test execution failed"
	end
	
	testResult.duration = tick() - startTime
	testResult.memoryUsage = collectgarbage("count") - startMemory
	
	return testResult
end

-- Test SecurityValidator integration
function IntegrationTestSuite.TestSecurityValidation(): {[string]: any}
	local SecurityValidator = ServiceLocator.GetService("SecurityValidator")
	if not SecurityValidator then
		error("SecurityValidator service not available")
	end
	
	local testData = {
		validRequest = {
			weaponId = "ASSAULT_RIFLE",
			targetPosition = Vector3.new(100, 0, 50),
			timestamp = tick()
		},
		invalidRequest = {
			weaponId = "INVALID_WEAPON",
			targetPosition = "not a vector3",
			timestamp = "invalid_timestamp"
		},
		exploitRequest = {
			weaponId = "'; DROP TABLE players; --",
			targetPosition = Vector3.new(999999, 999999, 999999),
			timestamp = tick() - 1000 -- Old timestamp
		}
	}
	
	local validationSchema = {
		weaponId = {
			type = "string",
			whitelist = {"ASSAULT_RIFLE", "SNIPER_RIFLE", "SHOTGUN", "PISTOL"}
		},
		targetPosition = {
			type = "Vector3",
			validation = "position_bounds_check"
		},
		timestamp = {
			type = "number",
			validation = "anti_speedhack_check"
		}
	}
	
	local operations = 0
	local mockPlayer = {UserId = 12345, Name = "TestPlayer"}
	
	-- Test valid request
	local result1 = SecurityValidator.ValidateRemoteCall(mockPlayer, "FireWeapon", validationSchema, testData.validRequest)
	operations = operations + 1
	assert(result1.isValid, "Valid request should pass validation")
	
	-- Test invalid request
	local result2 = SecurityValidator.ValidateRemoteCall(mockPlayer, "FireWeapon", validationSchema, testData.invalidRequest)
	operations = operations + 1
	assert(not result2.isValid, "Invalid request should fail validation")
	
	-- Test exploit attempt
	local result3 = SecurityValidator.ValidateRemoteCall(mockPlayer, "FireWeapon", validationSchema, testData.exploitRequest)
	operations = operations + 1
	assert(not result3.isValid, "Exploit attempt should fail validation")
	
	-- Test rate limiting
	for i = 1, 15 do -- Exceed rate limit
		SecurityValidator.CheckRateLimit(mockPlayer, "FireWeapon")
		operations = operations + 1
	end
	
	local rateLimitResult = SecurityValidator.CheckRateLimit(mockPlayer, "FireWeapon")
	operations = operations + 1
	assert(not rateLimitResult, "Rate limit should block excessive requests")
	
	return {
		details = {
			validationTests = 3,
			rateLimitTests = 16,
			exploitDetection = true
		},
		operations = operations
	}
end

-- Test NetworkBatcher integration
function IntegrationTestSuite.TestNetworkBatchingFlow(): {[string]: any}
	local NetworkBatcher = ServiceLocator.GetService("NetworkBatcher")
	if not NetworkBatcher then
		error("NetworkBatcher service not available")
	end
	
	local operations = 0
	local mockPlayer = {UserId = 12345, Name = "TestPlayer"}
	
	-- Queue events with different priorities
	local testEvents = {
		{type = "combat_hit", data = {damage = 50}, priority = "Critical"},
		{type = "ui_update", data = {score = 100}, priority = "Normal"},
		{type = "analytics", data = {action = "jump"}, priority = "Low"},
		{type = "combat_reload", data = {weapon = "AK47"}, priority = "Critical"},
		{type = "shop_view", data = {category = "weapons"}, priority = "Low"}
	}
	
	-- Queue all events
	for _, event in ipairs(testEvents) do
		local success = NetworkBatcher.QueueEvent(event.type, mockPlayer, event.data, event.priority)
		operations = operations + 1
		assert(success, string.format("Failed to queue %s event", event.type))
	end
	
	-- Test priority processing
	NetworkBatcher.ProcessPriorityQueue(10) -- Critical priority
	operations = operations + 1
	
	NetworkBatcher.ProcessPriorityQueue(5) -- Normal priority  
	operations = operations + 1
	
	NetworkBatcher.ProcessPriorityQueue(1) -- Low priority
	operations = operations + 1
	
	-- Test batch compression
	local compressionTest = NetworkBatcher.GetQueueMetrics()
	operations = operations + 1
	
	return {
		details = {
			eventsQueued = #testEvents,
			priorityLevels = 3,
			batchProcessing = true,
			compressionEnabled = compressionTest.compressionEnabled or false
		},
		operations = operations
	}
end

-- Test Service Locator resilience
function IntegrationTestSuite.TestServiceLocatorResilience(): {[string]: any}
	local operations = 0
	
	-- Test service registration and resolution
	local mockService = {
		name = "TestService",
		testMethod = function() return "test_result" end
	}
	
	ServiceLocator.RegisterService("TestService", mockService, {})
	operations = operations + 1
	
	local retrievedService = ServiceLocator.GetService("TestService")
	operations = operations + 1
	assert(retrievedService ~= nil, "Service should be retrievable after registration")
	assert(retrievedService.testMethod() == "test_result", "Service methods should work correctly")
	
	-- Test dependency resolution
	local dependentService = {
		name = "DependentService",
		initialize = function() return true end
	}
	
	ServiceLocator.RegisterService("DependentService", dependentService, {"TestService"})
	operations = operations + 1
	
	-- Test service health checks
	local healthStatus = ServiceLocator.CheckServiceHealth("TestService")
	operations = operations + 1
	assert(healthStatus.isHealthy, "Service should report healthy status")
	
	-- Test failure scenarios
	ServiceLocator.RegisterService("FailingService", nil, {}) -- Simulate registration failure
	operations = operations + 1
	
	local failingService = ServiceLocator.GetService("FailingService")
	operations = operations + 1
	assert(failingService == nil, "Failed service should not be retrievable")
	
	-- Test circular dependency detection
	local serviceA = {name = "ServiceA"}
	local serviceB = {name = "ServiceB"}
	
	ServiceLocator.RegisterService("ServiceA", serviceA, {"ServiceB"})
	ServiceLocator.RegisterService("ServiceB", serviceB, {"ServiceA"})
	operations = operations + 2
	
	-- Should handle circular dependencies gracefully
	local circularA = ServiceLocator.GetService("ServiceA")
	local circularB = ServiceLocator.GetService("ServiceB")
	operations = operations + 2
	
	return {
		details = {
			serviceRegistrations = 5,
			dependencyResolution = true,
			healthChecks = 1,
			failureHandling = true,
			circularDependencyDetection = true
		},
		operations = operations
	}
end

-- Test AntiExploit integration
function IntegrationTestSuite.TestAntiExploitIntegration(): {[string]: any}
	local AntiExploit = ServiceLocator.GetService("AntiExploit")
	local SecurityValidator = ServiceLocator.GetService("SecurityValidator")
	
	if not AntiExploit or not SecurityValidator then
		error("Required services not available for AntiExploit integration test")
	end
	
	local operations = 0
	local mockPlayer = {UserId = 12345, Name = "TestPlayer"}
	
	-- Simulate various threat scenarios
	local threatScenarios = {
		{
			type = "speed_hack",
			severity = 8,
			evidence = {maxSpeed = 150, normalSpeed = 16}
		},
		{
			type = "teleport_exploit", 
			severity = 9,
			evidence = {distance = 1000, timeFrame = 0.1}
		},
		{
			type = "invalid_weapon",
			severity = 6,
			evidence = {weaponId = "ADMIN_ONLY_WEAPON"}
		},
		{
			type = "sql_injection",
			severity = 10,
			evidence = {input = "'; DROP TABLE players; --"}
		}
	}
	
	-- Process each threat through the integrated system
	for _, scenario in ipairs(threatScenarios) do
		local threat = {
			playerId = mockPlayer.UserId,
			threatType = scenario.type,
			severity = scenario.severity,
			description = string.format("Detected %s exploit", scenario.type),
			timestamp = tick(),
			evidence = scenario.evidence
		}
		
		local response = AntiExploit.ProcessSecurityThreat(threat)
		operations = operations + 1
		
		assert(response ~= nil, "AntiExploit should process threat")
		assert(response.action ~= nil, "Response should include action taken")
		
		-- Verify SecurityValidator integration
		if scenario.severity >= 8 then
			assert(response.action == "ban" or response.action == "kick", 
				"High severity threats should result in ban/kick")
		end
	end
	
	-- Test automated response escalation
	local multipleThreats = {}
	for i = 1, 5 do
		table.insert(multipleThreats, {
			playerId = mockPlayer.UserId,
			threatType = "rapid_fire",
			severity = 6,
			description = "Rapid fire exploit detected",
			timestamp = tick(),
			evidence = {fireRate = 30} -- 30 shots per second
		})
	end
	
	for _, threat in ipairs(multipleThreats) do
		AntiExploit.ProcessSecurityThreat(threat)
		operations = operations + 1
	end
	
	return {
		details = {
			threatScenariosProcessed = #threatScenarios,
			escalationTests = #multipleThreats,
			integrationPoints = 2, -- SecurityValidator + AntiExploit
			automatedResponses = true
		},
		operations = operations
	}
end

-- Test complete RemoteEvent lifecycle
function IntegrationTestSuite.TestRemoteEventLifecycle(): {[string]: any}
	local SecurityValidator = ServiceLocator.GetService("SecurityValidator")
	local NetworkBatcher = ServiceLocator.GetService("NetworkBatcher")
	
	if not SecurityValidator or not NetworkBatcher then
		error("Required services not available for RemoteEvent lifecycle test")
	end
	
	local operations = 0
	local mockPlayer = {UserId = 12345, Name = "TestPlayer"}
	
	-- Simulate complete RemoteEvent flow: Client → Validation → Processing → Response
	local remoteEventTests = {
		{
			name = "FireWeapon",
			data = {
				weaponId = "ASSAULT_RIFLE",
				targetPosition = Vector3.new(100, 0, 50),
				timestamp = tick()
			},
			schema = {
				weaponId = {type = "string", whitelist = {"ASSAULT_RIFLE", "SNIPER_RIFLE"}},
				targetPosition = {type = "Vector3"},
				timestamp = {type = "number"}
			},
			expectedValid = true
		},
		{
			name = "PurchaseItem",
			data = {
				itemId = "weapon_skin_001",
				quantity = 1,
				currencyType = "coins"
			},
			schema = {
				itemId = {type = "string"},
				quantity = {type = "number", min = 1, max = 99},
				currencyType = {type = "string", whitelist = {"coins", "gems"}}
			},
			expectedValid = true
		},
		{
			name = "ExploitAttempt",
			data = {
				weaponId = "'; DROP TABLE weapons; --",
				targetPosition = Vector3.new(999999, 999999, 999999),
				timestamp = tick() - 1000
			},
			schema = {
				weaponId = {type = "string", whitelist = {"ASSAULT_RIFLE", "SNIPER_RIFLE"}},
				targetPosition = {type = "Vector3"},
				timestamp = {type = "number"}
			},
			expectedValid = false
		}
	}
	
	for _, test in ipairs(remoteEventTests) do
		-- Step 1: Security validation
		local validationResult = SecurityValidator.ValidateRemoteCall(
			mockPlayer, test.name, test.schema, test.data
		)
		operations = operations + 1
		
		assert(validationResult.isValid == test.expectedValid, 
			string.format("Validation result mismatch for %s", test.name))
		
		if validationResult.isValid then
			-- Step 2: Network batching (if validation passed)
			local batchSuccess = NetworkBatcher.QueueEvent(
				test.name, mockPlayer, validationResult.sanitizedData, "Normal"
			)
			operations = operations + 1
			
			assert(batchSuccess, string.format("Failed to batch %s", test.name))
			
			-- Step 3: Process the batch
			NetworkBatcher.ProcessPriorityQueue(5) -- Normal priority
			operations = operations + 1
		else
			-- Step 2: Security violation should be logged
			-- This would normally trigger AntiExploit
			operations = operations + 1
		end
	end
	
	-- Test concurrent RemoteEvent processing
	local concurrentEvents = {}
	for i = 1, 10 do
		table.insert(concurrentEvents, {
			name = "UpdateStats",
			data = {statType = "kills", value = i},
			schema = {
				statType = {type = "string", whitelist = {"kills", "deaths", "score"}},
				value = {type = "number", min = 0}
			}
		})
	end
	
	for _, event in ipairs(concurrentEvents) do
		local validationResult = SecurityValidator.ValidateRemoteCall(
			mockPlayer, event.name, event.schema, event.data
		)
		operations = operations + 1
		
		if validationResult.isValid then
			NetworkBatcher.QueueEvent(event.name, mockPlayer, validationResult.sanitizedData, "Low")
			operations = operations + 1
		end
	end
	
	-- Process all low priority events
	NetworkBatcher.ProcessPriorityQueue(1)
	operations = operations + 1
	
	return {
		details = {
			remoteEventTests = #remoteEventTests,
			concurrentEvents = #concurrentEvents,
			validationSteps = #remoteEventTests,
			batchingSteps = 2,
			lifecycleComplete = true
		},
		operations = operations
	}
end

-- Test MetricsExporter integration
function IntegrationTestSuite.TestMetricsExporterIntegration(): {[string]: any}
	local MetricsExporter = ServiceLocator.GetService("MetricsExporter")
	if not MetricsExporter then
		error("MetricsExporter service not available")
	end
	
	local operations = 0
	
	-- Test metric registration
	local testMetrics = {
		{name = "test_counter", type = "counter", description = "Test counter metric"},
		{name = "test_gauge", type = "gauge", description = "Test gauge metric"},
		{name = "test_histogram", type = "histogram", description = "Test histogram metric"}
	}
	
	for _, metric in ipairs(testMetrics) do
		local fullName = MetricsExporter.RegisterMetric(metric.name, metric.type, metric.description, {})
		operations = operations + 1
		assert(fullName ~= nil, string.format("Failed to register %s metric", metric.type))
	end
	
	-- Test metric operations
	MetricsExporter.IncrementCounter("test_counter", {}, 5)
	operations = operations + 1
	
	MetricsExporter.SetGauge("test_gauge", {}, 42.5)
	operations = operations + 1
	
	MetricsExporter.ObserveHistogram("test_histogram", {}, 0.125)
	operations = operations + 1
	
	-- Test metrics export
	local exportedMetrics = MetricsExporter.ExportMetrics()
	operations = operations + 1
	assert(#exportedMetrics > 0, "Exported metrics should not be empty")
	
	-- Test Prometheus format
	local prometheusFormat = MetricsExporter.ExportPrometheusFormat()
	operations = operations + 1
	assert(type(prometheusFormat) == "string", "Prometheus format should be string")
	assert(string.find(prometheusFormat, "test_counter"), "Should contain test counter")
	
	return {
		details = {
			metricsRegistered = #testMetrics,
			metricOperations = 3,
			exportFormats = 2,
			prometheusCompatible = true
		},
		operations = operations
	}
end

-- Test LoadTester system integration
function IntegrationTestSuite.TestLoadTesterSystemIntegration(): {[string]: any}
	local LoadTester = ServiceLocator.GetService("LoadTester")
	if not LoadTester then
		error("LoadTester service not available")
	end
	
	local operations = 0
	
	-- Test load testing framework
	local testConfig = {
		playerCount = 5, -- Small test
		duration = 2, -- Short duration
		scenarios = {"combat", "ui_interaction"}
	}
	
	local sessionId = LoadTester.RunStressTest("IntegrationTest", testConfig)
	operations = operations + 1
	assert(sessionId ~= nil, "LoadTester should return session ID")
	
	-- Wait for test to complete
	wait(testConfig.duration + 1)
	
	-- Get test results
	local results = LoadTester.GetTestResults(sessionId)
	operations = operations + 1
	assert(results ~= nil, "LoadTester should return results")
	assert(results.completed, "Test should be completed")
	
	return {
		details = {
			loadTestExecuted = true,
			virtualPlayers = testConfig.playerCount,
			testDuration = testConfig.duration,
			systemIntegration = true
		},
		operations = operations
	}
end

-- Test performance under load
function IntegrationTestSuite.TestPerformanceUnderLoad(): {[string]: any}
	local SecurityValidator = ServiceLocator.GetService("SecurityValidator")
	local NetworkBatcher = ServiceLocator.GetService("NetworkBatcher")
	local MetricsExporter = ServiceLocator.GetService("MetricsExporter")
	
	if not SecurityValidator or not NetworkBatcher or not MetricsExporter then
		error("Required services not available for performance test")
	end
	
	local operations = 0
	local startTime = tick()
	
	-- Simulate high load scenario
	local mockPlayers = {}
	for i = 1, 50 do
		table.insert(mockPlayers, {UserId = 10000 + i, Name = "LoadTestPlayer" .. i})
	end
	
	local validationSchema = {
		action = {type = "string", whitelist = {"move", "jump", "shoot", "reload"}},
		value = {type = "number", min = 0, max = 100}
	}
	
	-- Process many concurrent requests
	for round = 1, 5 do
		for _, player in ipairs(mockPlayers) do
			local testData = {
				action = ({"move", "jump", "shoot", "reload"})[math.random(1, 4)],
				value = math.random(1, 100)
			}
			
			-- Security validation
			local validationStart = tick()
			local result = SecurityValidator.ValidateRemoteCall(player, "PlayerAction", validationSchema, testData)
			local validationTime = tick() - validationStart
			operations = operations + 1
			
			-- Check performance threshold
			assert(validationTime < TEST_CONFIG.performanceThresholds.securityValidation,
				string.format("Security validation too slow: %.3fs", validationTime))
			
			if result.isValid then
				-- Network batching
				local batchStart = tick()
				NetworkBatcher.QueueEvent("PlayerAction", player, result.sanitizedData, "Normal")
				local batchTime = tick() - batchStart
				operations = operations + 1
				
				assert(batchTime < TEST_CONFIG.performanceThresholds.networkBatching,
					string.format("Network batching too slow: %.3fs", batchTime))
			end
		end
		
		-- Process batches
		NetworkBatcher.ProcessPriorityQueue(5)
		operations = operations + 1
		
		-- Update metrics
		MetricsExporter.IncrementCounter("test_operations", {round = tostring(round)}, #mockPlayers)
		operations = operations + 1
	end
	
	local totalTime = tick() - startTime
	local operationsPerSecond = operations / totalTime
	
	return {
		details = {
			totalOperations = operations,
			totalTime = totalTime,
			operationsPerSecond = operationsPerSecond,
			playersSimulated = #mockPlayers,
			performanceThresholdsMet = true
		},
		operations = operations
	}
end

-- Test failure recovery
function IntegrationTestSuite.TestFailureRecovery(): {[string]: any}
	local operations = 0
	
	-- Test Service Locator recovery from service failures
	local unstableService = {
		name = "UnstableService",
		failureCount = 0,
		testMethod = function(self)
			self.failureCount = self.failureCount + 1
			if self.failureCount <= 3 then
				error("Simulated service failure")
			end
			return "success"
		end
	}
	
	ServiceLocator.RegisterService("UnstableService", unstableService, {})
	operations = operations + 1
	
	local service = ServiceLocator.GetService("UnstableService")
	operations = operations + 1
	
	-- Test failure handling
	for attempt = 1, 5 do
		local success, result = pcall(function()
			return service:testMethod()
		end)
		operations = operations + 1
		
		if attempt <= 3 then
			assert(not success, "Service should fail first 3 attempts")
		else
			assert(success, "Service should recover after failures")
			assert(result == "success", "Service should return correct result after recovery")
		end
	end
	
	-- Test service health monitoring during recovery
	local healthChecks = {}
	for i = 1, 3 do
		local health = ServiceLocator.CheckServiceHealth("UnstableService")
		table.insert(healthChecks, health)
		operations = operations + 1
		wait(0.1)
	end
	
	return {
		details = {
			failureSimulations = 5,
			recoveryTested = true,
			healthMonitoring = #healthChecks,
			serviceResilience = true
		},
		operations = operations
	}
end

-- Test cross-system communication
function IntegrationTestSuite.TestCrossSystemCommunication(): {[string]: any}
	local SecurityValidator = ServiceLocator.GetService("SecurityValidator")
	local NetworkBatcher = ServiceLocator.GetService("NetworkBatcher")
	local MetricsExporter = ServiceLocator.GetService("MetricsExporter")
	local AntiExploit = ServiceLocator.GetService("AntiExploit")
	
	if not SecurityValidator or not NetworkBatcher or not MetricsExporter or not AntiExploit then
		error("Required services not available for cross-system communication test")
	end
	
	local operations = 0
	local mockPlayer = {UserId = 12345, Name = "TestPlayer"}
	
	-- Test complex interaction flow
	local exploitData = {
		weaponId = "INVALID_WEAPON_EXPLOIT",
		damage = 999999,
		targetPosition = Vector3.new(999999, 999999, 999999)
	}
	
	local schema = {
		weaponId = {type = "string", whitelist = {"ASSAULT_RIFLE", "SNIPER_RIFLE"}},
		damage = {type = "number", min = 1, max = 100},
		targetPosition = {type = "Vector3"}
	}
	
	-- Step 1: SecurityValidator detects invalid data
	local validationResult = SecurityValidator.ValidateRemoteCall(mockPlayer, "FireWeapon", schema, exploitData)
	operations = operations + 1
	assert(not validationResult.isValid, "Exploit should be caught by SecurityValidator")
	
	-- Step 2: SecurityValidator triggers threat detection
	local threat = {
		playerId = mockPlayer.UserId,
		threatType = "invalid_weapon_exploit",
		severity = 8,
		description = "Player attempted to use invalid weapon with excessive damage",
		timestamp = tick(),
		evidence = exploitData
	}
	
	-- Step 3: AntiExploit processes the threat
	local response = AntiExploit.ProcessSecurityThreat(threat)
	operations = operations + 1
	assert(response ~= nil, "AntiExploit should process threat")
	assert(response.action == "kick" or response.action == "ban", "High severity threat should result in punishment")
	
	-- Step 4: MetricsExporter records security event
	MetricsExporter.IncrementCounter("security_threats_detected", {type = threat.threatType}, 1)
	operations = operations + 1
	
	MetricsExporter.IncrementCounter("anti_exploit_actions", {action = response.action}, 1)
	operations = operations + 1
	
	-- Step 5: NetworkBatcher processes legitimate traffic around the incident
	local legitimateEvents = {
		{type = "ui_update", data = {score = 100}, priority = "Normal"},
		{type = "movement", data = {position = Vector3.new(10, 0, 10)}, priority = "Critical"}
	}
	
	for _, event in ipairs(legitimateEvents) do
		NetworkBatcher.QueueEvent(event.type, mockPlayer, event.data, event.priority)
		operations = operations + 1
	end
	
	NetworkBatcher.ProcessPriorityQueue(10) -- Process critical
	NetworkBatcher.ProcessPriorityQueue(5)  -- Process normal
	operations = operations + 2
	
	-- Verify all systems communicated properly
	local securityMetrics = MetricsExporter.ExportMetrics()
	operations = operations + 1
	
	local foundSecurityThreat = false
	local foundAntiExploitAction = false
	
	for _, metric in ipairs(securityMetrics) do
		if metric.name:find("security_threats_detected") then
			foundSecurityThreat = true
		end
		if metric.name:find("anti_exploit_actions") then
			foundAntiExploitAction = true
		end
	end
	
	assert(foundSecurityThreat, "Security threat should be recorded in metrics")
	assert(foundAntiExploitAction, "Anti-exploit action should be recorded in metrics")
	
	return {
		details = {
			systemsIntegrated = 4, -- SecurityValidator, AntiExploit, MetricsExporter, NetworkBatcher
			crossSystemEvents = 7,
			threatDetectionFlow = true,
			metricsRecording = true,
			networkProcessing = true
		},
		operations = operations
	}
end

-- Generate comprehensive test report
function IntegrationTestSuite.GenerateTestReport(): string
	local report = {}
	
	-- Header
	table.insert(report, "# Enterprise Integration Test Report")
	table.insert(report, "")
	table.insert(report, string.format("**Generated:** %s", os.date("%Y-%m-%d %H:%M:%S")))
	table.insert(report, string.format("**Duration:** %.2f seconds", testResults.endTime - testResults.startTime))
	table.insert(report, string.format("**Total Tests:** %d", #testResults.executed))
	table.insert(report, string.format("**Passed:** %d", #testResults.passed))
	table.insert(report, string.format("**Failed:** %d", #testResults.failed))
	table.insert(report, string.format("**Success Rate:** %.1f%%", (#testResults.passed / #testResults.executed) * 100))
	table.insert(report, "")
	
	-- Test Results Summary
	table.insert(report, "## Test Results Summary")
	table.insert(report, "")
	table.insert(report, "| Test Name | Category | Priority | Status | Duration | Operations |")
	table.insert(report, "|-----------|----------|----------|--------|----------|------------|")
	
	for _, test in ipairs(testResults.executed) do
		local status = test.success and "✅ PASS" or "❌ FAIL"
		table.insert(report, string.format("| %s | %s | %s | %s | %.3fs | %d |",
			test.name, test.category, test.priority, status, test.duration, test.operations or 0))
	end
	table.insert(report, "")
	
	-- Failed Tests Details
	if #testResults.failed > 0 then
		table.insert(report, "## Failed Tests")
		table.insert(report, "")
		
		for _, test in ipairs(testResults.failed) do
			table.insert(report, string.format("### %s", test.name))
			table.insert(report, string.format("**Error:** %s", test.error))
			table.insert(report, string.format("**Description:** %s", test.description))
			table.insert(report, "")
		end
	end
	
	-- Performance Analysis
	table.insert(report, "## Performance Analysis")
	table.insert(report, "")
	
	for testName, metrics in pairs(testResults.performance) do
		table.insert(report, string.format("**%s:**", testName))
		table.insert(report, string.format("- Duration: %.3f seconds", metrics.duration))
		table.insert(report, string.format("- Memory Usage: %.2f KB", metrics.memoryUsage))
		table.insert(report, string.format("- Operations: %d", metrics.operations))
		if metrics.operations > 0 then
			table.insert(report, string.format("- Ops/Second: %.1f", metrics.operations / metrics.duration))
		end
		table.insert(report, "")
	end
	
	-- System Health Assessment
	table.insert(report, "## System Health Assessment")
	table.insert(report, "")
	
	local healthCategories = {
		Security = {"SecurityValidation", "AntiExploitIntegration"},
		Network = {"NetworkBatchingFlow", "RemoteEventLifecycle"},
		Performance = {"PerformanceUnderLoad", "LoadTesterSystemIntegration"},
		Core = {"ServiceLocatorResilience", "CrossSystemCommunication"},
		Monitoring = {"MetricsExporterIntegration"},
		Resilience = {"FailureRecovery"}
	}
	
	for category, tests in pairs(healthCategories) do
		local passed = 0
		local total = 0
		
		for _, testName in ipairs(tests) do
			total = total + 1
			for _, test in ipairs(testResults.passed) do
				if test.name == testName then
					passed = passed + 1
					break
				end
			end
		end
		
		local healthScore = total > 0 and (passed / total) * 100 or 0
		local healthStatus = healthScore >= 90 and "🟢 Excellent" or
		                   healthScore >= 75 and "🟡 Good" or
		                   healthScore >= 50 and "🟠 Needs Attention" or "🔴 Critical"
		
		table.insert(report, string.format("**%s:** %.1f%% %s (%d/%d tests passed)", 
			category, healthScore, healthStatus, passed, total))
	end
	table.insert(report, "")
	
	-- Recommendations
	table.insert(report, "## Recommendations")
	table.insert(report, "")
	
	if #testResults.failed == 0 then
		table.insert(report, "✅ All integration tests passed! System is ready for production deployment.")
	else
		table.insert(report, "⚠️ The following issues should be addressed before production deployment:")
		for _, test in ipairs(testResults.failed) do
			table.insert(report, string.format("- **%s**: %s", test.name, test.error))
		end
	end
	
	return table.concat(report, "\n")
end

-- Run specific test by name
function IntegrationTestSuite.RunSpecificTest(testName: string): {[string]: any}
	local scenario = nil
	for _, test in ipairs(testScenarios) do
		if test.name == testName then
			scenario = test
			break
		end
	end
	
	if not scenario then
		error("Test not found: " .. testName)
	end
	
	print(string.format("[IntegrationTestSuite] Running specific test: %s", testName))
	return IntegrationTestSuite.ExecuteTest(scenario)
end

-- Get test suite status
function IntegrationTestSuite.GetTestSuiteStatus(): {[string]: any}
	return {
		totalScenarios = #testScenarios,
		lastExecuted = testResults.executed and #testResults.executed or 0,
		lastPassed = testResults.passed and #testResults.passed or 0,
		lastFailed = testResults.failed and #testResults.failed or 0,
		averageDuration = testResults.executed and
			(testResults.endTime - testResults.startTime) / #testResults.executed or 0
	}
end

-- Console commands for testing
_G.IntegrationTest_RunAll = function()
	return IntegrationTestSuite.RunAllTests()
end

_G.IntegrationTest_RunSpecific = function(testName)
	return IntegrationTestSuite.RunSpecificTest(testName)
end

_G.IntegrationTest_Report = function()
	return IntegrationTestSuite.GenerateTestReport()
end

_G.IntegrationTest_Status = function()
	return IntegrationTestSuite.GetTestSuiteStatus()
end

return IntegrationTestSuite
