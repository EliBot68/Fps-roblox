--!strict
--[[
	Combat System Types
	Comprehensive type definitions for the enterprise combat system
]]

-- Core Combat Types
export type PlayerId = number
export type WeaponId = string
export type AttachmentId = string

export type Vector3 = {
	X: number,
	Y: number, 
	Z: number
}

export type CFrame = {
	Position: Vector3,
	LookVector: Vector3,
	RightVector: Vector3,
	UpVector: Vector3
}

-- Weapon System Types
export type WeaponCategory = "AssaultRifle" | "SniperRifle" | "SMG" | "Shotgun" | "Pistol" | "LMG" | "Melee"
export type WeaponRarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"
export type DamageType = "Bullet" | "Explosive" | "Melee" | "Fire" | "Poison"

export type WeaponStats = {
	damage: number,
	headshotMultiplier: number,
	fireRate: number, -- rounds per minute
	reloadTime: number,
	magazineSize: number,
	maxAmmo: number,
	range: number,
	accuracy: number, -- 0-1
	recoilPattern: {Vector3},
	damageDropoff: {[number]: number}, -- distance -> multiplier
	penetration: number, -- 0-1
	muzzleVelocity: number, -- studs/second
	weight: number
}

export type WeaponConfig = {
	id: WeaponId,
	name: string,
	displayName: string,
	description: string,
	category: WeaponCategory,
	rarity: WeaponRarity,
	stats: WeaponStats,
	attachmentSlots: {[AttachmentType]: boolean},
	unlockLevel: number,
	cost: number,
	modelId: string,
	iconId: string,
	sounds: WeaponSounds,
	animations: WeaponAnimations,
	effects: WeaponEffects
}

export type AttachmentType = "Scope" | "Barrel" | "Grip" | "Magazine" | "Stock" | "Muzzle" | "Laser" | "Light"

export type AttachmentConfig = {
	id: AttachmentId,
	name: string,
	displayName: string,
	type: AttachmentType,
	rarity: WeaponRarity,
	statModifiers: {[string]: number}, -- stat name -> modifier
	compatibleWeapons: {[WeaponId]: boolean},
	unlockLevel: number,
	cost: number,
	modelId: string,
	iconId: string
}

export type WeaponSounds = {
	fire: string,
	dryFire: string,
	reload: string,
	reloadEmpty: string,
	draw: string,
	holster: string,
	hit: string,
	miss: string
}

export type WeaponAnimations = {
	idle: string,
	fire: string,
	reload: string,
	reloadEmpty: string,
	draw: string,
	holster: string,
	inspect: string,
	melee: string
}

export type WeaponEffects = {
	muzzleFlash: string,
	shellEject: string,
	bulletTrail: string,
	impactEffects: {[string]: string}, -- material -> effect
	smokePuff: string
}

-- Combat State Types
export type LoadoutData = {
	primaryWeapon: string?,
	secondaryWeapon: string?,
	utilityItem: string?,
	equipment: {[string]: any}?
}

export type WeaponInstance = {
	config: WeaponConfig,
	attachments: {[AttachmentType]: AttachmentId?},
	currentAmmo: number,
	totalAmmo: number,
	condition: number, -- 0-1, affects stats
	kills: number,
	experience: number,
	level: number,
	lastFired: number,
	isReloading: boolean,
	owner: PlayerId?
}

export type CombatState = {
	equippedWeapons: {[number]: WeaponInstance?}, -- slot -> weapon
	activeSlot: number,
	isInCombat: boolean,
	lastDamageTime: number,
	health: number,
	maxHealth: number,
	shield: number,
	maxShield: number,
	kills: number,
	deaths: number,
	assists: number,
	damageDealt: number,
	damageTaken: number,
	accuracy: number,
	headshotRate: number
}

-- Hit Detection Types
export type HitInfo = {
	shooter: PlayerId,
	target: PlayerId?,
	weapon: WeaponId,
	hitPosition: Vector3,
	hitNormal: Vector3,
	damage: number,
	isHeadshot: boolean,
	distance: number,
	timestamp: number,
	validated: boolean
}

export type ShotData = {
	shooter: PlayerId,
	weapon: WeaponId,
	origin: Vector3,
	direction: Vector3,
	timestamp: number,
	clientTimestamp: number,
	spread: number,
	prediction: boolean
}

export type RaycastResult = {
	hit: boolean,
	position: Vector3,
	normal: Vector3,
	instance: Instance?,
	material: Enum.Material?,
	distance: number
}

-- Ballistics Types
export type BulletData = {
	position: Vector3,
	velocity: Vector3,
	damage: number,
	penetration: number,
	gravity: number,
	airResistance: number,
	maxDistance: number,
	travelTime: number,
	shooter: PlayerId,
	weapon: WeaponId
}

export type BallisticsConfig = {
	gravity: number, -- studs/s²
	airDensity: number,
	windSpeed: Vector3,
	temperature: number, -- affects air density
	humidity: number -- affects air density
}

-- Anti-Cheat Types
export type SuspiciousActivity = {
	playerId: PlayerId,
	activityType: "Aimbot" | "Wallhack" | "SpeedHack" | "RapidFire" | "NoRecoil",
	severity: number, -- 0-1
	evidence: {[string]: any},
	timestamp: number,
	confidence: number -- 0-1
}

export type PlayerStatistics = {
	playerId: PlayerId,
	totalShots: number,
	shotsHit: number,
	headshots: number,
	avgReactionTime: number,
	avgAccuracy: number,
	suspicionLevel: number,
	flaggedActivities: {SuspiciousActivity}
}

-- Mobile/Accessibility Types
export type InputConfig = {
	sensitivity: number,
	invertY: boolean,
	autoFire: boolean,
	aimAssist: boolean,
	hapticFeedback: boolean,
	crosshairStyle: string,
	crosshairColor: Color3,
	fov: number,
	controlScheme: "Default" | "Claw" | "Custom"
}

export type AccessibilityConfig = {
	colorblindMode: "None" | "Protanopia" | "Deuteranopia" | "Tritanopia",
	highContrast: boolean,
	reducedMotion: boolean,
	largeText: boolean,
	audioDescription: boolean,
	subtitles: boolean
}

-- Network Types
export type CombatEvent = {
	type: "Fire" | "Hit" | "Reload" | "Equip" | "Kill",
	playerId: PlayerId,
	data: {[string]: any},
	timestamp: number,
	sequence: number
}

export type NetworkPacket = {
	events: {CombatEvent},
	checksum: string,
	compression: boolean,
	priority: "Low" | "Medium" | "High" | "Critical"
}

-- Analytics Types
export type CombatMetrics = {
	totalKills: number,
	totalDeaths: number,
	kdr: number,
	avgDamagePerMatch: number,
	weaponUsage: {[WeaponId]: number},
	mapPerformance: {[string]: number},
	sessionLength: number,
	matchesPlayed: number
}

export type ServerMetrics = {
	averageLatency: number,
	packetLoss: number,
	hitRegistration: number,
	serverFPS: number,
	memoryUsage: number,
	activePlayers: number,
	combatEvents: number
}

return {}
