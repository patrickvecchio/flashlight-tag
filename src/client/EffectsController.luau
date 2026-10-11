--[[
	Sounds and screen effects:

	- A tick for each of the last 5 seconds of hiding, a ping when the seeker is released,
	  and a ping at the end of each round (higher if your side won).
	- A click when the flashlight is switched on or off.
	- While a hider is in the beam: a heartbeat, a small camera shake, and the colour draining
	  from the screen as their health drops.
	- A groan when you are caught, and a whoosh whenever you are sent somewhere.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local States = Attributes.States
local Roles = Attributes.Roles

local EffectsController = {}

local player = Players.LocalPlayer
local HEARTBEAT_INTERVAL = 0.45
local SHAKE_STUDS = 0.15

local sounds: { [string]: Sound } = {}

local function play(name: string, speed: number?, volume: number?)
	local id = Config.Sounds[name]
	if not id or id == "" then
		return
	end
	local sound = sounds[name]
	if not sound then
		local s = Instance.new("Sound")
		s.Name = name
		s.SoundId = id
		s.Parent = SoundService
		sounds[name] = s
		sound = s
	end
	local s = sound :: Sound
	s.PlaybackSpeed = speed or 1
	s.Volume = volume or 0.6
	SoundService:PlayLocalSound(s)
end

local function watchFlashlight(character: Model)
	character.ChildAdded:Connect(function(child)
		if child.Name == "Flashlight" and child:IsA("Tool") then
			play("Toggle", 1.3)
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child.Name == "Flashlight" and child:IsA("Tool") then
			play("Toggle", 1)
		end
	end)
end

function EffectsController.start()
	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "LitTint"
	tint.Parent = Lighting

	local lastState = player:GetAttribute(Attributes.RoundState)
	local lastSeconds = player:GetAttribute(Attributes.SecondsLeft)

	local function onStateChanged()
		local state = player:GetAttribute(Attributes.RoundState)
		local seconds = player:GetAttribute(Attributes.SecondsLeft)

		if state == States.Hiding and seconds ~= lastSeconds and typeof(seconds) == "number" then
			local release = seconds - (Config.Round.DurationSeconds - Config.Round.HidingSeconds)
			if release <= 5 and release > 0 then
				play("Tick", 1, 0.5)
			end
		end
		if state ~= lastState then
			if state == States.Hiding then
				play("Whoosh")
			elseif state == States.Seeking then
				play("Release", 0.8, 0.8)
			elseif state == States.Results then
				local winner = player:GetAttribute(Attributes.Winner)
				local role = player:GetAttribute(Attributes.Role)
				local won = (winner == "Seeker" and role == Roles.Seeker)
					or (winner == "Hiders" and role == Roles.Hider)
				play("RoundEnd", if won then 1.4 else 0.7, 0.8)
			end
		end
		lastState = state
		lastSeconds = seconds
	end
	player.AttributeChanged:Connect(function(name)
		if name == Attributes.RoundState or name == Attributes.SecondsLeft then
			onStateChanged()
		end
	end)

	local caughtRemote = Remotes.get(Remotes.Events.Caught) :: RemoteEvent
	caughtRemote.OnClientEvent:Connect(function()
		play("Caught", 1, 0.8)
		play("Whoosh")
	end)

	if player.Character then
		watchFlashlight(player.Character)
	end
	player.CharacterAdded:Connect(watchFlashlight)

	-- Heartbeat, shake and fading colour while lit.
	local sinceBeat = 0
	RunService.RenderStepped:Connect(function(dt)
		local lit = player:GetAttribute(Attributes.Lit) == true
		local health = player:GetAttribute(Attributes.LightHealth)
		local fraction = if typeof(health) == "number" then math.clamp(health / Config.Health.Max, 0, 1) else 1

		tint.Saturation = -(1 - fraction) * 0.8
		tint.TintColor = if lit then Color3.fromRGB(255, 215, 215) else Color3.new(1, 1, 1)

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if lit then
			sinceBeat += dt
			-- Beats get faster as health drops.
			if sinceBeat >= HEARTBEAT_INTERVAL * (0.5 + fraction * 0.5) then
				sinceBeat = 0
				play("Heartbeat", 0.55, 0.9)
			end
			if humanoid then
				humanoid.CameraOffset =
					Vector3.new((math.random() - 0.5) * SHAKE_STUDS, (math.random() - 0.5) * SHAKE_STUDS, 0)
			end
		else
			sinceBeat = HEARTBEAT_INTERVAL
			if humanoid and humanoid.CameraOffset ~= Vector3.zero then
				humanoid.CameraOffset = Vector3.zero
			end
		end
	end)
end

return EffectsController
