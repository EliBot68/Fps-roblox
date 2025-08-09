-- SessionMigration.server.lua
-- Session migration and seamless teleport fallback

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logging = require(ReplicatedStorage.Shared.Logging)

local SessionMigration = {}

-- MemoryStore for session data
local sessionStore = MemoryStoreService:GetHashMap("PlayerSessions")
local serverStatusStore = MemoryStoreService:GetSortedMap("ServerStatus")

-- DataStore for persistent session recovery
local sessionRecoveryStore = DataStoreService:GetDataStore("SessionRecovery")

-- Server tracking
local SERVER_ID = game.JobId
local serverStartTime = os.time()
local migrationInProgress = {}

-- Session data structure
local function createSessionData(player)
	return {
		userId = player.UserId,
		username = player.Name,
		joinTime = os.time(),
		serverId = SERVER_ID,
		position = nil,
		health = 100,
		currency = 0,
		inventory = {},
		matchState = {},
		preferences = {},
		version = 1,
		lastUpdate = os.time()
	}
end

function SessionMigration.SavePlayerSession(player, additionalData)
	local sessionData = createSessionData(player)
	
	-- Get current player state
	if player.Character then
		local humanoid = player.Character:FindFirstChild("Humanoid")
		local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
		
		if humanoid then
			sessionData.health = humanoid.Health
		end
		
		if rootPart then
			sessionData.position = {
				X = rootPart.Position.X,
				Y = rootPart.Position.Y,
				Z = rootPart.Position.Z,
				orientation = {
					X = rootPart.CFrame.Rotation.X,
					Y = rootPart.CFrame.Rotation.Y,
					Z = rootPart.CFrame.Rotation.Z
				}
			}
		end
	end
	
	-- Merge additional data
	if additionalData then
		for key, value in pairs(additionalData) do
			sessionData[key] = value
		end
	end
	
	sessionData.lastUpdate = os.time()
	
	-- Save to MemoryStore
	pcall(function()
		sessionStore:SetAsync(tostring(player.UserId), sessionData, 1800) -- 30 minutes TTL
	end)
	
	-- Also save to persistent storage for critical data
	pcall(function()
		sessionRecoveryStore:SetAsync(tostring(player.UserId), {
			sessionData = sessionData,
			timestamp = os.time()
		})
	end)
	
	Logging.Event("SessionSaved", {
		u = player.UserId,
		serverId = SERVER_ID,
		health = sessionData.health
	})
end

function SessionMigration.LoadPlayerSession(player)
	local userId = tostring(player.UserId)
	local sessionData = nil
	
	-- Try MemoryStore first (fastest)
	local success, result = pcall(function()
		return sessionStore:GetAsync(userId)
	end)
	
	if success and result then
		sessionData = result
	else
		-- Fallback to persistent storage
		local persistentSuccess, persistentResult = pcall(function()
			return sessionRecoveryStore:GetAsync(userId)
		end)
		
		if persistentSuccess and persistentResult then
			sessionData = persistentResult.sessionData
		end
	end
	
	if sessionData then
		SessionMigration.RestorePlayerState(player, sessionData)
		Logging.Event("SessionRestored", {
			u = player.UserId,
			originalServer = sessionData.serverId,
			currentServer = SERVER_ID
		})
	end
	
	return sessionData
end

function SessionMigration.RestorePlayerState(player, sessionData)
	-- Wait for character to spawn
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	
	local character = player.Character
	if not character then return end
	
	-- Restore health
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid and sessionData.health then
		humanoid.Health = math.min(sessionData.health, humanoid.MaxHealth)
	end
	
	-- Restore position (with safety checks)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart and sessionData.position then
		local position = Vector3.new(
			sessionData.position.X,
			sessionData.position.Y,
			sessionData.position.Z
		)
		
		-- Validate position is safe
		if SessionMigration.IsPositionSafe(position) then
			rootPart.CFrame = CFrame.new(position)
			
			-- Restore orientation if available
			if sessionData.position.orientation then
				local rotation = CFrame.Angles(
					sessionData.position.orientation.X,
					sessionData.position.orientation.Y,
					sessionData.position.orientation.Z
				)
				rootPart.CFrame = CFrame.new(position) * rotation
			end
		end
	end
	
	-- Restore other game-specific state
	SessionMigration.RestoreGameState(player, sessionData)
