-- WeaponFactoryManager.server.lua
-- Enterprise weapon creation and management system

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WeaponExpansion = require(ReplicatedStorage.Shared.WeaponExpansion)
local WeaponRegistry = require(ReplicatedStorage.Shared.WeaponRegistry)
local Logging = require(ReplicatedStorage.Shared.Logging)

local WeaponFactoryManager = {
	PendingWeapons = {}, -- Weapons waiting to be registered
	ValidationQueue = {}, -- Weapons in validation process
	ActiveFactories = {} -- Active weapon creation processes
}

-- Create weapon factory for batch weapon creation
function WeaponFactoryManager.CreateWeaponFactory(factoryConfig)
	local factory = {
		id = factoryConfig.id or "factory_" .. os.time(),
		weapons = {},
		config = factoryConfig,
		status = "initialized"
	}
	
	WeaponFactoryManager.ActiveFactories[factory.id] = factory
	return factory
end

-- Add weapon to factory
function WeaponFactoryManager.AddWeaponToFactory(factoryId, weaponData)
	local factory = WeaponFactoryManager.ActiveFactories[factoryId]
	if not factory then
		warn("Factory not found: " .. factoryId)
		return false
	end
	
	-- Create weapon using expansion template
	local weapon = WeaponExpansion.CreateWeapon(weaponData)
	table.insert(factory.weapons, weapon)
	
	Logging.Info("WeaponFactoryManager", "Added weapon " .. weapon.Id .. " to factory " .. factoryId)
	return true
end

-- Process factory and register all weapons
function WeaponFactoryManager.ProcessFactory(factoryId)
	local factory = WeaponFactoryManager.ActiveFactories[factoryId]
	if not factory then
		warn("Factory not found: " .. factoryId)
		return false
	end
	
	factory.status = "processing"
	local successCount = 0
	local failCount = 0
	
	for _, weapon in ipairs(factory.weapons) do
		-- Validate weapon
		local issues = WeaponExpansion.ValidateWeapon(weapon)
		
		if #issues == 0 then
			-- Register weapon
			if WeaponRegistry.RegisterWeapon(weapon.Id, weapon) then
				successCount = successCount + 1
				Logging.Info("WeaponFactoryManager", "Successfully registered weapon: " .. weapon.Id)
			else
				failCount = failCount + 1
				Logging.Error("WeaponFactoryManager", "Failed to register weapon: " .. weapon.Id)
			end
		else
			failCount = failCount + 1
			Logging.Error("WeaponFactoryManager", "Weapon validation failed for " .. weapon.Id .. ": " .. table.concat(issues, ", "))
		end
	end
	
	factory.status = "completed"
	factory.results = {
		success = successCount,
		failed = failCount,
		total = successCount + failCount
	}
	
	Logging.Info("WeaponFactoryManager", string.format("Factory %s completed: %d/%d weapons registered successfully", 
		factoryId, successCount, successCount + failCount))
	
	return factory.results
end

