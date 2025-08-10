--!strict
--[[
    Enterprise FPS - Luau Type Definitions
    Professional type system for type-safe development
]]

-- ================================================================
-- CORE GAME TYPES
-- ================================================================

export type PlayerId = number
export type TeamId = "Red" | "Blue" | "Spectator"
export type GameMode = "Deathmatch" | "TeamDeathmatch" | "BattleRoyale" | "Tournament" | "Practice"
export type MatchState = "Waiting" | "Starting" | "InProgress" | "Ending" | "Completed"

export type Player = {
    id: PlayerId,
    name: string,
    displayName: string,
    team: TeamId,
    level: number,
    experience: number,
    rank: string,
    elo: number,
    stats: PlayerStats,
    inventory: PlayerInventory,
    settings: PlayerSettings,
    joinTime: number,
    lastActive: number,
}

export type PlayerStats = {
    kills: number,
    deaths: number,
    assists: number,
    wins: number,
    losses: number,
    gamesPlayed: number,
    timePlayedHours: number,
    accuracy: number,
    headshots: number,
    damageDealt: number,
    damageTaken: number,
    healsUsed: number,
    distanceTraveled: number,
}

export type PlayerInventory = {
    currency: number,
    premium: boolean,
    weapons: {[WeaponId]: WeaponInstance},
    skins: {[SkinId]: boolean},
    items: {[ItemId]: number},
    activeLoadout: LoadoutConfiguration,
}

export type PlayerSettings = {
    sensitivity: number,
    fieldOfView: number,
    crosshairColor: Color3,
    audioVolume: number,
    graphicsQuality: "Low" | "Medium" | "High" | "Ultra",
    keybinds: {[string]: Enum.KeyCode},
    touchControls: TouchControlSettings?,
}

export type TouchControlSettings = {
    fireButtonSize: number,
    joystickSize: number,
    hudTransparency: number,
    hapticFeedback: boolean,
}

-- ================================================================
-- WEAPON SYSTEM TYPES
-- ================================================================

export type WeaponId = "AK47" | "M4A1" | "AWP" | "Glock" | "MP5" | "Shotgun" | "Sniper" | "Pistol"
export type WeaponCategory = "AssaultRifle" | "SniperRifle" | "SMG" | "Shotgun" | "Pistol" | "LMG"
export type WeaponRarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"
export type DamageType = "Normal" | "Piercing" | "Explosive" | "Fire" | "Poison"

export type WeaponConfiguration = {
    id: WeaponId,
    name: string,
    category: WeaponCategory,
    rarity: WeaponRarity,
    damage: number,
    headshotMultiplier: number,
    fireRate: number,
    reloadTime: number,
    magazineSize: number,
    maxAmmo: number,
    range: number,
    accuracy: number,
    recoilPattern: Vector3,
    damageDropoff: {[number]: number},
    penetration: number,
    muzzleVelocity: number,
    cost: number,
    unlockLevel: number,
    attachmentSlots: {[AttachmentType]: boolean},
    sounds: WeaponSounds,
    animations: WeaponAnimations,
    effects: WeaponEffects,
}

export type WeaponInstance = {
    config: WeaponConfiguration,
    attachments: {[AttachmentType]: AttachmentId?},
    skin: SkinId?,
    kills: number,
    experience: number,
    level: number,
    condition: number, -- 0-100, affects performance
    equipped: boolean,
    lastUsed: number,
}

export type AttachmentType = "Scope" | "Barrel" | "Grip" | "Magazine" | "Stock" | "Muzzle"
export type AttachmentId = string
export type SkinId = string
export type ItemId = string

export type Attachment = {
    id: AttachmentId,
    name: string,
    type: AttachmentType,
    rarity: WeaponRarity,
    cost: number,
    unlockLevel: number,
    statModifiers: {[string]: number},
    compatibleWeapons: {[WeaponId]: boolean},
    description: string,
}

export type WeaponSounds = {
    fire: string,
    reload: string,
    empty: string,
    draw: string,
    holster: string,
}

export type WeaponAnimations = {
    idle: string,
    fire: string,
    reload: string,
    reloadEmpty: string,
    draw: string,
    holster: string,
    inspect: string,
}

export type WeaponEffects = {
    muzzleFlash: string,
    shellEject: string,
    impact: {[string]: string}, -- material -> effect
    tracer: string?,
}

export type LoadoutConfiguration = {
    primary: WeaponId?,
    secondary: WeaponId?,
    melee: WeaponId?,
    grenades: {[string]: number},
    equipment: {[string]: boolean},
    perks: {[string]: boolean},
}

-- ================================================================
-- MATCH AND GAME STATE TYPES
-- ================================================================

