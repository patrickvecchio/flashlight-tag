local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3

local Cone = require("../src/shared/Cone")

local ORIGIN = Vector3.new(0, 0, 0)
local FORWARD = Vector3.new(0, 0, -1)
local RANGE = 40
local HALF_ANGLE = 25

local function check(target)
	return Cone.contains(ORIGIN, FORWARD, target, RANGE, HALF_ANGLE)
end

return {
	["straight ahead in range is lit"] = function()
		assert(check(Vector3.new(0, 0, -10)), "expected lit")
	end,

	["beyond range is not lit"] = function()
		assert(not check(Vector3.new(0, 0, -41)), "expected not lit")
	end,

	["behind the seeker is not lit"] = function()
		assert(not check(Vector3.new(0, 0, 10)), "expected not lit")
	end,

	["just inside the cone edge is lit"] = function()
		local angle = math.rad(HALF_ANGLE - 1)
		assert(check(Vector3.new(math.sin(angle) * 20, 0, -math.cos(angle) * 20)), "expected lit")
	end,

	["just outside the cone edge is not lit"] = function()
		local angle = math.rad(HALF_ANGLE + 1)
		assert(not check(Vector3.new(math.sin(angle) * 20, 0, -math.cos(angle) * 20)), "expected not lit")
	end,

	["direction does not need to be unit length"] = function()
		assert(Cone.contains(ORIGIN, FORWARD * 5, Vector3.new(0, 0, -10), RANGE, HALF_ANGLE), "expected lit")
	end,

	["zero direction lights nothing"] = function()
		assert(not Cone.contains(ORIGIN, Vector3.zero, Vector3.new(0, 0, -10), RANGE, HALF_ANGLE), "expected not lit")
	end,
}
