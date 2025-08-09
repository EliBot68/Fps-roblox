--[[
	AmmoCounter.lua
	Place in: StarterGui/WeaponUI/
	
	Creates and manages the ammo counter UI display showing current
	ammunition, weapon name, and reload status.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local AmmoCounter = {}

-- Create ammo counter UI
function AmmoCounter.CreateUI()
	-- Main weapon UI frame
	local weaponUI = Instance.new("ScreenGui")
	weaponUI.Name = "WeaponUI"
	weaponUI.ResetOnSpawn = false
	weaponUI.Parent = PlayerGui
	
	-- Ammo frame (bottom right)
	local ammoFrame = Instance.new("Frame")
	ammoFrame.Name = "AmmoFrame"
	ammoFrame.Size = UDim2.new(0, 200, 0, 80)
	ammoFrame.Position = UDim2.new(1, -220, 1, -100)
	ammoFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	ammoFrame.BackgroundTransparency = 0.3
	ammoFrame.BorderSizePixel = 0
	ammoFrame.Parent = weaponUI
	
	-- Ammo frame corner
	local ammoCorner = Instance.new("UICorner")
	ammoCorner.CornerRadius = UDim.new(0, 8)
	ammoCorner.Parent = ammoFrame
	
	-- Ammo label
	local ammoLabel = Instance.new("TextLabel")
	ammoLabel.Name = "AmmoLabel"
	ammoLabel.Size = UDim2.new(1, 0, 0.6, 0)
	ammoLabel.Position = UDim2.new(0, 0, 0.4, 0)
	ammoLabel.BackgroundTransparency = 1
	ammoLabel.Text = "30 / 30"
	ammoLabel.TextColor3 = Color3.new(1, 1, 1)
	ammoLabel.TextScaled = true
	ammoLabel.Font = Enum.Font.SourceSansBold
	ammoLabel.TextStrokeTransparency = 0
	ammoLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	ammoLabel.Parent = ammoFrame
	
	-- Weapon name label
	local weaponLabel = Instance.new("TextLabel")
	weaponLabel.Name = "WeaponLabel"
	weaponLabel.Size = UDim2.new(1, 0, 0.4, 0)
	weaponLabel.Position = UDim2.new(0, 0, 0, 0)
	weaponLabel.BackgroundTransparency = 1
	weaponLabel.Text = "M4A1 Carbine"
	weaponLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
	weaponLabel.TextScaled = true
	weaponLabel.Font = Enum.Font.SourceSans
	weaponLabel.TextStrokeTransparency = 0
	weaponLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	weaponLabel.Parent = ammoFrame
	
	-- Weapon slots frame (bottom center)
	local slotsFrame = Instance.new("Frame")
	slotsFrame.Name = "SlotsFrame"
	slotsFrame.Size = UDim2.new(0, 300, 0, 60)
	slotsFrame.Position = UDim2.new(0.5, -150, 1, -80)
	slotsFrame.BackgroundTransparency = 1
	slotsFrame.Parent = weaponUI
	
	-- Create weapon slot indicators
	local slotNames = {"Primary", "Secondary", "Melee"}
	local slotKeys = {"1", "2", "3"}
	
	for i, slotName in ipairs(slotNames) do
		local slotFrame = Instance.new("Frame")
		slotFrame.Name = slotName .. "Slot"
		slotFrame.Size = UDim2.new(0, 90, 1, 0)
		slotFrame.Position = UDim2.new(0, (i-1) * 105, 0, 0)
		slotFrame.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
		slotFrame.BackgroundTransparency = 0.5
		slotFrame.BorderSizePixel = 0
		slotFrame.Parent = slotsFrame
		
		local slotCorner = Instance.new("UICorner")
		slotCorner.CornerRadius = UDim.new(0, 6)
		slotCorner.Parent = slotFrame
		
		-- Key indicator
		local keyLabel = Instance.new("TextLabel")
		keyLabel.Size = UDim2.new(0, 20, 0, 20)
		keyLabel.Position = UDim2.new(0, 5, 0, 5)
		keyLabel.BackgroundColor3 = Color3.new(0, 0, 0)
		keyLabel.BackgroundTransparency = 0.3
		keyLabel.Text = slotKeys[i]
		keyLabel.TextColor3 = Color3.new(1, 1, 1)
		keyLabel.TextScaled = true
		keyLabel.Font = Enum.Font.SourceSansBold
		keyLabel.Parent = slotFrame
		
		local keyCorner = Instance.new("UICorner")
		keyCorner.CornerRadius = UDim.new(0, 3)
		keyCorner.Parent = keyLabel
		
		-- Weapon icon placeholder
		local iconLabel = Instance.new("TextLabel")
		iconLabel.Size = UDim2.new(1, -30, 0.6, 0)
		iconLabel.Position = UDim2.new(0, 30, 0, 5)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Text = slotName:sub(1, 3):upper() -- First 3 letters
		iconLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
		iconLabel.TextScaled = true
		iconLabel.Font = Enum.Font.SourceSans
		iconLabel.Parent = slotFrame
		
		-- Selection indicator
		local selectionFrame = Instance.new("Frame")
		selectionFrame.Name = "Selection"
		selectionFrame.Size = UDim2.new(1, 4, 1, 4)
		selectionFrame.Position = UDim2.new(0, -2, 0, -2)
		selectionFrame.BackgroundColor3 = Color3.new(0, 1, 0)
		selectionFrame.BackgroundTransparency = 1
		selectionFrame.BorderSizePixel = 0
		selectionFrame.Parent = slotFrame
		
		local selectionCorner = Instance.new("UICorner")
		selectionCorner.CornerRadius = UDim.new(0, 8)
		selectionCorner.Parent = selectionFrame
	end
	
	-- Reload indicator
	local reloadFrame = Instance.new("Frame")
	reloadFrame.Name = "ReloadFrame"
	reloadFrame.Size = UDim2.new(0, 200, 0, 40)
	reloadFrame.Position = UDim2.new(0.5, -100, 0.5, 0)
	reloadFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	reloadFrame.BackgroundTransparency = 1
	reloadFrame.BorderSizePixel = 0
	reloadFrame.Visible = false
	reloadFrame.Parent = weaponUI
	
	local reloadLabel = Instance.new("TextLabel")
	reloadLabel.Size = UDim2.new(1, 0, 1, 0)
	reloadLabel.BackgroundTransparency = 1
	reloadLabel.Text = "RELOADING..."
	reloadLabel.TextColor3 = Color3.new(1, 1, 0)
	reloadLabel.TextScaled = true
	reloadLabel.Font = Enum.Font.SourceSansBold
	reloadLabel.TextStrokeTransparency = 0
	reloadLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	reloadLabel.Parent = reloadFrame
	
	return weaponUI
end

-- Update slot selection
function AmmoCounter.UpdateSlotSelection(currentSlot: string)
	local weaponUI = PlayerGui:FindFirstChild("WeaponUI")
	if not weaponUI then return end
	
	local slotsFrame = weaponUI:FindFirstChild("SlotsFrame")
	if not slotsFrame then return end
	
	-- Reset all selections
	for _, child in ipairs(slotsFrame:GetChildren()) do
		if child:IsA("Frame") then
			local selection = child:FindFirstChild("Selection")
			if selection then
				selection.BackgroundTransparency = 1
			end
		end
	end
	
	-- Highlight current slot
	local currentSlotFrame = slotsFrame:FindFirstChild(currentSlot .. "Slot")
	if currentSlotFrame then
		local selection = currentSlotFrame:FindFirstChild("Selection")
		if selection then
			selection.BackgroundTransparency = 0.3
			
			-- Pulse animation
			local pulseTween = TweenService:Create(
				selection,
				TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{BackgroundTransparency = 0.7}
			)
			pulseTween:Play()
		end
	end
end

-- Show reload indicator
function AmmoCounter.ShowReloadIndicator(reloadTime: number)
	local weaponUI = PlayerGui:FindFirstChild("WeaponUI")
	if not weaponUI then return end
	
	local reloadFrame = weaponUI:FindFirstChild("ReloadFrame")
	if not reloadFrame then return end
	
	-- Show reload frame
	reloadFrame.Visible = true
	reloadFrame.BackgroundTransparency = 0.3
	
	-- Animate reload text
	local reloadLabel = reloadFrame:FindFirstChild("TextLabel")
	if reloadLabel then
		local pulseTween = TweenService:Create(
			reloadLabel,
			TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{TextTransparency = 0.5}
		)
		pulseTween:Play()
		
		-- Hide after reload time
		task.spawn(function()
			task.wait(reloadTime)
			pulseTween:Cancel()
			reloadFrame.Visible = false
			reloadLabel.TextTransparency = 0
		end)
	end
end

-- Update ammo color based on amount
function AmmoCounter.UpdateAmmoColor(currentAmmo: number, maxAmmo: number)
	local weaponUI = PlayerGui:FindFirstChild("WeaponUI")
	if not weaponUI then return end
	
	local ammoFrame = weaponUI:FindFirstChild("AmmoFrame")
	if not ammoFrame then return end
	
	local ammoLabel = ammoFrame:FindFirstChild("AmmoLabel")
	if not ammoLabel then return end
	
	-- Color code based on ammo percentage
	local ammoPercent = maxAmmo > 0 and (currentAmmo / maxAmmo) or 1
	
	if ammoPercent > 0.5 then
		ammoLabel.TextColor3 = Color3.new(1, 1, 1) -- White (good)
	elseif ammoPercent > 0.25 then
		ammoLabel.TextColor3 = Color3.new(1, 1, 0) -- Yellow (warning)
	else
		ammoLabel.TextColor3 = Color3.new(1, 0, 0) -- Red (critical)
		
		-- Flash red when critical
		local flashTween = TweenService:Create(
			ammoLabel,
			TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 2, true),
			{TextTransparency = 0.5}
		)
		flashTween:Play()
	end
end

-- Initialize UI
local weaponUI = AmmoCounter.CreateUI()

-- Listen for weapon state changes
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeaponEvents = ReplicatedStorage:WaitForChild("WeaponEvents")
local WeaponStateRemote = WeaponEvents:WaitForChild("WeaponState")

WeaponStateRemote.OnClientEvent:Connect(function(data)
	if data.Type == "WeaponSwitched" then
		AmmoCounter.UpdateSlotSelection(data.Slot)
	elseif data.Type == "ReloadStart" then
		AmmoCounter.ShowReloadIndicator(data.ReloadTime)
	elseif data.Type == "AmmoUpdate" then
		-- Update ammo color
		local weapon = require(ReplicatedStorage:WaitForChild("WeaponSystem"):WaitForChild("Modules"):WaitForChild("WeaponDefinitions")).GetWeapon(data.WeaponId)
		if weapon then
			AmmoCounter.UpdateAmmoColor(data.CurrentAmmo, weapon.MagazineSize)
		end
	end
end)

print("AmmoCounter UI initialized")

return AmmoCounter
