--!strict
--[[
	WeaponConfig.lua
	Central weapon configuration and stats
]]

local WeaponConfig = {}

-- Import unified types from CombatTypes
local CombatTypes = require(script.Parent.CombatTypes)
type WeaponStats = CombatTypes.WeaponConfig -- Use the comprehensive WeaponConfig type

-- Weapon configurations
local WEAPON_CONFIGS: {[string]: WeaponStats} = {
	-- Assault Rifles
	["AK47"] = {
		id = "AK47",
		name = "AK-47",
		displayName = "AK-47 Assault Rifle",
		description = "Reliable assault rifle with moderate recoil",
		category = "AssaultRifle",
		rarity = "Common",
		stats = {
			damage = 34,
			headshotMultiplier = 3.0,
			fireRate = 600, -- rounds per minute
			reloadTime = 2.5,
			magazineSize = 30,
			maxAmmo = 120,
			range = 300,
			accuracy = 0.75,
			recoilPattern = {
				Vector3.new(0, 2, 0),    -- Shot 1
				Vector3.new(-1, 3, 0),   -- Shot 2
				Vector3.new(1, 4, 0),    -- Shot 3
				Vector3.new(-2, 5, 0),   -- Shot 4
				Vector3.new(2, 6, 0),    -- Shot 5
				Vector3.new(-3, 7, 0),   -- Shot 6
				Vector3.new(3, 8, 0),    -- Shot 7
				Vector3.new(-2, 9, 0),   -- Shot 8
				Vector3.new(1, 10, 0),   -- Shot 9
				Vector3.new(-1, 11, 0),  -- Shot 10
			},
			damageDropoff = {
				[50] = 1.0,
				[150] = 0.85,
				[300] = 0.6
			},
			penetration = 0.7,
			muzzleVelocity = 715,
			weight = 3.5
		},
		attachmentSlots = {
			Scope = true,
			Barrel = true,
			Grip = true,
			Magazine = true,
			Stock = true
		},
		unlockLevel = 1,
		cost = 2700,
		modelId = "rbxassetid://0",
		iconId = "rbxassetid://0",
		sounds = {
			fire = "rbxassetid://1585183374",
			dryFire = "rbxassetid://131961136",
			reload = "rbxassetid://200289883",
			reloadEmpty = "rbxassetid://200289883",
			draw = "rbxassetid://131961136",
			holster = "rbxassetid://131961136",
			hit = "rbxassetid://131961136",
			miss = "rbxassetid://131961136"
		},
		animations = {
			idle = "rbxassetid://0",
			fire = "rbxassetid://0",
			reload = "rbxassetid://0",
			reloadEmpty = "rbxassetid://0",
			draw = "rbxassetid://0",
			holster = "rbxassetid://0",
			inspect = "rbxassetid://0",
			melee = "rbxassetid://0"
		},
		effects = {
			muzzleFlash = "rbxassetid://5069424304",
			shellEject = "rbxassetid://0",
			bulletTrail = "rbxassetid://0",
			impactEffects = {
				Concrete = "rbxassetid://0",
				Metal = "rbxassetid://0",
				Wood = "rbxassetid://0"
			},
			smokePuff = "rbxassetid://0"
		}
	},
	
	["M4A1"] = {
		id = "M4A1",
		name = "M4A1-S",
		category = "AssaultRifle",
		stats = {
			damage = 33,
			headDamage = 99,
			range = 350,
			accuracy = 0.82,
			fireRate = 666,
			magazineSize = 25,
			maxAmmo = 100,
			reloadTime = 3.1,
			recoilPattern = {
				Vector3.new(0, 1.5, 0),
				Vector3.new(-0.5, 2.5, 0),
				Vector3.new(0.5, 3.5, 0),
				Vector3.new(-1, 4.5, 0),
				Vector3.new(1.5, 5.5, 0),
				Vector3.new(-2, 6.5, 0),
				Vector3.new(2.5, 7.5, 0),
				Vector3.new(-1.5, 8.5, 0),
				Vector3.new(1, 9.5, 0),
				Vector3.new(-0.5, 10.5, 0),
			},
			penetration = 2,
			velocity = 880,
			dropoff = {
				{distance = 50, damageMultiplier = 1.0},
				{distance = 200, damageMultiplier = 0.9},
				{distance = 350, damageMultiplier = 0.7}
			}
		},
		attachmentSlots = {
			optic = true,
			barrel = true,
			grip = true,
			magazine = true,
			stock = true
		},
		economy = {
			cost = 3100,
			unlockLevel = 5,
			rarity = "Common"
		},
		model = "rbxassetid://0",
		sounds = {
			fire = "rbxassetid://0",
			reload = "rbxassetid://0",
			empty = "rbxassetid://0",
			inspect = "rbxassetid://0"
		},
		animations = {
			idle = "rbxassetid://0",
			fire = "rbxassetid://0",
			reload = "rbxassetid://0",
			inspect = "rbxassetid://0",
			draw = "rbxassetid://0"
		},
		effects = {
			muzzleFlash = "rbxassetid://0",
			ejectionPort = Vector3.new(0, 0, 0),
			shellCasing = "rbxassetid://0",
			hitEffects = {
				Flesh = "rbxassetid://0",
				Metal = "rbxassetid://0",
				Wood = "rbxassetid://0"
			},
			smokePuff = "rbxassetid://0"
		}
	},
	
	-- Sniper Rifles
	["AWP"] = {
		id = "AWP",
		name = "AWP",
		category = "SniperRifle",
		stats = {
			damage = 115,
			headDamage = 460,
			range = 1000,
			accuracy = 0.95,
			fireRate = 41,
			magazineSize = 10,
			maxAmmo = 30,
			reloadTime = 3.7,
			recoilPattern = {
				Vector3.new(0, 15, 0), -- High recoil single shot
			},
			penetration = 5,
			velocity = 2500,
			dropoff = {
				{distance = 100, damageMultiplier = 1.0},
				{distance = 500, damageMultiplier = 0.95},
				{distance = 1000, damageMultiplier = 0.85}
			}
		},
		attachmentSlots = {
			optic = true,
			barrel = true,
			grip = false,
			magazine = true,
			stock = true
		},
		economy = {
			cost = 4750,
			unlockLevel = 15,
			rarity = "Legendary"
		},
		model = "rbxassetid://0",
		sounds = {
			fire = "rbxassetid://0",
			reload = "rbxassetid://0",
			empty = "rbxassetid://0",
			inspect = "rbxassetid://0"
		},
		animations = {
			idle = "rbxassetid://0",
			fire = "rbxassetid://0",
			reload = "rbxassetid://0",
			inspect = "rbxassetid://0",
			draw = "rbxassetid://0"
		},
		effects = {
			muzzleFlash = "rbxassetid://0",
			ejectionPort = Vector3.new(0, 0, 0),
			shellCasing = "rbxassetid://0",
			hitEffects = {
				Flesh = "rbxassetid://0",
				Metal = "rbxassetid://0",
				Wood = "rbxassetid://0"
			},
			smokePuff = "rbxassetid://0"
		}
	},
	
	["GLOCK17"] = {
		id = "GLOCK17",
		name = "Glock-18",
		displayName = "Glock-18 Pistol",
		description = "Reliable sidearm with good capacity",
		category = "Pistol",
		rarity = "Common",
		stats = {
			damage = 28,
			headshotMultiplier = 4.0,
			fireRate = 400,
			reloadTime = 2.2,
			magazineSize = 20,
			maxAmmo = 120,
			range = 100,
			accuracy = 0.68,
			recoilPattern = {
				Vector3.new(0, 3, 0),
				Vector3.new(-1, 4, 0),
				Vector3.new(1, 5, 0),
				Vector3.new(-1.5, 6, 0),
				Vector3.new(1.5, 7, 0),
			},
			damageDropoff = {
				[25] = 1.0,
				[50] = 0.8,
				[100] = 0.5
			},
			penetration = 0.3,
			muzzleVelocity = 375,
			weight = 0.8
		},
		attachmentSlots = {
			Scope = false,
			Barrel = true,
			Grip = false,
			Magazine = true,
			Stock = false
		},
		unlockLevel = 1,
		cost = 200,
		modelId = "rbxassetid://0",
		iconId = "rbxassetid://0",
		sounds = {
			fire = "rbxassetid://8817903681",
			dryFire = "rbxassetid://131961136",
			reload = "rbxassetid://5801855104",
			reloadEmpty = "rbxassetid://5801855104",
			draw = "rbxassetid://131961136",
			holster = "rbxassetid://131961136",
			hit = "rbxassetid://131961136",
			miss = "rbxassetid://131961136"
		},
		animations = {
			idle = "rbxassetid://0",
			fire = "rbxassetid://0",
			reload = "rbxassetid://0",
			reloadEmpty = "rbxassetid://0",
			draw = "rbxassetid://0",
			holster = "rbxassetid://0",
			inspect = "rbxassetid://0",
			melee = "rbxassetid://0"
		},
		effects = {
			muzzleFlash = "rbxassetid://5069424304",
			shellEject = "rbxassetid://0",
			bulletTrail = "rbxassetid://0",
			impactEffects = {
				Concrete = "rbxassetid://0",
				Metal = "rbxassetid://0",
				Wood = "rbxassetid://0"
			},
			smokePuff = "rbxassetid://0"
		}
	},
	
	["DEAGLE"] = {
		id = "DEAGLE",
		name = "Desert Eagle",
		category = "Pistol",
		stats = {
			damage = 63,
			headDamage = 252,
			range = 150,
			accuracy = 0.78,
			fireRate = 267,
			magazineSize = 7,
			maxAmmo = 35,
			reloadTime = 2.2,
			recoilPattern = {
				Vector3.new(0, 8, 0),
				Vector3.new(-2, 10, 0),
				Vector3.new(2, 12, 0),
				Vector3.new(-3, 14, 0),
				Vector3.new(3, 16, 0),
			},
			penetration = 2,
			velocity = 250,
			dropoff = {
				{distance = 30, damageMultiplier = 1.0},
				{distance = 75, damageMultiplier = 0.85},
				{distance = 150, damageMultiplier = 0.6}
			}
		},
		attachmentSlots = {
			optic = true,
			barrel = true,
			grip = false,
			magazine = true,
			stock = false
		},
		economy = {
			cost = 700,
			unlockLevel = 10,
			rarity = "Rare"
		},
		model = "rbxassetid://0",
		sounds = {
			fire = "rbxassetid://0",
			reload = "rbxassetid://0",
			empty = "rbxassetid://0",
			inspect = "rbxassetid://0"
		},
		animations = {
			idle = "rbxassetid://0",
			fire = "rbxassetid://0",
			reload = "rbxassetid://0",
			inspect = "rbxassetid://0",
			draw = "rbxassetid://0"
		},
		effects = {
			muzzleFlash = "rbxassetid://0",
			ejectionPort = Vector3.new(0, 0, 0),
			shellCasing = "rbxassetid://0",
			hitEffects = {
				Flesh = "rbxassetid://0",
				Metal = "rbxassetid://0",
				Wood = "rbxassetid://0"
			},
			smokePuff = "rbxassetid://0"
		}
	},
	
	-- SMGs
	["MP5"] = {
		id = "MP5",
		name = "MP5-SD",
		category = "SMG",
		stats = {
			damage = 26,
			headDamage = 104,
			range = 150,
			accuracy = 0.71,
			fireRate = 750,
			magazineSize = 30,
			maxAmmo = 120,
			reloadTime = 2.6,
			recoilPattern = {
				Vector3.new(0, 1, 0),
				Vector3.new(-0.5, 1.5, 0),
				Vector3.new(0.5, 2, 0),
				Vector3.new(-1, 2.5, 0),
				Vector3.new(1, 3, 0),
				Vector3.new(-1.5, 3.5, 0),
				Vector3.new(1.5, 4, 0),
				Vector3.new(-1, 4.5, 0),
				Vector3.new(0.5, 5, 0),
				Vector3.new(-0.5, 5.5, 0),
			},
			penetration = 1,
			velocity = 400,
			dropoff = {
				{distance = 25, damageMultiplier = 1.0},
				{distance = 75, damageMultiplier = 0.8},
				{distance = 150, damageMultiplier = 0.6}
			}
		},
		attachmentSlots = {
			optic = true,
			barrel = true,
			grip = true,
			magazine = true,
			stock = true
		},
		economy = {
			cost = 1500,
			unlockLevel = 3,
			rarity = "Common"
		},
		model = "rbxassetid://0",
		sounds = {
			fire = "rbxassetid://0",
			reload = "rbxassetid://0",
			empty = "rbxassetid://0",
			inspect = "rbxassetid://0"
		},
		animations = {
			idle = "rbxassetid://0",
			fire = "rbxassetid://0",
			reload = "rbxassetid://0",
			inspect = "rbxassetid://0",
			draw = "rbxassetid://0"
		},
		effects = {
			muzzleFlash = "rbxassetid://0",
			ejectionPort = Vector3.new(0, 0, 0),
			shellCasing = "rbxassetid://0",
			hitEffects = {
				Flesh = "rbxassetid://0",
				Metal = "rbxassetid://0",
				Wood = "rbxassetid://0"
			},
			smokePuff = "rbxassetid://0"
		}
	},
	
	-- Shotguns
	["NOVA"] = {
		id = "NOVA",
		name = "Nova",
		category = "Shotgun",
		stats = {
			damage = 26, -- Per pellet (8 pellets = 208 max damage)
			headDamage = 52,
			range = 50,
			accuracy = 0.45,
			fireRate = 68,
			magazineSize = 8,
			maxAmmo = 32,
			reloadTime = 4.0,
			recoilPattern = {
				Vector3.new(0, 12, 0), -- Heavy recoil
			},
			penetration = 0,
			velocity = 400,
			dropoff = {
				{distance = 10, damageMultiplier = 1.0},
				{distance = 25, damageMultiplier = 0.7},
				{distance = 50, damageMultiplier = 0.3}
			}
		},
		attachmentSlots = {
			optic = true,
			barrel = true,
			grip = false,
			magazine = false,
			stock = true
		},
		economy = {
			cost = 1200,
			unlockLevel = 7,
			rarity = "Common"
		},
		model = "rbxassetid://0",
		sounds = {
			fire = "rbxassetid://0",
			reload = "rbxassetid://0",
			empty = "rbxassetid://0",
			inspect = "rbxassetid://0"
		},
		animations = {
			idle = "rbxassetid://0",
			fire = "rbxassetid://0",
			reload = "rbxassetid://0",
			inspect = "rbxassetid://0",
			draw = "rbxassetid://0"
		},
		effects = {
			muzzleFlash = "rbxassetid://0",
			ejectionPort = Vector3.new(0, 0, 0),
			shellCasing = "rbxassetid://0",
			hitEffects = {
				Flesh = "rbxassetid://0",
				Metal = "rbxassetid://0",
				Wood = "rbxassetid://0"
			},
			smokePuff = "rbxassetid://0"
		}
	},
	
	-- LMGs
	["M249"] = {
		id = "M249",
		name = "M249",
		category = "LMG",
		stats = {
			damage = 32,
			headDamage = 128,
			range = 400,
			accuracy = 0.68,
			fireRate = 750,
			magazineSize = 100,
			maxAmmo = 200,
			reloadTime = 5.7,
			recoilPattern = {
				Vector3.new(0, 2, 0),
				Vector3.new(-1, 3, 0),
				Vector3.new(1, 4, 0),
				Vector3.new(-2, 5, 0),
				Vector3.new(2, 6, 0),
				Vector3.new(-3, 7, 0),
				Vector3.new(3, 8, 0),
				Vector3.new(-4, 9, 0),
				Vector3.new(4, 10, 0),
				Vector3.new(-3, 11, 0),
			},
			penetration = 3,
			velocity = 960,
			dropoff = {
				{distance = 75, damageMultiplier = 1.0},
				{distance = 200, damageMultiplier = 0.9},
				{distance = 400, damageMultiplier = 0.75}
			}
		},
		attachmentSlots = {
			optic = true,
			barrel = true,
			grip = true,
			magazine = false,
			stock = true
		},
		economy = {
			cost = 5200,
			unlockLevel = 20,
			rarity = "Epic"
		},
		model = "rbxassetid://0",
		sounds = {
			fire = "rbxassetid://0",
			reload = "rbxassetid://0",
			empty = "rbxassetid://0",
			inspect = "rbxassetid://0"
		},
		animations = {
			idle = "rbxassetid://0",
			fire = "rbxassetid://0",
			reload = "rbxassetid://0",
			inspect = "rbxassetid://0",
			draw = "rbxassetid://0"
		},
		effects = {
			muzzleFlash = "rbxassetid://0",
			ejectionPort = Vector3.new(0, 0, 0),
			shellCasing = "rbxassetid://0",
			hitEffects = {
				Flesh = "rbxassetid://0",
				Metal = "rbxassetid://0",
				Wood = "rbxassetid://0"
			},
			smokePuff = "rbxassetid://0"
		}
	},
	
	-- Utility
	["GRENADE"] = {
		id = "GRENADE",
		name = "HE Grenade",
		category = "Utility",
		stats = {
			damage = 99,
			headDamage = 99,
			range = 25, -- Explosion radius
			accuracy = 1.0,
			fireRate = 30, -- Throw rate
			magazineSize = 1,
			maxAmmo = 1,
			reloadTime = 0,
			recoilPattern = {},
			penetration = 0,
			velocity = 100,
			dropoff = {
				{distance = 5, damageMultiplier = 1.0},
				{distance = 15, damageMultiplier = 0.6},
				{distance = 25, damageMultiplier = 0.2}
			}
		},
		attachmentSlots = {
			optic = false,
			barrel = false,
			grip = false,
			magazine = false,
			stock = false
		},
		economy = {
			cost = 300,
			unlockLevel = 1,
			rarity = "Common"
		},
		model = "rbxassetid://0",
		sounds = {
			fire = "rbxassetid://0",
			reload = "rbxassetid://0",
			empty = "rbxassetid://0",
			inspect = "rbxassetid://0"
		},
		animations = {
			idle = "rbxassetid://0",
			fire = "rbxassetid://0",
			reload = "rbxassetid://0",
			inspect = "rbxassetid://0",
			draw = "rbxassetid://0"
		},
		effects = {
			muzzleFlash = "rbxassetid://0",
			ejectionPort = Vector3.new(0, 0, 0),
			shellCasing = "rbxassetid://0",
			hitEffects = {
				Flesh = "rbxassetid://0",
				Metal = "rbxassetid://0",
				Wood = "rbxassetid://0"
			},
			smokePuff = "rbxassetid://0"
		}
	},
	
	["FLASHBANG"] = {
		id = "FLASHBANG",
		name = "Flashbang",
		category = "Utility",
		stats = {
			damage = 1,
			headDamage = 1,
			range = 20, -- Effect radius
			accuracy = 1.0,
			fireRate = 30,
			magazineSize = 1,
			maxAmmo = 2,
			reloadTime = 0,
			recoilPattern = {},
			penetration = 0,
			velocity = 100,
			dropoff = {}
		},
		attachmentSlots = {
			optic = false,
			barrel = false,
			grip = false,
			magazine = false,
			stock = false
		},
		economy = {
			cost = 200,
			unlockLevel = 5,
			rarity = "Common"
		},
		model = "rbxassetid://0",
		sounds = {
			fire = "rbxassetid://0",
			reload = "rbxassetid://0",
			empty = "rbxassetid://0",
			inspect = "rbxassetid://0"
		},
		animations = {
			idle = "rbxassetid://0",
			fire = "rbxassetid://0",
			reload = "rbxassetid://0",
			inspect = "rbxassetid://0",
			draw = "rbxassetid://0"
		},
		effects = {
			muzzleFlash = "rbxassetid://0",
			ejectionPort = Vector3.new(0, 0, 0),
			shellCasing = "rbxassetid://0",
			hitEffects = {
				Flesh = "rbxassetid://0",
				Metal = "rbxassetid://0",
				Wood = "rbxassetid://0"
			},
			smokePuff = "rbxassetid://0"
		}
	}
}

