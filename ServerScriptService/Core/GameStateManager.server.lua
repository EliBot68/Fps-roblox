-- GameStateManager.server.lua
-- Enterprise game state coordination and flow management

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Logging = require(ReplicatedStorage.Shared.Logging)

local GameStateManager = {}

-- Game state enum
local GameState = {
	STARTUP = "startup",
	LOBBY = "lobby", 
	MATCHMAKING = "matchmaking",
	MATCH_WARMUP = "match_warmup",
	MATCH_ACTIVE = "match_active",
	MATCH_OVERTIME = "match_overtime",
	MATCH_ENDING = "match_ending",
	SHUTDOWN = "shutdown"
}

-- Current game state
local currentState = GameState.STARTUP
local stateStartTime = os.time()
local stateData = {}

-- State transition callbacks
local stateCallbacks = {
	enter = {},
	exit = {},
	update = {}
}

-- System references
local systems = {}

function GameStateManager.Initialize()
	-- Get system references
	systems = {
		Matchmaker = require(script.Parent.Matchmaker),
		Combat = require(script.Parent.Combat),
		MapManager = require(script.Parent.MapManager),
		SystemManager = require(script.Parent.SystemManager),
		NetworkManager = require(script.Parent.NetworkManager),
	}
	
	-- Set up state machine
	GameStateManager.SetupStateCallbacks()
	
	-- Start with lobby state
	GameStateManager.TransitionTo(GameState.LOBBY)
	
	-- Start state update loop
	spawn(function()
		while true do
			wait(1) -- Update every second
			GameStateManager.UpdateCurrentState()
		end
	end)
	
	Logging.Info("GameStateManager initialized - State machine active")
end

