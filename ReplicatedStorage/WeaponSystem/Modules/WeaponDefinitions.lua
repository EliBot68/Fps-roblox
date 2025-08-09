--[[
	WeaponDefinitions.lua
	Place in: ReplicatedStorage/WeaponSystem/Modules/
	
	Enterprise weapon configuration system with complete weapon stats,
	asset references, and validation parameters for FPS game modes.
]]

local WeaponDefinitions = {}

-- Weapon slot types
export type WeaponSlot = "Primary" | "Secondary" | "Melee"

-- Complete weapon configuration type
export type WeaponConfig = {
	Id: string,
	Name: string,
	Slot: WeaponSlot,
	Category: string,
	
	-- Combat Stats
	Damage: number,
	HeadshotMultiplier: number,
	FireRate: number, -- rounds per second
	MagazineSize: number,
	ReloadTime: number,
	
	-- Ballistics
	Range: number,
	Spread: number,
	PelletCount: number?, -- for shotguns
	
	-- Assets
	ModelId: string,
	FireSound: string,
	ReloadSound: string,
	
	-- Animations (TODO: Replace with actual Animation IDs)
	Animations: {
		Idle: string,
		Fire: string,
		Reload: string,
		Equip: string,
		Unequip: string
	},
	
	-- Anti-exploit
	MaxFireRate: number, -- server-side throttle
	MaxRange: number -- server validation
}

-- PRIMARY WEAPONS
WeaponDefinitions.AssaultRifle = {
	Id = "AssaultRifle",
	Name = "M4A1 Carbine",
	Slot = "Primary",
	Category = "AssaultRifle",
	
	-- Combat Stats
	Damage = 30,
	HeadshotMultiplier = 2.0,
	FireRate = 10, -- 600 RPM
	MagazineSize = 30,
	ReloadTime = 2.5,
	
	-- Ballistics
	Range = 200,
	Spread = 0.02,
	
	-- Assets
	ModelId = "rbxassetid://153042904",
	FireSound = "rbxassetid://1585183374",
	ReloadSound = "rbxassetid://200289883",
	
	-- Animations (TODO: Replace with actual Animation IDs)
	Animations = {
		Idle = "rbxassetid://0", -- TODO: Replace
		Fire = "rbxassetid://0", -- TODO: Replace
		Reload = "rbxassetid://0", -- TODO: Replace
		Equip = "rbxassetid://0", -- TODO: Replace
		Unequip = "rbxassetid://0" -- TODO: Replace
	},
	
	-- Anti-exploit
	MaxFireRate = 12, -- 720 RPM max
	MaxRange = 250
}

WeaponDefinitions.SMG = {
	Id = "SMG",
	Name = "MP5-K",
	Slot = "Primary",
	Category = "SMG",
	
	-- Combat Stats
	Damage = 22,
	HeadshotMultiplier = 1.8,
	FireRate = 15, -- 900 RPM
	MagazineSize = 25,
	ReloadTime = 2.0,
	
	-- Ballistics
	Range = 120,
	Spread = 0.035,
	
	-- Assets
	ModelId = "rbxassetid://39444008",
	FireSound = "rbxassetid://1585183374",
	ReloadSound = "rbxassetid://200289883",
	
	-- Animations (TODO: Replace with actual Animation IDs)
	Animations = {
		Idle = "rbxassetid://0", -- TODO: Replace
		Fire = "rbxassetid://0", -- TODO: Replace
		Reload = "rbxassetid://0", -- TODO: Replace
		Equip = "rbxassetid://0", -- TODO: Replace
		Unequip = "rbxassetid://0" -- TODO: Replace
	},
	
	-- Anti-exploit
	MaxFireRate = 18, -- 1080 RPM max
	MaxRange = 150
}

