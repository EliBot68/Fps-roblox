-- LobbyUI.client.lua
-- Main lobby interface and navigation

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local LobbyUI = {}

-- RemoteEvents
local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
local MatchmakingEvents = RemoteRoot:WaitForChild("MatchmakingEvents")
local UIEvents = RemoteRoot:WaitForChild("UIEvents")

function LobbyUI.Initialize()
	-- Create main lobby frame
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LobbyUI"
	screenGui.Parent = playerGui
	
	-- Main lobby frame
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainLobby"
	mainFrame.Size = UDim2.new(1, 0, 1, 0)
	mainFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
	mainFrame.Parent = screenGui
	
	-- Game mode buttons
	LobbyUI.CreateGameModeButtons(mainFrame)
	
	print("LobbyUI initialized")
end

function LobbyUI.CreateGameModeButtons(parent)
	local buttonContainer = Instance.new("Frame")
	buttonContainer.Name = "GameModeButtons"
	buttonContainer.Size = UDim2.new(0.8, 0, 0.6, 0)
	buttonContainer.Position = UDim2.new(0.1, 0, 0.2, 0)
	buttonContainer.BackgroundTransparency = 1
	buttonContainer.Parent = parent
	
	local gameModes = {"Casual", "Competitive", "Tournament", "Training"}
	
	for i, mode in ipairs(gameModes) do
		local button = Instance.new("TextButton")
		button.Name = mode .. "Button"
		button.Size = UDim2.new(0.4, -10, 0.4, -10)
		button.Position = UDim2.new((i-1) % 2 * 0.5 + 0.05, 0, math.floor((i-1) / 2) * 0.5 + 0.1, 0)
		button.BackgroundColor3 = Color3.new(0.2, 0.3, 0.8)
		button.Text = mode
		button.TextColor3 = Color3.new(1, 1, 1)
		button.TextScaled = true
		button.Font = Enum.Font.SourceSansBold
		button.Parent = buttonContainer
		
		-- Button click handler
		button.MouseButton1Click:Connect(function()
			LobbyUI.JoinGameMode(mode)
		end)
	end
end

function LobbyUI.JoinGameMode(mode)
	local RequestMatchRemote = MatchmakingEvents:FindFirstChild("RequestMatch")
	if RequestMatchRemote then
		RequestMatchRemote:FireServer(mode:lower())
		print("Requested match for mode:", mode)
	end
end

-- Initialize when script loads
LobbyUI.Initialize()

return LobbyUI
