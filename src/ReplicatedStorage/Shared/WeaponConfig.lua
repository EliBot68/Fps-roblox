--!strict
--[[
	WeaponConfig.lua
	Central weapon configuration and stats (normalized + legacy compatibility)
]]

local WeaponConfig = {}
local CombatTypes = require(script.Parent.CombatTypes)
local Logger = require(script.Parent.Logger)

local logger = Logger.new("WeaponConfig")

-- Internal normalized stats type (unified)
export type NormalizedWeaponStats = {
	-- Core unified fields
	damage: number,
	headDamage: number,
	headshotMultiplier: number, -- derived for backward compatibility
	fireRate: number,
	reloadTime: number,
	magazineSize: number,
	maxAmmo: number,
	range: number,
	accuracy: number,
	recoilPattern: {Vector3},
	penetration: number,
	velocity: number,
	muzzleVelocity: number, -- alias for velocity
	dropoff: { { distance: number, damageMultiplier: number } },
	damageDropoff: {[number]: number}?, -- synthesized legacy map (distance->mult)
	weight: number?
}

export type NormalizedWeaponConfig = {
	id: string,
	name: string,
	displayName: string?,
	description: string?,
	category: CombatTypes.WeaponCategory,
	rarity: CombatTypes.WeaponRarity,
	stats: NormalizedWeaponStats,
	attachmentSlots: {[string]: boolean}?,
	unlockLevel: number?,
	cost: number?,
	modelId: string?,
	iconId: string?,
	sounds: {[string]: any}?,
	animations: {[string]: any}?,
	effects: {[string]: any}?,
	economy: {cost: number?, unlockLevel: number?, rarity: string?}?,
	model: string?
}

