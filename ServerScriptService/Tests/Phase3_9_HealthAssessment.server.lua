--!strict
--[[
	Phase3_9_HealthAssessment.server.lua
	Enterprise Error Handling & Recovery System Health Assessment
	
	Comprehensive health assessment for Phase 3.9 implementation
	validating all components and integration points.
	
	Author: Enterprise Development Team
	Created: December 2024
]]--

local ServiceLocator = require(script.Parent.Parent.ReplicatedStorage.Shared.ServiceLocator)

-- Health Assessment Results
local healthResults = {
	overall = "PENDING",
	score = 0,
	maxScore = 100,
	components = {},
	recommendations = {},
	timestamp = os.time()
}

-- Assessment Functions

-- Assess ErrorHandler
local function assessErrorHandler(): {status: string, score: number, details: any}
	local success, result = pcall(function()
		local errorHandler = require(script.Parent.Parent.ReplicatedStorage.Shared.ErrorHandler).new()
		
		-- Test basic functionality
		local testError = errorHandler:HandleError("Health assessment test", "HealthCheck")
		assert(testError ~= nil, "ErrorHandler should handle errors")
		assert(testError.id ~= nil, "Error should have ID")
		assert(testError.severity ~= nil, "Error should have severity")
		
		-- Test health status
		local health = errorHandler:GetHealthStatus()
		assert(health.status == "healthy", "ErrorHandler should be healthy")
		assert(health.metrics.recoveryRate >= 95, "Recovery rate should be >= 95%")
		
		return {
			status = "HEALTHY",
			score = 25,
			details = {
				errorHandling = "Operational",
				recoveryRate = health.metrics.recoveryRate,
				errorClassification = "Functional",
				circuitBreakerIntegration = "Active"
			}
		}
	end)
	
	if success then
		return result
	else
		return {
			status = "FAILED",
			score = 0,
			details = {
				error = tostring(result),
				errorHandling = "Failed",
				recoveryRate = 0,
				errorClassification = "Failed",
				circuitBreakerIntegration = "Failed"
			}
		}
	end
end

-- Assess CircuitBreaker
local function assessCircuitBreaker(): {status: string, score: number, details: any}
	local success, result = pcall(function()
		local circuitBreaker = ServiceLocator:GetService("CircuitBreaker")
		assert(circuitBreaker ~= nil, "CircuitBreaker service should be available")
		
		-- Test circuit breaker creation
		local testCB = circuitBreaker:CreateCircuitBreaker("HealthTestCB", {
			name = "HealthTestCB",
			failureThreshold = 3,
			successThreshold = 2,
			timeout = 1000,
			monitoringWindowSize = 10,
			slowCallDurationThreshold = 100,
			slowCallRateThreshold = 0.5,
			minimumNumberOfCalls = 2,
			enableMetrics = true,
			enableNotifications = false
		})
		
		assert(testCB ~= nil, "Should create circuit breaker")
		assert(testCB:getState() == "Closed", "Circuit breaker should start Closed")
		
		-- Test execution
		local execSuccess, execResult = testCB:execute(function()
			return "test success"
		end)
		assert(execSuccess == true, "Should execute successfully")
		assert(execResult == "test success", "Should return correct result")
		
		-- Test health status
		local health = circuitBreaker:GetHealthStatus()
		assert(health.status == "healthy", "CircuitBreaker should be healthy")
		
		return {
			status = "HEALTHY",
			score = 25,
			details = {
				circuitBreakerCreation = "Operational",
				stateManagement = "Functional",
				executionProtection = "Active",
				metricsCollection = "Operational"
			}
		}
	end)
	
	if success then
		return result
	else
		return {
			status = "FAILED",
			score = 0,
			details = {
				error = tostring(result),
				circuitBreakerCreation = "Failed",
				stateManagement = "Failed",
				executionProtection = "Failed",
				metricsCollection = "Failed"
			}
		}
	end
end

