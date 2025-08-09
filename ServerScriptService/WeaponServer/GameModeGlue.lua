--[[
	GameModeGlue.lua
	Place in: ServerScriptService/WeaponServer/
	
	Integration hooks for different game modes (Battle Royale, TDM, FFA)
	to handle weapon spawning, loadout restrictions, and mode-specific logic.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for weapon server
local WeaponServer = require(script.Parent.WeaponServer)

-- Wait for weapon system modules
local WeaponSystem = ReplicatedStorage:WaitForChild("WeaponSystem")
local Modules = WeaponSystem:WaitForChild("Modules")
local WeaponDefinitions = require(Modules:WaitForChild("WeaponDefinitions"))
local WeaponUtils = require(Modules:WaitForChild("WeaponUtils"))

local GameModeGlue = {}

-- Game mode configurations
local GAME_MODE_CONFIGS = {
	BattleRoyale = {
		StartingWeapons = {
			Primary = nil, -- No primary weapon at start
			Secondary = "Pistol", -- Basic pistol only
			Melee = "CombatKnife"
		},
		AllowWeaponPickup = true,
		RespawnWithLoadout = false
	},
	
	TeamDeathmatch = {
		StartingWeapons = {
			Primary = "AssaultRifle",
			Secondary = "Pistol",
			Melee = "CombatKnife"
		},
		AllowWeaponPickup = false,
		RespawnWithLoadout = true
	},
	
	FreeForAll = {
		StartingWeapons = {
			Primary = "AssaultRifle",
			Secondary = "Pistol",
			Melee = "CombatKnife"
		},
		AllowWeaponPickup = false,
		RespawnWithLoadout = true
	},
	
	Practice = {
		StartingWeapons = {
			Primary = "AssaultRifle",
			Secondary = "Pistol",
			Melee = "CombatKnife"
		},
		AllowWeaponPickup = true,
		RespawnWithLoadout = true,
		UnlimitedAmmo = true
	}
}

-- Current game mode
local CurrentGameMode = "Practice" -- Default to practice mode

-- Player game mode states
local PlayerGameStates = {} -- [UserId] = {GameMode, Team, Loadout}

-- Set game mode
function GameModeGlue.SetGameMode(gameMode: string)
	if not GAME_MODE_CONFIGS[gameMode] then
		warn("Invalid game mode:", gameMode)
		return false
	end
	
	CurrentGameMode = gameMode
	print("Game mode set to:", gameMode)
	
	-- Apply mode to all existing players
	for _, player in ipairs(Players:GetPlayers()) do
		GameModeGlue.ApplyGameModeToPlayer(player, gameMode)
	end
	
	return true
end

-- Apply game mode configuration to player
function GameModeGlue.ApplyGameModeToPlayer(player: Player, gameMode: string?)
	gameMode = gameMode or CurrentGameMode
	local config = GAME_MODE_CONFIGS[gameMode]
	
	if not config then
		warn("Invalid game mode for player:", gameMode)
		return
	end
	
	local userId = player.UserId
	
	-- Initialize player game state
	PlayerGameStates[userId] = {
		GameMode = gameMode,
		Team = nil, -- Set by team assignment
		Loadout = {}
	}
	
	-- Apply starting weapon loadout
	local loadout = {}
	for slot, weaponId in pairs(config.StartingWeapons) do
		if weaponId then
			loadout[slot] = weaponId
		end
	end
	
	-- Set player loadout through weapon server
	WeaponServer.SetPlayerLoadout(player, loadout)
	
	print(string.format("Applied %s mode to player %s", gameMode, player.Name))
end

-- Handle player spawn in game mode
function GameModeGlue.OnPlayerSpawn(player: Player, gameMode: string?)
	gameMode = gameMode or CurrentGameMode
	local config = GAME_MODE_CONFIGS[gameMode]
	
	if not config then return end
	
	if config.RespawnWithLoadout then
		-- Give player their loadout on respawn
		GameModeGlue.ApplyGameModeToPlayer(player, gameMode)
	end
	
	-- Handle unlimited ammo for practice mode
	if gameMode == "Practice" and config.UnlimitedAmmo then
		GameModeGlue.EnableUnlimitedAmmo(player)
	end
end

-- Enable unlimited ammo for player (practice mode)
function GameModeGlue.EnableUnlimitedAmmo(player: Player)
	local playerWeapons = WeaponServer.GetPlayerWeapons(player)
	if not playerWeapons then return end
	
	-- Set all weapon ammo to maximum
	for weaponId, _ in pairs(playerWeapons.Ammo) do
		local weapon = WeaponDefinitions.GetWeapon(weaponId)
		if weapon then
			playerWeapons.Ammo[weaponId] = weapon.MagazineSize
		end
	end
end

-- Handle weapon pickup (Battle Royale mode)
function GameModeGlue.HandleWeaponPickup(player: Player, weaponId: string): boolean
	local userId = player.UserId
	local gameState = PlayerGameStates[userId]
	
	if not gameState then
		return false
	end
	
	local config = GAME_MODE_CONFIGS[gameState.GameMode]
	if not config or not config.AllowWeaponPickup then
		return false -- Weapon pickup not allowed in this mode
	end
	
	local weapon = WeaponDefinitions.GetWeapon(weaponId)
	if not weapon then
		return false
	end
	
	-- Determine which slot to place the weapon in
	local targetSlot = weapon.Slot
	
	-- Create new loadout with picked up weapon
	local newLoadout = {}
	newLoadout[targetSlot] = weaponId
	
	-- Set the new weapon
	WeaponServer.SetPlayerLoadout(player, newLoadout)
	
	print(string.format("%s picked up %s", player.Name, weapon.Name))
	return true
end

-- Create weapon pickup (for Battle Royale)
function GameModeGlue.CreateWeaponPickup(weaponId: string, position: Vector3): Part?
	local weapon = WeaponDefinitions.GetWeapon(weaponId)
	if not weapon then
		return nil
	end
	
	-- Create pickup part
	local pickup = Instance.new("Part")
	pickup.Name = "WeaponPickup_" .. weaponId
	pickup.Size = Vector3.new(2, 0.5, 4)
	pickup.Position = position
	pickup.Material = Enum.Material.Neon
	pickup.Color = Color3.fromRGB(0, 150, 255) -- Blue glow
	pickup.Anchored = true
	pickup.CanCollide = false
	pickup.Parent = workspace
	
	-- Add weapon model
	local weaponModel = WeaponUtils.GetWeaponModel(weapon.ModelId)
	if weaponModel then
		weaponModel.Parent = pickup
		weaponModel:SetPrimaryPartCFrame(pickup.CFrame)
	end
	
	-- Add pickup label
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.Parent = pickup
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = weapon.Name
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.SourceSansBold
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Parent = billboard
	
	-- Handle pickup interaction
	local touched = false
	pickup.Touched:Connect(function(hit)
		if touched then return end
		
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		
		if player then
			local success = GameModeGlue.HandleWeaponPickup(player, weaponId)
			if success then
				touched = true
				pickup:Destroy()
			end
		end
	end)
	
	return pickup
end

-- Handle team assignment (for team-based modes)
function GameModeGlue.AssignPlayerToTeam(player: Player, teamName: string)
	local userId = player.UserId
	local gameState = PlayerGameStates[userId]
	
	if gameState then
		gameState.Team = teamName
		print(string.format("Assigned %s to team %s", player.Name, teamName))
	end
end

-- Get player's current game state
function GameModeGlue.GetPlayerGameState(player: Player)
	return PlayerGameStates[player.UserId]
end

-- Handle match start
function GameModeGlue.OnMatchStart(gameMode: string)
	GameModeGlue.SetGameMode(gameMode)
	
	-- Apply game mode to all players
	for _, player in ipairs(Players:GetPlayers()) do
		GameModeGlue.OnPlayerSpawn(player, gameMode)
	end
	
	print("Match started with mode:", gameMode)
end

-- Handle match end
function GameModeGlue.OnMatchEnd()
	-- Reset all players to practice mode
	GameModeGlue.SetGameMode("Practice")
	
	print("Match ended, returning to practice mode")
end

-- Spawn random weapons (Battle Royale)
function GameModeGlue.SpawnRandomWeapons(spawnPoints: {Vector3}, weaponCount: number?)
	weaponCount = weaponCount or 10
	
	-- Get all available weapons except melee
	local availableWeapons = {}
	for _, slot in ipairs({"Primary", "Secondary"}) do
		local weapons = WeaponDefinitions.GetWeaponsForSlot(slot)
		for _, weapon in ipairs(weapons) do
			table.insert(availableWeapons, weapon.Id)
		end
	end
	
	-- Spawn random weapons at spawn points
	for i = 1, math.min(weaponCount, #spawnPoints) do
		local spawnPoint = spawnPoints[i]
		local randomWeapon = availableWeapons[math.random(#availableWeapons)]
		
		GameModeGlue.CreateWeaponPickup(randomWeapon, spawnPoint)
	end
	
	print(string.format("Spawned %d random weapons", math.min(weaponCount, #spawnPoints)))
end

-- Clean up player on leave
local function onPlayerRemoving(player: Player)
	local userId = player.UserId
	PlayerGameStates[userId] = nil
end

-- Connect events
Players.PlayerAdded:Connect(function(player)
	-- Apply current game mode to new player
	GameModeGlue.ApplyGameModeToPlayer(player, CurrentGameMode)
end)

Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Initialize for existing players
for _, player in ipairs(Players:GetPlayers()) do
	GameModeGlue.ApplyGameModeToPlayer(player, CurrentGameMode)
end

print("GameModeGlue initialized with mode:", CurrentGameMode)

return GameModeGlue
