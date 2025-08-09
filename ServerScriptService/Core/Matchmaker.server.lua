-- Matchmaker.server.lua
-- Handles player queueing and match lifecycle for competitive team modes

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Matchmaker = {}

-- Competitive mode configurations
local GAME_MODES = {
	["1v1"] = { minPlayers = 2, maxPlayers = 2, teams = 2, playersPerTeam = 1 },
	["2v2"] = { minPlayers = 4, maxPlayers = 4, teams = 2, playersPerTeam = 2 },
	["3v3"] = { minPlayers = 6, maxPlayers = 6, teams = 2, playersPerTeam = 3 },
	["4v4"] = { minPlayers = 8, maxPlayers = 8, teams = 2, playersPerTeam = 4 }
}

-- Config  
local LOBBY_WAIT = 10 -- seconds before force start once min reached
local MATCH_LENGTH = 300 -- 5 minutes for competitive matches
local COUNTDOWN = 5
local SCORE_TO_WIN = 30 -- Higher score for competitive play

-- Queue system for different modes
local queues = {
	["1v1"] = {},
	["2v2"] = {},
	["3v3"] = {},
	["4v4"] = {}
}

local activeMatches = {} -- Support multiple concurrent matches
local matchId = 0
local queue = {} -- Fixed: undefined variable
local inMatch = false -- Fixed: undefined variable
local countdownActive = false -- Fixed: undefined variable
local matchStartTime = 0 -- Fixed: undefined variable
local MIN_PLAYERS = 2 -- Fixed: undefined variable
local MAX_PLAYERS = 8 -- Fixed: undefined variable

local teams = { A = {}, B = {} }
local score = { A = 0, B = 0 }

-- Import required modules
local Metrics = require(script.Parent.Metrics)
local DataStore = require(script.Parent.DataStore)
local RankManager = require(script.Parent.RankManager)
local CurrencyManager = require(script.Parent.Parent.Economy.CurrencyManager)
local DailyChallenges = require(script.Parent.Parent.Events.DailyChallenges)
local MapManager = require(script.Parent.MapManager)

local function broadcast(eventName, payload, targetPlayers)
	local remoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
	local matchmakingEvents = remoteRoot:WaitForChild("MatchmakingEvents")
	
	targetPlayers = targetPlayers or Players:GetPlayers()
	
	if eventName == "MatchStarted" then
		local matchStartRemote = matchmakingEvents:FindFirstChild("MatchStart")
		if matchStartRemote then
			for _, plr in ipairs(targetPlayers) do
				matchStartRemote:FireClient(plr, payload)
			end
		end
	elseif eventName == "MatchEnded" then
		local matchEndRemote = matchmakingEvents:FindFirstChild("MatchEnd")
		if matchEndRemote then
			for _, plr in ipairs(targetPlayers) do
				matchEndRemote:FireClient(plr, payload)
			end
		end
	end
	
	print("[Matchmaker] " .. eventName, payload and payload.state or "")
end

local function clearQueue()
	for i = #queue,1,-1 do table.remove(queue, i) end
end

local function averageElo(players)
	local sum = 0
	for _,p in ipairs(players) do sum += RankManager.Get(p) end
	return (#players>0) and (sum/#players) or 0
end

local function assignTeams()
	teams.A = {}
	teams.B = {}
	-- simple balancing: alternate after sorting by Elo descending
	table.sort(queue, function(a,b) return RankManager.Get(a) > RankManager.Get(b) end)
	for i,plr in ipairs(queue) do
		if i % 2 == 1 then table.insert(teams.A, plr) else table.insert(teams.B, plr) end
	end
end

local function startMatch()
	inMatch = true
	matchId += 1
	matchStartTime = os.clock()
	score.A, score.B = 0, 0
	assignTeams()
	broadcast("MatchStarted", { id = matchId, players = #queue })
	-- TODO: spawn players at team spawn points
end

local function endMatch(reason)
	if not inMatch then return end
	inMatch = false
	broadcast("MatchEnded", { id = matchId, reason = reason, score = score })
	Metrics.Inc("MatchEnded")
	-- ELO adjust placeholder: winners vs losers
	local winners
	if reason == "ScoreWin" then
		winners = score.A > score.B and teams.A or teams.B
	end
	local losers = {}
	if winners then
		local winnerAvg = 0
		for _,p in ipairs(winners) do winnerAvg += RankManager.Get(p) end
		winnerAvg /= math.max(1,#winners)
		for _,p in ipairs(winners) do
			RankManager.ApplyResult(p, winnerAvg, 1)
			local prof = DataStore.Get(p); if prof then prof.TotalMatches += 1; DataStore.MarkDirty(p) end
			CurrencyManager.AwardForWin(p)
			DailyChallenges.Inc(p, "wins_1", 1)
		end
		local other = winners == teams.A and teams.B or teams.A
		for _,p in ipairs(other) do
			RankManager.ApplyResult(p, winnerAvg, 0)
			local prof = DataStore.Get(p); if prof then prof.TotalMatches += 1; DataStore.MarkDirty(p) end
		end
	end
	clearQueue()
	teams.A, teams.B = {}, {}
end

local function beginCountdown()
	if countdownActive or inMatch then return end
	countdownActive = true
	local remaining = COUNTDOWN
	while remaining > 0 and #queue >= MIN_PLAYERS and not inMatch do
		broadcast("Countdown", { t = remaining })
		remaining -= 1
		task.wait(1)
	end
	countdownActive = false
	if #queue >= MIN_PLAYERS and not inMatch then
		startMatch()
	end
end

local function tryStartCountdown()
	if inMatch then return end
	if #queue < MIN_PLAYERS then return end
	beginCountdown()
end

function Matchmaker.Join(player)
	if inMatch then return false, "Match running" end
	for _,p in ipairs(queue) do if p == player then return false, "Already queued" end end
	if #queue >= MAX_PLAYERS then return false, "Queue full" end
	table.insert(queue, player)
	print("[Matchmaker] Player joined queue", player.Name, "queue size", #queue)
	tryStartCountdown()
	return true
end

function Matchmaker.Leave(player)
	for i,p in ipairs(queue) do
		if p == player then table.remove(queue, i) break end
	end
	print("[Matchmaker] Player left queue", player.Name, "queue size", #queue)
end

function Matchmaker.OnPlayerKill(killer, victim)
	if not inMatch then return end
	local function inTeam(t, plr)
		for _,x in ipairs(t) do if x == plr then return true end end
	end
	local teamKilled
	if inTeam(teams.A, victim) then teamKilled = "A" elseif inTeam(teams.B, victim) then teamKilled = "B" end
	if not teamKilled then return end
	local other = teamKilled == "A" and "B" or "A"
	score[other] += 1
	broadcast("ScoreUpdate", { A = score.A, B = score.B })
	if score[other] >= SCORE_TO_WIN then
		endMatch("ScoreWin")
	end
	CurrencyManager.AwardForKill(killer)
	DailyChallenges.Inc(killer, "elims_10", 1)
end

Players.PlayerRemoving:Connect(function(plr)
	Matchmaker.Leave(plr)
	if inMatch and #queue == 0 then
		endMatch("All players left")
	end
end)

-- Simple match timeout check
RunService.Heartbeat:Connect(function()
	if inMatch and (os.clock() - matchStartTime) >= MATCH_LENGTH then
		endMatch("TimeUp")
	end
end)

return Matchmaker