export type Match = {
    id: string,
    mode: GameMode,
    map: MapId,
    state: MatchState,
    players: {[PlayerId]: Player},
    teams: {[TeamId]: Team},
    startTime: number,
    endTime: number?,
    duration: number,
    maxPlayers: number,
    settings: MatchSettings,
    scores: {[TeamId]: number},
    events: {MatchEvent},
    statistics: MatchStatistics,
}

export type Team = {
    id: TeamId,
    name: string,
    color: Color3,
    players: {[PlayerId]: Player},
    score: number,
    spawns: {CFrame},
}

export type MatchSettings = {
    timeLimit: number,
    scoreLimit: number,
    friendlyFire: boolean,
    respawnTime: number,
    killCam: boolean,
    spectatorMode: boolean,
    ranked: boolean,
    region: string,
}

export type MatchEvent = {
    type: "Kill" | "Death" | "Assist" | "Objective" | "Disconnect" | "Reconnect",
    timestamp: number,
    playerId: PlayerId,
    targetId: PlayerId?,
    weaponId: WeaponId?,
    position: Vector3?,
    data: {[string]: any}?,
}

export type MatchStatistics = {
    totalKills: number,
    totalDeaths: number,
    averageScore: number,
    topPlayer: PlayerId?,
    mvp: PlayerId?,
    longestKillstreak: number,
    mostKills: PlayerId?,
    bestAccuracy: PlayerId?,
}

-- ================================================================
-- MAP AND ENVIRONMENT TYPES
-- ================================================================

export type MapId = string

export type MapConfiguration = {
    id: MapId,
    name: string,
    description: string,
    thumbnail: string,
    author: string,
    version: string,
    supportedModes: {[GameMode]: boolean},
    maxPlayers: number,
    recommendedPlayers: number,
    spawns: {[TeamId]: {CFrame}},
    objectives: {ObjectivePoint},
    boundaries: {CFrame},
    lighting: LightingSettings,
    weather: WeatherSettings?,
    assets: {[string]: string},
    navigation: NavigationMesh?,
}

export type ObjectivePoint = {
    id: string,
    type: "Flag" | "Bomb" | "Control" | "Spawn",
    position: CFrame,
    radius: number,
    team: TeamId?,
    active: boolean,
}

export type LightingSettings = {
    timeOfDay: string,
    brightness: number,
    ambient: Color3,
    colorShift_Bottom: Color3,
    colorShift_Top: Color3,
    shadowSoftness: number,
    technology: Enum.Technology,
}

export type WeatherSettings = {
    enabled: boolean,
    type: "Rain" | "Snow" | "Fog" | "Storm",
    intensity: number,
    windDirection: Vector3,
    windSpeed: number,
}

export type NavigationMesh = {
    nodes: {NavigationNode},
    connections: {[number]: {number}},
}

export type NavigationNode = {
    id: number,
    position: Vector3,
    type: "Ground" | "Cover" | "Elevated" | "Water",
    cover: boolean,
    team: TeamId?,
}

-- ================================================================
-- ECONOMY AND PROGRESSION TYPES
-- ================================================================

export type Currency = "Coins" | "Gems" | "BattlePoints" | "TournamentTokens"

export type ShopItem = {
    id: string,
    name: string,
    description: string,
    type: "Weapon" | "Skin" | "Attachment" | "Bundle" | "Currency",
    cost: {[Currency]: number},
    discount: number?,
    featured: boolean,
    limited: boolean,
    endTime: number?,
    requirements: {[string]: any}?,
    rewards: {[string]: any},
}

export type BattlePass = {
    id: string,
    name: string,
    season: number,
    startTime: number,
    endTime: number,
    tiers: {BattlePassTier},
    premium: boolean,
    cost: number,
}

export type BattlePassTier = {
    tier: number,
    experience: number,
    freeReward: ShopItem?,
    premiumReward: ShopItem?,
    unlocked: boolean,
}

export type Achievement = {
    id: string,
    name: string,
    description: string,
    icon: string,
    rarity: "Bronze" | "Silver" | "Gold" | "Platinum",
    category: string,
    requirements: {[string]: any},
    rewards: {[string]: any},
    progress: number,
    completed: boolean,
    dateCompleted: number?,
}

-- ================================================================
-- TOURNAMENT AND COMPETITIVE TYPES
-- ================================================================

export type Tournament = {
    id: string,
    name: string,
    description: string,
    format: "Single" | "Double" | "Swiss" | "RoundRobin",
    entryFee: number,
    prizePool: number,
    maxParticipants: number,
    startTime: number,
    endTime: number,
    status: "Registration" | "InProgress" | "Completed" | "Cancelled",
    brackets: {TournamentBracket},
    participants: {[PlayerId]: TournamentParticipant},
    rules: TournamentRules,
}

export type TournamentBracket = {
    round: number,
    matches: {TournamentMatch},
}

export type TournamentMatch = {
    id: string,
    participants: {PlayerId},
    winner: PlayerId?,
    scores: {[PlayerId]: number},
    scheduledTime: number,
    actualTime: number?,
    status: "Scheduled" | "InProgress" | "Completed" | "Forfeit",
}

