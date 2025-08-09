-- Bootstrap.server.lua
-- Initializes core services, ensures RemoteEvents, wires feature flags

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local function ensureFolder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then f = Instance.new("Folder"); f.Name = name; f.Parent = parent end
	return f
end

local remoteRoot = ensureFolder(ReplicatedStorage, "RemoteEvents")
local domains = { "MatchmakingEvents", "CombatEvents", "ShopEvents", "UIEvents" }
local requiredEvents = {
	MatchmakingEvents = { "RequestMatch", "LeaveQueue" },
	CombatEvents = { "FireWeapon", "ReportHit", "RequestReload" },
	ShopEvents = { "PurchaseItem", "EquipCosmetic" },
	UIEvents = { "UpdateStats", "ShowLeaderboard" },
}

for _,domain in ipairs(domains) do
	local folder = ensureFolder(remoteRoot, domain)
	for _,evtName in ipairs(requiredEvents[domain]) do
		if not folder:FindFirstChild(evtName) then
			local re = Instance.new("RemoteEvent")
			re.Name = evtName
			re.Parent = folder
		end
	end
end

local Metrics = require(script.Parent.Metrics)
local Logging = require(game:GetService("ReplicatedStorage").Shared.Logging)

Metrics.Init()
Logging.SetMetrics(Metrics)

print("[Bootstrap] Initialization complete")