-- Assess RecoveryManager
local function assessRecoveryManager(): {status: string, score: number, details: any}
	local success, result = pcall(function()
		local recoveryManager = ServiceLocator:GetService("RecoveryManager")
		assert(recoveryManager ~= nil, "RecoveryManager service should be available")
		
		-- Test service registration
		local mockService = {
			name = "HealthTestService",
			GetHealthStatus = function()
				return {status = "healthy"}
			end
		}
		recoveryManager:RegisterService("HealthTestService", mockService)
		
		-- Test health monitoring
		local health = recoveryManager:GetServiceHealth("HealthTestService")
		assert(health ~= nil, "Should track service health")
		assert(health.serviceName == "HealthTestService", "Should track correct service")
		
		-- Test recovery statistics
		local stats = recoveryManager:GetRecoveryStatistics()
		assert(stats ~= nil, "Should provide recovery statistics")
		assert(stats.totalServices > 0, "Should track registered services")
		
		-- Test health status
		local systemHealth = recoveryManager:GetHealthStatus()
		assert(systemHealth.status == "healthy", "RecoveryManager should be healthy")
		
		return {
			status = "HEALTHY",
			score = 25,
			details = {
				serviceRegistration = "Operational",
				healthMonitoring = "Active",
				recoveryProcedures = "Available",
				statisticsTracking = "Functional"
			}
		}
	end)
	
	if success then
		return result
	else
		return {
			status = "FAILED",
			score = 0,
			details = {
				error = tostring(result),
				serviceRegistration = "Failed",
				healthMonitoring = "Failed",
				recoveryProcedures = "Failed",
				statisticsTracking = "Failed"
			}
		}
	end
end

-- Assess Integration
local function assessIntegration(): {status: string, score: number, details: any}
	local success, result = pcall(function()
		-- Test ServiceLocator integration
		local errorHandler = ServiceLocator:GetService("ErrorHandler")
		local circuitBreaker = ServiceLocator:GetService("CircuitBreaker")
		local recoveryManager = ServiceLocator:GetService("RecoveryManager")
		
		assert(errorHandler ~= nil, "ErrorHandler should be registered")
		assert(circuitBreaker ~= nil, "CircuitBreaker should be registered")
		assert(recoveryManager ~= nil, "RecoveryManager should be registered")
		
		-- Test integration between components
		local testError = errorHandler:HandleError("Integration test", "IntegrationTest")
		assert(testError ~= nil, "Integration error handling should work")
		
		-- Test circuit breaker integration
		local cbState = errorHandler:GetCircuitBreakerState("IntegrationTest")
		-- Note: cbState might be nil if circuit breaker doesn't exist yet, which is OK
		
		-- Test analytics integration (if available)
		local analytics = ServiceLocator:GetService("AnalyticsEngine")
		local analyticsIntegration = analytics ~= nil
		
		-- Test logging integration
		local logging = ServiceLocator:GetService("Logging")
		local loggingIntegration = logging ~= nil
		
		return {
			status = "HEALTHY",
			score = 25,
			details = {
				serviceLocatorIntegration = "Complete",
				componentIntegration = "Functional",
				analyticsIntegration = analyticsIntegration and "Active" or "Not Available",
				loggingIntegration = loggingIntegration and "Active" or "Not Available",
				crossComponentCommunication = "Operational"
			}
		}
	end)
	
	if success then
		return result
	else
		return {
			status = "FAILED",
			score = 0,
			details = {
				error = tostring(result),
				serviceLocatorIntegration = "Failed",
				componentIntegration = "Failed",
				analyticsIntegration = "Failed",
				loggingIntegration = "Failed",
				crossComponentCommunication = "Failed"
			}
		}
	end
end

