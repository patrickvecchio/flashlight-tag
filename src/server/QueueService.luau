--[[
	Lobby pads. Each pad is a group: players join or leave it with a prompt, and once it has
	enough players a countdown starts. When the countdown ends, the pad's players start a match
	in that pad's arena, and the pad stays locked until the match is over.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local World = require(script.Parent.World)

local QueueService = {}

type Pad = {
	index: number,
	members: { Player },
	inMatch: boolean,
	countdown: number?, -- seconds left, nil when not counting down
	prompt: ProximityPrompt,
	label: TextLabel,
	part: Part,
}

local pads: { Pad } = {}

local function padOf(player: Player): Pad?
	for _, pad in pads do
		if table.find(pad.members, player) then
			return pad
		end
	end
	return nil
end

local function refresh(pad: Pad)
	local count = #pad.members
	local max = Config.Queue.MaxPlayers
	local text
	if pad.inMatch then
		text = `Group {pad.index}\nMatch in progress`
		pad.part.Color = Color3.fromRGB(120, 60, 60)
	elseif pad.countdown then
		text = `Group {pad.index}  {count}/{max}\nStarting in {pad.countdown}`
		pad.part.Color = Color3.fromRGB(70, 140, 80)
	else
		local need = math.max(0, Config.Queue.MinPlayers - count)
		local waiting = if need > 0 then `Need {need} more` else "Ready"
		text = `Group {pad.index}  {count}/{max}\n{waiting}`
		pad.part.Color = Color3.fromRGB(70, 90, 160)
	end
	pad.label.Text = text
	pad.prompt.Enabled = not pad.inMatch
end

local function remove(pad: Pad, player: Player)
	local index = table.find(pad.members, player)
	if index then
		table.remove(pad.members, index)
		player:SetAttribute(Attributes.Pad, nil)
		refresh(pad)
	end
end

local function makePad(index: number, count: number): Pad
	local part = Instance.new("Part")
	part.Name = `Pad{index}`
	part.Anchored = true
	part.Size = Vector3.new(12, 1, 12)
	part.Position = World.padPosition(index, count) + Vector3.new(0, 0.5, 0)
	part.Material = Enum.Material.Neon
	part.Parent = World.lobbyFolder()

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = `Group {index}`
	prompt.ActionText = "Join / Leave"
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(220, 70)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Parent = billboard

	return {
		index = index,
		members = {},
		inMatch = false,
		countdown = nil,
		prompt = prompt,
		label = label,
		part = part,
	}
end

local function onTriggered(pad: Pad, player: Player)
	if pad.inMatch or player:GetAttribute(Attributes.MatchId) ~= nil then
		return
	end
	local current = padOf(player)
	if current == pad then
		remove(pad, player)
		return
	end
	if #pad.members >= Config.Queue.MaxPlayers then
		return
	end
	if current then
		remove(current, player)
	end
	table.insert(pad.members, player)
	player:SetAttribute(Attributes.Pad, pad.index)
	refresh(pad)
end

-- Counts down while the pad has enough players, then hands its players to `startMatch`.
local function runPad(pad: Pad, startMatch: (padIndex: number, players: { Player }) -> ())
	while true do
		task.wait(1)
		if pad.inMatch then
			continue
		end
		if #pad.members < Config.Queue.MinPlayers then
			if pad.countdown then
				pad.countdown = nil
				refresh(pad)
			end
			continue
		end

		pad.countdown = if pad.countdown then pad.countdown - 1 else Config.Queue.CountdownSeconds
		if (pad.countdown :: number) > 0 then
			refresh(pad)
			continue
		end

		local players = pad.members
		pad.members = {}
		for _, player in players do
			player:SetAttribute(Attributes.Pad, nil)
		end
		pad.countdown = nil
		pad.inMatch = true
		refresh(pad)

		task.spawn(function()
			local ok, err = pcall(startMatch, pad.index, players)
			if not ok then
				warn(`[FlashlightTag] Match on pad {pad.index} failed: {err}`)
			end
			pad.inMatch = false
			refresh(pad)
		end)
	end
end

--[=[
	Builds the pads and starts watching them. `startMatch` runs a whole match and returns when
	it is over; the pad unlocks then.
]=]
function QueueService.start(startMatch: (padIndex: number, players: { Player }) -> ())
	local count = Config.Queue.Pads
	for index = 1, count do
		local pad = makePad(index, count)
		pads[index] = pad
		pad.prompt.Triggered:Connect(function(player)
			onTriggered(pad, player)
		end)
		refresh(pad)
		task.spawn(runPad, pad, startMatch)
	end

	Players.PlayerRemoving:Connect(function(player)
		local pad = padOf(player)
		if pad then
			remove(pad, player)
		end
	end)
end

return QueueService
