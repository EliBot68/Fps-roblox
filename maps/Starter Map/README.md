# Practice Map System

## Overview
Basic practice map system for weapon testing and target practice in the FPS game.

## Features
- **Teleport Button**: Blue glowing button at spawn location to teleport to practice range
- **Weapon Selection**: 6 colored touchpads for different weapons (AssaultRifle, SMG, Shotgun, Sniper, Pistol, BurstRifle)
- **Target Dummies**: 4 interactive target dummies with hit detection and visual feedback
- **Return Portal**: Cyan swirling portal to return to lobby
- **Practice Statistics**: Real-time tracking of shots, hits, and accuracy

## How to Use
1. Click the blue "PRACTICE RANGE" button at spawn
2. Walk on colored weapon touchpads to select weapons
3. Shoot at target dummies for practice
4. Use E key to return to lobby or walk through return portal
5. Use R key to reset practice statistics

## File Structure
- `LobbyManager.server.lua` - Manages lobby area and teleport button
- `PracticeMapManager.server.lua` - Creates and manages practice map
- `PracticeRangeClient.client.lua` - Client-side UI and interactions
- `ReplicatedStorage/RemoteEvents/PracticeEvents/` - RemoteEvents for practice system

## RemoteEvents
- `TeleportToPractice` - Teleports player to practice range
- `TeleportToLobby` - Teleports player back to lobby
- `SelectWeapon` - Gives weapon to player in practice range

## Weapon Touchpad Colors
- **AssaultRifle**: Orange
- **SMG**: Yellow  
- **Shotgun**: Red
- **Sniper**: Blue
- **Pistol**: Gray
- **BurstRifle**: Purple

## Rojo Compatibility
All files are structured for Rojo compatibility and will sync properly with the existing project structure.