WeaponDefinitions.Shotgun = {
	Id = "Shotgun",
	Name = "M870 Express",
	Slot = "Primary",
	Category = "Shotgun",
	
	-- Combat Stats
	Damage = 25, -- per pellet
	HeadshotMultiplier = 1.5,
	FireRate = 1.2, -- 72 RPM
	MagazineSize = 8,
	ReloadTime = 3.5,
	
	-- Ballistics
	Range = 80,
	Spread = 0.08,
	PelletCount = 8, -- 8 pellets per shot
	
	-- Assets
	ModelId = "rbxassetid://52108067",
	FireSound = "rbxassetid://1585183374",
	ReloadSound = "rbxassetid://200289883",
	
	-- Animations (TODO: Replace with actual Animation IDs)
	Animations = {
		Idle = "rbxassetid://0", -- TODO: Replace
		Fire = "rbxassetid://0", -- TODO: Replace
		Reload = "rbxassetid://0", -- TODO: Replace
		Equip = "rbxassetid://0", -- TODO: Replace
		Unequip = "rbxassetid://0" -- TODO: Replace
	},
	
	-- Anti-exploit
	MaxFireRate = 2.0, -- 120 RPM max
	MaxRange = 100
}

WeaponDefinitions.Sniper = {
	Id = "Sniper",
	Name = "AWP-S",
	Slot = "Primary",
	Category = "Sniper",
	
	-- Combat Stats
	Damage = 80,
	HeadshotMultiplier = 2.5,
	FireRate = 0.8, -- 48 RPM
	MagazineSize = 5,
	ReloadTime = 4.0,
	
	-- Ballistics
	Range = 500,
	Spread = 0.005,
	
	-- Assets
	ModelId = "rbxassetid://112992131",
	FireSound = "rbxassetid://1585183374",
	ReloadSound = "rbxassetid://200289883",
	
	-- Animations (TODO: Replace with actual Animation IDs)
	Animations = {
		Idle = "rbxassetid://0", -- TODO: Replace
		Fire = "rbxassetid://0", -- TODO: Replace
		Reload = "rbxassetid://0", -- TODO: Replace
		Equip = "rbxassetid://0", -- TODO: Replace
		Unequip = "rbxassetid://0" -- TODO: Replace
	},
	
	-- Anti-exploit
	MaxFireRate = 1.5, -- 90 RPM max
	MaxRange = 600
}

-- SECONDARY WEAPONS
WeaponDefinitions.Pistol = {
	Id = "Pistol",
	Name = "Glock-18",
	Slot = "Secondary",
	Category = "Pistol",
	
	-- Combat Stats
	Damage = 35,
	HeadshotMultiplier = 2.2,
	FireRate = 5, -- 300 RPM
	MagazineSize = 17,
	ReloadTime = 2.0,
	
	-- Ballistics
	Range = 100,
	Spread = 0.025,
	
	-- Assets
	ModelId = "rbxassetid://172589768",
	FireSound = "rbxassetid://8817903681",
	ReloadSound = "rbxassetid://5801855104",
	
	-- Animations (TODO: Replace with actual Animation IDs)
	Animations = {
		Idle = "rbxassetid://0", -- TODO: Replace
		Fire = "rbxassetid://0", -- TODO: Replace
		Reload = "rbxassetid://0", -- TODO: Replace
		Equip = "rbxassetid://0", -- TODO: Replace
		Unequip = "rbxassetid://0" -- TODO: Replace
	},
	
	-- Anti-exploit
	MaxFireRate = 7, -- 420 RPM max
	MaxRange = 120
}

-- MELEE WEAPONS
WeaponDefinitions.CombatKnife = {
	Id = "CombatKnife",
	Name = "Combat Knife",
	Slot = "Melee",
	Category = "Melee",
	
	-- Combat Stats
	Damage = 60,
	HeadshotMultiplier = 1.0, -- no headshot for melee
	FireRate = 2, -- 2 swings per second
	MagazineSize = 999, -- infinite ammo
	ReloadTime = 0,
	
	-- Ballistics
	Range = 8, -- melee range
	Spread = 0,
	
	-- Assets
	ModelId = "rbxassetid://76371671",
	FireSound = "rbxassetid://151130059", -- slash sound
	ReloadSound = "",
	
	-- Animations (TODO: Replace with actual Animation IDs)
	Animations = {
		Idle = "rbxassetid://0", -- TODO: Replace
		Fire = "rbxassetid://0", -- TODO: Replace (swing)
		Reload = "rbxassetid://0", -- TODO: Replace (none)
		Equip = "rbxassetid://0", -- TODO: Replace
		Unequip = "rbxassetid://0" -- TODO: Replace
	},
	
	-- Anti-exploit
	MaxFireRate = 3, -- 3 swings per second max
	MaxRange = 12
}

