--[[
	Pure math for the flashlight beam: is a point inside the cone?
	No Roblox services here, so it can be unit tested outside Studio.
]]

local Cone = {}

--[=[
	Returns true when `target` is within `range` of `origin` and no more than
	`halfAngleDegrees` away from `direction`.
]=]
function Cone.contains(
	origin: Vector3,
	direction: Vector3,
	target: Vector3,
	range: number,
	halfAngleDegrees: number
): boolean
	local offset = target - origin
	local distance = offset.Magnitude
	if distance > range then
		return false
	end
	if distance < 1e-6 then
		return true
	end
	if direction.Magnitude < 1e-6 then
		return false
	end

	local cosAngle = direction.Unit:Dot(offset / distance)
	return cosAngle >= math.cos(math.rad(halfAngleDegrees))
end

return Cone
