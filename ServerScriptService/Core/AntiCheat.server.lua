-- AntiCheat.server.lua
-- Enhanced anti-cheat heuristics with progressive punishment and anomaly detection

local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logging = require(ReplicatedStorage.Shared.Logging)
local Metrics = require(script.Parent.Metrics)

local AntiCheat = {}

local lastPositions = {}
local MAX_SPEED = 90
local MAX_TELEPORT_DIST = 120

local shotHistory = {} -- shotHistory[player] = { times = {}, hits = 0, headshots = 0 }
local FIRE_WINDOW = 5
local MAX_RPS_SOFT = 12
local MAX_RPS_HARD = 18

-- Enhanced anomaly detection with rolling z-scores
local anomalyScore = {}
local behaviorStats = {} -- Rolling statistics for anomaly detection
local STATS_WINDOW = 300 -- 5 minutes of behavioral data
local Z_SCORE_THRESHOLD = 2.5 -- Standard deviations for anomaly detection

-- Behavior tracking metrics
local function updateBehaviorStats(player, metric, value)
	if not behaviorStats[player] then
		behaviorStats[player] = {}
	end
	
	if not behaviorStats[player][metric] then
		behaviorStats[player][metric] = {
			values = {},
			sum = 0,
			sumSquares = 0,
			count = 0,
			mean = 0,
			stdDev = 0
		}
	end
	
	local stat = behaviorStats[player][metric]
	
	-- Add new value
	table.insert(stat.values, {value = value, timestamp = tick()})
	stat.sum = stat.sum + value
	stat.sumSquares = stat.sumSquares + (value * value)
	stat.count = stat.count + 1
	
	-- Remove old values (older than STATS_WINDOW seconds)
	local currentTime = tick()
	for i = #stat.values, 1, -1 do
		if currentTime - stat.values[i].timestamp > STATS_WINDOW then
			local oldValue = stat.values[i].value
			stat.sum = stat.sum - oldValue
			stat.sumSquares = stat.sumSquares - (oldValue * oldValue)
			stat.count = stat.count - 1
			table.remove(stat.values, i)
		end
	end
	
	-- Calculate rolling mean and standard deviation
	if stat.count > 1 then
		stat.mean = stat.sum / stat.count
		local variance = (stat.sumSquares / stat.count) - (stat.mean * stat.mean)
		stat.stdDev = math.sqrt(math.max(0, variance))
	end
end

-- Calculate z-score for anomaly detection
local function calculateZScore(player, metric, value)
	local stat = behaviorStats[player] and behaviorStats[player][metric]
	if not stat or stat.count < 10 or stat.stdDev == 0 then
		return 0 -- Not enough data or no variance
	end
	
	return math.abs(value - stat.mean) / stat.stdDev
end

-- Enhanced bump function with behavioral analysis
local function bump(player, key, weight, value)
	anomalyScore[player] = anomalyScore[player] or { total = 0 }
	anomalyScore[player].total += weight
	anomalyScore[player][key] = (anomalyScore[player][key] or 0) + 1
	
	-- Update behavioral statistics if value provided
	if value then
		updateBehaviorStats(player, key, value)
		local zScore = calculateZScore(player, key, value)
		
		-- Additional penalty for high z-score anomalies
		if zScore > Z_SCORE_THRESHOLD then
			local anomalyWeight = math.min(20, zScore * 3) -- Cap at 20 points
			anomalyScore[player].total += anomalyWeight
			
			Logging.Event("BehaviorAnomaly", {
				userId = player.UserId,
				metric = key,
				value = value,
				zScore = zScore,
				mean = behaviorStats[player][key].mean,
				stdDev = behaviorStats[player][key].stdDev
			})
		end
	end
	
	local totalScore = anomalyScore[player].total
	
	-- Progressive punishment system
	if totalScore > 150 then
		-- Immediate ban for severe violations
		player:Kick("Detected cheating - Banned")
		-- Log to DataStore for permanent ban tracking
		pcall(function()
			DataStoreService:GetDataStore("BannedPlayers"):SetAsync(
				tostring(player.UserId), 
				{banned = true, reason = "Anti-cheat detection", timestamp = os.time()}
			)
		end)
	elseif totalScore > 100 then
		-- Temporary kick for high suspicion
		player:Kick("Suspected cheating detected - Please reconnect")
	elseif totalScore > 75 then
		-- Warning to player
		local warningCount = (anomalyScore[player].warnings or 0) + 1
		anomalyScore[player].warnings = warningCount
		
		if warningCount >= 3 then
			player:Kick("Multiple warnings - Temporary suspension")
		else
			-- Send warning to player via RemoteEvent
			local UIEvents = ReplicatedStorage.RemoteEvents.UIEvents
			local warningRemote = UIEvents:FindFirstChild("AntiCheatWarning")
			if warningRemote then
				warningRemote:FireClient(player, "Warning: Suspicious activity detected (" .. warningCount .. "/3)")
			end
		end
	elseif totalScore > 50 then
		-- Silent monitoring - increase tracking
		anomalyScore[player].monitoringLevel = (anomalyScore[player].monitoringLevel or 1) + 0.5
		Logging.Warn("AntiCheat", player.Name .. " high anomaly score=" .. totalScore)
		Metrics.Inc("AC_AnomalyHigh")
	end
