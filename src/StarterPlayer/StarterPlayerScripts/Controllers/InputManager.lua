--!strict
--[[
	InputManager.lua
	Cross-platform input handling for mobile and desktop
]]

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

type InputCallback = () -> ()
type InputCallbackWithState = (actionName: string, inputState: Enum.UserInputState, inputObject: InputObject) -> ()

local InputManager = {}

-- Configuration
local INPUT_CONFIG = {
	mouseSensitivity = 1.0,
	invertY = false,
	deadZone = 0.1,
	mobileUIScale = 1.0,
	vibrationEnabled = true
}

-- Input state
local boundActions: {[string]: {
	startCallback: InputCallback?,
	endCallback: InputCallback?,
	keyCode: Enum.KeyCode?,
	inputType: Enum.UserInputType?
}} = {}

local isMouseLocked = false
local lastMousePosition = Vector2.new()
local touchConnections: {[InputObject]: RBXScriptConnection} = {}

-- Platform detection
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local isGamepad = UserInputService.GamepadEnabled
local isDesktop = UserInputService.KeyboardEnabled and UserInputService.MouseEnabled

-- Initialize input manager
function InputManager.Initialize()
	-- Set up platform-specific input
	if isMobile then
		InputManager.SetupMobileInput()
	elseif isGamepad then
		InputManager.SetupGamepadInput()
	else
		InputManager.SetupDesktopInput()
	end
	
	-- Set up universal input handlers
	InputManager.SetupUniversalInput()
	
	print("[InputManager] ✓ Initialized for platform:", isMobile and "Mobile" or isGamepad and "Gamepad" or "Desktop")
end

-- Bind action to input
function InputManager.BindAction(actionName: string, startCallback: InputCallback?, endCallback: InputCallback?)
	boundActions[actionName] = {
		startCallback = startCallback,
		endCallback = endCallback
	}
	
	-- Set default key bindings
	local keyCode = InputManager.GetDefaultKeyCode(actionName)
	if keyCode then
		boundActions[actionName].keyCode = keyCode
	end
end

-- Get default key code for action
function InputManager.GetDefaultKeyCode(actionName: string): Enum.KeyCode?
	local defaultBindings = {
		Fire = Enum.KeyCode.ButtonR2, -- Mouse1 for desktop
		Reload = Enum.KeyCode.R,
		Aim = Enum.KeyCode.ButtonL2, -- Mouse2 for desktop
		Jump = Enum.KeyCode.Space,
		Crouch = Enum.KeyCode.LeftControl,
		Sprint = Enum.KeyCode.LeftShift,
		Weapon1 = Enum.KeyCode.One,
		Weapon2 = Enum.KeyCode.Two,
		Weapon3 = Enum.KeyCode.Three,
		Interact = Enum.KeyCode.E,
		Scoreboard = Enum.KeyCode.Tab
	}
	
	return defaultBindings[actionName]
end

-- Set up desktop input
function InputManager.SetupDesktopInput()
	-- Mouse input
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			InputManager.HandleActionStart("Fire")
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			InputManager.HandleActionStart("Aim")
		end
	end)
	
	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			InputManager.HandleActionEnd("Fire")
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			InputManager.HandleActionEnd("Aim")
		end
	end)
	
	-- Keyboard input
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.UserInputType == Enum.UserInputType.Keyboard then
			InputManager.HandleKeyboardInput(input.KeyCode, true)
		end
	end)
	
	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.UserInputType == Enum.UserInputType.Keyboard then
			InputManager.HandleKeyboardInput(input.KeyCode, false)
		end
	end)
	
	-- Mouse lock for camera
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement and isMouseLocked then
			local delta = input.Delta * INPUT_CONFIG.mouseSensitivity
			if INPUT_CONFIG.invertY then
				delta = Vector2.new(delta.X, -delta.Y)
			end
			InputManager.OnMouseMove(delta)
		end
	end)
end

