-- WeaponAttachmentSystem.lua
-- Advanced attachment system for weapon customization

local WeaponAttachmentSystem = {
	-- Attachment categories
	AttachmentTypes = {
		Optic = {
			"RedDot", "Holographic", "ACOG", "Scope4x", "Scope8x", "Scope12x",
			"IronSights", "ReflexSight", "ThermalScope", "NightVision"
		},
		Barrel = {
			"Suppressor", "Compensator", "MuzzleBrake", "FlashHider", 
			"ExtendedBarrel", "HeavyBarrel", "LightBarrel"
		},
		Grip = {
			"VerticalGrip", "AngledGrip", "BipodGrip", "PistolGrip",
			"TacticalGrip", "StubbyGrip"
		},
		Stock = {
			"FixedStock", "AdjustableStock", "HeavyStock", "LightStock",
			"TacticalStock", "NoStock"
		},
		Magazine = {
			"ExtendedMag", "FastMag", "DualMag", "DrumMag",
			"HollowPoint", "ArmorPiercing", "Incendiary"
		},
		Laser = {
			"RedLaser", "GreenLaser", "IRLaser", "TacticalLight",
			"StrobeLight"
		}
	},
	
	-- Attachment configurations
	Attachments = {}
}

-- Initialize attachment system
function WeaponAttachmentSystem.Initialize()
	-- Optics
	WeaponAttachmentSystem.Attachments.RedDot = {
		Name = "Red Dot Sight",
		Type = "Optic",
		Effects = {
			AdsZoom = 1.2,
			AdsTime = 0.9, -- 10% faster ADS
			Spread = 0.95 -- 5% better accuracy
		},
		Cost = 500,
		UnlockLevel = 5
	}
	
	WeaponAttachmentSystem.Attachments.ACOG = {
		Name = "ACOG 4x Scope",
		Type = "Optic",
		Effects = {
			AdsZoom = 4.0,
			AdsTime = 1.2, -- 20% slower ADS
			Spread = 0.8, -- 20% better accuracy
			Range = 1.2 -- 20% better range
		},
		Cost = 1500,
		UnlockLevel = 15
	}
	
	WeaponAttachmentSystem.Attachments.Scope8x = {
		Name = "8x Sniper Scope",
		Type = "Optic",
		Effects = {
			AdsZoom = 8.0,
			AdsTime = 1.5, -- 50% slower ADS
			Spread = 0.7, -- 30% better accuracy
			Range = 1.5 -- 50% better range
		},
		Cost = 3000,
		UnlockLevel = 25
	}
	
	-- Barrels
	WeaponAttachmentSystem.Attachments.Suppressor = {
		Name = "Suppressor",
		Type = "Barrel",
		Effects = {
			MuzzleFlash = 0.1, -- 90% reduction
			SoundReduction = 0.3, -- 70% quieter
			Range = 0.9, -- 10% range reduction
			Velocity = 0.95 -- 5% velocity reduction
		},
		Cost = 800,
		UnlockLevel = 10
	}
	
	WeaponAttachmentSystem.Attachments.Compensator = {
		Name = "Compensator",
		Type = "Barrel",
		Effects = {
			VerticalRecoil = 0.7, -- 30% reduction
			HorizontalRecoil = 1.1, -- 10% increase
			MuzzleFlash = 1.2 -- 20% increase
		},
		Cost = 600,
		UnlockLevel = 8
	}
	
	WeaponAttachmentSystem.Attachments.ExtendedBarrel = {
		Name = "Extended Barrel",
		Type = "Barrel",
		Effects = {
			Range = 1.3, -- 30% increase
			Damage = 1.05, -- 5% damage increase
			Mobility = 0.9, -- 10% mobility reduction
			AdsTime = 1.1 -- 10% slower ADS
		},
		Cost = 1000,
		UnlockLevel = 12
	}
	
	-- Grips
	WeaponAttachmentSystem.Attachments.VerticalGrip = {
		Name = "Vertical Grip",
		Type = "Grip",
		Effects = {
			VerticalRecoil = 0.8, -- 20% reduction
			AdsTime = 1.05, -- 5% slower ADS
			HipfireAccuracy = 0.95 -- 5% better hipfire
		},
		Cost = 400,
		UnlockLevel = 6
	}
	
	WeaponAttachmentSystem.Attachments.AngledGrip = {
		Name = "Angled Grip",
		Type = "Grip",
		Effects = {
			AdsTime = 0.9, -- 10% faster ADS
			HorizontalRecoil = 0.85, -- 15% reduction
			VerticalRecoil = 1.05 -- 5% increase
		},
		Cost = 450,
		UnlockLevel = 7
	}
	
	WeaponAttachmentSystem.Attachments.BipodGrip = {
		Name = "Bipod",
		Type = "Grip",
		Effects = {
			ProneRecoil = 0.5, -- 50% recoil reduction when prone
			ProneSpread = 0.7, -- 30% better accuracy when prone
			Mobility = 0.85, -- 15% mobility reduction
			AdsTime = 1.15 -- 15% slower ADS
		},
		Cost = 700,
		UnlockLevel = 14
	}
	
	-- Stocks
	WeaponAttachmentSystem.Attachments.AdjustableStock = {
		Name = "Adjustable Stock",
		Type = "Stock",
		Effects = {
			Recoil = 0.9, -- 10% overall recoil reduction
			AdsTime = 0.95, -- 5% faster ADS
			Mobility = 1.05 -- 5% better mobility
		},
		Cost = 500,
		UnlockLevel = 9
	}
	
	WeaponAttachmentSystem.Attachments.HeavyStock = {
		Name = "Heavy Stock",
		Type = "Stock",
		Effects = {
			Recoil = 0.8, -- 20% recoil reduction
			Damage = 1.03, -- 3% damage increase
			Mobility = 0.9, -- 10% mobility reduction
			AdsTime = 1.1 -- 10% slower ADS
		},
		Cost = 650,
		UnlockLevel = 11
	}
	
	WeaponAttachmentSystem.Attachments.NoStock = {
		Name = "No Stock",
		Type = "Stock",
		Effects = {
			Mobility = 1.2, -- 20% better mobility
			AdsTime = 0.85, -- 15% faster ADS
			Recoil = 1.3, -- 30% more recoil
			Spread = 1.15 -- 15% worse accuracy
		},
		Cost = 300,
		UnlockLevel = 13
	}
	
	-- Magazines
	WeaponAttachmentSystem.Attachments.ExtendedMag = {
		Name = "Extended Magazine",
		Type = "Magazine",
		Effects = {
			MagazineSize = 1.5, -- 50% more ammo
			ReloadTime = 1.15, -- 15% slower reload
			Mobility = 0.95 -- 5% mobility reduction
		},
		Cost = 400,
		UnlockLevel = 4
	}
	
	WeaponAttachmentSystem.Attachments.FastMag = {
		Name = "Fast Magazine",
		Type = "Magazine",
		Effects = {
			ReloadTime = 0.8, -- 20% faster reload
			MagazineSize = 0.9 -- 10% less ammo
		},
		Cost = 350,
		UnlockLevel = 6
	}
	
	WeaponAttachmentSystem.Attachments.DrumMag = {
		Name = "Drum Magazine",
		Type = "Magazine",
		Effects = {
			MagazineSize = 2.0, -- 100% more ammo
			ReloadTime = 1.4, -- 40% slower reload
			Mobility = 0.85, -- 15% mobility reduction
			AdsTime = 1.2 -- 20% slower ADS
		},
		Cost = 800,
		UnlockLevel = 18
	}
	
	WeaponAttachmentSystem.Attachments.ArmorPiercing = {
		Name = "Armor Piercing Rounds",
		Type = "Magazine",
		Effects = {
			Penetration = 1.5, -- 50% better penetration
			Damage = 0.95, -- 5% less base damage
			ArmorDamage = 2.0 -- 100% more armor damage
		},
		Cost = 600,
		UnlockLevel = 16
	}
	
	-- Lasers
	WeaponAttachmentSystem.Attachments.RedLaser = {
		Name = "Red Laser Sight",
		Type = "Laser",
		Effects = {
			HipfireAccuracy = 0.8, -- 20% better hipfire
			AdsTime = 0.95 -- 5% faster ADS
		},
		Cost = 300,
		UnlockLevel = 3
	}
	
	WeaponAttachmentSystem.Attachments.TacticalLight = {
		Name = "Tactical Flashlight",
		Type = "Laser",
		Effects = {
			EnemyFlash = true, -- Blinds enemies when aimed at
			HipfireAccuracy = 0.9, -- 10% better hipfire
			Stealth = 0.7 -- 30% less stealthy
		},
		Cost = 250,
		UnlockLevel = 2
	}