-- Get weapon configuration by ID
function WeaponConfig.GetWeaponConfig(weaponID: string): CombatTypes.WeaponConfig?
	return WEAPON_CONFIGS[weaponID]
end

-- Get all weapon configurations
function WeaponConfig.GetAllWeapons(): {[string]: CombatTypes.WeaponConfig}
	return WEAPON_CONFIGS
end

-- Get weapons by category
function WeaponConfig.GetWeaponsByCategory(category: string): {CombatTypes.WeaponConfig}
	local weapons = {}
	
	for _, weapon in pairs(WEAPON_CONFIGS) do
		if weapon.category == category then
			table.insert(weapons, weapon)
		end
	end
	
	return weapons
end

-- Get weapons by rarity
function WeaponConfig.GetWeaponsByRarity(rarity: string): {CombatTypes.WeaponConfig}
	local weapons = {}
	
	for _, weapon in pairs(WEAPON_CONFIGS) do
		if weapon.economy.rarity == rarity then
			table.insert(weapons, weapon)
		end
	end
	
	return weapons
end

-- Get weapons unlocked at level
function WeaponConfig.GetWeaponsForLevel(level: number): {CombatTypes.WeaponConfig}
	local weapons = {}
	
	for _, weapon in pairs(WEAPON_CONFIGS) do
		if weapon.economy.unlockLevel <= level then
			table.insert(weapons, weapon)
		end
	end
	
	return weapons
