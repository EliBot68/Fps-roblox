--!strict
--[[
	WeaponService.lua
	Server-side weapon management and validation
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

-- Import dependencies
local CombatTypes = require(ReplicatedStorage.Shared.CombatTypes)
local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)
local AntiCheatService = require(ServerStorage.Services.AntiCheatService)
local AnalyticsService = require(ServerStorage.Services.AnalyticsService)

type WeaponInstance = CombatTypes.WeaponInstance
type WeaponConfig = CombatTypes.WeaponConfig -- Use unified type
type LoadoutData = CombatTypes.LoadoutData
local WeaponService = {}

-- Configuration
local WEAPON_CONFIG = {
	maxWeaponsPerPlayer = 3,
	respawnLoadoutDelay = 2.0, -- seconds
	weaponDropEnabled = true,
	weaponPickupRadius = 10, -- studs
	weaponDespawnTime = 30 -- seconds
}

-- Server state
local playerWeapons: {[Player]: {[number]: WeaponInstance}} = {}
local playerLoadouts: {[Player]: LoadoutData} = {}
local droppedWeapons: {[BasePart]: {weapon: WeaponInstance, dropTime: number}} = {}

-- Remote events
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("CombatEvents")
local equipWeaponRemote = remoteEvents:WaitForChild("EquipWeapon")
local dropWeaponRemote = remoteEvents:WaitForChild("DropWeapon")
local pickupWeaponRemote = remoteEvents:WaitForChild("PickupWeapon")

-- Initialize weapon service
function WeaponService.Initialize()
	-- Set up remote event handlers
	equipWeaponRemote.OnServerEvent:Connect(WeaponService.OnEquipWeapon)
	dropWeaponRemote.OnServerEvent:Connect(WeaponService.OnDropWeapon)
	pickupWeaponRemote.OnServerEvent:Connect(WeaponService.OnPickupWeapon)
	
	-- Set up player connections
	Players.PlayerAdded:Connect(WeaponService.OnPlayerAdded)
	Players.PlayerRemoving:Connect(WeaponService.OnPlayerRemoving)
	
	-- Set up cleanup loop
	RunService.Heartbeat:Connect(WeaponService.CleanupDroppedWeapons)
	
	print("[WeaponService] ✓ Initialized")
end

-- Handle player joining
function WeaponService.OnPlayerAdded(player: Player)
	playerWeapons[player] = {}
	playerLoadouts[player] = WeaponService.GetDefaultLoadout()
	
	-- Wait for character spawn then give weapons
	player.CharacterAdded:Connect(function(character)
		task.wait(WEAPON_CONFIG.respawnLoadoutDelay)
		WeaponService.GiveLoadoutWeapons(player)
	end)
end

-- Handle player leaving
function WeaponService.OnPlayerRemoving(player: Player)
	-- Drop all weapons
	if playerWeapons[player] then
		for slot, weapon in pairs(playerWeapons[player]) do
			WeaponService.DropWeapon(player, slot, true)
		end
	end
	
	-- Clean up data
	playerWeapons[player] = nil
	playerLoadouts[player] = nil
end

-- Handle weapon equip request
function WeaponService.OnEquipWeapon(player: Player, weaponID: string, slot: number)
	-- Validate request
	if not WeaponService.ValidateEquipRequest(player, weaponID, slot) then
		warn("[WeaponService] Invalid equip request from", player.Name)
		return
	end
	
	-- Get weapon configuration
	local weaponConfig = WeaponConfig.GetWeaponConfig(weaponID)
	if not weaponConfig then
		warn("[WeaponService] Unknown weapon ID:", weaponID)
		return
	end
	
	-- Create weapon instance
	local weaponInstance = WeaponService.CreateWeaponInstance(weaponConfig)
	
	-- Equip weapon
	WeaponService.EquipWeapon(player, weaponInstance, slot)
	
	-- Log for analytics
	AnalyticsService.LogEvent(player, "weapon_equipped", {
		weaponId = weaponID,
		slot = slot
	})
end

-- Handle weapon drop request
function WeaponService.OnDropWeapon(player: Player, slot: number)
	if not WEAPON_CONFIG.weaponDropEnabled then return end
	
	-- Validate request
	if not WeaponService.ValidateDropRequest(player, slot) then
		warn("[WeaponService] Invalid drop request from", player.Name)
		return
	end
	
	WeaponService.DropWeapon(player, slot, false)
end

-- Handle weapon pickup request
function WeaponService.OnPickupWeapon(player: Player, weaponPart: BasePart, slot: number)
	-- Validate pickup
	if not WeaponService.ValidatePickupRequest(player, weaponPart, slot) then
		warn("[WeaponService] Invalid pickup request from", player.Name)
		return
	end
	
	local droppedData = droppedWeapons[weaponPart]
	if not droppedData then return end
	
	-- Move weapon from ground to player
	WeaponService.EquipWeapon(player, droppedData.weapon, slot)
	
	-- Remove from dropped weapons
	droppedWeapons[weaponPart] = nil
	weaponPart:Destroy()
	
	-- Log pickup
	AnalyticsService.LogEvent(player, "weapon_picked_up", {
		weaponId = droppedData.weapon.config.id
	})
end

-- Create weapon instance from config
function WeaponService.CreateWeaponInstance(config: WeaponConfig): WeaponInstance
	return {
		config = config,
		attachments = {},
		currentAmmo = config.stats.magazineSize,
		totalAmmo = config.stats.maxAmmo - config.stats.magazineSize,
		condition = 1.0, -- Full condition (0-1)
		kills = 0,
		experience = 0,
		level = 1,
		lastFired = 0,
		isReloading = false,
		owner = nil
	}
end

-- Equip weapon to player slot
function WeaponService.EquipWeapon(player: Player, weapon: WeaponInstance, slot: number)
	if not playerWeapons[player] then
		playerWeapons[player] = {}
	end
	
	-- Drop existing weapon in slot
	if playerWeapons[player][slot] and WEAPON_CONFIG.weaponDropEnabled then
		WeaponService.DropWeapon(player, slot, true)
	end
	
	-- Equip new weapon
	playerWeapons[player][slot] = weapon
	
	-- Sync with client
	WeaponService.SyncWeaponToClient(player, weapon, slot)
end

-- Drop weapon from player slot
function WeaponService.DropWeapon(player: Player, slot: number, forced: boolean)
	if not playerWeapons[player] or not playerWeapons[player][slot] then
		return
	end
	
	local weapon = playerWeapons[player][slot]
	local character = player.Character
	
	if character and character:FindFirstChild("HumanoidRootPart") then
		-- Create dropped weapon model
		local weaponPart = WeaponService.CreateDroppedWeaponModel(weapon)
		local rootPart = character.HumanoidRootPart
		
		-- Position in front of player
		local dropPosition = rootPart.Position + rootPart.CFrame.LookVector * 3
		weaponPart.Position = dropPosition
		weaponPart.Parent = workspace
		
		-- Add physics
		local bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
		bodyVelocity.Velocity = rootPart.CFrame.LookVector * 10 + Vector3.new(0, 5, 0)
		bodyVelocity.Parent = weaponPart
		
		-- Remove velocity after short time
		task.wait(0.5)
		bodyVelocity:Destroy()
		
		-- Track dropped weapon
		droppedWeapons[weaponPart] = {
			weapon = weapon,
			dropTime = tick()
		}
	end
	
	-- Remove from player
	playerWeapons[player][slot] = nil
	
	-- Log drop
	if not forced then
		AnalyticsService.LogEvent(player, "weapon_dropped", {
			weaponId = weapon.config.id
		})
	end
end

-- Create visual model for dropped weapon
function WeaponService.CreateDroppedWeaponModel(weapon: WeaponInstance): BasePart
	local part = Instance.new("Part")
	part.Name = weapon.config.name .. "_Dropped"
	part.Size = Vector3.new(1, 0.2, 3) -- Approximate gun size
	part.Material = Enum.Material.Metal
	part.Color = Color3.new(0.3, 0.3, 0.3)
	part.Shape = Enum.PartType.Block
	part.CanCollide = true
	
	-- Add weapon icon/model here (future enhancement)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 100, 0, 50)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.Parent = part
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Text = weapon.config.name
	label.TextColor3 = Color3.new(1, 1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = gui
	
	return part
end

-- Give player their loadout weapons
function WeaponService.GiveLoadoutWeapons(player: Player)
	local loadout = playerLoadouts[player]
	if not loadout then return end
	
	-- Give primary weapon
	if loadout.primaryWeapon then
		local weapon = WeaponService.CreateWeaponInstance(
			WeaponConfig.GetWeaponConfig(loadout.primaryWeapon)
		)
		WeaponService.EquipWeapon(player, weapon, 1)
	end
	
	-- Give secondary weapon
	if loadout.secondaryWeapon then
		local weapon = WeaponService.CreateWeaponInstance(
			WeaponConfig.GetWeaponConfig(loadout.secondaryWeapon)
		)
		WeaponService.EquipWeapon(player, weapon, 2)
	end
	
	-- Give utility item
	if loadout.utilityItem then
		local weapon = WeaponService.CreateWeaponInstance(
			WeaponConfig.GetWeaponConfig(loadout.utilityItem)
		)
		WeaponService.EquipWeapon(player, weapon, 3)
	end
end

-- Sync weapon data to client
function WeaponService.SyncWeaponToClient(player: Player, weapon: WeaponInstance, slot: number)
	-- TODO: Implement client synchronization
	-- Send weapon data to client for UI updates and prediction
end

-- Get default loadout for new players
function WeaponService.GetDefaultLoadout(): LoadoutData
	return {
		primaryWeapon = "AK47",
		secondaryWeapon = "GLOCK17",
		utilityItem = "GRENADE",
		equipment = {}
	}
end

-- Validation functions
function WeaponService.ValidateEquipRequest(player: Player, weaponID: string, slot: number): boolean
	-- Check slot validity
	if slot < 1 or slot > WEAPON_CONFIG.maxWeaponsPerPlayer then
		return false
	end
	
	-- Check if player owns this weapon (from loadout or pickup)
	local loadout = playerLoadouts[player]
	if not loadout then 
		return false
	end
	
	-- For now, allow any weapon from config (future: check ownership)
	local weaponConfig = WeaponConfig.GetWeaponConfig(weaponID)
	return weaponConfig ~= nil
end

function WeaponService.ValidateDropRequest(player: Player, slot: number): boolean
	-- Check slot validity
	if slot < 1 or slot > WEAPON_CONFIG.maxWeaponsPerPlayer then
		return false
	end
	
	-- Check if player has weapon in slot
	return playerWeapons[player] and playerWeapons[player][slot] ~= nil
end

function WeaponService.ValidatePickupRequest(player: Player, weaponPart: BasePart, slot: number): boolean
	-- Check slot validity
	if slot < 1 or slot > WEAPON_CONFIG.maxWeaponsPerPlayer then
		return false
	end
	
	-- Check if weapon exists and is close enough
	local droppedData = droppedWeapons[weaponPart]
	if not droppedData then return false end
	
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return false
	end
	
	local distance = (character.HumanoidRootPart.Position - weaponPart.Position).Magnitude
	return distance <= WEAPON_CONFIG.weaponPickupRadius
end

-- Clean up old dropped weapons
function WeaponService.CleanupDroppedWeapons()
	local currentTime = tick()
	
	for weaponPart, data in pairs(droppedWeapons) do
		if currentTime - data.dropTime > WEAPON_CONFIG.weaponDespawnTime then
			droppedWeapons[weaponPart] = nil
			if weaponPart.Parent then
				weaponPart:Destroy()
			end
		end
	end
end

-- Get player weapon in slot
function WeaponService.GetPlayerWeapon(player: Player, slot: number): WeaponInstance?
	if playerWeapons[player] then
		return playerWeapons[player][slot]
	end
	return nil
end

-- Update player loadout
function WeaponService.UpdatePlayerLoadout(player: Player, newLoadout: LoadoutData)
	playerLoadouts[player] = newLoadout
	
	-- If player is alive, re-equip weapons
	if player.Character and player.Character:FindFirstChild("Humanoid") then
		-- Clear current weapons
		for slot = 1, WEAPON_CONFIG.maxWeaponsPerPlayer do
			playerWeapons[player][slot] = nil
		end
		
		-- Give new loadout
		WeaponService.GiveLoadoutWeapons(player)
	end
end

-- Consume ammo from weapon
function WeaponService.ConsumeAmmo(player: Player, slot: number, amount: number): boolean
	local weapon = WeaponService.GetPlayerWeapon(player, slot)
	if not weapon then return false end
	
	if weapon.currentAmmo >= amount then
		weapon.currentAmmo = weapon.currentAmmo - amount
		return true
	end
	
	return false
end

-- Reload weapon
function WeaponService.ReloadWeapon(player: Player, slot: number): {success: boolean, ammoCount: number}
	local weapon = WeaponService.GetPlayerWeapon(player, slot)
	if not weapon then
		return {success = false, ammoCount = 0}
	end
	
	-- Check if reload is needed and possible
	if weapon.currentAmmo >= weapon.config.magazineSize then
		return {success = false, ammoCount = weapon.currentAmmo}
	end
	
	if weapon.totalAmmo <= 0 then
		return {success = false, ammoCount = weapon.currentAmmo}
	end
	
	-- Calculate reload amount
	local ammoNeeded = weapon.config.magazineSize - weapon.currentAmmo
	local ammoToReload = math.min(ammoNeeded, weapon.totalAmmo)
	
	-- Perform reload
	weapon.currentAmmo = weapon.currentAmmo + ammoToReload
	weapon.totalAmmo = weapon.totalAmmo - ammoToReload
	
	-- Log reload
	AnalyticsService.LogEvent(player, "weapon_reloaded", {
		weaponId = weapon.config.id,
		ammoReloaded = ammoToReload
	})
	
	return {success = true, ammoCount = weapon.currentAmmo}
end

-- Get all player weapons
function WeaponService.GetPlayerWeapons(player: Player): {[number]: WeaponInstance}
	return playerWeapons[player] or {}
end

return WeaponService
