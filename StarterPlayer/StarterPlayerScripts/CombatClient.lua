-- CombatClient.lua
-- Handles local firing input and sends to server (placeholder)

-- NOTE: RemoteEvents not yet created in hierarchy; will reference later

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local currentWeapon = "AssaultRifle"
local lastFire = 0

local FIRE_COOLDOWN = 0.12

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local now = tick()
		if now - lastFire < FIRE_COOLDOWN then return end
		lastFire = now
		-- TODO: send RemoteEvent with origin + direction
		print("[Client] Fire weapon", currentWeapon)
	end
end)
