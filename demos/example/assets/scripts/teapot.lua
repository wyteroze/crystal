--[[
Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.
--]]

local cmath = require("core.math")
local assets = require("assets")

local Teapot = {
    Multiplier = 1
}
Teapot.__index = Teapot

function Teapot.new(entity)
    local self = setmetatable({
        entity = entity
    }, Teapot)

    self.entity:SetComponents({
        Position = cmath.Vec3.new(0, 0, -5),
        Rotation = cmath.Vec3.new(0, 0, 0),
        Mesh = assets.load("asset://models/shortandstout.glb")
    })

    return self
end

function Teapot:OnUpdate(dt)
    local toAdd = self.Multiplier * dt
    local add = cmath.Vec3.new(toAdd * 5, toAdd * 10, toAdd * 20)
    
    self.entity.Components.Rotation = self.entity.Components.Rotation + add
end

function Teapot:OnDestroy()
    print(("%s is being destroyed!"):format(self.entity.Name))
end

return Teapot