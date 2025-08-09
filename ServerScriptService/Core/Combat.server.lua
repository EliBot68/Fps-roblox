-- Combat.server.lua
-- Validates shots and applies damage

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Combat = {}

-- Basic player state (placeholder)
local health = {}
local MAX_HEALTH = 100

local lastFireTime = {}
local FIRE_COOLDOWN = 0.12 -- ~8.3 rps
local MAX_RAY_DISTANCE = 300

local function ensurePlayer(plr)
	if not health[plr] then
		health[plr] = MAX_HEALTH
	end
end

function Combat.Fire(plr, origin, direction)
	ensurePlayer(plr)
	local now = os.clock()
	local last = lastFireTime[plr] or 0
	if now - last < FIRE_COOLDOWN then
		return false, "Rate limited"
	end
	lastFireTime[plr] = now

	-- Raycast
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { plr.Character }
	local result = workspace:Raycast(origin, direction.Unit * MAX_RAY_DISTANCE, params)
	if result and result.Instance then
		local hitChar = result.Instance:FindFirstAncestorWhichIsA("Model")
		if hitChar and hitChar:FindFirstChild("Humanoid") then
			local targetPlayer = Players:GetPlayerFromCharacter(hitChar)
			if targetPlayer then
				ensurePlayer(targetPlayer)
				health[targetPlayer] -= 25
				if health[targetPlayer] <= 0 then
					print(plr.Name .. " eliminated " .. targetPlayer.Name)
					health[targetPlayer] = MAX_HEALTH -- simple respawn reset
				end
			end
		end
	end
	return true
end

return Combat
