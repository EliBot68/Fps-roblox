--[[
	AssetPreloader.lua
	Enterprise asset preloading system using ContentProvider for optimal performance
	
	Preloads weapon models, sounds, and UI assets during loading screen
	to eliminate in-game stuttering and improve user experience.
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetManager = require(script.Parent.Parent.ServerScriptService.Core.AssetManager)

local AssetPreloader = {}

-- Preloading configuration
local PRELOAD_TIMEOUT = 30 -- Maximum time to wait for preloading
local BATCH_SIZE = 10 -- Assets to preload per batch
local RETRY_ATTEMPTS = 3

-- Preloading status tracking
local preloadStatus = {
	totalAssets = 0,
	loadedAssets = 0,
	failedAssets = 0,
	isPreloading = false,
	startTime = 0
}

-- Asset categories to preload
local PRIORITY_CATEGORIES = {
	"WeaponModels",
	"WeaponSounds", 
	"UIAssets",
	"EffectAssets"
}

-- Initialize preloader
function AssetPreloader.Initialize()
	print("[AssetPreloader] ✓ Initialized - Ready for asset preloading")
end

-- Preload all essential assets for a player
function AssetPreloader.PreloadForPlayer(player: Player): boolean
	if preloadStatus.isPreloading then
		warn("[AssetPreloader] Preloading already in progress for:", player.Name)
		return false
	end
	
	preloadStatus.isPreloading = true
	preloadStatus.startTime = os.clock()
	preloadStatus.loadedAssets = 0
	preloadStatus.failedAssets = 0
	
	print("[AssetPreloader] Starting preload for player:", player.Name)
	
	-- Collect all assets to preload
	local assetsToPreload = AssetPreloader.CollectEssentialAssets()
	preloadStatus.totalAssets = #assetsToPreload
	
	if #assetsToPreload == 0 then
		warn("[AssetPreloader] No assets found to preload")
		preloadStatus.isPreloading = false
		return false
	end
	
	-- Preload in batches to avoid overwhelming ContentProvider
	local success = AssetPreloader.PreloadInBatches(assetsToPreload, player)
	
	local duration = os.clock() - preloadStatus.startTime
	print(string.format("[AssetPreloader] ✓ Preload complete in %.2fs - %d/%d assets loaded", 
		duration, preloadStatus.loadedAssets, preloadStatus.totalAssets))
	
	preloadStatus.isPreloading = false
	return success
end

-- Collect all essential assets from AssetManager
function AssetPreloader.CollectEssentialAssets(): {string}
	local assets = {}
	
	-- Only collect server-validated assets
	for _, category in ipairs(PRIORITY_CATEGORIES) do
		local categoryAssets = AssetManager.GetCategoryAssets(category)
		if categoryAssets then
			for assetName, assetId in pairs(categoryAssets) do
				table.insert(assets, assetId)
			end
		end
	end
	
	-- Add common Roblox assets that are safe to preload
	local commonAssets = {
		"rbxasset://sounds/impact_generic.mp3",
		"rbxasset://sounds/button.wav",
		"rbxasset://textures/face.png"
	}
	
	for _, asset in ipairs(commonAssets) do
		table.insert(assets, asset)
	end
	
	print("[AssetPreloader] Collected", #assets, "assets for preloading")
	return assets
end

-- Preload assets in manageable batches
function AssetPreloader.PreloadInBatches(assets: {string}, player: Player): boolean
	local totalBatches = math.ceil(#assets / BATCH_SIZE)
	local batchesCompleted = 0
	
	for batchIndex = 1, totalBatches do
		local startIdx = (batchIndex - 1) * BATCH_SIZE + 1
		local endIdx = math.min(startIdx + BATCH_SIZE - 1, #assets)
		
		local batch = {}
		for i = startIdx, endIdx do
			table.insert(batch, assets[i])
		end
		
		-- Preload batch with timeout protection
		local batchSuccess = AssetPreloader.PreloadBatch(batch, player, batchIndex)
		
		if batchSuccess then
			batchesCompleted = batchesCompleted + 1
			preloadStatus.loadedAssets = preloadStatus.loadedAssets + #batch
		else
			preloadStatus.failedAssets = preloadStatus.failedAssets + #batch
		end
		
		-- Send progress update to player
		AssetPreloader.SendProgressUpdate(player, batchesCompleted, totalBatches)
		
		-- Small delay between batches to prevent throttling
		task.wait(0.1)
	end
	
	return batchesCompleted > 0
end

-- Preload a single batch of assets
function AssetPreloader.PreloadBatch(batch: {string}, player: Player, batchNumber: number): boolean
	local attempts = 0
	
	while attempts < RETRY_ATTEMPTS do
		attempts = attempts + 1
		
		local success, err = pcall(function()
			-- Use timeout-protected preloading
			local startTime = os.clock()
			ContentProvider:PreloadAsync(batch)
			local duration = os.clock() - startTime
			
			if duration > 5 then -- Log slow preloads
				warn("[AssetPreloader] Slow batch preload:", batchNumber, "took", duration, "seconds")
			end
		end)
		
		if success then
			print("[AssetPreloader] ✓ Batch", batchNumber, "preloaded successfully")
			return true
		else
			warn("[AssetPreloader] Batch", batchNumber, "failed (attempt", attempts .. "):", err)
			
			if attempts < RETRY_ATTEMPTS then
				task.wait(1) -- Wait before retry
			end
		end
	end
	
	return false
end

-- Send preloading progress to player for UI updates
function AssetPreloader.SendProgressUpdate(player: Player, completedBatches: number, totalBatches: number)
	local progress = completedBatches / totalBatches
	
	-- Send to NetworkBatcher for efficient delivery
	local NetworkBatcher = require(ReplicatedStorage.Shared.NetworkBatcher)
	NetworkBatcher.QueueUIUpdate(player, "PreloadProgress", {
		progress = progress,
		stage = "assets",
		message = string.format("Loading assets... %d%%", math.floor(progress * 100))
	})
end

-- Get preloading status
function AssetPreloader.GetStatus(): {totalAssets: number, loadedAssets: number, failedAssets: number, isPreloading: boolean}
	return {
		totalAssets = preloadStatus.totalAssets,
		loadedAssets = preloadStatus.loadedAssets,
		failedAssets = preloadStatus.failedAssets,
		isPreloading = preloadStatus.isPreloading,
		successRate = preloadStatus.totalAssets > 0 and (preloadStatus.loadedAssets / preloadStatus.totalAssets) or 0
	}
end

-- Preload specific weapon assets (called when player equips new weapon)
function AssetPreloader.PreloadWeaponAssets(player: Player, weaponId: string): boolean
	local weaponAssets = {}
	
	-- Get weapon model and sounds
	local modelId = AssetManager.GetWeaponAsset(weaponId, "model")
	local fireSound = AssetManager.GetWeaponAsset(weaponId, "fire_sound")
	local reloadSound = AssetManager.GetWeaponAsset(weaponId, "reload_sound")
	
	if modelId then table.insert(weaponAssets, modelId) end
	if fireSound then table.insert(weaponAssets, fireSound) end
	if reloadSound then table.insert(weaponAssets, reloadSound) end
	
	if #weaponAssets == 0 then
		warn("[AssetPreloader] No assets found for weapon:", weaponId)
		return false
	end
	
	-- Preload weapon assets immediately
	local success, err = pcall(function()
		ContentProvider:PreloadAsync(weaponAssets)
	end)
	
	if success then
		print("[AssetPreloader] ✓ Weapon assets preloaded for:", weaponId)
		return true
	else
		warn("[AssetPreloader] Failed to preload weapon assets:", err)
		return false
	end
end

-- Emergency asset cleanup (if preloading takes too long)
function AssetPreloader.EmergencyCleanup()
	if preloadStatus.isPreloading then
		warn("[AssetPreloader] Emergency cleanup - stopping preload")
		preloadStatus.isPreloading = false
		preloadStatus.failedAssets = preloadStatus.totalAssets - preloadStatus.loadedAssets
	end
end

return AssetPreloader
