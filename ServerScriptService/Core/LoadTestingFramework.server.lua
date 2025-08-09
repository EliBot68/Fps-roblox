--[[
	LoadTestingFramework.lua
	Automated load simulation and regression testing for RemoteEvents
	
	Simulates multiple concurrent players to test server performance and stability
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local RateLimiter = require(ReplicatedStorage.Shared.RateLimiter)
local Logging = require(ReplicatedStorage.Shared.Logging)
local TestFramework = require(ReplicatedStorage.Shared.TestFramework)

local LoadTestingFramework = {}

-- Load test configuration
local testConfig = {
	virtualPlayers = 20,
	testDuration = 60, -- seconds
	actionsPerSecond = 5,
	remoteEventTests = {
		"FireWeapon",
		"ReloadWeapon", 
		"RequestMatch",
		"UpdateCurrency"
	}
}

-- Test results tracking
local testResults = {
	totalRequests = 0,
	successfulRequests = 0,
	failedRequests = 0,
	rateLimitedRequests = 0,
	averageLatency = 0,
	errors = {}
}

-- Virtual player simulation
local virtualPlayers = {}

-- Mock player creation for load testing
local function createVirtualPlayer(playerId: number): {Name: string, UserId: number, Kick: () -> ()}
	return {
		Name = "LoadTestPlayer_" .. playerId,
		UserId = 100000 + playerId,
		Kick = function() end
	}
end

-- Simulate RemoteEvent calls
local function simulateRemoteEvent(virtualPlayer, eventName: string): {success: boolean, latency: number, error: string?}
	local startTime = tick()
	local success = true
	local error = nil
	
	-- Simulate different RemoteEvent behaviors
	if eventName == "FireWeapon" then
		-- Test rate limiting for weapon fire
		success = RateLimiter.CheckLimit(virtualPlayer, "FireWeapon", 10)
		if not success then
			error = "Rate limited"
			testResults.rateLimitedRequests = testResults.rateLimitedRequests + 1
		end
		
		-- Simulate processing time
		task.wait(0.001) -- 1ms processing time
		
	elseif eventName == "ReloadWeapon" then
		success = RateLimiter.CheckLimit(virtualPlayer, "ReloadWeapon", 2)
		if not success then
			error = "Rate limited"
			testResults.rateLimitedRequests = testResults.rateLimitedRequests + 1
		end
		task.wait(0.002) -- 2ms processing time
		
	elseif eventName == "RequestMatch" then
		success = RateLimiter.CheckLimit(virtualPlayer, "RequestMatch", 0.5)
		if not success then
			error = "Rate limited"
			testResults.rateLimitedRequests = testResults.rateLimitedRequests + 1
		end
		task.wait(0.005) -- 5ms processing time
		
	elseif eventName == "UpdateCurrency" then
		-- This should have loose rate limits
		success = RateLimiter.CheckLimit(virtualPlayer, "UpdateCurrency", 1)
		task.wait(0.001)
	end
	
	local latency = tick() - startTime
	
	-- Track results
	testResults.totalRequests = testResults.totalRequests + 1
	if success then
		testResults.successfulRequests = testResults.successfulRequests + 1
	else
		testResults.failedRequests = testResults.failedRequests + 1
		if error then
			table.insert(testResults.errors, {
				player = virtualPlayer.Name,
				event = eventName,
				error = error,
				timestamp = tick()
			})
		end
	end
	
	return {
		success = success,
		latency = latency,
		error = error
	}
end

-- Run load test simulation
function LoadTestingFramework.RunLoadTest(config: {virtualPlayers: number?, testDuration: number?, actionsPerSecond: number?}?): {
	success: boolean,
	results: typeof(testResults),
	summary: {avgLatency: number, successRate: number, requestsPerSecond: number}
}
	-- Apply configuration
	if config then
		testConfig.virtualPlayers = config.virtualPlayers or testConfig.virtualPlayers
		testConfig.testDuration = config.testDuration or testConfig.testDuration
		testConfig.actionsPerSecond = config.actionsPerSecond or testConfig.actionsPerSecond
	end
	
	-- Reset test results
	testResults = {
		totalRequests = 0,
		successfulRequests = 0,
		failedRequests = 0,
		rateLimitedRequests = 0,
		averageLatency = 0,
		errors = {}
	}
	
	-- Create virtual players
	virtualPlayers = {}
	for i = 1, testConfig.virtualPlayers do
		table.insert(virtualPlayers, createVirtualPlayer(i))
	end
	
	print("[LoadTest] 🧪 Starting load test with", testConfig.virtualPlayers, "virtual players")
	print("[LoadTest] Duration:", testConfig.testDuration, "seconds, Actions/sec:", testConfig.actionsPerSecond)
	
	local startTime = tick()
	local totalLatency = 0
	local requestCount = 0
	
	-- Main load test loop
	local testConnections = {}
	
	for _, virtualPlayer in ipairs(virtualPlayers) do
		local connection = task.spawn(function()
			local playerStartTime = tick()
			
			while tick() - playerStartTime < testConfig.testDuration do
				-- Choose random RemoteEvent to test
				local eventName = testConfig.remoteEventTests[math.random(1, #testConfig.remoteEventTests)]
				
				-- Simulate the event
				local result = simulateRemoteEvent(virtualPlayer, eventName)
				
				totalLatency = totalLatency + result.latency
				requestCount = requestCount + 1
				
				-- Wait before next action
				task.wait(1 / testConfig.actionsPerSecond)
			end
		end)
		
		table.insert(testConnections, connection)
	end
	
	-- Wait for all virtual players to complete
	for _, connection in ipairs(testConnections) do
		-- Connections are already running via task.spawn
	end
	
	-- Wait for test duration
	task.wait(testConfig.testDuration)
	
	local testDuration = tick() - startTime
	
	-- Calculate summary statistics
	local avgLatency = requestCount > 0 and (totalLatency / requestCount) or 0
	local successRate = testResults.totalRequests > 0 and (testResults.successfulRequests / testResults.totalRequests) or 0
	local requestsPerSecond = testResults.totalRequests / testDuration
	
	testResults.averageLatency = avgLatency
	
	local summary = {
		avgLatency = avgLatency,
		successRate = successRate,
		requestsPerSecond = requestsPerSecond
	}
	
	-- Log results
	Logging.Info("LoadTest", "Load test completed", {
		duration = testDuration,
		totalRequests = testResults.totalRequests,
		successRate = successRate,
		avgLatency = avgLatency,
		requestsPerSecond = requestsPerSecond
	})
	
	print("[LoadTest] ✅ Load test completed!")
	print("[LoadTest] Total requests:", testResults.totalRequests)
	print("[LoadTest] Success rate:", string.format("%.1f%%", successRate * 100))
	print("[LoadTest] Avg latency:", string.format("%.2fms", avgLatency * 1000))
	print("[LoadTest] Requests/sec:", string.format("%.1f", requestsPerSecond))
	
	-- Determine if test passed
	local testPassed = successRate > 0.95 and avgLatency < 0.01 and requestsPerSecond > 50
	
	return {
		success = testPassed,
		results = testResults,
		summary = summary
	}
end

-- Automated regression testing
function LoadTestingFramework.RunRegressionTests(): {passed: number, failed: number, results: {{name: string, passed: boolean, details: any}}}
	print("[LoadTest] 🔄 Running automated regression tests...")
	
	local regressionTests = {
		{
			name = "Basic Load Test",
			config = {virtualPlayers = 10, testDuration = 30, actionsPerSecond = 3}
		},
		{
			name = "High Load Test", 
			config = {virtualPlayers = 25, testDuration = 20, actionsPerSecond = 8}
		},
		{
			name = "Burst Load Test",
			config = {virtualPlayers = 50, testDuration = 15, actionsPerSecond = 15}
		}
	}
	
	local results = {}
	local passed = 0
	local failed = 0
	
	for _, test in ipairs(regressionTests) do
		print("[LoadTest] Running:", test.name)
		
		local result = LoadTestingFramework.RunLoadTest(test.config)
		
		if result.success then
			passed = passed + 1
			print("[LoadTest] ✅", test.name, "PASSED")
		else
			failed = failed + 1
			print("[LoadTest] ❌", test.name, "FAILED")
		end
		
		table.insert(results, {
			name = test.name,
			passed = result.success,
			details = result.summary
		})
		
		-- Brief pause between tests
		task.wait(2)
	end
	
	print("[LoadTest] Regression testing completed:", passed, "passed,", failed, "failed")
	
	return {
		passed = passed,
		failed = failed,
		results = results
	}
end

-- Stress test specific RemoteEvents
function LoadTestingFramework.StressTestRemoteEvent(eventName: string, playersCount: number, duration: number): {success: boolean, maxRPS: number, breakdown: {success: number, rateLimited: number, errors: number}}
	print("[LoadTest] 🔥 Stress testing RemoteEvent:", eventName)
	
	local stressResults = {
		success = 0,
		rateLimited = 0,
		errors = 0
	}
	
	-- Create stress test players
	local stressPlayers = {}
	for i = 1, playersCount do
		table.insert(stressPlayers, createVirtualPlayer(1000 + i))
	end
	
	local startTime = tick()
	local requestCount = 0
	
	-- Stress test loop
	for _, player in ipairs(stressPlayers) do
		task.spawn(function()
			local playerStartTime = tick()
			
			while tick() - playerStartTime < duration do
				local result = simulateRemoteEvent(player, eventName)
				requestCount = requestCount + 1
				
				if result.success then
					stressResults.success = stressResults.success + 1
				elseif result.error == "Rate limited" then
					stressResults.rateLimited = stressResults.rateLimited + 1
				else
					stressResults.errors = stressResults.errors + 1
				end
				
				-- No wait - maximum stress
			end
		end)
	end
	
	task.wait(duration)
	
	local actualDuration = tick() - startTime
	local maxRPS = requestCount / actualDuration
	
	print("[LoadTest] Stress test results for", eventName)
	print("[LoadTest] Max RPS achieved:", string.format("%.1f", maxRPS))
	print("[LoadTest] Success:", stressResults.success, "Rate Limited:", stressResults.rateLimited, "Errors:", stressResults.errors)
	
	return {
		success = stressResults.errors == 0,
		maxRPS = maxRPS,
		breakdown = stressResults
	}
end

-- Get load testing statistics
function LoadTestingFramework.GetStats(): {currentVirtualPlayers: number, lastTestResults: typeof(testResults)}
	return {
		currentVirtualPlayers = #virtualPlayers,
		lastTestResults = testResults
	}
end

return LoadTestingFramework
