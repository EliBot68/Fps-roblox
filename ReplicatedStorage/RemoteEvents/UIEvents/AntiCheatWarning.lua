-- AntiCheatWarning RemoteEvent Module
-- This creates and returns the AntiCheatWarning RemoteEvent

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create the RemoteEvent if it doesn't exist
local AntiCheatWarning = ReplicatedStorage.RemoteEvents.UIEvents:FindFirstChild("AntiCheatWarning")
if not AntiCheatWarning then
    AntiCheatWarning = Instance.new("RemoteEvent")
    AntiCheatWarning.Name = "AntiCheatWarning"
    AntiCheatWarning.Parent = ReplicatedStorage.RemoteEvents.UIEvents
end

return AntiCheatWarning
