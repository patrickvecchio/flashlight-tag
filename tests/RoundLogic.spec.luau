local RoundLogic = require("../src/shared/RoundLogic")

return {
	["pickSeeker covers every candidate"] = function()
		local players = { "a", "b", "c" }
		assert(RoundLogic.pickSeeker(players, 0) == "a", "roll 0 picks the first")
		assert(RoundLogic.pickSeeker(players, 0.5) == "b", "roll 0.5 picks the middle")
		assert(RoundLogic.pickSeeker(players, 0.9999) == "c", "roll near 1 picks the last")
	end,

	["pickSeeker with nobody returns nil"] = function()
		assert(RoundLogic.pickSeeker({}, 0.5) == nil, "expected nil")
	end,

	["drain takes rate times seconds"] = function()
		assert(RoundLogic.drain(100, 0.1, 25) == 97.5, "expected 97.5")
	end,

	["drain never goes below zero"] = function()
		assert(RoundLogic.drain(10, 1, 25) == 0, "expected 0")
	end,

	["seeker wins when no hiders are left"] = function()
		assert(RoundLogic.winner(0, 60) == "Seeker", "expected Seeker")
	end,

	["hiders win when time runs out"] = function()
		assert(RoundLogic.winner(2, 0) == "Hiders", "expected Hiders")
	end,

	["seeker wins if the last hider falls as time runs out"] = function()
		assert(RoundLogic.winner(0, 0) == "Seeker", "expected Seeker")
	end,

	["round continues otherwise"] = function()
		assert(RoundLogic.winner(1, 1) == nil, "expected nil")
	end,

	["formatTime pads seconds"] = function()
		assert(RoundLogic.formatTime(180) == "3:00", "expected 3:00")
		assert(RoundLogic.formatTime(65) == "1:05", "expected 1:05")
		assert(RoundLogic.formatTime(0.2) == "0:01", "expected 0:01")
		assert(RoundLogic.formatTime(-3) == "0:00", "expected 0:00")
	end,

	["seekerCandidates skips players who already sought"] = function()
		local candidates = RoundLogic.seekerCandidates({ "a", "b", "c" }, { a = true })
		assert(#candidates == 2 and candidates[1] == "b" and candidates[2] == "c", "expected b and c")
	end,

	["seekerCandidates starts over once everyone has sought"] = function()
		local candidates = RoundLogic.seekerCandidates({ "a", "b" }, { a = true, b = true })
		assert(#candidates == 2, "expected everyone again")
	end,

	["formatStandings sorts by score then name"] = function()
		local text = RoundLogic.formatStandings({
			{ name = "Cam", score = 10 },
			{ name = "Ann", score = 20 },
			{ name = "Bo", score = 10 },
		})
		assert(text == "1. Ann  20\n2. Bo  10\n3. Cam  10", `got {text}`)
	end,
}
