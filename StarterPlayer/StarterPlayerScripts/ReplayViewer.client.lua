-- ReplayViewer.client.lua
-- Replay playback and viewing system

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
local ReplayRemote = RemoteRoot:WaitForChild("ReplayRemote")

local replayMode = false
local replayData = nil
local currentFrame = 1
local playbackSpeed = 1
local isPlaying = false
local replayPlayers = {}

local gui = Instance.new("ScreenGui")
gui.Name = "ReplayUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local controlFrame = Instance.new("Frame")
controlFrame.Name = "ReplayControls"
controlFrame.Size = UDim2.new(0,500,0,80)
controlFrame.Position = UDim2.new(0.5,-250,1,-90)
controlFrame.BackgroundColor3 = Color3.fromRGB(20,20,20)
controlFrame.BackgroundTransparency = 0.2
controlFrame.BorderSizePixel = 0
controlFrame.Visible = false
controlFrame.Parent = gui

local progressBar = Instance.new("Frame")
progressBar.Name = "ProgressBar"
progressBar.Size = UDim2.new(1,-20,0,6)
progressBar.Position = UDim2.new(0,10,0,10)
progressBar.BackgroundColor3 = Color3.fromRGB(60,60,60)
progressBar.BorderSizePixel = 0
progressBar.Parent = controlFrame

local progressFill = Instance.new("Frame")
progressFill.Name = "ProgressFill"
progressFill.Size = UDim2.new(0,0,1,0)
progressFill.BackgroundColor3 = Color3.fromRGB(100,150,255)
progressFill.BorderSizePixel = 0
progressFill.Parent = progressBar

local timeLabel = Instance.new("TextLabel")
timeLabel.Text = "00:00 / 00:00"
timeLabel.Size = UDim2.new(0,100,0,20)
timeLabel.Position = UDim2.new(0,10,0,20)
timeLabel.BackgroundTransparency = 1
timeLabel.TextColor3 = Color3.fromRGB(255,255,255)
timeLabel.Font = Enum.Font.Gotham
timeLabel.TextSize = 12
timeLabel.TextXAlignment = Enum.TextXAlignment.Left
timeLabel.Parent = controlFrame

local playButton = Instance.new("TextButton")
playButton.Text = "▶"
playButton.Size = UDim2.new(0,40,0,30)
playButton.Position = UDim2.new(0,10,0,45)
playButton.BackgroundColor3 = Color3.fromRGB(50,150,50)
playButton.TextColor3 = Color3.fromRGB(255,255,255)
playButton.Font = Enum.Font.GothamBold
playButton.TextSize = 16
playButton.Parent = controlFrame

local pauseButton = Instance.new("TextButton")
pauseButton.Text = "⏸"
pauseButton.Size = UDim2.new(0,40,0,30)
pauseButton.Position = UDim2.new(0,55,0,45)
pauseButton.BackgroundColor3 = Color3.fromRGB(150,150,50)
pauseButton.TextColor3 = Color3.fromRGB(255,255,255)
pauseButton.Font = Enum.Font.GothamBold
pauseButton.TextSize = 16
pauseButton.Parent = controlFrame

local speedLabel = Instance.new("TextLabel")
speedLabel.Text = "Speed: 1.0x"
speedLabel.Size = UDim2.new(0,100,0,20)
speedLabel.Position = UDim2.new(0,110,0,50)
speedLabel.BackgroundTransparency = 1
speedLabel.TextColor3 = Color3.fromRGB(255,255,255)
speedLabel.Font = Enum.Font.Gotham
speedLabel.TextSize = 12
speedLabel.Parent = controlFrame

local fasterButton = Instance.new("TextButton")
fasterButton.Text = "+"
fasterButton.Size = UDim2.new(0,25,0,25)
fasterButton.Position = UDim2.new(0,220,0,50)
fasterButton.BackgroundColor3 = Color3.fromRGB(100,100,100)
fasterButton.TextColor3 = Color3.fromRGB(255,255,255)
fasterButton.Font = Enum.Font.GothamBold
fasterButton.TextSize = 14
fasterButton.Parent = controlFrame

local slowerButton = Instance.new("TextButton")
slowerButton.Text = "-"
slowerButton.Size = UDim2.new(0,25,0,25)
slowerButton.Position = UDim2.new(0,250,0,50)
slowerButton.BackgroundColor3 = Color3.fromRGB(100,100,100)
slowerButton.TextColor3 = Color3.fromRGB(255,255,255)
slowerButton.Font = Enum.Font.GothamBold
slowerButton.TextSize = 14
slowerButton.Parent = controlFrame

local exitButton = Instance.new("TextButton")
exitButton.Text = "Exit Replay"
exitButton.Size = UDim2.new(0,80,0,30)
exitButton.Position = UDim2.new(1,-90,0,45)
exitButton.BackgroundColor3 = Color3.fromRGB(150,50,50)
exitButton.TextColor3 = Color3.fromRGB(255,255,255)
exitButton.Font = Enum.Font.GothamBold
exitButton.TextSize = 12
exitButton.Parent = controlFrame

local function formatTime(seconds)
	local mins = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%02d:%02d", mins, secs)
end

