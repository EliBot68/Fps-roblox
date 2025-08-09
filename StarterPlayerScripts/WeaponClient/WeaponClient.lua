--[[
	WeaponClient.lua
	Place in: StarterPlayerScripts/WeaponClient/
	
	Client-side weapon handling including input, camera recoil,
	muzzle VFX, and UI updates for the weapon system.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")

local Player = Players.LocalPlayer
local Character = Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local Camera = workspace.CurrentCamera

-- Wait for weapon system
local WeaponSystem = ReplicatedStorage:WaitForChild("WeaponSystem")
local Modules = WeaponSystem:WaitForChild("Modules")
local WeaponDefinitions = require(Modules:WaitForChild("WeaponDefinitions"))
local WeaponUtils = require(Modules:WaitForChild("WeaponUtils"))

-- Wait for RemoteEvents
local WeaponEvents = ReplicatedStorage:WaitForChild("WeaponEvents")
local FireWeaponRemote = WeaponEvents:WaitForChild("FireWeapon")
local ReloadWeaponRemote = WeaponEvents:WaitForChild("ReloadWeapon")
local SwitchWeaponRemote = WeaponEvents:WaitForChild("SwitchWeapon")
local WeaponStateRemote = WeaponEvents:WaitForChild("WeaponState")

local WeaponClient = {}

-- Client weapon state
local CurrentWeapons = {
	Primary = nil,
	Secondary = nil,
	Melee = nil,
	CurrentSlot = "Primary",
	Ammo = {}
}

local CurrentWeaponModel = nil
local IsReloading = false
local LastFireTime = 0

-- Input bindings
local INPUT_BINDINGS = {
	Fire = {Enum.UserInputType.MouseButton1},
	Reload = {Enum.KeyCode.R},
	SwitchPrimary = {Enum.KeyCode.One},
	SwitchSecondary = {Enum.KeyCode.Two},
	SwitchMelee = {Enum.KeyCode.Three}
}

-- Recoil settings
local RECOIL_SETTINGS = {
	AssaultRifle = Vector3.new(2, 1, 0),
	SMG = Vector3.new(1.5, 1.5, 0),
	Shotgun = Vector3.new(4, 2, 0),
	Sniper = Vector3.new(6, 0.5, 0),
	Pistol = Vector3.new(3, 1, 0),
	CombatKnife = Vector3.new(0.5, 0.5, 0),
	Axe = Vector3.new(1, 1, 0),
	ThrowingKnife = Vector3.new(2, 1, 0)
}

-- Handle weapon firing
function WeaponClient.FireWeapon()
	local currentWeapon = CurrentWeapons[CurrentWeapons.CurrentSlot]
	if not currentWeapon then return end
	
	local weapon = WeaponDefinitions.GetWeapon(currentWeapon)
	if not weapon then return end
	
	-- Check fire rate
	local currentTime = tick()
	local timeSinceLastFire = currentTime - LastFireTime
	local minFireInterval = 1 / weapon.FireRate
	
	if timeSinceLastFire < minFireInterval then
		return -- Too soon to fire again
	end
	
	-- Check if reloading
	if IsReloading then return end
	
	-- Check ammo
	local currentAmmo = CurrentWeapons.Ammo[currentWeapon] or 0
	if currentAmmo <= 0 and weapon.MagazineSize > 0 and weapon.MagazineSize < 999 then
		-- Auto-reload if empty
		WeaponClient.ReloadWeapon()
		return
	end
	
	-- Get camera direction
	local cameraCFrame = Camera.CFrame
	local fireDirection = cameraCFrame.LookVector
	
	-- Send fire request to server
	FireWeaponRemote:FireServer(currentWeapon, cameraCFrame, fireDirection, tick())
	
	-- Apply local recoil
	local recoilAmount = RECOIL_SETTINGS[currentWeapon] or Vector3.new(2, 1, 0)
	WeaponUtils.ApplyRecoil(Camera, recoilAmount)
	
	-- Play local muzzle flash
	WeaponClient.PlayMuzzleFlash()
	
	-- Play fire sound
	WeaponUtils.PlaySound(weapon.FireSound, 0.5)
	
	LastFireTime = currentTime
end

-- Handle weapon reload
function WeaponClient.ReloadWeapon()
	local currentWeapon = CurrentWeapons[CurrentWeapons.CurrentSlot]
	if not currentWeapon then return end
	
	local weapon = WeaponDefinitions.GetWeapon(currentWeapon)
	if not weapon then return end
	
	-- Check if already reloading
	if IsReloading then return end
	
	-- Check if infinite ammo weapon
	if weapon.MagazineSize >= 999 then return end
	
	-- Check if already full
	local currentAmmo = CurrentWeapons.Ammo[currentWeapon] or 0
	if currentAmmo >= weapon.MagazineSize then return end
	
	-- Start reload
	IsReloading = true
	ReloadWeaponRemote:FireServer(currentWeapon)
end

-- Handle weapon switching
function WeaponClient.SwitchWeapon(slot: string)
	if slot == CurrentWeapons.CurrentSlot then return end
	if not CurrentWeapons[slot] then return end
	
	-- Send switch request to server
	SwitchWeaponRemote:FireServer(slot)
end

-- Play muzzle flash effect
function WeaponClient.PlayMuzzleFlash()
	if not CurrentWeaponModel then return end
	
	-- Find muzzle attachment point
	local muzzle = CurrentWeaponModel:FindFirstChild("Muzzle") or CurrentWeaponModel.PrimaryPart
	if not muzzle then return end
	
	-- Get muzzle flash from pool
	local muzzleFlash = WeaponUtils.GetMuzzleFlash()
	muzzleFlash.Parent = muzzle
	muzzleFlash.Enabled = true
	
	-- Flash for short duration
	task.spawn(function()
		task.wait(0.1)
		muzzleFlash.Enabled = false
		task.wait(0.5) -- Cool down
		WeaponUtils.ReturnMuzzleFlash(muzzleFlash)
	end)
end

-- Update weapon model
function WeaponClient.UpdateWeaponModel(weaponId: string)
	-- Remove old weapon model
	if CurrentWeaponModel then
		CurrentWeaponModel:Destroy()
		CurrentWeaponModel = nil
	end
	
	-- Get weapon configuration
	local weapon = WeaponDefinitions.GetWeapon(weaponId)
	if not weapon then return end
	
	-- Load new weapon model
	local weaponModel = WeaponUtils.GetWeaponModel(weapon.ModelId)
	if not weaponModel then
		warn("Failed to load weapon model for:", weaponId)
		return
	end
	
	-- Attach to character
	local rightHand = Character:FindFirstChild("Right Arm") or Character:FindFirstChild("RightHand")
	if rightHand then
		weaponModel.Parent = Character
		
		-- Position weapon in hand
		if weaponModel.PrimaryPart then
			local handCFrame = rightHand.CFrame * CFrame.new(0, -1, 0) * CFrame.Angles(0, math.pi/2, 0)
			weaponModel:SetPrimaryPartCFrame(handCFrame)
		end
		
		-- Weld weapon to hand
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = rightHand
		weld.Part1 = weaponModel.PrimaryPart or weaponModel:FindFirstChildWhichIsA("Part")
		weld.Parent = rightHand
	end
	
	CurrentWeaponModel = weaponModel
end

-- Handle server weapon state updates
function WeaponClient.OnWeaponStateUpdate(data)
	if data.Type == "AmmoUpdate" then
		-- Update ammo count
		CurrentWeapons.Ammo[data.WeaponId] = data.CurrentAmmo
		WeaponClient.UpdateAmmoUI()
		
	elseif data.Type == "WeaponSwitched" then
		-- Handle weapon switch
		CurrentWeapons.CurrentSlot = data.Slot
		CurrentWeapons.Ammo[data.WeaponId] = data.CurrentAmmo
		WeaponClient.UpdateWeaponModel(data.WeaponId)
		WeaponClient.UpdateAmmoUI()
		
	elseif data.Type == "ReloadStart" then
		-- Start reload animation
		IsReloading = true
		WeaponClient.PlayReloadAnimation(data.ReloadTime)
		WeaponUtils.PlaySound(WeaponDefinitions.GetWeapon(data.WeaponId).ReloadSound, 0.3)
		
	elseif data.Type == "ReloadComplete" then
		-- Complete reload
		IsReloading = false
		CurrentWeapons.Ammo[data.WeaponId] = data.CurrentAmmo
		WeaponClient.UpdateAmmoUI()
		
	elseif data.Type == "WeaponFired" then
		-- Handle other players firing
		if data.Player ~= Player.Name then
			WeaponClient.HandleOtherPlayerFire(data)
		end
		
	elseif data.Type == "EmptyAmmo" then
		-- Play empty chamber sound
		WeaponUtils.PlaySound("rbxassetid://131961136", 0.3) -- Click sound
		
	elseif data.Type == "PlayerEliminated" then
		-- Handle elimination notification
		WeaponClient.ShowEliminationFeed(data.Data)
		
	else
		-- Full weapon state update
		CurrentWeapons = data
		local currentWeapon = CurrentWeapons[CurrentWeapons.CurrentSlot]
		if currentWeapon then
			WeaponClient.UpdateWeaponModel(currentWeapon)
		end
		WeaponClient.UpdateAmmoUI()
	end
end

-- Handle other players firing (for VFX)
function WeaponClient.HandleOtherPlayerFire(fireData)
	-- Play fire sound at origin
	local sound = WeaponUtils.GetSound(WeaponDefinitions.GetWeapon(fireData.WeaponId).FireSound)
	sound.Parent = workspace
	
	-- Create 3D positioned sound
	local soundPart = Instance.new("Part")
	soundPart.Size = Vector3.new(0.1, 0.1, 0.1)
	soundPart.Position = fireData.Origin
	soundPart.Anchored = true
	soundPart.CanCollide = false
	soundPart.Transparency = 1
	soundPart.Parent = workspace
	
	sound.Parent = soundPart
	sound:Play()
	
	-- Clean up after sound plays
	sound.Ended:Connect(function()
		soundPart:Destroy()
		WeaponUtils.ReturnSound(sound)
	end)
	
	-- Handle hit effects
	for _, hit in ipairs(fireData.Hits) do
		if hit.Type == "EnvironmentHit" then
			WeaponUtils.CreateHitEffect(hit.Position, hit.Normal, hit.Material)
		end
	end
end

-- Play reload animation
function WeaponClient.PlayReloadAnimation(reloadTime: number)
	-- TODO: Play actual reload animation
	-- For now, just show reload indicator
	print("Reloading for", reloadTime, "seconds...")
end

-- Update ammo UI
function WeaponClient.UpdateAmmoUI()
	local currentWeapon = CurrentWeapons[CurrentWeapons.CurrentSlot]
	if not currentWeapon then return end
	
	local weapon = WeaponDefinitions.GetWeapon(currentWeapon)
	if not weapon then return end
	
	local currentAmmo = CurrentWeapons.Ammo[currentWeapon] or 0
	local maxAmmo = weapon.MagazineSize
	
	-- Update UI elements (handled by AmmoCounter script)
	local playerGui = Player:WaitForChild("PlayerGui")
	local weaponUI = playerGui:FindFirstChild("WeaponUI")
	
	if weaponUI then
		local ammoFrame = weaponUI:FindFirstChild("AmmoFrame")
		if ammoFrame then
			local ammoLabel = ammoFrame:FindFirstChild("AmmoLabel")
			if ammoLabel then
				if maxAmmo >= 999 then
					ammoLabel.Text = "∞" -- Infinite ammo symbol
				else
					ammoLabel.Text = string.format("%d / %d", currentAmmo, maxAmmo)
				end
			end
		end
		
		local weaponLabel = weaponUI:FindFirstChild("WeaponLabel")
		if weaponLabel then
			weaponLabel.Text = weapon.Name
		end
	end
end

-- Show elimination feed
function WeaponClient.ShowEliminationFeed(eliminationData)
	print(string.format("🏆 %s eliminated %s with %s%s", 
		eliminationData.Killer,
		eliminationData.Victim,
		eliminationData.Weapon,
		eliminationData.Headshot and " (HEADSHOT)" or ""
	))
end

-- Input handling
local function handleInput(actionName: string, inputState: Enum.UserInputState, inputObject: InputObject)
	if inputState ~= Enum.UserInputState.Begin then return end
	
	if actionName == "Fire" then
		WeaponClient.FireWeapon()
	elseif actionName == "Reload" then
		WeaponClient.ReloadWeapon()
	elseif actionName == "SwitchPrimary" then
		WeaponClient.SwitchWeapon("Primary")
	elseif actionName == "SwitchSecondary" then
		WeaponClient.SwitchWeapon("Secondary")
	elseif actionName == "SwitchMelee" then
		WeaponClient.SwitchWeapon("Melee")
	end
end

-- Handle continuous firing
local fireConnection
local function startContinuousFire()
	if fireConnection then return end
	
	fireConnection = RunService.Heartbeat:Connect(function()
		if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
			WeaponClient.FireWeapon()
		end
	end)
end

local function stopContinuousFire()
	if fireConnection then
		fireConnection:Disconnect()
		fireConnection = nil
	end
end

-- Bind inputs
for actionName, keys in pairs(INPUT_BINDINGS) do
	ContextActionService:BindAction(actionName, handleInput, false, table.unpack(keys))
end

-- Special handling for continuous fire
UserInputService.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		startContinuousFire()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		stopContinuousFire()
	end
end)

-- Connect server events
WeaponStateRemote.OnClientEvent:Connect(WeaponClient.OnWeaponStateUpdate)

-- Handle character respawn
Player.CharacterAdded:Connect(function(newCharacter)
	Character = newCharacter
	Humanoid = newCharacter:WaitForChild("Humanoid")
	
	-- Reset weapon model
	CurrentWeaponModel = nil
	
	-- Wait for server to send weapon state
	task.wait(1)
	WeaponClient.UpdateAmmoUI()
end)

print("WeaponClient initialized")

return WeaponClient
