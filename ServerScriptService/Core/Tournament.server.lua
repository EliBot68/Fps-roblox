-- Tournament.server.lua
-- Tournament bracket system (single elimination expanded)

local Players = game:GetService("Players")
local Logging = require(game:GetService("ReplicatedStorage").Shared.Logging)
local RankManager = require(script.Parent.RankManager)

local Tournament = {}

-- State
local activeBracket = nil
local TOURNAMENT_SIZE_MIN = 4
local TOURNAMENT_SIZE_MAX = 32

-- Helper to deep copy
local function cloneArray(arr)
	local t = {}
	for i,v in ipairs(arr) do t[i] = v end
	return t
end

local function pairPlayers(players)
	local matches = {}
	for i = 1,#players,2 do
		local p1 = players[i]
		local p2 = players[i+1]
		if p1 and p2 then
			matches[#matches+1] = { P1 = p1, P2 = p2, Winner = nil }
		else
			-- bye advances automatically
			matches[#matches+1] = { P1 = p1, P2 = nil, Winner = p1 }
		end
	end
	return matches
end

local function buildInitialRounds(players)
	-- shuffle by ELO (simple: sort descending so high seeds apart then pair sequentially)
	table.sort(players, function(a,b)
		return RankManager.Get(a) > RankManager.Get(b)
	end)
	local firstRound = pairPlayers(players)
	return { firstRound }
end

local function computeNextRound(prevRound)
	local advancers = {}
	for _,match in ipairs(prevRound) do
		if match.Winner then
			advancers[#advancers+1] = match.Winner
		end
	end
	if #advancers <= 1 then return nil end
	return pairPlayers(advancers)
end

function Tournament.Create(players)
	if activeBracket then return false, "AlreadyRunning" end
	local list = {}
	for _,p in ipairs(players) do
		if p and p:IsDescendantOf(Players) then list[#list+1] = p end
	end
	if #list < TOURNAMENT_SIZE_MIN then return false, "TooFew" end
	if #list > TOURNAMENT_SIZE_MAX then return false, "TooMany" end
	local rounds = buildInitialRounds(list)
	activeBracket = {
		Rounds = rounds,
		State = "InProgress",
		CreatedAt = os.time(),
	}
	Logging.Event("TournamentCreated", { size = #list })
	return true
end

-- Report a result for a specific match in current round
function Tournament.ReportResult(playerWinner)
	if not activeBracket or activeBracket.State ~= "InProgress" then return false, "NoActive" end
	local rounds = activeBracket.Rounds
	local currentRound = rounds[#rounds]
	local allResolved = true
	local found = false
	for _,match in ipairs(currentRound) do
		if not match.Winner then allResolved = false end
		if (match.P1 == playerWinner or match.P2 == playerWinner) then
			if match.Winner and match.Winner ~= playerWinner then
				return false, "AlreadyDecided"
			end
			if match.P1 ~= playerWinner and match.P2 ~= playerWinner then
				return false, "NotInMatch"
			end
			match.Winner = playerWinner
			found = true
			Logging.Event("TournamentMatchResult", { w = playerWinner.UserId })
		end
	end
	if not found then return false, "NoMatchFound" end
	-- check if round complete
	local roundDone = true
	for _,m in ipairs(currentRound) do
		if not m.Winner then roundDone = false break end
	end
	if roundDone then
		local nextRound = computeNextRound(currentRound)
		if nextRound then
			activeBracket.Rounds[#activeBracket.Rounds+1] = nextRound
			Logging.Event("TournamentAdvanceRound", { round = #activeBracket.Rounds })
		else
			-- champion
			activeBracket.State = "Completed"
			activeBracket.Winner = currentRound[1].Winner
			Logging.Event("TournamentCompleted", { champion = activeBracket.Winner.UserId })
		end
	end
	return true
end

function Tournament.Get()
	return activeBracket
end

function Tournament.Reset()
	activeBracket = nil
end

return Tournament