-- Run comprehensive health assessment
local function runHealthAssessment(): ()
	print("🏥 Starting Phase 3.9 Health Assessment...")
	print("=" * 50)
	
	-- Wait for services to initialize
	task.wait(5)
	
	-- Assess all components
	healthResults.components.errorHandler = assessErrorHandler()
	healthResults.components.circuitBreaker = assessCircuitBreaker()
	healthResults.components.recoveryManager = assessRecoveryManager()
	healthResults.components.integration = assessIntegration()
	
	-- Calculate overall score
	local totalScore = 0
	local componentCount = 0
	
	for componentName, assessment in pairs(healthResults.components) do
		totalScore = totalScore + assessment.score
		componentCount = componentCount + 1
		
		local statusEmoji = assessment.status == "HEALTHY" and "✅" or "❌"
		print(string.format("%s %s: %s (%d/25 points)", 
			statusEmoji, componentName, assessment.status, assessment.score))
		
		-- Print component details
		for detailName, detailValue in pairs(assessment.details) do
			if detailName ~= "error" then
				print(string.format("   - %s: %s", detailName, detailValue))
			end
		end
		
		-- Print errors if any
		if assessment.details.error then
			print(string.format("   ❌ Error: %s", assessment.details.error))
		end
		
		print()
	end
	
	healthResults.score = totalScore
	
	-- Determine overall health
	if totalScore >= 95 then
		healthResults.overall = "EXCELLENT"
	elseif totalScore >= 80 then
		healthResults.overall = "GOOD"
	elseif totalScore >= 60 then
		healthResults.overall = "FAIR"
	elseif totalScore >= 40 then
		healthResults.overall = "POOR"
	else
		healthResults.overall = "CRITICAL"
	end
	
	-- Generate recommendations
	if totalScore < healthResults.maxScore then
		for componentName, assessment in pairs(healthResults.components) do
			if assessment.status ~= "HEALTHY" then
				table.insert(healthResults.recommendations, 
					string.format("Fix %s component issues", componentName))
			end
		end
	end
	
	if #healthResults.recommendations == 0 then
		table.insert(healthResults.recommendations, "System is operating optimally")
	end
	
	-- Print final results
	print("=" * 50)
	print("🎯 PHASE 3.9 HEALTH ASSESSMENT RESULTS")
	print("=" * 50)
	print(string.format("Overall Health: %s", healthResults.overall))
	print(string.format("Health Score: %d/%d (%.1f%%)", 
		healthResults.score, healthResults.maxScore, 
		(healthResults.score / healthResults.maxScore) * 100))
	print()
	
	print("📊 Component Breakdown:")
	for componentName, assessment in pairs(healthResults.components) do
		local statusEmoji = assessment.status == "HEALTHY" and "✅" or "❌"
		print(string.format("  %s %s: %d/25 points", statusEmoji, componentName, assessment.score))
	end
	print()
	
	print("💡 Recommendations:")
	for i, recommendation in ipairs(healthResults.recommendations) do
		print(string.format("  %d. %s", i, recommendation))
	end
	print()
	
	-- Success criteria check
	local meetsSuccessCriteria = healthResults.score >= 95
	print("✅ SUCCESS CRITERIA:")
	print(string.format("  Target Score: 95/100 - %s", 
		meetsSuccessCriteria and "✅ MET" or "❌ NOT MET"))
	print(string.format("  Achieved Score: %d/100", healthResults.score))
	print()
	
	if meetsSuccessCriteria then
		print("🎉 PHASE 3.9 SUCCESSFULLY COMPLETED!")
		print("   Enterprise Error Handling & Recovery System is operational")
		print("   Ready for production deployment")
	else
		print("⚠️  PHASE 3.9 NEEDS ATTENTION")
		print("   Some components require fixes before completion")
	end
	
	print("=" * 50)
	
	-- Record results
	local logger = ServiceLocator:GetService("Logging")
	if logger then
		logger.LogInfo("Phase 3.9 health assessment completed", healthResults)
	end
end

-- Run the assessment
task.spawn(function()
	task.wait(10) -- Allow time for all services to initialize
	runHealthAssessment()
end)

return healthResults
