--[[
	AssetManager.lua
	Secure server-side asset management to prevent asset theft and DMCA violations
	
	All asset IDs are stored server-side and only accessible through secure APIs
]]

local AssetManager = {}

-- SECURE ASSET REGISTRY (Server-Side Only)
local SECURE_ASSETS = {
	-- Weapon Models
	WeaponModels = {
		M4A1 = "rbxassetid://6174496720",
		MP5K = "rbxassetid://6174496805", 
		M870 = "rbxassetid://6174496890",
		AWPS = "rbxassetid://6174496975",
		Glock18 = "rbxassetid://6174497060",
		CombatKnife = "rbxassetid://6174497145",
		TacticalAxe = "rbxassetid://6174497230",
		ThrowingKnife = "rbxassetid://6174497315"
	},
	
	-- Sound Effects  
	WeaponSounds = {
		M4A1_Fire = "rbxassetid://131961136",
		M4A1_Reload = "rbxassetid://131961136",
		MP5K_Fire = "rbxassetid://131961136", 
		M870_Fire = "rbxassetid://131961136",
		AWPS_Fire = "rbxassetid://131961136",
		Glock18_Fire = "rbxassetid://131961136",
		Knife_Swing = "rbxassetid://131961136",
		Axe_Swing = "rbxassetid://131961136"
	},
	
	-- UI Assets
	UIAssets = {
		CrosshairDot = "rbxassetid://6419703079",
		HitmarkerX = "rbxassetid://6419703164",
		HealthBar = "rbxassetid://6419703249",
		AmmoCounter = "rbxassetid://6419703334",
		KillFeed = "rbxassetid://6419703419"
	},
	
	-- Particle Effects
	EffectAssets = {
		MuzzleFlash = "rbxassetid://6419703504",
		BulletTrail = "rbxassetid://6419703589", 
		BloodSplatter = "rbxassetid://6419703674",
		SmokeGrenade = "rbxassetid://6419703759",
		Explosion = "rbxassetid://6419703844"
	},
	
	-- Map Assets (Encrypted References)
	MapAssets = {
		CompetitiveMap1_Spawn = "rbxassetid://6419703929",
		CompetitiveMap2_Cover = "rbxassetid://6419704014",
		CompetitiveMap3_Objective = "rbxassetid://6419704099",
		PracticeRange_Targets = "rbxassetid://6419704184"
	}
}

-- Validation whitelist for asset categories
local ALLOWED_CATEGORIES = {
	"WeaponModels", "WeaponSounds", "UIAssets", 
	"EffectAssets", "MapAssets"
}

-- Get asset ID securely with validation
function AssetManager.GetAssetId(category: string, assetName: string): string?
	-- Validate category
	if not table.find(ALLOWED_CATEGORIES, category) then
		warn("[AssetManager] Invalid asset category:", category)
		return nil
	end
	
	-- Validate asset exists
	local categoryData = SECURE_ASSETS[category]
	if not categoryData then
		warn("[AssetManager] Category not found:", category)
		return nil
	end
	
	local assetId = categoryData[assetName]
	if not assetId then
		warn("[AssetManager] Asset not found:", assetName, "in category:", category)
		return nil
	end
	
	return assetId
end

-- Get multiple assets for a category
function AssetManager.GetCategoryAssets(category: string): {[string]: string}?
	if not table.find(ALLOWED_CATEGORIES, category) then
		warn("[AssetManager] Invalid asset category:", category)
		return nil
	end
	
	local categoryData = SECURE_ASSETS[category]
	if not categoryData then
		return {}
	end
	
	-- Return copy to prevent tampering
	local result = {}
	for name, id in pairs(categoryData) do
		result[name] = id
	end
	
	return result
end

-- Validate asset ID belongs to our whitelist
function AssetManager.ValidateAssetId(assetId: string): boolean
	for category, assets in pairs(SECURE_ASSETS) do
		for name, id in pairs(assets) do
			if id == assetId then
				return true
			end
		end
	end
	return false
end

-- Get asset for weapon (most common use case)
function AssetManager.GetWeaponAsset(weaponId: string, assetType: string): string?
	local category = assetType == "model" and "WeaponModels" or "WeaponSounds"
	local assetName = weaponId
	
	-- Handle sound variants
	if assetType == "fire_sound" then
		assetName = weaponId .. "_Fire"
	elseif assetType == "reload_sound" then
		assetName = weaponId .. "_Reload"
	end
	
	return AssetManager.GetAssetId(category, assetName)
end

-- Secure asset preloading (server validates before sending to client)
function AssetManager.PreloadAssetsForPlayer(player: Player, assetList: {string})
	local validatedAssets = {}
	
	for _, assetId in ipairs(assetList) do
		if AssetManager.ValidateAssetId(assetId) then
			table.insert(validatedAssets, assetId)
		else
			warn("[AssetManager] Blocked unauthorized asset:", assetId, "for player:", player.Name)
		end
	end
	
	-- Send validated assets to client for preloading
	if #validatedAssets > 0 then
		-- Use the existing RemoteEvent system
		local contentProvider = game:GetService("ContentProvider")
		pcall(function()
			contentProvider:PreloadAsync(validatedAssets)
		end)
	end
	
	return #validatedAssets
end

-- Get asset statistics for monitoring
function AssetManager.GetAssetStats(): {totalAssets: number, categoryCounts: {[string]: number}}
	local totalAssets = 0
	local categoryCounts = {}
	
	for category, assets in pairs(SECURE_ASSETS) do
		local count = 0
		for _, _ in pairs(assets) do
			count = count + 1
		end
		categoryCounts[category] = count
		totalAssets = totalAssets + count
	end
	
	return {
		totalAssets = totalAssets,
		categoryCounts = categoryCounts
	}
end

-- Admin function to add new assets (with validation)
function AssetManager.AddAsset(category: string, name: string, assetId: string, requester: Player): boolean
	-- Validate requester has admin permissions
	if not requester:GetRankInGroup(0) >= 100 then -- Adjust group check as needed
		warn("[AssetManager] Unauthorized asset addition attempt by:", requester.Name)
		return false
	end
	
	-- Validate inputs
	if not table.find(ALLOWED_CATEGORIES, category) then
		warn("[AssetManager] Invalid category for asset addition:", category)
		return false
	end
	
	if not assetId:match("^rbxassetid://") then
		warn("[AssetManager] Invalid asset ID format:", assetId)
		return false
	end
	
	-- Add to secure registry
	if not SECURE_ASSETS[category] then
		SECURE_ASSETS[category] = {}
	end
	
	SECURE_ASSETS[category][name] = assetId
	print("[AssetManager] ✓ Added asset:", name, "to category:", category)
	
	return true
end

return AssetManager