end

local function ensurePlayer(plr)
	if not shotHistory[plr] then
		shotHistory[plr] = { times = {}, hits = 0, head = 0 }
	end
end

function AntiCheat.RecordShot(plr)
	ensurePlayer(plr)
	local h = shotHistory[plr]
	local currentTime = os.clock()
	table.insert(h.times, currentTime)
	
	-- prune old shots
	for i=#h.times,1,-1 do
		if currentTime - h.times[i] > FIRE_WINDOW then table.remove(h.times, i) end
	end
	
	local rps = #h.times / FIRE_WINDOW
	
	-- Update behavioral stats and check for anomalies
	updateBehaviorStats(plr, "fireRate", rps)
	
	if rps > MAX_RPS_HARD then
		Logging.Warn("AntiCheat", plr.Name .. " exceeded HARD RPS: " .. rps)
		Metrics.Inc("AC_RPSHard")
		bump(plr, "rpsHard", 15, rps)
	elseif rps > MAX_RPS_SOFT then
		Logging.Event("AC_RPSSoft", { u = plr.UserId, rps = rps })
		Metrics.Inc("AC_RPSSoft")
		bump(plr, "rpsSoft", 5, rps)
	end
end

function AntiCheat.RecordHit(plr, isHead)
	ensurePlayer(plr)
	local h = shotHistory[plr]
	h.hits += 1
	if isHead then h.head += 1 end
	local totalShots = math.max(1, #h.times)
	local acc = h.hits / totalShots
	
	-- Update behavioral stats
	updateBehaviorStats(plr, "accuracy", acc)
	
	if h.hits + h.head > 15 then
		if acc > 0.9 then
			Logging.Warn("AntiCheat", plr.Name .. " high accuracy " .. acc)
			Metrics.Inc("AC_HighAcc")
			bump(plr, "acc", 10, acc)
		end
		local headRatio = h.head / h.hits
		
		-- Update headshot ratio stats
		updateBehaviorStats(plr, "headRatio", headRatio)
		
		if h.head > 5 and headRatio > 0.7 then
			Logging.Warn("AntiCheat", plr.Name .. " headshot ratio " .. headRatio)
			Metrics.Inc("AC_HeadRatio")
			bump(plr, "head", 12, headRatio)
		end
	end
end

-- Enhanced position tracking with speed analysis
RunService.Heartbeat:Connect(function(dt)
	for player,posData in pairs(lastPositions) do
		local char = player.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			local root = char.HumanoidRootPart
			local last = posData.Position
			local dist = (root.Position - last).Magnitude
			local speed = dist / dt
			
			-- Update behavioral stats for movement
			updateBehaviorStats(player, "movementSpeed", speed)
			updateBehaviorStats(player, "positionDelta", dist)
			
			if dist > MAX_TELEPORT_DIST then
				Logging.Warn("AntiCheat", player.Name .. " teleport spike dist=" .. dist)
				Metrics.Inc("AC_Teleport")
				bump(player, "teleport", 20, dist)
			elseif speed > MAX_SPEED then
				Logging.Warn("AntiCheat", player.Name .. " speed=" .. speed)
				Metrics.Inc("AC_Speed")
				bump(player, "speed", 8, speed)
			end
			
			posData.Position = root.Position
		else
			lastPositions[player] = nil
		end
	end
end)

function AntiCheat.StartTracking(player)
	if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		lastPositions[player] = { Position = player.Character.HumanoidRootPart.Position }
	end
	player.CharacterAdded:Connect(function(char)
		local root = char:WaitForChild("HumanoidRootPart")
		lastPositions[player] = { Position = root.Position }
	end)
end

-- Get comprehensive anti-cheat statistics for player
function AntiCheat.GetPlayerStats(player)
	local anomaly = anomalyScore[player] or { total = 0 }
	local behavior = behaviorStats[player] or {}
	local shots = shotHistory[player] or { times = {}, hits = 0, head = 0 }
	
	return {
		anomalyScore = anomaly.total,
		violations = anomaly,
		behaviorStats = behavior,
		shotStats = {
			totalShots = #shots.times,
			hits = shots.hits,
			headshots = shots.head,
			accuracy = shots.hits > 0 and (shots.hits / math.max(1, #shots.times)) or 0,
			headRatio = shots.hits > 0 and (shots.head / shots.hits) or 0
		}
	}
end

-- Clean up player data on disconnect
local function onPlayerLeaving(player)
	anomalyScore[player] = nil
	behaviorStats[player] = nil
	shotHistory[player] = nil
	lastPositions[player] = nil
end

game.Players.PlayerRemoving:Connect(onPlayerLeaving)

return AntiCheat
