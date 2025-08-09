-- DataStore.server.lua
-- Enterprise persistence layer with queue, retry, and exponential backoff

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Utilities = require(game:GetService("ReplicatedStorage").Shared.Utilities)
local RateLimiter = require(game:GetService("ReplicatedStorage").Shared.RateLimiter)

local profileStore = DataStoreService:GetDataStore("PlayerProfile_v3")

local SCHEMA_VERSION = 3
local SAVE_RETRY = 3
local SAVE_DELAY = 6
local MAX_QUEUE_SIZE = 100
local DEBOUNCE_TIME = 2 -- Minimum time between saves per player

local DataStoreModule = {}
local cache = {}
local dirty = {}
local saveQueue = {} -- {playerId, timestamp, retryCount}
local lastSaveTime = {} -- [playerId] = timestamp
local saveRateLimiter = RateLimiter.new(10, 1) -- 10 saves max, refill 1/sec

local DEFAULT_PROFILE = {
	Schema = SCHEMA_VERSION,
	TotalKills = 0,
	TotalMatches = 0,
	Elo = 1000,
	Currency = 0,
	OwnedCosmetics = {},
	OwnedWeapons = { AssaultRifle = true },
	EquippedCosmetic = nil,
	Daily = { Challenges = {}, ResetAt = 0 },
}

local function mergeSchema(data)
	if type(data) ~= 'table' then return Utilities.DeepCopy(DEFAULT_PROFILE) end
	if data.Schema ~= SCHEMA_VERSION then
		-- Simple upgrade strategy
		for k,v in pairs(DEFAULT_PROFILE) do
			if data[k] == nil then
				data[k] = Utilities.DeepCopy(v)
			end
		end
		data.Schema = SCHEMA_VERSION
	end
	return data
end

function DataStoreModule.Get(plr)
	return cache[plr.UserId]
end

function DataStoreModule.MarkDirty(plr)
	dirty[plr.UserId] = true
	-- Add to save queue with debouncing
	DataStoreModule.QueueSave(plr.UserId)
end

-- Queue a save with debouncing
function DataStoreModule.QueueSave(playerId)
	local currentTime = tick()
	local lastSave = lastSaveTime[playerId] or 0
	
	-- Debounce: only queue if enough time has passed
	if currentTime - lastSave < DEBOUNCE_TIME then
		return
	end
	
	-- Check if already in queue
	for i, queueItem in ipairs(saveQueue) do
		if queueItem.playerId == playerId then
			-- Update timestamp, don't add duplicate
			queueItem.timestamp = currentTime
			return
		end
	end
	
	-- Add to queue if not full
	if #saveQueue < MAX_QUEUE_SIZE then
		table.insert(saveQueue, {
			playerId = playerId,
			timestamp = currentTime,
			retryCount = 0
		})
	else
		warn("[DataStore] Save queue full, dropping save request for", playerId)
	end
end

function DataStoreModule.Increment(plr, key, amount)
	local profile = cache[plr.UserId]; if not profile then return end
	profile[key] = (profile[key] or 0) + amount
	DataStoreModule.MarkDirty(plr)
end

-- Enhanced save function with exponential backoff
local function savePlayerById(playerId)
	local player = Players:GetPlayerByUserId(playerId)
	if not player then
		-- Player left, still try to save cached data
		local data = cache[playerId]
		if not data or not dirty[playerId] then return true end
	else
		local data = cache[playerId]
		if not data or not dirty[playerId] then return true end
	end
	
	-- Rate limiting for DataStore API
	if not RateLimiter.consume(saveRateLimiter, 1) then
		warn("[DataStore] Rate limit exceeded for save operations")
		return false
	end
	
	local data = cache[playerId]
	local key = "P_" .. playerId
	
	local success, result = pcall(function()
		return profileStore:UpdateAsync(key, function(old)
			-- Validate data before saving
			if type(data) ~= "table" or not data.Schema then
				warn("[DataStore] Invalid data structure for", playerId)
				return nil -- Don't save corrupted data
			end
			return data
		end)
	end)
	
	if success then
		dirty[playerId] = nil
		lastSaveTime[playerId] = tick()
		print("[DataStore] ✓ Saved player", playerId)
		return true
	else
		warn("[DataStore] Save failed for", playerId, result)
		return false
	end
end

-- Process save queue with exponential backoff
local function processSaveQueue()
	if #saveQueue == 0 then return end
	
	local queueItem = table.remove(saveQueue, 1) -- FIFO
	local success = savePlayerById(queueItem.playerId)
	
	if not success then
		-- Exponential backoff retry
		queueItem.retryCount = queueItem.retryCount + 1
		local backoffDelay = math.min(30, 2 ^ queueItem.retryCount) -- Max 30 seconds
		
		if queueItem.retryCount < SAVE_RETRY then
			-- Re-queue with delay
			task.spawn(function()
				task.wait(backoffDelay)
				table.insert(saveQueue, queueItem)
			end)
			print("[DataStore] Retrying save for", queueItem.playerId, "in", backoffDelay, "seconds")
		else
			warn("[DataStore] Maximum retries exceeded for", queueItem.playerId)
		end
	end
end

-- Queue processor
local function startQueueProcessor()
	RunService.Heartbeat:Connect(function()
		-- Process one save per frame to avoid blocking
		if #saveQueue > 0 then
			processSaveQueue()
		end
	end)
end

local function periodicSaves()
	while task.wait(SAVE_DELAY) do
		for _,plr in ipairs(Players:GetPlayers()) do
			-- Add to queue instead of direct save
			if dirty[plr.UserId] then
				DataStoreModule.QueueSave(plr.UserId)
			end
		end
	end
end

local function loadPlayer(plr)
	local key = "P_" .. plr.UserId
	local ok, data = Utilities.Retry(SAVE_RETRY, 2, function()
		return profileStore:GetAsync(key)
	end)
	if not ok or not data then
		data = Utilities.DeepCopy(DEFAULT_PROFILE)
	end
	cache[plr.UserId] = mergeSchema(data)
	dirty[plr.UserId] = false
end

Players.PlayerAdded:Connect(loadPlayer)
Players.PlayerRemoving:Connect(function(plr)
	-- Force immediate save on player leaving
	savePlayerById(plr.UserId)
	cache[plr.UserId] = nil
	dirty[plr.UserId] = nil
	lastSaveTime[plr.UserId] = nil
end)

-- Start queue processor
startQueueProcessor()

-- Start periodic saves
task.spawn(periodicSaves)

game:BindToClose(function()
	-- Force save all players on server shutdown
	for _,plr in ipairs(Players:GetPlayers()) do
		savePlayerById(plr.UserId)
	end
	
	-- Process any remaining queue items
	while #saveQueue > 0 do
		processSaveQueue()
		task.wait(0.1)
	end
end)

return DataStoreModule