end

function SessionMigration.RestoreGameState(player, sessionData)
	-- This would integrate with other game systems
	-- Examples:
	
	-- Restore currency
	if sessionData.currency then
		-- CurrencyManager.SetCurrency(player, sessionData.currency)
	end
	
	-- Restore inventory
	if sessionData.inventory then
		-- InventoryManager.RestoreInventory(player, sessionData.inventory)
	end
	
	-- Restore match state
	if sessionData.matchState then
		-- MatchManager.RestoreMatchState(player, sessionData.matchState)
	end
end

function SessionMigration.IsPositionSafe(position)
	-- Check if position is within map bounds
	local mapBounds = {
		min = Vector3.new(-1000, 0, -1000),
		max = Vector3.new(1000, 1000, 1000)
	}
	
	if position.X < mapBounds.min.X or position.X > mapBounds.max.X or
	   position.Y < mapBounds.min.Y or position.Y > mapBounds.max.Y or
	   position.Z < mapBounds.min.Z or position.Z > mapBounds.max.Z then
		return false
	end
	
	-- Additional safety checks could be added here
	-- (e.g., raycast to check for solid ground)
	
	return true
end

function SessionMigration.MigratePlayerToServer(player, targetServerId, reason)
	reason = reason or "server_migration"
	
	if migrationInProgress[player.UserId] then
		return false, "Migration already in progress"
	end
	
	migrationInProgress[player.UserId] = true
	
	-- Save current session
	SessionMigration.SavePlayerSession(player, {
		migrationReason = reason,
		migrationTime = os.time(),
		sourceServer = SERVER_ID
	})
	
	-- Attempt teleport
	local success, errorMessage = pcall(function()
		if targetServerId == "new" then
			-- Teleport to a new server
			TeleportService:Teleport(game.PlaceId, player)
		else
			-- Teleport to specific server
			TeleportService:TeleportToPlaceInstance(game.PlaceId, targetServerId, player)
		end
	end)
	
	if success then
		Logging.Event("PlayerMigrated", {
			u = player.UserId,
			targetServer = targetServerId,
			reason = reason
		})
	else
		migrationInProgress[player.UserId] = nil
		Logging.Error("SessionMigration", "Failed to migrate player: " .. tostring(errorMessage))
	end
	
	return success, errorMessage
end

