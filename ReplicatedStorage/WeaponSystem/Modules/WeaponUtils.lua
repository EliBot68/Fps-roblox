--[[
	WeaponUtils.lua
	Place in: ReplicatedStorage/WeaponSystem/Modules/
	
	Utility functions for weapon system including raycast handling,
	spread calculation, recoil patterns, and VFX/SFX object pooling.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local WeaponUtils = {}

-- Object pools for performance
local MuzzleFlashPool = {}
local SoundPool = {}
local EffectPool = {}

-- Raycast parameters
local RaycastParams = RaycastParams.new()
RaycastParams.FilterType = Enum.RaycastFilterType.Blacklist
RaycastParams.IgnoreWater = true

-- VFX Asset IDs
local VFX_ASSETS = {
	MuzzleFlash = "rbxassetid://5069424304",
	BulletHit = "rbxassetid://151130059",
	WoodHit = "rbxassetid://6961977071"
}

-- Calculate bullet spread for weapon
function WeaponUtils.CalculateSpread(baseDirection: Vector3, spreadAngle: number): Vector3
	if spreadAngle <= 0 then
		return baseDirection
	end
	
	-- Generate random spread within cone
	local theta = math.random() * math.pi * 2 -- Random angle around circle
	local phi = math.acos(1 - math.random() * (1 - math.cos(spreadAngle))) -- Random angle from center
	
	-- Convert spherical to cartesian coordinates
	local x = math.sin(phi) * math.cos(theta)
	local y = math.sin(phi) * math.sin(theta)
	local z = math.cos(phi)
	
	-- Create orthonormal basis around base direction
	local up = math.abs(baseDirection.Y) < 0.99 and Vector3.new(0, 1, 0) or Vector3.new(1, 0, 0)
	local right = baseDirection:Cross(up).Unit
	up = right:Cross(baseDirection).Unit
	
	-- Transform spread vector to world space
	return baseDirection * z + right * x + up * y
end

-- Perform raycast with hit validation
function WeaponUtils.PerformRaycast(origin: Vector3, direction: Vector3, maxRange: number, ignoreList: {Instance}?): RaycastResult?
	-- Set up raycast parameters
	RaycastParams.FilterDescendantsInstances = ignoreList or {}
	
	-- Perform raycast
	local raycastResult = workspace:Raycast(origin, direction * maxRange, RaycastParams)
	
	return raycastResult
end

-- Handle shotgun spread (multiple pellets)
function WeaponUtils.ShotgunRaycast(origin: Vector3, baseDirection: Vector3, pelletCount: number, spread: number, maxRange: number, ignoreList: {Instance}?): {RaycastResult?}
	local results = {}
	
	for i = 1, pelletCount do
		local spreadDirection = WeaponUtils.CalculateSpread(baseDirection, spread)
		local result = WeaponUtils.PerformRaycast(origin, spreadDirection, maxRange, ignoreList)
		table.insert(results, result)
	end
	
	return results
end

-- Validate hit for headshot detection
function WeaponUtils.IsHeadshot(raycastResult: RaycastResult, targetCharacter: Model): boolean
	if not raycastResult or not targetCharacter then
		return false
	end
	
	local hitPart = raycastResult.Instance
	local humanoid = targetCharacter:FindFirstChild("Humanoid")
	
	if not humanoid then
		return false
	end
	
	-- Check if hit part is head or neck area
	if hitPart.Name == "Head" then
		return true
	end
	
	-- Additional check for headshot area using bounding box
	local head = targetCharacter:FindFirstChild("Head")
	if head then
		local hitPosition = raycastResult.Position
		local headPosition = head.Position
		local distance = (hitPosition - headPosition).Magnitude
		
		-- Consider hit within head radius as headshot
		return distance <= head.Size.Magnitude / 2
	end
	
	return false
end

-- Get or create muzzle flash effect
function WeaponUtils.GetMuzzleFlash(): ParticleEmitter
	if #MuzzleFlashPool > 0 then
		return table.remove(MuzzleFlashPool)
	end
	
	-- Create new muzzle flash
	local muzzleFlash = Instance.new("ParticleEmitter")
	muzzleFlash.Texture = VFX_ASSETS.MuzzleFlash
	muzzleFlash.Lifetime = NumberRange.new(0.1, 0.2)
	muzzleFlash.Rate = 500
	muzzleFlash.SpreadAngle = Vector2.new(25, 25)
	muzzleFlash.Speed = NumberRange.new(10, 20)
	muzzleFlash.VelocityInheritance = 0.5
	muzzleFlash.EmissionDirection = Enum.NormalId.Front
	
	return muzzleFlash
end

-- Return muzzle flash to pool
function WeaponUtils.ReturnMuzzleFlash(muzzleFlash: ParticleEmitter)
	muzzleFlash.Parent = nil
	muzzleFlash.Enabled = false
	table.insert(MuzzleFlashPool, muzzleFlash)
end

-- Get or create sound effect
function WeaponUtils.GetSound(soundId: string): Sound
	local poolKey = soundId
	
	if not SoundPool[poolKey] then
		SoundPool[poolKey] = {}
	end
	
	if #SoundPool[poolKey] > 0 then
		return table.remove(SoundPool[poolKey])
	end
	
	-- Create new sound
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = 0.5
	sound.Parent = SoundService
	
	return sound
end

-- Return sound to pool
function WeaponUtils.ReturnSound(sound: Sound)
	local poolKey = sound.SoundId
	
	if not SoundPool[poolKey] then
		SoundPool[poolKey] = {}
	end
	
	sound:Stop()
	table.insert(SoundPool[poolKey], sound)
end

-- Play sound effect with pooling
function WeaponUtils.PlaySound(soundId: string, volume: number?): Sound?
	if soundId == "" then return nil end
	
	local sound = WeaponUtils.GetSound(soundId)
	sound.Volume = volume or 0.5
	sound:Play()
	
	-- Return to pool after playing
	sound.Ended:Connect(function()
		WeaponUtils.ReturnSound(sound)
	end)
	
	return sound
end

-- Create hit effect at position
function WeaponUtils.CreateHitEffect(position: Vector3, normal: Vector3, material: Enum.Material?)
	-- Determine hit sound based on material
	local hitSound = VFX_ASSETS.BulletHit
	if material == Enum.Material.Wood or material == Enum.Material.WoodPlanks then
		hitSound = VFX_ASSETS.WoodHit
	end
	
	-- Play hit sound
	WeaponUtils.PlaySound(hitSound, 0.3)
	
	-- Create impact particle effect
	local hitEffect = Instance.new("Explosion")
	hitEffect.Position = position
	hitEffect.BlastRadius = 0
	hitEffect.BlastPressure = 0
	hitEffect.Visible = false -- No explosion visual, just for impact
	hitEffect.Parent = workspace
	
	-- Create spark particles
	local attachment = Instance.new("Attachment")
	attachment.Position = position
	attachment.Parent = workspace.Terrain
	
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxassetid://241650934" -- Spark texture
	sparks.Lifetime = NumberRange.new(0.2, 0.5)
	sparks.Rate = 100
	sparks.SpreadAngle = Vector2.new(45, 45)
	sparks.Speed = NumberRange.new(5, 15)
	sparks.Parent = attachment
	
	-- Clean up after effect
	task.spawn(function()
		sparks:Emit(10)
		task.wait(1)
		attachment:Destroy()
	end)
end

-- Validate fire rate (anti-exploit)
local LastFireTimes = {}
function WeaponUtils.ValidateFireRate(player: Player, weaponConfig, currentTime: number): boolean
	local playerId = player.UserId
	local lastFire = LastFireTimes[playerId] or 0
	local minInterval = 1 / weaponConfig.MaxFireRate
	
	if currentTime - lastFire < minInterval then
		return false -- Firing too fast
	end
	
	LastFireTimes[playerId] = currentTime
	return true
end

-- Validate shot direction (anti-exploit)
function WeaponUtils.ValidateDirection(player: Player, shotDirection: Vector3, maxDeviation: number?): boolean
	maxDeviation = maxDeviation or math.rad(60) -- 60 degree max deviation
	
	local character = player.Character
	if not character then return false end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return false end
	
	-- Get player's look direction
	local playerDirection = humanoidRootPart.CFrame.LookVector
	
	-- Calculate angle between shot direction and player direction
	local dotProduct = playerDirection:Dot(shotDirection.Unit)
	local angle = math.acos(math.clamp(dotProduct, -1, 1))
	
	return angle <= maxDeviation
end

-- Calculate damage with distance falloff
function WeaponUtils.CalculateDamage(baseDamage: number, distance: number, maxRange: number, headshotMultiplier: number?, isHeadshot: boolean?): number
	local damage = baseDamage
	
	-- Apply distance falloff (linear)
	local falloffStart = maxRange * 0.5 -- 50% of max range
	if distance > falloffStart then
		local falloffFactor = 1 - ((distance - falloffStart) / (maxRange - falloffStart)) * 0.5
		damage = damage * math.max(falloffFactor, 0.25) -- Minimum 25% damage
	end
	
	-- Apply headshot multiplier
	if isHeadshot and headshotMultiplier then
		damage = damage * headshotMultiplier
	end
	
	return math.floor(damage)
end

-- Get weapon model from assets
function WeaponUtils.GetWeaponModel(modelId: string): Model?
	local assetsFolder = ReplicatedStorage:WaitForChild("WeaponSystem"):WaitForChild("Assets")
	local modelName = "Model_" .. modelId:gsub("rbxassetid://", "")
	
	local existingModel = assetsFolder:FindFirstChild(modelName)
	if existingModel then
		return existingModel:Clone()
	end
	
	-- Load model if not cached
	local success, model = pcall(function()
		return game:GetService("InsertService"):LoadAsset(tonumber(modelId:gsub("rbxassetid://", "")))
	end)
	
	if success and model then
		model.Name = modelName
		model.Parent = assetsFolder
		return model:Clone()
	end
	
	warn("Failed to load weapon model: " .. modelId)
	return nil
end

-- Apply recoil pattern (client-side)
function WeaponUtils.ApplyRecoil(camera: Camera, recoilAmount: Vector3)
	local currentCFrame = camera.CFrame
	local recoilCFrame = CFrame.Angles(
		math.rad(-recoilAmount.X), -- Vertical recoil (up)
		math.rad(recoilAmount.Y * (math.random() > 0.5 and 1 or -1)), -- Horizontal recoil (random left/right)
		0
	)
	
	-- Apply recoil with tween for smooth recovery
	local recoilTween = TweenService:Create(
		camera,
		TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{CFrame = currentCFrame * recoilCFrame}
	)
	
	recoilTween:Play()
	
	-- Recovery tween
	recoilTween.Completed:Connect(function()
		local recoveryTween = TweenService:Create(
			camera,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{CFrame = currentCFrame}
		)
		recoveryTween:Play()
	end)
end

-- Clean up pools (call on game shutdown)
function WeaponUtils.Cleanup()
	-- Clear muzzle flash pool
	for _, effect in ipairs(MuzzleFlashPool) do
		effect:Destroy()
	end
	MuzzleFlashPool = {}
	
	-- Clear sound pools
	for _, pool in pairs(SoundPool) do
		for _, sound in ipairs(pool) do
			sound:Destroy()
		end
	end
	SoundPool = {}
	
	-- Clear last fire times
	LastFireTimes = {}
end

return WeaponUtils