export type TournamentParticipant = {
    playerId: PlayerId,
    seed: number,
    eliminatedRound: number?,
    winnings: number,
    performance: {[string]: number},
}

export type TournamentRules = {
    gameMode: GameMode,
    maps: {MapId},
    bestOf: number,
    timeLimit: number,
    allowedWeapons: {[WeaponId]: boolean}?,
    bannedItems: {[string]: boolean}?,
    spectatorMode: boolean,
}

-- ================================================================
-- NETWORK AND SECURITY TYPES
-- ================================================================

export type NetworkPacket = {
    type: string,
    timestamp: number,
    playerId: PlayerId,
    data: {[string]: any},
    checksum: string?,
}

export type SecurityReport = {
    playerId: PlayerId,
    type: "Exploit" | "Cheat" | "Spam" | "Inappropriate",
    severity: "Low" | "Medium" | "High" | "Critical",
    evidence: {[string]: any},
    timestamp: number,
    reporterId: PlayerId?,
    status: "Pending" | "Investigating" | "Resolved" | "Dismissed",
}

export type RateLimitBucket = {
    playerId: PlayerId,
    action: string,
    tokens: number,
    lastRefill: number,
    maxTokens: number,
    refillRate: number,
}

-- ================================================================
-- UI AND INTERFACE TYPES
-- ================================================================

export type UITheme = {
    name: string,
    primaryColor: Color3,
    secondaryColor: Color3,
    accentColor: Color3,
    backgroundColor: Color3,
    textColor: Color3,
    fonts: {[string]: Font},
    sounds: {[string]: string},
}

export type MenuState = "MainMenu" | "Lobby" | "Settings" | "Shop" | "Inventory" | "Profile" | "Tournament"

export type HUDElement = {
    name: string,
    visible: boolean,
    position: UDim2,
    size: UDim2,
    anchor: Vector2,
    zIndex: number,
    transparency: number,
}

export type InputBinding = {
    action: string,
    input: Enum.KeyCode | Enum.UserInputType,
    context: "Menu" | "Game" | "Both",
    description: string,
}

-- ================================================================
-- ANALYTICS AND TELEMETRY TYPES
-- ================================================================

export type AnalyticsEvent = {
    event: string,
    category: string,
    playerId: PlayerId?,
    properties: {[string]: any},
    timestamp: number,
    sessionId: string?,
}

export type PerformanceMetrics = {
    fps: number,
    ping: number,
    memoryUsage: number,
    cpuUsage: number,
    networkIn: number,
    networkOut: number,
    renderTime: number,
    timestamp: number,
}

export type UserSession = {
    sessionId: string,
    playerId: PlayerId,
    startTime: number,
    endTime: number?,
    duration: number,
    platform: "PC" | "Mobile" | "Console",
    device: string,
    location: string,
    events: {AnalyticsEvent},
}

-- ================================================================
-- SERVICE INTERFACES
-- ================================================================

export type ServiceLocator = {
    GetService: <T>(serviceName: string) -> T,
    RegisterService: <T>(serviceName: string, service: T) -> (),
    IsServiceRegistered: (serviceName: string) -> boolean,
}

export type NetworkService = {
    SendToServer: (eventName: string, ...any) -> (),
    SendToClient: (player: Player, eventName: string, ...any) -> (),
    SendToAllClients: (eventName: string, ...any) -> (),
    ConnectEvent: (eventName: string, callback: (...any) -> ()) -> RBXScriptConnection,
}

export type DatabaseService = {
    SavePlayerData: (playerId: PlayerId, data: {[string]: any}) -> boolean,
    LoadPlayerData: (playerId: PlayerId) -> {[string]: any}?,
    UpdatePlayerStats: (playerId: PlayerId, stats: {[string]: any}) -> boolean,
    GetLeaderboard: (statName: string, limit: number) -> {{playerId: PlayerId, value: any}},
}

export type MatchmakingService = {
    FindMatch: (playerId: PlayerId, preferences: {[string]: any}) -> string?,
    CreateMatch: (settings: MatchSettings) -> string,
    JoinMatch: (playerId: PlayerId, matchId: string) -> boolean,
    LeaveMatch: (playerId: PlayerId) -> boolean,
}

export type WeaponService = {
    GetWeaponConfig: (weaponId: WeaponId) -> WeaponConfiguration,
    EquipWeapon: (playerId: PlayerId, weaponId: WeaponId) -> boolean,
    FireWeapon: (playerId: PlayerId, weaponId: WeaponId, target: Vector3) -> boolean,
    ReloadWeapon: (playerId: PlayerId, weaponId: WeaponId) -> boolean,
    ValidateShot: (playerId: PlayerId, weaponId: WeaponId, target: Vector3) -> boolean,
}

return {}
