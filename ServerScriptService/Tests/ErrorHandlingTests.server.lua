--!strict
--[[
	ErrorHandlingTests.server.lua
	Comprehensive Unit Tests for Enterprise Error Handling & Recovery System
	
	Tests all components of the error handling system including:
	- ErrorHandler functionality
	- Circuit breaker patterns
	- Recovery manager operations
	- Integration between components
	- Performance and reliability metrics
	
	Author: Enterprise Development Team
	Created: December 2024
]]--

local TestFramework = require(script.Parent.Parent.ReplicatedStorage.Shared.TestFramework)
local ErrorHandler = require(script.Parent.Parent.ReplicatedStorage.Shared.ErrorHandler)
local ServiceLocator = require(script.Parent.Parent.ReplicatedStorage.Shared.ServiceLocator)

-- Test Suite Configuration
local TEST_SUITE = "Error Handling & Recovery System"
local testResults = {
	passed = 0,
	failed = 0,
	total = 0,
	details = {}
}

-- Test Utilities
local function createMockService(name: string, shouldFail: boolean?): any
	return {
		name = name,
		shouldFail = shouldFail or false,
		callCount = 0,
		
		DoOperation = function(self)
			self.callCount = self.callCount + 1
			if self.shouldFail then
				error("Mock service failure: " .. name)
			end
			return "success"
		end,
		
		GetHealthStatus = function(self)
			return {
				status = self.shouldFail and "unhealthy" or "healthy",
				metrics = {
					callCount = self.callCount,
					errorRate = self.shouldFail and 1.0 or 0.0
				}
			}
		end
	}
end

local function simulateError(message: string, source: string?, context: any?): any
	return ErrorHandler:HandleError(message, source, context)
end

local function waitForCondition(condition: () -> boolean, timeout: number): boolean
	local startTime = tick()
	while tick() - startTime < timeout do
		if condition() then
			return true
		end
		task.wait(0.1)
	end
	return false
end

-- Test Functions

-- Test 1: ErrorHandler Initialization
local function testErrorHandlerInitialization(): boolean
	local success, result = pcall(function()
		local errorHandler = ErrorHandler.new()
		
		-- Verify error handler is created
		assert(errorHandler ~= nil, "ErrorHandler should be created")
		
		-- Verify health status
		local health = errorHandler:GetHealthStatus()
		assert(health.status == "healthy", "ErrorHandler should start healthy")
		assert(health.metrics ~= nil, "ErrorHandler should have metrics")
		
		return true
	end)
	
	return success and result
end

-- Test 2: Error Classification
local function testErrorClassification(): boolean
	local success, result = pcall(function()
		local errorHandler = ErrorHandler.new()
		
		-- Test network error classification
		local networkError = errorHandler:HandleError("Connection timeout", "NetworkService")
		assert(networkError.category == "Network", "Should classify as Network error")
		
		-- Test datastore error classification
		local datastoreError = errorHandler:HandleError("DataStore quota exceeded", "DataService")
		assert(datastoreError.category == "Data", "Should classify as Data error")
		
		-- Test security error classification
		local securityError = errorHandler:HandleError("Exploit detected", "SecurityService")
		assert(securityError.category == "Security", "Should classify as Security error")
		
		-- Test performance error classification
		local performanceError = errorHandler:HandleError("Memory limit exceeded", "PerformanceService")
		assert(performanceError.category == "Performance", "Should classify as Performance error")
		
		return true
	end)
	
	return success and result
end

-- Test 3: Error Severity Determination
local function testErrorSeverityDetermination(): boolean
	local success, result = pcall(function()
		local errorHandler = ErrorHandler.new()
		
		-- Test critical severity
		local criticalError = errorHandler:HandleError("Security exploit detected", "SecurityService")
		assert(criticalError.severity == "Critical", "Security exploits should be Critical")
		
		-- Test high severity
		local highError = errorHandler:HandleError("Network connection lost", "NetworkService")
		assert(highError.severity == "High", "Connection loss should be High")
		
		-- Test medium severity
		local mediumError = errorHandler:HandleError("Temporary retry needed", "DataService")
		assert(mediumError.severity == "Medium", "Retry errors should be Medium")
		
		-- Test low severity (default)
		local lowError = errorHandler:HandleError("Minor validation issue", "ValidationService")
		assert(lowError.severity == "Low", "Minor issues should be Low")
		
		return true
	end)
	
	return success and result
