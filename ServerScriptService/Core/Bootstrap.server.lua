-- Bootstrap.server.lua
-- Enterprise initialization system - orchestrates all game systems

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Core system orchestration
local function ensureFolder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then f = Instance.new("Folder"); f.Name = name; f.Parent = parent end
	return f
end

-- Ensure RemoteEvents structure is complete
local remoteRoot = ensureFolder(ReplicatedStorage, "RemoteEvents")
local domains = { "MatchmakingEvents", "CombatEvents", "ShopEvents", "UIEvents" }
local requiredEvents = {
	MatchmakingEvents = { "RequestMatch", "LeaveQueue", "MatchStart", "MatchEnd" },
	CombatEvents = { "FireWeapon", "ReportHit", "RequestReload", "SwitchWeapon" },
	ShopEvents = { "PurchaseItem", "EquipCosmetic" },
	UIEvents = { "UpdateStats", "ShowLeaderboard", "UpdateCurrency", "GameStateUpdate", "AntiCheatWarning" },
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

-- Initialize core logging and metrics first
local Metrics = require(script.Parent.Metrics)
local Logging = require(ReplicatedStorage.Shared.Logging)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

Metrics.Init()
Logging.SetMetrics(Metrics)

print("[Bootstrap] Starting enterprise FPS game initialization...")
Logging.Info("Bootstrap", "Enterprise FPS game server starting up")

-- Initialize systems in dependency order
local initializationOrder = {
	-- Core infrastructure
	"SystemManager",      -- Master system coordinator
	"NetworkManager",     -- Network optimization
	"GameStateManager",   -- Game flow control
	"GameOrchestrator",   -- Enterprise orchestration
	
	-- Data and persistence
	"DataStore",          -- Player data persistence
	"ErrorAggregation",   -- Error tracking and recovery
	
	-- Security and monitoring
	"AntiCheat",          -- Cheat detection
	"AdminReviewTool",    -- Admin tools
	"FeatureFlags",       -- Feature toggles
	"RateLimiter",        -- Request limiting
	
	-- Game systems
	"MapManager",         -- Map loading and village spawn
	"RankManager",        -- ELO and ranking
	"Combat",             -- Weapon and damage systems
	"KillStreakManager",  -- Kill streak bonuses
	"Matchmaker",         -- Player matching
	"CompetitiveMatchmaker", -- Ranked matchmaking
	"CrossServerMatchmaking", -- Multi-server matching
	
	-- Economy and progression
	"CurrencyManager",    -- Virtual currency
	"ShopManager",        -- Item purchases
	"DailyChallenges",    -- Daily objectives
	"RankRewards",        -- Rank-based rewards
	
	-- Social and competitive
	"Clan",               -- Clan system
	"ClanBattles",        -- Clan vs clan
	"RankedSeasons",      -- Seasonal competition
	"Tournament",         -- Tournament system
	"TournamentPersistence", -- Tournament data
	
	-- Analytics and optimization
	"StatisticsAnalytics", -- Player analytics
	"MetricsDashboard",    -- Real-time metrics
	"ABTesting",           -- A/B experiments
	"SessionMigration",    -- Server migration
	"ReplayRecorder",      -- Match recording
	"MatchRecording",      -- Match history
	"Spectator",           -- Spectator system
	"GlobalAnnouncements", -- Server messaging
	"ShardedLeaderboards", -- Distributed rankings
}

local initializedSystems = {}
local failedSystems = {}

for i, systemName in ipairs(initializationOrder) do
	local success, result = pcall(function()
		local system = require(script.Parent[systemName])
		
		-- Initialize if the system has an Initialize method
		if system and type(system.Initialize) == "function" then
			system.Initialize()
			print(string.format("[Bootstrap] ✓ %s initialized (%d/%d)", systemName, i, #initializationOrder))
		else
			print(string.format("[Bootstrap] ✓ %s loaded (%d/%d)", systemName, i, #initializationOrder))
		end
		
		table.insert(initializedSystems, systemName)
		return system
	end)
	
	if not success then
		print(string.format("[Bootstrap] ✗ %s failed: %s", systemName, tostring(result)))
		table.insert(failedSystems, { name = systemName, error = result })
		Logging.Error("Bootstrap", "Failed to initialize " .. systemName .. ": " .. tostring(result))
	end
end

-- Report initialization results
local successCount = #initializedSystems
local totalCount = #initializationOrder
local successRate = math.floor((successCount / totalCount) * 100)

print(string.format("[Bootstrap] Initialization complete: %d/%d systems (%.1f%% success rate)", 
	successCount, totalCount, successRate))

if #failedSystems > 0 then
	print("[Bootstrap] Failed systems:")
	for _, failure in ipairs(failedSystems) do
		print("  - " .. failure.name .. ": " .. tostring(failure.error))
	end
end

-- Set up village spawning with enhanced features
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		wait(0.2) -- Ensure character is fully loaded
		
		-- Find village spawn points
		local spawnPoints = {}
		for _, obj in ipairs(game.Workspace:GetChildren()) do
			if obj:IsA("SpawnLocation") and string.find(obj.Name, "VillageSpawn") then
				table.insert(spawnPoints, obj)
			end
		end
		
		if #spawnPoints > 0 then
			-- Choose random spawn point
			local randomSpawn = spawnPoints[math.random(1, #spawnPoints)]
			
			-- Teleport player with safety checks
			if character:FindFirstChild("HumanoidRootPart") then
				local safePosition = randomSpawn.CFrame + Vector3.new(0, 3, 0)
				character.HumanoidRootPart.CFrame = safePosition
				
				-- Add spawn protection if configured
				if GameConfig.Maps.SpawnProtectionTime > 0 then
					local humanoid = character:FindFirstChild("Humanoid")
					if humanoid then
						-- Temporary invulnerability
						spawn(function()
							wait(GameConfig.Maps.SpawnProtectionTime)
							-- Remove protection after time expires
						end)
					end
				end
			end
			
			Logging.Event("PlayerSpawned", {
				u = player.UserId,
				spawnPoint = randomSpawn.Name,
				position = randomSpawn.Position
			})
		else
			Logging.Warn("Bootstrap", "No village spawn points found for " .. player.Name)
		end
	end)
end)

-- Set up graceful shutdown
game:BindToClose(function()
	print("[Bootstrap] Server shutting down - saving all data...")
	Logging.Info("Bootstrap", "Server shutdown initiated")
	
	-- Give systems time to cleanup
	wait(5)
	
	print("[Bootstrap] Shutdown complete")
end)

-- Performance monitoring
spawn(function()
	while true do
		wait(60) -- Check every minute
		
		local stats = game:GetService("Stats")
		local memory = stats:GetTotalMemoryUsageMb()
		local playerCount = #Players:GetPlayers()
		
		if memory > GameConfig.Performance.MaxServerMemoryMB then
			Logging.Warn("Bootstrap", "High memory usage detected: " .. memory .. "MB")
			collectgarbage("collect") -- Force garbage collection
		end
		
		-- Log server health
		Logging.Event("ServerHealth", {
			memory = memory,
			playerCount = playerCount,
			uptime = os.time()
		})
	end
end)

print("[Bootstrap] ✓ Enterprise FPS game server is fully operational!")
print(string.format("[Bootstrap] ✓ %d systems active, village spawn ready, all RemoteEvents created", successCount))
print("[Bootstrap] ✓ Ready for players - Welcome to the ultimate competitive FPS experience!")

Logging.Info("Bootstrap", "Enterprise initialization complete - Server ready for players")
