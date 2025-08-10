--!strict
--[[
	EffectsController.lua
	Handles all visual and audio effects for weapons and combat
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import dependencies
local CombatTypes = require(ReplicatedStorage.Shared.CombatTypes)

type WeaponID = string

local EffectsController = {}

-- Configuration
local EFFECT_CONFIG = {
	muzzleFlashDuration = 0.1,
	bulletTrailSpeed = 1000, -- studs per second
	particlePoolSize = 100,
	soundMaxDistance = 500,
	impactEffectLifetime = 2.0,
	bloodEffectLifetime = 3.0
}

-- Effect pools for performance
local effectPools = {
	muzzleFlashes = {},
	bulletTrails = {},
	impactParticles = {},
	bloodParticles = {},
	shells = {}
}

-- Audio libraries
local weaponSounds = {
	["AK47"] = {
		fire = "rbxassetid://1234567890",
		reload = "rbxassetid://1234567891",
		dryFire = "rbxassetid://1234567892",
		draw = "rbxassetid://1234567893",
		holster = "rbxassetid://1234567894"
	},
	["M4A1"] = {
		fire = "rbxassetid://1234567895",
		reload = "rbxassetid://1234567896",
		dryFire = "rbxassetid://1234567897",
		draw = "rbxassetid://1234567898",
		holster = "rbxassetid://1234567899"
	},
	["AWP"] = {
		fire = "rbxassetid://1234567900",
		reload = "rbxassetid://1234567901",
		dryFire = "rbxassetid://1234567902",
		draw = "rbxassetid://1234567903",
		holster = "rbxassetid://1234567904"
	},
	["GLOCK17"] = {
		fire = "rbxassetid://1234567905",
		reload = "rbxassetid://1234567906",
		dryFire = "rbxassetid://1234567907",
		draw = "rbxassetid://1234567908",
		holster = "rbxassetid://1234567909"
	}
}

-- Camera shake parameters
local shakeProfiles = {
	light = { amplitude = 0.5, frequency = 20, duration = 0.2 },
	medium = { amplitude = 1.0, frequency = 15, duration = 0.3 },
	heavy = { amplitude = 2.0, frequency = 10, duration = 0.5 }
}

-- State
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local character = player.CharacterAdded:Wait()

-- Initialize effects system
function EffectsController.Initialize()
	-- Pre-create effect pools
	EffectsController.CreateEffectPools()
	
	-- Set up audio
	EffectsController.SetupAudio()
	
	print("[EffectsController] ✓ Initialized with pooled effects")
end

-- Create object pools for performance
function EffectsController.CreateEffectPools()
	-- Muzzle flash pool
	for i = 1, EFFECT_CONFIG.particlePoolSize do
		local muzzleFlash = EffectsController.CreateMuzzleFlashPart()
		muzzleFlash.Parent = nil
		table.insert(effectPools.muzzleFlashes, muzzleFlash)
	end
	
	-- Bullet trail pool
	for i = 1, EFFECT_CONFIG.particlePoolSize do
		local trail = EffectsController.CreateBulletTrailPart()
		trail.Parent = nil
		table.insert(effectPools.bulletTrails, trail)
	end
	
	-- Impact particle pool
	for i = 1, EFFECT_CONFIG.particlePoolSize do
		local particle = EffectsController.CreateImpactParticle()
		particle.Parent = nil
		table.insert(effectPools.impactParticles, particle)
	end
end

-- Set up audio system
function EffectsController.SetupAudio()
	-- Configure sound groups
	local weaponSoundGroup = Instance.new("SoundGroup")
	weaponSoundGroup.Name = "WeaponSounds"
	weaponSoundGroup.Volume = 0.8
	weaponSoundGroup.Parent = SoundService
	
	local impactSoundGroup = Instance.new("SoundGroup")
	impactSoundGroup.Name = "ImpactSounds"
	impactSoundGroup.Volume = 0.6
	impactSoundGroup.Parent = SoundService
end

-- Play muzzle flash effect
function EffectsController.PlayMuzzleFlash(weaponID: WeaponID)
	local muzzleFlash = EffectsController.GetPooledMuzzleFlash()
	if not muzzleFlash then return end
	
	-- Position at weapon muzzle
	local weaponModel = EffectsController.GetWeaponModel(weaponID)
	if weaponModel then
		local muzzle = weaponModel:FindFirstChild("Muzzle")
		if muzzle then
			muzzleFlash.CFrame = muzzle.CFrame
		end
	end
	
	muzzleFlash.Parent = workspace
	
	-- Animate muzzle flash
	local tween = TweenService:Create(
		muzzleFlash,
		TweenInfo.new(EFFECT_CONFIG.muzzleFlashDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Transparency = 1, Size = muzzleFlash.Size * 2 }
	)
	
	tween:Play()
	tween.Completed:Connect(function()
		EffectsController.ReturnMuzzleFlashToPool(muzzleFlash)
	end)
	
	-- Camera shake
	EffectsController.CameraShake(shakeProfiles.light)
end

-- Show bullet trail
function EffectsController.ShowBulletTrail(startPos: Vector3, endPos: Vector3)
	local trail = EffectsController.GetPooledBulletTrail()
	if not trail then return end
	
	-- Position and orient trail
	local distance = (endPos - startPos).Magnitude
	local direction = (endPos - startPos).Unit
	
	trail.CFrame = CFrame.lookAt(startPos + direction * distance / 2, endPos)
	trail.Size = Vector3.new(0.1, 0.1, distance)
	trail.Parent = workspace
	
	-- Animate trail
	local tween = TweenService:Create(
		trail,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Transparency = 1 }
	)
	
	tween:Play()
	tween.Completed:Connect(function()
		EffectsController.ReturnBulletTrailToPool(trail)
	end)
end

-- Play hit effect on target
function EffectsController.PlayHitEffect(hitPart: BasePart, damage: number)
	-- Blood effect for player hits
	if EffectsController.IsPlayerPart(hitPart) then
		EffectsController.PlayBloodEffect(hitPart, damage)
	else
		-- Generic impact effect
		EffectsController.PlayImpactEffect(hitPart.Position, hitPart.Material)
	end
	
	-- Hit marker sound
	EffectsController.PlayHitMarkerSound(damage)
end

-- Play blood effect for player hits
function EffectsController.PlayBloodEffect(hitPart: BasePart, damage: number)
	local bloodParticle = EffectsController.GetPooledBloodParticle()
	if not bloodParticle then return end
	
	-- Position at hit location
	bloodParticle.Position = hitPart.Position
	bloodParticle.Parent = workspace
	
	-- Scale effect based on damage
	local intensity = math.min(damage / 100, 1)
	bloodParticle.ParticleEmitter.Rate = 50 * intensity
	
	-- Clean up after delay
	Debris:AddItem(bloodParticle, EFFECT_CONFIG.bloodEffectLifetime)
end

-- Play impact effect for environment hits
function EffectsController.PlayImpactEffect(position: Vector3, material: Enum.Material)
	local particle = EffectsController.GetPooledImpactParticle()
	if not particle then return end
	
	particle.Position = position
	particle.Parent = workspace
	
	-- Customize based on material
	local emitter = particle.ParticleEmitter
	if material == Enum.Material.Concrete then
		emitter.Color = ColorSequence.new(Color3.new(0.7, 0.7, 0.7))
	elseif material == Enum.Material.Metal then
		emitter.Color = ColorSequence.new(Color3.new(0.8, 0.8, 0.9))
	elseif material == Enum.Material.Wood then
		emitter.Color = ColorSequence.new(Color3.new(0.6, 0.4, 0.2))
	end
	
	emitter:Emit(10)
	
	-- Clean up
	task.wait(EFFECT_CONFIG.impactEffectLifetime)
	EffectsController.ReturnImpactParticleToPool(particle)
end

-- Play weapon fire sound
function EffectsController.PlayFireSound(weaponID: WeaponID)
	local weaponData = weaponSounds[weaponID]
	if not weaponData then return end
	
	local soundID = weaponData.fire
	if not soundID then return end
	
	local sound = EffectsController.CreatePositionalSound(soundID, camera.CFrame.Position)
	sound.Volume = 0.5
	sound.Pitch = math.random(95, 105) / 100 -- Slight randomization
	sound:Play()
	
	-- Clean up after playback
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

-- Play reload sound
function EffectsController.PlayReloadSound(weaponID: WeaponID)
	local weaponData = weaponSounds[weaponID]
	if not weaponData then return end
	
	local soundID = weaponData.reload
	if not soundID then return end
	
	local sound = EffectsController.CreatePositionalSound(soundID, camera.CFrame.Position)
	sound.Volume = 0.3
	sound:Play()
	
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

-- Play dry fire sound
function EffectsController.PlayDryFireSound(weaponID: WeaponID)
	local weaponData = weaponSounds[weaponID]
	if not weaponData then return end
	
	local soundID = weaponData.dryFire
	if not soundID then return end
	
	local sound = EffectsController.CreatePositionalSound(soundID, camera.CFrame.Position)
	sound.Volume = 0.2
	sound:Play()
	
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

-- Play hit marker sound
function EffectsController.PlayHitMarkerSound(damage: number)
	local sound = EffectsController.CreatePositionalSound("rbxassetid://hitmarker", camera.CFrame.Position)
	sound.Volume = 0.4
	sound.Pitch = 1 + (damage / 200) -- Higher pitch for more damage
	sound:Play()
	
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

-- Camera shake effect
function EffectsController.CameraShake(profile: {amplitude: number, frequency: number, duration: number})
	local originalCFrame = camera.CFrame
	local startTime = tick()
	
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local elapsed = tick() - startTime
		local progress = elapsed / profile.duration
		
		if progress >= 1 then
			camera.CFrame = originalCFrame
			connection:Disconnect()
			return
		end
		
		-- Decay shake over time
		local intensity = (1 - progress) * profile.amplitude
		
		-- Generate shake offset
		local shakeX = math.sin(elapsed * profile.frequency) * intensity
		local shakeY = math.cos(elapsed * profile.frequency * 1.2) * intensity
		local shakeZ = math.sin(elapsed * profile.frequency * 0.8) * intensity
		
		local shakeOffset = Vector3.new(shakeX, shakeY, shakeZ) * 0.01
		camera.CFrame = originalCFrame + shakeOffset
	end)
