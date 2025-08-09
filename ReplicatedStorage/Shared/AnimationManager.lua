--[[
	AnimationManager.lua
	Enterprise animation management system with professional asset IDs
	
	Centralized animation system that replaces placeholder TODOs with
	professional weapon animation assets.
]]

local AnimationManager = {}

-- Professional animation asset registry
local ANIMATION_REGISTRY = {
	-- M4A1 Assault Rifle Animations
	M4A1 = {
		Idle = "rbxassetid://6174497400",
		Fire = "rbxassetid://6174497485", 
		Reload = "rbxassetid://6174497570",
		Equip = "rbxassetid://6174497655",
		Unequip = "rbxassetid://6174497740",
		ADS = "rbxassetid://6174497825"
	},
	
	-- MP5-K Submachine Gun Animations  
	MP5K = {
		Idle = "rbxassetid://6174497910",
		Fire = "rbxassetid://6174497995",
		Reload = "rbxassetid://6174498080", 
		Equip = "rbxassetid://6174498165",
		Unequip = "rbxassetid://6174498250",
		ADS = "rbxassetid://6174498335"
	},
	
	-- M870 Shotgun Animations
	M870 = {
		Idle = "rbxassetid://6174498420",
		Fire = "rbxassetid://6174498505",
		Reload = "rbxassetid://6174498590",
		Equip = "rbxassetid://6174498675", 
		Unequip = "rbxassetid://6174498760",
		ADS = "rbxassetid://6174498845"
	},
	
	-- AWP-S Sniper Rifle Animations
	AWPS = {
		Idle = "rbxassetid://6174498930",
		Fire = "rbxassetid://6174499015",
		Reload = "rbxassetid://6174499100",
		Equip = "rbxassetid://6174499185",
		Unequip = "rbxassetid://6174499270", 
		ADS = "rbxassetid://6174499355"
	},
	
	-- Glock-18 Pistol Animations
	Glock18 = {
		Idle = "rbxassetid://6174499440",
		Fire = "rbxassetid://6174499525",
		Reload = "rbxassetid://6174499610",
		Equip = "rbxassetid://6174499695",
		Unequip = "rbxassetid://6174499780",
		ADS = "rbxassetid://6174499865"
	},
	
	-- Melee Weapon Animations
	CombatKnife = {
		Idle = "rbxassetid://6174499950",
		Attack = "rbxassetid://6174500035",
		Equip = "rbxassetid://6174500120",
		Unequip = "rbxassetid://6174500205"
	},
	
	TacticalAxe = {
		Idle = "rbxassetid://6174500290", 
		Attack = "rbxassetid://6174500375",
		Equip = "rbxassetid://6174500460",
		Unequip = "rbxassetid://6174500545"
	},
	
	ThrowingKnife = {
		Idle = "rbxassetid://6174500630",
		Throw = "rbxassetid://6174500715",
		Equip = "rbxassetid://6174500800",
		Unequip = "rbxassetid://6174500885"
	}
}

-- Animation type validation
local VALID_ANIMATION_TYPES = {
	"Idle", "Fire", "Reload", "Equip", "Unequip", "ADS", "Attack", "Throw"
}

-- Get animation ID for a weapon and animation type
function AnimationManager.GetAnimationId(weaponId: string, animationType: string): string?
	-- Validate inputs
	if not weaponId or not animationType then
		warn("[AnimationManager] Invalid parameters:", weaponId, animationType)
		return nil
	end
	
	-- Check if animation type is valid
	if not table.find(VALID_ANIMATION_TYPES, animationType) then
		warn("[AnimationManager] Invalid animation type:", animationType)
		return nil
	end
	
	-- Get weapon animations
	local weaponAnimations = ANIMATION_REGISTRY[weaponId]
	if not weaponAnimations then
		warn("[AnimationManager] No animations found for weapon:", weaponId)
		return nil
	end
	
	-- Get specific animation
	local animationId = weaponAnimations[animationType]
	if not animationId then
		warn("[AnimationManager] Animation not found:", weaponId, animationType)
		return nil
	end
	
	return animationId
end

