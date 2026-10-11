local EffectsController = require(script.Parent.EffectsController)
local FlashlightController = require(script.Parent.FlashlightController)
local HudController = require(script.Parent.HudController)
local LightingController = require(script.Parent.LightingController)

LightingController.start()
FlashlightController.start()
EffectsController.start()
HudController.start()

print("[FlashlightTag] Client started")
