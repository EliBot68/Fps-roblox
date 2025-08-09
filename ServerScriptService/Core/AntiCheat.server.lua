-- AntiCheat.server.lua
-- Baseline sanity checks

local RunService = game:GetService("RunService")

local AntiCheat = {}

local lastPositions = {}
local MAX_SPEED = 80 -- studs/sec placeholder

function AntiCheat.Track(player)
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return end
	local root = char.HumanoidRootPart
	local lp = lastPositions[player]
	local nowPos = root.Position
	if lp then
		local dt = 1/RunService.Heartbeat:Wait() -- not perfect, replaced below
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
			if speed > MAX_SPEED then
				print("[AntiCheat] Speed violation", player.Name, speed)
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
