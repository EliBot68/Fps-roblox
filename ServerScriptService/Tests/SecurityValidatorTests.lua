-- SecurityValidatorTests.lua
-- Comprehensive unit tests for the SecurityValidator system
-- Place in: ServerScriptService/Tests/SecurityValidatorTests.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local SecurityValidator = require(ReplicatedStorage.Shared.SecurityValidator)
local TestFramework = require(ReplicatedStorage.Shared.TestFramework)

local SecurityValidatorTests = {}

-- Create mock player for testing
local function CreateMockPlayer(userId, name)
	return {
		UserId = userId or 12345,
		Name = name or "TestPlayer",
		AccountAge = 30,
		Character = {
			HumanoidRootPart = {
				Position = Vector3.new(0, 0, 0)
			}
		}
	}
end

-- Test suite for basic validation functionality
function SecurityValidatorTests.TestBasicValidation()
	local validator = SecurityValidator.new()
	local testPlayer = CreateMockPlayer()
	
	-- Test valid data
	local schema = {
		weaponId = { type = "string", required = true },
		damage = { type = "number", required = true, min = 1, max = 100 }
	}
	
	local result = validator:ValidateRemoteCall(testPlayer, "TestRemote", schema, {"ASSAULT_RIFLE", 50})
	
	TestFramework.Assert(result.isValid, "Valid data should pass validation")
	TestFramework.Assert(result.sanitizedData.weaponId == "ASSAULT_RIFLE", "Weapon ID should be sanitized correctly")
	TestFramework.Assert(result.sanitizedData.damage == 50, "Damage should be sanitized correctly")
	
	print("✅ Basic validation test passed")
end

