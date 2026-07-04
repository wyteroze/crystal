--[[
Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.
--]]

local camera = Object.camera();
local myScene = Scene.new("Test scene")
myScene.Camera = camera
camera.Position = Vec3.new(0, 0, -10)
camera.Rotation = Vec3.new(0, 0, 0)

Scene.CurrentScene = myScene

local bullyMoonMesh = Assets.loadMesh("bullymoon.obj")
local bullyMoonTex = Assets.loadImage("bullymoon.bmp")
local bullyMoon = Object.mesh(bullyMoonMesh, bullyMoonTex)
bullyMoon.Position = Vec3.new(-5, 0, 0)
myScene:AddObject(bullyMoon)

local uziMesh = Assets.loadMesh("cube.obj")
local uziTex = Assets.loadImage("uzi.bmp")
local uziCube = Object.mesh(uziMesh, uziTex)
uziCube.Position = Vec3.new(5, 0, 0)
myScene:AddObject(uziCube)

print(bullyMoon.Scale, uziCube.Scale)

myScene:OnUpdate(function(dt)
    print(bullyMoon.Rotation, uziCube.Rotation)

    bullyMoon.Rotation:Add(Vec3.new(0, dt * 10, 0))
    uziCube.Rotation:Add(Vec3.new(dt * 5, dt * 10, dt * 20))
end)

print("done")
