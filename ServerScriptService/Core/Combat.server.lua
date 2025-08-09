-- Combat.server.lua
-- Enterprise combat system with advanced damage calculation and validation

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)
local Utilities = require(ReplicatedStorage.Shared.Utilities)
local Matchmaker = require(script.Parent.Matchmaker)
local Logging = require(ReplicatedStorage.Shared.Logging)
local Metrics = require(script.Parent.Metrics)
local AntiCheat = require(script.Parent.AntiCheat)
local KillStreakManager = require(script.Parent.KillStreakManager)
local RemoteValidator = require(ReplicatedStorage.Shared.RemoteValidator)
local ReplayRecorder = require(script.Parent.ReplayRecorder)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local RateLimiter = require(script.Parent.RateLimiter)
local RankRewards = require(script.Parent.RankRewards)

-- Ensure remote references
local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
local CombatEvents = RemoteRoot:WaitForChild("CombatEvents")
local UIEvents = RemoteRoot:WaitForChild("UIEvents")
local FireWeaponRemote = CombatEvents:WaitForChild("FireWeapon", 5)
local ReportHitRemote = CombatEvents:WaitForChild("ReportHit", 5)
local RequestReloadRemote = CombatEvents:FindFirstChild("RequestReload") or Instance.new("RemoteEvent")
RequestReloadRemote.Name = "RequestReload"; RequestReloadRemote.Parent = CombatEvents
local UpdateStatsRemote = UIEvents:FindFirstChild("UpdateStats") or Instance.new("RemoteEvent")
UpdateStatsRemote.Name = "UpdateStats"; UpdateStatsRemote.Parent = UIEvents
local SwitchWeaponRemote = CombatEvents:FindFirstChild("SwitchWeapon") or Instance.new("RemoteEvent")
SwitchWeaponRemote.Name = "SwitchWeapon"; SwitchWeaponRemote.Parent = CombatEvents

local Combat = {}

-- Combat constants
local MAX_HEALTH = 100
local HEADSHOT_MULTIPLIER = 1.5
local DAMAGE_FALLOFF_ENABLED = true
local PENETRATION_ENABLED = true

-- Player state management
local playerHealth = {}
local playerState = {}
local damageHistory = {} -- For anti-cheat analysis

-- Advanced combat metrics
local combatMetrics = {
	totalShots = 0,
	totalHits = 0,
	totalKills = 0,
	averageDamagePerShot = 0,
	headshotPercentage = 0,
	weaponUsageStats = {}
}

-- Damage zones with multipliers
local DAMAGE_ZONES = {
	Head = 1.5,
	UpperTorso = 1.0,
	LowerTorso = 0.9,
	LeftArm = 0.8,
	RightArm = 0.8,
	LeftLeg = 0.7,
	RightLeg = 0.7
}

local function initPlayer(player)
	if not playerState[player] then
		local defaultWeapon = WeaponConfig.AssaultRifle
		playerState[player] = {
			lastFire = 0,
			weapon = defaultWeapon.Id,
			ammo = defaultWeapon.MagazineSize,
			reserve = defaultWeapon.MagazineSize * 4,
			kills = 0,
			deaths = 0,
			assists = 0,
			damage = 0,
			accuracy = 0,
			headshots = 0,
			totalShots = 0,
			hitShots = 0,
			killStreak = 0,
			longestKillStreak = 0,
			inventory = { "AssaultRifle", "Pistol" },
			weaponAmmo = {}, -- Per-weapon ammo tracking
			lastDamageTime = {},
			reloadStartTime = 0,
			isReloading = false
		}
	end
	
	if not playerHealth[player] then
		playerHealth[player] = MAX_HEALTH
	end
	
	if not damageHistory[player] then
		damageHistory[player] = {}
	end
end

local function getWeaponStats(weaponId)
	return WeaponConfig[weaponId]
end

