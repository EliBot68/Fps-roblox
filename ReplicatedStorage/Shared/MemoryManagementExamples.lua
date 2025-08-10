--[[
	MemoryManagementExamples.lua
	Comprehensive usage examples for Phase 2.4 Memory Management System

	Examples for:
	- Bullet pooling for high-performance combat
	- Effect pooling for visual elements
	- UI element pooling for dynamic interfaces
	- Integration with existing weapon systems
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ObjectPool = require(ReplicatedStorage.Shared.ObjectPool)
local ServiceLocator = require(ReplicatedStorage.Shared.ServiceLocator)
local Logging = require(ReplicatedStorage.Shared.Logging)

local MemoryExamples = {}

-- Example 1: Bullet Pooling for Combat System
function MemoryExamples.SetupBulletPooling()
	-- Create bullet pool with custom configuration
	local bulletPool = ObjectPool.new("CombatBullets", 
		-- Factory function
		function()
			local bullet = Instance.new("Part")
			bullet.Name = "Bullet"
			bullet.Size = Vector3.new(0.2, 0.2, 1)
			bullet.Material = Enum.Material.Neon
			bullet.BrickColor = BrickColor.new("Bright yellow")
			bullet.CanCollide = false
			bullet.Anchored = true
			
			-- Add tracer effect
			local attachment = Instance.new("Attachment")
			attachment.Parent = bullet
			
			local trail = Instance.new("Trail")
			trail.Parent = bullet
			trail.Attachment0 = attachment
			trail.Attachment1 = attachment
			trail.Lifetime = 0.3
			trail.MinLength = 0
			trail.FaceCamera = true
			
			return bullet
		end,
		
		-- Reset function
		function(bullet)
			bullet.Position = Vector3.new(0, -1000, 0) -- Hide offscreen
			bullet.Parent = nil
			bullet.Trail.Enabled = false
			bullet.Transparency = 0
		end,
		
		-- Configuration
		{
			maxSize = 500, -- High capacity for combat
			prepopulate = 50,
			autoResize = true,
			leakThreshold = 5 -- Bullets should return quickly
		}
	)
	
	-- Usage function for firing bullets
	local function fireBullet(origin: Vector3, direction: Vector3, speed: number)
		local bullet = ObjectPool.Get(bulletPool)
		bullet.Position = origin
		bullet.CFrame = CFrame.lookAt(origin, origin + direction)
		bullet.Parent = workspace
		bullet.Trail.Enabled = true
		
		-- Animate bullet movement
		local connection
		local startTime = tick()
		
		connection = RunService.Heartbeat:Connect(function()
			local elapsed = tick() - startTime
			local distance = speed * elapsed
			
			bullet.Position = origin + direction * distance
			
			-- Return bullet after 2 seconds or if too far
			if elapsed > 2 or distance > 1000 then
				connection:Disconnect()
				ObjectPool.Return(bulletPool, bullet)
			end
		end)
	end
	
	Logging.Info("MemoryExamples", "Bullet pooling system initialized", {
		poolName = "CombatBullets",
		maxSize = 500,
		prepopulated = 50
	})
	
	return {pool = bulletPool, fire = fireBullet}
end

-- Example 2: Effect Pooling for Visual Elements
function MemoryExamples.SetupEffectPooling()
	-- Explosion effect pool
	local explosionPool = ObjectPool.new("ExplosionEffects",
		function()
			local effect = Instance.new("Part")
			effect.Name = "Explosion"
			effect.Size = Vector3.new(1, 1, 1)
			effect.Material = Enum.Material.ForceField
			effect.BrickColor = BrickColor.new("Bright orange")
			effect.CanCollide = false
			effect.Anchored = true
			effect.Shape = Enum.PartType.Ball
			
			-- Add particle effects
			local particles = Instance.new("ParticleEmitter")
			particles.Parent = effect
			particles.Texture = "rbxasset://textures/particles/explosion01_implosion_main.png"
			particles.Lifetime = NumberRange.new(0.3, 1.2)
			particles.Rate = 200
			particles.SpreadAngle = Vector2.new(45, 45)
			
			return effect
		end,
		
		function(effect)
			effect.Size = Vector3.new(1, 1, 1)
			effect.Transparency = 0
			effect.Parent = nil
			effect.ParticleEmitter.Enabled = false
		end,
		
		{maxSize = 100, prepopulate = 10}
	)
	
	-- Hit effect pool
	local hitEffectPool = ObjectPool.new("HitEffects",
		function()
			local effect = Instance.new("Part")
			effect.Size = Vector3.new(0.5, 0.5, 0.5)
			effect.Material = Enum.Material.Neon
			effect.BrickColor = BrickColor.new("Bright red")
			effect.CanCollide = false
			effect.Anchored = true
			effect.Shape = Enum.PartType.Ball
			return effect
		end,
		
		function(effect)
			effect.Size = Vector3.new(0.5, 0.5, 0.5)
			effect.Transparency = 0
			effect.Parent = nil
		end,
		
		{maxSize = 200, prepopulate = 20}
	)
	
	-- Usage functions
	local function createExplosion(position: Vector3, size: number)
		local explosion = ObjectPool.Get(explosionPool)
		explosion.Position = position
		explosion.Size = Vector3.new(size, size, size)
		explosion.Parent = workspace
		explosion.ParticleEmitter.Enabled = true
		
		-- Animate expansion and fade
		local tween = TweenService:Create(explosion, 
			TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = Vector3.new(size * 3, size * 3, size * 3), Transparency = 1}
		)
		tween:Play()
		
		tween.Completed:Connect(function()
			ObjectPool.Return(explosionPool, explosion)
		end)
	end
	
	local function createHitEffect(position: Vector3)
		local hit = ObjectPool.Get(hitEffectPool)
		hit.Position = position
		hit.Parent = workspace
		
		-- Quick flash effect
		local tween = TweenService:Create(hit,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad),
			{Transparency = 1}
		)
		tween:Play()
		
		tween.Completed:Connect(function()
			ObjectPool.Return(hitEffectPool, hit)
		end)
	end
	
	return {
		explosion = {pool = explosionPool, create = createExplosion},
		hit = {pool = hitEffectPool, create = createHitEffect}
	}
