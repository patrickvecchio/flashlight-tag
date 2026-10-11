--[[
	The seeker's flashlight: the tool, the beam everyone sees, and the server-side damage check.

	The seeker's client sends where it is aiming; the server points the beam that way and,
	several times a second, drains health from every hider who is inside the cone with
	nothing blocking the line from the seeker's head.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local Cone = require(ReplicatedStorage.Shared.Cone)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoundLogic = require(ReplicatedStorage.Shared.RoundLogic)

local TOOL_NAME = "Flashlight"
local BEAM_COLOR = Color3.fromRGB(255, 240, 210)
local BEAM_SPOTTING_COLOR = Color3.fromRGB(255, 150, 120)
local BEAM_ATTACHMENT_NAME = "FlashlightBeam"
-- Body parts checked for line of sight; a hider is lit if any of them is visible.
local TARGET_PARTS = { "Head", "UpperTorso", "Torso", "HumanoidRootPart" }

local Flashlight = {}

-- Latest aim direction per seeker, as sent by their client.
local aims: { [Player]: Vector3 } = {}

local function makeTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = "Shine it on hiders to catch them"

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.4, 1.6)
	handle.Color = Color3.fromRGB(30, 30, 30)
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	return tool
end

local function getBeam(character: Model): SpotLight?
	local head = character:FindFirstChild("Head")
	local attachment = head and head:FindFirstChild(BEAM_ATTACHMENT_NAME)
	return attachment and attachment:FindFirstChildOfClass("SpotLight")
end

local function isEquipped(character: Model): boolean
	local tool = character:FindFirstChild(TOOL_NAME)
	return tool ~= nil and tool:IsA("Tool")
end

--[=[
	Gives the seeker the flashlight tool, equips it, and adds the beam to their head.
]=]
function Flashlight.give(seeker: Player)
	local character = seeker.Character
	local head = character and character:FindFirstChild("Head")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (character and head and humanoid) then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = BEAM_ATTACHMENT_NAME
	attachment.Parent = head

	local beam = Instance.new("SpotLight")
	beam.Face = Enum.NormalId.Front
	beam.Angle = Config.Flashlight.HalfAngleDegrees * 2
	beam.Range = Config.Flashlight.RangeStuds
	beam.Brightness = 6
	beam.Color = BEAM_COLOR
	beam.Shadows = true
	beam.Enabled = false
	beam.Parent = attachment

	local tool = makeTool()
	tool.Equipped:Connect(function()
		beam.Enabled = true
	end)
	tool.Unequipped:Connect(function()
		beam.Enabled = false
	end)
	tool.Parent = seeker:FindFirstChildOfClass("Backpack")
	humanoid:EquipTool(tool)
end

--[=[
	Removes the flashlight and beam from a player, wherever the tool currently is.
]=]
function Flashlight.take(player: Player)
	aims[player] = nil
	player:SetAttribute(Attributes.Spotting, nil)
	local backpack = player:FindFirstChildOfClass("Backpack")
	for _, container in { player.Character, backpack } do
		local tool = container and container:FindFirstChild(TOOL_NAME)
		if tool then
			tool:Destroy()
		end
	end
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local attachment = head and head:FindFirstChild(BEAM_ATTACHMENT_NAME)
	if attachment then
		attachment:Destroy()
	end
end

local function isLit(seekerCharacter: Model, aim: Vector3, hiderCharacter: Model): boolean
	local head = seekerCharacter:FindFirstChild("Head") :: BasePart?
	if not head then
		return false
	end
	local origin = head.Position

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { seekerCharacter }

	for _, partName in TARGET_PARTS do
		local target = hiderCharacter:FindFirstChild(partName)
		if target and target:IsA("BasePart") then
			local position = target.Position
			if
				Cone.contains(origin, aim, position, Config.Flashlight.RangeStuds, Config.Flashlight.HalfAngleDegrees)
			then
				local result = workspace:Raycast(origin, position - origin, params)
				if result == nil or result.Instance:IsDescendantOf(hiderCharacter) then
					return true
				end
			end
		end
	end
	return false
end

--[=[
	Starts draining health from hiders in the beam. `getHiders` returns the hiders still in
	the round; `onCaught` is called once for a hider whose health reaches zero.
	Returns a function that stops the damage loop.
]=]
function Flashlight.startDamage(seeker: Player, getHiders: () -> { Player }, onCaught: (Player) -> ()): () -> ()
	local interval = 1 / Config.Flashlight.ChecksPerSecond
	local elapsed = 0

	local connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < interval then
			return
		end
		local step = elapsed
		elapsed = 0

		local seekerCharacter = seeker.Character
		local aim = aims[seeker]
		local beamOn = seekerCharacter ~= nil and aim ~= nil and isEquipped(seekerCharacter)
		local spotting = 0

		for _, hider in getHiders() do
			local hiderCharacter = hider.Character
			local lit = beamOn
				and hiderCharacter ~= nil
				and isLit(seekerCharacter :: Model, aim :: Vector3, hiderCharacter)
			hider:SetAttribute(Attributes.Lit, lit)

			if lit then
				spotting += 1
				local health = hider:GetAttribute(Attributes.LightHealth) or Config.Health.Max
				health = RoundLogic.drain(health, step, Config.Health.DrainPerSecond)
				hider:SetAttribute(Attributes.LightHealth, health)
				if health <= 0 then
					hider:SetAttribute(Attributes.Lit, false)
					onCaught(hider)
				end
			end
		end

		-- The seeker's HUD shows when the beam is on someone, and the beam turns red for everyone.
		seeker:SetAttribute(Attributes.Spotting, spotting)
		local beam = seekerCharacter and getBeam(seekerCharacter)
		if beam then
			beam.Color = if spotting > 0 then BEAM_SPOTTING_COLOR else BEAM_COLOR
		end
	end)

	return function()
		connection:Disconnect()
	end
end

local function onAim(player: Player, direction: unknown)
	if player:GetAttribute(Attributes.Role) ~= Attributes.Roles.Seeker then
		return
	end
	if typeof(direction) ~= "Vector3" then
		return
	end
	local vector = direction :: Vector3
	-- Reject NaN and zero-length vectors before normalising.
	if vector.Magnitude ~= vector.Magnitude or vector.Magnitude < 1e-3 then
		return
	end
	local aim = vector.Unit
	aims[player] = aim

	-- Point the beam the same way so everyone sees where the seeker is looking.
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	local beam = character and getBeam(character)
	if head and beam then
		local attachment = beam.Parent :: Attachment
		local world = CFrame.lookAt(head.Position, head.Position + aim)
		attachment.CFrame = head.CFrame:ToObjectSpace(world)
	end
end

function Flashlight.init()
	local aimRemote = Remotes.get(Remotes.UnreliableEvents.FlashlightAim) :: UnreliableRemoteEvent
	aimRemote.OnServerEvent:Connect(onAim)
	Players.PlayerRemoving:Connect(function(player)
		aims[player] = nil
	end)
end

return Flashlight
