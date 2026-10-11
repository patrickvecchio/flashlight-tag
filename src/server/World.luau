--[[
	Builds the lobby and a blockout arena from plain parts, and sets the dusk lighting.
	This stands in for a real map until phase 4, when the arena gets built in Studio.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local World = {}

local LOBBY_CENTER = Vector3.new(0, 150, 300)
local LOBBY_SIZE = Vector3.new(80, 2, 60)
local ARENA_SIZE = 160
-- Arenas sit side by side along X, far enough apart that one match can't see into another.
local ARENA_SPACING = 400
local WALL_HEIGHT = 24

-- Cover for hiders: { size, position (centre, y = floor level), colour }.
local COVER = {
	-- Crates
	{ Vector3.new(6, 6, 6), Vector3.new(-50, 0, -40), Color3.fromRGB(120, 85, 50) },
	{ Vector3.new(6, 6, 6), Vector3.new(-44, 0, -40), Color3.fromRGB(120, 85, 50) },
	{ Vector3.new(6, 6, 6), Vector3.new(-47, 6, -40), Color3.fromRGB(120, 85, 50) },
	{ Vector3.new(8, 8, 8), Vector3.new(45, 0, 50), Color3.fromRGB(120, 85, 50) },
	{ Vector3.new(6, 6, 6), Vector3.new(52, 0, 44), Color3.fromRGB(120, 85, 50) },
	{ Vector3.new(6, 6, 6), Vector3.new(10, 0, -60), Color3.fromRGB(120, 85, 50) },
	-- Long walls
	{ Vector3.new(40, 12, 2), Vector3.new(0, 0, 20), Color3.fromRGB(90, 90, 100) },
	{ Vector3.new(2, 12, 36), Vector3.new(-25, 0, 50), Color3.fromRGB(90, 90, 100) },
	{ Vector3.new(2, 12, 36), Vector3.new(30, 0, -30), Color3.fromRGB(90, 90, 100) },
	{ Vector3.new(30, 12, 2), Vector3.new(-45, 0, 0), Color3.fromRGB(90, 90, 100) },
	{ Vector3.new(30, 12, 2), Vector3.new(55, 0, 10), Color3.fromRGB(90, 90, 100) },
	-- Shed: three walls and a roof, open on the south side
	{ Vector3.new(24, 10, 1), Vector3.new(-50, 0, 62), Color3.fromRGB(100, 70, 60) },
	{ Vector3.new(1, 10, 16), Vector3.new(-62, 0, 54), Color3.fromRGB(100, 70, 60) },
	{ Vector3.new(1, 10, 16), Vector3.new(-38, 0, 54), Color3.fromRGB(100, 70, 60) },
	{ Vector3.new(26, 1, 18), Vector3.new(-50, 10, 54), Color3.fromRGB(70, 50, 45) },
	-- Pillars
	{ Vector3.new(4, 16, 4), Vector3.new(-15, 0, -20), Color3.fromRGB(110, 110, 120) },
	{ Vector3.new(4, 16, 4), Vector3.new(15, 0, -20), Color3.fromRGB(110, 110, 120) },
	{ Vector3.new(4, 16, 4), Vector3.new(60, 0, -60), Color3.fromRGB(110, 110, 120) },
	{ Vector3.new(4, 16, 4), Vector3.new(-60, 0, -65), Color3.fromRGB(110, 110, 120) },
}

local HIDER_SPAWNS = {
	Vector3.new(-60, 0, -55),
	Vector3.new(60, 0, -45),
	Vector3.new(-60, 0, 30),
	Vector3.new(65, 0, 65),
	Vector3.new(0, 0, 65),
	Vector3.new(-10, 0, -65),
	Vector3.new(40, 0, 25),
	Vector3.new(-30, 0, -15),
}

local SEEKER_SPAWN = Vector3.new(0, 0, 0)

local function part(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

export type Arena = {
	index: number,
	origin: Vector3,
}

local function arenaOrigin(index: number): Vector3
	return Vector3.new((index - 1) * ARENA_SPACING, 0, 0)
end

local function buildArena(parent: Instance, index: number)
	local origin = arenaOrigin(index)
	local arena = Instance.new("Model")
	arena.Name = `Arena{index}`

	local floorTop = 1
	part({
		Name = "Floor",
		Size = Vector3.new(ARENA_SIZE, 1, ARENA_SIZE),
		Position = origin + Vector3.new(0, floorTop - 0.5, 0),
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(45, 70, 40),
	}, arena)

	local half = ARENA_SIZE / 2
	local wallY = floorTop + WALL_HEIGHT / 2
	for _, wall in
		{
			{ Vector3.new(ARENA_SIZE, WALL_HEIGHT, 2), Vector3.new(0, wallY, -half) },
			{ Vector3.new(ARENA_SIZE, WALL_HEIGHT, 2), Vector3.new(0, wallY, half) },
			{ Vector3.new(2, WALL_HEIGHT, ARENA_SIZE), Vector3.new(-half, wallY, 0) },
			{ Vector3.new(2, WALL_HEIGHT, ARENA_SIZE), Vector3.new(half, wallY, 0) },
		}
	do
		part({
			Name = "BoundaryWall",
			Size = wall[1],
			Position = origin + wall[2],
			Material = Enum.Material.Brick,
			Color = Color3.fromRGB(70, 60, 60),
		}, arena)
	end

	local cover = Instance.new("Folder")
	cover.Name = "Cover"
	cover.Parent = arena
	for _, item in COVER do
		local size: Vector3, base: Vector3, color: Color3 = item[1], item[2], item[3]
		part({
			Name = "Cover",
			Size = size,
			Position = origin + Vector3.new(base.X, floorTop + base.Y + size.Y / 2, base.Z),
			Material = Enum.Material.Wood,
			Color = color,
		}, cover)
	end

	arena.Parent = parent
end

local function buildLobby(parent: Instance)
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"

	part({
		Name = "Floor",
		Size = LOBBY_SIZE,
		Position = LOBBY_CENTER - Vector3.new(0, 1, 0),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(60, 60, 75),
	}, lobby)

	for _, rail in
		{
			{ Vector3.new(LOBBY_SIZE.X, 6, 1), Vector3.new(0, 3, -LOBBY_SIZE.Z / 2) },
			{ Vector3.new(LOBBY_SIZE.X, 6, 1), Vector3.new(0, 3, LOBBY_SIZE.Z / 2) },
			{ Vector3.new(1, 6, LOBBY_SIZE.Z), Vector3.new(-LOBBY_SIZE.X / 2, 3, 0) },
			{ Vector3.new(1, 6, LOBBY_SIZE.Z), Vector3.new(LOBBY_SIZE.X / 2, 3, 0) },
		}
	do
		part({
			Name = "Rail",
			Size = rail[1],
			Position = LOBBY_CENTER + rail[2],
			Transparency = 0.6,
			Color = Color3.fromRGB(150, 150, 200),
		}, lobby)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = LOBBY_CENTER + Vector3.new(0, 0.5, 18)
	spawn.Color = Color3.fromRGB(90, 90, 140)
	spawn.Parent = lobby

	local light = Instance.new("PointLight")
	light.Range = 40
	light.Brightness = 1
	light.Parent = spawn

	lobby.Parent = parent
end

local function applyDusk()
	local dusk = Config.Dusk
	Lighting.ClockTime = dusk.ClockTime
	Lighting.Brightness = dusk.Brightness
	Lighting.Ambient = dusk.Ambient
	Lighting.OutdoorAmbient = dusk.OutdoorAmbient
	Lighting.FogColor = dusk.FogColor
	Lighting.FogEnd = dusk.FogEnd
end

--[=[
	Where pad `index` of `count` sits on the lobby floor, spaced evenly across the north side.
]=]
function World.padPosition(index: number, count: number): Vector3
	local spacing = LOBBY_SIZE.X / (count + 1)
	local x = -LOBBY_SIZE.X / 2 + spacing * index
	return LOBBY_CENTER + Vector3.new(x, 0, -10)
end

function World.lobbyFolder(): Instance
	return workspace:WaitForChild("FlashlightTag"):WaitForChild("Lobby")
end

function World.build(arenaCount: number)
	-- Only our lobby spawn should place players, so turn off any spawns the place already had
	-- (a new Baseplate comes with one in the middle of where the arena goes).
	for _, existing in workspace:GetDescendants() do
		if existing:IsA("SpawnLocation") then
			existing.Enabled = false
		end
	end

	local root = Instance.new("Folder")
	root.Name = "FlashlightTag"
	for index = 1, arenaCount do
		buildArena(root, index)
	end
	buildLobby(root)
	root.Parent = workspace

	applyDusk()
end

local function teleport(player: Player, position: Vector3)
	local character = player.Character
	if character then
		character:PivotTo(CFrame.new(position + Vector3.new(0, 4, 0)))
	end
end

function World.sendToLobby(player: Player)
	local offset = Vector3.new(math.random(-20, 20), 0, math.random(8, 24))
	teleport(player, LOBBY_CENTER + offset)
end

function World.sendToSeekerSpawn(arena: Arena, player: Player)
	teleport(player, arena.origin + SEEKER_SPAWN + Vector3.new(0, 1, 0))
end

--[=[
	Sends each hider to a different spawn point, reusing them only if there are more hiders than spawns.
]=]
function World.sendToHiderSpawns(arena: Arena, hiders: { Player })
	local order = table.clone(HIDER_SPAWNS)
	for i = #order, 2, -1 do
		local j = math.random(1, i)
		order[i], order[j] = order[j], order[i]
	end
	for index, hider in hiders do
		local spawnPoint = order[(index - 1) % #order + 1]
		teleport(hider, arena.origin + spawnPoint + Vector3.new(0, 1, 0))
	end
end

function World.arena(index: number): Arena
	return { index = index, origin = arenaOrigin(index) }
end

return World
