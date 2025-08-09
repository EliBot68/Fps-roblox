-- MapManager.server.lua
-- Manages map loading, spawn points, and team configurations for competitive modes

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Logging = require(ReplicatedStorage.Shared.Logging)

local MapManager = {}

-- Configuration for competitive team modes
local TEAM_CONFIGS = {
	["1v1"] = { maxPlayers = 2, teamsPerSide = 1, playersPerTeam = 1 },
	["2v2"] = { maxPlayers = 4, teamsPerSide = 2, playersPerTeam = 2 },
	["3v3"] = { maxPlayers = 6, teamsPerSide = 2, playersPerTeam = 3 },
	["4v4"] = { maxPlayers = 8, teamsPerSide = 2, playersPerTeam = 4 }
}

-- Map metadata structure for competitive maps
local mapRegistry = {}
local currentMap = nil
local mapsFolder = Workspace:WaitForChild("Maps")

function MapManager.Initialize()
	-- Scan for available maps
	MapManager.ScanAvailableMaps()
	
	-- Set up map loading events
	MapManager.SetupEvents()
	
	Logging.Info("MapManager initialized with " .. #mapRegistry .. " competitive maps")
end

function MapManager.ScanAvailableMaps()
	mapRegistry = {}
	
	for _, mapFolder in ipairs(mapsFolder:GetChildren()) do
		if mapFolder:IsA("Folder") or mapFolder:IsA("Model") then
			local mapData = MapManager.AnalyzeMap(mapFolder)
			if mapData then
				mapRegistry[mapFolder.Name] = mapData
				Logging.Info("Registered competitive map: " .. mapFolder.Name)
			end
		end
	end
end

function MapManager.AnalyzeMap(mapFolder)
	-- Analyze map for competitive viability
	local mapData = {
		name = mapFolder.Name,
		folder = mapFolder,
		spawnPoints = {},
		bounds = { min = Vector3.new(), max = Vector3.new() },
		lighting = {},
		supportedModes = {},
		competitiveRating = 0
	}
	
	-- Find spawn points
	local spawnPointsFolder = mapFolder:FindFirstChild("SpawnPoints")
	if spawnPointsFolder then
		MapManager.AnalyzeSpawnPoints(spawnPointsFolder, mapData)
	else
		-- Auto-generate spawn points if not found
		MapManager.GenerateSpawnPoints(mapFolder, mapData)
	end
	
	-- Calculate map bounds
	MapManager.CalculateMapBounds(mapFolder, mapData)
	
	-- Determine supported competitive modes
	MapManager.DetermineSupportedModes(mapData)
	
	-- Get lighting configuration
	local lightingFolder = mapFolder:FindFirstChild("Lighting")
	if lightingFolder then
		mapData.lighting = MapManager.ExtractLightingConfig(lightingFolder)
	end
	
	return mapData
end

function MapManager.AnalyzeSpawnPoints(spawnPointsFolder, mapData)
	local teamSpawns = { Team1 = {}, Team2 = {} }
	
	for _, spawn in ipairs(spawnPointsFolder:GetChildren()) do
		if spawn:IsA("BasePart") or spawn:IsA("Model") then
			local team = spawn:GetAttribute("Team") or "Team1"
			local position = spawn:IsA("Model") and spawn.PrimaryPart.Position or spawn.Position
			
			table.insert(teamSpawns[team], {
				position = position,
				rotation = spawn:IsA("Model") and spawn.PrimaryPart.CFrame or spawn.CFrame,
				part = spawn
			})
		end
	end
	
	mapData.spawnPoints = teamSpawns
	
	-- Validate spawn balance
	MapManager.ValidateSpawnBalance(mapData)
end

function MapManager.GenerateSpawnPoints(mapFolder, mapData)
	-- Auto-generate balanced spawn points for competitive play
	local bounds = MapManager.CalculateMapBounds(mapFolder, mapData)
	local center = (bounds.min + bounds.max) / 2
	local size = bounds.max - bounds.min
	
	-- Generate team spawns on opposite sides
	local team1Spawns = {}
	local team2Spawns = {}
	
	-- Team 1: Left side
	for i = 1, 4 do -- Support up to 4v4
		local x = bounds.min.X + size.X * 0.2
		local z = bounds.min.Z + (size.Z / 5) * i
		local y = bounds.max.Y + 5 -- Spawn above map
		
		table.insert(team1Spawns, {
			position = Vector3.new(x, y, z),
			rotation = CFrame.lookAt(Vector3.new(x, y, z), center)
		})
	end
	
	-- Team 2: Right side
	for i = 1, 4 do
		local x = bounds.max.X - size.X * 0.2
		local z = bounds.min.Z + (size.Z / 5) * i
		local y = bounds.max.Y + 5
		
		table.insert(team2Spawns, {
			position = Vector3.new(x, y, z),
			rotation = CFrame.lookAt(Vector3.new(x, y, z), center)
		})
	end
	
	mapData.spawnPoints = { Team1 = team1Spawns, Team2 = team2Spawns }
end

function MapManager.CalculateMapBounds(mapFolder, mapData)
	local minBounds = Vector3.new(math.huge, math.huge, math.huge)
	local maxBounds = Vector3.new(-math.huge, -math.huge, -math.huge)
	
	local function processPart(part)
		if part:IsA("BasePart") then
			local cf = part.CFrame
			local size = part.Size
			local corners = {
				cf * CFrame.new(-size.X/2, -size.Y/2, -size.Z/2),
				cf * CFrame.new(size.X/2, size.Y/2, size.Z/2)
			}
			
			for _, corner in ipairs(corners) do
				minBounds = Vector3.new(
					math.min(minBounds.X, corner.Position.X),
					math.min(minBounds.Y, corner.Position.Y),
					math.min(minBounds.Z, corner.Position.Z)
				)
				maxBounds = Vector3.new(
					math.max(maxBounds.X, corner.Position.X),
					math.max(maxBounds.Y, corner.Position.Y),
					math.max(maxBounds.Z, corner.Position.Z)
				)
			end
		end
	end
	
	local function traverse(obj)
		processPart(obj)
		for _, child in ipairs(obj:GetChildren()) do
			traverse(child)
		end
	end
	
	traverse(mapFolder)
	
	mapData.bounds = { min = minBounds, max = maxBounds }
	return mapData.bounds
end

function MapManager.DetermineSupportedModes(mapData)
	local team1Count = #mapData.spawnPoints.Team1
	local team2Count = #mapData.spawnPoints.Team2
	local minSpawns = math.min(team1Count, team2Count)
	
	-- Determine which competitive modes this map supports
	for mode, config in pairs(TEAM_CONFIGS) do
		if minSpawns >= config.playersPerTeam then
			table.insert(mapData.supportedModes, mode)
		end
	end
	
	-- Calculate competitive rating based on balance and design
	mapData.competitiveRating = MapManager.CalculateCompetitiveRating(mapData)
end

function MapManager.CalculateCompetitiveRating(mapData)
	local rating = 50 -- Base rating
	
	-- Spawn balance
	local team1Count = #mapData.spawnPoints.Team1
	local team2Count = #mapData.spawnPoints.Team2
	local spawnBalance = math.min(team1Count, team2Count) / math.max(team1Count, team2Count)
	rating = rating + (spawnBalance * 20)
	
	-- Map size appropriateness for competitive play
	local bounds = mapData.bounds
	local mapSize = (bounds.max - bounds.min).Magnitude
	if mapSize >= 100 and mapSize <= 500 then -- Optimal size for small teams
		rating = rating + 20
	elseif mapSize < 50 or mapSize > 1000 then
		rating = rating - 10
	end
	
	-- Number of supported modes
	rating = rating + (#mapData.supportedModes * 5)
	
	return math.min(rating, 100)
end

function MapManager.ValidateSpawnBalance(mapData)
	local team1Count = #mapData.spawnPoints.Team1
	local team2Count = #mapData.spawnPoints.Team2
	
	if math.abs(team1Count - team2Count) > 1 then
		Logging.Warning("Map " .. mapData.name .. " has unbalanced spawns: Team1=" .. team1Count .. ", Team2=" .. team2Count)
	end
	
	-- Validate spawn distances
	MapManager.ValidateSpawnDistances(mapData)
end

function MapManager.ValidateSpawnDistances(mapData)
	-- Check that spawns aren't too close to each other
	local minDistance = 20 -- Minimum distance between opposing team spawns
	
	for _, team1Spawn in ipairs(mapData.spawnPoints.Team1) do
		for _, team2Spawn in ipairs(mapData.spawnPoints.Team2) do
			local distance = (team1Spawn.position - team2Spawn.position).Magnitude
			if distance < minDistance then
				Logging.Warning("Map " .. mapData.name .. " has spawns too close together: " .. distance .. " studs")
			end
		end
	end
end

function MapManager.LoadMap(mapName, gameMode)
	if not mapRegistry[mapName] then
		return false, "Map not found: " .. mapName
	end
	
	local mapData = mapRegistry[mapName]
	
	-- Validate map supports the game mode
	if not table.find(mapData.supportedModes, gameMode) then
		return false, "Map " .. mapName .. " doesn't support " .. gameMode .. " mode"
	end
	
	-- Unload current map
	if currentMap then
		MapManager.UnloadCurrentMap()
	end
	
	-- Load new map
	local success = MapManager.LoadMapGeometry(mapData)
	if not success then
		return false, "Failed to load map geometry"
	end
	
	-- Apply lighting
	MapManager.ApplyMapLighting(mapData)
	
	-- Set current map
	currentMap = {
		name = mapName,
		data = mapData,
		gameMode = gameMode,
		loadTime = os.time()
	}
	
	Logging.Event("MapLoaded", {
		mapName = mapName,
		gameMode = gameMode,
		competitiveRating = mapData.competitiveRating
	})
	
	return true, "Map loaded successfully"
end

function MapManager.LoadMapGeometry(mapData)
	-- Clone map geometry into workspace
	local mapClone = mapData.folder:Clone()
	mapClone.Name = "CurrentMap"
	mapClone.Parent = Workspace
	
	-- Hide spawn points from players (make transparent)
	local spawnPointsFolder = mapClone:FindFirstChild("SpawnPoints")
	if spawnPointsFolder then
		for _, spawn in ipairs(spawnPointsFolder:GetChildren()) do
			if spawn:IsA("BasePart") then
				spawn.Transparency = 1
				spawn.CanCollide = false
			end
		end
	end
	
	return true
end

function MapManager.UnloadCurrentMap()
	local currentMapObj = Workspace:FindFirstChild("CurrentMap")
	if currentMapObj then
		currentMapObj:Destroy()
	end
	
	-- Reset lighting to default
	MapManager.ResetLighting()
	
	if currentMap then
		Logging.Event("MapUnloaded", {
			mapName = currentMap.name,
			duration = os.time() - currentMap.loadTime
		})
	end
	
	currentMap = nil
end

function MapManager.GetSpawnPoint(teamNumber, playerIndex, gameMode)
	if not currentMap then
		return nil
	end
	
	local teamKey = "Team" .. teamNumber
	local spawns = currentMap.data.spawnPoints[teamKey]
	
	if not spawns or #spawns == 0 then
		return nil
	end
	
	-- For competitive modes, use specific spawn assignments
	local config = TEAM_CONFIGS[gameMode]
	if config then
		local spawnIndex = ((playerIndex - 1) % #spawns) + 1
		return spawns[spawnIndex]
	end
	
	-- Fallback to random spawn
	return spawns[math.random(1, #spawns)]
end

function MapManager.ApplyMapLighting(mapData)
	if mapData.lighting and next(mapData.lighting) then
		-- Apply custom lighting settings
		for property, value in pairs(mapData.lighting) do
			if Lighting[property] ~= nil then
				Lighting[property] = value
			end
		end
	else
		-- Apply default competitive lighting
		MapManager.ApplyCompetitiveLighting()
	end
end

function MapManager.ApplyCompetitiveLighting()
	-- Optimized lighting for competitive play
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.new(0.2, 0.2, 0.2)
	Lighting.GlobalShadows = true
	Lighting.Technology = Enum.Technology.Voxel
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.5
end

function MapManager.ResetLighting()
	-- Reset to default lighting
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.new(0, 0, 0)
	Lighting.GlobalShadows = true
	Lighting.Technology = Enum.Technology.Voxel
end

function MapManager.ExtractLightingConfig(lightingFolder)
	local config = {}
	
	-- Extract lighting values from folder attributes or configuration
	for _, obj in ipairs(lightingFolder:GetChildren()) do
		if obj:IsA("Configuration") then
			for _, value in ipairs(obj:GetChildren()) do
				if value:IsA("StringValue") or value:IsA("NumberValue") or value:IsA("BoolValue") then
					config[value.Name] = value.Value
				end
			end
		end
	end
	
	return config
end

function MapManager.GetAvailableMaps(gameMode)
	local availableMaps = {}
	
	for mapName, mapData in pairs(mapRegistry) do
		if not gameMode or table.find(mapData.supportedModes, gameMode) then
			table.insert(availableMaps, {
				name = mapName,
				supportedModes = mapData.supportedModes,
				competitiveRating = mapData.competitiveRating,
				bounds = mapData.bounds
			})
		end
	end
	
	-- Sort by competitive rating
	table.sort(availableMaps, function(a, b)
		return a.competitiveRating > b.competitiveRating
	end)
	
	return availableMaps
end

function MapManager.GetCurrentMap()
	return currentMap
end

function MapManager.GetMapInfo(mapName)
	return mapRegistry[mapName]
end

function MapManager.SetupEvents()
	-- Set up RemoteEvents for map-related communication
	local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
	
	local MapRemote = Instance.new("RemoteEvent")
	MapRemote.Name = "MapRemote"
	MapRemote.Parent = RemoteRoot
	
	MapRemote.OnServerEvent:Connect(function(player, action, data)
		if action == "GetAvailableMaps" then
			local maps = MapManager.GetAvailableMaps(data.gameMode)
			MapRemote:FireClient(player, "AvailableMaps", maps)
		elseif action == "GetCurrentMap" then
			MapRemote:FireClient(player, "CurrentMap", currentMap)
		end
	end)
end

-- Initialize the map manager
MapManager.Initialize()

return MapManager
