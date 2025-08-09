-- CrossServerMatchmaking.server.lua
-- Cross-server party matchmaking using MemoryStore

local Players = game:GetService("Players")
local MemoryStoreService = game:GetService("MemoryStoreService")
local TeleportService = game:GetService("TeleportService")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logging = require(ReplicatedStorage.Shared.Logging)

local CrossServerMatchmaking = {}

-- MemoryStore queues and data
local matchmakingQueue = MemoryStoreService:GetSortedMap("MatchmakingQueue")
local partyStore = MemoryStoreService:GetHashMap("Parties")
local serverStatusStore = MemoryStoreService:GetHashMap("ServerStatus")

-- Local state
local LOCAL_SERVER_ID = game.JobId
local currentParties = {}
local queuedPlayers = {}

-- Configuration
local QUEUE_TTL = 300 -- 5 minutes
local PARTY_TTL = 1800 -- 30 minutes
local MAX_PARTY_SIZE = 4
local TEAM_SIZE = 6

-- RemoteEvents
local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
local MatchmakingEvents = RemoteRoot:WaitForChild("MatchmakingEvents")

local PartyRemote = Instance.new("RemoteEvent")
PartyRemote.Name = "PartyRemote"
PartyRemote.Parent = MatchmakingEvents

local QueueRemote = Instance.new("RemoteEvent")
QueueRemote.Name = "QueueRemote"
QueueRemote.Parent = MatchmakingEvents

function CrossServerMatchmaking.CreateParty(leader)
	local partyId = game:GetService("HttpService"):GenerateGUID(false)
	local party = {
		id = partyId,
		leader = leader.UserId,
		members = { leader.UserId },
		server = LOCAL_SERVER_ID,
		created = os.time(),
		inQueue = false
	}
	
	-- Store locally and in MemoryStore
	currentParties[partyId] = party
	pcall(function()
		partyStore:SetAsync(partyId, party, PARTY_TTL)
	end)
	
	Logging.Event("PartyCreated", { partyId = partyId, leader = leader.UserId })
	return partyId
end

function CrossServerMatchmaking.JoinParty(player, partyId)
	local party = currentParties[partyId]
	if not party then
		-- Try to load from MemoryStore
		local success, result = pcall(function()
			return partyStore:GetAsync(partyId)
		end)
		if success and result then
			party = result
			currentParties[partyId] = party
		end
	end
	
	if not party then
		return false, "Party not found"
	end
	
	if #party.members >= MAX_PARTY_SIZE then
		return false, "Party is full"
	end
	
	if table.find(party.members, player.UserId) then
		return false, "Already in party"
	end
	
	if party.server ~= LOCAL_SERVER_ID then
		-- Teleport player to party's server
		local success = pcall(function()
			TeleportService:TeleportToPlaceInstance(game.PlaceId, party.server, player)
		end)
		return success, success and "Teleporting to party server" or "Failed to teleport"
	end
	
	-- Add to party
	table.insert(party.members, player.UserId)
	party.updated = os.time()
	
	-- Update stores
	currentParties[partyId] = party
	pcall(function()
		partyStore:SetAsync(partyId, party, PARTY_TTL)
	end)
	
	-- Notify all party members
	for _, memberId in ipairs(party.members) do
		local member = Players:GetPlayerByUserId(memberId)
		if member then
			PartyRemote:FireClient(member, "PartyUpdated", party)
		end
	end
	
	Logging.Event("PartyJoined", { partyId = partyId, player = player.UserId })
	return true, "Joined party"
end

function CrossServerMatchmaking.LeaveParty(player, partyId)
	local party = currentParties[partyId]
	if not party then return false, "Party not found" end
	
	local memberIndex = table.find(party.members, player.UserId)
	if not memberIndex then return false, "Not in party" end
	
	table.remove(party.members, memberIndex)
	
	-- If leader left, promote next member or disband
	if party.leader == player.UserId then
		if #party.members > 0 then
			party.leader = party.members[1]
		else
			-- Disband party
			currentParties[partyId] = nil
			pcall(function()
				partyStore:RemoveAsync(partyId)
			end)
			Logging.Event("PartyDisbanded", { partyId = partyId })
			return true, "Party disbanded"
		end
	end
	
	party.updated = os.time()
	
	-- Update stores
	currentParties[partyId] = party
	pcall(function()
		partyStore:SetAsync(partyId, party, PARTY_TTL)
	end)
	
	-- Notify remaining members
	for _, memberId in ipairs(party.members) do
		local member = Players:GetPlayerByUserId(memberId)
		if member then
			PartyRemote:FireClient(member, "PartyUpdated", party)
		end
	end
	
	Logging.Event("PartyLeft", { partyId = partyId, player = player.UserId })
	return true, "Left party"
end

function CrossServerMatchmaking.JoinQueue(player, partyId)
	local queueEntry = {
		player = player.UserId,
		party = partyId,
		server = LOCAL_SERVER_ID,
		elo = 1000, -- Would get from RankManager
		timestamp = os.time()
	}
	
	if partyId then
		local party = currentParties[partyId]
		if not party then return false, "Party not found" end
		if party.leader ~= player.UserId then return false, "Only party leader can queue" end
		
		party.inQueue = true
		queueEntry.partySize = #party.members
		queueEntry.partyMembers = party.members
	else
		queueEntry.partySize = 1
		queueEntry.partyMembers = { player.UserId }
	end
	
	-- Add to queue with score based on ELO and timestamp
	local score = queueEntry.elo * 1000 + (os.time() - queueEntry.timestamp)
	
	pcall(function()
		matchmakingQueue:SetAsync(player.UserId, queueEntry, QUEUE_TTL, score)
	end)
	
	queuedPlayers[player.UserId] = queueEntry
	
	Logging.Event("QueueJoined", { 
		player = player.UserId, 
		party = partyId, 
		partySize = queueEntry.partySize 
	})
	
	return true, "Joined queue"
