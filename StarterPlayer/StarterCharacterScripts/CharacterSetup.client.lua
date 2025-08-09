-- CharacterSetup.client.lua
-- Runs when a character spawns
-- Placeholder for character-specific scripts

local Players = game:GetService("Players")

local player = Players.LocalPlayer

-- Wait for character to spawn
local function onCharacterAdded(character)
	-- Character setup logic can go here
	print(player.Name .. " character spawned")
end

if player.Character then
	onCharacterAdded(player.Character)
end

player.CharacterAdded:Connect(onCharacterAdded)
