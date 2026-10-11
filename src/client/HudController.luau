--[[
	A plain HUD for playtesting: lobby and round status, your role and score, a hider health
	bar, a red edge while you are in the beam, a black screen for the seeker while hiders hide,
	and the final standings at the end of a match.
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

	local score = label({
		Name = "Score",
		Size = UDim2.new(0, 160, 0, 26),
		Position = UDim2.new(1, -176, 0, 48),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 4,
	}, gui)

	local standings = label({
		Name = "Standings",
		Size = UDim2.new(0.3, 0, 0.4, 0),
		Position = UDim2.fromScale(0.35, 0.3),
		BackgroundTransparency = 0.3,
		BackgroundColor3 = Color3.fromRGB(20, 20, 30),
		TextScaled = false,
		TextSize = 24,
		TextYAlignment = Enum.TextYAlignment.Top,
		Visible = false,
		ZIndex = 6,
	}, gui)

	gui.Parent = player:WaitForChild("PlayerGui")

	local function update()
		local state = player:GetAttribute(Attributes.RoundState)
		local seconds = player:GetAttribute(Attributes.SecondsLeft) or 0
		local roundNumber = player:GetAttribute(Attributes.RoundNumber) or 1
		local myRole = player:GetAttribute(Attributes.Role)
		local health = player:GetAttribute(Attributes.LightHealth)
		local myScore = player:GetAttribute(Attributes.Score)
		local pad = player:GetAttribute(Attributes.Pad)
		local roundText = `Round {roundNumber} of {Config.Match.RoundsPerMatch}`

		if player:GetAttribute(Attributes.MatchId) == nil then
			status.Text = if pad
				then `In group {pad}. Waiting for players...`
				else "Walk up to a group pad to join a game"
		elseif state == States.Hiding then
			local release = seconds - (Config.Round.DurationSeconds - Config.Round.HidingSeconds)
			status.Text = `{roundText}: hide! Seeker released in {release}`
		elseif state == States.Seeking then
			status.Text = `{roundText}  {RoundLogic.formatTime(seconds)}`
		elseif state == States.Results then
			local winner = player:GetAttribute(Attributes.Winner)
			status.Text = if winner == "Seeker" then "The seeker wins the round!" else "The hiders win the round!"
		elseif state == States.MatchResults then
			status.Text = "Match over"
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

		score.Text = if typeof(myScore) == "number" then `Score: {myScore}` else ""

		local standingsText = player:GetAttribute(Attributes.Standings)
		standings.Visible = state == States.MatchResults and typeof(standingsText) == "string"
		if typeof(standingsText) == "string" then
			standings.Text = `Final scores\n\n{standingsText}`
		end

		blindness.Visible = myRole == Roles.Seeker and state == States.Hiding
		healthBack.Visible = myRole == Roles.Hider and typeof(health) == "number"
		if typeof(health) == "number" then
			healthFill.Size = UDim2.fromScale(math.clamp(health / Config.Health.Max, 0, 1), 1)
		end
		litEdge.Visible = player:GetAttribute(Attributes.Lit) == true
	end

	player.AttributeChanged:Connect(update)
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