-- Raw weapon configurations (may contain legacy field names)
local WEAPON_CONFIGS: {[string]: any} = {
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

-- Normalized cache
local _normalizedCache: {[string]: NormalizedWeaponConfig} = {}
local _ttkCache: {[string]: {[number]: number}} = {} -- weaponId -> {distance -> ttk}
local _validationResults: {weaponId: string, issues: {string}}? = nil

local function normalizeDropoff(stats: any): { { distance: number, damageMultiplier: number } }
	-- Accept either table with numeric keys (array of objects) or map distance->multiplier
	local result: { { distance: number, damageMultiplier: number } } = {}
	if stats.dropoff and typeof(stats.dropoff) == "table" then
		if #stats.dropoff > 0 then
			for _, point in ipairs(stats.dropoff) do
				if typeof(point) == "table" and point.distance and point.damageMultiplier then
					table.insert(result, { distance = point.distance, damageMultiplier = point.damageMultiplier })
				end
			end
		else
			for distance, mult in pairs(stats.dropoff) do
				if typeof(distance) == "number" and typeof(mult) == "number" then
					table.insert(result, { distance = distance, damageMultiplier = mult })
				end
			end
		end
	elseif stats.damageDropoff then
		for distance, mult in pairs(stats.damageDropoff) do
			if typeof(distance) == "number" and typeof(mult) == "number" then
				table.insert(result, { distance = distance, damageMultiplier = mult })
			end
		end
	end
	if #result == 0 then
		result = { { distance = 0, damageMultiplier = 1.0 } }
	end
	 table.sort(result, function(a,b) return a.distance < b.distance end)
	return result
end

local function normalizeStats(rawStats: any): NormalizedWeaponStats
	local damage = rawStats.damage or 0
	local headDamage = rawStats.headDamage
	local headshotMultiplier = rawStats.headshotMultiplier
	if not headDamage and headshotMultiplier then
		headDamage = damage * headshotMultiplier
	elseif not headDamage then
		headDamage = damage * 2
	end
	local derivedMultiplier = headDamage > 0 and damage > 0 and (headDamage / damage) or (headshotMultiplier or 2)
	local velocity = rawStats.muzzleVelocity or rawStats.velocity or 0
	local dropoffArr = normalizeDropoff(rawStats)
	local dropoffMap: {[number]: number} = {}
	for _, p in ipairs(dropoffArr) do
		dropoffMap[p.distance] = p.damageMultiplier
	end
	return {
		damage = damage,
		headDamage = headDamage,
		headshotMultiplier = derivedMultiplier,
		fireRate = rawStats.fireRate or 0,
		reloadTime = rawStats.reloadTime or 0,
		magazineSize = rawStats.magazineSize or 0,
		maxAmmo = rawStats.maxAmmo or 0,
		range = rawStats.range or 0,
		accuracy = rawStats.accuracy or 0,
		recoilPattern = rawStats.recoilPattern or {},
		penetration = rawStats.penetration or 0,
		velocity = velocity,
		muzzleVelocity = velocity,
		dropoff = dropoffArr,
		damageDropoff = dropoffMap,
		weight = rawStats.weight,
	}
end

local function normalizeConfig(raw: any): NormalizedWeaponConfig
	if _normalizedCache[raw.id] then
		return _normalizedCache[raw.id]
	end
	local cfg: NormalizedWeaponConfig = {
		id = raw.id,
		name = raw.name,
		displayName = raw.displayName or raw.name,
		description = raw.description,
		category = raw.category,
		rarity = (raw.economy and raw.economy.rarity) or raw.rarity,
		stats = normalizeStats(raw.stats or raw),
		attachmentSlots = raw.attachmentSlots,
		unlockLevel = (raw.economy and raw.economy.unlockLevel) or raw.unlockLevel,
		cost = (raw.economy and raw.economy.cost) or raw.cost,
		modelId = raw.modelId or raw.model,
		iconId = raw.iconId,
		sounds = raw.sounds,
		animations = raw.animations,
		effects = raw.effects,
		economy = raw.economy,
		model = raw.model,
	}
	_normalizedCache[raw.id] = cfg
	return cfg
end

-- Cache invalidation and management
function WeaponConfig.RefreshCache(weaponId: string?)
	if weaponId then
		_normalizedCache[weaponId] = nil
		_ttkCache[weaponId] = nil
		logger:debug("Cache refreshed for weapon", {weaponId = weaponId})
	else
		_normalizedCache = {}
		_ttkCache = {}
		_validationResults = nil
		logger:info("Full weapon cache cleared")
	end
end

-- Efficient iteration utility
function WeaponConfig.Iterate(callback: (NormalizedWeaponConfig) -> ())
	for _, raw in pairs(WEAPON_CONFIGS) do
		local normalized = normalizeConfig(raw)
		callback(normalized)
	end
end

-- Advanced validation with discrepancy logging
function WeaponConfig.ValidateAllConfigs(): {totalWeapons: number, validWeapons: number, issues: {{weaponId: string, problems: {string}}}}
	if _validationResults then
		return _validationResults
	end
	
	local issues: {{weaponId: string, problems: {string}}} = {}
	local validCount = 0
	local totalCount = 0
	
	for weaponId, raw in pairs(WEAPON_CONFIGS) do
		totalCount += 1
		local problems: {string} = {}
		
		-- Basic field validation
		if not raw.id or raw.id == "" then
			table.insert(problems, "Missing or empty ID")
		end
		if not raw.name or raw.name == "" then
			table.insert(problems, "Missing or empty name")
		end
		if not raw.category then
			table.insert(problems, "Missing category")
		else
			-- Validate category is in union
			local validCategories = {"AssaultRifle", "SniperRifle", "SMG", "Shotgun", "Pistol", "LMG", "Melee", "Utility"}
			local isValidCategory = false
			for _, validCat in ipairs(validCategories) do
				if raw.category == validCat then
					isValidCategory = true
					break
				end
			end
			if not isValidCategory then
				table.insert(problems, "Invalid category: " .. tostring(raw.category))
			end
		end
		
		-- Stats validation
		local stats = raw.stats or raw
		if (stats.damage or 0) <= 0 then
			table.insert(problems, "Non-positive damage")
		end
		if (stats.fireRate or 0) <= 0 then
			table.insert(problems, "Non-positive fire rate")
		end
		if (stats.magazineSize or 0) <= 0 then
			table.insert(problems, "Non-positive magazine size")
		end
		if (stats.accuracy or 0) < 0 or (stats.accuracy or 0) > 1 then
			table.insert(problems, "Accuracy out of range [0,1]")
		end
		
		-- Recoil pattern validation
		if not stats.recoilPattern or #stats.recoilPattern == 0 then
			table.insert(problems, "Missing or empty recoil pattern")
		end
		
		-- Dropoff validation
		local dropoffPoints = normalizeDropoff(stats)
		for i = 2, #dropoffPoints do
			if dropoffPoints[i].distance <= dropoffPoints[i-1].distance then
				table.insert(problems, "Dropoff distances not in ascending order")
				break
			end
		end
		
		-- Rarity validation
		if raw.rarity or (raw.economy and raw.economy.rarity) then
			local rarity = (raw.economy and raw.economy.rarity) or raw.rarity
			local validRarities = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic"}
			local isValidRarity = false
			for _, validRar in ipairs(validRarities) do
				if rarity == validRar then
					isValidRarity = true
					break
				end
			end
			if not isValidRarity then
				table.insert(problems, "Invalid rarity: " .. tostring(rarity))
			end
		end
		
		if #problems == 0 then
			validCount += 1
		else
			table.insert(issues, {weaponId = weaponId, problems = problems})
		end
	end
	
	_validationResults = {
		totalWeapons = totalCount,
		validWeapons = validCount,
		issues = issues
	}
	
	-- Log discrepancies
	if #issues > 0 then
		logger:warn("Weapon configuration validation found issues", {
			totalWeapons = totalCount,
			validWeapons = validCount,
			invalidWeapons = #issues
		})
		for _, issue in ipairs(issues) do
			logger:error("Weapon validation failed", {
				weaponId = issue.weaponId,
				problems = issue.problems
			})
		end
	else
		logger:info("All weapon configurations validated successfully", {
			totalWeapons = totalCount
		})
	end
	
	return _validationResults
end

-- Precompute TTK tables for analytics
function WeaponConfig.PrecomputeTTKTables()
	logger:info("Precomputing TTK reference tables...")
	local distances = {10, 25, 50, 75, 100, 150, 200, 300, 500, 1000}
	local armorValues = {0, 50, 100}
	
	for weaponId, _ in pairs(WEAPON_CONFIGS) do
		_ttkCache[weaponId] = {}
		for _, distance in ipairs(distances) do
			for _, armor in ipairs(armorValues) do
				local key = distance * 1000 + armor -- Composite key
				_ttkCache[weaponId][key] = WeaponConfig.CalculateTTK(weaponId, distance, armor)
			end
		end
	end
	
	logger:info("TTK tables precomputed", {
		weaponCount = table.getn or #WEAPON_CONFIGS,
		distancePoints = #distances,
		armorVariants = #armorValues
	})
end

-- Get precomputed TTK
function WeaponConfig.GetPrecomputedTTK(weaponId: string, distance: number, armor: number): number?
	local cache = _ttkCache[weaponId]
	if not cache then return nil end
	
	-- Find closest distance
	local distances = {10, 25, 50, 75, 100, 150, 200, 300, 500, 1000}
	local closestDistance = distances[1]
	for _, d in ipairs(distances) do
		if math.abs(d - distance) < math.abs(closestDistance - distance) then
			closestDistance = d
		end
	end
	
	-- Find closest armor
	local armorValues = {0, 50, 100}
	local closestArmor = armorValues[1]
	for _, a in ipairs(armorValues) do
		if math.abs(a - armor) < math.abs(closestArmor - armor) then
			closestArmor = a
		end
	end
	
	local key = closestDistance * 1000 + closestArmor
	return cache[key]
end

-- Public API
function WeaponConfig.GetWeaponConfig(weaponID: string): NormalizedWeaponConfig?
	local raw = WEAPON_CONFIGS[weaponID]
	if not raw then return nil end
	return normalizeConfig(raw)
end

function WeaponConfig.GetAllWeapons(): {[string]: NormalizedWeaponConfig}
	local out: {[string]: NormalizedWeaponConfig} = {}
	for id, raw in pairs(WEAPON_CONFIGS) do
		out[id] = normalizeConfig(raw)
	end
	return out
end

function WeaponConfig.GetWeaponsByCategory(category: string): {NormalizedWeaponConfig}
	local weapons: {NormalizedWeaponConfig} = {}
	for _, raw in pairs(WEAPON_CONFIGS) do
		if raw.category == category then
			table.insert(weapons, normalizeConfig(raw))
		end
	end
	return weapons
end

function WeaponConfig.GetWeaponsByRarity(rarity: string): {NormalizedWeaponConfig}
	local weapons: {NormalizedWeaponConfig} = {}
	for _, raw in pairs(WEAPON_CONFIGS) do
		local r = (raw.economy and raw.economy.rarity) or raw.rarity
		if r == rarity then
			table.insert(weapons, normalizeConfig(raw))
		end
	end
	return weapons
end

function WeaponConfig.GetWeaponsForLevel(level: number): {NormalizedWeaponConfig}
	local weapons: {NormalizedWeaponConfig} = {}
	for _, raw in pairs(WEAPON_CONFIGS) do
		local unlock = (raw.economy and raw.economy.unlockLevel) or raw.unlockLevel or 1
		if unlock <= level then
			table.insert(weapons, normalizeConfig(raw))
		end
	end
	return weapons
end

function WeaponConfig.CalculateDamageAtDistance(weaponID: string, distance: number, isHeadshot: boolean): number
	local cfg = WeaponConfig.GetWeaponConfig(weaponID)
	if not cfg then return 0 end
	local baseDamage = isHeadshot and cfg.stats.headDamage or cfg.stats.damage
	local multiplier = 1.0
	for i = #cfg.stats.dropoff, 1, -1 do
		local point = cfg.stats.dropoff[i]
		if distance >= point.distance then
			multiplier = point.damageMultiplier
			break
		end
	end
	return math.floor(baseDamage * multiplier)
end

function WeaponConfig.CalculateBTK(weaponID: string, distance: number, armor: number): {body: number, head: number}
	local bodyDamage = WeaponConfig.CalculateDamageAtDistance(weaponID, distance, false)
	local headDamage = WeaponConfig.CalculateDamageAtDistance(weaponID, distance, true)
	local armorMultiplier = math.max(0.5, 1 - (armor / 200))
	bodyDamage = math.floor(bodyDamage * armorMultiplier)
	headDamage = math.floor(headDamage * armorMultiplier)
	return { body = math.ceil(100 / math.max(bodyDamage,1)), head = math.ceil(100 / math.max(headDamage,1)) }
end

function WeaponConfig.CalculateTTK(weaponID: string, distance: number, armor: number): number
	local cfg = WeaponConfig.GetWeaponConfig(weaponID)
	if not cfg then return math.huge end
	local btk = WeaponConfig.CalculateBTK(weaponID, distance, armor)
	local shotsNeeded = btk.body
	if shotsNeeded <= 1 then return 0 end
	local timeBetweenShots = 60 / math.max(cfg.stats.fireRate,1)
	return (shotsNeeded - 1) * timeBetweenShots
end

function WeaponConfig.ValidateWeapon(raw: any): boolean
	if not raw or not raw.id or not raw.name or not raw.category then return false end
	local stats = raw.stats or raw
	if (stats.damage or 0) <= 0 then return false end
	if (stats.fireRate or 0) <= 0 then return false end
	if (stats.magazineSize or 0) <= 0 then return false end
	local acc = stats.accuracy or 0
	if acc < 0 or acc > 1 then return false end
	return true
end

function WeaponConfig.GetCategories(): {string}
	return {"AssaultRifle","SniperRifle","Pistol","SMG","Shotgun","LMG","Utility"}
end

function WeaponConfig.GetRarities(): {string}
	return {"Common","Rare","Epic","Legendary","Mythic"}
end

function WeaponConfig.GetHeadshotMultiplier(weaponID: string): number
	local cfg = WeaponConfig.GetWeaponConfig(weaponID)
	if not cfg then return 2 end
	return cfg.stats.headshotMultiplier
end

-- Initialize WeaponConfig system with validation and precomputation
function WeaponConfig.Initialize()
	logger:info("Initializing WeaponConfig system...")
	
	-- Run comprehensive validation
	local validationResults = WeaponConfig.ValidateAllConfigs()
	
	-- Precompute TTK tables
	WeaponConfig.PrecomputeTTKTables()
	
	logger:info("WeaponConfig system initialized", {
		totalWeapons = validationResults.totalWeapons,
		validWeapons = validationResults.validWeapons,
		hasIssues = #validationResults.issues > 0
	})
	
	return validationResults
end

return WeaponConfig
