--[[
Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.
--]]

local assets = require("@assets")
local ui = require("@ui")

local Teapot = {}
Teapot.__index = Teapot

function Teapot.new(entity: Entity)
    local self = setmetatable({
        Multiplier = 1,
        _entity = entity,
        _timer = 0,
    }, Teapot)
    
    print(entity)
    local audioStream = assets.load("assets://audios/Lifestyle - Rich Gang.mp3")
    local chickenPng = assets.load("assets://images/chicken.jpg")
    local jbMono = assets.load("assets://fonts/JetBrains-Mono.ttf")

    entity:AddComponent("Position", Vec3.new(0, 0, 5))
    entity:AddComponent("Rotation", Vec3.new(0, 0, 0))
    entity:AddComponent("Mesh", assets.load("assets://models/cube.fbx"))
    entity:AddComponent("Image", chickenPng)

    -- local graph = audio.Graph.new()
    -- local filter = graph:AddNode(audio.GraphNode.LowPassFilter { Cutoff = 800 })
    -- graph.Input:Connect(filter)
    -- filter:Connect(graph.Output)

    entity:AddComponent("Speaker", {
        Volume = 1,
        MinDistance = 1,
        MaxDistance = 100,
        Attenuation = "InverseSquare",
        -- Graph = graph
    })

    -- local track: AudioTrack = entity.Components.Speaker:Play(audioStream)
    
    -- track:Play()
    -- track:Stop()
    -- track.Played:Connect()
    -- track.Stopped:Connect()
    -- track.Looped:Connect()
    -- track:Destroy()

    local elem = ui.CreateElement {
        Size = { Width = 640, Height = 640 },
        Color = Color.new(1, 0, 1, 0.5),
        Borders = { Top = 4, Bottom = 4, Left = 4, Right = 4 },
        Text = {
            Font = jbMono,
            Content = "Yo",
            Color = Color.new(1, 1, 1, 1),
            Size = 13
        },
        Layout = { Grid = {
            Padding = { Top = 10, Bottom = 10, Left = 10, Right = 10 },
            Rows = "Auto",
            Flow = "Row",
            RowGap = 2, ColumnGap = 2,
        } }
    }
    local hue = 0
    entity.Updated:Connect(function(dt)
        self._timer = self._timer + dt
        local toAdd = self.Multiplier * dt
        local add = Vec3.new(toAdd * 5, toAdd * 10, toAdd * 20)
        hue = (hue + dt)%1

        elem.Components.Text.Content = ("The fps is %.2f"):format(1/dt)
        elem.Components.Text.Size = (math.sin(self._timer)+2)*7
        elem.Components.Text.Color = Color.fromHSV(hue, 1, 1)
        self._entity.Components.Rotation += add
    end)

    -- entity.Events.Destroyed:Connect(function()
    --     print(("%s is being destroyed!"):format(self._entity.Name))
    -- end)
    
    -- for i = 1, 5 do
    --     local child = ui.CreateElement {
    --         Parent = mainElement,
    --         Size = { Width = "Fill", Height = "Fill" },
    --         Color = Color.new(.1, .1, .1, 1),
    --         Layout = { Generic = {
    --             Padding = { Left = 6, Right = 6, Top = 0, Bottom = 0 }
    --         } }
    --     }

    --     local txt = ui.CreateElement {
    --         Parent = child,
    --         Size = { Width = "Fill", Height = "Fill" },
    --         Text = {
    --             Font = jbMono,
    --             Content = "Friendly faces everywhere humble folks without temptation",
    --             Justify = "Center",
    --             Color = Color.new(1, 1, 1, 1),
    --             Size = 13
    --         }
    --     }

    --     table.insert(elements, txt)
    -- end

    -- -- The image is tinted by the element's Color, 
    -- -- which is Color(1, 1, 1, 1) by default for images.
    -- ui.CreateElement {
    --     Parent = mainElement,
    --     Size = { Width = 64, Height = 64 },
    --     CornerRadii = { TopLeft = 6, TopRight = 6, BottomLeft = 6, BottomRight = 6 },
    --     Borders = { Top = 2, Bottom = 2, Left = 2, Right = 2 },
    --     Image = {
    --         Source = chickenPng,
    --         Crop = { Min = Vec2.new(0, 0), Max = Vec2.new(1, 1) }
    --     },
    -- }

    return self
end

return Teapot