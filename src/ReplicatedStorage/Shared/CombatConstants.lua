--!strict
--[[
	CombatConstants.lua
	Centralized combat system constants to prevent drift and ensure consistency
]]

local CombatConstants = {}

-- Distance and Range Constants
CombatConstants.MAX_SHOT_DISTANCE = 1000 -- Maximum valid shot distance (studs)
CombatConstants.MAX_HIT_DISTANCE = 1000 -- Maximum valid hit distance (studs)
CombatConstants.WEAPON_PICKUP_RADIUS = 10 -- Weapon pickup radius (studs)
CombatConstants.WEAPON_DROP_VELOCITY = 10 -- Initial drop velocity (studs/sec)

-- Timing Constants
CombatConstants.LAG_COMPENSATION_WINDOW = 0.3 -- Maximum lag compensation (seconds)
CombatConstants.HIT_VALIDATION_WINDOW = 0.5 -- Hit validation window (seconds)
CombatConstants.WEAPON_DESPAWN_TIME = 30 -- Weapon despawn time (seconds)
CombatConstants.RESPAWN_LOADOUT_DELAY = 2.0 -- Delay before giving loadout (seconds)

-- Performance Constants
CombatConstants.MAX_SHOTS_PER_SECOND = 20 -- Anti-spam limit
CombatConstants.MAX_PENETRATIONS = 3 -- Maximum bullet penetrations
CombatConstants.CLEANUP_INTERVAL = 5.0 -- Data cleanup interval (seconds)
CombatConstants.HIT_CACHE_TIMEOUT = 10 -- Hit cache timeout (seconds)
CombatConstants.HIT_CACHE_MAX_SIZE = 100 -- Maximum hits to cache per player

-- Combat Mechanics
CombatConstants.HITBOX_EXPANSION = 0.2 -- Lag compensation hitbox expansion (studs)
CombatConstants.HEAD_HITBOX_MULTIPLIER = 1.2 -- Head hitbox size multiplier
CombatConstants.PENETRATION_DAMAGE_REDUCTION = 0.85 -- Damage reduction per penetration
CombatConstants.MIN_PENETRATION_THICKNESS = 0.1 -- Minimum thickness for penetration (studs)
CombatConstants.MAX_PENETRABLE_THICKNESS = 2.0 -- Maximum thickness that can be penetrated (studs)

-- Fire Rate Constants
CombatConstants.FIRE_RATE_TOLERANCE = 0.95 -- Server fire rate tolerance (95% of max rate)
CombatConstants.MIN_DAMAGE = 1 -- Minimum damage that can be dealt

-- Weapon System Constants
CombatConstants.MAX_WEAPONS_PER_PLAYER = 3 -- Maximum weapons a player can carry
CombatConstants.DEFAULT_WEAPON_CONDITION = 1.0 -- Default weapon condition (0-1)
CombatConstants.MIN_WEAPON_CONDITION = 0.1 -- Minimum usable weapon condition

-- Network Constants
CombatConstants.MAX_PING_COMPENSATION = 200 -- Maximum ping to compensate for (ms)
CombatConstants.LATENCY_SAMPLE_SIZE = 10 -- Number of latency samples for rolling average

-- Ordered distance breakpoints for deterministic damage falloff
-- Format: {distance, multiplier} pairs in ascending distance order
CombatConstants.DAMAGE_FALLOFF_POINTS = {
	{0, 1.0},     -- Point blank
	{25, 0.95},   -- Close range
	{50, 0.9},    -- Medium range
	{100, 0.8},   -- Long range
	{200, 0.65},  -- Very long range
	{500, 0.4},   -- Extreme range
	{1000, 0.2}   -- Maximum range
}

-- Material penetration properties
CombatConstants.PENETRABLE_MATERIALS = {
	[Enum.Material.Wood] = true,
	[Enum.Material.Plastic] = true,
	[Enum.Material.Glass] = true,
	[Enum.Material.Ice] = true,
	[Enum.Material.Cardboard] = true,
	[Enum.Material.Fabric] = true
}

-- Get damage multiplier for distance using ordered breakpoints
function CombatConstants.GetDamageMultiplierForDistance(distance: number): number
	local multiplier = 1.0
	
	-- Find the appropriate breakpoint using binary search for performance
	local breakpoints = CombatConstants.DAMAGE_FALLOFF_POINTS
	for i = 1, #breakpoints do
		local breakpoint = breakpoints[i]
		if distance >= breakpoint[1] then
			multiplier = breakpoint[2]
		else
			break
		end
	end
	
	return multiplier
end

-- Validate if material can be penetrated
function CombatConstants.CanPenetrateMaterial(material: Enum.Material): boolean
	return CombatConstants.PENETRABLE_MATERIALS[material] == true
end

return CombatConstants
