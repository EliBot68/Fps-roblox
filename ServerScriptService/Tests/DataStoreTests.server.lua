--[[
	DataStoreTests.server.lua
	Enterprise DataStore System Test Suite
	Phase 2.5: Comprehensive Testing Framework

	Test Coverage:
	- DataValidator validation and sanitization
	- DataManager save/load operations with retries
	- DataMigration system with rollback testing
	- Backup and recovery mechanisms
	- Performance benchmarking (99.9% success rate validation)
	- Stress testing and concurrency
	- Error handling and edge cases
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ServiceLocator = require(ReplicatedStorage.Shared.ServiceLocator)
local Logging = require(ReplicatedStorage.Shared.Logging)
local DataValidator = require(ReplicatedStorage.Shared.DataValidator)

-- Wait for DataManager and DataMigration to be available
local DataManager = ServiceLocator.Get("DataManager")
local DataMigration = ServiceLocator.Get("DataMigration")

local DataStoreTests = {}

-- Test configuration
local TEST_CONFIG = {
	performanceTestDuration = 30, -- seconds
	stressTestIterations = 100,
	targetSuccessRate = 99.9, -- 99.9% target
	maxAcceptableLatency = 2000, -- 2 seconds
	concurrentUsers = 50
}

-- Test state
local testState = {
	totalTests = 0,
	passedTests = 0,
	failedTests = 0,
	results = {},
	performanceMetrics = {
		saveOperations = {},
		loadOperations = {},
		migrationOperations = {}
	}
}

-- Utility: Test framework helpers
local function assert(condition, message)
	if not condition then
		error("Assertion failed: " .. (message or "unknown"), 2)
	end
end

local function runTest(testName: string, testFunction: () -> ())
	testState.totalTests += 1
	
	Logging.Info("DataStoreTests", "Running test: " .. testName)
	
	local startTime = tick()
	local success, result = pcall(testFunction)
	local duration = (tick() - startTime) * 1000
	
	local testResult = {
		name = testName,
		success = success,
		duration = duration,
		error = success and nil or tostring(result),
		timestamp = os.time()
	}
	
	table.insert(testState.results, testResult)
	
	if success then
		testState.passedTests += 1
		Logging.Info("DataStoreTests", "✅ PASS: " .. testName .. " (" .. string.format("%.2fms", duration) .. ")")
	else
		testState.failedTests += 1
		Logging.Error("DataStoreTests", "❌ FAIL: " .. testName, {
			error = result,
			duration = duration
		})
	end
	
	return success
end

-- Test: DataValidator basic validation
local function testDataValidatorBasic()
	local testData = {
		userId = 12345,
		username = "TestUser",
		level = 5,
		experience = 1250,
		currency = 500,
		playtime = 3600,
		lastSeen = os.time(),
		settings = {
			soundEnabled = true,
			musicVolume = 0.7,
			sfxVolume = 0.8,
			sensitivity = 1.2
		},
		inventory = {
			weapons = {},
			items = {},
			skins = {}
		},
		statistics = {
			kills = 10,
			deaths = 5,
			wins = 3,
			losses = 2,
			shotsFired = 100,
			shotsHit = 75
		}
	}
	
	local result = DataValidator.ValidateData(testData)
	
	assert(result.isValid, "Valid data should pass validation")
	assert(result.sanitizedData ~= nil, "Sanitized data should be provided")
	assert(result.sanitizedData._version == 2.0, "Should auto-upgrade to current version")
	assert(#result.errors == 0, "Should have no errors for valid data")
end

-- Test: DataValidator with invalid data
local function testDataValidatorInvalid()
	local invalidData = {
		userId = "not_a_number", -- Wrong type
		username = "", -- Too short
		level = -5, -- Below minimum
		currency = "invalid", -- Wrong type
		settings = {
			musicVolume = 2.0 -- Above maximum
		}
	}
	
	local result = DataValidator.ValidateData(invalidData)
	
	assert(not result.isValid, "Invalid data should fail validation")
	assert(#result.errors > 0, "Should have validation errors")
	assert(result.sanitizedData ~= nil, "Should provide sanitized data")
	
	-- Check that sanitization fixed the volume
	assert(result.sanitizedData.settings.musicVolume <= 1.0, "Should sanitize volume to max")
end

-- Test: DataValidator corruption detection
local function testDataValidatorCorruption()
	local corruptedData = {
		userId = 12345,
		username = "Test"
	}
	
	-- Create circular reference
	corruptedData.circular = corruptedData
	
	local corruptionResult = DataValidator.DetectCorruption(corruptedData)
	
	assert(corruptionResult.corrupted, "Should detect circular reference")
	assert(#corruptionResult.issues > 0, "Should report corruption issues")
end

-- Test: DataValidator default data creation
local function testDataValidatorDefaults()
	local defaultData = DataValidator.CreateDefaultPlayerData(99999, "NewUser")
	
	assert(defaultData.userId == 99999, "Should set correct userId")
	assert(defaultData.username == "NewUser", "Should set correct username")
	assert(defaultData.level == 1, "Should set default level")
	assert(defaultData.currency == 0, "Should set default currency")
	assert(type(defaultData.settings) == "table", "Should create settings table")
	assert(type(defaultData.inventory) == "table", "Should create inventory table")
	assert(type(defaultData.statistics) == "table", "Should create statistics table")
end

-- Test: DataManager save and load operations
local function testDataManagerSaveLoad()
	local testUserId = 88888
	local testData = DataValidator.CreateDefaultPlayerData(testUserId, "SaveLoadTest")
	
	-- Modify some data
	testData.level = 15
	testData.currency = 1500
	testData.statistics.kills = 25
	
	-- Test save
	local saveResult = DataManager.SavePlayerData(testUserId, testData)
	
	assert(saveResult.success, "Save operation should succeed: " .. (saveResult.error or ""))
	assert(saveResult.timeTaken < TEST_CONFIG.maxAcceptableLatency, "Save should be within latency threshold")
	
	wait(0.1) -- Brief pause to ensure save completes
	
	-- Test load
	local loadResult = DataManager.LoadPlayerData(testUserId)
	
	assert(loadResult.success, "Load operation should succeed")
	assert(loadResult.data ~= nil, "Loaded data should not be nil")
	assert(loadResult.data.level == 15, "Should load correct level")
	assert(loadResult.data.currency == 1500, "Should load correct currency")
	assert(loadResult.data.statistics.kills == 25, "Should load correct statistics")
end

-- Test: DataManager backup and recovery
local function testDataManagerBackupRecovery()
	local testUserId = 77777
	local testData = DataValidator.CreateDefaultPlayerData(testUserId, "BackupTest")
	
	-- Save original data
	local saveResult = DataManager.SavePlayerData(testUserId, testData)
	assert(saveResult.success, "Initial save should succeed")
	assert(saveResult.backupSaved, "Backup should be created")
	
	wait(0.1)
	
	-- Test backup loading
	local backupData = DataManager.LoadLatestBackup(testUserId)
	assert(backupData ~= nil, "Should be able to load backup")
	assert(backupData.userId == testUserId, "Backup should contain correct userId")
	
	-- Test forced backup
	local forceBackupResult = DataManager.ForceBackup(testUserId)
	assert(forceBackupResult, "Forced backup should succeed")
end

-- Test: DataManager emergency recovery
local function testDataManagerEmergencyRecovery()
	local testUserId = 66666
	
	-- Test emergency recovery for non-existent user (should create default)
	local recoveryResult = DataManager.EmergencyRecovery(testUserId)
	
	-- Emergency recovery might fail for test user, but should not crash
	assert(type(recoveryResult) == "table", "Should return recovery result table")
	assert(type(recoveryResult.success) == "boolean", "Should have success field")
end

-- Test: DataMigration basic migration
local function testDataMigrationBasic()
	-- Create old version data
	local oldData = {
		userId = 55555,
		username = "MigrationTest",
		level = 10,
		experience = 2500,
		currency = 750,
		settings = {
			soundEnabled = true,
			musicVolume = 0.5,
			sfxVolume = 0.8,
			sensitivity = 1.0
		},
		inventory = {
			weapons = {},
			items = {},
			skins = {}
		},
		statistics = {
			kills = 20,
			deaths = 10,
			wins = 5,
			losses = 5,
			shotsFired = 200,
			shotsHit = 150
		},
		_version = 1.0 -- Old version
	}
	
	-- Test migration
	local migrationResult = DataMigration.MigrateData(55555, oldData)
	
	assert(migrationResult.success, "Migration should succeed: " .. table.concat(migrationResult.errors, ", "))
	assert(migrationResult.stepsExecuted > 0, "Should execute migration steps")
	assert(oldData._version == 2.0, "Should update to current version")
	assert(oldData.achievements ~= nil, "Should add achievements section")
	assert(oldData.premiumCurrency ~= nil, "Should add premium currency")
end

-- Test: DataMigration test mode
local function testDataMigrationTestMode()
	local testData = {
		userId = 44444,
		username = "TestMode",
		level = 5,
		_version = 1.0
	}
	
	local originalData = {}
	for k, v in pairs(testData) do
		originalData[k] = v
	end
	
	-- Test migration without applying changes
	local testResult = DataMigration.TestMigration(testData)
	
	assert(type(testResult) == "table", "Should return test result")
	assert(testData._version == 1.0, "Original data should remain unchanged")
	
	-- Original data should be intact
	for k, v in pairs(originalData) do
		assert(testData[k] == v, "Original data field should be unchanged: " .. k)
	end
end

-- Test: DataMigration plan generation
local function testDataMigrationPlan()
	local testData = {_version = 1.0}
	
	local plan = DataMigration.GetMigrationPlan(testData)
	
	assert(plan ~= nil, "Should generate migration plan for old data")
	assert(plan.totalSteps > 0, "Should have migration steps")
	assert(plan.estimatedTime > 0, "Should estimate migration time")
	assert(type(plan.requiresBackup) == "boolean", "Should specify backup requirement")
end

-- Test: Performance benchmark - 99.9% success rate validation
local function testPerformanceBenchmark()
	Logging.Info("DataStoreTests", "Starting performance benchmark...")
	
	local totalOperations = 0
	local successfulOperations = 0
	local startTime = tick()
	
	-- Run save/load operations for specified duration
	while (tick() - startTime) < TEST_CONFIG.performanceTestDuration do
		local testUserId = math.random(100000, 999999)
		local testData = DataValidator.CreateDefaultPlayerData(testUserId, "PerfTest" .. testUserId)
		
		-- Test save operation
		totalOperations += 1
		local saveResult = DataManager.SavePlayerData(testUserId, testData)
		if saveResult.success then
			successfulOperations += 1
		end
		
		table.insert(testState.performanceMetrics.saveOperations, {
			success = saveResult.success,
			timeTaken = saveResult.timeTaken,
			retries = saveResult.retries
		})
		
		wait(0.01) -- Small delay to prevent overwhelming
	end
	
	local successRate = (successfulOperations / totalOperations) * 100
	
	Logging.Info("DataStoreTests", "Performance benchmark completed", {
		totalOperations = totalOperations,
		successfulOperations = successfulOperations,
		successRate = successRate,
		duration = TEST_CONFIG.performanceTestDuration
	})
	
	assert(successRate >= TEST_CONFIG.targetSuccessRate, 
		string.format("Success rate %.2f%% is below target %.2f%%", successRate, TEST_CONFIG.targetSuccessRate))
end

-- Test: Stress test with concurrent operations
local function testStressTestConcurrent()
	Logging.Info("DataStoreTests", "Starting stress test...")
	
	local operations = {}
	local results = {}
	
	-- Create concurrent operations
	for i = 1, TEST_CONFIG.concurrentUsers do
		local testUserId = 200000 + i
		local testData = DataValidator.CreateDefaultPlayerData(testUserId, "StressTest" .. i)
		
		table.insert(operations, function()
			local saveResult = DataManager.SavePlayerData(testUserId, testData)
			local loadResult = DataManager.LoadPlayerData(testUserId)
			
			return {
				saveSuccess = saveResult.success,
				loadSuccess = loadResult.success,
				saveTime = saveResult.timeTaken,
				loadTime = loadResult and loadResult.timeTaken or 0
			}
		end)
	end
	
	-- Execute operations concurrently
	local threads = {}
	for i, operation in ipairs(operations) do
		table.insert(threads, task.spawn(function()
			local result = operation()
			results[i] = result
		end))
	end
	
	-- Wait for all operations to complete
	for _, thread in ipairs(threads) do
		while coroutine.status(thread) ~= "dead" do
			wait(0.01)
		end
	end
	
	-- Analyze results
	local successfulSaves = 0
	local successfulLoads = 0
	
	for _, result in pairs(results) do
		if result.saveSuccess then successfulSaves += 1 end
		if result.loadSuccess then successfulLoads += 1 end
	end
	
	local saveSuccessRate = (successfulSaves / TEST_CONFIG.concurrentUsers) * 100
	local loadSuccessRate = (successfulLoads / TEST_CONFIG.concurrentUsers) * 100
	
	Logging.Info("DataStoreTests", "Stress test completed", {
		concurrentUsers = TEST_CONFIG.concurrentUsers,
		saveSuccessRate = saveSuccessRate,
		loadSuccessRate = loadSuccessRate
	})
	
	assert(saveSuccessRate >= 95, "Save success rate should be at least 95% under stress")
	assert(loadSuccessRate >= 95, "Load success rate should be at least 95% under stress")
end

-- Test: Error handling and edge cases
local function testErrorHandling()
	-- Test with nil data
	local invalidSave = DataManager.SavePlayerData(999999, nil)
	assert(not invalidSave.success, "Should fail to save nil data")
	
	-- Test with invalid userId
	local invalidLoad = DataManager.LoadPlayerData(-1)
	-- Should handle gracefully (may succeed with default data or fail safely)
	assert(type(invalidLoad) == "table", "Should return result table even for invalid userId")
	
	-- Test migration with corrupted data
	local corruptedData = {
		userId = "not_a_number",
		_version = "not_a_number"
	}
	
	local migrationResult = DataMigration.MigrateData(888888, corruptedData)
	assert(type(migrationResult) == "table", "Should handle corrupted data gracefully")
end

-- Test: ServiceLocator integration
local function testServiceLocatorIntegration()
	-- Test that all services are properly registered
	assert(ServiceLocator.Get("DataValidator") ~= nil, "DataValidator should be registered")
	assert(ServiceLocator.Get("DataManager") ~= nil, "DataManager should be registered")
	assert(ServiceLocator.Get("DataMigration") ~= nil, "DataMigration should be registered")
	
	-- Test health checks
	local dataValidatorHealth = ServiceLocator.HealthCheck("DataValidator")
	local dataManagerHealth = ServiceLocator.HealthCheck("DataManager")
	local dataMigrationHealth = ServiceLocator.HealthCheck("DataMigration")
	
	assert(dataValidatorHealth, "DataValidator should be healthy")
	assert(dataManagerHealth, "DataManager should be healthy")
	assert(dataMigrationHealth, "DataMigration should be healthy")
end

-- Main test runner
function DataStoreTests.RunAllTests()
	Logging.Info("DataStoreTests", "🚀 Starting Enterprise DataStore System Test Suite")
	
	local startTime = tick()
	
	-- Reset test state
	testState = {
		totalTests = 0,
		passedTests = 0,
		failedTests = 0,
		results = {},
		performanceMetrics = {
			saveOperations = {},
			loadOperations = {},
			migrationOperations = {}
		}
	}
	
	-- Run all tests
	local tests = {
		{"DataValidator Basic Validation", testDataValidatorBasic},
		{"DataValidator Invalid Data", testDataValidatorInvalid},
		{"DataValidator Corruption Detection", testDataValidatorCorruption},
		{"DataValidator Default Data", testDataValidatorDefaults},
		{"DataManager Save/Load", testDataManagerSaveLoad},
		{"DataManager Backup/Recovery", testDataManagerBackupRecovery},
		{"DataManager Emergency Recovery", testDataManagerEmergencyRecovery},
		{"DataMigration Basic", testDataMigrationBasic},
		{"DataMigration Test Mode", testDataMigrationTestMode},
		{"DataMigration Plan Generation", testDataMigrationPlan},
		{"ServiceLocator Integration", testServiceLocatorIntegration},
		{"Error Handling", testErrorHandling},
		{"Performance Benchmark", testPerformanceBenchmark},
		{"Stress Test Concurrent", testStressTestConcurrent}
	}
	
	for _, test in ipairs(tests) do
		runTest(test[1], test[2])
		wait(0.1) -- Small delay between tests
	end
	
	local totalTime = (tick() - startTime) * 1000
	local successRate = (testState.passedTests / testState.totalTests) * 100
	
	-- Generate final report
	local report = {
		summary = {
			totalTests = testState.totalTests,
			passedTests = testState.passedTests,
			failedTests = testState.failedTests,
			successRate = successRate,
			totalTime = totalTime
		},
		serviceStats = {
			dataValidator = DataValidator.GetValidationStats(),
			dataManager = DataManager.GetDataStats(),
			dataMigration = DataMigration.GetMigrationStats()
		},
		performanceMetrics = testState.performanceMetrics
	}
	
	-- Log comprehensive results
	Logging.Info("DataStoreTests", "📊 Enterprise DataStore Test Suite Complete", report.summary)
	
	if testState.failedTests == 0 then
		Logging.Info("DataStoreTests", "🎉 ALL TESTS PASSED! Enterprise DataStore System is fully operational.")
	else
		Logging.Error("DataStoreTests", "❌ Some tests failed. Review failed tests:", {
			failedTests = testState.failedTests,
			successRate = successRate
		})
	end
	
	return report
end

-- Auto-run tests when script loads (for testing environment)
if RunService:IsServer() then
	-- Small delay to ensure all services are initialized
	task.wait(2)
	
	task.spawn(function()
		DataStoreTests.RunAllTests()
	end)
end

return DataStoreTests