end

-- Test 4: Error Recovery Strategy Selection
local function testRecoveryStrategySelection(): boolean
	local success, result = pcall(function()
		local errorHandler = ErrorHandler.new()
		
		-- Test retry strategy for network errors
		local networkError = errorHandler:HandleError("Timeout", "NetworkService")
		assert(networkError.recoveryStrategy == "Retry", "Network errors should use Retry strategy")
		
		-- Test fallback strategy for data errors
		local dataError = errorHandler:HandleError("DataStore failed", "DataService")
		assert(dataError.recoveryStrategy == "Fallback", "Data errors should use Fallback strategy")
		
		-- Test degradation strategy for performance errors
		local perfError = errorHandler:HandleError("Performance degraded", "PerformanceService")
		assert(perfError.recoveryStrategy == "Degrade", "Performance errors should use Degrade strategy")
		
		return true
	end)
	
	return success and result
end

-- Test 5: Circuit Breaker Basic Functionality
local function testCircuitBreakerBasic(): boolean
	local success, result = pcall(function()
		local circuitBreaker = ServiceLocator:GetService("CircuitBreaker")
		assert(circuitBreaker ~= nil, "CircuitBreaker service should be available")
		
		-- Create test circuit breaker
		local testCB = circuitBreaker:CreateCircuitBreaker("TestService", {
			name = "TestService",
			failureThreshold = 3,
			successThreshold = 2,
			timeout = 1000, -- 1 second
			monitoringWindowSize = 10,
			slowCallDurationThreshold = 100,
			slowCallRateThreshold = 0.5,
			minimumNumberOfCalls = 3,
			enableMetrics = true,
			enableNotifications = false
		})
		
		-- Verify initial state
		assert(testCB:getState() == "Closed", "Circuit breaker should start Closed")
		
		-- Test successful execution
		local success1, result1 = testCB:execute(function()
			return "success"
		end)
		assert(success1 == true, "Successful operation should return true")
		assert(result1 == "success", "Should return operation result")
		
		return true
	end)
	
	return success and result
end

-- Test 6: Circuit Breaker State Transitions
local function testCircuitBreakerStateTransitions(): boolean
	local success, result = pcall(function()
		local circuitBreaker = ServiceLocator:GetService("CircuitBreaker")
		
		-- Create test circuit breaker with low threshold
		local testCB = circuitBreaker:CreateCircuitBreaker("FailureTestService", {
			name = "FailureTestService",
			failureThreshold = 2,
			successThreshold = 2,
			timeout = 100, -- 100ms for quick testing
			monitoringWindowSize = 10,
			slowCallDurationThreshold = 50,
			slowCallRateThreshold = 0.5,
			minimumNumberOfCalls = 2,
			enableMetrics = true,
			enableNotifications = false
		})
		
		-- Record failures to trigger state change
		testCB:recordFailure(10, "Test failure 1")
		testCB:recordFailure(10, "Test failure 2")
		testCB:recordFailure(10, "Test failure 3")
		
		-- Circuit breaker should transition to Open
		assert(testCB:getState() == "Open", "Circuit breaker should be Open after failures")
		
		-- Test that calls are rejected
		local success1, result1 = testCB:execute(function()
			return "should not execute"
		end)
		assert(success1 == false, "Calls should be rejected when Open")
		
		-- Wait for timeout to allow transition to HalfOpen
		task.wait(0.2) -- Wait longer than timeout
		
		-- Next call should allow transition to HalfOpen
		local canExecute = testCB:isCallAllowed()
		assert(canExecute == true, "Should allow calls after timeout")
		
		return true
	end)
	
	return success and result
end

