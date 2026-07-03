--[[
Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.
--]]

local myScene = Scene.new()

if true then return end
local bullyMoonMesh = Assets.loadMesh("bullymoon")
local bullyMoonTex = Assets.loadImage("bullymoon")
local bullyMoon = Object.mesh(bullyMoonMesh, bullyMoonTex)
bullyMoon.Position = Vec3.new(-5, 0, 0)
myScene:AddObject(bullyMoon)

local uziMesh = Assets.loadMesh("cube")
local uziTex = Assets.loadImage("uzi")
local uziCube = Object.mesh(uziMesh, uziTex)
uziCube.Position = Vec3.new(5, 0, 0)
myScene:AddObject(uziCube)

myScene:OnUpdate(function(dt)
    bullyMoon.Rotation:Add(Vec3.new(0, dt * 10, 0))
    uziCube.Rotation:Add(Vec3.new(dt * 5, dt * 10, dt * 20))
end)