local function calculateDamage(weaponId, distance, hitPart, isHeadshot)
	local weapon = getWeaponStats(weaponId)
	if not weapon then return 0 end
	
	local baseDamage = weapon.Damage
	
	-- Apply headshot multiplier
	if isHeadshot then
		baseDamage = baseDamage * weapon.HeadshotMultiplier
	else
		-- Apply body part multiplier
		local zoneMultiplier = DAMAGE_ZONES[hitPart] or 1.0
		baseDamage = baseDamage * zoneMultiplier
	end
	
	-- Apply range falloff
	if DAMAGE_FALLOFF_ENABLED then
		local effectiveness = WeaponConfig.GetEffectivenessAtRange(weaponId, distance)
		baseDamage = baseDamage * effectiveness
	end
	
	-- Apply penetration (simplified)
	if PENETRATION_ENABLED and weapon.Penetration then
		baseDamage = baseDamage * weapon.Penetration
	end
	
	return math.floor(baseDamage)
end

local function updatePlayerStats(player)
	local state = playerState[player]
	if not state then return end
	
	-- Calculate accuracy
	if state.totalShots > 0 then
		state.accuracy = (state.hitShots / state.totalShots) * 100
	end
	
	UpdateStatsRemote:FireClient(player, {
		Health = playerHealth[player],
		MaxHealth = MAX_HEALTH,
		Ammo = state.ammo,
		Reserve = state.reserve,
		Weapon = state.weapon,
		Kills = state.kills,
		Deaths = state.deaths,
		Assists = state.assists,
		Damage = state.damage,
		Accuracy = Utilities.Round(state.accuracy, 1),
		Headshots = state.headshots,
		KillStreak = state.killStreak,
		LongestKillStreak = state.longestKillStreak,
		IsReloading = state.isReloading
	})
end

local function respawnPlayer(player)
	task.wait(GameConfig.Respawn.Delay)
	
	if playerHealth[player] then
		playerHealth[player] = MAX_HEALTH
		
		-- Apply respawn invulnerability
		if GameConfig.Respawn.InvulnerabilityTime > 0 then
			local state = playerState[player]
			if state then
				state.invulnerableUntil = tick() + GameConfig.Respawn.InvulnerabilityTime
			end
		end
		
		updatePlayerStats(player)
		
		Logging.Event("PlayerRespawned", {
			u = player.UserId,
			health = playerHealth[player]
		})
	end
end

