--[[
	DataStoreExamples.server.lua
	Enterprise DataStore System Usage Examples
	Phase 2.5: Implementation Examples and Best Practices

	Examples:
	- Basic player data management
	- Advanced validation and migration
	- Backup and recovery scenarios
	- Performance optimization techniques
	- Integration with existing systems
	- Error handling patterns
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ServiceLocator = require(ReplicatedStorage.Shared.ServiceLocator)
local Logging = require(ReplicatedStorage.Shared.Logging)
local DataValidator = require(ReplicatedStorage.Shared.DataValidator)

-- Wait for services to be available
local DataManager = ServiceLocator.Get("DataManager")
local DataMigration = ServiceLocator.Get("DataMigration")

local DataStoreExamples = {}

--[[
	Example 1: Basic Player Data Management
	
	This example shows how to handle player joining and leaving
	with proper data loading, validation, and saving.
]]
function DataStoreExamples.BasicPlayerDataManagement()
	Logging.Info("DataStoreExamples", "=== Example 1: Basic Player Data Management ===")
	
	-- Simulate player joining
	local function onPlayerJoined(player)
		Logging.Info("DataStoreExamples", "Player joined: " .. player.Name, {userId = player.UserId})
		
		-- Load player data
		local loadResult = DataManager.LoadPlayerData(player.UserId)
		
		if loadResult.success then
			Logging.Info("DataStoreExamples", "Player data loaded successfully", {
				userId = player.UserId,
				source = loadResult.source,
				timeTaken = loadResult.timeTaken
			})
			
			-- Validate the loaded data
			local validationResult = DataValidator.ValidateData(loadResult.data)
			if not validationResult.isValid then
				Logging.Warn("DataStoreExamples", "Player data has validation issues", {
					userId = player.UserId,
					errors = validationResult.errors,
					warnings = validationResult.warnings
				})
			end
			
			-- Check if migration is needed
			if DataMigration.IsMigrationNeeded(loadResult.data) then
				Logging.Info("DataStoreExamples", "Player data needs migration", {userId = player.UserId})
				
				local migrationResult = DataMigration.MigrateData(player.UserId, loadResult.data)
				if migrationResult.success then
					Logging.Info("DataStoreExamples", "Player data migrated successfully", {
						userId = player.UserId,
						fromVersion = migrationResult.fromVersion,
						toVersion = migrationResult.toVersion
					})
				else
					Logging.Error("DataStoreExamples", "Player data migration failed", {
						userId = player.UserId,
						errors = migrationResult.errors
					})
				end
			end
			
			-- Example: Update playtime when player joins
			loadResult.data.lastSeen = os.time()
			
		else
			Logging.Error("DataStoreExamples", "Failed to load player data", {
				userId = player.UserId,
				error = loadResult.error
			})
		end
	end
	
	-- Simulate player leaving
	local function onPlayerLeaving(player)
		Logging.Info("DataStoreExamples", "Player leaving: " .. player.Name, {userId = player.UserId})
		
		-- Load current data and update playtime
		local loadResult = DataManager.LoadPlayerData(player.UserId)
		if loadResult.success then
			-- Update last seen and calculate session playtime
			local currentTime = os.time()
			local sessionStart = loadResult.data.lastSeen or currentTime
			local sessionPlaytime = currentTime - sessionStart
			
			loadResult.data.playtime = (loadResult.data.playtime or 0) + sessionPlaytime
			loadResult.data.lastSeen = currentTime
			
			-- Save updated data
			local saveResult = DataManager.SavePlayerData(player.UserId, loadResult.data)
			if saveResult.success then
				Logging.Info("DataStoreExamples", "Player data saved on leave", {
					userId = player.UserId,
					sessionPlaytime = sessionPlaytime,
					totalPlaytime = loadResult.data.playtime,
					timeTaken = saveResult.timeTaken
				})
			else
				Logging.Error("DataStoreExamples", "Failed to save player data on leave", {
					userId = player.UserId,
					error = saveResult.error
				})
			end
		end
	end
	
	-- Example usage with test player
	local testPlayer = {UserId = 123456, Name = "ExamplePlayer"}
	onPlayerJoined(testPlayer)
	wait(1)
	onPlayerLeaving(testPlayer)
end

--[[
	Example 2: Advanced Validation with Custom Rules
	
	Shows how to implement custom validation rules for
	specific game mechanics and data integrity.
]]
function DataStoreExamples.AdvancedValidationExample()
	Logging.Info("DataStoreExamples", "=== Example 2: Advanced Validation with Custom Rules ===")
	
	-- Register custom validation schema for weapon data
	local weaponSchema = {
		version = 1.0,
		rules = {
			weaponId = {
				type = "string",
				required = true,
				pattern = "^weapon_%w+$"
			},
			damage = {
				type = "number",
				required = true,
				min = 1,
				max = 200,
				custom = function(value)
					-- Custom rule: damage must be multiple of 5
					if value % 5 ~= 0 then
						return false, "Damage must be multiple of 5"
					end
					return true
				end
			},
			rarity = {
				type = "string",
				required = true,
				enum = {"common", "rare", "epic", "legendary"}
			},
			attachments = {
				type = "table",
				required = false,
				children = {
					scope = {type = "string", required = false},
					barrel = {type = "string", required = false},
					stock = {type = "string", required = false}
				}
			}
		}
	}
	
	DataValidator.RegisterSchema("WeaponData", weaponSchema)
	
	-- Test valid weapon data
	local validWeapon = {
		weaponId = "weapon_ak47",
		damage = 35,
		rarity = "rare",
		attachments = {
			scope = "red_dot",
			barrel = "extended"
		}
	}
	
	local validResult = DataValidator.ValidateWithSchema(validWeapon, "WeaponData")
	assert(validResult.isValid, "Valid weapon should pass validation")
	
	Logging.Info("DataStoreExamples", "Valid weapon data passed validation", {
		weaponId = validWeapon.weaponId,
		isValid = validResult.isValid
	})
	
	-- Test invalid weapon data
	local invalidWeapon = {
		weaponId = "invalid_format", -- Doesn't match pattern
		damage = 33, -- Not multiple of 5
		rarity = "ultra_rare" -- Not in enum
	}
	
	local invalidResult = DataValidator.ValidateWithSchema(invalidWeapon, "WeaponData")
	assert(not invalidResult.isValid, "Invalid weapon should fail validation")
	
	Logging.Info("DataStoreExamples", "Invalid weapon data failed validation as expected", {
		errors = invalidResult.errors,
		errorCount = #invalidResult.errors
	})
end

--[[
	Example 3: Backup and Recovery Scenarios
	
	Demonstrates how to handle data corruption, recovery
	from backups, and emergency data restoration.
]]
function DataStoreExamples.BackupRecoveryExample()
	Logging.Info("DataStoreExamples", "=== Example 3: Backup and Recovery Scenarios ===")
	
	local testUserId = 789012
	
	-- Create and save initial data
	local originalData = DataValidator.CreateDefaultPlayerData(testUserId, "BackupTest")
	originalData.level = 25
	originalData.currency = 5000
	originalData.statistics.kills = 150
	
	Logging.Info("DataStoreExamples", "Saving original data", {
		userId = testUserId,
		level = originalData.level,
		currency = originalData.currency
	})
	
	local saveResult = DataManager.SavePlayerData(testUserId, originalData)
	assert(saveResult.success, "Original data save should succeed")
	assert(saveResult.backupSaved, "Backup should be created")
	
	wait(0.5) -- Ensure save completes
	
	-- Force create additional backup
	local forceBackupResult = DataManager.ForceBackup(testUserId)
	assert(forceBackupResult, "Forced backup should succeed")
	
	Logging.Info("DataStoreExamples", "Backup created successfully")
	
	-- Simulate data corruption by modifying loaded data
	local loadResult = DataManager.LoadPlayerData(testUserId)
	assert(loadResult.success, "Data load should succeed")
	
	-- Corrupt the data
	loadResult.data.level = "corrupted"
	loadResult.data.currency = nil
	loadResult.data.circular = loadResult.data -- Create circular reference
	
	-- Test corruption detection
	local corruptionCheck = DataValidator.DetectCorruption(loadResult.data)
	assert(corruptionCheck.corrupted, "Should detect data corruption")
	
	Logging.Info("DataStoreExamples", "Data corruption detected", {
		issues = corruptionCheck.issues
	})
	
	-- Attempt recovery from backup
	local recoveredData = DataManager.LoadLatestBackup(testUserId)
	if recoveredData then
		Logging.Info("DataStoreExamples", "Data recovered from backup", {
			userId = testUserId,
			level = recoveredData.level,
			currency = recoveredData.currency
		})
		
		assert(recoveredData.level == 25, "Should recover original level")
		assert(recoveredData.currency == 5000, "Should recover original currency")
	else
		Logging.Error("DataStoreExamples", "Failed to recover data from backup")
	end
	
	-- Test emergency recovery
	local emergencyResult = DataManager.EmergencyRecovery(testUserId)
	Logging.Info("DataStoreExamples", "Emergency recovery result", {
		success = emergencyResult.success,
		source = emergencyResult.source
	})
end

--[[
	Example 4: Performance Optimization Techniques
	
	Shows best practices for high-performance data operations,
	batch processing, and resource management.
]]
function DataStoreExamples.PerformanceOptimizationExample()
	Logging.Info("DataStoreExamples", "=== Example 4: Performance Optimization Techniques ===")
	
	-- Batch operation example
	local batchUsers = {}
	for i = 1, 10 do
		local userId = 400000 + i
		table.insert(batchUsers, {
			userId = userId,
			data = DataValidator.CreateDefaultPlayerData(userId, "BatchUser" .. i)
		})
	end
	
	-- Measure batch save performance
	local batchStartTime = tick()
	local batchResults = {}
	
	for _, user in ipairs(batchUsers) do
		local saveResult = DataManager.SavePlayerData(user.userId, user.data)
		table.insert(batchResults, {
			userId = user.userId,
			success = saveResult.success,
			timeTaken = saveResult.timeTaken
		})
	end
	
	local batchTotalTime = (tick() - batchStartTime) * 1000
	
	-- Calculate statistics
	local successCount = 0
	local totalSaveTime = 0
	
	for _, result in ipairs(batchResults) do
		if result.success then
			successCount += 1
		end
		totalSaveTime += result.timeTaken
	end
	
	local successRate = (successCount / #batchResults) * 100
	local averageSaveTime = totalSaveTime / #batchResults
	
	Logging.Info("DataStoreExamples", "Batch operation performance", {
		userCount = #batchUsers,
		successCount = successCount,
		successRate = successRate,
		totalTime = batchTotalTime,
		averageSaveTime = averageSaveTime
	})
	
	-- Memory optimization example - cleanup old data
	task.spawn(function()
		for _, user in ipairs(batchUsers) do
			-- Cleanup old backups to manage storage
			DataManager.CleanupOldBackups(user.userId)
		end
		Logging.Info("DataStoreExamples", "Cleanup completed for batch users")
	end)
end

--[[
	Example 5: Integration with Game Systems
	
	Demonstrates how to integrate the DataStore system
	with other game systems like achievements, economy, etc.
]]
function DataStoreExamples.GameSystemIntegrationExample()
	Logging.Info("DataStoreExamples", "=== Example 5: Game System Integration ===")
	
	local playerId = 500001
	
	-- Load player data
	local loadResult = DataManager.LoadPlayerData(playerId)
	if not loadResult.success then
		-- Create new player
		local newData = DataValidator.CreateDefaultPlayerData(playerId, "IntegrationTest")
		DataManager.SavePlayerData(playerId, newData)
		loadResult = DataManager.LoadPlayerData(playerId)
	end
	
	local playerData = loadResult.data
	
	-- Example: Player kills an enemy
	local function onPlayerKill(killerUserId, victimUserId, weaponUsed, isHeadshot)
		local killerData = DataManager.LoadPlayerData(killerUserId).data
		if killerData then
			-- Update kill statistics
			killerData.statistics.kills += 1
			if isHeadshot then
				killerData.statistics.headshots += 1
			end
			
			-- Award experience and currency
			local expGained = isHeadshot and 150 or 100
			local currencyGained = isHeadshot and 50 or 25
			
			killerData.experience += expGained
			killerData.currency += currencyGained
			
			-- Check for level up
			local expNeededForNextLevel = killerData.level * 1000
			if killerData.experience >= expNeededForNextLevel then
				killerData.level += 1
				killerData.experience -= expNeededForNextLevel
				
				Logging.Info("DataStoreExamples", "Player leveled up!", {
					userId = killerUserId,
					newLevel = killerData.level
				})
			end
			
			-- Check achievements
			if killerData.statistics.kills == 100 then
				if not killerData.achievements.unlocked["centurion"] then
					killerData.achievements.unlocked["centurion"] = os.time()
					killerData.currency += 1000 -- Achievement reward
					
					Logging.Info("DataStoreExamples", "Achievement unlocked: Centurion", {
						userId = killerUserId
					})
				end
			end
			
			-- Save updated data
			local saveResult = DataManager.SavePlayerData(killerUserId, killerData)
			if saveResult.success then
				Logging.Info("DataStoreExamples", "Player progress saved", {
					userId = killerUserId,
					kills = killerData.statistics.kills,
					level = killerData.level,
					currency = killerData.currency
				})
			end
		end
	end
	
	-- Example: Player purchases item
	local function onPlayerPurchase(userId, itemId, cost, currencyType)
		local playerDataResult = DataManager.LoadPlayerData(userId)
		if playerDataResult.success then
			local data = playerDataResult.data
			
			-- Check if player has enough currency
			local currentCurrency = currencyType == "premium" and data.premiumCurrency or data.currency
			
			if currentCurrency >= cost then
				-- Deduct currency
				if currencyType == "premium" then
					data.premiumCurrency -= cost
				else
					data.currency -= cost
				end
				
				-- Add item to inventory
				if not data.inventory.items then
					data.inventory.items = {}
				end
				
				if not data.inventory.items[itemId] then
					data.inventory.items[itemId] = 0
				end
				data.inventory.items[itemId] += 1
				
				-- Save transaction
				local saveResult = DataManager.SavePlayerData(userId, data)
				if saveResult.success then
					Logging.Info("DataStoreExamples", "Purchase completed", {
						userId = userId,
						itemId = itemId,
						cost = cost,
						currencyType = currencyType,
						remainingCurrency = currencyType == "premium" and data.premiumCurrency or data.currency
					})
					return true
				else
					Logging.Error("DataStoreExamples", "Failed to save purchase", {
						userId = userId,
						error = saveResult.error
					})
				end
			else
				Logging.Warn("DataStoreExamples", "Insufficient currency for purchase", {
					userId = userId,
					required = cost,
					available = currentCurrency
				})
			end
		end
		return false
	end
	
	-- Simulate game events
	onPlayerKill(playerId, 999999, "weapon_ak47", true) -- Headshot kill
	onPlayerPurchase(playerId, "weapon_skin_gold", 500, "regular")
end

--[[
	Example 6: Error Handling Patterns
	
	Shows comprehensive error handling strategies
	and graceful degradation techniques.
]]
function DataStoreExamples.ErrorHandlingExample()
	Logging.Info("DataStoreExamples", "=== Example 6: Error Handling Patterns ===")
	
	-- Example: Robust data loading with fallbacks
	local function robustLoadPlayerData(userId)
		local attempts = 0
		local maxAttempts = 3
		
		while attempts < maxAttempts do
			attempts += 1
			
			local loadResult = DataManager.LoadPlayerData(userId)
			
			if loadResult.success then
				-- Validate loaded data
				local validationResult = DataValidator.ValidateData(loadResult.data)
				
				if validationResult.isValid then
					return loadResult.data, "primary"
				else
					Logging.Warn("DataStoreExamples", "Loaded data failed validation, trying backup", {
						userId = userId,
						attempt = attempts
					})
					
					-- Try backup
					local backupData = DataManager.LoadLatestBackup(userId)
					if backupData then
						local backupValidation = DataValidator.ValidateData(backupData)
						if backupValidation.isValid then
							return backupData, "backup"
						end
					end
				end
			end
			
			if attempts < maxAttempts then
				Logging.Warn("DataStoreExamples", "Load attempt failed, retrying", {
					userId = userId,
					attempt = attempts,
					error = loadResult.error
				})
				wait(1) -- Wait before retry
			end
		end
		
		-- All attempts failed, create default data
		Logging.Error("DataStoreExamples", "All load attempts failed, creating default data", {
			userId = userId
		})
		
		return DataValidator.CreateDefaultPlayerData(userId, "ErrorRecovery"), "default"
	end
	
	-- Example: Safe save operation with validation
	local function safeSavePlayerData(userId, data)
		-- Pre-save validation
		local validationResult = DataValidator.ValidateData(data)
		if not validationResult.isValid then
			Logging.Error("DataStoreExamples", "Cannot save invalid data", {
				userId = userId,
				errors = validationResult.errors
			})
			return false, "Data validation failed"
		end
		
		-- Check for corruption
		local corruptionCheck = DataValidator.DetectCorruption(data)
		if corruptionCheck.corrupted then
			Logging.Error("DataStoreExamples", "Cannot save corrupted data", {
				userId = userId,
				issues = corruptionCheck.issues
			})
			return false, "Data corruption detected"
		end
		
		-- Attempt save
		local saveResult = DataManager.SavePlayerData(userId, data)
		
		if not saveResult.success then
			-- Try emergency backup
			Logging.Warn("DataStoreExamples", "Primary save failed, creating emergency backup", {
				userId = userId,
				error = saveResult.error
			})
			
			local backupResult = DataManager.ForceBackup(userId)
			if backupResult then
				return false, "Primary save failed but emergency backup created"
			else
				return false, "Primary save and emergency backup both failed"
			end
		end
		
		return true, "Save successful"
	end
	
	-- Test error handling
	local testUserId = 600001
	
	-- Test robust loading
	local data, source = robustLoadPlayerData(testUserId)
	Logging.Info("DataStoreExamples", "Robust load completed", {
		userId = testUserId,
		source = source,
		hasData = data ~= nil
	})
	
	-- Test safe saving
	if data then
		local success, message = safeSavePlayerData(testUserId, data)
		Logging.Info("DataStoreExamples", "Safe save completed", {
			userId = testUserId,
			success = success,
			message = message
		})
	end
end

-- Main function to run all examples
function DataStoreExamples.RunAllExamples()
	Logging.Info("DataStoreExamples", "🚀 Running Enterprise DataStore System Examples")
	
	local examples = {
		{"Basic Player Data Management", DataStoreExamples.BasicPlayerDataManagement},
		{"Advanced Validation", DataStoreExamples.AdvancedValidationExample},
		{"Backup and Recovery", DataStoreExamples.BackupRecoveryExample},
		{"Performance Optimization", DataStoreExamples.PerformanceOptimizationExample},
		{"Game System Integration", DataStoreExamples.GameSystemIntegrationExample},
		{"Error Handling", DataStoreExamples.ErrorHandlingExample}
	}
	
	for i, example in ipairs(examples) do
		Logging.Info("DataStoreExamples", string.format("Running Example %d: %s", i, example[1]))
		
		local success, result = pcall(example[2])
		if success then
			Logging.Info("DataStoreExamples", "✅ Example completed successfully: " .. example[1])
		else
			Logging.Error("DataStoreExamples", "❌ Example failed: " .. example[1], {
				error = tostring(result)
			})
		end
		
		wait(0.5) -- Brief pause between examples
	end
	
	Logging.Info("DataStoreExamples", "🎉 All Enterprise DataStore Examples Completed!")
	
	-- Display final statistics
	local stats = {
		dataValidator = DataValidator.GetValidationStats(),
		dataManager = DataManager.GetDataStats(),
		dataMigration = DataMigration.GetMigrationStats()
	}
	
	Logging.Info("DataStoreExamples", "📊 Final System Statistics", stats)
end

-- Auto-run examples (can be disabled in production)
local AUTO_RUN_EXAMPLES = false -- Set to true to auto-run examples

if AUTO_RUN_EXAMPLES then
	task.spawn(function()
		task.wait(3) -- Wait for system initialization
		DataStoreExamples.RunAllExamples()
	end)
end

return DataStoreExamples