function GameStateManager.SetupStateCallbacks()
	-- LOBBY state
	stateCallbacks.enter[GameState.LOBBY] = function()
		Logging.Info("GameStateManager", "Entering LOBBY state")
		stateData.playersWaiting = {}
		stateData.activeMatches = {}
		
		-- Ensure village spawn is loaded
		if systems.MapManager then
			systems.MapManager.LoadVillageSpawn()
		end
	end
	
	stateCallbacks.update[GameState.LOBBY] = function()
		-- Monitor for matchmaking requests
		local playerCount = #Players:GetPlayers()
		if playerCount >= GameConfig.Match.MinPlayers then
			-- Auto-transition to matchmaking if enough players
			GameStateManager.TransitionTo(GameState.MATCHMAKING)
		end
	end
	
	-- MATCHMAKING state
	stateCallbacks.enter[GameState.MATCHMAKING] = function()
		Logging.Info("GameStateManager", "Entering MATCHMAKING state")
		stateData.matchmakingStartTime = os.time()
		stateData.queuedPlayers = {}
		
		-- Start matchmaking process
		if systems.Matchmaker then
			systems.Matchmaker.StartMatchmaking()
		end
	end
	
	stateCallbacks.update[GameState.MATCHMAKING] = function()
		local elapsed = os.time() - stateData.matchmakingStartTime
		
		-- Timeout check
		if elapsed > GameConfig.Server.MatchmakingTimeout then
			Logging.Warn("GameStateManager", "Matchmaking timeout - returning to lobby")
			GameStateManager.TransitionTo(GameState.LOBBY)
			return
		end
		
		-- Check if match was created
		if stateData.matchFound then
			GameStateManager.TransitionTo(GameState.MATCH_WARMUP)
		end
	end
	
	-- MATCH_WARMUP state
	stateCallbacks.enter[GameState.MATCH_WARMUP] = function()
		Logging.Info("GameStateManager", "Entering MATCH_WARMUP state")
		stateData.warmupStartTime = os.time()
		stateData.warmupDuration = GameConfig.Match.WarmupSeconds
		
		-- Load competitive map
		if systems.MapManager then
			systems.MapManager.LoadRandomCompetitiveMap()
		end
		
		-- Prepare combat systems
		if systems.Combat then
			systems.Combat.PrepareForMatch()
		end
	end
	
	stateCallbacks.update[GameState.MATCH_WARMUP] = function()
		local elapsed = os.time() - stateData.warmupStartTime
		
		if elapsed >= stateData.warmupDuration then
			GameStateManager.TransitionTo(GameState.MATCH_ACTIVE)
		end
	end
	
	-- MATCH_ACTIVE state
	stateCallbacks.enter[GameState.MATCH_ACTIVE] = function()
		Logging.Info("GameStateManager", "Entering MATCH_ACTIVE state")
		stateData.matchStartTime = os.time()
		stateData.matchDuration = GameConfig.Match.LengthSeconds
		stateData.scoreLimit = GameConfig.Match.ScoreToWin or 30
		
		-- Start combat systems
		if systems.Combat then
			systems.Combat.StartMatch()
		end
		
		-- Notify all systems match started
		GameStateManager.BroadcastStateChange("match_started")
	end
	
	stateCallbacks.update[GameState.MATCH_ACTIVE] = function()
		local elapsed = os.time() - stateData.matchStartTime
		
		-- Time limit check
		if elapsed >= stateData.matchDuration then
			-- Check if overtime is needed
			if GameStateManager.IsMatchTied() and GameConfig.Match.OvertimeSeconds > 0 then
				GameStateManager.TransitionTo(GameState.MATCH_OVERTIME)
			else
				GameStateManager.TransitionTo(GameState.MATCH_ENDING)
			end
			return
		end
		
		-- Score limit check
		if GameStateManager.HasWinConditionMet() then
			GameStateManager.TransitionTo(GameState.MATCH_ENDING)
		end
	end
	
	-- MATCH_OVERTIME state
	stateCallbacks.enter[GameState.MATCH_OVERTIME] = function()
		Logging.Info("GameStateManager", "Entering MATCH_OVERTIME state")
		stateData.overtimeStartTime = os.time()
		stateData.overtimeDuration = GameConfig.Match.OvertimeSeconds
		
		GameStateManager.BroadcastStateChange("overtime_started")
	end
	
	stateCallbacks.update[GameState.MATCH_OVERTIME] = function()
		local elapsed = os.time() - stateData.overtimeStartTime
		
		-- Overtime time limit or score change
		if elapsed >= stateData.overtimeDuration or GameStateManager.HasWinConditionMet() then
			GameStateManager.TransitionTo(GameState.MATCH_ENDING)
		end
	end
	
	-- MATCH_ENDING state
	stateCallbacks.enter[GameState.MATCH_ENDING] = function()
		Logging.Info("GameStateManager", "Entering MATCH_ENDING state")
		stateData.endingStartTime = os.time()
		stateData.endingDuration = GameConfig.Match.EndGameDelaySeconds
		
		-- End combat
		if systems.Combat then
			systems.Combat.EndMatch()
		end
		
		-- Process match results
		GameStateManager.ProcessMatchResults()
		
		GameStateManager.BroadcastStateChange("match_ended")
	end
	
	stateCallbacks.update[GameState.MATCH_ENDING] = function()
		local elapsed = os.time() - stateData.endingStartTime
		
		if elapsed >= stateData.endingDuration then
			-- Return to lobby
			GameStateManager.TransitionTo(GameState.LOBBY)
		end
	end
end

function GameStateManager.TransitionTo(newState)
	if newState == currentState then return end
	
	local oldState = currentState
	
	-- Exit current state
	if stateCallbacks.exit[currentState] then
		stateCallbacks.exit[currentState]()
	end
	
	-- Update state
	currentState = newState
	stateStartTime = os.time()
	
	-- Enter new state
	if stateCallbacks.enter[currentState] then
		stateCallbacks.enter[currentState]()
	end
	
	-- Log transition
	Logging.Event("StateTransition", {
		from = oldState,
		to = newState,
		timestamp = os.time()
	})
	
	-- Notify systems
	GameStateManager.BroadcastStateChange("state_transition", {
		from = oldState,
		to = newState
	})
end

function GameStateManager.UpdateCurrentState()
	if stateCallbacks.update[currentState] then
		stateCallbacks.update[currentState]()
	end
	
	-- Update state duration
	local duration = os.time() - stateStartTime
	stateData.currentDuration = duration
end

