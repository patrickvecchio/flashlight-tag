local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Flashlight = require(script.Parent.Flashlight)
local Match = require(script.Parent.Match)
local QueueService = require(script.Parent.QueueService)
local World = require(script.Parent.World)

Remotes.create()
World.build(Config.Queue.Pads)
Flashlight.init()
Match.init()
QueueService.start(Match.run)

print("[FlashlightTag] Server started")
