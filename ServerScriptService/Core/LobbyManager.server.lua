-- LobbyManager.server.lua
-- Manages lobby area with teleport buttons and player spawning

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Logging = require(ReplicatedStorage.Shared.Logging)

local LobbyManager = {}

-- Create practice teleport button at spawn
function LobbyManager.CreatePracticeTeleportButton()
	-- Find spawn location or create one
	local spawnLocation = workspace:FindFirstChild("SpawnLocation")
	if not spawnLocation then
		spawnLocation = Instance.new("SpawnLocation")
		spawnLocation.Name = "SpawnLocation"
		spawnLocation.Size = Vector3.new(6, 1, 6)
		spawnLocation.Position = Vector3.new(0, 0.5, 0)
		spawnLocation.Material = Enum.Material.Neon
		spawnLocation.BrickColor = BrickColor.new("Bright green")
		spawnLocation.Anchored = true
		spawnLocation.Parent = workspace
	end
	
	-- Create teleport button
	local teleportButton = Instance.new("Part")
	teleportButton.Name = "PracticeTeleportButton"
	teleportButton.Size = Vector3.new(4, 2, 4)
	teleportButton.Position = Vector3.new(10, 2, 0) -- Position near spawn
	teleportButton.Material = Enum.Material.Neon
	teleportButton.Color = Color3.new(0, 0.5, 1) -- Blue
	teleportButton.Anchored = true
	teleportButton.Shape = Enum.PartType.Cylinder
	teleportButton.Parent = workspace
	
	-- Add glow effect
	local pointLight = Instance.new("PointLight")
	pointLight.Color = Color3.new(0, 0.5, 1)
	pointLight.Brightness = 3
	pointLight.Range = 20
	pointLight.Parent = teleportButton
	
	-- Create button label
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 300, 0, 100)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.Parent = teleportButton
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0.6, 0)
	label.Position = UDim2.new(0, 0, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = "🎯 PRACTICE RANGE"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.SourceSansBold
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Parent = billboard
	
	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, 0, 0.4, 0)
	subLabel.Position = UDim2.new(0, 0, 0.6, 0)
	subLabel.BackgroundTransparency = 1
	subLabel.Text = "Click to teleport"
	subLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
	subLabel.TextScaled = true
	subLabel.Font = Enum.Font.SourceSans
	subLabel.TextStrokeTransparency = 0
	subLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	subLabel.Parent = billboard
	
	-- Add ClickDetector
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 20
	clickDetector.Parent = teleportButton
	
	-- Connect click event
	clickDetector.MouseClick:Connect(function(player)
		-- Fire remote event to teleport player
		local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
		local practiceEvents = RemoteRoot:WaitForChild("PracticeEvents")
		local teleportRemote = practiceEvents:WaitForChild("TeleportToPractice")
		
		if teleportRemote then
			teleportRemote:FireServer()
		end
	end)
	
	-- Add pulsing animation
	local pulseTween = TweenService:Create(teleportButton,
		TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{Size = Vector3.new(4.5, 2.5, 4.5)}
	)
	pulseTween:Play()
	
	-- Add floating animation
	local floatTween = TweenService:Create(teleportButton,
		TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{Position = teleportButton.Position + Vector3.new(0, 1, 0)}
	)
	floatTween:Play()
	
	Logging.Info("LobbyManager", "Practice teleport button created")
	return teleportButton
end

-- Create lobby information display
function LobbyManager.CreateLobbyInfo()
	-- Create welcome sign
	local welcomeSign = Instance.new("Part")
	welcomeSign.Name = "WelcomeSign"
	welcomeSign.Size = Vector3.new(0.2, 8, 12)
	welcomeSign.Position = Vector3.new(-15, 4, 0)
	welcomeSign.Material = Enum.Material.Neon
	welcomeSign.Color = Color3.new(0.1, 0.1, 0.1)
	welcomeSign.Anchored = true
	welcomeSign.Parent = workspace
	
	-- Add welcome text
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.Parent = welcomeSign
	
	local welcomeLabel = Instance.new("TextLabel")
	welcomeLabel.Size = UDim2.new(1, 0, 0.4, 0)
	welcomeLabel.Position = UDim2.new(0, 0, 0.1, 0)
	welcomeLabel.BackgroundTransparency = 1
	welcomeLabel.Text = "🏆 RIVAL CLASH"
	welcomeLabel.TextColor3 = Color3.new(1, 1, 0)
	welcomeLabel.TextScaled = true
	welcomeLabel.Font = Enum.Font.SourceSansBold
	welcomeLabel.Parent = surfaceGui
	
	local infoLabel = Instance.new("TextLabel")
	infoLabel.Size = UDim2.new(1, 0, 0.5, 0)
	infoLabel.Position = UDim2.new(0, 0, 0.5, 0)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Text = "Enterprise FPS Game\n\n• Practice Range Available\n• 6 Weapons to Test\n• Target Dummies\n• Return Portal"
	infoLabel.TextColor3 = Color3.new(1, 1, 1)
	infoLabel.TextScaled = true
	infoLabel.Font = Enum.Font.SourceSans
	infoLabel.TextXAlignment = Enum.TextXAlignment.Left
	infoLabel.Parent = surfaceGui
	
	Logging.Info("LobbyManager", "Lobby information display created")
end

-- Initialize lobby
function LobbyManager.Initialize()
	-- Create practice teleport button
	LobbyManager.CreatePracticeTeleportButton()
	
	-- Create lobby info
	LobbyManager.CreateLobbyInfo()
	
	-- Handle player spawning
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			-- Give player a moment to load
			task.wait(1)
			
			-- Send welcome message
			local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
			local UIEvents = RemoteRoot:WaitForChild("UIEvents")
			local notificationRemote = UIEvents:FindFirstChild("ShowNotification")
			if notificationRemote then
				notificationRemote:FireClient(player, "Welcome to Rival Clash! Click the blue button to access Practice Range.", "info", 5)
			end
		end)
	end)
	
	Logging.Info("LobbyManager", "Lobby system initialized")
end

-- Start lobby manager
LobbyManager.Initialize()

return LobbyManager