end

-- Animation helpers
function EffectsController.PlayFireAnimation(weaponID: WeaponID)
	-- TODO: Implement weapon fire animations
end

function EffectsController.PlayReloadAnimation(weaponID: WeaponID)
	-- TODO: Implement weapon reload animations
end

function EffectsController.PlayDrawAnimation(weaponID: WeaponID)
	-- TODO: Implement weapon draw animations
end

function EffectsController.PlayHolsterAnimation(weaponID: WeaponID)
	-- TODO: Implement weapon holster animations
end

-- Pool management functions
function EffectsController.GetPooledMuzzleFlash(): BasePart?
	if #effectPools.muzzleFlashes > 0 then
		return table.remove(effectPools.muzzleFlashes)
	end
	return EffectsController.CreateMuzzleFlashPart()
end

function EffectsController.ReturnMuzzleFlashToPool(muzzleFlash: BasePart)
	muzzleFlash.Parent = nil
	muzzleFlash.Transparency = 0
	muzzleFlash.Size = Vector3.new(1, 1, 1)
	table.insert(effectPools.muzzleFlashes, muzzleFlash)
end

function EffectsController.GetPooledBulletTrail(): BasePart?
	if #effectPools.bulletTrails > 0 then
		return table.remove(effectPools.bulletTrails)
	end
	return EffectsController.CreateBulletTrailPart()
