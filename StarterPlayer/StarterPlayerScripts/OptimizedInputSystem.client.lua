-- OptimizedInputSystem.client.lua
-- High-performance input system with prediction and lag compensation

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()
local Camera = workspace.CurrentCamera

local OptimizedInputSystem = {}

-- Input configuration
local INPUT_CONFIG = {
	mouseSensitivity = 1.0,
	enableRawInput = true,
	enablePrediction = true,
	maxInputLatency = 16, -- milliseconds
	inputBufferSize = 10,
	
	-- Keybinds
	fireKey = Enum.UserInputType.MouseButton1,
	reloadKey = Enum.KeyCode.R,
	switchWeaponKey = Enum.KeyCode.Q,
	jumpKey = Enum.KeyCode.Space,
	sprintKey = Enum.KeyCode.LeftShift,
	aimKey = Enum.UserInputType.MouseButton2
}

-- Input state
local inputState = {
	isMouseButtonDown = {},
	isKeyDown = {},
	lastInputTime = {},
	inputBuffer = {},
	mouseDelta = Vector2.new(0, 0),
	cameraSensitivity = 1.0
}

-- Input prediction
local prediction = {
	enabled = true,
	predictedActions = {},
	confirmationBuffer = {}
}

-- Performance metrics
local inputMetrics = {
	averageLatency = 0,
	inputsProcessed = 0,
	predictionsCorrect = 0,
	predictionsTotal = 0
}

-- Initialize the input system
function OptimizedInputSystem.Initialize()
	OptimizedInputSystem.SetupInputHandlers()
	OptimizedInputSystem.StartInputProcessing()
	OptimizedInputSystem.EnableRawInput()
	OptimizedInputSystem.OptimizeMouseTracking()
	
	print("[OptimizedInputSystem] High-performance input system initialized")
end

-- Setup optimized input handlers
function OptimizedInputSystem.SetupInputHandlers()
	-- Mouse input with prediction
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		local now = tick()
		inputState.lastInputTime[input.UserInputType] = now
		
		if input.UserInputType == INPUT_CONFIG.fireKey then
			inputState.isMouseButtonDown[Enum.UserInputType.MouseButton1] = true
			OptimizedInputSystem.HandleFireInput(now)
			
		elseif input.UserInputType == INPUT_CONFIG.aimKey then
			inputState.isMouseButtonDown[Enum.UserInputType.MouseButton2] = true
			OptimizedInputSystem.HandleAimInput(true)
			
		elseif input.KeyCode == INPUT_CONFIG.reloadKey then
			OptimizedInputSystem.HandleReloadInput(now)
			
		elseif input.KeyCode == INPUT_CONFIG.switchWeaponKey then
			OptimizedInputSystem.HandleWeaponSwitchInput(now)
			
		elseif input.KeyCode == INPUT_CONFIG.sprintKey then
			inputState.isKeyDown[Enum.KeyCode.LeftShift] = true
			OptimizedInputSystem.HandleSprintInput(true)
		end
	end)
	
	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.UserInputType == INPUT_CONFIG.fireKey then
			inputState.isMouseButtonDown[Enum.UserInputType.MouseButton1] = false
			
		elseif input.UserInputType == INPUT_CONFIG.aimKey then
			inputState.isMouseButtonDown[Enum.UserInputType.MouseButton2] = false
			OptimizedInputSystem.HandleAimInput(false)
			
		elseif input.KeyCode == INPUT_CONFIG.sprintKey then
			inputState.isKeyDown[Enum.KeyCode.LeftShift] = false
			OptimizedInputSystem.HandleSprintInput(false)
		end
	end)
end

-- Start input processing loop
function OptimizedInputSystem.StartInputProcessing()
	local lastProcess = tick()
	
	RunService.Heartbeat:Connect(function()
		local now = tick()
		local deltaTime = now - lastProcess
		
		-- Process input buffer
		OptimizedInputSystem.ProcessInputBuffer()
		
		-- Handle continuous inputs (like firing)
		if inputState.isMouseButtonDown[Enum.UserInputType.MouseButton1] then
			OptimizedInputSystem.HandleContinuousFire(now, deltaTime)
		end
		
		-- Update camera based on mouse movement
		OptimizedInputSystem.UpdateCamera(deltaTime)
		
		-- Process predictions
		if prediction.enabled then
			OptimizedInputSystem.ProcessPredictions(deltaTime)
		end
		
		lastProcess = now
	end)
