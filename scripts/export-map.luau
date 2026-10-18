--[[
	Writes the built-in neighborhood (src/server/ArenaMap.luau) to assets/ArenaMap.rbxmx, with
	SeekerSpawn and HiderSpawn parts added, as a starting point for editing the map in Studio.

	Run it with `lune run scripts/export-map`. It overwrites assets/ArenaMap.rbxmx, so only run
	it when you want to start over from the built-in map.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local SOURCE = "src/server/ArenaMap.luau"
local OUTPUT = "assets/ArenaMap.rbxmx"

-- ArenaMap.luau uses Roblox globals, so load it with Lune's versions of them
local environment = setmetatable({
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	Enum = roblox.Enum,
}, { __index = _G })
local ArenaMap = luau.load(fs.readFile(SOURCE), { debugName = SOURCE, environment = environment })()

local model, seekerSpawn, hiderSpawns = ArenaMap.build(roblox.Vector3.new(0, 0, 0))
model.Name = "ArenaMap"

-- A spawn's top face is where players stand, so sit each marker just under the spawn point
local function marker(name: string, position, color)
	local part = roblox.Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.Size = roblox.Vector3.new(4, 0.2, 4)
	part.CFrame = roblox.CFrame.new(position - roblox.Vector3.new(0, 0.1, 0))
	part.Color = color
	part.Material = roblox.Enum.Material.Neon
	part.Parent = model
end

marker("SeekerSpawn", seekerSpawn, roblox.Color3.fromRGB(220, 60, 60))
for _, spawn in hiderSpawns do
	marker("HiderSpawn", spawn, roblox.Color3.fromRGB(60, 140, 220))
end

fs.writeFile(OUTPUT, roblox.serializeModel({ model }, true))
print(`Wrote {OUTPUT}: {#model:GetDescendants()} instances, {#hiderSpawns} hider spawns`)
