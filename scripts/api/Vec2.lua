--[[
Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.
--]]

--- @meta Vec2
-- This file is for the Lua Language Server, do not require it

--- Represents a 2D vector
--- @class Vec2
--- @field X number
--- @field Y number
--- Adds `addend` to this vector in place. Equivalent to `+=` in other languages, but Lua doesn't have this.
--- @field Add fun(self: Vec2, addend: Vec2)
---
--- Subtracts `subtrahend` to this vector in place. Equivalent to `-=` in other languages, but Lua doesn't have this.
--- @field Sub fun(self: Vec2, subtrahend: Vec2)
---
--- Multiplies this vector by `multiplier` in place. Equivalent to `*=` in other languages, but Lua doesn't have this.
--- @field Mul fun(self: Vec2, multiplier: Vec2)
---
--- Divides this vector by `divisor` in place. Equivalent to `/=` in other languages, but Lua doesn't have this.
--- @field Div fun(self: Vec2, divisor: Vec2)

--- Factory for creating Vec2s
--- @class Vec2Lib
Vec2 = {}

--- Returns a new Vec2
--- @param x number
--- @param y number
--- @return Vec2
function Vec2.new(x, y) end
