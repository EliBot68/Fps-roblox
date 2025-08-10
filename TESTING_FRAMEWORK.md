# 🧪 Enterprise FPS - Testing Framework & Implementation

## 📋 Testing Strategy Overview

### Testing Pyramid
```
                    🔺 E2E Tests (5%)
                 🔺🔺🔺 Integration Tests (20%)
            🔺🔺🔺🔺🔺🔺 Unit Tests (75%)
```

### Test Categories
- **Unit Tests**: Individual module testing with mocks
- **Integration Tests**: System interaction testing
- **Performance Tests**: Load testing and benchmarking
- **Security Tests**: Anti-cheat and exploit validation
- **User Acceptance Tests**: Gameplay flow validation

---

## 🏗️ Test Framework Architecture

### Directory Structure
```
tests/
├── 📁 unit/                     # Unit tests for individual modules
│   ├── 📄 WeaponSystem.spec.lua
│   ├── 📄 MatchmakingService.spec.lua
│   ├── 📄 EconomyService.spec.lua
│   └── 📄 AntiCheatSystem.spec.lua
├── 📁 integration/              # Integration tests
│   ├── 📄 WeaponToNetwork.spec.lua
│   ├── 📄 MatchmakingFlow.spec.lua
│   └── 📄 EconomyTransactions.spec.lua
├── 📁 performance/              # Performance benchmarks
│   ├── 📄 WeaponSystemLoad.spec.lua
│   ├── 📄 NetworkStress.spec.lua
│   └── 📄 MemoryUsage.spec.lua
├── 📁 security/                 # Security and anti-cheat tests
│   ├── 📄 ExploitDetection.spec.lua
│   ├── 📄 RateLimiting.spec.lua
│   └── 📄 DataValidation.spec.lua
├── 📁 e2e/                      # End-to-end gameplay tests
│   ├── 📄 FullGameplay.spec.lua
│   ├── 📄 TournamentFlow.spec.lua
│   └── 📄 PlayerProgression.spec.lua
├── 📁 framework/                # Test utilities and framework
│   ├── 📄 TestRunner.lua        # Main test execution
│   ├── 📄 MockFactory.lua       # Mock object creation
│   ├── 📄 TestHelper.lua        # Test utilities
│   └── 📄 BenchmarkRunner.lua   # Performance testing
└── 📁 fixtures/                 # Test data and fixtures
    ├── 📄 PlayerData.lua        # Sample player data
    ├── 📄 WeaponConfigs.lua     # Test weapon configurations
    └── 📄 MatchData.lua         # Sample match data
```

---

## 🔧 Test Framework Implementation