end

function EffectsController.ReturnBulletTrailToPool(trail: BasePart)
	trail.Parent = nil
	trail.Transparency = 0.5
	table.insert(effectPools.bulletTrails, trail)
end

function EffectsController.GetPooledImpactParticle(): BasePart?
	if #effectPools.impactParticles > 0 then
		return table.remove(effectPools.impactParticles)
	end
	return EffectsController.CreateImpactParticle()
end

function EffectsController.ReturnImpactParticleToPool(particle: BasePart)
	particle.Parent = nil
	table.insert(effectPools.impactParticles, particle)
end

function EffectsController.GetPooledBloodParticle(): BasePart?
	if #effectPools.bloodParticles > 0 then
		return table.remove(effectPools.bloodParticles)
	end
	return EffectsController.CreateBloodParticle()
end

-- Part creation functions
function EffectsController.CreateMuzzleFlashPart(): BasePart
	local part = Instance.new("Part")
	part.Name = "MuzzleFlash"
	part.Material = Enum.Material.Neon
	part.Color = Color3.new(1, 0.8, 0.2)
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(0.5, 0.5, 0.5)
	part.CanCollide = false
	part.Anchored = true
	
	return part
end

function EffectsController.CreateBulletTrailPart(): BasePart
	local part = Instance.new("Part")
	part.Name = "BulletTrail"
	part.Material = Enum.Material.Neon
	part.Color = Color3.new(1, 1, 0.8)
	part.Size = Vector3.new(0.1, 0.1, 1)
	part.CanCollide = false
	part.Anchored = true
	part.Transparency = 0.5
	
	return part
