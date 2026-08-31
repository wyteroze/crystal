// Copyright 2026 wyteroze. Licensed under the Apache-2.0 license.

const std = @import("std");
const zlua = @import("zlua");
const util = @import("util.zig");
const recipes = @import("recipes.zig");
const Binding = @import("Binding.zig").Binding;
const Lua = zlua.Lua;

pub fn value(l: *Lua, comptime T: type, comptime recipe: recipes.LuaValueRecipe) void {
    const bind = Binding(T, false);
    l.newMetatable(bind.type_name) catch unreachable;

    _ = l.pushStringZ(switch (recipe.name) { .auto => util.shortTypeName(T), .named => |n| n });
    l.setField(-2, "__name");

    // index
    l.newTable();
    inline for (recipe.methods) |m| {
        m.push(l);
        l.setField(-2, m.name);
    }

    l.setField(-2, "__methods");

    if (recipe.fields.len > 0) {
        l.pushFunction(zlua.wrap(struct {
            fn c(lua: *Lua) i32 {
                const self = bind.checkPtr(lua, 1);
                const key = lua.checkString(2);

                inline for (recipe.fields) |name| {
                    const upper = comptime util.pascalCase(name);

                    if (std.mem.eql(u8, key, &upper)) {
                        lua.pushAny(@field(self.*, name)) catch unreachable;
                        return 1;
                    }
                }

                lua.getMetatable(1) catch { lua.pushNil(); return 1; };
                _ = lua.getField(-1, "__methods");
                lua.pushValue(2);
                _ = lua.getTable(-2);
                return 1;
            }
        }.c));

        l.setField(-2, "__index");

        l.pushFunction(zlua.wrap(struct {
            fn c(lua: *Lua) i32 {
                const self = bind.checkPtr(lua, 1);
                const key = lua.checkString(2);

                inline for (recipe.fields) |name| {
                    const upper = comptime util.pascalCase(name);

                    if (std.mem.eql(u8, key, &upper)) {
                        const FieldType = @TypeOf(@field(self.*, name));

                        @field(self.*, name) = (lua.toAny(FieldType, 3) catch |e| lua.raiseErrorStr(@errorName(e), .{}));
                        return 0;
                    }
                }

                lua.raiseErrorStr("attempt to set unknown field '%s'", .{ key.ptr });
            }
        }.c));

        l.setField(-2, "__newindex");
    } else {
        _ = l.getField(-1, "__methods");
        l.setField(-2, "__index");
    }

    if (recipe.fields.len > 0) {
        l.pushFunction(zlua.wrap(struct {
            fn c(lua: *Lua) i32 {
                const self = bind.checkPtr(lua, 1);
                const key = lua.checkString(2);

                inline for (recipe.fields) |name| {
                    const upper = comptime util.pascalCase(name);

                    if (std.mem.eql(u8, key, &upper)) {
                        const FieldType = @TypeOf(@field(self.*, name));

                        @field(self.*, name) = (lua.toAny(FieldType, 3) catch |e| lua.raiseErrorStr(@errorName(e), .{}));
                        return 0;
                    }
                }

                lua.raiseErrorStr("attempt to set unknown field '%s'", .{ key.ptr });
            }
        }.c));
        l.setField(-2, "__newindex");
    }

    // new
    inline for (.{
        .{ "__add", recipe.ops.add },
        .{ "__sub", recipe.ops.sub },
        .{ "__mul", recipe.ops.mul },
        .{ "__div", recipe.ops.div },
        .{ "__unm", recipe.ops.neg }
    }) |entry| {
        if (entry[1]) |mode| switch (mode) {
            .custom_fn => |func| {
                func(l);
                l.setField(-2, entry[0]);
            },
            .identity => @compileError(entry[0] ++ " has no identity default; pass .custom(fn)")
        };
    }

    if (recipe.ops.eq) |eq| switch (eq) {
        .identity => {
            l.pushFunction(zlua.wrap(util.identityEq(bind)));
            l.setField(-2, "__eq");
        },
        .custom_fn => |func| {
            func(l);
            l.setField(-2, "__eq");
        }
    };
    if (recipe.ops.tostring) |tostr| switch (tostr) {
        .identity => {
            l.pushFunction(zlua.wrap(util.identityToString(bind)));
            l.setField(-2, "__tostring");
        },
        .custom_fn => |func| {
            func(l);
            l.setField(-2, "__tostring");
        }
    };

    l.pop(1);

    l.newTable();
    inline for (recipe.constructors) |m| {
        m.push(l);
        l.setField(-2, m.name);
    }
    inline for (recipe.constants) |m| {
        m.push(l);
        l.setField(-2, m.name);
    }

    // Table is at top of stack

    switch (recipe.scope) {
        .global => l.setGlobal(switch (recipe.name) { .auto => util.shortTypeName(T), .named => |nm| nm }),
        .module => |name| util.moduleRegister(l, name, switch (recipe.name) { .auto => util.shortTypeName(T), .named => |nm| nm }),
        .top_level_module => util.registerTopLevelModule(l, switch (recipe.name) { .auto => util.shortTypeName(T), .named => |nm| nm })
    }
}
