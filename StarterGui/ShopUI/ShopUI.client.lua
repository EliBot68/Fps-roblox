-- ShopUI.client.lua
-- Shop interface for cosmetics and weapons

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local RemoteRoot = ReplicatedStorage:WaitForChild("RemoteEvents")
local ShopEvents = RemoteRoot:WaitForChild("ShopEvents")
local PurchaseItemRemote = ShopEvents:WaitForChild("PurchaseItem")
local EquipCosmeticRemote = ShopEvents:WaitForChild("EquipCosmetic")

local gui = Instance.new("ScreenGui")
gui.Name = "ShopUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Name = "ShopFrame"
frame.Size = UDim2.new(0,600,0,400)
frame.Position = UDim2.new(0.5,-300,0.5,-200)
frame.BackgroundColor3 = Color3.fromRGB(30,30,30)
frame.BorderSizePixel = 0
frame.Visible = false
frame.Parent = gui

local title = Instance.new("TextLabel")
title.Text = "Shop"
title.Size = UDim2.new(1,0,0,40)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255,255,255)
title.Font = Enum.Font.GothamBold
title.TextSize = 24
title.Parent = frame

local closeButton = Instance.new("TextButton")
closeButton.Text = "X"
closeButton.Size = UDim2.new(0,30,0,30)
closeButton.Position = UDim2.new(1,-35,0,5)
closeButton.BackgroundColor3 = Color3.fromRGB(200,50,50)
closeButton.TextColor3 = Color3.fromRGB(255,255,255)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 18
closeButton.Parent = frame

local tabFrame = Instance.new("Frame")
tabFrame.Size = UDim2.new(1,-20,0,30)
tabFrame.Position = UDim2.new(0,10,0,45)
tabFrame.BackgroundTransparency = 1
tabFrame.Parent = frame

local weaponsTab = Instance.new("TextButton")
weaponsTab.Text = "Weapons"
weaponsTab.Size = UDim2.new(0.5,0,1,0)
weaponsTab.BackgroundColor3 = Color3.fromRGB(50,50,50)
weaponsTab.TextColor3 = Color3.fromRGB(255,255,255)
weaponsTab.Font = Enum.Font.Gotham
weaponsTab.TextSize = 16
weaponsTab.Parent = tabFrame

local cosmeticsTab = Instance.new("TextButton")
cosmeticsTab.Text = "Cosmetics"
cosmeticsTab.Size = UDim2.new(0.5,0,1,0)
cosmeticsTab.Position = UDim2.new(0.5,0,0,0)
cosmeticsTab.BackgroundColor3 = Color3.fromRGB(40,40,40)
cosmeticsTab.TextColor3 = Color3.fromRGB(200,200,200)
cosmeticsTab.Font = Enum.Font.Gotham
cosmeticsTab.TextSize = 16
cosmeticsTab.Parent = tabFrame

local contentFrame = Instance.new("ScrollingFrame")
contentFrame.Size = UDim2.new(1,-20,1,-85)
contentFrame.Position = UDim2.new(0,10,0,75)
contentFrame.BackgroundTransparency = 1
contentFrame.BorderSizePixel = 0
contentFrame.Parent = frame

local currentTab = "Weapons"

local SHOP_ITEMS = {
	Weapons = {
		{ name = "SMG", cost = 500, desc = "High fire rate, low damage" },
		{ name = "Shotgun", cost = 800, desc = "Close range powerhouse" },
		{ name = "Sniper", cost = 1200, desc = "Long range precision" },
	},
	Cosmetics = {
		{ name = "RedTrail", cost = 300, desc = "Red particle trail" },
		{ name = "BlueTrail", cost = 300, desc = "Blue particle trail" },
		{ name = "GoldSkin", cost = 1000, desc = "Golden weapon skin" },
	}
}

local function createItemButton(item, index)
	local itemFrame = Instance.new("Frame")
	itemFrame.Size = UDim2.new(1,-10,0,60)
	itemFrame.Position = UDim2.new(0,5,0,(index-1)*65)
	itemFrame.BackgroundColor3 = Color3.fromRGB(40,40,40)
	itemFrame.BorderSizePixel = 0
	itemFrame.Parent = contentFrame
	
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Text = item.name
	nameLabel.Size = UDim2.new(0.4,0,0.5,0)
	nameLabel.Position = UDim2.new(0,10,0,0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(255,255,255)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 16
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = itemFrame
	
	local descLabel = Instance.new("TextLabel")
	descLabel.Text = item.desc
	descLabel.Size = UDim2.new(0.4,0,0.5,0)
	descLabel.Position = UDim2.new(0,10,0.5,0)
	descLabel.BackgroundTransparency = 1
	descLabel.TextColor3 = Color3.fromRGB(200,200,200)
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextSize = 12
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.Parent = itemFrame
	
	local costLabel = Instance.new("TextLabel")
	costLabel.Text = "$" .. item.cost
	costLabel.Size = UDim2.new(0.2,0,1,0)
	costLabel.Position = UDim2.new(0.4,0,0,0)
	costLabel.BackgroundTransparency = 1
	costLabel.TextColor3 = Color3.fromRGB(255,200,0)
	costLabel.Font = Enum.Font.GothamBold
	costLabel.TextSize = 18
	costLabel.Parent = itemFrame
	
	local buyButton = Instance.new("TextButton")
	buyButton.Text = "Buy"
	buyButton.Size = UDim2.new(0.2,0,0.8,0)
	buyButton.Position = UDim2.new(0.75,0,0.1,0)
	buyButton.BackgroundColor3 = Color3.fromRGB(50,150,50)
	buyButton.TextColor3 = Color3.fromRGB(255,255,255)
	buyButton.Font = Enum.Font.GothamBold
	buyButton.TextSize = 14
	buyButton.Parent = itemFrame
	
	buyButton.MouseButton1Click:Connect(function()
		PurchaseItemRemote:FireServer(currentTab == "Weapons" and "Weapon" or "Cosmetic", item.name)
	end)
end

local function refreshTab()
	for _,child in ipairs(contentFrame:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	
	local items = SHOP_ITEMS[currentTab]
	for i,item in ipairs(items) do
		createItemButton(item, i)
	end
	contentFrame.CanvasSize = UDim2.new(0,0,0,#items*65)
end

weaponsTab.MouseButton1Click:Connect(function()
	currentTab = "Weapons"
	weaponsTab.BackgroundColor3 = Color3.fromRGB(50,50,50)
	weaponsTab.TextColor3 = Color3.fromRGB(255,255,255)
	cosmeticsTab.BackgroundColor3 = Color3.fromRGB(40,40,40)
	cosmeticsTab.TextColor3 = Color3.fromRGB(200,200,200)
	refreshTab()
end)

cosmeticsTab.MouseButton1Click:Connect(function()
	currentTab = "Cosmetics"
	cosmeticsTab.BackgroundColor3 = Color3.fromRGB(50,50,50)
	cosmeticsTab.TextColor3 = Color3.fromRGB(255,255,255)
	weaponsTab.BackgroundColor3 = Color3.fromRGB(40,40,40)
	weaponsTab.TextColor3 = Color3.fromRGB(200,200,200)
	refreshTab()
end)

closeButton.MouseButton1Click:Connect(function()
	frame.Visible = false
end)

-- Toggle shop with key
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.B then
		frame.Visible = not frame.Visible
		if frame.Visible then
			refreshTab()
		end
	end
end)

refreshTab()
