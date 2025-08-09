-- Spectator.client.lua
-- Enhanced spectator mode with camera controls

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
local SpectatorRemote = RemoteRoot:WaitForChild("SpectatorRemote")

local spectatorMode = false
local currentTarget = nil
local spectatingPlayers = {}
local currentIndex = 1

local gui = Instance.new("ScreenGui")
gui.Name = "SpectatorUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local controlsFrame = Instance.new("Frame")
controlsFrame.Name = "SpectatorControls"
controlsFrame.Size = UDim2.new(0,300,0,60)
controlsFrame.Position = UDim2.new(0.5,-150,0,10)
controlsFrame.BackgroundColor3 = Color3.fromRGB(0,0,0)
controlsFrame.BackgroundTransparency = 0.5
controlsFrame.BorderSizePixel = 0
controlsFrame.Visible = false
controlsFrame.Parent = gui

local targetLabel = Instance.new("TextLabel")
targetLabel.Text = "Spectating: None"
targetLabel.Size = UDim2.new(1,0,0.5,0)
targetLabel.BackgroundTransparency = 1
targetLabel.TextColor3 = Color3.fromRGB(255,255,255)
targetLabel.Font = Enum.Font.GothamBold
targetLabel.TextSize = 16
targetLabel.Parent = controlsFrame

local instructionLabel = Instance.new("TextLabel")
instructionLabel.Text = "Left/Right Arrow: Switch Target | F: Exit Spectator"
instructionLabel.Size = UDim2.new(1,0,0.5,0)
instructionLabel.Position = UDim2.new(0,0,0.5,0)
instructionLabel.BackgroundTransparency = 1
instructionLabel.TextColor3 = Color3.fromRGB(200,200,200)
instructionLabel.Font = Enum.Font.Gotham
instructionLabel.TextSize = 12
targetLabel.Parent = controlsFrame

local function updateSpectatorList()
	spectatingPlayers = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			table.insert(spectatingPlayers, p)
		end
	end
end

local function setSpectatorTarget(targetPlayer)
	currentTarget = targetPlayer
	if targetPlayer then
		targetLabel.Text = "Spectating: " .. targetPlayer.Name
		
		-- Set camera to follow target
		if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
			camera.CameraSubject = targetPlayer.Character.Humanoid
			camera.CameraType = Enum.CameraType.Custom
		end
	else
		targetLabel.Text = "Spectating: None"
		camera.CameraSubject = player.Character and player.Character.Humanoid
	end
end

local function nextTarget()
	updateSpectatorList()
	if #spectatingPlayers == 0 then
		setSpectatorTarget(nil)
		return
	end
	
	currentIndex = currentIndex + 1
	if currentIndex > #spectatingPlayers then
		currentIndex = 1
	end
	
	setSpectatorTarget(spectatingPlayers[currentIndex])
end

local function previousTarget()
	updateSpectatorList()
	if #spectatingPlayers == 0 then
		setSpectatorTarget(nil)
		return
	end
	
	currentIndex = currentIndex - 1
	if currentIndex < 1 then
		currentIndex = #spectatingPlayers
	end
	
	setSpectatorTarget(spectatingPlayers[currentIndex])
end

local function enterSpectatorMode()
	spectatorMode = true
	controlsFrame.Visible = true
	
	-- Hide player character
	if player.Character then
		for _, part in ipairs(player.Character:GetChildren()) do
			if part:IsA("BasePart") then
				part.Transparency = 1
			elseif part:IsA("Accessory") then
				for _, accessoryPart in ipairs(part:GetChildren()) do
					if accessoryPart:IsA("BasePart") then
						accessoryPart.Transparency = 1
					end
				end
			end
		end
	end
	
	updateSpectatorList()
	if #spectatingPlayers > 0 then
		currentIndex = 1
		setSpectatorTarget(spectatingPlayers[currentIndex])
	end
end

local function exitSpectatorMode()
	spectatorMode = false
	controlsFrame.Visible = false
	currentTarget = nil
	
	-- Restore player character visibility
	if player.Character then
		for _, part in ipairs(player.Character:GetChildren()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				part.Transparency = 0
			elseif part:IsA("Accessory") then
				for _, accessoryPart in ipairs(part:GetChildren()) do
					if accessoryPart:IsA("BasePart") then
						accessoryPart.Transparency = 0
					end
				end
			end
		end
	end
	
	-- Reset camera
	camera.CameraSubject = player.Character and player.Character.Humanoid
	camera.CameraType = Enum.CameraType.Custom
end

-- Input handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.F then
		if not spectatorMode then
			-- Check if player is dead before entering spectator mode
			if not player.Character or not player.Character:FindFirstChild("Humanoid") or 
			   player.Character.Humanoid.Health <= 0 then
				enterSpectatorMode()
			end
		else
			exitSpectatorMode()
		end
	elseif spectatorMode then
		if input.KeyCode == Enum.KeyCode.Right then
			nextTarget()
		elseif input.KeyCode == Enum.KeyCode.Left then
			previousTarget()
		end
	end
end)

-- Auto-enter spectator when dead
player.CharacterAdded:Connect(function(character)
	if spectatorMode then
		exitSpectatorMode()
	end
	
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Died:Connect(function()
		wait(2) -- Brief delay before auto-spectating
		if not player.Character or player.Character.Humanoid.Health <= 0 then
			enterSpectatorMode()
		end
	end)
end)

-- Handle spectator list updates
Players.PlayerAdded:Connect(updateSpectatorList)
Players.PlayerRemoving:Connect(function(removedPlayer)
	if currentTarget == removedPlayer then
		nextTarget()
	end
	updateSpectatorList()
end)

-- Camera smoothing when spectating
local cameraConnection
local function updateCamera()
	if spectatorMode and currentTarget and currentTarget.Character then
		local targetHead = currentTarget.Character:FindFirstChild("Head")
		if targetHead then
			-- Smooth camera follow with slight offset
			local targetPosition = targetHead.Position + Vector3.new(0, 2, 5)
			camera.CFrame = camera.CFrame:Lerp(
				CFrame.lookAt(targetPosition, targetHead.Position),
				0.1
			)
		end
	end
end

RunService.Heartbeat:Connect(updateCamera)
