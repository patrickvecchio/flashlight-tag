--[[
	One match: a group from a lobby pad plays Config.Match.RoundsPerMatch rounds in its arena.

	Each round:  Hiding -> Seeking -> Results
	After the last round (or if too few players are left): MatchResults, then back to the lobby.

	Caught hiders wait in the lobby and rejoin for the next round. Nobody seeks twice until
	everyone in the match has had a turn.
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

local Match = {}

local random = Random.new()

type Round = {
	seeker: Player,
	hiders: { [Player]: boolean }, -- true while still in the round
	ended: boolean,
}

type MatchState = {
	arena: World.Arena,
	players: { Player }, -- everyone still in the match, caught or not
	scores: { [Player]: number },
	sought: { [Player]: boolean },
	round: Round?,
}

-- Which match each player is in.
local matchOf: { [Player]: MatchState } = {}

local function hasLiveCharacter(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function setState(match: MatchState, state: string, secondsLeft: number?)
	for _, player in match.players do
		player:SetAttribute(Attributes.RoundState, state)
		player:SetAttribute(Attributes.SecondsLeft, secondsLeft)
	end
end

local function setAll(match: MatchState, name: string, value: any)
	for _, player in match.players do
		player:SetAttribute(name, value)
	end
end

local function addScore(match: MatchState, player: Player, points: number)
	if not table.find(match.players, player) then
		return
	end
	local score = (match.scores[player] or 0) + points
	match.scores[player] = score
	player:SetAttribute(Attributes.Score, score)
end

local function setFrozen(player: Player, frozen: boolean)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = if frozen then 0 else 16
		humanoid.JumpHeight = if frozen then 0 else 7.2
	end
end

local function clearRoundAttributes(player: Player)
	player:SetAttribute(Attributes.Role, nil)
	player:SetAttribute(Attributes.LightHealth, nil)
	player:SetAttribute(Attributes.Lit, nil)
end

local function clearMatchAttributes(player: Player)
	clearRoundAttributes(player)
	for _, name in
		{
			Attributes.MatchId,
			Attributes.RoundState,
			Attributes.SecondsLeft,
			Attributes.RoundNumber,
			Attributes.Winner,
			Attributes.Standings,
			Attributes.Score,
		}
	do
		player:SetAttribute(name, nil)
	end
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

local function removeHider(match: MatchState, round: Round, hider: Player, caught: boolean)
	if not round.hiders[hider] then
		return
	end
	round.hiders[hider] = false
	clearRoundAttributes(hider)
	if caught then
		addScore(match, round.seeker, Config.Scoring.PerHiderCaught);
		(Remotes.get(Remotes.Events.Caught) :: RemoteEvent):FireClient(hider)
	end
	if hider.Parent then
		World.sendToLobby(hider)
	end
end

local function runRound(match: MatchState, players: { Player }, roundNumber: number)
	local candidates = RoundLogic.seekerCandidates(players, match.sought)
	local seeker = RoundLogic.pickSeeker(candidates, random:NextNumber()) :: Player
	match.sought[seeker] = true

	local round: Round = { seeker = seeker, hiders = {}, ended = false }
	match.round = round
	setAll(match, Attributes.RoundNumber, roundNumber)

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

	World.sendToSeekerSpawn(match.arena, seeker)
	World.sendToHiderSpawns(match.arena, hiderList)
	setFrozen(seeker, true)

	-- Hiding: the seeker is frozen and blind while the hiders scatter.
	local totalSeconds = Config.Round.DurationSeconds
	local hidingSeconds = Config.Round.HidingSeconds
	for elapsed = 0, hidingSeconds - 1 do
		setState(match, States.Hiding, totalSeconds - elapsed)
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
			removeHider(match, round, hider, true)
		end)
	end

	local winner: string? = nil
	local secondsLeft = totalSeconds - hidingSeconds
	while not round.ended do
		-- Hiders who reset or fell out of the world are out for this round, with no points.
		for _, hider in hidersLeft(round) do
			if not hasLiveCharacter(hider) then
				removeHider(match, round, hider, false)
			end
		end
		if not hasLiveCharacter(seeker) then
			break
		end

		winner = RoundLogic.winner(#hidersLeft(round), secondsLeft)
		if winner then
			break
		end
		setState(match, States.Seeking, secondsLeft)
		task.wait(1)
		secondsLeft -= 1
	end
	-- The seeker left the game or reset: the hiders win.
	winner = winner or "Hiders"

	if stopDamage then
		stopDamage()
	end
	round.ended = true
	Flashlight.take(seeker)
	setFrozen(seeker, false)

	if winner == "Hiders" then
		for _, hider in hidersLeft(round) do
			addScore(match, hider, Config.Scoring.PerHiderSurvived)
		end
	end

	-- Results, then everyone still in the arena goes back to the lobby.
	setAll(match, Attributes.Winner, winner)
	setState(match, States.Results, Config.Round.ResultsSeconds)
	task.wait(Config.Round.ResultsSeconds)
	setAll(match, Attributes.Winner, nil)

	for _, hider in hidersLeft(round) do
		removeHider(match, round, hider, false)
	end
	if seeker.Parent then
		clearRoundAttributes(seeker)
		World.sendToLobby(seeker)
	end
	match.round = nil
end

local function playersReady(match: MatchState): { Player }
	local ready = {}
	for _, player in match.players do
		if hasLiveCharacter(player) then
			table.insert(ready, player)
		end
	end
	return ready
end

--[=[
	Runs a whole match for `players` in arena `arenaIndex` and returns when it is over.
]=]
function Match.run(arenaIndex: number, players: { Player })
	local match: MatchState = {
		arena = World.arena(arenaIndex),
		players = table.clone(players),
		scores = {},
		sought = {},
		round = nil,
	}
	for _, player in match.players do
		matchOf[player] = match
		match.scores[player] = 0
		player:SetAttribute(Attributes.MatchId, arenaIndex)
		player:SetAttribute(Attributes.Score, 0)
	end

	local ok, err = pcall(function()
		local roundsPlayed = 0
		for roundNumber = 1, Config.Match.RoundsPerMatch do
			local ready = playersReady(match)
			if #ready < Config.Queue.MinPlayers then
				break
			end
			runRound(match, ready, roundNumber)
			roundsPlayed += 1
		end

		if roundsPlayed > 0 and #match.players > 0 then
			local entries = {}
			for _, player in match.players do
				table.insert(entries, { name = player.DisplayName, score = match.scores[player] or 0 })
			end
			setAll(match, Attributes.Standings, RoundLogic.formatStandings(entries))
			setState(match, States.MatchResults, Config.Match.ResultsSeconds)
			task.wait(Config.Match.ResultsSeconds)
		end
	end)

	-- Whatever happened, put everyone back in a clean lobby state.
	local round = match.round
	if round then
		Flashlight.take(round.seeker)
		setFrozen(round.seeker, false)
	end
	for _, player in match.players do
		matchOf[player] = nil
		clearMatchAttributes(player)
		if player.Parent then
			World.sendToLobby(player)
		end
	end

	if not ok then
		error(err, 0)
	end
end

function Match.init()
	Players.PlayerRemoving:Connect(function(player)
		local match = matchOf[player]
		if not match then
			return
		end
		matchOf[player] = nil
		local index = table.find(match.players, player)
		if index then
			table.remove(match.players, index)
		end
		local round = match.round
		if round then
			if player == round.seeker then
				round.ended = true
			elseif round.hiders[player] then
				round.hiders[player] = false
			end
		end
	end)
end

return Match
