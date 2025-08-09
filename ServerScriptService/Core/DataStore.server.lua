-- DataStore.server.lua
-- Placeholder persistence layer (stub)

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local profileStore = DataStoreService:GetDataStore("PlayerProfile_v1")

local DataStoreModule = {}
local cache = {}

local DEFAULT_PROFILE = {
	TotalKills = 0,
	TotalMatches = 0,
	Elo = 1000,
	Currency = 0,
	OwnedCosmetics = {},
}

local function deepCopy(tbl)
	local t = {}
	for k,v in pairs(tbl) do
		if type(v) == "table" then t[k] = deepCopy(v) else t[k] = v end
	end
	return t
end

function DataStoreModule.Get(plr)
	return cache[plr.UserId]
end

function DataStoreModule.Increment(plr, key, amount)
	local profile = cache[plr.UserId]; if not profile then return end
	profile[key] = (profile[key] or 0) + amount
end

local function loadPlayer(plr)
	local key = "P_" .. plr.UserId
	local ok, data = pcall(function()
		return profileStore:GetAsync(key)
	end)
	if not ok or not data then
		data = deepCopy(DEFAULT_PROFILE)
	end
	cache[plr.UserId] = data
end

local function savePlayer(plr)
	local data = cache[plr.UserId]; if not data then return end
	local key = "P_" .. plr.UserId
	pcall(function()
		profileStore:UpdateAsync(key, function()
			return data
		end)
	end)
end

Players.PlayerAdded:Connect(loadPlayer)
Players.PlayerRemoving:Connect(function(plr)
	savePlayer(plr)
	cache[plr.UserId] = nil
end)

game:BindToClose(function()
	for _,plr in ipairs(Players:GetPlayers()) do
		pcall(savePlayer, plr)
	end
end)

return DataStoreModule
