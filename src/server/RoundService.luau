--[[
	Runs rounds back to back:

		Waiting -> Countdown -> Hiding -> Seeking -> Results -> Waiting ...

	Phase 2 runs one round at a time for everyone in the server. Lobby pads, groups and
	several rounds per match arrive in phase 3.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoundLogic = require(ReplicatedStorage.Shared.RoundLogic)
local Flashlight = require(script.Parent.Flashlight)
local World = require(script.Parent.World)

local States = Attributes.States
local Roles = Attributes.Roles

local RoundService = {}

local random = Random.new()

type Round = {
	seeker: Player,
	hiders: { [Player]: boolean }, -- true while still in the round
	ended: boolean,
}

local current: Round? = nil

local function setState(state: string, secondsLeft: number?)
	ReplicatedStorage:SetAttribute(Attributes.RoundState, state)
	ReplicatedStorage:SetAttribute(Attributes.SecondsLeft, secondsLeft)
end

local function hasLiveCharacter(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function readyPlayers(): { Player }
	local ready = {}
	for _, player in Players:GetPlayers() do
		if hasLiveCharacter(player) then
			table.insert(ready, player)
		end
	end
	return ready
end

local function hidersLeft(round: Round): { Player }
	local left = {}
	for hider, inRound in round.hiders do
		if inRound then
			table.insert(left, hider)
		end
	end
	return left
end

local function setFrozen(player: Player, frozen: boolean)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = if frozen then 0 else 16
		humanoid.JumpHeight = if frozen then 0 else 7.2
	end
end

local function clearPlayer(player: Player)
	player:SetAttribute(Attributes.Role, nil)
	player:SetAttribute(Attributes.LightHealth, nil)
	player:SetAttribute(Attributes.Lit, nil)
end

local function removeHider(round: Round, hider: Player, caught: boolean)
	if not round.hiders[hider] then
		return
	end
	round.hiders[hider] = false
	clearPlayer(hider)
	if caught then
		(Remotes.get(Remotes.Events.Caught) :: RemoteEvent):FireClient(hider)
	end
	if hider.Parent then
		World.sendToLobby(hider)
	end
end

-- Waits until enough players are in the server, then counts down. Returns once a round can start.
local function waitForPlayers()
	while true do
		setState(States.Waiting)
		while #readyPlayers() < Config.Queue.MinPlayers do
			task.wait(1)
		end

		local cancelled = false
		for secondsLeft = Config.Queue.CountdownSeconds, 1, -1 do
			setState(States.Countdown, secondsLeft)
			task.wait(1)
			if #readyPlayers() < Config.Queue.MinPlayers then
				cancelled = true
				break
			end
		end
		if not cancelled then
			return
		end
	end
end

local function runRound()
	local players = readyPlayers()
	local seeker = RoundLogic.pickSeeker(players, random:NextNumber())
	if not seeker then
		return
	end

	local round: Round = { seeker = seeker, hiders = {}, ended = false }
	local hiderList = {}
	for _, player in players do
		if player ~= seeker then
			round.hiders[player] = true
			table.insert(hiderList, player)
			player:SetAttribute(Attributes.Role, Roles.Hider)
			player:SetAttribute(Attributes.LightHealth, Config.Health.Max)
			player:SetAttribute(Attributes.Lit, false)
		end
	end
	seeker:SetAttribute(Attributes.Role, Roles.Seeker)
	current = round

	World.sendToSeekerSpawn(seeker)
	World.sendToHiderSpawns(hiderList)
	setFrozen(seeker, true)

	-- Hiding: the seeker is frozen and blind while the hiders scatter.
	local totalSeconds = Config.Round.DurationSeconds
	local hidingSeconds = Config.Round.HidingSeconds
	for elapsed = 0, hidingSeconds - 1 do
		setState(States.Hiding, totalSeconds - elapsed)
		task.wait(1)
		if round.ended then
			break
		end
	end

	-- Seeking: the flashlight comes out and the clock runs down.
	local stopDamage: (() -> ())? = nil
	if not round.ended then
		setFrozen(seeker, false)
		Flashlight.give(seeker)
		stopDamage = Flashlight.startDamage(seeker, function()
			return hidersLeft(round)
		end, function(hider)
			removeHider(round, hider, true)
		end)
	end

	local winner: string? = nil
	local secondsLeft = totalSeconds - hidingSeconds
	while not round.ended do
		-- Hiders who reset or fell out of the world are out, but not counted as caught.
		for _, hider in hidersLeft(round) do
			if not hasLiveCharacter(hider) then
				removeHider(round, hider, false)
			end
		end
		if not hasLiveCharacter(seeker) then
			winner = "Hiders"
			break
		end

		winner = RoundLogic.winner(#hidersLeft(round), secondsLeft)
		if winner then
			break
		end
		setState(States.Seeking, secondsLeft)
		task.wait(1)
		secondsLeft -= 1
	end
	if round.ended and not winner then
		-- The seeker left the game.
		winner = "Hiders"
	end

	if stopDamage then
		stopDamage()
	end
	round.ended = true
	Flashlight.take(seeker)
	setFrozen(seeker, false)

	-- Results, then everyone still in the arena goes back to the lobby.
	ReplicatedStorage:SetAttribute(Attributes.Winner, winner)
	setState(States.Results, Config.Round.ResultsSeconds)
	task.wait(Config.Round.ResultsSeconds)
	ReplicatedStorage:SetAttribute(Attributes.Winner, nil)

	for _, hider in hidersLeft(round) do
		removeHider(round, hider, false)
	end
	if seeker.Parent then
		clearPlayer(seeker)
		World.sendToLobby(seeker)
	end
	current = nil
end

function RoundService.start()
	Players.PlayerRemoving:Connect(function(player)
		local round = current
		if not round then
			return
		end
		if player == round.seeker then
			round.ended = true
		elseif round.hiders[player] then
			round.hiders[player] = false
		end
	end)

	task.spawn(function()
		while true do
			waitForPlayers()
			local ok, err = pcall(runRound)
			if not ok then
				warn(`[FlashlightTag] Round failed: {err}`)
				-- Put everyone back in a clean lobby state so the next round can start.
				current = nil
				ReplicatedStorage:SetAttribute(Attributes.Winner, nil)
				for _, player in Players:GetPlayers() do
					if player:GetAttribute(Attributes.Role) ~= nil then
						Flashlight.take(player)
						setFrozen(player, false)
						clearPlayer(player)
						World.sendToLobby(player)
					end
				end
			end
		end
	end)
end

return RoundService
