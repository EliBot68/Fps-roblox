-- RankRewards.server.lua
-- Handles rank-based unlock gating and rewards

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStore = require(script.Parent.DataStore)
local RankManager = require(script.Parent.RankManager)
local CurrencyManager = require(script.Parent.Parent.Economy.CurrencyManager)
local Logging = require(ReplicatedStorage.Shared.Logging)

local RankRewards = {}

local RANK_UNLOCKS = {
	Bronze = { weapons = {}, cosmetics = {}, reward = 0 },
	Silver = { weapons = { "SMG" }, cosmetics = { "RedTrail" }, reward = 500 },
	Gold = { weapons = { "SMG", "Shotgun" }, cosmetics = { "RedTrail", "BlueTrail" }, reward = 1000 },
	Platinum = { weapons = { "SMG", "Shotgun", "Sniper" }, cosmetics = { "RedTrail", "BlueTrail", "GoldSkin" }, reward = 2000 },
	Diamond = { weapons = { "SMG", "Shotgun", "Sniper" }, cosmetics = { "RedTrail", "BlueTrail", "GoldSkin" }, reward = 5000 },
	Champion = { weapons = { "SMG", "Shotgun", "Sniper" }, cosmetics = { "RedTrail", "BlueTrail", "GoldSkin" }, reward = 10000 },
}

function RankRewards.CheckUnlocks(player)
	local tier = RankManager.GetTier(player)
	local profile = DataStore.Get(player)
	if not profile then return end
	
	local unlocks = RANK_UNLOCKS[tier]
	if not unlocks then return end
	
	local newUnlocks = {}
	
	-- Check weapon unlocks
	for _,weaponId in ipairs(unlocks.weapons) do
		if not profile.OwnedWeapons[weaponId] then
			profile.OwnedWeapons[weaponId] = true
			table.insert(newUnlocks, "Weapon: " .. weaponId)
		end
	end
	
	-- Check cosmetic unlocks
	for _,cosmeticId in ipairs(unlocks.cosmetics) do
		if not profile.OwnedCosmetics[cosmeticId] then
			profile.OwnedCosmetics[cosmeticId] = true
			table.insert(newUnlocks, "Cosmetic: " .. cosmeticId)
		end
	end
	
	-- Award rank-up currency
	if unlocks.reward > 0 and not profile["Rank_" .. tier .. "_Claimed"] then
		CurrencyManager.Award(player, unlocks.reward, "RankUp_" .. tier)
		profile["Rank_" .. tier .. "_Claimed"] = true
		table.insert(newUnlocks, "Currency: " .. unlocks.reward)
	end
	
	if #newUnlocks > 0 then
		DataStore.MarkDirty(player)
		Logging.Event("RankUnlock", { u = player.UserId, tier = tier, unlocks = newUnlocks })
	end
	
	return newUnlocks
end

function RankRewards.CanUseWeapon(player, weaponId)
	local tier = RankManager.GetTier(player)
	local unlocks = RANK_UNLOCKS[tier]
	if not unlocks then return false end
	
	for _,unlockedWeapon in ipairs(unlocks.weapons) do
		if unlockedWeapon == weaponId then return true end
	end
	
	return weaponId == "AssaultRifle" or weaponId == "Pistol" -- defaults
end

return RankRewards
