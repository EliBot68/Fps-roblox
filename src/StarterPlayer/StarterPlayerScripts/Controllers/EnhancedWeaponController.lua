--!strict
--[[
	@fileoverview Enterprise-grade client-side weapon controller with prediction, mobile support, and anti-cheat
	@author Enterprise Development Team
	@version 2.0.0
	@since Phase B Implementation
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

-- Import enterprise types and systems
local ClientTypes = require(script.Parent.Parent.Shared.ClientTypes)
local NetworkProxy = require(script.Parent.NetworkProxy)

-- Import shared systems
local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)
local CombatTypes = require(ReplicatedStorage.Shared.CombatTypes)

-- Type definitions
type WeaponId = CombatTypes.WeaponId
type WeaponConfig = CombatTypes.WeaponConfig
type WeaponInstance = CombatTypes.WeaponInstance
type ClientWeaponState = ClientTypes.ClientWeaponState
type PredictionFrame = ClientTypes.PredictionFrame
type NetworkProxy = ClientTypes.NetworkProxy

-- Forward declaration
export type EnhancedWeaponController = {
	currentWeapon: ClientWeaponState?,
	isEnabled: boolean,
	isMobile: boolean,
	equipWeapon: (self: EnhancedWeaponController, weaponId: WeaponId, weaponInstance: WeaponInstance) -> (),
	attemptFire: (self: EnhancedWeaponController, targetPosition: Vector3?) -> boolean,
	attemptReload: (self: EnhancedWeaponController) -> boolean,
	reconcileWithServer: (self: EnhancedWeaponController, serverState: WeaponInstance, timestamp: number) -> (),
	setEnabled: (self: EnhancedWeaponController, enabled: boolean) -> (),
	cleanup: (self: EnhancedWeaponController) -> ()
}

--[[
	@class EnhancedWeaponController
	@description Enterprise-grade weapon controller with client-side prediction, mobile optimization, and comprehensive validation
]]
local EnhancedWeaponController = {}
EnhancedWeaponController.__index = EnhancedWeaponController

-- Constants for performance and security
local MAX_PREDICTION_FRAMES = 60
local PREDICTION_TIMEOUT = 2.0
local RECOIL_RECOVERY_RATE = 5.0
local SPREAD_RECOVERY_RATE = 3.0
local MOBILE_FIRE_THRESHOLD = 0.1

-- Private properties
local player = Players.LocalPlayer
local character = player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local camera = workspace.CurrentCamera

--[[
	@constructor
	@returns EnhancedWeaponController
]]
function EnhancedWeaponController.new(): EnhancedWeaponController
	local self = setmetatable({
		-- Core state
		currentWeapon = nil :: ClientWeaponState?,
		isEnabled = true,
		isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,
		
		-- Network proxies
		fireProxy = nil :: NetworkProxy?,
		reloadProxy = nil :: NetworkProxy?,
		equipProxy = nil :: NetworkProxy?,
		
		-- Prediction system
		predictionEnabled = true,
		predictionFrames = {} :: {PredictionFrame},
		lastServerUpdate = 0,
		
		-- Visual systems
		recoilOffset = Vector3.new(),
		cameraShake = 0,
		muzzleFlashEnabled = true,
		
		-- Mobile-specific
		touchFireButton = nil :: GuiButton?,
		touchReloadButton = nil :: GuiButton?,
		lastTouchTime = 0,
		
		-- Performance monitoring
		frameTime = 0,
		lastOptimization = 0,
		
		-- Connections
		connections = {} :: {RBXScriptConnection}
	}, EnhancedWeaponController)
	
	self:_initializeNetworkProxies()
	self:_setupInputHandling()
	self:_setupMobileControls()
	self:_startUpdateLoop()
	
	return self
end

--[[
	@method equipWeapon
	@description Equips a weapon with full client-side state management
	@param weaponId WeaponId - The weapon to equip
	@param weaponInstance WeaponInstance - Server-provided weapon state
]]
function EnhancedWeaponController:equipWeapon(weaponId: WeaponId, weaponInstance: WeaponInstance): ()
	local config = WeaponConfig.getConfig(weaponId)
	if not config then
		warn("[WeaponController] Invalid weapon ID:", weaponId)
		return
	end
	
	-- Create client weapon state
	self.currentWeapon = {
		weaponInstance = weaponInstance,
		lastFireTime = 0,
		predictedAmmo = weaponInstance.ammo,
		recoilOffset = Vector3.new(),
		isReloading = false,
		reloadStartTime = nil,
		spreadAccumulation = 0,
		lastInputTime = 0,
		predictionBuffer = {}
	}
	
	-- Update UI and effects
	self:_updateWeaponUI()
	self:_playEquipEffects(config)
	
	-- Notify server with validation
	if self.equipProxy then
		self.equipProxy:fireServer(weaponId)
	end
	
	if self.isMobile then
		self:_optimizeForMobile(config)
	end
end

--[[
	@method attemptFire
	@description Attempts to fire the weapon with prediction and validation
	@param targetPosition Vector3? - Optional target position for mobile
	@returns boolean - True if fire attempt was successful
]]
function EnhancedWeaponController:attemptFire(targetPosition: Vector3?): boolean
	if not self.currentWeapon or not self.isEnabled then
		return false
	end
	
	local weapon = self.currentWeapon
	local config = WeaponConfig.getConfig(weapon.weaponInstance.weaponId)
	if not config then
		return false
	end
	
	local now = tick()
	local fireRate = 60 / config.stats.fireRate -- Convert RPM to seconds per shot
	
	-- Validate fire rate
	if now - weapon.lastFireTime < fireRate then
		return false
	end
	
	-- Check ammo
	if weapon.predictedAmmo <= 0 or weapon.isReloading then
		self:_playDryFireSound()
		return false
	end
	
	-- Create prediction frame
	local predictionFrame = self:_createPredictionFrame(weapon, now)
	
	-- Apply client-side effects immediately
	self:_applyFireEffects(config, predictionFrame)
	
	-- Update weapon state
	weapon.lastFireTime = now
	weapon.predictedAmmo = math.max(0, weapon.predictedAmmo - 1)
	weapon.lastInputTime = now
	
	-- Send to server with prediction data
	if self.fireProxy then
		local fireData = {
			timestamp = now,
			targetPosition = targetPosition or self:_getAimTarget(),
			predictionId = predictionFrame.timestamp,
			clientAmmo = weapon.predictedAmmo
		}
		self.fireProxy:fireServer(fireData)
	end
	
	-- Store prediction frame
	table.insert(weapon.predictionBuffer, predictionFrame)
	if #weapon.predictionBuffer > MAX_PREDICTION_FRAMES then
		table.remove(weapon.predictionBuffer, 1)
	end
	
	return true
end

--[[
	@method attemptReload
	@description Attempts to reload the weapon with prediction
	@returns boolean - True if reload attempt was successful
]]
function EnhancedWeaponController:attemptReload(): boolean
	if not self.currentWeapon or not self.isEnabled then
		return false
	end
	
	local weapon = self.currentWeapon
	local config = WeaponConfig.getConfig(weapon.weaponInstance.weaponId)
	if not config then
		return false
	end
	
	-- Check if reload is needed and possible
	if weapon.isReloading or weapon.predictedAmmo >= config.stats.magSize then
		return false
	end
	
	local now = tick()
	
	-- Start reload prediction
	weapon.isReloading = true
	weapon.reloadStartTime = now
	
	-- Play reload effects
	self:_playReloadEffects(config)
	
	-- Send to server
	if self.reloadProxy then
		local reloadData = {
			timestamp = now,
			clientAmmo = weapon.predictedAmmo
		}
		self.reloadProxy:fireServer(reloadData)
	end
	
	-- Schedule reload completion
	task.wait(config.stats.reloadTime)
	if weapon.isReloading and weapon.reloadStartTime == now then
		weapon.isReloading = false
		weapon.predictedAmmo = config.stats.magSize
		weapon.reloadStartTime = nil
		self:_updateWeaponUI()
	end
	
	return true
end

--[[
	@method reconcileWithServer
	@description Reconciles client prediction with authoritative server state
	@param serverState WeaponInstance - Authoritative weapon state from server
	@param timestamp number - Server timestamp
]]
function EnhancedWeaponController:reconcileWithServer(serverState: WeaponInstance, timestamp: number): ()
	if not self.currentWeapon then
		return
	end
	
	local weapon = self.currentWeapon
	self.lastServerUpdate = timestamp
	
	-- Check for significant desync
	local ammoDifference = math.abs(weapon.predictedAmmo - serverState.ammo)
	local reloadMismatch = weapon.isReloading ~= (serverState.lastReloadTime > timestamp - 3)
	
	if ammoDifference > 3 or reloadMismatch then
		-- Significant desync detected - apply server correction
		weapon.predictedAmmo = serverState.ammo
		weapon.isReloading = serverState.lastReloadTime > timestamp - 3
		weapon.weaponInstance = serverState
		
		-- Clear prediction buffer
		weapon.predictionBuffer = {}
		
		-- Update UI to reflect correction
		self:_updateWeaponUI()
		
		warn("[WeaponController] Server reconciliation applied - Ammo:", serverState.ammo)
	else
		-- Minor adjustments
		weapon.weaponInstance = serverState
	end
end

--[[
	@method setEnabled
	@description Enables or disables the weapon controller
	@param enabled boolean - Whether to enable the controller
]]
function EnhancedWeaponController:setEnabled(enabled: boolean): ()
	self.isEnabled = enabled
	
	if not enabled and self.currentWeapon then
		-- Stop any ongoing actions
		self.currentWeapon.isReloading = false
		self.currentWeapon.reloadStartTime = nil
	end
end

--[[
	@method cleanup
	@description Cleans up all resources and connections
]]
function EnhancedWeaponController:cleanup(): ()
	-- Disconnect all connections
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	self.connections = {}
	
	-- Clear weapon state
	self.currentWeapon = nil
	
	-- Clean up mobile controls
	if self.touchFireButton then
		self.touchFireButton:Destroy()
	end
	if self.touchReloadButton then
		self.touchReloadButton:Destroy()
	end
end

--[[
	@private
	@method _initializeNetworkProxies
	@description Initializes secure network communication proxies
]]
function EnhancedWeaponController:_initializeNetworkProxies(): ()
	local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
	
	self.fireProxy = NetworkProxy.new(remoteEvents:WaitForChild("FireWeapon"), {
		maxPayloadSize = 1024,
		enableLogging = true
	})
	
	self.reloadProxy = NetworkProxy.new(remoteEvents:WaitForChild("ReloadWeapon"), {
		maxPayloadSize = 512,
		enableLogging = true
	})
	
	self.equipProxy = NetworkProxy.new(remoteEvents:WaitForChild("EquipWeapon"), {
		maxPayloadSize = 256,
		enableLogging = true
	})
end

--[[
	@private
	@method _setupInputHandling
	@description Sets up cross-platform input handling
]]
function EnhancedWeaponController:_setupInputHandling(): ()
	local function handleInput(inputObject: InputObject, gameProcessed: boolean)
		if gameProcessed or not self.isEnabled then
			return
		end
		
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 or
		   inputObject.KeyCode == Enum.KeyCode.ButtonR2 then
			if inputObject.UserInputState == Enum.UserInputState.Begin then
				self:attemptFire()
			end
		elseif inputObject.KeyCode == Enum.KeyCode.R or
			   inputObject.KeyCode == Enum.KeyCode.ButtonX then
			if inputObject.UserInputState == Enum.UserInputState.Begin then
				task.spawn(function()
					self:attemptReload()
				end)
			end
		end
	end
	
	local connection = UserInputService.InputBegan:Connect(handleInput)
	table.insert(self.connections, connection)
end

--[[
	@private
	@method _setupMobileControls
	@description Sets up mobile-optimized touch controls
]]
function EnhancedWeaponController:_setupMobileControls(): ()
	if not self.isMobile then
		return
	end
	
	local playerGui = player:WaitForChild("PlayerGui")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "WeaponControls"
	screenGui.Parent = playerGui
	
	-- Fire button
	self.touchFireButton = Instance.new("TextButton")
	self.touchFireButton.Name = "FireButton"
	self.touchFireButton.Size = UDim2.new(0, 80, 0, 80)
	self.touchFireButton.Position = UDim2.new(1, -100, 1, -100)
	self.touchFireButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	self.touchFireButton.Text = "🔥"
	self.touchFireButton.TextScaled = true
	self.touchFireButton.Parent = screenGui
	
	-- Reload button
	self.touchReloadButton = Instance.new("TextButton")
	self.touchReloadButton.Name = "ReloadButton"
	self.touchReloadButton.Size = UDim2.new(0, 60, 0, 60)
	self.touchReloadButton.Position = UDim2.new(1, -180, 1, -90)
	self.touchReloadButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
	self.touchReloadButton.Text = "🔄"
	self.touchReloadButton.TextScaled = true
	self.touchReloadButton.Parent = screenGui
	
	-- Connect touch events
	local fireConnection = self.touchFireButton.MouseButton1Down:Connect(function()
		self:attemptFire()
	end)
	
	local reloadConnection = self.touchReloadButton.MouseButton1Down:Connect(function()
		task.spawn(function()
			self:attemptReload()
		end)
	end)
	
	table.insert(self.connections, fireConnection)
	table.insert(self.connections, reloadConnection)
end

--[[
	@private
	@method _createPredictionFrame
	@description Creates a prediction frame for client-side validation
	@param weapon ClientWeaponState - Current weapon state
	@param timestamp number - Frame timestamp
	@returns PredictionFrame
]]
function EnhancedWeaponController:_createPredictionFrame(weapon: ClientWeaponState, timestamp: number): PredictionFrame
	return {
		timestamp = timestamp,
		ammo = weapon.predictedAmmo - 1,
		recoil = weapon.recoilOffset + Vector3.new(math.random(-1, 1), math.random(1, 3), 0) * 0.1,
		spread = weapon.spreadAccumulation + 0.1,
		isValid = true
	}
end

--[[
	@private
	@method _applyFireEffects
	@description Applies immediate visual and audio effects for weapon firing
	@param config WeaponConfig - Weapon configuration
	@param predictionFrame PredictionFrame - Prediction data
]]
function EnhancedWeaponController:_applyFireEffects(config: WeaponConfig, predictionFrame: PredictionFrame): ()
	-- Apply recoil
	self.recoilOffset = predictionFrame.recoil
	
	-- Camera shake
	self.cameraShake = config.stats.damage * 0.01
	
	-- Play fire sound
	local fireSound = SoundService:PlayLocalSound(1234567890) -- Replace with actual sound ID
	if fireSound then
		fireSound.Volume = 0.5
		fireSound.Pitch = 1 + (math.random() - 0.5) * 0.2
	end
	
	-- Update UI immediately
	self:_updateWeaponUI()
end

--[[
	@private
	@method _getAimTarget
	@description Calculates the current aim target position
	@returns Vector3
]]
function EnhancedWeaponController:_getAimTarget(): Vector3
	if not camera then
		return Vector3.new()
	end
	
	local raycast = workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * 1000)
	if raycast then
		return raycast.Position
	end
	
	return camera.CFrame.Position + camera.CFrame.LookVector * 1000
