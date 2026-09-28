--[[
Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.
--]]

local core = require("core")
local assets = require("assets")
local input = require("input")
local ui = require("ui")

local Teapot = {}
Teapot.__index = Teapot

function Teapot.new(entity)
    local self = setmetatable({
        Multiplier = 1,
        _entity = entity,
        _timer = 0,
        _lastFlicker = 0,
        _ogParent = entity.Parent
    }, Teapot)

    local chickenPng = assets.load("assets://images/chicken.jpg")
    entity:AddComponent("Position", core.Vec3.new(0, 0, 5))
    entity:AddComponent("Rotation", core.Vec3.new(0, 0, 0))
    entity:AddComponent("Mesh", assets.load("assets://models/cube.fbx"))
    entity:AddComponent("Image", chickenPng)

    entity.Events.Updated:Connect(function(dt)
        self._timer = self._timer + dt
        local toAdd = self.Multiplier * dt
        local add = core.Vec3.new(toAdd * 5, toAdd * 10, toAdd * 20)
        
        self._entity.Components.Rotation = self._entity.Components.Rotation + add
    end)

    entity.Events.Destroyed:Connect(function()
        print(("%s is being destroyed!"):format(self._entity.Name))
    end)
    
    local jbMono = assets.load("assets://fonts/JetBrains-Mono.ttf")
    local mainElement = ui:CreateElement({
        Size = ui.SizeMode({ Width = ui.SizeAxis.Fixed(640), Height = ui.SizeAxis.Fixed(360) }),
        Color = core.Color.new(1, 0, 1, 0.5),
        Text = ui.Text({
            Font = jbMono,
            Content = "Yo",
            Color = core.Color.new(1, 1, 1, 1),
            Size = 13
        }),
        Layout = ui.Layout({
            Direction = ui.LayoutDirection.Vertical,
            AlignItems = ui.Align.Start,
            Justify = ui.Justify.SpaceBetween,
            Padding = ui.Padding({ Top = 10, Bottom = 10, Left = 10, Right = 10 }),
            Gap = 10
        })
    })

    for i = 1, 10 do
        local child = ui:CreateElement({
            Parent = mainElement,
            Size = ui.SizeMode({ Width = ui.SizeAxis.Hug, Height = ui.SizeAxis.Hug }),
            Color = core.Color.new(0, 0, 1, 1),
            Layout = ui.Layout({
                Padding = ui.Padding({ Left = 6, Right = 6, Top = 0, Bottom = 0 })
            })
        })

        ui:CreateElement({
            Parent = child,
            Size = ui.SizeMode({ Width = ui.SizeAxis.Hug, Height = ui.SizeAxis.Hug }),
            Text = ui.Text({
                Font = jbMono,
                Content = ("Boi %d"):format(i),
                Justify = ui.Justify.Center,
                Color = core.Color.new(1, 1, 1, 1),
                Size = 13
            })
        })
    end

    -- The image is tinted by the element's Color, 
    -- which is Color(1, 1, 1, 1) by default for images.
    ui:CreateElement({
        Parent = mainElement,
        Size = ui.SizeMode({ Width = ui.SizeAxis.Fixed(64), Height = ui.SizeAxis.Fixed(64) }),
        Image = ui.Image({
            Source = chickenPng,
            Crop = ui.Crop({ Min = core.Vec2.new(0, 0), Max = core.Vec2.new(1, 1) })
        })
    })

    return self
end

return Teapot