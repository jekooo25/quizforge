# BlowDryer — removed 2026-10-29

Deleted from the place at the user's request ("remove the blowers totally"):

- `ServerScriptService.BlowDryerGiver` (Script)
- `ServerStorage.BlowDryer` (Tool)

Nothing else in the place referenced either one (verified by scanning every
`LuaSourceContainer.Source` for "blowdryer"/"blower"). The machine-shop
"Dryer" machines are a separate system and were not touched.

This file is a plain-text backup so the tool can be rebuilt if it is ever
wanted back.

---

## ServerStorage.BlowDryer (Tool)

Properties: `CanBeDropped = false`, `RequiresHandle = true`,
`ToolTip = ""`, `TextureId = http://www.roblox.com/asset/?id=11716958`

Tree:

```
Tool  BlowDryer
  Script       BlowDryer
  LocalScript  MouseIcon
  LocalScript  LocalScript
  Part         Handle
    Size 2, 0.4, 2   Color 0.388235, 0.372549, 0.384314   Material Plastic
    Transparency 0   Anchored false   CanCollide false
    Sound        DryerSound
      SoundId http://www.roblox.com/asset/?id=11717967  Volume 0.25  Looped true
    SpecialMesh  Mesh
      MeshType FileMesh
      MeshId   http://www.roblox.com/asset/?id=11712365
      TextureId http://www.roblox.com/asset/?id=11712384
      Scale 1, 1.8, 1
```

## Handle.BlowDryer (Script)

```lua
-- Rescripted by Luckymaxer (bubbles/air effect removed; sound loops; no reload)

Tool = script.Parent
Handle = Tool:WaitForChild("Handle")

Players = game:GetService("Players")

Sounds = {
	DryerSound = Handle:WaitForChild("DryerSound")
}
Sounds.DryerSound.Looped = true

MouseDown = false
ToolEquipped = false

ServerControl = (Tool:FindFirstChild("ServerControl") or Instance.new("RemoteFunction"))
ServerControl.Name = "ServerControl"
ServerControl.Parent = Tool

ClientControl = (Tool:FindFirstChild("ClientControl") or Instance.new("RemoteFunction"))
ClientControl.Name = "ClientControl"
ClientControl.Parent = Tool

Tool.Enabled = true

function CheckIfAlive()
	return (((Player and Player.Parent and Character and Character.Parent and Humanoid and Humanoid.Parent and Humanoid.Health > 0) and true) or false)
end

function Equipped()
	Character = Tool.Parent
	Player = Players:GetPlayerFromCharacter(Character)
	Humanoid = Character:FindFirstChild("Humanoid")
	if not CheckIfAlive() then
		return
	end
	ToolEquipped = true
end

function Unequipped()
	MouseDown = false
	ToolEquipped = false
	Sounds.DryerSound:Stop()
end

function InvokeClient(Mode, Value)
	local ClientReturn = nil
	pcall(function()
		ClientReturn = ClientControl:InvokeClient(Player, Mode, Value)
	end)
	return ClientReturn
end

ServerControl.OnServerInvoke = (function(player, Mode, Value)
	if player ~= Player or not ToolEquipped or not CheckIfAlive() or not Mode or not Value then
		return
	end
	if Mode == "Button1Click" then
		local Down = Value.Down
		if Down and not MouseDown then
			MouseDown = true
			Sounds.DryerSound:Play()
		elseif not Down and MouseDown then
			MouseDown = false
			Sounds.DryerSound:Stop()
		end
	end
end)

Tool.Equipped:connect(Equipped)
Tool.Unequipped:connect(Unequipped)
```

## Handle.MouseIcon (LocalScript)

```lua
--Made by Luckymaxer

Mouse_Icon = "rbxasset://textures/GunCursor.png"
Reloading_Icon = "rbxasset://textures/GunWaitCursor.png"

Tool = script.Parent

Mouse = nil

function UpdateIcon()
	if Mouse then
		Mouse.Icon = Tool.Enabled and Mouse_Icon or Reloading_Icon
	end
end

function OnEquipped(ToolMouse)
	Mouse = ToolMouse
	UpdateIcon()
end

function OnChanged(Property)
	if Property == "Enabled" then
		UpdateIcon()
	end
end

Tool.Equipped:connect(OnEquipped)
Tool.Changed:connect(OnChanged)
```

## Handle.LocalScript (LocalScript)

