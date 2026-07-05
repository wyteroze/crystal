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

-- not implemented yet
-- local pierre = Assets.loadAudio("yopierre.wav")
-- local pierreAudio = Audio.new(pierre)
-- pierreAudio:AttachTo(uziCube)
-- myScene:AddAudio(pierreAudio)
-- pierreAudio.Playing = true

Input.OnBegin("LeftMouseButton", function()
    Input.MouseVisible = false
end)
Input.OnBegin("Escape", function()
	Input.MouseVisible = true
end)

Input.OnChange("MouseMove", function(input)
    camera.Rotation:Add(Vec3.new(input.Delta.Y, input.Delta.X, 0))
end)

myScene:OnUpdate(function(dt)
    local mul = Vec3.new(dt, dt, dt)

    if Input.IsDown("W") then camera.Position:Add(camera.ForwardVector * mul) end
    if Input.IsDown("S") then camera.Position:Sub(camera.ForwardVector * mul) end
    if Input.IsDown("A") then camera.Position:Sub(camera.RightVector * mul) end
    if Input.IsDown("D") then camera.Position:Add(camera.RightVector * mul) end
    if Input.IsDown("Space") then camera.Position:Add(camera.UpVector * mul) end
    if Input.IsDown("LeftShift") then camera.Position:Sub(camera.UpVector * mul) end

    bullyMoon.Rotation:Add(Vec3.new(0, dt * 50, 0))
    uziCube.Rotation:Add(Vec3.new(dt * 5, dt * 50, dt * 20))
end)

print("done")
