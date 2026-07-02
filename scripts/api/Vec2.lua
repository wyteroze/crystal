--[[
Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.
--]]

--- @meta Vec2
-- This file is for the Lua Language Server, do not require it

--- Represents a 2D vector
--- @class Vec2
--- @field x number
--- @field y number
--- @field add fun(self: Vec2, addend: Vec2)
--- @field subtract fun(self: Vec2, subtrahend: Vec2)
--- @field multiply fun(self: Vec2, multiplier: Vec2)
--- @field divide fun(self: Vec2, divisor: Vec2)

--- Factory for creating Vec2s
--- @class Vec2Lib
Vec2 = {}

--- Returns a new Vec2
--- @param x number
--- @param y number
--- @return Vec2
function Vec2.new(x, y, z) end
