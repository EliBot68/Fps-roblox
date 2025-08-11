--!strict
--[[
	WeaponConfigTest.server.lua
	Comprehensive test suite for WeaponConfig system
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Import test dependencies
local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)
local CombatTypes = require(ReplicatedStorage.Shared.CombatTypes)
local Logger = require(ReplicatedStorage.Shared.Logger)

local logger = Logger.new("WeaponConfigTest")

local WeaponConfigTest = {}

-- Test results tracking
local testResults = {
	passed = 0,
	failed = 0,
	errors = {}
}

-- Test utility functions
local function assertEquals(expected: any, actual: any, message: string)
	if expected == actual then
		testResults.passed += 1
		logger:debug("✅ PASS: " .. message)
	else
		testResults.failed += 1
		local error = string.format("❌ FAIL: %s (Expected: %s, Got: %s)", message, tostring(expected), tostring(actual))
		table.insert(testResults.errors, error)
		logger:error(error)
	end
end

local function assertNotNil(value: any, message: string)
	if value ~= nil then
		testResults.passed += 1
		logger:debug("✅ PASS: " .. message)
	else
		testResults.failed += 1
		local error = "❌ FAIL: " .. message .. " (Got nil)"
		table.insert(testResults.errors, error)
		logger:error(error)
	end
end

local function assertTrue(condition: boolean, message: string)
	if condition then
		testResults.passed += 1
		logger:debug("✅ PASS: " .. message)
	else
		testResults.failed += 1
		local error = "❌ FAIL: " .. message
		table.insert(testResults.errors, error)
		logger:error(error)
	end
end

-- Test weapon configuration retrieval
function WeaponConfigTest.TestWeaponRetrieval()
	logger:info("Testing weapon configuration retrieval...")
	
	-- Test getting existing weapon
	local ak47 = WeaponConfig.GetWeaponConfig("AK47")
	assertNotNil(ak47, "AK47 config should exist")
	
	if ak47 then
		assertEquals("AK47", ak47.id, "AK47 ID should match")
		assertEquals("AssaultRifle", ak47.category, "AK47 should be AssaultRifle category")
		assertTrue(ak47.stats.damage > 0, "AK47 damage should be positive")
		assertTrue(ak47.stats.fireRate > 0, "AK47 fire rate should be positive")
		assertTrue(ak47.stats.headDamage > ak47.stats.damage, "Head damage should be higher than body damage")
		assertNotNil(ak47.stats.headshotMultiplier, "Headshot multiplier should be derived")
	end
	
	-- Test getting non-existent weapon
	local nonExistent = WeaponConfig.GetWeaponConfig("NONEXISTENT")
	assertEquals(nil, nonExistent, "Non-existent weapon should return nil")
end

-- Test normalization system
function WeaponConfigTest.TestNormalization()
	logger:info("Testing weapon normalization...")
	
	-- Test weapons with different schema formats
	local weapons = WeaponConfig.GetAllWeapons()
	assertNotNil(weapons, "Should get all weapons")
	
	for weaponId, weapon in pairs(weapons) do
		-- Test all weapons have required normalized fields
		assertNotNil(weapon.stats.damage, weaponId .. " should have damage")
		assertNotNil(weapon.stats.headDamage, weaponId .. " should have head damage")
		assertNotNil(weapon.stats.headshotMultiplier, weaponId .. " should have headshot multiplier")
		assertNotNil(weapon.stats.muzzleVelocity, weaponId .. " should have muzzle velocity")
		assertNotNil(weapon.stats.dropoff, weaponId .. " should have dropoff array")
		assertNotNil(weapon.stats.damageDropoff, weaponId .. " should have legacy dropoff map")
		
		-- Test dropoff ordering
		local dropoff = weapon.stats.dropoff
		for i = 2, #dropoff do
			assertTrue(dropoff[i].distance > dropoff[i-1].distance, 
				weaponId .. " dropoff should be in ascending order")
		end
		
		-- Test headshot multiplier calculation
		local expectedMultiplier = weapon.stats.headDamage / weapon.stats.damage
		local actualMultiplier = weapon.stats.headshotMultiplier
		assertTrue(math.abs(expectedMultiplier - actualMultiplier) < 0.01,
			weaponId .. " headshot multiplier should match headDamage/damage ratio")
	end
end

-- Test cache functionality
function WeaponConfigTest.TestCache()
	logger:info("Testing cache functionality...")
	
	-- Get weapon multiple times to test caching
	local weapon1 = WeaponConfig.GetWeaponConfig("AK47")
	local weapon2 = WeaponConfig.GetWeaponConfig("AK47")
	
	-- Should be same reference due to caching
	assertEquals(weapon1, weapon2, "Cached weapon should return same reference")
	
	-- Test cache invalidation
	WeaponConfig.RefreshCache("AK47")
	local weapon3 = WeaponConfig.GetWeaponConfig("AK47")
	
	-- Should be new reference after cache clear
	assertTrue(weapon1 ~= weapon3, "Cache refresh should create new reference")
	
	-- Test full cache clear
	WeaponConfig.RefreshCache()
	local weapon4 = WeaponConfig.GetWeaponConfig("AK47")
	assertTrue(weapon3 ~= weapon4, "Full cache refresh should create new reference")
end

-- Test damage calculations
function WeaponConfigTest.TestDamageCalculations()
	logger:info("Testing damage calculations...")
	
	local weaponId = "AK47"
	
	-- Test damage at different distances
	local closeDamage = WeaponConfig.CalculateDamageAtDistance(weaponId, 10, false)
	local mediumDamage = WeaponConfig.CalculateDamageAtDistance(weaponId, 150, false)
	local farDamage = WeaponConfig.CalculateDamageAtDistance(weaponId, 300, false)
	
	assertTrue(closeDamage > 0, "Close damage should be positive")
	assertTrue(mediumDamage > 0, "Medium damage should be positive")
	assertTrue(farDamage > 0, "Far damage should be positive")
	assertTrue(closeDamage >= mediumDamage, "Close damage should be >= medium damage")
	assertTrue(mediumDamage >= farDamage, "Medium damage should be >= far damage")
	
	-- Test headshot damage
	local bodyDamage = WeaponConfig.CalculateDamageAtDistance(weaponId, 50, false)
	local headDamage = WeaponConfig.CalculateDamageAtDistance(weaponId, 50, true)
	assertTrue(headDamage > bodyDamage, "Headshot damage should be higher than body damage")
	
	-- Test BTK calculations
	local btk = WeaponConfig.CalculateBTK(weaponId, 50, 0)
	assertTrue(btk.head <= btk.body, "Head BTK should be <= body BTK")
	assertTrue(btk.body > 0, "Body BTK should be positive")
	assertTrue(btk.head > 0, "Head BTK should be positive")
	
	-- Test TTK calculations
	local ttk = WeaponConfig.CalculateTTK(weaponId, 50, 0)
	assertTrue(ttk >= 0, "TTK should be non-negative")
end

-- Test TTK precomputation
function WeaponConfigTest.TestTTKPrecomputation()
	logger:info("Testing TTK precomputation...")
	
	-- Test precomputation
	WeaponConfig.PrecomputeTTKTables()
	
	-- Test getting precomputed values
	local precomputedTTK = WeaponConfig.GetPrecomputedTTK("AK47", 100, 0)
	assertNotNil(precomputedTTK, "Should get precomputed TTK")
	
	-- Compare with calculated TTK
	local calculatedTTK = WeaponConfig.CalculateTTK("AK47", 100, 0)
	assertTrue(math.abs(precomputedTTK - calculatedTTK) < 0.01, 
		"Precomputed TTK should match calculated TTK")
end

-- Test validation system
function WeaponConfigTest.TestValidation()
	logger:info("Testing validation system...")
	
	local results = WeaponConfig.ValidateAllConfigs()
	assertNotNil(results, "Should get validation results")
	assertTrue(results.totalWeapons > 0, "Should have weapons to validate")
	assertTrue(results.validWeapons >= 0, "Valid weapons count should be non-negative")
	
	logger:info("Validation results", {
		totalWeapons = results.totalWeapons,
		validWeapons = results.validWeapons,
		invalidWeapons = #results.issues
	})
	
	-- Log any validation issues
	if #results.issues > 0 then
		logger:warn("Found weapon configuration issues:")
		for _, issue in ipairs(results.issues) do
			logger:warn("Weapon " .. issue.weaponId .. " issues:", issue.problems)
		end
	end
end

-- Test iteration utility
function WeaponConfigTest.TestIteration()
	logger:info("Testing iteration utility...")
	
	local count = 0
	local categories = {}
	
	WeaponConfig.Iterate(function(weapon)
		count += 1
		categories[weapon.category] = (categories[weapon.category] or 0) + 1
		
		-- Validate each weapon during iteration
		assertNotNil(weapon.id, "Weapon should have ID")
		assertNotNil(weapon.name, "Weapon should have name")
		assertNotNil(weapon.category, "Weapon should have category")
	end)
	
	assertTrue(count > 0, "Should iterate over weapons")
	assertTrue(next(categories) ~= nil, "Should find weapon categories")
	
	logger:info("Iteration results", {
		weaponCount = count,
		categories = categories
	})
end

-- Test edge cases
function WeaponConfigTest.TestEdgeCases()
	logger:info("Testing edge cases...")
	
	-- Test invalid weapon IDs
	local invalidWeapon = WeaponConfig.GetWeaponConfig("")
	assertEquals(nil, invalidWeapon, "Empty weapon ID should return nil")
	
	-- Test zero distance damage
	local zeroDamage = WeaponConfig.CalculateDamageAtDistance("AK47", 0, false)
	assertTrue(zeroDamage > 0, "Zero distance damage should be positive")
	
	-- Test extreme distance damage
	local extremeDamage = WeaponConfig.CalculateDamageAtDistance("AK47", 10000, false)
	assertTrue(extremeDamage > 0, "Extreme distance should still have some damage")
	
	-- Test negative armor TTK
	local negativeTTK = WeaponConfig.CalculateTTK("AK47", 50, -50)
	assertTrue(negativeTTK >= 0, "Negative armor TTK should be non-negative")
end

-- Run all tests
function WeaponConfigTest.RunAllTests()
	logger:info("Starting WeaponConfig test suite...")
	
	-- Reset test results
	testResults = {passed = 0, failed = 0, errors = {}}
	
	-- Run test functions
	local tests = {
		WeaponConfigTest.TestWeaponRetrieval,
		WeaponConfigTest.TestNormalization,
		WeaponConfigTest.TestCache,
		WeaponConfigTest.TestDamageCalculations,
		WeaponConfigTest.TestTTKPrecomputation,
		WeaponConfigTest.TestValidation,
		WeaponConfigTest.TestIteration,
		WeaponConfigTest.TestEdgeCases
	}
	
	for _, testFunc in ipairs(tests) do
		local success, error = pcall(testFunc)
		if not success then
			testResults.failed += 1
			table.insert(testResults.errors, "❌ TEST ERROR: " .. tostring(error))
			logger:error("Test function failed:", error)
		end
	end
	
	-- Report results
	local totalTests = testResults.passed + testResults.failed
	local successRate = totalTests > 0 and (testResults.passed / totalTests * 100) or 0
	
	logger:info("WeaponConfig test suite completed", {
		totalTests = totalTests,
		passed = testResults.passed,
		failed = testResults.failed,
		successRate = string.format("%.1f%%", successRate)
	})
	
	if #testResults.errors > 0 then
		logger:error("Test failures:")
		for _, error in ipairs(testResults.errors) do
			logger:error(error)
		end
	end
	
	return testResults
end

-- Auto-run tests when script loads
task.wait(2) -- Wait for other systems to initialize
WeaponConfigTest.RunAllTests()

return WeaponConfigTest
