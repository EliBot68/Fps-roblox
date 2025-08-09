-- RankedSeasons.server.lua
-- Manages ranked seasons with placement matches

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStore = require(script.Parent.DataStore)
local RankManager = require(script.Parent.RankManager)
local Logging = require(ReplicatedStorage.Shared.Logging)

local RankedSeasons = {}

local CURRENT_SEASON = 1
local PLACEMENT_MATCHES_REQUIRED = 10
local SEASON_DURATION_DAYS = 90

local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
local SeasonRemote = Instance.new("RemoteEvent")
SeasonRemote.Name = "SeasonRemote"
SeasonRemote.Parent = RemoteRoot

function RankedSeasons.GetSeasonData(player)
	local profile = DataStore.Get(player)
	if not profile then return nil end
	
	local seasonKey = "Season" .. CURRENT_SEASON
	if not profile[seasonKey] then
		profile[seasonKey] = {
			placementMatches = 0,
			seasonElo = 1000,
			highestRank = "Unranked",
			matchesPlayed = 0,
			wins = 0,
			losses = 0,
			isPlaced = false
		}
		DataStore.MarkDirty(player)
	end
	
	return profile[seasonKey]
end

function RankedSeasons.IsInPlacement(player)
	local seasonData = RankedSeasons.GetSeasonData(player)
	return seasonData and not seasonData.isPlaced
end

function RankedSeasons.CompleteMatch(player, won, eloChange)
	local seasonData = RankedSeasons.GetSeasonData(player)
	if not seasonData then return end
	
	seasonData.matchesPlayed = seasonData.matchesPlayed + 1
	
	if won then
		seasonData.wins = seasonData.wins + 1
	else
		seasonData.losses = seasonData.losses + 1
	end
	
	-- Handle placement matches
	if not seasonData.isPlaced then
		seasonData.placementMatches = seasonData.placementMatches + 1
		
		-- Apply larger ELO changes during placements
		local placementMultiplier = 2.0
		seasonData.seasonElo = seasonData.seasonElo + (eloChange * placementMultiplier)
		
		if seasonData.placementMatches >= PLACEMENT_MATCHES_REQUIRED then
			seasonData.isPlaced = true
			local tier = RankManager.GetTierFromElo(seasonData.seasonElo)
			seasonData.highestRank = tier
			
			Logging.Event("PlacementComplete", {
				u = player.UserId,
				season = CURRENT_SEASON,
				finalElo = seasonData.seasonElo,
				tier = tier,
				record = seasonData.wins .. "-" .. seasonData.losses
			})
			
			-- Notify player of placement result
			SeasonRemote:FireClient(player, "PlacementComplete", {
				tier = tier,
				elo = seasonData.seasonElo,
				record = { wins = seasonData.wins, losses = seasonData.losses }
			})
		end
	else
		-- Normal ranked match
		seasonData.seasonElo = seasonData.seasonElo + eloChange
		local currentTier = RankManager.GetTierFromElo(seasonData.seasonElo)
		
		-- Track highest rank achieved
		local tierOrder = { "Bronze", "Silver", "Gold", "Platinum", "Diamond", "Champion" }
		local currentIndex = table.find(tierOrder, currentTier) or 1
		local highestIndex = table.find(tierOrder, seasonData.highestRank) or 0
		
		if currentIndex > highestIndex then
			seasonData.highestRank = currentTier
			Logging.Event("NewHighRank", {
				u = player.UserId,
				season = CURRENT_SEASON,
				tier = currentTier,
				elo = seasonData.seasonElo
			})
		end
	end
	
	DataStore.MarkDirty(player)
	
	-- Send season update to client
	SeasonRemote:FireClient(player, "SeasonUpdate", RankedSeasons.GetPlayerSeasonInfo(player))
end

function RankedSeasons.GetPlayerSeasonInfo(player)
	local seasonData = RankedSeasons.GetSeasonData(player)
	if not seasonData then return nil end
	
	local currentTier = RankManager.GetTierFromElo(seasonData.seasonElo)
	
	return {
		season = CURRENT_SEASON,
		currentTier = currentTier,
		currentElo = seasonData.seasonElo,
		highestRank = seasonData.highestRank,
		isPlaced = seasonData.isPlaced,
		placementMatches = seasonData.placementMatches,
		placementRequired = PLACEMENT_MATCHES_REQUIRED,
		matchesPlayed = seasonData.matchesPlayed,
		wins = seasonData.wins,
		losses = seasonData.losses,
		winRate = seasonData.matchesPlayed > 0 and (seasonData.wins / seasonData.matchesPlayed * 100) or 0
	}
end

function RankedSeasons.StartNewSeason()
	CURRENT_SEASON = CURRENT_SEASON + 1
	
	-- Reset all player season data would happen via DataStore migration
	Logging.Event("SeasonStart", { season = CURRENT_SEASON })
	
	-- Broadcast season reset to all players
	for _, player in ipairs(Players:GetPlayers()) do
		SeasonRemote:FireClient(player, "NewSeason", CURRENT_SEASON)
	end
end

function RankedSeasons.GetLeaderboard(limit)
	limit = limit or 100
	local leaderboard = {}
	
	-- This would typically query a sorted DataStore in production
	for _, player in ipairs(Players:GetPlayers()) do
		local seasonData = RankedSeasons.GetSeasonData(player)
		if seasonData and seasonData.isPlaced then
			table.insert(leaderboard, {
				name = player.Name,
				userId = player.UserId,
				elo = seasonData.seasonElo,
				tier = RankManager.GetTierFromElo(seasonData.seasonElo),
				wins = seasonData.wins,
				losses = seasonData.losses
			})
		end
	end
	
	-- Sort by ELO descending
	table.sort(leaderboard, function(a, b) return a.elo > b.elo end)
	
	-- Limit results
	local result = {}
	for i = 1, math.min(#leaderboard, limit) do
		result[i] = leaderboard[i]
	end
	
	return result
end

-- Handle client requests
SeasonRemote.OnServerEvent:Connect(function(player, action, data)
	if action == "GetSeasonInfo" then
		local info = RankedSeasons.GetPlayerSeasonInfo(player)
		SeasonRemote:FireClient(player, "SeasonInfo", info)
	elseif action == "GetLeaderboard" then
		local leaderboard = RankedSeasons.GetLeaderboard(50)
		SeasonRemote:FireClient(player, "Leaderboard", leaderboard)
	end
end)

return RankedSeasons
