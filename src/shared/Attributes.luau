--[[
	Attribute names the server sets and clients read. Everything lives on the Player, so each
	client only needs to watch its own player, and a late joiner sees current values.

	Lobby:
		Pad         - the group pad the player has joined, nil when not queued

	Match state (set on every player in a match, including caught hiders waiting in the lobby):
		MatchId     - which pad/arena the player's match uses, nil when not in a match
		RoundState  - one of Attributes.States
		SecondsLeft - whole seconds left in the current state
		RoundNumber - 1-based round within the match
		Winner      - "Seeker" or "Hiders" during Results, nil otherwise
		Standings   - final scores text during MatchResults, nil otherwise
		Score       - this player's points so far in the match

	Round state (only while the player is in the arena):
		Role        - "Seeker" or "Hider"
		LightHealth - hider health, 0 to Config.Health.Max
		Lit         - true while the flashlight is on this hider
]]

return {
	Pad = "Pad",
	MatchId = "MatchId",
	RoundState = "RoundState",
	SecondsLeft = "SecondsLeft",
	RoundNumber = "RoundNumber",
	Winner = "Winner",
	Standings = "Standings",
	Score = "Score",

	Role = "Role",
	LightHealth = "LightHealth",
	Lit = "Lit",

	States = {
		Hiding = "Hiding",
		Seeking = "Seeking",
		Results = "Results",
		MatchResults = "MatchResults",
	},

	Roles = {
		Seeker = "Seeker",
		Hider = "Hider",
	},
}
