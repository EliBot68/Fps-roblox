--[[
	LobbyManager.server.lua
	Enterprise-level lobby management with advanced touchpad teleportation system
	
	Features:
	- High-performance touchpad teleportation with validation
	- Advanced visual effects and animations
	- Rate limiting and security measures
	- Professional user experience
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

local Logging = require(ReplicatedStorage.Shared.Logging)
local RateLimiter = require(ReplicatedStorage.Shared.RateLimiter)

local LobbyManager = {}

-- Configuration constants
local TOUCHPAD_CONFIG = {
	position = Vector3.new(25, 5, 0), -- Raised from 3 to 5 for better visibility
	baseSize = Vector3.new(14, 1, 14),
	activationSize = Vector3.new(10, 0.8, 10),
	effectHeight = 15,
	cooldownTime = 2, -- Reduced from 3 seconds
	animationSpeed = 2,
	lightRange = 35,
	particleRate = 30
}

-- State management
local touchpadState = {
	cooldowns = {},
	teleportInProgress = {},
	activeEffects = {},
	connectionsCleaned = false
}

-- Ensure spawn location exists with proper setup
function LobbyManager.EnsureSpawnLocation()
	local spawnLocation = workspace:FindFirstChild("SpawnLocation")
	if not spawnLocation then
		spawnLocation = Instance.new("SpawnLocation")
		spawnLocation.Name = "SpawnLocation"
		spawnLocation.Size = Vector3.new(10, 1, 10)
		spawnLocation.Position = Vector3.new(0, 0.5, 0)
		spawnLocation.Material = Enum.Material.Neon
		spawnLocation.BrickColor = BrickColor.new("Bright green")
		spawnLocation.Anchored = true
		spawnLocation.TopSurface = Enum.SurfaceType.Smooth
		spawnLocation.BottomSurface = Enum.SurfaceType.Smooth
		spawnLocation.Parent = workspace
		
		-- Add spawn location lighting
		local spawnLight = Instance.new("PointLight")
		spawnLight.Color = Color3.new(0, 1, 0)
		spawnLight.Brightness = 3
		spawnLight.Range = 20
		spawnLight.Parent = spawnLocation
	end
end

-- Create touchpad base platform
function LobbyManager.CreateTouchpadBase()
	local touchpadBase = Instance.new("Part")
	touchpadBase.Name = "PracticeTeleportTouchpad"
	touchpadBase.Size = TOUCHPAD_CONFIG.baseSize
	touchpadBase.Position = TOUCHPAD_CONFIG.position
	touchpadBase.Material = Enum.Material.ForceField
	touchpadBase.Color = Color3.new(0, 0.2, 0.6) -- Deep blue
	touchpadBase.Anchored = true
	touchpadBase.CanCollide = true
	touchpadBase.TopSurface = Enum.SurfaceType.Smooth
	touchpadBase.BottomSurface = Enum.SurfaceType.Smooth
	touchpadBase.Parent = workspace
	
	-- Add base rim effect
	local rim = Instance.new("SelectionBox")
	rim.Adornee = touchpadBase
	rim.Color3 = Color3.new(0, 0.8, 1)
	rim.LineThickness = 0.2
	rim.Transparency = 0.3
	rim.Parent = touchpadBase
	
	return touchpadBase
end

-- Create activation pad with enhanced visuals
function LobbyManager.CreateActivationPad()
	local activationPad = Instance.new("Part")
	activationPad.Name = "ActivationPad"
	activationPad.Size = TOUCHPAD_CONFIG.activationSize
	activationPad.Position = Vector3.new(TOUCHPAD_CONFIG.position.X, TOUCHPAD_CONFIG.position.Y + 1, TOUCHPAD_CONFIG.position.Z)
	activationPad.Material = Enum.Material.Neon
	activationPad.Color = Color3.new(0, 0.7, 1) -- Bright cyan
	activationPad.Anchored = true
	activationPad.CanCollide = false
	activationPad.Shape = Enum.PartType.Cylinder
	activationPad.Parent = workspace
	
	-- Add primary lighting
	local mainLight = Instance.new("PointLight")
	mainLight.Color = Color3.new(0, 0.7, 1)
	mainLight.Brightness = 5
	mainLight.Range = TOUCHPAD_CONFIG.lightRange
	mainLight.Parent = activationPad
	
	-- Add particle system
	local particles = Instance.new("ParticleEmitter")
	particles.Texture = "rbxassetid://241650934"
	particles.Lifetime = NumberRange.new(1.5, 3)
	particles.Rate = TOUCHPAD_CONFIG.particleRate
	particles.SpreadAngle = Vector2.new(45, 45)
	particles.Speed = NumberRange.new(3, 8)
	particles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(0, 0.7, 1)),
		ColorSequenceKeypoint.new(0.5, Color3.new(0.3, 0.9, 1)),
		ColorSequenceKeypoint.new(1, Color3.new(0, 0.4, 0.8))
	})
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.5, 0.8),
		NumberSequenceKeypoint.new(1, 0.1)
	})
	particles.Parent = activationPad
	
	return activationPad
