--[[
Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.
--]]

local core = require("core")
local assets = require("assets")
local input = require("input")
local ui = require("ui")
-- local audio = require("audio")

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
    local jbMono = assets.load("assets://fonts/JetBrains-Mono.ttf")
    entity:AddComponent("Position", core.Vec3.new(0, 0, 5))
    entity:AddComponent("Rotation", core.Vec3.new(0, 0, 0))
    entity:AddComponent("Mesh", assets.load("assets://models/cube.fbx"))
    entity:AddComponent("Image", chickenPng)

    -- local graph = audio.Graph.new()
    -- local filter = graph:AddNode(audio.GraphNode.LowPassFilter { Cutoff = 800 })
    -- graph.Input:Connect(filter)
    -- filter:Connect(graph.Output)

    -- entity:AddComponent("Speaker", audio.Speaker {
    --     Volume = 1,
    --     MinDistance = 1,
    --     MaxDistance = 100,
    --     Attenuation = audio.Attenuation.InverseSquare,
    --     -- Graph = graph
    -- })

    -- local track = entity.Components.Speaker:Play(audioStream)
    
    -- track:Play()
    -- track:Stop()
    -- track.Played:Connect()
    -- track.Stopped:Connect()
    -- track.Looped:Connect()
    -- track:Destroy()

    local elements = {}
    entity.Events.Updated:Connect(function(dt)
        self._timer = self._timer + dt
        local toAdd = self.Multiplier * dt
        local add = core.Vec3.new(toAdd * 5, toAdd * 10, toAdd * 20)
        
        self._entity.Components.Rotation = self._entity.Components.Rotation + add
        print(pcall(function (...)
            elements[1].Components.Text = ui.Text {
                Font = jbMono,
                Content = ("The fps is %.2f rn"):format(1/dt),
                Color = core.Color.new(1, 1, 1, 1),
                Size = 13
            }
        end))
    end)

    entity.Events.Destroyed:Connect(function()
        print(("%s is being destroyed!"):format(self._entity.Name))
    end)
    
    local mainElement = ui:CreateElement {
        Size = ui.SizeMode { Width = ui.SizeAxis.Fixed(640), Height = ui.SizeAxis.Fixed(360) },
        Color = core.Color.new(1, 0, 1, 0.5),
        Borders = ui.Borders { Top = 4, Bottom = 4, Left = 4, Right = 4 },
        Text = ui.Text {
            Font = jbMono,
            Content = "Yo",
            Color = core.Color.new(1, 1, 1, 1),
            Size = 13
        },
        Layout = ui.Layout.Grid {
            Padding = ui.Padding { Top = 10, Bottom = 10, Left = 10, Right = 10 },
            Columns = ui.GridAxis.Fixed(1),
            Rows = ui.GridAxis.Auto,
            Flow = ui.GridFlow.Column,
            RowGap = 2, ColumnGap = 2,
        }
    }
    
    for i = 1, 5 do
        local child = ui:CreateElement {
            Parent = mainElement,
            Size = ui.SizeMode { Width = ui.SizeAxis.Fill, Height = ui.SizeAxis.Fill },
            Color = core.Color.new(.1, .1, .1, 1),
            Layout = ui.Layout {
                Padding = ui.Padding { Left = 6, Right = 6, Top = 0, Bottom = 0 }
            }
        }

        local txt = ui:CreateElement {
            Parent = child,
            Size = ui.SizeMode { Width = ui.SizeAxis.Fill, Height = ui.SizeAxis.Fill },
            Text = ui.Text {
                Font = jbMono,
                Content = "Friendly faces everywhere humble folks without temptation",
                Justify = ui.Justify.Center,
                Color = core.Color.new(1, 1, 1, 1),
                Size = 13
            }
        }

        table.insert(elements, txt)
    end

    -- The image is tinted by the element's Color, 
    -- which is Color(1, 1, 1, 1) by default for images.
    ui:CreateElement {
        Parent = mainElement,
        Size = ui.SizeMode { Width = ui.SizeAxis.Fixed(64), Height = ui.SizeAxis.Fixed(64) },
        CornerRadii = ui.CornerRadii { TopLeft = 6, TopRight = 6, BottomLeft = 6, BottomRight = 6 },
        Borders = ui.Borders { Top = 2, Bottom = 2, Left = 2, Right = 2 },
        Image = ui.Image {
            Source = chickenPng,
            Crop = ui.Crop { Min = core.Vec2.new(0, 0), Max = core.Vec2.new(1, 1) }
        },
    }

    return self
end

return Teapot