--[[
Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.
--]]

local camera = Object.camera();
local myScene = Scene.new("Test scene")
myScene.Camera = camera
camera.Position = Vec3.new(0, 0, -5)

myScene.SkyboxTexture = Assets.loadImage("skyboxes/Ocean-1.bmp")
Scene.CurrentScene = myScene

local bullyMoonMesh = Assets.loadMesh("bullymoon.obj")
local bullyMoonTex = Assets.loadImage("bullymoon.bmp")
local bullyMoon = Object.mesh(bullyMoonMesh, bullyMoonTex)
bullyMoon.Position = Vec3.new(-2.5, 0, 0)
myScene:AddObject(bullyMoon)

local uziMesh = Assets.loadMesh("cube.obj")
local uziTex = Assets.loadImage("uzi.bmp")
local uziCube = Object.mesh(uziMesh, uziTex)
uziCube.Position = Vec3.new(2.5, 0, 0)
myScene:AddObject(uziCube)

local pierre = Assets.loadAudio("yopierre.wav")
local pierreAudio = Audio.new(pierre)
pierreAudio:AttachTo(uziCube)
myScene:AddAudio(pierreAudio)
pierreAudio.Playing = true

Input.OnBegin("LeftMouseButton", function()
    Input.MouseVisible = false
    Input.MouseLocked = true
end)
Input.OnBegin("Escape", function()
    Input.MouseVisible = true
    Input.MouseLocked = false
end)

Input.OnChange("MouseMove", function(input)
    camera.Rotation = camera.Rotation + Vec3.new(input.Delta.Y, input.Delta.X, 0)
end)

myScene:OnUpdate(function(dt)
    local mul = Vec3.new(dt, dt, dt)

    local toAdd = Vec3.new(0, 0, 0)
    if Input.IsDown("W")            then toAdd = toAdd + camera.ForwardDirection * mul end
    if Input.IsDown("S")            then toAdd = toAdd - camera.ForwardDirection * mul end
    if Input.IsDown("A")            then toAdd = toAdd - camera.RightDirection * mul end
    if Input.IsDown("D")            then toAdd = toAdd + camera.RightDirection * mul end
    if Input.IsDown("Space")        then toAdd = toAdd + camera.UpDirection * mul end
    if Input.IsDown("LeftShift")    then toAdd = toAdd - camera.UpDirection * mul end

    if toAdd then camera.Position = camera.Position + toAdd end

    bullyMoon.Rotation = bullyMoon.Rotation + Vec3.new(0, dt * 50, 0)
    uziCube.Rotation = uziCube.Rotation + Vec3.new(dt * 5, dt * 50, dt * 20)
end)

print("done")
