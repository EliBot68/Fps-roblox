-- PracticeRangeClient.client.lua
-- Client-side handling for practice range interactions and UI

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Logging = require(ReplicatedStorage.Shared.Logging)

local PracticeRangeClient = {}

-- Current practice state
local inPracticeRange = false
local currentWeapon = nil
local practiceStats = {
	shotsHit = 0,
	totalShots = 0,
	timeInRange = 0,
	startTime = nil
}

-- UI Elements
local practiceGui = nil

-- Initialize practice range client
function PracticeRangeClient.Initialize()
	-- Wait for RemoteEvents
	local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
	local practiceEvents = RemoteRoot:WaitForChild("PracticeEvents")
	
	-- Connect to teleport events
	local teleportToPractice = practiceEvents:WaitForChild("TeleportToPractice")
	local teleportToLobby = practiceEvents:WaitForChild("TeleportToLobby")
	local selectWeapon = practiceEvents:WaitForChild("SelectWeapon")
	
	-- Handle teleport to practice
	teleportToPractice.OnClientEvent:Connect(function()
		PracticeRangeClient.EnterPracticeRange()
	end)
	
	-- Handle teleport to lobby
	teleportToLobby.OnClientEvent:Connect(function()
		PracticeRangeClient.ExitPracticeRange()
	end)
	
	-- Handle weapon selection
	selectWeapon.OnClientEvent:Connect(function(weaponName)
		PracticeRangeClient.OnWeaponSelected(weaponName)
	end)
	
	-- Handle input for quick actions
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not inPracticeRange then return end
		
		if input.KeyCode == Enum.KeyCode.E then
			-- Return to lobby
			teleportToLobby:FireServer()
		elseif input.KeyCode == Enum.KeyCode.R then
			-- Reset stats
			PracticeRangeClient.ResetStats()
		end
	end)
	
	Logging.Info("PracticeRangeClient", "Practice range client initialized")
end

-- Enter practice range
function PracticeRangeClient.EnterPracticeRange()
	inPracticeRange = true
	practiceStats.startTime = tick()
	
	-- Create practice GUI
	PracticeRangeClient.CreatePracticeGUI()
	
	-- Show welcome notification
	PracticeRangeClient.ShowNotification("🎯 Welcome to Practice Range!", "Press E to return to lobby, R to reset stats", 5)
	
	Logging.Info("PracticeRangeClient", "Entered practice range")
end

-- Exit practice range
function PracticeRangeClient.ExitPracticeRange()
	inPracticeRange = false
	currentWeapon = nil
	
	-- Calculate time spent
	if practiceStats.startTime then
		practiceStats.timeInRange = practiceStats.timeInRange + (tick() - practiceStats.startTime)
	end
	
	-- Destroy practice GUI
	if practiceGui then
		practiceGui:Destroy()
		practiceGui = nil
	end
	
	-- Show exit notification with stats
	local accuracy = practiceStats.totalShots > 0 and math.floor((practiceStats.shotsHit / practiceStats.totalShots) * 100) or 0
	local timeMinutes = math.floor(practiceStats.timeInRange / 60)
	local timeSeconds = math.floor(practiceStats.timeInRange % 60)
	
	PracticeRangeClient.ShowNotification(
		"Practice Session Complete!",
		string.format("Accuracy: %d%% | Time: %dm %ds | Hits: %d/%d", 
			accuracy, timeMinutes, timeSeconds, practiceStats.shotsHit, practiceStats.totalShots),
		8
	)
	
	Logging.Info("PracticeRangeClient", "Exited practice range")
end

-- Weapon selected
function PracticeRangeClient.OnWeaponSelected(weaponName)
	currentWeapon = weaponName
	
	PracticeRangeClient.ShowNotification(
		"🔫 " .. weaponName .. " Selected!",
		"Start shooting at the target dummies",
		3
	)
	
	-- Update GUI
	if practiceGui then
		local weaponLabel = practiceGui:FindFirstChild("WeaponLabel")
		if weaponLabel then
			weaponLabel.Text = "Current Weapon: " .. weaponName
		end
	end
	
	Logging.Info("PracticeRangeClient", "Weapon selected: " .. weaponName)
