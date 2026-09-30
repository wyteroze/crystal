// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const ecs = @import("../ecs/ecs.zig");
const math = @import("../core/math/math.zig");
const text = @import("text.zig");
const types = @import("types.zig");
const ComponentIds = @import("Ui.zig").ComponentIds;

const MeasureCache = std.AutoHashMap(ecs.Entity, math.Vec2);
const GridDims = struct { cols: usize, rows: usize };
const GridCell = struct { col: usize, row: usize };

pub fn reflowUi(
    world: *ecs.World, 
    ids: ComponentIds, 
    changed: []const ecs.Entity, 
    allocator: std.mem.Allocator,
    frame_allocator: std.mem.Allocator
) void {
    var dirty: std.AutoHashMap(ecs.Entity, void) = .init(frame_allocator);

    for (changed) |e| {
        var cur = e;
        while (cur.getParent()) |p| {
            const mode = world.getComponent(cur, ids.size, types.SizeMode) orelse {
                cur = p;
                continue;
            };
            // Fill and hug depend on *something* else, so it can't be resolved
            // right now. We only know the size of Fixed 
            if (mode.width == .fixed and mode.height == .fixed) break;
            cur = p;
        }
        
        dirty.put(cur, {}) catch @panic("Out of memory");
    }

    var cache: MeasureCache = .init(frame_allocator);

    var it = dirty.keyIterator();
    while (it.next()) |r| {
        cache.clearRetainingCapacity();

        const measured = measure(r.*, world, ids, &cache);
        const origin: math.Vec2 = if (r.*.getParent() == null)
            (if (world.getComponent(r.*, ids.position, math.Vec2)) |p| p.* else .zero)
        else if (world.getComponent(r.*, ids.computed_position, math.Vec2)) |p| p.* else .zero;

        // arrange only needs an allocator for `[]GlyphQuad`s,
        // which outlasts the frame, so it needs the non-frame allocator.
        arrange(r.*, measured, origin, world, ids, &cache, allocator);
    }
}

fn measure(entity: ecs.Entity, world: *ecs.World, ids: ComponentIds, cache: *MeasureCache) math.Vec2 {
    const mode: types.SizeMode = if (entity.getComponent(ids.size, types.SizeMode)) |m| m.* else .{};
    const layout = entity.getComponent(ids.layout, types.Layout);
    const txt = entity.getComponent(ids.text, types.Text);
    const children = entity.getChildren();

    var intr: math.Vec2 = .zero;

    if (txt) |t| {
        const font = t.font.ensureGpuGet(.font, .{}) catch unreachable;
        intr = text.measureText(&font, t.content, t.size);
    }

    if (layout) |lay| {
        switch (lay.*) {
            .generic => |l| {
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

                intr = intr.add(if (l.direction == .horizontal) .new(hug_main, hug_cross) else .new(hug_cross, hug_main));
            },
            .grid => |l| {
                for (children) |c| {
                    const sz = measure(c, world, ids, cache);
                    cache.put(c, sz) catch @panic("Out of memory");
                }

                const dims = gridDims(l, children.len);

                var col_widest: f32 = 0;
                for (children) |c| {
                    const sz: math.Vec2 = cache.get(c) orelse .zero;
                    col_widest = @max(col_widest, sz.x);
                }

                var rows_height: f32 = 0;
                var row: usize = 0;
                while (row < dims.rows) : (row += 1) {
                    var row_h: f32 = 0;
                    for (children, 0..) |c, i| {
                        const cell = gridCell(l, i, dims);
                        if (cell.row != row) continue;

                        const sz: math.Vec2 = cache.get(c) orelse .zero;
                        row_h = @max(row_h, sz.y);
                    }

                    rows_height += row_h;
                }

                if (dims.rows > 1) rows_height += l.row_gap * @as(f32, @floatFromInt(dims.rows-1));

                const hug_w = col_widest * @as(f32, @floatFromInt(dims.cols))
                    + l.column_gap * @as(f32, @floatFromInt(dims.cols -| 1))
                    + l.padding.left + l.padding.right;
                const hug_h = rows_height + l.padding.top + l.padding.bottom;
                intr = intr.add(.new(hug_w, hug_h));
            }
        }
    }

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

fn arrange(
    entity: ecs.Entity, 
    final: math.Vec2, 
    origin: math.Vec2, 
    world: *ecs.World, 
    ids: ComponentIds, 
    cache: *MeasureCache, 
    allocator: std.mem.Allocator
) void {
    if (!world.hasComponent(entity, ids.computed_position)) world.addComponent(entity, ids.computed_position, math.Vec2, .zero) catch {};
    if (!world.hasComponent(entity, ids.computed_size)) world.addComponent(entity, ids.computed_size, math.Vec2, .zero) catch {};
    entity.setComponent(ids.computed_position, math.Vec2, origin) catch {};
    entity.setComponent(ids.computed_size, math.Vec2, final) catch {};

    if (entity.getComponent(ids.text, types.Text)) |t| {
        const font = t.font.ensureGpuGet(.font, .{}) catch unreachable;
        const quads = text.layoutGlyphs(allocator, &font, t.*, origin, final) catch @panic("Out of memory");

        if (entity.getComponent(ids.computed_text_layout, types.ComputedTextLayout)) |computed| {
            allocator.free(computed.quads);
            computed.quads = quads;
        } else {
            world.addComponent(entity, ids.computed_text_layout, types.ComputedTextLayout, .{ .quads = quads }) catch {};
        }
    }

    const layout = (entity.getComponent(ids.layout, types.Layout) orelse return).*;
    const children = entity.getChildren();

    const pad = switch (layout) { inline else => |l| l.padding };
    const content_size: math.Vec2 = .new(
        final.x - pad.left - pad.right,
        final.y - pad.top - pad.bottom
    );
    
    switch (layout) {
        .generic => |l| arrangeFlex(l, children, content_size, origin, pad, world, ids, cache, allocator),
        .grid => |l| arrangeGrid(l, children, content_size, origin, pad, world, ids, cache, allocator),
    }
}

fn arrangeFlex(
    layout: types.GenericLayout,
    children: []const ecs.Entity,
    content_size: math.Vec2,
    origin: math.Vec2,
    pad: types.Padding,
    world: *ecs.World,
    ids: ComponentIds,
    cache: *MeasureCache,
    allocator: std.mem.Allocator
) void {
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

        arrange(c, child_size, child_origin, world, ids, cache, allocator);
        
        cursor += main_size + layout.gap + (if (layout.justify == .space_between and i < children.len-1) extra else 0);
    }
}