function SessionMigration.HandleServerShutdown()
	-- Migrate all players before shutdown
	local players = Players:GetPlayers()
	
	Logging.Event("ServerShutdownMigration", {
		playerCount = #players,
		serverId = SERVER_ID
	})
	
	-- Save all sessions
	for _, player in ipairs(players) do
		SessionMigration.SavePlayerSession(player, {
			migrationReason = "server_shutdown",
			shutdownTime = os.time()
		})
	end
	
	-- Find alternative servers
	local alternativeServers = SessionMigration.FindAlternativeServers(#players)
	
	if #alternativeServers > 0 then
		-- Distribute players across available servers
		local playersPerServer = math.ceil(#players / #alternativeServers)
		local currentServerIndex = 1
		local playersInCurrentServer = 0
		
		for _, player in ipairs(players) do
			local targetServer = alternativeServers[currentServerIndex]
			
			SessionMigration.MigratePlayerToServer(player, targetServer, "server_shutdown")
			
			playersInCurrentServer = playersInCurrentServer + 1
			if playersInCurrentServer >= playersPerServer and currentServerIndex < #alternativeServers then
				currentServerIndex = currentServerIndex + 1
				playersInCurrentServer = 0
			end
		end
	else
		-- No alternative servers, migrate to new instances
		for _, player in ipairs(players) do
			SessionMigration.MigratePlayerToServer(player, "new", "server_shutdown")
		end
	end
end

function SessionMigration.FindAlternativeServers(minCapacity)
	local servers = {}
	
	-- This would query server status from MemoryStore
	-- For now, return empty array as placeholder
	pcall(function()
		serverStatusStore:ReadAsync(1, 100, function(key, value)
			if value and value.capacity >= minCapacity and value.serverId ~= SERVER_ID then
				table.insert(servers, value.serverId)
			end
		end)
	end)
	
	return servers
end

function SessionMigration.UpdateServerStatus()
	local currentPlayers = #Players:GetPlayers()
	local maxPlayers = Players.MaxPlayers
	
	local serverStatus = {
		serverId = SERVER_ID,
		playerCount = currentPlayers,
		maxPlayers = maxPlayers,
		capacity = maxPlayers - currentPlayers,
		uptime = os.time() - serverStartTime,
		lastUpdate = os.time(),
		status = "healthy"
	}
	
	-- Determine server health
	if currentPlayers >= maxPlayers * 0.9 then
		serverStatus.status = "near_full"
	elseif currentPlayers >= maxPlayers then
		serverStatus.status = "full"
	end
	
	-- Update MemoryStore
	pcall(function()
		serverStatusStore:SetAsync(SERVER_ID, serverStatus, 300) -- 5 minute TTL
	end)
end

function SessionMigration.MonitorServerHealth()
	-- Monitor various health metrics
	local metrics = {
		fps = 1 / game:GetService("RunService").Heartbeat:Wait(),
		memory = pcall(function() return game:GetService("Stats"):GetTotalMemoryUsageMb(Enum.MemoryInfoType.Internal) end) and game:GetService("Stats"):GetTotalMemoryUsageMb(Enum.MemoryInfoType.Internal) or 0,
		playerCount = #Players:GetPlayers(),
		uptime = os.time() - serverStartTime
	}
	
	-- Check if server needs migration
	local needsMigration = false
	local reason = ""
	
	if metrics.fps < 10 then
		needsMigration = true
		reason = "low_performance"
	elseif metrics.memory > 2000 then -- 2GB memory usage
		needsMigration = true
		reason = "high_memory"
	end
	
	if needsMigration then
		Logging.Warn("SessionMigration", "Server health degraded: " .. reason)
		-- Could trigger automatic migration here
	end
	
	return metrics, needsMigration, reason
end

-- Handle teleport data when players join
local function onPlayerAdded(player)
	-- Check if player has teleport data (session migration)
	local teleportData = player:GetJoinData()
	
	if teleportData and teleportData.TeleportData then
		-- Player is joining from a migration
		Logging.Event("PlayerJoinedFromMigration", {
			u = player.UserId,
			sourceData = teleportData.TeleportData
		})
	end
	
	-- Load player session
	wait(2) -- Allow character to spawn
	SessionMigration.LoadPlayerSession(player)
end

local function onPlayerRemoving(player)
	-- Save session when player leaves
	SessionMigration.SavePlayerSession(player, {
		leaveTime = os.time(),
		leaveReason = "player_left"
	})
	
	migrationInProgress[player.UserId] = nil
end

-- Connect events
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Server shutdown handler
game:BindToClose(function()
	SessionMigration.HandleServerShutdown()
	wait(5) -- Give time for migrations to start
end)

-- Periodic monitoring
spawn(function()
	while true do
		wait(30) -- Every 30 seconds
		SessionMigration.UpdateServerStatus()
		SessionMigration.MonitorServerHealth()
	end
end)

-- Periodic session cleanup
spawn(function()
	while true do
		wait(600) -- Every 10 minutes
		
		-- Clean up old session data
		for _, player in ipairs(Players:GetPlayers()) do
			SessionMigration.SavePlayerSession(player)
		end
	end
end)

return SessionMigration
