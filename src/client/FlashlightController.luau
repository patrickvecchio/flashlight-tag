--[[
	While the seeker holds the flashlight, aims it where the camera looks and tells the server.
	The beam is also turned locally every frame so it feels smooth to the seeker; the server's
	copy (what hiders see) updates at the send rate.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local FlashlightController = {}

local player = Players.LocalPlayer

function FlashlightController.start()
	local aimRemote = Remotes.get(Remotes.UnreliableEvents.FlashlightAim) :: UnreliableRemoteEvent
	local interval = 1 / Config.Flashlight.ChecksPerSecond
	local sinceSend = 0

	RunService.RenderStepped:Connect(function(dt)
		if player:GetAttribute(Attributes.Role) ~= Attributes.Roles.Seeker then
			return
		end
		local character = player.Character
		local camera = workspace.CurrentCamera
		if not (character and camera and character:FindFirstChild("Flashlight")) then
			return
		end

		local aim = camera.CFrame.LookVector

		local head = character:FindFirstChild("Head") :: BasePart?
		local attachment = head and head:FindFirstChild("FlashlightBeam") :: Attachment?
		if head and attachment then
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