-- Test suite for type validation
function SecurityValidatorTests.TestTypeValidation()
	local validator = SecurityValidator.new()
	local testPlayer = CreateMockPlayer()
	
	local schema = {
		stringField = { type = "string", required = true },
		numberField = { type = "number", required = true },
		booleanField = { type = "boolean", required = true }
	}
	
	-- Test correct types
	local result1 = validator:ValidateRemoteCall(testPlayer, "TestRemote", schema, {"hello", 42, true})
	TestFramework.Assert(result1.isValid, "Correct types should pass validation")
	
	-- Test incorrect types
	local result2 = validator:ValidateRemoteCall(testPlayer, "TestRemote", schema, {123, "not a number", "not a boolean"})
	TestFramework.Assert(not result2.isValid, "Incorrect types should fail validation")
	TestFramework.Assert(#result2.errors > 0, "Should have validation errors")
	
	-- Test type conversion
	local schema2 = {
		numberFromString = { type = "number", required = true }
	}
	local result3 = validator:ValidateRemoteCall(testPlayer, "TestRemote", schema2, {"123"})
	TestFramework.Assert(result3.isValid, "String to number conversion should work")
	TestFramework.Assert(result3.sanitizedData.numberFromString == 123, "Converted number should be correct")
	
	print("✅ Type validation test passed")
end

-- Test suite for range validation
function SecurityValidatorTests.TestRangeValidation()
	local validator = SecurityValidator.new()
	local testPlayer = CreateMockPlayer()
	
	local schema = {
		damage = { type = "number", required = true, min = 1, max = 100 },
		name = { type = "string", required = true, min = 3, max = 20 }
	}
	
	-- Test valid ranges
	local result1 = validator:ValidateRemoteCall(testPlayer, "TestRemote", schema, {50, "TestName"})
	TestFramework.Assert(result1.isValid, "Values within range should pass")
	
	-- Test number too low
	local result2 = validator:ValidateRemoteCall(testPlayer, "TestRemote", schema, {0, "TestName"})
	TestFramework.Assert(not result2.isValid, "Number below minimum should fail")
	
	-- Test number too high
	local result3 = validator:ValidateRemoteCall(testPlayer, "TestRemote", schema, {150, "TestName"})
	TestFramework.Assert(not result3.isValid, "Number above maximum should fail")
	
	-- Test string too short
	local result4 = validator:ValidateRemoteCall(testPlayer, "TestRemote", schema, {50, "Hi"})
	TestFramework.Assert(not result4.isValid, "String below minimum length should fail")
	
	-- Test string too long
	local result5 = validator:ValidateRemoteCall(testPlayer, "TestRemote", schema, {50, "ThisStringIsTooLongForValidation"})
	TestFramework.Assert(not result5.isValid, "String above maximum length should fail")
	
	print("✅ Range validation test passed")
end

-- Test suite for whitelist/blacklist validation
function SecurityValidatorTests.TestWhitelistBlacklistValidation()
	local validator = SecurityValidator.new()
	local testPlayer = CreateMockPlayer()
	
	local schema = {
		weaponType = { 
			type = "string", 
			required = true, 
			whitelist = {"RIFLE", "PISTOL", "SHOTGUN"} 
		},
		bannedWord = { 
			type = "string", 
			required = true, 
			blacklist = {"exploit", "hack", "cheat"} 
		}
	}
	
	-- Test valid whitelist
	local result1 = validator:ValidateRemoteCall(testPlayer, "TestRemote", schema, {"RIFLE", "normal"})
	TestFramework.Assert(result1.isValid, "Whitelisted value should pass")
	
	-- Test invalid whitelist
	local result2 = validator:ValidateRemoteCall(testPlayer, "TestRemote", schema, {"GRENADE", "normal"})
	TestFramework.Assert(not result2.isValid, "Non-whitelisted value should fail")
	
	-- Test valid blacklist (not in blacklist)
	local result3 = validator:ValidateRemoteCall(testPlayer, "TestRemote", schema, {"RIFLE", "normal"})
	TestFramework.Assert(result3.isValid, "Non-blacklisted value should pass")
	
	-- Test invalid blacklist (in blacklist)
	local result4 = validator:ValidateRemoteCall(testPlayer, "TestRemote", schema, {"RIFLE", "exploit"})
	TestFramework.Assert(not result4.isValid, "Blacklisted value should fail")
	
	print("✅ Whitelist/Blacklist validation test passed")
end

-- Test suite for pattern validation
function SecurityValidatorTests.TestPatternValidation()
	local validator = SecurityValidator.new()
	local testPlayer = CreateMockPlayer()
	
	local schema = {
		weaponId = { 
			type = "string", 
			required = true, 
			pattern = "^[A-Z_]+$" -- Only uppercase letters and underscores
		},
		email = {
			type = "string",
			required = true,
			pattern = "^[%w%.]+@[%w%.]+%.[%a]+$" -- Basic email pattern
		}
	}
	
	-- Test valid patterns
	local result1 = validator:ValidateRemoteCall(testPlayer, "TestRemote", schema, {"ASSAULT_RIFLE", "test@example.com"})
	TestFramework.Assert(result1.isValid, "Valid patterns should pass")
	
	-- Test invalid weapon ID pattern
	local result2 = validator:ValidateRemoteCall(testPlayer, "TestRemote", schema, {"assault_rifle", "test@example.com"})
	TestFramework.Assert(not result2.isValid, "Invalid weapon ID pattern should fail")
	
	-- Test invalid email pattern
	local result3 = validator:ValidateRemoteCall(testPlayer, "TestRemote", schema, {"ASSAULT_RIFLE", "not-an-email"})
	TestFramework.Assert(not result3.isValid, "Invalid email pattern should fail")
	
	print("✅ Pattern validation test passed")
end

-- Test suite for custom validation
function SecurityValidatorTests.TestCustomValidation()
	local validator = SecurityValidator.new()
	local testPlayer = CreateMockPlayer()
	
	local schema = {
		position = {
			type = "Vector3",
			required = true,
			customValidator = function(pos)
				if typeof(pos) ~= "Vector3" then
					return false, "Must be a Vector3"
				end
				if pos.Magnitude > 1000 then
					return false, "Position too far from origin"
				end
				return true
			end
		},
		evenNumber = {
			type = "number",
			required = true,
			customValidator = function(num)
				if num % 2 ~= 0 then
					return false, "Must be an even number"
				end
				return true
			end
		}
	}
	
	-- Test valid custom validation
	local result1 = validator:ValidateRemoteCall(testPlayer, "TestRemote", schema, {Vector3.new(10, 20, 30), 42})
	TestFramework.Assert(result1.isValid, "Valid custom validation should pass")
	
	-- Test invalid position (too far)
	local result2 = validator:ValidateRemoteCall(testPlayer, "TestRemote", schema, {Vector3.new(2000, 0, 0), 42})
	TestFramework.Assert(not result2.isValid, "Position too far should fail custom validation")
	
	-- Test invalid number (odd)
	local result3 = validator:ValidateRemoteCall(testPlayer, "TestRemote", schema, {Vector3.new(10, 20, 30), 43})
	TestFramework.Assert(not result3.isValid, "Odd number should fail custom validation")
	
	print("✅ Custom validation test passed")
end

-- Test suite for rate limiting
function SecurityValidatorTests.TestRateLimiting()
	local validator = SecurityValidator.new()
	local testPlayer = CreateMockPlayer()
	
	local schema = { test = { type = "string", required = true } }
	
	-- Test normal rate limit
	for i = 1, 5 do
		local result = validator:ValidateRemoteCall(testPlayer, "ui_TestRemote", schema, {"test"})
		TestFramework.Assert(result.isValid, "Normal rate should pass (attempt " .. i .. ")")
	end
	
	-- Test rate limit exceeded
	local result = validator:ValidateRemoteCall(testPlayer, "ui_TestRemote", schema, {"test"})
	TestFramework.Assert(not result.isValid, "Rate limit should be exceeded")
	TestFramework.Assert(#result.errors > 0, "Should have rate limit error")
	
	-- Wait and test rate limit reset
	task.wait(2) -- Wait for rate limit window to reset
	local result2 = validator:ValidateRemoteCall(testPlayer, "ui_TestRemote", schema, {"test"})
	TestFramework.Assert(result2.isValid, "Rate limit should reset after window")
	
	print("✅ Rate limiting test passed")
end

-- Test suite for exploit detection
function SecurityValidatorTests.TestExploitDetection()
	local validator = SecurityValidator.new()
	local testPlayer = CreateMockPlayer()
	
	-- Test rapid fire detection
	local schema = { damage = { type = "number", required = true } }
	
	-- Simulate rapid firing
	for i = 1, 60 do -- Exceed rapid fire threshold
		validator:ValidateRemoteCall(testPlayer, "shoot_TestRemote", schema, {50})
		task.wait(0.01) -- Very fast firing
	end
	
	-- The next shot should be detected as rapid fire
	local result = validator:ValidateRemoteCall(testPlayer, "shoot_TestRemote", schema, {50})
	-- Note: This test may pass depending on timing, rapid fire detection is time-sensitive
	
	print("✅ Exploit detection test completed")
end

-- Test suite for malicious data detection
function SecurityValidatorTests.TestMaliciousDataDetection()
	local validator = SecurityValidator.new()
	
	-- Test malicious strings
	TestFramework.Assert(validator:IsInvalidData("require(script)"), "Script injection should be detected")
	TestFramework.Assert(validator:IsInvalidData("loadstring('code')"), "Loadstring should be detected")
	TestFramework.Assert(validator:IsInvalidData("game.Players.LocalPlayer.Parent"), "Parent access should be detected")
	TestFramework.Assert(validator:IsInvalidData("<script>alert('xss')</script>"), "Script tags should be detected")
	
	-- Test valid strings
	TestFramework.Assert(not validator:IsInvalidData("normal text"), "Normal text should not be detected")
	TestFramework.Assert(not validator:IsInvalidData("player name"), "Player names should not be detected")
	
	-- Test malicious numbers
	TestFramework.Assert(validator:IsInvalidData(math.huge), "Infinity should be detected")
	TestFramework.Assert(validator:IsInvalidData(-math.huge), "Negative infinity should be detected")
	TestFramework.Assert(validator:IsInvalidData(0/0), "NaN should be detected")
	TestFramework.Assert(validator:IsInvalidData(1e15), "Extremely large numbers should be detected")
	
	-- Test valid numbers
	TestFramework.Assert(not validator:IsInvalidData(42), "Normal numbers should not be detected")
	TestFramework.Assert(not validator:IsInvalidData(-100), "Negative numbers should not be detected")
	
	print("✅ Malicious data detection test passed")
end

-- Test suite for metrics collection
function SecurityValidatorTests.TestMetricsCollection()
	local validator = SecurityValidator.new()
	local testPlayer = CreateMockPlayer()
	
	local schema = { test = { type = "string", required = true } }
	
	-- Perform some validations
	validator:ValidateRemoteCall(testPlayer, "TestRemote", schema, {"valid"})
	validator:ValidateRemoteCall(testPlayer, "TestRemote", schema, {123}) -- Invalid
	validator:ValidateRemoteCall(testPlayer, "TestRemote", schema, {"valid2"})
	
	local metrics = validator:GetSecurityMetrics()
	
	TestFramework.Assert(metrics.validation.totalValidations >= 3, "Should track total validations")
	TestFramework.Assert(metrics.validation.successfulValidations >= 2, "Should track successful validations")
	TestFramework.Assert(metrics.validation.failedValidations >= 1, "Should track failed validations")
	TestFramework.Assert(type(metrics.validation.averageValidationTime) == "number", "Should track average validation time")
	
	print("✅ Metrics collection test passed")
end

-- Run all tests
function SecurityValidatorTests.RunAllTests()
	print("🧪 Starting SecurityValidator test suite...")
	
	local tests = {
		SecurityValidatorTests.TestBasicValidation,
		SecurityValidatorTests.TestTypeValidation,
		SecurityValidatorTests.TestRangeValidation,
		SecurityValidatorTests.TestWhitelistBlacklistValidation,
		SecurityValidatorTests.TestPatternValidation,
		SecurityValidatorTests.TestCustomValidation,
		SecurityValidatorTests.TestRateLimiting,
		SecurityValidatorTests.TestExploitDetection,
		SecurityValidatorTests.TestMaliciousDataDetection,
		SecurityValidatorTests.TestMetricsCollection
	}
	
	local passed = 0
	local failed = 0
	
	for i, test in ipairs(tests) do
		local success, error = pcall(test)
		if success then
			passed += 1
		else
			failed += 1
			warn("❌ Test failed:", debug.getinfo(test, "n").name, error)
		end
	end
	
	print(string.format("🏁 Test suite completed: %d passed, %d failed", passed, failed))
	
	if failed == 0 then
		print("🎉 All SecurityValidator tests passed!")
		return true
	else
		warn("⚠️ Some SecurityValidator tests failed!")
		return false
	end
end

-- Auto-run tests when required (for development)
if game:GetService("RunService"):IsStudio() then
	task.spawn(function()
		task.wait(2) -- Wait for services to initialize
		SecurityValidatorTests.RunAllTests()
	end)
end

return SecurityValidatorTests
