-- Spectator.server.lua
-- Placeholder spectator mode manager

local Spectator = {}
local Players = game:GetService("Players")

local activeSpectators = {}

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

return Spectator
