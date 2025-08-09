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
local queueTimers = {} -- Track queue wait times

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
end

function Matchmaker.JoinQueue(player, gameMode)
	gameMode = gameMode or "2v2" -- Default to 2v2
	
	if not GAME_MODES[gameMode] then
		return false, "Invalid game mode: " .. gameMode
	end
	
	-- Check if player is already in any queue
	for mode, queue in pairs(queues) do
		for i, queuedPlayer in ipairs(queue) do
			if queuedPlayer.player == player then
				return false, "Already in " .. mode .. " queue"
			end
		end
	end
	
	-- Check if player is in an active match
	for _, match in pairs(activeMatches) do
		for _, matchPlayer in ipairs(match.players) do
			if matchPlayer == player then
				return false, "Already in an active match"
			end
		end
	end
	
	local queue = queues[gameMode]
	local config = GAME_MODES[gameMode]
	
	if #queue >= config.maxPlayers then
		return false, "Queue full for " .. gameMode
	end
	
	-- Add player to queue with metadata
	table.insert(queue, {
		player = player,
		joinTime = tick(),
		rank = RankManager.Get(player) or 1000,
		gameMode = gameMode
	})
	
	print("[Matchmaker] Player joined " .. gameMode .. " queue:", player.Name, "Queue size:", #queue)
	
	-- Try to start match if enough players
	Matchmaker.CheckForMatch(gameMode)
	
	return true, "Joined " .. gameMode .. " queue"
end

function Matchmaker.LeaveQueue(player)
	local foundQueue = nil
	local foundIndex = nil
	
	-- Find player in queues
	for mode, queue in pairs(queues) do
		for i, queuedPlayer in ipairs(queue) do
			if queuedPlayer.player == player then
				foundQueue = mode
				foundIndex = i
				break
			end
		end
		if foundQueue then break end
	end
	
	if foundQueue and foundIndex then
		table.remove(queues[foundQueue], foundIndex)
		print("[Matchmaker] Player left " .. foundQueue .. " queue:", player.Name, "Queue size:", #queues[foundQueue])
		return true, "Left " .. foundQueue .. " queue"
	end
	
	return false, "Not in any queue"
end

function Matchmaker.CheckForMatch(gameMode)
	local queue = queues[gameMode]
	local config = GAME_MODES[gameMode]
	
	if #queue < config.minPlayers then
		return
	end
	
	-- Sort queue by rank for balanced matches
	table.sort(queue, function(a, b)
		return a.rank > b.rank
	end)
	
	-- Select players for match
	local matchPlayers = {}
	for i = 1, config.maxPlayers do
		if queue[i] then
			table.insert(matchPlayers, queue[i])
		end
	end
	
	if #matchPlayers >= config.minPlayers then
		Matchmaker.StartMatch(matchPlayers, gameMode)
		
		-- Remove players from queue
		for i = config.maxPlayers, 1, -1 do
			if queue[i] then
				table.remove(queue, i)
			end
		end
	end
end

function Matchmaker.StartMatch(queuedPlayers, gameMode)
	matchId = matchId + 1
	local players = {}
	
	-- Extract player objects
	for _, queuedPlayer in ipairs(queuedPlayers) do
		table.insert(players, queuedPlayer.player)
	end
	
	local config = GAME_MODES[gameMode]
	
	-- Get suitable map for this game mode
	local availableMaps = MapManager.GetAvailableMaps(gameMode)
	if #availableMaps == 0 then
		print("[Matchmaker] No maps available for " .. gameMode)
		return
	end
	
	local selectedMap = availableMaps[math.random(1, #availableMaps)]
	
	-- Load the map
	local mapLoaded, mapError = MapManager.LoadMap(selectedMap.name, gameMode)
	if not mapLoaded then
		print("[Matchmaker] Failed to load map:", mapError)
		return
	end
	
	-- Create match object
	local match = {
		id = matchId,
		gameMode = gameMode,
		players = players,
		map = selectedMap.name,
		startTime = tick(),
		endTime = nil,
		teams = { A = {}, B = {} },
		score = { A = 0, B = 0 },
		status = "starting"
	}
	
	-- Assign players to teams
	Matchmaker.AssignTeams(match, config)
	
	-- Spawn players
	Matchmaker.SpawnPlayers(match)
	
	-- Start match
	activeMatches[matchId] = match
	match.status = "active"
	
	-- Broadcast match start
	broadcast("MatchStarted", {
		id = matchId,
		gameMode = gameMode,
		map = selectedMap.name,
		matchLength = MATCH_LENGTH,
		teams = match.teams
	}, players)
	
	-- Set up match timer
	spawn(function()
		wait(MATCH_LENGTH)
		if activeMatches[matchId] and activeMatches[matchId].status == "active" then
			Matchmaker.EndMatch(matchId, "time")
		end
	end)
	
	print("[Matchmaker] Started " .. gameMode .. " match:", matchId, "Map:", selectedMap.name)
	
	-- Log metrics
	Metrics.LogMatch(matchId, gameMode, #players)
end

function Matchmaker.AssignTeams(match, config)
	local players = match.players
	local teams = match.teams
	
	-- Shuffle players for random team assignment
	for i = #players, 2, -1 do
		local j = math.random(i)
		players[i], players[j] = players[j], players[i]
	end
	
	-- Assign to teams alternating
	for i, player in ipairs(players) do
		if i <= config.playersPerTeam then
			table.insert(teams.A, player)
		else
			table.insert(teams.B, player)
		end
	end
end

function Matchmaker.SpawnPlayers(match)
	for teamName, teamPlayers in pairs(match.teams) do
		local teamNumber = teamName == "A" and 1 or 2
		
		for i, player in ipairs(teamPlayers) do
			local spawnData = MapManager.GetSpawnPoint(teamNumber, i, match.gameMode)
			
			if spawnData and player.Character then
				-- Teleport player to spawn point
				if player.Character.PrimaryPart then
					player.Character:SetPrimaryPartCFrame(spawnData.rotation)
				elseif player.Character:FindFirstChild("HumanoidRootPart") then
					player.Character.HumanoidRootPart.CFrame = spawnData.rotation
				end
			end
		end
	end
end

function Matchmaker.EndMatch(matchId, reason)
	local match = activeMatches[matchId]
	if not match then return end
	
	match.status = "ended"
	match.endTime = tick()
	match.duration = match.endTime - match.startTime
	
	-- Determine winner
	local winner = nil
	if match.score.A > match.score.B then
		winner = "A"
	elseif match.score.B > match.score.A then
		winner = "B"
	else
		winner = "draw"
	end
	
	-- Broadcast match end
	broadcast("MatchEnded", {
		id = matchId,
		winner = winner,
		score = match.score,
		reason = reason,
		duration = match.duration
	}, match.players)
	
	-- Process rewards and ranking
	Matchmaker.ProcessMatchResults(match, winner)
	
	-- Clean up match
	activeMatches[matchId] = nil
	
	print("[Matchmaker] Ended match:", matchId, "Winner:", winner, "Reason:", reason)
end

function Matchmaker.ProcessMatchResults(match, winner)
	for teamName, teamPlayers in pairs(match.teams) do
		local won = (winner == teamName)
		local drew = (winner == "draw")
		
		for _, player in ipairs(teamPlayers) do
			-- Update player statistics
			local stats = {
				matches = 1,
				wins = won and 1 or 0,
				losses = (not won and not drew) and 1 or 0,
				draws = drew and 1 or 0
			}
			
			-- Update rank
			if won then
				RankManager.Update(player, 25) -- Win points
			elseif drew then
				RankManager.Update(player, 5) -- Draw points  
			else
				RankManager.Update(player, -15) -- Loss points
			end
			
			-- Award currency
			local currencyReward = won and 100 or (drew and 50 or 25)
			CurrencyManager.Add(player, currencyReward)
			
			-- Update daily challenges
			DailyChallenges.UpdateProgress(player, "play_match", 1)
			if won then
				DailyChallenges.UpdateProgress(player, "win_match", 1)
			end
		end
	end
end

function Matchmaker.AddScore(player, points)
	-- Find which match and team the player is in
	for _, match in pairs(activeMatches) do
		for teamName, teamPlayers in pairs(match.teams) do
			if table.find(teamPlayers, player) then
				match.score[teamName] = match.score[teamName] + points
				
				-- Check for win condition
				if match.score[teamName] >= SCORE_TO_WIN then
					Matchmaker.EndMatch(match.id, "score")
				end
				
				return true
			end
		end
	end
	
	return false
end

function Matchmaker.GetQueueStatus(player)
	-- Return queue status for player
	for mode, queue in pairs(queues) do
		for i, queuedPlayer in ipairs(queue) do
			if queuedPlayer.player == player then
				return {
					inQueue = true,
					gameMode = mode,
					position = i,
					queueSize = #queue,
					waitTime = tick() - queuedPlayer.joinTime
				}
			end
		end
	end
	
	return { inQueue = false }
end

function Matchmaker.GetActiveMatchInfo(player)
	-- Return active match info for player
	for _, match in pairs(activeMatches) do
		if table.find(match.players, player) then
			return {
				inMatch = true,
				matchId = match.id,
				gameMode = match.gameMode,
				map = match.map,
				score = match.score,
				timeElapsed = tick() - match.startTime
			}
		end
	end
	
	return { inMatch = false }
end

-- Handle player disconnections
Players.PlayerRemoving:Connect(function(player)
	-- Remove from queue
	Matchmaker.LeaveQueue(player)
	
	-- Handle active match
	for matchId, match in pairs(activeMatches) do
		if table.find(match.players, player) then
			-- Remove player from teams
			for teamName, teamPlayers in pairs(match.teams) do
				local index = table.find(teamPlayers, player)
				if index then
					table.remove(teamPlayers, index)
					break
				end
			end
			
			-- End match if too few players remain
			local totalPlayers = #match.teams.A + #match.teams.B
			if totalPlayers < GAME_MODES[match.gameMode].minPlayers then
				Matchmaker.EndMatch(matchId, "player_left")
			end
			
			break
		end
	end
end)

return Matchmaker
