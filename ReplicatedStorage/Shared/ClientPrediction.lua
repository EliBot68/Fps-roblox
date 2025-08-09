--[[
	ClientPrediction.lua
	Enterprise client-side prediction system for responsive gameplay
	
	Predicts weapon fire, movement, and effects client-side while maintaining
	server authority for security. Handles server reconciliation seamlessly.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetworkBatcher = require(ReplicatedStorage.Shared.NetworkBatcher)
local ObjectPool = require(ReplicatedStorage.Shared.ObjectPool)

local ClientPrediction = {}

-- Prediction configuration
local RECONCILIATION_WINDOW = 1.0 -- Keep predictions for 1 second
local MAX_PREDICTION_DRIFT = 5 -- Max studs of prediction error before snap
local PREDICTION_SMOOTHING = 0.1 -- Smoothing factor for corrections

-- Prediction state tracking
local predictions = {} -- [predictionId] = {type, data, timestamp, confirmed}
local nextPredictionId = 1
local serverState = {} -- Latest confirmed server state
local predictionBuffer = {} -- Ordered list of predictions

-- Player reference
local player = Players.LocalPlayer

-- Initialize prediction system
function ClientPrediction.Initialize()
	-- Initialize object pools for predicted effects
	ObjectPool.new("PredictedBulletTrails", function()
		local trail = Instance.new("Part")
		trail.Name = "PredictedTrail"
		trail.Size = Vector3.new(0.05, 0.05, 0.1)
		trail.Material = Enum.Material.ForceField
		trail.BrickColor = BrickColor.new("Bright yellow")
		trail.CanCollide = false
		trail.Anchored = true
		trail.Transparency = 0.5
		return trail
	end)
	
	ObjectPool.new("PredictedHitEffects", function()
		local effect = Instance.new("Part")
		effect.Name = "PredictedHit"
		effect.Size = Vector3.new(0.5, 0.5, 0.5)
		effect.Shape = Enum.PartType.Ball
		effect.Material = Enum.Material.Neon
		effect.BrickColor = BrickColor.new("Really red")
		effect.CanCollide = false
		effect.Anchored = true
		effect.Transparency = 0.3
		return effect
	end)
	
	-- Listen for server reconciliation
	ClientPrediction.SetupReconciliation()
	
	print("[ClientPrediction] ✓ Initialized with", RECONCILIATION_WINDOW, "s window")
end

-- Predict weapon fire with immediate visual feedback
function ClientPrediction.PredictWeaponFire(weaponId: string, origin: Vector3, direction: Vector3): number
	local predictionId = nextPredictionId
	nextPredictionId = nextPredictionId + 1
	
	local timestamp = tick()
	
	-- Store prediction
	predictions[predictionId] = {
		type = "WeaponFire",
		weaponId = weaponId,
		origin = origin,
		direction = direction,
		timestamp = timestamp,
		confirmed = false
	}
	
	table.insert(predictionBuffer, predictionId)
	
	-- Show immediate visual feedback
	ClientPrediction.ShowPredictedWeaponEffects(weaponId, origin, direction, predictionId)
	
	-- Send to server for validation
	NetworkBatcher.QueueEvent("WeaponFire", player, {
		predictionId = predictionId,
		weaponId = weaponId,
		origin = origin,
		direction = direction,
		timestamp = timestamp
	})
	
	return predictionId
end

-- Show predicted weapon effects immediately
function ClientPrediction.ShowPredictedWeaponEffects(weaponId: string, origin: Vector3, direction: Vector3, predictionId: number)
	-- Get predicted bullet trail from pool
	local bulletTrailPool = ObjectPool.Get(ObjectPool.GetPool("PredictedBulletTrails"))
	local trail = ObjectPool.Get(bulletTrailPool)
	
	if trail then
		-- Position trail along predicted bullet path
		local distance = 100 -- Assume 100 stud range for prediction
		local endPosition = origin + (direction * distance)
		
		trail.CFrame = CFrame.lookAt(origin, endPosition)
		trail.Size = Vector3.new(0.05, 0.05, distance)
		trail.Parent = workspace
		
		-- Fade out prediction effect
		task.spawn(function()
			local startTime = tick()
			while tick() - startTime < 0.5 do
				local alpha = (tick() - startTime) / 0.5
				trail.Transparency = 0.5 + (alpha * 0.5)
				task.wait()
			end
			
			-- Return to pool
			trail.Parent = nil
			ObjectPool.Return(bulletTrailPool, trail)
		end)
	end
	
	-- Predict hit effects with simple raycast
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	raycastParams.FilterDescendantsInstances = {player.Character}
	
	local raycastResult = workspace:Raycast(origin, direction * 200, raycastParams)
	
	if raycastResult then
		-- Show predicted hit effect
		local hitEffectPool = ObjectPool.GetPool("PredictedHitEffects")
		local effect = ObjectPool.Get(hitEffectPool)
		
		if effect then
			effect.Position = raycastResult.Position
			effect.Parent = workspace
			
			-- Animate hit effect
			task.spawn(function()
				local startSize = Vector3.new(0.1, 0.1, 0.1)
				local endSize = Vector3.new(1, 1, 1)
				local duration = 0.3
				
				local startTime = tick()
				while tick() - startTime < duration do
					local alpha = (tick() - startTime) / duration
					effect.Size = startSize:Lerp(endSize, alpha)
					effect.Transparency = 0.3 + (alpha * 0.7)
					task.wait()
				end
				
				-- Return to pool
				effect.Parent = nil
				ObjectPool.Return(hitEffectPool, effect)
			end)
		end
	end
end

-- Setup server reconciliation system
function ClientPrediction.SetupReconciliation()
	-- Listen for server confirmations
	local reconciliationRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("PredictionReconciliation")
	
	reconciliationRemote.OnClientEvent:Connect(function(reconciliationData)
		ClientPrediction.HandleServerReconciliation(reconciliationData)
	end)
	
	-- Cleanup old predictions periodically
	task.spawn(function()
		while true do
			task.wait(1)
			ClientPrediction.CleanupOldPredictions()
		end
	end)
end

-- Handle server reconciliation
function ClientPrediction.HandleServerReconciliation(reconciliationData)
	local predictionId = reconciliationData.predictionId
	local serverResult = reconciliationData.result
	
	local prediction = predictions[predictionId]
	if not prediction then
		return -- Prediction already cleaned up
	end
	
	prediction.confirmed = true
	prediction.serverResult = serverResult
	
	-- Compare predicted vs actual results
	if serverResult.success then
		-- Prediction was correct, no action needed
		print("[ClientPrediction] ✓ Prediction", predictionId, "confirmed")
	else
		-- Prediction was wrong, show correction
		print("[ClientPrediction] ✗ Prediction", predictionId, "rejected:", serverResult.reason)
		ClientPrediction.ShowPredictionCorrection(prediction, serverResult)
	end
end

-- Show visual correction when prediction is wrong
function ClientPrediction.ShowPredictionCorrection(prediction, serverResult)
	-- Could show a brief "correction" effect
	-- For now, just log the correction
	warn("[ClientPrediction] Corrected prediction:", prediction.type, "Reason:", serverResult.reason)
end

-- Predict player movement for smooth interpolation
function ClientPrediction.PredictMovement(character: Model, velocity: Vector3, deltaTime: number): Vector3?
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return nil end
	
	local currentPosition = humanoidRootPart.Position
	local predictedPosition = currentPosition + (velocity * deltaTime)
	
	-- Validate prediction isn't too far off
	local maxMovement = 50 * deltaTime -- Max 50 studs/second
	local movementDistance = (predictedPosition - currentPosition).Magnitude
	
	if movementDistance > maxMovement then
		-- Clamp to maximum reasonable movement
		local direction = (predictedPosition - currentPosition).Unit
		predictedPosition = currentPosition + (direction * maxMovement)
	end
	
	return predictedPosition
end

-- Clean up old predictions
function ClientPrediction.CleanupOldPredictions()
	local currentTime = tick()
	local cleanedCount = 0
	
	-- Remove old predictions from buffer
	for i = #predictionBuffer, 1, -1 do
		local predictionId = predictionBuffer[i]
		local prediction = predictions[predictionId]
		
		if prediction and (currentTime - prediction.timestamp) > RECONCILIATION_WINDOW then
			predictions[predictionId] = nil
			table.remove(predictionBuffer, i)
			cleanedCount = cleanedCount + 1
		end
	end
	
	if cleanedCount > 0 then
		print("[ClientPrediction] ✓ Cleaned up", cleanedCount, "old predictions")
	end
end

-- Get prediction statistics
function ClientPrediction.GetStats(): {activePredictions: number, confirmationRate: number, avgLatency: number}
	local activePredictions = 0
	local confirmedPredictions = 0
	local totalLatency = 0
	local latencyCount = 0
	
	for _, prediction in pairs(predictions) do
		activePredictions = activePredictions + 1
		
		if prediction.confirmed then
			confirmedPredictions = confirmedPredictions + 1
			
			if prediction.serverResult then
				local latency = prediction.serverResult.serverTimestamp - prediction.timestamp
				totalLatency = totalLatency + latency
				latencyCount = latencyCount + 1
			end
		end
	end
	
	return {
		activePredictions = activePredictions,
		confirmationRate = activePredictions > 0 and (confirmedPredictions / activePredictions) or 0,
		avgLatency = latencyCount > 0 and (totalLatency / latencyCount) or 0
	}
end

return ClientPrediction