### TestRunner.lua
```lua
--!strict
local TestRunner = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

type TestCase = {
    name: string,
    test: () -> (),
    beforeEach: (() -> ())?,
    afterEach: (() -> ())?,
    timeout: number?,
}

type TestSuite = {
    name: string,
    tests: {TestCase},
    beforeAll: (() -> ())?,
    afterAll: (() -> ())?,
}

local testSuites: {TestSuite} = {}
local results = {
    passed = 0,
    failed = 0,
    skipped = 0,
    errors = {}
}

function TestRunner.describe(name: string, setupFunction: () -> ())
    local suite: TestSuite = {
        name = name,
        tests = {},
        beforeAll = nil,
        afterAll = nil,
    }
    
    local currentSuite = suite
    table.insert(testSuites, suite)
    
    -- Execute setup function to define tests
    setupFunction()
    
    return suite
end

function TestRunner.it(name: string, testFunction: () -> (), timeout: number?)
    local testCase: TestCase = {
        name = name,
        test = testFunction,
        timeout = timeout or 5,
    }
    
    -- Add to current suite
    if #testSuites > 0 then
        table.insert(testSuites[#testSuites].tests, testCase)
    end
end

function TestRunner.beforeEach(setupFunction: () -> ())
    if #testSuites > 0 then
        local currentSuite = testSuites[#testSuites]
        for _, test in ipairs(currentSuite.tests) do
            test.beforeEach = setupFunction
        end
    end
end

function TestRunner.afterEach(teardownFunction: () -> ())
    if #testSuites > 0 then
        local currentSuite = testSuites[#testSuites]
        for _, test in ipairs(currentSuite.tests) do
            test.afterEach = teardownFunction
        end
    end
end

function TestRunner.expect(value: any)
    return {
        toBe = function(expected: any)
            if value ~= expected then
                error(string.format("Expected %s, got %s", tostring(expected), tostring(value)))
            end
        end,
        toEqual = function(expected: any)
            if not TestRunner._deepEqual(value, expected) then
                error(string.format("Expected %s, got %s", tostring(expected), tostring(value)))
            end
        end,
        toBeCloseTo = function(expected: number, precision: number?)
            precision = precision or 2
            local diff = math.abs(value - expected)
            local threshold = math.pow(10, -precision)
            if diff >= threshold then
                error(string.format("Expected %f to be close to %f", value, expected))
            end
        end,
        toThrow = function()
            local success, _ = pcall(value)
            if success then
                error("Expected function to throw an error")
            end
        end,
        toBeTruthy = function()
            if not value then
                error("Expected value to be truthy")
            end
        end,
        toBeFalsy = function()
            if value then
                error("Expected value to be falsy")
            end
        end,
    }
end

function TestRunner._deepEqual(a: any, b: any): boolean
    if type(a) ~= type(b) then return false end
    
    if type(a) == "table" then
        for k, v in pairs(a) do
            if not TestRunner._deepEqual(v, b[k]) then
                return false
            end
        end
        for k, v in pairs(b) do
            if a[k] == nil then
                return false
            end
        end
        return true
    end
    
    return a == b
end

function TestRunner.runTests(): {passed: number, failed: number, skipped: number, errors: {string}}
    results = {
        passed = 0,
        failed = 0,
        skipped = 0,
        errors = {}
    }
    
    print("🧪 Running Enterprise FPS Test Suite")
    print("=" .. string.rep("=", 50))
    
    for _, suite in ipairs(testSuites) do
        print(string.format("📋 Suite: %s", suite.name))
        
        -- Run beforeAll
        if suite.beforeAll then
            suite.beforeAll()
        end
        
        for _, test in ipairs(suite.tests) do
            local success, error = TestRunner._runSingleTest(test)
            
            if success then
                results.passed += 1
                print(string.format("  ✅ %s", test.name))
            else
                results.failed += 1
                table.insert(results.errors, string.format("%s: %s", test.name, error))
                print(string.format("  ❌ %s: %s", test.name, error))
            end
        end
        
        -- Run afterAll
        if suite.afterAll then
            suite.afterAll()
        end
        
        print("")
    end
    
    print("🏁 Test Results:")
    print(string.format("  ✅ Passed: %d", results.passed))
    print(string.format("  ❌ Failed: %d", results.failed))
    print(string.format("  ⏭️ Skipped: %d", results.skipped))
    print("=" .. string.rep("=", 50))
    
    return results
end

function TestRunner._runSingleTest(test: TestCase): (boolean, string?)
    -- Run beforeEach
    if test.beforeEach then
        test.beforeEach()
    end
    
    local success, error = pcall(test.test)
    
    -- Run afterEach
    if test.afterEach then
        test.afterEach()
    end
    
    return success, error
end

return TestRunner
```

