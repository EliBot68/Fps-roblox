-- ShardedLeaderboards.server.lua
-- Sharded leaderboards and caching layer for high-performance ranking

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logging = require(ReplicatedStorage.Shared.Logging)

local ShardedLeaderboards = {}

-- Configuration
local CONFIG = {
	shardSize = 1000, -- Players per shard
	cacheExpiry = 300, -- 5 minutes
	updateInterval = 30, -- 30 seconds
	maxLeaderboardSize = 100,
	enableRealTimeUpdates = true
}

-- DataStores and MemoryStores
local leaderboardStore = DataStoreService:GetDataStore("ShardedLeaderboards")
local cacheStore = MemoryStoreService:GetSortedMap("LeaderboardCache")
local shardMetaStore = DataStoreService:GetDataStore("LeaderboardShards")

-- Cache management
local localCache = {}
local cacheTimestamps = {}
local updateQueue = {}

-- Shard management
local shardInfo = {
	totalShards = 0,
	playerShardMap = {},
	shardPlayerCounts = {}
}

-- Leaderboard types
local LEADERBOARD_TYPES = {
	kills = { metric = "totalKills", order = "desc" },
	deaths = { metric = "totalDeaths", order = "asc" },
	kdr = { metric = "kdr", order = "desc" },
	wins = { metric = "totalWins", order = "desc" },
	winrate = { metric = "winRate", order = "desc" },
	playtime = { metric = "totalPlaytime", order = "desc" },
	level = { metric = "level", order = "desc" },
	accuracy = { metric = "accuracy", order = "desc" },
	headshots = { metric = "totalHeadshots", order = "desc" },
	damage = { metric = "totalDamage", order = "desc" }
}

function ShardedLeaderboards.Initialize()
	-- Load shard metadata
	ShardedLeaderboards.LoadShardMetadata()
	
	-- Start cache management
	ShardedLeaderboards.StartCacheManager()
	
	-- Start periodic updates
	ShardedLeaderboards.StartPeriodicUpdates()
	
	-- Subscribe to cross-server updates
	ShardedLeaderboards.SubscribeToUpdates()
	
	Logging.Info("ShardedLeaderboards initialized with " .. shardInfo.totalShards .. " shards")
end

function ShardedLeaderboards.LoadShardMetadata()
	local success, metadata = pcall(function()
		return shardMetaStore:GetAsync("metadata")
	end)
	
	if success and metadata then
		shardInfo.totalShards = metadata.totalShards or 0
		shardInfo.playerShardMap = metadata.playerShardMap or {}
		shardInfo.shardPlayerCounts = metadata.shardPlayerCounts or {}
	else
		-- Initialize new shard system
		shardInfo.totalShards = 1
		shardInfo.shardPlayerCounts[1] = 0
		ShardedLeaderboards.SaveShardMetadata()
	end
end

function ShardedLeaderboards.SaveShardMetadata()
	pcall(function()
		shardMetaStore:SetAsync("metadata", {
			totalShards = shardInfo.totalShards,
			playerShardMap = shardInfo.playerShardMap,
			shardPlayerCounts = shardInfo.shardPlayerCounts,
			lastUpdated = os.time()
		})
	end)
end

function ShardedLeaderboards.GetPlayerShard(userId)
	if shardInfo.playerShardMap[userId] then
		return shardInfo.playerShardMap[userId]
	end
	
	-- Assign player to least populated shard
	local targetShard = ShardedLeaderboards.FindOptimalShard()
	shardInfo.playerShardMap[userId] = targetShard
	shardInfo.shardPlayerCounts[targetShard] = (shardInfo.shardPlayerCounts[targetShard] or 0) + 1
	
	-- Create new shard if current one is full
	if shardInfo.shardPlayerCounts[targetShard] >= CONFIG.shardSize then
		shardInfo.totalShards = shardInfo.totalShards + 1
		shardInfo.shardPlayerCounts[shardInfo.totalShards] = 0
	end
	
	ShardedLeaderboards.SaveShardMetadata()
	return targetShard
