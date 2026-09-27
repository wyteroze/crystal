// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const ecs = @import("../ecs/ecs.zig");
const core = @import("../core/core.zig");
const math = @import("../core/math/math.zig");
const render = @import("../render/render.zig");
const reflow = @import("reflow.zig");
pub const types = @import("types.zig");

pub const ComponentIds = struct {
    position: ecs.ComponentId,
    size: ecs.ComponentId,
    layout: ecs.ComponentId,
    color: ecs.ComponentId,
    corner_radius: ecs.ComponentId,
    opacity: ecs.ComponentId,
    text: ecs.ComponentId,
    render_view: ecs.ComponentId,
    absolute_size: ecs.ComponentId,
    absolute_position: ecs.ComponentId
};

const Ui = @This();
allocator: std.mem.Allocator,
frame_allocator: std.heap.ArenaAllocator,
component_ids: ComponentIds,
world: ecs.World,
changed: std.ArrayList(ecs.Entity),

pub fn init(allocator: std.mem.Allocator) !Ui {
    var world: ecs.World = .init(allocator);

    const position = try world.registerComponentNativeShaped(math.Vec2, "Position", null);
    const size = try world.registerComponentNativeShaped(types.SizeMode, "Size", null);
    const layout = try world.registerComponentNativeShaped(types.Layout, "Layout", null);
    const color = try world.registerComponentNativeShaped(core.Color, "Color", null);
    const corner_radius = try world.registerComponentNativeShaped(f32, "CornerRadius", null);
    const opacity = try world.registerComponentNativeShaped(f32, "Opacity", null);
    const text = try world.registerComponentNativeShaped(render.types.Text, "Text", null);
    const render_view = try world.registerComponentNativeShaped(types.RenderViewOptions, "RenderView", null);
    const absolute_size = try world.registerComponentNativeShaped(math.Vec2, "AbsoluteSize", null);
    const absolute_position = try world.registerComponentNativeShaped(math.Vec2, "AbsolutePosition", null);

    return .{
        .allocator = allocator,
        .frame_allocator = .init(allocator),
        .world = world,
        .changed = .empty,
        .component_ids = .{
            .position = position,
            .size = size,
            .layout = layout,
            .color = color,
            .corner_radius = corner_radius,
            .opacity = opacity,
            .text = text,
            .render_view = render_view,
            .absolute_size = absolute_size,
            .absolute_position = absolute_position
        },
    };
}

pub fn deinit(self: *Ui) void {
    self.world.deinit();
    self.frame_allocator.deinit();
}

pub fn update(self: *Ui) void {
    const changed = &self.world.hierarchy.changed;
    if (changed.items.len == 0) return;

    reflow.reflowUi(&self.world, self.component_ids, changed.items, self.frame_allocator.allocator());
    _ = self.frame_allocator.reset(.retain_capacity);
    changed.clearRetainingCapacity();
}