```lua
--Made by Luckymaxer

Tool = script.Parent
Handle = Tool:WaitForChild("Handle")

Players = game:GetService("Players")
RunService = game:GetService("RunService")
UserInputService = game:GetService("UserInputService")

Animations = {}
LocalObjects = {}

ServerControl = Tool:WaitForChild("ServerControl")
ClientControl = Tool:WaitForChild("ClientControl")

InputCheck = Instance.new("ScreenGui")
InputCheck.Name = "InputCheck"
InputButton = Instance.new("ImageButton")
InputButton.Name = "InputButton"
InputButton.Image = ""
InputButton.BackgroundTransparency = 1
InputButton.ImageTransparency = 1
InputButton.Size = UDim2.new(1, 0, 1, 0)
InputButton.Parent = InputCheck

Rate = (1 / 60)

ToolEquipped = false

function SetAnimation(mode, value)
	if mode == "PlayAnimation" and value and ToolEquipped and Humanoid then
		for i, v in pairs(Animations) do
			if v.Animation == value.Animation then
				v.AnimationTrack:Stop()
				table.remove(Animations, i)
			end
		end
		local AnimationTrack = Humanoid:LoadAnimation(value.Animation)
		table.insert(Animations, {Animation = value.Animation, AnimationTrack = AnimationTrack})
		AnimationTrack:Play(value.FadeTime, value.Weight, value.Speed)
	elseif mode == "StopAnimation" and value then
		for i, v in pairs(Animations) do
			if v.Animation == value.Animation then
				v.AnimationTrack:Stop(value.FadeTime)
				table.remove(Animations, i)
			end
		end
	end
end

function CheckIfAlive()
	return (((Character and Character.Parent and Humanoid and Humanoid.Parent and Humanoid.Health > 0 and Player and Player.Parent) and true) or false)
end

function Equipped(Mouse)
	Character = Tool.Parent
	Player = Players:GetPlayerFromCharacter(Character)
	Humanoid = Character:FindFirstChild("Humanoid")
	ToolEquipped = true
	if not CheckIfAlive() then
		return
	end
	spawn(function()
		PlayerMouse = Player:GetMouse()
		Mouse.Button1Down:connect(function()
			InvokeServer("Button1Click", {Down = true})
		end)
		Mouse.Button1Up:connect(function()
			InvokeServer("Button1Click", {Down = false})
		end)
		local PlayerGui = Player:FindFirstChild("PlayerGui")
		if PlayerGui then
			if UserInputService.TouchEnabled then
				InputCheckClone = InputCheck:Clone()
				InputCheckClone.InputButton.InputBegan:connect(function()
					InvokeServer("Button1Click", {Down = true})
				end)
				InputCheckClone.InputButton.InputEnded:connect(function()
					InvokeServer("Button1Click", {Down = false})
				end)
				InputCheckClone.Parent = PlayerGui
			end
		end
	end)
end

function Unequipped()
	LocalObjects = {}
	if InputCheckClone and InputCheckClone.Parent then
		InputCheckClone:Destroy()
	end
	for i, v in pairs(Animations) do
		if v and v.AnimationTrack then
			v.AnimationTrack:Stop()
		end
	end
	for i, v in pairs({ObjectLocalTransparencyModifier}) do
		if v then
			v:disconnect()
		end
	end
	Animations = {}
	ToolEquipped = false
end

function InvokeServer(mode, value)
	pcall(function()
		local ServerReturn = ServerControl:InvokeServer(mode, value)
		return ServerReturn
	end)
end

function OnClientInvoke(mode, value)
	if mode == "PlayAnimation" and value and ToolEquipped and Humanoid then
		SetAnimation("PlayAnimation", value)
	elseif mode == "StopAnimation" and value then
		SetAnimation("StopAnimation", value)
	elseif mode == "PlaySound" and value then
		value:Play()
	elseif mode == "StopSound" and value then
		value:Stop()
	elseif mode == "MousePosition" then
		return {Position = PlayerMouse.Hit.p, Target = PlayerMouse.Target}
	elseif mode == "SetLocalTransparencyModifier" and value and ToolEquipped then
		pcall(function()
			local ObjectFound = false
			for i, v in pairs(LocalObjects) do
				if v == value then
					ObjectFound = true
				end
			end
			if not ObjectFound then
				table.insert(LocalObjects, value)
				if ObjectLocalTransparencyModifier then
					ObjectLocalTransparencyModifier:disconnect()
				end
				ObjectLocalTransparencyModifier = RunService.RenderStepped:connect(function()
					for i, v in pairs(LocalObjects) do
						if v.Object and v.Object.Parent then
							local CurrentTransparency = v.Object.LocalTransparencyModifier
							if ((not v.AutoUpdate and (CurrentTransparency == 1 or  CurrentTransparency == 0)) or v.AutoUpdate) then
								v.Object.LocalTransparencyModifier = v.Transparency
							end
						else
							table.remove(LocalObjects, i)
						end
					end
				end)
			end
		end)
	end
end

ClientControl.OnClientInvoke = OnClientInvoke
Tool.Equipped:connect(Equipped)
Tool.Unequipped:connect(Unequipped)
```

## ServerScriptService.BlowDryerGiver (Script)

```lua
--[[
	BlowDryerGiver
	Gives every player the BlowDryer tool automatically and permanently.
	- Given on join and re-given on every respawn (death never loses it).
	- CanBeDropped = false, so the player cannot drop/unequip it away.
	- Watchdog re-adds it if it ever goes missing.
	Works alongside BaretaGiver (both tools are given).
--]]

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local TEMPLATE_NAME = "BlowDryer"
local template = ServerStorage:WaitForChild(TEMPLATE_NAME)
template.CanBeDropped = false

local function giveTool(player)
	if not player.Parent then return end
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character

	local hasIt = (backpack and backpack:FindFirstChild(TEMPLATE_NAME))
		or (character and character:FindFirstChild(TEMPLATE_NAME))
	if hasIt then
		hasIt.CanBeDropped = false
		return
	end

	local tool = template:Clone()
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Parent = backpack or player
end

local function onCharacter(player)
	task.spawn(function()
		player:WaitForChild("Backpack", 10)
		task.wait(0.2)
		giveTool(player)
		local checks = 0
		while player.Parent and checks < 40 do
			task.wait(1)
			checks += 1
			giveTool(player)
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		onCharacter(player)
	end)
	if player.Character then onCharacter(player) end
end)

for _, player in ipairs(Players:GetPlayers()) do
	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		onCharacter(player)
	end)
	if player.Character then onCharacter(player) end
end
```
