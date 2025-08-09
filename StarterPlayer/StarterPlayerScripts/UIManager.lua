-- UIManager.lua
-- Placeholder for HUD updates

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local UIManager = {}

function UIManager.UpdateStats(stats)
	-- TODO: update PlayerGui elements
	print("[UI] Stats update", stats and stats.Health)
end

return UIManager