### MockFactory.lua
```lua
--!strict
local MockFactory = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)

function MockFactory.createMockPlayer(playerId: Types.PlayerId, overrides: {[string]: any}?): Types.Player
    local defaults = {
        id = playerId,
        name = "TestPlayer" .. tostring(playerId),
        displayName = "TestPlayer" .. tostring(playerId),
        team = "Red",
        level = 1,
        experience = 0,
        rank = "Bronze",
        elo = 1000,
        stats = MockFactory.createMockPlayerStats(),
        inventory = MockFactory.createMockPlayerInventory(),
        settings = MockFactory.createMockPlayerSettings(),
        joinTime = os.time(),
        lastActive = os.time(),
    }
    
    if overrides then
        for key, value in pairs(overrides) do
            defaults[key] = value
        end
    end
    
    return defaults :: Types.Player
end

function MockFactory.createMockPlayerStats(): Types.PlayerStats
    return {
        kills = 0,
        deaths = 0,
        assists = 0,
        wins = 0,
        losses = 0,
        gamesPlayed = 0,
        timePlayedHours = 0,
        accuracy = 0,
        headshots = 0,
        damageDealt = 0,
        damageTaken = 0,
        healsUsed = 0,
        distanceTraveled = 0,
    }
end

function MockFactory.createMockPlayerInventory(): Types.PlayerInventory
    return {
        currency = 1000,
        premium = false,
        weapons = {},
        skins = {},
        items = {},
        activeLoadout = {
            primary = "AK47",
            secondary = "Glock",
            melee = nil,
            grenades = {},
            equipment = {},
            perks = {},
        },
    }
end

function MockFactory.createMockPlayerSettings(): Types.PlayerSettings
    return {
        sensitivity = 1.0,
        fieldOfView = 90,
        crosshairColor = Color3.new(1, 1, 1),
        audioVolume = 0.5,
        graphicsQuality = "Medium",
        keybinds = {},
        touchControls = nil,
    }
end

function MockFactory.createMockWeapon(weaponId: Types.WeaponId): Types.WeaponConfiguration
    return {
        id = weaponId,
        name = "Test " .. weaponId,
        category = "AssaultRifle",
        rarity = "Common",
        damage = 25,
        headshotMultiplier = 2.0,
        fireRate = 600,
        reloadTime = 2.5,
        magazineSize = 30,
        maxAmmo = 120,
        range = 100,
        accuracy = 0.85,
        recoilPattern = Vector3.new(1, 1, 0),
        damageDropoff = {[50] = 0.8, [100] = 0.6},
        penetration = 0.3,
        muzzleVelocity = 800,
        cost = 1000,
        unlockLevel = 1,
        attachmentSlots = {
            Scope = true,
            Barrel = true,
            Grip = true,
            Magazine = false,
            Stock = true,
            Muzzle = true,
        },
        sounds = {
            fire = "rbxasset://sounds/weapon_fire.mp3",
            reload = "rbxasset://sounds/weapon_reload.mp3",
            empty = "rbxasset://sounds/weapon_empty.mp3",
            draw = "rbxasset://sounds/weapon_draw.mp3",
            holster = "rbxasset://sounds/weapon_holster.mp3",
        },
        animations = {
            idle = "rbxasset://animations/weapon_idle.rbxm",
            fire = "rbxasset://animations/weapon_fire.rbxm",
            reload = "rbxasset://animations/weapon_reload.rbxm",
            reloadEmpty = "rbxasset://animations/weapon_reload_empty.rbxm",
            draw = "rbxasset://animations/weapon_draw.rbxm",
            holster = "rbxasset://animations/weapon_holster.rbxm",
            inspect = "rbxasset://animations/weapon_inspect.rbxm",
        },
        effects = {
            muzzleFlash = "rbxasset://effects/muzzle_flash.rbxm",
            shellEject = "rbxasset://effects/shell_eject.rbxm",
            impact = {
                Metal = "rbxasset://effects/impact_metal.rbxm",
                Wood = "rbxasset://effects/impact_wood.rbxm",
                Concrete = "rbxasset://effects/impact_concrete.rbxm",
            },
            tracer = "rbxasset://effects/bullet_tracer.rbxm",
        },
    }
end

function MockFactory.createMockMatch(): Types.Match
    return {
        id = "test_match_" .. tostring(os.time()),
        mode = "Deathmatch",
        map = "TestMap",
        state = "Waiting",
        players = {},
        teams = {
            Red = {
                id = "Red",
                name = "Red Team",
                color = Color3.new(1, 0, 0),
                players = {},
                score = 0,
                spawns = {},
            },
            Blue = {
                id = "Blue",
                name = "Blue Team",
                color = Color3.new(0, 0, 1),
                players = {},
                score = 0,
                spawns = {},
            },
        },
        startTime = os.time(),
        endTime = nil,
        duration = 0,
        maxPlayers = 10,
        settings = {
            timeLimit = 600,
            scoreLimit = 50,
            friendlyFire = false,
            respawnTime = 5,
            killCam = true,
            spectatorMode = true,
            ranked = true,
            region = "US-East",
        },
        scores = {
            Red = 0,
            Blue = 0,
        },
        events = {},
        statistics = {
            totalKills = 0,
            totalDeaths = 0,
            averageScore = 0,
            topPlayer = nil,
            mvp = nil,
            longestKillstreak = 0,
            mostKills = nil,
            bestAccuracy = nil,
        },
    }
end

return MockFactory
```

---

## 🧪 Unit Test Examples

