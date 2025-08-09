-- RecoilClient.lua
-- Client recoil pattern placeholder

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local RecoilClient = {}
local recoilActive = false
local currentRecoil = Vector3.new()

local function applyRecoil(weapon, intensity)
	if not camera then return end
	intensity = intensity or 1
	local pattern = {
		Vector3.new(0, 0.5, 0),
		Vector3.new(-0.2, 0.3, 0),
		Vector3.new(0.3, 0.4, 0),
		Vector3.new(-0.1, 0.2, 0)
	}
	
	for i,offset in ipairs(pattern) do
		task.wait(0.05)
		if camera then
			camera.CFrame = camera.CFrame * CFrame.Angles(
				math.rad(offset.X * intensity),
				math.rad(offset.Y * intensity),
				math.rad(offset.Z * intensity)
			)
		end
	end
end

function RecoilClient.FireRecoil(weaponId)
	if recoilActive then return end
	recoilActive = true
	local intensity = 1
	if weaponId == "Sniper" then intensity = 2.5
	elseif weaponId == "SMG" then intensity = 0.7
	end
	task.spawn(function()
		applyRecoil(weaponId, intensity)
		recoilActive = false
	end)
end

return RecoilClient