end

-- Create visual indicators with improved design
function LobbyManager.CreateVisualIndicators()
	local indicators = {}
	local numIndicators = 6 -- Increased from 4
	
	for i = 1, numIndicators do
		local angle = (i - 1) * (math.pi * 2 / numIndicators)
		local radius = 9
		local x = TOUCHPAD_CONFIG.position.X + math.cos(angle) * radius
		local z = TOUCHPAD_CONFIG.position.Z + math.sin(angle) * radius
		
		local indicator = Instance.new("Part")
		indicator.Name = "TouchpadIndicator" .. i
		indicator.Size = Vector3.new(0.8, 8, 0.8)
		indicator.Position = Vector3.new(x, 4.5, z)
		indicator.Material = Enum.Material.ForceField
		indicator.Color = Color3.new(0, 1, 1)
		indicator.Anchored = true
		indicator.CanCollide = false
		indicator.Transparency = 0.2
		indicator.Parent = workspace
		
		-- Add indicator lighting
		local indicatorLight = Instance.new("PointLight")
		indicatorLight.Color = Color3.new(0, 1, 1)
		indicatorLight.Brightness = 2
		indicatorLight.Range = 15
		indicatorLight.Parent = indicator
		
		table.insert(indicators, indicator)
	end
	
	return indicators
end

