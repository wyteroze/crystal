// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const ecs = @import("../ecs/ecs.zig");
const math = @import("../core/math/math.zig");
const types = @import("types.zig");
const ComponentIds = @import("Ui.zig").ComponentIds;

const MeasureCache = std.AutoHashMap(ecs.Entity, math.Vec2);

pub fn reflowUi(
    world: *ecs.World, 
    ids: ComponentIds, 
    changed: []const ecs.Entity, 
    allocator: std.mem.Allocator
) void {
    var dirty: std.AutoHashMap(ecs.Entity, void) = .init(allocator);

    for (changed) |e| {
        var cur = e;
        while (cur.getParent()) |p| : (cur = p) {
            const mode = world.getComponent(cur, ids.size, types.SizeMode) orelse break;
            if (mode.width != .fill and mode.height != .fill) break;
        }
        dirty.put(cur, {}) catch @panic("Out of memory");
    }

    var cache: MeasureCache = .init(allocator);

    var it = dirty.keyIterator();
    while (it.next()) |r| {
        cache.clearRetainingCapacity();

        const measured = measure(r.*, world, ids, &cache);
        const origin: math.Vec2 = if (world.getComponent(r.*, ids.absolute_position, math.Vec2)) |p| p.* else .zero;

        arrange(r.*, measured, origin, world, ids, &cache);
    }
}

fn measure(entity: ecs.Entity, world: *ecs.World, ids: ComponentIds, cache: *MeasureCache) math.Vec2 {
    const mode: types.SizeMode = if (entity.getComponent(ids.size, types.SizeMode)) |m| m.* else .{};
    const layout = entity.getComponent(ids.layout, types.Layout);
    const children = entity.getChildren();

    var intr: math.Vec2 = .zero;
    if (layout) |l| {
        var main_sum: f32 = 0;
        var cross_max: f32 = 0;

        for (children, 0..) |c, i| {
            const child_size = measure(c, world, ids, cache);
            cache.put(c, child_size) catch @panic("Out of memory");
            
            const main = if (l.direction == .horizontal) child_size.x else child_size.y;
            const cross = if (l.direction == .horizontal) child_size.y else child_size.x;

            main_sum += main;
            if (i > 0) main_sum += l.gap;
            cross_max = @max(cross_max, cross);
        }

        const pad_main = if (l.direction == .horizontal) l.padding.left + l.padding.right else l.padding.top + l.padding.bottom;
        const pad_cross = if (l.direction == .horizontal) l.padding.top + l.padding.bottom else l.padding.left + l.padding.right;

        const hug_main = main_sum + pad_main;
        const hug_cross = cross_max + pad_cross;

        intr = if (l.direction == .horizontal) .new(hug_main, hug_cross) else .new(hug_cross, hug_main);
    }// else if (entity.getComponent(ids.text, types.TextMeasurable)) |t| {
    //     intr = t.measure();
    // }

    return .new(
        axis(mode.width, intr.x),
        axis(mode.height, intr.y)
    );
}

fn axis(a: types.SizeAxis, hug_val: f32) f32 {
    return switch (a) {
        .fixed => |v| v,
        .hug => hug_val,
        .fill => 0
    };
}

fn arrange(entity: ecs.Entity, final: math.Vec2, origin: math.Vec2, world: *ecs.World, ids: ComponentIds, cache: *MeasureCache) void {
    if (!world.hasComponent(entity, ids.absolute_position)) world.addComponent(entity, ids.absolute_position, math.Vec2, .zero) catch {};
    if (!world.hasComponent(entity, ids.absolute_size)) world.addComponent(entity, ids.absolute_size, math.Vec2, .zero) catch {};
    entity.setComponent(ids.absolute_position, math.Vec2, origin) catch {};
    entity.setComponent(ids.absolute_size, math.Vec2, final) catch {};

    std.log.debug("arranging {d}", .{ entity.toU64() });

    const layout = entity.getComponent(ids.layout, types.Layout) orelse return;
    const children = entity.getChildren();

    const pad = layout.padding;
    const content_size: math.Vec2 = .new(
        final.x - pad.left - pad.right,
        final.y - pad.top - pad.bottom
    );

    var main_sum: f32 = 0;
    var fill_count: u32 = 0;

    for (children) |c| {
        const mode: types.SizeMode = if (c.getComponent(ids.size, types.SizeMode)) |m| m.* else .{};
        const main_mode = if (layout.direction == .horizontal) mode.width else mode.height;

        if (main_mode == .fill) {
            fill_count += 1;
        } else {
            const cached: math.Vec2 = cache.get(c) orelse .zero;
            main_sum += if (layout.direction == .horizontal) cached.x else cached.y;
        }
    }

    const total_gap = layout.gap * @as(f32, @floatFromInt(children.len -| 1));
    const content_main = if (layout.direction == .horizontal) content_size.x else content_size.y;
    const remaining = @max(0, content_main - main_sum - total_gap);
    const fill = if (fill_count > 0) remaining / @as(f32, @floatFromInt(fill_count)) else 0;

    const used = main_sum + fill * @as(f32, @floatFromInt(fill_count)) + total_gap;

    var cursor = switch (layout.justify) {
        .start => 0,
        .center => (content_main - used) / 2,
        .end => content_main - used,
        .space_between => 0
    };
    const extra = if (layout.justify == .space_between and children.len > 1)
        remaining / @as(f32, @floatFromInt(children.len-1))
    else 0;

    for (children, 0..) |c, i| {
        const mode: types.SizeMode = if (c.getComponent(ids.size, types.SizeMode)) |m| m.* else .{};
        const cached: math.Vec2 = cache.get(c) orelse .zero;

        const main_mode = if (layout.direction == .horizontal) mode.width else mode.height;
        const cross_mode = if (layout.direction == .horizontal) mode.height else mode.width;

        const cross_available = if (layout.direction == .horizontal) content_size.y else content_size.x;
        const main_size = if (main_mode == .fill) fill else (if (layout.direction == .horizontal) cached.x else cached.y);
        const cross_size = if (cross_mode == .fill) cross_available else (if (layout.direction == .horizontal) cached.y else cached.x);

        const cross_offset = switch (layout.align_items) {
            .start => 0,
            .center => (cross_available - cross_size) / 2,
            .end => cross_available - cross_size
        };

        const child_size: math.Vec2 = if (layout.direction == .horizontal) .new(main_size, cross_size) else .new(cross_size, main_size);
        const child_origin = if (layout.direction == .horizontal)
            origin.add(.new(pad.left + cursor, pad.top + cross_offset))
        else
            origin.add(.new(pad.left + cross_offset, pad.top + cursor));

        arrange(c, child_size, child_origin, world, ids, cache);
        
        cursor += main_size + layout.gap + (if (layout.justify == .space_between and i < children.len-1) extra else 0);
    }
}