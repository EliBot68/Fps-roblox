-- Spectator.server.lua
-- Placeholder spectator mode manager

local Spectator = {}
local Players = game:GetService("Players")

local activeSpectators = {}
local currentTarget = {}

function Spectator.Enter(plr)
	activeSpectators[plr] = true
	-- TODO: set camera mode, hide character
end

function Spectator.Exit(plr)
	activeSpectators[plr] = nil
end

Players.PlayerRemoving:Connect(function(plr)
	activeSpectators[plr] = nil
end)

local function getAlivePlayers()
	local list = {}
	for _,plr in ipairs(Players:GetPlayers()) do
		if plr.Character and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health > 0 then
			list[#list+1] = plr
		end
	end
	return list
end

function Spectator.NextTarget(plr)
	if not activeSpectators[plr] then return end
	local alive = getAlivePlayers()
	if #alive == 0 then return end
	local idx = 1
	for i,p in ipairs(alive) do
		if p == currentTarget[plr] then idx = i+1 break end
	end
	if idx > #alive then idx = 1 end
	currentTarget[plr] = alive[idx]
	return currentTarget[plr]
end

function Spectator.GetTarget(plr)
	return currentTarget[plr]
end

return Spectator