-- Set up mobile input
function InputManager.SetupMobileInput()
	-- Touch input for looking around
	UserInputService.TouchStarted:Connect(function(touch, gameProcessed)
		if gameProcessed then return end
		InputManager.HandleTouchStart(touch)
	end)
	
	UserInputService.TouchMoved:Connect(function(touch, gameProcessed)
		if gameProcessed then return end
		InputManager.HandleTouchMove(touch)
	end)
	
	UserInputService.TouchEnded:Connect(function(touch, gameProcessed)
		if gameProcessed then return end
		InputManager.HandleTouchEnd(touch)
	end)
	
	-- Accelerometer for device tilt (optional)
	if UserInputService.AccelerometerEnabled then
		UserInputService.DeviceAccelerationChanged:Connect(function(acceleration)
			-- TODO: Handle device tilt for additional controls
		end)
	end
	
	-- Gyroscope for precise aiming (optional)
	if UserInputService.GyroscopeEnabled then
		UserInputService.DeviceRotationChanged:Connect(function(rotation, cframe)
			-- TODO: Handle gyroscope input for fine aiming
		end)
	end
end

-- Set up gamepad input
function InputManager.SetupGamepadInput()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.UserInputType == Enum.UserInputType.Gamepad1 then
			InputManager.HandleGamepadInput(input.KeyCode, true)
		end
	end)
	
	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.UserInputType == Enum.UserInputType.Gamepad1 then
			InputManager.HandleGamepadInput(input.KeyCode, false)
		end
	end)
	
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Gamepad1 then
			InputManager.HandleGamepadAnalog(input)
		end
	end)
end

-- Set up universal input handlers
function InputManager.SetupUniversalInput()
	-- Window focus handling
	UserInputService.WindowFocused:Connect(function()
		-- Resume input processing
	end)
	
	UserInputService.WindowFocusReleased:Connect(function()
		-- Pause input processing
		InputManager.ReleaseAllInputs()
	end)
	
	-- Jump detection (space/gamepad button)
	UserInputService.JumpRequest:Connect(function()
		InputManager.HandleActionStart("Jump")
		task.wait(0.1)
		InputManager.HandleActionEnd("Jump")
	end)
end

-- Handle keyboard input
function InputManager.HandleKeyboardInput(keyCode: Enum.KeyCode, isPressed: boolean)
	for actionName, actionData in pairs(boundActions) do
		if actionData.keyCode == keyCode then
			if isPressed then
				InputManager.HandleActionStart(actionName)
			else
				InputManager.HandleActionEnd(actionName)
			end
			break
		end
	end
end

-- Handle gamepad input
function InputManager.HandleGamepadInput(keyCode: Enum.KeyCode, isPressed: boolean)
	local actionMap = {
		[Enum.KeyCode.ButtonR2] = "Fire",
		[Enum.KeyCode.ButtonL2] = "Aim",
		[Enum.KeyCode.ButtonY] = "Reload",
		[Enum.KeyCode.ButtonA] = "Jump",
		[Enum.KeyCode.ButtonB] = "Crouch",
		[Enum.KeyCode.ButtonX] = "Interact",
		[Enum.KeyCode.DPadUp] = "Weapon1",
		[Enum.KeyCode.DPadRight] = "Weapon2",
		[Enum.KeyCode.DPadDown] = "Weapon3"
	}
	
	local actionName = actionMap[keyCode]
	if actionName then
		if isPressed then
			InputManager.HandleActionStart(actionName)
		else
			InputManager.HandleActionEnd(actionName)
		end
	end
end

-- Handle gamepad analog sticks
function InputManager.HandleGamepadAnalog(input: InputObject)
	if input.KeyCode == Enum.KeyCode.Thumbstick1 then
		-- Left stick - movement (handled by Roblox default)
	elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
		-- Right stick - camera
		local delta = input.Position
		
		-- Apply deadzone
		if delta.Magnitude < INPUT_CONFIG.deadZone then
			delta = Vector2.new()
		end
		
		-- Apply sensitivity and inversion
		delta = delta * INPUT_CONFIG.mouseSensitivity * 2
		if INPUT_CONFIG.invertY then
			delta = Vector2.new(delta.X, -delta.Y)
		end
		
		InputManager.OnMouseMove(delta)
	end
