-- ABTesting.server.lua
-- A/B testing framework using MemoryStore

local Players = game:GetService("Players")
local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Logging = require(ReplicatedStorage.Shared.Logging)

local ABTesting = {}

-- MemoryStore for experiment configurations
local experimentsStore = MemoryStoreService:GetSortedMap("Experiments")
local userVariantsStore = MemoryStoreService:GetHashMap("UserVariants")

-- Local cache for experiments
local activeExperiments = {}
local userAssignments = {}

-- RemoteEvent for client-side experiments
local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
local ABTestingRemote = Instance.new("RemoteEvent")
ABTestingRemote.Name = "ABTestingRemote"
ABTestingRemote.Parent = RemoteRoot

function ABTesting.CreateExperiment(experimentId, config)
	local experiment = {
		id = experimentId,
		name = config.name or experimentId,
		status = config.status or "draft", -- draft, active, paused, completed
		trafficPercentage = config.trafficPercentage or 100,
		variants = config.variants or {
			{ id = "control", weight = 50 },
			{ id = "treatment", weight = 50 }
		},
		startDate = config.startDate or os.time(),
		endDate = config.endDate,
		targetingRules = config.targetingRules or {},
		metrics = config.metrics or {},
		created = os.time(),
		updated = os.time()
	}
	
	-- Validate variants weights sum to 100
	local totalWeight = 0
	for _, variant in ipairs(experiment.variants) do
		totalWeight = totalWeight + variant.weight
	end
	
	if totalWeight ~= 100 then
		error("Variant weights must sum to 100")
	end
	
	-- Store in MemoryStore
	pcall(function()
		experimentsStore:SetAsync(experimentId, experiment, 86400 * 30) -- 30 days TTL
	end)
	
	-- Update local cache
	activeExperiments[experimentId] = experiment
	
	Logging.Event("ExperimentCreated", {
		experimentId = experimentId,
		variants = #experiment.variants,
		traffic = experiment.trafficPercentage
	})
	
	return experiment
end

function ABTesting.GetVariant(player, experimentId)
	if userAssignments[player.UserId] and userAssignments[player.UserId][experimentId] then
		return userAssignments[player.UserId][experimentId]
	end
	
	local experiment = activeExperiments[experimentId]
	if not experiment or experiment.status ~= "active" then
		return nil
	end
	
	-- Check if experiment has ended
	if experiment.endDate and os.time() > experiment.endDate then
		return nil
	end
	
	-- Check targeting rules
	if not ABTesting.MatchesTargeting(player, experiment.targetingRules) then
		return nil
	end
	
	-- Check traffic percentage
	local userHash = ABTesting.HashUser(player.UserId, experimentId)
	local trafficThreshold = experiment.trafficPercentage / 100
	
	if userHash > trafficThreshold then
		return nil -- User not in experiment traffic
	end
	
	-- Assign variant based on weighted distribution
	local variantHash = ABTesting.HashUser(player.UserId, experimentId .. "_variant")
	local cumulativeWeight = 0
	
	for _, variant in ipairs(experiment.variants) do
		cumulativeWeight = cumulativeWeight + variant.weight
		if variantHash * 100 <= cumulativeWeight then
			-- Cache assignment
			if not userAssignments[player.UserId] then
				userAssignments[player.UserId] = {}
			end
			userAssignments[player.UserId][experimentId] = variant.id
			
			-- Store in MemoryStore for persistence
			pcall(function()
				userVariantsStore:SetAsync(
					tostring(player.UserId), 
					userAssignments[player.UserId], 
					86400 * 7 -- 7 days TTL
				)
			end)
			
			Logging.Event("VariantAssigned", {
				u = player.UserId,
				experimentId = experimentId,
				variant = variant.id
			})
			
			return variant.id
		end
	end
	
	return nil
end

function ABTesting.HashUser(userId, salt)
	local combined = tostring(userId) .. salt
	local hash = 0
	
	for i = 1, #combined do
		hash = (hash * 31 + string.byte(combined, i)) % 2147483647
	end
	
	return hash / 2147483647 -- Normalize to 0-1
