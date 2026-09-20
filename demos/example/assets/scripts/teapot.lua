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

    
    input.Keyboards.Connected:Connect(function(k)
        print("Keyboard connected:", k.Id)

        local kb = input:GetKeyboard(k.Id)
        print(kb)

        kb.KeyPressed:Connect(function(key)
            print("Pressed", key)
        end)

        kb.KeyReleased:Connect(function(key)
            print("Released", key)
        end)
    end)
    input.Keyboards.Disconnected:Connect(function(kb)
        print("Keyboard disconnected:", kb)
    end)

    input.Mice.Connected:Connect(function(ms) 
        print("Mouse connected:", ms.Id)

        local ms = input:GetMouse(ms.Id)
        print(ms)

        ms.ButtonPressed:Connect(function(btn) 
            print("Pressed", btn)
        end)
        ms.ButtonReleased:Connect(function(btn) 
            print("Released", btn)
        end)
        ms.Moved:Connect(function(delta, pos)
            print("Moved delta =", delta, "pos =", pos)
        end)
        ms.Scrolled:Connect(function(delta)
            print("Scrolled", delta)
        end)
    end)

    return self
end

return Teapot