--[[
    Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.
    --]]

--- @meta Scene
-- This file is for the Lua Language Server, do not require it

--- Represents a collection of objects, and has
--- other responsibilities.
--- @class Scene
--- @field Objects Object[]
--- @field Camera? Camera
---
--- "Attaches" a function to the scene's update event.
--- This function will be called every time the scene updates,
--- unless detached by calling the returned `detach` function once.
--- @field OnUpdate fun(self: Scene, callback: fun(delta: number)): fun()
---
--- Adds an object to the scene's Objects list, making it visible. Does nothing if the object is already in the scene.
--- @field AddObject fun(self: Scene, object: Object)
---
--- Removes an object from the scene. Does nothing if the object isn't in the scene.
--- @field RemoveObject fun(self: Scene, object: Object)

--- Factory for creating scenes
--- @class SceneLib
Scene = {}

--- Returns a new Scene
--- @param name? string
--- @return Scene
function Scene.new(name) end
