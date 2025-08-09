local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create AntiCheatWarning RemoteEvent
local UIEvents = ReplicatedStorage.RemoteEvents.UIEvents
local AntiCheatWarning = Instance.new("RemoteEvent")
AntiCheatWarning.Name = "AntiCheatWarning"
AntiCheatWarning.Parent = UIEvents
