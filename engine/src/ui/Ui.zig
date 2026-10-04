// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const ecs = @import("../ecs/ecs.zig");
const core = @import("../core/core.zig");
const math = @import("../core/math/math.zig");
const render = @import("../render/render.zig");
const reflow = @import("reflow.zig");
pub const types = @import("types.zig");

const u64_max = std.math.maxInt(u64);

pub const ComponentIds = struct {
    position: ecs.ComponentId,
    size: ecs.ComponentId,
    layout: ecs.ComponentId,
    color: ecs.ComponentId,
    opacity: ecs.ComponentId,
    text: ecs.ComponentId,
    render_view: ecs.ComponentId,
    computed_size: ecs.ComponentId,
    computed_position: ecs.ComponentId,
    computed_text_layout: ecs.ComponentId,
    image: ecs.ComponentId,
    corner_radii: ecs.ComponentId,
    borders: ecs.ComponentId
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
    const opacity = try world.registerComponentNativeShaped(f32, "Opacity", null);
    const text = try world.registerComponentNativeShaped(Ui.types.Text, "Text", null);
    const render_view = try world.registerComponentNativeShaped(types.RenderViewOptions, "RenderView", null);
    const computed_size = try world.registerComponentNativeShaped(math.Vec2, "ComputedSize", null);
    const computed_position = try world.registerComponentNativeShaped(math.Vec2, "ComputedPosition", null);
    const computed_text_layout = try world.registerComponentNativeShaped(types.ComputedTextLayout, "ComputedTextLayout", null);
    const image = try world.registerComponentNativeShaped(types.Image, "Image", null);
    const corner_radii = try world.registerComponentNativeShaped(Ui.types.CornerRadii, "CornerRadii", null);
    const borders = try world.registerComponentNativeShaped(Ui.types.Borders, "Borders", null);

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
            .corner_radii = corner_radii,
            .opacity = opacity,
            .text = text,
            .render_view = render_view,
            .computed_size = computed_size,
            .computed_position = computed_position,
            .computed_text_layout = computed_text_layout,
            .image = image,
            .borders = borders
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

    reflow.reflowUi(&self.world, self.component_ids, changed.items, self.allocator, self.frame_allocator.allocator());
    _ = self.frame_allocator.reset(.retain_capacity);
    changed.clearRetainingCapacity();
}

