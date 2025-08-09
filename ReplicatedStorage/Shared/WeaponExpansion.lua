-- WeaponExpansion.lua
-- Enterprise weapon expansion framework for new weapon systems

local WeaponExpansion = {
	-- Base template for new weapons
	WeaponTemplate = {
		Id = "",
		Name = "",
		DisplayName = "",
		Category = "Primary", -- Primary, Secondary, Heavy, Special
		Class = "", -- AR, SMG, Shotgun, Sniper, LMG, Launcher, Melee, etc.
		
		-- Core Stats
		Damage = 0,
		HeadshotMultiplier = 1.0,
		FireRate = 0, -- rounds per second
		MagazineSize = 0,
		ReloadTime = 0,
		
		-- Ballistics
		Range = 0,
		FalloffStart = 0,
		FalloffEnd = 0,
		Spread = 0,
		Penetration = 0,
		
		-- Special Properties
		BurstCount = nil, -- for burst weapons
		BurstDelay = nil,
		PelletCount = nil, -- for shotguns
		ExplosiveDamage = nil, -- for explosive weapons
		ExplosiveRadius = nil,
		
		-- Recoil System
		Recoil = {
			Vertical = 0,
			Horizontal = 0,
			Recovery = 0,
			Pattern = nil -- Custom recoil pattern
		},
		
		-- Mobility Impact
		Mobility = {
			WalkSpeed = 1.0,
			AdsSpeed = 1.0,
			SwapSpeed = 1.0
		},
		
		-- Progression
		Cost = 0,
		Tier = 1,
		UnlockLevel = 1,
		UnlockRequirement = nil, -- Custom unlock conditions
		
		-- Effectiveness by range
		Effectiveness = {
			Close = 1.0,
			Medium = 1.0,
			Long = 1.0
		},
		
		-- Visual/Audio
		Model = nil,
		Sounds = {
			Fire = nil,
			Reload = nil,
			Empty = nil
		},
		
		-- Attachments Support
		AttachmentSlots = {
			Optic = false,
			Barrel = false,
			Grip = false,
			Stock = false,
			Magazine = false
		},
		
		-- Special Abilities
		SpecialAbilities = {}
	},
	
	-- Weapon categories for organization
	Categories = {
		Primary = {
			AssaultRifles = {},
			SMGs = {},
			Shotguns = {},
			Snipers = {},
			LMGs = {},
			DMRs = {} -- Designated Marksman Rifles
		},
		Secondary = {
			Pistols = {},
			SMGs = {},
			Shotguns = {}
		},
		Heavy = {
			LMGs = {},
			Launchers = {},
			Miniguns = {}
		},
		Special = {
			Melee = {},
			Throwables = {},
			Gadgets = {}
		}
	},
	
	-- Ammunition types
	AmmoTypes = {
		["9mm"] = { damage_modifier = 1.0, penetration = 0.3 },
		["5.56"] = { damage_modifier = 1.1, penetration = 0.7 },
		["7.62"] = { damage_modifier = 1.3, penetration = 0.9 },
		[".50cal"] = { damage_modifier = 2.0, penetration = 1.5 },
		["12gauge"] = { damage_modifier = 0.8, penetration = 0.2 },
		["explosive"] = { damage_modifier = 3.0, penetration = 2.0 }
	}
}

-- Create new weapon from template
function WeaponExpansion.CreateWeapon(weaponData)
	local weapon = {}
	
	-- Copy template
	for key, value in pairs(WeaponExpansion.WeaponTemplate) do
		if type(value) == "table" then
			weapon[key] = {}
			for subKey, subValue in pairs(value) do
				weapon[key][subKey] = subValue
			end
		else
			weapon[key] = value
		end
	end
	
	-- Override with provided data
	for key, value in pairs(weaponData) do
		if type(value) == "table" and weapon[key] and type(weapon[key]) == "table" then
			for subKey, subValue in pairs(value) do
				weapon[key][subKey] = subValue
			end
		else
			weapon[key] = value
		end
	end
	
	return weapon
end

-- Validate weapon configuration
function WeaponExpansion.ValidateWeapon(weapon)
	local issues = {}
	
	if not weapon.Id or weapon.Id == "" then
		table.insert(issues, "Missing weapon ID")
	end
	
	if not weapon.Name or weapon.Name == "" then
		table.insert(issues, "Missing weapon name")
	end
	
	if weapon.Damage <= 0 then
		table.insert(issues, "Invalid damage value")
	end
	
	if weapon.FireRate <= 0 then
		table.insert(issues, "Invalid fire rate")
	end
	
	-- TTK validation
	local ttk = 100 / (weapon.Damage * weapon.FireRate)
	if ttk < 0.2 then
		table.insert(issues, "TTK too low: " .. ttk .. "s")
	elseif ttk > 5.0 then
		table.insert(issues, "TTK too high: " .. ttk .. "s")
	end
	
	return issues
end

-- Register new weapon category
function WeaponExpansion.RegisterCategory(categoryName, subcategories)
	WeaponExpansion.Categories[categoryName] = subcategories or {}
end

-- Get all weapons in category
function WeaponExpansion.GetWeaponsByCategory(category, subcategory)
	if subcategory then
		return WeaponExpansion.Categories[category] and WeaponExpansion.Categories[category][subcategory] or {}
	else
		return WeaponExpansion.Categories[category] or {}
	end
end

return WeaponExpansion
