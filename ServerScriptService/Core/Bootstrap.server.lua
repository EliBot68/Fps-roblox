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
	MatchmakingEvents = { "RequestMatch", "LeaveQueue", "MatchStart", "MatchEnd" },
	CombatEvents = { "FireWeapon", "ReportHit", "RequestReload", "SwitchWeapon" },
	ShopEvents = { "PurchaseItem", "EquipCosmetic" },
	UIEvents = { "UpdateStats", "ShowLeaderboard", "UpdateCurrency" },
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

-- Set up player spawning in village
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		wait(0.1) -- Small delay to ensure character is fully loaded
		
		-- Find a village spawn point
		local spawnPoints = {}
		for _, obj in ipairs(game.Workspace:GetChildren()) do
			if obj:IsA("SpawnLocation") and string.find(obj.Name, "VillageSpawn") then
				table.insert(spawnPoints, obj)
			end
		end
		
		if #spawnPoints > 0 then
			-- Choose random spawn point
			local randomSpawn = spawnPoints[math.random(1, #spawnPoints)]
			
			-- Teleport player to village spawn
			if character:FindFirstChild("HumanoidRootPart") then
				character.HumanoidRootPart.CFrame = randomSpawn.CFrame + Vector3.new(0, 3, 0)
			end
			
			Logging.Info(player.Name .. " spawned in village at " .. tostring(randomSpawn.Position))
		end
	end)
end)

print("[Bootstrap] Initialization complete - Village spawn system active")
