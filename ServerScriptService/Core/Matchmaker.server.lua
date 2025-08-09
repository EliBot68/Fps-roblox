-- Matchmaker.server.lua
-- Handles player queueing and match lifecycle

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Matchmaker = {}

-- Config
local MIN_PLAYERS = 2
local MAX_PLAYERS = 8
local LOBBY_WAIT = 10 -- seconds before force start once min reached
local MATCH_LENGTH = 180 -- seconds
local COUNTDOWN = 5
local SCORE_TO_WIN = 25

local queue = {}
local inMatch = false
local matchId = 0
local matchStartTime = 0
local countdownActive = false

local teams = { A = {}, B = {} }
local score = { A = 0, B = 0 }

local Metrics = require(script.Parent.Metrics)
local DataStore = require(script.Parent.DataStore)
local RankManager = require(script.Parent.RankManager)
local CurrencyManager = require(script.Parent.Parent.Economy.CurrencyManager)
local DailyChallenges = require(script.Parent.Parent.Events.DailyChallenges)

local function broadcast(eventName, payload)
	local remoteRoot = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents")
	local matchmakingEvents = remoteRoot:WaitForChild("MatchmakingEvents")
	
	if eventName == "MatchStarted" then
		local matchStartRemote = matchmakingEvents:FindFirstChild("MatchStart")
		if matchStartRemote then
			for _,plr in ipairs(queue) do
				matchStartRemote:FireClient(plr, MATCH_LENGTH)
			end
		end
	elseif eventName == "MatchEnded" then
		local matchEndRemote = matchmakingEvents:FindFirstChild("MatchEnd")
		if matchEndRemote then
			for _,plr in ipairs(Players:GetPlayers()) do
				matchEndRemote:FireClient(plr)
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
