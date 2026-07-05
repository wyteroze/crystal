--[[
    Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.
    --]]

--- @meta Scene
-- This file is for the Lua Language Server, do not require it

--- Represents a collection of objects, and has
--- other responsibilities.
--- @class Scene
---
--- Objects under the scene.
--- @field Objects Object[]
--- Audios under the scene.
--- @field Audios Audio[]
---
--- The camera that's used to render the scene.
--- @field Camera? Camera
---
--- The image data that will be used for the skybox's texture. It expects a cubemap texture, otherwise the skybox may look bugged.
--- @field SkyboxTexture? ImageData
---
--- "Attaches" a function to the scene's update event.
--- This function will be called every time the scene updates,
--- unless detached by calling the returned function once.
--- @field OnUpdate fun(self: Scene, callback: fun(delta: number)): fun()
---
--- Adds an object to the scene's Objects list, making it visible. Does nothing if the object is already in the scene.
--- @field AddObject fun(self: Scene, object: Object)
---
--- Removes an object from the scene. Does nothing if the object isn't in the scene.
--- @field RemoveObject fun(self: Scene, object: Object)
---
--- Adds an audio to the scene's Audios list, making it audible. Does nothing if the audio is already in the scene.
--- @field AddAudio fun(self: Scene, audio: Audio)
---
--- Removes an audio from the scene. Does nothing if the audio isn't in the scene.
--- @field RemoveAudio fun(self: Scene, audio: Audio)

--- Factory for creating and managing scenes
--- @class SceneLib
---
--- The scene that will be rendered. You may only have one scene enabled at any time. Set to nil to render nothing.
--- @field CurrentScene Scene?
Scene = {}

--- Returns a new Scene
--- @param name? string
--- @return Scene
function Scene.new(name) end
