--[[
Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.
--]]

--- @meta Vec3
-- This file is for the Lua Language Server, do not require it

--- Represents a 3D vector
--- @class Vec3
--- @field x number
--- @field y number
--- @field z number
--- @field add fun(self: Vec3, addend: Vec3)
--- @field subtract fun(self: Vec3, subtrahend: Vec3)
--- @field multiply fun(self: Vec3, multiplier: Vec3)
--- @field divide fun(self: Vec3, divisor: Vec3)

--- Factory for creating Vec3s
--- @class Vec3Lib
Vec3 = {}

--- Returns a new Vec3
--- @param x number
--- @param y number
--- @param z number
--- @return Vec3
function Vec3.new(x, y, z) end
