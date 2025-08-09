--[[
	WeaponConfig.lua
	Enterprise weapon configuration with advanced balance metrics and type safety
	
	Provides comprehensive weapon statistics with Luau type annotations
]]

-- Type definitions for weapon system
export type WeaponRecoil = {
	Vertical: number,
	Horizontal: number,
	Recovery: number
}

export type WeaponMobility = {
	WalkSpeed: number,
	AdsSpeed: number,
	SwapSpeed: number
}

export type WeaponEffectiveness = {
	Close: number,
	Medium: number,
	Long: number
}

export type WeaponData = {
	Id: string,
	Name: string,
	Damage: number,
	HeadshotMultiplier: number,
	FireRate: number,
	MagazineSize: number,
	ReloadTime: number,
	Range: number,
	FalloffStart: number,
	FalloffEnd: number,
	Spread: number,
	Recoil: WeaponRecoil,
	Mobility: WeaponMobility,
	Class: string,
	Cost: number,
	Tier: number,
	UnlockLevel: number,
	Penetration: number,
	Effectiveness: WeaponEffectiveness
}

export type WeaponRegistry = {
	[string]: WeaponData
}

local WeaponConfig: WeaponRegistry = {
	AssaultRifle = {
		Id = "AssaultRifle",
		Name = "M4A1 Carbine",
		Damage = 25,
		HeadshotMultiplier = 1.4,
		FireRate = 8.0, -- rounds per second
		MagazineSize = 30,
		ReloadTime = 2.2,
		Range = 300,
		FalloffStart = 150,
		FalloffEnd = 300,
		Spread = 2.5, -- degrees
		Recoil = {
			Vertical = 1.2,
			Horizontal = 0.8,
			Recovery = 0.15
		},
		Mobility = {
			WalkSpeed = 0.95,
			AdsSpeed = 0.4,
			SwapSpeed = 1.0
		},
		Class = "AR",
		Cost = 0,
		Tier = 1,
		UnlockLevel = 1,
		Penetration = 0.7,
		Effectiveness = {
			Close = 0.8,
			Medium = 1.0,
			Long = 0.9
		}
	},
	SMG = {
		Id = "SMG",
		Name = "MP5-K",
		Damage = 18,
		HeadshotMultiplier = 1.3,
		FireRate = 12.0,
		MagazineSize = 40,
		ReloadTime = 2.0,
		Range = 200,
		FalloffStart = 80,
		FalloffEnd = 200,
		Spread = 4.0,
		Recoil = {
			Vertical = 0.9,
			Horizontal = 1.2,
			Recovery = 0.2
		},
		Mobility = {
			WalkSpeed = 1.1,
			AdsSpeed = 0.6,
			SwapSpeed = 1.3
		},
		Class = "SMG",
		Cost = 500,
		Tier = 2,
		UnlockLevel = 5,
		Penetration = 0.4,
		Effectiveness = {
			Close = 1.2,
			Medium = 0.8,
			Long = 0.4
		}
	},
	Shotgun = {
		Id = "Shotgun",
		Name = "M870 Express",
		Damage = 12, -- per pellet
		PelletCount = 8,
		HeadshotMultiplier = 1.5,
		FireRate = 1.2,
		MagazineSize = 8,
		ReloadTime = 3.0,
		Range = 120,
		FalloffStart = 40,
		FalloffEnd = 120,
		Spread = 6.0,
		Recoil = {
			Vertical = 2.5,
			Horizontal = 1.0,
			Recovery = 0.4
		},
		Mobility = {
			WalkSpeed = 0.9,
			AdsSpeed = 0.3,
			SwapSpeed = 0.8
		},
		Class = "Shotgun",
		Cost = 800,
		Tier = 2,
		UnlockLevel = 8,
		Penetration = 0.2,
		Effectiveness = {
			Close = 1.5,
			Medium = 0.6,
			Long = 0.2
		}
	},
	Sniper = {
		Id = "Sniper",
		Name = "AWP-S",
		Damage = 80,
		HeadshotMultiplier = 2.0,
		FireRate = 0.8,
		MagazineSize = 5,
		ReloadTime = 2.8,
		Range = 800,
		FalloffStart = 400,
		FalloffEnd = 800,
		Spread = 0.5,
		Recoil = {
			Vertical = 3.2,
			Horizontal = 0.2,
			Recovery = 0.8
		},
		Mobility = {
			WalkSpeed = 0.7,
			AdsSpeed = 0.2,
			SwapSpeed = 0.6
		},
		Class = "Sniper",
		Cost = 1200,
		Tier = 3,
		UnlockLevel = 12,
		Penetration = 1.0,
		Effectiveness = {
			Close = 0.4,
			Medium = 0.8,
			Long = 1.3
		}
	},
	Pistol = {
		Id = "Pistol",
		Name = "Glock-18",
		Damage = 22,
		HeadshotMultiplier = 1.2,
		FireRate = 4.5,
		MagazineSize = 12,
		ReloadTime = 1.6,
		Range = 180,
		FalloffStart = 90,
		FalloffEnd = 180,
		Spread = 3.0,
		Recoil = {
			Vertical = 0.6,
			Horizontal = 0.4,
			Recovery = 0.1
		},
		Mobility = {
			WalkSpeed = 1.2,
			AdsSpeed = 0.8,
			SwapSpeed = 1.5
		},
		Class = "Pistol",
		Cost = 0,
		Tier = 1,
		UnlockLevel = 1,
		Penetration = 0.3,
		Effectiveness = {
			Close = 0.9,
			Medium = 0.7,
			Long = 0.3
		}
	},
	
	-- Advanced weapons for higher tiers
	BurstRifle = {
		Id = "BurstRifle",
		Name = "AN-94 Abakan",
		Damage = 28,
		HeadshotMultiplier = 1.5,
		FireRate = 3.0, -- bursts per second
		BurstCount = 3,
		BurstDelay = 0.08,
		MagazineSize = 30,
		ReloadTime = 2.5,
		Range = 350,
		FalloffStart = 180,
		FalloffEnd = 350,
		Spread = 1.8,
		Recoil = {
			Vertical = 1.5,
			Horizontal = 0.6,
			Recovery = 0.3
		},
		Mobility = {
			WalkSpeed = 0.9,
			AdsSpeed = 0.35,
			SwapSpeed = 0.9
		},
		Class = "AR",
		Cost = 1500,
		Tier = 3,
		UnlockLevel = 15,
		Penetration = 0.8,
		Effectiveness = {
			Close = 0.9,
			Medium = 1.1,
			Long = 1.0
		}
	},
}

