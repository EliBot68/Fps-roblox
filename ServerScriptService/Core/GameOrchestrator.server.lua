-- GameOrchestrator.server.lua
-- Master orchestrator that coordinates all enterprise systems

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Logging = require(ReplicatedStorage.Shared.Logging)

local GameOrchestrator = {}

-- System references
local systems = {}
local orchestratorState = {
	initialized = false,
	activeMatches = {},
	playerStates = {},
	serverHealth = "healthy",
	lastHealthCheck = 0
}

function GameOrchestrator.Initialize()
	Logging.Info("GameOrchestrator", "Starting enterprise game orchestration...")
	
	-- Get references to all systems
	systems = {
		SystemManager = require(script.Parent.SystemManager),
		NetworkManager = require(script.Parent.NetworkManager),
		GameStateManager = require(script.Parent.GameStateManager),
		Combat = require(script.Parent.Combat),
		Matchmaker = require(script.Parent.Matchmaker),
		DataStore = require(script.Parent.DataStore),
		RankManager = require(script.Parent.RankManager),
		AntiCheat = require(script.Parent.AntiCheat),
		MapManager = require(script.Parent.MapManager),
		MetricsDashboard = require(script.Parent.MetricsDashboard),
		StatisticsAnalytics = require(script.Parent.StatisticsAnalytics),
		CurrencyManager = require(script.Parent.Parent.Economy.CurrencyManager),
	}
	
	-- Set up cross-system integration
	GameOrchestrator.SetupSystemIntegration()
	
	-- Set up player management
	GameOrchestrator.SetupPlayerManagement()
	
	-- Start orchestration loops
	GameOrchestrator.StartOrchestrationLoops()
	
	orchestratorState.initialized = true
	Logging.Info("GameOrchestrator", "✓ Enterprise orchestration active")
end

function GameOrchestrator.SetupSystemIntegration()
	-- Integrate Combat with other systems
	if systems.Combat then
		-- Connect kills to currency rewards
		local originalProcessKill = systems.Combat.ProcessKill
		if originalProcessKill then
			systems.Combat.ProcessKill = function(killer, victim, weaponId, isHeadshot)
				-- Call original function
				originalProcessKill(killer, victim, weaponId, isHeadshot)
				
				-- Add currency reward
				local reward = GameConfig.Economy.KillReward
				if isHeadshot then
					reward = reward * 1.5 -- Headshot bonus
				end
				
				if systems.CurrencyManager then
					systems.CurrencyManager.AddCurrency(killer, reward, "Kill")
				end
				
				-- Update statistics
				if systems.StatisticsAnalytics then
					systems.StatisticsAnalytics.RecordKill(killer, victim, weaponId, isHeadshot)
				end
				
				-- Check for achievements/streaks
				GameOrchestrator.CheckKillAchievements(killer, victim, isHeadshot)
			end
		end
		
		-- Connect damage to anti-cheat
		local originalProcessDamage = systems.Combat.ProcessDamage
		if originalProcessDamage then
			systems.Combat.ProcessDamage = function(attacker, victim, damage, weaponId, hitPart)
				-- Anti-cheat validation
				if systems.AntiCheat then
					local isValid = systems.AntiCheat.ValidateDamage(attacker, victim, damage, weaponId)
					if not isValid then
						Logging.Warn("GameOrchestrator", "Suspicious damage detected from " .. attacker.Name)
						return false
					end
				end
				
				-- Call original function
				return originalProcessDamage(attacker, victim, damage, weaponId, hitPart)
			end
		end
	end
	
	-- Integrate Matchmaker with GameState
	if systems.Matchmaker and systems.GameStateManager then
		-- Override match creation
		local originalCreateMatch = systems.Matchmaker.CreateMatch
		if originalCreateMatch then
			systems.Matchmaker.CreateMatch = function(players, mode, mapName)
				-- Notify game state manager
				systems.GameStateManager.OnMatchFound({
					players = players,
					mode = mode,
					map = mapName
				})
				
				-- Call original function
				return originalCreateMatch(players, mode, mapName)
			end
		end
	end
	
	-- Integrate RankManager with match results
	if systems.RankManager then
		local originalUpdateRank = systems.RankManager.UpdateFromMatch
		if originalUpdateRank then
			systems.RankManager.UpdateFromMatch = function(player, won, performance)
				-- Call original function
				local oldRank = systems.RankManager.Get(player)
				originalUpdateRank(player, won, performance)
				local newRank = systems.RankManager.Get(player)
				
				-- Check for rank up rewards
				if newRank > oldRank then
					GameOrchestrator.HandleRankUp(player, oldRank, newRank)
				end
				
				-- Update analytics
				if systems.StatisticsAnalytics then
					systems.StatisticsAnalytics.RecordRankChange(player, oldRank, newRank)
				end
			end
		end
	end
