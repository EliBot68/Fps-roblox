-- StatisticsAnalytics.server.lua
-- Advanced statistics and performance analytics

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Logging = require(ReplicatedStorage.Shared.Logging)

local StatisticsAnalytics = {}

-- DataStores for analytics
local playerStatsStore = DataStoreService:GetDataStore("PlayerStatistics")
local matchStatsStore = DataStoreService:GetDataStore("MatchStatistics")
local performanceStore = DataStoreService:GetDataStore("PerformanceMetrics")

-- Real-time analytics cache
local playerAnalytics = {}
local matchAnalytics = {}
local sessionStats = {
	startTime = os.time(),
	peakPlayerCount = 0,
	totalMatches = 0,
	totalKills = 0,
	averageMatchDuration = 0,
	weaponUsage = {},
	mapPerformance = {}
}

-- RemoteEvent for client statistics
local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
local StatsRemote = Instance.new("RemoteEvent")
StatsRemote.Name = "StatsRemote"
StatsRemote.Parent = RemoteRoot

function StatisticsAnalytics.InitializePlayer(player)
	local userId = player.UserId
	
	-- Load existing stats or create new profile
	local success, stats = pcall(function()
		return playerStatsStore:GetAsync(tostring(userId))
	end)
	
	if not success or not stats then
		stats = {
			userId = userId,
			username = player.Name,
			created = os.time(),
			lastSeen = os.time(),
			playtime = 0,
			sessions = 0,
			
			-- Combat statistics
			totalKills = 0,
			totalDeaths = 0,
			totalDamage = 0,
			totalShots = 0,
			totalHits = 0,
			headshots = 0,
			longestKillStreak = 0,
			currentKillStreak = 0,
			
			-- Match statistics
			matchesPlayed = 0,
			matchesWon = 0,
			totalMatchTime = 0,
			averageScore = 0,
			bestScore = 0,
			
			-- Weapon statistics
			weaponStats = {
				AssaultRifle = { kills = 0, shots = 0, hits = 0, damage = 0 },
				SMG = { kills = 0, shots = 0, hits = 0, damage = 0 },
				Shotgun = { kills = 0, shots = 0, hits = 0, damage = 0 },
				Sniper = { kills = 0, shots = 0, hits = 0, damage = 0 },
				Pistol = { kills = 0, shots = 0, hits = 0, damage = 0 }
			},
			
			-- Performance metrics
			averageAccuracy = 0,
			kdr = 0,
			winRate = 0,
			averageKillsPerMatch = 0,
			damagePerSecond = 0,
			
			-- Behavioral analytics
			preferredWeapons = {},
			peakPlayTime = "",
			sessionLengths = {},
			improvementTrend = 0
		}
	end
	
	-- Update session info
	stats.lastSeen = os.time()
	stats.sessions = stats.sessions + 1
	
	playerAnalytics[userId] = {
		stats = stats,
		sessionStart = os.time(),
		sessionKills = 0,
		sessionDeaths = 0,
		sessionDamage = 0,
		sessionShots = 0,
		sessionHits = 0,
		dirty = false
	}
	
	Logging.Event("PlayerStatsInitialized", { u = userId, sessions = stats.sessions })
end

function StatisticsAnalytics.UpdateCombatStats(player, eventType, data)
	local userId = player.UserId
	local analytics = playerAnalytics[userId]
	if not analytics then return end
	
	local stats = analytics.stats
	
	if eventType == "kill" then
		stats.totalKills = stats.totalKills + 1
		stats.currentKillStreak = stats.currentKillStreak + 1
		stats.longestKillStreak = math.max(stats.longestKillStreak, stats.currentKillStreak)
		
		analytics.sessionKills = analytics.sessionKills + 1
		
		-- Weapon-specific stats
		local weapon = data.weapon or "AssaultRifle"
		if stats.weaponStats[weapon] then
			stats.weaponStats[weapon].kills = stats.weaponStats[weapon].kills + 1
		end
		
		-- Update session weapon usage
		sessionStats.weaponUsage[weapon] = (sessionStats.weaponUsage[weapon] or 0) + 1
		sessionStats.totalKills = sessionStats.totalKills + 1
		
	elseif eventType == "death" then
		stats.totalDeaths = stats.totalDeaths + 1
		stats.currentKillStreak = 0
		analytics.sessionDeaths = analytics.sessionDeaths + 1
		
	elseif eventType == "damage" then
		local damage = data.damage or 0
		stats.totalDamage = stats.totalDamage + damage
		analytics.sessionDamage = analytics.sessionDamage + damage
		
		local weapon = data.weapon or "AssaultRifle"
		if stats.weaponStats[weapon] then
			stats.weaponStats[weapon].damage = stats.weaponStats[weapon].damage + damage
		end
		
	elseif eventType == "shot" then
		stats.totalShots = stats.totalShots + 1
		analytics.sessionShots = analytics.sessionShots + 1
		
		local weapon = data.weapon or "AssaultRifle"
		if stats.weaponStats[weapon] then
			stats.weaponStats[weapon].shots = stats.weaponStats[weapon].shots + 1
		end
		
	elseif eventType == "hit" then
		stats.totalHits = stats.totalHits + 1
		analytics.sessionHits = analytics.sessionHits + 1
		
		local weapon = data.weapon or "AssaultRifle"
		if stats.weaponStats[weapon] then
			stats.weaponStats[weapon].hits = stats.weaponStats[weapon].hits + 1
		end
		
		if data.headshot then
			stats.headshots = stats.headshots + 1
		end
	end
	
	analytics.dirty = true
	StatisticsAnalytics.CalculateMetrics(userId)