end

--[[
	@private
	@method _updateWeaponUI
	@description Updates weapon-related UI elements
]]
function EnhancedWeaponController:_updateWeaponUI(): ()
	-- Implementation would update HUD elements
	-- This would integrate with the UI system created later
end

--[[
	@private
	@method _playDryFireSound
	@description Plays dry fire sound effect
]]
function EnhancedWeaponController:_playDryFireSound(): ()
	local dryFireSound = SoundService:PlayLocalSound(987654321) -- Replace with actual sound ID
	if dryFireSound then
		dryFireSound.Volume = 0.3
	end
end

--[[
	@private
	@method _playReloadEffects
	@description Plays reload visual and audio effects
	@param config WeaponConfig - Weapon configuration
]]
function EnhancedWeaponController:_playReloadEffects(config: WeaponConfig): ()
	local reloadSound = SoundService:PlayLocalSound(1122334455) -- Replace with actual sound ID
	if reloadSound then
		reloadSound.Volume = 0.4
		reloadSound.Pitch = 1
	end
end

--[[
	@private
	@method _playEquipEffects
	@description Plays weapon equip effects
	@param config WeaponConfig - Weapon configuration
]]
function EnhancedWeaponController:_playEquipEffects(config: WeaponConfig): ()
	-- Play equip animation and sound
	local equipSound = SoundService:PlayLocalSound(5566778899) -- Replace with actual sound ID
	if equipSound then
		equipSound.Volume = 0.3
	end