end

function ShardedLeaderboards.FindOptimalShard()
	local minPlayers = math.huge
	local optimalShard = 1
	
	for shardId, playerCount in pairs(shardInfo.shardPlayerCounts) do
		if playerCount < minPlayers and playerCount < CONFIG.shardSize then
			minPlayers = playerCount
			optimalShard = shardId
		end
	end
	
	return optimalShard
end

function ShardedLeaderboards.UpdatePlayerStats(userId, stats)
	local shard = ShardedLeaderboards.GetPlayerShard(userId)
	local shardKey = "shard_" .. shard
	
	-- Add to update queue for batch processing
	if not updateQueue[shardKey] then
		updateQueue[shardKey] = {}
	end
	
	updateQueue[shardKey][userId] = {
		stats = stats,
		timestamp = os.time()
	}
	
	-- Update local cache immediately
	ShardedLeaderboards.UpdateLocalCache(userId, stats)
	
	-- Trigger real-time update if enabled
	if CONFIG.enableRealTimeUpdates then
		ShardedLeaderboards.NotifyRealTimeUpdate(userId, stats)
	end
end

function ShardedLeaderboards.UpdateLocalCache(userId, stats)
	for leaderboardType, config in pairs(LEADERBOARD_TYPES) do
		local value = stats[config.metric]
		if value then
			local cacheKey = "local_" .. leaderboardType
			if not localCache[cacheKey] then
				localCache[cacheKey] = {}
			end
			
			localCache[cacheKey][userId] = {
				value = value,
				name = stats.name or "Unknown",
				timestamp = os.time()
			}
			
			cacheTimestamps[cacheKey] = os.time()
		end
	end
end

function ShardedLeaderboards.ProcessUpdateQueue()
	for shardKey, updates in pairs(updateQueue) do
		if next(updates) then
			ShardedLeaderboards.BatchUpdateShard(shardKey, updates)
			updateQueue[shardKey] = {}
		end
	end
end

function ShardedLeaderboards.BatchUpdateShard(shardKey, updates)
	-- Get current shard data
	local success, shardData = pcall(function()
		return leaderboardStore:GetAsync(shardKey) or {}
	end)
	
	if not success then
		Logging.Error("Failed to load shard data: " .. shardKey)
		return
	end
	
	-- Apply updates
	for userId, update in pairs(updates) do
		shardData[userId] = {
			stats = update.stats,
			lastUpdated = update.timestamp
		}
	end
	
	-- Save updated shard data
	pcall(function()
		leaderboardStore:SetAsync(shardKey, shardData)
	end)
	
	-- Update cache
	ShardedLeaderboards.UpdateShardCache(shardKey, shardData)
end