pub const registerLua = struct {
    const zlua = @import("zlua");
    const linker = @import("../scripting/linker/linker.zig");
    const Runtime = @import("../scripting/runtime/Runtime.zig");
    const LayoutBind = linker.Binding(types.Layout, false);
    const PaddingBind = linker.Binding(types.Padding, false);
    const CornerRadiiBind = linker.Binding(types.CornerRadii, false);
    const SizeModeBind = linker.Binding(types.SizeMode, false);
    const SizeAxisBind = linker.Binding(types.SizeAxis, false);
    const TextBind = linker.Binding(types.Text, false);
    const CropBind = linker.Binding(types.Crop, false);
    const ImageBind = linker.Binding(types.Image, false);
    const BordersBind = linker.Binding(types.Borders, false);
    const GridLayoutBind = linker.Binding(types.GridLayout, false);
    const GridAxisBind = linker.Binding(types.GridAxis, false);

    fn sizeAxisFixed(lua: *zlua.Lua) i32 {
        SizeAxisBind.push(lua, .{ .fixed = @floatCast(lua.checkNumber(1)) });
        return 1;
    }

    // layoutGeneric and layoutGrid is so that you can do either
    // `ui.Layout {}` for generic layout, or `ui.Layout.Grid {}` for grid layout

    // 1 = table, 2 = value
    fn layoutGeneric(lua: *zlua.Lua) i32 {
        const generic = linker.util.luaTableToStruct(lua, 2, types.GenericLayout, .{});
        LayoutBind.push(lua, .{ .generic = generic });
        return 1;
    }

    // 1 = table, 2 = key, 3 = value
    fn layoutGrid(lua: *zlua.Lua) i32 {
        if (!std.mem.eql(u8, lua.toString(2) catch return 0, "Grid")) return 0;
        lua.pushFunction(zlua.wrap(struct {
            fn c(lua_state: *zlua.Lua) i32 {
                const grid = linker.util.luaTableToStruct(lua_state, 1, types.GridLayout, .{});
                if (grid.justify == .space_between) 
                    lua_state.raiseErrorStr("Justify.SpaceBetween is not usable on GridLayouts", .{});
                if (grid.flow == .row and grid.rows == .auto or grid.flow == .column and grid.columns == .auto) 
                    lua_state.raiseErrorStr("GridLayout.Flow can't use an axis that uses GridAxis.Auto.", .{});

                LayoutBind.push(lua_state, .{ .grid = grid });
                return 1;
            }
        }.c));
        return 1;
    }

    fn gridAxisFixed(lua: *zlua.Lua) i32 {
        GridAxisBind.push(lua, .{ .fixed = @intCast(lua.checkInteger(1)) });
        return 1;
    }

    fn uiGet(l: *zlua.Lua) i32 {
        const key = l.toString(2) catch |e| linker.util.luaErr(l, e, .{ []const u8, 2 });

        if (std.mem.eql(u8, key, "SizeAxis")) {
            l.newTable();
            SizeAxisBind.push(l, .hug);  l.setField(-2, "Hug");
            SizeAxisBind.push(l, .fill); l.setField(-2, "Fill");
            l.pushFunction(zlua.wrap(sizeAxisFixed)); l.setField(-2, "Fixed");
            return 1;
        } else if (std.mem.eql(u8, key, "Layout")) {
            l.newTable();
            _ = l.getMetatableRegistry("LayoutMt");
            l.setMetatable(-2);
            return 1;
        } else if (std.mem.eql(u8, key, "LayoutDirection")) {
            linker.util.pushEnum(l, types.LayoutDirection);
            return 1;
        } else if (std.mem.eql(u8, key, "GridAxis")) {
            l.newTable();
            GridAxisBind.push(l, .auto); l.setField(-2, "Auto");
            l.pushFunction(zlua.wrap(gridAxisFixed)); l.setField(-2, "Fixed");

            return 1;
        } else if (std.mem.eql(u8, key, "GridFlow")) {
            linker.util.pushEnum(l, types.GridFlow);
            return 1;
        } else if (std.mem.eql(u8, key, "Align")) {
            linker.util.pushEnum(l, types.Align);
            return 1;
        } else if (std.mem.eql(u8, key, "Justify")) {
            linker.util.pushEnum(l, types.Justify);
            return 1;
        } else {
            // fallback to exising methods
            l.getMetatable(1) catch { l.pushNil(); return 1; };
            _ = l.getField(-1, "__methods");
            l.pushValue(2);
            _ = l.getTable(-2);

            return 1;
        }

        l.pushNil();
        return 1;
    }

    fn uiSet(l: *zlua.Lua) i32 {
        l.raiseErrorStr("'ui' is read-only", .{});
        
        return 0;
    }

    fn luaCreateElement(l: *zlua.Lua) i32 {
        const self = Runtime.fromState(l).ui;
        l.checkType(2, .table);

        const parent: ?ecs.Entity = switch (l.getField(2, "Parent")) {
            .nil => null,
            .userdata => linker.util.parseVal(l, ecs.Entity, -1) catch |e| linker.util.luaErr(l, e, .{}),
            else => l.raiseErrorStr("Parent must be an Entity, got %s", .{ l.typeNameIndex(-1).ptr }),
        };
        l.pop(1);

        const entity = self.world.spawnEntity() catch |e| linker.util.luaErr(l, e, .{});
        ecs.Entity.luaBinding.applyComponentTable(l, entity, 2, &.{ "Parent" }, true );

        if (parent) |p| entity.setParent(p) catch |e| linker.util.luaErr(l, e, .{});

        linker.Binding(ecs.Entity, false).push(l, entity);
        return 1;
    }

    fn luaMeasureText(l: *zlua.Lua) i32 {
        _ = l;
        return 0;
    }

    pub fn registerLua(l: *zlua.Lua) void {
        linker.value(l, types.Padding, .{
            .name = .{ .named = "Padding" },
            .scope = .{ .module = "ui.types" },
            .fields = &.{ "top", "bottom", "left", "right" }
        });
        linker.value(l, types.CornerRadii, .{
            .name = .{ .named = "CornerRadii" },
            .scope = .{ .module = "ui.types" },
            .fields = &.{ "top_left", "top_right", "bottom_left", "bottom_right" }
        });
        linker.value(l, types.Layout, .{
            .name = .{ .named = "Layout" },
            .scope = .{ .module = "ui.types" },
        });
        linker.value(l, types.SizeMode, .{
            .name = .{ .named = "SizeMode" },
            .scope = .{ .module = "ui.types" },
            .fields = &.{ "width", "height" },
        });
        linker.value(l, types.SizeAxis, .{
            .name = .{ .named = "SizeAxis" },
            .scope = .{ .module = "ui.types" }
        });
        linker.value(l, types.Text, .{
            .name = .{ .named = "Text" },
            .scope = .{ .module = "ui.types" }
        });
        linker.value(l, types.Image, .{
            .name = .{ .named = "Image" },
            .scope = .{ .module = "ui.types" },
            .fields = &.{ "source", "crop" }
        });
        linker.value(l, types.Crop, .{
            .name = .{ .named = "Crop" },
            .scope = .{ .module = "ui.types" },
            .fields = &.{ "min", "max" }
        });
        linker.value(l, types.Borders, .{
            .name = .{ .named = "Borders" },
            .scope = .{ .module = "ui.types" },
            .fields = &.{ "top", "bottom", "left", "right" }
        });
        linker.value(l, types.GridAxis, .{
            .name = .{ .named = "GridAxis" },
            .scope = .{ .module = "ui.types" }
        });
        linker.value(l, types.GenericLayout, .{ 
            .name = .{ .named = "GenericLayout" },
            .scope = .{ .module = "ui.types" },
            .fields = &.{ "direction", "gap", "padding", "align_items", "justify" },
        });
        linker.value(l, types.GridLayout, .{
            .name = .{ .named = "GridLayout" },
            .scope = .{ .module = "ui.types" },
            .fields = &.{ "columns", "rows", "flow", "row_gap", "column_gap" }
        });

        l.newMetatable("LayoutMt") catch unreachable;
        l.pushFunction(zlua.wrap(layoutGeneric)); l.setField(-2, "__call");
        l.pushFunction(zlua.wrap(layoutGrid)); l.setField(-2, "__index");
        l.pop(1);
        
        linker.module(l, .{
            .name = "ui",
            .functions = &.{
                .custom("CreateElement", luaCreateElement),
                //.custom("MeasureText", luaMeasureText),

                // Types
                .custom("Padding", struct {
                    fn c(lua: *zlua.Lua) i32 {
                        PaddingBind.push(lua, linker.util.luaTableToStruct(lua, 1, types.Padding, .{}));
                        return 1;
                    }
                }.c),
                .custom("CornerRadii", struct {
                    fn c(lua: *zlua.Lua) i32 {
                        CornerRadiiBind.push(lua, linker.util.luaTableToStruct(lua, 1, types.CornerRadii, .{}));
                        return 1;
                    }
                }.c),
                .custom("SizeMode", struct {
                    fn c(lua: *zlua.Lua) i32 {
                        SizeModeBind.push(lua, linker.util.luaTableToStruct(lua, 1, types.SizeMode, .{}));
                        return 1;
                    }
                }.c),
                .custom("Text", struct {
                    fn c(lua: *zlua.Lua) i32 {
                        // This asset ID isn't actually used for the text, rather we use it below to make sure that a font was given
                        // without being too intrusive to the linker.util.luaTableToStruct function.
                        const str = linker.util.luaTableToStruct(lua, 1, types.Text, .{ .font = .{ .id = u64_max, .assets = undefined } });
                        if (str.font.id == u64_max) lua.raiseErrorStr("'Font' must be defined when creating 'Text'", .{});

                        TextBind.push(lua, str);
                        return 1;
                    }
                }.c),
                .custom("Crop", struct {
                    fn c(lua: *zlua.Lua) i32 {
                        const str = linker.util.luaTableToStruct(lua, 1, types.Crop, .{});

                        CropBind.push(lua, str);
                        return 1;
                    }
                }.c),
                .custom("Image", struct {
                    fn c(lua: *zlua.Lua) i32 {
                        const str = linker.util.luaTableToStruct(lua, 1, types.Image, .{ .source = .{ .id = u64_max, .assets = undefined } });
                        if (str.source.id == u64_max) lua.raiseErrorStr("'Source' must be defined when creating 'Image'", .{});

                        ImageBind.push(lua, str);
                        return 1;
                    }
                }.c),
                .custom("Borders", struct {
                    fn c(lua: *zlua.Lua) i32 {
                        const str = linker.util.luaTableToStruct(lua, 1, types.Borders, .{ });

                        BordersBind.push(lua, str);
                        return 1;
                    }
                }.c)
            },
            .properties = .luaCustom(uiGet, uiSet) 
        });
    }
}.registerLua;