end

-- Create practice GUI
function PracticeRangeClient.CreatePracticeGUI()
	practiceGui = Instance.new("ScreenGui")
	practiceGui.Name = "PracticeRangeGUI"
	practiceGui.ResetOnSpawn = false
	practiceGui.Parent = playerGui
	
	-- Main frame
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0, 300, 0, 200)
	mainFrame.Position = UDim2.new(0, 10, 0, 10)
	mainFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	mainFrame.BackgroundTransparency = 0.3
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = practiceGui
	
	-- Add corner rounding
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = mainFrame
	
	-- Title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, 0, 0, 30)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "🎯 PRACTICE RANGE"
	titleLabel.TextColor3 = Color3.new(1, 1, 0)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.SourceSansBold
	titleLabel.Parent = mainFrame
	
	-- Weapon label
	local weaponLabel = Instance.new("TextLabel")
	weaponLabel.Name = "WeaponLabel"
	weaponLabel.Size = UDim2.new(1, 0, 0, 25)
	weaponLabel.Position = UDim2.new(0, 0, 0, 35)
	weaponLabel.BackgroundTransparency = 1
	weaponLabel.Text = "Current Weapon: None"
	weaponLabel.TextColor3 = Color3.new(1, 1, 1)
	weaponLabel.TextScaled = true
	weaponLabel.Font = Enum.Font.SourceSans
	weaponLabel.Parent = mainFrame
	
	-- Stats frame
	local statsFrame = Instance.new("Frame")
	statsFrame.Name = "StatsFrame"
	statsFrame.Size = UDim2.new(1, -20, 1, -90)
	statsFrame.Position = UDim2.new(0, 10, 0, 70)
	statsFrame.BackgroundTransparency = 1
	statsFrame.Parent = mainFrame
	
	-- Stats labels
	local shotsLabel = Instance.new("TextLabel")
	shotsLabel.Name = "ShotsLabel"
	shotsLabel.Size = UDim2.new(1, 0, 0.25, 0)
	shotsLabel.Position = UDim2.new(0, 0, 0, 0)
	shotsLabel.BackgroundTransparency = 1
	shotsLabel.Text = "Shots: 0"
	shotsLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
	shotsLabel.TextScaled = true
	shotsLabel.Font = Enum.Font.SourceSans
	shotsLabel.TextXAlignment = Enum.TextXAlignment.Left
	shotsLabel.Parent = statsFrame
	
	local hitsLabel = Instance.new("TextLabel")
	hitsLabel.Name = "HitsLabel"
	hitsLabel.Size = UDim2.new(1, 0, 0.25, 0)
	hitsLabel.Position = UDim2.new(0, 0, 0.25, 0)
	hitsLabel.BackgroundTransparency = 1
	hitsLabel.Text = "Hits: 0"
	hitsLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
	hitsLabel.TextScaled = true
	hitsLabel.Font = Enum.Font.SourceSans
	hitsLabel.TextXAlignment = Enum.TextXAlignment.Left
	hitsLabel.Parent = statsFrame
	
	local accuracyLabel = Instance.new("TextLabel")
	accuracyLabel.Name = "AccuracyLabel"
	accuracyLabel.Size = UDim2.new(1, 0, 0.25, 0)
	accuracyLabel.Position = UDim2.new(0, 0, 0.5, 0)
	accuracyLabel.BackgroundTransparency = 1
	accuracyLabel.Text = "Accuracy: 0%"
	accuracyLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
	accuracyLabel.TextScaled = true
	accuracyLabel.Font = Enum.Font.SourceSans
	accuracyLabel.TextXAlignment = Enum.TextXAlignment.Left
	accuracyLabel.Parent = statsFrame
	
	local controlsLabel = Instance.new("TextLabel")
	controlsLabel.Name = "ControlsLabel"
	controlsLabel.Size = UDim2.new(1, 0, 0.25, 0)
	controlsLabel.Position = UDim2.new(0, 0, 0.75, 0)
	controlsLabel.BackgroundTransparency = 1
	controlsLabel.Text = "E: Exit | R: Reset"
	controlsLabel.TextColor3 = Color3.new(0.6, 0.6, 0.6)
	controlsLabel.TextScaled = true
	controlsLabel.Font = Enum.Font.SourceSans
	controlsLabel.TextXAlignment = Enum.TextXAlignment.Left
	controlsLabel.Parent = statsFrame
	
	-- Start updating stats
	PracticeRangeClient.StartStatsUpdate()