WeaponDefinitions.Axe = {
	Id = "Axe",
	Name = "Tactical Axe",
	Slot = "Melee",
	Category = "Melee",
	
	-- Combat Stats
	Damage = 85,
	HeadshotMultiplier = 1.0,
	FireRate = 1.2, -- slower than knife
	MagazineSize = 999,
	ReloadTime = 0,
	
	-- Ballistics
	Range = 10,
	Spread = 0,
	
	-- Assets
	ModelId = "rbxassetid://81878057",
	FireSound = "rbxassetid://6961977071", -- wood hit sound
	ReloadSound = "",
	
	-- Animations (TODO: Replace with actual Animation IDs)
	Animations = {
		Idle = "rbxassetid://0", -- TODO: Replace
		Fire = "rbxassetid://0", -- TODO: Replace
		Reload = "rbxassetid://0", -- TODO: Replace
		Equip = "rbxassetid://0", -- TODO: Replace
		Unequip = "rbxassetid://0" -- TODO: Replace
	},
	
	-- Anti-exploit
	MaxFireRate = 2, -- 2 swings per second max
	MaxRange = 15
}

WeaponDefinitions.ThrowingKnife = {
	Id = "ThrowingKnife",
	Name = "Throwing Knife",
	Slot = "Melee",
	Category = "Throwable",
	
	-- Combat Stats
	Damage = 100, -- one-shot potential
	HeadshotMultiplier = 1.5,
	FireRate = 0.5, -- slow throw rate
	MagazineSize = 3, -- limited throws
	ReloadTime = 5.0, -- long recovery
	
	-- Ballistics
	Range = 150, -- projectile range
	Spread = 0.01,
	
	-- Assets
	ModelId = "rbxassetid://31315197",
	FireSound = "rbxassetid://151130059",
	ReloadSound = "",
	
	-- Animations (TODO: Replace with actual Animation IDs)
	Animations = {
		Idle = "rbxassetid://0", -- TODO: Replace
		Fire = "rbxassetid://0", -- TODO: Replace (throw)
		Reload = "rbxassetid://0", -- TODO: Replace (restock)
		Equip = "rbxassetid://0", -- TODO: Replace
		Unequip = "rbxassetid://0" -- TODO: Replace
	},
	
	-- Anti-exploit
	MaxFireRate = 1, -- 1 throw per second max
	MaxRange = 200
}

-- DEFAULT LOADOUT
WeaponDefinitions.DefaultLoadout = {
	Primary = "AssaultRifle",
	Secondary = "Pistol",
	Melee = "CombatKnife"
}

-- WEAPON LISTS BY SLOT
WeaponDefinitions.WeaponsBySlot = {
	Primary = {"AssaultRifle", "SMG", "Shotgun", "Sniper"},
	Secondary = {"Pistol"},
	Melee = {"CombatKnife", "Axe", "ThrowingKnife"}
}

-- Get weapon config by ID
function WeaponDefinitions.GetWeapon(weaponId: string): WeaponConfig?
	return WeaponDefinitions[weaponId]
end

-- Get all weapons for a slot
function WeaponDefinitions.GetWeaponsForSlot(slot: WeaponSlot): {WeaponConfig}
	local weapons = {}
	local weaponIds = WeaponDefinitions.WeaponsBySlot[slot] or {}
	
	for _, weaponId in ipairs(weaponIds) do
		local weapon = WeaponDefinitions.GetWeapon(weaponId)
		if weapon then
			table.insert(weapons, weapon)
		end
	end
	
	return weapons
end

-- Validate weapon configuration
function WeaponDefinitions.ValidateWeapon(weapon: WeaponConfig): boolean
	if not weapon.Id or weapon.Id == "" then return false end
	if not weapon.Name or weapon.Name == "" then return false end
	if weapon.Damage <= 0 then return false end
	if weapon.FireRate <= 0 then return false end
	if weapon.Range <= 0 then return false end
	if not weapon.ModelId or weapon.ModelId == "" then return false end
	
	return true
end

return WeaponDefinitions
