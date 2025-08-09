-- AntiCheatWarning.client.lua
-- Client handler for anti-cheat warnings

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
local UIEvents = RemoteRoot:WaitForChild("UIEvents")
local AntiCheatWarning = UIEvents:WaitForChild("AntiCheatWarning")

-- Create warning GUI
local gui = Instance.new("ScreenGui")
gui.Name = "AntiCheatWarningUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local warningFrame = Instance.new("Frame")
warningFrame.Name = "WarningFrame"
warningFrame.Size = UDim2.new(0,400,0,100)
warningFrame.Position = UDim2.new(0.5,-200,0.1,0)
warningFrame.BackgroundColor3 = Color3.fromRGB(200,50,50)
warningFrame.BorderSizePixel = 0
warningFrame.Visible = false
warningFrame.Parent = gui

-- Add warning styling
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0,8)
corner.Parent = warningFrame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255,100,100)
stroke.Thickness = 2
stroke.Parent = warningFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Text = "⚠️ ANTI-CHEAT WARNING"
titleLabel.Size = UDim2.new(1,0,0.4,0)
titleLabel.Position = UDim2.new(0,0,0,0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.fromRGB(255,255,255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 16
titleLabel.Parent = warningFrame

local messageLabel = Instance.new("TextLabel")
messageLabel.Text = "Suspicious activity detected"
messageLabel.Size = UDim2.new(1,-20,0.6,0)
messageLabel.Position = UDim2.new(0,10,0.4,0)
messageLabel.BackgroundTransparency = 1
messageLabel.TextColor3 = Color3.fromRGB(255,255,255)
messageLabel.Font = Enum.Font.Gotham
messageLabel.TextSize = 12
messageLabel.TextWrapped = true
messageLabel.Parent = warningFrame

local function showWarning(message)
	messageLabel.Text = message
	warningFrame.Visible = true
	
	-- Slide in animation
	warningFrame.Position = UDim2.new(0.5,-200,-0.2,0)
	local slideIn = TweenService:Create(warningFrame, 
		TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = UDim2.new(0.5,-200,0.1,0)}
	)
	slideIn:Play()
	
	-- Auto-hide after 5 seconds
	task.wait(5)
	local slideOut = TweenService:Create(warningFrame,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{Position = UDim2.new(0.5,-200,-0.2,0)}
	)
	slideOut:Play()
	slideOut.Completed:Connect(function()
		warningFrame.Visible = false
	end)
end

-- Handle warning events from server
AntiCheatWarning.OnClientEvent:Connect(function(message)
	showWarning(message)
end)
