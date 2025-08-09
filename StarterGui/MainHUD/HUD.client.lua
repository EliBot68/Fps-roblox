-- HUD.client.lua
-- Basic ScreenGui HUD implementation

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "MainHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function makeLabel(name, position)
	local t = Instance.new("TextLabel")
	t.Name = name
	t.Size = UDim2.new(0,180,0,24)
	t.Position = position
	t.BackgroundTransparency = 0.3
	t.BackgroundColor3 = Color3.fromRGB(20,20,20)
	t.TextColor3 = Color3.fromRGB(255,255,255)
	t.Font = Enum.Font.GothamBold
	t.TextSize = 16
	t.Text = name..":0"
	t.Parent = gui
	return t
end

local healthLabel = makeLabel("Health", UDim2.new(0,10,0,10))
local ammoLabel = makeLabel("Ammo", UDim2.new(0,10,0,40))
local killsLabel = makeLabel("Kills", UDim2.new(0,10,0,70))
local deathsLabel = makeLabel("Deaths", UDim2.new(0,10,0,100))
local currencyLabel = makeLabel("Currency", UDim2.new(0,10,0,130))

-- Match Timer
local timerLabel = makeLabel("Time", UDim2.new(0.5,-90,0,10))
timerLabel.Size = UDim2.new(0,180,0,30)
timerLabel.TextSize = 20
timerLabel.BackgroundColor3 = Color3.fromRGB(40,40,40)

local matchStartTime = nil
local matchLength = 180 -- 3 minutes default

local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
local UIEvents = RemoteRoot:WaitForChild("UIEvents")
local UpdateStatsRemote = UIEvents:WaitForChild("UpdateStats")
local UpdateCurrencyRemote = UIEvents:FindFirstChild("UpdateCurrency")

-- Match timer update
RunService.Heartbeat:Connect(function()
	if matchStartTime then
		local elapsed = os.clock() - matchStartTime
		local remaining = math.max(0, matchLength - elapsed)
		local minutes = math.floor(remaining / 60)
		local seconds = math.floor(remaining % 60)
		timerLabel.Text = string.format("Time: %02d:%02d", minutes, seconds)
		
		if remaining <= 0 then
			timerLabel.Text = "Time: 00:00"
			matchStartTime = nil
		end
	else
		timerLabel.Text = "Time: --:--"
	end
end)

-- Listen for match events
local MatchmakingEvents = RemoteRoot:WaitForChild("MatchmakingEvents")
local MatchStartRemote = MatchmakingEvents:FindFirstChild("MatchStart")
local MatchEndRemote = MatchmakingEvents:FindFirstChild("MatchEnd")

if MatchStartRemote then
	MatchStartRemote.OnClientEvent:Connect(function(duration)
		matchStartTime = os.clock()
		matchLength = duration or 180
	end)
end

if MatchEndRemote then
	MatchEndRemote.OnClientEvent:Connect(function()
		matchStartTime = nil
	end)
end

UpdateStatsRemote.OnClientEvent:Connect(function(data)
	if not data then return end
	healthLabel.Text = "Health:".. tostring(data.Health)
	ammoLabel.Text = "Ammo:".. tostring(data.Ammo) .. "/" .. tostring(data.Reserve)
	killsLabel.Text = "Kills:".. tostring(data.Kills)
	deathsLabel.Text = "Deaths:".. tostring(data.Deaths)
end)

if UpdateCurrencyRemote then
	UpdateCurrencyRemote.OnClientEvent:Connect(function(amount)
		currencyLabel.Text = "Currency:" .. tostring(amount)
	end)
end