-- Test 7: Recovery Manager Service Registration
local function testRecoveryManagerRegistration(): boolean
	local success, result = pcall(function()
		local recoveryManager = ServiceLocator:GetService("RecoveryManager")
		assert(recoveryManager ~= nil, "RecoveryManager service should be available")
		
		-- Create mock service
		local mockService = createMockService("TestMockService")
		
		-- Register service
		recoveryManager:RegisterService("TestMockService", mockService, {"DependencyService"})
		
		-- Verify service health
		local health = recoveryManager:GetServiceHealth("TestMockService")
		assert(health ~= nil, "Service health should be tracked")
		assert(health.serviceName == "TestMockService", "Service name should match")
		assert(health.status == "Healthy", "Service should start healthy")
		
		return true
	end)
	
	return success and result
end

-- Test 8: Recovery Manager Health Monitoring
local function testRecoveryManagerHealthMonitoring(): boolean
	local success, result = pcall(function()
		local recoveryManager = ServiceLocator:GetService("RecoveryManager")
		
		-- Create failing mock service
		local failingService = createMockService("FailingTestService", true)
		recoveryManager:RegisterService("FailingTestService", failingService)
		
		-- Force health check
		local health = recoveryManager:GetServiceHealth("FailingTestService")
		assert(health ~= nil, "Should have health record")
		
		-- Manually trigger health status change to test monitoring
		recoveryManager:ForceServiceHealth("FailingTestService", "Unhealthy")
		
		-- Verify status change
		local updatedHealth = recoveryManager:GetServiceHealth("FailingTestService")
		assert(updatedHealth.status == "Unhealthy", "Service status should be updated")
		
		return true
	end)
	
	return success and result
end

-- Test 9: Recovery Trigger and Execution
local function testRecoveryTriggerAndExecution(): boolean
	local success, result = pcall(function()
		local recoveryManager = ServiceLocator:GetService("RecoveryManager")
		
		-- Create test service
		local testService = createMockService("RecoveryTestService")
		recoveryManager:RegisterService("RecoveryTestService", testService)
		
		-- Trigger recovery
		local executionId = recoveryManager:TriggerRecovery("RecoveryTestService", "test", "Restart")
		assert(executionId ~= nil, "Should return execution ID")
		
		-- Check that recovery is active
		local activeRecoveries = recoveryManager:GetActiveRecoveries()
		assert(activeRecoveries[executionId] ~= nil, "Recovery should be active")
		
		-- Wait for recovery to complete
		local completed = waitForCondition(function()
			local recovery = activeRecoveries[executionId]
			return recovery and (recovery.status == "Success" or recovery.status == "Failed")
		end, 10)
		
		assert(completed == true, "Recovery should complete within timeout")
		
		return true
	end)
	
	return success and result
end

-- Test 10: Error Handler Integration with Circuit Breaker
local function testErrorHandlerCircuitBreakerIntegration(): boolean
	local success, result = pcall(function()
		local errorHandler = ErrorHandler.new()
		local circuitBreaker = ServiceLocator:GetService("CircuitBreaker")
		
		-- Create test circuit breaker
		local testCB = circuitBreaker:CreateCircuitBreaker("IntegrationTestService", {
			name = "IntegrationTestService",
			failureThreshold = 2,
			successThreshold = 1,
			timeout = 100,
			monitoringWindowSize = 5,
			slowCallDurationThreshold = 50,
			slowCallRateThreshold = 0.5,
			minimumNumberOfCalls = 2,
			enableMetrics = true,
			enableNotifications = false
		})
		
		-- Simulate errors that should trigger circuit breaker
		errorHandler:HandleError("Service failure 1", "IntegrationTestService")
		errorHandler:HandleError("Service failure 2", "IntegrationTestService")
		errorHandler:HandleError("Service failure 3", "IntegrationTestService")
		
		-- Check circuit breaker state
		local cbState = errorHandler:GetCircuitBreakerState("IntegrationTestService")
		assert(cbState == "Open" or cbState == "HalfOpen", "Circuit breaker should be triggered by errors")
		
		return true
	end)
	
	return success and result
end

