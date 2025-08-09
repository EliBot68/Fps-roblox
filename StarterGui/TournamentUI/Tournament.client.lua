-- Tournament.client.lua  
-- Tournament UI and client management

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
local TournamentRemote = RemoteRoot:WaitForChild("TournamentRemote")

local gui = Instance.new("ScreenGui")
gui.Name = "TournamentUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Name = "TournamentFrame"
mainFrame.Size = UDim2.new(0,700,0,500)
mainFrame.Position = UDim2.new(0.5,-350,0.5,-250)
mainFrame.BackgroundColor3 = Color3.fromRGB(25,25,25)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = gui

local titleLabel = Instance.new("TextLabel")
titleLabel.Text = "Tournament"
titleLabel.Size = UDim2.new(1,0,0,50)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.fromRGB(255,255,255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 28
titleLabel.Parent = mainFrame

local closeButton = Instance.new("TextButton")
closeButton.Text = "X"
closeButton.Size = UDim2.new(0,30,0,30)
closeButton.Position = UDim2.new(1,-35,0,10)
closeButton.BackgroundColor3 = Color3.fromRGB(200,50,50)
closeButton.TextColor3 = Color3.fromRGB(255,255,255)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 18
closeButton.Parent = mainFrame

local statusFrame = Instance.new("Frame")
statusFrame.Size = UDim2.new(1,-20,0,80)
statusFrame.Position = UDim2.new(0,10,0,60)
statusFrame.BackgroundColor3 = Color3.fromRGB(40,40,40)
statusFrame.BorderSizePixel = 0
statusFrame.Parent = mainFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Text = "No active tournament"
statusLabel.Size = UDim2.new(1,-20,0,30)
statusLabel.Position = UDim2.new(0,10,0,10)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(255,255,255)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 16
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = statusFrame

local joinButton = Instance.new("TextButton")
joinButton.Text = "Join Tournament"
joinButton.Size = UDim2.new(0,150,0,30)
joinButton.Position = UDim2.new(0,10,0,40)
joinButton.BackgroundColor3 = Color3.fromRGB(50,150,50)
joinButton.TextColor3 = Color3.fromRGB(255,255,255)
joinButton.Font = Enum.Font.GothamBold
joinButton.TextSize = 14
joinButton.Enabled = false
joinButton.Parent = statusFrame

local createButton = Instance.new("TextButton")
createButton.Text = "Create Tournament"
createButton.Size = UDim2.new(0,150,0,30)
createButton.Position = UDim2.new(0,170,0,40)
createButton.BackgroundColor3 = Color3.fromRGB(50,50,150)
createButton.TextColor3 = Color3.fromRGB(255,255,255)
createButton.Font = Enum.Font.GothamBold
createButton.TextSize = 14
createButton.Parent = statusFrame

local bracketFrame = Instance.new("ScrollingFrame")
bracketFrame.Size = UDim2.new(1,-20,1,-160)
bracketFrame.Position = UDim2.new(0,10,0,150)
bracketFrame.BackgroundColor3 = Color3.fromRGB(35,35,35)
bracketFrame.BorderSizePixel = 0
bracketFrame.Parent = mainFrame

local currentTournament = nil

local function createMatchDisplay(match, round, position)
	local matchFrame = Instance.new("Frame")
	matchFrame.Size = UDim2.new(0,180,0,60)
	matchFrame.Position = UDim2.new(0,round*200+10,0,position*70+10)
	matchFrame.BackgroundColor3 = Color3.fromRGB(50,50,50)
	matchFrame.BorderSizePixel = 0
	matchFrame.Parent = bracketFrame
	
	local player1Label = Instance.new("TextLabel")
	player1Label.Text = match.player1 or "TBD"
	player1Label.Size = UDim2.new(1,-10,0.4,0)
	player1Label.Position = UDim2.new(0,5,0,2)
	player1Label.BackgroundTransparency = 1
	player1Label.TextColor3 = match.winner == match.player1 and Color3.fromRGB(100,255,100) or Color3.fromRGB(255,255,255)
	player1Label.Font = Enum.Font.Gotham
	player1Label.TextSize = 12
	player1Label.TextXAlignment = Enum.TextXAlignment.Left
	player1Label.Parent = matchFrame
	
	local vsLabel = Instance.new("TextLabel")
	vsLabel.Text = "vs"
	vsLabel.Size = UDim2.new(1,0,0.2,0)
	vsLabel.Position = UDim2.new(0,0,0.4,0)
	vsLabel.BackgroundTransparency = 1
	vsLabel.TextColor3 = Color3.fromRGB(200,200,200)
	vsLabel.Font = Enum.Font.Gotham
	vsLabel.TextSize = 10
	vsLabel.Parent = matchFrame
	
	local player2Label = Instance.new("TextLabel")
	player2Label.Text = match.player2 or "TBD"
	player2Label.Size = UDim2.new(1,-10,0.4,0)
	player2Label.Position = UDim2.new(0,5,0.6,0)
	player2Label.BackgroundTransparency = 1
	player2Label.TextColor3 = match.winner == match.player2 and Color3.fromRGB(100,255,100) or Color3.fromRGB(255,255,255)
	player2Label.Font = Enum.Font.Gotham
	player2Label.TextSize = 12
	player2Label.TextXAlignment = Enum.TextXAlignment.Left
	player2Label.Parent = matchFrame
	
	-- Add connecting lines for bracket visualization
	if round > 0 then
		local line = Instance.new("Frame")
		line.Size = UDim2.new(0,20,0,2)
		line.Position = UDim2.new(0,-20,0.5,-1)
		line.BackgroundColor3 = Color3.fromRGB(100,100,100)
		line.BorderSizePixel = 0
		line.Parent = matchFrame
	end
end

local function refreshBracket()
	for _,child in ipairs(bracketFrame:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	
	if not currentTournament then return end
	
	local rounds = currentTournament.rounds
	local maxRounds = #rounds
	local maxMatches = 0
	
	for roundNum, round in ipairs(rounds) do
		for matchNum, match in ipairs(round) do
			createMatchDisplay(match, roundNum-1, matchNum-1)
			maxMatches = math.max(maxMatches, matchNum)
		end
	end
	
	bracketFrame.CanvasSize = UDim2.new(0,maxRounds*200+100,0,maxMatches*70+20)
end

local function updateStatus(tournament)
	currentTournament = tournament
	
	if tournament then
		statusLabel.Text = string.format("Tournament: %s | Players: %d/%d | Status: %s", 
			tournament.name or "Tournament", 
			#(tournament.players or {}), 
			tournament.maxPlayers or 8,
			tournament.status or "Unknown")
		
		joinButton.Enabled = tournament.status == "Registration" and 
			not table.find(tournament.players or {}, player.Name)
		
		createButton.Enabled = false
		
		refreshBracket()
	else
		statusLabel.Text = "No active tournament"
		joinButton.Enabled = false
		createButton.Enabled = true
		for _,child in ipairs(bracketFrame:GetChildren()) do
			if child:IsA("GuiObject") then child:Destroy() end
		end
	end
end

joinButton.MouseButton1Click:Connect(function()
	TournamentRemote:FireServer("Join")
end)

createButton.MouseButton1Click:Connect(function()
	TournamentRemote:FireServer("Create", {
		name = "FPS Tournament",
		maxPlayers = 8
	})
end)

closeButton.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
end)

-- Toggle UI with key
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.T then
		mainFrame.Visible = not mainFrame.Visible
		if mainFrame.Visible then
			TournamentRemote:FireServer("GetStatus")
		end
	end
end)

-- Handle server updates
TournamentRemote.OnClientEvent:Connect(function(action, data)
	if action == "TournamentUpdate" then
		updateStatus(data)
	elseif action == "TournamentEnded" then
		updateStatus(nil)
		if data and data.winner then
			statusLabel.Text = "Tournament ended! Winner: " .. data.winner
		end
	end
end)