end

function ABTesting.MatchesTargeting(player, rules)
	if not rules or #rules == 0 then return true end
	
	for _, rule in ipairs(rules) do
		if rule.type == "country" then
			-- Would need to implement country detection
			-- For now, always match
		elseif rule.type == "platform" then
			-- Check platform (PC, Mobile, Console)
			-- For now, always match
		elseif rule.type == "newUser" then
			-- Check if user is new (account age < X days)
			local accountAge = (os.time() - player.AccountAge * 86400) / 86400
			if rule.value and accountAge > rule.value then
				return false
			end
		elseif rule.type == "premium" then
			if rule.value and player.MembershipType ~= Enum.MembershipType.Premium then
				return false
			end
		elseif rule.type == "rank" then
			-- Check player rank/ELO
			-- Would integrate with RankManager
		end
	end
	
	return true
end

function ABTesting.TrackEvent(player, experimentId, eventName, value)
	local variant = ABTesting.GetVariant(player, experimentId)
	if not variant then return end
	
	Logging.Event("ABTestEvent", {
		u = player.UserId,
		experimentId = experimentId,
		variant = variant,
		event = eventName,
		value = value or 1,
		timestamp = os.time()
	})
end

function ABTesting.GetExperimentResults(experimentId)
	local experiment = activeExperiments[experimentId]
	if not experiment then return nil end
	
	-- This would typically aggregate from logging data
	-- For now, return a basic structure
	return {
		experimentId = experimentId,
		status = experiment.status,
		participants = 0, -- Would count from logs
		variants = {},
		metrics = {},
		startDate = experiment.startDate,
		endDate = experiment.endDate
	}
end

function ABTesting.LoadExperiments()
	-- Load active experiments from MemoryStore on server start
	pcall(function()
		experimentsStore:ReadAsync(1, 100, function(key, value)
			if value and value.status == "active" then
				activeExperiments[key] = value
			end
		end)
	end)
end

function ABTesting.LoadUserAssignments(player)
	-- Load cached user assignments
	pcall(function()
		local assignments = userVariantsStore:GetAsync(tostring(player.UserId))
		if assignments then
			userAssignments[player.UserId] = assignments
		end
	end)
end

-- Handle player joining
local function onPlayerAdded(player)
	ABTesting.LoadUserAssignments(player)
	
	-- Send active experiments to client
	local clientExperiments = {}
	for id, experiment in pairs(activeExperiments) do
		local variant = ABTesting.GetVariant(player, id)
		if variant then
			clientExperiments[id] = {
				variant = variant,
				config = experiment.clientConfig or {}
			}
		end
	end
	
	if next(clientExperiments) then
		ABTestingRemote:FireClient(player, "ExperimentAssignments", clientExperiments)
	end
end

-- Handle client events
ABTestingRemote.OnServerEvent:Connect(function(player, action, data)
	if action == "TrackEvent" then
		if data.experimentId and data.eventName then
			ABTesting.TrackEvent(player, data.experimentId, data.eventName, data.value)
		end
	elseif action == "GetAssignments" then
		-- Resend current assignments
		onPlayerAdded(player)
	end
end)

-- Cleanup when player leaves
local function onPlayerRemoving(player)
	userAssignments[player.UserId] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Load experiments on startup
ABTesting.LoadExperiments()

-- Example experiment creation
ABTesting.CreateExperiment("weapon_balance_v1", {
	name = "Weapon Balance Test",
	status = "active",
	trafficPercentage = 50,
	variants = {
		{ id = "control", weight = 50 },
		{ id = "buffed_smg", weight = 50 }
	},
	startDate = os.time(),
	endDate = os.time() + (86400 * 14), -- 2 weeks
	targetingRules = {
		{ type = "newUser", value = 30 } -- New users only
	},
	clientConfig = {
		smgDamage = 25 -- Would be 20 in control
	}
})

return ABTesting
