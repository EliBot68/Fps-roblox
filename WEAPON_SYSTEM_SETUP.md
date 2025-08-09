# ENTERPRISE WEAPON SYSTEM - INSTALLATION GUIDE

## STEP-BY-STEP STUDIO SETUP

### 1. FOLDER STRUCTURE CREATION
```
ReplicatedStorage/
├── WeaponSystem/
│   ├── Modules/
│   │   ├── WeaponDefinitions (ModuleScript)
│   │   └── WeaponUtils (ModuleScript)
│   └── Assets/ (Folder - weapon models will be loaded here automatically)
ServerScriptService/
├── WeaponServer/
│   ├── WeaponServer (ServerScript)
│   └── GameModeGlue (ServerScript)
StarterPlayerScripts/
└── WeaponClient/
    └── WeaponClient (LocalScript)
StarterGui/
└── WeaponUI/
    ├── AmmoCounter (LocalScript)
    └── WeaponIcons (LocalScript)
```

### 2. SCRIPT PLACEMENT INSTRUCTIONS

**ReplicatedStorage Setup:**
1. Create Folder "WeaponSystem" in ReplicatedStorage
2. Create Folder "Modules" inside WeaponSystem
3. Create Folder "Assets" inside WeaponSystem (for weapon models)
4. Place WeaponDefinitions.lua as ModuleScript in Modules/
5. Place WeaponUtils.lua as ModuleScript in Modules/

**ServerScriptService Setup:**
1. Create Folder "WeaponServer" in ServerScriptService
2. Place WeaponServer.lua as ServerScript in WeaponServer/
3. Place GameModeGlue.lua as ServerScript in WeaponServer/

**StarterPlayerScripts Setup:**
1. Create Folder "WeaponClient" in StarterPlayerScripts
2. Place WeaponClient.lua as LocalScript in WeaponClient/

**StarterGui Setup:**
1. Create Folder "WeaponUI" in StarterGui
2. Place AmmoCounter.lua as LocalScript in WeaponUI/
3. Place WeaponIcons.lua as LocalScript in WeaponUI/

### 3. ASSET LOADING
The system automatically loads weapon models using the Asset IDs defined in WeaponDefinitions.lua:
- Models are cached in ReplicatedStorage/WeaponSystem/Assets/
- First load may take a moment as models download from Creator Store
- Subsequent loads use cached models for performance

### 4. TESTING THE SYSTEM
1. Run the game in Studio
2. Default loadout: M4A1 Carbine (Primary), Glock-18 (Secondary), Combat Knife (Melee)
3. Test controls:
   - Left Click: Fire weapon
   - R: Reload
   - 1/2/3: Switch weapon slots
4. Check console for initialization messages

### 5. INTEGRATION WITH EXISTING SYSTEMS
- The weapon system automatically integrates with the practice range
- Players can test all weapons at the practice map touchpads
- GameModeGlue handles different game modes (BR, TDM, FFA, Practice)

## TROUBLESHOOTING CHECKLIST

### Sound Issues:
- Check if SoundService is accessible
- Verify Asset IDs in WeaponDefinitions are correct
- Ensure game has permission to play copyrighted audio

### Model Loading Issues:
- Verify Creator Store Asset IDs are valid
- Check if InsertService is enabled in your game
- Models may take time to load on first run

### UI Not Appearing:
- Check if StarterGui scripts are in correct folders
- Verify PlayerGui is accessible
- Look for script errors in Developer Console

### Weapon Not Firing:
- Check RemoteEvent connections in output
- Verify WeaponServer is running
- Test with default weapons first

### Performance Issues:
- Monitor object pooling in WeaponUtils
- Check for memory leaks in VFX effects
- Adjust fire rates if needed

## ADDING NEW WEAPONS

### Method 1: Direct Addition to WeaponDefinitions
1. Open WeaponDefinitions.lua
2. Copy existing weapon configuration
3. Modify properties (damage, fire rate, model ID, etc.)
4. Add to appropriate slot array in WeaponsBySlot
5. Test in Practice mode

### Method 2: Using GameModeGlue (Runtime)
```lua
local GameModeGlue = require(ServerScriptService.WeaponServer.GameModeGlue)
GameModeGlue.SetPlayerLoadout(player, {
    Primary = "NewWeaponId",
    Secondary = "Pistol",
    Melee = "CombatKnife"
})
```

### Animation ID Replacement
1. Find TODO comments in WeaponDefinitions.lua
2. Replace placeholder "rbxassetid://0" with actual Animation IDs
3. Ensure animations match weapon types (rifle vs pistol vs melee)

## ADVANCED CONFIGURATION

### Fire Rate Balancing:
- Modify MaxFireRate in weapon configs for anti-exploit limits
- Server automatically throttles based on these values

### Game Mode Setup:
```lua
local GameModeGlue = require(ServerScriptService.WeaponServer.GameModeGlue)
GameModeGlue.SetGameMode("BattleRoyale") -- or "TeamDeathmatch", "FreeForAll"
```

### Custom Recoil Patterns:
- Edit RECOIL_SETTINGS in WeaponClient.lua
- Values are Vector3(vertical, horizontal, recovery)

## PERFORMANCE OPTIMIZATION

### Recommended Settings:
- Max concurrent muzzle flashes: 10
- Sound pool size: 5 per sound type
- Raycast distance limit: 500 studs
- Fire rate cap: 20 RPS maximum

### Memory Management:
- VFX objects are automatically pooled and reused
- Sounds return to pool after playing
- Models are cached and cloned as needed

## SECURITY FEATURES

### Anti-Exploit Measures:
- Server-side fire rate validation
- Direction angle checking (max 60° deviation)
- Range validation per weapon
- Ammo count verification
- Player position validation

### Rate Limiting:
- Per-player fire rate throttling
- Reload cooldown enforcement
- Weapon switch limitations

The weapon system is now ready for production use with enterprise-level performance and security!