-- Create holographic display system
function LobbyManager.CreateHolographicDisplay(activationPad)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 500, 0, 250)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.LightInfluence = 0
	billboard.Parent = activationPad
	
	-- Main title
	local mainLabel = Instance.new("TextLabel")
	mainLabel.Size = UDim2.new(1, 0, 0.4, 0)
	mainLabel.Position = UDim2.new(0, 0, 0, 0)
	mainLabel.BackgroundTransparency = 1
	mainLabel.Text = "🎯 PRACTICE RANGE PORTAL"
	mainLabel.TextColor3 = Color3.new(0, 1, 1)
	mainLabel.TextScaled = true
	mainLabel.Font = Enum.Font.SourceSansBold
	mainLabel.TextStrokeTransparency = 0
	mainLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	mainLabel.Parent = billboard
	
	-- Instructions
	local instructionLabel = Instance.new("TextLabel")
	instructionLabel.Size = UDim2.new(1, 0, 0.25, 0)
	instructionLabel.Position = UDim2.new(0, 0, 0.4, 0)
	instructionLabel.BackgroundTransparency = 1
	instructionLabel.Text = "Walk onto the platform to teleport"
	instructionLabel.TextColor3 = Color3.new(0.8, 0.9, 1)
	instructionLabel.TextScaled = true
	instructionLabel.Font = Enum.Font.SourceSans
	instructionLabel.TextStrokeTransparency = 0
	instructionLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	instructionLabel.Parent = billboard
	
	-- Status display
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, 0, 0.25, 0)
	statusLabel.Position = UDim2.new(0, 0, 0.65, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "⚡ READY FOR TRANSPORT"
	statusLabel.TextColor3 = Color3.new(0, 1, 0)
	statusLabel.TextScaled = true
	statusLabel.Font = Enum.Font.SourceSansBold
	statusLabel.TextStrokeTransparency = 0
	statusLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	statusLabel.Parent = billboard
	
	-- Info display
	local infoLabel = Instance.new("TextLabel")
	infoLabel.Size = UDim2.new(1, 0, 0.1, 0)
	infoLabel.Position = UDim2.new(0, 0, 0.9, 0)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Text = "Enterprise Teleportation System v2.0"
	infoLabel.TextColor3 = Color3.new(0.5, 0.7, 0.8)
	infoLabel.TextScaled = true
	infoLabel.Font = Enum.Font.SourceSansItalic
	infoLabel.TextStrokeTransparency = 0.5
	infoLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	infoLabel.Parent = billboard
	
	return {
		billboard = billboard,
		mainLabel = mainLabel,
		instructionLabel = instructionLabel,
		statusLabel = statusLabel,
		infoLabel = infoLabel
	}
end

-- Setup enterprise touch detection system
function LobbyManager.SetupTouchDetection(touchpadBase, activationPad, statusLabel)
	-- Enhanced touch detection with comprehensive validation
	local function handleTouch(hit, hitPart)
		local character = hit.Parent
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local player = Players:GetPlayerFromCharacter(character)
		
		-- Multi-layer validation
		if not player or not humanoid or not character:FindFirstChild("HumanoidRootPart") then 
			return 
		end
		
		local userId = player.UserId
		local currentTime = tick()
		
		-- Rate limiting check
		if touchpadState.cooldowns[userId] and currentTime - touchpadState.cooldowns[userId] < TOUCHPAD_CONFIG.cooldownTime then
			return -- Still on cooldown
		end
		
		-- Anti-spam protection
		if touchpadState.teleportInProgress[userId] then 
			return 
		end
		
		-- Additional rate limiting using enterprise system
		if not RateLimiter.CheckLimit(player, "TeleportTouchpad", 0.5) then
			statusLabel.Text = "⚠️ RATE LIMITED - WAIT"
			statusLabel.TextColor3 = Color3.new(1, 0.5, 0)
			
			task.spawn(function()
				task.wait(2)
				statusLabel.Text = "⚡ READY FOR TRANSPORT"
				statusLabel.TextColor3 = Color3.new(0, 1, 0)
			end)
			return
		end
		
		-- Set state
		touchpadState.cooldowns[userId] = currentTime
		touchpadState.teleportInProgress[userId] = true
		
		-- Update display
		statusLabel.Text = "🚀 TELEPORTING " .. player.Name:upper() .. "..."
		statusLabel.TextColor3 = Color3.new(1, 1, 0)
		
		-- Execute teleport
		LobbyManager.ExecuteTeleportSequence(player, statusLabel, function()
			touchpadState.teleportInProgress[userId] = false
			statusLabel.Text = "⚡ READY FOR TRANSPORT"
			statusLabel.TextColor3 = Color3.new(0, 1, 0)
		end)
		
		-- Log teleport event
		Logging.Info("LobbyManager", "Touchpad teleport triggered", {
			player = player.Name,
			userId = userId,
			timestamp = currentTime
		})
	end
	
	-- Connect touch events with error handling
	local success1, connection1 = pcall(function()
		return touchpadBase.Touched:Connect(handleTouch)
	end)
	
	local success2, connection2 = pcall(function()
		return activationPad.Touched:Connect(handleTouch)
	end)
	
	if not success1 or not success2 then
		warn("[LobbyManager] Failed to connect touch events")
	end
	
	-- Store connections for cleanup
	touchpadState.activeEffects.connections = {connection1, connection2}
end

-- Initialize advanced animation system
function LobbyManager.InitializeAnimations(activationPad, indicators, displayElements)
	local animations = {}
	
	-- Activation pad pulsing animation
	local padPulse = TweenService:Create(activationPad,
		TweenInfo.new(TOUCHPAD_CONFIG.animationSpeed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{Transparency = 0.1}
	)
	table.insert(animations, padPulse)
	
	-- Light brightness animation
	local lightChild = activationPad:FindFirstChildOfClass("PointLight")
	if lightChild then
		local lightPulse = TweenService:Create(lightChild,
			TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{Brightness = 2}
		)
		table.insert(animations, lightPulse)
	end
	
	-- Text animations
	local textGlow = TweenService:Create(displayElements.mainLabel,
		TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{TextTransparency = 0.2}
	)
	table.insert(animations, textGlow)
	
	-- Start all animations
	for _, animation in ipairs(animations) do
		animation:Play()
	end
	
	-- Advanced indicator rotation system
	task.spawn(function()
		local rotationSpeed = 0.02
		
		while not touchpadState.connectionsCleaned do
			for i, indicator in ipairs(indicators) do
				local baseY = 4.5
				local oscillation = math.sin(tick() * 2 + i) * 0.5
				
				-- Smooth rotation and height oscillation
				indicator.CFrame = CFrame.new(
					indicator.Position.X,
					baseY + oscillation,
					indicator.Position.Z
				) * CFrame.Angles(0, tick() * rotationSpeed * i, 0)
			end
			
			RunService.Heartbeat:Wait()
		end
	end)
	
	-- Store animations for cleanup
	touchpadState.activeEffects.animations = animations
end

-- Execute enterprise teleport sequence with enhanced effects
function LobbyManager.ExecuteTeleportSequence(player, statusLabel, callback)
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
	
	-- Create enhanced teleport VFX
	local teleportEffect = Instance.new("Part")
	teleportEffect.Size = Vector3.new(6, TOUCHPAD_CONFIG.effectHeight, 6)
	teleportEffect.Position = humanoidRootPart.Position
	teleportEffect.Material = Enum.Material.ForceField
	teleportEffect.Color = Color3.new(0, 1, 1)
	teleportEffect.Anchored = true
	teleportEffect.CanCollide = false
	teleportEffect.Shape = Enum.PartType.Cylinder
	teleportEffect.Parent = workspace
	
	-- Add teleport particles
	local teleportParticles = Instance.new("ParticleEmitter")
	teleportParticles.Texture = "rbxassetid://241650934"
	teleportParticles.Lifetime = NumberRange.new(0.5, 1.5)
	teleportParticles.Rate = 100
	teleportParticles.SpreadAngle = Vector2.new(180, 180)
	teleportParticles.Speed = NumberRange.new(10, 20)
	teleportParticles.Color = ColorSequence.new(Color3.new(0, 1, 1))
	teleportParticles.Parent = teleportEffect
	
	-- Professional teleport sound
	local teleportSound = Instance.new("Sound")
	teleportSound.SoundId = "rbxassetid://131961136"
	teleportSound.Volume = 0.4
	teleportSound.Pitch = 1.2
	teleportSound.Parent = teleportEffect
	teleportSound:Play()
	
	-- Enhanced visual effect sequence
	local effectTween1 = TweenService:Create(teleportEffect,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = Vector3.new(12, TOUCHPAD_CONFIG.effectHeight + 5, 12),
			Transparency = 0.5
		}
	)
	
	local effectTween2 = TweenService:Create(teleportEffect,
		TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.3),
		{
			Size = Vector3.new(1, TOUCHPAD_CONFIG.effectHeight + 10, 1),
			Transparency = 1,
			CFrame = teleportEffect.CFrame * CFrame.Angles(0, math.pi * 6, 0)
		}
	)
	
	effectTween1:Play()
	effectTween2:Play()
	
	-- Execute teleport with timing
	task.spawn(function()
		task.wait(0.4) -- Optimal teleport timing
		
		-- Direct teleport execution
		local success = pcall(function()
			local PracticeMapManager = require(game.ServerScriptService.Core:WaitForChild("PracticeMapManager"))
			PracticeMapManager.TeleportToPractice(player)
			
			Logging.Info("LobbyManager", "Enterprise teleport executed", {
				player = player.Name,
				timestamp = tick()
			})
		end)
		
		if not success then
			warn("[LobbyManager] Failed to execute teleport for " .. player.Name)
			statusLabel.Text = "⚠️ TELEPORT FAILED"
			statusLabel.TextColor3 = Color3.new(1, 0, 0)
		end
		
		-- Cleanup effects
		task.wait(0.6)
		teleportParticles.Enabled = false
		task.wait(1)
		teleportEffect:Destroy()
		callback()
	end)
