-- GameConfig.lua
-- Enterprise-level game configuration with all systems integrated

local GameConfig = {
	-- Core game mechanics
	Match = {
		MinPlayers = 2,
		MaxPlayers = 8,
		LengthSeconds = 180,
		OvertimeSeconds = 60,
		WarmupSeconds = 30,
		EndGameDelaySeconds = 10,
	},
	
	-- Player systems
	Respawn = {
		Delay = 3,
		SafeZoneRadius = 10,
		InvulnerabilityTime = 2,
	},
	
	-- Combat balance
	Combat = {
		HeadshotMultiplier = 1.5,
		LegShotMultiplier = 0.8,
		MaxHitDistance = 1000,
		BulletDropEnabled = true,
		FriendlyFireEnabled = false,
	},
	
	-- Economy and progression
	Economy = {
		KillReward = 50,
		WinReward = 100,
		LossReward = 25,
		StreakBonusMultiplier = 1.2,
		DailyChallengeReward = 200,
		RankedBonusMultiplier = 1.5,
	},
	
	-- Ranking system
	Ranking = {
		DefaultElo = 1000,
		MaxEloGain = 50,
		MaxEloLoss = 40,
		PlacementMatches = 10,
		SeasonDurationDays = 90,
		DecayThresholdDays = 14,
	},
	
	-- Anti-cheat thresholds
	AntiCheat = {
		MaxShotDistance = 1000,
		MaxFireRate = 20, -- shots per second
		MaxMoveSpeed = 50,
		SuspiciousAccuracyThreshold = 0.95,
		AutobanThreshold = 0.99,
		ReportCooldown = 30,
	},
	
	-- Performance monitoring
	Performance = {
		MaxServerMemoryMB = 2000,
		MinServerFPS = 10,
		MaxLatencyMS = 300,
		ErrorRateThreshold = 10,
		CrashRateThreshold = 3,
		MetricsIntervalSeconds = 30,
	},
	
	-- Clan system
	Clans = {
		MaxMembers = 20,
		MinMembersForBattle = 3,
		BattleDurationMinutes = 10,
		ChallengeExpiryHours = 24,
		ClanCreationCost = 1000,
		MaxActiveInvites = 5,
	},
	
	-- Feature flags for A/B testing
	Features = {
		NewWeaponBalance = false,
		EnhancedAntiCheat = true,
		TournamentMode = false,
		SpectatorMode = true,
		ReplaySystem = true,
		AdvancedMetrics = true,
		SessionMigration = true,
		CompetitiveMode = true,
	},
	
	-- Maps and spawning
	Maps = {
		VillageSpawnEnabled = true,
		RandomSpawnRadius = 5,
		CompetitiveMapRotation = true,
		MapVotingEnabled = false,
		SpawnProtectionTime = 3,
	},
	
	-- UI and UX
	UI = {
		ShowKillFeed = true,
		ShowLeaderboard = true,
		ShowMinimap = false,
		ChatEnabled = true,
		VoiceChatEnabled = false,
		CrosshairCustomization = true,
	},
	
	-- Server limits
	Server = {
		MaxConcurrentMatches = 5,
		PlayerQueueTimeout = 120,
		MatchmakingTimeout = 60,
		SessionTimeoutMinutes = 30,
		GarbageCollectionInterval = 300,
	},
	
	-- Analytics and telemetry
	Analytics = {
		TrackPlayerMovement = true,
		TrackWeaponUsage = true,
		TrackMatchEvents = true,
		TrackPerformanceMetrics = true,
		DataRetentionDays = 90,
		PrivacyCompliant = true,
	},
}

return GameConfig
