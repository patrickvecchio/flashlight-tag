--[[
	A plain HUD for playtesting: round timer and status, your role, a hider health bar,
	a red edge while you are in the beam, and a black screen for the seeker while hiders hide.
	Phase 4 replaces this with a designed one.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoundLogic = require(ReplicatedStorage.Shared.RoundLogic)

local States = Attributes.States
local Roles = Attributes.Roles

local HudController = {}

local player = Players.LocalPlayer

local function label(props: { [string]: any }, parent: Instance): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.5
	l.TextScaled = true
	for key, value in props do
		(l :: any)[key] = value
	end
	l.Parent = parent
	return l
end

local function frame(props: { [string]: any }, parent: Instance): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for key, value in props do
		(f :: any)[key] = value
	end
	f.Parent = parent
	return f
end

function HudController.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "FlashlightTagHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true

	local blindness = frame({
		Name = "Blindness",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		Visible = false,
		ZIndex = 1,
	}, gui)
	label({
		Size = UDim2.new(0.6, 0, 0, 40),
		Position = UDim2.fromScale(0.2, 0.55),
		Text = "Hiders are hiding. Get ready...",
		ZIndex = 2,
	}, blindness)

	local litEdge = frame({
		Name = "LitEdge",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 3,
	}, gui)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 40, 40)
	stroke.Thickness = 24
	stroke.Transparency = 0.3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = litEdge

	local status = label({
		Name = "Status",
		Size = UDim2.new(0.5, 0, 0, 36),
		Position = UDim2.new(0.25, 0, 0, 48),
		ZIndex = 4,
	}, gui)

	local role = label({
		Name = "Role",
		Size = UDim2.new(0.4, 0, 0, 28),
		Position = UDim2.new(0.3, 0, 0, 88),
		ZIndex = 4,
	}, gui)

	local healthBack = frame({
		Name = "Health",
		Size = UDim2.new(0, 260, 0, 18),
		Position = UDim2.new(0.5, -130, 1, -60),
		BackgroundColor3 = Color3.fromRGB(30, 30, 30),
		BackgroundTransparency = 0.3,
		Visible = false,
		ZIndex = 4,
	}, gui)
	local healthFill = frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(240, 220, 120),
		ZIndex = 5,
	}, healthBack)

	local caught = label({
		Name = "Caught",
		Size = UDim2.new(0.5, 0, 0, 60),
		Position = UDim2.fromScale(0.25, 0.4),
		Text = "Caught! Back to the lobby until the next round.",
		TextColor3 = Color3.fromRGB(255, 90, 90),
		Visible = false,
		ZIndex = 6,
	}, gui)

	gui.Parent = player:WaitForChild("PlayerGui")

	local function update()
		local state = ReplicatedStorage:GetAttribute(Attributes.RoundState)
		local seconds = ReplicatedStorage:GetAttribute(Attributes.SecondsLeft) or 0
		local myRole = player:GetAttribute(Attributes.Role)
		local health = player:GetAttribute(Attributes.LightHealth)

		if state == States.Waiting then
			status.Text = `Waiting for players ({#Players:GetPlayers()}/{Config.Queue.MinPlayers})`
		elseif state == States.Countdown then
			status.Text = `Round starts in {seconds}`
		elseif state == States.Hiding then
			status.Text =
				`Hide! Seeker released in {seconds - (Config.Round.DurationSeconds - Config.Round.HidingSeconds)}`
		elseif state == States.Seeking then
			status.Text = RoundLogic.formatTime(seconds)
		elseif state == States.Results then
			local winner = ReplicatedStorage:GetAttribute(Attributes.Winner)
			status.Text = if winner == "Seeker" then "The seeker wins!" else "The hiders win!"
		else
			status.Text = ""
		end

		if myRole == Roles.Seeker then
			role.Text = "You are the SEEKER"
		elseif myRole == Roles.Hider then
			role.Text = "You are a HIDER"
		else
			role.Text = ""
		end

		blindness.Visible = myRole == Roles.Seeker and state == States.Hiding
		healthBack.Visible = myRole == Roles.Hider and typeof(health) == "number"
		if typeof(health) == "number" then
			healthFill.Size = UDim2.fromScale(math.clamp(health / Config.Health.Max, 0, 1), 1)
		end
		litEdge.Visible = player:GetAttribute(Attributes.Lit) == true
	end

	for _, name in { Attributes.RoundState, Attributes.SecondsLeft, Attributes.Winner } do
		ReplicatedStorage:GetAttributeChangedSignal(name):Connect(update)
	end
	for _, name in { Attributes.Role, Attributes.LightHealth, Attributes.Lit } do
		player:GetAttributeChangedSignal(name):Connect(update)
	end
	Players.PlayerAdded:Connect(update)
	Players.PlayerRemoving:Connect(update)
	update()

	local caughtRemote = Remotes.get(Remotes.Events.Caught) :: RemoteEvent
	caughtRemote.OnClientEvent:Connect(function()
		caught.Visible = true
		task.delay(3, function()
			caught.Visible = false
		end)
	end)
end

return HudController