end

-- Start stats update loop
function PracticeRangeClient.StartStatsUpdate()
	if not inPracticeRange then return end
	
	task.spawn(function()
		while inPracticeRange and practiceGui do
			-- Update stats display
			local shotsLabel = practiceGui:FindFirstChild("MainFrame") and practiceGui.MainFrame:FindFirstChild("StatsFrame") and practiceGui.MainFrame.StatsFrame:FindFirstChild("ShotsLabel")
			local hitsLabel = practiceGui:FindFirstChild("MainFrame") and practiceGui.MainFrame:FindFirstChild("StatsFrame") and practiceGui.MainFrame.StatsFrame:FindFirstChild("HitsLabel")
			local accuracyLabel = practiceGui:FindFirstChild("MainFrame") and practiceGui.MainFrame:FindFirstChild("StatsFrame") and practiceGui.MainFrame.StatsFrame:FindFirstChild("AccuracyLabel")
			
			if shotsLabel then
				shotsLabel.Text = "Shots: " .. practiceStats.totalShots
			end
			
			if hitsLabel then
				hitsLabel.Text = "Hits: " .. practiceStats.shotsHit
			end
			
			if accuracyLabel then
				local accuracy = practiceStats.totalShots > 0 and math.floor((practiceStats.shotsHit / practiceStats.totalShots) * 100) or 0
				accuracyLabel.Text = "Accuracy: " .. accuracy .. "%"
				
				-- Color code accuracy
				if accuracy >= 80 then
					accuracyLabel.TextColor3 = Color3.new(0, 1, 0) -- Green
				elseif accuracy >= 60 then
					accuracyLabel.TextColor3 = Color3.new(1, 1, 0) -- Yellow
				elseif accuracy >= 40 then
					accuracyLabel.TextColor3 = Color3.new(1, 0.5, 0) -- Orange
				else
					accuracyLabel.TextColor3 = Color3.new(1, 0, 0) -- Red
				end
			end
			
			task.wait(0.1)
		end
	end)
end

-- Reset stats
function PracticeRangeClient.ResetStats()
	practiceStats.shotsHit = 0
	practiceStats.totalShots = 0
	practiceStats.timeInRange = 0
	practiceStats.startTime = tick()
	
	PracticeRangeClient.ShowNotification("Stats Reset!", "Practice statistics have been cleared", 2)
end

-- Show notification
function PracticeRangeClient.ShowNotification(title, message, duration)
	-- Create notification GUI
	local notificationGui = Instance.new("ScreenGui")
	notificationGui.Name = "NotificationGUI"
	notificationGui.Parent = playerGui
	
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 400, 0, 100)
	frame.Position = UDim2.new(0.5, -200, 0, -100)
	frame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Parent = notificationGui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame
	
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -20, 0.5, 0)
	titleLabel.Position = UDim2.new(0, 10, 0, 5)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = title
	titleLabel.TextColor3 = Color3.new(1, 1, 0)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.SourceSansBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = frame
	
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
	
	-- Animate out after duration
	task.wait(duration)
	local slideOut = TweenService:Create(frame,
		TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In),
		{Position = UDim2.new(0.5, -200, 0, -100)}
	)
	slideOut:Play()
	
	slideOut.Completed:Connect(function()
		notificationGui:Destroy()
	end)
end

-- Track shot fired
function PracticeRangeClient.OnShotFired()
	if inPracticeRange then
		practiceStats.totalShots = practiceStats.totalShots + 1
	end
end

-- Track shot hit
function PracticeRangeClient.OnShotHit()
	if inPracticeRange then
		practiceStats.shotsHit = practiceStats.shotsHit + 1
	end
end

-- Initialize when script loads
PracticeRangeClient.Initialize()

-- Expose functions for other scripts
_G.PracticeRangeClient = PracticeRangeClient

return PracticeRangeClient
