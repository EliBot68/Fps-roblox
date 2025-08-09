-- CombatClient.client.lua
-- Enterprise client-side combat system with advanced features

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Wait for shared modules
local GameConfig = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig")
local WeaponConfig = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponConfig")
local Utilities = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilities")
local RemoteValidator = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RemoteValidator")

-- Wait for RemoteEvents
local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
local CombatEvents = RemoteRoot:WaitForChild("CombatEvents")
local FireWeaponRemote = CombatEvents:WaitForChild("FireWeapon")
local ReportHitRemote = CombatEvents:WaitForChild("ReportHit")
local RequestReloadRemote = CombatEvents:WaitForChild("RequestReload")
local SwitchWeaponRemote = CombatEvents:WaitForChild("SwitchWeapon")

-- Client systems
local RecoilClient = require(script.Parent.RecoilClient)
local SoundManager = require(script.Parent.SoundManager)

local CombatClient = {}

-- Combat state
local combatState = {
	currentWeapon = "AssaultRifle",
	isReloading = false,
	currentAmmo = 30,
	reserveAmmo = 120,
	lastFire = 0,
	fireMode = "auto", -- auto, semi, burst
	isAiming = false,
	crosshairSpread = 0,
	recoilPattern = Vector2.new(0, 0),
	weaponSway = Vector2.new(0, 0)
}

-- Input tracking
local inputState = {
	leftMouseDown = false,
	rightMouseDown = false,
	wasdPressed = {},
	lastMovementTime = 0
}

-- Performance tracking
local performanceMetrics = {
	shotsToHit = 0,
	totalShots = 0,
	accuracy = 0,
	consecutiveHits = 0,
	consecutiveMisses = 0
}

-- Fire rate limiting with burst support
local function canFire()
	local weapon = WeaponConfig[combatState.currentWeapon]
	if not weapon then return false end
	
	local now = tick()
	local cooldown = 1 / weapon.FireRate
	
	-- Additional checks
	if combatState.isReloading then return false end
	if combatState.currentAmmo <= 0 then return false end
	if now - combatState.lastFire < cooldown then return false end
	
	return true
end

-- Enhanced firing with client-side prediction
local function fire()
	if not canFire() then return end
	
	local weapon = WeaponConfig[combatState.currentWeapon]
	local now = tick()
	combatState.lastFire = now
	
	-- Calculate firing position and direction
	local character = player.Character
	if not character then return end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end
	
	-- Use camera for better accuracy
	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector
	
	-- Apply weapon spread with movement penalty
	local movementPenalty = 1.0
	if inputState.lastMovementTime and now - inputState.lastMovementTime < 0.5 then
		movementPenalty = 1.5 -- Increase spread when moving
	end
	
	local aimPenalty = combatState.isAiming and 0.7 or 1.0
	local totalSpread = weapon.Spread * movementPenalty * aimPenalty
	direction = Utilities.ApplySpread(direction, totalSpread)
	
	-- Validate before sending
	local valid, reason = RemoteValidator.ValidateFire(origin, direction, combatState.currentWeapon)
	if not valid then
		warn("Invalid fire parameters: " .. reason)
		return
	end
	
	-- Send to server
	FireWeaponRemote:FireServer(origin, direction, combatState.currentWeapon)
	
	-- Update local state
	combatState.currentAmmo = combatState.currentAmmo - 1
	performanceMetrics.totalShots = performanceMetrics.totalShots + 1
	
	-- Client-side effects
	CombatClient.PlayFireEffects(weapon)
	CombatClient.ApplyRecoil(weapon)
	CombatClient.UpdateCrosshair()
	
	-- Auto-reload when empty
	if combatState.currentAmmo <= 0 and combatState.reserveAmmo > 0 then
		CombatClient.RequestReload()
	end
end

-- Enhanced reload system
function CombatClient.RequestReload()
	if combatState.isReloading then return end
	if combatState.currentAmmo >= WeaponConfig[combatState.currentWeapon].MagazineSize then return end
	if combatState.reserveAmmo <= 0 then return end
	
	combatState.isReloading = true
	RequestReloadRemote:FireServer()
	
	-- Play reload sound and animation
	local weapon = WeaponConfig[combatState.currentWeapon]
	SoundManager.PlaySound("Reload_" .. combatState.currentWeapon)
	
	-- Reload timer
	spawn(function()
		wait(weapon.ReloadTime)
		local ammoToReload = math.min(
			weapon.MagazineSize - combatState.currentAmmo,
			combatState.reserveAmmo
		)
		
		combatState.currentAmmo = combatState.currentAmmo + ammoToReload
		combatState.reserveAmmo = combatState.reserveAmmo - ammoToReload
		combatState.isReloading = false
		
		CombatClient.UpdateHUD()
	end)
