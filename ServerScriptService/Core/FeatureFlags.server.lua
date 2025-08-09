-- FeatureFlags.server.lua
-- Simple in-memory feature flag system (extend to MemoryStore for dynamic changes)

local FeatureFlags = {}

local flags = {
	EnableDailyChallenges = false,
	EnableAdvancedAntiCheat = false,
	EnableSpectatorMode = false,
	EnableTournament = false,
}

function FeatureFlags.IsEnabled(name)
	return flags[name] == true
end

function FeatureFlags.Set(name, value)
	flags[name] = value and true or false
end

function FeatureFlags.All()
	return flags
end

function FeatureFlags.Init()
	-- Could load persisted config
end

return FeatureFlags
