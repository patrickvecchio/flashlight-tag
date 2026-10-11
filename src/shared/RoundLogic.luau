--[[
	Pure round rules, kept free of Roblox services so they can be unit tested with Lune.
]]

local RoundLogic = {}

--[=[
	Picks one entry from `candidates`. `roll` is a number in [0, 1), e.g. Random:NextNumber().
]=]
function RoundLogic.pickSeeker<T>(candidates: { T }, roll: number): T?
	local count = #candidates
	if count == 0 then
		return nil
	end
	local index = math.clamp(math.floor(roll * count) + 1, 1, count)
	return candidates[index]
end

--[=[
	Players who may seek next: everyone who has not sought yet this match,
	or everyone again once all of them have had a turn.
]=]
function RoundLogic.seekerCandidates<T>(players: { T }, sought: { [T]: boolean }): { T }
	local fresh = {}
	for _, player in players do
		if not sought[player] then
			table.insert(fresh, player)
		end
	end
	if #fresh == 0 then
		return table.clone(players)
	end
	return fresh
end

--[=[
	Orders { name, score } entries highest first (ties by name) and formats them for the HUD.
]=]
function RoundLogic.formatStandings(entries: { { name: string, score: number } }): string
	local sorted = table.clone(entries)
	table.sort(sorted, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.name < b.name
	end)
	local lines = {}
	for place, entry in sorted do
		table.insert(lines, `{place}. {entry.name}  {entry.score}`)
	end
	return table.concat(lines, "\n")
end

--[=[
	Health after `seconds` in the beam at `ratePerSecond`, never below zero.
]=]
function RoundLogic.drain(health: number, seconds: number, ratePerSecond: number): number
	return math.max(0, health - seconds * ratePerSecond)
end

--[=[
	Who has won, or nil if the round should keep going.
	The seeker wins once no hiders are left; the hiders win when time runs out.
]=]
function RoundLogic.winner(hidersLeft: number, secondsLeft: number): ("Seeker" | "Hiders")?
	if hidersLeft <= 0 then
		return "Seeker"
	end
	if secondsLeft <= 0 then
		return "Hiders"
	end
	return nil
end

--[=[
	Formats seconds as m:ss for the HUD timer.
]=]
function RoundLogic.formatTime(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

return RoundLogic