end

-- Weapon switching with validation
function CombatClient.SwitchWeapon(weaponId)
	local weapon = WeaponConfig[weaponId]
	if not weapon then return end
	if combatState.isReloading then return end
	
	combatState.currentWeapon = weaponId
	combatState.currentAmmo = weapon.MagazineSize
	combatState.reserveAmmo = weapon.MagazineSize * 4 -- 4 magazines
	
	SwitchWeaponRemote:FireServer(weaponId)
	SoundManager.PlaySound("WeaponSwitch")
	
	CombatClient.UpdateHUD()
	CombatClient.UpdateCrosshair()
end

-- Client-side hit registration for immediate feedback
function CombatClient.RegisterHit(hitResult)
	if hitResult.hit then
		performanceMetrics.shotsToHit = performanceMetrics.shotsToHit + 1
		performanceMetrics.consecutiveHits = performanceMetrics.consecutiveHits + 1
		performanceMetrics.consecutiveMisses = 0
		
		-- Report to server for validation
		ReportHitRemote:FireServer(
			hitResult.origin,
			hitResult.direction,
			hitResult.hitPosition,
			hitResult.hitPart,
			hitResult.distance
		)
		
		-- Play hit effects
		CombatClient.PlayHitEffects(hitResult)
	else
		performanceMetrics.consecutiveMisses = performanceMetrics.consecutiveMisses + 1
		performanceMetrics.consecutiveHits = 0
	end
	
	-- Update accuracy
	performanceMetrics.accuracy = (performanceMetrics.shotsToHit / performanceMetrics.totalShots) * 100
end

-- Visual and audio effects
function CombatClient.PlayFireEffects(weapon)
	-- Play weapon fire sound
	SoundManager.PlaySound("Fire_" .. weapon.Id)
	
	-- Flash effect
	CombatClient.CreateMuzzleFlash()
	
	-- Shell ejection
	CombatClient.EjectShell(weapon)
end

function CombatClient.CreateMuzzleFlash()
	-- Create brief muzzle flash effect
	local flash = Instance.new("PointLight")
	flash.Brightness = 2
	flash.Color = Color3.fromRGB(255, 200, 100)
	flash.Range = 10
	flash.Parent = camera
	
	local tween = TweenService:Create(flash, 
		TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Brightness = 0 }
	)
	
	tween:Play()
	tween.Completed:Connect(function()
		flash:Destroy()
	end)
end

function CombatClient.EjectShell(weapon)
	-- Create shell casing effect
	local shell = Instance.new("Part")
	shell.Size = Vector3.new(0.1, 0.05, 0.1)
	shell.Material = Enum.Material.Metal
	shell.Color = Color3.fromRGB(200, 180, 120)
	shell.CanCollide = false
	shell.Parent = workspace
	
	shell.CFrame = camera.CFrame * CFrame.new(0.2, -0.1, -0.5)
	
	-- Add physics
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
	bodyVelocity.Velocity = camera.CFrame:VectorToWorldSpace(Vector3.new(
		math.random(-5, 5),
		math.random(2, 8),
		math.random(-2, 2)
	))
	bodyVelocity.Parent = shell
	
	-- Clean up after 3 seconds
	game:GetService("Debris"):AddItem(shell, 3)
end

function CombatClient.PlayHitEffects(hitResult)
	-- Create hit spark/dust effect at hit position
	local effect = Instance.new("Explosion")
	effect.Size = 2
	effect.BlastRadius = 0
	effect.BlastPressure = 0
	effect.Position = hitResult.hitPosition
	effect.Parent = workspace
	
	-- Play hit sound
	SoundManager.PlaySound("BulletImpact")
end

-- Recoil application
function CombatClient.ApplyRecoil(weapon)
	RecoilClient.ApplyRecoil(weapon.Recoil.Vertical, weapon.Recoil.Horizontal)
	
	-- Update weapon sway
	combatState.weaponSway = combatState.weaponSway + Vector2.new(
		math.random(-weapon.Recoil.Horizontal, weapon.Recoil.Horizontal) * 0.5,
		weapon.Recoil.Vertical * 0.8
	)
