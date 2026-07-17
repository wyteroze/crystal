--[[
Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.
--]]

--- @meta Window
-- This file is for the Lua Language Server, do not require it

--- A window's UI namespace, used to create widgets inside the window.
--- Accessed via `window.UI`.
--- @class WindowUI
---
--- Creates a Panel in this window. A panel is a colored rectangle, with an optional border.
--- @field Panel fun(self: WindowUI, anchor: Anchor, offset: Vec2, size: Vec2): Widget
--- Creates a Label in this window. A label sizes itself from its font and text, so no size is given.
--- @field Label fun(self: WindowUI, anchor: Anchor, offset: Vec2, text: string): Widget
--- Creates a Button in this window. Use the returned button's OnClick event to respond to clicks.
--- @field Button fun(self: WindowUI, anchor: Anchor, offset: Vec2, size: Vec2, text: string): Widget

--- A window's input namespace. Only receives input while the window is focused.
--- Accessed via `window.Input`.
--- @class WindowInput
---
--- Whether the mouse is locked to this window (relative mode) while it is
--- focused. Useful for first-person camera look.
--- @field MouseLocked boolean
--- Whether the mouse cursor is visible.
--- @field MouseVisible boolean
---
--- Connects a callback to when an input begins (ex. key pressed).
--- @field OnBegin fun(self: WindowInput, code: InputCode, callback: fun(input: Input))
--- Connects a callback to when an input ends (ex. key released).
--- @field OnEnd fun(self: WindowInput, code: InputCode, callback: fun(input: Input))
--- Connects a callback to when an input changes (ex. mouse movement).
--- @field OnChange fun(self: WindowInput, code: InputCode, callback: fun(input: Input))
--- Checks whether an input is currently down.
--- @field IsDown fun(self: WindowInput, code: InputCode): boolean
--- Gets an input's current value.
--- @field GetValue fun(self: WindowInput, code: InputCode): number

--- Represents a window. A window owns everything shown inside it; the scene
--- it renders, the camera it renders the scene from, UI widgets, and the
--- input it receives while focused.
---
--- Windows are independent. The same Scene can be assigned to several windows at
--- once, each with its own Camera, so two windows can look into one shared world
--- at different points.
--- @class Window
---
--- The scene rendered in this window. Set to nil for a UI-only window (no 3D).
--- The same Scene may be assigned to multiple windows at once.
--- @field Scene? Scene
---
--- The camera this window renders its scene from. The same camera may be assigned
--- to multiple windows at once.
--- @field Camera? Camera
---
--- The window's title text.
--- @field Title string
---
--- Widget creation for this window. See WindowUI.
--- @field UI WindowUI
--- Per-window input. See WindowInput.
--- @field Input WindowInput
---
--- Attaches a function to this window's per frame update. It is called once per
--- frame with the delta time (in seconds) for as long as the window is open.
--- Use this for per window logic; for example moving this window's Camera
--- from this window's input. For scene-wide updates, use Scene:OnUpdate instead.
--- @field OnUpdate fun(self: Window, callback: fun(delta: number))
---
--- Closes and destroys the window. Any remaining references to it become invalid.
--- @field Close fun(self: Window)

--- Factory for creating windows. The engine opens no window on its own; the
--- first Window.new call creates the game window.
--- @class WindowLib
Window = {}

--- Creates and opens a new window. Width and height determine the internal resolution,
--- and the optional `scale` (default is 1.0) determines the window size multiplier.
--- @param title string
--- @param width integer
--- @param height integer
--- @param scale number?
--- @return Window
function Window.new(title, width, height, scale) end
