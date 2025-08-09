-- WeaponConfig.lua
-- Enterprise weapon configuration with advanced balance metrics

local WeaponConfig = {
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

-- Balance validation for enterprise competitive play
function WeaponConfig.ValidateBalance()
	local warnings = {}
	
	for weaponId, config in pairs(WeaponConfig) do
		if type(config) == "table" and config.Id then
			-- TTK (Time To Kill) validation
			local damage = config.Damage * (config.PelletCount or 1)
			local ttk = 100 / (damage * config.FireRate) -- Seconds to kill 100 HP
			
			if ttk < 0.3 then
				table.insert(warnings, weaponId .. " has extremely low TTK: " .. ttk .. "s")
			elseif ttk > 3.0 then
				table.insert(warnings, weaponId .. " has very high TTK: " .. ttk .. "s")
			end
			
			-- Range validation
			if config.Range > 1000 then
				table.insert(warnings, weaponId .. " has excessive range: " .. config.Range)
			end
			
			-- Fire rate sanity check
			if config.FireRate > 20 then
				table.insert(warnings, weaponId .. " has extreme fire rate: " .. config.FireRate)
			end
		end
	end
	
	return warnings
end

-- Get weapon effectiveness at range
function WeaponConfig.GetEffectivenessAtRange(weaponId, distance)
	local weapon = WeaponConfig[weaponId]
	if not weapon then return 1 end
	
	if distance <= weapon.FalloffStart then
		return 1.0
	elseif distance >= weapon.FalloffEnd then
		return 0.5
	else
		-- Linear falloff between start and end
		local falloffProgress = (distance - weapon.FalloffStart) / (weapon.FalloffEnd - weapon.FalloffStart)
		return 1.0 - (falloffProgress * 0.5)
	end
end

-- Calculate damage with all modifiers
function WeaponConfig.CalculateDamage(weaponId, distance, isHeadshot, penetrationFactor)
	local weapon = WeaponConfig[weaponId]
	if not weapon then return 0 end
	
	local baseDamage = weapon.Damage * (weapon.PelletCount or 1)
	local rangeFactor = WeaponConfig.GetEffectivenessAtRange(weaponId, distance)
	local headshotFactor = isHeadshot and weapon.HeadshotMultiplier or 1.0
	local penetrationFactor = penetrationFactor or 1.0
	
	return math.floor(baseDamage * rangeFactor * headshotFactor * penetrationFactor)
end

return WeaponConfig