end

-- Crosshair dynamics
function CombatClient.UpdateCrosshair()
	local weapon = WeaponConfig[combatState.currentWeapon]
	local baseSpread = weapon.Spread
	
	-- Factor in movement, aiming, and recent shots
	local movementFactor = inputState.lastMovementTime and tick() - inputState.lastMovementTime < 0.5 and 1.5 or 1.0
	local aimFactor = combatState.isAiming and 0.6 or 1.0
	local fireFactor = math.max(1.0, 3.0 - (tick() - combatState.lastFire))
	
	combatState.crosshairSpread = baseSpread * movementFactor * aimFactor * fireFactor
	
	-- Update UI crosshair size (would connect to HUD system)
	-- HUDManager.UpdateCrosshair(combatState.crosshairSpread)
end

-- HUD updates
function CombatClient.UpdateHUD()
	-- This would integrate with the HUD system
	-- For now, print to console for debugging
	print(string.format("Ammo: %d/%d | Weapon: %s | Accuracy: %.1f%%",
		combatState.currentAmmo,
		combatState.reserveAmmo,
		combatState.currentWeapon,
		performanceMetrics.accuracy
	))
end

-- Input handling
local function handleInput(input, gameProcessed)
	if gameProcessed then return end
	
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if input.UserInputState == Enum.UserInputState.Begin then
			inputState.leftMouseDown = true
		else
			inputState.leftMouseDown = false
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		if input.UserInputState == Enum.UserInputState.Begin then
			inputState.rightMouseDown = true
			combatState.isAiming = true
		else
			inputState.rightMouseDown = false
			combatState.isAiming = false
		end
	elseif input.KeyCode == Enum.KeyCode.R and input.UserInputState == Enum.UserInputState.Begin then
		CombatClient.RequestReload()
	elseif input.KeyCode then
		-- Track movement keys
		local movementKeys = {
			[Enum.KeyCode.W] = true,
			[Enum.KeyCode.A] = true,
			[Enum.KeyCode.S] = true,
			[Enum.KeyCode.D] = true
		}
		
		if movementKeys[input.KeyCode] then
			if input.UserInputState == Enum.UserInputState.Begin then
				inputState.wasdPressed[input.KeyCode] = true
				inputState.lastMovementTime = tick()
			else
				inputState.wasdPressed[input.KeyCode] = false
			end
		end
		
		-- Weapon switching
		if input.UserInputState == Enum.UserInputState.Begin then
			if input.KeyCode == Enum.KeyCode.One then
				CombatClient.SwitchWeapon("AssaultRifle")
			elseif input.KeyCode == Enum.KeyCode.Two then
				CombatClient.SwitchWeapon("SMG")
			elseif input.KeyCode == Enum.KeyCode.Three then
				CombatClient.SwitchWeapon("Shotgun")
			elseif input.KeyCode == Enum.KeyCode.Four then
				CombatClient.SwitchWeapon("Sniper")
			elseif input.KeyCode == Enum.KeyCode.Five then
				CombatClient.SwitchWeapon("Pistol")
			end
		end
	end
end

-- Auto-fire system
local autoFireConnection
local function startAutoFire()
	if autoFireConnection then return end
	
	autoFireConnection = RunService.Heartbeat:Connect(function()
		if inputState.leftMouseDown and combatState.fireMode == "auto" then
			fire()
		end
	end)
end

local function stopAutoFire()
	if autoFireConnection then
		autoFireConnection:Disconnect()
		autoFireConnection = nil
	end
end

-- Semi-auto fire
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	handleInput(input, gameProcessed)
	
	-- Single shot for semi-auto
	if input.UserInputType == Enum.UserInputType.MouseButton1 and not gameProcessed then
		if combatState.fireMode == "semi" then
			fire()
		elseif combatState.fireMode == "auto" then
			startAutoFire()
		end
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	handleInput(input, gameProcessed)
	
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		stopAutoFire()
	end
end)

-- Performance monitoring
spawn(function()
	while true do
		wait(5) -- Update every 5 seconds
		CombatClient.UpdateCrosshair()
		CombatClient.UpdateHUD()
	end
end)

-- Initialize
CombatClient.UpdateHUD()
print("[CombatClient] Enterprise combat system initialized")

return CombatClient