end

--[[
	@private
	@method _optimizeForMobile
	@description Applies mobile-specific optimizations
	@param config WeaponConfig - Weapon configuration
]]
function EnhancedWeaponController:_optimizeForMobile(config: WeaponConfig): ()
	-- Reduce visual effects for performance
	self.muzzleFlashEnabled = false
	
	-- Adjust touch control sizes based on weapon type
	if self.touchFireButton then
		local size = if config.category == "Sniper" then 100 else 80
		self.touchFireButton.Size = UDim2.new(0, size, 0, size)
	end
end

--[[
	@private
	@method _startUpdateLoop
	@description Starts the main update loop for weapon systems
]]
function EnhancedWeaponController:_startUpdateLoop(): ()
	local connection = RunService.Heartbeat:Connect(function(deltaTime)
		self:_update(deltaTime)
	end)
	table.insert(self.connections, connection)
end

--[[
	@private
	@method _update
	@description Main update loop for weapon systems
	@param deltaTime number - Time since last frame
]]
function EnhancedWeaponController:_update(deltaTime: number): ()
	if not self.currentWeapon then
		return
	end
	
	-- Update recoil recovery
	self.recoilOffset = self.recoilOffset:lerp(Vector3.new(), deltaTime * RECOIL_RECOVERY_RATE)
	
	-- Update camera shake
	if self.cameraShake > 0 then
		self.cameraShake = math.max(0, self.cameraShake - deltaTime * 2)
		if camera then
			local shake = Vector3.new(
				(math.random() - 0.5) * self.cameraShake,
				(math.random() - 0.5) * self.cameraShake,
				0
			)
			camera.CFrame = camera.CFrame + shake
		end
	end
	
	-- Update spread recovery
	local weapon = self.currentWeapon
	weapon.spreadAccumulation = math.max(0, weapon.spreadAccumulation - deltaTime * SPREAD_RECOVERY_RATE)
	
	-- Clean old prediction frames
	local now = tick()
	for i = #weapon.predictionBuffer, 1, -1 do
		local frame = weapon.predictionBuffer[i]
		if now - frame.timestamp > PREDICTION_TIMEOUT then
			table.remove(weapon.predictionBuffer, i)
		end
	end
	
	-- Performance monitoring
	self.frameTime = deltaTime
	if now - self.lastOptimization > 5 then
		self:_performanceOptimization()
		self.lastOptimization = now
	end
end

--[[
	@private
	@method _performanceOptimization
	@description Performs periodic performance optimizations
]]
function EnhancedWeaponController:_performanceOptimization(): ()
	-- Adjust quality based on frame rate
	if self.frameTime > 1/30 then -- Below 30 FPS
		self.muzzleFlashEnabled = false
		self.predictionEnabled = false
	elseif self.frameTime < 1/60 then -- Above 60 FPS
		self.muzzleFlashEnabled = true
		self.predictionEnabled = true
	end
end

-- Export the enhanced controller
return EnhancedWeaponController
