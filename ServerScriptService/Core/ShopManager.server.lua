-- ShopManager.server.lua
-- Handles cosmetic & weapon purchases and equipment

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataStore = require(script.Parent.DataStore)
local CurrencyManager = require(script.Parent.Parent.Economy.CurrencyManager)
local Logging = require(ReplicatedStorage.Shared.Logging)
local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)

local ShopManager = {}

local ITEMS = {
	-- weapon unlocks map to weapon ids in WeaponConfig
	Weapons = {
		SMG = WeaponConfig.SMG.Cost,
		Shotgun = WeaponConfig.Shotgun.Cost,
		Sniper = WeaponConfig.Sniper.Cost,
	},
	Cosmetics = {
		RedTrail = 300,
		BlueTrail = 300,
		GoldSkin = 1000,
	},
}

local function ensureProfile(plr)
	local profile = DataStore.Get(plr); if not profile then return end
	if not profile.OwnedCosmetics then profile.OwnedCosmetics = {} end
	if not profile.OwnedWeapons then profile.OwnedWeapons = { AssaultRifle = true } end
end

function ShopManager.PurchaseWeapon(plr, weaponId)
	ensureProfile(plr)
	if not WeaponConfig[weaponId] then return false, "Invalid" end
	local profile = DataStore.Get(plr); if not profile then return false, "NoProfile" end
	if profile.OwnedWeapons[weaponId] then return false, "Owned" end
	local cost = ITEMS.Weapons[weaponId]
	if not cost then return false, "NotForSale" end
	if not CurrencyManager.CanAfford(plr, cost) then return false, "NoFunds" end
	if not CurrencyManager.Spend(plr, cost, "BuyWeapon_"..weaponId) then return false, "SpendFail" end
	profile.OwnedWeapons[weaponId] = true
	DataStore.MarkDirty(plr)
	Logging.Event("PurchaseWeapon", { u = plr.UserId, w = weaponId, c = cost })
	return true
end

function ShopManager.PurchaseCosmetic(plr, cosmeticId)
	ensureProfile(plr)
	local profile = DataStore.Get(plr); if not profile then return false end
	if profile.OwnedCosmetics[cosmeticId] then return false, "Owned" end
	local cost = ITEMS.Cosmetics[cosmeticId]; if not cost then return false, "Invalid" end
	if not CurrencyManager.CanAfford(plr, cost) then return false, "NoFunds" end
	if not CurrencyManager.Spend(plr, cost, "Cosmetic_"..cosmeticId) then return false, "SpendFail" end
	profile.OwnedCosmetics[cosmeticId] = true
	DataStore.MarkDirty(plr)
	Logging.Event("PurchaseCosmetic", { u = plr.UserId, c = cosmeticId, cost = cost })
	return true
end

-- Remote wiring
local remoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
local shopFolder = remoteRoot:WaitForChild("ShopEvents")
local purchaseWeaponRE = shopFolder:WaitForChild("PurchaseItem")
local equipCosmeticRE = shopFolder:WaitForChild("EquipCosmetic")

purchaseWeaponRE.OnServerEvent:Connect(function(plr, kind, id)
	if kind == "Weapon" then
		ShopManager.PurchaseWeapon(plr, id)
	elseif kind == "Cosmetic" then
		ShopManager.PurchaseCosmetic(plr, id)
	end
end)

equipCosmeticRE.OnServerEvent:Connect(function(plr, cosmeticId)
	ensureProfile(plr)
	local profile = DataStore.Get(plr); if not profile then return end
	if not profile.OwnedCosmetics[cosmeticId] then return end
	profile.EquippedCosmetic = cosmeticId
	DataStore.MarkDirty(plr)
	Logging.Event("EquipCosmetic", { u = plr.UserId, c = cosmeticId })
end)

Players.PlayerAdded:Connect(ensureProfile)

return ShopManager