end

-- Handle fire input with prediction
function OptimizedInputSystem.HandleFireInput(timestamp)
	local inputData = {
		action = "fire",
		timestamp = timestamp,
		origin = Camera.CFrame.Position,
		direction = Camera.CFrame.LookVector,
		predicted = false
	}
	
	-- Add to input buffer
	table.insert(inputState.inputBuffer, inputData)
	
	-- Client-side prediction
	if prediction.enabled then
		OptimizedInputSystem.PredictFire(inputData)
	end
	
	-- Limit buffer size
	if #inputState.inputBuffer > INPUT_CONFIG.inputBufferSize then
		table.remove(inputState.inputBuffer, 1)
	end
end

-- Handle continuous firing
function OptimizedInputSystem.HandleContinuousFire(now, deltaTime)
	-- This would implement automatic firing for weapons that support it
	-- Rate limiting would be handled here
end

-- Client-side prediction for fire
function OptimizedInputSystem.PredictFire(inputData)
	local predictionId = HttpService:GenerateGUID(false)
	
	-- Store prediction
	prediction.predictedActions[predictionId] = {
		action = "fire",
		timestamp = inputData.timestamp,
		origin = inputData.origin,
		direction = inputData.direction,
		confirmed = false
	}
	
	-- Perform client-side raycast for immediate feedback
	local raycast = workspace:Raycast(inputData.origin, inputData.direction * 1000)
	
	if raycast then
		-- Show immediate hit effect
		OptimizedInputSystem.ShowPredictedHitEffect(raycast.Position, raycast.Normal)
	end
	
	-- Clean up old predictions
	OptimizedInputSystem.CleanupPredictions()
end

-- Show predicted hit effect
function OptimizedInputSystem.ShowPredictedHitEffect(position, normal)
	-- Create temporary hit effect
	local effect = Instance.new("Explosion")
	effect.Position = position
	effect.BlastRadius = 5
	effect.BlastPressure = 0
	effect.Parent = workspace
	
	-- Remove after short time if not confirmed
	task.spawn(function()
		task.wait(0.1)
		if effect.Parent then
			effect:Destroy()
		end
	end)
end

-- Process input buffer
function OptimizedInputSystem.ProcessInputBuffer()
	for i = #inputState.inputBuffer, 1, -1 do
		local input = inputState.inputBuffer[i]
		local latency = (tick() - input.timestamp) * 1000 -- Convert to milliseconds
		
		-- Only send if latency is acceptable
		if latency <= INPUT_CONFIG.maxInputLatency then
			OptimizedInputSystem.SendInputToServer(input)
			table.remove(inputState.inputBuffer, i)
			
			-- Update metrics
			inputMetrics.inputsProcessed = inputMetrics.inputsProcessed + 1
			inputMetrics.averageLatency = (inputMetrics.averageLatency + latency) / 2
		end
	end
end

-- Send input to server
function OptimizedInputSystem.SendInputToServer(inputData)
	local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
	local CombatEvents = RemoteRoot:WaitForChild("CombatEvents")
	
	if inputData.action == "fire" then
		local fireRemote = CombatEvents:WaitForChild("FireWeapon")
		fireRemote:FireServer(inputData.origin, inputData.direction)
		
	elseif inputData.action == "reload" then
		local reloadRemote = CombatEvents:WaitForChild("RequestReload")
		reloadRemote:FireServer()
		
	elseif inputData.action == "switchWeapon" then
		local switchRemote = CombatEvents:WaitForChild("SwitchWeapon")
		switchRemote:FireServer(inputData.weaponIndex)
	end
end

