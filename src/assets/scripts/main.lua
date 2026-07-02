--[[
Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.
--]]

local vec1 = Vec3.new(5, 10, 20)
local vec2 = Vec3.new(-5, -10, -20)

print(vec1, vec2)

-- local myScene = Scene.new()

-- local bullyMoonMeshData = Assets.loadMesh("bullymoon")
-- local bullyMoon = Object.mesh(bullyMoonMeshData)
-- bullyMoon.Position = Vec3.new(-5, 0, 0)
-- bullyMoon.Texture = Assets.loadImage("bullymoon")

-- local uziCubeMeshData = Assets.loadMesh("cube")
-- local uziCube = Object.mesh(uziCubeMeshData)
-- uziCube.Position = Vec3.new(5, 0, 0)
-- uziCube.Texture = Assets.loadImage("uzi")

-- myScene:OnUpdate(function(dt)
--     bullyMoon.Rotation:add(Vec3.new(0, dt * 10, 0))
--     uziCube.Rotation:add(Vec3.new(dt * 5, dt * 10, dt * 20))
-- end)
