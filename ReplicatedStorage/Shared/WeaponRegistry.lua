-- WeaponRegistry.lua
-- Central registry for all weapons with dynamic loading capabilities

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeaponExpansion = require(ReplicatedStorage.Shared.WeaponExpansion)
local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)

local WeaponRegistry = {
	RegisteredWeapons = {},
	WeaponsByCategory = {},
	WeaponsByTier = {}
}

-- Initialize with existing weapons
function WeaponRegistry.Initialize()
	-- Register existing weapons from WeaponConfig
	for weaponId, weaponData in pairs(WeaponConfig) do
		if type(weaponData) == "table" and weaponData.Name then
			WeaponRegistry.RegisterWeapon(weaponId, weaponData)
		end
	end
end

-- Register a new weapon
function WeaponRegistry.RegisterWeapon(weaponId, weaponData)
	-- Validate weapon
	local issues = WeaponExpansion.ValidateWeapon(weaponData)
	if #issues > 0 then
		warn("Weapon validation failed for " .. weaponId .. ": " .. table.concat(issues, ", "))
		return false
	end
	
	-- Register weapon
	WeaponRegistry.RegisteredWeapons[weaponId] = weaponData
	
	-- Categorize weapon
	local category = weaponData.Category or "Primary"
	local class = weaponData.Class or "Unknown"
	
	if not WeaponRegistry.WeaponsByCategory[category] then
		WeaponRegistry.WeaponsByCategory[category] = {}
	end
	if not WeaponRegistry.WeaponsByCategory[category][class] then
		WeaponRegistry.WeaponsByCategory[category][class] = {}
	end
	
	table.insert(WeaponRegistry.WeaponsByCategory[category][class], weaponId)
	
	-- Tier organization
	local tier = weaponData.Tier or 1
	if not WeaponRegistry.WeaponsByTier[tier] then
		WeaponRegistry.WeaponsByTier[tier] = {}
	end
	table.insert(WeaponRegistry.WeaponsByTier[tier], weaponId)
	
	return true
end

-- Get weapon by ID
function WeaponRegistry.GetWeapon(weaponId)
	return WeaponRegistry.RegisteredWeapons[weaponId]
end

-- Get all weapons in category/class
function WeaponRegistry.GetWeaponsByCategory(category, class)
	if class then
		return WeaponRegistry.WeaponsByCategory[category] and WeaponRegistry.WeaponsByCategory[category][class] or {}
	else
		local weapons = {}
		if WeaponRegistry.WeaponsByCategory[category] then
			for _, classWeapons in pairs(WeaponRegistry.WeaponsByCategory[category]) do
				for _, weaponId in ipairs(classWeapons) do
					table.insert(weapons, weaponId)
				end
			end
		end
		return weapons
	end
end

-- Get weapons by tier
function WeaponRegistry.GetWeaponsByTier(tier)
	return WeaponRegistry.WeaponsByTier[tier] or {}
end

-- Get all registered weapons
function WeaponRegistry.GetAllWeapons()
	return WeaponRegistry.RegisteredWeapons
end

-- Search weapons by criteria
function WeaponRegistry.SearchWeapons(criteria)
	local results = {}
	
	for weaponId, weapon in pairs(WeaponRegistry.RegisteredWeapons) do
		local matches = true
		
		-- Check each criteria
		for key, value in pairs(criteria) do
			if key == "minDamage" then
				if weapon.Damage < value then matches = false break end
			elseif key == "maxDamage" then
				if weapon.Damage > value then matches = false break end
			elseif key == "category" then
				if weapon.Category ~= value then matches = false break end
			elseif key == "class" then
				if weapon.Class ~= value then matches = false break end
			elseif key == "tier" then
				if weapon.Tier ~= value then matches = false break end
			elseif key == "unlockLevel" then
				if weapon.UnlockLevel > value then matches = false break end
			elseif weapon[key] ~= value then
				matches = false
				break
			end
		end
		
		if matches then
			table.insert(results, weaponId)
		end
	end
	
	return results
end

-- Generate weapon statistics
function WeaponRegistry.GenerateStats()
	local stats = {
		totalWeapons = 0,
		byCategory = {},
		byTier = {},
		averageDamage = 0,
		averageFireRate = 0,
		averageTTK = 0
	}
	
	local totalDamage = 0
	local totalFireRate = 0
	local totalTTK = 0
	
	for weaponId, weapon in pairs(WeaponRegistry.RegisteredWeapons) do
		stats.totalWeapons = stats.totalWeapons + 1
		
		-- Category stats
		local category = weapon.Category or "Unknown"
		stats.byCategory[category] = (stats.byCategory[category] or 0) + 1
		
		-- Tier stats
		local tier = weapon.Tier or 1
		stats.byTier[tier] = (stats.byTier[tier] or 0) + 1
		
		-- Damage stats
		totalDamage = totalDamage + weapon.Damage
		totalFireRate = totalFireRate + weapon.FireRate
		
		-- TTK calculation
		local ttk = 100 / (weapon.Damage * weapon.FireRate)
		totalTTK = totalTTK + ttk
	end
	
	if stats.totalWeapons > 0 then
		stats.averageDamage = totalDamage / stats.totalWeapons
		stats.averageFireRate = totalFireRate / stats.totalWeapons
		stats.averageTTK = totalTTK / stats.totalWeapons
	end
	
	return stats
end

-- Initialize the registry
WeaponRegistry.Initialize()

return WeaponRegistry
