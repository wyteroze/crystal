--[[
Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.
--]]

--- @meta Vec3
-- This file is for the Lua Language Server, do not require it

--- Represents a 3D vector
--- @class Vec3
--- @field X number
--- @field Y number
--- @field Z number
---
--- Adds `addend` to this vector in place. Similar to `+=` in other languages, but Lua doesn't have this.
--- @field Add fun(self: Vec3, addend: Vec3)
---
--- Subtracts `subtrahend` to this vector in place. Similar to `-=` in other languages, but Lua doesn't have this.
--- @field Sub fun(self: Vec3, subtrahend: Vec3)
---
--- Multiplies this vector by `multiplier` in place. Similar to `*=` in other languages, but Lua doesn't have this.
--- @field Mul fun(self: Vec3, multiplier: Vec3)
---
--- Divides this vector by `divisor` in place. Similar to `/=` in other languages, but Lua doesn't have this.
--- @field Div fun(self: Vec3, divisor: Vec3)

--- Factory for creating Vec3s
--- @class Vec3Lib
Vec3 = {}

--- Returns a new Vec3
--- @param x number
--- @param y number
--- @param z number
--- @return Vec3
function Vec3.new(x, y, z) end
