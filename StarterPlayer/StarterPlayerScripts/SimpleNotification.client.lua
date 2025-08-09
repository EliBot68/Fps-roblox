-- SimpleNotification.client.lua
-- Basic notification system for practice range

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SimpleNotification = {}

-- Initialize notification system
function SimpleNotification.Initialize()
	local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
	local UIEvents = RemoteRoot:WaitForChild("UIEvents")
	local notificationRemote = UIEvents:WaitForChild("ShowNotification")
	
	-- Handle notification requests
	notificationRemote.OnClientEvent:Connect(function(title, message, duration)
		SimpleNotification.ShowNotification(title, message, duration or 3)
	end)
	
	print("SimpleNotification system initialized")
end

-- Show a notification
function SimpleNotification.ShowNotification(title, message, duration)
	-- Create notification GUI
	local notificationGui = Instance.new("ScreenGui")
	notificationGui.Name = "SimpleNotification"
	notificationGui.Parent = playerGui
	
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 400, 0, 120)
	frame.Position = UDim2.new(0.5, -200, 0, -130)
	frame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Parent = notificationGui
	
	-- Add corner rounding
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame
	
	-- Add title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -20, 0.5, 0)
	titleLabel.Position = UDim2.new(0, 10, 0, 10)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = title
	titleLabel.TextColor3 = Color3.new(1, 1, 0)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.SourceSansBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = frame
	
	-- Add message
	local messageLabel = Instance.new("TextLabel")
	messageLabel.Size = UDim2.new(1, -20, 0.5, 0)
	messageLabel.Position = UDim2.new(0, 10, 0.5, 0)
	messageLabel.BackgroundTransparency = 1
	messageLabel.Text = message
	messageLabel.TextColor3 = Color3.new(1, 1, 1)
	messageLabel.TextScaled = true
	messageLabel.Font = Enum.Font.SourceSans
	messageLabel.TextXAlignment = Enum.TextXAlignment.Left
	messageLabel.Parent = frame
	
	-- Animate in
	local slideIn = TweenService:Create(frame,
		TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = UDim2.new(0.5, -200, 0, 20)}
	)
	slideIn:Play()
	
	-- Auto-close after duration
	task.spawn(function()
		task.wait(duration)
		
		local slideOut = TweenService:Create(frame,
			TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In),
			{Position = UDim2.new(0.5, -200, 0, -130)}
		)
		slideOut:Play()
		
		slideOut.Completed:Connect(function()
			notificationGui:Destroy()
		end)
	end)
end

-- Initialize when loaded
SimpleNotification.Initialize()

return SimpleNotification
