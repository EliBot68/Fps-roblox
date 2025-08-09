--[[
	RemoteEventTests.lua
	Unit tests for RemoteEvent handling and rate limiting
	
	Tests RateLimiter, remote validation, and security systems
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local TestFramework = require(ReplicatedStorage.Shared.TestFramework)
local RateLimiter = require(ReplicatedStorage.Shared.RateLimiter)

-- Create RemoteEvent test suite
local RemoteEventTests = TestFramework.CreateSuite("RemoteEvents")

-- Mock player for testing
local function createMockPlayer()
	return {
		Name = "TestPlayer",
		UserId = 12345,
		Kick = function() end
	}
end

-- Test rate limiter basic functionality
TestFramework.AddTest("RateLimiter_Basic", function()
	local mockPlayer = createMockPlayer()
	
	-- Test initial rate limit check
	local allowed1 = RateLimiter.CheckLimit(mockPlayer, "TestAction", 1) -- 1 per second
	TestFramework.Assert(allowed1, "First request should be allowed")
	
	-- Test immediate second request (should be blocked)
	local allowed2 = RateLimiter.CheckLimit(mockPlayer, "TestAction", 1)
	TestFramework.Assert(not allowed2, "Second immediate request should be blocked")
end)

-- Test rate limiter token bucket
TestFramework.AddTest("RateLimiter_TokenBucket", function()
	local mockPlayer = createMockPlayer()
	
	-- Test burst allowance
	local burst1 = RateLimiter.CheckLimit(mockPlayer, "BurstAction", 5) -- 5 per second
	local burst2 = RateLimiter.CheckLimit(mockPlayer, "BurstAction", 5)
	local burst3 = RateLimiter.CheckLimit(mockPlayer, "BurstAction", 5)
	
	TestFramework.Assert(burst1, "First burst request should be allowed")
	TestFramework.Assert(burst2, "Second burst request should be allowed")
	TestFramework.Assert(burst3, "Third burst request should be allowed")
	
	-- Test burst exhaustion
	for i = 1, 10 do
		RateLimiter.CheckLimit(mockPlayer, "BurstAction", 5)
	end
	
	local burstExhausted = RateLimiter.CheckLimit(mockPlayer, "BurstAction", 5)
	TestFramework.Assert(not burstExhausted, "Burst should be exhausted")
end)

-- Test rate limiter violation tracking
TestFramework.AddTest("RateLimiter_Violations", function()
	local mockPlayer = createMockPlayer()
	
	-- Generate violations
	for i = 1, 15 do
		RateLimiter.CheckLimit(mockPlayer, "ViolationTest", 0.1) -- Very restrictive
	end
	
	local stats = RateLimiter.GetStats(mockPlayer)
	TestFramework.AssertNotNil(stats, "Should have player stats")
	TestFramework.Assert(stats.totalViolations > 0, "Should have recorded violations")
end)

-- Test rate limiter cleanup
TestFramework.AddTest("RateLimiter_Cleanup", function()
	local mockPlayer = createMockPlayer()
	
	-- Create some rate limit data
	RateLimiter.CheckLimit(mockPlayer, "CleanupTest", 1)
	
	-- Test cleanup
	RateLimiter.CleanupPlayer(mockPlayer)
	
	-- Verify cleanup worked
	local statsAfterCleanup = RateLimiter.GetStats(mockPlayer)
	TestFramework.AssertNotNil(statsAfterCleanup, "Stats should still exist but be reset")
end)

-- Test different action types
TestFramework.AddTest("RateLimiter_ActionTypes", function()
	local mockPlayer = createMockPlayer()
	
	-- Test different actions have separate limits
	local fireAllowed = RateLimiter.CheckLimit(mockPlayer, "FireWeapon", 10)
	local reloadAllowed = RateLimiter.CheckLimit(mockPlayer, "ReloadWeapon", 2)
	local teleportAllowed = RateLimiter.CheckLimit(mockPlayer, "Teleport", 0.5)
	
	TestFramework.Assert(fireAllowed, "Fire weapon should be allowed")
	TestFramework.Assert(reloadAllowed, "Reload weapon should be allowed")
	TestFramework.Assert(teleportAllowed, "Teleport should be allowed")
	
	-- Actions should be tracked separately
	for i = 1, 20 do
		RateLimiter.CheckLimit(mockPlayer, "FireWeapon", 10)
	end
	
	-- Reload should still work even if fire is exhausted
	local reloadStillAllowed = RateLimiter.CheckLimit(mockPlayer, "ReloadWeapon", 2)
	TestFramework.Assert(reloadStillAllowed, "Reload should still work when fire is exhausted")
end)

-- Test edge cases
TestFramework.AddTest("RateLimiter_EdgeCases", function()
	local mockPlayer = createMockPlayer()
	
	-- Test zero rate limit
	local zeroRate = RateLimiter.CheckLimit(mockPlayer, "ZeroRate", 0)
	TestFramework.Assert(not zeroRate, "Zero rate should always be blocked")
	
	-- Test very high rate limit
	local highRate = RateLimiter.CheckLimit(mockPlayer, "HighRate", 1000)
	TestFramework.Assert(highRate, "Very high rate should be allowed")
	
	-- Test negative rate limit (should be treated as blocked)
	local negativeRate = RateLimiter.CheckLimit(mockPlayer, "NegativeRate", -1)
	TestFramework.Assert(not negativeRate, "Negative rate should be blocked")
end)

-- Setup function for RemoteEvent tests
TestFramework.SetSetup(function()
	print("[RemoteEventTests] Setting up test environment...")
	-- Any setup needed for RemoteEvent tests
end)

-- Teardown function for RemoteEvent tests
TestFramework.SetTeardown(function()
	print("[RemoteEventTests] Cleaning up test environment...")
	-- Clean up any test data
end)

-- Run RemoteEvent tests and return module
function RemoteEventTests.RunTests()
	return TestFramework.RunSuite("RemoteEvents")
end

return RemoteEventTests
