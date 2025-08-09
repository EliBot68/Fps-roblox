-- LobbyManager.server.lua
-- Manages lobby area with teleport buttons and player spawning

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Logging = require(ReplicatedStorage.Shared.Logging)

local LobbyManager = {}

-- Create enterprise-level practice teleport touchpad
function LobbyManager.CreatePracticeTeleportTouchpad()
	-- Find or create spawn location in main lobby area
	local spawnLocation = workspace:FindFirstChild("SpawnLocation")
	if not spawnLocation then
		spawnLocation = Instance.new("SpawnLocation")
		spawnLocation.Name = "SpawnLocation"
		spawnLocation.Size = Vector3.new(8, 1, 8)
		spawnLocation.Position = Vector3.new(0, 0.5, 0) -- Main lobby spawn at origin
		spawnLocation.Material = Enum.Material.Neon
		spawnLocation.BrickColor = BrickColor.new("Bright green")
		spawnLocation.Anchored = true
		spawnLocation.Parent = workspace
	end
	
	-- Create teleport touchpad platform (enterprise-level design)
	local touchpadBase = Instance.new("Part")
	touchpadBase.Name = "PracticeTeleportTouchpad"
	touchpadBase.Size = Vector3.new(12, 1, 12)
	touchpadBase.Position = Vector3.new(25, 0.5, 0) -- 25 studs away from main spawn
	touchpadBase.Material = Enum.Material.ForceField
	touchpadBase.Color = Color3.new(0, 0.3, 0.8) -- Deep blue
	touchpadBase.Anchored = true
	touchpadBase.CanCollide = true
	touchpadBase.Parent = workspace
	
	-- Create central activation pad
	local activationPad = Instance.new("Part")
	activationPad.Name = "ActivationPad"
	activationPad.Size = Vector3.new(8, 0.5, 8)
	activationPad.Position = Vector3.new(25, 1.25, 0)
	activationPad.Material = Enum.Material.Neon
	activationPad.Color = Color3.new(0, 0.7, 1) -- Bright blue
	activationPad.Anchored = true
	activationPad.CanCollide = false
	activationPad.Parent = workspace
	
	-- Create holographic indicators around the pad
	local indicators = {}
	for i = 1, 4 do
		local angle = (i - 1) * (math.pi / 2)
		local x = 25 + math.cos(angle) * 8
		local z = 0 + math.sin(angle) * 8
		
		local indicator = Instance.new("Part")
		indicator.Name = "Indicator" .. i
		indicator.Size = Vector3.new(1, 6, 1)
		indicator.Position = Vector3.new(x, 3.5, z)
		indicator.Material = Enum.Material.ForceField
		indicator.Color = Color3.new(0, 1, 1) -- Cyan
		indicator.Anchored = true
		indicator.CanCollide = false
		indicator.Transparency = 0.3
		indicator.Parent = workspace
		
		table.insert(indicators, indicator)
	end
	
	-- Add enterprise-level lighting system
	local mainLight = Instance.new("PointLight")
	mainLight.Color = Color3.new(0, 0.7, 1)
	mainLight.Brightness = 5
	mainLight.Range = 30
	mainLight.Parent = activationPad
	
	-- Add particle effects
	local particles = Instance.new("ParticleEmitter")
	particles.Texture = "rbxassetid://241650934" -- Sparkle texture
	particles.Lifetime = NumberRange.new(2, 4)
	particles.Rate = 20
	particles.SpreadAngle = Vector2.new(360, 360)
	particles.Speed = NumberRange.new(5, 10)
	particles.Color = ColorSequence.new(Color3.new(0, 0.7, 1))
	particles.Parent = activationPad
	
	-- Create holographic display
	local hologramAttachment = Instance.new("Attachment")
	hologramAttachment.Position = Vector3.new(0, 4, 0)
	hologramAttachment.Parent = activationPad
	
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 400, 0, 200)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.LightInfluence = 0
	billboard.Parent = activationPad
	
	local mainLabel = Instance.new("TextLabel")
	mainLabel.Size = UDim2.new(1, 0, 0.5, 0)
	mainLabel.Position = UDim2.new(0, 0, 0, 0)
	mainLabel.BackgroundTransparency = 1
	mainLabel.Text = "🎯 PRACTICE RANGE ACCESS"
	mainLabel.TextColor3 = Color3.new(0, 1, 1)
	mainLabel.TextScaled = true
	mainLabel.Font = Enum.Font.SourceSansBold
	mainLabel.TextStrokeTransparency = 0
	mainLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	mainLabel.Parent = billboard
	
	local instructionLabel = Instance.new("TextLabel")
	instructionLabel.Size = UDim2.new(1, 0, 0.3, 0)
	instructionLabel.Position = UDim2.new(0, 0, 0.5, 0)
	instructionLabel.BackgroundTransparency = 1
	instructionLabel.Text = "Step onto the pad to teleport"
	instructionLabel.TextColor3 = Color3.new(0.8, 0.8, 1)
	instructionLabel.TextScaled = true
	instructionLabel.Font = Enum.Font.SourceSans
	instructionLabel.TextStrokeTransparency = 0
	instructionLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	instructionLabel.Parent = billboard
	
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, 0, 0.2, 0)
	statusLabel.Position = UDim2.new(0, 0, 0.8, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "READY FOR TRANSPORT"
	statusLabel.TextColor3 = Color3.new(0, 1, 0)
	statusLabel.TextScaled = true
	statusLabel.Font = Enum.Font.SourceSansBold
	statusLabel.TextStrokeTransparency = 0
	statusLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	statusLabel.Parent = billboard
	
	-- Enterprise touch detection system with debounce
	local touchCooldowns = {} -- Per-player cooldown system
	local teleportInProgress = {} -- Track teleportation states
	
	-- Enhanced touch detection with validation
	local function handleTouch(hit, hitPart)
		local character = hit.Parent
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local player = Players:GetPlayerFromCharacter(character)
		
		-- Validation checks
		if not player or not humanoid then return end
		if not character:FindFirstChild("HumanoidRootPart") then return end
		
		local userId = player.UserId
		local currentTime = tick()
		
		-- Check cooldown (prevent spam teleporting)
		if touchCooldowns[userId] and currentTime - touchCooldowns[userId] < 3 then
			return -- Still on cooldown
		end
		
		-- Check if already teleporting
		if teleportInProgress[userId] then return end
		
		-- Set cooldown and teleport state
		touchCooldowns[userId] = currentTime
		teleportInProgress[userId] = true
		
		-- Update status display
		statusLabel.Text = "TELEPORTING " .. player.Name:upper() .. "..."
		statusLabel.TextColor3 = Color3.new(1, 1, 0) -- Yellow
		
		-- Enterprise-level teleport sequence
		LobbyManager.ExecuteTeleportSequence(player, statusLabel, function()
			teleportInProgress[userId] = false
			statusLabel.Text = "READY FOR TRANSPORT"
			statusLabel.TextColor3 = Color3.new(0, 1, 0) -- Green
		end)
	end
	
	-- Connect touch events to both base and activation pad
	touchpadBase.Touched:Connect(handleTouch)
	activationPad.Touched:Connect(handleTouch)
	
	-- Enterprise animation system
	local animationSequence = {
		-- Pad pulsing
		TweenService:Create(activationPad,
			TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{Transparency = 0.2}
		),
		-- Light pulsing
		TweenService:Create(mainLight,
			TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{Brightness = 2}
		)
	}
	
	-- Start all animations
	for _, tween in ipairs(animationSequence) do
		tween:Play()
	end
	
	-- Indicator rotation animation
	task.spawn(function()
		while true do
			for i, indicator in ipairs(indicators) do
				local rotationTween = TweenService:Create(indicator,
					TweenInfo.new(4, Enum.EasingStyle.Linear),
					{CFrame = indicator.CFrame * CFrame.Angles(0, math.pi * 2, 0)}
				)
				rotationTween:Play()
			end
			task.wait(4)
		end
	end)
	
	Logging.Info("LobbyManager", "Enterprise practice teleport touchpad created with validation system")
	return {touchpadBase, activationPad, indicators}
end

-- Execute enterprise teleport sequence
function LobbyManager.ExecuteTeleportSequence(player, statusLabel, callback)
	-- Create teleport effect at player position
	local character = player.Character
	if not character then 
		callback()
		return 
	end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then 
		callback()
		return 
	end
	
	-- Create teleport VFX
	local teleportEffect = Instance.new("Part")
	teleportEffect.Size = Vector3.new(8, 12, 8)
	teleportEffect.Position = humanoidRootPart.Position
	teleportEffect.Material = Enum.Material.ForceField
	teleportEffect.Color = Color3.new(0, 1, 1)
	teleportEffect.Anchored = true
	teleportEffect.CanCollide = false
	teleportEffect.Shape = Enum.PartType.Cylinder
	teleportEffect.Parent = workspace
	
	-- Teleport sound effect
	local teleportSound = Instance.new("Sound")
	teleportSound.SoundId = "rbxassetid://131961136" -- Teleport sound
	teleportSound.Volume = 0.5
	teleportSound.Parent = teleportEffect
	teleportSound:Play()
	
	-- Spin and scale effect
	local effectTween = TweenService:Create(teleportEffect,
		TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = Vector3.new(2, 20, 2),
			Transparency = 1,
			CFrame = teleportEffect.CFrame * CFrame.Angles(0, math.pi * 4, 0)
		}
	)
	effectTween:Play()
	
	-- Execute teleport after effect
	task.spawn(function()
		task.wait(0.5) -- Mid-effect teleport for smoothness
		
		-- Execute teleport directly (server-side call)
		local success = pcall(function()
			-- Import PracticeMapManager if not already done
			local PracticeMapManager = require(game.ServerScriptService.Core:WaitForChild("PracticeMapManager"))
			
			-- Call teleport function directly
			PracticeMapManager.TeleportToPractice(player)
			
			Logging.Info("LobbyManager", "Direct teleport executed for " .. player.Name)
		end)
		
		if not success then
			warn("Failed to execute teleport for " .. player.Name)
		end
		
		-- Clean up effect
		task.wait(0.5)
		teleportEffect:Destroy()
		callback()
	end)
end

-- Create lobby information display
function LobbyManager.CreateLobbyInfo()
	-- Create welcome sign positioned in main lobby area
	local welcomeSign = Instance.new("Part")
	welcomeSign.Name = "WelcomeSign"
	welcomeSign.Size = Vector3.new(0.5, 12, 20)
	welcomeSign.Position = Vector3.new(-30, 6, 0) -- West of main spawn area
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
	-- Create practice teleport touchpad (enterprise-level touchpad system)
	LobbyManager.CreatePracticeTeleportTouchpad()
	
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
				notificationRemote:FireClient(player, "Welcome to Rival Clash! Step on the blue touchpad to access Practice Range.", "info", 5)
			end
		end)
	end)
	
	Logging.Info("LobbyManager", "Enterprise lobby system initialized with touchpad teleportation")
end

-- Start lobby manager
LobbyManager.Initialize()

return LobbyManager
