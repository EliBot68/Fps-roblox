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
local CombatConstants = require(ReplicatedStorage.Shared.CombatConstants)
local Logger = require(ReplicatedStorage.Shared.Logger)
local AntiCheatService = require(ServerStorage.Services.AntiCheatService)
local AnalyticsService = require(ServerStorage.Services.AnalyticsService)

type WeaponInstance = CombatTypes.WeaponInstance
type WeaponConfig = CombatTypes.WeaponConfig -- Use unified type
type LoadoutData = CombatTypes.LoadoutData
type AttachmentConfig = CombatTypes.AttachmentConfig

local WeaponService = {}
local logger = Logger.new("WeaponService")

-- Configuration using centralized constants
local WEAPON_CONFIG = {
	maxWeaponsPerPlayer = CombatConstants.MAX_WEAPONS_PER_PLAYER,
	respawnLoadoutDelay = CombatConstants.RESPAWN_LOADOUT_DELAY,
	weaponDropEnabled = true,
	weaponPickupRadius = CombatConstants.WEAPON_PICKUP_RADIUS,
	weaponDespawnTime = CombatConstants.WEAPON_DESPAWN_TIME
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
local syncWeaponRemote = remoteEvents:WaitForChild("SyncWeapon")

-- Initialize weapon service
function WeaponService.Initialize()
	-- Initialize WeaponConfig system first
	local validationResults = WeaponConfig.Initialize()
	
	-- Validate all weapon configurations at startup  
	WeaponService.ValidateAllWeaponConfigs()
	
	-- Set up remote event handlers
	equipWeaponRemote.OnServerEvent:Connect(WeaponService.OnEquipWeapon)
	dropWeaponRemote.OnServerEvent:Connect(WeaponService.OnDropWeapon)
	pickupWeaponRemote.OnServerEvent:Connect(WeaponService.OnPickupWeapon)
	
	-- Set up player connections
	Players.PlayerAdded:Connect(WeaponService.OnPlayerAdded)
	Players.PlayerRemoving:Connect(WeaponService.OnPlayerRemoving)
	
	-- Set up cleanup loop
	RunService.Heartbeat:Connect(WeaponService.CleanupDroppedWeapons)
	
	logger:info("Weapon service initialized")
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
function WeaponService.CreateWeaponInstance(config: WeaponConfig, attachments: {[string]: AttachmentConfig}?): WeaponInstance
	local weaponInstance: WeaponInstance = {
		config = config,
		attachments = {},
		currentAmmo = config.stats.magazineSize,
		totalAmmo = config.stats.maxAmmo - config.stats.magazineSize,
		condition = CombatConstants.DEFAULT_WEAPON_CONDITION,
		kills = 0,
		experience = 0,
		level = 1,
		lastFired = 0,
		isReloading = false,
		owner = nil
	}
	
	-- Apply attachment modifiers if provided
	if attachments then
		weaponInstance = WeaponService.ApplyAttachmentModifiers(weaponInstance, attachments)
	end
	
	return weaponInstance
end

-- Apply attachment modifiers to weapon instance
function WeaponService.ApplyAttachmentModifiers(weaponInstance: WeaponInstance, attachments: {[string]: AttachmentConfig}): WeaponInstance
	-- Create a copy of the weapon stats to modify
	local modifiedStats = {}
	for key, value in pairs(weaponInstance.config.stats) do
		modifiedStats[key] = value
	end
	
	-- Apply each attachment's stat modifiers
	for attachmentType, attachment in pairs(attachments) do
		weaponInstance.attachments[attachmentType] = attachment.id
		
		-- Apply stat modifiers
		for statName, modifier in pairs(attachment.statModifiers) do
			if modifiedStats[statName] then
				-- Apply modifier (could be additive or multiplicative based on design)
				if statName == "damage" or statName == "fireRate" or statName == "magazineSize" then
					-- Additive modifiers
					modifiedStats[statName] = modifiedStats[statName] + modifier
				elseif statName == "accuracy" or statName == "reloadTime" then
					-- Multiplicative modifiers
					modifiedStats[statName] = modifiedStats[statName] * (1 + modifier)
				end
			end
		end
	end
	
	-- Create new config with modified stats
	local modifiedConfig = {}
	for key, value in pairs(weaponInstance.config) do
		modifiedConfig[key] = value
	end
	modifiedConfig.stats = modifiedStats
	
	weaponInstance.config = modifiedConfig
	
	logger:trace("Applied attachment modifiers", {
		weaponId = weaponInstance.config.id,
		attachmentCount = #attachments
	})
	
	-- Invalidate normalized cache for this weapon since stats changed
	WeaponConfig.RefreshCache(weaponInstance.config.id)
	
	return weaponInstance
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
	
	-- Give primary weapon with self-healing
	if loadout.primaryWeapon then
		local weaponConfig = WeaponConfig.GetWeaponConfig(loadout.primaryWeapon)
		if not weaponConfig then
			logger:warn("Primary weapon config missing, using fallback", {
				playerId = player.UserId,
				requestedWeapon = loadout.primaryWeapon
			})
			weaponConfig = WeaponService.GetFallbackWeaponConfig()
		end
		local weapon = WeaponService.CreateWeaponInstance(weaponConfig)
		WeaponService.EquipWeapon(player, weapon, 1)
	end
	
	-- Give secondary weapon with self-healing
	if loadout.secondaryWeapon then
		local weaponConfig = WeaponConfig.GetWeaponConfig(loadout.secondaryWeapon)
		if not weaponConfig then
			logger:warn("Secondary weapon config missing, using fallback", {
				playerId = player.UserId,
				requestedWeapon = loadout.secondaryWeapon
			})
			weaponConfig = WeaponService.GetFallbackWeaponConfig()
		end
		local weapon = WeaponService.CreateWeaponInstance(weaponConfig)
		WeaponService.EquipWeapon(player, weapon, 2)
	end
	
	-- Give utility item with self-healing
	if loadout.utilityItem then
		local weaponConfig = WeaponConfig.GetWeaponConfig(loadout.utilityItem)
		if not weaponConfig then
			logger:warn("Utility item config missing, skipping", {
				playerId = player.UserId,
				requestedWeapon = loadout.utilityItem
			})
		else
			local weapon = WeaponService.CreateWeaponInstance(weaponConfig)
			WeaponService.EquipWeapon(player, weapon, 3)
		end
	end
end

-- Sync weapon data to client
function WeaponService.SyncWeaponToClient(player: Player, weapon: WeaponInstance, slot: number)
	-- Send comprehensive weapon data to client for UI updates and prediction
	local weaponData = {
		weaponId = weapon.config.id,
		slot = slot,
		currentAmmo = weapon.currentAmmo,
		totalAmmo = weapon.totalAmmo,
		condition = weapon.condition,
		attachments = weapon.attachments,
		stats = weapon.config.stats,
		lastFired = weapon.lastFired,
		isReloading = weapon.isReloading
	}
	
	-- Send to specific player
	syncWeaponRemote:FireClient(player, weaponData)
	
	logger:trace("Synced weapon to client", {
		playerId = player.UserId,
		weaponId = weapon.config.id,
		slot = slot
	})
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

-- Get safe fallback weapon config
function WeaponService.GetFallbackWeaponConfig(): WeaponConfig
	-- Return a basic pistol config as fallback
	return {
		id = "FALLBACK_PISTOL",
		name = "Basic Pistol",
		displayName = "Basic Pistol",
		description = "Emergency fallback weapon",
		category = "Pistol",
		rarity = "Common",
		stats = {
			damage = 25,
			headshotMultiplier = 2.0,
			fireRate = 400,
			reloadTime = 2.0,
			magazineSize = 12,
			maxAmmo = 48,
			range = 100,
			accuracy = 0.8,
			recoilPattern = {Vector3.new(0, 2, 0)},
			damageDropoff = {},
			penetration = 0,
			muzzleVelocity = 300,
			weight = 1.5
		},
		attachmentSlots = {},
		unlockLevel = 1,
		cost = 0,
		modelId = "",
		iconId = "",
		sounds = {
			fire = "", dryFire = "", reload = "", reloadEmpty = "",
			draw = "", holster = "", hit = "", miss = ""
		},
		animations = {
			idle = "", fire = "", reload = "", reloadEmpty = "",
			draw = "", holster = "", inspect = "", melee = ""
		},
		effects = {
			muzzleFlash = "", shellEject = "", bulletTrail = "",
			impactEffects = {}, smokePuff = ""
		}
	}
end

-- Validate all weapon configurations at startup
function WeaponService.ValidateAllWeaponConfigs()
	local allWeapons = WeaponConfig.GetAllWeapons()
	local validCount = 0
	local invalidCount = 0
	
	for weaponId, weaponConfig in pairs(allWeapons) do
		if WeaponConfig.ValidateWeapon(weaponConfig) then
			validCount = validCount + 1
		else
			invalidCount = invalidCount + 1
			logger:error("Invalid weapon configuration detected", {
				weaponId = weaponId,
				weaponName = weaponConfig.name
			})
		end
	end
	
	logger:info("Weapon configuration validation complete", {
		validWeapons = validCount,
		invalidWeapons = invalidCount,
		totalWeapons = validCount + invalidCount
	})
	
	if invalidCount > 0 then
		logger:warn("Some weapon configurations are invalid and may cause issues")
	end
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
