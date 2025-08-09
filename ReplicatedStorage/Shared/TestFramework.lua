--[[
	TestFramework.lua
	Enterprise unit testing framework for critical modules
	
	Provides a testing harness for RemoteEvent handling, weapon systems, and core logic
]]

local TestFramework = {}

-- Test result types
export type TestResult = {
	name: string,
	passed: boolean,
	message: string?,
	duration: number,
	timestamp: number
}

export type TestSuite = {
	name: string,
	tests: {() -> TestResult},
	setup: (() -> ())?,
	teardown: (() -> ())?
}

-- Test state
local testSuites: {TestSuite} = {}
local currentSuite: TestSuite? = nil
local totalTests = 0
local passedTests = 0

-- Assertion functions
function TestFramework.Assert(condition: boolean, message: string?): boolean
	if not condition then
		error(message or "Assertion failed", 2)
	end
	return true
end

function TestFramework.AssertEqual(actual: any, expected: any, message: string?): boolean
	if actual ~= expected then
		local errorMsg = message or string.format("Expected %s, got %s", tostring(expected), tostring(actual))
		error(errorMsg, 2)
	end
	return true
end

function TestFramework.AssertNotEqual(actual: any, expected: any, message: string?): boolean
	if actual == expected then
		local errorMsg = message or string.format("Expected not %s, but got %s", tostring(expected), tostring(actual))
		error(errorMsg, 2)
	end
	return true
end

function TestFramework.AssertNil(value: any, message: string?): boolean
	if value ~= nil then
		local errorMsg = message or string.format("Expected nil, got %s", tostring(value))
		error(errorMsg, 2)
	end
	return true
end

function TestFramework.AssertNotNil(value: any, message: string?): boolean
	if value == nil then
		local errorMsg = message or "Expected non-nil value"
		error(errorMsg, 2)
	end
	return true
end

function TestFramework.AssertType(value: any, expectedType: string, message: string?): boolean
	local actualType = type(value)
	if actualType ~= expectedType then
		local errorMsg = message or string.format("Expected type %s, got %s", expectedType, actualType)
		error(errorMsg, 2)
	end
	return true
end

-- Create a new test suite
function TestFramework.CreateSuite(name: string): TestSuite
	local suite: TestSuite = {
		name = name,
		tests = {},
		setup = nil,
		teardown = nil
	}
	
	table.insert(testSuites, suite)
	currentSuite = suite
	
	return suite
end

-- Add a test to the current suite
function TestFramework.AddTest(name: string, testFunction: () -> ())
	if not currentSuite then
		error("No active test suite. Call CreateSuite first.")
	end
	
	local function wrappedTest(): TestResult
		local startTime = tick()
		local success, errorMessage = pcall(testFunction)
		local duration = tick() - startTime
		
		totalTests = totalTests + 1
		if success then
			passedTests = passedTests + 1
		end
		
		return {
			name = name,
			passed = success,
			message = errorMessage,
			duration = duration,
			timestamp = tick()
		}
	end
	
	table.insert(currentSuite.tests, wrappedTest)
end

-- Set setup function for current suite
function TestFramework.SetSetup(setupFunction: () -> ())
	if not currentSuite then
		error("No active test suite. Call CreateSuite first.")
	end
	
	currentSuite.setup = setupFunction
end

-- Set teardown function for current suite
function TestFramework.SetTeardown(teardownFunction: () -> ())
	if not currentSuite then
		error("No active test suite. Call CreateSuite first.")
	end
	
	currentSuite.teardown = teardownFunction
end

-- Run a specific test suite
function TestFramework.RunSuite(suiteName: string): {results: {TestResult}, passed: number, failed: number, duration: number}
	local suite = nil
	for _, s in ipairs(testSuites) do
		if s.name == suiteName then
			suite = s
			break
		end
	end
	
	if not suite then
		error("Test suite not found: " .. suiteName)
	end
	
	local results: {TestResult} = {}
	local passed = 0
	local failed = 0
	local startTime = tick()
	
	print("[TestFramework] Running suite:", suiteName)
	
	-- Run setup if available
	if suite.setup then
		local setupSuccess, setupError = pcall(suite.setup)
		if not setupSuccess then
			print("[TestFramework] ❌ Setup failed:", setupError)
			return {results = {}, passed = 0, failed = 1, duration = 0}
		end
	end
	
	-- Run all tests
	for _, test in ipairs(suite.tests) do
		local result = test()
		table.insert(results, result)
		
		if result.passed then
			passed = passed + 1
			print("[TestFramework] ✅", result.name, string.format("(%.2fms)", result.duration * 1000))
		else
			failed = failed + 1
			print("[TestFramework] ❌", result.name, ":", result.message)
		end
	end
	
	-- Run teardown if available
	if suite.teardown then
		local teardownSuccess, teardownError = pcall(suite.teardown)
		if not teardownSuccess then
			print("[TestFramework] ⚠️ Teardown failed:", teardownError)
		end
	end
	
	local duration = tick() - startTime
	print("[TestFramework] Suite completed:", passed, "passed,", failed, "failed", string.format("(%.2fs)", duration))
	
	return {
		results = results,
		passed = passed,
		failed = failed,
		duration = duration
	}
end

-- Run all test suites
function TestFramework.RunAll(): {totalPassed: number, totalFailed: number, suiteResults: {{name: string, passed: number, failed: number}}}
	local totalPassed = 0
	local totalFailed = 0
	local suiteResults: {{name: string, passed: number, failed: number}} = {}
	
	print("[TestFramework] 🧪 Running all test suites...")
	
	for _, suite in ipairs(testSuites) do
		local result = TestFramework.RunSuite(suite.name)
		totalPassed = totalPassed + result.passed
		totalFailed = totalFailed + result.failed
		
		table.insert(suiteResults, {
			name = suite.name,
			passed = result.passed,
			failed = result.failed
		})
	end
	
	print("[TestFramework] 🏁 All tests completed:", totalPassed, "passed,", totalFailed, "failed")
	
	return {
		totalPassed = totalPassed,
		totalFailed = totalFailed,
		suiteResults = suiteResults
	}
end

-- Get testing statistics
function TestFramework.GetStats(): {totalSuites: number, totalTests: number, passedTests: number, failedTests: number}
	local totalSuites = #testSuites
	local totalTestCount = 0
	
	for _, suite in ipairs(testSuites) do
		totalTestCount = totalTestCount + #suite.tests
	end
	
	return {
		totalSuites = totalSuites,
		totalTests = totalTestCount,
		passedTests = passedTests,
		failedTests = totalTests - passedTests
	}
end

-- Reset all test data
function TestFramework.Reset()
	testSuites = {}
	currentSuite = nil
	totalTests = 0
	passedTests = 0
	print("[TestFramework] ♻️ Reset all test data")
end

return TestFramework