end

-- Calculate damage at distance
function WeaponConfig.CalculateDamageAtDistance(weaponID: string, distance: number, isHeadshot: boolean): number
	local weapon = WEAPON_CONFIGS[weaponID]
	if not weapon then return 0 end
	
	local baseDamage = isHeadshot and weapon.stats.headDamage or weapon.stats.damage
	
	-- Find appropriate damage multiplier for distance
	local multiplier = 1.0
	for i = #weapon.stats.dropoff, 1, -1 do
		local dropoffPoint = weapon.stats.dropoff[i]
		if distance >= dropoffPoint.distance then
			multiplier = dropoffPoint.damageMultiplier
			break
		end
	end
	
	return math.floor(baseDamage * multiplier)
end

-- Calculate bullets to kill
function WeaponConfig.CalculateBTK(weaponID: string, distance: number, armor: number): {body: number, head: number}
	local bodyDamage = WeaponConfig.CalculateDamageAtDistance(weaponID, distance, false)
	local headDamage = WeaponConfig.CalculateDamageAtDistance(weaponID, distance, true)
	
	-- Apply armor reduction (simplified)
	local armorMultiplier = math.max(0.5, 1 - (armor / 200))
	bodyDamage = math.floor(bodyDamage * armorMultiplier)
	headDamage = math.floor(headDamage * armorMultiplier)
	
	return {
		body = math.ceil(100 / bodyDamage),
		head = math.ceil(100 / headDamage)
	}
