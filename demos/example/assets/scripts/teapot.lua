--[[
Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.
--]]

local cmath = require("core.math")
local assets = require("assets")
local input = require("input")

local Teapot = {}
Teapot.__index = Teapot

function Teapot.new(entity)
    local self = setmetatable({
        Multiplier = 1,
        _entity = entity,
        _timer = 0,
        _lastFlicker = 0,
        _ogParent = entity.Parent
    }, Teapot)

    entity:AddComponent("Position", cmath.Vec3.new(0, 0, -5))
    entity:AddComponent("Rotation", cmath.Vec3.new(0, 0, 0))
    entity:AddComponent("Mesh", assets.load("assets://models/cube.fbx"))
    entity:AddComponent("Image", assets.load("assets://images/chicken.jpg"))

    entity.Events.Updated:Connect(function(dt)
        self._timer = self._timer + dt
        local toAdd = self.Multiplier * dt
        local add = cmath.Vec3.new(toAdd * 5, toAdd * 10, toAdd * 20)
        
        self._entity.Components.Rotation = self._entity.Components.Rotation + add
    end)

    entity.Events.Destroyed:Connect(function()
        print(("%s is being destroyed!"):format(self._entity.Name))
    end)
    
    return self
end

return Teapot