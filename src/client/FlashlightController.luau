--[[
	Seeker controls, the same on every device:

	- Aim: the flashlight points at whatever is under the middle of the screen, so it follows
	  the camera whether that is moved with the mouse, a thumbstick or a finger drag. While
	  seeking, the character turns to face where the camera looks.
	- Toggle: F on a keyboard, X on a gamepad, or the on-screen button on a phone.

	The aim goes to the server ~10 times a second. The beam is also turned locally every frame
	so it feels smooth to the seeker; the server's copy (what hiders see) follows at the send rate.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local FlashlightController = {}

local player = Players.LocalPlayer
local TOGGLE_ACTION = "ToggleFlashlight"
local AIM_DISTANCE = 500

local function getTool(): Tool?
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	for _, container in { character, backpack } do
		local tool = container and container:FindFirstChild("Flashlight")
		if tool and tool:IsA("Tool") then
			return tool
		end
	end
	return nil
end

local function toggle(_: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local tool = getTool()
	if not (humanoid and tool) then
		return Enum.ContextActionResult.Pass
	end
	if tool.Parent == character then
		humanoid:UnequipTools()
	else
		humanoid:EquipTool(tool)
	end
	return Enum.ContextActionResult.Sink
end

-- The point under the middle of the screen, ignoring the seeker's own character.
local function aimPoint(camera: Camera, character: Model): Vector3
	local viewport = camera.ViewportSize
	local ray = camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local result = workspace:Raycast(ray.Origin, ray.Direction * AIM_DISTANCE, params)
	return if result then result.Position else ray.Origin + ray.Direction * AIM_DISTANCE
end

local function isSeeking(): boolean
	return player:GetAttribute(Attributes.Role) == Attributes.Roles.Seeker
		and player:GetAttribute(Attributes.RoundState) == Attributes.States.Seeking
end

function FlashlightController.start()
	local aimRemote = Remotes.get(Remotes.UnreliableEvents.FlashlightAim) :: UnreliableRemoteEvent
	local interval = 1 / Config.Flashlight.ChecksPerSecond
	local sinceSend = 0
	local bound = false
	local facingCamera = false

	local function setFacingCamera(on: boolean)
		if on == facingCamera then
			return
		end
		facingCamera = on
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.AutoRotate = not on
		end
	end

	local function updateBinding()
		local want = isSeeking()
		if want and not bound then
			ContextActionService:BindAction(TOGGLE_ACTION, toggle, true, Enum.KeyCode.F, Enum.KeyCode.ButtonX)
			ContextActionService:SetTitle(TOGGLE_ACTION, "Light")
			ContextActionService:SetPosition(TOGGLE_ACTION, UDim2.new(1, -150, 1, -150))
		elseif not want and bound then
			ContextActionService:UnbindAction(TOGGLE_ACTION)
		end
		bound = want
		setFacingCamera(want)
	end

	player:GetAttributeChangedSignal(Attributes.Role):Connect(updateBinding)
	player:GetAttributeChangedSignal(Attributes.RoundState):Connect(updateBinding)
	player.CharacterAdded:Connect(function()
		facingCamera = false
		updateBinding()
	end)
	updateBinding()

	RunService.RenderStepped:Connect(function(dt)
		if not isSeeking() then
			return
		end
		local character = player.Character
		local camera = workspace.CurrentCamera
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local head = character and character:FindFirstChild("Head") :: BasePart?
		if not (character and camera and root and head) then
			return
		end

		-- Face where the camera looks (yaw only).
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 1e-3 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
		end

		if not character:FindFirstChild("Flashlight") then
			return
		end

		local target = aimPoint(camera, character)
		local offset = target - head.Position
		if offset.Magnitude < 1e-3 then
			return
		end
		local aim = offset.Unit

		local attachment = head:FindFirstChild("FlashlightBeam") :: Attachment?
		if attachment then
			local world = CFrame.lookAt(head.Position, head.Position + aim)
			attachment.CFrame = head.CFrame:ToObjectSpace(world)
		end

		sinceSend += dt
		if sinceSend >= interval then
			sinceSend = 0
			aimRemote:FireServer(aim)
		end
	end)
end

return FlashlightController
