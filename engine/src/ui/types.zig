// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const ecs = @import("../ecs/ecs.zig");
const Assets = @import("../assets/Assets.zig");
const core = @import("../core/core.zig");
const math = @import("../core/math/math.zig");
const text = @import("text.zig");

pub const RenderViewOptions = struct {
    camera: ecs.Entity,
    size: [2]u32
};

pub const ComputedTextLayout = struct {
    quads: []const text.GlyphQuad
};

pub const LayoutDirection = enum { 
    horizontal, 
    vertical,

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("LayoutDirection.{s}", .{ switch (self) {
            .horizontal => "Horizontal",
            .vertical => "Vertical"
        } });
    }
};
pub const Align = enum { 
    start, 
    center, 
    end,

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("Align.{s}", .{ switch (self) {
            .start => "Start",
            .center => "Center",
            .end => "End"
        } });
    }
};
pub const Justify = enum { 
    start, 
    center, 
    end, 
    space_between,

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("Justify.{s}", .{ switch (self) {
            .start => "Start",
            .center => "Center",
            .end => "End",
            .space_between => "SpaceBetween"
        } });
    }
};
pub const SizeAxis = union(enum) { 
    fixed: f32, 
    hug, 
    fill,

    pub const __lua = .val;
    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        switch (self) {
            .fixed => |f| try writer.print("SizeAxis.Fixed({d})", .{ f }),
            .hug => try writer.print("SizeAxis.Hug", .{}),
            .fill => try writer.print("SizeAxis.Fill", .{})
        }
    }
};

pub const Padding = struct {
    top: f32 = 0,
    bottom: f32 = 0,
    left: f32 = 0,
    right: f32 = 0,

    pub fn all(pad: f32) Padding {
        return .{ .top = pad, .bottom = pad, .left = pad, .right = pad };
    }
    pub fn horizontal(pad: f32) Padding {
        return .{ .left = pad, .right = pad };
    }
    pub fn vertical(pad: f32) Padding {
        return .{ .top = pad, .bottom = pad };
    }
    pub fn horizontalVertical(horizontal_pad: f32, vertical_pad: f32) Padding {
        return .{ .left = horizontal_pad, .right = horizontal_pad, .top = vertical_pad, .bottom = vertical_pad };
    }

    pub const __lua = .val;
    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print(
            "Padding{{ Top = {d}, Bottom = {d}, Left  = {d}, Right = {d} }}", 
            .{ self.top, self.bottom, self.left, self.right }
        );
    }
};

pub const CornerRadii = struct {
    top_left: f32 = 0,
    top_right: f32 = 0,
    bottom_left: f32 = 0,
    bottom_right: f32 = 0,

    pub const __lua = .val;
    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print(
            "CornerRadii{{ TopLeft = {d}, TopRight = {d}, BottomLeft  = {d}, BottomRight = {d} }}", 
            .{ self.top_left, self.top_right, self.bottom_left, self.bottom_right }
        );
    }
};

pub const Layout = struct {
    direction: LayoutDirection = .horizontal,
    gap: f32 = 0,
    padding: Padding = .{},
    align_items: Align = .start,
    justify: Justify = .start,

    pub const __lua = .val;
    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print(
            "Layout{{ Direction = {f}, Gap = {d}, Padding = {f}, AlignItems = {f}, Justify = {f} }}", 
            .{ self.direction, self.gap, self.padding, self.align_items, self.justify }
        );
    }
};

pub const SizeMode = struct {
    width: SizeAxis = .{ .fixed = 100 },
    height: SizeAxis = .{ .fixed = 100 },

    pub fn fixed(w: f32, h: f32) SizeMode {
        return .{ .width = .{ .fixed = w }, .height = .{ .fixed = h } };
    }

    pub const __lua = .val;
    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print(
            "SizeMode{{ Width = {f}, Height = {f} }}", 
            .{ self.width, self.height }
        );  
    }
};

pub const Text = struct {
    font: Assets.AssetHandle,
    content: []const u8 = "",

    // Styling
    align_text: Align = .center,
    justify: Justify = .center,

    color: core.Color = .fromRgbFloat(1, 1, 1, 1),
    size: u32 = 13,

    /// Since all components' strings must be heap-allocated, this frees the last
    /// string and dupes the given string. You should use the same allocator
    /// for every setText call.
    pub fn setText(self: *Text, allocator: std.mem.Allocator, txt: []const u8) !void {
        allocator.free(self.content);
        self.content = try allocator.dupe(u8, txt);
    }

    pub const __lua = .val;
};

pub const Crop = struct {
    min: math.Vec2 = .zero,
    max: math.Vec2 = .one,

    pub const __lua = .val;
    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("Crop{{ Min = {f}, Max = {f} }}", .{ self.min, self.max });
    }
};

pub const Image = struct {
    source: Assets.AssetHandle,
    crop: Crop = .{},

    pub const __lua = .val;
};