-- Matchmaker.server.lua
-- Handles player queueing and match lifecycle

local Players = game:GetService("Players")

local Matchmaker = {}

-- Config
local MIN_PLAYERS = 2
local MAX_PLAYERS = 8
local LOBBY_WAIT = 10 -- seconds before force start once min reached
local MATCH_LENGTH = 180 -- seconds

local queue = {}
local inMatch = false
local matchId = 0
local matchStartTime = 0

local function broadcast(eventName, payload)
	-- Placeholder: use RemoteEvent later
	print("[Matchmaker] " .. eventName, payload and payload.state or "")
end

local function clearQueue()
	for i = #queue,1,-1 do table.remove(queue, i) end
end

local function startMatch()
	inMatch = true
	matchId += 1
	matchStartTime = os.clock()
	broadcast("MatchStarted", { id = matchId, players = #queue })
	-- TODO: assign teams, teleport to arena, spawn logic
end

local function endMatch(reason)
	if not inMatch then return end
	inMatch = false
	broadcast("MatchEnded", { id = matchId, reason = reason })
	clearQueue()
end

local function tryStartCountdown()
	if inMatch then return end
	if #queue < MIN_PLAYERS then return end
	-- Simple immediate start for scaffold; add countdown later
	startMatch()
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

Players.PlayerRemoving:Connect(function(plr)
	Matchmaker.Leave(plr)
	if inMatch and #queue == 0 then
		endMatch("All players left")
	end
end)

-- Simple match timeout check
game:GetService("RunService").Heartbeat:Connect(function()
	if inMatch and (os.clock() - matchStartTime) >= MATCH_LENGTH then
		endMatch("TimeUp")
	end
end)

return Matchmaker
