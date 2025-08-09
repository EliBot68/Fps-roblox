-- Combat.server.lua
-- Validates shots and applies damage

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local WeaponConfig = require(game:GetService("ReplicatedStorage").Shared.WeaponConfig)

local Combat = {}

local health = {}
local MAX_HEALTH = 100

local playerState = {}
-- playerState[player] = { lastFire=0, weapon="AssaultRifle", ammo=mag, reserve=total }

local function initPlayer(plr)
	if not playerState[plr] then
		local w = WeaponConfig.AssaultRifle
		playerState[plr] = {
			lastFire = 0,
			weapon = w.Id,
			ammo = w.MagazineSize,
			reserve = w.MagazineSize * 3,
		}
	end
	if not health[plr] then
		health[plr] = MAX_HEALTH
	end
end

local function weaponStats(id)
	return WeaponConfig[id]
end

function Combat.Fire(plr, origin, direction)
	initPlayer(plr)
	local state = playerState[plr]
	local wStats = weaponStats(state.weapon)
	if not wStats then return false, "Invalid weapon" end

	if state.ammo <= 0 then
		return false, "Empty"
	end

	local now = os.clock()
	local cooldown = 1 / wStats.FireRate
	if now - state.lastFire < cooldown then
		return false, "Rate limited"
	end
	state.lastFire = now
	state.ammo -= 1

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { plr.Character }
	local result = workspace:Raycast(origin, direction.Unit * wStats.Range, params)
	if result and result.Instance then
		local hitChar = result.Instance:FindFirstAncestorWhichIsA("Model")
		if hitChar and hitChar:FindFirstChild("Humanoid") then
			local targetPlayer = Players:GetPlayerFromCharacter(hitChar)
			if targetPlayer then
				initPlayer(targetPlayer)
				health[targetPlayer] -= wStats.Damage
				if health[targetPlayer] <= 0 then
					print(plr.Name .. " eliminated " .. targetPlayer.Name)
					health[targetPlayer] = MAX_HEALTH
					-- TODO: respawn delay
				end
			end
		end
	end
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
	return true, { ammo = state.ammo, reserve = state.reserve }
end

return Combat