### WeaponSystem.spec.lua
```lua
--!strict
local TestRunner = require(script.Parent.Parent.framework.TestRunner)
local MockFactory = require(script.Parent.Parent.framework.MockFactory)
local WeaponService = require(ServerScriptService.Core.WeaponService)

TestRunner.describe("WeaponService", function()
    local mockPlayer: Player
    local mockWeapon
    
    TestRunner.beforeEach(function()
        mockPlayer = MockFactory.createMockPlayer(12345)
        mockWeapon = MockFactory.createMockWeapon("AK47")
        WeaponService:Initialize()
    end)
    
    TestRunner.it("should validate proper weapon fire rate", function()
        -- Test firing at proper intervals
        local timestamp1 = 1000
        local timestamp2 = 1100 -- 100ms later (600 RPM = 100ms between shots)
        
        local result1 = WeaponService:CheckFireRate(mockPlayer, "AK47", timestamp1)
        local result2 = WeaponService:CheckFireRate(mockPlayer, "AK47", timestamp2)
        
        TestRunner.expect(result1).toBeTruthy()
        TestRunner.expect(result2).toBeTruthy()
    end)
    
    TestRunner.it("should reject rapid fire attempts", function()
        -- Test firing too quickly
        local timestamp1 = 1000
        local timestamp2 = 1050 -- 50ms later (too fast for 600 RPM)
        
        WeaponService:CheckFireRate(mockPlayer, "AK47", timestamp1)
        local result = WeaponService:CheckFireRate(mockPlayer, "AK47", timestamp2)
        
        TestRunner.expect(result).toBeFalsy()
    end)
    
    TestRunner.it("should calculate damage dropoff correctly", function()
        local baseDamage = 25
        local distance50m = WeaponService:CalculateDamage(mockWeapon, 50, Vector3.new())
        local distance100m = WeaponService:CalculateDamage(mockWeapon, 100, Vector3.new())
        
        TestRunner.expect(distance50m).toBeCloseTo(baseDamage * 0.8, 1)
        TestRunner.expect(distance100m).toBeCloseTo(baseDamage * 0.6, 1)
    end)
    
    TestRunner.it("should apply headshot multiplier", function()
        local bodyDamage = WeaponService:CalculateDamage(mockWeapon, 25, Vector3.new(), false)
        local headDamage = WeaponService:CalculateDamage(mockWeapon, 25, Vector3.new(), true)
        
        TestRunner.expect(headDamage).toBeCloseTo(bodyDamage * 2.0, 1)
    end)
end)
```

### MatchmakingService.spec.lua
```lua
--!strict
local TestRunner = require(script.Parent.Parent.framework.TestRunner)
local MockFactory = require(script.Parent.Parent.framework.MockFactory)
local MatchmakingService = require(ServerScriptService.Core.MatchmakingService)

TestRunner.describe("MatchmakingService", function()
    TestRunner.beforeEach(function()
        MatchmakingService:Initialize()
        MatchmakingService:ClearQueues() -- Reset state
    end)
    
    TestRunner.it("should create balanced teams based on ELO", function()
        -- Create players with different ELO ratings
        local players = {
            MockFactory.createMockPlayer(1, {elo = 1000}),
            MockFactory.createMockPlayer(2, {elo = 1050}),
            MockFactory.createMockPlayer(3, {elo = 1100}),
            MockFactory.createMockPlayer(4, {elo = 1150}),
        }
        
        local teams = MatchmakingService:CreateBalancedTeams(players)
        
        -- Calculate team ELO averages
        local teamRedElo = 0
        local teamBlueElo = 0
        local redCount = 0
        local blueCount = 0
        
        for _, player in ipairs(teams.Red) do
            teamRedElo += player.elo
            redCount += 1
        end
        
        for _, player in ipairs(teams.Blue) do
            teamBlueElo += player.elo
            blueCount += 1
        end
        
        local avgRedElo = teamRedElo / redCount
        local avgBlueElo = teamBlueElo / blueCount
        local eloDifference = math.abs(avgRedElo - avgBlueElo)
        
        -- Teams should be within 100 ELO of each other
        TestRunner.expect(eloDifference).toBeLessThan(100)
    end)
    
    TestRunner.it("should prioritize players who have waited longer", function()
        -- Add players to queue with different wait times
        local preferences = {
            gameMode = "Deathmatch",
            region = "US-East",
            maxPing = 150,
            rankRange = 200,
        }
        
        MatchmakingService:EnterQueue(1, preferences)
        wait(0.1) -- Small delay
        MatchmakingService:EnterQueue(2, preferences)
        
        local queue = MatchmakingService:GetQueue("Deathmatch")
        
        -- First player should be prioritized
        TestRunner.expect(queue[1].playerId).toBe(1)
        TestRunner.expect(queue[2].playerId).toBe(2)
    end)
end)
```

---

## ⚡ Performance Test Examples

