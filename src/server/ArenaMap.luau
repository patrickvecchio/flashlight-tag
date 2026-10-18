--[[
	The built-in arena: a small neighborhood at night, built from parts.

	Two houses with rooms, a garage, a playground, a street with parked cars, trees, hedges,
	fences and dark streetlamps, inside a walled 160 x 160 stud lot. Everything is placed
	relative to the arena's origin, so several copies can sit side by side.

	The game normally plays assets/ArenaMap.rbxmx instead (see World.luau); this is the fallback,
	and `lune run scripts/export-map` regenerates that file from it.
]]

local ArenaMap = {}

local SIZE = 160
local BOUNDARY_HEIGHT = 24
local FLOOR_TOP = 1

local COLORS = {
	Grass = Color3.fromRGB(45, 70, 40),
	Road = Color3.fromRGB(40, 40, 45),
	Sidewalk = Color3.fromRGB(110, 110, 115),
	Boundary = Color3.fromRGB(70, 60, 60),
	HouseA = Color3.fromRGB(150, 130, 110),
	HouseB = Color3.fromRGB(110, 125, 145),
	Roof = Color3.fromRGB(60, 45, 40),
	Floor = Color3.fromRGB(95, 75, 55),
	Garage = Color3.fromRGB(130, 130, 125),
	Furniture = Color3.fromRGB(120, 90, 70),
	Trunk = Color3.fromRGB(80, 55, 35),
	Leaves = Color3.fromRGB(35, 75, 40),
	Hedge = Color3.fromRGB(30, 65, 35),
	Fence = Color3.fromRGB(125, 100, 75),
	Metal = Color3.fromRGB(70, 70, 75),
	Play = Color3.fromRGB(170, 70, 60),
	Sand = Color3.fromRGB(190, 170, 120),
	CarRed = Color3.fromRGB(130, 35, 35),
	CarBlue = Color3.fromRGB(40, 60, 120),
	Glass = Color3.fromRGB(30, 35, 45),
}

-- Open ground where hiders start, as (x, z) offsets from the arena's centre.
local HIDER_SPAWNS = {
	Vector3.new(-60, 0, -20),
	Vector3.new(60, 0, -20),
	Vector3.new(0, 0, -45),
	Vector3.new(-5, 0, 70),
	Vector3.new(65, 0, 70),
	Vector3.new(-70, 0, 70),
	Vector3.new(30, 0, -70),
	Vector3.new(-30, 0, 20),
}

local SEEKER_SPAWN = Vector3.new(0, 0, 0)

type Builder = {
	model: Model,
	origin: Vector3,
}

