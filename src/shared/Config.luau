--[[
	Every tunable number for the game lives here.
	See "Decisions for Patrick" in the build plan for why each default was picked.
]]

local Config = {
	Queue = {
		MinPlayers = 3, -- 1 seeker + 2 hiders
		MaxPlayers = 8,
		CountdownSeconds = 10,
	},

	Match = {
		RoundsPerMatch = 3,
		-- Caught hiders wait in the lobby and rejoin for the next round.
		CaughtHidersRejoinNextRound = true,
	},

	Round = {
		DurationSeconds = 180, -- includes the hiding head start
		HidingSeconds = 15, -- seeker is frozen and blind
		ResultsSeconds = 5,
	},

	Health = {
		Max = 100,
		DrainPerSecond = 25, -- 4 seconds of steady light
		RegenPerSecond = 0,
	},

	Flashlight = {
		RangeStuds = 40,
		HalfAngleDegrees = 25,
		ChecksPerSecond = 10,
	},

	SeekerVision = {
		RadiusStuds = 8, -- the small circle the seeker can see without the flashlight
	},

	Scoring = {
		PerHiderCaught = 10,
		PerHiderSurvived = 10,
	},
}

return Config
