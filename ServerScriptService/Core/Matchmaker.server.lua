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

local function broadcast(eventName, payload)
	-- Placeholder: use RemoteEvent later
	print("[Matchmaker] " .. eventName, payload and payload.state or "")
end

local function clearQueue()
	for i = #queue,1,-1 do table.remove(queue, i) end
end

local function assignTeams()
	teams.A = {}
	teams.B = {}
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
