--[[
Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.
--]]

local assets = require("@assets")

local Teapot = {}
Teapot.__index = Teapot

function Teapot.new(entity: Entity)
    local self = setmetatable({
        Multiplier = 1,
        _entity = entity,
        _timer = 0,
    }, Teapot)
    
    print(entity)
    local chickenPng = assets.load("assets://images/chicken.jpg")

    entity:AddComponent("Position", Vec3.new(0, 0, 5))
    entity:AddComponent("Rotation", Vec3.new(0, 0, 0))
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

    -- local elements = {}
    entity.Updated:Connect(function(dt)
        self._timer = self._timer + dt
        local toAdd = self.Multiplier * dt
        local add = Vec3.new(toAdd * 5, toAdd * 10, toAdd * 20)
        
        self._entity.Components.Rotation += add
        -- print(pcall(function (...)
        --     elements[1].Components.Text.Content = ("The fps is %.2f rn"):format(1/dt)
        -- end))
    end)

    -- entity.Events.Destroyed:Connect(function()
    --     print(("%s is being destroyed!"):format(self._entity.Name))
    -- end)
    
    -- local mainElement = ui:CreateElement {
    --     Size = { Width = 640, Height = 640 },
    --     Color = core.Color.new(1, 0, 1, 0.5),
    --     Borders = { Top = 4, Bottom = 4, Left = 4, Right = 4 },
    --     Text = {
    --         Font = jbMono,
    --         Content = "Yo",
    --         Color = core.Color.new(1, 1, 1, 1),
    --         Size = 13
    --     },
    --     Layout = { Grid = {
    --         Padding = { Top = 10, Bottom = 10, Left = 10, Right = 10 },
    --         Rows = ui.GridAxis.Auto,
    --         Flow = ui.GridFlow.Column,
    --         RowGap = 2, ColumnGap = 2,
    --     } }
    -- }
    
    -- for i = 1, 5 do
    --     local child = ui:CreateElement {
    --         Parent = mainElement,
    --         Size = { Width = "Fill", Height = "Fill" },
    --         Color = core.Color.new(.1, .1, .1, 1),
    --         Layout = { Generic = {
    --             Padding = { Left = 6, Right = 6, Top = 0, Bottom = 0 }
    --         } }
    --     }

    --     local txt = ui:CreateElement {
    --         Parent = child,
    --         Size = { Width = "Fill", Height = "Fill" },
    --         Text = {
    --             Font = jbMono,
    --             Content = "Friendly faces everywhere humble folks without temptation",
    --             Justify = "Center",
    --             Color = core.Color.new(1, 1, 1, 1),
    --             Size = 13
    --         }
    --     }

    --     table.insert(elements, txt)
    -- end

    -- -- The image is tinted by the element's Color, 
    -- -- which is Color(1, 1, 1, 1) by default for images.
    -- ui:CreateElement {
    --     Parent = mainElement,
    --     Size = { Width = 64, Height = 64 },
    --     CornerRadii = { TopLeft = 6, TopRight = 6, BottomLeft = 6, BottomRight = 6 },
    --     Borders = { Top = 2, Bottom = 2, Left = 2, Right = 2 },
    --     Image = {
    --         Source = chickenPng,
    --         Crop = { Min = core.Vec2.new(0, 0), Max = core.Vec2.new(1, 1) }
    --     },
    -- }

    return self
end

return Teapot