end

-- Create enhanced lobby information display
function LobbyManager.CreateLobbyInfo()
	local welcomeSign = Instance.new("Part")
	welcomeSign.Name = "WelcomeSign"
	welcomeSign.Size = Vector3.new(0.8, 15, 22)
	welcomeSign.Position = Vector3.new(-32, 7.5, 0)
	welcomeSign.Material = Enum.Material.Neon
	welcomeSign.Color = Color3.new(0.05, 0.05, 0.1)
	welcomeSign.Anchored = true
	welcomeSign.Parent = workspace
	
	-- Add welcome display
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.Parent = welcomeSign
	
	local welcomeLabel = Instance.new("TextLabel")
	welcomeLabel.Size = UDim2.new(1, 0, 0.3, 0)
	welcomeLabel.Position = UDim2.new(0, 0, 0.05, 0)
	welcomeLabel.BackgroundTransparency = 1
	welcomeLabel.Text = "🏆 RIVAL CLASH"
	welcomeLabel.TextColor3 = Color3.new(1, 1, 0)
	welcomeLabel.TextScaled = true
	welcomeLabel.Font = Enum.Font.SourceSansBold
	welcomeLabel.Parent = surfaceGui
	
	local infoLabel = Instance.new("TextLabel")
	infoLabel.Size = UDim2.new(1, 0, 0.6, 0)
	infoLabel.Position = UDim2.new(0, 0, 0.35, 0)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Text = "Enterprise FPS System\n\n🎯 Practice Range Available\n⚔️ 6 Weapon Types\n🎪 Target Practice\n🔄 Return Portal\n\n✨ Step on the blue platform\n    to access training!"
	infoLabel.TextColor3 = Color3.new(0.9, 0.9, 1)
	infoLabel.TextScaled = true
	infoLabel.Font = Enum.Font.SourceSans
	infoLabel.TextXAlignment = Enum.TextXAlignment.Left
	infoLabel.Parent = surfaceGui
	
	-- Add sign lighting
	local signLight = Instance.new("PointLight")
	signLight.Color = Color3.new(1, 1, 0)
	signLight.Brightness = 4
	signLight.Range = 25
	signLight.Parent = welcomeSign
	
	Logging.Info("LobbyManager", "Enhanced lobby information display created")