function Combat.Fire(player, origin, direction, weaponId)
	initPlayer(player)
	local state = playerState[player]
	local weapon = getWeaponStats(weaponId or state.weapon)
	
	if not weapon then return false, "Invalid weapon" end
	if state.ammo <= 0 then return false, "Empty magazine" end
	if state.isReloading then return false, "Reloading" end
	
	-- Rate limiting with weapon-specific cooldown
	local now = tick()
	local cooldown = 1 / weapon.FireRate
	if now - state.lastFire < cooldown then return false, "Rate limited" end
	
	-- Check invulnerability
	if state.invulnerableUntil and now < state.invulnerableUntil then
		state.invulnerableUntil = nil -- Remove on attack
	end
	
	state.lastFire = now
	state.ammo = state.ammo - 1
	state.totalShots = state.totalShots + 1
	
	-- Update global metrics
	combatMetrics.totalShots = combatMetrics.totalShots + 1
	if not combatMetrics.weaponUsageStats[weapon.Id] then
		combatMetrics.weaponUsageStats[weapon.Id] = { shots = 0, hits = 0, kills = 0 }
	end
	combatMetrics.weaponUsageStats[weapon.Id].shots = combatMetrics.weaponUsageStats[weapon.Id].shots + 1
	
	Logging.Event("FireAttempt", { 
		u = player.UserId, 
		w = weapon.Id, 
		ammo = state.ammo,
		origin = origin,
		direction = direction
	})
	
	ReplayRecorder.Log("Fire", { 
		u = player.UserId, 
		w = weapon.Id,
		pos = origin,
		dir = direction,
		time = now
	})
	
	Metrics.Inc("ShotsFired")
	AntiCheat.RecordShot(player, weapon.Id, origin, direction)
	
	local startTime = os.clock()
	
	-- Perform raycast
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { player.Character }
	
	local rayResult = workspace:Raycast(origin, direction.Unit * weapon.Range, raycastParams)
	
	if rayResult and rayResult.Instance then
		local hitCharacter = rayResult.Instance:FindFirstAncestorWhichIsA("Model")
		if hitCharacter and hitCharacter:FindFirstChild("Humanoid") then
			local targetPlayer = Players:GetPlayerFromCharacter(hitCharacter)
			if targetPlayer and targetPlayer ~= player then
				initPlayer(targetPlayer)
				local targetState = playerState[targetPlayer]
				
				-- Check target invulnerability
				if targetState.invulnerableUntil and now < targetState.invulnerableUntil then
					updatePlayerStats(player)
					return true, { ammo = state.ammo, hit = false, reason = "invulnerable" }
				end
				
				local distance = (rayResult.Position - origin).Magnitude
				local hitPart = rayResult.Instance.Name
				local isHeadshot = hitPart == "Head"
				
				local damage = calculateDamage(weapon.Id, distance, hitPart, isHeadshot)
				
				-- Apply damage
				playerHealth[targetPlayer] = playerHealth[targetPlayer] - damage
				state.hitShots = state.hitShots + 1
				state.damage = state.damage + damage
				
				if isHeadshot then
					state.headshots = state.headshots + 1
				end
				
				-- Track damage for assists
				if not state.lastDamageTime[targetPlayer.UserId] then
					state.lastDamageTime[targetPlayer.UserId] = now
				else
					state.lastDamageTime[targetPlayer.UserId] = now
				end
				
				-- Record hit for anti-cheat
				AntiCheat.RecordHit(player, isHeadshot, distance, weapon.Id)
				
				combatMetrics.totalHits = combatMetrics.totalHits + 1
				combatMetrics.weaponUsageStats[weapon.Id].hits = combatMetrics.weaponUsageStats[weapon.Id].hits + 1
				
				Logging.Event("PlayerHit", {
					attacker = player.UserId,
					victim = targetPlayer.UserId,
					weapon = weapon.Id,
					damage = damage,
					distance = distance,
					headshot = isHeadshot,
					hitPart = hitPart
				})
				
				-- Check for elimination
				if playerHealth[targetPlayer] <= 0 then
					Combat.ProcessElimination(player, targetPlayer, weapon, isHeadshot, distance)
				end
				
				updatePlayerStats(targetPlayer)
			end
		else
			-- Hit environment
			ReplayRecorder.Log("EnvironmentHit", {
				u = player.UserId,
				pos = rayResult.Position,
				normal = rayResult.Normal
			})
		end
	end
	
	Metrics.Observe("FireValidationLatency", os.clock() - startTime)
	updatePlayerStats(player)
	
	return true, { 
		ammo = state.ammo, 
		hit = rayResult ~= nil,
		hitPosition = rayResult and rayResult.Position or nil
	}
end