end

function CrossServerMatchmaking.LeaveQueue(player)
	-- Remove from queue
	pcall(function()
		matchmakingQueue:RemoveAsync(player.UserId)
	end)
	
	queuedPlayers[player.UserId] = nil
	
	-- Update party queue status
	for _, party in pairs(currentParties) do
		if party.leader == player.UserId then
			party.inQueue = false
		end
	end
	
	Logging.Event("QueueLeft", { player = player.UserId })
	return true, "Left queue"
end

function CrossServerMatchmaking.ProcessQueue()
	local queueEntries = {}
	
	-- Read queue entries
	pcall(function()
		matchmakingQueue:ReadAsync(1, 50, function(key, value)
			table.insert(queueEntries, value)
		end)
	end)
	
	if #queueEntries < TEAM_SIZE * 2 then return end -- Need at least 2 teams
	
	-- Sort by ELO for balanced matches
	table.sort(queueEntries, function(a, b) return a.elo < b.elo end)
	
	-- Try to form matches
	local team1 = {}
	local team2 = {}
	local team1Size = 0
	local team2Size = 0
	
	for _, entry in ipairs(queueEntries) do
		if team1Size + entry.partySize <= TEAM_SIZE and team1Size <= team2Size then
			table.insert(team1, entry)
			team1Size = team1Size + entry.partySize
		elseif team2Size + entry.partySize <= TEAM_SIZE then
			table.insert(team2, entry)
			team2Size = team2Size + entry.partySize
		end
		
		-- If both teams are full, create match
		if team1Size >= TEAM_SIZE and team2Size >= TEAM_SIZE then
			CrossServerMatchmaking.CreateMatch(team1, team2)
			team1, team2 = {}, {}
			team1Size, team2Size = 0, 0
		end
	end
end

function CrossServerMatchmaking.CreateMatch(team1, team2)
	local matchId = game:GetService("HttpService"):GenerateGUID(false)
	
	-- Create new server for the match
	local reserveCode = TeleportService:ReserveServer(game.PlaceId)
	
	-- Collect all players
	local allPlayers = {}
	for _, entry in ipairs(team1) do
		for _, playerId in ipairs(entry.partyMembers) do
			table.insert(allPlayers, playerId)
		end
	end
	for _, entry in ipairs(team2) do
		for _, playerId in ipairs(entry.partyMembers) do
			table.insert(allPlayers, playerId)
		end
	end
	
	-- Teleport all players to match server
	local teleportData = {
		matchId = matchId,
		team1 = {},
		team2 = {},
		gameMode = "Competitive"
	}
	
	for _, entry in ipairs(team1) do
		for _, playerId in ipairs(entry.partyMembers) do
			table.insert(teleportData.team1, playerId)
		end
	end
	for _, entry in ipairs(team2) do
		for _, playerId in ipairs(entry.partyMembers) do
			table.insert(teleportData.team2, playerId)
		end
	end
	
	-- Teleport players
	local playersToTeleport = {}
	for _, playerId in ipairs(allPlayers) do
		local player = Players:GetPlayerByUserId(playerId)
		if player then
			table.insert(playersToTeleport, player)
		end
	end
	
	if #playersToTeleport > 0 then
		local success = pcall(function()
			TeleportService:TeleportToPrivateServer(
				game.PlaceId, 
				reserveCode, 
				playersToTeleport, 
				nil, 
				teleportData
			)
		end)
		
		if success then
			-- Remove players from queue
			for _, playerId in ipairs(allPlayers) do
				pcall(function()
					matchmakingQueue:RemoveAsync(playerId)
				end)
				queuedPlayers[playerId] = nil
			end
			
			Logging.Event("MatchCreated", {
				matchId = matchId,
				players = allPlayers,
				team1Size = #teleportData.team1,
				team2Size = #teleportData.team2
			})
		end
	end
end

-- Handle client requests
PartyRemote.OnServerEvent:Connect(function(player, action, data)
	if action == "CreateParty" then
		local partyId = CrossServerMatchmaking.CreateParty(player)
		PartyRemote:FireClient(player, "PartyCreated", { id = partyId })
	elseif action == "JoinParty" then
		local success, message = CrossServerMatchmaking.JoinParty(player, data.partyId)
		PartyRemote:FireClient(player, "PartyJoinResult", { success = success, message = message })
	elseif action == "LeaveParty" then
		local success, message = CrossServerMatchmaking.LeaveParty(player, data.partyId)
		PartyRemote:FireClient(player, "PartyLeaveResult", { success = success, message = message })
	end
end)

QueueRemote.OnServerEvent:Connect(function(player, action, data)
	if action == "JoinQueue" then
		local success, message = CrossServerMatchmaking.JoinQueue(player, data.partyId)
		QueueRemote:FireClient(player, "QueueResult", { success = success, message = message })
	elseif action == "LeaveQueue" then
		local success, message = CrossServerMatchmaking.LeaveQueue(player)
		QueueRemote:FireClient(player, "QueueResult", { success = success, message = message })
	end
end)

-- Process queue periodically
local function processQueueLoop()
	while true do
		wait(5) -- Process every 5 seconds
		CrossServerMatchmaking.ProcessQueue()
	end
end

spawn(processQueueLoop)

return CrossServerMatchmaking
