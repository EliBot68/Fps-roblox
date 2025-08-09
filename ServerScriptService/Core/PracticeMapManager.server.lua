-- PracticeMapManager.server.lua
-- Practice map system with weapon selection and target dummies

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)
local Logging = require(ReplicatedStorage.Shared.Logging)

local PracticeMapManager = {}

-- Practice map configuration with proper spatial separation
local PRACTICE_CONFIG = {
	-- Practice arena is 1000 studs away from main spawn to avoid conflicts
	mapSize = Vector3.new(300, 10, 400),
	spawnPosition = Vector3.new(1000, 50, 1000), -- FAR from main spawn (0,0,0)
	weaponPadSpacing = 20,
	-- Target dummies positioned in practice arena space
	dummyPositions = {
		Vector3.new(1000, 55, 1150),      -- Forward center
		Vector3.new(980, 55, 1180),       -- Forward left
		Vector3.new(1020, 55, 1180),      -- Forward right
		Vector3.new(1000, 55, 1200)       -- Far forward
	},
	-- Return portal positioned in practice arena
	returnPortalPosition = Vector3.new(950, 60, 1000)
}

-- Active practice sessions
local practiceSessions = {}

-- Create practice map structure
function PracticeMapManager.CreatePracticeMap()
	local practiceMap = Instance.new("Folder")
	practiceMap.Name = "PracticeMap"
	practiceMap.Parent = workspace
	
	-- Create main practice ground platform (far from spawn)
	local ground = Instance.new("Part")
	ground.Name = "PracticeGround"
	ground.Size = PRACTICE_CONFIG.mapSize
	ground.Position = Vector3.new(1000, 40, 1100) -- Centered in practice area
	ground.Material = Enum.Material.Concrete
	ground.Color = Color3.new(0.2, 0.3, 0.2) -- Dark green for practice
	ground.Anchored = true
	ground.Parent = practiceMap
	
	-- Create practice spawn platform
	local spawnPlatform = Instance.new("Part")
	spawnPlatform.Name = "PracticeSpawn"
	spawnPlatform.Size = Vector3.new(25, 3, 25)
	spawnPlatform.Position = PRACTICE_CONFIG.spawnPosition
	spawnPlatform.Material = Enum.Material.Neon
	spawnPlatform.Color = Color3.new(0, 1, 0) -- Green spawn indicator
	spawnPlatform.Anchored = true
	spawnPlatform.Parent = practiceMap
	
	-- Create spawn point for teleported players
	local spawnPoint = Instance.new("SpawnLocation")
	spawnPoint.Name = "PracticeSpawnLocation"
	spawnPoint.Size = Vector3.new(6, 1, 6)
	spawnPoint.Position = PRACTICE_CONFIG.spawnPosition + Vector3.new(0, 3, 0)
	spawnPoint.Material = Enum.Material.ForceField
	spawnPoint.BrickColor = BrickColor.new("Bright green")
	spawnPoint.Anchored = true
	spawnPoint.CanCollide = false
	spawnPoint.Enabled = false -- Disable automatic spawning here
	spawnPoint.Parent = practiceMap
	
	-- Add boundaries to prevent players from falling
	PracticeMapManager.CreateBoundaries(practiceMap)
	
	-- Create weapon selection pads
	PracticeMapManager.CreateWeaponPads(practiceMap)
	
	-- Create target dummies
	PracticeMapManager.CreateTargetDummies(practiceMap)
	
	-- Create return portal
	PracticeMapManager.CreateReturnPortal(practiceMap)
	
	Logging.Info("PracticeMapManager", "Practice map created at coordinates (1000, 50, 1000)")
	return practiceMap
end

