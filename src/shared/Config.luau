--[[
	Every tunable number for the game lives here.
	See "Decisions for Patrick" in the build plan for why each default was picked.
]]

local Config = {
	Queue = {
		MinPlayers = 3, -- 1 seeker + 2 hiders
		MaxPlayers = 8,
		CountdownSeconds = 10,
		-- One lobby pad per arena; each pad runs its own match.
		Pads = 2,
	},

	Match = {
		RoundsPerMatch = 3,
		-- Caught hiders wait in the lobby and rejoin for the next round.
		CaughtHidersRejoinNextRound = true,
		ResultsSeconds = 8, -- final standings before everyone returns to the lobby
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
		Brightness = 0.6,
	},

	-- What hiders (and everyone in the lobby) see: a dim dusk.
	Dusk = {
		ClockTime = 19.3,
		Brightness = 1,
		Ambient = Color3.fromRGB(45, 45, 70),
		OutdoorAmbient = Color3.fromRGB(80, 75, 110),
		FogColor = Color3.fromRGB(40, 40, 65),
		FogEnd = 350,
	},

	-- What the seeker sees outside the flashlight beam: nearly nothing.
	Darkness = {
		ClockTime = 0,
		Brightness = 0,
		Ambient = Color3.new(0, 0, 0),
		OutdoorAmbient = Color3.new(0, 0, 0),
		FogColor = Color3.new(0, 0, 0),
		FogEnd = 80,
	},

	-- Sound ids. These are sounds that ship with Roblox; swap in any audio from the Creator Store.
	Sounds = {
		Tick = "rbxasset://sounds/clickfast.wav", -- last seconds of the hiding countdown
		Release = "rbxasset://sounds/electronicpingshort.wav", -- the seeker is released
		Toggle = "rbxasset://sounds/clickfast.wav", -- flashlight on/off
		Heartbeat = "rbxasset://sounds/clickfast.wav", -- repeats, slowed down, while you are lit
		Caught = "rbxasset://sounds/uuhhh.mp3",
		RoundEnd = "rbxasset://sounds/electronicpingshort.wav",
		Whoosh = "rbxasset://sounds/swoosh.wav", -- sent to the lobby or the arena
	},

	Scoring = {
		PerHiderCaught = 10,
		PerHiderSurvived = 10,
	},
}

return Config