-- Create weapon from template with auto-generation
function WeaponFactoryManager.GenerateWeapon(baseTemplate, variations)
	local weapons = {}
	
	for _, variation in ipairs(variations or {{}}) do
		local weaponData = {}
		
		-- Copy base template
		for key, value in pairs(baseTemplate) do
			weaponData[key] = value
		end
		
		-- Apply variations
		for key, value in pairs(variation) do
			weaponData[key] = value
		end
		
		-- Auto-generate ID if not provided
		if not weaponData.Id then
			weaponData.Id = baseTemplate.Id .. "_" .. (#weapons + 1)
		end
		
		local weapon = WeaponExpansion.CreateWeapon(weaponData)
		table.insert(weapons, weapon)
	end
	
	return weapons
end

-- Batch create weapons with progression system
function WeaponFactoryManager.CreateWeaponProgression(weaponFamily)
	local progression = {}
	local baseDamage = weaponFamily.baseDamage or 25
	local baseFireRate = weaponFamily.baseFireRate or 10
	
	for tier = 1, weaponFamily.tiers or 3 do
		-- Calculate tier multipliers
		local damageMultiplier = 1 + (tier - 1) * 0.15 -- 15% damage increase per tier
		local fireRateMultiplier = 1 + (tier - 1) * 0.1 -- 10% fire rate increase per tier
		local costMultiplier = math.pow(1.5, tier - 1) -- Exponential cost increase
		
		local weaponData = {
			Id = weaponFamily.baseId .. "_T" .. tier,
			Name = weaponFamily.baseName .. " Mk" .. tier,
			DisplayName = weaponFamily.baseName .. " Mark " .. tier,
			Category = weaponFamily.category or "Primary",
			Class = weaponFamily.class or "AR",
			
			Damage = math.floor(baseDamage * damageMultiplier),
			FireRate = baseFireRate * fireRateMultiplier,
			MagazineSize = weaponFamily.baseMagazine or 30,
			ReloadTime = weaponFamily.baseReload or 2.5,
			
			Range = weaponFamily.baseRange or 100,
			FalloffStart = weaponFamily.baseFalloffStart or 50,
			FalloffEnd = weaponFamily.baseFalloffEnd or 100,
			
			Cost = math.floor((weaponFamily.baseCost or 1000) * costMultiplier),
			Tier = tier,
			UnlockLevel = (tier - 1) * 10 + (weaponFamily.baseUnlockLevel or 1)
		}
		
		-- Apply family-specific overrides
		if weaponFamily.overrides and weaponFamily.overrides[tier] then
			for key, value in pairs(weaponFamily.overrides[tier]) do
				weaponData[key] = value
			end
		end
		
		local weapon = WeaponExpansion.CreateWeapon(weaponData)
		table.insert(progression, weapon)
	end
	
	return progression
end

-- Real-time weapon balancing system
function WeaponFactoryManager.StartBalancingSystem()
	local balanceConnection = RunService.Heartbeat:Connect(function()
		-- Monitor weapon performance and suggest balance changes
		local stats = WeaponRegistry.GenerateStats()
		
		-- Check for balance issues
		if stats.averageTTK < 0.5 then
			Logging.Warn("WeaponFactoryManager", "Average TTK too low: " .. stats.averageTTK .. "s - Consider damage reduction")
		elseif stats.averageTTK > 3.0 then
			Logging.Warn("WeaponFactoryManager", "Average TTK too high: " .. stats.averageTTK .. "s - Consider damage increase")
		end
	end)
	
	WeaponFactoryManager.BalanceConnection = balanceConnection
end

-- Stop balancing system
function WeaponFactoryManager.StopBalancingSystem()
	if WeaponFactoryManager.BalanceConnection then
		WeaponFactoryManager.BalanceConnection:Disconnect()
		WeaponFactoryManager.BalanceConnection = nil
	end
end

-- Create weapon testing environment
function WeaponFactoryManager.CreateTestingEnvironment(weaponIds)
	local testingData = {
		weapons = {},
		startTime = os.time(),
		results = {}
	}
	
	for _, weaponId in ipairs(weaponIds) do
		local weapon = WeaponRegistry.GetWeapon(weaponId)
		if weapon then
			testingData.weapons[weaponId] = {
				weapon = weapon,
				testResults = {
					damageTests = {},
					rangeTests = {},
					balanceScore = 0
				}
			}
		end
	end
	
	return testingData
end

-- Export weapon configurations for external tools
function WeaponFactoryManager.ExportWeaponConfigs(format)
	local weapons = WeaponRegistry.GetAllWeapons()
	
	if format == "json" then
		-- JSON-like table structure
		local export = {
			metadata = {
				exportTime = os.time(),
				totalWeapons = 0,
				version = "1.0"
			},
			weapons = {}
		}
		
		for weaponId, weapon in pairs(weapons) do
			export.metadata.totalWeapons = export.metadata.totalWeapons + 1
			export.weapons[weaponId] = weapon
		end
		
		return export
	elseif format == "stats" then
		-- Statistical summary
		return WeaponRegistry.GenerateStats()
	else
		-- Raw format
		return weapons
	end
end

-- Initialize factory manager
function WeaponFactoryManager.Initialize()
	-- Start balancing system
	WeaponFactoryManager.StartBalancingSystem()
	
	-- Set up RemoteEvents for weapon management
	local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
	
	-- Create weapon factory events
	local weaponFactoryEvents = RemoteRoot:FindFirstChild("WeaponFactoryEvents")
	if not weaponFactoryEvents then
		weaponFactoryEvents = Instance.new("Folder")
		weaponFactoryEvents.Name = "WeaponFactoryEvents"
		weaponFactoryEvents.Parent = RemoteRoot
	end
	
	-- Create weapon creation remote
	local createWeaponRemote = weaponFactoryEvents:FindFirstChild("CreateWeapon")
	if not createWeaponRemote then
		createWeaponRemote = Instance.new("RemoteEvent")
		createWeaponRemote.Name = "CreateWeapon"
		createWeaponRemote.Parent = weaponFactoryEvents
	end
	
	-- Create weapon query remote
	local queryWeaponsRemote = weaponFactoryEvents:FindFirstChild("QueryWeapons")
	if not queryWeaponsRemote then
		queryWeaponsRemote = Instance.new("RemoteEvent")
		queryWeaponsRemote.Name = "QueryWeapons"
		queryWeaponsRemote.Parent = weaponFactoryEvents
	end
	
	-- Handle weapon creation requests (admin only)
	createWeaponRemote.OnServerEvent:Connect(function(player, weaponData)
		-- Add admin permission check here
		if player.Name == "EliBot68" or player:GetRankInGroup(0) >= 100 then
			local weapon = WeaponExpansion.CreateWeapon(weaponData)
			local success = WeaponRegistry.RegisterWeapon(weapon.Id, weapon)
			
			if success then
				Logging.Info("WeaponFactoryManager", player.Name .. " created weapon: " .. weapon.Id)
			else
				Logging.Error("WeaponFactoryManager", player.Name .. " failed to create weapon: " .. weapon.Id)
			end
		end
	end)
	
	-- Handle weapon queries
	queryWeaponsRemote.OnServerEvent:Connect(function(player, query)
		local results = WeaponRegistry.SearchWeapons(query)
		queryWeaponsRemote:FireClient(player, results)
	end)
	
	Logging.Info("WeaponFactoryManager", "Weapon factory system initialized")
end

-- Start the weapon factory manager
WeaponFactoryManager.Initialize()

return WeaponFactoryManager
