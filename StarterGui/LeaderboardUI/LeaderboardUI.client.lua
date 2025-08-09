-- LeaderboardUI.client.lua
-- Client leaderboard remote scaffold

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
local UIEvents = RemoteRoot:WaitForChild("UIEvents")
local ShowLeaderboardRemote = UIEvents:WaitForChild("ShowLeaderboard")

local gui = Instance.new("ScreenGui")
gui.Name = "LeaderboardUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Name = "LeaderboardFrame"
frame.Size = UDim2.new(0,400,0,300)
frame.Position = UDim2.new(0.5,-200,0.5,-150)
frame.BackgroundColor3 = Color3.fromRGB(40,40,40)
frame.BorderSizePixel = 0
frame.Visible = false
frame.Parent = gui

local title = Instance.new("TextLabel")
title.Text = "Leaderboard"
title.Size = UDim2.new(1,0,0,30)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255,255,255)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.Parent = frame

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1,-20,1,-40)
scrollFrame.Position = UDim2.new(0,10,0,30)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.Parent = frame

ShowLeaderboardRemote.OnClientEvent:Connect(function(data)
	frame.Visible = not frame.Visible
	if frame.Visible and data then
		-- Clear old entries
		for _,child in ipairs(scrollFrame:GetChildren()) do
			if child:IsA("GuiObject") then child:Destroy() end
		end
		-- Add new entries
		for i,entry in ipairs(data) do
			local entryFrame = Instance.new("TextLabel")
			entryFrame.Text = string.format("%d. %s - %d ELO", i, entry.Name, entry.Elo)
			entryFrame.Size = UDim2.new(1,0,0,25)
			entryFrame.Position = UDim2.new(0,0,0,(i-1)*25)
			entryFrame.BackgroundTransparency = 1
			entryFrame.TextColor3 = Color3.fromRGB(200,200,200)
			entryFrame.Font = Enum.Font.Gotham
			entryFrame.TextSize = 14
			entryFrame.Parent = scrollFrame
		end
		scrollFrame.CanvasSize = UDim2.new(0,0,0,#data*25)
	end
end)
