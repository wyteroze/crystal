-- Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

local input = require("@input")

-- Util --

-- Bool to number
local function btn(bool)
    return if bool then 1 else 0
end

-- TODO: Make these engine functions in the future
-- pitch = x, yaw = y, roll = z

local function rotToRightVector(rot: Vec3): Vec3
    local pitch = math.rad(rot.X)
    local yaw = math.rad(rot.Y)
    local roll = math.rad(rot.Z)

    return Vec3.new(
        math.cos(roll) * math.cos(yaw) - math.sin(roll) * math.sin(pitch) * math.sin(yaw),
        math.sin(roll) * math.cos(roll),
        -math.cos(roll) * math.sin(yaw) - math.sin(roll) * math.sin(pitch) * math.cos(yaw)
    )
end

local function rotToUpVector(rot: Vec3): Vec3
    local pitch = math.rad(rot.X)
    local yaw = math.rad(rot.Y)
    local roll = math.rad(rot.Z)

    return Vec3.new(
        math.sin(roll) * math.cos(yaw) + math.cos(roll) * math.sin(pitch) * math.sin(yaw),
        math.cos(roll) * math.cos(pitch),
        -math.sin(roll) * math.sin(yaw) + math.cos(roll) * math.sin(pitch) * math.cos(yaw)
    )
end

local function rotToForwardVector(rot: Vec3): Vec3
    local pitch = math.rad(rot.X)
    local yaw = math.rad(rot.Y)
    local _ = math.rad(rot.Z)

    return Vec3.new(
        math.cos(pitch) * math.sin(yaw),
        -math.sin(pitch),
        math.cos(pitch) * math.cos(yaw)
    )
end

local Camera = {}
Camera.__index = Camera

type Camera = typeof(Camera) & { Speed: number, _entity: Entity }

function Camera.new(entity: Entity)
    local self = setmetatable({
        Speed = 1,
        _entity = entity,
    }, Camera) :: Camera

    self:_setup()
    self._entity.Updated:Connect(function(dt) self:_step(dt) end)

    return self
end

function Camera._setup(self: Camera)
    input.Keyboards.KeyPressed:Connect(function(key)
        if key == "Escape" then
            if input.IsCursorLocked() then input.SetCursorLocked(false) end
            if not input.IsCursorVisible() then input.SetCursorVisible(true) end
        end
    end)

    input.Mice.ButtonPressed:Connect(function(btn)
        if btn == "Left" then
            if not input.IsCursorLocked() then input.SetCursorLocked(true) end
            if input.IsCursorVisible() then input.SetCursorVisible(false) end
        end
    end)

    input.Mice.Scrolled:Connect(function(delta)
        self.Speed = math.max(0, self.Speed + delta.Y)
    end)
end

function Camera._step(self: Camera, dt: number)
    local kb = input.GetKeyboard(1) :: Keyboard
    local ms = input.GetMouse(1) :: Mouse

    -- TODO: Allow vec * (or /) number 
    print(kb, ms)
    
    -- 5 m/s
    local moveX = (btn(kb:IsKeyPressed("D"))-btn(kb:IsKeyPressed("A")))*dt*self.Speed
    local moveY = (btn(kb:IsKeyPressed("Space"))-btn(kb:IsKeyPressed("LeftShift")))*dt*self.Speed
    local moveZ = (btn(kb:IsKeyPressed("W"))-btn(kb:IsKeyPressed("S")))*dt*self.Speed

    local msDelta = if input.IsCursorLocked() then ms:GetMoveDelta() else Vec2.new(0, 0)
    local rot = self._entity.Components.Rotation
        + Vec3.new(msDelta.Y, msDelta.X, 0)

    self._entity.Components.Position +=
        rotToRightVector(rot) * Vec3.new(moveX, moveX, moveX)
        + rotToUpVector(rot) * Vec3.new(moveY, moveY, moveY)
        + rotToForwardVector(rot) * Vec3.new(moveZ, moveZ, moveZ)

    self._entity.Components.Rotation = rot
end

return Camera