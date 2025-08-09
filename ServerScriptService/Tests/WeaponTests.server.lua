--[[
	WeaponTests.lua
	Unit tests for weapon system validation and balance
	
	Tests weapon configuration, damage calculation, and balance metrics
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestFramework = require(ReplicatedStorage.Shared.TestFramework)
local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)

-- Create weapon test suite
local WeaponTests = TestFramework.CreateSuite("WeaponSystem")

-- Test weapon data validation
TestFramework.AddTest("WeaponData_Validation", function()
	-- Test valid weapon
	local assaultRifle = WeaponConfig.GetWeapon("AssaultRifle")
	TestFramework.AssertNotNil(assaultRifle, "AssaultRifle should exist")
	TestFramework.AssertType(assaultRifle, "table", "Weapon should be a table")
	TestFramework.AssertEqual(assaultRifle.Id, "AssaultRifle", "Weapon ID should match")
	
	-- Test weapon validation
	local validation = WeaponConfig.ValidateWeapon(assaultRifle)
	TestFramework.Assert(validation.valid, "AssaultRifle should be valid")
	TestFramework.AssertEqual(#validation.issues, 0, "Should have no validation issues")
end)

-- Test damage calculation
TestFramework.AddTest("Damage_Calculation", function()
	-- Test damage at different ranges
	local closeRange = WeaponConfig.CalculateDamageAtRange("AssaultRifle", 50)
	local midRange = WeaponConfig.CalculateDamageAtRange("AssaultRifle", 200)
	local longRange = WeaponConfig.CalculateDamageAtRange("AssaultRifle", 350)
	
	TestFramework.AssertNotNil(closeRange, "Close range damage should be calculated")
	TestFramework.AssertNotNil(midRange, "Mid range damage should be calculated")
	TestFramework.AssertNotNil(longRange, "Long range damage should be calculated")
	
	-- Damage should decrease with range
	TestFramework.Assert(closeRange >= midRange, "Close range should deal more damage than mid range")
	TestFramework.Assert(midRange >= longRange, "Mid range should deal more damage than long range")
end)

-- Test weapon balance
TestFramework.AddTest("Weapon_Balance", function()
	local balanceResult = WeaponConfig.ValidateBalance()
	
	TestFramework.AssertType(balanceResult.totalWeapons, "number", "Total weapons should be a number")
	TestFramework.Assert(balanceResult.totalWeapons > 0, "Should have weapons configured")
	TestFramework.Assert(balanceResult.validWeapons > 0, "Should have valid weapons")
	
	-- Check for reasonable balance
	local stats = WeaponConfig.GetBalanceStats()
	TestFramework.Assert(stats.averageTTK > 0.3, "Average TTK should be reasonable (> 0.3s)")
	TestFramework.Assert(stats.averageTTK < 3.0, "Average TTK should be reasonable (< 3.0s)")
end)

-- Test weapon classes
TestFramework.AddTest("Weapon_Classes", function()
	local arWeapons = WeaponConfig.GetWeaponsByClass("AR")
	local smgWeapons = WeaponConfig.GetWeaponsByClass("SMG")
	
	TestFramework.Assert(#arWeapons > 0, "Should have AR weapons")
	TestFramework.Assert(#smgWeapons > 0, "Should have SMG weapons")
	
	-- Verify class properties
	for _, weapon in ipairs(arWeapons) do
		TestFramework.AssertEqual(weapon.Class, "AR", "AR weapon should have correct class")
	end
	
	for _, weapon in ipairs(smgWeapons) do
		TestFramework.AssertEqual(weapon.Class, "SMG", "SMG weapon should have correct class")
	end
end)

-- Test invalid weapon handling
TestFramework.AddTest("Invalid_Weapon_Handling", function()
	local invalidWeapon = WeaponConfig.GetWeapon("NonExistentWeapon")
	TestFramework.AssertNil(invalidWeapon, "Non-existent weapon should return nil")
	
	local invalidDamage = WeaponConfig.CalculateDamageAtRange("NonExistentWeapon", 100)
	TestFramework.AssertNil(invalidDamage, "Invalid weapon damage should return nil")
	
	local emptyClass = WeaponConfig.GetWeaponsByClass("NonExistentClass")
	TestFramework.AssertEqual(#emptyClass, 0, "Non-existent class should return empty table")
end)

-- Run weapon tests and return module
function WeaponTests.RunTests()
	return TestFramework.RunSuite("WeaponSystem")
end

return WeaponTests
