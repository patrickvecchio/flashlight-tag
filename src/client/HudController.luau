--[[
	The HUD:

	- Top: a timer pill with the round and phase, how many hiders are left, and your score.
	- Centre: a role banner at the start of each round, a crosshair for the seeker, the
	  seeker's blackout while hiders hide, "Caught!" and the final standings.
	- Bottom: a hider's light meter, and a hint for the seeker on how to toggle the flashlight.
	- Edges: a pulsing red border while you are in the beam.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoundLogic = require(ReplicatedStorage.Shared.RoundLogic)

local States = Attributes.States
local Roles = Attributes.Roles

local HudController = {}

local player = Players.LocalPlayer

local PANEL = Color3.fromRGB(18, 20, 30)
local TEXT = Color3.fromRGB(240, 240, 245)
local MUTED = Color3.fromRGB(170, 175, 195)
local SEEKER = Color3.fromRGB(255, 205, 90)
local HIDER = Color3.fromRGB(120, 190, 255)
local DANGER = Color3.fromRGB(255, 70, 70)

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local function corner(parent: Instance, radius: number)
	new("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function text(props: { [string]: any }, parent: Instance): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = TEXT,
		TextScaled = true,
	}
	for key, value in props do
		defaults[key] = value
	end
	return new("TextLabel", defaults, parent)
end

local function toggleHint(): string
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Tap LIGHT to switch the flashlight on or off"
	elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "Press X to switch the flashlight on or off"
	end
	return "Press F to switch the flashlight on or off"
end

function HudController.start()
	local gui = new("ScreenGui", { Name = "FlashlightTagHud", ResetOnSpawn = false, IgnoreGuiInset = true })

	-- Seeker blackout while the hiders hide
	local blindness = new("Frame", {
		Name = "Blindness",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 1,
	}, gui)
	local blindText = text({
		Size = UDim2.new(0.6, 0, 0, 36),
		Position = UDim2.new(0.2, 0, 0.5, 20),
		Font = Enum.Font.Gotham,
		TextColor3 = MUTED,
		ZIndex = 2,
	}, blindness)

	-- Red border while lit
	local litEdge = new("Frame", {
		Name = "LitEdge",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 3,
	}, gui)
	local litStroke = new("UIStroke", {
		Color = DANGER,
		Thickness = 28,
		Transparency = 0.2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, litEdge)

	-- Top: timer pill
	local pill = new("Frame", {
		Name = "Timer",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 44),
		Size = UDim2.fromOffset(240, 64),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.25,
		Visible = false,
		ZIndex = 4,
	}, gui)
	corner(pill, 14)
	local timerText = text({ Size = UDim2.new(1, 0, 0, 38), Position = UDim2.fromOffset(0, 4), ZIndex = 5 }, pill)
	local phaseText = text({
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.fromOffset(8, 42),
		Font = Enum.Font.Gotham,
		TextColor3 = MUTED,
		ZIndex = 5,
	}, pill)

	-- Top: lobby / results message
	local banner = text({
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.new(0.6, 0, 0, 34),
		TextStrokeTransparency = 0.5,
		ZIndex = 4,
	}, gui)

	-- Top right: score and hiders left
	local stats = new("Frame", {
		Name = "Stats",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 44),
		Size = UDim2.fromOffset(170, 64),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.25,
		Visible = false,
		ZIndex = 4,
	}, gui)
	corner(stats, 12)
	local scoreText = text({
		Size = UDim2.new(1, -20, 0, 26),
		Position = UDim2.fromOffset(10, 6),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 5,
	}, stats)
	local hidersText = text({
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.fromOffset(10, 36),
		Font = Enum.Font.Gotham,
		TextColor3 = MUTED,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 5,
	}, stats)

	-- Centre: role banner
	local roleBanner = text({
		Name = "RoleBanner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.new(0.7, 0, 0, 64),
		TextStrokeTransparency = 0.3,
		TextTransparency = 1,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		ZIndex = 6,
	}, gui)

	-- Centre: seeker crosshair and spotting cue
	local crosshair = new("Frame", {
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(14, 14),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 4,
	}, gui)
	corner(crosshair, 7)
	local crosshairStroke = new("UIStroke", { Color = TEXT, Thickness = 2, Transparency = 0.2 }, crosshair)
	local spotted = text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 18),
		Size = UDim2.fromOffset(200, 24),
		Text = "SPOTTED!",
		TextColor3 = DANGER,
		TextStrokeTransparency = 0.4,
		Visible = false,
		ZIndex = 4,
	}, gui)

	-- Bottom: light meter for hiders
	local meter = new("Frame", {
		Name = "LightMeter",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -40),
		Size = UDim2.fromOffset(300, 44),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.25,
		Visible = false,
		ZIndex = 4,
	}, gui)
	corner(meter, 12)
	text({
		Size = UDim2.new(0, 60, 0, 16),
		Position = UDim2.fromOffset(12, 4),
		Text = "HIDDEN",
		TextColor3 = MUTED,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5,
	}, meter)
	local meterBack = new("Frame", {
		Position = UDim2.fromOffset(12, 22),
		Size = UDim2.new(1, -24, 0, 12),
		BackgroundColor3 = Color3.fromRGB(50, 52, 65),
		BorderSizePixel = 0,
		ZIndex = 5,
	}, meter)
	corner(meterBack, 6)
	local meterFill = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = HIDER,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, meterBack)
	corner(meterFill, 6)

	-- Bottom: seeker hint
	local hint = text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -48),
		Size = UDim2.new(0.6, 0, 0, 22),
		Font = Enum.Font.Gotham,
		TextColor3 = MUTED,
		TextStrokeTransparency = 0.6,
		Visible = false,
		ZIndex = 4,
	}, gui)

	-- Centre: caught message and final standings
	local caught = text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(0.6, 0, 0, 56),
		Text = "Caught! You'll be back next round.",
		TextColor3 = DANGER,
		TextStrokeTransparency = 0.3,
		Visible = false,
		ZIndex = 7,
	}, gui)

	local standings = new("Frame", {
		Name = "Standings",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(360, 320),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.1,
		Visible = false,
		ZIndex = 7,
	}, gui)
	corner(standings, 16)
	text({
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.fromOffset(0, 16),
		Text = "Final scores",
		ZIndex = 8,
	}, standings)
	local standingsText = text({
		Size = UDim2.new(1, -40, 1, -76),
		Position = UDim2.fromOffset(20, 64),
		Font = Enum.Font.Gotham,
		TextScaled = false,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 8,
	}, standings)

	gui.Parent = player:WaitForChild("PlayerGui")

	local function showRole(role: string)
		roleBanner.Text = if role == Roles.Seeker then "YOU ARE THE SEEKER" else "YOU ARE A HIDER"
		roleBanner.TextColor3 = if role == Roles.Seeker then SEEKER else HIDER
		roleBanner.TextTransparency = 0
		roleBanner.TextStrokeTransparency = 0.3
		TweenService:Create(
			roleBanner,
			TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 2.5),
			{ TextTransparency = 1, TextStrokeTransparency = 1 }
		):Play()
	end

	local function update()
		local state = player:GetAttribute(Attributes.RoundState)
		local seconds = player:GetAttribute(Attributes.SecondsLeft) or 0
		local roundNumber = player:GetAttribute(Attributes.RoundNumber) or 1
		local role = player:GetAttribute(Attributes.Role)
		local health = player:GetAttribute(Attributes.LightHealth)
		local score = player:GetAttribute(Attributes.Score)
		local hidersLeft = player:GetAttribute(Attributes.HidersLeft)
		local pad = player:GetAttribute(Attributes.Pad)
		local inMatch = player:GetAttribute(Attributes.MatchId) ~= nil
		local roundText = `Round {roundNumber} of {Config.Match.RoundsPerMatch}`

		-- Timer pill and banner
		pill.Visible = inMatch and (state == States.Hiding or state == States.Seeking)
		if state == States.Hiding then
			local release = seconds - (Config.Round.DurationSeconds - Config.Round.HidingSeconds)
			timerText.Text = RoundLogic.formatTime(release)
			timerText.TextColor3 = HIDER
			phaseText.Text = `{roundText} · Hide!`
		elseif state == States.Seeking then
			timerText.Text = RoundLogic.formatTime(seconds)
			timerText.TextColor3 = if seconds <= 10 then DANGER else TEXT
			phaseText.Text = `{roundText} · Seeker is hunting`
		end

		if not inMatch then
			banner.Text = if pad
				then `You're in group {pad}. Waiting for players...`
				else "Walk up to a group pad to join a game"
			banner.TextColor3 = TEXT
		elseif state == States.Results then
			local winner = player:GetAttribute(Attributes.Winner)
			banner.Text = if winner == "Seeker" then "The seeker caught everyone!" else "The hiders survived!"
			banner.TextColor3 = if winner == "Seeker" then SEEKER else HIDER
		elseif state == States.Hiding or state == States.Seeking then
			banner.Text = if role == nil then "Caught. Watch the clock, you're back next round." else ""
			banner.TextColor3 = MUTED
		else
			banner.Text = ""
		end

		-- Stats
		stats.Visible = inMatch
		scoreText.Text = if typeof(score) == "number" then `Score {score}` else ""
		hidersText.Text = if typeof(hidersLeft) == "number"
			then `{hidersLeft} hider{if hidersLeft == 1 then "" else "s"} left`
			else ""

		-- Seeker view
		local seeking = role == Roles.Seeker and state == States.Seeking
		blindness.Visible = role == Roles.Seeker and state == States.Hiding
		blindText.Text = `The hiders are hiding. You're released in {math.max(
			0,
			seconds - (Config.Round.DurationSeconds - Config.Round.HidingSeconds)
		)}...`
		crosshair.Visible = seeking
		local spotting = player:GetAttribute(Attributes.Spotting)
		local isSpotting = seeking and typeof(spotting) == "number" and spotting > 0
		spotted.Visible = isSpotting
		crosshairStroke.Color = if isSpotting then DANGER else TEXT
		hint.Visible = seeking
		hint.Text = toggleHint()

		-- Hider view
		meter.Visible = role == Roles.Hider and typeof(health) == "number"
		if typeof(health) == "number" then
			local fraction = math.clamp(health / Config.Health.Max, 0, 1)
			meterFill.Size = UDim2.fromScale(fraction, 1)
			meterFill.BackgroundColor3 = HIDER:Lerp(DANGER, 1 - fraction)
		end
		litEdge.Visible = player:GetAttribute(Attributes.Lit) == true

		-- End of match
		local standingsValue = player:GetAttribute(Attributes.Standings)
		standings.Visible = state == States.MatchResults and typeof(standingsValue) == "string"
		if typeof(standingsValue) == "string" then
			standingsText.Text = standingsValue
		end
	end

	player.AttributeChanged:Connect(function(name)
		if name == Attributes.Role then
			local role = player:GetAttribute(Attributes.Role)
			if role then
				showRole(role)
			end
		end
		update()
	end)
	update()

	-- Pulse the red border while it shows.
	TweenService:Create(
		litStroke,
		TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.7 }
	):Play()

	local caughtRemote = Remotes.get(Remotes.Events.Caught) :: RemoteEvent
	local caughtToken = 0
	caughtRemote.OnClientEvent:Connect(function()
		caughtToken += 1
		local token = caughtToken
		caught.Visible = true
		task.delay(3, function()
			if token == caughtToken then
				caught.Visible = false
			end
		end)
	end)
end

return HudController