-- Create boundaries to prevent players from falling off practice area
function PracticeMapManager.CreateBoundaries(practiceMap)
	local boundariesFolder = Instance.new("Folder")
	boundariesFolder.Name = "Boundaries"
	boundariesFolder.Parent = practiceMap
	
	-- Create invisible walls around practice area
	local boundaryPositions = {
		{pos = Vector3.new(850, 60, 1100), size = Vector3.new(10, 50, 400)}, -- Left wall
		{pos = Vector3.new(1150, 60, 1100), size = Vector3.new(10, 50, 400)}, -- Right wall
		{pos = Vector3.new(1000, 60, 900), size = Vector3.new(300, 50, 10)}, -- Back wall
		{pos = Vector3.new(1000, 60, 1300), size = Vector3.new(300, 50, 10)} -- Front wall
	}
	
	for i, boundary in ipairs(boundaryPositions) do
		local wall = Instance.new("Part")
		wall.Name = "Boundary" .. i
		wall.Size = boundary.size
		wall.Position = boundary.pos
		wall.Material = Enum.Material.ForceField
		wall.Transparency = 0.8
		wall.CanCollide = true
		wall.Anchored = true
		wall.Color = Color3.new(1, 0, 0) -- Red tint to indicate boundary
		wall.Parent = boundariesFolder
	end
end

-- Create weapon selection touchpads in practice area
function PracticeMapManager.CreateWeaponPads(practiceMap)
	local weaponPadsFolder = Instance.new("Folder")
	weaponPadsFolder.Name = "WeaponPads"
	weaponPadsFolder.Parent = practiceMap
	
	local weapons = {"AssaultRifle", "SMG", "Shotgun", "Sniper", "Pistol", "BurstRifle"}
	local padColors = {
		AssaultRifle = Color3.new(0.8, 0.4, 0.2), -- Orange
		SMG = Color3.new(1, 1, 0), -- Yellow
		Shotgun = Color3.new(1, 0, 0), -- Red
		Sniper = Color3.new(0, 0, 1), -- Blue
		Pistol = Color3.new(0.5, 0.5, 0.5), -- Gray
		BurstRifle = Color3.new(0.8, 0, 0.8) -- Purple
	}
	
	for i, weaponId in ipairs(weapons) do
		local weapon = WeaponConfig[weaponId]
		if not weapon then continue end
		
		-- Position weapon pads in a line in front of practice spawn
		local xOffset = (i - 3.5) * PRACTICE_CONFIG.weaponPadSpacing
		local position = Vector3.new(1000 + xOffset, 46, 970) -- In practice area, south of spawn
		
		-- Create weapon pad
		local weaponPad = Instance.new("Part")
		weaponPad.Name = weaponId .. "Pad"
		weaponPad.Size = Vector3.new(12, 2, 12)
		weaponPad.Position = position
		weaponPad.Material = Enum.Material.Neon
		weaponPad.Color = padColors[weaponId] or Color3.new(1, 1, 1)
		weaponPad.Anchored = true
		weaponPad.Parent = weaponPadsFolder
		
		-- Add glow effect
		local pointLight = Instance.new("PointLight")
		pointLight.Color = weaponPad.Color
		pointLight.Brightness = 2
		pointLight.Range = 15
		pointLight.Parent = weaponPad
		
		-- Create weapon name label
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.new(0, 200, 0, 50)
		billboard.StudsOffset = Vector3.new(0, 3, 0)
		billboard.Parent = weaponPad
		
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = weapon.Name
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextScaled = true
		label.Font = Enum.Font.SourceSansBold
		label.TextStrokeTransparency = 0
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.Parent = billboard
		
		-- Add touch detection
		local detector = Instance.new("Part")
		detector.Name = "TouchDetector"
		detector.Size = Vector3.new(10, 8, 10)
		detector.Position = position + Vector3.new(0, 4, 0)
		detector.Material = Enum.Material.ForceField
		detector.Transparency = 0.8
		detector.CanCollide = false
		detector.Anchored = true
		detector.Parent = weaponPad
		
		-- Connect touch event
		detector.Touched:Connect(function(hit)
			local character = hit.Parent
			local humanoid = character:FindFirstChild("Humanoid")
			local player = Players:GetPlayerFromCharacter(character)
			
			if player and humanoid then
				PracticeMapManager.GiveWeapon(player, weaponId)
			end
		end)
		
		-- Add pulsing animation
		local pulseTween = TweenService:Create(weaponPad, 
			TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{Transparency = 0.3}
		)
		pulseTween:Play()
	end