-- Weapon categories for UI and progression
WeaponConfig.Categories = {
	Primary = { "AssaultRifle", "SMG", "Shotgun", "Sniper", "BurstRifle" },
	Secondary = { "Pistol" }
}

-- Tier system for progression
WeaponConfig.Tiers = {
	[1] = { weapons = { "AssaultRifle", "Pistol" }, name = "Recruit" },
	[2] = { weapons = { "SMG", "Shotgun" }, name = "Veteran" },
	[3] = { weapons = { "Sniper", "BurstRifle" }, name = "Elite" }
}

-- Type-safe utility functions for weapon management

-- Get weapon data with type safety
function WeaponConfig.GetWeapon(weaponId: string): WeaponData?
	local weapon = WeaponConfig[weaponId]
	if weapon and type(weapon) == "table" and weapon.Id then
		return weapon :: WeaponData
	end
	return nil
end

-- Get all weapons of a specific class
function WeaponConfig.GetWeaponsByClass(weaponClass: string): {WeaponData}
	local weapons: {WeaponData} = {}
	
	for _, weapon in pairs(WeaponConfig) do
		if type(weapon) == "table" and weapon.Class == weaponClass then
			table.insert(weapons, weapon :: WeaponData)
		end
	end
	
	return weapons
end

-- Calculate damage at specific range with type safety
function WeaponConfig.CalculateDamageAtRange(weaponId: string, range: number): number?
	local weapon = WeaponConfig.GetWeapon(weaponId)
	if not weapon then return nil end
	
	local baseDamage = weapon.Damage
	
	if range <= weapon.FalloffStart then
		return baseDamage
	elseif range >= weapon.FalloffEnd then
		return baseDamage * 0.5 -- 50% damage at max range
	else
		-- Linear interpolation between falloff points
		local falloffFactor = (range - weapon.FalloffStart) / (weapon.FalloffEnd - weapon.FalloffStart)
		return baseDamage * (1.0 - (falloffFactor * 0.5))
	end
