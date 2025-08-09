-- CombatClient.lua
-- Handles local firing input and sends to server (placeholder)

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
local CombatEvents = RemoteRoot:WaitForChild("CombatEvents")
local FireWeaponRemote = CombatEvents:WaitForChild("FireWeapon")
local RequestReloadRemote = CombatEvents:WaitForChild("RequestReload")
local SwitchWeaponRemote = CombatEvents:WaitForChild("SwitchWeapon")

local RecoilClient = require(script.Parent.RecoilClient)

local currentWeapon = "AssaultRifle"
local lastFire = 0
local FIRE_COOLDOWN = 0.12

local function fire()
	local now = tick()
	if now - lastFire < FIRE_COOLDOWN then return end
	lastFire = now
	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector
	FireWeaponRemote:FireServer(origin, direction)
end

local function switchWeapon(id)
	SwitchWeaponRemote:FireServer(id)
end

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		fire()
	elseif input.KeyCode == Enum.KeyCode.R then
		RequestReloadRemote:FireServer()
	end
end)

-- TODO: listen to UpdateStats for HUD updates

-- Placeholder input binding (developer to connect to UI):
-- switchWeapon("SMG")
-- switchWeapon("Sniper")