fn arrangeGrid(
    layout: types.GridLayout,
    children: []const ecs.Entity,
    content_size: math.Vec2,
    origin: math.Vec2,
    pad: types.Padding,
    world: *ecs.World,
    ids: ComponentIds,
    cache: *MeasureCache,
    allocator: std.mem.Allocator
) void {
    if (children.len == 0) return;

    const dims = gridDims(layout, children.len);

    const total_col_gap = layout.column_gap * @as(f32, @floatFromInt(dims.cols -| 1));
    const col_width = @max(0, (content_size.x - total_col_gap) / @as(f32, @floatFromInt(dims.cols)));

    const row_heights = allocator.alloc(f32, dims.rows) catch @panic("Out of memory");
    defer allocator.free(row_heights);
    @memset(row_heights, 0);

    for (children, 0..) |c, idx| {
        const cell = gridCell(layout, idx, dims);
        const cs: math.Vec2 = cache.get(c) orelse .zero;
        row_heights[cell.row] = @max(row_heights[cell.row], cs.y);
    }

    const total_row_gap = layout.row_gap * @as(f32, @floatFromInt(dims.rows -| 1));
    var intrinsic_rows_height: f32 = 0;
    for (row_heights) |h| intrinsic_rows_height += h;

    const leftover = @max(0, content_size.y - intrinsic_rows_height - total_row_gap);
    if (dims.rows > 0) {
        const extra_per_row = leftover / @as(f32, @floatFromInt(dims.rows));
        for (row_heights) |*h| h.* += extra_per_row;
    }

    const row_y = allocator.alloc(f32, dims.rows) catch @panic("Out of memory");
    defer allocator.free(row_y);
    {
        var y = pad.top;
        var row: usize = 0;
        while (row < dims.rows) : (row += 1) {
            row_y[row] = y;
            y += row_heights[row] + layout.row_gap;
        }
    }

    for (children, 0..) |c, idx| {
        const cell = gridCell(layout, idx, dims);

        const mode: types.SizeMode = if (c.getComponent(ids.size, types.SizeMode)) |m| m.* else .{};
        const cached: math.Vec2 = cache.get(c) orelse .zero;

        const cell_w = col_width;
        const cell_h = row_heights[cell.row];
        const cell_x = pad.left + @as(f32, @floatFromInt(cell.col)) * (col_width + layout.column_gap);
        const cell_y = row_y[cell.row];

        const child_w = switch (mode.width) {
            .fill => cell_w,
            .hug, .fixed => @min(cached.x, cell_w),
        };
        const child_h = switch (mode.height) {
            .fill => cell_h,
            .hug, .fixed => @min(cached.y, cell_h),
        };

        const offset_x = switch (layout.justify) {
            .start, .space_between => 0,
            .center => (cell_w - child_w) / 2,
            .end => cell_w - child_w,
        };
        const offset_y = switch (layout.align_items) {
            .start => 0,
            .center => (cell_h - child_h) / 2,
            .end => cell_h - child_h,
        };

        const child_origin = origin.add(.new(cell_x + offset_x, cell_y + offset_y));
        const child_size: math.Vec2 = .new(child_w, child_h);

        arrange(c, child_size, child_origin, world, ids, cache, allocator);
    }
}

fn gridDims(g: types.GridLayout, child_count: usize) GridDims {
    const ax = switch (g.flow) {
        .column => g.columns,
        .row => g.rows
    };

    const driving = switch (ax) {
        .fixed => |c| @max(1, c),
        .auto => @max(1, child_count)
    };
    const cross = if (driving == 0) 0 else (child_count + driving - 1) / driving;

    return switch (g.flow) {
        .column => .{ .cols = driving, .rows = cross },
        .row => .{ .cols = cross, .rows = driving }
    };
}

fn gridCell(g: types.GridLayout, idx: usize, dims: GridDims) GridCell {
    return switch (g.flow) {
        .column => .{ .col = idx % dims.cols, .row = idx / dims.cols },
        .row => .{ .col = idx / dims.rows, .row = idx % dims.rows }
    };
}