end

-- Create target dummies for shooting practice
function PracticeMapManager.CreateTargetDummies(practiceMap)
	local dummiesFolder = Instance.new("Folder")
	dummiesFolder.Name = "TargetDummies"
	dummiesFolder.Parent = practiceMap
	
	for i, position in ipairs(PRACTICE_CONFIG.dummyPositions) do
		local dummy = PracticeMapManager.CreateSingleDummy(position, "Dummy" .. i)
		dummy.Parent = dummiesFolder
	end
end

-- Create a single target dummy
function PracticeMapManager.CreateSingleDummy(position, name)
	local dummy = Instance.new("Model")
	dummy.Name = name
	
	-- Create dummy body parts
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Position = position
	torso.Material = Enum.Material.Plastic
	torso.Color = Color3.new(1, 0.8, 0.6) -- Skin color
	torso.Anchored = true
	torso.Parent = dummy
	
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.5, 1.5, 1.5)
	head.Position = position + Vector3.new(0, 1.75, 0)
	head.Material = Enum.Material.Plastic
	head.Color = Color3.new(1, 0.8, 0.6)
	head.Shape = Enum.PartType.Ball
	head.Anchored = true
	head.Parent = dummy
	
	-- Add face
	local face = Instance.new("Decal")
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head
	
	-- Create arms
	local leftArm = Instance.new("Part")
	leftArm.Name = "Left Arm"
	leftArm.Size = Vector3.new(1, 2, 1)
	leftArm.Position = position + Vector3.new(-1.5, 0, 0)
	leftArm.Material = Enum.Material.Plastic
	leftArm.Color = Color3.new(1, 0.8, 0.6)
	leftArm.Anchored = true
	leftArm.Parent = dummy
	
	local rightArm = Instance.new("Part")
	rightArm.Name = "Right Arm"
	rightArm.Size = Vector3.new(1, 2, 1)
	rightArm.Position = position + Vector3.new(1.5, 0, 0)
	rightArm.Material = Enum.Material.Plastic
	rightArm.Color = Color3.new(1, 0.8, 0.6)
	rightArm.Anchored = true
	rightArm.Parent = dummy
	
	-- Create legs
	local leftLeg = Instance.new("Part")
	leftLeg.Name = "Left Leg"
	leftLeg.Size = Vector3.new(1, 2, 1)
	leftLeg.Position = position + Vector3.new(-0.5, -2, 0)
	leftLeg.Material = Enum.Material.Plastic
	leftLeg.Color = Color3.new(0, 0, 1) -- Blue pants
	leftLeg.Anchored = true
	leftLeg.Parent = dummy
	
	local rightLeg = Instance.new("Part")
	rightLeg.Name = "Right Leg"
	rightLeg.Size = Vector3.new(1, 2, 1)
	rightLeg.Position = position + Vector3.new(0.5, -2, 0)
	rightLeg.Material = Enum.Material.Plastic
	rightLeg.Color = Color3.new(0, 0, 1)
	rightLeg.Anchored = true
	rightLeg.Parent = dummy
	
	-- Add humanoid for hit detection
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 1000
	humanoid.Health = 1000
	humanoid.PlatformStand = true
	humanoid.Parent = dummy
	
	-- Add target indicator
	local targetIndicator = Instance.new("BillboardGui")
	targetIndicator.Size = UDim2.new(0, 100, 0, 30)
	targetIndicator.StudsOffset = Vector3.new(0, 3, 0)
	targetIndicator.Parent = head
	
	local targetLabel = Instance.new("TextLabel")
	targetLabel.Size = UDim2.new(1, 0, 1, 0)
	targetLabel.BackgroundColor3 = Color3.new(1, 0, 0)
	targetLabel.BackgroundTransparency = 0.3
	targetLabel.Text = "TARGET"
	targetLabel.TextColor3 = Color3.new(1, 1, 1)
	targetLabel.TextScaled = true
	targetLabel.Font = Enum.Font.SourceSansBold
	targetLabel.Parent = targetIndicator
	
	-- Add hit effect when damaged
	humanoid.HealthChanged:Connect(function(health)
		if health < humanoid.MaxHealth then
			-- Flash red when hit
			for _, part in pairs(dummy:GetChildren()) do
				if part:IsA("Part") then
					local originalColor = part.Color
					part.Color = Color3.new(1, 0, 0)
					
					task.spawn(function()
						task.wait(0.1)
						part.Color = originalColor
					end)
				end
			end
			
			-- Reset health after a moment
			task.spawn(function()
				task.wait(2)
				humanoid.Health = humanoid.MaxHealth
			end)
		end
	end)
	
	return dummy
