--[[
Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.
--]]

local assets = require("@assets")
local ui = require("@ui")
local input = require("@input")

-- TODO: Make `require` allow file paths
local Modal = {}
Modal.__index = Modal

type Modal = typeof(Modal) & {
    modal: any,
    button: any,
    held: boolean
}

function Modal.new(size: Vec2, color: Color, font: Asset, headerText: string, btnText: string, center: bool): Modal
    local modalBg = ui.CreateElement {
        Size = { Width = size.X, Height = size.Y },
        Color = color,
        Layout = { Generic = {
            Direction = "Vertical",
            Padding = { Top = 25, Bottom = 25 },
            AlignItems = "Center",
            Justify = "Center",
            Gap = 25
        } }
    }

    if center then modalBg.Components.Position = Vec2.new(640 - size.X/2, 360 - size.Y/2) end

    local modalText = ui.CreateElement {
        Parent = modalBg,
        Color = Color.new(0, 0, 0, 0),
        Size = { Width = "Hug", Height = "Hug" },
        Text = {
            Font = font,
            Content = headerText,
            Color = Color.new(1, 1, 1, 1),
            Size = 16
        },
    }

    local button = ui.CreateElement {
        Parent = modalBg,
        -- Make it just a lil brighter
        Color = color:Lerp(Color.new(1, 1, 1), .1),
        Size = { Width = "Hug", Height = "Hug" },
        Layout = { Generic = { Padding = { Left = 10, Right = 10, Top = 5, Bottom = 5 } } },
    }

    local buttonText = ui.CreateElement {
        Parent = button,
        Color = Color.new(0, 0, 0, 0),
        Size = { Width = "Hug", Height = "Hug" },
        Text = {
            Font = font,
            Content = btnText,
            Color = Color.new(1, 1, 1, 1),
            Size = 13
        },
    }

    local self = setmetatable({
        modal = modalBg,
        button = button,
        held = false
    }, Modal) :: Modal

    self.modal.PointerDown:Connect(function() self.held = true end)
    self.modal.PointerUp:Connect(function() self.held = false end)
    self.modal.PointerMoved:Connect(function()
        if self.held then modalBg.Components.Position += input.Mice:GetMoveDelta() end
    end)
    self.button.PointerDown:Connect(function() self.button.Components.Color = color:Lerp(Color.new(1, 1, 1), .3) end)
    self.button.PointerLeft:Connect(function() self.button.Components.Color = color:Lerp(Color.new(1, 1, 1), .2) end)
    self.button.PointerUp:Connect(function() self.button.Components.Color = color:Lerp(Color.new(1, 1, 1), .2) end)

    return self
end

local Teapot = {}
Teapot.__index = Teapot

function Teapot.new(entity: Entity)
    local self = setmetatable({
        Multiplier = 1,
        _entity = entity,
        _timer = 0,
    }, Teapot)
    
    print(entity)
    local didALottaShitToLiveThisHereLifestyle = assets.load("assets://audios/Lifestyle - Rich Gang.mp3")
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

    local modal = Modal.new(Vec2.new(300, 150), Color.new(.1, .1, .1), jbMono, "You smell like updog", "What's updog")
    modal.button.Activated:Connect(function()
        local response = Modal.new(Vec2.new(300, 150), Color.new(.5, .5, .5), jbMono, "Not much how about you... lmao!!\ngottem!!", "Bruh.", true)
        response.button.Activated:Connect(function() response.modal:Destroy() end)
    end)

    entity.Updated:Connect(function(dt)
        self._timer = self._timer + dt
        local toAdd = self.Multiplier * dt
        local add = Vec3.new(toAdd * 5, toAdd * 10, toAdd * 20)
        
        self._entity.Components.Rotation += add
    end)
    
    -- button.PointerDown:Connect(function(...) print(`Pointer down! {...}`) end)
    -- button.PointerUp:Connect(function(...) print(`Pointer up! {...}`) end)
    -- button.Activated:Connect(function(...) print(`Activated! {...}`) end)
    -- button.PointerEntered:Connect(function(...) print(`Pointer entered! {...}`) end)
    -- button.PointerMoved:Connect(function(...) print(`Pointer moved! {...}`) end)
    -- button.PointerLeft:Connect(function(...) print(`Pointer left! {...}`) end)

    -- entity.Destroyed:Connect(function()
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