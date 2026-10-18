--[[
	Builds the lobby and one arena per pad, and sets the dusk lighting.

	Arenas are copies of ServerStorage.ArenaMap, which Rojo syncs from assets/ArenaMap.rbxmx.
	It is a Model centred on the origin, containing parts named "SeekerSpawn" and "HiderSpawn"
	(as many hider spawns as you like). Those spawn parts are hidden when the game starts. The
	map needs its own walls to keep players in. Without a usable ServerStorage.ArenaMap, arenas
	fall back to the neighborhood built in code by ArenaMap.luau.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ArenaMap = require(script.Parent.ArenaMap)

local World = {}

local LOBBY_CENTER = Vector3.new(0, 150, 300)
local LOBBY_SIZE = Vector3.new(80, 2, 60)
-- Arenas sit side by side along X, far enough apart that one match can't see into another.
local ARENA_SPACING = 400

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
	seekerSpawn: Vector3,
	hiderSpawns: { Vector3 },
}

local arenas: { Arena } = {}

local function arenaOrigin(index: number): Vector3
	return Vector3.new((index - 1) * ARENA_SPACING, 0, 0)
end

-- Clones the Studio-built map, if there is one, and reads its spawn parts.
local function cloneCustomMap(template: Model, origin: Vector3): (Model?, Vector3?, { Vector3 })
	local model = template:Clone()
	model:PivotTo(model:GetPivot() + origin)

	local seekerSpawn: Vector3? = nil
	local hiderSpawns = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and (descendant.Name == "SeekerSpawn" or descendant.Name == "HiderSpawn") then
			local top = descendant.Position + Vector3.new(0, descendant.Size.Y / 2, 0)
			if descendant.Name == "SeekerSpawn" then
				seekerSpawn = top
			else
				table.insert(hiderSpawns, top)
			end
			descendant.Transparency = 1
			descendant.CanCollide = false
			descendant.CanQuery = false
		end
	end

	if not seekerSpawn or #hiderSpawns == 0 then
		warn(
			"[FlashlightTag] ServerStorage.ArenaMap needs a SeekerSpawn and at least one HiderSpawn part; using the built-in map"
		)
		model:Destroy()
		return nil, nil, {}
	end
	return model, seekerSpawn, hiderSpawns
end

local function buildArena(parent: Instance, index: number)
	local origin = arenaOrigin(index)
	local template = ServerStorage:FindFirstChild("ArenaMap")

	local model: Model?, seekerSpawn: Vector3?, hiderSpawns: { Vector3 } = nil, nil, {}
	if template and template:IsA("Model") then
		model, seekerSpawn, hiderSpawns = cloneCustomMap(template, origin)
	end
	if not model then
		model, seekerSpawn, hiderSpawns = ArenaMap.build(origin)
	end

	local arenaModel = model :: Model
	arenaModel.Name = `Arena{index}`
	arenaModel.Parent = parent
	arenas[index] = { index = index, seekerSpawn = seekerSpawn :: Vector3, hiderSpawns = hiderSpawns }
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
	teleport(player, arena.seekerSpawn)
end

--[=[
	Sends each hider to a different spawn point, reusing them only if there are more hiders than spawns.
]=]
function World.sendToHiderSpawns(arena: Arena, hiders: { Player })
	local order = table.clone(arena.hiderSpawns)
	for i = #order, 2, -1 do
		local j = math.random(1, i)
		order[i], order[j] = order[j], order[i]
	end
	for index, hider in hiders do
		local spawnPoint = order[(index - 1) % #order + 1]
		teleport(hider, spawnPoint)
	end
end

function World.arena(index: number): Arena
	return arenas[index]
end

return World
