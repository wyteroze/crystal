--[[
Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.
--]]

local camera = Object.camera()
camera.Position = Vec3.new(0, 0, -5)

local scene = Scene.new("Test scene")
scene.SkyboxTexture = Assets.loadImage("skyboxes/Ocean-1.bmp")

local window = Window.new("Game window", 540, 360, 2)

window.Camera = camera
window.Scene = scene

window.UI:Button("Top", Vec2.new(0, 0), Vec2.new(64, 64), "hello")

local bullyMoonMesh = Assets.loadMesh("bullymoon.obj")
local bullyMoonTex = Assets.loadImage("bullymoon.bmp")
local bullyMoon = Object.mesh(bullyMoonMesh, bullyMoonTex)
bullyMoon.Position = Vec3.new(-2.5, 0, 0)
scene:AddObject(bullyMoon)

local uziMesh = Assets.loadMesh("cube.obj")
local uziTex = Assets.loadImage("uzi.bmp")
local uziCube = Object.mesh(uziMesh, uziTex)
uziCube.Position = Vec3.new(2.5, 0, 0)
scene:AddObject(uziCube)

-- local pierre = Assets.loadAudio("yopierre.wav")
-- local pierreAudio = Audio.new(pierre)
-- pierreAudio:AttachTo(uziCube)
-- scene:AddAudio(pierreAudio)
-- pierreAudio.Playing = true

window.Input:OnBegin("LeftMouseButton", function()
    window.Input.MouseVisible = false
    window.Input.MouseLocked = true
end)
window.Input:OnBegin("Escape", function()
    window.Input.MouseVisible = true
	window.Input.MouseLocked = false
end)

window.Input:OnChange("MouseMove", function(input)
    if not window.Input.MouseLocked then return end
    camera.Rotation = camera.Rotation + Vec3.new(input.Delta.Y, input.Delta.X, 0)
end)

window:OnUpdate(function(dt)
    local mul = Vec3.new(dt, dt, dt)

    local toAdd = Vec3.new(0, 0, 0)
    if window.Input:IsDown("W")            then toAdd = toAdd + camera.ForwardDirection * mul end
    if window.Input:IsDown("S")            then toAdd = toAdd - camera.ForwardDirection * mul end
    if window.Input:IsDown("A")            then toAdd = toAdd - camera.RightDirection * mul end
    if window.Input:IsDown("D")            then toAdd = toAdd + camera.RightDirection * mul end
    if window.Input:IsDown("Space")        then toAdd = toAdd + camera.UpDirection * mul end
    if window.Input:IsDown("LeftShift")    then toAdd = toAdd - camera.UpDirection * mul end

    if toAdd then camera.Position = camera.Position + toAdd end

    bullyMoon.Rotation = bullyMoon.Rotation + Vec3.new(0, dt * 50, 0)
    uziCube.Rotation = uziCube.Rotation + Vec3.new(dt * 5, dt * 50, dt * 20)
end)

print("done")
