--[[
	Gives the seeker and the hiders two different views of the same arena.

	Lighting changes made on a client stay on that client, so the seeker's client swaps the
	server's dusk for near-total darkness while everyone else keeps the dusk. A short-range
	light on the seeker shows the small circle they can always see.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)

local LightingController = {}

local player = Players.LocalPlayer
local AURA_NAME = "SeekerAura"

local original = {
	EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
	EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
}

local function apply(settings: typeof(Config.Dusk))
	Lighting.ClockTime = settings.ClockTime
	Lighting.Brightness = settings.Brightness
	Lighting.Ambient = settings.Ambient
	Lighting.OutdoorAmbient = settings.OutdoorAmbient
	Lighting.FogColor = settings.FogColor
	Lighting.FogEnd = settings.FogEnd
end

local function setAura(enabled: boolean)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local aura = root:FindFirstChild(AURA_NAME) :: PointLight?
	if not aura then
		local light = Instance.new("PointLight")
		light.Name = AURA_NAME
		light.Range = Config.SeekerVision.RadiusStuds
		light.Brightness = Config.SeekerVision.Brightness
		light.Shadows = false
		light.Parent = root
		aura = light
	end
	(aura :: PointLight).Enabled = enabled
end

local function isInDarkness(): boolean
	local state = player:GetAttribute(Attributes.RoundState)
	return player:GetAttribute(Attributes.Role) == Attributes.Roles.Seeker
		and (state == Attributes.States.Hiding or state == Attributes.States.Seeking)
end

local darkNow = false

local function update()
	local dark = isInDarkness()
	setAura(dark)
	if dark == darkNow then
		return
	end
	darkNow = dark
	if dark then
		apply(Config.Darkness)
		Lighting.EnvironmentDiffuseScale = 0
		Lighting.EnvironmentSpecularScale = 0
	else
		apply(Config.Dusk)
		Lighting.EnvironmentDiffuseScale = original.EnvironmentDiffuseScale
		Lighting.EnvironmentSpecularScale = original.EnvironmentSpecularScale
	end
end

function LightingController.start()
	player:GetAttributeChangedSignal(Attributes.Role):Connect(update)
	player:GetAttributeChangedSignal(Attributes.RoundState):Connect(update)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart")
		update()
	end)
	update()
end

return LightingController
