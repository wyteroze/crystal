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
    computed_size: ecs.ComponentId,
    computed_position: ecs.ComponentId,
    computed_text_layout: ecs.ComponentId,
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
    const text = try world.registerComponentNativeShaped(Ui.types.Text, "Text", null);
    const render_view = try world.registerComponentNativeShaped(types.RenderViewOptions, "RenderView", null);
    const computed_size = try world.registerComponentNativeShaped(math.Vec2, "ComputedSize", null);
    const computed_position = try world.registerComponentNativeShaped(math.Vec2, "ComputedPosition", null);
    const computed_text_layout = try world.registerComponentNativeShaped(types.ComputedTextLayout, "ComputedTextLayout", null);

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
            .computed_size = computed_size,
            .computed_position = computed_position,
            .computed_text_layout = computed_text_layout
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

    fn sizeAxisFixed(lua: *zlua.Lua) i32 {
        SizeAxisBind.push(lua, .{ .fixed = @floatCast(lua.checkNumber(1)) });
        return 1;
    }

    fn pushEnum(l: *zlua.Lua, comptime T: type) void {
        l.newTable();
        inline for (std.meta.fields(T)) |f| {
            _ = l.pushStringZ(f.name); l.setField(-2, f.name);
        }
    }

    fn uiGet(l: *zlua.Lua) i32 {
        const key = l.toString(2) catch |e| linker.util.luaErr(l, e, .{ []const u8, 2 });

        if (std.mem.eql(u8, key, "SizeAxis")) {
            l.newTable();
            SizeAxisBind.push(l, .hug);  l.setField(-2, "Hug");
            SizeAxisBind.push(l, .fill); l.setField(-2, "Fill");
            l.pushFunction(zlua.wrap(sizeAxisFixed)); l.setField(-2, "Fixed");
            return 1;
        } else if (std.mem.eql(u8, key, "LayoutDirection")) {
            pushEnum(l, types.LayoutDirection);
            return 1;
        } else if (std.mem.eql(u8, key, "Align")) {
            pushEnum(l, types.Align);
            return 1;
        } else if (std.mem.eql(u8, key, "Justify")) {
            pushEnum(l, types.Justify);
            return 1;
        }
        else {
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
        _ = l;
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

    fn luaTableToStruct(l: *zlua.Lua, idx: i32, comptime T: type, default: T) T {
        var str: T = default;

        l.checkType(idx, .table);
        l.pushNil();
        while (l.next(idx)) {
            l.checkType(-2, .string);
            const key = l.toString(-2) catch |e| linker.util.luaErr(l, e, .{ []const u8, -2 });

            var matched = false;
            inline for (@typeInfo(T).@"struct".fields) |sf| {
                if (std.mem.eql(u8, key, &linker.util.pascalCase(sf.name))) {
                    @field(str, sf.name) = linker.util.parseVal(l, sf.type, -1) catch |e| linker.util.luaErr(l, e, .{});
                    matched = true;
                }
            }
            if (!matched) l.raiseErrorStr("unknown field '%s'", .{ key.ptr });

            l.pop(1);
        }

        return str;
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
            .fields = &.{ "direction", "gap", "padding", "align_items", "justify" },
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
        
        linker.module(l, .{
            .name = "ui",
            .functions = &.{
                .custom("CreateElement", luaCreateElement),
                //.custom("MeasureText", luaMeasureText),

                // Types
                .custom("Padding", struct {
                    fn c(lua: *zlua.Lua) i32 {
                        PaddingBind.push(lua, luaTableToStruct(lua, 1, types.Padding, .{}));
                        return 1;
                    }
                }.c),
                .custom("CornerRadii", struct {
                    fn c(lua: *zlua.Lua) i32 {
                        CornerRadiiBind.push(lua, luaTableToStruct(lua, 1, types.CornerRadii, .{}));
                        return 1;
                    }
                }.c),
                .custom("Layout", struct {
                    fn c(lua: *zlua.Lua) i32 {
                        LayoutBind.push(lua, luaTableToStruct(lua, 1, types.Layout, .{}));
                        return 1;
                    }
                }.c),
                .custom("SizeMode", struct {
                    fn c(lua: *zlua.Lua) i32 {
                        SizeModeBind.push(lua, luaTableToStruct(lua, 1, types.SizeMode, .{}));
                        return 1;
                    }
                }.c),
                .custom("Text", struct {
                    fn c(lua: *zlua.Lua) i32 {
                        // This asset ID isn't actually used for the text, rather we use it below to make sure that a font was given
                        // without being too intrusive to the luaTableToStruct function.
                        const str = luaTableToStruct(lua, 1, types.Text, .{ .font = .{ .id = std.math.maxInt(usize), .assets = undefined } });
                        if (str.font.id == std.math.maxInt(usize)) lua.raiseErrorStr("'Font' must be defined when creating 'Text'", .{});

                        TextBind.push(lua, str);
                        return 1;
                    }
                }.c)
            },
            .properties = .luaCustom(uiGet, uiSet) 
        });
    }
}.registerLua;