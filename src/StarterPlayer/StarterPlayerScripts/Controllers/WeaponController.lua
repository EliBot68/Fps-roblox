--!strict
--[[
	WeaponController.lua
	Client-side weapon handling with prediction and mobile support
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import dependencies
local CombatTypes = require(ReplicatedStorage.Shared.CombatTypes)
local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)
local EffectsController = require(script.Parent.EffectsController)
local InputManager = require(script.Parent.InputManager)

type WeaponInstance = CombatTypes.WeaponInstance
type InputConfig = CombatTypes.InputConfig

local WeaponController = {}

-- Configuration
local WEAPON_CONFIG = {
	maxPredictionTime = 0.1, -- seconds
	recoilRecoveryRate = 2.0, -- per second
	mobileAimAssistRange = 50, -- studs
	crosshairUpdateRate = 60, -- hz
	effectPoolSize = 50
}

-- State
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse = player:GetMouse()

local equippedWeapons: {[number]: WeaponInstance} = {}
local activeSlot = 1
local isAiming = false
local isFiring = false
local isReloading = false
local lastFireTime = 0
local recoilOffset = Vector3.new()
local crosshairSpread = 0

-- Input configuration
local inputConfig: InputConfig = {
	sensitivity = 1.0,
	invertY = false,
	autoFire = false,
	aimAssist = true,
	hapticFeedback = true,
	crosshairStyle = "Default",
	crosshairColor = Color3.new(1, 1, 1),
	fov = 90,
	controlScheme = "Default"
}

-- Remote events
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("CombatEvents")
local fireWeaponRemote = remoteEvents:WaitForChild("FireWeapon")
local reloadWeaponRemote = remoteEvents:WaitForChild("ReloadWeapon")
local equipWeaponRemote = remoteEvents:WaitForChild("EquipWeapon")

-- Initialize weapon controller
function WeaponController.Initialize()
	-- Set up input handling
	InputManager.Initialize()
	InputManager.BindAction("Fire", WeaponController.StartFiring, WeaponController.StopFiring)
	InputManager.BindAction("Reload", WeaponController.Reload)
	InputManager.BindAction("Aim", WeaponController.StartAiming, WeaponController.StopAiming)
	
	-- Set up weapon switching
	for i = 1, 3 do
		InputManager.BindAction("Weapon" .. i, function()
			WeaponController.SwitchWeapon(i)
		end)
	end
	
	-- Set up update loop
	RunService.Heartbeat:Connect(WeaponController.Update)
	
	-- Set up mobile-specific features
	if UserInputService.TouchEnabled then
		WeaponController.SetupMobileControls()
	end
	
	print("[WeaponController] ✓ Initialized with mobile support")
end

-- Main update loop
function WeaponController.Update()
	local currentTime = tick()
	
	-- Update recoil recovery
	if recoilOffset.Magnitude > 0 then
		local recovery = WEAPON_CONFIG.recoilRecoveryRate * RunService.Heartbeat:Wait()
		recoilOffset = recoilOffset * math.max(0, 1 - recovery)
	end
	
	-- Update crosshair
	WeaponController.UpdateCrosshair()
	
	-- Update weapon sway
	WeaponController.UpdateWeaponSway()
	
	-- Handle continuous firing
	if isFiring and not isReloading then
		local weapon = equippedWeapons[activeSlot]
		if weapon then
			local fireRate = weapon.config.stats.fireRate / 60 -- convert RPM to RPS
			local timeBetweenShots = 1 / fireRate
			
			if currentTime - lastFireTime >= timeBetweenShots then
				WeaponController.FireWeapon()
			end
		end
	end
end

-- Start firing weapon
function WeaponController.StartFiring()
	if isReloading then return end
	
	local weapon = equippedWeapons[activeSlot]
	if not weapon then return end
	
	isFiring = true
	
	-- Immediate first shot (no delay)
	WeaponController.FireWeapon()
	
	-- Handle mobile haptic feedback
	if UserInputService.TouchEnabled and inputConfig.hapticFeedback then
		UserInputService:PulseCoreHaptics(Enum.CoreHapticsType.ImpactLight, 1)
	end
end

-- Stop firing weapon
function WeaponController.StopFiring()
	isFiring = false
end

-- Fire weapon with prediction
function WeaponController.FireWeapon()
	local weapon = equippedWeapons[activeSlot]
	if not weapon then return end
	
	-- Check ammunition
	if weapon.currentAmmo <= 0 then
		WeaponController.PlayDryFireEffect()
		return
	end
	
	local currentTime = tick()
	
	-- Get target position
	local targetPosition = WeaponController.GetTargetPosition()
	
	-- Client prediction - immediate visual feedback
	WeaponController.PredictShot(weapon, targetPosition)
	
	-- Send to server for validation
	local result = fireWeaponRemote:InvokeServer(weapon.config.id, targetPosition, currentTime)
	
	-- Handle server response
	if result.success then
		-- Server confirmed hit
		if result.hitTarget then
			EffectsController.PlayHitEffect(result.hitTarget, result.damage)
		end
	else
		-- Server rejected shot - correct prediction
		WeaponController.CorrectPrediction(result.reason)
	end
	
	lastFireTime = currentTime
end

-- Get target position with aim assist
function WeaponController.GetTargetPosition(): Vector3
	local targetPosition = mouse.Hit.Position
	
	-- Mobile aim assist
	if UserInputService.TouchEnabled and inputConfig.aimAssist then
		local assistTarget = WeaponController.FindAimAssistTarget()
		if assistTarget then
			-- Blend between raw input and assisted target
			local blendFactor = 0.3
			targetPosition = targetPosition:Lerp(assistTarget, blendFactor)
		end
	end
	
	return targetPosition
end

-- Find nearby target for aim assist
function WeaponController.FindAimAssistTarget(): Vector3?
	local centerRay = camera:ScreenPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
	
	-- Raycast for nearby players
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	raycastParams.FilterDescendantsInstances = {player.Character}
	
	local result = workspace:Raycast(centerRay.Origin, centerRay.Direction * WEAPON_CONFIG.mobileAimAssistRange, raycastParams)
	
	if result and result.Instance then
		local hitCharacter = result.Instance.Parent
		if hitCharacter:FindFirstChild("Humanoid") then
			-- Found a player, return torso position
			local humanoidRootPart = hitCharacter:FindFirstChild("HumanoidRootPart")
			if humanoidRootPart then
				return humanoidRootPart.Position
			end
		end
	end
	
	return nil
end

-- Predict shot for immediate feedback
function WeaponController.PredictShot(weapon: WeaponInstance, targetPosition: Vector3)
	-- Consume ammo (prediction)
	weapon.currentAmmo = weapon.currentAmmo - 1
	
	-- Apply recoil
	WeaponController.ApplyRecoil(weapon)
	
	-- Play visual effects
	EffectsController.PlayMuzzleFlash(weapon.config.id)
	EffectsController.PlayFireSound(weapon.config.id)
	EffectsController.PlayFireAnimation(weapon.config.id)
	
	-- Show bullet trail
	EffectsController.ShowBulletTrail(camera.CFrame.Position, targetPosition)
	
	-- Update crosshair spread
	crosshairSpread = math.min(1, crosshairSpread + 0.2)
end

-- Apply weapon recoil
function WeaponController.ApplyRecoil(weapon: WeaponInstance)
	local recoilPattern = weapon.config.stats.recoilPattern
	if #recoilPattern == 0 then return end
	
	-- Get recoil for current shot in pattern
	local shotIndex = math.min(#recoilPattern, weapon.config.stats.magazineSize - weapon.currentAmmo)
	local recoil = recoilPattern[shotIndex]
	
	-- Apply to camera
	recoilOffset = recoilOffset + recoil
	
	-- Convert to camera rotation
	local recoilCFrame = CFrame.Angles(
		math.rad(-recoil.X), -- pitch
		math.rad(recoil.Y),  -- yaw
		math.rad(recoil.Z)   -- roll
	)
	
	camera.CFrame = camera.CFrame * recoilCFrame
end

-- Start aiming down sights
function WeaponController.StartAiming()
	if isReloading then return end
	
	isAiming = true
	
	-- Reduce crosshair spread
	crosshairSpread = crosshairSpread * 0.5
	
	-- Zoom camera
	local weapon = equippedWeapons[activeSlot]
	if weapon then
		-- Adjust FOV for zoom
		local zoomFactor = 0.7
		camera.FieldOfView = inputConfig.fov * zoomFactor
	end
end

-- Stop aiming down sights
function WeaponController.StopAiming()
	isAiming = false
	
	-- Reset camera FOV
	camera.FieldOfView = inputConfig.fov
end

-- Reload current weapon
function WeaponController.Reload()
	if isReloading then return end
	
	local weapon = equippedWeapons[activeSlot]
	if not weapon then return end
	
	-- Check if reload is needed
	if weapon.currentAmmo >= weapon.config.stats.magazineSize then return end
	if weapon.totalAmmo <= 0 then return end
	
	isReloading = true
	
	-- Play reload animation and sound
	EffectsController.PlayReloadAnimation(weapon.config.id)
	EffectsController.PlayReloadSound(weapon.config.id)
	
	-- Send reload request to server
	task.spawn(function()
		local result = reloadWeaponRemote:InvokeServer(weapon.config.id)
		
		if result.success then
			weapon.currentAmmo = result.ammoCount
		end
		
		isReloading = false
	end)
end

-- Switch to weapon slot
function WeaponController.SwitchWeapon(slot: number)
	if slot < 1 or slot > 3 or slot == activeSlot then return end
	
	local weapon = equippedWeapons[slot]
	if not weapon then return end
	
	-- Stop current actions
	WeaponController.StopFiring()
	WeaponController.StopAiming()
	
	-- Switch slots
	local oldSlot = activeSlot
	activeSlot = slot
	
	-- Play switch animation
	if equippedWeapons[oldSlot] then
		EffectsController.PlayHolsterAnimation(equippedWeapons[oldSlot].config.id)
	end
	EffectsController.PlayDrawAnimation(weapon.config.id)
	
	-- Notify server
	equipWeaponRemote:FireServer(weapon.config.id, slot)
end

-- Update crosshair appearance
function WeaponController.UpdateCrosshair()
	-- Gradually reduce spread when not firing
	if not isFiring then
		crosshairSpread = math.max(0, crosshairSpread - RunService.Heartbeat:Wait() * 2)
	end
	
	-- Update crosshair size based on spread and accuracy
	local weapon = equippedWeapons[activeSlot]
	if weapon then
		local baseSpread = (1 - weapon.config.stats.accuracy) * 0.5
		local totalSpread = baseSpread + crosshairSpread
		
		-- Apply to UI crosshair
		-- TODO: Implement crosshair UI updates
	end
end

-- Update weapon sway for immersion
function WeaponController.UpdateWeaponSway()
	-- Add subtle weapon sway based on movement and aim
	-- TODO: Implement weapon sway effects
end

-- Set up mobile-specific controls
function WeaponController.SetupMobileControls()
	-- Create mobile fire button
	-- TODO: Implement mobile UI controls
	
	-- Set up gesture recognition
	-- TODO: Implement swipe gestures for weapon switching
end

-- Play dry fire effect when out of ammo
function WeaponController.PlayDryFireEffect()
	local weapon = equippedWeapons[activeSlot]
	if weapon then
		EffectsController.PlayDryFireSound(weapon.config.id)
	end
end

-- Correct prediction when server rejects shot
function WeaponController.CorrectPrediction(reason: string)
	-- Restore ammo if prediction was wrong
	local weapon = equippedWeapons[activeSlot]
	if weapon then
		weapon.currentAmmo = weapon.currentAmmo + 1
	end
	
	warn("[WeaponController] Shot rejected:", reason)
end

-- Equip weapon in slot
function WeaponController.EquipWeapon(weaponInstance: WeaponInstance, slot: number)
	equippedWeapons[slot] = weaponInstance
	
	if slot == activeSlot then
		EffectsController.PlayDrawAnimation(weaponInstance.config.id)
	end
end

-- Get current weapon
function WeaponController.GetCurrentWeapon(): WeaponInstance?
	return equippedWeapons[activeSlot]
end

-- Update input configuration
function WeaponController.UpdateInputConfig(newConfig: InputConfig)
	inputConfig = newConfig
	camera.FieldOfView = inputConfig.fov
end

return WeaponController