end

-- Example 3: UI Element Pooling
function MemoryExamples.SetupUIPooling()
	-- Damage number pool
	local damageNumberPool = ObjectPool.new("DamageNumbers",
		function()
			local gui = Instance.new("ScreenGui")
			gui.Name = "DamageNumber"
			
			local frame = Instance.new("Frame")
			frame.Size = UDim2.new(0, 100, 0, 30)
			frame.BackgroundTransparency = 1
			frame.Parent = gui
			
			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, 0, 1, 0)
			label.BackgroundTransparency = 1
			label.TextColor3 = Color3.new(1, 0, 0)
			label.TextStrokeTransparency = 0
			label.Font = Enum.Font.SourceSansBold
			label.TextScaled = true
			label.Parent = frame
			
			return gui
		end,
		
		function(gui)
			gui.Parent = nil
			gui.Frame.TextLabel.Text = ""
			gui.Frame.Position = UDim2.new(0, 0, 0, 0)
			gui.Frame.TextLabel.TextTransparency = 0
		end,
		
		{maxSize = 50, prepopulate = 5}
	)
	
	-- Usage function
	local function showDamageNumber(player: Player, damage: number, position: Vector3)
		local gui = ObjectPool.Get(damageNumberPool)
		gui.Parent = player.PlayerGui
		gui.Frame.TextLabel.Text = tostring(damage)
		
		-- Convert world position to screen position
		local camera = workspace.CurrentCamera
		local screenPos, onScreen = camera:WorldToScreenPoint(position)
		
		if onScreen then
			gui.Frame.Position = UDim2.new(0, screenPos.X - 50, 0, screenPos.Y - 15)
			
			-- Animate upward movement and fade
			local tween = TweenService:Create(gui.Frame,
				TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{Position = UDim2.new(0, screenPos.X - 50, 0, screenPos.Y - 100)}
			)
			
			local fadeTween = TweenService:Create(gui.Frame.TextLabel,
				TweenInfo.new(1, Enum.EasingStyle.Quad),
				{TextTransparency = 1}
			)
			
			tween:Play()
			fadeTween:Play()
			
			fadeTween.Completed:Connect(function()
				ObjectPool.Return(damageNumberPool, gui)
			end)
		else
			-- Position not visible, return immediately
			ObjectPool.Return(damageNumberPool, gui)
		end
	end
	
	return {pool = damageNumberPool, show = showDamageNumber}