end

-- Create return portal to main spawn
function PracticeMapManager.CreateReturnPortal(practiceMap)
	local portal = Instance.new("Part")
	portal.Name = "ReturnPortal"
	portal.Size = Vector3.new(8, 15, 2)
	portal.Position = PRACTICE_CONFIG.returnPortalPosition
	portal.Material = Enum.Material.ForceField
	portal.Color = Color3.new(0, 1, 1) -- Cyan
	portal.Anchored = true
	portal.CanCollide = false
	portal.Parent = practiceMap
	
	-- Add swirling effect
	local swirTween = TweenService:Create(portal,
		TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
		{Rotation = Vector3.new(0, 360, 0)}
	)
	swirTween:Play()
	
	-- Add portal label
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.Parent = portal
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "RETURN TO LOBBY"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.SourceSansBold
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Parent = billboard
	
	-- Touch detection for return
	portal.Touched:Connect(function(hit)
		local character = hit.Parent
		local humanoid = character:FindFirstChild("Humanoid")
		local player = Players:GetPlayerFromCharacter(character)
		
		if player and humanoid then
			PracticeMapManager.ReturnToLobby(player)
		end
	end)
end

-- Give weapon to player
function PracticeMapManager.GiveWeapon(player, weaponId)
	-- Send weapon change to combat system
	local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
	local CombatEvents = RemoteRoot:WaitForChild("CombatEvents")
	local switchWeaponRemote = CombatEvents:FindFirstChild("SwitchWeapon")
	
	if switchWeaponRemote then
		-- Simulate weapon switch
		switchWeaponRemote:FireServer(weaponId)
	end
	
	-- Visual feedback
	local weapon = WeaponConfig[weaponId]
	if weapon then
		-- Send notification to player
		local UIEvents = RemoteRoot:WaitForChild("UIEvents")
		local notificationRemote = UIEvents:FindFirstChild("ShowNotification")
		if notificationRemote then
			notificationRemote:FireClient(player, "Equipped " .. weapon.Name, "success", 2)
		end
	end
	
	Logging.Info("PracticeMapManager", player.Name .. " equipped " .. weaponId)
end

-- Teleport player to practice map
function PracticeMapManager.TeleportToPractice(player)
	if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
		return false
	end
	
	-- Create practice session
	practiceSessions[player.UserId] = {
		player = player,
		startTime = os.time(),
		shots = 0,
		hits = 0
	}
	
	-- Teleport player to practice area (far from main spawn)
	local humanoidRootPart = player.Character.HumanoidRootPart
	humanoidRootPart.CFrame = CFrame.new(PRACTICE_CONFIG.spawnPosition + Vector3.new(0, 5, 0))
	
	-- Send welcome message
	local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
	local UIEvents = RemoteRoot:WaitForChild("UIEvents")
	local notificationRemote = UIEvents:FindFirstChild("ShowNotification")
	if notificationRemote then
		notificationRemote:FireClient(player, "🎯 Welcome to Practice Range!", "Walk on colored pads to select weapons. Shoot the dummies!", 5)
	end
	
	Logging.Info("PracticeMapManager", player.Name .. " teleported to practice area at (1000, 55, 1000)")
	return true
