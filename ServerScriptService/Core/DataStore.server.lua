-- DataStore.server.lua
-- Persistence layer with retry + schema

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Utilities = require(game:GetService("ReplicatedStorage").Shared.Utilities)

local profileStore = DataStoreService:GetDataStore("PlayerProfile_v2")

local SCHEMA_VERSION = 2
local SAVE_RETRY = 3
local SAVE_DELAY = 6

local DataStoreModule = {}
local cache = {}
local dirty = {}

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
end

function DataStoreModule.Increment(plr, key, amount)
	local profile = cache[plr.UserId]; if not profile then return end
	profile[key] = (profile[key] or 0) + amount
	DataStoreModule.MarkDirty(plr)
end

local function savePlayer(plr)
	local data = cache[plr.UserId]; if not data then return end
	if not dirty[plr.UserId] then return end
	local key = "P_" .. plr.UserId
	local ok, err = Utilities.Retry(SAVE_RETRY, 2, function()
		return profileStore:UpdateAsync(key, function(old)
			return data
		end)
	end)
	if ok then
		dirty[plr.UserId] = nil
	else
		warn("[DataStore] Save failed for", plr.UserId, err)
	end
end

local function periodicSaves()
	while task.wait(SAVE_DELAY) do
		for _,plr in ipairs(Players:GetPlayers()) do
			pcall(savePlayer, plr)
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
	pcall(savePlayer, plr)
	cache[plr.UserId] = nil
	dirty[plr.UserId] = nil
end)

task.spawn(periodicSaves)

game:BindToClose(function()
	for _,plr in ipairs(Players:GetPlayers()) do
		pcall(savePlayer, plr)
	end
end)

return DataStoreModule
