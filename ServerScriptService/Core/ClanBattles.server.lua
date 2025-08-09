-- ClanBattles.server.lua
-- Clan vs clan battle system

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Clan = require(script.Parent.Clan)
local Logging = require(ReplicatedStorage.Shared.Logging)

local ClanBattles = {}

-- DataStore for battle history
local battleHistoryStore = DataStoreService:GetDataStore("ClanBattleHistory")

-- Active battles
local activeBattles = {}
local battleQueue = {}

-- Battle configuration
local BATTLE_DURATION = 600 -- 10 minutes
local MIN_CLAN_SIZE = 3
local MAX_CLAN_SIZE = 6
local BATTLE_MODES = {
	"Elimination", "Domination", "Capture", "Assault"
}

-- RemoteEvents
local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
local ClanBattleRemote = Instance.new("RemoteEvent")
ClanBattleRemote.Name = "ClanBattleRemote"
ClanBattleRemote.Parent = RemoteRoot

function ClanBattles.ChallengeClan(challengingClan, targetClan, battleMode, wager)
	battleMode = battleMode or "Elimination"
	wager = wager or 0
	
	-- Validate clans
	if not challengingClan or not targetClan then
		return false, "Invalid clan"
	end
	
	if challengingClan.id == targetClan.id then
		return false, "Cannot challenge your own clan"
	end
	
	-- Check clan sizes
	local challengingSize = #challengingClan.members
	local targetSize = #targetClan.members
	
	if challengingSize < MIN_CLAN_SIZE or targetSize < MIN_CLAN_SIZE then
		return false, "Both clans must have at least " .. MIN_CLAN_SIZE .. " members"
	end
	
	-- Check if clans are already in battle
	for _, battle in pairs(activeBattles) do
		if battle.clan1.id == challengingClan.id or battle.clan2.id == challengingClan.id or
		   battle.clan1.id == targetClan.id or battle.clan2.id == targetClan.id then
			return false, "One or both clans are already in battle"
		end
	end
	
	-- Create challenge
	local challenge = {
		id = game:GetService("HttpService"):GenerateGUID(false),
		challenger = challengingClan,
		target = targetClan,
		battleMode = battleMode,
		wager = wager,
		status = "pending",
		created = os.time(),
		expires = os.time() + 300 -- 5 minutes to accept
	}
	
	-- Add to queue
	battleQueue[challenge.id] = challenge
	
	-- Notify target clan members
	ClanBattles.NotifyClanMembers(targetClan, "challenge_received", challenge)
	
	Logging.Event("ClanChallengeCreated", {
		challengeId = challenge.id,
		challenger = challengingClan.name,
		target = targetClan.name,
		mode = battleMode,
		wager = wager
	})
	
	return true, "Challenge sent to " .. targetClan.name
end

function ClanBattles.AcceptChallenge(challengeId, acceptingPlayer)
	local challenge = battleQueue[challengeId]
	if not challenge then
		return false, "Challenge not found"
	end
	
	if challenge.status ~= "pending" then
		return false, "Challenge is no longer pending"
	end
	
	if os.time() > challenge.expires then
		battleQueue[challengeId] = nil
		return false, "Challenge has expired"
	end
	
	-- Check if player can accept for the clan
	local playerClan = Clan.GetPlayerClan(acceptingPlayer)
	if not playerClan or playerClan.id ~= challenge.target.id then
		return false, "You cannot accept this challenge"
	end
	
	local playerRole = Clan.GetPlayerRole(acceptingPlayer)
	if playerRole ~= "Leader" and playerRole ~= "Officer" then
		return false, "Only leaders and officers can accept challenges"
	end
	
	-- Create battle
	local battle = ClanBattles.CreateBattle(challenge)
	if battle then
		challenge.status = "accepted"
		battleQueue[challengeId] = nil
		return true, "Challenge accepted! Battle starting..."
	else
		return false, "Failed to create battle"
	end
end

function ClanBattles.DeclineChallenge(challengeId, decliningPlayer)
	local challenge = battleQueue[challengeId]
	if not challenge then
		return false, "Challenge not found"
	end
	
	-- Check if player can decline for the clan
	local playerClan = Clan.GetPlayerClan(decliningPlayer)
	if not playerClan or playerClan.id ~= challenge.target.id then
		return false, "You cannot decline this challenge"
	end
	
	local playerRole = Clan.GetPlayerRole(decliningPlayer)
	if playerRole ~= "Leader" and playerRole ~= "Officer" then
		return false, "Only leaders and officers can decline challenges"
	end
	
	challenge.status = "declined"
	battleQueue[challengeId] = nil
	
	-- Notify challenger
	ClanBattles.NotifyClanMembers(challenge.challenger, "challenge_declined", challenge)
	
	return true, "Challenge declined"
end

