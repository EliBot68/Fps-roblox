-- AntiCheat.server.lua
-- Enhanced anti-cheat heuristics

local RunService = game:GetService("RunService")
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

local function ensurePlayer(plr)
	if not shotHistory[plr] then
		shotHistory[plr] = { times = {}, hits = 0, head = 0 }
	end
end

function AntiCheat.RecordShot(plr)
	ensurePlayer(plr)
	local h = shotHistory[plr]
	table.insert(h.times, os.clock())
	-- prune
	for i=#h.times,1,-1 do
		if os.clock() - h.times[i] > FIRE_WINDOW then table.remove(h.times, i) end
	end
	local rps = #h.times / FIRE_WINDOW
	if rps > MAX_RPS_HARD then
		Logging.Warn("AntiCheat", plr.Name .. " exceeded HARD RPS: " .. rps)
		Metrics.Inc("AC_RPSHard")
	elseif rps > MAX_RPS_SOFT then
		Logging.Event("AC_RPSSoft", { u = plr.UserId, rps = rps })
		Metrics.Inc("AC_RPSSoft")
	end
end

function AntiCheat.RecordHit(plr, isHead)
	ensurePlayer(plr)
	local h = shotHistory[plr]
	h.hits += 1
	if isHead then h.head += 1 end
	local totalShots = math.max(1, #h.times)
	local acc = h.hits / totalShots
	if h.hits + h.head > 15 then
		if acc > 0.9 then
			Logging.Warn("AntiCheat", plr.Name .. " high accuracy " .. acc)
			Metrics.Inc("AC_HighAcc")
		end
		local headRatio = h.head / h.hits
		if h.head > 5 and headRatio > 0.7 then
			Logging.Warn("AntiCheat", plr.Name .. " headshot ratio " .. headRatio)
			Metrics.Inc("AC_HeadRatio")
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	for player,posData in pairs(lastPositions) do
		local char = player.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			local root = char.HumanoidRootPart
			local last = posData.Position
			local dist = (root.Position - last).Magnitude
			local speed = dist / dt
			if dist > MAX_TELEPORT_DIST then
				Logging.Warn("AntiCheat", player.Name .. " teleport spike dist=" .. dist)
				Metrics.Inc("AC_Teleport")
			elseif speed > MAX_SPEED then
				Logging.Warn("AntiCheat", player.Name .. " speed=" .. speed)
				Metrics.Inc("AC_Speed")
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

return AntiCheat