end

-- Example 4: Integration with Weapon System
function MemoryExamples.IntegrateWithWeaponSystem()
	local weaponPools = {}
	
	-- Create pools for different weapon types
	local weaponTypes = {"Rifle", "Pistol", "Shotgun", "Sniper"}
	
	for _, weaponType in ipairs(weaponTypes) do
		weaponPools[weaponType] = ObjectPool.new(weaponType .. "Casings",
			function()
				local casing = Instance.new("Part")
				casing.Name = weaponType .. "Casing"
				casing.Size = Vector3.new(0.1, 0.1, 0.2)
				casing.Material = Enum.Material.Metal
				casing.BrickColor = BrickColor.new("Gold")
				casing.CanCollide = true
				
				-- Add physics
				local bodyVelocity = Instance.new("BodyVelocity")
				bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
				bodyVelocity.Parent = casing
				
				return casing
			end,
			
			function(casing)
				casing.Position = Vector3.new(0, -1000, 0)
				casing.Velocity = Vector3.new(0, 0, 0)
				casing.AngularVelocity = Vector3.new(0, 0, 0)
				casing.Parent = nil
			end,
			
			{maxSize = 100, prepopulate = 10}
		)
	end
	
	-- Weapon firing integration
	local function onWeaponFired(weaponType: string, ejectionPosition: Vector3, direction: Vector3)
		local pool = weaponPools[weaponType]
		if not pool then return end
		
		local casing = ObjectPool.Get(pool)
		casing.Position = ejectionPosition
		casing.Parent = workspace
		
		-- Apply ejection physics
		local ejectionForce = direction:Cross(Vector3.new(0, 1, 0)).Unit * 10
		ejectionForce = ejectionForce + Vector3.new(0, 5, 0) -- Add upward component
		
		casing.BodyVelocity.Velocity = ejectionForce
		casing.AssemblyAngularVelocity = Vector3.new(
			math.random(-20, 20),
			math.random(-20, 20), 
			math.random(-20, 20)
		)
		
		-- Return casing after 10 seconds
		task.wait(10)
		ObjectPool.Return(pool, casing)
	end
	
	return {pools = weaponPools, onFired = onWeaponFired}
end

-- Example 5: Performance Monitoring Setup
function MemoryExamples.SetupPerformanceMonitoring()
	local MemoryManager = ServiceLocator.GetService("MemoryManager")
	
	-- Register alert callbacks
	MemoryManager.On("memoryWarning", function(key, data)
		Logging.Warn("MemoryExamples", "Memory warning triggered", data)
		-- Could trigger cleanup of non-essential pools
	end)
	
	MemoryManager.On("poolLeak", function(poolName, data)
		Logging.Error("MemoryExamples", "Pool leak detected", {pool = poolName, data = data})
		-- Could force cleanup of specific pool
	end)
	
	MemoryManager.On("lowEfficiency", function(poolName, data)
		Logging.Info("MemoryExamples", "Pool efficiency low", {pool = poolName, data = data})
		-- Could adjust pool parameters
	end)
	
	-- Periodic reporting
	task.spawn(function()
		while true do
			task.wait(300) -- Every 5 minutes
			local report = MemoryManager.GetReport()
			Logging.Info("MemoryExamples", "Memory report", {
				luaHeapMB = report.latest and report.latest.luaHeapKB / 1024,
				totalPools = #report.registeredPools,
				sampleCount = report.totalSamples
			})
		end
	end)
end

-- Initialize all examples
function MemoryExamples.InitializeAll()
	Logging.Info("MemoryExamples", "Initializing all memory management examples...")
	
	local systems = {
		bullets = MemoryExamples.SetupBulletPooling(),
		effects = MemoryExamples.SetupEffectPooling(),
		ui = MemoryExamples.SetupUIPooling(),
		weapons = MemoryExamples.IntegrateWithWeaponSystem()
	}
	
	MemoryExamples.SetupPerformanceMonitoring()
	
	Logging.Info("MemoryExamples", "All memory management examples initialized", {
		systems = {"bullets", "effects", "ui", "weapons", "monitoring"}
	})
	
	return systems
end

return MemoryExamples
