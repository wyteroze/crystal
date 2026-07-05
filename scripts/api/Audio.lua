--[[
Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.
--]]

--- @meta Audio
-- This file is for the Lua Language Server, do not require it

--- Represents a sound in your game.
--- @class Audio
--- The volume of the sound. Ranges from 0-10 with 1 being the default.
--- @field Volume number
--- The time that the audio is at. Never exceeds the audio's length, and never goes below 0.
--- @field Time number
--- The length of the audio. You can not set this, it is purely read-only.
--- @field Length number
--- Whether or not the audio loops once it finishes.
--- @field Loops boolean
--- The object the audio is attached to. You can not set this, use AttachTo instead.
--- @field AttachedTo Object?
--- Determines whether or not the audio is playing. If not, the Time field stays frozen and the audio is not audible.
--- Regardless of what this field is set to, the Time field is always frozen and the audio is never audible if the scene it's under is not the current visible scene.
--- @field Playing boolean
--- Attach the audio to an object. The audio will exist in 3D space and get louder/quieter based on your position relative to the attached object's position, unlike an audio attached to nothing.
--- Pass nil as the first argument to detach it from any object.
--- @field AttachTo fun(self: Audio, object: Object?)

--- Library relating to various audio-related things
--- @class AudioLib
Audio = {}

--- Creates a new Audio. You must add it to a scene to hear it.
--- @param audioData AudioData
--- @return Audio
function Audio.new(audioData) end