end

-- Cleanup touchpad system
function LobbyManager.CleanupTouchpadSystem()
	touchpadState.connectionsCleaned = true
	
	-- Disconnect touch events
	if touchpadState.activeEffects.connections then
		for _, connection in ipairs(touchpadState.activeEffects.connections) do
			if connection then
				connection:Disconnect()
			end
		end
	end
	
	-- Stop animations
	if touchpadState.activeEffects.animations then
		for _, animation in ipairs(touchpadState.activeEffects.animations) do
			if animation then
				animation:Cancel()
			end
		end
	end
	
	print("[LobbyManager] 🧹 Touchpad system cleaned up")
end

-- Create enterprise-level practice teleport touchpad
function LobbyManager.CreatePracticeTeleportTouchpad()
	print("[LobbyManager] 🚀 Creating enterprise touchpad teleportation system...")
	
	-- Ensure spawn location exists
	LobbyManager.EnsureSpawnLocation()
	
	-- Create touchpad base platform
	local touchpadBase = LobbyManager.CreateTouchpadBase()
	
	-- Create activation pad
	local activationPad = LobbyManager.CreateActivationPad()
	
	-- Create visual indicators
	local indicators = LobbyManager.CreateVisualIndicators()
	
	-- Create holographic display
	local displayElements = LobbyManager.CreateHolographicDisplay(activationPad)
	
	-- Setup enterprise touch system
	LobbyManager.SetupTouchDetection(touchpadBase, activationPad, displayElements.statusLabel)
	
	-- Initialize animations
	LobbyManager.InitializeAnimations(activationPad, indicators, displayElements)
	
	-- Setup cleanup on server shutdown
	game.BindToClose(function()
		LobbyManager.CleanupTouchpadSystem()
	end)
	
	Logging.Info("LobbyManager", "Enterprise touchpad system initialized", {
		position = TOUCHPAD_CONFIG.position,
		cooldownTime = TOUCHPAD_CONFIG.cooldownTime
	})
	
	return {
		base = touchpadBase,
		activation = activationPad,
		indicators = indicators,
		display = displayElements
	}
end

-- Initialize enterprise lobby system
function LobbyManager.Initialize()
	print("[LobbyManager] 🏢 Initializing Enterprise Lobby System...")
	
	-- Create enterprise touchpad system
	LobbyManager.CreatePracticeTeleportTouchpad()
	
	-- Create enhanced lobby info
	LobbyManager.CreateLobbyInfo()
	
	-- Handle player spawning with welcome system
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			-- Brief delay for character to fully load
			task.wait(1.5)
			
			-- Send enterprise welcome message
			local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
			local UIEvents = RemoteRoot:WaitForChild("UIEvents")
			local notificationRemote = UIEvents:FindFirstChild("ShowNotification")
			
			if notificationRemote then
				notificationRemote:FireClient(player, 
					"🎯 Welcome to Rival Clash Enterprise! Step on the blue teleportation platform to access the Practice Range.", 
					"info", 6)
			end
			
			Logging.Info("LobbyManager", "Player welcomed to enterprise lobby", {
				player = player.Name,
				userId = player.UserId
			})
		end)
	end)
	
	Logging.Info("LobbyManager", "Enterprise lobby system fully initialized")
	print("[LobbyManager] ✅ Enterprise Lobby System Online!")
end

-- Auto-initialize lobby system
LobbyManager.Initialize()

return LobbyManager