end

function EffectsController.CreateImpactParticle(): BasePart
	local part = Instance.new("Part")
	part.Name = "ImpactParticle"
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.CanCollide = false
	part.Anchored = true
	
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxassetid://241650934"
	emitter.Lifetime = NumberRange.new(0.3, 0.8)
	emitter.Rate = 0
	emitter.SpreadAngle = Vector2.new(45, 45)
	emitter.Speed = NumberRange.new(5, 15)
	emitter.Parent = part
	
	return part
end

function EffectsController.CreateBloodParticle(): BasePart
	local part = Instance.new("Part")
	part.Name = "BloodParticle"
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.CanCollide = false
	part.Anchored = true
	
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxassetid://241650934"
	emitter.Color = ColorSequence.new(Color3.new(0.8, 0.1, 0.1))
	emitter.Lifetime = NumberRange.new(0.5, 1.5)
	emitter.Rate = 0
	emitter.SpreadAngle = Vector2.new(30, 30)
	emitter.Speed = NumberRange.new(2, 8)
	emitter.Parent = part
	
	return part
end

-- Utility functions
function EffectsController.CreatePositionalSound(soundId: string, position: Vector3): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = 1
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.MaxDistance = EFFECT_CONFIG.soundMaxDistance
	
	-- Create invisible part for positional audio
	local soundPart = Instance.new("Part")
	soundPart.Transparency = 1
	soundPart.CanCollide = false
	soundPart.Anchored = true
	soundPart.Size = Vector3.new(1, 1, 1)
	soundPart.Position = position
	soundPart.Parent = workspace
	
	sound.Parent = soundPart
	
	-- Clean up part when sound ends
	sound.Ended:Connect(function()
		soundPart:Destroy()
	end)
	
	return sound
end

function EffectsController.GetWeaponModel(weaponID: WeaponID): Model?
	-- TODO: Get weapon model from character or camera
	return nil
end

function EffectsController.IsPlayerPart(part: BasePart): boolean
	local character = part.Parent
	return character and character:FindFirstChild("Humanoid") ~= nil
end

return EffectsController
