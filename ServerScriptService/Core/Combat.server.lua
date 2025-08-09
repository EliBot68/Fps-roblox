-- Combat.server.lua
-- Validates shots and applies damage

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)
local Matchmaker = require(script.Parent.Matchmaker)
local Logging = require(ReplicatedStorage.Shared.Logging)
local Metrics = require(script.Parent.Metrics)
local AntiCheat = require(script.Parent.AntiCheat)
local KillStreakManager = require(script.Parent.KillStreakManager)

-- Ensure remote references
local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
local CombatEvents = RemoteRoot:WaitForChild("CombatEvents")
local UIEvents = RemoteRoot:WaitForChild("UIEvents")
local FireWeaponRemote = CombatEvents:WaitForChild("FireWeapon", 5)
local RequestReloadRemote = CombatEvents:FindFirstChild("RequestReload") or Instance.new("RemoteEvent")
RequestReloadRemote.Name = "RequestReload"; RequestReloadRemote.Parent = CombatEvents
local UpdateStatsRemote = UIEvents:FindFirstChild("UpdateStats") or Instance.new("RemoteEvent")
UpdateStatsRemote.Name = "UpdateStats"; UpdateStatsRemote.Parent = UIEvents
local SwitchWeaponRemote = CombatEvents:FindFirstChild("SwitchWeapon") or Instance.new("RemoteEvent")
SwitchWeaponRemote.Name = "SwitchWeapon"; SwitchWeaponRemote.Parent = CombatEvents

local Combat = {}

local health = {}
local MAX_HEALTH = 100

local playerState = {}
-- playerState[player] = { lastFire=0, weapon="AssaultRifle", ammo=mag, reserve=total, deaths=0, kills=0, inventory = {"AssaultRifle"} }

local function initPlayer(plr)
	if not playerState[plr] then
		local w = WeaponConfig.AssaultRifle
		playerState[plr] = {
			lastFire = 0,
			weapon = w.Id,
			ammo = w.MagazineSize,
			reserve = w.MagazineSize * 3,
			kills = 0,
			deaths = 0,
			inventory = { "AssaultRifle" },
		}
	end
	if not health[plr] then
		health[plr] = MAX_HEALTH
	end
end

local function weaponStats(id)
	return WeaponConfig[id]
end

local function pushStats(plr)
	local state = playerState[plr]
	if not state then return end
	UpdateStatsRemote:FireClient(plr, {
		Health = health[plr],
		Ammo = state.ammo,
		Reserve = state.reserve,
		Weapon = state.weapon,
		Kills = state.kills,
		Deaths = state.deaths,
	})
end

function Combat.Fire(plr, origin, direction)
	initPlayer(plr)
	local state = playerState[plr]
	local wStats = weaponStats(state.weapon)
	if not wStats then return false, "Invalid weapon" end
	if state.ammo <= 0 then return false, "Empty" end
	local now = os.clock()
	local cooldown = 1 / wStats.FireRate
	if now - state.lastFire < cooldown then return false, "Rate limited" end
	state.lastFire = now
	state.ammo -= 1

	Logging.Event("FireAttempt", { u = plr.UserId, w = state.weapon, ammo = state.ammo })
	Metrics.Inc("ShotsFired")
	local startT = os.clock()

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { plr.Character }
	local result = workspace:Raycast(origin, direction.Unit * wStats.Range, params)
	AntiCheat.RecordShot(plr)
	if result and result.Instance then
		local hitChar = result.Instance:FindFirstAncestorWhichIsA("Model")
		if hitChar and hitChar:FindFirstChild("Humanoid") then
			local targetPlayer = Players:GetPlayerFromCharacter(hitChar)
			if targetPlayer and targetPlayer ~= plr then
				initPlayer(targetPlayer)
				local isHead = (result.Instance.Name == "Head")
				local damage = wStats.Damage
				if isHead then damage *= 1.5 end
				health[targetPlayer] -= damage
				if health[targetPlayer] <= 0 then
					state.kills += 1
					playerState[targetPlayer].deaths += 1
					print(plr.Name .. " eliminated " .. targetPlayer.Name)
					Logging.Event("Elimination", { killer = plr.UserId, victim = targetPlayer.UserId, w = state.weapon, head = isHead })
					Metrics.Inc("Eliminations")
					Matchmaker.OnPlayerKill(plr, targetPlayer)
					KillStreakManager.OnKill(plr, targetPlayer)
					KillStreakManager.Reset(targetPlayer)
					health[targetPlayer] = MAX_HEALTH
					-- Simple immediate respawn placeholder
					AntiCheat.RecordHit(plr, isHead)
				else
					AntiCheat.RecordHit(plr, isHead)
				end
			end
		end
	end
	Metrics.Observe("FireValidationLatency", os.clock() - startT)
	pushStats(plr)
	return true, { ammo = state.ammo }
end

function Combat.Reload(plr)
	initPlayer(plr)
	local state = playerState[plr]
	local wStats = weaponStats(state.weapon)
	if state.ammo >= wStats.MagazineSize then return false, "Full" end
	if state.reserve <= 0 then return false, "NoReserve" end
	local needed = wStats.MagazineSize - state.ammo
	local taken = math.min(needed, state.reserve)
	state.ammo += taken
	state.reserve -= taken
	pushStats(plr)
	return true, { ammo = state.ammo, reserve = state.reserve }
end

function Combat.SwitchWeapon(plr, newWeapon)
	initPlayer(plr)
	local state = playerState[plr]
	for _,w in ipairs(state.inventory) do
		if w == newWeapon then
			if state.weapon == newWeapon then return end
			state.weapon = newWeapon
			local cfg = weaponStats(newWeapon)
			if cfg then
				-- reset ammo if switching to a weapon without stored ammo yet (simple scaffold)
				if state["ammo_"..newWeapon] then
					state.ammo = state["ammo_"..newWeapon]
					state.reserve = state["reserve_"..newWeapon]
				else
					state.ammo = cfg.MagazineSize
					state.reserve = cfg.MagazineSize * 3
				end
				pushStats(plr)
			end
			return
		end
	end
end

-- Remote wiring
if FireWeaponRemote then
	FireWeaponRemote.OnServerEvent:Connect(function(plr, origin, direction)
		if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then return end
		Combat.Fire(plr, origin, direction)
	end)
end

RequestReloadRemote.OnServerEvent:Connect(function(plr)
	Combat.Reload(plr)
end)

SwitchWeaponRemote.OnServerEvent:Connect(function(plr, weaponId)
	if typeof(weaponId) ~= "string" then return end
	Combat.SwitchWeapon(plr, weaponId)
end)

Players.PlayerAdded:Connect(function(plr)
	initPlayer(plr)
	pushStats(plr)
end)

return Combat
