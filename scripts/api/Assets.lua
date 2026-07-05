--[[
Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.
--]]

--- @meta Assets
-- This file is for the Lua Language Server, do not require it

--- Factory for loading assets
--- @class AssetsLib
Assets = {}

--- Loads a mesh from your game's `assets/models/`
--- You may also choose meshes from folders. (ex. `guns/pistol/bullet.obj`)
--- @param meshPath string
--- @return MeshData
function Assets.loadMesh(meshPath) end

--- Loads an image from your game's `assets/images/`
--- You may also choose images from folders. (ex. `guns/pistol/icon.bmp`)
--- @param imagePath string
--- @return ImageData
function Assets.loadImage(imagePath) end

--- Loads an audio from your game's `assets/audios/`
--- You may also choose audios from folders. (ex. `guns/pistol/shoot.wav`)
--- @param audioPath string
--- @return AudioData
function Assets.loadAudio(audioPath) end
