// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const math = @import("../core/math/math.zig");
const Display = @import("Display.zig");

pub const WindowState = enum {
    normal,
    minimized,
    maximized,
    fullscreen
};

pub const WindowKind = enum {
    normal,
    utility,
    tooltip,
    popup
};

pub const WindowPosition = struct {
    /// Null = current primary display
    display: ?Display = null,
    anchor: math.Vec2 = .new(0.5, 0.5),
    offset: math.Vec2 = .zero,
};