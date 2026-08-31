-- Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

local Camera = {}
Camera.__index = Camera

function Camera.new(entity)
    local self = setmetatable({

    }, Camera)

    return self
end

function Camera:OnUpdate(dt)
    
end

function Camera:OnDestroy()
    
end