function Combat.ProcessElimination(killer, victim, weapon, isHeadshot, distance)
	local killerState = playerState[killer]
	local victimState = playerState[victim]
	
	killerState.kills = killerState.kills + 1
	killerState.killStreak = killerState.killStreak + 1
	killerState.longestKillStreak = math.max(killerState.longestKillStreak, killerState.killStreak)
	
	victimState.deaths = victimState.deaths + 1
	victimState.killStreak = 0
	
	-- Process assists (players who damaged victim in last 5 seconds)
	local assistWindow = 5
	local currentTime = tick()
	
	for assistPlayer, _ in pairs(playerState) do
		if assistPlayer ~= killer and assistPlayer ~= victim then
			local assistState = playerState[assistPlayer]
			if assistState.lastDamageTime[victim.UserId] and 
			   currentTime - assistState.lastDamageTime[victim.UserId] <= assistWindow then
				assistState.assists = assistState.assists + 1
				
				Logging.Event("Assist", {
					assistant = assistPlayer.UserId,
					killer = killer.UserId,
					victim = victim.UserId
				})
			end
		end
	end
	
	-- Clear damage tracking for victim
	for _, state in pairs(playerState) do
		state.lastDamageTime[victim.UserId] = nil
	end
	
	combatMetrics.totalKills = combatMetrics.totalKills + 1
	combatMetrics.weaponUsageStats[weapon.Id].kills = combatMetrics.weaponUsageStats[weapon.Id].kills + 1
	
	print(string.format("%s eliminated %s with %s (Distance: %.1fm%s)", 
		killer.Name, 
		victim.Name, 
		weapon.Name or weapon.Id,
		distance,
		isHeadshot and " - HEADSHOT" or ""
	))
	
	Logging.Event("Elimination", {
		killer = killer.UserId,
		victim = victim.UserId,
		weapon = weapon.Id,
		headshot = isHeadshot,
		distance = distance,
		killerStreak = killerState.killStreak
	})
	
	ReplayRecorder.Log("Elimination", {
		k = killer.UserId,
		v = victim.UserId,
		w = weapon.Id,
		head = isHeadshot,
		dist = distance,
		time = tick()
	})
	
	Metrics.Inc("Eliminations")
	
	-- Trigger external systems
	if Matchmaker.OnPlayerKill then
		Matchmaker.OnPlayerKill(killer, victim)
	end
	
	if KillStreakManager.OnKill then
		KillStreakManager.OnKill(killer, victim)
	end
	
	if KillStreakManager.Reset then
		KillStreakManager.Reset(victim)
	end
	
	-- Respawn victim
	spawn(function()
		respawnPlayer(victim)
	end)
end

function Combat.Reload(player)
	initPlayer(player)
	local state = playerState[player]
	local weapon = getWeaponStats(state.weapon)
	
	if state.ammo >= weapon.MagazineSize then return false, "Magazine full" end
	if state.reserve <= 0 then return false, "No reserve ammo" end
	if state.isReloading then return false, "Already reloading" end
	
	state.isReloading = true
	state.reloadStartTime = tick()
	
	Logging.Event("ReloadStarted", {
		u = player.UserId,
		weapon = state.weapon,
		currentAmmo = state.ammo,
		reserveAmmo = state.reserve
	})
	
	-- Reload timer
	spawn(function()
		wait(weapon.ReloadTime)
		
		if state.isReloading then -- Check if reload wasn't interrupted
			local needed = weapon.MagazineSize - state.ammo
			local taken = math.min(needed, state.reserve)
			
			state.ammo = state.ammo + taken
			state.reserve = state.reserve - taken
			state.isReloading = false
			
			Logging.Event("ReloadCompleted", {
				u = player.UserId,
				weapon = state.weapon,
				newAmmo = state.ammo,
				remainingReserve = state.reserve
			})
			
			updatePlayerStats(player)
		end
	end)
	
	updatePlayerStats(player)
	return true, { ammo = state.ammo, reserve = state.reserve, reloadTime = weapon.ReloadTime }
end

function Combat.SwitchWeapon(player, newWeaponId)
	initPlayer(player)
	local state = playerState[player]
	
	-- Validate weapon exists
	local newWeapon = getWeaponStats(newWeaponId)
	if not newWeapon then return false, "Invalid weapon" end
	
	-- Check if player can use this weapon
	if not RankRewards.CanUseWeapon(player, newWeaponId) then
		return false, "Weapon locked - insufficient rank"
	end
	
	-- Check inventory
	if not Utilities.TableContains(state.inventory, newWeaponId) then
		return false, "Weapon not in inventory"
	end
	
	if state.weapon == newWeaponId then 
		return false, "Already equipped"
	end
	
	-- Cancel reload if switching
	if state.isReloading then
		state.isReloading = false
	end
	
	-- Save current weapon ammo
	if not state.weaponAmmo[state.weapon] then
		state.weaponAmmo[state.weapon] = {}
	end
	state.weaponAmmo[state.weapon].ammo = state.ammo
	state.weaponAmmo[state.weapon].reserve = state.reserve
	
	-- Switch to new weapon
	state.weapon = newWeaponId
	
	-- Restore or initialize ammo for new weapon
	if state.weaponAmmo[newWeaponId] then
		state.ammo = state.weaponAmmo[newWeaponId].ammo
		state.reserve = state.weaponAmmo[newWeaponId].reserve
	else
		state.ammo = newWeapon.MagazineSize
		state.reserve = newWeapon.MagazineSize * 4
	end
	
	Logging.Event("WeaponSwitched", {
		u = player.UserId,
		from = state.weapon,
		to = newWeaponId
	})
	
	updatePlayerStats(player)
	return true, { weapon = newWeaponId, ammo = state.ammo, reserve = state.reserve }
