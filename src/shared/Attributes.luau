--[[
	Attribute names the server sets and clients read.

	On ReplicatedStorage (the round everyone sees):
		RoundState  - one of Attributes.States
		SecondsLeft - whole seconds left in the current state
		Winner      - "Seeker" or "Hiders" during Results, nil otherwise

	On each Player:
		Role        - "Seeker" or "Hider" while in a round, nil in the lobby
		LightHealth - hider health, 0 to Config.Health.Max
		Lit         - true while the flashlight is on this hider
]]

return {
	RoundState = "RoundState",
	SecondsLeft = "SecondsLeft",
	Winner = "Winner",

	Role = "Role",
	LightHealth = "LightHealth",
	Lit = "Lit",

	States = {
		Waiting = "Waiting",
		Countdown = "Countdown",
		Hiding = "Hiding",
		Seeking = "Seeking",
		Results = "Results",
	},

	Roles = {
		Seeker = "Seeker",
		Hider = "Hider",
	},
}