end

function GameOrchestrator.SetupPlayerManagement()
	-- Enhanced player join handling
	Players.PlayerAdded:Connect(function(player)
		GameOrchestrator.OnPlayerJoined(player)
	end)
	
	-- Enhanced player leave handling
	Players.PlayerRemoving:Connect(function(player)
		GameOrchestrator.OnPlayerLeaving(player)
	end)
end

function GameOrchestrator.OnPlayerJoined(player)
	Logging.Event("PlayerJoinedOrchestrator", {
		u = player.UserId,
		name = player.Name,
		timestamp = os.time()
	})
	
	-- Initialize player state
	orchestratorState.playerStates[player.UserId] = {
		joinTime = os.time(),
		currentState = "lobby",
		currentMatch = nil,
		performance = {
			kills = 0,
			deaths = 0,
			accuracy = 0,
			playtime = 0
		},
		flags = {
			suspicious = false,
			afk = false,
			newPlayer = true
		}
	}
	
	-- Set up player monitoring
	spawn(function()
		GameOrchestrator.MonitorPlayer(player)
	end)
	
	-- Send welcome message with game info
	spawn(function()
		wait(2) -- Let player load in
		GameOrchestrator.SendWelcomeMessage(player)
	end)
	
	-- Check for returning player bonuses
	if systems.DataStore then
		local profile = systems.DataStore.Get(player)
		if profile and profile.TotalMatches > 0 then
			orchestratorState.playerStates[player.UserId].flags.newPlayer = false
			GameOrchestrator.HandleReturningPlayer(player, profile)
		end
	end
end

function GameOrchestrator.OnPlayerLeaving(player)
	local playerState = orchestratorState.playerStates[player.UserId]
	if not playerState then return end
	
	local sessionTime = os.time() - playerState.joinTime
	
	Logging.Event("PlayerLeftOrchestrator", {
		u = player.UserId,
		sessionTime = sessionTime,
		performance = playerState.performance
	})
	
	-- Handle mid-match leave
	if playerState.currentMatch then
		GameOrchestrator.HandleMidMatchLeave(player, playerState.currentMatch)
	end
	
	-- Update analytics
	if systems.StatisticsAnalytics then
		systems.StatisticsAnalytics.RecordSessionEnd(player, sessionTime, playerState.performance)
	end
	
	-- Clean up
	orchestratorState.playerStates[player.UserId] = nil
end

function GameOrchestrator.MonitorPlayer(player)
	local playerState = orchestratorState.playerStates[player.UserId]
	if not playerState then return end
	
	while player.Parent and playerState do
		wait(10) -- Check every 10 seconds
		
		-- Update playtime
		playerState.performance.playtime = os.time() - playerState.joinTime
		
		-- Check for AFK
		GameOrchestrator.CheckPlayerAFK(player, playerState)
		
		-- Check network quality
		if systems.NetworkManager then
			local quality = systems.NetworkManager.GetConnectionQuality(player)
			if quality == "poor" then
				GameOrchestrator.HandlePoorConnection(player)
			end
		end
		
		-- Update state reference
		playerState = orchestratorState.playerStates[player.UserId]
	end
end

function GameOrchestrator.CheckKillAchievements(killer, victim, isHeadshot)
	local playerState = orchestratorState.playerStates[killer.UserId]
	if not playerState then return end
	
	playerState.performance.kills = playerState.performance.kills + 1
	
	-- Check for kill streaks
	local killStreak = playerState.performance.kills - playerState.performance.deaths
	
	if killStreak == 5 then
		GameOrchestrator.AwardKillStreak(killer, "Killing Spree", 5)
	elseif killStreak == 10 then
		GameOrchestrator.AwardKillStreak(killer, "Rampage", 10)
	elseif killStreak == 15 then
		GameOrchestrator.AwardKillStreak(killer, "Unstoppable", 15)
	end
	
	-- Headshot achievements
	if isHeadshot then
		GameOrchestrator.CheckHeadshotAchievements(killer)
	end
end