function ShardedLeaderboards.UpdateShardCache(shardKey, shardData)
	-- Update MemoryStore cache for each leaderboard type
	for leaderboardType, config in pairs(LEADERBOARD_TYPES) do
		local cacheKey = shardKey .. "_" .. leaderboardType
		local sortedData = {}
		
		-- Extract and sort data
		for userId, playerData in pairs(shardData) do
			local value = playerData.stats[config.metric]
			if value then
				table.insert(sortedData, {
					userId = userId,
					value = value,
					name = playerData.stats.name or "Unknown"
				})
			end
		end
		
		-- Sort based on leaderboard configuration
		if config.order == "desc" then
			table.sort(sortedData, function(a, b) return a.value > b.value end)
		else
			table.sort(sortedData, function(a, b) return a.value < b.value end)
		end
		
		-- Store in MemoryStore (top players only)
		local topPlayers = {}
		for i = 1, math.min(#sortedData, CONFIG.maxLeaderboardSize) do
			topPlayers[i] = sortedData[i]
		end
		
		pcall(function()
			cacheStore:SetAsync(cacheKey, topPlayers, CONFIG.cacheExpiry)
		end)
	end
end

function ShardedLeaderboards.GetLeaderboard(leaderboardType, startRank, endRank)
	startRank = startRank or 1
	endRank = endRank or 50
	
	if not LEADERBOARD_TYPES[leaderboardType] then
		return {}
	end
	
	-- Try local cache first
	local localData = ShardedLeaderboards.GetLocalCachedLeaderboard(leaderboardType, startRank, endRank)
	if localData and #localData > 0 then
		return localData
	end
	
	-- Aggregate from all shards
	local aggregatedData = {}
	
	for shardId = 1, shardInfo.totalShards do
		local shardData = ShardedLeaderboards.GetShardLeaderboard(shardId, leaderboardType)
		for _, entry in ipairs(shardData) do
			table.insert(aggregatedData, entry)
		end
	end
	
	-- Sort aggregated data
	local config = LEADERBOARD_TYPES[leaderboardType]
	if config.order == "desc" then
		table.sort(aggregatedData, function(a, b) return a.value > b.value end)
	else
		table.sort(aggregatedData, function(a, b) return a.value < b.value end)
	end
	
	-- Return requested range
	local result = {}
	for i = startRank, math.min(endRank, #aggregatedData) do
		if aggregatedData[i] then
			result[#result + 1] = {
				rank = i,
				userId = aggregatedData[i].userId,
				name = aggregatedData[i].name,
				value = aggregatedData[i].value
			}
		end
	end
	
	-- Cache the result
	ShardedLeaderboards.CacheAggregatedLeaderboard(leaderboardType, result)
	
	return result
end

function ShardedLeaderboards.GetLocalCachedLeaderboard(leaderboardType, startRank, endRank)
	local cacheKey = "aggregated_" .. leaderboardType
	local cached = localCache[cacheKey]
	
	if not cached or not cacheTimestamps[cacheKey] then
		return nil
	end
	
	-- Check if cache is still valid
	if os.time() - cacheTimestamps[cacheKey] > CONFIG.cacheExpiry then
		localCache[cacheKey] = nil
		cacheTimestamps[cacheKey] = nil
		return nil
	end
	
	-- Return requested range
	local result = {}
	for i = startRank, math.min(endRank, #cached) do
		if cached[i] then
			result[#result + 1] = cached[i]
		end
	end
	
	return result
end

function ShardedLeaderboards.GetShardLeaderboard(shardId, leaderboardType)
	local cacheKey = "shard_" .. shardId .. "_" .. leaderboardType
	
	-- Try MemoryStore cache first
	local success, cached = pcall(function()
		return cacheStore:GetAsync(cacheKey)
	end)
	
	if success and cached then
		return cached
	end
	
	-- Fallback to DataStore
	local shardKey = "shard_" .. shardId
	success, cached = pcall(function()
		return leaderboardStore:GetAsync(shardKey)
	end)
	
	if success and cached then
		-- Build leaderboard from raw data
		local config = LEADERBOARD_TYPES[leaderboardType]
		local data = {}
		
		for userId, playerData in pairs(cached) do
			local value = playerData.stats[config.metric]
			if value then
				table.insert(data, {
					userId = userId,
					value = value,
					name = playerData.stats.name or "Unknown"
				})
			end
		end
		
		-- Sort and cache
		if config.order == "desc" then
			table.sort(data, function(a, b) return a.value > b.value end)
		else
			table.sort(data, function(a, b) return a.value < b.value end)
		end
		
		-- Cache the result
		pcall(function()
			cacheStore:SetAsync(cacheKey, data, CONFIG.cacheExpiry)
		end)
		
		return data
	end
	
	return {}
end

function ShardedLeaderboards.CacheAggregatedLeaderboard(leaderboardType, data)
	local cacheKey = "aggregated_" .. leaderboardType
	localCache[cacheKey] = data
	cacheTimestamps[cacheKey] = os.time()
end

function ShardedLeaderboards.GetPlayerRank(userId, leaderboardType)
	if not LEADERBOARD_TYPES[leaderboardType] then
		return nil
	end
	
	-- Get full leaderboard (this could be optimized for large datasets)
	local leaderboard = ShardedLeaderboards.GetLeaderboard(leaderboardType, 1, 10000)
	
	for i, entry in ipairs(leaderboard) do
		if entry.userId == userId then
			return {
				rank = i,
				value = entry.value,
				totalPlayers = #leaderboard
			}
		end
	end
	
	return nil
end

function ShardedLeaderboards.GetPlayerStats(userId)
	local shard = ShardedLeaderboards.GetPlayerShard(userId)
	local shardKey = "shard_" .. shard
	
	local success, shardData = pcall(function()
		return leaderboardStore:GetAsync(shardKey)
	end)
	
	if success and shardData and shardData[userId] then
		return shardData[userId].stats
	end
	
	return nil
end

function ShardedLeaderboards.StartCacheManager()
	-- Clean expired cache entries periodically
	spawn(function()
		while true do
			wait(60) -- Check every minute
			
			local currentTime = os.time()
			for cacheKey, timestamp in pairs(cacheTimestamps) do
				if currentTime - timestamp > CONFIG.cacheExpiry then
					localCache[cacheKey] = nil
					cacheTimestamps[cacheKey] = nil
				end
			end
		end
	end)
end

function ShardedLeaderboards.StartPeriodicUpdates()
	-- Process update queue periodically
	spawn(function()
		while true do
			wait(CONFIG.updateInterval)
			ShardedLeaderboards.ProcessUpdateQueue()
		end
	end)
	
	-- Refresh leaderboard caches periodically
	spawn(function()
		while true do
			wait(CONFIG.cacheExpiry / 2) -- Refresh halfway through expiry
			ShardedLeaderboards.RefreshPopularLeaderboards()
		end
	end)
end

function ShardedLeaderboards.RefreshPopularLeaderboards()
	-- Refresh most commonly accessed leaderboards
	local popularTypes = { "kills", "kdr", "wins", "level" }
	
	for _, leaderboardType in ipairs(popularTypes) do
		-- This will refresh the cache
		ShardedLeaderboards.GetLeaderboard(leaderboardType, 1, CONFIG.maxLeaderboardSize)
	end
end

function ShardedLeaderboards.SubscribeToUpdates()
	-- Subscribe to cross-server leaderboard updates
	pcall(function()
		MessagingService:SubscribeAsync("LeaderboardUpdate", function(message)
			local data = message.Data
			if data and data.userId and data.stats then
				ShardedLeaderboards.UpdatePlayerStats(data.userId, data.stats)
			end
		end)
	end)
end

function ShardedLeaderboards.NotifyRealTimeUpdate(userId, stats)
	-- Notify other servers of the update
	pcall(function()
		MessagingService:PublishAsync("LeaderboardUpdate", {
			userId = userId,
			stats = stats,
			server = game.JobId,
			timestamp = os.time()
		})
	end)
end

function ShardedLeaderboards.GetLeaderboardTypes()
	local types = {}
	for leaderboardType, config in pairs(LEADERBOARD_TYPES) do
		table.insert(types, {
			name = leaderboardType,
			metric = config.metric,
			order = config.order
		})
	end
	return types
end

function ShardedLeaderboards.GetShardInfo()
	return {
		totalShards = shardInfo.totalShards,
		playersPerShard = shardInfo.shardPlayerCounts,
		shardSize = CONFIG.shardSize,
		cacheExpiry = CONFIG.cacheExpiry
	}
end

function ShardedLeaderboards.GetCacheStats()
	local stats = {
		localCacheEntries = 0,
		memoryCacheEntries = 0,
		cacheHitRate = 0, -- Would need to track this
		lastUpdateTime = 0
	}
	
	for _ in pairs(localCache) do
		stats.localCacheEntries = stats.localCacheEntries + 1
	end
	
	return stats
end

-- Initialize on server start
ShardedLeaderboards.Initialize()

return ShardedLeaderboards
