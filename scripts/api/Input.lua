--[[
Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.
--]]

--- @meta Input
-- This file is for the Lua Language Server, do not require it

--- @alias InputCode "A" | "B" | "C" | "D" | "E" | "F" |"G" | "H" | "I" | "J" | "K" | "L" | "M" | "N" | "O" | "P" | "Q" | "R" | "S" | "T" | "U" | "V" | "W" | "X" | "Y" | "Z" | "Exclamation" | "At" | "Hashtag" | "Dollar" | "Percent" | "Caret" | "Ampersand" | "Asterisk" | "LeftParen" | "RightParen" | "Plus" | "Minus" | "Underscore" | "Equal" | "LeftBrace" | "RightBrace" | "LeftBracket" | "RightBracket" | "Pipe" | "Slash" | "Backslash" | "Colon" | "Semicolon" | "Quote" | "DoubleQuote" | "Comma" | "Period" | "LessThan" | "GreaterThan" | "Question" | "Tilde" | "Backquote" | "Escape" | "F1" | "F2" | "F3" | "F4" | "F5" | "F6" | "F7" | "F8" | "F9" | "F10" | "F11" | "F12" | "Tab" | "Backspace" | "CapsLock" | "Enter" | "LeftShift" | "RightShift" | "LeftControl" | "RightControl" | "LeftAlt" | "RightAlt" | "LeftSuper" | "RightSuper" | "Up" | "Down" | "Left" | "Right" | "LeftMouseButton" | "RightMouseButton" | "MiddleMouseButton" | "MouseScroll" | "MouseMove" | "Space"

--- Represents an input.
--- @class Input
---
--- The input code as a string.
--- @field Code InputCode
---
--- The input's value.
--- For keys and other digital inputs (on or off), this is either 0 or 1.
--- For analog inputs, this ranges from 0-1.
--- @field Value number|Vec2
---
--- How much the input has changed. Especially useful for movement and joysticks.
--- @field Delta number|Vec2
---
--- Which gamepad/player this came from (always 1 for keyboard/mouse)
--- @field UserIndex number

--- Library relating to various input-related things
--- @class InputLib
---
--- Determines if the mouse can move.
--- @field MouseLocked boolean
---
--- Determines if the mouse is visible.
--- @field MouseVisible boolean
Input = {}

--- Connect a callback to when an input begins. Call the returned function once to disconnect the callback.
--- @overload fun(code: InputCode, callback: fun(input: Input))
--- @param callback fun(input: Input)
--- @return fun()
function Input.OnBegin(callback) end

--- Connect a callback to when an input ends. Call the returned function once to disconnect the callback.
--- @overload fun(code: InputCode, callback: fun(input: Input))
--- @param callback fun(input: Input)
--- @return fun()
function Input.OnEnd(callback) end

--- Connect a callback to when an input changes (like mouse movement). Call the returned function once to disconnect the callback.
--- @overload fun(code: InputCode, callback: fun(input: Input))
--- @param callback fun(input: Input)
--- @return fun()
function Input.OnChange(callback) end

--- Checks if an input is down.
--- @param code InputCode
function Input.IsDown(code) end

--- Gets an input's value.
--- @param code InputCode
function Input.GetValue(code) end