function GameOrchestrator.AwardKillStreak(player, streakName, count)
	-- Award currency bonus
	local bonus = GameConfig.Economy.StreakBonusMultiplier * count * 10
	if systems.CurrencyManager then
		systems.CurrencyManager.AddCurrency(player, bonus, "KillStreak_" .. streakName)
	end
	
	-- Send notification
	GameOrchestrator.SendPlayerNotification(player, streakName .. "! +" .. bonus .. " coins", "success")
	
	-- Broadcast to all players
	GameOrchestrator.BroadcastKillStreak(player, streakName, count)
end

function GameOrchestrator.CheckHeadshotAchievements(player)
	-- Implementation for headshot-based achievements
	if systems.StatisticsAnalytics then
		local stats = systems.StatisticsAnalytics.GetPlayerStats(player)
		if stats and stats.headshots then
			if stats.headshots % 50 == 0 then -- Every 50 headshots
				local reward = 500
				if systems.CurrencyManager then
					systems.CurrencyManager.AddCurrency(player, reward, "HeadshotMilestone")
				end
				GameOrchestrator.SendPlayerNotification(player, 
					"Headshot Master! " .. stats.headshots .. " headshots! +" .. reward .. " coins", "success")
			end
		end
	end
end

function GameOrchestrator.HandleRankUp(player, oldRank, newRank)
	-- Calculate rank up reward
	local reward = math.floor((newRank - oldRank) * 100)
	
	if systems.CurrencyManager then
		systems.CurrencyManager.AddCurrency(player, reward, "RankUp")
	end
	
	-- Send congratulations
	GameOrchestrator.SendPlayerNotification(player, 
		"Rank Up! ELO: " .. newRank .. " (+" .. reward .. " coins)", "success")
	
	-- Check for tier promotions
	GameOrchestrator.CheckTierPromotion(player, newRank)
end

function GameOrchestrator.CheckTierPromotion(player, elo)
	local tiers = {
		{ name = "Bronze", min = 0, reward = 0 },
		{ name = "Silver", min = 1100, reward = 500 },
		{ name = "Gold", min = 1300, reward = 1000 },
		{ name = "Platinum", min = 1500, reward = 2000 },
		{ name = "Diamond", min = 1700, reward = 3000 },
		{ name = "Champion", min = 1900, reward = 5000 },
	}
	
	for i = #tiers, 1, -1 do
		local tier = tiers[i]
		if elo >= tier.min and tier.reward > 0 then
			-- Check if this is a new tier for the player
			local profile = systems.DataStore.Get(player)
			if profile and not profile.TierAchievements then
				profile.TierAchievements = {}
			end
			
			if profile and not profile.TierAchievements[tier.name] then
				profile.TierAchievements[tier.name] = true
				systems.DataStore.MarkDirty(player)
				
				-- Award tier reward
				if systems.CurrencyManager then
					systems.CurrencyManager.AddCurrency(player, tier.reward, "TierPromotion_" .. tier.name)
				end
				
				GameOrchestrator.SendPlayerNotification(player, 
					"🏆 " .. tier.name .. " Tier Achieved! +" .. tier.reward .. " coins", "success")
				
				-- Broadcast achievement
				GameOrchestrator.BroadcastTierAchievement(player, tier.name)
			end
			break
		end
	end
end

function GameOrchestrator.HandleReturningPlayer(player, profile)
	local message = "Welcome back, " .. player.Name .. "!"
	if profile.TotalMatches then
		message = message .. " Matches played: " .. profile.TotalMatches
	end
	
	GameOrchestrator.SendPlayerNotification(player, message, "info")
	
	-- Daily login bonus
	GameOrchestrator.CheckDailyLoginBonus(player, profile)
end

function GameOrchestrator.CheckDailyLoginBonus(player, profile)
	local today = os.date("%Y-%m-%d")
	
	if not profile.LastLogin or profile.LastLogin ~= today then
		profile.LastLogin = today
		profile.LoginStreak = (profile.LoginStreak or 0) + 1
		systems.DataStore.MarkDirty(player)
		
		local bonus = 100 + (profile.LoginStreak * 10)
		if systems.CurrencyManager then
			systems.CurrencyManager.AddCurrency(player, bonus, "DailyLogin")
		end
		
		GameOrchestrator.SendPlayerNotification(player, 
			"Daily Login Bonus! Day " .. profile.LoginStreak .. " (+" .. bonus .. " coins)", "success")
	end
end

