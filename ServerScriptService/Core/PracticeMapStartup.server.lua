-- PracticeMapStartup.server.lua
-- Ensures players spawn directly in lobby with practice access (no game mode selection)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logging = require(ReplicatedStorage.Shared.Logging)

local PracticeMapStartup = {}

-- Override default player spawning to bypass game mode selection
function PracticeMapStartup.Initialize()
	-- Handle new players joining
	Players.PlayerAdded:Connect(function(player)
		-- Give player time to load
		task.wait(2)
		
		-- Ensure player spawns in lobby without game mode selection
		player.CharacterAdded:Connect(function(character)
			task.wait(1) -- Wait for character to fully load
			
			-- Send welcome message
			local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
			local UIEvents = RemoteRoot:WaitForChild("UIEvents")
			local notificationRemote = UIEvents:FindFirstChild("ShowNotification")
			
			if notificationRemote then
				notificationRemote:FireClient(player, 
					"🎯 Welcome to Rival Clash FPS!", 
					"Find the blue Practice Range button to test weapons", 
					8
				)
			end
			
			Logging.Info("PracticeMapStartup", "Player " .. player.Name .. " spawned in lobby")
		end)
	end)
	
	-- Disable any automatic game mode selection
	local GameStateManager = require(script.Parent.GameStateManager)
	if GameStateManager and GameStateManager.SetState then
		-- Keep game in lobby state to prevent automatic matchmaking
		GameStateManager.SetState("lobby")
	end
	
	Logging.Info("PracticeMapStartup", "Practice map startup system initialized")
end

-- Start the system
PracticeMapStartup.Initialize()

return PracticeMapStartup