function GameStateManager.BroadcastStateChange(eventType, data)
	local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
	local UIEvents = RemoteRoot:WaitForChild("UIEvents")
	
	-- Find or create GameState remote
	local gameStateRemote = UIEvents:FindFirstChild("GameStateUpdate")
	if not gameStateRemote then
		gameStateRemote = Instance.new("RemoteEvent")
		gameStateRemote.Name = "GameStateUpdate"
		gameStateRemote.Parent = UIEvents
	end
	
	local payload = {
		eventType = eventType,
		currentState = currentState,
		stateData = stateData,
		timestamp = os.time(),
		data = data
	}
	
	-- Send to all players
	for _, player in ipairs(Players:GetPlayers()) do
		gameStateRemote:FireClient(player, payload)
	end
end

function GameStateManager.IsMatchTied()
	-- This would check if teams have equal scores
	-- Placeholder implementation
	return false
end

function GameStateManager.HasWinConditionMet()
	-- This would check if any team has reached win condition
	-- Placeholder implementation
	return false
end

function GameStateManager.ProcessMatchResults()
	-- Process end-of-match rewards, rankings, etc.
	local matchData = {
		duration = os.time() - stateData.matchStartTime,
		players = {},
		winner = nil,
		statistics = {}
	}
	
	-- Collect player data
	for _, player in ipairs(Players:GetPlayers()) do
		table.insert(matchData.players, {
			userId = player.UserId,
			username = player.Name,
			-- Additional stats would be collected here
		})
	end
	
	-- Save match results
	if systems.StatisticsAnalytics then
		systems.StatisticsAnalytics.RecordMatchResults(matchData)
	end
	
	Logging.Event("MatchCompleted", matchData)
end

function GameStateManager.GetCurrentState()
	return currentState
end

function GameStateManager.GetStateData()
	return stateData
end

function GameStateManager.GetStateDuration()
	return os.time() - stateStartTime
end

function GameStateManager.ForceTransition(newState, reason)
	Logging.Info("GameStateManager", "Forced transition to " .. newState .. " - Reason: " .. (reason or "Unknown"))
	GameStateManager.TransitionTo(newState)
end

function GameStateManager.IsInMatch()
	return currentState == GameState.MATCH_ACTIVE or 
	       currentState == GameState.MATCH_OVERTIME or
	       currentState == GameState.MATCH_WARMUP
end

function GameStateManager.IsMatchActive()
	return currentState == GameState.MATCH_ACTIVE or currentState == GameState.MATCH_OVERTIME
end

function GameStateManager.GetMatchTimeRemaining()
	if currentState == GameState.MATCH_ACTIVE then
		local elapsed = os.time() - stateData.matchStartTime
		return math.max(0, stateData.matchDuration - elapsed)
	elseif currentState == GameState.MATCH_OVERTIME then
		local elapsed = os.time() - stateData.overtimeStartTime
		return math.max(0, stateData.overtimeDuration - elapsed)
	end
	
	return 0
end

-- Event handlers for external systems
function GameStateManager.OnMatchFound(matchData)
	stateData.matchFound = true
	stateData.currentMatch = matchData
end

function GameStateManager.OnPlayerScored(player, score)
	if not GameStateManager.IsMatchActive() then return end
	
	-- Update score and check win conditions
	-- This would integrate with actual scoring system
	
	if GameStateManager.HasWinConditionMet() then
		GameStateManager.TransitionTo(GameState.MATCH_ENDING)
	end
end

function GameStateManager.OnPlayerEliminated(player)
	if not GameStateManager.IsMatchActive() then return end
	
	-- Check if match should end due to eliminations
	-- This would integrate with actual elimination tracking
end

-- Emergency state management
function GameStateManager.EmergencyReset(reason)
	Logging.Warn("GameStateManager", "Emergency reset triggered - Reason: " .. (reason or "Unknown"))
	
	-- Clear all state data
	stateData = {}
	
	-- Force return to lobby
	GameStateManager.ForceTransition(GameState.LOBBY, "emergency_reset")
	
	-- Notify admin systems
	if systems.SystemManager then
		systems.SystemManager.AlertAdmins("GameState emergency reset", { reason = reason })
	end
end

return GameStateManager