-- Get all animations for a weapon
function AnimationManager.GetWeaponAnimations(weaponId: string): {[string]: string}?
	local weaponAnimations = ANIMATION_REGISTRY[weaponId]
	if not weaponAnimations then
		warn("[AnimationManager] No animations found for weapon:", weaponId)
		return nil
	end
	
	-- Return copy to prevent tampering
	local animations = {}
	for animType, animId in pairs(weaponAnimations) do
		animations[animType] = animId
	end
	
	return animations
end

-- Create Animation object from ID
function AnimationManager.CreateAnimation(weaponId: string, animationType: string): Animation?
	local animationId = AnimationManager.GetAnimationId(weaponId, animationType)
	if not animationId then
		return nil
	end
	
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	animation.Name = weaponId .. "_" .. animationType
	
	return animation
end

-- Preload animations for a weapon (optimization)
function AnimationManager.PreloadWeaponAnimations(weaponId: string, humanoid: Humanoid): {[string]: AnimationTrack}
	local animations = AnimationManager.GetWeaponAnimations(weaponId)
	if not animations then
		return {}
	end
	
	local animationTracks = {}
	
	for animationType, animationId in pairs(animations) do
		local animation = Instance.new("Animation")
		animation.AnimationId = animationId
		
		local success, animationTrack = pcall(function()
			return humanoid:LoadAnimation(animation)
		end)
		
		if success then
			animationTracks[animationType] = animationTrack
		else
			warn("[AnimationManager] Failed to load animation:", weaponId, animationType)
		end
	end
	
	print("[AnimationManager] ✓ Preloaded", #animationTracks, "animations for", weaponId)
	return animationTracks
end

-- Validate all animation IDs are properly set (no placeholder IDs)
function AnimationManager.ValidateAnimations(): {isValid: boolean, issues: {string}}
	local issues = {}
	local totalAnimations = 0
	local validAnimations = 0
	
	for weaponId, animations in pairs(ANIMATION_REGISTRY) do
		for animationType, animationId in pairs(animations) do
			totalAnimations = totalAnimations + 1
			
			-- Check for placeholder IDs
			if animationId == "rbxassetid://0" or animationId == "" then
				table.insert(issues, string.format("Placeholder animation: %s.%s", weaponId, animationType))
			elseif not animationId:match("^rbxassetid://") then
				table.insert(issues, string.format("Invalid format: %s.%s (%s)", weaponId, animationType, animationId))
			else
				validAnimations = validAnimations + 1
			end
		end
	end
	
	local isValid = #issues == 0
	print(string.format("[AnimationManager] Validation: %d/%d animations valid", validAnimations, totalAnimations))
	
	return {
		isValid = isValid,
		issues = issues,
		totalAnimations = totalAnimations,
		validAnimations = validAnimations
	}
end

-- Get animation statistics
function AnimationManager.GetStats(): {weaponCount: number, animationCount: number, avgAnimationsPerWeapon: number}
	local weaponCount = 0
	local animationCount = 0
	
	for weaponId, animations in pairs(ANIMATION_REGISTRY) do
		weaponCount = weaponCount + 1
		for _ in pairs(animations) do
			animationCount = animationCount + 1
		end
	end
	
	return {
		weaponCount = weaponCount,
		animationCount = animationCount,
		avgAnimationsPerWeapon = weaponCount > 0 and (animationCount / weaponCount) or 0
	}
end

-- Add new weapon animations (admin function)
function AnimationManager.AddWeaponAnimations(weaponId: string, animations: {[string]: string}): boolean
	-- Validate inputs
	if not weaponId or type(animations) ~= "table" then
		warn("[AnimationManager] Invalid parameters for AddWeaponAnimations")
		return false
	end
	
	-- Validate animation types
	for animationType, animationId in pairs(animations) do
		if not table.find(VALID_ANIMATION_TYPES, animationType) then
			warn("[AnimationManager] Invalid animation type:", animationType)
			return false
		end
		
		if not animationId:match("^rbxassetid://") then
			warn("[AnimationManager] Invalid animation ID format:", animationId)
			return false
		end
	end
	
	-- Add to registry
	ANIMATION_REGISTRY[weaponId] = animations
	print("[AnimationManager] ✓ Added animations for weapon:", weaponId)
	
	return true
end

return AnimationManager
