// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const ecs = @import("../ecs/ecs.zig");

pub const RenderViewOptions = struct {
    camera: ecs.Entity,
    size: [2]u32
};

pub const LayoutDirection = enum { horizontal, vertical };
pub const Align = enum { start, center, end };
pub const Justify = enum { start, center, end, space_between };
pub const SizeAxis = union(enum) { fixed: f32, hug, fill };

pub const Padding = struct {
    top: f32 = 0,
    bottom: f32 = 0,
    left: f32 = 0,
    right: f32 = 0
};

pub const CornerRadii = struct {
    top_left: f32 = 0,
    top_right: f32 = 0,
    bottom_left: f32 = 0,
    bottom_right: f32 = 0
};

pub const Layout = struct {
    direction: LayoutDirection,
    gap: f32 = 0,
    padding: Padding = .{},
    align_items: Align = .start,
    justify: Justify = .start
};

pub const SizeMode = struct {
    width: SizeAxis = .{ .fixed = 100 },
    height: SizeAxis = .{ .fixed = 100 },

    pub fn fixed(w: f32, h: f32) SizeMode {
        return .{ .width = .{ .fixed = w }, .height = .{ .fixed = h } };
    }
};