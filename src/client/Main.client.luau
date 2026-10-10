local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

Remotes.get(Remotes.Events.RoleAssigned)

print(`[FlashlightTag] Client started for {Players.LocalPlayer.Name}`)