function ClanBattles.CreateBattle(challenge)
	local battleId = game:GetService("HttpService"):GenerateGUID(false)
	
	-- Reserve server for battle
	local success, reserveCode = pcall(function()
		return TeleportService:ReserveServer(game.PlaceId)
	end)
	
	if not success then
		return nil
	end
	
	local battle = {
		id = battleId,
		clan1 = challenge.challenger,
		clan2 = challenge.target,
		mode = challenge.battleMode,
		wager = challenge.wager,
		status = "starting",
		startTime = os.time(),
		endTime = os.time() + BATTLE_DURATION,
		reserveCode = reserveCode,
		scores = { clan1 = 0, clan2 = 0 },
		events = {},
		participants = {
			clan1 = {},
			clan2 = {}
		}
	}
	
	activeBattles[battleId] = battle
	
	-- Teleport clan members to battle server
	ClanBattles.TeleportClansToServer(battle)
	
	Logging.Event("ClanBattleStarted", {
		battleId = battleId,
		clan1 = battle.clan1.name,
		clan2 = battle.clan2.name,
		mode = battle.mode
	})
	
	return battle
end

function ClanBattles.TeleportClansToServer(battle)
	local teleportData = {
		battleId = battle.id,
		battleMode = battle.mode,
		clan1 = battle.clan1,
		clan2 = battle.clan2,
		wager = battle.wager
	}
	
	-- Get online members from both clans
	local clan1Players = ClanBattles.GetOnlineClanMembers(battle.clan1)
	local clan2Players = ClanBattles.GetOnlineClanMembers(battle.clan2)
	
	-- Limit to max battle size
	local maxPerClan = math.min(MAX_CLAN_SIZE, math.min(#clan1Players, #clan2Players))
	
	local playersToTeleport = {}
	
	-- Add clan1 players
	for i = 1, math.min(maxPerClan, #clan1Players) do
		table.insert(playersToTeleport, clan1Players[i])
		table.insert(battle.participants.clan1, clan1Players[i].UserId)
	end
	
	-- Add clan2 players
	for i = 1, math.min(maxPerClan, #clan2Players) do
		table.insert(playersToTeleport, clan2Players[i])
		table.insert(battle.participants.clan2, clan2Players[i].UserId)
	end
	
	-- Teleport to reserved server
	if #playersToTeleport > 0 then
		pcall(function()
			TeleportService:TeleportToPrivateServer(
				game.PlaceId,
				battle.reserveCode,
				playersToTeleport,
				nil,
				teleportData
			)
		end)
	end
end

function ClanBattles.GetOnlineClanMembers(clan)
	local onlineMembers = {}
	
	for _, memberId in ipairs(clan.members) do
		local player = Players:GetPlayerByUserId(memberId)
		if player then
			table.insert(onlineMembers, player)
		end
	end
	
	return onlineMembers
end

function ClanBattles.UpdateBattleScore(battleId, clanId, points, eventType)
	local battle = activeBattles[battleId]
	if not battle then return end
	
	-- Update scores
	if clanId == battle.clan1.id then
		battle.scores.clan1 = battle.scores.clan1 + points
	elseif clanId == battle.clan2.id then
		battle.scores.clan2 = battle.scores.clan2 + points
	end
	
	-- Log event
	table.insert(battle.events, {
		type = eventType,
		clanId = clanId,
		points = points,
		timestamp = os.time()
	})
	
	-- Check for battle end conditions
	ClanBattles.CheckBattleEndConditions(battleId)
end

function ClanBattles.CheckBattleEndConditions(battleId)
	local battle = activeBattles[battleId]
	if not battle then return end
	
	local shouldEnd = false
	local reason = ""
	
	-- Time limit reached
	if os.time() >= battle.endTime then
		shouldEnd = true
		reason = "time_limit"
	end
	
	-- Score limit reached (mode-specific)
	if battle.mode == "Elimination" then
		if battle.scores.clan1 >= 50 or battle.scores.clan2 >= 50 then
			shouldEnd = true
			reason = "score_limit"
		end
	elseif battle.mode == "Domination" then
		if battle.scores.clan1 >= 1000 or battle.scores.clan2 >= 1000 then
			shouldEnd = true
			reason = "score_limit"
		end
	end
	
	if shouldEnd then
		ClanBattles.EndBattle(battleId, reason)
	end
end

function ClanBattles.EndBattle(battleId, reason)
	local battle = activeBattles[battleId]
	if not battle then return end
	
	battle.status = "completed"
	battle.endReason = reason
	battle.actualEndTime = os.time()
	
	-- Determine winner
	local winner, loser
	if battle.scores.clan1 > battle.scores.clan2 then
		winner = battle.clan1
		loser = battle.clan2
	elseif battle.scores.clan2 > battle.scores.clan1 then
		winner = battle.clan2
		loser = battle.clan1
	else
		-- Tie
		winner = nil
		loser = nil
	end
	
	battle.winner = winner
	battle.loser = loser
	
	-- Award wager and experience
	if winner and battle.wager > 0 then
		-- Transfer wager from loser to winner clan treasury
		-- This would integrate with a clan treasury system
	end
	
	-- Award clan experience
	ClanBattles.AwardClanExperience(battle)
	
	-- Save battle history
	ClanBattles.SaveBattleHistory(battle)
	
	-- Notify all participants
	ClanBattles.NotifyBattleEnd(battle)
	
	-- Remove from active battles
	activeBattles[battleId] = nil
	
	Logging.Event("ClanBattleEnded", {
		battleId = battleId,
		winner = winner and winner.name or "tie",
		clan1Score = battle.scores.clan1,
		clan2Score = battle.scores.clan2,
		duration = battle.actualEndTime - battle.startTime
	})
end

function ClanBattles.AwardClanExperience(battle)
	local winnerExp = 100
	local loserExp = 25
	
	if battle.winner then
		-- Award experience to winner
		-- This would integrate with clan leveling system
	end
	
	-- Award participation experience to both clans
	-- Implementation would depend on clan system structure
end

function ClanBattles.SaveBattleHistory(battle)
	pcall(function()
		battleHistoryStore:SetAsync(battle.id, {
			id = battle.id,
			clan1 = { id = battle.clan1.id, name = battle.clan1.name },
			clan2 = { id = battle.clan2.id, name = battle.clan2.name },
			mode = battle.mode,
			wager = battle.wager,
			winner = battle.winner and battle.winner.id or nil,
			scores = battle.scores,
			startTime = battle.startTime,
			endTime = battle.actualEndTime,
			duration = battle.actualEndTime - battle.startTime,
			participants = battle.participants,
			events = battle.events
		})
	end)
end

function ClanBattles.NotifyBattleEnd(battle)
	-- Notify all participants about battle result
	local allParticipants = {}
	
	for _, userId in ipairs(battle.participants.clan1) do
		table.insert(allParticipants, userId)
	end
	for _, userId in ipairs(battle.participants.clan2) do
		table.insert(allParticipants, userId)
	end
	
	for _, userId in ipairs(allParticipants) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			ClanBattleRemote:FireClient(player, "BattleEnded", {
				battle = battle,
				isWinner = battle.winner and 
					(table.find(battle.participants.clan1, userId) and battle.winner.id == battle.clan1.id) or
					(table.find(battle.participants.clan2, userId) and battle.winner.id == battle.clan2.id)
			})
		end
	end
end

function ClanBattles.NotifyClanMembers(clan, eventType, data)
	for _, memberId in ipairs(clan.members) do
		local player = Players:GetPlayerByUserId(memberId)
		if player then
			ClanBattleRemote:FireClient(player, eventType, data)
		end
	end
end

function ClanBattles.GetBattleHistory(clanId, limit)
	limit = limit or 10
	-- This would typically query with filters in production
	-- For now, return empty array as placeholder
	return {}
end

function ClanBattles.GetActiveBattles()
	local battles = {}
	for _, battle in pairs(activeBattles) do
		table.insert(battles, {
			id = battle.id,
			clan1 = battle.clan1.name,
			clan2 = battle.clan2.name,
			mode = battle.mode,
			scores = battle.scores,
			timeRemaining = battle.endTime - os.time()
		})
	end
	return battles
end

-- Handle client requests
ClanBattleRemote.OnServerEvent:Connect(function(player, action, data)
	if action == "ChallengeClan" then
		local playerClan = Clan.GetPlayerClan(player)
		if not playerClan then
			ClanBattleRemote:FireClient(player, "Error", "You must be in a clan to challenge")
			return
		end
		
		local targetClan = Clan.GetClanById(data.targetClanId)
		local success, message = ClanBattles.ChallengeClan(
			playerClan, 
			targetClan, 
			data.battleMode, 
			data.wager
		)
		
		ClanBattleRemote:FireClient(player, "ChallengeResult", { success = success, message = message })
		
	elseif action == "AcceptChallenge" then
		local success, message = ClanBattles.AcceptChallenge(data.challengeId, player)
		ClanBattleRemote:FireClient(player, "ChallengeResponse", { success = success, message = message })
		
	elseif action == "DeclineChallenge" then
		local success, message = ClanBattles.DeclineChallenge(data.challengeId, player)
		ClanBattleRemote:FireClient(player, "ChallengeResponse", { success = success, message = message })
		
	elseif action == "GetActiveBattles" then
		local battles = ClanBattles.GetActiveBattles()
		ClanBattleRemote:FireClient(player, "ActiveBattles", battles)
		
	elseif action == "GetBattleHistory" then
		local playerClan = Clan.GetPlayerClan(player)
		if playerClan then
			local history = ClanBattles.GetBattleHistory(playerClan.id, data.limit)
			ClanBattleRemote:FireClient(player, "BattleHistory", history)
		end
	end
end)

-- Clean up expired challenges
spawn(function()
	while true do
		wait(60) -- Check every minute
		local now = os.time()
		local toRemove = {}
		
		for challengeId, challenge in pairs(battleQueue) do
			if now > challenge.expires then
				table.insert(toRemove, challengeId)
			end
		end
		
		for _, challengeId in ipairs(toRemove) do
			battleQueue[challengeId] = nil
		end
	end
end)

return ClanBattles