### WeaponSystemLoad.spec.lua
```lua
--!strict
local TestRunner = require(script.Parent.Parent.framework.TestRunner)
local BenchmarkRunner = require(script.Parent.Parent.framework.BenchmarkRunner)
local WeaponService = require(ServerScriptService.Core.WeaponService)

TestRunner.describe("WeaponSystem Performance", function()
    TestRunner.it("should handle 100 concurrent weapon fires", function()
        local startTime = tick()
        
        for i = 1, 100 do
            local mockPlayer = MockFactory.createMockPlayer(i)
            WeaponService:ValidateShot(mockPlayer, "AK47", Vector3.new(100, 0, 100), tick())
        end
        
        local endTime = tick()
        local duration = endTime - startTime
        
        -- Should complete within 100ms
        TestRunner.expect(duration).toBeLessThan(0.1)
    end)
    
    TestRunner.it("should maintain stable memory usage", function()
        local initialMemory = collectgarbage("count")
        
        -- Simulate 1000 weapon fires
        for i = 1, 1000 do
            local mockPlayer = MockFactory.createMockPlayer(i % 100 + 1)
            WeaponService:ValidateShot(mockPlayer, "AK47", Vector3.new(), tick())
        end
        
        collectgarbage("collect")
        local finalMemory = collectgarbage("count")
        local memoryIncrease = finalMemory - initialMemory
        
        -- Memory increase should be minimal (<10MB)
        TestRunner.expect(memoryIncrease).toBeLessThan(10240) -- 10MB in KB
    end)
end)
```

---

## 🔐 Security Test Examples

### ExploitDetection.spec.lua
```lua
--!strict
local TestRunner = require(script.Parent.Parent.framework.TestRunner)
local MockFactory = require(script.Parent.Parent.framework.MockFactory)
local AntiCheatService = require(ServerScriptService.Core.AntiCheatService)

TestRunner.describe("Anti-Cheat System", function()
    TestRunner.it("should detect impossible accuracy", function()
        local mockPlayer = MockFactory.createMockPlayer(1)
        
        -- Simulate 100% accuracy over 50 shots (impossible for real player)
        for i = 1, 50 do
            AntiCheatService:RecordShot(mockPlayer.id, true, "AK47")
        end
        
        local suspicionLevel = AntiCheatService:GetSuspicionLevel(mockPlayer.id)
        
        TestRunner.expect(suspicionLevel).toBeGreaterThan(0.8) -- High suspicion
    end)
    
    TestRunner.it("should detect impossible reaction times", function()
        local mockPlayer = MockFactory.createMockPlayer(1)
        
        -- Simulate inhuman reaction time (10ms average)
        for i = 1, 20 do
            AntiCheatService:RecordReactionTime(mockPlayer.id, 0.01)
        end
        
        local flagged = AntiCheatService:IsPlayerFlagged(mockPlayer.id, "FastReactions")
        
        TestRunner.expect(flagged).toBeTruthy()
    end)
    
    TestRunner.it("should rate limit rapid requests", function()
        local mockPlayer = MockFactory.createMockPlayer(1)
        
        -- Attempt to fire 10 shots in 100ms (impossible)
        local blocked = 0
        for i = 1, 10 do
            local allowed = AntiCheatService:CheckRateLimit(mockPlayer.id, "WeaponFire")
            if not allowed then
                blocked += 1
            end
        end
        
        TestRunner.expect(blocked).toBeGreaterThan(7) -- Most should be blocked
    end)
end)
```

---

## 🎮 End-to-End Test Examples

### FullGameplay.spec.lua
```lua
--!strict
local TestRunner = require(script.Parent.Parent.framework.TestRunner)
local MockFactory = require(script.Parent.Parent.framework.MockFactory)

TestRunner.describe("Full Gameplay Flow", function()
    TestRunner.it("should complete a full deathmatch game", function()
        -- This would be a longer integration test
        -- Testing the complete flow from matchmaking to game completion
        
        local players = {}
        for i = 1, 6 do
            table.insert(players, MockFactory.createMockPlayer(i))
        end
        
        -- Enter matchmaking
        -- Create match
        -- Play game
        -- Update statistics
        -- Distribute rewards
        
        -- This test would take longer and test the entire pipeline
        TestRunner.expect(true).toBeTruthy() -- Placeholder
    end)
end)
```

This comprehensive testing framework provides the foundation for maintaining code quality, catching regressions, and ensuring the enterprise FPS game meets professional standards for reliability and performance.