end

function StatisticsAnalytics.UpdateMatchStats(player, matchResult)
	local userId = player.UserId
	local analytics = playerAnalytics[userId]
	if not analytics then return end
	
	local stats = analytics.stats
	
	stats.matchesPlayed = stats.matchesPlayed + 1
	stats.totalMatchTime = stats.totalMatchTime + (matchResult.duration or 0)
	
	if matchResult.won then
		stats.matchesWon = stats.matchesWon + 1
	end
	
	local score = matchResult.score or 0
	stats.averageScore = ((stats.averageScore * (stats.matchesPlayed - 1)) + score) / stats.matchesPlayed
	stats.bestScore = math.max(stats.bestScore, score)
	
	-- Update session match count
	sessionStats.totalMatches = sessionStats.totalMatches + 1
	
	analytics.dirty = true
	StatisticsAnalytics.CalculateMetrics(userId)
end

function StatisticsAnalytics.CalculateMetrics(userId)
	local analytics = playerAnalytics[userId]
	if not analytics then return end
	
	local stats = analytics.stats
	
	-- Calculate derived metrics
	if stats.totalDeaths > 0 then
		stats.kdr = stats.totalKills / stats.totalDeaths
	else
		stats.kdr = stats.totalKills
	end
	
	if stats.totalShots > 0 then
		stats.averageAccuracy = (stats.totalHits / stats.totalShots) * 100
	end
	
	if stats.matchesPlayed > 0 then
		stats.winRate = (stats.matchesWon / stats.matchesPlayed) * 100
		stats.averageKillsPerMatch = stats.totalKills / stats.matchesPlayed
	end
	
	if stats.totalMatchTime > 0 then
		stats.damagePerSecond = stats.totalDamage / stats.totalMatchTime
	end
	
	-- Calculate improvement trend (simplified)
	local recentPerformance = analytics.sessionKills - analytics.sessionDeaths
	local overallPerformance = stats.totalKills - stats.totalDeaths
	if overallPerformance > 0 then
		stats.improvementTrend = (recentPerformance / math.max(1, analytics.sessionKills + analytics.sessionDeaths)) * 100
	end
	
	-- Update preferred weapons
	local weaponPreferences = {}
	for weapon, weaponStats in pairs(stats.weaponStats) do
		table.insert(weaponPreferences, {
			weapon = weapon,
			score = weaponStats.kills * 2 + weaponStats.damage * 0.01
		})
	end
	
	table.sort(weaponPreferences, function(a, b) return a.score > b.score end)
	
	stats.preferredWeapons = {}
	for i = 1, math.min(3, #weaponPreferences) do
		table.insert(stats.preferredWeapons, weaponPreferences[i].weapon)
	end
end

function StatisticsAnalytics.SavePlayerStats(userId)
	local analytics = playerAnalytics[userId]
	if not analytics or not analytics.dirty then return end
	
	local stats = analytics.stats
	
	-- Update playtime
	local sessionDuration = os.time() - analytics.sessionStart
	stats.playtime = stats.playtime + sessionDuration
	
	-- Save session length for analysis
	table.insert(stats.sessionLengths, sessionDuration)
	if #stats.sessionLengths > 50 then
		table.remove(stats.sessionLengths, 1)
	end
	
	-- Determine peak play time
	local hour = os.date("%H", os.time())
	stats.peakPlayTime = hour .. ":00"
	
	-- Save to DataStore
	pcall(function()
		playerStatsStore:SetAsync(tostring(userId), stats)
	end)
	
	analytics.dirty = false
	
	Logging.Event("PlayerStatsSaved", { 
		u = userId, 
		playtime = stats.playtime,
		kdr = stats.kdr,
		accuracy = stats.averageAccuracy
	})
end

function StatisticsAnalytics.GetPlayerStats(player)
	local userId = player.UserId
	local analytics = playerAnalytics[userId]
	
	if analytics then
		StatisticsAnalytics.CalculateMetrics(userId)
		return analytics.stats
	end
	
	-- Load from DataStore if not in cache
	local success, stats = pcall(function()
		return playerStatsStore:GetAsync(tostring(userId))
	end)
	
	return success and stats or nil
end

function StatisticsAnalytics.GetLeaderboards(category, limit)
	limit = limit or 10
	category = category or "kdr"
	
	local leaderboard = {}
	
	-- Collect stats from all online players
	for userId, analytics in pairs(playerAnalytics) do
		local stats = analytics.stats
		local value = 0
		
		if category == "kdr" then
			value = stats.kdr
		elseif category == "kills" then
			value = stats.totalKills
		elseif category == "accuracy" then
			value = stats.averageAccuracy
		elseif category == "wins" then
			value = stats.matchesWon
		elseif category == "playtime" then
			value = stats.playtime
		end
		
		table.insert(leaderboard, {
			userId = userId,
			username = stats.username,
			value = value,
			category = category
		})
	end
	
	-- Sort by value descending
	table.sort(leaderboard, function(a, b) return a.value > b.value end)
	
	-- Limit results
	local result = {}
	for i = 1, math.min(#leaderboard, limit) do
		result[i] = leaderboard[i]
	end
	
	return result
end

function StatisticsAnalytics.GetServerAnalytics()
	-- Update peak player count
	local currentPlayers = #Players:GetPlayers()
	sessionStats.peakPlayerCount = math.max(sessionStats.peakPlayerCount, currentPlayers)
	
	-- Calculate average match duration
	if sessionStats.totalMatches > 0 then
		local totalMatchTime = 0
		for _, analytics in pairs(playerAnalytics) do
			totalMatchTime = totalMatchTime + analytics.stats.totalMatchTime
		end
		sessionStats.averageMatchDuration = totalMatchTime / sessionStats.totalMatches
	end
	
	return {
		uptime = os.time() - sessionStats.startTime,
		currentPlayers = currentPlayers,
		peakPlayers = sessionStats.peakPlayerCount,
		totalMatches = sessionStats.totalMatches,
		totalKills = sessionStats.totalKills,
		averageMatchDuration = sessionStats.averageMatchDuration,
		weaponUsage = sessionStats.weaponUsage,
		playerCount = #Players:GetPlayers()
	}
end

function StatisticsAnalytics.GeneratePlayerReport(player)
	local stats = StatisticsAnalytics.GetPlayerStats(player)
	if not stats then return nil end
	
	local analytics = playerAnalytics[player.UserId]
	local sessionData = nil
	
	if analytics then
		sessionData = {
			duration = os.time() - analytics.sessionStart,
			kills = analytics.sessionKills,
			deaths = analytics.sessionDeaths,
			damage = analytics.sessionDamage,
			accuracy = analytics.sessionShots > 0 and (analytics.sessionHits / analytics.sessionShots * 100) or 0
		}
	end
	
	return {
		overall = stats,
		session = sessionData,
		rankings = {
			kdr = StatisticsAnalytics.GetPlayerRank(player, "kdr"),
			kills = StatisticsAnalytics.GetPlayerRank(player, "kills"),
			accuracy = StatisticsAnalytics.GetPlayerRank(player, "accuracy")
		}
	}
end

function StatisticsAnalytics.GetPlayerRank(player, category)
	local leaderboard = StatisticsAnalytics.GetLeaderboards(category, 1000)
	
	for rank, entry in ipairs(leaderboard) do
		if entry.userId == player.UserId then
			return rank
		end
	end
	
	return #leaderboard + 1
end

-- Handle client requests
StatsRemote.OnServerEvent:Connect(function(player, action, data)
	if action == "GetStats" then
		local report = StatisticsAnalytics.GeneratePlayerReport(player)
		StatsRemote:FireClient(player, "StatsReport", report)
	elseif action == "GetLeaderboard" then
		local category = data.category or "kdr"
		local limit = data.limit or 10
		local leaderboard = StatisticsAnalytics.GetLeaderboards(category, limit)
		StatsRemote:FireClient(player, "Leaderboard", { category = category, data = leaderboard })
	elseif action == "GetServerStats" then
		local serverStats = StatisticsAnalytics.GetServerAnalytics()
		StatsRemote:FireClient(player, "ServerStats", serverStats)
	end
end)

-- Player event handlers
Players.PlayerAdded:Connect(function(player)
	StatisticsAnalytics.InitializePlayer(player)
end)

Players.PlayerRemoving:Connect(function(player)
	StatisticsAnalytics.SavePlayerStats(player.UserId)
	playerAnalytics[player.UserId] = nil
end)

-- Periodic save
spawn(function()
	while true do
		wait(300) -- Save every 5 minutes
		for userId, analytics in pairs(playerAnalytics) do
			if analytics.dirty then
				StatisticsAnalytics.SavePlayerStats(userId)
			end
		end
	end
end)

return StatisticsAnalytics
