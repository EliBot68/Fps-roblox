--[[
	WeaponServer.lua
	Place in: ServerScriptService/WeaponServer/
	
	Server-authoritative weapon system handling all fire validation,
	damage calculation, ammo management, and anti-exploit measures.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Wait for weapon system modules
local WeaponSystem = ReplicatedStorage:WaitForChild("WeaponSystem")
local Modules = WeaponSystem:WaitForChild("Modules")
local WeaponDefinitions = require(Modules:WaitForChild("WeaponDefinitions"))
local WeaponUtils = require(Modules:WaitForChild("WeaponUtils"))

-- Import enterprise rate limiting
local Shared = ReplicatedStorage:WaitForChild("Shared")
local RateLimiter = require(Shared:WaitForChild("RateLimiter"))
local ObjectPool = require(Shared:WaitForChild("ObjectPool"))
local NetworkBatcher = require(Shared:WaitForChild("NetworkBatcher"))
local Scheduler = require(Shared:WaitForChild("Scheduler"))
local SpatialPartitioner = require(Shared:WaitForChild("SpatialPartitioner"))
local AssetPreloader = require(Shared:WaitForChild("AssetPreloader"))

local WeaponServer = {}

-- Initialize enterprise systems
ObjectPool.new("BulletEffects", function()
	local effect = Instance.new("Part")
	effect.Name = "BulletTrail"
	effect.Size = Vector3.new(0.1, 0.1, 2)
	effect.Material = Enum.Material.Neon
	effect.CanCollide = false
	effect.Anchored = true
	return effect
end)

ObjectPool.new("HitEffects", function()
	local effect = Instance.new("Explosion")
	effect.BlastRadius = 0
	effect.BlastPressure = 0
	return effect
end)

-- Initialize enterprise systems
NetworkBatcher.Initialize()
Scheduler.Initialize()
SpatialPartitioner.Initialize()
AssetPreloader.Initialize()

-- Player weapon states
local PlayerWeapons = {} -- [UserId] = {Primary, Secondary, Melee, CurrentSlot, Ammo}
local PlayerCooldowns = {} -- [UserId] = {LastFire, LastReload}
local PlayerRateLimiters = {} -- [UserId] = {FireLimiter, ReloadLimiter, SwitchLimiter}

-- RemoteEvents
local RemoteEvents = Instance.new("Folder")
RemoteEvents.Name = "WeaponEvents"
RemoteEvents.Parent = ReplicatedStorage

local FireWeaponRemote = Instance.new("RemoteEvent")
FireWeaponRemote.Name = "FireWeapon"
FireWeaponRemote.Parent = RemoteEvents

local ReloadWeaponRemote = Instance.new("RemoteEvent")
ReloadWeaponRemote.Name = "ReloadWeapon"
ReloadWeaponRemote.Parent = RemoteEvents

local SwitchWeaponRemote = Instance.new("RemoteEvent")
SwitchWeaponRemote.Name = "SwitchWeapon"
SwitchWeaponRemote.Parent = RemoteEvents

local WeaponStateRemote = Instance.new("RemoteEvent")
WeaponStateRemote.Name = "WeaponState"
WeaponStateRemote.Parent = RemoteEvents

-- Initialize player weapon loadout
function WeaponServer.InitializePlayer(player: Player)
	local userId = player.UserId
	
	-- Set up default loadout
	PlayerWeapons[userId] = {
		Primary = WeaponDefinitions.DefaultLoadout.Primary,
		Secondary = WeaponDefinitions.DefaultLoadout.Secondary,
		Melee = WeaponDefinitions.DefaultLoadout.Melee,
		CurrentSlot = "Primary",
		Ammo = {}
	}
	
	-- Initialize ammo for each weapon
	local loadout = PlayerWeapons[userId]
	for slot, weaponId in pairs({
		Primary = loadout.Primary,
		Secondary = loadout.Secondary,
		Melee = loadout.Melee
	}) do
		local weapon = WeaponDefinitions.GetWeapon(weaponId)
		if weapon then
			loadout.Ammo[weaponId] = weapon.MagazineSize
		end
	end
	
	-- Initialize cooldowns
	PlayerCooldowns[userId] = {
		LastFire = 0,
		LastReload = 0
	}
	
	-- Initialize enterprise rate limiters
	PlayerRateLimiters[userId] = {
		FireLimiter = RateLimiter.new(30, 5),      -- 30 shots max, refill 5/sec (300 RPM burst)
		ReloadLimiter = RateLimiter.new(10, 0.5),   -- 10 reloads max, refill 0.5/sec
		SwitchLimiter = RateLimiter.new(20, 2)      -- 20 switches max, refill 2/sec
	}
	
	-- Preload weapon assets for player
	task.spawn(function()
		AssetPreloader.PreloadForPlayer(player)
	end)
	
	-- Send initial weapon state to client
	WeaponStateRemote:FireClient(player, PlayerWeapons[userId])
	
	print("Initialized weapon loadout for", player.Name)
end

-- Clean up player data
function WeaponServer.CleanupPlayer(player: Player)
	local userId = player.UserId
	PlayerWeapons[userId] = nil
	PlayerCooldowns[userId] = nil
	PlayerRateLimiters[userId] = nil
end

-- Handle weapon firing
function WeaponServer.HandleFireWeapon(player: Player, weaponId: string, originCFrame: CFrame, direction: Vector3, clientTick: number)
	local userId = player.UserId
	local currentTime = tick()
	
	-- Validate player data
	local playerWeapons = PlayerWeapons[userId]
	local playerLimiters = PlayerRateLimiters[userId]
	if not playerWeapons or not playerLimiters then
		warn("No weapon data for player:", player.Name)
		return
	end
	
	-- Enterprise rate limiting - Check if player is muted
	if RateLimiter.isMuted(playerLimiters.FireLimiter) then
		-- Player is temporarily muted due to excessive violations
		return
	end
	
	-- Enterprise rate limiting - Consume fire token
	if not RateLimiter.consume(playerLimiters.FireLimiter, 1) then
		warn("Fire rate limit exceeded for player:", player.Name, "Status:", RateLimiter.getStatus(playerLimiters.FireLimiter))
		return
	end
	
	-- Get weapon configuration
	local weapon = WeaponDefinitions.GetWeapon(weaponId)
	if not weapon then
		warn("Invalid weapon ID:", weaponId)
		return
	end
	
	-- Validate weapon is equipped
	local currentWeapon = playerWeapons[playerWeapons.CurrentSlot]
	if currentWeapon ~= weaponId then
		warn("Weapon not equipped:", weaponId, "Current:", currentWeapon)
		return
	end
	
	-- Validate fire rate
	if not WeaponUtils.ValidateFireRate(player, weapon, currentTime) then
		warn("Fire rate exceeded for player:", player.Name)
		return
	end
	
	-- Validate shot direction
	if not WeaponUtils.ValidateDirection(player, direction) then
		warn("Invalid shot direction for player:", player.Name)
		return
	end
	
	-- Check ammo
	local currentAmmo = playerWeapons.Ammo[weaponId] or 0
	if currentAmmo <= 0 and weapon.MagazineSize > 0 then
		-- Send empty chamber feedback
		WeaponStateRemote:FireClient(player, {Type = "EmptyAmmo", WeaponId = weaponId})
		return
	end
	
	-- Consume ammo (except for melee weapons)
	if weapon.MagazineSize > 0 and weapon.MagazineSize < 999 then
		playerWeapons.Ammo[weaponId] = math.max(0, currentAmmo - 1)
	end
	
	-- Get player position for raycast origin validation
	local character = player.Character
	if not character then return end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end
	
	-- Use server-validated origin (prevent teleport exploits)
	local serverOrigin = humanoidRootPart.Position + Vector3.new(0, 1.5, 0) -- Eye level
	
	-- Ignore player's character for raycast
	local ignoreList = {character}
	
	-- Perform raycast(s)
	local hitResults = {}
	
	if weapon.PelletCount and weapon.PelletCount > 1 then
		-- Shotgun: Multiple pellets
		local pelletResults = WeaponUtils.ShotgunRaycast(
			serverOrigin,
			direction,
			weapon.PelletCount,
			weapon.Spread,
			weapon.Range,
			ignoreList
		)
		
		for _, result in ipairs(pelletResults) do
			if result then
				table.insert(hitResults, result)
			end
		end
	else
		-- Single projectile
		local spreadDirection = WeaponUtils.CalculateSpread(direction, weapon.Spread)
		local result = WeaponUtils.PerformRaycast(serverOrigin, spreadDirection, weapon.Range, ignoreList)
		
		if result then
			table.insert(hitResults, result)
		end
	end
	
	-- Process hits
	local hitData = {}
	
	for _, raycastResult in ipairs(hitResults) do
		local hitPosition = raycastResult.Position
		local hitPart = raycastResult.Instance
		local distance = (hitPosition - serverOrigin).Magnitude
		
		-- Check if hit a player
		local targetCharacter = hitPart.Parent
		local targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
		local targetPlayer = targetHumanoid and Players:GetPlayerFromCharacter(targetCharacter)
		
		if targetPlayer and targetPlayer ~= player then
			-- Player hit - calculate damage
			local isHeadshot = WeaponUtils.IsHeadshot(raycastResult, targetCharacter)
			local damage = WeaponUtils.CalculateDamage(
				weapon.Damage,
				distance,
				weapon.Range,
				weapon.HeadshotMultiplier,
				isHeadshot
			)
			
			-- Apply damage
			targetHumanoid.Health = math.max(0, targetHumanoid.Health - damage)
			
			-- Record hit data
			table.insert(hitData, {
				Type = "PlayerHit",
				Target = targetPlayer.Name,
				Damage = damage,
				Headshot = isHeadshot,
				Position = hitPosition
			})
			
			-- Check for elimination
			if targetHumanoid.Health <= 0 then
				WeaponServer.HandleElimination(player, targetPlayer, weaponId, isHeadshot)
			end
		else
			-- Environmental hit
			table.insert(hitData, {
				Type = "EnvironmentHit",
				Position = hitPosition,
				Normal = raycastResult.Normal,
				Material = hitPart.Material
			})
		end
	end
	
	-- Use enterprise network batching with spatial partitioning
	SpatialPartitioner.BroadcastToZones("WeaponFired", {
		shooter = player.Name,
		weapon = weaponId,
		hits = hitData,
		origin = serverOrigin,
		direction = direction,
		timestamp = tick()
	}, serverOrigin)
	
	-- Send updated ammo to firing player (immediate for responsive feel)
	NetworkBatcher.QueueUIUpdate(player, "AmmoUpdate", {
		WeaponId = weaponId,
		CurrentAmmo = playerWeapons.Ammo[weaponId],
		MaxAmmo = weapon.MagazineSize
	})
end

-- Handle weapon reload
function WeaponServer.HandleReloadWeapon(player: Player, weaponId: string)
	local userId = player.UserId
	local currentTime = tick()
	
	-- Validate player data
	local playerWeapons = PlayerWeapons[userId]
	local playerLimiters = PlayerRateLimiters[userId]
	if not playerWeapons or not playerLimiters then return end
	
	-- Enterprise rate limiting - Check reload limiter
	if RateLimiter.isMuted(playerLimiters.ReloadLimiter) then
		return -- Player temporarily muted
	end
	
	-- Enterprise rate limiting - Consume reload token
	if not RateLimiter.consume(playerLimiters.ReloadLimiter, 1) then
		warn("Reload rate limit exceeded for player:", player.Name)
		return
	end
	
	-- Get weapon configuration
	local weapon = WeaponDefinitions.GetWeapon(weaponId)
	if not weapon then return end
	
	-- Check if weapon can be reloaded
	if weapon.MagazineSize >= 999 then -- Infinite ammo weapons
		return
	end
	
	-- Check current ammo
	local currentAmmo = playerWeapons.Ammo[weaponId] or 0
	if currentAmmo >= weapon.MagazineSize then
		return -- Already full
	end
	
	-- Check reload cooldown
	local lastReload = PlayerCooldowns[userId].LastReload or 0
	if currentTime - lastReload < weapon.ReloadTime then
		return -- Still reloading
	end
	
	-- Start reload
	PlayerCooldowns[userId].LastReload = currentTime
	
	-- Send reload start to client
	WeaponStateRemote:FireClient(player, {
		Type = "ReloadStart",
		WeaponId = weaponId,
		ReloadTime = weapon.ReloadTime
	})
	
	-- Complete reload after delay
	task.spawn(function()
		task.wait(weapon.ReloadTime)
		
		-- Verify player still exists and has the weapon
		if PlayerWeapons[userId] then
			playerWeapons.Ammo[weaponId] = weapon.MagazineSize
			
			-- Send reload complete
			WeaponStateRemote:FireClient(player, {
				Type = "ReloadComplete",
				WeaponId = weaponId,
				CurrentAmmo = weapon.MagazineSize,
				MaxAmmo = weapon.MagazineSize
			})
		end
	end)
end

-- Handle weapon switching
function WeaponServer.HandleSwitchWeapon(player: Player, slot: string)
	local userId = player.UserId
	
	-- Validate player data
	local playerWeapons = PlayerWeapons[userId]
	local playerLimiters = PlayerRateLimiters[userId]
	if not playerWeapons or not playerLimiters then return end
	
	-- Enterprise rate limiting - Check switch limiter
	if RateLimiter.isMuted(playerLimiters.SwitchLimiter) then
		return -- Player temporarily muted
	end
	
	-- Enterprise rate limiting - Consume switch token
	if not RateLimiter.consume(playerLimiters.SwitchLimiter, 1) then
		warn("Weapon switch rate limit exceeded for player:", player.Name)
		return
	end
	
	-- Validate slot
	if not playerWeapons[slot] then return end
	
	-- Switch weapon
	playerWeapons.CurrentSlot = slot
	local weaponId = playerWeapons[slot]
	
	-- Send weapon switch confirmation
	WeaponStateRemote:FireClient(player, {
		Type = "WeaponSwitched",
		Slot = slot,
		WeaponId = weaponId,
		CurrentAmmo = playerWeapons.Ammo[weaponId] or 0,
		MaxAmmo = WeaponDefinitions.GetWeapon(weaponId).MagazineSize
	})
end

-- Handle player elimination
function WeaponServer.HandleElimination(killer: Player, victim: Player, weaponId: string, wasHeadshot: boolean)
	-- Send elimination event to game mode system
	local eliminationData = {
		Killer = killer.Name,
		Victim = victim.Name,
		Weapon = weaponId,
		Headshot = wasHeadshot,
		Timestamp = tick()
	}
	
	-- Broadcast elimination to all players
	for _, player in ipairs(Players:GetPlayers()) do
		WeaponStateRemote:FireClient(player, {
			Type = "PlayerEliminated",
			Data = eliminationData
		})
	end
	
	print(string.format("%s eliminated %s with %s%s", 
		killer.Name, 
		victim.Name, 
		weaponId, 
		wasHeadshot and " (HEADSHOT)" or ""
	))
end

-- Get player weapon state
function WeaponServer.GetPlayerWeapons(player: Player)
	return PlayerWeapons[player.UserId]
end

-- Set player weapon loadout (for game modes)
function WeaponServer.SetPlayerLoadout(player: Player, loadout: {Primary: string?, Secondary: string?, Melee: string?})
	local userId = player.UserId
	local playerWeapons = PlayerWeapons[userId]
	
	if not playerWeapons then
		WeaponServer.InitializePlayer(player)
		playerWeapons = PlayerWeapons[userId]
	end
	
	-- Update loadout
	for slot, weaponId in pairs(loadout) do
		if WeaponDefinitions.GetWeapon(weaponId) then
			playerWeapons[slot] = weaponId
			-- Reset ammo for new weapon
			local weapon = WeaponDefinitions.GetWeapon(weaponId)
			playerWeapons.Ammo[weaponId] = weapon.MagazineSize
		end
	end
	
	-- Send updated state to client
	WeaponStateRemote:FireClient(player, PlayerWeapons[userId])
end

-- Connect RemoteEvent handlers
FireWeaponRemote.OnServerEvent:Connect(WeaponServer.HandleFireWeapon)
ReloadWeaponRemote.OnServerEvent:Connect(WeaponServer.HandleReloadWeapon)
SwitchWeaponRemote.OnServerEvent:Connect(WeaponServer.HandleSwitchWeapon)

-- Connect player events
Players.PlayerAdded:Connect(WeaponServer.InitializePlayer)
Players.PlayerRemoving:Connect(WeaponServer.CleanupPlayer)

-- Initialize existing players
for _, player in ipairs(Players:GetPlayers()) do
	WeaponServer.InitializePlayer(player)
end

print("WeaponServer initialized")

return WeaponServer
