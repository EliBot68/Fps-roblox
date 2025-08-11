--!strict
--[[
	@fileoverview Enhanced client-side types and interfaces for enterprise FPS system
	@author Enterprise Development Team
	@version 2.0.0
	@since Phase B Implementation
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatTypes = require(ReplicatedStorage.Shared.CombatTypes)

-- Re-export core types
export type WeaponId = CombatTypes.WeaponId
export type WeaponConfig = CombatTypes.WeaponConfig
export type WeaponInstance = CombatTypes.WeaponInstance
export type HitInfo = CombatTypes.HitInfo
export type InputConfig = CombatTypes.InputConfig

-- Client-specific types for enhanced functionality

--[[
	@interface NetworkProxy
	@description Secure wrapper for RemoteEvent/RemoteFunction communications
]]
export type NetworkProxy = {
	validatePayload: (self: NetworkProxy, payload: {[string]: any}) -> boolean,
	sanitizeData: (self: NetworkProxy, data: any) -> any,
	throttle: (self: NetworkProxy, action: string, cooldown: number) -> boolean,
	debounce: (self: NetworkProxy, action: string, delay: number) -> boolean,
	fireServer: (self: NetworkProxy, ...any) -> (),
	invokeServer: (self: NetworkProxy, ...any) -> any?
}

--[[
	@interface ClientWeaponState
	@description Enhanced weapon state for client-side prediction
]]
export type ClientWeaponState = {
	weaponInstance: WeaponInstance,
	lastFireTime: number,
	predictedAmmo: number,
	recoilOffset: Vector3,
	isReloading: boolean,
	reloadStartTime: number?,
	spreadAccumulation: number,
	lastInputTime: number,
	predictionBuffer: {PredictionFrame}
}

--[[
	@interface PredictionFrame
	@description Single frame of weapon prediction data
]]
export type PredictionFrame = {
	timestamp: number,
	ammo: number,
	recoil: Vector3,
	spread: number,
	isValid: boolean
}

--[[
	@interface UIManager
	@description Base interface for all UI controllers
]]
export type UIManager = {
	isInitialized: boolean,
	connections: {RBXScriptConnection},
	elements: {[string]: GuiObject},
	
	initialize: (self: UIManager) -> (),
	cleanup: (self: UIManager) -> (),
	show: (self: UIManager) -> (),
	hide: (self: UIManager) -> (),
	update: (self: UIManager, deltaTime: number) -> ()
}

--[[
	@interface InputHandler
	@description Enhanced input handling with platform adaptation
]]
export type InputHandler = {
	platform: "Desktop" | "Mobile" | "Gamepad" | "VR",
	bindings: {[string]: InputBinding},
	isEnabled: boolean,
	
	bind: (self: InputHandler, action: string, binding: InputBinding) -> (),
	unbind: (self: InputHandler, action: string) -> (),
	handleInput: (self: InputHandler, inputObject: InputObject, gameProcessed: boolean) -> (),
	cleanup: (self: InputHandler) -> ()
}

--[[
	@interface InputBinding
	@description Configuration for input actions
]]
export type InputBinding = {
	keyCode: Enum.KeyCode?,
	inputType: Enum.UserInputType?,
	callback: (actionName: string, inputState: Enum.UserInputState, inputObject: InputObject) -> (),
	throttleTime: number?,
	debounceTime: number?
}

--[[
	@interface PredictionSystem
	@description Client-side weapon prediction system
]]
export type PredictionSystem = {
	enabled: boolean,
	maxPredictionTime: number,
	reconciliationThreshold: number,
	
	predictFire: (self: PredictionSystem, weapon: ClientWeaponState, timestamp: number) -> PredictionFrame,
	reconcile: (self: PredictionSystem, serverState: WeaponInstance, timestamp: number) -> (),
	rollback: (self: PredictionSystem, timestamp: number) -> (),
	validatePrediction: (self: PredictionSystem, frame: PredictionFrame) -> boolean
}

--[[
	@interface AntiCheatClient
	@description Client-side anti-cheat validation
]]
export type AntiCheatClient = {
	lastValidationTime: number,
	suspiciousActivityCount: number,
	
	validateFireRate: (self: AntiCheatClient, weapon: WeaponConfig, lastFireTime: number) -> boolean,
	validateReloadTime: (self: AntiCheatClient, weapon: WeaponConfig, reloadStartTime: number) -> boolean,
	validateAmmoCount: (self: AntiCheatClient, weapon: ClientWeaponState) -> boolean,
	reportSuspiciousActivity: (self: AntiCheatClient, activityType: string, evidence: {[string]: any}) -> ()
}

--[[
	@interface EffectSystem
	@description Enhanced visual and audio effects system
]]
export type EffectSystem = {
	pools: {[string]: {Instance}},
	audioSources: {[string]: Sound},
	particleSystems: {[string]: ParticleEmitter},
	
	playEffect: (self: EffectSystem, effectId: string, position: Vector3, properties: {[string]: any}?) -> (),
	playSound: (self: EffectSystem, soundId: string, volume: number?, pitch: number?) -> (),
	createMuzzleFlash: (self: EffectSystem, weapon: WeaponConfig, position: Vector3, direction: Vector3) -> (),
	createBulletTrail: (self: EffectSystem, startPos: Vector3, endPos: Vector3, speed: number) -> (),
	cleanup: (self: EffectSystem) -> ()
}

--[[
	@interface MobileInterface
	@description Mobile-optimized UI and input interface
]]
export type MobileInterface = {
	touchControls: {[string]: GuiButton},
	gestureRecognizer: any, -- Custom gesture recognition system
	hapticFeedback: boolean,
	
	setupTouchControls: (self: MobileInterface) -> (),
	handleTouchInput: (self: MobileInterface, touch: InputObject, gameProcessed: boolean) -> (),
	provideFeedback: (self: MobileInterface, feedbackType: "light" | "medium" | "heavy") -> (),
	adaptToScreenSize: (self: MobileInterface) -> ()
}

--[[
	@interface AccessibilitySystem
	@description Accessibility and inclusive design features
]]
export type AccessibilitySystem = {
	colorblindMode: "None" | "Protanopia" | "Deuteranopia" | "Tritanopia",
	highContrast: boolean,
	reducedMotion: boolean,
	
	applyColorblindFilter: (self: AccessibilitySystem, element: GuiObject) -> (),
	enableHighContrast: (self: AccessibilitySystem) -> (),
	reduceMotionEffects: (self: AccessibilitySystem) -> (),
	announceToScreenReader: (self: AccessibilitySystem, message: string) -> ()
}

--[[
	@interface PerformanceMonitor
	@description Client-side performance monitoring and optimization
]]
export type PerformanceMonitor = {
	frameRate: number,
	memory: number,
	networkLatency: number,
	
	startProfiling: (self: PerformanceMonitor) -> (),
	stopProfiling: (self: PerformanceMonitor) -> (),
	getMetrics: (self: PerformanceMonitor) -> {[string]: number},
	optimizeForDevice: (self: PerformanceMonitor) -> ()
}

return {}