end

-- Get time to kill
function WeaponConfig.CalculateTTK(weaponID: string, distance: number, armor: number): number
	local weapon = WEAPON_CONFIGS[weaponID]
	if not weapon then return math.huge end
	
	local btk = WeaponConfig.CalculateBTK(weaponID, distance, armor)
	local shotsNeeded = btk.body
	
	if shotsNeeded <= 1 then
		return 0
	end
	
	local timeBetweenShots = 60 / weapon.stats.fireRate -- Convert RPM to seconds
	return (shotsNeeded - 1) * timeBetweenShots
end

-- Validate weapon configuration
function WeaponConfig.ValidateWeapon(weapon: CombatTypes.WeaponConfig): boolean
	-- Check required fields
	if not weapon.id or not weapon.name or not weapon.category then
		return false
	end
	
	-- Check numeric values are positive
	if weapon.stats.damage <= 0 or weapon.stats.fireRate <= 0 or weapon.stats.magazineSize <= 0 then
		return false
	end
	
	-- Check accuracy is between 0 and 1
	if weapon.stats.accuracy < 0 or weapon.stats.accuracy > 1 then
		return false
	end
	
	return true
end

-- Get weapon categories
function WeaponConfig.GetCategories(): {string}
	return {
		"AssaultRifle",
		"SniperRifle", 
		"Pistol",
		"SMG",
		"Shotgun",
		"LMG",
		"Utility"
	}
end

-- Get weapon rarities
function WeaponConfig.GetRarities(): {string}
	return {
		"Common",
		"Rare", 
		"Epic",
		"Legendary",
		"Mythic"
	}
end

return WeaponConfig
