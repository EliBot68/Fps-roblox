-- UIManager.lua
-- Placeholder for HUD updates

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local UIManager = {}

local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
local UIEvents = RemoteRoot:WaitForChild("UIEvents")
local UpdateStatsRemote = UIEvents:WaitForChild("UpdateStats")

local Localization = require(ReplicatedStorage.Shared.Localization)
local locale = "EN"

local latest = {}

function UIManager.UpdateStats(stats)
	latest = stats
	print(string.format("[UI] %s:%s %s:%s/%s K:%s D:%s", Localization.Get(locale,"HUD_HEALTH"), stats.Health, Localization.Get(locale,"HUD_AMMO"), stats.Ammo, stats.Reserve, stats.Kills, stats.Deaths))
	-- TODO: apply to ScreenGui elements
end

UpdateStatsRemote.OnClientEvent:Connect(function(data)
	UIManager.UpdateStats(data)
end)

return UIManager