end

-- Apply attachment effects to weapon
function WeaponAttachmentSystem.ApplyAttachment(weapon, attachmentId)
	local attachment = WeaponAttachmentSystem.Attachments[attachmentId]
	if not attachment then
		warn("Attachment not found: " .. attachmentId)
		return weapon
	end
	
	-- Clone weapon to avoid modifying original
	local modifiedWeapon = {}
	for key, value in pairs(weapon) do
		if type(value) == "table" then
			modifiedWeapon[key] = {}
			for subKey, subValue in pairs(value) do
				modifiedWeapon[key][subKey] = subValue
			end
		else
			modifiedWeapon[key] = value
		end
	end
	
	-- Apply effects
	for effect, multiplier in pairs(attachment.Effects) do
		if effect == "MagazineSize" then
			modifiedWeapon.MagazineSize = math.floor(modifiedWeapon.MagazineSize * multiplier)
		elseif effect == "ReloadTime" then
			modifiedWeapon.ReloadTime = modifiedWeapon.ReloadTime * multiplier
		elseif effect == "Range" then
			modifiedWeapon.Range = modifiedWeapon.Range * multiplier
		elseif effect == "Damage" then
			modifiedWeapon.Damage = math.floor(modifiedWeapon.Damage * multiplier)
		elseif effect == "VerticalRecoil" then
			if modifiedWeapon.Recoil then
				modifiedWeapon.Recoil.Vertical = modifiedWeapon.Recoil.Vertical * multiplier
			end
		elseif effect == "HorizontalRecoil" then
			if modifiedWeapon.Recoil then
				modifiedWeapon.Recoil.Horizontal = modifiedWeapon.Recoil.Horizontal * multiplier
			end
		elseif effect == "Recoil" then
			if modifiedWeapon.Recoil then
				modifiedWeapon.Recoil.Vertical = modifiedWeapon.Recoil.Vertical * multiplier
				modifiedWeapon.Recoil.Horizontal = modifiedWeapon.Recoil.Horizontal * multiplier
			end
		end
		-- Add more effect applications as needed
	end
	
	-- Add attachment to weapon's attachment list
	if not modifiedWeapon.Attachments then
		modifiedWeapon.Attachments = {}
	end
	table.insert(modifiedWeapon.Attachments, attachmentId)
	
	return modifiedWeapon
end

-- Get compatible attachments for weapon
function WeaponAttachmentSystem.GetCompatibleAttachments(weapon)
	local compatible = {}
	
	if weapon.AttachmentSlots then
		for slotType, allowed in pairs(weapon.AttachmentSlots) do
			if allowed then
				compatible[slotType] = {}
				
				for attachmentId, attachment in pairs(WeaponAttachmentSystem.Attachments) do
					if attachment.Type == slotType then
						table.insert(compatible[slotType], attachmentId)
					end
				end
			end
		end
	end
	
	return compatible
end

-- Calculate attachment loadout effects
function WeaponAttachmentSystem.CalculateLoadoutEffects(weapon, attachments)
	local finalWeapon = weapon
	
	for _, attachmentId in ipairs(attachments) do
		finalWeapon = WeaponAttachmentSystem.ApplyAttachment(finalWeapon, attachmentId)
	end
	
	return finalWeapon
end

-- Initialize the attachment system
WeaponAttachmentSystem.Initialize()

return WeaponAttachmentSystem