end

-- Return player to main lobby spawn
function PracticeMapManager.ReturnToLobby(player)
	if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
		return false
	end
	
	-- End practice session
	local session = practiceSessions[player.UserId]
	if session then
		local duration = os.time() - session.startTime
		local accuracy = session.shots > 0 and (session.hits / session.shots * 100) or 0
		
		-- Send session summary
		local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
		local UIEvents = RemoteRoot:WaitForChild("UIEvents")
		local notificationRemote = UIEvents:FindFirstChild("ShowNotification")
		if notificationRemote then
			notificationRemote:FireClient(player, 
				string.format("🏆 Practice Complete! Accuracy: %.1f%% | Time: %ds", accuracy, duration), 
				"success", 5)
		end
		
		practiceSessions[player.UserId] = nil
	end
	
	-- Teleport back to main spawn area (0, 0, 0 region)
	local humanoidRootPart = player.Character.HumanoidRootPart
	local spawnLocation = workspace:FindFirstChild("SpawnLocation") 
	if spawnLocation then
		humanoidRootPart.CFrame = spawnLocation.CFrame + Vector3.new(math.random(-15, 15), 8, math.random(-15, 15))
	else
		-- Default main spawn position if no SpawnLocation found
		humanoidRootPart.CFrame = CFrame.new(math.random(-20, 20), 10, math.random(-20, 20))
	end
	
	Logging.Info("PracticeMapManager", player.Name .. " returned to main lobby spawn")
	return true
end

-- Initialize practice map system
function PracticeMapManager.Initialize()
	-- Create the practice map
	PracticeMapManager.CreatePracticeMap()
	
	-- Set up RemoteEvents for practice map
	local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
	
	-- Create practice map events folder if it doesn't exist
	local practiceEvents = RemoteRoot:FindFirstChild("PracticeEvents")
	if not practiceEvents then
		practiceEvents = Instance.new("Folder")
		practiceEvents.Name = "PracticeEvents"
		practiceEvents.Parent = RemoteRoot
	end
	
	-- Create teleport to practice remote
	local teleportToPracticeRemote = practiceEvents:FindFirstChild("TeleportToPractice")
	if not teleportToPracticeRemote then
		teleportToPracticeRemote = Instance.new("RemoteEvent")
		teleportToPracticeRemote.Name = "TeleportToPractice"
		teleportToPracticeRemote.Parent = practiceEvents
	end
	
	-- Create teleport to lobby remote
	local teleportToLobbyRemote = practiceEvents:FindFirstChild("TeleportToLobby")
	if not teleportToLobbyRemote then
		teleportToLobbyRemote = Instance.new("RemoteEvent")
		teleportToLobbyRemote.Name = "TeleportToLobby"
		teleportToLobbyRemote.Parent = practiceEvents
	end
	
	-- Create select weapon remote
	local selectWeaponRemote = practiceEvents:FindFirstChild("SelectWeapon")
	if not selectWeaponRemote then
		selectWeaponRemote = Instance.new("RemoteEvent")
		selectWeaponRemote.Name = "SelectWeapon"
		selectWeaponRemote.Parent = practiceEvents
	end
	
	-- Connect teleport to practice event
	teleportToPracticeRemote.OnServerEvent:Connect(function(player)
		PracticeMapManager.TeleportToPractice(player)
	end)
	
	-- Connect teleport to lobby event
	teleportToLobbyRemote.OnServerEvent:Connect(function(player)
		PracticeMapManager.ReturnToLobby(player)
	end)
	
	-- Connect weapon selection event
	selectWeaponRemote.OnServerEvent:Connect(function(player, weaponId)
		PracticeMapManager.GiveWeapon(player, weaponId)
	end)
	
	Logging.Info("PracticeMapManager", "Practice map system initialized")
end

-- Start the practice map manager
PracticeMapManager.Initialize()

return PracticeMapManager
