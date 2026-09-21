-- Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

local cmath = require("core.math")
local input = require("input")

-- Util --

-- Bool to number
local function btn(bool)
    return bool and 1 or 0
end

-- TODO: Make these engine functions in the future
-- pitch = x, yaw = y, roll = z

local function rotToRightVector(rot)
    local pitch = math.rad(rot.X)
    local yaw = math.rad(rot.Y)
    local roll = math.rad(rot.Z)

    return cmath.Vec3.new(
        math.cos(roll) * math.cos(yaw) - math.sin(roll) * math.sin(pitch) * math.sin(yaw),
        math.sin(roll) * math.cos(roll),
        -math.cos(roll) * math.sin(yaw) - math.sin(roll) * math.sin(pitch) * math.cos(yaw)
    )
end

local function rotToUpVector(rot)
    local pitch = math.rad(rot.X)
    local yaw = math.rad(rot.Y)
    local roll = math.rad(rot.Z)

    return cmath.Vec3.new(
        math.sin(roll) * math.cos(yaw) + math.cos(roll) * math.sin(pitch) * math.sin(yaw),
        math.cos(roll) * math.cos(pitch),
        -math.sin(roll) * math.sin(yaw) + math.cos(roll) * math.sin(pitch) * math.cos(yaw)
    )
end

local function rotToForwardVector(rot)
    local pitch = math.rad(rot.X)
    local yaw = math.rad(rot.Y)
    local roll = math.rad(rot.Z)

    return cmath.Vec3.new(
        math.cos(pitch) * math.sin(yaw),
        -math.sin(pitch),
        math.cos(pitch) * math.cos(yaw)
    )
end

local Camera = {}
Camera.__index = Camera

function Camera.new(entity)
    local self = setmetatable({
        _entity = entity,
        Speed = 1
    }, Camera)

    entity.Events.Updated:Connect(function(dt) 
        self:_step(dt)
    end)

    self:_setup()

    return self
end

function Camera:_setup()
    input.Keyboards.KeyPressed:Connect(function(key)
        if key == "Escape" then
            if input.CursorLocked then input.CursorLocked = false end
            if not input.CursorVisible then input.CursorVisible = true end
        end
    end)

    input.Mice.ButtonPressed:Connect(function(btn)
        if btn == "Left" then
            if not input.CursorLocked then input.CursorLocked = true end
            if input.CursorVisible then input.CursorVisible = false end
        end
    end)
end

function Camera:_step(dt)
    local kb = input:GetKeyboard(1)
    local ms = input:GetMouse(1)

    -- TODO: Allow vec * (or /) number 
    
    local moveX = (btn(kb:IsKeyPressed("D"))-btn(kb:IsKeyPressed("A")))/10
    local moveY = (btn(kb:IsKeyPressed("Space"))-btn(kb:IsKeyPressed("LeftShift")))/10
    local moveZ = (btn(kb:IsKeyPressed("S"))-btn(kb:IsKeyPressed("W")))/10
    
    local msDelta = ms:GetDelta()
    local rot = self._entity.Components.Rotation
        + cmath.Vec3.new(-msDelta.Y, -msDelta.X, 0)

    local pos = self._entity.Components.Position
        + rotToRightVector(rot) * cmath.Vec3.new(moveX, moveX, moveX)
        + rotToUpVector(rot) * cmath.Vec3.new(moveY, moveY, moveY)
        + rotToForwardVector(rot) * cmath.Vec3.new(moveZ, moveZ, moveZ)

    self._entity.Components.Position = pos
    self._entity.Components.Rotation = rot
end

return Camera