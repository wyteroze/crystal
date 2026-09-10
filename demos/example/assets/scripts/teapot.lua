--[[
Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.
--]]

local cmath = require("core.math")
local assets = require("assets")

local Teapot = {}
Teapot.__index = Teapot

function Teapot.new(entity)
    local self = setmetatable({
        Multiplier = 1,
        entity = entity,
        timer = 0,
        lastFlicker = 0,
        ogParent = entity.Parent
    }, Teapot)

    self.entity:AddComponent("Position", cmath.Vec3.new(0, 0, -5))
    self.entity:AddComponent("Rotation", cmath.Vec3.new(0, 0, 0))
    self.entity:AddComponent("Mesh", assets.load("assets://models/cube.fbx"))
    self.entity:AddComponent("Image", assets.load("assets://images/chicken.jpg"))

    return self
end

function Teapot:OnUpdate(dt)
    self.timer = self.timer + dt
    local toAdd = self.Multiplier * dt
    local add = cmath.Vec3.new(toAdd * 5, toAdd * 10, toAdd * 20)
    
    self.entity.Components.Rotation = self.entity.Components.Rotation + add
end

function Teapot:OnDestroy()
    print(("%s is being destroyed!"):format(self.entity.Name))
end

return Teapot