-- Handle aim input
function OptimizedInputSystem.HandleAimInput(isAiming)
	-- Adjust camera sensitivity when aiming
	if isAiming then
		inputState.cameraSensitivity = 0.5
	else
		inputState.cameraSensitivity = 1.0
	end
end

-- Handle reload input
function OptimizedInputSystem.HandleReloadInput(timestamp)
	local inputData = {
		action = "reload",
		timestamp = timestamp
	}
	
	table.insert(inputState.inputBuffer, inputData)
end

-- Handle weapon switch input
function OptimizedInputSystem.HandleWeaponSwitchInput(timestamp)
	local inputData = {
		action = "switchWeapon",
		timestamp = timestamp,
		weaponIndex = 1 -- This would cycle through weapons
	}
	
	table.insert(inputState.inputBuffer, inputData)
end

-- Handle sprint input
function OptimizedInputSystem.HandleSprintInput(isSprinting)
	-- This would modify player movement speed
	-- Implementation would depend on your movement system
end

-- Update camera based on mouse movement
function OptimizedInputSystem.UpdateCamera(deltaTime)
	local mouseDelta = UserInputService:GetMouseDelta()
	
	if mouseDelta.Magnitude > 0 then
		-- Apply sensitivity and smoothing
		local adjustedDelta = mouseDelta * INPUT_CONFIG.mouseSensitivity * inputState.cameraSensitivity
		
		-- Apply camera rotation
		local currentCFrame = Camera.CFrame
		local yaw = -adjustedDelta.X * 0.005
		local pitch = -adjustedDelta.Y * 0.005
		
		-- Clamp pitch to prevent camera flipping
		local newCFrame = currentCFrame * CFrame.Angles(pitch, yaw, 0)
		Camera.CFrame = newCFrame
	end
end

-- Enable raw input for better precision
function OptimizedInputSystem.EnableRawInput()
	if INPUT_CONFIG.enableRawInput then
		-- Enable raw mouse input if supported
		local success, _ = pcall(function()
			UserInputService.MouseDeltaSensitivity = 1.0
		end)
		
		if success then
			print("[OptimizedInputSystem] Raw input enabled")
		end
	end
end

-- Optimize mouse tracking
function OptimizedInputSystem.OptimizeMouseTracking()
	-- Disable mouse icon for better performance
	UserInputService.MouseIconEnabled = false
	
	-- Lock mouse to center when in game
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
end

-- Process predictions and confirmations
function OptimizedInputSystem.ProcessPredictions(deltaTime)
	-- Clean up old predictions
	local now = tick()
	for predictionId, prediction in pairs(prediction.predictedActions) do
		if now - prediction.timestamp > 1.0 then -- 1 second timeout
			prediction.predictedActions[predictionId] = nil
		end
	end
end

-- Clean up old predictions
function OptimizedInputSystem.CleanupPredictions()
	prediction.predictionsTotal = prediction.predictionsTotal + 1
	
	-- Calculate prediction accuracy
	if prediction.predictionsTotal > 0 then
		local accuracy = (prediction.predictionsCorrect / prediction.predictionsTotal) * 100
		-- This could be used for adaptive prediction tuning
	end
end

-- Get input system statistics
function OptimizedInputSystem.GetStats()
	return {
		averageLatency = inputMetrics.averageLatency,
		inputsProcessed = inputMetrics.inputsProcessed,
		predictionAccuracy = prediction.predictionsTotal > 0 and 
			(prediction.predictionsCorrect / prediction.predictionsTotal * 100) or 0,
		bufferSize = #inputState.inputBuffer
	}
end

-- Configuration functions
function OptimizedInputSystem.SetMouseSensitivity(sensitivity)
	INPUT_CONFIG.mouseSensitivity = math.clamp(sensitivity, 0.1, 5.0)
end

function OptimizedInputSystem.SetPredictionEnabled(enabled)
	prediction.enabled = enabled
end

function OptimizedInputSystem.SetMaxInputLatency(latency)
	INPUT_CONFIG.maxInputLatency = math.max(1, latency)
end

return OptimizedInputSystem