end

-- Handle touch input
function InputManager.HandleTouchStart(touch: InputObject)
	-- Determine touch zone
	local screenSize = workspace.CurrentCamera.ViewportSize
	local touchPosition = touch.Position
	
	-- Right side of screen for camera control
	if touchPosition.X > screenSize.X * 0.6 then
		touchConnections[touch] = UserInputService.TouchMoved:Connect(function(movedTouch)
			if movedTouch == touch then
				InputManager.HandleTouchMove(movedTouch)
			end
		end)
	end
	
	-- Left side of screen for movement (handled by default mobile controls)
	-- Bottom right for fire button (if no UI button)
	if touchPosition.X > screenSize.X * 0.8 and touchPosition.Y > screenSize.Y * 0.7 then
		InputManager.HandleActionStart("Fire")
	end
end

function InputManager.HandleTouchMove(touch: InputObject)
	-- Calculate delta for camera movement
	local delta = touch.Delta * INPUT_CONFIG.mouseSensitivity * 0.5
	if INPUT_CONFIG.invertY then
		delta = Vector2.new(delta.X, -delta.Y)
	end
	
	InputManager.OnMouseMove(delta)
end

function InputManager.HandleTouchEnd(touch: InputObject)
	-- Clean up touch connections
	local connection = touchConnections[touch]
	if connection then
		connection:Disconnect()
		touchConnections[touch] = nil
	end
	
	-- Stop firing if this was a fire touch
	InputManager.HandleActionEnd("Fire")
end

-- Handle action start
function InputManager.HandleActionStart(actionName: string)
	local actionData = boundActions[actionName]
	if actionData and actionData.startCallback then
		actionData.startCallback()
	end
end

-- Handle action end
function InputManager.HandleActionEnd(actionName: string)
	local actionData = boundActions[actionName]
	if actionData and actionData.endCallback then
		actionData.endCallback()
	end
end

-- Mouse movement callback (override this)
function InputManager.OnMouseMove(delta: Vector2)
	-- Override this function to handle camera movement
end

-- Mouse lock management
function InputManager.LockMouse()
	if not isMouseLocked and isDesktop then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		isMouseLocked = true
	end
end

function InputManager.UnlockMouse()
	if isMouseLocked then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		isMouseLocked = false
	end
end

-- Release all inputs (for window focus loss)
function InputManager.ReleaseAllInputs()
	for actionName in pairs(boundActions) do
		InputManager.HandleActionEnd(actionName)
	end
end

-- Haptic feedback (mobile)
function InputManager.PlayHapticFeedback(type: string, intensity: number)
	if isMobile and INPUT_CONFIG.vibrationEnabled then
		-- Use available haptic types: "ImpactLight", "ImpactMedium", "ImpactHeavy"
		if type == "ImpactLight" then
			UserInputService:PulseCoreHaptics("ImpactLight", intensity)
		elseif type == "ImpactMedium" then
			UserInputService:PulseCoreHaptics("ImpactMedium", intensity)
		elseif type == "ImpactHeavy" then
			UserInputService:PulseCoreHaptics("ImpactHeavy", intensity)
		end
	end
end

-- Configuration updates
function InputManager.UpdateSensitivity(sensitivity: number)
	INPUT_CONFIG.mouseSensitivity = math.clamp(sensitivity, 0.1, 5.0)
end

function InputManager.UpdateInvertY(invert: boolean)
	INPUT_CONFIG.invertY = invert
end

function InputManager.UpdateVibration(enabled: boolean)
	INPUT_CONFIG.vibrationEnabled = enabled
end

-- Platform queries
function InputManager.IsMobile(): boolean
	return isMobile
end

function InputManager.IsGamepad(): boolean
	return isGamepad
end

function InputManager.IsDesktop(): boolean
	return isDesktop
end

-- Get input configuration
function InputManager.GetConfig(): typeof(INPUT_CONFIG)
	return INPUT_CONFIG
end

return InputManager
