--[[
	CombatAuthorityTests.lua
	Comprehensive unit tests for the server-authoritative combat system
	
	Test Coverage:
	- Hit validation accuracy and performance
	- Lag compensation effectiveness up to 200ms
	- Anti-cheat detection and prevention
	- Combat event processing and logging
	- Integration with security and network systems
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import test framework and dependencies
local TestFramework = require(ReplicatedStorage.Shared.TestFramework)
local ServiceLocator = require(ReplicatedStorage.Shared.ServiceLocator)

local CombatAuthorityTests = {}

-- Test configuration
local TEST_CONFIG = {
	timeout = 10, -- seconds
	iterations = 100, -- for performance tests
	lagSimulation = {0.05, 0.1, 0.15, 0.2}, -- Lag values to test
	weaponTypes = {"ASSAULT_RIFLE", "SNIPER_RIFLE", "SHOTGUN", "PISTOL", "SMG"}
}

-- Mock player data for testing
local function createMockPlayer(name: string, userId: number): any
	return {
		Name = name,
		UserId = userId,
		Character = {
			PrimaryPart = {
				Position = Vector3.new(0, 0, 0),
				Velocity = Vector3.new(0, 0, 0)
			},
			Head = {
				Position = Vector3.new(0, 5, 0)
			}
		}
	}
end

-- Mock shot data for testing
local function createMockShotData(shooter: any, weapon: string, targetPos: Vector3): any
	return {
		shooter = shooter,
		weapon = weapon,
		origin = shooter.Character.PrimaryPart.Position,
		direction = (targetPos - shooter.Character.PrimaryPart.Position).Unit,
		targetPosition = targetPos,
		clientTimestamp = tick(),
		shotId = string.format("test_%s_%d", weapon, math.random(1000, 9999))
	}
end

-- Test hit validation accuracy
function CombatAuthorityTests.TestHitValidationAccuracy()
	return TestFramework.CreateTest("HitValidationAccuracy", function()
		local HitValidation = ServiceLocator.GetService("HitValidation")
		TestFramework.Assert(HitValidation ~= nil, "HitValidation service should be available")
		
		local mockShooter = createMockPlayer("TestShooter", 12345)
		local mockTarget = Vector3.new(10, 0, 0) -- 10 studs away
		
		-- Test valid shot
		local validShot = createMockShotData(mockShooter, "ASSAULT_RIFLE", mockTarget)
		local result = HitValidation.ValidateShot(validShot)
		
		TestFramework.Assert(result ~= nil, "Hit validation should return a result")
		TestFramework.Assert(type(result.isValid) == "boolean", "Result should have isValid field")
		TestFramework.Assert(type(result.damage) == "number", "Result should have damage field")
		TestFramework.Assert(type(result.distance) == "number", "Result should have distance field")
		
		print("✓ Hit validation accuracy test passed")
	end)
end

-- Test lag compensation effectiveness
function CombatAuthorityTests.TestLagCompensationEffectiveness()
	return TestFramework.CreateTest("LagCompensationEffectiveness", function()
		local LagCompensation = ServiceLocator.GetService("LagCompensation")
		TestFramework.Assert(LagCompensation ~= nil, "LagCompensation service should be available")
		
		local mockPlayer = createMockPlayer("TestPlayer", 54321)
		
		-- Update player position history
		for i = 1, 10 do
			local position = Vector3.new(i, 0, 0)
			local velocity = Vector3.new(1, 0, 0)
			LagCompensation.UpdatePlayerPosition(mockPlayer, position, velocity, tick(), 0.1)
			task.wait(0.01) -- Small delay to build history
		end
		
		-- Test compensation at different lag values
		for _, lag in ipairs(TEST_CONFIG.lagSimulation) do
			local targetTimestamp = tick() - lag
			local compensation = LagCompensation.CompensatePosition(mockPlayer, targetTimestamp)
			
			TestFramework.Assert(compensation ~= nil, "Compensation should return a result")
			TestFramework.Assert(type(compensation.isValid) == "boolean", "Compensation should have isValid field")
			TestFramework.Assert(type(compensation.compensationTime) == "number", "Compensation should have compensationTime field")
			
			if lag <= 0.2 then -- Within max compensation time
				TestFramework.Assert(compensation.compensationTime <= 0.2, "Compensation time should be within limits")
			end
		end
		
		print("✓ Lag compensation effectiveness test passed")
	end)
end

-- Test anti-cheat detection
function CombatAuthorityTests.TestAntiCheatDetection()
	return TestFramework.CreateTest("AntiCheatDetection", function()
		local HitValidation = ServiceLocator.GetService("HitValidation")
		TestFramework.Assert(HitValidation ~= nil, "HitValidation service should be available")
		
		local mockShooter = createMockPlayer("Cheater", 99999)
		
		-- Test 1: Invalid weapon
		local invalidWeaponShot = createMockShotData(mockShooter, "INVALID_WEAPON", Vector3.new(10, 0, 0))
		local result1 = HitValidation.ValidateShot(invalidWeaponShot)
		TestFramework.Assert(not result1.isValid, "Invalid weapon should be rejected")
		TestFramework.Assert(result1.exploitFlags and #result1.exploitFlags > 0, "Should flag invalid weapon")
		
		-- Test 2: Extreme distance shot
		local extremeDistanceShot = createMockShotData(mockShooter, "ASSAULT_RIFLE", Vector3.new(1000, 0, 0))
		local result2 = HitValidation.ValidateShot(extremeDistanceShot)
		TestFramework.Assert(not result2.isValid or result2.exploitFlags, "Extreme distance should be flagged")
		
		-- Test 3: Rapid fire simulation
		local rapidFireCount = 0
		for i = 1, 25 do -- Exceed rate limit
			local rapidShot = createMockShotData(mockShooter, "ASSAULT_RIFLE", Vector3.new(5, 0, 0))
			local result = HitValidation.ValidateShot(rapidShot)
			if result.exploitFlags and table.find(result.exploitFlags, "RATE_LIMIT_EXCEEDED") then
				rapidFireCount = rapidFireCount + 1
			end
		end
		TestFramework.Assert(rapidFireCount > 0, "Rapid fire should be detected")
		
		print("✓ Anti-cheat detection test passed")
	end)
end

-- Test weapon damage calculation
function CombatAuthorityTests.TestWeaponDamageCalculation()
	return TestFramework.CreateTest("WeaponDamageCalculation", function()
		local HitValidation = ServiceLocator.GetService("HitValidation")
		TestFramework.Assert(HitValidation ~= nil, "HitValidation service should be available")
		
		-- Test different weapons with different body parts
		local mockShooter = createMockPlayer("TestShooter", 11111)
		local weapons = {"ASSAULT_RIFLE", "SNIPER_RIFLE", "SHOTGUN", "PISTOL", "SMG"}
		
		for _, weapon in ipairs(weapons) do
			local shotData = createMockShotData(mockShooter, weapon, Vector3.new(5, 0, 0))
			local result = HitValidation.ValidateShot(shotData)
			
			-- Note: In a real scenario, we'd need actual targets to hit
			-- This test validates the structure and processing
			TestFramework.Assert(type(result.damage) == "number", "Damage should be a number")
			TestFramework.Assert(result.damage >= 0, "Damage should be non-negative")
		end
		
		print("✓ Weapon damage calculation test passed")
	end)
end

-- Test combat event processing performance
function CombatAuthorityTests.TestCombatEventProcessingPerformance()
	return TestFramework.CreateTest("CombatEventProcessingPerformance", function()
		local HitValidation = ServiceLocator.GetService("HitValidation")
		TestFramework.Assert(HitValidation ~= nil, "HitValidation service should be available")
		
		local mockShooter = createMockPlayer("PerformanceTest", 22222)
		local startTime = tick()
		local processedShots = 0
		
		-- Process multiple shots to test performance
		for i = 1, TEST_CONFIG.iterations do
			local weapon = TEST_CONFIG.weaponTypes[math.random(1, #TEST_CONFIG.weaponTypes)]
			local targetPos = Vector3.new(
				math.random(-50, 50),
				math.random(-10, 10), 
				math.random(-50, 50)
			)
			
			local shotData = createMockShotData(mockShooter, weapon, targetPos)
			local shotStartTime = tick()
			local result = HitValidation.ValidateShot(shotData)
			local shotProcessTime = tick() - shotStartTime
			
			TestFramework.Assert(result ~= nil, "Each shot should return a result")
			TestFramework.Assert(shotProcessTime < 0.01, "Shot processing should be under 10ms") -- Performance requirement
			
			processedShots = processedShots + 1
		end
		
		local totalTime = tick() - startTime
		local averageTimePerShot = totalTime / processedShots
		
		TestFramework.Assert(averageTimePerShot < 0.005, "Average processing time should be under 5ms")
		TestFramework.Assert(processedShots == TEST_CONFIG.iterations, "All shots should be processed")
		
		print(string.format("✓ Performance test passed: %d shots in %.3fs (%.4fs avg)", 
			processedShots, totalTime, averageTimePerShot))
	end)
end

-- Test integration with security systems
function CombatAuthorityTests.TestSecurityIntegration()
	return TestFramework.CreateTest("SecurityIntegration", function()
		local SecurityValidator = ServiceLocator.GetService("SecurityValidator")
		local HitValidation = ServiceLocator.GetService("HitValidation")
		
		TestFramework.Assert(SecurityValidator ~= nil, "SecurityValidator should be available")
		TestFramework.Assert(HitValidation ~= nil, "HitValidation should be available")
		
		local mockPlayer = createMockPlayer("SecurityTest", 33333)
		
		-- Test security validation integration
		local validationSchema = {
			weaponId = {type = "string", whitelist = {"ASSAULT_RIFLE"}},
			targetPosition = {type = "Vector3"}
		}
		
		local validData = {weaponId = "ASSAULT_RIFLE", targetPosition = Vector3.new(10, 0, 0)}
		local invalidData = {weaponId = "EXPLOIT_WEAPON", targetPosition = Vector3.new(10, 0, 0)}
		
		local validResult = SecurityValidator.ValidateRemoteCall(mockPlayer, "FireWeapon", validationSchema, validData)
		local invalidResult = SecurityValidator.ValidateRemoteCall(mockPlayer, "FireWeapon", validationSchema, invalidData)
		
		TestFramework.Assert(validResult.isValid, "Valid data should pass security validation")
		TestFramework.Assert(not invalidResult.isValid, "Invalid data should fail security validation")
		
		print("✓ Security integration test passed")
	end)
end

-- Test lag compensation memory management
function CombatAuthorityTests.TestLagCompensationMemoryManagement()
	return TestFramework.CreateTest("LagCompensationMemoryManagement", function()
		local LagCompensation = ServiceLocator.GetService("LagCompensation")
		TestFramework.Assert(LagCompensation ~= nil, "LagCompensation service should be available")
		
		local mockPlayer = createMockPlayer("MemoryTest", 44444)
		
		-- Generate lots of position updates
		for i = 1, 200 do -- More than max history entries
			local position = Vector3.new(i % 50, 0, 0)
			local velocity = Vector3.new(1, 0, 0)
			LagCompensation.UpdatePlayerPosition(mockPlayer, position, velocity, tick(), 0.1)
		end
		
		-- Check that player info is still available and reasonable
		local playerInfo = LagCompensation.GetPlayerInfo(mockPlayer)
		TestFramework.Assert(playerInfo ~= nil, "Player info should be available")
		TestFramework.Assert(playerInfo.entriesCount <= 60, "History should be limited to max entries") -- Max entries from config
		TestFramework.Assert(playerInfo.isValid, "Player should still be valid")
		
		print("✓ Lag compensation memory management test passed")
	end)
end

-- Test combat statistics collection
function CombatAuthorityTests.TestCombatStatistics()
	return TestFramework.CreateTest("CombatStatistics", function()
		local HitValidation = ServiceLocator.GetService("HitValidation")
		local LagCompensation = ServiceLocator.GetService("LagCompensation")
		
		TestFramework.Assert(HitValidation ~= nil, "HitValidation service should be available")
		TestFramework.Assert(LagCompensation ~= nil, "LagCompensation service should be available")
		
		-- Get initial statistics
		local hitStats = HitValidation.GetValidationStats()
		local lagStats = LagCompensation.GetCompensationStats()
		
		TestFramework.Assert(type(hitStats) == "table", "Hit stats should be a table")
		TestFramework.Assert(type(lagStats) == "table", "Lag stats should be a table")
		
		TestFramework.Assert(type(hitStats.totalShots) == "number", "Total shots should be a number")
		TestFramework.Assert(type(lagStats.totalCompensations) == "number", "Total compensations should be a number")
		
		print("✓ Combat statistics test passed")
	end)
end

-- Test error handling and edge cases
function CombatAuthorityTests.TestErrorHandling()
	return TestFramework.CreateTest("ErrorHandling", function()
		local HitValidation = ServiceLocator.GetService("HitValidation")
		TestFramework.Assert(HitValidation ~= nil, "HitValidation service should be available")
		
		-- Test with nil values
		local invalidShot1 = {
			shooter = nil,
			weapon = "ASSAULT_RIFLE",
			origin = Vector3.new(0, 0, 0),
			direction = Vector3.new(1, 0, 0),
			targetPosition = Vector3.new(10, 0, 0),
			clientTimestamp = tick(),
			shotId = "test_nil"
		}
		
		local result1 = HitValidation.ValidateShot(invalidShot1)
		TestFramework.Assert(not result1.isValid, "Shot with nil shooter should be invalid")
		TestFramework.Assert(result1.exploitFlags and #result1.exploitFlags > 0, "Should flag invalid data")
		
		-- Test with invalid vectors
		local mockShooter = createMockPlayer("ErrorTest", 55555)
		local invalidShot2 = createMockShotData(mockShooter, "ASSAULT_RIFLE", Vector3.new(0/0, 0, 0)) -- NaN
		
		local result2 = HitValidation.ValidateShot(invalidShot2)
		TestFramework.Assert(not result2.isValid, "Shot with NaN position should be invalid")
		
		print("✓ Error handling test passed")
	end)
end

-- Run all combat authority tests
function CombatAuthorityTests.RunAllTests(): {passed: number, failed: number, total: number}
	print("[CombatAuthorityTests] 🧪 Running comprehensive combat system tests...")
	
	local tests = {
		CombatAuthorityTests.TestHitValidationAccuracy(),
		CombatAuthorityTests.TestLagCompensationEffectiveness(),
		CombatAuthorityTests.TestAntiCheatDetection(),
		CombatAuthorityTests.TestWeaponDamageCalculation(),
		CombatAuthorityTests.TestCombatEventProcessingPerformance(),
		CombatAuthorityTests.TestSecurityIntegration(),
		CombatAuthorityTests.TestLagCompensationMemoryManagement(),
		CombatAuthorityTests.TestCombatStatistics(),
		CombatAuthorityTests.TestErrorHandling()
	}
	
	local results = TestFramework.RunTests(tests, TEST_CONFIG.timeout)
	
	print(string.format("[CombatAuthorityTests] ✅ Tests completed: %d/%d passed", 
		results.passed, results.total))
	
	if results.failed > 0 then
		print(string.format("[CombatAuthorityTests] ❌ %d tests failed", results.failed))
	end
	
	return results
end

-- Console command for running tests
_G.CombatAuthority_RunTests = function()
	return CombatAuthorityTests.RunAllTests()
end

return CombatAuthorityTests