-- Test 11: Error Handler Recovery Analytics
local function testErrorHandlerRecoveryAnalytics(): boolean
	local success, result = pcall(function()
		local errorHandler = ErrorHandler.new()
		
		-- Generate multiple errors
		for i = 1, 5 do
			errorHandler:HandleError("Test error " .. i, "AnalyticsTestService")
		end
		
		-- Get error history
		local errorHistory = errorHandler:GetErrorHistory()
		assert(#errorHistory >= 5, "Should have recorded errors in history")
		
		-- Verify error information
		local latestError = errorHistory[#errorHistory]
		assert(latestError.id ~= nil, "Error should have ID")
		assert(latestError.timestamp ~= nil, "Error should have timestamp")
		assert(latestError.source == "AnalyticsTestService", "Error should have correct source")
		
		return true
	end)
	
	return success and result
end

-- Test 12: Service Health Metrics
local function testServiceHealthMetrics(): boolean
	local success, result = pcall(function()
		local errorHandler = ErrorHandler.new()
		
		-- Simulate service health tracking
		local serviceName = "MetricsTestService"
		
		-- Generate errors to affect health metrics
		for i = 1, 3 do
			errorHandler:HandleError("Error " .. i, serviceName)
		end
		
		-- Get service health
		local serviceHealth = errorHandler:GetServiceHealth(serviceName)
		assert(serviceHealth ~= nil, "Should track service health")
		assert(serviceHealth.serviceName == serviceName, "Service name should match")
		assert(serviceHealth.errorRate > 0, "Error rate should be tracked")
		
		return true
	end)
	
	return success and result
end

-- Test 13: Recovery Performance Impact
local function testRecoveryPerformanceImpact(): boolean
	local success, result = pcall(function()
		local recoveryManager = ServiceLocator:GetService("RecoveryManager")
		
		-- Create performance test service
		local perfService = createMockService("PerformanceTestService")
		recoveryManager:RegisterService("PerformanceTestService", perfService)
		
		-- Measure recovery overhead
		local startTime = tick()
		local executionId = recoveryManager:TriggerRecovery("PerformanceTestService", "performance_test", "Restart")
		local triggerTime = tick() - startTime
		
		-- Recovery trigger should be fast
		assert(triggerTime < 0.1, "Recovery trigger should be fast (< 100ms)")
		
		-- Wait for completion
		local completed = waitForCondition(function()
			local activeRecoveries = recoveryManager:GetActiveRecoveries()
			local recovery = activeRecoveries[executionId]
			return recovery and (recovery.status == "Success" or recovery.status == "Failed")
		end, 5)
		
		assert(completed == true, "Recovery should complete efficiently")
		
		return true
	end)
	
	return success and result
end

-- Test 14: Error Handler Custom Recovery Actions
local function testCustomRecoveryActions(): boolean
	local success, result = pcall(function()
		local errorHandler = ErrorHandler.new()
		
		-- Register custom recovery action
		local customActionExecuted = false
		errorHandler:RegisterRecoveryAction({
			name = "customTestAction",
			strategy = "Repair",
			enabled = true,
			priority = 1,
			maxRetries = 1,
			backoffMultiplier = 1,
			timeout = 5,
			conditions = {category = "Logic"},
			action = function(errorInfo)
				customActionExecuted = true
				return true
			end
		})
		
		-- Trigger error that should use custom action
		errorHandler:HandleError("Logic error for custom action", "CustomActionTestService")
		
		-- Wait for custom action to execute
		local executed = waitForCondition(function()
			return customActionExecuted
		end, 5)
		
		assert(executed == true, "Custom recovery action should be executed")
		
		return true
	end)
	
	return success and result
end

-- Test 15: System Health and Recovery Rate
local function testSystemHealthAndRecoveryRate(): boolean
	local success, result = pcall(function()
		local errorHandler = ErrorHandler.new()
		local recoveryManager = ServiceLocator:GetService("RecoveryManager")
		
		-- Get initial health status
		local errorHandlerHealth = errorHandler:GetHealthStatus()
		local recoveryManagerHealth = recoveryManager:GetHealthStatus()
		
		-- Verify health status structure
		assert(errorHandlerHealth.status ~= nil, "ErrorHandler should report health status")
		assert(errorHandlerHealth.metrics ~= nil, "ErrorHandler should report metrics")
		
		assert(recoveryManagerHealth.status ~= nil, "RecoveryManager should report health status")
		assert(recoveryManagerHealth.metrics ~= nil, "RecoveryManager should report metrics")
		
		-- Verify recovery rate tracking
		assert(errorHandlerHealth.metrics.recoveryRate ~= nil, "Should track recovery rate")
		assert(recoveryManagerHealth.metrics.recoveryRate ~= nil, "Should track recovery rate")
		
		return true
	end)
	
	return success and result
end

-- Execute Tests
local function runTest(testName: string, testFunction: () -> boolean): ()
	testResults.total = testResults.total + 1
	
	local success, result = pcall(testFunction)
	
	if success and result then
		testResults.passed = testResults.passed + 1
		table.insert(testResults.details, {
			name = testName,
			status = "PASSED",
			message = "Test completed successfully"
		})
		print(string.format("✅ %s - PASSED", testName))
	else
		testResults.failed = testResults.failed + 1
		local errorMessage = success and "Test returned false" or tostring(result)
		table.insert(testResults.details, {
			name = testName,
			status = "FAILED",
			message = errorMessage
		})
		print(string.format("❌ %s - FAILED: %s", testName, errorMessage))
	end
end

-- Main Test Execution
local function runAllTests(): ()
	print(string.format("\n🧪 Starting %s Tests...\n", TEST_SUITE))
	
	-- Wait for services to initialize
	task.wait(3)
	
	-- Run all tests
	runTest("ErrorHandler Initialization", testErrorHandlerInitialization)
	runTest("Error Classification", testErrorClassification)
	runTest("Error Severity Determination", testErrorSeverityDetermination)
	runTest("Recovery Strategy Selection", testRecoveryStrategySelection)
	runTest("Circuit Breaker Basic Functionality", testCircuitBreakerBasic)
	runTest("Circuit Breaker State Transitions", testCircuitBreakerStateTransitions)
	runTest("Recovery Manager Service Registration", testRecoveryManagerRegistration)
	runTest("Recovery Manager Health Monitoring", testRecoveryManagerHealthMonitoring)
	runTest("Recovery Trigger and Execution", testRecoveryTriggerAndExecution)
	runTest("Error Handler Circuit Breaker Integration", testErrorHandlerCircuitBreakerIntegration)
	runTest("Error Handler Recovery Analytics", testErrorHandlerRecoveryAnalytics)
	runTest("Service Health Metrics", testServiceHealthMetrics)
	runTest("Recovery Performance Impact", testRecoveryPerformanceImpact)
	runTest("Custom Recovery Actions", testCustomRecoveryActions)
	runTest("System Health and Recovery Rate", testSystemHealthAndRecoveryRate)
	
	-- Print results summary
	print(string.format("\n📊 %s Test Results:", TEST_SUITE))
	print(string.format("✅ Passed: %d", testResults.passed))
	print(string.format("❌ Failed: %d", testResults.failed))
	print(string.format("📈 Total: %d", testResults.total))
	print(string.format("📊 Success Rate: %.1f%%", (testResults.passed / testResults.total) * 100))
	
	-- Register test results with TestFramework if available
	if TestFramework then
		TestFramework:RecordTestSuite(TEST_SUITE, testResults)
	end
	
	-- Record test completion
	local logger = ServiceLocator:GetService("Logging")
	if logger then
		logger.LogInfo("Error Handling & Recovery tests completed", {
			suite = TEST_SUITE,
			passed = testResults.passed,
			failed = testResults.failed,
			total = testResults.total,
			successRate = (testResults.passed / testResults.total) * 100
		})
	end
end

-- Initialize and run tests
task.spawn(function()
	-- Wait for all services to be ready
	task.wait(5)
	runAllTests()
end)

return {
	runTests = runAllTests,
	results = testResults
}