local function createReplayCharacter(playerName, data)
	local character = Instance.new("Model")
	character.Name = playerName .. "_Replay"
	character.Parent = workspace
	
	-- Create basic humanoid structure
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character
	
	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = Vector3.new(2,2,1)
	rootPart.CanCollide = false
	rootPart.Transparency = 1
	rootPart.Parent = character
	
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2,1,1)
	head.CanCollide = false
	head.BrickColor = BrickColor.new("Light orange")
	head.TopSurface = Enum.SurfaceType.Smooth
	head.BottomSurface = Enum.SurfaceType.Smooth
	head.Parent = character
	
	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = rootPart
	headWeld.Part1 = head
	headWeld.Parent = rootPart
	
	-- Add player name display
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0,100,0,25)
	billboard.StudsOffset = Vector3.new(0,2,0)
	billboard.Parent = head
	
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Text = playerName
	nameLabel.Size = UDim2.new(1,0,1,0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(255,255,255)
	nameLabel.TextStrokeTransparency = 0
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 14
	nameLabel.Parent = billboard
	
	replayPlayers[playerName] = {
		character = character,
		rootPart = rootPart,
		head = head
	}
	
	return character
end

local function updateReplayFrame()
	if not replayData or not replayData.frames then return end
	
	local frame = replayData.frames[currentFrame]
	if not frame then return end
	
	-- Update each player's position
	for playerName, positionData in pairs(frame.positions) do
		local replayPlayer = replayPlayers[playerName]
		if not replayPlayer then
			createReplayCharacter(playerName, positionData)
			replayPlayer = replayPlayers[playerName]
		end
		
		if replayPlayer and replayPlayer.rootPart then
			replayPlayer.rootPart.CFrame = CFrame.new(
				positionData.position.X or 0,
				positionData.position.Y or 0, 
				positionData.position.Z or 0
			) * CFrame.Angles(
				math.rad(positionData.rotation.X or 0),
				math.rad(positionData.rotation.Y or 0),
				math.rad(positionData.rotation.Z or 0)
			)
		end
	end
	
	-- Update progress bar
	local progress = currentFrame / #replayData.frames
	progressFill.Size = UDim2.new(progress, 0, 1, 0)
	
	-- Update time display
	local currentTime = (currentFrame - 1) * 0.1 -- Assuming 10 FPS recording
	local totalTime = (#replayData.frames - 1) * 0.1
	timeLabel.Text = formatTime(currentTime) .. " / " .. formatTime(totalTime)
end

local function clearReplayCharacters()
	for _, replayPlayer in pairs(replayPlayers) do
		if replayPlayer.character then
			replayPlayer.character:Destroy()
		end
	end
	replayPlayers = {}
end

local function startReplay(data)
	replayMode = true
	replayData = data
	currentFrame = 1
	isPlaying = false
	
	controlFrame.Visible = true
	
	-- Hide live players
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			for _, part in ipairs(p.Character:GetChildren()) do
				if part:IsA("BasePart") then
					part.Transparency = 1
				end
			end
		end
	end
	
	updateReplayFrame()
end

local function endReplay()
	replayMode = false
	replayData = nil
	isPlaying = false
	
	controlFrame.Visible = false
	clearReplayCharacters()
	
	-- Restore live players
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			for _, part in ipairs(p.Character:GetChildren()) do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					part.Transparency = 0
				end
			end
		end
	end
end

-- Control handlers
playButton.MouseButton1Click:Connect(function()
	isPlaying = true
end)

pauseButton.MouseButton1Click:Connect(function()
	isPlaying = false
end)

fasterButton.MouseButton1Click:Connect(function()
	playbackSpeed = math.min(playbackSpeed * 2, 4)
	speedLabel.Text = "Speed: " .. playbackSpeed .. "x"
end)

slowerButton.MouseButton1Click:Connect(function()
	playbackSpeed = math.max(playbackSpeed / 2, 0.25)
	speedLabel.Text = "Speed: " .. playbackSpeed .. "x"
end)

exitButton.MouseButton1Click:Connect(function()
	endReplay()
end)

-- Progress bar click handling
progressBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 and replayData then
		local mouse = Players.LocalPlayer:GetMouse()
		local relativeX = (mouse.X - progressBar.AbsolutePosition.X) / progressBar.AbsoluteSize.X
		relativeX = math.clamp(relativeX, 0, 1)
		currentFrame = math.floor(relativeX * #replayData.frames) + 1
		updateReplayFrame()
	end
end)

-- Playback loop
local lastUpdate = 0
RunService.Heartbeat:Connect(function()
	if replayMode and isPlaying and replayData then
		local now = tick()
		if now - lastUpdate >= (0.1 / playbackSpeed) then -- 10 FPS base rate
			currentFrame = currentFrame + 1
			if currentFrame > #replayData.frames then
				currentFrame = #replayData.frames
				isPlaying = false
			end
			updateReplayFrame()
			lastUpdate = now
		end
	end
end)

-- Keyboard controls
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not replayMode then return end
	
	if input.KeyCode == Enum.KeyCode.Space then
		isPlaying = not isPlaying
	elseif input.KeyCode == Enum.KeyCode.Right then
		if replayData then
			currentFrame = math.min(currentFrame + 1, #replayData.frames)
			updateReplayFrame()
		end
	elseif input.KeyCode == Enum.KeyCode.Left then
		currentFrame = math.max(currentFrame - 1, 1)
		updateReplayFrame()
	end
end)

-- Handle replay requests
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.R and not replayMode then
		ReplayRemote:FireServer("RequestReplay")
	end
end)

-- Handle server responses
ReplayRemote.OnClientEvent:Connect(function(action, data)
	if action == "StartReplay" then
		startReplay(data)
	elseif action == "ReplayNotAvailable" then
		-- Could show UI message here
		print("No replay data available")
	end
end)