function GameOrchestrator.StartOrchestrationLoops()
	-- Main orchestration loop
	spawn(function()
		while orchestratorState.initialized do
			wait(30) -- Run every 30 seconds
			GameOrchestrator.RunMainOrchestrationCycle()
		end
	end)
	
	-- Performance monitoring loop
	spawn(function()
		while orchestratorState.initialized do
			wait(60) -- Run every minute
			GameOrchestrator.MonitorServerPerformance()
		end
	end)
	
	-- Player analytics loop
	spawn(function()
		while orchestratorState.initialized do
			wait(300) -- Run every 5 minutes
			GameOrchestrator.UpdatePlayerAnalytics()
		end
	end)
end

function GameOrchestrator.RunMainOrchestrationCycle()
	-- Check system health
	if systems.SystemManager then
		local status = systems.SystemManager.GetSystemStatus()
		if status.performance.systemErrors > 10 then
			orchestratorState.serverHealth = "degraded"
		end
	end
	
	-- Balance server load
	GameOrchestrator.BalanceServerLoad()
	
	-- Update global statistics
	GameOrchestrator.UpdateGlobalStatistics()
end

function GameOrchestrator.MonitorServerPerformance()
	local stats = game:GetService("Stats")
	local memory = stats:GetTotalMemoryUsageMb()
	local playerCount = #Players:GetPlayers()
	
	-- Log performance metrics
	if systems.MetricsDashboard then
		systems.MetricsDashboard.UpdateServerMetrics({
			memory = memory,
			playerCount = playerCount,
			activeMatches = #orchestratorState.activeMatches,
			serverHealth = orchestratorState.serverHealth
		})
	end
	
	-- Alert if performance issues
	if memory > GameConfig.Performance.MaxServerMemoryMB then
		GameOrchestrator.HandleHighMemoryUsage(memory)
	end
end

function GameOrchestrator.BalanceServerLoad()
	local playerCount = #Players:GetPlayers()
	local maxPlayers = Players.MaxPlayers
	local loadPercentage = playerCount / maxPlayers
	
	if loadPercentage > 0.9 then
		-- High load - optimize systems
		if systems.NetworkManager then
			systems.NetworkManager.OptimizeForServerLoad()
		end
		
		-- Consider session migration for new players
		if loadPercentage >= 1.0 and systems.SessionMigration then
			-- Server is full, suggest migration for new joiners
		end
	end
end

function GameOrchestrator.SendPlayerNotification(player, message, type)
	local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
	local UIEvents = RemoteRoot:WaitForChild("UIEvents")
	
	local notificationRemote = UIEvents:FindFirstChild("PlayerNotification")
	if not notificationRemote then
		notificationRemote = Instance.new("RemoteEvent")
		notificationRemote.Name = "PlayerNotification"
		notificationRemote.Parent = UIEvents
	end
	
	notificationRemote:FireClient(player, {
		message = message,
		type = type or "info",
		timestamp = os.time()
	})
end

function GameOrchestrator.BroadcastKillStreak(player, streakName, count)
	local message = player.Name .. " is on a " .. streakName .. "! (" .. count .. " streak)"
	
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player then
			GameOrchestrator.SendPlayerNotification(otherPlayer, message, "info")
		end
	end
end

function GameOrchestrator.BroadcastTierAchievement(player, tierName)
	local message = "🏆 " .. player.Name .. " reached " .. tierName .. " tier!"
	
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player then
			GameOrchestrator.SendPlayerNotification(otherPlayer, message, "success")
		end
	end
end

function GameOrchestrator.SendWelcomeMessage(player)
	local messages = {
		"Welcome to the ultimate competitive FPS experience!",
		"🎯 Compete in ranked matches and climb the leaderboards",
		"💰 Earn coins to unlock new weapons and cosmetics",
		"🏆 Join or create a clan for epic clan battles",
		"Good luck, soldier!"
	}
	
	for i, message in ipairs(messages) do
		spawn(function()
			wait(i * 2) -- Stagger messages
			GameOrchestrator.SendPlayerNotification(player, message, "info")
		end)
	end
end

-- Error handling and recovery
function GameOrchestrator.HandleSystemError(systemName, error)
	Logging.Error("GameOrchestrator", "System error in " .. systemName .. ": " .. tostring(error))
	
	-- Attempt system recovery
	if systems.SystemManager then
		systems.SystemManager.AttemptSystemRecovery(systemName)
	end
end

function GameOrchestrator.GetOrchestrationStatus()
	return {
		initialized = orchestratorState.initialized,
		serverHealth = orchestratorState.serverHealth,
		activePlayers = #Players:GetPlayers(),
		activeMatches = #orchestratorState.activeMatches,
		systemsOnline = systems and #systems or 0
	}
end

return GameOrchestrator