end

function Combat.GetCombatMetrics()
	local metrics = Utilities.DeepCopy(combatMetrics)
	
	-- Calculate derived metrics
	if combatMetrics.totalShots > 0 then
		metrics.hitPercentage = (combatMetrics.totalHits / combatMetrics.totalShots) * 100
	end
	
	if combatMetrics.totalHits > 0 then
		metrics.killsPerHit = combatMetrics.totalKills / combatMetrics.totalHits
	end
	
	return metrics
end

-- Remote event handlers
if FireWeaponRemote then
	FireWeaponRemote.OnServerEvent:Connect(function(player, origin, direction, weaponId)
		if not RateLimiter.Consume(player, "Fire", 1) then return end
		
		local valid, reason = RemoteValidator.ValidatePlayerAction(player, "FireWeapon", {origin, direction, weaponId})
		if not valid then
			Logging.Warn("Combat", "Invalid fire from " .. player.Name .. ": " .. reason)
			return
		end
		
		Combat.Fire(player, origin, direction, weaponId)
	end)
end

if ReportHitRemote then
	ReportHitRemote.OnServerEvent:Connect(function(player, origin, direction, hitPosition, hitPart, distance)
		if not RateLimiter.Consume(player, "ReportHit", 1) then return end
		
		local valid, reason = RemoteValidator.ValidatePlayerAction(player, "ReportHit", {origin, direction, hitPosition, hitPart, distance})
		if not valid then
			Logging.Warn("Combat", "Invalid hit report from " .. player.Name .. ": " .. reason)
			return
		end
		
		-- Process client-side hit report for additional validation
		AntiCheat.ValidateHitReport(player, origin, direction, hitPosition, hitPart, distance)
	end)
end

RequestReloadRemote.OnServerEvent:Connect(function(player)
	if not RateLimiter.Consume(player, "Reload", 1) then return end
	Combat.Reload(player)
end)

SwitchWeaponRemote.OnServerEvent:Connect(function(player, weaponId)
	if not RateLimiter.Consume(player, "Switch", 1) then return end
	
	local valid, reason = RemoteValidator.ValidateWeaponId(weaponId)
	if not valid then
		Logging.Warn("Combat", "Invalid weapon switch from " .. player.Name .. ": " .. reason)
		return
	end
	
	Combat.SwitchWeapon(player, weaponId)
end)

-- Player management
Players.PlayerAdded:Connect(function(player)
	initPlayer(player)
	updatePlayerStats(player)
end)

Players.PlayerRemoving:Connect(function(player)
	-- Cleanup
	playerState[player] = nil
	playerHealth[player] = nil
	damageHistory[player] = nil
end)

-- Performance monitoring
spawn(function()
	while true do
		wait(60) -- Every minute
		
		local metrics = Combat.GetCombatMetrics()
		Logging.Event("CombatMetrics", metrics)
		
		-- Weapon balance analysis
		for weaponId, stats in pairs(metrics.weaponUsageStats) do
			if stats.shots > 0 then
				local accuracy = (stats.hits / stats.shots) * 100
				local lethality = stats.hits > 0 and (stats.kills / stats.hits) * 100 or 0
				
				Logging.Event("WeaponBalance", {
					weapon = weaponId,
					accuracy = accuracy,
					lethality = lethality,
					usage = stats.shots
				})
			end
		end
	end
end)

print("[Combat] Enterprise combat system initialized")
return Combat
