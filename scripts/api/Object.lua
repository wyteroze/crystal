--[[
Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.
--]]

--- @meta Object
-- This file is for the Lua Language Server, do not require it

--- Represents a physical *thing* in your game. Can be anything.
--- All scene objects inherit from Object.
--- @class Object
--- @field Position Vec3
--- @field Rotation Vec3
--- @field Scale Vec3

--- Factory for creating scene objects
--- @class ObjectLib
Object = {}

--- Returns a Mesh, which can be put in a scene unlike MeshData
--- @param mesh MeshData
--- @return Mesh
function Object.mesh(mesh) end

--- Returns an image, which can be put in a scene unlike ImageData
--- @param image ImageData
--- @return Image
function Object.image(image) end
