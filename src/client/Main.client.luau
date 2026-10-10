local FlashlightController = require(script.Parent.FlashlightController)
local HudController = require(script.Parent.HudController)
local LightingController = require(script.Parent.LightingController)

LightingController.start()
FlashlightController.start()
HudController.start()

print("[FlashlightTag] Client started")
