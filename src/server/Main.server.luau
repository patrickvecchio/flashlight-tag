local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Flashlight = require(script.Parent.Flashlight)
local RoundService = require(script.Parent.RoundService)
local World = require(script.Parent.World)

Remotes.create()
World.build()
Flashlight.init()
RoundService.start()

print("[FlashlightTag] Server started")
