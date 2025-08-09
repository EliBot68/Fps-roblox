-- HUD.client.lua
-- Basic ScreenGui HUD implementation

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
local UIEvents = RemoteRoot:WaitForChild("UIEvents")
local UpdateStatsRemote = UIEvents:WaitForChild("UpdateStats")
local UpdateCurrencyRemote = UIEvents:FindFirstChild("UpdateCurrency")

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