-- Adds an anchored part. `base` is the (x, z) centre with y measured up from the floor,
-- so `base.Y = 0` puts the part's bottom on the ground.
local function block(
	b: Builder,
	name: string,
	size: Vector3,
	base: Vector3,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Position = b.origin + Vector3.new(base.X, FLOOR_TOP + base.Y + size.Y / 2, base.Z)
	p.Parent = b.model
	return p
end

type Gap = { center: number, width: number }

--[=[
	A straight wall from `from` to `to` along one axis, skipping each gap (a doorway 8 studs
	tall with a lintel above it). `axis` is "X" (wall runs along X at z = `fixed`) or "Z".
]=]
local function wall(
	b: Builder,
	axis: string,
	fixed: number,
	from: number,
	to: number,
	height: number,
	gaps: { Gap },
	color: Color3
)
	local thickness = 1
	local doorHeight = 8
	local function segment(a: number, c: number, y: number, h: number)
		if c - a < 0.05 then
			return
		end
		local mid = (a + c) / 2
		local length = c - a
		if axis == "X" then
			block(b, "Wall", Vector3.new(length, h, thickness), Vector3.new(mid, y, fixed), color)
		else
			block(b, "Wall", Vector3.new(thickness, h, length), Vector3.new(fixed, y, mid), color)
		end
	end

	table.sort(gaps, function(g1, g2)
		return g1.center < g2.center
	end)
	local cursor = from
	for _, gap in gaps do
		local gapStart = gap.center - gap.width / 2
		local gapEnd = gap.center + gap.width / 2
		segment(cursor, gapStart, 0, height)
		segment(gapStart, gapEnd, doorHeight, height - doorHeight)
		cursor = gapEnd
	end
	segment(cursor, to, 0, height)
end

--[=[
	A house of two rooms: doors on both long sides and one between the rooms, a flat roof,
	and some furniture to hide behind.
]=]
local function house(b: Builder, cx: number, cz: number, width: number, depth: number, color: Color3)
	local height = 12
	local x1, x2 = cx - width / 2, cx + width / 2
	local z1, z2 = cz - depth / 2, cz + depth / 2

	block(
		b,
		"HouseFloor",
		Vector3.new(width, 0.2, depth),
		Vector3.new(cx, 0, cz),
		COLORS.Floor,
		Enum.Material.WoodPlanks
	)
	wall(b, "X", z1, x1, x2, height, { { center = cx + width / 4, width = 6 } }, color)
	wall(b, "X", z2, x1, x2, height, { { center = cx - width / 4, width = 6 } }, color)
	wall(b, "Z", x1, z1, z2, height, {}, color)
	wall(b, "Z", x2, z1, z2, height, {}, color)
	wall(b, "Z", cx, z1 + 0.5, z2 - 0.5, height, { { center = cz, width = 5 } }, color)
	block(
		b,
		"Roof",
		Vector3.new(width + 2, 1, depth + 2),
		Vector3.new(cx, height, cz),
		COLORS.Roof,
		Enum.Material.Slate
	)

	-- West room: a bed and a wardrobe. East room: a table and a sofa.
	block(b, "Bed", Vector3.new(6, 2.5, 9), Vector3.new(x1 + 4.5, 0, z1 + 6), COLORS.Furniture, Enum.Material.Fabric)
	block(b, "Wardrobe", Vector3.new(5, 9, 2.5), Vector3.new(cx - 3, 0, z2 - 2), COLORS.Furniture, Enum.Material.Wood)
	block(b, "Table", Vector3.new(6, 3, 4), Vector3.new(cx + width / 4, 0, cz), COLORS.Furniture, Enum.Material.Wood)
	block(b, "Sofa", Vector3.new(9, 3.5, 3), Vector3.new(x2 - 6, 0, z2 - 3), COLORS.Furniture, Enum.Material.Fabric)
end

local function garage(b: Builder, cx: number, cz: number)
	local width, depth, height = 22, 18, 10
	local x1, x2 = cx - width / 2, cx + width / 2
	local z1, z2 = cz - depth / 2, cz + depth / 2
	wall(b, "X", z1, x1, x2, height, {}, COLORS.Garage)
	wall(b, "Z", x1, z1, z2, height, {}, COLORS.Garage)
	wall(b, "Z", x2, z1, z2, height, {}, COLORS.Garage)
	block(
		b,
		"Roof",
		Vector3.new(width + 2, 1, depth + 2),
		Vector3.new(cx, height, cz),
		COLORS.Roof,
		Enum.Material.Metal
	)
	block(b, "Shelves", Vector3.new(2, 7, 10), Vector3.new(x2 - 2, 0, cz - 2), COLORS.Metal, Enum.Material.Metal)
	block(b, "Workbench", Vector3.new(8, 3.5, 3), Vector3.new(cx - 4, 0, z1 + 2), COLORS.Furniture, Enum.Material.Wood)
end

local function car(b: Builder, cx: number, cz: number, color: Color3)
	block(b, "CarBody", Vector3.new(14, 3, 6), Vector3.new(cx, 1, cz), color, Enum.Material.Metal)
	block(b, "CarCabin", Vector3.new(7, 2.5, 5.6), Vector3.new(cx - 1, 4, cz), COLORS.Glass, Enum.Material.Glass)
	for _, offset in
		{ Vector3.new(-4.5, 0, -3), Vector3.new(4.5, 0, -3), Vector3.new(-4.5, 0, 3), Vector3.new(4.5, 0, 3) }
	do
		local wheel = block(
			b,
			"Wheel",
			Vector3.new(1, 2.4, 2.4),
			Vector3.new(cx + offset.X, 0, cz + offset.Z),
			COLORS.Road,
			Enum.Material.Rubber,
			Enum.PartType.Cylinder
		)
		wheel.Orientation = Vector3.new(0, 90, 0)
	end
end

local function tree(b: Builder, x: number, z: number)
	local trunk = block(
		b,
		"Trunk",
		Vector3.new(10, 2, 2),
		Vector3.new(x, 0, z),
		COLORS.Trunk,
		Enum.Material.Wood,
		Enum.PartType.Cylinder
	)
	-- A cylinder's length runs along X; stand it up.
	trunk.Orientation = Vector3.new(0, 0, 90)
	trunk.Position = b.origin + Vector3.new(x, FLOOR_TOP + 5, z)
	block(
		b,
		"Leaves",
		Vector3.new(12, 12, 12),
		Vector3.new(x, 7, z),
		COLORS.Leaves,
		Enum.Material.Grass,
		Enum.PartType.Ball
	)
end

local function hedge(b: Builder, x: number, z: number, lengthX: number, lengthZ: number)
	block(b, "Hedge", Vector3.new(lengthX, 4, lengthZ), Vector3.new(x, 0, z), COLORS.Hedge, Enum.Material.Grass)
end

local function fence(b: Builder, axis: string, fixed: number, from: number, to: number, gaps: { Gap })
	local height = 5
	local function segment(a: number, c: number)
		if c - a < 0.05 then
			return
		end
		if axis == "X" then
			block(
				b,
				"Fence",
				Vector3.new(c - a, height, 0.5),
				Vector3.new((a + c) / 2, 0, fixed),
				COLORS.Fence,
				Enum.Material.WoodPlanks
			)
		else
			block(
				b,
				"Fence",
				Vector3.new(0.5, height, c - a),
				Vector3.new(fixed, 0, (a + c) / 2),
				COLORS.Fence,
				Enum.Material.WoodPlanks
			)
		end
	end
	local cursor = from
	for _, gap in gaps do
		segment(cursor, gap.center - gap.width / 2)
		cursor = gap.center + gap.width / 2
	end
	segment(cursor, to)
end

local function streetlamp(b: Builder, x: number, z: number)
	block(b, "LampPost", Vector3.new(0.6, 14, 0.6), Vector3.new(x, 0, z), COLORS.Metal, Enum.Material.Metal)
	-- The lamps are out: that's the point.
	block(b, "LampHead", Vector3.new(2, 1, 2), Vector3.new(x, 14, z), COLORS.Glass, Enum.Material.Glass)
end

local function playground(b: Builder, cx: number, cz: number)
	-- Sandbox
	block(b, "Sand", Vector3.new(14, 0.4, 14), Vector3.new(cx + 12, 0, cz + 8), COLORS.Sand, Enum.Material.Sand)
	-- Slide tower: a platform on four posts with side walls; steps up the back, slide down the front
	local tx, tz = cx - 6, cz - 2
	for _, offset in
		{ Vector3.new(-3.5, 0, -3.5), Vector3.new(3.5, 0, -3.5), Vector3.new(-3.5, 0, 3.5), Vector3.new(3.5, 0, 3.5) }
	do
		block(
			b,
			"Post",
			Vector3.new(1, 6, 1),
			Vector3.new(tx + offset.X, 0, tz + offset.Z),
			COLORS.Play,
			Enum.Material.Metal
		)
	end
	block(b, "Platform", Vector3.new(8, 1, 8), Vector3.new(tx, 6, tz), COLORS.Play, Enum.Material.Wood)
	block(b, "TowerWall", Vector3.new(0.5, 3, 8), Vector3.new(tx - 3.75, 7, tz), COLORS.Play)
	block(b, "TowerWall", Vector3.new(0.5, 3, 8), Vector3.new(tx + 3.75, 7, tz), COLORS.Play)
	local slide =
		block(b, "Slide", Vector3.new(3, 0.5, 12), Vector3.new(tx, 3, tz + 9), COLORS.Play, Enum.Material.Metal)
	-- Tilted so the end by the tower is high and the far end is near the ground.
	slide.CFrame = CFrame.new(b.origin + Vector3.new(tx, FLOOR_TOP + 4, tz + 9)) * CFrame.Angles(math.rad(28), 0, 0)
	-- Steps up the back, highest next to the platform
	for step = 0, 5 do
		block(
			b,
			"Step",
			Vector3.new(3, 1, 1.2),
			Vector3.new(tx, step * 1.2, tz - 10.6 + step * 1.2),
			COLORS.Metal,
			Enum.Material.Metal
		)
	end
	-- A little play house with a doorway
	local px, pz = cx + 14, cz - 10
	wall(b, "X", pz - 4, px - 5, px + 5, 7, {}, COLORS.Play)
	wall(b, "X", pz + 4, px - 5, px + 5, 7, { { center = px, width = 4 } }, COLORS.Play)
	wall(b, "Z", px - 5, pz - 4, pz + 4, 7, {}, COLORS.Play)
	wall(b, "Z", px + 5, pz - 4, pz + 4, 7, {}, COLORS.Play)
	block(b, "Roof", Vector3.new(12, 1, 10), Vector3.new(px, 7, pz), COLORS.Roof)
end

--[=[
	Builds the map into a new Model centred on `origin` and returns it with the spawn points
	(in world space).
]=]
function ArenaMap.build(origin: Vector3): (Model, Vector3, { Vector3 })
	local model = Instance.new("Model")
	local b: Builder = { model = model, origin = origin }
	local half = SIZE / 2

	-- Ground, street and sidewalks
	block(b, "Ground", Vector3.new(SIZE, 1, SIZE), Vector3.new(0, -1, 0), COLORS.Grass, Enum.Material.Grass)
	block(b, "Road", Vector3.new(SIZE, 0.2, 20), Vector3.new(0, 0, 0), COLORS.Road, Enum.Material.Asphalt)
	block(b, "Sidewalk", Vector3.new(SIZE, 0.4, 4), Vector3.new(0, 0, -12), COLORS.Sidewalk, Enum.Material.Concrete)
	block(b, "Sidewalk", Vector3.new(SIZE, 0.4, 4), Vector3.new(0, 0, 12), COLORS.Sidewalk, Enum.Material.Concrete)

	-- Boundary walls
	for _, side in
		{
			{ Vector3.new(SIZE, BOUNDARY_HEIGHT, 2), Vector3.new(0, 0, -half) },
			{ Vector3.new(SIZE, BOUNDARY_HEIGHT, 2), Vector3.new(0, 0, half) },
			{ Vector3.new(2, BOUNDARY_HEIGHT, SIZE), Vector3.new(-half, 0, 0) },
			{ Vector3.new(2, BOUNDARY_HEIGHT, SIZE), Vector3.new(half, 0, 0) },
		}
	do
		block(b, "BoundaryWall", side[1], side[2], COLORS.Boundary, Enum.Material.Brick)
	end

	-- Buildings
	house(b, -42, -45, 36, 26, COLORS.HouseA)
	house(b, 42, 45, 36, 26, COLORS.HouseB)
	garage(b, 50, -45)
	car(b, 50, -46, COLORS.CarBlue)
	playground(b, -48, 50)

	-- Parked cars on the street
	car(b, -20, -4, COLORS.CarRed)
	car(b, 35, 5, COLORS.CarBlue)

	-- Trees
	for _, spot in
		{
			Vector3.new(-10, 0, -40),
			Vector3.new(12, 0, -62),
			Vector3.new(-72, 0, -20),
			Vector3.new(15, 0, -30),
			Vector3.new(5, 0, 38),
			Vector3.new(-15, 0, 62),
			Vector3.new(72, 0, 22),
			Vector3.new(-70, 0, 22),
		}
	do
		tree(b, spot.X, spot.Z)
	end

	-- Hedges and fences
	hedge(b, 0, -25, 26, 2.5)
	hedge(b, -18, -48, 2.5, 26)
	hedge(b, 20, 48, 2.5, 22)
	fence(b, "X", 30, -79, -22, { { center = -45, width = 8 } })
	fence(b, "Z", -22, 30, 79, { { center = 55, width = 6 } })

	-- Bins and crates
	block(b, "Bin", Vector3.new(3, 4, 3), Vector3.new(34, 0, -30), COLORS.Metal, Enum.Material.Metal)
	block(b, "Bin", Vector3.new(3, 4, 3), Vector3.new(38, 0, -30), COLORS.Metal, Enum.Material.Metal)
	block(b, "Crate", Vector3.new(6, 6, 6), Vector3.new(-70, 0, -70), COLORS.Furniture, Enum.Material.Wood)
	block(b, "Crate", Vector3.new(6, 6, 6), Vector3.new(-64, 0, -70), COLORS.Furniture, Enum.Material.Wood)
	block(b, "Crate", Vector3.new(6, 6, 6), Vector3.new(-67, 6, -70), COLORS.Furniture, Enum.Material.Wood)
	block(b, "Crate", Vector3.new(8, 8, 8), Vector3.new(70, 0, -70), COLORS.Furniture, Enum.Material.Wood)

	-- Streetlamps along both sidewalks
	for _, x in { -60, -20, 20, 60 } do
		streetlamp(b, x, -13)
	end
	for _, x in { -40, 0, 40 } do
		streetlamp(b, x, 13)
	end

	local hiderSpawns = {}
	for _, spot in HIDER_SPAWNS do
		table.insert(hiderSpawns, origin + Vector3.new(spot.X, FLOOR_TOP, spot.Z))
	end
	return model, origin + SEEKER_SPAWN + Vector3.new(0, FLOOR_TOP, 0), hiderSpawns
end

return ArenaMap