end

-- Type-safe weapon validation with comprehensive metrics
function WeaponConfig.ValidateWeapon(weapon: WeaponData): {valid: boolean, issues: {string}}
	local issues: {string} = {}
	
	-- Required field validation
	if not weapon.Id or weapon.Id == "" then
		table.insert(issues, "Missing or empty weapon ID")
	end
	
	if not weapon.Name or weapon.Name == "" then
		table.insert(issues, "Missing or empty weapon name")
	end
	
	-- Numeric validation
	if weapon.Damage <= 0 then
		table.insert(issues, "Damage must be positive")
	end
	
	if weapon.FireRate <= 0 then
		table.insert(issues, "Fire rate must be positive")
	end
	
	if weapon.MagazineSize <= 0 then
		table.insert(issues, "Magazine size must be positive")
	end
	
	-- Balance validation
	local ttk = 100 / (weapon.Damage * weapon.FireRate)
	if ttk < 0.3 then
		table.insert(issues, "TTK too low (< 0.3s): " .. string.format("%.2f", ttk))
	elseif ttk > 3.0 then
		table.insert(issues, "TTK too high (> 3.0s): " .. string.format("%.2f", ttk))
	end
	
	return {
		valid = #issues == 0,
		issues = issues
	}
end

-- Balance validation for enterprise competitive play
function WeaponConfig.ValidateBalance(): {totalWeapons: number, validWeapons: number, issues: {{weaponId: string, problems: {string}}}}
	local issues: {{weaponId: string, problems: {string}}} = {}
	local validCount = 0
	local totalCount = 0
	
	for weaponId, config in pairs(WeaponConfig) do
		if type(config) == "table" and config.Id then
			totalCount = totalCount + 1
			local validation = WeaponConfig.ValidateWeapon(config :: WeaponData)
			
			if validation.valid then
				validCount = validCount + 1
			else
				table.insert(issues, {
					weaponId = weaponId,
					problems = validation.issues
				})
			end
		end
	end
	
	return {
		totalWeapons = totalCount,
		validWeapons = validCount,
		issues = issues
	}
end

-- Get weapon statistics for balancing
function WeaponConfig.GetBalanceStats(): {
	averageTTK: number,
	averageDPS: number,
	weaponsByTier: {[number]: number},
	classCoverage: {[string]: number}
}
	local totalTTK = 0
	local totalDPS = 0
	local weaponCount = 0
	local tierCounts: {[number]: number} = {}
	local classCounts: {[string]: number} = {}
	
	for _, config in pairs(WeaponConfig) do
		if type(config) == "table" and config.Id then
			local weapon = config :: WeaponData
			weaponCount = weaponCount + 1
			
			-- Calculate TTK and DPS
			local ttk = 100 / (weapon.Damage * weapon.FireRate)
			local dps = weapon.Damage * weapon.FireRate
			
			totalTTK = totalTTK + ttk
			totalDPS = totalDPS + dps
			
			-- Count by tier
			tierCounts[weapon.Tier] = (tierCounts[weapon.Tier] or 0) + 1
			
			-- Count by class
			classCounts[weapon.Class] = (classCounts[weapon.Class] or 0) + 1
		end
	end
	
	return {
		averageTTK = weaponCount > 0 and (totalTTK / weaponCount) or 0,
		averageDPS = weaponCount > 0 and (totalDPS / weaponCount) or 0,
		weaponsByTier = tierCounts,
		classCoverage = classCounts
	}
end

return WeaponConfig
