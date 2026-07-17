--[[
Copyright 2026 wyteroze. Licensed under the Apache License, Version 2.0.
--]]

--- @meta Font
-- This file is for the Lua Language Server, do not require it

--- Represents a loaded font. You do not need to care about the font format.
--- @class Font
--- Returns the pixel size of the text when drawn with this font.
--- @field MeasureText fun(self: Font, text: string): Vec2
Font = {}
